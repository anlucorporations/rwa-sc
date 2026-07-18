# 🔧 Referencia Técnica Rápida - RWA Smart Contracts

## 📖 Guía de Referencia para Implementación

Este documento es una **referencia rápida** con toda la información técnica necesaria para implementar contratos similares.

---

## 🏗️ Estructura de Contratos

### Patrón: Token ERC-3643

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract Token is ERC20, AccessControl, Pausable {
    // 1. ROLES
    bytes32 public constant AGENT_ROLE = keccak256("AGENT_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    
    // 2. REGISTRIES
    IdentityRegistry public identityRegistry;
    TrustedIssuersRegistry public trustedIssuersRegistry;
    ClaimTopicsRegistry public claimTopicsRegistry;
    
    // 3. COMPLIANCE
    ICompliance[] public complianceModules;
    
    // 4. STATE
    mapping(address => bool) private frozen;
    bool private bypassCompliance;
    
    // 5. CONSTRUCTOR
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address admin
    ) ERC20(name_, symbol_) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(AGENT_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);
    }
    
    // 6. VERIFICATION
    function isVerified(address account) public view returns (bool) {
        // Verifica registro, identity y claims
    }
    
    // 7. COMPLIANCE
    function canTransfer(address from, address to, uint256 amount) 
        public view returns (bool) 
    {
        // Verifica paused, frozen, verified, compliance
    }
    
    // 8. OVERRIDE _update
    function _update(address from, address to, uint256 amount) 
        internal virtual override 
    {
        // Verifica compliance antes de transferir
        if (from != address(0) && to != address(0) && !bypassCompliance) {
            require(canTransfer(from, to, amount), "Transfer not compliant");
        }
        super._update(from, to, amount);
        // Notifica módulos después de transferir
    }
}
```

---

## 🔄 Patrón: Clone Factory (EIP-1167)

### Implementation Contract (Cloneable)

```solidity
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TokenCloneable is ERC20Upgradeable, AccessControlUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers(); // Previene inicialización del implementation
    }
    
    function initialize(
        string memory name,
        string memory symbol,
        uint8 decimals,
        address admin
    ) external initializer {
        __ERC20_init(name, symbol);
        __AccessControl_init();
        
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        // ... configuración inicial
    }
    
    // ... resto del código igual que Token normal
}
```

**Diferencias clave:**
- ✅ Hereda de contratos `Upgradeable` (ERC20Upgradeable, etc.)
- ✅ Constructor vacío con `_disableInitializers()`
- ✅ Función `initialize()` con modifier `initializer`
- ✅ Usa `__ContractName_init()` en initialize

### Factory Contract

```solidity
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TokenCloneFactory is Ownable {
    using Clones for address;
    
    address public immutable implementation;
    address[] public allTokens;
    mapping(address => address[]) public adminTokens;
    
    constructor(address initialOwner) Ownable(initialOwner) {
        implementation = address(new TokenCloneable());
    }
    
    function createToken(...) external returns (address token) {
        // 1. Clone
        token = implementation.clone();
        
        // 2. Initialize
        TokenCloneable(token).initialize(...);
        
        // 3. Track
        allTokens.push(token);
        adminTokens[admin].push(token);
        
        return token;
    }
}
```

**Conceptos clave:**
- `implementation` es immutable (se crea en constructor)
- `clone()` crea minimal proxy de 45 bytes
- `initialize()` se llama después de clonar
- Tracking de tokens creados

---

## 🎯 Patrón: Compliance Aggregator

### Aggregator Contract

```solidity
contract ComplianceAggregator is ICompliance, Ownable {
    // Módulos por token
    mapping(address => ICompliance[]) private tokenModules;
    
    // Tracking
    mapping(address => mapping(address => bool)) private isModuleActive;
    address[] private tokens;
    
    // Gestión dual
    modifier onlyOwnerOrToken(address token) {
        require(
            msg.sender == owner() || msg.sender == token,
            "Only owner or token can call"
        );
        _;
    }
    
    // Añadir módulo (owner o token)
    function addModule(address token, address module) 
        external onlyOwnerOrToken(token) 
    {
        tokenModules[token].push(ICompliance(module));
        isModuleActive[token][module] = true;
    }
    
    // Verificación (delega a TODOS)
    function canTransfer(address from, address to, uint256 amount) 
        external view override returns (bool) 
    {
        address token = msg.sender;
        
        for (uint256 i = 0; i < tokenModules[token].length; i++) {
            if (!tokenModules[token][i].canTransfer(from, to, amount)) {
                return false;
            }
        }
        return true;
    }
    
    // Callbacks (notifica a TODOS)
    function transferred(address from, address to, uint256 amount) 
        external override 
    {
        address token = msg.sender;
        
        for (uint256 i = 0; i < tokenModules[token].length; i++) {
            tokenModules[token][i].transferred(from, to, amount);
        }
    }
}
```

### Token Integration

```solidity
contract Token {
    // Importar aggregator
    import {ComplianceAggregator} from "./compliance/ComplianceAggregator.sol";
    
    // Métodos de gestión
    function addModuleThroughAggregator(address aggregator, address module) 
        external onlyRole(COMPLIANCE_ROLE) 
    {
        // 1. Verificar que aggregator esté añadido
        require(isAggregatorAdded(aggregator), "Aggregator not added");
        
        // 2. Llamar al aggregator
        ComplianceAggregator(aggregator).addModule(address(this), module);
    }
    
    function removeModuleThroughAggregator(address aggregator, address module) 
        external onlyRole(COMPLIANCE_ROLE) 
    {
        ComplianceAggregator(aggregator).removeModule(address(this), module);
    }
    
    // Helpers
    function isAggregatorAdded(address aggregator) private view returns (bool) {
        for (uint256 i = 0; i < complianceModules.length; i++) {
            if (address(complianceModules[i]) == aggregator) return true;
        }
        return false;
    }
}
```

---

## 🔐 Authorized Callers Pattern

### Para Módulos con State

```solidity
contract MaxHoldersCompliance is ICompliance, Ownable {
    address public tokenContract;
    mapping(address => bool) public authorizedCallers;
    
    modifier onlyTokenOrAuthorized() {
        require(
            msg.sender == tokenContract || authorizedCallers[msg.sender],
            "Only token contract or authorized caller"
        );
        _;
    }
    
    function addAuthorizedCaller(address caller) external onlyOwner {
        authorizedCallers[caller] = true;
    }
    
    function transferred(...) external override onlyTokenOrAuthorized {
        // Puede ser llamado por token O por aggregator (si autorizado)
    }
}
```

**Cuándo usar:**
- ✅ Módulos que mantienen state (MaxHolders, TransferLock)
- ❌ Módulos stateless (MaxBalance)

**Setup:**
```solidity
// Autorizar aggregator a llamar al módulo
module.addAuthorizedCaller(address(aggregator));
```

---

## 📊 Deployment Patterns

### Pattern 1: Todo desde Owner

```solidity
// 1. Deploy factories
TokenCloneFactory tokenFactory = new TokenCloneFactory(owner);
ComplianceAggregator aggregator = new ComplianceAggregator(owner);

// 2. Deploy módulos compartidos
MaxBalanceCompliance maxBal = new MaxBalanceCompliance(owner, 1000 ether);

// 3. Para cada token
address token = tokenFactory.createToken("Token", "TKN", 18, admin);

// 4. Configurar módulos
maxBal.setTokenContract(token);
aggregator.addModule(token, address(maxBal));

// 5. Token usa aggregator
Token(token).addComplianceModule(address(aggregator));
```

### Pattern 2: Token Self-Configure

```solidity
// 1. Token admin crea token
address token = tokenFactory.createToken("Token", "TKN", 18, tokenAdmin);

// 2. Token añade aggregator
Token(token).addComplianceModule(aggregatorAddress);

// 3. Token admin deploya sus módulos
MaxBalanceCompliance myMaxBal = new MaxBalanceCompliance(tokenAdmin, 500 ether);
myMaxBal.setTokenContract(token);

// 4. Token añade módulos
Token(token).addModuleThroughAggregator(aggregatorAddress, address(myMaxBal));
```

---

## 🧪 Testing Patterns

### Setup Completo

```solidity
contract MyTest is Test {
    // Contratos
    Token public token;
    ComplianceAggregator public aggregator;
    IdentityRegistry public identityRegistry;
    
    // Usuarios
    address public owner;
    address public user1;
    address public user2;
    
    function setUp() public {
        // 1. Crear addresses
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // 2. Deploy registries
        vm.startPrank(owner);
        identityRegistry = new IdentityRegistry(owner);
        // ...
        vm.stopPrank();
        
        // 3. Deploy token
        vm.prank(owner);
        token = new Token("Test", "TST", 18, owner);
        
        // 4. Setup identities
        _setupIdentity(user1);
        _setupIdentity(user2);
        
        // 5. Configure token
        vm.startPrank(owner);
        token.setIdentityRegistry(address(identityRegistry));
        // ...
        vm.stopPrank();
    }
    
    function _setupIdentity(address user) internal {
        // Deploy identity
        // Add claims
        // Register in registry
    }
}
```

### Assertions Útiles

```solidity
// Igualdad
assertEq(a, b);
assertEq(a, b, "Error message");

// Booleanos
assertTrue(condition);
assertFalse(condition);

// Comparaciones
assertGt(a, b);  // a > b
assertLt(a, b);  // a < b
assertGe(a, b);  // a >= b
assertLe(a, b);  // a <= b

// Aproximado (útil para timestamps)
assertApproxEqAbs(a, b, maxDelta);

// Expect revert
vm.expectRevert("Error message");
vm.expectRevert(CustomError.selector);
```

### Cheat Codes Útiles

```solidity
// Cambiar msg.sender
vm.prank(user);           // Solo próxima llamada
vm.startPrank(user);      // Todas las llamadas hasta stopPrank
vm.stopPrank();

// Tiempo
vm.warp(timestamp);       // Cambiar block.timestamp
vm.roll(blockNumber);     // Cambiar block.number

// Balances
vm.deal(user, 10 ether);  // Dar ETH a user

// Expect
vm.expectEmit(true, true, false, true);
emit Event(param1, param2);
// ... acción que emite el evento

vm.expectRevert("Error");
// ... acción que debe revertir
```

---

## 📋 Checklists de Implementación

### Checklist: Módulo de Compliance

```
[ ] Hereda de ICompliance
[ ] Hereda de Ownable (para configuración)
[ ] Define state variables necesarias
[ ] Implementa constructor con parámetros iniciales
[ ] Implementa setTokenContract()
[ ] Implementa canTransfer() (view, lógica de verificación)
[ ] Implementa transferred() (actualiza state si necesario)
[ ] Implementa created() (actualiza state si necesario)
[ ] Implementa destroyed() (actualiza state si necesario)
[ ] Añade eventos apropiados
[ ] Añade funciones de configuración
[ ] Añade view functions para queries
[ ] Si mantiene state: añade authorizedCallers
[ ] Escribe tests (mínimo 10)
[ ] Documenta el código
```

### Checklist: Token Cloneable

```
[ ] Hereda de contratos Upgradeable (ERC20Upgradeable, etc.)
[ ] Constructor vacío con _disableInitializers()
[ ] Función initialize() con modifier initializer
[ ] Usa __ContractName_init() en initialize
[ ] Mismo comportamiento que versión normal
[ ] Tests de clonabilidad
[ ] Tests de no re-inicialización
```

### Checklist: Factory

```
[ ] Hereda de Ownable
[ ] Variable immutable para implementation
[ ] Constructor deploya implementation
[ ] Función createX() que:
    - Clona implementation
    - Inicializa clone
    - Trackea clone creado
    - Emite evento
[ ] Funciones de query (getAll, getByOwner, etc.)
[ ] Tests de deployment
[ ] Tests de creación
[ ] Tests de independencia de clones
[ ] Tests de gas savings
```

---

## 🔑 Snippets Útiles

### Access Control Setup

```solidity
// Definir roles
bytes32 public constant MY_ROLE = keccak256("MY_ROLE");

// En constructor
_grantRole(DEFAULT_ADMIN_ROLE, admin);
_grantRole(MY_ROLE, admin);

// Usar en funciones
function myFunction() external onlyRole(MY_ROLE) {
    // Solo usuarios con MY_ROLE pueden llamar
}

// Gestión de roles
function grantMyRole(address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
    grantRole(MY_ROLE, account);
}
```

### Pausability

```solidity
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract MyContract is Pausable {
    function pause() external onlyAdmin {
        _pause();
    }
    
    function unpause() external onlyAdmin {
        _unpause();
    }
    
    function myFunction() external whenNotPaused {
        // Solo funciona si no está pausado
    }
}
```

### Events y Logging

```solidity
// Definir evento
event Transfer(
    address indexed from,
    address indexed to,
    uint256 value
);

// Emitir evento
emit Transfer(from, to, amount);

// En tests: verificar eventos
vm.expectEmit(true, true, false, true);
emit Transfer(user1, user2, 100);
token.transfer(user2, 100);
```

### Safe Math (ya incluido en Solidity 0.8+)

```solidity
// Solidity 0.8+ tiene overflow/underflow protection automático
uint256 a = 5;
uint256 b = 10;
uint256 c = a - b;  // Revierte con panic (no underflow silencioso)

// Si quieres permitir wrapping:
unchecked {
    c = a - b;  // Permite wrapping, usa con cuidado
}
```

### Interacción entre Contratos

```solidity
// Opción 1: Import y type-safe
import {OtherContract} from "./OtherContract.sol";
OtherContract other = OtherContract(otherAddress);
uint256 value = other.getValue();

// Opción 2: Interface
interface IOther {
    function getValue() external view returns (uint256);
}
IOther other = IOther(otherAddress);
uint256 value = other.getValue();

// Opción 3: Low-level call (para verificar success)
(bool success, bytes memory data) = address.call(
    abi.encodeWithSignature("getValue()")
);
if (success) {
    uint256 value = abi.decode(data, (uint256));
}

// Opción 4: Static call (para view functions)
(bool success, bytes memory data) = address.staticcall(
    abi.encodeWithSignature("balanceOf(address)", user)
);
```

---

## 📊 Gas Optimization Techniques

### 1. Storage Packing

```solidity
// ❌ Malo: 3 storage slots
uint256 a;  // slot 0
uint256 b;  // slot 1
uint256 c;  // slot 2

// ✅ Bueno: 1 storage slot (si valores son pequeños)
uint128 a;  // slot 0 (primeros 128 bits)
uint128 b;  // slot 0 (últimos 128 bits)
uint256 c;  // slot 1
```

### 2. Caching

```solidity
// ❌ Malo: Lee storage en cada iteración
for (uint256 i = 0; i < array.length; i++) {
    // array.length se lee en cada iteración
}

// ✅ Bueno: Cachea length
uint256 length = array.length;
for (uint256 i = 0; i < length; i++) {
    // Solo una lectura de storage
}
```

### 3. Immutable y Constant

```solidity
// Constant: Valor conocido en compile-time
uint256 public constant MAX_SUPPLY = 1_000_000 ether;

// Immutable: Valor conocido en deploy-time
address public immutable implementation;

constructor() {
    implementation = address(new Implementation());
}

// Ambos ahorran gas vs storage variables
```

### 4. Short-circuit Evaluation

```solidity
// ✅ Bueno: Condiciones baratas primero
if (simpleCheck && expensiveCheck()) {
    // simpleCheck se evalúa primero (barato)
    // expensiveCheck() solo si simpleCheck es true
}

// ❌ Malo: Condición cara primero
if (expensiveCheck() && simpleCheck) {
    // expensiveCheck() siempre se ejecuta
}
```

### 5. Custom Errors

```solidity
// ❌ Malo: String errors (caros)
require(value > 0, "Value must be greater than zero");

// ✅ Bueno: Custom errors (más baratos)
error ValueMustBePositive();

if (value == 0) revert ValueMustBePositive();
```

---

## 🔒 Security Checklist

### General

```
[ ] Todos los external/public functions tienen access control apropiado
[ ] No hay integer overflow/underflow (usa Solidity 0.8+)
[ ] Validas parámetros de input (address(0), amounts, etc.)
[ ] Emites eventos para acciones importantes
[ ] Usas checks-effects-interactions pattern
[ ] No hay re-entrancy vulnerabilities
```

### Access Control

```
[ ] Roles bien definidos y documentados
[ ] DEFAULT_ADMIN_ROLE protegido
[ ] Funciones críticas solo para roles apropiados
[ ] No hay funciones admin sin protección
```

### Compliance

```
[ ] canTransfer se ejecuta ANTES de _update
[ ] transferred se ejecuta DESPUÉS de _update
[ ] Bypass compliance solo en casos específicos (forcedTransfer)
[ ] Módulos no tienen dependencias circulares
```

### Clone Factory

```
[ ] Implementation tiene _disableInitializers()
[ ] Initialize tiene modifier initializer
[ ] Initialize valida todos los parámetros
[ ] Factory trackea todos los clones
[ ] Implementation address es immutable
```

---

## 📚 Referencias de Interfaces

### ICompliance

```solidity
interface ICompliance {
    function canTransfer(address from, address to, uint256 amount) 
        external view returns (bool);
        
    function transferred(address from, address to, uint256 amount) 
        external;
        
    function created(address to, uint256 amount) 
        external;
        
    function destroyed(address from, uint256 amount) 
        external;
}
```

### IERC20 (Métodos principales)

```solidity
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
```

---

## 🎯 Comandos de Foundry

### Build

```bash
forge build                    # Compilar
forge build --force            # Forzar recompilación
forge clean                    # Limpiar artifacts
```

### Test

```bash
forge test                                      # Todos los tests
forge test --match-test test_Name              # Test específico
forge test --match-contract ContractTest       # Suite específica
forge test -vvvv                               # Máximo verbose
forge test --gas-report                        # Reporte de gas
forge test --gas-report --json > gas.json     # Gas en JSON
forge coverage                                 # Coverage
forge coverage --report lcov                   # Coverage en lcov
```

### Deploy

```bash
# Local (Anvil)
forge script script/Deploy.s.sol --rpc-url localhost --broadcast

# Testnet
forge script script/Deploy.s.sol \
  --rpc-url $SEPOLIA_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_KEY

# Verificar contrato después
forge verify-contract \
  --chain sepolia \
  --compiler-version v0.8.20 \
  CONTRACT_ADDRESS \
  src/Token.sol:Token \
  --etherscan-api-key $ETHERSCAN_KEY
```

### Cast (Interacción)

```bash
# Llamadas view
cast call CONTRACT_ADDRESS "name()" --rpc-url localhost
cast call CONTRACT_ADDRESS "balanceOf(address)" USER_ADDRESS --rpc-url localhost

# Transacciones
cast send CONTRACT_ADDRESS \
  "transfer(address,uint256)" \
  TO_ADDRESS \
  1000000000000000000 \
  --rpc-url localhost \
  --private-key $PRIVATE_KEY

# Obtener datos
cast block latest --rpc-url localhost
cast balance ADDRESS --rpc-url localhost
cast code ADDRESS --rpc-url localhost
```

---

## 💾 Datos de Referencia

### Claim Topics Estándar

```
1  = KYC (Know Your Customer)
2  = AML (Anti-Money Laundering)
3  = Accredited Investor
4  = Country
5  = Identity Verification
6  = Tax Status
7  = Investor Type
8  = Risk Assessment
9  = Sanctions Check
10 = Politically Exposed Person (PEP)
```

### Signature Schemes

```
1 = ECDSA (Elliptic Curve Digital Signature Algorithm)
2 = RSA
```

### Time Constants

```solidity
uint256 constant MINUTE = 60;
uint256 constant HOUR = 60 * MINUTE;
uint256 constant DAY = 24 * HOUR;
uint256 constant WEEK = 7 * DAY;
uint256 constant MONTH = 30 * DAY;
uint256 constant YEAR = 365 * DAY;

// Uso
uint256 lockPeriod = 30 * DAY;
uint256 vestingDuration = 2 * YEAR;
```

### Addresses de Prueba (Anvil)

```
Cuenta 0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
Cuenta 1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8
Cuenta 2: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC

Private Key 0: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

---

## 🎨 Patrones de Código

### Loop sobre Array

```solidity
// Pattern básico
for (uint256 i = 0; i < array.length; i++) {
    // Procesar array[i]
}

// Pattern optimizado
uint256 length = array.length;
for (uint256 i = 0; i < length; ) {
    // Procesar array[i]
    unchecked { ++i; }  // Ahorra gas
}
```

### Verificar Interface

```solidity
// Usando supportsInterface (ERC-165)
bool isCompliant = IERC165(contract).supportsInterface(
    type(ICompliance).interfaceId
);

// Usando try/catch
try ICompliance(contract).canTransfer(a, b, c) returns (bool result) {
    // Es ICompliance
} catch {
    // No es ICompliance
}
```

### Remove from Array

```solidity
// Eliminar elemento (swap con último y pop)
function remove(uint256 index) internal {
    require(index < array.length, "Index out of bounds");
    
    array[index] = array[array.length - 1];
    array.pop();
}

// Mantener mapping para O(1) lookup
mapping(address => uint256) private indexOf;
```

---

## 🔍 Debugging Patterns

### Console Logging

```solidity
import {console} from "forge-std/Test.sol";

// En tests o scripts
console.log("Value:", value);
console.log("Address:", address);
console.log("Bool:", boolValue);
console.log("Multiple:", value1, value2);
```

### Require con Mensajes Descriptivos

```solidity
// ❌ Malo
require(value > 0);

// ✅ Bueno
require(value > 0, "Value must be positive");

// ✅ Mejor
require(value > 0, "Value must be positive");
require(value < maxValue, "Value exceeds maximum");

// 🚀 Excelente (custom errors)
error ValueMustBePositive(uint256 provided);
error ValueExceedsMaximum(uint256 provided, uint256 maximum);

if (value == 0) revert ValueMustBePositive(value);
if (value > maxValue) revert ValueExceedsMaximum(value, maxValue);
```

---

## 📖 Ejemplo Completo: Módulo Simple

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ICompliance} from "../ICompliance.sol";

/**
 * @title MinimumHoldingPeriodCompliance
 * @dev Requires users to hold tokens for minimum period before selling
 */
contract MinimumHoldingPeriodCompliance is ICompliance, Ownable {
    uint256 public holdingPeriod;
    address public tokenContract;
    
    mapping(address => uint256) private firstReceiveTime;
    
    event HoldingPeriodSet(uint256 period);
    event FirstReceiveRecorded(address indexed account, uint256 timestamp);
    
    constructor(address initialOwner, uint256 _holdingPeriod) 
        Ownable(initialOwner) 
    {
        holdingPeriod = _holdingPeriod;
        emit HoldingPeriodSet(_holdingPeriod);
    }
    
    function setTokenContract(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token address");
        tokenContract = _token;
    }
    
    function setHoldingPeriod(uint256 _period) external onlyOwner {
        holdingPeriod = _period;
        emit HoldingPeriodSet(_period);
    }
    
    function canTransfer(address from, address, uint256) 
        external view override returns (bool) 
    {
        // Si nunca ha recibido, no puede enviar
        if (firstReceiveTime[from] == 0) return false;
        
        // Verificar que pasó el holding period
        return block.timestamp >= firstReceiveTime[from] + holdingPeriod;
    }
    
    function transferred(address, address to, uint256) external override {
        // Registrar primera recepción
        if (firstReceiveTime[to] == 0) {
            firstReceiveTime[to] = block.timestamp;
            emit FirstReceiveRecorded(to, block.timestamp);
        }
    }
    
    function created(address to, uint256) external override {
        // Registrar primera recepción (mint)
        if (firstReceiveTime[to] == 0) {
            firstReceiveTime[to] = block.timestamp;
            emit FirstReceiveRecorded(to, block.timestamp);
        }
    }
    
    function destroyed(address, uint256) external override {
        // No action needed
    }
    
    // View functions
    function getFirstReceiveTime(address account) external view returns (uint256) {
        return firstReceiveTime[account];
    }
    
    function getRemainingHoldingTime(address account) external view returns (uint256) {
        if (firstReceiveTime[account] == 0) return 0;
        
        uint256 unlockTime = firstReceiveTime[account] + holdingPeriod;
        if (block.timestamp >= unlockTime) return 0;
        
        return unlockTime - block.timestamp;
    }
}
```

---

## 🎓 Conclusión

Esta referencia técnica proporciona:

✅ **Templates** listos para usar  
✅ **Checklists** para no olvidar nada  
✅ **Snippets** de código común  
✅ **Patterns** probados y optimizados  
✅ **Comandos** esenciales de Foundry  

**Úsala como:**
- 📖 Referencia durante desarrollo
- ✅ Checklist antes de commit
- 🎯 Guía para code reviews
- 📚 Material de estudio

---

**¡Buena suerte implementando tus contratos!** 🚀

