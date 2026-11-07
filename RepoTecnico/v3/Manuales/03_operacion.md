# 3. Operación e incidentes

## 3.1 Salud y observabilidad

| Comprobación | Cómo |
|---|---|
| App viva | `GET /api/health` de `txb-metaplace` → `{status:"ok",chainId:31337,rpcConfigured,database}` |
| Panel Sistema | `GET /api/system` (Admin/Auditor): ping BD, colas de claims, indexer, última auditoría |
| Logs | Cloud Logging `resource.type="cloud_run_revision"` por servicio |
| Colas | `GET /api/review-queue?status=pending|documents_verified` |

## 3.2 Jobs y retención (Q10)

- Indexer: Cloud Run Job `rwa-indexer`, programado cada 10 min; tabla `rwa.indexer_state`.
- Rechazo de solicitudes: el trigger fija `retention_delete_at = +30 días` en `document_files`.
- Purga programada con `rwa.purge_expired_documents()`; verificar logs del job.

## 3.3 Backups y recuperación (servicios globales)

- PostgreSQL global `truekeate-db-dev`: backups automáticos + PITR (RPO ≤ 15 min) — verificados.
- Foundry global: estado persistido en GCS (`mcc-ecommerce-anvil-state`); runbook de redeploy de contratos.
- Restore drill de la base `txbarlovento` en instancia temporal (pendiente pre-piloto).

## 3.4 Backups y recuperación (histórico)

- Cloud SQL: backups automáticos + **PITR** (RPO ≤ 15 min) — verificado en el acta C0.
- Restore drill pendiente (C6): restaurar en instancia temporal y validar esquema `rwa` + conteos.
- Anvil: estado persistido en GCS; ante pérdida, re-ejecutar `DeployBarloToken → GrantBarloRoles → DeployAssets → DeployMarketplace`.

## 3.4 Runbook: facturación GCP deshabilitada

1. Revisar Cloud Logging: `billing is disabled for this project` / GCS 403 `accountDisabled`.
2. Restaurar el pago de la cuenta en Cloud Console.
3. Verificar `gcloud run services describe mcc-foundry-anvil` → Ready y `eth_chainId = 0x7a69`.
4. Comprobar `cast code` de BRLT/AssetFactory/Marketplace; si falta estado, redeploy.
5. Reanudar E2E on-chain y D-V3-29 (identidades + claims).

## 3.5 Roles y secretos

- Concesión/revocación de roles: `POST /api/admin/roles`, revocación con efecto inmediato.
- Claves BRLT en Secret Manager (`BRLT_ADMIN_KEY`, `BRLT_MINTER_KEY`, `BRLT_PAUSER_KEY`), nunca en repo.
- Rotación: procedimiento pendiente (C6); tras rotar, actualizar secreto y rol on-chain correspondiente.

## 3.6 Límites operativos y endurecimiento

- Rate limiting en app: 10/min auth por IP (nonce y verify), 30/min escrituras por wallet; 429 con `Retry-After`.
- Subida KYC: máx. 5 documentos y 50 MB por solicitud; tamaño por archivo ≤ 10 MB.
- Guardia de origen: con `ALLOWED_ORIGINS` definido, las mutaciones sin `Origin` válido responden 403.
- `ALLOWED_HOSTS` restringe el host aceptado por SIWE; `SESSION_COOKIE_NAME=__Host-rwa_session` y
  `COOKIE_SECURE=1` fuerzan cookie `__Host-` + `Secure` en producción.
- Sesión: `SESSION_TTL_HOURS` (default 24) y `SESSION_ROLLING=1`; acciones de admin exigen login dentro
  de `ADMIN_REAUTH_WINDOW_MIN` (default 15 min).
- CSP con nonce gestionada en `middleware.ts` (las páginas se renderizan dinámicas).
- Cuotas de subida: `UPLOAD_QUOTA_FILES_PER_HOUR` (10) y `UPLOAD_QUOTA_MB_PER_HOUR` (50).
- WAF/Cloud Armor y rate limiting distribuido: pendiente (AM-08, requiere GCP).
