# Casos de uso — RWA v3 «Barlo Metaplace»

> **Versión:** v3.2 · **Fecha:** 2026-11-04 · **Fase:** 2 (Casos de uso + documento técnico)
> **Base:** `requerimientos.md` v3.2 (31 RF · 14 RNF · 8 RT), `diseno_cierre_v3_2.md`, `base_datos.sql` v3.2.
> **Regla:** un caso de uso por **objetivo de actor**; criterios funcionales en **Gherkin** y
> restricciones del sistema en **EARS**; todo criterio es **testeable** y está trazado a RF/RNF.
> **Convención:** `CU-XX` casos de uso · `RF-V3-XX` requerimientos funcionales · `RNF-V3-XX` no funcionales.

---

## 1. Actores

| Actor | Tipo | Descripción | Rol en `role_assignments` |
|---|---|---|---|
| **Visitante** | humano | Sin sesión; solo catálogo público | — |
| **Usuario** | humano | Persona con identidad seudónima; opera con claims | `investor` (implícito por sesión) |
| **Fiador** | humano/entidad | Respalda un activo y consiente la fianza | `fiador` (claim) + capacidad de consentir |
| **Operador** | humano | Verifica documentos; **no** aprueba ni emite | `operator` |
| **Emisor (Issuer)** | humano/entidad | Emite/revoca claims de sus programas y tokeniza | `issuer` (ámbito `issuer_program`) |
| **Admin** | humano | Administración de plataforma, ISSUER, claims, roles | `admin` |
| **Auditor** | humano | Solo lectura y exportación de auditoría | `auditor` |
| **Árbitro** | humano | Resuelve disputas del marketplace | `arbiter` |
| **Soporte** | humano | Escala incidencias con SLA | `support` |
| **Sistema** | automático | Jobs: expiración de reservas, purga, indexer, conciliación | — (procesos) |

## 2. Convenciones de aceptación

- **Comportamiento de actor → Gherkin** (`Dado / Cuando / Entonces`), un criterio por comportamiento
  verificable, con números concretos.
- **Restricción del sistema → EARS**:
  - `Mientras <estado>, el sistema <respuesta>` · `Cuando <evento>, el sistema <respuesta>` ·
    `Si <condición>, entonces el sistema <respuesta>` · `El sistema deberá <capacidad>`.
- Cada CU declara el **tipo de prueba** que lo valida: `E2E` (navegador), `API` (integración),
  `DB` (SQL/trigger), `CONTRATO` (Foundry), `JOB` (ejecución programada).

---

## 3. Catálogo de casos de uso

| CU | Actor | Objetivo | Suite | RF |
|---|---|---|---|---|
| CU-01 | Visitante | Consultar el catálogo público | Metaplace | RF-V3-01, 02, 05, 19 |
| CU-02 | Visitante | Autenticarse con SIWE | Metaplace | RF-V3-01, 06 |
| CU-03 | Usuario | Crear su identidad seudónima | Identity | RF-V3-03, 06 |
| CU-04 | Usuario | Solicitar un certificado (claim) | Identity | RF-V3-07, 09, 13 |
| CU-05 | Usuario | Consultar sus certificados | Identity | RF-V3-03, 10 |
| CU-06 | Usuario | Solicitar recuperación de identidad | Identity | RF-V3-11 |
| CU-07 | Fiador | Consentir/revocar la fianza de un activo | Identity | RF-V3-14, 27 |
| CU-08 | Admin | Crear un ISSUER (plantilla de certificación) | Issuer | RF-V3-12, 18 |
| CU-09 | Operador | Verificar documentos de una solicitud | Issuer | RF-V3-13, 22 |
| CU-10 | Admin / Emisor | Aprobar y emitir un claim | Issuer | RF-V3-07, 10, 24 |
| CU-11 | Emisor / Admin | Revocar un claim | Issuer | RF-V3-10, 24 |
| CU-12 | Emisor | Tokenizar un producto (cantidad final) | Issuer | RF-V3-15, 18, 31 |
| CU-13 | Emisor | Tokenizar un servicio (NFT quemable) | Issuer | RF-V3-16, 31 |
| CU-14 | Emisor | Tokenizar un bien (1 NFT) | Issuer | RF-V3-17, 14, 31 |
| CU-15 | Admin | Gestionar roles y asignaciones | Issuer | RF-V3-29 |
| CU-16 | Admin | Configurar comisiones y fees | Issuer | RF-V3-20, 25 |
| CU-17 | Admin / Auditor | Monitorear la plataforma (panel Sistema) | Issuer | RF-V3-23 |
| CU-18 | Auditor | Exportar la auditoría | Issuer | RF-V3-27, 29 |
| CU-19 | Soporte | Escalar una incidencia | Issuer | RF-V3-27 |
| CU-20 | Usuario | Publicar un activo a precio fijo | Token | RF-V3-19, 25 |
| CU-21 | Usuario | Comprar un activo (escrow) | Token | RF-V3-19, 20, 25 |
| CU-22 | Usuario | Confirmar recepción y liberar escrow | Token | RF-V3-19, 25 |
| CU-23 | Usuario | Abrir una disputa | Token | RF-V3-25 |
| CU-24 | Árbitro | Resolver una disputa | Token | RF-V3-25 |
| CU-25 | Usuario | Consumir un servicio (quemar NFT) | Token | RF-V3-16 |
| CU-26 | Sistema | Expirar reservas vencidas | Sistema | RF-V3-25, 30 |
| CU-27 | Sistema | Purgar documentos por retención | Sistema | RF-V3-30, RNF-V3-12 |
| CU-28 | Sistema | Indexar eventos on-chain | Sistema | RF-V3-23 |
| CU-29 | Sistema | Conciliar pagos pendientes | Sistema | RF-V3-25 |

---

## 4. Casos de uso detallados

### CU-01 — Consultar el catálogo público
- **Actor:** Visitante · **Tipo de prueba:** E2E + API
- **Objetivo:** ver los activos publicados sin sesión.
- **Precondiciones:** existen activos en estado `listed` con publicación activa.
- **Flujo principal:**
  1. El visitante abre `/catalogo`.
  2. El sistema lista los activos con nombre, tipo, precio BRLT y emisor (sin datos personales).
  3. El visitante filtra por tipo (producto/servicio/bien) o por programa emisor.
  4. El visitante abre el detalle `/activo/{id}`.
- **Alternativas:** A1. No hay activos → mensaje «sin publicaciones» (no error). A2. Filtro sin resultados → lista vacía con sugerencia.
- **Criterios (Gherkin):**
```gherkin
Escenario: catálogo público sin sesión
  Dado que existen 3 activos publicados y 1 en borrador
  Cuando un visitante sin sesión abre /catalogo
  Entonces ve exactamente 3 activos y ninguno en estado borrador
  Y la respuesta HTTP es 200

Escenario: detalle de activo inexistente
  Dado que no existe el activo "abc"
  Cuando el visitante abre /activo/abc
  Entonces recibe HTTP 404 con `Content-Type: application/json`, un campo `error` de la lista cerrada, y el cuerpo no contiene stack traces, nombres de tabla ni rutas internas
```
- **Restricciones (EARS):**
  - `El sistema deberá` devolver en el catálogo público **0 datos personales** (wallet, alias de identidad, documentos).
  - `Si` el RPC está caído, `entonces` el catálogo sigue sirviendo datos off-chain y marca el precio como «no verificable ahora».
- **Trazabilidad:** RF-V3-01, RF-V3-02, RF-V3-05, RF-V3-19 · RNF-V3-01, RNF-V3-04.
- **Test:** E2E de las rutas 1–4 del Anexo A; API `GET /api/catalog`.

---

### CU-02 — Autenticarse con SIWE
- **Actor:** Visitante → Usuario · **Tipo de prueba:** API + E2E
- **Objetivo:** iniciar sesión firmando un mensaje con la wallet, sin contraseña.
- **Precondiciones:** wallet con soporte EIP-4361; `chainId` = 31337.
- **Flujo principal:**
  1. El visitante pulsa «Conectar wallet».
  2. El sistema pide un `nonce` de un solo uso (`/api/auth/nonce`).
  3. La wallet firma el mensaje SIWE.
  4. El sistema verifica firma, `domain`, `uri`, `chainId` y nonce; emite cookie `httpOnly` + `SameSite=Strict` + `Secure`.
  5. El usuario accede a su panel.
- **Alternativas:** A1. Firma inválida → `401`, sin crear sesión. A2. Nonce reutilizado → `401`. A3. `chainId` distinto → error explícito y bloqueo.
- **Criterios (Gherkin):**
```gherkin
Escenario: login correcto
  Dado un nonce vigente y una wallet con chainId 31337
  Cuando el usuario firma el mensaje SIWE y lo envía a /api/auth/verify
  Entonces recibe 200 y una cookie httpOnly, SameSite=Strict y Secure

Escenario: nonce reutilizado
  Dado un nonce ya consumido
  Cuando se intenta verificar de nuevo
  Entonces el sistema responde 401 y no emite cookie
```
- **Restricciones (EARS):**
  - `El sistema deberá` invalidar el nonce tras el primer uso y caducarlo en ≤ 5 minutos.
  - `Si` el `chainId` de la wallet no coincide con el canónico, `entonces` el sistema rechaza la operación con error explícito.
- **Trazabilidad:** RF-V3-01, 06 · RNF-V3-01, RNF-V3-06.
- **Test:** API de auth (4 rutas) + E2E de login.

---

### CU-03 — Crear la identidad seudónima
- **Actor:** Usuario autenticado · **Tipo de prueba:** API + DB
- **Objetivo:** obtener una identidad única en el Metaplace sin exponer la wallet ni los datos.
- **Precondiciones:** sesión SIWE válida; wallet sin identidad previa.
- **Flujo principal:**
  1. El usuario entra en `/identidad` y confirma el alta.
  2. El sistema crea `identities` (alias público único, `kyc_level=0`).
  3. El sistema muestra el alias y explica que la wallet no se publica.
- **Alternativas:** A1. La wallet ya tiene identidad → se reutiliza (idempotente). A2. Alias ocupado → se genera otro automáticamente (sin exponer motivos internos).
- **Criterios (Gherkin):**
```gherkin
Escenario: alta de identidad
  Dado un usuario con sesión válida y wallet sin identidad
  Cuando confirma el alta en /identidad
  Entonces existe 1 fila en identities con esa wallet y un alias público
  Y la respuesta 200 no devuelve la dirección de la wallet en el alias

Escenario: alta repetida
  Dado un usuario que ya tiene identidad
  Cuando repite el alta
  Entonces no se crea una segunda identidad y la respuesta es 200
```
- **Restricciones (EARS):**
  - `El sistema deberá` mantener la wallet fuera de cualquier vista pública.
  - `Mientras` la identidad esté `suspended`, `el sistema` impedirá operar en el Metaplace.
- **Trazabilidad:** RF-V3-03, 06 · RNF-V3-02.
- **Test:** API `POST /api/identity` + consulta DB.

---

### CU-04 — Solicitar un certificado (claim)
- **Actor:** Usuario · **Tipo de prueba:** API + DB
- **Objetivo:** pedir un claim de un ISSUER adjuntando los requisitos.
- **Precondiciones:** identidad activa; ISSUER activo; no hay solicitud `pending` del mismo tipo.
- **Flujo principal:**
  1. El usuario elige un ISSUER en `/identidad/claims`.
  2. El sistema muestra los requisitos (documentos y claims previos).
  3. El usuario sube los PDF/PNG y firma la solicitud (EIP-712).
  4. El sistema valida magic bytes, tamaño y cuota; cifra y guarda los documentos.
  5. La solicitud queda `pending` y entra en la cola del Operador.
- **Alternativas:** A1. Falta un requisito → no permite enviar y explica cuál. A2. Documento con MIME no permitido → rechazo con lista válida. A3. Solicitud duplicada `pending` → `409`.
- **Criterios (Gherkin):**
```gherkin
Escenario: solicitud válida
  Dado un usuario con KYC base aprobado y un ISSUER que exige título de propiedad
  Cuando sube un PDF válido, firma y envía la solicitud
  Entonces existe 1 claim_request en estado pending con firma del solicitante
  Y los documentos están cifrados y con sha256 del contenido

Escenario: documento inválido
  Dado un archivo de 25 MB
  Cuando el usuario intenta subirlo
  Entonces el sistema responde 413 y no crea la solicitud
```
- **Restricciones (EARS):**
  - `El sistema deberá` aceptar solo PDF/PNG/JPEG (y Word heredado de v2) con tamaño 0 < n ≤ 20 MB.
  - `El sistema deberá` registrar cada acceso a documentos en `audit_log`.
- **Trazabilidad:** RF-V3-07, 08, 09, 13 · RNF-V3-02.
- **Test:** API de claims + DB + E2E.

---

### CU-05 — Consultar mis certificados
- **Actor:** Usuario · **Tipo de prueba:** API + E2E
- **Objetivo:** ver claims vigentes, su emisor y su estado.
- **Precondiciones:** identidad con al menos un claim.
- **Flujo principal:**
  1. El usuario abre `/identidad`.
  2. El sistema lista los claims con tipo, emisor, fecha y estado (vigente/revocado).
  3. El usuario puede ver el detalle y el hash de la transacción.
- **Alternativas:** A1. Sin claims → estado vacío explicativo con enlace a «solicitar».
- **Criterios (Gherkin):**
```gherkin
Escenario: listado de certificados
  Dado un usuario con 2 claims aprobados y 1 revocado
  Cuando abre /identidad
  Entonces ve 3 certificados, 2 como vigentes y 1 como revocado
  Y ninguno muestra datos de otro usuario
```
- **Restricciones (EARS):**
  - `El sistema deberá` mostrar solo los claims de la identidad del solicitante.
- **Trazabilidad:** RF-V3-03, 10 · RNF-V3-01.
- **Test:** API + E2E de autorización negativa (id de otro usuario → 403).

---

### CU-06 — Solicitar recuperación de identidad
- **Actor:** Usuario · **Tipo de prueba:** API + DB + E2E
- **Objetivo:** recuperar el acceso cuando se pierde o compromete la wallet.
- **Precondiciones:** identidad existente; evidencia del caso.
- **Flujo principal:**
  1. El usuario abre `/identidad/recuperacion` y adjunta evidencia (documento de identidad).
  2. Declara la wallet nueva.
  3. El sistema crea `identity_recovery_requests` en `requested` y avisa al Admin.
  4. El Admin revisa; un **segundo** Admin aprueba (4-eyes).
  5. El sistema actualiza `identities.wallet_address` y deja auditoría.
- **Alternativas:** A1. Evidencia insuficiente → `rejected` con motivo. A2. Wallet nueva ya registrada → rechazo. A3. Un solo aprobador → no permite aprobar.
- **Criterios (Gherkin):**
```gherkin
Escenario: recuperación con doble aprobación
  Dado un caso con evidencia válida y dos administradores distintos
  Cuando ambos aprueban
  Entonces identities.wallet_address pasa a la wallet nueva
  Y audit_log registra recovery.approve.first y recovery.approve.second

Escenario: mismo aprobador dos veces
  Dado un administrador que ya aprobó
  Cuando intenta aprobar de nuevo con la misma wallet
  Entonces la base rechaza la operación por la regla 4-eyes
```
- **Restricciones (EARS):**
  - `El sistema deberá` exigir `evidence_document_id` y dos wallets aprobadoras distintas.
  - `Si` la wallet nueva ya existe en `identities`, `entonces` el sistema rechaza la recuperación.
- **Trazabilidad:** RF-V3-11, 27 · RNF-V3-03.
- **Test:** API + DB (CHECK 4-eyes) + E2E.

---

### CU-07 — Consentir o revocar la fianza
- **Actor:** Fiador · **Tipo de prueba:** API + DB
- **Objetivo:** aceptar formalmente respaldar un activo y poder revocarlo.
- **Precondiciones:** claim FIADOR vigente; solicitud de fianza del emisor.
- **Flujo principal:**
  1. El fiador recibe la solicitud con el activo y el alcance.
  2. Firma el consentimiento (EIP-712) y lo envía.
  3. El sistema registra la garantía como `ofrecida → aceptada` asociada al token.
  4. Si retira el respaldo, la garantía pasa a `revocada` y el token se pausa si estaba listado.
- **Alternativas:** A1. Fiador sin claim FIADOR → no puede aceptar. A2. Fiador = creador del activo → rechazo (independencia).
- **Criterios (Gherkin):**
```gherkin
Escenario: consentimiento del fiador
  Dado un fiador con claim FIADOR vigente y un activo pendiente de fianza
  Cuando firma el consentimiento
  Entonces la garantía queda en estado aceptada y verificada
  Y audit_log registra guarantee.accept

Escenario: fiador que es el creador
  Dado que el fiador es también el creador del activo
  Cuando intenta aceptar la fianza
  Entonces el sistema rechaza la operación
```
- **Restricciones (EARS):**
  - `Mientras` la garantía del fiador no esté aceptada, `el sistema` no permitirá tokenizar ni publicar el activo.
- **Trazabilidad:** RF-V3-14, 27 · RNF-V3-03.
- **Test:** API + DB (trigger de independencia) + E2E.

---

### CU-08 — Crear un ISSUER
- **Actor:** Admin · **Tipo de prueba:** API + E2E
- **Objetivo:** definir un programa de certificación con su proceso y requisitos.
- **Precondiciones:** sesión con rol `admin` vigente.
- **Flujo principal:**
  1. El Admin abre `/emisor` → «Nuevo ISSUER».
  2. Define nombre, descripción, tipo de actividad, requisitos (documentos/claims) y claims que emite.
  3. Guarda; el ISSUER queda activo y visible para los usuarios.
- **Alternativas:** A1. Slug duplicado → `409`. A2. Requisito de credencial sin tipo → validación impide guardar.
- **Criterios (Gherkin):**
```gherkin
Escenario: creación de ISSUER
  Dado un admin autenticado
  Cuando crea un ISSUER con 2 documentos y 1 claim previo
  Entonces existe issuer_programs activo con sus requisitos y claims asociados
  Y ningún usuario sin rol admin puede verlo en /emisor

Escenario: requisito incompleto
  Dado un REQUISITO de tipo credential sin credential_type_id
  Cuando el admin intenta guardar
  Entonces el sistema responde 422 y no crea el ISSUER
```
- **Restricciones (EARS):**
  - `Si` el rol `admin` no está vigente, `entonces` el sistema responderá 403 en todas las escrituras.
- **Trazabilidad:** RF-V3-04, RF-V3-12, RF-V3-18, RF-V3-29 · RNF-V3-01.
- **Test:** API + E2E + matriz de autorización negativa.

---

### CU-09 — Verificar documentos (Operador)
- **Actor:** Operador · **Tipo de prueba:** API + E2E
- **Objetivo:** validar la documentación de una solicitud y dejarla lista para aprobación.
- **Precondiciones:** solicitud `pending`; rol `operator` vigente.
- **Flujo principal:**
  1. El Operador abre `/emisor/verificacion` y ve la cola.
  2. Abre cada documento (descifrado en servidor, solo para su rol).
  3. Marca «documentos verificados» y deja observaciones.
  4. La solicitud pasa a `documents_verified`; queda en cola del Admin.
- **Alternativas:** A1. Documento ilegible → devuelve a `pending` con motivo. A2. El Operador intenta aprobar → `403`.
- **Criterios (Gherkin):**
```gherkin
Escenario: verificación exitosa
  Dado un operador con una solicitud pending
  Cuando verifica los documentos
  Entonces claim_requests.verified_by_wallet y verified_at quedan registrados
  Y el estado pasa a documents_verified

Escenario: operador intenta aprobar
  Dado un operador autenticado
  Cuando intenta aprobar o emitir un claim
  Entonces el sistema responde 403
```
- **Restricciones (EARS):**
  - `El sistema deberá` impedir que `verified_by_wallet` y `reviewed_by_wallet` sean la misma wallet.
- **Trazabilidad:** RF-V3-04, RF-V3-13, RF-V3-22 · RNF-V3-01, RNF-V3-02.
- **Test:** API + E2E + DB (segregación).

---

### CU-10 — Aprobar y emitir un claim
- **Actor:** Admin o Emisor del programa · **Tipo de prueba:** API + CONTRATO + DB
- **Objetivo:** emitir el certificado firmado on-chain tras la verificación.
- **Precondiciones:** solicitud `documents_verified`; emisor autorizado para el programa.
- **Flujo principal:**
  1. El Admin (o el Emisor del programa) revisa la solicitud.
  2. Firma el claim con EIP-712 (clave del emisor) y envía la transacción `addClaim`.
  3. El sistema guarda `issuer_signature`, `tx_hash`, `issuer_id`, `reviewed_by_wallet` y pasa a `approved`.
  4. El usuario recibe el certificado.
- **Alternativas:** A1. Firma de otro programa → trigger rechaza. A2. Autofirma del solicitante → CHECK rechaza. A3. Ya existe claim aprobado del mismo tipo → índice único rechaza duplicado.
- **Criterios (Gherkin):**
```gherkin
Escenario: emisión correcta
  Dado un claim documents_verified de KYC y un emisor autorizado para kyc-base
  Cuando el emisor firma y se confirma la transacción
  Entonces claim_requests.status = approved con issuer_id, tx_hash y firma
  Y el usuario ve el certificado como vigente

Escenario: emisor de otro programa
  Dado un emisor del programa fiador
  Cuando intenta emitir un claim de kyc-base
  Entonces la base rechaza la operación (emisor fuera del programa)
```
- **Restricciones (EARS):**
  - `El sistema deberá` verificar la firma EIP-712 y que el emisor esté en `TrustedIssuersRegistry`.
  - `Si` el claim ya fue aprobado para la misma identidad y tipo, `entonces` se rechaza un segundo.
- **Trazabilidad:** RF-V3-04, RF-V3-07, RF-V3-10, RF-V3-13, RF-V3-24, RF-V3-31 · RNF-V3-03.
- **Test:** CONTRATO (Foundry) + API + DB.

---

### CU-11 — Revocar un claim
- **Actor:** Emisor del programa o Admin · **Tipo de prueba:** API + CONTRATO + DB
- **Objetivo:** retirar un certificado por incumplimiento o fraude.
- **Precondiciones:** claim `approved` y vigente; emisor autorizado.
- **Flujo principal:**
  1. El emisor elige el claim y el motivo.
  2. Firma y envía `removeClaim`/revocación.
  3. El sistema marca `revoked`, `revoked_at` y el motivo.
  4. La cascada invalida garantías y pausa/cierra el mercado del activo afectado.
- **Alternativas:** A1. Claim ya revocado → idempotente. A2. Emisor no autorizado → `403`.
- **Criterios (Gherkin):**
```gherkin
Escenario: revocación con impacto en mercado
  Dado un claim aprobado que respalda un activo listado
  Cuando el emisor lo revoca
  Entonces el claim queda revoked con motivo y fecha
  Y las garantías asociadas quedan no verificadas y el listing se cancela

Escenario: transición inválida
  Dado un claim revocado
  Cuando se intenta volver a aprobado
  Entonces la base rechaza la transición
```
- **Restricciones (EARS):**
  - `Cuando` se revoca un claim, `el sistema` invalidará garantías y bloqueará el mercado del activo en la misma transacción.
- **Trazabilidad:** RF-V3-10, 24, 31 · RNF-V3-03.
- **Test:** API + DB (cascada) + CONTRATO.

---

### CU-12 — Tokenizar un producto
- **Actor:** Emisor · **Tipo de prueba:** API + CONTRATO + DB
- **Objetivo:** acuñar la cantidad final de un producto artesanal respaldado.
- **Precondiciones:** claims GARANTÍA y FIADOR vigentes del emisor/activo; ISSUER con actividad `product`.
- **Flujo principal:**
  1. El Emisor crea el activo: nombre, cantidad, unidad, precio BRLT, tasación y documentos.
  2. El sistema valida precio ≤ tasación y que existan las dos garantías verificadas.
  3. El Emisor firma la acuñación; el contrato acuña (ERC-1155) y registra `token_address` y `token_id`.
  4. El activo queda `minted` y disponible para publicar.
- **Alternativas:** A1. Sin Garantía o Fiador → trigger rechaza. A2. Precio > tasación → CHECK/trigger rechaza. A3. Documento faltante → no permite acuñar.
- **Criterios (Gherkin):**
```gherkin
Escenario: acuñación con respaldo completo
  Dado un emisor con claims GARANTIA y FIADOR vigentes y tasación de 1000 BRLT
  Cuando acuña 100 unidades a 8 BRLT por unidad
  Entonces el activo queda minted con supply 100 y ERC-1155 acuñado
  Y audit_log registra asset.tokenize

Escenario: sin fiador
  Dado un activo con Garantía pero sin Fiador
  Cuando el emisor intenta acuñar
  Entonces la operación se rechaza y el activo no pasa a minted
```
- **Restricciones (EARS):**
  - `Mientras` falte alguna de las dos garantías verificadas, `el sistema` no permitirá acuñar ni publicar.
- **Trazabilidad:** RF-V3-14, 15, 18, 31 · RNF-V3-09.
- **Test:** CONTRATO + API + DB.

---

### CU-13 — Tokenizar un servicio
- **Actor:** Emisor · **Tipo de prueba:** API + CONTRATO + DB
- **Objetivo:** acuñar N servicios como NFTs que se queman al usarse.
- **Precondiciones:** garantías vigentes; ISSUER con actividad `service`.
- **Flujo principal:**
  1. El Emisor define el servicio, la cantidad (p. ej. 60), el precio en BRLT y la vigencia.
  2. El sistema valida las garantías y crea los NFTs (1 por servicio).
  3. Cada servicio puede publicarse o asignarse; al usarse se quema.
- **Alternativas:** A1. Cantidad 0 o negativa → validación. A2. Sin garantías → rechazo.
- **Criterios (Gherkin):**
```gherkin
Escenario: acuñación de servicios
  Dado un emisor con garantías vigentes y 60 servicios mensuales
  Cuando acuña los 60 servicios
  Entonces existen 60 NFTs ERC-721 asociados al lote
  Y cada NFT puede quemarse una sola vez al consumirse
```
- **Trazabilidad:** RF-V3-16, 31 · RNF-V3-09.
- **Test:** CONTRATO + DB.

---

### CU-14 — Tokenizar un bien
- **Actor:** Emisor · **Tipo de prueba:** API + CONTRATO + DB
- **Objetivo:** acuñar un NFT único por bien con su tenencia y tasación.
- **Precondiciones:** garantías vigentes; documentos de tenencia y tasación.
- **Flujo principal:**
  1. El Emisor registra el bien y adjunta título y tasación.
  2. El sistema valida documentos y precio ≤ tasación.
  3. Se acuña 1 NFT con `metadata_uri` fija y hash de documentos.
  4. El bien queda `minted` y publicable.
- **Criterios (Gherkin):**
```gherkin
Escenario: bien único
  Dado un bien con título de propiedad y tasación de 5000 BRLT
  Cuando el emisor lo tokeniza a 4500 BRLT
  Entonces existe 1 NFT ERC-721 con metadata_uri y hash de documentos
  Y el precio de listado no podrá superar 5000 BRLT
```
- **Trazabilidad:** RF-V3-17, 14, 31 · RNF-V3-02.
- **Test:** CONTRATO + API + DB.

---

### CU-15 — Gestionar roles
- **Actor:** Admin · **Tipo de prueba:** API + DB + E2E
- **Objetivo:** conceder o revocar roles de plataforma y de programa.
- **Precondiciones:** rol `admin` vigente.
- **Flujo principal:**
  1. El Admin abre la gestión de roles y busca la wallet.
  2. Concede un rol (`issuer`/`operator`/`auditor`/`arbiter`/`support`/`admin`) con ámbito y motivo.
  3. El sistema crea `role_assignments` y registra `role.grant`.
  4. Para revocar, marca `revoked_at` y registra `role.revoke`.
- **Alternativas:** A1. Rol de programa sin programa → CHECK rechaza. A2. Rol activo duplicado → índice único rechaza.
- **Criterios (Gherkin):**
```gherkin
Escenario: concesión de rol
  Dado un admin autenticado y una wallet sin rol
  Cuando concede rol operator en ámbito platform
  Entonces existe 1 role_assignment activo y audit_log registra role.grant

Escenario: revocación inmediata
  Dado un usuario con rol issuer vigente
  Cuando el admin lo revoca
  Entonces la siguiente petición del usuario recibe 403
```
- **Trazabilidad:** RF-V3-04, RF-V3-27, RF-V3-29 · RNF-V3-03.
- **Test:** API + DB + E2E.

---

### CU-16 — Configurar comisiones
- **Actor:** Admin · **Tipo de prueba:** API + DB
- **Objetivo:** fijar la comisión por venta y el fee de tokenización.
- **Precondiciones:** rol `admin`.
- **Flujo principal:**
  1. El Admin abre la configuración de comisiones.
  2. Fija `sale_fee_bps` (0–5000) y `tokenization_fee_brlt`.
  3. El sistema actualiza `platform_fees` (singleton) y registra auditoría.
- **Criterios (Gherkin):**
```gherkin
Escenario: comisión válida
  Dado un admin autenticado
  Cuando fija sale_fee_bps = 500
  Entonces la siguiente orden calcula una comisión del 5 % del precio

Escenario: comisión fuera de rango
  Dado un valor de 6000 bps
  Cuando el admin intenta guardarlo
  Entonces el sistema responde 422 y no modifica la comisión
```
- **Trazabilidad:** RF-V3-20 · RNF-V3-01.
- **Test:** API + DB.

---

### CU-17 — Monitorear la plataforma
- **Actor:** Admin / Auditor (lectura) · **Tipo de prueba:** API + E2E
- **Objetivo:** ver salud, lag del indexer, solicitudes y eventos.
- **Precondiciones:** rol `admin` o `auditor`.
- **Flujo principal:**
  1. El actor abre `/sistema`.
  2. El panel muestra: health de apps, lag del indexer, cola de solicitudes, disputas abiertas, jobs y alertas.
  3. El Auditor solo ve; el Admin puede actuar.
- **Criterios (Gherkin):**
```gherkin
Escenario: panel con lag alto
  Dado que el indexer lleva 3 bloques de retraso
  Cuando el admin abre /sistema
  Entonces ve una alerta de lag con el valor y el umbral superado

Escenario: auditor sin escritura
  Dado un auditor autenticado
  Cuando intenta ejecutar una acción de administración
  Entonces recibe 403
```
- **Trazabilidad:** RF-V3-04, RF-V3-23, RF-V3-27 · RNF-V3-13.
- **Test:** E2E + API + matriz de autorización.

---

### CU-18 — Exportar la auditoría
- **Actor:** Auditor · **Tipo de prueba:** API + E2E
- **Objetivo:** descargar el registro de auditoría para revisión.
- **Precondiciones:** rol `auditor`.
- **Flujo principal:**
  1. El Auditor elige rango de fechas y filtros.
  2. El sistema genera CSV firmado (sha256) con los registros.
  3. La descarga queda registrada en `audit_log`.
- **Criterios (Gherkin):**
```gherkin
Escenario: exportación
  Dado un auditor con rango de fechas válido
  Cuando solicita la exportación
  Entonces recibe un CSV con sha256 publicado y la descarga queda auditada
```
- **Restricciones (EARS):**
  - `El sistema deberá` impedir `UPDATE`/`DELETE` sobre `audit_log` (append-only).
- **Trazabilidad:** RF-V3-27, 29 · RNF-V3-03.
- **Test:** API + DB (append-only).

---

### CU-19 — Escalar una incidencia
- **Actor:** Soporte · **Tipo de prueba:** API
- **Objetivo:** registrar y escalar un problema de un usuario con SLA.
- **Precondiciones:** rol `support`.
- **Flujo principal:**
  1. Soporte registra la incidencia con categoría y usuario.
  2. El sistema la asigna, fija SLA de 24 h y notifica al Admin si es crítica.
- **Criterios (Gherkin):**
```gherkin
Escenario: incidencia crítica
  Dado un rol support autenticado
  Cuando registra una incidencia de categoría crítica
  Entonces se crea el caso con SLA de 24 h y se notifica al admin

Escenario: usuario sin rol support
  Dado un usuario autenticado sin rol support
  Cuando intenta registrar una incidencia
  Entonces el sistema responde 403
```
- **Trazabilidad:** RF-V3-27 · RNF-V3-13.
- **Test:** API.

---

### CU-20 — Publicar un activo
- **Actor:** Usuario (dueño con SOCIO) o Emisor · **Tipo de prueba:** API + CONTRATO + DB
- **Objetivo:** poner un activo a la venta a precio fijo.
- **Precondiciones:** activo `minted`, garantías verificadas, SOCIO vigente, precio ≤ tasación.
- **Flujo principal:**
  1. El usuario elige el activo y fija precio y cantidad.
  2. El sistema valida estado, garantías, SOCIO y tope de tasación.
  3. Crea `listings` activo y publica el listado on-chain.
- **Alternativas:** A1. Activo `draft`/`paused` → rechazo. A2. Precio > tasación → rechazo. A3. Ya hay publicación activa → `409`.
- **Criterios (Gherkin):**
```gherkin
Escenario: publicación válida
  Dado un activo minted con garantías verificadas y un usuario con SOCIO
  Cuando publica a 100 BRLT
  Entonces existe 1 listing activo y el token pasa a listed

Escenario: publicación de activo en borrador
  Dado un activo en estado draft
  Cuando el usuario intenta publicarlo
  Entonces la base rechaza la operación
```
- **Trazabilidad:** RF-V3-05, RF-V3-19, RF-V3-25, RF-V3-31 · RNF-V3-01.
- **Test:** CONTRATO + API + DB.

---

### CU-21 — Comprar un activo
- **Actor:** Usuario (SOCIO) · **Tipo de prueba:** API + CONTRATO + DB
- **Objetivo:** comprar a precio fijo con BRLT en escrow.
- **Precondiciones:** listing activo con remanente; comprador con SOCIO; saldo BRLT.
- **Flujo principal:**
  1. El usuario pulsa «Comprar» e indica cantidad.
  2. El sistema crea la orden `pending_payment` con TTL 30 min y comisión calculada.
  3. El usuario firma el depósito; el contrato retiene BRLT en escrow (`escrow_tx_hash`).
  4. La orden pasa a `escrowed`.
- **Alternativas:** A1. Dos compradores simultáneos → solo una orden abierta. A2. Sin SOCIO → `403`. A3. TTL vencido → cancelación y liberación.
- **Criterios (Gherkin):**
```gherkin
Escenario: compra con escrow
  Dado un listing activo de 100 BRLT y un comprador con SOCIO y saldo
  Cuando confirma la compra
  Entonces existe 1 orden escrowed con escrow_tx_hash único y fee = 5 BRLT
  Y el BRLT está retenido en escrow

Escenario: doble compra concurrente
  Dado dos compradores que intentan comprar el mismo listing a la vez
  Cuando ambos confirman
  Entonces solo 1 orden queda abierta y el segundo recibe 409
```
- **Trazabilidad:** RF-V3-19, RF-V3-20, RF-V3-25, RF-V3-31 · RNF-V3-05.
- **Test:** CONTRATO + API + prueba de concurrencia.

---

### CU-22 — Confirmar recepción y liberar escrow
- **Actor:** Usuario comprador · **Tipo de prueba:** API + CONTRATO + DB
- **Objetivo:** confirmar que recibió el activo y liberar el pago.
- **Precondiciones:** orden `escrowed` con ambos tramos del escrow.
- **Flujo principal:**
  1. El comprador confirma la recepción.
  2. El sistema verifica `escrow_tx_hash`, `escrow_asset_tx_hash` y `asset_transferred_at`.
  3. El contrato libera BRLT al vendedor y la comisión al `FeeCollector`.
  4. La orden pasa a `confirmed`; el remanente se descuenta.
- **Alternativas:** A1. Falta un tramo → la BD rechaza la confirmación. A2. El activo no fue transferido → no permite confirmar.
- **Criterios (Gherkin):**
```gherkin
Escenario: liberación correcta
  Dado una orden escrowed con ambos tramos registrados
  Cuando el comprador confirma
  Entonces el vendedor recibe el 95 % y FeeCollector el 5 %
  Y la orden queda confirmed con confirmed_at

Escenario: confirmación sin tramo NFT
  Dado una orden escrowed sin escrow_asset_tx_hash
  Cuando se intenta confirmar
  Entonces la base rechaza la transición
```
- **Trazabilidad:** RF-V3-19, 25 · RNF-V3-03.
- **Test:** DB (trigger) + CONTRATO + API.

---

### CU-23 — Abrir una disputa
- **Actor:** Usuario comprador · **Tipo de prueba:** API + DB
- **Objetivo:** impugnar una orden cuando el activo no coincide o no llega.
- **Precondiciones:** orden `escrowed`.
- **Flujo principal:**
  1. El comprador abre disputa con motivo y evidencias.
  2. El sistema crea `disputes` y pasa la orden a `disputed`.
  3. Se notifica al Árbitro.
- **Alternativas:** A1. Orden ya confirmada → no permite disputa. A2. Disputa duplicada → `409`.
- **Criterios (Gherkin):**
```gherkin
Escenario: apertura de disputa
  Dado una orden escrowed
  Cuando el comprador abre una disputa con motivo
  Entonces existe 1 disputa open y la orden queda disputed
```
- **Trazabilidad:** RF-V3-25 · RNF-V3-03.
- **Test:** API + DB.

---

### CU-24 — Resolver una disputa
- **Actor:** Árbitro · **Tipo de prueba:** API + CONTRATO + DB
- **Objetivo:** decidir el destino del escrow (vendedor o comprador).
- **Precondiciones:** disputa `open`/`in_review`; rol `arbiter`.
- **Flujo principal:**
  1. El Árbitro revisa evidencias y decide.
  2. Registra resolución y firma la operación on-chain.
  3. Si es a favor del comprador: reembolso (`refunded`); si del vendedor: libera (`confirmed`).
- **Criterios (Gherkin):**
```gherkin
Escenario: resolución a favor del comprador
  Dado una disputa abierta
  Cuando el árbitro resuelve a favor del comprador
  Entonces la orden pasa a refunded y el BRLT vuelve al comprador
  Y audit_log registra dispute.resolve

Escenario: doble resolución
  Dado una disputa ya resuelta
  Cuando el árbitro intenta resolverla de nuevo
  Entonces el sistema rechaza la operación

Escenario: sin rol árbitro
  Dado un usuario sin rol arbiter
  Cuando intenta resolver una disputa
  Entonces el sistema responde 403
```
- **Trazabilidad:** RF-V3-25 · RNF-V3-03.
- **Test:** CONTRATO + API + DB.

---

### CU-25 — Consumir un servicio
- **Actor:** Usuario titular · **Tipo de prueba:** CONTRATO + API
- **Objetivo:** quemar el NFT del servicio al usarlo.
- **Precondiciones:** NFT de servicio en la wallet del titular.
- **Flujo principal:**
  1. El usuario confirma el uso del servicio.
  2. El contrato quema el NFT (`burn`).
  3. El sistema registra el consumo y actualiza el estado.
- **Alternativas:** A1. NFT ya quemado → no permite repetir. A2. Titular distinto → `403`.
- **Criterios (Gherkin):**
```gherkin
Escenario: consumo de servicio
  Dado un NFT de servicio en la wallet del titular
  Cuando el usuario confirma el uso
  Entonces el NFT queda quemado y no puede volver a usarse
```
- **Trazabilidad:** RF-V3-16 · RNF-V3-09.
- **Test:** CONTRATO + API.

---

### CU-26 — Expirar reservas (job)
- **Actor:** Sistema · **Tipo de prueba:** JOB + DB
- **Objetivo:** cancelar reservas vencidas y liberar inventario.
- **Precondiciones:** job programado cada 5 min.
- **Flujo principal:**
  1. El job invoca `rwa.expire_orders()`.
  2. La función cancela órdenes `pending_payment`/`escrowed` vencidas.
  3. Se registra el contador y se emiten alertas si falla.
- **Criterios (Gherkin):**
```gherkin
Escenario: reserva vencida
  Dado una orden pending_payment con expires_at en el pasado
  Cuando corre el job de expiración
  Entonces la orden queda cancelled y el remanente se libera

Escenario: reserva vigente
  Dado una orden con expires_at futuro
  Cuando corre el job
  Entonces la orden no cambia
```
- **Trazabilidad:** RF-V3-25, 30 · RNF-V3-06.
- **Test:** JOB + DB.

---

### CU-27 — Purgar documentos por retención (job)
- **Actor:** Sistema · **Tipo de prueba:** JOB + DB
- **Objetivo:** aplicar la retención Q10 y borrar documentos vencidos.
- **Precondiciones:** job diario 03:00; fechas calculadas por los triggers.
- **Flujo principal:**
  1. El job invoca `rwa.purge_expired_documents()`.
  2. Se borran documentos con `retention_delete_at <= current_date`.
  3. La app registra `document.purge` con el contador.
- **Criterios (Gherkin):**
```gherkin
Escenario: purga diaria
  Dado 2 documentos con retención vencida y 1 vigente
  Cuando corre el job de purga
  Entonces se borran 2 y el vigente permanece
  Y audit_log registra document.purge con el contador
```
- **Restricciones (EARS):**
  - `El sistema deberá` impedir que la API sirva un documento con `deleted_at` no nulo.
- **Trazabilidad:** RF-V3-30, RNF-V3-12.
- **Test:** JOB + DB.

---

### CU-28 — Indexar eventos on-chain
- **Actor:** Sistema · **Tipo de prueba:** JOB + DB
- **Objetivo:** persistir los eventos de la cadena para el panel y el historial.
- **Precondiciones:** RPC disponible; `indexer_state` con `chain_id` y último bloque.
- **Flujo principal:**
  1. El job lee eventos desde `last_block + 1`.
  2. Persiste en `chain_events` (con `block_hash` y `removed`).
  3. Actualiza `last_block` y detecta reset/reorg.
- **Criterios (Gherkin):**
```gherkin
Escenario: indexación incremental
  Dado un indexer con last_block = 100 y 2 bloques nuevos
  Cuando corre el job
  Entonces chain_events contiene los nuevos eventos y last_block = 102

Escenario: reorg
  Dado un block_hash distinto en el mismo número de bloque
  Cuando el indexer detecta el cambio
  Entonces no avanza y registra una alerta
```
- **Trazabilidad:** RF-V3-23 · RNF-V3-06, 13.
- **Test:** JOB + DB.

---

### CU-29 — Conciliar pagos pendientes (job)
- **Actor:** Sistema · **Tipo de prueba:** JOB + DB
- **Objetivo:** reconciliar pagos/órdenes con transacciones on-chain.
- **Precondiciones:** job periódico; `payments` con `pending`.
- **Flujo principal:**
  1. El job busca pagos pendientes con antigüedad > N minutos.
  2. Verifica la transacción en cadena y actualiza el estado.
  3. Alerta si hay pagos sin transacción.
- **Criterios (Gherkin):**
```gherkin
Escenario: pago sin transacción
  Dado un pago pending de más de 30 minutos sin tx_hash
  Cuando corre la conciliación
  Entonces el pago se marca failed y se alerta al admin

Escenario: idempotencia del job
  Dado un pago ya conciliado
  Cuando corre la conciliación de nuevo
  Entonces el pago no cambia de estado y no se duplica ninguna alerta
```
- **Trazabilidad:** RF-V3-25 · RNF-V3-06, 13.
- **Test:** JOB + DB.

---

## 5. Matriz de trazabilidad CU ↔ RF

| RF | Casos de uso |
|---|---|
| RF-V3-01 | CU-01, CU-02 |
| RF-V3-02 | CU-01 |
| RF-V3-03 | CU-03, CU-05 |
| RF-V3-04 | CU-08, CU-09, CU-10, CU-15, CU-17 (suite ISSUER) |
| RF-V3-05 | CU-01, CU-20 |
| RF-V3-06 | CU-02, CU-03 |
| RF-V3-07 | CU-04, CU-10 |
| RF-V3-08 | CU-04 |
| RF-V3-09 | CU-04 |
| RF-V3-10 | CU-05, CU-10, CU-11 |
| RF-V3-11 | CU-06 |
| RF-V3-12 | CU-08 |
| RF-V3-13 | CU-04, CU-09, CU-10 |
| RF-V3-14 | CU-07, CU-12, CU-14 |
| RF-V3-15 | CU-12 |
| RF-V3-16 | CU-13, CU-25 |
| RF-V3-17 | CU-14 |
| RF-V3-18 | CU-08, CU-12 |
| RF-V3-19 | CU-01, CU-20, CU-21, CU-22 |
| RF-V3-20 | CU-16, CU-21 |
| RF-V3-21 | **transversal (no-CU)**: mensajes de firma verificados en CU-02/04/07/10/21/22 |
| RF-V3-22 | CU-09 |
| RF-V3-23 | CU-17, CU-28 |
| RF-V3-24 | CU-10, CU-11 |
| RF-V3-25 | CU-20…CU-24, CU-26, CU-29 |
| RF-V3-26 | (migración: validada en acta v3.1, no es caso de uso) |
| RF-V3-27 | CU-06, CU-07, CU-15, CU-17, CU-18, CU-19 |
| RF-V3-28 | (asistencia guiada: requisito transversal de CU-01…CU-04) |
| RF-V3-29 | CU-08, CU-15, CU-18 |
| RF-V3-30 | CU-26, CU-27 |
| RF-V3-31 | CU-10, CU-11, CU-12…CU-14, CU-20, CU-21 |

## 6. Criterios globales de cobertura y testeabilidad

1. **Cobertura de actores:** 100 % de los actores de §1 tienen ≥ 1 CU con criterio testeable.
2. **Cobertura de RF:** 100 % de los RF-V3-01…31 aparecen en §5; **RF-V3-21, RF-V3-26 y RF-V3-28** son los tres RF sin CU propio (transversales/migración justificados).
3. **Testeabilidad:** cada CU declara su tipo de prueba (`E2E/API/DB/CONTRATO/JOB`) y un criterio con números concretos.
4. **Gherkin/EARS:** criterios de comportamiento en Gherkin; restricciones de sistema en EARS; ninguno sin posibilidad de test.
5. **Trazabilidad:** cero criterios sin RF de origen; cero RF sin CU o justificación.

## 7. Preguntas abiertas (para la entrevista de Fase 2)

| # | Pregunta | Impacto |
|---|---|---|
| Q15 | ¿La asistencia guiada (RF-V3-28) se implementa como wizard de 4 pasos o como ayuda contextual por pantalla? | Define CU transversales de UX |
| Q16 | ¿El soporte (CU-19) opera dentro del Metaplace o por canal externo (email/WhatsApp) con registro manual? | Alcance de la suite Admin |
| Q17 | ¿El alta de Socio exige también claim de JURISDICCIÓN desde el inicio o se puede completar después? | Flujo de CU-04/10 |
| Q18 | ¿La exportación de auditoría debe incluir datos personales cifrados o solo metadatos? | RNF-V3-02/12 |

---

*Casos de uso v3.2 · Fase 2 · Se sincronizan con `requerimientos.md` y `documento_tecnico.md`.*
