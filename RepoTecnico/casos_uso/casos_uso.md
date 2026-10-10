# 🎭 Casos de Uso — Proyecto de Mejora RWA (`rwa-sc`)

> **Alcance:** solo `rwa-sc` (contratos Solidity 0.8.20 + tests Forge), decisión **D-003**.
> **Fuentes:** `RepoTecnico/requerimientos.md` (RF-001..RF-013, RNF-001..RNF-006, HB-01..HB-12, D-003..D-018),
> `RepoTecnico/INFORME_OPTIMIZACION_V1.md` (hallazgos de la auditoría V1: **H-01..H-34**, de los que aquí se citan
> **H-05**, **H-08** y **H-22**, siempre con el sufijo *«auditoría V1»*),
> `RepoTecnico/diccionario_datos.md` y el código real en `rwa-sc/sc/src/` + `rwa-sc/sc/src/compliance/`.
> **Dos numeraciones:** los 12 hallazgos del análisis base del Lead se citan como **`HB-01..HB-12`** (HB = «hallazgo
> base»); los 34 hallazgos de la auditoría V1 conservan **`H-01..H-34`**. Cuando un `H-xx` pertenezca a la auditoría
> V1 se marca explícitamente como «H-xx (auditoría V1)»; sin esa marca, `HB-xx` es siempre el análisis base.
> **Regla de testabilidad:** todo criterio está anclado a una función de test Foundry (`test_*`) o a una
> inspección de estado on-chain (`forge inspect`, `cast call`). Los criterios de documentación/CI usan *checks*
> automáticos de pipeline (`ci_check_*`); no hay criterios manuales.
> **Convención de test:** los tests nuevos se nombran `test_<RF|RNF|H>_<caso>_<condición>`.
> **Taxonomía de criterios (M-02):** comportamiento funcional observable → **Gherkin** (Dado/Cuando/Entonces);
> restricción del sistema (invariante, cota, atomicidad, condición de entorno) → **EARS** (Mientras/Si/Cuando).
> **Etiquetas de estado (M-08):** cada caso y cada criterio indica `IMPLEMENTADO` o `A IMPLEMENTAR (RF-00x)`
> según el contraste con el código real; esto permite planificar la Fase 3 sin confundir especificación y realidad.

---

## Changelog

### v1.3 — 2026-10-03

Revisión de coherencia sobre v1.2 (a partir de las 9 inconsistencias detectadas por el auditor de diagramas).
Se corrigen las 9 y se alinea [`diagramas_casos_uso.md`](diagramas_casos_uso.md) con esta v1.3:

1. **§4 — conteo de casos de uso:** se confirma **17 casos de uso (CU-01..CU-17)**; se elimina cualquier resto de
   los «14 casos de uso» de v1.0.
2. **§4 — conteo de criterios:** recuento real sobre el archivo final = **92 Gherkin + 50 EARS = 142**
   (sustituye a los 77 + 41 = 118 de v1.1/v1.2, que a su vez venían de la reclasificación M-02 sobre los
   66 + 52 = 118 de v1.0); ver §4 para el método de conteo.
3. **§4 — decisiones:** **D-012** y **D-013** quedan **CERRADAS** (por D-016 y D-018); §4 ya no las presenta como
   abiertas ni bloqueantes de la Fase 3, en coherencia con §2.5 y el changelog v1.2.
4. **Matriz 3.3 — H-05 (auditoría V1):** el fail-open de `isVerified()` mapea a **CU-15 / RF-011** (no a CU-11);
   se revisan el resto de filas tras la ampliación a 17 CU sin más cruces.
5. **Matriz 3.3 y texto — H-08:** se desambiguan los dos hallazgos homónimos: **HB-08** (análisis base, duplicidad
   `web-registry-trusted2`, fuera de alcance) y **H-08 (auditoría V1)** (claims sin vigencia ni revocación,
   cubierto por **RF-013 / CU-17**).
6. **Matriz 3.3 — H-22 (auditoría V1):** se añade la fila que faltaba (aggregator fail-open, cubierto por
   **RF-012 / CU-16**).
7. **Mensajes de revert propuestos vs. reales:** `"Only token admin can call"` (RF-012) y
   `"Only issuer can revoke"` (RF-013) se marcan como **propuesta (no existe hoy; llegará con RF-012 / RF-013)**;
   se conserva la cita del mensaje vigente (`"Only owner or token can call"`, `ComplianceAggregator.sol:50-53`) y
   se explicita que `IdentityCloneable` **no tiene** `revokeClaim` ni campos `expiresAt`/`revoked`.
8. **CU-16, paso 1:** se elimina la referencia a `registerToken` (no existe en `ComplianceAggregator.sol`); el
   registro explícito del token queda como **mecanismo a definir en RF-012**, hoy solo existe el estado privado
   `_isTokenRegistered` (`ComplianceAggregator.sol:38`).
9. **Diagramas:** [`diagramas_casos_uso.md`](diagramas_casos_uso.md) se regenera y alinea con esta v1.3
   (versiones, conteos, mensajes propuestos, `registerToken` y convención de IDs **HB-xx** / **H-xx (auditoría V1)**).

### v1.2 — 2026-10-03

Ampliación aditiva sobre la auditoría V1 ([`INFORME_OPTIMIZACION_V1.md`](../INFORME_OPTIMIZACION_V1.md)) y
cierre de las dos decisiones que quedaban abiertas en v1.1:

- **3 casos de uso nuevos** (aditivos; no se elimina ningún CU de v1.1):
  - **CU-15 — Cerrar el fail-open de `isVerified()`** (RF-011 · H-05 auditoría V1): paso a fail-closed cuando
    `claimTopicsRegistry == address(0)` o no hay topics, incluido el token recién creado por factory.
  - **CU-16 — `ComplianceAggregator` fail-closed y administración acotada por token** (RF-012 · H-22 auditoría V1):
    cero módulos = denegar y solo el owner/rol del token administra sus módulos.
  - **CU-17 — Ciclo de vida del claim: vigencia y revocación por el issuer** (RF-013 · H-08 auditoría V1):
    `expiresAt`/`revoked` y `isVerified` rechazando claims vencidos o revocados.
- **Cierre de D-012** (decisión del usuario, **D-016**): se mantiene el chequeo de compliance en `mint()`
  (alternativa A, *compliant siempre*); la alternativa B (bypass del agente) queda **descartada**. Se retira el
  marcador de «decisión abierta» de CU-10 y sus criterios vigentes son los de la alternativa A.
- **Cierre de D-013** (decisión del usuario, registrada como **D-018**): al reintentar un claim para el mismo par
  `(topic, issuer)` con firma válida se **sobrescribe** el claim existente (permite renovar). Actualizado el flujo
  alternativo A3.6 de CU-03 y sus criterios.
- **Matriz de trazabilidad actualizada:** se añaden RF-011, RF-012 y RF-013 con sus CU nuevos (CU-15, CU-16, CU-17);
  se refleja el alcance de RNF-002 según **D-017** (cobertura sobre `src/` excluyendo `src/ICompliance.sol`,
  `src/IClaimTopicsRegistry.sol` y `test/`) y se depuran las filas de H-05/H-08/H-22 de la auditoría V1.
- **Conteo de criterios actualizado** sobre el archivo final (ver §4).

### v1.1 — 2026-10-03

Correcciones aplicadas sobre el informe de auditoría [`casos_uso/AUDITORIA_CASOS_USO.md`](AUDITORIA_CASOS_USO.md)
(17 hallazgos: A-01, A-02, M-01..M-08 y B-01..B-07; 8 descartados FD-01..FD-08):

- **A-01 (CU-05):** precondición y criterios separados en (a) verificable HOY y (b) tras implementar RF-003;
  consta explícitamente que RF-003 implica modificar `ICompliance.sol` y los 4 contratos de compliance. Se
  documenta FD-03: añadir `IERC165` no altera `type(ICompliance).interfaceId`.
- **A-02 (CU-10):** el criterio de `mint` se alinea con `TokenCloneable.sol:180-182` (sí llama `canTransfer` y
  revierte `"Mint not compliant"`). Se añade la **decisión abierta D-012 (propuesta)** con las dos alternativas
  *(cerrada después en v1.2 por **D-016**; ya no es una decisión pendiente)*.
- **M-01:** todos los mensajes de revert citados se sustituyen por los literales reales de `src/` (p. ej.
  `"Claim topic already exists"` / `"Claim topic does not exist"`).
- **M-02:** reclasificación Gherkin/EARS; los *happy-path* que estaban en EARS pasan a Gherkin.
- **M-03:** trazabilidad inversa depurada; cada RF/RNF/H de la matriz se apoya en al menos un criterio real.
- **M-04:** CU-02 paso 5 cita únicamente `TrustedIssuersRegistry.hasClaimTopic` (no `IdentityRegistry`).
- **M-05:** criterios ambiguos concretados con comando/artefacto y valor esperado (CU-08 gas, CU-12 ABIs, CU-13
  Secret Manager, CU-01 renuncia).
- **M-06:** deduplicación de criterios `forcedTransfer` entre CU-04 y CU-06 (se conservan en CU-04).
- **M-07:** corregida la descripción de `.gitmodules`: `rwa-sc/.gitmodules` (raíz) declara los 3 submódulos;
  `rwa-sc/sc/.gitmodules` declara solo `openzeppelin-contracts`.
- **M-08:** etiquetas `IMPLEMENTADO` / `A IMPLEMENTAR (RF-00x)` por caso y por criterio.
- **B-01..B-07:** `setClaimTopics` inexistente eliminado; D-007 mal citada reformulada (nace **D-013 propuesta**);
  `test_*` que era comando renombrado a `ci_check_*`; naming `test_RF005_createToken*`; guard `from == address(0)`
  marcado como cambio objetivo; baseline real de tests; `moduleIndex` privado eliminado de las aserciones.
- **Decisiones abiertas propuestas:** **D-012** (`mint` y compliance) y **D-013** (replay de claims) *(ambas
  cerradas en v1.2: **D-016** y **D-018**; a partir de v1.2 no queda ninguna decisión pendiente)*.

### v1.0 — 2026-10-03

Versión inicial auditada (14 CU, 66 Gherkin + 52 EARS, matriz de trazabilidad).

---

## 1. Actores

| # | Actor | Descripción | Roles on-chain que le corresponden |
|---|---|---|---|
| A1 | **Admin / Owner** | Gobierna el token y los registries. Configura registries, pausa, concede roles, define límites y whitelist. | `DEFAULT_ADMIN_ROLE` (`TokenCloneable`), `owner()` de `IdentityRegistry`, `TrustedIssuersRegistry`, `IdentityCloneFactory`, `ClaimTopicsRegistryCloneFactory`, `TokenCloneFactory` y `ComplianceAggregator` (patrón `Ownable`). |
| A2 | **Agente** | Operador de ciclo de vida: emite, quema, congela y ejecuta recuperaciones. | `AGENT_ROLE` (`mint`, `burn`, `forcedTransfer`, `freezeAccount`, `unfreezeAccount`). |
| A3 | **Compliance Officer** | Administra el cumplimiento: alta/baja de módulos, alta/baja vía aggregator, parámetros de reglas. | `COMPLIANCE_ROLE` (`addComplianceModule`, `removeComplianceModule`, `addModuleThroughAggregator`, `removeModuleThroughAggregator`) + `owner()` del módulo/aggregator concreto. |
| A4 | **Inversor / titular** | Wallet registrada con contrato `IdentityCloneable` propio; recibe, mantiene y transfiere tokens; solicita claims. | Propietario (`owner()`) de su `IdentityCloneable`; sujeto de `identityRegistry.registered[wallet]` y `isVerified(wallet)`. No tiene rol de gobernanza. |
| A5 | **Issuer confiable** | Emisor externo de claims (KYC=1, Accreditation=7, Jurisdiction=9) que firma con EIP-712. | `TrustedIssuersRegistry.trustedIssuers[issuer]` + `issuerClaimTopics[issuer][topic]`; recuperado por `ecrecover` en `addClaim`. |
| A6 | **Creador de token** | Lanza tokens nuevos (clones EIP-1167) y recibe los tres roles de gobernanza. | Invoca `TokenCloneFactory.createToken` / `createTokenWithRegistries`; pasa a ser `DEFAULT_ADMIN_ROLE` + `AGENT_ROLE` + `COMPLIANCE_ROLE` del clon. |
| A7 | **Desarrollador / CI** | Compila, prueba y mide cobertura; opera el pipeline GitLab y los scripts de despliegue. | Runner CI (sin clave en repo); firma transacciones de deploy vía `PRIVATE_KEY` inyectada por variable de entorno / Secret Manager. |
| A8 | **Auditor externo** | Verifica mitigaciones, trazabilidad y estado desplegado sin poder de mutación. | Solo lectura (`view`/`staticcall`), `cast call`, `forge inspect`, informe sobre `SECURITY.md`. |

> Nota de fidelidad al código: los *registries* (`IdentityRegistry`, `TrustedIssuersRegistry`) usan `Ownable`, **no**
> `AccessControl`; el token usa `AccessControlUpgradeable` con los tres roles. Los módulos de compliance y el
> `ComplianceAggregator` usan `Ownable`. El actor A1 acumula `owner()` + `DEFAULT_ADMIN_ROLE` únicamente cuando
> es la misma cuenta; el diseño no lo obliga.

---

## 2. Casos de uso

Formato por caso: Actor · Objetivo · **Estado** · Precondición · Flujo principal · Flujos alternativos ·
Postcondición · Cobertura (RF/RNF/H) · Criterios Gherkin (funcional) · Restricciones EARS (sistema).

---

### CU-01 — Administrar emisores confiables y sus topics

- **Actor:** A1 (Admin/Owner de `TrustedIssuersRegistry`).
- **Objetivo:** Alta, modificación y baja de emisores confiables, declarando exactamente qué topics puede emitir cada uno.
- **Estado:** **IMPLEMENTADO.** `TrustedIssuersRegistry.sol:32-113` implementa `addTrustedIssuer`/`updateIssuerClaimTopics`/`removeTrustedIssuer`/`hasClaimTopic` con los mensajes citados (verificado).
- **Precondición:** `TrustedIssuersRegistry` desplegado y `owner` = A1. Para la baja, el emisor existe.
- **Flujo principal:**
  1. A1 llama `addTrustedIssuer(issuer, claimTopics)` con `issuer != address(0)` y `claimTopics.length > 0`.
  2. El contrato marca `trustedIssuers[issuer] = true`, guarda `issuerClaimTopics[issuer] = claimTopics` e inserta en `trustedIssuersList`.
  3. Emite `TrustedIssuerAdded(issuer, claimTopics)`.
  4. A1 ajusta posteriormente con `updateIssuerClaimTopics(issuer, nuevosTopics)` (emite `ClaimTopicsUpdated`).
  5. A1 retira con `removeTrustedIssuer(issuer)`: borra flag y topics, y hace *swap-and-pop* en `trustedIssuersList`; emite `TrustedIssuerRemoved`.
- **Flujos alternativos:**
  - A1.1 `addTrustedIssuer` con `issuer == address(0)` → revierte `"Invalid issuer address"`.
  - A1.2 `addTrustedIssuer` repetido → revierte `"Issuer already trusted"`.
  - A1.3 `addTrustedIssuer` con array vacío → revierte `"Must specify at least one claim topic"` (criterio EARS).
  - A1.4 `removeTrustedIssuer` de no confiable → revierte `"Issuer not trusted"`.
  - A1.5 Cualquier llamada desde una cuenta distinta de `owner` → revierte por `onlyOwner`.
  - A1.6 `hasClaimTopic` para issuer confiable sin ese topic → devuelve `false` (no revierte).
- **Postcondición:** `trustedIssuers`, `issuerClaimTopics`, `trustedIssuersList` y `getTrustedIssuersCount()` coherentes; el estado es consumido por `isVerified` y por la verificación EIP-712 de `addClaim` (CU-02/CU-03).
- **Cobertura:** RF-001 (precondición de emisor autorizado) · HB-01.

**Criterios Gherkin**
1. `test_RF001_addTrustedIssuer_guarda_topics` — **IMPLEMENTADO**
   - **Dado** un `TrustedIssuersRegistry` con owner A1 y un issuer aún no confiable,
   - **Cuando** A1 llama `addTrustedIssuer(issuer, [1,7])`,
   - **Entonces** `isTrustedIssuer(issuer) == true`, `getIssuerClaimTopics(issuer)` es `[1,7]` y `getTrustedIssuersCount() == 1`.
2. `test_RF001_addTrustedIssuer_duplicado_revierte` — **IMPLEMENTADO**
   - **Dado** un issuer ya confiable,
   - **Cuando** A1 repite `addTrustedIssuer`,
   - **Entonces** la transacción revierte con `"Issuer already trusted"`.
3. `test_RF001_removeTrustedIssuer_swap_and_pop` — **IMPLEMENTADO**
   - **Dado** tres issuers confiables `[I1,I2,I3]`,
   - **Cuando** A1 llama `removeTrustedIssuer(I1)`,
   - **Entonces** `isTrustedIssuer(I1) == false`, `getTrustedIssuersCount() == 2` y no quedan huecos cero en `getTrustedIssuers()`.
4. `test_RF001_updateIssuerClaimTopics_actualiza` — **IMPLEMENTADO**
   - **Dado** issuer confiable con topics `[1]`,
   - **Cuando** A1 llama `updateIssuerClaimTopics(issuer, [7,9])`,
   - **Entonces** `hasClaimTopic(issuer,1) == false` y `hasClaimTopic(issuer,7) == true`.
5. `test_RF001_addTrustedIssuer_only_owner_revierte` — **IMPLEMENTADO**
   - **Dado** una cuenta sin `owner`,
   - **Cuando** intenta `addTrustedIssuer`,
   - **Entonces** revierte por `OwnableUnauthorizedAccount`.
6. `test_RF001_hasClaimTopic_issuer_confiable_topic_ausente_false` — **IMPLEMENTADO**
   - **Dado** un issuer confiable solo para el topic `[1]`,
   - **Cuando** se consulta `hasClaimTopic(issuer, 99)`,
   - **Entonces** devuelve `false` sin revertir (vista pura, `TrustedIssuersRegistry.sol:101-113`).
7. `test_RF001_registries_owner_tras_renuncia` — **IMPLEMENTADO**
   - **Dado** el owner de `TrustedIssuersRegistry` que ejecuta `renounceOwnership()`,
   - **Cuando** cualquier cuenta (incluido el antes-owner, con `vm.prank`) llama `addTrustedIssuer`, `removeTrustedIssuer` o `updateIssuerClaimTopics`,
   - **Entonces** cada llamada revierte con `OwnableUnauthorizedAccount` y el estado no cambia.

**Restricciones EARS**
- `test_RF001_addTrustedIssuer_topics_vacios_revierte` — **Si** el array `claimTopics` está vacío, entonces el sistema deberá revertir con `"Must specify at least one claim topic"` sin modificar `trustedIssuers`, `issuerClaimTopics` ni `trustedIssuersList` (caso A1.3).

---

### CU-02 — Verificar la firma EIP-712 del claim y añadirlo

- **Actor:** A4 (Inversor/titular, `owner` de su `IdentityCloneable`), con firma de A5.
- **Objetivo:** Añadir un claim KYC/acreditación a la identidad on-chain validando criptográficamente la firma **EIP-712** del issuer y su autorización de topic.
- **Estado:** **A IMPLEMENTAR (RF-001)** en la verificación de firma. HOY `IdentityCloneable.addClaim` (`:63-97`) escribe el claim sin comprobar `scheme`, `ecrecover` ni el emisor; el `claimId = keccak256(abi.encode(issuer, topic))` y el índice `topicIssuers` **sí están IMPLEMENTADOS**.
- **Precondición:** `IdentityCloneable` inicializado con A4 como owner; A5 registrado en `TrustedIssuersRegistry` con el `topic` del claim (CU-01); A5 ha firmado el struct tipado; `scheme == 1` (ECDSA). *La comprobación on-chain de estas precondiciones es el objeto de RF-001.*
- **Flujo principal:**
  1. A4 (o el relay) construye el digest EIP-712: `domainSeparator = keccak256(EIP712Domain(name,version,chainId,verifyingContract))` y `structHash = keccak256(abi.encode(CLAIM_TYPEHASH, walletOwner, topic, scheme, keccak256(data)))`.
  2. A4 llama `addClaim(topic, scheme, issuer, signature, data, uri)`.
  3. El contrato comprueba `scheme == 1` y que `issuer != address(0)`.
  4. El contrato resuelve el digest y ejecuta `ecrecover`; `recovered == issuer` y `issuer != address(0)`.
  5. El contrato verifica la autorización consultando **`trustedIssuersRegistry.hasClaimTopic(issuer, topic) == true`** (`TrustedIssuersRegistry.sol:101-113`). `IdentityRegistry` **no** participa en la autorización de issuers: solo mantiene el mapeo wallet→identity (M-04).
  6. El contrato gestiona el reintento: `claimId = keccak256(issuer, topic)`; si ya existe, **se sobrescribe** el claim previo siempre que la firma EIP-712 sea válida (**D-018**, decisión del usuario; permite renovar un claim vigente).
  7. El contrato escribe `claims[topic][issuer]`, actualiza `topicIssuers`/`topicIssuerExists`, emite `ClaimAdded(topic, scheme, issuer, signature, data, uri)` y retorna `claimId`.
- **Flujos alternativos:**
  - A2.1 `signature.length != 65` → revierte `"Invalid signature length"` (mensaje propuesto por RF-001).
  - A2.2 `ecrecover` devuelve `address(0)` (firma malformada / `v` inválido) → revierte `"Invalid signature"` (propuesto).
  - A2.3 `recovered != issuer` → revierte `"Signature signer mismatch"` (propuesto).
  - A2.4 `scheme != 1` → revierte `"Unsupported scheme"` (propuesto).
  - A2.5 Issuer no autorizado para el topic → revierte `"Issuer not authorized for topic"` (propuesto).
  - A2.6 Llamada desde cuenta distinta del owner de la identidad → revierte por `onlyOwner`.
- **Postcondición:** Existe `claims[topic][issuer]` verificable; `getClaimIssuersForTopic(topic)` incluye a `issuer`; `isVerified(wallet)` puede pasar a `true` si se cubren todos los topics requeridos.
- **Cobertura:** RF-001 · HB-01 · D-007.

**Criterios Gherkin**
1. `test_RF001_addClaim_con_firma_valida` — **A IMPLEMENTAR (RF-001)**
   - **Dado** un issuer confiable para el topic 1 y una firma EIP-712 válida sobre `(wallet,1,1,data)`,
   - **Cuando** el owner de la identidad llama `addClaim(1,1,issuer,firma,data,"")`,
   - **Entonces** `claimExists(1,issuer) == true`, `getClaim(1,issuer)` devuelve `issuer` y `data` originales, y se emite `ClaimAdded`.
2. `test_RF001_addClaim_emite_claimId_estable` — **IMPLEMENTADO** (salvo la verificación de firma del paso previo)
   - **Dado** un claim admitido,
   - **Cuando** se llama `addClaim` dos veces para `(topic,issuer)` distintos,
   - **Entonces** el `claimId` retornado es `keccak256(abi.encode(issuer, topic))` y es determinista.
3. `test_RF001_addClaim_actualiza_indice_topicIssuers` — **IMPLEMENTADO**
   - **Dado** una identidad sin claim del topic 1,
   - **Cuando** se añade un claim válido del topic 1 del issuer A5,
   - **Entonces** `getClaimIssuersForTopic(1)` contiene exactamente una vez a A5 (sin duplicados al re-añadir).
4. `test_RF001_addClaim_only_owner_revierte` — **IMPLEMENTADO**
   - **Dado** una cuenta que no es owner de la identidad,
   - **Cuando** intenta `addClaim`,
   - **Entonces** revierte por `OwnableUnauthorizedAccount`.

**Restricciones EARS**
- `test_RF001_addClaim_scheme_no_soportado_revierte` — **Cuando** el `scheme` recibido sea distinto de `1` (ECDSA), el sistema deberá revertir con `"Unsupported scheme"` sin escribir `claims` ni `topicIssuers`. **A IMPLEMENTAR (RF-001)**
- `test_RF001_addClaim_digest_vincula_verifyingContract` — **Mientras** la firma se genere con un `verifyingContract` distinto al de la identidad, el sistema deberá rechazar el claim por `recovered != issuer`. **A IMPLEMENTAR (RF-001)**
- `test_RF001_addClaim_digest_vincula_chainId` — **Si** el `chainId` del digest no coincide con el de la red de ejecución, entonces el sistema deberá rechazar el claim. **A IMPLEMENTAR (RF-001)**
- `test_RF001_addClaim_issuer_cero_revierte` — **Si** `issuer == address(0)`, entonces el sistema deberá revertir con el literal `"Invalid issuer address"` (fijado por la implementación de RF-001) **sin ejecutar `ecrecover`**, y `claimExists(topic, address(0)) == false`; se verifica con `vm.expectRevert(bytes("Invalid issuer address"))`. **A IMPLEMENTAR (RF-001)**

---

### CU-03 — Rechazar claim con firma inválida o issuer no autorizado para el topic

- **Actor:** A4 (remitente) / A5 (firmante); resultado observado también por A8.
- **Objetivo:** Garantizar que ningún claim sin firma criptográficamente válida de un issuer autorizado entre en la identidad.
- **Estado:** **A IMPLEMENTAR (RF-001).** HOY `addClaim` no verifica nada; todos los criterios de este CU quedan pendientes de RF-001.
- **Precondición:** `IdentityCloneable` desplegado; `TrustedIssuersRegistry` con un issuer autorizado solo para el topic 1.
- **Flujo principal:**
  1. El remitente prepara un claim con firma manipulada, o con un `issuer` que no puede emitir el topic.
  2. Llama `addClaim(topic, 1, issuer, signature, data, uri)`.
  3. La verificación EIP-712 falla (firma) o la consulta `hasClaimTopic(issuer, topic)` devuelve `false` (autorización).
  4. El contrato revierte y **no** escribe en `claims` ni en `topicIssuers`.
  5. El invocador recibe el motivo de rechazo on-chain.
- **Flujos alternativos:**
  - A3.1 Firma de otra clave válida (`recovered != issuer`) → `"Signature signer mismatch"`.
  - A3.2 `data` alterado tras firmar → el `structHash` cambia → `recovered != issuer` → revierte.
  - A3.3 `topic` alterado tras firmar → revierte igualmente.
  - A3.4 Issuer confiable para topic 7 pero claim de topic 1 → `"Issuer not authorized for topic"`.
  - A3.5 Issuer retirado de `TrustedIssuersRegistry` antes del `addClaim` → revierte.
  - A3.6 Reintento del mismo `(topic, issuer)` ya existente **con firma válida** → el claim se **sobrescribe** (renovación): se actualizan `claims[topic][issuer]`, `signature`, `data`, `uri` y los metadatos de vigencia, sin duplicar al issuer en `topicIssuers`, y se emite un nuevo `ClaimAdded`. Es la política decidida por el usuario y registrada como **D-018** (cierra la antigua D-013). Si la firma no es válida, aplican A3.1–A3.5 y **no** hay sobrescritura alguna.
- **Postcondición:** El estado de la identidad permanece idéntico al previo; `claimExists(topic,issuer) == false`; `identityRegistry.isVerified(wallet)` no mejora por un claim inválido.
- **Cobertura:** RF-001 · HB-01 · D-018 (cierra D-013).

**Criterios Gherkin**
1. `test_RF001_addClaim_firma_de_otra_clave_revierte` — **A IMPLEMENTAR (RF-001)**
   - **Dado** un issuer confiable para topic 1 y una firma producida por una clave distinta,
   - **Cuando** el owner llama `addClaim(1,1,issuer,firma,data,"")`,
   - **Entonces** la llamada revierte con `"Signature signer mismatch"` y `claimExists(1,issuer) == false`.
2. `test_RF001_addClaim_data_manipulada_revierte` — **A IMPLEMENTAR (RF-001)**
   - **Dado** una firma válida sobre `data` original,
   - **Cuando** se envía `data'` distinto,
   - **Entonces** la llamada revierte y no se persiste el claim.
3. `test_RF001_addClaim_topic_no_autorizado_revierte` — **A IMPLEMENTAR (RF-001)**
   - **Dado** un issuer confiable solo para el topic 7,
   - **Cuando** el owner llama `addClaim(1,1,issuer,firma,data,"")`,
   - **Entonces** revierte con `"Issuer not authorized for topic"`.
4. `test_RF001_addClaim_firma_longitud_invalida_revierte` — **A IMPLEMENTAR (RF-001)**
   - **Dado** un `bytes signature` de 64 bytes,
   - **Cuando** se llama `addClaim`,
   - **Entonces** revierte con `"Invalid signature length"`.
5. `test_RF001_addClaim_reintento_sobrescribe_renueva` — **A IMPLEMENTAR (RF-001)**
   - **Dado** un claim válido ya persistido para `(topic,issuer)` con `data`/`uri` antiguos,
   - **Cuando** el owner reintenta `addClaim` con una nueva firma EIP-712 válida del mismo issuer para el mismo topic y con `data'`/`uri'` nuevos,
   - **Entonces** `getClaim(1,issuer)` devuelve `data'`/`uri'`, `getClaimIssuersForTopic(1)` sigue conteniendo al issuer **una sola vez** y se emite `ClaimAdded` de nuevo (renovación por sobrescritura, D-018).

**Restricciones EARS**
- `test_RF001_addClaim_ecrecover_cero_revierte` — **Si** `ecrecover` devuelve `address(0)`, entonces el sistema deberá revertir con `"Invalid signature"` y no almacenar el claim. **A IMPLEMENTAR (RF-001)**
- `test_RF001_addClaim_issuer_retirado_revierte` — **Mientras** el issuer no figure como confiable en el momento de la transacción, el sistema deberá rechazar el claim. **A IMPLEMENTAR (RF-001)**
- `test_RF001_addClaim_no_escribe_estado_en_fallo` — **Cuando** cualquier verificación del claim falle, el sistema deberá garantizar que `claims` y `topicIssuers` quedan sin cambios (atomicidad del revert). **A IMPLEMENTAR (RF-001)**

---

### CU-04 — Retirar el bypass de compliance y proteger contra reentrancia

- **Actor:** A2 (Agente) y A3 (Compliance Officer).
- **Objetivo:** Eliminar el flag mutable `bypassCompliance` y sustituirlo por un mecanismo de recuperación acotado (`forcedTransfer` a destino autorizado) bajo `ReentrancyGuardUpgradeable`.
- **Estado:** **A IMPLEMENTAR (RF-002).** HOY `TokenCloneable.sol:47` declara `bool private bypassCompliance`, `:212/:218` lo activan/desactivan y `:317/:324` lo usan; **no** existen `authorizedDestinations`, `maxForcedPerTx` ni `ReentrancyGuard` (`grep` → 0 resultados). Lo único IMPLEMENTADO aquí es `require(isVerified(to), "Recipient not verified")` (`:209`) y la notificación `transferred` (`:221-223`).
- **Precondición (tras RF-002):** `TokenCloneable` inicializado; `bypassCompliance` **ya no existe** en el layout (D-009 permite redeploy limpio); actor con `AGENT_ROLE`; destino en `authorizedDestinations`.
- **Flujo principal:**
  1. A2 llama `forcedTransfer(from, to, amount)`, marcada `nonReentrant`.
  2. El contrato valida `authorizedDestinations[to] == true` y `amount <= maxForcedPerTx`.
  3. El contrato valida `isVerified(to) == true`.
  4. El contrato ejecuta la transferencia sin llamar a `canTransfer` (bypass acotado) mediante un método interno que invoca `super._update`, sin escribir ningún flag de storage.
  5. Notifica `transferred(from,to,amount)` a los módulos de compliance.
  6. Emite el evento de transferencia ERC-20.
- **Flujos alternativos:**
  - A4.1 `to` no autorizado → revierte `"Destination not authorized"`.
  - A4.2 `amount > maxForcedPerTx` → revierte `"Exceeds max forced per tx"`.
  - A4.3 `to` no verificado → revierte `"Recipient not verified"` (mensaje ya existente).
  - A4.4 Reentrada: un módulo de compliance malicioso reentra en `forcedTransfer`, `transfer` o `_update` durante el callback → revierte `ReentrancyGuardReentrantCall`.
  - A4.5 Remitente sin `AGENT_ROLE` → revierte por `AccessControlUnauthorizedAccount`.
  - A4.6 `from == address(0)` → HOY `forcedTransfer(0,to,amount)` **acuña** tokens (no revierte), porque `_update` con `from == 0` es un mint (`TokenCloneable.sol:208-224,315-321`). Es un **cambio objetivo de RF-002**: añadir `require(from != address(0), "Invalid from address")`. `to == address(0)` revierte por `ERC20InvalidReceiver` (caso B-05).
- **Postcondición:** No queda ningún flag booleano de bypass en storage (`forge inspect TokenCloneable storage-layout --json` sin `bypassCompliance`); los balances reflejan la transferencia forzada; el guard de reentrancia queda libre al final.
- **Cobertura:** RF-002 · HB-03 · D-006 · D-009.

**Criterios Gherkin**
1. `test_RF002_forcedTransfer_destino_autorizado_ok` — **A IMPLEMENTAR (RF-002)**
   - **Dado** un token con `authorizedDestinations[to] = true`, `maxForcedPerTx = 1000` y saldo de `from` de 500,
   - **Cuando** A2 llama `forcedTransfer(from,to,500)`,
   - **Entonces** `balanceOf(to)` aumenta en 500 y no se consulta `canTransfer` de los módulos.
2. `test_RF002_forcedTransfer_destino_no_autorizado_revierte` — **A IMPLEMENTAR (RF-002)**
   - **Dado** `authorizedDestinations[to] == false`,
   - **Cuando** A2 llama `forcedTransfer`,
   - **Entonces** revierte con `"Destination not authorized"`.
3. `test_RF002_forcedTransfer_excede_maximo_revierte` — **A IMPLEMENTAR (RF-002)**
   - **Dado** `maxForcedPerTx = 100` y `amount = 101`,
   - **Cuando** A2 llama `forcedTransfer`,
   - **Entonces** revierte con `"Exceeds max forced per tx"`.
4. `test_RF002_forcedTransfer_notifica_modulos` — **IMPLEMENTADO (parcial)**
   - **Dado** un token con un módulo espía registrado,
   - **Cuando** A2 llama `forcedTransfer(from,to,amount)` con éxito,
   - **Entonces** el módulo recibe `transferred(from,to,amount)` exactamente una vez.
5. `ci_check_RF002_no_bypassCompliance_storage` — **A IMPLEMENTAR (RF-002)** (renombrado; era un `test_*` que en realidad es un comando, B-03)
   - **Dado** el contrato compilado `TokenCloneable`,
   - **Cuando** el CI ejecuta `forge inspect TokenCloneable storage-layout --json | grep -c bypassCompliance`,
   - **Entonces** el comando imprime `0` y el job falla (exit != 0) si el conteo es ≥ 1.

**Restricciones EARS**
- `test_RF002_forcedTransfer_reentrancy_revierte` — **Mientras** una llamada a `forcedTransfer` esté en ejecución, el sistema deberá revertir con `ReentrancyGuardReentrantCall` cualquier reintento de entrada a funciones `nonReentrant`. **A IMPLEMENTAR (RF-002)**
- `test_RF002_forcedTransfer_invoca_super_update_sin_flag` — **Cuando** se ejecute `forcedTransfer`, el sistema deberá realizar la actualización de balances sin escribir ningún flag de storage de bypass. **A IMPLEMENTAR (RF-002)**
- `test_RF002_forcedTransfer_only_agent_revierte` — **Si** el emisor no posee `AGENT_ROLE`, entonces el sistema deberá revertir por control de acceso (`AccessControlUnauthorizedAccount`). **IMPLEMENTADO** (`onlyRole(AGENT_ROLE)`, `:208`)
- `test_RF002_forcedTransfer_from_cero_revierte` — **Si** `from == address(0)`, entonces el sistema deberá revertir con `"Invalid from address"` y no acuñar tokens. **A IMPLEMENTAR (RF-002)** (caso B-05)

---

### CU-05 — Validar la interfaz `ICompliance` al registrar un módulo

- **Actor:** A3 (Compliance Officer).
- **Objetivo:** Impedir el alta de direcciones que no implementan `ICompliance`, validando `supportsInterface`.
- **Estado:** **A IMPLEMENTAR (RF-003)** en la validación; el cálculo del `interfaceId` es verificable HOY.
- **Precondición:**
  - **(a) Verificable HOY:** `TokenCloneable` inicializado y A3 con `COMPLIANCE_ROLE`. HOY `ICompliance.sol:8` es `interface ICompliance {` y **no** hereda `IERC165`; ningún contrato de `src/` implementa `supportsInterface` (`grep -rn "supportsInterface\|IERC165\|ERC165" rwa-sc/sc/src/` → **0 resultados**). Por tanto `addComplianceModule` (`TokenCloneable.sol:119-124`) HOY **no valida nada**: solo comprueba `module != address(0)`. Los criterios 1–3 y las EARS de este CU están **A IMPLEMENTAR (RF-003)**.
  - **(b) TRAS implementar RF-003:** `ICompliance` pasa a `interface ICompliance is IERC165` y los **4 contratos de compliance** —`MaxBalanceCompliance`, `MaxHoldersCompliance`, `TransferLockCompliance` y `ComplianceAggregator`— implementan `supportsInterface(type(ICompliance).interfaceId) == true`. **RF-003 implica modificar `ICompliance.sol` y esos 4 contratos**, no solo el token. El `interfaceId` sigue siendo el XOR de los 4 selectores **propios** (`canTransfer`, `transferred`, `created`, `destroyed`): Solidity excluye las funciones heredadas del `interfaceId`, por lo que el criterio 4 es válido antes y después de RF-003 (FD-03).
- **Flujo principal (tras RF-003):**
  1. A3 llama `TokenCloneable.addComplianceModule(module)`.
  2. El contrato valida `module != address(0)`.
  3. El contrato invoca `IERC165(module).supportsInterface(type(ICompliance).interfaceId)`.
  4. Si devuelve `true`, se hace `complianceModules.push(ICompliance(module))` y se emite `ComplianceModuleAdded(module)`.
  5. Análogamente, `ComplianceAggregator.addModule(token, module)` repite la validación antes de insertar (CU-07).
- **Flujos alternativos:**
  - A5.1 `module == address(0)` → revierte `"Invalid module address"` (mensaje ya existente en `:120`).
  - A5.2 Contrato sin `supportsInterface` → la llamada revierte (o retorna `false`) → revierte `"Module does not implement ICompliance"` (propuesto por RF-003).
  - A5.3 `supportsInterface` devuelve `false` (EOA o contrato ajeno) → revierte `"Module does not implement ICompliance"`.
  - A5.4 Módulo ya añadido → revierte `"Module already added"` (aplica al aggregator; el token debe impedir duplicados).
  - A5.5 Remitente sin `COMPLIANCE_ROLE` → revierte por `AccessControlUnauthorizedAccount`.
- **Postcondición:** `getComplianceModules()` y `getModuleCount` reflejan únicamente módulos conformes; `canTransfer` del token no puede romperse por un selector inexistente.
- **Cobertura:** RF-003 · HB-04.

**Criterios Gherkin**
1. `test_RF003_addComplianceModule_valida_erc165_ok` — **A IMPLEMENTAR (RF-003)**
   - **Dado** un `MaxBalanceCompliance` que, tras RF-003, implementa `supportsInterface`,
   - **Cuando** A3 llama `addComplianceModule(module)`,
   - **Entonces** `getComplianceModules()[0] == module` y se emite `ComplianceModuleAdded`.
2. `test_RF003_addComplianceModule_revierte_contrato_sin_interfaz` — **A IMPLEMENTAR (RF-003)**
   - **Dado** un contrato cualquiera sin `supportsInterface`,
   - **Cuando** A3 llama `addComplianceModule`,
   - **Entonces** revierte con `"Module does not implement ICompliance"` y `getComplianceModules().length == 0`.
3. `test_RF003_addComplianceModule_revierte_eoa` — **A IMPLEMENTAR (RF-003)**
   - **Dado** una EOA (`address(0xBEEF)`),
   - **Cuando** A3 llama `addComplianceModule`,
   - **Entonces** revierte y `getComplianceModules().length == 0`.
4. `test_RF003_interfaceId_ICompliance_correcto` — **IMPLEMENTADO** (cálculo verificable HOY)
   - **Dado** el `bytes4 type(ICompliance).interfaceId`,
   - **Cuando** se compara con el XOR de los selectores `canTransfer`, `transferred`, `created`, `destroyed`,
   - **Entonces** coinciden exactamente (sin cambios al añadir `is IERC165`).

**Restricciones EARS**
- `test_RF003_addComplianceModule_no_escribe_si_invalido` — **Si** `supportsInterface` devuelve `false`, entonces el sistema deberá revertir sin modificar `complianceModules`. **A IMPLEMENTAR (RF-003)**
- `test_RF003_addComplianceModule_zero_revierte` — **Cuando** `module == address(0)`, el sistema deberá revertir con `"Invalid module address"` sin invocar `supportsInterface`. **IMPLEMENTADO**
- `test_RF003_addComplianceModule_duplicado_revierte` — **Mientras** el módulo ya esté registrado, el sistema deberá rechazar un segundo alta. **A IMPLEMENTAR (RF-003)** (hoy `TokenCloneable` no impide duplicados).

---

### CU-06 — Limitar `burn`/`forcedTransfer` por whitelist de destinos y límites por operación

- **Actor:** A2 (Agente) ejecuta; A1/A3 administran los parámetros de control.
- **Objetivo:** Acotar los poderes de `AGENT_ROLE` mediante whitelist de destinos para recuperaciones y topes por transacción en quema y transferencia forzada.
- **Estado:** **A IMPLEMENTAR (RF-004).** HOY `burn` (`TokenCloneable.sol:192-201`) no aplica tope y `forcedTransfer` no consulta whitelist ni límite; tampoco existen `authorizedDestinations`, `maxBurnPerTx` ni `maxForcedPerTx` (grep → 0 resultados).
- **Precondición (tras RF-004):** Token inicializado; A1/A3 gestionan `authorizedDestinations`, `maxBurnPerTx`, `maxForcedPerTx`.
- **Flujo principal:**
  1. A1/A3 llama `setAuthorizedDestination(addr, true)` y `setMaxBurnPerTx(n)` / `setMaxForcedPerTx(m)`.
  2. A2 llama `burn(from, amount)` con `amount <= maxBurnPerTx`.
  3. El contrato ejecuta `_burn(from, amount)` y notifica `destroyed(from, amount)` a los módulos.
  4. A2 llama `forcedTransfer(from, to, amount)` con `to` autorizado y `amount <= maxForcedPerTx` (criterios y deduplicación en CU-04 #1/#2).
  5. El contrato ejecuta la transferencia forzada y notifica `transferred`.
- **Flujos alternativos:**
  - A6.1 `burn` con `amount > maxBurnPerTx` → revierte `"Exceeds max burn per tx"`.
  - A6.2 `forcedTransfer` con `to` no autorizado → revierte `"Destination not authorized"` (ver CU-04 #2).
  - A6.3 `setAuthorizedDestination` desde cuenta sin `DEFAULT_ADMIN_ROLE` **ni** `COMPLIANCE_ROLE` → revierte.
  - A6.4 `burn` de una cuenta con saldo insuficiente → revierte por `ERC20InsufficientBalance`.
  - A6.5 `setMaxBurnPerTx(0)` o `setMaxForcedPerTx(0)` → el criterio fija el comportamiento: `0` desactiva la operación (revert en cualquier `amount > 0`).
  - A6.6 `maxBurnPerTx` no limita el agregado de varias transacciones (el límite es por operación).
- **Nota M-06 (deduplicación):** los criterios de `forcedTransfer` con destino whitelisted/no whitelisted viven en **CU-04 #1 y CU-04 #2**; este CU los referencia y no los repite.
- **Postcondición:** Ninguna quema ni recuperación supera el tope; toda recuperación va a un destino declarado autorizado; `burn`/`forcedTransfer` denegados no alteran balances.
- **Cobertura:** RF-004 · RF-002 · HB-02 · D-006.

**Criterios Gherkin**
1. `test_RF004_burn_dentro_del_limite_ok` — **A IMPLEMENTAR (RF-004)**
   - **Dado** `maxBurnPerTx = 100` y saldo 100 de `from`,
   - **Cuando** A2 llama `burn(from,100)`,
   - **Entonces** `totalSupply` baja en 100 y `balanceOf(from) == 0`.
2. `test_RF004_burn_excede_limite_revierte` — **A IMPLEMENTAR (RF-004)**
   - **Dado** `maxBurnPerTx = 100`, saldo 200,
   - **Cuando** A2 llama `burn(from,101)`,
   - **Entonces** revierte con `"Exceeds max burn per tx"` y el saldo no cambia.
3. `test_RF004_setAuthorizedDestination_solo_admin_o_compliance` — **A IMPLEMENTAR (RF-004)**
   - **Dado** una cuenta sin `DEFAULT_ADMIN_ROLE` ni `COMPLIANCE_ROLE`,
   - **Cuando** llama `setAuthorizedDestination(addr,true)`,
   - **Entonces** revierte por control de acceso y `authorizedDestinations[addr] == false`.
4. `test_RF004_burn_notifica_modulos` — **IMPLEMENTADO**
   - **Dado** un token con un módulo espía registrado,
   - **Cuando** `burn(from,amount)` tiene éxito,
   - **Entonces** el módulo recibe `destroyed(from,amount)` exactamente una vez (`TokenCloneable.sol:192-201`).

**Restricciones EARS**
- `test_RF004_limite_es_por_operacion_no_acumulado` — **Mientras** el límite por operación esté configurado, el sistema deberá permitir N operaciones sucesivas cuyo importe individual no exceda el tope. **A IMPLEMENTAR (RF-004)**
- `test_RF004_whitelist_revocada_bloquea` — **Cuando** A1/A3 revoque `authorizedDestinations[to]`, el sistema deberá rechazar cualquier `forcedTransfer` posterior hacia ese destino. **A IMPLEMENTAR (RF-004)**
- `test_RF004_limites_zero_bloquean` — **Si** `maxBurnPerTx == 0`, entonces el sistema deberá revertir toda llamada `burn` con `amount > 0`. **A IMPLEMENTAR (RF-004)**

---

### CU-07 — Añadir y retirar módulos de compliance a través del `ComplianceAggregator`

- **Actor:** A3 (Compliance Officer), con A1 como `owner` del aggregator.
- **Objetivo:** Gestionar dinámicamente las reglas de compliance por token a través del aggregator, sin redeployar el token (extensibilidad).
- **Estado:** **IMPLEMENTADO** en su mayoría (`ComplianceAggregator.sol:50-130,252-255`). Solo la validación `supportsInterface` del paso 4 está **A IMPLEMENTAR (RF-003)**.
- **Precondición:** Aggregator desplegado; el aggregator está añadido como módulo del token (`addComplianceModule(aggregator)`); módulo conforme `ICompliance` (CU-05).
- **Flujo principal:**
  1. A3 llama `TokenCloneable.addModuleThroughAggregator(aggregator, module)`.
  2. El token comprueba que `aggregator` figura en `complianceModules`; si no, revierte `"Aggregator not added as compliance module"`.
  3. El token llama `ComplianceAggregator.addModule(address(this), module)`.
  4. El aggregator valida `onlyOwnerOrToken`, `token != address(0)`, `module != address(0)`, `!isModuleActive`, y `supportsInterface` (**A IMPLEMENTAR RF-003**).
  5. Registra el token en `tokens` si es la primera vez (`TokenRegistered`), inserta el módulo, fija `moduleIndex` y `isModuleActive`; emite `ModuleAdded`.
  6. Para la baja, A3 llama `removeModuleThroughAggregator(aggregator, module)`; el aggregator localiza el índice, hace *swap-and-pop* con `moduleIndex`, limpia `isModuleActive` y emite `ModuleRemoved`.
- **Flujos alternativos:**
  - A7.1 `aggregator == address(0)` o `module == address(0)` → revierte `"Invalid aggregator address"` / `"Invalid module address"`.
  - A7.2 Aggregator no añadido al token → revierte `"Aggregator not added as compliance module"`.
  - A7.3 `addModule` duplicado → revierte `"Module already added"`.
  - A7.4 `removeModule` de módulo inactivo → revierte `"Module not active"`.
  - A7.5 Llamada directa a `aggregator.addModule` desde una cuenta que no es `owner` ni el token → revierte `"Only owner or token can call"`.
  - A7.6 Baja del módulo del medio de una lista de tres → el índice del último se reasigna correctamente (test de swap-and-pop).
- **Postcondición:** `getModules(token)`/`getModuleCount(token)` reflejan la composición vigente; `canTransfer` del token (que consulta al aggregator) usa las reglas efectivas.
- **Cobertura:** RF-003 · RNF-005 · HB-04.

**Criterios Gherkin**
1. `test_RF003_addModuleThroughAggregator_ok` — **IMPLEMENTADO**
   - **Dado** un aggregator añadido a `complianceModules` del token y un módulo `ICompliance` válido,
   - **Cuando** A3 llama `addModuleThroughAggregator(aggregator, module)`,
   - **Entonces** `isModuleActiveInAggregator(aggregator, module) == true` y `getAggregatorModuleCount(aggregator) == 1`.
2. `test_RF003_removeModuleThroughAggregator_ok` — **IMPLEMENTADO**
   - **Dado** un módulo activo en el aggregator,
   - **Cuando** A3 llama `removeModuleThroughAggregator(aggregator, module)`,
   - **Entonces** `isModuleActiveInAggregator(...) == false` y el conteo baja en 1.
3. `test_RF003_removeModule_swap_and_pop_orden` — **IMPLEMENTADO**
   - **Dado** tres módulos `[M1,M2,M3]` activos,
   - **Cuando** se retira `M1` (`removeModule`),
   - **Entonces** `getModuleAt(token,0) == M3`, `getModuleCount(token) == 2` e `isModuleActiveForToken(token,M1) == false` (`moduleIndex` es `private` sin getter: no es observable, B-07).
4. `test_RF003_addModuleThroughAggregator_sin_agregador_revierte` — **IMPLEMENTADO**
   - **Dado** un aggregator que no está en `complianceModules`,
   - **Cuando** A3 llama `addModuleThroughAggregator`,
   - **Entonces** revierte con `"Aggregator not added as compliance module"`.
5. `test_RF003_aggregator_addModule_duplicado_revierte` — **IMPLEMENTADO**
   - **Dado** un módulo ya activo,
   - **Cuando** se reintenta `addModule`,
   - **Entonces** revierte con `"Module already added"`.
6. `test_RF003_aggregator_canTransfer_sin_modulos_true` — **IMPLEMENTADO**
   - **Dado** un token sin módulos configurados en el aggregator,
   - **Cuando** el token invoca `canTransfer`,
   - **Entonces** el aggregator devuelve `true` (`ComplianceAggregator.sol:118-125`).
7. `test_RF003_aggregator_canTransfer_todos_true` — **IMPLEMENTADO**
   - **Dado** dos módulos activos que devuelven `true`,
   - **Cuando** el token invoca `canTransfer`,
   - **Entonces** devuelve `true`; si uno devuelve `false`, devuelve `false`.
8. `test_RF003_aggregator_transferred_propaga` — **IMPLEMENTADO**
   - **Dado** dos módulos activos en el aggregator,
   - **Cuando** el token invoca `transferred`,
   - **Entonces** el aggregator propaga la notificación a todos los módulos activos del token.

**Restricciones EARS**
- `test_RF003_aggregator_only_owner_or_token` — **Si** el emisor no es `owner()` del aggregator ni el propio `token`, entonces el sistema deberá revertir con `"Only owner or token can call"`. **IMPLEMENTADO**

---

### CU-08 — Crear un token clon con registries mediante `TokenCloneFactory`

- **Actor:** A6 (Creador de token).
- **Objetivo:** Desplegar un token ERC-3643 como clon EIP-1167 con sus tres registries y sus roles ya concedidos al creador.
- **Estado:** **IMPLEMENTADO** en la creación (`TokenCloneFactory.sol:26-160`, `TokenCloneable.sol:50-52`); el criterio de gas RNF-001 **está roto hoy** (ver EARS) y debe reescribirse.
- **Precondición:** `TokenCloneFactory` desplegada (deploya la implementación en su constructor); registries desplegados.
- **Flujo principal:**
  1. A6 llama `createTokenWithRegistries(name, symbol, decimals, admin, idReg, tiReg, ctReg)`.
  2. El factory valida `admin != address(0)`, `name` no vacío y `symbol` no vacío.
  3. `token = implementation.clone()`.
  4. `TokenCloneable(token).initialize(name,symbol,decimals,address(this))` (factory como admin temporal).
  5. El factory fija los tres registries no nulos vía `setIdentityRegistry` / `setTrustedIssuersRegistry` / `setClaimTopicsRegistry`.
  6. El factory concede `DEFAULT_ADMIN_ROLE`, `AGENT_ROLE` y `COMPLIANCE_ROLE` a `admin`, y renuncia a los tres roles propios.
  7. Registra el token en `adminTokens[admin]` y `allTokens`; emite `TokenCreated(token, admin, name, symbol, decimals)`.
  8. Retorna la dirección del clon.
- **Flujos alternativos:**
  - A8.1 `admin == address(0)` → revierte `"Invalid admin address"`.
  - A8.2 `name` o `symbol` vacíos → revierte `"Token name required"` / `"Token symbol required"`.
  - A8.3 Algún registry es `address(0)` → se omite su `set*` (el token queda con ese registry sin configurar) y `isVerified` devuelve `false` hasta completarse.
  - A8.4 Llamada a `initialize` sobre un clon ya inicializado → revierte `"InvalidInitialization"`.
  - A8.5 `createToken` sin registries → clon operativo, registries configurables después por A1.
- **Postcondición:** Clon con `decimals` correctos, roles en `admin`, factory sin roles residuales, token listado en `getTokensByAdmin(admin)`; el coste de gas del alta respeta RNF-001.
- **Cobertura:** RF-005 · RNF-001 · HB-06 (no reutiliza storage muerto).

**Criterios Gherkin**
1. `test_RF005_createTokenWithRegistries_clon_ok` — **IMPLEMENTADO** (renombrado desde `test_RNF001_*`, B-04)
   - **Dado** registries desplegados y un admin válido,
   - **Cuando** A6 llama `createTokenWithRegistries("RWA","RWA",18,admin,id,ti,ct)`,
   - **Entonces** el clon tiene `name()=="RWA"`, `symbol()=="RWA"`, `decimals()==18`, y sus tres registries apuntan a los indicados.
2. `test_RF005_createTokenWithRegistries_roles_admin` — **IMPLEMENTADO**
   - **Dado** el flujo anterior,
   - **Cuando** se consultan los roles del clon,
   - **Entonces** `hasRole(DEFAULT_ADMIN_ROLE,admin)`, `hasRole(AGENT_ROLE,admin)` y `hasRole(COMPLIANCE_ROLE,admin)` son `true`, y el factory ya no tiene ninguno.
3. `test_RF005_createToken_sin_registries_ok` — **IMPLEMENTADO**
   - **Dado** un admin válido,
   - **Cuando** A6 llama `createToken`,
   - **Entonces** el clon queda inicializado y `getTotalTokens()` aumenta en 1, listándose en `getTokensByAdmin(admin)`.
4. `test_RF005_createToken_name_vacio_revierte` — **IMPLEMENTADO**
   - **Dado** `name_ == ""`,
   - **Cuando** A6 llama `createToken`,
   - **Entonces** revierte con `"Token name required"`.
5. `test_RF005_initialization_implementacion_bloqueada` — **IMPLEMENTADO**
   - **Dado** la implementación apuntada por `factory.implementation()`,
   - **Cuando** se llama `initialize` directamente sobre ella,
   - **Entonces** revierte por `_disableInitializers`.

**Restricciones EARS**
- `test_RNF001_gas_clone_menor_que_deploy_completo` — **Cuando** se cree un token por clon, el sistema deberá consumir `gasUsed(createTokenWithRegistries(name,symbol,decimals,admin,id,ti,ct)) < 0.10 × gasUsed(deploy directo equivalente)`, donde el término de comparación es exactamente `new TokenCloneable()` + `initialize(...)` + `setIdentityRegistry` + `setTrustedIssuersRegistry` + `setClaimTopicsRegistry` + `grantRole×3` + `renounceRole×3` desplegado y configurado en el mismo test; el test deberá declarar el valor medido. **A IMPLEMENTAR (RF-005/RNF-001).** Referencia rota hoy: el test de gas en underflow (clone 387.469 gas frente a "directo" 5.974) impide afirmar el `< 10%` hasta reescribirlo (`metricas_ejecucion.md:50-61`).
- `test_RF005_implementacion_unica_por_factory` — **Mientras** la factory exista, el sistema deberá exponer una única `implementation` inmutable. **IMPLEMENTADO**
- `test_RF005_clones_independientes` — **Cuando** se creen dos clones, el sistema deberá garantizar que el estado (balances, registries, módulos) de uno no afecte al otro. **IMPLEMENTADO**
- `test_RF005_no_storage_muerto_tokenName` — **Si** `name()`/`symbol()` se sirven desde ERC-20, entonces el sistema deberá evitar duplicar `_tokenName`/`_tokenSymbol` como almacenamiento muerto. **IMPLEMENTADO** (HB-06)

---

### CU-09 — Registrar identidad y consultar `isVerified`

- **Actor:** A1 (owner de `IdentityRegistry`) registra; A3/A2/A6 consultan; A4 es el titular.
- **Objetivo:** Vincular wallet ↔ contrato de identidad y determinar la verificación según topics requeridos y emisores confiables.
- **Estado:** **IMPLEMENTADO** (`IdentityRegistry.sol:33-82`; `TokenCloneable.sol:229-281`).
- **Precondición:** `IdentityRegistry` y `TrustedIssuersRegistry` configurados; `ClaimTopicsRegistry` del token con al menos un topic; identidad creada por `IdentityCloneFactory`.
- **Flujo principal:**
  1. A1 llama `registerIdentity(wallet, identity)` con ambos no nulos y wallet no registrada.
  2. El contrato fija `identities[wallet]`, `registered[wallet] = true`, inserta en `registeredAddresses` y emite `IdentityRegistered`.
  3. A4 añade claims válidos (CU-02).
  4. Un consumidor llama `TokenCloneable.isVerified(wallet)`: comprueba registry != 0, `isRegistered == true`, `getIdentity != 0`, y para cada topic requerido busca emisores en la identidad (`getClaimIssuersForTopic`) y exige `trustedIssuersRegistry.hasClaimTopic(issuer, topic)`.
  5. Devuelve `true` solo si todos los topics tienen al menos un claim de emisor confiable.
- **Flujos alternativos:**
  - A9.1 `wallet == address(0)` o `identity == address(0)` → revierte `"Invalid wallet address"` / `"Invalid identity address"`.
  - A9.2 Wallet ya registrada → revierte `"Wallet already registered"`.
  - A9.3 `updateIdentity` de wallet no registrada → revierte `"Wallet not registered"`.
  - A9.4 `removeIdentity` de wallet no registrada → revierte `"Wallet not registered"`; si existe, borra el mapeo y hace swap-and-pop en `registeredAddresses`.
  - A9.5 `claimTopicsRegistry == address(0)` → HOY `isVerified` retorna `true` para wallet registrada con identidad (sin topics exigidos). Es el **fail-open H-05 (auditoría V1)**, que **RF-011 revierte a `false`** (ver CU-15).
  - A9.6 Falta la claim de un topic → `isVerified` retorna `false`.
  - A9.7 La claim existe pero el issuer es confiable para otro topic → `isVerified` retorna `false`.
- **Postcondición:** `isRegistered(wallet)`, `getIdentity(wallet)` y `getRegisteredCount()` coherentes; `isVerified` determinista y consumible por `mint`/`canTransfer`.
- **Cobertura:** RF-001 · HB-01.

**Criterios Gherkin**
1. `test_RF001_registerIdentity_ok` — **IMPLEMENTADO**
   - **Dado** un registry con owner A1 y una wallet nueva,
   - **Cuando** A1 llama `registerIdentity(wallet, identity)`,
   - **Entonces** `isRegistered(wallet) == true`, `getIdentity(wallet) == identity` y `getRegisteredCount() == 1`.
2. `test_RF001_isVerified_todo_topics_cubiertos_true` — **IMPLEMENTADO**
   - **Dado** un token con topics requeridos `[1]`, wallet registrada con claim válido del issuer confiable para 1,
   - **Cuando** se consulta `isVerified(wallet)`,
   - **Entonces** devuelve `true`.
3. `test_RF001_isVerified_falta_claim_false` — **IMPLEMENTADO**
   - **Dado** topics requeridos `[1,7]` y solo claim del topic 1,
   - **Cuando** se consulta `isVerified(wallet)`,
   - **Entonces** devuelve `false`.
4. `test_RF001_isVerified_issuer_no_confiable_para_topic_false` — **IMPLEMENTADO**
   - **Dado** claim del topic 1 emitido por un issuer confiable solo para el topic 7,
   - **Cuando** se consulta `isVerified(wallet)`,
   - **Entonces** devuelve `false`.
5. `test_RF001_removeIdentity_swap_and_pop` — **IMPLEMENTADO**
   - **Dado** tres wallets registradas,
   - **Cuando** A1 llama `removeIdentity` sobre la primera,
   - **Entonces** `isRegistered == false`, el conteo baja a 2 y las otras permanecen registradas.
6. `test_RF001_registerIdentity_duplicado_revierte` — **IMPLEMENTADO**
   - **Dado** una wallet ya registrada,
   - **Cuando** A1 repite `registerIdentity`,
   - **Entonces** revierte con `"Wallet already registered"`.
7. `test_RF001_isVerified_sin_topics_registrada_true` — **IMPLEMENTADO (comportamiento actual; RF-011 lo revierte a `false`, ver CU-15)**
   - **Dado** un token con `claimTopicsRegistry == address(0)` y una wallet registrada con identidad,
   - **Cuando** se consulta `isVerified(wallet)`,
   - **Entonces** devuelve `true` (`TokenCloneable.sol:247-250`). **Nota RF-011 (H-05 auditoría V1):** este criterio documenta el comportamiento fail-open vigente y **debe invertirse** al implementar RF-011 (`test_RF011_isVerified_sin_registry_topics_false`).

**Restricciones EARS**
- `test_RF001_isVerified_registry_vacio_false` — **Mientras** `identityRegistry == address(0)` en el token, el sistema deberá devolver `false` en `isVerified`. **IMPLEMENTADO**
- `test_RF001_isVerified_no_confia_en_issuer_del_identity_sin_registry` — **Si** `trustedIssuersRegistry == address(0)`, entonces el sistema deberá devolver `false` para toda wallet con topics requeridos. **IMPLEMENTADO**
- `test_RF001_registerIdentity_only_owner_revierte` — **Cuando** una cuenta distinta del owner invoque `registerIdentity`, el sistema deberá revertir por control de acceso. **IMPLEMENTADO**

---

### CU-10 — Ejecutar una transferencia compliant (camino feliz y rechazos)

- **Actor:** A4 (Inversor/titular) como remitente/receptor.
- **Objetivo:** Transferir tokens respetando pausa, congelación, verificación de identidad y todos los módulos de compliance.
- **Estado:** **PARCIALMENTE IMPLEMENTADO.** `transfer`, pausa, congelación, `isVerified` y notificación `transferred` funcionan hoy (`TokenCloneable.sol:296-327`). Los criterios de `mint`/`burn`/`forcedTransfer` sin bypass que dependen de RF-002 están **A IMPLEMENTAR (RF-002)**.
- **Precondición:** `from` y `to` registrados y verificados; ninguno congelado; token no pausado; módulos configurados.
- **Flujo principal:**
  1. A4 llama `transfer(to, amount)` (o `transferFrom` con allowance).
  2. `_update(from,to,amount)` detecta que es transferencia real (ninguno es `address(0)`) y **no** hay bypass.
  3. `canTransfer(from,to,amount)` comprueba: no pausado, no congelados, `isVerified(from) && isVerified(to)`, y todos los módulos devuelven `true`.
  4. `super._update` mueve los balances.
  5. Se notifica `transferred(from,to,amount)` a todos los módulos (p. ej. `MaxHoldersCompliance` actualiza `holderCount`, `TransferLockCompliance` fija el lock del receptor).
  6. Se emite el evento `Transfer` de ERC-20.
- **Flujos alternativos:**
  - A10.1 Token pausado → revierte `"Transfer not compliant"` (`paused()==true`).
  - A10.2 `from` o `to` congelado → revierte `"Transfer not compliant"`.
  - A10.3 `from` o `to` no verificado → revierte `"Transfer not compliant"`.
  - A10.4 `MaxBalanceCompliance` rechaza por exceder `maxBalance` → revierte.
  - A10.5 `TransferLockCompliance` rechaza por lock vigente del remitente → revierte.
  - A10.6 `MaxHoldersCompliance` rechaza por alcanzar `maxHolders` con receptor nuevo → revierte.
  - A10.7 Saldo insuficiente → revierte por `ERC20InsufficientBalance` una vez pasada la compliance.
  - A10.8 Aggregator configurado como módulo: el rechazo de uno de sus módulos propaga `false` (CU-07).
- **Postcondición:** Balances actualizados o revert atómico; `holderCount` y lock coherentes con el resultado; ningún módulo queda notificado de una transferencia fallida.
- **Cobertura:** RF-002 · HB-03 · D-012 (RESUELTA por D-016).

> **D-012 — RESUELTA (decisión del usuario, registrada como D-016):** se **mantiene el chequeo de compliance en `mint()`** (alternativa A, *compliant siempre*).
> **Situación real:** `TokenCloneable.mint()` (`:176-190`) **sí** recorre los módulos y llama `canTransfer(address(0), to, amount)`, revirtiendo `"Mint not compliant"`; el salto de compliance de `_update` (`:317`) es a nivel ERC-20, pero `mint()` lo compensa explícitamente. Un test escrito como "mint omite `canTransfer`" fallará.
> **Criterios vigentes (alternativa A):** **Gherkin** `test_RF002_mint_llama_canTransfer_revierte` (Dado un módulo que rechaza, Cuando A2 llama `mint`, Entonces revierte `"Mint not compliant"`); **EARS** `test_RF002_mint_sin_modulos_ok` (Mientras no haya módulos, `mint` no revierte por compliance y notifica `created`).
> **Consecuencia asumida:** el agente no puede emitir a un receptor que incumpla una regla de compliance; debe corregirse antes el estado de compliance. Esto puede bloquear reposiciones legítimas (p. ej. `MaxBalance`), riesgo aceptado explícitamente por el usuario.
> **Alternativa B — DESCARTADA (bypass del agente).** Permitir que `mint` omita `canTransfer` bajo `AGENT_ROLE` fue **rechazada por decisión del usuario (D-016)**: ampliaba la superficie de poder del agente (un agente comprometido podría emitir saltándose reglas) y exigía whitelist/recuperación acotada análoga a `forcedTransfer`. No se redacta criterio vigente para esta alternativa; queda únicamente como registro histórico.

**Criterios Gherkin**
1. `test_RF002_transfer_camino_feliz` — **IMPLEMENTADO**
   - **Dado** `from` con saldo 100, `from`/`to` verificados y sin módulos que rechacen,
   - **Cuando** `from` llama `transfer(to,40)`,
   - **Entonces** `balanceOf(to) == 40`, `balanceOf(from) == 60` y se emitió `Transfer`.
2. `test_RF002_transfer_cuenta_congelada_revierte` — **IMPLEMENTADO**
   - **Dado** `frozen[to] == true`,
   - **Cuando** `from` llama `transfer(to,1)`,
   - **Entonces** revierte con `"Transfer not compliant"`.
3. `test_RF002_transfer_token_pausado_revierte` — **IMPLEMENTADO**
   - **Dado** A1 llamó `pause()`,
   - **Cuando** `from` llama `transfer(to,1)`,
   - **Entonces** revierte con `"Transfer not compliant"`.
4. `test_RF002_transfer_no_verificado_revierte` — **IMPLEMENTADO**
   - **Dado** `to` sin identidad registrada,
   - **Cuando** `from` llama `transfer(to,1)`,
   - **Entonces** revierte con `"Transfer not compliant"`.
5. `test_RF002_transfer_maxBalance_rechaza` — **IMPLEMENTADO** (renombrado desde `test_RF003_*`, M-03)
   - **Dado** `MaxBalanceCompliance` con `maxBalance = 100` y `to` con saldo 90,
   - **Cuando** `from` transfiere 20 a `to`,
   - **Entonces** revierte por `"Transfer not compliant"`.
6. `test_RF002_transfer_transferLock_rechaza` — **IMPLEMENTADO**
   - **Dado** `TransferLockCompliance` con lock vigente para `from`,
   - **Cuando** `from` transfiere,
   - **Entonces** revierte por `"Transfer not compliant"`.
7. `test_RF002_transfer_notifica_transferred_una_vez` — **IMPLEMENTADO**
   - **Dado** un módulo espía que cuenta llamadas,
   - **Cuando** se completa una transferencia,
   - **Entonces** el módulo recibe `transferred` exactamente una vez y no recibe `created`/`destroyed`.
8. `test_RF002_mint_llama_canTransfer_revierte` — **IMPLEMENTADO** (A-02, alternativa A vigente — **D-016**)
   - **Dado** un módulo de compliance registrado que devuelve `false` en `canTransfer`,
   - **Cuando** A2 (`AGENT_ROLE`) llama `mint(to, amount)`,
   - **Entonces** revierte con `"Mint not compliant"` y no cambia `totalSupply` (`TokenCloneable.sol:180-182`).
9. `test_RF002_burn_no_llama_canTransfer_y_notifica_destroyed` — **IMPLEMENTADO**
   - **Dado** un token con un módulo espía que rechazaría `canTransfer`,
   - **Cuando** A2 llama `burn(from, amount)`,
   - **Entonces** la quema sucede, el módulo no recibe `canTransfer` y sí recibe `destroyed(from,amount)`.
10. `test_RF002_forcedTransfer_no_llama_canTransfer` — **IMPLEMENTADO (parcial)**
    - **Dado** un módulo espía que rechazaría `canTransfer`,
    - **Cuando** A2 ejecuta `forcedTransfer(from,to,amount)`,
    - **Entonces** no se consulta `canTransfer`; con RF-002 el bypass deberá lograrse **sin** flag de storage mutable (hoy usa `bypassCompliance`).

**Restricciones EARS**
- `test_RF002_mint_sin_modulos_ok` — **Mientras** no haya módulos de compliance registrados, el sistema deberá permitir `mint(to, amount)` sin revertir por compliance y notificar `created(to, amount)`. **IMPLEMENTADO**
- `test_RF002_transfer_from_sin_allowance_revierte` — **Si** `allowance(from,spender)` es insuficiente, entonces el sistema deberá revertir por `ERC20InsufficientAllowance` sin ejecutar notificaciones a módulos. **IMPLEMENTADO**

---

### CU-11 — Compilar y ejecutar la suite de tests en CI con umbral de cobertura

- **Actor:** A7 (Desarrollador/CI) sobre la rama `rwa-sc-DSH-GCP` (D-005, D-008).
- **Objetivo:** Garantizar build reproducible, 151+ tests al 100% y cobertura ≥ 80% en cada commit/MR.
- **Estado:** **IMPLEMENTADO (Ciclo 11 / RF-009), validado en local y pendiente de ejecución remota** (no hay `push`). El pipeline `.gitlab-ci.yml` materializa las etapas `validate`→`build`→`fmt`→`test`→`coverage`→`gas`→`ci-checks`; los criterios Gherkin/EARS de este CU se cumplen en la simulación local `sc/script/ci/run_local_ci.sh` (exit 0). Baseline real medido (2026-10-03): 151 declarados, **98 ejecutados, 93 pasan, 5 fallan, 53 no arrancan**, coverage **42,86%**; estado actual: **353 tests, 353 pasan**, cobertura `src/` **97,12 %** de líneas (mínimo por contrato 91,53 %; D-017/D-042). Ver `metricas_ejecucion.md` §19.
- **Precondición:** `rwa-sc/.gitmodules` (raíz) declara los 3 submódulos con commit pinneado: `sc/lib/forge-std`, `sc/lib/openzeppelin-contracts`, `sc/lib/openzeppelin-contracts-upgradeable`. `rwa-sc/sc/.gitmodules` declara **solo** `lib/openzeppelin-contracts` (M-07). `foundry.toml` con remappings correctos; runner GitLab con Foundry instalado.
- **Flujo principal:**
  1. El pipeline ejecuta `git submodule update --init --recursive`.
  2. Ejecuta `forge build` con `--deny-warnings` (o warnings tratados como error).
  3. Ejecuta `forge test -vvv`.
  4. Ejecuta `forge coverage --report lcov` y calcula el porcentaje total.
  5. El pipeline publica el reporte como artefacto y compara el umbral.
- **Flujos alternativos:**
  - A11.1 Falla `forge build` → el pipeline se detiene en `build`.
  - A11.2 Cualquier test falla → el pipeline se detiene en `test` (RNF-003).
  - A11.3 Cobertura < 80% → el pipeline se detiene en `coverage` con exit != 0 (RNF-002).
  - A11.4 Submódulo ausente/desactualizado → `build` falla y se reporta como HB-05 no resuelto.
  - A11.5 Tests nuevos por cambio no añadidos → se verifica que el número de tests pasados no disminuye respecto del inicio de la iteración y alcanza ≥ 151 al cerrar RF-005.
- **Postcondición:** Pipeline verde solo si build OK, 100% tests OK y coverage ≥ 80%; artefacto LCOV disponible; commit/MR bloqueado si falla.
- **Cobertura:** RF-005 · RF-009 · RNF-002 · RNF-003 · HB-05 · HB-10 · HB-11 · D-008 · D-010.

**Criterios Gherkin**
1. `ci_check_RF005_forge_build_ok` — **A IMPLEMENTAR (RF-005)**
   - **Dado** el checkout con submódulos inicializados,
   - **Cuando** el CI ejecuta `forge build --deny-warnings`,
   - **Entonces** el comando termina con código 0 y `out/` contiene al menos un artefacto `.json` por contrato de `src/`.
2. `ci_check_RF009_pipeline_test_exit_0` — **A IMPLEMENTAR (RF-005/RF-009)**
   - **Dado** el checkout en CI con el baseline medido (98 ejecutados / 93 pasan / 5 fallan / 53 no arrancan),
   - **Cuando** el CI ejecuta `forge test -vvv`,
   - **Entonces** el número de tests pasados es ≥ el baseline del inicio de la iteración y no hay fallos; al cerrar RF-005 el total pasa a ≥ 151 con 0 fallos y 0 no-arrancados.
3. `ci_check_RNF002_coverage_mayor_igual_80` — **A IMPLEMENTAR (RNF-002)**
   - **Dado** el reporte `lcov.info` generado por `forge coverage --report lcov`,
   - **Cuando** el CI calcula el porcentaje agregado (líneas cubiertas / líneas totales del reporte),
   - **Entonces** el pipeline falla si el porcentaje es < 80 (hoy 42,86%).
4. `ci_check_RF009_artefacto_lcov_publicado` — **A IMPLEMENTAR (RF-009)**
   - **Dado** un pipeline completo,
   - **Cuando** finaliza el job,
   - **Entonces** el artefacto `lcov.info` está disponible como *artifact* del job.

**Restricciones EARS**
- `ci_check_RF005_submodulos_pinneados` — **Cuando** el CI inicialice dependencias, el sistema deberá comprobar que `rwa-sc/.gitmodules` (raíz) declara los 3 submódulos (`sc/lib/forge-std`, `sc/lib/openzeppelin-contracts`, `sc/lib/openzeppelin-contracts-upgradeable`) y que `git submodule status` los muestra con commit concreto, sin prefijo `-` (no inicializado) ni `+` (commit desalineado); deberá además alinear `rwa-sc/sc/.gitmodules`, que hoy solo declara `lib/openzeppelin-contracts`. **A IMPLEMENTAR (RF-005)** (M-07)
- `ci_check_RNF003_bloqueo_merge_con_fallos` — **Mientras** el pipeline no esté verde, el sistema de CI deberá impedir el merge en la rama protegida. **A IMPLEMENTAR (RNF-003)**
- `ci_check_RF005_remappings_coherentes` — **Si** `foundry.toml` no declara los remappings de OpenZeppelin y upgradeable, entonces el sistema deberá fallar el job de build con el listado de remappings ausentes en el log. **A IMPLEMENTAR (RF-005)**
- `ci_check_RF009_umbral_configurable_centralizado` — **Cuando** se modifique el umbral de cobertura, el sistema deberá leerlo de una única variable de CI (`.gitlab-ci.yml` → `COVERAGE_THRESHOLD`), no de literales duplicados. **A IMPLEMENTAR (RF-009)**

---

### CU-12 — Publicar y verificar documentación de seguridad y CHANGELOG de ABIs

- **Actor:** A7 (mantiene) y A8 (verifica).
- **Objetivo:** Corregir referencias rotas a archivos inexistentes, publicar `SECURITY.md` con hallazgos/mitigaciones y un `CHANGELOG` de ABIs para sincronizar `rwa-web`.
- **Estado:** **A IMPLEMENTAR (RF-006).**
- **Precondición:** Repositorio `rwa-sc` en la rama de trabajo; hallazgos HB-01..HB-12 conocidos.
- **Flujo principal:**
  1. Se sustituyen en la documentación las referencias a `Token.sol`, `Identity.sol` y los `.md` inexistentes por las rutas reales (`TokenCloneable.sol`, `IdentityCloneable.sol`, `ComplianceAggregator.sol`, módulos).
  2. Se crea `SECURITY.md` mapeando cada HB-xx a su mitigación (RF-xxx) y su test.
  3. Se crea `CHANGELOG_ABIS.md` con el diff de firmas entre la versión previa y la nueva.
  4. El CI ejecuta el script `script/ci/abi_diff.sh` y los *checks* de documentación.
- **Flujos alternativos:**
  - A12.1 Alguna referencia rota persiste → el *check* `ci_check_RF006_refs_rotas` falla y lista el archivo y la línea.
  - A12.2 Un HB-xx no aparece en `SECURITY.md` → el *check* `ci_check_RF006_hallazgos_cubiertos` falla.
  - A12.3 `CHANGELOG_ABIS.md` sin entradas para un selector modificado → `script/ci/abi_diff.sh` falla.
  - A12.4 Documentación enlazada a rutas con espacios → se exige formato `<...>` y el *check* lo valida.
- **Postcondición:** `SECURITY.md` y `CHANGELOG_ABIS.md` presentes; cero enlaces a rutas inexistentes verificados en CI; HB-07 cerrado.
- **Cobertura:** RF-006 · HB-07 · D-011.

**Criterios Gherkin**
1. `ci_check_RF006_refs_rotas_cero` — **A IMPLEMENTAR (RF-006)**
   - **Dado** el árbol de documentación,
   - **Cuando** el *check* resuelve cada ruta enlazada,
   - **Entonces** no existe ningún enlace a `Token.sol`, `Identity.sol` ni a los `.md` inexistentes.
2. `ci_check_RF006_security_md_existe` — **A IMPLEMENTAR (RF-006)**
   - **Dado** el repositorio,
   - **Cuando** el CI busca `SECURITY.md`,
   - **Entonces** el archivo existe y no está vacío.
3. `ci_check_RF006_hallazgos_cubiertos` — **A IMPLEMENTAR (RF-006)**
   - **Dado** el listado HB-01..HB-12,
   - **Cuando** el CI busca cada identificador `HB-xx` en `SECURITY.md`,
   - **Entonces** los 12 aparecen al menos una vez.
4. `ci_check_RF006_changelog_abis_existe` — **A IMPLEMENTAR (RF-006)**
   - **Dado** el repositorio,
   - **Cuando** el CI busca `CHANGELOG_ABIS.md`,
   - **Entonces** existe y contiene al menos una sección de firmas.
5. `ci_check_RF006_abi_diff_automatico` — **A IMPLEMENTAR (RF-006)** (concretado, M-05)
   - **Dado** el job de CI con `forge` instalado y el ABI versionado en `abis/<Contrato>.json`,
   - **Cuando** un selector público cambie y el job ejecute `script/ci/abi_diff.sh`,
   - **Entonces** el script compara `forge inspect <Contrato> abi --json` contra `abis/<Contrato>.json` y falla con código != 0 si algún selector nuevo, modificado o eliminado no aparece en una sección de `CHANGELOG_ABIS.md`; la evidencia es la salida del job con la lista de selectores del diff.

**Restricciones EARS**
- `ci_check_RF006_mitigacion_con_test` — **Mientras** `SECURITY.md` declare una mitigación, el sistema deberá exigir que referencie al menos una función `test_*` o un `ci_check_*` existente. **A IMPLEMENTAR (RF-006)**
- `ci_check_RF006_docs_sin_placeholders` — **Si** un documento contiene un marcador sin sustituir, entonces el sistema deberá fallar el *check* de documentación. **A IMPLEMENTAR (RF-006)**

---

### CU-13 — Gestionar secretos de despliegue sin material en repositorios

- **Actor:** A7 (Desarrollador/CI) ejecutando `deploy-besu.sh`.
- **Objetivo:** Que el despliegue obtenga `PRIVATE_KEY` de variable de entorno / Secret Manager GCP y nunca de `~/.foundry/keys.json` ni de archivos versionados.
- **Estado:** **A IMPLEMENTAR (RF-010).** HOY `deploy-besu.sh:14,37` lee `~/.foundry/keys.json`.
- **Precondición:** Script `deploy-besu.sh` refactorizado; variable `DS_PRIVATE_KEY` (o equivalente) inyectada por el pipeline; `.env` en `.gitignore`.
- **Flujo principal:**
  1. El script lee `PRIVATE_KEY="${DS_PRIVATE_KEY:?secret no definido}"`.
  2. Valida que la variable no esté vacía y tenga formato `0x` + 64 hex.
  3. Ejecuta los despliegues con `--private-key "$PRIVATE_KEY"` (sin persistir a disco).
  4. No exporta la clave a archivos temporales ni la imprime en logs.
- **Flujos alternativos:**
  - A13.1 `DS_PRIVATE_KEY` ausente → el script aborta con mensaje y código != 0, sin intentar leer `keys.json`.
  - A13.2 Clave con formato inválido → aborta sin ejecutar `forge create`.
  - A13.3 `keys.json` presente en el entorno → el script lo ignora por completo (no lo abre).
  - A13.4 Clave impresa por `-vvvv`/logs → el *check* de secret-scan la detecta y falla el pipeline.
  - A13.5 Secreto versionado por error → `gitleaks`/`trufflehog` bloquea el commit.
- **Postcondición:** Ningún secreto en el repositorio ni en scripts; HB-12 cerrado; despliegue reproducible con la variable inyectada.
- **Cobertura:** RF-010 · RNF-004 · HB-12 · D-008.

**Criterios Gherkin**
1. `ci_check_RF010_script_sin_keys_json` — **A IMPLEMENTAR (RF-010)**
   - **Dado** el archivo `deploy-besu.sh`,
   - **Cuando** el CI busca referencias a `keys.json` o `~/.foundry/keys.json`,
   - **Entonces** no existe ninguna.
2. `ci_check_RF010_script_usa_env` — **A IMPLEMENTAR (RF-010)**
   - **Dado** el script refactorizado,
   - **Cuando** el CI busca la lectura de `DS_PRIVATE_KEY` (o `PRIVATE_KEY` de entorno),
   - **Entonces** la encuentra y no hay valores de clave literales.
3. `ci_check_RF010_secret_scan_sin_hallazgos` — **A IMPLEMENTAR (RF-010)**
   - **Dado** el árbol del repositorio,
   - **Cuando** el CI ejecuta el escáner de secretos,
   - **Entonces** el número de hallazgos es 0 y el pipeline pasa.
4. `ci_check_RF010_AbortSinSecreto` — **A IMPLEMENTAR (RF-010)**
   - **Dado** un entorno sin `DS_PRIVATE_KEY`,
   - **Cuando** se ejecuta `deploy-besu.sh`,
   - **Entonces** el script termina con código != 0 antes de cualquier `forge create`.
5. `ci_check_RF010_secret_manager_soportado` — **A IMPLEMENTAR (RF-010)** (concretado, M-05)
   - **Dado** un entorno con `gcloud` presente y un stub de `gcloud secrets versions access latest --secret=DS_PRIVATE_KEY` que devuelve `0x`+64 hex,
   - **Cuando** `deploy-besu.sh` arranca con `USE_SECRET_MANAGER=1` y **sin** `DS_PRIVATE_KEY` en el entorno,
   - **Entonces** el script exporta el valor solo en el proceso y completa `forge create`; el test de shell `test/ci/test_deploy_secret_manager.sh` intercepta la invocación a `gcloud` y comprueba que no se escribió ningún archivo temporal.

**Restricciones EARS**
- `ci_check_RF010_env_en_gitignore` — **Mientras** exista un archivo `.env`, el sistema deberá garantizar que está excluido por `.gitignore`. **A IMPLEMENTAR (RF-010)**
- `ci_check_RF010_sin_clave_en_logs` — **Cuando** el script falle, el sistema deberá emitir un mensaje de error sin incluir el valor ni parte de la clave privada. **A IMPLEMENTAR (RF-010)**
- `ci_check_RF010_clave_solo_efimera` — **Si** el script necesita persistir la clave para pasos posteriores, entonces el sistema deberá hacerlo solo en variable de proceso, nunca en disco. **A IMPLEMENTAR (RF-010)**

---

### CU-14 — Configurar los topics requeridos del token (extensibilidad de compliance)

- **Actor:** A1 (owner del `ClaimTopicsRegistry` del token) y A3 (evalúa impacto).
- **Objetivo:** Declarar qué topics de claim exige el token y actualizarlos sin redeployar el token ni los registries.
- **Estado:** **IMPLEMENTADO** (`ClaimTopicsRegistryCloneable.sol:36-60`; `TokenCloneable.setClaimTopicsRegistry` `:110-114`).
- **Precondición:** `ClaimTopicsRegistry` (o su variante por token) desplegado y vinculado al token vía `setClaimTopicsRegistry`.
- **Flujo principal:**
  1. A1 llama `addClaimTopic(topic)`.
  2. El contrato marca `claimTopicExists[topic] = true` y añade a `claimTopics`; emite `ClaimTopicAdded`.
  3. El token consume `getClaimTopics()` dentro de `isVerified`.
  4. Para retirar, A1 llama `removeClaimTopic(topic)`; el contrato borra el flag y hace *swap-and-pop*.
  5. A1 puede reasignar el registry del token con `setClaimTopicsRegistry(nuevo)` si necesita una política distinta.
- **Flujos alternativos:**
  - A14.1 `addClaimTopic` de un topic ya existente → revierte `"Claim topic already exists"`.
  - A14.2 `removeClaimTopic` de un topic inexistente → revierte `"Claim topic does not exist"`.
  - A14.3 Llamada desde una cuenta sin `owner` (o sin `DEFAULT_ADMIN_ROLE` en la variante por token) → revierte.
  - A14.4 `setClaimTopicsRegistry(address(0))` → revierte `"Invalid registry address"` (`TokenCloneable.sol:111`).
  - A14.5 Sustituir el registry por otro que exige más topics → `isVerified` de wallets antes válidas pasa a `false` (test de regresión).
- **Postcondición:** `getClaimTopics()` devuelve exactamente el conjunto vigente; el cambio altera `isVerified` de forma determinista sin tocar balances.
- **Cobertura:** RNF-005.
- **Nota (M-01/B-01):** no existe ninguna función `setClaimTopics(topics)` en el código (`grep -rn "setClaimTopics\b" rwa-sc/sc/src/` → solo `setClaimTopicsRegistry`); la mención previa se elimina. Los literales de revert son los reales de `ClaimTopicsRegistryCloneable.sol:37,49`.

**Criterios Gherkin**
1. `test_RNF005_addClaimTopic_ok` — **IMPLEMENTADO**
   - **Dado** un registry sin topics,
   - **Cuando** A1 llama `addClaimTopic(1)`,
   - **Entonces** `getClaimTopics()` es `[1]` y `claimTopicExists(1) == true`.
2. `test_RNF005_addClaimTopic_duplicado_revierte` — **IMPLEMENTADO**
   - **Dado** el topic 1 ya existente,
   - **Cuando** A1 repite `addClaimTopic(1)`,
   - **Entonces** revierte con `"Claim topic already exists"`.
3. `test_RNF005_removeClaimTopic_swap_and_pop` — **IMPLEMENTADO**
   - **Dado** topics `[1,7,9]`,
   - **Cuando** A1 llama `removeClaimTopic(1)`,
   - **Entonces** `getClaimTopics()` contiene `7` y `9` sin huecos.
4. `test_RNF005_cambio_topics_afecta_isVerified` — **IMPLEMENTADO**
   - **Dado** un token con registry de topics `[1]` y wallet verificada,
   - **Cuando** A1 añade el topic 7,
   - **Entonces** `isVerified(wallet)` pasa a `false` sin que cambien los balances.
5. `test_RNF005_nueva_regla_sin_redeploy_token` — **IMPLEMENTADO**
   - **Dado** un token con topics configurables,
   - **Cuando** A1 cambia el conjunto de topics,
   - **Entonces** la dirección del token y su bytecode no cambian y el nuevo requisito se aplica.

**Restricciones EARS**
- `test_RNF005_registry_topics_only_owner` — **Si** el emisor no es el owner del `ClaimTopicsRegistry`, entonces el sistema deberá revertir toda mutación de topics. **IMPLEMENTADO**
- `test_RNF005_set_claim_topics_registry_cero_revierte` — **Cuando** se intente asignar `address(0)` como `claimTopicsRegistry`, el sistema deberá revertir con `"Invalid registry address"`. **IMPLEMENTADO**
- `test_RNF005_agregar_modulo_sin_tocar_token` — **Mientras** el token no se modifique, el sistema deberá permitir añadir reglas nuevas vía módulos y aggregator. **IMPLEMENTADO**
- `test_RNF005_topics_persisten_entre_llamadas` — **Cuando** se consulten los topics en llamadas sucesivas, el sistema deberá devolver el mismo conjunto hasta la siguiente mutación. **IMPLEMENTADO**

---

### CU-15 — Cerrar el fail-open de `isVerified()` (RF-011 · H-05 auditoría V1)

- **Actor:** A1 (Admin/Owner configura los registries del token), A6 (Creador de token por factory), A4 (inversor/titular que resulta verificado o no); el resultado lo observa A8.
- **Objetivo:** Convertir `isVerified()` en **fail-closed**: sin `claimTopicsRegistry` configurado, o sin topics requeridos, ninguna wallet se considera verificada.
- **Estado:** **A IMPLEMENTAR (RF-011).** HOY `TokenCloneable.sol:245-247` devuelve `true` cuando `claimTopicsRegistry == address(0)`, de modo que toda wallet registrada en `IdentityRegistry` queda «verificada» sin ningún claim (H-05, auditoría V1; PoC `test_FailOpenNoClaimTopicsRegistry`). El token recién creado por `createToken` (ruta sin registries, `TokenCloneFactory.sol`) es el caso alcanzable más directo.
- **Precondición (tras RF-011):** `TokenCloneable` inicializado; `identityRegistry` configurado; para que `isVerified` pueda devolver `true` deben estar fijados `claimTopicsRegistry` con al menos un topic y `trustedIssuersRegistry`.
- **Flujo principal (tras RF-011):**
  1. Un consumidor (`mint`, `canTransfer`, `transfer`, `forcedTransfer`) consulta `isVerified(account)`.
  2. El contrato comprueba `identityRegistry != address(0)`, `isRegistered(account) == true` y `getIdentity(account) != address(0)` (igual que hoy).
  3. El contrato exige `claimTopicsRegistry != address(0)` y `getClaimTopics().length > 0`; si no, devuelve `false` (fail-closed).
  4. Para cada topic requerido busca un claim de emisor confiable (`getClaimIssuersForTopic` + `trustedIssuersRegistry.hasClaimTopic`) y exige que el claim sea válido y vigente (CU-17).
  5. Devuelve `true` solo si se cumplen 2–4 para **todos** los topics requeridos.
- **Flujos alternativos:**
  - A15.1 `claimTopicsRegistry == address(0)` → `isVerified` devuelve `false` (revierte el fail-open actual).
  - A15.2 `claimTopicsRegistry` fijado pero `getClaimTopics()` vacío → `isVerified` devuelve `false`.
  - A15.3 `trustedIssuersRegistry == address(0)` → `isVerified` devuelve `false` para toda wallet con topics requeridos (ya ocurre hoy).
  - A15.4 Token recién creado por factory sin registries → `isVerified` devuelve `false`; `mint`/`transfer` a esa wallet revierten por `"Recipient not verified"` / `"Transfer not compliant"`.
  - A15.5 Configuración incompleta corregida por A1 (`setClaimTopicsRegistry` + topics + claims) → `isVerified` vuelve a `true` de forma determinista (no hay bloqueo permanente).
- **Postcondición:** Ninguna wallet queda verificada si falta la política de topics; la semántica de `isVerified` es idéntica para token recién creado y token configurado; CU-09 A9.5 y el criterio `test_RF001_isVerified_sin_topics_registrada_true` quedan invertidos.
- **Cobertura:** RF-011 · H-05 (auditoría V1) · D-014.

**Criterios Gherkin**
1. `test_RF011_isVerified_sin_registry_topics_false` — **A IMPLEMENTAR (RF-011)**
   - **Dado** un token con `identityRegistry` fijado, `claimTopicsRegistry == address(0)` y una wallet registrada con identidad,
   - **Cuando** se consulta `isVerified(wallet)`,
   - **Entonces** devuelve `false` (hoy devuelve `true`; `TokenCloneable.sol:245-247`).
2. `test_RF011_isVerified_topics_vacios_false` — **A IMPLEMENTAR (RF-011)**
   - **Dado** un token con `claimTopicsRegistry` fijado pero `getClaimTopics()` vacío y una wallet registrada con identidad,
   - **Cuando** se consulta `isVerified(wallet)`,
   - **Entonces** devuelve `false` sin revertir.
3. `test_RF011_token_recien_creado_por_factory_no_verificado` — **A IMPLEMENTAR (RF-011)**
   - **Dado** un token creado con `TokenCloneFactory.createToken` (ruta sin registries) y una wallet registrada en su `IdentityRegistry`,
   - **Cuando** se consulta `isVerified(wallet)`,
   - **Entonces** devuelve `false` y `mint(wallet, 1)` revierte con `"Recipient not verified"`.
4. `test_RF011_configuracion_completa_verifica` — **A IMPLEMENTAR (RF-011)**
   - **Dado** un token fail-closed con topics `[1]`, un issuer confiable y un claim válido del topic 1 (CU-02),
   - **Cuando** A1 fija `claimTopicsRegistry` con el topic 1,
   - **Entonces** `isVerified(wallet)` pasa a `true` (la corrección no bloquea permanentemente).

**Restricciones EARS**
- `test_RF011_isVerified_registry_topics_cero_false` — **Mientras** `claimTopicsRegistry` del token sea `address(0)`, el sistema deberá devolver `false` en `isVerified` para toda wallet, sin revertir. **A IMPLEMENTAR (RF-011)**
- `test_RF011_isVerified_failclosed_por_defecto` — **Si** no hay topics requeridos (registry sin configurar o conjunto vacío), entonces el sistema deberá denegar por defecto (`false`) en lugar de permitir. **A IMPLEMENTAR (RF-011)**
- `test_RF011_mint_transfer_bloqueados_sin_politica` — **Cuando** falte la política de topics, el sistema deberá impedir `mint` y `transfer` hacia cualquier wallet registrada, de modo que el fail-open no sea alcanzable por ninguna vía. **A IMPLEMENTAR (RF-011)**

---

### CU-16 — `ComplianceAggregator` fail-closed y administración acotada por token (RF-012 · H-22 auditoría V1)

- **Actor:** A3 (Compliance Officer del token), A1 (Admin/Owner del token y del aggregator) y A6 (Creador de token); A8 observa.
- **Objetivo:** Denegar por defecto cuando no hay módulos de compliance y que **solo el owner/rol del token** administre los módulos de **ese** token.
- **Estado:** **A IMPLEMENTAR (RF-012).** HOY `ComplianceAggregator.canTransfer` devuelve `true` con cero módulos (`ComplianceAggregator.sol:115-135`, en particular `:123-125`) y el modifier `onlyOwnerOrToken` (`:50-53`) permite al **owner global** del aggregator añadir/quitar módulos de **cualquier** token (`:61`, `:87`). H-22, auditoría V1; PoC `test_AggregatorFailOpenNoModules`.
- **Precondición (tras RF-012):** aggregator añadido como módulo del token (CU-07); el token está **registrado explícitamente** en el aggregator; quien administra posee el rol del token.
- **Flujo principal (tras RF-012):**
  1. El token queda registrado explícitamente en el aggregator al añadir su primer módulo. El **mecanismo de registro explícito (p. ej. una función dedicada) es un diseño a definir en RF-012**: HOY `ComplianceAggregator.sol` **no tiene** ninguna función `registerToken` (grep `registerToken` en `rwa-sc/sc/src/` → 0 resultados); solo existe el estado privado `_isTokenRegistered` (`ComplianceAggregator.sol:38`), que `addModule` fija al insertar el primer módulo (`:67-70`) y que la vista `isTokenRegistered` expone en modo lectura (`:242-244`).
  2. A3 llama `addModuleThroughAggregator(aggregator, module)`; el token reenvía `ComplianceAggregator.addModule(address(this), module)` (CU-07).
  3. El aggregator valida que el emisor es el propio token/`owner()` **del token** (no un owner global ajeno) y las validaciones de módulo (`token != 0`, `module != 0`, `!isModuleActive`, `supportsInterface` de RF-003).
  4. `canTransfer(from,to,amount)`: si el token no está registrado o no tiene módulos activos → devuelve `false`; en otro caso exige `true` de **todos** los módulos.
  5. `removeModule`: el último módulo retirado deja al token sin reglas → `canTransfer` vuelve a `false`.
- **Flujos alternativos:**
  - A16.1 Token sin registrar o con cero módulos → `canTransfer` devuelve `false` (hoy `true`).
  - A16.2 Owner global del aggregator, sin rol sobre el token, intenta `addModule`/`removeModule` de un token ajeno → revierte con `"Only token admin can call"` — **propuesta (no existe hoy; llegará con RF-012)**. HOY el modifier real `onlyOwnerOrToken` (`ComplianceAggregator.sol:50-53`) **autoriza** al owner global y su literal vigente es `"Only owner or token can call"` (cita conservada; criterio `test_RF003_aggregator_only_owner_or_token`).
  - A16.3 Módulo ya activo → revierte `"Module already added"`.
  - A16.4 `removeModule` de módulo inactivo → revierte `"Module not active"`.
  - A16.5 Token registrado con módulos activos que devuelven `true` → `canTransfer` devuelve `true` (no se rompe el camino feliz).
- **Postcondición:** `canTransfer` deniega si faltan reglas; la administración de módulos de cada token queda acotada a su owner/rol; `getModuleCount(token)`, `isModuleActiveForToken` y `isTokenRegistered` reflejan la composición vigente.
- **Cobertura:** RF-012 · H-22 (auditoría V1) · D-014.

**Criterios Gherkin**
1. `test_RF012_aggregator_sin_modulos_revierte_transfer` — **A IMPLEMENTAR (RF-012)**
   - **Dado** un token registrado en el aggregator con cero módulos activos,
   - **Cuando** el token invoca `canTransfer(from,to,amount)`,
   - **Entonces** el aggregator devuelve `false` (hoy devuelve `true`; `ComplianceAggregator.sol:123-125`) y la transferencia revierte por `"Transfer not compliant"`.
2. `test_RF012_aggregator_token_no_registrado_false` — **A IMPLEMENTAR (RF-012)**
   - **Dado** un `msg.sender` token no registrado en el aggregator,
   - **Cuando** invoca `canTransfer`,
   - **Entonces** devuelve `false` (denegación por defecto).
3. `test_RF012_aggregator_admin_del_token_ok` — **A IMPLEMENTAR (RF-012)**
   - **Dado** el owner/rol del token `T`,
   - **Cuando** añade un módulo con `addModule(T, module)`,
   - **Entonces** `isModuleActiveForToken(T,module) == true` y `getModuleCount(T) == 1`.
4. `test_RF012_aggregator_owner_global_token_ajeno_revierte` — **A IMPLEMENTAR (RF-012)**
   - **Dado** una cuenta que es `owner()` del aggregator pero **no** owner/rol del token `T`,
   - **Cuando** llama `addModule(T,module)` o `removeModule(T,module)`,
   - **Entonces** revierte con `"Only token admin can call"` — **propuesta (no existe hoy; llegará con RF-012)**: el literal vigente del modifier es `"Only owner or token can call"` (`ComplianceAggregator.sol:50-53`), que hoy **autoriza** al owner global; RF-012 debe restringirlo al owner/rol del token — y la composición de `T` no cambia.
5. `test_RF012_aggregator_modulos_todos_true_ok` — **A IMPLEMENTAR (RF-012)**
   - **Dado** un token registrado con dos módulos que devuelven `true`,
   - **Cuando** el token invoca `canTransfer`,
   - **Entonces** devuelve `true`; si uno devuelve `false`, devuelve `false`.

**Restricciones EARS**
- `test_RF012_aggregator_failclosed_por_defecto` — **Mientras** no haya módulos activos para el token solicitante, el sistema deberá devolver `false` en `canTransfer` (fail-closed). **A IMPLEMENTAR (RF-012)**
- `test_RF012_agregar_modulo_sin_tocar_token_holder` — **Cuando** se añada un módulo por la vía autorizada, el sistema deberá hacerlo sin modificar la dirección ni el bytecode del token (RNF-005). **A IMPLEMENTAR (RF-012)**
- `test_RF012_retirar_ultimo_modulo_bloquea` — **Si** se retira el último módulo activo de un token, entonces el sistema deberá pasar a denegar sus transferencias. **A IMPLEMENTAR (RF-012)**

---

### CU-17 — Ciclo de vida del claim: vigencia y revocación por el issuer (RF-013 · H-08 auditoría V1)

- **Actor:** A5 (Issuer confiable que emite, fija vigencia y revoca), A4 (inversor/titular que solicita y renueva), A1 (admin que observa); A8 verifica.
- **Objetivo:** Dotar al claim de **vigencia** (`expiresAt`) y **revocación autorizada por el issuer**, y hacer que `isVerified` deje de aceptar claims vencidos o revocados.
- **Estado:** **A IMPLEMENTAR (RF-013).** HOY el struct `Claim` solo tiene `{topic, scheme, issuer, signature, data, uri}` sin vigencia ni estado de revocación (`IdentityCloneable.sol:21-28`); `removeClaim` es `onlyOwner` del **titular** (`:105-123`), de modo que el propio inversor decide si su claim sigue vigente; `isVerified` no comprueba caducidad (`TokenCloneable.sol:249-281`). `IdentityCloneable` **no tiene** `revokeClaim` ni ningún campo `expiresAt`/`revoked` (grep `revokeClaim|expiresAt|revoked` en `rwa-sc/sc/src/` → 0 resultados). H-08, auditoría V1.
- **Precondición (tras RF-013):** `IdentityCloneable` inicializado; issuer autorizado para el topic (CU-01/CU-02); claim emitido con `expiresAt`; para la revocación, el claim existe.
- **Flujo principal (tras RF-013):**
  1. `addClaim` persiste el claim con `expiresAt` (parámetro o política del issuer) y `revoked = false`; emite `ClaimAdded` incluyendo la vigencia.
  2. A5 (el propio `claim.issuer`) llama `revokeClaim(topic, issuer)`; el contrato exige `msg.sender == claim.issuer` y `claimExists == true`.
  3. El contrato marca `revoked = true`, conserva el histórico y emite `ClaimRevoked(topic, issuer, timestamp)`.
  4. `isVerified` acepta un claim solo si `revoked == false` y `block.timestamp < expiresAt`; si hay varios issuers para el topic, basta uno vigente y confiable.
  5. Renovación: un nuevo `addClaim` del mismo `(topic,issuer)` con firma válida actualiza `expiresAt` y reactiva `revoked = false` (**D-018**, CU-03 A3.6).
- **Flujos alternativos:**
  - A17.1 Claim con `block.timestamp >= expiresAt` → `isVerified` devuelve `false` para ese claim.
  - A17.2 Claim con `revoked == true` → `isVerified` devuelve `false`.
  - A17.3 `revokeClaim` desde una cuenta distinta de `claim.issuer` → revierte `"Only issuer can revoke"` — **propuesta (no existe hoy; llegará con RF-013)**: HOY no existe la función `revokeClaim` (`IdentityCloneable.sol` solo expone `removeClaim`, `onlyOwner` del titular, `:105-123`) ni el campo `expiresAt` (`:21-28`).
  - A17.4 `revokeClaim` de un claim inexistente → revierte `"Claim does not exist"`.
  - A17.5 El titular conserva `removeClaim` (onlyOwner) pero **no** puede reactivar ni alterar la vigencia fijada por el issuer sin una nueva firma válida.
- **Postcondición:** Ningún claim vencido o revocado habilita `isVerified`; la revocación es granular por `(topic, issuer)` y trazable por evento; la renovación es posible sin redeploy (D-018).
- **Cobertura:** RF-013 · H-08 (auditoría V1) · D-014 · D-018.

**Criterios Gherkin**
1. `test_RF013_claim_vigente_isVerified_true` — **A IMPLEMENTAR (RF-013)**
   - **Dado** un token con topic requerido `[1]` y un claim del issuer confiable con `expiresAt` futuro y `revoked == false`,
   - **Cuando** se consulta `isVerified(wallet)`,
   - **Entonces** devuelve `true`.
2. `test_RF013_claim_expirado_isVerified_false` — **A IMPLEMENTAR (RF-013)**
   - **Dado** un claim con `expiresAt <= block.timestamp` (`vm.warp`),
   - **Cuando** se consulta `isVerified(wallet)`,
   - **Entonces** devuelve `false` y `transfer` desde esa wallet revierte por `"Transfer not compliant"`.
3. `test_RF013_claim_revocado_por_issuer_isVerified_false` — **A IMPLEMENTAR (RF-013)**
   - **Dado** un claim vigente y su issuer autorizado,
   - **Cuando** el issuer llama `revokeClaim(1, issuer)`,
   - **Entonces** `getClaim` refleja `revoked == true`, se emite `ClaimRevoked` y `isVerified(wallet)` pasa a `false`.
4. `test_RF013_revocar_solo_issuer_revierte` — **A IMPLEMENTAR (RF-013)**
   - **Dado** un claim del issuer A5 y una cuenta distinta (incluido el titular A4),
   - **Cuando** intenta `revokeClaim`,
   - **Entonces** revierte con `"Only issuer can revoke"` — **propuesta (no existe hoy; llegará con RF-013)**; la función `revokeClaim` todavía no existe en `IdentityCloneable` (sin `revokeClaim` ni `expiresAt`/`revoked`, `IdentityCloneable.sol:21-28,105-123`) — y el claim permanece vigente.
5. `test_RF013_renovacion_actualiza_vigencia` — **A IMPLEMENTAR (RF-013)**
   - **Dado** un claim expirado o revocado de `(1,A5)`,
   - **Cuando** A5 firma y se reintenta `addClaim` con nueva vigencia (D-018),
   - **Entonces** `expiresAt` se actualiza, `revoked == false` y `isVerified(wallet)` vuelve a `true`.

**Restricciones EARS**
- `test_RF013_isVerified_rechaza_vencidos` — **Mientras** `block.timestamp >= expiresAt` del único claim de un topic requerido, el sistema deberá rechazar ese claim en `isVerified`. **A IMPLEMENTAR (RF-013)**
- `test_RF013_revocacion_emite_evento_y_conserva_historico` — **Cuando** el issuer revoque un claim, el sistema deberá emitir `ClaimRevoked` sin borrar el histórico de `ClaimAdded`. **A IMPLEMENTAR (RF-013)**
- `test_RF013_revocacion_no_reactivable_por_titular` — **Si** el titular intenta reactivar un claim revocado sin una nueva firma del issuer, entonces el sistema deberá mantenerlo rechazado. **A IMPLEMENTAR (RF-013)**

---

## 2.5 Decisiones D-012 y D-013 (cerradas en v1.2)

| ID | Caso | Pregunta | Alternativas | Estado |
|---|---|---|---|---|
| **D-012** | CU-10 | ¿El `mint` debe seguir exigiendo compliance (`canTransfer`) o permitir bypass acotado para el agente? | **(A) compliant siempre — ELEGIDA** (criterios Gherkin `test_RF002_mint_llama_canTransfer_revierte` + EARS `test_RF002_mint_sin_modulos_ok`); (B) bypass de agente — **DESCARTADA** | **RESUELTA** por el usuario, registrada como **D-016** en `requerimientos.md` §6 |
| **D-013** | CU-03 (A3.6) | Política de replay al reintentar el mismo `(topic, issuer)`: ¿rechazar el reintento o sobreescribir solo con firma válida? | (A) rechazar replay — **DESCARTADA**; **(B) sobrescribir solo si la firma es válida y `recovered == issuer` — ELEGIDA** (permite renovar) | **RESUELTA** por el usuario, registrada como **D-018** en este documento |

> **D-016 (cierre de D-012):** `mint()` mantiene el chequeo de compliance; la alternativa B (bypass del agente) fue **descartada por decisión del usuario**. Los criterios de la alternativa A son los vigentes en CU-10.
> **D-018 (cierre de D-013):** al reintentar un claim para el mismo par `(topic, issuer)` con firma válida se **sobrescribe** el claim existente, lo que permite renovarlo; si la firma no es válida no hay sobrescritura (CU-03 A3.6). Decisión del usuario; cierra la antigua D-013.
> Ambas decisiones forman parte ya de las decisiones aprobadas: no queda ninguna decisión **abierta** en este documento.

---

## 3. Matriz de trazabilidad

> **Criterio M-03:** cada fila se apoya en al menos un criterio concreto del CU. Se eliminaron los mappings sin respaldo (RF-005→CU-07, RNF-005→CU-09/CU-10, RF-003→CU-10, HB-05→CU-07/CU-08, HB-04→CU-10, HB-01→CU-14).

### 3.1 Requisitos funcionales → Casos de uso

| Requisito | Descripción breve | CU que lo cubren | Criterio de respaldo (ejemplo) | Estado |
|---|---|---|---|---|
| RF-001 | Verificación EIP-712 del claim + issuer autorizado | CU-01, CU-02, CU-03, CU-09 | `test_RF001_addClaim_con_firma_valida`; `hasClaimTopic` | ⚠️ Parcial — **A IMPLEMENTAR (RF-001)** |
| RF-002 | Retirar `bypassCompliance` + reentrancia + forcedTransfer acotado | CU-04, CU-06, CU-10 | `test_RF002_forcedTransfer_destino_autorizado_ok`; `ci_check_RF002_no_bypassCompliance_storage` | ⚠️ **A IMPLEMENTAR (RF-002)** |
| RF-003 | Validar `supportsInterface(ICompliance)` | CU-05, CU-07 | `test_RF003_addComplianceModule_valida_erc165_ok` | ⚠️ **A IMPLEMENTAR (RF-003)** |
| RF-004 | Whitelist de destinos + `maxBurnPerTx`/`maxForcedPerTx` | CU-06 | `test_RF004_burn_excede_limite_revierte` | ⚠️ **A IMPLEMENTAR (RF-004)** |
| RF-005 | Compilación reproducible (`forge build`/`forge test` 100%) | CU-08, CU-11 | `ci_check_RF005_forge_build_ok`; `test_RF005_createTokenWithRegistries_clon_ok` | ⚠️ **A IMPLEMENTAR (RF-005)** |
| RF-006 | Docs sin referencias rotas + `SECURITY.md` + `CHANGELOG` ABIs | CU-12 | `ci_check_RF006_refs_rotas_cero` | ⚠️ **A IMPLEMENTAR (RF-006)** |
| RF-007 | Unificar/retirar `web-registry-trusted2` | — | — | ⛔ **Sin CU — fuera de alcance (D-003, zona web)** |
| RF-008 | Fuente única de verdad para direcciones | — | — | ⛔ **Sin CU — fuera de alcance (D-003, zona web)** |
| RF-009 | CI GitLab `build` + `test` + `coverage` ≥ 80% | CU-11 | `ci_check_RNF002_coverage_mayor_igual_80` | ⚠️ **A IMPLEMENTAR (RF-009)** |
| RF-010 | Secretos fuera de scripts (`PRIVATE_KEY` por entorno/Secret Manager) | CU-13 | `ci_check_RF010_script_sin_keys_json` | ⚠️ **A IMPLEMENTAR (RF-010)** |
| RF-011 | `isVerified()` fail-closed sin `claimTopicsRegistry`/topics | CU-15 | `test_RF011_isVerified_sin_registry_topics_false` | ⚠️ **A IMPLEMENTAR (RF-011)** |
| RF-012 | `ComplianceAggregator` fail-closed + administración acotada por token | CU-16 | `test_RF012_aggregator_sin_modulos_revierte_transfer`; `test_RF012_aggregator_owner_global_token_ajeno_revierte` | ⚠️ **A IMPLEMENTAR (RF-012)** |
| RF-013 | Ciclo de vida del claim: vigencia + revocación por el issuer | CU-17 | `test_RF013_claim_expirado_isVerified_false`; `test_RF013_claim_revocado_por_issuer_isVerified_false` | ⚠️ **A IMPLEMENTAR (RF-013)** |

### 3.2 Requisitos no funcionales → Casos de uso

| Requisito | Descripción breve | CU que lo cubren | Criterio de respaldo (ejemplo) | Estado |
|---|---|---|---|---|
| RNF-001 | Ahorros de gas EIP-1167 (94–98%) mantenidos/mejorados | CU-08 | `test_RNF001_gas_clone_menor_que_deploy_completo` | ⚠️ Parcial — criterio de gas **a reescribir** |
| RNF-002 | Cobertura ≥ 80% (`forge coverage`) sobre `src/` **excluyendo** `src/ICompliance.sol`, `src/IClaimTopicsRegistry.sol` y `test/` (D-017) | CU-11 | `ci_check_RNF002_coverage_mayor_igual_80` | ⚠️ **A IMPLEMENTAR** (hoy 42,86%) |
| RNF-003 | 100% tests pasando en CI antes del merge | CU-11 | `ci_check_RF009_pipeline_test_exit_0` / `ci_check_RNF003_bloqueo_merge_con_fallos` | ⚠️ **A IMPLEMENTAR** |
| RNF-004 | Ningún secreto en repos/scripts | CU-13 | `ci_check_RF010_secret_scan_sin_hallazgos` | ⚠️ **A IMPLEMENTAR** |
| RNF-005 | Reglas de compliance extensibles sin tocar el token | CU-07, CU-14 | `test_RF003_addModuleThroughAggregator_ok`; `test_RNF005_nueva_regla_sin_redeploy_token` | ✅ Parcialmente IMPLEMENTADO |
| RNF-006 | Apps web con `docker compose up` | — | — | ⛔ **Sin CU — no aplica (D-003, zona web)** |

### 3.3 Hallazgos → Casos de uso

| Hallazgo | CU que lo resuelven |
|---|---|
| HB-01 | CU-01, CU-02, CU-03, CU-09 |
| HB-02 | CU-06 |
| HB-03 | CU-04, CU-10 |
| HB-04 | CU-05, CU-07 |
| HB-05 (análisis base — `lib/` ausente) | CU-11 |
| HB-06 | CU-08 (eliminación de storage muerto) |
| HB-07 | CU-12 |
| HB-08 (análisis base — `web-registry-trusted2`) | — (⛔ fuera de alcance, zona web) |
| HB-09 | — (⛔ fuera de alcance, zona web) |
| HB-10 | CU-11 |
| HB-11 | CU-11 |
| HB-12 | CU-13 |
| **H-05 (auditoría V1)** | CU-15 (`isVerified` fail-open sin `claimTopicsRegistry`) |
| **H-08 (auditoría V1)** | CU-17 (claims sin vigencia ni revocación por el issuer) |
| **H-22 (auditoría V1)** | CU-16 (`ComplianceAggregator` fail-open y owner global) |

### 3.4 Requisitos sin cobertura (declaración explícita)

- **RF-007** — *Unificar o retirar `web-registry-trusted2`*: **sin caso de uso**. Pausado por **D-003** (zona `rwa-web` fuera de este ciclo).
- **RF-008** — *Fuente única de verdad para direcciones de contratos*: **sin caso de uso**. Pausado por **D-003**.
- **RNF-006** — *Apps web con `docker compose up`*: **sin caso de uso**. No aplica este ciclo por **D-003**.

No hay ningún otro RF/RNF huérfano: **RF-001..RF-006, RF-009, RF-010, RF-011, RF-012, RF-013** y **RNF-001..RNF-005** quedan cubiertos por al menos un CU con criterio de respaldo.

---

## 4. Resumen de criterios y anclaje de test

- **17 casos de uso** (CU-01..CU-17; conteo real: `grep -cE '^### CU-[0-9]+'` = 17). Criterios finales contados sobre este archivo:
  - **92 criterios Gherkin** (ítems numerados `N. \`test_*\`` / `N. \`ci_check_*\``: `grep -cE '^[0-9]+\. \`(test_|ci_check_)'` = 92; 3 líneas Dado/Cuando/Entonces por criterio = 276 líneas).
  - **50 restricciones EARS** (viñetas EARS `- \`test_*\`` / `- \`ci_check_*\``: `grep -cE '^- \`(test_|ci_check_)'` = 50; reparto por palabra clave: 15 Mientras, 19 Si y 16 Cuando).
  - **142 criterios totales** (92 + 50). Estas cifras sustituyen a los 77 Gherkin + 41 EARS = 118 de v1.1/v1.2 (y a los 66 + 52 = 118 de v1.0, de donde proceden tras la reclasificación M-02) y salen de ejecutar los conteos sobre este archivo final.
- Cada criterio Gherkin y cada restricción EARS declara su artefacto de verificación: función `test_*` de Foundry, `ci_check_*` de pipeline o inspección de estado (`forge inspect`, `cast call`).
- Convención de nombres: `test_RF00X_<caso>_<condición>` / `test_RNF00X_<caso>_<condición>` / `ci_check_<ID>_<caso>`.
- Los CU de documentación y secretos (CU-12, CU-13) se verifican con *checks* automáticos de CI, no con inspección manual: se cumple la regla de testabilidad.
- Los CU de contratos (CU-01..CU-10 y CU-14..CU-17) se verifican con tests Foundry sobre los contratos reales de `rwa-sc/sc/src/` y `rwa-sc/sc/src/compliance/`.
- **Etiquetas de estado:** los criterios `IMPLEMENTADO` pueden ejecutarse contra el código actual; los `A IMPLEMENTAR (RF-00x)` describen la especificación de la mejora y deben escribirse al implementar el RF correspondiente.
- **Decisiones cerradas en v1.2 (reafirmadas en v1.3):** **D-012** (comportamiento de `mint` frente a compliance) quedó **RESUELTA** por **D-016** (alternativa A —*compliant siempre*—; la alternativa B fue descartada) y **D-013** (política de replay de claims) quedó **RESUELTA** y registrada como **D-018** (sobrescritura/renovación con firma válida). **D-012 y D-013 están CERRADAS y no quedan decisiones abiertas que bloqueen el cierre de criterios ni la Fase 3.**
