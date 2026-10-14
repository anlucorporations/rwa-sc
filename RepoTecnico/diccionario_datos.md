# 🗂️ Diccionario de Datos — RWA

> **🔗 Artefacto de datos compartido — copia espejo sincronizada (2026-10-14).** Existe en las dos líneas
> de desarrollo: **canónico** `rwa-sc/RepoTecnico/diccionario_datos.md` · **espejo** `rwa-web/RepoTecnico/diccionario_datos.md`.
> Deben ser **idénticos byte a byte**: edita solo el canónico y ejecuta `rwa-web/RepoTecnico/check_sincronizacion_datos.sh --sync`
> (regla de sincronización en `rwa-web/RepoTecnico/ARTEFACTOS_DATOS_SINCRONIZADOS.md`).
>
> **Versión: v1.2 · 2026-10-14.** Fuente de verdad de datos del proyecto. Cubre el **modelo on-chain**
> (contratos, storage) y el **modelo off-chain** (PostgreSQL, esquema `rwa`).
>
> **Changelog v1.2 (2026-10-14):**
> - **D-095 (decisión del usuario — Q6 resuelta):** la BD off-chain del frontend es **PostgreSQL**
>   (Cloud SQL, PG 15+), **no MongoDB**. §2 se reescribe con el esquema real y ejecutable de
>   `base_datos.sql` v1.0.
> - **D-096:** la red on-chain canónica del frontend es el **Anvil de GCP (chain 31337)**.
> - **D-092/D-093:** se añaden `rwa.sessions` (SIWE) y `rwa.audit_log`; `document_files` sustituye al bucket
>   GridFS y guarda el contenido **cifrado AES-256-GCM**.
> - **Normalización:** `tokens.requiredClaims` → `token_required_claims` y `tokens.complianceModules` →
>   `token_compliance_modules`; `claim_topic` (string libre) → FK a `claim_topics` (H-13).
> - La transcripción fiel del sistema MongoDB sustituido se conserva como **Anexo A de `base_datos.sql`**
>   (referencia del ETL).
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
| `claims` | `mapping(uint256 => mapping(address => Claim))` private | PK lógica (topic+issuer) | existe (`IdentityCloneable.sol:26`) | Claim por topic y emisor |
| `topicIssuers` | `mapping(uint256 => address[])` private | — | existe (`IdentityCloneable.sol:29`) | Emisores con claim en el topic (índice) |
| `topicIssuerExists` | `mapping(uint256 => mapping(address => bool))` private | — | existe (`IdentityCloneable.sol:32`) | Índice de existencia de emisor por topic |
| `claimNonce` | `mapping(uint256 => mapping(address => uint256))` public | — | existe (`IdentityCloneable.sol:37`) | Nonce firmado por `(topic, issuer)`; lo incrementan `revokeClaim` (RF-013/D-050) y `removeClaim` (AF-12) |
| struct `Claim` | `{uint256 topic; uint256 scheme; address issuer; bytes signature; bytes data; string uri; uint256 expiresAt; bool revoked;}` | — | existe (`IdentityCloneable.sol:39-51`) | Incluye **`expiresAt`** y **`revoked`** (RF-013, D-038/D-046) |

> **H-14 corregido:** no existe `holders[]`, `holderIndex[]`, `firstReceiveTime` ni `issuerTopics` en este
> contrato. El índice de emisores se llama `topicIssuers` (array) + `topicIssuerExists` (mapping).
> **Actualizado (RF-013/AF-12):** el struct `Claim` ya no son 7 campos; añade `expiresAt` (vigencia, D-038)
> y `revoked` (revocación por el issuer, D-046), y existe el mapping `claimNonce` fuera del struct.

### Entidad: `IdentityRegistry` (compartido)
| Campo | Tipo | Clave | Estado | Descripción |
|---|---|---|---|---|
| `identities` | `mapping(address => IdentityCloneable)` private | PK (wallet) | existe (`IdentityRegistry.sol:14`) | Contrato Identity de cada wallet |
| `registered` | `mapping(address => bool)` private | — | existe (`IdentityRegistry.sol:17`) | Bandera de registro |
| `registeredAddresses` | `address[]` private | — | existe (`IdentityRegistry.sol:20`) | Enumeración de wallets registradas |
| `addressIndex` | `mapping(address => uint256)` private | — | existe (`IdentityRegistry.sol`) | **H-20:** índice 1-based en `registeredAddresses` (`0` = ausente); borrado O(1) |

> **H-20 corregido:** la pertenencia y el borrado ya **no** recorren el array; se usa `addressIndex`.
> El swap-and-pop se conserva, así que el array sigue sin huecos. Vista paginada
> `getRegisteredAddressesPaginated(offset, limit)`.

### Entidad: `TrustedIssuersRegistry` (compartido)
| Campo | Tipo | Clave | Estado | Descripción |
|---|---|---|---|---|
| `trustedIssuers` | `mapping(address => bool)` private | PK (issuer) | existe (`TrustedIssuersRegistry.sol:16`) | Si el emisor es confiable |
| `issuerClaimTopics` | `mapping(address => uint256[])` private | — | existe (`TrustedIssuersRegistry.sol:13`) | Topics autorizados por emisor (enumeración) |
| `trustedIssuersList` | `address[]` private | — | existe (`TrustedIssuersRegistry.sol:19`) | Enumeración de emisores |
| `issuerIndex` | `mapping(address => uint256)` private | — | existe (`TrustedIssuersRegistry.sol`) | **H-20:** índice 1-based; borrado O(1) |
| `issuerHasTopic` | `mapping(address => mapping(uint256 => bool))` private | PK lógica (issuer, topic) | existe (`TrustedIssuersRegistry.sol`) | **H-20:** pertenencia `(issuer, topic)` en O(1) |

> **H-20 corregido:** la autorización por topic ya **no** itera `issuerClaimTopics`; `hasClaimTopic()`
> consulta `issuerHasTopic[issuer][topic]` en O(1) (se mantiene sincronizado en alta/actualización/baja).
> Vista paginada `getTrustedIssuersPaginated(offset, limit)`.

### Entidad: `ClaimTopicsRegistryCloneable` (por token)
| Campo | Tipo | Clave | Estado | Descripción |
|---|---|---|---|---|
| `claimTopics` | `uint256[]` private | — | existe (`ClaimTopicsRegistryCloneable.sol:14`) | Topics requeridos por el token |
| `topicIndex` | `mapping(uint256 => uint256)` private | — | existe (`ClaimTopicsRegistryCloneable.sol`) | **H-20:** índice 1-based; borrado O(1) |
| `topicExistsFlag` | `mapping(uint256 => bool)` private | PK lógica (topic) | existe (`ClaimTopicsRegistryCloneable.sol`) | **H-20:** pertenencia O(1) que responde a `claimTopicExists()` |
| `claimTopicExists` | `function (uint256) public view returns (bool)` | — | existe (`ClaimTopicsRegistryCloneable.sol`) | **Es una función**, no un mapping; ahora lee `topicExistsFlag` (O(1)) |

> **H-14 corregido:** **no** existe el campo `token` en este registro (la relación token–registro se guarda
> en `TokenCloneable.claimTopicsRegistry`). **H-20:** `claimTopicExists` dejó de iterar `claimTopics` y usa
> `topicExistsFlag`; el borrado usa `topicIndex`. Vista paginada `getClaimTopicsPaginated(offset, limit)`.
> La variante no clonable `ClaimTopicsRegistry` tiene el mismo storage y las mismas vistas.

### Entidad: `TokenCloneable`
| Campo | Tipo | Clave | Estado | Descripción |
|---|---|---|---|---|
| `identityRegistry` | `IdentityRegistry` public | FK | existe (`TokenCloneable.sol:39`) | Registry de identidades |
| `trustedIssuersRegistry` | `TrustedIssuersRegistry` public | FK | existe (`TokenCloneable.sol:40`) | Registry de emisores |
| `claimTopicsRegistry` | `IClaimTopicsRegistry` public | FK | existe (`TokenCloneable.sol:41`) | Requirements de claims del token |
| `complianceModules` | `ICompliance[]` public | — | existe (`TokenCloneable.sol:44`) | Módulos activos directos (**AF-05:** array vacío ⇒ `canTransfer == false`) |
| `_tokenDecimals` | `uint8` private | — | existe (`TokenCloneable.sol:49`) | Decimales (lo usa `decimals()`) |
| `frozen` | `mapping(address => bool)` private | PK (account) | existe (`TokenCloneable.sol:60`) | Cuenta congelada |
| `authorizedDestinations` | `mapping(address => bool)` public | PK (account) | existe (`TokenCloneable.sol:66`) | Whitelist de destinos de `burn`/`forcedTransfer` (RF-004) |
| `maxBurnPerTx` | `uint256` public | — | existe (`TokenCloneable.sol:69`) | Tope de `burn` por transacción; `0` desactiva (RF-004) |
| `maxForcedPerTx` | `uint256` public | — | existe (`TokenCloneable.sol:72`) | Tope de `forcedTransfer`; `0` desactiva (RF-004) |
| `maxSupply` | `uint256` public | — | existe (`TokenCloneable.sol:75`) | Tope de suministro; `0` = sin tope (D-022) |
| `moduleIndex` | `mapping(address => uint256)` private | PK lógica (module) | existe (`TokenCloneable.sol`) | **H-20:** índice 1-based en `complianceModules`; pertenencia y borrado O(1) |
| roles `DEFAULT_ADMIN_ROLE`, `AGENT_ROLE`, `COMPLIANCE_ROLE` | `bytes32 public constant` | — | existe (`TokenCloneable.sol:35-36` + `AccessControlUpgradeable`) | `DEFAULT_ADMIN_ROLE` heredado de OZ |
| balances / allowances / totalSupply | ERC-20 | — | existe (`ERC20Upgradeable`) | State estándar ERC-20 |

> **H-14 corregido (TokenCloneable):** **no** existen `_tokenName` ni `_tokenSymbol` (storage muerto
> eliminado en D-070) ni el flag `bypassCompliance` (retirado en RF-002); en su lugar están los 4 campos
> de RF-004 (`authorizedDestinations`, `maxBurnPerTx`, `maxForcedPerTx`, `maxSupply`). El layout real
> (slots 0..10) se verifica con `forge inspect TokenCloneable storage-layout`.
> **H-20:** `moduleIndex` hace O(1) `_isComplianceModule` y el alta duplicada; vistas paginadas
> `getComplianceModulesPaginated` y borrado por dirección `removeComplianceModuleByAddress`.

### Entidad: `ComplianceAggregator`
| Campo | Tipo | Clave | Estado | Descripción |
|---|---|---|---|---|
| `tokenModules` | `mapping(address => ICompliance[])` private | FK (token) | existe (`ComplianceAggregator.sol:38`) | Módulos por token |
| `moduleIndex` | `mapping(address => mapping(address => uint256))` private | — | existe (`ComplianceAggregator.sol:41`) | Índice para borrado O(1) |
| `isModuleActive` | `mapping(address => mapping(address => bool))` private | — | existe (`ComplianceAggregator.sol:44`) | Estado del módulo |
| `tokens` | `address[]` private | — | existe (`ComplianceAggregator.sol:47`) | Índice de tokens que usan el aggregator |
| `_isTokenRegistered` | `mapping(address => bool)` private | PK lógica (token) | existe (`ComplianceAggregator.sol:50`) | Registro del token; **RF-012** ya lo usa fail-closed (0 módulos ⇒ denegar) |

### Módulos de compliance (state propio)
| Módulo | Campos | Estado |
|---|---|---|
| `MaxBalanceCompliance` | `maxBalance` (`MaxBalanceCompliance.sol:16`), `tokenContract` (`:19`) | existe |
| `MaxHoldersCompliance` | `maxHolders` (`MaxHoldersCompliance.sol:16`), `holderCount` (`:19`), `tokenContract` (`:22`), `isHolder` (`:25`), `authorizedCallers` (`:28`) | existe |
| `TransferLockCompliance` | `lockPeriod` (`TransferLockCompliance.sol:16`), `tokenContract` (`:19`), `lockEndTime` (`:22`), `authorizedCallers` (`:25`) | existe |

> **H-14 corregido (módulos):** el identificador del token es **`tokenContract`**, no `token`. En
> `MaxHoldersCompliance` el estado por cuenta es **`isHolder`** (mapping, **no** `holders[]` +
> `holderIndex[]`) y se añade **`holderCount`** (contador) y **`authorizedCallers`**. En> `TransferLockCompliance` el lock por cuenta es **`lockEndTime`** (**no** `firstReceiveTime`).

### Estado de eventos de compliance
Los tres módulos **sí** emiten `TokenContractSet(address indexed tokenContract)` al fijar `tokenContract`
(QW-8, cierra **H-34**). El resto de eventos son los documentados en cada `.sol`
(`MaxHoldersSet`, `HolderAdded`, `HolderRemoved`, `LockPeriodSet`, `TransferLocked`, `MaxBalanceSet`,
`ModuleAdded`, `ModuleRemoved`, `TokenRegistered`).

> **H-19:** `tokenContract` es **bind-once**: solo se puede fijar a un token (idempotente con el mismo;
> revert `"Module already bound to another token"` para otro). Así el estado por cuenta de
> `MaxHoldersCompliance` (`isHolder`/`holderCount`) y `TransferLockCompliance` (`lockEndTime`), que **no**
> está indexado por token, no se mezcla entre tokens.

## 2. Modelo off-chain (rwa-web → **PostgreSQL**, esquema `rwa`)

> **v1.2 — DECISIÓN DEL USUARIO (Q6 resuelta, D-095):** la BD off-chain del frontend es **PostgreSQL**
> (Cloud SQL, PG 15+), **no MongoDB**. La red on-chain canónica es el **Anvil de GCP (chain 31337)** (D-096).
> Este apartado describe el esquema **real y ejecutable** de `base_datos.sql` v1.0; los nombres y tipos son
> idénticos a los de ese script y a `diagrama_er.md` §2.
>
> **Migración documentada:** la transcripción fiel del sistema MongoDB sustituido (colecciones
> `claim_requests`, `tokens`, `issuers` y bucket GridFS `claim_documents`) se conserva como **Anexo A** de
> `base_datos.sql`, como fuente para el ETL.

### Tabla: `rwa.claim_topics` (catálogo canónico, H-13)
| Campo | Tipo | Clave | Descripción |
|---|---|---|---|
| `id` | smallint | PK | Código canónico: 1=KYC, 7=Accreditation, 9=Jurisdiction |
| `code` | text | UK | Identificador legible |
| `name` | text | — | Nombre |
| `description` | text | — | Descripción |
| `active` | boolean | — | `false` para reservados (5=Environmental, 6=Sanctions) |
| `created_at` | timestamptz | — | `default now()` |

### Tabla: `rwa.issuers`
| Campo | Tipo | Clave | Descripción |
|---|---|---|---|
| `id` | uuid | PK | `default gen_random_uuid()` |
| `address` | text | UK, CHECK `^0x[0-9a-f]{40}$` | Dirección del emisor (minúsculas) |
| `name` | text | CHECK no vacío | Nombre visible |
| `verified` | boolean | — | Caché del estado on-chain (`default false`) |
| `verified_at` | timestamptz | — | Fecha de verificación |
| `created_at` / `updated_at` | timestamptz | — | Triggers `set_updated_at()` |

> La autoridad real (quién es issuer y para qué topic) vive en `TrustedIssuersRegistry` on-chain; esta tabla
> **no concede permisos** (RF-W-12).

### Tabla: `rwa.claim_requests`
| Campo | Tipo | Clave | Descripción |
|---|---|---|---|
| `id` | uuid | PK | `default gen_random_uuid()` |
| `requester_address` | text | CHECK `0x…` | Wallet solicitante; índice con `created_at` |
| `issuer_address` | text | CHECK `0x…` | Emisor destinatario; índice con `status` |
| `claim_topic_id` | smallint | FK → `claim_topics.id` | Topic canónico (antes string libre) |
| `message` | text? | — | Mensaje del solicitante |
| `status` | `claim_request_status` | enum | `pending` (default) / `approved` / `rejected` |
| `signed_message` | text | — | Mensaje firmado por el solicitante |
| `signature` | text | — | Firma del solicitante (verificada en servidor, RF-W-04) |
| `review_note` | text? | — | Nota del emisor |
| `issuer_signed_message` | text? | — | Mensaje firmado por el emisor |
| `issuer_signature` | text? | — | Firma del emisor (verificada en servidor, RF-W-03) |
| `reviewed_by` | text? | — | **Nuevo (HW-01):** dirección derivada de la firma del revisor |
| `reviewed_at` | timestamptz? | — | Fecha de revisión |
| `created_at` / `updated_at` | timestamptz | — | Timestamps |

> **CHECK `claim_requests_review_consistency`:** si `status <> 'pending'`, entonces `reviewed_at`,
> `issuer_signature` y `reviewed_by` son obligatorios; si `status = 'pending'`, los tres son `NULL`.
> Hace **imposible** una aprobación sin trazabilidad (HW-01).

### Tabla: `rwa.document_files` (sustituye a GridFS `claim_documents`)
| Campo | Tipo | Clave | Descripción |
|---|---|---|---|
| `id` | uuid | PK | Identificador del documento |
| `claim_request_id` | uuid | FK → `claim_requests.id` ON DELETE CASCADE | Solicitud propietaria (autorización por propiedad) |
| `original_name` | text | — | Nombre original |
| `content_type` | text | CHECK allowlist | PDF, JPEG, PNG, DOC, DOCX |
| `size_bytes` | bigint | CHECK `0 < n ≤ 10485760` | Tamaño (máx. 10 MB) |
| `sha256` | bytea | — | Hash del contenido en claro (integridad) |
| `content` | bytea | — | Contenido **cifrado AES-256-GCM** (D-093) |
| `encryption_algo` | text | — | `AES-256-GCM` (default) |
| `encryption_nonce` | bytea? | — | Nonce del cifrado |
| `uploaded_by` | text | CHECK `0x…` | Wallet que subió el documento |
| `created_at` | timestamptz | — | Fecha de subida |

### Tabla: `rwa.tokens`
| Campo | Tipo | Clave | Descripción |
|---|---|---|---|
| `id` | uuid | PK | Identificador |
| `token_address` | text | UK, CHECK `0x…` | Dirección on-chain |
| `admin_address` | text | CHECK `0x…` | Admin del token |
| `name` / `symbol` | text | CHECK `symbol ^[A-Z0-9]{1,11}$` | Metadatos |
| `decimals` | smallint | CHECK 0–18 | Decimales |
| `max_total_supply` / `total_supply` | numeric(78,0)? | — | Suministro |
| `identity_registry` / `trusted_issuers_registry` / `claim_topics_registry` | text | **NOT NULL** (CHECK) | Los tres registries son obligatorios (RF-W-11 / D-084) |
| `compliance_address` | text? | — | Módulo principal (compatibilidad) |
| `price` | numeric(38,18)? | CHECK ≥ 0 | Precio |
| `description` | text? | — | Descripción |
| `transaction_hash` / `block_number` | text? / bigint? | — | Traza del despliegue |
| `created_at` / `updated_at` | timestamptz | — | Timestamps |

> `requiredClaims` y `complianceModules` **se normalizan** en dos tablas puente (abajo); ya no son arrays.

### Tablas puente: `rwa.token_required_claims` y `rwa.token_compliance_modules`
| Tabla | Campos | Clave |
|---|---|---|
| `token_required_claims` | `token_id` (FK tokens, CASCADE), `claim_topic_id` (FK claim_topics, RESTRICT), `created_at` | PK (`token_id`,`claim_topic_id`) |
| `token_compliance_modules` | `token_id` (FK tokens, CASCADE), `module_address` (CHECK `0x…`), `is_primary` (bool), `created_at` | PK (`token_id`,`module_address`) |

### Tabla: `rwa.sessions` (nueva, SIWE — D-092)
| Campo | Tipo | Clave | Descripción |
|---|---|---|---|
| `id` | uuid | PK | Id de sesión (transportado en cookie `httpOnly` firmada) |
| `address` | text | CHECK `0x…` | Wallet autenticada |
| `nonce` | text | UK | Nonce SIWE de un solo uso |
| `role` | `session_role` | enum | `investor` / `issuer` / `admin` |
| `issued_at` | timestamptz | — | Emisión |
| `expires_at` | timestamptz | CHECK > `issued_at` | Caducidad |
| `revoked_at` | timestamptz? | — | Revocación inmediata |
| `user_agent` / `ip` | text? / inet? | — | Contexto de la sesión |

### Tabla: `rwa.audit_log` (nueva — RNF-W-02)
| Campo | Tipo | Clave | Descripción |
|---|---|---|---|
| `id` | bigserial | PK | Secuencia |
| `actor_address` | text? | — | Quién |
| `action` | text | — | Qué acción |
| `resource_type` / `resource_id` | text / text? | — | Sobre qué recurso |
| `request_id` | text? | — | Correlación con el log estructurado (RT-W-10) |
| `detail` | jsonb? | — | Detalle |
| `at` | timestamptz | — | `default now()` |

### Tabla: `rwa.schema_migrations`
| Campo | Tipo | Clave | Descripción |
|---|---|---|---|
| `version` | text | PK | Versión aplicada (p. ej. `1.0`) |
| `applied_at` | timestamptz | — | `default now()` |

### Vista: `rwa.v_claim_request_summary`
Solicitud + `issuer_name` + `claim_topic_name` + `document_count` (lectura del panel de emisor).

### Índices obligatorios (idénticos a `base_datos.sql` §6)
`claim_requests (requester_address, created_at DESC)` · `(issuer_address, status, created_at DESC)` ·
`(status, created_at DESC)` · `(claim_topic_id)` · `document_files (claim_request_id)` · `(sha256)` ·
`tokens (admin_address, created_at DESC)` · `(block_number)` · `sessions (address, expires_at DESC)` ·
`(expires_at) WHERE revoked_at IS NULL` · `audit_log (actor_address, at DESC)` ·
`(resource_type, resource_id, at DESC)` · `(request_id)`.

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

## 4. Estado de datos (decisiones)
- **DB (Q6 RESUELTA — D-095):** la BD off-chain del frontend es **PostgreSQL** (Cloud SQL, PG 15+) y su
  esquema real está en `base_datos.sql` v1.0 (esquema `rwa`, ejecutable). El sistema MongoDB anterior se
  sustituye; su transcripción queda como Anexo A de ese script para el ETL.
- **Red on-chain (D-096):** **Anvil de GCP** (`MCC_ANVIL_RPC_URL`, chain 31337) es la red canónica del
  frontend; Besu 81234 queda como alternativa documentada y no canónica.
- **Custodia/privacidad (H-11 → D-093):** en la etapa web se resuelve con `document_files` cifrado
  (AES-256-GCM) y `audit_log` de accesos; la política formal de base legal, retención y supresión sigue
  pendiente como backlog R-3 (fuera del alcance de D-088).
- **Escala (H-20):** arrays no acotados con borrado O(n) en `IdentityRegistry.registeredAddresses`,
  `TrustedIssuersRegistry.trustedIssuersList`, `ClaimTopicsRegistryCloneable.claimTopics` y
  `ComplianceAggregator.tokens`; vistas sin paginación. **Backlog M-11.**
- **Índices off-chain:** definidos y ejecutables en `base_datos.sql` §6 y listados en §2 (los 12 índices
  obligatorios). En el sistema MongoDB anterior **no existía ninguno** (`grep createIndex` sin resultados).

## 5. Cambios on-chain por requisito (IMPLEMENTADOS en Fase 3 — referencia histórica)

> **Nota v1.2:** esta sección se redactó en v1.1 como *planificado*. La Fase 3 los **implementó y verificó**
> (394/394 tests, cobertura `src/` 97,05 %): RF-001 EIP-712 (Ciclo 2, D-020/D-083/D-084), RF-002 retirada del
> flag de bypass y anti-reentrancia (Ciclo 3), RF-004 whitelist y límites (D-006/D-078), RF-011 fail-closed
> (Ciclo 6), RF-012 registro explícito por token, RF-013 vigencia/revocación de claims. Se conserva el detalle
> como **referencia histórica**; el estado real y las decisiones están en `estado_proyecto.md`.
> El alcance de la presente etapa es **solo frontend** (D-088): el storage on-chain no se modifica.

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
