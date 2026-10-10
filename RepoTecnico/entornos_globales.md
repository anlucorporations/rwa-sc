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
| Besu CodeCrypto | `https://besu1.proyectos.codecrypto.academy` | (autodetectado por el wrapper) | Alternativa documentada (D-040); script `deploy-besu.sh` |
| Anvil GCP | `$RPC_URL` (gcp-env) | **31337 (verificado)** | **Despliegue canónico verificado (Ciclo 9)**; destino de `sc/script/deploy.sh` |

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

## 7. Contratos desplegados (Anvil, chain 31337)

### 7.1 Snapshot 2026-09/10 (histórico)

| Contrato | Dirección |
|---|---|
| IdentityRegistry | `0xa513E6E4b8f2a923D98304ec87F64353C4D5C853` |
| IdentityCloneFactory | `0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0` |
| Implementation | `0x75537828f2ce51be7289709686A69CbFDbB714F1` |

> Fuente de verdad histórica: pendiente RF-008 (`.env` + módulo compartido).

### 7.2 Despliegue canónico verificado en el Anvil de GCP (Ciclo 9 / RF-010)

Fuente de verdad: artefacto versionado `sc/deployments/31337-20261010T162639Z.json` (chain-id 31337,
bloque **517**, `deployer` `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`, 10 contratos verificados por
`cast code` y estado por `cast call`). Ya hay por tanto un **despliegue real en el Anvil de GCP**.

| Contrato | Dirección |
|---|---|
| IdentityRegistry | `0xF5b81Fe0B6F378f9E6A3fb6A6cD1921FCeA11799` |
| TrustedIssuersRegistry | `0x67baFF31318638F497f4c4894Cd73918563942c8` |
| TokenCloneFactory | `0x6533158b042775e2FdFeF3cA1a782EFDbB8EB9b1` |
| IdentityCloneFactory | `0x73C68f1f41e4890D06Ba3e71b9E9DfA555f1fb46` |
| ClaimTopicsRegistryCloneFactory | `0xD2D5e508C82EFc205cAFA4Ad969a4395Babce026` |
| ComplianceAggregator | `0x2b639Cc84e1Ad3aA92D4Ee7d2755A6ABEf300D72` |
| ClaimTopicsRegistry | `0xafAC6756b04A92C5C4a68cE3882b99531995eBBA` |
| Token (`RWA Demo Token` / `RWAD`, 18 dec) | `0x382F74873b3798BEca33Cf69623d0CF35dE0f369` |
| MaxBalanceCompliance (módulo del token) | `0xB468647B04bF657C9ee2de65252037d781eABafD` |
| Identity (clon de ejemplo, registrado) | `0x47d480c84C1223D914D99872a2738bDE05F191e5` |

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

# Despliegue canonico verificado (Ciclo 9 / RF-010)
cd /home/dsh/workspace/RWA/rwa-sc
source /home/dsh/workspace/gcp-env.sh    # exporta RPC_URL, CHAIN_ID=31337 y la clave (ADMIN_PRIVATE_KEY)
sc/script/deploy.sh                      # despliega, valida red, verifica on-chain y escribe sc/deployments/
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

## 12. Procedimiento de despliegue (Ciclo 9 / RF-010)

### 12.1 Anvil de GCP (destino canónico, D-040)

```bash
cd /home/dsh/workspace/RWA/rwa-sc
set +u; source /home/dsh/workspace/gcp-env.sh; set +u   # RPC_URL + CHAIN_ID=31337 + ADMIN_PRIVATE_KEY
export PATH="$HOME/.foundry/bin:$PATH"
sc/script/deploy.sh
```

`sc/script/deploy.sh`:

1. Exige `RPC_URL` y valida `cast chain-id` == `CHAIN_ID` **antes** de cualquier broadcast (si no coinciden,
   aborta sin desplegar).
2. Toma la clave de `DS_DEPLOYER_PRIVATE_KEY` → `DEPLOYER_PRIVATE_KEY` → `DS_PRIVATE_KEY` →
   `DS_ADMIN_PRIVATE_KEY` → `ADMIN_PRIVATE_KEY` → `PRIVATE_KEY` (o `DEPLOYER_KEY_VAR`, o
   `USE_SECRET_MANAGER=1` con `gcloud`). **Nunca** de un archivo de claves en disco.
3. Crea un **keystore cifrado efímero** (modo 600) en un directorio temporal 700 con `eth_keyfile`,
   pasando la clave por variable de entorno del proceso hijo (nunca por `argv`), y lo borra con `trap`.
4. Firma con `forge script --keystore <tmp> --password-file <tmp>` (sin `--private-key`).
5. Verifica on-chain: `cast code != 0x` en cada dirección y `cast call` de `name()`, registries,
   `getModuleCount`, `isModuleActiveForToken` y `tokenContract` (no decide el éxito por `grep` de logs).
6. Persiste `sc/deployments/<chainId>-<timestamp>.json` (direcciones, `chainId`, bloque, `deployer`,
   token, compliance y ABIs relevantes) y comprueba que no contiene secretos.

### 12.2 Besu (alternativa documentada)

```bash
cd /home/dsh/workspace/RWA/rwa-sc
export PATH="$HOME/.foundry/bin:$PATH"
RPC_URL=https://besu1.proyectos.codecrypto.academy CHAIN_ID=<chainId de Besu> ADMIN_PRIVATE_KEY=<clave> \
  ./deploy-besu.sh
```

`deploy-besu.sh` es un **wrapper de compatibilidad**: fija el RPC de Besu por defecto, autodetecta el
`chain-id` si no se declara y delega en `sc/script/deploy.sh`. El mismo script sirve para cualquier red
cambiando `RPC_URL`/`CHAIN_ID`.

### 12.3 Ejemplo de verificación manual

```bash
J=$(ls -t sc/deployments/*.json | head -1)
TOKEN=$(jq -r '.contracts.Token' "$J"); AGG=$(jq -r '.contracts.ComplianceAggregator' "$J")
cast code "$TOKEN" --rpc-url "$RPC_URL"
cast call "$TOKEN" 'name()(string)' --rpc-url "$RPC_URL"
cast call "$AGG" 'getModuleCount(address)(uint256)' "$TOKEN" --rpc-url "$RPC_URL"
```

> Nota: `cast call` devuelve los `string` entrecomillados; normaliza las comillas al comparar.
