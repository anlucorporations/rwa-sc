-- =============================================================================
-- base_datos.sql — Creación de la BD off-chain (PostgreSQL) de la plataforma RWA
-- Versión: 1.1 · 2026-10-14
-- =============================================================================
-- ARTEFACTO DE DATOS COMPARTIDO — COPIA ESPEJO SINCRONIZADA (2026-10-14):
--   Canónico: rwa-sc/RepoTecnico/base_datos.sql   (línea @sc)
--   Espejo:   rwa-web/RepoTecnico/base_datos.sql  (línea @web)
--   Deben ser IDÉNTICOS byte a byte. Edita solo el canónico y ejecuta
--   `rwa-web/RepoTecnico/check_sincronizacion_datos.sh --sync`.
--   Regla: rwa-web/RepoTecnico/ARTEFACTOS_DATOS_SINCRONIZADOS.md
-- =============================================================================
-- Changelog:
--   v0.1 (2026-10-03): Artefacto inicial documental (BD activa era MongoDB).
--   v0.2 (2026-10-03): Transcripción fiel de las colecciones MongoDB + catálogo
--     canónico de claim topics. Sección PostgreSQL PENDIENTE de la decisión Q6.
--   v1.0 (2026-10-14): **DECISIÓN DEL USUARIO (Q6 resuelta): la BD off-chain del
--     frontend es PostgreSQL** (Cloud SQL, PG 15+) y la red on-chain canónica es
--     el **Anvil de GCP (chain 31337)**. Por tanto:
--       - SECCIÓN 1 pasa a ser DDL REAL y ejecutable (ya no documental).
--       - Se añaden `sessions` (D-092, SIWE) y `audit_log` (RNF-W-02).
--       - `claim_documents` (GridFS) se sustituye por `document_files` (bytea
--         cifrado AES-256-GCM, D-093) con `sha256` y metadatos.
--       - Se normalizan los arrays de MongoDB: `token_required_claims` y
--         `token_compliance_modules` (join tables con FK reales).
--       - `claim_topic` pasa de string libre a FK contra el catálogo canónico
--         `claim_topics` (H-13).
--       - Se añade `claim_request_status`/`session_role` como ENUM, función
--         `set_updated_at()` con triggers e índices de búsqueda.
--       - La transcripción MongoDB original se conserva como ANEXO A (referencia
--         de migración, no se ejecuta).
--     Trazabilidad: `rwa-web/RepoTecnico/INFORME_OPTIMIZACION_WEB_V1.md` (HW-01/02/04),
--     `rwa-web/RepoTecnico/requerimientos_web.md`
--     v1.1 (RF-W-02/05/06, RNF-W-02), D-092/D-093/D-095, y `diccionario_datos.md` v1.2
--     + `diagrama_er.md` v1.2 (sincronizados en el mismo turno).
--   v1.1 (O2.3, 2026-10-14): **payload EIP-712 del claim** (RF-W-10, D-020/D-083).
--     `claim_requests` gana `identity_address`, `claim_chain_id`, `claim_scheme`,
--     `claim_wallet_owner`, `claim_nonce`, `claim_expires_at`, `claim_data`,
--     `claim_uri`, `claim_uri_hash`, `claim_data_hash` y `claim_signature`, con un
--     CHECK de completitud al resolver. `issuer_signature`/`issuer_signed_message`
--     conservan la firma EIP-712 y su JSON (compatibilidad con HW-01).
--
-- Convenciones: snake_case · tablas en plural · PK `id` (uuid salvo catálogos) ·
--   FK `<tabla_singular>_id` · timestamps `created_at`/`updated_at`.
-- Idempotente y reejecutable: IF NOT EXISTS + DO $$ para tipos + DROP TRIGGER IF EXISTS.
-- Sin secretos: la conexión se toma de `DATABASE_URL` (ver entornos_globales.md §14).
--   Usuario/host/clave NO se escriben aquí.
-- =============================================================================

-- =============================================================================
-- SECCIÓN 0 — Extensiones y esquema
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid(), digest()

CREATE SCHEMA IF NOT EXISTS rwa;
SET search_path TO rwa, public;

-- =============================================================================
-- SECCIÓN 1 — Tipos ENUM (idempotentes)
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                   WHERE t.typname = 'claim_request_status' AND n.nspname = 'rwa') THEN
        CREATE TYPE rwa.claim_request_status AS ENUM ('pending', 'approved', 'rejected');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                   WHERE t.typname = 'session_role' AND n.nspname = 'rwa') THEN
        CREATE TYPE rwa.session_role AS ENUM ('investor', 'issuer', 'admin');
    END IF;
END
$$;

-- =============================================================================
-- SECCIÓN 2 — Catálogos
-- =============================================================================

-- Catálogo canónico de claim topics (H-13): 1=KYC, 7=Accreditation, 9=Jurisdiction.
-- Reservados (active = false): 5=Environmental, 6=Sanctions (H-10, no implementados).
CREATE TABLE IF NOT EXISTS rwa.claim_topics (
    id          smallint     PRIMARY KEY,
    code        text         NOT NULL UNIQUE,
    name        text         NOT NULL,
    description text,
    active      boolean      NOT NULL DEFAULT true,
    created_at  timestamptz  NOT NULL DEFAULT now()
);

COMMENT ON TABLE rwa.claim_topics IS 'Catálogo canónico de claim topics (H-13). Único origen permitido para claim_requests.claim_topic_id y token_required_claims.claim_topic_id.';

-- Registro de nombres visibles de emisores. La autoridad real (quién es issuer
-- y para qué topic) vive on-chain en TrustedIssuersRegistry; aquí solo el nombre
-- visible y el estado de verificación cacheado (RF-W-12).
CREATE TABLE IF NOT EXISTS rwa.issuers (
    id          uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
    address     text         NOT NULL UNIQUE,
    name        text         NOT NULL,
    verified    boolean      NOT NULL DEFAULT false,
    verified_at timestamptz,
    created_at  timestamptz  NOT NULL DEFAULT now(),
    updated_at  timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT issuers_address_lower_hex CHECK (address ~ '^0x[0-9a-f]{40}$'),
    CONSTRAINT issuers_name_not_blank CHECK (btrim(name) <> '')
);

COMMENT ON TABLE rwa.issuers IS 'Nombre visible del emisor. La autorización por topic se valida on-chain (TrustedIssuersRegistry); esta tabla no concede permisos.';

-- =============================================================================
-- SECCIÓN 3 — Núcleo del frontend
-- =============================================================================

-- Solicitudes de claim. Sustituye a la colección MongoDB `claim_requests`.
CREATE TABLE IF NOT EXISTS rwa.claim_requests (
    id                    uuid                   PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_address     text                   NOT NULL,
    issuer_address        text                   NOT NULL,
    claim_topic_id        smallint               NOT NULL REFERENCES rwa.claim_topics(id) ON DELETE RESTRICT,
    message               text,
    status                rwa.claim_request_status NOT NULL DEFAULT 'pending',
    signed_message        text                   NOT NULL,
    signature             text                   NOT NULL,
    review_note           text,
    issuer_signed_message text,
    issuer_signature      text,
    reviewed_by           text,
    reviewed_at           timestamptz,
    -- O2.3 (v1.1): payload EIP-712 firmado por el emisor (`IdentityCloneable.addClaim`)
    identity_address      text,
    claim_chain_id        integer,
    claim_scheme          smallint               NOT NULL DEFAULT 1,
    claim_wallet_owner    text,
    claim_nonce           numeric(78,0),
    claim_expires_at      numeric(78,0),
    claim_data            text,
    claim_uri             text,
    claim_uri_hash        text,
    claim_data_hash       text,
    claim_signature       text,
    created_at            timestamptz            NOT NULL DEFAULT now(),
    updated_at            timestamptz            NOT NULL DEFAULT now(),
    CONSTRAINT claim_requests_requester_lower_hex CHECK (requester_address ~ '^0x[0-9a-f]{40}$'),
    CONSTRAINT claim_requests_issuer_lower_hex    CHECK (issuer_address ~ '^0x[0-9a-f]{40}$'),
    -- Una revisión exige firma y firmante; ninguna revisión queda sin trazabilidad (HW-01).
    CONSTRAINT claim_requests_review_consistency CHECK (
        (status = 'pending'  AND reviewed_at IS NULL AND issuer_signature IS NULL AND reviewed_by IS NULL)
        OR
        (status <> 'pending' AND reviewed_at IS NOT NULL AND issuer_signature IS NOT NULL AND reviewed_by IS NOT NULL)
    ),
    -- Al resolver, el payload EIP-712 debe estar completo (O2.3).
    CONSTRAINT claim_requests_claim_payload_consistency CHECK (
        (status <> 'approved')
        OR
        (identity_address IS NOT NULL AND claim_chain_id IS NOT NULL
         AND claim_wallet_owner IS NOT NULL AND claim_nonce IS NOT NULL
         AND claim_expires_at IS NOT NULL AND claim_data IS NOT NULL
         AND claim_uri IS NOT NULL AND claim_uri_hash IS NOT NULL
         AND claim_data_hash IS NOT NULL AND claim_signature IS NOT NULL)
    ),
    CONSTRAINT claim_requests_identity_lower_hex CHECK (
        identity_address IS NULL OR identity_address ~ '^0x[0-9a-f]{40}$'
    ),
    CONSTRAINT claim_requests_wallet_owner_lower_hex CHECK (
        claim_wallet_owner IS NULL OR claim_wallet_owner ~ '^0x[0-9a-f]{40}$'
    )
);

COMMENT ON TABLE rwa.claim_requests IS 'Solicitudes de claim off-chain. `claim_topic_id` es FK al catálogo canónico (antes string libre, H-13). Una solicitud resuelta siempre lleva `reviewed_by`, `reviewed_at` e `issuer_signature` (HW-01).';

-- Documentos KYC. Sustituye al bucket GridFS `claim_documents`.
-- El contenido se guarda cifrado (AES-256-GCM, D-093); el acceso se autoriza por
-- propiedad de la solicitud asociada (RF-W-06).
CREATE TABLE IF NOT EXISTS rwa.document_files (
    id               uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_request_id uuid         NOT NULL REFERENCES rwa.claim_requests(id) ON DELETE CASCADE,
    original_name    text         NOT NULL,
    content_type     text         NOT NULL,
    size_bytes       bigint       NOT NULL,
    sha256           bytea        NOT NULL,
    content          bytea        NOT NULL,
    encryption_algo  text         NOT NULL DEFAULT 'AES-256-GCM',
    encryption_nonce bytea,
    uploaded_by      text         NOT NULL,
    created_at       timestamptz  NOT NULL DEFAULT now(),
    CONSTRAINT document_files_size_range CHECK (size_bytes > 0 AND size_bytes <= 10485760),
    CONSTRAINT document_files_uploader_lower_hex CHECK (uploaded_by ~ '^0x[0-9a-f]{40}$'),
    CONSTRAINT document_files_mime_allowlist CHECK (
        content_type IN ('application/pdf','image/jpeg','image/png',
                         'application/msword',
                         'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
    )
);

COMMENT ON TABLE rwa.document_files IS 'Documentos KYC cifrados en reposo (D-093). MIME validado en servidor por magic bytes y restringido por CHECK. Tamaño máximo 10 MB.';

-- Tokens registrados por la fábrica (registro off-chain para la UI).
-- Sustituye a la colección MongoDB `tokens`; los arrays se normalizan.
CREATE TABLE IF NOT EXISTS rwa.tokens (
    id                        uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
    token_address             text          NOT NULL UNIQUE,
    admin_address             text          NOT NULL,
    name                      text          NOT NULL,
    symbol                    text          NOT NULL,
    decimals                  smallint      NOT NULL,
    max_total_supply          numeric(78,0),
    total_supply              numeric(78,0),
    identity_registry         text,
    trusted_issuers_registry  text,
    claim_topics_registry     text,
    compliance_address        text,
    price                     numeric(38,18),
    description               text,
    transaction_hash          text,
    block_number              bigint,
    created_at                timestamptz   NOT NULL DEFAULT now(),
    updated_at                timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT tokens_address_lower_hex  CHECK (token_address ~ '^0x[0-9a-f]{40}$'),
    CONSTRAINT tokens_admin_lower_hex    CHECK (admin_address ~ '^0x[0-9a-f]{40}$'),
    CONSTRAINT tokens_decimals_range     CHECK (decimals BETWEEN 0 AND 18),
    CONSTRAINT tokens_symbol_format      CHECK (symbol ~ '^[A-Z0-9]{1,11}$'),
    -- RF-W-11 / D-084: sin claimTopicsRegistry el token es fail-closed; se prohíbe registrar
    -- un token sin los tres registries (evita reproducir el estado actual roto).
    CONSTRAINT tokens_registries_required CHECK (
        identity_registry IS NOT NULL
        AND trusted_issuers_registry IS NOT NULL
        AND claim_topics_registry IS NOT NULL
    ),
    CONSTRAINT tokens_price_non_negative CHECK (price IS NULL OR price >= 0)
);

COMMENT ON TABLE rwa.tokens IS 'Registro off-chain de tokens. CHECK `tokens_registries_required` impide persistir tokens sin claimTopicsRegistry (HW-03 / RF-W-11).';

-- Join table: topics exigidos por token (sustituye `tokens.requiredClaims`).
CREATE TABLE IF NOT EXISTS rwa.token_required_claims (
    token_id       uuid     NOT NULL REFERENCES rwa.tokens(id) ON DELETE CASCADE,
    claim_topic_id smallint NOT NULL REFERENCES rwa.claim_topics(id) ON DELETE RESTRICT,
    created_at     timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (token_id, claim_topic_id)
);

-- Join table: módulos de compliance asociados a un token (sustituye `tokens.complianceModules`).
CREATE TABLE IF NOT EXISTS rwa.token_compliance_modules (
    token_id      uuid        NOT NULL REFERENCES rwa.tokens(id) ON DELETE CASCADE,
    module_address text       NOT NULL,
    is_primary    boolean     NOT NULL DEFAULT false,
    created_at    timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (token_id, module_address),
    CONSTRAINT token_compliance_modules_address_lower_hex CHECK (module_address ~ '^0x[0-9a-f]{40}$')
);

-- =============================================================================
-- SECCIÓN 4 — Sesión SIWE y auditoría (D-092, RNF-W-02)
-- =============================================================================

CREATE TABLE IF NOT EXISTS rwa.sessions (
    id         uuid              PRIMARY KEY DEFAULT gen_random_uuid(),
    address    text              NOT NULL,
    nonce      text              NOT NULL UNIQUE,
    role       rwa.session_role  NOT NULL DEFAULT 'investor',
    issued_at  timestamptz       NOT NULL DEFAULT now(),
    expires_at timestamptz       NOT NULL,
    revoked_at timestamptz,
    user_agent text,
    ip         inet,
    CONSTRAINT sessions_address_lower_hex CHECK (address ~ '^0x[0-9a-f]{40}$'),
    CONSTRAINT sessions_expiry_after_issue CHECK (expires_at > issued_at)
);

COMMENT ON TABLE rwa.sessions IS 'Sesiones SIWE (EIP-4361, D-092). `nonce` de un solo uso. La cookie httpOnly firmada transporta el id de sesión; esta tabla permite revocación inmediata.';

CREATE TABLE IF NOT EXISTS rwa.audit_log (
    id             bigserial   PRIMARY KEY,
    actor_address  text,
    action         text        NOT NULL,
    resource_type  text        NOT NULL,
    resource_id    text,
    request_id     text,
    detail         jsonb,
    at             timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE rwa.audit_log IS 'Registro de auditoría de accesos y mutaciones (RNF-W-02): quién accedió a qué documento o claim y cuándo.';

CREATE TABLE IF NOT EXISTS rwa.schema_migrations (
    version    text        PRIMARY KEY,
    applied_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- SECCIÓN 4.1 — Migraciones incrementales (idempotentes)
-- =============================================================================
-- v1.1 (O2.3): payload EIP-712 del claim. Reejecutable sobre instalaciones v1.0.

ALTER TABLE rwa.claim_requests ADD COLUMN IF NOT EXISTS identity_address   text;
ALTER TABLE rwa.claim_requests ADD COLUMN IF NOT EXISTS claim_chain_id     integer;
ALTER TABLE rwa.claim_requests ADD COLUMN IF NOT EXISTS claim_scheme       smallint NOT NULL DEFAULT 1;
ALTER TABLE rwa.claim_requests ADD COLUMN IF NOT EXISTS claim_wallet_owner text;
ALTER TABLE rwa.claim_requests ADD COLUMN IF NOT EXISTS claim_nonce        numeric(78,0);
ALTER TABLE rwa.claim_requests ADD COLUMN IF NOT EXISTS claim_expires_at   numeric(78,0);
ALTER TABLE rwa.claim_requests ADD COLUMN IF NOT EXISTS claim_data         text;
ALTER TABLE rwa.claim_requests ADD COLUMN IF NOT EXISTS claim_uri          text;
ALTER TABLE rwa.claim_requests ADD COLUMN IF NOT EXISTS claim_uri_hash     text;
ALTER TABLE rwa.claim_requests ADD COLUMN IF NOT EXISTS claim_data_hash    text;
ALTER TABLE rwa.claim_requests ADD COLUMN IF NOT EXISTS claim_signature    text;

ALTER TABLE rwa.claim_requests DROP CONSTRAINT IF EXISTS claim_requests_claim_payload_consistency;

DO $$ BEGIN
    ALTER TABLE rwa.claim_requests ADD CONSTRAINT claim_requests_claim_payload_consistency CHECK (
        (status <> 'approved')
        OR
        (identity_address IS NOT NULL AND claim_chain_id IS NOT NULL
         AND claim_wallet_owner IS NOT NULL AND claim_nonce IS NOT NULL
         AND claim_expires_at IS NOT NULL AND claim_data IS NOT NULL
         AND claim_uri IS NOT NULL AND claim_uri_hash IS NOT NULL
         AND claim_data_hash IS NOT NULL AND claim_signature IS NOT NULL)
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    ALTER TABLE rwa.claim_requests ADD CONSTRAINT claim_requests_identity_lower_hex CHECK (
        identity_address IS NULL OR identity_address ~ '^0x[0-9a-f]{40}$'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    ALTER TABLE rwa.claim_requests ADD CONSTRAINT claim_requests_wallet_owner_lower_hex CHECK (
        claim_wallet_owner IS NULL OR claim_wallet_owner ~ '^0x[0-9a-f]{40}$'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- =============================================================================
-- SECCIÓN 5 — Función y triggers de `updated_at`
-- =============================================================================

CREATE OR REPLACE FUNCTION rwa.set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_issuers_updated_at ON rwa.issuers;
CREATE TRIGGER trg_issuers_updated_at BEFORE UPDATE ON rwa.issuers
    FOR EACH ROW EXECUTE FUNCTION rwa.set_updated_at();

DROP TRIGGER IF EXISTS trg_claim_requests_updated_at ON rwa.claim_requests;
CREATE TRIGGER trg_claim_requests_updated_at BEFORE UPDATE ON rwa.claim_requests
    FOR EACH ROW EXECUTE FUNCTION rwa.set_updated_at();

DROP TRIGGER IF EXISTS trg_tokens_updated_at ON rwa.tokens;
CREATE TRIGGER trg_tokens_updated_at BEFORE UPDATE ON rwa.tokens
    FOR EACH ROW EXECUTE FUNCTION rwa.set_updated_at();

-- =============================================================================
-- SECCIÓN 6 — Índices
-- =============================================================================

-- claim_requests: consultas de la UI (HW-02 exigía paginación y filtrado por titular/emisor).
CREATE INDEX IF NOT EXISTS idx_claim_requests_requester_created ON rwa.claim_requests (requester_address, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_claim_requests_issuer_status     ON rwa.claim_requests (issuer_address, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_claim_requests_status_created    ON rwa.claim_requests (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_claim_requests_topic             ON rwa.claim_requests (claim_topic_id);

-- document_files
CREATE INDEX IF NOT EXISTS idx_document_files_claim_request ON rwa.document_files (claim_request_id);
CREATE INDEX IF NOT EXISTS idx_document_files_sha256        ON rwa.document_files (sha256);

-- tokens
CREATE INDEX IF NOT EXISTS idx_tokens_admin_created ON rwa.tokens (admin_address, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tokens_block_number  ON rwa.tokens (block_number);
CREATE INDEX IF NOT EXISTS idx_token_required_claims_topic ON rwa.token_required_claims (claim_topic_id);
CREATE INDEX IF NOT EXISTS idx_token_modules_address       ON rwa.token_compliance_modules (module_address);

-- sesiones y auditoría
CREATE INDEX IF NOT EXISTS idx_sessions_address_expires ON rwa.sessions (address, expires_at DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_expires         ON rwa.sessions (expires_at) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_audit_log_actor_at       ON rwa.audit_log (actor_address, at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_resource       ON rwa.audit_log (resource_type, resource_id, at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_request_id     ON rwa.audit_log (request_id);

-- =============================================================================
-- SECCIÓN 7 — Vista de apoyo para la UI (solicitudes con nombre de emisor y nº de documentos)
-- =============================================================================

CREATE OR REPLACE VIEW rwa.v_claim_request_summary AS
SELECT cr.id,
       cr.requester_address,
       cr.issuer_address,
       i.name                     AS issuer_name,
       cr.claim_topic_id,
       ct.name                    AS claim_topic_name,
       cr.status,
       cr.created_at,
       cr.reviewed_at,
       cr.reviewed_by,
       count(df.id)               AS document_count
FROM rwa.claim_requests cr
LEFT JOIN rwa.issuers       i  ON i.address = cr.issuer_address
LEFT JOIN rwa.claim_topics  ct ON ct.id     = cr.claim_topic_id
LEFT JOIN rwa.document_files df ON df.claim_request_id = cr.id
GROUP BY cr.id, i.name, ct.name;

COMMENT ON VIEW rwa.v_claim_request_summary IS 'Vista de lectura para el panel de emisor: solicitud + nombre de emisor + nombre de topic + número de documentos.';

-- =============================================================================
-- SECCIÓN 8 — Datos semilla (catálogo canónico, reejecutable)
-- =============================================================================

INSERT INTO rwa.claim_topics (id, code, name, description, active) VALUES
    (1, 'KYC',          'Know Your Customer', 'Verificación de identidad del inversor',           true),
    (7, 'ACCREDITATION','Accreditation',      'Acreditación de inversor cualificado',             true),
    (9, 'JURISDICTION', 'Jurisdiction',       'Jurisdicción aplicable al inversor',               true),
    (5, 'ENVIRONMENTAL','Environmental',      'RESERVADO / backlog (H-10) — no implementado',     false),
    (6, 'SANCTIONS',    'Sanctions',          'RESERVADO / backlog (H-10) — no implementado',     false)
ON CONFLICT (id) DO UPDATE
    SET code        = EXCLUDED.code,
        name        = EXCLUDED.name,
        description = EXCLUDED.description,
        active      = EXCLUDED.active;

INSERT INTO rwa.schema_migrations (version) VALUES ('1.0')
ON CONFLICT (version) DO NOTHING;

INSERT INTO rwa.schema_migrations (version) VALUES ('1.1')
ON CONFLICT (version) DO NOTHING;

-- =============================================================================
-- SECCIÓN 9 — Comprobación final
-- =============================================================================

DO $$
DECLARE
    n_tables int;
BEGIN
    SELECT count(*) INTO n_tables
    FROM information_schema.tables
    WHERE table_schema = 'rwa' AND table_type = 'BASE TABLE';

    RAISE NOTICE 'RWA off-chain PostgreSQL: % tablas en el esquema rwa. Red on-chain canonica: Anvil de GCP (chain 31337). Catalogo de topics: 1=KYC, 7=Accreditation, 9=Jurisdiction.', n_tables;
END
$$;

-- =============================================================================
-- ANEXO A — Transcripción del sistema MongoDB sustituido (REFERENCIA DE MIGRACIÓN)
-- =============================================================================
-- No se ejecuta. Se conserva para el ETL Mongo → PostgreSQL (ver `rwa-web/RepoTecnico/plan_desarrollo_web.md`).
--
-- claim_requests  ← colección `claim_requests`
--   _id(ObjectId)→id(uuid) · requesterAddress→requester_address · issuerAddress→issuer_address
--   claimTopic(string)→claim_topic_id(smallint FK) · message→message · status→status(enum)
--   signedMessage→signed_message · signature→signature · reviewedAt→reviewed_at
--   reviewNote→review_note · issuerSignedMessage→issuer_signed_message
--   issuerSignature→issuer_signature · createdAt→created_at · updatedAt→updated_at
--   [NUEVO] reviewed_by (HW-01) · [RETIRADO] documentFileId/Name/ContentType/Size → tabla document_files
--
-- claim_documents (GridFS: .files/.chunks) ← bucket `claim_documents`
--   _id→document_files.id · filename→original_name · length→size_bytes
--   metadata.contentType→content_type · metadata.uploadedAt→created_at
--   chunks→content(bytea cifrado) · [NUEVO] sha256, encryption_algo, encryption_nonce,
--   claim_request_id, uploaded_by
--
-- tokens ← colección `tokens`
--   _id→id · tokenAddress→token_address · adminAddress→admin_address · name/symbol/decimals
--   complianceAddress→compliance_address · complianceModules[]→token_compliance_modules
--   requiredClaims[]→token_required_claims · price/description/transactionHash/blockNumber
--   totalSupply→total_supply · [NUEVO] max_total_supply, registries, created_at/updated_at
--
-- issuers ← colección `issuers`
--   _id→id · address→address · name→name · [NUEVO] verified, verified_at
--
-- [NUEVAS TABLAS] sessions (SIWE, D-092) · audit_log (RNF-W-02) · schema_migrations
-- =============================================================================

-- Fin de base_datos.sql v1.0
