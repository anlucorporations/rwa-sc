# Revisión adversarial del modelo de amenazas — informe

> **Fecha:** 2026-11-06 · **Revisor:** equipo de auditoría (verificación adversarial)
> **Versión evaluada:** `modelo_amenazas_v3.md` md5 `1f60391663a30b8e64af63108b3a7379` (incluye T13–T15)
> **Veredicto: NO APTO (pre-piloto)** — 3 hallazgos críticos y 8 altos.

## Resumen

El modelo no es una base fiable para el gate RNF-V3-15: varias mitigaciones declaradas no coinciden
con el código (T4, T5, T6, T7, T8, T9, T10, T14) y faltan amenazas de gobernanza/cadena de suministro
on-chain, recuperación de identidad, privacidad/GDPR, continuidad GCP/RPC y consumo de servicios.
T13–T15 se añadieron durante la revisión; T13 sigue con criterio "pendiente" y T14 no cubre
tokenización/publicación/subida.

## Hallazgos

| ID | Sev. | Amenaza | Corrección propuesta | Tipo |
|---|---|---|---|---|
| AM-01 | Crítica | Escrow/confirmación sin verificación on-chain efectiva (tx falsas, reusadas, otro importe; `CHAIN_VERIFY_TX` opcional y tramo del activo tomado del listing) | Verificación fail-closed con logs `ListingPurchased/Completed`, `listingId`, comprador, importe y ambos tramos; confirmar con tx de `confirmReceipt`/liquidación server-side | Código |
| AM-02 | Crítica | Cualquier SOCIO publica tokens ajenos con cantidad inventada; ERC-721 vendible varias veces | Ligar vendedor al propietario on-chain/off-chain, verificar `ownerOf`/balance y escrow; `quantity=1` en ERC-721 y tope de supply; token registrado por `AssetFactory` | Código |
| AM-03 | Crítica | Claims/SOCIO solo en BD, sin `addClaim` on-chain; payload EIP-712 no anclado (chainId, clon, claimNonce, expiry, dataHash) | Exigir recibo/`isVerified`, anclar payload y usar el helper de consistencia; no aprobar sin tx verificada | Código |
| AM-04 | Alta | No existe endpoint de revocación de claims (la cascada de triggers queda inerte) | Revocación con RBAC por programa, motivo, auditoría y efecto inmediato | Código |
| AM-05 | Alta | RBAC sin ámbito: emisor del programa A opera sobre B | Resolver `issuer_program_id` por recurso y filtrar todas las consultas | Código |
| AM-06 | Alta | Auditoría best-effort, sin `request_id`/IP, sin eventos de tokenización/publicación/subida | Auditoría en la misma transacción, `request_id`/IP/actor/rol, export CSV firmado | Código/Operación |
| AM-07 | Alta | Privacidad: DTO público expone wallet del vendedor; staff global accede a todo KYC; sin DPIA/DSAR | DTO público solo con alias; acceso KYC por programa; DPIA y DSAR ≤30 días | Código/Documentación |
| AM-08 | Alta | Rate limiting débil (memoria por instancia, XFF spoofeable, sin alertas ni `Retry-After`) | WAF + almacén distribuido, IP de confianza, cobertura completa | Código/Operación |
| AM-09 | Alta | Sesión/origen: `X-Forwarded-Host/Proto` sin allowlist, `Secure` condicional, TTL fijo, sin re-auth admin, CSP con `unsafe-inline` | Allowlist, cookie `__Host-`+`Secure`, TTL corto/rolling, re-auth, `Origin`, CSP con nonce | Código |
| AM-10 | Alta | Gobernanza/cadena de suministro: roles en EOA sin multisig/timelock, Marketplace sin pausa, direcciones hardcodeadas, gate de deriva elige artefacto v2 | Multisig+timelock, árbitro separado, pausa de emergencia, direcciones desde artefacto v3, verificación de bytecode/fuente, SBOM | Operación/Código |
| AM-11 | Alta | Continuidad: un solo proyecto/región/Anvil/Cloud SQL; sin failover RPC, RTO/RPO ni reembolso de escrow huérfano | Alertas de billing, runbook, failover RPC, reconciliación de escrow, simulacro RTO/RPO | Operación |
| AM-12 | Media | Consumo de servicio con carrera (SELECT+INSERT), idempotencia global por token y sin quema on-chain | Unique por orden/titular/token, llamada on-chain `consumeService` y verificación de recibo | Código |
| AM-13 | Media | Replay de consentimiento/intención EIP-191 sin dominio/nonce/expiry; intención opcional | EIP-712 con dominio, partes, precio, listingId, nonce y expiry; exigir y reconstruir en servidor | Código |
| AM-14 | Media | Clave KYC única sin versión/rotación, sin AAD | Envelope encryption con `key_id`, AAD, migración legacy y rotación | Código/Operación |
| AM-15 | Media | KYC sin límite de ficheros/bytes por petición, sin cuota ni AV | Límites por petición y wallet, streaming, cuarentena AV | Código |
| AM-16 | Media | Disputas: árbitro puede ser parte, sin evidencia ni plazos | Prohibir árbitro parte, evidencias, plazos y doble control | Código |
| AM-17 | Media | `chain_events` del indexer desalineado con el esquema canónico (INSERT fallaría) | Alinear DDL/INSERT y test de integración | Código |
| AM-18 | Media | El modelo sobredeclara cobertura (T14 incompleto; doc técnico lista contratos inexistentes; conteos inconsistentes) | Actualizar modelo/documento técnico a la implementación real con matriz RNF→amenaza→control→test | Documentación |

## Amenazas ausentes recomendadas

1. Gobernanza y cadena de suministro on-chain (multisig/timelock, pausa, bytecode, SBOM).
2. Propiedad/estado del listing y liquidación on-chain (extiende T5/T7).
3. Recuperación de identidad y 4-eyes (tabla `identity_recovery_requests` sin flujo).
4. Secuestro de sesión/cuenta privilegiada y XSS (T13 solo CSRF).
5. Privacidad y GDPR (wallet pública, staff, DSAR, transferencias).
6. Continuidad RPC/GCP y abuso de servicio (billing, reorg, failover, replay).

## Plan priorizado (10 acciones)

1. Escrow fail-closed con logs/eventos e importe/listing/comprador (AM-01).
2. Propiedad y supply del activo; token registrado y escrow existente (AM-02).
3. Claims/SOCIO on-chain y EIP-712 anclado (AM-03).
4. Revocación, recuperación 4-eyes y RBAC por ámbito (AM-04/05).
5. Auditoría transaccional, `request_id`/IP, export firmado e indexer alineado (AM-06/17).
6. Sesión y borde web: allowlist, cookie `__Host-`, TTL, re-auth, `Origin`, CSP (AM-09).
7. Anti-abuso: WAF, rate limit distribuido, cuotas de subida y alertas (AM-08/15).
8. Claves y cadena de suministro: multisig+timelock, árbitro separado, pausa, SBOM (AM-10).
9. Privacidad: DTO sin wallet, acceso KYC por programa, DPIA/DSAR (AM-07).
10. Continuidad: alertas, failover RPC, reconciliación de escrow, simulacro RTO/RPO (AM-11).

## Nota de método

Se revisaron modelo, requerimientos (RNF-V3-15), documento técnico, casos de uso, actas C1–C5, incidente,
`rwa-web/apps/metaplace`, `packages/shared` y `rwa-sc/sc/src/v3`. El árbol se modificó durante la
revisión: si cambia el modelo o el código, hay que revalidar los criterios.
