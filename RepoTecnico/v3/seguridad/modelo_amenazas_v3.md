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
| T13 | CSRF sobre mutaciones | Petición cruzada con cookie | `SameSite=Strict` + cookie `__Host-`/`Secure` + guardia de `Origin` en middleware | ✅ sin/mal Origin → 403 (E2E C6) |
| T14 | Falta de trazabilidad de mutaciones | Operaciones sin registro | `audit_log` en claims, órdenes, disputas, roles, ISSUER, descargas KYC y consumo | E2E auditoría 4/4 (order/role) |
| T15 | Acceso no trazado a documentos KYC | Staff descarga sin registro | Evento `kyc.document.downloaded` con `asStaff` | Evidencia en `audit_log` |

## 4. Revisión adversarial externa (2026-11-06)

**Veredicto: NO APTO (pre-piloto)** — informe completo en
[revision_adversarial_modelo_amenazas_2026-11-06.md](revision_adversarial_modelo_amenazas_2026-11-06.md).
3 hallazgos críticos (AM-01 escrow sin verificación on-chain, AM-02 propiedad/supply del listing,
AM-03 claims/SOCIO sin anclaje on-chain) y 8 altos. Se añaden las amenazas ausentes señaladas:

| # | Amenaza | Estado del control |
|---|---|---|
| T16 | Gobernanza/cadena de suministro on-chain (roles en EOA, sin multisig/timelock, Marketplace sin pausa, bytecode/SBOM) | 🔴 pendiente (AM-10) |
| T17 | Propiedad y estado del listing/liquidación on-chain (token ajeno, cantidad inventada, tx reusada) | 🟡 parcial: `quantity=1` y trigger de estado; propiedad on-chain pendiente (AM-02) |
| T18 | Recuperación de identidad y 4-eyes (`identity_recovery_requests` sin flujo) | 🔴 pendiente |
| T19 | Secuestro de sesión/XSS (CSP con `unsafe-inline`, sin re-auth admin ni revocación global) | 🟡 parcial: cookie `__Host-`+`Secure`, `SameSite=Strict`, guardia de `Origin`, allowlist host/proto; faltan re-auth admin, TTL rolling y CSP con nonce (AM-09) |
| T20 | Privacidad y GDPR (wallet pública, staff con acceso global a KYC, sin DPIA/DSAR) | 🟡 parcial: DTO sin wallet y auditoría de descargas; DPIA/DSAR pendientes (AM-07) |
| T21 | Continuidad RPC/GCP y abuso (billing, RPC único, reorg, reembolso de escrow huérfano) | 🔴 pendiente (AM-11) |

### Correcciones ya aplicadas tras la revisión

| Hallazgo | Corrección | Evidencia |
|---|---|---|
| AM-04 (revocación) | `POST /api/claims/{id}/revoke` con RBAC por programa, motivo y cascada de triggers | E2E C6: SOCIO revocado → acceso y compra denegados |
| AM-05 (ámbito RBAC) | `assertProgramScope` en typed-data/issue/revoke y cola filtrada por programa | E2E C6: emisor de KYC no opera sobre `onboarding-socio` (403) |
| AM-06 (auditoría) | Auditoría de tokenización, publicación, solicitud, revocación y descargas | E2E: `listing.created`, `order.*`, `claim.revoked` |
| AM-07 (privacidad) | DTO público sin `seller_wallet` | `lib/market.ts` |
| AM-13 (intención) | Intención obligatoria y mensaje canónico reconstruido en servidor | E2E C6: sin/alterada → 400; válida → 201 |
| AM-15 (subida) | Máx. 5 documentos y 50 MB por solicitud | E2E C6: 6 ficheros → 400 |
| AM-16 (arbitraje) | Prohibido que el árbitro sea comprador/vendedor | E2E C6: 403 |

Los hallazgos AM-01/02/03/08/09/10/11/12/14/17 y las amenazas T16/T18/T21 quedan en el **roadmap
priorizado** del informe de revisión (no son aceptables para el piloto hasta cerrarse).

## 5. Riesgos residuales (pre-piloto)

1. **Rate limiting** implementado a nivel de app; falta WAF/Cloud Armor en el borde (C5/C6).
2. **Anvil GCP** es una red de desarrollo sin alta disponibilidad ni backup transaccional; para piloto debe
   sustituirse por una red persistente/gestionada.
3. **Claves de rol** gestionadas con Secret Manager; falta rotación periódica documentada (C6).
4. **Exportación de auditoría** limitada a metadatos (Q18) — revisar requisitos legales antes de piloto.
5. **Validación de `Origin`** en mutaciones autenticadas: pendiente (mitigación parcial por `SameSite=Strict`).
6. **Revisión adversarial externa** del propio modelo: en curso; los hallazgos de la revisión interna ya
   están aplicados (T13–T15 y auditoría instrumentada).

## 5. Verificación

- Tests/E2E citados en el acta C1/C2/C3/C4 (matriz de roles, 401/403/400, doble escrow, retención Q10).
- `verificar_artefactos.py` en PASS como gate de documentación y consistencia.
