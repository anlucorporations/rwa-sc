# RUNBOOK — Migración por redeploy limpio (`rwa-sc`)

> **Proyecto:** RWA / `rwa-sc` · **Fase 4 (Pruebas)** · **Fecha:** 2026-10-11
> **Decisiones aplicables:** **D-019** (ciclo de vida = redeploy limpio con EIP-1167, **sin proxy actualizable**; runbook de migración documentado), **D-009 / RT-008** (redeploy limpio permitido; el *layout* de storage puede moverse) y **D-023/D-037** (los tokens/módulos ya desplegados se corrigen por redeploy; no hay registro retroactivo).
> **Alcance:** procedimiento operativo para re-desplegar la pila `rwa-sc` en una red nueva o tras un cambio incompatible de bytecode/ABI.

---

## 1. Propósito y alcance

`TokenCloneable`, `IdentityCloneable` y sus registries **no usan proxy actualizable**: se despliegan como implementación + clones EIP-1167 (D-019). Por tanto, cualquier cambio de bytecode de la *implementación* (o de la interfaz) **no se puede aplicar in-place**: exige un **redeploy limpio** y la migración de identidades, claims, registros y saldos al nuevo despliegue.

**Cuándo aplicar este runbook:**

- Cambio de bytecode de la implementación (p. ej. RF-003/RF-004 nuevos, un `supportsInterface` distinto).
- Cambio incompatible de ABI (documentado en `CHANGELOG_ABIS.md`).
- Incidente de seguridad que invalide las direcciones actuales.
- Alta de una red/entorno nuevo.

**Cuándo NO aplicar:** cambios que solo afectan a la configuración del token ya desplegado y son administrables por los roles (`setMaxBurnPerTx`, `setMaxForcedPerTx`, `setAuthorizedDestination`, `setMaxSupply`, `addClaimTopic`, `addTrustedIssuer`, `addComplianceModule`/`addModuleThroughAggregator`, `addClaim`/`revokeClaim`). Para esos casos, basta una **transacción de configuración**, no un redeploy.

> **Principio operativo:** el despliegue antiguo **permanece intacto** durante la migración. No se anuncia el nuevo hasta que el smoke test de operatividad pasa.

---

## 2. Precondiciones

1. **Herramientas:** `forge`, `cast`, `jq`, `python3` con `eth_keyfile` (el `deploy.sh` las exige). `export PATH="$HOME/.foundry/bin:$PATH"`.
2. **Acceso a RPC** de la red destino y **saldo** en el firmante.
3. **Variables de entorno** (ver `sc/script/deploy.sh`):
   - `RPC_URL` (obligatoria), `CHAIN_ID` (opcional; si se define, debe coincidir con `cast chain-id`).
   - Clave de despliegue en **variable de entorno** (`DS_DEPLOYER_PRIVATE_KEY` / `DEPLOYER_PRIVATE_KEY` / `ADMIN_PRIVATE_KEY` / `PRIVATE_KEY`) o vía GCP Secret Manager (`USE_SECRET_MANAGER=1`, `DS_DEPLOYER_SECRET`). **Nunca** en `argv` ni en `keys.json` (RF-010).
   - Opcionales del full stack: `MAX_BALANCE`, `MAX_BURN_PER_TX`, `MAX_FORCED_PER_TX`, `ISSUER_ADDRESS`, `DEPLOYMENT_JSON`.
   - `BROADCAST=0` para simular sin enviar transacciones.
4. **Evidencia previa:** copia del artefacto del despliegue anterior (`sc/deployments/<chain>-<stamp>.json`) y de los ABIs (`sc/abis/`) para poder hacer rollback y comparar.
5. **Commit/rama** a desplegar fijados (`git rev-parse HEAD`) y pipeline en verde sobre ese commit.

---

## 3. Orden de despliegue (paso a paso)

El camino canónico es `sc/script/DeployFullStack.s.sol` orquestado por `sc/script/deploy.sh` (que despliega, **verifica on-chain** y ejecuta el **smoke test de operatividad**). El orden es obligatorio por dependencias:

| # | Paso | Contrato / llamada | Por qué en este orden |
|---|---|---|---|
| 1 | Registries compartidos | `new IdentityRegistry(admin)`, `new TrustedIssuersRegistry(admin)` | Los consumen el token y las identidades |
| 2 | Factories de clones | `new TokenCloneFactory(admin)`, `new IdentityCloneFactory(admin)`, `new ClaimTopicsRegistryCloneFactory(admin)` | Despliegan sus implementaciones en el constructor (`_disableInitializers`) |
| 3 | Aggregator | `new ComplianceAggregator(admin)` | Es un módulo multi-token; se da de alta en cada token |
| 4 | Política de issuers | `TrustedIssuersRegistry.addTrustedIssuer(issuer, topics[])` | Sin esto `isVerified` es fail-closed (RF-011) |
| 5 | ClaimTopicsRegistry del token | `ClaimTopicsRegistryCloneFactory.createRegistryWithTopics(admin, topics[])` | Fija los topics requeridos del token |
| 6 | Token | `TokenCloneFactory.createTokenWithRegistries(name, symbol, decimals, admin, identityRegistry, trustedIssuersRegistry, claimTopicsRegistry)` | Registries ya cableados en la creación |
| 7 | Módulo(s) de compliance | `new MaxBalanceCompliance(admin, max)`; **`module.setTokenContract(address(token))`**; `token.addComplianceModule(address(aggregator))`; `token.addModuleThroughAggregator(address(aggregator), address(module))` | **AF-01:** `addComplianceModule`/`aggregator.addModule` rechazan un módulo que no devuelva `tokenContract() == token`. El `setTokenContract` debe ir **antes** del alta. El aggregator (sin `tokenContract()`) queda exento. **AF-05:** este paso es **obligatorio**: sin ningún módulo registrado el token es fail-closed y `transfer`/`transferFrom` revierten `"Transfer not compliant"` |
| 8 | Configuración obligatoria del token (AF-07) | `token.setMaxBurnPerTx(v)`, `token.setMaxForcedPerTx(v)`, `token.setAuthorizedDestination(destino, true)`, `token.setMaxSupply(v)` si aplica | Con los topes a `0` la quema/recuperación están **desactivadas**; es lo que verifica el smoke test del `deploy.sh` |
| 9 | Identidades y claims | `IdentityCloneFactory.createIdentity(owner)`; `IdentityRegistry.registerIdentity(wallet, identity)`; `IdentityCloneable.addClaim(topic, 1, issuer, firma, data, uri, expiresAt)` | La firma es **EIP-712** por el issuer (RF-001): incluye `walletOwner`, `topic`, `scheme`, `dataHash`, `expiresAt` y `nonce` (D-050). Ver `sc/test/helpers/SigUtils.sol` |
| 10 | Verificación | `token.isVerified(wallet)` por cada wallet operativa | Fail-closed: exige registro, identidad, topics e issuer autorizado con claim vigente y no revocado (RF-011/RF-013) |

### 3.1 Comando canónico

```bash
source /home/dsh/workspace/gcp-env.sh         # exporta RPC_URL, CHAIN_ID, ADMIN_PRIVATE_KEY...
export PATH="$HOME/.foundry/bin:$PATH"
cd rwa-sc
sc/script/deploy.sh                            # despliega, verifica con cast y ejecuta el smoke test (AF-07)
```

Simulación sin broadcast:

```bash
BROADCAST=0 sc/script/deploy.sh
```

Parámetros del token de ejemplo (opcionales):

```bash
MAX_BALANCE=1000000000000000000000000 \
MAX_BURN_PER_TX=1000 \
MAX_FORCED_PER_TX=1000 \
sc/script/deploy.sh
```

> El `deploy.sh` **no** hace `set -e`: cada paso comprueba su resultado y falla con mensaje explícito. La clave se materializa en un keystore temporal (modo 600) y se borra con `trap cleanup`.

---

## 4. Verificación post-redeploy con `cast`

El `deploy.sh` ya ejecuta `cast code` sobre cada contrato y un **smoke test de operatividad** (AF-07). Para una verificación manual, con `DEPLOYMENT_JSON` = artefacto generado:

```bash
RPC="$RPC_URL"; J="$DEPLOYMENT_JSON"
TOKEN=$(jq -r '.contracts.Token' "$J")
AGG=$(jq -r '.contracts.ComplianceAggregator' "$J")
MOD=$(jq -r '.compliance.MaxBalanceCompliance' "$J")
IR=$(jq -r '.contracts.IdentityRegistry' "$J")
DEP=$(jq -r '.deployer' "$J")

cast call "$TOKEN" 'name()(string)'    --rpc-url "$RPC"
cast call "$TOKEN" 'symbol()(string)'  --rpc-url "$RPC"
cast call "$TOKEN" 'decimals()(uint8)' --rpc-url "$RPC"

cast call "$TOKEN" 'identityRegistry()(address)'       --rpc-url "$RPC"   # == IR
cast call "$TOKEN" 'trustedIssuersRegistry()(address)' --rpc-url "$RPC"
cast call "$TOKEN" 'claimTopicsRegistry()(address)'    --rpc-url "$RPC"

cast call "$AGG" 'getModuleCount(address)(uint256)' "$TOKEN"                 --rpc-url "$RPC"   # >= 1
cast call "$AGG" 'isModuleActiveForToken(address,address)(bool)' "$TOKEN" "$MOD" --rpc-url "$RPC" # true
cast call "$MOD" 'tokenContract()(address)' --rpc-url "$RPC"                 # == TOKEN (AF-01)
cast call "$TOKEN" 'complianceModules(uint256)(address)' 0 --rpc-url "$RPC"  # == AGG (AF-05: >= 1 módulo)

cast call "$TOKEN" 'maxBurnPerTx()(uint256)'   --rpc-url "$RPC"              # != 0
cast call "$TOKEN" 'maxForcedPerTx()(uint256)' --rpc-url "$RPC"              # != 0
cast call "$TOKEN" 'authorizedDestinations(address)(bool)' "$DEP" --rpc-url "$RPC" # true
cast call "$IR" 'isRegistered(address)(bool)' "$DEP" --rpc-url "$RPC"        # true
cast call "$TOKEN" 'isVerified(address)(bool)' "$DEP" --rpc-url "$RPC"       # true si hay claims vigentes
```

**Criterio de éxito:** `deploy.sh` termina con `exit 0` y el mensaje `Smoke test de operatividad correcto`. Si algo falla, **no** se anuncia el nuevo despliegue.

---

## 5. Actualización de consumidores

Tras verificar el nuevo despliegue:

1. **Artefacto de despliegue:** `sc/deployments/<chainId>-<stamp>.json` (lo escribe `deploy.sh`, con ABIs anexados y `verifiedContracts`). Es la **fuente de direcciones** para los consumidores.
2. **ABIs:** si cambió la interfaz, regenerar `sc/abis/` con `sc/script/ci/abi_diff.sh --update` y declarar el cambio en `sc/CHANGELOG_ABIS.md` (el gate `abi_diff.sh` exige ambos en el mismo cambio).
3. **Consumidores Web/indexer** (`rwa-web` y cualquier indexer/observabilidad): actualizar las direcciones y los ABIs importados. Buscar las direcciones antiguas en el repositorio:
   ```bash
   grep -rn "0x<direccion_antigua>" --include='*.json' --include='*.ts' --include='*.tsx' --include='*.env*' .
   ```
4. **Registros y saldos:** re-registrar identidades (`registerIdentity`), re-emitir claims (EIP-712) y **re-acuñar/replicar saldos** según el plan aprobado (el redeploy limpio **no** migra estado on-chain automáticamente). Documentar el mapeo antiguo→nuevo.
5. **Comunicación:** publicar direcciones nuevas, commit, artefacto y IDs de pipeline verdes.

---

## 6. Plan de rollback

| Situación | Acción |
|---|---|
| Falla la validación de red (`chain-id` != `CHAIN_ID`) | **Nada se ha desplegado**; abortar y corregir la configuración. |
| Falla `forge script` o la verificación `cast code`/`cast call` | Conservar el artefacto previo; **no** anunciar direcciones nuevas; descartar el artefacto parcial. El token antiguo sigue operativo. |
| Falla el smoke test de operatividad | No promover; investigar (topes a 0, módulo no vinculado, `isVerified` false). El token antiguo sigue operativo. |
| El nuevo despliegue se promociona y luego aparece un defecto | **Rollback de consumidores**: reapuntar `rwa-web`/indexer al artefacto anterior (siguen existiendo las direcciones y ABIs antiguos). El token nuevo se pausa (`pause()`) o se deja inerte; los saldos ya migrados se reconcilian con un nuevo redeploy corregido. |
| Cambio de gobernanza/clave | Rotar la clave según D-021 y repetir el runbook. |

**Regla de oro:** el artefacto y los ABIs del despliegue anterior **no se borran** hasta que el nuevo lleve un periodo de observación estable.

---

## 7. Checklist final

- [ ] Pipeline en verde sobre el commit desplegado (IDs registrados).
- [ ] `deploy.sh` `exit 0` y **smoke test de operatividad** correcto.
- [ ] `cast code` != `0x` en todas las direcciones; ABIs anexados al artefacto.
- [ ] `module.tokenContract() == token` (AF-01) y módulo activo en el aggregator.
- [ ] **Token con al menos un módulo de compliance** (`complianceModules(0) != 0`) — AF-05: sin módulos no hay transferencias.
- [ ] `maxBurnPerTx` / `maxForcedPerTx` != 0 y destino autorizado.
- [ ] Identidades registradas y `isVerified(wallet) == true` para las wallets operativas.
- [ ] Consumidores (`rwa-web`, indexer) reapuntados; direcciones antiguas localizadas y reemplazadas.
- [ ] `abi_diff.sh` verde y `CHANGELOG_ABIS.md` actualizado si hubo cambio de ABI.
- [ ] Artefacto guardado y comunicado; plan de rollback revisado.

---

## 8. Gobernanza: entrega al multisig + timelock (H-06 / D-021)

> Objetivo: que las operaciones administrativas dejen de depender de una sola EOA. El mecanismo
> on-chain es `sc/src/GovernanceMultisig.sol` (M-de-N + timelock) y su despliegue
> `sc/script/DeployGovernance.s.sol`.

### 8.1 Despliegue

```bash
cd rwa-sc/sc
GOVERNANCE_OWNER_1=0x... GOVERNANCE_OWNER_2=0x... GOVERNANCE_OWNER_3=0x... \
GOVERNANCE_THRESHOLD=2 GOVERNANCE_DELAY=86400 \
forge script script/DeployGovernance.s.sol:DeployGovernance \
  --rpc-url "$RPC_URL" --broadcast --keystore <path> --password-file <path>
```

Los owners deben ser **custodios de claves distintos** (D-021) y `GOVERNANCE_DELAY` ≥ 24 h.

### 8.2 Entrega de roles (por cada contrato administrado)

1. Desde el multisig, proponer y ejecutar `grantRole(<ROL>, <multisig>)` sobre el contrato:
   `propose(contrato, 0, abi.encodeCall(AccessControl.grantRole, (ROL, multisig)))` + `approve` ×
   umbral + esperar el timelock + `execute`.
2. Verificar con `cast call contrato 'hasRole(bytes32,address)(bool)' <ROL> <multisig>` → `true`.
3. El owner EOA **renuncia** a su rol con `renounceRole(<ROL>, <eoa>)`.
4. Repetir para `DEFAULT_ADMIN_ROLE`, `AGENT_ROLE` y `COMPLIANCE_ROLE` en token, registries y
   factories (conceder el rol admin de las factories al multisig antes de renunciar).

### 8.3 Mantenimiento del propio multisig

Añadir/quitar owners, cambiar el umbral o el delay se hace **por propuesta auto-dirigida**
(`target = address(multisig)`), nunca con una llamada directa (`onlySelf`). El umbral no puede
exceder el número de owners.

### 8.4 Checklist de gobernanza

- [ ] Owners distintos, con custodia y rotación documentadas.
- [ ] `threshold` ≥ 2 y `delay` ≥ 24 h.
- [ ] `hasRole(ROL, multisig) == true` en todos los contratos administrados.
- [ ] EOA sin roles (`hasRole(ROL, eoa) == false`) tras `renounceRole`.
- [ ] Procedimiento de recuperación de claves de los owners probado.
- [ ] Multisig y script auditados antes de producción (D-024).

---

## 9. Referencias

- `RepoTecnico/requerimientos.md` — D-019 (líneas 129-130), D-037, D-009/RT-008 (línea 95).
- `RepoTecnico/documento_tecnico.md` — ciclo de vida (§8.2.1, líneas 270, 775, 789).
- `rwa-sc/sc/script/DeployFullStack.s.sol` y `rwa-sc/sc/script/deploy.sh` — despliegue y verificación canónicos.
- `rwa-sc/sc/script/ci/run_local_ci.sh` y `rwa-sc/.gitlab-ci.yml` — pipeline.
- `rwa-sc/SECURITY.md` y `rwa-sc/CHANGELOG_ABIS.md` — modelo de amenazas y control de deriva de ABIs.
