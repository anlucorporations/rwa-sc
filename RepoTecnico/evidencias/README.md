# Evidencias — Verificación independiente de hallazgos críticos

> Verificación hecha por el Lead del proyecto (no por los agentes auditores) para confirmar los dos
> hallazgos de mayor impacto del [INFORME_OPTIMIZACION_V1.md](../INFORME_OPTIMIZACION_V1.md).
> Fecha: 2026-10-03.

## Qué se verificó

| Hallazgo | Qué demuestra el PoC | Resultado |
|---|---|---|
| **H-01** (Crítica) | ~~Un claim con **firma vacía** (`""`) es aceptado por `addClaim`~~ **INVERTIDO en el Ciclo 2 (RF-001)**: con la verificación EIP-712, la firma vacía **revierte** y `isVerified()` sigue devolviendo `false`; una firma válida del issuer sí crea el claim. | `[PASS] test_H01_claim_forjado_firma_vacia_revierte` + `[PASS] test_H01_claim_con_firma_valida_aceptado` |
| **H-05** (Alta) | Sin `claimTopicsRegistry` configurado, `isVerified()` devolvía `true` para una identidad **sin ningún claim** (fail-open). **INVERTIDO en el Ciclo 6 (RF-011)**: ahora devuelve `false` (fail-closed). | `[PASS] test_H05_isVerified_fail_closed_ok` |

El PoC de H-01 ya **no** reproduce la vulnerabilidad: el caso negativo revierte y el positivo exige firma EIP-712 válida. El de H-05 **también está corregido** desde el Ciclo 6/RF-011: sin política de topics `isVerified()` devuelve `false`.
Salida completa en [`salida_poc.txt`](salida_poc.txt).

> **Traza histórica:** la salida **pre-corrección** (claim con firma vacía **aceptado**) quedó registrada en
> [`INFORME_OPTIMIZACION_V1.md`](../INFORME_OPTIMIZACION_V1.md) §5 (H-01, test `test_ForgedClaimEmptySignature`)
> y en `metricas_ejecucion.md` §3.1. `salida_poc.txt` refleja el estado **posterior** al Ciclo 2.

## Cómo reproducir

```bash
export PATH="$HOME/.foundry/bin:$PATH"
rm -rf /tmp/rwa-poc
cp -r /home/dsh/workspace/RWA/rwa-sc/sc /tmp/rwa-poc          # copia aislada: no se toca el proyecto
cp /home/dsh/workspace/RWA/RepoTecnico/evidencias/PoC_H01_H05.t.sol /tmp/rwa-poc/test/
cd /tmp/rwa-poc && forge test --match-path test/PoC_H01_H05.t.sol -vv
```

## Uso en las fases siguientes

- **Fase 3 (RF-001 / RF-011):** estos PoC se **invierten** en pruebas de regresión negativas
  (con EIP-712 el claim forjado debe revertir; con el fail-closed de `isVerified` el caso H-05 debe devolver `false`).
- **Fase 4:** el criterio de aceptación B-1/B-2 del informe exige que "el PoC de forja falle" tras la corrección;
  estos archivos son la línea base para comprobarlo.

## Nota

El `.sol` de esta carpeta es **evidencia**, no forma parte de la suite del repositorio: no está en
`rwa-sc/sc/test/` y no se ejecuta con `forge test` del proyecto. Se conserva aquí para que la corrección sea
auditable contra el fallo original.
