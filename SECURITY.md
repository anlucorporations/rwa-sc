# SECURITY.md — `rwa-sc` (contratos RWA)

> Documento de seguridad del proyecto RWA (RF-006, Ciclo 10). **Todos los datos de este documento son
> comprobables en el repositorio**; las fuentes se citan con `ruta` y, cuando procede, con la línea.
>
> - Auditoría de origen y estado de los 34 hallazgos: [`RepoTecnico/INFORME_OPTIMIZACION_V1.md`](RepoTecnico/INFORME_OPTIMIZACION_V1.md).
> - Historial de cambios de interfaz/selectores: [`CHANGELOG_ABIS.md`](CHANGELOG_ABIS.md).
> - Cifras reales (tests, cobertura, gas): [`RepoTecnico/metricas_ejecucion.md`](RepoTecnico/metricas_ejecucion.md).
> - Requisitos y decisiones (D-xxx): [`RepoTecnico/requerimientos.md`](RepoTecnico/requerimientos.md).

## 0. Declaración de conformidad (verificable)

El proyecto está **inspirado en ERC-3643 / T-REX**, pero **no es "ERC-3643 compliant"**: no implementa la
especificación completa. Lo que sí se puede comprobar en el código:

| Interfaz / capacidad | Estado | Evidencia |
|---|---|---|
| ERC-20 (OpenZeppelin v5.5.0) | Implementada | `src/TokenCloneable.sol` (hereda `ERC20Upgradeable`) |
| ERC-165 (`supportsInterface`) | Implementada en `ICompliance` y sus implementaciones | `src/ICompliance.sol`, `test/RF003_ERC165.t.sol` |
| EIP-1167 (minimal proxy) + `Initializable` | Usada como ciclo de vida de clones | `src/*CloneFactory.sol`, `test/TokenCloneFactory.t.sol` |
| EIP-712 (claims firmados) | Implementada con digest propio (D-026), no con `EIP712Upgradeable` | `src/IdentityCloneable.sol`, `test/IdentityCloneable.t.sol` |
| Especificación ERC-3643 completa (interfaz `IToken`, `IIdentity`, `ICompliance` de T-REX) | **No** implementada ni certificada | — |

**Este software no está auditado por terceros y no es apto para producción con activos reales**
(D-024; `RepoTecnico/requerimientos.md:143`). El veredicto de la auditoría V1 es explícitamente **"NO apto
para producción en su estado actual"** (`INFORME_OPTIMIZACION_V1.md:16`).

## 1. Modelo de amenazas (resumen)

Activos a proteger: (a) integridad del suministro y de las transferencias del token; (b) validez de las
identidades y claims (KYC/AML) que habilitan operar; (c) control de acceso a funciones privilegiadas
(`mint`, `burn`, `forcedTransfer`, `freeze`, cambios de registries y módulos); (d) material de firma
(claves) fuera del repositorio; (e) trazabilidad de cambios de interfaz para consumidores.

| # | Amenaza | Vector | Control actual | Residual |
|---|---|---|---|---|
| T1 | **Forja de claims** | Un titular de identidad se añade un claim de KYC sin firma válida del issuer | Firma **EIP-712** obligatoria en `addClaim` (RF-001); `isVerified` exige claim vigente y no revocado | Firmas EIP-712 propias (no `EIP712Upgradeable`), sin auditoría |
| T2 | **Fail-open de verificación** | Token sin `claimTopicsRegistry` (o sin topics) marca a cualquiera como verificado | `isVerified` **fail-closed** (RF-011) | — |
| T3 | **Módulo de compliance malicioso/incompatible** | Registrar una EOA o un contrato sin `ICompliance` como módulo | Validación **ERC-165** en token y aggregator (RF-003) | — |
| T4 | **Reentrancia** | Callbacks `transferred`/`created`/`destroyed` de un módulo malicioso | `ReentrancyGuardUpgradeable` (`nonReentrant`) en `transfer`/`forcedTransfer`/`mint`/`burn` (RF-002) | — |
| T5 | **Abuso de poderes del agente** | `burn`/`forcedTransfer` masivos o a destinos arbitrarios | Whitelist `authorizedDestinations` + `maxBurnPerTx`/`maxForcedPerTx` + `maxSupply` (RF-004) | Gobernanza en una sola EOA hasta el multisig (H-06/R-7) |
| T6 | **Aggregator fail-open / cross-token** | 0 módulos = permitir todo; owner global gestiona módulos ajenos | `ComplianceAggregator` **fail-closed** y gestión solo por el token (RF-012) | Estado singleton de módulos (H-19, backlog M-10) |
| T7 | **Replay de un claim revocado** | Reintroducir la firma original tras una revocación | `claimNonce` por `(topic, issuer)` dentro del digest; `revokeClaim` lo incrementa (RF-013, Ciclo 8c) | — |
| T8 | **Fuga de claves de despliegue** | Clave privada en `argv`/`ps` o en `~/.foundry/keys.json` | `deploy.sh` lee la clave de variable de entorno/Secret Manager y firma con keystore efímero (D-054/D-055) | Custodia de claves y rotación pendientes (H-06/R-7) |
| T9 | **Deriva de ABI no declarada** | Un cambio de interfaz rompe a `rwa-web` sin aviso | `script/ci/abi_diff.sh` contra `sc/abis/` + `CHANGELOG_ABIS.md` (RF-006) | El pipeline de CI aún no existe (RF-009) |
| T10 | **Documentación que sobreafirma** | Publicar "production-ready"/"ERC-3643 compliant" o cifras sin respaldo | Gate `script/ci/check_docs.sh`; cifras enlazadas a artefacto (RF-006) | — |

## 2. Estado de los hallazgos de la auditoría V1

Fuente de los IDs y títulos: `RepoTecnico/INFORME_OPTIMIZACION_V1.md` §4. El estado "corregido" exige un
test o un gate que lo demuestre.

### 2.1 Críticos y altos corregidos

| ID | Título breve | Estado | Ciclo / RF | Evidencia (test o gate) |
|---|---|---|---|---|
| **H-01** | Claims auto-forjados sin verificación de firma | **Corregido** | Ciclo 2 · RF-001 | `test/RF001_*` en `test/IdentityCloneable.t.sol` (`test_RF001_addClaim_firma_vacia_revierte`, `test_RF001_addClaim_firma_de_otra_clave_revierte`, `test_RF001_addClaim_firma_maleable_s_alto_revierte`, `test_RF001_addClaim_con_firma_valida`) |
| **H-02** | "139 tests (100 % passing)" falso; suites muertas; cobertura 42,86 % | **Corregido** | Ciclos 1/1b · RF-005, y Ciclo 10 · RF-006 | `forge test` → **353/353**; cobertura `src/` **97,11 % líneas / 86,13 % ramas** (`metricas_ejecucion.md` §16.3) |
| **H-04** | Build no reproducible: submódulos, pin de `solc`, sin CI | **Corregido** (CI pendiente en RF-009) | Ciclo 1 · RF-005 | `.gitmodules` único + `sc/foundry.lock`; `solc_version = 0.8.20` y `evm_version` en `sc/foundry.toml`; `metricas_ejecucion.md` §7.4 |
| **H-05** | `isVerified()` fail-open sin `claimTopicsRegistry` | **Corregido** | Ciclo 6 · RF-011 | `test/RF011_FailClosed.t.sol` (`test_RF011_isVerified_sin_registry_topics_false`, `test_RF011_mint_transfer_bloqueados_sin_politica`) |
| **H-08** | Claims sin vigencia ni revocación por el issuer | **Corregido** | Ciclos 8/8c · RF-013 | `test/RF013_ClaimLifecycle.t.sol` (`test_RF013_claim_expirado_isVerified_false`, `test_RF013_claim_revocado_por_issuer_isVerified_false`, `test_RF013_revocacion_replay_firma_original_revierte`) |
| **H-17** | `addComplianceModule`/`addModule` sin validar `ICompliance` | **Corregido** | Ciclo 4 · RF-003 | `test/RF003_ERC165.t.sol` (`test_RF003_addComplianceModule_revierte_eoa`, `test_RF003_aggregator_addModule_revierte_contrato_sin_interfaz`) |
| **H-18** | Callbacks externos sin `ReentrancyGuard` | **Corregido** | Ciclo 3 · RF-002 | `test/TokenReentrancy.t.sol` (`test_RF002_reentrancy_transfer_revierte`, `test_RF002_reentrancy_burn_revierte`) + `script/ci/check_no_bypass_flag.sh` |
| **H-22** | `ComplianceAggregator` fail-open y owner global | **Corregido** | Ciclo 7 · RF-012 | `test/RF012_AggregatorFailClosed.t.sol` (`test_RF012_aggregator_failclosed_por_defecto`, `test_RF012_aggregator_owner_global_token_ajeno_revierte`) |

### 2.2 Altos parcialmente corregidos o en backlog

| ID | Título breve | Estado | Backlog |
|---|---|---|---|
| **H-06** | Centralización de poderes en una EOA; `burn`/`forcedTransfer` sin límites | **Parcial**: RF-004 acota operaciones (whitelist/topes/`maxSupply`); falta multisig/timelock y reparto de roles | R-7 (D-021) |
| **H-07** | Factories permissionless; EIP-1167 sin ruta de upgrade | Backlog | M-7, R-6 (D-019) |
| **H-09** | Catálogo RNF incompleto (ISO 25010) | Backlog | R-1 |
| **H-10** | Sin RNF de cumplimiento regulatorio (sanciones/PEP/AML) | Backlog | R-2 |
| **H-11** | PII/KYC sin custodio, base legal, cifrado ni retención | Backlog | R-3 |
| **H-12** | Sin RNF de observabilidad ni indexación de eventos | Backlog | R-4 |

### 2.3 Medios y bajos

| ID | Título breve | Estado | Backlog |
|---|---|---|---|
| **H-13** | Catálogo de claim topics divergente | Backlog | M-8 |
| **H-14** | `diccionario_datos.md` describe storage inexistente | Backlog | QW-6 |
| **H-15** | Docs citan archivos/contratos inexistentes | **Corregido** | Ciclo 10 · RF-006 (gate `script/ci/check_docs.sh`) |
| **H-16** | "ERC-3643 compliant"/"production-ready" sin criterio | **Corregido** | Ciclo 10 · RF-006 (declaración verificable §0); `LICENSE` pendiente en R-8 |
| **H-19** | Estado singleton cross-token en módulos de compliance | Backlog | M-10 |
| **H-20** | Arrays O(n) y vistas sin paginación | Backlog | M-11 |
| **H-21** | Sin indexación de eventos ni artefactos de despliegue | **Parcial**: el Ciclo 9 persiste `sc/deployments/<chainId>-<timestamp>.json`; falta indexer | M-15, R-4 |
| **H-23** | Rúbrica de evaluación no operacional | **Corregido** | Ciclo 10 · RF-006 (rúbrica con comandos y umbrales en `EJERCICIOS_PRACTICOS.md`) |
| **H-24** | `deploy-besu.sh` parcial | **Corregido** | Ciclo 9 · RF-010 (`DeployFullStack.s.sol` + `deploy.sh`) |
| **H-25** | Falta stakeholder regulador/supervisor | Backlog | R-2 |
| **H-26** | Sin operador de red ni validación de `chainId` | **Corregido** | Ciclo 9 · D-055 (`deploy.sh` aborta si `CHAIN_ID` no coincide) |
| **H-27** | Sin soporte al inversor / recuperación auditable | **Parcial**: RF-004 añade whitelist/topes; falta actor de soporte | R-7 |
| **H-28** | Clave privada en claro en scripts | **Corregido** | Ciclo 9 · RF-010 (D-054/D-055; keystore efímero, sin `keys.json`) |
| **H-29** | El deploy no instancia/activa módulos de compliance | **Parcial**: Ciclo 9 despliega y activa `MaxBalanceCompliance` (`metricas_ejecucion.md` §17.2); generalización | M-14 |
| **H-30** | Sin backup/DR, RPO/RTO ni runbook | Backlog | R-5 |
| **H-31** | Éxito del deploy por `grep` de logs | **Corregido** | Ciclo 9 · D-056 (verificación con `cast code`/`cast call`) |
| **H-32** | Exactitud documental (`DEPENDENCIAS_CONTRATOS`, `metricas_ejecucion`) | **Parcial**: import inexistente de `IdentityCloneable` corregido en el Ciclo 10; `diccionario_datos.md` | QW-6 |
| **H-33** | Estado de fases/rama contradictorio | **Corregido** | Ciclo 10 · RF-006 (`RepoTecnico/estado_proyecto.md` actualizado) |
| **H-34** | Los cambios de `tokenContract` no emiten evento | Backlog | QW-8 |

**Recuento** (coherente con `RepoTecnico/requerimientos.md` §8.1): 34 hallazgos totales; tras el Ciclo 10
quedan **corregidos o parcialmente corregidos** los críticos/altos de seguridad y en **backlog** los
relacionados con gobernanza avanzada, cumplimiento regulatorio, privacidad, observabilidad, escalabilidad
y backup/DR.

## 3. Hallazgos-base (HB-01..HB-12) y su cierre

Los `HB-xx` provienen del análisis base (`RepoTecnico/requerimientos.md` §2).

| ID | Hallazgo base | Estado | Cierre |
|---|---|---|---|
| HB-01 | `addClaim()` no verifica la firma ECDSA | **Corregido** | RF-001 / Ciclo 2 (`test_RF001_addClaim_con_firma_valida`) |
| HB-02 | `burn()`/`forcedTransfer()` con poderes absolutos | **Parcial** | RF-004 / Ciclo 5 (topes + whitelist); multisig R-7 |
| HB-03 | Flag `bypassCompliance` sin guard anti-reentrancia | **Corregido** | RF-002 / Ciclo 3 (`test_RF002_storage_layout_sin_bypassCompliance`) |
| HB-04 | `addComplianceModule()` no valida `ICompliance` | **Corregido** | RF-003 / Ciclo 4 (`test_RF003_addComplianceModule_revierte_eoa`) |
| HB-05 | `lib/` ausente / Forge no instalado | **Corregido** | RF-005 / Ciclo 1 (submódulos pinneados + `foundry.lock`) |
| HB-06 | Storage muerto en `TokenCloneable` | **Corregido** | RF-005 / Ciclo 1 (`forge inspect … storage-layout`) |
| HB-07 | Docs referencian archivos inexistentes | **Corregido** | RF-006 / Ciclo 10 (`script/ci/check_docs.sh`) |
| HB-08 | `web-registry-trusted2` duplicado (zona web) | **Pausado** | D-003 (fuera de alcance) |
| HB-09 | Direcciones hardcodeadas en `rwa-web` | **Pausado** | D-003 (fuera de alcance) |
| HB-10 | No hay CI/CD | Backlog | RF-009 / Ciclo 11 |
| HB-11 | 151 tests no verificados en el entorno | **Corregido** | RF-005 / Ciclo 1; hoy **353/353** |
| HB-12 | `deploy-besu.sh` maneja clave privada en claro | **Corregido** | RF-010 / Ciclo 9 (D-054/D-055) |

## 4. Controles implementados (con su prueba)

1. **EIP-712 con nonce (RF-001 + RF-013).** `addClaim` exige `scheme == 1`, `signature.length == 65`,
   recuperación vía `ECDSA` de OpenZeppelin y `recovered == issuer != address(0)`; el digest incluye
   `walletOwner`, `topic`, `scheme`, `dataHash`, `expiresAt` y `nonce` (D-020, D-050). `revokeClaim` (solo el
   issuer) incrementa `claimNonce`, invalidando firmas previas. Pruebas: `test/IdentityCloneable.t.sol`
   (`test_RF001_*`) y `test/RF013_ClaimLifecycle.t.sol`.
2. **Fail-closed en `isVerified` (RF-011).** Sin `claimTopicsRegistry`, con topics vacíos o sin claim válido,
   devuelve `false` (`src/TokenCloneable.sol`, `isVerified`). Prueba: `test/RF011_FailClosed.t.sol`.
3. **Fail-closed en el aggregator (RF-012).** Con cero módulos para un token la operación se deniega y solo
   el admin del token gestiona sus módulos (`src/compliance/ComplianceAggregator.sol`). Prueba:
   `test/RF012_AggregatorFailClosed.t.sol`.
4. **ERC-165 (RF-003).** `supportsInterface` valida módulos en token y aggregator. Prueba:
   `test/RF003_ERC165.t.sol`.
5. **Whitelist, topes y `maxSupply` (RF-004/D-022).** `authorizedDestinations`, `maxBurnPerTx`,
   `maxForcedPerTx` y `maxSupply` (no puede bajar de `totalSupply()`). Prueba: `test/TokenLimits.t.sol` y
   `test_RF004_*`.
6. **Anti-reentrancia (RF-002/D-016).** `nonReentrant` en `transfer`/`transferFrom`/`forcedTransfer`/
   `mint`/`burn` y en las notificaciones del aggregator. Prueba: `test/TokenReentrancy.t.sol`;
   gate `script/ci/check_no_bypass_flag.sh`.
7. **Secretos fuera de los scripts (RF-010).** `sc/script/deploy.sh` lee la clave de variables de entorno o
   Secret Manager, firma con keystore efímero en modo 600 y verifica on-chain con `cast code`/`cast call`;
   `deploy-besu.sh` es un wrapper sin material de claves (D-054..D-057). Comprobación:
   `grep -rniE 'private[_-]?key|keys\.json' sc/script deploy-besu.sh` → 0 coincidencias de material real.
8. **Trazabilidad de ABIs (RF-006).** `sc/abis/<Contrato>.json` como línea base + `script/ci/abi_diff.sh`
   que falla ante deriva no declarada en `CHANGELOG_ABIS.md`.
9. **Gate de documentación (RF-006).** `script/ci/check_docs.sh` falla ante referencias inexistentes,
   afirmaciones sin matizar o ausencia de `SECURITY.md`/`CHANGELOG_ABIS.md`.

## 5. Riesgos residuales (declaración honesta)

1. **Sin auditoría externa.** El código no ha sido auditado por un tercero (H-16/R-9/D-024). **No es apto
   para producción con activos reales.**
2. **Gobernanza concentrada.** Los roles `DEFAULT_ADMIN_ROLE`, `AGENT_ROLE` y `COMPLIANCE_ROLE` pueden
   recaer en una sola EOA; no hay multisig ni timelock (H-06). El modelo objetivo está en D-021 y el
   backlog R-7.
3. **PII off-chain sin política formal.** Los documentos KYC viven en MongoDB/GridFS sin base legal,
   cifrado ni retención documentados (H-11).
4. **Sin pipeline de CI todavía.** Los gates `check_docs.sh`, `abi_diff.sh` y `check_no_bypass_flag.sh`
   existen y se ejecutan manualmente, pero RF-009 (`.gitlab-ci.yml`) sigue pendiente (H-04/HB-10).
5. **Claim topics no canónicos.** El catálogo de topics diverge entre documentos (H-13).
6. **Escalabilidad y observabilidad.** Arrays O(n), vistas sin paginación, sin indexer de eventos
   (H-12/H-20/H-21).

## 6. Política de reporte de vulnerabilidades

- **Canal:** abre un *issue* privado en el repositorio del proyecto o contacta al responsable técnico
  designado. **No publiques un exploit funcional** antes de que exista mitigación.
- **Contenido mínimo del reporte:** descripción, impacto, precondiciones, pasos de reproducción
  (comando `forge test` o PoC minimizado) y versión/commit afectado.
- **Acuse de recibo:** 3 días laborables; evaluación inicial en 10 días laborables.
- **Divulgación:** coordinada; el proyecto publicará la corrección y su entrada en
  [`CHANGELOG_ABIS.md`](CHANGELOG_ABIS.md) cuando el cambio afecte a ABIs, y actualizará este documento
  con el estado del hallazgo.
- **Alcance:** contratos de `rwa-sc/sc/src` y scripts de `rwa-sc/sc/script`. `rwa-web` queda fuera del
  alcance de los ciclos actuales (D-003).

---

*Última revisión: Ciclo 10 (RF-006). Fuente de los hallazgos: [`RepoTecnico/INFORME_OPTIMIZACION_V1.md`](RepoTecnico/INFORME_OPTIMIZACION_V1.md).*
