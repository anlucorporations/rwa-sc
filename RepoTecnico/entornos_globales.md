# 🌐 Entornos Globales — RWA

> Configuración, rutas, variables y comandos de referencia. Sin secretos: las claves
> viven en GCP Secret Manager o en `.env` ignorado.

## 1. Áreas y rutas

| Área | Comando | Ruta local | Contenido |
|---|---|---|---|
| Contratos | `@contratos` | `/home/dsh/workspace/RWA/rwa-sc/` | Foundry project en `sc/` (src/test/script), docs .md, `deploy-besu.sh` |
| Web | `@web` | `/home/dsh/workspace/RWA/rwa-web/` | 5 apps Next.js + docs + `start-all.sh` |
| Reportes | — | `/home/dsh/workspace/RWA/RepoTecnico/` | Documentación técnica (este skill) |

## 2. Repositorios remotos

| Repositorio | URL | Estado (2026-10-03) |
|---|---|---|
| rwa-sc (GitLab) | `https://gitlab.com/anlucorporations/rwa-sc.git` | ✅ Existe · ramas: `main`, `rwa-sc-DSH`, `rwa-sc-DSH-GCP` (misma cabeza `2a4a683`) |
| rwa-sc (GitHub) | `https://github.com/anlucorporations/rwa-sc` | ⚠️ Repo vacío (0 ramas) |
| rwa-sc (CodeCrypto) | `https://gitlab.codecrypto.academy/anlucorporations/rwa-sc.git` | ❌ 404 (o privado sin token) |
| rwa-web | — | ❌ **No existe en ningún remoto** (GitHub, GitLab.com, CodeCrypto: 404). Pendiente autorización de creación (Q3) |

- **Rama de trabajo**: pendiente de Q3.
- **Regla**: nunca `git push` sin orden explícita del usuario (`/push`).

## 3. GCP (global, `/home/dsh/workspace/`)

| Elemento | Valor |
|---|---|
| Cargador | `source /home/dsh/workspace/gcp-env.sh` |
| `.env.global` | `/home/dsh/workspace/.env.global` (variables sin secretos) |
| Proyecto default | `mcc-ecommerce` |
| Anvil en GCP | RPC `MCC_ANVIL_RPC_URL` → `RPC_URL`, `CHAIN_ID=31337` |
| Cloud SQL | `truekeate-main:us-east1:truekeate-db-dev` (BD `truekeate`, user `app`, PG 15.18) — proyecto `truekeate-main`; proxy en `[IP]:5433` |
| Secretos | Prefijo `DS_` (`DS_RPC_URL`, `DS_DATABASE_URL`, `DS_KYC_SECRET`, `DS_RELAYER_PRIVATE_KEY`, `DS_PINATA_JWT`) + `DATABASE_URL`, `ADMIN_PRIVATE_KEY`, `RELAYER_PRIVATE_KEY` |
| SA de mínimos privilegios | `GCP_SA=ds-dev source gcp-env.sh` |

## 4. Redes blockchain

| Red | RPC | Chain ID | Uso |
|---|---|---|---|
| Anvil local | `http://localhost:8545` | 31337 | Desarrollo/tests web |
| Besu CodeCrypto | `https://besu1.proyectos.codecrypto.academy` | (pendiente confirmar) | Deploy actual (`deploy-besu.sh`) |
| Anvil GCP | `$RPC_URL` (gcp-env) | 31337 | Preview (si se aprueba Q7) |

## 5. Apps web y puertos

| App | Puerto | Rol | Stack particular |
|---|---|---|---|
| `web-identity` | 4001 | Inversores: identity + claims | ethers v6, MongoDB |
| `web-registry-trusted` | 4002 | Issuers: aprobar claims | ethers v6, MongoDB |
| `web-registry-trusted2` | (sin puerto asignado) | Duplicado H-08 | viem, react-query |
| `web-rwa` | (sin puerto asignado) | Landing/portal | Next puro |
| `web-token` | 4003 | Creadores de token | ethers v6, MongoDB |

## 6. Cuentas (solo red local Anvil — keys por defecto)

| Rol | Dirección |
|---|---|
| Admin/Owner | `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` |
| User 1 | `0x70997970C51812dc3A010C7d01b50e0d17dc79C8` |
| User 2 | `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC` |

> Claves: defaults públicos de Anvil (`.env` local / Secret Manager `DS_`). No commit.

## 7. Contratos desplegados (Anvil, chain 31337) — snapshot 2026-09/10

| Contrato | Dirección |
|---|---|
| IdentityRegistry | `0xa513E6E4b8f2a923D98304ec87F64353C4D5C853` |
| IdentityCloneFactory | `0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0` |
| Implementation | `0x75537828f2ce51be7289709686A69CbFDbB714F1` |

> Fuente de verdad: pendiente RF-008 (`.env` + módulo compartido).

## 8. Comandos útiles

```bash
# Contratos
cd /home/dsh/workspace/RWA/rwa-sc/sc
export PATH="$HOME/.foundry/bin:$PATH"   # Forge/Anvil v1.8.3 (instalados, fuera del PATH)
forge build && forge test --gas-report

# Web
cd /home/dsh/workspace/RWA/rwa-web
./start-all.sh        # 4001-4003 (asume Anvil + MongoDB corriendo)
./stop-all.sh
./check-status.sh

# GCP
source /home/dsh/workspace/gcp-env.sh    # carga RPC_URL, DATABASE_URL, DS_*
```
## 9. Estado del toolchain (verificado 2026-10-03)

| Herramienta | Estado real | Nota |
|---|---|---|
| Forge / Anvil | **Instalados** v1.8.3 en `/home/dsh/.foundry/bin/` | No estaban en el `PATH`: usar `export PATH="$HOME/.foundry/bin:$PATH"` |
| `sc/lib/` (forge-std v1.12.0, OZ v5.5.0, OZ-upgradeable v5.5.0) | **Clonados** para la auditoría | `lib/` está en `.gitignore`: el bootstrap reproducible sigue pendiente (H-04 / RF-005) |
| Node.js / npm | v22.23.2 / 10.9.8 | Suficiente para `rwa-web` (fuera de alcance) |
| MongoDB local | por verificar | Necesario solo para `rwa-web` |
| CI (GitLab) | **no existe** | RF-009: crear `.gitlab-ci.yml` sobre `rwa-sc-DSH-GCP` |

## 10. Rama y repositorios de trabajo

- Rama de trabajo de contratos: **`rwa-sc-DSH-GCP`** (D-005) en `https://gitlab.com/anlucorporations/rwa-sc.git`.
- Estado del repo remoto: HEAD = 1 commit (`2a4a683`) con solo `README.md`; el árbol real de `rwa-sc`
  (contratos, tests, scripts y docs) sigue **sin versionar** → H-04 / RF-005.
- No se hace `push` sin orden explícita del usuario.

## 11. Métricas de referencia (medidas, no declaradas)

Ver `metricas_ejecucion.md`: 151 tests declarados · 93 pasan · 5 fallan · 53 no arrancan · cobertura 42,86 %.
Ninguna cifra de los documentos originales ("139 tests", "100 % passing", "coverage > 80 %") está respaldada.
