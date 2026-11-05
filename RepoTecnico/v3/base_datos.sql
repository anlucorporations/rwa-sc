-- =============================================================================
-- base_datos.sql — RWA v3 «Barlo Metaplace»
-- =============================================================================
-- Propósito : creación del esquema PostgreSQL de la plataforma v3 (off-chain).
-- Motor     : PostgreSQL 15 (Cloud SQL truekeate-db-dev) · Esquema: rwa
-- Versión   : 3.0 de esquema · revisión documental v3.1 · Fecha: 2026-10-31
-- Autor     : Asistente de Proyecto (Fase 1)
--
-- CHANGELOG
--   3.0  2026-10-31  Esquema v3 completo: ISSUER configurable, identidades,
--                    certificaciones (Socio/Garantía/Fiador), activos tokenizados
--                    (producto/servicio/bien), marketplace a precio fijo con
--                    escrow/comisión, pagos BRLT, recuperación de identidad,
--                    plantillas de mensajes de billetera, jurisdicciones,
--                    comisiones configurables y retención documental.
--                    Absorbe el esquema v2 (1.0–1.2) y sustituye claim_topics
--                    por credential_types; generaliza tokens a activos.
--   1.2  (v2)        Indexer (chain_events, indexer_state).
--   1.1  (v2)        Sesiones SIWE y auditoría.
--   1.0  (v2)        Identidades, claims, documentos y tokens.
--
-- SINCRONÍA: este archivo, diccionario_datos.md y diagrama_er.md son una sola
-- fuente de verdad y se editan juntos.
--
-- EJECUCIÓN
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f base_datos.sql
--   (usuario/host/password NUNCA se escriben aquí: van en DATABASE_URL)
-- =============================================================================

\set ON_ERROR_STOP on

-- -----------------------------------------------------------------------------
-- 1. Extensiones
-- -----------------------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid(), digest()

-- -----------------------------------------------------------------------------
-- 2. Esquema
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS rwa;
SET search_path = rwa, public;

-- -----------------------------------------------------------------------------
-- 3. Tipos enumerados (idempotentes vía bloque DO)
-- -----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                   WHERE n.nspname = 'rwa' AND t.typname = 'asset_kind') THEN
        CREATE TYPE rwa.asset_kind AS ENUM ('product', 'service', 'good');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                   WHERE n.nspname = 'rwa' AND t.typname = 'asset_standard') THEN
        CREATE TYPE rwa.asset_standard AS ENUM ('erc20', 'erc721', 'erc1155');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                   WHERE n.nspname = 'rwa' AND t.typname = 'asset_status') THEN
        CREATE TYPE rwa.asset_status AS ENUM ('draft', 'certifying', 'minted', 'listed', 'sold_out', 'paused');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                   WHERE n.nspname = 'rwa' AND t.typname = 'claim_status') THEN
        CREATE TYPE rwa.claim_status AS ENUM ('pending', 'documents_verified', 'in_review', 'approved', 'rejected', 'revoked');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                   WHERE n.nspname = 'rwa' AND t.typname = 'asset_doc_kind') THEN
        CREATE TYPE rwa.asset_doc_kind AS ENUM ('tenencia', 'garantia', 'tasacion', 'ficha_tecnica', 'otro');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                   WHERE n.nspname = 'rwa' AND t.typname = 'guarantee_kind') THEN
        CREATE TYPE rwa.guarantee_kind AS ENUM ('garantia', 'fiador');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                   WHERE n.nspname = 'rwa' AND t.typname = 'order_status') THEN
        CREATE TYPE rwa.order_status AS ENUM ('pending_payment', 'escrowed', 'confirmed', 'cancelled', 'disputed', 'refunded');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                   WHERE n.nspname = 'rwa' AND t.typname = 'payment_kind') THEN
        CREATE TYPE rwa.payment_kind AS ENUM ('sale', 'tokenization_fee', 'refund');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                   WHERE n.nspname = 'rwa' AND t.typname = 'payment_status') THEN
        CREATE TYPE rwa.payment_status AS ENUM ('pending', 'settled', 'failed', 'refunded');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                   WHERE n.nspname = 'rwa' AND t.typname = 'recovery_status') THEN
        CREATE TYPE rwa.recovery_status AS ENUM ('requested', 'in_review', 'approved', 'rejected', 'completed');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                   WHERE n.nspname = 'rwa' AND t.typname = 'requirement_kind') THEN
        CREATE TYPE rwa.requirement_kind AS ENUM ('document', 'credential');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                   WHERE n.nspname = 'rwa' AND t.typname = 'dispute_status') THEN
        CREATE TYPE rwa.dispute_status AS ENUM ('open', 'in_review', 'resolved_buyer', 'resolved_seller', 'rejected');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
                   WHERE n.nspname = 'rwa' AND t.typname = 'session_role') THEN
        CREATE TYPE rwa.session_role AS ENUM ('visitor', 'investor', 'issuer', 'operator', 'admin', 'auditor', 'arbiter', 'support');
    END IF;
END
$$;

-- -----------------------------------------------------------------------------
-- 4. Catálogos y configuración
-- -----------------------------------------------------------------------------

-- 4.1 Jurisdicciones soportadas (Q7: piloto LatAm; el Admin habilita países)
CREATE TABLE IF NOT EXISTS rwa.jurisdictions (
    id          smallint    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    iso2        char(2)     NOT NULL UNIQUE,
    name        text        NOT NULL,
    enabled     boolean     NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT jurisdictions_iso2_uppercase CHECK (iso2 = upper(iso2))
);

-- 4.2 Catálogo extensible de credenciales (sustituye claim_topics de v2)
CREATE TABLE IF NOT EXISTS rwa.credential_types (
    id              smallint    GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code            text        NOT NULL UNIQUE,
    name            text        NOT NULL,
    description     text,
    on_chain_topic  smallint    UNIQUE,
    validity_days   integer,
    active          boolean     NOT NULL DEFAULT true,
    created_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT credential_types_validity CHECK (validity_days IS NULL OR validity_days > 0)
);

-- 4.3 Comisiones de plataforma (Q4: singleton)
CREATE TABLE IF NOT EXISTS rwa.platform_fees (
    id                      smallint      PRIMARY KEY DEFAULT 1,
    sale_fee_bps            smallint      NOT NULL DEFAULT 500,
    tokenization_fee_brlt   numeric(20,8) NOT NULL DEFAULT 50.00000000,
    active                  boolean       NOT NULL DEFAULT true,
    updated_at              timestamptz   NOT NULL DEFAULT now(),
    CONSTRAINT platform_fees_singleton CHECK (id = 1),
    CONSTRAINT platform_fees_sale_fee  CHECK (sale_fee_bps BETWEEN 0 AND 5000),
    CONSTRAINT platform_fees_token_fee CHECK (tokenization_fee_brlt >= 0)
);

-- 4.4 Plantillas de mensajes de firma en lenguaje llano (RF-V3-21)
CREATE TABLE IF NOT EXISTS rwa.wallet_messages (
    id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    process_key  text        NOT NULL,
    locale       text        NOT NULL DEFAULT 'es',
    title        text        NOT NULL,
    template     text        NOT NULL,
    variables    jsonb       NOT NULL DEFAULT '[]'::jsonb,
    version      integer     NOT NULL DEFAULT 1,
    active       boolean     NOT NULL DEFAULT true,
    created_at   timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT wallet_messages_unique UNIQUE (process_key, locale, version),
    CONSTRAINT wallet_messages_version CHECK (version > 0)
);

-- -----------------------------------------------------------------------------
-- 5. ISSUER, identidad y certificaciones
-- -----------------------------------------------------------------------------

-- 5.1 ISSUER: plantilla de certificación (proceso + requisitos + N claims)
CREATE TABLE IF NOT EXISTS rwa.issuer_programs (
    id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    slug           text        NOT NULL UNIQUE,
    name           text        NOT NULL,
    description    text,
    activity_kind  rwa.asset_kind,
    active         boolean     NOT NULL DEFAULT true,
    created_by     text        NOT NULL,
    created_at     timestamptz NOT NULL DEFAULT now(),
    updated_at     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT issuer_programs_created_by_wallet CHECK (created_by ~* '^0x[0-9a-f]{40}$')
);

-- 5.2 Requisitos de un ISSUER (documentos y/o claims previos)
CREATE TABLE IF NOT EXISTS rwa.issuer_program_requirements (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    issuer_program_id   uuid        NOT NULL REFERENCES rwa.issuer_programs(id) ON DELETE CASCADE,
    kind                rwa.requirement_kind NOT NULL,
    label               text        NOT NULL,
    credential_type_id  smallint    REFERENCES rwa.credential_types(id) ON DELETE RESTRICT,
    mime_allowlist      text[]      DEFAULT ARRAY['application/pdf','image/png','image/jpeg'],
    required            boolean     NOT NULL DEFAULT true,
    sort_order          smallint    NOT NULL DEFAULT 0,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT issuer_req_credential_fk CHECK (kind <> 'credential' OR credential_type_id IS NOT NULL),
    CONSTRAINT issuer_req_unique UNIQUE (issuer_program_id, kind, label)
);

-- 5.3 Claims que puede emitir cada ISSUER (N:M)
CREATE TABLE IF NOT EXISTS rwa.issuer_program_credentials (
    issuer_program_id   uuid        NOT NULL REFERENCES rwa.issuer_programs(id) ON DELETE CASCADE,
    credential_type_id  smallint    NOT NULL REFERENCES rwa.credential_types(id) ON DELETE RESTRICT,
    mandatory           boolean     NOT NULL DEFAULT true,
    PRIMARY KEY (issuer_program_id, credential_type_id)
);

-- 5.4 Emisores on-chain (caché verificada)
CREATE TABLE IF NOT EXISTS rwa.issuers (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    address             text        NOT NULL UNIQUE,
    display_name        text,
    issuer_program_id   uuid        REFERENCES rwa.issuer_programs(id) ON DELETE SET NULL,
    verified_at         timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT issuers_address_wallet CHECK (address ~* '^0x[0-9a-f]{40}$')
);

-- 5.5 Identidad del usuario en el Metaplace (seudónimo público)
CREATE TABLE IF NOT EXISTS rwa.identities (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_address  text        NOT NULL UNIQUE,
    display_alias   text        NOT NULL UNIQUE,
    status          text        NOT NULL DEFAULT 'active',
    kyc_level       smallint    NOT NULL DEFAULT 0,
    ended_at        timestamptz,                     -- fin de relación: dispara retención Q10
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT identities_wallet CHECK (wallet_address ~* '^0x[0-9a-f]{40}$'),
    CONSTRAINT identities_status CHECK (status IN ('active', 'suspended', 'recovering')),
    CONSTRAINT identities_kyc_level CHECK (kyc_level BETWEEN 0 AND 2)
);

-- 5.6 Solicitud y emisión de claims (Socio, Garantía, Fiador, KYC, …)
CREATE TABLE IF NOT EXISTS rwa.claim_requests (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_id         uuid        NOT NULL REFERENCES rwa.identities(id) ON DELETE CASCADE,
    issuer_program_id   uuid        NOT NULL REFERENCES rwa.issuer_programs(id) ON DELETE RESTRICT,
    credential_type_id  smallint    NOT NULL REFERENCES rwa.credential_types(id) ON DELETE RESTRICT,
    issuer_id           uuid        REFERENCES rwa.issuers(id) ON DELETE RESTRICT,   -- H-02: emisor concreto
    status              rwa.claim_status NOT NULL DEFAULT 'pending',
    requester_wallet    text        NOT NULL,
    requester_signature text,
    verified_by_wallet  text,                        -- H-09: Operador (verificación documental)
    verified_at         timestamptz,
    reviewed_by_wallet  text,                        -- H-09: Admin (aprobación)
    reviewed_at         timestamptz,
    issuer_signature    text,
    tx_hash             text,
    expires_at          timestamptz,                 -- Q8: NULL = sin caducidad en v3.0
    revoked_at          timestamptz,
    revocation_reason   text,
    metadata            jsonb       NOT NULL DEFAULT '{}'::jsonb,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT claim_requests_requester CHECK (requester_wallet ~* '^0x[0-9a-f]{40}$'),
    CONSTRAINT claim_requests_approved_consistent CHECK (
        status NOT IN ('approved')
        OR (reviewed_by_wallet IS NOT NULL AND reviewed_at IS NOT NULL AND issuer_signature IS NOT NULL
            AND verified_by_wallet IS NOT NULL AND verified_at IS NOT NULL AND issuer_id IS NOT NULL)
    ),
    CONSTRAINT claim_requests_revoked_consistent CHECK (
        status <> 'revoked' OR revoked_at IS NOT NULL
    ),
    -- H-06: nadie aprueba su propia solicitud
    CONSTRAINT claim_requests_no_self_approval CHECK (
        reviewed_by_wallet IS NULL OR reviewed_by_wallet <> requester_wallet
    ),
    -- H-09: el Operador que verifica no puede ser el Admin que aprueba
    CONSTRAINT claim_requests_segregation_of_duties CHECK (
        verified_by_wallet IS NULL OR reviewed_by_wallet IS NULL
        OR verified_by_wallet <> reviewed_by_wallet
    )
);

-- 5.7 Documentos KYC cifrados (AES-256-GCM)
CREATE TABLE IF NOT EXISTS rwa.document_files (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    claim_request_id    uuid        NOT NULL REFERENCES rwa.claim_requests(id) ON DELETE CASCADE,
    label               text        NOT NULL,
    mime_type           text        NOT NULL,
    size_bytes          integer     NOT NULL,
    sha256              char(64)    NOT NULL,
    encrypted_data      bytea       NOT NULL,
    encryption_meta     jsonb       NOT NULL DEFAULT '{}'::jsonb,
    retention_delete_at date,
    deleted_at          timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT document_files_size  CHECK (size_bytes > 0 AND size_bytes <= 20971520),
    -- PDF/PNG/JPEG según el brief; se admiten los dos formatos Word heredados de v2
    CONSTRAINT document_files_mime  CHECK (mime_type IN (
        'application/pdf', 'image/png', 'image/jpeg',
        'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document')),
    CONSTRAINT document_files_sha   CHECK (sha256 ~ '^[0-9a-f]{64}$')
);

-- 5.8 Recuperación asistida de identidad (Q5: non-custodial + doble aprobación)
CREATE TABLE IF NOT EXISTS rwa.identity_recovery_requests (
    id                     uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    identity_id            uuid        NOT NULL REFERENCES rwa.identities(id) ON DELETE CASCADE,
    old_wallet             text        NOT NULL,
    new_wallet             text        NOT NULL,
    status                 rwa.recovery_status NOT NULL DEFAULT 'requested',
    requested_by_wallet    text        NOT NULL,
    evidence_document_id   uuid        REFERENCES rwa.document_files(id) ON DELETE SET NULL,
    approved_by_wallet     text,
    second_approval_wallet text,
    approved_at            timestamptz,
    rejected_reason        text,
    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT recovery_old_wallet CHECK (old_wallet ~* '^0x[0-9a-f]{40}$'),
    CONSTRAINT recovery_new_wallet CHECK (new_wallet ~* '^0x[0-9a-f]{40}$'),
    CONSTRAINT recovery_distinct_wallets CHECK (old_wallet <> new_wallet),
    CONSTRAINT recovery_requester_wallet CHECK (requested_by_wallet ~* '^0x[0-9a-f]{40}$'),
    CONSTRAINT recovery_double_approval CHECK (
        status NOT IN ('approved', 'completed')
        OR (approved_by_wallet IS NOT NULL AND second_approval_wallet IS NOT NULL
            AND evidence_document_id IS NOT NULL)
    ),
    -- H-08: dos aprobadores distintos y ninguno es el solicitante (4-eyes real)
    CONSTRAINT recovery_four_eyes CHECK (
        approved_by_wallet IS NULL OR second_approval_wallet IS NULL
        OR approved_by_wallet <> second_approval_wallet
    ),
    CONSTRAINT recovery_approver_not_requester CHECK (
        (approved_by_wallet IS NULL OR approved_by_wallet <> requested_by_wallet)
        AND (second_approval_wallet IS NULL OR second_approval_wallet <> requested_by_wallet)
    )
);

-- -----------------------------------------------------------------------------
-- 6. Activos tokenizados
-- -----------------------------------------------------------------------------

-- 6.1 Registro off-chain del activo (producto / servicio / bien)
CREATE TABLE IF NOT EXISTS rwa.tokens (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    issuer_program_id   uuid        NOT NULL REFERENCES rwa.issuer_programs(id) ON DELETE RESTRICT,
    token_address       text        NOT NULL UNIQUE,
    on_chain_token_id   numeric(78,0),
    asset_kind          rwa.asset_kind NOT NULL,
    standard            rwa.asset_standard NOT NULL,
    name                text        NOT NULL,
    symbol              text,
    decimals            smallint,
    total_supply        numeric(30,8),
    unit                text,
    price_brlt          numeric(20,8),
    valued_brlt         numeric(20,8),
    metadata_uri        text,
    status              rwa.asset_status NOT NULL DEFAULT 'draft',
    minted_tx_hash      text,
    created_by          text        NOT NULL,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT tokens_address_wallet CHECK (token_address ~* '^0x[0-9a-f]{40}$'),
    CONSTRAINT tokens_creator_wallet CHECK (created_by ~* '^0x[0-9a-f]{40}$'),
    CONSTRAINT tokens_price_positive   CHECK (price_brlt IS NULL OR price_brlt > 0),
    CONSTRAINT tokens_valued_positive  CHECK (valued_brlt IS NULL OR valued_brlt > 0),
    -- Q9: el precio de listado no puede exceder la tasación documental
    CONSTRAINT tokens_price_leq_valued CHECK (
        valued_brlt IS NULL OR price_brlt IS NULL OR price_brlt <= valued_brlt
    ),
    CONSTRAINT tokens_good_has_token_id CHECK (
        asset_kind <> 'good' OR on_chain_token_id IS NOT NULL
    ),
    CONSTRAINT tokens_service_is_erc721 CHECK (
        asset_kind <> 'service' OR standard = 'erc721'
    )
);

-- 6.2 Claims exigidos por activo
CREATE TABLE IF NOT EXISTS rwa.token_required_claims (
    token_id            uuid        NOT NULL REFERENCES rwa.tokens(id) ON DELETE CASCADE,
    credential_type_id  smallint    NOT NULL REFERENCES rwa.credential_types(id) ON DELETE RESTRICT,
    PRIMARY KEY (token_id, credential_type_id)
);

-- 6.3 Módulos de compliance por activo
CREATE TABLE IF NOT EXISTS rwa.token_compliance_modules (
    token_id        uuid    NOT NULL REFERENCES rwa.tokens(id) ON DELETE CASCADE,
    module_address  text    NOT NULL,
    module_kind     text,
    PRIMARY KEY (token_id, module_address),
    CONSTRAINT token_compliance_module_address CHECK (module_address ~* '^0x[0-9a-f]{40}$')
);

-- 6.4 Garantía y Fiador del activo (precondición de tokenización)
CREATE TABLE IF NOT EXISTS rwa.token_guarantees (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    token_id            uuid        NOT NULL REFERENCES rwa.tokens(id) ON DELETE CASCADE,
    kind                rwa.guarantee_kind NOT NULL,
    identity_id         uuid        REFERENCES rwa.identities(id) ON DELETE SET NULL,
    claim_request_id    uuid        NOT NULL REFERENCES rwa.claim_requests(id) ON DELETE RESTRICT,  -- H-06
    verified            boolean     NOT NULL DEFAULT false,
    verified_at         timestamptz,
    validated_by_wallet text,                        -- quién verificó (Admin/emisor)
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT token_guarantees_unique UNIQUE (token_id, kind),
    CONSTRAINT token_guarantees_fiador_identity CHECK (
        kind <> 'fiador' OR identity_id IS NOT NULL
    ),
    CONSTRAINT token_guarantees_verified_meta CHECK (
        verified = false OR (verified_at IS NOT NULL AND validated_by_wallet IS NOT NULL)
    )
);

-- 6.5 Documentos del activo (tenencia, garantía, tasación, ficha técnica)
CREATE TABLE IF NOT EXISTS rwa.asset_documents (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    token_id        uuid        NOT NULL REFERENCES rwa.tokens(id) ON DELETE CASCADE,
    doc_kind        rwa.asset_doc_kind NOT NULL,
    mime_type       text        NOT NULL,
    size_bytes      integer     NOT NULL,
    sha256          char(64)    NOT NULL,
    encrypted_data  bytea       NOT NULL,
    encryption_meta jsonb       NOT NULL DEFAULT '{}'::jsonb,
    retention_delete_at date,
    deleted_at      timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT asset_documents_size CHECK (size_bytes > 0 AND size_bytes <= 20971520),
    CONSTRAINT asset_documents_mime CHECK (mime_type IN ('application/pdf', 'image/png', 'image/jpeg')),
    CONSTRAINT asset_documents_sha  CHECK (sha256 ~ '^[0-9a-f]{64}$')
);

-- -----------------------------------------------------------------------------
-- 7. Metaplace: publicaciones, órdenes y pagos
-- -----------------------------------------------------------------------------

-- 7.1 Publicación a precio fijo en BRLT (Q3)
CREATE TABLE IF NOT EXISTS rwa.listings (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    token_id            uuid        NOT NULL REFERENCES rwa.tokens(id) ON DELETE CASCADE,
    seller_identity_id  uuid        NOT NULL REFERENCES rwa.identities(id) ON DELETE RESTRICT,
    price_brlt          numeric(20,8) NOT NULL,
    quantity            numeric(30,8) NOT NULL DEFAULT 1,
    remaining_quantity  numeric(30,8) NOT NULL DEFAULT 1,
    currency            text        NOT NULL DEFAULT 'BRLT',
    -- v3.3: referencia on-chain de la publicación (Marketplace) y tx del escrow del activo
    on_chain_listing_id numeric(78,0),
    escrow_tx_hash      text,
    status              text        NOT NULL DEFAULT 'active',
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    closed_at           timestamptz,
    CONSTRAINT listings_price_positive CHECK (price_brlt > 0),
    CONSTRAINT listings_quantity_positive CHECK (quantity > 0),
    CONSTRAINT listings_currency CHECK (currency = 'BRLT'),
    CONSTRAINT listings_status CHECK (status IN ('active', 'paused', 'sold', 'cancelled')),
    CONSTRAINT listings_onchain_tx_format CHECK (escrow_tx_hash IS NULL OR escrow_tx_hash ~ '^0x[0-9a-f]{64}$')
);

-- 7.2 Órdenes (escrow y comisión)
CREATE TABLE IF NOT EXISTS rwa.orders (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id          uuid        NOT NULL REFERENCES rwa.listings(id) ON DELETE RESTRICT,
    buyer_identity_id   uuid        NOT NULL REFERENCES rwa.identities(id) ON DELETE RESTRICT,
    seller_identity_id  uuid        NOT NULL REFERENCES rwa.identities(id) ON DELETE RESTRICT,
    quantity            numeric(30,8) NOT NULL DEFAULT 1,
    price_brlt          numeric(20,8) NOT NULL,
    fee_brlt            numeric(20,8) NOT NULL DEFAULT 0,
    status              rwa.order_status NOT NULL DEFAULT 'pending_payment',
    escrow_tx_hash      text,
    escrow_asset_tx_hash text,                        -- B3: tramo NFT del escrow (transferencia atómica)
    asset_transferred_at timestamptz,                 -- B3: momento de la transferencia del activo
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),   -- requerido por el trigger global
    expires_at          timestamptz,                 -- H-05: TTL de la reserva
    confirmed_at        timestamptz,
    cancelled_at        timestamptz,
    CONSTRAINT orders_price_positive CHECK (price_brlt > 0),
    CONSTRAINT orders_quantity_positive CHECK (quantity > 0),
    CONSTRAINT orders_fee_valid CHECK (fee_brlt >= 0 AND fee_brlt <= price_brlt),
    CONSTRAINT orders_distinct_parties CHECK (buyer_identity_id <> seller_identity_id),
    CONSTRAINT orders_escrow_tx_format CHECK (escrow_tx_hash IS NULL OR escrow_tx_hash ~ '^0x[0-9a-f]{64}$')
);

-- 7.3 Pagos en BRLT
CREATE TABLE IF NOT EXISTS rwa.payments (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id            uuid        REFERENCES rwa.orders(id) ON DELETE SET NULL,
    payer_identity_id   uuid        REFERENCES rwa.identities(id) ON DELETE SET NULL,
    payee_wallet        text        NOT NULL,
    kind                rwa.payment_kind NOT NULL,
    amount_brlt         numeric(20,8) NOT NULL,
    fee_brlt            numeric(20,8) NOT NULL DEFAULT 0,
    status              rwa.payment_status NOT NULL DEFAULT 'pending',
    tx_hash             text,
    created_at          timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT payments_tx_format CHECK (tx_hash IS NULL OR tx_hash ~ '^0x[0-9a-f]{64}$'),
    CONSTRAINT payments_amount_positive CHECK (amount_brlt > 0),
    CONSTRAINT payments_fee_valid CHECK (fee_brlt >= 0),
    CONSTRAINT payments_payee_wallet CHECK (payee_wallet ~* '^0x[0-9a-f]{40}$')
);

-- 7.4 Disputas de órdenes (H-05: árbitro y resolución)
CREATE TABLE IF NOT EXISTS rwa.disputes (
    id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id              uuid        NOT NULL UNIQUE REFERENCES rwa.orders(id) ON DELETE CASCADE,
    opened_by_identity_id uuid        NOT NULL REFERENCES rwa.identities(id) ON DELETE RESTRICT,
    reason                text        NOT NULL,
    status                rwa.dispute_status NOT NULL DEFAULT 'open',
    arbiter_wallet        text,
    resolution            text,
    opened_at             timestamptz NOT NULL DEFAULT now(),
    resolved_at           timestamptz,
    CONSTRAINT disputes_resolved_meta CHECK (
        status NOT IN ('resolved_buyer', 'resolved_seller')
        OR (resolved_at IS NOT NULL AND arbiter_wallet IS NOT NULL AND resolution IS NOT NULL)
    )
);

-- -----------------------------------------------------------------------------
-- 8. Operación, sesiones y auditoría
-- -----------------------------------------------------------------------------

-- 8.1 Sesiones SIWE (roles v3: visitor/investor/issuer/operator/admin)
CREATE TABLE IF NOT EXISTS rwa.sessions (
    id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    nonce           text        NOT NULL UNIQUE,
    wallet_address  text        NOT NULL,
    role            rwa.session_role NOT NULL DEFAULT 'investor',
    domain          text        NOT NULL,
    issued_at       timestamptz NOT NULL DEFAULT now(),
    expires_at      timestamptz NOT NULL,
    revoked_at      timestamptz,
    CONSTRAINT sessions_wallet CHECK (wallet_address ~* '^0x[0-9a-f]{40}$'),
    CONSTRAINT sessions_expiry CHECK (expires_at > issued_at)
);

-- 8.2 B5: asignaciones de rol persistentes (principal ≠ claim)
CREATE TABLE IF NOT EXISTS rwa.role_assignments (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_address      text        NOT NULL,
    role                rwa.session_role NOT NULL,
    scope               text        NOT NULL DEFAULT 'platform',
    issuer_program_id   uuid        REFERENCES rwa.issuer_programs(id) ON DELETE CASCADE,
    granted_by_wallet   text        NOT NULL,
    granted_at          timestamptz NOT NULL DEFAULT now(),
    revoked_at          timestamptz,
    reason              text,
    CONSTRAINT role_assignments_wallet CHECK (wallet_address ~* '^0x[0-9a-f]{40}$'),
    CONSTRAINT role_assignments_granted_by CHECK (granted_by_wallet ~* '^0x[0-9a-f]{40}$'),
    CONSTRAINT role_assignments_scope CHECK (scope IN ('platform', 'issuer_program')),
    CONSTRAINT role_assignments_program_required CHECK (scope <> 'issuer_program' OR issuer_program_id IS NOT NULL),
    CONSTRAINT role_assignments_role_scope CHECK (
        scope = 'platform' OR role IN ('issuer', 'operator', 'auditor', 'arbiter')
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_role_assignments_platform
    ON rwa.role_assignments (lower(wallet_address), role)
    WHERE revoked_at IS NULL AND issuer_program_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_role_assignments_program
    ON rwa.role_assignments (lower(wallet_address), role, issuer_program_id)
    WHERE revoked_at IS NULL AND issuer_program_id IS NOT NULL;

-- 8.3 Auditoría (accesos y mutaciones)
CREATE TABLE IF NOT EXISTS rwa.audit_log (
    id             bigserial   PRIMARY KEY,
    actor_wallet   text,
    actor_role     text,
    action         text        NOT NULL,
    resource_type  text        NOT NULL,
    resource_id    text,
    request_id     text,
    ip             inet,
    metadata       jsonb       NOT NULL DEFAULT '{}'::jsonb,
    created_at     timestamptz NOT NULL DEFAULT now()
);

-- 8.3 Eventos on-chain indexados
CREATE TABLE IF NOT EXISTS rwa.chain_events (
    id                bigserial   PRIMARY KEY,
    chain_id          bigint      NOT NULL,
    block_number      bigint      NOT NULL,
    block_hash        text        NOT NULL,
    parent_hash       text,
    tx_hash           text        NOT NULL,
    log_index         integer     NOT NULL,
    event_name        text        NOT NULL,
    contract_address  text        NOT NULL,
    payload           jsonb       NOT NULL DEFAULT '{}'::jsonb,
    removed           boolean     NOT NULL DEFAULT false,
    created_at        timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT chain_events_unique UNIQUE (chain_id, tx_hash, log_index),
    CONSTRAINT chain_events_block_hash CHECK (block_hash ~ '^0x[0-9a-f]{64}$'),
    CONSTRAINT chain_events_tx_hash CHECK (tx_hash ~ '^0x[0-9a-f]{64}$')
);

-- 8.4 Estado del indexer (reanudable)
CREATE TABLE IF NOT EXISTS rwa.indexer_state (
    id              smallint    PRIMARY KEY DEFAULT 1,
    chain_id        bigint      NOT NULL DEFAULT 31337,
    last_block      bigint      NOT NULL DEFAULT 0,
    last_block_hash text,
    updated_at      timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT indexer_state_singleton CHECK (id = 1),
    CONSTRAINT indexer_state_block CHECK (last_block >= 0)
);

-- 8.5 Control de versiones del esquema
CREATE TABLE IF NOT EXISTS rwa.schema_migrations (
    version     text        PRIMARY KEY,
    description text,
    applied_at  timestamptz NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- 9. Índices (FK y búsqueda)
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS ix_credential_types_code        ON rwa.credential_types (code);
CREATE INDEX IF NOT EXISTS ix_issuer_req_program           ON rwa.issuer_program_requirements (issuer_program_id);
CREATE INDEX IF NOT EXISTS ix_issuers_program              ON rwa.issuers (issuer_program_id);
CREATE INDEX IF NOT EXISTS ix_claim_requests_identity      ON rwa.claim_requests (identity_id, status);
CREATE INDEX IF NOT EXISTS ix_claim_requests_credential    ON rwa.claim_requests (credential_type_id, status);
CREATE INDEX IF NOT EXISTS ix_claim_requests_program       ON rwa.claim_requests (issuer_program_id);
CREATE INDEX IF NOT EXISTS ix_claim_requests_created       ON rwa.claim_requests (created_at DESC);
CREATE INDEX IF NOT EXISTS ix_document_files_claim         ON rwa.document_files (claim_request_id);
CREATE INDEX IF NOT EXISTS ix_document_files_retention     ON rwa.document_files (retention_delete_at)
    WHERE deleted_at IS NULL AND retention_delete_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS ix_recovery_identity            ON rwa.identity_recovery_requests (identity_id, status);
CREATE INDEX IF NOT EXISTS ix_tokens_program               ON rwa.tokens (issuer_program_id);
CREATE INDEX IF NOT EXISTS ix_tokens_status                ON rwa.tokens (status);
CREATE INDEX IF NOT EXISTS ix_asset_documents_token        ON rwa.asset_documents (token_id, doc_kind);
CREATE INDEX IF NOT EXISTS ix_guarantees_token             ON rwa.token_guarantees (token_id);
CREATE INDEX IF NOT EXISTS ix_listings_active              ON rwa.listings (token_id, status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS ix_listings_seller              ON rwa.listings (seller_identity_id);
CREATE INDEX IF NOT EXISTS ix_orders_listing               ON rwa.orders (listing_id);
CREATE INDEX IF NOT EXISTS ix_orders_buyer                 ON rwa.orders (buyer_identity_id, status);
CREATE INDEX IF NOT EXISTS ix_payments_order               ON rwa.payments (order_id);
CREATE INDEX IF NOT EXISTS ix_sessions_wallet              ON rwa.sessions (wallet_address, expires_at DESC);
CREATE INDEX IF NOT EXISTS ix_audit_log_actor              ON rwa.audit_log (actor_wallet, created_at DESC);
CREATE INDEX IF NOT EXISTS ix_audit_log_resource           ON rwa.audit_log (resource_type, resource_id);
CREATE INDEX IF NOT EXISTS ix_audit_log_request            ON rwa.audit_log (request_id);
CREATE INDEX IF NOT EXISTS ix_chain_events_block           ON rwa.chain_events (block_number DESC);

-- Una sola solicitud pending por identidad y tipo de credencial
CREATE UNIQUE INDEX IF NOT EXISTS ux_claim_requests_pending
    ON rwa.claim_requests (identity_id, credential_type_id)
    WHERE status = 'pending';

-- Una sola publicación activa por token (v3.0: precio fijo)
CREATE UNIQUE INDEX IF NOT EXISTS ux_listings_one_active
    ON rwa.listings (token_id)
    WHERE status = 'active';

-- H-06: un solo claim aprobado por identidad y tipo de credencial
CREATE UNIQUE INDEX IF NOT EXISTS ux_claim_requests_approved
    ON rwa.claim_requests (identity_id, credential_type_id)
    WHERE status = 'approved';

-- H-05: una sola orden abierta por publicación (evita doble venta)
CREATE UNIQUE INDEX IF NOT EXISTS ux_orders_open
    ON rwa.orders (listing_id)
    WHERE status IN ('pending_payment', 'escrowed');

-- H-05: idempotencia de transacciones (escrow y pagos)
CREATE UNIQUE INDEX IF NOT EXISTS ux_orders_escrow_tx
    ON rwa.orders (escrow_tx_hash)
    WHERE escrow_tx_hash IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_payments_tx
    ON rwa.payments (tx_hash)
    WHERE tx_hash IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_issuers_address_lower   ON rwa.issuers (lower(address));
CREATE UNIQUE INDEX IF NOT EXISTS ux_identities_wallet_lower ON rwa.identities (lower(wallet_address));

CREATE INDEX IF NOT EXISTS ix_claim_requests_issuer  ON rwa.claim_requests (issuer_id);
CREATE INDEX IF NOT EXISTS ix_guarantees_claim       ON rwa.token_guarantees (claim_request_id);
CREATE INDEX IF NOT EXISTS ix_disputes_status        ON rwa.disputes (status, opened_at DESC);

-- -----------------------------------------------------------------------------
-- 10. Funciones y triggers
-- -----------------------------------------------------------------------------

-- 10.1 updated_at automático
CREATE OR REPLACE FUNCTION rwa.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DO $$
DECLARE
    t text;
    tablas text[] := ARRAY[
        'issuer_programs', 'identities', 'claim_requests',
        'identity_recovery_requests', 'tokens', 'listings', 'orders'
    ];
BEGIN
    FOREACH t IN ARRAY tablas LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_%1$s_updated_at ON rwa.%1$s', t);
        EXECUTE format(
            'CREATE TRIGGER trg_%1$s_updated_at BEFORE UPDATE ON rwa.%1$s
             FOR EACH ROW EXECUTE FUNCTION rwa.set_updated_at()', t);
    END LOOP;
END
$$;

-- 10.2 Regla fail-closed: un activo no puede pasar a 'minted' sin Garantía y Fiador verificados
CREATE OR REPLACE FUNCTION rwa.enforce_token_guarantees()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_count integer;
BEGIN
    IF NEW.status IN ('minted', 'listed', 'sold_out') THEN
        SELECT count(*) INTO v_count
        FROM rwa.token_guarantees
        WHERE token_id = NEW.id AND verified = true;
        IF v_count < 2 THEN
            RAISE EXCEPTION
                'token % requiere Garantía y Fiador verificados antes de %', NEW.id, NEW.status
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_tokens_guarantees ON rwa.tokens;
CREATE TRIGGER trg_tokens_guarantees
    BEFORE INSERT OR UPDATE OF status ON rwa.tokens
    FOR EACH ROW EXECUTE FUNCTION rwa.enforce_token_guarantees();

-- 10.3 Regla: el precio de listado no puede superar la tasación (Q9)
CREATE OR REPLACE FUNCTION rwa.enforce_listing_price_cap()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_valued numeric(20,8);
BEGIN
    SELECT valued_brlt INTO v_valued FROM rwa.tokens WHERE id = NEW.token_id;
    IF v_valued IS NOT NULL AND NEW.price_brlt > v_valued THEN
        RAISE EXCEPTION
            'precio % supera la tasación % del activo %', NEW.price_brlt, v_valued, NEW.token_id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_listings_price_cap ON rwa.listings;
CREATE TRIGGER trg_listings_price_cap
    BEFORE INSERT OR UPDATE OF price_brlt ON rwa.listings
    FOR EACH ROW EXECUTE FUNCTION rwa.enforce_listing_price_cap();

-- 10.4 H-06: al revocar un claim se invalidan sus garantías y se pausa el token
CREATE OR REPLACE FUNCTION rwa.cascade_claim_revocation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status = 'revoked' AND OLD.status <> 'revoked' THEN
        UPDATE rwa.token_guarantees
           SET verified = false
         WHERE claim_request_id = NEW.id;

        UPDATE rwa.tokens t
           SET status = 'paused'
         WHERE t.status IN ('minted', 'listed', 'sold_out')
           AND EXISTS (
               SELECT 1 FROM rwa.token_guarantees g
                WHERE g.token_id = t.id AND g.claim_request_id = NEW.id
           );

        -- N-06: cerrar el mercado de los activos afectados (no solo pausar el token)
        UPDATE rwa.listings l
           SET status = 'cancelled', closed_at = now()
         WHERE l.status IN ('active', 'paused')
           AND l.token_id IN (
               SELECT g.token_id FROM rwa.token_guarantees g WHERE g.claim_request_id = NEW.id
           );

        UPDATE rwa.orders o
           SET status = 'cancelled', cancelled_at = now()
         WHERE o.status IN ('pending_payment', 'escrowed')
           AND o.listing_id IN (
               SELECT l.id FROM rwa.listings l
                WHERE l.token_id IN (
                    SELECT g.token_id FROM rwa.token_guarantees g WHERE g.claim_request_id = NEW.id
                )
           );
    END IF;

    -- Q10: retención automática al resolver/rechazar
    IF NEW.status = 'rejected' AND OLD.status <> 'rejected' THEN
        UPDATE rwa.document_files
           SET retention_delete_at = current_date + 30
         WHERE claim_request_id = NEW.id AND retention_delete_at IS NULL;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_claim_revocation_cascade ON rwa.claim_requests;
CREATE TRIGGER trg_claim_revocation_cascade
    AFTER UPDATE OF status ON rwa.claim_requests
    FOR EACH ROW EXECUTE FUNCTION rwa.cascade_claim_revocation();

-- 10.5 H-06: una garantía solo se verifica con su claim aprobado, del tipo correcto
--             y sin que el fiador sea el creador del activo
CREATE OR REPLACE FUNCTION rwa.validate_token_guarantee()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_claim   rwa.claim_requests%ROWTYPE;
    v_cred    text;
    v_creator text;
    v_fiador  text;
BEGIN
    IF NEW.verified = false THEN
        RETURN NEW;
    END IF;

    SELECT * INTO v_claim FROM rwa.claim_requests WHERE id = NEW.claim_request_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'la garantía % referencia un claim inexistente', NEW.id
            USING ERRCODE = 'check_violation';
    END IF;
    IF v_claim.status <> 'approved' OR v_claim.revoked_at IS NOT NULL THEN
        RAISE EXCEPTION 'el claim % no está aprobado y vigente', NEW.claim_request_id
            USING ERRCODE = 'check_violation';
    END IF;

    SELECT upper(code) INTO v_cred FROM rwa.credential_types WHERE id = v_claim.credential_type_id;
    IF (NEW.kind = 'garantia' AND v_cred <> 'GARANTIA')
       OR (NEW.kind = 'fiador' AND v_cred <> 'FIADOR') THEN
        RAISE EXCEPTION 'el claim % no corresponde al tipo de garantía %', v_cred, NEW.kind
            USING ERRCODE = 'check_violation';
    END IF;

    IF NEW.kind = 'fiador' THEN
        SELECT created_by INTO v_creator FROM rwa.tokens WHERE id = NEW.token_id;
        SELECT wallet_address INTO v_fiador FROM rwa.identities WHERE id = NEW.identity_id;
        IF v_fiador IS NOT NULL AND v_fiador = v_creator THEN
            RAISE EXCEPTION 'el fiador no puede ser el creador del activo'
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    NEW.verified_at := coalesce(NEW.verified_at, now());
    NEW.validated_by_wallet := coalesce(NEW.validated_by_wallet, v_claim.reviewed_by_wallet);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_token_guarantee ON rwa.token_guarantees;
CREATE TRIGGER trg_validate_token_guarantee
    BEFORE INSERT OR UPDATE OF verified ON rwa.token_guarantees
    FOR EACH ROW EXECUTE FUNCTION rwa.validate_token_guarantee();

-- 10.5b N-05: el emisor que firma debe pertenecer al programa del claim
CREATE OR REPLACE FUNCTION rwa.validate_claim_issuer_program()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_program uuid;
BEGIN
    IF NEW.issuer_id IS NOT NULL THEN
        SELECT issuer_program_id INTO v_program FROM rwa.issuers WHERE id = NEW.issuer_id;
        IF v_program IS DISTINCT FROM NEW.issuer_program_id THEN
            RAISE EXCEPTION 'el emisor % no pertenece al programa %', NEW.issuer_id, NEW.issuer_program_id
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_claim_issuer_program ON rwa.claim_requests;
CREATE TRIGGER trg_claim_issuer_program
    BEFORE INSERT OR UPDATE OF issuer_id, issuer_program_id, status ON rwa.claim_requests
    FOR EACH ROW EXECUTE FUNCTION rwa.validate_claim_issuer_program();

-- 10.5c N-06: no se puede listar un activo draft/paused ni sin Garantía+Fiador
CREATE OR REPLACE FUNCTION rwa.validate_listing_token()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_status rwa.asset_status;
    v_guarantees integer;
BEGIN
    SELECT status INTO v_status FROM rwa.tokens WHERE id = NEW.token_id;
    IF v_status IS NULL THEN
        RAISE EXCEPTION 'activo % inexistente', NEW.token_id USING ERRCODE = 'check_violation';
    END IF;
    IF v_status NOT IN ('minted', 'listed') THEN
        RAISE EXCEPTION 'no se puede publicar un activo en estado %', v_status USING ERRCODE = 'check_violation';
    END IF;
    SELECT count(*) INTO v_guarantees
      FROM rwa.token_guarantees WHERE token_id = NEW.token_id AND verified = true;
    IF v_guarantees < 2 THEN
        RAISE EXCEPTION 'el activo % no tiene Garantía y Fiador verificados', NEW.token_id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_listing_token ON rwa.listings;
CREATE TRIGGER trg_validate_listing_token
    BEFORE INSERT ON rwa.listings
    FOR EACH ROW EXECUTE FUNCTION rwa.validate_listing_token();

-- 10.5d Q10: al cerrar la relación con una identidad, sus documentos se purgan a los 12 meses
CREATE OR REPLACE FUNCTION rwa.apply_retention_on_identity_end()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.ended_at IS NOT NULL AND OLD.ended_at IS NULL THEN
        UPDATE rwa.document_files df
           SET retention_delete_at = current_date + 365
          FROM rwa.claim_requests cr
         WHERE df.claim_request_id = cr.id
           AND cr.identity_id = NEW.id
           AND df.retention_delete_at IS NULL;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_identity_end_retention ON rwa.identities;
CREATE TRIGGER trg_identity_end_retention
    AFTER UPDATE OF ended_at ON rwa.identities
    FOR EACH ROW EXECUTE FUNCTION rwa.apply_retention_on_identity_end();

-- 10.6 H-05: reserva de inventario y consumo al confirmar la orden
CREATE OR REPLACE FUNCTION rwa.reserve_listing_inventory()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_listing rwa.listings%ROWTYPE;
BEGIN
    SELECT * INTO v_listing FROM rwa.listings WHERE id = NEW.listing_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'publicación % inexistente', NEW.listing_id USING ERRCODE = 'check_violation';
    END IF;
    IF v_listing.status <> 'active' THEN
        RAISE EXCEPTION 'la publicación % no está activa', NEW.listing_id USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.quantity > v_listing.remaining_quantity THEN
        RAISE EXCEPTION 'cantidad % supera el remanente %', NEW.quantity, v_listing.remaining_quantity
            USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.expires_at IS NULL THEN
        NEW.expires_at := now() + interval '30 minutes';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reserve_listing_inventory ON rwa.orders;
CREATE TRIGGER trg_reserve_listing_inventory
    BEFORE INSERT ON rwa.orders
    FOR EACH ROW EXECUTE FUNCTION rwa.reserve_listing_inventory();

CREATE OR REPLACE FUNCTION rwa.consume_listing_inventory()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status = 'confirmed' AND OLD.status <> 'confirmed' THEN
        UPDATE rwa.listings
           SET remaining_quantity = remaining_quantity - NEW.quantity,
               status = CASE WHEN remaining_quantity - NEW.quantity <= 0 THEN 'sold' ELSE status END,
               closed_at = CASE WHEN remaining_quantity - NEW.quantity <= 0 THEN now() ELSE closed_at END
         WHERE id = NEW.listing_id;

        UPDATE rwa.tokens t
           SET status = 'sold_out'
         WHERE t.id = (SELECT token_id FROM rwa.listings WHERE id = NEW.listing_id)
           AND NOT EXISTS (
               SELECT 1 FROM rwa.listings l
                WHERE l.id = NEW.listing_id AND l.remaining_quantity > 0
           );
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_consume_listing_inventory ON rwa.orders;
CREATE TRIGGER trg_consume_listing_inventory
    AFTER UPDATE OF status ON rwa.orders
    FOR EACH ROW EXECUTE FUNCTION rwa.consume_listing_inventory();

-- 10.7 B3: máquina de estados de la orden (solo transiciones válidas)
CREATE OR REPLACE FUNCTION rwa.validate_order_transition()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    allowed boolean := false;
BEGIN
    IF NEW.status = OLD.status THEN
        RETURN NEW;
    END IF;
    allowed := (OLD.status = 'pending_payment' AND NEW.status IN ('escrowed', 'cancelled'))
            OR (OLD.status = 'escrowed'        AND NEW.status IN ('confirmed', 'cancelled', 'disputed'))
            OR (OLD.status = 'disputed'        AND NEW.status IN ('confirmed', 'refunded'));
    IF NOT allowed THEN
        RAISE EXCEPTION 'transición de orden inválida: % → %', OLD.status, NEW.status
            USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.status = 'confirmed' THEN
        -- F-04: confirmar exige los DOS tramos del escrow (BRLT + activo)
        IF NEW.escrow_tx_hash IS NULL OR NEW.escrow_asset_tx_hash IS NULL
           OR NEW.asset_transferred_at IS NULL THEN
            RAISE EXCEPTION 'no se puede confirmar sin los dos tramos del escrow (BRLT + activo)'
                USING ERRCODE = 'check_violation';
        END IF;
        NEW.confirmed_at := coalesce(NEW.confirmed_at, now());
    ELSIF NEW.status = 'cancelled' THEN
        NEW.cancelled_at := coalesce(NEW.cancelled_at, now());
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_order_transition ON rwa.orders;
CREATE TRIGGER trg_validate_order_transition
    BEFORE UPDATE OF status ON rwa.orders
    FOR EACH ROW EXECUTE FUNCTION rwa.validate_order_transition();

-- 10.8 B3: la orden fija vendedor/comisión desde la publicación y la tarifa vigente
CREATE OR REPLACE FUNCTION rwa.set_order_economics()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_listing rwa.listings%ROWTYPE;
    v_bps     smallint;
BEGIN
    SELECT * INTO v_listing FROM rwa.listings WHERE id = NEW.listing_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'publicación % inexistente', NEW.listing_id USING ERRCODE = 'check_violation';
    END IF;
    NEW.seller_identity_id := v_listing.seller_identity_id;
    NEW.price_brlt := coalesce(NEW.price_brlt, v_listing.price_brlt);
    SELECT sale_fee_bps INTO v_bps FROM rwa.platform_fees WHERE active LIMIT 1;
    NEW.fee_brlt := round(NEW.price_brlt * coalesce(v_bps, 0) / 10000.0, 8);
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_order_economics ON rwa.orders;
CREATE TRIGGER trg_set_order_economics
    BEFORE INSERT ON rwa.orders
    FOR EACH ROW EXECUTE FUNCTION rwa.set_order_economics();

-- 10.9 B3: el pago al vendedor debe ser la wallet del vendedor de la orden
CREATE OR REPLACE FUNCTION rwa.validate_payment_payee()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_wallet text;
BEGIN
    IF NEW.order_id IS NOT NULL THEN
        SELECT i.wallet_address INTO v_wallet
          FROM rwa.orders o
          JOIN rwa.identities i ON i.id = o.seller_identity_id
         WHERE o.id = NEW.order_id;
        IF v_wallet IS NOT NULL AND lower(NEW.payee_wallet) <> v_wallet THEN
            RAISE EXCEPTION 'el pago debe ir a la wallet del vendedor (%), no a %', v_wallet, NEW.payee_wallet
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_payment_payee ON rwa.payments;
CREATE TRIGGER trg_validate_payment_payee
    BEFORE INSERT ON rwa.payments
    FOR EACH ROW EXECUTE FUNCTION rwa.validate_payment_payee();

-- 10.9b F-05: al venderse el activo, sus documentos se purgan a los 12 meses
CREATE OR REPLACE FUNCTION rwa.apply_asset_retention_on_sale()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status = 'sold_out' AND OLD.status <> 'sold_out' THEN
        UPDATE rwa.asset_documents
           SET retention_delete_at = current_date + 365
         WHERE token_id = NEW.id AND retention_delete_at IS NULL;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_asset_retention_on_sale ON rwa.tokens;
CREATE TRIGGER trg_asset_retention_on_sale
    AFTER UPDATE OF status ON rwa.tokens
    FOR EACH ROW EXECUTE FUNCTION rwa.apply_asset_retention_on_sale();

-- 10.10 B5: audit_log append-only (sin UPDATE ni DELETE)
CREATE OR REPLACE FUNCTION rwa.audit_log_append_only()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'audit_log es append-only: % no permitido', TG_OP
        USING ERRCODE = 'insufficient_privilege';
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_log_append_only ON rwa.audit_log;
CREATE TRIGGER trg_audit_log_append_only
    BEFORE UPDATE OR DELETE ON rwa.audit_log
    FOR EACH ROW EXECUTE FUNCTION rwa.audit_log_append_only();

-- 10.11 B3/B7: jobs invocables por Cloud Scheduler (funciones de base de datos)
--        expire_orders: cancela reservas vencidas y libera inventario
--        purge_expired_documents: borra documentos fuera de retención (Q10)
CREATE OR REPLACE FUNCTION rwa.expire_orders()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_count integer;
BEGIN
    WITH expired AS (
        UPDATE rwa.orders
           SET status = 'cancelled', cancelled_at = now()
         WHERE status IN ('pending_payment', 'escrowed')
           AND expires_at IS NOT NULL
           AND expires_at <= now()
        RETURNING id
    )
    SELECT count(*) INTO v_count FROM expired;
    RETURN v_count;
END;
$$;

CREATE OR REPLACE FUNCTION rwa.purge_expired_documents()
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    v_docs   integer := 0;
    v_assets integer := 0;
BEGIN
    DELETE FROM rwa.document_files
     WHERE deleted_at IS NULL
       AND retention_delete_at IS NOT NULL
       AND retention_delete_at <= current_date;
    GET DIAGNOSTICS v_docs = ROW_COUNT;

    DELETE FROM rwa.asset_documents
     WHERE deleted_at IS NULL
       AND retention_delete_at IS NOT NULL
       AND retention_delete_at <= current_date;
    GET DIAGNOSTICS v_assets = ROW_COUNT;

    -- La app registra document.purge en audit_log con v_docs + v_assets
    RETURN v_docs + v_assets;
END;
$$;

-- -----------------------------------------------------------------------------
-- 11. Vistas
-- -----------------------------------------------------------------------------

-- 11.1 Resumen de solicitudes de claim
CREATE OR REPLACE VIEW rwa.v_claim_request_summary AS
SELECT
    cr.id,
    cr.status,
    i.display_alias                            AS solicitante,
    ct.code                                    AS credencial,
    ip.name                                    AS issuer_program,
    cr.reviewed_by_wallet,
    cr.reviewed_at,
    cr.expires_at,
    cr.revoked_at,
    cr.created_at
FROM rwa.claim_requests cr
JOIN rwa.identities i          ON i.id = cr.identity_id
JOIN rwa.credential_types ct   ON ct.id = cr.credential_type_id
JOIN rwa.issuer_programs ip    ON ip.id = cr.issuer_program_id;

-- 11.2 Catálogo del Metaplace
CREATE OR REPLACE VIEW rwa.v_asset_catalog AS
SELECT
    t.id,
    t.asset_kind,
    t.standard,
    t.name,
    t.symbol,
    t.total_supply,
    t.unit,
    t.price_brlt,
    t.valued_brlt,
    t.status,
    ip.name                                    AS issuer_program,
    l.id                                       AS listing_id,
    l.price_brlt                               AS listing_price_brlt,
    l.quantity                                 AS listing_quantity,
    (SELECT count(*) FROM rwa.token_guarantees g
      WHERE g.token_id = t.id AND g.verified)  AS garantias_verificadas
FROM rwa.tokens t
JOIN rwa.issuer_programs ip ON ip.id = t.issuer_program_id
LEFT JOIN rwa.listings l ON l.token_id = t.id AND l.status = 'active';

-- 11.3 Resumen de órdenes
CREATE OR REPLACE VIEW rwa.v_order_summary AS
SELECT
    o.id,
    o.status,
    b.display_alias  AS comprador,
    s.display_alias  AS vendedor,
    t.name           AS activo,
    o.price_brlt,
    o.fee_brlt,
    o.escrow_tx_hash,
    o.created_at,
    o.confirmed_at
FROM rwa.orders o
JOIN rwa.identities b ON b.id = o.buyer_identity_id
JOIN rwa.identities s ON s.id = o.seller_identity_id
JOIN rwa.listings l   ON l.id = o.listing_id
JOIN rwa.tokens t     ON t.id = l.token_id;

-- 11.4 Documentos pendientes de purga (Q10)
CREATE OR REPLACE VIEW rwa.v_documents_due_deletion AS
SELECT id, claim_request_id, retention_delete_at
FROM rwa.document_files
WHERE deleted_at IS NULL
  AND retention_delete_at IS NOT NULL
  AND retention_delete_at <= current_date;

-- -----------------------------------------------------------------------------
-- 12. Comentarios
-- -----------------------------------------------------------------------------
COMMENT ON SCHEMA rwa IS 'Esquema off-chain de RWA v3 «Barlo Metaplace» (PostgreSQL 15).';
COMMENT ON TABLE rwa.jurisdictions IS 'Países soportados (Q7: piloto LatAm; el Admin habilita más).';
COMMENT ON TABLE rwa.credential_types IS 'Catálogo extensible de claims; sustituye claim_topics de v2.';
COMMENT ON TABLE rwa.platform_fees IS 'Comisión por venta (bps) y fee de tokenización en BRLT (Q4).';
COMMENT ON TABLE rwa.wallet_messages IS 'Plantillas de mensajes de firma en lenguaje llano (RF-V3-21).';
COMMENT ON TABLE rwa.issuer_programs IS 'ISSUER: proceso + requisitos + claims que puede emitir.';
COMMENT ON TABLE rwa.claim_requests IS 'Solicitud y emisión de credenciales; sin caducidad en v3.0 (Q8).';
COMMENT ON TABLE rwa.document_files IS 'Documentos KYC cifrados AES-256-GCM con retención (Q10).';
COMMENT ON TABLE rwa.identity_recovery_requests IS 'Recuperación asistida non-custodial con doble aprobación (Q5).';
COMMENT ON TABLE rwa.tokens IS 'Registro off-chain del activo tokenizado (producto/servicio/bien).';
COMMENT ON TABLE rwa.token_guarantees IS 'Precondición de tokenización: Garantía y Fiador verificados.';
COMMENT ON TABLE rwa.listings IS 'Publicación a precio fijo en BRLT (Q3).';
COMMENT ON TABLE rwa.orders IS 'Órdenes de compra/venta con escrow y comisión.';
COMMENT ON TABLE rwa.payments IS 'Pagos en BRLT: ventas, fee de tokenización y reembolsos.';
COMMENT ON TABLE rwa.disputes IS 'Disputas de órdenes y resolución por árbitro (H-05).';
COMMENT ON COLUMN rwa.claim_requests.issuer_id IS 'Emisor concreto que firma el claim (H-02).';
COMMENT ON COLUMN rwa.claim_requests.verified_by_wallet IS 'Operador que verifica documentos (H-09).';
COMMENT ON COLUMN rwa.claim_requests.reviewed_by_wallet IS 'Admin que aprueba y emite (H-09).';
COMMENT ON COLUMN rwa.orders.quantity IS 'Unidades compradas (ERC-1155 / lotes).';
COMMENT ON COLUMN rwa.orders.expires_at IS 'TTL de la reserva (H-05).';
COMMENT ON COLUMN rwa.chain_events.chain_id IS 'Cadena del evento (detección de reset/reorg, H-13).';
COMMENT ON COLUMN rwa.indexer_state.last_block_hash IS 'Hash del último bloque para detectar reorg/reset (H-13).';
COMMENT ON COLUMN rwa.issuers.address IS 'Direcciones semilla SOLO DEV (Anvil); rotar en C0 (H-11).';
COMMENT ON COLUMN rwa.claim_requests.expires_at IS 'Q8: NULL = sin caducidad en v3.0; preparado para v3.1.';
COMMENT ON COLUMN rwa.document_files.retention_delete_at IS 'Q10: 30 días tras rechazo; 12 meses tras fin de relación.';
COMMENT ON COLUMN rwa.identities.ended_at IS 'Fin de relación: dispara la retención Q10 (+12 meses) de sus documentos.';
COMMENT ON COLUMN rwa.orders.updated_at IS 'Requerido por el trigger global de updated_at (N-01).';
COMMENT ON COLUMN rwa.tokens.valued_brlt IS 'Q9: tasación documental en BRLT; tope del precio de listado.';

-- -----------------------------------------------------------------------------
-- 13. Datos semilla (reejecutables)
-- -----------------------------------------------------------------------------
INSERT INTO rwa.jurisdictions (iso2, name, enabled) VALUES
    ('VE', 'Venezuela', true),
    ('CO', 'Colombia', true),
    ('PA', 'Panamá', true),
    ('MX', 'México', true),
    ('CL', 'Chile', true),
    ('PE', 'Perú', true),
    ('AR', 'Argentina', true)
ON CONFLICT (iso2) DO NOTHING;

INSERT INTO rwa.credential_types (code, name, description, on_chain_topic, validity_days) VALUES
    ('KYC',          'Identidad verificada',  'Documento de identidad y domicilio verificados', 1,  NULL),
    ('ACREDITACION', 'Inversor acreditado',   'Acredita la condición de inversor acreditado',   7,  NULL),
    ('JURISDICCION', 'Jurisdicción',          'País de residencia declarado y verificado',      9,  NULL),
    ('SOCIO',        'Socio del Metaplace',   'Certificado de membresía (KYC avanzado)',        10, NULL),
    ('GARANTIA',     'Certificado de Garantía','Respalda un activo real para tokenizar',        11, NULL),
    ('FIADOR',       'Certificado de Fiador', 'Acredita la idoneidad del fiador del emisor',    12, NULL)
ON CONFLICT (code) DO NOTHING;

INSERT INTO rwa.platform_fees (id, sale_fee_bps, tokenization_fee_brlt, active)
VALUES (1, 500, 50.00000000, true)
ON CONFLICT (id) DO NOTHING;

-- Cuentas semilla SOLO DEV (Anvil, chain 31337). En C0 se sustituyen por claves
-- dedicadas en Secret Manager; el gate de CI rechaza cuentas conocidas de Anvil (H-11).
INSERT INTO rwa.issuer_programs (slug, name, description, activity_kind, created_by) VALUES
    ('kyc-base', 'Verificación KYC base',
     'Verificación documental inicial: identidad y domicilio. Operado por el Operador y aprobado por el Admin.',
     NULL, '0x70997970c51812dc3a010c7d01b50e0d17dc79c8'),
    ('onboarding-socio', 'Alta y certificación de Socio',
     'Emite el claim SOCIO tras completar el KYC avanzado (requiere KYC base previo).',
     NULL, '0x70997970c51812dc3a010c7d01b50e0d17dc79c8'),
    ('garantia-activos', 'Certificación de Garantía',
     'Título de propiedad, tasación y emisión del claim GARANTIA.', NULL,
     '0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc'),
    ('fiador', 'Certificación de Fiador',
     'Estados financieros y referencias para emitir el claim FIADOR.', NULL,
     '0x90f79bf6eb2c4f870365e785982e1f101e93b906'),
    ('legacy-v2', 'Migración desde v2',
     'Programa contenedor para claims y activos heredados de la versión 2 (solo migración).',
     NULL, '0x70997970c51812dc3a010c7d01b50e0d17dc79c8')
ON CONFLICT (slug) DO NOTHING;

-- Emisores on-chain de desarrollo (H-02: el emisor se persiste y se vincula al claim)
INSERT INTO rwa.issuers (address, display_name, issuer_program_id, verified_at)
SELECT '0x70997970c51812dc3a010c7d01b50e0d17dc79c8', 'Emisor KYC/Socio (dev)', id, now()
FROM rwa.issuer_programs WHERE slug = 'kyc-base'
ON CONFLICT (address) DO NOTHING;

INSERT INTO rwa.issuers (address, display_name, issuer_program_id, verified_at)
SELECT '0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc', 'Emisor Garantía (dev)', id, now()
FROM rwa.issuer_programs WHERE slug = 'garantia-activos'
ON CONFLICT (address) DO NOTHING;

INSERT INTO rwa.issuers (address, display_name, issuer_program_id, verified_at)
SELECT '0x90f79bf6eb2c4f870365e785982e1f101e93b906', 'Emisor Fiador (dev)', id, now()
FROM rwa.issuer_programs WHERE slug = 'fiador'
ON CONFLICT (address) DO NOTHING;

-- N-04: emisor dedicado del programa SOCIO (distinto del emisor KYC)
INSERT INTO rwa.issuers (address, display_name, issuer_program_id, verified_at)
SELECT '0x9965507d1a55bcc2695c58ba16fb37d819b0a4dc', 'Emisor Socio (dev)', id, now()
FROM rwa.issuer_programs WHERE slug = 'onboarding-socio'
ON CONFLICT (address) DO NOTHING;

-- N-04: emisor contenedor para datos migrados de v2
INSERT INTO rwa.issuers (address, display_name, issuer_program_id, verified_at)
SELECT '0x976ea74026e726554db657fa54763abd0c3a0aa9', 'Emisor legacy v2 (dev)', id, now()
FROM rwa.issuer_programs WHERE slug = 'legacy-v2'
ON CONFLICT (address) DO NOTHING;

INSERT INTO rwa.issuer_program_credentials (issuer_program_id, credential_type_id, mandatory)
SELECT p.id, c.id, true
FROM rwa.issuer_programs p
JOIN rwa.credential_types c ON c.code = 'KYC'
WHERE p.slug = 'kyc-base'
ON CONFLICT DO NOTHING;

INSERT INTO rwa.issuer_program_credentials (issuer_program_id, credential_type_id, mandatory)
SELECT p.id, c.id, true
FROM rwa.issuer_programs p
JOIN rwa.credential_types c ON c.code = 'SOCIO'
WHERE p.slug = 'onboarding-socio'
ON CONFLICT DO NOTHING;

INSERT INTO rwa.issuer_program_credentials (issuer_program_id, credential_type_id, mandatory)
SELECT p.id, c.id, true
FROM rwa.issuer_programs p
JOIN rwa.credential_types c ON c.code = 'GARANTIA'
WHERE p.slug = 'garantia-activos'
ON CONFLICT DO NOTHING;

INSERT INTO rwa.issuer_program_credentials (issuer_program_id, credential_type_id, mandatory)
SELECT p.id, c.id, true
FROM rwa.issuer_programs p
JOIN rwa.credential_types c ON c.code = 'FIADOR'
WHERE p.slug = 'fiador'
ON CONFLICT DO NOTHING;

-- Requisitos de ejemplo por ISSUER
INSERT INTO rwa.issuer_program_requirements (issuer_program_id, kind, label, credential_type_id, required, sort_order)
SELECT p.id, 'document', 'Documento de identidad (anverso y reverso)', NULL, true, 1
FROM rwa.issuer_programs p WHERE p.slug = 'kyc-base'
ON CONFLICT DO NOTHING;

INSERT INTO rwa.issuer_program_requirements (issuer_program_id, kind, label, credential_type_id, required, sort_order)
SELECT p.id, 'document', 'Comprobante de domicilio', NULL, true, 2
FROM rwa.issuer_programs p WHERE p.slug = 'kyc-base'
ON CONFLICT DO NOTHING;

INSERT INTO rwa.issuer_program_requirements (issuer_program_id, kind, label, credential_type_id, required, sort_order)
SELECT p.id, 'document', 'Documento de identidad (anverso y reverso)', NULL, true, 1
FROM rwa.issuer_programs p WHERE p.slug = 'onboarding-socio'
ON CONFLICT DO NOTHING;

INSERT INTO rwa.issuer_program_requirements (issuer_program_id, kind, label, credential_type_id, required, sort_order)
SELECT p.id, 'document', 'Comprobante de domicilio', NULL, true, 2
FROM rwa.issuer_programs p WHERE p.slug = 'onboarding-socio'
ON CONFLICT DO NOTHING;

INSERT INTO rwa.issuer_program_requirements (issuer_program_id, kind, label, credential_type_id, required, sort_order)
SELECT p.id, 'credential', 'Tener el KYC base aprobado', c.id, true, 3
FROM rwa.issuer_programs p, rwa.credential_types c
WHERE p.slug = 'onboarding-socio' AND c.code = 'KYC'
ON CONFLICT DO NOTHING;

INSERT INTO rwa.issuer_program_requirements (issuer_program_id, kind, label, credential_type_id, required, sort_order)
SELECT p.id, 'document', 'Título de propiedad del activo', NULL, true, 1
FROM rwa.issuer_programs p WHERE p.slug = 'garantia-activos'
ON CONFLICT DO NOTHING;

INSERT INTO rwa.issuer_program_requirements (issuer_program_id, kind, label, credential_type_id, required, sort_order)
SELECT p.id, 'document', 'Tasación del activo en BRLT', NULL, true, 2
FROM rwa.issuer_programs p WHERE p.slug = 'garantia-activos'
ON CONFLICT DO NOTHING;

INSERT INTO rwa.issuer_program_requirements (issuer_program_id, kind, label, credential_type_id, required, sort_order)
SELECT p.id, 'credential', 'Ser Socio del Metaplace', c.id, true, 3
FROM rwa.issuer_programs p, rwa.credential_types c
WHERE p.slug = 'garantia-activos' AND c.code = 'SOCIO'
ON CONFLICT DO NOTHING;

INSERT INTO rwa.issuer_program_requirements (issuer_program_id, kind, label, credential_type_id, required, sort_order)
SELECT p.id, 'document', 'Estados financieros del fiador', NULL, true, 1
FROM rwa.issuer_programs p WHERE p.slug = 'fiador'
ON CONFLICT DO NOTHING;

INSERT INTO rwa.issuer_program_requirements (issuer_program_id, kind, label, credential_type_id, required, sort_order)
SELECT p.id, 'credential', 'Ser Socio del Metaplace', c.id, true, 2
FROM rwa.issuer_programs p, rwa.credential_types c
WHERE p.slug = 'fiador' AND c.code = 'SOCIO'
ON CONFLICT DO NOTHING;

-- Plantillas de mensajes de billetera (es)
INSERT INTO rwa.wallet_messages (process_key, locale, title, template, variables, version) VALUES
    ('identity.create', 'es', 'Crear tu identidad en Barlo',
     'Vas a crear tu identidad en Barlo. No compartimos tus datos ni el saldo de tu billetera con nadie.',
     '[]'::jsonb, 1),
    ('claim.request', 'es', 'Solicitar un certificado',
     'Vas a pedir tu certificado de {credencial}. Revisaremos tus documentos y te avisaremos.',
     '["credencial"]'::jsonb, 1),
    ('claim.issue', 'es', 'Emitir un certificado',
     'Firmas que {emisor} certifica que cumples los requisitos de {credencial}.',
     '["emisor","credencial"]'::jsonb, 1),
    ('asset.tokenize', 'es', 'Crear un activo digital',
     'Vas a crear {cantidad} {unidad} de {activo}, respaldados por el certificado de Garantía.',
     '["cantidad","unidad","activo"]'::jsonb, 1),
    ('order.buy', 'es', 'Comprar en el Metaplace',
     'Compras {activo} por {precio} BRLT. El pago queda retenido hasta que confirmes la recepción.',
     '["activo","precio"]'::jsonb, 1),
    ('service.consume', 'es', 'Usar un servicio',
     'Confirmas que usaste {servicio}; su certificado digital se destruye.',
     '["servicio"]'::jsonb, 1),
    ('identity.recovery', 'es', 'Recuperar tu identidad',
     'Pides recuperar tu identidad. Un administrador revisará tu caso y te contactará.',
     '[]'::jsonb, 1)
ON CONFLICT (process_key, locale, version) DO NOTHING;

INSERT INTO rwa.wallet_messages (process_key, locale, title, template, variables, version) VALUES
    ('identity.create', 'en', 'Create your Barlo identity',
     'You are creating your Barlo identity. We never share your data or your wallet balance.',
     '[]'::jsonb, 1),
    ('claim.request', 'en', 'Request a certificate',
     'You are requesting your {credencial} certificate. We will review your documents and let you know.',
     '["credencial"]'::jsonb, 1),
    ('claim.issue', 'en', 'Issue a certificate',
     'You sign that {emisor} certifies you meet the requirements for {credencial}.',
     '["emisor","credencial"]'::jsonb, 1),
    ('asset.tokenize', 'en', 'Create a digital asset',
     'You are creating {cantidad} {unidad} of {activo}, backed by the Guarantee certificate.',
     '["cantidad","unidad","activo"]'::jsonb, 1),
    ('order.buy', 'en', 'Buy in the Metaplace',
     'You buy {activo} for {precio} BRLT. Payment is held until you confirm reception.',
     '["activo","precio"]'::jsonb, 1),
    ('service.consume', 'en', 'Use a service',
     'You confirm you used {servicio}; its digital certificate is destroyed.',
     '["servicio"]'::jsonb, 1),
    ('identity.recovery', 'en', 'Recover your identity',
     'You are requesting identity recovery. An administrator will review your case and contact you.',
     '[]'::jsonb, 1),
    ('guarantee.consent', 'es', 'Respaldar un activo',
     'Vas a aceptar respaldar {activo} como fiador. Podrás revocar el respaldo antes de la venta.',
     '["activo"]'::jsonb, 1),
    ('guarantee.consent', 'en', 'Back an asset',
     'You are accepting to back {activo} as guarantor. You can revoke it before the sale.',
     '["activo"]'::jsonb, 1)
ON CONFLICT (process_key, locale, version) DO NOTHING;

-- B5: cuentas semilla por rol (SOLO DEV; rotar en C0, H-11)
INSERT INTO rwa.role_assignments (wallet_address, role, scope, issuer_program_id, granted_by_wallet, reason)
VALUES
    ('0x14dc79964da2c08b23698b3d3cc7ca32193d9955', 'admin',   'platform', NULL,
     '0x14dc79964da2c08b23698b3d3cc7ca32193d9955', 'semilla dev: administrador'),
    ('0x23618e81e3f5cdf7f54c3d65f7beb7d73c26c1f4', 'auditor', 'platform', NULL,
     '0x14dc79964da2c08b23698b3d3cc7ca32193d9955', 'semilla dev: auditor'),
    ('0xa0ee7a142d267c1f36714e4a8f75612f20a79720', 'arbiter', 'platform', NULL,
     '0x14dc79964da2c08b23698b3d3cc7ca32193d9955', 'semilla dev: árbitro'),
    ('0x15d34aaf54267db7d7c367839aaf71a00a2c6a65', 'operator','platform', NULL,
     '0x14dc79964da2c08b23698b3d3cc7ca32193d9955', 'semilla dev: operador'),
    ('0x23618e81e3f5cdf7f54c3d65f7beb7d73c26c1f4', 'support', 'platform', NULL,
     '0x14dc79964da2c08b23698b3d3cc7ca32193d9955', 'semilla dev: soporte')
ON CONFLICT DO NOTHING;

INSERT INTO rwa.role_assignments (wallet_address, role, scope, issuer_program_id, granted_by_wallet, reason)
SELECT v.wallet, 'issuer'::rwa.session_role, 'issuer_program', p.id,
       '0x14dc79964da2c08b23698b3d3cc7ca32193d9955', 'semilla dev: emisor por programa'
FROM (VALUES
    ('0x70997970c51812dc3a010c7d01b50e0d17dc79c8', 'kyc-base'),
    ('0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc', 'garantia-activos'),
    ('0x90f79bf6eb2c4f870365e785982e1f101e93b906', 'fiador'),
    ('0x9965507d1a55bcc2695c58ba16fb37d819b0a4dc', 'onboarding-socio')
) AS v(wallet, slug)
JOIN rwa.issuer_programs p ON p.slug = v.slug
ON CONFLICT DO NOTHING;

INSERT INTO rwa.indexer_state (id, last_block) VALUES (1, 0)
ON CONFLICT (id) DO NOTHING;

INSERT INTO rwa.schema_migrations (version, description) VALUES
    ('3.0', 'Esquema v3.0: ISSUER, identidades, certificaciones, activos, marketplace, pagos y recuperación')
ON CONFLICT (version) DO NOTHING;

-- -----------------------------------------------------------------------------
-- 14. Migración desde v2 (1.0–1.2)
-- -----------------------------------------------------------------------------
-- Este archivo crea el esquema v3 DESDE CERO (BD nueva). Para evolucionar una BD
-- v2 existente se usa el script hermano, que archiva las tablas heredadas y hace
-- el ETL de datos:
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
--        -f RepoTecnico/migracion_v2_a_v3.sql
--
-- Regla: 0 sentencias CREATE sobre tablas colidentes con v2 (se renombran a *_v2
-- antes de ejecutar este archivo). Ver `migracion_v2_a_v3.sql` §1–§6.
--
-- Fin de base_datos.sql v3.0
-- =============================================================================
