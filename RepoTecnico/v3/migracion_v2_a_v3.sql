-- =============================================================================
-- migracion_v2_a_v3.sql — Evolución del esquema rwa de v2 (1.0–1.2) a v3.0
-- =============================================================================
-- Propósito : migrar una base PostgreSQL ya existente con el esquema v2 a v3.0 (revisión v3.1)
--             SIN pérdida de datos y SIN colisiones de nombre.
-- Estrategia: (1) archivar las tablas v2 como *_v2, (2) crear el esquema v3
--             canónico con `\ir base_datos.sql`, (3) ETL de datos v2→v3,
--             (4) registrar versiones en schema_migrations, todo en UNA transacción.
--
-- Ejecución:
--   pg_dump "$DATABASE_URL" -Fc -f rwa_v2_$(date +%Y%m%d).dump   # backup OBLIGATORIO
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f RepoTecnico/migracion_v2_a_v3.sql
--
-- Requisitos: el script debe ejecutarse desde la carpeta que contiene base_datos.sql
-- (\ir resuelve la ruta relativa al script). PostgreSQL 15.
--
-- Reejecutable: NO (la 2ª ejecución debe fallar y proteger los datos). El guard
-- de §0 aborta si detecta que la migración ya se aplicó.
-- =============================================================================

\set ON_ERROR_STOP on
\timing on

BEGIN;

-- -----------------------------------------------------------------------------
-- §0. Guard: abortar si ya se migró (idempotencia segura)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF to_regclass('rwa.claim_requests_v2') IS NOT NULL THEN
        RAISE EXCEPTION 'La migración v2→v3 ya se aplicó (existe rwa.claim_requests_v2). Abortando.';
    END IF;
    IF to_regclass('rwa.claim_requests') IS NULL THEN
        RAISE EXCEPTION 'No existe rwa.claim_requests: la BD no es v2. Usa base_datos.sql en una BD nueva.';
    END IF;
END
$$;

-- -----------------------------------------------------------------------------
-- §1. Archivar las 12 tablas v2 (elimina las colisiones de nombre de H-01)
-- -----------------------------------------------------------------------------
ALTER TABLE rwa.claim_topics              RENAME TO claim_topics_v2;
ALTER TABLE rwa.issuers                   RENAME TO issuers_v2;
ALTER TABLE rwa.claim_requests            RENAME TO claim_requests_v2;
ALTER TABLE rwa.document_files            RENAME TO document_files_v2;
ALTER TABLE rwa.tokens                    RENAME TO tokens_v2;
ALTER TABLE rwa.token_required_claims     RENAME TO token_required_claims_v2;
ALTER TABLE rwa.token_compliance_modules  RENAME TO token_compliance_modules_v2;
ALTER TABLE rwa.sessions                  RENAME TO sessions_v2;
ALTER TABLE rwa.audit_log                 RENAME TO audit_log_v2;
ALTER TABLE rwa.schema_migrations         RENAME TO schema_migrations_v2;
ALTER TABLE rwa.indexer_state             RENAME TO indexer_state_v2;
ALTER TABLE rwa.chain_events              RENAME TO chain_events_v2;

-- 1.1 Los nombres de índice/secuencia son globales al esquema: renombrarlos
--     para que el esquema v3 pueda crear los suyos sin colisión (H-01).
DO $$
DECLARE
    r record;
BEGIN
    FOR r IN
        SELECT indexname FROM pg_indexes
         WHERE schemaname = 'rwa' AND tablename LIKE '%\_v2' ESCAPE '\'
    LOOP
        IF r.indexname NOT LIKE '%\_v2' ESCAPE '\' THEN
            EXECUTE format('ALTER INDEX rwa.%I RENAME TO %I', r.indexname, r.indexname || '_v2');
        END IF;
    END LOOP;
END
$$;

ALTER SEQUENCE IF EXISTS rwa.audit_log_id_seq   RENAME TO audit_log_id_seq_v2;
ALTER SEQUENCE IF EXISTS rwa.chain_events_id_seq RENAME TO chain_events_id_seq_v2;

-- -----------------------------------------------------------------------------
-- §2. Evolucionar el enum de sesiones (v3 añade visitor y operator)
-- -----------------------------------------------------------------------------
ALTER TYPE rwa.session_role ADD VALUE IF NOT EXISTS 'visitor';
ALTER TYPE rwa.session_role ADD VALUE IF NOT EXISTS 'operator';
ALTER TYPE rwa.session_role ADD VALUE IF NOT EXISTS 'auditor';
ALTER TYPE rwa.session_role ADD VALUE IF NOT EXISTS 'arbiter';
ALTER TYPE rwa.session_role ADD VALUE IF NOT EXISTS 'support';

-- -----------------------------------------------------------------------------
-- §3. Crear el esquema v3 canónico (nuevas tablas, enums, índices, triggers, semillas)
-- -----------------------------------------------------------------------------
-- La vista v2 se sustituye por la de v3 (mismo nombre): se elimina antes del \ir
DROP VIEW IF EXISTS rwa.v_claim_request_summary;

\ir base_datos.sql

-- -----------------------------------------------------------------------------
-- §4. ETL v2 → v3
-- -----------------------------------------------------------------------------

-- 4.1 Catálogo de credenciales: mapear claim_topics_v2 → credential_types
--     N-02: no se copia on_chain_topic (el UNIQUE ya está ocupado por las semillas
--     canónicas ACREDITACION=7 / JURISDICCION=9); se alinean los códigos heredados
--     con los canónicos y se preserva `active`.
INSERT INTO rwa.credential_types (code, name, description, on_chain_topic, active)
SELECT
    CASE lower(ct.code)
        WHEN 'accreditation' THEN 'ACREDITACION'
        WHEN 'jurisdiction'  THEN 'JURISDICCION'
        ELSE upper(ct.code)
    END,
    ct.name,
    ct.description,
    NULL,
    ct.active
FROM rwa.claim_topics_v2 ct
ON CONFLICT (code) DO NOTHING;

-- 4.2 Emisores heredados: vincularlos al programa contenedor 'legacy-v2'
INSERT INTO rwa.issuers (address, display_name, issuer_program_id, verified_at)
SELECT lower(i.address), i.name, p.id,
       CASE WHEN i.verified THEN coalesce(i.verified_at, now()) ELSE NULL END
FROM rwa.issuers_v2 i
CROSS JOIN rwa.issuer_programs p
WHERE p.slug = 'legacy-v2'
ON CONFLICT (lower(address)) DO NOTHING;

-- 4.2b Emisores referenciados por claims no registrados en issuers_v2
INSERT INTO rwa.issuers (address, display_name, issuer_program_id, verified_at)
SELECT DISTINCT lower(cr.issuer_address), 'Emisor v2 (migrado)', p.id, now()
FROM rwa.claim_requests_v2 cr
CROSS JOIN rwa.issuer_programs p
WHERE p.slug = 'legacy-v2'
  AND cr.issuer_address ~* '^0x[0-9a-f]{40}$'
ON CONFLICT (lower(address)) DO NOTHING;

-- 4.3 Identidades: una por wallet conocida (requester, wallet owner, admin y review)
INSERT INTO rwa.identities (wallet_address, display_alias, status, kyc_level)
SELECT lower(w), 'v2-' || substr(md5(lower(w)), 1, 10), 'active', 0
FROM (
    SELECT requester_address AS w FROM rwa.claim_requests_v2
    UNION SELECT claim_wallet_owner FROM rwa.claim_requests_v2 WHERE claim_wallet_owner IS NOT NULL
    UNION SELECT admin_address FROM rwa.tokens_v2
) AS wallets
WHERE w IS NOT NULL AND w ~* '^0x[0-9a-f]{40}$'
ON CONFLICT (lower(wallet_address)) DO NOTHING;

-- 4.4 Claims heredados (mapeo de topic, emisor, estado y payload EIP-712)
INSERT INTO rwa.claim_requests (
    id, identity_id, issuer_program_id, credential_type_id, issuer_id,
    status, requester_wallet, requester_signature,
    verified_by_wallet, verified_at, reviewed_by_wallet, reviewed_at,
    issuer_signature, tx_hash, expires_at, metadata, created_at, updated_at
)
SELECT
    cr.id,
    i.id,
    p.id,
    ct.id,
    iss.id,
    CASE cr.status::text
        WHEN 'pending'  THEN 'pending'::rwa.claim_status
        WHEN 'approved' THEN 'approved'::rwa.claim_status
        ELSE 'rejected'::rwa.claim_status
    END,
    lower(cr.requester_address),
    cr.signature,
    -- H-09: el revisor v2 hacía ambas funciones; se sintetiza un Operador distinto
    -- del aprobador para no violar la segregación (documentado en el acta de migración)
    CASE WHEN cr.status::text <> 'pending'
         THEN '0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65'
    END,
    CASE WHEN cr.status::text <> 'pending' THEN cr.reviewed_at END,
    CASE WHEN cr.status::text <> 'pending' THEN lower(cr.reviewed_by) END,
    CASE WHEN cr.status::text <> 'pending' THEN cr.reviewed_at END,
    cr.issuer_signature,
    NULL,
    CASE WHEN cr.claim_expires_at > 0 AND cr.claim_expires_at < 4102444800
         THEN to_timestamp(cr.claim_expires_at::double precision) END,
    jsonb_build_object(
        'legacy', true,
        'claim_topic_id', cr.claim_topic_id,
        'claim_scheme', cr.claim_scheme,
        'claim_chain_id', cr.claim_chain_id,
        'claim_uri', cr.claim_uri,
        'claim_uri_hash', cr.claim_uri_hash,
        'claim_data_hash', cr.claim_data_hash,
        'legacy_identity_address', cr.identity_address,
        'legacy_unverified', true
    ),
    cr.created_at,
    cr.updated_at
FROM rwa.claim_requests_v2 cr
JOIN rwa.credential_types ct ON ct.code = (
    SELECT CASE lower(x.code)
               WHEN 'accreditation' THEN 'ACREDITACION'
               WHEN 'jurisdiction'  THEN 'JURISDICCION'
               ELSE upper(x.code)
           END
      FROM rwa.claim_topics_v2 x WHERE x.id = cr.claim_topic_id)
JOIN rwa.identities i       ON i.wallet_address = lower(cr.requester_address)
JOIN rwa.issuers iss        ON iss.address = lower(cr.issuer_address)
JOIN rwa.issuer_programs p  ON p.id = iss.issuer_program_id
ON CONFLICT (id) DO NOTHING;

-- 4.5 Documentos cifrados
INSERT INTO rwa.document_files (
    id, claim_request_id, label, mime_type, size_bytes, sha256,
    encrypted_data, encryption_meta, retention_delete_at, deleted_at, created_at
)
SELECT
    df.id, df.claim_request_id, df.original_name, df.content_type, df.size_bytes::integer,
    encode(df.sha256, 'hex'),   -- F-07: hash del contenido ORIGINAL, no del blob cifrado
    df.content,
    jsonb_build_object('algo', df.encryption_algo,
                       'nonce', CASE WHEN df.encryption_nonce IS NOT NULL
                                     THEN encode(df.encryption_nonce, 'hex') END,
                       'legacy', true),
    NULL, NULL, df.created_at
FROM rwa.document_files_v2 df
WHERE df.size_bytes BETWEEN 1 AND 20971520
  AND df.content_type IN ('application/pdf', 'image/png', 'image/jpeg',
                          'application/msword',
                          'application/vnd.openxmlformats-officedocument.wordprocessingml.document')
ON CONFLICT (id) DO NOTHING;

-- 4.6 Activos tokenizados (los ERC-20 demo de v2 se tratan como 'product')
INSERT INTO rwa.tokens (
    id, issuer_program_id, token_address, on_chain_token_id, asset_kind, standard,
    name, symbol, decimals, total_supply, unit, price_brlt, valued_brlt,
    metadata_uri, status, minted_tx_hash, created_by, created_at, updated_at
)
SELECT
    t.id,
    p.id,
    lower(t.token_address),
    NULL,
    'product'::rwa.asset_kind,
    'erc20'::rwa.asset_standard,
    t.name,
    t.symbol,
    t.decimals,
    t.total_supply,
    'unidad',
    CASE WHEN t.price IS NOT NULL AND t.price > 0 THEN round(t.price::numeric, 8) END,
    CASE WHEN t.price IS NOT NULL AND t.price > 0 THEN round(t.price::numeric, 8) END,
    NULL,
    -- H-06: los activos heredados no tienen Garantía+Fiador; quedan en 'draft'
    'draft'::rwa.asset_status,
    t.transaction_hash,
    lower(t.admin_address),
    t.created_at,
    t.updated_at
FROM rwa.tokens_v2 t
CROSS JOIN rwa.issuer_programs p
WHERE p.slug = 'legacy-v2'
ON CONFLICT (id) DO NOTHING;

-- 4.7 Claims requeridos por activo (F-01: mismo alias canónico que §4.1)
INSERT INTO rwa.token_required_claims (token_id, credential_type_id)
SELECT trc.token_id, ct.id
FROM rwa.token_required_claims_v2 trc
JOIN rwa.claim_topics_v2 ct2 ON ct2.id = trc.claim_topic_id
JOIN rwa.credential_types ct ON ct.code = CASE lower(ct2.code)
        WHEN 'accreditation' THEN 'ACREDITACION'
        WHEN 'jurisdiction'  THEN 'JURISDICCION'
        ELSE upper(ct2.code)
    END
ON CONFLICT DO NOTHING;

-- 4.8 Módulos de compliance por activo
INSERT INTO rwa.token_compliance_modules (token_id, module_address, module_kind)
SELECT tcm.token_id, lower(tcm.module_address), 'legacy'
FROM rwa.token_compliance_modules_v2 tcm
ON CONFLICT DO NOTHING;

-- 4.9 Sesiones
INSERT INTO rwa.sessions (id, nonce, wallet_address, role, domain, issued_at, expires_at, revoked_at)
SELECT s.id, s.nonce, lower(s.address),
       CASE s.role::text
           WHEN 'admin'  THEN 'admin'::rwa.session_role
           WHEN 'issuer' THEN 'issuer'::rwa.session_role
           ELSE 'investor'::rwa.session_role
       END,
       'legacy-v2', s.issued_at, s.expires_at, s.revoked_at
FROM rwa.sessions_v2 s
ON CONFLICT (id) DO NOTHING;

-- 4.10 Auditoría
INSERT INTO rwa.audit_log (actor_wallet, actor_role, action, resource_type, resource_id, request_id, ip, metadata, created_at)
SELECT lower(a.actor_address), NULL, a.action, a.resource_type, a.resource_id,
       a.request_id, NULL, coalesce(a.detail, '{}'::jsonb), a.at
FROM rwa.audit_log_v2 a;

-- 4.11 Eventos on-chain (con los campos de reorg/finalidad de v3)
INSERT INTO rwa.chain_events (chain_id, block_number, block_hash, parent_hash, tx_hash,
                              log_index, event_name, contract_address, payload, removed, created_at)
SELECT ce.chain_id, ce.block_number, ce.block_hash, NULL, ce.tx_hash,
       ce.log_index, ce.event_name, lower(ce.address), ce.args, ce.removed, ce.indexed_at
FROM rwa.chain_events_v2 ce
ON CONFLICT (chain_id, tx_hash, log_index) DO NOTHING;

-- 4.12 Estado del indexer (singleton): último bloque de la cadena canónica
INSERT INTO rwa.indexer_state (id, chain_id, last_block, last_block_hash)
SELECT 1, coalesce(max(chain_id), 31337), coalesce(max(last_block), 0), NULL
FROM rwa.indexer_state_v2
ON CONFLICT (id) DO NOTHING;

-- -----------------------------------------------------------------------------
-- §5. Historial de migraciones: conservar v2 y registrar v3.0
-- -----------------------------------------------------------------------------
INSERT INTO rwa.schema_migrations (version, description)
SELECT version, 'heredado de v2 (schema_migrations_v2)' FROM rwa.schema_migrations_v2
ON CONFLICT (version) DO NOTHING;

INSERT INTO rwa.schema_migrations (version, description) VALUES
    ('1.0', 'v2 base: identidades, claims, documentos y tokens'),
    ('1.1', 'v2: payload EIP-712 del claim'),
    ('1.2', 'v2: sesiones SIWE, auditoría e indexer'),
    ('3.0', 'v3.0: ISSUER, identidades, certificaciones, activos, marketplace, pagos y recuperación')
ON CONFLICT (version) DO NOTHING;

-- -----------------------------------------------------------------------------
-- §6. Verificación de la migración (aborta si los conteos no cuadran)
-- -----------------------------------------------------------------------------
DO $$
DECLARE
    v_req_v2 bigint;
    v_req_v3 bigint;
    v_doc_v2 bigint;
    v_doc_v3 bigint;
    v_tok_v2 bigint;
    v_tok_v3 bigint;
    v_trc_v2 bigint;
    v_trc_v3 bigint;
BEGIN
    SELECT count(*) INTO v_req_v2 FROM rwa.claim_requests_v2;
    SELECT count(*) INTO v_req_v3 FROM rwa.claim_requests;
    SELECT count(*) INTO v_doc_v2 FROM rwa.document_files_v2;
    SELECT count(*) INTO v_doc_v3 FROM rwa.document_files;
    SELECT count(*) INTO v_tok_v2 FROM rwa.tokens_v2;
    SELECT count(*) INTO v_tok_v3 FROM rwa.tokens;
    SELECT count(*) INTO v_trc_v2 FROM rwa.token_required_claims_v2;
    SELECT count(*) INTO v_trc_v3 FROM rwa.token_required_claims;

    RAISE NOTICE 'claims  v2=% v3=%', v_req_v2, v_req_v3;
    RAISE NOTICE 'docs    v2=% v3=% (se omiten MIME/tamaño inválidos)', v_doc_v2, v_doc_v3;
    RAISE NOTICE 'tokens  v2=% v3=%', v_tok_v2, v_tok_v3;
    RAISE NOTICE 'required_claims v2=% v3=%', v_trc_v2, v_trc_v3;
    IF v_trc_v3 < v_trc_v2 THEN
        RAISE EXCEPTION 'Pérdida de claims requeridos: v2=% v3=%', v_trc_v2, v_trc_v3;
    END IF;
    IF v_doc_v3 > v_doc_v2 THEN
        RAISE EXCEPTION 'Documentos migrados (% ) > origen (%)', v_doc_v3, v_doc_v2;
    END IF;

    IF v_req_v3 <> v_req_v2 THEN
        RAISE EXCEPTION 'Discrepancia en claims: v2=% v3=%', v_req_v2, v_req_v3;
    END IF;
    IF v_tok_v3 <> v_tok_v2 THEN
        RAISE EXCEPTION 'Discrepancia en tokens: v2=% v3=%', v_tok_v2, v_tok_v3;
    END IF;
END
$$;

COMMIT;

-- =============================================================================
-- Nota: las tablas *_v2 se conservan como archivo de solo lectura. Se pueden
-- eliminar tras validar el piloto:
--   DROP TABLE rwa.claim_requests_v2, rwa.document_files_v2, ... CASCADE;
-- =============================================================================
