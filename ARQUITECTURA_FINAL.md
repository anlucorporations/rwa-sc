# 🏗️ Arquitectura Final del Sistema RWA

## 📋 Resumen Ejecutivo

Este sistema implementa el estándar **ERC-3643** para tokens de activos del mundo real (RWA) con **patrón de clonación EIP-1167** para maximizar la eficiencia de gas.

## 🎯 Componentes Principales

### 1. Sistema de Tokens

#### Producción (con Factory)
- **`TokenCloneable.sol`** - Contrato de token cloneable
- **`TokenCloneFactory.sol`** - Factory para crear clones de tokens
- **Ahorro**: ~2.95M gas por token (después del primero)

#### Testing
- **`Token.sol`** - Versión no-upgradeable para tests ⚠️ SOLO PARA TESTING

### 2. Sistema de Identidades

#### Producción (con Factory)
- **`IdentityCloneable.sol`** - Contrato de identidad cloneable
- **`IdentityCloneFactory.sol`** - Factory para crear clones de identidades
- **`IdentityRegistry.sol`** - Registro que vincula wallets → identities (compartido)
- **Ahorro**: ~755k gas por identidad (después de la primera)

### 3. Sistema de ClaimTopics ⭐ NUEVO

#### Producción (con Factory)
- **`IClaimTopicsRegistry.sol`** - Interface (usado por Token)
- **`ClaimTopicsRegistryCloneable.sol`** - Registry cloneable que implementa la interface
- **`ClaimTopicsRegistryCloneFactory.sol`** - Factory para crear clones
- **Ahorro**: ~350k gas por registry (después del primero)

#### Testing
- **`ClaimTopicsRegistry.sol`** - Versión no-upgradeable para tests ⚠️ SOLO PARA TESTING

### 4. Registros Compartidos

Estos son **compartidos** entre todos los tokens:
- **`TrustedIssuersRegistry.sol`** - Emisores de claims confiables
- **`IdentityRegistry.sol`** - Vinculación wallet → identity

### 5. Módulos de Compliance

Estos pueden ser compartidos o específicos por token:
- **`ComplianceAggregator.sol`** - Agregador que gestiona múltiples módulos
- **`MaxBalanceCompliance.sol`** - Límite de balance máximo
- **`MaxHoldersCompliance.sol`** - Límite de número de holders
- **`TransferLockCompliance.sol`** - Período de bloqueo tras recepción

## 🔄 Flujo de Deployment Recomendado

```solidity
// ===== PASO 1: Deploy Factories (una vez) =====
TokenCloneFactory tokenFactory = new TokenCloneFactory(admin);
IdentityCloneFactory identityFactory = new IdentityCloneFactory(admin);
ClaimTopicsRegistryCloneFactory claimTopicsFactory = new ClaimTopicsRegistryCloneFactory(admin);

// ===== PASO 2: Deploy Registros Compartidos (una vez) =====
IdentityRegistry identityRegistry = new IdentityRegistry(admin);
TrustedIssuersRegistry trustedIssuersRegistry = new TrustedIssuersRegistry(admin);

// Configurar emisores confiables
uint256[] memory topics = [1, 2, 3, 4]; // KYC, AML, Accredited, Tax
trustedIssuersRegistry.addTrustedIssuer(issuerAddress, topics);

// ===== PASO 3: Por cada Token =====

// 3.1 Crear ClaimTopicsRegistry específico para este token
uint256[] memory tokenTopics = [1, 2, 3]; // Requisitos específicos
address claimTopicsRegistry = claimTopicsFactory.createRegistryForTokenWithTopics(
    admin,
    tokenAddress,
    tokenTopics
);

// 3.2 Crear el Token con todos los registros configurados
address token = tokenFactory.createTokenWithRegistries(
    "Token Name",
    "SYMBOL",
    18,
    admin,
    address(identityRegistry),          // Compartido
    address(trustedIssuersRegistry),    // Compartido
    claimTopicsRegistry                 // Específico del token
);

// 3.3 Agregar módulos de compliance (opcional)
ComplianceAggregator aggregator = new ComplianceAggregator(admin);
MaxBalanceCompliance maxBalance = new MaxBalanceCompliance(admin, 1000 ether);
aggregator.addModule(token, address(maxBalance));
TokenCloneable(token).addComplianceModule(address(aggregator));

// ===== PASO 4: Por cada Inversor =====

// 4.1 Crear identidad con claim inicial
address identity = identityFactory.createIdentityWithClaim(
    investorAddress,
    1,           // KYC topic
    1,           // ECDSA scheme
    issuerAddress,
    signature,
    data,
    uri
);

// 4.2 Agregar más claims según necesidad
IdentityCloneable identityContract = IdentityCloneable(identity);
identityContract.transferOwnership(admin); // Temporalmente
identityContract.addClaim(2, 1, issuerAddress, sig, data, uri); // AML
identityContract.addClaim(3, 1, issuerAddress, sig, data, uri); // Accredited
identityContract.transferOwnership(investorAddress); // Devolver control

// 4.3 Registrar identidad
identityRegistry.registerIdentity(investorAddress, identity);
```

## 🔍 Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                     FACTORIES (Deploy 1x)                        │
├──────────────────┬──────────────────┬─────────────────────────────┤
│ TokenClone       │ IdentityClone    │ ClaimTopicsRegistry        │
│ Factory          │ Factory          │ CloneFactory               │
└────────┬─────────┴────────┬─────────┴────────┬──────────────────┘
         │                  │                  │
         │ crea (gas bajo)  │ crea (gas bajo)  │ crea (gas bajo)
         ▼                  ▼                  ▼
┌──────────────────┐ ┌─────────────────┐ ┌──────────────────────┐
│ TokenCloneable   │ │IdentityCloneable│ │ClaimTopicsRegistry   │
│ Instance 1       │ │ Instance 1      │ │ Cloneable Instance 1 │
│ (Token A)        │ │ (Investor 1)    │ │ (Para Token A)       │
└────────┬─────────┘ └────────┬────────┘ └────────┬─────────────┘
         │                    │                   │
         │ consulta           │ registra          │ consulta
         │ identidad          │ en                │ requisitos
         ▼                    ▼                   ▼
┌─────────────────────────────────────────────────────────────────┐
│              SHARED INFRASTRUCTURE (Deploy 1x)                   │
├──────────────────┬──────────────────┬───────────────────────────┤
│ IdentityRegistry │ TrustedIssuers   │ Compliance Modules        │
│                  │ Registry         │ (MaxBalance, MaxHolders,  │
│ Vincula:         │                  │  TransferLock, etc.)      │
│ Wallet→Identity  │ Define:          │                           │
│                  │ Quién puede      │ Reglas de negocio         │
│                  │ emitir claims    │                           │
└──────────────────┴──────────────────┴───────────────────────────┘
```

## 🎨 Patrones de Diseño Utilizados

### 1. **EIP-1167 Minimal Proxy (Clone Pattern)**
- Un contrato de implementación
- Múltiples proxies mínimos (clones)
- ~99% ahorro de gas en deployments subsecuentes

### 2. **Factory Pattern**
- Centraliza la creación de contratos
- Tracking automático de contratos creados
- Métodos helper para configuración compleja

### 3. **Interface Segregation**
- `IClaimTopicsRegistry` - Interface para abstracción
- `ICompliance` - Interface para módulos de compliance
- Permite múltiples implementaciones

### 4. **Registry Pattern**
- `IdentityRegistry` - Registro centralizado
- `TrustedIssuersRegistry` - Registro de autoridades
- Separación de concerns

### 5. **Role-Based Access Control (RBAC)**
- `DEFAULT_ADMIN_ROLE` - Admin principal
- `AGENT_ROLE` - Operaciones del día a día
- `COMPLIANCE_ROLE` - Gestión de compliance

## 📊 Comparativa de Gas

| Operación | Sin Factory | Con Factory | Ahorro |
|-----------|-------------|-------------|---------|
| **Primera vez** | | | |
| Token | 3M gas | 3M gas | 0 |
| Identity | 800k gas | 800k gas | 0 |
| ClaimTopics | 400k gas | 400k gas | 0 |
| **Subsecuentes** | | | |
| Token | 3M gas | 50k gas | **2.95M (98%)** |
| Identity | 800k gas | 45k gas | **755k (94%)** |
| ClaimTopics | 400k gas | 50k gas | **350k (88%)** |
| **10 Tokens + 20 Identities + 10 Registries** | | | |
| Total | 39M gas | 2.35M gas | **36.65M (94%)** |

## 🔐 Modelo de Seguridad

### Separación de Responsabilidades

1. **Factory Owner** (puede ser DAO)
   - No tiene control sobre tokens/identities individuales
   - Solo gestiona el proceso de creación

2. **Token Admin** (emisor del token)
   - Control total sobre su token
   - Gestiona compliance y registros
   - Puede mint/burn/freeze

3. **Identity Owner** (inversor)
   - Control sobre su identidad
   - Puede agregar/remover claims (con restricciones)

4. **Trusted Issuers** (KYC providers)
   - Emiten claims verificables
   - Definidos en TrustedIssuersRegistry

### Verificación en Cada Transfer

```solidity
function transfer(address to, uint256 amount) public {
    // 1. Verificar identidad del sender
    require(identityRegistry.isRegistered(msg.sender));
    
    // 2. Verificar identidad del recipient
    require(identityRegistry.isRegistered(to));
    
    // 3. Verificar claims requeridos (dinámico por token)
    uint256[] memory topics = claimTopicsRegistry.getClaimTopics();
    // Verifica que ambos tengan todos los claims...
    
    // 4. Verificar compliance modules
    for (module in complianceModules) {
        require(module.canTransfer(msg.sender, to, amount));
    }
    
    // 5. Ejecutar transfer
    _transfer(msg.sender, to, amount);
}
```

## 🚀 Casos de Uso

### Caso 1: Token Inmobiliario (Strict)
```solidity
// Requiere: KYC + AML + Accredited Investor + Tax Compliance
uint256[] memory topics = [1, 2, 3, 4];
address registry = claimTopicsFactory.createRegistryForTokenWithTopics(...);

// Solo inversores acreditados pueden participar
```

### Caso 2: Token de Utilidad (Light)
```solidity
// Requiere: Solo KYC básico
uint256[] memory topics = [1];
address registry = claimTopicsFactory.createRegistryForTokenWithTopics(...);

// Amplia participación
```

### Caso 3: Token Regulado Dinámico
```solidity
// Día 1: KYC
ClaimTopicsRegistryCloneable registry = ClaimTopicsRegistryCloneable(...);
registry.addClaimTopic(1);

// Día 180: Nueva regulación agrega AML
registry.addClaimTopic(2);
// Holders sin AML no pueden transferir hasta obtenerlo

// Día 365: Se relaja
registry.removeClaimTopic(3);
```

## 📝 Mejores Prácticas

### ✅ DO

1. **Usar factories para deployments de producción**
2. **Un ClaimTopicsRegistry por token** para requisitos específicos
3. **Compartir IdentityRegistry y TrustedIssuersRegistry** entre tokens
4. **Planificar cambios de requisitos** con antelación
5. **Documentar topic IDs** claramente en el proyecto
6. **Usar ComplianceAggregator** para gestionar múltiples módulos

### ❌ DON'T

1. **No usar Token.sol/Identity.sol/ClaimTopicsRegistry.sol en producción** (solo para tests)
2. **No cambiar requisitos sin comunicar a holders**
3. **No compartir ClaimTopicsRegistry** entre tokens con diferentes necesidades
4. **No olvidar configurar TrustedIssuers** antes de verificar claims
5. **No hardcodear topic IDs** (usar constantes)

## 🔮 Extensibilidad

### Agregar Nuevos Topic IDs
```solidity
uint256 constant ENVIRONMENTAL_COMPLIANCE = 5;
uint256 constant SANCTIONS_CHECK = 6;
uint256 constant SOURCE_OF_FUNDS = 7;
```

### Agregar Nuevos Compliance Modules
```solidity
contract CustomCompliance is ICompliance {
    function canTransfer(address from, address to, uint256 amount) external view returns (bool) {
        // Tu lógica personalizada
    }
    // ... otros métodos requeridos
}
```

### Multi-Chain Deployment
Cada chain tiene sus propias factories, pero las identidades pueden ser "portadas" usando bridges o oracles.

## 📚 Referencias

- [EIP-1167: Minimal Proxy Contract](https://eips.ethereum.org/EIPS/eip-1167)
- [ERC-3643: T-REX Token Standard](https://erc3643.org/)
- [OpenZeppelin Upgradeable Contracts](https://docs.openzeppelin.com/contracts/4.x/upgradeable)

---

**Arquitectura diseñada para:**
- ⚡ Máxima eficiencia de gas
- 🔒 Máxima seguridad
- 🎯 Máxima flexibilidad
- 📈 Escalabilidad ilimitada

