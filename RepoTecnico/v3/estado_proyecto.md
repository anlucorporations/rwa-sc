# Estado del Proyecto — RWA v3 «Barlo Metaplace»

> **Última actualización:** 2026-11-02 · **Fase actual:** 2 (Auditoría)
> **Estado de la Fase 1:** 🔴 **EN CORRECCIÓN / RE-AUDITORÍA — NO cerrada.**
> **Carpeta de reportes:** `RWA/RepoTecnico/` (v3) · **Documentación v2:** `rwa-sc/RepoTecnico/` y `rwa-web/RepoTecnico/`

## 1. Resumen

| Campo | Valor |
|---|---|
| Proyecto | RWA v3 «Barlo Metaplace» |
| Entrada | `RepoTecnico/BRIEF_BARLOBLOKCHAIN_v3.md` (32 líneas) |
| Base heredada | RWA v2 desplegada en GCP (`mcc-ecommerce`, `europe-west1`): 3 apps + indexer + Anvil + Cloud SQL |
| Respaldo de partida | `/home/dsh/workspace/backups/rwa-v2-backup-20261031T171645Z.zip` (105 MB, SHA-256 en el manifiesto) |
| Esquema de datos | `rwa` **26 tablas** · versión de esquema **3.0** · revisión documental **v3.1** |
| Compuerta de cierre | **0 CUMPLE / 11 PARCIAL / 3 NO CUMPLE** (re-auditoría 2026-11-02) → **no se pasa a Fase 2** |

## 2. Artefactos

| Artefacto | Estado | Contenido |
|---|---|---|
| `requerimientos.md` | ✅ v3.1 | **28 RF · 14 RNF · 8 RT**; supuestos **S-1…S-13** |
| `propuesta_v3.md` | ✅ v3.1 | Lectura del brief, brechas v2, arquitectura, 7 ciclos, riesgos |
| `diccionario_datos.md` | ✅ v3.1 | 26 tablas, tipos, claves, reglas de integridad |
| `diagrama_er.md` | ✅ v3.1 | Mermaid, 5 bloques, 26/26 entidades |
| `base_datos.sql` | ✅ v3.1 | PostgreSQL 15: 26 tablas, 12 enums, triggers, vistas y semillas |
| `migracion_v2_a_v3.sql` | ✅ v3.1 | Archiva 12 tablas v2, ETL y registro `3.0` transaccional |
| `entornos_globales.md` | ✅ v3.1 | Rutas, repos, GCP, BD, variables, toolchain y deuda operativa |
| `verificar_artefactos.py` | ✅ | Script de CI: SQL, cuadre tablas/columnas, Mermaid, versión, recuentos |
| `pruebas/validacion_ejecucion_v3_1.md` | ✅ | Acta de ejecución real: migración (B1) + 16 smoke tests (B2) |
| `INFORME_OPTIMIZACION_V3.md` | 📜 Histórico | 44 hallazgos de la 1ª auditoría |
| `INFORME_CIERRE_V3_1.md` | 📜 Vigente | Re-auditoría de cierre: veredicto NO + compuerta de 14 criterios + B1–B12 |

## 3. Decisiones tomadas

| ID | Decisión | Estado |
|---|---|---|
| D-V3-01 | **Q1:** v3 sustituye a v2 sobre la misma infraestructura (rama `rwa-v3`); v2 congelada | ✅ |
| D-V3-02 | **Q2:** BRLT = ERC-20 de 8 decimales, **utilidad sin valor real** (demo/Anvil) | ✅ |
| D-V3-03 | **Q3:** marketplace v3.0 a **precio fijo** (ofertas/subastas/barter → v3.1) | ✅ |
| D-V3-04 | Los **ISSUER** son datos configurables (`issuer_programs` + `credential_types`) | ✅ |
| D-V3-05 | Deuda de seguridad v2 (RF-011/012/013) se cierra en v3 | ✅ |
| D-V3-06 | **Q4:** comisión **5 %** configurable + fee de tokenización; `FeeCollector` on-chain | ✅ |
| D-V3-07 | **Q5:** **non-custodial** con recuperación asistida y doble aprobación | ✅ |
| D-V3-08 | **Q6:** catálogo solo **BRLT + tokens/NFTs RWA** en v3.0 | ✅ |
| D-V3-09 | **Q7:** jurisdicciones del piloto **LatAm** (VE, CO, PA, MX, CL, PE, AR) | ✅ |
| D-V3-10 | **Q8:** claims **sin caducidad** en v3.0 (revocables) | ✅ |
| D-V3-11 | **Q9:** **tasación documental en BRLT** con tope al precio de listado | ✅ |
| D-V3-12 | **Q10:** retención **30 días tras rechazo / 12 meses tras fin de relación** | ✅ |
| D-V3-13 | **Q11:** Emisor = **rol de plataforma** acotado, persistido por claim | ✅ |
| D-V3-14 | **Q12:** escrow **completo** (reserva con TTL, atomicidad, disputa con árbitro) | ✅ |
| D-V3-15 | **Q13:** **demo/piloto sin activos reales** + gate legal previo a valor real | ✅ |

## 4. Auditoría 1 (`INFORME_OPTIMIZACION_V3.md`, 2026-11-02)

- 7 lentes en paralelo + 7 verificadores adversariales + síntesis.
- 70 hallazgos verificados → **44 únicos** (2 CRÍTICAS · 20 ALTAS · 19 MEDIAS · 3 BAJAS).
- Veredicto: Fase 1 no lista; corregible sin reescribir la propuesta.

## 5. Re-auditoría de cierre (`INFORME_CIERRE_V3_1.md`, 2026-11-02)

- 7 lentes + auditor de compuerta (14 criterios) + 8 verificadores adversariales.
- **Veredicto: NO** — la Fase 1 no puede declararse cerrada ni pasar a casos de uso.
- Compuerta: **0 CUMPLE / 11 PARCIAL / 3 NO CUMPLE**; **11 criterios bloquean** (C1–C7, C9, C10, C13, C14).
- Registro consolidado: **2 CRÍTICAS · 15 ALTAS · 24 MEDIAS · 2 BAJAS** abiertas.
- **2 defectos nuevos introducidos por la corrección anterior:**
  - **N-01 (CRÍTICA):** el trigger global `updated_at` incluía `rwa.orders`, tabla sin esa columna → todo `UPDATE` del escrow abortaba en runtime (el parseo no lo detecta).
  - **N-02 (CRÍTICA):** el ETL de `claim_topics` colisionaba `credential_types.on_chain_topic` (`ACCREDITATION`/`JURISDICTION` v2 vs `ACREDITACION`/`JURISDICCION` v3) → la migración abortaba.
- Cerrados en la corrección previa: H-03, H-08 (esencial), H-09, H-21, H-30; H-42 descartado como falso positivo.

## 6. Correcciones aplicadas tras la re-auditoría (2026-11-02)

| ID | Corrección | Evidencia |
|---|---|---|
| **N-01** | `orders.updated_at` añadido (y al diccionario/ER); trigger global seguro | `base_datos.sql`, `verificar_artefactos.py` |
| **N-02** | ETL determinista de `claim_topics`: alias canónicos, `on_chain_topic` NULL, `active` preservado; `DROP VIEW` previo de la vista v2 | `migracion_v2_a_v3.sql` §3–§4.1 |
| **N-03** | ETL de tokens: `price` NULL/0 ya **no** se convierte en 0 BRLT (respeta `CHECK > 0`) | `migracion_v2_a_v3.sql` §4.6 |
| **N-04** | Emisores semilla para `onboarding-socio` y `legacy-v2` (SOCIO puede emitirse/aprobarse) | `base_datos.sql` semillas |
| **N-05** | Trigger `trg_claim_issuer_program`: el emisor debe pertenecer al programa del claim | `base_datos.sql` §10.5b |
| **N-06** | Cascada de revocación cierra listings y cancela órdenes; trigger impide publicar activo no acuñado o sin Garantía+Fiador | `base_datos.sql` §10.5c |
| **N-07** | Claims migrados marcados como `legacy_unverified` en `metadata` | `migracion_v2_a_v3.sql` §4.4 |
| **N-09** | Semillas/ETL preservan `active=false` de topics reservados | `migracion_v2_a_v3.sql` §4.1 |
| **N-10** | Índices únicos `lower(address)` / `lower(wallet_address)` (evita duplicados por checksum) | `base_datos.sql` §9 |
| **Q10** | Retención ejecutable en DDL: +30 días al rechazar y +12 meses al cerrar relación (`identities.ended_at`) | `base_datos.sql` §10.5, §10.5d |
| **N-12** | Recuento de tablas v2 corregido a **12** en propuesta y estado | `propuesta_v3.md`, este documento |
| **N-13** | Origen de RF-V3-24…28 y RNF-V3-12…14 declarado como auditoría/decisiones, no como brief | `requerimientos.md` §6 |
| **N-14** | RNF-V3-01 reformulado a «0 endpoints **de escritura** sin autenticación» | `requerimientos.md` |
| **N-17** | Cabeceras unificadas: revisión documental v3.1 / esquema 3.0 | todos los artefactos |
| **B11** | Script de verificación automática (SQL, cuadre, Mermaid, versión, recuentos) | `verificar_artefactos.py` |

## 7. Verificación posterior (ejecutada)

| Comprobación | Resultado |
|---|---|
| `python3 RepoTecnico/verificar_artefactos.py` | ✅ **PASS** |
| SQL `base_datos.sql` | ✅ 153 sentencias parseadas |
| SQL `migracion_v2_a_v3.sql` | ✅ 37 sentencias parseadas |
| Tablas y columnas | ✅ 26/26 tablas y 0 discrepancias de columnas |
| Mermaid | ✅ 5 bloques, 0 errores |
| Versión operativa | ✅ única (`3.0`) |
| Requisitos | ✅ 28 RF · 14 RNF · 8 RT · S-1…S-13 |

## 8. Compuerta de re-cierre (B1–B12) — estado real

| ID | Criterio | Estado | Qué falta |
|---|---|---|---|
| **B1** | Migración ejecutable y probada sobre `pg_dump` v2 real | 🟢 **VERIFICADO EN TEST** | Ejecutada en PostgreSQL 16 embebido sobre el esquema v2 canónico + datos sintéticos: `exit 0`, claims 2=2, docs 1=1, tokens 1=1 ([acta](pruebas/validacion_ejecucion_v3_1.md)). Queda repetirla en CI con el dump real |
| **B2** | DDL ejecutable (smoke `UPDATE` por tabla con trigger) | 🟢 **VERIFICADO** | **16/16 smoke tests** PASS, incluido `UPDATE orders` (N-01) y 4 pruebas negativas ([acta](pruebas/validacion_ejecucion_v3_1.md)) |
| **B3** | Escrow verificable (máquina de estados, job de expiración, tramo NFT, validaciones) | 🔴 **ABIERTO** | Diseño en C4: transiciones, job, atomicidad y pruebas negativas |
| **B4** | Autoridad del Emisor (vínculo emisor↔programa + semillas) | 🟢 **CUBIERTO EN DDL** | E2E de alta pendiente de runtime |
| **B5** | RBAC real (Issuer/Auditor/Árbitro/Soporte, `role_assignments`, cuentas por rol) | 🔴 **ABIERTO** | Modelo de roles y semillas por rol |
| **B6** | Compliance on-chain (hooks `_update`/`beforeTokenTransfer`) | 🔴 **ABIERTO** | Diseño e implementación en C3 |
| **B7** | Retención Q10 ejecutable (cálculo, `ended_at`, job de purga, tests) | 🟡 **PARCIAL** | Cálculo + `ended_at` en DDL ✅; **job de purga** y test pendientes (C1) |
| **B8** | Operación documentada (backup/PITR, claves, pooling, RPC respaldo, coste) | 🔴 **ABIERTO** | Plan concreto y ensayo de restauración |
| **B9** | RNF falsables (12 rutas, axe, p95, pico S-14, SLI) | 🟡 **PARCIAL** | Enumerar rutas, condiciones de medición y supuesto de capacidad |
| **B10** | Estado único y compuerta honesta | 🟢 **HECHO** | Este documento regenerado desde los artefactos |
| **B11** | Trazabilidad automatizada y script en CI | 🟢 **HECHO** | `verificar_artefactos.py`; falta integrarlo en el pipeline |
| **B12** | 14/14 criterios CUMPLE, 0 CRÍTICAS y 0 ALTAS | 🔴 **no cumplido** | Requiere cerrar B1–B9 y re-auditar |

**Conclusión:** la corrección eliminó los 2 defectos nuevos críticos; **B1 y B2 ya están verificados por ejecución real** (migración + 16 smoke tests). La compuerta **aún no está superada**: quedan B3 (escrow), B5 (RBAC), B6 (compliance on-chain), B8 (operación) y los parciales B7/B9. La Fase 1 sigue **en corrección**.

## 9. Próximos pasos

1. ~~Ejecutar la migración y los smoke tests en un entorno PostgreSQL~~ ✅ (B1/B2 verificados en test; ver `pruebas/validacion_ejecucion_v3_1.md`). Repetir en CI con el `pg_dump` real.
2. **Diseñar/decidir** B3 (escrow), B5 (roles) y B6 (compliance on-chain) en los ciclos C4/C5/C3.
3. **Documentar** B8 (backup/PITR, claves, pooling, coste) y B9 (rutas, métricas, pico).
4. **Re-auditoría final** de compuerta; solo con 14/14 CUMPLE y 0 CRÍTICAS/0 ALTAS se pasa a casos de uso + documento técnico.

## 10. Estado heredado de la v2 (referencia)

| Línea | Estado |
|---|---|
| Contratos (`rwa-sc`) | 16 contratos fuente; 10 desplegados en Anvil GCP (bloque 549); CI 7/7 en verde |
| Web (`rwa-web`) | 3 apps + indexer; 42 tests; E2E contra Anvil GCP en verde; Cloud Run tag `20261029-174915` |
| Datos | Esquema `rwa` v2 con **12 tablas** en Cloud SQL; migraciones 1.0–1.2 |
| Brechas v2 | RF-011/012/013, alertas del indexer, auditoría externa |
