# Modelo de amenazas v3 (RNF-V3-15) — pre-piloto

> **Alcance:** Metaplace (3 suites), claim/KYC, tokenización, marketplace con escrow.
> **Método:** STRIDE sobre activos y flujos, con mitigaciones y criterio de aceptación.

## 1. Activos a proteger

| Activo | Confidencialidad | Integridad | Disponibilidad |
|---|---|---|---|
| Documentos KYC (PDF/imagen) | 🔴 alta | 🔴 alta | 🟡 media |
| Claves de emisión (BRLT, issuer) | 🔴 alta | 🔴 alta | 🔴 alta |
| Claims y certificados (SOCIO, GARANTÍA, FIADOR) | 🟡 media | 🔴 alta | 🟡 media |
| Órdenes y pagos en BRLT | 🟡 media | 🔴 alta | 🟡 media |
| Identidad seudónima (alias/wallet) | 🟡 media | 🟡 media | 🟢 baja |
| Auditoría (`audit_log`) | 🟡 media | 🔴 alta | 🟢 baja |

## 2. Actores y confianza

- **Usuario/inversor** (SIWE): no confiable en entrada; autenticado por firma.
- **Emisor/Operador/Árbitro**: confianza media, acotada por RBAC y segregación de funciones.
- **Admin**: confianza alta, acciones auditadas; nunca puede aprobar su propia solicitud.
- **Servicios externos**: RPC (Anvil), Cloud SQL, Secret Manager, GCS.

## 3. Amenazas y mitigaciones (STRIDE)

| # | Amenaza | Vector | Mitigación | Criterio |
|---|---|---|---|---|
| T1 | Suplantación de wallet | Reutilizar nonce SIWE | Nonce de un solo uso, dominio/uri/chainId validados, cookie HMAC `httpOnly`+`SameSite=Strict` | 401 en nonce reutilizado (E2E C1) |
| T2 | Escalada de privilegios | Rol autodeclarado | RBAC en servidor contra `role_assignments` vigentes en cada petición | 403 por rol (E2E C2) |
| T3 | Fuga de documentos KYC | Acceso directo a `/api/documents` | Cifrado AES-256-GCM en reposo, autorización titular/Operador/Admin, `nosniff` | 401/403 en descarga ajena (E2E C1) |
| T4 | Manipulación de claims | Reutilizar firma EIP-712 | `chainId`, `verifyingContract`, `dataHash`, `nonce`, `expiry` firmados; emisor autorizado por programa | Firma inválida → 400 (E2E C1) |
| T5 | Fraude en el marketplace | Confirmar sin pago o sin activo | Escrow de dos tramos (BRLT + activo), triggers de estado, verificación de recibos on-chain | Confirmar sin ambos tramos → rechazo (DDL/E2E C4) |
| T6 | Repudio de compra/venta | Disputa sin evidencia | Firma de intención del comprador, `disputes` con motivo y árbitro separado | Intent manipulada → 400 (E2E C4) |
| T7 | Doble gasto de inventario | Comprar más que el stock | `remaining_quantity` y triggers de reserva/consumo | Segunda compra sobre stock 1 → rechazo |
| T8 | Abuso/DoS | Fuerza bruta en auth, subida masiva | Rate limiting por IP/wallet, límites de tamaño/tipo, cuotas | 429 tras umbral (C5) |
| T9 | Filtración de secretos | Claves en repo/logs | Secret Manager, variables server-only, `.gitignore`, rotación | `verificar_artefactos` + revisión |
| T10 | Replay de consentimiento de fianza | Reutilizar firma legible | Mensaje incluye activo; firma verificada contra wallet del fiador | Firma de otro texto → 400 (E2E C3) |
| T11 | Borrado de auditoría | UPDATE/DELETE en `audit_log` | Trigger append-only | Update/delete rechazado (DDL) |
| T12 | Suplantación de ISSUER | Emisor sin claims | Requisitos del ISSUER + claims previos + emisor autorizado por programa | 409/403 (E2E C1/C3) |

## 4. Riesgos residuales (pre-piloto)

1. **Rate limiting** implementado a nivel de app; falta WAF/Cloud Armor en el borde (C5/C6).
2. **Anvil GCP** es una red de desarrollo sin alta disponibilidad ni backup transaccional; para piloto debe
   sustituirse por una red persistente/gestionada.
3. **Claves de rol** gestionadas con Secret Manager; falta rotación periódica documentada (C6).
4. **Exportación de auditoría** limitada a metadatos (Q18) — revisar requisitos legales antes de piloto.

## 5. Verificación

- Tests/E2E citados en el acta C1/C2/C3/C4 (matriz de roles, 401/403/400, doble escrow, retención Q10).
- `verificar_artefactos.py` en PASS como gate de documentación y consistencia.
