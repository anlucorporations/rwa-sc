# 📌 Estado del Proyecto — RWA (Mejora)

> **Proyecto:** Mejora y estabilización de la plataforma RWA (Real World Assets, ERC-3643)
> **Directivo:** Asistente de Proyecto (`@asistenteProyecto`)
> **Versión:** v2.0 · 2026-10-03 (cierre de la Fase 2)

## Fases

| Fase | Nombre | Estado | Criterios |
|---|---|---|---|
| 1 | Concepción | ✅ COMPLETADO | Artefactos creados, repos y GCP definidos, entrevista de 3 bloques |
| 2 | Auditoría | ✅ COMPLETADO (por confirmar) | Auditoría sin issues críticos + CU auditados + gráficos + documento técnico auditado |
| 3 | Desarrollo | 🔄 EN CURSO — Ciclos 1, 1b, 2 y 3 ✅ · Ciclos 4–8 autorizados en bloque | Plan vertical aprobado, ciclos completados y probados |
| 4 | Pruebas | ⬜ Por cerrar | 100 % de tests en verde (Forge) + cobertura ≥ 80 % |
| 5 | Manuales | ⬜ Por cerrar | Manuales generados y confirmación final |

## Hitos de la Fase 2 (completados)

- [x] Auditoría del proyecto en 3 fases y 7 lentes: **34 hallazgos** (1 crítica, 11 altas, 18 medias, 4 bajas), 12 falsos positivos descartados y veredicto explícito.
- [x] **PoC propios del Lead** que reproducen los dos fallos de mayor impacto (H-01 claims forjados, H-05 `isVerified` fail-open): ambos PASS, guardados en `evidencias/`.
- [x] Métricas reales medidas: 151 tests declarados, 93 pasan, 5 fallan, **53 nunca arrancan**, cobertura **42,86 %**, 52 avisos de lint.
- [x] Requisitos v1.1: **RF-001..RF-013** + RNF-001..RNF-006 + RT-001..RT-008 y backlog priorizado con los 34 hallazgos.
- [x] Casos de uso v1.3: **17 CU**, 92 Gherkin + 50 EARS = **142 criterios** testeables, auditados y corregidos.
- [x] Diagramas: 1 UML de casos de uso + 6 de secuencia + matriz actores↔CU.
- [x] Artefactos de datos sincronizados (diccionario v1.1, E-R v1.1, SQL v0.2) contra el código real.
- [x] Documento técnico v1.1 (as-is, to-be, datos, trazas, entornos, CI, riesgos y criterios V2) + su auditoría (13 hallazgos DT-01..DT-13).

## Hitos de la Fase 3 (en curso)

- [x] **Ciclo 1 — RF-005 · Build reproducible y suites en verde** (commit local `d959145`, sin push):
  `solc 0.8.20` + optimizer 200 + `evm_version = "paris"`; submódulos pinneados y un único `.gitmodules`;
  las 2 suites muertas adaptadas a **factory + clon + `initialize`**; 3 tests de gas reescritos con línea base
  equivalente; `.gas-snapshot` versionado. Resultado verificado por el Lead: **151/151 tests pasan, 0 fallan**,
  `forge fmt --check` limpio, cobertura `src/` **86,33 %** (total 67,50 %, que incluye `script/` y benchmarks).
- [x] **Ciclo 2 — RF-001 · Verificación criptográfica del claim con EIP-712** (commit local, sin push):
  `IdentityCloneable.addClaim` exige firma **EIP-712** del `issuer` (dominio `RWA-Identity`/`1`/`chainId`/clon
  y `CLAIM_TYPEHASH` con `expiresAt`, D-020), con `scheme == 1`, longitud 65, `issuer != 0`,
  `recovered == issuer` y `walletOwner == owner()`; sobrescritura solo con firma válida (D-018) y
  autorización de topic delegada al token (D-025). `createIdentityWithClaim` propaga `expiresAt`.
  **264/264 tests** (21 nuevos `test_RF001_*`), `src/` 96,08 % de líneas y `IdentityCloneable` 100 %;
  PoC H-01 **invertido** (firma vacía → revert). Cierra **H-01** y el bloqueante **B-1**.
- [x] **Ciclo 3 — RF-002 · Retirada del flag de bypass y anti-reentrancia** (commit local `45496cf`):
  `bypassCompliance` **eliminado** del storage (sustituido por la ruta interna `_forcedUpdate`); `nonReentrant`
  en los 5 puntos de entrada (`transfer`, `transferFrom`, `mint`, `burn`, `forcedTransfer`) y en las entradas
  con estado del `ComplianceAggregator`; gate `check_no_bypass_flag.sh`; `forcedTransfer` rechaza `from == 0`
  (cerraba una vía de acuñación). **281/281 tests** (17 nuevos, 7 de reentrancia que revierten con
  `ReentrancyGuardReentrantCall`), `src/` 96,28 % líneas / 82,90 % ramas, +3.074 gas por transferencia y
  **0** en `createToken`. Decisiones **D-029..D-032**.
- [x] **Documentación versionada:** `RepoTecnico/` se movió dentro del repo (`rwa-sc/RepoTecnico/`, commit
  `fb38e4f`), por lo que los ciclos siguientes versionan código **y** documentación. Decisión del usuario.
- [ ] Ciclo 3 (RF-002) → Ciclo 4 (RF-003) → Ciclo 5 (RF-004) → Ciclo 6 (RF-011)
  → Ciclo 7 (RF-012) → Ciclo 8 (RF-013) → **Ciclo 8b (toolchain: solc ≥ 0.8.24 + `EIP712Upgradeable` de OZ,
  decidido por el usuario antes del despliegue)** → Ciclo 9 (RF-010) → Ciclo 10 (RF-006) → Ciclo 11 (RF-009).

- [x] **Ciclo 1b — RF-005 · Cobertura ≥ 80 % por contrato en los registries** (commit local `a92cf1d`):
  3 suites nuevas (92 tests: IdentityRegistry 34, TrustedIssuersRegistry 33, ClaimTopicsRegistry 25);
  los tres contratos pasan de 37/38/45 % a **100 %** de líneas, sentencias, ramas y funciones; agregado `src/`
  **96,00 %** de líneas y 81,77 % de ramas; **243/243 tests en verde**; `src/` intacto (solo tests y snapshot).
  El ciclo descubrió **HB-13..HB-16** (registrados en `requerimientos.md` §2 y agrupados por afinidad en los
  Ciclos 4 y 8 salvo HB-16, que va con H-20 al backlog).

### Corrección de cifras tras el Ciclo 1

| Afirmación previa | Medición real |
|---|---|
| "139 tests, 100 % passing" | **151 tests, 151 pasan** (antes: 98 contados, 93 pasan, 5 fallan, 53 muertos) |
| "Ahorro de gas 88–98 %" | **45–59 %** medido con comparación equivalente (Token 55 %, Identity 59 %, Identity+claim 45 %, Registry 53 %) |
| "Cobertura > 80 %" | `src/` **86,33 %** (agregado) · total 67,50 % · puntos débiles por contrato: `IdentityRegistry` 37 %, `TrustedIssuersRegistry` 38 %, `ClaimTopicsRegistry` 45 % |

## Acuerdos y decisiones

| ID | Decisión |
|---|---|
| D-001 | `rwa-sc` es la base de este ciclo; los cambios de contrato impactan a las apps web |
| D-002 | La base de datos del proyecto es **MongoDB**; `base_datos.sql` es borrador de una eventual migración |
| D-003 | Alcance = **solo `rwa-sc`**; `rwa-web` fuera de este ciclo |
| D-004 | Prioridad = **seguridad + estabilidad del build** |
| D-005 | Rama de trabajo = **`rwa-sc-DSH-GCP`** (GitLab.com) |
| D-006 | `AGENT_ROLE`: **whitelist de destinos + límites** |
| D-007 | Claims: **firma EIP-712 tipada** verificada con `ecrecover` |
| D-008 | Cadena destino = **Besu CodeCrypto** + **GitLab CI** |
| D-009 | **Redeploy limpio** permitido (se puede mover el layout de storage) |
| D-010 | Pruebas: 100 % de lo existente + nuevas + fuzz + cobertura ≥ 80 % |
| D-011 | Docs + **SECURITY.md** + **CHANGELOG de ABIs** |
| D-012 | *(cerrada por D-016)* política de compliance en `mint()` |
| D-013 | *(cerrada por D-018)* política de reintento de claim |
| D-014 | Alcance ampliado a los 3 fallos abiertos de seguridad (RF-011, RF-012, RF-013) |
| D-015 | Los tests se adaptan al patrón **factory + clon + `initialize`** |
| D-016 | Se **mantiene** el chequeo de compliance en `mint()` |
| D-017 | Cobertura ≥ 80 % medida sobre `src/` sin interfaces ni `test/` |
| D-018 | Reintento de claim: **sobrescritura con firma válida** (renovación) |
| D-019 | Ciclo de vida: **redeploy limpio con EIP-1167** + runbook de migración |
| D-020 | EIP-712: dominio `RWA-Identity`/`1`/`chainId`/clon y `CLAIM_TYPEHASH` **con `expiresAt` firmado** |
| D-021 | Gobernanza: **roles separados + multisig 2-de-3 + timelock + custodio de claves** |
| D-022 | **Tope de suministro** (`maxSupply`) administrable con evento |
| D-023 | `ComplianceAggregator` **fail-closed** con registro automático del token al primer módulo |
| D-024 | **Auditoría externa** bloqueante solo para producción con activos reales |
| D-025 | RF-001: la autorización del issuer **para el topic** la impone el token (`isVerified`), no `addClaim` |
| D-026 | EIP-712 reproducido a mano (mismo digest) por el pragma `^0.8.24` de `EIP712Upgradeable` vs `solc 0.8.20`; `ECDSA` sí es de OpenZeppelin |
| D-027 | `createIdentityWithClaim`: el `walletOwner` firmado es la factory (owner temporal); anti-replay por `verifyingContract` |
| D-028 | Los criterios de autorización de topic de CU-02/CU-03 se reubican en la capa token (coherente con D-025) |

## Plan de la Fase 3 (orden aprobado)

```
RF-005 (build reproducible: submódulos, solc/optimizer fijados, 0 tests en rojo)
  → RF-001 (EIP-712 con D-020)   → RF-002 (reentrancia, retirada del flag bypass)
  → RF-003 (ERC-165 en módulos)  → RF-004 (whitelist + límites + maxSupply)
  → RF-011 (isVerified fail-closed) → RF-012 (aggregator fail-closed, D-023)
  → RF-013 (vigencia y revocación de claim)
  → RF-010 (secretos fuera de scripts) → RF-006 (docs + SECURITY.md + changelog ABIs) → RF-009 (CI)
```

Criterios de salida de la V2: **B-1..B-8** (bloqueantes) y **C-1..C-11** (calidad), definidos en
`INFORME_OPTIMIZACION_V1.md` §9 y enlazados a los RF en `documento_tecnico.md`.

## Artefactos de `RepoTecnico/`

| Archivo | Versión | Contenido |
|---|---|---|
| `requerimientos.md` | v1.1 | RF-001..RF-013, RNF, RT, HB-01..HB-12, entrevista (5 bloques), backlog |
| `INFORME_OPTIMIZACION_V1.md` | V1 | Auditoría de 34 hallazgos + plan + criterios V2 |
| `casos_uso/casos_uso.md` | v1.3 | 17 CU y 142 criterios Gherkin/EARS |
| `casos_uso/AUDITORIA_CASOS_USO.md` | — | 17 hallazgos de la auditoría de CU |
| `casos_uso/diagramas_casos_uso.md` | v1.1 | 7 diagramas Mermaid |
| `documento_tecnico.md` | v1.1 | Arquitectura, datos, trazas, entornos, riesgos |
| `AUDITORIA_DOCUMENTO_TECNICO.md` | — | 13 hallazgos DT-01..DT-13 |
| `diccionario_datos.md` · `diagrama_er.md` · `base_datos.sql` | v1.1 · v1.1 · v0.2 | Modelo de datos |
| `metricas_ejecucion.md` · `entornos_globales.md` | — | Métricas y entorno reales |
| `evidencias/` | — | PoC H-01/H-05, salida y lint (52 avisos) |

## Brechas abiertas (declaradas)

1. **Sin CI**: no existe `.gitlab-ci.yml`; las métricas son mediciones puntuales (RF-009).
2. **Árbol sin versionar**: HEAD del remoto = 1 commit con solo `README.md` (HB-04 / H-04).
3. **Sin auditoría externa**: bloqueante para producción (D-024).
4. **Cobertura** resuelta para `src/`: 96,08 % de líneas (Ciclo 2); el gate de CI por umbral llega en RF-009.
5. **DF3-05..DF3-10**: detalles de diseño que se resuelven dentro de los ciclos de la Fase 3.

## Próximo paso

Confirmación del usuario para iniciar el **Ciclo 3 (RF-002)**: retirada del flag `bypassCompliance` y
protección anti-reentrancia (`ReentrancyGuardUpgradeable`) en `TokenCloneable` y `ComplianceAggregator`.
