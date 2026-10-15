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

- **`rwa-sc`** (Zona Contratos): 15 contratos Solidity 0.8.20 (11 en `src/` + 4 en `src/compliance/`) + 24 suites de test Forge (420 tests)
  + 7 scripts `.s.sol` de deploy + `deploy.sh` + gates de CI. Patrones: EIP-1167 clones, Compliance modular, Registry de identidades/claims.
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
| HB-14 | `removeIdentity` no comprueba que el wallet esté en `registeredAddresses`; si mapping y array se desincronizan, emitiría el evento sin borrar (`src/IdentityRegistry.sol:73-79`). Hoy inalcanzable. **Resuelto en el Ciclo 8 (D-048)** | rwa-sc | Bajo |
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
- **D-016 (mint):** se **MANTIENE** el chequeo de compliance en `mint()` (`src/TokenCloneable.sol:311`, bucle `canTransfer(address(0), to, amount)`);
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
  `CLAIM_TYPEHASH = keccak256("Claim(address walletOwner,uint256 topic,uint256 scheme,bytes32 dataHash,uint256 expiresAt,uint256 nonce)")`
  (el `nonce` lo añade D-050 en el Ciclo 8c; **el typehash vigente incluye `nonce`**).
  **`expiresAt` y `nonce` van dentro del digest**: renovar la vigencia exige nueva firma del issuer y una firma anterior a una revocación no sirve (anti-replay) (RF-001 + RF-013).
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
- **D-043 (Ciclo 7 · `require` de dirección cero inalcanzables con `onlyToken`):** al restringir
  `addModule`/`removeModule` a `msg.sender == token`, las comprobaciones `token != address(0)` (en ambas) y
  `module != address(0)` del **aggregator** dejan de ser alcanzables desde llamadores externos: nadie puede
  ser `address(0)` y el token ya pre-valida el módulo en `addModuleThroughAggregator`. Se **conservan** en
  `src/` (no se altera la semántica del ciclo) como defensa en profundidad y se documentan aquí; la cobertura
  de **ramas** de `ComplianceAggregator` baja de 100 % (18/18) a **88,89 % (16/18)**, muy por encima del mínimo
  por contrato del 80 % (D-042) y sin afectar a las líneas.
- **D-044 (Ciclo 7 · adaptación de suites a la ruta de producción):** las 3 suites con llamadas directas
  (`ComplianceAggregator.t.sol`, `RF003_ERC165.t.sol`, `TokenReentrancy.t.sol`) se adaptan a la ruta
  **token → aggregator** (`token.addComplianceModule(aggregator)` una vez y, después,
  `addModuleThroughAggregator`/`removeModuleThroughAggregator`), conservando intención y aserciones. Las 4
  llamadas directas que quedan en esas suites (y 1 en la nueva) son **negativas a propósito** para comprobar
  `"Only token admin can call"`. Dos tests se renombran para reflejar la semántica nueva —`test_NoModules_AllowsAll`
  → `test_NoModules_FailClosed` (aserción invertida a fail-closed) y `test_TokenAndOwnerCanBothManageModules` →
  `test_TokenCanManageModules_OwnerCannot`— sin borrar ni debilitar ningún caso.
- **D-045 (Ciclo 8 · semántica de vigencia):** se confirma **D-038**: `expiresAt == 0` = **sin caducidad**
  (perpetuo); con `expiresAt > 0` el claim es válido mientras `block.timestamp < expiresAt` (en el límite
  exacto ya vence). La vista `IdentityCloneable.hasValidClaim(topic, issuer)` es la **única fuente de verdad**
  y la que consulta `TokenCloneable.isVerified`; no se duplica la regla en el token.
- **D-046 (Ciclo 8 · revocación por el issuer y layout):** `revokeClaim(topic, issuer)` exige
  `msg.sender == _issuer` y que el claim exista, **sin `onlyOwner`** (el titular no revoca en nombre del
  issuer); marca `revoked = true` y **conserva** `data`/`uri`/`signature` (no borra el histórico de
  `ClaimAdded` ni retira al issuer de `topicIssuers`). El titular conserva `removeClaim` (onlyOwner) para
  borrar su propio claim. `revoked` se **añade al final** del struct `Claim` (append-only: el *storage
  layout* previo queda intacto); sin proxy actualizable (D-019), el ciclo de vida es redeploy limpio (D-037).
- **D-047 (Ciclo 8 · evento `ClaimRevoked`):** se emite `ClaimRevoked(uint256 indexed topic, address indexed
  issuer)` (topic0 `0x2773a486…`), **sin `timestamp`**, ciñéndose al diseño obligatorio de RF-013; el instante
  de la revocación es el `block.timestamp` del bloque del evento. Queda documentado como desviación del texto
  ilustrativo de CU-17 (`ClaimRevoked(topic, issuer, timestamp)`).
- **D-048 (Ciclo 8 · HB-14 · pertenencia al borrar):** `IdentityRegistry.removeIdentity` comprueba
  explícitamente que el wallet figure en `registeredAddresses` y revierte `"Wallet not in registered
  addresses"` si no, en lugar de confiar solo en `registered[_wallet]`; se conservan *swap-and-pop* y el
  evento `IdentityRemoved`. La desincronización mapping/array es hoy **inalcanzable** por las rutas públicas;
  la rama defensiva se cubre forzando el storage con `vm.store` en `test_HB14_*`.
- **D-049 (Ciclo 8 · `isVerified` consulta la validez, fail-closed):** `TokenCloneable.isVerified` exige,
  además de `trustedIssuersRegistry.hasClaimTopic(...)`, que `hasValidClaim(topic, issuer)` del clon devuelva
  `true` por `staticcall`; un fallo de la llamada, una identidad que no implemente la vista o un retorno mal
  formado se tratan como **no válido** (coherente con el fail-closed de RF-011). El cambio es de
  comportamiento: una identidad desplegada antes del Ciclo 8 sin `hasValidClaim` no verifica a nadie.
- **D-050 (Ciclo 8c · nonce firmado anti-replay):** cierra el bypass detectado en D-046: la firma EIP-712
  original seguía siendo válida tras la revocación y el titular podía reactivar el claim reintroduciéndola.
  `CLAIM_TYPEHASH` pasa a
  `keccak256("Claim(address walletOwner,uint256 topic,uint256 scheme,bytes32 dataHash,uint256 expiresAt,uint256 nonce)")`
  y `addClaim` construye el `structHash` con `claimNonce[topic][issuer]`. `revokeClaim` **incrementa** ese
  nonce (además de marcar `revoked = true`), de modo que toda firma anterior a la revocación deja de
  verificar; reactivar exige una **firma nueva** del issuer con el nonce incrementado. El alta/renovación
  **no** incrementa el nonce: D-018 (sobrescritura idempotente con firma válida) queda intacto.
- **D-051 (Ciclo 8c · layout y ABI del nonce):** el nonce vive en un mapping aparte
  `mapping(uint256 => mapping(address => uint256)) public claimNonce` (por par `(topic, issuer)`), **no** en
  el struct `Claim`: `getClaim` sigue devolviendo **8** salidas y el struct no gana campos. La vista
  `claimNonce(uint256,address)` (`0x8a2eff53`) es aditiva y la necesitan los clientes que firman.
- **D-052 (Ciclo 8c · compatibilidad de los helpers de test):** `SigUtils.signClaim` gana el parámetro
  `nonce` al final y conserva un **overload sin `nonce` que firma con `0`**, para no romper las llamadas
  existentes; igual patrón en `claimDigest`/`claimStructHash`. La suite `RF013_ClaimLifecycle.t.sol` firma
  con el nonce vigente leído de `claimNonce` y añade 5 tests del cierre (replay, incremento, reactivación,
  idempotencia D-018 y digest). Ningún test se borra ni se debilita.
- **D-053 (Ciclo 8b · toolchain — decisión del usuario):** se **mantiene `solc 0.8.20`** y el **digest EIP-712
  propio** en `IdentityCloneable` (revisado y cubierto por tests de binding de `chainId`, `verifyingContract`
  y `nonce`, con `ECDSA` de OpenZeppelin para la recuperación y la maleabilidad). Motivo: cero riesgo de
  toolchain y baseline de gas estable antes del despliegue; `EIP712Upgradeable` de OZ 5.5.0 exige `^0.8.24`.
  **Tarea registrada para el ciclo del área web:** subir `solc` (≥ 0.8.24/0.8.26, con `evm_version` explícito
  para Besu) y adoptar `EIP712Upgradeable`, que además expone `eip712Domain()` (EIP-5267) para que los clientes
  construyan el digest sin hardcodear el dominio; se re-baselinizará `.gas-snapshot` en ese momento.
- **D-054 (Ciclo 9 · firma con mínima exposición de la clave):** el despliegue firma con
  `forge script --keystore <keystore_cifrado_efimero> --password-file <fichero>`; el keystore v3 se construye
  con `eth_keyfile` (Python) leyendo la clave de una **variable de entorno del proceso hijo** (nunca por
  `argv`) y el fichero resultante queda en modo **600** dentro de un directorio temporal **700**, borrado por
  `trap` al terminar. Se descarta `--private-key` (expondría la clave en `argv`/`ps`) y el `--account` de
  Foundry (persistiría el keystore en `~/.foundry/keystores`, incompatible con "solo efímero"). Comprobado:
  la clave no aparece en `ps` durante `forge script`.
- **D-055 (Ciclo 9 · validación de red y fuentes de clave):** `sc/script/deploy.sh` exige `RPC_URL` y, si se
  declara `CHAIN_ID`, **aborta antes del broadcast** cuando `cast chain-id` no coincide (D-040/H-26); sin
  `CHAIN_ID` adopta el real de la red. Fuentes de clave, en orden: `DS_DEPLOYER_PRIVATE_KEY` →
  `DEPLOYER_PRIVATE_KEY` → `DS_PRIVATE_KEY` → `DS_ADMIN_PRIVATE_KEY` → `ADMIN_PRIVATE_KEY` → `PRIVATE_KEY`,
  con override `DEPLOYER_KEY_VAR` y soporte de `USE_SECRET_MANAGER=1` (gcloud, secreto `DS_PRIVATE_KEY` o
  `DS_DEPLOYER_SECRET`). Nunca se lee ningún archivo de claves en disco.
- **D-056 (Ciclo 9 · verificación post-deploy y artefacto JSON):** el éxito no se decide con `grep` de logs
  (H-31) sino por el **código de salida** de `forge script` y por **verificación on-chain**: `cast code != 0x`
  en cada dirección y `cast call` de `name()`, `identityRegistry()`, `trustedIssuersRegistry()`,
  `claimTopicsRegistry()`, `aggregator.getModuleCount() == 1`, `isModuleActiveForToken == true` y
  `module.tokenContract() == token`. Se persiste `sc/deployments/<chainId>-<timestamp>.json` con `chainId`,
  bloque, `timestamp`, `deployer`, direcciones (`contracts`), `token`, `compliance`, `paths`, `verifiedContracts`
  y los **ABIs relevantes** (`forge inspect … abi --json`). El JSON es **trazable** (no se añade a `.gitignore`)
  y se comprueba que no contiene material sensible.
- **D-057 (Ciclo 9 · manejo de errores y wrapper Besu):** `deploy.sh` **no** usa `set -e` (H-31): cada paso
  comprueba su propio resultado y aborta con un mensaje claro que nunca incluye la clave. El antiguo
  `deploy-besu.sh` se conserva como **wrapper de compatibilidad** hacia `sc/script/deploy.sh` (RPC de Besu por
  defecto y autodetección de `chain-id`), sin leer archivos de claves; el destino canónico es el Anvil de GCP
  (D-040). La clave privada por defecto de Anvil que figuraba en `REFERENCIA_TECNICA.md` se **redacta**.
- **D-058 (Ciclo 10 · documentación veraz):** toda cifra publicada en la documentación se sustituye por la
  **medida** y se enlaza a su artefacto (`RepoTecnico/metricas_ejecucion.md`, shards de gas, `sc/abis/`).
  Quedan **prohibidas** las referencias a archivos/contratos inexistentes (`Token.sol`, `Identity.sol`,
  `TOKEN_CLONE_FACTORY.md`, `COMPLIANCE_AGGREGATOR_FINAL.md`, `COMPLIANCE_AGGREGATOR_V2.md`,
  `DeployIdentityRegistry.s.sol`) y las afirmaciones "production-ready"/"ERC-3643 compliant" sin declaración
  verificable. Cifras canónicas: **420 tests / 420 pasan** (24 suites), cobertura `src/` **97,01 % líneas**
  (mínimo por contrato 92,31 %; D-017/D-042), ahorro de gas **45–59 %** con comparación equivalente.
- **D-059 (Ciclo 10 · `SECURITY.md`):** el documento de seguridad es **vivo** y refleja el estado de los 34
  hallazgos de la auditoría V1 (corregido + ciclo, parcial o backlog), los hallazgos base HB-01..HB-12, los
  controles implementados y los **riesgos residuales**; cada mitigación cita al menos una función `test_*` o un
  `ci_check_*` existente. Enlaza a `INFORME_OPTIMIZACION_V1.md` y a `CHANGELOG_ABIS.md`.
- **D-060 (Ciclo 10 · control de deriva de ABIs):** la línea base de ABIs se versiona en
  `sc/abis/<Contrato>.json` (estado actual: **15 contratos**). `sc/script/ci/abi_diff.sh` compara
  `forge inspect <Contrato> abi --json` contra esa línea base y **falla** si hay selectores o firmas nuevos,
  modificados o eliminados que no estén declarados en `CHANGELOG_ABIS.md`. Actualizar la línea base exige
  `script/ci/abi_diff.sh --update` **y** la entrada correspondiente en `CHANGELOG_ABIS.md`.
- **D-061 (Ciclo 10 · gate de documentación):** `sc/script/ci/check_docs.sh` falla si algún documento raíz
  referencia archivos inexistentes, si falta `SECURITY.md` o `CHANGELOG_ABIS.md`, si aparece una afirmación
  prohibida sin matizar, si `SECURITY.md` no cubre HB-01..HB-12 o si hay marcadores sin sustituir. Los
  documentos de `RepoTecnico/` quedan fuera del escaneo por ser el registro de auditoría (citan los textos
  prohibidos como hallazgo histórico).
- **D-062 (Ciclo 11 · pipeline de CI):** el pipeline vive en `rwa-sc/.gitlab-ci.yml` y se dispara en
  *merge requests* y en la rama `rwa-sc-DSH-GCP` (`workflow.rules`). Etapas en orden:
  `validate` (submódulos pinneados, B-5) → `build` (`forge build`) → `fmt` (`forge fmt --check`) →
  `test` (gate RNF-003) → `coverage` (gate RNF-002/D-042) → `gas` (`forge snapshot --check --tolerance 5`,
  gate RNF-001/D-039) → `ci-checks` (RF-002 + RF-006). Imagen **fijada**
  `ghcr.io/foundry-rs/foundry:v1.8.3` (tag verificado en `ghcr.io`); variables `FOUNDRY_PROFILE=default` y
  `SOLC_VERSION=0.8.20` coherentes con `foundry.toml`; **sin secretos** (el pipeline no despliega). El pipeline
  **no se ha ejecutado en remoto** porque no se hace `push` sin orden explícita del usuario.
- **D-063 (Ciclo 11 · gate de cobertura por contrato, D-042):** `sc/script/ci/check_coverage.sh` parsea
  `forge coverage --report summary` y exige (a) el **agregado de líneas de `src/` ≥ umbral**, excluyendo
  `src/ICompliance.sol` y `src/IClaimTopicsRegistry.sol` (D-017), y (b) el **mínimo por contrato de líneas ≥
  umbral** (D-042), indicando el contrato y el porcentaje que fallan. Las **ramas** se publican pero **no
  bloquean** (hay contratos por debajo del 80 % de ramas por diseño, p. ej. `MaxBalanceCompliance` 66,67 %).
  El umbral se lee de una única variable (`COVERAGE_THRESHOLD`, y `COVERAGE_CONTRACT_THRESHOLD`, por defecto
  igual), cumpliendo el EARS `ci_check_RF009_umbral_configurable_centralizado`.
- **D-064 (Ciclo 11 · conteo real como artefacto):** el job `test` genera
  `sc/ci-artifacts/test-count.txt` con `forge test --list | grep -cE '^    test'` y el resumen de la
  ejecución, y `coverage` publica `sc/lcov.info`; queda **prohibido** fijar el número de tests a mano en el
  pipeline o en los documentos (coherente con D-058).
- **D-065 (Ciclo 11 · `jq` en el runner de CI):** la imagen oficial de Foundry es Ubuntu **no-root** y **no
  incluye `jq`**, que `sc/script/ci/abi_diff.sh` exige. El job `ci-checks` lo instala si el runner permite
  `root` (`user = "root"` en el ejecutor docker) o si el ejecutor es **shell** (donde `forge` y `jq` ya están,
  precondición de CU-11); si el runner es docker no-root, hay que usar una imagen propia
  `FROM ghcr.io/foundry-rs/foundry:v1.8.3` con `jq` instalado.
- **D-066 (Fase 4 · invariantes con estado):** se incorporan 4 suites de invariantes con handlers acotados
  (`sc/test/invariant/`) y la sección `[invariant]` de `sc/foundry.toml` con `runs = 64`, `depth = 64` y
  `fail_on_revert = false`. Justificación: `64 * 64 = 4096` llamadas al handler por contrato cubren las
  acciones acotadas en **13,2 s** (16 384 llamadas en total), mientras que `128/128` tarda **313 s** y es
  inviable para el pipeline; `fail_on_revert = false` se compensa con handlers que **nunca revierten**
  (encapsulan cada llamada en bajo nivel) y con todos los `assert` fuera de los handlers. Los invariantes
  se declaran en `RepoTecnico/pruebas/pruebas_invariantes.md` y el detalle de tiempos/cobertura en
  `RepoTecnico/metricas_ejecucion.md` §21.
- **D-067 (Fase 4 · conteo de invariantes como artefacto):** el artefacto `sc/ci-artifacts/test-count.txt`
  (D-064) añade `invariant_functions_listed` (`forge test --list | grep -cE '^    invariant_'`) y mantiene
  `tests_listed` sobre las funciones `test*`; así el conteo real (357 `test*` + 19 `invariant_*` = 376
  entradas en `.gas-snapshot`) queda publicado sin cambiar el significado de `tests_listed`.
- **D-068 (Fase 4 · presupuesto de invariantes en la etapa de cobertura):** el job `coverage` ejecuta los
  invariantes con `FOUNDRY_INVARIANT_RUNS=1` y `FOUNDRY_INVARIANT_DEPTH=1` (65 s frente a 204 s con 64/64)
  porque la cobertura de `src/` la fijan las suites unitarias y **no baja** (97,12 % / 92,31 % idénticos en
  ambos presupuestos). `run_local_ci.sh` aplica el mismo *override* para que el ensayo local refleje el
  pipeline.
- **D-069 (Fase 4 · determinismo del fuzzer de invariantes):** Foundry v1.8.3 no expone semilla de
  invariantes (`forge config` no lista `[invariant] seed`), por lo que las secuencias exploradas varían
  entre ejecuciones y el tiempo de `forge test` oscila entre 15,5 s y 80,7 s. No afecta al gate de gas
  (RNF-001/D-039) porque las entradas de invariantes del `.gas-snapshot` registran `(runs, calls, reverts)`,
  no gas; se acepta como limitación conocida de reproducibilidad del *conjunto de entradas*.
- **D-070 (Fase 4 · storage muerto de `TokenCloneable`):** se eliminan `_tokenName` y `_tokenSymbol` del
  contrato clonable (RF-005): `name()`/`symbol()` los sirve `ERC20Upgradeable` desde su propio storage, así que
  mantenerlos era storage muerto escrito en `initialize` y nunca leído. Se conserva `_tokenDecimals`, que sí
  usa `decimals()`. La prueba `test_RF005_no_storage_muerto_tokenName` inspecciona el `storageLayout` del
  artefacto compilado (control positivo: `identityRegistry`/`_tokenDecimals`; negativo: los dos slots muertos).
  No cambia la ABI.
- **D-071 (Fase 4 · gate de secretos de RF-010):** se crea `sc/script/ci/check_secrets.sh` y se integra en el
  job `ci-checks` y en `run_local_ci.sh`. Falla ante claves privadas de 64 hex en scripts/configuración, ante
  asignaciones de secreto (`private_key`/`mnemonic`/`secret`) con valor de 64 hex, ante tokens de proveedor
  (`glpat-`, `ghp_`, `AKIA…`), ante el uso de `keys.json` o `--private-key` en scripts, y exige que `.env` y
  `.env.*` estén en `.gitignore`. Cierra el único criterio de CU-13 (`ci_check_RF010_secret_scan_sin_hallazgos`)
  que no tenía ningún soporte.
- **D-072 (Fase 4 · mitigación con test de RF-006):** `sc/script/ci/check_docs.sh` se amplía para exigir que
  cada `test_*` citado en `SECURITY.md` exista realmente en `sc/test/**` y cada `ci_check_*` exista como gate en
  `sc/script/ci/**` (o en `.gitlab-ci.yml`). Los prefijos terminados en `_` (p. ej. `test_RF004_*`) se aceptan
  si existe al menos un miembro de la familia. Cierra `ci_check_RF006_mitigacion_con_test`.
- **D-073 (Fase 4 · cierre de los huecos de la matriz):** se añaden las 7 pruebas que cierran los criterios
  FALTA/PARCIAL priorizados de `RepoTecnico/pruebas/matriz_criterios.md` §3 y se regenera `.gas-snapshot`. La
  línea base de ABIs no se toca porque el cambio de storage no altera la ABI.
- **D-074 (Fase 4 · alineación de `casos_uso.md` a v1.4):** se sustituyen todos los rótulos «pendiente
  (RF-00x)» por «IMPLEMENTADO (Ciclo N)» en los requisitos ya materializados, se reemplazan los 67 nombres de
  test obsoletos (más los 2 citados en prosa) por los reales de la matriz §4.1 y se reescriben los dos criterios
  derogados que describían el comportamiento fail-open (`isVerified` sin topics y `canTransfer` sin módulos) a
  su forma fail-closed vigente (RF-011/RF-012). El encabezado remite a la matriz de criterios.

### Bloque 6b — Cierre de la Fase 4: corrección de la auditoría adversarial final (AF-01..AF-15)

- **D-075 (AF-01 · módulo de compliance mal configurado):** `TokenCloneable.addComplianceModule` y
  `ComplianceAggregator.addModule` exigen, además de ERC-165, que un módulo de un solo token esté **vinculado
  al token destinatario**: `staticcall` a `tokenContract()` y exigencia de que devuelva `address(this)` (o el
  `token` del alta). Los módulos multi-token que **no** exponen `tokenContract()` (el `ComplianceAggregator`)
  quedan exentos. Además, `MaxBalanceCompliance.canTransfer`, `MaxHoldersCompliance.transferred` y
  `MaxHoldersCompliance.destroyed` sustituyen el `abi.decode` directo por lectura defensiva
  (`success && data.length >= 32`), degradando a `false`/sin cambios en vez de revertir con un `Panic` opaco.
  Cierra AF-01 (ALTA). Pruebas: `test/AuditoriaFinalAF.t.sol` (`test_AF01_*`), `test/MaxBalanceCompliance.t.sol`,
  `test/MaxHoldersCompliance.t.sol`.
- **D-076 (AF-02 · pausa y congelación en operaciones privilegiadas):** `mint` y `burn` pasan a exigir
  `whenNotPaused`; `mint` además rechaza destinos congelados (`require(!frozen[to])`). `forcedTransfer`
  **sigue operativo durante la pausa** como mecanismo de recuperación de emergencia (siempre con `AGENT_ROLE`,
  destino whitelisted y verificado), documentado en su NatSpec. Cierra AF-02 (MEDIA). Pruebas:
  `test/AuditoriaFinalAF.t.sol` (`test_AF02_*`).
- **D-077 (AF-13 · simetría del alta y la retirada por aggregator):** `removeModuleThroughAggregator` comprueba
  que el aggregator sea módulo registrado del token y que el módulo esté **activo para este token** antes de
  delegar la retirada, con mensajes explícitos. Cierra AF-13 (BAJA). Pruebas:
  `test/AuditoriaFinalAF.t.sol` (`test_AF13_*`) y `test/ComplianceAggregator.t.sol`.
- **D-078 (AF-07 · despliegue operable y smoke test):** `DeployFullStack.s.sol` configura
  `setMaxBurnPerTx`/`setMaxForcedPerTx` y autoriza el destino de la transferencia forzada; `deploy.sh` añade un
  **smoke test de operatividad** (`cast call` de topes, whitelist, módulo vinculado y registro de identidad)
  cotejando el artefacto con el estado on-chain, de modo que "verde" implica token **operable**, no solo
  desplegado. Cierra AF-07 (MEDIA).
- **D-079 (AF-08/AF-09 · scripts de ejemplo y aggregator):** `CompleteDeploymentExample.s.sol` usa firmas
  EIP-712 reales (`vm.sign` con la clave de issuer de prueba) en lugar de `hex""`, de modo que compila y se
  simula en local sin revertir; `DeployComplianceAggregator.s.sol` corrige los "Next Steps" para reflejar la
  API real (`addComplianceModule` + `addModuleThroughAggregator` + `removeModuleThroughAggregator`), eliminando
  la llamada inexistente `configureToken()`. Cierra AF-08 y AF-09 (MEDIA).
- **D-080 (AF-10 · runbook de migración, cierra D-019):** se crea `rwa-sc/RUNBOOK_MIGRACION.md` con el
  procedimiento de **redeploy limpio**: precondiciones, orden de despliegue, configuración obligatoria
  (registries, topes, whitelist, topics, issuers, vinculación de módulos), verificación con `cast`,
  actualización de consumidores y plan de rollback. Cierra AF-10 (MEDIA) y materializa el runbook exigido por
  D-019/RT-008.
- **D-081 (AF-06/AF-11/AF-15 · evidencia y deriva documental a cero):** se regenera
  `RepoTecnico/pruebas/matriz_criterios.md` como **v2 (vigente)**: 386 tests, 24 suites, 19 invariantes,
  **0 FALTA** (los 9 huecos cerrados); `SECURITY.md`, `.gitlab-ci.yml`, `README.md`, `entornos_globales.md` y
  `run_local_ci.sh` se alinean con el estado real de la CI (pipelines `2934202154` y `2934241152`, 7/7);
  se corrige el `CLAIM_TYPEHASH` de D-020 (incluye `nonce`, superado por D-050) y la referencia de línea de
  D-016. Cierra AF-06, AF-11 y AF-15 (MEDIA/BAJA).
- **D-082 (alcance del cierre · hallazgos diferidos):** quedan **fuera** de este cierre, por decisión propia y
  registro en backlog, los hallazgos **AF-03** (`_uri` fuera del digest EIP-712), **AF-04** (front-running de
  `createIdentityWithClaim`, ligado a D-027), **AF-05** (fail-closed del array de módulos del token), **AF-12**
  (`removeClaim`/nonce) y **AF-14** (`.md` en el gate de secretos). Ninguno es CRÍTICO; AF-03/AF-05 son
  cambios de comportamiento con impacto en consumidores off-chain y AF-04 depende de rediseñar el alta de
  identidad. Se reevalúan antes de producción (D-024). **Actualización (Fase 4, cierre definitivo):** por
  decisión explícita del usuario, **AF-03** y **AF-05** se incorporan al alcance y quedan cerrados en
  **D-083** y **D-084**; AF-04/AF-12/AF-14 siguen diferidos.
- **D-083 (AF-03 · firma del `uri` del claim · decisión del usuario):** el `CLAIM_TYPEHASH` de
  `IdentityCloneable` pasa a
  `keccak256("Claim(address walletOwner,uint256 topic,uint256 scheme,bytes32 dataHash,uint256 expiresAt,uint256 nonce,bytes32 uriHash)")`
  y el `structHash` incorpora `uriHash = keccak256(bytes(_uri))`. El issuer firma la referencia documental
  KYC/AML off-chain (H-11) y el titular **no** puede publicar otra distinta ni renovarla sin una firma nueva:
  una firma con un `uri` y un alta con otro revierten `"Signature signer mismatch"` (mismo criterio que
  `data`). `SigUtils` gana el parámetro `uri` en `signClaim`/`claimDigest`/`claimStructHash` y **conserva
  overloads sin `uri` que firman con `""`**, de modo que las llamadas históricas no cambian de semántica.
  Cambio **breaking off-chain crítico** documentado en `CHANGELOG_ABIS.md`; **no** cambia el ABI (`forge
  inspect abi` no expone el valor de la constante: el selector `CLAIM_TYPEHASH()` sigue siendo `0x6b0509b1`)
  y `sc/abis/` no se regenera (`abi_diff.sh` en verde). Pruebas: `test/IdentityCloneable.t.sol`
  (`test_AF03_addClaim_uri_alterado_revierte`, `test_AF03_addClaim_uri_correcto_ok`,
  `test_AF03_digest_cambia_con_el_uri`).
- **D-084 (AF-05 · token fail-closed sin módulos · decisión del usuario):** `TokenCloneable.canTransfer`
  devuelve **`false`** cuando `complianceModules.length == 0`, de modo que `transfer`/`transferFrom` (vía
  `_update`) revierten `"Transfer not compliant"`: un token sin política de compliance no permite
  transferencias. Antes el bucle vacío devolvía `true` ("0 módulos = permitir todo"), el mismo patrón que
  RF-012 declaró vulnerabilidad en el aggregator. `mint` **no cambia** (la emisión es una operación
  privilegiada del agente y ya respeta pausa/congelación por AF-02) y `forcedTransfer` sigue su ruta
  explícita. Sin cambio de ABI. Se documenta en el NatSpec, en `SECURITY.md` (nuevo invariante «sin módulos
  = sin transferencias») y en `RUNBOOK_MIGRACION.md`; `deploy.sh` verifica on-chain que el token tiene al
  menos un módulo (`complianceModules(0)`). Pruebas: `test/AuditoriaFinalAF.t.sol` (`test_AF05_*`) con el
  módulo permisivo de test `test/mocks/AllowAllCompliance.sol`.
- **D-085 (cierre definitivo de la Fase 4 y adaptación de suites):** se adaptan las suites que emitían URIs
  no cubiertos por la firma (`test/IdentityCloneable.t.sol`, `test/IdentityCloneFactory.t.sol`,
  `test/RF013_ClaimLifecycle.t.sol`) para que `SigUtils` firme exactamente el `uri` que se da de alta; **no
  se debilita, borra ni salta ningún test**. Estado final: `forge test` → **394/394** (24 suites, 19
  funciones `invariant_*`), `forge build` 0 errores, `forge fmt --check` limpio, los 5 gates de
  `ci-checks` + `run_local_ci.sh` en verde y `.gas-snapshot` regenerado. Cierra la Fase 4 (Pruebas).

## 7. Mapa RF → casos de uso (Fase 2)

Ver `casos_uso/casos_uso.md` (**v1.4, 17 casos de uso**, 92 criterios Gherkin + 50 EARS = 142), auditado,
corregido y alineado con `pruebas/matriz_criterios.md` (ver `casos_uso/AUDITORIA_CASOS_USO.md`) y con diagramas
en `casos_uso/diagramas_casos_uso.md` (v1.1).
- Cubiertos: RF-001..RF-006, RF-009, RF-010 y RNF-001..RNF-005.
- **Ampliación auditoría V1 (D-014):** RF-011 (fail-closed de `isVerified`) → **CU-15**; RF-012
  (`ComplianceAggregator` fail-closed y administración por token) → **CU-16**; RF-013 (vigencia y revocación de
  claims) → **CU-17**. Los tres están implementados y con etiqueta `IMPLEMENTADO (Ciclo N)` en los casos de uso.
- Sin cobertura por alcance (D-003): RF-007, RF-008, RNF-006.
- Datos reales de la suite (Fase 4, estado actual): **394 tests, 394 pasan, 0 fallan**, 24 suites (19 funciones
  `invariant_*`); cobertura `src/` 97,05 % de líneas (691/712; mínimo por contrato 92,31 % de líneas; D-017/D-042), con
  el gate `check_coverage.sh` en el pipeline. Ver `metricas_ejecucion.md` §21 y §22.
  (Histórico de la auditoría V1, 2026-10-03: 151 declarados, 93 pasan, 5 fallan, 53 no arrancan, coverage 42,86 %.)

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
| H-07 | Factories permissionless; EIP-1167 sin ruta de upgrade | **Corregido** | Allowlist `setAuthorizedCreator`/`onlyCreator` (3 factories) + redeploy limpio (D-019); `test_H07_*` (6) |
| H-08 | Claims sin vigencia ni revocación por el issuer | **Cubierto (implementado, Ciclo 8)** | RF-013 (D-014, D-045..D-047) |
| H-09 | Catálogo RNF incompleto (ISO 25010) | **Definido (R-1)** | `RepoTecnico/requerimientos_no_funcionales.md` §1 (RNF-101..109); pendiente fijar Slither |
| H-10 | Sin RNF de cumplimiento regulatorio (sanciones/PEP/AML) | **Definido (R-2)** | §2 (RNF-201..206); **pendiente aprobación legal** |
| H-11 | PII/KYC sin custodio, base legal, cifrado ni retención | **Parcial (R-3)** | §3 (RNF-301..306); cifrado en `@web`; pendiente DPIA/DPO |
| H-12 | Sin RNF de observabilidad ni indexación de eventos | **Definido (R-4)** | §4 (RNF-401..405); indexer pendiente |
| H-13 | Catálogo de claim topics divergente | **Corregido** | Catálogo canónico v1.0 (1/7/9) + gate `ci_check_H13_catalogo_topics_unico` |
| H-14 | `diccionario_datos.md` describe storage inexistente | **Corregido** | QW-6/H-14: sección on-chain contra `forge inspect storage-layout` |
| H-15 | Docs y contratos citados como existentes que no existen | **Cubierto** | RF-006 / D-058 (`script/ci/check_docs.sh`) |
| H-16 | "ERC-3643 compliant"/"production-ready" sin criterio | **Cubierto** | RF-006 / D-058 (declaración verificable en `SECURITY.md`); `LICENSE` en R-8 |
| H-17 | `addComplianceModule` no valida `ICompliance` (ERC-165) | **Cubierto** | RF-003 |
| H-18 | Reentrancia en callbacks / flag `bypassCompliance` | **Cubierto** | RF-002 |
| H-19 | Estado singleton cross-token en módulos de compliance | **Corregido** | `setTokenContract` bind-once + AF-01; `test_H19_*` (6) |
| H-20 | Arrays no acotados O(n) y vistas sin paginación | **Corregido** | Índices O(1) + 6 vistas paginadas; `test/H20_Escalabilidad.t.sol` (6) |
| H-21 | Sin indexación de eventos ni artefactos de despliegue | **Cubierto (parcial)** | Ciclo 9 persiste `sc/deployments/<chainId>-<timestamp>.json`; indexer en R-4 |
| H-22 | `ComplianceAggregator` fail-open y owner global | **Cubierto** | RF-012 (D-014) |
| H-23 | Rúbrica de evaluación no operacional | **Cubierto** | RF-006 / D-058 (rúbrica con comandos y umbrales en `EJERCICIOS_PRACTICOS.md`) |
| H-24 | `deploy-besu.sh` parcial (no despliega registries/token) | **Cubierto** | Ciclo 9 · RF-010 (`DeployFullStack.s.sol` + `deploy.sh`) |
| H-25 | Falta stakeholder regulador/supervisor y reporte | **Definido (R-2)** | §2 RNF-206; pendiente validación legal |
| H-26 | Sin operador de red Besu ni validación de `chainId` | **Cubierto** | Ciclo 9 · D-055 (`deploy.sh` aborta si `CHAIN_ID` no coincide) |
| H-27 | Sin soporte al inversor / recuperación auditable | **Parcial** | RF-004/AF-02 (recuperación auditable) + §6 (RNF-601..603) |
| H-28 | Clave privada en claro en `deploy-besu.sh` | **Cubierto** | RF-010, RNF-004 |
| H-29 | El deploy no instancia/activa módulos de compliance | **Cubierto (parcial)** | Ciclo 9 despliega y activa `MaxBalanceCompliance`; generalización en M-14 |
| H-30 | Sin backup/DR, RPO/RTO ni runbook de recuperación | **Parcial (R-5)** | §5 (RNF-501..505) + `RUNBOOK_MIGRACION.md`; pendiente ensayo |
| H-31 | Éxito del deploy decidido por `grep` de logs | **Cubierto** | Ciclo 9 · D-056 (verificación on-chain con `cast code`/`cast call`) |
| H-32 | Exactitud documental (`DEPENDENCIAS_CONTRATOS`, `metricas_ejecucion`) | **Corregido** | Import corregido + diccionario contra el storage real (H-14) + 0 referencias `.sol` rotas (H-32) |
| H-33 | Estado de fases/rama contradictorio entre docs | **Cubierto** | RF-006 / D-058 (`estado_proyecto.md` y `entornos_globales.md` alineados) |
| H-34 | Los cambios de `tokenContract` no emiten evento | **Corregido** | QW-8: evento `TokenContractSet` en los 3 módulos |

**Resumen (tras el cierre de deuda):** 23 hallazgos **cubiertos** (H-01, H-02, H-04, H-05, H-07, H-08, H-13, H-14, H-15, H-16, H-17, H-18, H-19, H-20, H-22, H-23, H-24, H-26, H-28, H-31, H-32, H-33, H-34),
11 **parciales o definidos** (H-03, H-06, H-09, H-10, H-11, H-12, H-21, H-25, H-27, H-29, H-30) y **0 en backlog** (los pendientes dependen de aprobación legal/dirección o de un componente off-chain).

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
- **D-086 (Fase 5 · decisión del usuario):** los **manuales quedan aplazados** ("sin manuales por los
  momentos"). El proceso de 5 fases se cierra con las Fases 1–4 completadas; la Fase 5 puede retomarse con
  `@manuales` (skill `equipo-manuales`), cuyos insumos ya existen: arquitectura y flujos
  (`documento_tecnico.md`), despliegue (`entornos_globales.md`, `RUNBOOK_MIGRACION.md`), datos
  (`diccionario_datos.md`, `diagrama_er.md`), seguridad (`SECURITY.md`) y métricas (`metricas_ejecucion.md`).
  Nota técnica: en este entorno no hay `mmdc`, ni PDF (Chromium sin librerías), ni `pandoc`; los gráficos
  deberían generarse como SVG escritos a mano y el PDF como HTML imprimible.
- **D-087 (Fase 5 · decisión del usuario):** se **omite definitivamente la Fase 5 (Manuales)** ("omite la
  fase 5"), que sustituye al aplazamiento de D-086. El proyecto cierra con las Fases 1 a 4 completadas;
  los insumos para una eventual generación futura quedan versionados en `RepoTecnico/`.
