# Evidencia — H-06 / R-7 · Adopción de la gobernanza (multisig + timelock)

> **Fecha:** 2026-10-24 · **Área:** `@sc` (contratos) · **Hallazgos:** H-06, R-7 · **Decisión:** D-021
> **Estado:** ✅ **Adopción automatizada y drill end-to-end en verde** · ⏳ pendiente: auditoría externa del multisig (D-024) y decisión de producto sobre `IdentityRegistry`.

---

## 1. Qué se ha implementado

| Artefacto | Función |
|---|---|
| `sc/script/AdoptGovernance.s.sol` | **Adopción**: transfiere `Ownable` de los contratos administrados al `GovernanceMultisig` y entrega los roles `AccessControl` del token, con la EOA renunciando a ellos. Preflight (multisig con código, `threshold ≥ 2`, `owners ≥ 3`, `delay ≥ 24 h` salvo drill) y **verificación en cerrado** de todas las postcondiciones. |
| `sc/script/adopt_governance.sh` | **Wrapper operativo**: valida red (`cast chain-id`), valida el multisig, usa **keystore efímero** (la clave nunca pasa por `argv`), ejecuta el script y hace una **verificación independiente con `cast`**. Soporta `ADOPT_SKIP_IDENTITY_REGISTRY=1` para excluir el registro operativo de identidades. |
| `sc/script/ci/test_adopt_governance.sh` | **Drill end-to-end** sobre Anvil efímero: despliegue completo → multisig 2-de-3 → adopción → comprobaciones → operación timelocked del multisig. No toca el despliegue canónico ni deja artefactos. |
| `sc/script/ci/run_local_ci.sh` | Paso opt-in `h06-governance` (`RUN_H06_DRILL=1`). |

## 2. Drill ejecutado (Anvil efímero, chain 31337)

```bash
cd rwa-sc/sc
./script/ci/test_adopt_governance.sh
```

Resultado real del snapshot 2026-10-24:

```
▶ 1/6 · Anvil efímero en http://127.0.0.1:8555
✓ Anvil listo (chain 31337)
▶ 2/6 · Despliegue completo del stack (EOA admin)
✓ Stack desplegado · token=0xE451980132E65465d0a498c53f0b5227326Dd73F · identityRegistry=0x5FbDB2315678afecb367f032d93F642f64180aa3
▶ 3/6 · Despliegue del GovernanceMultisig (2-de-3, delay 10 s para el drill)
✓ Multisig desplegado: 0x68B1D87F95878fE05B998F19b66F4baba5De1aed (2-de-3, delay 10 s)
▶ 4/6 · Adopción: propiedad y roles al multisig; la EOA renuncia
✓ Adopción completada y verificada (script + cast)
▶ 5/6 · La EOA ya NO puede administrar directamente
✓ La EOA no puede administrar el token (revert esperado)
▶ 6/6 · Operatividad de la gobernanza: propuesta -> aprobaciones -> timelock -> execute
✓ Gobierno operativo: AGENT_ROLE concedido por el multisig tras timelock
✓ DRILL H-06 EN VERDE: adopción completa + gobernanza operativa
```

**Postcondiciones verificadas** (el drill falla si alguna no se cumple):

- `owner() == multisig` en: `IdentityRegistry`, `TrustedIssuersRegistry`, `TokenCloneFactory`, `IdentityCloneFactory`, `ClaimTopicsRegistryCloneFactory`, `ComplianceAggregator`, `ClaimTopicsRegistry` y el módulo `MaxBalanceCompliance` (los módulos opcionales se adoptan si existen).
- `hasRole(DEFAULT_ADMIN_ROLE|AGENT_ROLE|COMPLIANCE_ROLE, multisig) == true` en el token.
- `hasRole(ROL, EOA) == false` para los tres roles (la EOA renunció).
- La EOA **ya no puede** ejecutar `grantRole` directamente (revert esperado).
- **Gobernanza operativa:** propuesta `#1` (`grantRole(AGENT_ROLE, operador)`), 2 aprobaciones, timelock y `execute` → `hasRole(AGENT_ROLE, operador) == true`.

## 3. Aplicación al despliegue canónico (procedimiento)

> **No ejecutado sobre el Anvil de GCP**: la adopción es una operación **irreversible** de gobernanza y requiere decisión explícita del usuario. El script está listo y validado; el procedimiento es el del `RUNBOOK_MIGRACION.md` §8.

```bash
cd rwa-sc/sc
source /home/dsh/workspace/gcp-env.sh            # RPC_URL + clave admin
# 1) Desplegar el multisig (owners custodios reales, threshold 2, delay >= 24 h)
GOVERNANCE_OWNER_1=0x... GOVERNANCE_OWNER_2=0x... GOVERNANCE_OWNER_3=0x... \
GOVERNANCE_THRESHOLD=2 GOVERNANCE_DELAY=86400 \
forge script script/DeployGovernance.s.sol:DeployGovernance --rpc-url "$RPC_URL" --broadcast ...

# 2) Adoptar (una sola orden; verificación incluida)
GOVERNANCE_MULTISIG=0x... sc/script/adopt_governance.sh
```

> ⚠️ **Impacto cross-línea:** `IdentityRegistry.registerIdentity` es `onlyOwner` (D-105). Tras adoptar, **el alta de identidades desde `@web` requerirá una propuesta del multisig** (propuesta + umbral + timelock). Si se quiere mantener un operador ágil, usar `ADOPT_SKIP_IDENTITY_REGISTRY=1` y documentar la excepción, o abrir una etapa para añadir un rol operativo de registro en `IdentityRegistry`.

## 4. Checklist de gobernanza (RUNBOOK §8.4)

| Ítem | Estado |
|---|---|
| Owners distintos con custodia/rotación documentadas | ⏳ operativo (definir custodios reales antes de producción) |
| `threshold ≥ 2` y `delay ≥ 24 h` | ✅ validado por el script (drill usa 10 s con `ALLOW_SHORT_DELAY=1`) |
| `hasRole(ROL, multisig) == true` en todos los contratos | ✅ verificado por el drill |
| EOA sin roles tras `renounceRole` | ✅ verificado por el drill |
| Recuperación de claves de owners probada | ⏳ pendiente (H-30/RNF-505) |
| Multisig y script auditados antes de producción (D-024) | ⏳ **auditoría externa pendiente** |

## 5. Reproducibilidad

```bash
cd rwa-sc/sc
forge build
forge test                    # 443/443 tests (snapshot 2026-10-24)
RUN_H06_DRILL=1 ./script/ci/run_local_ci.sh   # incluye el drill
```
