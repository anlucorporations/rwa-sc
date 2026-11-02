# Informe de Cierre — Re-auditoría de Fase 1 · RWA v3 «Barlo Metaplace»

**Documento:** `RepoTecnico/INFORME_CIERRE_V3_1.md`
**Fecha de emisión:** 2026-11-02
**Rol:** Sintetizador de la re-auditoría de cierre (Fase 2 de auditoría → compuerta de Fase 1)
**Insumos consolidados:** verificados adversariales de las lentes R1 (testabilidad/ambigüedad), R2 (consistencia + ensayo real de migración), R3 (completitud RNF / ISO 25010), R4 (stakeholders/RBAC), R5 (trazabilidad con el brief) y R6 (riesgos técnicos, migración y DDL), más el dictamen verificado del auditor de compuerta sobre 14 criterios y las métricas mecánicas independientes.
**Naturaleza:** informe de cierre. No modifica artefactos auditados; solo consolida, deduplica y dictamina.

---

## 1. Veredicto de cierre

### **NO — la Fase 1 no puede declararse cerrada.**

No se autoriza el paso a la siguiente etapa (casos de uso + documento técnico) con los artefactos en su estado actual, y menos aún a un piloto. La Fase 1 permanece **«en corrección / re-auditoría»**, no cerrada.

**Justificación (5 razones de fondo):**

1. **Compuerta incumplida de forma objetiva:** de los 14 criterios de cierre, **0 CUMPLEN, 11 son PARCIALES y 3 NO CUMPLEN (C1, C4, C14)**; **11 criterios bloquean** el cierre (C1–C7, C9, C10, C13 y C14). El propio gate de salida exige «0 CRÍTICAS y 0 ALTAS abiertas» y ese requisito no se satisface.
2. **Una CRÍTICA real y determinista de migración:** la migración v2→v3 (`migracion_v2_a_v3.sql`) **no completa en ninguna base v2**. El ETL §4.1 inserta `ACCREDITATION`/`JURISDICTION` con `ON CONFLICT (code)`, pero `credential_types.on_chain_topic` es `UNIQUE` y las semillas v3 ya ocupan los tópicos 7/9 con `ACREDITACION`/`JURISDICCION`: colisión de clave única que aborta la transacción. A ello se suma el `CREATE OR REPLACE VIEW` sobre la vista v2 `v_claim_request_summary` (compatible en columnas solo si se elimina antes) y el ETL de tokens que convierte `price` NULL/0 en 0 BRLT, violando los `CHECK > 0` de v3. R2 lo reprodujo en un PostgreSQL 16.15 temporal con `exit=3` y rollback limpio; el dictamen de compuerta lo confirma por análisis estático y el ensayo de R6 sobre la v2 canónica coincide.
3. **Una segunda CRÍTICA de runtime verificada por R6 (no contabilizada por el dictamen de compuerta):** el trigger `updated_at` incluye `rwa.orders` en su array de tablas, pero `orders` **no tiene columna `updated_at`**; cualquier `UPDATE` del ciclo de escrow aborta con `record "new" has no field "updated_at"`. El parseo sintáctico (138 sentencias OK) no lo detecta porque PostgreSQL no valida campos al crear el trigger. Esto inutiliza la máquina de estados del escrow que la corrección decía haber cerrado (H-05).
4. **El estado del proyecto certifica un cierre que sus propias cifras desmienten:** `estado_proyecto.md` declara «0 CRÍTICAS abiertas; 4 ALTAS residuales» y «Fase 1 cerrada», mientras su propia tabla enumera **9 ALTAS abiertas** y conserva métricas obsoletas (23 RF/11 RNF/S-1…S-10/25 tablas/102 sentencias frente a los 28 RF/14 RNF/S-1…S-13/26 tablas/138 sentencias reales). No hay fuente única de estado ni chequeo automático; el acta de correcciones afirma cerrados hallazgos (H-01, H-20, H-32, H-34, H-38) que la verificación desmiente.
5. **Bloqueantes técnicos de diseño que no son documentales:** compliance on-chain inexistente más allá de un comentario (H-07/C7), retención Q10 sin mecanismo (H-17/C9), RBAC sin modelo de roles/roles declarados no representables (C10), emisor sin autoridad por programa ni semilla para SOCIO (C2/C3), escrow sin expiración efectiva, sin tramo NFT ni validación de precio/vendedor (C5), y operación (backup/PITR, claves, pooling, coste) sin documentar (C13).

**Consecuencia operativa:** no se reanuda la Fase 2 (casos de uso/documento técnico) ni se inicia piloto. Se abre un **ciclo de corrección con compuerta de re-cierre**: los 14 criterios deben llegar a CUMPLE con evidencia reproducible (ver §8), no bastando la declaración documental.

> Nota de honestidad: los criterios PARCIALES que dependen de implementación futura (p. ej. C8 accesibilidad/carga, C11 estimaciones, C12 ER conceptual) **no son por sí mismos defectos documentales**; son brechas de verificabilidad y están marcados como tales en §4. Ninguno de ellos, sin embargo, permite hoy declarar CUMPLE.

---

## 2. Metodología

### 2.1 Diseño de la re-auditoría

Re-auditoría **focalizada y adversarial** en tres capas:

1. **Siete lentes independientes** (R1–R7), en paralelo y en solo lectura, cada una con un objeto distinto: ambigüedad/testabilidad (R1), consistencia documental y de esquema (R2), completitud RNF/ISO 25010 (R3), stakeholders/RBAC/consentimiento (R4), trazabilidad con el brief (R5), riesgos técnicos —DDL, migración, reorg, ETL— (R6) y seguridad/legal en la medida cubierta por las demás. Cada lente recibió los 12 hallazgos del revisor previo y los 9 artefactos reales para **verificar, no repetir**.
2. **Auditor de compuerta** independiente: dictaminó los 14 criterios con evidencia ruta:línea y ejecutó comprobaciones mecánicas reales (parseo SQL con `pglast`, validación Mermaid, cuadre tablas/columnas SQL↔diccionario↔ER, recuento de RF/RNF/RT/supuestos, búsqueda de «1.3»).
3. **Síntesis (este informe):** consolida hallazgos verificados, deduplica entre lentes, resuelve discrepancias de severidad y cruza el dictamen de compuerta con los hallazgos de lente para producir el veredicto único.

### 2.2 Reglas aplicadas

- **«Ante la duda se descarta»**: un hallazgo sin evidencia ruta:línea verificable o que admite interpretación razonable en contra no se computa (ver §2.3).
- **Solo se computan hallazgos con evidencia en los artefactos reales**; no se añaden hallazgos que no estén en las verificaciones.
- **Deduplicación obligatoria**: defectos con la misma causa raíz se fusionan en un solo registro con sus facetas (p. ej. H-18/H-19 por «RNF numéricos sin fuente de medición ni gate»; H-32/H-38 por trazas contra el brief; H-20 con H-37/H-10 según faceta).
- **Ajuste de severidad justificado**: se rebajan defectos sin impacto funcional/riesgo (p. ej. H-20 «soporte guiado» de ALTA a MEDIA: el RF ya existe y el defecto es de criterio de aceptación; H-33 descartado por R2 y mantenido solo como MEDIA documental por el dictamen; H-10 conservado ALTA por ser residual de la tabla de gates del propio estado).
- **Los auditores no modificaron archivos**; el ensayo de migración de R2 se ejecutó en `/tmp` y se eliminó. Este informe es el único artefacto creado.
- **Distinción explícita** entre (a) defecto documental/DDL, (b) brecha de verificabilidad (testabilidad) y (c) trabajo de implementación futura. Un PARCIAL por dependencia de implementación no se presenta como defecto documental.

### 2.3 Hallazgos y señales descartados (regla «ante la duda»)

| Señal descartada | Lente | Motivo |
|---|---|---|
| Recuperación 4-eyes «sin timestamps separados / sin segundo Admin» como defecto propio de recuperación | R1 | El bypass real ya está cerrado por `recovery_four_eyes` y `recovery_approver_not_requester` (`base_datos.sql:305-319`); el residuo es el modelo de roles (H-23), ya computado. |
| H-30 (estimación de reutilización/plazo sin línea base) | R1 | Confirmado **CERRADO**: `propuesta_v3.md:31-33` declara estimación de orden de magnitud y método de recalibración; el ~55–60 % ya no se presenta como medido. |
| H-01(a) «hay una tabla v2 no contabilizada» (12 vs 13) | R2 | La formulación es inversa: la v2 tiene **12** tablas y la migración archiva 12; el error está en los documentos que dicen 13. Se conserva como defecto documental (N-12), no como tabla perdida. |
| H-03 (dependencia circular de semillas KYC) | R2 | Verificado **CERRADO**: `kyc-base` emite KYC con requisitos documentales y `onboarding-socio` es programa distinto; un usuario nuevo puede obtener KYC y luego SOCIO sin circularidad. |
| H-33 (aristas del ER sin columna/FK) como contradicción | R2 | Duda razonable: un ER conceptual admite relaciones no materializadas; 26/26 tablas coinciden con el SQL. El dictamen de compuerta, no obstante, mantiene el defecto como MEDIA **documental** (marcar el alcance), que se conserva en §5.2. |
| H-42 (MIME de `asset_documents` vs allowlist) | R2 | Falso positivo: la allowlist citada es `issuer_program_requirements.mime_allowlist`, no `asset_documents`. |
| RNF-V3-14 ↔ `entornos_globales` «backup no documentado» como contradicción | R3 | El RNF es un objetivo falsable y el entorno lo registra como deuda declarada con dueño; la parte real (el estado certifica cerrado lo pendiente) se computa en H-04. |
| H-37 (visitante/catálogo público inventado) como defecto de coherencia rol/RBAC | R4 | RF-V3-02 declara el modo visitante y la matriz RBAC lo representa coherentemente; la tensión con el brief es de alcance y se conserva como MEDIA de trazabilidad (no como contradicción). |
| H-21 (Operador con acceso al Panel Sistema) | R5 | Confirmado **CERRADO** (`propuesta_v3.md:208` ❌ Operador en Panel Sistema; RF-V3-22 alineado). |
| Backup/PITR (H-14) y Anvil (H-12) como hallazgos autónomos «ocultos» | R6 | La deuda está declarada expresamente con dueño y etapa (C0); lo accionable es que los criterios de C0/C6 no los ejecutan, absorbido en el hallazgo de gates (§7). |

**Falsos positivos relevantes que evita este informe:** no hay contradicción estructural RNF-V3-14↔entornos; el ER conceptual no es incoherente por convención; el MIME no se contradice; H-30 y H-21 están cerrados; el «Fase actual 2 vs Fase 1 cerrada» no es contradicción *per se* (sí lo es la cifra de residuales y la certificación de cierre).

### 2.4 Limitaciones declaradas

- **No hay `psql`, PostgreSQL ni Docker en el entorno del auditor de compuerta**, por lo que la ejecución real de la migración no fue verificable en esa capa: el dictamen se basó en parseo + análisis estático contra el esquema v2 canónico. R2 **sí** ejecutó el ensayo en un PostgreSQL 16.15 temporal (v2 cargada desde `rwa-sc/RepoTecnico/base_datos.sql` + `pg_dump -Fc`) y reprodujo el fallo determinista (`exit=3`, rollback limpio). R6 lo verificó sobre la v2 canónica del repositorio.
- **No verificable en esta re-auditoría:** existencia real de cuentas/roles PostgreSQL y RLS en despliegue, permisos efectivos, y datos reales del dump v2 (la regla de escala de `total_supply` y posibles overflows quedan como verificación pendiente contra el dump).
- Las etiquetas de versión de los artefactos están desalineadas (§3 y B-01), por lo que «qué revisión se auditó» se fija por fecha/mtime de los archivos listados en §9.

---

## 3. Verificación mecánica independiente

Comprobaciones ejecutadas por el auditor de compuerta (no declarativas: repetibles con las mismas herramientas):

| Comprobación | Resultado real | Veredicto |
|---|---|---|
| Parseo SQL `base_datos.sql` (`pglast` 8.7) | **138 sentencias, OK** (1 meta-comando psql excluido) | ✅ |
| Parseo SQL `migracion_v2_a_v3.sql` (`pglast` 8.7) | **36 sentencias, OK** (3 meta-comandos excluidos; `\ir base_datos.sql` no lo ejecuta pglast) | ✅ (sintaxis) |
| Ejecución real de la migración | **No verificable** en el entorno del auditor (sin `psql`/PostgreSQL/Docker) | ⚠️ |
| Tablas SQL ↔ diccionario ↔ ER | **26 / 26 / 26, 0 discrepancias** | ✅ |
| Columnas SQL ↔ diccionario | **225 / 225, 0 discrepancias** | ✅ |
| Diagramas Mermaid (`mermaid` 12.2.0) | **5 bloques, 0 errores de sintaxis** | ✅ |
| Referencias a «1.3» | 13 ocurrencias totales, **0 operativas** (8 históricas en INFORME, numeración de sección, 1 §11.3 SQL, 1 declaración negativa, 2 histórico/verificación en estado) | ✅ |
| Tablas v2 reales | **12** en el esquema v2; **12** archivadas por la migración; **13 declaradas** en propuesta/estado | ❌ (documental) |
| Requisitos | **28 RF, 14 RNF, 8 RT**; supuestos **S-1…S-13** | ✅ real / ❌ estado dice 23/11/8/S-1…S-10 |
| ALTAS abiertas | **9** en la tabla de residuales de `estado_proyecto.md:136-151`; cabecera declara **4** | ❌ |
| CRÍTICAS abiertas | Estado declara **0**; verificadas **1 determinista** (migración) + **1 de runtime** (trigger `orders`, R6) | ❌ |
| Criterios de compuerta | **0 CUMPLE / 11 PARCIAL / 3 NO CUMPLE**; **11 bloquean** | ❌ |
| Desglose del veredicto | 11 PARCIALES: C2, C3, C5, C6, C7, C8, C9, C10, C11, C12, C13 · 3 NO CUMPLE: C1, C4, C14 | — |

**Lectura:** el andamiaje mecánico (parseo, cuadre esquema↔diccionario↔ER, Mermaid, sin referencias «1.3» operativas) está **bien** y es un avance real de la corrección. Lo que falla es la **semántica**: el SQL parsea pero no ejecuta la migración ni el trigger de `orders`; el estado cuadra contra sí mismo pero no contra los artefactos; los criterios existen pero no son falsables. **Parsear no es ejecutar**: ningún cierre debe apoyarse solo en `pglast`.

---

## 4. Compuerta de 14 criterios

| # | Criterio | Veredicto | Evidencia verificada (condensada) | ¿Bloquea? |
|---|---|---|---|---|
| **C1** | Migración v2→v3 ejecutable, archivado, ETL y registro de versión | **NO CUMPLE** | Existe y parsea (36 sentencias), archiva 12 tablas `*_v2`, ETL §4 y registra esquema 3.0 (§5 `:279-288`). Pero §4.1 `:91-95` colisiona `credential_types.on_chain_topic` UNIQUE (`base_datos.sql:118-128,123`; semillas ACREDITACION 7/JURISDICCION 9 `:963-969`; v2 ACCREDITATION 7/JURISDICTION 9 `rwa-sc/.../base_datos.sql:455-465`) → duplicate key y `ON CONFLICT (code)` no cubre esa restricción; el ETL de tokens pone 0 donde v2 permite NULL/0 (`:216-217` vs `base_datos.sql:348-349`); la vista v2 `v_claim_request_summary` no se elimina antes del `CREATE OR REPLACE VIEW`; no hay evidencia de ejecución en CI contra `pg_dump` v2 (`estado:124-134` solo certifica parseo). Docs dicen 13 tablas v2, el esquema real tiene 12. | **SÍ** |
| **C2** | Autoridad del Emisor (Q11) persistida y con RBAC | **PARCIAL** | Q11 registrada (`propuesta:409`), `claim_requests.issuer_id` obligatorio al aprobar (`base_datos:229,246-250`). Pero la matriz RBAC no tiene actor/columna Issuer (solo Visitante/Usuario/Fiador/Operador/Admin `propuesta:197-210`) y mete «Issuer (rol)» como texto en la celda de Admin (`:203`), con filas duplicadas `:203,:205`; no hay vínculo BD `issuer_id↔issuer_program_id` ni emisor semilla para `onboarding-socio`. | **SÍ** |
| **C3** | Onboarding E2E con evidencias y gate | **PARCIAL** | La circularidad KYC/SOCIO **sí se corrigió**: `kyc-base` emite KYC con emisor propio (`base_datos:978-981,997-1000,1012-1017`) y `onboarding-socio` solo exige KYC base (`:1056-1065`) emitiendo SOCIO (`:1019-1024`). Pero no hay emisor semilla para `onboarding-socio` ni `legacy-v2` (`:997-1010` solo kyc-base, garantía-activos y fiador) y aprobar exige `issuer_id` no nulo (`:246-250`): el E2E de alta no puede completarse con las semillas actuales ni consta ejecutado. | **SÍ** |
| **C4** | Documento coherente, supuestos y residuales | **NO CUMPLE** | Los tres documentos no declaran el mismo estado ni supuestos: `estado:3` «Fase actual: 2» y «0 CRÍTICAS; 4 ALTAS residuales», `:14/:88` «Fase 1 cerrada», `:20` «23 RF, 11 RNF, S-1…S-10», `:48` «Ninguna bloqueante» frente a D-V3-04 «Provisional» `:34`, `:57` «Confirmar cierre», `:67` «13 tablas», `:74-78` «25 tablas/102 sentencias», `:122` «Cabeceras v3.1, S-1…S-13»; `propuesta:4` «propuesta para validación» y `:420` «Confirmar cierre»; `diccionario:5` «Fase 1 cerrada (Q1–Q10)»; `entornos:3` «Fase 1 cerrada». S-3 sigue `[SUPUESTO]` sin dueño/fecha (`requerimientos:125`). | **SÍ** |
| **C5** | Escrow/marketplace: reserva, TTL, disputa, atomicidad, estados y pruebas | **PARCIAL** | Sí existen `quantity`, una orden abierta por listing, UNIQUE de `tx`, TTL, trigger de reserva y disputas/árbitro (`base:438-457,608-619,449,807-809,478-492,789-846,702-705`). Faltan: enforcement de transiciones (solo CHECKs; cualquier salto es válido), expiración/liberación efectiva (sin job/trigger; único Scheduler = indexer, `entornos:53`), atomicidad NFT↔BRLT (solo prosa `propuesta:286-287,331`), validación de precio/vendedor/comisión contra `listings`/`platform_fees`, y pruebas de concurrencia/doble venta/timeout/reembolso (exigidas en INFORME:838). **Además** el trigger `updated_at` de `orders` rompe todo UPDATE (ver §6). | **SÍ** |
| **C6** | Garantías, cumplimiento y segregación de funciones en DDL | **PARCIAL** | Controles presentes: `claim_request_id NOT NULL` (`:384`), trigger que exige claim aprobado/tipo/independencia (`:737-786`), fail-closed de dos garantías verificadas (`:658-682`), cascada de revocación (`:708-733`), 4-eyes real (`:305-318`), anti-autoaprobación y segregación Operador/Admin (`:255-262`). Brechas: al revocar se pausa el token pero no se cierran listings/órdenes ni se bloquean nuevas compras (la reserva solo mira el listing `:789-817`); el rol Operador no existe en el modelo de roles; no hay tests negativos. | **SÍ** |
| **C7** | Compliance on-chain (AssetComplianceHook / `token_required_claims`) | **PARCIAL** | Único diseño: comentario de una línea «AssetComplianceHook // _update/beforeTokenTransfer -> IdentityRegistry (H-07)» (`propuesta:252`) e invariante 2 (`:162-163`). `token_required_claims`/`token_compliance_modules` existen solo off-chain (`base:363-376`) y ningún trigger/vista/contrato los aplica; sin hook especificado (mint/transfer/listing) ni tests de transferencia a wallet no verificada (INFORME:840). Sigue como gate C3 (`estado:140`). | **SÍ** |
| **C8** | RNF operativos con umbrales y verificabilidad | **PARCIAL** | RNF-V3-12/13/14 y legibilidad con umbrales numéricos (title≤40, template≤200, lista cerrada de jerga, Flesch-Szigriszt≥55, gate CI `requerimientos:90`); p95 lectura <800 ms y escritura <1,5 s con carga 2× (`:91`). Faltan: RNF-V3-04 remite a «12 rutas principales enumeradas» **que no se enumeran en ningún artefacto**; p95 sin entorno/concurrencia/dataset/ventana/herramienta; sin gate de CI de axe/p95 (H-28). **Brecha de verificabilidad, no defecto documental grave.** | No |
| **C9** | Retención Q10 ejecutable y probada | **PARCIAL** | Solo existen la columna `document_files.retention_delete_at` (`base:275`) y la vista de vencidos (`:912-918`); ningún trigger/función calcula la fecha, no hay `ended_at`, no hay job de purga (único Scheduler = indexer `entornos:53`), `asset_documents` no tiene retención (`:399-412`) y no hay test de purga. Gate con dueño H-17→C1 (`estado:145`). | **SÍ** |
| **C10** | Rol/proceso para Fiador, Auditor, Soporte y árbitro | **PARCIAL** | RF-V3-27 los declara (`requerimientos:78`) y la matriz RBAC define Visitante/Usuario/Fiador/Operador/Admin (`propuesta:197-210`), pero Auditor/árbitro solo aparecen como paréntesis en celdas de Admin (`:209-210`); el enum `session_role` no los incluye (`base:98`); no existe `role_assignments` ni cuentas/semilla por rol entre las 26 tablas (solo emisores `:997-1010`). El modelo «rol vs claim» es parcial. | **SÍ** |
| **C11** | Trazabilidad casos de uso ↔ RF ↔ brief y estimaciones | **PARCIAL** | Tabla §6 (`requerimientos:144-155`) no se deriva de la columna «Brief»: RF-02 (Brief [procesos generales] 1) bajo [OBJETIVO]; RF-08 (Brief [WEB-ISSUSER], [procesos generales] 2) bajo procesos 1; RF-09/RF-10 ausentes; RF-15/16/17 (Brief [WEB-ISSUSER] 1/2/3) bajo procesos generales 2; RF-24/26 sin fila de origen; RF-27/28 atribuidos a WEB-ISSUSER pese a originarse en H-10/H-34/H-20. Estimaciones «~55–60 %» y «≈14–18 semanas» solo con nota de limitación (`propuesta:26,31-33,403`); 60/mes sin supuesto S-14. Gate documental, no de producto. | No |
| **C12** | Consistencia SQL ↔ diccionario ↔ ER y camino de datos | **PARCIAL** | Cuadre mecánico correcto: 26/26 tablas y 225/225 columnas, 0 discrepancias. Pero el ER mantiene ≥8 relaciones sin columna de respaldo y sin marcarlas como conceptuales (`diagrama_er:17,43,45,46,48,49,50,51`). La evidencia de recuperación sigue sin camino de datos: `evidence_document_id→document_files` (`base:294`) y `document_files.claim_request_id` es `NOT NULL` (`:268`). MIME y proceso del ISSUER sí quedan documentados (`:280-283,1041-1092`). | No |
| **C13** | Operación: Anvil, claves, backup/PITR, pooling, RPC y coste | **PARCIAL** | Anvil no apto y claves dev declaradas (`entornos:156-161`). Pero backup/PITR, copia/rotación de `KYC_ENCRYPTION_KEY`, límite global del pool y modelo de coste **NO están documentados**: el propio entorno reconoce «No documentado aún» / «No documentada» / «sin límite global documentado» / «Sin modelo de coste» (`:163-172`); RPC de respaldo solo como mitigación futura (`:158`, `propuesta:364`). H-14/H-15 abiertas como gates (`estado:143-144`). | **SÍ** |
| **C14** | Cierre honesto: 0 CRÍTICAS/0 ALTAS y verificación automática | **NO CUMPLE** | Repite las comprobaciones mecánicas (26/26, 138/36, 5/5 Mermaid) pero **no existe script automático de trazabilidad ni de convención de versión** (no hay scripts en `RepoTecnico`; `estado:124-134` es una tabla manual con cifras contradictorias, 25 vs 26 tablas y 102 vs 138 sentencias). El requisito 0 CRÍTICAS / 0 ALTAS no se cumple: hay 1 CRÍTICA nueva de migración (+1 de runtime verificada por R6) y `estado:136-151` lista 9 ALTAS abiertas, mientras `:3` y `:149` afirman «4 ALTAS residuales» y `:134` «ALTAS cerradas». | **SÍ** |

**Resumen:** **0 CUMPLE · 11 PARCIAL · 3 NO CUMPLE · 11 bloquean (C1–C7, C9, C10, C13, C14).** Ningún criterio alcanza hoy el umbral de cierre.

---

## 5. Estado de los hallazgos previos (H-01…H-44)

Criterio de consolidación: se conserva la severidad más alta verificada, se deduplican causas raíz y se ajusta severidad solo con justificación explícita. La columna «Evidencia» resume la comprobación; el detalle completo consta en las verificaciones de las lentes.

### 5.1 CRÍTICAS y ALTAS

| ID | Hallazgo | Severidad | Estado | Evidencia verificada (resumen) |
|---|---|---|---|---|
| **H-01** | Migración v2→v3 no ejecutable / H-01 declarada cerrada | **CRÍTICA** | **ABIERTO** | Colisión `on_chain_topic` UNIQUE + vista v2 + `price` NULL→0; ensayo real `exit=3`; docs dicen 13 tablas v2 (reales 12) (`migracion:91-95,216-217`; `base:118-128,348-349,853-868`; `rwa-sc/...:455-465`; `estado:116,128-130`). |
| **H-02** | Autoridad Emisor↔programa no impuesta ni sembrada | **ALTA** | **PARCIAL** | `issuers.issuer_program_id` nullable e independiente de `claim_requests.issuer_program_id`; `issuer_signature` texto libre; sin semilla para `onboarding-socio` (`base:199-207,229,246-250,978-1010`; `propuesta:288-289`). |
| **H-04** | Estado del proyecto se autocontradice y certifica cierre no sostenido | **ALTA** | **ABIERTO** | «Fase 1 cerrada» con 9 ALTAS en tabla propia; cifras 23 RF/11 RNF/S-1…S-10/25 tablas/102 sentencias vs 28/14/S-1…S-13/26/138; Q1–Q10 vs Q1–Q13 (`estado:3,14,20,43-48,74-83,110,136-151`; `requerimientos:4,121-135`; `propuesta:405-411`). |
| **H-05** | Escrow: TTL sin ejecutor, atomicidad NFT↔BRLT no modelada, precio/vendedor/comisión sin validar, estados sin máquina | **ALTA** | **PARCIAL** | `expires_at` decorativo; `ux_orders_open` bloquea la publicación indefinidamente; `confirmed` sin verificar escrow/transferencia del NFT; trigger de reserva solo valida estado y remanente (`base:438-457,608-610,789-817`; `entornos:53`; `propuesta:286-287,331`). |
| **H-07** | Compliance on-chain sin diseño (AssetComplianceHook) | **ALTA** | **ABIERTO** | Solo comentario de una línea e invariante; `token_required_claims` sin aplicación on-chain; sin tests (`propuesta:252,162-163`; `base:363-376`; gate C3 `estado:140`). |
| **H-10** | Fiador sin consentimiento ni estados de garantía; RBAC sin capacidad de aceptar/revocar | **ALTA** | **ABIERTO** | `token_guarantees` solo `verified`/metadatos; sin `guarantee_state`, firma EIP-712 ni `accepted_at/revoked_at`; RBAC sin rol Fiador (`base:379-396`; `requerimientos:78`; `propuesta:200-201`; `estado:141`). |
| **H-12** | Anvil declarado en presente y no materializado (dev-only) | **ALTA** | **ABIERTO (gate C0)** | Deuda declarada con dueño/etapa; la afirmación en presente y la falta de segundo RPC/criterio de C0 se registran en §7 (`entornos:156-161`; `estado:142`). |
| **H-13** | Indexer: reorg sin algoritmo, sin detección/alertas, sin job de reconciliación ni SLO | **ALTA** | **ABIERTO** | Añadidos `chain_id/block_hash/parent_hash/removed`, pero ninguna función/job los mantiene; `estado:120` lo marca cerrado; no figura como residual (`base:527-554`; `entornos:52-53`; `estado:136-147`). |
| **H-14** | Backup/PITR y copia/rotación de `KYC_ENCRYPTION_KEY` sin documentar | **ALTA** | **ABIERTO (gate antes de C0)** | «No documentado aún»/«No documentada» (`entornos:163-172`; `estado:143`); RNF-V3-14 con umbral pero sin método ni ensayo (`requerimientos:100`). |
| **H-15** | Pooling, límite global de conexiones y RPC de respaldo sin documentar | **ALTA** | **ABIERTO (gate)** | «Sin límite global documentado»; failover futuro (`entornos:158,163-172`; `estado:144`). |
| **H-16** | RNF-V3-12 cumplimiento/protección de datos declarativo | **ALTA** | **PARCIAL** | RNF-V3-12 existe (`requerimientos:98`) pero sin modelo de consentimiento/base legal en BD, sin notificación de brechas, DPIA sin dueño/artefacto ni criterio en C1 (`base:210-221`; `propuesta:328`). |
| **H-17** | Retención Q10 sin mecanismo ejecutable | **ALTA** | **ABIERTO** | Sin trigger de cálculo, sin job de purga, `v_documents_due_deletion` es un SELECT; `entornos:92-93` la presenta erróneamente como «purga controlada» (`base:266-284,913-918`; `entornos:53,92-93`). |
| **H-18 / H-19** | RNF-V3-05/06/13 con umbrales pero sin SLI, fuente, instrumentación, dueño de alertas ni gate en C4/C6 | **ALTA** | **PARCIAL** | Disponibilidad ≥99,5 % con error budget y alertas escritas (`requerimientos:91-92,99`) pero sin fuente/ventana/herramienta, sin definición del «pico», sin supuesto S-14 y sin criterios de ciclo (`propuesta:331-333`; `entornos:53,171`). Deduplicados por causa raíz común. |
| **H-22** | Legibilidad: umbrales añadidos pero sin lista de jerga, método de Flesch-Szigriszt ni umbral inglés | **ALTA** | **PARCIAL** | RNF-V3-04 fija title≤40, template≤200, «0 términos de lista cerrada» y FS≥55 (`requerimientos:90`) sin publicar la lista ni el método; catálogo `es`/`en` (`base:1095,1119`) deja el inglés sin umbral; `check-wallet-messages` solo nombrado (`propuesta:308`). |
| **H-41** | Modelo de coste por ciclo y budget alerts como criterio | **ALTA** | **ABIERTO** | Solo objetivo «≤50 USD/mes», sin desglose ni criterio (`entornos:163-172`; `propuesta:327-333,339-351`). |

**Recuento CRÍTICAS/ALTAS abiertas: 2 CRÍTICAS + 15 ALTAS** (H-18/H-19 computadas como dos IDs, un solo defecto consolidado). De ellas, **9 figuraban ya en la tabla de residuales del estado** (H-07, H-10, H-12, H-14, H-15, H-17, H-18, H-19 y H-20, que esta síntesis reclasifica a MEDIA); **7 ALTAS no registradas** se añaden al registro: H-02, H-04, H-05, H-13, H-16, H-22 y H-41.

### 5.2 MEDIAS y BAJAS agrupadas por bloque

**Bloque A — Datos, modelo y tasación** (12 MEDIAS)
`H-11` (claves dev/Anvil y RPC público sin restricción, PARCIAL) · `H-23` (roles no representables: enum sin fiador/user, sin `role_assignments`, sin cuentas por rol, fila KYC «Operador + Admin», **ABIERTO**) · `H-25` (quemado NFT servicio sin Q ni estado off-chain `consumed/burned`, ABIERTO) · `H-26` (cap 100 M / maxMintPerTx 10 000 solo en prosa; sin límites por periodo ni cuórum/timelock, PARCIAL) · `H-27` (tope precio≤tasación opcional con `valued_brlt` NULL y sin trazabilidad de tasador, ABIERTO) · `H-31` (evidencia de recuperación colgando de `document_files.claim_request_id NOT NULL`, ABIERTO) · `H-33` (≥8 aristas del ER sin columna ni marca conceptual, ABIERTO) · `H-34` (`audit_log` mutable, sin retención/partición ni rol Auditor persistido, PARCIAL) · `H-35` (custodia de claves de plataforma sin dueño/rotación/break-glass; Admin/Owner = cuenta #0 contradice la nota «nunca», PARCIAL) · `H-39` (ficha de características del activo sin RF ni modelo estructurado, ABIERTO) · `H-37` (Visitante/Fiador como actores y requisitos no trazables al brief, PARCIAL) · `H-36` (sin proceso de suspensión/revocación del Socio ni efectos sobre listings/órdenes, ABIERTO).

**Bloque B — UX, i18n y verificabilidad** (4 MEDIAS)
`H-20` (soporte guiado: RF-V3-27/28 existe pero «grandes pasos» sin definir, SLA sin número y criterios C1–C3 sin guiado; **reclasificada de ALTA a MEDIA**: el RF ya existe y el defecto es de aceptación, sin impacto funcional) · `H-28` (WCAG remite a «12 rutas» inexistentes; p95 sin condiciones) · `H-29` (catálogo es/en de 7 procesos, faltan plantillas de procesos con firma v3.0) · `H-44` (`2× el pico` indefinido y 60 servicios/mes sin supuesto S-14).

**Bloque C — Seguridad y operación** (4 MEDIAS)
`H-24` (sin anti-abuso/rate limiting, nonce SIWE de un solo uso, TTL máximo de sesión ni rotación de secreto; no figura como residual, ABIERTO) · `H-41` (coste — ver ALTAS) · `H-12/H-14/H-15` (gates, ver ALTAS) · `H-11/H-35` (claves, ver Bloque A). Riesgo de seguridad no cubierto: **no hay threat model ni auditoría externa de contratos**.

**Bloque D — Documentación y trazabilidad** (5 MEDIAS + 2 BAJAS)
`H-32` (§5.3 con tablas inexistentes `issuer_requirements/assets/guarantors/recovery_requests`; el estado la da por cerrada, ABIERTO) · `H-38` (tabla §6 no generada desde «Brief»; deduplicada con H-32 por causa raíz, **PARCIAL**) · `H-30` (**CERRADO**: estimación reconocida como orden de magnitud) · N-12 (12 vs 13 tablas v2) · N-13 (nota de origen de RF-24…28 y RF-26 sin fila) · `B-01` (**BAJA**) cabeceras de versión desalineadas (diccionario/ER/SQL v3.0 vs estado v3.1) · `H-43` (**BAJA**, ABIERTO: «proceso» del ISSUER como `description` libre, sin pasos ni criterio).

**Bloque E — Cerrados / descartados**
`H-03` **CERRADO** (circularidad KYC/SOCIO resuelta) · `H-08` **CERRADO en lo esencial** (bypass 4-eyes cerrado por CHECK; residuo de roles en H-23) · `H-09` **CERRADO** (segregación Operador/Admin con `verified_by`/`reviewed_by` y CHECKs) · `H-21` **CERRADO** (Operador sin Panel Sistema) · `H-30` **CERRADO** · `H-42` **FALSO POSITIVO** · señales descartadas según §2.3.

---

## 6. Hallazgos nuevos introducidos por la corrección

Solo se listan defectos **introducidos o agravados por la propia corrección** (no los previos que persisten, ya registrados en §5). Todos con evidencia verificada.

| ID | Severidad | Título | Evidencia | Recomendación |
|---|---|---|---|---|
| **N-01** | **CRÍTICA** | Trigger `updated_at` sobre `rwa.orders`, tabla sin columna `updated_at`: todo UPDATE del escrow falla en runtime | `base_datos.sql:438-457` (definición sin `updated_at`); `:630-638` (`NEW.updated_at := now()`); `:643-645` (array incluye `'orders'`); `:647-656` (creación). PostgreSQL no valida el campo al crear el trigger: el parseo (138 OK) no lo detecta. | Añadir `updated_at timestamptz NOT NULL DEFAULT now()` a `orders` (y diccionario/ER) **o** retirar `'orders'` del array. Añadir a CI un smoke test que haga un `UPDATE` por cada tabla con trigger `updated_at` y falle si falta la columna. |
| **N-02** | **CRÍTICA** *(causa determinista de H-01)* | La migración colisiona `credential_types.on_chain_topic` UNIQUE: `ACCREDITATION`/`JURISDICTION` v2 vs `ACREDITACION`/`JURISDICCION` v3 | `migracion:91-95`; `base:118-128,123,963-969`; `rwa-sc/.../base_datos.sql:455-465`. `ON CONFLICT (code)` no cubre la restricción de `on_chain_topic`; el JOIN de §4.4 dejaría claims sin migrar y §6 abortaría por conteos. | Mapear `claim_topics→credential_types` por `on_chain_topic` con `ON CONFLICT ON CONSTRAINT`/`DO UPDATE`, preservar `active` y ejecutar la migración real en CI contra `pg_dump` v2 antes de §6. |
| **N-03** | ALTA | El ETL de tokens convierte `price` NULL/0 en 0 BRLT y viola los `CHECK > 0` de v3 | `migracion:216-217` (`round(coalesce(t.price,0),8)`); `base:348-349`; v2 permite NULL/0 (`rwa-sc/...:216,233`) | `CASE WHEN t.price IS NULL OR t.price = 0 THEN NULL ELSE round(t.price,8) END`, o normalizar/validar el dump en CI y registrar la decisión en acta de migración real (hoy inexistente). |
| **N-04** | ALTA | No hay emisor semilla para `onboarding-socio`: el claim SOCIO no se puede emitir ni aprobar | `base:978-1010,1019-1024,246-250`; programas y emisores desalineados | Sembrar un emisor dedicado para `onboarding-socio` (distinto del emisor KYC, para preservar separación) y otro para `legacy-v2`, o documentar y probar la regla de autorización. |
| **N-05** | ALTA | Sin integridad emisor↔programa: `issuer_id` puede firmar claims fuera de su programa | `base:199-207,224-263`; `propuesta:288-289`; ETL vincula todos los emisores migrados a `legacy-v2` (`migracion:97-113`) | FK compuesta/trigger que valide `issuers.issuer_program_id = claim_requests.issuer_program_id` (o tabla de autorización emisor-programa) y `NOT NULL` cuando corresponda. |
| **N-06** | ALTA | La cascada de revocación no bloquea el mercado: no cierra listings/órdenes y se puede listar/comprar un token `draft`/`paused` | `base:708-733,419-435,702-705,789-817` (crear listing solo valida tope de precio; crear orden solo estado del listing) | Triggers que exijan `token.status` minted/listed y garantías verificadas al crear listings; cascada que cierre listings y cancele órdenes con reembolso/reversión. |
| **N-07** | ALTA | El ETL fabrica un verificador (cuenta #4 de Anvil) en todos los claims resueltos, sin distinguir datos sintéticos | `migracion:146-153` (wallet fija `0x15d34AAf…`, `verified_at = reviewed_at`); `base:233-236,258-262` | No fabricar: migrar con `verified_by_wallet`/`verified_at` NULL y marca `legacy_unverified` (adaptando la restricción), o reverificar en C0 con auditoría; acta de migración real. |
| **N-08** | MEDIA | `sha256` migrado de `document_files` pasa a ser el hash del **blob cifrado**, no del contenido original; se pierde `uploaded_by` y retención | `migracion:184` (`digest(df.content)`), `:177-196` sin `uploaded_by`, `retention_delete_at = NULL`; v2 `sha256` = hash en claro (`rwa-sc/...:184,188`; `diccionario:186`) | Preservar el hash original (metadato legacy o verificación contra ciphertext), migrar atribución de subida (columna o `audit_log`) y aplicar retención Q10; comprobación de cobertura en §6. |
| **N-09** | MEDIA | Los `claim_topics` reservados (`ENVIRONMENTAL`/`SANCTIONS`, `active=false`) se migran como `credential_types` activos | `migracion:92-95` no copia `active`; `base:125` DEFAULT true; v2 `:459-460` | Incluir `active` en el SELECT y preservar `false`; verificar catálogo final contra §6. |
| **N-10** | MEDIA | Direcciones con checksum mixto + `UNIQUE` case-sensitive + `CHECK ~*` permiten duplicar la misma wallet | `base:199-207,997-1010`; `migracion:98-113` (`lower(...)`) | Normalizar a minúsculas o `citext` y añadir `UNIQUE` sobre `lower(address)`. |
| **N-11** | MEDIA | No hay máquina de estados de la orden ni expiración efectiva de la reserva | `base:438-457,789-817`; `entornos:53`; `INFORME:838` | Trigger/máquina de transiciones permitidas, job de expiración/liberación y tests de concurrencia/timeout/reembolso como criterio de C4. |
| **N-12** | MEDIA | Recuento de tablas v2 contradictorio: 12 reales frente a 13 declaradas | v2 real 12 `CREATE TABLE`; `migracion:41-54` archiva 12; `estado:67`; `propuesta:71,255` | Verificar inventario con `pg_dump` v2, archivar cualquier tabla adicional y unificar el recuento. |
| **N-13** | MEDIA | Regresión de trazabilidad: la nota de origen de RF-V3-24…28 se contradice con §6, omite RF-26 y atribuye mal el origen de RNF-V3-12…14 | `requerimientos:75-79,144-158`; `BRIEF:2,24,32`; `INFORME:804,841`; `estado:121` | Fila «Origen auditoría/decisiones» para RF-24…28, alta de RF-26, y corrección de la lista de hallazgos origen de RNF-12…14. |
| **N-14** | MEDIA | RNF-V3-01 («0 endpoints sin autenticación») contradice el catálogo público del Visitante exigido por RF-V3-02 | `requerimientos:33,87`; `propuesta:197-200,208` | Reformular como «0 endpoints **de escritura** sin autenticación y 0 sin autorización por recurso», excluyendo lecturas públicas, o definir sesión visitante de solo lectura. |
| **N-15** | MEDIA | La corrección endurece la evidencia de recuperación pero el modelo documental sigue sin camino: `document_files.claim_request_id` NOT NULL | `base:266-310,294,268`; `diccionario:177-214` | `claim_request_id` nullable + `recovery_request_id` con CHECK de exclusividad (o dueño polimórfico) y definición de qué ocurre al purgar el documento (el `ON DELETE SET NULL` puede violar el CHECK). |
| **N-16** | MEDIA | No existe chequeo automático de trazabilidad ni de convención de versión; la «verificación posterior» es manual y con cifras contradictorias | `estado:124-134`; sin scripts en `RepoTecnico` | Script de CI: `pglast`, validación Mermaid, cuadre tablas/columnas, «1.3» operativo = 0 y regeneración de §6 desde la columna «Brief»; publicar salida como evidencia. |
| **N-17** | BAJA | Cabeceras de versión desalineadas entre artefactos corregidos | `diccionario:3,5`; `diagrama_er:3`; `base:5`; `estado:20-24,122` | Unificar versión y referencias a decisiones (Q1–Q13) en cabeceras y estado; separar «versión de esquema 3.0» de «revisión documental». |

> **Nota de deduplicación:** N-02 es la causa determinista que mantiene H-01 abierto; N-15 es la faceta de modelo documental de H-31; N-11 se solapa con H-05 (se conserva separado por ser un defecto de implementación concreto de la corrección); N-13 refina H-38; N-17 corresponde a la BAJA del dictamen. No se duplican en el contador de §9.

---

## 7. Riesgos residuales y gates declarados

Los riesgos no se consideran «cerrados por declaración»: cada uno debe tener **dueño, etapa y evidencia de cierre**. Hoy solo H-12/H-14/H-15 tienen dueño/etapa declarados en `estado_proyecto.md`; el resto carece de asignación formal, lo que es en sí un **defecto de gobernanza** (H-04).

| Gate | Contenido / riesgo residual | Hallazgo(s) | Dueño | Etapa |
|---|---|---|---|---|
| **G-C0.1** | Migración v2→v3 ejecutable y probada contra `pg_dump` v2 + `schema-diff` + smoke test de triggers | H-01, N-01, N-02, N-07 | Datos/Backend (sin dueño asignado) | **C0 (bloqueante)** |
| **G-C0.2** | Anvil: prohibición de cuentas dev como roles, segundo RPC, gate de CI anti-cuentas Anvil | H-12, H-11 | Operaciones/Contratos (`estado:142`) | **C0** |
| **G-C0.3** | Backup/PITR con RPO ≤15 min / RTO ≤4 h, ensayo de restauración, copia/rotación de `KYC_ENCRYPTION_KEY`, pooling, RPC de respaldo, modelo de coste | H-14, H-15, H-41 | DevOps/Operaciones (`estado:143-144`) | **antes de C0** |
| **G-C1.1** | Retención Q10 ejecutable: cálculo de fechas, `ended_at`, job de purga auditado, test | H-17 | Datos/Backend (`estado:145`) | **C1** |
| **G-C1.2** | DPIA, opinión legal, consentimiento/base legal y notificación de brechas | H-16 | Producto/Legal | **C1** |
| **G-C2.1** | Autoridad emisor↔programa, semillas por programa, autorización única por claim | H-02, N-04, N-05 | Backend/Datos | **C2** |
| **G-C2.2** | Fiador: consentimiento firmado y estados; garantías revocables | H-10 | Producto/Backend | **C2–C3** |
| **G-C3.1** | Compliance on-chain: hook `_update`/`beforeTokenTransfer`, módulos, tests adversariales | H-07 | Contratos | **C3** |
| **G-C4.1** | Escrow: máquina de estados, job de expiración, tramo NFT, validación precio/vendedor/comisión, pruebas negativas/doble venta/timeout/reembolso | H-05, N-06, N-11 | Backend | **C4** |
| **G-C4.2** | Indexer: algoritmo de reorg/reset, reconciliación, SLO de lag y alertas | H-13 | Backend | **C0–C4** |
| **G-C5.1** | RBAC: Issuer/Auditor/Árbitro/Soporte como principales, `role_assignments`, cuentas por rol, `audit_log` append-only | H-23, H-34, H-10 (RBAC) | Backend/Seguridad | **C5** |
| **G-C5.2** | Accesibilidad y carga: manifiesto de 12 rutas, axe con umbral, p95 con condiciones, supuesto S-14 | H-22, H-28, H-44 | Frontend/QA | **C5** |
| **G-C6.1** | SLO/observabilidad: SLI, error budget, alertas, retención de logs, panel Sistema | H-18, H-19 | DevOps | **C6** |
| **G-Piloto.1** | Trazabilidad §6, §5.3 con nombres reales, versiones unificadas y CI de verificación | H-32, H-38, N-13, N-16, N-17 | QA/Documentación | **antes de piloto** |
| **G-Piloto.2** | Amenazas: threat model STRIDE, anti-abuso/rate limiting, nonce SIWE de un solo uso, TTL de sesión, rotación de secretos y auditoría externa de contratos | H-24 (y H-11/H-35) | Seguridad | **antes de piloto** |

**Riesgos residuales abiertos de mayor impacto si se ignoran:** pérdida de datos por migración no ejecutable (integridad de la BD v2), escrow que no avanza (trigger `orders`), activos revocados/pausados comprables, evidencia de cumplimiento (KYC) no purgable, y segregación de funciones no auditable. Ninguno tiene hoy mecanismo de cierre implementado.

---

## 8. Criterios de aceptación para la siguiente etapa y para autorizar un piloto

### 8.1 Para autorizar el paso a casos de uso + documento técnico (re-cierre de Fase 1)

Bloqueantes (todos obligatorios, con evidencia reproducible adjunta):

1. **B1. Migración ejecutable y probada:** `migracion_v2_a_v3.sql` completa en CI sobre un `pg_dump -Fc` v2 real, con log publicado, `schema-diff` contra una instalación limpia 3.0 (incluido el orden del enum `session_role`) y bloque §6 verificando `last_block`/`chain_id`/documentos/activos. H-01/N-02 cerradas con evidencia.
2. **B2. DDL ejecutable:** `UPDATE` de humo sobre **cada** tabla con trigger `updated_at` (incluida `orders`), y pruebas de ejecución de cada función/trigger; N-01 cerrado.
3. **B3. Escrow verificable:** máquina de estados con transiciones válidas, job/endpoint de expiración de reservas, tramo NFT del escrow modelado, validación de precio/vendedor/comisión contra `listings`/`platform_fees`, pruebas negativas de concurrencia/doble venta/timeout/reembolso. C4/C5 en CUMPLE.
4. **B4. Autoridad del Emisor:** vínculo emisor↔programa en BD y semillas para todos los programas (incluido SOCIO); E2E de alta ejecutado. C2/C3 en CUMPLE.
5. **B5. RBAC real:** matriz con Issuer/Auditor/Árbitro/Soporte, `role_assignments` append-only, cuentas por rol y matriz de pruebas de autorización positiva/negativa; `audit_log` append-only con retención/partición. C10 en CUMPLE.
6. **B6. Compliance on-chain:** hook especificado e implementado con `IdentityRegistry` y `token_required_claims` aplicados on-chain, con tests adversariales (transferencia a wallet no verificada). C7 en CUMPLE.
7. **B7. Retención Q10 ejecutable:** cálculo de `retention_delete_at`, `ended_at`, job de purga auditado, retención de `asset_documents` y test «0 filas vencidas servidas / 100 % purgas auditadas». C9 en CUMPLE.
8. **B8. Operación documentada:** backup/PITR con RPO/RTO y ensayo de restauración, copia/rotación de clave, pooling, RPC de respaldo con failover y modelo de coste con budget alerts. C13 en CUMPLE.
9. **B9. RNF falsables:** manifiesto cerrado de las 12 rutas + reglas axe con impacto serious/critical; p95 con entorno/concurrencia/dataset/ventana/herramienta; definición formal del «pico» (S-14); SLI/error budget/alertas y dueño. C8 en CUMPLE.
10. **B10. Estado único y compuerta honesta:** `estado_proyecto.md` regenerado desde artefactos (28 RF/14 RNF/S-1…S-13/26 tablas/138 sentencias; residuales reales), sin «Fase 1 cerrada» hasta que la compuerta pase; S-3 con dueño y fecha; Q1–Q13 unificadas. C4/C14 en CUMPLE.
11. **B11. Trazabilidad automatizada:** §6 generada desde la columna «Brief» con test que falle si un RF falta o se duplica de sección; §5.3 con nombres reales; versiones unificadas; script de verificación en CI publicado. C11/C14 en CUMPLE.
12. **B12. Compuerta de 14 criterios: 14/14 CUMPLE** con **0 CRÍTICAS y 0 ALTAS abiertas** y **0 PARCIALES**; toda excepción aceptada solo por decisión explícita del sponsor, registrada con dueño, fecha y criterio de verificación posterior.

### 8.2 Para autorizar un piloto

Además de B1–B12: (P1) ensayo de restauración y failover ejecutados con evidencia; (P2) prueba de carga a 2× el pico definido con resultados y sin dobles ventas; (P3) threat model STRIDE + rate limiting/nonce de un solo uso/TTL de sesión implementados; (P4) `audit_log` append-only probado (UPDATE/DELETE fallan); (P5) revisión legal de DPIA, retención y consentimiento aprobada; (P6) monitorización con alertas activas y panel Sistema conforme; (P7) presupuesto aprobado con budget alerts configuradas; (P8) acta de migración real firmada y datos legacy marcados (sin verificadores fabricados).

---

## 9. Firma

### 9.1 Contador final

| Categoría | Dictamen de compuerta (cifras certificadas) | Registro consolidado de esta síntesis |
|---|---|---|
| **CRÍTICAS abiertas** | **1** (H-01 migración) | **2** (H-01 + N-01 trigger `orders`, verificado por R6) |
| **ALTAS abiertas** | **10** | **15** (10 del dictamen + 5 ALTAS de lente absorbidas en criterios ya bloqueantes; ver §5.1) |
| **MEDIAS abiertas** | **13** | **24** (13 del dictamen, una reclasificada a ALTA, + 12 MEDIAS de lente verificadas y deduplicadas; ver §5.2) |
| **BAJAS abiertas** | **1** | **2** (B-01 versiones + H-43 proceso ISSUER) |
| **Cerrados / descartados** | — | **5 cerrados** (H-03, H-08 esencial, H-09, H-21, H-30) + **1 falso positivo** (H-42) + señales descartadas de §2.3 |
| **Criterios de compuerta** | **0 CUMPLE / 11 PARCIAL / 3 NO CUMPLE** | idéntico; **11 bloquean el cierre** (C1–C7, C9, C10, C13, C14) |

> Las dos columnas no se contradicen: la primera es el recuento del dictamen de compuerta; la segunda incorpora hallazgos verificados por las lentes que el dictamen no recontó (trigger de `orders`, indexer H-13, RNF-12 H-16, legibilidad H-22, escrow H-05 y las MEDIAS de modelo/seguridad). Ninguna de las dos variantes permite el cierre: **ambas incumplen el gate de 0 CRÍTICAS / 0 ALTAS abiertas.**

### 9.2 Dictamen

**NO se puede declarar cerrada la Fase 1 ni pasar a casos de uso/documento técnico.** El estado correcto es **«Fase 1 en corrección / re-auditoría»**, con la compuerta de re-cierre de §8.1 como condición de avance. El sistema tiene un andamiaje documental y de esquema sustancialmente mejor que en la iteración previa (parseo completo, 26/26/26 tablas, 225/225 columnas, Mermaid válido, RNF con umbrales, correcciones reales en KYC/SOCIO, 4-eyes, segregación y garantías), pero los defectos de ejecución (migración, trigger de `orders`), de modelo de roles/autoridad, de compliance on-chain, de retención y de operación impiden cualquier certificación de cierre.

### 9.3 Artefactos auditados (9 + brief + referencia v2)

| Artefacto | Ruta | mtime (revisión auditada) |
|---|---|---|
| Brief del producto | `RepoTecnico/BRIEF_BARLOBLOKCHAIN_v3.md` | 2026-10-31 17:12 |
| Requerimientos | `RepoTecnico/requerimientos.md` | 2026-11-02 01:59 |
| Propuesta v3 | `RepoTecnico/propuesta_v3.md` | 2026-11-02 02:01 |
| Diccionario de datos | `RepoTecnico/diccionario_datos.md` | 2026-11-02 02:00 |
| Diagrama ER | `RepoTecnico/diagrama_er.md` | 2026-11-02 01:58 |
| Esquema de base de datos | `RepoTecnico/base_datos.sql` | 2026-11-02 01:58 |
| Migración v2→v3 | `RepoTecnico/migracion_v2_a_v3.sql` | 2026-11-02 01:58 |
| Entornos globales | `RepoTecnico/entornos_globales.md` | 2026-11-02 02:00 |
| Estado del proyecto | `RepoTecnico/estado_proyecto.md` | 2026-11-02 02:01 |
| Informe de optimización v3 (histórico, criterios y hallazgos) | `RepoTecnico/INFORME_OPTIMIZACION_V3.md` | 2026-11-02 01:32 |
| Referencia v2 canónica (ensayo de migración) | `rwa-sc/RepoTecnico/base_datos.sql` (+ `pg_dump -Fc`) | — (v2 original) |

### 9.4 Constancia

- Informe emitido el **2026-11-02** por el **SINTETIZADOR de la re-auditoría de cierre de Fase 1 (RWA v3 «Barlo Metaplace»)** a partir de los verificados adversariales de las lentes R1–R6 y del dictamen verificado del auditor de compuerta (14 criterios).
- Ningún artefacto auditado fue modificado; el ensayo de migración se realizó en `/tmp` y fue eliminado. Este informe es el único documento creado.
- Las cifras de §3 son reproducibles con `pglast` 8.7 y `mermaid` 12.2.0; la ejecución real de la migración no pudo repetirse en el entorno del auditor de compuerta (sin `psql`/PostgreSQL/Docker) y se respalda en el ensayo de R2 (PostgreSQL 16.15, `exit=3`) y el análisis estático de R6 sobre la v2 canónica. Queda como condición B1 reproducirla en CI antes de cualquier declaración de cierre.
- **Conclusión firmada: Fase 1 NO cerrada. 11 criterios bloquean. 2 CRÍTICAS, 15 ALTAS, 24 MEDIAS y 2 BAJAS abiertas en el registro consolidado; 0/11/3 en la compuerta de 14 criterios.**

---

*Fin del informe.*
