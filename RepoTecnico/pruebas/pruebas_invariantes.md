# Pruebas de invariantes con estado (Foundry invariant testing) — `rwa-sc`

> **Proyecto:** RWA / `rwa-sc` · **Fase 4 (Pruebas)** · **Requisito:** RF-009 · **Fecha:** 2026-10-10
> **Ámbito:** `rwa-sc/sc/test/invariant/**`, `rwa-sc/sc/foundry.toml`, `.gitlab-ci.yml`, `sc/script/ci/run_local_ci.sh`.
> **Línea base:** 353 tests / 18 suites en verde, cobertura `src/` 97,12 % (674/694) y mínimo por contrato 91,53 %.
> **Sin cambios en `src/`:** las invariantes **no** encontraron ninguna violación atribuible al código de producción,
> por lo que no se tocó ningún contrato, ni ABI, ni `SECURITY.md` (ver §5).

---

## 1. Objetivo y enfoque

Buscar violaciones de invariantes **con estado** que las suites unitarias (353 tests) no cubren, usando
*handlers* acotados y el fuzzer de invariantes de Foundry (`targetContract` + acciones con argumentos
fuzzeados). El diseño sigue tres reglas:

1. **Modelo independiente (ghosts).** Las propiedades de llamada («todo `forcedTransfer` con éxito va a un
   destino autorizado», «ninguna transferencia con éxito usa cuentas congeladas») no son propiedades de
   estado puras: se observan en el momento de la llamada y se anotan en un contrato de *ghosts* que los
   invariantes leen. Las propiedades de estado (sincronía array↔mapping, contadores, `maxSupply`,
   `claimNonce`) se comparan contra un **modelo fantasma** que solo se actualiza cuando la llamada al
   contrato tiene éxito.
2. **Los handlers no revierten.** Encapsulan cada llamada al contrato en un `call` de bajo nivel y ignoran
   el resultado. Así `[invariant] fail_on_revert = false` no descarta silenciosamente una violación de
   `assert` (todas las comprobaciones viven en las funciones `invariant_*` y en `test_handler_operativo`).
3. **ABI de handler mínimo.** Los handlers no heredan de `Test`/`StdUtils` y sus campos son `private`; su
   ABI solo expone las acciones acotadas (nada de getters fuzzeables). Un `test_handler_operativo` por
   suite demuestra que el handler alcanza caminos de éxito reales (si no, los invariantes pasarían de
   forma trivial).

## 2. Configuración (`sc/foundry.toml`)

```toml
[invariant]
runs = 64          # secuencias independientes por contrato de invariantes
depth = 64         # llamadas al handler por secuencia
fail_on_revert = false
```

- **`runs * depth = 4096`** llamadas al handler por contrato de invariantes, **16 384** en total (4
  contratos). Se probó `128/128` (16 384 por contrato): la suite pasó en **313 s**, inviable para el
  pipeline. `64/64` mantiene un coste de **~13 s** en la suite de invariantes y deja el job `test`
  completo en **~15-25 s** (máximo medido 80 s, ver §4), muy por debajo del límite de 3-4 min.
- **`fail_on_revert = false`**: los handlers no revierten, de modo que un revert inesperado de una acción
  acotada no aborta la secuencia; las violaciones se registran en ghosts. El precio es que `assert`
  dentro de un handler sería ignorado, por eso **no hay ningún `assert` en los handlers**.
- **Sin semilla propia.** Foundry v1.8.3 no expone `[invariant] seed` (`forge config` no lo lista); las
  secuencias varían entre ejecuciones. El gate de gas **no** se ve afectado porque las entradas de
  invariantes del `.gas-snapshot` registran `(runs, calls, reverts)`, no gas (ver §4).
- **Presupuesto distinto en la etapa de cobertura:** el job `coverage` ejecuta los invariantes con
  `FOUNDRY_INVARIANT_RUNS=1` / `FOUNDRY_INVARIANT_DEPTH=1` (65 s en local frente a 204 s con 64/64),
  porque la cobertura de `src/` la determinan las suites unitarias y **no baja** (97,12 % en ambos casos).

## 3. Inventario de suites, handlers e invariantes

Cuatro contratos de invariantes en `sc/test/invariant/`:

| Suite | Handler | Acciones fuzzeadas | Invariantes |
|---|---|---|---|
| `TokenInvariants.t.sol` | `handlers/TokenHandler.sol` | 23 | 8 |
| `RegistryInvariants.t.sol` | `handlers/RegistryHandler.sol` | 8 | 3 |
| `IdentityInvariants.t.sol` | `handlers/IdentityHandler.sol` | 5 | 4 |
| `AggregatorInvariants.t.sol` | `handlers/AggregatorHandler.sol` | 6 | 4 |

Total: **19 funciones `invariant_*`** en **4 suites**, más **4** `test_handler_operativo`.

### 3.1 `TokenCloneable` — seguridad y contabilidad

Handler (`TokenHandler`, 23 acciones): `mint`, `burn`, `transfer`, `transferFrom`, `forcedTransfer`,
`freezeAccount`/`unfreezeAccount`, `pause`/`unpause`, `setAuthorizedDestination`,
`setMaxBurnPerTx`/`setMaxForcedPerTx`/`setMaxSupply`, `addComplianceModule`/`removeComplianceModule`,
`addTrustedIssuer`/`removeTrustedIssuer`, `addClaimTopic`/`removeClaimTopic`, `revokeClaim`/`renewClaim`/
`removeClaim`, `warpTime`. Escenario: 5 actores verificados con `MaxBalanceCompliance` +
`MaxHoldersCompliance`, topes RF-004 activos y whitelist de destinos conmutable.

| Invariante | Propiedad |
|---|---|
| `invariant_totalSupply_igual_suma_de_saldos` | `totalSupply() == Σ balanceOf(actor)` |
| `invariant_totalSupply_solo_baja_por_burn` | `totalSupply` nunca decrece salvo por `burn` |
| `invariant_maxSupply_respetado` | `maxSupply == 0 \|\| totalSupply() <= maxSupply` |
| `invariant_burn_no_supera_limite` | `burn` con éxito ⇒ `maxBurnPerTx > 0 && amount <= maxBurnPerTx` |
| `invariant_forcedTransfer_destino_autorizado` | `forcedTransfer` con éxito ⇒ `to` autorizado y `amount <= maxForcedPerTx` |
| `invariant_transferencia_sin_congelados_ni_pausa` | `transfer`/`transferFrom` con éxito ⇒ token no pausado y ninguna cuenta congelada |
| `invariant_guard_nonReentrant_no_pegado` | sonda `mint(actor,0)`: nunca revierte con `ReentrancyGuardReentrantCall` |
| `invariant_isVerified_equivalente_a_claim_valido` | `isVerified(a)` ⟺ todos los topics requeridos tienen un claim vigente y no revocado de un issuer autorizado |

### 3.2 Registries — sincronía array ↔ mapping

Handler (`RegistryHandler`, 8 acciones): altas/bajas/actualizaciones de identidad, de issuer confiable y
de topic en cualquier orden, sobre pools fijos (5 wallets, 6 identidades, 4 issuers, topics {1,2,3}).
`RegistryGhosts` mantiene la pertenencia esperada, actualizada **solo** en éxito.

| Invariante | Propiedad |
|---|---|
| `invariant_identityRegistry_sincronizado` | `registeredAddresses` ↔ `registered`/`identities`: contador = tamaño, todo elemento registrado y con identidad ≠ 0, sin duplicados, y `isRegistered(w)` coincide con el modelo para cada wallet |
| `invariant_trustedIssuers_sincronizado` | `trustedIssuersList` ↔ `trustedIssuers`: contador = tamaño, sin duplicados, todo emisor con topics no vacíos, modelo coincidente |
| `invariant_claimTopics_sincronizado` | `claimTopics`: contador = tamaño, sin duplicados, sin topic 0, `claimTopicExists` coincide con el modelo |

### 3.3 `IdentityCloneable` — ciclo de vida del claim (CU-17)

Handler (`IdentityHandler`, 5 acciones): alta/renovación firmada EIP-712 con el `claimNonce` vigente,
baja por el titular, revocación por el issuer, intento de revocación por terceros y avance del reloj.

| Invariante | Propiedad |
|---|---|
| `invariant_claimNonce_no_decrece` | `claimNonce[topic][issuer]` es monótono no decreciente por identidad/topic |
| `invariant_revokeClaim_solo_issuer` | ninguna cuenta distinta del issuer logra revocar |
| `invariant_hasValidClaim_semantica` | `hasValidClaim` ⟺ existe ∧ ¬revocado ∧ (`expiresAt == 0` ∨ `now < expiresAt`) |
| `invariant_isVerified_equivalente_a_claim_valido` | un claim revocado o vencido nunca verifica: equivalencia de `isVerified` con «claim vigente de issuer autorizado» |

### 3.4 `ComplianceAggregator` (CU-16)

Handler (`AggregatorHandler`, 6 acciones): alta/baja por la vía de producción
(`token.addModuleThroughAggregator`/`removeModuleThroughAggregator`) y cuatro ataques de aislamiento
(un token administrando los módulos de otro y el owner global administrando los de un token).

| Invariante | Propiedad |
|---|---|
| `invariant_aggregator_failclosed_sin_modulos` | 0 módulos o token no registrado ⇒ `canTransfer == false` |
| `invariant_token_no_administra_modulos_ajenos` | ningún ataque de aislamiento ha tenido éxito |
| `invariant_getModuleCount_coincide_con_activos` | `getModuleCount` = tamaño de `getModules` = nº de módulos activos del modelo, sin duplicados |
| `invariant_registro_de_tokens_consistente` | `tokens` ↔ `_isTokenRegistered`: sin duplicados y pertenencia coherente |

## 4. Resultados y tiempos

| Verificación | Comando | Resultado |
|---|---|---|
| Build | `forge build` | 0 errores |
| Suite completa | `forge test` | **361 tests / 0 fallos / 0 skip**, 22 suites |
| Solo invariantes | `forge test --match-path 'test/invariant/*'` | **8 tests** (4 suites + 4 `test_handler_operativo`), **13,2 s** |
| Cobertura `src/` | `forge coverage --report summary` | **97,12 % (674/694)**, mínimo por contrato **91,53 %** (sin cambios) |
| Gas | `forge snapshot --check --tolerance 5` | OK (376 entradas) |

Desglose de la suite completa (22 suites):

- **353** tests unitarios previos (intactos).
- **4** contratos de invariantes (`runs: 64, calls: 4096, reverts: 0` cada uno).
- **4** `test_handler_operativo` (comprobación del harness, no invariantes).
- **19** funciones `invariant_*` dentro de los 4 contratos.

Tiempos medidos (máquina de desarrollo, Forge 1.8.3):

| Medición | Tiempo |
|---|---|
| `forge test` completo — mínimo observado | **15,5 s** |
| `forge test` completo — medición típica | **25,2 s** |
| `forge test` completo — máximo observado | **80,7 s** |
| Suite de invariantes sola (64/64) | **13,2 s** |
| `forge coverage` con 64/64 | **204 s** |
| `forge coverage` con `RUNS=1 DEPTH=1` (etapa CI) | **65 s** |
| Intento descartado `runs=128, depth=128` | **313 s** |

La variación del `forge test` completo (15–80 s) proviene de que el fuzzer de invariantes no admite
semilla y explora secuencias distintas en cada ejecución; el peor caso sigue muy por debajo del límite del
job. Los 19 invariantes pasaron **en todas** las configuraciones probadas.

## 5. Hallazgos

**No se encontró ninguna violación de los invariantes del encargo.** Concretamente:

- La contabilidad del token es consistente: `totalSupply` = suma de saldos de los actores manejados en
  todas las secuencias, y solo `burn` lo reduce.
- `maxSupply` nunca queda por debajo del suministro; `burn` y `forcedTransfer` respetan sus topes por
  operación y la whitelist de destinos de `forcedTransfer`.
- `transfer`/`transferFrom` nunca tienen éxito con token pausado o cuentas congeladas.
- El guard `nonReentrant` no se queda «pegado»: la sonda nunca revierte con `ReentrancyGuardReentrantCall`
  (coherente con el `ReentrancyGuard` sin estado ERC-7201 de OZ v5.5.0).
- `isVerified` equivale exactamente a «todos los topics requeridos cubiertos por un claim vigente y no
  revocado de un issuer autorizado para el topic», también cuando el handler borra topics, revoca claims o
  avanza el reloj más allá de `expiresAt`.
- Los tres registries mantienen array y mapping sincronizados (contador, pertenencia, sin duplicados ni
  huecos) tras altas/bajas/actualizaciones en cualquier orden.
- `claimNonce` solo crece; `revokeClaim` solo lo acepta el issuer; `hasValidClaim` rechaza revocados y
  vencidos.
- El `ComplianceAggregator` es fail-closed con 0 módulos y ningún token (ni el owner global) administra
  módulos de otro token.

**Observaciones de alcance (no son bugs):**

1. El invariante «ninguna transferencia con cuentas congeladas ni token pausado» se limita, como en
   CU-10, a `transfer`/`transferFrom`. `forcedTransfer` **omite a propósito** pausa/congelación y
   compliance (RF-002, ruta explícita de recuperación), y `mint` es una operación privilegiada de emisión,
   no una transferencia; por eso no se marcan como violación.
2. El fuzzer de invariantes de Foundry v1.8.3 no tiene semilla configurable, de modo que las secuencias
   exploradas cambian entre ejecuciones. Es una limitación de reproducibilidad del *conjunto de entradas*
   (no del resultado: los 19 invariantes pasan siempre) que conviene registrar.

## 6. Integración en el pipeline

- `sc/foundry.toml`: sección `[invariant]` (runs/depth/`fail_on_revert`).
- `.gitlab-ci.yml`:
  - job `test`: se añade `invariant_functions_listed` al artefacto `test-count.txt` (el conteo
    `tests_listed` sigue contando funciones `test*`, ahora 357).
  - job `coverage`: `variables: FOUNDRY_INVARIANT_RUNS=1`, `FOUNDRY_INVARIANT_DEPTH=1` para acotar la
    etapa (65 s frente a 204 s) sin afectar a la cobertura de `src/`.
- `sc/script/ci/run_local_ci.sh`: mismas dos modificaciones para que el ensayo local refleje el pipeline.

## 7. Trazabilidad

| Invariante | RF / CU | Criterio previo reforzado |
|---|---|---|
| Suministro y `maxSupply` | RF-004 / CU-06 · D-022 | `test_RF004_maxSupply_no_baja_bajo_total_supply` |
| Topes y whitelist de `burn`/`forcedTransfer` | RF-004 / CU-06 | `test_RF004_burn_excede_limite_revierte`, `test_RF004_whitelist_revocada_bloquea` |
| Congelación y pausa | RF-002 / CU-10 | `test_RF002_transfer_cuenta_congelada_revierte`, `test_RF002_transfer_token_pausado_revierte` |
| Guard `nonReentrant` | RF-002 / H-18 | `test/TokenReentrancy.t.sol` |
| `isVerified` fail-closed y vigencia | RF-011/RF-013 / CU-15·CU-17 | `test_RF011_*`, `test_RF013_*` |
| Sincronía de registries | HB-14 / RF-001 | `IdentityRegistry.t.sol`, `TrustedIssuersRegistry.t.sol` |
| `claimNonce` y revocación | RF-013 / CU-17 | `RF013_ClaimLifecycle.t.sol` |
| Fail-closed y aislamiento del aggregator | RF-012 / CU-16 | `RF012_AggregatorFailClosed.t.sol` |
