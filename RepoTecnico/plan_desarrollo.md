# 🗺️ Plan de Desarrollo Vertical — RWA (`rwa-sc`)

> **Versión:** v1.0 · 2026-10-03 · Fase 3 del Asistente de Proyecto
> **Fuentes:** `requerimientos.md` (RF-001..RF-013), `INFORME_OPTIMIZACION_V1.md` (H-01..H-34), `casos_uso/casos_uso.md` (CU-01..CU-17),
> `documento_tecnico.md` (arquitectura objetivo), `AUDITORIA_DOCUMENTO_TECNICO.md` (DT-01..DT-13 y D-019..D-024).
> **Rama de trabajo:** `rwa-sc-DSH-GCP` · **Regla:** cada ciclo es una entrega 100 % operativa y verificable;
> no se pasa al siguiente hasta que sus criterios de aceptación se cumplan y las pruebas estén documentadas.
> **Push:** nunca sin orden explícita del usuario (`/push`). Los commits locales en la rama sí forman parte del ciclo.

## Reglas de cada ciclo

1. **Implementar** el cambio en `rwa-sc/sc/` sin romper lo anterior.
2. **Probar**: `forge build` + `forge fmt --check` + `forge test` + `forge coverage`.
3. **Documentar**: métricas antes/después en `metricas_ejecucion.md` y avance en `estado_proyecto.md`.
4. **Registrar**: decisión o notas en `requerimientos.md` si el ciclo cierra una DF3.
5. **Esperar** la interacción del usuario antes de empezar el ciclo siguiente.

---

## Ciclo 1 — RF-005 · Build reproducible y suites en verde

| Campo | Detalle |
|---|---|
| **Objetivo** | Que un clon limpio compile y pase la suite al 100 %, sin pasos manuales ni tests muertos. |
| **Requisitos** | RF-005 (HB-05, HB-11, H-02, H-04) · RNF-003 · CU-11 |
| **Entregables** | `foundry.toml` con `solc_version`/`optimizer`/`evm_version` fijados; `.gitmodules` unificado y submódulos pinneados (bootstrap documentado); suites `Token.t.sol` y `ComplianceAggregator.t.sol` adaptadas a **factory + clon + `initialize`** (D-015); los 3 tests de ahorro de gas reescritos con comparación equivalente + `.gas-snapshot` (H-03/M-2); `forge build`/`fmt --check`/`test` en verde; README/START_HERE corregidos en las cifras falsas (M-2/C-10) |
| **Criterios de aceptación** | `forge test` → **0 fallos** y ninguna suite revierte en `setUp`; `forge test --list` = 151 (o el conteo real documentado); `forge fmt --check` sin cambios; `forge build` sin errores; `.gas-snapshot` versionado y comparación equivalente en los 3 tests de gas; métricas publicadas en `metricas_ejecucion.md` |
| **Riesgo** | Que el conteo real difiera de 151 al adaptar los tests → se documenta el número nuevo. |
| **Cierra** | DT-04 (aritmética 53/55), DT-08 (cita RT-001), parte de DT-09 |

## Ciclo 1b — RF-005 (continuación) · Cobertura ≥ 80 % por contrato en los registries

| Campo | Detalle |
|---|---|
| **Objetivo** | Que los contratos centrales de la cadena de identidad/claims superen el umbral **por contrato**, no solo en el agregado de `src/`. |
| **Requisitos** | RF-005 · RNF-002 (D-017) · CU-01, CU-09 |
| **Motivo** | El agregado de `src/` quedó en 86,33 % tras el Ciclo 1, pero `IdentityRegistry` (37 %), `TrustedIssuersRegistry` (38 %) y `ClaimTopicsRegistry` (45 %) están muy por debajo. |
| **Entregables** | Suites nuevas `sc/test/IdentityRegistry.t.sol`, `sc/test/TrustedIssuersRegistry.t.sol`, `sc/test/ClaimTopicsRegistry.t.sol`; `.gas-snapshot` regenerado; métricas actualizadas |
| **Criterios de aceptación** | Los tres contratos ≥ 80 % de líneas **y** funciones; **sin modificar `src/`**; 0 fallos; `forge fmt --check` y `forge snapshot --check` limpios |
| **Cierra** | El punto débil detectado en la verificación del Ciclo 1 y habilita el gate por contrato del Ciclo 11 |

## Ciclo 2 — RF-001 · Verificación criptográfica del claim (EIP-712)

| Campo | Detalle |
|---|---|
| **Objetivo** | Que un claim solo se acepte con firma EIP-712 válida de un issuer autorizado para el topic (D-020). |
| **Requisitos** | RF-001 (H-01 crítica) · RNF-005 · CU-02, CU-03 |
| **Entregables** | `IdentityCloneable.addClaim` con `domainSeparator` (`RWA-Identity`/`1`/`chainId`/clon) y `CLAIM_TYPEHASH` con `expiresAt`; validación `scheme == 1`, longitud 65, `recovered == issuer ≠ 0`; exigencia de `hasClaimTopic(issuer, topic)`; sobrescritura/renovación con firma válida (D-018); `createIdentityWithClaim` alineado |
| **Criterios de aceptación** | Los PoC de `evidencias/PoC_H01_H05.t.sol` **invertidos**: firma vacía/ inválida/issuer no autorizado → revert; firma válida → `ClaimAdded`; renovación sobrescribe sin duplicar issuer. Tests nombrados `test_RF001_*` |
| **Cierra** | DT-01 (diseño EIP-712) y el bloqueante V2 **B-1** |

## Ciclo 3 — RF-002 · Retirada del flag de bypass y anti-reentrancia

| Campo | Detalle |
|---|---|
| **Objetivo** | Eliminar `bypassCompliance` mutable y proteger las llamadas externas frente a reentrancia (H-03/H-18). |
| **Requisitos** | RF-002 (HB-03, H-18) · CU-04 |
| **Entregables** | `ReentrancyGuardUpgradeable` en `transfer`/`forcedTransfer`/`mint`/`burn` y en las entradas del aggregator; bypass sustituido por una ruta explícita de `forcedTransfer` sujeta a RF-004; gate de CI `ci_check_RF002_no_bypassCompliance_storage` (`forge inspect storage-layout`) |
| **Criterios de aceptación** | `forge inspect TokenCloneable storage-layout` sin `bypassCompliance`; test con módulo malicioso que reentra y **revierte**; cola de eventos coherente |
| **Cierra** | Parte del criterio **C-2** |

## Ciclo 4 — RF-003 · Validación de módulos con ERC-165

| Campo | Detalle |
|---|---|
| **Objetivo** | Que token y aggregator rechacen módulos que no implementan `ICompliance`. |
| **Requisitos** | RF-003 (HB-04, H-17) · RNF-005 · CU-05 |
| **Entregables** | `ICompliance is IERC165` + `supportsInterface` en los 3 módulos; validación en `addComplianceModule` y `addModule`; tests que rechazan EOAs y contratos no conformes; **incluye HB-13** (validar que la identidad registrada sea un contrato) y **HB-15** (rechazar `topic == 0` en `addClaimTopic`), agrupados por afinidad con las validaciones de este ciclo |
| **Criterios de aceptación** | `test_RF003_*`: EOA y contrato sin interface → revert; módulo conforme → alta; `interfaceId` de `ICompliance` verificado |
| **Cierra** | **C-1** |

## Ciclo 5 — RF-004 · Whitelist, límites y tope de suministro

| Campo | Detalle |
|---|---|
| **Objetivo** | Acotar los poderes del agente sobre balances ajenos y la emisión (D-021/D-022). |
| **Requisitos** | RF-004 (HB-02) · CU-06 · DT-03 |
| **Entregables** | `authorizedDestinations[address]`, `maxBurnPerTx`, `maxForcedPerTx`, `maxSupply` con eventos y validaciones; rol que administra la whitelist (DF3-09); tests de límites y de ampliación de `maxSupply` |
| **Criterios de aceptación** | `forcedTransfer`/`burn` fuera de whitelist o por encima del tope → revert; `maxSupply` no baja por debajo de lo emitido; eventos emitidos |
| **Cierra** | **B-4** (junto con D-021) |

## Ciclo 6 — RF-011 · `isVerified` fail-closed

| Campo | Detalle |
|---|---|
| **Objetivo** | Que sin política de topics ninguna wallet quede verificada (H-05). |
| **Requisitos** | RF-011 (H-05 auditoría V1) · CU-15 |
| **Entregables** | `isVerified` devuelve `false` si `claimTopicsRegistry == address(0)` o sin topics; inversión del criterio fail-open de CU-09 |
| **Criterios de aceptación** | PoC `test_H05_isVerified_fail_open` **invertido** (`test_RF011_*`); token recién creado por factory → `isVerified == false` |
| **Cierra** | **B-2** |

## Ciclo 7 — RF-012 · `ComplianceAggregator` fail-closed

| Campo | Detalle |
|---|---|
| **Objetivo** | Sin módulos registrados, denegar; el token se registra al añadir su primer módulo (D-023). |
| **Requisitos** | RF-012 (H-22 auditoría V1) · CU-16 |
| **Entregables** | `canTransfer` deniega sin módulos; registro automático del token en `addModule`; administración acotada al token/admin del token; tests cross-token |
| **Criterios de aceptación** | PoC `test_AggregatorFailOpenNoModules` **invertido**; un token no puede alterar módulos de otro |
| **Cierra** | **C-3** (con H-19) |

## Ciclo 8 — RF-013 · Vigencia y revocación de claims

| Campo | Detalle |
|---|---|
| **Objetivo** | Que `isVerified` rechace claims vencidos o revocados por el issuer (H-08). |
| **Requisitos** | RF-013 (H-08 auditoría V1) · CU-17 · DF3-07 |
| **Entregables** | `expiresAt` y `revoked` en `Claim`; `revokeClaim` restringido al issuer/no-owner; consulta en `isVerified`; eventos; **incluye HB-14** (verificar pertenencia en `registeredAddresses` al borrar), agrupado porque este ciclo ya modifica los registries de claims |
| **Criterios de aceptación** | Claim vencido o revocado → `isVerified == false` y transferencia revertida; renovación exige nueva firma (D-020) |
| **Cierra** | **B-6** |

## Ciclo 8c — RF-013 · Nonce firmado anti-replay en la revocación

| Campo | Detalle |
|---|---|
| **Objetivo** | Cerrar el bypass detectado en el Ciclo 8 (D-046): la firma EIP-712 original seguía siendo válida tras `revokeClaim` y permitía reactivar el claim por replay. |
| **Requisitos** | RF-013 (D-046) · CU-17 |
| **Entregables** | `CLAIM_TYPEHASH` con `uint256 nonce`; mapping `claimNonce[topic][issuer]`; `revokeClaim` lo incrementa; `addClaim` firma con el nonce vigente sin incrementarlo (D-018); vista `claimNonce(uint256,address)`; helper `SigUtils.signClaim` con overload sin nonce |
| **Criterios de aceptación** | Reintroducir la firma original tras revocar revierte (`"Signature signer mismatch"`) y el claim sigue revocado; reactivar exige firma nueva con el nonce incrementado; reaplicar una firma válida sin revocación sigue siendo idempotente; ninguna métrica de `src/` baja |
| **Cierra** | Cierra el bypass de D-046 (residual de H-08) |

## Ciclo 8b — Revisión del toolchain (decidido por el usuario)

| Campo | Detalle |
|---|---|
| **Objetivo** | Evaluar y, si procede, subir `solc` a ≥ 0.8.24 para poder usar `EIP712Upgradeable` de OpenZeppelin en lugar del digest EIP-712 propio (D-026), re-fijando `evm_version` y regenerando todo. |
| **Motivo** | D-026: OZ v5.5.0 declara `pragma ^0.8.24` en `EIP712Upgradeable`, incompatible con el `solc 0.8.20` fijado en el Ciclo 1. Usar la librería auditada reduce código criptográfico propio. |
| **Momento** | **Antes del Ciclo 9** (despliegue), para no re-desplegar dos veces. |
| **Criterios de aceptación** | Decisión registrada (subir o mantener 0.8.20 con justificación); si se sube: `forge build`/`test`/`fmt`/`snapshot` y cobertura sin regresión, `evm_version` re-fijado según la red Besu, y `IdentityCloneable` usando `EIP712Upgradeable` con los mismos digests (tests `test_RF001_digest_*` intactos) |
| **Riesgo** | La subida de `solc` puede cambiar el bytecode/gas y exige regenerar `.gas-snapshot` y re-verificar la compatibilidad con Besu |

## Ciclo 9 — RF-010 · Secretos y despliegue verificable

| Campo | Detalle |
|---|---|
| **Objetivo** | No exponer claves y verificar el despliegue on-chain (H-28/H-31/M-14/M-15). |
| **Requisitos** | RF-010 (HB-12, H-28) · CU-13 · RT-005/RT-006 |
| **Entregables** | `deploy-besu.sh` lee `PRIVATE_KEY` de entorno/Secret Manager (`DS_*`), sin `argv`; script canónico end-to-end (registries + token + módulos); verificación post-deploy con `cast code`/`cast call`; JSON de artefactos (direcciones, ABIs, `chainId`, bloque) |
| **Criterios de aceptación** | Escaneo de secretos limpio; despliegue local contra Anvil verificado por `cast`; JSON persistido |
| **Cierra** | **B-4** (parte de claves) y **C-9** |

## Ciclo 10 — RF-006 · Documentación, SECURITY.md y changelog de ABIs

| Campo | Detalle |
|---|---|
| **Objetivo** | Alinear la documentación con el código y dejar el rastro de seguridad (D-011). |
| **Requisitos** | RF-006 (HB-07) · CU-12 |
| **Entregables** | Corrección de referencias rotas (Token.sol/Identity.sol y 3 `.md` inexistentes); cifras reales; `SECURITY.md` (hallazgos y mitigaciones); `CHANGELOG_ABIS.md` + `script/ci/abi_diff.sh`; retirada de "production-ready"/"ERC-3643 compliant" no verificables |
| **Criterios de aceptación** | `ci_check_RF006_*` en verde: sin referencias rotas, `SECURITY.md` y changelog presentes, diff de ABIs reproducible |
| **Cierra** | **B-8** y **C-10** |

## Ciclo 11 — RF-009 · CI GitLab con gates

| Campo | Detalle |
|---|---|
| **Objetivo** | Pipeline que impida fusionar sin build, tests y cobertura correctos. |
| **Requisitos** | RF-009 (HB-10, H-04) · RNF-002/003 · CU-11 |
| **Entregables** | `.gitlab-ci.yml` en `rwa-sc-DSH-GCP`: submódulos pinneados → `forge build` → `fmt --check` → `test` (gate RNF-003) → `coverage` con `COVERAGE_THRESHOLD` sobre `src/` sin interfaces (D-017) → publicación de `lcov` y conteo real; gates adicionales de RF-002/RF-006 |
| **Criterios de aceptación** | Pipeline en verde en la rama; cobertura ≥ 80 %; el conteo de tests se publica como artefacto, no a mano |
| **Cierra** | **B-3** y **B-5** (con el bootstrap reproducible) |

---

## Trazabilidad de ciclos

| Ciclo | RF | CU | Hallazgos que cierra | Criterios V2 |
|---|---|---|---|---|
| 1 | RF-005 | CU-11 | HB-05, HB-11, H-02, H-04, H-03 (gas) | B-7 (base) |
| 1b | RF-005 | CU-01, CU-09 | — (refuerzo de RNF-002 por contrato) | B-3 |
| 2 | RF-001 | CU-02, CU-03 | H-01 | B-1 |
| 3 | RF-002 | CU-04 | HB-03, H-18 | C-2 |
| 4 | RF-003 | CU-05 | HB-04, H-17 | C-1 |
| 5 | RF-004 | CU-06 | HB-02, H-06 (parcial) | B-4 |
| 6 | RF-011 | CU-15 | H-05 (auditoría V1) | B-2 |
| 7 | RF-012 | CU-16 | H-22 (auditoría V1), H-19 | C-3 |
| 8 | RF-013 | CU-17 | H-08 (auditoría V1) | B-6 |
| 9 | RF-010 | CU-13 | HB-12, H-28, H-31, H-24 | B-4, C-9 |
| 10 | RF-006 | CU-12 | HB-07, H-15, H-16, H-33 | B-8, C-10 |
| 11 | RF-009 | CU-11 | HB-10, H-04, H-02 | B-3, B-5 |

## Fuera de estos ciclos (backlog §8 de `requerimientos.md`)

El resto de los 34 hallazgos (RNF ISO 25010, AML/sanciones, PII/GDPR, observabilidad/indexación, backup/DR,
multisig efectivo, auditoría externa y demás) permanece en el backlog priorizado con su plan
(12 Quick wins + 17 Mejoras + 9 Roadmap) y no bloquea la ejecución de los 11 ciclos.
