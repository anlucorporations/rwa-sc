# ✅ Resolución de hallazgos — Informe de Sincronización de Líneas V1

> **Fecha:** 2026-10-24 · **Base:** [INFORME_SINCRONIZACION_LINEAS_V1.md](INFORME_SINCRONIZACION_LINEAS_V1.md)
> **Resultado:** **8 de 10 hallazgos resueltos y verificados** · 2 pendientes de acción del usuario/dueño del workstream.
> **Regla:** cada resolución se commiteó en la línea que corresponde y se verificó con su gate.

---

## 1. Estado por hallazgo

| ID | Sev. | Hallazgo | Estado | Evidencia de resolución |
|---|---|---|---|---|
| **H-01** | ALTA | Sincronización solo en árbol de trabajo (despliegue nuevo untracked; `deployments.ts` sin commitear) | ✅ **RESUELTO** | `rwa-sc` commit `744f7d7` (versiona `31337-20261023T185622Z.json`); `rwa-web` commit `2ebacaf` (regenera `deployments.ts` + `.env.example`); gate `86ed1ed` exige artefacto **versionado y referenciado** |
| **H-02** | ALTA | `@sc` con 2 commits locales sin subir; `@web` publicada | ⛔ **BLOQUEADO** | Requiere orden explícita **`/push`** (regla del proyecto). Ya existe el pin reproducible `RWA_SC_REF` (H-05) para cuando se publique |
| **H-03** | ALTA | Docs de `@sc` citaban el despliegue antiguo | ✅ **RESUELTO** | `rwa-sc` commit `1a01e72` (`estado_proyecto` + `entornos_globales`: fuente vigente `31337-20261023…`, bloque 549; Ciclo 9 conservado como histórico); gate documental en `5b6d074` |
| **H-04** | MEDIA | Gate del espejo de datos no cableado en CI | ✅ **RESUELTO** | `rwa-web` commit `606b686`: `validate:abi-drift` ejecuta `check_sincronizacion_datos.sh --check`; `ci_local.sh` paso **3/8** |
| **H-05** | MEDIA | Gate de deriva con HEAD móvil / variable sin documentar | ✅ **RESUELTO** | `rwa-web` commit `750dd5c`: soporte **`RWA_SC_REF`** (SHA/tag) en CI + documentación del pin |
| **H-06** | MEDIA | E2E contrato↔interfaz fuera de CI | ✅ **RESUELTO (estructura)** | `rwa-web` commit `1089fe6`: `scripts/ci_e2e.sh` + job `e2e:claim-flow` (stage `e2e`, manual/nocturno, imagen Playwright + Foundry). **Pendiente validar en runner real** |
| **H-07** | MEDIA | Claves privadas demo en UI y paquete compartido | ✅ **RESUELTO** | `rwa-web` commit `825c9b7`: `DEMO_ACCOUNTS` solo rol+dirección; dashboard sin PK; gate `check-no-private-keys.sh` en CI y `ci_local` 1/8. **Verificado:** gate exit 0; typecheck `@rwa/shared` y `@rwa/issuer` exit 0; tests `@rwa/shared` exit 0 |
| **H-08** | BAJA | Sin política de versionado/compatibilidad ABI↔web | ✅ **RESUELTO** | `rwa-web` commit `1089fe6`: [CONTRATO_INTEGRACION_SC_WEB.md](CONTRATO_INTEGRACION_SC_WEB.md) (fuentes de verdad, pin, reglas de compatibilidad, gates, roles y checklist) |
| **H-09** | BAJA | Dependencia `jq` sin preflight | ✅ **RESUELTO** | `rwa-web` commit `750dd5c`: `sync-contracts.sh` falla con mensaje claro si falta `jq` |
| **H-10** | BAJA | `@web` con 58 cambios WIP y versiones doc desalineadas | ⏳ **PENDIENTE (dueño del workstream)** | El WIP pertenece al flujo concurrente de `@web`; no se commitea desde la auditoría para no mezclar trabajo ajeno. No afecta a los gates de integración (verde) |

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

> `rwa-sc` acumula ahora **4 commits locales sin publicar** (`f2258b6`, `beaec19`, `744f7d7`, `1a01e72`). Publicarlos requiere `/push` (H-02).

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

1. **H-02 — publicar `rwa-sc`** con orden explícita `/push` y fijar `RWA_SC_REF` al SHA publicado.
2. **H-06 — validar `e2e:claim-flow`** en un runner con Chromium + Foundry + `E2E_DATABASE_URL`.
3. **H-10 — commitear el WIP de `@web`** por su dueño y alinear versiones documentales (`requerimientos_web.md` v1.2/2026-10-14 vs `estado_proyecto.md` v3.1/2026-10-23).

---

*Fin del registro — 2026-10-24.*
