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

> Este archivo se ampliará en el Ciclo 10 / RF-006 (documentación, `SECURITY.md` y
> `script/ci/abi_diff.sh`) con el resto de cambios de ABI y el procedimiento de verificación del diff.
