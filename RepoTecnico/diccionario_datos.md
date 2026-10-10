# 🗂️ Diccionario de Datos — RWA

> **Versión: v1.1 · 2026-10-03.** Fuente de verdad de datos del proyecto. Cubre el **modelo on-chain**
> (contratos, storage) y el **modelo off-chain** (MongoDB).
>
> **Changelog v1.1 (2026-10-03):**
> - **H-14 (fidelidad on-chain):** se regeneran las tablas de storage contra el código real de
>   `rwa-sc/sc/src/` (cada campo se marca `existe (ruta:línea)` o `planificado (RF-0xx)`). Se eliminan
>   campos inexistentes (`holders[]`, `holderIndex[]`, `firstReceiveTime`, `issuerTopics`, `token` en
>   módulos y en `ClaimTopicsRegistry`).
> - **H-13 (catálogo de claim topics):** se fija un **catálogo canónico único** (§3) y se documentan los
>   catálogos antiguos divergentes que quedan **deprecados**.
> - **RF-004/RF-011/RF-012/RF-013/RF-001:** nueva sección "Cambios planificados por requisito" (§5),
>   separada de forma explícita de lo existente.
> - **H-11/H-20:** se anota la ausencia de custodio/índices off-chain y los arrays O(n) no acotados.
> - Trazabilidad: ver `INFORME_OPTIMIZACION_V1.md` (H-13, H-14, H-08, H-11, H-20) y `requerimientos.md`.
>
> Regla: cada cambio de datos en Fase 3 actualiza este archivo + `diagrama_er.md` + `base_datos.sql` en el
> mismo turno. **Ningún nombre de campo puede diferir entre los tres artefactos.**

## 1. Modelo on-chain (rwa-sc)

> Convención: `existe (ruta:línea)` = presente hoy en el código citado. `planificado (RF-0xx)` = aprobado
> pero **no implementado** (ver §5). Las líneas corresponden a `rwa-sc/sc/src/`.

### Entidad: `IdentityCloneable` (por inversor)
| Campo | Tipo | Clave | Estado | Descripción |
|---|---|---|---|---|
| `claims` | `mapping(uint256 => mapping(address => Claim))` private | PK lógica (topic+issuer) | existe (`IdentityCloneable.sol:13`) | Claim por topic y emisor |
| `topicIssuers` | `mapping(uint256 => address[])` private | — | existe (`IdentityCloneable.sol:16`) | Emisores con claim en el topic (índice) |
| `topicIssuerExists` | `mapping(uint256 => mapping(address => bool))` private | — | existe (`IdentityCloneable.sol:19`) | Índice de existencia de emisor por topic |
| struct `Claim` | `{uint256 topic; uint256 scheme; address issuer; bytes signature; bytes data; string uri;}` | — | existe (`IdentityCloneable.sol:21-28`) | **Sin** `expiresAt`, `revoked`, `issuedAt` (H-08) |

> **H-14 corregido:** no existe `holders[]`, `holderIndex[]`, `firstReceiveTime` ni `issuerTopics` en este
> contrato. El índice de emisores se llama `topicIssuers` (array) + `topicIssuerExists` (mapping).

### Entidad: `IdentityRegistry` (compartido)
| Campo | Tipo | Clave | Estado | Descripción |
|---|---|---|---|---|
| `identities` | `mapping(address => IdentityCloneable)` private | PK (wallet) | existe (`IdentityRegistry.sol:14`) | Contrato Identity de cada wallet |
| `registered` | `mapping(address => bool)` private | — | existe (`IdentityRegistry.sol:17`) | Bandera de registro |
| `registeredAddresses` | `address[]` private | — | existe (`IdentityRegistry.sol:20`) | Índice de wallets registradas (**H-20:** array O(n) con borrado O(n), `:73-79`) |

### Entidad: `TrustedIssuersRegistry` (compartido)
| Campo | Tipo | Clave | Estado | Descripción |
|---|---|---|---|---|
| `trustedIssuers` | `mapping(address => bool)` private | PK (issuer) | existe (`TrustedIssuersRegistry.sol:16`) | Si el emisor es confiable |
| `issuerClaimTopics` | `mapping(address => uint256[])` private | — | existe (`TrustedIssuersRegistry.sol:13`) | Topics autorizados por emisor (array, no mapping por topic) |
| `trustedIssuersList` | `address[]` private | — | existe (`TrustedIssuersRegistry.sol:19`) | Índice de emisores (**H-20:** borrado O(n), `:55-61`) |

> **H-14 corregido:** **no** existe `issuerTopics[issuer][topic]` (mapping booleano). La autorización por
> topic se calcula iterando `issuerClaimTopics` en `hasClaimTopic()` (`TrustedIssuersRegistry.sol:101-113`).

### Entidad: `ClaimTopicsRegistryCloneable` (por token)
| Campo | Tipo | Clave | Estado | Descripción |
|---|---|---|---|---|
| `claimTopics` | `uint256[]` private | — | existe (`ClaimTopicsRegistryCloneable.sol:14`) | Topics requeridos por el token |
| `claimTopicExists` | `function (uint256) public view returns (bool)` | — | existe (`ClaimTopicsRegistryCloneable.sol:73-80`) | **Es una función**, no un mapping; itera `claimTopics` |

> **H-14 corregido:** **no** existe el campo `token` en este registro (la relación token–registro se guarda
> en `TokenCloneable.claimTopicsRegistry`), ni un mapping índice `claimTopicExists[topic]`.
> La variante no clonable `ClaimTopicsRegistry` (`ClaimTopicsRegistry.sol:16-81`) tiene el mismo storage.

### Entidad: `TokenCloneable`
| Campo | Tipo | Clave | Estado | Descripción |
|---|---|---|---|---|
| `identityRegistry` | `IdentityRegistry` public | FK | existe (`TokenCloneable.sol:23`) | Registry de identidades |
| `trustedIssuersRegistry` | `TrustedIssuersRegistry` public | FK | existe (`TokenCloneable.sol:24`) | Registry de emisores |
| `claimTopicsRegistry` | `IClaimTopicsRegistry` public | FK | existe (`TokenCloneable.sol:25`) | Requirements de claims del token |
| `complianceModules` | `ICompliance[]` public | — | existe (`TokenCloneable.sol:28`) | Módulos activos directos |
| `_tokenName` | `string` private | — | existe (`TokenCloneable.sol:31`) | **H-06:** storage muerto (nombre ERC-20 duplicado) |
| `_tokenSymbol` | `string` private | — | existe (`TokenCloneable.sol:32`) | **H-06:** storage muerto |
| `_tokenDecimals` | `uint8` private | — | existe (`TokenCloneable.sol:33`) | Decimales |
| `frozen` | `mapping(address => bool)` private | PK (account) | existe (`TokenCloneable.sol:44`) | Cuenta congelada |
| `bypassCompliance` | `bool` private | — | existe (`TokenCloneable.sol:47`) | **H-03/H-18: flag a rediseñar (RF-002)** |
| roles `DEFAULT_ADMIN_ROLE`, `AGENT_ROLE`, `COMPLIANCE_ROLE` | `bytes32 public constant` | — | existe (`TokenCloneable.sol:19-20` + `AccessControlUpgradeable`) | `DEFAULT_ADMIN_ROLE` heredado de OZ |
| balances / allowances / totalSupply | ERC-20 | — | existe (`ERC20Upgradeable`) | State estándar ERC-20 |

### Entidad: `ComplianceAggregator`
| Campo | Tipo | Clave | Estado | Descripción |
|---|---|---|---|---|
| `tokenModules` | `mapping(address => ICompliance[])` private | FK (token) | existe (`ComplianceAggregator.sol:26`) | Módulos por token |
| `moduleIndex` | `mapping(address => mapping(address => uint256))` private | — | existe (`ComplianceAggregator.sol:29`) | Índice para borrado O(1) |
| `isModuleActive` | `mapping(address => mapping(address => bool))` private | — | existe (`ComplianceAggregator.sol:32`) | Estado del módulo |
| `tokens` | `address[]` private | — | existe (`ComplianceAggregator.sol:35`) | Índice de tokens que usan el aggregator |
| `_isTokenRegistered` | `mapping(address => bool)` private | PK lógica (token) | existe (`ComplianceAggregator.sol:38`) | Registro implícito (se marca solo al añadir módulo). **RF-012** lo hará explícito y fail-closed → §5 |

### Módulos de compliance (state propio)
| Módulo | Campos | Estado |
|---|---|---|
| `MaxBalanceCompliance` | `maxBalance` (`MaxBalanceCompliance.sol:14`), `tokenContract` (`:17`) | existe |
| `MaxHoldersCompliance` | `maxHolders` (`MaxHoldersCompliance.sol:14`), `holderCount` (`:17`), `tokenContract` (`:20`), `isHolder` (`:23`), `authorizedCallers` (`:26`) | existe |
| `TransferLockCompliance` | `lockPeriod` (`TransferLockCompliance.sol:14`), `tokenContract` (`:17`), `lockEndTime` (`:20`), `authorizedCallers` (`:23`) | existe |

> **H-14 corregido (módulos):** el identificador del token es **`tokenContract`**, no `token`. En
> `MaxHoldersCompliance` el estado por cuenta es **`isHolder`** (mapping, **no** `holders[]` +
> `holderIndex[]`) y se añade **`holderCount`** (contador) y **`authorizedCallers`**. En
> `TransferLockCompliance` el lock por cuenta es **`lockEndTime`** (**no** `firstReceiveTime`).

### Estado de eventos de compliance
Los módulos **no** emiten `TokenContractSet` al fijar `tokenContract` (H-34, backlog QW-8). Los eventos hoy
emitidos son los documentados en cada `.sol` (`MaxHoldersSet`, `HolderAdded`, `HolderRemoved`,
`LockPeriodSet`, `TransferLocked`, `MaxBalanceSet`, `ModuleAdded`, `ModuleRemoved`, `TokenRegistered`).

## 2. Modelo off-chain (rwa-web → MongoDB, BD `rwa`)

> Transcrito fielmente de los tipos y rutas de `rwa-web/` (no de suposiciones). Los nombres de campo son
> **exactos** (camelCase). La BD **activa** es MongoDB; la transcripción PostgreSQL es un borrador
> pendiente (ver `base_datos.sql`).

### Colección: `claim_requests`
Fuente: `rwa-web/web-identity/types/claim-request.ts:5-26` (idéntico en `web-registry-trusted`),
`web-identity/app/api/claim-requests/route.ts`, `web-registry-trusted/app/api/update-request/route.ts`.

| Campo | Tipo | Índice | Descripción |
|---|---|---|---|
| `_id` | ObjectId | PK | Identificador único |
| `requesterAddress` | string (0x…) | — (sin índice en código) | Wallet solicitante |
| `issuerAddress` | string (0x…) | — (filtro en consulta `:29`) | Emisor destinatario (minúsculas) |
| `claimTopic` | string | — | Topic del claim (string, no int) |
| `message` | string? | — | Mensaje del solicitante |
| `documentFileId` | string? | — | Ref GridFS del documento adjunto |
| `documentName` | string? | — | Nombre del documento |
| `documentContentType` | string? | — | MIME del documento |
| `documentSize` | number? | — | Bytes del documento |
| `status` | enum: `pending`/`approved`/`rejected` | — (filtro `:32`) | Estado de la solicitud |
| `signedMessage` | string | — | Mensaje firmado por el solicitante (requester + fecha) |
| `signature` | string | — | Firma criptográfica del solicitante (MetaMask) |
| `createdAt` | ISODate | — | Creación (`web-identity/.../route.ts:90`) |
| `updatedAt` | ISODate | — | Última actualización |
| `reviewedAt` | ISODate? | — | Revisión por el issuer |
| `reviewNote` | string? | — | Nota del issuer al aprobar/rechazar |
| `issuerSignedMessage` | string? | — | Mensaje firmado por el issuer |
| `issuerSignature` | string? | — | Firma criptográfica del issuer |

> **Corrección respecto a v1.0:** los campos `wallet`, `issuer`, `topic`, `documentId` e `issuerNote` **no
> existen** con esos nombres; son `requesterAddress`, `issuerAddress`, `claimTopic`, `documentFileId` y
> `reviewNote`. No hay índice único compuesto declarado en el código (`grep createIndex` sin resultados).

### Colección: `tokens`
Fuente: `rwa-web/web-token/types/token.ts:5-24`, `app/api/tokens/route.ts`.

| Campo | Tipo | Índice | Descripción |
|---|---|---|---|
| `_id` | ObjectId | PK | Identificador único |
| `name` / `symbol` | string | — | Metadatos |
| `decimals` | number | — | Decimales |
| `tokenAddress` | string (0x…) | — | Dirección on-chain del token |
| `adminAddress` | string (0x…) | — | Admin del token |
| `complianceAddress` | string? | — | Módulo principal (compatibilidad) |
| `complianceModules` | string[]? | — | Todos los módulos de compliance |
| `requiredClaims` | number[] | — | Topics exigidos (**no** `requiredTopics`) |
| `price` | number? | — | Precio por token en ETH |
| `createdAt` / `updatedAt` | ISODate | — | Timestamps |
| `transactionHash` | string? | — | Hash del deploy |
| `blockNumber` | number? | — | Bloque del deploy |
| `totalSupply` | string? | — | Suministro |
| `description` | string? | — | Descripción |

> **Corrección respecto a v1.0:** `address` → `tokenAddress`; `requiredTopics` → `requiredClaims`;
> `complianceModule` → `complianceAddress`; `createdBy` → `adminAddress`; se añaden `decimals`,
> `complianceModules`, `transactionHash`, `blockNumber`, `totalSupply`, `description`, `updatedAt`.

### Colección: `issuers` (**nueva en v1.1, existía sin documentar**)
Fuente: `rwa-web/web-identity/types/issuer.ts:5-10`, `web-registry-trusted/app/api/issuers/route.ts:28-55`.

| Campo | Tipo | Índice | Descripción |
|---|---|---|---|
| `_id` | ObjectId | PK | Identificador único |
| `address` | string (0x…, minúsculas) | — (búsqueda por `address`) | Dirección del emisor |
| `name` | string | — | Nombre del emisor |
| `createdAt` / `updatedAt` | ISODate | — | Timestamps |

### GridFS: bucket `claim_documents` (colecciones `claim_documents.files` / `claim_documents.chunks`)
Fuente: `rwa-web/web-identity/app/api/upload/route.ts:62-80`, `.../download/[fileId]/route.ts:42`.

| Campo | Tipo | Descripción |
|---|---|---|
| `_id` | ObjectId | Ref en `claim_requests.documentFileId` |
| `filename` | string | Nombre del subido (`openUploadStream(file.name)`) |
| `length` | number | Bytes |
| `chunkSize` | number | Tamaño de chunk (GridFS) |
| `uploadDate` | ISODate | Fecha de subida (GridFS) |
| `metadata.originalName` | string | Nombre original |
| `metadata.contentType` | string | MIME (**dentro de `metadata`**, no en la raíz) |
| `metadata.size` | number | Bytes |
| `metadata.uploadedAt` | ISODate | Fecha de subida (aplicación) |

> **Corrección respecto a v1.0:** `contentType` no está en la raíz del documento de GridFS sino en
> `metadata.contentType`; se añaden `chunkSize`, `uploadDate` y el resto de `metadata`.

## 3. Catálogo canónico de Claim Topics (compartido on/off-chain)

> **Canónico y único (v1.1):** los tres topics oficiales del sistema son **1 = KYC**, **7 = Accreditation**
> y **9 = Jurisdiction**. Fuente: `rwa-web/README.md:325-327` y `rwa-web/web-token/types/token.ts:46-50`
> (`INVESTMENT_CLAIMS { KYC: 1, ACCREDITATION: 7, JURISDICTION: 9 }`).

### 3.1 Catálogo oficial (implementado)
| ID | Nombre | Uso | Evidencia |
|---|---|---|---|
| 1 | KYC | Inversión en token | `web-token/types/token.ts:47`; `README.md:325` |
| 7 | Accreditation | Inversor acreditado | `web-token/types/token.ts:48`; `README.md:326` |
| 9 | Jurisdiction | Cumplimiento geográfico | `web-token/types/token.ts:49`; `README.md:327` |

### 3.2 Reservados / backlog (NO implementados)
| ID | Nombre | Estado | Origen |
|---|---|---|---|
| 5 | Environmental | **Reservado (backlog, H-10)** — no exigido por ningún token | `INFORME_OPTIMIZACION_V1.md` H-10/R-2 |
| 6 | Sanctions | **Reservado (backlog, H-10)** — no exigido por ningún token | `INFORME_OPTIMIZACION_V1.md` H-10/R-2 |

> Estos dos IDs **no** están implementados ni configurados en el flujo real; solo se reservan para no
> colisionar con catálogos antiguos. Cualquier uso exige requisito y criterio de aceptación (R-2).

### 3.3 Catálogos antiguos divergentes — **DEPRECADOS (H-13)**
| Catálogo antiguo | Fuente | Estado |
|---|---|---|
| 1=KYC, 2=AML, 3=Accredited, 4=Tax | `rwa-sc/ARQUITECTURA_FINAL.md:65,244` | **Deprecado** |
| 1=KYC, 2=AML, 3=Accredited, 4=Country, 5=Identity Verification, 6=Tax Status, 7=Investor Type, 8=Risk Assessment, 9=Sanctions Check, 10=PEP | `rwa-sc/REFERENCIA_TECNICA.md:823-833` | **Deprecado** (contradice 9=Jurisdiction) |
| 5/6/7 con otros significados | `INFORME_OPTIMIZACION_V1.md:122` (H-13) | **Deprecado** |
| Fixtures de test: `KYC_TOPIC=1`, `AML_TOPIC=2` | `rwa-sc/sc/test/Token.t.sol:34-35` | **No canónico** (fixture de test) |
| Fixtures de test: 1, 2, 3 | `rwa-sc/sc/test/ClaimTopicsRegistryCloneFactory.t.sol:46-56` | **No canónico** (fixture de test) |
| Fixture de test: 2="Accreditation" | `rwa-sc/sc/test/IdentityCloneFactory.t.sol:184` | **No canónico** (contradice 7=Accreditation) |

> **Resolución H-13:** el valor **9 queda oficialmente como "Jurisdiction"** (nunca "Sanctions Check").
> Los tests usan fixtures legacy y no definen el catálogo; su alineación es parte de M-8 (backlog).
> La definición de los topics es **genérica en el contrato** (`uint256`), por lo que el catálogo es una
> convención de datos que debe residir en una única fuente versionada (M-8, §8 de `requerimientos.md`).

### 3.4 Signature schemes (contexto, no topics)
| ID | Esquema | Estado |
|---|---|---|
| 1 | ECDSA (comentado en `IdentityCloneable.sol:57`) | existe (documentado) |
| 2 | RSA (citado en `REFERENCIA_TECNICA.md:839`) | **Deprecado/no implementado** |

## 4. Estado de datos (pendientes de decisión)
- **DB:** MongoDB local (`rwa`) → destino GCP (Atlas / Cloud SQL PostgreSQL) — ver `requerimientos.md` §6 Q6.
  La decisión **no está tomada**; `base_datos.sql` es un borrador PostgreSQL (**no** ejecutable).
- **Custodia/privacidad (H-11):** las colecciones off-chain contienen PII y documentos KYC sin custodio,
  base legal, cifrado, retención ni borrado; on-chain `Claim.data`/`Claim.uri` son inmutables y los eventos
  `ClaimAdded(signature, data, uri)` son permanentes. **Backlog R-3.**
- **Escala (H-20):** arrays no acotados con borrado O(n) en `IdentityRegistry.registeredAddresses`,
  `TrustedIssuersRegistry.trustedIssuersList`, `ClaimTopicsRegistryCloneable.claimTopics` y
  `ComplianceAggregator.tokens`; vistas sin paginación. **Backlog M-11.**
- **Índices off-chain:** el código web **no** ejecuta `createIndex`; los filtros por `issuerAddress`/`status`
  se resuelven en consulta. Cualquier índice (p. ej. único por emisor) es **planificado**, no existente.

## 5. Cambios planificados por requisito (PLANIFICADO — no existe hoy)

> Todo lo de esta sección está **aprobado** (`requerimientos.md` §3, D-014) pero **no implementado**. No
> debe confundirse con el storage real de §1.

### RF-004 — Whitelist de destinos y límites (`TokenCloneable`)
| Campo planificado | Tipo | Descripción |
|---|---|---|
| `authorizedDestinations[address]` | mapping(address => bool) | Destinos autorizados para `burn`/`forcedTransfer` |
| `maxBurnPerTx` | uint256 | Tope por transacción de `burn()` |
| `maxForcedPerTx` | uint256 | Tope por transacción de `forcedTransfer()` |

### RF-011 — `isVerified` fail-closed (`TokenCloneable`) — **cambio de comportamiento, sin campos nuevos**
Hoy, si `claimTopicsRegistry == address(0)`, `isVerified()` devuelve `true` (`TokenCloneable.sol:245-247`).
RF-011 lo invierte a **`false`** (fail-closed). No introduce campos de storage; solo cambia la semántica.

### RF-012 — Registro explícito por token (`ComplianceAggregator`)
Hoy existe el mapping privado implícito `_isTokenRegistered` (`ComplianceAggregator.sol:38`) y
`canTransfer` devuelve `true` con cero módulos (`:123-125`, fail-open).
| Campo planificado | Tipo | Descripción |
|---|---|---|
| `tokenRegistered[token]` | mapping(address => bool) | Estado explícito de registro; sin registro o sin módulos ⇒ transferencia **denegada**; administración restringida al owner/COMPLIANCE del token |

### RF-013 — Vigencia y revocación de claims (`IdentityCloneable`)
| Campo planificado | Tipo | Descripción |
|---|---|---|
| `expiresAt` | uint256 (en struct `Claim`) | Marca temporal de caducidad |
| `revoked` | bool (en struct `Claim`) | Estado de revocación por el issuer autorizado |
| índice de revocación | p. ej. `mapping(uint256 => mapping(address => bool))` o lista de revocados | Consulta O(1) por `isVerified` |

### RF-001 — Firma EIP-712 (`IdentityCloneable`)
| Campo planificado | Tipo | Descripción |
|---|---|---|
| `schemeId` | uint256 (en struct `Claim`) | Identifica el dominio/tipo EIP-712 |
| digest EIP-712 | struct tipado + `ecrecover` | El `signature`/`data` actuales se validan contra wallet titular, `chainId` y `verifyingContract` |

## 6. Trazabilidad de esta revisión
| Defecto | Evidencia de corrección | Artefactos sincronizados |
|---|---|---|
| H-14 storage inexistente | §1 con `existe (ruta:línea)` | diccionario, diagrama, SQL |
| H-13 topics divergentes | §3 catálogo canónico + deprecados | diccionario, diagrama, SQL |
| H-08 / RF-013 | §5 (planificado) | diccionario, diagrama, SQL |
| H-11 PII/custodia | §2 y §4 | diccionario, diagrama, SQL |
| H-20 arrays O(n) | §1 y §4 | diccionario |
