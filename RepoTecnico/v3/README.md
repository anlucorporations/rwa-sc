# RWA v3 «Barlo Metaplace» — paquete documental de Fase 1

> **Estado:** Fase 1 **en corrección / NO cerrada** (re-auditoría de cierre 2026-11-02).
> **Esquema de datos:** versión `3.0` · revisión documental `v3.1` · rama `rwa-v3`.

## Contenido

| Archivo | Rol |
|---|---|
| `BRIEF_BARLOBLOKCHAIN_v3.md` | Brief de entrada del cliente |
| `requerimientos.md` | 28 RF · 14 RNF · 8 RT · supuestos S-1…S-13 |
| `propuesta_v3.md` | Lectura del brief, brechas vs v2, arquitectura, 7 ciclos |
| `diccionario_datos.md` | 26 tablas, tipos, claves y reglas de integridad |
| `diagrama_er.md` | Entidad-Relación en Mermaid (5 bloques, 26 entidades) |
| `base_datos.sql` | Esquema PostgreSQL 15 (26 tablas, 12 enums, triggers, semillas) |
| `migracion_v2_a_v3.sql` | Migración v2→v3 (archiva 12 tablas, ETL, registra `3.0`) |
| `entornos_globales.md` | Rutas, repos, GCP, BD, variables y deuda operativa |
| `estado_proyecto.md` | Estado real del proyecto y compuerta de re-cierre |
| `INFORME_OPTIMIZACION_V3.md` | 1ª auditoría (44 hallazgos) |
| `INFORME_CIERRE_V3_1.md` | Re-auditoría de cierre (veredicto NO + criterios B1–B12) |
| `pruebas/validacion_ejecucion_v3_1.md` | Acta: migración ejecutada + 16/16 smoke tests |
| `verificar_artefactos.py` | Verificación automática de artefactos (CI) |

## Verificación

```bash
python3 RepoTecnico/v3/verificar_artefactos.py
# RESULTADO: PASS — todos los artefactos cuadran.
```

## Reglas

- `main` permanece intacta; la v2 queda congelada como referencia y plan de retorno.
- Sin push sin orden explícita (`/push`).
- Los tres artefactos de datos (`diccionario_datos.md`, `diagrama_er.md`, `base_datos.sql`)
  se actualizan **juntos** en el mismo cambio.
