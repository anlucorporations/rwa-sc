# 🔎 Auditoría adversarial de `casos_uso.md` (Fase 2)

> Auditor: agente auditor de requisitos (rol adversarial). Fecha de auditoría: sobre el estado del repo en esta sesión.
> Alcance auditado: `RepoTecnico/casos_uso/casos_uso.md` (14 CU, 66 Gherkin + 52 EARS, matriz de trazabilidad).
> Documento auditado **intacto** (no se modificó). Este informe es el único artefacto escrito.

---

## 1. Veredicto

**NO — aptos para pasar a Fase 3 solo tras corregir 2 hallazgos Altos (A-01, A-02) y la clasificación Gherkin/EARS (M-02).**
La cobertura RF/RNF y la estructura son sólidas y no hay requisitos huérfanos reales; el bloqueo es de fidelidad al código en CU-05/CU-10 y de trazabilidad inflada, no de fondo de alcance.

---

## 2. Metodología y qué se leyó

**Documentos leídos (solo lectura):**
- `RepoTecnico/casos_uso/casos_uso.md` (796 líneas, íntegro).
- `RepoTecnico/requerimientos.md` (RF-001..RF-010, RNF-001..RNF-006, H-01..H-12, RT, decisiones).
- `RepoTecnico/estado_proyecto.md` (D-001..D-011, fases).
- `RepoTecnico/metricas_ejecucion.md` (datos reales: 151 declarados / 98 ejecutados / 93 pasan / 5 fallan / 53 no arrancan; coverage 42,86%).

**Código contrastado (ruta:línea como evidencia):**
- `rwa-sc/sc/src/TokenCloneable.sol`, `IdentityCloneable.sol`, `IdentityRegistry.sol`, `TrustedIssuersRegistry.sol`, `ClaimTopicsRegistryCloneable.sol`, `ClaimTopicsRegistry.sol`, `ICompliance.sol`, `IClaimTopicsRegistry.sol`, `TokenCloneFactory.sol`.
- `rwa-sc/sc/src/compliance/ComplianceAggregator.sol`, `MaxBalanceCompliance.sol`, `MaxHoldersCompliance.sol`, `TransferLockCompliance.sol`.
- `rwa-sc/sc/test/` (nombres de tests existentes), `rwa-sc/sc/.gitmodules`, `rwa-sc/sc/foundry.toml`, `rwa-sc/.gitignore`, `rwa-sc/deploy-besu.sh`.

**Comprobaciones ejecutadas:** `grep` de `supportsInterface|IERC165|ERC165`, `ReentrancyGuard`, `authorizedDestinations|maxBurnPerTx|maxForcedPerTx`, `setClaimTopics`, y listado de `function test*`; conteo de campos por CU.

**Regla de juicio aplicada:** una diferencia doc↔código que coincide con un RF/RNF/H declarado (p. ej. EIP-712 ausente, `bypassCompliance` presente) **NO** se cuenta como defecto: el documento es especificación de la mejora. Solo se penaliza (a) afirmar como real algo que el código contradice y no es el objetivo declarado, (b) errores internos de la especificación (mensajes, firmas, taxonomía, trazabilidad, duplicidad).

---

## 3. Hallazgos por impacto

### Altos

| ID | CU | Problema | Evidencia | Corrección propuesta |
|---|---|---|---|---|
| **A-01** | CU-05 (y CU-07 paso 4) | La precondición afirma que **`ICompliance` extiende `IERC165`** y que los módulos implementan `supportsInterface(type(ICompliance).interfaceId) == true`. Es **falso** en el código: `ICompliance` no hereda de nada y ningún contrato del `src/` define `supportsInterface`. Todo CU-05 (Gherkin 1–4 y las 3 EARS) es inejecutable tal cual; el Gherkin #1 usa `MaxBalanceCompliance` "real" que hoy NO pasaría la validación que el propio CU exige. | `rwa-sc/sc/src/ICompliance.sol:8` → `interface ICompliance {` (sin `is IERC165`); `grep -rn "supportsInterface\|IERC165\|ERC165" rwa-sc/sc/src/` → **0 resultados**; `MaxBalanceCompliance.sol:12`, `MaxHoldersCompliance.sol:12`, `TransferLockCompliance.sol:12`, `ComplianceAggregator.sol:23` implementan `ICompliance` sin ERC-165. | Reescribir CU-05 como **cambio objetivo de RF-003**: (1) mover a "postcondición de RF-003" el añadir `is IERC165` a `ICompliance` y `supportsInterface` a los 4 contratos; (2) la precondición pasa a "tras aplicar RF-003"; (3) dejar constancia de que `type(ICompliance).interfaceId` sigue siendo el XOR de los 4 selectores **propios** (Solidity excluye funciones heredadas del interfaceId), por lo que Gherkin #4 se mantiene válido tal cual. |
| **A-02** | CU-10 (EARS) | El criterio **`test_RF002_mint_salta_compliance_y_notifica_created`** afirma: "Cuando el `from` sea `address(0)` (mint), el sistema deberá **omitir `canTransfer`**". Contradice el código real: `mint()` recorre todos los módulos y **sí** llama `canTransfer`, revirtiendo `"Mint not compliant"`. Un test escrito según el criterio fallará. | `rwa-sc/sc/src/TokenCloneable.sol:180-182` (`for ... require(complianceModules[i].canTransfer(address(0), to, amount), "Mint not compliant")`); el salto de compliance de `_update` (`:317`) es a nivel ERC-20, pero `mint()` lo compensa explícitamente. | Elegir y documentar el diseño: **(A)** mantener el comportamiento actual → reescribir el criterio como Gherkin "Dado un módulo que rechaza, Cuando A2 llama `mint`, Entonces revierte `\"Mint not compliant\"`" + EARS "Si no hay módulos, `mint` no revierte por compliance". **(B)** si RF-002 debe saltar compliance también en `mint`, declararlo como cambio explícito y añadir EARS que diferencie `mint()` de `_update`. |

### Medios

| ID | CU | Problema | Evidencia | Corrección propuesta |
|---|---|---|---|---|
| **M-01** | CU-14 | Mensajes de revert inexistentes. A14.1 y Gherkin #2 esperan `"Topic already exists"`; A14.2 espera `"Topic does not exist"`. El código usa la palabra "Claim": `"Claim topic already exists"` y `"Claim topic does not exist"`. `vm.expectRevert("Topic already exists")` no casará. | `rwa-sc/sc/src/ClaimTopicsRegistryCloneable.sol:37` (`"Claim topic already exists"`) y `:49` (`"Claim topic does not exist"`); idéntico en `ClaimTopicsRegistry.sol:30,42`. | Sustituir los literales en A14.1, A14.2 y Gherkin #2 por los reales (`"Claim topic already exists"` / `"Claim topic does not exist"`). |
| **M-02** | CU-01, CU-06, CU-07, CU-09, CU-10 | **Clasificación Gherkin/EARS inconsistente.** La regla del propio doc reserva EARS para restricciones del sistema, pero hay comportamientos funcionales de camino feliz en EARS: CU-07 `canTransfer_sin_modulos_true`, `canTransfer_todos_true`, `transferred_propaga`; CU-10 `mint_salta...`, `burn_salta...`, `forcedTransfer_no_llama_canTransfer`; CU-06 `burn_notifica_modulos`; CU-09 `isVerified_sin_topics_registrada_true`; CU-01 `hasClaimTopic...false`. Son "Dado/Cuando/Entonces" disfrazados. | `casos_uso.md:84`, `:325`, `:375-377`, `:484`, `:545-547`. | Mover a Gherkin todo criterio que describa una salida funcional observable; dejar en EARS solo invariantes, cotas, atomicidad y condiciones de entorno (p. ej. `no_escribe_estado_en_fallo`, `reentrancy_revierte`, `limite_es_por_operacion`). |
| **M-03** | Matriz §3.1–3.3 | **Trazabilidad inversa inflada.** Hay mappings que ninguna criterio respalda: **RF-005→CU-07** (CU-07 no tiene ni un criterio de `forge build`/submódulos); **RNF-005→CU-09** (el `IdentityRegistry` no es extensibilidad de compliance) y **RNF-005→CU-10**; **RF-003→CU-10** (los `test_RF003_transfer_maxBalance_rechaza` / `transferLock_rechaza` prueban el comportamiento de módulos, no `supportsInterface`); **H-05→CU-07/CU-08** (H-05 es `lib/` ausente/compilación). | `casos_uso.md:349` (`RF-003 · RF-005 · RNF-005 · H-04 · H-05`), `:454` (`RF-001 · RNF-005 · H-01`), `:512`, `:570`, `:744`, `:770-772`. | O bien eliminar los mappings no soportados, o bien añadir un criterio explícito por cada uno. RF-005/H-05 deben quedar en CU-11 (y opcionalmente CU-08); RF-003 en CU-05 y CU-07; renombrar los `test_RF003_transfer_*` de CU-10 a `test_RF002_transfer_*` (su contenido es comportamiento de transferencia, no validación de interfaz). |
| **M-04** | CU-02 (flujo principal, paso 5) | Error conceptual: "El contrato verifica que el `issuer` esté en **`IdentityRegistry`/`TrustedIssuersRegistry`**". `IdentityRegistry` vincula wallets↔identidades, no autoriza issuers; la autorización de topic vive únicamente en `TrustedIssuersRegistry.hasClaimTopic`. | `rwa-sc/sc/src/IdentityRegistry.sol:33-43` (solo `registerIdentity` wallet↔identity); `TrustedIssuersRegistry.sol:101-113` (`hasClaimTopic`). | Dejar el paso 5 como: "verifica `trustedIssuersRegistry.hasClaimTopic(issuer, topic) == true`"; eliminar la mención a `IdentityRegistry` como registro de issuers. |
| **M-05** | CU-08, CU-12, CU-13 | **Criterios no testeables o infradeterminados.** (a) `ci_check_RF006_abi_diff_automatico`: "regenerar el diff de ABIs de forma automática" sin herramienta, formato ni comando. (b) `ci_check_RF010_secret_manager_soportado`: "permitir obtener el secreto desde Secret Manager sin cambiar el flujo", sin invocación ni forma de verificarlo. (c) `test_RNF001_gas_clone_menor_que_deploy_completo`: umbral "inferior al 10%" y comparación "equivalente" sin definir el término de comparación, cuando las métricas reales muestran que el test de gas actual está roto. | `casos_uso.md:636`, `:682`, `:427`; `metricas_ejecucion.md:50-61` (clone 387.469 vs "directo" 5.974; `test_GasSavings` en underflow). | Concretar en §4 de este informe (reescrituras). |
| **M-06** | CU-04 ↔ CU-06 | **Duplicidad de criterios.** `test_RF002_forcedTransfer_destino_no_autorizado_revierte` (CU-04 #2) ≡ `test_RF004_forcedTransfer_destino_fuera_whitelist_revierte` (CU-06 #5): mismo escenario y mismo mensaje `"Destination not authorized"`. `test_RF002_forcedTransfer_destino_autorizado_ok` (CU-04 #1) ≡ `test_RF004_forcedTransfer_destino_whitelisted_ok` (CU-06 #4). Además CU-01 A1.3 repite el caso de la EARS `addTrustedIssuer_topics_vacios_revierte`. | `casos_uso.md:212-215` vs `:316-319`; `:208-211` vs `:312-315`; `:54` vs `:85`. | Deduplicar: conservar el criterio en CU-04 (donde nace `forcedTransfer`) y en CU-06 referenciar "ver CU-04 #2/#1"; eliminar la repetición literal. |
| **M-07** | CU-11 | El criterio `ci_check_RF005_submodulos_pinneados` exige fijar `forge-std`, `openzeppelin-contracts` y `openzeppelin-contracts-upgradeable`, pero el repo **solo declara un submódulo**: `openzeppelin-contracts`. `openzeppelin-contracts-upgradeable` se resuelve por remapping a un directorio no declarado como submódulo y `forge-std` no figura. | `rwa-sc/sc/.gitmodules` (una sola entrada); `rwa-sc/sc/foundry.toml` (remappings a `lib/openzeppelin-contracts-upgradeable/`); `requerimientos.md:45,67`. | Alinear el criterio con la realidad (declarar los 3 en `.gitmodules` con commit pinneado) o rebajar el criterio a "las dependencias presentes están pinneadas". |
| **M-08** | CU-02..CU-08, CU-13 | **Presentismo sin marca de estado.** El doc afirma en presente hechos que hoy son objetivos de RF-001/RF-002/RF-004 (verificación EIP-712, ausencia de `bypassCompliance`, `authorizedDestinations`, `maxBurnPerTx`, `ReentrancyGuard`, `supportsInterface`, `deploy-besu.sh` sin `keys.json`). No es incorrecto como especificación de la mejora, pero impide planificar Fase 3 y fue la causa de confusión doc↔código. | `TokenCloneable.sol:47,212,218` (`bypassCompliance` existe); `grep` de `authorizedDestinations|maxBurnPerTx|maxForcedPerTx|ReentrancyGuard` → 0; `deploy-besu.sh:14,37` (lee `~/.foundry/keys.json`). | Añadir por criterio una marca `[nuevo]`/`[existente]` o una columna "estado: implementado / a-implementar por RF-xxx". |

### Bajos

| ID | CU | Problema | Evidencia | Corrección propuesta |
|---|---|---|---|---|
| **B-01** | CU-14 (paso 1) | Cita `setClaimTopics(topics)` como alternativa a `addClaimTopic`; esa función **no existe** en ningún contrato. | `grep -rn "setClaimTopics" rwa-sc/sc/src/` → solo `setClaimTopicsRegistry` (token) y usos en factories/tests. | Eliminar la mención o declararla explícitamente como propuesta nueva. |
| **B-02** | CU-03 (A3.6) | Atribuye a **D-007** la semántica de replay/sobreescritura ("sobreescribe solo si la firma es válida"), pero D-007 solo fija "EIP-712 tipada con `ecrecover` on-chain". | `requerimientos.md:85`; `estado_proyecto.md:37`. | Crear una decisión específica de replay o reformular sin invocar D-007. |
| **B-03** | CU-04 (Gherkin #4) | `test_RF002_no_existe_bypassCompliance_en_storage` está nombrado como test Foundry pero su artefacto real es un comando (`forge inspect ... storage-layout`). | `casos_uso.md:220-223`. | Renombrar a `ci_check_RF002_no_bypassCompliance_storage` y describir el comando exacto. |
| **B-04** | CU-08 | Los criterios de funcionalidad `createToken*` se nombran `test_RNF001_*`, pero RNF-001 es ahorro de gas; no miden gas. | `casos_uso.md:405-424`; RNF-001 en `requerimientos.md:56`. | Renombrar a `test_RF005_createToken*`; reservar `test_RNF001_*` para el criterio de gas. |
| **B-05** | CU-04 (A4.6) | Afirma que `from == address(0)` revierte. Hoy `forcedTransfer(0, to, amount)` acuña tokens (no revierte), porque `_update` con `from == 0` es un mint. | `TokenCloneable.sol:208-224` (sin guard de `from`), `:315-321`. | Marcar como cambio objetivo y añadir `require(from != address(0), ...)` al criterio. |
| **B-06** | CU-11 | Fija el baseline "151 tests" en `ci_check_RF009_pipeline_test_exit_0`, cuando la línea base real medida es 98 ejecutados / 93 pasan / 5 fallan / 53 no arrancan y coverage 42,86%. | `casos_uso.md:580`; `metricas_ejecucion.md:27-35,65-72`. | Declarar baseline real + objetivo, y convertir el criterio en "no disminuye respecto al inicio de la iteración y llega a ≥151 al cerrar RF-005". |
| **B-07** | CU-07 (Gherkin #3) | Verifica `moduleIndex` de `M3 == 0`, pero `moduleIndex` es `private` sin getter; no es observable. | `ComplianceAggregator.sol:29`. | Verificar solo por orden (`getModuleAt(token,0) == M3`, `getModuleCount == 2`); eliminar la aserción sobre `moduleIndex`. |

---

## 4. Criterios no testeables / ambiguos y su reescritura

1. **CU-12 — `ci_check_RF006_abi_diff_automatico`** (actual: "deberá regenerar el diff de ABIs de forma automática").
   **Reescritura:** `Dado` el job de CI con `forge` instalado, `Cuando` cambie un selector público, `Entonces` un script compara `forge inspect <Contrato> abi` contra el ABI versionado en `out/` y falla con código ≠ 0 si el selector nuevo/modificado/eliminado no aparece en una sección de `CHANGELOG_ABIS.md`; evidencia: salida del job con la lista de selectores del diff.

2. **CU-13 — `ci_check_RF010_secret_manager_soportado`** (actual: "deberá permitir obtener el secreto desde Secret Manager sin cambiar el flujo").
   **Reescritura:** `Dado` un entorno con `gcloud` presente y un stub de `gcloud secrets versions access latest --secret=DS_PRIVATE_KEY`, `Cuando` `deploy-besu.sh` arranque con `USE_SECRET_MANAGER=1` y sin la variable en entorno, `Entonces` el script exporta el valor solo en el proceso y completa `forge create`; evidencia: test de shell que intercepta la invocación a `gcloud` y comprueba que no se escribe ningún archivo.

3. **CU-08 — `test_RNF001_gas_clone_menor_que_deploy_completo`** (actual: "`gasUsed` inferior al 10% del de un despliegue completo equivalente").
   **Reescritura:** fijar el término de comparación de forma equivalente: `gasUsed(createTokenWithRegistries(name,symbol,decimals,admin,id,ti,ct)) < 0.10 × gasUsed(new TokenCloneable() + initialize(...) + setIdentityRegistry + setTrustedIssuersRegistry + setClaimTopicsRegistry + grant×3 + renounce×3)`; declarar el valor medido en el propio test (referencia rota actual: `metricas_ejecucion.md:54-55`).

4. **CU-07 — Gherkin #3 (`moduleIndex` privado)**: reescribir quitando "y `moduleIndex` de `M3` es `0`"; la verificación queda: `getModuleAt(token,0) == M3`, `getModuleCount(token) == 2`, `isModuleActiveInAggregator(aggregator,M1) == false`.

5. **CU-02 — EARS `test_RF001_addClaim_issuer_cero_revierte`** (actual: "deberá revertir sin ejecutar `ecrecover`", sin mensaje).
   **Reescritura:** `Si issuer == address(0)`, `Entonces` `addClaim` revierte con el literal que fije la implementación de RF-001 (declarar el string exacto) y `claimExists(topic, issuer) == false`; usar `vm.expectRevert(bytes("..."))`.

6. **CU-04 — `test_RF002_no_existe_bypassCompliance_en_storage`**: separar el artefacto. Comando verificable: `forge inspect TokenCloneable storage-layout --json | grep -c bypassCompliance == 0` dentro de un `ci_check_RF002_*`; el nombre `test_*` no debe usarse para un comando de shell.

7. **CU-01 — EARS `test_RF001_registries_owner_tras_renuncia`**: acotar a comportamiento observable: `Dado` owner renuncia, `Cuando` cualquier cuenta llama `addTrustedIssuer/removeTrustedIssuer/updateIssuerClaimTopics`, `Entonces` revierte `OwnableUnauthorizedAccount`; incluir `test_RF001_registries_owner_tras_renuncia` con `vm.prank` de la cuenta antes-owner.

---

## 5. Cobertura RF/RNF real

**Funcionales**

| ID | Descripción | Cobertura | Veredicto |
|---|---|---|---|
| RF-001 | EIP-712 + issuer autorizado | CU-02, CU-03 (núcleo); CU-01/09/14 (precondiciones) | ✅ Cubierto |
| RF-002 | Quitar `bypassCompliance` + reentrancia + forcedTransfer acotado | CU-04, CU-10 | ✅ Cubierto (corregir A-02) |
| RF-003 | Validar `supportsInterface(ICompliance)` | CU-05, CU-07 | ⚠️ Cubierto, condicionado a implementar ERC-165 (A-01) |
| RF-004 | Whitelist + `maxBurnPerTx`/`maxForcedPerTx` | CU-06 | ✅ Cubierto |
| RF-005 | Compilación/submódulos/build-test 100% | CU-11 (real), CU-08 (parcial) | ✅ Cubierto; mapping a CU-07 no válido (M-03) |
| RF-006 | Docs sin refs rotas + SECURITY.md + CHANGELOG ABIs | CU-12 | ✅ Cubierto (concretar M-05) |
| RF-007 | Unificar/retirar `web-registry-trusted2` | — | ⛔ Fuera de alcance declarado (D-003, §3.4) |
| RF-008 | Fuente única de direcciones | — | ⛔ Fuera de alcance declarado (D-003, §3.4) |
| RF-009 | CI build+test+coverage ≥80% | CU-11 | ✅ Cubierto |
| RF-010 | Secretos fuera de scripts | CU-13 | ✅ Cubierto (concretar M-05) |

**No funcionales**

| ID | Descripción | Cobertura | Veredicto |
|---|---|---|---|
| RNF-001 | Ahorros gas EIP-1167 94–98% | CU-08 | ✅ Cubierto (reescribir criterio) |
| RNF-002 | Coverage ≥ 80% | CU-11 | ✅ Cubierto |
| RNF-003 | 100% tests en CI antes de merge | CU-11 | ✅ Cubierto |
| RNF-004 | Ningún secreto en repos/scripts | CU-13 | ✅ Cubierto |
| RNF-005 | Extensibilidad de compliance sin tocar el token | CU-07, CU-14 | ✅ Cubierto; mappings CU-09/CU-10 no válidos (M-03) |
| RNF-006 | Apps web con `docker compose up` | — | ⛔ Fuera de alcance declarado (D-003, §3.4) |

**Conclusión de cobertura:** no hay huérfanos reales. RF-001..RF-006, RF-009, RF-010 y RNF-001..RNF-005 están cubiertos; RF-007, RF-008 y RNF-006 están explícitamente excluidos y justificados por D-003. El problema no es cobertura sino **trazabilidad sobredimensionada** (M-03).

---

## 6. Lo que está BIEN (no rehacer)

- **Estructura completa:** los 14 CU tienen Actor, Objetivo, Precondición, Flujo principal, Flujos alternativos, Postcondición y Cobertura (verificado: 14/14 en cada campo).
- **Trazabilidad formal y exclusiones explícitas:** existen las matrices §3.1–3.3 y la declaración §3.4 de sin-cobertura; ningún RF/RNF queda huérfano sin justificar.
- **Sin referencias inventadas:** todos los `H-xx` (H-01..H-12), `RF/RNF` y `D-xx` (D-003..D-011) citados existen en `requerimientos.md` / `estado_proyecto.md`. No aparece H-13 ni requisitos inexistentes.
- **Conteo consistente:** 66 criterios Gherkin (66 "Dado") + 52 EARS, coincidente con `requerimientos.md:95`.
- **Fidelidad verificada en CU-01:** mensajes (`"Invalid issuer address"`, `"Issuer already trusted"`, `"Must specify at least one claim topic"`, `"Issuer not trusted"`), eventos `TrustedIssuerAdded/Removed/ClaimTopicsUpdated`, `hasClaimTopic` sin revert y swap-and-pop coinciden con `TrustedIssuersRegistry.sol:21-23,32-64,101-113`.
- **Fidelidad verificada en CU-07:** `onlyOwnerOrToken` (`ComplianceAggregator.sol:50-53`), mensajes `"Only owner or token can call"`/`"Module already added"`/`"Module not active"`, swap-and-pop con reasignación de índice (`:87-106`), `canTransfer` vacío→`true` (`:123`).
- **Fidelidad verificada en CU-08:** firmas de `createToken`/`createTokenWithRegistries`, evento `TokenCreated`, `implementation` inmutable, `_disableInitializers` en la implementación (`TokenCloneFactory.sol:26-32,38-40,51-135`; `TokenCloneable.sol:50-52`).
- **Fidelidad verificada en CU-09:** `registerIdentity/updateIdentity/removeIdentity` con swap-and-pop y sus mensajes (`IdentityRegistry.sol:33-82`); `isVerified` devuelve `false` con registry cero y `true` con `claimTopicsRegistry == 0` (`TokenCloneable.sol:229-281`).
- **CU-02 `claimId` correcto:** el criterio `keccak256(abi.encode(issuer, topic))` coincide con el ensamblador real (`IdentityCloneable.sol:88-97`) — no requiere corrección.
- **Actoría y notas de fidelidad:** la tabla de actores y la nota `Ownable` vs `AccessControl` (`casos_uso.md:26-29`) reflejan bien el diseño real.

---

## 7. Criterios de aceptación para dar el documento por bueno

1. **A-01 corregido:** RF-003 declarado como cambio (añadir `IERC165` a `ICompliance` + `supportsInterface` a los 4 contratos) y precondición de CU-05 reescrita; ningún criterio presupone ERC-165 inexistente.
2. **A-02 corregido:** el criterio de `mint` es coherente con `TokenCloneable.sol:180-182` **o** existe decisión explícita de cambio de comportamiento con su criterio EARS diferenciando `mint()` y `_update`.
3. **M-01 corregido:** todos los mensajes de revert de CU-14 son literales del código ("Claim topic ...").
4. **M-02 corregido:** ≥95% de los criterios de comportamiento observable están en Gherkin; ningún EARS describe un happy-path.
5. **M-03 corregido:** cada fila de la matriz §3.1–3.3 se apoya en al menos un criterio concreto (eliminados RF-005→CU-07, RNF-005→CU-09/CU-10, H-05→CU-07/CU-08 salvo criterio explícito).
6. **M-04 corregido:** CU-02 paso 5 cita solo `TrustedIssuersRegistry.hasClaimTopic`.
7. **M-05 corregido:** ningún criterio usa "automático", "soportado" o umbral sin comando/herramienta/medición concreta (ver §4).
8. **M-06 corregido:** criterios de `forcedTransfer` whitelist sin duplicar entre CU-04 y CU-06.
9. **B-01..B-07 corregidos** (función inexistente, D-007 mal citada, `test_*` que es comando, naming RNF-001, guard de `from == 0`, baseline real, `moduleIndex` privado).
10. **M-08 aplicado:** cada criterio de CU-02..CU-08/CU-13 marcado `[existente]`/`[nuevo:RF-xxx]` para planificar Fase 3.

---

## 8. Descartados (falsos positivos, con motivo)

| Id | Acusación descartada | Motivo |
|---|---|---|
| FD-01 | "CU-02/CU-03 describen verificación EIP-712 que no existe en `IdentityCloneable.addClaim`". | **No es defecto:** es exactamente RF-001/H-01 (`requerimientos.md:41`); el doc especifica la mejora. Solo se penaliza no marcar estado (M-08). |
| FD-02 | "CU-04 sigue teniendo `bypassCompliance`" / "CU-06 inventa `authorizedDestinations` y topes". | **No es defecto:** son objetivos de RF-002/RF-004 (`requerimientos.md:42,44`). El código real los tiene/omite porque la mejora no se ha implementado. |
| FD-03 | "Al heredar `IERC165`, el `interfaceId` de `ICompliance` cambiaría y Gherkin #4 sería erróneo". | **Falso:** la semántica de Solidity excluye funciones heredadas de `type(I).interfaceId`; el XOR de los 4 selectores propios (`ICompliance.sol:16,24,31,38`) se mantiene. Se documenta en la corrección de A-01. |
| FD-04 | "CU-07 swap-and-pop contradice el código". | **Falso:** `ComplianceAggregator.sol:90-103` implementa exactamente el swap-and-pop descrito. |
| FD-05 | "CU-01 mensajes/eventos no coinciden". | **Falso:** verificados uno a uno en `TrustedIssuersRegistry.sol:32-113`. |
| FD-06 | "CU-09 no hace swap-and-pop en `removeIdentity`". | **Falso:** `IdentityRegistry.sol:72-79` lo implementa. |
| FD-07 | "Faltan CU para RF-007, RF-008 y RNF-006". | **Falso como defecto:** exclusión de alcance declarada y justificada por D-003 en §3.4; es una decisión de gestión, no una omisión. |
| FD-08 | "CU-02 Gherkin #2 (claimId) contradice el código". | **Falso:** `keccak256(abi.encode(issuer, topic))` replica el ensamblador de `IdentityCloneable.sol:88-97`. |

---

*Fin del informe. Documento auditado no modificado. Único artefacto escrito: `RepoTecnico/casos_uso/AUDITORIA_CASOS_USO.md`.*
