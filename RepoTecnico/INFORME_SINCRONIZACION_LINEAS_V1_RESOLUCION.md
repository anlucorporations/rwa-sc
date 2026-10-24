# ✅ Resolución de hallazgos — Informe de Sincronización de Líneas V1

> **Fecha:** 2026-10-24 · **Base:** [INFORME_SINCRONIZACION_LINEAS_V1.md](INFORME_SINCRONIZACION_LINEAS_V1.md)
> **Resultado:** **10 de 10 hallazgos resueltos** · H-06 (E2E) validado en estructura y **en ejecución local**, con un defecto nuevo detectado en `@sc` que se documenta en §5.
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
| **H-06** | MEDIA | E2E contrato↔interfaz fuera de CI | ✅ **RESUELTO (estructura)** | `rwa-web` commit `1089fe6`: `scripts/ci_e2e.sh` + job `e2e:claim-flow` (stage `e2e`, manual/nocturno, imagen Playwright + Foundry). **Pendiente validar en runner real** |
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

---

## 4. Pendiente para cerrar al 100 %

1. **H-06 — corregir `@sc/script/deploy.sh`** (ver §5) y repetir la ejecución completa de `e2e:claim-flow`; después, validarlo también en un runner de CI con Chromium + Foundry + `E2E_DATABASE_URL`.

---

## 5. Defecto nuevo detectado al ejecutar el E2E (línea `@sc`)

**Hallazgo H-11 (ALTA, `@sc`) — el smoke test de `deploy.sh` falla con Foundry 1.8.3.**

- **Evidencia:** durante la ejecución local del E2E, el despliegue efímero creó el stack y verificó **10/10 contratos** con `cast code` y `cast call`, pero el smoke test (AF-07) abortó:
  `ERROR: token.maxBurnPerTx() (1000000000000000000000000 [1e24]) != artefacto (1000000000000000000000000)`.
- **Causa raíz:** `rwa-sc/script/deploy.sh:337` compara la **cadena exacta** de `cast call` con el valor JSON. En Foundry **1.8.3** `cast call` añade la anotación de unidad (` [1e24]`), por lo que la comparación falla aunque el valor numérico sea idéntico.
- **Impacto:** `deploy.sh` termina con `exit 1` en cualquier despliegue con la versión pinneada de Foundry; el artefacto se genera, pero el "verde" de despliegue no es alcanzable. Afecta a la reproducibilidad de `@sc` (y por tanto al E2E de `@web`).
- **Recomendación:** normalizar la salida antes de comparar, p. ej. `cast call … --format` o `| sed -E 's/ \[[^]]*\]$//'`, y convertir a decimal con `cast to-dec`. Añadir test del comparador.

---

*Fin del registro — 2026-10-24.*
