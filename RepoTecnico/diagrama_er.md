# 📐 Diagrama Entidad-Relación — RWA

> **Versión: v1.1 · 2026-10-03.** Cubre el modelo de datos del proyecto: on-chain (contratos de
> `rwa-sc/sc/src/`) y off-chain (MongoDB `rwa`).
> **Sincronizado con `diccionario_datos.md`** (mismo nombre para cada entidad, campo y topic) y con
> `base_datos.sql`.
>
> **Changelog v1.1:** regenerado contra el storage real (H-14); se eliminan `holders[]`, `holderIndex[]`,
> `firstReceiveTime`, `issuerTopics` y el campo `token` de los módulos/registro de topics; se añade el
> bloque **§3 PLANIFICADO** (RF-001, RF-004, RF-011, RF-012, RF-013); se corrige el modelo off-chain
> (`requesterAddress`, `tokenAddress`, `requiredClaims`, colección `issuers`, metadata GridFS).
> Trazabilidad: `INFORME_OPTIMIZACION_V1.md` (H-13, H-14, H-08, H-11, H-20).

## 1. Modelo on-chain — EXISTENTE hoy

```mermaid
erDiagram
    WALLET ||--o| IDENTITYCLONEABLE : "posee"
    WALLET ||--o| IDENTITYREGISTRY : "registrada_en"
    IDENTITYCLONEABLE ||--o{ CLAIM : "contiene"
    CLAIM }o--|| TRUSTEDISSUERSREGISTRY : "emitido_por"
    TOKENCLONEABLE }o--|| IDENTITYREGISTRY : "consulta"
    TOKENCLONEABLE }o--|| TRUSTEDISSUERSREGISTRY : "valida_claims"
    TOKENCLONEABLE }o--o| CLAIMTOPICSREGISTRYCLONEABLE : "exige_topics"
    TOKENCLONEABLE ||--o{ MAXBALANCECOMPLIANCE : "regulado_por"
    TOKENCLONEABLE ||--o{ MAXHOLDERSCOMPLIANCE : "regulado_por"
    TOKENCLONEABLE ||--o{ TRANSFERLOCKCOMPLIANCE : "regulado_por"
    COMPLIANCEAGGREGATOR }o--o{ MAXBALANCECOMPLIANCE : "agrega"
    COMPLIANCEAGGREGATOR }o--o{ MAXHOLDERSCOMPLIANCE : "agrega"
    COMPLIANCEAGGREGATOR }o--o{ TRANSFERLOCKCOMPLIANCE : "agrega"
    COMPLIANCEAGGREGATOR }o--o{ TOKENCLONEABLE : "gestiona_modulos_de"

    IDENTITYCLONEABLE {
        mapping claims "topic=>issuer=>Claim"
        mapping topicIssuers "topic=>address[]"
        mapping topicIssuerExists "topic=>issuer=>bool"
    }
    CLAIM {
        uint256 topic
        uint256 scheme
        address issuer
        bytes signature "FIRMA_NO_VERIFICADA_H01"
        bytes data
        string uri
    }
    IDENTITYREGISTRY {
        mapping identities "wallet=>IdentityCloneable"
        mapping registered "wallet=>bool"
        address_array registeredAddresses "H20_O_n"
    }
    TRUSTEDISSUERSREGISTRY {
        mapping trustedIssuers "issuer=>bool"
        mapping issuerClaimTopics "issuer=>uint256[]"
        address_array trustedIssuersList "H20_O_n"
    }
    CLAIMTOPICSREGISTRYCLONEABLE {
        uint256_array claimTopics "H20_O_n"
        bool claimTopicExists "funcion_no_mapping"
    }
    TOKENCLONEABLE {
        address identityRegistry "FK"
        address trustedIssuersRegistry "FK"
        address claimTopicsRegistry "FK"
        mapping complianceModules "ICompliance[]"
        mapping frozen "account=>bool"
        bool bypassCompliance "H03_RF002"
        string _tokenName "H06_muerto"
        string _tokenSymbol "H06_muerto"
        uint8 _tokenDecimals
    }
    COMPLIANCEAGGREGATOR {
        mapping tokenModules "token=>ICompliance[]"
        mapping moduleIndex "token=>module=>uint256"
        mapping isModuleActive "token=>module=>bool"
        address_array tokens "H20_O_n"
        mapping _isTokenRegistered "token=>bool"
    }
    MAXBALANCECOMPLIANCE {
        uint256 maxBalance
        address tokenContract "FK"
    }
    MAXHOLDERSCOMPLIANCE {
        uint256 maxHolders
        uint256 holderCount
        address tokenContract "FK"
        mapping isHolder "account=>bool"
        mapping authorizedCallers "caller=>bool"
    }
    TRANSFERLOCKCOMPLIANCE {
        uint256 lockPeriod
        address tokenContract "FK"
        mapping lockEndTime "account=>uint256"
        mapping authorizedCallers "caller=>bool"
    }
```

> **H-14:** en esta versión **no** aparecen `holders[]`, `holderIndex[]`, `firstReceiveTime` ni
> `issuerTopics`. El estado por cuenta de holders es `isHolder` + `holderCount`; el lock es `lockEndTime`;
> la autorización por topic es `issuerClaimTopics`; el token en los módulos es `tokenContract`.

## 2. Modelo off-chain (MongoDB `rwa`) — EXISTENTE hoy

```mermaid
erDiagram
    CLAIM_REQUEST }o--|| ISSUER : "destinada_a"
    CLAIM_REQUEST }o--o| DOCUMENT_FILE : "adjunta"
    CLAIM_REQUEST ||--o| CLAIM : "produce_si_aprobada"

    CLAIM_REQUEST {
        objectid _id PK
        string requesterAddress
        string issuerAddress "filtro en consulta"
        string claimTopic
        string message "opcional"
        string documentFileId "ref GridFS"
        string documentName "opcional"
        string documentContentType "opcional"
        number documentSize "opcional"
        string status "pending|approved|rejected"
        string signedMessage
        string signature
        date createdAt
        date updatedAt
        date reviewedAt "opcional"
        string reviewNote "opcional"
        string issuerSignedMessage "opcional"
        string issuerSignature "opcional"
    }
    ISSUER {
        objectid _id PK
        string address "minusculas"
        string name
        date createdAt
        date updatedAt
    }
    DOCUMENT_FILE {
        objectid _id PK "GridFS claim_documents.files"
        string filename
        number length
        number chunkSize
        date uploadDate
        string metadata_contentType "MIME en metadata"
        string metadata_originalName
        number metadata_size
        date metadata_uploadedAt
    }
    TOKEN {
        objectid _id PK
        string name
        string symbol
        number decimals
        string tokenAddress "unique funcional"
        string adminAddress
        string complianceAddress "opcional"
        string_array complianceModules "opcional"
        number_array requiredClaims
        number price "opcional"
        date createdAt
        date updatedAt
        string transactionHash "opcional"
        number blockNumber "opcional"
        string totalSupply "opcional"
        string description "opcional"
    }
```

> **Corrección off-chain:** la solicitud se identifica por `requesterAddress` (no `wallet`),
> `issuerAddress` (no `issuer`), `claimTopic` (no `topic`) y `documentFileId` (no `documentId`); el token
> por `tokenAddress` (no `address`) y `requiredClaims` (no `requiredTopics`); se documenta la colección
> `issuers`. Sin índices explícitos en código (`createIndex` no aparece).

## 3. PLANIFICADO (aprobado y NO implementado) — `requerimientos.md` §3, D-014

> Bloque separado: **no existe hoy**. No debe confundirse con §1/§2.

```mermaid
erDiagram
    TOKENCLONEABLE {
        mapping authorizedDestinations "RF004 address=>bool"
        uint256 maxBurnPerTx "RF004"
        uint256 maxForcedPerTx "RF004"
        bool isVerified_failClosed "RF011 cambio_semantica_sin_campos"
    }
    COMPLIANCEAGGREGATOR {
        mapping tokenRegistered "RF012 token=>bool fail_closed"
    }
    CLAIM {
        uint256 expiresAt "RF013"
        bool revoked "RF013"
        mapping revocationIndex "RF013"
        uint256 schemeId "RF001 EIP712"
        bytes32 digest "RF001 ecrecover"
    }
```

| Requisito | Entidad afectada | Cambio planificado |
|---|---|---|
| RF-004 | `TokenCloneable` | `authorizedDestinations[address]`, `maxBurnPerTx`, `maxForcedPerTx` |
| RF-011 | `TokenCloneable` | `isVerified` fail-closed (cambio de comportamiento, sin campos) |
| RF-012 | `ComplianceAggregator` | estado explícito `tokenRegistered[token]` (hoy `_isTokenRegistered` implícito) |
| RF-013 | `IdentityCloneable` / `Claim` | `expiresAt`, `revoked`, índice de revocación |
| RF-001 | `IdentityCloneable` / `Claim` | `schemeId` + digest EIP-712 y `ecrecover` |

## 4. Relaciones clave a preservar

1. **wallet → identity → claims → trusted issuer**: cadena de verificación de `isVerified()` del token.
2. **token → claimTopicsRegistry (1:1 por token)**: requisitos dinámicos por emisión.
3. **compliance module: N agregados por token a través de `ComplianceAggregator`** (el token puede tener
   además módulos directos en `complianceModules`).
4. **claim_request off-chain → claim on-chain**: la aprobación del issuer dispara `addClaim` on-chain
   (flujo actual **sin verificación de firma** — H-01/RF-001).

## 5. Catálogo de claim topics (idéntico al diccionario §3)

- **Oficial:** `1 = KYC`, `7 = Accreditation`, `9 = Jurisdiction` (`rwa-web/README.md:325-327`).
- **Reservado/backlog:** `5 = Environmental`, `6 = Sanctions` (**no implementados**, H-10/R-2).
- **Deprecados:** catálogos `1/2/3/4` (`ARQUITECTURA_FINAL.md:65`), `1/2/3/9/10`
  (`REFERENCIA_TECNICA.md:823-833`) y `5/6/7`; y las fixtures de test `1/2`, `1/2/3` y `2=Accreditation`.
