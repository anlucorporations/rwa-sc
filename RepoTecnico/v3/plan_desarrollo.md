# Plan de desarrollo — RWA v3 «Barlo Metaplace» (Fase 3)

> **Versión:** v3.2 · **Fecha:** 2026-11-04 · **Fase:** 3 (Desarrollo)
> **Base:** Fase 1 cerrada como baseline (Q14a) · Fase 2 cerrada (29 CU + documento técnico auditados,
> Q15–Q24 resueltas por defecto).
> **Regla:** cada ciclo es una **entrega 100 % operativa y verificable**; no se avanza sin acta de
> evidencia y sin cerrar los gates de su ámbito. Ciclos verticales (funcionalidad completa), no por capas.

---

## 1. Estrategia y reglas

- **Rama de trabajo:** `rwa-web-DSH-GCP-v3` en `rwa-sc` y `rwa-web` (v2 congelada; `main` intacta).
- **Entorno canónico:** GCP `mcc-ecommerce` (Cloud Run) + Anvil GCP (chain 31337) + Cloud SQL
  `truekeate-db-dev`, esquema `rwa`. Sin nodos ni BD nuevos.
- **Definition of Done (DoD) de cada ciclo:**
  1. Código/contratos/DDL en la rama, compilando y con tests en verde.
  2. Migraciones versionadas (`schema_migrations`) y `base_datos.sql`/diccionario/ER sincronizados.
  3. Despliegue en GCP verificado (`deploy_gcp.sh verify`) si aplica.
  4. **Acta de evidencia** en `RepoTecnico/pruebas/<ciclo>_<fecha>.md` con números reales.
  5. Gates del ciclo en **CUMPLE** y 0 ALTAS abiertas del ámbito.
  6. Documentación actualizada (estado + artefacto del ciclo).
- **Sin push a `main`** ni a las ramas v2. Sin secretos en el repo.
- **Decisiones Q15–Q24** aplicadas: wizard de 4 pasos, soporte in-app con SLA 24 h, JURISDICCIÓN
  diferida, exportación de auditoría solo metadatos, Q14a ratificada, threat model/rate limiting
  exigibles antes de piloto, firma EIP-712 de fianza legible, dueño nominal por componente,
  servicios=ERC-721 / productos=ERC-1155 / bienes=ERC-721, RF-26 y RF-28 transversales sin CU.
- **D-V3-27 (alcance):** el consentimiento de fianza (CU-07) se implementa en **C3** junto con la
  tokenización y `token_guarantees` (requiere claim FIADOR aprobado y token existente); se retira de C2.

---

## 2. Secuencia de ciclos

```
C0 Fundación ──▶ C1 Identidad/Socio ──▶ C2 ISSUER/Claims ──▶ C3 Tokenización ──▶ C4 Mercado/Escrow
                                                    │                                    │
                                                    └──────────────▶ C5 Firma/Admin/Sistema ◀──┘
                                                                                  │
                                                                                  ▼
                                                                          C6 Endurecimiento
```

Dependencias: C0 → C1 → C2 → C3 → C4 → C5 → C6 (C5 puede solaparse con C4 al 50 %).

---

## 3. C0 — Fundación (infra + BRLT + migración real)

**Objetivo:** dejar la base operativa de la v3 desplegada y verificable, sin funcionalidad de negocio.

| # | Tarea | Entregable |
|---|---|---|
| T0.1 | Crear ramas y estructura: `apps/metaplace` (shell), `packages/wallet-messages`, `sc/src/v3/` | esqueleto que compila |
| T0.2 | `BarloToken` (ERC-20, 8 dec, cap 100 M, maxMintPerTx 10 k, pausable, roles, multisig+timelock) | contrato + tests Foundry |
| T0.3 | Migración real v2→v3 en CI contra `pg_dump` v2 (script §6 verificado) | pipeline `artefactos-v3` + job `migracion-v3` en verde |
| T0.4 | Claves dedicadas por rol en Secret Manager + gate CI anti-cuentas Anvil | rotación aplicada + gate |
| T0.5 | Infra: Cloud SQL backups/PITR, pool, RPC fallback, Cloud Run Job `rwa-jobs` + Scheduler | `deploy_gcp.sh` actualizado + verify |
| T0.6 | CI: `validate` con `artefactos-v3`, `build`, `test`, `coverage` ≥ 80 % de contratos | pipeline en verde en la rama |

**Gates de salida (C0):**
- BRLT desplegado en Anvil GCP con cap/límites/multisig verificados on-chain.
- Migración v2→v3 ejecutada en CI con conteos cuadrados (claims/docs/tokens/required_claims).
- 0 wallets de rol coinciden con cuentas de Anvil (gate).
- Backup/PITR y restore drill documentados (**B8**), RPO/RTO medidos.
- Jobs `expire_orders` y `purge_documents` aprovisionados (invocación de prueba).

**Riesgos:** contratos v3 sin auditar (mitiga: auditoría externa antes de C4); migración real (mitiga: CI con dump).
**Esfuerzo:** 2 semanas.

---

## 4. C1 — Identidad y Socio

**Objetivo:** alta completa KYC → SOCIO con acceso al Metaplace y recuperación.

| # | Tarea | Entregable |
|---|---|---|
| T1.1 | Shell Metaplace + SSO SIWE + navegación de 3 suites | `/`, `/login`, layout + design system |
| T1.2 | Alta de identidad seudónima (CU-03) | API + UI `/identidad` |
| T1.3 | KYC: upload cifrado, magic bytes, cuota, retención (CU-04) | API + storage en BD + job de purga |
| T1.4 | Cola del Operador + verificación (CU-09) y emisión SOCIO/KYC (CU-10) | API + UI `/emisor/verificacion` |
| T1.5 | Claims on-chain: `addClaim`/revocación con EIP-712 (CU-10/11) | contratos ClaimLifecycle + tests |
| T1.6 | Recuperación 4-eyes (CU-06) | API + UI `/identidad/recuperacion` |
| T1.7 | Wizard de asistencia guiada (Q15) en alta/claim | componente wizard 4 pasos |
| T1.8 | DPIA + base legal/consentimiento (RNF-V3-12) | artefacto legal + registro en BD |

**Gates de salida (C1):**
- E2E: usuario nuevo completa KYC → SOCIO y opera; usuario sin SOCIO no opera.
- Purga de documentos vencidos probada (0 servidos / 100 % auditados).
- 4-eyes probado (mismo aprobador rechazado); Operador no aprueba.
- WCAG AA en rutas 1, 2, 6, 7, 8 (Anexo A) y mensajes de firma legibles.
- DPIA firmada y consentimiento registrado.

**Riesgos:** DPIA/legal (gate), KYC avanzado (UX).
**Esfuerzo:** 2–3 semanas.

---

## 5. C2 — ISSUER configurable y claims genéricos

**Objetivo:** el Admin crea ISSUER sin redeploy; el Emisor emite claims de su programa; RBAC real.

| # | Tarea | Entregable |
|---|---|---|
| T2.1 | CRUD de ISSUER + requisitos + claims que emite (CU-08) | API + UI `/emisor` |
| T2.2 | Solicitud genérica por ISSUER con requisitos previos (CU-04) | API + validaciones |
| T2.3 | `RoleRegistry` on-chain + `role_assignments` + API de roles (CU-15) | contratos + API + UI |
| T2.4 | Matriz de autorización 9 roles × 12 capacidades (positiva/negativa) | suite de tests |
| T2.5 | Consentimiento de fianza con firma EIP-712 legible (CU-07, Q21) | proceso `guarantee.consent` |
| T2.6 | Panel Sistema v1 (salud, colas, jobs) (CU-17) | UI + endpoints |

**Gates de salida (C2):**
- Crear un ISSUER nuevo desde UI sin redeploy y usarlo en una solicitud.
- Matriz de autorización 100 % verde (403 en ❌, 200 en ✅); revocación de rol efectiva < 1 s.
- FIADOR consiente con firma legible; fiador=creador rechazado.
- `audit_log` append-only probado.

**Esfuerzo:** 2–3 semanas.

---

## 6. C3 — Tokenización

**Objetivo:** acuñar producto/servicio/bien con Garantía+Fiador y compliance on-chain.

| # | Tarea | Entregable |
|---|---|---|
| T3.1 | `AssetNFT721`, `AssetERC1155`, `AssetFactory` + metadata (CID/hash, Q9) | contratos + tests |
| T3.2 | `AssetComplianceHook` (`_update`/`beforeTokenTransfer` + `isVerified`) | hook + tests adversariales |
| T3.3 | Flujo de tokenización producto (CU-12), servicio (CU-13), bien (CU-14) | API + UI + contratos |
| T3.4 | Garantía + Fiador como precondición on-chain | condition gates |
| T3.5 | Catálogo público + detalle (CU-01) con datos off-chain | UI `/catalogo`, `/activo/[id]` |
| T3.6 | Consumo de servicio (quema, CU-25) | contrato + API |

**Gates de salida (C3):**
- Los 3 tipos acuñan y se verifican on-chain; sin Garantía/Fiador revierte.
- Transferencia a wallet no verificada revierte (tests adversariales).
- `token_required_claims` de BD = `requiredTopics` on-chain (gate anti-deriva).
- Precio ≤ tasación aplicado; metadata con hash y URI estable.

**Esfuerzo:** 3 semanas.

---

## 7. C4 — Mercado, escrow y disputa

**Objetivo:** compra/venta a precio fijo con escrow atómico y disputa.

| # | Tarea | Entregable |
|---|---|---|
| T4.1 | `MarketplaceEscrow` (leg1 BRLT + leg2 activo en la misma tx) | contrato + tests |
| T4.2 | `FeeCollector` + comisión 500 bps (CU-16) | contrato + API |
| T4.3 | Publicación y compra (CU-20/21) + TTL y una orden abierta | API + UI `/compras` |
| T4.4 | Confirmación y liberación (CU-22) con dos tramos | API + contrato |
| T4.5 | `DisputeManager` + árbitro (CU-23/24) | contrato + UI |
| T4.6 | Jobs de expiración y conciliación (CU-26/29) | jobs + alertas |
| T4.7 | Indexer con reorg/reset (CU-28) | indexer + métricas |

**Gates de salida (C4):**
- Compra E2E con ambos tramos; 0 dobles ventas con 40 compras concurrentes (carga 2×).
- Transiciones inválidas rechazadas por BD; pago solo al vendedor.
- Disputa: reembolso y liberación correctos, auditados.
- Indexer con lag < 2 bloques y detección de reorg.
- **Auditoría externa de contratos** antes de operar con usuarios.

**Esfuerzo:** 3–4 semanas.

---

## 8. C5 — Firma legible, Admin y Sistema

**Objetivo:** experiencia de firma comprensible y administración completa.

| # | Tarea | Entregable |
|---|---|---|
| T5.1 | 8 plantillas de mensajes es/en + gate de legibilidad | `packages/wallet-messages` + CI |
| T5.2 | Panel Sistema completo (CU-17) con SLI | UI `/sistema` |
| T5.3 | Exportación de auditoría solo metadatos, solo Auditor (CU-18) | API + UI |
| T5.4 | Soporte in-app con SLA 24 h (CU-19, Q16) | API + UI |
| T5.5 | Accesibilidad WCAG AA en las 12 rutas + gate axe | tests + CI |
| T5.6 | Recuperación de identidad UI + doble aprobación visible | UI |

**Gates de salida (C5):**
- 100 % de procesos con mensaje legible (título ≤ 40, texto ≤ 200, jerga 0, Flesch ≥ 55).
- Matriz de autorización completa en verde; auditoría exportable sin PII.
- axe serious/critical = 0 en las 12 rutas.
- Panel con SLI/alertas y dueño.

**Esfuerzo:** 2 semanas.

---

## 9. C6 — Endurecimiento y cierre

**Objetivo:** SLO, DR, seguridad, rendimiento y manuales.

| # | Tarea | Entregable |
|---|---|---|
| T6.1 | SLO/SLI/error budget + alertas activas | dashboards + alertas |
| T6.2 | Restore drill (RPO/RTO) + rotación de clave | actas |
| T6.3 | Prueba de carga 2× con 0 dobles ventas | informe |
| T6.4 | Threat model STRIDE + rate limiting (RNF-V3-15) | documento + implementación |
| T6.5 | Cobertura ≥ 80 % contratos / ≥ 70 % web + E2E completo | pipeline |
| T6.6 | Manuales (usuario/admin/técnico) + despliegue final | `RepoTecnico/Manuales/` |

**Gates de salida (C6):**
- 100 % de pruebas en verde; cobertura cumplida.
- RTO ≤ 4 h medido; RPO ≤ 15 min.
- Threat model aprobado; rate limiting activo.
- Manuales entregados y Fase 4/5 habilitadas.

**Esfuerzo:** 2 semanas.

---

## 10. Resumen y calendario

| Ciclo | Semanas | Acumulado | Hito demostrable |
|---|---|---|---|
| C0 | 2 | 2 | BRLT + migración real + infra verificada |
| C1 | 2,5 | 4,5 | Alta KYC→SOCIO operativa |
| C2 | 2,5 | 7 | ISSUER configurable + RBAC |
| C3 | 3 | 10 | Tokenización de 3 tipos con compliance |
| C4 | 3,5 | 13,5 | Mercado con escrow y disputa |
| C5 | 2 | 15,5 | Firma legible + Admin/Sistema |
| C6 | 2 | 17,5 | SLO/DR/manuales |

**Total ≈ 17–18 semanas** (estimación de orden de magnitud; se recalibra al cierre de C0).

---

## 11. Primer paso propuesto: C0

1. Crear esqueleto (`apps/metaplace`, `packages/wallet-messages`, `sc/src/v3`) y rama de trabajo.
2. Implementar `BarloToken` + tests Foundry (mint/burn/pause/cap/límites).
3. Añadir job `migracion-v3` al CI con `pg_dump` v2 y ejecutar la migración real.
4. Rotar a claves dedicadas en Secret Manager + gate anti-Anvil.
5. Aprovisionar backups/PITR, pool, RPC fallback y Cloud Run Job `rwa-jobs`.
6. Acta `pruebas/c0_<fecha>.md` con evidencia.

**Criterio para arrancar:** aprobación del plan por el sponsor.

---

*Plan de desarrollo v3.2 · Fase 3 · Se actualiza al cierre de cada ciclo.*
