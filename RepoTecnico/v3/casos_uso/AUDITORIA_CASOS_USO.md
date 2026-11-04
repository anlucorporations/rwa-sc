# Auditoría de casos de uso — RWA v3 «Barlo Metaplace»

**Documento:** `RepoTecnico/casos_uso/AUDITORIA_CASOS_USO.md`
**Fecha de emisión:** 2026-11-04
**Rol:** SINTETIZADOR de la auditoría de CASOS DE USO (Fase 3 de auditoría)
**Objeto auditado:** `RepoTecnico/casos_uso.md` v3.2 (890 líneas, 29 CU, 10 actores), con sus diagramas en `RepoTecnico/casos_uso/diagramas_casos_uso.md`.
**Insumos de contraste:** `RepoTecnico/requerimientos.md` v3.2 (31 RF · 14 RNF · 8 RT), `RepoTecnico/base_datos.sql` v3.2 (1520 líneas), `RepoTecnico/diseno_cierre_v3_2.md`, `RepoTecnico/estado_proyecto.md` (decisiones Q1–Q14a).
**Entradas de la fase adversarial:** 3 revisiones de lente (`REVISIONES = [{}, {}, {}]`) y 1 verificación adversarial consolidada (`VERIFICACIÓN`: 0 hallazgos, 0 descartados).

---

## 1. Veredicto

> ### ✅ SÍ — los casos de uso son aptos para pasar al documento técnico.

**Fundamento (sin hallazgos abiertos):**

1. La fase de revisión (3 lentes) entregó **0 hallazgos** y la verificación adversarial **0 supervivientes y 0 descartados**; no existe materia que deduplicar ni re-severizar.
2. **Cobertura completa:** los 10 actores de `casos_uso.md` §1 tienen al menos un CU con criterio testeable; los 29 CU están detallados y trazados; los 31 RF-V3 tienen CU directo (28) o tratamiento transversal/no-CU justificado (RF-V3-21, RF-V3-26, RF-V3-28).
3. **Consistencia verificada** con `requerimientos.md`, `base_datos.sql` y las decisiones Q1–Q14a: 4-eyes de recuperación, máquina de estados y doble tramo del escrow, singleton y rango de comisiones, ámbito de `role_assignments`, jobs de expiración/purga e indexer (evidencia en §5).
4. **Calidad formal suficiente:** 29/29 CU declaran tipo de prueba, 48 escenarios Gherkin con aserciones observables y 21 restricciones EARS; los desajustes detectados son **editoriales de trazabilidad**, no funcionales (ver §6.2 y §7).

**Condición no bloqueante:** aplicar las correcciones de forma de §7 (8 desajustes de trazabilidad —7 RF— en la matriz §5 y 3 escenarios adversariales opcionales). Ninguna altera requisitos ni cobertura; el documento técnico puede redactarse en paralelo.

---

## 2. Metodología

| Fase | Ejecución | Resultado |
|---|---|---|
| **1. Revisión (3 lentes)** | Tres revisiones independientes sobre `casos_uso.md`, sus diagramas y los artefactos de contraste. | `REVISIONES = [{}, {}, {}]` → **0 hallazgos** en las 3 lentes. |
| **2. Verificación adversarial** | Contraste de cada hallazgo contra los artefactos; deduplicación y ajuste de severidad; **ante la duda, se descarta**. | Sin hallazgos de entrada, el conjunto de supervivientes es vacío. Aun así se contrastó la coherencia CU ↔ RF/RNF ↔ DDL ↔ decisiones para descartar una contradicción grave oculta. Resultado: **0 hallazgos · 0 descartados**. |
| **3. Síntesis (este informe)** | Consolidación de lo verificado, tablas de cobertura y calidad, correcciones accionables y firma. | **0 CRÍTICAS · 0 ALTAS · 0 MEDIAS · 0 BAJAS.** |

**Reglas aplicadas:** (a) toda afirmación se ancla a `ruta:línea`; (b) lo no reproducible se marca como no verificado; (c) **ante la duda se descarta** y no se promueve a hallazgo; (d) el sintetizador **no crea hallazgos nuevos**: las observaciones de §6.2 y las correcciones de §7 son de forma, detectadas al completar la tabla de trazabilidad, y se declaran explícitamente **fuera del cómputo de hallazgos**.

**Limitación declarada:** al haber llegado vacías las 3 lentes, no fue posible deduplicar entre lentes ni re-severizar hallazgos propios; el veredicto se apoya en la verificación adversarial y en la comprobación documental directa de cobertura/consistencia recogida en §3–§5. No se modificó ningún artefacto auditado (auditoría de solo lectura; este informe es el único archivo creado).

---

## 3. Cobertura: actores (10), CU (29), RF (31)

### 3.1 Tabla de universos y huecos

| Dimensión | Universo | Cubierto | Huecos | Evidencia |
|---|---|---|---|---|
| **Actores** | 10 | **10 (100 %)** | **0** | `casos_uso.md:11-24` (actores) + §3/§4 (cada actor es actor primario de ≥1 CU) |
| **Casos de uso** | 29 | **29 detallados (100 %)**, con Gherkin y tipo de prueba | **0** | `casos_uso.md:40-70` (catálogo) y `:76-832` (detalle) |
| **Requerimientos funcionales** | 31 | **31 (100 %)**: 28 con CU directo + 3 con tratamiento justificado | **0 sin cobertura** | `casos_uso.md:838-869` (matriz §5) |
| **Requerimientos no funcionales** | 14 | Cobertura parcial declarada (RNF-V3-01…14 aparecen en trazas de CU, no todos) | No evaluado como hueco en esta auditoría (0 hallazgos de lente) | `casos_uso.md` trazas §4 |

### 3.2 Actores → CU (sin huecos)

| Actor | CU donde es actor primario | Suite |
|---|---|---|
| Visitante | CU-01, CU-02 | Metaplace |
| Usuario | CU-03, CU-04, CU-05, CU-06, CU-20, CU-21, CU-22, CU-23, CU-25 | Identity / Token |
| Fiador | CU-07 | Identity |
| Operador | CU-09 | Issuer |
| Emisor (Issuer) | CU-10, CU-11, CU-12, CU-13, CU-14, CU-20 | Issuer / Token |
| Admin | CU-08, CU-10, CU-11, CU-15, CU-16, CU-17 | Issuer |
| Auditor | CU-17, CU-18 | Issuer |
| Árbitro | CU-24 | Token |
| Soporte | CU-19 | Issuer |
| Sistema | CU-26, CU-27, CU-28, CU-29 | Jobs |

**Reparto por suite (29 CU):** Metaplace 2 · Identity 5 · Issuer 12 · Token 6 · Jobs de sistema 4. Coherente con las tres suites del brief y con RF-V3-01/03/04/05.

**Nota de cobertura (no es hueco):** `requerimientos.md:19` enumera 7 actores; `casos_uso.md:11-24` despliega **10**, añadiendo Auditor, Árbitro y Soporte (exigidos por RF-V3-27) y desdoblando Sistema (RF-V3-23/30). Es una **ampliación coherente** con RF-V3-27, no una inconsistencia.

### 3.3 RF sin CU directo (justificados, no huecos)

| RF | Tratamiento en el documento | Evidencia | ¿Hueco? |
|---|---|---|---|
| **RF-V3-21** (mensajes de firma comprensibles) | Requisito transversal; se verifica en CU-02/04/07/10/21/22 y en la tabla `wallet_messages` del DDL | `casos_uso.md:859` · `base_datos.sql:142-156` | No (transversal) |
| **RF-V3-26** (migración v2→v3) | No es caso de uso; validado en acta v3.1 y en `migracion_v2_a_v3.sql` | `casos_uso.md:864` | No (no-CU justificado) |
| **RF-V3-28** (asistencia guiada) | Requisito transversal de UX sobre CU-01…CU-04 | `casos_uso.md:866` | No (transversal) |

---

## 4. Calidad Gherkin/EARS: criterios bien formados vs corregibles

### 4.1 Métricas objetivas

| Indicador | Valor | Lectura |
|---|---|---|
| CU con bloque Gherkin | **29/29** | 100 % de los CU tienen criterios de aceptación |
| Escenarios Gherkin | **48** en 29 CU | 19 CU con 2 escenarios; 10 CU con 1 escenario |
| Escenarios con aserción observable (HTTP/estado/fila/conteo) | **48/48** | Todos verificables por API, DB o contrato |
| Escenarios con cifra explícita en el resultado | **29/48** | El resto usa estado/HTTP/SQL, igualmente binario |
| Restricciones EARS | **21** en **14 CU** | 14/29 CU declaran restricciones de sistema; 15 no las requieren o no las declaran |
| CU con alternativas en prosa | **19/29** | Complementa la cobertura negativa |
| CU con camino negativo/adversarial (escenario, alternativa o EARS) | **26/29** | 3 sin camino negativo explícito (CU-19, CU-24, CU-29) |
| CU con tipo de prueba declarado | **29/29** | E2E / API / DB / CONTRATO / JOB en combinaciones |
| Criterios con adjetivo no binario | **1** | CU-01:97 «mensaje comprensible» |

### 4.2 Criterios bien formados vs corregibles

| Ámbito | Bien formados | Corregibles (no bloqueantes) | Recomendación |
|---|---|---|---|
| Estructura Gherkin | 48/48 escenarios con `Dado/Cuando/Entonces` y resultado observable | — | Sin acción |
| Cobertura negativa | 26/29 CU con camino de fallo/edge | **CU-19, CU-24, CU-29** (solo camino feliz) | Añadir 1 escenario adversarial por CU (§7-B) |
| Restricciones EARS | 21 restricciones medibles; 14 CU cubiertos | **15 CU sin EARS** (no todos requieren restricción de sistema) | Opcional: declarar «sin restricción EARS aplicable» para dejar constancia |
| Lenguaje binario | 47/48 aserciones sin ambigüedad | **CU-01:97** «mensaje comprensible» | Sustituir por criterio comprobable (§7-B) |
| Trazabilidad criterio→RF | Todos los criterios declaran RF/RNF de origen | Asimetrías matriz §5 ↔ detalle (§6.2) | Correcciones §7-A |
| Testeabilidad | 29/29 CU con tipo de prueba y criterio numérico/estado | — | Sin acción |

**Conclusión de calidad:** el formato Gherkin/EARS es **apto**; las carencias son de **completitud de escenarios** y **una redacción**, no de testabilidad estructural. No se promueven a hallazgo por impacto bajo y porque las lentes no las reportaron.

---

## 5. Consistencia con DDL y decisiones Q1–Q14

Contraste directo de `casos_uso.md` con `base_datos.sql` v3.2 y las decisiones registradas en `estado_proyecto.md:54-69`. **Todas las comprobaciones resultaron coherentes.**

| Decisión | Contenido | Evidencia DDL / documento | Estado |
|---|---|---|---|
| **Q1** | v3 sustituye a v2 sobre la misma infraestructura | `migracion_v2_a_v3.sql` (ETL versionado) · esquema `rwa` · CU sobre las 3 suites | ✅ Coherente |
| **Q2** | BRLT = token de utilidad, sin valor real; 8 decimales | Columnas de importes `numeric(20,8)` (`base_datos.sql:133-134,339,426,447`); BRLT como única moneda de listado | ✅ Coherente |
| **Q3** | Marketplace v3.0 a **precio fijo** con escrow | `listings` precio fijo (`base_datos.sql:421-436`); sin tablas de ofertas/subastas; CU-20…CU-24 | ✅ Coherente |
| **Q4** | Comisión 5 % configurable + fee de tokenización; `FeeCollector` | `platform_fees` singleton, `sale_fee_bps DEFAULT 500` y rango 0–5000 (`base_datos.sql:131-139`); trigger de economics (`:1040-1042`); CU-16, CU-22 | ✅ Coherente |
| **Q5** | Non-custodial + recuperación asistida con doble aprobación | `identity_recovery_requests` con `recovery_double_approval` y `recovery_four_eyes` (`base_datos.sql:288,307-320`); CU-06 | ✅ Coherente |
| **Q6** | Catálogo solo BRLT + tokens/NFTs RWA en v3.0 | `listings.currency CHECK (currency = 'BRLT')` (`base_datos.sql:436`); no hay monedas alternativas; CU-01, CU-20, CU-21 | ✅ Coherente |
| **Q7** | Piloto LatAm (VE, CO, PA, MX, CL, PE, AR) | `jurisdictions` + semilla de 7 países (`base_datos.sql:107-118,1239,1270-1277`); CU-04 (claims de jurisdicción) y CU-15 (roles) no contradicen Q7 | ✅ Coherente |
| **Q8** | Claims sin caducidad en v3.0; columna preparada | `claim_requests.expires_at` NULL por defecto y comentario Q8 (`base_datos.sql:240,1261`); CU-05/CU-11 | ✅ Coherente |
| **Q9** | Tasación documental en BRLT con tope al precio de listado | `tokens_price_leq_valued` (`base_datos.sql:351-354`) + trigger (`:730-732`); CU-12, CU-14, CU-20 | ✅ Coherente |
| **Q10** | Retención 30 días tras rechazo / 12 meses tras fin de relación | Triggers de fechas (`base_datos.sql:783-787,906-926`) + `purge_expired_documents()` (`:1138-1160`); CU-27 | ✅ Coherente |
| **Q11** | Emisor = rol de plataforma acotado, persistido por claim | `role_assignments` con ámbito (`base_datos.sql:519-534`) + trigger emisor↔programa (`:869-…`); CU-10, CU-11, CU-15 | ✅ Coherente |
| **Q12** | Escrow completo: TTL, una orden abierta, idempotencia, atomicidad, disputa | `ux_orders_open` y `ux_orders_escrow_tx` (`base_datos.sql:641-649`); máquina de estados (`:989-1024`) y doble tramo (`:1006-1012`); TTL 30 min (`:947-948`); CU-21…CU-24, CU-26 | ✅ Coherente |
| **Q13** | Demo/piloto sin activos reales + gate legal previo | `requerimientos.md:133` (S-8) y `:101` (RNF-V3-12); el CU solo opera BRLT simbólico (CU-16, CU-21) | ✅ Coherente (decisión de alcance, no requiere CU) |
| **Q14a** | Fase 1 cerrada como baseline de diseño; implementación a gates C0–C6 | `estado_proyecto.md:4,17,69`; `casos_uso.md:3` declara base en `diseno_cierre_v3_2.md` | ✅ Coherente |

**Sin contradicciones DDL ↔ CU detectadas.** La verificación adversarial revisó además, sin hallazgos: 4-eyes (`base_datos.sql:307-318`), máquina de estados y doble tramo de escrow (`:997-1010`), singleton/rango de fees (`:131-139`), ámbito de roles (`:519-532`), `expire_orders`/`purge_expired_documents` (`:1118,1138`) y `chain_events`/`indexer_state` (`:561,580`).

---

## 6. Hallazgos abiertos por severidad

### 6.1 Cómputo oficial

| Severidad | Abiertos | IDs | Evidencia | Recomendación |
|---|---|---|---|---|
| **CRÍTICA** | **0** | — | — | — |
| **ALTA** | **0** | — | — | — |
| **MEDIA** | **0** | — | — | — |
| **BAJA** | **0** | — | — | — |
| **TOTAL** | **0** | — | 0 hallazgos · 0 descartados | Aplicar correcciones editoriales de §7 |

No hay hallazgos que reportar: las 3 lentes no emitieron ninguno y la verificación adversarial no tenía materia que filtrar. **No se promueve ningún hallazgo nuevo desde la síntesis.**

### 6.2 Observaciones no promovidas (fuera del cómputo de hallazgos)

La verificación adversarial citó, sin promoverlas, **asimetrías de trazabilidad** entre la matriz §5 y el detalle de cada CU. Al completar la comprobación se confirman **8 desajustes (7 RF, 14 pares RF↔CU)** de la misma clase, todos de **impacto bajo** (no hay RF ni CU sin cobertura; solo difiere dónde se declara):

| # | RF | Matriz §5 dice | Detalle del CU | Evidencia |
|---|---|---|---|---|
| O-01 | RF-V3-02 | CU-02 | CU-02 no lo lista | `casos_uso.md:840` vs `:133` |
| O-02 | RF-V3-04 | CU-08, 09, 10, 15, 17 | Ninguno de los 5 lo lista | `:842` vs `:310,340,371,502,552` |
| O-03 | RF-V3-05 | CU-20 | CU-20 no lo lista *(citado por la verificación)* | `:843` vs `:619` |
| O-04 | RF-V3-13 | CU-10 | CU-10 no lo lista | `:851` vs `:371` |
| O-05 | RF-V3-25 | No incluye CU-16 | CU-16 sí lo lista | `:863` vs `:527` |
| O-06 | RF-V3-27 | No incluye CU-06 ni CU-17 | Ambos sí lo listan | `:865` vs `:251,552` |
| O-07 | RF-V3-29 | No incluye CU-08 | CU-08 sí lo lista | `:867` vs `:310` |
| O-08 | RF-V3-31 | CU-10 y CU-21 | Ninguno de los dos lo lista *(CU-10 citado por la verificación)* | `:869` vs `:371,647` |

**Dictamen:** se mantienen como **observaciones editoriales no promovidas** (regla «ante la duda, se descarta» + impacto bajo), y se resuelven en §7-A. No alteran cobertura ni veredicto.

---

## 7. Correcciones concretas a aplicar en `casos_uso.md`

### A. Trazabilidad matriz §5 ↔ detalle (obligatorias de forma, no bloqueantes)

Criterio: una sola fuente de verdad por fila. Se recomienda alinear el detalle con la matriz §5, salvo cuando la fila de la matriz sea la incorrecta (C-01, C-05), en cuyo caso se corrige la matriz y se mantiene el detalle.

| # | Archivo:línea | Cambio propuesto |
|---|---|---|
| C-01 | `casos_uso.md:840` | Añadir `RF-V3-02` a la traza de CU-02 (`:133`) **o** retirar CU-02 de la fila de RF-V3-02 (el login no exige claim Socio). Preferible: retirar CU-02 y dejar `RF-V3-02 → CU-01`. |
| C-02 | `casos_uso.md:842` | Añadir `RF-V3-04` a las trazas de CU-08 (`:310`), CU-09 (`:340`), CU-10 (`:371`), CU-15 (`:502`) y CU-17 (`:552`), o sustituir la fila por una nota «suite Issuer (CU-08/09/10/15/17)». |
| C-03 | `casos_uso.md:619` | Añadir `RF-V3-05` a la traza de CU-20 (publicación en la suite WEB-TOKEN), alineando con `:843`. |
| C-04 | `casos_uso.md:371` | Añadir `RF-V3-13` a la traza de CU-10 (aprobación/emisión dentro del flujo de solicitud). |
| C-05 | `casos_uso.md:527` | Añadir `CU-16` a la fila RF-V3-25 (`:863`) **o** retirar RF-V3-25 de la traza de CU-16 (la configuración de comisión no abre órdenes). Preferible: retirar del detalle. |
| C-06 | `casos_uso.md:865` | Añadir `CU-06` y `CU-17` a la fila RF-V3-27 (recuperación asistida y panel de auditoría). |
| C-07 | `casos_uso.md:867` | Añadir `CU-08` a la fila RF-V3-29 (creación de ISSUER con rol admin auditado). |
| C-08 | `casos_uso.md:371,647` | Añadir `RF-V3-31` a las trazas de CU-10 y CU-21 (compliance on-chain en emisión/transferencia), alineando con `:869` — **el desajuste de CU-10 fue citado expresamente por la verificación**. |

### B. Calidad editorial (opcionales, recomendadas antes de C1)

| # | Archivo:línea | Cambio propuesto |
|---|---|---|
| C-09 | `casos_uso.md:97` | Sustituir «mensaje comprensible y sin detalles internos» por criterio binario: «cuerpo sin stack trace, sin nombres de tabla ni rutas internas; `Content-Type: application/json`; campo `error` de la lista cerrada». |
| C-10 | `casos_uso.md:593` (CU-19) | Añadir escenario adversarial: incidencia sin rol `support` → `403`; SLA ausente → error de validación. |
| C-11 | `casos_uso.md:717` (CU-24) | Añadir escenario: disputa `resolved` → nueva resolución rechazada; árbitro no asignado → `403`. |
| C-12 | `casos_uso.md:831` (CU-29) | Añadir escenario de idempotencia: segunda pasada del job no vuelve a marcar el mismo pago. |
| C-13 | `casos_uso.md:874` | Aclarar en §6.2 que **RF-V3-21, RF-V3-26 y RF-V3-28** son los tres RF sin CU propio (hoy cita solo 26 y 28). |
| C-14 | `casos_uso.md:859` | Etiquetar la fila de RF-V3-21 como «transversal (no-CU)» para que un lector automatizado no la cuente como CU. |

> Ninguna corrección modifica el alcance funcional ni requiere re-auditoría: son cambios de trazabilidad/redacción.

---

## 8. Preguntas para el sponsor (decisiones abiertas)

Las 4 preguntas abiertas ya declaradas en `casos_uso.md:883-886` siguen vigentes. **Ninguna bloquea el paso al documento técnico**, pero conviene resolverlas antes de C1 porque afectan a CU transversales y a RNF:

| # | Pregunta | Impacto | Recomendación del sintetizador |
|---|---|---|---|
| **Q15** | ¿La asistencia guiada (RF-V3-28) se implementa como wizard de 4 pasos o como ayuda contextual por pantalla? | Define CU transversales de UX y criterios de RF-V3-28 | Resolver antes de documentar la capa UX; si no, el documento técnico debe dejar ambas opciones como decisión C1 |
| **Q16** | ¿El soporte (CU-19) opera dentro del Metaplace o por canal externo con registro manual? | Alcance de la suite Admin y modelo de datos de incidencias | Confirmar canal y SLA antes de C1 |
| **Q17** | ¿El alta de Socio exige también claim de JURISDICCIÓN desde el inicio o se puede completar después? | Flujo CU-04/CU-10 y estado de identidad | Confirmar con el sponsor; impacta la secuencia de claims |
| **Q18** | ¿La exportación de auditoría debe incluir datos personales cifrados o solo metadatos? | RNF-V3-02/12 y CU-18 | Resolver antes de C1; hoy CU-18 es agnóstico (CSV + sha256) |

**No surgieron preguntas nuevas** en esta auditoría.

---

## 9. Firma

| Contador | Valor |
|---|---|
| **CRÍTICAS** | **0** |
| **ALTAS** | **0** |
| **MEDIAS** | **0** |
| **BAJAS** | **0** |
| **TOTAL hallazgos abiertos** | **0** |
| Hallazgos descartados por la verificación adversarial | **0** |
| Observaciones editoriales no promovidas (§6.2) | **8** |
| Correcciones accionables (§7) | **14** (8 de trazabilidad + 6 editoriales) |

### Artefactos auditados (solo lectura)

| Artefacto | Líneas | SHA-256 (prefijo) |
|---|---|---|
| `RepoTecnico/casos_uso.md` | 890 | `b965afbcb3db022a` |
| `RepoTecnico/casos_uso/diagramas_casos_uso.md` | 285 | `8c192b622255e17f` |
| `RepoTecnico/requerimientos.md` | 182 | `78f7d01d972eeae7` |
| `RepoTecnico/base_datos.sql` | 1520 | `cba3f504afd56fbc` |
| `RepoTecnico/diseno_cierre_v3_2.md` | 305 | `7581ed81de27dd52` |
| `RepoTecnico/estado_proyecto.md` | 204 | `fa35d9c6729fb4b5` |
| `RepoTecnico/migracion_v2_a_v3.sql` | 368 | (contraste de Q1; no se modificó) |

**Firma:** SINTETIZADOR — auditoría de casos de uso · RWA v3.2 · 2026-11-04.
**Veredicto final:** **SÍ**, aptos para el documento técnico, con las correcciones de forma de §7 como tarea de higiene documental.
