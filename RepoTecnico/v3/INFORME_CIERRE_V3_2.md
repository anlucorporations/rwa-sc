# Informe de Cierre v3.2 — Re-auditoría FINAL de Fase 1 · RWA v3 «Barlo Metaplace»

**Documento:** `RepoTecnico/INFORME_CIERRE_V3_2.md`
**Fecha de emisión:** 2026-11-04
**Rol:** Sintetizador de la re-auditoría FINAL de Fase 1 (Fase 2 de auditoría → compuerta de Fase 1)
**Insumos consolidados:** dictamen de compuerta con los 14 criterios C1–C14 y los 12 criterios B1–B12; dos lentes de verificación adversarial (documental/estado y técnico/DDL-migración) con reproducción de hallazgos; verificación mecánica independiente del script oficial de artefactos; y las actas de ejecución real `pruebas/validacion_ejecucion_v3_1.md` y `pruebas/validacion_ejecucion_v3_2.md`.
**Naturaleza:** informe de cierre. **Auditoría en solo lectura:** no se modificó ningún artefacto auditado; este informe es el único archivo escrito. No se añaden hallazgos que no estén en los dictámenes verificados.
**Regla de evidencia:** todo hallazgo se ancla a `ruta:línea`. Lo no verificable se dictamina PARCIAL o DISEÑO, nunca CUMPLE. **Ante la duda se descarta.**

---

## 1. Veredicto final

### **NO — la Fase 1 NO se puede cerrar.**

No se autoriza el paso a la siguiente etapa (casos de uso + documento técnico) ni el arranque de un piloto. La Fase 1 permanece **«en corrección / re-auditoría»**.

**Compuerta real: 2 CUMPLE (C2, C8) · 11 PARCIAL (C1, C3, C4, C5, C6, C7, C9, C10, C11, C12, C13) · 1 NO CUMPLE (C14).** **Nueve criterios bloquean** el cierre (C1, C3, C4, C5, C6, C7, C9, C10, C14).

**B1–B12:** 2 CERRADO (B2, B9) · 6 DISEÑO (B3, B4, B5, B6, B7, B8) · 4 ABIERTO (B1, B10, B11, B12).

**Justificación en cinco puntos:**

1. **La compuerta no está superada y el propio estado del proyecto lo reconoce.** `estado_proyecto.md:131` declara B12 «no cumplido», y la exigencia de 0 CRÍTICAS / 0 ALTAS abiertas no se satisface (§6).
2. **Lo mecánico cuadra, pero no cierra la compuerta.** El script oficial pasa (PASS, exit 0) y el cuadre es real: 172/40 sentencias SQL, 27/27/27 tablas, 0 discrepancias de columnas, 5 bloques Mermaid, 31 RF · 14 RNF · 8 RT · S-1…S-14 (§3). Pero parsear/ejecutar DDL no demuestra producto, cumplimiento ni trazabilidad.
3. **Persisten brechas ALTAS del registro previo:** H-07 (compliance on-chain), H-10 (consentimiento/estado del Fiador), H-13 (reorg del indexer), H-16 (DPIA), H-22 (jerga/método Flesch) y H-32 (tablas inexistentes en la propuesta).
4. **Hay defectos nuevos verificados por análisis estático:** F-01 (pérdida silenciosa de `token_required_claims` en el ETL), F-02 (documentos que certifican un cierre no verificado) y F-03 (verificación incompleta y fuera de CI), más seis MEDIAS y una BAJA (§6).
5. **Los criterios que dependen de implementación futura se dictaminan DISEÑO/PARCIAL, nunca CUMPLE:** contratos v3 inexistentes en `rwa-sc/sc/src`, jobs cloud no aprovisionados, sin API Metaplace ni E2E de alta, sin API RBAC, sin restore drill ni DPIA.

### Lo que falta (lista de cierre)

| # | Falta | Evidencia / criterio |
|---|---|---|
| 1 | Corregir el alias `ACCREDITATION/JURISDICTION` en §4.7 del ETL y verificar esa tabla (y el conteo de documentos) en §6 | `migracion_v2_a_v3.sql:256-261`, `:318-345`; F-01, C1, B1 |
| 2 | Ejecutar la migración en CI contra el `pg_dump` v2 **real** (hoy solo esquema canónico + datos sintéticos) | `pruebas/validacion_ejecucion_v3_1.md:71-79`; B1 |
| 3 | Unificar estado y cifras en todos los documentos; eliminar «Fase 1 cerrada», «26 tablas», «v3.1/S-1…S-13»; dueño/fecha de S-3 | `diccionario_datos.md:3,5`; `entornos_globales.md:3,85`; `propuesta_v3.md:424-425`; `requerimientos.md:4-6,128,139`; B10, C4 |
| 4 | Extender `verificar_artefactos.py` a trazabilidad brief↔RF y a contradicciones de estado/recuentos, e integrarlo en `.gitlab-ci.yml` | `verificar_artefactos.py:1-140`; sin referencia en `rwa-sc/.gitlab-ci.yml` ni `rwa-web/.gitlab-ci.yml`; B11, C14 |
| 5 | Enforcement en BD del tramo NFT del escrow (los dos hashes) y job cloud real; pruebas de concurrencia/doble venta/TTL/reembolso | `base_datos.sql:450-452`; `diseno_cierre_v3_2.md:56,85-92`; C5, B3 |
| 6 | Retención de `asset_documents` al vender, registro en `audit_log`, vista de vencidos y prueba del camino `ended_at` | `diseno_cierre_v3_2.md:206,213`; `base_datos.sql:1112-1132,1199-1204`; C9, B7 |
| 7 | Modelar consentimiento y estado de garantía del Fiador (H-10) y probar en ejecución la cascada de revocación | `base_datos.sql:380-397,744-795`; C6 |
| 8 | Implementar contratos v3 (`AssetComplianceHook`, `MarketplaceEscrow`, `BarloToken`) con tests adversariales de transferencia | `rwa-sc/sc/src` solo contiene v2; `diseno_cierre_v3_2.md:160-195`; C7, B6 |
| 9 | E2E de alta KYC→SOCIO y API/UX Metaplace | `estado_proyecto.md:123`; C3, B4 |
| 10 | Ejecutar la matriz de autorización (roles × capacidades) y corregir la inconsistencia «8 roles»/9 columnas/enum | `diseno_cierre_v3_2.md:108-121`; `base_datos.sql:98`; C10, B5 |
| 11 | Evidencia operativa: restore drill, rotación de clave, failover RPC, budget alerts | `entornos_globales.md:182-194`; `diseno_cierre_v3_2.md:227-246`; C13, B8 |
| 12 | Cerrar ALTAS documentales/legales y de diseño: H-07, H-13, H-16, H-22, H-32 | §6 |

**Consecuencia operativa:** se mantiene abierto un **ciclo de corrección con compuerta de re-cierre**. Solo con **14/14 CUMPLE y 0 CRÍTICAS/0 ALTAS abiertas** (B12) se pasa a Fase 2 o a piloto.

> **Nota de honestidad:** C12 (modelo documental) y C13 (operación) y los criterios que dependen de gates de ejecución no son por sí solos defectos de producto; son brechas de verificabilidad. Ninguno permite, sin embargo, declarar CUMPLE.

---

## 2. Metodología

### 2.1 Diseño de la re-auditoría final

Re-auditoría **focalizada, adversarial y en solo lectura**, en tres capas:

1. **Compuerta formal (C1–C14 + B1–B12).** Un auditor de compuerta independiente dictaminó los 14 criterios con evidencia `ruta:línea`, verificó la ejecución real del script oficial y contrastó las actas de ejecución contra el DDL y los documentos.
2. **Dos lentes independientes.** Una lente **documental/estado** (coherencia de versiones, recuentos, trazabilidad con el brief, contradicciones de cierre) y una lente **técnica** (DDL, migración, triggers, ETL, retención, RBAC, escrow, contratos). Cada lente recibió los dictámenes previos y los artefactos reales para **verificar, no repetir**.
3. **Verificación adversarial de hallazgos.** Cada defecto nuevo (F-01…F-10) fue contrastado contra el archivo y la línea citada; los que no se pudieron reproducir se descartaron. **Regla aplicada: ante la duda se descarta** — solo llegan a este informe los hallazgos con evidencia verificable en el repositorio.

### 2.2 Tratamiento de la evidencia

| Nivel de evidencia | Veredicto máximo admitido |
|---|---|
| Ejecutado y reproducible con acta (DDL, 19/19 runtime, migración en PostgreSQL 16) | CUMPLE, solo si el criterio se satisface íntegro |
| Documentado pero sin ejecución (contratos, jobs, restore, DPIA, matriz RBAC, E2E) | PARCIAL / DISEÑO |
| Declarado sin verificación o contradicho por los propios artefactos | NO CUMPLE / ABIERTO |

Ningún artefacto auditado fue modificado. Este informe consolidó, deduplicó y dictaminó; no re-auditó dimensiones no cubiertas por los insumos.

### 2.3 Límites declarados

- No hay CI que ejecute la migración contra un `pg_dump` v2 real (`pruebas/validacion_ejecucion_v3_1.md:71-79`): la evidencia de ejecución es sobre esquema canónico + datos sintéticos y shims de entorno (`pgcrypto`→`sha256()`, PostgreSQL embebido).
- No existe API v3, suite Metaplace ni contratos v3: el E2E, la RBAC ejecutada, el tramo NFT y el compliance on-chain **no son verificables en ejecución** hoy.
- No existe acta de restauración, rotación de clave, failover ni alertas activas.

---

## 3. Verificación mecánica (números reales)

**Comando ejecutado:** `python3 RepoTecnico/verificar_artefactos.py` desde `/home/dsh/workspace/RWA` → **exit 0 (PASS)**.

```
[PASS] SQL base_datos.sql — 172 sentencias parseadas
[PASS] SQL migracion_v2_a_v3.sql — 40 sentencias parseadas
[PASS] Tablas SQL = diccionario — 27 SQL / 27 diccionario
[PASS] Tablas SQL = ER — 27 SQL / 27 ER
[PASS] Columnas SQL = diccionario = ER — 0 discrepancias
[PASS] Sintaxis Mermaid — 5 bloques, 0 errores
[PASS] Versión operativa única 3.0 (sin 1.3)
[INFO] Requisitos: 31 RF · 14 RNF · 8 RT · supuestos S-1…S-14
[PASS] Cobertura de requisitos mínima — 31/14/8 (esperado ≥28/14/8)
RESULTADO: PASS — todos los artefactos cuadran.
```

**Recuentos reales:** `base_datos.sql` 172 sentencias · `migracion_v2_a_v3.sql` 40 sentencias · 27 tablas SQL = 27 diccionario = 27 ER · 0 discrepancias de columnas · 5 bloques Mermaid · 31 RF · 14 RNF · 8 RT · S-1…S-14.

**Evidencia de ejecución real registrada en actas (no re-ejecutada por el sintetizador):**

| Comprobación | Resultado | Fuente |
|---|---|---|
| `base_datos.sql` carga completa en PostgreSQL 16.15 | ✅ 31 objetos (27 tablas + 4 vistas) | `pruebas/validacion_ejecucion_v3_2.md:12-18` |
| Trigger `UPDATE orders` (N-01) | ✅ 16/16 smoke tests | `pruebas/validacion_ejecucion_v3_1.md:50-69` |
| Migración v2→v3 sobre v2 canónico | ✅ EXIT 0, COMMIT, claims 2=2, docs 1=1, tokens 1=1 | `pruebas/validacion_ejecucion_v3_1.md:33-48` |
| Rollback de la migración | ✅ verificado | `pruebas/validacion_ejecucion_v3_1.md:46-48` |
| Pruebas de runtime v3.2 (transiciones, economía 500 bps, pago, expiración, append-only, purga) | ✅ 19/19 PASS | `pruebas/validacion_ejecucion_v3_2.md:24-42` |

**Advertencia crítica de lectura:** el PASS es **mecánico**. El propio script no valida trazabilidad brief↔RF ni contradicciones de estado/reccuentos (solo mínimos en `verificar_artefactos.py:125-133`) y no está integrado en CI. **PASS mecánico ≠ cierre de compuerta.**

---

## 4. Compuerta de 14 criterios

| Criterio | Veredicto | Evidencia verificada (resumen) | ¿Bloquea? |
|---|---|---|---|
| **C1** — Migración v2→v3 ejecutable y verificada | **PARCIAL** | Transaccional `BEGIN/COMMIT` (`migracion_v2_a_v3.sql:24,347`), archiva 12 tablas v2 (`:43-54`), renombra índices/secuencias sin colisión (`:58-74`), elimina la vista v2 antes del `\ir` (`:89`), ETL §4 y registro 3.0 (`:304-313`); ejecución real en PostgreSQL 16 con conteos 2=2/1=1/1=1 y rollback (`pruebas/validacion_ejecucion_v3_1.md:33-48,71-79`). **PERO** §4.7 (`:256-261`) une `credential_types.code = upper(claim_topics_v2.code)` sin el alias `ACCREDITATION→ACREDITACION`/`JURISDICTION→JURISDICCION` de §4.1 (`:101-113`) y descarta en silencio los `token_required_claims` de los topics 7/9 del v2 (`rwa-sc/RepoTecnico/base_datos.sql:455-460`); §6 (`:318-345`) no contrasta esa tabla ni el conteo de documentos; `:209` sigue calculando `sha256` del blob cifrado (N-08); no hay CI contra el `pg_dump` v2 real. | **Sí** |
| **C2** — Emisor persistido por claim | **CUMPLE** | `claim_requests.issuer_id` (`base_datos.sql:230`) y CHECK de aprobación que lo exige con firma y revisión (`:247-251`); vínculo emisor↔programa por `trg_claim_issuer_program` (`:851-872`) probado en `pruebas/validacion_ejecucion_v3_1.md:60` (test 7); semillas para los 5 programas incluido SOCIO y legacy-v2 (`:1266-1282,1285-1310,1300-1304,1306-1310`). | No |
| **C3** — Circularidad KYC/SOCIO resuelta y E2E de alta | **PARCIAL** | Circularidad resuelta en DDL: kyc-base emite KYC con emisor propio (`:1266-1269,1285-1288,1312-1317`); onboarding-socio exige KYC previo y emite SOCIO con emisor propio (`:1270-1272,1300-1304,1319-1324,1361-1365`). **Pero** no existe E2E de alta ejecutado: no hay app/API v3 (en `rwa-web/apps` solo identity/indexer/issuer/token v2, sin suite Metaplace) y `estado_proyecto.md:123` declara «E2E de alta pendiente de runtime»; las actas no cubren KYC→SOCIO. | **Sí** |
| **C4** — Estado único y cifras unificadas | **PARCIAL** | `estado_proyecto.md` es honesto (`:4` «EN CORRECCIÓN / RE-AUDITORÍA — NO cerrada»; `:15` 27 tablas; `:22` 31/14/8/S-1…S-14; `:131` B12 no cumplido). **Pero** no hay estado único: `diccionario_datos.md:3,5` «v3.1 … Fase 1 cerrada (Q1–Q10)»; `entornos_globales.md:3` «Fase 1 cerrada con correcciones» y `:85` «26 tablas» (reales 27); `propuesta_v3.md:424-425` «26/26 … Confirmar cierre de Fase 1»; `requerimientos.md:4-6` «v3.1» y «S-1…S-13» pese a S-14 (`:139`); S-3 sigue `[SUPUESTO]` sin dueño/fecha (`:128`). | **Sí** |
| **C5** — Escrow verificable | **PARCIAL** | Columnas de escrow y tramo NFT (`base_datos.sql:441-463,450-452`); índices `ux_orders_open`, `ux_orders_escrow_tx`, `ux_payments_tx` (`:642-653`); máquina de estados `trg_validate_order_transition` (`:989-1018`); vendedor/comisión desde listings/platform_fees (`:1021-1044`); pago solo a wallet del vendedor (`:1047-1071`); precio ≤ tasación (`:722-742,352-354`); `expire_orders()` (`:1092-1109`); 19/19 pruebas de runtime (`pruebas/validacion_ejecucion_v3_2.md:24-42`). **Faltan:** enforcement DB del tramo NFT al confirmar (el diseño lo promete en `diseno_cierre_v3_2.md:56`), job cloud real (`entornos_globales.md:103-112` es plan) y pruebas de concurrencia/doble venta/TTL con reloj simulado/reembolso (`diseno_cierre_v3_2.md:85-92`). | **Sí** |
| **C6** — Controles de garantía y autorización verificados | **PARCIAL** | Fail-closed Garantía+Fiador (`base_datos.sql:694-719`) probado en `pruebas/validacion_ejecucion_v3_2.md:35` (test 12); cascada de revocación que cierra listings y cancela órdenes, N-06 (`:744-795`); 4-eyes real (`:306-319`) probado en `validacion_ejecucion_v3_1.md:59`; anti-autoaprobación y segregación Operador/Admin (`:255-263`) probados en `validacion_v3_1.md:58,61`. **Brechas:** la cascada de revocación no se prueba en ejecución en ninguna acta; H-10 abierto porque `token_guarantees` no modela consentimiento ni estado de garantía aceptada/revocada (`:380-397`) y no hay prueba de «revocación bloquea mercado». | **Sí** |
| **C7** — Compliance on-chain | **PARCIAL** | Solo especificación: hooks `_update`/`beforeTokenTransfer`, `token_required_claims`, `isVerified` fail-closed (`diseno_cierre_v3_2.md:160-195`; `propuesta_v3.md:256`). `token_required_claims` y `token_compliance_modules` existen solo off-chain (`base_datos.sql:364-378`) y ningún trigger/vista/contrato los aplica; no existen contratos v3 en `rwa-sc/sc/src` (solo v2: sin `BarloToken`, `MarketplaceEscrow` ni `AssetComplianceHook`) ni tests adversariales de transferencia. | **Sí** |
| **C8** — RNF falsables y cerrados en el plano documental | **CUMPLE** | Manifiesto de las 12 rutas (`requerimientos.md:167-184`; RNF-V3-04 las referencia en `:93`); axe wcag2aa con 0 violaciones serious/critical y umbrales numéricos (`:93`); p95 con condiciones completas —k6/Artillery, 50 VU 5 min, dataset ≥10k `chain_events`, `min-instances=1`, lectura <800 ms / escritura <1,5 s— (`diseno_cierre_v3_2.md:269-275`); pico S-14 formal (`requerimientos.md:139`); SLI/SLO/error budget (99,5 %, error <1 %, lag indexer <2 bloques) y alertas con dueño (`requerimientos.md:95,102`; `diseno_cierre_v3_2.md:274`). La ejecución de esos gates pertenece a C5. | No |
| **C9** — Retención y purga | **PARCIAL** | Rechazo +30 días (`base_datos.sql:783-787`); fin de relación +12 meses vía `identities.ended_at` (`:216`) con trigger (`:906-926`); `purge_expired_documents()` sobre `document_files` y `asset_documents` (`:1112-1132`), probada con 1 documento borrado (`pruebas/validacion_ejecucion_v3_2.md:42`). **Brechas:** falta trigger que fije `asset_documents.retention_delete_at` al vender (diferido a C1 en `diseno_cierre_v3_2.md:206`); no hay vista de vencidos para `asset_documents` (`:1199-1204` solo `document_files`); la purga no registra `document.purge` en `audit_log` (diseño `:213`) ni cuenta los `asset_documents` borrados (`:1125-1130`); no se prueba el camino `ended_at`; job cloud no aprovisionado (`entornos_globales.md:103-112`). | **Sí** |
| **C10** — RBAC real | **PARCIAL** | `role_assignments` con `principal≠claim` y ámbitos platform/issuer_program (`base_datos.sql:519-544`); 9 semillas (`:1444-1468`); `audit_log` append-only con triggers (`:1074-1087`) verificado en ejecución (`pruebas/validacion_ejecucion_v3_2.md:40-41`, tests 17-18); matriz definida en `diseno_cierre_v3_2.md:108-121` y `propuesta_v3.md:200-212`. **Brechas:** matriz 8 roles × 12 capacidades positivas/negativas no ejecutada (diseño la difiere a C5 en `:149-156`); rótulo «8 roles» inconsistente con 9 columnas y con un enum `session_role` que no incluye Fiador/Usuario (`base_datos.sql:98`); `role_assignments` no es append-only (revocación por `revoked_at`, `:527`). | **Sí** |
| **C11** — Trazabilidad brief↔RF exhaustiva | **PARCIAL** | La tabla §6 no se deriva de la columna «Brief»: `requerimientos.md:150-160` coloca RF-02 (Brief `[procesos generales]` 1, `:33`) bajo `[OBJETIVO]` y lo omite de procesos generales 1; RF-08 (Brief `[WEB-ISSUSER]`+`[procesos generales]` 2, `:44`) bajo procesos 1; RF-15/16/17 (Brief `[WEB-ISSUSER]` 1/2/3, `:56-58`) bajo procesos 2; RF-07 duplicado (procesos 1 y WEB-IDENTITY); RF-26 no figura en §6; RF-27/28 atribuidos a WEB-ISSUSER pese a originarse en H-10/H-34/H-20 (`:162-165`). **Sí están:** origen de RF-24…31 (`:75-82`), nota de RNF-12…14 (`:162-165`), estimaciones con método (`propuesta_v3.md:26-33,344-356`) y S-14 (`:139`); no hay citas a secciones inexistentes del brief. Brecha documental, no de producto. | No |
| **C12** — Cuadre SQL↔diccionario↔ER | **PARCIAL** | Cuadre mecánico correcto (PASS): 27/27 tablas y 0 discrepancias de columnas (`estado_proyecto.md:111`). **Pero** el ER mantiene relaciones sin columna/FK de respaldo sin marcarlas como conceptuales (`diagrama_er.md:17-51`: IDENTITIES→ROLE_ASSIGNMENTS por wallet, JURISDICTIONS→IDENTITIES, PLATFORM_FEES→PAYMENTS, WALLET_MESSAGES↔SESSIONS, AUDIT_LOG↔IDENTITIES, SCHEMA_MIGRATIONS→AUDIT_LOG) y la evidencia de recuperación no tiene camino de datos: `identity_recovery_requests.evidence_document_id→document_files` (`base_datos.sql:295`) con `document_files.claim_request_id NOT NULL` (`:269`), N-15 sin corregir. No bloquea. | No |
| **C13** — Operación (backup/PITR/claves/RPC/coste) | **PARCIAL** | Documentación completa: backup 7 días + PITR 7 días, RPO ≤15 min / RTO ≤4 h, rotación de `KYC_ENCRYPTION_KEY` cada 90 días con versiones+KMS, pooling 5×3=15 conexiones, RPC primario+fallback con conmutación, coste demo ≤50 USD/mes con budget alerts 10/25/50 USD (`entornos_globales.md:182-194`; `diseno_cierre_v3_2.md:227-246`). **Falta evidencia de ejecución:** no existe acta `pruebas/restore_<fecha>.md`, ni pruebas de rotación de clave, failover RPC ni alertas activas; los criterios de aceptación quedan como futuros (`diseno_cierre_v3_2.md:241-246`). | No |
| **C14** — Cierre automatizado y 0 CRÍTICAS/0 ALTAS | **NO CUMPLE** | Hay script y pasa, y las comprobaciones mecánicas son reales (§3). **Pero:** (1) el script no comprueba trazabilidad brief↔RF ni contradicciones de estado/recuentos (solo mínimos en `verificar_artefactos.py:125-133`) y no está en CI (sin referencia en `rwa-sc/.gitlab-ci.yml` ni `rwa-web/.gitlab-ci.yml`; `estado_proyecto.md:130` lo reconoce); (2) no hay 0 CRÍTICAS/0 ALTAS: persisten H-07, H-10, H-13, H-16, H-22, H-32 y los nuevos F-01, F-02, F-03; (3) la compuerta queda 2/11/1 y `estado_proyecto.md:131` declara B12 no cumplido. | **Sí** |

---

## 5. Estado de B1–B12

| ID | Criterio | Estado | Evidencia / qué falta |
|---|---|---|---|
| **B1** | Migración ejecutable y probada sobre `pg_dump` v2 real | **ABIERTO** | Ejecutada de verdad en PostgreSQL 16.15 sobre esquema v2 canónico + datos sintéticos: EXIT 0, COMMIT, conteos cuadrados y rollback (`pruebas/validacion_ejecucion_v3_1.md:33-48`), con N-02/N-03 corregidos (`migracion_v2_a_v3.sql:101-113,241-242`). **No cerrado:** sin CI contra `pg_dump` v2 real (`:71-79`), pérdida silenciosa de `token_required_claims` por alias no aplicado (`:256-261`) y falta de verificación de documentos en §6 (`:335,341-343`). |
| **B2** | DDL ejecutable | **CERRADO** | Carga completa sin errores: 31 objetos/27 tablas + triggers + funciones (`pruebas/validacion_ejecucion_v3_2.md:12-18`); 16/16 smoke tests incluido el `UPDATE orders` que fallaba (N-01) (`validacion_ejecucion_v3_1.md:50-69`); 19/19 pruebas de runtime v3.2 (`validacion_ejecucion_v3_2.md:20-42`). |
| **B3** | Escrow verificable | **DISEÑO** | Máquina de estados, economía, validación de pago, una orden abierta, UNIQUE de tx, TTL 30 min y `expire_orders` en DDL/pruebas (`base_datos.sql:642-653,989-1109`; 19/19 en `validacion_ejecucion_v3_2.md:24-42`). **Depende de implementación futura:** tramo NFT no impuesto en BD (`:450-452,1006-1007`; `diseno_cierre_v3_2.md:56`), job Cloud Run/Scheduler inexistente (`entornos_globales.md:103-112`) y faltan pruebas de concurrencia/doble venta/timeout/reembolso (`diseno_cierre_v3_2.md:85-92`). |
| **B4** | Autoridad del Emisor | **DISEÑO** | Vínculo emisor↔programa en DDL y probado (`base_datos.sql:851-872`; `validacion_ejecucion_v3_1.md:60`) y semillas para los 5 programas incluido SOCIO (`:1285-1310`). **No cerrado:** E2E de alta KYC→SOCIO no ejecutado (`estado_proyecto.md:123`; sin app/API v3); el criterio exige E2E con C2/C3 en CUMPLE. |
| **B5** | RBAC real | **DISEÑO** | `role_assignments` con ámbitos/unicidad y semillas (`base_datos.sql:519-544,1444-1468`) y `audit_log` append-only verificado (`validacion_ejecucion_v3_2.md:40-41`). **No cerrado:** matriz 8 roles × 12 capacidades no ejecutada (diferida a C5: `diseno_cierre_v3_2.md:149-156`), sin API RBAC y «role_assignments append-only» no se cumple (revocación por `revoked_at`, `:527`). |
| **B6** | Compliance on-chain | **DISEÑO** | Solo especificación de hooks y fuente de claims por activo (`diseno_cierre_v3_2.md:160-195`; `token_required_claims` off-chain `base_datos.sql:364-378`). No existen contratos v3 en `rwa-sc/sc/src` (solo v2), ni hook implementado, ni gate anti-deriva, ni tests adversariales: implementación futura (C3). |
| **B7** | Retención Q10 ejecutable | **DISEÑO** | Trigger +30 días y fin de relación +12 meses (`base_datos.sql:783-787,906-926`) y `purge_expired_documents()` probada con 1 documento vencido (`validacion_ejecucion_v3_2.md:42`). **No cerrado:** sin retención de `asset_documents` al vender (prometida para C1, `diseno_cierre_v3_2.md:206`), sin registro en `audit_log`, sin prueba de `ended_at` ni de «0 filas vencidas servidas» y sin job cloud (`entornos_globales.md:103-112`). |
| **B8** | Operación documentada | **DISEÑO** | Operación y coste documentados con cifras y criterios (`entornos_globales.md:182-194`; `diseno_cierre_v3_2.md:227-246`). **No cerrado:** sin ensayo de restauración (no existe `pruebas/restore_<fecha>.md`), sin prueba de rotación de `KYC_ENCRYPTION_KEY`, sin failover RPC ni budget alerts activas; criterios de aceptación futuros (`diseno_cierre_v3_2.md:241-246`). |
| **B9** | RNF falsables | **CERRADO** | RNF falsables con manifiesto de 12 rutas (`requerimientos.md:167-184`), regla axe serious/critical=0 (`:93`), p95 con entorno/concurrencia/dataset/ventana/herramienta (`diseno_cierre_v3_2.md:269-275`), pico S-14 formal (`requerimientos.md:139`) y SLI/error budget/alertas con dueño (`:95,102`; `diseno_cierre_v3_2.md:274`). La ejecución de gates pertenece a C5. |
| **B10** | Estado único y compuerta honesta | **ABIERTO** | `estado_proyecto.md` ya es honesto (`:4,15,22,131`), pero no hay estado único: `diccionario_datos.md:3,5` y `entornos_globales.md:3` declaran «Fase 1 cerrada»; `entornos_globales.md:85` dice 26 tablas; `propuesta_v3.md:424-425` «26/26 … Confirmar cierre»; `requerimientos.md:4-6` v3.1/S-1…S-13; S-3 sin dueño/fecha (`:128`). `diseno_cierre_v3_2.md:7-8` afirma B10/B11 «hechos», lo que no se sostiene. |
| **B11** | Trazabilidad automatizada y script en CI | **ABIERTO** | El script existe y pasa, pero no valida trazabilidad brief↔RF (no regenera §6 ni falla si un RF falta o se duplica de sección; solo recuentos mínimos `:125-133`) y no está en CI (sin referencias en `rwa-sc/.gitlab-ci.yml` ni `rwa-web/.gitlab-ci.yml`; `estado_proyecto.md:130` lo reconoce). |
| **B12** | 14/14 CUMPLE, 0 CRÍTICAS y 0 ALTAS | **ABIERTO** | Compuerta real 2/11/1 con 9 bloqueantes; ALTAS abiertas H-07, H-10, H-13, H-16, H-22, H-32 y nuevas F-01/F-02/F-03; `estado_proyecto.md:131` declara B12 «no cumplido». |

---

## 6. Hallazgos abiertos por severidad (solo verificados)

**Resumen de contadores de hallazgos abiertos:** 0 CRÍTICAS · 9 ALTAS · 6 MEDIAS · 1 BAJA.
*(Las ALTAS son 9: 6 previas —H-07, H-10, H-13, H-16, H-22, H-32— y 3 nuevas —F-01, F-02, F-03—. Las MEDIAS son 6: F-04, F-05, F-06, F-07, F-08, F-09; F-06 describe el mismo sustrato que H-32 y por eso **no se suma al total de ALTAS**. Las dos CRÍTICAS de la ronda anterior quedaron corregidas: N-01 y N-02.)*

### 6.1 ALTAS (9)

| ID | Hallazgo | Evidencia verificada | Recomendación |
|---|---|---|---|
| **F-01** | **Pérdida silenciosa de `token_required_claims` en el ETL.** §4.7 une por código sin aplicar el alias de §4.1, por lo que los topics 7/9 del v2 no encuentran `credential_type` y se descartan con `ON CONFLICT DO NOTHING`; §6 no verifica esa tabla. Riesgo de compliance incompleto en activos migrados. | `migracion_v2_a_v3.sql:256-261` vs `:101-113`; topics 7/9 en `rwa-sc/RepoTecnico/base_datos.sql:455-460`; §6 sin verificación en `:318-345`. | Aplicar el mismo `CASE` de alias en §4.7 y añadir a §6 el contraste de `token_required_claims` (v2 vs v3) y del conteo de documentos; añadir caso de prueba con topics 7/9. |
| **F-02** | **Documentos que certifican un cierre no verificado.** `diccionario_datos.md` y `entornos_globales.md` declaran «Fase 1 cerrada»; `entornos_globales.md:85` dice 26 tablas (reales 27); `propuesta_v3.md:424-425` «26/26 … Confirmar cierre»; `requerimientos.md:4-6` v3.1/S-1…S-13 con S-14 existente. | `diccionario_datos.md:3,5`; `entornos_globales.md:3,85`; `propuesta_v3.md:424-425`; `requerimientos.md:4-6,139`. | Alinear todos los artefactos al estado único de `estado_proyecto.md` (no cerrada, 27 tablas, v3.2, 31/14/8, S-1…S-14) y eliminar toda certificación de cierre no sustentada. |
| **F-03** | **Verificación incompleta y fuera de CI.** El script no comprueba trazabilidad brief↔RF ni contradicciones de estado/recuentos y no está integrado en el pipeline; por ello B11/C14 no son CUMPLE. | `verificar_artefactos.py:1-140` (solo mínimos en `:125-133`); sin referencia en `rwa-sc/.gitlab-ci.yml` ni `rwa-web/.gitlab-ci.yml`; `estado_proyecto.md:130`. | Extender el script (trazabilidad de §6, coherencia de versiones/recuentos, estado declarado) e integrarlo como job obligatorio de CI con artefacto de salida. |
| **H-07** | **Compliance on-chain inexistente más allá de especificación:** no hay contratos v3, hook ni enforcement on-chain de `token_required_claims`. | `diseno_cierre_v3_2.md:160-195`; `base_datos.sql:364-378`; `rwa-sc/sc/src` solo v2. | Implementar `AssetComplianceHook` + `token_required_claims` on-chain con tests adversariales (C7/B6) antes del piloto. |
| **H-10** | **El Fiador no tiene consentimiento ni estado de garantía modelado.** `token_guarantees` no representa aceptación/revocación; no hay prueba de «revocación bloquea mercado». | `base_datos.sql:380-397`; brecha reconocida en C6/B4. | Modelar consentimiento y estado de la garantía y probar en ejecución la cascada de revocación completa. |
| **H-13** | **Reorg del indexer no resuelto** (sigue abierto del registro previo). | Registro previo de hallazgos ALTAS; sin mecanismo de reversión/reconciliación verificado. | Definir y probar política de reorg (confirmaciones, reindexado idempotente, reconciliación de `chain_events`). |
| **H-16** | **DPIA (evaluación de impacto de protección de datos) no realizada.** | Registro previo de hallazgos ALTAS; C13/B8 documentan operación pero no la DPIA. | Elaborar la DPIA antes del tratamiento de datos personales del piloto. |
| **H-22** | **Jerga y método Flesch sin corregir.** | Registro previo de hallazgos ALTAS; sin informe de legibilidad en el repositorio. | Reescribir la documentación de usuario y medir legibilidad (Flesch) con criterio de aceptación explícito. |
| **H-32 / F-06** | **Tablas citadas que no existen.** La propuesta cita `issuer_requirements`, `assets`, `guarantors` y `recovery_requests`, inexistentes en el esquema real. | `propuesta_v3.md:264-275`; esquema con 27 tablas reales §3. | Regenerar la sección de modelo de la propuesta desde `base_datos.sql` y corregir los nombres a los reales. |

### 6.2 MEDIAS (6)

| ID | Hallazgo | Evidencia verificada | Recomendación |
|---|---|---|---|
| **F-04** | **Trigger prometido del tramo NFT no implementado.** El diseño promete que la BD no da por confirmada una orden sin los dos hashes; el DDL solo tiene columnas, sin enforcement (ni trigger ni CHECK). | `diseno_cierre_v3_2.md:56`; `base_datos.sql:450-452`. | Añadir trigger/CHECK que exija `escrow_asset_tx_hash` y `asset_transferred_at` al pasar a `confirmed`, con prueba negativa. |
| **F-05** | **Retención de `asset_documents` al vender sin mecanismo.** No existe el trigger prometido; la purga no escribe `audit_log`, no cuenta `asset_documents` y el job cloud no existe. | `diseno_cierre_v3_2.md:206,213`; `base_datos.sql:1112-1132`; `entornos_globales.md:103-112`. | Implementar `trg_asset_retention_on_sale`, registrar `document.purge` en `audit_log`, contar `asset_documents` y probar el flujo completo. |
| **F-07** | **Migración sigue calculando `sha256` sobre el blob cifrado (N-08)** y §6 no contrasta el conteo de documentos. | `migracion_v2_a_v3.sql:209`; `:335,341-343`. | Calcular el hash sobre el contenido en claro o documentar formalmente el criterio; añadir contraste de documentos en §6. |
| **F-08** | **El verificador Operador se fabrica en claims migrados**, solo mitigado con `legacy_unverified` en metadata. | `migracion_v2_a_v3.sql:164-168`; mitigación `:185`. | Declarar explícitamente los claims legacy como no verificados en el modelo (no solo metadata) o exigir re-verificación. |
| **F-09** | **«Matriz 8 roles» inconsistente:** 9 columnas en la matriz y el enum no incluye Fiador/Usuario; además la matriz no se ha ejecutado. | `diseno_cierre_v3_2.md:108-121`; `base_datos.sql:98`. | Corregir a 9 roles y alinear el enum `session_role`; ejecutar matriz positiva/negativa (C10/B5). |
| **F-06** | **Persistencia de H-32:** la propuesta cita tablas que no existen (`issuer_requirements`, `assets`, `guarantors`, `recovery_requests`). Se mantiene como MEDIA propia del catálogo de defectos nuevos y su sustrato figura también como H-32 en 6.1; **no se cuenta dos veces en el total de ALTAS**. | `propuesta_v3.md:264-275`. | Regenerar §5.3 desde el esquema real (27 tablas). |

### 6.3 BAJAS (1)

| ID | Hallazgo | Evidencia verificada | Recomendación |
|---|---|---|---|
| **F-10** | **Cabecera duplicada** «## 10. Respaldo y retorno## 10.» | `entornos_globales.md:198` | Corregir la cabecera (trivial). |

---

## 7. Distinción «cerrado» vs «diseñado pendiente de implementación»

La confusión entre ambos estados es la causa raíz de varias brechas (F-02, B10). Se fija la siguiente taxonomía vinculante:

| Estado | Significado | Qué puede declararse |
|---|---|---|
| **CERRADO** | Existe el artefacto y hay **evidencia de ejecución reproducible** (acta) que satisface el criterio íntegro. | B2 (DDL), B9 (RNF falsables documentales) |
| **DISEÑADO** | Existe especificación completa y, en su caso, DDL cargable, **pero falta implementación y/o prueba de runtime**. | B3, B4, B5, B6, B7, B8; C5, C6, C7, C9, C10 parciales |
| **ABIERTO** | El criterio no se satisface y no hay plan suficiente o la evidencia contradice la declaración. | B1, B10, B11, B12; C1, C4, C14 |

**Reglas de honestidad aplicadas en este informe:**

1. **Parsear/ejecutar DDL no equivale a producto:** las 19/19 pruebas de runtime y la migración en PostgreSQL 16 son avances reales, pero no cierran C1/C3/C5/C6/C7/C9 porque falta verificación completa (datos reales, concurrencia, contratos, jobs, E2E).
2. **«Diseñado» no es «cumple»:** los criterios B3–B8 se dictaminan DISEÑO aunque su DDL cargue y tenga pruebas parciales.
3. **«Documentado» no es «verificado»:** C13/B8 quedan PARCIAL/DISEÑO hasta que exista acta de restore, rotación y failover.
4. **Ningún contrato, hook, job cloud, DPIA, restore drill, E2E o matriz de prueba se declara CUMPLE por existir en un documento de diseño.**
5. **B12 solo sería CUMPLE con 14/14 criterios y 0 CRÍTICAS/0 ALTAS**, y hoy no lo es.

**Inventario de «cerrado» real:** DDL ejecutable con triggers y 19/19 pruebas (B2); migración ejecutada una vez sobre v2 canónico + datos sintéticos (B1 parcial); RNF falsables documentalmente (B9); emisor por claim (C2); cuadre mecánico de artefactos (§3). **Todo lo demás es diseño o trabajo pendiente.**

---

## 8. Plan mínimo para cerrar y autorizar piloto (P1–P8)

> **Regla de salida:** cada paso exige **evidencia reproducible** (acta o job de CI), no declaración documental. La compuerta de re-cierre se re-ejecuta al final (P8).

| Paso | Objetivo | Acciones mínimas | Cierra | Esfuerzo |
|---|---|---|---|---|
| **P1** | Corregir ETL y verificación de migración | Aplicar alias en §4.7, verificar `token_required_claims`/documentos en §6, decidir `sha256` (N-08), ejecutar en CI contra `pg_dump` v2 real con limpieza y rollback. | F-01, F-07, C1, B1 | M |
| **P2** | Estado único y cifras unificadas | Alinear `diccionario_datos.md`, `entornos_globales.md`, `propuesta_v3.md`, `requerimientos.md` y `diseno_cierre_v3_2.md` a un único estado (no cerrada, 27 tablas, v3.2, 31/14/8, S-1…S-14); dueño/fecha de S-3; eliminar «Fase 1 cerrada». | F-02, C4, B10 | S |
| **P3** | Verificación en CI | Extender `verificar_artefactos.py` (trazabilidad §6, coherencia de recuentos/versiones/estado) e integrarlo en `.gitlab-ci.yml` como job obligatorio. | F-03, C14, B11 | M |
| **P4** | RBAC ejecutado | Corregir a 9 roles y el enum `session_role`; ejecutar la matriz positiva/negativa contra API/BD; corregir el estado «append-only» de `role_assignments`. | F-09, C10, B5 | M |
| **P5** | Escrow completo | Trigger/CHECK de los dos hashes al confirmar; job cloud de expiración; pruebas de concurrencia, doble venta, TTL con reloj simulado, reembolso y tramo NFT. | F-04, C5, B3 | L |
| **P6** | Retención completa | `trg_asset_retention_on_sale`, `audit_log` en la purga, vista de vencidos para `asset_documents`, prueba del camino `ended_at`, job cloud. | F-05, C9, B7 | M |
| **P7** | Producto mínimo verificable | E2E de alta KYC→SOCIO (C3/B4); contratos v3 (`AssetComplianceHook`, `MarketplaceEscrow`, `BarloToken`) con tests adversariales (C7/B6); consentimiento y estado del Fiador (H-10/C6); prueba de la cascada de revocación; corregir modelo de la propuesta (H-32/F-06). | C3, C6, C7, B4, B6, H-10, H-32 | L |
| **P8** | Cierre operativo y re-auditoría final | Restore drill con acta, rotación de clave, failover RPC, budget alerts (C13/B8); H-13 reorg, H-16 DPIA, H-22 legibilidad; F-08, F-10; re-ejecutar la compuerta completa con 14/14 CUMPLE y 0 CRÍTICAS/0 ALTAS. | C13, B8, B12, H-07, H-13, H-16, H-22 | L |

**Criterio de autorización de piloto:** P1–P8 completados, compuerta 14/14 CUMPLE, 0 CRÍTICAS/0 ALTAS abiertas, script en CI verde y acta de re-auditoría emitida. **Hoy no se autoriza piloto.**

---

## 9. Firma y contadores

### 9.1 Contadores de hallazgos abiertos

| Severidad | Total | Detalle |
|---|---|---|
| **CRÍTICAS** | **0** | Las 2 de la ronda previa quedaron corregidas (N-01, N-02) |
| **ALTAS** | **9** | H-07, H-10, H-13, H-16, H-22, H-32/F-06, F-01, F-02, F-03 |
| **MEDIAS** | **6** | F-04, F-05, F-06, F-07, F-08, F-09 *(F-06 comparte sustrato con H-32, sin doble cómputo en ALTAS)* |
| **BAJAS** | **1** | F-10 |

### 9.2 Contadores de compuerta

| Veredicto | Total | Criterios |
|---|---|---|
| **CUMPLE** | **2** | C2, C8 |
| **PARCIAL** | **11** | C1, C3, C4, C5, C6, C7, C9, C10, C11, C12, C13 |
| **NO CUMPLE** | **1** | C14 |
| **Bloqueantes** | **9** | C1, C3, C4, C5, C6, C7, C9, C10, C14 |

| B1–B12 | Total | IDs |
|---|---|---|
| **CERRADO** | **2** | B2, B9 |
| **DISEÑO** | **6** | B3, B4, B5, B6, B7, B8 |
| **ABIERTO** | **4** | B1, B10, B11, B12 |

### 9.3 Artefactos auditados

**Fecha de revisión: 2026-11-04.** Todos los artefactos de `RepoTecnico/` llevan fecha de artefacto 2026-11-02.

| Artefacto | Rol en la auditoría |
|---|---|
| `RepoTecnico/BRIEF_BARLOBLOKCHAIN_v3.md` | Fuente de trazabilidad (32 líneas) |
| `RepoTecnico/requerimientos.md` | 31 RF · 14 RNF · 8 RT · S-1…S-14; §6 y Anexo A |
| `RepoTecnico/propuesta_v3.md` | Arquitectura, modelo de datos (§5.3), estimaciones, próximos pasos |
| `RepoTecnico/diccionario_datos.md` | 27 tablas, tipos, claves, reglas |
| `RepoTecnico/diagrama_er.md` | ER Mermaid (5 bloques, 27/27 entidades) |
| `RepoTecnico/base_datos.sql` | DDL v3.2 (172 sentencias, 27 tablas, triggers, jobs, semillas) |
| `RepoTecnico/migracion_v2_a_v3.sql` | ETL v2→v3 (40 sentencias, 12 tablas archivadas) |
| `RepoTecnico/entornos_globales.md` | Rutas, GCP, BD, jobs, variables, backup/PITR, coste |
| `RepoTecnico/diseno_cierre_v3_2.md` | Diseño B3/B5/B6/B7/B8/B9, matriz RBAC, criterios de aceptación |
| `RepoTecnico/estado_proyecto.md` | Estado declarado y compuerta B1–B12 |
| `RepoTecnico/verificar_artefactos.py` | Script oficial de verificación mecánica |
| `RepoTecnico/pruebas/validacion_ejecucion_v3_1.md` | Acta de migración + 16 smoke tests (PostgreSQL 16.15) |
| `RepoTecnico/pruebas/validacion_ejecucion_v3_2.md` | Acta de 19/19 pruebas de runtime v3.2 |
| `RepoTecnico/INFORME_CIERRE_V3_1.md` | Informe de cierre previo (ronda anterior) |
| `RepoTecnico/INFORME_OPTIMIZACION_V3.md` | Auditoría de optimización previa |
| `rwa-sc/RepoTecnico/base_datos.sql` | Esquema v2 canónico (topics 7/9 en `:455-460`; contraste del ETL) |
| `rwa-sc/.gitlab-ci.yml`, `rwa-web/.gitlab-ci.yml` | Comprobación de integración del script en CI (sin referencia) |
| `rwa-sc/sc/src` | Comprobación de contratos v3 (solo v2; sin `BarloToken`/`MarketplaceEscrow`/`AssetComplianceHook`) |

### 9.4 Declaración final

**Auditoría en solo lectura:** no se modificó ningún artefacto auditado. Este informe (`RepoTecnico/INFORME_CIERRE_V3_2.md`) es el único archivo escrito y consolida los dictámenes verificados sin añadir hallazgos.

**Veredicto:** **NO se puede cerrar la Fase 1.** Compuerta 2 CUMPLE / 11 PARCIAL / 1 NO CUMPLE, con 9 criterios bloqueantes, 9 ALTAS abiertas y 4 B1–B12 en ABIERTO. El cuadre mecánico (PASS del script, migración y 19/19 pruebas de runtime) demuestra avances sustantivos, pero **no sustituye** la verificación de producto, compliance on-chain, operación y evidencia real exigida por la compuerta. Se requiere el ciclo P1–P8 y una nueva re-auditoría final.

*Fin del informe v3.2.*
