# INFORME DE OPTIMIZACIÓN V1 — Auditoría RWA (ERC-3643)

**Proyecto:** RWA — plataforma de tokenización de activos (security token inspirado en ERC-3643 / T-REX)
**Alcance auditado:** `rwa-sc/` (contratos Solidity, tests, scripts y documentación) y `RepoTecnico/`
**Fecha de síntesis:** consolidación de la Fase 3 sobre las verificaciones adversariales R1–R7
**Versión del informe:** V1

---

## 1. Resumen ejecutivo

### Veredicto explícito

| Pregunta | Veredicto |
|---|---|
| ¿Apto para producción / uso con KYC y activos reales? | **NO. No apto para producción en su estado actual.** |
| ¿Apto para continuar a la fase de desarrollo de mejoras? | **SÍ. Apto para continuar, con condiciones.** El diagnóstico está cerrado y las mitigaciones ya están mapeadas a RF-001…RF-010 y RNF-002/003/004, por lo que el defecto dominante es de **implementación**, no de falta de análisis. |

**Justificación del veredicto negativo.** El sistema no puede acreditar las garantías que publica. Un inversor registrado puede **auto-emitir claims de KYC/acreditación/jurisdicción sin firma válida** y quedar `isVerified == true` (hallazgo H-01, reproducido con PoC en Forge por R4, R5, R6 y R7); si el token no tiene `claimTopicsRegistry`, `isVerified()` devuelve `true` para cualquier wallet registrada, saltándose todo el control de identidad (H-05). A esto se suma que la red de seguridad declarada **no existe en los hechos**: la documentación publica "139 tests (100% passing)" y "production-ready", mientras el conteo real es de 151 funciones de test de las cuales solo 93 pasan, 5 fallan y 53 **nunca llegan a ejecutarse** porque dos suites núcleo revierten en `setUp` con `InvalidInitialization()`; la cobertura medida es **42,86 % de líneas** frente al objetivo ≥ 80 % (H-02).

**Justificación del veredicto positivo para continuar a mejoras.** El núcleo del sistema (nombres de contratos, factories, patrón EIP-1167, estructura de documentos) es internamente consistente; los cuatro verificadores que reejecutaron la suite (R1, R4, R5, R7) reprodujeron idéntico resultado (`93 passed, 5 failed, 0 skipped, 98 total`), y ya existe en `RepoTecnico/requerimientos.md` el plan de mitigación (H-01…H-12 → RF-001…RF-010). La corrección de los hallazgos críticos y altos es acotada y verificable.

### Cifras de la consolidación

- **Hallazgos verificados consolidados: 34** (1 crítico, 11 altos, 18 medios, 4 bajos).
- **Duplicados entre lentes deduplicados:** el mismo hecho aparecía en 2–6 dimensiones (p. ej. la forja de claims en R4, R5, R6 y R7; el "139/100 %" en R1, R2, R3, R4, R5, R6 y R7; la reproducibilidad del build en R1, R2, R3, R5 y R6).
- **Falsos positivos descartados en Fase 2:** 12 (entre ellos `requerimientos.md` corrupto, reentrancia del flag `bypassCompliance`, front-running del `initialize` de clones y el vector de storage layout en ausencia de proxy actualizable).

---

## 2. Metodología

### 2.1 Estructura en 3 fases

| Fase | Objetivo | Resultado |
|---|---|---|
| **Fase 1 — Revisión multidimensional (7 lentes)** | 7 revisores independientes examinan el repositorio cada uno con una lente distinta: (1) Ambigüedad y testabilidad, (2) Consistencia documental, (3) Completitud RNF / ISO 25010, (4) Stakeholders, (5) Trazabilidad con el brief, (6) Riesgos técnicos, (7) Seguridad y legal. | 12 hallazgos candidatos por lente (≈ 84 candidatos brutos). |
| **Fase 2 — Verificación adversarial** | Cada hallazgo se contrasta contra los archivos reales (`read`/`grep`/`glob`), se reejecuta lo reproducible en copias aisladas y se aplica la **regla de descarte**. | 7 verificadores R1–R7; sobreviven 10 hallazgos por lente tras deduplicar, fusionar y ajustar severidades. |
| **Fase 3 — Síntesis** | Deduplicación entre lentes, asignación de IDs únicos `H-01…`, priorización por severidad y redacción de este informe. | 34 hallazgos únicos priorizados. |

### 2.2 Las 7 lentes

1. **Ambigüedad / testabilidad** — criterios de aceptación medibles y falsables.
2. **Consistencia** — coherencia entre documentos, código y métricas.
3. **Completitud RNF (ISO 25010)** — cobertura de las categorías de calidad.
4. **Stakeholders** — actores definidos, responsables y ausentes.
5. **Trazabilidad** — correspondencia brief ↔ requisitos ↔ casos de uso ↔ implementación.
6. **Riesgos técnicos** — seguridad on-chain, arquitectura, escalabilidad, reproducibilidad.
7. **Seguridad y legal** — explotabilidad, cumplimiento normativo y protección de datos.

### 2.3 Regla de descarte

> **Ante la duda, se descarta.** Un hallazgo solo sobrevive si (a) se reproduce o se verifica directamente contra un archivo real con `ruta:línea`, (b) tiene impacto verificable sobre el alcance auditado, y (c) no es un artefacto del entorno de auditoría ni un sub-claim ya contenido en otro hallazgo.

**Premisas del encargo corregidas en Fase 2 (hecho de entorno obsoleto, NO hallazgo):** la afirmación de que "Foundry no está instalado" y "`sc/lib/` no existe" es **falsa en el estado actual**. Se verificó que `/home/dsh/.foundry/bin/forge` v1.8.3 existe (fuera del `PATH`) y que `rwa-sc/sc/lib/` contiene los tres submódulos clonados (forge-std v1.12.0, OZ v5.5.0, OZ-upgradeable v5.5.0), coherentes con `foundry.lock`. **Por tanto la suite sí se compiló y ejecutó durante la auditoría** (resultado reproducido por R1, R4, R5 y R7). El bloqueo real de reproducibilidad es de control de versiones y CI (ver H-04), no de toolchain.

### 2.4 Cautela metodológica

En ninguna fase se editó código fuente ni documentación del proyecto. Las ejecuciones de `forge test` / `forge coverage` se realizaron sobre copias aisladas en `/tmp` (R4, R5, R7) o regenerando únicamente artefactos de build gitignored en `sc/out` y `sc/cache` (R1). El conteo de "53 tests muertos" procede de `RepoTecnico/metricas_ejecucion.md`; el recuento propio de funciones en las dos suites afectadas da **55** (30 en `Token.t.sol` + 25 en `ComplianceAggregator.t.sol`). El informe registra ambas cifras y prioriza la medición directa (55).

---

## 3. Estado de calidad y métricas reales disponibles

### 3.1 Brecha de verificación (declaración obligatoria)

> **Durante la auditoría original se reportó que no fue posible ejecutar los tests por ausencia de Foundry y de `sc/lib/`. Esa premisa resultó OBSOLETA:** verificado en esta sesión, `forge` v1.8.3 existe y `sc/lib/` está poblada, por lo que varios verificadores **sí ejecutaron la suite**. No obstante, **la suite no pasa en verde y el pipeline de CI no existe**, de modo que los resultados siguientes son **mediciones puntuales reproducidas en el entorno de auditoría**, no resultados de un pipeline automatizado ni un artefacto de release. Deben tratarse como **brecha de verificación abierta** hasta que exista CI (H-04).

### 3.2 Métricas reales medidas

| Métrica | Valor real verificado | Objetivo declarado | Estado |
|---|---|---|---|
| Funciones de test declaradas | **151** (8 suites) | — | La tabla de `README.md` lista solo 7 suites (omite `ClaimTopicsRegistryCloneFactory.t.sol`, 12 tests) |
| Tests ejecutados | **98** | 151 | 53 nunca arrancan (55 según recuento directo de las 2 suites muertas) |
| Tests que pasan | **93** | 100 % | ❌ |
| Tests que fallan | **5** (3 de ahorro de gas + `setUp` de 2 suites) | 0 | ❌ |
| Cobertura de líneas | **42,86 %** (339/791) | ≥ 80 % (RNF-002) | ❌ |
| Cobertura de ramas / sentencias | 35,68 % / 38,25 % | — | ❌ |
| Cobertura de `ComplianceAggregator.sol` | 1,56 % | — | ❌ |
| Cifra publicada en docs | "139 tests (100 % passing)" | — | ❌ **Falsificada por medición** |
| Scripts `.s.sol` | **6** | 4 (README/START_HERE) / 5 (requerimientos) | ❌ Inconsistente |
| Contratos `.sol` en `src/` | **15** | 11 (requerimientos.md:11) | ❌ Inconsistente |
| CI | **no existe** (ni `.github/` ni `.gitlab-ci.yml`) | RF-009 | ❌ |
| `solc` fijado | **no** (pragma `^0.8.20`; artefactos compilados con 0.8.28) | reproducibilidad | ❌ |
| `.gas-snapshot` versionado | **no existe** | RNF-001 | ❌ |
| Repositorio versionado | HEAD = 1 commit (`2a4a683`) con **solo `README.md`** | RF-005/RF-009 | ❌ |

**Resultado reproducido (R1, R4, R5, R7):** `cd rwa-sc/sc && forge test` → `Ran 8 test suites ... 93 tests passed, 5 failed, 0 skipped (98 total tests)`.

**Causa raíz de las suites muertas:** `test/Token.t.sol` y `test/ComplianceAggregator.t.sol` ejecutan `new TokenCloneable()` / `new IdentityCloneable()` + `initialize()` en `setUp`, pero los constructores llaman `_disableInitializers()`, por lo que `initialize()` revierte con `InvalidInitialization()` y mata la suite completa.

---

## 4. Tabla de hallazgos por severidad

### 4.1 Críticos (1)

| ID | Dimensión | Título | Evidencia |
|---|---|---|---|
| **H-01** | Seguridad / Trazabilidad KYC-AML | Claims auto-forjados: `addClaim` no verifica firma y `isVerified` solo cruza el issuer con el registry | `src/IdentityCloneable.sol:63-98`; `src/TokenCloneable.sol:229-281`; `src/IdentityCloneFactory.sol:72-103`; PoC `test_ForgedClaimEmptySignature` PASS; `grep ecrecover\|EIP712` en `src/` → sin coincidencias; R4-1, R5-1, R6-1, R7-1 |

### 4.2 Altos (11)

| ID | Dimensión | Título | Evidencia |
|---|---|---|---|
| **H-02** | Tests / Documentación | "139 tests (100 % passing)" es falso: 151 declarados, 93 pasan, 5 fallan, 53 (55) no arrancan; cobertura 42,86 % | `README.md:24,138,260,368`; `START_HERE.md:12,491`; `metricas_ejecucion.md:29-35,65-72`; ejecución propia 93/5/98 |
| **H-03** | Métricas de gas / RNF-001 | Cifras de ahorro contradictorias (39 %, 88–98 %, 90,2 %, 96,5 %), tests de gas rotos y benchmarks sin medir; RNF-001 no verificable | `README.md:272`; `ARQUITECTURA_FINAL.md:188-192`; `OPTIMIZACION_VERIFICACION.md:42,108,159,254`; `TokenCloneFactory.t.sol:142-160`; `TokenCloneFactory.sol:168-170`; sin `.gas-snapshot` |
| **H-04** | Reproducibilidad / VCS / CI | Código no versionado (HEAD solo README), `.gitmodules` contradictorios, `lib/` gitignored, sin pin de `solc` ni CI; docs de entorno obsoletas | `git ls-files` → solo README; `rwa-sc/.gitmodules` (3) vs `rwa-sc/sc/.gitmodules` (1); `rwa-sc/.gitignore:5`; `foundry.toml:1-10`; `entornos_globales.md:93-95` |
| **H-05** | Compliance / Semántica de `isVerified` | Fail-open: `isVerified` devuelve `true` si `claimTopicsRegistry == address(0)` | `src/TokenCloneable.sol:245-247`; `TokenCloneFactory.sol:87-135`; PoC `test_FailOpenNoClaimTopicsRegistry` PASS; R1-9, R4-5, R5-6, R6, R7-2 |
| **H-06** | Seguridad / Gobernanza | Una sola EOA acumula `DEFAULT_ADMIN_ROLE`+`AGENT_ROLE`+`COMPLIANCE_ROLE`; `burn`/`forcedTransfer` sin límites ni whitelist; sin custodio de claves | `src/TokenCloneable.sol:77-79,195-224`; `ComplianceAggregator.sol:50-53`; `deploy-besu.sh:13-14,37,86`; `casos_uso.md:15-24`; R4-2, R6-6, R7-3 |
| **H-07** | Arquitectura / Control de acceso | Factories permissionless; `createRegistryForToken` es "primer llamador gana"; implementation EIP-1167 inmutable sin ruta de upgrade ni runbook de migración | `TokenCloneFactory.sol:51-74`; `ClaimTopicsRegistryCloneFactory.sol:70-92`; `IdentityCloneFactory.sol:43-59`; `IdentityCloneFactory.sol:17,27`; R4-3, R6-5 |
| **H-08** | Ciclo de vida de claims | Los claims no expiran ni pueden revocarse por el issuer; `removeClaim` es `onlyOwner` del propio titular | `src/IdentityCloneable.sol:21-28,105-123`; `src/TokenCloneable.sol:249-281`; `VERIFICACION_TRUSTED_ISSUER.md:377`; R5-2, R7-7 |
| **H-09** | Completitud RNF / ISO 25010 | El catálogo RNF solo cubre 5 requisitos aplicables (gas, cobertura, tests, secretos, extensibilidad) y omite 6 de las 9 categorías ISO 25010 | `requerimientos.md:52-61`; `casos_uso.md:755-762`; sin RNF de fiabilidad, mantenibilidad, portabilidad, observabilidad, backup/DR ni usabilidad |
| **H-10** | Cumplimiento regulatorio | No existe RNF ni control de screening de sanciones/PEP/AML ni retención/reporte regulatorio para un security token | `requerimientos.md:52-61`; `diccionario_datos.md:99-106`; `grep sanciones\|PEP\|OFAC\|GDPR` sin coincidencias; R3-2, R5-3 |
| **H-11** | Datos personales / Custodia | PII y documentos KYC en MongoDB/GridFS sin custodio, base legal, cifrado, retención ni borrado; `data`/`uri` on-chain inmutables | `diccionario_datos.md:63-96`; `diagrama_er.md:73-88`; `IdentityCloneable.sol:21-28,63-86`; R4-4, R7-5 |
| **H-12** | Observabilidad / Monitoreo | No hay RNF de observabilidad ni indexación pese a que el token emite eventos de dominio críticos | `requerimientos.md:52-61`; `TokenCloneable.sol:35-41`; `IdentityRegistry.sol:22-24`; `ComplianceAggregator.sol:41-43`; R3-5, R6-9 |

### 4.3 Medios (18)

| ID | Dimensión | Título | Evidencia |
|---|---|---|---|
| **H-13** | Modelo de datos / Claims | Catálogo de claim topics no canónico y divergente (1/2/3/4 vs 1/7/9 vs 1/2/3/9/10 vs 5/6/7) | `ARQUITECTURA_FINAL.md:65`; `REFERENCIA_TECNICA.md:823-833`; `diccionario_datos.md:99-106`; `Token.t.sol:34-35`; R1-5, R2-5, R5-3 |
| **H-14** | Modelo de datos | `diccionario_datos.md` describe campos de storage que no existen (`holders[]`, `holderIndex[]`, `firstReceiveTime`, `issuerTopics`) | `diccionario_datos.md:24-27,56-61`; `MaxHoldersCompliance.sol:14-26`; `TransferLockCompliance.sol:14-23`; R1-4, R2-8 |
| **H-15** | Documentación | Documentos y contratos citados como existentes que no existen (`TOKEN_CLONE_FACTORY.md`, `Token.sol`, `Identity.sol`, resúmenes de sesión, etc.) | `README.md:49,97,213-215`; `START_HERE.md:169,191-192,481-484`; `ARQUITECTURA_FINAL.md:17`; `ls` → todos inexistentes; R2-6 |
| **H-16** | Afirmaciones de conformidad | "ERC-3643 compliant" y "production-ready" sin criterio, versión de spec, ERC-165, test de conformidad, auditoría, `SECURITY.md` ni `LICENSE` | `README.md:21,25`; `TokenCloneable.sol:15`; `grep ERC165/supportsInterface` sin coincidencias; R1-8, R2-4, R7-6 |
| **H-17** | Validación de módulos | `addComplianceModule` / `addModule` no validan la interfaz `ICompliance` (sin ERC-165): DoS o bypass | `TokenCloneable.sol:119-123`; `ComplianceAggregator.sol:61-79`; `grep supportsInterface` sin coincidencias; H-04/RF-003; R6-4, R7-9 |
| **H-18** | Seguridad / Reentrancia | Callbacks externos post-actualización (`transferred`/`created`/`destroyed`) sin `ReentrancyGuard` | `TokenCloneable.sol:186-189,198-201,220-223,324-327`; `grep ReentrancyGuard\|nonReentrant` sin coincidencias; R6-4 |
| **H-19** | Escala / Estado cross-token | Módulos de compliance con estado singleton y un único `tokenContract` pueden compartirse entre tokens vía aggregator | `ComplianceAggregator.sol:20,61-79`; `MaxBalanceCompliance.sol:17,49-62`; `MaxHoldersCompliance.sol:20,108-135`; `TransferLockCompliance.sol:17`; R6-7 |
| **H-20** | Escala / Gas | Arrays no acotados con borrado O(n) y vistas sin paginación en registros y factories → gas creciente y DoS operativo | `IdentityRegistry.sol:20,73-79`; `TrustedIssuersRegistry.sol:19,55-61`; `ClaimTopicsRegistry.sol:44-50`; `TokenCloneFactory.sol:20-23`; R6-8 |
| **H-21** | Indexación / Integración | Sin capa de indexación de eventos ni persistencia de artefactos de despliegue (solo `stdout`) | `deploy-besu.sh:191-204`; `ls sc/broadcast` → no existe; `grep indexer\|subgraph\|getLogs` sin resultados; R5-8, R6-9 |
| **H-22** | Arquitectura de compliance | `ComplianceAggregator` es fail-open (0 módulos = permitir) y su owner global puede gestionar módulos de cualquier token | `ComplianceAggregator.sol:50-53,61,87,115-135`; PoC `test_AggregatorFailOpenNoModules` PASS; R6-6, R7-8 |
| **H-23** | Rúbrica de evaluación | Criterios de calificación no operacionales ("gas optimizado", "documentación completa", "sin warnings de seguridad") sin umbral | `EJERCICIOS_PRACTICOS.md:731-741,762-791`; R1-6 |
| **H-24** | Trazabilidad de despliegue | `deploy-besu.sh` es parcial: no despliega `IdentityRegistry`, `TrustedIssuersRegistry` ni ningún token | `deploy-besu.sh:83-207`; `CompleteDeploymentExample.s.sol:84,88`; `ARQUITECTURA_FINAL.md:52-117`; R5-8 |
| **H-25** | Stakeholders | No existe actor regulador/supervisor ni mecanismo de reporte, snapshot de holders o exportación de eventos | `casos_uso.md:15-24`; `requerimientos.md:52-62`; `grep regulador` sin coincidencias; R4-8 |
| **H-26** | Stakeholders / Red | No se define operador de la red Besu ni se valida `chainId` antes de desplegar; RPC hardcodeado | `deploy-besu.sh:13,61-68`; `entornos_globales.md:43`; R4-9 |
| **H-27** | Stakeholders / Recuperación | Sin actor de soporte al inversor ni proceso auditable de recuperación; `forcedTransfer` sin `authorizedDestinations` ni topes | `TokenCloneable.sol:204-224,46-47`; `requerimientos.md:21,44`; `casos_uso.md:15-24`; R4-10 |
| **H-28** | Gestión de secretos | Clave privada en claro desde `~/.foundry/keys.json` y pasada por `--private-key` a `argv`/entorno | `deploy-besu.sh:13-14,30-37,86,110,114,142,169`; H-12/RF-010; R6-10, R7-10 |
| **H-29** | Despliegue / Compliance | El flujo de despliegue no instancia ni activa módulos de compliance: el rol A3 queda sin reglas que administrar | `CompleteDeploymentExample.s.sol:102-155`; `deploy-besu.sh:82-189`; `MaxBalanceCompliance.sol:20-42`; R4-7 |
| **H-30** | Backup / Continuidad | Sin RNF de backup, restauración, RPO/RTO ni runbook de recuperación para MongoDB/GridFS y estado on-chain | `estado_proyecto.md:32`; `diccionario_datos.md:73,89`; `entornos_globales.md:96`; `requerimientos.md:52-61`; R3-6 |

### 4.4 Bajos (4)

| ID | Dimensión | Título | Evidencia |
|---|---|---|---|
| **H-31** | Deploy / Criterio de éxito | El éxito del despliegue se decide por `grep` de mensajes de log, sin verificación on-chain; `set -e` invalida el manejo de errores | `deploy-besu.sh:3,13,83-103,123-131,151-159,178-186,191-204`; R1-10 |
| **H-32** | Exactitud documental | `DEPENDENCIAS_CONTRATOS.md` atribuye un import inexistente a `IdentityCloneable`; `metricas_ejecucion.md` niega la existencia de un archivo que sí existe | `DEPENDENCIAS_CONTRATOS.md:124-134`; `IdentityCloneable.sol:4`; `metricas_ejecucion.md:47-48`; `ClaimTopicsRegistry.sol:1-18`; R2-9, R5-9 |
| **H-33** | Estado del proyecto | Estado de fases y rama de trabajo contradictorios entre `estado_proyecto.md` y `entornos_globales.md` | `estado_proyecto.md:11-14,20,28,35`; `entornos_globales.md:23`; `requerimientos.md:81`; R2-10 |
| **H-34** | Observabilidad on-chain | Los cambios de `tokenContract` en los tres módulos de compliance no emiten evento | `MaxBalanceCompliance.sol:30-33`; `MaxHoldersCompliance.sol:51`; `TransferLockCompliance.sol:47`; R3-8 |

**Recuento por severidad: 1 CRÍTICA · 11 ALTAS · 18 MEDIAS · 4 BAJAS = 34.**

---

## 5. Hallazgos críticos y altos detallados

### H-01 — CRÍTICA · Claims auto-forjados: sin verificación criptográfica (EIP-712/ECDSA)

**Dimensión:** Seguridad on-chain / Compliance y normativa de valores · **Origen:** R2-4, R4-1, R5-1, R6-1, R7-1

**Evidencia.** `IdentityCloneable.addClaim()` es `onlyOwner` y almacena `{topic, scheme, issuer, signature, data, uri}` **sin verificar la firma** ni comprobar que el emisor esté autorizado para ese topic (`src/IdentityCloneable.sol:63-98`). El `owner` de la identidad es el propio inversor, porque `IdentityCloneFactory.createIdentity(owner)` es permissionless y acepta un owner arbitrario (`src/IdentityCloneFactory.sol:43-59`). `TokenCloneable.isVerified()` solo comprueba (a) que la wallet esté registrada, (b) que `getClaimIssuersForTopic()` devuelva algún emisor y (c) que ese emisor figure en `TrustedIssuersRegistry.hasClaimTopic()`; **nunca valida bytes de firma ni contenido del claim** (`src/TokenCloneable.sol:229-281`). En consecuencia, un inversor registrado puede ejecutar `addClaim(topic, 1, issuerConfiable, hex"", hex"", "")` y quedar verificado. No existe `ecrecover`/`EIP712`/`ECDSA` en `src/` (única aparición: un comentario en `IdentityCloneable.sol:57`). `createIdentityWithClaim()` permite crear identidad + claim en una sola transacción con firma arbitraria (`src/IdentityCloneFactory.sol:72-103`), y el ejemplo canónico de despliegue registra inversores "verified" con `signature = hex""` (`script/CompleteDeploymentExample.s.sol:159-175`).

**PoC reproducido (Forge 1.8.3):** identidad con `owner = atacante` + `addClaim(1, 1, issuer, "", "", "")` + `registerIdentity` ⇒ `isVerified(atacante) == true` (R7, test `test_ForgedClaimEmptySignature` PASS).

**Contradicción documental:** `VERIFICACION_TRUSTED_ISSUER.md:389-394` afirma como garantía actual que "los inversores no pueden falsificar claims" y marca el "Ataque 3: Claim Falso" como DETECTADO apoyándose en una validación off-chain inexistente. El hallazgo ya está identificado como H-01/RF-001 en `requerimientos.md:20,41`, pero **sigue sin implementarse**.

**Recomendación.** Implementar RF-001/D-007: claim EIP-712 tipado, `ecrecover` con `scheme == 1` y `signature.length == 65`, exigir `recovered == issuer ≠ 0`, incluir en el digest la wallet titular y el `verifyingContract`/`chainId`, y que `isVerified` requiera un claim firmado válido (no solo la presencia del issuer). Añadir tests negativos (firma vacía, firmante distinto, issuer no autorizado, longitud inválida) y reprocesar las identidades existentes antes de habilitar transferencias. No desplegar con activos reales hasta que exista verificación criptográfica.

---

### H-02 — ALTA · "139 tests (100 % passing)" es falso; dos suites núcleo no arrancan

**Dimensión:** Tests / Documentación · **Origen:** R1-1, R2-1, R3-4, R4-6, R5-4, R6-3, R7-4

**Evidencia.** `README.md:24,138,260,368`, `START_HERE.md:12,491` y `GUIA_ESTUDIANTE.md:1262` publican "139 tests (100 % passing)". El conteo real es de **151 funciones de test en 8 suites**; los 139 salen de sumar solo las 7 suites listadas en `README.md:250-258`, omitiendo `ClaimTopicsRegistryCloneFactory.t.sol` (12 tests). `test/Token.t.sol:51-52` y `test/ComplianceAggregator.t.sol:71-74` ejecutan `new TokenCloneable()`/`new IdentityCloneable()` + `initialize()` en `setUp`, pero los constructores llaman `_disableInitializers()` (`TokenCloneable.sol:50-52`, `IdentityCloneable.sol:42-44`), por lo que `initialize()` revierte con `InvalidInitialization()` y **mata las dos suites completas** (55 funciones según recuento directo; 53 según `metricas_ejecucion.md`). Resultado reproducido por cuatro verificadores: `93 passed, 5 failed, 0 skipped (98 total)`. Los otros 3 fallos son los tests de ahorro de gas. La cobertura es **42,86 % de líneas** frente al objetivo ≥ 80 % (`RNF-002`), con `ComplianceAggregator.sol` al 1,56 %. El propio repositorio se contradice: `metricas_ejecucion.md:29-35,65-72` y `requerimientos.md:98` registran el estado real, mientras RF-005, RNF-003 y `estado_proyecto.md:14` exigen "100 % de tests pasando", y la matriz de `casos_uso.md:758-759` marca RNF-002/RNF-003 como "✅ Cubierto".

**Recomendación.** Corregir primero los `setUp` (inicializar clones reales vía factory/`Clones.clone`, o crear versiones no-upgradeable de test): mientras no arranquen las 8 suites, ni RF-005 ni RNF-003 son alcanzables. Sustituir la cifra manual por un artefacto generado en CI (JUnit/reporte de `forge test`) y no publicar "100 % passing" sin él. Alinear README, START_HERE, GUIA, `estado_proyecto` y `requerimientos` con el conteo medido (151) y el resultado real; reabrir la matriz de trazabilidad para que "Cubierto" signifique cobertura medida.

---

### H-03 — ALTA · Cifras de ahorro de gas contradictorias y no verificables; RNF-001 sin criterio operativo

**Dimensión:** Métricas de gas · **Origen:** R1-2, R1-3, R2-7, R3-3, R5-5

**Evidencia.** El sistema declara ahorros incompatibles: **39 %** (`GUIA_ESTUDIANTE.md:98`; 11,1M vs 6,795M), **90,2 %** "Ahorro Medido" (`README.md:272`; 3.736.079 vs 364.903), **88–98 %** por artefacto y 94 % agregado (`ARQUITECTURA_FINAL.md:188-192`), **96,5 %** (`CLAIM_TOPICS_REGISTRY_FACTORY.md:181`) y "~85 %" (`OPTIMIZACION_VERIFICACION.md:254`). `OPTIMIZACION_VERIFICACION.md` presenta una tabla "Benchmarks / Test Environment: Foundry, Local Network" (1.450.000→430.000; 1.200.000→180.000; 150.000→25.000) cuyas cifras en el mismo texto se rotulan como "estimado" (`:42`, `:108`), sin distinguir estimación de medición, y contra un "Código Anterior" no versionado (`:7-25`). Ningún test mide iteraciones ni gas de `isVerified` (`Token.t.sol:170-192` solo comprueba booleanos). RNF-001 (`requerimientos.md:56`) fija 94–98 % como criterio de aceptación sin baseline, método, tolerancia ni condición de fallo; no existe `.gas-snapshot` ni `--gas-report` versionado ni CI. Los 3 tests que intentan medir ahorro **fallan** con `panic: arithmetic underflow` o `Clone should save at least 50% gas` (`TokenCloneFactory.t.sol:142-160`; `IdentityCloneFactory.t.sol:146`; `ClaimTopicsRegistryCloneFactory.t.sol:145-162`), porque comparan un clon inicializado contra desplegar la implementación pelada (5.974 gas vs 387.469). Agravante: `getGasSavingsInfo()` devuelve literales calculados a mano en `TokenCloneFactory.sol:168-170`, `IdentityCloneFactory.sol:136-138` y `ClaimTopicsRegistryCloneFactory.sol:211-212`, y sus tests solo comprueban que la cadena no esté vacía.

**Recomendación.** Definir **una** métrica canónica (`forge snapshot` con `.gas-snapshot` versionado) y derivar de ahí todas las cifras; prohibir cifras en docs sin enlace al snapshot. Reescribir los tests de ahorro con comparación equivalente (clon inicializado vs despliegue completo + `initialize` + callbacks), fallando si el ahorro se desvía del snapshot con tolerancia explícita. Reescribir RNF-001 en forma operativa ("el gas del snapshot para X operaciones no debe superar el baseline del commit Y en más de Z %") y RNF-005 con prueba concreta. Etiquetar el bloque de benchmarks como "estimación no medida" o retirarlo hasta reproducirlo; conservar la implementación previa en branch/fixture para poder comparar.

---

### H-04 — ALTA · Build no reproducible: código sin versionar, submódulos inconsistentes y sin CI

**Dimensión:** Reproducibilidad / VCS / CI · **Origen:** R1-7, R2-2, R2-3, R3-7, R5-7, R6-2

**Evidencia.** El repositorio `rwa-sc` tiene un único commit (`2a4a683`, "Initial commit") que añade **solo `README.md`** (93 inserciones); `git ls-files` devuelve únicamente `README.md` y todo `sc/` (src, test, script, `foundry.toml`, `foundry.lock`, `.gitmodules`), `deploy-besu.sh` y los 9 `.md` figuran como untracked. Las ramas remotas `main`, `rwa-sc-DSH` y `rwa-sc-DSH-GCP` apuntan todas a `2a4a683`, por lo que **el remoto no contiene contratos**. Existen dos `.gitmodules` contradictorios: la raíz declara 3 submódulos (`forge-std`, OZ, OZ-upgradeable) y `sc/.gitmodules` solo `openzeppelin-contracts`, mientras `foundry.toml:5-8` y `foundry.lock` requieren los tres. `rwa-sc/.gitignore:5` ignora `lib/` y no hay gitlinks registrados (`git submodule status` vacío, `git ls-files sc/lib` vacío), de modo que **un clon limpio no compila**. `foundry.toml` no fija `solc_version`, `evm_version`, optimizer ni fuzz (artefactos en `sc/cache` compilados con 0.8.28 frente al pragma `^0.8.20`). No existe CI (ni `.github/` ni `.gitlab-ci.yml`) pese a RF-009/RNF-002/003. Además, `entornos_globales.md:93-95` afirma que "Foundry no está instalado" y "`sc/lib/` no está clonada", y `requerimientos.md:24,30` mantiene H-05/H-11, **desmentidos por el filesystem actual** (forge v1.8.3 en `/home/dsh/.foundry/bin`; `sc/lib/` con forge-std v1.12.0, OZ v5.5.0, OZ-upgradeable v5.5.0) y ya corregidos en `metricas_ejecucion.md:8-15`.

**Recomendación.** Commitear y versionar todo el árbol (respetando secretos) en `rwa-sc-DSH-GCP` con push autorizado; verificar en el remoto que el código está presente antes de declarar RF-005/RF-009 cubiertos. Elegir una única fuente de verdad de submódulos (raíz con los 3, sin duplicado en `sc/`), registrar los gitlinks y no ignorar `lib/` o documentar el bootstrap. Fijar `solc_version`/optimizer/`evm_version` y commitear `foundry.lock`. Crear pipeline (GitLab) con `forge build`, `fmt --check`, `test` y `coverage ≥ 80 %` como gate, más `git clone --recurse-submodules && forge build && forge test` en directorio limpio. Actualizar `entornos_globales.md`/H-05/H-11 al estado real y documentar `export PATH="$HOME/.foundry/bin:$PATH"`.

---

### H-05 — ALTA · `isVerified()` es fail-open sin `claimTopicsRegistry`

**Dimensión:** Compliance / Semántica · **Origen:** R1-9, R4-5, R5-6, R6, R7-2

**Evidencia.** `src/TokenCloneable.sol:245-247`: si `address(claimTopicsRegistry) == address(0)`, `isVerified()` retorna `true` de inmediato, de modo que cualquier wallet registrada en `IdentityRegistry` queda "verificada" sin ningún claim. La situación es alcanzable porque `setClaimTopicsRegistry` no obliga a configurarlo tras fijar `identityRegistry` (`TokenCloneable.sol:92-96,110-114`), y `TokenCloneFactory.createToken` / `createTokenWithRegistries` permiten dejar registries sin fijar (`TokenCloneFactory.sol:51-74,87-135`; `CreateTokenWithCloneFactory.s.sol:40` usa la ruta básica). Contradice la descripción documental de que "ambos deben tener todos los claims" (`ARQUITECTURA_FINAL.md:217-236`), y `casos_uso.md:450,484` llega a especificar el fail-open como comportamiento esperado (`test_RF001_isVerified_sin_topics_registrada_true`), contradiciendo la precondición de CU-09 (`casos_uso.md:438`) y A14.4 (`:701`). No existe test que fije la semántica: todos los tests configuran el registry en `setUp`.

**PoC reproducido (Forge 1.8.3):** token con `identityRegistry` fijado y `claimTopicsRegistry` sin fijar ⇒ `isVerified(inversor) == true` (R7, `test_FailOpenNoClaimTopicsRegistry` PASS).

**Recomendación.** Aplicar fail-closed: devolver `false` o revertir si `claimTopicsRegistry` (o `trustedIssuersRegistry`) es `address(0)` o está vacío; exigir los tres registries configurados antes de permitir `mint`/`transfer`; añadir test de regresión de configuración incompleta y resolver explícitamente la contradicción de CU-09.

---

### H-06 — ALTA · Centralización de poderes: una EOA, `AGENT_ROLE` absoluto y sin custodio de claves

**Dimensión:** Seguridad / Gobernanza · **Origen:** R4-2, R6-6, R7-3

**Evidencia.** `initialize()` concede `DEFAULT_ADMIN_ROLE`, `AGENT_ROLE` y `COMPLIANCE_ROLE` a la **misma cuenta** (`TokenCloneable.sol:77-79`), y factories/registries usan `Ownable` de un paso con `initialOwner` idéntico. `burn(from, amount)` quema tokens de terceros sin verificar al titular ni límite (`TokenCloneable.sol:195-202`); `forcedTransfer` activa `bypassCompliance = true` y se salta pausa, congelaciones y todos los módulos de compliance, exigiendo solo que el destino esté verificado (`:208-224`, flag en `:44-47`); `mint` no tiene cap de suministro (`:176-190`). El `ComplianceAggregator` comparte un owner global y su modifier `onlyOwnerOrToken` permite al owner añadir/quitar módulos de **cualquier** token (`ComplianceAggregator.sol:50-53,61,87`). No hay multisig, timelock ni `Ownable2Step` (grep sin coincidencias), y `casos_uso.md:15-24` no define ningún actor custodio de claves. El deploy firma con la clave privada en claro de `~/.foundry/keys.json` (`deploy-besu.sh:13-14,37`). Comprometer esa clave permite acuñar, quemar, forzar transferencias, congelar cuentas y cambiar registries/reglas de compliance sin control.

**Recomendación.** Ejecutar RF-004/D-006: `authorizedDestinations`, `maxBurnPerTx`, `maxForcedPerTx`, eventos `Burn`/`ForcedTransfer` y whitelist de destinos; separar `AGENT_ROLE` de `DEFAULT_ADMIN_ROLE` y repartir los tres roles entre cuentas distintas con mínimo privilegio; usar `Ownable2Step` y transferir la propiedad a multisig/timelock; acotar el `mint` con cap de suministro; definir el actor custodio y documentar custodia/rotación; ejecutar RF-010 (secreto desde Secret Manager, nunca desde `keys.json`).

---

### H-07 — ALTA · Factories permissionless, "primer llamador gana" y patrón EIP-1167 sin ruta de actualización

**Dimensión:** Arquitectura / Control de acceso · **Origen:** R4-3, R6-5

**Evidencia.** `createToken` y `createTokenWithRegistries` no tienen control de acceso: cualquier cuenta crea un clon y queda como `DEFAULT_ADMIN_ROLE` + `AGENT_ROLE` + `COMPLIANCE_ROLE` del token (`TokenCloneFactory.sol:51-74,87-135`); `createIdentity` / `createIdentityWithClaim` son permissionless y aceptan un owner arbitrario (`IdentityCloneFactory.sol:43-59,72-103`); `ClaimTopicsRegistryCloneFactory.createRegistryForToken` es permissionless, exige `tokenRegistry[token] == address(0)` y asigna el mapeo (`:70-92`), por lo que **cualquiera puede fijar primero un registro falso/bloqueante para un token ajeno**, sin función de actualización. Los tres factories guardan `address public immutable implementation` creada en el constructor (`TokenCloneFactory.sol:17,40`; `IdentityCloneFactory.sol:17,35`; `ClaimTopicsRegistryCloneFactory.sol:17,38`), sin setter ni proxy: cada clon EIP-1167 delega para siempre a esa implementación, sin ruta de upgrade ni migración on-chain de saldos, congelaciones, holders o claims. Evidencia de intención no implementada: `IdentityCloneFactory.sol:27` declara el evento `ImplementationUpdated` que nunca se emite. No hay allowlist de emisores autorizados ni vínculo con el activo real ni due diligence documentada; el script `CreateTokenWithCloneFactory.s.sol:40,77` usa la ruta `createToken` sin registries ni módulos.

**Recomendación.** Restringir las factories a un registro/allowlist de emisores autorizados y exigir registries mínimos obligatorios; documentar quién puede tokenizar, con qué due diligence y evidencia. En `createRegistryForToken`, exigir que `msg.sender` sea owner/admin del token o permitir actualización controlada con evento + timelock; en `createIdentity`, forzar `owner = msg.sender` o requerir autorización. Decidir y documentar el modelo de ciclo de vida: proxy actualizable (UUPS/Transparent/Beacon con storage gaps) o runbook ensayado de redeploy limpio (snapshot de estado y eventos, plan de corte); si se mantiene EIP-1167 inmutable, eliminar el evento muerto `ImplementationUpdated` y registrar hash/tag de la implementación por factory. Prohibir en los scripts de ejemplo la ruta sin `claimTopicsRegistry`.

---

### H-08 — ALTA · Claims sin vigencia ni revocación por el issuer

**Dimensión:** Ciclo de vida de claims · **Origen:** R5-2, R7-7

**Evidencia.** El struct `Claim` solo tiene `{topic, scheme, issuer, signature, data, uri}`: no hay fecha de emisión, validez, expiración ni estado de revocación (`IdentityCloneable.sol:21-28`). `isVerified()` no comprueba vigencia (`TokenCloneable.sol:249-281`). `removeClaim()` es `onlyOwner` de la identidad, es decir, **el propio inversor decide si su KYC sigue vigente** (`:105-123`); el emisor (KYC/AML) no dispone de ninguna vía on-chain para revocar un claim ante sanción, defunción o pérdida de acreditación — la única revocación efectiva es eliminar al emisor del `TrustedIssuersRegistry` o borrar la identidad del registro, acciones masivas y sin granularidad. `VERIFICACION_TRUSTED_ISSUER.md:313-316` describe la renovación como "proceso manual" y `:377-380` admite "implementar lógica para claims con expiración", sin RF/RNF, criterio de aceptación ni caso de uso asociado.

**Recomendación.** Añadir `expiresAt` y `revoked` al claim, un evento `ClaimRevoked` firmado por el issuer (o lista de revocación por issuer) consultado por `isVerified`, y soporte de renovación/reemisión con eventos. Añadir tests de claim expirado/revocado que bloqueen la transferencia, o declarar formalmente la renovación como proceso off-chain con control on-chain de caducidad y responsable identificado.

---

### H-09 — ALTA · Catálogo RNF incompleto: solo 5 requisitos aplicables frente a las 9 categorías ISO 25010

**Dimensión:** Completitud RNF / ISO 25010 · **Origen:** R3-1

**Evidencia.** `requerimientos.md:52-61` define únicamente RNF-001…RNF-006, y RNF-006 está explícitamente marcado como no aplicable. Los 5 RNF vigentes se limitan a: ahorro de gas, cobertura de tests, tests en CI, ausencia de secretos y extensibilidad de compliance. No existe ningún RNF de fiabilidad operativa (disponibilidad, tolerancia a fallos, recuperación ante incidentes), mantenibilidad (versionado de ABIs/implementaciones, deuda técnica, análisis estático), portabilidad (multi-red, reproducibilidad), observabilidad/monitoreo, backup/DR, usabilidad/accesibilidad, ni eficiencia más allá del gas de despliegue. La matriz de `casos_uso.md:755-762` reproduce exactamente esa lista cerrada y concluye "no hay huérfanos", produciendo un **falso sentido de completitud**: se verifica cobertura contra un universo incompleto. La única mención de "monitoreo" en todo el alcance es una viñeta de carrera en `EJERCICIOS_PRACTICOS.md:811`, no un requisito.

**Recomendación.** Añadir en `requerimientos.md` §4 una matriz RNF por categoría ISO 25010, cada una con criterio de aceptación medible y responsable; marcar N/A con justificación explícita (p. ej. usabilidad/accesibilidad por D-003) y reabrir la matriz de trazabilidad para que "Cubierto" signifique cobertura real y no pertenencia a una lista cerrada.

---

### H-10 — ALTA · Sin control ni RNF de cumplimiento regulatorio para un security token

**Dimensión:** Cumplimiento regulatorio · **Origen:** R3-2, R5-3, R4-5

**Evidencia.** El proyecto tokeniza activos regulados y usa topics KYC/Accreditation/Jurisdiction, pero el catálogo RNF no incluye: cribado de sanciones (OFAC/UE/listas), periodicidad de rescreening, retención y trazabilidad de registros de transferencias y claims, reporte regulatorio, aplicación de restricciones por jurisdicción, ni privacidad/protección de datos personales KYC. `grep` de `sanciones|sanction|OFAC|PEP|AML|MiCA|Reg D|Reg S|retención|GDPR|reporte regulatorio` en `RepoTecnico/` y `rwa-sc/*.md` no devuelve coincidencias de requisito. La única referencia regulatoria es una nota operativa sobre topics que dice que incorporar nuevos temas "se decide en entrevista B2" (`diccionario_datos.md:106`), sin requisito ni criterio de aceptación. Esto se combina con el catálogo de topics divergente (H-13): un token que configure el topic 9 como "Jurisdiction" podría estar exigiendo "Sanctions Check" según otra fuente.

**Recomendación.** Definir RNF regulatorios explícitos: lista de sanciones y periodicidad de rescreening; retención mínima de evidencia; formato y reporte de auditoría regulatoria; base legal y cifrado/retención de documentos KYC en GridFS; mapeo a la normativa aplicable (p. ej. MiCA, Reg D/Reg S, CNMV/LMV, DLT Pilot). Añadir el requisito de screening de sanciones/PEP/AML con caso de uso y test.

---

### H-11 — ALTA · PII y documentos KYC sin custodio, base legal, cifrado, retención ni borrado

**Dimensión:** Datos personales / Custodia documental · **Origen:** R4-4, R7-5

**Evidencia.** El modelo off-chain almacena solicitudes de claim y documentos identificativos en MongoDB + GridFS (`claim_requests`: wallet, issuer, topic, signature del usuario, `documentId`, estado y notas; `claim_documents`: `filename`/`contentType`/`length`) según `diccionario_datos.md:63-96` y `diagrama_er.md:62-96`. Ningún artefacto asigna un responsable de custodia/protección de datos (DPO o custodio documental), ni define base legal, cifrado, control de acceso, plazos de retención o borrado; `casos_uso.md:15-24` no menciona DPO/custodia. On-chain, `IdentityCloneable` almacena `bytes data` y `string uri` y emite `ClaimAdded(signature, data, uri)` completos, que son inmutables, públicos y permanentes; `removeClaim` borra el mapping pero el histórico de eventos permanece, imposibilitando la supresión (RGPD art. 17) y la minimización (art. 5). En `RepoTecnico` no hay ninguna mención a GDPR/RGPD/privacidad/datos personales/consentimiento/DPIA (grep sin coincidencias). `base_datos.sql` es un borrador PostgreSQL pendiente y no cubre este vacío.

**Recomendación.** Off-chain por defecto para PII: on-chain solo hash/commitment y flags. Cifrado en reposo y en tránsito, control de acceso y mínimo privilegio en GridFS. Definir el stakeholder custodio de datos/DPO y una política de protección de datos (base jurídica, finalidad, retención, derecho de supresión, registro de auditoría y procedimiento de brecha), reflejada en `casos_uso.md` y `diccionario_datos.md`; realizar DPIA y evaluar ZK/atributos para minimización.

---

### H-12 — ALTA · Sin RNF de observabilidad ni indexación de eventos

**Dimensión:** Observabilidad / Monitoreo · **Origen:** R3-5, R6-9

**Evidencia.** Los contratos emiten eventos de dominio relevantes (`TokenCloneable.sol:35-41`, `IdentityRegistry.sol:22-24`, `TrustedIssuersRegistry.sol:21-23`, `IdentityCloneable.sol:30-39`, `ComplianceAggregator.sol:41-43`), pero el catálogo RNF no exige nada sobre su explotación: no hay requisito de indexación off-chain, alertas ante eventos de riesgo (freeze, forcedTransfer, cambio de registries, alta/baja de módulos), retención de logs ni panel de monitorización. No existe indexer, subgraph, worker ni colección de eventos (`grep indexer|subgraph|listener|getLogs|watchEvent` sin resultados) y el modelo MongoDB declarado (RT-004) no incluye eventos on-chain. Sin esto, incidentes propios de un security token no tienen canal de detección exigido; tras un redeploy limpio (D-009) se pierde la trazabilidad.

**Recomendación.** Definir RNF de observabilidad: conjunto mínimo de eventos monitorizados, alertas (p. ej. `forcedTransfer`/`burn` fuera de umbral), retención de logs/índice y canal de incidentes con tiempos de detección, enlazado con el plan de respuesta del `AGENT_ROLE` (RF-004). Implementar un indexer (worker con `getLogs` o subgraph) que alimente MongoDB con historial de transferencias, claims y cambios de compliance.

---

## 6. RNF faltantes

Además de los 5 RNF aplicables existentes (RNF-001 gas, RNF-002 cobertura, RNF-003 tests, RNF-004 secretos, RNF-005 extensibilidad; RNF-006 N/A), faltan por completo las siguientes categorías. Se listan con el ID del hallazgo donde se evidencian.

| # | Categoría ISO 25010 | RNF faltante | Evidencia |
|---|---|---|---|
| 1 | **Cumplimiento regulatorio** | Screening de sanciones/PEP/AML y periodicidad de rescreening; retención y trazabilidad de registros de transferencias/claims; reporte regulatorio periódico; restricciones por jurisdicción; mapeo normativo (MiCA, Reg D/S, CNMV/LMV) | H-10, H-25 |
| 2 | **Seguridad de la información / privacidad** | Base legal y consentimiento; cifrado de PII KYC; minimización on-chain; plazos de retención y derecho de supresión; DPIA | H-11 |
| 3 | **Observabilidad / monitoreo** | Eventos mínimos monitorizados; alertas de riesgo; retención de logs/índice; canal de incidentes y tiempos de detección | H-12, H-21 |
| 4 | **Fiabilidad operativa / continuidad** | Disponibilidad y tolerancia a fallos; política de backup y prueba de restauración de MongoDB/GridFS con RPO/RTO; runbook de recuperación on-chain (roles, registries, claves) | H-30, H-27 |
| 5 | **Portabilidad / reproducibilidad** | Bootstrap reproducible y multiplataforma; `solc`/`evm_version` fijados; soporte multi-red y validación de `chainId`; artefactos de despliegue versionados | H-04, H-26 |
| 6 | **Mantenibilidad** | Versionado de ABIs e implementaciones; umbral de deuda técnica; análisis estático obligatorio (p. ej. Slither sin High); política de actualización del patrón clone | H-04, H-07 |
| 7 | **Eficiencia (más allá del gas de despliegue)** | Umbrales de gas por operación en runtime con `forge snapshot`; límites operativos de arrays y paginación | H-03, H-20 |
| 8 | **Usabilidad / accesibilidad (N/A justificado)** | No aplica al ciclo activo (contratos sin UI; `rwa-web` fuera de alcance por D-003); debe marcarse N/A con justificación explícita | H-09 |

**Nota de verificabilidad.** Los RNF existentes tampoco son verificables en el estado actual: los tests de ahorro de gas (RNF-001) revierten con underflow, 53–55 de 151 tests nunca se ejecutan (RNF-003), la cobertura es 42,86 % frente a ≥ 80 % (RNF-002), y la matriz de trazabilidad `casos_uso.md:755-762` declara "✅ Cubierto" RNF-002/RNF-003 pese a los datos medidos.

---

## 7. Stakeholders faltantes

**Definidos actualmente** (`casos_uso.md:15-24`): A1 Admin/Owner, A2 Agente, A3 Compliance Officer, A4 Inversor, A5 Issuer confiable, A6 Creador de token, A7 Desarrollador/CI, A8 Auditor (solo lectura).

**Faltantes, con evidencia:**

| # | Stakeholder ausente | Por qué importa | Evidencia |
|---|---|---|---|
| 1 | **Custodio de claves / responsable de gobernanza** | Una sola EOA acumula todos los roles y no hay multisig/timelock; no hay responsable de custodia ni rotación | H-06; `casos_uso.md:15-24` (grep de "custodio" sin coincidencias) |
| 2 | **DPO / custodio de datos personales** | PII y documentos KYC en GridFS sin responsable, base legal ni política de retención | H-11; `casos_uso.md` sin DPO |
| 3 | **Regulador / supervisor** | No hay rol, interfaz ni procedimiento de reporte regulatorio, snapshot de holders o exportación de eventos | H-25; `grep regulador` sin coincidencias |
| 4 | **Operador de la red Besu** | Sin responsable de disponibilidad/finalidad/control de acceso al nodo; `chainId` pendiente y RPC hardcodeado | H-26; `entornos_globales.md:43` |
| 5 | **Soporte al inversor / recuperación** | Sin cauce de incidencias (claves perdidas, identidad comprometida, disputas); la única vía es `forcedTransfer` sin whitelist ni topes | H-27; `grep soporte` sin coincidencias |

Adicionalmente, los actores existentes quedan **sin fuerza efectiva**: A5 (issuer confiable) es una etiqueta sin validación criptográfica (H-01), A6 (creador de token) no tiene restricción ni due diligence (H-07) y A3 (compliance officer) no tiene reglas que administrar en el flujo de despliegue entregado (H-29).

---

## 8. Plan de acción

**Esfuerzo:** S = ≤ 1 día · M = 2–5 días · L = > 1 semana.

### 8.1 Quick wins (≤ 1 semana, sin rediseño)

| # | Acción | Hallazgo | Responsable sugerido | Esfuerzo |
|---|---|---|---|---|
| QW-1 | Corregir los `setUp` de `Token.t.sol` y `ComplianceAggregator.t.sol` para inicializar clones reales vía factory/`Clones.clone` | H-02 | Dev contratos | S |
| QW-2 | Sustituir "139 tests (100 % passing)" y "production-ready" por el estado real medido en README, START_HERE y GUIA | H-02, H-16 | Dev/docs | S |
| QW-3 | Aplicar fail-closed en `isVerified()` cuando `claimTopicsRegistry == address(0)` + test de regresión | H-05 | Dev contratos | S |
| QW-4 | Etiquetar `OPTIMIZACION_VERIFICACION.md` como "estimación no medida" y retirar la tabla "Benchmarks" | H-03 | Dev/docs | S |
| QW-5 | Unificar `.gitmodules` (raíz con los 3, eliminar el de `sc/`) y no ignorar `lib/` o documentar bootstrap | H-04 | DevOps | S |
| QW-6 | Corregir `diccionario_datos.md` y `DEPENDENCIAS_CONTRATOS.md` contra el storage/imports reales | H-14, H-32 | Datos/docs | S |
| QW-7 | Actualizar `entornos_globales.md` (Forge existe, `lib/` poblada, `export PATH`) y H-05/H-11 | H-04 | DevOps/docs | S |
| QW-8 | Emitir evento `TokenContractSet` en los 3 módulos de compliance | H-34 | Dev contratos | S |
| QW-9 | Cargar `PRIVATE_KEY` desde variable de entorno/Secret Manager; no usar `--private-key` en `argv` | H-28 | DevOps/seguridad | S |
| QW-10 | Eliminar del README/START_HERE/GUIA referencias a documentos y contratos inexistentes | H-15 | Dev/docs | S |
| QW-11 | Corregir el criterio de éxito de `deploy-besu.sh`: verificar con `cast code`/recibo y no por `grep` de log | H-31 | DevOps | S |
| QW-12 | Actualizar `estado_proyecto.md` y `entornos_globales.md`: rama `rwa-sc-DSH-GCP` (D-005) y fases con criterios verificables | H-33 | PM/docs | S |

### 8.2 Mejoras (2–4 semanas)

| # | Acción | Hallazgo | Responsable sugerido | Esfuerzo |
|---|---|---|---|---|
| M-1 | Implementar RF-001: EIP-712 + `ecrecover` en `addClaim`, exigir issuer autorizado por topic y firma válida; tests negativos | H-01 | Dev contratos + seguridad | L |
| M-2 | Reescribir los 3 tests de ahorro de gas con comparación equivalente y crear `.gas-snapshot`; reescribir RNF-001 en forma operativa | H-03 | Dev contratos | M |
| M-3 | Añadir `ReentrancyGuardUpgradeable` en `transfer`/`forcedTransfer`/`mint`/`burn` y en el aggregator; tests con módulo malicioso | H-18 | Dev contratos | M |
| M-4 | Implementar RF-003: `supportsInterface` ERC-165 y validación de módulos en token y aggregator | H-17 | Dev contratos | M |
| M-5 | Implementar RF-004: `authorizedDestinations`, `maxBurnPerTx`, `maxForcedPerTx`, eventos; separar `AGENT_ROLE` de admin | H-06 | Dev contratos | M |
| M-6 | Añadir `expiresAt`/`revoked` al claim y revocación por issuer consultada por `isVerified` | H-08 | Dev contratos | M |
| M-7 | Restringir factories a allowlist de emisores; proteger `createRegistryForToken` y `createIdentity` | H-07 | Dev contratos | M |
| M-8 | Crear catálogo único y versionado de claim topics (constantes + tabla canónica) y alinearlo en las 5 fuentes | H-13 | Datos + dev contratos | M |
| M-9 | Hacer fail-closed `ComplianceAggregator` (0 módulos = denegar) y restringir la gestión de módulos a admin del token | H-22 | Dev contratos | M |
| M-10 | Aislar estado por token en módulos de compliance (mapping por token) o rechazar módulo ya asociado a otro token | H-19 | Dev contratos | M |
| M-11 | Sustituir arrays O(n) por mappings/índices O(1) y añadir vistas paginadas | H-20 | Dev contratos | L |
| M-12 | Crear pipeline CI con `forge build`, `fmt --check`, `test`, `coverage ≥ 80 %` y publicación de conteo real | H-04, H-02 | DevOps | M |
| M-13 | Versionar todo el árbol en `rwa-sc-DSH-GCP` con push autorizado; fijar `solc_version`, optimizer y `evm_version` | H-04 | DevOps | S–M |
| M-14 | Extender `deploy-besu.sh` (o designar `CompleteDeploymentExample.s.sol`) para desplegar registries + token + módulos de compliance, con verificación post-deploy | H-24, H-29 | DevOps | M |
| M-15 | Persistir artefactos de despliegue (JSON con direcciones, ABIs, `chainId`, bloque) como fuente de verdad | H-21 | DevOps | M |
| M-16 | Convertir la rúbrica de `EJERCICIOS_PRACTICOS.md` en criterios observables (assertions mínimas, Slither sin High, umbral de gas) | H-23 | PM/docs | S–M |
| M-17 | Validar `chainId`/red y parametrizar `RPC_URL` antes de cualquier broadcast | H-26 | DevOps | S–M |

### 8.3 Roadmap (1–3 meses)

| # | Acción | Hallazgo | Responsable sugerido | Esfuerzo |
|---|---|---|---|---|
| R-1 | Definir y aprobar el catálogo RNF completo por categoría ISO 25010, con criterios medibles y responsables | H-09, H-30, H-10 | PM + arquitectura | M |
| R-2 | Definir RNF regulatorios (sanciones/PEP/AML, retención, reporte) y mapear al perímetro normativo (MiCA, Reg D/S, CNMV/LMV, DLT Pilot) | H-10, H-25 | Legal + compliance | L |
| R-3 | Política de protección de datos: cifrado GridFS, minimización on-chain, retención/supresión, DPIA y designación de DPO | H-11 | Legal + datos | L |
| R-4 | Capa de indexación de eventos (indexer/subgraph) + RNF de observabilidad con alertas y retención | H-12, H-21 | Arquitectura + backend | L |
| R-5 | Backup/DR de MongoDB/GridFS con RPO/RTO y runbook de recuperación on-chain (roles, registries, claves) | H-30 | Operaciones | M |
| R-6 | Decidir el modelo de ciclo de vida: proxy actualizable con storage gaps **o** runbook ensayado de redeploy limpio (D-009/RT-008) | H-07 | Arquitectura | L |
| R-7 | Gobernanza con multisig/timelock y reparto de roles; designar custodio de claves y rotación | H-06, H-25 | Seguridad + operaciones | M |
| R-8 | Sustituir todas las afirmaciones de conformidad por declaración verificable de spec ERC-3643, interfaces cubiertas y tests de conformidad; añadir `SECURITY.md` y `LICENSE` | H-16 | Dev + legal | M |
| R-9 | Auditar la versión candidata (externa) antes de cualquier despliegue con activos reales | H-01, H-16 | Dirección | L |

---

## 9. Criterios de aceptación para la siguiente versión (V2)

La V2 se considerará **apta para desarrollo avanzado y candidata a auditoría externa** solo si cumple **todos** los criterios bloqueantes (B) y los criterios de calidad (C):

### Criterios bloqueantes (B) — sin ellos no hay promoción de versión

- **B-1 — Verificación criptográfica de claims (H-01):** `addClaim` valida firma EIP-712 con `ecrecover` (`scheme == 1`, `signature.length == 65`, `recovered == issuer ≠ 0`), exige `TrustedIssuersRegistry.hasClaimTopic(issuer, topic)` y rechaza firmas vacías/inválidas en todas las rutas, incluida `createIdentityWithClaim`. Existe un test adversarial que demuestra que el PoC de forja falla.
- **B-2 — Fail-closed de `isVerified` (H-05):** con `claimTopicsRegistry == address(0)` o vacío, `isVerified` devuelve `false` (o la operación revierte); existe test de regresión y la contradicción de CU-09 está resuelta explícitamente.
- **B-3 — Suite en verde y CI (H-02, H-04):** `forge test` arranca las 8 suites con **0 fallos** y publica el conteo real como artefacto de CI; `forge coverage` ≥ **80 %** de líneas (RNF-002); ninguna suite revierte en `setUp`. El pipeline corre en cada commit/MR.
- **B-4 — Gobernanza mínima (H-06, H-28):** los tres roles no recaen en una única cuenta sin decisión documentada; `forcedTransfer`/`burn` están acotados con whitelist y topes (RF-004); la clave privada no se pasa por `argv` ni se lee de `keys.json` en claro (RF-010).
- **B-5 — Reproducibilidad (H-04):** un clon limpio ejecuta `git clone --recurse-submodules && forge build && forge test` sin pasos manuales; el árbol completo está versionado en el remoto; `solc_version`/optimizer/`evm_version` fijados y `foundry.lock` commiteado.
- **B-6 — Claims con vigencia y revocación (H-08):** existe control on-chain de expiración/revocación con test que bloquea la transferencia de un claim caducado o revocado.
- **B-7 — RNF-001 operativo (H-03):** existe una única métrica de gas respaldada por `.gas-snapshot` versionado, con umbral y tolerancia explícitos, y los tests de ahorro usan comparación equivalente y pasan.
- **B-8 — Trazabilidad documental (H-02, H-15, H-16, H-33):** toda cifra publicada está enlazada a su artefacto generado; no hay referencias a documentos/contratos inexistentes; "ERC-3643 compliant" se sustituye por una declaración verificable (versión de spec + interfaces + test de conformidad) o se retira; "production-ready" solo puede usarse tras auditoría.

### Criterios de calidad (C)

- **C-1 — Validación de módulos (H-17):** `supportsInterface(ICompliance)` implementado y verificado en token y aggregator; tests que rechazan EOAs y contratos no conformes.
- **C-2 — Reentrancia (H-18):** `nonReentrant` en `transfer`/`forcedTransfer`/`mint`/`burn` y entradas del aggregator; test con módulo malicioso.
- **C-3 — ComplianceAggregator fail-closed (H-22):** sin módulos → denegar; gestión de módulos restringida al admin del token; tests de aislamiento cross-token (H-19).
- **C-4 — Escalabilidad (H-20):** borrados e iteraciones O(1) y vistas paginadas; pruebas de gas con volúmenes realistas documentadas.
- **C-5 — Observabilidad e indexación (H-12, H-21):** indexer de eventos operativo que alimenta la base de datos con historial de transferencias/claims/compliance y RNF de alertas definido; artefactos de despliegue versionados.
- **C-6 — Catálogo ISO 25010 (H-09, H-10, H-30):** matriz RNF completa por categoría, con criterios medibles y responsables; cada N/A justificado por escrito; RNF regulatorios y de backup/continuidad aprobados.
- **C-7 — Stakeholders (H-25, H-26, H-27):** definidos y con procedimiento documentado el custodio de claves, el DPO, el regulador/supervisor, el operador de red Besu y el soporte al inversor.
- **C-8 — Datos personales (H-11):** política de protección de datos aprobada (base legal, cifrado, retención, supresión, DPIA) y PII fuera de la cadena salvo hash/commitment.
- **C-9 — Despliegue completo (H-24, H-29):** script canónico end-to-end que despliega registries + token + módulos de compliance y verifica post-deploy con `cast call`; artefacto JSON de direcciones verificado.
- **C-10 — Documentación consistente (H-13, H-14, H-23, H-31, H-32, H-34):** catálogo único de topics; diccionario regenerado contra el storage real; rúbrica con criterios observables; deploy con verificación on-chain; eventos `TokenContractSet` emitidos.
- **C-11 — Auditoría externa (H-01, H-16):** aprobación de auditoría independiente y `SECURITY.md`/`LICENSE` presentes antes de manejar activos reales.

### Condición de salida

> La V2 se declara **apta para continuar a desarrollo de mejoras** cuando cierra las brechas de verificación (B-1…B-8). Se declara **apta para producción con activos reales** únicamente cuando, además, cierra los criterios C-1…C-11 y supera una auditoría externa. Hasta entonces, permanece **NO apta para producción**.

---

## Anexo A — Trazabilidad de IDs consolidados

| IDs originales (dimensión) | ID consolidado |
|---|---|
| R4-1, R5-1, R6-1, R7-1, R2-4 (parcial) | **H-01** |
| R1-1, R2-1, R3-4, R4-6, R5-4, R6-3, R7-4 | **H-02** |
| R1-2, R1-3, R2-7, R3-3, R5-5 | **H-03** |
| R1-7, R2-2, R2-3, R3-7, R5-7, R6-2 | **H-04** |
| R1-9, R4-5, R5-6, R6-1 (parcial), R7-2 | **H-05** |
| R4-2, R6-6, R7-3 | **H-06** |
| R4-3, R6-5 | **H-07** |
| R5-2, R7-7 | **H-08** |
| R3-1 | **H-09** |
| R3-2, R4-4 (parcial), R5-3 | **H-10** |
| R4-4, R7-5 | **H-11** |
| R3-5, R6-9 (parcial) | **H-12** |
| R1-5, R2-5, R5-3 (parcial) | **H-13** |
| R1-4, R2-8 | **H-14** |
| R2-6 | **H-15** |
| R1-8, R2-4 (parcial), R7-6 | **H-16** |
| R6-4 (parcial), R7-9 | **H-17** |
| R6-4 | **H-18** |
| R6-7 | **H-19** |
| R6-8 | **H-20** |
| R5-8 (parcial), R6-9 | **H-21** |
| R6-6 (parcial), R7-8 | **H-22** |
| R1-6 | **H-23** |
| R5-8 | **H-24** |
| R4-8 | **H-25** |
| R4-9 | **H-26** |
| R4-10 | **H-27** |
| R6-10, R7-10 | **H-28** |
| R4-7 | **H-29** |
| R3-6 | **H-30** |
| R1-10 | **H-31** |
| R2-9, R5-9 | **H-32** |
| R2-10 | **H-33** |
| R3-8 | **H-34** |

## Anexo B — Falsos positivos descartados en Fase 2 (no incluidos como hallazgos)

1. `requerimientos.md` truncado/corrupto con etiquetas de modelo sin cerrar (el archivo actual está íntegro; `RT-004` definido y `§6`/`Q1–Q9` presentes; `grep` de etiquetas sin coincidencias).
2. Premisa del encargo "Foundry no instalado / `sc/lib/` no existe" (falso en el estado actual).
3. "`lib/` ausente ⇒ no se puede compilar" como hallazgo autónomo (la parte vigente — `lib/` no rastreado — está integrada en H-04).
4. Front-running del `initialize` de clones EIP-1167 (clonado e inicialización atómicos en la misma transacción).
5. Reentrancia en la fase `canTransfer` pre-actualización (llamada `view` ⇒ `STATICCALL`).
6. Reentrancia / bypass del flag `bypassCompliance` con ventana explotable (sin hook externo en `_update` de OZ v5.5; cubierto como diseño pendiente por H-03/RF-002).
7. Colisión de storage layout entre versiones de la implementation como vulnerabilidad (no hay proxy actualizable).
8. Exposición de la "Private Key 0" de Anvil como secreto (clave de desarrollo pública; se conserva como higiene documental dentro de H-28).
9. Falta de RNF de usabilidad/accesibilidad WCAG (fuera de alcance por D-003; debe marcarse N/A).
10. Falta de RNF de escalabilidad (afirmación de marketing sin umbral; no constituye RNF exigible).
11. Falta de RNF de seguridad (la seguridad sí está cubierta por RF-001…RF-004; el vacío real es el catálogo ISO de H-09).
12. Matriz RF→CU por no anclar tests inexistentes (la columna dice "CU que lo cubren" y el mapa es de Fase 2/diseño).

**No se añadieron hallazgos ajenos a los informes verificados R1–R7.**

---

*Fin del informe — INFORME_OPTIMIZACION_V1.md*
