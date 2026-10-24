# INFORME DE SINCRONIZACIÓN DE LÍNEAS — RWA (`@sc` contratos ↔ `@web` interfaces)

> **Proyecto:** RWA (security token inspirado en ERC-3643 / T-REX)
> **Alcance:** ¿las dos líneas de desarrollo trabajan **sincronizadamente como un solo proyecto**?
> **Snapshot auditado:** `2026-10-24T00:22:40Z` — árbol **en flujo**: `rwa-sc` HEAD `0cbb0f7` (+1 despliegue sin trackear); `rwa-web` HEAD `bd00aff` (+58 ficheros modificados sin commitear).
> **Método:** `equipo-auditoria` — 3 fases (revisar · verificar adversarialmente · sintetizar) y 7 lentes adaptadas a la sincronización entre líneas.
> **Ejecución:** revisión y verificación adversarial realizadas directamente sobre el árbol real (comandos reproducibles en el Anexo A). El orquestador paralelo de subagentes no completó la Fase 1 por latencia del backend en esta sesión; **no se incluye ningún hallazgo que no haya sido contrastado contra archivos/comandos**.
> **Naturaleza:** el árbol está en movimiento (trabajo concurrente en ambas líneas); este informe fotografía el snapshot indicado.

---

## 1. Resumen ejecutivo — Veredicto

### ¿Las dos líneas trabajan sincronizadamente como un solo proyecto?

## ⚠️ PARCIAL — sí en el árbol de trabajo y en los gates; **no** en el estado commiteado/remoto.

La arquitectura de integración es **real y mecanizada** y supone un salto enorme frente al estado auditado en `INFORME_OPTIMIZACION_WEB_V1`:

- `rwa-web` ya **genera** sus ABIs y direcciones desde `rwa-sc` (`scripts/sync-contracts.sh` → `packages/shared/src/contracts/`) y tiene un **gate de deriva** (`check-contract-drift.sh`, RF-W-09) que hoy pasa.
- Los **3 artefactos de datos compartidos** (D-102) están duplicados byte a byte y el gate `check_sincronizacion_datos.sh --check` pasa (3/3).
- El esquema off-chain **v1.1** con payload EIP-712 está sincronizado en las dos líneas (commit `0cbb0f7` en `@sc` + espejo regenerado en `@web`).
- El monorepo (`apps/{identity,issuer,token}` + `packages/{shared,ui,config}`), la CI con 7 jobs y el flujo de claim EIP-712/SIWE están implementados.

**Pero la sincronización no está consolidada:**

1. El **despliegue canónico nuevo** (`31337-20261023T185622Z.json`) **no está versionado** en `rwa-sc` (untracked) y el `deployments.ts` de `rwa-web` está **modificado sin commitear** (el commit apunta al despliegue antiguo `31337-20261010T162639Z.json`). La foto "un solo proyecto" existe solo en el working tree (H-01).
2. `rwa-sc` tiene **2 commits locales sin subir** mientras `rwa-web` está sincronizada con su remoto (0/0): el estado remoto de las dos líneas diverge (H-02).
3. La documentación de `@sc` sigue declarando como fuente de verdad el **despliegue antiguo** (2026-10-10) mientras `@web` consume el nuevo (2026-10-23) (H-03).

**Conteo:** 0 CRÍTICA · **3 ALTA** · **4 MEDIA** · **3 BAJA**. No hay incompatibilidad funcional demostrada entre líneas; el riesgo es de **reproducibilidad y consolidación**, no de contrato roto en el árbol actual.

---

## 2. Metodología

| Fase | Qué se hizo |
|---|---|
| **1 · Revisar** | 7 lentes adaptadas: R1 criterios/gates/testabilidad · R2 consistencia contrato-interfaz · R3 completitud RNF de integración · R4 stakeholders/propiedad · R5 trazabilidad contrato→web · R6 riesgos técnicos · R7 seguridad y legal. |
| **2 · Verificar (adversarial)** | Cada candidato se contrastó contra el árbol real con `read`/`grep`/`git`/`sha256sum`/`diff` y ejecución de los gates en modo solo lectura; los no reproducibles se marcan "necesita verificación" o se descartan. |
| **3 · Sintetizar** | Deduplicación entre lentes, IDs únicos, priorización por severidad, plan de acción y criterios de aceptación. |

Severidades: `CRITICA` · `ALTA` · `MEDIA` · `BAJA`.

---

## 3. Lo que SÍ está sincronizado (verificado en el snapshot)

| Mecanismo | Evidencia | Resultado |
|---|---|---|
| Espejo de artefactos de datos (D-102) | `rwa-web/RepoTecnico/check_sincronizacion_datos.sh --check` | ✅ exit 0 — 3/3 idénticos (`base_datos.sql`, `diccionario_datos.md`, `diagrama_er.md`) |
| Generación de contratos desde `@sc` | `rwa-web/scripts/sync-contracts.sh` (lee `rwa-sc/sc/abis` y el último `sc/deployments/*.json`) | ✅ 16 ABIs + `deployments.ts` + `index.ts` generados y versionados |
| Gate de deriva ABI/direcciones (RF-W-09) | `rwa-web/scripts/check-contract-drift.sh` | ✅ exit 0 — "ABIs y direcciones sincronizados con rwa-sc" |
| Gate de literales de red (RF-W-08) | `rwa-web/scripts/check-network-literals.sh` | ✅ exit 0 — 0 direcciones/URLs/chainIds literales |
| Esquema de datos v1.1 (EIP-712) | `rwa-sc` commit `0cbb0f7` + espejo `@web` | ✅ sincronizado en ambos lados |
| Trazabilidad de cambios de contrato | `rwa-sc/CHANGELOG_ABIS.md` (incluye `GovernanceMultisig` y RNF-107) + ABI generada `GovernanceMultisig.ts` | ✅ el cambio está documentado y consumido |
| Monorepo y CI de `@web` | `.gitlab-ci.yml`: `validate:network-literals`, `validate:abi-drift`, `quality:typecheck`, `quality:lint`, `quality:test`, `quality:a11y-browser`, `build:apps` | ✅ 7 jobs definidos |
| Flujo E2E contrato↔interfaz | `rwa-web/scripts/e2e_claim_o5.mjs` (Playwright + viem, identidad→claim→aprobación→`addClaim`) | ⚠️ existe, pero es manual (ver H-06) |

---

## 4. Estado de calidad — métricas

| Métrica | Valor | Estado |
|---|---|---|
| Gate espejo de datos | 3/3 sincronizados | ✅ verificado (ejecutado) |
| Gate deriva ABIs/direcciones | exit 0 | ✅ verificado (ejecutado) |
| Gate literales de red | 0 literales | ✅ verificado (ejecutado) |
| ABIs fuente en `rwa-sc/sc/abis` | 16 JSON (incl. `GovernanceMultisig`) | ✅ verificado |
| Despliegues en `rwa-sc/sc/deployments` | 2 (1 versionado + 1 untracked) | ⚠️ verificado |
| Apps/paquetes `@web` | 3 apps + 3 paquetes | ✅ verificado |
| Jobs CI `@web` | 7 | ✅ verificado |
| Tests `@web` | 55 tests · cobertura crítica 97,16 % | ⚠️ necesita verificación (cifra del informe de cierre; no re-ejecutada) |
| Estado git `@sc` | HEAD `0cbb0f7`, **2 commits por delante** de `origin/rwa-sc-DSH-GCP` | ⚠️ verificado |
| Estado git `@web` | HEAD `bd00aff`, **58 cambios sin commitear**, 0/0 vs `origin` | ⚠️ verificado |
| E2E en CI | No hay job E2E | ❌ verificado |

---

## 5. Hallazgos por severidad

| ID | Sev. | Área | Título | Evidencia principal |
|---|---|---|---|---|
| **H-01** | **ALTA** | Integridad de artefactos | La sincronización real está **sin commitear**: despliegue nuevo untracked y contratos regenerados modificados | `rwa-sc`: `?? sc/deployments/31337-20261023T185622Z.json`; `rwa-web`: `M packages/shared/src/contracts/deployments.ts` (HEAD → `20261010…`, árbol → `20261023…`) |
| **H-02** | **ALTA** | Proceso/entrega | `@sc` tiene 2 commits locales sin subir; `@web` está publicada: el estado remoto de las líneas diverge | `git rev-list --left-right --count origin/rwa-sc-DSH-GCP...HEAD` → `0 2`; `@web` → `0 0` |
| **H-03** | **ALTA** | Documentación | Los docs de `@sc` declaran como fuente de verdad el **despliegue antiguo** mientras `@web` consume el nuevo | `rwa-sc/RepoTecnico/estado_proyecto.md:112`, `entornos_globales.md:90,283` → `31337-20261010T162639Z.json`; `rwa-web/.env.example:10` → `31337-20261023T185622Z.json` |
| **H-04** | **MEDIA** | CI/gates | El gate del espejo de datos (D-102) **no está cableado en CI** | `rwa-web/.gitlab-ci.yml` no invoca `check_sincronizacion_datos.sh`; solo `ci_local.sh`/manual |
| **H-05** | **MEDIA** | CI/reproducibilidad | El gate de deriva depende de `RWA_SC_REPO_URL` (falla si falta) y clona `--depth 1` el **HEAD móvil** de `rwa-sc` (sin SHA fijo) | `rwa-web/.gitlab-ci.yml:44-55`; documentado en `RepoTecnico/pruebas/o3_verificabilidad.md:66` |
| **H-06** | **MEDIA** | Verificación de integración | El E2E contrato↔interfaz **no corre en CI**; los gates verdes no prueban comportamiento | `scripts/e2e_claim_o5.mjs`, `scripts/test_e2e_o2.sh` existen; `.gitlab-ci.yml` sin job E2E |
| **H-07** | **MEDIA** | Seguridad | Claves privadas de cuentas demo expuestas en la **UI** y en el paquete compartido | `rwa-web/apps/issuer/app/dashboard/page.tsx:282,289,311`; `rwa-web/packages/shared/src/network/index.ts:72,77,82` |
| **H-08** | BAJA | RNF integración | No hay política de **versionado/compatibilidad ABI↔web** (pin de versión, reglas breaking, monitoreo de deriva fuera de CI) | `rwa-web/RepoTecnico/requerimientos_web.md` (RF-W-09 solo exige gate); D-102 cubre datos, no código |
| **H-09** | BAJA | Tooling | `sync-contracts.sh` depende de `jq` **sin preflight** | `rwa-web/scripts/sync-contracts.sh:58,77,82,87`; sin `command -v jq` |
| **H-10** | BAJA | Higiene documental | `@web` con 58 cambios sin commitear y versiones desalineadas (`requerimientos_web.md` v1.2 fecha 2026-10-14 vs estado v3.1 2026-10-23) | `rwa-web` `git status --short` (58); `RepoTecnico/requerimientos_web.md:9`; `RepoTecnico/estado_proyecto.md:5` |

---

## 6. Hallazgos detallados (ALTOS y MEDIOS)

### H-01 · ALTA — La sincronización existe solo en el árbol de trabajo

**Detalle.** `sync-contracts.sh` toma como fuente el **último** `rwa-sc/sc/deployments/*.json` (`ls | sort | tail -1`). Localmente hay dos artefactos, pero solo el antiguo está versionado; el nuevo (`31337-20261023T185622Z.json`) está **untracked**. En consecuencia, `deployments.ts` local apunta al nuevo mientras el **commiteado** apunta al antiguo. Un clon limpio, otra persona o la CI ven un proyecto "sincronizado" pero **desfasado** del despliegue canónico real.

**Impacto.** Rompe la propiedad "un solo proyecto reproducible": la sincronización depende de un working tree local. Si se commitea un lado sin el otro, se introduce deriva real.

**Recomendación.** Commitear en el **mismo turno**: (a) `rwa-sc/sc/deployments/31337-20261023T185622Z.json`; (b) `rwa-web/packages/shared/src/contracts/deployments.ts` + `.env.example` regenerados. Añadir un gate que verifique que el artefacto referenciado por `@web` existe y está **trackeado** en `@sc`.

### H-02 · ALTA — Divergencia de estado remoto entre las dos líneas

**Detalle.** `rwa-sc` está 2 commits por delante de su remoto (`f2258b6`, `0cbb0f7`) y `rwa-web` está 0/0 con el suyo. El job `validate:abi-drift` clona `RWA_SC_REPO_URL` (el **remoto**) y compara contra él: mientras `@sc` no se suba, la CI de `@web` valida contra un estado antiguo.

**Impacto.** El gate de sincronización mide una relación que ya no es la local; el resultado (verde/rojo) puede ser engañoso.

**Recomendación.** Subir `@sc` con orden explícita (`/push`) o, mejor, **fijar un SHA** de `rwa-sc` en la CI de `@web` y versionarlo como contrato de integración.

### H-03 · ALTA — Deriva documental del despliegue canónico

**Detalle.** `rwa-sc/RepoTecnico/estado_proyecto.md:112` y `entornos_globales.md:90,283` siguen citando `31337-20261010T162639Z.json` como "fuente de verdad versionada". `@web` ya consume `31337-20261023T185622Z.json` (`.env.example:10`, cabecera de `deployments.ts`).

**Impacto.** Un operador que siga la documentación de `@sc` desplegará/verificará contra direcciones equivocadas.

**Recomendación.** Actualizar los tres puntos a la nueva fuente y añadir el artefacto nuevo al control de versiones; añadir un gate documental (la ruta citada debe existir y coincidir con la que usa `@web`).

### H-04 · MEDIA — El espejo de datos no se protege en CI

**Detalle.** El gate `RepoTecnico/check_sincronizacion_datos.sh --check` (D-102) solo se ejecuta manualmente; `.gitlab-ci.yml` no lo invoca.

**Impacto.** Los 3 artefactos de datos pueden divergir sin que la CI lo detecte.

**Recomendación.** Añadir job `validate:data-sync` que ejecute el gate (es rápido y no necesita red).

### H-05 · MEDIA — Gate de deriva no reproducible (variable + HEAD móvil)

**Detalle.** `validate:abi-drift` falla explícitamente si `RWA_SC_REPO_URL` no está definida y clona `--depth 1` (HEAD de la rama por defecto), no un SHA fijo.

**Impacto.** Pipeline frágil (falla por configuración) e **inestable** (el resultado depende de cuándo se ejecute).

**Recomendación.** Definir la variable en el proyecto y fijar `RWA_SC_REF` (SHA/tag) versionado; documentar en el README de CI.

### H-06 · MEDIA — E2E fuera de CI

**Detalle.** Existen harnesses E2E reales (`e2e_claim_o5.mjs` con Playwright+viem; `test_e2e_o2.sh`), pero ningún job de CI los ejecuta; el gate de deriva solo compara **forma** (ABIs/direcciones), no **comportamiento** (eventos, firmas, flujo).

**Impacto.** Un cambio de contrato que rompa el flujo UI puede pasar todos los gates actuales.

**Recomendación.** Job E2E (nocturno o en MR) que despliegue `rwa-sc` en Anvil local y ejecute el harness; publicar evidencia como artefacto.

### H-07 · MEDIA — Claves privadas demo en UI y paquete compartido

**Detalle.** `apps/issuer/app/dashboard/page.tsx:282,289,311` muestra y copia `DEMO_ACCOUNTS[].privateKey`; `packages/shared/src/network/index.ts:72,77,82` las incluye. Son claves **públicas de Anvil** (no secretos reales), pero se bundelean y normalizan una mala práctica; contradicen la afirmación "0 secretos" y pueden enmascarar una fuga real.

**Recomendación.** Sacar claves de UI y de código de producción; limitar cuentas demo a `NODE_ENV !== 'production'`/flag local; dejar claves solo en fixtures de test; añadir gate de "0 claves privadas en `src`".

---

## 7. RNF de integración faltantes

| Categoría ISO 25010 | Qué falta |
|---|---|
| **Compatibilidad / interoperabilidad** | Política explícita de versionado ABI↔web y reglas de cambios *breaking*; pin de la versión de `rwa-sc` que consume `@web` (SHA/tag). |
| **Integridad** | Gate que garantice que el artefacto de despliegue referenciado está versionado y coincide con el generado (H-01). |
| **Mantenibilidad** | Fuente única de verdad formalizada para despliegues; gate documental que impida citar artefactos obsoletos (H-03). |
| **Observabilidad** | Monitoreo de deriva fuera de CI (p. ej. alerta si `rwa-sc` avanza y `@web` no regenera); panel de versión desplegada. |
| **Fiabilidad** | Verificación E2E continua (H-06). |
| **Seguridad** | Gate de "0 claves privadas" en fuentes y retirada de claves demo de la UI (H-07). |

---

## 8. Stakeholders / propiedad de la sincronización faltantes

| Stakeholder / rol | Situación |
|---|---|
| **Dueño de los artefactos de contrato** (ABIs, despliegues) | No está declarado quién es responsable de commitear y publicar un nuevo despliegue (H-01/H-02). |
| **Dueño de la regeneración en `@web`** | El flujo `sync-contracts.sh` existe, pero no hay política "quién y cuándo regenera" ligada al cierre de un ciclo de `@sc`. |
| **Release manager cross-línea** | No hay release/pin conjunto `rwa-sc@SHA ↔ rwa-web@SHA`. |
| **Responsable de documentación** | Sin gate que detecte citas obsoletas a despliegues (H-03). |
| **Seguridad/operación** | No hay revisión que impida publicar cuentas demo con claves en UI (H-07). |

---

## 9. Plan de acción

### Quick wins (S)

1. **Commitear el estado de sincronización real**: despliegue nuevo en `@sc` + `deployments.ts`/`.env.example` regenerados en `@web` (H-01).
2. **Actualizar los 3 puntos documentales** de `@sc` al despliegue `20261023` (H-03).
3. **Cablear `check_sincronizacion_datos.sh --check`** como job de CI (H-04).
4. **Sacar claves privadas demo de la UI** y de `packages/shared/src/network` (H-07).
5. **Preflight `jq`** en `sync-contracts.sh` (H-09).

### Mejoras (M)

6. **Fijar `RWA_SC_REF` (SHA)** y definir `RWA_SC_REPO_URL` en CI; documentar (H-05).
7. **Job E2E** contra Anvil local en CI/nocturno (H-06).
8. **Gate documental**: las rutas de despliegue citadas en `RepoTecnico` deben existir y coincidir con `@web` (H-03).
9. **Commitear los 58 cambios WIP de `@web`** y alinear versiones documentales (H-10).

### Roadmap (L)

10. **Contrato de integración versionado** `@sc`↔`@web`: versión, SHA pinneado, reglas de compatibilidad, checklist de release (H-08).
11. **Monitorización de deriva** con alerta (version desplegada vs versión de artefactos) y *release notes* conjuntas.
12. **Auditoría externa** (R-9) antes de producción, con foco en la integración y en los secretos.

---

## 10. Gates de sincronización recomendados y criterios de aceptación

| Gate | Comando | Criterio |
|---|---|---|
| Datos espejo | `rwa-web/RepoTecnico/check_sincronizacion_datos.sh --check` | exit 0 · 3/3 idénticos |
| Deriva ABI/direcciones | `rwa-web/scripts/check-contract-drift.sh` | exit 0 contra **SHA fijo** de `rwa-sc` |
| Literales de red | `rwa-web/scripts/check-network-literals.sh` | 0 literales |
| Despliegue versionado | nuevo | el artefacto referenciado por `@web` existe y está **trackeado** en `@sc` |
| Documentación | nuevo | rutas de despliegue citadas existen y coinciden con `@web` |
| E2E contrato↔interfaz | `e2e_claim_o5.mjs` | flujo identidad→claim→aprobación→`addClaim` en verde |
| Secretos | nuevo | 0 claves privadas en `src` de apps/packages |

**Criterios de aceptación para la siguiente versión (V2):** los 7 gates en verde **desde un clon limpio** de ambos repos, con `rwa-sc` en un SHA publicado y `rwa-web` sin cambios sin commitear que afecten a contratos/config.

---

## Anexo A — Comandos de verificación reproducibles

```bash
cd /home/dsh/workspace/RWA

# 1) Gate espejo de datos (D-102)
rwa-web/RepoTecnico/check_sincronizacion_datos.sh --check; echo "exit=$?"

# 2) Gate de deriva ABI/direcciones (RF-W-09)
cd rwa-web && ./scripts/check-contract-drift.sh; echo "exit=$?"

# 3) Gate de literales de red (RF-W-08)
./scripts/check-network-literals.sh; echo "exit=$?"

# 4) Estado de sincronización commiteado vs árbol
cd /home/dsh/workspace/RWA/rwa-sc && git status --short sc/deployments/
git ls-files sc/deployments/
cd ../rwa-web && git show HEAD:packages/shared/src/contracts/deployments.ts | grep -m1 artifact
grep -m1 artifact packages/shared/src/contracts/deployments.ts
git status --short packages/shared/src/contracts/deployments.ts

# 5) Divergencia remota entre líneas
cd ../rwa-sc && git rev-list --left-right --count origin/rwa-sc-DSH-GCP...HEAD
cd ../rwa-web && git rev-list --left-right --count origin/rwa-web-DSH...HEAD

# 6) ¿E2E y gate de datos en CI?
grep -nE "check_sincronizacion|e2e" .gitlab-ci.yml
```

## Anexo B — Evidencia clave del snapshot

- `rwa-sc` HEAD `0cbb0f7` «datos: esquema v1.1 con payload EIP-712 del claim (O2.3 @web)»; untracked `sc/deployments/31337-20261023T185622Z.json`.
- `rwa-web` HEAD `bd00aff` «E2E claim-flow: SIWE en cliente, fix decodeEventLog y harness local»; 58 cambios sin commitear; remotos `origin` (CodeCrypto) y `github`.
- Gates ejecutados por el Lead en el snapshot: datos `exit 0`, deriva `exit 0`, literales `exit 0`.
- `@web` genera 16 ABIs + `deployments.ts` desde `@sc` (`packages/shared/src/contracts/`, incluye `GovernanceMultisig`).

---

*Fin del informe — `INFORME_SINCRONIZACION_LINEAS_V1.md` · snapshot 2026-10-24T00:22:40Z.*
