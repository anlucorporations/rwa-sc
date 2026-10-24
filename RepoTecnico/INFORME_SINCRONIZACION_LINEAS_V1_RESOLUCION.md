# ✅ Resolución de hallazgos — Informe de Sincronización de Líneas V1

> **Fecha:** 2026-10-24 · **Base:** [INFORME_SINCRONIZACION_LINEAS_V1.md](INFORME_SINCRONIZACION_LINEAS_V1.md)
> **Resultado:** **10 de 10 hallazgos resueltos** · **H-06 validado con el E2E en verde** (identidad → claim → aprobación → `addClaim` on-chain, `E2E_EXIT=0`) · 2 defectos nuevos detectados y corregidos (**H-11** en `@sc`, **H-12** en `@web`, ver §5).
> **Regla:** cada resolución se commiteó en la línea que corresponde y se verificó con su gate.

---

## 1. Estado por hallazgo

| ID | Sev. | Hallazgo | Estado | Evidencia de resolución |
|---|---|---|---|---|
| **H-01** | ALTA | Sincronización solo en árbol de trabajo (despliegue nuevo untracked; `deployments.ts` sin commitear) | ✅ **RESUELTO** | `rwa-sc` commit `744f7d7` (versiona `31337-20261023T185622Z.json`); `rwa-web` commit `2ebacaf` (regenera `deployments.ts` + `.env.example`); gate `86ed1ed` exige artefacto **versionado y referenciado** |
| **H-02** | ALTA | `@sc` con commits locales sin subir; `@web` publicada | ✅ **RESUELTO** | **`/push` autorizado y ejecutado (2026-10-24):** `rwa-sc` `f946b1e` publicado en **`origin`, `github` y `codecrypto`** (0/0); `rwa-web` `b17867d` publicado en `origin` y `github` (0/0); `RWA_SC_REF` fijado al SHA publicado (commit `3d3f19c`) |
| **H-03** | ALTA | Docs de `@sc` citaban el despliegue antiguo | ✅ **RESUELTO** | `rwa-sc` commit `1a01e72` (`estado_proyecto` + `entornos_globales`: fuente vigente `31337-20261023…`, bloque 549; Ciclo 9 conservado como histórico); gate documental en `5b6d074` |
| **H-04** | MEDIA | Gate del espejo de datos no cableado en CI | ✅ **RESUELTO** | `rwa-web` commit `606b686`: `validate:abi-drift` ejecuta `check_sincronizacion_datos.sh --check`; `ci_local.sh` paso **3/8** |
| **H-05** | MEDIA | Gate de deriva con HEAD móvil / variable sin documentar | ✅ **RESUELTO** | `rwa-web` commit `750dd5c`: soporte **`RWA_SC_REF`** (SHA/tag) en CI + documentación del pin |
| **H-06** | MEDIA | E2E contrato↔interfaz fuera de CI | ✅ **RESUELTO Y VALIDADO** | `rwa-web` commits `1089fe6` (job `e2e:claim-flow`, wrapper `ci_e2e.sh`) y `ef585a9` (CSP + clonado de `rwa-sc` en el job). **Ejecución local completa en verde:** identidad → claim → aprobación/firma → `addClaim` on-chain (`E2E_EXIT=0`). Pendiente: repetirlo en runner de CI |
| **H-07** | MEDIA | Claves privadas demo en UI y paquete compartido | ✅ **RESUELTO** | `rwa-web` commit `825c9b7`: `DEMO_ACCOUNTS` solo rol+dirección; dashboard sin PK; gate `check-no-private-keys.sh` en CI y `ci_local` 1/8. **Verificado:** gate exit 0; typecheck `@rwa/shared` y `@rwa/issuer` exit 0; tests `@rwa/shared` exit 0 |
| **H-08** | BAJA | Sin política de versionado/compatibilidad ABI↔web | ✅ **RESUELTO** | `rwa-web` commit `1089fe6`: [CONTRATO_INTEGRACION_SC_WEB.md](CONTRATO_INTEGRACION_SC_WEB.md) (fuentes de verdad, pin, reglas de compatibilidad, gates, roles y checklist) |
| **H-09** | BAJA | Dependencia `jq` sin preflight | ✅ **RESUELTO** | `rwa-web` commit `750dd5c`: `sync-contracts.sh` falla con mensaje claro si falta `jq` |
| **H-10** | BAJA | `@web` con 58 cambios WIP y versiones doc desalineadas | ✅ **RESUELTO** | `rwa-web` commits `080d2ea` (WIP código/scripts validado: typecheck 0, lint 0 errores, **55/55 tests**, cobertura 96,8 %) y `b17867d` (docs: estado v3.1, requerimientos v1.3, plan v1.3); árbol limpio y publicado |

---

## 2. Commits de resolución

| Repo | Commit | Contenido |
|---|---|---|
| `rwa-sc` | `744f7d7` | versiona el artefacto de despliegue canónico 2026-10-23 (H-01) |
| `rwa-sc` | `1a01e72` | documentación alineada con el despliegue canónico (H-03) |
| `rwa-web` | `2ebacaf` | contratos y config regenerados (H-01) |
| `rwa-web` | `86ed1ed` | gate: despliegue versionado + referenciado (H-01) |
| `rwa-web` | `5b6d074` | gate documental del despliegue en `@sc` (H-03) |
| `rwa-web` | `606b686` | gate de datos en CI y `ci_local` (H-04) |
| `rwa-web` | `825c9b7` | claves demo fuera del bundle + gate de secretos (H-07) |
| `rwa-web` | `750dd5c` | preflight `jq` + pin `RWA_SC_REF` (H-09, H-05) |
| `rwa-web` | `1089fe6` | E2E en CI + contrato de integración (H-06, H-08) |

> **Publicación:** `rwa-sc` `f946b1e` y `rwa-web` `b17867d` están publicados (0/0 en todos sus remotos). `RWA_SC_REF` fijado a `f946b1e…` en la CI de `@web` (commit `3d3f19c`).

---

## 3. Verificación final (ejecutada)

```bash
cd /home/dsh/workspace/RWA/rwa-web
./scripts/check-network-literals.sh              # exit 0
./scripts/check-no-private-keys.sh               # exit 0
./scripts/check-contract-drift.sh                # exit 0 (incluye despliegue versionado + doc)
./RepoTecnico/check_sincronizacion_datos.sh --check  # exit 0 (3/3)
python3 -c "import yaml; yaml.safe_load(open('.gitlab-ci.yml'))"  # YAML OK
pnpm --filter @rwa/shared typecheck              # exit 0
pnpm --filter @rwa/issuer typecheck              # exit 0
pnpm --filter @rwa/shared test                   # exit 0
```

| Gate | Resultado |
|---|---|
| Literales de red | ✅ 0 |
| Claves privadas en producción | ✅ 0 |
| Deriva ABI/direcciones + despliegue + doc | ✅ exit 0 |
| Espejo de datos D-102 | ✅ 3/3 idénticos |
| YAML de CI | ✅ válido (4 stages, 8 jobs) |
| Typecheck `@rwa/shared` / `@rwa/issuer` | ✅ exit 0 |
| Tests `@rwa/shared` | ✅ exit 0 |
| **E2E claim-flow (local, con CSP corregida)** | ✅ **identidad → claim → aprobación/firma → `addClaim` on-chain** (`E2E_EXIT=0`; 0 errores de CSP) |

---

## 4. Pendiente para cerrar al 100 %

1. **H-06 — repetir `e2e:claim-flow` en un runner de CI** (imagen Playwright + Foundry + `E2E_DATABASE_URL`). La ejecución local ya está **en verde**; ver §3 y §5.

---

## 5. Hallazgos nuevos detectados al ejecutar el E2E (corregidos)

### H-11 (ALTA, `@sc`) — `deploy.sh` fallaba con Foundry 1.8.3 · ✅ RESUELTO

- **Evidencia:** el despliegue efímero verificó **10/10 contratos**, pero el smoke test (AF-07) abortó:
  `ERROR: token.maxBurnPerTx() (1000000000000000000000000 [1e24]) != artefacto (1000000000000000000000000)`.
- **Causa raíz:** `rwa-sc/sc/script/deploy.sh` comparaba la **cadena exacta** de `cast call`; Foundry 1.8.3 anexa la notación científica (` [1e24]`).
- **Fix:** commit `c605ff0` — helper `norm_num()` que elimina el sufijo entre corchetes y espacios, aplicado a `getModuleCount`, `maxBurnPerTx` y `maxForcedPerTx`.

### H-12 (ALTA, `@web`) — la CSP bloqueaba el RPC configurado · ✅ RESUELTO

- **Evidencia:** con `E2E_DEBUG=1`, la consola del navegador mostró decenas de:
  `Connecting to 'http://127.0.0.1:8546/' violates the following Content Security Policy directive: "connect-src 'self' https: wss:"`.
  El navegador no podía leer el recibo de la transacción → `waitForTransactionReceipt` quedaba colgado y el flujo agotaba el timeout.
- **Impacto adicional:** la CSP también rompía el **desarrollo local** contra Anvil por HTTP (la red de desarrollo canónica documentada), no solo el E2E.
- **Fix:** commit `ef585a9` — `connect-src` incorpora el **origen de `NEXT_PUBLIC_RPC_URL`** y, en desarrollo, `http://localhost:*` / `http://127.0.0.1:*`. Verificado en el E2E: **0 errores de CSP** y flujo completo en verde.

---

*Fin del registro — 2026-10-24.*
