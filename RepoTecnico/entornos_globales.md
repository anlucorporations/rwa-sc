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

| Repositorio | URL | Estado (2026-10-14) |
|---|---|---|
| rwa-sc (GitLab.com, `origin`) | `https://gitlab.com/anlucorporations/rwa-sc.git` | ✅ Existe · ramas: `main` (`2a4a683`), `rwa-sc-DSH`, **`rwa-sc-DSH-GCP`** sincronizada. `fetch` por HTTPS; **`push` por SSH** (`remote.origin.pushurl = git@gitlab.com:...`, el HTTPS no tiene token) |
| rwa-sc (GitHub, remoto `github`) | `git@github.com:anlucorporations/rwa-sc.git` | ✅ Existe · `rwa-sc-DSH-GCP` sincronizada (SSH) |
| rwa-sc (CodeCrypto, remoto `codecrypto`) | `https://gitlab.codecrypto.academy/anlucorporations/rwa-sc.git` | ✅ Existe · `rwa-sc-DSH-GCP` sincronizada (helper `git-credential-gitlab-codecrypto`) |
| rwa-web | — | ⏳ Repo **local** `rwa-web/.git`, rama `rwa-web-DSH`; **sin remoto** configurado (D-094) |

- **Rama de trabajo**: `rwa-sc-DSH-GCP` (D-005).
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

> **Etapa de optimización (2026-10-14, D-088/D-089/D-095/D-096):** `rwa-web` pasa a estar **en alcance**. La
> BD off-chain es **PostgreSQL** (Cloud SQL, esquema `rwa`) y la red on-chain canónica es el **Anvil de GCP**
> (chain 31337). Estado final objetivo: **3 apps** (`identity`, `issuer`, `token`) sobre monorepo pnpm +
> `packages/shared`; `web-rwa` y `web-registry-trusted2` se absorben o se retiran (RF-W-18). Detalles en
> `rwa-web/RepoTecnico/requerimientos_web.md` y `rwa-web/RepoTecnico/plan_desarrollo_web.md`; variables en §14.
> **Reorganización de líneas (2026-10-14):** la documentación propia de la línea `@web` vive en
> `rwa-web/RepoTecnico/`; los artefactos de datos compartidos (`base_datos.sql`, `diccionario_datos.md`,
> `diagrama_er.md`) y este documento permanecen en `rwa-sc/RepoTecnico/`.

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
| Node.js / npm | v22.23.2 / 10.9.8 | Suficiente para `rwa-web` (en alcance desde 2026-10-14) |
| PostgreSQL (Cloud SQL `truekeate-db-dev`) | Documentado vía Auth Proxy `127.0.0.1:5433` | BD **oficial** de la plataforma; usada por la etapa web (D-095). Verificar instancia/región antes del ciclo O0 |
| MongoDB local | **En retirada** | Sustituido por PostgreSQL en la etapa web (D-095); solo necesario para reproducir el sistema anterior |
| CI (GitLab) | **`.gitlab-ci.yml` creado (Ciclo 11 / RF-009)**, validado en local | Aún **sin ejecutar en remoto**: no hay `push`. Ver §13 |

## 10. Rama y repositorios de trabajo

- Rama de trabajo de contratos: **`rwa-sc-DSH-GCP`** (D-005). Remotos configurados: **`origin`**
  (`https://gitlab.com/anlucorporations/rwa-sc.git`, push por SSH), **`github`**
  (`git@github.com:anlucorporations/rwa-sc.git`) y **`codecrypto`**
  (`https://gitlab.codecrypto.academy/anlucorporations/rwa-sc.git`).
- Estado del repo remoto: la rama está **publicada y sincronizada en los tres remotos** (último commit de
  referencia `688f737`); `main` intacta en `2a4a683`. El `push` se ejecutó con orden explícita del usuario.
- No se hace `push` sin orden explícita del usuario.
- **Repo del frontend (etapa de optimización, D-094):** ✅ **creado en local** el 2026-10-14 — `rwa-web/.git`,
  rama **`rwa-web-DSH`**, commit inicial `cd97c7d` («chore(web): commit inicial — separación de líneas @sc/@web»),
  **229 ficheros rastreados**, `git status` limpio y **sin remoto configurado** todavía. Destino previsto:
  `https://gitlab.com/anlucorporations/rwa-web.git`. `push` solo con `/push`.
- **Estructura de documentación por líneas:** cada línea tiene su `RepoTecnico/` (`rwa-sc/RepoTecnico/` para `@sc`,
  `rwa-web/RepoTecnico/` para `@web`). Los tres artefactos de datos (`base_datos.sql`, `diccionario_datos.md`,
  `diagrama_er.md`) existen en las dos líneas: **canónico en `rwa-sc/RepoTecnico/` + espejo en
  `rwa-web/RepoTecnico/`**, con gate de sincronización
  (`rwa-web/RepoTecnico/check_sincronizacion_datos.sh --check` → exit 0).

## 11. Métricas de referencia (medidas, no declaradas)

Cifras vigentes (medidas, ver `metricas_ejecucion.md` §27): **420 tests / 420 pasan / 0 fallan** (24 suites,
19 invariantes) y cobertura de `src/` **97,01 % de líneas** (D-017, sin interfaces; mínimo por contrato 92,31 %).
Las cifras originales ("139 tests", "100 % passing", "coverage > 80 %") no estaban respaldadas; históricamente
la auditoría V1 midió 98 ejecutados / 93 pasan / 5 fallan / 53 no arrancan / cobertura 42,86 % (2026-10-03).

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

## 13. Integración Continua — pipeline de GitLab (Ciclo 11 / RF-009)

### 13.1 Qué es y dónde vive

- Fichero: **`rwa-sc/.gitlab-ci.yml`** (raíz del repositorio), versionado.
- Rama de CI: **`rwa-sc-DSH-GCP`** (D-005); también se dispara en *merge requests* (`merge_request_event`).
  Ninguna otra rama dispara pipeline (`workflow.rules` → `when: never`).
- Imagen **fijada**: `ghcr.io/foundry-rs/foundry:v1.8.3` (tag verificado en `ghcr.io` el 2026-10-10; coincide
  con el toolchain local: Forge/Anvil **v1.8.3**). Para actualizarla: cambiar el tag en `default.image.name`
  y en esta sección; volver a medir cobertura y `.gas-snapshot`.
- Variables (sin secretos): `FOUNDRY_PROFILE=default`, `SOLC_VERSION=0.8.20`,
  `COVERAGE_THRESHOLD=80`, `COVERAGE_CONTRACT_THRESHOLD=80`, `GIT_SUBMODULE_STRATEGY=recursive`.

### 13.2 Etapas y gates

| Etapa | Comando | Gate | Requisito |
|---|---|---|---|
| `validate` | `git submodule update --init --recursive` + `git submodule status` | 3 submódulos pinneados, sin `-`/`+` y `.gitmodules` con `sc/lib/*` | B-5 / RF-005 |
| `build` | `forge build` | 0 errores | RF-005 |
| `fmt` | `forge fmt --check` | limpio | RF-005 |
| `test` | `forge test` | 0 fallos; **conteo real** publicado como artefacto | RNF-003 |
| `coverage` | `forge coverage --report summary --report lcov` + `check_coverage.sh` | agregado `src/` ≥ 80 % (sin `ICompliance.sol`/`IClaimTopicsRegistry.sol`) y mínimo por contrato ≥ 80 % | RNF-002 / D-017 / D-042 |
| `gas` | `forge snapshot --check --tolerance 5` | dentro del 5 % del `.gas-snapshot` | RNF-001 / D-039 |
| `ci-checks` | `check_no_bypass_flag.sh`, `check_docs.sh`, `abi_diff.sh` | sin `bypassCompliance`, docs consistentes, sin deriva de ABIs | RF-002 / RF-006 |

Artefactos: `sc/ci-artifacts/test-count.txt` (conteo real + resumen), `sc/ci-artifacts/test-run.log`,
`sc/ci-artifacts/coverage-summary.txt` y `sc/lcov.info`.

### 13.3 Ensayo local (mismos comandos, mismo orden)

```bash
cd /home/dsh/workspace/RWA/rwa-sc
export PATH="$HOME/.foundry/bin:$PATH"
sc/script/ci/run_local_ci.sh        # exit 0 = pipeline local en verde
# CI_KEEP_GOING=1 ... para no detenerse en la primera etapa que falle
```

El script recorre `validate → build → fmt → test → coverage+gate → gas → ci-checks`, imprime un resumen por
etapa y devuelve exit 0/1. Los umbrales se leen de `COVERAGE_THRESHOLD` / `COVERAGE_CONTRACT_THRESHOLD`.

### 13.4 Estado real: el pipeline ha corrido en remoto en verde

- **Pipelines en remoto en verde**: `2934202154` y `2934241152` (rama `rwa-sc-DSH-GCP`), con **7/7 jobs en
  `success`** (AF-11, cierre de Fase 4). La brecha original ("sin CI ejecutada") quedó cerrada.
- El repositorio remoto (`https://gitlab.com/anlucorporations/rwa-sc.git`) recibe los `push` autorizados
  explícitamente por el usuario; `run_local_ci.sh` reproduce el mismo pipeline en local.
- Requisitos ya satisfechos para que el pipeline corra en GitLab: **(1)** `push` de `rwa-sc-DSH-GCP`;
  **(2)** un **runner** registrado para el proyecto (docker o shell).
- Nota de entorno del runner: la imagen oficial de Foundry es **Ubuntu no-root y no incluye `jq`**, que
  `abi_diff.sh` necesita. El job `ci-checks` lo instala si el runner permite root (`user = "root"` en el
  `config.toml` del ejecutor docker) o si el ejecutor es **shell** (donde ya están `forge` y `jq`, según la
  precondición de CU-11). Si el runner es docker no-root, hay que usar una imagen propia `FROM
  ghcr.io/foundry-rs/foundry:v1.8.3` con `jq` instalado. No se cachea `~/.svm` (fuera del proyecto): solc
  0.8.20 se descarga por job.

## 14. Entorno del frontend — etapa de optimización (2026-10-14)

### 14.1 Red y datos (D-095/D-096)

| Elemento | Valor canónico |
|---|---|
| Red on-chain | **Anvil de GCP** · `MCC_ANVIL_RPC_URL` = `https://mcc-foundry-anvil-1095249147821.europe-west1.run.app` · **chain 31337** (verificado: `0x7a69`, `anvil/v1.5.1`) — D-096 |
| Anvil local | `http://localhost:8545` (31337) — alternativa de desarrollo offline; misma cadena |
| Fuente de direcciones | `rwa-sc/sc/deployments/31337-20261010T162639Z.json` (**nunca literales en el código**); verificado on-chain: 9/9 contratos con código, EIP-712 + RF-004 + AF-01 presentes |
| Fuente de ABIs | `rwa-sc/sc/abis/*.json` (con gate de deriva en CI) |
| BD off-chain | **PostgreSQL en GCP** (Cloud SQL **`truekeate-db-dev`**, **PG 15.18**, usuario `app`, proyecto `truekeate-main`, región **`southamerica-east1-a`**, IP pública **`34.39.180.101`**) — esquema **`rwa`** ✅ aplicado (D-095/D-097) |
| Esquema | `RepoTecnico/base_datos.sql` v1.0 — **aplicado y verificado**: 10 tablas + 1 vista + 29 índices + catálogo (5 topics) + `schema_migrations` 1.0; **idempotente** (2ª ejecución sin errores). **Arranque limpio, sin ETL** (D-099) |
| Acceso de red | ACL de Cloud SQL = `35.232.138.181/32`, **la IP de salida de este host**; `requireSsl=false`; canónico por socket (`/cloudsql/…`, Cloud Run/Auth Proxy), local por TCP |
| Sistema sustituido | MongoDB `rwa` + GridFS `claim_documents` (transcripción en Anexo A de `base_datos.sql`) |
| Besu CodeCrypto (81234) | Alternativa documentada; **no** canónica |

### 14.2 Variables de entorno del frontend

| Variable | Ámbito | Origen | Uso |
|---|---|---|---|
| `NEXT_PUBLIC_CHAIN_ID` | público | `31337` | Red canónica (Anvil de GCP) |
| `NEXT_PUBLIC_RPC_URL` | público | `$RPC_URL` (`gcp-env.sh`) / `localhost:8545` | RPC |
| `NEXT_PUBLIC_DEPLOYMENT_JSON` | público | `sc/deployments/*.json` | Direcciones de contratos |
| `DATABASE_URL` | servidor | `DATABASE_URL` de `gcp-env.sh` (Secret Manager) | **PostgreSQL** (sustituye a `MONGODB_URI`) |
| `SIWE_SESSION_SECRET` | servidor | Secret Manager `DS_*` | Firma de cookie de sesión (RF-W-01) |
| `KYC_ENCRYPTION_KEY` | servidor | Secret Manager `DS_*` | AES-256-GCM de documentos (RNF-W-02) |
| `LOG_LEVEL` | servidor | `info` por defecto | Logging estructurado (RT-W-10) |
| `ALLOW_DEBUG_ENDPOINTS` | servidor | ausente en producción | Habilita `/api/test-*` solo en local (RF-W-07) |

> **Regla:** ningún secreto en el repositorio. `.env.local` ignorado y `.env.example` versionado por app
> (HW-15: el fichero `web-registry-trusted2/env.local` actual **no** está cubierto por el patrón `.env*`).

### 14.3 Comandos de la etapa

```bash
# Repositorio del frontend (se crea en O3; git local puede adelantarse en O1/O2)
cd /home/dsh/workspace/RWA/rwa-web
git init -b rwa-web-DSH        # solo si el usuario lo autoriza
# git remote add origin https://gitlab.com/anlucorporations/rwa-web.git   # en O3

# Gates de la etapa (se implementan en O2/O3)
pnpm -r install
pnpm -r lint && pnpm -r typecheck && pnpm -r build && pnpm -r test
sc/script/ci/check_secrets.sh  # patrón reutilizado de contratos
# gates nuevos: check-abi-drift (ABIs vs sc/abis) y check-network-literals (0 literales de red)

# Entorno reproducible (O5)
docker compose up -d          # 3 apps + PostgreSQL + nodo Anvil local, con healthchecks

# Esquema de datos (O0.1) — ✅ APLICADO en Cloud SQL el 2026-10-14
source rwa-web/scripts/gcp-env.sh --tcp     # exporta DATABASE_URL + RPC y VERIFICA ambos servicios
psql "host=34.39.180.101 port=5432 dbname=truekeate user=app sslmode=disable" -f RepoTecnico/base_datos.sql
psql "$CONN" -c '\dt rwa.*'                 # 10 tablas + 1 vista
```

### 14.5 Conexión verificada a los servicios GCP (2026-10-14)

| Aspecto | Valor real |
|---|---|
| Script de entorno | `rwa-web/scripts/gcp-env.sh` (`source … --tcp` para este host; sin flag = socket canónico) |
| Plantilla | `rwa-web/.env.example` (sin secretos) |
| Comprobación integrada | El script consulta `eth_chainId` (espera `0x7a69`) y `select 1` + nº de tablas de `rwa`; **aborta si fallan** |
| `gcloud` | El de snap (`/snap/bin/gcloud`) **está roto** en este host: usar `$HOME/bin/gcloud` (SDK 582.0.0) |
| Secreto de BD | Proyecto **`truekeate-main`**, secreto **`DATABASE_URL`** (socket unix). `DS_DATABASE_URL` de `mcc-ecommerce` está **vacío** |
| Auth Proxy | **No instalado**; en local se usa TCP a la IP pública (host ya autorizado). En Cloud Run se usa el socket |
| Cloud Run `mcc-postgres-…` | Devuelve **503**; no usar como pasarela SQL |

> Acta completa con la evidencia: `rwa-web/RepoTecnico/pruebas/verificacion_gcp_o0.md`.

### 14.4 Estado actual verificado del frontend (línea base, 2026-10-14)

| Métrica | Valor |
|---|---|
| Apps / líneas / ficheros | 5 / 16.648 / 181 |
| Rutas de API | 16 (0 con autenticación) |
| Tests · CI · VCS | 0 · 0 · ninguno |
| Versiones de `next` / `react` | 4 (16.0.1, 16.1.1, 16.1.3, 16.1.6) / 2 (19.2.0, 19.2.3) |
| Stacks web3 | 2 (`ethers` v6 ×3, `viem`+`wagmi` ×1) |
| `ignoreBuildErrors: true` | 3 apps |
| `console.log` · `any` · `window.ethereum` | 161 · 67 · 96 |
| BD off-chain actual | MongoDB `rwa` + GridFS `claim_documents` → **objetivo: PostgreSQL esquema `rwa`** (D-095) |
| Red on-chain | configuraciones divergentes (Besu 81234 en `web-identity`, Anvil local en el resto) → **objetivo: Anvil de GCP, 31337** (D-096) |
| Flujo end-to-end contra contratos | **roto** (deriva de ABI + `claimTopicsRegistry = 0x0`) |
