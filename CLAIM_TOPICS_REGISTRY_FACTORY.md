# ClaimTopicsRegistry Clone Factory

## 🎯 Problema Resuelto

Cada token RWA necesita su propio `ClaimTopicsRegistry` con requisitos específicos de compliance. Desplegar múltiples contratos completos es costoso en gas.

## 💡 Solución: Patrón de Clonación EIP-1167

Usando el mismo patrón de las otras factories del proyecto:
- **Un contrato de implementación** (`ClaimTopicsRegistryCloneable`)
- **Múltiples clones baratos** creados por la factory
- **Ahorro de ~350k gas por registry**

## 📦 Componentes

### 1. `ClaimTopicsRegistryCloneable.sol`
Versión cloneable del registry con patrón `Initializable`:
```solidity
contract ClaimTopicsRegistryCloneable is OwnableUpgradeable {
    function initialize(address initialOwner) external initializer;
    function addClaimTopic(uint256 _claimTopic) external onlyOwner;
    function removeClaimTopic(uint256 _claimTopic) external onlyOwner;
    function getClaimTopics() external view returns (uint256[] memory);
}
```

### 2. `ClaimTopicsRegistryCloneFactory.sol`
Factory para crear clones eficientemente:
```solidity
contract ClaimTopicsRegistryCloneFactory is Ownable {
    // Crear registry básico
    function createRegistry(address owner) external returns (address);
    
    // Crear registry para un token específico
    function createRegistryForToken(address owner, address token) external returns (address);
    
    // Crear registry con topics iniciales
    function createRegistryWithTopics(address owner, uint256[] memory topics) external returns (address);
    
    // Crear registry para token con topics
    function createRegistryForTokenWithTopics(
        address owner, 
        address token, 
        uint256[] memory topics
    ) external returns (address);
}
```

## 🚀 Casos de Uso

### Caso 1: Tokens con Diferentes Requisitos

```solidity
// Deploy la factory
ClaimTopicsRegistryCloneFactory factory = new ClaimTopicsRegistryCloneFactory(admin);

// Token de Real Estate (muy regulado)
uint256[] memory strictTopics = new uint256[](4);
strictTopics[0] = 1; // KYC
strictTopics[1] = 2; // AML
strictTopics[2] = 3; // Accredited Investor
strictTopics[3] = 4; // Tax Compliance

address realEstateRegistry = factory.createRegistryForTokenWithTopics(
    admin,
    realEstateTokenAddress,
    strictTopics
);

// Token de Utilidad (menos regulado)
uint256[] memory lightTopics = new uint256[](1);
lightTopics[0] = 1; // Solo KYC

address utilityRegistry = factory.createRegistryForTokenWithTopics(
    admin,
    utilityTokenAddress,
    lightTopics
);

// Configurar los tokens
realEstateToken.setClaimTopicsRegistry(realEstateRegistry);
utilityToken.setClaimTopicsRegistry(utilityRegistry);
```

**Resultado:**
- Real Estate Token requiere: KYC + AML + Accredited + Tax
- Utility Token requiere: Solo KYC
- Mismos inversores, diferentes niveles de acceso
- Ahorro de ~350k gas por registry vs deployment completo

### Caso 2: Requisitos Dinámicos en el Tiempo

```solidity
// Día 1: Lanzamiento con requisitos básicos
address registry = factory.createRegistryForToken(admin, tokenAddress);
ClaimTopicsRegistryCloneable registryContract = ClaimTopicsRegistryCloneable(registry);

registryContract.addClaimTopic(1); // KYC
token.setClaimTopicsRegistry(registry);

// Día 180: Nueva regulación
registryContract.addClaimTopic(2); // AML ahora requerido
// Efecto inmediato: holders sin AML no pueden transferir

// Día 365: Se relajan requisitos
registryContract.removeClaimTopic(3); // Ya no se requiere algo específico
// Efecto inmediato: más personas pueden participar
```

### Caso 3: Deployment Completo de Ecosystem

```solidity
// 1. Deploy todas las factories
TokenCloneFactory tokenFactory = new TokenCloneFactory(admin);
IdentityCloneFactory identityFactory = new IdentityCloneFactory(admin);
ClaimTopicsRegistryCloneFactory claimFactory = new ClaimTopicsRegistryCloneFactory(admin);

// 2. Crear múltiples tokens con sus propios requisitos
for (uint i = 0; i < 10; i++) {
    // Cada token tiene su registry específico
    uint256[] memory topics = getTopicsForToken(i);
    address registry = claimFactory.createRegistryWithTopics(admin, topics);
    
    address token = tokenFactory.createToken(...);
    token.setClaimTopicsRegistry(registry);
}

// Ahorro total: 10 registries × ~350k gas = ~3.5M gas
```

## 📊 Arquitectura Completa

```
┌─────────────────────────────────────────────────────────┐
│                    RWA Token System                      │
└─────────────────────────────────────────────────────────┘

┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  TokenCloneFactory│  │IdentityClone     │  │ClaimTopicsRegistry│
│                  │  │Factory           │  │CloneFactory      │
└────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
         │                     │                     │
         │ crea                │ crea                │ crea
         ▼                     ▼                     ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│ TokenCloneable   │  │IdentityCloneable │  │ClaimTopicsRegistry│
│ (Token A)        │  │ (Investor 1)     │  │Cloneable (A)     │
└────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘
         │                     │                     │
         │ usa                 │ registra            │ consulta
         ▼                     ▼                     ▼
┌─────────────────────────────────────────────────────────┐
│              Shared Infrastructure                       │
├──────────────────┬──────────────────┬───────────────────┤
│ IdentityRegistry │ TrustedIssuers   │ ComplianceModules │
│                  │ Registry         │                   │
└──────────────────┴──────────────────┴───────────────────┘
```

## ✨ Ventajas del Sistema

### 1. **Flexibilidad por Token**
- Cada token define sus propios requisitos
- Los requisitos pueden cambiar dinámicamente
- No afecta a otros tokens del ecosistema

### 2. **Eficiencia de Gas**
```
Deployment Tradicional:
- Token: ~3M gas
- Identity: ~800k gas  
- ClaimTopics: ~400k gas
Total: ~4.2M gas

Con Factories (después del primer deployment):
- Token Clone: ~50k gas
- Identity Clone: ~45k gas
- ClaimTopics Clone: ~50k gas
Total: ~145k gas

Ahorro: ~4M gas (96.5% menos!)
```

### 3. **Reutilización de Infraestructura**
- IdentityRegistry compartido (un inversor, múltiples tokens)
- TrustedIssuersRegistry compartido (emisores confiables globales)
- ComplianceModules compartidos

### 4. **Compliance Adaptativo**
```solidity
// Nueva regulación: agregar requisito
registry.addClaimTopic(5); // Environmental compliance

// Período de gracia: comunicar a holders
// Después de X días, quien no tenga el claim no puede transferir

// Crisis: suspender temporalmente
registry.removeClaimTopic(4);
// ... resolver situación ...
registry.addClaimTopic(4); // Restaurar
```

## 🧪 Tests Incluidos

- ✅ Creación de registries básicos
- ✅ Creación con topics iniciales
- ✅ Vinculación a tokens específicos
- ✅ Modificación dinámica de topics
- ✅ Múltiples registries para diferentes tokens
- ✅ Verificación de ahorro de gas
- ✅ Simulación de evolución temporal

Ejecutar tests:
```bash
forge test --match-contract ClaimTopicsRegistryCloneFactoryTest -vv
```

## 📝 Ejemplo Completo

Ver `script/CompleteDeploymentExample.s.sol` para un ejemplo completo que incluye:
- Deployment de todas las factories
- Creación de tokens con diferentes requisitos
- Configuración de identidades
- Flujo completo de compliance

## 🎓 Conceptos Clave

### Topic IDs (ejemplos comunes)
```solidity
uint256 constant KYC = 1;                    // Know Your Customer
uint256 constant AML = 2;                    // Anti Money Laundering
uint256 constant ACCREDITED_INVESTOR = 3;    // Investor acreditado
uint256 constant TAX_COMPLIANCE = 4;         // Cumplimiento fiscal
uint256 constant ENVIRONMENTAL = 5;          // Compliance ambiental
uint256 constant US_RESIDENT = 6;            // Residencia US
uint256 constant EU_RESIDENT = 7;            // Residencia EU
```

### Cambios Dinámicos
Los cambios se aplican **inmediatamente** en la siguiente transferencia:
- No requiere redeployment del token
- No afecta balances existentes
- Solo impacta la capacidad de transferir

### Gestión de Múltiples Tokens
```solidity
// Consultar registry de un token
address registry = factory.getRegistryForToken(tokenAddress);

// Ver todos los registries creados
address[] memory registries = factory.getRegistriesByOwner(admin);

// Total de registries
uint256 total = factory.getTotalRegistries();
```

## 🚀 Próximos Pasos

1. Deploy la factory en tu red
2. Crea registries para cada tipo de token
3. Configura los topics iniciales
4. Vincula los registries a los tokens
5. Monitorea y ajusta requisitos según regulaciones

## 📚 Referencias

- **EIP-1167**: Minimal Proxy Contract (Clone Pattern)
- **ERC-3643**: T-REX Token Standard
- **OpenZeppelin Upgradeable**: Contratos base para clones

---

**Gas Total Ahorrado en un Ecosystem con 10 Tokens:**
- Tokens: 10 × 2.95M = 29.5M gas
- Identities: 20 × 755k = 15.1M gas (2 inversores × 10 identities)
- Registries: 10 × 350k = 3.5M gas

**Total: ~48M gas ahorrado** 💰

