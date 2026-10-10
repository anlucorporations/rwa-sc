# Auditoría adversarial — Documento Técnico RWA v1.0

| Campo | Valor |
|---|---|
| **Objeto auditado** | `RepoTecnico/documento_tecnico.md` v1.0 · 2026-10-03 (683 líneas) |
| **Tipo** | Auditoría técnica adversarial de coherencia, fidelidad al código, completitud, riesgos, Mermaid y utilidad para Fase 3 |
| **Auditor** | Auditor Técnico adversarial (rol independiente) |
| **Fecha** | 2026-10-03 |
| **Alcance verificado** | `RepoTecnico/` (8 artefactos) + código real `rwa-sc/sc/src/`, `test/`, `script/`, `deploy-besu.sh`, `foundry.toml`, `.gitmodules`, `.gitignore`, `git` |
| **Escritura** | Único archivo creado/modificado: este informe. El documento técnico no se ha editado. |
| **Convención de IDs** | Base `HB-01..HB-12`; auditoría V1 `H-01..H-34` marcados «(auditoría V1)». Hallazgos de este informe: `DT-01..DT-13`. |

---

## 1. Veredicto

**SÍ, apto para iniciar la Fase 3 — con condiciones.** El documento tiene la arquitectura as-is/to-be, la traza RF/RNF/CU y el veredicto correctamente anclados en el código y en las métricas reales; la mayoría de sus citas `ruta:línea` son exactas. Para arrancar RF-005/RF-001 sin retrabajo debe primero: (a) **cerrar el diseño EIP-712** (dominio y campos firmados, hoy sin `expiresAt` ni `name`/`version` concretos), (b) **corregir la atribución H-02→RF-004** (debe ser HB-02) y la aritmética 53/55 de tests, y (c) **registrar como decisión** la gobernanza/custodia de claves y el tope de `mint`, que hoy solo viven en el backlog. Sin (a), RF-001 y RF-013 no son implementables de forma no ambigua.

---

## 2. Metodología y qué se leyó/verificó

### 2.1 Artefactos leídos íntegramente

- `RepoTecnico/documento_tecnico.md` (683 líneas, objeto).
- `RepoTecnico/requerimientos.md` (257 líneas): RF-001..RF-013, RNF-001..RNF-006, RT-001..RT-008, HB-01..HB-12, §6 decisiones, §8 backlog, D-003..D-018.
- `RepoTecnico/INFORME_OPTIMIZACION_V1.md` (471 líneas): H-01..H-34, §6 RNF faltantes, §7 stakeholders, §8 plan, §9 B-1..B-8/C-1..C-11.
- `RepoTecnico/casos_uso/casos_uso.md` (1127 líneas): 17 CU, 8 actores, 142 criterios, matriz §3.
- `RepoTecnico/casos_uso/diagramas_casos_uso.md` (573 líneas): UML + 6 secuencias + matriz actores↔CU.
- `RepoTecnico/diccionario_datos.md` (290), `diagrama_er.md` (218), `entornos_globales.md` (113), `metricas_ejecucion.md` (101), `estado_proyecto.md`, `base_datos.sql`, `evidencias/README.md`, `evidencias/PoC_H01_H05.t.sol`, `evidencias/salida_poc.txt`, `evidencias/lint_forge.txt`.

### 2.2 Código real contrastado

- Los 15 contratos de `rwa-sc/sc/src/` y `src/compliance/` (lectura completa de `TokenCloneable.sol`, `IdentityCloneable.sol`, `ComplianceAggregator.sol`; grep de declaraciones y storage del resto).
- 8 suites de `rwa-sc/sc/test/` (recuento por función de test), 6 scripts de `rwa-sc/sc/script/`, `rwa-sc/deploy-besu.sh`, `rwa-sc/sc/foundry.toml`, `foundry.lock`, `.gitmodules` (raíz y `sc/`), `.gitignore`, estado `git` (HEAD y `git ls-files`).
- Grep dirigido de `ecrecover|EIP712|ECDSA|supportsInterface|IERC165|ReentrancyGuard|nonReentrant` en `src/`.

### 2.3 Verificaciones cuantitativas realizadas

- Recuento de funciones `test*` por suite: **30** en `Token.t.sol` y **25** en `ComplianceAggregator.t.sol` (total 55), frente al «53 (30 + 25)» del documento (DT-04).
- Reglas de `evidencias/lint_forge.txt`: 19 + 14 + 5 + 4 + 3 + 3 + 2 + 1 + 1 = **52** (coincide con el documento).
- Submódulos: raíz declara 3, `sc/.gitmodules` declara 1; `lib/` en `.gitignore:5`; `git ls-files` = solo `README.md`; HEAD `2a4a683` (coincide).
- Declaraciones de los 15 contratos: **las 15 líneas de la tabla §2.1 son exactas**.

### 2.4 Validación Mermaid

- 5 bloques `mermaid`, vallas balanceadas (104/149, 193/220, 224/266, 270/305, 505/516).
- Dentro de los bloques: **0** paréntesis, **0** `;`, **0** emojis.
- `alt/else/end` y `loop/end` balanceados; los `end` de los flowcharts corresponden a sus `subgraph`.
- **Sin defectos de sintaxis Mermaid** (ver falsos positivos, §7).

### 2.5 Muestra de citas comprobadas (≥ 10 exigidas; se comprobaron > 30)

Se detallan en §4. Todas las citas de la tabla de contratos §2.1, las de storage §2.3/§4.1, las de `isVerified`/`bypassCompliance`/`ComplianceAggregator` y las de métricas/entornos resultaron correctas salvo las 3 excepciones documentadas en DT-05 y DT-08.

---

## 3. Hallazgos por impacto

### 3.1 Alto

| ID | Sección del documento | Problema | Evidencia | Corrección propuesta |
|---|---|---|---|---|
| **DT-01** | §3.1 (tabla to-be, filas RF-001 y RF-013), §3.4, §5.2 (RF-001/RF-013) | El **diseño EIP-712 está incompleto**: no se fijan `name`/`version` del dominio y, sobre todo, **no se define si `expiresAt` (y `revoked`) forman parte del digest firmado**. CU-02 define `structHash = keccak256(abi.encode(CLAIM_TYPEHASH, walletOwner, topic, scheme, keccak256(data)))` (sin `expiresAt` ni `uri`), mientras CU-17 exige que `addClaim` persista `expiresAt` «parámetro o política del issuer». Si la vigencia no se firma, un relay/llamador puede alterarla; si se firma, la interfaz de `addClaim` (hoy 6 argumentos) debe cambiar. RF-001/RF-013 quedan no implementables sin decidir esto. | `documento_tecnico.md:179-180,277,304`; `casos_uso.md:201-206,997,1000`; `diccionario_datos.md:273,280-281`; `IdentityCloneable.sol:63-70` | Fijar `EIP712Domain(name, version, chainId, verifyingContract)` con valores concretos; declarar el `CLAIM_TYPEHASH` completo incluyendo `expiresAt` (y decidir `uri`/`nonce`); especificar la nueva firma de `addClaim` y actualizar `createIdentityWithClaim` + `CHANGELOG_ABIS`. Añadir que para clones EIP-1167 el `verifyingContract` es la **dirección del clon** (`address(this)`), no la implementación. |
| **DT-02** | §3.1 (fila «`TokenCloneable` — `burn`/`forcedTransfer`»), en contradicción con §5.2 | Atribuye **RF-004 a «H-02 (auditoría V1)»**, pero H-02 es «139 tests falsos»; el hallazgo correcto es **HB-02** («`burn()`/`forcedTransfer()` dan poderes absolutos a `AGENT_ROLE`»). El propio documento lo mapea bien en §5.2 (`HB-02 → RF-004`), lo que evidencia confusión de la convención HB/H. Un implementador puede perseguir la suite de tests en vez de los topes de quema. | `documento_tecnico.md:183` vs `documento_tecnico.md:420`; `requerimientos.md:25,55,57`; `INFORME_OPTIMIZACION_V1.md:106` (H-02) | Sustituir `H-02` por `HB-02` en la fila RF-004 de §3.1. Revisar todas las celdas «Hallazgo» de §3.1 contra `requerimientos.md:52-66`. |
| **DT-03** | §8.1 (R2, R6) y §8.2 (DF3-01..DF3-10) | El documento **no registra decisión alguna** sobre (a) **gobernanza y custodia de claves** (reparto de los 3 roles, multisig/timelock, custodio, rotación) ni sobre (b) el **tope de suministro de `mint`**; ambas son mitigaciones explícitas de H-06. B-4 exige que los tres roles no recaigan en una única cuenta «sin decisión documentada», pero no hay DF3 que la documente, y la recomendación de cap de `mint` (`INFORME_OPTIMIZACION_V1.md:218`) desaparece del plan RF-004/B-4. | `documento_tecnico.md:588,622,638-639`; `INFORME_OPTIMIZACION_V1.md:216-218,387,401`; `requerimientos.md:55,57`; `TokenCloneable.sol:176-190` (sin cap) | Añadir DF3 de gobernanza (opciones EOA documentada / roles separados / multisig+timelock) y DF3 de política de suministro (`maxSupply` administrable, inmutable o sin tope documentado), con su criterio de aceptación y test. |

### 3.2 Medio

| ID | Sección del documento | Problema | Evidencia | Corrección propuesta |
|---|---|---|---|---|
| **DT-04** | §1.4 (punto 3) y §7.1 (tabla de métricas) | **Aritmética inconsistente del recuento de tests muertos**: el documento escribe «53 (`Token.t.sol` 30 + `ComplianceAggregator.t.sol` 25)», pero 30 + 25 = **55**. El informe V1 ya registró la discrepancia (53 según `metricas_ejecucion.md`, 55 por recuento directo) y priorizó **55**; el documento copia solo el 53 y elimina la salvedad, y 93 + 5 + 53 = 151 mientras el recuento directo da 153. Afecta al baseline de RNF-003. | `documento_tecnico.md:66-67,533-537`; `metricas_ejecucion.md:31-35`; `INFORME_OPTIMIZACION_V1.md:59,74,174`; recuento real en `test/Token.t.sol` (30) y `test/ComplianceAggregator.t.sol` (25) | Publicar ambas cifras con su origen como hace el informe V1, o re-ejecutar la medición; fijar explícitamente el baseline de RNF-003. Alinear con D-015. |
| **DT-05** | §4.2 y §8.2 (DF3-10) | La decisión de destino de datos off-chain se etiqueta **«Q6»**, pero en `requerimientos.md:102` **Q6 = cadena destino Besu CodeCrypto + CI GitLab (D-008), ya resuelta**; la migración de BD no es Q6. Además DF3-10 cita `requerimientos.md:236`, que es la fila **R-7 (gobernanza)**, no la decisión de datos. | `documento_tecnico.md:334,607`; `requerimientos.md:102,236`; `base_datos.sql:3,10`; `estado_proyecto.md:32` | Corregir la referencia: la BD oficial es MongoDB (D-002, `estado_proyecto.md:32`); la eventual migración no tiene ID Q en `requerimientos.md`. Retirar `requerimientos.md:236` o sustituirla por la cita real. |
| **DT-06** | §2.3 (arrays O(n)) | La lista de arrays no acotados (`registeredAddresses`, `trustedIssuersList`, `claimTopics`, `tokens`) **no coincide con la evidencia de H-20**, que cita `TokenCloneFactory.sol:20-23` y no cita `tokens`; además omite los arrays de las factories (`adminTokens`/`allTokens` y `userIdentities`/`allIdentities`), también lineales y sin paginación. Mezcla la fuente del diccionario (§4) con la del informe (H-20). | `documento_tecnico.md:168-169`; `INFORME_OPTIMIZACION_V1.md:129`; `diccionario_datos.md:241-243`; `TokenCloneFactory.sol:20,23`; `IdentityCloneFactory.sol:20,23` | Unificar la lista con la evidencia de H-20 e incluir expresamente los arrays de factories; o remitir a `diccionario_datos.md:241-243` sin reenumerar. |
| **DT-07** | §8.1 y §8.2 | El riesgo de **ausencia de auditoría externa** (H-16/R-9/M-8) no aparece en la tabla de riesgos §8.1 ni como DF3; queda solo como criterio C-11 y entrada de backlog, pese a que §9 condiciona la producción a superarla. Se subestima su carácter bloqueante. | `documento_tecnico.md:579-592,642,646`; `INFORME_OPTIMIZACION_V1.md:373-374,405,409`; `requerimientos.md:237-238` | Añadir la auditoría externa como riesgo explícito de R5/R6 y como decisión de alcance (¿entregable de Fase 3 o posterior?), con criterio de aceptación. |
| **DT-08** | §1.1 (línea 28) | Cita incorrecta: atribuye a **«RT-001»** la organización en dos zonas citando `requerimientos.md:15-18`; RT-001 es `requerimientos.md:83` (Solidity 0.8.20 / OZ 5.5.0). Las líneas 15-18 son §1 (dos zonas), no RT-001. | `documento_tecnico.md:28`; `requerimientos.md:13-18,83` | Sustituir por `requerimientos.md:13-18` (dos zonas) y, si se quiere citar RT-001, usar `requerimientos.md:83`. |
| **DT-09** | §2 (as-is) vs §6/§10 | La arquitectura as-is (§2.1-§2.2) **omite los componentes de despliegue y CI** (`deploy-besu.sh`, los 6 `.s.sol` de `script/`, `.gitlab-ci.yml`), que sí aparecen en §5.1, §6.5 y §10.2. Un lector de §2 no ve la capa de despliegue. | `documento_tecnico.md:75-149` vs `documento_tecnico.md:382,398,485-516,677-679` | Añadir un bloque «Tooling/despliegue» al diagrama as-is o declarar explícitamente que §2.1 cubre solo contratos de `src/`. |

### 3.3 Bajo

| ID | Sección del documento | Problema | Evidencia | Corrección propuesta |
|---|---|---|---|---|
| **DT-10** | §2.1 (tabla, fila `IdentityCloneable`) | La cita del constructor es `:42-43`; el bloque `constructor` real abarca 42-44 (la llave de cierre está en 44). Es un desfase trivial, no un error de contenido. | `documento_tecnico.md:83`; `IdentityCloneable.sol:42-44` | Ajustar a `:42-44` o citar solo `:42`. |
| **DT-11** | §5.1 (matriz componente→CU) | Celdas laxas: `TokenCloneable` aparece como implementador de CU-02/CU-03 (alta/rechazo de claims, que residen en `IdentityCloneable`), y `CI / foundry.toml` cubre CU-12/CU-13 (documentación/secretos). Diluye la utilidad de la matriz. | `documento_tecnico.md:365-382`; `casos_uso.md:194-291,746-838` | Ajustar leyenda o celdas para que «X» signifique intervención real del componente; mover CU-02/CU-03 al `IdentityCloneable` (ya presente). |
| **DT-12** | §9 y §5.2 | **Duplicidad con riesgo de deriva**: §9 reproduce el texto de B-1..B-8/C-1..C-11 (fuente `INFORME_OPTIMIZACION_V1.md:378-409`) y §5.2 reproduce el mapa RF→CU de `casos_uso.md`. El propio documento declara que no debe duplicar (regla H-14/H-13). Cualquier cambio en las fuentes dejará este documento desincronizado. | `documento_tecnico.md:352-354,611-642`; `INFORME_OPTIMIZACION_V1.md:384-405` | Convertir §9 y §5.2 en tablas-resumen con enlace/commit de la fuente (o generar por script), no en copia literal. |

---

## 4. Citas al código verificadas

### 4.1 Verificadas correctas

| Cita del documento | Contenido real | Veredicto |
|---|---|---|
| `rwa-sc/sc/src/TokenCloneable.sol:18` | `contract TokenCloneable is ERC20Upgradeable, AccessControlUpgradeable, PausableUpgradeable` | OK |
| `rwa-sc/sc/src/TokenCloneable.sol:47` | `bool private bypassCompliance;` | OK |
| `rwa-sc/sc/src/TokenCloneable.sol:212,218,317,324` | activa/desactiva el flag y lo consulta en `_update` | OK |
| `rwa-sc/sc/src/TokenCloneable.sol:245-247` | `isVerified` devuelve `true` sin `claimTopicsRegistry` (fail-open) | OK |
| `rwa-sc/sc/src/TokenCloneable.sol:23-25,28,31-32,44` | FKs a registries, `complianceModules`, `_tokenName`/`_tokenSymbol`, `frozen` | OK |
| `rwa-sc/sc/src/IdentityCloneable.sol:11` | `contract IdentityCloneable is OwnableUpgradeable` | OK |
| `rwa-sc/sc/src/IdentityCloneable.sol:13,16,19,21-28` | `claims`, `topicIssuers`, `topicIssuerExists`, struct `Claim` | OK |
| `rwa-sc/sc/src/IdentityCloneable.sol:63-98` | `addClaim` `onlyOwner`, sin verificación de firma | OK |
| `rwa-sc/sc/src/IdentityCloneable.sol:105-123` | `removeClaim` `onlyOwner` del titular, swap-and-pop | OK |
| `rwa-sc/sc/src/compliance/ComplianceAggregator.sol:23` | `contract ComplianceAggregator is ICompliance, Ownable` | OK |
| `rwa-sc/sc/src/compliance/ComplianceAggregator.sol:26,29,32,35,38` | `tokenModules`, `moduleIndex`, `isModuleActive`, `tokens`, `_isTokenRegistered` | OK |
| `rwa-sc/sc/src/compliance/ComplianceAggregator.sol:50-53` | modifier `onlyOwnerOrToken` con literal `"Only owner or token can call"` | OK |
| `rwa-sc/sc/src/compliance/ComplianceAggregator.sol:61,87` | `addModule` / `removeModule` | OK |
| `rwa-sc/sc/src/compliance/ComplianceAggregator.sol:115-135,123-125` | `canTransfer` fail-open con cero módulos | OK |
| `rwa-sc/sc/src/compliance/ComplianceAggregator.sol:242-244` | vista `isTokenRegistered` | OK |
| `rwa-sc/sc/src/ICompliance.sol:8` | `interface ICompliance {` (sin `IERC165`) | OK |
| `rwa-sc/sc/src/ClaimTopicsRegistry.sol:16` | `contract ClaimTopicsRegistry is Ownable, IClaimTopicsRegistry` | OK |
| `rwa-sc/sc/src/ClaimTopicsRegistryCloneable.sol:12` | `contract ClaimTopicsRegistryCloneable is OwnableUpgradeable, IClaimTopicsRegistry` | OK |
| `rwa-sc/sc/src/TokenCloneFactory.sol:13` | `contract TokenCloneFactory is Ownable` | OK |
| `rwa-sc/sc/src/IdentityRegistry.sol:12` | `contract IdentityRegistry is Ownable` | OK |
| `rwa-sc/sc/src/TrustedIssuersRegistry.sol:11` | `contract TrustedIssuersRegistry is Ownable` | OK |
| `rwa-sc/sc/src/compliance/MaxBalanceCompliance.sol:12`, `MaxHoldersCompliance.sol:12`, `TransferLockCompliance.sol:12` | declaraciones de los 3 módulos | OK |
| `deploy-besu.sh:14,37` | `KEYS_FILE="$HOME/.foundry/keys.json"` y extracción de `private_key` | OK |
| `metricas_ejecucion.md:75` y `:39-49` | 1,56 % del aggregator; suites muertas | OK |
| `INFORME_OPTIMIZACION_V1.md:150,194,355,378-409` | recuento de severidades, `foundry.toml`, CI, criterios | OK |
| `entornos_globales.md:43,101,105` | `chainId` pendiente, CI inexistente, rama de trabajo | OK |
| `casos_uso.md:703,750,947,1061` | estados de CU-11/CU-12, paso de CU-16 y fila RF-001 | OK |

**Total comprobado: 27 citas/entradas correctas** (además de las 15 líneas de declaración de la tabla §2.1).

### 4.2 Citas incorrectas o desalineadas

| Cita del documento | Valor/cita real | Problema |
|---|---|---|
| `documento_tecnico.md:183` → «RF-004 … H-02 (auditoría V1)» | El hallazgo es **HB-02** (`requerimientos.md:25,55`); H-02 es el de los tests (DT-02) | ID de hallazgo equivocado |
| `documento_tecnico.md:334,607` → `requerimientos.md:236` | Línea 236 = **R-7 gobernanza**; la decisión de BD no está en `requerimientos.md` (D-002 en `estado_proyecto.md:32`) | Cita fuera de contexto (DT-05) |
| `documento_tecnico.md:28` → «(RT-001, `requerimientos.md:15-18`)» | Líneas 15-18 = §1 dos zonas; **RT-001 = línea 83** | Atribución incorrecta (DT-08) |
| `documento_tecnico.md:83` → `IdentityCloneable.sol:42-43` | Bloque `constructor` real 42-44 | Desfase trivial (DT-10) |

---

## 5. Vacíos técnicos y decisiones que el documento NO registra

1. **EIP-712: parámetros de dominio y campos firmados** (DT-01). Faltan `name`, `version` y la decisión de incluir `expiresAt`/`revoked`/`uri`/`nonce` en el `CLAIM_TYPEHASH`; falta fijar que, en clones EIP-1167, `verifyingContract` es la dirección del clon.
2. **Nueva firma de `addClaim`** al incorporar `expiresAt` (¿7 argumentos?) y su efecto en `createIdentityWithClaim`, en los PoC y en el `CHANGELOG_ABIS` para `rwa-web`. No está registrado.
3. **Modelo operativo de revocación**: quién custodia la clave del issuer, cómo paga el gas, si `revokeClaim` es por `(identidad, topic, issuer)` y si se admite revocación masiva/por lista. CU-17 lo deja como mensaje propuesto, sin dueño operativo.
4. **Gobernanza y custodia de claves** (DT-03): reparto de `DEFAULT_ADMIN_ROLE`/`AGENT_ROLE`/`COMPLIANCE_ROLE`, `Ownable2Step`, multisig/timelock y rotación.
5. **Política de suministro de `mint`** (DT-03): cap, valor, quién lo administra.
6. **Ubicación del guard de reentrancia**: el documento pide `nonReentrant` en `transfer`/`forcedTransfer`/`mint`/`burn`, pero `TokenCloneable` no sobrescribe `transfer`/`transferFrom` (solo `_update`); falta decidir si se sobrescriben o si el guard va en `_update`/entradas del aggregator, y su compatibilidad con `initializer`/storage layout.
7. **Tratamiento de tokens ya desplegados** para RF-011/RF-012 (DF3-03 está registrado pero sin opción recomendada ni criterio de aceptación).
8. **Reconciliación de métricas 53 vs 55** y su impacto en el baseline de RNF-003 (DT-04).
9. **Deprecación efectiva de `ClaimTopicsRegistry` (no clonable)** en producción: el documento lo sitúa como variante de tests/PoC, pero no declara si se retira o se mantiene.
10. **Riesgo de auditoría externa** sin tratamiento en §8 (DT-07).
11. **Modelo de firma off-chain/relay** (quién construye y envía `addClaim`; riesgo de que el relay altere campos no firmados), ligado a DT-01.

---

## 6. Preguntas para el usuario

> Máximo 2 bloques × 3 preguntas. Todas buscan desbloquear RF-001/RF-002/RF-004/RF-012 y el cierre de la Fase 3. La opción recomendada va marcada con **(Recomendada)**.

### Bloque 1 — Diseño de contratos (desbloquea RF-001, RF-002, RF-004)

**P1. Modelo de ciclo de vida y layout (DF3-01): ¿cómo se actualizará el contrato tras RF-002/RF-004 (que añaden storage)?**
- (a) **Redeploy limpio con runbook ensayado, manteniendo EIP-1167** — amparado en D-009/RT-008; no hay que tocar el patrón clone. **(Recomendada)**
- (b) Migrar a proxy actualizable **UUPS** con storage gaps (mayor complejidad y nueva superficie de seguridad).
- (c) Migrar a **Transparent/Beacon** con un contrato de administración de proxies.
- *Impacto:* determina si los cambios de storage de RF-002/RF-004 son libres y cómo se migran los clones actuales.

**P2. Firma EIP-712: ¿qué se firma exactamente y con qué dominio?**
- (a) **Dominio `("RWA-Identity", "1", chainId, cloneAddress)` y `CLAIM_TYPEHASH` que incluya `wallet, topic, scheme, keccak(data), expiresAt`** (la vigencia queda firmada por el issuer). **(Recomendada)**
- (b) Firmar solo `wallet, topic, scheme, keccak(data)` y tratar `expiresAt` como parámetro no firmado (más simple, permite manipulación de la vigencia por el relay).
- (c) Incluir además `uri` y un `nonce` anti-replay, con coste de gas adicional.
- *Impacto:* fija la interfaz de `addClaim` y el patrón de tests negativos de B-1.

**P3. Gobernanza y custodia de claves (H-06/R-7/B-4): ¿cómo se reparten los tres roles y quién custodia la clave de deploy?**
- (a) **Roles separados en cuentas distintas y propiedad del token a un multisig 2-de-3 + timelock; deploy con `DS_PRIVATE_KEY` y rotación documentada.** **(Recomendada)**
- (b) Mantener una EOA única documentada con límites y plan de rotación (se acepta el riesgo explícitamente).
- (c) Separar solo `AGENT_ROLE` ahora y posponer multisig/timelock a una fase posterior.
- *Impacto:* B-4 no puede cerrarse sin una decisión documentada; condiciona RF-002/RF-004/RF-010.

### Bloque 2 — Alcance y cierre (desbloquea RF-005, RF-012 y el veredicto)

**P4. Suministro de `mint` (H-06): ¿se añade tope?**
- (a) **`maxSupply` administrable por admin/compliance con evento y test de exceso.** **(Recomendada)**
- (b) Tope inmutable fijado en `initialize` (menos flexible, más predecible).
- (c) Sin tope; documentar el riesgo y dejarlo al backlog R-7.
- *Impacto:* completa la mitigación de H-06 y afecta a RF-004 y a B-4.

**P5. Registro del token en `ComplianceAggregator` (DF3-03/DF3-04): ¿mecanismo y alcance?**
- (a) **`canTransfer` fail-closed si el token no está registrado o no tiene módulos; el registro lo hace el propio token (`msg.sender`) al añadir su primer módulo; los tokens existentes se re-despliegan (D-009).** **(Recomendada)**
- (b) Añadir `registerToken()` retroactivo invocable por el owner/rol del token, con evento `TokenRegistered`.
- (c) Mantener el registro implícito actual y limitar el cambio a «cero módulos ⇒ denegar».
- *Impacto:* define la interfaz de RF-012 y el test de aislamiento cross-token (C-3).

**P6. Auditoría externa (R-9/C-11): ¿entra en el alcance de la Fase 3?**
- (a) **Sí: R-9 es entregable bloqueante antes de cualquier despliegue con activos reales; C-11 no bloquea el cierre de los RF pero sí la salida a producción.** **(Recomendada)**
- (b) No: R-9 queda en backlog y solo se contrata tras la Fase 4.
- (c) Sustituirla por una revisión interna (auto-auditoría) documentada en `SECURITY.md`.
- *Impacto:* fija la condición de salida y evita declarar «production-ready» sin auditoría (B-8).

---

## 7. Lo que está BIEN y falsos positivos descartados

### 7.1 Lo que está BIEN (no rehacer)

- **Fidelidad de la tabla de contratos §2.1:** las 15 líneas de declaración, los patrones (`Ownable`/`OwnableUpgradeable`/`ICompliance`) y las responsabilidades son exactos.
- **Storage §2.3/§4.1:** todas las citas de `claims`, `topicIssuers`, `topicIssuerExists`, `complianceModules`, `frozen`, `bypassCompliance`, `_tokenName`/`_tokenSymbol`, `tokenModules`, `moduleIndex`, `isModuleActive`, `tokens`, `_isTokenRegistered` son correctas.
- **Núcleo de seguridad bien identificado:** H-01 (`addClaim` sin `ecrecover`), H-05 (`isVerified` fail-open), H-08 (claims sin vigencia), H-17 (sin ERC-165), H-18 (sin guard) y H-22 (aggregator fail-open) están correctamente localizados y con PoC reproducible.
- **Veredicto honesto y anclado:** «NO para producción / SÍ para mejoras» coincide con `INFORME_OPTIMIZACION_V1.md:16-17`; las métricas (151/98/93/5, 42,86 %) y el HEAD `2a4a683` con solo `README.md` están verificados.
- **Trazabilidad completa:** los 13 RF, los 6 RNF, los 17 CU, los HB-01..HB-12 y los 34 H-01..H-34 aparecen clasificados; B-1..B-8 y C-1..C-11 están íntegros en §9.
- **Gestión de decisiones:** D-003/D-004/D-009/D-015/D-016/D-017/D-018 correctamente reflejadas; DF3-01..DF3-10 son las decisiones pendientes reales.
- **Determinismo de D-017 y D-018:** exclusión de interfaces en la cobertura y sobrescritura de claims con firma válida quedan sin ambigüedad.
- **Alcance disciplinado:** `rwa-web` fuera de alcance por D-003, sin contaminar la arquitectura de contratos.

### 7.2 Falsos positivos descartados (con motivo)

| Sospecha | Motivo del descarte |
|---|---|
| «Los bloques Mermaid tienen errores de sintaxis» | Verificado: 5 bloques con vallas balanceadas; sin `;`, sin paréntesis sin comillas, sin emojis internos; `alt/else/end` y `loop/end` cuadran. |
| «`deploy-besu.sh:14,37` está mal citado» | Verificado contra el archivo real: línea 14 = `KEYS_FILE="$HOME/.foundry/keys.json"`, línea 37 = extracción de `private_key`. Cita correcta. |
| «`TokenCloneable.sol:245-247` no es el fail-open» | Verificado: línea 245 `if (address(claimTopicsRegistry) == address(0))`, 246 `return true`. Cita correcta. |
| «Los 15 contratos / 8 suites / 6 scripts son una cifra inflada» | Verificado por `ls`: 11 `.sol` + 4 en `compliance/`, 8 `.t.sol`, 6 `.s.sol`. Correcto. |
| «El `interfaceId` de `ICompliance` cambiaría al añadir `IERC165` y RF-003 está mal» | Ya contemplado: Solidity excluye funciones heredadas del `interfaceId`; `casos_uso.md:355` lo documenta como FD-03. No es defecto del documento técnico. |
| «`lib/`, GCP, CI o `ComplianceAggregator` son componentes inventados» | Verificado: `sc/lib/` existe con los 3 submódulos; `ComplianceAggregator.sol` y los registries existen; CI se describe explícitamente como «a crear». |
| «La cita `:42-43` del constructor de `IdentityCloneable` invalida la tabla §2.1» | Desfase de una línea (el bloque termina en 44); contenido correcto. Se degrada a Bajo (DT-10). |
| «`H-02` en §8.1 (R3) está mal» | Allí H-02 (tests falsos) es correcto; el error está solo en §3.1 (DT-02). No generalizar. |

---

*Fin del informe — `AUDITORIA_DOCUMENTO_TECNICO.md` · auditoría adversarial del Documento Técnico v1.0.*
