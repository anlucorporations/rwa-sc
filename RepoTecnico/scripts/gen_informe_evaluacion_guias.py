#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Genera el informe de evaluación del proyecto frente a las guías estudiantiles.

La rúbrica vive aquí para que los porcentajes sean reproducibles y auditables:
cada criterio se puntúa 1 (cumple), 0,5 (parcial) o 0 (no cumple).
"""

from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "INFORME_EVALUACION_GUIAS_ESTUDIANTE_V1.md"

# ---------------------------------------------------------------------------
# Rúbrica GUIA_ESTUDIANTE.md (contratos) — 53 criterios
# ---------------------------------------------------------------------------
GUIA = {
    "A. Objetivos de aprendizaje": [
        ("A1", "Implementar el estándar ERC-3643", 0.5,
         "`rwa-sc/README.md:21`: «inspirado en ERC-3643, no compliant»; la guía lo presenta como estándar implementado"),
        ("A2", "Clone Factory (EIP-1167)", 1,
         "`Clones` de OpenZeppelin en las 3 factories (`ClaimTopicsRegistryCloneFactory.sol:4,75`); clones desplegados en E2E"),
        ("A3", "Compliance modular y extensible", 1,
         "`ICompliance` + `ComplianceAggregator` + 3 módulos (`sc/src/compliance/`)"),
        ("A4", "Identity verification on-chain", 1,
         "`IdentityRegistry` + `TokenCloneable.isVerified` (`TokenCloneable.sol:424`)"),
        ("A5", "Access control con roles", 1,
         "`AGENT_ROLE`/`COMPLIANCE_ROLE`/`DEFAULT_ADMIN_ROLE` (`TokenCloneable.sol:35-36,110-112`)"),
        ("A6", "Tests comprehensivos con Foundry", 1,
         "21 suites / 443 tests (fuzz 256, invariantes) en `sc/test/`"),
        ("A7", "Scripts de deployment automatizados", 1,
         "9 scripts `.s.sol` + `deploy.sh`, `DeployFullStack.s.sol`, CI (`run_local_ci.sh`)"),
    ],
    "B. Conceptos fundamentales": [
        ("B1", "Concepto de RWA token", 1, "`README.md`, `RepoTecnico/estado_proyecto.md`, `requerimientos.md`"),
        ("B2", "Componentes de ERC-3643 (registries, compliance, claims, roles)", 1,
         "Los cuatro pilares existen en `sc/src/`"),
        ("B3", "Clone Factory (EIP-1167)", 1,
         "Factories con `Clones.clone()`; ahorro de gas medido en `test/benchmarks/`"),
        ("B4", "Compliance Aggregator", 1,
         "`ComplianceAggregator.sol` con despacho modular y fail-closed (RF-012)"),
    ],
    "C. Arquitectura del sistema": [
        ("C1", "Vista general de la arquitectura", 1, "`README.md` (diagrama), `RepoTecnico/diagrama_er.md`"),
        ("C2", "Flujo de una transferencia con compliance", 1,
         "`TokenCloneable.canTransfer` (:511) → `isVerified` + aggregator; cubierto en `Token.t.sol`"),
        ("C3", "Roles y permisos documentados y en código", 1,
         "Roles por contrato + gobernanza `GovernanceMultisig` (H-06)"),
    ],
    "D. Contratos básicos (Nivel 1)": [
        ("D1", "Contrato individual de identidad (`Identity.sol`)", 0.5,
         "Existe `IdentityCloneable.sol`; `addClaim` de 7 args con `expiresAt` (:147) y `getClaim(topic,issuer)` (:294) frente a 6 args/`claimId` de la guía"),
        ("D2", "`IdentityRegistry` (`registerIdentity`/`isRegistered`/`getIdentity`)", 1,
         "`IdentityRegistry.sol:41,120,112`"),
        ("D3", "`TrustedIssuersRegistry` (`addTrustedIssuer`/`hasClaimTopic`/`getTrustedIssuerClaimTopics`)", 0.5,
         "`addTrustedIssuer` (:40), `isTrustedIssuer` (:114), `hasClaimTopic` (:131); el getter real es `getIssuerClaimTopics` (:122)"),
        ("D4", "`ClaimTopicsRegistry.addClaimTopic`", 1, "`ClaimTopicsRegistry.sol:37`"),
    ],
    "E. Compliance modules (Nivel 2)": [
        ("E1", "Interfaz `ICompliance` con los 4 callbacks", 1, "`ICompliance.sol:24-46` (firma idéntica a la guía)"),
        ("E2", "`MaxBalanceCompliance`", 1, "`MaxBalanceCompliance.sol` (canTransfer/transferred/created/destroyed)"),
        ("E3", "`MaxHoldersCompliance`", 1, "`MaxHoldersCompliance.sol`"),
        ("E4", "`TransferLockCompliance`", 1, "`TransferLockCompliance.sol`"),
        ("E5", "Patrón `onlyTokenOrAuthorized`", 1, "`MaxHoldersCompliance.sol:39`"),
    ],
    "F. Contratos avanzados (Nivel 3)": [
        ("F1", "Token ERC-3643 (`Token.sol`)", 0.5,
         "Existe `TokenCloneable.sol` (upgradeable/clon) con `mint` (:342), `addComplianceModule` (:163), `pause` (:288), `isVerified` (:424), `canTransfer` (:511); nombre y herencia distintos"),
        ("F2", "`ComplianceAggregator` (proxy modular)", 0.5,
         "`getModules` (:245), `getModuleCount` (:261), `canTransfer` (:176); la guía muestra `onlyOwnerOrToken(address)` y el real es `onlyToken(address)` (:86)"),
    ],
    "G. Patrones de diseño": [
        ("G1", "Factory Pattern (Clone Factory)", 1, "3 factories + `Clones`"),
        ("G2", "Proxy Pattern (Compliance Aggregator)", 1, "Aggregator como proxy modular"),
        ("G3", "Access Control Pattern", 1, "Roles `AccessControl` en token y gobernanza"),
        ("G4", "Registry Pattern", 1, "`IdentityRegistry`, `TrustedIssuersRegistry`, `ClaimTopicsRegistry`"),
        ("G5", "Modifier Pattern (authorization)", 1, "`onlyToken`, `onlyOwner`, `onlyRole`, `onlyTokenOrAuthorized`"),
    ],
    "H. Ejercicios prácticos": [
        ("H1", "Ejercicio 1: `TimeBasedCompliance.sol`", 0,
         "No existe; `EJERCICIOS_PRACTICOS.md` propone otros ejercicios (DailyTransferLimit, Whitelist, CountryRestriction)"),
        ("H2", "Ejercicio 2: `deploy-real-estate-token.sh` (Manhattan 301)", 0,
         "No existe; la propia guía lo marca como `TODO`"),
        ("H3", "Ejercicio 3: `GeographicCompliance`", 0,
         "No existe; el doc de ejercicios tiene `CountryRestrictionCompliance` (distinto)"),
        ("H4", "Ejercicio 4: test de integración completo", 1,
         "`RF013_ClaimLifecycle.t.sol`, `AuditoriaFinalAF.t.sol` y E2E claim-flow"),
    ],
    "I. Conceptos avanzados": [
        ("I1", "Initializable pattern", 1, "`initialize`/`_disableInitializers` en `IdentityCloneable`/`TokenCloneable`"),
        ("I2", "Delegatecall", 1, "Clones EIP-1167 + aggregator"),
        ("I3", "Gas optimization con evidencia", 1,
         "`optimizer_runs=200`, `.gas-snapshot` con tolerancia, `test/benchmarks/` y CI (RNF-001)"),
    ],
    "J. Herramientas y setup": [
        ("J1", "Foundry (prerequisitos y comandos)", 1, "`foundry.toml`, `forge build/test`; toolchain v1.8.3 fijada"),
        ("J2", "Tests, cobertura y CI", 1, "443 tests, `lcov.info`, `.gitlab-ci.yml`, `run_local_ci.sh`"),
        ("J3", "Scripts de despliegue y gestión", 1, "`deploy.sh`, `DeployFullStack.s.sol`, `backup/restore`, `run_local_ci.sh`"),
    ],
    "K. Checklist de competencias": [
        ("K1", "Competencia: smart contracts", 1, "Contratos completos y testeados"),
        ("K2", "Competencia: patrones de diseño", 1, "Factories, aggregator, registries, access control"),
        ("K3", "Competencia: testing", 1, "443 tests + fuzz + invariantes + cobertura"),
        ("K4", "Competencia: deployment", 1, "9 scripts + artefactos versionados + gobernanza"),
        ("K5", "Competencia: gas optimization", 1, "Benchmarks + snapshot + optimizador"),
    ],
    "L. Recursos y documentación": [
        ("L1", "Documentación del proyecto referenciada", 0.5,
         "`README.md` y `EJERCICIOS_PRACTICOS.md` existen; `TOKEN_CLONE_FACTORY.md` y `COMPLIANCE_AGGREGATOR_FINAL.md` no existen"),
        ("L2", "Troubleshooting de errores", 0.5,
         "Errores custom (`onlyToken`, `TransferNotCompliant`, etc.); los mensajes literales de la guía no siempre coinciden"),
        ("L3", "Glosario y recursos", 1, "Glosario en la guía y documentación en `RepoTecnico/`"),
    ],
    "M. Vigencia de la guía (vs. proyecto actual)": [
        ("M1", "Nombres de contratos (`Identity.sol`/`Token.sol`)", 0,
         "Los reales son `IdentityCloneable.sol` y `TokenCloneable.sol`"),
        ("M2", "Firmas `addClaim`/`getClaim`", 0,
         "`addClaim` de 7 args con `expiresAt`; `getClaim(uint256,address)`"),
        ("M3", "Afirmación «ERC-3643 compliant»", 0.5, "El proyecto lo corrige a «inspirado» (`README.md:21`)"),
        ("M4", "Documentos referenciados", 0.5, "2 de 4 existen"),
        ("M5", "Comandos y setup (forge/anvil)", 1, "Válidos"),
    ],
}

# ---------------------------------------------------------------------------
# Rúbrica FICHERO_PARA_ESTUDIANTE.md (web) — 66 criterios
# ---------------------------------------------------------------------------
FICHERO = {
    "A. Alcance funcional": [
        ("A1", "Crear identidades digitales on-chain", 1, "`apps/identity` + `IdentityRegistry.registerIdentity`"),
        ("A2", "Solicitar/aprobar/rechazar claims", 1,
         "`ClaimRequestForm`, `RequestDetailModal`, `/api/claim-requests`, `/api/update-request`"),
        ("A3", "Crear tokens RWA con compliance", 1, "`apps/token` factory + `CreateTokenForm`/`TokensList`"),
        ("A4", "Comprar y transferir tokens con compliance", 0.5,
         "UI de marketplace y código de compra/transferencia; la compra usa ABI legacy (ver G5/H6)"),
    ],
    "B. Arquitectura de aplicaciones": [
        ("B1", "3 apps separadas", 0.5, "Hay 3 apps + `indexer`; estructura monorepo `apps/*`, no directorios `web-*`"),
        ("B2", "web-identity (puerto 4001)", 0.5, "`apps/identity` en 4001 (dev y compose)"),
        ("B3", "web-registry-trusted (puerto 4002)", 0.5, "Renombrada `apps/issuer` en 4002"),
        ("B4", "web-token (puerto 4003)", 0.5, "`apps/token` en 4003"),
    ],
    "C. Stack tecnológico": [
        ("C1", "Next.js 16 + React + TypeScript + Tailwind", 1, "`next 16.1.6`, `react 19.2.3`, TS; Tailwind en las apps"),
        ("C2", "ethers.js v6", 0, "0 dependencias/imports: `wagmi` + `viem` (`README.md:70`)"),
        ("C3", "MongoDB", 0, "PostgreSQL (`docker-compose.yml` → postgres:16-alpine; `@rwa/shared/db`)"),
        ("C4", "GridFS para documentos", 0, "`rwa.document_files` (bytea cifrado AEAD, D-093)"),
        ("C5", "MetaMask", 0.5, "Conector inyectado de wagmi; la UI menciona MetaMask y `switchChain`"),
    ],
    "D. Configuración e instalación": [
        ("D1", "Requisitos previos (Node, MongoDB, Anvil)", 0.5, "Node + Anvil ✓; MongoDB ✗ (PostgreSQL)"),
        ("D2", "Instalación por app con npm", 0, "Monorepo pnpm (`pnpm-workspace.yaml`, `pnpm install`)"),
        ("D3", "`start-all.sh` / `stop-all.sh` / `check-status.sh`", 1, "Los tres scripts existen y arrancan las 3 apps"),
        ("D4", "Puertos 4001-4003", 1, "Dev y compose publican 4001/4002/4003 (`docker-compose.yml:60,76,92`)"),
    ],
    "E. App Identity": [
        ("E1", "Crear identidad", 1, "`apps/identity/app/app/page.tsx`"),
        ("E2", "Solicitar claim a un issuer", 1, "`ClaimRequestForm`"),
        ("E3", "Ver mis requests", 1, "`RequestDetailModal`, `/api/claim-requests` (GET)"),
        ("E4", "Cargar claims aprobados", 1, "`addClaim` on-chain (`RequestDetailModal.tsx:36-70`)"),
        ("E5", "Account status", 1, "Estado de conexión/cuenta en `app/app`"),
    ],
    "F. App Registry/Issuer": [
        ("F1", "Ver trusted issuers", 1, "`/api/issuers`, `apps/issuer`"),
        ("F2", "Panel de issuer", 1, "`apps/issuer/app/dashboard/page.tsx`"),
        ("F3", "Aprobar/Rechazar claims", 1, "`/api/update-request` + modal de revisión"),
        ("F4", "Ver firmas", 1, "`RequestDetailModal` firma EIP-712 y muestra firmas"),
    ],
    "G. App Token": [
        ("G1", "Crear token (factory)", 1, "`apps/token/app/factory/page.tsx`, `/api/tokens`"),
        ("G2", "Gestionar compliance modules", 0.5,
         "Alta en `TokensList`/`CreateTokenForm` y `/api/tokens/[tokenId]/modules`; no hay UI de baja"),
        ("G3", "Gestionar required claims", 1, "`/api/tokens/[tokenId]/claims`, `requiredClaims`"),
        ("G4", "Establecer precio", 0.5,
         "UI y `/api/tokens/[tokenId]/price`, pero el ABI actual de `TokenCloneable` no declara `setPrice` (`market.ts:4-7`)"),
        ("G5", "Marketplace: comprar tokens", 0.5,
         "`marketplace/page.tsx` llama `buyToken`; ABI legacy (`market.ts`) y el contrato actual no expone `buyToken`"),
        ("G6", "Transferir tokens", 0.5, "Lógica en `marketplace`/compliance, sin flujo dedicado ni E2E"),
        ("G7", "Cambiar de cuenta", 1, "«Switch Account» en marketplace + wagmi"),
    ],
    "H. Flujo completo de uso": [
        ("H1", "Paso 1: crear identidad", 1, "Flujo E2E claim-flow"),
        ("H2", "Paso 2: solicitar claims", 1, "Flujo E2E claim-flow"),
        ("H3", "Paso 3: issuer aprueba", 1, "Flujo E2E claim-flow"),
        ("H4", "Paso 4: cargar claims", 1, "Flujo E2E claim-flow"),
        ("H5", "Paso 5: admin crea token", 1, "Factory + `/api/tokens`"),
        ("H6", "Paso 6: investor compra", 0.5, "UI legacy de compra; contrato actual sin `buyToken`"),
        ("H7", "Paso 7: investor transfiere", 0.5, "Sin flujo E2E de transferencia"),
    ],
    "I. Smart contracts (sección web)": [
        ("I1", "Identity Registry", 1, "`registerIdentity`/`isRegistered`/`getIdentity`"),
        ("I2", "Trusted Issuers Registry", 1, "`addTrustedIssuer`/`isTrustedIssuer`/`getIssuerClaimTopics`"),
        ("I3", "Identity Contract (`addClaim` de 6 args)", 0.5, "`addClaim` de 7 args + EIP-712 (`IdentityCloneable.sol:147`)"),
        ("I4", "Token Clone Factory", 1, "`createToken`/`createTokenWithRegistries`"),
        ("I5", "Token Cloneable", 1, "`TokenCloneable.sol`"),
    ],
    "J. Base de datos": [
        ("J1", "MongoDB, base `rwa`", 0, "PostgreSQL, esquema `rwa`"),
        ("J2", "Colecciones `claim_requests`/`tokens`", 0.5, "Existen como tablas `rwa.claim_requests`/`rwa.tokens` con campos equivalentes"),
        ("J3", "Buckets GridFS", 0, "`rwa.document_files` (bytea cifrado)"),
    ],
    "K. Sistema de firmas": [
        ("K1", "Firma dual requester + issuer", 1, "Flujo E2E: firma del inversor + firma del issuer"),
        ("K2", "Mecanismo `signMessage` (EIP-191) para ambas", 0,
         "Inversor EIP-191, issuer EIP-712; el contrato valida EIP-712"),
        ("K3", "Firma del issuer usada en `addClaim`", 1, "`addClaim` verifica la firma EIP-712 del issuer"),
    ],
    "L. APIs importantes": [
        ("L1", "Rutas de identity (`claim-requests`, `upload`, `download`)", 1, "Rutas presentes"),
        ("L2", "Rutas de issuer (`issuer-requests`, `update-request`)", 1, "Rutas presentes"),
        ("L3", "Rutas de token (`tokens`, `price`, `modules`, `claims`)", 1, "Rutas presentes"),
    ],
    "M. Troubleshooting, seguridad y topics": [
        ("M1", "Troubleshooting (compliance/MongoDB)", 0.5, "Los errores de compliance aplican; los de MongoDB/GridFS no"),
        ("M2", "Seguridad (firmas, compliance, permisos)", 1, "EIP-712, SIWE, compliance y roles"),
        ("M3", "Claim topics 1/7/9 (5/6 reservados)", 1, "`base_datos.sql:456-460`"),
    ],
    "N. Features y quick start": [
        ("N1", "Features de identity", 1, "Página + APIs"),
        ("N2", "Features de issuer", 1, "Panel + APIs"),
        ("N3", "Features de token", 1, "Factory/marketplace + APIs"),
        ("N4", "Quick start (MongoDB, start-all, MetaMask, test)", 0.5, "start-all/MetaMask/health ✓; MongoDB ✗"),
    ],
    "P. Cast, glosario y avanzado": [
        ("P1", "Comandos `cast` verificables", 1, "`cast call` a registries/token; Anvil/GCP"),
        ("P2", "EIP-1167 minimal proxy", 1, "Factories con `Clones`"),
        ("P3", "Sistema modular de compliance", 1, "Aggregator + módulos"),
    ],
    "V. Vigencia de la guía (vs. proyecto actual)": [
        ("V1", "Stack tecnológico (ethers/MongoDB/GridFS)", 0, "El real es wagmi+viem/PostgreSQL/document_files"),
        ("V2", "Nombres de apps (`web-*`)", 0, "`apps/identity|issuer|token`"),
        ("V3", "Instalación (npm por app, MongoDB, dir `57_RWA_WEB`)", 0, "Monorepo pnpm, PostgreSQL, `rwa-web`"),
        ("V4", "Firmas (EIP-191 para ambas)", 0.5, "Inversor EIP-191; issuer EIP-712"),
        ("V5", "9 documentos referenciados", 0, "Ninguno de los 9 existe (`SCRIPTS_README.md`, `FIRMA_DIGITAL.md`, …)"),
    ],
}

GUIA_FUNC = [g for g in GUIA if g not in ("H. Ejercicios prácticos", "M. Vigencia de la guía (vs. proyecto actual)")]
GUIA_EJER = ["H. Ejercicios prácticos"]
GUIA_VIG = ["M. Vigencia de la guía (vs. proyecto actual)"]
FICH_FUNC = [g for g in FICHERO if g != "V. Vigencia de la guía (vs. proyecto actual)"]
FICH_VIG = ["V. Vigencia de la guía (vs. proyecto actual)"]


def totals(data, groups):
    items = sum(len(data[g]) for g in groups)
    score = sum(t[2] for g in groups for t in data[g])
    return score, items


def pct(score, items):
    return 0.0 if items == 0 else 100.0 * score / items


def badge(score):
    return "✅" if score == 1 else ("🟡" if score == 0.5 else "❌")


def fmt(x):
    return f"{x:.1f}".replace(".", ",")


def category_table(data):
    rows = ["| Categoría | Criterios | Puntos | Cumplimiento |", "|---|---:|---:|---:|"]
    for g, items in data.items():
        s = sum(t[2] for t in items)
        rows.append(f"| {g} | {len(items)} | {fmt(s)}/{len(items)} | **{fmt(pct(s, len(items)))} %** |")
    return "\n".join(rows)


def detail_tables(data):
    out = []
    for g, items in data.items():
        out.append(f"### {g}\n")
        out.append("| ID | Criterio | Estado | Evidencia |")
        out.append("|---|---|---|---|")
        for cid, name, score, ev in items:
            out.append(f"| {cid} | {name} | {badge(score)} | {ev} |")
        out.append("")
    return "\n".join(out)


g_func_s, g_func_n = totals(GUIA, GUIA_FUNC)
g_ejer_s, g_ejer_n = totals(GUIA, GUIA_EJER)
g_vig_s, g_vig_n = totals(GUIA, GUIA_VIG)
g_all_s, g_all_n = totals(GUIA, list(GUIA))

f_func_s, f_func_n = totals(FICHERO, FICH_FUNC)
f_vig_s, f_vig_n = totals(FICHERO, FICH_VIG)
f_all_s, f_all_n = totals(FICHERO, list(FICHERO))

glob_func_s = g_func_s + f_func_s
glob_func_n = g_func_n + f_func_n
glob_ejer_s = g_func_s + g_ejer_s + f_func_s
glob_ejer_n = g_func_n + g_ejer_n + f_func_n
glob_all_s = g_all_s + f_all_s
glob_all_n = g_all_n + f_all_n

P_G_FUNC = pct(g_func_s, g_func_n)
P_G_EJER = pct(g_ejer_s, g_ejer_n)
P_G_VIG = pct(g_vig_s, g_vig_n)
P_G_ALL = pct(g_all_s, g_all_n)
P_F_FUNC = pct(f_func_s, f_func_n)
P_F_VIG = pct(f_vig_s, f_vig_n)
P_F_ALL = pct(f_all_s, f_all_n)
P_GFUNC = pct(glob_func_s, glob_func_n)
P_GEJER = pct(glob_ejer_s, glob_ejer_n)
P_GALL = pct(glob_all_s, glob_all_n)

assert (g_all_s, g_all_n) == (43.5, 53)
assert (f_all_s, f_all_n) == (49.0, 69)
assert (glob_all_s, glob_all_n) == (92.5, 122)

report = f"""# 📊 Informe de evaluación del proyecto frente a las guías estudiantiles

> **Versión:** v1.0 · **Fecha:** 2026-10-25 · **Alcance:** línea `@sc` (`rwa-sc`) + línea `@web` (`rwa-web`)
> **Documentos de referencia (adjuntos):** `GUIA_ESTUDIANTE.md` (guía de contratos) y
> `FICHERO_PARA_ESTUDIANTE.md` (guía web). Se evalúa el proyecto **tal como está hoy**
> (`rwa-sc` en `cb72ac4`, `rwa-web` en `14ec0ff`).
> **Naturaleza:** evaluación documental y de código (no es una auditoría de seguridad ni un pentest).

---

## 1. Resumen ejecutivo

**Veredicto:** el proyecto **cumple en alto grado los contenidos funcionales** de las dos guías
(**{fmt(P_GFUNC)} %** de los {glob_func_n} criterios funcionales), pero las guías **están desactualizadas**
respecto al estado real del proyecto: al incorporar la vigencia documental, el cumplimiento literal
baja al **{fmt(P_GALL)} %** ({fmt(glob_all_s)}/{glob_all_n} criterios). La conclusión práctica es que **el producto está por
delante de su material didáctico**, no al revés.

| Dimensión | Contratos (`GUIA_ESTUDIANTE.md`) | Web (`FICHERO_PARA_ESTUDIANTE.md`) | Global |
|---|---:|---:|---:|
| Cumplimiento funcional | **{fmt(P_G_FUNC)} %** ({fmt(g_func_s)}/{g_func_n}) | **{fmt(P_F_FUNC)} %** ({fmt(f_func_s)}/{f_func_n}) | **{fmt(P_GFUNC)} %** ({fmt(glob_func_s)}/{glob_func_n}) |
| + Ejercicios/actividades | {fmt(P_G_EJER)} % ({fmt(g_ejer_s)}/{g_ejer_n}) | — | {fmt(P_GEJER)} % ({fmt(glob_ejer_s)}/{glob_ejer_n}) |
| + Vigencia de la guía | {fmt(P_G_VIG)} % ({fmt(g_vig_s)}/{g_vig_n}) | {fmt(P_F_VIG)} % ({fmt(f_vig_s)}/{f_vig_n}) | **{fmt(P_GALL)} %** ({fmt(glob_all_s)}/{glob_all_n}) |
| **Total por guía** | **{fmt(P_G_ALL)} %** ({fmt(g_all_s)}/{g_all_n}) | **{fmt(P_F_ALL)} %** ({fmt(f_all_s)}/{f_all_n}) | **{fmt(P_GALL)} %** |

### Hallazgos clave

1. **Contratos: núcleo funcional prácticamente completo** ({fmt(P_G_FUNC)} %). Existen los 16
   contratos que la guía describe (registries, identidad, token, 3 módulos de compliance,
   aggregator, 3 factories), la interfaz `ICompliance` es idéntica, y hay **443 tests** en 21
   suites con fuzz, invariantes, benchmarks de gas, cobertura y CI.
2. **La guía de contratos está desfasada en nomenclatura y firmas**: habla de `Identity.sol` y
   `Token.sol` (hoy `IdentityCloneable.sol`/`TokenCloneable.sol`), de `addClaim` con 6 argumentos
   (hoy 7, con `expiresAt` y firma EIP-712) y de `getClaim(bytes32 claimId)` (hoy
   `getClaim(topic, issuer)`). Además afirma "ERC-3643 compliant", cuando el proyecto declara
   explícitamente "**inspirado** en ERC-3643, no compliant".
3. **Web: la arquitectura y los flujos existen, pero el stack descrito es obsoleto**: las guías
   describen MongoDB/GridFS y `ethers.js`, mientras el proyecto usa **PostgreSQL** (D-095),
   `wagmi`+`viem` y `rwa.document_files` cifrado. Las apps se renombraron
   (`web-registry-trusted` → `apps/issuer`) y ahora hay una cuarta pieza (`apps/indexer`).
4. **Brecha funcional real en el marketplace**: la UI de compra/venta y de precio usa un ABI
   legacy (`pricePerToken`/`setPrice`/`buyToken`) que el `TokenCloneable` actual **no expone**;
   `market.ts` lo reconoce como deuda ("cuando el contrato de mercado se alinee con `rwa-sc`,
   este módulo debe desaparecer"). Impacta a "comprar", "precio" y al paso 6 del flujo.
5. **Documentación de soporte rota**: de los **9 documentos** que cita la guía web
   (`SCRIPTS_README.md`, `FIRMA_DIGITAL.md`, `CLAIM_REQUESTS_README.md`, `TESTING_GUIDE.md`,
   `ISSUER_PANEL_README.md`, `INTERFAZ_ISSUER.md`, `DONDE_ESTA_EL_FORMULARIO.md`,
   `TOKEN_MANAGEMENT_README.md`, `DEBUGGING_MONGODB.md`) **no existe ninguno**; en contratos faltan
   `TOKEN_CLONE_FACTORY.md` y `COMPLIANCE_AGGREGATOR_FINAL.md`.
6. **Los ejercicios de la guía no son los del proyecto**: la guía propone `TimeBasedCompliance`,
   `GeographicCompliance` y el token "Manhattan 301"; el repo tiene
   `EJERCICIOS_PRACTICOS.md` con otros ejercicios (DailyTransferLimit, Whitelist,
   CountryRestriction, DividendToken, VotingToken, Fees, presets, multisig).
7. **Fortalezas que las guías no recogen** (el proyecto va por delante): gobernanza
   `GovernanceMultisig` M-de-N con timelock (H-06), backup/DR verificado (H-30), indexer
   off-chain (H-12/H-21), SIWE, EIP-712, PostgreSQL y la separación de líneas con gates de
   sincronización (D-102).

---

## 2. Metodología

### 2.1 Objeto y fuentes

- **Objeto de evaluación:** el proyecto de las dos líneas (`rwa-sc` y `rwa-web`) frente a las dos
  guías adjuntas. No se evalúa a los estudiantes ni el proceso formativo, sino la **coherencia
  entre lo que las guías afirman y lo que el proyecto contiene**.
- **Fuentes primarias:** código (`sc/src`, `sc/test`, `sc/script`, `apps/*`, `packages/*`),
  documentación (`README.md`, `RepoTecnico/`), scripts y CI.
- **Nota sobre las copias adjuntas:** la `GUIA_ESTUDIANTE.md` adjunta es una versión **anterior**
  a la del repo (la del repo ya corrige EIP-712/`expiresAt`/`IdentityCloneable`); la
  `FICHERO_PARA_ESTUDIANTE.md` adjunta es **idéntica en contenido** a la del repo (solo cambia el
  fin de línea). La evaluación se hace contra las **copias adjuntas**, que son las que el usuario
  aportó como referencia.

### 2.2 Rúbrica

- **122 criterios** verificables, agrupados en categorías (13 en contratos, 16 en web).
- **Escala:** `1` = cumple y es localizable; `0,5` = parcial (existe con cambios, o existe la
  capacidad pero no el artefacto exacto); `0` = no cumple o no existe.
- **Dimensiones:** *funcional* (lo que la guía dice que el sistema hace/contiene), *ejercicios*
  (actividades propuestas) y *vigencia* (si la guía describe el proyecto actual o una versión
  anterior). Los porcentajes se calculan como puntos obtenidos / criterios × 100.
- **Trazabilidad:** cada criterio incluye evidencia (ruta y, cuando aplica, línea). La rúbrica
  está codificada en el generador de este informe y se puede reproducir (Anexo A).

### 2.3 Límites

- Evaluación **estática** (código y documentación). No se ejecutó la interfaz completa en
  navegador para cada funcionalidad; se apoyó en el E2E existente (claim-flow) y en los tests.
- La puntuación de "parcial" introduce juicio experto; los criterios y evidencias quedan a la
  vista para que cualquier lector pueda recalibrar.
- No se evalúan aspectos de seguridad ofensiva, rendimiento ni accesibilidad; ya tienen sus
  propios informes (`INFORME_OPTIMIZACION_*`, `perf:o5`, `a11y:o5`).

---

## 3. Resultados globales

| Indicador | Valor |
|---|---:|
| Criterios funcionales (ambas guías) | **{fmt(P_GFUNC)} %** ({fmt(glob_func_s)}/{glob_func_n}) |
| + Ejercicios propuestos | {fmt(P_GEJER)} % ({fmt(glob_ejer_s)}/{glob_ejer_n}) |
| **Cumplimiento global (incluye vigencia)** | **{fmt(P_GALL)} %** ({fmt(glob_all_s)}/{glob_all_n}) |
| Guía de contratos — total | {fmt(P_G_ALL)} % ({fmt(g_all_s)}/{g_all_n}) |
| Guía web — total | {fmt(P_F_ALL)} % ({fmt(f_all_s)}/{f_all_n}) |

> Lectura: si solo se mira "¿el proyecto hace lo que la guía enseña?", el resultado es **{fmt(P_GFUNC)} %**.
> Si se exige además que la guía describa el proyecto real, cae al **{fmt(P_GALL)} %**. La distancia
> ({fmt(P_GFUNC - P_GALL)} puntos) mide **deuda documental**, no deuda de producto.

---

## 4. Evaluación de la guía de contratos (`GUIA_ESTUDIANTE.md`)

**Resultado: {fmt(P_G_ALL)} %** ({fmt(g_all_s)}/{g_all_n}) · funcional {fmt(P_G_FUNC)} % ·
ejercicios {fmt(P_G_EJER)} % · vigencia {fmt(P_G_VIG)} %.

{category_table(GUIA)}

**Lectura por categorías:** el núcleo (conceptos, arquitectura, compliance, patrones, herramientas,
checklist) está al 100 %. Las pérdidas se concentran en: ejercicios no implementados (25 %),
vigencia de la guía (40 %), nivel 3 (50 % por nomenclatura/`onlyOwnerOrToken`) y recursos (66,7 % por
documentos inexistentes). La categoría de identidad (75 %) refleja el único cambio de API
significativo: `addClaim`/`getClaim`.

{detail_tables(GUIA)}

### 4.1 Brechas del proyecto (no imputables a la guía)

- **`F2` (parcial):** el aggregator real usa `onlyToken(address)` + `Ownable`, mientras la guía
  muestra `onlyOwnerOrToken(address)`; funcionalmente equivalente, pero conviene documentar la
  API real.
- **`L1`:** faltan `TOKEN_CLONE_FACTORY.md` y `COMPLIANCE_AGGREGATOR_FINAL.md` que la guía cita
  como documentación del proyecto.
- **`H1`–`H3`:** los ejercicios de la guía no están resueltos ni existen como contratos; el repo
  ofrece otros ejercicios en `EJERCICIOS_PRACTICOS.md`. Si la guía es material del curso, conviene
  alinear ambos catálogos.

### 4.2 Brechas de la guía (vigencia)

- `Identity.sol` → `IdentityCloneable.sol`, `Token.sol` → `TokenCloneable.sol`.
- `addClaim(topic, scheme, issuer, signature, data, uri)` → 7 argumentos con `expiresAt` y
  validación EIP-712.
- `getClaim(bytes32 claimId)` → `getClaim(uint256 topic, address issuer)`.
- "Implementar el estándar ERC-3643" → "inspirado en ERC-3643, no compliant".

---

## 5. Evaluación de la guía web (`FICHERO_PARA_ESTUDIANTE.md`)

**Resultado: {fmt(P_F_ALL)} %** ({fmt(f_all_s)}/{f_all_n}) · funcional {fmt(P_F_FUNC)} % ·
vigencia {fmt(P_F_VIG)} %.

{category_table(FICHERO)}

**Lectura por categorías:** las apps y sus flujos están completos (identity, issuer, token al
100 %; APIs al 100 %), y el flujo claim está verificado E2E. Las pérdidas se concentran en el
**stack tecnológico** (30 %: MongoDB/GridFS/ethers), la **base de datos** (16,7 %), el
**despliegue/instalación** (62,5 %) y, sobre todo, la **vigencia** (10 %). El token baja al 71,4 %
por el marketplace legacy.

{detail_tables(FICHERO)}

### 5.1 Brechas del proyecto (no imputables a la guía)

- **Marketplace/precio (`G4`, `G5`, `H6`)**: la UI usa `pricePerToken`/`setPrice`/`buyToken` de un
  ABI legacy; el `TokenCloneable` actual no los declara. `apps/token/lib/contracts/market.ts:4-7`
  reconoce la deuda. Es la brecha funcional más importante de la línea web.
- **`G2`**: no hay UI para retirar módulos de compliance (sí para añadirlos).
- **`G6`/`H7`**: transferencia de tokens existe en código pero sin flujo dedicado ni E2E.
- **`L`/`N`**: cobertura E2E solo del claim-flow; compra/transferencia no están en E2E.

### 5.2 Brechas de la guía (vigencia)

- MongoDB/GridFS → PostgreSQL + `rwa.document_files` (D-095/D-093).
- `ethers.js` v6 → `wagmi` + `viem` (cero `ethers`, cero `window.ethereum`).
- `web-identity`/`web-registry-trusted`/`web-token` → `apps/identity`/`apps/issuer`/`apps/token`
  (monorepo pnpm) + `apps/indexer`.
- Firmas: la guía usa `signMessage` (EIP-191) para ambas; el proyecto usa EIP-191 para el
  inversor, **EIP-712** para el issuer y **SIWE** para la sesión.
- Los 9 documentos de soporte citados no existen.

---

## 6. Hallazgos transversales

| # | Hallazgo | Guía(s) | Impacto | Evidencia |
|---|---|---|---|---|
| T1 | Stack de datos obsoleto (MongoDB/GridFS → PostgreSQL + `document_files`) | web | Alto | `docker-compose.yml` (postgres:16), `README.md:70-78` |
| T2 | Stack Web3 obsoleto (`ethers` → `wagmi`/`viem`) | web | Alto | `README.md:70`; 0 imports de `ethers` en código |
| T3 | Renombres de apps y contratos | ambas | Medio | `apps/*`, `IdentityCloneable.sol`, `TokenCloneable.sol` |
| T4 | Firmas: EIP-191 → EIP-712 (+SIWE) | web | Medio | `packages/shared/src/claims/eip712.ts`, `RequestDetailModal.tsx` |
| T5 | Marketplace con ABI legacy sin soporte en el contrato actual | web | **Alto (funcional)** | `market.ts:4-7` |
| T6 | Documentos de soporte citados inexistentes (9 web + 2 contratos) | ambas | Medio | `ls` de los nombres citados |
| T7 | Ejercicios de la guía ≠ ejercicios del repo | contratos | Bajo/Medio | `EJERCICIOS_PRACTICOS.md` |
| T8 | Afirmación "ERC-3643 compliant" corregida por el proyecto | contratos | Bajo | `rwa-sc/README.md:21` |
| T9 | El proyecto incorpora piezas nuevas que las guías no recogen (gobernanza, backup/DR, indexer, gates) | ambas | Bajo (positivo) | `estado_proyecto.md`, `pruebas/` |

---

## 7. Recomendaciones priorizadas

### P0 — Actualizar las guías (mayor impacto, bajo esfuerzo)
1. **Stack real**: PostgreSQL (D-095), `wagmi`+`viem`, `rwa.document_files`, monorepo pnpm,
   `apps/identity|issuer|token` (+ `indexer`), puertos y scripts actuales.
2. **Contratos reales**: nombres `IdentityCloneable`/`TokenCloneable`, `addClaim` de 7 argumentos,
   `getClaim(topic,issuer)`, `onlyToken`, y matiz "inspirado en ERC-3643".
3. **Firmas**: EIP-191 (inversor) + EIP-712 (issuer) + SIWE (sesión); eliminar referencias a
   MongoDB/GridFS/ethers.
4. **Enlaces**: sustituir los 9 documentos inexistentes por los reales (`README.md`,
   `GUIA_RAPIDA.md`, `DIAGRAMA_C4.md`, `RepoTecnico/*`).

### P1 — Cerrar la brecha funcional del marketplace
5. Alinear el contrato de mercado con la UI: o se añade un `Marketplace`/`buyToken`/`setPrice` a
   `rwa-sc` (con tests y evento de compra para el indexer), o se retira/marca la UI como legacy.
   Mientras tanto, marcar claramente "no operativo" en la UI y en la guía.
6. Añadir E2E de compra y transferencia (hoy solo claim-flow).

### P2 — Completar material y ejercicios
7. Decidir qué catálogo de ejercicios es el oficial (guía vs `EJERCICIOS_PRACTICOS.md`) y
   referenciarlos mutuamente.
8. Crear/renombrar `TOKEN_CLONE_FACTORY.md` y `COMPLIANCE_AGGREGATOR_FINAL.md` (o retirar las
   referencias de la guía).

### P3 — Mejoras de mantenimiento
9. Añadir un gate/check que detecte referencias a documentos inexistentes (extensión de
   `check_docs.sh`) y otro que detecte términos obsoletos en guías (`MongoDB`, `ethers`,
   `web-identity`) para evitar nueva deriva.
10. Mantener este informe como línea base y repetirlo al cerrar cada etapa.

---

## 8. Anexo A — Verificación reproducible

```bash
# Contratos: inventario, firmas y tests
ls rwa-sc/sc/src rwa-sc/sc/src/compliance
grep -n "function addClaim" -A9 rwa-sc/sc/src/IdentityCloneable.sol
grep -nE "function (registerIdentity|isRegistered|getIdentity)\\(" rwa-sc/sc/src/IdentityRegistry.sol
grep -nE "function (addTrustedIssuer|isTrustedIssuer|getIssuerClaimTopics)\\(" rwa-sc/sc/src/TrustedIssuersRegistry.sol
grep -nE "function (canTransfer|transferred|created|destroyed)\\(" rwa-sc/sc/src/ICompliance.sol
cd rwa-sc/sc && forge test --summary          # 443 tests / 21 suites

# Web: stack, apps, rutas y firmas
ls rwa-web/apps
grep -rIl --include=*.ts --include=*.tsx --exclude-dir=node_modules --exclude-dir=.next ethers rwa-web/apps rwa-web/packages
grep -nE "postgres|mongo" rwa-web/docker-compose.yml
find rwa-web/apps -path '*/app/api/*/route.ts' | sort
grep -rn "signTypedData\\|signMessage" rwa-web/apps rwa-web/packages

# Datos: topics canónicos
psql "$DATABASE_URL" -tAc "SELECT id, code FROM rwa.claim_topics ORDER BY id"
```

> Rúbrica codificada y versionada en `RepoTecnico/scripts/gen_informe_evaluacion_guias.py`
> (122 criterios). Este informe se regenera con `python3 RepoTecnico/scripts/gen_informe_evaluacion_guias.py`;
> las evidencias de cada fila permiten auditar cada decisión.

---

*Fin del informe — `INFORME_EVALUACION_GUIAS_ESTUDIANTE_V1.md`*
"""

import re as _re
report = _re.sub(r"(\d+),0/", r"\1/", report)
OUT.write_text(report, encoding="utf-8")
print(f"OK -> {OUT} ({len(report.splitlines())} líneas)")
print(f"GUIA: funcional {P_G_FUNC:.1f}% | ejercicios {P_G_EJER:.1f}% | vigencia {P_G_VIG:.1f}% | total {P_G_ALL:.1f}% ({g_all_s}/{g_all_n})")
print(f"FICHERO: funcional {P_F_FUNC:.1f}% | vigencia {P_F_VIG:.1f}% | total {P_F_ALL:.1f}% ({f_all_s}/{f_all_n})")
print(f"GLOBAL: funcional {P_GFUNC:.1f}% ({glob_func_s}/{glob_func_n}) | con ejercicios {P_GEJER:.1f}% | total {P_GALL:.1f}% ({glob_all_s}/{glob_all_n})")
