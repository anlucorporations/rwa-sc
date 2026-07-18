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

Este proyecto implementa un **sistema completo de tokenización RWA** con:

- ✅ **ERC-3643** (T-REX) standard para security tokens
- ✅ **Clone Factory** (EIP-1167) - 90% ahorro de gas
- ✅ **Compliance Aggregator** - Gestión modular de compliance
- ✅ **139 tests** pasando (100%)
- ✅ **Gas optimizado** y production-ready

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
- `Token.sol` - Token ERC-3643 original
- `TokenCloneable.sol` - Versión cloneable (90% menos gas)
- `TokenCloneFactory.sol` - Factory para crear tokens

**Key Features:**
- Identity verification obligatoria
- Compliance checks en cada transfer
- Role-based access control
- Pausability
- Freeze accounts

### 2. Identity System

**Contracts:**
- `Identity.sol` - Identity básica (para testing)
- `IdentityCloneable.sol` - Versión cloneable
- `IdentityCloneFactory.sol` - Factory para identities
- `IdentityRegistry.sol` - Registro de identities
- `TrustedIssuersRegistry.sol` - Emisores autorizados
- `ClaimTopicsRegistry.sol` - Claims requeridos

**Key Features:**
- Claims on-chain
- Trusted issuers
- Configurable claim requirements

### 3. Compliance System

**Contracts:**
- `ComplianceAggregator.sol` - Aggregador modular
- `MaxBalanceCompliance.sol` - Límite de saldo
- `MaxHoldersCompliance.sol` - Límite de holders
- `TransferLockCompliance.sol` - Período de bloqueo

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
  - Token.sol                    (Token ERC-3643 original)
  - TokenCloneable.sol           (Versión cloneable)
  - TokenCloneFactory.sol        (Factory de tokens)

Identity:
  - Identity.sol                 (Identity básica)
  - IdentityCloneable.sol        (Versión cloneable)
  - IdentityCloneFactory.sol     (Factory de identities)
  - IdentityRegistry.sol         (Registro)
  - TrustedIssuersRegistry.sol   (Emisores)
  - ClaimTopicsRegistry.sol      (Topics requeridos)

Compliance:
  - compliance/
    ├─ ComplianceAggregator.sol       (Aggregador modular)
    ├─ MaxBalanceCompliance.sol       (Límite de balance)
    ├─ MaxHoldersCompliance.sol       (Límite de holders)
    └─ TransferLockCompliance.sol     (Lock period)
  - ICompliance.sol              (Interface)
```

### Scripts (`script/`)

```
- DeployTokenCloneFactory.s.sol        (Deploy token factory)
- DeployIdentityCloneFactory.s.sol     (Deploy identity factory)
- DeployComplianceAggregator.s.sol     (Deploy aggregator)
- CreateTokenWithCloneFactory.s.sol    (Crear token)
```

### Tests (`test/`)

```
- Token.t.sol                          (30 tests)
- TokenCloneFactory.t.sol              (13 tests)
- IdentityCloneFactory.t.sol           (12 tests)
- ComplianceAggregator.t.sol           (25 tests)
- MaxBalanceCompliance.t.sol           (15 tests)
- MaxHoldersCompliance.t.sol           (22 tests)
- TransferLockCompliance.t.sol         (22 tests)

Total: 139 tests (100% passing)
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

### Compilar y Testear

```bash
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
| **TOKEN_CLONE_FACTORY.md** | Clone Factory pattern explicado |
| **COMPLIANCE_AGGREGATOR_FINAL.md** | Aggregator arquitectura y uso |
| **COMPLIANCE_AGGREGATOR_V2.md** | Arquitectura modular detallada |

### Para Project Managers (Ejecutivo)

| Documento | Descripción |
|-----------|-------------|
| **../RESUMEN_EJECUTIVO_FINAL.md** | Resumen de toda la implementación |
| **../SESSION_FINAL_SUMMARY.md** | Resumen de la sesión |
| **../CLEANUP_REPORT.md** | Archivos eliminados/mantenidos |

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
| TokenTest | 30 | Token principal |
| TokenCloneFactoryTest | 13 | Token factory |
| ComplianceAggregatorTest | 25 | Compliance aggregator |
| IdentityCloneFactoryTest | 12 | Identity factory |
| MaxBalanceComplianceTest | 15 | Max balance module |
| MaxHoldersComplianceTest | 22 | Max holders module |
| TransferLockComplianceTest | 22 | Transfer lock module |

**Total: 139 tests (100% passing)**

---

## 💰 Gas Optimization

### Ahorro Medido

**Token Deployment:**
```
Direct deployment:  3,736,079 gas
Clone via factory:    364,903 gas
SAVINGS:           3,371,176 gas (90.2%)
```

**Compliance (3 tokens):**
```
Separate modules:  ~2,700,000 gas
ComplianceAggregator: ~900,000 gas
SAVINGS:           ~1,800,000 gas (67%)
```

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
address clone = implementation.clone();  // ~365K gas
TokenCloneable(clone).initialize(...);   // Inicializa clone

// vs deployment tradicional
Token token = new Token(...);  // ~3.7M gas
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

*Este proyecto representa 139 tests, miles de líneas de código, y múltiples patrones avanzados de Solidity. Tómate tu tiempo para entenderlo bien.*
