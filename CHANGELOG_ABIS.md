# CHANGELOG de ABIs — `rwa-sc`

> Registro de cambios incompatibles (breaking) en las interfaces públicas de los contratos de
> `rwa-sc/sc/src/`. Cada entrada indica el contrato, la firma anterior, la nueva, el selector y el
> impacto en consumidores (`rwa-web`, scripts, índices de eventos).
>
> **Regla:** las ABIs de `rwa-web/*/contracts/*.abi.json` son copias estáticas del contrato; tras
> cualquier entrada de este changelog deben **regenerarse** desde `sc/out/` (`forge build`) y volver
> a desplegarse/actualizarse los clientes. `rwa-web` está fuera del alcance de los ciclos actuales
> (D-003), por lo que aquí solo se documenta el cambio y su impacto.

## Historial

| Fecha | Ciclo | Requisito | Contratos afectados | Breaking |
|---|---|---|---|---|
| 2026-10-10 | Ciclo 2 | RF-001 (cierra H-01) | `IdentityCloneable`, `IdentityCloneFactory` | **Sí** |
| 2026-10-10 | Ciclo 4 | RF-003 (cierra H-17/HB-04) | `ICompliance`, `ComplianceAggregator`, `MaxBalanceCompliance`, `MaxHoldersCompliance`, `TransferLockCompliance`, `TokenCloneable` | **No (aditivo)**; rompe a implementadores de módulos |
| 2026-10-10 | Ciclo 8 | RF-013 (cierra H-08 auditoría V1) | `IdentityCloneable`, `IdentityRegistry` | **Sí** (`getClaim` añade salida; `revokeClaim`/`hasValidClaim`/`ClaimRevoked` son aditivos) |
| 2026-10-11 | Ciclo 8c | RF-013 (cierra el bypass de revocación por replay) | `IdentityCloneable` | **Sí off-chain**: `CLAIM_TYPEHASH` gana `uint256 nonce`; nueva vista `claimNonce(uint256,address)` (aditiva); el digest firmado cambia |
| 2026-10-11 | Ciclo 10 | RF-006 (cierra H-15/H-16/H-23/H-33) | — (ningún contrato de `src/`) | **No**: añade la línea base `sc/abis/` (15 ABIs) y el gate `script/ci/abi_diff.sh` |
| 2026-10-11 | Fase 4 (cierre) | AF-03 y AF-05 (auditoría adversarial final, decisiones del usuario) | `IdentityCloneable` (typehash/digest y `uri`), `TokenCloneable` (fail-closed sin módulos) | **Sí off-chain** (AF-03: el `CLAIM_TYPEHASH` gana `bytes32 uriHash`); **AF-05 sin cambio de ABI/firma** |

---

## RF-001 — Verificación criptográfica EIP-712 del claim (Ciclo 2)

**Motivo:** `addClaim` aceptaba claims sin verificar la firma (H-01, crítica: claims auto-forjados).
Ahora exige una firma **EIP-712** válida del `issuer` y añade `expiresAt` al claim (D-020, D-025).

### `IdentityCloneable.addClaim`

| | |
|---|---|
| **Antes** | `addClaim(uint256 _topic, uint256 _scheme, address _issuer, bytes _signature, bytes _data, string _uri) returns (bytes32)` |
| **Después** | `addClaim(uint256 _topic, uint256 _scheme, address _issuer, bytes _signature, bytes _data, string _uri, uint256 _expiresAt) returns (bytes32)` |
| **Selector antes** | `0xb1a34e0d` |
| **Selector después** | `0x16cd5ffe` |
| **Breaking** | Sí — se añade el parámetro `_expiresAt` (firmado y almacenado). |

Nuevas validaciones (revienten con estos literales):

- `"Unsupported scheme"` — `_scheme != 1`.
- `"Invalid issuer address"` — `_issuer == address(0)`.
- `"Invalid signature length"` — `_signature.length != 65`.
- `"Invalid signature"` — `ECDSA.tryRecover` devuelve `address(0)` (firma malformada, `v` inválido o `s` alto/maleable).
- `"Signature signer mismatch"` — la firma recupera una dirección distinta de `_issuer`.

Digest firmado por el issuer (EIP-712):

```
domain     = {name: "RWA-Identity", version: "1", chainId, verifyingContract: <dirección del clon>}
typeHash   = keccak256("Claim(address walletOwner,uint256 topic,uint256 scheme,bytes32 dataHash,uint256 expiresAt)")
structHash = keccak256(abi.encode(typeHash, walletOwner, topic, scheme, keccak256(data), expiresAt))
digest     = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash))
```

> **Obsoleto desde el Ciclo 8c:** este `typeHash` es el **histórico** de RF-001; el vigente añade
> `uint256 nonce` (ver la sección «RF-013 · Nonce firmado anti-replay (Ciclo 8c)» al final). Un firmante
> que use el typehash de este bloque produce un digest inválido.

`walletOwner` es el `owner()` de la identidad en el momento del `addClaim` (anti-replay entre titulares).
La autorización del `issuer` **para el topic** no se comprueba en este contrato (D-025): la impone
`TokenCloneable.isVerified` contra el `TrustedIssuersRegistry` del token.

### `IdentityCloneFactory.createIdentityWithClaim`

| | |
|---|---|
| **Antes** | `createIdentityWithClaim(address owner, uint256 topic, uint256 scheme, address issuer, bytes signature, bytes data, string uri) returns (address)` |
| **Después** | `createIdentityWithClaim(address owner, uint256 topic, uint256 scheme, address issuer, bytes signature, bytes data, string uri, uint256 expiresAt) returns (address)` |
| **Selector antes** | `0x8d6e23de` |
| **Selector después** | `0xaa57cd9f` |
| **Breaking** | Sí — propaga `expiresAt` a `IdentityCloneable.addClaim`. |

> Nota (D-027): el clon se inicializa con la factory como `owner` temporal para poder invocar
> `addClaim` (onlyOwner); por tanto, en esta ruta el `walletOwner` firmado es la **dirección de la
> factory**. El anti-replay entre identidades lo garantiza `verifyingContract` (único por clon).

### Struct `Claim` y `getClaim`

| | |
|---|---|
| **Antes** | `Claim { uint256 topic; uint256 scheme; address issuer; bytes signature; bytes data; string uri; }` |
| **Después** | `Claim { uint256 topic; uint256 scheme; address issuer; bytes signature; bytes data; string uri; uint256 expiresAt; }` |
| **`getClaim` selector** | `0x48e6b5a3` (el selector no cambia; **sí cambian las salidas**) |
| **Salidas antes** | `(uint256 topic, uint256 scheme, address issuer, bytes signature, bytes data, string uri)` |
| **Salidas después** | `(uint256 topic, uint256 scheme, address issuer, bytes signature, bytes data, string uri, uint256 expiresAt)` |
| **Breaking** | Sí — clientes que decodifican el retorno de 6 campos fallarán. |

### Evento `ClaimAdded`

| | |
|---|---|
| **Antes** | `ClaimAdded(uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri)` — topic0 `0xf825f7a3` |
| **Después** | `ClaimAdded(uint256 indexed topic, uint256 scheme, address indexed issuer, bytes signature, bytes data, string uri, uint256 expiresAt)` — topic0 `0xb3317b4f` |
| **Breaking** | Sí — para índices/subgraphs y filtros de eventos. |

### API nueva (no breaking)

- `CLAIM_TYPEHASH() view returns (bytes32)` — typehash público para que el firmante y los clientes
  construyan el digest sin duplicar el literal.

### Impacto en `rwa-web` (D-003: fuera de alcance, requiere trabajo posterior)

ABIs estáticas con las firmas antiguas que **quedarán obsoletas** y deben regenerarse:

- `rwa-web/web-identity/contracts/IdentityCloneable.abi.json` — `addClaim` (6 params) y `getClaim` (6 salidas).
- `rwa-web/web-identity/contracts/IdentityCloneFactory.abi.json` — `createIdentityWithClaim` (7 params).
- `rwa-web/web-identity/lib/identity-claims.ts` — tipo del claim y `addClaimToIdentity` (construye la
  transacción con los parámetros antiguos y no firma EIP-712).
- `rwa-web/web-identity/components/ClaimRequestsList.tsx`, `RequestDetailModal.tsx` y
  `app/app/page.tsx` — consumen el claim/evento y la lista de claims.
- Cualquier indexador o listener de `ClaimAdded` debe actualizar el topic0 y el número de campos.

Acción requerida (cuando se retome la zona web, p. ej. RF-007/RF-008):

1. `forge build` en `rwa-sc/sc/` y copiar las ABIs desde `sc/out/`.
2. Añadir `expiresAt` a las llamadas de `addClaim`/`createIdentityWithClaim`.
3. Implementar la firma EIP-712 en el cliente (viem `signTypedData`/ethers `signTypedData`) con el
   dominio `RWA-Identity`/`1`/`chainId`/`verifyingContract = identidad del titular`.

---

## RF-003 — Validación ERC-165 de módulos de compliance (Ciclo 4)

**Motivo:** `addComplianceModule`/`addModule` aceptaban cualquier dirección como módulo de compliance;
un contrato sin `canTransfer`/`transferred`/`created`/`destroyed` rompía la ruta de transferencia
(H-17/HB-04). Ahora `ICompliance` hereda `IERC165` y toda alta valida `supportsInterface`.

### ABI: función nueva `supportsInterface(bytes4) returns (bool)`

| Contrato | Firma nueva | Selector |
|---|---|---|
| `ICompliance` (interfaz, `is IERC165`) | `supportsInterface(bytes4) returns (bool)` | `0x01ffc9a7` |
| `MaxBalanceCompliance` | idem (heredada de `ERC165`) | `0x01ffc9a7` |
| `MaxHoldersCompliance` | idem | `0x01ffc9a7` |
| `TransferLockCompliance` | idem | `0x01ffc9a7` |
| `ComplianceAggregator` | idem | `0x01ffc9a7` |

`type(ICompliance).interfaceId` **no cambia** al heredar `IERC165` (Solidity excluye las funciones
heredadas): sigue siendo el XOR de `canTransfer`, `transferred`, `created` y `destroyed`.

### Firmas existentes

- `TokenCloneable.addComplianceModule(address)` — sin cambios en la firma; **sí** cambia el
  comportamiento (rechaza EOA/contrato no conforme y duplicados).
- `ComplianceAggregator.addModule(address,address)` — sin cambios en la firma; valida ERC-165.
- `ComplianceAggregator.supportsInterface` es necesario porque el aggregator también se registra como
  módulo del token (`token.addComplianceModule(aggregator)`).

### Impacto / breaking

- **Llamadas (consumidores):** no breaking; se añade una función de consulta estándar.
- **Implementadores de módulos (terceros):** **breaking**. Un módulo que no implemente
  `supportsInterface` no puede registrarse (`"Module does not implement ICompliance"`).
- **Módulos ya desplegados antes del Ciclo 4:** al no implementar ERC-165, no pueden volver a darse de
  alta. Sin proxy actualizable (D-019), el ciclo de vida es **redeploy limpio** (D-037): volver a
  desplegar el módulo con `supportsInterface`, sustituir el `ComplianceAggregator` si aplica y
  re-registrar los módulos por token.
- ABIs de `rwa-web` (D-003, fuera de alcance): si alguna app registra módulos de compliance, debe
  regenerar la ABI desde `sc/out/` y comprobar que el módulo objetivo declara
  `supportsInterface(type(ICompliance).interfaceId) == true`.

---

> Este archivo se ampliará en el Ciclo 10 / RF-006 (documentación, `SECURITY.md` y
> `script/ci/abi_diff.sh`) con el resto de cambios de ABI y el procedimiento de verificación del diff.

## Ciclo 5 — RF-004 (whitelist de destinos, límites y tope de suministro)

**Nuevas funciones en `TokenCloneable`** (ABI aditiva; las firmas existentes no cambian):

| Función | Selector | Autorización |
|---|---|---|
| `setAuthorizedDestination(address,bool)` | (calcular con `cast sig`) | `DEFAULT_ADMIN_ROLE` o `COMPLIANCE_ROLE` |
| `setMaxBurnPerTx(uint256)` | — | `DEFAULT_ADMIN_ROLE` o `COMPLIANCE_ROLE` |
| `setMaxForcedPerTx(uint256)` | — | `DEFAULT_ADMIN_ROLE` o `COMPLIANCE_ROLE` |
| `setMaxSupply(uint256)` | — | `DEFAULT_ADMIN_ROLE` |

**Nuevas vistas públicas:** `authorizedDestinations(address)`, `maxBurnPerTx()`, `maxForcedPerTx()`, `maxSupply()`.

**Nuevos eventos:** `DestinationAuthorized(address indexed destination, bool authorized)`,
`LimitsUpdated(uint256 maxBurnPerTx, uint256 maxForcedPerTx)`, `MaxSupplyUpdated(uint256 maxSupply)`.

**Cambios de comportamiento (no de firma):**
- `burn(from, amount)` **revierte** con `"Exceeds max burn per tx"` si `maxBurnPerTx == 0` o `amount > maxBurnPerTx`.
- `forcedTransfer(from, to, amount)` **revierte** con `"Destination not authorized"` si `to` no está autorizado y con
  `"Exceeds max forced transfer per tx"` si `maxForcedPerTx == 0` o `amount > maxForcedPerTx`.
- `mint(to, amount)` **revierte** con `"Max supply exceeded"` si `maxSupply > 0` y se excedería.

> **Impacto en `rwa-web` (fuera de alcance por D-003):** el flujo de la app debe configurar la whitelist y los topes
> antes de usar `burn`/`forcedTransfer`; con los valores por defecto (`0`) esas operaciones están desactivadas
> (fail-closed). No hay cambios de firma, así que las ABIs de las apps siguen siendo válidas, pero el
> comportamiento operativo cambia (requiere configuración previa).

> **Reproducibilidad (Ciclo 5):** `foundry.toml` fija `[fuzz] seed`, lo que hace determinista el baseline de gas
> (`.gas-snapshot`) y permite el gate `forge snapshot --check --tolerance 5` (D-039).

---

## RF-013 — Ciclo de vida del claim: vigencia y revocación por el issuer (Ciclo 8)

**Motivo:** el struct `Claim` no tenía vigencia ni estado de revocación, y `isVerified` aceptaba claims
vencidos; solo el **titular** podía dejar de usar su claim (`removeClaim`, `onlyOwner`), nunca el issuer
(H-08, auditoría V1). Ahora el claim es **vigente** (`expiresAt`, ya firmado desde RF-001/D-020) y el
issuer puede **revocarlo**, y `TokenCloneable.isVerified` exige ambas condiciones. Incluye **HB-14**
(`IdentityRegistry.removeIdentity` verifica la pertenencia a `registeredAddresses`).

### Struct `Claim`

| | |
|---|---|
| **Antes** | `Claim { uint256 topic; uint256 scheme; address issuer; bytes signature; bytes data; string uri; uint256 expiresAt; }` |
| **Después** | `Claim { uint256 topic; uint256 scheme; address issuer; bytes signature; bytes data; string uri; uint256 expiresAt; bool revoked; }` |
| **Breaking** | **Sí** — cambio de *storage layout* del clon. `revoked` se **añade al final**, por lo que el layout previo queda intacto (append-only). Sin proxy actualizable (D-019), el ciclo de vida sigue siendo **redeploy limpio** (D-037). |

### `getClaim` — salidas

| | |
|---|---|
| **Firma** | `getClaim(uint256,address) returns (uint256 topic, uint256 scheme, address issuer, bytes signature, bytes data, string uri, uint256 expiresAt)` |
| **Selector** | `0x48e6b5a3` (no cambia; **sí cambian las salidas**) |
| **Antes** | 7 salidas (hasta `expiresAt`) |
| **Después** | 8 salidas: se añade `bool revoked` al final (posible en adelante y con el mismo selector) |
| **Breaking** | Sí — cualquier cliente que decodifique la tupla de 7 campos debe leer 8 (o ignorar la última). La semántica: `revoked == true` ⇒ el claim sigue almacenado (trazabilidad) pero **no es válido**. |

### API nueva (aditiva)

| Firma | Selector | Notas |
|---|---|---|
| `revokeClaim(uint256 _topic, address _issuer)` | `0x512752e4` | **Sin `onlyOwner`**: exige `msg.sender == _issuer` y que el claim exista. Marca `revoked = true` y conserva `data`/`uri`/`signature`. Revierte `"Claim does not exist"` / `"Only issuer can revoke"`. |
| `hasValidClaim(uint256 _topic, address _issuer) view returns (bool)` | `0x03658fd8` | `true` solo si el claim existe, no está revocado y (`expiresAt == 0` — sin caducidad, D-038 — o `block.timestamp < expiresAt`). Es la vista que consulta `isVerified` por `staticcall`. |

### Evento `ClaimRevoked`

| | |
|---|---|
| **Firma** | `ClaimRevoked(uint256 indexed topic, address indexed issuer)` — topic0 `0x2773a4866bfa84cbee6a7def6453a797ed617c6d11fcd93b8c0c1f94570b9434` |
| **Nota** | El histórico de `ClaimAdded` **no se borra** al revocar (ni `claimExists` pasa a `false`). La revocación es granular por `(topic, issuer)`. |

> Desviación respecto al texto ilustrativo de CU-17 (`ClaimRevoked(topic, issuer, timestamp)`): se emite
> **sin timestamp** para ceñirse al diseño obligatorio de RF-013. El instante de la revocación es el
> `block.timestamp` del bloque que contiene el evento (recuperable por el consumidor). Ver D-047.

### Comportamiento (no de firma)

- `addClaim` (renovación, D-018): un nuevo claim firmado del mismo `(topic, issuer)` **reactiva** el claim
  (`revoked = false`) y actualiza `expiresAt`; `expiresAt` va dentro del digest (D-020), así que reactivar
  exige una **nueva firma** del issuer.
- `TokenCloneable.isVerified`: además de `trustedIssuersRegistry.hasClaimTopic(issuer, topic)`, exige
  `hasValidClaim(topic, issuer)` en el clon de identidad; si el `staticcall` falla, el claim **no** cuenta
  (fail-closed, RF-011). Un claim vencido o revocado ya no verifica al titular y bloquea `mint`/`transfer`.
- `IdentityRegistry.removeIdentity` (HB-14): si el wallet no figura en `registeredAddresses`, revierte
  `"Wallet not in registered addresses"` en lugar de emitir `IdentityRemoved` sin borrar. Sin cambio de firma.

### Impacto en `rwa-web` (D-003: fuera de alcance, requiere trabajo posterior)

- `rwa-web/web-identity/contracts/IdentityCloneable.abi.json` — ABI **estática y ya obsoleta** (no incluye
  `expiresAt` de RF-001 ni ahora `revoked`/`revokeClaim`/`hasValidClaim`/`ClaimRevoked`); debe regenerarse
  desde `sc/out/`.
- `rwa-web/web-identity/lib/identity-claims.ts:164` — `getIdentityClaims` decodifica `getClaim` por nombre
  (`claim.topic`…); al regenerar la ABI debe añadir `expiresAt` y `revoked` al tipo `IdentityClaim` y exponer
  la vigencia en la UI (badge de vencido/revocado). Mientras la ABI siga desactualizada, la decodificación de
  la tupla nueva puede fallar.
- `rwa-web/web-identity/contracts/IdentityRegistry.abi.json` — sin cambio de firma (solo aparece un literal
  de revert nuevo).
- No existe hoy UI de revocación en el cliente; si se añade, `revokeClaim` debe firmarse **desde la cuenta
  del issuer** (no desde la del titular).

Acción requerida (cuando se retome la zona web, p. ej. RF-007/RF-008): `forge build` y copiar de `sc/out/`,
leer las 8 salidas de `getClaim`, y filtrar los claims no válidos (`revoked`/`expiresAt`).

---

## RF-013 — Nonce firmado anti-replay en la revocación de claims (Ciclo 8c)

**Motivo:** `revokeClaim` marcaba `revoked = true`, pero la **firma EIP-712 original** del issuer seguía
siendo válida para la tupla `(walletOwner, topic, scheme, dataHash, expiresAt)`. El titular podía
reintroducirla con `addClaim` y reactivar el claim: la revocación **no era definitiva** (D-046, detectado
en el Ciclo 8). El Ciclo 8c incorpora el `nonce` al digest firmado y lo incrementa **solo** al revocar,
de modo que toda firma anterior a la revocación queda inservible.

### Cambio crítico de firma off-chain — `CLAIM_TYPEHASH`

| | |
|---|---|
| **Antes** | `keccak256("Claim(address walletOwner,uint256 topic,uint256 scheme,bytes32 dataHash,uint256 expiresAt)")` |
| **Después** | `keccak256("Claim(address walletOwner,uint256 topic,uint256 scheme,bytes32 dataHash,uint256 expiresAt,uint256 nonce)")` — valor `0x8f719673d99f0733a2d1b85addf49c9a7b0dd6360023e749aa7c0494375a6ead` |
| **Selector `CLAIM_TYPEHASH()`** | `0x6b0509b1` (sin cambio: es un getter constante) |
| **Breaking** | **Sí, crítico off-chain.** Un firmante que use el typehash antiguo produce un digest distinto y `addClaim` revierte `"Signature signer mismatch"`. |

Nuevo digest firmado por el issuer (EIP-712):

```
domain     = {name: "RWA-Identity", version: "1", chainId, verifyingContract: <dirección del clon>}
typeHash   = keccak256("Claim(address walletOwner,uint256 topic,uint256 scheme,bytes32 dataHash,uint256 expiresAt,uint256 nonce)")
structHash = keccak256(abi.encode(typeHash, walletOwner, topic, scheme, keccak256(data), expiresAt, nonce))
digest     = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash))
```

`nonce` = `claimNonce(topic, issuer)` **leído en el momento de firmar** (0 en el alta inicial; se
incrementa en cada `revokeClaim`).

### API nueva (aditiva) — `claimNonce`

| | |
|---|---|
| **Firma** | `claimNonce(uint256 _topic, address _issuer) view returns (uint256)` |
| **Selector** | `0x8a2eff53` |
| **Semántica** | Nonce vigente del par `(topic, issuer)`. Empieza en `0`; `revokeClaim` lo incrementa en 1 (y solo entonces). Forma parte del digest firmado. |
| **Breaking** | No para consumidores que no firman; **obligatorio** para todo cliente que construya firmas de claim. |

### Funciones existentes: firmas sin cambios

| Función | Selector | Cambio |
|---|---|---|
| `addClaim(uint256,uint256,address,bytes,bytes,string,uint256)` | `0x16cd5ffe` | **Sin cambio de firma**; cambia el digest que verifica y **no** incrementa el nonce (D-018 intacto). |
| `revokeClaim(uint256,address)` | `0x512752e4` | **Sin cambio de firma**; además de marcar `revoked = true` incrementa `claimNonce[topic][issuer]`. |
| `getClaim(uint256,address)` | `0x48e6b5a3` | **Sin cambio**: sigue devolviendo 8 salidas. El nonce vive en un mapping aparte, no en el struct `Claim`. |
| `hasValidClaim(uint256,address)` | `0x03658fd8` | Sin cambio de semántica. |

### Impacto en `rwa-web` (D-003: fuera de alcance, requiere trabajo posterior)

- El cliente **debe leer `claimNonce(topic, issuer)` antes de firmar** y añadir `uint256 nonce` como último
  campo del mensaje EIP-712 (`signTypedData`). Con el typehash antiguo la firma **no verifica**.
- `rwa-web/web-identity/contracts/IdentityCloneable.abi.json` — ABI estática: al regenerarla desde
  `sc/out/` incorpora el getter `claimNonce`.
- Al reactivar un claim previamente revocado, el cliente debe **volver a leer** el nonce (habrá cambiado)
  y pedir al issuer una firma nueva; la firma original ya no es reutilizable.
- `rwa-web/web-identity/lib/identity-claims.ts` — hoy no firma EIP-712; cuando implemente la firma
  (RF-007/RF-008), debe usar el typehash con `nonce`.

Acción requerida: `forge build` en `rwa-sc/sc/`, copiar las ABIs de `sc/out/`, exponer `claimNonce` en el
cliente y actualizar el mensaje EIP-712 antes de firmar cualquier claim.

---

## Ciclo 9 — RF-010: artefacto de despliegue verificado (sin cambios de ABI)

El Ciclo 9 **no modifica ningún contrato de `src/`**: no hay cambios de firma, de selector ni de número de
salidas. Lo relevante para consumidores es el **artefacto de despliegue versionado** que produce el script
canónico `sc/script/deploy.sh` + `sc/script/DeployFullStack.s.sol`:

- Ruta: `sc/deployments/<chainId>-<timestamp>.json` (versionado; **no** está en `.gitignore`).
- Contenido: `chainId`, `block`, `timestamp`, `deployer`, `contracts` (direcciones), `token` (dirección,
  `name`/`symbol`/`decimals` y registries configurados), `compliance` (módulo y `maxBalance`),
  `verifiedContracts` y `abis` con los **ABIs relevantes** ya extraídos
  (`IdentityRegistry`, `TrustedIssuersRegistry`, `TokenCloneFactory`, `IdentityCloneFactory`,
  `ClaimTopicsRegistryCloneFactory`, `ComplianceAggregator`, `ClaimTopicsRegistryCloneable`,
  `TokenCloneable`, `IdentityCloneable`, `MaxBalanceCompliance`).
- No contiene secretos (0 cadenas de 64 hex y 0 menciones a material sensible; comprobado por el script).

### Despliegue de referencia (Anvil de GCP, chain-id 31337, bloque 517)

| Contrato | Dirección |
|---|---|
| IdentityRegistry | `0xF5b81Fe0B6F378f9E6A3fb6A6cD1921FCeA11799` |
| TrustedIssuersRegistry | `0x67baFF31318638F497f4c4894Cd73918563942c8` |
| TokenCloneFactory | `0x6533158b042775e2FdFeF3cA1a782EFDbB8EB9b1` |
| IdentityCloneFactory | `0x73C68f1f41e4890D06Ba3e71b9E9DfA555f1fb46` |
| ClaimTopicsRegistryCloneFactory | `0xD2D5e508C82EFc205cAFA4Ad969a4395Babce026` |
| ComplianceAggregator | `0x2b639Cc84e1Ad3aA92D4Ee7d2755A6ABEf300D72` |
| ClaimTopicsRegistry | `0xafAC6756b04A92C5C4a68cE3882b99531995eBBA` |
| Token (`RWA Demo Token` / `RWAD`) | `0x382F74873b3798BEca33Cf69623d0CF35dE0f369` |
| MaxBalanceCompliance | `0xB468647B04bF657C9ee2de65252037d781eABafD` |

### Impacto en `rwa-web` (D-003: fuera de alcance, requiere trabajo posterior)

- Para apuntar las apps a un despliegue concreto, leer direcciones y ABIs del propio artefacto JSON en vez de
  hardcodear las ABIs estáticas: las firmas son las mismas del Ciclo 8c, así que no hay migración de tipos,
  solo actualización de direcciones.

---

## Ciclo 10 — RF-006: línea base de ABIs y control de deriva (sin cambios de ABI)

El Ciclo 10 **no modifica ningún contrato de `src/`**: todas las firmas, selectores y salidas son las del
Ciclo 8c. Lo relevante para consumidores es el nuevo **control automático de deriva**:

- **Línea base versionada:** `sc/abis/<Contrato>.json` (una ABI canónica por cada contrato de `src/` y
  `src/compliance/`, incluidas las interfaces `ICompliance` e `IClaimTopicsRegistry`). Estado inicial:
  **15 ABIs**, generadas con `forge inspect <Contrato> abi --json`.
- **Gate:** `sc/script/ci/abi_diff.sh` compara la ABI actual con la línea base y **falla** si algún
  selector o firma nuevo, modificado o eliminado no está declarado en este changelog.
- **Procedimiento de actualización de la línea base:**
  1. Cambiar el contrato en `src/`.
  2. Añadir aquí la sección del contrato con la firma anterior/nueva, el selector y el impacto en `rwa-web`.
  3. Ejecutar `sc/script/ci/abi_diff.sh --update` y commitear `sc/abis/*.json` **junto con** esta entrada.

> Añadir o regenerar `sc/abis/` sin la entrada correspondiente en este archivo deja el gate en rojo: es el
> comportamiento buscado (debe acompañarse de una entrada en `CHANGELOG_ABIS.md`).

---

## Fase 4 (cierre) — AF-03: el digest EIP-712 cubre el `uri` (cambio crítico de firma off-chain)

**Motivo:** el `CLAIM_TYPEHASH` vigente (Ciclo 8c) cubría `walletOwner`, `topic`, `scheme`, `dataHash`,
`expiresAt` y `nonce`, pero **no** el `uri`. El `uri` se almacenaba y se emitía, pero el titular (owner de
la identidad, `addClaim` es `onlyOwner`) podía publicar **cualquier** referencia documental KYC/AML
reutilizando una firma legítima del issuer, o renovar el claim con otro `uri` sin consentimiento. La
referencia off-chain (H-11) quedaba **no autenticada** (hallazgo AF-03 de la auditoría adversarial final).

### Cambio crítico de firma off-chain — `CLAIM_TYPEHASH`

| | |
|---|---|
| **Antes** | `keccak256("Claim(address walletOwner,uint256 topic,uint256 scheme,bytes32 dataHash,uint256 expiresAt,uint256 nonce)")` |
| **Después** | `keccak256("Claim(address walletOwner,uint256 topic,uint256 scheme,bytes32 dataHash,uint256 expiresAt,uint256 nonce,bytes32 uriHash)")` — valor `0x65c6cda5a06929bfdef28339b542f297fa9c29c42c29dea189fd85441d8301fc` |
| **Selector `CLAIM_TYPEHASH()`** | `0x6b0509b1` (**sin cambio**: es un getter `constant`; cambia el **valor** devuelto, no la firma) |
| **Selector `addClaim(...)`** | `0x16cd5ffe` (**sin cambio de firma**; el parámetro `string _uri` ya existía) |
| **`sc/abis/`** | **Sin regenerar**: `forge inspect abi` no incluye el valor de una constante; `abi_diff.sh` sigue en verde |
| **Breaking** | **Sí, crítico off-chain.** Un firmante que use el typehash del Ciclo 8c produce un digest distinto y `addClaim` revierte `"Signature signer mismatch"`. |

Nuevo digest firmado por el issuer (EIP-712):

```
domain     = {name: "RWA-Identity", version: "1", chainId, verifyingContract: <dirección del clon>}
typeHash   = keccak256("Claim(address walletOwner,uint256 topic,uint256 scheme,bytes32 dataHash,uint256 expiresAt,uint256 nonce,bytes32 uriHash)")
structHash = keccak256(abi.encode(typeHash, walletOwner, topic, scheme, keccak256(data), expiresAt, nonce, keccak256(bytes(uri))))
digest     = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash))
```

`uriHash = keccak256(bytes(uri))`; `nonce = claimNonce(topic, issuer)` leído al firmar. `uri == ""` se firma
como `uriHash = keccak256("")` (los overloads históricos de `SigUtils` sin `uri` hacen exactamente eso).

### Impacto en `rwa-web` (D-003: fuera de alcance, requiere trabajo posterior)

- Todo cliente que firme claims (`signTypedData`) **debe añadir `bytes32 uriHash` como último campo** del
  mensaje EIP-712. La ABI estática no cambia; sí cambia el mensaje firmado.
- Si el cliente no pasa `uri` (claims sin documento), debe firmar `uriHash = keccak256(bytes(""))`.
- Pruebas de regresión: `test/IdentityCloneable.t.sol`
  (`test_AF03_addClaim_uri_alterado_revierte`, `test_AF03_addClaim_uri_correcto_ok`,
  `test_AF03_digest_cambia_con_el_uri`).

---

## Fase 4 (cierre) — AF-05: el token es fail-closed sin módulos de compliance (sin cambio de ABI)

**Motivo:** el `ComplianceAggregator` ya era fail-closed con 0 módulos (RF-012), pero el **token** no:
`canTransfer` recorría `complianceModules` y, con el array vacío, devolvía `true` ("0 módulos = permitir
todo"). Retirar el último módulo (o el aggregator) desactivaba en silencio toda la política de compliance
(hallazgo AF-05 de la auditoría adversarial final).

### Regla vigente

- `TokenCloneable.canTransfer(from, to, amount)` devuelve **`false`** cuando `complianceModules.length == 0`.
  Por tanto `transfer`/`transferFrom` revierten `"Transfer not compliant"` hasta que `COMPLIANCE_ROLE`
  registre un módulo conforme (ERC-165 y, si es de un solo token, `tokenContract() == token`; AF-01).
- `mint`/`burn`/`forcedTransfer` **no** dependen de `canTransfer`: la emisión y la recuperación siguen su
  ruta privilegiada (agente) y **no** se ven afectadas por AF-05. La emisión con 0 módulos sigue operativa.
- **Sin cambio de ABI:** ninguna firma, selector, salida ni evento cambia; `sc/abis/` no se regenera.

### Impacto en consumidores

- Un token recién creado **no permite transferencias** hasta que se le registre al menos un módulo de
  compliance. El despliegue canónico (`DeployFullStack.s.sol` + `deploy.sh`) ya registra el
  `ComplianceAggregator` + `MaxBalanceCompliance`, y el smoke test verifica on-chain que el token tiene
  **al menos un módulo** (`complianceModules(0)`).
- Pruebas de regresión: `test/AuditoriaFinalAF.t.sol` (`test_AF05_canTransfer_false_sin_modulos`,
  `test_AF05_transfer_revierte_sin_modulos`, `test_AF05_con_modulo_permisivo_transfiere`,
  `test_AF05_retirar_ultimo_modulo_bloquea_y_registrar_recupera`,
  `test_AF05_mint_y_forcedTransfer_no_dependen_de_modulos`).

---

## Cierre de deuda (QW-8) — evento `TokenContractSet` en los módulos de compliance (ABI **aditiva**)

**Motivo:** H-34 — fijar `tokenContract` en los módulos no emitía ningún evento, así que la vinculación
módulo→token no dejaba traza on-chain. QW-8 añade el evento en los tres módulos.

### ABI: evento nuevo (aditivo)

```
event TokenContractSet(address indexed tokenContract);
```

- `MaxBalanceCompliance.setTokenContract(address)` → emite `TokenContractSet(_token)`
- `MaxHoldersCompliance.setTokenContract(address)` → emite `TokenContractSet(_token)`
- `TransferLockCompliance.setTokenContract(address)` → emite `TokenContractSet(_token)`

### Firmas existentes: sin cambios

`setTokenContract(address)` conserva su selector; **no** cambia ninguna firma de función, salida ni
comportamiento de autorización (`onlyOwner`, `require(_token != address(0))`). Por tanto **no hay impacto**
para los consumidores que llaman a la función; solo se añade un log.

### Línea base

`sc/abis/MaxBalanceCompliance.json`, `MaxHoldersCompliance.json` y `TransferLockCompliance.json` se
regeneran con `script/ci/abi_diff.sh --update`; los `.methods` no cambian (no hay selectores nuevos).

---

## Cierre de deuda (AF-12) — `removeClaim` con anti-replay (sin cambio de ABI)

**Motivo:** AF-12 — el titular podía borrar el claim (`removeClaim`) sin invalidar la firma previa, y el
`delete` perdía la traza de un claim revocado (D-046).

### Regla vigente

- `IdentityCloneable.removeClaim(topic, issuer)` sigue siendo `onlyOwner` y **sigue borrando** la entrada
  (`claimExists` → `false`), pero ahora **incrementa `claimNonce[topic][issuer]`**, igual que `revokeClaim`.
  La firma EIP-712 emitida antes del borrado deja de verificar (`addClaim` revierte
  `"Signature signer mismatch"`), de modo que el borrado no puede reactivar el claim por replay.
- La traza on-chain del claim eliminado queda en los eventos `ClaimAdded` (con firma, `data`, `uri` y
  `expiresAt`), `ClaimRevoked` (si lo hubo) y `ClaimRemoved`. Es la fuente de verdad documentada cuando el
  storage se borra.
- **Sin cambio de ABI:** `claimNonce` ya era público (Ciclo 8c); ninguna firma, selector, salida ni evento
  cambia. `sc/abis/` no requiere regeneración por este cambio.

### Pruebas de regresión

`test/RF013_ClaimLifecycle.t.sol`: `test_AF12_removeClaim_incrementa_nonce_y_borra`,
`test_AF12_removeClaim_firma_previa_no_reactiva`, `test_AF12_removeClaim_reactivacion_con_nonce_nuevo_ok`,
`test_AF12_removeClaim_emite_evento_de_traza`.

---

## Cierre de deuda (H-20) — indices O(1) y vistas paginadas (ABI **aditiva**)

**Motivo:** H-20 (auditoria V1 / plan M-11) — la pertenencia y el borrado en los arrays de
enumeracion eran O(n), y las vistas materializaban el array completo. H-20 anade mappings de indice
y vistas paginadas **sin retirar** los arrays ni sus getters (ABI solo aditiva).

### API nueva (aditiva)

| Contrato | Firma nueva |
|---|---|
| `TokenCloneable` | `removeComplianceModuleByAddress(address)` |
| `TokenCloneable` | `getComplianceModulesPaginated(uint256,uint256) returns (address[])` |
| `IdentityRegistry` | `getRegisteredAddressesPaginated(uint256,uint256) returns (address[])` |
| `TrustedIssuersRegistry` | `getTrustedIssuersPaginated(uint256,uint256) returns (address[])` |
| `ClaimTopicsRegistry` | `getClaimTopicsPaginated(uint256,uint256) returns (uint256[])` |
| `ClaimTopicsRegistryCloneable` | `getClaimTopicsPaginated(uint256,uint256) returns (uint256[])` |
| `ComplianceAggregator` | `getModulesPaginated(address,uint256,uint256) returns (address[])` |
| `ComplianceAggregator` | `getTokensPaginated(uint256,uint256) returns (address[])` |

### Firmas existentes: sin cambios

Se conservan `complianceModules(uint256)`, `getComplianceModules()`, `getRegisteredAddress(uint256)`,
`getTrustedIssuers()`, `getClaimTopics()`, `getModules(address)`, etc. `hasClaimTopic(address,uint256)`
y `claimTopicExists(uint256)` mantienen su firma: solo cambia su implementacion interna (mapping O(1)).

### Storage (redeploy limpio D-009/RT-008)

Nuevos mappings (no hay proxy actualizable):
`TokenCloneable.moduleIndex`, `IdentityRegistry.addressIndex`,
`TrustedIssuersRegistry.issuerIndex` y `issuerHasTopic`, `ClaimTopicsRegistry.topicIndex` y
`topicExistsFlag` (idem en `ClaimTopicsRegistryCloneable`). Los slots previos no se reordenan: los
mappings nuevos se declaran al final.

### Impacto en consumidores

Ninguno obligatorio (aditivo). Los consumidores pueden migrar a las vistas paginadas para no traer
listas completas; los getters historicos siguen disponibles con la misma semantica.

---

## Cierre de deuda (H-19) — vinculacion unica modulo→token (sin cambio de ABI)

`setTokenContract` de `MaxBalanceCompliance`, `MaxHoldersCompliance` y `TransferLockCompliance` ahora
revierte `"Module already bound to another token"` si el modulo ya estaba vinculado a otro token
(idempotente si se repite el mismo). Cierra la contaminacion de estado entre tokens de H-19 (los
contenedores `isHolder`/`holderCount` y `lockEndTime` no estan indexados por token). AF-01 ya impedia
registrar un modulo sin vincular; H-19 cierra la re-vinculacion posterior. **Sin cambio de ABI.**
