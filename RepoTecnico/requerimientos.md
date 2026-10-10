# 📋 Requisitos — Proyecto de Mejora RWA

> Fuente de extracción: análisis estático de `rwa-sc` y `rwa-web` (2026-10-03) + petición del usuario
> ("prepara para mejorar el proyecto"). Este archivo es la guía principal de desarrollo: cada hito de la
> Fase 3 implementa uno o varios requisitos y se marca aquí como completado.
>
> **Versión del documento:** v1.1 — 2026-10-03. Ampliación derivada de la auditoría V1
> (`INFORME_OPTIMIZACION_V1.md`): se añaden RF-011..RF-013 (§3), el Bloque 4 de decisiones (§6) y el
> backlog priorizado (§8).

## 1. Contexto

Plataforma de tokenización RWA tipo **ERC-3643** en dos zonas:

- **`rwa-sc`** (Zona Contratos): 11 contratos Solidity 0.8.20 + 8 suites de test Forge (151 tests)
  + 5 scripts de deploy. Patrones: EIP-1167 clones, Compliance modular, Registry de identidades/claims.
- **`rwa-web`** (Zona WEB): 5 micro-apps Next.js 16 / React 19 / TS / Tailwind v4 sobre Anvil + MongoDB
  (GridFS para documentos). Ethers v6 (viem en `web-registry-trusted2`). **Fuera de alcance de este ciclo (D-003).**

## 2. Hallazgos-base (del análisis) que motivan la mejora

| ID | Hallazgo | Zona | Impacto |
|---|---|---|---|
| HB-01 | `addClaim()` no verifica la firma ECDSA del claim (confianza off-chain) | rwa-sc | Alto |
| HB-02 | `burn()`/`forcedTransfer()` dan poderes absolutos a `AGENT_ROLE` | rwa-sc | Medio-Alto |
| HB-03 | Flag `bypassCompliance` sin guard anti-reentrancia | rwa-sc | Medio |
| HB-04 | `addComplianceModule()` no valida `ICompliance` (`supportsInterface`) | rwa-sc | Medio |
| HB-05 | `lib/` ausente (submodules no inicializados) → no compila; Forge/Anvil no instalados | rwa-sc | Alto |
| HB-06 | Storage muerto en `TokenCloneable` (`_tokenName`, `_tokenSymbol`) | rwa-sc | Menor |
| HB-07 | Docs referencian archivos inexistentes (Token.sol, Identity.sol, 3 .md) | rwa-sc | Medio |
| HB-08 | `web-registry-trusted2` duplica `web-registry-trusted` con stack distinto (viem/react-query) | rwa-web | Medio |
| HB-09 | Direcciones de contratos hardcodeadas en README/apps (sin source de verdad única) | rwa-web | Medio |
| HB-10 | No hay CI/CD ni `docker-compose` (MongoDB y Anvil se asumen locales) | ambos | Alto |
| HB-11 | 151 tests no ejecutados/verificados en este entorno | rwa-sc | Alto |
| HB-12 | `deploy-besu.sh` maneja clave privada sin cifrado (`~/.foundry/keys.json`) | rwa-sc | Medio |
| HB-13 | `IdentityRegistry` no valida que `_identity` sea un contrato: acepta una EOA o un contrato sin la interfaz (`src/IdentityRegistry.sol:38,56`). Detectado en el Ciclo 1b | rwa-sc | Medio |
| HB-14 | `removeIdentity` no comprueba que el wallet esté en `registeredAddresses`; si mapping y array se desincronizan, emitiría el evento sin borrar (`src/IdentityRegistry.sol:73-79`). Hoy inalcanzable | rwa-sc | Bajo |
| HB-15 | `addClaimTopic` acepta el topic `0` (no hay `require(_claimTopic != 0)`, `src/ClaimTopicsRegistry.sol:29-35`). Detectado en el Ciclo 1b | rwa-sc | Bajo |
| HB-16 | Los 3 registries borran con swap-and-pop O(n) y reordenan el array (relacionado con H-20 de la auditoría V1) | rwa-sc | Medio |

> **Nota (dos numeraciones):** Estos 16 hallazgos provienen del análisis base del Lead (HB-13..HB-16 se
> añadieron al ejecutar el Ciclo 1b de la Fase 3). La auditoría V1
> (`INFORME_OPTIMIZACION_V1.md`) usa su propia numeración H-01..H-34; cuando un requisito cite hallazgos de la
> auditoría se indicará como 'H-xx (auditoría V1)'.

## 3. Requisitos Funcionales (RF)

> **Alcance activo (D-003): solo `rwa-sc`.** Orden de trabajo (D-004):
> RF-005 → RF-001 → RF-002 → RF-003 → RF-004 → RF-010 → RF-006 → RF-009 → RF-011 → RF-012 → RF-013.
> RF-007/008: no aplican este ciclo (zona web).
>
> **Nota (auditoría V1):** RF-011, RF-012 y RF-013 provienen de la auditoría V1
> (`INFORME_OPTIMIZACION_V1.md`, hallazgos H-05, H-22 y H-08 respectivamente) y se aprobaron por decisión
> **D-014** (ver §6, Bloque 4). Se mantienen al final del orden de trabajo porque amplían el alcance al
> cierre de los tres fallos de seguridad abiertos.

| ID | Requisito | Hallazgo | Zona |
|---|---|---|---|
| RF-001 | Verificar criptográficamente la firma del claim en `addClaim()` con **EIP-712 tipado** (relevar el struct del claim y validar con `ecrecover`; el issuer debe poder emitir el topic según `TrustedIssuersRegistry`) | HB-01 | rwa-sc |
| RF-002 | Eliminar el flag mutable `bypassCompliance`; reemplazar por control de reentrancia (`ReentrancyGuardUpgradeable`) y bypass limitado al agente vía `forcedTransfer` con destino en whitelist | HB-03 | rwa-sc |
| RF-003 | Validar `supportsInterface(typehash(ICompliance))` al registrar módulos de compliance (token y aggregator) | HB-04 | rwa-sc |
| RF-004 | **Whitelist de destinos + límites** para `burn()`/`forcedTransfer()`: `authorizedDestinations[address]`, `maxBurnPerTx`, `maxForcedPerTx`; solo admin/compliance puede administrar | HB-02 | rwa-sc |
| RF-005 | Asegurar compilación reproducible: submódulos correctos (`forge-std`, OZ v5.5.0, OZ-upgradeable v5.5.0), `forge build` y `forge test` pasando **100%** | HB-05, HB-11 | rwa-sc |
| RF-006 | Corregir docs con referencias rotas; actualizar README; añadir **SECURITY.md** y **CHANGELOG de ABIs** | HB-07 | rwa-sc |
| RF-007 | ~~Unificar o retirar `web-registry-trusted2`~~ **Pausado** (zona web, D-003) | HB-08 | rwa-web |
| RF-008 | ~~Fuente única de verdad para direcciones de contratos~~ **Pausado** (zona web, D-003) | HB-09 | rwa-web |
| RF-009 | **CI GitLab** sobre `rwa-sc-DSH-GCP`: `forge build` + `forge test` + `forge coverage` por commit/MR, con umbral ≥ 80% | HB-10 | rwa-sc |
| RF-010 | Mover secretos fuera de scripts: `deploy-besu.sh` lee `PRIVATE_KEY` de variable de entorno/Secret Manager GCP (`DS_`), no de `keys.json` en disco | HB-12 | rwa-sc |
| RF-011 | Cerrar el fail-open de `isVerified()`: si `claimTopicsRegistry` no está configurado (o no hay topics requeridos), `isVerified` debe devolver `false` (fail-closed) en lugar de `true`. Evidencia: `src/TokenCloneable.sol:245-247`. Cubre H-05 (auditoría V1). Impacto Alto (seguridad). | H-05 (auditoría V1) | rwa-sc |
| RF-012 | Hacer `ComplianceAggregator` fail-closed y acotar su administración: con cero módulos registrados para un token la transferencia debe denegarse (o exigir registro explícito del token), y solo el owner del token (o su rol COMPLIANCE) debe poder añadir/quitar módulos de ese token. Evidencia: `src/compliance/ComplianceAggregator.sol:115-135` y `:50-53`. Cubre H-22 (auditoría V1). Impacto Alto. | H-22 (auditoría V1) | rwa-sc |
| RF-013 | Ciclo de vida de claims: soportar vigencia (expiry) y revocación del claim por parte del issuer autorizado, y que `isVerified` deje de aceptar claims vencidos o revocados. Evidencia: `src/IdentityCloneable.sol:21-28` y `:105-123`. Cubre H-08 (auditoría V1). Impacto Alto. | H-08 (auditoría V1) | rwa-sc |

## 4. Requisitos No Funcionales (RNF)

| ID | Requisito |
|---|---|
| RNF-001 | Los ahorros de gas EIP-1167 documentados (94–98%) deben mantenerse o mejorar |
| RNF-002 | Cobertura de tests ≥ 80% (`forge coverage`) |
| RNF-003 | 100% de tests pasando en CI antes de cada merge |
| RNF-004 | Ningún secreto en repos o scripts (claves solo en Secret Manager GCP o `.env` ignorado) |
| RNF-005 | Nuevas reglas de compliance deben poder agregarse sin modificar el token (extensibilidad) |
| RNF-006 | ~~Las apps web corran con `docker compose up`~~ No aplica este ciclo (zona web, D-003) |

## 5. Requisitos Técnicos (RT)

| ID | Dato |
|---|---|
| RT-001 | Solidity ^0.8.20 · OpenZeppelin 5.5.0 (contracts + upgradeable) · forge-std 1.12.0 (foundry.lock) |
| RT-002 | Next.js 16 · React 19 · TypeScript · TailwindCSS v4 (contexto; fuera de alcance) |
| RT-003 | Web3: ethers v6 (apps 1,2,5) / viem 2.x (app 4) — contexto; fuera de alcance |
| RT-004 | MongoDB 7 (driver nativo + GridFS) · BD `rwa` · colecciones `claim_requests`, `tokens`, `claim_documents` (contexto; fuera de alcance) |
| RT-005 | Redes: Anvil local (chain 31337, `http://localhost:8545`) · **Besu CodeCrypto** (cadena destino, D-008) |
| RT-006 | GCP: `gcp-env.sh` global · project `mcc-ecommerce` (default) · Secret Manager con prefijo `DS_` |
| RT-007 | Solidity pragma unico 0.8.20 en todos los contratos |
| RT-008 | Redeploy limpio permitido (D-009): se puede mover el layout de storage; sin obligacion de compatibilidad binaria con lo desplegado antes |

## 6. Entrevista (RESUELTO — 4 bloques, 2026-10-03)

### Bloque 1 — Alcance y prioridades (OK)
- **Q1:** Alcance = **solo `rwa-sc`** (D-003). RF-007 y RF-008 no aplican este ciclo (web).
- **Q2:** Prioridad = **seguridad + estabilidad del build** (D-004).
- **Q3:** Rama de trabajo = **`rwa-sc-DSH-GCP`** (D-005).

### Bloque 2 — Control y seguridad (OK)
- **Q4:** `AGENT_ROLE`: whitelist de destinos + limites (D-006) → RF-004.
- **Q5:** Firma de claims: **EIP-712 tipada** con verificacion on-chain (D-007) → RF-001.
- **Q6:** Cadena destino **Besu CodeCrypto**; CI en **GitLab** (D-008) → RF-005/009.

### Bloque 3 — Entregables (OK)
- **Q7:** Redeploy limpio permitido (D-009) → RT-008.
- **Q8:** Pruebas: 100% tests + nuevos + fuzz + coverage >= 80% (D-010) → RNF-002/003.
- **Q9:** Docs tecnicas + SECURITY.md + CHANGELOG de ABIs (D-011) → RF-006.

### Bloque 4 — Fase 2 (auditoría) (OK)
- **D-014 (alcance V1):** se amplía el alcance a los **3 fallos abiertos de seguridad** de la auditoría V1
  (H-05 → **RF-011**, H-22 → **RF-012**, H-08 → **RF-013**); el resto de hallazgos (H-01..H-34 del informe,
  salvo los ya cubiertos por RF-001..RF-010/RNF-001..RNF-006) pasa al **backlog de la sección 8**.
- **D-015 (suites muertas):** los tests se adaptan al **patrón de producción factory + clon + `initialize`**
  (no se crean contratos harness nuevos), afectando a `test/Token.t.sol` y `test/ComplianceAggregator.t.sol`.
- **D-016 (mint):** se **MANTIENE** el chequeo de compliance en `mint()` (`src/TokenCloneable.sol:180-182`);
  queda **cerrada la decisión abierta D-012** con la alternativa **A (compliant siempre)**.
- **D-017 (cobertura):** la métrica **RNF-002** de cobertura ≥ 80% se calcula sobre `src/` **excluyendo las
  interfaces** (`src/ICompliance.sol`, `src/IClaimTopicsRegistry.sol`) y **excluyendo `test/`**.

### Bloque 5 — Fase 2 (diseño del documento técnico) (OK)
> Decisiones tomadas al resolver las 6 preguntas de `AUDITORIA_DOCUMENTO_TECNICO.md` (P1..P6). Se registran
> también como D-019..D-024 en `estado_proyecto.md` y en `documento_tecnico.md`.

- **D-019 (P1 · cierra DF3-01):** ciclo de vida = **redeploy limpio con EIP-1167**, sin proxy actualizable;
  se exige **runbook de migración** documentado (coherente con D-009 / RT-008).
- **D-020 (P2 · cierra DT-01):** firma del claim con dominio EIP-712
  `{name: "RWA-Identity", version: "1", chainId, verifyingContract: <clon de identidad>}` y
  `CLAIM_TYPEHASH = keccak256("Claim(address walletOwner,uint256 topic,uint256 scheme,bytes32 dataHash,uint256 expiresAt)")`.
  **`expiresAt` va dentro del digest**: renovar la vigencia exige nueva firma del issuer (RF-001 + RF-013).
- **D-021 (P3 · cierra DF3-03):** gobernanza = **roles separados** (admin en multisig, `AGENT_ROLE` operativo
  con los límites de RF-004, `COMPLIANCE_ROLE` independiente) + **multisig 2-de-3** + **timelock** para
  acciones sensibles + **custodio de claves designado** con rotación (mitiga H-06 y cubre el criterio B-4).
- **D-022 (P4 · cierra la parte de `mint` de DT-03):** se añade **tope de suministro administrable con evento**
  (`maxSupply`); no puede bajarse por debajo de lo ya emitido ni subirse sin evento (RF-004).
- **D-023 (P5 · cierra DF3-04):** `ComplianceAggregator` **fail-closed** con **registro automático del token al
  añadir su primer módulo** (sin `registerToken` externa); los tokens ya desplegados se corrigen por redeploy
  (D-019) (RF-012).
- **D-024 (P6 · cierra DT-07):** la **auditoría externa (R-9/H-16) es bloqueante solo para producción con
  activos reales**, no para cerrar RF-001..RF-013; queda como riesgo y condición de salida.

### Bloque 6 — Fase 3 (aclaraciones de diseño durante los ciclos)
- **D-025 (alcance de la verificación de issuer en RF-001):** `addClaim` verifica la **firma EIP-712**
  (dominio `RWA-Identity`/`1`/`chainId`/clon y `CLAIM_TYPEHASH` con `expiresAt`), exige `scheme == 1`,
  `signature.length == 65` y `recovered == issuer != address(0)`. La autorización del issuer **para el topic**
  la sigue imponiendo `TokenCloneable.isVerified` contra el `TrustedIssuersRegistry` **del token** (check
  autoritativo, ya implementado): el clon de identidad no conoce el registry de cada token y una firma válida
  ya prueba el consentimiento del issuer, de modo que un issuer no autorizado nunca cuenta. Se descarta
  añadir al clon una referencia al registry (complejidad sin ganancia de seguridad); si se quiere defensa en
  profundidad, queda como mejora de backlog.
- **D-026 (implementación EIP-712 sin `EIP712Upgradeable`):** OpenZeppelin v5.5.0 declara
  `pragma solidity ^0.8.24` en `EIP712Upgradeable.sol` (y en `EIP712.sol`), incompatible con el
  `solc_version = "0.8.20"` fijado por RF-005 y con RT-007 ("pragma único 0.8.20"). Para no romper el
  toolchain pinneado (ni la reproducibilidad ni el baseline de gas del Ciclo 1), el clon reproduce
  exactamente el mismo digest EIP-712 (`\x19\x01 || domainSeparator || structHash`, mismos typehashes)
  con funciones internas documentadas. Sí se usa `ECDSA` de OpenZeppelin (válido en 0.8.20) para la
  recuperación, de modo que las comprobaciones de maleabilidad (`s` bajo, `v ∈ {27,28}`) siguen siendo
  las de la librería. La alternativa (subir `solc` a ≥ 0.8.24) queda como posible decisión de un ciclo
  futuro si se adopta `EIP712Upgradeable`.
- **D-027 (alcance de `createIdentityWithClaim`):** la ruta de la factory inicializa el clon con la
  propia factory como `owner` temporal (necesario para invocar `addClaim`, que es `onlyOwner`) y
  transfiere la propiedad al titular después. Por tanto, el `walletOwner` firmado en esa ruta es la
  **dirección de la factory**, no el titular; el anti-replay entre identidades lo garantiza
  `verifyingContract` (dirección única del clon). Se mantiene el comportamiento y se documenta en
  NatSpec y en `CHANGELOG_ABIS.md`; alinear la semántica (owner final en el digest) queda como mejora
  de backlog.
- **D-028 (reubicación de la autorización de issuer por topic):** los criterios de CU-02/CU-03 que
  pedían `hasClaimTopic(issuer, topic)` dentro de `addClaim` se interpretan conforme a D-025: la
  comprobación autoritativa se hace en `TokenCloneable.isVerified` con el `TrustedIssuersRegistry` del
  token. En el Ciclo 2 se implementa como test de integración
  (`test_RF001_issuer_no_autorizado_para_topic_no_verifica`) en lugar de como `require` en el clon; no
  se añade al clon un registry de la lista blanca (coherente con D-025). Los literales
  `"Issuer not authorized for topic"` de CU-03 quedan, por tanto, sin efecto en el clon.
- **D-029 (guard de reentrancia stateless en lugar de `ReentrancyGuardUpgradeable`):** OpenZeppelin
  **v5.5.0 eliminó** `ReentrancyGuardUpgradeable` de `contracts-upgradeable` (su CHANGELOG indica que
  los contratos marcados *stateless* —`ReentrancyGuard` incluido— ya no se transpilan y que los
  usuarios de las variantes upgradeable deben importar la versión de `contracts`). El
  `ReentrancyGuard` de `@openzeppelin/contracts` usa almacenamiento con namespace ERC-7201 (vía
  `StorageSlot`), **no ocupa slots del layout lineal** y es *clone-safe*: el slot del clon arranca en
  `0 != ENTERED`, por lo que el guard funciona sin `initialize`. Por eso **no** se añade una llamada
  de inicialización (no existe) y la decisión de dónde proteger se documenta en D-030. Es la misma
  librería que usa el benchmark (D-032).
- **D-030 (ubicación del `nonReentrant`):** se aplica a los **cinco puntos de entrada externos con
  estado** que alcanzan contratos externos (`transfer`, `transferFrom`, `mint`, `burn`,
  `forcedTransfer`) y **no** al `_update` interno. Ponerlo solo en `_update` cubriría el callback
  `transferred` de `transfer`/`transferFrom`, pero dejaría sin guardar los bucles de notificación
  *post-actualización* de `mint` (`created`), `burn` (`destroyed`) y `forcedTransfer`
  (`transferred`); y ponerlo en `_update` **y** en `mint`/`burn` provocaría un revert por guard
  anidado (`ReentrancyGuardReentrantCall`) en el flujo normal. Guardar los puntos de entrada cubre
  todas las rutas sin anidamiento. `nonReentrant` se coloca como **primer modificador** (regla del
  linter `non-reentrant-not-first`) y `canTransfer` sigue siendo `view` sin guard.
- **D-031 (ruta explícita `_forcedUpdate` y `from != address(0)`):** el flag mutable
  `bypassCompliance` se sustituye por la función interna `_forcedUpdate(from,to,amount)` que llama
  directamente a `super._update` (salta la comprobación de compliance y la notificación del
  override) y **no escribe ningún flag de storage**; `forcedTransfer` es la única ruta que la invoca,
  sigue siendo `onlyRole(AGENT_ROLE)` y sigue notificando `transferred`. Se añade
  `require(from != address(0), "Invalid from address")` (CU-04 A4.6 / B-05), que cierra la acuñación
  silenciosa que antes permitía `forcedTransfer(address(0), ...)`. La **whitelist
  `authorizedDestinations` y los topes `maxForcedPerTx`/`maxBurnPerTx` siguen diferidos a RF-004
  (Ciclo 5)**; la dependencia queda anotada en el NatSpec de `forcedTransfer`. El gate
  `script/ci/check_no_bypass_flag.sh` (criterio `ci_check_RF002_no_bypassCompliance_storage`) se apoya
  en `forge inspect TokenCloneable storage-layout --json`; el test
  `test_RF002_storage_layout_sin_bypassCompliance` lo verifica además leyendo el artefacto compilado,
  para lo que `foundry.toml` añade `extra_output = ["storageLayout"]`.
- **D-032 (benchmark de gas equivalente al añadir el guard):** `test/benchmarks/TokenBenchmark.sol`
  incorpora el mismo `ReentrancyGuard` stateless para que la comparación "clon EIP-1167 vs despliegue
  completo + init" siga siendo honesta. `createToken` (**381.570** gas) no cambia porque el guard es
  stateless y no añade inicialización ni código por clon; el despliegue completo sube a **882.257**
  gas (+23.159) y el ahorro relativo mejora (56,75 %). Los umbrales (`>= 45 %` y `> 300.000`) **no se
  tocan** porque se siguen cumpliendo con holgura.

- **D-033 (validación ERC-165 — diseño):** `ICompliance` pasa a `interface ICompliance is IERC165` y los
  **cuatro** contratos de compliance heredan `ERC165` e implementan
  `supportsInterface(bytes4)`: `MaxBalanceCompliance`, `MaxHoldersCompliance`, `TransferLockCompliance` y
  `ComplianceAggregator` (este último también es módulo del token). Devuelven `true` para
  `type(ICompliance).interfaceId` y `type(IERC165).interfaceId` (`0x01ffc9a7`). El `interfaceId` de
  `ICompliance` **no cambia** al heredar `IERC165` porque Solidity excluye las funciones heredadas del
  cálculo (FD-03, verificado por `test_RF003_interfaceId_ICompliance_correcto`). La validación se hace con
  un `staticcall` a `supportsInterface(type(ICompliance).interfaceId)` que exige
  `success && data.length >= 32 && decode == true`: así se rechazan EOA (retorno vacío), contratos sin la
  función (fallo de llamada o retorno corto) y contratos que devuelven `false`, siempre con
  `"Module does not implement ICompliance"`. Se evita el `try/catch` de alto nivel para no depender del
  chequeo de `extcodesize` ni de la decodificación implícita. Se aplica en `TokenCloneable.addComplianceModule`
  y en `ComplianceAggregator.addModule`.
- **D-034 (rechazo de duplicados en el token):** `TokenCloneable.addComplianceModule` rechaza un módulo ya
  registrado con `"Module already added"` (criterio EARS de CU-05) mediante un barrido O(n) de
  `complianceModules`, coherente con el `isModuleActive` del aggregator (que ya impedía duplicados).
- **D-035 (HB-13 — alcance de la validación de identidad):** se exige `_identity.code.length > 0` en
  `registerIdentity` **y** en `updateIdentity`, con revert explícito `"Identity must be a contract"`
  (rechaza EOAs). No se añade comprobación de interfaz en el registry: D-025/D-028 ya descartaron que el
  registry conozca la interfaz de claim; la identidad es un clon `IdentityCloneable` cuya conformidad se
  prueba en `addClaim`/`isVerified`. Los tests existentes de `IdentityRegistry.t.sol` (que usaban EOAs
  deterministas para el *bookkeeping*) se adaptan dotando a esas direcciones de código con
  `vm.etch(addr, hex"00")`, sin tocar aserciones ni eliminar casos.
- **D-036 (HB-15 — topic 0):** `addClaimTopic` rechaza el topic `0` con `"Invalid claim topic"` antes de la
  comprobación de duplicado, tanto en `ClaimTopicsRegistryCloneable` (producción) como en
  `ClaimTopicsRegistry` (variante de testing). El test que documentaba la aceptación
  (`test_AddClaimTopic_AcceptsZeroValue`) se **invierte** en `test_HB15_AddClaimTopic_RevertWhen_ZeroValue`
  (conserva el caso de estudio, cambia la aserción a la nueva regla) y `testFuzz_ClaimTopicExists` se acota
  a `[1, type(uint256).max]`.
- **D-037 (impacto en módulos ya registrados — redeploy limpio):** un módulo desplegado antes de RF-003 que
  no implemente ERC-165 **no puede volver a registrarse** (ni por token ni por aggregator) tras el cambio.
  Como los módulos ya dados de alta permanecen en el estado y no hay proxy actualizable (D-019/D-023), el
  ciclo de vida es **redeploy limpio**: volver a desplegar cada módulo con el `supportsInterface` nuevo,
  actualizar el `ComplianceAggregator` (que es módulo del token y también debe ser ERC-165) y re-registrar
  los módulos por token. Documentado en `CHANGELOG_ABIS.md`.

### Decisiones resueltas en la Fase 3 (una a una, 2026-10-03)

> Resuelven las DF3 que quedaban abiertas. Los criterios operativos están en `plan_desarrollo.md`.

- **D-038 (DF3-07 · vigencia del claim):** `expiresAt == 0` significa **sin caducidad** (perpetuo); con un
  timestamp futuro, el claim vence y `isVerified` lo rechaza (Ciclo 8 / RF-013). La renovación exige nueva firma
  (D-020). No se prohibe el valor 0, por compatibilidad con los claims ya emitidos.
- **D-039 (DF3-06 · gas de RNF-001):** la CI ejecuta `forge snapshot --check --tolerance 5` sobre el
  `.gas-snapshot` versionado; superar el 5 % obliga a actualizar el snapshot en un commit explícito.
- **D-040 (DF3-08 · redes y despliegue):** el despliegue y la verificación del Ciclo 9 se hacen contra el
  **Anvil de GCP** (servicio global: `source /home/dsh/workspace/gcp-env.sh` → `RPC_URL`, `CHAIN_ID=31337`),
  con **Besu CodeCrypto como alternativa** documentada. El script parametriza `RPC_URL`/`CHAIN_ID` y **valida la
  red antes del broadcast**; la clave se lee de entorno / Secret Manager (`DS_*`), nunca de un archivo en claro.
- **D-041 (DF3-10 · datos off-chain):** se **confirma diferido al área web** (`base_datos.sql` sigue siendo
  borrador y MongoDB local la BD actual); el destino (Atlas / Cloud SQL / on-premise) y el tratamiento de
  PII/GDPR (H-11/R-3) se abordan en el ciclo del área web.
- **D-042 (Ciclo 11 · gate de cobertura):** la CI exige el **agregado de `src/` ≥ 80 %** (D-017) **y un mínimo
  por contrato ≥ 80 %**, para que ningún contrato concreto quede sin cubrir tras un promedio alto.

## 7. Mapa RF → casos de uso (Fase 2)

Ver `casos_uso/casos_uso.md` (**v1.3, 17 casos de uso**, 92 criterios Gherkin + 50 EARS = 142), auditado y corregido
(ver `casos_uso/AUDITORIA_CASOS_USO.md`) y con diagramas en `casos_uso/diagramas_casos_uso.md` (v1.1).
- Cubiertos: RF-001..RF-006, RF-009, RF-010 y RNF-001..RNF-005.
- **Ampliación auditoría V1 (D-014):** RF-011 (fail-closed de `isVerified`) → **CU-15**; RF-012
  (`ComplianceAggregator` fail-closed y administración por token) → **CU-16**; RF-013 (vigencia y revocación de
  claims) → **CU-17**. Los tres marcados como "A IMPLEMENTAR" en los casos de uso.
- Sin cobertura por alcance (D-003): RF-007, RF-008, RNF-006.
- Datos reales de la suite (2026-10-03): 151 tests declarados, 93 pasan, 5 fallan y 53 no arrancan;
  coverage 42,86%. Ver `metricas_ejecucion.md`.

## 8. Backlog priorizado (auditoría V1 — no en este ciclo)

> Fuente: `INFORME_OPTIMIZACION_V1.md` (34 hallazgos H-01..H-34; plan §8; criterios §9).
> **Decisión D-014:** este ciclo solo incorpora al alcance activo los tres fallos abiertos de seguridad
> (H-05 → RF-011, H-22 → RF-012, H-08 → RF-013). El resto de hallazgos permanece aquí como backlog.
> No se inventan hallazgos: todos los IDs y evidencias proceden del informe V1.

### 8.1 Cobertura de los 34 hallazgos V1

| Hallazgo | Título (breve) | Estado | Cobertura actual / acción de backlog |
|---|---|---|---|
| H-01 | Claims auto-forjados: `addClaim` sin verificación de firma | **Cubierto** | RF-001 (EIP-712 + `ecrecover`) |
| H-02 | "139 tests (100% passing)" falso; 2 suites muertas; coverage 42,86% | **Cubierto** | RF-005, RNF-002, RNF-003, D-015 |
| H-03 | Cifras de ahorro de gas contradictorias; RNF-001 sin criterio operativo | **Cubierto (parcial)** | RNF-001; operacionalización (`.gas-snapshot`) al backlog M-2 |
| H-04 | Build no reproducible: código sin versionar, submódulos, sin CI | **Cubierto** | RF-005, RF-009 |
| H-05 | `isVerified()` fail-open sin `claimTopicsRegistry` | **Cubierto** | RF-011 (D-014) |
| H-06 | Centralización de poderes: una EOA, `AGENT_ROLE` absoluto | **Cubierto (parcial)** | RF-004; gobernanza multisig/timelock al backlog R-7 |
| H-07 | Factories permissionless; EIP-1167 sin ruta de upgrade | Backlog | M-7, R-6 |
| H-08 | Claims sin vigencia ni revocación por el issuer | **Cubierto** | RF-013 (D-014) |
| H-09 | Catálogo RNF incompleto (ISO 25010) | Backlog | R-1 (ver §8.3) |
| H-10 | Sin RNF de cumplimiento regulatorio (sanciones/PEP/AML) | Backlog | R-2 |
| H-11 | PII/KYC sin custodio, base legal, cifrado ni retención | Backlog | R-3 |
| H-12 | Sin RNF de observabilidad ni indexación de eventos | Backlog | R-4 (ver §8.3) |
| H-13 | Catálogo de claim topics divergente | Backlog | M-8 |
| H-14 | `diccionario_datos.md` describe storage inexistente | Backlog | QW-6 |
| H-15 | Docs y contratos citados como existentes que no existen | **Cubierto** | RF-006 |
| H-16 | "ERC-3643 compliant"/"production-ready" sin criterio | Backlog | R-8 (RF-006 solo cubre `SECURITY.md`) |
| H-17 | `addComplianceModule` no valida `ICompliance` (ERC-165) | **Cubierto** | RF-003 |
| H-18 | Reentrancia en callbacks / flag `bypassCompliance` | **Cubierto** | RF-002 |
| H-19 | Estado singleton cross-token en módulos de compliance | Backlog | M-10 |
| H-20 | Arrays no acotados O(n) y vistas sin paginación | Backlog | M-11 |
| H-21 | Sin indexación de eventos ni artefactos de despliegue | Backlog | M-15, R-4 |
| H-22 | `ComplianceAggregator` fail-open y owner global | **Cubierto** | RF-012 (D-014) |
| H-23 | Rúbrica de evaluación no operacional | Backlog | M-16 |
| H-24 | `deploy-besu.sh` parcial (no despliega registries/token) | Backlog | M-14 |
| H-25 | Falta stakeholder regulador/supervisor y reporte | Backlog | R-2 |
| H-26 | Sin operador de red Besu ni validación de `chainId` | Backlog | M-17 |
| H-27 | Sin soporte al inversor / recuperación auditable | **Cubierto (parcial)** | RF-004 (whitelist/topes); actor de soporte al backlog |
| H-28 | Clave privada en claro en `deploy-besu.sh` | **Cubierto** | RF-010, RNF-004 |
| H-29 | El deploy no instancia/activa módulos de compliance | Backlog | M-14 |
| H-30 | Sin backup/DR, RPO/RTO ni runbook de recuperación | Backlog | R-5 (ver §8.3) |
| H-31 | Éxito del deploy decidido por `grep` de logs | Backlog | QW-11 |
| H-32 | Exactitud documental (`DEPENDENCIAS_CONTRATOS`, `metricas_ejecucion`) | Backlog | QW-6 |
| H-33 | Estado de fases/rama contradictorio entre docs | Backlog | QW-12 |
| H-34 | Los cambios de `tokenContract` no emiten evento | Backlog | QW-8 |

**Resumen:** 10 hallazgos **cubiertos** (H-01, H-02, H-04, H-05, H-08, H-15, H-17, H-18, H-22, H-28),
3 **parcialmente cubiertos** (H-03, H-06, H-27) y 21 **en backlog**.

### 8.2 Agrupación por el plan del informe V1 (§8) — esfuerzo S/M/L

**Esfuerzo:** S = ≤ 1 día · M = 2–5 días · L = > 1 semana.
> Nota: los ítems ya asignados a RF-001..RF-013 pertenecen al ciclo activo; se listan aquí para trazabilidad
> completa del plan. El resto constituye el backlog propiamente dicho.

#### Quick wins (≤ 1 semana, sin rediseño)

| # | Acción | Hallazgo | Esfuerzo |
|---|---|---|---|
| QW-1 | Corregir `setUp` de `Token.t.sol` y `ComplianceAggregator.t.sol` (factory + clon + `initialize`, D-015) | H-02 | S |
| QW-2 | Sustituir "139 tests (100% passing)" y "production-ready" por el estado real medido | H-02, H-16 | S |
| QW-3 | Fail-closed en `isVerified()` cuando `claimTopicsRegistry == address(0)` + test de regresión | H-05 | S |
| QW-4 | Etiquetar `OPTIMIZACION_VERIFICACION.md` como "estimación no medida" y retirar la tabla "Benchmarks" | H-03 | S |
| QW-5 | Unificar `.gitmodules` (raíz con los 3, eliminar el de `sc/`) y no ignorar `lib/` o documentar bootstrap | H-04 | S |
| QW-6 | Corregir `diccionario_datos.md` y `DEPENDENCIAS_CONTRATOS.md` contra storage/imports reales | H-14, H-32 | S |
| QW-7 | Actualizar `entornos_globales.md` (Forge existe, `lib/` poblada, `export PATH`) y HB-05/HB-11 | H-04 | S |
| QW-8 | Emitir evento `TokenContractSet` en los 3 módulos de compliance | H-34 | S |
| QW-9 | Cargar `PRIVATE_KEY` desde entorno/Secret Manager; no usar `--private-key` en `argv` | H-28 | S |
| QW-10 | Eliminar referencias a documentos y contratos inexistentes en README/START_HERE/GUIA | H-15 | S |
| QW-11 | Corregir el criterio de éxito de `deploy-besu.sh` (verificar con `cast code`/recibo, no `grep`) | H-31 | S |
| QW-12 | Actualizar `estado_proyecto.md` y `entornos_globales.md` (rama `rwa-sc-DSH-GCP`, fases verificables) | H-33 | S |

#### Mejoras (2–4 semanas)

| # | Acción | Hallazgo | Esfuerzo |
|---|---|---|---|
| M-1 | RF-001: EIP-712 + `ecrecover` en `addClaim`; issuer autorizado por topic; tests negativos | H-01 | L |
| M-2 | Reescribir los 3 tests de ahorro de gas y crear `.gas-snapshot`; RNF-001 operativo | H-03 | M |
| M-3 | `ReentrancyGuardUpgradeable` en `transfer`/`forcedTransfer`/`mint`/`burn` y aggregator | H-18 | M |
| M-4 | RF-003: `supportsInterface` ERC-165 y validación de módulos en token y aggregator | H-17 | M |
| M-5 | RF-004: `authorizedDestinations`, `maxBurnPerTx`, `maxForcedPerTx`, eventos; separar `AGENT_ROLE` | H-06 | M |
| M-6 | RF-013: `expiresAt`/`revoked` en el claim y revocación por issuer consultada por `isVerified` | H-08 | M |
| M-7 | Restringir factories a allowlist de emisores; proteger `createRegistryForToken` y `createIdentity` | H-07 | M |
| M-8 | Catálogo único y versionado de claim topics, alineado en las 5 fuentes | H-13 | M |
| M-9 | RF-012: `ComplianceAggregator` fail-closed y gestión de módulos restringida al admin del token | H-22 | M |
| M-10 | Aislar estado por token en módulos de compliance o rechazar módulo ya asociado | H-19 | M |
| M-11 | Sustituir arrays O(n) por mappings/índices O(1) y vistas paginadas | H-20 | L |
| M-12 | Pipeline CI con `forge build`, `fmt --check`, `test`, `coverage ≥ 80 %` | H-04, H-02 | M |
| M-13 | Versionar todo el árbol en `rwa-sc-DSH-GCP`; fijar `solc_version`, optimizer y `evm_version` | H-04 | S–M |
| M-14 | Deploy end-to-end: registries + token + módulos de compliance con verificación post-deploy | H-24, H-29 | M |
| M-15 | Persistir artefactos de despliegue (JSON con direcciones, ABIs, `chainId`, bloque) | H-21 | M |
| M-16 | Convertir la rúbrica de `EJERCICIOS_PRACTICOS.md` en criterios observables | H-23 | S–M |
| M-17 | Validar `chainId`/red y parametrizar `RPC_URL` antes de cualquier broadcast | H-26 | S–M |

#### Roadmap (1–3 meses)

| # | Acción | Hallazgo | Esfuerzo |
|---|---|---|---|
| R-1 | Catálogo RNF completo por categoría ISO 25010, con criterios medibles y responsables | H-09, H-30, H-10 | M |
| R-2 | RNF regulatorios (sanciones/PEP/AML, retención, reporte) y mapeo normativo | H-10, H-25 | L |
| R-3 | Política de protección de datos: cifrado GridFS, minimización on-chain, retención/supresión, DPIA, DPO | H-11 | L |
| R-4 | Capa de indexación de eventos (indexer/subgraph) + RNF de observabilidad con alertas | H-12, H-21 | L |
| R-5 | Backup/DR de MongoDB/GridFS con RPO/RTO y runbook de recuperación on-chain | H-30 | M |
| R-6 | Decidir ciclo de vida: proxy actualizable con storage gaps **o** runbook de redeploy limpio | H-07 | L |
| R-7 | Gobernanza con multisig/timelock, reparto de roles y custodio de claves con rotación | H-06, H-25 | M |
| R-8 | Sustituir afirmaciones de conformidad por declaración verificable; `SECURITY.md` y `LICENSE` | H-16 | M |
| R-9 | Auditoría externa de la versión candidata antes de activos reales | H-01, H-16 | L |

### 8.3 RNF faltantes de ISO 25010 (backlog)

Tomado de `INFORME_OPTIMIZACION_V1.md` §6. El catálogo actual solo cubre gas (RNF-001), cobertura (RNF-002),
tests en CI (RNF-003), secretos (RNF-004) y extensibilidad (RNF-005); RNF-006 es N/A por D-003.

| # | Categoría ISO 25010 | RNF faltante | Hallazgo | Esfuerzo |
|---|---|---|---|---|
| 1 | Cumplimiento regulatorio | Screening de sanciones/PEP/AML y rescreening; retención/trazabilidad de registros; reporte regulatorio; restricciones por jurisdicción; mapeo normativo | H-10, H-25 | L |
| 2 | Seguridad de la información / privacidad | Base legal y consentimiento; cifrado de PII KYC; minimización on-chain; retención y supresión; DPIA | H-11 | L |
| 3 | **Observabilidad / monitoreo** | Eventos mínimos monitorizados; alertas de riesgo; retención de logs/índice; canal de incidentes y tiempos de detección | **H-12**, H-21 | L |
| 4 | **Fiabilidad operativa / continuidad** | Disponibilidad y tolerancia a fallos; política de backup y prueba de restauración con RPO/RTO; runbook de recuperación on-chain | **H-30**, H-27 | M |
| 5 | **Portabilidad / reproducibilidad** | Bootstrap reproducible y multiplataforma; `solc`/`evm_version` fijados; soporte multi-red y validación de `chainId`; artefactos versionados | H-04, H-26 | M |
| 6 | **Mantenibilidad** | Versionado de ABIs e implementaciones; umbral de deuda técnica; análisis estático obligatorio (p. ej. Slither sin High); política de actualización del patrón clone | H-04, H-07 | M |
| 7 | Eficiencia (más allá del gas de despliegue) | Umbrales de gas por operación en runtime con `forge snapshot`; límites operativos de arrays y paginación | H-03, H-20 | M |
| 8 | **Usabilidad / accesibilidad (N/A justificado)** | No aplica al ciclo activo (contratos sin UI; `rwa-web` fuera de alcance por D-003); debe marcarse N/A con justificación explícita | **H-09** | — |

> **Fiabilidad, mantenibilidad, portabilidad y backup/DR** derivan además de **H-09** (catálogo RNF incompleto);
> **observabilidad** de **H-12/H-21**; **backup/DR** de **H-30**; **usabilidad** se marca N/A con justificación (H-09).
