# Auditoría del documento técnico — RWA v3 «Barlo Metaplace»

> **Documento auditado:** `RepoTecnico/documento_tecnico.md` v3.2 (259 líneas, 13 secciones)
> **Fecha de síntesis:** 2026-11-04 · **Fase auditada:** Fase 2 (casos de uso + documento técnico)
> **Alcance:** contraste documental del documento técnico contra `casos_uso.md`, `requerimientos.md`,
> `base_datos.sql`, `diseno_cierre_v3_2.md`, `estado_proyecto.md`, `entornos_globales.md` y
> `propuesta_v3.md`, con verificación de existencia de los artefactos de repositorio citados.
> **Naturaleza:** auditoría documental. No acredita producto ejecutado, ni implementación de contratos,
> ni operación en GCP; esos extremos pertenecen a los gates C0–C6 de la Fase 3.

---

## 1. Veredicto

**SÍ CON CORRECCIONES**

El documento técnico es una especificación **mecánicamente coherente y sustancialmente completa**:
los recuentos cuadran con el repositorio (27/27/27 tablas, 13 enums, 7 procesos de firma, matriz §9 de
11 filas, CI de 9 jobs y `deploy_gcp.sh` con los 5 modos citados), y la arquitectura, contratos, API,
datos, seguridad y despliegue están cubiertos con decisiones Q1–Q14a trazadas. **No se detectan
hallazgos CRÍTICOS.**

Sin embargo, **no puede declararse cerrada la Fase 2 con el documento en su estado actual** por dos
razones verificables:

1. **Una ALTA de gobernanza documental:** el estado de la Fase 1 es contradictorio entre cuatro
   artefactos y dentro de dos de ellos (H-01), lo que impide determinar qué estado es el vigente y
   contradice la decisión Q14a que el propio documento invoca como base.
2. **El documento no satisface dos de sus propios criterios de aceptación (§12):** el criterio 1 exige
   dueño por componente y el criterio 2 exige que todo RF aparezca en la matriz §9; ambos incumplen
   (H-02, H-03). Un documento que fija criterios y no los cumple no es cerrable sin corrección o sin
   reformulación explícita aprobada.

**Condición de cierre:** corregir H-01 (ALTA) y H-02, H-03 y H-04 (MEDIA) antes de declarar cerrada
la Fase 2; H-05, H-06 y H-07 (BAJA) deben corregirse en la misma pasada o aceptarse explícitamente por
el sponsor con dueño, fecha y criterio de verificación posterior. Con esas correcciones, el veredicto
pasa a **SÍ**.

| Dimensión | Resultado |
|---|---|
| ¿Apto para cerrar la Fase 2 hoy? | **No** — requiere correcciones |
| ¿Apto tras corregir ALTA + MEDIAS? | **Sí** |
| Hallazgos CRÍTICOS | 0 |
| Hallazgos ALTOS | 1 |
| Hallazgos MEDIOS | 3 |
| Hallazgos BAJOS | 3 |
| Criterios §12 cumplidos | 3/5 (criterios 3, 4 y 5); 1 y 2 incumplidos; 4 nominal en R-7 |

---

## 2. Metodología (2 lentes + verificación adversarial)

### 2.1 Las dos lentes previstas

| Lente | Pregunta central | Qué contrasta |
|---|---|---|
| **Lente A — Completitud y consistencia técnica** | ¿La especificación cubre arquitectura, contratos, API, datos, seguridad y despliegue sin contradicciones internas? | Recuentos, tablas, enums, endpoints, eventos, jobs, CI y script de despliegue contra los artefactos de Fase 1 y Fase 2 |
| **Lente B — Trazabilidad, estado y gobernanza** | ¿Cada CU y cada RF tienen componente y ciclo? ¿El estado declarado es único y verificable? ¿Los riesgos tienen mitigación y gate? | Matriz §9, criterios §12, estados de Fase 1, registro de riesgos, referencias a gates |

### 2.2 Entrada y activación de la verificación adversarial

Las **dos actas de revisión recibidas llegaron vacías** (`[{}, {}]`: 0 candidatos). Para no emitir un
veredicto vacío, la verificación se ejecutó en **modo adversarial directo** contra los 8 artefactos
núcleo, exigiendo para cada hipótesis:

- **evidencia `ruta:línea`** verificable en el repositorio;
- **falsabilidad**: si el artefacto no permite sostener la contradicción, el candidato se descarta;
- **calibración de severidad** por impacto en el cierre de Fase 2, no por preferencia editorial;
- **deduplicación** contra defectos ya registrados en `INFORME_CIERRE_V3_2.md`.

### 2.3 Verificación mecánica ejecutada (no solo lectura)

| Comprobación | Resultado |
|---|---|
| Tablas SQL = diccionario = ER | **27/27/27**, 0 discrepancias de columnas |
| Enums del esquema | **13** (`asset_kind` … `session_role`) |
| Semillas `wallet_messages` | **7 procesos × `es`/`en` = 14 plantillas** |
| Matriz §9 | **11 filas** barridas contra 29 CU y 31 RF |
| CI citada | `rwa-sc/.gitlab-ci.yml` existe: `validate`, `artefactos-v3`, `build`, `fmt`, `test`, `coverage`, `gas`, `ci-checks`, `slither` (**9 jobs**) |
| Despliegue citado | `rwa-web/scripts/deploy_gcp.sh` existe: `provision\|build\|deploy\|job\|scheduler\|verify\|all` (los 5 modos del documento, más `job`/`all`) |
| Contraste de estados | `documento_tecnico.md`, `estado_proyecto.md`, `requerimientos.md`, `entornos_globales.md`, `propuesta_v3.md` |

### 2.4 Filtro adversarial: 7 candidatos descartados

| Candidato | Razón del descarte |
|---|---|
| §6.2 no lista `OrderStatusChanged` pese a que el diseño dice que cada transición lo emite | El diseño no precisa si es evento on-chain indexable o de aplicación y `chain_events.event_name` es texto libre; sin contradicción verificable |
| CU-19 (soporte) sin endpoint en §6.1 ni tabla en el esquema | Cubierto por la decisión abierta Q16 (`documento_tecnico.md:253`; `casos_uso.md:905`); no es defecto mientras siga abierta |
| CU-06 (recuperación 4-eyes) sin endpoints de aprobación en §6.1 | §6.1 declara «endpoints principales (por suite)», no contrato exhaustivo; el flujo sí está exigido en CU-06 |
| `sc/deployments/31337-<ts>-v3.json` no existe en el repositorio | Es el artefacto objetivo de C0/C3; el documento no declara implementados los contratos v3. No es afirmación de estado actual |
| «8 roles»/9 columnas y `session_role` sin Fiador | Ya registrado como F-09 en `INFORME_CIERRE_V3_2.md` §6.2; además Fiador es un claim (`casos_uso.md:17`), no un `session_role` |
| Auditor y Soporte comparten wallet semilla | Semilla de desarrollo declarada; rotación obligatoria en C0 con gate de CI (H-11) |
| CU-28 (indexar) sin endpoint HTTP en §6.1 | El indexer se invoca como Cloud Run Job por Scheduler (`entornos_globales.md:109`); no requiere endpoint |

**Resultado del filtro:** 14 hipótesis contrastadas → **7 supervivientes** y **7 descartadas**. Los
descartes no se incorporan como hallazgos en la sección 6.

---

## 3. Cobertura y trazabilidad (componentes, CU, RF)

### 3.1 Recuento estructural

| Artefacto | Universo | Cobertura verificada |
|---|---|---|
| Componentes internos (§3.3) | 8 | 8/8 con responsabilidad y estado; **0/8 con columnas de ciclo y dueño** (el ciclo es inferible de §4/§11, no está declarado en §3.3) |
| Contratos (§4) | 14 | 14/14 con red, responsabilidad y ciclo; **0/14 con dueño** |
| Casos de uso | 29 | 29/29 aparecen al menos una vez en la matriz §9 |
| Requerimientos funcionales | 31 | **29/31** en la matriz: faltan RF-V3-26 y RF-V3-28 |
| Requerimientos no funcionales | 14 | Citados por referencia (RNF-V3-02, -06, -12); sin matriz NFR propia |
| Requerimientos técnicos | 8 | Referenciados en §8 (RT-V3-06, -07); RT-V3-03 desincronizado (H-07) |
| Tablas | 27 | 27/27/27 SQL = diccionario = ER |
| Enums | 13 | 13/13 en el DDL |

### 3.2 CU ↔ componente

La matriz asigna componente a todos los CU mediante rangos (`CU-03…CU-06`, `CU-07…CU-14`,
`CU-15…CU-19`, `CU-20…CU-25`, `CU-26…CU-29`). La cobertura nominal es completa, pero la asignación
**RF ↔ CU** es defectuosa:

- **CU-16** aparece dentro del rango Admin `CU-15…CU-19`, pero sus RF (`RF-V3-20`, `RF-V3-25`, según
  `casos_uso.md:879`) no figuran en ninguna fila cuyo rango de CU incluya CU-16.
- **RF-V3-22** aparece en la fila Admin (`documento_tecnico.md:204`), pero `casos_uso.md:881` lo mapea
  únicamente a **CU-09** (fila API Issuer).

### 3.3 RF ↔ componente

| RF | Estado en §9 | Comentario |
|---|---|---|
| RF-V3-01…-25, -27, -29, -30, -31 | Presente | Trazados a componente y, en su mayoría, a CU |
| **RF-V3-26** (migración v2→v3) | **Ausente** | `casos_uso.md:885` lo justifica como no-CU; el documento técnico no recoge la justificación ni le asigna componente/ciclo (H-02) |
| **RF-V3-28** (asistencia guiada) | **Ausente** | `casos_uso.md:887` lo declara transversal de CU-01…CU-04; el documento técnico no lo recoge (H-02) |
| RF-V3-21 (firma legible) | Presente en fila `wallet-messages` | La fila atribuye 6 CU, pero el catálogo solo cubre 7 procesos y no incluye el consentimiento del fiador de CU-07 (H-04) |

### 3.4 Componentes ↔ ciclo

Los ciclos están asignados en §4 (contratos) y §11 (plan C0–C6), y son verificables y coherentes. El
**dueño nominal** no existe en ninguna tabla del documento: la palabra «dueño» solo aparece en el
enunciado del criterio §12.1 (`documento_tecnico.md:242`). Esto no impide implementar, pero **sí
impide verificar el criterio de aceptación 1** (H-03).

---

## 4. Completitud técnica (arquitectura, contratos, API, datos, seguridad, despliegue)

### 4.1 Tabla de huecos por dominio

| Dominio | Qué está cubierto y verificado | Hueco confirmado | Severidad |
|---|---|---|---|
| **Arquitectura** | C4 contexto y contenedores; 3 suites; shell; jobs; indexer; BD; Anvil; Secret Manager; región y proyecto | El diagrama de contexto contiene una pregunta abierta y un nodo `S3` para un servicio que el propio documento declara inexistente (H-06) | BAJA |
| **Contratos** | 14 contratos con red, responsabilidad y ciclo; fuente de ABIs en `sc/deployments/31337-<ts>-v3.json`; gate anti-deriva; hooks de compliance | Falta dueño por contrato (H-03); los contratos v3 aún no implementados es riesgo asumido por ciclo (R-1), no defecto documental | MEDIA |
| **API y eventos** | Endpoints por suite; convenciones `{success,data}`; códigos 401/403/404/409/422/503; 14 eventos indexados con `chain_id`, `block_hash`, `removed` | Sin hueco verificable. Decisiones abiertas Q16/Q18 afectan alcance, no completitud actual | — |
| **Datos** | 27 tablas en 5 dominios; 13 enums; reglas de integridad (firma+verificación+emisor, anti-autoaprobación, 4-eyes, fail-closed, tx_hash únicos, tope de precio, retención) | Catálogo `wallet_messages` de 7 procesos no cubre la firma EIP-712 de consentimiento/revocación de fianza de CU-07 (H-04); migración RF-V3-26 sin componente/ciclo en §9 (H-02) | MEDIA |
| **Seguridad** | SIWE, cookie endurecida, autorización por `role_assignments` + claims, segregación Operador/Admin, 4-eyes, AES-256-GCM, retención, Secret Manager, no-custodial, compliance on-chain, DPIA/legal | R-7 remite a «P3» sin definir; «rate limiting» no existe como RNF; el criterio §12.4 queda nominal para ese riesgo (H-05) | BAJA |
| **Despliegue** | Cloud Run/Jobs/Scheduler, Cloud SQL, Anvil, secretos, CI de 9 jobs y `deploy_gcp.sh` con los 5 modos citados; artefacto de despliegue v3 como objetivo de C0/C3 | Sin hueco verificado: los artefactos citados existen y contienen lo que el documento afirma | — |
| **Criterios del propio documento (§12)** | 5 criterios formulados; 3, 4 y 5 razonablemente satisfechos | Criterio 1 (dueño/ciclo por componente) y criterio 2 (todo RF en matriz) incumplidos; criterio 4 nominal por R-7 | MEDIA |

### 4.2 Valoración de conjunto

- **Arquitectura:** completa para el nivel C4 y coherente con la infraestructura heredada de la v2;
  no hay contradicciones de despliegue ni de red. El único defecto es editorial (H-06).
- **Contratos:** la separación por ciclos (C0 token/gobernanza, C3 activos, C4 mercado, C5 roles/
  recuperación) es trazable y no promete implementación prematura.
- **API y eventos:** suficiente para una especificación de Fase 2; no se exige contrato exhaustivo y
  §6.1 lo declara explícitamente.
- **Datos:** el modelo está maduro (27/27/27, 13 enums) y las reglas de integridad están alineadas con
  el DDL. La brecha es de cobertura del catálogo de mensajes, no de esquema.
- **Seguridad:** controles bien identificados; la debilidad es de **definición de gate y de requisito**
  (R-7), no de diseño.
- **Despliegue:** verificado contra archivos reales; no se detectaron citas falsas.

---

## 5. Riesgos y gates: ¿tienen mitigación y etapa?

| Riesgo | Mitigación / gate declarado | ¿Etapa explícita? | Valoración |
|---|---|---|---|
| R-1 Contratos v3 no implementados | C3/C4 + auditoría externa antes de piloto | Sí | Correcto |
| R-2 Atomicidad NFT↔BRLT | Spec §1.2 de diseño + tests de contrato en C4 | Sí | Correcto |
| R-3 Jobs cloud no aprovisionados | C0 (infra) + C1 (purga) | Sí | Correcto |
| R-4 Región BD vs apps | Medir p95 en C0; mover apps si incumple | Sí | Correcto |
| R-5 DPIA/legal pendientes | Gate C1/piloto (RNF-V3-12) | Sí | Correcto |
| R-6 Reorg/reset de Anvil | `block_hash`/`removed` + runbook | Sí (operativo) | Correcto |
| **R-7 Threat model y rate limiting** | **«gate antes de piloto (P3)»** | **No: P3 sin definir** | **Nominal** — H-05 |
| R-8 Restore drill y rotación de clave | Gate antes de C0/piloto (B8) | Sí (backlog B8) | Correcto |

**Conclusión de la sección:** **7 de 8 riesgos** tienen mitigación y etapa identificables. **R-7** no
define la escala «P», colisiona con dos acepciones distintas de P3 en los informes de cierre
(`INFORME_CIERRE_V3_1.md:242`: implementación; `INFORME_CIERRE_V3_2.md:222`: verificación en CI) y no
tiene RNF asociado, de modo que el criterio §12.4 no es verificable para ese riesgo. Los gates de los
ciclos C0–C6, en cambio, sí son verificables (evidencia reproducible + sin ALTAS abiertas, §11).

---

## 6. Hallazgos abiertos por severidad

> Los 7 hallazgos siguientes son los únicos supervivientes de la verificación adversarial. No se
> incluyen los 7 candidatos descartados (§2.4) ni defectos ya registrados en informes previos.

### 6.1 H-01 — ALTA — El estado de la Fase 1 es contradictorio entre artefactos (y dentro de dos de ellos) tras Q14a

- **Área:** Estado y gobernanza documental.
- **Evidencia:** `documento_tecnico.md:5` cita Q14a como «Fase 1 cerrada como baseline de diseño»;
  `estado_proyecto.md:4`, `:146` y `:192` la declaran CERRADA; pero `requerimientos.md:4` y
  `entornos_globales.md:3` siguen afirmando «Fase 1 en corrección (re-auditoría v3.2: NO cerrada)».
  Hay contradicción interna: `estado_proyecto.md:188` dice «La Fase 1 sigue en corrección» en la misma
  página que `:4` y `:192`; `propuesta_v3.md:432-435` afirma «La Fase 1 sigue en corrección… solo con
  14/14 CUMPLE… se pasa a Fase 2», justo después de la nota Q14a de `:426-428` que declara cerrada la
  Fase 1 y desbloqueada la Fase 2.
- **Impacto:** un lector o un chequeo automático no puede determinar el estado vigente. Es recurrencia
  del criterio «estado único» (B10/C4) que la corrección F-02 decía haber cerrado. Afecta la premisa
  declarada del documento técnico (Q14a) y, por tanto, la base de cierre de Fase 2.
- **Recomendación:** fijar Q14a como estado único y corregir esas cuatro ubicaciones (o marcar §8 de
  `estado_proyecto.md` y los pasos 3–4 de `propuesta_v3.md` como históricos). Añadir al chequeo de
  artefactos una verificación del literal de estado «Fase 1» para impedir recaídas.

### 6.2 H-02 — MEDIA — La matriz §9 no satisface el criterio 2 de §12: omite RF-V3-26 y RF-V3-28 y atribuye RF-V3-22 a CU-15…CU-19

- **Área:** Trazabilidad CU/componente/RF.
- **Evidencia:** `documento_tecnico.md:243` exige que todo RF aparezca al menos una vez en la matriz
  §9, pero el barrido de sus 11 filas (`documento_tecnico.md:201-211`) no contiene **RF-V3-26**
  (migración v2→v3) ni **RF-V3-28** (asistencia guiada); `casos_uso.md:885` y `:887` sí los justifican
  como no-CU/transversales, pero el documento técnico no recoge esa justificación ni les asigna
  componente y ciclo. Además, la fila «API Admin | CU-15…CU-19» (`documento_tecnico.md:204`) incluye
  RF-V3-22, que `casos_uso.md:881` mapea únicamente a CU-09; y CU-16, dentro de ese rango, tiene
  RF-V3-20 y RF-V3-25 (`casos_uso.md:879`) que no figuran en ninguna fila cuyo rango de CU incluya
  CU-16.
- **Impacto:** el documento incumple su propio criterio de aceptación 2. La cobertura nominal de
  29/29 CU oculta que dos RF transversales no tienen componente/ciclo y que una atribución es errónea.
- **Recomendación:** añadir a §9 las filas/notas de RF-V3-26 (migración; componente script/ETL; ciclo
  C0) y RF-V3-28 (asistencia guiada; componente UI; ciclos C1–C3), y alinear las filas con la matriz
  CU↔RF de `casos_uso.md` (RF-22→CU-09; RF-20/25 correspondientes a CU-16).

### 6.3 H-03 — MEDIA — El criterio 1 de §12 (responsabilidad, ciclo y dueño por componente) no se cumple en las tablas §3.3 y §4

- **Área:** Criterios de aceptación del documento.
- **Evidencia:** `documento_tecnico.md:242` exige que todo componente tenga «responsabilidad, ciclo y
  dueño declarado», pero la tabla de componentes §3.3 (`documento_tecnico.md:95-102`) solo tiene las
  columnas Componente | Responsabilidad | Estado (sin ciclo ni dueño) y la tabla de contratos §4
  (`documento_tecnico.md:106-121`) tiene Ciclo pero ningún dueño. La palabra «dueño» solo aparece en el
  enunciado del propio criterio (`:242`).
- **Impacto:** el documento no permite verificar su criterio de aceptación 1; la trazabilidad de
  responsabilidad nominal queda incompleta para la Fase 3.
- **Recomendación:** añadir las columnas **Ciclo** y **Dueño** a §3.3 (y **Dueño** a §4), o reformular
  el criterio 1 si la propiedad no se va a declarar en este documento (con decisión del sponsor).

### 6.4 H-04 — MEDIA — El catálogo wallet_messages de 7 procesos no cubre los CU que §9 le atribuye: el consentimiento EIP-712 del fiador (CU-07) queda sin plantilla

- **Área:** Cobertura RF-21 (mensajes de firma legibles).
- **Evidencia:** `documento_tecnico.md:165` declara un catálogo de 7 procesos y `:210` asigna
  `packages/wallet-messages` a CU-02, CU-04, CU-07, CU-10, CU-21 y CU-22. Los 7 `process_key`
  realmente sembrados son `identity.create`, `claim.request`, `claim.issue`, `asset.tokenize`,
  `order.buy`, `service.consume` e `identity.recovery` (`base_datos.sql:1424-1470`): ninguno cubre el
  «consentimiento (EIP-712)» del Fiador exigido por CU-07 (`casos_uso.md:262`), que §9 da por
  cubierto; y CU-02/CU-22 figuran en la fila sin proceso asociado. En consecuencia, el gate de C5
  «100 % procesos con mensaje legible» (`documento_tecnico.md:235`) no es verificable con este
  catálogo y RF-V3-21 quedaría incompleto para una firma real del flujo de tokenización.
- **Impacto:** el requisito de legibilidad de firmas no cubre una firma de consentimiento con efecto
  legal/económico (fianza), y el gate de C5 no es medible contra el catálogo real.
- **Recomendación:** definir el proceso de firma de consentimiento/revocación de fianza (nuevo
  `process_key` `es`/`en` en `wallet_messages`) o retirar CU-07 de la fila §9; alinear la fila con los
  7 procesos reales y con todos los CU que firman EIP-712.

### 6.5 H-05 — BAJA — El gate «P3» del riesgo R-7 no está definido y colisiona con dos definiciones distintas del registro de auditoría

- **Área:** Riesgos técnicos.
- **Evidencia:** la tabla de riesgos remite R-7 («Threat model y rate limiting») a «gate antes de
  piloto (P3)» (`documento_tecnico.md:223`) sin definir la escala P en ningún punto del documento. En
  el registro de auditoría, P3 significa dos cosas distintas: «threat model STRIDE + rate limiting…
  implementados» (`INFORME_CIERRE_V3_1.md:242`) y «verificación en CI»
  (`INFORME_CIERRE_V3_2.md:222`). Además, «rate limiting» no existe como RNF en `requerimientos.md`,
  por lo que el riesgo no tiene requisito asociado que lo cierre y el criterio §12.4 (riesgos con
  mitigación y gate) queda nominal.
- **Impacto:** riesgo sin criterio de cierre verificable; ambigüedad de nomenclatura de gates.
- **Recomendación:** sustituir «P3» por la referencia explícita al gate de piloto (p. ej. G-Piloto.2
  de `INFORME_CIERRE_V3_1`) y añadir el RNF de rate limiting/threat model o declarar el control fuera
  de alcance con dueño y fecha.

### 6.6 H-06 — BAJA — Pregunta abierta incrustada en el diagrama C4 de contexto (§3.1)

- **Área:** Arquitectura / calidad editorial.
- **Evidencia:** el diagrama de contexto contiene literalmente el nodo
  `S3[Cloud Storage de documentos? no: cifrado en BD]` (`documento_tecnico.md:63`): una duda de diseño
  dentro de una especificación declarativa, con la etiqueta «S3» (Cloud Storage) para un elemento que
  §7 (`:177`) declara inexistente porque los documentos se cifran en la BD.
- **Impacto:** un diagrama técnico no debe contener preguntas abiertas (su lugar es §13) ni nombrar un
  servicio descartado; induce a error sobre la arquitectura de almacenamiento.
- **Recomendación:** eliminar el nodo o renombrarlo «documentos KYC cifrados en BD» y trasladar
  cualquier duda pendiente a §13 (preguntas abiertas).

### 6.7 H-07 — BAJA — RT-V3-03 sigue dejando «a confirmar en Fase 2» el estándar de servicios y admite ERC-1155, ya resuelto como ERC-721 en el documento técnico

- **Área:** Requerimientos / sincronización Fase 2.
- **Evidencia:** `requerimientos.md:113` mantiene «ERC-1155 para productos/servicios por cantidad (a
  confirmar en Fase 2)», mientras que el documento técnico de Fase 2 resuelve «servicios (ERC-721
  quemable)» y ERC-1155 solo para productos (`documento_tecnico.md:21`, `:112-114`), en línea con los
  hooks de `diseno_cierre_v3_2.md:169`.
- **Impacto:** el artefacto de requerimientos no refleja la decisión tomada en su propia Fase 2 y deja
  ambigüedad de estándar para C3 (un servicio con cantidades podría implementarse como 1155 en contra
  del diseño).
- **Recomendación:** actualizar RT-V3-03 (servicios = ERC-721 quemable; productos = ERC-1155; bienes =
  ERC-721) y eliminar el «a confirmar en Fase 2» una vez decidido.

---

## 7. Correcciones concretas al documento técnico (lista accionable)

> Las correcciones C-01 a C-04 son bloqueantes de cierre de Fase 2. Algunas tocan artefactos
> sincronizados (`requerimientos.md`, `entornos_globales.md`, `estado_proyecto.md`, `propuesta_v3.md`,
> `base_datos.sql`) porque el criterio de estado único y la trazabilidad RF dependen de ellos.

### P0 — Bloqueantes de cierre de Fase 2

- [ ] **C-01 (H-01, ALTA):** fijar Q14a como estado único de Fase 1 y corregir `requerimientos.md:4`,
  `entornos_globales.md:3`, `estado_proyecto.md:188` y `propuesta_v3.md:432-435`; marcar como
  históricos §8 de `estado_proyecto.md` y pasos 3–4 de `propuesta_v3.md`. Añadir al script
  `verificar_artefactos.py` una comprobación del literal de estado «Fase 1» para impedir recaídas.
- [ ] **C-02 (H-02, MEDIA):** añadir a §9 las filas/notas de **RF-V3-26** (migración; script/ETL;
  ciclo C0) y **RF-V3-28** (asistencia guiada; UI; ciclos C1–C3). Corregir la fila Admin
  (`documento_tecnico.md:204`): RF-V3-22 → CU-09 (fila API Issuer) y añadir RF-V3-20/RF-V3-25 a la
  fila que cubra CU-16.
- [ ] **C-03 (H-03, MEDIA):** añadir columnas **Ciclo** y **Dueño** a la tabla §3.3
  (`documento_tecnico.md:95-102`) y **Dueño** a la tabla §4 (`:106-121`); si el sponsor no quiere
  declarar dueños en este documento, reformular el criterio §12.1 y dejar constancia de la decisión.
- [ ] **C-04 (H-04, MEDIA):** definir el `process_key` de consentimiento/revocación de fianza en
  `base_datos.sql` (`wallet_messages`, `es`/`en`) o retirar CU-07 de la fila §9; alinear la fila
  `packages/wallet-messages` con los 7 procesos reales y con todos los CU que firman EIP-712.

### P1 — Correcciones de la misma pasada

- [ ] **C-05 (H-05, BAJA):** sustituir «P3» en §10 R-7 por la referencia explícita al gate de piloto
  (p. ej. G-Piloto.2 de `INFORME_CIERRE_V3_1.md:242`); añadir el RNF de rate limiting/threat model a
  `requerimientos.md` o declarar el control fuera de alcance con dueño y fecha.
- [ ] **C-06 (H-06, BAJA):** eliminar del diagrama §3.1 el nodo `S3[...]` o renombrarlo «documentos KYC
  cifrados en BD»; trasladar cualquier duda abierta a §13.
- [ ] **C-07 (H-07, BAJA):** actualizar `requerimientos.md:113` (RT-V3-03) a la decisión de Fase 2:
  servicios = ERC-721 quemable; productos = ERC-1155; bienes = ERC-721; retirar «a confirmar en Fase 2».

### P2 — Endurecimiento de la verificación

- [ ] **C-08:** incorporar al script de artefactos las comprobaciones de: (a) todos los RF de
  `requerimientos.md` presentes en §9; (b) todos los `process_key` de `wallet_messages` cubiertos por
  §9 y viceversa; (c) todo componente con ciclo y dueño (o excepción documentada); (d) estado único
  de Fase 1 en los cinco documentos.
- [ ] **C-09:** al corregir, re-ejecutar `verificar_artefactos.py` y dejar evidencia en un acta; no
  declarar Fase 2 cerrada hasta que H-01…H-04 estén corregidos y verificados.

**Criterio de aceptación de las correcciones:** el documento y los cuatro artefactos sincronizados
deben pasar el script ampliado, con 0 contradicciones de estado, 31/31 RF en §9, 8/8 componentes y
14/14 contratos con dueño (o excepción aprobada), y catálogo de mensajes alineado 1:1 con los CU de
firma EIP-712.

---

## 8. Preguntas para el sponsor

Las preguntas Q15–Q18 ya figuran en `documento_tecnico.md:250-255` y se mantienen vigentes. Se añaden
las siguientes, derivadas exclusivamente de los hallazgos anteriores:

| # | Pregunta | Origen | Impacto si no se responde |
|---|---|---|---|
| Q19 | ¿Se ratifica Q14a como estado único de la Fase 1 y se autoriza corregir `requerimientos.md`, `entornos_globales.md`, `estado_proyecto.md` y `propuesta_v3.md`? | H-01 | La Fase 2 se cerraría sobre una premisa de estado contradictoria |
| Q20 | ¿El threat model y el rate limiting son RNF exigibles antes del piloto, o se aceptan como control fuera de alcance con dueño y fecha? | H-05 | R-7 queda sin criterio de cierre verificable |
| Q21 | ¿El consentimiento y la revocación de fianza (CU-07) requieren firma EIP-712 con mensaje legible en C5, o se acepta otro mecanismo? | H-04 | El catálogo de mensajes y el gate de C5 no serían verificables |
| Q22 | ¿El documento técnico debe declarar un dueño nominal por componente/contrato, o la propiedad se delega al plan de ciclos C0–C6? | H-03 | El criterio §12.1 no es verificable y el documento no puede cerrarse por sus propios criterios |
| Q23 | ¿Se confirma la decisión de estándares (servicios = ERC-721 quemable; productos = ERC-1155; bienes = ERC-721) para actualizar RT-V3-03? | H-07 | Ambigüedad de estándar para la implementación de C3 |
| Q24 | ¿Se aceptan RF-V3-26 (migración) y RF-V3-28 (asistencia guiada) como transversales sin CU, con componente y ciclo asignados en §9? | H-02 | El criterio §12.2 seguiría incumplido |

---

## 9. Firma: contadores y artefactos auditados

### 9.1 Contadores de la auditoría

| Métrica | Valor |
|---|---|
| Actas de revisión recibidas | **2** (ambas vacías: 0 candidatos) |
| Hallazgos de entrada | **0** |
| Hipótesis contrastadas en verificación adversarial | **14** |
| Hallazgos supervivientes | **7** |
| — CRÍTICAS | **0** |
| — ALTAS | **1** (H-01) |
| — MEDIAS | **3** (H-02, H-03, H-04) |
| — BAJAS | **3** (H-05, H-06, H-07) |
| Candidatos descartados | **7** |
| Criterios de aceptación §12 cumplidos | **3/5** (3, 4 y 5; 4 nominal en R-7) |
| Artefactos núcleo auditados | **8** |
| Artefactos de soporte contrastados | **4** |

### 9.2 Artefactos núcleo auditados (8)

| # | Artefacto | Rol en la auditoría |
|---|---|---|
| 1 | `RepoTecnico/documento_tecnico.md` (259 líneas) | Objeto auditado |
| 2 | `RepoTecnico/casos_uso.md` | Fuente de CU y matriz CU↔RF |
| 3 | `RepoTecnico/requerimientos.md` | Fuente de RF/RNF/RT y estado |
| 4 | `RepoTecnico/base_datos.sql` | DDL, enums y semillas `wallet_messages` |
| 5 | `RepoTecnico/diseno_cierre_v3_2.md` | Hooks, atomicidad y gates de diseño |
| 6 | `RepoTecnico/estado_proyecto.md` | Estado de Fase 1 y compuerta |
| 7 | `RepoTecnico/entornos_globales.md` | Infraestructura, CI y rutas |
| 8 | `RepoTecnico/propuesta_v3.md` | Decisiones Q1–Q14a y estado |

### 9.3 Artefactos de soporte contrastados (4)

| # | Artefacto | Uso |
|---|---|---|
| 1 | `RepoTecnico/INFORME_CIERRE_V3_1.md` | Registro de gates P1–P8 y definición de P3 |
| 2 | `RepoTecnico/INFORME_CIERRE_V3_2.md` | Defectos ya registrados (F-01…F-10), compuerta y P3 |
| 3 | `rwa-sc/.gitlab-ci.yml` | Verificación de los 9 jobs de CI citados |
| 4 | `rwa-web/scripts/deploy_gcp.sh` | Verificación de los modos `provision\|build\|deploy\|scheduler\|verify` |

### 9.4 Comprobaciones mecánicas registradas

- **27/27/27** tablas SQL = diccionario = ER; **0** discrepancias de columnas.
- **13** enums del esquema `rwa`.
- **7** procesos de `wallet_messages` × **2** locales = **14** plantillas.
- **11** filas de la matriz §9 barridas contra **29** CU y **31** RF.
- **9** jobs en `.gitlab-ci.yml`; **5** modos citados presentes en `deploy_gcp.sh`.
- **8** riesgos R-1…R-8; **7/8** con gate y etapa verificables.
- **6** ciclos C0–C6 con criterios de salida.

### 9.5 Limitaciones y firma

- Esta auditoría es **documental**: no ejecuta la plataforma, no despliega contratos, no corre E2E ni
  acredita operación. Los criterios de implementación pertenecen a los gates C0–C6.
- No se re-auditaron los 7 candidatos descartados (§2.4); su descarte se basa en duda razonable o en
  estar ya registrados, conforme a la regla de la verificación adversarial.
- El veredicto **SÍ CON CORRECCIONES** se emite con los contadores anteriores y queda condicionado a
  las correcciones C-01 a C-04 y a la decisión del sponsor sobre Q19–Q24.

**Firmado:** Sintetizador de la auditoría documental — RWA v3 · 2026-11-04

---

*Fin del informe — `AUDITORIA_DOCUMENTO_TECNICO.md` · 7 hallazgos abiertos (1 ALTA, 3 MEDIA, 3 BAJA) ·
8 artefactos núcleo auditados.*
