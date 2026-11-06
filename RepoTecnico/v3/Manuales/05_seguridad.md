# 5. Seguridad

## 5.1 Controles implementados

| Control | Implementación | Verificación |
|---|---|---|
| Sesión SIWE | nonce de un solo uso, dominio/uri/chainId, cookie HMAC `httpOnly`+`SameSite=Strict` (+`Secure` en HTTPS) | E2E C1 9/9 |
| RBAC | `role_assignments` consultadas en cada petición; efecto inmediato al revocar | E2E C2 25/25 |
| KYC | magic bytes, límite 10 MB, AES-256-GCM en reposo, acceso por titular/Operador/Admin | E2E C1 16/16 |
| Claims | firma EIP-712 (dominio, dataHash, nonce, expiry) y emisor autorizado por programa | E2E C1 |
| Consentimiento Fiador | texto legible firmado EIP-191 verificado contra la wallet | E2E C3 9/9 |
| Escrow | dos tramos obligatorios (BRLT + activo) y triggers de estado | Tests Foundry + E2E C4 16/16 |
| Consumo de servicio | SOCIO + compra confirmada + idempotencia por auditoría | E2E C5 10/10 |
| Rate limiting | 10/min auth por IP · 30/min escrituras por wallet | E2E C5 (429) |
| Cabeceras | CSP, X-Frame-Options DENY, nosniff, HSTS, COOP, Permissions-Policy | E2E C5 |
| Auditoría | `audit_log` append-only por trigger | DDL + tests |

## 5.2 Modelo de amenazas

Documento completo: [modelo_amenazas_v3.md](../seguridad/modelo_amenazas_v3.md) (12 amenazas STRIDE,
mitigaciones y criterios). Riesgos residuales principales: red Anvil de desarrollo sin HA, WAF de borde
pendiente, rotación de claves pendiente y revisión adversarial del propio modelo.

## 5.3 Comprobaciones rápidas

```bash
python3 RepoTecnico/verificar_artefactos.py            # consistencia documental
cd rwa-sc/sc && forge test                             # contratos
cd rwa-web && pnpm --filter @rwa/metaplace test        # rate limiting
```

## 5.4 Reglas del repositorio

- Sin secretos ni claves privadas en código, docs o logs.
- Direcciones de red sólo en `config/` (servidor) o variables públicas.
- Cambios de esquema → actualizar `base_datos.sql`, migración, diccionario y ER (verificador en PASS).
