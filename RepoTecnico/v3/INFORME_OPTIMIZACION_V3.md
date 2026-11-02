# INFORME DE OPTIMIZACIÓN V3 — Auditoría RWA v3 «Barlo Metaplace»

**Proyecto:** RWA v3 — «Barlo Metaplace» (tokenización de activos reales, suites WEB-IDENTITY / WEB-ISSUSER / WEB-TOKEN)
**Alcance auditado:** los 8 artefactos de Fase 1 en `RepoTecnico/` — `BRIEF_BARLOBLOKCHAIN_v3.md`, `requerimientos.md`, `propuesta_v3.md`, `diccionario_datos.md`, `diagrama_er.md`, `base_datos.sql`, `entornos_globales.md` y `estado_proyecto.md` — contrastados con el esquema v2 real (`rwa-sc/RepoTecnico/`) donde el hallazgo dependía de la base heredada.
**Fecha de síntesis:** consolidación de la Fase 3 sobre las verificaciones adversariales R1–R7.
**Versión del informe:** V3 · **Modo:** auditoría de solo lectura (no se modificó ningún artefacto del proyecto durante la auditoría).

---

## 1. Resumen ejecutivo

### 1.1 Veredicto explícito

| Pregunta | Veredicto |
|---|---|
| **¿Está la Fase 1 (Concepto) lista para pasar a Fase 2 (casos de uso y documento técnico)?** | **NO en el estado actual.** La documentación es un borrador sólido y mayoritariamente coherente, pero **no constituye una línea base certificable**: 2 hallazgos CRÍTICOS y 20 ALTOS invalidan la compuerta de cierre y varios criterios de aceptación de los ciclos C0–C5. **Sí podrá pasar a Fase 2 tras un sprint de corrección documental y de modelo de datos de ~1–2 semanas**, sin necesidad de reescribir la propuesta. |
| **¿Es apto para producción / uso con activos reales?** | **NO. El proyecto no es apto para producción con activos reales en su estado actual.** Es un diseño de demo/piloto sobre Anvil local (chainId 31337), con token BRLT declarado sin valor real, claves de desarrollo públicas, ausencia de auditoría externa de contratos, de compliance regulatorio, de backup/DR verificado y de SLO. Nada de ello es descalificante para la Fase 1, pero sí bloquea cualquier uso con dinero o activos de terceros. |
| **¿Es apto para continuar a Fase 2 con condiciones?** | **SÍ, con condiciones.** No hay defecto fatal ni reescritura de arquitectura: los 44 hallazgos consolidados son corregibles en documentación, decisión de producto y DDL. El defecto dominante es de **testabilidad y de sincronía entre artefactos**, no de concepto. |

**Justificación del veredicto negativo para producción.** El diseño concentra en un único Admin (con la cuenta #0 de Anvil, de clave privada pública) la emisión de claims, la tokenización, la aprobación de recuperaciones, el mint/pausa de BRLT y el cobro de comisiones; el "escrow" retiene BRLT sin atomicidad del NFT ni proceso de disputa; el control de doble aprobación de recuperación es eludible con la misma wallet; la migración v2→v3 no es ejecutable; y no existe modelo de rol persistido, compliance on-chain de transferencias, ni RNF de disponibilidad, recuperación u observabilidad. Cualquiera de estos puntos basta para vetar activos reales.

**Justificación del veredicto positivo para continuar a Fase 2.** El núcleo del modelo de datos es internamente coherente: **25/25 tablas** cuadran entre diccionario, ER y SQL; las **102 sentencias SQL** parsean sin errores; los **5 bloques Mermaid** son válidos; y las 23 RF / 11 RNF / 8 RT están mayoritariamente trazadas contra el brief. Los CRÍTICOS son de **migración** y de **autoridad del Emisor**, ambos resolubles con DDL, una decisión Q11 y una validación con el sponsor.

### 1.2 Cifras de la consolidación

- **Candidatos brutos:** ≈ 84 (7 lentes × ~12 hallazgos propuestos).
- **Hallazgos verificados que sobreviven a la verificación adversarial:** 70 (10 por cada verificador R1–R7).
- **Hallazgos únicos consolidados: 44** — **2 CRÍTICOS, 20 ALTOS, 19 MEDIOS y 3 BAJOS.**
- **Falsos positivos / duplicados descartados en Fase 2:** 13, más 11 fusiones entre dimensiones (p. ej. la doble aprobación de recuperación aparecía en R1, R4 y R7; el marketplace/escrow en R1, R2, R3, R4, R6 y R7; la cuenta Admin de Anvil en R6 y R7; el modelo de roles en R2, R4, R5 y R7).
- **Duplicación típica:** el mismo hecho verificado aparecía en 2–6 dimensiones; la regla aplicada fue fusionar conservando la evidencia más fuerte y la severidad más alta justificada, y descartar el resto.

### 1.3 Los cinco riesgos dominantes

1. **No hay una migración v2→v3 ejecutable** (H-01): el script v3 se apoya en `CREATE TABLE IF NOT EXISTS` sobre 9 tablas heredadas y no evoluciona columnas ni enums; el criterio de aceptación de C0 («esquema `rwa` v1.3») es hoy inverificable.
2. **La autoridad de emisión de claims no está decidida ni registrada** (H-02): el Emisor/Issuer del brief no tiene rol en el RBAC, no se persiste qué emisor firma cada claim y R-1 se declaró cerrado sin validación del sponsor.
3. **La integridad del marketplace no está garantizada por el esquema** (H-05): sin reserva de inventario, sin `UNIQUE` en tx de escrow/pago, sin atomicidad del NFT, sin estado de disputa y sin árbitro.
4. **Los controles de identidad declarados son eludibles** (H-06, H-08): el fail-closed de Garantía+Fiador cuenta filas `verified=true` sin exigir claim aprobado, y la "doble aprobación" de recuperación cabe en una sola wallet.
5. **El entorno y la operación no son aptos para activos reales** (H-11 a H-19): clave Admin de Anvil pública en un RPC `NEXT_PUBLIC`, Anvil sin persistencia, indexer singleton de 10 min sin reorg/reset, Cloud SQL única sin HA/backup documentado y sin SLO ni observabilidad.

---

## 2. Metodología

### 2.1 Estructura en 3 fases

| Fase | Objetivo | Resultado |
|---|---|---|
| **Fase 1 — Revisión multidimensional (7 lentes en paralelo)** | 7 revisores independientes examinan los 8 artefactos con una lente distinta cada uno: (1) Ambigüedad y testabilidad, (2) Consistencia documental, (3) Completitud RNF / ISO 25010, (4) Stakeholders, (5) Trazabilidad con el brief, (6) Riesgos técnicos, (7) Seguridad y legal. | ≈ 84 hallazgos candidatos brutos (≈ 12 por lente). |
| **Fase 2 — Verificación adversarial** | Cada candidato se contrasta contra los archivos reales con `read`/`grep`/`glob` y, cuando aplica, contra el esquema/artefactos v2; se corrige la cita `ruta:línea`, se ajusta la severidad y se aplica la **regla de descarte**. | 7 verificadores R1–R7; **70 hallazgos sobreviven** (10 por verificador) tras descartar 13 falsos positivos y duplicados. |
| **Fase 3 — Síntesis** | Deduplicación entre lentes, asignación de IDs únicos `H-01…`, priorización por severidad, consolidación de RNF y stakeholders faltantes, y redacción de este informe. | **44 hallazgos únicos priorizados** + plan de acción + criterios de cierre. |

### 2.2 Las 7 lentes

1. **Ambigüedad / testabilidad** — criterios de aceptación medibles y falsables.
2. **Consistencia** — coherencia entre documentos, DDL, diccionario y ER.
3. **Completitud RNF (ISO 25010)** — cobertura de las categorías de calidad.
4. **Stakeholders** — actores definidos, responsables y ausentes.
5. **Trazabilidad** — correspondencia brief ↔ RF/RNF ↔ ciclos ↔ datos.
6. **Riesgos técnicos** — arquitectura, migración, indexación, on-chain, operación.
7. **Seguridad y legal** — explotabilidad, gobernanza de claves, protección de datos y cumplimiento.

### 2.3 Regla de descarte

> **Ante la duda, se descarta.** Un hallazgo solo sobrevive si (a) se verifica directamente contra un archivo real o contra el esquema v2 y la cita `ruta:línea` sostiene la afirmación, (b) tiene impacto verificable sobre el alcance de Fase 1, y (c) no es un sub-claim ya contenido en otro hallazgo. Las severidades se ajustan a la baja cuando la evidencia muestra que el revisor las sobrevaloraba; no se suben sin evidencia nueva.

### 2.4 Falsos positivos y duplicados descartados en Fase 2

| # | Propuesta descartada | Motivo de descarte |
|---|---|---|
| 1 | «Socio vigente» como puerta de acceso con dos fuentes de verdad (`kyc_level` vs claim SOCIO) | Especulativo: ningún artefacto declara `kyc_level` como gate; Q8 permite derivar "vigente = no revocado". (R1) |
| 2 | La separación Operador/Admin no es testeable por usar `claim_requests` un único `reviewed_by` | Parcialmente falso: `audit_log` registra actor, rol y acción, y RNF-V3-01 exige test de autorización por recurso; el defecto real (no registrar la verificación) se conserva como H-09. (R1) |
| 3 | `tokens` no tiene lote/SKU pese a RF-V3-15 y §4.4 | Carencia de completitud, no contradicción: `unit`/`metadata_uri`/documentos admiten identificar el lote. (R2) |
| 4 | Q3 (precio fijo) contradicho por RF-V3-05, matriz RBAC y §4.4 | Discrepancia editorial ya acotada por Q3, RF-V3-19 y el criterio de C4; no bloquea. (R2) |
| 5 | El ER declara relaciones sin FK y omite jurisdicción | Falso positivo parcial: el ER no promete integridad referencial y la jurisdicción es representable vía claim JURISDICCION; se conserva solo la parte funcional (jurisdicciones sin camino de datos) como H-33. (R3) |
| 6 | Los tokens no representan varios NFTs por contrato ni el consumo de servicios | RF-V3-16 es un requerimiento blando («se valorará») y RT-V3-03 difiere el mapeo 721/1155 a Fase 2; se conserva solo la ambigüedad de decisión como H-25. (R3) |
| 7 | El indexer tratado como actor sin responsable humano | `requerimientos.md:19` lo lista como componente, no como stakeholder; el monitoreo está asignado al Administrador. (R4) |
| 8 | Contradicción `ADMIN_PRIVATE_KEY` vs firma con keystore/`argv` | Es variable de entorno, no `argv`; se conserva la ausencia de dueño/rotación/break-glass como H-35. (R4) |
| 9 | Intercambio/criptomonedas simbólicas contradichas sin control de cambio | Duplicado de consistencia ya recogido; la reducción está documentada en Q3/Q6/S-9. (R5) |
| 10 | Claims JURISDICCION/ACREDITACION inventados sin ISSUER emisor | Catálogo explícitamente extensible y heredado de v2; los 3 ISSUER son semillas. (R5) |
| 11 | Gobierno/secretos duplicado y RBAC como riesgo R6 | Solapamiento con H-11/H-35 y dimensión de seguridad; sub-claims no concluyentes. (R6) |
| 12 | Plantillas de mensajes mutables sin vínculo criptográfico con el digest | La propuesta define el paquete EIP-712 y tests de digest↔texto; el escenario exige un fallo de implementación no verificable. (R7) |
| 13 | Modelo de amenazas del escrow (reentrancy, autoridad de liberación) | Se fusiona la parte verificable en el esquema (H-05); la parte de reentrancy se refiere a contratos que aún no existen. (R7) |

### 2.5 Cautela metodológica

En ninguna fase se editaron los artefactos del proyecto; todas las comprobaciones fueron de lectura y contraste. La auditoría usa la documentación y el DDL como fuente, no código v3 ejecutable (no existe todavía). Por tanto los hallazgos de operación (HA, backups, IAM, coste) se formulan como **"no documentado / no verificable en los artefactos"**, no como hechos del entorno real. Las métricas mecánicas de la sección 3 fueron validadas con parseo/recuento directo.

---

## 3. Estado de calidad

### 3.1 Métricas mecánicas ya validadas

| Métrica | Resultado verificado | Estado |
|---|---|---|
| Artefactos auditados | 8 documentos/DDL · 2.462 líneas leídas | ✅ |
| Tablas definidas | **25** en `base_datos.sql`; **25/25** coherentes entre diccionario, ER y SQL | ✅ |
| Sentencias SQL | **102** sentencias parseadas sin errores (PostgreSQL 15) | ✅ |
| Bloques Mermaid | **5/5** sin errores de sintaxis; 25/25 tablas cubiertas | ✅ |
| Recuento de RF / RNF / RT | 23 RF · 11 RNF · 8 RT declarados | ✅ |
| Convención de migraciones | **contradictoria**: `1.3` vs `3.0`, sin fila `1.3` en `schema_migrations` | ❌ H-01 |
| Colisiones de tablas v2 | **9 tablas heredadas** recreadas con `CREATE TABLE IF NOT EXISTS` | ❌ H-01 |
| Criterios de aceptación C0–C6 | C0, C3, C4 y C5 **no verificables** con el texto actual; C1/C2/C6 parciales | ❌ H-05, H-08, H-09, H-17, H-18, H-22 |

### 3.2 Lo que el parseo no detecta

El hecho de que el DDL parsee y las 25 tablas cuadren **no valida la semántica ni la migración**: el script v3 puede estar sintácticamente perfecto y no ser ejecutable sobre una BD v2 (H-01), y puede ser internamente coherente y no implementar los controles que la prosa promete (H-06, H-08). Las métricas mecánicas son condición necesaria, no suficiente; el veredicto se apoya en el contraste semántico de la Fase 2.

### 3.3 Cobertura de los criterios de aceptación por ciclo

| Ciclo | Criterio declarado | ¿Verificable con los artefactos actuales? | Bloqueo principal |
|---|---|---|---|
| **C0** | Esquema `rwa` v1.3 · BRLT desplegado · mint/burn/pause probados | ❌ No | H-01 (versión y migración), H-26 (cap/política), H-11 |
| **C1** | Usuario sin Socio no entra; con Socio sí; E2E | ⚠️ Parcial | H-03 (semilla circular KYC), H-02 |
| **C2** | Crear ISSUER sin redeploy; 3 tipos de requisito | ⚠️ Parcial | H-02 (autoridad/registro del emisor), H-43 |
| **C3** | Tokenizar sin Garantía/Fiador revierte; 3 tipos acuñan | ❌ No (control eludible) | H-06, H-25 (NFT quemable sin decisión) |
| **C4** | Compra E2E con escrow, comisión, evento indexado | ❌ No | H-05 (reserva/idempotencia/atomicidad/disputa), H-13 |
| **C5** | 100 % de procesos con mensaje legible; recuperación con doble aprobación | ❌ No | H-08, H-22, H-21, H-17 |
| **C6** | Cobertura ≥ 80 %/70 %, E2E, despliegue, manuales | ⚠️ Parcial | H-18, H-19, H-14 |

---

## 4. Tabla resumen por severidad

**Recuento: 2 CRÍTICAS · 20 ALTAS · 19 MEDIAS · 3 BAJAS = 44 hallazgos únicos.**

### 4.1 Críticas (2)

| ID | Severidad | Área | Título | Esfuerzo |
|---|---|---|---|---|
| **H-01** | CRÍTICA | Migración / versión de esquema | La migración v2→v3 no es ejecutable: 9 tablas heredadas sin evolucionar y versionado 1.3 vs 3.0 contradictorio | L |
| **H-02** | CRÍTICA | Identidad / RBAC / Emisor | El Emisor/Issuer del brief no tiene rol ni autoridad de emisión registrable; R-1 se cerró sin decisión | M |

### 4.2 Altas (20)

| ID | Severidad | Área | Título | Esfuerzo |
|---|---|---|---|---|
| **H-03** | ALTA | Semillas / KYC | Dependencia circular: `onboarding-socio` es el único emisor de KYC y a la vez exige KYC previo | S |
| **H-04** | ALTA | Estado del proyecto | Estado de Fase 1 contradictorio entre documentos y recuento de supuestos falso | S |
| **H-05** | ALTA | Marketplace / escrow | Sin reserva, idempotencia, atomicidad del NFT ni proceso de disputa: sobreventa y doble liquidación posibles | L |
| **H-06** | ALTA | Contratos de datos / claims | El fail-closed de Garantía+Fiador y la revocación de claims son eludibles desde el esquema | M |
| **H-07** | ALTA | Compliance on-chain | Los activos RWA no tienen control de cumplimiento en transferencias (solo API) | M |
| **H-08** | ALTA | Recuperación de identidad | La "doble aprobación" puede cumplirla la misma wallet: control 4-eyes no verificable | S |
| **H-09** | ALTA | RBAC / Operador | La verificación del Operador no es separable ni auditable de la aprobación del Admin | M |
| **H-10** | ALTA | Stakeholders / Fiador | El Fiador carece de consentimiento, rol de sesión y obligaciones definidas | M |
| **H-11** | ALTA | Claves / Anvil | Admin/Owner con la cuenta #0 de Anvil (clave pública) y RPC expuesto como `NEXT_PUBLIC` | M |
| **H-12** | ALTA | Infra on-chain | Anvil sin persistencia ni HA: un reinicio borra saldos, escrow y propiedad de NFT | M |
| **H-13** | ALTA | Indexer | Indexer de 10 min, singleton y sin reset/reorg/alertas: mercado y escrow obsoletos o congelados | M |
| **H-14** | ALTA | Infra / backup | Cloud SQL única sin HA/backup/PITR documentados, en región distinta a las apps y pool de 5 | M |
| **H-15** | ALTA | Privacidad / PII KYC | Una sola Service Account y un único usuario de BD acceden a todos los KYC; sin roles ni RLS | M |
| **H-16** | ALTA | Cumplimiento / ISO 25010 | Categoría de cumplimiento y derechos del titular ausente, con el supuesto regulatorio no sustentado | M |
| **H-17** | ALTA | Retención (Q10) | La retención Q10 no tiene mecanismo que la ejecute: sin cálculo de fechas, sin purga, sin fin de relación | M |
| **H-18** | ALTA | RNF fiabilidad / desempeño | Sin SLO de disponibilidad ni rendimiento en escritura/concurrencia | M |
| **H-19** | ALTA | Observabilidad | Observabilidad solo como función de UI, sin RNF de métricas, alertas, trazas ni retención de logs | M |
| **H-20** | ALTA | Trazabilidad / UX | «Soporte en los grandes pasos» y «metodología de identidad Web3» no generan RF ni criterio | S |
| **H-21** | ALTA | RBAC / Operador | El RBAC da al Operador acceso «parcial» al Panel Sistema, contra el brief y RF-V3-22 | S |
| **H-22** | ALTA | UX billetera / testabilidad | «Mensajes comprensibles» sin umbral de legibilidad: el único test comprometido mide el digest | S |

### 4.3 Medias (19)

| ID | Severidad | Área | Título | Esfuerzo |
|---|---|---|---|---|
| **H-23** | MEDIA | RBAC / modelo de roles | Modelo de roles no representable ni testeable: enum desalineado, sin asignación persistida ni cuentas por rol | M |
| **H-24** | MEDIA | Seguridad | Sin rate limiting/anti-abuso, ciclo de vida de secretos, TTL máximo de sesión ni threat model | M |
| **H-25** | MEDIA | Servicios NFT | NFT quemables al uso: decisión implícita sin estado off-chain que permita testear el quemado | M |
| **H-26** | MEDIA | BRLT / economía | BRLT sin cap, límite ni política numérica; oráculo bajo el mismo Admin y comisión DB vs FeeCollector | M |
| **H-27** | MEDIA | Tasación / Q9 | El tope «precio ≤ tasación» es opcional si `valued_brlt` es NULL y la tasación no tiene método ni procedencia | S |
| **H-28** | MEDIA | WCAG / rendimiento | WCAG y p95 sin condiciones de verificación: «rutas principales», «violaciones críticas» y métricas sin definir | S |
| **H-29** | MEDIA | UX billetera / i18n | Solo 7 plantillas, sin venta/cancelación/liberación/revocación, y solo en español pese a exigir es/en | S |
| **H-30** | MEDIA | Planificación | «~55–60 % reutilizable» y «≈14–18 semanas» sin método ni línea base verificable | S |
| **H-31** | MEDIA | Datos / recuperación | La evidencia de recuperación apunta a `document_files`, cuyo `claim_request_id` es NOT NULL | S |
| **H-32** | MEDIA | Documentación | Inventario §5.3 con nombres de tablas que no existen y omisión de tablas reales | S |
| **H-33** | MEDIA | Modelo ER | El ER dibuja relaciones sin respaldo de columna; `jurisdictions` queda sin camino de datos (Q7) | S |
| **H-34** | MEDIA | Auditoría / retención | `audit_log` mutable, sin retención ni rol auditor; `asset_documents` sin purga ni derechos del titular | M |
| **H-35** | MEDIA | Custodia de claves | Claves de plataforma sin dueño, rotación ni break-glass; multisig no mapeado a roles v3 | M |
| **H-36** | MEDIA | Ciclo de vida del Socio | Suspensión de identidad sin actor, efectos sobre listings/órdenes ni apelación | M |
| **H-37** | MEDIA | Stakeholders / actores | Actores inventados (Visitante/Fiador/Emisor) y «catálogo público» que tensiona el gate Socio | S |
| **H-38** | MEDIA | Trazabilidad | Requisitos atribuidos al brief que no contiene, cita a un §4.3 inexistente y tabla §6 incoherente | S |
| **H-39** | MEDIA | Modelo de activos | «Cargar todas las características del activo» no se convierte en requisito ni en modelo de atributos | M |
| **H-40** | MEDIA | Metadatos NFT | `metadata_uri` sin estrategia de almacenamiento: se pierde el pinning de v2 y el NFT apunta a recurso mutable/SPOF | M |
| **H-41** | MEDIA | Coste / operación | Sin modelo de coste, cuotas ni alarmas de facturación para GCP, BD, documentos y pinning | S |

### 4.4 Bajas (3)

| ID | Severidad | Área | Título | Esfuerzo |
|---|---|---|---|---|
| **H-42** | BAJA | Validación documental | La allowlist MIME configurable no puede materializarse contra el CHECK fijo pdf/png/jpeg | S |
| **H-43** | BAJA | Modelo ISSUER | El «proceso» del ISSUER se modela solo como texto libre | S |
| **H-44** | BAJA | Capacidad | «≈60 servicios/mes» se hereda como dato de diseño sin supuesto formal ni RNF de capacidad | S |

---

## 5. Hallazgos detallados por severidad

### 5.1 Críticos

---

#### H-01 — CRÍTICA · La migración v2→v3 no es ejecutable y el versionado del esquema es contradictorio

**Área:** Migración / versión de esquema · **Origen:** R6-1, R2-2 · **Esfuerzo:** L

**Detalle.** El script v3 declara con `CREATE TABLE IF NOT EXISTS` al menos **9 tablas que ya existen en v2 con otro modelo** —`claim_requests`, `document_files`, `tokens`, `sessions`, `audit_log`, `chain_events`, `indexer_state`, `schema_migrations` e `issuers`—. Sobre una BD v2 esas sentencias **no hacen nada**, por lo que no se añaden las columnas nuevas de v3 (`identity_id`, `credential_type_id`, `issuer_program_id`, `asset_kind`, `standard`, `requester_signature`, `tx_hash`, `revoked_at`, `metadata_uri`…). La primera sentencia que falla con `ON_ERROR_STOP` es `CREATE INDEX ix_claim_requests_identity` (`base_datos.sql:502`), porque la `claim_requests` v2 no tiene `identity_id`; después caerían `ix_sessions_wallet` (`:519`, v2 usa `address`) y el `INSERT` de `'3.0'` (`:841-843`, la `schema_migrations` v2 no tiene `description`). Como no hay `BEGIN/COMMIT`, la BD queda en estado intermedio. El bloque `DO` de tipos (`:92-95`) encuentra el enum v2 `session_role` (`investor`,`issuer`,`admin`; `rwa-sc/RepoTecnico/base_datos.sql:75`) y **no añade** `visitor`/`operator`. La sección §14 es solo comentario (`:846-858`) y su único `ALTER` está comentado (`:857`). Corrección al revisor: `identities` **no** existe en v2 (es nueva en v3); las colisiones son las 9 listadas. En paralelo, la propuesta fija el esquema de C0 como «`rwa` v1.3» y las migraciones «arrancan en 1.3» (`propuesta_v3.md:285,308,361`), mientras `entornos_globales.md:79` registra «v2: 1.0–1.2; v3: 3.0», el diccionario lista 1.3 como versión válida (`diccionario_datos.md:392`) y el SQL solo inserta `'3.0'`. No hay versión canónica única ni forma de comprobar el estado del esquema; los documentos afirman que la migración es aditiva (`entornos_globales.md:156`, `propuesta_v3.md:285`) y que hay 13 tablas v2 (`estado_proyecto.md:64`).

**Evidencia.** `RepoTecnico/base_datos.sql:92-95,206,220,294,490,502,519,841-843,846-858`; `RepoTecnico/propuesta_v3.md:285,308,361`; `RepoTecnico/entornos_globales.md:79,156`; `RepoTecnico/diccionario_datos.md:392`; `RepoTecnico/estado_proyecto.md:64`; esquema v2: `rwa-sc/RepoTecnico/base_datos.sql:75,119,178,203,260,289,341,351`.

**Recomendación.** Escribir una migración real y versionada: por cada tabla heredada, `ALTER TABLE / ALTER TYPE / backfill` con defaults y validación de datos; renombrar/archivar las tablas v2 antes de crear las v3 o crear las v3 con nombres no colidentes; registrar la versión solo al final y dentro de una transacción; ensayarla en CI contra un `pg_dump`/snapshot v2 (dry-run + conteos) antes de tocar Cloud SQL. Elegir **una** convención (recomendado: v3 = `3.0`, `3.1`…, sin `1.3`) y corregirla en propuesta §6.1/§7, diccionario §5.5 y entornos §5. Incluir la evolución del enum `session_role` y verificar que `credential_types` absorbe `claim_topics`.

---

#### H-02 — CRÍTICA · El Emisor/Issuer no tiene rol ni autoridad de emisión registrable; R-1 se cerró sin decisión

**Área:** Identidad / RBAC / Emisor · **Origen:** R4-1, R5-3 · **Esfuerzo:** M

**Detalle.** `requerimientos.md:19` incluye «Emisor/Issuer» entre los actores, pero la propuesta lo normaliza como plantilla de certificación (`issuer_program`) y, a la vez, atribuye la emisión a un «Admin/Issuer de onboarding/garantía/fiador/jurisdicción». El RBAC §4.7 no tiene fila ni rol `issuer`: solo el Admin emite/revoca claims (`propuesta_v3.md:192-202`), mientras RF-V3-07 exige que el claim SOCIO sea «emitido por un emisor autorizado» (`requerimientos.md:43`) y RF-V3-13 dice que lo emite el Administrador (`:49`). En datos, `claim_requests` referencia el programa (`issuer_program_id`) y guarda `issuer_signature`, pero **no registra qué emisor concreto** (wallet de `rwa.issuers`) emitió el claim (`base_datos.sql:223,230`); las semillas crean 3 `issuer_programs` con `created_by=0x000…0` y ninguna fila en `rwa.issuers` (`:736-746`). Aclaración de verificación: `rwa.issuers` **no** está huérfana (se relaciona con `issuer_programs` en `diagrama_er.md:23` y `base_datos.sql:199`); el vacío real es el vínculo emisor→claim y la autoridad de rol. El riesgo R-1 prometía normalizar en Fase 1 y validar con el sponsor (`propuesta_v3.md:339`), pero Q1–Q10 no incluyen pregunta al respecto y aun así se declara «No quedan decisiones bloqueantes» (`:384`) y «Fase 1 CERRADA» (`estado_proyecto.md:3,14,45`), con `D-V3-04` aún «Provisional» (`:34`). Si «ISSUES» aludía a actividades de comercio, cambia el modelo.

**Evidencia.** `RepoTecnico/requerimientos.md:19,43,49`; `RepoTecnico/propuesta_v3.md:52,140,192-202,339,384`; `RepoTecnico/base_datos.sql:195-203,223,230,736-746`; `RepoTecnico/diagrama_er.md:23`; `RepoTecnico/estado_proyecto.md:3,14,34,45`.

**Recomendación.** Cerrar R-1 con una decisión explícita (Q11): si el Issuer es actor, añadir rol `issuer` al RBAC con capacidades acotadas (gestionar sus ISSUER, emitir/revocar solo claims de sus programas, firmar EIP-712) y una FK de emisor en `claim_requests` y `tokens`; si es solo plantilla, eliminar «Emisor/Issuer» de la lista de actores y de la autoría de claims. Sembrar emisores reales (no `0x000…0`) y registrar la vinculación emisor→claim en diccionario/ER/SQL. Validar la normalización ISSUER/ISSUSER/ISSUES con el sponsor y dejarla como supuesto explícito o decisión asumida antes de Fase 2.

---

### 5.2 Altos

---

#### H-03 — ALTA · Dependencia circular en las semillas: `onboarding-socio` emite KYC y a la vez exige KYC previo

**Área:** Semillas / KYC · **Origen:** R2-3 · **Esfuerzo:** S

**Detalle.** La semilla de `issuer_program_credentials` hace que `onboarding-socio` emita SOCIO **y** KYC (`base_datos.sql:748-753`). La semilla de `issuer_program_requirements` para ese mismo programa exige «Tener el KYC base aprobado» como requisito `credential` obligatorio (`:780-784`). Ningún otro ISSUER sembrado emite KYC (`garantia-activos` emite GARANTIA y `fiador` emite FIADOR; `:755-768`), y el diccionario define los requisitos `credential` como «claim previo». Resultado: ningún usuario nuevo puede satisfacer el requisito para obtener su primer KYC/SOCIO; el alta de C1 queda muerta o indefinida tal como están las semillas. Es coherente con la incoherencia adicional de `propuesta_v3.md:143`, que asigna el KYC base a «Operador + Admin» y no a un ISSUER de onboarding.

**Evidencia.** `RepoTecnico/base_datos.sql:748-753,755-768,780-784`; `RepoTecnico/propuesta_v3.md:121-122,143`.

**Recomendación.** Separar el emisor del KYC base: sembrar un ISSUER dedicado a «KYC base» (operado por Operador/Admin, conforme a propuesta §4.3) y dejar que `onboarding-socio` solo emita SOCIO; o documentar formalmente la regla de evaluación que permite obtener KYC y SOCIO en la misma aprobación sin circularidad y retirar el requisito redundante de la semilla. Añadir un E2E de alta de usuario nuevo como criterio de C1.

---

#### H-04 — ALTA · Estado de Fase 1 contradictorio y recuento de supuestos falso

**Área:** Estado del proyecto · **Origen:** R2-1 · **Esfuerzo:** S

**Detalle.** `requerimientos.md` se presenta como «Fase 1 (Concepto) — en curso», «v3.0-borrador», «extracción inicial del brief» dependiente de la entrevista, y mantiene S-3 (GCP) y S-8 (regulatorio) como `[SUPUESTO]` (`:112,117`). `propuesta_v3.md:8` aún dice que «requiere cerrar la entrevista (bloques 1–3) antes de Fase 2», aunque su §10 declara «Entrevista completa (Q1–Q10). No quedan decisiones bloqueantes» (`:384`). `estado_proyecto.md` afirma «Fase 1 CERRADA» y «Ninguna bloqueante» (`:3,45`), y resume el estado de requerimientos como «supuestos S-1…S-10 resueltos» cuando la tabla llega a S-13 y dos siguen abiertos (`:20`). El conjunto no permite certificar de forma unívoca el cierre de la fase que es, precisamente, la compuerta de la auditoría.

**Evidencia.** `RepoTecnico/requerimientos.md:4,5-6,112,117`; `RepoTecnico/propuesta_v3.md:8,384`; `RepoTecnico/estado_proyecto.md:3,20,45`.

**Recomendación.** Actualizar las cabeceras de `requerimientos.md` (Fase 1 cerrada, v3.0, S-1…S-13) y de `propuesta_v3.md` (retirar «requiere cerrar la entrevista»); corregir `estado_proyecto.md:20` a «S-1…S-13» y, o bien resolver S-3/S-8, o bien declararlos supuestos **aceptados** con dueño y fecha de validación, dejando de afirmar «ninguna decisión abierta» si siguen abiertos. Crear una tabla única de estado de supuestos referenciada por los tres documentos.

---

#### H-05 — ALTA · Marketplace/escrow: sin reserva, idempotencia, atomicidad del NFT ni proceso de disputa

**Área:** Marketplace / escrow · **Origen:** R1-8, R2-4, R3-6, R4-4, R6-6, R6-7, R7-2 · **Esfuerzo:** L

**Detalle.** `ux_listings_one_active` garantiza una sola publicación activa por token (`base_datos.sql:531-533`), pero `ix_orders_listing` es no único (`:516`) y no hay índice único parcial de orden abierta por listing: dos compradores pueden crear órdenes y depositar BRLT en escrow para el mismo listing concurrentemente. `listings.quantity` existe (`:383-398`) pero no se decrementa en ningún trigger ni hay reserva; `orders` no tiene `quantity` (`:401-416`), por lo que las compras parciales de un lote ERC-1155 no se pueden representar ni validar contra el remanente. `orders.escrow_tx_hash` (`:409`) y `payments.tx_hash` (`:428`) no son `UNIQUE` (solo `chain_events` lo es): un reintento de webhook/API puede duplicar pagos o liquidar la misma tx en varias filas. `payments.payee_wallet` es texto libre sin vínculo con la wallet del vendedor (`:423`; CHECK solo de formato en `:432`). `order_status` incluye `disputed`/`refunded` (`:74`) pero `orders` no tiene `disputed_at`/`resolved_at`/`resolution`/`resolved_by`, no hay tabla/proceso de disputa ni árbitro en el RBAC, y la plantilla de compra promete «el pago queda retenido hasta que confirmes la recepción» sin plazo, auto-liberación ni cancelación (`propuesta_v3.md:183`). El escrow se describe como «escrow en BRLT» sin custodia del NFT ni intercambio atómico (`:234-237`), de modo que el vendedor podría transferir el activo tras el depósito. La propuesta reconoce R-3 (concurrencia y disputas) sin especificación funcional (`:341`) y C4 no incluye prueba de concurrencia (`:312`). Además, la propuesta afirma que el modelo «deja espacio (`orders.type`)» (`:365`) pero esa columna no existe.

**Evidencia.** `RepoTecnico/base_datos.sql:74,383-398,401-416,419-433,516,531-533`; `RepoTecnico/diccionario_datos.md:291-317`; `RepoTecnico/propuesta_v3.md:183,234-237,312,341,364-365`.

**Recomendación.** Reserva atómica: índice único parcial de orden abierta por listing (o tabla de reservas) con decremento transaccional de `quantity`; `quantity`/`remaining_quantity` en `orders`/`listings`; `UNIQUE` en `orders.escrow_tx_hash` y `payments.tx_hash`; triggers que validen precio/fee contra `listings` y `platform_fees` e impidan `payee_wallet` distinto del vendedor; máquina de estados del escrow con plazos, auto-confirmación, cancelación y disputa con árbitro y campos de resolución; atomicidad NFT+BRLT (depósito del activo o `approve`+`transferFrom` en la liquidación); `idempotency keys`; tests de concurrencia, doble venta, reembolso y transición inválida en C4, y auditoría externa como gate.

---

#### H-06 — ALTA · El fail-closed de Garantía+Fiador y la revocación de claims son eludibles

**Área:** Contratos de datos / claims · **Origen:** R7-3 · **Esfuerzo:** M

**Detalle.** El trigger `enforce_token_guarantees` solo cuenta filas `token_guarantees` con `verified=true` (`base_datos.sql:567-592,576-583`); `claim_request_id` es NULL-able (`:352`) y no se exige que el claim esté `approved` ni emitido por un emisor de confianza, por lo que dos `INSERT` (garantía y fiador) con `verified=true` habilitan el paso a `minted`/`listed`; el fiador puede ser la misma identidad/creador del activo (CHECK solo exige `identity_id` no nulo; `:347-359`). En `claim_requests`, el paso a `approved` no impide autoaprobación (`reviewed_by_wallet` puede igualar a `requester_wallet`), `requester_signature` es NULL-able y `issuer_signature` no se vincula a `issuers.address` (`:239-246`). La revocación solo cambia el status: no hay trigger que ponga `verified=false` en `token_guarantees` ni que saque el token de `listed`/`sold_out`, y el enum no tiene máquina de estados (una fila `revoked` puede volver a `approved`); el índice parcial solo limita solicitudes `pending`, permitiendo varios claims aprobados del mismo tipo por identidad (`:526-528`).

**Evidencia.** `RepoTecnico/base_datos.sql:239-246,243-245,347-360,352,526-528,567-592`; `RepoTecnico/propuesta_v3.md:160-161,267,269`.

**Recomendación.** Hacer `claim_request_id NOT NULL` en `token_guarantees` y exigir claim `approved` no revocado (FK compuesta o trigger), validando `issuer_signature` contra `issuers.address`; trigger en `claim_requests` que al revocar invalide garantías y bloquee el token; máquina de estados que prohíba `revoked→approved` y la autoaprobación (`reviewed_by <> requester` y rol operador/admin); exigir independencia entre fiador, emisor y creador; verificación del lado del contrato (`isVerified` real, no solo filas de BD) e índice único parcial de claim aprobado por `(identity_id, credential_type_id)`; tests negativos en C3.

---

#### H-07 — ALTA · Los activos RWA no tienen control de cumplimiento en transferencias

**Área:** Compliance on-chain · **Origen:** R7-4 · **Esfuerzo:** M

**Detalle.** La invariante declara que «nadie sin claim SOCIO opera en el mercado», validado en API y en el contrato de marketplace (`propuesta_v3.md:266`), pero los contratos de activo se describen como ERC721Burnable/ERC1155Supply + `AccessControl`, sin hook `_update`/`beforeTokenTransfer` ni referencia a `IdentityRegistry`/`ComplianceAggregator` (`:229-232`). `token_required_claims` y `token_compliance_modules` existen solo off-chain (`base_datos.sql:331-344`) y ningún trigger/vista los aplica; tras una venta, el NFT puede transferirse a una wallet sin KYC ni compliance y operar fuera del Metaplace, y el filtro de marketplace no protege transferencias secundarias ni listados por otras vías. La deuda v2 RF-011/012 se declara cerrada «como intención» (`estado_proyecto.md:35`) sin diseño de enforcement por activo, y sigue como brecha abierta (`:65`).

**Evidencia.** `RepoTecnico/propuesta_v3.md:229-232,266`; `RepoTecnico/base_datos.sql:331-344`; `RepoTecnico/estado_proyecto.md:35,65`.

**Recomendación.** Especificar hooks `_update`/`beforeTokenTransfer` en `AssetNFT721`/`AssetERC1155` que consulten `IdentityRegistry` (`isVerified` del receptor) y los módulos de compliance por token; aplicar `token_required_claims` on-chain en mint/transfer/listing; definir qué claims exige cada tipo de activo (SOCIO/KYC/JURISDICCION) y el comportamiento de activos ya acuñados; tests adversariales de transferencia a wallet no verificada y de listado por wallet sin Socio.

---

#### H-08 — ALTA · La doble aprobación de recuperación de identidad se satisface con un único aprobador

**Área:** Recuperación de identidad · **Origen:** R1-2, R4-5, R7-1 · **Esfuerzo:** S

**Detalle.** El CHECK `recovery_double_approval` solo exige que `approved_by_wallet` y `second_approval_wallet` sean NO NULL cuando el estado es `approved`/`completed` (`base_datos.sql:283-286`); **no** exige que sean wallets distintas, ni que no sean el solicitante, ni roles distintos ni timestamps por aprobación. `evidence_document_id` es NULL-able (`:273`), `recovery_distinct_wallets` solo exige `old_wallet <> new_wallet` (`:282`) y no hay trigger ni máquina de estados. Un único Admin puede rellenar ambas columnas con su misma wallet y cumplir el CHECK, por lo que ni el criterio de C5 («recuperación con doble aprobación auditada», `propuesta_v3.md:313`) ni el invariante de Q5 (`:372`) son verificables. `audit_log` puede registrar actores (`diccionario_datos.md:355-357`), pero no impide el bypass.

**Evidencia.** `RepoTecnico/base_datos.sql:266-287`; `RepoTecnico/diccionario_datos.md:196-197,203`; `RepoTecnico/propuesta_v3.md:271,313,372`; `RepoTecnico/requerimientos.md:116`.

**Recomendación.** Añadir `CHECK (second_approval_wallet <> approved_by_wallet)` y trigger que valide dos sesiones admin activas y distintas, que aprobador/solicitante no coincidan y que `new_wallet` no exista ya en `identities.wallet_address`; hacer `evidence_document_id NOT NULL` para estados `approved`/`completed`; máquina de estados que impida retroceder; acciones `recovery.approve.first/second` en `audit_log`; periodo de enfriamiento con aviso a la wallet anterior; y test explícito del bypass (mismo aprobador ⇒ rechazo).

---

#### H-09 — ALTA · La verificación del Operador no es separable ni auditable de la aprobación del Admin

**Área:** RBAC / Operador · **Origen:** R4-3 · **Esfuerzo:** M

**Detalle.** El flujo maestro y RF-V3-13 separan dos funciones: el Operador verifica documentos y el Administrador aprueba/emite la firma (`propuesta_v3.md:121-122`; `requerimientos.md:49`). Sin embargo, `claim_requests` solo tiene un par `reviewed_by_wallet`/`reviewed_at` y el diccionario lo describe como campo único para «Operador verifica, Admin aprueba» (`diccionario_datos.md:155,166`; `base_datos.sql:228-229`); `claim_status` no tiene estado intermedio (`base_datos.sql:62`). No se puede registrar quién verificó, cuándo, ni distinguir la verificación documental de la aprobación, por lo que la segregación de funciones que el brief exige para WEB-ISSUSER no queda trazada y el Operador no produce un resultado propio (el control es testeable vía `audit_log`, pero el modelo no lo soporta).

**Evidencia.** `RepoTecnico/propuesta_v3.md:121-122,197`; `RepoTecnico/requerimientos.md:49,68`; `RepoTecnico/diccionario_datos.md:155,166,355-357`; `RepoTecnico/base_datos.sql:62,228-229`.

**Recomendación.** Separar en el esquema `verified_by_wallet`/`verified_at` (Operador) de `approved_by_wallet`/`approved_at` e `issuer_signature` (Admin); añadir estado `documents_verified`/`in_review` al enum y una capacidad RBAC específica; incluir una consulta/test de auditoría que demuestre la segregación y que el Operador no puede aprobar/emitir.

---

#### H-10 — ALTA · El Fiador carece de consentimiento, rol y obligaciones definidas

**Área:** Stakeholders / Fiador · **Origen:** R4-2 · **Esfuerzo:** M

**Detalle.** El Fiador es precondición de tokenización (el brief exige certificado de Garantía y de Fiador; `BRIEF_BARLOBLOKCHAIN_v3.md:14`) y figura como actor y columna del RBAC, pero no existe en el enum `session_role` (`base_datos.sql:94`); el RBAC solo le concede comprar/vender/intercambiar y solicitar claims, sin capacidad de aceptar, limitar o revocar una garantía (`propuesta_v3.md:192,195-196`). En datos, `token_guarantees` permite crear la fila «fiador» apuntando a una identity sin consentimiento (`identity_id` nullable salvo el CHECK de tipo), con `claim_request_id` opcional y un `verified` booleano sin campo de quién valida (`base_datos.sql:347-359`; `diccionario_datos.md:261-263`); no hay estado de garantía (ofrecida/aceptada/revocada/vencida) ni deberes, alcance o responsabilidad del fiador.

**Evidencia.** `RepoTecnico/BRIEF_BARLOBLOKCHAIN_v3.md:14`; `RepoTecnico/requerimientos.md:19,55`; `RepoTecnico/propuesta_v3.md:192,195-196`; `RepoTecnico/base_datos.sql:94,347-359`; `RepoTecnico/diccionario_datos.md:261-263`.

**Recomendación.** Modelar al Fiador como parte con consentimiento: solicitud/aceptación firmada (claim FIADOR + aceptación del respaldo), rol o capacidad explícita de otorgar/limitar/revocar, estados de la garantía con auditoría y reglas de responsabilidad/alcance; alinear el enum de sesión y el RBAC, y añadir un E2E de garantía ofrecida→aceptada→revocada.

---

#### H-11 — ALTA · Admin/Owner con la cuenta #0 de Anvil (clave pública) en un RPC `NEXT_PUBLIC`

**Área:** Claves / Anvil · **Origen:** R6-2, R7-6 · **Esfuerzo:** M

**Detalle.** `entornos_globales.md:70` asigna Admin/Owner a `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`, cuenta #0 del mnemónico por defecto de Anvil/Hardhat, cuya clave privada es pública y conocida; el documento las titula «claves públicas por defecto» (`:69`). La misma dirección fue el deployer del artefacto v2 (`rwa-sc/sc/deployments/31337-20261023T185622Z.json:23`). En v3 el Admin concentra crear/editar ISSUER, emitir/revocar claims, tokenizar, aprobar recuperación y, vía `BarloToken`/`FeeCollector`, acuñar/pausar BRLT y recaudar comisiones (`propuesta_v3.md:169,198-201`). El RPC se publica como `NEXT_PUBLIC_RPC_URL` (`entornos_globales.md:93`), consumible por el navegador desde una URL de Cloud Run, con el nodo declarado de desarrollo (`:46,150`). Si el entorno de demo/piloto usa esa cuenta y el RPC es alcanzable, cualquier tercero podría firmar transacciones de Admin.

**Evidencia.** `RepoTecnico/entornos_globales.md:46,69-73,93,150`; `RepoTecnico/propuesta_v3.md:169,198-201,308,313`; `rwa-sc/sc/deployments/31337-20261023T185622Z.json:23`.

**Recomendación.** Generar claves dedicadas por rol (owner/minters/issuers/operador) fuera de las cuentas por defecto de Anvil y cargarlas desde Secret Manager; restringir el ingress del RPC (IAP/red privada o gateway autenticado); verificar on-chain los roles tras cada despliegue; gate de CI que falle si una dirección de rol coincide con cuentas conocidas de Anvil; no reutilizar el entorno en pilotos con usuarios reales sin rotación previa.

---

#### H-12 — ALTA · Anvil sin persistencia ni HA: un reinicio borra saldos, escrow y propiedad de NFT

**Área:** Infra on-chain · **Origen:** R6-3 · **Esfuerzo:** M

**Detalle.** Anvil es un único servicio Cloud Run de desarrollo y el documento acepta que su estado «puede reiniciarse» (`entornos_globales.md:150`). La mitigación declarada (artefacto de despliegue reejecutable + verificación en CI) solo reconstruye contratos vacíos: no preserva saldos BRLT, órdenes en escrow, propiedad de NFTs ni historial de transacciones. La BD off-chain seguiría apuntando a contratos/tx de una cadena muerta y `chain_events` quedaría huérfano. El riesgo R-7 se clasifica Media/Medio (`propuesta_v3.md:345`) pese a que el marketplace/escrow dependen de esa cadena como fuente de verdad del valor (`:308`). No hay failover ni segundo RPC documentado; al caer el nodo las escrituras on-chain se detienen (RNF-V3-06 solo cubre el 503 tipado; `requerimientos.md:82`).

**Evidencia.** `RepoTecnico/entornos_globales.md:46,62,150`; `RepoTecnico/propuesta_v3.md:308,345`; `RepoTecnico/requerimientos.md:82`.

**Recomendación.** Definir persistencia del estado de Anvil (volumen/estado respaldado) o un runbook de reset con reconciliación off-chain: invalidar órdenes/pagos abiertos, reconstruir saldos demo desde semillas y verificar hashes de génesis. Añadir `chainId` + hash de génesis al artefacto y a `indexer_state`, snapshot periódico y un segundo endpoint RPC de respaldo; reclasificar R-7 a Alto/Impacto Alto.

---

#### H-13 — ALTA · Indexer de 10 minutos, singleton y sin manejo de reset/reorg ni alertas

**Área:** Indexer · **Origen:** R6-4 · **Esfuerzo:** M

**Detalle.** El indexer corre como Cloud Run Job cada 10 minutos y guarda un único `last_block` (`entornos_globales.md:52-53`; `requerimientos.md:101`); los pagos/escrow que dependen de eventos on-chain pueden mostrarse hasta 10 minutos desactualizados y confirmarse una compra sobre estado obsoleto. La v3 de `chain_events` solo tiene `UNIQUE(tx_hash, log_index)` y no guarda `block_hash`, `chain_id`, finalidad ni marca `removed` (`base_datos.sql:468-478`) —regresión frente a la v2, cuyo `chain_events` sí tenía `chain_id`, `block_hash` y `removed` (`rwa-sc/RepoTecnico/base_datos.sql:351-361`)—, e `indexer_state` pierde el `indexer_id`/`chain_id` que tenía v2 (`:341`). Tras un reset de Anvil, `last_block` quedaría por delante del nuevo head y el indexer no procesaría nada, sin alerta (la brecha «alertas del indexer» ya estaba abierta en v2; `estado_proyecto.md:65`). No se define patrón outbox/idempotencia ni job de reconciliación entre los `tx_hash` escritos por la app y los eventos indexados.

**Evidencia.** `RepoTecnico/entornos_globales.md:52-53`; `RepoTecnico/requerimientos.md:101`; `RepoTecnico/base_datos.sql:468-478,481-487`; `RepoTecnico/estado_proyecto.md:65`; `RepoTecnico/propuesta_v3.md:133`; esquema v2: `rwa-sc/RepoTecnico/base_datos.sql:341,351-361`.

**Recomendación.** Añadir `block_hash`/`parent_hash`/`chain_id`/finalidad por evento y detección de cambio de cadena/génesis (rebuild o bloqueo explícito), alertas de lag/fallo y health del job; bajar latencia (event-driven o 1-2 min) para carrito/escrow; definir idempotencia y job de reconciliación de pagos pendientes con antigüedad > N, con métricas en el panel Sistema.

---

#### H-14 — ALTA · Cloud SQL única sin HA/backup/PITR documentados, en región distinta a las apps y pool de 5

**Área:** Infra / backup · **Origen:** R6-5, R3-5 · **Esfuerzo:** M

**Detalle.** La BD canónica es una sola instancia Cloud SQL `truekeate-main:southamerica-east1:truekeate-db-dev` (`requerimientos.md:98`), mientras las apps/Cloud Run se despliegan en `europe-west1` (`:100`): cada consulta paga un RTT intercontinental y RNF-V3-05 exige p95 < 800 ms (`:81`) con varias consultas por vista. No consta en los documentos HA, réplica de lectura, backup automático ni PITR; el único respaldo citado es el ZIP de la v2 (`entornos_globales.md:154`), no un plan de backup/restauración de la BD operativa. No hay RPO/RTO, ni prueba de restauración, ni copia/rotación de `KYC_ENCRYPTION_KEY` (`:50`): perder la clave haría irrecuperables los documentos aunque exista backup de la BD. El pool es `PG_POOL_MAX=5` por instancia de Cloud Run (`:101`), sin pgbouncer ni límite de max-instances documentado: con varias réplicas de apps+shell+indexer puede agotarse el límite de conexiones. El RPC es también un único endpoint sin failover (`:93`).

**Evidencia.** `RepoTecnico/requerimientos.md:81,98,100`; `RepoTecnico/entornos_globales.md:41-44,50,93,101,154`; `RepoTecnico/base_datos.sql:849`.

**Recomendación.** Alinear región de BD y apps (o medir la latencia real y ajustar el RNF), fijar `max-instances` y usar connection pooling (pgbouncer/Cloud SQL connector con límite global), documentar y probar backups/PITR con simulacro de restauración, activar copia versionada de `KYC_ENCRYPTION_KEY` con plan de rotación, y definir un RPC de respaldo con failover. Añadir RNF de recuperación con **RPO ≤ 15 min y RTO ≤ 4 h** y un ensayo de restauración antes de C0.

---

#### H-15 — ALTA · Una sola Service Account y un único usuario de BD con acceso a todos los KYC

**Área:** Privacidad / PII KYC · **Origen:** R7-5 · **Esfuerzo:** M

**Detalle.** Las tres apps y el indexer comparten el mismo `DATABASE_URL` y la SA `rwa-web-run`, que tiene `secretAccessor` sobre `DATABASE_URL`, `SIWE_SESSION_SECRET` y `KYC_ENCRYPTION_KEY` (`entornos_globales.md:43,47,50`); el esquema no define roles PostgreSQL, RLS ni `GRANT` (0 coincidencias en 861 líneas de `base_datos.sql`). Cualquier SSRF/RCE/dependencia comprometida en cualquiera de las apps —o en el indexer, que no necesita la clave KYC— permite descifrar todos los documentos KYC y leer PII de las 25 tablas. No se documenta rotación/versionado de `KYC_ENCRYPTION_KEY` ni claves por propósito; la separación «solo titular/operador/admin» queda a nivel de código (`propuesta_v3.md:270`), sin defensa en profundidad. La afirmación de «mínimos privilegios» (`entornos_globales.md:146`) es relativa: la SA accede a los 3 secretos y a la BD completa.

**Evidencia.** `RepoTecnico/entornos_globales.md:43,47,50,146`; `RepoTecnico/base_datos.sql` (sin `CREATE ROLE`/`ROW LEVEL SECURITY`/`GRANT`); `RepoTecnico/propuesta_v3.md:270,272`.

**Recomendación.** Separar Service Accounts y secretos por servicio (identity/issuer/token/indexer), de modo que solo identity/issuer accedan a `KYC_ENCRYPTION_KEY` y el indexer a ningún secreto KYC; envelope encryption con KMS y rotación/versionado (versionar en `encryption_meta`); roles PostgreSQL de mínimo privilegio y RLS por tabla; documentar la matriz de acceso a datos y probar que un servicio no puede leer lo que no le corresponde.

---

#### H-16 — ALTA · Cumplimiento y derechos del titular ausentes del catálogo RNF, con el supuesto regulatorio no sustentado

**Área:** Cumplimiento / ISO 25010 · **Origen:** R3-1, R7-7 · **Esfuerzo:** M

**Detalle.** RNF-V3-01…11 cubre seguridad, privacidad limitada a cifrado, auditabilidad, desempeño, fiabilidad, portabilidad, mantenibilidad, extensibilidad, i18n y operación, pero **no incluye cumplimiento legal ni protección de datos del titular**: no hay base legal/consentimiento, DPIA, derechos de acceso/rectificación/supresión/portabilidad, notificación de brechas, inventario de encargados (GCP/Cloud SQL) ni evaluación por jurisdicción, pese a procesar PII sensible (KYC con documento de identidad y domicilio) en 7 países. La única mención es una exclusión de alcance financiero (AML/PSD2/MiCA) «a confirmar» (`requerimientos.md:21-22`), que no cubre protección de datos. El supuesto S-8 asume «sin obligaciones regulatorias» (`:117`) mientras el diseño usa BRLT como medio de pago, cobra 5 % de comisión, retiene BRLT en escrow, tokeniza activos reales y emite certificados: según la jurisdicción del piloto LatAm (VE, CO, PA, MX, CL, PE, AR) puede encuadrar en servicios de pago/e-money, VASP, valores o consumo. `jurisdictions` solo tiene un flag `enabled` sin reglas por país (`base_datos.sql:104-111`).

**Evidencia.** `RepoTecnico/requerimientos.md:21-22,44,77-87,117`; `RepoTecnico/estado_proyecto.md:14,45`; `RepoTecnico/propuesta_v3.md:342,355,372`; `RepoTecnico/base_datos.sql:104-111`.

**Recomendación.** Añadir **RNF-V3-12 (cumplimiento y protección de datos)** con criterios medibles: base legal y consentimiento registrados por identidad, procedimiento de derechos del titular con SLA (p. ej. respuesta ≤ 30 días y trazada en `audit_log`), DPIA firmada antes de C1, inventario de encargados y retención probada por categoría; encargar opinión legal por jurisdicción del piloto y clasificar formalmente BRLT, el escrow, las comisiones y las credenciales; si hay valor real, programa AML/CFT (KYC/KYB, screening de sanciones/PEP, monitoreo, travel rule), geo-bloqueo y feature flags por país; tratar esta validación como gate bloqueante de C4/piloto y no como supuesto.

---

#### H-17 — ALTA · La retención Q10 no tiene mecanismo que la ejecute

**Área:** Retención (Q10) · **Origen:** R3-2 · **Esfuerzo:** M

**Detalle.** Q10 (30 días tras rechazo / 12 meses tras fin de relación) figura como decisión aprobada y auditada (`propuesta_v3.md:383`), pero en los artefactos: (a) ningún trigger/función calcula `retention_delete_at` —los triggers existentes son `updated_at`, fail-closed de garantías y tope de precio, y `document_files` no está en la lista de `updated_at` (`base_datos.sql:540-565`)—; (b) `v_documents_due_deletion` solo hace `SELECT`, no borra (`:682-687`); (c) el único Cloud Scheduler documentado es el del indexer (`entornos_globales.md:53`), no hay job de purga; (d) no hay modelo de fin de relación en `identities` (`base_datos.sql:206-217`) ni campo específico de rechazo que dispare el plazo (el estado `rejected` y `reviewed_at` podrían servir de base, pero no hay lógica que fije la fecha). La retención, por tanto, no es verificable ni auditable como Q10 exige.

**Evidencia.** `RepoTecnico/base_datos.sql:206-217,258,540-565,682-687`; `RepoTecnico/entornos_globales.md:53,85-86`; `RepoTecnico/diccionario_datos.md:417`; `RepoTecnico/propuesta_v3.md:383`.

**Recomendación.** Definir en Fase 2/Fase 3: job programado de purga (Cloud Scheduler + función/endpoint que borre y escriba en `audit_log`), lógica que fije `retention_delete_at` al pasar a `rejected` y al cierre de relación, y campo `ended_at` (o equivalente) en `identities`; añadir prueba automatizada de que un documento vencido deja de servirse y se elimina (criterio medible: 0 filas vencidas servidas por API y 100 % de purgas registradas en `audit_log`).

---

#### H-18 — ALTA · Sin objetivos de disponibilidad (SLO) ni de rendimiento en escritura/concurrencia

**Área:** RNF fiabilidad / desempeño · **Origen:** R3-3 · **Esfuerzo:** M

**Detalle.** RNF-V3-06 solo cubre tolerancia a fallos (503 tipado, indexer reanudable) y RNF-V3-05 solo mide lecturas (First Load JS, p95 de lectura, health) (`requerimientos.md:81-82`). No hay disponibilidad objetivo ni error budget, ni p95 de escritura (tokenización, solicitud de claim, compra, depósito en escrow), ni throughput/concurrencia para el marketplace, aunque el propio diseño reconoce el riesgo de concurrencia y disputas (R-3; `propuesta_v3.md:341`). Sin criterio medible no se puede aceptar C4 ni operar el panel Sistema con garantías; el criterio de aceptación de C4 no incluye prueba de concurrencia/carga (`:312`).

**Evidencia.** `RepoTecnico/requerimientos.md:81-82`; `RepoTecnico/propuesta_v3.md:312,341`.

**Recomendación.** Añadir RNF: disponibilidad ≥ 99,5 % mensual con error budget y alerta de consumo; p95 de escritura < 1,5 s; prueba de carga a 2× del pico esperado (≈60 servicios/mes concentrados + N compras concurrentes) con 0 dobles ventas y 0 dobles listings; gate obligatorio en C4.

---

#### H-19 — ALTA · La observabilidad existe solo como función de UI, sin RNF de métricas, alertas ni trazas

**Área:** Observabilidad · **Origen:** R3-4 · **Esfuerzo:** M

**Detalle.** RF-V3-23 pide un panel que «monitoreará» la plataforma (`requerimientos.md:69`), pero no define señales, umbrales, destinatario de alertas ni retención; el catálogo RNF no tiene categoría de observabilidad (`:77-87`). No se especifican SLIs/métricas RED o USE, trazas correlacionadas (`request_id` existe en `audit_log` pero no hay RNF de propagación), política de logs (solo `LOG_LEVEL`, sin retención) ni cierre de la brecha v2 «alertas del indexer» (`estado_proyecto.md:65`). La propuesta menciona «panel + logs estructurados + métricas» como componente (`propuesta_v3.md:220`), sin requisito verificable ni criterio de aceptación del panel en C5.

**Evidencia.** `RepoTecnico/requerimientos.md:69,77-87`; `RepoTecnico/entornos_globales.md:102`; `RepoTecnico/estado_proyecto.md:65`; `RepoTecnico/propuesta_v3.md:220`.

**Recomendación.** Añadir **RNF-V3-13**: 100 % de rutas instrumentadas con `request_id`/traza, dashboards de latencia/errores/saturación, alertas con umbral y dueño (indexer lag > 2 bloques, 5xx > 1 %, p95 fuera de SLO), retención de logs ≥ 90 días; y criterio de aceptación explícito del panel Sistema en C5.

---

#### H-20 — ALTA · «Soporte en los grandes pasos» y «metodología de identidad Web3» no generan RF ni criterio

**Área:** Trazabilidad / UX · **Origen:** R1-6, R4-10, R5-1 · **Esfuerzo:** S

**Detalle.** El `[OBJETIVO]` del brief pide una metodología para crear/certificar identidad Web3 y 3 instancias «proporcionando soporte en los grandes pasos» (`BRIEF_BARLOBLOKCHAIN_v3.md:2`). La propuesta lo interpreta solo en prosa (`propuesta_v3.md:41,54` «soporte guiado en los pasos grandes»), pero ningún RF recoge guía/asistencia ni metodología: RF-V3-01 cubre shell, identidad visual y SSO (`requerimientos.md:32`); la tabla de trazabilidad §6 asigna a `[OBJETIVO]` solo RF-V3-01/02/19/20 (`:130-139`); y los ciclos C0–C6 no incluyen entregable de guiado/metodología (`propuesta_v3.md:306-316`). Tampoco se define qué son los «grandes pasos» (¿alta? ¿solicitud de claim? ¿tokenización? ¿compra?), qué forma tiene el soporte (wizard, tooltip, ayuda contextual, estados de progreso) ni cómo se mide que existe. El brief no define un actor humano de soporte, por lo que el hueco es de requisito y criterio, no de organigrama.

**Evidencia.** `RepoTecnico/BRIEF_BARLOBLOKCHAIN_v3.md:2`; `RepoTecnico/propuesta_v3.md:41,54,306-316`; `RepoTecnico/requerimientos.md:32-36,130-139`.

**Recomendación.** Crear RF específicos para (a) asistencia guiada por suite (wizard/checklist con criterios de aceptación) y (b) metodología de identidad Web3 publicada; asignarlos a C1/C2/C3 y a la tabla §6. Si el cliente decide excluirlos de v3.0, registrar la renuncia por escrito como decisión de alcance. Convertir además el soporte en requisito explícito (RF de asistencia y canal de escalado) o declararlo fuera de alcance.

---

#### H-21 — ALTA · El RBAC da al Operador acceso «parcial» al Panel Sistema, contra el brief y RF-V3-22

**Área:** RBAC / Operador · **Origen:** R5-2 · **Esfuerzo:** S

**Detalle.** El brief restringe WEB-ISSUSER a Administrador y Operador, y define al Operador como «solo tiene acceso a la verificación de documentos» (`BRIEF_BARLOBLOKCHAIN_v3.md:24`). RF-V3-22 lo reproduce correctamente (`requerimientos.md:68`), pero la matriz RBAC de la propuesta asigna «parcial» al Operador en la fila «Panel Sistema» (`propuesta_v3.md:202`), introduciendo un permiso no pedido y contradiciendo el propio RF. Impacto de seguridad/visibilidad de plataforma en el único rol restringido; la matriz es el instrumento que se implementará en C5.

**Evidencia.** `RepoTecnico/BRIEF_BARLOBLOKCHAIN_v3.md:24`; `RepoTecnico/propuesta_v3.md:202`; `RepoTecnico/requerimientos.md:68`.

**Recomendación.** Poner ❌ al Operador en «Panel Sistema» en §4.7 y alinear la matriz con RF-V3-22; si se desea darle monitoreo, abrirlo como decisión explícita del sponsor documentando la desviación, y añadir un test de autorización negativa.

---

#### H-22 — ALTA · «Mensajes comprensibles» sin umbral de legibilidad: el único test comprometido mide el digest

**Área:** UX billetera / testabilidad · **Origen:** R1-1 · **Esfuerzo:** S

**Detalle.** RF-V3-21 exige mensajes «comprensibles por un usuario común» con «lenguaje coloquial» (`requerimientos.md:67`) y RNF-V3-04 lo operativiza como «test de legibilidad (p. ej. longitud y ausencia de jerga técnica)» (`:80`): no hay longitud máxima (caracteres/palabras), ni índice de legibilidad objetivo, ni glosario cerrado de jerga prohibida, y el «p. ej.» deja los ejemplos como ilustración, no como criterio. El test que la propuesta compromete en §4.6 verifica que el texto mostrado coincide con el digest firmado (integridad), no que sea legible (`propuesta_v3.md:188`); el gate de CI `check-wallet-messages` (`:289`) solo se enuncia, sin especificación funcional; la tabla `wallet_messages` no impone longitud ni contenido más allá de `NOT NULL` y `version>0` (`base_datos.sql:139-151`). Matiz verificado: el catálogo de procesos **sí** está cerrado en 7 `process_key` (`diccionario_datos.md:68`) y ya sembrado (`base_datos.sql:815-836`), por lo que la parte del hallazgo original que negaba el catálogo es incorrecta y se elimina; el defecto superviviente es la ausencia de criterio numérico y de test que lo mida, lo que deja el criterio de C5 «100 % de procesos con mensaje legible» no verificable.

**Evidencia.** `RepoTecnico/requerimientos.md:67,80`; `RepoTecnico/propuesta_v3.md:188,289,313`; `RepoTecnico/base_datos.sql:139-151,815-836`; `RepoTecnico/diccionario_datos.md:68`.

**Recomendación.** Fijar RNF-V3-04 en términos numéricos y testeables: longitud máxima (p. ej. ≤ 200 caracteres en `template` y ≤ 40 en `title`), índice de legibilidad objetivo (p. ej. Flesch-Szigriszt ≥ 55) o lista cerrada de términos técnicos prohibidos; especificar `check-wallet-messages` como test que falla si se supera el límite o aparece jerga prohibida, además del test digest↔texto; añadir el criterio numérico a la aceptación de C5.

---

### 5.3 Medios

---

#### H-23 — MEDIA · Modelo de roles no representable ni testeable: enum desalineado, sin asignación persistida ni cuentas por rol

**Área:** RBAC / modelo de roles · **Origen:** R2-5, R3-10, R4-9, R7-8 · **Esfuerzo:** M

**Detalle.** El conjunto de principales del RBAC (Visitante, Usuario/Socio, Fiador, Operador, Admin; `propuesta_v3.md:192`) no coincide con `session_role` (`visitor, investor, issuer, operator, admin`; `base_datos.sql:94`): falta Fiador, sobra `issuer` sin uso en el RBAC y `investor` no corresponde a Usuario/Socio. `sessions.role` es una columna con DEFAULT `'investor'` (`:444`) y `sessions.wallet_address` no tiene FK a `identities`; no hay tabla entre las 25 que asocie una wallet a un rol administrativo, lo revoque, lo caduque o registre quién lo concedió. Además, los entornos de desarrollo solo documentan cuentas Admin/Owner, User 1 y User 2 (`entornos_globales.md:69-73`), sin cuentas para Operador, Fiador ni Issuer, por lo que la segregación de funciones y los flujos de certificación no pueden ejercitarse en C1–C5. La emisión del KYC se atribuye a «Operador + Admin» (`propuesta_v3.md:143`) mientras RF-V3-22 reserva emitir/revocar claims exclusivamente al Admin (`requerimientos.md:68`) y §4.7 solo marca ✅ al Admin (`:199`).

**Evidencia.** `RepoTecnico/propuesta_v3.md:84,143,192-202`; `RepoTecnico/requerimientos.md:68`; `RepoTecnico/diccionario_datos.md:344`; `RepoTecnico/base_datos.sql:94,440-451`; `RepoTecnico/entornos_globales.md:69-73`.

**Recomendación.** Definir el rol de sesión canónico en un único lugar (p. ej. `visitor|user|operator|admin`, con Socio/Fiador en `credential_types`) y actualizar `CREATE TYPE rwa.session_role`, diccionario §5.1 y ER; crear `role_assignments` (wallet, rol, `granted_by`, `granted_at`, `expires_at`, `revoked_at`) con historial append-only; corregir la fila KYC a «Admin (emite) + Operador (verifica)»; definir cuentas/seed por rol y una matriz de pruebas de autorización positiva y negativa que cubra Operador y Fiador en C2/C5.

---

#### H-24 — MEDIA · Seguridad sin rate limiting/anti-abuso, ciclo de vida de secretos, TTL de sesión ni threat model

**Área:** Seguridad · **Origen:** R3-10 · **Esfuerzo:** M

**Detalle.** RNF-V3-01/02 cubren authn/authz por recurso y cifrado de documentos, pero: (a) no hay requisito de rate limiting/anti-abuso en mutaciones (compras, claim-requests, reutilización de nonce SIWE); (b) no hay rotación/versionado de `SIWE_SESSION_SECRET` ni `KYC_ENCRYPTION_KEY` —`encryption_meta` alude a «versión de clave» sin plan (`base_datos.sql:257`)—, ni TTL máximo de sesión (solo `expires_at > issued_at`; `:440-451`); (c) no se exige threat model ni auditoría externa de contratos, brecha v2 todavía abierta (`estado_proyecto.md:65`); (d) no se especifica cómo se obtiene el rol admin/operator más allá de `sessions.role` (ver H-23).

**Evidencia.** `RepoTecnico/requerimientos.md:77-78`; `RepoTecnico/diccionario_datos.md:344`; `RepoTecnico/base_datos.sql:257,440-451`; `RepoTecnico/entornos_globales.md:50,99`; `RepoTecnico/estado_proyecto.md:65`.

**Recomendación.** Añadir RNF y modelo: rate limit por IP/wallet (p. ej. ≤ 10 req/min en mutaciones), nonce SIWE de un solo uso invalidado tras uso, TTL de sesión ≤ 24 h con renovación, rotación anual/de incidente de claves con re-cifrado versionado en `encryption_meta`, threat model STRIDE y auditoría externa (Slither + revisión) como gate antes de exponer C4.

---

#### H-25 — MEDIA · NFT que se queman al usarse: decisión implícita y sin estado off-chain que permita testearlo

**Área:** Servicios NFT · **Origen:** R1-3, R5-10 · **Esfuerzo:** M

**Detalle.** El brief lo plantea como posibilidad («evalúa la posibilidad que sean NFT que se queman al uso»; `BRIEF_BARLOBLOKCHAIN_v3.md:27`), `requerimientos.md` lo mantiene como no-requisito («se valorará»; `:57`), pero la propuesta lo asume como diseño decidido (ERC-721 burnable, «Se quema al usarse»; `propuesta_v3.md:157`) y lo exige en C3 (`:311`), y siembra la plantilla `service.consume` («su certificado digital se destruye»; `base_datos.sql:830-831`). Ninguna decisión Q1–Q10 resuelve si es obligatorio, opcional o backlog v3.1. Además el modelo off-chain no lo soporta: `asset_status` no tiene estado de consumo/quemado (`base_datos.sql:58`; `diccionario_datos.md:230`), `tokens` no registra consumo por servicio y no hay tabla/evento de uso; no hay forma de testear E2E «el NFT se quema al usarse» ni de conciliar el burn on-chain con el estado off-chain.

**Evidencia.** `RepoTecnico/BRIEF_BARLOBLOKCHAIN_v3.md:27`; `RepoTecnico/requerimientos.md:57`; `RepoTecnico/propuesta_v3.md:157,311`; `RepoTecnico/base_datos.sql:58,830-831`; `RepoTecnico/diccionario_datos.md:230`.

**Recomendación.** Tomar decisión explícita (nueva Q11): ¿servicios quemables obligatorios en v3.0 o backlog v3.1? Si se acepta, convertirlo en RF medible: evento `ServiceConsumed` indexado, estado off-chain `consumed`/`burned` (ampliar enum), `tx_hash` del burn, plantilla `service.consume` firmada y test de aceptación «emitir NFT de servicio → consumir → supply on-chain 0 y estado off-chain consumed». Si no, retirarlo de RF-V3-16 y de propuesta §4.4.

---

#### H-26 — MEDIA · BRLT sin cap, límite ni política numérica; oráculo bajo el mismo Admin y comisión DB vs FeeCollector

**Área:** BRLT / economía · **Origen:** R1-4, R6-8, R7-9 · **Esfuerzo:** M

**Detalle.** RF-V3-20 exige que el suministro y la emisión estén «gobernados por la plataforma» (`requerimientos.md:66`) y la propuesta afirma «sin mint arbitrario; límites por tx» (`propuesta_v3.md:268`), pero no hay cap total, ni límite numérico por transacción, ni política de emisión (quién acuña, cuándo, contra qué), ni de burn. Q2 solo decide «sin valor real» y que se deja «cap y roles preparados por si se respalda» (`:171,362-363`), es decir, sin cap definido. El tope de precio de listado usa `tokens.valued_brlt` y un `PriceOracle` «simple, admin-managed» (`:237`): el mismo Admin que aprueba la tasación controla el oráculo y la emisión, de modo que Q9 no protege contra sobrevaluación deliberada. Además la comisión vive en DB (500 bps, `platform_fees`; `base_datos.sql:127-136`) mientras `FeeCollector` la recauda on-chain, sin fuente de verdad única ni conciliación; no hay multisig/timelock (se hereda `GovernanceMultisig` de v2 sin mapear) ni ruta de fondeo demo diseñada. El criterio de C0 («mint/burn/pause probados») no verifica ninguna cota (`:308`) y R-2 sigue abierto (`:340`).

**Evidencia.** `RepoTecnico/requerimientos.md:66`; `RepoTecnico/propuesta_v3.md:165-171,237,268,308,340,362-363,381`; `RepoTecnico/base_datos.sql:127-136,319-321`; `RepoTecnico/entornos_globales.md:93-95,149`.

**Recomendación.** Fijar cifras y política en un artefacto: cap total (p. ej. 1.000.000.000 BRLT), límite de mint por tx y por periodo, roles exactos y condiciones de pausa/burn; codificarlas como constantes y tests de contrato («mint por encima del cap revierte», «mint sobre límite por tx revierte»). Poner `MINTER/BURNER/PAUSER` tras multisig+timelock, separar la tasación/oráculo del rol que aprueba el listado (multiaprobación o fuente independiente), definir la comisión como dato on-chain con espejo off-chain reconciliado, y diseñar el faucet/fondeo demo con límites o declarar cómo se fondean los usuarios.

---

#### H-27 — MEDIA · El tope «precio ≤ tasación» es opcional si `valued_brlt` es NULL y la tasación no tiene método ni procedencia

**Área:** Tasación / Q9 · **Origen:** R1-5, R2-9 · **Esfuerzo:** S

**Detalle.** Q9 se presenta como decisión cerrada con «regla de BD + trigger» (`propuesta_v3.md:381`), pero el CHECK de `tokens` admite los tres NULL y el trigger de `listings` solo actúa si `v_valued IS NOT NULL` (`base_datos.sql:319-321,603`); por tanto un token puede registrarse sin tasación (`valued_brlt` NULL; `:309`) y listarse a cualquier precio, de modo que la regla no es universal ni puede testearse como «todo precio de listado ≤ tasación» (falta el caso negativo «listar sin tasación ⇒ rechazo»). Añadido verificado: `valued_brlt` no tiene campo de quién/cuándo la fija ni vínculo al documento `asset_doc_kind='tasacion'` (`:66`), por lo que el propio valor de tasación es un dato sin criterio de verificación. `diccionario_datos.md:228,236` reproduce el mismo CHECK permisivo.

**Evidencia.** `RepoTecnico/base_datos.sql:66,309,319-321,603`; `RepoTecnico/diccionario_datos.md:228,236`; `RepoTecnico/propuesta_v3.md:381`.

**Recomendación.** Hacer la regla fail-closed: exigir `valued_brlt NOT NULL` para estados `minted`/`listed` (trigger) y/o que `listings` rechace tokens sin tasación; definir que la tasación la fija el Admin a partir de un `asset_documents.doc_kind='tasacion'` y registrar quién/cuándo; añadir test negativo (listar sin tasación ⇒ rechazo) y documentar el alcance (¿aplica a productos/servicios?) en Q9 y en C3/C4.

---

#### H-28 — MEDIA · WCAG y rendimiento sin condiciones de verificación

**Área:** WCAG / rendimiento · **Origen:** R1-7, R3-7 · **Esfuerzo:** S

**Detalle.** RNF-V3-04 promete WCAG 2.1 AA pero su criterio operativo es «0 violaciones críticas en axe en las rutas principales» (`requerimientos.md:80`): axe-core clasifica por impacto `minor/moderate/serious/critical`, de modo que aceptar solo «críticas» permite violaciones `serious` (típicamente contraste, que es justamente AA) y el criterio es más laxo que el nivel declarado; además «rutas principales» no está enumerado en ningún artefacto. En paralelo, RNF-V3-05 fija «API p95 < 800 ms en rutas de lectura» (`:81`) sin enumerar rutas, sin condiciones de medición (entorno, concurrencia, dataset, ventana) ni método (k6/artillery), por lo que el número no es reproducible ni comparable entre ciclos. RF-V3-23 exige «métricas operativas» sin catálogo ni umbrales (`:69`), y R-8 menciona `axe` en CI sin especificar reglas (`propuesta_v3.md:346`). Tampoco hay pruebas con tecnología de asistencia, contraste 4.5:1, foco visible, teclado, zoom 200 % ni reducción de movimiento.

**Evidencia.** `RepoTecnico/requerimientos.md:69,80-81`; `RepoTecnico/propuesta_v3.md:102,346`.

**Recomendación.** Concretar RNF-V3-04: lista cerrada de rutas (manifiesto E2E), 0 violaciones de impacto `serious` y `critical` con tags `wcag2a/wcag2aa/wcag21aa`, viewports y tema; contraste ≥ 4.5:1 verificado por token de diseño; navegación 100 % por teclado y prueba con NVDA/VoiceOver de los 7 flujos de firma. Concretar RNF-V3-05: rutas medidas, entorno (Cloud Run/Anvil), concurrencia y ventana de percentil, y herramienta de carga; enlazar ambos al pipeline CI como gates con salida numérica.

---

#### H-29 — MEDIA · Solo 7 plantillas de billetera, sin procesos de venta/cancelación/liberación/revocación, y solo en español

**Área:** UX billetera / i18n · **Origen:** R5-8, R3-8 · **Esfuerzo:** S

**Detalle.** El brief exige plantillas de mensajes «para cada tipo de proceso que involucra la billetera» (`BRIEF_BARLOBLOKCHAIN_v3.md:7`). Solo hay 7 claves (`identity.create`, `claim.request`, `claim.issue`, `asset.tokenize`, `order.buy`, `service.consume`, `identity.recovery`; `base_datos.sql:814-836`), todas de la parte compradora/administrativa. Procesos de v3.0 que también implican interacción/firma de billetera —publicar/listar un activo para vender, cancelar una orden, confirmar recepción/liberar escrow, revocar un claim— no tienen plantilla, y RF-V3-21 no enumera los procesos cubiertos ni define criterio de aceptación; C5 promete «100 % de procesos con mensaje legible» sin lista verificable (`propuesta_v3.md:313`). Además, RNF-V3-10 y C5 exigen plantillas es/en (`requerimientos.md:86`), pero la semilla inserta 7 filas con locale `'es'` y ninguna con `'en'` (`base_datos.sql:814-836`), por lo que la selección de versión activa devolvería vacío en inglés o caería al español, sin fallback documentado.

**Evidencia.** `RepoTecnico/BRIEF_BARLOBLOKCHAIN_v3.md:7`; `RepoTecnico/requerimientos.md:67,86`; `RepoTecnico/propuesta_v3.md:177-185,313`; `RepoTecnico/base_datos.sql:814-836`.

**Recomendación.** Enumerar en RF-V3-21 los procesos de v3.0 con firma de billetera y completar las plantillas faltantes (listado/venta, cancelación, confirmación de recepción/liberación de escrow, revocación); sembrar las 7 plantillas en `'en'` (o degradar formalmente el requisito a español-only y ajustar RNF/C5), definir fallback documentado y test de cobertura 100 % `process_key × locale`, más un test que falle si un proceso con firma no tiene plantilla activa.

---

#### H-30 — MEDIA · «~55–60 % reutilizable» y «≈14–18 semanas» sin método ni línea base

**Área:** Planificación · **Origen:** R1-9 · **Esfuerzo:** S

**Detalle.** La propuesta afirma que «~55–60 % del trabajo de infraestructura de la v2 es reutilizable tal cual» (`propuesta_v3.md:25`) y estima «~14–18 semanas» con «1 dev full-stack + 0,5 blockchain + revisión» (`:30-31`). No hay línea base de dimensionamiento (LOC, ficheros, puntos de historia, cobertura/tests por módulo de v2), ni método de estimación, ni contingencia, ni definición de «0,5 dev» (¿50 % de FTE?, ¿qué tareas?) ni de «revisión»; el porcentaje no se mide en ningún sitio y el rango implica 2–2,6 semanas/ciclo sin justificar. §8 se etiqueta «orden de magnitud» (`:320,331`), pero el 55–60 % se presenta como hecho («La buena noticia») y el plan C0–C6 y la aprobación de Fase 3 se apoyan en esas cifras; el inventario de §2.2 no aporta métricas de tamaño (`:67-71`) y `estado_proyecto.md:62-63` solo da 16 contratos/42 tests.

**Evidencia.** `RepoTecnico/propuesta_v3.md:25,30-31,67-71,320,331`; `RepoTecnico/estado_proyecto.md:62-63`.

**Recomendación.** Sustituir el porcentaje por una tabla de dimensionamiento por módulo (person-days por rol y ciclo), indicar método (analogía v2 / 3 puntos), contingencia (%) y criterio de «done» por ciclo; marcar el porcentaje de reutilización como «necesita verificación» con la medición concreta a hacer sobre `rwa-sc`/`rwa-web` antes de comprometer fechas, o eliminarlo del resumen ejecutivo.

---

#### H-31 — MEDIA · La evidencia de recuperación apunta a `document_files`, cuyo `claim_request_id` es NOT NULL

**Área:** Datos / recuperación · **Origen:** R2-6 · **Esfuerzo:** S

**Detalle.** `identity_recovery_requests.evidence_document_id` referencia `document_files(id)` para adjuntar la evidencia del caso (Q5/RF-V3-11; `diccionario_datos.md:195`). Pero `document_files.claim_request_id` es NOT NULL con FK a `claim_requests` (`diccionario_datos.md:175`; `base_datos.sql:251`): no hay camino limpio para registrar un documento sin una solicitud de claim asociada, y la recuperación de identidad no es un claim. El diccionario y el SQL no prevén un `document_files` polimórfico ni una tabla puente, de modo que la evidencia solo puede insertarse reutilizando un `claim_request_id` ajeno, rompiendo la trazabilidad que exige RNF-V3-03. `evidence_document_id` es nullable (`:273`), así que el proceso puede existir sin evidencia y hay workaround, pero el modelo de integridad queda incorrecto.

**Evidencia.** `RepoTecnico/diccionario_datos.md:175,195`; `RepoTecnico/base_datos.sql:251,273`.

**Recomendación.** Hacer `document_files.claim_request_id` nullable y añadir `recovery_request_id` nullable con CHECK de exclusividad (o introducir `document_owner_type`/`document_owner_id` polimórfico o tabla puente); reflejarlo en diccionario §2.7-2.8, diagrama ER y SQL, y cubrirlo con un test de integridad.

---

#### H-32 — MEDIA · El inventario de tablas de §5.3 usa nombres que no existen y omite tablas reales

**Área:** Documentación · **Origen:** R2-7 · **Esfuerzo:** S

**Detalle.** §5.3 lista 12 tablas «nuevas» que deben escribirse juntas con diccionario/ER/SQL (`propuesta_v3.md:246-259`). Contrastadas con los tres artefactos: `issuer_requirements` es en realidad `issuer_program_requirements`; `assets` es `tokens`; `recovery_requests` es `identity_recovery_requests`; y `guarantors` no existe en ningún artefacto (el Fiador se modela con `token_guarantees.identity_id` + `identities`). Además el esquema contiene tablas que la propuesta no lista (`jurisdictions`, `issuer_program_credentials`, `token_required_claims`, `token_compliance_modules`, `token_guarantees`, `issuers`). El recuento 13+12=25 cuadra numéricamente pero oculta que la composición no coincide; la afirmación de sincronía (`:261-262`) se cumple entre los tres artefactos de datos, no respecto a la propuesta.

**Evidencia.** `RepoTecnico/propuesta_v3.md:217,246-262`; `RepoTecnico/base_datos.sql:172,267,294,347`; `RepoTecnico/diccionario_datos.md` (ausencia de `guarantors`).

**Recomendación.** Reescribir §5.3/§5.1 de la propuesta con los nombres reales del esquema e incluir las tablas omitidas (o renombrar el esquema, decisión única), alineando con la regla de sincronía y con el recuento de 25 tablas de `estado_proyecto.md` §7.

---

#### H-33 — MEDIA · El ER dibuja relaciones sin respaldo de columna; `jurisdictions` queda sin camino de datos (Q7)

**Área:** Modelo ER · **Origen:** R2-8 · **Esfuerzo:** S

**Detalle.** El diagrama afirma que los nombres son «idénticos a `base_datos.sql`» y que no hay «relaciones fuera del diagrama» (`diagrama_er.md:4-6`), pero varias aristas del bloque global no tienen columna ni FK que las sostenga: `payments` no tiene `platform_fee_id` (`:43`); `wallet_messages` no tiene ninguna clave hacia `sessions` (`:44`); `identities` no tiene `jurisdiction_id` ni tabla puente —la nota «reside (via claim)» no tiene camino: `claim_requests.metadata` es jsonb libre y no guarda jurisdicción (`:41`)—; `audit_log` no tiene columna de versión de esquema (`:49`); `chain_events` no tiene `token_id` (`:46-47`); `indexer_state` no se relaciona por columna con `chain_events`. Algunas son semánticas/conceptuales, pero la de jurisdicciones es funcionalmente relevante: `jurisdictions` queda huérfana y no puede gobernar el piloto LatAm de Q7.

**Evidencia.** `RepoTecnico/diagrama_er.md:4-6,41,43,44,46-47,49`; `RepoTecnico/base_datos.sql:206-217,419-433,454-466,468-479`.

**Recomendación.** Por cada relación: (a) eliminarla del ER si no aporta, o (b) materializarla en el DDL (p. ej. `identities.jurisdiction_id smallint FK`, `payments.platform_fee_id`, `chain_events.token_id`) y reflejarla en diccionario §6. En particular, añadir `jurisdiction_id` a `identities` (o a `claim_requests`) para que Q7 sea exigible y verificable, y ajustar la declaración de sincronía del ER.

---

#### H-34 — MEDIA · `audit_log` mutable, sin retención ni rol auditor; `asset_documents` sin purga ni derechos del titular

**Área:** Auditoría / retención · **Origen:** R3-9, R4-6, R7-10 · **Esfuerzo:** M

**Detalle.** `audit_log` es una tabla normal: no hay `REVOKE UPDATE/DELETE`, trigger de bloqueo, hash-chain, export WORM ni política de retención/partición; cualquier rol de aplicación puede alterar o borrar la evidencia de emisión/revocación de claims, pagos y recuperación (`base_datos.sql:454-465,520-522`). La propuesta afirma que la recuperación se hace «con doble aprobación y rastro inmutable» (`:271`), afirmación que el esquema no garantiza. El RBAC no incluye rol de auditoría de solo lectura (`propuesta_v3.md:192-202`), `actor_role` es texto libre y no se designa dueño de compliance/DPO ni responsable de auditoría externa (brecha v2 abierta; `estado_proyecto.md:65`). Además, la retención Q10 se materializa solo en `document_files.retention_delete_at` y `v_documents_due_deletion`; `asset_documents` (títulos de propiedad, tasaciones, fichas técnicas) no tiene `retention_delete_at` ni `deleted_at` (`:363-376`) y se conserva indefinidamente, y `audit_log` almacena `ip inet` y `actor_wallet` sin retención, legal hold ni derechos del titular (acceso, rectificación, supresión).

**Evidencia.** `RepoTecnico/base_datos.sql:363-376,454-465,520-522,682-687`; `RepoTecnico/propuesta_v3.md:192-202,270-271`; `RepoTecnico/requerimientos.md:79`; `RepoTecnico/estado_proyecto.md:65`.

**Recomendación.** Hacer `audit_log` append-only (REVOKE UPDATE/DELETE + trigger de bloqueo), particionar por mes con retención definida y añadir export/verificación de integridad (hash encadenado o copia a Cloud Storage con Object Lock); añadir rol auditor de solo lectura + export; extender `retention_delete_at`/`deleted_at` y purga a `asset_documents`; definir retención y legal hold para `audit_log`; documentar y probar derechos del titular y consentimiento; prueba de que UPDATE/DELETE falla como criterio de aceptación.

---

#### H-35 — MEDIA · Custodia de claves de plataforma sin dueño, rotación ni break-glass

**Área:** Custodia de claves · **Origen:** R4-7 · **Esfuerzo:** M

**Detalle.** Q5 define custodia non-custodial solo para la clave del usuario; no hay diseño ni responsable para las claves de plataforma (Admin, tesorería/`FeeCollector`, despliegue). `entornos_globales.md` lista `ADMIN_PRIVATE_KEY` entre variables de despliegue (`:103`) y publica las cuentas Anvil por defecto (`:69-73`), mientras exige firma con keystore cifrado/Secret Manager (`:145-148`); `GovernanceMultisig` se hereda de v2 (`propuesta_v3.md:67`) pero no se mapea a los roles v3. Se confirma la ausencia de responsable, rotación, break-glass y de un plan de pérdida/compromiso para la clave Admin, que puede emitir claims, tokenizar y aprobar recuperaciones.

**Evidencia.** `RepoTecnico/propuesta_v3.md:67,216,372`; `RepoTecnico/entornos_globales.md:69-73,103,145-148`.

**Recomendación.** Definir el modelo de custodia de claves de plataforma (multisig/HSM/Secret Manager), responsable, rotación y break-glass; declarar qué acciones del Admin requieren multisig y alinear `entornos_globales` con la política de firma. Incluir un procedimiento de recuperación por pérdida/compromiso y pruebas de que las acciones sensibles requieren el cuórum.

---

#### H-36 — MEDIA · Suspensión de identidad sin actor, efectos sobre listings/órdenes ni apelación

**Área:** Ciclo de vida del Socio · **Origen:** R4-8 · **Esfuerzo:** M

**Detalle.** `identities.status` admite `suspended`/`recovering` (`diccionario_datos.md:139`; `base_datos.sql:215`) y el RBAC permite al Admin emitir/revocar claims (la revocación del claim SOCIO sí retira el acceso; `propuesta_v3.md:266`), pero no hay capacidad ni proceso explícito de suspensión de identidad, ni se definen efectos sobre publicaciones activas, órdenes en escrow o activos ya vendidos: `listings.status` no incluye hold/suspended (`base_datos.sql:397`) y `orders` no prevé congelación por sanción (`:401-416`). Tampoco hay notificación, apelación o re-verificación para el Socio afectado.

**Evidencia.** `RepoTecnico/diccionario_datos.md:139`; `RepoTecnico/base_datos.sql:215,397,401-416`; `RepoTecnico/propuesta_v3.md:199,266`; `RepoTecnico/requerimientos.md:47`.

**Recomendación.** Definir el proceso de suspensión/revocación del Socio (quién, evidencia, doble control), sus efectos sobre listings y órdenes abiertas (congelar, cancelar/reembolsar) y el derecho de apelación/re-verificación; reflejarlo en estados y en un RF, con casos de uso Gherkin.

---

#### H-37 — MEDIA · Actores inventados (Visitante/Fiador/Emisor) y «catálogo público» tensiona el gate Socio

**Área:** Stakeholders / actores · **Origen:** R5-4 · **Esfuerzo:** S

**Detalle.** El brief define como usuarios al usuario/identidad, al Administrador y al Operador; «Fiador» aparece solo como certificado y «Emisor» no aparece como usuario de plataforma (`BRIEF_BARLOBLOKCHAIN_v3.md:13-14,24`). Sin embargo, `requerimientos.md:19` lista como actores a Visitante, Fiador y Emisor/Issuer; RF-V3-02 inventa un «modo visitante con acceso limitado (catálogo público, sin compra)» que no está en el brief y que tensiona la regla de que para acceder al Metaplace hay que obtener el claim Socio (`:33`); y la matriz RBAC otorga al Fiador compra/venta/intercambio y solicitud de claims (`propuesta_v3.md:192-202`). El enum `session_role` conserva además `visitor`/`investor`/`issuer`/`operator`/`admin` (`base_datos.sql:94`). Parte de este contenido se cruza con H-02 (Emisor) y H-10 (Fiador); el residuo propio es el Visitante y el catálogo público.

**Evidencia.** `RepoTecnico/BRIEF_BARLOBLOKCHAIN_v3.md:13-14,24`; `RepoTecnico/requerimientos.md:19,33`; `RepoTecnico/propuesta_v3.md:192-202`; `RepoTecnico/base_datos.sql:94`.

**Recomendación.** Confirmar el modelo de actores: si el catálogo no es público, quitar el modo visitante de RF-V3-02/RBAC; si el Fiador no es rol de plataforma, eliminarlo de actores/RBAC y modelarlo solo como claim; documentar Emisor/Issuer como rol (o retirarlo) y ajustar el enum de roles heredados de v2 que el brief no reconoce. Registrar la validación con el cliente.

---

#### H-38 — MEDIA · Requisitos atribuidos al brief que no contiene, cita a un §4.3 inexistente y tabla §6 incoherente

**Área:** Trazabilidad · **Origen:** R5-5, R5-6 · **Esfuerzo:** S

**Detalle.** El brief solo dice que BRLT (8 decimales) es la moneda de pago y que WEB-TOKEN permite compra/venta/intercambio de tokens, NFTs y criptomonedas simbólicas. RF-V3-19 añade «precio fijo con escrow y comisión» atribuyéndolo a `[objetivo]`/`[WEB-TOKEN]`; RF-V3-20 añade «sin valor real; suministro y emisión gobernados» atribuyéndolo a `[objetivo]`; RF-V3-10 añade revocación/caducidad atribuyéndolo a `[WEB-ISSUSER]` (`requerimientos.md:46,65-66`). Esas piezas provienen de Q2/Q3/Q4/Q8 y del diseño, y la tabla §6 repite la atribución (`:130-139`), haciendo parecer que el brief justifica alcance que no contiene. Además, RF-V3-21 remite a «(ver §4.3 del brief)» (`:67`) pero el brief (32 líneas) no tiene secciones numeradas; y §6 no coincide con la columna «Brief» de cada RF: omite RF-V3-02, coloca RF-V3-07 bajo `[WEB-IDENTITY]` aunque cita `[procesos generales]`, y asigna RF-V3-15/16/17 a `[procesos generales]` cuando citan `[WEB-ISSUSER]`.

**Evidencia.** `RepoTecnico/BRIEF_BARLOBLOKCHAIN_v3.md:1-32`; `RepoTecnico/requerimientos.md:46,56-58,65-67,130-139`; `RepoTecnico/propuesta_v3.md:54`.

**Recomendación.** Separar en la tabla de requerimientos la columna «Brief» (solo lo literal) de una columna «Origen» (Q2/Q3/Q4/Q8/diseño); reetiquetar RF-V3-19/20/10 como derivados de decisión o diseño; eliminar o corregir la cita a §4.3; regenerar §6 desde la columna de cada RF y añadir un chequeo automático de trazabilidad (todo RF apunta a una sección existente y toda sección del brief tiene RF o justificación de no aplicabilidad).

---

#### H-39 — MEDIA · «Cargar todas las características del activo» no se convierte en requisito ni en modelo de atributos

**Área:** Modelo de activos · **Origen:** R5-7 · **Esfuerzo:** M

**Detalle.** El proceso general 2 del brief pide, además de Garantía y Fiador, cargar todas las características del activo real junto con los PDF de tenencia (`BRIEF_BARLOBLOKCHAIN_v3.md:14`). RF-V3-14 solo exige los dos claims y los PDF; RF-V3-15 añade «lote y documentos de respaldo» sin atributos (`requerimientos.md:55`); la tabla `tokens` solo tiene `name/symbol/unit/total_supply/price/valued/metadata_uri` (sin ficha estructurada por tipo; `base_datos.sql:294-329`) y `asset_documents` admite «ficha_tecnica» como documento, no como datos consultables (`diccionario_datos.md:275`). La parte del brief sobre características queda parcialmente absorbida y no es verificable.

**Evidencia.** `RepoTecnico/BRIEF_BARLOBLOKCHAIN_v3.md:14`; `RepoTecnico/requerimientos.md:55`; `RepoTecnico/diccionario_datos.md:229,275`; `RepoTecnico/base_datos.sql:294-329`.

**Recomendación.** Añadir un RF de ficha de activo con atributos obligatorios por tipo (producto/servicio/bien) y criterio de aceptación medible; modelarlo (jsonb validado o tabla `asset_attributes`) y enlazarlo al entregable C3, con validación de campos obligatorios por tipo.

---

#### H-40 — MEDIA · `metadata_uri` sin estrategia de almacenamiento: se pierde el pinning de v2 y el NFT apunta a recurso mutable/SPOF

**Área:** Metadatos NFT · **Origen:** R6-9 · **Esfuerzo:** M

**Detalle.** El único campo previsto para metadatos del NFT es `tokens.metadata_uri` (text), sin CID/hash de contenido, sin proveedor de pinning, sin gateway/caché ni verificación de inmutabilidad (`diccionario_datos.md:229`; `base_datos.sql:294-328`, campo en `:308`). Los ERC-721/1155 pueden incluir imágenes/documentos del activo (y potencialmente PII), pero no hay esquema de metadatos ni control de qué se publica. En v2 existía `DS_PINATA_JWT` para almacenamiento tipo IPFS (`rwa-sc/RepoTecnico/entornos_globales.md:36`); la lista de secretos de v3 solo conserva `DATABASE_URL`, `SIWE_SESSION_SECRET` y `KYC_ENCRYPTION_KEY` (`entornos_globales.md:50`) y no menciona IPFS/pinning, por lo que la continuidad del almacenamiento de metadatos no está definida. Si `metadata_uri` es una URL del backend Barlo, el NFT se rompe al mover/retirar el servicio; si es mutable, el activo puede cambiar de metadatos.

**Evidencia.** `RepoTecnico/diccionario_datos.md:229`; `RepoTecnico/base_datos.sql:294-328`; `RepoTecnico/entornos_globales.md:50`; v2: `rwa-sc/RepoTecnico/entornos_globales.md:36`; `RepoTecnico/propuesta_v3.md:216-230`.

**Recomendación.** Definir en el diccionario el esquema de metadatos y el almacenamiento content-addressed (CID IPFS con pinning/replicación o hash on-chain + gateway Barlo con respaldo), guardar `sha256` del JSON y de los medios, excluir PII de metadatos públicos y documentar fallback/migración si el proveedor de pinning desaparece.

---

#### H-41 — MEDIA · Sin modelo de coste, cuotas ni alarmas de facturación

**Área:** Coste / operación · **Origen:** R6-10 · **Esfuerzo:** S

**Detalle.** La estimación §8 solo expresa esfuerzo en semanas-persona (`propuesta_v3.md:320-331`); no hay coste mensual de GCP, presupuesto, alarmas de facturación ni cuotas. Quedan sin dimensionar: Cloud SQL (instancia always-on, posible HA, almacenamiento y backups), Cloud Run de apps+Anvil+indexer Job+Scheduler, Secret Manager, almacenamiento de documentos cifrados (hasta 20 MB por documento y retención de hasta 12 meses según Q10; `base_datos.sql:258,261`; `diccionario_datos.md:182`) y el pinning de metadatos NFT. Tampoco hay límites de `max-instances` ni de gasto por ciclo, por lo que el piloto demo puede escalar coste sin control. Los importes concretos requieren la facturación real del proyecto y no se afirman.

**Evidencia.** `RepoTecnico/propuesta_v3.md:320-331`; `RepoTecnico/entornos_globales.md:41-53`; `RepoTecnico/base_datos.sql:258,261`; `RepoTecnico/diccionario_datos.md:182`.

**Recomendación.** Añadir a la propuesta un modelo de coste por ciclo (Cloud SQL tier/HA, Cloud Run min/max, almacenamiento de documentos con retención, pinning NFT) con presupuesto y budget alerts, y fijar cuotas/límites de instancias y de gasto como criterio de aceptación de C6.

---

### 5.4 Bajos

---

#### H-42 — BAJA · La allowlist MIME configurable no puede materializarse contra el CHECK fijo pdf/png/jpeg

**Área:** Validación documental · **Origen:** R2-10 · **Esfuerzo:** S

**Detalle.** `issuer_program_requirements.mime_allowlist` es `text[]` configurable por el Admin (`diccionario_datos.md:106`) y el diccionario describe `document_files.mime_type` como «validado por allowlist» (`:177`), pero el DDL impone `CHECK (mime_type IN ('application/pdf','image/png','image/jpeg'))` en `document_files` y en `asset_documents` (`base_datos.sql:262,374`). Un ISSUER que configure otro MIME (WebP, TIFF, DOCX…) sería rechazado por la BD sin migración, de modo que la configurabilidad prometida en el modelo de ISSUER no funciona; RF-V3-08 admite «formatos adicionales a definir» (`requerimientos.md:44`). El impacto es bajo en v3.0 porque la allowlist por defecto coincide con el CHECK y la validación puede hacerse en aplicación.

**Evidencia.** `RepoTecnico/diccionario_datos.md:106,177`; `RepoTecnico/base_datos.sql:262,374`; `RepoTecnico/requerimientos.md:44`.

**Recomendación.** O bien validar el MIME en aplicación contra `issuer_program_requirements.mime_allowlist` y dejar el CHECK como red de seguridad, o sustituir/ampliar los CHECK por una tabla `mime_types(code, active)`; documentar en diccionario §2.2/§2.7 y §3.5 que la allowlist configurable está acotada por el tipo permitido en BD en v3.0.

---

#### H-43 — BAJA · El «proceso» del ISSUER se modela solo como texto libre

**Área:** Modelo ISSUER · **Origen:** R5-9 · **Esfuerzo:** S

**Detalle.** El brief dice que los ISSUER se crean «definiendo el proceso y los requisitos» y que el Metaplace opera «siempre que se cumpla las condiciones dadas en el ISSUER» (`BRIEF_BARLOBLOKCHAIN_v3.md:16,25`). RF-V3-12 y RF-V3-18 recogen la idea, pero `issuer_programs` solo tiene `slug/name/description/activity_kind`: el «proceso» es la descripción («Proceso explicado al usuario»; `diccionario_datos.md:90`), no una secuencia verificable; `issuer_program_requirements` solo admite documento o claim previo (`:95-115`) y las condiciones de operación quedan en `token_required_claims`. El impacto es de modelado/testabilidad, no de pérdida total del deseo.

**Evidencia.** `RepoTecnico/BRIEF_BARLOBLOKCHAIN_v3.md:16,25`; `RepoTecnico/diccionario_datos.md:90,95-115`; `RepoTecnico/requerimientos.md:48,59`.

**Recomendación.** Modelar los pasos del ISSUER (p. ej. `issuer_program_steps` ordenada) o documentar explícitamente que «proceso» = descripción + lista de requisitos y que las «condiciones» = claims exigidos; añadir criterio de aceptación verificable a RF-V3-12 y RF-V3-18.

---

#### H-44 — BAJA · «≈60 servicios/mes» se hereda como dato de diseño sin supuesto formal ni RNF de capacidad

**Área:** Capacidad · **Origen:** R1-10, R5-10 · **Esfuerzo:** S

**Detalle.** El brief aporta «se estima 60 servicios por mes» (`BRIEF_BARLOBLOKCHAIN_v3.md:27`) y requerimiento/propuesta lo repiten como «≈60/mes» (`requerimientos.md:57`; `propuesta_v3.md:157`), pero no se define si es por ISSUER o total, si es media mensual o pico, ni tolerancia/concurrencia, ni cómo se relaciona con RNF-V3-05 (rendimiento; `requerimientos.md:81`) o con la capacidad de acuñación (gas, lotes). Tampoco queda como supuesto formal (S-1…S-13 no lo recogen; `:110-122`), de modo que no hay criterio para decir si el sistema «soporta 60 servicios/mes».

**Evidencia.** `RepoTecnico/BRIEF_BARLOBLOKCHAIN_v3.md:27`; `RepoTecnico/requerimientos.md:57,81,110-122`; `RepoTecnico/propuesta_v3.md:157`.

**Recomendación.** Convertirlo en supuesto formal y, si aplica, RNF de capacidad con número y condiciones: p. ej. «≥ 60 acuñaciones y 60 consumos de servicio/mes por ISSUER, con pico de X/hora y p95 de API < 800 ms bajo esa carga», verificado con test de carga o justificación de capacidad; si no se puede medir aún, marcarlo como supuesto abierto (S-14) y no como dato de diseño.

---

## 6. RNF faltantes o débiles (agrupados por ISO 25010)

| Categoría ISO 25010 | RNF existente | Hueco principal | Hallazgos |
|---|---|---|---|
| **Adecuación funcional** | RF-V3-01…23 | Criterios de aceptación medibles ausentes en varias RF (servicios, activos, Issuer, soporte) | H-20, H-25, H-39, H-43 |
| **Eficiencia de desempeño** | RNF-V3-05 (solo lectura; p95 < 800 ms sin condiciones) | Sin p95 de escritura, throughput ni concurrencia; medición no reproducible | H-18, H-28, H-44 |
| **Compatibilidad** | — | No hay RNF de interoperabilidad de wallet/red más allá de SIWE; no crítico en Fase 1 | — |
| **Usabilidad / accesibilidad** | RNF-V3-04 (axe «críticas», sin rutas ni WCAG completo) | Sin contraste, teclado, lector de pantalla, zoom ni umbral de legibilidad | H-22, H-28, H-29 |
| **Fiabilidad** | RNF-V3-06 (503 tipado, indexer reanudable) | Sin SLO de disponibilidad, error budget, RPO/RTO ni prueba de restauración | H-14, H-18, H-13 |
| **Seguridad** | RNF-V3-01/02 (authn/authz, cifrado) | Sin rate limiting, rotación de secretos, TTL de sesión, threat model ni RLS | H-15, H-24, H-35 |
| **Mantenibilidad** | RNF-V3-08 (cobertura 80/70 %) | No cubre migraciones reproducibles ni contratos de datos versionados | H-01, H-23 |
| **Portabilidad** | RNF-V3-07 (sin literales de red) | No cubre portabilidad de metadatos NFT ni de almacenamiento | H-40 |
| **Operación / observabilidad** | RNF-V3-11 (despliegue reproducible) | Sin SLIs, alertas, trazas ni retención de logs | H-19, H-13, H-41 |
| **Cumplimiento y protección de datos** | — (solo exclusión AML/PSD2/MiCA «a confirmar») | Categoría completa ausente: base legal, DPIA, derechos del titular, retención, encargados | H-16, H-17, H-34 |
| **Recuperabilidad** | — | Sin backup/PITR documentado, sin copia de `KYC_ENCRYPTION_KEY`, sin ensayo de restauración | H-14, H-12, H-17 |

**Lectura.** De las categorías relevantes, **cumplimiento/protección de datos, recuperabilidad y observabilidad no tienen RNF alguno**, y las existentes de desempeño, fiabilidad y usabilidad carecen de condiciones de verificación. El catálogo RNF debe ampliarse con al menos RNF-V3-12 (cumplimiento y derechos del titular), RNF-V3-13 (observabilidad) y RNF-V3-14 (recuperación RPO/RTO), además de numerar los criterios de las RNF actuales.

---

## 7. Stakeholders faltantes o con rol incompleto

| Stakeholder | Estado en los artefactos | Hueco | Hallazgo |
|---|---|---|---|
| **Emisor / Issuer** | Listado como actor (`requerimientos.md:19`), pero sin rol en el RBAC ni registro de qué wallet emite cada claim | Autoridad de emisión ambigua; R-1 sin decisión | H-02 |
| **Fiador** | Solo como certificado y columna del RBAC | Sin consentimiento, rol de sesión, obligaciones ni estados de garantía | H-10 |
| **Operador** | Actor con rol, pero con acceso «parcial» al Panel Sistema y sin resultado propio registrado | Contradice el brief y RF-V3-22; verificación no separable de la aprobación | H-09, H-21 |
| **Auditor** | No existe | Sin rol de solo lectura, sin exportación y sin `audit_log` inmutable | H-34 |
| **Regulador / DPO / compliance** | No designado; cumplimiento «fuera de alcance (a confirmar)» | Sin responsable, sin DPIA, sin opinión legal por jurisdicción | H-16 |
| **Soporte / helpdesk** | No existe como actor ni canal ni SLA | Sin escalado para rechazos, disputas o pérdida de wallet | H-20 |
| **Árbitro de disputas** | No asignado | `disputed`/`refunded` sin actor que resuelva, libere o reembolse | H-05 |
| **Socio (ciclo de vida)** | Claim SOCIO definido, pero sin proceso de suspensión/apelación | Sin efectos sobre listings/órdenes ni derecho de apelación | H-36 |
| **Visitante** | Inventado en RF-V3-02 (catálogo público) | No está en el brief y tensiona el gate Socio | H-37 |
| **Custodio de claves de plataforma** | No designado | Claves Admin/tesorería/despliegue sin dueño, rotación ni break-glass | H-35 |

**Lectura.** El mapa de actores del brief (usuario, Administrador, Operador) se quedó corto para v3: el diseño incorpora Fiador, Emisor, Soporte, Auditor y árbitro de disputas sin asignarles rol, responsabilidad ni trazabilidad. En Fase 1 basta con declararlos y decidir cuáles son roles de plataforma, cuáles claims y cuáles procesos; en Fase 2 deben materializarse en el modelo de roles y en los casos de uso.

---

## 8. Plan de acción

### 8.1 Quick wins (≤ 1 día)

| # | Acción | Hallazgos | Responsable sugerido | Esfuerzo |
|---|---|---|---|---|
| QW-1 | Corregir cabeceras y estado: `requerimientos.md` (Fase 1 cerrada, v3.0, S-1…S-13), `propuesta_v3.md` (retirar «requiere cerrar entrevista») y `estado_proyecto.md` (S-13, supuestos aceptados con dueño/fecha) | H-04 | Producto | S |
| QW-2 | Eliminar la referencia a un §4.3 inexistente y regenerar la tabla §6 desde la columna «Brief» de cada RF; separar «Brief» de «Origen» | H-38 | Producto | S |
| QW-3 | Corregir §5.3 con los nombres reales de tabla (`issuer_program_requirements`, `tokens`, `identity_recovery_requests`) y las tablas omitidas | H-32 | Producto / Datos | S |
| QW-4 | Fijar la convención de versión única (recomendado 3.0, sin 1.3) en propuesta, diccionario y entornos; actualizar el criterio de C0 | H-01 | Arquitectura | S |
| QW-5 | Añadir `CHECK (second_approval_wallet <> approved_by_wallet)` y `UNIQUE` en `orders.escrow_tx_hash` y `payments.tx_hash` | H-08, H-05 | Datos | S |
| QW-6 | Poner ❌ al Operador en «Panel Sistema» y alinear la matriz con RF-V3-22 | H-21 | Producto | S |
| QW-7 | Numerar criterios pendientes: límites de legibilidad (H-22), cap y límites BRLT (H-26), WCAG/p95 (H-28), retención (H-17) y 60/mes (H-44) | H-17, H-22, H-26, H-28, H-44 | Producto / Arquitectura | S |
| QW-8 | Separar el emisor KYC en las semillas (ISSUER dedicado) y quitar el requisito circular de `onboarding-socio` | H-03 | Datos | S |
| QW-9 | Documentar la cuenta Admin de Anvil como solo-dev y añadir gate de CI que detecte direcciones conocidas | H-11 | DevOps / Contratos | S |
| QW-10 | Sembrar las 7 plantillas en `en` o degradar formalmente el requisito es/en | H-29 | Datos / Web | S |

### 8.2 Mejoras (≤ 1 semana)

| # | Acción | Hallazgos | Responsable sugerido | Esfuerzo |
|---|---|---|---|---|
| M-1 | Escribir la migración real v2→v3 (`ALTER`/`ALTER TYPE`/backfill) y probarla en CI contra un `pg_dump` v2, con `schema_migrations` única | H-01 | Datos / Arquitectura | L |
| M-2 | Decidir Q11 (Emisor/Issuer) y, si aplica, rol `issuer` + FK emisor→claim en `claim_requests`/`tokens`; validar ISSUER/ISSUES con el sponsor | H-02 | Producto / Arquitectura | M |
| M-3 | Endurecer garantías y revocación: `claim_request_id NOT NULL`, claim aprobado, trigger de invalidación, anti-autoaprobación y tests negativos | H-06 | Datos / Contratos | M |
| M-4 | Diseñar el escrow/marketplace íntegro: reserva con TTL, `quantity`, `UNIQUE`, máquina de estados, disputa/árbitro y atomicidad NFT+BRLT | H-05 | Datos / Contratos / Arquitectura | L |
| M-5 | Definir el modelo de roles canónico + `role_assignments` + cuentas/seed por rol y matriz de pruebas de autorización | H-23, H-21, H-37 | Datos / DevOps | M |
| M-6 | Completar RNF numéricos: RNF-V3-12 (cumplimiento/derechos), RNF-V3-13 (observabilidad), RNF-V3-14 (recuperación RPO/RTO), legibilidad, WCAG y p95 con condiciones | H-16, H-17, H-18, H-19, H-22, H-28 | Producto / Arquitectura | M |
| M-7 | Documentar y probar backup/PITR, copia/rotación de `KYC_ENCRYPTION_KEY`, pooling y un RPC de respaldo | H-14, H-15 | DevOps | M |
| M-8 | Endurecer el indexer: `chain_id`/`block_hash`/`removed`, detección de reset/reorg, alertas y job de reconciliación | H-13 | Arquitectura / Datos | M |
| M-9 | Especificar hooks de compliance on-chain por activo (`_update`/`beforeTokenTransfer` + IdentityRegistry) | H-07 | Contratos | M |
| M-10 | Separar Service Accounts y secretos por servicio, roles PostgreSQL y RLS; rotación de claves | H-15, H-24, H-35 | DevOps / Datos | M |
| M-11 | Definir política numérica de BRLT (cap, límites, multisig+timelock), separar oráculo de tasación y unificar comisión on-chain/off-chain | H-26 | Contratos / Arquitectura | M |
| M-12 | Hacer fail-closed el tope de tasación y registrar procedencia de la valuación | H-27 | Datos | S |
| M-13 | Hacer `audit_log` append-only, añadir rol auditor y extender la retención a `asset_documents` | H-34, H-17 | Datos / DevOps | M |
| M-14 | Definir proceso de suspensión/apelación del Socio con efectos sobre listings y órdenes | H-36 | Producto / Datos | M |
| M-15 | Modelar características del activo y estrategia de metadatos NFT (CID/hash, pinning, PII) | H-39, H-40 | Producto / Arquitectura / Web | M |
| M-16 | Añadir RF de soporte guiado y metodología de identidad Web3 con criterios en C1/C2/C3 | H-20 | Producto | S |
| M-17 | Sustituir el 55–60 % y las 14–18 semanas por una tabla de dimensionamiento con método y contingencia | H-30 | Producto | S |
| M-18 | Añadir modelo de coste, cuotas y budget alerts; fijarlos como criterio de C6 | H-41 | Producto / DevOps | S |

### 8.3 Roadmap (Fase 2 → pre-piloto)

| Etapa | Objetivo | Hallazgos que cierra | Responsable |
|---|---|---|---|
| **Fase 2 (casos de uso y documento técnico)** | Bajar a casos de uso Gherkin los flujos de identidad, ISSUER, tokenización, compra y recuperación; fijar contratos de API y modelo de datos v3 final | H-02, H-05, H-07, H-09, H-23, H-25, H-36, H-39 | Producto / Arquitectura |
| **Antes de C0** | Migración probada en CI, versión única de esquema, `KYC_ENCRYPTION_KEY` con copia/rotación, gate anti-claves-Anvil | H-01, H-11, H-14, H-15 | Datos / DevOps |
| **Antes de C4** | Escrow atómico, disputa/árbitro, idempotencia, compliance on-chain, prueba de concurrencia, auditoría externa de contratos | H-05, H-07, H-18, H-24 | Contratos / Arquitectura |
| **Antes de piloto con usuarios** | Opinión legal por jurisdicción, DPIA, derechos del titular, retención operativa, SLO/DR ensayados, observabilidad y coste | H-16, H-17, H-18, H-19, H-34, H-41 | Producto / DevOps |
| **Producción con activos reales** | **No autorizada** hasta cerrar H-01…H-26 (CRÍTICAS y ALTAS), auditoría externa y compliance; no hay atajo documental | Todos los CRÍTICOS/ALTOS | Dirección / Producto |

---

## 9. Criterios de aceptación para cerrar la Fase 1 con la documentación corregida

La Fase 1 podrá declararse cerrada y habilitar la Fase 2 cuando se cumplan **todos** los criterios siguientes, verificables por un revisor independiente:

1. **Migración y versión (H-01).** Existe una única convención de versión (`3.0`) coherente en `propuesta_v3.md`, `diccionario_datos.md`, `entornos_globales.md` y `base_datos.sql`; el script de migración se ejecuta sin errores sobre un `pg_dump` v2 en CI, con `schema_migrations` registrando la versión al final y evidencia de que las 9 tablas heredadas evolucionan por `ALTER`/backfill (0 sentencias `CREATE TABLE IF NOT EXISTS` sobre tablas colidentes).
2. **Autoridad del Emisor (H-02).** Existe una decisión registrada (Q11) sobre el Emisor/Issuer; si es rol, figura en el RBAC con capacidades y se persiste el emisor por claim en `claim_requests`/`tokens`; si es plantilla, se retira de la lista de actores y de la autoría. La validación ISSUER/ISSUES con el sponsor queda documentada.
3. **Alta de usuario (H-03).** Las semillas permiten obtener KYC y SOCIO sin circularidad; un E2E de alta de usuario nuevo pasa en C1.
4. **Estado y supuestos (H-04).** Los tres documentos declaran el mismo estado de Fase 1 y la misma lista de supuestos (S-1…S-13); S-3 y S-8 están resueltos o aceptados con dueño y fecha; no se afirma «ninguna decisión abierta» si queda alguna.
5. **Integridad del marketplace (H-05).** Existen índice único de orden abierta por listing, `quantity` en `orders`, `UNIQUE` en tx de escrow/pago, máquina de estados con plazos, proceso de disputa con árbitro y atomicidad NFT+BRLT; los tests de concurrencia, doble venta, timeout y reembolso pasan y C4 los exige.
6. **Controles de claims (H-06, H-08).** Los tests negativos demuestran que: garantía/fiador sin claim aprobado no habilita la tokenización; la revocación bloquea el token; el mismo aprobador de recuperación es rechazado; y el Operador no puede aprobar/emitir.
7. **Cumplimiento on-chain (H-07).** El diseño de los contratos de activo incluye hooks de verificación por transferencia y tests de transferencia a wallet no verificada; `token_required_claims` se aplica on-chain.
8. **RNF numéricos y medibles (H-16 a H-19, H-22, H-28).** Existen RNF-V3-12 (cumplimiento/derechos), RNF-V3-13 (observabilidad) y RNF-V3-14 (recuperación RPO/RTO), y las RNF de legibilidad, WCAG y p95 incluyen umbral, rutas/enumero, condiciones de medición y gate de CI; cada una tiene un criterio de aceptación falsable.
9. **Retención ejecutable (H-17).** Existe job de purga programado, lógica que fija `retention_delete_at` y `ended_at`, y un test que demuestra que un documento vencido deja de servirse y la purga queda en `audit_log`.
10. **Modelo de roles y stakeholders (H-02, H-10, H-21, H-23, H-35, H-36, H-37).** Está decidido qué actores son roles de plataforma y cuáles claims; el enum de roles está alineado con el RBAC; existen cuentas/seed por rol y matriz de autorización; Fiador, Auditor, Soporte y árbitro de disputas tienen rol o proceso declarado.
11. **Trazabilidad (H-32, H-38, H-30, H-44).** La tabla de trazabilidad se genera desde la columna «Brief» de cada RF, no contiene citas a secciones inexistentes, y todo RF/RNF apunta a un origen existente; las estimaciones se presentan con método o marcadas como no verificadas; el volumen de 60/mes es supuesto formal o RNF de capacidad.
12. **Documentación de datos sincronizada (H-31, H-33, H-42, H-43).** Diccionario, ER y SQL vuelven a cuadrar 25/25 tras los cambios; el ER no declara relaciones sin respaldo o las marca como conceptuales; la evidencia de recuperación tiene camino de datos; MIME y proceso del ISSUER están documentados con su alcance real.
13. **Operación y coste (H-14, H-24, H-35, H-40, H-41).** Backup/PITR, copia de claves, pooling, RPC de respaldo, modelo de coste y presupuesto están documentados; el entorno Anvil de demo queda declarado como no apto para activos reales y con claves rotadas.
14. **Verificación final.** Se repiten las comprobaciones mecánicas (25/25 tablas, SQL sin errores de parseo, 5 bloques Mermaid) y se añade un chequeo automático de trazabilidad y de convención de versión; el informe de cierre registra **0 CRÍTICAS y 0 ALTAS abiertas**, con las MEDIAS y BAJAS con dueño y fecha.

**Gate de salida.** Si al repetir la verificación queda abierta alguna CRÍTICA o ALTA, la Fase 1 **no** se declara cerrada. Las MEDIAS y BAJAS pueden quedar abiertas con dueño y fecha si no afectan a C0–C2, pero deben estar registradas en `estado_proyecto.md`. El paso a Fase 2 no requiere código v3 desplegado; requiere que la documentación y el DDL sean una línea base verificable.

---

**Fin del informe V3.** Consolidación de 70 hallazgos verificados en 44 hallazgos únicos (2 CRÍTICAS · 20 ALTAS · 19 MEDIAS · 3 BAJAS), sin añadir hallazgos fuera de los informes adversariales R1–R7.
