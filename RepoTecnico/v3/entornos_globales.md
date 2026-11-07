# Entornos globales — RWA v3 «Barlo Metaplace»

> **Versión:** v3.2 · **Fecha:** 2026-11-04 · **Fase:** 1 **CERRADA como baseline de diseño** (Q14a); implementación en gates C0–C6
> **Alcance:** rutas, repositorios, GCP, redes, BD, cuentas, toolchain, variables y comandos.
> **Regla:** ningún secreto en este documento ni en el repositorio. Claves en Secret Manager
> (`truekeate-main`) o en `.env` ignorado.

---

## 1. Rutas de trabajo

| Recurso | Ruta |
|---|---|
| Raíz del proyecto | `/home/dsh/workspace/RWA` |
| Contratos (Foundry) | `/home/dsh/workspace/RWA/rwa-sc/sc` |
| Web (monorepo pnpm) | `/home/dsh/workspace/RWA/rwa-web` |
| Documentación v3 | `/home/dsh/workspace/RWA/RepoTecnico` |
| Documentación v2 (referencia) | `rwa-sc/RepoTecnico/` y `rwa-web/RepoTecnico/` |
| Cargador de entorno global | `/home/dsh/workspace/gcp-env.sh` |
| Cargador de entorno web | `rwa-web/scripts/gcp-env.sh` (`--tcp` en este host) |
| `gcloud` operativo | `$HOME/bin/gcloud` (SDK 582.0.0). **El de snap (`/snap/bin/gcloud`) está roto en este host** |
| Foundry | `$HOME/.foundry/bin` (forge/anvil v1.8.3; no está en el `PATH` por defecto) |
| Respaldo de partida | `/home/dsh/workspace/backups/rwa-v2-backup-20261031T171645Z.zip` |

## 2. Repositorios

| Repo | Remoto | Uso |
|---|---|---|
| `rwa-sc` | `https://gitlab.com/anlucorporations/rwa-sc.git` (origin) · `git@github.com:anlucorporations/rwa-sc.git` (github) | Contratos, CI Foundry |
| `rwa-web` | `https://gitlab.com/anlucorporations/rwa-web.git` (origin) + espejos | Apps, indexer, despliegue |
| CodeCrypto | `https://gitlab.codecrypto.academy/anlucorporations/rwa-sc.git` | Espejo académico |

- **Rama de trabajo v3:** `rwa-web-DSH-GCP-v3` (creada desde el HEAD de la rama de trabajo v2; `main` permanece intacta).
- **Ramas v2:** `rwa-sc-DSH-GCP` (contratos) y `rwa-web-DSH` (web), congeladas.
- **Estado de publicación (2026-11-02):** `rwa-web-DSH-GCP-v3` publicada en **GitLab.com**, **GitHub** y **CodeCrypto** en ambos repos.
- **Credencial CodeCrypto (global, sin secretos en repos):** el token vive en
  `~/.config/gitlab/codecrypto.token` (permisos `600`) y el helper global
  `~/.local/bin/git-credential-gitlab-codecrypto` lo inyecta para
  `gitlab.codecrypto.academy` en **todos los proyectos** (config `git config --global`). Rotar el token =
  editar ese único archivo; no hay que tocar ningún repo. Verificado que `~/.git-credentials` no cachea
  el token (0 bytes).
- **Push solo con orden explícita del usuario** (`/push`). El push de `rwa-sc` va por SSH.
- La v2 queda **congelada** como referencia y plan de retorno (Q1).

## 3. GCP — destino **tx barlovento** (`barloventasv2`)

> **Cambio de entorno (2026-11-06):** el despliegue del Metaplace v3 pasa del proyecto
> `mcc-ecommerce` al proyecto **tx barlovento = `barloventasv2` (BarloVentasV2)**,
> **reutilizando los servicios globales** de la cuenta: el **Foundry (Anvil) global** y el
> **PostgreSQL global**. No se crean nodos ni instancias nuevas.

### 3.1 Proyecto destino (aplicaciones)

| Recurso | Valor |
|---|---|
| Proyecto | **`barloventasv2`** (BarloVentasV2) · número `107180969515` · región `europe-west1` |
| Cloud Run (actuales de txb) | `barloventas-web-admin`, `barloventas-pasarela`, `barloventas-compra-stablecoin` |
| Servicio objetivo v3 | `txb-metaplace` (shell + API) |
| Jobs objetivo | `txb-indexer`, `txb-maintenance` |
| Scheduler | `txb-indexer-schedule` (`*/10 * * * *`), `txb-maintenance-schedule` (diario) |
| Service Account runtime | `txb-metaplace@barloventasv2.iam.gserviceaccount.com` |
| Service Account jobs | `txb-jobs@barloventasv2.iam.gserviceaccount.com` |
| Artifact Registry | repo `txb` en `europe-west1` (crear; hoy las imágenes usan `gcr.io` legacy) |
| Secret Manager | `txb-database-url`, `txb-siwe-session-secret`, `txb-kyc-encryption-key`, `txb-anvil-admin-key`, `txb-brlt-{admin,minter,pauser}-key` |

### 3.2 Servicios globales reutilizados (obligatorio)

| Servicio global | Valor | Uso por txb |
|---|---|---|
| **Foundry (Anvil) global** | Cloud Run `mcc-foundry-anvil` (proyecto `mcc-ecommerce`, `europe-west1`) · URL canónica `https://mcc-foundry-anvil-slzlptbcla-ew.a.run.app` · **chainId 31337** · estado persistente en GCS `mcc-ecommerce-anvil-state` | RPC de la app, despliegue de contratos BRLT/Factory/Marketplace del set `txb-*` |
| **PostgreSQL global** | `truekeate-main:southamerica-east1:truekeate-db-dev` · **PostgreSQL 15** · `RUNNABLE` · backups **y PITR activos** · IP pública habilitada | Base **dedicada `txbarlovento`** con esquema `rwa` (socket Cloud SQL) |
| Secret Manager global (referencia) | `truekeate-main` (canónico) / `mcc-ecommerce` (copia operativa) | Los secretos de txb se crean en `barloventasv2` (`txb-*`) |

**Aislamiento:** base de datos dedicada + juego de contratos propio (`sc/config/v3_*_txb.json`) sobre la
misma chain global; claves/roles dedicados (nunca cuentas por defecto de Anvil).

**Conexión BD desde Cloud Run:** adjuntar `--add-cloudsql-instances=truekeate-main:southamerica-east1:truekeate-db-dev`
y usar el socket `/cloudsql/truekeate-main:southamerica-east1:truekeate-db-dev` en `DATABASE_URL`
(no requiere VPC connector ni exponer la BD a Internet).

### 3.3 Estado observado del GCP de tx barlovento (2026-11-06)

| Elemento | Estado | Impacto |
|---|---|---|
| Billing (`013B00-B9A67C-014A43`) | irregular: `describe` = true pero las APIs responden `BILLING_DISABLED` | 🔴 **gate G0**: sin desbloqueo no se puede desplegar |
| APIs en `barloventasv2` | run/cloudbuild/storage/iam/logging/monitoring ✅ · `sqladmin`, `secretmanager`, `artifactregistry`*, `vpcaccess`, `cloudscheduler`, `billingbudgets` ❌ | habilitar en G0 |
| RPC Foundry global | `eth_chainId` devuelve **HTTP 500** | 🔴 contratos/RPC no operativos (gate G2) |
| PostgreSQL global | `RUNNABLE`, backups+PITR ✅ | 🟢 listo; crear BD `txbarlovento` |
| Cloud Run txb | 3 servicios v2 con **SA default compute** | migrar a SA dedicadas en el despliegue v3 |

Detalle completo y plan por fases: `RepoTecnico/planes/plan_despliegue_gcp_txbarlovento.md`.

### 3.4 Infraestructura heredada (referencia v2, ya no destino)

| Recurso | Valor |
|---|---|
| Proyecto de apps v2 | `mcc-ecommerce` (`europe-west1`) |
| Cloud Run v2 | `rwa-identity`, `rwa-issuer`, `rwa-token` |
| Cloud Run Job v2 | `rwa-indexer` |
| Cloud Scheduler v2 | `rwa-indexer-schedule` (`*/10 * * * *`) |
| SA runtime v2 | `rwa-web-run@mcc-ecommerce.iam.gserviceaccount.com` |

**Decisión Q1 (actualizada):** la v3 **reutiliza los servicios globales** (Foundry + PostgreSQL) pero se
despliega en el proyecto **tx barlovento (`barloventasv2`)** con servicios, jobs, secretos y SA propios.

## 4. Redes y contratos

| Red | Chain ID | Uso |
|---|---|---|
| **Anvil de GCP** | **31337** | Red canónica de la v3 (desarrollo/demo) |
| Anvil local | 31337 | Desarrollo y tests |
| Besu CodeCrypto | autodetectado | Alternativa documentada (no usada) |

- **Fuente de verdad de direcciones:** `sc/deployments/31337-<ts>-v3.json` (artefacto versionado).
  El artefacto v2 (`31337-20261023T185622Z.json`) queda como referencia.
- **Gate anti-deriva:** `rwa-web/scripts/check-contract-drift.sh` compara artefacto ↔ `packages/shared`.
- **Cuentas de desarrollo (Anvil, claves públicas por defecto):**
  - Admin/Owner: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
  - User 1: `0x70997970C51812dc3A010C7d01b50e0d17dc79C8`
  - User 2: `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC`
  - Claves: solo en `.env` local ignorado o Secret Manager (`DS_*`). Nunca en el repo.

## 5. Base de datos off-chain

- Esquema **`rwa`** en PostgreSQL 15 (Cloud SQL). **27 tablas** en v3.2 (ver `base_datos.sql`).
- **Convención de versión única: `3.0`** (`schema_migrations`); no existe versión intermedia.
- Artefactos sincronizados: `diccionario_datos.md`, `diagrama_er.md`, `base_datos.sql`.
- Migraciones registradas en `rwa.schema_migrations` (v2: `1.0`–`1.2`; v3: `3.0`).
- Aplicación (BD nueva):
  ```bash
  source rwa-web/scripts/gcp-env.sh --tcp     # exporta DATABASE_URL (sin imprimirla)
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f RepoTecnico/base_datos.sql
  ```
- Migración de una BD v2 existente (archiva tablas `*_v2` + ETL + registra `3.0`):
  ```bash
  pg_dump "$DATABASE_URL" -Fc -f rwa_v2_$(date +%Y%m%d).dump   # backup obligatorio
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f RepoTecnico/migracion_v2_a_v3.sql
  ```
  Se ensaya en CI contra un `pg_dump` v2 antes de tocar Cloud SQL (criterio H-01).
- **Política de retención (Q10):** 30 días tras rechazo; 12 meses tras fin de relación;
  purga controlada por `rwa.v_documents_due_deletion`.

### 5.1 Jobs programados (B3/B7)

| Job | Cron (Cloud Scheduler) | Acción | Invocación |
|---|---|---|---|
| `expire_orders` | `*/5 * * * *` | `SELECT rwa.expire_orders();` libera reservas vencidas | Scheduler → Cloud Run Job `rwa-jobs` → `/internal/jobs/expire-orders` (OAuth) |
| `purge_documents` | `0 3 * * *` | `SELECT rwa.purge_expired_documents();` aplica retención Q10 | Scheduler → Cloud Run Job `rwa-jobs` → `/internal/jobs/purge-documents` |
| `rwa-indexer-schedule` | `*/10 * * * *` | indexer on-chain (heredado v2) | Scheduler → Cloud Run Job `rwa-indexer` |

Los endpoints internos exigen OAuth de la SA `rwa-scheduler@mcc-ecommerce` y no son públicos.
Cada ejecución deja contador + entrada en `audit_log`; el fallo dispara alerta.

### 5.2 BRLT y claves de rol (C0, 2026-11-04)

| Dato | Valor |
|---|---|
| Contrato `BarloToken` | `0xf08521C9359E5950E9334D79C29cbDC2059a31f8` (chain 31337, bloque 566) |
| Artefacto | `sc/deployments/31337-1793828678-barlo.json` |
| Config pública de roles | `sc/config/v3_roles.json` (admin/minter/pauser, solo direcciones) |
| Secretos | `BRLT_ADMIN_KEY`, `BRLT_MINTER_KEY`, `BRLT_PAUSER_KEY` en Secret Manager (`mcc-ecommerce`) |
| Gate anti-Anvil | `sc/script/ci/check_role_wallets.sh` (job `check-role-wallets` en CI) |
| Aprovisionamiento C0 | `rwa-web/scripts/provision_c0.sh` (backups/PITR, IAM, Cloud Run Job `rwa-jobs`, Scheduler) |

> Las claves **no** se versionan: viven en Secret Manager y se leen por variable de entorno en los
> scripts de Foundry (`vm.envUint`), nunca por `argv` (RF-010).

## 6. Variables de entorno

| Variable | Ámbito | Uso |
|---|---|---|
| `NEXT_PUBLIC_CHAIN_ID` | público | `31337` (Anvil de GCP) |
| `NEXT_PUBLIC_RPC_URL` | público | RPC del Anvil de GCP |
| `NEXT_PUBLIC_DEPLOYMENT_JSON` | público | Artefacto de direcciones v3 |
| `NEXT_PUBLIC_BRLT_ADDRESS` | público | Dirección de `BarloToken` |
| `NEXT_PUBLIC_MARKETPLACE_ADDRESS` | público | Dirección del marketplace/escrow |
| `DATABASE_URL` | servidor (secreto) | PostgreSQL (Cloud SQL) |
| `SIWE_SESSION_SECRET` | servidor (secreto) | Firma de cookie de sesión |
| `KYC_ENCRYPTION_KEY` | servidor (secreto) | AES-256-GCM de documentos |
| `WALLET_MESSAGES_LOCALE` | servidor | Idioma por defecto de plantillas (`es`) |
| `PG_POOL_MAX` | servidor | Máx. conexiones del pool (5 en Cloud Run) |
| `LOG_LEVEL` | servidor | Nivel de logs estructurados |
| `RPC_URL`, `CHAIN_ID`, `ADMIN_PRIVATE_KEY` | despliegue | Scripts de despliegue de contratos (entorno/Secret Manager) |

## 7. Toolchain

| Herramienta | Versión / nota |
|---|---|
| Node.js | ≥ 22 (Next 16 / React 19) |
| pnpm | workspaces (`apps/*`, `packages/*`) |
| Foundry | v1.8.3 (`$HOME/.foundry/bin`) · solc **0.8.20** · OZ 5.5.0 (+ upgradeable) |
| PostgreSQL | 15 (cliente `psql` requerido para aplicar el esquema) |
| gcloud | SDK 582.0.0 en `$HOME/bin/gcloud` |

## 8. Comandos útiles

### 8.0 Entorno tx barlovento (`barloventasv2`) + servicios globales

```bash
# Carga variables del destino y comprueba Foundry/PostgreSQL globales (no imprime secretos)
source rwa-web/scripts/gcp-env-txb.sh

# Provisión idempotente (DRY_RUN=1 por defecto; ejecutar DRY_RUN=0 sólo tras G0)
DRY_RUN=1 bash rwa-web/scripts/provision_txb.sh
BUILD=1 DEPLOY=1 DRY_RUN=0 bash rwa-web/scripts/provision_txb.sh
```

Gates: **G0** billing/APIs + RPC `0x7a69` + BD `RUNNABLE`; **G1** base `txbarlovento`+esquema `rwa`+secretos;
**G2** contratos `txb-*` desplegados en el Foundry global; **G3** `txb-metaplace` con `/api/health` OK.


```bash
# --- Contratos ---
cd /home/dsh/workspace/RWA/rwa-sc/sc
export PATH="$HOME/.foundry/bin:$PATH"
forge build && forge test --gas-report

# --- Web ---
cd /home/dsh/workspace/RWA/rwa-web
source scripts/gcp-env.sh --tcp          # RPC + DATABASE_URL verificados
pnpm install && pnpm -r build
./start-all.sh                            # apps en 4001-4003 (v2)
./check-status.sh

# --- GCP ---
source /home/dsh/workspace/gcp-env.sh     # RPC_URL, DATABASE_URL, DS_*
export PATH="$HOME/bin:$PATH"
gcloud run services list --project mcc-ecommerce --region europe-west1

# --- Despliegue ---
cd /home/dsh/workspace/RWA/rwa-web
TAG=$(date -u +%Y%m%d-%H%M%S) ./scripts/deploy_gcp.sh all

# --- Esquema v3 ---
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f /home/dsh/workspace/RWA/RepoTecnico/base_datos.sql
```

## 9. Notas de seguridad

- 0 secretos en repos, scripts ni documentación; el `.env` está ignorado.
- La SA de runtime tiene **mínimos privilegios** (Cloud SQL client + acceso a 3 secretos).
- La firma de transacciones usa keystore cifrado efímero o Secret Manager; nunca `--private-key`
  en `argv` ni `keys.json` en disco.
- BRLT es un token de **utilidad sin valor real** (Q2): se declara en UI, contratos y manuales.
- El Anvil de GCP es un nodo de desarrollo: su estado puede reiniciarse. Mitigación: runbook de
  reset con reconciliación off-chain, snapshot periódico y segundo endpoint RPC (H-12).
- **Claves de rol SOLO DEV (H-11):** las semillas usan cuentas conocidas de Anvil; en C0 se sustituyen
  por claves dedicadas en Secret Manager y un gate de CI falla si una wallet de rol coincide con una
  cuenta conocida de Anvil. La cuenta #0 de Anvil **nunca** debe ser Admin/Owner.

## 9.1 Operación, continuidad y coste (B8)

| Tema | Compromiso | Verificación |
|---|---|---|
| Backup Cloud SQL | backups automáticos 7 días + PITR 7 días | `gcloud sql instances describe` + restore drill |
| RPO / RTO | **RPO ≤ 15 min · RTO ≤ 4 h** | ensayo trimestral con fecha y RTO medido |
| Restauración | ensayo mensual a instancia `-restore-test`; 27 tablas + conteos | acta `pruebas/restore_<fecha>.md` |
| Clave KYC | Secret Manager con versiones + envelope encryption KMS; rotación 90 días; copia en `truekeate-main` | `secrets versions list` + descifrado con versión anterior |
| Pooling | `PG_POOL_MAX=5` × `max-instances=3` = 15 conexiones (≤ 30 % del límite); pgbouncer si se supera | test de carga + métrica de conexiones |
| RPC | primario + `RPC_URL_FALLBACK` con health-check y conmutación | test de caída del primario |
| Anvil | runbook de reset con reconciliación off-chain; snapshot del estado; nunca producción | runbook en `pruebas/` |
| Región | apps `europe-west1` vs BD `southamerica-east1`: medir p95 y, si incumple, mover apps a `southamerica-east1` | medición en C0 |
| Coste | presupuesto demo **≤ 50 USD/mes**; budget alerts 10/25/50 USD; desglose: Cloud Run ~10, Cloud SQL ~15, storage/egress ~10, Secret Manager ~2, extras ~13 | factura + alertas activas |

> Diseño detallado y criterios de aceptación: `diseno_cierre_v3_2.md` §5.

## 10. Respaldo y retorno

- Respaldo completo de la v2 (2026-10-31): `rwa-v2-backup-20261031T171645Z.zip` (SHA-256 en el manifiesto).
- Plan de retorno: la v2 permanece desplegada y congelada; revertir = reapuntar revisiones de
  Cloud Run a las imágenes `20261029-174915` y conservar el esquema v2 (la migración v3 es aditiva).
