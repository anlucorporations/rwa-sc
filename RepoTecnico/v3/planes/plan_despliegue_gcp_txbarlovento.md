# Plan de despliegue en GCP — txbarlovento (Barlo Ventas)

> **Fecha:** 2026-11-06 · **Estado:** propuesta para aprobación (no se ha desplegado nada)
> **Objetivo:** desplegar el Metaplace RWA v3 bajo el proyecto **txbarlovento**, reutilizando los
> **servicios globales de Foundry (Anvil) y PostgreSQL** ya operados por la organización.
> **Decisión de naming:** no existe un proyecto GCP accesible llamado `txbarlovento`; el proyecto
> equivalente es **`barloventasv2` (BarloVentasV2)**. Este plan asume desplegar ahí salvo instrucción
> contraria (ver §9, decisión D1).

---

## 1. Estado actual del GCP de txbarlovento (evidencia 2026-11-06)

### 1.1 Proyecto `barloventasv2` (BarloVentasV2)

| Elemento | Valor observado |
|---|---|
| Número de proyecto | `107180969515` |
| Región por defecto | `europe-west1` |
| Billing (describe) | `billingEnabled: true` · cuenta `013B00-B9A67C-014A43` |
| **Estado real de APIs** | ⚠️ varias APIs responden `BILLING_DISABLED` (cuenta en estado irregular): `sqladmin`, `secretmanager`, `artifactregistry`, `vpcaccess`, `cloudscheduler`, `billingbudgets` |
| Cloud Run activos | 3 servicios, todos `Ready` en `europe-west1` |
| Service account | `107180969515-compute@developer.gserviceaccount.com` (**default compute**, mala práctica) |
| Imágenes | `gcr.io/barloventasv2/{compra-stablecoin,pasarela-de-pago,web-admin}:v2` (Container Registry legacy) |
| Cloud SQL | **ninguno** en el proyecto (usa PostgreSQL global) |
| VPC connectors | ninguno (`vpcaccess` no habilitado) |
| Cloud Scheduler / Jobs | ninguno (APIs no habilitadas) |
| Cloud Build triggers | ninguno |
| Env claves (web-admin) | `DATABASE_URL`, `NEXT_PUBLIC_RPC_URL`, `NEXT_PUBLIC_ECOMMERCE_MAIN_ADDRESS` → confirma dependencia de **servicios globales** (BD y Foundry externos) |

**Servicios Cloud Run actuales de txbarlovento:**

| Servicio | URL | Imagen |
|---|---|---|
| `barloventas-pasarela` | https://barloventas-pasarela-fjsz6i7o3a-ew.a.run.app | `gcr.io/barloventasv2/pasarela-de-pago:v2` |
| `barloventas-compra-stablecoin` | https://barloventas-compra-stablecoin-fjsz6i7o3a-ew.a.run.app | `gcr.io/barloventasv2/compra-stablecoin:v2` |
| `barloventas-web-admin` | https://barloventas-web-admin-fjsz6i7o3a-ew.a.run.app | `gcr.io/barloventasv2/web-admin:v2` |

### 1.2 Servicio global de PostgreSQL

| Elemento | Valor observado |
|---|---|
| Instancia | `truekeate-main:southamerica-east1:truekeate-db-dev` |
| Motor | PostgreSQL **15** · estado `RUNNABLE` |
| Región | `southamerica-east1` |
| Backups | `enabled: true` · **PITR: true** (RPO ≤ 15 min) |
| IP pública | habilitada (`ipv4Enabled: true`) |
| Bases existentes | `truekeate`, `postgres`, `ggtov2`, `sfhostpot` — **no existe una base RWA dedicada** |
| Uso por txbarlovento | vía `DATABASE_URL` (secreto global; no legible ahora por billing) |

### 1.3 Servicio global de Foundry (Anvil)

| Elemento | Valor observado |
|---|---|
| Servicio | `mcc-foundry-anvil` en `mcc-ecommerce`, `europe-west1` |
| URL | https://mcc-foundry-anvil-slzlptbcla-ew.a.run.app |
| Revisión | `mcc-foundry-anvil-00016-lhb` · condición `Ready` |
| Chain | `31337` (canónica), estado persistido en GCS (`mcc-ecommerce-anvil-state`) |
| **Estado RPC** | 🔴 **HTTP 500** al llamar `eth_chainId` (servicio no operativo) |
| Servicios RWA existentes | `rwa-identity`, `rwa-issuer`, `rwa-token` (Cloud Run) + job `rwa-indexer` (`Ready`) |
| Contratos desplegados | `sc/config/v3_roles.json`, `v3_assets.json`, `v3_market.json` (BRLT, AssetFactory, Marketplace) — estado en el bucket GCS |

### 1.4 Bloqueo transversal

La cuenta de facturación `013B00-B9A67C-014A43` está en estado irregular: `gcloud billing projects describe`
devuelve `true`, pero las APIs de los proyectos `mcc-ecommerce`, `truekeate-main` y `barloventasv2`
responden `BILLING_DISABLED` / `accountDisabled`. Consecuencias:
- El **RPC global de Foundry no responde** (500) y los secretos no son legibles por API.
- Cualquier despliegue nuevo fallará en el primer `gcloud run deploy`/`gcloud secrets` hasta regularizar el pago.

**Gate 0 del plan:** regularizar la cuenta de facturación antes de ejecutar cualquier fase.

---

## 2. Arquitectura objetivo (txbarlovento + servicios globales)

```
                        ┌──────────────────────────────┐
   Usuarios ──HTTPS──▶  │ Cloud Run: txb-metaplace      │  (Next.js standalone + API routes)
                        │  · shell Metaplace v3         │
                        │  · SIWE / KYC / claims        │
                        │  · marketplace + escrow API   │
                        └──────┬───────────────┬────────┘
                               │               │
             Cloud SQL socket  │               │ HTTPS (RPC)
                               ▼               ▼
        ┌──────────────────────────┐   ┌──────────────────────────────────┐
        │ GLOBAL PostgreSQL        │   │ GLOBAL Foundry (Anvil 31337)      │
        │ truekeate-db-dev (PG15)  │   │ mcc-foundry-anvil (Cloud Run)     │
        │ base: txbarlovento        │   │ contratos: BRLT/Factory/Marketplace│
        │ schema: rwa               │   │ estado: GCS anvil-state           │
        └──────────────────────────┘   └──────────────────────────────────┘
                               ▲
        ┌──────────────────────┴───────────────────────┐
        │ Cloud Run Job: txb-indexer                    │  ← Cloud Scheduler (cada 10 min)
        │ Cloud Run Job: txb-maintenance (purga Q10)    │  ← Cloud Scheduler (diario)
        └───────────────────────────────────────────────┘
```

**Principios:**
1. **PostgreSQL y Foundry son globales y compartidos**: txbarlovento **no** crea Cloud SQL ni Anvil propios;
   consume la instancia y el servicio existentes. Aislamiento por **base de datos dedicada** (`txbarlovento`)
   dentro de la instancia global y por **juego de contratos propio** en la misma chain.
2. Una sola imagen Cloud Run para el shell + API (las 3 suites se consolidan en `apps/metaplace`).
3. Secretos en **Secret Manager de barloventasv2** (API a habilitar), nunca env en texto plano.
4. IAM de mínimo privilegio: una SA por workload (no la default compute).
5. Región `europe-west1` para cómputo; la BD global queda en `southamerica-east1` (latencia de red aceptable
   para API; si el piloto exige < 50 ms, evaluar réplica o mover la BD, fuera del alcance de este plan).

---

## 3. Fase 0 — Prerrequisitos y desbloqueo (bloqueante)

| # | Acción | Comando / criterio |
|---|---|---|
| 0.1 | Regularizar cuenta de facturación | Consola GCP → Billing; verificar `gcloud billing projects describe barloventasv2` y que `gcloud secrets list` funcione |
| 0.2 | Habilitar APIs en `barloventasv2` | `run`, `cloudbuild`, `artifactregistry`, `secretmanager`, `sqladmin`, `cloudscheduler`, `cloudscheduler`+`run` jobs, `logging`, `monitoring`, `billingbudgets`, `iam`, `compute` (si VPC) |
| 0.3 | Verificar RPC global Foundry | `curl -X POST <ANVIL_URL> eth_chainId` → `0x7a69`; si no responde, reiniciar/redesplegar el servicio global con su estado GCS |
| 0.4 | Verificar BD global | `gcloud sql instances describe truekeate-db-dev` → RUNNABLE + backups/PITR |
| 0.5 | Presupuesto y alertas | Crear budget en `billingbudgets` (p. ej. 150 €/mes) con alertas 50/80/100 % |

**Gate G0:** billing OK + APIs OK + RPC `0x7a69` + BD RUNNABLE + budget creado.

---

## 4. Fase 1 — Identidad, red y datos

### 4.1 Service accounts

| SA | Uso | Roles |
|---|---|---|
| `txb-metaplace@barloventasv2.iam.gserviceaccount.com` | Cloud Run web/API | `cloudsql.client`, `secretmanager.secretAccessor` (solo secretos txb) |
| `txb-jobs@barloventasv2.iam.gserviceaccount.com` | Jobs indexer/mantenimiento | idem + permisos mínimos de BD |
| `txb-builder@…` (opcional) | Cloud Build | `run.developer`, `artifactregistry.writer`, `iam.serviceAccountUser` |

### 4.2 Base de datos dedicada (dentro de la instancia global)

```bash
# Crear base dedicada (no reutilizar "truekeate" para aislar datos del Metaplace)
gcloud sql databases create txbarlovento \
  --instance=truekeate-db-dev --project=truekeate-main

# Usuario dedicado con contraseña en Secret Manager (nunca en texto plano)
gcloud sql users create txb_app --instance=truekeate-db-dev \
  --project=truekeate-main --password="$(openssl rand -base64 24)"
```

- Conectar Cloud Run por **socket Cloud SQL** (`--add-cloudsql-instances=truekeate-main:southamerica-east1:truekeate-db-dev`)
  → `DATABASE_URL=postgresql://txb_app:…@/txbarlovento?host=/cloudsql/truekeate-main:southamerica-east1:truekeate-db-dev`.
  Evita VPC connector y no expone la BD a Internet. Alternativa: IP autorizada + SSL (menos recomendable).
- Cargar esquema canónico: `base_datos.sql` **v3.3** + `migracion_v3_2_a_v3_3.sql` si aplica; esquema `rwa`.
- Aplicar privilegios mínimos (`GRANT USAGE ON SCHEMA rwa`, `SELECT/INSERT/UPDATE/DELETE` de tablas, sin DDL en runtime).
- **Restore drill**: restaurar PITR a una instancia temporal y validar esquema/conteos antes del piloto.

### 4.3 Secretos (Secret Manager `barloventasv2`)

| Secreto | Contenido |
|---|---|
| `txb-database-url` | URL con socket y usuario `txb_app` |
| `txb-siwe-session-secret` | ≥32 caracteres aleatorios |
| `txb-kyc-encryption-key` | 32 bytes hex (AES-256-GCM) |
| `txb-anvil-admin-key` | clave dedicada deployer/roles (no cuenta Anvil por defecto) |
| `txb-brlt-admin/minter/pauser-key` | claves de roles BRLT (rotación 90 d) |
| `txb-arbiter-key` (opcional) | árbitro separado |

IAM: solo las SA `txb-*` con `secretAccessor` sobre `txb-*`.

**Gate G1:** base `txbarlovento` con esquema `rwa` cargado, usuario de app con permisos mínimos, secretos creados y accesibles, restore drill documentado.

---

## 5. Fase 2 — Contratos en el Foundry global

> ⚠️ **Dependencia compartida:** los contratos viven en la misma chain 31337 y en el mismo Anvil que otros
> proyectos. Aislamiento por configuración (`sc/config/v3_*_txb.json`) y por claves/roles propios.

1. Verificar estado previo: `cast code <BRLT/FACTORY/MARKETPLACE>` contra el RPC global.
2. Desplegar en orden con la clave dedicada (artefactos NUEVOS con sufijo `-txb`):
   `DeployBarloToken` → `GrantBarloRoles` → `DeployAssets` → `DeployMarketplace`.
3. Guardar direcciones en `rwa-sc/sc/config/v3_roles_txb.json`, `v3_assets_txb.json`, `v3_market_txb.json`
   y exportarlas como variables de entorno de Cloud Run (`NEXT_PUBLIC_*` / `MARKETPLACE_ADDRESS`).
4. Registrar la clave deployer y los roles en Secret Manager; nunca en el repositorio.
5. **Riesgo de estado:** el Anvil global persiste en GCS pero no es HA; documentar runbook de recuperación
   (redeploy + re-seed de roles) y validar backup/replica del bucket.

**Gate G2:** contratos desplegados y verificados (`cast code` ≠ `0x`), direcciones en config versionada, roles concedidos a claves dedicadas (gate anti-Anvil), `Marketplace` aprobado en `AssetFactory`/tokens según flujo.

---

## 6. Fase 3 — Imagen y despliegue del shell

1. **Artifact Registry** (`barloventasv2`, `europe-west1`, repo `txb`).
2. Build de `rwa-web/apps/metaplace` (Next standalone) con `NEXT_PUBLIC_CHAIN_ID=31337`,
   `NEXT_PUBLIC_RPC_URL=<ANVIL_URL>`, `NEXT_PUBLIC_DEPLOYMENT_JSON`/`MARKETPLACE_ADDRESS` del set `txb`.
3. Despliegue Cloud Run:

| Parámetro | Valor |
|---|---|
| Servicio | `txb-metaplace` |
| Región | `europe-west1` |
| SA | `txb-metaplace@…` |
| Min/Max instancias | `0` / `10` (piloto) |
| Concurrency | `80` |
| Memoria / CPU | `512Mi` / `1` |
| Timeout | `60s` |
| Ingress | `all` (o `internal-and-cloud-load-balancer` + LB/WAF) |
| Cloud SQL | `--add-cloudsql-instances=truekeate-main:southamerica-east1:truekeate-db-dev` |
| Health | startup probe `/api/health` |

Variables (no secretas): `NEXT_PUBLIC_CHAIN_ID`, `NEXT_PUBLIC_RPC_URL`, `RPC_URL`, `MARKETPLACE_ADDRESS`,
`ALLOWED_ORIGINS=https://<dominio>`, `ALLOWED_HOSTS=<host>`, `SESSION_COOKIE_NAME=__Host-rwa_session`,
`COOKIE_SECURE=1`, `SESSION_TTL_HOURS`, `SESSION_ROLLING=1`, `ADMIN_REAUTH_WINDOW_MIN`, `RATE_LIMIT_*`,
`UPLOAD_QUOTA_*`, `CHAIN_VERIFY_TX=1`.
Secretos montados: `DATABASE_URL`, `SIWE_SESSION_SECRET`, `KYC_ENCRYPTION_KEY`.

4. **Jobs y scheduler:**
   - `txb-indexer` (Cloud Run Job, SA `txb-jobs`, mismas DB/RPC) ← Cloud Scheduler `*/10 * * * *`.
   - `txb-maintenance` (purga `purge_expired_documents`, diario 03:00 UTC).
5. **Dominio y TLS:** domain mapping de Cloud Run o LB externo con certificado gestionado; HSTS ya aplicado.
   Opcional (pre-piloto): Cloud Armor + WAF delante del LB para rate limiting distribuido (AM-08).

**Gate G3:** `GET /api/health` 200 con `database:"ok"` y `chainId:31337`; login SIWE real; `GET /api/catalog` responde; logs sin errores 5xx en 30 min; jobs y scheduler en `Ready`.

---

## 7. Fase 4 — Verificación funcional (E2E) y cutover

1. Ejecutar la batería E2E de los ciclos C1–C6 adaptada al dominio (`ALLOWED_ORIGINS`), con 3 wallets de prueba.
2. Smoke obligatorio: identidad → KYC (2 docs) → claim SOCIO → alta de activo → listing → orden → confirmación →
   consumo de servicio; y negativos (401/403/409/429).
3. **Datos de demostración**: seed controlado (script idempotente) solo en ventana de demo; documentar limpieza.
4. Cutover: si se reemplaza `barloventas-web-admin`, publicar `txb-metaplace` como servicio nuevo primero,
   redirigir tráfico tras gate y mantener el anterior 7 días para rollback.
5. **Rollback:** `gcloud run services update-traffic txb-metaplace --to-revisions=<prev>=100`; reversión de BD no
   destructiva (PITR a instancia nueva) y redeploy de contratos solo si el estado de la chain se corrompe.

---

## 8. Operación, seguridad y costos

### 8.1 Observabilidad
- Alertas: 5xx > 1 %, latencia p95 > 2 s, instancias al máximo, errores del indexer, `database:"down"`,
  RPC 500/latencia, uso de CPU/memoria, fallos de scheduler.
- Logs estructurados (JSON) con request-id; retención 30 días; export de auditoría (CU-18) pendiente en roadmap.

### 8.2 Seguridad
- SA por workload, sin claves en env, secretos rotados (60–90 d), `secretAccessor` acotado.
- Cloud Run `ingress` + Cloud Armor (WAF), CSP con nonce ya implementada, cookie `__Host-`, guardia de `Origin`.
- Gate anti-Anvil: ninguna cuenta por defecto de Anvil como rol de producción.
- Dependencias: SBOM/dependency scanning (pendiente AM-10).

### 8.3 Costo estimado (piloto, mensual)
| Componente | Estimación |
|---|---|
| Cloud Run web (scale-to-zero, 2–5 instancias medias) | 10–30 € |
| Jobs + Scheduler | < 5 € |
| Artifact Registry/GCS/Secrets | < 10 € |
| PostgreSQL global (compartido) | asignar cuota interna (100–200 €/mes de la instancia existente) |
| Foundry global (compartido) | asignar cuota interna |
| **Total incremental txbarlovento** | **≈ 25–45 €/mes** (+ cuota de servicios globales) |

---

## 9. Decisiones abiertas y riesgos

| ID | Decisión / riesgo | Opciones | Recomendación |
|---|---|---|---|
| D1 | ¿Proyecto `txbarlovento`? | No existe proyecto accesible con ese ID; `barloventasv2` es el equivalente | Confirmar; por defecto desplegar en `barloventasv2` |
| D2 | Tenancy de BD | base dedicada `txbarlovento` vs schema `txb` en base existente | **Base dedicada** (aislamiento, borrado limpio) |
| D3 | Foundry compartido | Global compartido vs Anvil dedicado para txbarlovento | Piloto: global; producción: Anvil dedicado HA |
| D4 | Dominio | Subdominio de barloventas vs nuevo | Subdominio con TLS gestionado |
| R1 | Facturación irregular | Bloquea toda la fase 0 | Desbloqueo previo obligatorio |
| R2 | RPC global caído (500) | Sin cadena no hay tokenización/marketplace | Restaurar servicio global y validar antes de G2 |
| R3 | BD global compartida | Ruido/latencia entre tenants | Base aislada + límites de conexión; evaluar réplica |
| R4 | Estado Anvil en GCS | Reset/redeploy pierde direcciones | Runbook de redeploy + config versionada |
| R5 | APIs deshabilitadas en barloventasv2 | Secret Manager/SQL/Scheduler no disponibles | Gate G0 |
| R6 | Acceso a KYC/privacidad | DPIA pendiente | Completar DPIA/DPO antes de datos reales |

---

## 10. Checklist de aceptación del despliegue

- [ ] G0: billing regularizado, APIs habilitadas, RPC `0x7a69`, BD RUNNABLE, budget con alertas.
- [ ] G1: base `txbarlovento` + esquema `rwa` v3.3, usuario app con permisos mínimos, secretos `txb-*`.
- [ ] G2: BRLT + Factory + Marketplace desplegados con claves dedicadas y config `*_txb.json` versionada.
- [ ] G3: `txb-metaplace` con health OK, SIWE real, logs limpios, jobs/scheduler activos.
- [ ] G4: E2E C1–C6 adaptado en verde contra el dominio desplegado.
- [ ] Operación: alertas, runbooks (billing, RPC, BD), restore drill y DPIA al día.

*Fin del plan. Ninguna acción de despliegue fue ejecutada.*
