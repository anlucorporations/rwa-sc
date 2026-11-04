-- =============================================================================
-- seed_ci_v2.sql — datos mínimos para el job `migracion-v3` del CI (C0)
-- =============================================================================
-- Se carga SOBRE el esquema v2 canónico (rwa-sc/RepoTecnico/base_datos.sql) y sirve
-- para que `migracion_v2_a_v3.sql` ejecute el ETL completo y sus verificaciones §6.
-- No contiene datos reales ni personales: solo direcciones de Anvil y valores de prueba.
-- =============================================================================

BEGIN;

-- Emisor legacy
INSERT INTO rwa.issuers (address, name, verified, verified_at)
VALUES ('0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc', 'Emisor legacy CI', true, now());

-- Claim pending (sin payload) + claim approved (con payload EIP-712)
INSERT INTO rwa.claim_requests (
  requester_address, issuer_address, claim_topic_id, status, signed_message, signature,
  reviewed_by, reviewed_at, issuer_signed_message, issuer_signature,
  identity_address, claim_chain_id, claim_wallet_owner, claim_nonce, claim_expires_at,
  claim_data, claim_uri, claim_uri_hash, claim_data_hash, claim_signature
) VALUES
('0x70997970c51812dc3a010c7d01b50e0d17dc79c8','0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc',1,'pending',
 'msg','0xsig',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL),
('0x70997970c51812dc3a010c7d01b50e0d17dc79c8','0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc',7,'approved',
 'msg','0xsig','0x90f79bf6eb2c4f870365e785982e1f101e93b906',now(),'signed','0xissuersig',
 '0x70997970c51812dc3a010c7d01b50e0d17dc79c8',31337,'0x70997970c51812dc3a010c7d01b50e0d17dc79c8',7,
 4102444800,'data','ipfs://uri','0xurihash','0xdatahash','0xclaimsig');

-- Documento cifrado de prueba (sha256 en claro como bytea en v2)
INSERT INTO rwa.document_files (claim_request_id, original_name, content_type, size_bytes, sha256, content, uploaded_by)
SELECT id, 'kyc.pdf', 'application/pdf', 12, sha256('hello world'::bytea),
       'hello world'::bytea, '0x70997970c51812dc3a010c7d01b50e0d17dc79c8'
FROM rwa.claim_requests WHERE status = 'pending' LIMIT 1;

-- Token demo v2 (ERC-20) con registries no nulos
INSERT INTO rwa.tokens (token_address, admin_address, name, symbol, decimals, total_supply,
  identity_registry, trusted_issuers_registry, claim_topics_registry, price, transaction_hash, block_number)
VALUES ('0x1111111111111111111111111111111111111111','0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266',
 'Token demo CI','TDC',18,1000.0,
 '0x2222222222222222222222222222222222222222','0x3333333333333333333333333333333333333333',
 '0x4444444444444444444444444444444444444444',100.5,'0xabc',100);

INSERT INTO rwa.token_required_claims (token_id, claim_topic_id)
SELECT id, 1 FROM rwa.tokens LIMIT 1;

-- Sesión, auditoría, evento e indexer
INSERT INTO rwa.sessions (address, nonce, role, expires_at)
VALUES ('0x70997970c51812dc3a010c7d01b50e0d17dc79c8','nonce-ci-1','investor', now() + interval '1 day');

INSERT INTO rwa.audit_log (actor_address, action, resource_type, resource_id, detail)
VALUES ('0x70997970c51812dc3a010c7d01b50e0d17dc79c8','claim.read','claim_request','x','{"k":1}');

INSERT INTO rwa.indexer_state (indexer_id, chain_id, last_block) VALUES ('default', 31337, 558);

INSERT INTO rwa.chain_events (chain_id, block_number, block_hash, tx_hash, log_index, address, event_name, args, removed)
VALUES (31337, 558, '0x' || repeat('ab', 32), '0x' || repeat('cd', 32), 0,
        '0x2222222222222222222222222222222222222222', 'Transfer', '{"v":"1"}', false);

COMMIT;
