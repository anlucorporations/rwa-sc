# INFORME DE OPTIMIZACIÓN WEB V1 — Auditoría del frontend RWA (`@web`)

**Proyecto:** RWA — plataforma de tokenización de activos (security token inspirado en ERC-3643 / T-REX)
**Alcance auditado:** `rwa-web/` (5 aplicaciones Next.js, 16 rutas de API, scripts de arranque y documentación propia). Se usa `rwa-sc/` **solo como referencia** del estado actual de contratos.
**Fecha:** 2026-10-14
**Versión del informe:** V1 (primera auditoría dedicada al frontend)
**Precedente:** `INFORME_OPTIMIZACION_V1.md` (contratos). Este informe **no repite** esos hallazgos: los referencias cuando el web los materializa o los agrava.

---

## 1. Resumen ejecutivo

### Veredicto explícito

| Pregunta | Veredicto |
|---|---|
| ¿Apto para producción / uso con KYC y activos reales? | **NO. El frontend no es apto para producción en su estado actual.** |
| ¿Apto para continuar a un plan de optimización? | **SÍ. El diagnóstico está cerrado y las mitigaciones están mapeadas.** La mayor parte del problema es de **capa de servicio (autorización/validación)** y de **higiene de ingeniería (VCS/tests/CI/dependencias)**, no de rediseño visual. |
| ¿Es funcional el flujo end-to-end contra los contratos actuales? | **NO. El flujo de claims y de creación de tokens está roto por desincronización de ABI y de direcciones.** |

### Por qué el veredicto es negativo (3 hechos verificados)

1. **Cualquiera puede aprobar un KYC.** `POST /api/update-request` escribe `status: "approved" | "rejected"` en MongoDB **sin autenticar al llamante, sin comprobar que sea un trusted issuer y sin verificar criptográficamente `issuerSignature`** (`rwa-web/web-registry-trusted/app/api/update-request/route.ts:12-77`). No existe **ni un solo** primitivo de autorización o verificación de firma en todo el frontend: `grep -riE "authorization|bearer|jwt|next-auth|verifyMessage|recoverAddress|ecrecover"` sobre `rwa-web/**/*.ts*` devuelve **0 coincidencias**.
2. **Los documentos KYC y las solicitudes están expuestos.** `GET /api/claim-requests` devuelve **todas** las solicitudes con direcciones, notas y mensajes firmados, sin autenticación ni paginación (`web-identity/app/api/claim-requests/route.ts:12-56`); `GET /api/download/[fileId]` sirve **cualquier** documento por id sin comprobar propiedad (`web-identity/app/api/download/[fileId]/route.ts:11-81`); y los endpoints de depuración `GET /api/test-gridfs` (`web-identity/app/api/test-gridfs/route.ts`) y `GET /api/test-db` (`web-token/app/api/test-db/route.ts`) **listan el inventario completo de ficheros KYC, solicitudes y estadísticas de la base** en producción.
3. **El web habla con contratos que ya no existen en esa forma.** Escribió contra un `addClaim` de **6 parámetros**; los contratos actuales exigen **7** (`_expiresAt`) y **firma EIP-712 verificada con `ecrecover`** (`rwa-sc/sc/src/IdentityCloneable.sol:147-156`, `CLAIM_TYPEHASH` en `:68`). El ABI versionado en el web es una versión antigua (`IdentityCloneable`: md5 `2136a456…` vs `72ffbbcc…` del contrato). Y `web-token` sigue creando tokens con `claimTopicsRegistry = 0x0` (`web-token/components/CreateTokenForm.tsx:145`), ruta que ahora es **fail-closed** (`TokenCloneable.isVerified` devuelve `false` si no hay registry, `rwa-sc/sc/src/TokenCloneable.sol:245-252`): el token creado desde la UI **no verifica a nadie**.

### Cifras medidas (auditoría de esta sesión)

| Métrica | Valor real | Estado |
|---|---|---|
| Aplicaciones Next.js | **5** (`web-identity`, `web-registry-trusted`, `web-registry-trusted2`, `web-rwa`, `web-token`) | El `README.md` raíz declara solo 3 |
| Líneas TS/JS (sin `node_modules`, `.next`, `docker-build`) | **16.648** | — |
| Ficheros fuente | **181** | — |
| Rutas de API | **16** | **16/16 sin autenticación** |
| Tests automatizados (unit/e2e) | **0** | frente a 394/394 en contratos |
| Pipeline CI para el web | **0** | el `.gitlab-ci.yml` existente solo cubre contratos |
| Control de versiones | **ninguno** (no hay `.git` y `rwa-web/` no está rastreado por `rwa-sc`) | riesgo de pérdida total |
| `console.log` en fuente | **161** | — |
| Usos de `window.ethereum` | **96** | sin abstracción ni `wagmi` unificado |
| Anotaciones `any` / `as any` / `: any` | **67** | con `strict: true` declarado pero `ignoreBuildErrors: true` en 3 apps |
| Versiones distintas de `next` | **4** (16.0.1, 16.1.1, 16.1.3, 16.1.6) | 5 lockfiles independientes |
| Versiones distintas de `react` | **2** (19.2.0 ×3, 19.2.3 ×2) | — |
| Stacks web3 distintos | **2** (`ethers` v6 ×3, `viem`+`wagmi`+`rainbowkit` ×1) | — |
| `lib/mongodb.ts` duplicado | **3 copias byte-idénticas** (md5 `c8b48f41…`) | sin paquete compartido |
| Redes destino distintas | **2** (Besu remoto `chainId 81234` en `web-identity` vs Anvil local `31337` en el resto) | direcciones hardcodeadas divergentes |

### Relación con la auditoría de contratos (no duplicación)

El `INFORME_OPTIMIZACION_V1` fijó `D-003: alcance = solo rwa-sc; rwa-web fuera de este ciclo`. Ese recorte es precisamente el origen de la brecha actual: los contratos endurecieron `addClaim` (EIP-712), `isVerified` (fail-closed) y el flujo de despliegue, y **el frontend no acompañó el cambio**. Los hallazgos de contratos que el web materializa son:

| Hallazgo contratos | Cómo lo materializa el web |
|---|---|
| **H-01** claims forjados sin firma | El inversor ejecuta él mismo `addClaim` con la firma del emisor guardada en MongoDB (`web-identity/components/RequestDetailModal.tsx:28-118`); nada valida en cliente la autorización del emisor. |
| **H-05** `isVerified` fail-open | Ya está cerrado on-chain; **ahora el web rompe** al crear tokens con `claimTopicsRegistry = 0x0` (`CreateTokenForm.tsx:145`). |
| **H-11** PII sin custodia | El web la expone activamente por 5 endpoints públicos (HW-02). |
| **H-04** sin VCS/CI | El web está **un escalón por debajo**: no solo no tiene CI, no tiene repositorio. |

---

## 2. Metodología

- **Tipo:** auditoría de solo lectura, sin modificar código ni configuración del proyecto.
- **Técnica:** inventario de ficheros y LOC; lectura directa de rutas de API, capa de contratos, contextos de wallet y formularios; `grep` de primitivas de seguridad (`authorization`, `jwt`, `verifyMessage`, `recoverAddress`, `ecrecover`) y de anti-patrones (`any`, `console.log`, `ignoreBuildErrors`); comparación de ABIs y direcciones contra `rwa-sc/sc/abis/` y `rwa-sc/sc/deployments/`; comparación de versiones entre los 5 lockfiles.
- **Regla de evidencia:** cada hallazgo se sustenta en `ruta:línea` verificable. No se incluye ninguna afirmación que no se haya comprobado contra el sistema de ficheros.
- **Verificación adversarial:** los hallazgos críticos y altos fueron re-verificados por un revisor independiente contra los archivos (ver §6, nota de verificación).
- **Limitación declarada:** no se ejecutó `npm install` ni `next build` (los 5 proyectos **no tienen `node_modules`**), por lo que las afirmaciones sobre errores de compilación se limitan a lo observable en fuente y configuración; no se midió rendimiento en runtime.

---

## 3. Estado real del frontend

### 3.1 Mapa de aplicaciones

| App | Puerto | Rol | LOC | Stack web3 | Estado |
|---|---|---|---|---|---|
| `web-identity` | 4001 | Inversor: identidad y claims | 3.990 | `ethers` v6 + MongoDB | Funcional por partes; flujo de claim **roto** contra ABI actual |
| `web-registry-trusted` | 4002 | Emisor: alta de issuers y aprobación | 4.145 | `ethers` v6 + MongoDB | Aprobación **sin autorización** (HW-01) |
| `web-token` | 4003 | Creador: factory y marketplace | 6.593 | `ethers` v6 + MongoDB | Crea tokens **sin claimTopicsRegistry** (HW-03) |
| `web-registry-trusted2` | — | Duplicado experimental (H-08 del informe de contratos) | 1.756 | `viem` + `wagmi` + RainbowKit | Más moderno, sin puerto ni documentación; `env.local` versionable |
| `web-rwa` | — | Landing | 164 | — | Enlaces a puertos **3004/3005/3006** (no existen) |

### 3.2 Reparto de responsabilidades de datos

Colecciones MongoDB usadas: `claim_requests`, `claim_documents` (GridFS), `tokens`, `issuers`. El acceso se hace por 16 rutas de API en 3 apps, cada una con su **propia** copia de `lib/mongodb.ts` (cache de cliente a nivel de módulo). No hay esquema compartido, ni migraciones, ni índices declarados, ni validación de entrada con librería (no hay `zod`/`yup` en ningún `package.json`).

---

## 4. Hallazgos

**Recuento: 3 CRÍTICOS · 5 ALTOS · 6 MEDIOS · 2 BAJOS = 16.**

### 4.1 Críticos (3)

#### HW-01 — CRÍTICA · Aprobación de claims sin autorización ni verificación de firma

**Evidencia.** `web-registry-trusted/app/api/update-request/route.ts:12-77`: valida que lleguen `requestId`, `status`, `issuerSignedMessage`, `issuerSignature` (`:17-26`), que `status ∈ {approved, rejected}` (`:29-38`) y que el `ObjectId` sea válido (`:41-49`)… y a continuación hace `updateOne` directo (`:55-67`). **No comprueba quién llama, no comprueba que su dirección esté en `TrustedIssuersRegistry`, no comprueba que `issuerSignature` corresponda a `issuerSignedMessage`, y no registra quién aprobó.** Un `curl` anónimo con tres cadenas arbitrarias deja una solicitud de KYC en `approved`.

**Impacto.** Es el mismo defecto de fondo que **H-01** del informe de contratos, pero trasladado a la capa de servicio: aunque los contratos verifiquen la firma EIP-712, el frontend **publica el estado "aprobado" como fuente de verdad para la UI** y cualquiera puede escribirlo. Con **H-11** (PII sin custodia), el estado aprobado habilita además la lectura de documentos.

**Recomendación.** Verificar la firma con `verifyMessage`/`recoverAddress` y exigir que el firmante sea un issuer autorizado para ese topic (lectura on-chain o cache verificada de `TrustedIssuersRegistry`); derivar `issuerAddress` de la firma, nunca del cuerpo; añadir semántica de idempotencia (no re-aprobar lo ya resuelto); registrar `reviewedBy` + evento de auditoría. Ver §7 QW-1.

#### HW-02 — CRÍTICA · Exposición pública de PII y documentos KYC (4 vectores)

**Evidencia.**
- `web-identity/app/api/claim-requests/route.ts:12-56`: `GET` sin autenticación que devuelve **todas** las solicitudes (direcciones, `message`, `signedMessage`, `signature`, `documentFileId`) y sin paginación.
- `web-identity/app/api/download/[fileId]/route.ts:11-81`: sirve el fichero por id **sin comprobar que el solicitante sea el titular o un issuer autorizado**; además se sirve `Content-Disposition: inline` con el `contentType` declarado por el cliente al subir (`:75-80`), lo que permite *stored XSS* si se falsifica el tipo (el `MIME` declarado es el único control, `upload/route.ts:41-59`).
- `web-identity/app/api/test-gridfs/route.ts:10-…`: endpoint de depuración que **lista todos los ficheros de GridFS y todas las solicitudes KYC**.
- `web-token/app/api/test-db/route.ts:10-54`: endpoint de depuración que lista todos los tokens y estadísticas de la BD.
- `web-registry-trusted/app/api/issuers/route.ts:12-45`: `POST` que hace *upsert* del **nombre visible de cualquier issuer** sin autenticación (suplantación visual de la identidad del emisor en la UI).

**Impacto.** Fuga de datos personales de inversores (documentos de identidad), incumplimiento directo del RGPD e imposibilidad de sostener el requisito de custodia que reclama **H-11**. Los endpoints `test-*` convierten la base en un volcado navegable.

**Recomendación.** Retirar los endpoints `test-*` en cualquier build no local (o protegerlos con `NODE_ENV` + token); exigir sesión verificada (SIWE/EIP-712) en todas las rutas de lectura de PII; autorizar por pertenencia (`requesterAddress` o `issuerAddress` de la sesión); forzar `Content-Disposition: attachment` y `X-Content-Type-Options: nosniff`, validar el tipo por *magic bytes* y no por `file.type`; añadir *rate limiting*. Ver §7 QW-2.

#### HW-03 — CRÍTICA · Desincronización ABI ↔ contratos: el flujo end-to-end está roto

**Evidencia.**
- `web-identity/contracts/IdentityCloneable.abi.json` declara `addClaim(_topic, _scheme, _issuer, _signature, _data, _uri)` (6 parámetros). El contrato actual exige 7, con `_expiresAt`, y `scheme == 1`, longitud 65 y `ecrecover` (`rwa-sc/sc/src/IdentityCloneable.sol:147-156`). **La llamada revierte con cualquier ABI viejo.**
- ABIs divergentes respecto a la fuente de verdad: `IdentityCloneable` md5 web `2136a456…` vs `sc/abis` `72ffbbcc…`; `IdentityCloneFactory` `1a6ce3c8…` vs `f869e227…`; `IdentityRegistry` `3459fb20…` vs `8d05832b…`.
- `web-token/components/CreateTokenForm.tsx:145` pasa `0x000…000` como `claimTopicsRegistry` a `createTokenWithRegistries`. Desde el Ciclo 6, `isVerified` es **fail-closed** sin ese registry (`rwa-sc/sc/src/TokenCloneable.sol:245-252`): el token existe pero **no verifica a ningún inversor**.
- Direcciones por defecto obsoletas: `web-registry-trusted2/lib/contracts.ts:6,11` usa `0x0165878A…` y `0x5FC8d326…`, mientras el último despliegue versionado es `TrustedIssuersRegistry = 0x67baFF…` y `ClaimTopicsRegistry = 0xafAC67…` (`rwa-sc/sc/deployments/31337-20261010T162639Z.json`).
- El ABI de `addClaim` también se **duplica inline** en `web-identity/components/RequestDetailModal.tsx:59-80` y en `web-identity/lib/identity-claims.ts:13`, tres copias que habrá que corregir a mano.

**Impacto.** El usuario percibe un flujo que existe en pantalla pero falla on-chain (o peor: "funciona" en una red antigua y no en la canónica). Es la razón principal por la que el frontend **no puede considerarse integrado** hoy.

**Recomendación.** Única fuente de verdad de ABIs: paquete compartido generado desde `rwa-sc/sc/abis/` en CI (o copia automática verificada por hash). Añadir un *gate* que falle si el hash del ABI del web difiere del de contratos. Las direcciones deben venir de un artefacto de despliegue versionado (`deployments/*.json`), nunca de literales en el código. Ver §7 QW-3.

### 4.2 Altos (5)

#### HW-04 — ALTA · Toda la superficie de escritura está sin autenticar

**Evidencia.** 16/16 rutas sin ningún primitivo de auth (`grep` de `authorization|bearer|jwt|next-auth|verifyMessage|recoverAddress|ecrecover` → 0 coincidencias). Además de HW-01:
- `web-token/app/api/tokens/route.ts` `POST`: registra un token en el marketplace sin comprobar que el llamante sea el `admin` ni que el contrato exista.
- `web-token/app/api/tokens/[tokenId]/claims/route.ts:11-44`: `POST` que sobrescribe `requiredClaims` de cualquier token por `_id`.
- `web-token/app/api/tokens/[tokenId]/{compliance,modules,price}/route.ts`: misma ausencia de control.
- `web-identity/app/api/upload/route.ts:12-113`: subida anónima a GridFS (sin cuota ni rate limit) → coste/almacenamiento a discreción de cualquiera.

**Impacto.** Integridad del marketplace y del registro de emisores comprometida: suplantación de tokens e issuers, DoS de almacenamiento. La UI confía en MongoDB como fuente de verdad, de modo que un atacante puede alterar lo que ven los emisores legítimos.

**Recomendación.** Definir un único middleware de autorización por rol (inversor / issuer autorizado / admin de token) basado en sesión SIWE con nonce + `chainId` + caducidad; exigir propiedad del recurso; validar cada cuerpo con esquema (`zod`) y rechazar campos desconocidos; limitar subida (tamaño, tasa, cuota por wallet).

#### HW-05 — ALTA · Frontend sin control de versiones, sin tests y sin CI

**Evidencia.** `rwa-web/` **no contiene `.git`** y `git -C rwa-web rev-parse --show-toplevel` falla con *not a git repository*; `rwa-sc` no rastrea ningún fichero de `rwa-web`. No existe ningún fichero `*.test.*` / `*.spec.*` ni configuración de Vitest/Jest/Playwright; el único *script* de calidad es `"lint": "eslint"` en 5 apps, sin *gate*. El pipeline existente (`rwa-sc/.gitlab-ci.yml`) cubre `build/fmt/test/coverage/gas` **solo de contratos**.

**Impacto.** 16.648 líneas sin historia, sin *rollback*, sin revisión y sin red de seguridad. Cualquier refactor (los que propone este informe) es irreversible y no verificable. Es el bloqueante estructural: sin esto, las demás mejoras no se pueden sostener.

**Recomendación.** Crear el repositorio (`rwa-web`) y publicarlo en el remoto autorizado; añadir pipeline con `lint` + `tsc --noEmit` + `build` + tests de rutas críticas, y convertir la comparación de ABIs/direcciones (HW-03) en *gate* de CI. Ver §7 M-1.

#### HW-06 — ALTA · Divergencia de dependencias y dos stacks web3 incompatibles

**Evidencia.** `next` aparece en 4 versiones (16.0.1 en `web-registry-trusted` y `web-token`; 16.1.1 en el lock de `web-identity`; 16.1.3 en `web-rwa`; 16.1.6 en `web-registry-trusted2`); `react` en 19.2.0 (×3) y 19.2.3 (×2). `web-identity/package.json` declara `next: ^16.0.12` pero su lock fija 16.1.1. El stack web3 está partido: `ethers` v6 en 3 apps (96 usos directos de `window.ethereum`) frente a `viem`+`wagmi`+`@rainbow-me/rainbowkit` en `web-registry-trusted2`. Y las 3 apps con `ethers` desactivan la comprobación de tipos en el build (`typescript.ignoreBuildErrors: true` en `web-identity/next.config.ts`, `web-registry-trusted/next.config.ts`, `web-token/next.config.ts`).

**Impacto.** Correcciones aplicadas 5 veces, vulnerabilidades parcheadas a destiempo en unas apps y no en otras, y errores de tipo que llegan a producción porque el build los ignora (`strict: true` es cosmético hoy).

**Recomendación.** Workspace único con **una** versión por dependencia (pnpm + catálogo), consolidar el stack web3 en uno solo (`wagmi`+`viem` es el que ya usa la app más nueva), quitar `ignoreBuildErrors` y saldar los errores de tipo de forma acotada por app.

#### HW-07 — ALTA · Entornos inconsistentes y direcciones hardcodeadas

**Evidencia.** `web-identity/lib/contracts.ts:7-10` apunta a Besu remoto (`https://besu1.proyectos.codecrypto.academy`, `BESU_CHAIN_ID = 0x13D52` = 81234) con direcciones literales (`:5-6`), mientras `web-registry-trusted2/lib/contracts.ts:6-20` y `web-token/lib/contracts/TokenCloneFactory.ts:374-377`, `compliance.ts:201` apuntan a Anvil local `http://localhost:8545` / `31337`. La inconsistencia llega a darse **dentro de una misma app**: `web-registry-trusted/lib/contracts/TrustedIssuersRegistry.ts:292-296` define la red como **Besu 81234**, pero su `dashboard/page.tsx:313-314` muestra al usuario la guía de **localhost:8545 / 31337**; y `web-token/lib/contracts/TokenCloneFactory.ts:6` afirma en comentario "Deployed on Besu" sobre una configuración que en realidad es Anvil. `web-rwa/app/page.tsx:2-4` enlaza a `localhost:3004/3005/3006`, puertos que no usa nadie (`start-all.sh` usa 4001/4002/4003). No existe `.env.example` en ninguna app; sólo `web-registry-trusted2/env.local` (HW-15).

**Impacto.** Mostrar "conectado" en una red y ejecutar transacciones en otra; direcciones obsoletas → llamadas a contratos inexistentes o a *proxies* de pruebas. Es una fuente silenciosa de fallos irresolubles para el usuario.

**Recomendación.** Un único módulo de configuración de red (`NEXT_PUBLIC_CHAIN_ID`, `NEXT_PUBLIC_RPC_URL`, direcciones desde artefacto de despliegue), validado al arrancar y con error explícito si `chainId` no coincide con el de la wallet. `.env.example` por app y *check* de CI que detecte literales `0x…{40}` y `localhost:` en fuente.

#### HW-08 — ALTA · El manejo de errores oculta fallos y filtra detalles internos

**Evidencia.** `web-token/app/api/tokens/route.ts:36-46` captura cualquier error de Mongo y responde **HTTP 200 con `data: []`** y el mensaje "MongoDB not available": un fallo de infraestructura es indistinguible de "no hay tokens". En sentido contrario, varias rutas devuelven `error.message` crudo al cliente (`claim-requests/route.ts:107-116`, `update-request/route.ts:87-97`, `upload/route.ts:102-112`, `download/.../route.ts:82-92`), exponiendo cadenas internas de driver/red.

**Impacto.** Fallos silenciosos en producción (el más caro: nadie se entera) y filtración de información de infraestructura al atacante.

**Recomendación.** Códigos de estado correctos (503 para dependencia caída), respuestas de error tipadas y estables, traza correlacionada en servidor (`requestId`) y mensaje genérico al cliente; nunca `error.message` de librería hacia el navegador.

### 4.3 Medios (6)

#### HW-09 — MEDIA · Duplicación estructural sin paquete compartido

**Evidencia.** `lib/mongodb.ts` es **byte-idéntico** en `web-identity`, `web-registry-trusted` y `web-token` (md5 `c8b48f41…`). `TrustedIssuersRegistry.ts` está duplicado con **300 líneas** en `web-identity/contracts/` y `web-registry-trusted/lib/contracts/`, con contenido distinto (md5 distinto). `components/RequestDetailModal.tsx` existe con 381 y 383 líneas en dos apps. `types/issuer.ts` idéntico en dos apps, mientras `types/claim-request.ts` y `types/ethereum.d.ts` divergen (mismos tipos, distinta definición). Hay **dos landings completas** en `web-registry-trusted` (`app/page.tsx`, `app/page-new-design.tsx`, `app/landing-page.tsx`) y varios ficheros de ejemplo (`lib/examples/*`) que no se usan. No existe `package.json` raíz ni workspace.

**Impacto.** Cada corrección de seguridad o de tipos debe replicarse (y se olvida). Es la deuda que explica HW-06.

**Recomendación.** Monorepo con `packages/shared` (config de red, ABIs generados, tipos, cliente Mongo, hooks de wallet, cliente de API tipado) consumido por las 3 apps que se mantengan; eliminar los ficheros muertos.

#### HW-10 — MEDIA · `web-rwa` desalineada y no arrancada

**Evidencia.** `web-rwa/app/page.tsx:2-4` apunta a 3004/3005/3006; `start-all.sh` (raíz de `rwa-web`) arranca solo 4001/4002/4003 y no menciona `web-registry-trusted2` ni `web-rwa`. El README raíz describe "3 aplicaciones" ignorando las otras dos.

**Recomendación.** Decidir el rol de `web-rwa` (portal real con enlaces correctos y configurables) y de `web-registry-trusted2` (fusionar o retirar, es el duplicado H-08), o declararlos fuera de alcance explícitamente.

#### HW-11 — MEDIA · Artefactos de build parciales presentes en el árbol

**Evidencia.** `web-identity/docker-build/`, `web-registry-trusted/docker-build/` y `web-registry-trusted2/docker-build/` contienen `Dockerfile`, `standalone/server.js`, `standalone/package.json` y assets públicos (≈48-52 KB) **sin el directorio `.next`**, por lo que **no pueden ejecutarse**: el `Dockerfile` sólo copia `standalone/` (`web-identity/docker-build/Dockerfile:9-13`) y el `server.js` de Next standalone requiere el build ausente. El cuarto proyecto (`web-token`) sí ignora `docker-build/` en su `.gitignore:11`. Además, `standalone/server.js` contiene una **ruta absoluta del desarrollador** (`/Users/joseviejo`) en los tres casos, y el `Dockerfile` usa `EXPOSE 3000` mientras las apps se sirven en 4001-4003.

**Recomendación.** Eliminar estos directorios del árbol y generar la imagen en CI (`next build` + `output: standalone` → contexto Docker reproducible y multi-stage), con `PORT` configurable.

#### HW-12 — MEDIA · Arranque y operación frágiles

**Evidencia.** `start-all.sh` arranca con `npm run dev` (modo desarrollo), mata puertos con `kill -9` y `lsof`, y sin `node_modules` presentes no puede funcionar; no hay `Dockerfile` por app, ni `docker-compose`, ni healthchecks, ni *graceful shutdown*; `stop-all.sh` se apoya en PIDs implícitos. No hay variables de entorno documentadas ni separación *dev/prod*.

**Recomendación.** Scripts de operación por entorno (`dev` con Turbopack; `prod` con build + `standalone`), contenedores con healthcheck y límites, y `docker-compose` con Mongo y el nodo de la red para un entorno local reproducible de una orden.

#### HW-13 — MEDIA · Observabilidad y calidad de código

**Evidencia.** 161 `console.log` (varios con emojis, en rutas de servidor y componentes), 67 anotaciones `any`, 96 accesos directos a `window.ethereum` sin abstracción, ausencia de *error boundaries*, de estados de error tipados y de telemetría. Sin *gate* de lint: `eslint` existe pero no bloquea nada.

**Recomendación.** Logger con niveles y correlación (sustituir `console.log`), tipo `Eip1193Provider` único o adopción de `wagmi`, `error.tsx`/`loading.tsx` por ruta, y lint estricto como paso de CI.

#### HW-14 — MEDIA · Validación de entrada sólo en el cliente; sin defensa de perímetro

**Evidencia.** No hay `zod`/`yup`/validador de esquemas en ningún `package.json`; las rutas validan campos a mano con condiciones sueltas y aceptan el resto del cuerpo (`claim-requests/route.ts:60-94` inserta el DTO tal cual; `tokens/route.ts` igual). No hay `rate limiting`, ni comprobación de `Origin`/CSRF, ni cabeceras de seguridad (`next.config.ts` no define `headers()`), ni límite de tamaño de cuerpo global (solo el chequeo de 10 MB en el upload).

**Recomendación.** Esquemas de validación compartidos en `packages/shared` aplicados en cada ruta; *middleware* con `Origin` permitido, límites por IP/wallet y cabeceras (`Content-Security-Policy`, `X-Frame-Options`, `Referrer-Policy`, `Strict-Transport-Security`).

### 4.4 Bajos (2)

#### HW-15 — BAJA · Documentación del web contradictoria y `env.local` versionable

**Evidencia.** El README raíz declara 3 apps (existen 5) y puertos que no coinciden con `web-rwa`; hay documentación duplicada y de plantilla (`QUICK_INSTALL.md`, `QUICK_REFERENCE.txt`, `DESIGN_SUMMARY.md` ×2, `README_LANDING.md`, `SETUP.sh`). `web-registry-trusted2/env.local` contiene la dirección del owner por defecto de Anvil en claro y **no está cubierto por `.gitignore`**, cuyo patrón es `.env*` (no coincide con el nombre `env.local`), de modo que quedaría versionado al crear el repositorio.

**Recomendación.** Un único README por app + README raíz con el mapa real; renombrar a `.env.local` (ignorado) y publicar `.env.example`; eliminar documentos de plantilla.

#### HW-16 — BAJA · UX y accesibilidad sin requisitos

**Evidencia.** La comunicación de errores es nativa (`alert(...)`, p. ej. `web-registry-trusted/app/dashboard/page.tsx:217,222,263,274`) e inconsistente (`console.log` para diagnóstico), hay `dark:` aplicado de forma desigual, no hay i18n ni estados de carga normalizados, y `INFORME_OPTIMIZACION_V1` dejó la usabilidad/accesibilidad como **N/A por D-003** al no incluir el web en alcance.

**Recomendación.** Con el web en alcance, definir RNF de usabilidad y accesibilidad (WCAG 2.1 AA como mínimo verificable), patrón único de notificaciones/errores y estados de carga; medir con `axe` en CI.

---

## 5. Trazabilidad

| Hallazgo web | Severidad | Refs. de contratos / decisiones |
|---|---|---|
| HW-01 | Crítica | H-01, D-007 (EIP-712) |
| HW-02 | Crítica | H-11, H-10, R-3 (política de datos) |
| HW-03 | Crítica | H-01, H-05, D-008 (Besu), H-21 (artefactos de despliegue) |
| HW-04 | Alta | H-06, H-11 |
| HW-05 | Alta | H-04, RF-009, RNF-003 |
| HW-06 | Alta | H-04 (mantenibilidad) |
| HW-07 | Alta | H-26, D-008, H-21 |
| HW-08 | Alta | H-12 (observabilidad) |
| HW-09 | Media | H-04, H-33 |
| HW-10 | Media | H-08 del informe de contratos (duplicado), D-003 |
| HW-11 | Media | H-04 (reproducibilidad) |
| HW-12 | Media | H-30 (continuidad), RNF faltantes |
| HW-13 | Media | H-12, H-09 (ISO 25010) |
| HW-14 | Media | H-10, H-17 (validación) |
| HW-15 | Baja | H-33 (documentación contradictoria) |
| HW-16 | Baja | H-09, D-003 (N/A ahora debe revisarse) |

---

## 6. Nota de verificación

Los hallazgos críticos y altos se contrastaron de forma independiente contra el sistema de ficheros por un **verificador adversarial** (contexto separado, sin acceso a las conclusiones del auditor): lectura directa de las rutas citadas, comparación de ABIs por hash, comparación de versiones entre lockfiles, `git check-ignore` para la cobertura del `.gitignore` y `grep` de primitivas de seguridad. Resultado: **15/15 afirmaciones verificadas CONFIRMADAS, 0 refutadas**; dos con corrección de matiz — (a) `docker-build/` no está "versionado" sino **presente en el árbol** (el proyecto no tiene VCS todavía), y (b) la inconsistencia de red se da también **dentro de una misma app** (HW-07 ampliado). El verificador añadió cuatro defectos que ya quedan cubiertos por HW-02 y HW-04: escritura anónima de `price/claims/modules/compliance`, *upsert* anónimo de nombres de emisor, volcado de inventario en `test-gridfs`/`test-db` y la ruta absoluta del desarrollador en `docker-build/standalone/server.js:11` (ahora en HW-11).

Las afirmaciones de este informe se limitan a lo verificado en fuente; no se ejecutó build ni test, y esa limitación está declarada en §2. Si en la revisión V2 aparece cualquier discrepancia entre este texto y el código, **prevalece el código**.

---

## 7. Plan de acción

**Esfuerzo:** S = ≤ 1 día · M = 2-5 días · L = > 1 semana.

### 7.1 Quick wins (≤ 1 semana) — contener el riesgo

| # | Acción | Hallazgo | Responsable | Esfuerzo |
|---|---|---|---|---|
| QW-1 | Verificar firma y autorización de issuer en `POST /api/update-request`; derivar el emisor de la firma; idempotencia y `reviewedBy` | HW-01 | Backend + seguridad | S |
| QW-2 | Retirar `api/test-db` y `api/test-gridfs` fuera de local; forzar `attachment` + `nosniff` en `download`; validar tipo por *magic bytes* | HW-02 | Backend | S |
| QW-3 | Regenerar ABIs desde `sc/abis/` y actualizar `addClaim` (7 args + `expiresAt`), `createIdentityWithClaim` y las direcciones desde `deployments/*.json` | HW-03 | Frontend + contratos | M |
| QW-4 | Exigir `claimTopicsRegistry` en `CreateTokenForm` (dejar de enviar `0x0`) y bloquear la creación si falta | HW-03 | Frontend | S |
| QW-5 | Crear el repositorio `rwa-web`, versionar sin secretos, renombrar `env.local` → `.env.local` y añadir `.env.example` | HW-05, HW-15 | DevOps | S |
| QW-6 | Devolver `503`/error tipado en lugar de `200 []`, y dejar de exponer `error.message` al cliente | HW-08 | Backend | S |
| QW-7 | Añadir `tsc --noEmit` + `eslint` como pasos obligatorios y retirar `ignoreBuildErrors` de una app piloto | HW-06, HW-13 | Frontend | S |
| QW-8 | Corregir los enlaces de `web-rwa` y documentar qué apps están en alcance | HW-10, HW-15 | Frontend | S |
| QW-9 | Borrar `docker-build/` parciales del árbol y añadirlo al `.gitignore` raíz | HW-11 | DevOps | S |
| QW-10 | Unificar `next`/`react` a una versión con `pnpm` (aunque sea sólo fijando los lockfiles) | HW-06 | DevOps | S-M |

### 7.2 Mejoras (2-4 semanas) — cerrar la brecha estructural

| # | Acción | Hallazgo | Responsable | Esfuerzo |
|---|---|---|---|---|
| M-1 | CI del web: `lint` + `tsc --noEmit` + `build` + tests (Vitest para rutas y hooks, Playwright para el flujo claim→aprobación) | HW-05 | DevOps + QA | M |
| M-2 | Sesión SIWE/EIP-712 + middleware de autorización por rol y propiedad de recurso en las 16 rutas | HW-01, HW-04 | Backend + seguridad | L |
| M-3 | Monorepo pnpm + `packages/shared`: config de red, ABIs generados, tipos, cliente Mongo, cliente de API tipado, esquemas `zod` | HW-06, HW-09, HW-14 | Arquitectura | L |
| M-4 | Pipeline de sincronización de ABIs/direcciones con *gate* por hash contra `rwa-sc` | HW-03, HW-07 | DevOps | M |
| M-5 | Configuración de red única validada al arranque (`chainId` + RPC + direcciones) y eliminación de literales | HW-07 | Frontend | M |
| M-6 | Validación de entrada con esquemas en todas las rutas + cabeceras de seguridad + rate limiting + límites de subida | HW-02, HW-14 | Backend | M |
| M-7 | Logging estructurado, `error.tsx`/`loading.tsx`, telemetría básica y eliminación de `console.log` de rutas | HW-13 | Frontend | M |
| M-8 | Entorno reproducible: `docker-compose` (3 apps + Mongo + nodo) con healthchecks y build de producción | HW-12, HW-11 | DevOps | M |
| M-9 | Eliminar ficheros muertos y landings duplicadas; decidir el destino de `web-registry-trusted2` y `web-rwa` | HW-09, HW-10 | Frontend | S-M |
| M-10 | Consolidar el stack web3 en `wagmi`+`viem` y eliminar los 96 usos directos de `window.ethereum` | HW-06 | Frontend | L |

### 7.3 Roadmap (1-3 meses) — calidad sostenida

| # | Acción | Hallazgo | Responsable | Esfuerzo |
|---|---|---|---|---|
| R-1 | Unificar los 5 proyectos en **3 apps** (inversor / emisor / token) sobre el monorepo, con `web-rwa` como portal | HW-09, HW-10 | Arquitectura | L |
| R-2 | Cifrado de documentos KYC en reposo, control de acceso por propiedad y política de retención/supresión alineada con `R-3` de contratos | HW-02 | Backend + legal | L |
| R-3 | RNF web ISO 25010 (disponibilidad, usabilidad/accesibilidad WCAG 2.1 AA, mantenibilidad, portabilidad) con criterios medibles y verificación en CI (`axe`, Lighthouse) | HW-16, HW-13 | PM + frontend | M |
| R-4 | Observabilidad de extremo a extremo: correlación UI ↔ API ↔ eventos on-chain (enlaza con `R-4` de contratos) | HW-08, HW-13 | Arquitectura | L |
| R-5 | Estrategia de despliegue y *rollback* (imágenes versionadas, entornos dev/staging/prod, migraciones de MongoDB con índices) | HW-05, HW-12 | DevOps | M |

---

## 8. Criterios de aceptación para la V2 web

**Bloqueantes (B) — sin ellos no se promociona la versión:**

- **B-1 (HW-01/HW-04):** ninguna ruta que muta estado acepta una petición sin sesión verificada; la aprobación de claims exige firma válida de un issuer autorizado para el topic, derivada de la propia firma; existe test que demuestra que un `POST` anónimo es rechazado.
- **B-2 (HW-02):** no existe ningún endpoint público que devuelva PII, documentos o estadísticas de la base; `download` exige propiedad; los endpoints `test-*` están ausentes del build de producción.
- **B-3 (HW-03/HW-07):** ABIs y direcciones provienen de artefactos versionados de `rwa-sc` y un *gate* de CI falla si hay deriva; el flujo completo identidad → solicitud → aprobación → `addClaim` firmado → `isVerified` funciona en la red canónica contra los contratos actuales.
- **B-4 (HW-05):** `rwa-web` existe como repositorio con todo el árbol versionado (sin secretos) y CI que ejecuta lint, `tsc --noEmit`, build y tests en cada MR.
- **B-5 (HW-06):** una sola versión de `next`/`react` en todas las apps; `ignoreBuildErrors` eliminado; `tsc --noEmit` en verde.
- **B-6 (HW-08):** ninguna ruta devuelve `200` ante un fallo de dependencia y ninguna devuelve `error.message` de librería al cliente.

**De calidad (C):**

- **C-1 (HW-09/HW-14):** existe `packages/shared` con config de red, tipos, ABIs y esquemas de validación; 0 copias duplicadas de `mongodb.ts` y `TrustedIssuersRegistry`.
- **C-2 (HW-12/HW-11):** un entorno local reproducible con una orden (compose) y una imagen de producción por app, con healthcheck.
- **C-3 (HW-13):** 0 `console.log` en rutas/componentes de producción, logger estructurado y `error.tsx` por ruta.
- **C-4 (HW-10/HW-15):** README raíz con el mapa real de apps y puertos; 0 documentos de plantilla duplicados; enlaces del portal correctos y configurables.
- **C-5 (HW-16):** RNF web aprobados con umbral verificable y medición en CI (accesibilidad AA, presupuesto de rendimiento, cobertura mínima de tests de rutas críticas).

**Condición de salida:** el frontend se declara **apto para producción con activos reales** solo cuando cierra B-1…B-6, C-1…C-5 y supera la auditoría externa prevista en `R-9` del informe de contratos. Hasta entonces permanece **NO apto**.

---

## 9. Decisiones que se solicitan al usuario

| # | Decisión | Opciones | Impacto |
|---|---|---|---|
| W-1 | Alcance del ciclo | (a) solo hardening de los 3 apps en uso; (b) hardening + consolidación en monorepo; (c) rediseño unificado en 3 apps | Determina el esfuerzo total y si `web-registry-trusted2`/`web-rwa` sobreviven |
| W-2 | Modelo de sesión del frontend | (a) SIWE + cookie firmada; (b) sólo firma por operación; (c) delegación on-chain de permisos | Define cómo se implementa B-1 y B-2 |
| W-3 | Red canónica del web | (a) Anvil local 31337 (coherente con `deployments/`); (b) Besu CodeCrypto 81234 (coherente con `web-identity`) | Hoy conviven las dos y eso rompe la integración |
| W-4 | Fuente de verdad de ABIs | (a) paquete generado en CI desde `sc/abis`; (b) submódulo/sync script | Condiciona HW-03 y su verificación |
| W-5 | Custodia de documentos KYC | (a) GridFS cifrado con acceso por propiedad; (b) almacenamiento externo (S3/GCS) con URLs firmadas | Define el alcance de HW-02 y de R-2 |

---

## Anexo A — Inventario de rutas de API y control de acceso

| App | Ruta | Métodos | Auth | Autorización | Riesgo principal |
|---|---|---|---|---|---|
| web-identity | `/api/claim-requests` | GET, POST | ❌ | ❌ | GET: fuga de PII; POST: firma no verificada (HW-02, HW-04) |
| web-identity | `/api/upload` | POST | ❌ | ❌ | DoS de almacenamiento (HW-04) |
| web-identity | `/api/download/[fileId]` | GET | ❌ | ❌ | IDOR de documentos KYC (HW-02) |
| web-identity | `/api/issuers/batch` | POST | ❌ | ❌ | Resolución masiva de nombres de emisor sin auth |
| web-identity | `/api/test-gridfs` | GET | ❌ | ❌ | Volcado de PII (HW-02) |
| web-registry-trusted | `/api/update-request` | POST | ❌ | ❌ | **Aprobación de KYC por cualquiera (HW-01)** |
| web-registry-trusted | `/api/issuer-requests` | GET | ❌ | ❌ | Fuga de solicitudes |
| web-registry-trusted | `/api/issuers` | POST, GET | ❌ | ❌ | Suplantación de nombre de emisor; enumeración (HW-02) |
| web-registry-trusted | `/api/issuers/batch` | POST | ❌ | ❌ | Resolución masiva sin auth |
| web-registry-trusted | `/api/download/[fileId]` | GET | ❌ | ❌ | IDOR de documentos KYC |
| web-token | `/api/tokens` | GET, POST | ❌ | ❌ | POST: registro de token falso (HW-04) |
| web-token | `/api/tokens/[tokenId]/claims` | POST | ❌ | ❌ | Alteración de requisitos (HW-04) |
| web-token | `/api/tokens/[tokenId]/compliance` | POST | ❌ | ❌ | Alteración de compliance (HW-04) |
| web-token | `/api/tokens/[tokenId]/modules` | POST | ❌ | ❌ | Alteración de módulos (HW-04) |
| web-token | `/api/tokens/[tokenId]/price` | POST | ❌ | ❌ | Alteración de precio (HW-04) |
| web-token | `/api/test-db` | GET | ❌ | ❌ | Volcado de BD (HW-02) |

**Total: 16 rutas y 20 manejadores HTTP · 0 con autenticación · 0 con autorización por recurso.**

---

## Anexo B — Comandos de reproducción de la evidencia

```bash
# 1. Superficie y tamaño
cd /home/dsh/workspace/RWA/rwa-web
find . -path '*/app/api/*/route.ts' -not -path '*/node_modules/*' | wc -l   # 16 rutas

# 2. Ausencia total de autorización / verificación de firma
grep -rniE "authorization|bearer|jwt|next-auth|verifyMessage|recoverAddress|ecrecover" \
  --include='*.ts' --include='*.tsx' . | grep -v node_modules      # 0 coincidencias

# 3. Sin control de versiones
git -C /home/dsh/workspace/RWA/rwa-web rev-parse --show-toplevel  # fatal: not a git repository

# 4. Deriva de ABIs (hashes distintos)
md5sum web-identity/contracts/IdentityCloneable.abi.json \
       /home/dsh/workspace/RWA/rwa-sc/sc/abis/IdentityCloneable.json

# 5. Firma actual de addClaim en contratos (7 parámetros + EIP-712)
grep -n "function addClaim" -A 10 /home/dsh/workspace/RWA/rwa-sc/sc/src/IdentityCloneable.sol

# 6. Fail-closed de isVerified (token creado desde el web no verifica a nadie)
grep -n "claimTopicsRegistry == address(0)" -A 3 /home/dsh/workspace/RWA/rwa-sc/sc/src/TokenCloneable.sol

# 7. Divergencia de versiones
for d in web-identity web-registry-trusted web-registry-trusted2 web-rwa web-token; do
  grep -m1 '"node_modules/next"' -A2 $d/package-lock.json
done
```

---

*Fin del informe — INFORME_OPTIMIZACION_WEB_V1.md*
