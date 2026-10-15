# 📌 Estado del Proyecto — RWA (Mejora)

> **Proyecto:** Mejora y estabilización de la plataforma RWA (Real World Assets, inspirada en ERC-3643)
> **Directivo:** Asistente de Proyecto (`@asistenteProyecto`)
> **Versión:** v2.5 · 2026-10-14 — Fases 1–4 cerradas (Fase 5 omitida, D-087), **backlog post-Fase 4 cerrado** (QW-8 · AF-04/AF-12/AF-14 · H-06/H-07/H-09/H-13/H-14/H-19/H-20/H-29/H-32 · RNF-107) y **etapa `@web` abierta** (D-088…D-102, ciclo O0 en curso)

## Fases

| Fase | Nombre | Estado | Criterios |
|---|---|---|---|
| 1 | Concepción | ✅ COMPLETADO | Artefactos creados, repos y GCP definidos, entrevista de 3 bloques |
| 2 | Auditoría | ✅ COMPLETADO (por confirmar) | Auditoría sin issues críticos + CU auditados + gráficos + documento técnico auditado |
| 3 | Desarrollo | ✅ COMPLETADO — Ciclos 1, 1b, 2, 3, 4, 5, 6, 7, 8, 8b, 8c, 9, 10 y **11** ✅ | Plan vertical aprobado, ciclos completados y probados |
| 4 | Pruebas | ✅ COMPLETADO (cierre definitivo) — **394/394 tests en verde** (23 suites, 19 funciones `invariant_*`), cobertura `src/` **97,05 % líneas** (691/712; mínimo por contrato 91,53 %), matriz **v2** de **142 criterios** con **0 FALTA**; auditoría adversarial final **AF-01..AF-15** cerrada (AF-01/AF-02/AF-03/AF-05/AF-06/AF-07/AF-08/AF-09/AF-10/AF-11/AF-13/AF-15 corregidos; **AF-03 y AF-05 por decisión del usuario**, D-083/D-084; AF-04/AF-12/AF-14 diferidos); pipeline 7/7 en verde (`2934202154`, `2934241152`) | 100 % de tests en verde (Forge) + cobertura ≥ 80 % |
| 5 | Manuales | ⛔ **OMITIDA** por decisión del usuario (D-087) | No aplica: el usuario decidió no generar manuales |

## Hitos de la Fase 2 (completados)

- [x] Auditoría del proyecto en 3 fases y 7 lentes: **34 hallazgos** (1 crítica, 11 altas, 18 medias, 4 bajas), 12 falsos positivos descartados y veredicto explícito.
- [x] **PoC propios del Lead** que reproducen los dos fallos de mayor impacto (H-01 claims forjados, H-05 `isVerified` fail-open): ambos PASS, guardados en `evidencias/`.
- [x] Métricas reales medidas: 151 tests declarados, 93 pasan, 5 fallan, **53 nunca arrancan**, cobertura **42,86 %**, 52 avisos de lint.
- [x] Requisitos v1.1: **RF-001..RF-013** + RNF-001..RNF-006 + RT-001..RT-008 y backlog priorizado con los 34 hallazgos.
- [x] Casos de uso v1.3: **17 CU**, 92 Gherkin + 50 EARS = **142 criterios** testeables, auditados y corregidos.
- [x] Diagramas: 1 UML de casos de uso + 6 de secuencia + matriz actores↔CU.
- [x] Artefactos de datos sincronizados (diccionario v1.1, E-R v1.1, SQL v0.2) contra el código real.
- [x] Documento técnico v1.1 (as-is, to-be, datos, trazas, entornos, CI, riesgos y criterios V2) + su auditoría (13 hallazgos DT-01..DT-13).

## Hitos de la Fase 3 (completados)

- [x] **Ciclo 1 — RF-005 · Build reproducible y suites en verde** (commit local `d959145`, sin push):
  `solc 0.8.20` + optimizer 200 + `evm_version = "paris"`; submódulos pinneados y un único `.gitmodules`;
  las 2 suites muertas adaptadas a **factory + clon + `initialize`**; 3 tests de gas reescritos con línea base
  equivalente; `.gas-snapshot` versionado. Resultado verificado por el Lead: **151/151 tests pasan, 0 fallan**,
  `forge fmt --check` limpio, cobertura `src/` **86,33 %** (total 67,50 %, que incluye `script/` y benchmarks).
- [x] **Ciclo 2 — RF-001 · Verificación criptográfica del claim con EIP-712** (commit local, sin push):
  `IdentityCloneable.addClaim` exige firma **EIP-712** del `issuer` (dominio `RWA-Identity`/`1`/`chainId`/clon
  y `CLAIM_TYPEHASH` con `expiresAt`, D-020), con `scheme == 1`, longitud 65, `issuer != 0`,
  `recovered == issuer` y `walletOwner == owner()`; sobrescritura solo con firma válida (D-018) y
  autorización de topic delegada al token (D-025). `createIdentityWithClaim` propaga `expiresAt`.
  **264/264 tests** (21 nuevos `test_RF001_*`), `src/` 96,08 % de líneas y `IdentityCloneable` 100 %;
  PoC H-01 **invertido** (firma vacía → revert). Cierra **H-01** y el bloqueante **B-1**.
- [x] **Ciclo 3 — RF-002 · Retirada del flag de bypass y anti-reentrancia** (commit local `45496cf`):
  `bypassCompliance` **eliminado** del storage (sustituido por la ruta interna `_forcedUpdate`); `nonReentrant`
  en los 5 puntos de entrada (`transfer`, `transferFrom`, `mint`, `burn`, `forcedTransfer`) y en las entradas
  con estado del `ComplianceAggregator`; gate `check_no_bypass_flag.sh`; `forcedTransfer` rechaza `from == 0`
  (cerraba una vía de acuñación). **281/281 tests** (17 nuevos, 7 de reentrancia que revierten con
  `ReentrancyGuardReentrantCall`), `src/` 96,28 % líneas / 82,90 % ramas, +3.074 gas por transferencia y
  **0** en `createToken`. Decisiones **D-029..D-032**.
- [x] **Documentación versionada:** `RepoTecnico/` se movió dentro del repo (`rwa-sc/RepoTecnico/`, commit
  `fb38e4f`), por lo que los ciclos siguientes versionan código **y** documentación. Decisión del usuario.
- [x] **Ciclo 11 (RF-009):** pipeline `.gitlab-ci.yml` con build, `fmt`, test, coverage y los gates de RF-006.
  **(Ciclo 11 completado — ver más abajo.)**

- [x] **Ciclo 1b — RF-005 · Cobertura ≥ 80 % por contrato en los registries** (commit local `a92cf1d`):
  3 suites nuevas (92 tests: IdentityRegistry 34, TrustedIssuersRegistry 33, ClaimTopicsRegistry 25);
  los tres contratos pasan de 37/38/45 % a **100 %** de líneas, sentencias, ramas y funciones; agregado `src/`
  **96,00 %** de líneas y 81,77 % de ramas; **243/243 tests en verde**; `src/` intacto (solo tests y snapshot).
  El ciclo descubrió **HB-13..HB-16** (registrados en `requerimientos.md` §2 y agrupados por afinidad en los
  Ciclos 4 y 8 salvo HB-16, que va con H-20 al backlog).
- [x] **Ciclo 4 — RF-003 · Validación ERC-165 de módulos (+ HB-13 y HB-15)** (commit local `49bc7d1`):
  `ICompliance is IERC165` con `supportsInterface` en los 3 módulos y en el aggregator; validación por
  `staticcall` al dar de alta (rechaza EOA, contrato sin interfaz y ERC-165 ajeno) y rechazo de duplicados;
  `IdentityRegistry` exige que la identidad sea contrato (HB-13) y `addClaimTopic` rechaza el topic `0` (HB-15).
  **303/303 tests** (+22), `src/` 96,44 % líneas / 84,62 % ramas, ABI aditiva.
- [x] **Ciclo 5 — RF-004 · Whitelist de destinos, límites y tope de suministro** (implementado y verificado):
  `authorizedDestinations` (fail-closed), `maxBurnPerTx` y `maxForcedPerTx` (**0 = operación desactivada**,
  CU-06), `maxSupply` (0 = sin tope, D-022) con setters por admin/compliance y eventos; `mint` respeta el tope.
  Suite nueva `TokenLimits.t.sol` (17 tests) y adaptación de `Token.t.sol`/`TokenReentrancy.t.sol`.
  **320/320 tests**, `src/` 96,43 % líneas (todos los contratos ≥ 91 %, `TokenCloneable` 97,71 %).
  Hallazgo del ciclo: el gate de gas fallaba por el fuzz no determinista → se fijó `[fuzz] seed` en
  `foundry.toml` y `forge snapshot --check --tolerance 5` pasa de forma estable (D-039 viable).
- [x] **Ciclo 6 — RF-011 · `isVerified` fail-closed** (implementado): devuelve `false` si
  `claimTopicsRegistry == address(0)` o si el conjunto de topics requeridos está vacío (antes `true`;
  fail-open H-05 de la auditoría V1). Un token recién creado por factory no verifica a nadie y
  `mint`/`transfer` quedan bloqueados hasta configurar la política, que vuelve a habilitarlos.
  Suite nueva `RF011_FailClosed.t.sol` (6 tests, CU-15); **326/326 tests**; `TokenCloneable` 99,44 % de
  líneas. La evidencia `evidencias/PoC_H01_H05.t.sol` invierte también el PoC de H-05
  (`test_H05_isVerified_fail_closed_ok`): **H-01 y H-05 quedan verificados como corregidos**.
- [x] **Ciclo 7 — RF-012 · `ComplianceAggregator` fail-closed y gestión solo por el token** (commit local
  `f3183f8`): `addModule`/`removeModule` pasan a `onlyToken` (**el owner global ya no administra tokens
  ajenos**: `"Only token admin can call"`) y `canTransfer` deniega si el token no está registrado o no tiene
  módulos (antes permitía todo: fail-open H-22). Registro automático del token al primer módulo (`TokenRegistered`).
  Suite nueva `RF012_AggregatorFailClosed.t.sol` (8 tests, CU-16) y **31 de 35** puntos de llamada de las 3
  suites afectadas reencaminados a la ruta de producción `token → aggregator` (los 4 restantes son negativos de
  autorización); `test_NoModules_AllowsAll` invertido a `test_NoModules_FailClosed`.
  **334/334 tests**, `src/` 97,18 % líneas / 85,53 % ramas. Decisiones **D-043/D-044**.
- [x] **Ciclo 8 — RF-013 · vigencia y revocación de claims por el issuer (+ HB-14)** (commit local
  `RF-013`): struct `Claim` con `bool revoked` (append-only) y vista `hasValidClaim` que aplica D-038
  (`expiresAt == 0` = sin caducidad); `revokeClaim` solo por el propio issuer (conserva histórico y emite
  `ClaimRevoked`); `addClaim` renovado reactiva `revoked = false` (D-020/D-018); `isVerified` exige claim
  vigente y no revocado (fail-closed); HB-14 verifica pertenencia en `registeredAddresses` y revierte
  `"Wallet not in registered addresses"`. Suite nueva `RF013_ClaimLifecycle.t.sol` (11 tests, CU-17) y
  **3 tests HB-14** en `IdentityRegistry.t.sol`. **348/348 tests**, `src/` 97,11 % líneas / 86,13 % ramas.
  Decisiones **D-045..D-049**; cambio de ABI en `getClaim` (+`revoked`) documentado en `CHANGELOG_ABIS.md`.
- [x] **Ciclo 8c — RF-013 · nonce firmado anti-replay en la revocación de claims** (commit local `RF-013-8c`):
  cierra el bypass detectado en D-046. `CLAIM_TYPEHASH` gana `uint256 nonce`; el nuevo mapping público
  `claimNonce[topic][issuer]` (fuera del struct `Claim`: `getClaim` sigue con 8 salidas) entra en el digest
  firmado; `revokeClaim` lo incrementa (y **solo** entonces), de modo que la firma original deja de
  verificar y no puede reactivar el claim por replay; el alta/renovación **no** lo incrementa y preserva
  D-018 (sobrescritura idempotente con firma válida). 5 tests nuevos en `RF013_ClaimLifecycle.t.sol`
  (replay, incremento, reactivación con nonce nuevo, idempotencia y digest) y adaptación de los existentes
  de firma tras revocación sin borrar ni debilitar ninguno. **353/353 tests**, `src/` 97,11 % líneas /
  86,13 % ramas, `IdentityCloneable` 100 % líneas. Decisiones **D-050..D-052**; cambio crítico de firma
  off-chain documentado en `CHANGELOG_ABIS.md` (impacto en `rwa-web`).
- [x] **Ciclo 9 — RF-010 · secretos fuera de los scripts y despliegue verificable** (commit local, sin push):
  `sc/script/deploy.sh` lee `RPC_URL`/`CHAIN_ID` y la clave **solo de variables de entorno** (o Secret Manager
  con `USE_SECRET_MANAGER=1`), valida la red con `cast chain-id` **antes** del broadcast y firma con un
  **keystore cifrado efímero** (`--keystore`+`--password-file`, modo 600, borrado al terminar) creado con
  `eth_keyfile` sin pasar la clave por `argv`. Script canónico `sc/script/DeployFullStack.s.sol`: despliega
  registries + 3 factories + aggregator + token de ejemplo (con su claim topics registry) + un módulo de
  compliance dado de alta **por la ruta del token** + una identidad registrada; persiste el artefacto
  `sc/deployments/31337-20261010T162639Z.json` (`chainId`, bloque, direcciones, ABIs y `deployer`), versionado
  y sin secretos. Verificación post-deploy on-chain con `cast code` (10/10) y `cast call` (`name()`, registries,
  `getModuleCount` = 1), **no** con `grep`. Despliegue real contra el **Anvil de GCP** (chain-id 31337, bloque
  517) verificado; Besu queda como alternativa vía el wrapper `deploy-besu.sh`. **353/353 tests sin regresión**.
  Cierra **HB-12, H-24, H-28, H-31** y el criterio **C-9**. Decisiones **D-054..D-057**.

### Corrección de cifras tras el Ciclo 10

| Afirmación previa | Medición real |
|---|---|
| "139 tests, 100 % passing" | **353 tests, 353 pasan** (18 suites; `forge test` → `353 passed, 0 failed, 0 skipped`); antes: 98 contados, 93 pasan, 5 fallan, 53 muertos |
| "Ahorro de gas 88–98 %" | **45–59 %** medido con comparación equivalente (Token 55 %, Identity 59 %, Identity+claim 45 %, Registry 53 %) |
| "Cobertura > 80 %" | `src/` **97,11 % líneas / 86,13 % ramas** (D-017, sin interfaces ni `test/`) |
| "production-ready" / "ERC-3643 compliant" | **Retiradas**: sustituidas por una declaración verificable en [`../SECURITY.md`](../SECURITY.md); sin auditoría externa y **no aptas para producción con activos reales** (D-024) |

- [x] **Ciclo 10 — RF-006 · Documentación veraz, `SECURITY.md` y control de deriva de ABIs** (commit local, sin push):
  se eliminan las referencias a `Token.sol`/`Identity.sol` y a los 3 `.md` inexistentes en los 10 documentos raíz;
  las cifras manuales se sustituyen por las medidas y enlazadas a su artefacto; se crea **`SECURITY.md`**
  (modelo de amenazas, estado de los 34 hallazgos de la auditoría V1, controles con test y riesgos residuales)
  y la línea base **`sc/abis/<Contrato>.json`** (15 ABIs) con `sc/script/ci/abi_diff.sh` y
  `sc/script/ci/check_docs.sh`; la rúbrica de `EJERCICIOS_PRACTICOS.md` pasa a criterios observables (H-23).
  **353/353 tests sin regresión**, `forge fmt --check` limpio, ambos gates en verde. Cierra **HB-07, H-15, H-16,
  H-23 y H-33** y los criterios **B-8** y **C-10** (parcial: quedan H-13/H-14/H-34 en backlog). Decisiones
  **D-058..D-061**.

- [x] **Ciclo 11 — RF-009 · Pipeline de CI de GitLab con gates** (commit local, sin push):
  `.gitlab-ci.yml` en la raíz con 7 etapas (`validate`, `build`, `fmt`, `test`, `coverage`, `gas`, `ci-checks`),
  imagen `ghcr.io/foundry-rs/foundry:v1.8.3` **fijada** y `rules` en *merge requests* y en `rwa-sc-DSH-GCP`;
  umbral de cobertura centralizado (`COVERAGE_THRESHOLD` / `COVERAGE_CONTRACT_THRESHOLD`) con el gate
  `sc/script/ci/check_coverage.sh` (**RNF-002/D-017/D-042**: agregado de `src/` **y** mínimo por contrato) y
  `sc/script/ci/run_local_ci.sh` como ensayo local del pipeline. El job `test` publica el **conteo real** como
  artefacto y `coverage` publica `lcov.info`. **353/353 tests sin regresión**, `forge fmt --check` limpio,
  agregado `src/` **97,12 %** (mínimo por contrato 91,53 %), `forge snapshot --check --tolerance 5` OK y los 3
  gates de CI (RF-002/RF-006) en verde. **No ha corrido en remoto: no hay `push`.** Cierra **B-3**, **B-5** y
  **HB-10**. Decisiones **D-062..D-065**.

> **Cierre de la Fase 3.** Con el Ciclo 11 quedan completados **todos** los ciclos de la Fase 3:
> **1, 1b, 2, 3, 4, 5, 6, 7, 8, 8b, 8c, 9, 10 y 11** (RF-005, RF-001..RF-004, RF-011, RF-012, RF-013, RF-010,
> RF-006 y RF-009). Los criterios bloqueantes **B-1..B-8** quedan cubiertos y los de calidad aplicables,
> cerrados. Lo único que resta es **operativo**: `push` de `rwa-sc-DSH-GCP` y un **runner** de GitLab para
> ejecutar el pipeline en remoto (Fase 4).

## Hitos de la Fase 4 (completados)

- [x] **Invariantes con estado (RF-009):** 4 suites en `sc/test/invariant/` (19 `invariant_*`) con
  `runs = 64`/`depth = 64`; cero violaciones. Detalle en `pruebas/pruebas_invariantes.md` y
  `metricas_ejecucion.md` §21. Decisiones **D-066..D-069**.
- [x] **Matriz de trazabilidad criterio→prueba:** `pruebas/matriz_criterios.md` cruza los **142 criterios**
  de `casos_uso.md` v1.3 con las suites y gates reales; veredicto 111 CUBIERTO / 22 PARCIAL / 9 FALTA.
- [x] **Cierre de los 7 huecos de criterios y del cambio de código:** 7 pruebas nuevas
  (`test_RF001_registries_owner_tras_renuncia`, `test_RF002_transfer_from_sin_allowance_revierte`,
  `test_RNF005_cambio_topics_afecta_isVerified`, `test_RNF005_set_claim_topics_registry_cero_revierte`,
  `test_RF012_retirar_ultimo_modulo_bloquea`, `test_RF005_initialization_implementacion_bloqueada`,
  `test_RF005_no_storage_muerto_tokenName`) y eliminación del storage muerto `_tokenName`/`_tokenSymbol`
  de `TokenCloneable` (RF-005, se conserva `_tokenDecimals`). `forge test` → **368/368**. Decisiones
  **D-070 y D-073**.
- [x] **Gates nuevos de CI:** `sc/script/ci/check_secrets.sh` (RF-010,
  `ci_check_RF010_secret_scan_sin_hallazgos`) integrado en el job `ci-checks` y en `run_local_ci.sh`;
  `check_docs.sh` amplía `ci_check_RF006_mitigacion_con_test` (todo `test_*`/`ci_check_*` citado en
  `SECURITY.md` debe existir). Decisiones **D-071 y D-072**.
- [x] **Alineación documental (`casos_uso.md` v1.4):** 0 rótulos pendientes en los RF materializados,
  0 nombres de test obsoletos y los dos criterios derogados (fail-open) reescritos a fail-closed.
  Cobertura `src/` **97,11 %** (672/692) y mínimo **91,53 %**. Decisión **D-074**.
- [x] **Auditoría adversarial final (AF-01..AF-15) y cierre:** se corrigen **AF-01** (vinculación del módulo
  al token + lectura defensiva en los 3 módulos), **AF-02** (`mint`/`burn` `whenNotPaused`, `mint` rechaza
  cuentas congeladas, `forcedTransfer` operativo en pausa), **AF-06** (matriz v2 con **0 FALTA**),
  **AF-07** (`DeployFullStack` operable + smoke test en `deploy.sh`), **AF-08/AF-09** (scripts de ejemplo y
  aggregator), **AF-10** (`RUNBOOK_MIGRACION.md`), **AF-11/AF-15** (deriva documental y `CLAIM_TYPEHASH` de
  D-020) y **AF-13** (simetría de `removeModuleThroughAggregator`). **Cierre definitivo:** se incorporan por
  decisión del usuario **AF-03** (el digest EIP-712 cubre el `uri` via `uriHash`) y **AF-05** (token
  fail-closed sin módulos), D-083/D-084; quedan diferidos AF-04/AF-12/AF-14. `forge test` → **394/394**
  (23 suites, 19 invariantes). Decisiones **D-075..D-085**. Suite `test/AuditoriaFinalAF.t.sol` (23 pruebas).
  Pipeline en verde: `2934202154` y `2934241152`.
- [x] **Documentación de operación:** `RUNBOOK_MIGRACION.md` (redeploy limpio D-019/RT-008) creado.

## Acuerdos y decisiones

| ID | Decisión |
|---|---|
| D-001 | `rwa-sc` es la base de este ciclo; los cambios de contrato impactan a las apps web |
| D-002 | La base de datos del proyecto es **MongoDB**; `base_datos.sql` es borrador de una eventual migración |
| D-003 | Alcance = **solo `rwa-sc`**; `rwa-web` fuera de este ciclo |
| D-004 | Prioridad = **seguridad + estabilidad del build** |
| D-005 | Rama de trabajo = **`rwa-sc-DSH-GCP`** (GitLab.com) |
| D-006 | `AGENT_ROLE`: **whitelist de destinos + límites** |
| D-007 | Claims: **firma EIP-712 tipada** verificada con `ecrecover` |
| D-008 | Cadena destino = **Besu CodeCrypto** + **GitLab CI** |
| D-009 | **Redeploy limpio** permitido (se puede mover el layout de storage) |
| D-010 | Pruebas: 100 % de lo existente + nuevas + fuzz + cobertura ≥ 80 % |
| D-011 | Docs + **SECURITY.md** + **CHANGELOG de ABIs** |
| D-012 | *(cerrada por D-016)* política de compliance en `mint()` |
| D-013 | *(cerrada por D-018)* política de reintento de claim |
| D-014 | Alcance ampliado a los 3 fallos abiertos de seguridad (RF-011, RF-012, RF-013) |
| D-015 | Los tests se adaptan al patrón **factory + clon + `initialize`** |
| D-016 | Se **mantiene** el chequeo de compliance en `mint()` |
| D-017 | Cobertura ≥ 80 % medida sobre `src/` sin interfaces ni `test/` |
| D-018 | Reintento de claim: **sobrescritura con firma válida** (renovación) |
| D-019 | Ciclo de vida: **redeploy limpio con EIP-1167** + runbook de migración |
| D-020 | EIP-712: dominio `RWA-Identity`/`1`/`chainId`/clon y `CLAIM_TYPEHASH` **con `expiresAt` firmado** |
| D-021 | Gobernanza: **roles separados + multisig 2-de-3 + timelock + custodio de claves** |
| D-022 | **Tope de suministro** (`maxSupply`) administrable con evento |
| D-023 | `ComplianceAggregator` **fail-closed** con registro automático del token al primer módulo |
| D-024 | **Auditoría externa** bloqueante solo para producción con activos reales |
| D-025 | RF-001: la autorización del issuer **para el topic** la impone el token (`isVerified`), no `addClaim` |
| D-026 | EIP-712 reproducido a mano (mismo digest) por el pragma `^0.8.24` de `EIP712Upgradeable` vs `solc 0.8.20`; `ECDSA` sí es de OpenZeppelin |
| D-027 | `createIdentityWithClaim`: el `walletOwner` firmado es la factory (owner temporal); anti-replay por `verifyingContract` |
| D-028 | Los criterios de autorización de topic de CU-02/CU-03 se reubican en la capa token (coherente con D-025) |
| D-058 | **Documentación veraz (RF-006)**: toda cifra publicada se sustituye por la medida y enlaza a su artefacto; se prohíben las referencias a archivos inexistentes y las afirmaciones "production-ready"/"ERC-3643 compliant" sin declaración verificable |
| D-059 | **`SECURITY.md` como documento vivo**: refleja el estado de los 34 hallazgos V1 (corregido/ciclo o backlog) y los riesgos residuales; cada mitigación cita al menos un `test_*` o un `ci_check_*` |
| D-060 | **Control de deriva de ABIs**: la línea base vive en `sc/abis/<Contrato>.json`; `sc/script/ci/abi_diff.sh` falla ante cualquier deriva no declarada en `CHANGELOG_ABIS.md`, que debe actualizarse junto con la línea base |
| D-061 | **Gate de documentación**: `sc/script/ci/check_docs.sh` falla ante referencias rotas, falta de `SECURITY.md`/`CHANGELOG_ABIS.md`, afirmaciones prohibidas sin matizar, HB-01..HB-12 sin cubrir o placeholders (`RepoTecnico/` queda fuera del escaneo por ser registro de auditoría) |
| D-062 | **Pipeline de CI (RF-009)**: `.gitlab-ci.yml` en la raíz con 7 etapas (`validate`, `build`, `fmt`, `test`, `coverage`, `gas`, `ci-checks`), imagen fijada `ghcr.io/foundry-rs/foundry:v1.8.3`, `rules` en MR y `rwa-sc-DSH-GCP`, sin secretos; **ejecutado en remoto en verde** (pipelines `2934202154` y `2934241152`, 7/7 jobs) |
| D-063 | **Gate de cobertura por contrato (D-042)**: `check_coverage.sh` exige el **agregado de líneas de `src/` ≥ umbral** (D-017, sin interfaces) **y el mínimo por contrato de líneas ≥ umbral**; las ramas se reportan pero no bloquean (hay contratos por debajo del 80 % de ramas por diseño). Umbral en una única variable `COVERAGE_THRESHOLD` (+ `COVERAGE_CONTRACT_THRESHOLD`) |
| D-064 | **Conteo real como artefacto**: el job `test` publica `sc/ci-artifacts/test-count.txt` generado con `forge test --list \| grep -cE '^    test'` más el resumen de la ejecución; **prohibido escribir el número a mano** en el pipeline o en los documentos |
| D-065 | **`jq` en el runner**: la imagen oficial de Foundry es Ubuntu **no-root** y no incluye `jq` (que `abi_diff.sh` exige); el job `ci-checks` lo instala si el runner permite root o si el ejecutor es **shell**, y si no hay que usar una imagen propia `FROM ghcr.io/foundry-rs/foundry:v1.8.3` con `jq` |
| D-070 | **RF-005 · storage muerto:** se eliminan `_tokenName`/`_tokenSymbol` de `TokenCloneable` (`name()`/`symbol()` vienen de `ERC20Upgradeable`); se conserva `_tokenDecimals`, que sí usa `decimals()`. Test de storage-layout (`test_RF005_no_storage_muerto_tokenName`) sobre el artefacto compilado |
| D-071 | **Gate de secretos (RF-010):** `sc/script/ci/check_secrets.sh` falla ante claves de 64 hex en scripts/config, asignaciones de secreto con valor de 64 hex, tokens `glpat-`/`ghp_`/`AKIA`, uso de `keys.json` o `--private-key` en scripts, y exige `.env`/`.env.*` en `.gitignore`; se integra en `ci-checks` y en `run_local_ci.sh` |
| D-072 | **Mitigación con test (RF-006):** `check_docs.sh` exige que cada `test_*` citado en `SECURITY.md` exista en `sc/test/**` y cada `ci_check_*` exista como gate en `sc/script/ci/**` (o `.gitlab-ci.yml`); los prefijos terminados en `_` se aceptan si existe al menos un miembro de la familia |
| D-073 | **Cierre de huecos (Fase 4):** se añaden las 7 pruebas que cierran los FALTA de la matriz y se regeneran `.gas-snapshot`; la ABI no cambia (el storage no es ABI) y `sc/abis/` no requiere actualización |
| D-074 | **Alineación documental:** `casos_uso.md` v1.4 sustituye los rótulos «pendiente» por «IMPLEMENTADO (Ciclo N)», reemplaza los 67 nombres de test obsoletos por los reales de la matriz y reescribe los 2 criterios derogados (fail-open) a fail-closed |
| D-075 | **AF-01 (ALTA):** `addComplianceModule` y `aggregator.addModule` exigen que un módulo de un solo token esté vinculado al token (`tokenContract() == token`); el aggregator (sin `tokenContract()`) queda exento; los 3 módulos usan lectura defensiva (`success && data.length >= 32`) y degradan a `false`/sin cambios en vez de revertir |
| D-076 | **AF-02:** `mint`/`burn` son `whenNotPaused`; `mint` rechaza destinos congelados; `forcedTransfer` sigue operativo en pausa como recuperación de emergencia (destino whitelisted y verificado) |
| D-077 | **AF-13:** `removeModuleThroughAggregator` exige aggregator registrado y módulo activo para este token antes de delegar (simetría con el alta) |
| D-078 | **AF-07:** `DeployFullStack` configura `maxBurnPerTx`/`maxForcedPerTx`/destino autorizado; `deploy.sh` ejecuta un smoke test de operatividad con `cast call` y falla si el token no es operable |
| D-079 | **AF-08/AF-09:** `CompleteDeploymentExample.s.sol` firma claims EIP-712 reales con `vm.sign` (no revierte al simular); `DeployComplianceAggregator.s.sol` corrige los "Next Steps" a la API real (sin `configureToken()`) |
| D-080 | **AF-10:** se crea `rwa-sc/RUNBOOK_MIGRACION.md` (redeploy limpio D-019/RT-008: orden, configuración obligatoria, verificación con `cast`, consumidores y rollback) |
| D-081 | **AF-06/AF-11/AF-15:** matriz `matriz_criterios.md` v2 (386 tests, 23 suites, 19 invariantes, 0 FALTA); `SECURITY.md`/`.gitlab-ci.yml`/`README.md`/`entornos_globales.md`/`run_local_ci.sh` alineados con la CI en verde; `CLAIM_TYPEHASH` de D-020 con `nonce` y línea de D-016 corregida |
| D-083 | **AF-03 (decisión del usuario):** el `CLAIM_TYPEHASH` gana `bytes32 uriHash` (= `keccak256(bytes(uri))`); el issuer firma la referencia documental y el titular no puede alterarla. Breaking off-chain crítico (documentado en `CHANGELOG_ABIS.md`); sin cambio de ABI (`sc/abis/` no se regenera). `SigUtils` gana `uri` y conserva overloads con `""` |
| D-084 | **AF-05 (decisión del usuario):** `TokenCloneable.canTransfer` devuelve `false` con `complianceModules.length == 0`; `transfer`/`transferFrom` revierten `"Transfer not compliant"`. `mint`/`burn`/`forcedTransfer` no dependen del array. Sin cambio de ABI; `deploy.sh` verifica `complianceModules(0)` |
| D-085 | **Cierre definitivo Fase 4:** se adaptan las suites que emitían URIs no firmados (`IdentityCloneable`, `IdentityCloneFactory`, `RF013_ClaimLifecycle`) sin debilitar tests; **394/394**, 23 suites, 19 invariantes; 5 gates + `run_local_ci.sh` en verde; `.gas-snapshot` regenerado |
| D-082 | **Diferidos (D-024):** AF-03 (`_uri` en el digest), AF-04 (D-027/front-running de `createIdentityWithClaim`), AF-05 (fail-closed del array de módulos del token), AF-12 (`removeClaim`/nonce) y AF-14 (`.md` en el gate de secretos) quedan fuera de este cierre por impacto en consumidores off-chain o rediseño pendiente; se reevalúan antes de producción |

## Plan de la Fase 3 (orden aprobado)

```
RF-005 (build reproducible: submódulos, solc/optimizer fijados, 0 tests en rojo)
  → RF-001 (EIP-712 con D-020)   → RF-002 (reentrancia, retirada del flag bypass)
  → RF-003 (ERC-165 en módulos)  → RF-004 (whitelist + límites + maxSupply)
  → RF-011 (isVerified fail-closed) → RF-012 (aggregator fail-closed, D-023)
  → RF-013 (vigencia y revocación de claim)
  → RF-010 (secretos fuera de scripts) → RF-006 (docs + SECURITY.md + changelog ABIs) → RF-009 (CI)
```

Criterios de salida de la V2: **B-1..B-8** (bloqueantes) y **C-1..C-11** (calidad), definidos en
`INFORME_OPTIMIZACION_V1.md` §9 y enlazados a los RF en `documento_tecnico.md`.

## Artefactos de `RepoTecnico/`

| Archivo | Versión | Contenido |
|---|---|---|
| `requerimientos.md` | v1.1 | RF-001..RF-013, RNF, RT, HB-01..HB-12, entrevista (5 bloques), backlog |
| `INFORME_OPTIMIZACION_V1.md` | V1 | Auditoría de 34 hallazgos + plan + criterios V2 |
| `casos_uso/casos_uso.md` | v1.4 | 17 CU y 142 criterios Gherkin/EARS, alineados con la matriz (rótulos y nombres reales) |
| `pruebas/matriz_criterios.md` | v1.0 | Matriz de los 142 criterios → prueba/gate, con FALTA/PARCIAL y plan de cierre |
| `pruebas/pruebas_invariantes.md` | v1.0 | Invariantes con estado de la Fase 4 |
| `casos_uso/AUDITORIA_CASOS_USO.md` | — | 17 hallazgos de la auditoría de CU |
| `casos_uso/diagramas_casos_uso.md` | v1.1 | 7 diagramas Mermaid |
| `documento_tecnico.md` | v1.1 | Arquitectura, datos, trazas, entornos, riesgos |
| `AUDITORIA_DOCUMENTO_TECNICO.md` | — | 13 hallazgos DT-01..DT-13 |
| `metricas_ejecucion.md` · `entornos_globales.md` | — | Métricas y entorno reales |
| `evidencias/` | — | PoC H-01/H-05, salida y lint (52 avisos) |
| `rwa-web/RepoTecnico/INFORME_OPTIMIZACION_WEB_V1.md` | V1 | Auditoría del frontend: 16 hallazgos + plan + criterios V2 web (etapa `@web`) |
| `rwa-web/RepoTecnico/requerimientos_web.md` | v1.2 | RF-W-01..18, RNF-W-01..08, RT-W-01..10, modelo PostgreSQL y trazabilidad HW→req (etapa `@web`) |
| `rwa-web/RepoTecnico/plan_desarrollo_web.md` | v1.2 | Plan vertical de la etapa: ciclos O0..O5 con tareas, gates y DoD |
| `rwa-web/RepoTecnico/pruebas/verificacion_gcp_o0.md` | — | **Acta de verificación de los servicios GCP** (Anvil de GCP + Cloud SQL) del ciclo O0 |
| `rwa-web/RepoTecnico/ARTEFACTOS_DATOS_SINCRONIZADOS.md` · `check_sincronizacion_datos.sh` | — | Regla y gate de sincronización canónico↔espejo de los tres artefactos de datos |
| `base_datos.sql` | **v1.0** | **DDL real PostgreSQL** del esquema `rwa` (10 tablas + 1 vista + catálogo + Anexo A con la transcripción MongoDB). **Duplicado** como espejo en `rwa-web/RepoTecnico/` |
| `diccionario_datos.md` · `diagrama_er.md` | **v1.2 · v1.2** | Modelo de datos: on-chain + off-chain **PostgreSQL** (Q6 resuelta, D-095). **Duplicados** como espejo en `rwa-web/RepoTecnico/` |

## Brechas abiertas (declaradas)

1. **Pipeline en remoto**: RESUELTA — los pipelines `2934202154` y `2934241152` (rama `rwa-sc-DSH-GCP`) terminaron en verde con 7/7 jobs; `run_local_ci.sh` (con el gate nuevo `check_secrets.sh`) sigue siendo el ensayo local (RF-009).
2. **Sin auditoría externa**: bloqueante para producción con activos reales (D-024; `SECURITY.md` §5).
3. **Gobernanza en una sola EOA** hasta el multisig/timelock (H-06; D-021, backlog R-7).
4. **PII/KYC off-chain sin política formal** de base legal, cifrado y retención (H-11, backlog R-3).
5. **`check_secrets.sh` es estático**: no ejecuta `deploy.sh` ni escanea el histórico de git; cubre el árbol versionado actual (RF-010). La verificación dinámica del despliegue (aborto sin clave, limpieza del keystore) queda como deuda declarada.
6. **Pipeline en remoto (histórico)**: los pipelines `2934202154` y `2934241152` (rama `rwa-sc-DSH-GCP`) terminaron en verde con 7/7 jobs; la brecha original ("sin CI ejecutada") quedó cerrada.

## Pipeline en GitLab (cerrado)

- **Pipeline 2934202154 en `rwa-sc-DSH-GCP`: verde, 7/7 jobs** (`validate`, `build`, `fmt`, `test`, `coverage`,
  `gas`, `ci-checks`). Evidencia: artefactos de conteo real de tests y gate de cobertura
  (`agregado src/ 97.12 %`, mínimo por contrato `91.53 %`, umbrales 80 %/80 %).
- Incidencias reales resueltas durante el primer push: *dubious ownership* en el runner no-root (arreglado con
  `git config --global --add safe.directory '*'`, que cubre también los submódulos anidados) y eliminación de la
  dependencia de `jq` en el gate de ABIs (la imagen oficial solo trae `git`).
- Quedan **subidos** todos los commits de las Fases 3 y 4 (rama `rwa-sc-DSH-GCP`; `main` intacta). El `push`
  se autorizó explícitamente y la rama está replicada en **GitLab.com**, **GitHub** y **CodeCrypto**.

## Próximo paso

**Proyecto de contratos cerrado** (Fases 1–4 completadas, Fase 5 omitida por D-087). Se abre una **nueva etapa de optimización** centrada en el frontend `@web` (ver sección final). La operación de `push` ya está
ejecutada: `rwa-sc-DSH-GCP` está publicada en GitLab.com (`origin`), GitHub y CodeCrypto. El ensayo oficial del pipeline sigue siendo:

```bash
cd /home/dsh/workspace/RWA/rwa-sc
export PATH="$HOME/.foundry/bin:$PATH"
sc/script/ci/run_local_ci.sh        # validate -> build -> fmt -> test -> coverage -> gas -> ci-checks
```
- [x] **Ciclo 8b — Revisión del toolchain** (decisión **D-053**, sin cambios de código): se **mantiene
  `solc 0.8.20`** y el **digest EIP-712 propio** (binding de `chainId`/`verifyingContract`/`nonce` cubierto
  por tests, con `ECDSA` de OpenZeppelin). `EIP712Upgradeable` de OZ 5.5.0 exige `^0.8.24`; la subida del
  compilador y la adopción de la librería (más `eip712Domain()` de EIP-5267) quedan registradas como tarea
  del ciclo del área web, donde se re-baselinizará `.gas-snapshot`.

## Cierre de la Fase 4 y decisión sobre la Fase 5

- **Fase 4 (Pruebas) COMPLETADA**: 394/394 tests, 23 suites, 19 invariantes con estado; cobertura `src/`
  97,05 % líneas (mínimo por contrato 91,53 %); 5 gates + pipeline de GitLab en verde (7/7 jobs,
  pipeline `2935871780`); matriz de 142 criterios sin huecos; auditoría adversarial con 15 hallazgos
  (11 corregidos + 2 por decisión del usuario + 3 diferidos).
- **D-086 (decisión del usuario):** la **Fase 5 (Manuales) queda aplazada**; puede retomarse en cualquier
  momento con el skill `@manuales` (los insumos ya están: arquitectura, despliegue, datos, runbook y métricas).
- **Estado del repositorio remoto (`rwa-sc-DSH-GCP`)**: rama replicada en GitLab.com, GitHub y CodeCrypto;
  pipelines `2934202154`, `2934241152` y `2935871780` en verde; `main` intacta en `2a4a683`.

## Cierre de deuda (QW-8 · AF-12 · H-14 · H-19 · H-20 · H-07 · H-13)

- [x] **QW-8 (cierra H-34):** evento `TokenContractSet(address indexed tokenContract)` en los 3 módulos de
  compliance; antes la vinculación módulo→token no dejaba traza. Tests: `test_QW8_SetTokenContract_emite_evento`
  en las 3 suites de módulos. ABI **aditiva** (solo evento) → `sc/abis/` regenerado y `CHANGELOG_ABIS.md`
  actualizado.
- [x] **AF-12:** `removeClaim` incrementa `claimNonce[_topic][_issuer]` (mismo anti-replay que `revokeClaim`):
  la firma EIP-712 previa al borrado ya no reactiva el claim. La traza del claim borrado queda en los eventos
  `ClaimAdded`/`ClaimRevoked`/`ClaimRemoved` (storage borrado por diseño, `claimExists == false`). Tests:
  `test_AF12_*` (4) en `RF013_ClaimLifecycle.t.sol`.
- [x] **H-14:** `diccionario_datos.md` §1 (modelo on-chain) se corrige contra el storage real verificado con
  `forge inspect <C> storage-layout`: fuera `_tokenName`/`_tokenSymbol`/`bypassCompliance`, dentro `claimNonce`,
  `expiresAt`/`revoked` y los 4 campos de RF-004; líneas y eventos actualizados (incluye `TokenContractSet`).
- [x] **H-19 (M-10):** `setTokenContract` es *bind-once* en los 3 módulos: revierte
  `"Module already bound to another token"` si ya apuntaban a otro token (idempotente con el mismo). AF-01 ya
  bloqueaba registrar un módulo sin vincular; con esto el estado por cuenta (`isHolder`/`holderCount`,
  `lockEndTime`) no puede mezclarse entre tokens. **Sin cambio de ABI.** Tests: `test_H19_*` (6).
- [x] **H-20 (M-11):** índices O(1) (`moduleIndex`, `addressIndex`, `issuerIndex`, `issuerHasTopic`,
  `topicIndex`, `topicExistsFlag`) y 6 vistas paginadas, **sin retirar** arrays ni getters (ABI aditiva).
  `hasClaimTopic` y `claimTopicExists` dejan de recorrer arrays; `removeComplianceModuleByAddress` permite
  borrar por dirección en O(1); `addModuleThroughAggregator` ya no escanea. Suite nueva
  `test/H20_Escalabilidad.t.sol` (6 tests).
- [x] **H-07 (M-7):** allowlist de creadores en `TokenCloneFactory`, `IdentityCloneFactory` y
  `ClaimTopicsRegistryCloneFactory` (`authorizedCreators` + `setAuthorizedCreator` + `onlyCreator` +
  evento `CreatorAuthorized`). Cierra el "primer llamador gana" de `createRegistryForToken`. La
  implementación clonada sigue siendo `immutable`: ciclo de vida = **redeploy limpio** (D-009/D-019,
  `RUNBOOK_MIGRACION.md`). Tests: `test_H07_*` (6).
- [x] **H-13 (M-8):** catálogo canónico **v1.0** de claim topics (1=KYC, 7=Accreditation,
  9=Jurisdiction; 5/6 reservados) con fuente única en el seed `rwa.claim_topics`; `ARQUITECTURA_FINAL.md`
  y `REFERENCIA_TECNICA.md` alineados y gate nuevo `sc/script/ci/check_claim_topics.sh`
  (`ci_check_H13_catalogo_topics_unico`) integrado en `ci-checks`.
- **Estado actual medido:** **420/443 tests en 25 suites**, cobertura `src/` **97,18 %** (896/922; mínimo
  92,31 %), CI local 7/7. Detalle en `metricas_ejecucion.md` §25–§28 y `CHANGELOG_ABIS.md`.

## Cierre de los hallazgos restantes (AF-04 · AF-14 · H-06 · H-29 · H-32 · RNF)

- [x] **AF-04:** `createIdentityWithClaim` exige `msg.sender == owner` (anti front-running del clon
  predecible). `test_AF04_createIdentityWithClaim_tercero_revierte`.
- [x] **AF-14:** `check_secrets.sh` escanea los `.md` con `DOC_RE` buscando claves crudas **etiquetadas**
  (sin marcar hashes de evidencia); prueba negativa documentada.
- [x] **H-06 (R-7/D-021) — mecanismo:** nuevo `src/GovernanceMultisig.sol` (multisig M-de-N + timelock,
  mantenimiento auto-dirigido, propagación del revert), `script/DeployGovernance.s.sol` y runbook de
  entrega de roles (`RUNBOOK_MIGRACION.md` §8). Suite `GovernanceMultisig.t.sol` (23). **Pendiente:
  adoptarlo en el despliegue canónico y auditarlo** (el mecanismo por sí solo no cierra H-06).
- [x] **H-29 (M-14):** `DeployFullStack.s.sol` activa hasta 3 módulos (MaxBalance obligatorio;
  MaxHolders/TransferLock opcionales por env) y `deploy.sh` deriva y verifica el conteo real y cada
  módulo. Simulado con 1 y 3 módulos.
- [x] **H-32:** 0 referencias `.sol` rotas en `DEPENDENCIAS_CONTRATOS.md` + diccionario contra el storage
  real (H-14).
- [x] **H-09 / RNF-107:** análisis estático obligatorio con Slither: gate `check_slither.sh` +
  `slither.config.json` y job `slither` (imagen Python + Foundry v1.8.3). `src/` queda en **0 High y
  0 Medium** (2 falsos positivos `reentrancy-no-eth` mitigados con `nonReentrant` y suprimidos, y 2
  `unused-return` suprimidos con justificación).
- [x] **H-09 · H-10 · H-11 · H-12 · H-25 · H-27 · H-30:** nuevo
  `RepoTecnico/requerimientos_no_funcionales.md` (catálogo RNF ISO 25010 + regulatorio + protección de
  datos + observabilidad + continuidad + soporte). Quedan **definidos y medibles**; las categorías
  legal/regulatorias y el ensayo de restauración requieren **aprobación/ejecución externa**, y el
  **indexer** (H-12/H-21) es un componente off-chain.
- **Lo que queda (no lo cierra el equipo técnico):** aprobación **legal** (H-10, H-11, H-25), **ensayo
  de restauración** (H-30), **indexer off-chain** (H-12/H-21), **adopción + auditoría del multisig**
  (H-06, R-7) y la **auditoría externa** antes de activos reales (R-9).

## Cierre del proyecto (Fase 5 omitida)

- **D-087 (decisión del usuario):** se **omite la Fase 5 (Manuales)**. El proceso de 5 fases queda
  cerrado con las **Fases 1–4 completadas** y la Fase 5 explícitamente omitida.
- **Entregable final**: rama `rwa-sc-DSH-GCP` (30 commits) replicada y sincronizada en **GitLab**,
  **GitHub** y **CodeCrypto** (`0fa22f0`), con 5 pipelines verdes (7/7 jobs).
- Si en el futuro se quieren manuales, pueden generarse con `@manuales` (skill `equipo-manuales`) a partir
  de los insumos ya versionados: `documento_tecnico.md`, `entornos_globales.md`, `RUNBOOK_MIGRACION.md`,
  `diccionario_datos.md`, `diagrama_er.md`, `SECURITY.md` y `metricas_ejecucion.md`.

## Entregables de comunicación (2026-10-13)

- **Informe de optimización antes/después** → `RepoTecnico/informe_optimizacion_antes_despues.md`
  (dimensiones **lógica**, **administrativa** y **característica**, con trazabilidad de cada afirmación).
- **Infografía del proyecto** → `RepoTecnico/imagenes/infografia_proyecto.png` (1400×1390) y su fuente
  `infografia_proyecto.html`; render reproducible con `imagenes/render_infografia.sh`
  (usa el Chromium de Playwright del host + `LD_LIBRARY_PATH` a `/home/dsh/tools/libs`, ya que el sistema
  no tiene `mmdc`, `pandoc`, ImageMagick ni librerías de Chromium instaladas).

---

## Nueva etapa — Optimización del proyecto: frontend `@web` (2026-10-14)

> Abierta a petición del usuario (`@web` + `@asistenteProyecto`). **No reabre** las Fases 1–4 de contratos
> (cerradas y en verde) ni revive la Fase 5 (omitida, D-087): es una etapa nueva sobre `rwa-web/`.

> **Reorganización de líneas (2026-10-14, petición del usuario):** con el fin de mantener separadas las dos
> líneas de desarrollo **con sus propios archivos** (`@sc` en `rwa-sc/` y `@web` en `rwa-web/`), los documentos
> propios del frontend se movieron a `rwa-web/RepoTecnico/`: `INFORME_OPTIMIZACION_WEB_V1.md`,
> `requerimientos_web.md`, `plan_desarrollo_web.md` y `pruebas/verificacion_gcp_o0.md`. Los artefactos de datos
> compartidos (`base_datos.sql`, `diccionario_datos.md`, `diagrama_er.md`) se **duplican** en las dos líneas
> (canónico en `rwa-sc/RepoTecnico/` + espejo en `rwa-web/RepoTecnico/`), con la **regla de sincronización
> byte a byte** documentada y verificable en `rwa-web/RepoTecnico/ARTEFACTOS_DATOS_SINCRONIZADOS.md`
> (`check_sincronizacion_datos.sh`); el resto de documentación de la línea `@sc` permanece en `rwa-sc/RepoTecnico/`.

### Estado y alcance

| Campo | Valor |
|---|---|
| **Estado** | 🟡 **CICLO O0 EN CURSO** — **O0.1 completado (2026-10-14):** PostgreSQL en GCP conectado y esquema `rwa` aplicado/verificado; **Anvil de GCP verificado** (chain 31337, 9/9 contratos, EIP-712 + RF-004 + AF-01 al día). Siguiente: O0.2 (capa de datos) |
| **Artefactos de la etapa** | **Línea `@web` (movidos a `rwa-web/RepoTecnico/`):** `INFORME_OPTIMIZACION_WEB_V1.md` · `requerimientos_web.md` v1.2 · `plan_desarrollo_web.md` v1.2 · `pruebas/verificacion_gcp_o0.md`. **Compartidos (canónico en `rwa-sc/RepoTecnico/` + espejo en `rwa-web/RepoTecnico/`, sincronizados byte a byte):** `base_datos.sql` v1.0 · `diccionario_datos.md` v1.2 · `diagrama_er.md` v1.2. **Solo en `rwa-sc/`:** `entornos_globales.md` §14. **Ya en `rwa-web/`:** `scripts/gcp-env.sh` · `.env.example` |
| **Área** | `rwa-web/` — 5 apps Next.js. **Queda incorporada al alcance** (D-003 la excluía del ciclo de contratos) |
| **Insumo auditado** | `rwa-web/RepoTecnico/INFORME_OPTIMIZACION_WEB_V1.md` — 16 hallazgos (3 críticos, 5 altos, 6 medios, 2 bajos); verificación adversarial **15/15 confirmados, 0 refutados** |
| **Métricas base** | 16.648 líneas · 16 rutas de API (0 con auth) · 0 tests · 0 CI · sin control de versiones · 4 versiones de `next` · 2 stacks web3 |
| **Artefactos de datos** | **ACTUALIZADOS (D-095):** `base_datos.sql` v1.0 es ya **DDL real y ejecutable** del esquema PostgreSQL `rwa` (10 tablas + 1 vista + catálogo); `diccionario_datos.md` v1.2 y `diagrama_er.md` v1.2 se sincronizaron en el mismo turno. El Anexo A de `base_datos.sql` conserva la transcripción MongoDB para el ETL |

### Verificación de contexto (2026-10-14, tras la reorganización)

> Re-análisis del árbol real contra la línea base de la auditoría. **No hay crecimiento de código**: se
> mantienen 16.648 líneas TS/JS (el glob de medición se mantiene idéntico; los 125 líneas `.mjs` quedan fuera).

| Hecho verificado | Valor actual | ¿Cambió? |
|---|---|---|
| Líneas TS/JS (5 apps) | **16.648** | **No** (idéntico a la auditoría) |
| Rutas de API / con autenticación | **16 / 0** | No |
| Referencias a MongoDB en el código | **18** | No (es O0.3) |
| `ignoreBuildErrors: true` | 3 apps | No |
| Versiones de `next` / `react` | 4 / 2 | No |
| Repositorio `rwa-web` | ✅ creado: rama `rwa-web-DSH`, 229 ficheros, commit inicial `cd97c7d`; **5 commits** hasta `84bd35a` (contexto `@web` + sincronizaciones del espejo de datos), **sin remoto** | **Sí** (D-094 en curso) |
| `web-registry-trusted2/env.local` | **eliminado** → `.env.example` versionado; `.env.local` ignorado (`.gitignore:19`) | **Sí** (HW-15 cerrado) |
| `docker-build/` de 3 apps | **rastreado en git** (incluye ruta absoluta de desarrollador) | ⚠️ **Regresión de HW-11**: `git rm -r --cached` en O1/O3 |
| Gate de sincronización de datos | `check_sincronizacion_datos.sh --check` → **exit 0** (3/3 idénticos, sha256 coincidentes) | Nuevo (D-102) |
| Commit de la reorganización en `rwa-sc` | ✅ **commiteada en `688f737`** («docs: reorganiza @sc/@web y migra los artefactos de datos a PostgreSQL»); árbol de trabajo limpio y `rwa-sc-DSH-GCP` sincronizada con `origin` (0/0) | **Sí** (resuelto) |

### Decisiones de la etapa (D-088…D-102)

| ID | Tema | Estado |
|---|---|---|
| **D-088** | **Alcance = solo frontend `@web`.** Los contratos quedan cerrados (394/394 en verde); no se retoman AF-04/AF-12/AF-14 ni los bloques R-3/R-7 en esta etapa | ✅ **APROBADA** (bloque 1) |
| **D-089** | **Estrategia = hardening + monorepo y consolidación.** Ciclos O1–O5; estado final 3 apps sobre monorepo pnpm con paquete compartido | ✅ **APROBADA** (bloque 1) |
| **D-090** | **Orden = O1 seguridad → O2 integración → O3 higiene → O4 consolidación → O5 operación/calidad** | ✅ **APROBADA** (bloque 1) |
| **D-091** | **Red canónica = Anvil 31337**, con red parametrizable para Besu (81234 queda como alternativa documentada, no canónica) | ✅ **APROBADA** (bloque 2) |
| **D-092** | **Sesión = SIWE (EIP-4361) + cookie `httpOnly` firmada**; rol por wallet (inversor/issuer autorizado/admin de token) | ✅ **APROBADA** (bloque 2) |
| **D-093** | **Custodia KYC = GridFS cifrado (AES-256-GCM) + acceso por propiedad**, servido siempre como adjunto | ✅ **APROBADA** (bloque 2) |
| **D-094** | **Se crea el repositorio `rwa-web`** y se publica en GitLab.com (`anlucorporations/rwa-web`, rama `rwa-web-DSH`); sin `push` sin orden explícita | ✅ **APROBADA** (bloque 2) |
| **D-095** | **BD off-chain = PostgreSQL** (Cloud SQL, PG 15+, esquema `rwa`). **Sustituye a MongoDB** en el frontend y **resuelve Q6**. Esquema real: `base_datos.sql` v1.0 (10 tablas, 1 vista, catálogo sembrado); `document_files` cifrado sustituye a GridFS (matiza D-093) | ✅ **APROBADA** (directriz del usuario) |
| **D-096** | **Red on-chain canónica = Anvil de GCP** (`MCC_ANVIL_RPC_URL`, chain 31337). **Matiza D-091**: la instancia canónica es la de GCP, no la local; Besu 81234 queda como alternativa documentada | ✅ **APROBADA** (directriz del usuario) |
| **D-097** | **Hosting de la BD = Cloud SQL existente `truekeate-db-dev`** (PG 15.18, usuario `app`, Auth Proxy `127.0.0.1:5433`). **Región verificada: `southamerica-east1-a`** (V-3 resuelto; `entornos_globales.md` alineado) | ✅ **APROBADA** (bloque 3) |
| **D-098** | **Documentos KYC = `bytea` cifrado AES-256-GCM en `rwa.document_files`** (sin almacenamiento externo); `sha256` + metadatos en la misma fila | ✅ **APROBADA** (bloque 3) |
| **D-099** | **Arranque limpio:** no se migran los datos de MongoDB (solo había datos de prueba); el esquema se crea vacío con el catálogo de topics sembrado. El Anexo A de `base_datos.sql` queda como ETL opcional | ✅ **APROBADA** (bloque 3) |
| **D-100** | **Se añade el ciclo O0 (fundación: esquema PostgreSQL + capa de datos + red Anvil de GCP) como primer ciclo**, antes de O1. Matiza D-090 | ✅ **APROBADA** (bloque 3) |
| **D-101** | **Conexión a Cloud SQL:** forma canónica por **socket unix** (`/cloudsql/truekeate-main:southamerica-east1:truekeate-db-dev`) para Cloud Run/Auth Proxy; **TCP a la IP pública `34.39.180.101`** para hosts ya autorizados en el ACL (el proxy no está instalado). Se fija en `rwa-web/scripts/gcp-env.sh` con modo `--tcp` | ✅ **APLICADA** (verificación O0.1) |
| **D-102** | **Separación de líneas `@sc`/`@web`:** cada línea con su `RepoTecnico/`; los web-docs pasan a `rwa-web/RepoTecnico/`; los tres artefactos de datos se **duplican** (canónico `rwa-sc` + espejo `rwa-web`) con regla de sincronización byte a byte y **gate** `check_sincronizacion_datos.sh --check` | ✅ **APLICADA** (reorganización del usuario) |

### Plan de ciclos propuesto (borrador, a validar)

| Ciclo | Objetivo | Hallazgos | Esfuerzo |
|---|---|---|---|
| **O0** | **Fundación (D-100):** esquema PostgreSQL `rwa` + capa de datos + red Anvil de GCP (arranque limpio, sin ETL) | D-095…D-100 | M |
| **O1** | Contención de seguridad: retirar endpoints `test-*`, cerrar lectura de PII, autorizar `update-request` y toda escritura | HW-01, HW-02, HW-04 | S |
| **O2** | Sincronización con contratos: ABIs/direcciones desde artefactos, flujo de claim EIP-712, `claimTopicsRegistry` obligatorio | HW-03, HW-07 | M |
| **O3** | Verificabilidad: repo `rwa-web` + CI (lint/tsc/build/tests), versiones unificadas, retirada de `ignoreBuildErrors` | HW-05, HW-06, HW-08, HW-13 | M |
| **O4** | Consolidación: monorepo pnpm + `packages/shared`, deduplicación y decisión sobre `web-rwa` / `web-registry-trusted2` | HW-09, HW-10 | L |
| **O5** | Operación y calidad: contenedores reproducibles, observabilidad, RNF web (ISO 25010, WCAG 2.1 AA) | HW-11, HW-12, HW-14, HW-15, HW-16 | M |

### Criterios de cierre de la etapa

Se toman como criterios los **bloqueantes B-1…B-6** y de **calidad C-1…C-5** de `rwa-web/RepoTecnico/INFORME_OPTIMIZACION_WEB_V1.md` §8:
0 endpoints públicos con PII · flujo identidad → claim → aprobación → `isVerified` operativo en la red canónica ·
CI en verde sobre `rwa-web` · una sola versión de `next`/`react` por workspace · sin `ignoreBuildErrors` ·
0 errores de dependencia devueltos como `200`.
