# Manuales técnicos — Barlo Metaplace (v3)

> **Audiencia:** equipo técnico, operación y auditoría.
> **Alcance:** monorepo `rwa-web` (Metaplace + paquetes) y `rwa-sc` (contratos + despliegue).

## Índice

1. [Arquitectura](01_arquitectura.md) — componentes, flujo de datos, topología y variables.
2. [Puesta en marcha](02_puesta_en_marcha.md) — entorno local, base de datos, contratos y arranque.
3. [Operación e incidentes](03_operacion.md) — salud, logs, jobs, backups, retención y runbooks.
4. [Referencia de API](04_api_referencia.md) — endpoints, autenticación, roles y códigos.
5. [Seguridad](05_seguridad.md) — controles, modelo de amenazas y verificación.

## Convenciones

- Documentación canónica del proyecto: `RepoTecnico/` (espejo en `rwa-sc/RepoTecnico/v3/`).
- Actas de pruebas por ciclo: `RepoTecnico/pruebas/`.
- Comando de consistencia documental: `python3 RepoTecnico/verificar_artefactos.py` (debe dar PASS).
- Nunca se documentan secretos ni claves privadas.
