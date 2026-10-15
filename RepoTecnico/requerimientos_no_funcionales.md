# Requisitos No Funcionales y Políticas — RWA

> **Propósito:** cerrar el catálogo RNF incompleto (H-09) y las políticas que dependen de él
> (H-10 regulatorio, H-11 protección de datos, H-25 stakeholder supervisor, H-30 backup/DR,
> H-27 soporte al inversor), tal como exige el plan R-1..R-5 de
> [`INFORME_OPTIMIZACION_V1.md`](INFORME_OPTIMIZACION_V1.md) §8.
>
> **Estado de aprobación:** los RNF están **definidos y son medibles**; las categorías marcadas
> `LEGAL`/`DIR` requieren **aprobación formal** de asesoría legal o dirección antes de considerarse
> cerradas (no las puede aprobar el equipo técnico). Ver §7.
>
> **Alcance:** plataforma RWA (`rwa-sc` contratos + `rwa-web` frontend). Los RNF de gas, cobertura,
> CI y secretos ya existen en [`requerimientos.md`](requerimientos.md) §4 (RNF-001..RNF-005).

## 1. Catálogo RNF por categoría ISO 25010 (H-09 / R-1)

| ID | Categoría ISO 25010 | Requisito medible | Verificación | Responsable | Estado |
|---|---|---|---|---|---|
| RNF-101 | Adecuación funcional | Todo RF-001..RF-013 con al menos un test o gate verde | `forge test` ≥ 100 % en CI | Dev contratos | ✅ Verificado |
| RNF-102 | Eficiencia de desempeño | Gas por operación de runtime con umbral absoluto y baseline `.gas-snapshot` (tolerancia 5 %) | `forge snapshot --check --tolerance 5` | Dev contratos | ✅ Verificado |
| RNF-103 | Compatibilidad | ABIs versionadas; deriva declarada en `CHANGELOG_ABIS.md` | `abi_diff.sh` | Dev contratos | ✅ Verificado |
| RNF-104 | Usabilidad (contratos) | N/A justificado: sin UI en `rwa-sc`; la accesibilidad WCAG 2.1 AA se cubre en la línea `@web` | — | — | N/A justificado |
| RNF-105 | Fiabilidad | Ningún `invariant_*` con violación; 0 fallos en CI | `forge test` (19 invariantes) | Dev contratos | ✅ Verificado |
| RNF-106 | Seguridad de la información | Sin secretos en el árbol; claims firmados EIP-712; fail-closed | `check_secrets.sh`, RF-001/RF-011/RF-012 | Seguridad | ✅ Verificado |
| RNF-107 | Mantenibilidad | Cobertura de líneas `src/` ≥ 80 % agregada **y** por contrato; `forge fmt --check` limpio; análisis estático sin *High* | `check_coverage.sh`, `fmt`, `slither` (§7 pendiente) | Dev contratos | 🟡 Parcial (falta Slither fijado) |
| RNF-108 | Portabilidad | `solc 0.8.20` + optimizer + `evm_version=paris` fijados; bootstrap reproducible con submódulos; multi-red con validación de `chainId` | `validate` job, `deploy.sh` | DevOps | ✅ Verificado |
| RNF-109 | Cumplimiento regulatorio y privacidad | Cubierto por §2 y §3 | — | Legal + Compliance | 🟡 Definido, pendiente de aprobación |

> **H-09 cierre:** todas las categorías de ISO 25010 quedan con un RNF, un método de verificación y
> un responsable; las dos N/A quedan justificadas por escrito (RNF-104 y la parte web de RNF-107).

## 2. Cumplimiento regulatorio (H-10 / H-25 / R-2) — **LEGAL**

| ID | Requisito | Criterio operativo | Estado |
|---|---|---|---|
| RNF-201 | Screening de sanciones/PEP/AML **antes** de emitir un claim de inversor | El issuer no puede firmar un claim `KYC`/`Accreditation` sin un resultado de screening `PASS` registrado off-chain (`rwa.claim_requests`) | 🟡 Definido |
| RNF-202 | Rescreening periódico | Revalidación ≥ cada 12 meses o ante cambio normativo; claim vencido ⇒ `isVerified == false` (ya soportado por RF-013) | 🟡 Definido |
| RNF-203 | Trazabilidad de decisiones | Cada aprobación/rechazo con actor, fecha, motivo e identificador de evidencia en `rwa.audit_log` | 🟡 Definido |
| RNF-204 | Restricciones por jurisdicción | Topic `9 = Jurisdiction` (catálogo canónico v1.0) exigible por token; bloqueo de jurisdicciones prohibidas | ✅ Base on-chain (RF-013 + H-13) |
| RNF-205 | Reporte regulatorio | Export reproducible (CSV/JSON firmado) de inversores, claims y transferencias por período | 🟡 Definido |
| RNF-206 | Stakeholder **regulador/supervisor** (H-25) | Actor identificado con canal de reporte y periodicidad; marco objetivo propuesto: MiCA (UE), Reg D/S (EE. UU.), CNMV/LMV (ES) y DLT Pilot | 🟡 Definido, pendiente de validación legal |

> **No cerrable por el equipo técnico:** RNF-201/202/205/206 exigen que legal confirme el perímetro
> normativo y que compliance opere el screening. El diseño on-chain ya no lo impide (topics, claims
> con vigencia y revocación, auditoría off-chain).

## 3. Protección de datos y PII/KYC (H-11 / R-3) — **LEGAL**

| ID | Requisito | Criterio operativo | Estado |
|---|---|---|---|
| RNF-301 | Base legal y consentimiento | Registro de la base jurídica por tratamiento y consentimiento explícito del inversor | 🟡 Definido |
| RNF-302 | Cifrado de PII y documentos | Documentos KYC cifrados con AES-256-GCM en `rwa.document_files` (`bytea`), clave en Secret Manager (`DS_KYC_SECRET`); sin PII on-chain (solo hash/commitment) | ✅ Implementado en `@web` (D-098) |
| RNF-303 | Minimización on-chain | La cadena solo almacena `keccak256(data)` y `uriHash`; nunca datos personales | ✅ Verificado (RF-001/AF-03) |
| RNF-304 | Retención y supresión | Plazo de retención documentado + borrado verificable (`sha256` de auditoría sin contenido) | 🟡 Definido |
| RNF-305 | DPIA y DPO | Evaluación de impacto y designación de DPO antes de producción con activos reales | 🟡 Definido, pendiente de aprobación |
| RNF-306 | Acceso por propiedad | Un inversor solo accede a sus documentos; servido siempre como adjunto | ✅ Implementado en `@web` |

## 4. Observabilidad e indexación (H-12 / H-21 / R-4)

| ID | Requisito | Criterio operativo | Estado |
|---|---|---|---|
| RNF-401 | Indexer de eventos operativo | Indexa `Transfer`, `ClaimAdded`, `ClaimRevoked`, `ClaimRemoved`, `ComplianceModuleAdded/Removed`, `ModuleAdded/Removed`, `IdentityRegistered/Removed` hacia la BD off-chain con historial consultable | 🟡 Pendiente (componente off-chain) |
| RNF-402 | Alertas de riesgo | Alertas por: mint/burn fuera de umbral, `forcedTransfer`, congelación, revocación de claim, retirada del último módulo (fail-closed) | 🟡 Definido |
| RNF-403 | Retención de logs/índice | Retención ≥ 12 meses y capacidad de reconstrucción desde el bloque génesis del despliegue | 🟡 Definido |
| RNF-404 | Canal y tiempos de incidentes | Detección ≤ 15 min para eventos privilegiados; canal de incidentes con escalado | 🟡 Definido |
| RNF-405 | Artefactos de despliegue | Un JSON versionado por despliegue (direcciones, ABIs, `chainId`, bloque) | ✅ Implementado (Ciclo 9, H-29) |

## 5. Continuidad y backup/DR (H-30 / R-5)

| ID | Requisito | Criterio operativo | Estado |
|---|---|---|---|
| RNF-501 | RPO de la BD off-chain | Pérdida máxima de datos ≤ 24 h (backup diario) y PITR de Cloud SQL | 🟡 Definido |
| RNF-502 | RTO | Restauración de servicio ≤ 4 h desde incidente declarado | 🟡 Definido |
| RNF-503 | Restauración ensayada | Prueba de restauración documentada con resultado y fecha | 🟡 Pendiente de ensayo |
| RNF-504 | Recuperación on-chain | Runbook de recuperación de roles/registries y de **redeploy limpio** | ✅ `RUNBOOK_MIGRACION.md` |
| RNF-505 | Custodia de claves | Custodio designado con rotación y respaldo; sin claves en repo | 🟡 Definido (R-7) |

## 6. Soporte al inversor y recuperación auditable (H-27)

| ID | Requisito | Criterio operativo | Estado |
|---|---|---|---|
| RNF-601 | Actor de soporte | Rol/responsable identificado con canal y SLA (acuse ≤ 3 días laborables) | 🟡 Definido |
| RNF-602 | Recuperación auditable | Toda recuperación (`forcedTransfer`, descongelación, alta de claim) con destino whitelisted, verificado y evento auditable | ✅ On-chain (RF-004, AF-02) |
| RNF-603 | Procedimiento documentado | Guía de soporte con pasos, roles y evidencia por caso | 🟡 Definido |

## 7. Aprobaciones pendientes y trazabilidad

| Hallazgo | Artefacto que lo cierra | Quién aprueba | Estado |
|---|---|---|---|
| H-09 | §1 catálogo RNF ISO 25010 | Dirección técnica | 🟡 Definido |
| H-10 | §2 RNF regulatorios (RNF-201..206) | Legal + Compliance | 🟡 Pendiente de aprobación |
| H-11 | §3 protección de datos (RNF-301..306) | Legal / DPO | 🟡 Pendiente de aprobación |
| H-12 / H-21 | §4 observabilidad e indexación (RNF-401..405) | Arquitectura + backend | 🟡 Pendiente de implementación del indexer |
| H-25 | §2 RNF-206 stakeholder supervisor | Dirección + Legal | 🟡 Pendiente de aprobación |
| H-30 | §5 continuidad y backup/DR (RNF-501..505) | Operaciones | 🟡 Pendiente de ensayo |
| H-27 | §6 soporte al inversor (RNF-601..603) | Operaciones | 🟡 Definido |

> **Regla de cierre (D-024):** ninguna categoría `LEGAL`/`DIR` se marca cerrada hasta que exista
> aprobación explícita. Este documento es el insumo verificable para esa aprobación; su estado se
> actualiza en `RepoTecnico/estado_proyecto.md` y `SECURITY.md`.
