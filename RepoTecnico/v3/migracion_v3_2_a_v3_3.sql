-- =============================================================================
-- Migración v3.2 → v3.3 — referencia on-chain de publicaciones (C4)
-- Idempotente. Ejecutar con psql contra la BD `truekeate-db-dev`.
-- =============================================================================
BEGIN;

ALTER TABLE rwa.listings
    ADD COLUMN IF NOT EXISTS on_chain_listing_id numeric(78,0),
    ADD COLUMN IF NOT EXISTS escrow_tx_hash      text;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'listings_onchain_tx_format'
    ) THEN
        ALTER TABLE rwa.listings
            ADD CONSTRAINT listings_onchain_tx_format
            CHECK (escrow_tx_hash IS NULL OR escrow_tx_hash ~ '^0x[0-9a-f]{64}$');
    END IF;
END $$;

COMMENT ON COLUMN rwa.listings.on_chain_listing_id IS
    'id de la publicación en el contrato Marketplace (v3.3, C4)';
COMMENT ON COLUMN rwa.listings.escrow_tx_hash IS
    'tx de createListing (el activo ya está en escrow del Marketplace)';

COMMIT;
