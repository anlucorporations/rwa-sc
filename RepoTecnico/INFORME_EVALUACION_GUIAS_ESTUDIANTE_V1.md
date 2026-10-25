# 📊 Informe de evaluación del proyecto frente a las guías estudiantiles

> **Versión:** v1.0 · **Fecha:** 2026-10-25 · **Alcance:** línea `@sc` (`rwa-sc`) + línea `@web` (`rwa-web`)
> **Documentos de referencia (adjuntos):** `GUIA_ESTUDIANTE.md` (guía de contratos) y
> `FICHERO_PARA_ESTUDIANTE.md` (guía web). Se evalúa el proyecto **tal como está hoy**
> (`rwa-sc` en `cb72ac4`, `rwa-web` en `14ec0ff`).
> **Naturaleza:** evaluación documental y de código (no es una auditoría de seguridad ni un pentest).

---

## 1. Resumen ejecutivo

**Veredicto:** el proyecto **cumple en alto grado los contenidos funcionales** de las dos guías
(**82,4 %** de los 108 criterios funcionales), pero las guías **están desactualizadas**
respecto al estado real del proyecto: al incorporar la vigencia documental, el cumplimiento literal
baja al **75,8 %** (92,5/122 criterios). La conclusión práctica es que **el producto está por
delante de su material didáctico**, no al revés.

| Dimensión | Contratos (`GUIA_ESTUDIANTE.md`) | Web (`FICHERO_PARA_ESTUDIANTE.md`) | Global |
|---|---:|---:|---:|
| Cumplimiento funcional | **92,0 %** (40,5/44) | **75,8 %** (48,5/64) | **82,4 %** (89/108) |
| + Ejercicios/actividades | 25,0 % (1/4) | — | 80,4 % (90/112) |
| + Vigencia de la guía | 40,0 % (2/5) | 10,0 % (0,5/5) | **75,8 %** (92,5/122) |
| **Total por guía** | **82,1 %** (43,5/53) | **71,0 %** (49/69) | **75,8 %** |

### Hallazgos clave

1. **Contratos: núcleo funcional prácticamente completo** (92,0 %). Existen los 16
   contratos que la guía describe (registries, identidad, token, 3 módulos de compliance,
   aggregator, 3 factories), la interfaz `ICompliance` es idéntica, y hay **443 tests** en 21
   suites con fuzz, invariantes, benchmarks de gas, cobertura y CI.
2. **La guía de contratos está desfasada en nomenclatura y firmas**: habla de `Identity.sol` y
   `Token.sol` (hoy `IdentityCloneable.sol`/`TokenCloneable.sol`), de `addClaim` con 6 argumentos
   (hoy 7, con `expiresAt` y firma EIP-712) y de `getClaim(bytes32 claimId)` (hoy
   `getClaim(topic, issuer)`). Además afirma "ERC-3643 compliant", cuando el proyecto declara
   explícitamente "**inspirado** en ERC-3643, no compliant".
3. **Web: la arquitectura y los flujos existen, pero el stack descrito es obsoleto**: las guías
   describen MongoDB/GridFS y `ethers.js`, mientras el proyecto usa **PostgreSQL** (D-095),
   `wagmi`+`viem` y `rwa.document_files` cifrado. Las apps se renombraron
   (`web-registry-trusted` → `apps/issuer`) y ahora hay una cuarta pieza (`apps/indexer`).
4. **Brecha funcional real en el marketplace**: la UI de compra/venta y de precio usa un ABI
   legacy (`pricePerToken`/`setPrice`/`buyToken`) que el `TokenCloneable` actual **no expone**;
   `market.ts` lo reconoce como deuda ("cuando el contrato de mercado se alinee con `rwa-sc`,
   este módulo debe desaparecer"). Impacta a "comprar", "precio" y al paso 6 del flujo.
5. **Documentación de soporte rota**: de los **9 documentos** que cita la guía web
   (`SCRIPTS_README.md`, `FIRMA_DIGITAL.md`, `CLAIM_REQUESTS_README.md`, `TESTING_GUIDE.md`,
   `ISSUER_PANEL_README.md`, `INTERFAZ_ISSUER.md`, `DONDE_ESTA_EL_FORMULARIO.md`,
   `TOKEN_MANAGEMENT_README.md`, `DEBUGGING_MONGODB.md`) **no existe ninguno**; en contratos faltan
   `TOKEN_CLONE_FACTORY.md` y `COMPLIANCE_AGGREGATOR_FINAL.md`.
6. **Los ejercicios de la guía no son los del proyecto**: la guía propone `TimeBasedCompliance`,
   `GeographicCompliance` y el token "Manhattan 301"; el repo tiene
   `EJERCICIOS_PRACTICOS.md` con otros ejercicios (DailyTransferLimit, Whitelist,
   CountryRestriction, DividendToken, VotingToken, Fees, presets, multisig).
7. **Fortalezas que las guías no recogen** (el proyecto va por delante): gobernanza
   `GovernanceMultisig` M-de-N con timelock (H-06), backup/DR verificado (H-30), indexer
   off-chain (H-12/H-21), SIWE, EIP-712, PostgreSQL y la separación de líneas con gates de
   sincronización (D-102).

---

## 2. Metodología

### 2.1 Objeto y fuentes

- **Objeto de evaluación:** el proyecto de las dos líneas (`rwa-sc` y `rwa-web`) frente a las dos
  guías adjuntas. No se evalúa a los estudiantes ni el proceso formativo, sino la **coherencia
  entre lo que las guías afirman y lo que el proyecto contiene**.
- **Fuentes primarias:** código (`sc/src`, `sc/test`, `sc/script`, `apps/*`, `packages/*`),
  documentación (`README.md`, `RepoTecnico/`), scripts y CI.
- **Nota sobre las copias adjuntas:** la `GUIA_ESTUDIANTE.md` adjunta es una versión **anterior**
  a la del repo (la del repo ya corrige EIP-712/`expiresAt`/`IdentityCloneable`); la
  `FICHERO_PARA_ESTUDIANTE.md` adjunta es **idéntica en contenido** a la del repo (solo cambia el
  fin de línea). La evaluación se hace contra las **copias adjuntas**, que son las que el usuario
  aportó como referencia.

### 2.2 Rúbrica

- **122 criterios** verificables, agrupados en categorías (13 en contratos, 16 en web).
- **Escala:** `1` = cumple y es localizable; `0,5` = parcial (existe con cambios, o existe la
  capacidad pero no el artefacto exacto); `0` = no cumple o no existe.
- **Dimensiones:** *funcional* (lo que la guía dice que el sistema hace/contiene), *ejercicios*
  (actividades propuestas) y *vigencia* (si la guía describe el proyecto actual o una versión
  anterior). Los porcentajes se calculan como puntos obtenidos / criterios × 100.
- **Trazabilidad:** cada criterio incluye evidencia (ruta y, cuando aplica, línea). La rúbrica
  está codificada en el generador de este informe y se puede reproducir (Anexo A).

### 2.3 Límites

- Evaluación **estática** (código y documentación). No se ejecutó la interfaz completa en
  navegador para cada funcionalidad; se apoyó en el E2E existente (claim-flow) y en los tests.
- La puntuación de "parcial" introduce juicio experto; los criterios y evidencias quedan a la
  vista para que cualquier lector pueda recalibrar.
- No se evalúan aspectos de seguridad ofensiva, rendimiento ni accesibilidad; ya tienen sus
  propios informes (`INFORME_OPTIMIZACION_*`, `perf:o5`, `a11y:o5`).

---

## 3. Resultados globales

| Indicador | Valor |
|---|---:|
| Criterios funcionales (ambas guías) | **82,4 %** (89/108) |
| + Ejercicios propuestos | 80,4 % (90/112) |
| **Cumplimiento global (incluye vigencia)** | **75,8 %** (92,5/122) |
| Guía de contratos — total | 82,1 % (43,5/53) |
| Guía web — total | 71,0 % (49/69) |

> Lectura: si solo se mira "¿el proyecto hace lo que la guía enseña?", el resultado es **82,4 %**.
> Si se exige además que la guía describa el proyecto real, cae al **75,8 %**. La distancia
> (6,6 puntos) mide **deuda documental**, no deuda de producto.

---

## 4. Evaluación de la guía de contratos (`GUIA_ESTUDIANTE.md`)

**Resultado: 82,1 %** (43,5/53) · funcional 92,0 % ·
ejercicios 25,0 % · vigencia 40,0 %.

| Categoría | Criterios | Puntos | Cumplimiento |
|---|---:|---:|---:|
| A. Objetivos de aprendizaje | 7 | 6,5/7 | **92,9 %** |
| B. Conceptos fundamentales | 4 | 4/4 | **100,0 %** |
| C. Arquitectura del sistema | 3 | 3/3 | **100,0 %** |
| D. Contratos básicos (Nivel 1) | 4 | 3/4 | **75,0 %** |
| E. Compliance modules (Nivel 2) | 5 | 5/5 | **100,0 %** |
| F. Contratos avanzados (Nivel 3) | 2 | 1/2 | **50,0 %** |
| G. Patrones de diseño | 5 | 5/5 | **100,0 %** |
| H. Ejercicios prácticos | 4 | 1/4 | **25,0 %** |
| I. Conceptos avanzados | 3 | 3/3 | **100,0 %** |
| J. Herramientas y setup | 3 | 3/3 | **100,0 %** |
| K. Checklist de competencias | 5 | 5/5 | **100,0 %** |
| L. Recursos y documentación | 3 | 2/3 | **66,7 %** |
| M. Vigencia de la guía (vs. proyecto actual) | 5 | 2/5 | **40,0 %** |

**Lectura por categorías:** el núcleo (conceptos, arquitectura, compliance, patrones, herramientas,
checklist) está al 100 %. Las pérdidas se concentran en: ejercicios no implementados (25 %),
vigencia de la guía (40 %), nivel 3 (50 % por nomenclatura/`onlyOwnerOrToken`) y recursos (66,7 % por
documentos inexistentes). La categoría de identidad (75 %) refleja el único cambio de API
significativo: `addClaim`/`getClaim`.

### A. Objetivos de aprendizaje

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| A1 | Implementar el estándar ERC-3643 | 🟡 | `rwa-sc/README.md:21`: «inspirado en ERC-3643, no compliant»; la guía lo presenta como estándar implementado |
| A2 | Clone Factory (EIP-1167) | ✅ | `Clones` de OpenZeppelin en las 3 factories (`ClaimTopicsRegistryCloneFactory.sol:4,75`); clones desplegados en E2E |
| A3 | Compliance modular y extensible | ✅ | `ICompliance` + `ComplianceAggregator` + 3 módulos (`sc/src/compliance/`) |
| A4 | Identity verification on-chain | ✅ | `IdentityRegistry` + `TokenCloneable.isVerified` (`TokenCloneable.sol:424`) |
| A5 | Access control con roles | ✅ | `AGENT_ROLE`/`COMPLIANCE_ROLE`/`DEFAULT_ADMIN_ROLE` (`TokenCloneable.sol:35-36,110-112`) |
| A6 | Tests comprehensivos con Foundry | ✅ | 21 suites / 443 tests (fuzz 256, invariantes) en `sc/test/` |
| A7 | Scripts de deployment automatizados | ✅ | 9 scripts `.s.sol` + `deploy.sh`, `DeployFullStack.s.sol`, CI (`run_local_ci.sh`) |

### B. Conceptos fundamentales

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| B1 | Concepto de RWA token | ✅ | `README.md`, `RepoTecnico/estado_proyecto.md`, `requerimientos.md` |
| B2 | Componentes de ERC-3643 (registries, compliance, claims, roles) | ✅ | Los cuatro pilares existen en `sc/src/` |
| B3 | Clone Factory (EIP-1167) | ✅ | Factories con `Clones.clone()`; ahorro de gas medido en `test/benchmarks/` |
| B4 | Compliance Aggregator | ✅ | `ComplianceAggregator.sol` con despacho modular y fail-closed (RF-012) |

### C. Arquitectura del sistema

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| C1 | Vista general de la arquitectura | ✅ | `README.md` (diagrama), `RepoTecnico/diagrama_er.md` |
| C2 | Flujo de una transferencia con compliance | ✅ | `TokenCloneable.canTransfer` (:511) → `isVerified` + aggregator; cubierto en `Token.t.sol` |
| C3 | Roles y permisos documentados y en código | ✅ | Roles por contrato + gobernanza `GovernanceMultisig` (H-06) |

### D. Contratos básicos (Nivel 1)

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| D1 | Contrato individual de identidad (`Identity.sol`) | 🟡 | Existe `IdentityCloneable.sol`; `addClaim` de 7 args con `expiresAt` (:147) y `getClaim(topic,issuer)` (:294) frente a 6 args/`claimId` de la guía |
| D2 | `IdentityRegistry` (`registerIdentity`/`isRegistered`/`getIdentity`) | ✅ | `IdentityRegistry.sol:41,120,112` |
| D3 | `TrustedIssuersRegistry` (`addTrustedIssuer`/`hasClaimTopic`/`getTrustedIssuerClaimTopics`) | 🟡 | `addTrustedIssuer` (:40), `isTrustedIssuer` (:114), `hasClaimTopic` (:131); el getter real es `getIssuerClaimTopics` (:122) |
| D4 | `ClaimTopicsRegistry.addClaimTopic` | ✅ | `ClaimTopicsRegistry.sol:37` |

### E. Compliance modules (Nivel 2)

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| E1 | Interfaz `ICompliance` con los 4 callbacks | ✅ | `ICompliance.sol:24-46` (firma idéntica a la guía) |
| E2 | `MaxBalanceCompliance` | ✅ | `MaxBalanceCompliance.sol` (canTransfer/transferred/created/destroyed) |
| E3 | `MaxHoldersCompliance` | ✅ | `MaxHoldersCompliance.sol` |
| E4 | `TransferLockCompliance` | ✅ | `TransferLockCompliance.sol` |
| E5 | Patrón `onlyTokenOrAuthorized` | ✅ | `MaxHoldersCompliance.sol:39` |

### F. Contratos avanzados (Nivel 3)

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| F1 | Token ERC-3643 (`Token.sol`) | 🟡 | Existe `TokenCloneable.sol` (upgradeable/clon) con `mint` (:342), `addComplianceModule` (:163), `pause` (:288), `isVerified` (:424), `canTransfer` (:511); nombre y herencia distintos |
| F2 | `ComplianceAggregator` (proxy modular) | 🟡 | `getModules` (:245), `getModuleCount` (:261), `canTransfer` (:176); la guía muestra `onlyOwnerOrToken(address)` y el real es `onlyToken(address)` (:86) |

### G. Patrones de diseño

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| G1 | Factory Pattern (Clone Factory) | ✅ | 3 factories + `Clones` |
| G2 | Proxy Pattern (Compliance Aggregator) | ✅ | Aggregator como proxy modular |
| G3 | Access Control Pattern | ✅ | Roles `AccessControl` en token y gobernanza |
| G4 | Registry Pattern | ✅ | `IdentityRegistry`, `TrustedIssuersRegistry`, `ClaimTopicsRegistry` |
| G5 | Modifier Pattern (authorization) | ✅ | `onlyToken`, `onlyOwner`, `onlyRole`, `onlyTokenOrAuthorized` |

### H. Ejercicios prácticos

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| H1 | Ejercicio 1: `TimeBasedCompliance.sol` | ❌ | No existe; `EJERCICIOS_PRACTICOS.md` propone otros ejercicios (DailyTransferLimit, Whitelist, CountryRestriction) |
| H2 | Ejercicio 2: `deploy-real-estate-token.sh` (Manhattan 301) | ❌ | No existe; la propia guía lo marca como `TODO` |
| H3 | Ejercicio 3: `GeographicCompliance` | ❌ | No existe; el doc de ejercicios tiene `CountryRestrictionCompliance` (distinto) |
| H4 | Ejercicio 4: test de integración completo | ✅ | `RF013_ClaimLifecycle.t.sol`, `AuditoriaFinalAF.t.sol` y E2E claim-flow |

### I. Conceptos avanzados

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| I1 | Initializable pattern | ✅ | `initialize`/`_disableInitializers` en `IdentityCloneable`/`TokenCloneable` |
| I2 | Delegatecall | ✅ | Clones EIP-1167 + aggregator |
| I3 | Gas optimization con evidencia | ✅ | `optimizer_runs=200`, `.gas-snapshot` con tolerancia, `test/benchmarks/` y CI (RNF-001) |

### J. Herramientas y setup

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| J1 | Foundry (prerequisitos y comandos) | ✅ | `foundry.toml`, `forge build/test`; toolchain v1.8.3 fijada |
| J2 | Tests, cobertura y CI | ✅ | 443 tests, `lcov.info`, `.gitlab-ci.yml`, `run_local_ci.sh` |
| J3 | Scripts de despliegue y gestión | ✅ | `deploy.sh`, `DeployFullStack.s.sol`, `backup/restore`, `run_local_ci.sh` |

### K. Checklist de competencias

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| K1 | Competencia: smart contracts | ✅ | Contratos completos y testeados |
| K2 | Competencia: patrones de diseño | ✅ | Factories, aggregator, registries, access control |
| K3 | Competencia: testing | ✅ | 443 tests + fuzz + invariantes + cobertura |
| K4 | Competencia: deployment | ✅ | 9 scripts + artefactos versionados + gobernanza |
| K5 | Competencia: gas optimization | ✅ | Benchmarks + snapshot + optimizador |

### L. Recursos y documentación

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| L1 | Documentación del proyecto referenciada | 🟡 | `README.md` y `EJERCICIOS_PRACTICOS.md` existen; `TOKEN_CLONE_FACTORY.md` y `COMPLIANCE_AGGREGATOR_FINAL.md` no existen |
| L2 | Troubleshooting de errores | 🟡 | Errores custom (`onlyToken`, `TransferNotCompliant`, etc.); los mensajes literales de la guía no siempre coinciden |
| L3 | Glosario y recursos | ✅ | Glosario en la guía y documentación en `RepoTecnico/` |

### M. Vigencia de la guía (vs. proyecto actual)

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| M1 | Nombres de contratos (`Identity.sol`/`Token.sol`) | ❌ | Los reales son `IdentityCloneable.sol` y `TokenCloneable.sol` |
| M2 | Firmas `addClaim`/`getClaim` | ❌ | `addClaim` de 7 args con `expiresAt`; `getClaim(uint256,address)` |
| M3 | Afirmación «ERC-3643 compliant» | 🟡 | El proyecto lo corrige a «inspirado» (`README.md:21`) |
| M4 | Documentos referenciados | 🟡 | 2 de 4 existen |
| M5 | Comandos y setup (forge/anvil) | ✅ | Válidos |


### 4.1 Brechas del proyecto (no imputables a la guía)

- **`F2` (parcial):** el aggregator real usa `onlyToken(address)` + `Ownable`, mientras la guía
  muestra `onlyOwnerOrToken(address)`; funcionalmente equivalente, pero conviene documentar la
  API real.
- **`L1`:** faltan `TOKEN_CLONE_FACTORY.md` y `COMPLIANCE_AGGREGATOR_FINAL.md` que la guía cita
  como documentación del proyecto.
- **`H1`–`H3`:** los ejercicios de la guía no están resueltos ni existen como contratos; el repo
  ofrece otros ejercicios en `EJERCICIOS_PRACTICOS.md`. Si la guía es material del curso, conviene
  alinear ambos catálogos.

### 4.2 Brechas de la guía (vigencia)

- `Identity.sol` → `IdentityCloneable.sol`, `Token.sol` → `TokenCloneable.sol`.
- `addClaim(topic, scheme, issuer, signature, data, uri)` → 7 argumentos con `expiresAt` y
  validación EIP-712.
- `getClaim(bytes32 claimId)` → `getClaim(uint256 topic, address issuer)`.
- "Implementar el estándar ERC-3643" → "inspirado en ERC-3643, no compliant".

---

## 5. Evaluación de la guía web (`FICHERO_PARA_ESTUDIANTE.md`)

**Resultado: 71,0 %** (49/69) · funcional 75,8 % ·
vigencia 10,0 %.

| Categoría | Criterios | Puntos | Cumplimiento |
|---|---:|---:|---:|
| A. Alcance funcional | 4 | 3,5/4 | **87,5 %** |
| B. Arquitectura de aplicaciones | 4 | 2/4 | **50,0 %** |
| C. Stack tecnológico | 5 | 1,5/5 | **30,0 %** |
| D. Configuración e instalación | 4 | 2,5/4 | **62,5 %** |
| E. App Identity | 5 | 5/5 | **100,0 %** |
| F. App Registry/Issuer | 4 | 4/4 | **100,0 %** |
| G. App Token | 7 | 5/7 | **71,4 %** |
| H. Flujo completo de uso | 7 | 6/7 | **85,7 %** |
| I. Smart contracts (sección web) | 5 | 4,5/5 | **90,0 %** |
| J. Base de datos | 3 | 0,5/3 | **16,7 %** |
| K. Sistema de firmas | 3 | 2/3 | **66,7 %** |
| L. APIs importantes | 3 | 3/3 | **100,0 %** |
| M. Troubleshooting, seguridad y topics | 3 | 2,5/3 | **83,3 %** |
| N. Features y quick start | 4 | 3,5/4 | **87,5 %** |
| P. Cast, glosario y avanzado | 3 | 3/3 | **100,0 %** |
| V. Vigencia de la guía (vs. proyecto actual) | 5 | 0,5/5 | **10,0 %** |

**Lectura por categorías:** las apps y sus flujos están completos (identity, issuer, token al
100 %; APIs al 100 %), y el flujo claim está verificado E2E. Las pérdidas se concentran en el
**stack tecnológico** (30 %: MongoDB/GridFS/ethers), la **base de datos** (16,7 %), el
**despliegue/instalación** (62,5 %) y, sobre todo, la **vigencia** (10 %). El token baja al 71,4 %
por el marketplace legacy.

### A. Alcance funcional

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| A1 | Crear identidades digitales on-chain | ✅ | `apps/identity` + `IdentityRegistry.registerIdentity` |
| A2 | Solicitar/aprobar/rechazar claims | ✅ | `ClaimRequestForm`, `RequestDetailModal`, `/api/claim-requests`, `/api/update-request` |
| A3 | Crear tokens RWA con compliance | ✅ | `apps/token` factory + `CreateTokenForm`/`TokensList` |
| A4 | Comprar y transferir tokens con compliance | 🟡 | UI de marketplace y código de compra/transferencia; la compra usa ABI legacy (ver G5/H6) |

### B. Arquitectura de aplicaciones

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| B1 | 3 apps separadas | 🟡 | Hay 3 apps + `indexer`; estructura monorepo `apps/*`, no directorios `web-*` |
| B2 | web-identity (puerto 4001) | 🟡 | `apps/identity` en 4001 (dev y compose) |
| B3 | web-registry-trusted (puerto 4002) | 🟡 | Renombrada `apps/issuer` en 4002 |
| B4 | web-token (puerto 4003) | 🟡 | `apps/token` en 4003 |

### C. Stack tecnológico

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| C1 | Next.js 16 + React + TypeScript + Tailwind | ✅ | `next 16.1.6`, `react 19.2.3`, TS; Tailwind en las apps |
| C2 | ethers.js v6 | ❌ | 0 dependencias/imports: `wagmi` + `viem` (`README.md:70`) |
| C3 | MongoDB | ❌ | PostgreSQL (`docker-compose.yml` → postgres:16-alpine; `@rwa/shared/db`) |
| C4 | GridFS para documentos | ❌ | `rwa.document_files` (bytea cifrado AEAD, D-093) |
| C5 | MetaMask | 🟡 | Conector inyectado de wagmi; la UI menciona MetaMask y `switchChain` |

### D. Configuración e instalación

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| D1 | Requisitos previos (Node, MongoDB, Anvil) | 🟡 | Node + Anvil ✓; MongoDB ✗ (PostgreSQL) |
| D2 | Instalación por app con npm | ❌ | Monorepo pnpm (`pnpm-workspace.yaml`, `pnpm install`) |
| D3 | `start-all.sh` / `stop-all.sh` / `check-status.sh` | ✅ | Los tres scripts existen y arrancan las 3 apps |
| D4 | Puertos 4001-4003 | ✅ | Dev y compose publican 4001/4002/4003 (`docker-compose.yml:60,76,92`) |

### E. App Identity

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| E1 | Crear identidad | ✅ | `apps/identity/app/app/page.tsx` |
| E2 | Solicitar claim a un issuer | ✅ | `ClaimRequestForm` |
| E3 | Ver mis requests | ✅ | `RequestDetailModal`, `/api/claim-requests` (GET) |
| E4 | Cargar claims aprobados | ✅ | `addClaim` on-chain (`RequestDetailModal.tsx:36-70`) |
| E5 | Account status | ✅ | Estado de conexión/cuenta en `app/app` |

### F. App Registry/Issuer

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| F1 | Ver trusted issuers | ✅ | `/api/issuers`, `apps/issuer` |
| F2 | Panel de issuer | ✅ | `apps/issuer/app/dashboard/page.tsx` |
| F3 | Aprobar/Rechazar claims | ✅ | `/api/update-request` + modal de revisión |
| F4 | Ver firmas | ✅ | `RequestDetailModal` firma EIP-712 y muestra firmas |

### G. App Token

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| G1 | Crear token (factory) | ✅ | `apps/token/app/factory/page.tsx`, `/api/tokens` |
| G2 | Gestionar compliance modules | 🟡 | Alta en `TokensList`/`CreateTokenForm` y `/api/tokens/[tokenId]/modules`; no hay UI de baja |
| G3 | Gestionar required claims | ✅ | `/api/tokens/[tokenId]/claims`, `requiredClaims` |
| G4 | Establecer precio | 🟡 | UI y `/api/tokens/[tokenId]/price`, pero el ABI actual de `TokenCloneable` no declara `setPrice` (`market.ts:4-7`) |
| G5 | Marketplace: comprar tokens | 🟡 | `marketplace/page.tsx` llama `buyToken`; ABI legacy (`market.ts`) y el contrato actual no expone `buyToken` |
| G6 | Transferir tokens | 🟡 | Lógica en `marketplace`/compliance, sin flujo dedicado ni E2E |
| G7 | Cambiar de cuenta | ✅ | «Switch Account» en marketplace + wagmi |

### H. Flujo completo de uso

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| H1 | Paso 1: crear identidad | ✅ | Flujo E2E claim-flow |
| H2 | Paso 2: solicitar claims | ✅ | Flujo E2E claim-flow |
| H3 | Paso 3: issuer aprueba | ✅ | Flujo E2E claim-flow |
| H4 | Paso 4: cargar claims | ✅ | Flujo E2E claim-flow |
| H5 | Paso 5: admin crea token | ✅ | Factory + `/api/tokens` |
| H6 | Paso 6: investor compra | 🟡 | UI legacy de compra; contrato actual sin `buyToken` |
| H7 | Paso 7: investor transfiere | 🟡 | Sin flujo E2E de transferencia |

### I. Smart contracts (sección web)

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| I1 | Identity Registry | ✅ | `registerIdentity`/`isRegistered`/`getIdentity` |
| I2 | Trusted Issuers Registry | ✅ | `addTrustedIssuer`/`isTrustedIssuer`/`getIssuerClaimTopics` |
| I3 | Identity Contract (`addClaim` de 6 args) | 🟡 | `addClaim` de 7 args + EIP-712 (`IdentityCloneable.sol:147`) |
| I4 | Token Clone Factory | ✅ | `createToken`/`createTokenWithRegistries` |
| I5 | Token Cloneable | ✅ | `TokenCloneable.sol` |

### J. Base de datos

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| J1 | MongoDB, base `rwa` | ❌ | PostgreSQL, esquema `rwa` |
| J2 | Colecciones `claim_requests`/`tokens` | 🟡 | Existen como tablas `rwa.claim_requests`/`rwa.tokens` con campos equivalentes |
| J3 | Buckets GridFS | ❌ | `rwa.document_files` (bytea cifrado) |

### K. Sistema de firmas

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| K1 | Firma dual requester + issuer | ✅ | Flujo E2E: firma del inversor + firma del issuer |
| K2 | Mecanismo `signMessage` (EIP-191) para ambas | ❌ | Inversor EIP-191, issuer EIP-712; el contrato valida EIP-712 |
| K3 | Firma del issuer usada en `addClaim` | ✅ | `addClaim` verifica la firma EIP-712 del issuer |

### L. APIs importantes

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| L1 | Rutas de identity (`claim-requests`, `upload`, `download`) | ✅ | Rutas presentes |
| L2 | Rutas de issuer (`issuer-requests`, `update-request`) | ✅ | Rutas presentes |
| L3 | Rutas de token (`tokens`, `price`, `modules`, `claims`) | ✅ | Rutas presentes |

### M. Troubleshooting, seguridad y topics

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| M1 | Troubleshooting (compliance/MongoDB) | 🟡 | Los errores de compliance aplican; los de MongoDB/GridFS no |
| M2 | Seguridad (firmas, compliance, permisos) | ✅ | EIP-712, SIWE, compliance y roles |
| M3 | Claim topics 1/7/9 (5/6 reservados) | ✅ | `base_datos.sql:456-460` |

### N. Features y quick start

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| N1 | Features de identity | ✅ | Página + APIs |
| N2 | Features de issuer | ✅ | Panel + APIs |
| N3 | Features de token | ✅ | Factory/marketplace + APIs |
| N4 | Quick start (MongoDB, start-all, MetaMask, test) | 🟡 | start-all/MetaMask/health ✓; MongoDB ✗ |

### P. Cast, glosario y avanzado

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| P1 | Comandos `cast` verificables | ✅ | `cast call` a registries/token; Anvil/GCP |
| P2 | EIP-1167 minimal proxy | ✅ | Factories con `Clones` |
| P3 | Sistema modular de compliance | ✅ | Aggregator + módulos |

### V. Vigencia de la guía (vs. proyecto actual)

| ID | Criterio | Estado | Evidencia |
|---|---|---|---|
| V1 | Stack tecnológico (ethers/MongoDB/GridFS) | ❌ | El real es wagmi+viem/PostgreSQL/document_files |
| V2 | Nombres de apps (`web-*`) | ❌ | `apps/identity|issuer|token` |
| V3 | Instalación (npm por app, MongoDB, dir `57_RWA_WEB`) | ❌ | Monorepo pnpm, PostgreSQL, `rwa-web` |
| V4 | Firmas (EIP-191 para ambas) | 🟡 | Inversor EIP-191; issuer EIP-712 |
| V5 | 9 documentos referenciados | ❌ | Ninguno de los 9 existe (`SCRIPTS_README.md`, `FIRMA_DIGITAL.md`, …) |


### 5.1 Brechas del proyecto (no imputables a la guía)

- **Marketplace/precio (`G4`, `G5`, `H6`)**: la UI usa `pricePerToken`/`setPrice`/`buyToken` de un
  ABI legacy; el `TokenCloneable` actual no los declara. `apps/token/lib/contracts/market.ts:4-7`
  reconoce la deuda. Es la brecha funcional más importante de la línea web.
- **`G2`**: no hay UI para retirar módulos de compliance (sí para añadirlos).
- **`G6`/`H7`**: transferencia de tokens existe en código pero sin flujo dedicado ni E2E.
- **`L`/`N`**: cobertura E2E solo del claim-flow; compra/transferencia no están en E2E.

### 5.2 Brechas de la guía (vigencia)

- MongoDB/GridFS → PostgreSQL + `rwa.document_files` (D-095/D-093).
- `ethers.js` v6 → `wagmi` + `viem` (cero `ethers`, cero `window.ethereum`).
- `web-identity`/`web-registry-trusted`/`web-token` → `apps/identity`/`apps/issuer`/`apps/token`
  (monorepo pnpm) + `apps/indexer`.
- Firmas: la guía usa `signMessage` (EIP-191) para ambas; el proyecto usa EIP-191 para el
  inversor, **EIP-712** para el issuer y **SIWE** para la sesión.
- Los 9 documentos de soporte citados no existen.

---

## 6. Hallazgos transversales

| # | Hallazgo | Guía(s) | Impacto | Evidencia |
|---|---|---|---|---|
| T1 | Stack de datos obsoleto (MongoDB/GridFS → PostgreSQL + `document_files`) | web | Alto | `docker-compose.yml` (postgres:16), `README.md:70-78` |
| T2 | Stack Web3 obsoleto (`ethers` → `wagmi`/`viem`) | web | Alto | `README.md:70`; 0 imports de `ethers` en código |
| T3 | Renombres de apps y contratos | ambas | Medio | `apps/*`, `IdentityCloneable.sol`, `TokenCloneable.sol` |
| T4 | Firmas: EIP-191 → EIP-712 (+SIWE) | web | Medio | `packages/shared/src/claims/eip712.ts`, `RequestDetailModal.tsx` |
| T5 | Marketplace con ABI legacy sin soporte en el contrato actual | web | **Alto (funcional)** | `market.ts:4-7` |
| T6 | Documentos de soporte citados inexistentes (9 web + 2 contratos) | ambas | Medio | `ls` de los nombres citados |
| T7 | Ejercicios de la guía ≠ ejercicios del repo | contratos | Bajo/Medio | `EJERCICIOS_PRACTICOS.md` |
| T8 | Afirmación "ERC-3643 compliant" corregida por el proyecto | contratos | Bajo | `rwa-sc/README.md:21` |
| T9 | El proyecto incorpora piezas nuevas que las guías no recogen (gobernanza, backup/DR, indexer, gates) | ambas | Bajo (positivo) | `estado_proyecto.md`, `pruebas/` |

---

## 7. Recomendaciones priorizadas

### P0 — Actualizar las guías (mayor impacto, bajo esfuerzo)
1. **Stack real**: PostgreSQL (D-095), `wagmi`+`viem`, `rwa.document_files`, monorepo pnpm,
   `apps/identity|issuer|token` (+ `indexer`), puertos y scripts actuales.
2. **Contratos reales**: nombres `IdentityCloneable`/`TokenCloneable`, `addClaim` de 7 argumentos,
   `getClaim(topic,issuer)`, `onlyToken`, y matiz "inspirado en ERC-3643".
3. **Firmas**: EIP-191 (inversor) + EIP-712 (issuer) + SIWE (sesión); eliminar referencias a
   MongoDB/GridFS/ethers.
4. **Enlaces**: sustituir los 9 documentos inexistentes por los reales (`README.md`,
   `GUIA_RAPIDA.md`, `DIAGRAMA_C4.md`, `RepoTecnico/*`).

### P1 — Cerrar la brecha funcional del marketplace
5. Alinear el contrato de mercado con la UI: o se añade un `Marketplace`/`buyToken`/`setPrice` a
   `rwa-sc` (con tests y evento de compra para el indexer), o se retira/marca la UI como legacy.
   Mientras tanto, marcar claramente "no operativo" en la UI y en la guía.
6. Añadir E2E de compra y transferencia (hoy solo claim-flow).

### P2 — Completar material y ejercicios
7. Decidir qué catálogo de ejercicios es el oficial (guía vs `EJERCICIOS_PRACTICOS.md`) y
   referenciarlos mutuamente.
8. Crear/renombrar `TOKEN_CLONE_FACTORY.md` y `COMPLIANCE_AGGREGATOR_FINAL.md` (o retirar las
   referencias de la guía).

### P3 — Mejoras de mantenimiento
9. Añadir un gate/check que detecte referencias a documentos inexistentes (extensión de
   `check_docs.sh`) y otro que detecte términos obsoletos en guías (`MongoDB`, `ethers`,
   `web-identity`) para evitar nueva deriva.
10. Mantener este informe como línea base y repetirlo al cerrar cada etapa.

---

## 8. Anexo A — Verificación reproducible

```bash
# Contratos: inventario, firmas y tests
ls rwa-sc/sc/src rwa-sc/sc/src/compliance
grep -n "function addClaim" -A9 rwa-sc/sc/src/IdentityCloneable.sol
grep -nE "function (registerIdentity|isRegistered|getIdentity)\(" rwa-sc/sc/src/IdentityRegistry.sol
grep -nE "function (addTrustedIssuer|isTrustedIssuer|getIssuerClaimTopics)\(" rwa-sc/sc/src/TrustedIssuersRegistry.sol
grep -nE "function (canTransfer|transferred|created|destroyed)\(" rwa-sc/sc/src/ICompliance.sol
cd rwa-sc/sc && forge test --summary          # 443 tests / 21 suites

# Web: stack, apps, rutas y firmas
ls rwa-web/apps
grep -rIl --include=*.ts --include=*.tsx --exclude-dir=node_modules --exclude-dir=.next ethers rwa-web/apps rwa-web/packages
grep -nE "postgres|mongo" rwa-web/docker-compose.yml
find rwa-web/apps -path '*/app/api/*/route.ts' | sort
grep -rn "signTypedData\|signMessage" rwa-web/apps rwa-web/packages

# Datos: topics canónicos
psql "$DATABASE_URL" -tAc "SELECT id, code FROM rwa.claim_topics ORDER BY id"
```

> Rúbrica codificada y versionada en `RepoTecnico/scripts/gen_informe_evaluacion_guias.py`
> (122 criterios). Este informe se regenera con `python3 RepoTecnico/scripts/gen_informe_evaluacion_guias.py`;
> las evidencias de cada fila permiten auditar cada decisión.

---

*Fin del informe — `INFORME_EVALUACION_GUIAS_ESTUDIANTE_V1.md`*
