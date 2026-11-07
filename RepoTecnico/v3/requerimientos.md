# Requerimientos — Proyecto RWA v3 «Barlo Metaplace»

> **Fuente:** `RepoTecnico/BRIEF_BARLOBLOKCHAIN_v3.md` (v3, sin fecha; 32 líneas) + arquitectura heredada de la v2.
> **Versión:** v3.2 · **Fecha:** 2026-11-04 · **Fase:** 1 (Concepto) **CERRADA como baseline de diseño** (Q14a); implementación en gates C0–C6.
> **Estado:** especificación corregida tras las auditorías (`INFORME_OPTIMIZACION_V3`, `INFORME_CIERRE_V3_1`, `INFORME_CIERRE_V3_2`).
> Los supuestos S-1…S-14 están resueltos o aceptados explícitamente (S-14 en :139).
> **Trazabilidad:** cada requerimiento enlaza la sección del brief (`[objetivo]`, `[contexto]`,
> `[procesos generales]`, `[WEB-IDENTITY]`, `[WEB-ISSUSER]`, `[WEB-TOKEN]`).

---

## 1. Alcance

Metaplace de intercambio, compra y venta de activos del mundo real tokenizados (RWA), con
certificación de identidades Web3 y creación de tokens/NFT bajo demanda. La plataforma integra
**tres suites bajo un mismo concepto visual** y usa **BarloToken (BRLT, 8 decimales)** como moneda
de pago de servicios, bienes, productos y NFTs.

**Actores:** Visitante · Usuario (socio) · Fiador · Emisor/Issuer · Operador · Administrador · Sistema (indexer).

**Fuera de alcance (a confirmar):** activos reales con valor monetario, cumplimiento regulatorio
efectivo (AML/PSD2/MiCA), custodia de dinero FIAT.

---

## 2. Requerimientos funcionales (RF-V3)

### 2.1 Metaplace y suites

| ID | Requerimiento | Brief | Estado v2 |
|---|---|---|---|
| **RF-V3-01** | El sistema deberá ofrecer un **Metaplace** con navegación unificada y una **misma identidad visual** para las 3 suites (Identity, Issuer, Token), con sesión compartida (SSO SIWE) entre ellas. | [objetivo], [contexto] 1 | Parcial: 3 apps separadas, sin shell ni SSO de producto |
| **RF-V3-02** | El Metaplace solo será operable para usuarios con el claim **Socio** vigente; el resto verá modo visitante con acceso limitado (catálogo público, sin compra). | [procesos generales] 1 | Ausente (no existe topic Socio) |
| **RF-V3-03** | La suite **WEB-IDENTITY** será el alta del usuario: creación de identidad Web3 única, gestión de solicitudes de certificación y consulta de claims. | [WEB-IDENTITY] | Parcial: alta + claim-requests existen |
| **RF-V3-04** | La suite **WEB-ISSUSER** será la suite de administración: catálogo de ISSUER, aprobación de certificaciones, tokenización, monitoreo (Sistema), custodia de recuperación de identidad. | [WEB-ISSUSER] | Parcial: issuer + admin, sin catálogo ISSUER ni Sistema |
| **RF-V3-05** | La suite **WEB-TOKEN** será el Metaplace de compra/venta/intercambio de tokens, NFTs y criptomonedas **simbólicas** (sin valor real). | [WEB-TOKEN] | Parcial: catálogo de tokens, sin compra/venta/intercambio |

### 2.2 Identidad y certificaciones

| ID | Requerimiento | Brief | Estado v2 |
|---|---|---|---|
| **RF-V3-06** | El alta del usuario deberá crear una **identidad única** que no exponga los datos ni la dirección de su billetera dentro de la plataforma; la wallet solo firma. | [WEB-IDENTITY] | Parcial: identidad on-chain (clon) + SIWE, sin capa de seudonimia |
| **RF-V3-07** | El acceso al Metaplace exigirá completar **KYC avanzado** y obtener el certificado (claim) de **Socio**, emitido por un emisor autorizado. | [procesos generales] 1 | Ausente el topic/flujo Socio |
| **RF-V3-08** | El KYC avanzado deberá aceptar **documentos PDF/PNG** (y formatos adicionales a definir), verificar su integridad y custodiarlos cifrados. | [WEB-ISSUSER], [procesos generales] 2 | ✅ Cubierto (RF-W-05/06 v2) |
| **RF-V3-09** | El sistema deberá permitir **certificaciones previas** como requisito de un ISSUER (un ISSUER puede exigir claims ya emitidos). | [WEB-ISSUSER] | Ausente (solo topics fijos) |
| **RF-V3-10** | Cada claim deberá poder **revocarse** por el emisor autorizado y `isVerified` dejará de aceptarlo; la **caducidad** queda soportada por esquema pero **desactivada en v3.0** (Q8). | [WEB-ISSUSER] | 🔴 Pendiente v2 (RF-013 del backlog) |
| **RF-V3-11** | El sistema deberá soportar la **recuperación de identidad** (pérdida/robo de wallet, cambio de wallet, disputa) como proceso custodiado y auditado por el Administrador. | [WEB-ISSUSER] | Ausente |
| **RF-V3-12** | Los **ISSUER** se definirán por: proceso, requisitos (documentos PDF/PNG, certificaciones previas) y **varios certificados** por ISSUER. | [WEB-ISSUSER], [procesos generales] 3 | Parcial: emisores sin plantillas de proceso |
| **RF-V3-13** | El usuario podrá **solicitar** los certificados de cada ISSUER; el Operador verificará documentos y el Administrador aprobará/emitirá la firma EIP-712. | [procesos generales] 3, [WEB-ISSUSER] | Parcial: claim-requests + revisión; sin cola Operador separada |

### 2.3 Tokenización

| ID | Requerimiento | Brief | Estado v2 |
|---|---|---|---|
| **RF-V3-14** | Para tokenizar un activo real se requerirán los certificados de **Garantía** y de **Fiador**, además de los documentos PDF que acrediten la tenencia. | [procesos generales] 2 | Ausente (sin Garantía/Fiador) |
| **RF-V3-15** | **Productos:** se acuñará la **cantidad final** de un producto elaborado (preferentemente artesanal), con lote y documentos de respaldo. | [WEB-ISSUSER] 1 | Parcial: token factory ERC-20 genérico |
| **RF-V3-16** | **Servicios:** se acuñarán las **cantidades por servicio** (estimado 60 servicios/mes); el precio unitario se expresa en **BRLT**; se valorará que sean **NFT que se queman al usarse**. | [WEB-ISSUSER] 2 | Ausente |
| **RF-V3-17** | **Bienes:** se acuñará **un NFT por bien** a vender, con documentos de tenencia y valuación. | [WEB-ISSUSER] 3 | Ausente |
| **RF-V3-18** | La plataforma deberá permitir **crear/issues de tokenización** bajo demanda cuando se cumplan las condiciones definidas en el ISSUER. | [procesos generales] 4 | Parcial (creación de token sin ISSUER) |

### 2.4 Mercado, pagos y UX de billetera

| ID | Requerimiento | Brief | Estado v2 |
|---|---|---|---|
| **RF-V3-19** | El Metaplace permitirá **listar, comprar y vender** tokens y NFTs RWA a **precio fijo** con escrow y comisión; el intercambio (barter) queda para v3.1. | [objetivo], [WEB-TOKEN] | Ausente |
| **RF-V3-20** | **BarloToken (BRLT)** será la moneda de pago de servicios, bienes, productos y NFTs; **8 decimales**; token de **utilidad sin valor real**; suministro y emisión gobernados por la plataforma. | [objetivo] | Ausente (existe RWAD de 18 dec, solo demo) |
| **RF-V3-21** | Los **mensajes de firma/autorización/NFT** enviados a la billetera deberán ser comprensibles por un usuario común, con **plantillas por tipo de proceso** y lenguaje coloquial. | [contexto] 2 | Ausente (mensajes EIP-712 técnicos) |
| **RF-V3-22** | Solo **Administrador** y **Operador** accederán a WEB-ISSUSER: Admin con todas las funciones; Operador **solo** verificación de documentos. | [WEB-ISSUSER] | Parcial: roles investor/issuer/admin, sin Operador |
| **RF-V3-23** | La sección **Sistema** monitoreará la plataforma: salud de servicios, eventos on-chain, solicitudes, auditoría y métricas operativas. | [WEB-ISSUSER] | Parcial: health + indexer, sin panel |

### 2.5 Correcciones de la auditoría (Q11–Q13)

| ID | Requerimiento | Origen |
|---|---|---|
| **RF-V3-24** | El **Emisor (Issuer)** será un rol de plataforma acotado: gestiona sus ISSUER y emite/revoca **solo** los claims de sus programas, firmando EIP-712 con clave propia; cada claim persiste el emisor que lo firmó. | H-02 · Q11(a) |
| **RF-V3-25** | El marketplace garantizará: **una sola orden abierta** por publicación, reserva con TTL, remanente transaccional, idempotencia de `tx_hash`, `UNIQUE` de escrow, **atomicidad NFT↔BRLT** y **disputa con árbitro** y plazos. | H-05 · Q12(a) |
| **RF-V3-26** | La evolución v2→v3 será una **migración versionada y transaccional** que archiva las tablas heredadas, hace ETL de datos y registra `3.0` solo al final; se ensaya en CI contra un `pg_dump` v2. | H-01 · QW-4 |
| **RF-V3-27** | Existirán roles/procesos declarados para **Auditor** (lectura y exportación), **Soporte** (escalado con SLA) y **árbitro de disputas**, y el **Fiador** deberá **consentir** el respaldo (estados de garantía). | H-10, H-34 · Q11(a) |
| **RF-V3-28** | Habrá **asistencia guiada** en los «grandes pasos» de cada suite (wizard/checklist) y una **metodología de identidad Web3** publicada, con criterios medibles en C1–C3. | H-20 |
| **RF-V3-29** | Los roles se materializarán en `role_assignments` (principal ≠ claim), con ámbito `platform`/`issuer_program`, concesión y revocación auditadas y efecto inmediato; `audit_log` será **append-only**. | B5 · H-23/H-34 |
| **RF-V3-30** | El marketplace tendrá **máquina de estados** de la orden (solo transiciones válidas), **reserva con TTL**, **tramo NFT** del escrow (`escrow_asset_tx_hash`), validación de vendedor/comisión/pago y **job de expiración** cada 5 min. | B3 · H-05/N-11 |
| **RF-V3-31** | Los contratos de activo aplicarán **compliance on-chain** en cada transferencia (`_update`/`beforeTokenTransfer` contra `IdentityRegistry` y `token_required_claims`), con `isVerified` fail-closed y tests adversariales. | B6 · H-07 |

---

## 3. Requerimientos no funcionales (RNF-V3)

| ID | Categoría (ISO 25010) | Requerimiento y criterio medible |
|---|---|---|
| **RNF-V3-01** | Seguridad | **0 endpoints de escritura sin autenticación** y 0 sin autorización por recurso; las lecturas públicas del modo visitante (catálogo) se limitan a `GET` y a datos no sensibles. Toda mutación exige sesión SIWE válida, verificado por test que recorre el manifiesto de rutas. |
| **RNF-V3-02** | Privacidad | Documentos KYC cifrados en reposo (AES-256-GCM) con clave en Secret Manager; 0 endpoints públicos que devuelvan PII; todo acceso a documento queda en `audit_log`. |
| **RNF-V3-03** | Auditabilidad | Toda emisión/revocación de claim, tokenización, pago y recuperación de identidad deja rastro on-chain y/u off-chain correlacionable (`request_id` + `tx_hash`). |
| **RNF-V3-04** | Usabilidad | WCAG 2.1 AA sobre **las 12 rutas del Anexo A** (0 violaciones `axe` de impacto `serious`/`critical`: contraste, teclado, foco, nombres accesibles); mensajes de firma con **umbral numérico**: `title` ≤ 40 caracteres, `template` ≤ 200 caracteres, **0** términos de una lista cerrada de jerga e índice Flesch-Szigriszt ≥ 55; gate de CI `check-wallet-messages`. |
| **RNF-V3-05** | Desempeño | First Load JS ≤ 400 KB gzip por ruta; API p95 < 800 ms en lectura y **p95 < 1,5 s en escritura** (claim, tokenización, compra, escrow); prueba de carga a **2× el pico** (≈60 servicios/mes + compras concurrentes) con **0 dobles ventas**; health < 2 s. |
| **RNF-V3-06** | Fiabilidad | Ante caída de PostgreSQL o del RPC: `503` con error tipado, 0 respuestas `200` vacías por error; indexer reanudable (last_block + hash) y con detección de reset/reorg. **Disponibilidad ≥ 99,5 % mensual** con error budget. |
| **RNF-V3-07** | Portabilidad | 0 literales de red (`0x…` 40 hex, `localhost`, `http://` de servicio) en el código; configuración única validada al arranque. |
| **RNF-V3-08** | Mantenibilidad | Cobertura de tests ≥ 80 % en contratos (`forge coverage`) y ≥ 70 % en `packages/shared` + rutas de API críticas; `tsc --noEmit` y lint en verde. |
| **RNF-V3-09** | Extensibilidad | Nuevas reglas de compliance y nuevos tipos de ISSUER se añaden sin modificar el núcleo del token. |
| **RNF-V3-10** | Internacionalización | Mensajes de billetera y UI en **español** por defecto, con catálogo `es`/`en` **completo** (7 procesos × 2 idiomas) y test que falla si falta una traducción. |
| **RNF-V3-11** | Operación | Despliegue reproducible por comando (provision/build/deploy/verify) en GCP; 0 secretos en repositorio. |
| **RNF-V3-12** | Cumplimiento y protección de datos | Base legal y consentimiento registrados por identidad; derechos del titular (acceso, rectificación, supresión, portabilidad) con **SLA ≤ 30 días** trazado en `audit_log`; DPIA antes de C1; inventario de encargados; retención probada por categoría; opinión legal por jurisdicción del piloto. **BRLT sin valor real** (Q13). |
| **RNF-V3-13** | Observabilidad | 100 % de rutas y jobs instrumentados con `request_id`/traza; dashboards de latencia, errores y saturación; alertas con dueño y umbral (lag del indexer > 2 bloques, 5xx > 1 %, p95 fuera de SLO); retención de logs ≥ 90 días. |
| **RNF-V3-14** | Recuperación | **RPO ≤ 15 min y RTO ≤ 4 h** con backup/PITR documentado y **ensayo de restauración**; copia versionada y plan de rotación de `KYC_ENCRYPTION_KEY`; RPC de respaldo con failover. |
| **RNF-V3-15** | Seguridad (anti-abuso) | **Threat model STRIDE** documentado y revisado antes del piloto; **rate limiting** en auth y escrituras (p. ej. 10 req/min por wallet/IP), nonce SIWE de un solo uso y TTL máximo de sesión; alertas ante picos anómalos. |

---

## 4. Requerimientos técnicos (RT-V3)

| ID | Requerimiento |
|---|---|
| **RT-V3-01** | Reutilizar el stack de la v2: monorepo pnpm (`apps/*`, `packages/*`), Next 16 + React 19 + TypeScript strict + Tailwind 4, `wagmi` + `viem`, `zod`, TanStack Query. |
| **RT-V3-02** | Contratos: Solidity 0.8.20, OpenZeppelin 5.5.0 (+ upgradeable), Foundry; EIP-712 para claims y para toda firma mostrada en billetera. |
| **RT-V3-03** | Nuevo estándar de activos (decisión Fase 2): **ERC-721** para bienes (único) y **servicios** (quemable), **ERC-1155** para productos/lotes por cantidad; **ERC-20** con 8 decimales para BRLT. |
| **RT-V3-04** | Off-chain: **PostgreSQL global de la cuenta** `truekeate-main:southamerica-east1:truekeate-db-dev` (PG15, backups+PITR), base dedicada **`txbarlovento`** y esquema `rwa` (migraciones versionadas). |
| **RT-V3-05** | On-chain: **Foundry (Anvil) global de la cuenta** (`mcc-foundry-anvil`, chain 31337) como red canónica; direcciones desde artefacto versionado `sc/deployments/*.json` y gate anti-deriva. |
| **RT-V3-06** | Despliegue: Cloud Run + Cloud Run Jobs + Cloud Scheduler en el proyecto **tx barlovento (`barloventasv2`)**, región `europe-west1`, reutilizando los **servicios globales de Foundry y PostgreSQL**; Secret Manager propio (`txb-*`); pipeline `provision_txb.sh` + `deploy_gcp.sh`. |
| **RT-V3-07** | Indexer: persistencia de eventos en `rwa.chain_events`, estado reanudable, ejecución periódica cada 10 min. |
| **RT-V3-08** | CI (GitLab + espejo GitHub/CodeCrypto): `forge build`, `fmt --check`, `test`, `coverage ≥ 80 %`, `lint`, `tsc`, `check-network-literals`, `check-abi-drift`. |

---

## 5. Supuestos y decisiones abiertas (semilla de la entrevista)

| # | Tema | Supuesto / estado |
|---|---|---|
| S-1 | Relación con v2 | **RESUELTO (Q1):** v3 sustituye a v2 sobre los mismos repos y servicios GCP (rama `rwa-web-DSH-GCP-v3`); v2 congelada |
| S-2 | Repositorios | **RESUELTO (Q1):** continuidad en `gitlab.com/anlucorporations/rwa-sc` y `rwa-web`, rama `rwa-web-DSH-GCP-v3`; sin repos nuevos |
| S-3 | GCP | **ACEPTADO (dueño: Arquitectura, 2026-11-04)** reutilizar `mcc-ecommerce` + Anvil global + Cloud SQL; sin nodos ni BD duplicadas (D-095/D-096/D-101). Revisión: antes de C0 |
| S-4 | BRLT | **RESUELTO (Q2):** token de **utilidad sin valor real** (demo/Anvil), emisión controlada por el Admin |
| S-5 | Comisiones | **RESUELTO (Q4):** **5 % configurable por venta + fee fijo de tokenización**, recaudado por el Admin vía `FeeCollector` |
| S-6 | Marketplace | **RESUELTO (Q3):** **precio fijo** con escrow y comisión en v3.0; ofertas/subastas/barter → v3.1 |
| S-7 | Custodia | **RESUELTO (Q5):** **non-custodial** + recuperación asistida con doble aprobación del Admin |
| S-8 | Regulatorio | **RESUELTO (Q13):** demo/piloto **sin activos reales**; se documenta la exclusión y un **gate legal** antes de cualquier uso con valores reales. |
| S-9 | Criptomonedas simbólicas | **RESUELTO (Q6):** solo **BRLT + tokens/NFTs RWA** en v3.0; ampliable por el Admin en v3.1 |
| S-10 | Alcance geográfico | **RESUELTO (Q7):** piloto **LatAm** (VE, CO, PA, MX, CL, PE, AR); el Admin habilita más países. |
| S-11 | Caducidad de claims | **RESUELTO (Q8):** sin caducidad en v3.0; columna `expires_at` preparada y revocación soportada. |
| S-12 | Valuación | **RESUELTO (Q9):** tasación documental en BRLT; el precio de listado no excede la tasación. |
| S-13 | Retención documental | **RESUELTO (Q10):** 30 días tras rechazo / 12 meses tras fin de relación, auditado. |
| S-14 | Capacidad (pico) | **RESUELTO (B9):** 60 servicios/mes ≈ 2/día; pico definido = 20 compras concurrentes + 5 claims/min; prueba de carga a 2× = 40 compras concurrentes. |

---

## 6. Trazabilidad brief → requerimientos

Origen único: la sección del brief. Los RF derivados de auditoría/decisiones se declaran aparte para
no atribuirles un deseo que el brief no contiene. Todos los identificadores se escriben completos.

| Sección del brief | Requerimientos |
|---|---|
| `[OBJETIVO]` | RF-V3-01, RF-V3-19, RF-V3-20, RF-V3-28 |
| `[contexto] 1` | RF-V3-01 |
| `[contexto] 2` | RF-V3-21 |
| `[procesos generales] 1` | RF-V3-02, RF-V3-07, RF-V3-08 |
| `[procesos generales] 2` | RF-V3-09, RF-V3-14, RF-V3-15, RF-V3-16, RF-V3-17 |
| `[procesos generales] 3` | RF-V3-12, RF-V3-13 |
| `[procesos generales] 4` | RF-V3-18 |
| `[WEB-IDENTITY]` | RF-V3-03, RF-V3-06, RF-V3-11 |
| `[WEB-ISSUSER]` | RF-V3-04, RF-V3-10, RF-V3-13, RF-V3-22, RF-V3-23 |
| `[WEB-TOKEN]` | RF-V3-05, RF-V3-19 |
| **Derivados de auditoría/decisiones (no del brief)** | RF-V3-24 (H-02/Q11), RF-V3-25 (H-05/Q12), RF-V3-26 (H-01), RF-V3-27 (H-10/H-34), RF-V3-29 (B5), RF-V3-30 (B3), RF-V3-31 (B6); RNF-V3-12 (H-16), RNF-V3-13 (H-18/H-19), RNF-V3-14 (H-14) |

## Anexo A — Manifiesto de las 12 rutas principales (RNF-V3-04 / B9)

| # | Ruta | Suite |
|---|---|---|
| 1 | `/` | Metaplace |
| 2 | `/login` | Metaplace |
| 3 | `/catalogo` | Token |
| 4 | `/activo/[id]` | Token |
| 5 | `/compras` | Token |
| 6 | `/identidad` | Identity |
| 7 | `/identidad/claims` | Identity |
| 8 | `/identidad/recuperacion` | Identity |
| 9 | `/emisor` | Issuer |
| 10 | `/emisor/solicitudes` | Issuer |
| 11 | `/emisor/verificacion` | Issuer |
| 12 | `/sistema` | Issuer (admin) |

> El test de accesibilidad recorre este manifiesto; si se añade una ruta sin clasificar, el gate de CI falla.

*Documento vivo. Se sincroniza con `diccionario_datos.md`, `diagrama_er.md` y `base_datos.sql`
cuando se cierre la entrevista de Fase 1.*
