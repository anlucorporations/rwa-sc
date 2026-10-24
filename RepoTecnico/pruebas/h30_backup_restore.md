# Evidencia — H-30 · Backup/DR y continuidad on-chain (RNF-501…505)

> **Fecha:** 2026-10-24 · **Área:** `@sc` (contratos) · **Hallazgo:** H-30 (R-5) · **RNF:** 501–505
> **Estado:** ✅ **Backup y restauración implementados y ensayados (RNF-503 cerrado)** · ⏳ pendiente: ejecución periódica contra el Anvil canónico (requiere admin RPC) y custodia/rotación de claves (RNF-505, ligada a R-7).

---

## 1. Qué se ha implementado

| Artefacto | Función |
|---|---|
| `sc/script/backup_state.sh` | Backup verificable: volcado completo del estado on-chain (`anvil_dumpState`), copia del artefacto de despliegue, `metadata.json` (chainId, bloque, timestamp, cliente) y `MANIFEST.sha256`. |
| `sc/script/restore_state.sh` | Restauración sobre un nodo Anvil limpio (`anvil_loadState`), verificación de integridad del manifiesto, del bloque y (opcional) de contratos/roles/datos; **mide el RTO**. |
| `sc/script/ci/test_backup_restore.sh` | Drill end-to-end: despliegue → backup → caída simulada → nodo nuevo → restauración verificada → comprobaciones independientes y RPO/RTO. |
| `sc/script/ci/run_local_ci.sh` | Paso opt-in `h30-backup` (`RUN_H30_DRILL=1`). |

> **Nota técnica:** el volcado de estado ronda cientos de KB y **supera el límite de `argv`** (`MAX_ARG_STRLEN` ≈ 128 KB). Por eso `restore_state.sh` envía `anvil_loadState` por HTTP JSON-RPC (Python `urllib`), no como argumento de `cast`.

## 2. Drill ejecutado (Anvil efímero, chain 31337)

```bash
cd rwa-sc/sc
./script/ci/test_backup_restore.sh
```

Resultado real del snapshot 2026-10-24:

```
▶ 1/6 · Anvil efímero + despliegue completo
✓ Stack desplegado en bloque 4 · token=0xE451980132E65465d0a498c53f0b5227326Dd73F
▶ 2/6 · Backup (estado + artefacto + manifiesto)
✓ Backup: 216K de estado · bloque 4
▶ 3/6 · Pérdida simulada del nodo
✓ Nodo caído (estado perdido)
▶ 4/6 · Nodo nuevo + restauración verificada
✓ Restauración verificada en 484 ms
▶ 5/6 · Comprobaciones independientes del estado restaurado
✓ Datos on-chain restaurados: bloque, token, identidad y topes
▶ 6/6 · RPO/RTO del ensayo
{ "rpo": "bloque del backup (4)", "block": 4, "rtoMs": 484, "rtoTargetMs": 14400000, "rtoOk": true }
✓ DRILL H-30 EN VERDE: backup, pérdida, restauración verificada y RTO dentro de objetivo
```

**Comprobado tras restaurar:** mismo bloque, `token.name() == "RWA Demo Token"`, identidad del deployer registrada, `maxBurnPerTx` correcto, y código en todos los contratos del artefacto.

## 3. Mapeo a los RNF

| RNF | Criterio | Estado |
|---|---|---|
| **RNF-501** | RPO ≤ 24 h (BD off-chain con backup diario/PITR; on-chain con snapshot) | ✅ on-chain: el backup fija el bloque (RPO = último backup). Off-chain: cubierto por `rwa-web` (`scripts/backup_o5.mjs`, Cloud SQL). |
| **RNF-502** | RTO ≤ 4 h | ✅ ensayado: **484 ms** en Anvil local (holgado); en producción depende del host. |
| **RNF-503** | Restauración ensayada y documentada | ✅ **cerrado** con este ensayo (fecha 2026-10-24). |
| **RNF-504** | Runbook de recuperación on-chain / redeploy limpio | ✅ `RUNBOOK_MIGRACION.md` (§9 backup/DR + §3/§6 redeploy y rollback). |
| **RNF-505** | Custodia de claves con rotación | 🟡 procedimiento ligado a R-7 (multisig + custodios); definir custodios reales y probar recuperación de claves. |

## 4. Operación contra el Anvil canónico (pendiente de ejecución)

```bash
cd rwa-sc/sc
source /home/dsh/workspace/gcp-env.sh
DEPLOYMENT_JSON=sc/deployments/31337-20261023T185622Z.json ./script/backup_state.sh
# programar (p. ej. cron diario) y conservar 12+ meses (RNF-403)
```

> **Requisito:** el nodo debe exponer los métodos admin de Anvil (`anvil_dumpState`/`anvil_loadState`) y ser accesible para el proceso de backup. Si el Anvil canónico **no** los expone, el plan de recuperación es el **redeploy limpio** desde el artefacto versionado (RUNBOOK §3/§6): RTO mayor, pero reproducible. El drill valida la ruta principal; conviene añadir un ensayo periódico del redeploy limpio.

## 5. Reproducibilidad

```bash
cd rwa-sc/sc
./script/ci/test_backup_restore.sh          # drill completo
RUN_H30_DRILL=1 ./script/ci/run_local_ci.sh  # dentro del CI local
```
