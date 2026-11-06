# DPIA / GDPR — Barlo Metaplace v3 (documento operativo)

> **Estado:** borrador operativo para revisión legal (no sustituye a la DPIA firmada por el DPO).
> **Alcance:** tratamiento de datos personales en el Metaplace, KYC/certificaciones y marketplace.

## 1. Roles y base legal

| Elemento | Definición |
|---|---|
| Responsable del tratamiento | Titular del servicio Barlo Metaplace (a designar formalmente) |
| Encargados | Google Cloud (Cloud Run, Cloud SQL, Secret Manager, GCS) y proveedor de verificación KYC |
| Bases legales | Ejecución del contrato (cuenta/servicio) · obligación legal (KYC/AML) · interés legítimo (seguridad, antifraude) · consentimiento explícito en fianza (CU-07) |
| DPO | Pendiente de designación formal (C6) |

## 2. Inventario de datos (minimización)

| Dato | Finalidad | Base legal | Retención |
|---|---|---|---|
| Wallet address | Autenticación SIWE, propiedad de activos | contrato | mientras exista la cuenta |
| Alias seudónimo (`barlo-…`) | Identidad pública en el Metaplace | contrato | mientras exista la cuenta |
| Documentos KYC (PDF/imagen cifrados) | Verificación de identidad y certificados | obligación legal/KYC | 30 días si se rechaza; 12 meses tras fin de relación (Q10) |
| Claims y certificados (SOCIO/GARANTÍA/FIADOR) | Operar en el Metaplace | contrato/obligación | mientras el claim esté vigente + auditoría |
| Firma de consentimiento de fianza | Acreditar consentimiento | consentimiento | vigencia del activo + plazos legales |
| Órdenes/pagos BRLT | Ejecución del marketplace | contrato | plazos contables/legales |
| `audit_log` (actor, acción, IP) | Seguridad y trazabilidad | interés legítimo/legal | según política de auditoría (Q18: metadatos) |
| Logs técnicos | Operación y seguridad | interés legítimo | 30–90 días |

**Minimización aplicada:** el alias es lo único público; el DTO de marketplace **ya no expone** la wallet
del vendedor (AM-07) y el acceso a documentos KYC está limitado a titular/Operador/Admin con traza de auditoría.

## 3. Derechos del titular (DSAR) — procedimiento

| Derecho | Canal | SLA | Evidencia |
|---|---|---|---|
| Acceso | Solicitud in-app/soporte + verificación SIWE | **≤ 30 días** | export de datos del titular (alias, claims, órdenes, auditoría propia) |
| Rectificación | Soporte → Operador/Admin | ≤ 30 días | `audit_log` de la corrección |
| Supresión (erasure) | Soporte → Admin; borrado de documentos y anonimización de alias | ≤ 30 días (salvo obligación legal de conservación) | acta de supresión + auditoría |
| Portabilidad | Export JSON/CSV de datos del titular | ≤ 30 días | hash del export registrado |
| Oposición | Supresión de cuenta | ≤ 30 días | cierre y retención legal mínima |

**Verificación de identidad del solicitante:** firma SIWE del wallet de la cuenta (evita suplantación).
**Excepción:** datos con obligación legal de conservación (KYC/AML, contable) se conservan el plazo mínimo
legal, bloqueados para otros fines.

## 4. Evaluación de riesgos (DPIA resumida)

| Riesgo | Prob. | Impacto | Medidas |
|---|---|---|---|
| Acceso indebido a KYC | media | alto | cifrado AES-256-GCM, RBAC, auditoría de descargas, cuarentena/AV pendiente |
| Reidentificación por wallet pública | media | medio | solo alias público; DTO sin wallet |
| Conservación excesiva | media | medio | retención automática (Q10) + job de purga |
| Transferencia internacional | baja | medio | regiones UE (europe-west1) + cláusulas del proveedor |
| Brecha de datos | baja | alto | mínimo privilegio, secretos en Secret Manager, runbook de brecha ≤72 h |
| Elaboración de perfiles/decisiones automatizadas | baja | medio | no hay decisiones automatizadas sobre personas; revisión humana en KYC |

## 5. Registro de actividades de tratamiento (ROPA) — resumen

1. **Autenticación** (wallet, IP, user-agent) — seguridad.
2. **Onboarding/KYC** (documentos cifrados, claims) — verificación legal.
3. **Certificaciones** (solicitudes, firmas, resoluciones) — contrato.
4. **Marketplace** (órdenes, pagos, disputas) — contrato.
5. **Soporte/auditoría** (logs, `audit_log`, export) — interés legítimo/legal.
6. **Fianza** (consentimiento firmado legible) — consentimiento.

## 6. Brechas de seguridad

1. Detección y contención (runbook de incidentes).
2. Evaluación de riesgo para derechos y libertades.
3. Notificación a la autoridad de control **≤ 72 h** si hay riesgo.
4. Comunicación a titulares si riesgo alto.
5. Registro de la brecha y evidencias en `audit_log`/acta.

## 7. Pendientes para cierre pre-piloto

- Designar **DPO** y firmar la DPIA (revisión legal).
- Implementar el **export DSAR** técnico (endpoint + hash auditado) y el flujo de borrado/anonimización.
- Contrato de encargado con el proveedor KYC y cláusulas de transferencia.
- Antivirus/cuarentena de documentos (AM-15) y retención demostrada con el job de purga.
- Revisar la base legal de la fianza y el consentimiento (texto legible ya firmado por el Fiador).
