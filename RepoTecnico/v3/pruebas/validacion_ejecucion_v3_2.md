# Acta de validación de ejecución — v3.2 (ronda de diseño B3/B5/B7)

> **Fecha:** 2026-11-02 · **Objetivo:** verificar en ejecución real los objetos nuevos de la ronda de
> diseño (`diseno_cierre_v3_2.md`): RBAC persistido, máquina de estados del escrow, jobs de expiración
> y purga, y `audit_log` append-only.
> **Entorno:** PostgreSQL **16.15** embebido (`pgserver`), sin root, puerto 55433, base `rwa_v32` limpia.
> **Shim de entorno:** se comenta `CREATE EXTENSION pgcrypto` (el PostgreSQL embebido no trae `contrib`);
> `gen_random_uuid()` y `sha256()` son funciones core. **No se alteró ningún objeto del esquema.**

## 1. Carga del esquema v3.2

| Comprobación | Resultado |
|---|---|
| `base_datos.sql` (v3.2) | ✅ carga completa sin errores |
| Objetos en `rwa` | **31** (27 tablas + 4 vistas) |
| `role_assignments` semilla | **9** (5 de plataforma + 4 por programa) |
| Triggers nuevos | `trg_validate_order_transition`, `trg_set_order_economics`, `trg_validate_payment_payee`, `trg_audit_log_append_only` |
| Funciones de job | `rwa.expire_orders()`, `rwa.purge_expired_documents()` |

## 2. Pruebas de runtime — 19/19 PASS

| # | Prueba | Esperado | Resultado |
|---|---|---|---|
| 1 | Rol `issuer_program` sin programa | Rechazo | ✅ CHECK |
| 2 | Rol activo duplicado | Rechazo | ✅ índice único |
| 3 | Semillas de rol vigentes | 9 | ✅ |
| 4 | `pending_payment → confirmed` | Rechazo | ✅ transición inválida |
| 5 | `pending_payment → escrowed` | Permitido | ✅ |
| 6 | `escrowed → disputed` | Permitido | ✅ |
| 7 | `disputed → refunded` | Permitido | ✅ |
| 8 | `refunded → confirmed` | Rechazo | ✅ |
| 9 | `pending_payment → refunded` | Rechazo | ✅ |
| 10 | Alta de orden: vendedor desde el listing | Correcto | ✅ |
| 11 | Comisión = 500 bps (5 %) | 5,00 BRLT | ✅ |
| 12 | Confirmar sin Garantía+Fiador verificadas | Rechazo (fail-closed) | ✅ |
| 13 | Pago a wallet distinta del vendedor | Rechazo | ✅ |
| 14 | Pago a wallet del vendedor | Permitido | ✅ |
| 15 | `expire_orders()` con reserva vencida | 1 cancelada | ✅ |
| 16 | Estado final de la reserva | `cancelled` | ✅ |
| 17 | `UPDATE audit_log` | Rechazo | ✅ append-only |
| 18 | `DELETE audit_log` | Rechazo | ✅ append-only |
| 19 | `purge_expired_documents()` | 1 borrado, 0 vencidos restantes | ✅ |

> **Nota de transparencia:** en una primera pasada 4 aserciones fallaron **por errores del propio guion
> de prueba** (una prueba esperaba un estado previo distinto y otra usaba subconsultas con la misma
> identidad para comprador y vendedor). Se corrigió el guion y la máquina de estados se re-verificó de
> forma aislada (6/6 PASS). El DDL no requirió cambios.

## 3. Conclusión

- **B5:** ✅ `role_assignments` con ámbitos, unicidad y `audit_log` append-only **verificados en ejecución**.
- **B3:** ✅ máquina de estados, economía de la orden, validación de pago y job de expiración **verificados**.
- **B7:** ✅ `purge_expired_documents()` **verificado** (1 documento vencido borrado, 0 restantes).
- B6 y B8 siguen siendo **especificaciones** (contratos e infraestructura); su implementación/prueba
  corresponde a C3 y a la operación respectivamente.

*Fin del acta v3.2.*

---

## 4. Adenda — correcciones F-04/F-05 (2026-11-04)

Tras la re-auditoría final (`INFORME_CIERRE_V3_2.md`), se corrigieron y **verificaron en ejecución**
los dos hallazgos MEDIA de enforcement del DDL:

| # | Prueba | Esperado | Resultado |
|---|---|---|---|
| 20 | Confirmar una orden **sin** `escrow_tx_hash`, `escrow_asset_tx_hash` y `asset_transferred_at` | Rechazo | ✅ `no se puede confirmar sin los dos tramos del escrow` |
| 21 | Confirmar con ambos tramos del escrow | Permitido | ✅ |
| 22 | `purge_expired_documents()` con 1 `document_file` + 1 `asset_document` vencidos | Devuelve **2** | ✅ |

**Entorno:** PostgreSQL 16.15 embebido, esquema v3.3 (base_datos.sql con `trg_validate_order_transition`
endurecido y `purge_expired_documents` contando ambas tablas), sin root.

*Fin de la adenda.*
