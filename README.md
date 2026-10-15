# Smart Contracts - RWA Token Platform

## 🎓 Para Estudiantes

**¿Primera vez aquí? Empieza con:**

📖 **[START_HERE.md](START_HERE.md)** ← Lee esto primero

Luego continúa con:

1. **[GUIA_ESTUDIANTE.md](GUIA_ESTUDIANTE.md)** - Conceptos, arquitectura, teoría
2. **[EJERCICIOS_PRACTICOS.md](EJERCICIOS_PRACTICOS.md)** - Ejercicios paso a paso
3. **[REFERENCIA_TECNICA.md](REFERENCIA_TECNICA.md)** - Templates, snippets, checklists

---

## 📊 Overview del Proyecto

Este proyecto implementa un **sistema de tokenización RWA** (Real World Assets) con:

- ⚠️ **Inspirado en ERC-3643 / T-REX**, no "ERC-3643 compliant": implementa un subconjunto propio de interfaces (ver declaración verificable en [`SECURITY.md`](SECURITY.md)). **No auditado y no apto para producción con activos reales** (ver [`RepoTecnico/INFORME_OPTIMIZACION_V1.md`](RepoTecnico/INFORME_OPTIMIZACION_V1.md)).
- ✅ **Clone Factory** (EIP-1167) — ahorro de gas medido con comparación equivalente: **45–59 %** (Token 55 %, Identity 59 %, Identity+claim 45 %, Registry 53 %; ver `.gas-snapshot`).
- ✅ **Compliance Aggregator** — gestión modular de compliance (fail-closed).
- ✅ **443 tests** (443 pasando, 0 fallos, 0 skipped) — `forge test`, cifra respaldada por [`RepoTecnico/metricas_ejecucion.md`](RepoTecnico/metricas_ejecucion.md).
- ✅ **Cobertura de `src/`**: **97,18 % de líneas** (mínimo por contrato 92,31 %; D-017: sin interfaces ni `test/`; `metricas_ejecucion.md`).
- ✅ **Gas medido** con baseline versionado (`sc/.gas-snapshot`); **no production-ready** sin auditoría externa (D-024).

---

## 🏗️ Arquitectura

### Componentes Principales

```
┌─────────────────────────────────────────────────────────┐
│                  RWA TOKEN PLATFORM                     │
└─────────────────────────────────────────────────────────┘
                         │
      ┌──────────────────┼──────────────────┐
      │                  │                  │
      ▼                  ▼                  ▼
┌──────────┐      ┌──────────┐       ┌──────────┐
│  Tokens  │      │ Identity │       │Compliance│
└──────────┘      └──────────┘       └──────────┘
```

### 1. Token System

**Contracts:**
- `TokenCloneable.sol` - Token clonable principal (EIP-1167)
- `TokenCloneFactory.sol` - Factory para crear tokens
- `ICompliance.sol` - Interfaz de módulos de compliance

**Key Features:**
- Identity verification obligatoria
- Compliance checks en cada transfer
- Role-based access control
- Pausability
- Freeze accounts

### 2. Identity System

**Contracts:**
- `IdentityCloneable.sol` - Identity clonable con claims firmados (EIP-712)
- `IdentityCloneFactory.sol` - Factory para identities
- `IdentityRegistry.sol` - Registro de identities
- `TrustedIssuersRegistry.sol` - Emisores autorizados
- `ClaimTopicsRegistry.sol` / `ClaimTopicsRegistryCloneable.sol` - Topics requeridos
- `ClaimTopicsRegistryCloneFactory.sol` - Factory del registro de topics

**Key Features:**
- Claims on-chain
- Trusted issuers
- Configurable claim requirements

### 3. Compliance System

**Contracts:**
- `compliance/ComplianceAggregator.sol` - Aggregador modular (fail-closed)
- `compliance/MaxBalanceCompliance.sol` - Límite de saldo
- `compliance/MaxHoldersCompliance.sol` - Límite de holders
- `compliance/TransferLockCompliance.sol` - Período de bloqueo

**Key Features:**
- Modular architecture
- Extensible (add any ICompliance module)
- Dual management (owner + token admin)
- No holdersList in aggregator

---

## 📁 Estructura de Archivos

### Contratos (`src/`)

```
Tokens:
  - TokenCloneable.sol           (Token clonable, EIP-1167)
  - TokenCloneFactory.sol        (Factory de tokens)

Identity:
  - IdentityCloneable.sol        (Identity clonable con claims EIP-712)
  - IdentityCloneFactory.sol     (Factory de identities)
  - IdentityRegistry.sol         (Registro)
  - TrustedIssuersRegistry.sol   (Emisores)
  - ClaimTopicsRegistry.sol      (Topics requeridos)
  - ClaimTopicsRegistryCloneable.sol
  - ClaimTopicsRegistryCloneFactory.sol

Compliance:
  - compliance/
    ├─ ComplianceAggregator.sol       (Aggregador modular)
    ├─ MaxBalanceCompliance.sol       (Límite de balance)
    ├─ MaxHoldersCompliance.sol       (Límite de holders)
    └─ TransferLockCompliance.sol     (Lock period)
  - ICompliance.sol              (Interface)
  - IClaimTopicsRegistry.sol     (Interface)

Gobernanza:
  - GovernanceMultisig.sol       (Multisig M-de-N + timelock, H-06)
```

### Scripts (`script/`)

```
- DeployFullStack.s.sol                  (Despliegue canónico end-to-end)
- DeployTokenCloneFactory.s.sol          (Deploy token factory)
- DeployIdentityCloneFactory.s.sol       (Deploy identity factory)
- DeployClaimTopicsRegistryCloneFactory.s.sol
- DeployGovernance.s.sol                 (Gobernanza multisig + timelock)
- DeployComplianceAggregator.s.sol       (Deploy aggregator)
- CreateTokenWithCloneFactory.s.sol      (Crear token)
- CompleteDeploymentExample.s.sol        (Ejemplo completo)
- deploy.sh                              (Orquestación, secretos y verificación)
- ci/check_no_bypass_flag.sh             (Gate RF-002)
- ci/abi_diff.sh                         (Gate RF-006 — deriva de ABIs)
- ci/check_docs.sh                       (Gate RF-006 — documentación)
- ci/check_secrets.sh                    (Gate RF-010 — secretos)
- ci/check_claim_topics.sh               (Gate H-13 — catálogo de claim topics)
```

### Tests (`test/`)

```
- Token.t.sol                          (30 tests)
- TokenCloneFactory.t.sol              (17 tests)
- IdentityCloneFactory.t.sol           (15 tests)
- IdentityCloneable.t.sol              (24 tests)
- IdentityRegistry.t.sol               (41 tests)
- TrustedIssuersRegistry.t.sol         (34 tests)
- ClaimTopicsRegistry.t.sol            (25 tests)
- ClaimTopicsRegistryCloneFactory.t.sol (16 tests)
- ComplianceAggregator.t.sol           (25 tests)
- MaxBalanceCompliance.t.sol           (18 tests)
- MaxHoldersCompliance.t.sol           (25 tests)
- TransferLockCompliance.t.sol         (23 tests)
- RF003_ERC165.t.sol                   (16 tests)
- RF011_FailClosed.t.sol               (8 tests)
- RF012_AggregatorFailClosed.t.sol     (9 tests)
- RF013_ClaimLifecycle.t.sol           (20 tests)
- TokenLimits.t.sol                    (17 tests)
- TokenReentrancy.t.sol                (18 tests)
- AuditoriaFinalAF.t.sol               (19 tests)
- H20_Escalabilidad.t.sol              (6 tests)
- GovernanceMultisig.t.sol             (23 tests)
- invariant/AggregatorInvariants.t.sol (2 tests)
- invariant/IdentityInvariants.t.sol   (2 tests)
- invariant/RegistryInvariants.t.sol   (2 tests)
- invariant/TokenInvariants.t.sol      (2 tests)

Total: 443 tests en 25 suites (443 pasando, 0 fallos, 0 skipped)
```

---

## 🚀 Quick Start

### Prerequisitos

```bash
# Instalar Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verificar instalación
forge --version
```

### Clonar el repositorio (submódulos reproducibles)

Las dependencias (`forge-std` v1.12.0, `openzeppelin-contracts` v5.5.0 y
`openzeppelin-contracts-upgradeable` v5.5.0) están declaradas como submódulos en
**`rwa-sc/.gitmodules`** (único `.gitmodules` del repo) y pinneadas por revisión en
**`sc/foundry.lock`**. Bootstrap sin pasos manuales:

```bash
# Clona el repo y sus 3 submódulos en un solo paso
git clone --recurse-submodules <url-del-repo> rwa-sc

# Si ya lo clonaste sin submódulos:
git submodule update --init --recursive

# Verifica que los 3 submódulos estén en la revisión pinneada
# (no debe aparecer ningún prefijo '-' ni '+')
git submodule status
```

### Compilar y Testear

```bash
export PATH="$HOME/.foundry/bin:$PATH"   # Forge/Anvil v1.8.3
cd sc

# Compilar
forge build

# Ejecutar todos los tests
forge test

# Tests con detalles
forge test -vv

# Gas report
forge test --gas-report
```

### Deploy Local

```bash
# Terminal 1: Iniciar Anvil
anvil

# Terminal 2: Deploy
cd sc

# Deploy token factory
forge script script/DeployTokenCloneFactory.s.sol --rpc-url localhost --broadcast

# Deploy identity factory
forge script script/DeployIdentityCloneFactory.s.sol --rpc-url localhost --broadcast

# Deploy compliance aggregator
forge script script/DeployComplianceAggregator.s.sol --rpc-url localhost --broadcast

# Crear un token
forge script script/CreateTokenWithCloneFactory.s.sol --rpc-url localhost --broadcast
```

---

## 📚 Documentación

### Para Estudiantes (Educativo)

| Documento | Descripción | Tiempo |
|-----------|-------------|--------|
| **START_HERE.md** | Punto de inicio, mapa de documentación | 10 min |
| **GUIA_ESTUDIANTE.md** | Conceptos, arquitectura, explicaciones | 2-3 horas |
| **EJERCICIOS_PRACTICOS.md** | Ejercicios con código | Varias semanas |
| **REFERENCIA_TECNICA.md** | Templates, snippets, comandos | Referencia |

### Para Desarrolladores (Técnico)

| Documento | Descripción |
|-----------|-------------|
| **REFERENCIA_TECNICA.md** | Patrón Clone Factory, aggregator y snippets |
| **DEPENDENCIAS_CONTRATOS.md** | Dependencias e imports entre contratos |
| **SECURITY.md** | Modelo de amenazas, hallazgos y riesgos residuales |
| **CHANGELOG_ABIS.md** | Historial de cambios de ABI y su impacto en consumidores |
| **RepoTecnico/documento_tecnico.md** | Documento técnico del proyecto |
| **RepoTecnico/metricas_ejecucion.md** | Cifras reales medidas (tests, cobertura, gas) |

### Para Project Managers (Ejecutivo)

| Documento | Descripción |
|-----------|-------------|
| **RepoTecnico/estado_proyecto.md** | Estado de fases, hitos y decisiones |
| **RepoTecnico/requerimientos.md** | Requisitos, decisiones (D-xxx) y backlog |
| **RepoTecnico/requerimientos_no_funcionales.md** | Catálogo RNF ISO 25010 y políticas (regulatorio, PII, observabilidad, continuidad, soporte) |
| **RepoTecnico/plan_desarrollo.md** | Ciclos de desarrollo y trazabilidad |
| **RepoTecnico/INFORME_OPTIMIZACION_V1.md** | Auditoría V1: 34 hallazgos y plan de acción |

---

## 🧪 Testing

### Ejecutar Tests

```bash
# Todos los tests
forge test

# Suite específica
forge test --match-contract TokenTest -vv

# Test específico
forge test --match-test test_Transfer_Success -vvvv

# Con gas report
forge test --gas-report

# Coverage
forge coverage
```

### Test Suites

| Suite | Tests | Descripción |
|-------|-------|-------------|
| TokenTest | 30 | Token clonable principal |
| TokenCloneFactoryTest | 17 | Token factory |
| TokenLimitsTest | 17 | Whitelist/topes/`maxSupply` (RF-004) |
| TokenReentrancyTest | 18 | Anti-reentrancia (RF-002) |
| ComplianceAggregatorTest | 25 | Compliance aggregator |
| RF012_AggregatorFailClosedTest | 9 | Aggregator fail-closed (RF-012) |
| IdentityCloneFactoryTest | 15 | Identity factory |
| IdentityCloneableRF001Test | 24 | Claims EIP-712 (RF-001) |
| RF013_ClaimLifecycleTest | 20 | Vigencia/revocación de claims (RF-013) |
| IdentityRegistryTest | 41 | Registro de identidades |
| TrustedIssuersRegistryTest | 34 | Emisores autorizados |
| ClaimTopicsRegistryTest | 25 | Topics requeridos |
| ClaimTopicsRegistryCloneFactoryTest | 16 | Claim topics factory |
| RF011_FailClosedTest | 8 | `isVerified` fail-closed (RF-011) |
| RF003_ERC165Test | 16 | Validación de módulos ERC-165 (RF-003) |
| MaxBalanceComplianceTest | 18 | Max balance module |
| MaxHoldersComplianceTest | 25 | Max holders module |
| TransferLockComplianceTest | 23 | Transfer lock module |
| AuditoriaFinalAFTest | 19 | Auditoría adversarial final (AF-01..AF-15) |
| AggregatorInvariantsTest | 2 | Invariantes con estado del aggregator |
| IdentityInvariantsTest | 2 | Invariantes con estado de la identidad |
| RegistryInvariantsTest | 2 | Invariantes con estado de los registries |
| TokenInvariantsTest | 2 | Invariantes con estado del token |
| H20EscalabilidadTest | 6 | Índices O(1) y vistas paginadas (H-20) |
| GovernanceMultisigTest | 23 | Gobernanza multisig + timelock (H-06) |

**Total: 443 tests en 25 suites (443 pasando, 0 fallos, 0 skipped)** — verificado con `forge test` y enlazado a [`RepoTecnico/metricas_ejecucion.md`](RepoTecnico/metricas_ejecucion.md).

---

## 🔄 Integración Continua (RF-009)

El pipeline de GitLab vive en [`.gitlab-ci.yml`](.gitlab-ci.yml) y se ejecuta en la rama
**`rwa-sc-DSH-GCP`** y en cada *merge request*. Imagen fijada:
`ghcr.io/foundry-rs/foundry:v1.8.3` (la misma versión que el toolchain local).

| Etapa | Comando | Gate |
|---|---|---|
| `validate` | `git submodule update --init --recursive` + `git submodule status` | B-5: 3 submódulos pinneados, sin prefijos `-`/`+` |
| `build` | `forge build` | compilación reproducible |
| `fmt` | `forge fmt --check` | formato limpio |
| `test` | `forge test` | **RNF-003**: cualquier fallo detiene el pipeline; publica el **conteo real** como artefacto |
| `coverage` | `forge coverage --report summary --report lcov` | **RNF-002 / D-017 / D-042**: agregado de `src/` ≥ 80 % (sin interfaces) **y** mínimo por contrato ≥ 80 % |
| `gas` | `forge snapshot --check --tolerance 5` | **RNF-001 / D-039** |
| `ci-checks` | `check_no_bypass_flag.sh`, `check_docs.sh`, `abi_diff.sh`, `check_secrets.sh`, `check_claim_topics.sh` | RF-002 / RF-006 / RF-010 / H-13 |

Artefactos: `sc/ci-artifacts/test-count.txt` (conteo real, no escrito a mano) y `sc/lcov.info`.
Sin secretos: el pipeline no despliega.

**Estado:** el pipeline **ha corrido en remoto en verde** en la rama `rwa-sc-DSH-GCP`: IDs
`2934202154` y `2934241152`, 7/7 jobs en `success`. El ensayo local equivalente (mismos comandos,
mismo orden) es:

```bash
sc/script/ci/run_local_ci.sh   # validate -> build -> fmt -> test -> coverage -> gas -> ci-checks
```

Detalle de ejecución, umbrales y decisiones en
[`RepoTecnico/entornos_globales.md`](RepoTecnico/entornos_globales.md) §13 y
[`RepoTecnico/metricas_ejecucion.md`](RepoTecnico/metricas_ejecucion.md) §19.

---

## 💰 Gas Optimization

### Ahorro medido (comparación equivalente)

Los tests de gas comparan **clon EIP-1167 + `initialize`** contra un **despliegue
completo no-upgradeable equivalente** (`test/benchmarks/`: `TokenBenchmark`,
`IdentityBenchmark`, `IdentityWithClaimBenchmark` y `ClaimTopicsRegistry`). Son
líneas base de gas, no dobles funcionales. Cifras medidas con `forge test` sobre
`solc 0.8.20` + optimizer 200 runs + `evm_version = "paris"`:

| Contrato | Clon (factory) | Despliegue completo | Ahorro |
|---|---|---|---|
| `TokenCloneable` (`createToken`) | 381.570 | 859.098 | 477.528 (**55 %**) |
| `IdentityCloneable` (`createIdentity`) | 212.307 | 530.753 | 318.446 (**59 %**) |
| `IdentityCloneable` (`createIdentityWithClaim`) | 440.694 | 812.509 | 371.815 (**45 %**) |
| `ClaimTopicsRegistryCloneable` (`createRegistry`) | 210.149 | 451.038 | 240.889 (**53 %**) |

> Las cifras antiguas de este README (90,2 %, 67 %, "3,7M → 365k") nunca estuvieron
> respaldadas por un test y quedan sustituidas por estas. El baseline de gas por test
> está versionado en **`sc/.gas-snapshot`** (RNF-001).

#### Metodología (importante)

`forge` reescribe las expresiones `new Contrato()` de contratos de `src/` como el
cheatcode `vm.deployCode`, que **no consume gas medible** con `gasleft()`. Por eso
los benchmarks se despliegan con el opcode `CREATE` en assembly
(`test/benchmarks/BenchmarkDeployer.sol`), directamente comparable con el `create`
que usa EIP-1167 en `Clones.clone()`.

---

## 🔑 Conceptos Clave

### 1. ERC-3643 Compliance Flow

```solidity
// Verificación en cada transfer
function _update(address from, address to, uint256 amount) {
    // 1. Verificar identidad
    require(isVerified(from) && isVerified(to));
    
    // 2. Verificar compliance
    require(canTransfer(from, to, amount));
    
    // 3. Ejecutar transfer
    super._update(from, to, amount);
    
    // 4. Notificar módulos
    for (cada módulo) {
        módulo.transferred(from, to, amount);
    }
}
```

### 2. Clone Factory Pattern

```solidity
// Factory crea clones ligeros
address clone = implementation.clone();  // ~382K gas (clone + initialize, medido)
TokenCloneable(clone).initialize(...);   // Inicializa clone

// vs deployment tradicional
TokenCloneable token = new TokenCloneable();  // ~859K gas con init equivalente (medido)
```

### 3. Modular Compliance

```solidity
// Token puede gestionar sus módulos
token.addModuleThroughAggregator(aggregator, module);

// Aggregator delega a todos los módulos
for (cada módulo) {
    if (!módulo.canTransfer(...)) return false;
}
```

---

## 📞 Soporte

### ¿Tienes Preguntas?

1. **Revisa la documentación:** Probablemente ya está explicado
2. **Lee los tests:** Muestran cómo usar cada feature
3. **Revisa REFERENCIA_TECNICA.md:** Tiene debugging tips
4. **Busca en el código:** Está bien comentado

### ¿Encontraste un Bug?

1. Verifica que estés en la rama correcta
2. Ejecuta `forge clean && forge build`
3. Revisa que todos los tests pasen: `forge test`

---

## 🎉 ¡Empieza Ahora!

```bash
# Paso 1: Abre la guía principal
open START_HERE.md
# O en tu editor:
code START_HERE.md

# Paso 2: Sigue las instrucciones
# La guía te llevará paso a paso

# Paso 3: ¡Aprende haciendo!
# Implementa, prueba, rompe, arregla, repite
```

---

**¡Feliz aprendizaje! 🚀📚**

*Este proyecto representa 443 tests (443 pasando, 0 fallos) con baseline de gas versionado, miles de líneas de código, y múltiples patrones avanzados de Solidity. Tómate tu tiempo para entenderlo bien.*
