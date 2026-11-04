# Estado del Proyecto — RWA v3 «Barlo Metaplace»

> **Última actualización:** 2026-11-04 · **Fase actual:** 3 (Desarrollo) — **plan propuesto, pendiente de aprobación para arrancar C0** · Fase 2 ✅ cerrada
> **Estado de la Fase 1:** ✅ **CERRADA COMO BASELINE DE DISEÑO** (decisión **Q14a**, 2026-11-04).
> Implementación y operación se controlan con los gates de **C0–C6** (Fase 3).
> **Carpeta de reportes:** `RWA/RepoTecnico/` (v3) · **Documentación v2:** `rwa-sc/RepoTecnico/` y `rwa-web/RepoTecnico/`

## 1. Resumen

| Campo | Valor |
|---|---|
| Proyecto | RWA v3 «Barlo Metaplace» |
| Entrada | `RepoTecnico/BRIEF_BARLOBLOKCHAIN_v3.md` (32 líneas) |
| Base heredada | RWA v2 desplegada en GCP (`mcc-ecommerce`, `europe-west1`): 3 apps + indexer + Anvil + Cloud SQL |
| Respaldo de partida | `/home/dsh/workspace/backups/rwa-v2-backup-20261031T171645Z.zip` (105 MB, SHA-256 en el manifiesto) |
| Esquema de datos | `rwa` **27 tablas** · esquema **3.0** · revisión documental **v3.2** · 31 RF / 15 RNF |
| Compuerta de cierre | **Baseline de diseño: CUMPLE** (Q14a) · implementación: gates C0–C6 |

## 2. Artefactos

| Artefacto | Estado | Contenido |
|---|---|---|
| `requerimientos.md` | ✅ v3.2 | **31 RF · 15 RNF · 8 RT**; supuestos **S-1…S-14** |
| `propuesta_v3.md` | ✅ v3.1 | Lectura del brief, brechas v2, arquitectura, 7 ciclos, riesgos |
| `diccionario_datos.md` | ✅ v3.2 | 27 tablas, tipos, claves, reglas de integridad |
| `diagrama_er.md` | ✅ v3.2 | Mermaid, 5 bloques, 27/27 entidades |
| `base_datos.sql` | ✅ v3.2 | PostgreSQL 15: 27 tablas, 13 enums, triggers, jobs y semillas |
| `migracion_v2_a_v3.sql` | ✅ v3.1 | Archiva 12 tablas v2, ETL y registro `3.0` transaccional |
| `entornos_globales.md` | ✅ v3.1 | Rutas, repos, GCP, BD, variables, toolchain y deuda operativa |
| `verificar_artefactos.py` | ✅ | Script de CI: SQL, cuadre tablas/columnas, Mermaid, versión, recuentos |
| `diseno_cierre_v3_2.md` | ✅ | Diseño B3 (escrow), B5 (RBAC), B6 (compliance), B7 (retención), B8 (operación) y B9 (RNF) |
| `casos_uso.md` | ✅ v3.2 | **29 casos de uso** Gherkin/EARS con trazabilidad a RF-V3 |
| `casos_uso/diagramas_casos_uso.md` | ✅ v3.2 | Diagrama de casos de uso + 6 secuencias + estados (Mermaid) |
| `casos_uso/AUDITORIA_CASOS_USO.md` | ✅ v3.2 | Auditoría de CU: veredicto **SÍ**, 0 hallazgos, 14 correcciones aplicadas |
| `documento_tecnico.md` | ✅ v3.2 | Arquitectura, contratos, API, datos, seguridad, despliegue, riesgos y plan C0–C6 |
| `AUDITORIA_DOCUMENTO_TECNICO.md` | ✅ v3.2 | Auditoría del documento técnico: **SÍ CON CORRECCIONES** (1 ALTA, 3 MEDIAS, 3 BAJAS → corregidas) |
| `plan_desarrollo.md` | ✅ v3.2 | **Fase 3**: 7 ciclos C0–C6 con tareas, gates, DoD y calendario (~17–18 semanas) |
| `pruebas/validacion_ejecucion_v3_1.md` | ✅ | Acta de ejecución real: migración (B1) + 16 smoke tests (B2) |
| `INFORME_OPTIMIZACION_V3.md` | 📜 Histórico | 44 hallazgos de la 1ª auditoría |
| `INFORME_CIERRE_V3_1.md` | 📜 Vigente | Re-auditoría de cierre: veredicto NO + compuerta de 14 criterios + B1–B12 |

## 2.1 Repositorios, ramas y publicación (2026-11-02)

| Repo | Rama | Commit | Remotos con la rama |
|---|---|---|---|
| `rwa-sc` (contratos/datos) | `rwa-web-DSH-GCP-v3` | `4c09fc8` | GitLab.com · GitHub · CodeCrypto |
| `rwa-web` (web) | `rwa-web-DSH-GCP-v3` | `5bcfb72` | GitLab.com · GitHub · CodeCrypto |

- Ramas v2 (`rwa-sc-DSH-GCP`, `rwa-web-DSH`) y `main`: intactas y congeladas.
- Credencial de CodeCrypto: token único en `~/.config/gitlab/codecrypto.token` (0600) + helper global;
  **ningún secreto en los repositorios**.
- El canónico documental sigue siendo `rwa-sc/RepoTecnico/v3/`; `rwa-web` espeja los 4 artefactos de datos.

## 3. Decisiones tomadas

| ID | Decisión | Estado |
|---|---|---|
| D-V3-01 | **Q1:** v3 sustituye a v2 sobre la misma infraestructura (rama `rwa-web-DSH-GCP-v3`); v2 congelada | ✅ |
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
| D-V3-16 | **Q14a:** la compuerta de Fase 1 se redefine como **baseline de diseño verificada**; los criterios que dependen de implementación (C7, C13, C14) pasan a **gates de C0–C6** | ✅ Aprobada |
| D-V3-17 | **Q15:** asistencia guiada como **wizard de 4 pasos** | ✅ |
| D-V3-18 | **Q16:** soporte **in-app** con SLA 24 h | ✅ |
| D-V3-19 | **Q17:** claim de JURISDICCIÓN **diferido** | ✅ |
| D-V3-20 | **Q18:** exportación de auditoría **solo metadatos** | ✅ |
| D-V3-21 | **Q19:** **Q14a ratificada** como estado único | ✅ |
| D-V3-22 | **Q20:** threat model + rate limiting **exigibles antes del piloto** (RNF-V3-15) | ✅ |
| D-V3-23 | **Q21:** consentimiento de fianza con **firma EIP-712 legible** | ✅ |
| D-V3-24 | **Q22:** **dueño nominal** por componente/contrato | ✅ |
| D-V3-25 | **Q23:** servicios ERC-721 quemable · productos ERC-1155 · bienes ERC-721 | ✅ |
| D-V3-26 | **Q24:** RF-26 y RF-28 **transversales sin CU** | ✅ |

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

## 5.1 Re-auditoría FINAL v3.2 (`INFORME_CIERRE_V3_2.md`, 2026-11-04)

- Compuerta: **2 CUMPLE (C2, C8) · 11 PARCIAL · 1 NO CUMPLE (C14)**; **9 criterios bloquean**.
- B1–B12: 2 CERRADO (B2, B9) · 6 DISEÑO (B3–B8) · 4 ABIERTO (B1, B10, B11, B12).
- **Veredicto: NO** — la Fase 1 no se cierra; lo pendiente es mayoritariamente **implementación**
  (contratos v3, jobs cloud, E2E, RBAC API, restore drill, DPIA) más 3 ALTAS documentales nuevas.
- Hallazgos nuevos verificados: **F-01** (pérdida silenciosa de `token_required_claims` en el ETL),
  **F-02** (documentos que certificaban un cierre no verificado), **F-03** (script de verificación
  incompleto y fuera de CI), más 6 MEDIAS y 1 BAJA.

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

## 6.1 Correcciones de la re-auditoría final (2026-11-04)

| ID | Corrección | Evidencia |
|---|---|---|
| **F-01** | ETL §4.7 aplica el alias canónico `ACCREDITATION/JURISDICTION` y §6 verifica `token_required_claims` y conteo de documentos | `migracion_v2_a_v3.sql` §4.7, §6 |
| **F-02** | Estado/cifras unificados: diccionario, entornos, propuesta y requerimientos ya no certifican cierre; 27 tablas, v3.2, S-1…S-14, S-3 con dueño y fecha | 4 documentos |
| **F-03** | `verificar_artefactos.py` valida **trazabilidad brief↔RF** y **coherencia de estado/cifras**; job `artefactos-v3` añadido al CI (rama `rwa-web-DSH-GCP-v3`) | script + `rwa-sc/.gitlab-ci.yml` |
| **F-04** | La BD rechaza confirmar una orden sin los dos tramos del escrow (BRLT + NFT) | `trg_validate_order_transition`; prueba 20/21 del acta |
| **F-05** | Retención de `asset_documents` al vender + purga cuenta ambas tablas | `trg_asset_retention_on_sale`, `purge_expired_documents()`; prueba 22 |
| **F-06** | §5.3 de la propuesta con los nombres reales del esquema (sin tablas inventadas) | `propuesta_v3.md` §5.3 |
| **F-07** | El ETL conserva el **hash original** de los documentos (no el del blob cifrado) | `migracion_v2_a_v3.sql` §4.5 |
| **F-09** | Matriz RBAC aclarada (Visitante + 8 roles) | `diseno_cierre_v3_2.md` §2.2 |
| **F-10** | Cabecera duplicada «## 10» corregida | `entornos_globales.md` |
| **N-08/N-07** | Limitación documentada: claims migrados marcados `legacy_unverified`; verificador sintético documentado en el acta | acta v3.2 |

> **F-08** (verificador sintético en claims migrados) y **N-08** quedan como limitación documentada de
> la migración (no como dato verificado nativo); se resolverán reverificando en C0.

## 6.2 Cierre de la Fase 1 como baseline de diseño (Q14a, 2026-11-04)

La re-auditoría final (`INFORME_CIERRE_V3_2.md`) mostró que la compuerta de 14 criterios **mezcla diseño
con implementación**. Con la decisión **Q14a** del sponsor:

| Ámbito | Criterios | Estado |
|---|---|---|
| **Diseño/documentación verificada (Fase 1)** | C1, C2, C3 (diseño), C4, C5 (diseño+DDL), C6, C8, C9 (DDL), C10 (modelo), C11, C12 | ✅ **CUMPLE como baseline** (con las correcciones F-01…F-10) |
| **Implementación (Fase 3)** | C7 (contratos/hook on-chain), C13 (operación ejecutada), C14 (ejecución completa: E2E, restore drill, DPIA, alertas) | 🔒 **Gates de C0–C6** (ver `diseno_cierre_v3_2.md` §0 y §7) |

**Consecuencia:** la Fase 1 queda cerrada como **línea base de diseño** y se habilita la **Fase 2**
(casos de uso + gráficos + documento técnico). Ningún entregable de implementación se declara hecho:
cada uno tiene su gate y evidencia exigida en C0–C6.

## 6.3 Fase 2 — Casos de uso (2026-11-04)

- **`casos_uso.md`:** 29 CU (uno por objetivo de actor) con flujo principal, alternativos, criterios
  Gherkin, restricciones EARS, tipo de prueba (E2E/API/DB/CONTRATO/JOB) y trazabilidad a RF-V3.
- **Actores:** Visitante, Usuario, Fiador, Operador, Emisor, Admin, Auditor, Árbitro, Soporte y Sistema.
- **`casos_uso/diagramas_casos_uso.md`:** diagrama de casos de uso (Mermaid), 6 diagramas de secuencia
  (alta/claim, compra con escrow, tokenización, disputa, recuperación 4-eyes, jobs) y máquina de estados.
- **Auditoría de CU:** veredicto **SÍ** (0 hallazgos); 14 correcciones de trazabilidad/redacción aplicadas.
- **`documento_tecnico.md`:** arquitectura (C4 contexto/contenedores), componentes con ciclo y dueño,
  14 contratos, API por suite, 27 tablas, seguridad, despliegue, riesgos y plan C0–C6.
- **Auditoría del documento técnico:** **SÍ CON CORRECCIONES** → C-01…C-07 aplicadas (estado único Q14a,
  matriz §9 31/31 RF, dueños por componente, 8 procesos de firma, gate de rate limiting, diagrama limpio,
  RT-V3-03 actualizado); C-08/C-09 verificados con el script ampliado (**PASS**).
- **Pendiente para cerrar Fase 2:** respuestas del sponsor a **Q15–Q24** (asistencia guiada, soporte,
  jurisdicción, exportación, ratificación Q14a, threat model, firma de fianza, dueños, estándares, transversales).

## 6.4 Cierre de Fase 2 y estado de Fase 3 (2026-11-04)

- **Fase 2 ✅ cerrada:** 29 CU + 8 diagramas + `documento_tecnico.md`, ambos auditados
  (CU: veredicto SÍ, 0 hallazgos; doc técnico: SÍ CON CORRECCIONES, C-01…C-09 aplicadas).
- **Q15–Q24 resueltas por defecto** (D-V3-17…D-V3-26): wizard, soporte in-app, jurisdicción diferida,
  auditoría solo metadatos, Q14a ratificada, threat model/rate limiting pre-piloto, firma de fianza
  legible, dueños, estándares ERC-721/1155 y transversales.
- **Fase 3 propuesta:** `plan_desarrollo.md` con **C0–C6** (≈17–18 semanas), gates por ciclo y DoD.
- **Siguiente:** aprobación del plan para arrancar **C0** (BarloToken + migración real en CI +
  claves dedicadas + infra de backups/jobs).

## 7. Verificación posterior (ejecutada)

| Comprobación | Resultado |
|---|---|
| `python3 RepoTecnico/verificar_artefactos.py` | ✅ **PASS** (incluye trazabilidad y coherencia de estado) |
| SQL `base_datos.sql` | ✅ 175 sentencias parseadas |
| SQL `migracion_v2_a_v3.sql` | ✅ 40 sentencias parseadas |
| Tablas y columnas | ✅ 27/27 tablas y 0 discrepancias de columnas |
| Mermaid | ✅ 5 bloques, 0 errores |
| Versión operativa | ✅ única (`3.0`) |
| Requisitos | ✅ 31 RF · 15 RNF · 8 RT · S-1…S-14 |

## 8. Compuerta de re-cierre (B1–B12) — estado real

| ID | Criterio | Estado | Qué falta |
|---|---|---|---|
| **B1** | Migración ejecutable y probada sobre `pg_dump` v2 real | 🟡 **VERIFICADO EN TEST** (falta CI con dump real) | Ejecutada en PostgreSQL 16 embebido sobre el esquema v2 canónico + datos sintéticos: `exit 0`, claims 2=2, docs 1=1, tokens 1=1 ([acta](pruebas/validacion_ejecucion_v3_1.md)). Queda repetirla en CI con el dump real |
| **B2** | DDL ejecutable (smoke `UPDATE` por tabla con trigger) | 🟢 **VERIFICADO** | **16/16 smoke tests** PASS, incluido `UPDATE orders` (N-01) y 4 pruebas negativas ([acta](pruebas/validacion_ejecucion_v3_1.md)) |
| **B3** | Escrow verificable | 🟢 **DISEÑADO** | Máquina de estados + tramo NFT + job de expiración + validaciones en DDL; implementación y pruebas en C4 |
| **B4** | Autoridad del Emisor (vínculo emisor↔programa + semillas) | 🟢 **CUBIERTO EN DDL** | E2E de alta pendiente de runtime |
| **B5** | RBAC real | 🟢 **DISEÑADO** | `role_assignments`, 8 roles, semillas por rol y `audit_log` append-only; matriz de pruebas en C5 |
| **B6** | Compliance on-chain | 🟢 **DISEÑADO** | Spec de hooks, `token_required_claims` on-chain y tests adversariales en C3 |
| **B7** | Retención Q10 ejecutable | 🟢 **DISEÑADO** | Triggers de fecha + `purge_expired_documents()` + job diario; test en C1 |
| **B8** | Operación documentada | 🟢 **DOCUMENTADO** | Backup/PITR, RPO/RTO, rotación de clave, pooling, RPC fallback y coste (entornos §9.1) |
| **B9** | RNF falsables | 🟢 **DISEÑADO** | 12 rutas (Anexo A), axe serious/critical, p95 con condiciones, pico S-14 y SLI |
| **B10** | Estado único y compuerta honesta | 🟢 **HECHO (2026-11-04)** | Estado, cifras y revisión unificados en los 7 documentos; validado por el script |
| **B11** | Trazabilidad automatizada y script en CI | 🟢 **HECHO (2026-11-04)** | Script valida §6 y coherencia; job `artefactos-v3` en `.gitlab-ci.yml` (pipeline pendiente de ejecutar en remoto) |
| **B12** | 14/14 criterios CUMPLE, 0 CRÍTICAS y 0 ALTAS | 🔴 **no cumplido** | Requiere cerrar B1–B9 y re-auditar |

**Conclusión:** la corrección eliminó los 2 defectos nuevos críticos y **B1/B2 están verificados por ejecución real**. La compuerta de diseño se cerró como **baseline (Q14a)**; lo que resta (B3–B8) son **gates de implementación de C0–C6**, no bloqueos de la Fase 1. *Sección histórica: describe el estado previo a Q14a.*

## 9. Próximos pasos

- **Fase 1:** ✅ cerrada como baseline de diseño (Q14a).
- **Fase 2 (en curso):** casos de uso Gherkin/EARS + gráficos + documento técnico.
- **Fase 3:** plan de ciclos C0–C6; cada ciclo cierra los gates de implementación (contratos, jobs, E2E,
  RBAC API, restore drill, DPIA, observabilidad).

## 10. Estado heredado de la v2 (referencia)

| Línea | Estado |
|---|---|
| Contratos (`rwa-sc`) | 16 contratos fuente; 10 desplegados en Anvil GCP (bloque 549); CI 7/7 en verde |
| Web (`rwa-web`) | 3 apps + indexer; 42 tests; E2E contra Anvil GCP en verde; Cloud Run tag `20261029-174915` |
| Datos | Esquema `rwa` v2 con **12 tablas** en Cloud SQL; migraciones 1.0–1.2 |
| Brechas v2 | RF-011/012/013, alertas del indexer, auditoría externa |
