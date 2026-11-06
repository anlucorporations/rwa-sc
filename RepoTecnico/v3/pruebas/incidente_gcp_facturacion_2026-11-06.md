# Incidente — GCP con facturación deshabilitada (2026-11-06)

> **Severidad:** 🔴 alta (bloquea operación on-chain y servicios desplegados)
> **Estado:** abierto · **Responsable de desbloqueo:** titular de la cuenta de facturación

## 1. Síntoma

- `mcc-foundry-anvil` (Anvil chain 31337) responde **HTTP 503** en todas las rutas.
- Los servicios `rwa-identity`, `rwa-issuer`, `rwa-token` del proyecto `mcc-ecommerce` dependen del mismo
  proyecto y quedan inoperativos.

## 2. Causa raíz (evidencia)

Logs de Cloud Run (`mcc-foundry-anvil`):

```
ERROR  The request failed because billing is disabled for this project.
INFO   Billing disabled. Shutting down instance.
ERROR  gcsfuse: StatObject: googleapi: Error 403: The billing account for the owning project is
       disabled in state delinquent, accountDisabled
```

→ La cuenta de facturación del proyecto está **deshabilitada por impago/delinquencia**. No es un fallo de
código ni de configuración de las aplicaciones.

## 3. Impacto

| Área | Impacto |
|---|---|
| Anvil GCP (chain 31337) | 🔴 caído (503) |
| Servicios `rwa-*` | 🔴 no arrancan (misma facturación) |
| Contratos desplegados (BRLT, AssetFactory, Marketplace) | ⏸ inaccesibles; **estado persistente** en GCS `mcc-ecommerce-anvil-state` (anvil-state.json) |
| Registro on-chain de identidades/claims (D-V3-29) | ⏸ bloqueado hasta restaurar |
| Desarrollo de app (Next, contratos, tests locales, docs) | 🟢 sigue operativo |

## 4. Mitigación / desbloqueo

1. Restaurar el pago de la cuenta de facturación en Google Cloud Console.
2. Verificar `gcloud run services describe mcc-foundry-anvil` → Ready y `eth_chainId = 0x7a69`.
3. Comprobar que el estado on-chain sobrevive (bucket GCS): `cast code` del BRLT, AssetFactory y Marketplace.
4. Si el estado se hubiera corrompido, re-ejecutar los scripts idempotentes de despliegue en orden:
   `DeployBarloToken` → `GrantBarloRoles` → `DeployAssets` → `DeployMarketplace` y actualizar `config/v3_*.json`.
5. Reintentar D-V3-29 (registro de identidades + claims KYC/GARANTÍA/FIADOR) y el E2E on-chain.

## 5. Prevención

- Alertas de presupuesto/facturación en Cloud Monitoring.
- Runbook de incidentes con comprobación de billing como primer paso.
- Los despliegues de contratos deben quedar **registrados y reproducibles** (ya hay scripts + `deployments/*.json`).
