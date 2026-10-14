# 📊 Informe de Optimización — Área Contratos (`rwa-sc`)

> **Antes → Después de las Fases 1–4** · v1.0 · 2026-10-13
> **Alcance:** contratos y su ecosistema en `rwa-sc` (el área web queda fuera por D-003).
> **Fuentes:** `INFORME_OPTIMIZACION_V1.md` (estado inicial auditado), `metricas_ejecucion.md` (mediciones reales por ciclo),
> `auditoria_final.md` (revisión adversarial), `SECURITY.md`, `estado_proyecto.md` y los 31 commits de `rwa-sc-DSH-GCP`.
> **Nota de verificación:** todas las cifras de este informe salen de comandos ejecutados (`forge test`,
> `forge coverage`, `forge snapshot`, pipelines de GitLab) o de artefactos versionados; no hay estimaciones.

---

## 0. Resumen ejecutivo

| Indicador | ANTES (auditado) | DESPUÉS (verificado) |
|---|---|---|
| **Tests** | 151 declarados · 98 contados · **93 pasan, 5 fallan, 53 muertos** | **394 pasan, 0 fallan** (23 suites) |
| **Cobertura de `src/`** | ~**0 %** en los contratos núcleo (sus suites revertían) · 42,86 % total | **97,05 % líneas** · 86,13 % ramas · mínimo por contrato 91,53 % |
| **Invariantes con estado** | 0 | **19** (4 suites + handlers) — 0 violaciones reales |
| **Hallazgos de seguridad** | **1 crítica, 11 altas**, 18 medias, 4 bajas | Críticos y altos relevantes **cerrados**; 0 críticos abiertos |
| **CI/CD** | Ninguna (ni `.gitlab-ci.yml` ni Actions) | **7 jobs con gates** · **5 pipelines verdes** |
| **Repositorio** | 1 commit (`README.md`); árbol real sin versionar | **31 commits**, sincronizado en **3 remotos** (GitLab, GitHub, CodeCrypto) |
| **Despliegue** | Script parcial, éxito por `grep`, claves en claro | **Pila completa desplegada y verificada on-chain** (Anvil de GCP) con artefacto JSON |
| **Documentación** | Referencias rotas y cifras falsas ("139 tests", "production-ready") | `RepoTecnico/` versionado, `SECURITY.md`, `CHANGELOG_ABIS.md`, 15 ABIs baseline, runbook, matriz |
| **Ahorro de gas publicitado** | 88–98 % (sin respaldo) | **45–59 %** medido con comparación equivalente |

---

## 1. Línea base: qué se encontró (ANTES)

El análisis y la auditoría de 3 fases (7 lentes) sobre el estado inicial identificaron:

1. **Un fallo crítico de seguridad**: `addClaim()` **no verificaba ninguna firma**; un inversor podía auto-emitir su
   propio KYC (`test_ForgedClaimEmptySignature` reproducido). Cadena de consecuencias: `isVerified()` **fail-open**
   sin `claimTopicsRegistry`; aggregator **fail-open** con 0 módulos.
2. **La red de seguridad no existía**: 2 suites revertían en `setUp` por `InvalidInitialization()`
   (usaban `new TokenCloneable()` + `initialize` con los inicializadores desactivados en el constructor), lo que
   dejaba **53 tests sin ejecutar**; 3 tests de ahorro de gas comparaban magnitudes no equivalentes y desbordaban.
3. **Cifras públicas falsas**: "139 tests (100 % passing)", "coverage > 80 %", "production-ready",
   "ERC-3643 compliant" y ahorros de gas del 88–98 % **sin ninguna medición**.
4. **Operación insegura**: `deploy-besu.sh` leía la clave de `~/.foundry/keys.json`, decidía el éxito con `grep`
   de logs y **no desplegaba** los registries ni el token.
5. **Gobernanza concentrada**: una sola EOA con los tres roles (`DEFAULT_ADMIN`, `AGENT`, `COMPLIANCE`),
   `AGENT_ROLE` podía quemar o mover el saldo de cualquiera sin límite, y `forcedTransfer(0, …)` **acuñaba**.
6. **Sin trazabilidad**: sin CI, sin changelog de ABIs, sin política de seguridad, documentación con referencias a
   archivos inexistentes (`Token.sol`, `Identity.sol`, `.md` que no existían) y sin versionar en el repositorio.

> Detalle completo: [`INFORME_OPTIMIZACION_V1.md`](INFORME_OPTIMIZACION_V1.md) (34 hallazgos + 12 del análisis base).

---

## 2. Dimensión LÓGICA — qué hace distinto el sistema

Cambios de comportamiento del código (contrato por contrato). La columna "Evidencia" apunta a la prueba que lo verifica.

| Componente | ANTES | DESPUÉS | Ciclo | Evidencia |
|---|---|---|---|---|
| `IdentityCloneable.addClaim` | Acepta cualquier claim: **no verifica firma**, `scheme` decorativo, sin vigencia ni revocación | **EIP-712 verificado**: dominio `{RWA-Identity, 1, chainId, clon}`, `CLAIM_TYPEHASH` con `walletOwner`, `dataHash`, `expiresAt`, **`nonce`** y **`uriHash`**; `ECDSA.tryRecover` con maleabilidad; `walletOwner == owner()` | 2 y 8c, AF-03 | `test_RF001_*` (21) · `test_AF03_*` |
| `IdentityCloneable` (ciclo de vida) | Sin `expiresAt` ni `revoked`; `removeClaim` era la única baja (titular) | `expiresAt` **firmado** (`0` = perpetuo, D-038), `revoked`, `revokeClaim` **solo el issuer**, `hasValidClaim()` como fuente de verdad, **nonce que la revocación incrementa** (anti-replay) | 8 y 8c | `test_RF013_*` (16) |
| `TokenCloneable.isVerified` | **Fail-open**: sin `claimTopicsRegistry` devolvía `true`; aceptaba cualquier claim del issuer | **Fail-closed**: `false` sin registry o sin topics; exige claim **existente, no revocado y vigente** de un issuer autorizado por topic | 6 y 8 | `test_RF011_*` (6) · PoC invertido |
| `ComplianceAggregator` | Con **0 módulos permitía todo**; el owner global podía tocar módulos de cualquier token | **Fail-closed**: deniega sin módulos o sin token registrado; **gestión solo por el token** (`"Only token admin can call"`); registro automático al primer módulo | 7 | `test_RF012_*` (8) |
| `TokenCloneable` (módulos) | `addComplianceModule` no validaba nada; un módulo mal configurado podía **bloquear el token** | Exige **ERC-165** (`supportsInterface`) y que el módulo esté **vinculado a este token** (`tokenContract() == this`); los módulos leen el token de forma **defensiva** (degradan a `false`, no revierten); **sin módulos = sin transferencias** | 4 y AF-01/AF-05 | `test_RF003_*` (16) · `test_AF01_*` · `test_AF05_*` |
| `TokenCloneable` (poderes del agente) | `AGENT_ROLE` absoluto: `burn`/`forcedTransfer` sin tope y a cualquier destino; `forcedTransfer(0,…)` acuñaba | **Whitelist de destinos** (fail-closed), **topes por operación** (`maxBurnPerTx`, `maxForcedPerTx`; `0` desactiva) y **`maxSupply`** administrable; `from == 0` rechazado | 3, 5 | `test_RF004_*` (17) · `test_RF002_*` |
| `TokenCloneable` (reentrancia) | Flag mutable `bypassCompliance` durante la transferencia forzada → ventana de bypass | Flag **eliminado**; ruta explícita `_forcedUpdate`; **`nonReentrant` en los 5 puntos de entrada** y en el aggregator | 3 | 7 tests de reentrancia |
| `TokenCloneable` (pausa/congelación) | `mint`/`burn`/`forcedTransfer` ignoraban pausa y congelación | `mint`/`burn` con `whenNotPaused`; `mint` rechaza destinos congelados; `forcedTransfer` sigue operativo en pausa (recuperación de emergencia) | AF-02 | `test_AF02_*` (5) |
| Registries (`IdentityRegistry`, `TrustedIssuersRegistry`, `ClaimTopicsRegistry*`) | Aceptaban EOA como identidad, topic `0`, y `removeIdentity` no comprobaba pertenencia | Validan que la identidad sea **contrato** (HB-13), rechazan **topic 0** (HB-15) y verifican **pertenencia** al borrar (HB-14) | 4 y 8 | `test_HB13_*`, `test_HB15_*`, `test_HB14_*` |
| `deploy.sh` / `DeployFullStack` | `deploy-besu.sh`: claves en `keys.json`, éxito por `grep`, despliegue parcial | Script **canónico y parametrizado**, **valida la red antes del broadcast**, firma con **keystore efímero** (sin clave en `argv`), verifica con `cast code`/`cast call`, **smoke test de operatividad** y artefacto JSON | 9 y AF-07 | `sc/deployments/31337-*.json` |

---

## 3. Dimensión ADMINISTRATIVA — cómo se gobierna, opera y controla

| Área | ANTES | DESPUÉS |
|---|---|---|
| **Gobernanza y roles** | Una EOA con los tres roles; sin custodio ni rotación | **D-021**: roles separados (admin en multisig, `AGENT_ROLE` operativo con límites, `COMPLIANCE_ROLE` independiente), **multisig 2-de-3 + timelock** y **custodio de claves con rotación** como objetivo; los poderes del agente ya están acotados por código |
| **Ciclo de vida del despliegue** | Redeploy manual, sin runbook, direcciones por `grep` | **D-019 / `RUNBOOK_MIGRACION.md`**: orden de despliegue, configuración obligatoria (registries, límites, whitelist, topics, issuers), verificación con `cast`, actualización de consumidores y rollback |
| **Secretos** | Clave privada en `~/.foundry/keys.json` y en `deploy-besu.sh` | **D-040/D-054**: clave solo por entorno/Secret Manager (`DS_*`), **keystore efímero** (sin `argv`), gate `check_secrets.sh` que falla con claves/tokens en archivos versionados |
| **Integración continua** | Ninguna | **`.gitlab-ci.yml`** con 7 jobs: `validate` (submódulos pinneados) · `build` · `fmt` · `test` · `coverage` (agregado **y** por contrato) · `gas` (tolerancia 5 %) · `ci-checks` (5 gates) |
| **Trazabilidad de ABIs** | Ninguna; las apps web tenían ABIs copiadas a mano | `CHANGELOG_ABIS.md` (cambios por ciclo con selectores) y **baseline de 15 ABIs** con gate que **exige modificar el changelog en el mismo commit** que la ABI |
| **Documentación** | Cifras falsas, referencias a archivos inexistentes, sin política de seguridad | **Documentación veraz** (D-058): cifras medidas y enlazadas a su artefacto; `SECURITY.md` (modelo de amenazas, 34 hallazgos con estado, riesgos residuales, política de reporte); gate `check_docs.sh` que exige que cada mitigación cite un test real |
| **Gestión del conocimiento** | Sin casos de uso ni criterios | `RepoTecnico/` versionado: **17 CU con 142 criterios** Gherkin/EARS, **matriz criterio→prueba** (0 huecos), plan por ciclos, documento técnico y decisiones **D-001…D-087** |
| **Control de calidad** | 151 tests de los que 58 no servían; sin cobertura del núcleo | **394 tests** + **19 invariantes**; cobertura `src/` 97,05 % (mín. 91,53 %); **2 rondas de auditoría externa simulada** (34 y 15 hallazgos) con verificación adversarial |
| **Despliegue operativo** | Sin artefactos; se asumía éxito | **Pila completa en el Anvil de GCP** (10 contratos) verificada on-chain; artefacto con direcciones, `chainId`, bloque y 10 ABIs; `main` intacta y todo el trabajo en `rwa-sc-DSH-GCP` |
| **Distribución del código** | Solo `main` con `README.md`; GitHub vacío; CodeCrypto desincronizado | **3 remotos sincronizados** en el mismo commit (`GitLab`, `GitHub`, `CodeCrypto`) con historia compartida (se preservó su `Initial commit` mediante merge no destructivo) |

---

## 4. Dimensión CARACTERÍSTICA — propiedades medibles del sistema

### 4.1 Métricas antes → después

| Propiedad | ANTES | DESPUÉS | Cómo se mide |
|---|---|---|---|
| Tests ejecutables | 98 (93 ✓ / 5 ✗) | **394 (394 ✓)** | `forge test` |
| Tests muertos | 53 | **0** | `forge test --list` vs ejecución |
| Suites que revierten en `setUp` | 2 | **0** | salida de `forge test` |
| Invariantes con estado | 0 | **19** | `grep -c 'function invariant_' sc/test/invariant/*.sol` |
| Cobertura `src/` (líneas) | 42,86 % total; núcleo ~0 % | **97,05 %** | `forge coverage --report summary` |
| Cobertura ramas | 35,68 % | **86,13 %** | idem |
| Cobertura mínima por contrato | 1,56 % (`ComplianceAggregator`) | **91,53 %** (`ClaimTopicsRegistryCloneFactory`) | gate `check_coverage.sh` |
| Determinismo de la suite | Fuzz sin semilla (gas inestable) | **`[fuzz] seed` fija** + `.gas-snapshot` con tolerancia 5 % | `forge snapshot --check --tolerance 5` |
| Ahorro de gas EIP-1167 | 88–98 % (publicitado) | **45–59 %** (Token 55 % · Identity 59 % · +claim 45 % · Registry 53 %) | benchmarks equivalentes en `sc/test/benchmarks/` |
| Contratos en `src/` | 15 (12 útiles + 3 de testing) | **15** (todos con suite; storage muerto eliminado) | inventario + tests de layout |
| Avisos de lint (Forge) | 52 (19 reentrancia-eventos, 14 bucles, 5 reentrancia, …) | **Reentrancia eliminada** en los caminos de transferencia; bucles documentados como O(n) en backlog | `forge lint` |
| Cobertura de criterios de aceptación | Inexistente | **142/142 con prueba** (0 FALTA) | `matriz_criterios.md` |
| Pipelines verdes | 0 | **5** (7/7 jobs cada uno) | API de GitLab |
| Commits versionados | 1 (`README.md`) | **31** | `git rev-list --count` |

### 4.2 Propiedades cualitativas ganadas

- **Fail-closed por defecto** en las tres puertas de acceso: `isVerified` (RF-011), aggregator (RF-012) y array de
  módulos del token (AF-05). Un sistema mal configurado **deniega**, no permite.
- **No repudio del claim**: el issuer firma titular, topic, esquema, datos, **vigencia, nonce y URI**; el titular no
  puede alterar ninguno después de la firma, ni reutilizar una firma revocada.
- **Recuperación acotada**: las operaciones de emergencia siguen disponibles (incluso en pausa), pero solo a
  destinos **autorizados explícitamente** y dentro de **topes** configurables.
- **Trazabilidad extremo a extremo**: cada cambio tiene ciclo, requisito, caso de uso, test, decisión y entrada en
  el changelog de ABIs; cada afirmación pública tiene un artefacto que la respalda.
- **Reproducibilidad**: toolchain fijado (`solc 0.8.20`, optimizer 200, `evm paris`), dependencias pinneadas por
  revisión, fuzz con semilla, bootstrap documentado (`--recurse-submodules`).

### 4.3 Hallazgos cerrados (mapa rápido)

| Origen | Cerrados | Ejemplos |
|---|---|---|
| Informe V1 | **H-01** (crítica), H-02, H-04, H-05, H-08, H-15, H-16, H-17, H-18, H-22, H-23, H-24, H-26, H-28, H-31, H-33 | forja de claims, fail-opens, reentrancia, módulos sin validar, docs falsas, secretos |
| Análisis base | HB-02..HB-05, HB-11, HB-13..HB-15 | poderes del agente, bypass, lib ausente, identidad EOA, topic 0 |
| Auditoría adversarial (Fase 4) | **AF-01** (alta), AF-02, AF-03, AF-05, AF-06..AF-11, AF-13, AF-15 | módulo que bloqueaba el token, pausa/congelación, `uri` sin firmar, fail-closed del array |
| Detectados por el proceso | Acuñación por `forcedTransfer(0,…)` · **bypass de la revocación por replay** · 3 bugs de los propios gates de CI | correcciones con test de regresión |

**Diferido y declarado** (no bloquea la entrega interna): AF-04 (front-running del alta de identidad → ciclo web),
AF-12 (`removeClaim`/nonce), AF-14 (escaneo `.md`), catálogo ISO 25010 (AML/sanciones, PII/GDPR, observabilidad,
backup/DR), multisig efectivo y **auditoría externa** — condición para producción con activos reales (D-024).

---

## 5. Trazabilidad: dónde se verifica cada afirmación de este informe

| Afirmación | Artefacto que la respalda |
|---|---|
| Estado inicial y hallazgos | [`INFORME_OPTIMIZACION_V1.md`](INFORME_OPTIMIZACION_V1.md) · [`metricas_ejecucion.md`](metricas_ejecucion.md) §1–§6 |
| Métricas por ciclo y gates | [`metricas_ejecucion.md`](metricas_ejecucion.md) §7–§24 |
| Criterios de aceptación | [`casos_uso/casos_uso.md`](casos_uso/casos_uso.md) (v1.4) · [`pruebas/matriz_criterios.md`](pruebas/matriz_criterios.md) (v2) |
| Revisiones adversariales | [`pruebas/auditoria_final.md`](pruebas/auditoria_final.md) · [`casos_uso/AUDITORIA_CASOS_USO.md`](casos_uso/AUDITORIA_CASOS_USO.md) |
| Seguridad y riesgos residuales | [`SECURITY.md`](../SECURITY.md) |
| Cambios de interfaz | [`CHANGELOG_ABIS.md`](../CHANGELOG_ABIS.md) + baseline `sc/abis/` |
| Despliegue y migración | [`RUNBOOK_MIGRACION.md`](../RUNBOOK_MIGRACION.md) · `sc/deployments/31337-20261010T162639Z.json` |
| Decisiones del proyecto | `requerimientos.md` (Bloques 1–6b) · `estado_proyecto.md` (**D-001…D-087**) |
| CI en ejecución real | Pipelines de GitLab `2934202154`, `2934241152`, `2935871780`, `2944641183`, `2944742665` (7/7 jobs) |

---

## 6. Conclusión

El área de contratos pasó de ser un **prototipo educativo con la red de seguridad desactivada** (tests muertos,
cifras falsas, fallo crítico de forja de claims y despliegue inseguro) a un **sistema endurecido, medido y
auditado**, con:

- **394 tests y 19 invariantes** en verde, cobertura del 97 % y determinismo de gas;
- **fail-closed** en las tres puertas de acceso y control efectivo de los poderes del agente;
- **CI con 7 gates** ejecutándose en la nube (5 pipelines verdes) y trazabilidad de ABIs;
- **documentación veraz**, política de seguridad y runbook de migración;
- **despliegue verificado on-chain** y el mismo commit replicado en tres remotos.

Sigue **sin ser apto para producción con activos reales** (D-024) hasta cerrar el backlog regulatorio/operativo
(AML, PII, observabilidad, backup/DR), efectivizar el multisig y superar una **auditoría externa**.
