# 🎓 Ejercicios Prácticos - RWA Token Platform

## 📋 Índice de Ejercicios

1. [Nivel Básico: Compliance Modules](#nivel-básico-compliance-modules)
2. [Nivel Intermedio: Token Customization](#nivel-intermedio-token-customization)
3. [Nivel Avanzado: System Integration](#nivel-avanzado-system-integration)
4. [Proyecto Final: RWA Platform](#proyecto-final-rwa-platform)

---

## 🟢 Nivel Básico: Compliance Modules

### Ejercicio 1.1: DailyTransferLimitCompliance

**Objetivo:** Limitar la cantidad de tokens que se pueden transferir por día.

**Especificación:**
- Cada usuario tiene un límite diario (ej: 100 tokens/día)
- El límite se resetea cada 24 horas
- Acumula transfers del día actual

**Esqueleto:**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ICompliance} from "../ICompliance.sol";

contract DailyTransferLimitCompliance is ICompliance, Ownable {
    uint256 public dailyLimit;
    address public tokenContract;
    
    // Mapping: user => day => amount transferred
    mapping(address => mapping(uint256 => uint256)) private dailyTransfers;
    
    constructor(address initialOwner, uint256 _dailyLimit) 
        Ownable(initialOwner) 
    {
        dailyLimit = _dailyLimit;
    }
    
    function getCurrentDay() public view returns (uint256) {
        // TODO: Calcular día actual (block.timestamp / 1 days)
    }
    
    function canTransfer(address from, address to, uint256 amount) 
        external view override returns (bool) 
    {
        // TODO: Verificar que from no exceda su límite diario
    }
    
    function transferred(address from, address to, uint256 amount) 
        external override 
    {
        // TODO: Actualizar dailyTransfers[from][currentDay]
    }
    
    function created(address, uint256) external override { }
    function destroyed(address, uint256) external override { }
}
```

**Tests a implementar:**

```solidity
function test_AllowsTransferUnderDailyLimit() public { }
function test_BlocksTransferOverDailyLimit() public { }
function test_ResetsAfter24Hours() public { }
function testFuzz_DailyLimits(uint256 limit, uint256 amount) public { }
```

**Bonus:**
- Implementa límites diferentes por usuario (VIP, Regular, Basic)
- Añade función para ver cuánto queda disponible hoy

---

### Ejercicio 1.2: WhitelistCompliance

**Objetivo:** Solo permite transfers entre direcciones whitelisted.

**Especificación:**
- El owner puede añadir/remover direcciones de la whitelist
- Solo direcciones whitelisted pueden recibir tokens
- (Opcional) También limita quién puede enviar

**Esqueleto:**

```solidity
contract WhitelistCompliance is ICompliance, Ownable {
    mapping(address => bool) public isWhitelisted;
    address public tokenContract;
    
    event AddressWhitelisted(address indexed account);
    event AddressRemovedFromWhitelist(address indexed account);
    
    function addToWhitelist(address account) external onlyOwner {
        // TODO: Implementar
    }
    
    function removeFromWhitelist(address account) external onlyOwner {
        // TODO: Implementar
    }
    
    function canTransfer(address from, address to, uint256) 
        external view override returns (bool) 
    {
        // TODO: Verificar que 'to' esté whitelisted
        // BONUS: También verificar 'from'
    }
}
```

**Tests a implementar:**

```solidity
function test_AllowsTransferToWhitelisted() public { }
function test_BlocksTransferToNonWhitelisted() public { }
function test_OnlyOwnerCanWhitelist() public { }
function test_BatchWhitelisting() public { }
```

---

### Ejercicio 1.3: CountryRestrictionCompliance

**Objetivo:** Restricción por países (similar a sanctions compliance).

**Especificación:**
- Asigna país a cada usuario
- Define países permitidos y bloqueados
- Solo permite transfers entre usuarios de países permitidos

**Esqueleto:**

```solidity
contract CountryRestrictionCompliance is ICompliance, Ownable {
    mapping(address => string) public userCountry;
    mapping(string => bool) public allowedCountries;
    mapping(string => bool) public blockedCountries;
    
    function setUserCountry(address user, string memory country) 
        external onlyOwner 
    {
        // TODO: Implementar
    }
    
    function addAllowedCountry(string memory country) external onlyOwner {
        // TODO: Implementar
    }
    
    function blockCountry(string memory country) external onlyOwner {
        // TODO: Implementar
    }
    
    function canTransfer(address from, address to, uint256) 
        external view override returns (bool) 
    {
        // TODO: Verificar países de from y to
        // 1. No deben estar en blockedCountries
        // 2. Deben estar en allowedCountries (si hay lista)
    }
}
```

**Bonus:**
- Añade eventos para tracking de compliance
- Implementa batch operations para países
- Añade función para obtener stats por país

---

## 🟡 Nivel Intermedio: Token Customization

### Ejercicio 2.1: DividendToken

**Objetivo:** Token que distribuye dividendos a los holders.

**Especificación:**
- Owner puede depositar ETH como dividendos
- Dividendos se distribuyen proporcionalmente al balance
- Holders pueden reclamar sus dividendos

**Esqueleto:**

```solidity
contract DividendToken is Token {
    uint256 public totalDividends;
    uint256 public dividendsPerShare;
    
    mapping(address => uint256) public lastDividendPoints;
    mapping(address => uint256) public unclaimedDividends;
    
    function depositDividends() external payable onlyRole(AGENT_ROLE) {
        // TODO: Actualizar dividendsPerShare
    }
    
    function claimDividends() external {
        // TODO: Calcular y transferir dividendos pendientes
    }
    
    function getDividends(address account) public view returns (uint256) {
        // TODO: Calcular dividendos acumulados
    }
}
```

**Desafíos:**
1. ¿Cómo calculas dividendos cuando los balances cambian?
2. ¿Cómo evitas que alguien haga gaming del sistema?
3. Implementa tests para edge cases

---

### Ejercicio 2.2: VotingToken

**Objetivo:** Token con capacidad de votación para holders.

**Especificación:**
- Crear propuestas de votación
- Holders votan con peso según su balance
- Ejecutar acciones si la propuesta pasa

**Esqueleto:**

```solidity
contract VotingToken is Token {
    struct Proposal {
        string description;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 deadline;
        bool executed;
    }
    
    Proposal[] public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    
    function createProposal(string memory description, uint256 duration) 
        external onlyRole(AGENT_ROLE) 
    {
        // TODO: Crear propuesta
    }
    
    function vote(uint256 proposalId, bool support) external {
        // TODO: Registrar voto con peso = balance del votante
    }
    
    function executeProposal(uint256 proposalId) external {
        // TODO: Verificar que pasó y ejecutar
    }
}
```

**Bonus:**
- Implementa quorum mínimo
- Añade delegación de votos
- Sistema de timelock para ejecución

---

### Ejercicio 2.3: Token con Fees

**Objetivo:** Token que cobra fee en cada transfer.

**Especificación:**
- Fee del 1% en cada transfer
- Fees van a una treasury address
- Owner puede ajustar el fee (máximo 5%)

**Pistas:**
```solidity
function _update(address from, address to, uint256 amount) 
    internal override 
{
    if (from != address(0) && to != address(0)) {
        // Calcular fee
        uint256 fee = (amount * feePercentage) / 10000;
        uint256 netAmount = amount - fee;
        
        // Transfer fee a treasury
        super._update(from, treasuryAddress, fee);
        
        // Transfer neto al destinatario
        amount = netAmount;
    }
    
    super._update(from, to, amount);
}
```

---

## 🔴 Nivel Avanzado: System Integration

### Ejercicio 3.1: Factory con Configuración Automática

**Objetivo:** Crear TokenCloneFactory que configure automáticamente compliance.

**Especificación:**
```solidity
function createTokenWithCompliance(
    string memory name,
    string memory symbol,
    uint8 decimals,
    address admin,
    uint256 maxBalance,
    uint256 maxHolders,
    uint256 lockPeriod
) external returns (address token) {
    // 1. Crear token clone
    // 2. Deploy módulos de compliance
    // 3. Configurar módulos
    // 4. Añadir aggregator al token
    // 5. Añadir módulos al aggregator
    // TODO: Implementar todo el flujo
}
```

**Tests:**
- Token creado tiene todos los módulos configurados
- Módulos funcionan correctamente
- No se pueden hacer transfers que violen compliance

---

### Ejercicio 3.2: Compliance Preset System

**Objetivo:** Sistema de presets de compliance para diferentes tipos de tokens.

**Especificación:**

```solidity
enum CompliancePreset {
    NONE,           // Sin compliance
    BASIC,          // MaxBalance
    STANDARD,       // MaxBalance + MaxHolders
    STRICT,         // Todo
    CUSTOM          // Usuario define
}

contract CompliancePresetManager {
    ComplianceAggregator public aggregator;
    
    function applyPreset(
        address token,
        CompliancePreset preset
    ) external {
        if (preset == CompliancePreset.BASIC) {
            // TODO: Añadir solo MaxBalance
        } else if (preset == CompliancePreset.STANDARD) {
            // TODO: Añadir MaxBalance + MaxHolders
        } else if (preset == CompliancePreset.STRICT) {
            // TODO: Añadir todos los módulos
        }
    }
}
```

---

### Ejercicio 3.3: Multi-Signature Compliance

**Objetivo:** Módulo que requiere aprobación de múltiples agentes.

**Especificación:**
- Transfers grandes (>$100k) requieren aprobación
- 2 de 3 agentes deben aprobar
- Timelock de 24 horas antes de ejecutar

**Complejidad:** Alta
- Requiere sistema de propuestas
- Tracking de aprobaciones
- Timelock mechanism

---

## 🎯 Proyecto Final: RWA Platform

### Descripción del Proyecto

Crea una **plataforma completa de tokenización** para un tipo de asset específico.

### Opciones de Asset

1. **Real Estate Platform**
   - Tokeniza propiedades
   - Cada propiedad es un token
   - Dividendos de rentas

2. **Art Collection Platform**
   - Tokeniza obras de arte
   - Fractionalized ownership
   - Royalties en transfers

3. **Commodity Platform**
   - Tokeniza oro, plata, etc.
   - Backed por assets físicos
   - Redeemable por el asset

4. **Startup Equity Platform**
   - Tokeniza shares de startups
   - Vesting schedules
   - Voting rights

### Requisitos Mínimos

#### Smart Contracts (70 puntos)

**1. Token System (20 puntos)**
- [ ] Usar TokenCloneFactory para crear tokens
- [ ] Al menos 2 tipos de tokens diferentes
- [ ] Configuración customizada por token

**2. Identity System (15 puntos)**
- [ ] Usar IdentityCloneFactory
- [ ] Sistema de claims implementado
- [ ] Trusted issuers configurados

**3. Compliance System (25 puntos)**
- [ ] Usar ComplianceAggregator
- [ ] Mínimo 3 módulos de compliance
- [ ] Al menos 1 módulo custom
- [ ] Reglas diferentes por token

**4. Access Control (10 puntos)**
- [ ] Roles bien definidos
- [ ] Permisos apropiados
- [ ] Funciones admin protegidas

#### Testing (20 puntos)

- [ ] Mínimo 30 tests
- [ ] Coverage >80%
- [ ] Tests unitarios
- [ ] Tests de integración
- [ ] Tests de edge cases

#### Deployment (5 puntos)

- [ ] Scripts de deployment
- [ ] Deploy en testnet
- [ ] Contratos verificados

#### Documentación (5 puntos)

- [ ] README del proyecto
- [ ] Arquitectura explicada
- [ ] Guía de uso
- [ ] Comentarios en código

### Entregables

```
📁 my-rwa-platform/
  📁 src/
    - MyToken.sol (o usa TokenCloneable)
    - CustomCompliance1.sol
    - CustomCompliance2.sol
    - (otros contratos custom)
    
  📁 test/
    - MyToken.t.sol
    - CustomCompliance.t.sol
    - Integration.t.sol
    
  📁 script/
    - Deploy.s.sol
    - Setup.s.sol
    
  📄 README.md
  📄 ARCHITECTURE.md
  📄 GAS_REPORT.md
```

---

## 📝 Template de Módulo de Compliance

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ICompliance} from "../ICompliance.sol";

/**
 * @title [TU_NOMBRE]Compliance
 * @dev [DESCRIPCIÓN]
 * 
 * Rule: [EXPLICAR LA REGLA]
 * Example: [EJEMPLO CONCRETO]
 */
contract [TuNombre]Compliance is ICompliance, Ownable {
    // ============ State Variables ============
    
    address public tokenContract;
    
    // TODO: Añade tus variables de estado
    
    // ============ Events ============
    
    event [Evento](/* parámetros */);
    
    // ============ Modifiers ============
    
    modifier onlyToken() {
        require(msg.sender == tokenContract, "Only token contract can call");
        _;
    }
    
    // ============ Constructor ============
    
    constructor(address initialOwner /* otros parámetros */) 
        Ownable(initialOwner) 
    {
        // TODO: Inicializar
    }
    
    // ============ Configuration ============
    
    function setTokenContract(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token address");
        tokenContract = _token;
    }
    
    // TODO: Añade funciones de configuración
    
    // ============ Compliance Functions ============
    
    function canTransfer(
        address from,
        address to,
        uint256 amount
    ) external view override returns (bool) {
        // TODO: Implementar lógica de verificación
    }
    
    function transferred(
        address from,
        address to,
        uint256 amount
    ) external override onlyToken {
        // TODO: Actualizar estado si es necesario
    }
    
    function created(
        address to,
        uint256 amount
    ) external override onlyToken {
        // TODO: Actualizar estado si es necesario
    }
    
    function destroyed(
        address from,
        uint256 amount
    ) external override onlyToken {
        // TODO: Actualizar estado si es necesario
    }
    
    // ============ View Functions ============
    
    // TODO: Añade funciones de consulta útiles
}
```

---

## 📝 Template de Tests

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {[TuModulo]Compliance} from "../src/compliance/[TuModulo]Compliance.sol";
import {TokenCloneable} from "../src/TokenCloneable.sol";

contract [TuModulo]ComplianceTest is Test {
    [TuModulo]Compliance public compliance;
    TokenCloneable public token;
    
    address public owner;
    address public user1;
    address public user2;
    
    function setUp() public {
        owner = makeAddr("owner");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        
        // Deploy compliance
        vm.prank(owner);
        compliance = new [TuModulo]Compliance(owner /* parámetros */);
        
        // Setup identities y token...
    }
    
    // ============ Configuration Tests ============
    
    function test_Constructor() public view {
        // Verificar estado inicial
    }
    
    function test_SetTokenContract() public {
        // Verificar que se puede configurar el token
    }
    
    // ============ Compliance Tests ============
    
    function test_AllowsCompliantTransfer() public {
        // Setup
        // Acción
        // Verificación
    }
    
    function test_BlocksNonCompliantTransfer() public {
        // Setup
        vm.expectRevert("Transfer not compliant");
        // Acción que debe fallar
    }
    
    // ============ State Update Tests ============
    
    function test_UpdatesStateOnTransfer() public {
        // Verificar que transferred() actualiza el estado
    }
    
    function test_UpdatesStateOnMint() public {
        // Verificar que created() actualiza el estado
    }
    
    // ============ Edge Cases ============
    
    function test_ZeroAmountTransfer() public { }
    function test_SelfTransfer() public { }
    
    // ============ Fuzzing ============
    
    function testFuzz_RandomAmounts(uint256 amount) public {
        amount = bound(amount, 1, type(uint128).max);
        // Test con diferentes cantidades
    }
}
```

---

## 🎯 Ideas de Módulos de Compliance

### Módulos Simples (1-2 horas)

1. **MinBalanceCompliance** - Mínimo de tokens para mantener
2. **TransferFeeCompliance** - Cobra fee en transfers
3. **CooldownCompliance** - Tiempo mínimo entre transfers
4. **BusinessHoursCompliance** - Solo transfers en horario laboral

### Módulos Intermedios (3-5 horas)

5. **VestingCompliance** - Unlock gradual de tokens
6. **TierBasedLimitsCompliance** - Límites según tier del usuario
7. **DividendDistributionCompliance** - Distribuye dividendos automáticamente
8. **AMLCompliance** - Anti-money laundering checks

### Módulos Avanzados (1-2 días)

9. **OracleBasedCompliance** - Usa Chainlink para datos externos
10. **GovernanceCompliance** - Requiere aprobación de DAO
11. **MultiSigCompliance** - Requiere múltiples firmas
12. **CrossChainCompliance** - Verifica compliance en múltiples chains

---

## 🔍 Debugging Guide

### Problema: "Transfer not compliant"

**Paso 1:** Identifica qué módulo está fallando

```solidity
// En Foundry console
ICompliance[] memory modules = token.getComplianceModules();

for (uint i = 0; i < modules.length; i++) {
    bool result = modules[i].canTransfer(from, to, amount);
    console.log("Module", i, "result:", result);
}
```

**Paso 2:** Investiga el módulo específico

```solidity
// Si MaxBalanceCompliance falla:
uint256 balance = token.balanceOf(to);
uint256 maxBalance = compliance.maxBalance();
console.log("Current balance:", balance);
console.log("Max allowed:", maxBalance);
console.log("Trying to add:", amount);
console.log("Would be:", balance + amount);
```

### Problema: "Only token contract can call"

**Causa:** Módulo con state llamado desde lugar no autorizado

**Solución:**
```solidity
// Si usas ComplianceAggregator:
module.addAuthorizedCaller(address(aggregator));
```

### Problema: Clone initialization fails

**Causa:** Trying to initialize an already initialized clone

**Solución:**
```solidity
// Verifica que solo se inicializa una vez
function initialize(...) external initializer {
    // initializer modifier previene re-inicialización
}
```

---

## 📊 Métricas y Benchmarking

### Gas Optimization Checklist (con criterio observable)

| Práctica | Cómo se comprueba (comando / umbral) |
|---|---|
| `immutable`/`constant` para valores fijos | `forge inspect <Contrato> storage-layout --json` no lista la variable como storage |
| Cachear `array.length` en loops | `forge test --gas-report` con ≤ N llamadas `SLOAD` por iteración (revisar `--gas-report`) |
| Evitar escrituras de storage innecesarias | comparar `forge snapshot` antes/después: 0 regresiones con `--check --tolerance 5` |
| `memory` en lugar de `storage` en lecturas | 0 warnings de `forge lint` sobre copia innecesaria a storage |
| Empaquetar bools en un `uint256` | tamaño de `storage-layout` en bytes ≤ diseño de referencia |
| Custom errors en lugar de strings | `grep -c 'require(.*"' src/**/*.sol` = 0 |
| Evitar loops sobre arrays sin cota | vistas con paginación (`getXAt(index)`) y test de gas con N=100 sin crecimiento O(n²) |
| Baseline de gas versionado | `forge snapshot --check --tolerance 5` exit 0 con `.gas-snapshot` commiteado |

### Medir Gas

```bash
# Gas report completo
forge test --gas-report

# Gas de función específica
forge test --match-test test_MyFunction --gas-report

# Comparar implementaciones
# Implementación A
forge test --match-test test_VersionA --gas-report > gasA.txt
# Implementación B
forge test --match-test test_VersionB --gas-report > gasB.txt
# Comparar archivos
```

---

## 🎓 Rúbrica de Evaluación (criterios observables)

> Cada banda se comprueba **ejecutando comandos** sobre el proyecto del estudiante. No se evalúa por
> impresión subjetiva: se exige el artefacto o el `exit 0`. D-017: la cobertura se mide sobre `src/`
> excluyendo interfaces y `test/`.

| Criterio observable | Comando / artefacto | Excelente (90-100) | Bueno (75-89) | Aprobado (60-74) | Reprobado (<60) |
|---|---|---|---|---|---|
| Compila sin errores ni warnings de `solc` | `forge build` (exit 0) | exit 0 | exit 0 | exit 0 | falla |
| Formato | `forge fmt --check` | exit 0 | exit 0 | no exigido | — |
| Suite en verde | `forge test` | 0 fallos y ≥ 95 % de las suites con ≥ 1 aserción `assert*`/`vm.expectRevert` | 0 fallos | 0 fallos | ≥ 1 fallo |
| Tests negativos (revert) | `forge test --match-test Revert` | ≥ 1 por función con `require`/custom error | ≥ 1 por contrato | ≥ 1 en total | 0 |
| Cobertura de líneas `src/` (D-017) | `forge coverage --report summary` | ≥ 90 % | ≥ 80 % | ≥ 60 % | < 60 % |
| Ahorro de gas con comparación equivalente | test `CREATE` (clon vs despliegue completo) | ≥ 50 % y `.gas-snapshot` con `forge snapshot --check --tolerance 5` exit 0 | ≥ 40 % y cifra documentada con enlace al test | ahorro documentado | sin medición o cifra sin respaldo |
| Seguridad: sin hallazgos altos | `slither . --filter-path test` | 0 High y 0 Medium | 0 High | 0 High críticos (reentrancia/control de acceso) | ≥ 1 High |
| Sin secretos versionados | `grep -rniE 'private[_-]?key|keystore' src script README.md` | 0 coincidencias de material real | 0 | 0 | clave o seed en el repo |
| Documentación verificable | `script/ci/check_docs.sh` (adapta el alcance) | exit 0 y cifras con enlace a artefacto | exit 0 | README con comandos reproducibles | referencia a archivos inexistentes o "production-ready"/"ERC-3643 compliant" sin auditoría |
| Deriva de ABIs | `script/ci/abi_diff.sh` | exit 0 con `abis/` versionado | exit 0 | — | ABI cambiada sin entrada en el changelog |

---

## 🚀 Siguiente Nivel

Una vez domines este proyecto, puedes:

1. **Integración con Frontend**
   - Next.js + wagmi
   - UI para crear tokens
   - Dashboard de compliance

2. **Auditoría de Seguridad**
   - Estudiar vulnerabilidades comunes
   - Usar herramientas como Slither
   - Participar en auditorías

3. **Deploy en Mainnet**
   - Preparación para producción
   - Monitoreo y mantenimiento
   - Gestión de upgrades

4. **Contribuir a Standards**
   - Mejorar ERC-3643
   - Proponer nuevos EIPs
   - Participar en comunidad

---

## 📚 Recursos Adicionales

### Cursos Recomendados

- [CryptoZombies](https://cryptozombies.io/) - Solidity básico
- [Foundry Course by Cyfrin](https://updraft.cyfrin.io/) - Testing avanzado
- [Smart Contract Security](https://www.secureum.xyz/) - Seguridad

### Lecturas Obligatorias

1. [ERC-3643 Specification](https://erc3643.org/)
2. [EIP-1167 Minimal Proxy](https://eips.ethereum.org/EIPS/eip-1167)
3. [OpenZeppelin Contracts Documentation](https://docs.openzeppelin.com/)
4. [Foundry Book](https://book.getfoundry.sh/)

### Videos Útiles

- "Understanding ERC-3643" en YouTube
- "Clone Factory Pattern" - Smart Contract Programmer
- "Foundry Testing" - Patrick Collins

---

**¡Feliz aprendizaje! 🎓🚀**

Recuerda: El mejor modo de aprender es **haciendo**. No solo leas el código, **escríbelo**, **rómpelo**, **arréglalo**.

