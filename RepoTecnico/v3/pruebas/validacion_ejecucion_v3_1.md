# Acta de validación de ejecución — esquema v3.1

> **Fecha:** 2026-11-02 · **Objetivo:** cerrar B1 y B2 del `INFORME_CIERRE_V3_1.md`
> (migración ejecutable y DDL ejecutable) con **evidencia reproducible**, no solo con parseo.
> **Entorno:** PostgreSQL **16.15** embebido (`pgserver` / binarios en `~/.local/.../pginstall`),
> sin root, en `/tmp`, puerto 55432, `trust`. No había `psql`/PostgreSQL del sistema ni Docker.

## 1. Procedimiento

```bash
# 1) servidor temporal
initdb -D /tmp/rwadata -U postgres -A trust
pg_ctl -D /tmp/rwadata -o "-p 55432 -k /tmp -c listen_addresses=''" -l /tmp/rwa.log start
psql -h /tmp -p 55432 -U postgres -c "CREATE DATABASE rwa_test;"

# 2) cargar el esquema v2 CANÓNICO del repositorio
psql -d rwa_test -v ON_ERROR_STOP=1 -f rwa-sc/RepoTecnico/base_datos.sql

# 3) datos sintéticos v2 (1 emisor, 2 claims [1 pending + 1 approved], 1 documento,
#    1 token, 1 topic requerido, 1 módulo, 1 sesión, 1 auditoría, 1 evento, 1 indexer_state)

# 4) ejecutar la migración
psql -d rwa_test -v ON_ERROR_STOP=1 -f migracion_v2_a_v3.sql

# 5) smoke tests de runtime + pruebas negativas
```

**Shims necesarios (solo para el entorno de prueba, no en el repo):**
1. `CREATE EXTENSION pgcrypto` → comentado: el PostgreSQL embebido no trae `contrib`. Se sustituye
   `digest(x,'sha256')` por `sha256(x)` (función **core** de PostgreSQL ≥ 11). `gen_random_uuid()`
   es core desde PostgreSQL 13. **No** se alteró ninguna definición de tabla, trigger o constraint.

## 2. Resultado de la migración (B1)

| Comprobación | Resultado |
|---|---|
| Carga del esquema v2 canónico | ✅ OK (12 tablas + 1 vista) |
| `migracion_v2_a_v3.sql` | ✅ **EXIT 0**, `COMMIT` |
| Claims | ✅ v2=2 → v3=2 |
| Documentos | ✅ v2=1 → v3=1 |
| Tokens | ✅ v2=1 → v3=1 |
| Archivo de tablas v2 | ✅ 12 tablas renombradas `*_v2`, índices y secuencias renombrados sin colisión |
| Vista v2 | ✅ `v_claim_request_summary` eliminada antes de crear la de v3 |
| Versión | ✅ `schema_migrations` registra `3.0` |

> Sin los arreglos N-01/N-02/N-03 esta ejecución **abortaba**; con ellos completa y los conteos
> cuadran. La migración es transaccional: cualquier fallo deja la BD intacta (rollback verificado
> en el ensayo del auditor, `exit=3`).

## 3. Smoke tests de runtime (B2) — 16/16 PASS

| # | Prueba | Esperado | Resultado |
|---|---|---|---|
| 1 | `UPDATE identities` (trigger `updated_at`) | OK | ✅ |
| 2 | `UPDATE claim_requests` | OK | ✅ |
| 3 | `UPDATE tokens` | OK | ✅ |
| 4 | **`UPDATE orders` (N-01)** | OK | ✅ |
| 5 | Aprobar claim sin verificación del Operador | Rechazo | ✅ bloqueado (además por emisor↔programa) |
| 6 | Recuperación con el mismo aprobador (4-eyes) | Rechazo | ✅ `recovery_four_eyes` |
| 7 | Emisor de otro programa firma un claim | Rechazo | ✅ `trg_claim_issuer_program` |
| 8 | Publicar activo en `draft` sin Garantía+Fiador | Rechazo | ✅ `trg_validate_listing_token` |
| 9 | Alias `ACCREDITATION`→`ACREDITACION` (N-02) | OK | ✅ |
| 10 | Topics reservados (`ENVIRONMENTAL`) conservan `active=false` (N-09) | OK | ✅ |
| 11 | Token migrado en `draft` (no se presenta como acuñado) | OK | ✅ |
| 12 | `document_files.sha256` en hex de 64 | OK | ✅ |
| 13 | `chain_events` con `chain_id` | OK | ✅ |
| 14 | `indexer_state` singleton con `chain_id` | OK | ✅ |
| 15 | Claims migrados con `legacy_unverified=true` (N-07) | OK | ✅ |
| 16 | Objetos del esquema `rwa` (26 tablas + vistas) | OK | ✅ |

## 4. Limitaciones declaradas

- **Dataset sintético**, no el `pg_dump` real de Cloud SQL. B1 exige repetirlo en CI contra el dump
  real antes de tocar el entorno canónico; este acta demuestra que el script **ejecuta**.
- **No se ejecutaron** los contratos (Anvil/Foundry) ni los jobs de Cloud (purga, indexer):
  pertenecen a C0–C4.
- El shim de `pgcrypto` es una diferencia de entorno conocida; en Cloud SQL la extensión está
  disponible y el script del repo la usa tal cual.
- El PostgreSQL embebido es 16; el objetivo es 15 (sin diferencias de sintaxis usadas).

## 5. Conclusión

- **B1:** ✅ **verificado en entorno de prueba** (migración ejecuta y los conteos cuadran); queda
  repetirlo en CI contra el dump real.
- **B2:** ✅ **verificado** (16/16 smoke tests, incluido el `UPDATE` de `orders` que fallaba).
- Estado de la compuerta de re-cierre: **B1/B2 pasan de PENDIENTE a VERIFICADO (test)**; siguen
  abiertos B3, B5, B6, B8 y parciales B7/B9.
