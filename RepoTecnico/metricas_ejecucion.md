# 📊 Métricas reales de ejecución — rwa-sc

> Anexo de la Fase 2 (Auditoría). Datos obtenidos ejecutando la suite, no leídos de los docs.
> Fecha: 2026-10-03 · Ejecutado por el Lead del proyecto.
> Entorno: Forge v1.8.3 (`/home/dsh/.foundry/bin/forge`, fuera del PATH), OZ 5.5.0, forge-std 1.12.0,
> dependencias clonadas en `rwa-sc/sc/lib/` (gitignored) para poder compilar.
> **Numeración de hallazgos:** `HB-01..HB-12` = análisis base del Lead (`requerimientos.md` §2); `H-01..H-34` =
> auditoría V1 (`INFORME_OPTIMIZACION_V1.md`). Toda cita de la auditoría se marca como «(auditoría V1)».

## 1. Corrección del entorno (dato previo erróneo)

| Dato previo | Realidad verificada |
|---|---|
| "Forge/Anvil no instalados" | **Sí están**: `/home/dsh/.foundry/bin/forge` v1.8.3 (solo faltaba en el PATH) |
| "No se puede compilar ni ejecutar tests" | **Sí se puede**: con `lib/` clonado, `forge build` y `forge test` corren |

`HB-05` (análisis base: build roto) queda **parcialmente corregido**: el bloqueo real es la ausencia de `sc/lib/`, no la toolchain.

## 2. Compilación

```
forge build   →  OK (sin errores de compilación)
```
Advertencias del linter de Forge (no bloqueantes): `block.timestamp` leído antes de `vm.warp`
en `test/TransferLockCompliance.t.sol:230` y `:239`.

## 3. Suite de tests

| Métrica | Valor real | Declarado en los docs |
|---|---|---|
| Tests declarados | **151** | "139 tests" (START_HERE.md) |
| Tests ejecutados/contados | **98** | — |
| Pasados | **93** | "100% passing" (START_HERE.md) |
| Fallidos | **5** | — |
| Tests que nunca se ejecutan | **53** (suites `Token.t.sol` 30 y `ComplianceAggregator.t.sol` 25 no arrancan) | — |

Comando: `forge test` → `Ran 8 test suites ... 93 tests passed, 5 failed, 0 skipped (98 total tests)`.

### 3.1 Fallas `InvalidInitialization()` (bloqueantes) — 2 suites, 53 tests muertos

- `test/Token.t.sol` → `setUp()` revierte: **`InvalidInitialization()`**
- `test/ComplianceAggregator.t.sol` → `setUp()` revierte: **`InvalidInitialization()`**

Causa raíz (evidencia en código):
- `test/Token.t.sol` hace `token = new TokenCloneable(); token.initialize(...)`, pero
  `src/TokenCloneable.sol:50-52` tiene `constructor() { _disableInitializers(); }` → `initialize` revierte.
- Lo mismo con `identity1 = new IdentityCloneable(); identity1.initialize(admin)`
  (`src/IdentityCloneable.sol:42-44` apaga los inicializadores).
- Los tests esperan las versiones "no-upgradeable para testing" que `ARQUITECTURA_FINAL.md` declara. De esas, **solo existe** `src/ClaimTopicsRegistry.sol` (usada por `test/Token.t.sol`); **`Token.sol` e `Identity.sol` NO existen** (HB-07 análisis base / H-15 auditoría V1). Por eso los tests instancian los contratos cloneables directamente, y sus constructores apagan los inicializadores.

### 3.2 Fallas de "ahorro de gas" (tests inválidos) — 3 suites

| Test | Resultado | Números reales |
|---|---|---|
| `TokenCloneFactory.t.sol:test_GasSavings` | `panic: arithmetic underflow (0x11)` | clone: **387.469** gas · "directo": **5.974** gas |
| `IdentityCloneFactory.t.sol:testGasSavings` | `panic: arithmetic underflow (0x11)` | clone: **214.623** gas · "full": **3.318** gas |
| `ClaimTopicsRegistryCloneFactory.t.sol:test_GasSavings` | assertion "Clone should save at least 50% gas" | — |

Causa raíz: el test compara **crear un clon inicializado** (clone + `initialize` + callbacks) contra
**desplegar la implementación pelada** (`new TokenCloneable()`, cuyo constructor solo apaga inicializadores).
La comparación no es equivalente: mide 5.974 gas de un contrato vacío contra 387.469 gas de un clon funcional.
Los ahorros del 94–98% que afirman `ARQUITECTURA_FINAL.md` y `START_HERE.md` **no están validados por ningún test**.

## 4. Cobertura real vs objetivo

Comando: `forge coverage --report summary`

| Métrica | Real | Objetivo (`RNF-002`) |
|---|---|---|
| Líneas | **42,86%** (339/791) | ≥ 80% |
| Sentencias | **38,25%** (288/753) | ≥ 80% |
| Ramas | **35,68%** (66/185) | ≥ 80% |
| Funciones | **55,70%** (83/149) | ≥ 80% |

Por contrato: `ComplianceAggregator.sol` **1,56%** (su suite no arranca) · `TransferLockCompliance.sol` 81,08% ·
`MaxHoldersCompliance.sol` 87,04% · `MaxBalanceCompliance.sol` 94,44%.
Los contratos principales (`TokenCloneable`, `IdentityCloneable`, registros, factories) quedan sin cobertura
porque sus suites revierten en `setUp`.

## 5. Consecuencias para el plan de la Fase 3

1. `RF-005` adquiere un alcance mayor de lo previsto: no basta con clonar `lib/`; hay que **arreglar las suites
   que no arrancan** (decidir: crear las versiones no-upgradeable de testing, o inicializar clones reales en los tests).
2. `RF-002` (gas/EIP-1167): los tests de ahorro deben reescribirse con una comparación equivalente
   (clon inicializado vs despliegue completo + `initialize`).
3. `RNF-002` (coverage ≥ 80%) exige **duplicar** la cobertura actual: los contratos núcleo están en ~0%.
4. Los docs que afirman "139 tests 100% passing" y "coverage >80%" deben corregirse (`RF-006`).

## 6. Reproducibilidad

```bash
export PATH="$HOME/.foundry/bin:$PATH"
cd /home/dsh/workspace/RWA/rwa-sc/sc
# dependencias (gitignored):
git clone --depth 1 --branch v1.12.0 https://github.com/foundry-rs/forge-std lib/forge-std
git clone --depth 1 --branch v5.5.0  https://github.com/OpenZeppelin/openzeppelin-contracts lib/openzeppelin-contracts
git clone --depth 1 --branch v5.5.0  https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable lib/openzeppelin-contracts-upgradeable
forge build
forge test
forge coverage --report summary
```

---

## 7. Ciclo 1 (RF-005) — resultados tras el ciclo

> Fecha: 2026-10-10 · Rama `rwa-sc-DSH-GCP` · Commit local `RF-005` (sin push).
> Toolchain fijado en `sc/foundry.toml`: `solc_version = "0.8.20"`, `optimizer = true`,
> `optimizer_runs = 200`, `evm_version = "paris"`. Forge v1.8.3, OZ 5.5.0, forge-std 1.12.0.

### 7.1 Suite de tests — antes / después

| Métrica | Antes (2026-10-03) | Después (2026-10-10) |
|---|---|---|
| Tests declarados (`forge test --list`) | 151 | **151** |
| Tests ejecutados/contados | 98 | **151** |
| Pasados | 93 | **151** |
| Fallidos | 5 | **0** |
| Nunca ejecutados (suites que revertían en `setUp`) | 53 | **0** |
| Suites que revierten en `setUp` | 2 (`Token`, `ComplianceAggregator`) | **0** |
| Tests de ahorro de gas inválidos | 3 | **0** |

Comando: `forge test` → `Ran 8 test suites ... 151 tests passed, 0 failed, 0 skipped (151 total tests)`.

### 7.2 Cobertura — antes / después

Comando: `forge coverage --report summary`.

| Métrica | Antes (total) | Después (total) | Después (`src/` sólo) |
|---|---|---|---|
| Líneas | **42,86 %** (339/791) | **67,50 %** (565/837) | **86,33 %** (518/600) |
| Sentencias | 38,25 % (288/753) | 65,95 % (521/790) | 86,56 % (483/558) |
| Ramas | 35,68 % (66/185) | 62,76 % (123/196) | 65,19 % (118/181) |
| Funciones | 55,70 % (83/149) | 79,38 % (127/160) | 86,36 % (114/132) |

> El total de Forge incluye `script/` (0 %) y `test/benchmarks/` (nuevos en este ciclo),
> por lo que baja el porcentaje agregado. Sobre el código de producción (`src/`), las
> líneas pasan de 42,86 % a **86,33 %**, por encima del objetivo RNF-002 (≥ 80 %).

### 7.3 Ahorro de gas medido (comparación equivalente)

Los 3 tests de ahorro se reescribieron contra una **línea base no-upgradeable equivalente**
(`sc/test/benchmarks/`), midiendo con el opcode `CREATE` en assembly porque `forge` reescribe
`new Contrato()` de `src/` a `vm.deployCode` (gas no medible). Cifras del test:

| Operación | Clon (factory) | Despliegue completo | Ahorro |
|---|---|---|---|
| `TokenCloneFactory.createToken` | 381.570 | 859.098 | 477.528 (**55 %**) |
| `IdentityCloneFactory.createIdentity` | 212.307 | 530.753 | 318.446 (**59 %**) |
| `IdentityCloneFactory.createIdentityWithClaim` | 440.694 | 812.509 | 371.815 (**45 %**) |
| `ClaimTopicsRegistryCloneFactory.createRegistry` | 210.149 | 451.038 | 240.889 (**53 %**) |

Las cifras publicadas antes (39 %, 88–98 %, 90,2 %, 96,5 %) **no estaban medidas** y quedan
sustituidas por estas. Baseline por test versionado en `sc/.gas-snapshot` (RNF-001).

### 7.4 Reproducibilidad (B-5)

- Un único `.gitmodules` en `rwa-sc/`, con los 3 submódulos (`sc/lib/*`) pinneados por revisión
  en `sc/foundry.lock`:
  `forge-std` v1.12.0 (`7117c90`), `openzeppelin-contracts` v5.5.0 (`fcbae53`),
  `openzeppelin-contracts-upgradeable` v5.5.0 (`aa677e9`).
- `git submodule status` → 3 entradas sin prefijo `-`/`+`.
- Bootstrap documentado en `rwa-sc/README.md`: `git clone --recurse-submodules` + `forge build` + `forge test`.

---

## 8. Ciclo 1b — refuerzo de cobertura de los registries

> Fecha: 2026-10-10 · Rama `rwa-sc-DSH-GCP` (commit local, sin push).
> Objetivo: cerrar el gate de RNF-002 **por contrato** (decisión D-017) sobre
> `IdentityRegistry`, `TrustedIssuersRegistry` y `ClaimTopicsRegistry`.

### 8.1 Tests — antes / después

| Métrica | Antes (Ciclo 1) | Después (Ciclo 1b) |
|---|---|---|
| Tests ejecutados/pasados | **151 / 151** | **243 / 243** |
| Fallidos | 0 | **0** |
| Suites | 8 | **11** |
| Suites que revierten en `setUp` | 0 | **0** |

Comando: `forge test` → `Ran 11 test suites ... 243 tests passed, 0 failed, 0 skipped (243 total tests)`.
Las tres suites nuevas (`test/IdentityRegistry.t.sol` 34, `test/TrustedIssuersRegistry.t.sol` 33,
`test/ClaimTopicsRegistry.t.sol` 25) suman **92 tests** y no duplican lo ya cubierto desde
`Token.t.sol` / `ComplianceAggregator.t.sol`.

### 8.2 Cobertura por contrato objetivo (líneas / funciones)

Comando: `forge coverage --report summary`.

| Contrato | Líneas antes | Líneas después | Funciones antes | Funciones después |
|---|---|---|---|---|
| `src/IdentityRegistry.sol` | **37,14 %** (13/35) | **100,00 %** (35/35) | 50,00 % (4/8) | **100,00 %** (8/8) |
| `src/TrustedIssuersRegistry.sol` | **38,46 %** (15/39) | **100,00 %** (39/39) | 33,33 % (3/9) | **100,00 %** (9/9) |
| `src/ClaimTopicsRegistry.sol` | **45,45 %** (10/22) | **100,00 %** (22/22) | 50,00 % (3/6) | **100,00 %** (6/6) |

Los tres superan el umbral de RNF-002 (≥ 80 %) también en sentencias y ramas:

| Contrato | Sentencias después | Ramas después |
|---|---|---|
| `src/IdentityRegistry.sol` | 100,00 % (29/29) | 100,00 % (17/17) |
| `src/TrustedIssuersRegistry.sol` | 100,00 % (34/34) | 100,00 % (15/15) |
| `src/ClaimTopicsRegistry.sol` | 100,00 % (20/20) | 100,00 % (6/6) |

### 8.3 Cobertura agregada de `src/` (D-017: sin `ICompliance.sol` ni `IClaimTopicsRegistry.sol`)

| Métrica | Antes (Ciclo 1) | Después (Ciclo 1b) |
|---|---|---|
| Líneas | 86,33 % (518/600) | **96,00 %** (576/600) |
| Sentencias | 86,56 % (483/558) | **95,70 %** (534/558) |
| Ramas | 65,19 % (118/181) | **81,77 %** (148/181) |
| Funciones | 86,36 % (114/132) | **96,21 %** (127/132) |

> El total que imprime Forge (`74,43 %` líneas) incluye `script/` (0 %) y `test/benchmarks/`,
> fuera del alcance de RNF-002. Sobre `src/` el agregado queda en 96,00 % de líneas.

### 8.4 Verificaciones del ciclo

| Verificación | Resultado |
|---|---|
| `forge build` | 0 errores |
| `forge test` | 243/243, 0 fallos |
| `forge coverage --report summary` | 3 registries al 100 % (≥ 80 %) |
| `forge fmt --check` | limpio |
| `forge snapshot` + `forge snapshot --check` | regenerado (`.gas-snapshot`, 242 entradas) y OK |
| `git status --short` | sólo `sc/test/*.t.sol` nuevos y `sc/.gas-snapshot`; **ningún archivo de `sc/src/`** |

### 8.5 Hallazgos (no corregidos: prohibido tocar `src/` en este ciclo)

1. `src/IdentityRegistry.sol:38` y `:56` — no se verifica que `_identity` sea un contrato:
   puede registrarse una EOA o un contrato sin la interfaz esperada (fallará al usarse).
2. `src/IdentityRegistry.sol:73-79` — `removeIdentity` localiza la entrada en
   `registeredAddresses` por búsqueda lineal y no comprueba que realmente exista; si el
   array y el mapping `registered` se desincronizaran, emitiría el evento sin borrar la
   entrada (hueco fantasma). Hoy es inalcanzable porque `registered` es la única puerta.
3. `src/ClaimTopicsRegistry.sol:29-35` — `addClaimTopic` no rechaza el topic `0`
   (documentado con `test_AddClaimTopic_AcceptsZeroValue`).
4. Los borrados con swap-and-pop (`IdentityRegistry`, `TrustedIssuersRegistry`,
   `ClaimTopicsRegistry`) son O(n) y **alteran el orden** de los arrays; en registries
   grandes el bucle podría agotar el gas del bloque.

---

## 9. Ciclo 2 — RF-001 · Verificación criptográfica del claim con EIP-712

> Fecha: 2026-10-10 · Rama `rwa-sc-DSH-GCP` (commit local, sin push).
> Objetivo: cerrar H-01 (crítica, claims auto-forjados) exigiendo firma EIP-712 del `issuer`
> en `IdentityCloneable.addClaim`, con `expiresAt` firmado (D-020), política de reintento D-018
> y alcance de autorización D-025.

### 9.1 Tests — antes / después

| Métrica | Antes (Ciclo 1b) | Después (Ciclo 2) |
|---|---|---|
| Tests ejecutados/pasados | **243 / 243** | **264 / 264** |
| Fallidos | 0 | **0** |
| Suites | 11 | **12** |
| Suites que revierten en `setUp` | 0 | **0** |
| Tests `test_RF001_*` nuevos | 0 | **21** (`test/IdentityCloneable.t.sol`) |

Comando: `forge test` → `Ran 12 test suites ... 264 tests passed, 0 failed, 0 skipped (264 total tests)`.
La suite nueva no sustituye ninguna prueba existente: las 243 anteriores se conservan y solo se
adaptaron a la nueva firma de `addClaim`/`createIdentityWithClaim` (conservando su intención).

### 9.2 Cobertura — antes / después (`src/`, D-017)

Comando: `forge coverage --report summary`. Valores medidos sobre `src/` (interfaces excluidas
automáticamente por Forge al no tener código ejecutable):

| Métrica | Antes (Ciclo 1b) | Después (Ciclo 2) |
|---|---|---|
| Líneas | 96,00 % (576/600) | **96,08 %** (589/613) |
| Sentencias | 95,70 % (534/558) | **95,99 %** (550/573) |
| Ramas | 81,77 % (148/181) | **82,72 %** (158/191) |
| Funciones | 96,21 % (127/132) | **96,27 %** (129/134) |

`IdentityCloneable` (el contrato modificado) se mantiene alto:

| Métrica | Antes | Después |
|---|---|---|
| Líneas | 100,00 % (33/33) | **100,00 %** (46/46) |
| Sentencias | 96,43 % (27/28) | **97,67 %** (42/43) |
| Ramas | 100,00 % (3/3) | **100,00 %** (13/13) |
| Funciones | 100,00 % (7/7) | **100,00 %** (9/9) |

Ninguna métrica de `src/` baja. El total que imprime Forge (75,03 % líneas) incluye `script/` (0 %)
y `test/`, fuera del alcance de RNF-002 (D-017).

### 9.3 Diseño aplicado

- **Dominio EIP-712 (D-020):** `{name: "RWA-Identity", version: "1", chainId, verifyingContract: address(this)}`;
  en clones EIP-1167 `verifyingContract` es la **dirección del clon**. El `chainId` se lee en cada
  llamada, de modo que la firma deja de valer en otra cadena.
- **`CLAIM_TYPEHASH`:** `keccak256("Claim(address walletOwner,uint256 topic,uint256 scheme,bytes32 dataHash,uint256 expiresAt)")`.
- **Validaciones en `addClaim`:** `scheme == 1`, `signature.length == 65`, `issuer != address(0)`,
  `dataHash == keccak256(data)` (implícito en el digest), `recovered == issuer` y
  `walletOwner` firmado `== owner()` (anti-replay entre titulares). `expiresAt` queda **firmado y
  almacenado**; su enforcement es del Ciclo 8/RF-013.
- **Recuperación:** `ECDSA.tryRecover` de OpenZeppelin 5.5.0 (rechaza `s` alto y `v ∉ {27,28}`); los
  fallos se mapean a los literales de RF-001 sin debilitar la comprobación. Hay un test específico de
  firma maleable (`test_RF001_addClaim_firma_maleable_s_alto_revierte`).
- **EIP-712 sin `EIP712Upgradeable` (D-026):** OpenZeppelin v5.5.0 declara `pragma solidity ^0.8.24`
  en `EIP712Upgradeable.sol`, incompatible con el `solc_version = 0.8.20` fijado por RF-005/RT-007.
  Se reproduce el mismo digest (`\x19\x01 || domainSeparator || structHash`) con los typehashes de la
  EIP y se documenta en NatSpec; `ECDSA` sí se usa de OpenZeppelin.
- **Reintento (D-018):** un claim existente para el mismo `(topic, issuer)` se **sobrescribe solo con
  firma válida**; el issuer no se duplica en `topicIssuers`.
- **Alcance (D-025):** `addClaim` **no** comprueba la autorización del issuer para el topic; lo impone
  `TokenCloneable.isVerified` contra el `TrustedIssuersRegistry` del token. Cubierto por
  `test_RF001_issuer_no_autorizado_para_topic_no_verifica` y documentado en NatSpec.
- **`createIdentityWithClaim` (D-027):** propaga `expiresAt`; como el clon se inicializa con la factory
  como owner temporal, en esa ruta el `walletOwner` firmado es la factory y el anti-replay entre
  identidades lo aporta `verifyingContract`.

### 9.4 ABI y documentación

- Cambios de ABI (firma, struct, evento y selectores) en
  [`../rwa-sc/CHANGELOG_ABIS.md`](../rwa-sc/CHANGELOG_ABIS.md), con el impacto en `rwa-web`.
- Decisiones nuevas registradas: **D-026, D-027 y D-028** (`requerimientos.md`, Bloque 6).

### 9.5 Verificaciones del ciclo

| Verificación | Resultado |
|---|---|
| `forge build` | 0 errores (solo warnings del linter preexistentes) |
| `forge test` | 264/264, 0 fallos, 0 suites revertidas en `setUp` |
| PoC H-01 invertido | `test_RF001_addClaim_firma_vacia_revierte`; PoC aislado con `test_H01_claim_forjado_firma_vacia_revierte` |
| `forge coverage --report summary` | `src/` 96,08 % líneas; `IdentityCloneable` 100 % líneas |
| `forge fmt --check` | limpio |
| `forge snapshot` + `forge snapshot --check` | regenerado (`.gas-snapshot`) y OK |
| `git status --short` | limpio tras el commit (solo árbol `rwa-sc/`) |

### 9.6 Evidencia del PoC invertido

`RepoTecnico/evidencias/PoC_H01_H05.t.sol` se actualizó: el caso de H-01 ahora **revierte** con
firma vacía y el caso positivo exige firma EIP-712; H-05 sigue reproduciéndose (pendiente de RF-011).
Salida real en `RepoTecnico/evidencias/salida_poc.txt`:

```
[PASS] test_H01_claim_forjado_firma_vacia_revierte
[PASS] test_H01_claim_con_firma_valida_aceptado
[PASS] test_H05_isVerified_fail_open
```


## 10. Ciclo 3 — RF-002 · Retirada del flag de bypass y anti-reentrancia

> Fecha: 2026-10-10 · Rama `rwa-sc-DSH-GCP` (commit local, sin push).
> Objetivo: cerrar H-18 (callbacks externos sin `ReentrancyGuard`) y H-03 eliminando el flag mutable
> `bypassCompliance`, sustituyéndolo por la ruta interna explícita `_forcedUpdate` y protegiendo con
> `nonReentrant` el token y el `ComplianceAggregator`. Alcance: **sin** whitelist ni topes (RF-004/Ciclo 5).

### 10.1 Tests — antes / después

| Métrica | Antes (Ciclo 2) | Después (Ciclo 3) |
|---|---|---|
| Tests ejecutados/pasados | **264 / 264** | **281 / 281** |
| Fallidos | 0 | **0** |
| Suites | 12 | **13** (`+ test/TokenReentrancy.t.sol`) |
| Suites que revierten en `setUp` | 0 | **0** |
| Tests `test_RF002_*` nuevos | 0 | **17** |

Comando: `forge test` → `Ran 13 test suites ... 281 tests passed, 0 failed, 0 skipped (281 total tests)`.
No se debilitó ni borró ningún test: los 264 anteriores se conservan íntegros, sin `vm.skip`, sin
aserciones comentadas y sin casos eliminados.

### 10.2 Cobertura — antes / después (`src/`, D-017)

Comando: `forge coverage --report summary`. Valores medidos sobre `src/` (mismas 13 filas; las
interfaces no tienen código ejecutable):

| Métrica | Antes (Ciclo 2) | Después (Ciclo 3) |
|---|---|---|
| Líneas | 96,08 % (589/613) | **96,28 %** (595/618) |
| Sentencias | 95,99 % (550/573) | **95,99 %** (550/573) |
| Ramas | 82,72 % (158/191) | **82,90 %** (160/193) |
| Funciones | 96,27 % (129/134) | **97,08 %** (133/137) |

Contratos modificados:

| Contrato | Líneas antes → después | Ramas antes → después | Funciones antes → después |
|---|---|---|---|
| `TokenCloneable` | 97,08 % (133/137) → **97,18 %** (138/142) | 66,67 % (34/51) → **67,92 %** (36/53) | 100 % → **100 %** (28/28) |
| `ComplianceAggregator` | 93,75 % (60/64) → **95,31 %** (61/64) | 100 % (16/16) → **100 %** (16/16) | 93,33 % (14/15) → **100 %** (15/15) |

**Ninguna métrica de `src/` baja.** El total que imprime Forge incluye `script/` y `test/` (fuera del
alcance de RNF-002, D-017).

### 10.3 Diseño aplicado (dónde vive el guard)

- **Flag eliminado:** `bool private bypassCompliance` (`:47`) **desaparece** del storage
  (`forge inspect TokenCloneable storage-layout --json` → `identityRegistry`, `trustedIssuersRegistry`,
  `claimTopicsRegistry`, `complianceModules`, `_tokenName`, `_tokenSymbol`, `_tokenDecimals`, `frozen`).
- **Ruta explícita:** `_forcedUpdate(from,to,amount)` ejecuta `super._update(...)` directamente (salta
  la comprobación de compliance y la notificación del override) y **no escribe ningún flag**. Solo la
  invoca `forcedTransfer`, que sigue siendo `onlyRole(AGENT_ROLE)` y notifica `transferred` una vez.
  Un `transfer()` reentrante durante esa notificación pasa por el `nonReentrant` del token y **no**
  existe ninguna ventana de bypass.
- **Guard (`ReentrancyGuard` stateless, D-029):** se aplica en **`transfer`, `transferFrom`, `mint`,
  `burn` y `forcedTransfer`**, no en `_update`. Razón (D-030): un guard en `_update` solo cubriría el
  callback `transferred`; los bucles `created` de `mint`, `destroyed` de `burn` y `transferred` de
  `forcedTransfer` ocurren **después** de `_update` y quedarían sin guardar; además, poner el guard en
  `_update` y en `mint`/`burn` haría saltar el revert por guard anidado. Guardar los puntos de entrada
  cubre todas las rutas sin anidamiento. `canTransfer` es `view` y no necesita guard.
- **Aggregator:** `addModule`, `removeModule`, `transferred`, `created` y `destroyed` son
  `nonReentrant` (guard propio, namespace distinto del token). `canTransfer` sigue `view`.
- **Semántica intacta:** `forcedTransfer` no consulta `canTransfer`; `mint` sigue exigiendo compliance
  y `burn` no la consulta (D-016). Los límites/whitelist llegan en RF-004.

### 10.4 Gas — antes / después

Medición directa (test `test_RF002_gas_transfer_estandar`, `-vv`) sobre el mismo setup:

| Operación | Antes (Ciclo 2) | Después (Ciclo 3) | Δ |
|---|---|---|---|
| `createToken` (clon EIP-1167 + `initialize`) | 381.570 | **381.570** | **0** (guard stateless, sin init) |
| `TokenBenchmark` (despliegue completo + init) | 859.098 | **882.257** | +23.159 |
| Transferencia estándar (guard frío) | 169.656 | **172.730** | +3.074 (+1,81 %) |
| Transferencia estándar (guard caliente) | 130.959 | **134.033** | +3.074 (+2,35 %) |
| `test_ForcedTransfer` | 475.749 | **497.736** | +21.987 |
| `test_Mint` | 258.090 | **280.444** | +22.354 |
| `test_Transfer_Success` (mint + transfer) | 528.232 | **550.860** | +22.628 |

El sobrecoste por transferencia es de **~3.074 gas** cuando el guard ya está en `NOT_ENTERED` (lo
normal tras el primer `mint`); la primera operación guarded de un token paga una única escritura fría.
`createToken` no cambia: el guard no añade init ni código al clon. El ahorro del benchmark pasa de
55,58 % a **56,75 %** (umbrales `>=45 %` y `>300k` intactos, D-032). `.gas-snapshot` regenerado
(17 entradas nuevas de `TokenReentrancyTest`, resto de deltas de gas por el guard).

### 10.5 Lint (`forge lint`)

| Regla | Antes (evidencia Ciclo 1) | Después (Ciclo 3) |
|---|---|---|
| `reentrancy-events` | 19 | **19** |
| `calls-loop` | 14 | **14** |
| `reentrancy-no-eth` | 5 | **4** |
| `non-reentrant-not-first` | 0 | **0** (se corrigió el orden de modificadores) |

`reentrancy-events` y `calls-loop` son preexistentes y estructurales (llamadas externas a los módulos
dentro de bucles); reducirlos exige un rediseño *pull* fuera del alcance de RF-002.

### 10.6 Gate de CI

`script/ci/check_no_bypass_flag.sh` (criterio `ci_check_RF002_no_bypassCompliance_storage`) inspecciona
`forge inspect TokenCloneable storage-layout --json` y **falla con exit 1** si aparece
`bypassCompliance`. Probado en ambos sentidos: con el flag inyectado temporalmente devuelve exit 1 y
lista la etiqueta; restaurado el código, imprime
`OK: TokenCloneable no expone 'bypassCompliance' en su storage layout` (exit 0). El test
`test_RF002_storage_layout_sin_bypassCompliance` añade la verificación en Solidity sobre el artefacto
compilado (`extra_output = ["storageLayout"]` en `foundry.toml`).

### 10.7 Evidencia de reentrancia (invertida respecto a H-18)

`test/TokenReentrancy.t.sol` usa `MaliciousComplianceModule`, que desde
`transferred`/`created`/`destroyed` reentra en el token (o en el aggregator) propagando el revert. Los
7 tests de reentrancia revierten con `ReentrancyGuardReentrantCall`
(`0x3ee5aeb5`):

```
[PASS] test_RF002_reentrancy_transfer_revierte
[PASS] test_RF002_reentrancy_transferFrom_revierte
[PASS] test_RF002_reentrancy_mint_revierte
[PASS] test_RF002_reentrancy_burn_revierte
[PASS] test_RF002_reentrancy_forcedTransfer_revierte
[PASS] test_RF002_reentrancy_aggregator_transferred_revierte
[PASS] test_RF002_reentrancy_aggregator_created_revierte
```

### 10.8 Verificaciones del ciclo

| Verificación | Resultado |
|---|---|
| `forge build` | 0 errores |
| `forge test` | 281/281, 0 fallos, 0 suites revertidas en `setUp` |
| `forge inspect TokenCloneable storage-layout` | sin `bypassCompliance` (8 campos) |
| `script/ci/check_no_bypass_flag.sh` | OK (exit 0); falla (exit 1) con el flag inyectado |
| Reentrancia | 7 tests revierten con `ReentrancyGuardReentrantCall` |
| `forge coverage --report summary` | `src/` 96,28 % líneas, 82,90 % ramas (sin bajar) |
| `forge fmt --check` | limpio |
| `forge snapshot` + `forge snapshot --check` | regenerado (`.gas-snapshot`) y OK |
| `git status --short` | limpio tras el commit local |

### 10.9 Decisiones y documentación

- Decisiones nuevas: **D-029** (guard stateless), **D-030** (ubicación del `nonReentrant`),
  **D-031** (`_forcedUpdate`, `from != address(0)`, gate y `extra_output`) y **D-032** (benchmark
  equivalente con guard) en `requerimientos.md` (Bloque 6).
- Fila de `TokenCloneable` en `documento_tecnico.md` §2.1 actualizada: patrón sin `bypassCompliance` y
  con `ReentrancyGuard`.

## 11. Ciclo 4 — RF-003 · Validación de módulos con ERC-165 (+ HB-13 / HB-15)

> Fecha: 2026-10-10 · Rama `rwa-sc-DSH-GCP` (commit local, sin push).
> Objetivo: que token y `ComplianceAggregator` rechacen módulos que no implementan `ICompliance`
> (HB-04/H-17), agrupando **HB-13** (la identidad registrada debe ser un contrato) y **HB-15**
> (rechazar el topic `0`). Alcance: sin whitelist ni topes (RF-004/Ciclo 5).

### 11.1 Tests — antes / después

| Métrica | Antes (Ciclo 3) | Después (Ciclo 4) |
|---|---|---|
| Tests ejecutados/pasados | **281 / 281** | **303 / 303** |
| Fallidos | 0 | **0** |
| Suites | 13 | **14** (`+ test/RF003_ERC165.t.sol`) |
| Suites que revierten en `setUp` | 0 | **0** |
| Tests `test_RF003_*` nuevos | 0 | **16** |
| Tests HB-13 nuevos | 0 | **4** |
| Tests HB-15 (2 nuevos + 1 invertido) | 0 | **3** |

Balance neto: **+22** (una función `test_HB15_*` sustituye a `test_AddClaimTopic_AcceptsZeroValue`).

Comando: `forge test` → `Ran 14 test suites ... 303 tests passed, 0 failed, 0 skipped (303 total tests)`.
No se debilitó ni borró ningún test: los 281 anteriores se conservan íntegros, sin `vm.skip`, sin
aserciones comentadas y sin casos eliminados. Los tres casos afectados por los nuevos invariantes se
**adaptan conservando la intención**:

- `test/ClaimTopicsRegistry.t.sol`: `test_AddClaimTopic_AcceptsZeroValue` →
  `test_HB15_AddClaimTopic_RevertWhen_ZeroValue` (mismo caso, aserción invertida a la nueva regla) y
  `testFuzz_ClaimTopicExists` se acota a topic `≥ 1`.
- `test/IdentityRegistry.t.sol`: las direcciones deterministas de identidad reciben código con
  `vm.etch(addr, hex"00")` (HB-13), incluida la ruta fuzz y el helper de alta masiva.
- `test/TokenReentrancy.t.sol`: los dobles `MaliciousComplianceModule` y `RejectingComplianceModule`
  implementan `supportsInterface` (ahora son conformes, como exige el token para darlos de alta).

### 11.2 Cobertura — antes / después (`src/`, D-017)

Comando: `forge coverage --report summary`. Valores medidos sobre las 13 filas de `src/` (las interfaces
`ICompliance`/`IClaimTopicsRegistry` no tienen código ejecutable y quedan excluidas por D-017):

| Métrica | Antes (Ciclo 3) | Después (Ciclo 4) |
|---|---|---|
| Líneas | 96,28 % (595/618) | **96,44 %** (623/646) |
| Sentencias | 95,99 % (550/573) | **96,27 %** (593/616) |
| Ramas | 82,90 % (160/193) | **84,62 %** (176/208) |
| Funciones | 97,08 % (133/137) | **97,22 %** (140/144) |

Contratos modificados:

| Contrato | Líneas antes → después | Ramas antes → después | Funciones |
|---|---|---|---|
| `TokenCloneable` | 97,18 % (138/142) → **97,39 %** (149/153) | 67,92 % (36/53) → **72,41 %** (42/58) | 100 % (30/30) |
| `ComplianceAggregator` | 95,31 % (61/64) → **95,77 %** (68/71) | 100 % (16/16) → **100 %** (18/18) | 100 % (17/17) |
| `IdentityRegistry` | 100 % → **100 %** (37/37) | 100 % (19/19) → **100 %** (21/21) | 100 % (8/8) |
| `ClaimTopicsRegistry` | 100 % → **100 %** (23/23) | 100 % → **100 %** (8/8) | 100 % (6/6) |
| `ClaimTopicsRegistryCloneable` | — | — | **92,31 %** (24/26) líneas / 75,00 % (6/8) ramas |

**Ninguna métrica de `src/` baja.** El total que imprime Forge incluye `script/` y `test/` (fuera del
alcance de RNF-002, D-017).

### 11.3 Diseño aplicado

- **Interfaz:** `ICompliance is IERC165` (`src/ICompliance.sol`). El `interfaceId` sigue siendo el XOR de
  los 4 selectores propios (`canTransfer`, `transferred`, `created`, `destroyed`); Solidity excluye
  `supportsInterface` por ser heredado (FD-03). Verificado por `test_RF003_interfaceId_ICompliance_correcto`.
- **Módulos:** los 3 módulos y el aggregator heredan `ERC165` e implementan `supportsInterface` con
  `interfaceId == type(ICompliance).interfaceId || super.supportsInterface(interfaceId)` (que cubre
  `type(IERC165).interfaceId`).
- **Validación:** helper privado `_implementsCompliance(address)` en `TokenCloneable` y en
  `ComplianceAggregator`; hace `staticcall` al selector `supportsInterface` con
  `type(ICompliance).interfaceId` y devuelve
  `success && data.length >= 32 && abi.decode(data, (bool))`. Un EOA (retorno vacío), un contrato sin la
  función (fallo de llamada) y un contrato que devuelve `false` se rechazan con
  `"Module does not implement ICompliance"`; el alta no escribe estado.
- **Duplicados:** `addComplianceModule` añade `"Module already added"` (D-034).
- **HB-13:** `registerIdentity` y `updateIdentity` exigen `_identity.code.length > 0` →
  `"Identity must be a contract"`.
- **HB-15:** `addClaimTopic` exige `_claimTopic != 0` → `"Invalid claim topic"` en ambas variantes.

### 11.4 Gas — antes / después

Medición directa de `.gas-snapshot` (los deltas viven solo en el alta de módulos; `transfer`/`mint` no
consultan ERC-165):

| Operación | Antes (Ciclo 3) | Después (Ciclo 4) | Δ |
|---|---|---|---|
| `TokenTest:test_AddComplianceModule` | 433.518 | **437.593** | +4.075 (+0,94 %) |
| `ComplianceAggregatorTest:test_AddModule` | 217.348 | **221.262** | +3.914 |
| `ComplianceAggregatorTest:test_AddMultipleModules` | 484.830 | **496.530** | +11.700 (3 altas) |
| `ComplianceAggregatorTest:test_TokenCanAddModuleThroughAggregator` | 350.665 | **358.677** | +8.012 |
| `TokenTest:test_Mint` | 280.444 | **280.499** | +55 (+0,02 %) |
| `TokenTest:test_Transfer_Success` | 550.860 | **550.948** | +88 (+0,02 %) |
| Constructores de los 3 módulos | — | — | ±70 (ERC-165 añade ~decenas de bytes de runtime) |

El sobrecoste del alta es el `staticcall` ERC-165 (acceso en frío al módulo + retorno) más el barrido de
duplicados; las rutas de transferencia no cambian. `.gas-snapshot` regenerado (302 entradas, 16 nuevas de
`RF003_ERC165Test`) y `forge snapshot --check` OK.

### 11.5 Verificaciones del ciclo

| Verificación | Resultado |
|---|---|
| `forge build` | 0 errores |
| `forge test` | **303/303**, 0 fallos, 0 suites revertidas en `setUp` |
| RF-003 · EOA rechazada | `test_RF003_addComplianceModule_revierte_eoa` y `test_RF003_aggregator_addModule_revierte_eoa` → `"Module does not implement ICompliance"` |
| RF-003 · contrato sin interfaz rechazado | `test_RF003_addComplianceModule_revierte_contrato_sin_interfaz` y `test_RF003_aggregator_addModule_revierte_contrato_sin_interfaz` |
| RF-003 · ERC-165 ajeno rechazado | `test_RF003_addComplianceModule_revierte_erc165_ajeno` |
| HB-13 · EOA rechazada | `test_HB13_RegisterIdentity_RevertWhen_Eoa` y `test_HB13_UpdateIdentity_RevertWhen_Eoa` → `"Identity must be a contract"` |
| HB-15 · topic 0 rechazado | `test_HB15_AddClaimTopic_RevertWhen_ZeroValue` y `test_HB15_Cloneable_AddClaimTopic_RevertWhen_ZeroValue` → `"Invalid claim topic"` |
| `addModuleThroughAggregator` | `test_RF003_addModuleThroughAggregator_ok` (alta) y `..._revierte_modulo_no_conforme` |
| `forge coverage --report summary` | `src/` **96,44 %** líneas / **84,62 %** ramas (sin bajar) |
| `forge fmt --check` | limpio |
| `forge snapshot` + `forge snapshot --check` | regenerado y OK |
| `git status --short` | limpio tras el commit local |

### 11.6 Decisiones y documentación

- Decisiones nuevas: **D-033** (validación ERC-165), **D-034** (duplicados en el token), **D-035**
  (HB-13), **D-036** (HB-15) y **D-037** (impacto/redeploy limpio por D-019) en `requerimientos.md`
  (Bloque 6).
- `documento_tecnico.md`: fila de `ICompliance` en §2.1 y fila de §3.1 (marcada como implementada),
  además del hallazgo de ausencia de ERC-165.
- `CHANGELOG_ABIS.md`: nueva entrada del Ciclo 4 (adición de `supportsInterface`; no rompe llamadas pero
  obliga a que los módulos de terceros lo implementen).




## 12. Ciclo 5 — RF-004: whitelist de destinos, límites y tope de suministro

| Métrica | Antes (Ciclo 4) | Después (Ciclo 5) |
|---|---|---|
| Tests | 303 | **320** (+17) |
| Fallos | 0 | 0 |
| Cobertura `src/` (líneas) | 96,44 % | **96,43 %** (622/645) |
| `src/TokenCloneable.sol` | 97,08 % | **97,71 %** (171/175) |
| Contrato con menos cobertura de `src/` | ~91 % | 91,53 % (`ClaimTopicsRegistryCloneFactory`) |

**Cambios:** `authorizedDestinations` (whitelist fail-closed), `maxBurnPerTx`, `maxForcedPerTx` y `maxSupply`,
con setters (`setAuthorizedDestination`, `setMaxBurnPerTx`, `setMaxForcedPerTx`, `setMaxSupply`) y eventos
`DestinationAuthorized`/`LimitsUpdated`/`MaxSupplyUpdated`. `burn` queda acotado por `maxBurnPerTx`
(**0 = operación desactivada**, CU-06 A6.5), `forcedTransfer` exige destino autorizado y `amount <= maxForcedPerTx`
(0 = desactivado), y `mint` respeta `maxSupply` (0 = sin tope).

**Suites:** nueva `test/TokenLimits.t.sol` (17 tests, criterios `test_RF004_*` de CU-06); adaptadas `Token.t.sol`
y `TokenReentrancy.t.sol` para autorizar los destinos usados y levantar los topes, conservando su semántica.

**Hallazgo del ciclo (mejora de reproducibilidad):** `forge snapshot --check` fallaba por el **fuzz no
determinista** (3 diffs en tests `testFuzz_*`, exit 1). Se fijó `[fuzz] seed = "0x525741"` en `foundry.toml`;
ahora `forge snapshot --check --tolerance 5` pasa de forma **estable** (dos ejecuciones consecutivas, 0 diffs),
lo que hace viable el gate de gas de la CI (D-039) sobre **todas** las pruebas y refuerza B-5.

**Decisiones:** D-038 (vigencia `expiresAt == 0` = sin caducidad), D-039 (gate de gas 5 %), D-040 (despliegue
sobre Anvil de GCP, Besu como alternativa), D-041 (datos off-chain diferidos), D-042 (gate de cobertura
agregado + por contrato).

## 13. Ciclo 6 — RF-011: `isVerified` fail-closed

| Métrica | Antes (Ciclo 5) | Después (Ciclo 6) |
|---|---|---|
| Tests | 320 | **326** (+6) |
| Fallos | 0 | 0 |
| `src/TokenCloneable.sol` (líneas) | 97,71 % | 97,71 % |
| Gate de gas (`--check --tolerance 5`) | OK | OK (determinista) |

**Cambio:** `isVerified` devuelve `false` cuando `claimTopicsRegistry == address(0)` o cuando el conjunto de
topics requeridos está vacío (antes devolvía `true`: fail-open H-05). Un token recién creado por factory ya no
verifica a nadie y `mint`/`transfer` quedan bloqueados hasta configurar la política; al configurarla, la
verificación vuelve a `true` (no hay bloqueo permanente).

**Suites:** nueva `test/RF011_FailClosed.t.sol` (6 tests `test_RF011_*` de CU-15). Evidencia actualizada:
`evidencias/PoC_H01_H05.t.sol` invierte el PoC de H-05 (`test_H05_isVerified_fail_closed_ok`) y **ambos**
hallazgos (H-01 y H-05) quedan verificados como corregidos.

## 14. Ciclo 7 — RF-012: `ComplianceAggregator` fail-closed y gestión solo por el token

| Métrica | Antes (Ciclo 6) | Después (Ciclo 7) |
|---|---|---|
| Tests | 326 | **334** (+8) |
| Fallos | 0 | **0** |
| Suites | 16 | **17** (`+ test/RF012_AggregatorFailClosed.t.sol`) |
| Suites revertidas en `setUp` | 0 | **0** |
| Tests `test_RF012_*` nuevos | 0 | **8** (7 criterios CU-16 + aislamiento cross-token) |
| Entradas de `.gas-snapshot` | 325 | **333** (+8) |
| Gate de gas (`--check --tolerance 5`) | OK | **OK** (determinista, exit 0) |

**Cambio en `src/` (pre-existente al ciclo, no retocado en esta tarea):** el modifier `onlyOwnerOrToken`
(`"Only owner or token can call"`) pasa a **`onlyToken`** (`"Only token admin can call"`), de modo que
`addModule`/`removeModule` solo aceptan al propio token; y `canTransfer` pasa a **fail-closed**: devuelve
`false` si el token no está registrado (`_isTokenRegistered[token] == false`) o no tiene módulos (antes, cero
módulos = permitir: fail-open H-22). La ruta de producción es
`TokenCloneable.addComplianceModule(address(aggregator))` una vez + `addModuleThroughAggregator` /
`removeModuleThroughAggregator` (requiere `COMPLIANCE_ROLE` y el aggregator ya dado de alta como módulo del
token).

### 14.1 Suites adaptadas (antes / después)

Los 35 puntos de llamada directos a `aggregator.addModule`/`removeModule` de las 3 suites se reencaminan a la
ruta de producción; **31** se convierten en llamadas vía token y **4** se conservan directas porque son
**negativas a propósito** (`"Only token admin can call"`). No se borró, debilitó ni `vm.skip`ó ningún test.

| Suite | Puntos directos | Adaptación |
|---|---|---|
| `test/ComplianceAggregator.t.sol` | 29 | 25 vía token; 4 negativos (no owner / dirección cero / modelo nuevo) |
| `test/RF003_ERC165.t.sol` | 4 | 4 vía token (el aggregator conserva la validación ERC-165 y el token el rechazo de módulo cero) |
| `test/TokenReentrancy.t.sol` | 2 | 2 vía token (el guard del aggregator se dispara igual) |

Dos tests se renombran para reflejar la semántica nueva, conservando su montaje:

- `test_NoModules_AllowsAll` → **`test_NoModules_FailClosed`** (antes acuñaba `MAX_BALANCE * 100`; ahora el
  mint revierte `"Mint not compliant"` y el balance queda a 0).
- `test_TokenAndOwnerCanBothManageModules` → **`test_TokenCanManageModules_OwnerCannot`** (el token sí añade
  por su ruta; el owner global del aggregator revierte `"Only token admin can call"`).
- `test_DynamicModuleAddition`: el estado inicial sin módulos ahora bloquea (fail-closed); se añade un módulo
  holgado que permite acuñar `MAX_BALANCE * 2`, y después un módulo estricto que vuelve a bloquear, conservando
  la aserción `balanceOf(user1) == MAX_BALANCE * 2`.
- `test_RevertWhen_InvalidModuleAddress`: se enruta por el token (que conserva `"Invalid module address"`).
- `test_RevertWhen_InvalidTokenAddress`: con `onlyToken`, `token == address(0)` se rechaza por autorización
  antes de la comprobación de dirección; se asevera `"Only token admin can call"` y que no se registra nada
  (ver D-043).

### 14.2 Cobertura — antes / después (`src/`, D-017)

Comando: `forge coverage --report summary`. Agregado sobre los **13 contratos de `src/` con código ejecutable**
(las interfaces `ICompliance`/`IClaimTopicsRegistry` quedan excluidas por D-017):

| Métrica | Antes (Ciclo 4/6) | Después (Ciclo 7) |
|---|---|---|
| Líneas | 96,44 % (623/646) | **97,01 %** (650/670) |
| Sentencias | 96,27 % | **97,02 %** (619/638) |
| Ramas | 84,62 % | **85,53 %** (195/228) |
| Funciones | 97,22 % | **97,30 %** (144/148) |

| Contrato | Líneas antes → después | Ramas antes → después |
|---|---|---|
| `TokenCloneable` | 99,44 % (176/177) → **99,44 %** (176/177) | 80,77 % (63/78) → **80,77 %** (63/78) |
| `ComplianceAggregator` | 95,77 % (68/71) → **95,77 %** (68/71) | 100 % (18/18) → **88,89 %** (16/18) |

**Ninguna métrica agregada de `src/` baja** y `TokenCloneable` (99,44 %) se mantiene. La única bajada es la
**cobertura de ramas** de `ComplianceAggregator` (100 % → 88,89 %): son las dos ramas de los `require` de
dirección cero que `onlyToken` vuelve inalcanzables desde llamadores externos (D-043). Sigue por encima del
mínimo por contrato del 80 % (D-042).

### 14.3 Gas — antes / después

Medición de `.gas-snapshot` (el sobrecoste de los tests de gestión es **de setup**: ahora cada uno registra el
aggregator como módulo del token con `addComplianceModule` + `addModuleThroughAggregator`, dos llamadas
externas con `onlyRole` y validación ERC-165, en lugar de una llamada directa):

| Test | Antes | Después | Δ |
|---|---|---|---|
| `ComplianceAggregatorTest:test_AddModule` | 221.262 | **309.504** | +88.242 |
| `ComplianceAggregatorTest:test_AddMultipleModules` | 496.530 | **606.603** | +110.073 |
| `ComplianceAggregatorTest:test_RemoveModule` | 413.805 | **518.090** | +104.285 |
| `ComplianceAggregatorTest:test_TokenCanAddModuleThroughAggregator` | 358.662 | **356.511** | −2.151 |
| `ComplianceAggregatorTest:test_MaxBalance_WithAggregator` | 628.813 | **641.720** | +12.907 |
| `TokenReentrancyTest:test_RF002_reentrancy_aggregator_transferred_revierte` | 2.570.992 | **2.575.539** | +4.547 |

El gas de **producción** de `addModule`/`removeModule` no cambia (mismo cuerpo; solo cambia el `require` de
autorización) y el de `canTransfer` solo añade la lectura de `_isTokenRegistered`. `.gas-snapshot` regenerado
(333 entradas, 8 nuevas de `RF012_AggregatorFailClosedTest`) y `forge snapshot --check --tolerance 5` OK.

### 14.4 Verificaciones del ciclo

| Verificación | Resultado |
|---|---|
| `forge build` | 0 errores |
| `forge test` | **334/334**, 0 fallos, 0 suites revertidas en `setUp` |
| Fail-closed sin módulos | `test_RF012_aggregator_sin_modulos_revierte_transfer` y `test_RF012_aggregator_failclosed_por_defecto` → `canTransfer == false`; transfer revierte `"Transfer not compliant"` |
| Token no registrado | `test_RF012_aggregator_token_no_registrado_false` |
| Ruta del token | `test_RF012_aggregator_admin_del_token_ok` (`isModuleActiveForToken == true`, `getModuleCount == 1`) |
| Rechazo del owner global | `test_RF012_aggregator_owner_global_token_ajeno_revierte` → `"Only token admin can call"` |
| Aislamiento cross-token | `test_RF012_aggregator_aislamiento_cross_token` (un token no altera módulos de otro) |
| Registro automático (D-023) | `test_RF012_aggregator_registro_automatico_token` (`TokenRegistered` + `isTokenRegistered == true`) |
| Todos los módulos deben aprobar | `test_RF012_aggregator_modulos_todos_true_ok` |
| `forge coverage --report summary` | `src/` **97,01 %** líneas / **85,53 %** ramas (sin bajar el agregado) |
| `forge fmt --check` | limpio |
| `forge snapshot --check --tolerance 5` | OK (exit 0) |
| `git status --short` | limpio tras el commit local |

### 14.5 Decisiones y documentación

- Decisiones nuevas: **D-043** (`require` de dirección cero inalcanzables con `onlyToken`; se conservan como
  defensa en profundidad) y **D-044** (adaptación de las 3 suites a la ruta de producción, con los dos
  renombrados de tests) en `requerimientos.md` (Bloque 6).
- `documento_tecnico.md`: fila `| RF-012 |` de la tabla de estado → **IMPLEMENTADO (Ciclo 7)** con el modifier
  `onlyToken`; fila `| H-22 (auditoría V1) |` de la tabla de hallazgos → **IMPLEMENTADO (Ciclo 7)**. El resto
  del documento no se reescribe; quedan pendientes de una futura revisión editorial las citas de
  `onlyOwnerOrToken` en §2.1 y en los anclajes de código (líneas 129 y 524), ajenas a las dos tablas pedidas.
- ABI: **sin cambios de firma**. `ComplianceAggregator` no añade ni retira funciones/vistas/eventos; el cambio
  es de comportamiento (autorización y fail-closed). `TokenCloneable` mantiene su ABI (la ruta
  `addModuleThroughAggregator` ya existía).

## 15. Ciclo 8 — RF-013: vigencia y revocación de claims por el issuer (+ HB-14)

| Métrica | Antes (Ciclo 7) | Después (Ciclo 8) |
|---|---|---|
| Tests | 334 | **348** (+14) |
| Fallos | 0 | **0** |
| Suites | 17 | **18** (`+ test/RF013_ClaimLifecycle.t.sol`) |
| Suites revertidas en `setUp` | 0 | **0** |
| Tests `test_RF013_*` nuevos | 0 | **11** (6 Gherkin + 3 EARS + 2 de apoyo) |
| Tests HB-14 nuevos | 0 | **3** (1 éxito + 2 revert) |
| Entradas de `.gas-snapshot` | 333 | **347** (+14) |
| Gate de gas (`--check --tolerance 5`) | OK | **OK** (exit 0, 0 diffs) |

**Cambio en `src/`:**

- `IdentityCloneable`: el struct `Claim` gana `bool revoked` (al final); `addClaim` resetea `revoked = false`
  al renovar con firma válida; nueva `revokeClaim(uint256,address)` (sin `onlyOwner`, exige
  `msg.sender == _issuer` y que el claim exista) que marca `revoked = true` y emite
  `ClaimRevoked(topic, issuer)` **sin borrar** `data`/`uri`/`signature`; nueva vista
  `hasValidClaim(uint256,address)`; `getClaim` pasa a devolver **8** campos (añade `revoked`).
- `TokenCloneable.isVerified`: además de `trustedIssuersRegistry.hasClaimTopic(...)`, exige
  `hasValidClaim(topic, issuer)` en el clon de identidad por `staticcall`; un fallo de la llamada (o
  retorno mal formado) se trata como **no válido** (fail-closed, RF-011).
- `IdentityRegistry.removeIdentity` (**HB-14**): comprueba explícitamente que el wallet figure en
  `registeredAddresses` y revierte `"Wallet not in registered addresses"` si no; conserva *swap-and-pop*
  y `IdentityRemoved`.

**Semántica de vigencia (D-038 confirmada):** `expiresAt == 0` = **sin caducidad** (perpetuo);
con `expiresAt > 0`, el claim es válido mientras `block.timestamp < expiresAt` (en el límite exacto ya
vence). `hasValidClaim` es la única fuente de verdad y la que consulta `isVerified`.

### 15.1 Cobertura — antes / después (`src/`, D-017)

Comando: `forge coverage --report summary`. Agregado sobre los **13 contratos de `src/` con código
ejecutable** (interfaces `ICompliance`/`IClaimTopicsRegistry` excluidas):

| Métrica | Antes (Ciclo 7) | Después (Ciclo 8) |
|---|---|---|
| Líneas | 97,01 % (650/670) | **97,11 %** (671/691) |
| Sentencias | 97,02 % (619/638) | **97,13 %** (642/661) |
| Ramas | 85,53 % (195/228) | **86,13 %** (205/238) |
| Funciones | 97,30 % (144/148) | **97,33 %** (146/150) |

| Contrato | Líneas antes → después | Ramas antes → después |
|---|---|---|
| `TokenCloneable` | 99,44 % (176/177) → **99,45 %** (180/181) | 80,77 % (63/78) → **81,01 %** (64/79) |
| `IdentityCloneable` | 100 % → **100 %** (60/60) | — → **98,18 %** (54/55) |
| `IdentityRegistry` | 100 % → **100 %** (40/40) | 100 % → **100 %** (23/23) |

**Ninguna métrica agregada de `src/` baja** y `IdentityCloneable` mantiene el 100 % de líneas. La única
rama no cubierta de `IdentityCloneable` (54/55) pertenece al cortocircuito de `hasValidClaim`; el
agregado y el mínimo por contrato (D-042) se cumplen con holgura.

### 15.2 Gas — referencias del ciclo

| Test | Gas |
|---|---|
| `RF013_ClaimLifecycleTest:test_RF013_claim_vigente_isVerified_true` | 581.828 |
| `RF013_ClaimLifecycleTest:test_RF013_claim_expirado_isVerified_false` | 1.323.226 |
| `RF013_ClaimLifecycleTest:test_RF013_claim_revocado_por_issuer_isVerified_false` | 703.121 |
| `RF013_ClaimLifecycleTest:test_RF013_revocar_solo_issuer_revierte` | 607.196 |
| `RF013_ClaimLifecycleTest:test_RF013_renovacion_actualiza_vigencia` | 772.877 |
| `RF013_ClaimLifecycleTest:test_RF013_claim_inexistente_revierte` | 124.931 |
| `IdentityRegistryTest:test_HB14_RemoveIdentity_Ok_CuandoPerteneceAlArray` | 490.128 |
| `IdentityRegistryTest:test_HB14_RemoveIdentity_RevertWhen_MappingYArrayDesincronizados` | 73.056 |

**Nota operativa (snapshot):** conviene **no** ejecutar `forge coverage` inmediatamente antes de
`forge snapshot`; la instrumentación de cobertura deja artefactos que alteran el gas medido en la primera
regeneración. Tras regenerar con artefactos normales, `forge snapshot` es determinista (dos ejecuciones
seguidas producen el mismo archivo) y `forge snapshot --check --tolerance 5` da **exit 0 con 0 diffs**.

### 15.3 Verificaciones del ciclo

| Verificación | Resultado |
|---|---|
| `forge build` | 0 errores |
| `forge test` | **348/348**, 0 fallos, 0 suites revertidas en `setUp` |
| Claim vigente → `isVerified` | `test_RF013_claim_vigente_isVerified_true` → `true` |
| Claim expirado → `isVerified` | `test_RF013_claim_expirado_isVerified_false` (con `vm.warp`) → `false`; transfer `"Transfer not compliant"` |
| Claim revocado → `isVerified` | `test_RF013_claim_revocado_por_issuer_isVerified_false` (`ClaimRevoked`, `revoked == true`) → `false` |
| Revocar sin ser issuer | `test_RF013_revocar_solo_issuer_revierte` → `"Only issuer can revoke"` |
| Renovación limpia `revoked` | `test_RF013_renovacion_actualiza_vigencia` (`expiresAt` nuevo, `revoked == false`) |
| Claim inexistente | `test_RF013_claim_inexistente_revierte` → `"Claim does not exist"` |
| EARS vencidos | `test_RF013_isVerified_rechaza_vencidos` (`block.timestamp >= expiresAt`) |
| EARS histórico | `test_RF013_revocacion_emite_evento_y_conserva_historico` |
| EARS no reactivable | `test_RF013_revocacion_no_reactivable_por_titular` |
| HB-14 éxito / revierte | `test_HB14_RemoveIdentity_Ok_CuandoPerteneceAlArray`, `test_HB14_RemoveIdentity_RevertWhen_MappingYArrayDesincronizados` (`vm.store`) y `..._ArraySinMapping` |
| `forge coverage --report summary` | `src/` **97,11 %** líneas / **86,13 %** ramas (agregado sin bajar) |
| `forge fmt --check` | limpio |
| `forge snapshot --check --tolerance 5` | OK (exit 0, 0 diffs; 347 entradas) |
| `git status --short` | limpio tras el commit local |

### 15.4 ABI y documentación

- Cambio de ABI **breaking** en `getClaim` (7 → 8 salidas, se añade `revoked`); API nueva aditiva
  `revokeClaim` (`0x512752e4`), `hasValidClaim` (`0x03658fd8`) y evento `ClaimRevoked` (topic0
  `0x2773a486…`). Documentado en `CHANGELOG_ABIS.md` (sección RF-013) con el impacto en `rwa-web`.
- Decisiones nuevas: **D-045..D-049** en `requerimientos.md` (Bloque 6).
- `documento_tecnico.md`: filas `RF-013` y `H-08 (auditoría V1)` → **IMPLEMENTADO (Ciclo 8)**, y fila
  `IdentityCloneable` / struct `Claim` de §3.1 actualizada a implementado.

## 16. Ciclo 8c — RF-013: nonce firmado anti-replay en la revocación de claims

**Objetivo:** cerrar el bypass detectado en el Ciclo 8 (D-046): tras `revokeClaim`, la firma EIP-712
original seguía verificando y el titular podía reactivar el claim reintroduciéndola. El `nonce` entra en el
digest firmado y `revokeClaim` lo incrementa.

| Métrica | Antes (Ciclo 8) | Después (Ciclo 8c) |
|---|---|---|
| Tests | 348 | **353** (+5) |
| Fallos | 0 | **0** |
| Suites | 18 | **18** (sin suite nueva: los 5 casos se añaden a `RF013_ClaimLifecycle.t.sol`) |
| Suites revertidas en `setUp` | 0 | **0** |
| Tests `RF013_*` | 11 | **16** (+5 del cierre anti-replay) |
| Entradas de `.gas-snapshot` | 347 | **352** (+5) |
| Gate de gas (`--check --tolerance 5`) | OK | **OK** (exit 0, 0 diffs) |

**Cambio en `src/` (`IdentityCloneable`):**

- Nuevo mapping público `claimNonce[topic][issuer]` (nonce por par, fuera del struct `Claim`).
- `CLAIM_TYPEHASH` gana `uint256 nonce` (valor `0x8f719673…`); `addClaim` construye el `structHash` con el
  nonce vigente y **no** lo incrementa (D-018 intacto); `revokeClaim` lo incrementa tras marcar
  `revoked = true`.
- `getClaim` sigue con **8** salidas; `hasValidClaim`, `claimExists` y `TokenCloneable.isVerified` no cambian
  de semántica.

### 16.1 Cobertura — antes / después (`src/`, D-017)

Comando: `forge coverage --report summary`. Agregado sobre los **13 contratos de `src/` con código
ejecutable**:

| Métrica | Antes (Ciclo 8) | Después (Ciclo 8c) |
|---|---|---|
| Líneas | 97,11 % (671/691) | **97,11 %** (673/693) |
| Sentencias | 97,13 % (642/661) | **97,14 %** (646/665) |
| Ramas | 86,13 % (205/238) | **86,13 %** (205/238) |
| Funciones | 97,33 % (146/150) | **97,33 %** (146/150) |

| Contrato | Líneas antes → después | Ramas antes → después |
|---|---|---|
| `IdentityCloneable` | 100 % (60/60) → **100 %** (62/62) | 98,18 % (54/55) → **98,31 %** (58/59) |
| `TokenCloneable` | 99,45 % (180/181) → **99,45 %** (180/181) | 81,01 % (64/79) → **81,01 %** (64/79) |

**Ninguna métrica agregada de `src/` baja** y `IdentityCloneable` mantiene el **100 %** de líneas.

### 16.2 Gas — referencias del ciclo

| Test | Gas |
|---|---|
| `RF013_ClaimLifecycleTest:test_RF013_revocacion_replay_firma_original_revierte` | 822.596 |
| `RF013_ClaimLifecycleTest:test_RF013_revocacion_incrementa_nonce` | 625.260 |
| `RF013_ClaimLifecycleTest:test_RF013_reactivacion_con_nonce_nuevo_ok` | 836.433 |
| `RF013_ClaimLifecycleTest:test_RF013_renovacion_sin_revocar_sigue_idempotente` | 633.061 |
| `RF013_ClaimLifecycleTest:test_RF013_digest_incluye_nonce` | 578.554 |

**Nota operativa (snapshot):** se respetó la regla del Ciclo 8: tras `forge coverage` se hizo
`forge clean && forge build` (artefactos sin instrumentar) y **después** `forge snapshot`; el gate
`forge snapshot --check --tolerance 5` da **exit 0 con 0 diffs**.

### 16.3 Verificaciones del ciclo

| Verificación | Resultado |
|---|---|
| `forge build` | 0 errores |
| `forge test` | **353/353**, 0 fallos, 0 suites revertidas en `setUp` |
| Replay de la firma original | `test_RF013_revocacion_replay_firma_original_revierte` → `"Signature signer mismatch"` y el claim sigue revocado |
| Nonce se incrementa al revocar | `test_RF013_revocacion_incrementa_nonce` → 0 → 1 → 2 |
| Reactivación con firma nueva | `test_RF013_reactivacion_con_nonce_nuevo_ok` → `revoked == false`, `isVerified == true` |
| D-018 intacto | `test_RF013_renovacion_sin_revocar_sigue_idempotente` (misma firma, nonce 0, sin duplicar issuer) |
| Digest con nonce | `test_RF013_digest_incluye_nonce` (la firma con nonce 0 no vale cuando el nonce es 1) |
| `forge coverage --report summary` | `src/` **97,11 %** líneas / **86,13 %** ramas; `IdentityCloneable` 100 % líneas |
| `forge fmt --check` | limpio |
| `forge snapshot --check --tolerance 5` | OK (exit 0, 0 diffs; 352 entradas) |
| `git status --short` | limpio tras el commit local |

### 16.4 ABI y documentación

- **Cambio crítico de firma off-chain:** `CLAIM_TYPEHASH` gana `uint256 nonce`; nueva vista aditiva
  `claimNonce(uint256,address)` (`0x8a2eff53`). `addClaim` (`0x16cd5ffe`), `revokeClaim` (`0x512752e4`) y
  `getClaim` (`0x48e6b5a3`) **no** cambian de selector ni de número de salidas. Documentado en
  `CHANGELOG_ABIS.md` (sección RF-013 · Ciclo 8c) con el impacto en `rwa-web`.
- Decisiones nuevas: **D-050..D-052** en `requerimientos.md` (Bloque 6).
- `documento_tecnico.md`: fila `IdentityCloneable`/RF-013 y diccionario de datos (fila `nonce`) actualizados;
  D-020 corregida con el `nonce`.

## 17. Ciclo 9 — RF-010: secretos fuera de los scripts y despliegue verificable

**Objetivo:** eliminar el material de claves de los scripts (H-28/HB-12), desplegar la pila completa
end-to-end (H-24) y verificar el resultado on-chain en lugar de por `grep` de logs (H-31), contra el **Anvil
de GCP** (D-040).

**Código nuevo (no toca `src/`):** `sc/script/DeployFullStack.s.sol` (script canónico Solidity),
`sc/script/deploy.sh` (orquestación, secretos y verificación), `deploy-besu.sh` (wrapper de compatibilidad),
`sc/foundry.toml` (`fs_permissions` de escritura limitada a `./deployments`) y
`sc/deployments/31337-20261010T162639Z.json` (artefacto versionable).

### 17.1 Tests — sin regresión

| Métrica | Antes (Ciclo 8c) | Después (Ciclo 9) |
|---|---|---|
| Tests | 353 | **353** |
| Fallos | 0 | **0** |
| `src/` | 97,11 % líneas / 86,13 % ramas | **sin cambios** (el ciclo no toca `src/`) |

Comandos: `forge build` (0 errores) y `forge test` → `353 tests passed, 0 failed, 0 skipped (353 total)`.

### 17.2 Despliegue real (Anvil de GCP, chain-id 31337, bloque 517)

Contratos desplegados y verificados con `cast code` (10/10) y `cast call`:

| Contrato | Dirección |
|---|---|
| IdentityRegistry | `0xF5b81Fe0B6F378f9E6A3fb6A6cD1921FCeA11799` |
| TrustedIssuersRegistry | `0x67baFF31318638F497f4c4894Cd73918563942c8` |
| TokenCloneFactory | `0x6533158b042775e2FdFeF3cA1a782EFDbB8EB9b1` |
| IdentityCloneFactory | `0x73C68f1f41e4890D06Ba3e71b9E9DfA555f1fb46` |
| ClaimTopicsRegistryCloneFactory | `0xD2D5e508C82EFc205cAFA4Ad969a4395Babce026` |
| ComplianceAggregator | `0x2b639Cc84e1Ad3aA92D4Ee7d2755A6ABEf300D72` |
| ClaimTopicsRegistry | `0xafAC6756b04A92C5C4a68cE3882b99531995eBBA` |
| Token (`RWA Demo Token` / `RWAD`) | `0x382F74873b3798BEca33Cf69623d0CF35dE0f369` |
| MaxBalanceCompliance (módulo del token) | `0xB468647B04bF657C9ee2de65252037d781eABafD` |
| Identity (clon de ejemplo registrado) | `0x47d480c84C1223D914D99872a2738bDE05F191e5` |

| Verificación | Resultado |
|---|---|
| `cast chain-id --rpc-url "$RPC_URL"` | `31337` (coincide con `CHAIN_ID`) |
| Aborto con `CHAIN_ID=999` | exit 1: `CHAIN_ID declarado (999) != chain-id real de la red (31337)`, sin artefacto ni tx |
| `cast code` != `0x` | **10/10** contratos con bytecode |
| `token.name()` | `RWA Demo Token` |
| `token.symbol()` | `RWAD` |
| `token.identityRegistry()` | `0xF5b81Fe0B6F378f9E6A3fb6A6cD1921FCeA11799` (== registry) |
| `token.trustedIssuersRegistry()` | `0x67baFF31318638F497f4c4894Cd73918563942c8` (== registry) |
| `token.claimTopicsRegistry()` | `0xafAC6756b04A92C5C4a68cE3882b99531995eBBA` (== registry) |
| `aggregator.getModuleCount(token)` | `1` |
| `aggregator.isModuleActiveForToken(token, modulo)` | `true` |
| `module.tokenContract()` | `0x382F74873b3798BEca33Cf69623d0CF35dE0f369` (== token) |
| Clave en `ps` (argv) | **NO** (firma por `--keystore` + `--password-file`) |
| Clave / `keys.json` en scripts | **0** coincidencias |
| Clave en `rwa-sc` | **0** coincidencias (redactada la clave por defecto de Anvil en `REFERENCIA_TECNICA.md`) |
| `git status --short` | limpio tras el commit local |

### 17.3 ABI y documentación

- **Sin cambios de ABI de `src/`**: el Ciclo 9 no modifica ningún contrato. `CHANGELOG_ABIS.md` registra el
  artefacto de despliegue (direcciones + ABIs) como referencia para consumidores.
- Decisiones nuevas: **D-054..D-057** en `requerimientos.md` (Bloque 6).
- `documento_tecnico.md`: fila `RF-010` → **IMPLEMENTADO (Ciclo 9)**, `HB-12`/`RNF-004` implementados y §6.6
  reescrita con el procedimiento y las direcciones; `entornos_globales.md` §7.2/§12; `estado_proyecto.md`
  (hito del Ciclo 9).

## 18. Ciclo 10 — RF-006: documentación veraz, `SECURITY.md` y control de deriva de ABIs

**Objetivo:** alinear la documentación con el código (H-15/H-16/H-23/H-33), publicar el rastro de seguridad
(`SECURITY.md`) y crear los gates que impiden la deriva de ABIs y de documentación (CU-12). **El ciclo no
toca `src/` ni `test/`.**

### 18.1 Tests — sin regresión

| Métrica | Antes (Ciclo 9) | Después (Ciclo 10) |
|---|---|---|
| Tests | 353 | **353** |
| Fallos | 0 | **0** |
| `src/` | 97,11 % líneas / 86,13 % ramas | **sin cambios** (el ciclo no toca `src/`) |

Comandos: `forge build` (0 errores; 2 warnings de lint de tests preexistentes), `forge test` →
`353 tests passed, 0 failed, 0 skipped (353 total)`, `forge fmt --check` → limpio.

### 18.2 Artefactos nuevos

| Artefacto | Contenido |
|---|---|
| `rwa-sc/SECURITY.md` | Modelo de amenazas (T1..T10), estado de los 34 hallazgos V1, HB-01..HB-12, controles con test, riesgos residuales y política de reporte |
| `rwa-sc/sc/abis/<Contrato>.json` | Línea base de **15 ABIs** (una por contrato de `src/` y `src/compliance/`, incluidas interfaces) |
| `rwa-sc/sc/script/ci/abi_diff.sh` | Compara `forge inspect <C> abi --json` con `sc/abis/<C>.json`; falla ante selectores/firmas no declarados en `CHANGELOG_ABIS.md`; `--update` regenera la línea base |
| `rwa-sc/sc/script/ci/check_docs.sh` | Falla ante referencias a archivos inexistentes (H-15), falta de `SECURITY.md`/`CHANGELOG_ABIS.md`, afirmaciones prohibidas sin matizar, HB-01..HB-12 sin cubrir o placeholders |

### 18.3 Cifras corregidas en los documentos raíz

| Afirmación previa | Cifra publicada ahora | Respaldo |
|---|---|---|
| "139 tests (100 % passing)" | **353 tests, 353 pasan** | `forge test` (esta sección) |
| "coverage > 80 %" | `src/` **97,11 % líneas / 86,13 % ramas** | D-017; §16.3 |
| "ahorro de gas 88–98 %" | **45–59 %** (Token 55 %, Identity 59 %, Identity+claim 45 %, Registry 53 %) | `README.md` §Gas; §7.3 |
| "production-ready" / "ERC-3643 compliant" | **retiradas**; declaración verificable de interfaces + "sin auditoría, no apto para producción con activos reales" | `SECURITY.md` §0; D-024 |

El documento `OPTIMIZACION_VERIFICACION.md` queda rotulado como **estimación no medida** (H-03) y su tabla
"Benchmarks" retirada.

### 18.4 Verificaciones del ciclo

| Verificación | Resultado |
|---|---|
| `forge build` | 0 errores |
| `forge test` | **353/353**, 0 fallos |
| `forge fmt --check` | limpio |
| `sc/script/ci/check_docs.sh` | **exit 0** (`12 documentos; sin referencias rotas, sin afirmaciones sin matizar`) |
| `sc/script/ci/check_docs.sh` (negativo, copia `/tmp`) | **exit 1** al insertar "139 tests" y "production-ready" sin matizar |
| `sc/script/ci/abi_diff.sh` | **exit 0** (`15 ABIs sin deriva`) |
| `sc/script/ci/abi_diff.sh` (negativo, copia `/tmp`) | **exit 1** al alterar `abis/TokenCloneable.json` (`mint`→`mintFake`): lista los selectores `0x40c10f19` / `0x08650c09` no declarados |
| `grep -rn "Token.sol\|Identity.sol\|TOKEN_CLONE_FACTORY\|COMPLIANCE_AGGREGATOR_FINAL\|COMPLIANCE_AGGREGATOR_V2\|DeployIdentityRegistry" rwa-sc/ --include='*.md' --include='*.sh' --include='*.sol'` | Sin coincidencias en documentos raíz, `src/` ni `sc/script/` (salvo el propio `sc/script/ci/check_docs.sh`, que define los patrones a prohibir); quedan las citas históricas de `RepoTecnico/` (permitidas: explican que no existen) y las de `sc/lib/` (submódulos de terceros) |
| `ls rwa-sc/SECURITY.md rwa-sc/sc/abis` | `SECURITY.md` presente; **15** ABIs de línea base |
| `git status --short` | limpio tras el commit local |

### 18.5 Documentación y decisiones

- `SECURITY.md` y `CHANGELOG_ABIS.md` enlazados desde `README.md`, `START_HERE.md`, `GUIA_ESTUDIANTE.md`,
  `ARQUITECTURA_FINAL.md`, `REFERENCIA_TECNICA.md`, `VERIFICACION_TRUSTED_ISSUER.md` y
  `OPTIMIZACION_VERIFICACION.md`.
- Decisiones nuevas: **D-058, D-059, D-060 y D-061** en `requerimientos.md` (Bloque 6).
- `documento_tecnico.md`: `RF-006` → **IMPLEMENTADO (Ciclo 10)**, filas de H-15/H-16/H-23/H-33 y criterios
  **B-8**/**C-10**; §7.1 actualizada a las métricas vigentes; `estado_proyecto.md` con el hito del Ciclo 10.
- Cierra **HB-07, H-15, H-16, H-23 y H-33** y los criterios **B-8** y **C-10** (H-13/H-14/H-34 permanecen en backlog).

## 19. Ciclo 11 — RF-009: pipeline de CI de GitLab con gates

**Objetivo:** materializar en CI los gates ya decididos (tests, cobertura, gas, documentos y ABIs) sobre la
rama `rwa-sc-DSH-GCP`. **El ciclo no toca `src/` ni `test/`**: no hay cambios de contrato ni de suite.

### 19.1 Artefactos nuevos

| Artefacto | Contenido |
|---|---|
| `rwa-sc/.gitlab-ci.yml` | Pipeline de 7 etapas (`validate`, `build`, `fmt`, `test`, `coverage`, `gas`, `ci-checks`), imagen `ghcr.io/foundry-rs/foundry:v1.8.3` fijada, `rules` en MR y `rwa-sc-DSH-GCP`, artefactos de conteo real y `lcov.info`, sin secretos |
| `rwa-sc/sc/script/ci/check_coverage.sh` | Gate RNF-002/D-017/D-042: parsea `forge coverage --report summary`, calcula el **agregado de `src/`** (excluyendo `src/ICompliance.sol` y `src/IClaimTopicsRegistry.sol`) y el **mínimo por contrato** (líneas); umbral desde `COVERAGE_THRESHOLD` / `COVERAGE_CONTRACT_THRESHOLD`; falla indicando el contrato y el porcentaje |
| `rwa-sc/sc/script/ci/run_local_ci.sh` | Ensayo local del pipeline: recorre las 7 etapas con los mismos comandos y devuelve exit 0/1 (resumen por etapa) |

### 19.2 Tests y cobertura — sin regresión

| Métrica | Antes (Ciclo 10) | Después (Ciclo 11) |
|---|---|---|
| Tests | 353 | **353** |
| Fallos | 0 | **0** |
| `src/` (líneas, D-017) | 97,11 % | **97,12 % (674/694)** |
| Mínimo por contrato (líneas) | — | **91,53 %** (`src/ClaimTopicsRegistryCloneFactory.sol`) |

`forge build` → 0 errores; `forge fmt --check` → limpio; `forge snapshot --check --tolerance 5` → OK.

### 19.3 Verificaciones del ciclo

| Verificación | Resultado |
|---|---|
| `forge build` | 0 errores |
| `forge test` | **353 tests passed, 0 failed, 0 skipped (353 total)** |
| `forge fmt --check` | limpio |
| `python3 -c "import yaml; yaml.safe_load(open('.gitlab-ci.yml'))"` | **YAML OK**; 7 etapas y 7 jobs |
| `sc/script/ci/check_coverage.sh` (positivo) | **exit 0**: agregado `src/` **97,12 % (674/694)**; mínimo por contrato **91,53 %** (`src/ClaimTopicsRegistryCloneFactory.sol`) |
| `sc/script/ci/check_coverage.sh` (negativo 1: copia temporal con `TokenCloneable` al 60,00 %) | **exit 1**: `FAIL: contrato src/TokenCloneable.sol con cobertura de líneas 60.00% (108/180) < 80%` |
| `sc/script/ci/check_coverage.sh` (negativo 2: `COVERAGE_THRESHOLD=99`) | **exit 1**: `FAIL: cobertura agregada de src/ 97.12% < 99%` |
| `sc/script/ci/run_local_ci.sh` | **exit 0**: `validate OK · build OK · fmt OK · test OK · coverage OK · gas OK · ci-checks OK` |
| Artefacto de conteo | `sc/ci-artifacts/test-count.txt` → `tests_listed=353` + resumen real de la ejecución |
| `git status --short` | limpio tras el commit local |

Salida resumida de `run_local_ci.sh` (extracto real):

```text
== STAGE: validate   -> OK: 3 submódulos declarados y pinneados, sin prefijos -/+
== STAGE: build      -> OK
== STAGE: fmt        -> OK
== STAGE: test       -> Ran 18 test suites: 353 tests passed, 0 failed, 0 skipped (353 total tests)
== STAGE: coverage   -> agregado src/ 97.12% (674/694); mínimo por contrato 91.53%
                        OK: cobertura agregada de src/ 97.12% >= 80% y mínimo por contrato 91.53% >= 80%
== STAGE: gas        -> OK (353 tests; dentro de la tolerancia del 5 %)
== STAGE: ci-checks  -> OK: sin bypassCompliance; docs RF-006 consistentes (12 docs); 15 ABIs sin deriva
RESULTADO: OK (pipeline local en verde)
```

### 19.4 Estado real del pipeline

El pipeline está **ejecutado en remoto en verde** en la rama `rwa-sc-DSH-GCP`: pipelines **`2934202154`** y
**`2934241152`**, con **7/7 jobs en `success`** (AF-11, cierre de Fase 4). `run_local_ci.sh` reproduce las
mismas 7 etapas en local. Nota: la imagen oficial de Foundry es no-root y no trae `jq` (que `abi_diff.sh`
exige); `ci-checks` lo instala si el runner permite root o si el ejecutor es shell, y si no hay que usar una
imagen propia con `jq`. Detalle en `entornos_globales.md` §13.

### 19.5 Documentación y decisiones

- `README.md` (§Integración Continua), `entornos_globales.md` §9/§11/§13.
- Decisiones nuevas: **D-062..D-065** en `requerimientos.md` (Bloque 6).
- `documento_tecnico.md`: `RF-009` → **IMPLEMENTADO (Ciclo 11)**; `RNF-001/RNF-002/RNF-003` con gate en CI;
  cierra **B-3** y **B-5**.
- `estado_proyecto.md`: hito del Ciclo 11 y **cierre de la Fase 3** (ciclos 1, 1b, 2..11, 8b y 8c).

## 20. Ciclo 11 (ajuste) — primera ejecución real del pipeline en GitLab

Tras el `push` autorizado de `rwa-sc-DSH-GCP` (commit `e748978`), GitLab lanzó el
**pipeline 2934157857** y el job `validate` **falló**. Diagnóstico con el log del runner
(`/-/jobs/<id>/raw`, accesible sin token por ser proyecto público):

```
$ set -euo pipefail
fatal: detected dubious ownership in repository at '/builds/anlucorporations/rwa-sc'
ERROR: Job failed: exit code 128
```

**Causa raíz:** la imagen oficial de Foundry corre como usuario **no-root** (`foundry`, uid 1000)
sobre un checkout propiedad de otro UID, así que `git` aborta antes de ejecutar el script.
El resto de jobs quedaron `skipped`.

**Correcciones aplicadas (Ciclo 11-ajuste):**

1. `default.before_script` ejecuta `git config --global --add safe.directory "$CI_PROJECT_DIR"` en
   todos los jobs (arregla el fallo real y previene el mismo problema en `forge` y en los gates).
2. `abi_diff.sh` deja de depender de **`jq`**: la imagen es `ubuntu:22.04` + `git` (verificado en el
   `Dockerfile` de la release v1.8.3) y **no trae `jq` ni `python3`**. La línea base pasa a ser la
   salida **cruda y determinista** de `forge inspect <C> abi --json` (misma versión de forge y solc),
   y se compara con `diff`/`comm`/`grep`; se añaden `sc/abis/<C>.methods` para el detalle por firma.
   Con `jq`, el gate habría fallado en el runner no-root (no puede `apt-get install`).
3. Se elimina el `before_script` que intentaba instalar `jq` en `ci-checks` (ya no hace falta).
4. **Gate reforzado:** ante deriva de ABI, además de exigir el contrato y cada firma en
   `CHANGELOG_ABIS.md`, se exige que **`CHANGELOG_ABIS.md` se modifique en el mismo cambio**
   (commits desde la base + árbol de trabajo), de modo que una mención histórica del contrato
   no deje pasar una deriva nueva. Probado en positivo (sin deriva → exit 0) y en negativo
   (nueva función pública sin tocar el changelog → exit 1 con doble diagnóstico).
5. Documentación de la imagen y del comando de diagnóstico del pipeline.

Tras las correcciones, `run_local_ci.sh` sigue en verde (7/7 etapas) y el YAML valida.

### 20.1 Resultado final: pipeline en verde en GitLab

Tras el segundo arreglo (`097c221`, comodín `safe.directory '*'`), el **pipeline 2934202154** de
`rwa-sc-DSH-GCP` terminó en **verde con los 7 jobs**:

| Job | Estado | Duración |
|---|---|---|
| `validate` | ✅ success | 29 s |
| `build` | ✅ success | 48 s |
| `fmt` | ✅ success | 29 s |
| `test` | ✅ success | 36 s |
| `coverage` | ✅ success | 40 s |
| `gas` | ✅ success | 31 s |
| `ci-checks` | ✅ success | 33 s |

Evidencia del runner (logs públicos):
- `test`: sube los artefactos `sc/ci-artifacts/test-count.txt` y `test-run.log` (conteo real, no escrito a mano).
- `coverage`: `agregado src/ : 97.12% (674/694)` · `umbral agregado / por contrato : 80% / 80%` ·
  `OK: cobertura agregada de src/ 97.12% >= 80% y mínimo por contrato 91.53% >= 80%`.
- `ci-checks`: sin `bypassCompliance`, documentación consistente y 15 ABIs sin deriva.

Con esto, **RNF-002, RNF-003 y RNF-001 pasan a estar verificados por un pipeline real**, no solo por
mediciones locales, y los criterios **B-3 y B-5** del informe V1 quedan cubiertos.

## 21. Fase 4 — Pruebas de invariantes con estado (RF-009)

Se añaden 4 suites de invariantes con handlers acotados en `sc/test/invariant/` (19 funciones
`invariant_*` + 4 `test_handler_operativo`). Detalle completo en
`RepoTecnico/pruebas/pruebas_invariantes.md`.

### 21.1 Conteo y corrección

| Métrica | Antes | Después |
|---|---:|---:|
| Tests (`forge test`, resumen) | 353 | **361** |
| Suites | 18 | **22** |
| Funciones `invariant_*` | 0 | **19** |
| `tests_listed` (`test --list`, `^    test`) | 353 | **357** (`+4` harness) |
| Cobertura `src/` (líneas) | 97,12 % (674/694) | **97,12 % (674/694)** |
| Mínimo por contrato | 91,53 % | **91,53 %** |

`forge test` → `Ran 22 test suites ... 361 tests passed, 0 failed, 0 skipped`.

### 21.2 Configuración y tiempos (Forge 1.8.3)

`[invariant] runs = 64, depth = 64, fail_on_revert = false` (4096 llamadas/contrato; 16 384 en total).

| Medición | Tiempo |
|---|---:|
| `forge test` completo (típico / mínimo / máximo) | 25,2 s / 15,5 s / **80,7 s** |
| Suite de invariantes sola | **13,2 s** |
| `forge coverage` con invariantes 64/64 | 204 s |
| `forge coverage` con `RUNS=1 DEPTH=1` (etapa CI) | **65 s** |
| Intento descartado `128/128` | 313 s |

La variación del `test` completo se debe a que el fuzzer de invariantes de Foundry v1.8.3 no admite
semilla (`forge config` no expone `[invariant] seed`); el gate de gas no se ve afectado porque las
entradas de invariantes del `.gas-snapshot` registran `(runs, calls, reverts)`, no gas.

### 21.3 Pipeline (7/7 en verde tras el cambio)

`bash sc/script/ci/run_local_ci.sh` → exit 0 en **232 s**; las 7 etapas `validate`, `build`, `fmt`,
`test`, `coverage`, `gas`, `ci-checks` en `OK`. El artefacto `test-count.txt` añade
`invariant_functions_listed` (19) manteniendo `tests_listed` (357). La etapa `coverage` fija
`FOUNDRY_INVARIANT_RUNS=1` / `FOUNDRY_INVARIANT_DEPTH=1` y mantiene
`agregado src/ : 97.12% (674/694)` y `mínimo por contrato : 91.53%`.

### 21.4 Hallazgos

**Cero violaciones de los invariantes del encargo**: suministro/`maxSupply`, topes y whitelist de
`burn`/`forcedTransfer`, congelación/pausa, guard `nonReentrant`, `isVerified` ⟺ claim vigente de issuer
autorizado, sincronía de los tres registries, ciclo de vida del claim (`claimNonce`, revocación, vigencia)
y fail-closed/aislamiento del `ComplianceAggregator`. **No se modificó `src/`**, ni ABI, ni `SECURITY.md`.

---

## 22. Fase 4 — Matriz de criterios y cierre de huecos (RF-009/RF-005/RF-002/RF-012/RF-010/RF-006)

Cierre de los huecos detectados por `RepoTecnico/pruebas/matriz_criterios.md` (§3): 7 pruebas nuevas,
1 cambio de código (storage muerto) y 2 gates de CI nuevos.

### 22.1 Conteo y cobertura — antes / después

| Métrica | Antes (§21) | Después |
|---|---:|---:|
| Tests (`forge test`, resumen) | 361 | **368** |
| Suites | 22 | 22 |
| `tests_listed` (`test --list`, `^    test`) | 357 | **364** |
| Funciones `invariant_*` | 19 | 19 |
| Cobertura `src/` (líneas) | 97,12 % (674/694) | **97,11 % (672/692)** |
| Mínimo por contrato | 91,53 % | **91,53 %** |

`forge test` → `Ran 22 test suites ... 368 tests passed, 0 failed, 0 skipped`.
`forge snapshot --check --tolerance 5` → OK (`.gas-snapshot` regenerado).

### 22.2 Cambio de código (RF-005)

`TokenCloneable` elimina `_tokenName`/`_tokenSymbol` (storage muerto: `name()`/`symbol()` los sirve
`ERC20Upgradeable`). Se conserva `_tokenDecimals`, que sí usa `decimals()`. Sin cambio de ABI
(`abi_diff.sh` → 15 ABIs sin deriva; el layout de storage no es ABI) y cobertura `src/` **97,11 %**.

### 22.3 Pruebas nuevas (7)

| Prueba | CU / criterio | Cierra |
|---|---|---|
| `test_RF001_registries_owner_tras_renuncia` | CU-01 EARS | renuncia de owner en los 3 registries |
| `test_RF002_transfer_from_sin_allowance_revierte` | CU-10 EARS | allowance 0 → `ERC20InsufficientAllowance`, sin notificar módulos |
| `test_RNF005_cambio_topics_afecta_isVerified` | CU-14 Gherkin | añadir topic invalida `isVerified` sin redeploy |
| `test_RNF005_set_claim_topics_registry_cero_revierte` | CU-14 EARS | `setClaimTopicsRegistry(0)` → `"Invalid registry address"` |
| `test_RF012_retirar_ultimo_modulo_bloquea` | CU-16 EARS | fail-closed tras retirar el último módulo |
| `test_RF005_initialization_implementacion_bloqueada` | CU-08 Gherkin | `initialize` sobre la implementación → `InvalidInitialization` |
| `test_RF005_no_storage_muerto_tokenName` | CU-08 EARS | el artefacto no contiene `_tokenName`/`_tokenSymbol` |

### 22.4 Gates nuevos

- `sc/script/ci/check_secrets.sh` (RF-010): falla ante claves de 64 hex en scripts/config, asignaciones de
  secreto con 64 hex, tokens `glpat-`/`ghp_`/`AKIA`, `keys.json` o `--private-key` en scripts; exige
  `.env`/`.env.*` en `.gitignore`. Caso negativo demostrado en copia temporal (exit 1) y positivo en el repo
  (exit 0; 98 archivos versionados escaneados).
- `check_docs.sh` ampliado (RF-006, `ci_check_RF006_mitigacion_con_test`): cada `test_*` citado en
  `SECURITY.md` debe existir en `sc/test/**` y cada `ci_check_*` como gate en `sc/script/ci/**`. Caso negativo
  demostrado en copia temporal (exit 1) y positivo en el repo (exit 0).

### 22.5 Alineación documental

`casos_uso.md` v1.4: 109 referencias a `A IMPLEMENTAR` → **0**; 69 nombres de test obsoletos → **0**; 2 criterios
derogados (fail-open) reescritos a fail-closed; remisión a la matriz en el encabezado.

### 22.6 Verificaciones del cierre

`forge build` 0 errores; `forge test` **368/368**; `forge fmt --check` limpio;
`forge snapshot --check --tolerance 5` OK; `check_no_bypass_flag.sh` + `check_docs.sh` + `abi_diff.sh` +
`check_secrets.sh` + `check_coverage.sh` en verde; `run_local_ci.sh` → exit 0.

### 22.7 Hallazgos del cierre (bugs corregidos, sin impacto en contratos)

- **F4-01 — `run_local_ci.sh` enmascaraba fallos de gate.** `stage_ci_checks` invocaba los cuatro gates sin
  comprobar su estado; al no haber `set -e`, la función devolvía el estado del **último** comando
  (`check_secrets.sh`), de modo que un `check_docs.sh` o `abi_diff.sh` en rojo se reportaba como `ci-checks OK`
  y el pipeline local terminaba en exit 0. Corregido con `|| return 1` por gate. Es un bug de la simulación
  local, **no** del pipeline de GitLab (allí cada `bash script/...` es una línea del job y su fallo tumba el job).
- **F4-02 — falso negativo intermitente en `check_docs.sh` (nuevo check de RF-006).** La comprobación
  `printf '%s\n' "${real_tests[@]}" | grep -q` cerraba la tubería al primer acierto (SIGPIPE en `printf`) y con
  `set -o pipefail` devolvía "no existe" de forma no determinista (reproducido 1 de cada 50 ejecuciones).
  Sustituido por un índice asociativo en memoria; 100/100 ejecuciones estables.

### 22.8 F4-03 — falso positivo del gate de secretos (detectado por el Lead)

Al re-verificar la Fase 4, el Lead ejecutó `check_secrets.sh` y devolvió **exit 1** pese a que el
subagente lo había reportado en verde. Causa: el gate **se escaneaba a sí mismo** y sus propios
comentarios documentan los patrones prohibidos (`keys.json`, `--private-key`), de modo que los
marcaba como hallazgos.

**Corrección (commit `bd58e4c`):** se excluye el propio path (`sc/script/ci/check_secrets.sh`) de la
lista de *scripts/configuración* (los chequeos 2 y 3, que recorren **todos** los archivos, se mantienen).
Verificado: **positivo** → exit 0 (`99 archivos versionados escaneados`) y **negativo** → exit 1
al inyectar una clave `0x…64 hex` en `sc/script/deploy.sh`.

**Lección aplicada al proceso:** un agente no puede validar su propio gate cuando el gate documenta los
patrones que prohíbe; hace falta re-ejecución independiente del Lead (que es la que encontró F4-01..F4-03).

---

## 23. Fase 4 — Cierre: auditoría adversarial final (AF-01..AF-15)

Corrección de los hallazgos de `RepoTecnico/pruebas/auditoria_final.md` (1 ALTA · 10 MEDIA · 4 BAJA).
Quedan **fuera** del cierre (D-082): AF-03, AF-04, AF-05, AF-12 y AF-14. **(Actualizado en §24: por decisión
del usuario, AF-03 y AF-05 se cierran también en D-083/D-084; siguen diferidos AF-04, AF-12 y AF-14.)**

### 23.1 Conteo y cobertura — antes / después

| Métrica | Antes (§22) | Después |
|---|---:|---:|
| Tests (`forge test`, resumen) | 368 | **386** |
| Suites | 22 | **23** |
| Funciones `invariant_*` | 19 | 19 |
| Cobertura `src/` (líneas) | 97,11 % (672/692) | **97,05 % (690/711)** (líneas nuevas de AF-01/AF-02/AF-13) |
| Mínimo por contrato | 91,53 % | **91,53 %** (`ClaimTopicsRegistryCloneFactory.sol`) |

`forge test` → `Ran 23 test suites ... 386 tests passed, 0 failed, 0 skipped` (`+18` pruebas).

### 23.2 Cambios de código (AF-01/AF-02/AF-13)

| Hallazgo | Cambio | Evidencia de prueba |
|---|---|---|
| **AF-01 (ALTA)** | `TokenCloneable.addComplianceModule` y `ComplianceAggregator.addModule` exigen `tokenContract() == token` (helper `_isLinkedToToken`, exento si el módulo no expone el getter). Los 3 módulos usan **lectura defensiva** (`success && data.length >= 32`) en vez de `abi.decode` directo | `test/AuditoriaFinalAF.t.sol` (`test_AF01_*`), `test/MaxBalanceCompliance.t.sol`, `test/MaxHoldersCompliance.t.sol` |
| **AF-02 (MEDIA)** | `mint`/`burn` → `whenNotPaused`; `mint` → `require(!frozen[to])`; `forcedTransfer` sigue operativo en pausa (recuperación de emergencia) | `test/AuditoriaFinalAF.t.sol` (`test_AF02_*`) |
| **AF-13 (BAJA)** | `removeModuleThroughAggregator` exige aggregator registrado y módulo activo para este token antes de delegar | `test/AuditoriaFinalAF.t.sol` (`test_AF13_*`), `test/ComplianceAggregator.t.sol` |

### 23.3 Scripts y documentación (AF-06..AF-11, AF-15)

- **AF-06:** `pruebas/matriz_criterios.md` **v2** (386 tests, 23 suites, 19 invariantes, **0 FALTA**; los 9 huecos cerrados).
- **AF-07:** `DeployFullStack.s.sol` configura `maxBurnPerTx`/`maxForcedPerTx` y destino autorizado; `deploy.sh` añade smoke test de operatividad (`cast call` + cotejo con el artefacto).
- **AF-08:** `CompleteDeploymentExample.s.sol` firma claims EIP-712 reales con `vm.sign` (simula en local sin revertir; verificado con `forge script`).
- **AF-09:** `DeployComplianceAggregator.s.sol` corrige los "Next Steps" a la API real.
- **AF-10:** `RUNBOOK_MIGRACION.md` (redeploy limpio D-019/RT-008).
- **AF-11:** `SECURITY.md`, `.gitlab-ci.yml`, `README.md`, `entornos_globales.md` y `run_local_ci.sh` alineados con la CI en verde (`2934202154`, `2934241152`).
- **AF-15:** `CLAIM_TYPEHASH` de D-020 con `nonce` (superado por D-050) y línea de D-016 corregida (`src/TokenCloneable.sol:311`).

### 23.4 ABI y gas

Sin cambios de ABI: los helpers nuevos son `private`/`internal` y no añaden selectores públicos; `sc/abis/`
no requiere regeneración (`abi_diff.sh` → 15 ABIs sin deriva) y `CHANGELOG_ABIS.md` no cambia. El coste de
gas de `mint`/`burn` varía por las comprobaciones nuevas; `.gas-snapshot` se regenera y
`forge snapshot --check --tolerance 5` queda en verde.

### 23.5 Verificaciones del cierre

`forge build` 0 errores; `forge test` **386/386**; `forge fmt --check` limpio;
`forge snapshot --check --tolerance 5` OK; los 5 gates (`check_no_bypass_flag.sh`, `check_docs.sh`,
`abi_diff.sh`, `check_secrets.sh`, `check_coverage.sh`) y `run_local_ci.sh` en verde.

### 23.6 Decisiones

**D-075..D-082** en `requerimientos.md` (Bloque 6b) y en `estado_proyecto.md`.

---

## 24. Fase 4 — Cierre definitivo: AF-03 (firma del `uri`) y AF-05 (token fail-closed sin módulos)

> **Decisiones del usuario.** Se incorporan al alcance los dos hallazgos MEDIA que D-082 había diferido.
> Commits: `Fase 4: firma del uri (AF-03) y token fail-closed sin modulos (AF-05)`.

### 24.1 Conteo — antes / después

| Métrica | Antes (§23) | Después |
|---|---:|---:|
| Tests (`forge test`, resumen) | 386 | **394** |
| Suites | 23 | **23** |
| Funciones `invariant_*` | 19 | **19** |
| Cobertura `src/` (líneas) | 97,05 % (690/711) | **97,05 % (691/712)** (la rama fail-closed de `canTransfer` queda cubierta por `test_AF05_*`) |

`forge test` → `Ran 23 test suites ... 394 tests passed, 0 failed, 0 skipped` (`+8` pruebas: 3 de AF-03 y 5 de AF-05).

### 24.2 AF-03 — el digest EIP-712 cubre el `uri`

- `CLAIM_TYPEHASH` = `keccak256("Claim(address walletOwner,uint256 topic,uint256 scheme,bytes32 dataHash,uint256 expiresAt,uint256 nonce,bytes32 uriHash)")`;
  `structHash = keccak256(abi.encode(typeHash, owner(), topic, scheme, keccak256(data), expiresAt, nonce, keccak256(bytes(uri))))`.
- **Breaking off-chain crítico** (documentado en `CHANGELOG_ABIS.md`): el cliente que firme debe añadir
  `bytes32 uriHash` como último campo. **No** cambia el ABI (constante; `CLAIM_TYPEHASH()` sigue `0x6b0509b1`)
  y `sc/abis/` no se regenera.
- `SigUtils.signClaim`/`claimDigest`/`claimStructHash` ganan el parámetro `uri` y conservan overloads sin
  `uri` que firman con `""` (compatibilidad de las llamadas históricas).
- Pruebas: `test_AF03_addClaim_uri_alterado_revierte`, `test_AF03_addClaim_uri_correcto_ok`,
  `test_AF03_digest_cambia_con_el_uri`.

### 24.3 AF-05 — token fail-closed sin módulos

- `TokenCloneable.canTransfer` devuelve `false` si `complianceModules.length == 0`; `transfer`/`transferFrom`
  revierten `"Transfer not compliant"`. `mint`/`burn`/`forcedTransfer` **no** dependen de ese array.
- Sin cambio de ABI ni de gas relevante en las rutas con módulos.
- Pruebas: `test_AF05_canTransfer_false_sin_modulos`, `test_AF05_transfer_revierte_sin_modulos`,
  `test_AF05_con_modulo_permisivo_transfiere`, `test_AF05_retirar_ultimo_modulo_bloquea_y_registrar_recupera`,
  `test_AF05_mint_y_forcedTransfer_no_dependen_de_modulos` (módulo `test/mocks/AllowAllCompliance.sol`).

### 24.4 Suites adaptadas (sin debilitarlas)

Ninguna suite transfería con 0 módulos, así que AF-05 no rompió tests existentes. AF-03 sí obligó a que las
firmas cubrieran el `uri` que se da de alta:

| Suite | Adaptación |
|---|---|
| `test/IdentityCloneable.t.sol` | `_sign` recibe el `uri`; los negativos firman el mismo `uri` que `addClaim` (el revert sigue siendo por la manipulación bajo prueba, no por el `uri`) |
| `test/IdentityCloneFactory.t.sol` | `_sign` recibe el `uri`; cada call site firma la URI que usa `addClaim`/`createIdentityWithClaim` |
| `test/RF013_ClaimLifecycle.t.sol` | `_attest` y `_sign` firman el `uri`; los digests de `test_RF013_digest_incluye_nonce` usan el mismo `uri` |
| `test/mocks/AllowAllCompliance.sol` (nuevo) | Módulo permisivo para el camino positivo de AF-05 |

Ningún test se borra, se debilita ni usa `vm.skip`.

### 24.5 Verificaciones del cierre definitivo

`forge build` 0 errores; `forge test` **394/394** (0 fallos, 0 saltados); `forge fmt --check` limpio;
`check_no_bypass_flag.sh`, `check_docs.sh`, `abi_diff.sh`, `check_secrets.sh` y `run_local_ci.sh` en verde;
`forge snapshot --check --tolerance 5` OK (`.gas-snapshot` regenerado sin `forge coverage` previo).

### 24.6 Decisiones

**D-083** (AF-03), **D-084** (AF-05) y **D-085** (cierre definitivo y adaptación de suites) en
`requerimientos.md` (Bloque 6b) y en `estado_proyecto.md`.

---

## 25. Cierre de deuda de bajo riesgo — QW-8 · AF-12 · H-14

> Cambios fuera de la Fase 4 (que permanece cerrada): cierran deuda del backlog V1 y de la auditoría
> adversarial final sin tocar RF ni cambiar selectores.

### 25.1 Conteo — antes / después

| Métrica | Antes (§24) | Después |
|---|---:|---:|
| Tests (`forge test`) | 394 | **401** |
| Suites | 23 | **23** |
| Funciones `invariant_*` | 19 | **19** |
| Cobertura `src/` (líneas) | 97,05 % (691/712) | **97,07 % (695/716)** |
| Mínimo por contrato (líneas) | 91,53 % | **91,53 %** |

`forge test` → `Ran 23 test suites ... 401 tests passed, 0 failed, 0 skipped` (`+7` pruebas: 3 de QW-8 y 4
de AF-12). El denominador de cobertura sube de 712 a 716 líneas porque entran las 3 líneas `emit` nuevas
más la línea de `claimNonce++` de `removeClaim`.

### 25.2 QW-8 — evento `TokenContractSet` (cierra H-34)

`MaxBalanceCompliance`, `MaxHoldersCompliance` y `TransferLockCompliance` emiten
`TokenContractSet(address indexed tokenContract)` en `setTokenContract`. Traza la vinculación módulo→token
que antes era silenciosa. **ABI aditiva** (solo evento), sin cambio de selectores. Pruebas:
`test_QW8_SetTokenContract_emite_evento` en las 3 suites de módulos.

### 25.3 AF-12 — `removeClaim` con anti-replay

`IdentityCloneable.removeClaim` (solo titular) sigue borrando la entrada (`claimExists == false`) pero
incrementa `claimNonce[_topic][_issuer]`, igual que `revokeClaim`: la firma previa al borrado deja de
verificar y no reactiva el claim por replay; la traza queda en `ClaimAdded`/`ClaimRevoked`/`ClaimRemoved`.
Sin cambio de ABI (`claimNonce` ya era público). Pruebas: `test_AF12_*` (4) en `RF013_ClaimLifecycle.t.sol`.

### 25.4 H-14 — diccionario de datos contra el storage real

`RepoTecnico/diccionario_datos.md` §1 se reescribe contra `forge inspect <C> storage-layout`: se eliminan
`_tokenName`, `_tokenSymbol` (D-070) y `bypassCompliance` (RF-002); se añaden `claimNonce` (RF-013/AF-12),
`expiresAt`/`revoked` en el struct `Claim` y los 4 campos de RF-004 (`authorizedDestinations`,
`maxBurnPerTx`, `maxForcedPerTx`, `maxSupply`); se actualizan líneas y la lista de eventos (incluye
`TokenContractSet`). El espejo `rwa-web/RepoTecnico/diccionario_datos.md` se sincroniza byte a byte.

### 25.5 Verificaciones

`forge build` 0 errores; `forge test` **401/401** (0 fallos, 0 saltados); `forge fmt --check` limpio;
`check_coverage.sh` → agregado `src/` **97,07 %** y mínimo por contrato **91,53 %** (umbrales 80 %/80 %);
`abi_diff.sh` → 15 ABIs, deriva declarada en `CHANGELOG_ABIS.md` y línea base regenerada; `.gas-snapshot`
regenerado (`forge snapshot`), `check_no_bypass_flag.sh` y `check_secrets.sh` sin hallazgos.
