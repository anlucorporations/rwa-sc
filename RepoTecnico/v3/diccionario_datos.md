# Diccionario de datos — RWA v3 «Barlo Metaplace»

> **Versión:** v3.2 (esquema 3.0) · **Fecha:** 2026-11-04 · **Motor:** PostgreSQL 15 (Cloud SQL `truekeate-db-dev`) · **Esquema:** `rwa`
> **Sincronía obligatoria:** este documento, `diagrama_er.md` y `base_datos.sql` se actualizan **juntos**.
> **Estado:** Fase 1 **en corrección** (re-auditoría v3.2: NO cerrada). Decisiones Q1–Q13 aplicadas.

**Reglas de nombres:** `snake_case`; tablas en plural; PK `id`; FK `<tabla_singular>_id`; marcas de tiempo
`created_at` / `updated_at`; importes monetarios en `numeric(20,8)` (BRLT tiene 8 decimales);
direcciones de wallet en `text` (minúsculas, validadas por `CHECK` con regex).

**Decisiones reflejadas:** Q1 sustitución sobre la misma infraestructura · Q2 BRLT sin valor real ·
Q3 marketplace a precio fijo con escrow/comisión · Q4 comisión 5 % + fee de tokenización (`platform_fees`) ·
Q5 non-custodial con recuperación asistida · Q6 catálogo solo BRLT + RWA · Q7 jurisdicciones LatAm/piloto ·
Q8 claims sin caducidad en v3.0 (columna `expires_at` preparada, `NULL`) · Q9 tasación documental con tope
de precio · Q10 retención 30 días (rechazo) / 12 meses (fin de relación).

---

## 1. Dominio: catálogos y configuración

### 1.1 `jurisdictions` — países soportados (Q7)

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `smallint` | no | — | PK | Identificador interno |
| `iso2` | `char(2)` | no | — | UK | Código ISO-3166-1 alfa-2 |
| `name` | `text` | no | — | — | Nombre del país |
| `enabled` | `boolean` | no | `true` | — | Habilitado para operar (el Admin lo cambia sin redeploy) |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |

> Semilla: `VE`, `CO`, `PA`, `MX`, `CL`, `PE`, `AR` habilitados (piloto LatAm). Añadir países = `INSERT`.

### 1.2 `credential_types` — catálogo extensible de claims

Sustituye al enum fijo de v2 (`claim_topics`). Un tipo de credencial puede o no estar anclado on-chain.

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `smallint` | no | — | PK | Identificador |
| `code` | `text` | no | — | UK | Código estable: `SOCIO`, `GARANTIA`, `FIADOR`, `KYC`, `JURISDICCION`, `ACREDITACION` |
| `name` | `text` | no | — | — | Nombre visible |
| `description` | `text` | sí | — | — | Qué acredita |
| `on_chain_topic` | `smallint` | sí | — | UK | Topic numérico del registry on-chain (`NULL` si no va on-chain) |
| `validity_days` | `integer` | sí | — | — | Vigencia; `NULL` = sin caducidad (decisión Q8 para v3.0) |
| `active` | `boolean` | no | `true` | — | Disponible para nuevos ISSUER |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |

> Semilla: `KYC`(1), `ACREDITACION`(7), `JURISDICCION`(9) heredados de v2; `SOCIO`(10), `GARANTIA`(11),
> `FIADOR`(12) nuevos.

### 1.3 `platform_fees` — comisiones (Q4)

Configuración única (singleton).

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `smallint` | no | `1` | PK | Singleton (`CHECK id = 1`) |
| `sale_fee_bps` | `smallint` | no | `500` | — | Comisión por venta en puntos base (500 = 5 %) |
| `tokenization_fee_brlt` | `numeric(20,8)` | no | `50.00000000` | — | Fee fijo por tokenización, en BRLT |
| `active` | `boolean` | no | `true` | — | Vigente |
| `updated_at` | `timestamptz` | no | `now()` | — | Última modificación |

### 1.4 `wallet_messages` — plantillas de firma en lenguaje llano

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identificador |
| `process_key` | `text` | no | — | UK* | Proceso: `identity.create`, `claim.request`, `claim.issue`, `asset.tokenize`, `order.buy`, `service.consume`, `identity.recovery` |
| `locale` | `text` | no | `'es'` | UK* | Idioma (`es`, `en`) |
| `title` | `text` | no | — | — | Título corto mostrado en la billetera |
| `template` | `text` | no | — | — | Texto con variables `{…}` |
| `variables` | `jsonb` | no | `'[]'` | — | Lista de variables esperadas |
| `version` | `integer` | no | `1` | UK* | Versión de la plantilla |
| `active` | `boolean` | no | `true` | — | Vigente |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |

> UK* = `UNIQUE (process_key, locale, version)`. La app selecciona la versión activa más alta.

---

## 2. Dominio: ISSUER y certificaciones

### 2.1 `issuer_programs` — ISSUER (plantilla de certificación)

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identificador |
| `slug` | `text` | no | — | UK | Identificador legible (`onboarding-socio`, `garantia-activos`, …) |
| `name` | `text` | no | — | — | Nombre visible |
| `description` | `text` | sí | — | — | Proceso explicado al usuario |
| `activity_kind` | `rwa.asset_kind` | sí | — | — | Tipo de actividad que habilita (`NULL` = solo certificación) |
| `active` | `boolean` | no | `true` | — | Disponible para solicitudes |
| `created_by` | `text` | no | — | — | Wallet del Admin que lo creó |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |
| `updated_at` | `timestamptz` | no | `now()` | — | Modificación |

### 2.2 `issuer_program_requirements` — requisitos de un ISSUER

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identificador |
| `issuer_program_id` | `uuid` | no | — | FK → `issuer_programs` (CASCADE) | ISSUER |
| `kind` | `rwa.requirement_kind` | no | — | — | `document` (PDF/PNG) o `credential` (claim previo) |
| `label` | `text` | no | — | — | Texto que ve el usuario |
| `credential_type_id` | `smallint` | sí | — | FK → `credential_types` | Obligatorio si `kind = credential` |
| `mime_allowlist` | `text[]` | sí | `'{application/pdf,image/png,image/jpeg}'` | — | Formatos aceptados para documentos |
| `required` | `boolean` | no | `true` | — | Si es obligatorio |
| `sort_order` | `smallint` | no | `0` | — | Orden de presentación |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |

> `CHECK`: `kind = 'credential'` ⇒ `credential_type_id` NOT NULL.

### 2.3 `issuer_program_credentials` — claims que emite un ISSUER (N:M)

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `issuer_program_id` | `uuid` | no | — | PK/FK → `issuer_programs` (CASCADE) | ISSUER |
| `credential_type_id` | `smallint` | no | — | PK/FK → `credential_types` | Tipo de credencial que puede emitir |
| `mandatory` | `boolean` | no | `true` | — | Si se emite al aprobar por defecto |

### 2.4 `issuers` — emisores on-chain (caché verificada)

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identificador |
| `address` | `text` | no | — | UK | Dirección del emisor autorizado on-chain |
| `display_name` | `text` | sí | — | — | Nombre visible (solo el propio emisor o un Admin) |
| `issuer_program_id` | `uuid` | sí | — | FK → `issuer_programs` (SET NULL) | ISSUER al que pertenece |
| `verified_at` | `timestamptz` | sí | — | — | Última verificación contra `TrustedIssuersRegistry` |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |

### 2.5 `identities` — identidad del usuario en el Metaplace

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identidad interna (seudónimo público) |
| `wallet_address` | `text` | no | — | UK | Wallet de la que el usuario es titular (nunca se muestra en el Metaplace) |
| `display_alias` | `text` | no | — | UK | Alias público visible |
| `status` | `text` | no | `'active'` | — | `active`, `suspended`, `recovering` (`CHECK`) |
| `kyc_level` | `smallint` | no | `0` | — | 0 = sin KYC, 1 = KYC base, 2 = KYC avanzado (Socio) |
| `ended_at` | `timestamptz` | sí | — | — | Fin de relación; dispara la retención Q10 (+12 meses) de sus documentos |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |
| `updated_at` | `timestamptz` | no | `now()` | — | Modificación |

### 2.6 `claim_requests` — solicitud y emisión de un claim

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identificador |
| `identity_id` | `uuid` | no | — | FK → `identities` (CASCADE) | Solicitante |
| `issuer_program_id` | `uuid` | no | — | FK → `issuer_programs` (RESTRICT) | ISSUER bajo el que se solicita |
| `credential_type_id` | `smallint` | no | — | FK → `credential_types` | Claim solicitado |
| `issuer_id` | `uuid` | sí | — | FK → `issuers` | **Emisor concreto** que firma el claim (H-02; obligatorio al aprobar) |
| `status` | `rwa.claim_status` | no | `'pending'` | — | `pending`, `documents_verified`, `in_review`, `approved`, `rejected`, `revoked` |
| `requester_wallet` | `text` | no | — | — | Wallet que firma la solicitud |
| `requester_signature` | `text` | sí | — | — | Firma EIP-712 de la solicitud |
| `verified_by_wallet` | `text` | sí | — | — | Wallet del **Operador** que verifica documentos (H-09) |
| `verified_at` | `timestamptz` | sí | — | — | Fecha de la verificación documental |
| `reviewed_by_wallet` | `text` | sí | — | — | Wallet del **Admin** que aprueba y emite (H-09) |
| `reviewed_at` | `timestamptz` | sí | — | — | Fecha de resolución |
| `issuer_signature` | `text` | sí | — | — | Firma EIP-712 del emisor sobre el claim emitido |
| `tx_hash` | `text` | sí | — | — | Transacción on-chain del `addClaim` |
| `expires_at` | `timestamptz` | sí | — | — | Caducidad; `NULL` en v3.0 (Q8) |
| `revoked_at` | `timestamptz` | sí | — | — | Revocación |
| `revocation_reason` | `text` | sí | — | — | Motivo de revocación |
| `metadata` | `jsonb` | no | `'{}'` | — | Datos del formulario |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |
| `updated_at` | `timestamptz` | no | `now()` | — | Modificación |

> `CHECK` de consistencia: si `status = 'approved'` ⇒ `verified_by_wallet`, `verified_at`,
> `reviewed_by_wallet`, `reviewed_at`, `issuer_signature` e `issuer_id` NOT NULL.
> `CHECK`: si `status = 'revoked'` ⇒ `revoked_at` NOT NULL.
> **Anti-autoaprobación:** `reviewed_by_wallet <> requester_wallet`.
> **Segregación de funciones:** `verified_by_wallet <> reviewed_by_wallet` (H-09).
> Índices únicos parciales: una solicitud `pending` y un claim `approved` por
> (`identity_id`, `credential_type_id`).

### 2.7 `document_files` — documentos KYC cifrados

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identificador |
| `claim_request_id` | `uuid` | no | — | FK → `claim_requests` (CASCADE) | Solicitud asociada |
| `label` | `text` | no | — | — | Etiqueta del requisito |
| `mime_type` | `text` | no | — | — | Validado por allowlist (no por `file.type`) |
| `size_bytes` | `integer` | no | — | — | Tamaño (0 < n ≤ 20 MB) |
| `sha256` | `char(64)` | no | — | — | Huella del contenido original |
| `encrypted_data` | `bytea` | no | — | — | Contenido AES-256-GCM |
| `encryption_meta` | `jsonb` | no | `'{}'` | — | IV, tag y versión de clave |
| `retention_delete_at` | `date` | sí | — | — | Borrado programado (Q10: 30 días si rechazo; 12 meses si fin de relación) |
| `deleted_at` | `timestamptz` | sí | — | — | Borrado lógico/efectivo |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |

### 2.8 `identity_recovery_requests` — recuperación asistida (Q5)

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identificador |
| `identity_id` | `uuid` | no | — | FK → `identities` (CASCADE) | Identidad a recuperar |
| `old_wallet` | `text` | no | — | — | Wallet perdida/comprometida |
| `new_wallet` | `text` | no | — | — | Wallet nueva propuesta |
| `status` | `rwa.recovery_status` | no | `'requested'` | — | `requested`, `in_review`, `approved`, `rejected`, `completed` |
| `requested_by_wallet` | `text` | no | — | — | Wallet que solicita la recuperación |
| `evidence_document_id` | `uuid` | sí | — | FK → `document_files` (SET NULL) | Evidencia del caso (obligatoria al aprobar) |
| `approved_by_wallet` | `text` | sí | — | — | Primer aprobador (Admin) |
| `second_approval_wallet` | `text` | sí | — | — | Segundo aprobador (doble aprobación obligatoria) |
| `approved_at` | `timestamptz` | sí | — | — | Aprobación |
| `rejected_reason` | `text` | sí | — | — | Motivo de rechazo |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |
| `updated_at` | `timestamptz` | no | `now()` | — | Modificación |

> `CHECK`: `status IN ('approved','completed')` ⇒ `approved_by_wallet`, `second_approval_wallet`
> y `evidence_document_id` NOT NULL.
> **4-eyes real (H-08):** `approved_by_wallet <> second_approval_wallet` y ninguno de los dos es
> `requested_by_wallet`.

---

## 3. Dominio: activos tokenizados

### 3.1 `tokens` — registro off-chain del activo tokenizado

Sustituye y generaliza el `tokens` de v2: ahora un registro cubre productos (ERC-1155/ERC-20),
servicios (ERC-721 quemable) y bienes (ERC-721 único).

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identificador |
| `issuer_program_id` | `uuid` | no | — | FK → `issuer_programs` (RESTRICT) | ISSUER que autoriza la tokenización |
| `token_address` | `text` | no | — | UK | Contrato del activo |
| `on_chain_token_id` | `numeric(78,0)` | sí | — | — | `tokenId` en ERC-721/1155 (`NULL` en ERC-20) |
| `asset_kind` | `rwa.asset_kind` | no | — | — | `product`, `service`, `good` |
| `standard` | `rwa.asset_standard` | no | — | — | `erc20`, `erc721`, `erc1155` |
| `name` | `text` | no | — | — | Nombre del activo |
| `symbol` | `text` | sí | — | — | Símbolo (si aplica) |
| `decimals` | `smallint` | sí | — | — | Decimales (solo ERC-20) |
| `total_supply` | `numeric(30,8)` | sí | — | — | Cantidad acuñada |
| `unit` | `text` | sí | — | — | Unidad (unidad, servicio, lote, bien) |
| `price_brlt` | `numeric(20,8)` | sí | — | — | Precio unitario en BRLT |
| `valued_brlt` | `numeric(20,8)` | sí | — | — | Valor de tasación en BRLT (Q9) |
| `metadata_uri` | `text` | sí | — | — | Metadatos del NFT/activo |
| `status` | `rwa.asset_status` | no | `'draft'` | — | `draft`, `certifying`, `minted`, `listed`, `sold_out`, `paused` |
| `minted_tx_hash` | `text` | sí | — | — | Transacción de acuñación |
| `created_by` | `text` | no | — | — | Wallet del Admin/emisor que lo registra |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |
| `updated_at` | `timestamptz` | no | `now()` | — | Modificación |

> `CHECK` Q9: `valued_brlt IS NULL OR price_brlt IS NULL OR price_brlt <= valued_brlt`.
> `CHECK`: `asset_kind = 'good'` ⇒ `on_chain_token_id` NOT NULL; `asset_kind = 'service'` ⇒ `standard = 'erc721'`.

### 3.2 `token_required_claims`

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `token_id` | `uuid` | no | — | PK/FK → `tokens` (CASCADE) | Activo |
| `credential_type_id` | `smallint` | no | — | PK/FK → `credential_types` | Claim exigido para operar |

### 3.3 `token_compliance_modules`

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `token_id` | `uuid` | no | — | PK/FK → `tokens` (CASCADE) | Activo |
| `module_address` | `text` | no | — | PK | Dirección del módulo de compliance |
| `module_kind` | `text` | sí | — | — | `max_balance`, `max_holders`, `transfer_lock`, … |

### 3.4 `token_guarantees` — Garantía y Fiador (Q: RF-V3-14)

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identificador |
| `token_id` | `uuid` | no | — | FK → `tokens` (CASCADE) | Activo |
| `kind` | `rwa.guarantee_kind` | no | — | UK* | `garantia` o `fiador` |
| `identity_id` | `uuid` | sí | — | FK → `identities` (SET NULL) | Fiador (obligatorio si `kind = 'fiador'`) |
| `claim_request_id` | `uuid` | **no** | — | FK → `claim_requests` (RESTRICT) | Claim aprobado que respalda (H-06) |
| `verified` | `boolean` | no | `false` | — | Validado on-chain/off-chain |
| `verified_at` | `timestamptz` | sí | — | — | Fecha de validación (obligatoria si `verified`) |
| `validated_by_wallet` | `text` | sí | — | — | Quién validó la garantía |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |

> UK* = `UNIQUE (token_id, kind)`; `CHECK`: `kind = 'fiador'` ⇒ `identity_id` NOT NULL;
> `verified` ⇒ `verified_at` + `validated_by_wallet` NOT NULL.
> Trigger `trg_validate_token_guarantee`: solo se verifica con un claim **aprobado y vigente** del
> tipo correcto (`GARANTIA`/`FIADOR`) y el fiador no puede ser el creador del activo.

### 3.5 `asset_documents` — documentos del activo

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identificador |
| `token_id` | `uuid` | no | — | FK → `tokens` (CASCADE) | Activo |
| `doc_kind` | `rwa.asset_doc_kind` | no | — | — | `tenencia`, `garantia`, `tasacion`, `ficha_tecnica`, `otro` |
| `mime_type` | `text` | no | — | — | Allowlist PDF/PNG/JPEG |
| `size_bytes` | `integer` | no | — | — | Tamaño |
| `sha256` | `char(64)` | no | — | — | Huella |
| `encrypted_data` | `bytea` | no | — | — | AES-256-GCM |
| `encryption_meta` | `jsonb` | no | `'{}'` | — | IV, tag, versión de clave |
| `retention_delete_at` | `date` | sí | — | — | Retención Q10 aplicada también a documentos de activo (B7) |
| `deleted_at` | `timestamptz` | sí | — | — | Borrado lógico/purga |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |

---

## 4. Dominio: Metaplace (mercado y pagos)

### 4.1 `listings` — publicación a precio fijo (Q3)

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identificador |
| `token_id` | `uuid` | no | — | FK → `tokens` (CASCADE) | Activo publicado |
| `seller_identity_id` | `uuid` | no | — | FK → `identities` (RESTRICT) | Vendedor |
| `price_brlt` | `numeric(20,8)` | no | — | — | Precio (CHECK > 0) |
| `quantity` | `numeric(30,8)` | no | `1` | — | Unidades ofrecidas |
| `remaining_quantity` | `numeric(30,8)` | no | `1` | — | Remanente; lo decrementa el trigger al confirmar la orden (H-05) |
| `currency` | `text` | no | `'BRLT'` | — | Moneda de pago (CHECK = 'BRLT' en v3.0) |
| `status` | `text` | no | `'active'` | — | `active`, `paused`, `sold`, `cancelled` (`CHECK`) |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |
| `updated_at` | `timestamptz` | no | `now()` | — | Modificación |
| `closed_at` | `timestamptz` | sí | — | — | Cierre |

### 4.2 `orders`

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identificador |
| `listing_id` | `uuid` | no | — | FK → `listings` (RESTRICT) | Publicación |
| `buyer_identity_id` | `uuid` | no | — | FK → `identities` (RESTRICT) | Comprador |
| `seller_identity_id` | `uuid` | no | — | FK → `identities` (RESTRICT) | Vendedor |
| `quantity` | `numeric(30,8)` | no | `1` | — | Unidades compradas (H-05) |
| `price_brlt` | `numeric(20,8)` | no | — | — | Precio pactado |
| `fee_brlt` | `numeric(20,8)` | no | `0` | — | Comisión calculada |
| `status` | `rwa.order_status` | no | `'pending_payment'` | — | `pending_payment`, `escrowed`, `confirmed`, `cancelled`, `disputed`, `refunded` |
| `escrow_tx_hash` | `text` | sí | — | UK* | Depósito de BRLT en escrow (formato `0x`+64 hex) |
| `escrow_asset_tx_hash` | `text` | sí | — | — | **Tramo NFT** del escrow: transferencia del activo (B3) |
| `asset_transferred_at` | `timestamptz` | sí | — | — | Momento en que el activo quedó transferido |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |
| `updated_at` | `timestamptz` | no | `now()` | — | Modificación (requerido por el trigger global) |
| `expires_at` | `timestamptz` | sí | — | — | TTL de la reserva (30 min si no se indica) |
| `confirmed_at` | `timestamptz` | sí | — | — | Confirmación de recepción |
| `cancelled_at` | `timestamptz` | sí | — | — | Cancelación |

### 4.3 `payments`

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identificador |
| `order_id` | `uuid` | sí | — | FK → `orders` (SET NULL) | Orden (NULL en fee de tokenización) |
| `payer_identity_id` | `uuid` | sí | — | FK → `identities` (SET NULL) | Pagador |
| `payee_wallet` | `text` | no | — | — | Beneficiario |
| `kind` | `rwa.payment_kind` | no | — | — | `sale`, `tokenization_fee`, `refund` |
| `amount_brlt` | `numeric(20,8)` | no | — | — | Importe |
| `fee_brlt` | `numeric(20,8)` | no | `0` | — | Comisión de plataforma |
| `status` | `rwa.payment_status` | no | `'pending'` | — | `pending`, `settled`, `failed`, `refunded` |
| `tx_hash` | `text` | sí | — | UK* | Transacción BRLT (formato `0x`+64 hex, idempotente) |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |

> *`UNIQUE` parcial: `orders.escrow_tx_hash` y `payments.tx_hash` no nulos son únicos (H-05).
> Una sola orden abierta (`pending_payment`/`escrowed`) por publicación.

### 4.4 `disputes` — disputas de órdenes (H-05)

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identificador |
| `order_id` | `uuid` | no | — | UK/FK → `orders` (CASCADE) | Orden en disputa |
| `opened_by_identity_id` | `uuid` | no | — | FK → `identities` (RESTRICT) | Quién la abre |
| `reason` | `text` | no | — | — | Motivo |
| `status` | `rwa.dispute_status` | no | `'open'` | — | `open`, `in_review`, `resolved_buyer`, `resolved_seller`, `rejected` |
| `arbiter_wallet` | `text` | sí | — | — | Árbitro que resuelve |
| `resolution` | `text` | sí | — | — | Resolución |
| `opened_at` | `timestamptz` | no | `now()` | — | Apertura |
| `resolved_at` | `timestamptz` | sí | — | — | Resolución |

> `CHECK`: resuelta ⇒ `arbiter_wallet`, `resolution` y `resolved_at` NOT NULL.

---

## 5. Dominio: operación, sesiones y auditoría

### 5.1 `sessions` — sesiones SIWE

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identificador |
| `nonce` | `text` | no | — | UK | Nonce de un solo uso |
| `wallet_address` | `text` | no | — | — | Wallet autenticada |
| `role` | `rwa.session_role` | no | `'investor'` | — | `visitor`, `investor`, `issuer`, `operator`, `admin`, `auditor`, `arbiter`, `support` |
| `domain` | `text` | no | — | — | Dominio validado (EIP-4361) |
| `issued_at` | `timestamptz` | no | `now()` | — | Emisión |
| `expires_at` | `timestamptz` | no | — | — | Caducidad |
| `revoked_at` | `timestamptz` | sí | — | — | Cierre de sesión |

### 5.2 `audit_log`

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `bigserial` | no | — | PK | Secuencia |
| `actor_wallet` | `text` | sí | — | — | Actor (NULL = sistema) |
| `actor_role` | `text` | sí | — | — | Rol en el momento |
| `action` | `text` | no | — | — | Acción (`claim.approve`, `document.download`, `order.confirm`, …) |
| `resource_type` | `text` | no | — | — | Tipo de recurso |
| `resource_id` | `text` | sí | — | — | Identificador del recurso |
| `request_id` | `text` | sí | — | — | Correlación de logs |
| `ip` | `inet` | sí | — | — | IP de origen |
| `metadata` | `jsonb` | no | `'{}'` | — | Detalle |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |

### 5.3 `chain_events` — eventos on-chain indexados

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `bigserial` | no | — | PK | Secuencia |
| `chain_id` | `bigint` | no | — | UK* | Cadena del evento (detección de reset/reorg, H-13) |
| `block_number` | `bigint` | no | — | — | Bloque |
| `block_hash` | `text` | no | — | — | Hash del bloque (formato `0x`+64 hex) |
| `parent_hash` | `text` | sí | — | — | Hash del padre (reorg) |
| `tx_hash` | `text` | no | — | UK* | Transacción |
| `log_index` | `integer` | no | — | UK* | Índice del log |
| `event_name` | `text` | no | — | — | Nombre del evento |
| `contract_address` | `text` | no | — | — | Contrato emisor |
| `payload` | `jsonb` | no | `'{}'` | — | Argumentos decodificados |
| `removed` | `boolean` | no | `false` | — | Evento revertido por reorg |
| `created_at` | `timestamptz` | no | `now()` | — | Alta |

> UK* = `UNIQUE (chain_id, tx_hash, log_index)`.

### 5.4 `indexer_state`

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `smallint` | no | `1` | PK | Singleton (`CHECK id = 1`) |
| `chain_id` | `bigint` | no | `31337` | — | Cadena indexada |
| `last_block` | `bigint` | no | `0` | — | Último bloque procesado |
| `last_block_hash` | `text` | sí | — | — | Hash del último bloque (detección de reorg, H-13) |
| `updated_at` | `timestamptz` | no | `now()` | — | Actualización |

### 5.5 `schema_migrations`

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `version` | `text` | no | — | PK | Versión (`1.0`, `1.1`, `1.2` heredadas de v2; `3.0` canónica) |
| `description` | `text` | sí | — | — | Detalle |
| `applied_at` | `timestamptz` | no | `now()` | — | Aplicación |

### 5.6 `role_assignments` — asignaciones de rol persistentes (B5)

| Columna | Tipo | Nulo | Default | Clave | Descripción |
|---|---|---|---|---|---|
| `id` | `uuid` | no | `gen_random_uuid()` | PK | Identificador |
| `wallet_address` | `text` | no | — | — | Principal (wallet) |
| `role` | `rwa.session_role` | no | — | — | Rol asignado (incluye `issuer`, `operator`, `auditor`, `arbiter`, `support`) |
| `scope` | `text` | no | `'platform'` | — | `platform` o `issuer_program` |
| `issuer_program_id` | `uuid` | sí | — | FK → `issuer_programs` (CASCADE) | Programa al que se limita el rol |
| `granted_by_wallet` | `text` | no | — | — | Quién concede (Admin) |
| `granted_at` | `timestamptz` | no | `now()` | — | Alta |
| `revoked_at` | `timestamptz` | sí | — | — | Revocación |
| `reason` | `text` | sí | — | — | Motivo |

> **Unicidad:** un rol activo por (`lower(wallet_address)`, `role`) en ámbito `platform`, y por
> (`lower(wallet_address)`, `role`, `issuer_program_id`) en ámbito de programa.
> **Regla:** un rol de plataforma no puede llevar `issuer_program_id`; `issuer_program` exige programa
> y solo admite roles operativos (`issuer`, `operator`, `auditor`, `arbiter`).

---

## 6. Relaciones principales

```
identities 1—N claim_requests N—1 credential_types
issuer_programs 1—N issuer_program_requirements N—1 credential_types
issuer_programs 1—N issuer_program_credentials N—1 credential_types
claim_requests 1—N document_files
identities 1—N identity_recovery_requests
issuer_programs 1—N tokens N—N credential_types (token_required_claims)
tokens 1—N token_compliance_modules
tokens 1—N token_guarantees N—1 identities (fiador)
tokens 1—N asset_documents
tokens 1—N listings 1—N orders 1—N payments
orders 1—1 disputes
identities 1—N sessions / listings / orders
issuer_programs 1—N role_assignments (ámbito de programa)
identities 1—N role_assignments (por wallet)
```

## 7. Notas de integridad y seguridad

- **Dinero:** todos los importes en `numeric(20,8)` (BRLT 8 decimales); nunca `float`.
- **PII:** `encrypted_data` + `encryption_meta`; el SHA-256 permite verificar sin descifrar. `retention_delete_at` materializa Q10.
- **Fail-closed:** `claim_requests` no puede pasar a `approved` sin firma del emisor ni sin verificación
  del Operador; `tokens` no puede pasar a `minted` sin las dos filas de `token_guarantees` verificadas
  con su claim aprobado (trigger `trg_tokens_guarantees` + `trg_validate_token_guarantee`); la
  revocación de un claim invalida sus garantías y pausa el token (`trg_claim_revocation_cascade`).
- **Marketplace:** una sola orden abierta por publicación, remanente con reserva y TTL, `tx_hash`
  únicos y disputa con árbitro (`disputes`); solo se publica un activo `minted`/`listed` con
  Garantía+Fiador verificadas (`trg_validate_listing_token`).
- **Retención Q10:** `trg_claim_revocation_cascade` fija `retention_delete_at = +30 días` al rechazar
  y `trg_identity_end_retention` la fija a `+12 meses` al cerrar la relación (`identities.ended_at`).
- **Emisor:** `trg_claim_issuer_program` exige que el emisor pertenezca al programa del claim.
- **Trazabilidad:** toda mutación relevante escribe en `audit_log` con `request_id`; los cambios on-chain se reflejan en `chain_events`. `audit_log` es **append-only** (`trg_audit_log_append_only` rechaza UPDATE/DELETE).
- **RBAC (B5):** los roles se materializan en `role_assignments` (principal ≠ claim); el rol de sesión se valida contra la asignación vigente.
- **Escrow (B3):** máquina de estados en `trg_validate_order_transition`; el vendedor y la comisión se fijan desde la publicación y `platform_fees`; el tramo NFT se registra en `escrow_asset_tx_hash`.
- **Jobs (B3/B7):** `rwa.expire_orders()` libera reservas vencidas y `rwa.purge_expired_documents()` aplica la retención Q10; ambos los invoca Cloud Scheduler.
- **Borrado:** `document_files` es lógico (`deleted_at`) hasta la purga programada; nunca se sirve un documento con `deleted_at` no nulo.
