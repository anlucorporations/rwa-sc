# 2. Puesta en marcha

## 2.1 Requisitos

- Node ≥ 20 y pnpm 9.15.x · Foundry 1.8.x · PostgreSQL 15+ (o PostgreSQL embebido de `pgserver`)
- Cuenta GCP sólo para despliegue; el desarrollo local funciona sin GCP.

## 2.2 Frontend + paquetes

```bash
cd rwa-web
pnpm install
pnpm --filter @rwa/shared test:unit          # 55/55
pnpm --filter @rwa/wallet-messages test      # 8/8
pnpm --filter @rwa/metaplace test            # 3/3 rate limiting
pnpm --filter @rwa/metaplace typecheck
NEXT_PUBLIC_RPC_URL=http://127.0.0.1:8545 NEXT_PUBLIC_CHAIN_ID=31337 \
  pnpm --filter @rwa/metaplace build
```

## 2.3 Base de datos (local o CI)

```bash
# Esquema canónico (v3.3) — requiere pgcrypto; en CI está el shim documentado
psql "$DATABASE_URL" -f RepoTecnico/base_datos.sql

# Migración desde v3.2 (idempotente)
psql "$DATABASE_URL" -f RepoTecnico/migracion_v3_2_a_v3_3.sql
```

Para pruebas locales sin PostgreSQL del sistema existe el binario embebido (`pgserver`):
arrancar con `-k /tmp` y cargar el esquema con el shim de `pgcrypto`; **no commitear shims**.

## 2.4 Contratos

```bash
cd rwa-sc/sc
forge build
forge test          # suite completa (486+ tests)
```

- Compilador: `auto_detect_solc` + EVM **cancun** (OZ 5.5 exige solc ≥ 0.8.24; D-V3-28).
- Despliegue (cuando haya red): `ADMIN_PRIVATE_KEY=… IDENTITY_REGISTRY=… forge script script/v3/DeployAssets.s.sol --rpc-url "$RPC_URL" --broadcast`.
- Artefactos en `sc/deployments/`; direcciones vigentes en `sc/config/v3_*.json`.

## 2.5 Arranque del shell

```bash
cd rwa-web/apps/metaplace
DATABASE_URL=… SIWE_SESSION_SECRET=… KYC_ENCRYPTION_KEY=… \
NEXT_PUBLIC_RPC_URL=… NEXT_PUBLIC_CHAIN_ID=31337 PORT=4101 \
pnpm start
curl localhost:4101/api/health
```

> `next start` con `output: standalone` emite aviso; en producción usar `node .next/standalone/server.js`.
> En pruebas, si un proceso queda huérfano, terminarlo antes de reutilizar el puerto.

## 2.6 Problemas conocidos

| Síntoma | Causa / solución |
|---|---|
| 500 `NEXT_PUBLIC_RPC_URL no está definida` | build sin variables públicas: recompilar con `NEXT_PUBLIC_*` |
| `Next build` falla por `react` sin tipos | faltan `@types/react`/`@types/react-dom` en devDependencies |
| `forge build` error `mcopy`/pragma | `evm_version="cancun"` y pragma `^0.8.24` |
| `psql: connection refused` | puerto ocupado o socket distinto: usar `-k` propio y puerto libre |
| Migración falla por `ALTER TYPE` | los `ALTER TYPE … ADD VALUE` deben ir fuera de la transacción |
