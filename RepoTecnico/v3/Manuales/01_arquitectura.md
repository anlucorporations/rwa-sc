# 1. Arquitectura

## 1.1 Monorepo

```
rwa-web/                      # pnpm workspace
├─ apps/metaplace/            # shell único del Metaplace (Next.js 16, App Router)
│  ├─ app/                    # páginas + API routes (auth, identity, claims, assets, listings, orders, system)
│  └─ lib/                    # rbac, claims, market, services, admin, rate-limit, chain, onchain
├─ packages/shared/           # SIWE, DB (pool + repos), errores, validación, EIP-712, cifrado KYC
├─ packages/wallet-messages/  # 8 procesos × es/en con umbrales de legibilidad
├─ packages/config|ui/        # configuración y componentes comunes
└─ apps/identity|issuer|token # suites heredadas (migración progresiva al shell)
```

```
rwa-sc/sc/                    # Foundry
├─ src/                       # v2 (identity/claims/token) y src/v3 (BarloToken, AssetNFT721, AssetERC1155, AssetFactory, Marketplace)
├─ test/                      # suite completa (486+ tests)
├─ script/v3/                 # despliegues idempotentes (BRLT, roles, activos, marketplace)
├─ config/v3_*.json           # direcciones canónicas desplegadas
└─ deployments/               # artefactos por chain y timestamp
```

## 1.2 Flujo funcional

1. **Autenticación SIWE** → `sessions` (nonce de un solo uso) + cookie HMAC `httpOnly`.
2. **Identidad** seudónima (`identities`, alias `barlo-…`).
3. **Certificaciones**: solicitud + documento cifrado AES-256-GCM → cola del Operador → emisión firmada EIP-712 por el Emisor.
4. **Tokenización**: ISSUER crea activo (requiere GARANTÍA + FIADOR y consentimiento legible del Fiador); registro en `tokens` + `token_guarantees`.
5. **Marketplace**: publicación a precio fijo → orden con **doble escrow** (BRLT + activo) → confirmación / disputa → arbitraje.
6. **Consumo de servicio** (CU-25): compra confirmada + SOCIO → evento de auditoría idempotente.

## 1.3 Topología de despliegue (GCP)

| Componente | Servicio |
|---|---|
| Frontend | Cloud Run (imagen Next standalone) |
| Base de datos | Cloud SQL PostgreSQL 15 (`truekeate-db-dev`, esquema `rwa`) |
| Chain | Cloud Run `mcc-foundry-anvil` (chain 31337), estado persistente en GCS |
| Secretos | Secret Manager (`SIWE_SESSION_SECRET`, `KYC_ENCRYPTION_KEY`, claves BRLT) |
| Jobs | Cloud Run Job `rwa-indexer` (indexación) + purga de documentos |
| Scheduler | `*/10 * * * *` para el indexer |

> ⚠️ El estado on-chain vive en el bucket `mcc-ecommerce-anvil-state`; si el servicio se pierde,
> re-ejecutar los scripts de despliegue en orden y actualizar `config/v3_*.json`.

## 1.4 Variables de entorno relevantes

| Variable | Uso |
|---|---|
| `NEXT_PUBLIC_CHAIN_ID=31337` | red canónica (única permitida) |
| `NEXT_PUBLIC_RPC_URL` / `RPC_URL` | RPC de Anvil (cliente / servidor) |
| `DATABASE_URL` | PostgreSQL (socket `/cloudsql` o TCP autorizado) |
| `SIWE_SESSION_SECRET` | HMAC de la cookie (≥32 caracteres) |
| `KYC_ENCRYPTION_KEY` | AES-256-GCM de documentos KYC (32 bytes hex) |
| `CHAIN_VERIFY_TX=1` | verifica recibos on-chain de las órdenes |
| `MARKETPLACE_ADDRESS` | dirección del contrato Marketplace |
| `RATE_LIMIT_*` | límites de peticiones (auth/escrituras) |
