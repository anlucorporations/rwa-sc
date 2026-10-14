# 📐 Diagrama Entidad-Relación — RWA

> **🔗 Artefacto de datos compartido — copia espejo sincronizada (2026-10-14).** Existe en las dos líneas
> de desarrollo: **canónico** `rwa-sc/RepoTecnico/diagrama_er.md` · **espejo** `rwa-web/RepoTecnico/diagrama_er.md`.
> Deben ser **idénticos byte a byte**: edita solo el canónico y ejecuta `rwa-web/RepoTecnico/check_sincronizacion_datos.sh --sync`
> (regla de sincronización en `rwa-web/RepoTecnico/ARTEFACTOS_DATOS_SINCRONIZADOS.md`).
>
> **Versión: v1.2 · 2026-10-14.** Cubre el modelo de datos del proyecto: on-chain (contratos de
> `rwa-sc/sc/src/`) y off-chain (**PostgreSQL**, esquema `rwa`).
> **Sincronizado con `diccionario_datos.md` v1.2** (mismo nombre para cada entidad, campo y topic) y con
> `base_datos.sql` v1.0.
>
> **Changelog v1.2 (2026-10-14):** **Q6 resuelta (D-095):** el modelo off-chain pasa de MongoDB a
> **PostgreSQL**; §2 se reescribe con entidades del esquema `rwa` (nuevas `CLAIM_TOPICS`, `SESSIONS`,
> `AUDIT_LOG`; `DOCUMENT_FILES` con contenido cifrado; tablas puente `TOKEN_REQUIRED_CLAIMS` y
> `TOKEN_COMPLIANCE_MODULES`). Red on-chain canónica del frontend: **Anvil de GCP** (D-096). §3 pasa a
> referencia histórica (los cambios que figuraban como planificados **se implementaron** en la Fase 3).
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

## 2. Modelo off-chain (**PostgreSQL**, esquema `rwa`) — v1.2

> **Q6 RESUELTA (D-095):** la BD off-chain es **PostgreSQL**, no MongoDB. Entidades, campos y claves son
> **idénticos** a `base_datos.sql` v1.0 y a `diccionario_datos.md` §2 (sincronizados en el mismo turno).

```mermaid
erDiagram
    CLAIM_TOPICS ||--o{ CLAIM_REQUESTS : "clasifica"
    CLAIM_REQUESTS ||--o{ DOCUMENT_FILES : "adjunta"
    CLAIM_REQUESTS }o--|| ISSUERS : "destinada_a (logica, sin FK)"
    TOKENS ||--o{ TOKEN_REQUIRED_CLAIMS : "exige"
    CLAIM_TOPICS ||--o{ TOKEN_REQUIRED_CLAIMS : "es_exigido_en"
    TOKENS ||--o{ TOKEN_COMPLIANCE_MODULES : "usa"

    CLAIM_TOPICS {
        smallint id PK "1=KYC, 7=Accreditation, 9=Jurisdiction"
        text code UK
        text name
        text description "opcional"
        boolean active "false = reservado (5, 6)"
        timestamptz created_at
    }
    ISSUERS {
        uuid id PK
        text address UK "CHECK 0x[0-9a-f]{40}"
        text name
        boolean verified "cache del estado on-chain"
        timestamptz verified_at "opcional"
        timestamptz created_at
        timestamptz updated_at
    }
    CLAIM_REQUESTS {
        uuid id PK
        text requester_address "CHECK 0x..."
        text issuer_address "CHECK 0x..."
        smallint claim_topic_id FK
        text message "opcional"
        claim_request_status status "pending|approved|rejected"
        text signed_message
        text signature "verificada en servidor"
        text review_note "opcional"
        text issuer_signed_message "opcional"
        text issuer_signature "opcional"
        text reviewed_by "opcional, nuevo HW-01"
        timestamptz reviewed_at "opcional"
        timestamptz created_at
        timestamptz updated_at
    }
    DOCUMENT_FILES {
        uuid id PK
        uuid claim_request_id FK "CASCADE"
        text original_name
        text content_type "allowlist MIME"
        bigint size_bytes "0 < n <= 10 MB"
        bytea sha256
        bytea content "cifrado AES-256-GCM"
        text encryption_algo
        bytea encryption_nonce "opcional"
        text uploaded_by "CHECK 0x..."
        timestamptz created_at
    }
    TOKENS {
        uuid id PK
        text token_address UK "CHECK 0x..."
        text admin_address "CHECK 0x..."
        text name
        text symbol "CHECK ^[A-Z0-9]{1,11}$"
        smallint decimals "0..18"
        numeric max_total_supply "opcional"
        numeric total_supply "opcional"
        text identity_registry "NOT NULL"
        text trusted_issuers_registry "NOT NULL"
        text claim_topics_registry "NOT NULL (RF-W-11)"
        text compliance_address "opcional"
        numeric price "opcional"
        text description "opcional"
        text transaction_hash "opcional"
        bigint block_number "opcional"
        timestamptz created_at
        timestamptz updated_at
    }
    TOKEN_REQUIRED_CLAIMS {
        uuid token_id PK "FK tokens CASCADE"
        smallint claim_topic_id PK "FK claim_topics RESTRICT"
        timestamptz created_at
    }
    TOKEN_COMPLIANCE_MODULES {
        uuid token_id PK "FK tokens CASCADE"
        text module_address PK "CHECK 0x..."
        boolean is_primary
        timestamptz created_at
    }
    SESSIONS {
        uuid id PK "id de la cookie httpOnly"
        text address "CHECK 0x..."
        text nonce UK "SIWE de un solo uso"
        session_role role "investor|issuer|admin"
        timestamptz issued_at
        timestamptz expires_at
        timestamptz revoked_at "opcional"
        text user_agent "opcional"
        inet ip "opcional"
    }
    AUDIT_LOG {
        bigserial id PK
        text actor_address "opcional"
        text action
        text resource_type
        text resource_id "opcional"
        text request_id "opcional"
        jsonb detail "opcional"
        timestamptz at
    }
    SCHEMA_MIGRATIONS {
        text version PK
        timestamptz applied_at
    }
```

> **Relaciones:** `CLAIM_REQUESTS → ISSUERS` es **lógica** (no hay FK: la tabla `issuers` es solo el nombre
> visible y la integridad del emisor vive on-chain en `TrustedIssuersRegistry`). `DOCUMENT_FILES` pertenece a
> la solicitud (`ON DELETE CASCADE`) y es la unidad de autorización de acceso (RF-W-06). Las tablas puente
> `TOKEN_REQUIRED_CLAIMS` y `TOKEN_COMPLIANCE_MODULES` normalizan los antiguos arrays
> `requiredClaims`/`complianceModules`. `SESSIONS` y `AUDIT_LOG` no tienen FK (identifican wallets por
> dirección, no por usuario). Vista de apoyo: `rwa.v_claim_request_summary`.

## 3. Cambios on-chain implementados en Fase 3 (referencia histórica)

> **Nota v1.2:** este bloque figuraba como *PLANIFICADO*. La Fase 3 lo **implementó y verificó**
> (394/394 tests, cobertura `src/` 97,05 %): RF-001/RF-002/RF-004/RF-011/RF-012/RF-013. Se conserva como
> referencia; el estado real está en `estado_proyecto.md`. **No existe hoy** como bloque separado del modelo
> on-chain real de §1 — no debe confundirse con §1/§2. La etapa actual (D-088) **no modifica** el storage
> on-chain.

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
