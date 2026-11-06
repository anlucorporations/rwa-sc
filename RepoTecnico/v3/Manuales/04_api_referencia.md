# 4. Referencia de API (Metaplace)

> Convención: respuestas `{ success: boolean, data?: …, error?: { code, message } }`.
> Autenticación: cookie `rwa_session` emitida por `/api/auth/verify`.

## 4.1 Autenticación

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| POST | `/api/auth/nonce` | pública (rate-limited) | reto SIWE para una wallet |
| POST | `/api/auth/verify` | pública | verifica firma y emite cookie (nonce de un solo uso) |
| GET | `/api/auth/session` | cookie | sesión actual (401 si no) |
| POST | `/api/auth/logout` | cookie | revoca sesión y borra cookie |

## 4.2 Identidad y certificados

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| GET/POST | `/api/identity` | sesión | consulta/crea identidad seudónima |
| GET | `/api/access` | sesión | `hasKyc`, `hasSocio`, credenciales aprobadas |
| GET | `/api/issuer-programs` | pública | ISSUER activos y claims que emiten |
| GET/POST | `/api/claims` | sesión | historial / solicitud con documento cifrado |
| GET/POST | `/api/claims/{id}/verify` | Operador/Admin | verificación documental |
| POST | `/api/claims/{id}/reject` | Operador/Admin | rechazo con motivo (retención Q10) |
| GET | `/api/claims/{id}/typed-data` | Emisor/Admin | EIP-712 del claim |
| POST | `/api/claims/{id}/issue` | Emisor/Admin | emisión firmada → `approved` |
| GET | `/api/claims/{id}/documents` | titular/Operador/Admin | metadatos (incl. retención) |
| GET | `/api/documents/{id}` | titular/Operador/Admin | descarga descifrada |

## 4.3 Activos y marketplace

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| POST/GET | `/api/assets` | Emisor/Admin | tokenización (GARANTÍA+FIADOR+consentimiento) / mis activos |
| GET | `/api/assets/consent-message` | pública | texto legible que firma el Fiador |
| GET | `/api/catalog` | pública | catálogo de activos publicados |
| GET/POST | `/api/listings` | pública / sesión+SOCIO | publicaciones a precio fijo |
| POST/GET | `/api/orders` | sesión+SOCIO | compra con doble escrow / mis órdenes |
| POST | `/api/orders/{id}/confirm` | comprador | confirma recepción y libera pago |
| POST | `/api/orders/{id}/dispute` | comprador | abre disputa |
| POST | `/api/orders/{id}/resolve` | `arbiter`/Admin | reembolso o liberación |
| POST | `/api/services/{tokenId}/consume` | SOCIO+compra | consumo de servicio (idempotente) |

## 4.4 Administración y sistema

| Método | Ruta | Auth | Descripción |
|---|---|---|---|
| GET/POST | `/api/admin/issuer-programs` | Admin | CRUD de ISSUER |
| PATCH | `/api/admin/issuer-programs/{id}` | Admin | activar/desactivar |
| GET/POST | `/api/admin/roles` | Admin | listar/conceder roles |
| POST | `/api/admin/roles/{id}/revoke` | Admin | revocar (efecto inmediato) |
| GET | `/api/system` | Admin/Auditor | snapshot de salud y colas |

## 4.5 Códigos de estado

`400` validación · `401` sin sesión · `403` sin permiso/rol · `404` inexistente · `409` conflicto de estado/duplicado · `429` rate limit · `500` error interno (sin detalles sensibles).
