# 🚀 START HERE - Guía de Inicio para Estudiantes

## 👋 Bienvenido

Este proyecto es un **sistema de tokenización de RWA** (Real World Assets) **inspirado en ERC-3643 / T-REX** con patrones avanzados de Solidity. **No es "ERC-3643 compliant"**: implementa un subconjunto propio de interfaces (declaración verificable en [`SECURITY.md`](SECURITY.md)) y **no está auditado ni es apto para producción con activos reales** (ver [`RepoTecnico/INFORME_OPTIMIZACION_V1.md`](RepoTecnico/INFORME_OPTIMIZACION_V1.md)).

```
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   📚 PROYECTO EDUCATIVO DE NIVEL PROFESIONAL             ║
║                                                           ║
║   ✅ 420 tests (420 passing, 0 failing)                  ║
║   ✅ Gas medido: baseline .gas-snapshot                  ║
║   ✅ Patrones de diseño avanzados                        ║
║   ✅ Documentación completa                              ║
║                                                           ║
║   🎯 Nivel: Intermedio-Avanzado                          ║
║   ⏱️  Tiempo estimado: 3-4 semanas                       ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
```

---

## 🗺️ Mapa de Documentación

### Para Empezar (Lee en este orden)

```
1. 📖 START_HERE.md (este archivo)
   └─ Overview y ruta de aprendizaje

2. 📚 GUIA_ESTUDIANTE.md ⭐ IMPORTANTE
   └─ Conceptos, arquitectura, explicaciones completas

3. 🔧 REFERENCIA_TECNICA.md
   └─ Templates, snippets, checklists

4. 💪 EJERCICIOS_PRACTICOS.md
   └─ Ejercicios paso a paso con código

5. 📖 README.md
   └─ Overview técnico del proyecto
```

### Documentación del Proyecto (Fuera de sc/)



---

## 🎯 ¿Qué vas a Aprender?

### Conceptos de Blockchain

```
✅ Smart Contracts con Solidity 0.8.20
✅ ERC-20 y extensiones (ERC-3643)
✅ Access Control y roles
✅ Pausability y emergency stops
✅ Events y logging
✅ Gas optimization
```

### Patrones de Diseño

```
✅ Clone Factory (EIP-1167) - ~55% ahorro de gas (medido)
✅ Proxy Pattern - Delegación de compliance
✅ Registry Pattern - Centralized data
✅ Modifier Pattern - Authorization
✅ Initializable Pattern - Clone compatibility
```

### Herramientas

```
✅ Foundry (forge, cast, anvil)
✅ OpenZeppelin Contracts
✅ Testing avanzado
✅ Gas profiling
✅ Deployment automation
```

---

## 📅 Ruta de Aprendizaje Recomendada

### Semana 1: Fundamentos 🟢

**Día 1: Setup y Exploración**
```bash
# 1. Instalar Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 2. Explorar el proyecto
cd sc
forge build
forge test

# 3. Leer documentación
# - START_HERE.md (este archivo)
# - README.md (proyecto)
```

**Día 2-3: Identity System**
```
📖 Leer:
  - src/IdentityCloneable.sol
  - src/IdentityCloneFactory.sol
  - src/IdentityRegistry.sol
  - src/TrustedIssuersRegistry.sol
  - src/ClaimTopicsRegistry.sol

🧪 Ejecutar:
  forge test --match-contract IdentityCloneFactoryTest -vvv

💡 Entender:
  - ¿Qué es un Claim?
  - ¿Cómo se verifica una identidad?
  - ¿Por qué necesitamos trusted issuers?
```

**Día 4-5: Compliance Modules**
```
📖 Leer:
  - src/ICompliance.sol
  - src/compliance/MaxBalanceCompliance.sol
  - src/compliance/MaxHoldersCompliance.sol
  - src/compliance/TransferLockCompliance.sol

🧪 Ejecutar:
  forge test --match-contract MaxBalanceComplianceTest -vvv
  forge test --match-contract MaxHoldersComplianceTest -vvv

💡 Entender:
  - Interface ICompliance
  - Diferencia entre canTransfer() y transferred()
  - ¿Por qué algunos módulos necesitan state?
```

**Día 6-7: Token Principal**
```
📖 Leer:
  - src/TokenCloneable.sol (línea por línea)
  - src/TokenCloneFactory.sol

🧪 Ejecutar:
  forge test --match-contract TokenTest -vvv

💡 Entender:
  - Flujo completo de una transferencia
  - Función isVerified()
  - Función canTransfer()
  - Override de _update()

✍️ Ejercicio:
  - Dibuja diagrama de flujo de transfer
  - Implementa TimeBasedCompliance (EJERCICIOS_PRACTICOS.md)
```

### Semana 2: Patrones Avanzados 🟡

**Día 1-3: Clone Factory**
```
📖 Leer:
  - EIP-1167 specification
  - src/TokenCloneable.sol
  - src/TokenCloneFactory.sol
  - REFERENCIA_TECNICA.md (patrón Clone Factory y gas)

🧪 Ejecutar:
  forge test --match-contract TokenCloneFactoryTest -vvv
  forge test --match-test test_GasSavings -vvvv

💡 Entender:
  - ¿Por qué ahorra gas?
  - Diferencia constructor vs initialize
  - ¿Qué es _disableInitializers()?
  - Delegatecall vs Call

✍️ Ejercicio:
  - Mide el gas savings real
  - Crea un IdentityClone manualmente
  - Compara Token vs TokenCloneable
```

**Día 4-6: Compliance Aggregator**
```
📖 Leer:
  - src/compliance/ComplianceAggregator.sol
  - REFERENCIA_TECNICA.md (aggregator y compliance modular)

🧪 Ejecutar:
  forge test --match-contract ComplianceAggregatorTest -vvv

💡 Entender:
  - ¿Por qué array de módulos?
  - ¿Cómo funciona la delegación?
  - Gestión dual (owner + token)
  - Authorized callers

✍️ Ejercicio:
  - Usa aggregator con 3 módulos
  - Añade módulo desde el token
  - Implementa WhitelistCompliance (EJERCICIOS_PRACTICOS.md)
```

**Día 7: Integration**
```
📖 Leer:
  - Métodos de Token para aggregator
  - Tests de integración

🧪 Ejecutar:
  forge test --match-test test_Token -vvv

💡 Entender:
  - addModuleThroughAggregator()
  - ¿Por qué verificar que aggregator esté añadido?

✍️ Ejercicio:
  - Deploy sistema completo en Anvil
  - Crea 2 tokens con compliance diferente
```

### Semana 3: Proyecto Práctico 🔴

**Día 1-2: Diseño**
```
✍️ Diseña tu RWA Platform:
  - Elige un asset (real estate, art, commodity)
  - Define compliance rules necesarias
  - Diseña arquitectura
  - Escribe especificaciones
```

**Día 3-5: Implementación**
```
💻 Implementa:
  - Módulos de compliance custom
  - Tests comprehensivos
  - Scripts de deployment
```

**Día 6-7: Testing y Documentación**
```
🧪 Testing:
  - Mínimo 30 tests
  - Coverage >80% (objetivo del curso; cobertura real medida: 67,5 % total / 86,3 % de `src/`)
  - Gas profiling

📝 Documentación:
  - README
  - Arquitectura
  - Guía de uso
```

### Semana 4: Refinamiento y Presentación 🚀

```
✨ Pulir:
  - Code review propio
  - Optimizaciones de gas
  - Security review
  - Deploy en testnet
  - Verificar contratos
  - Preparar demo
```

---

## 🎯 Quick Start (15 minutos)

### Opción 1: Solo Explorar

```bash
# 1. Ver contratos
cd sc
ls -la src/
ls -la src/compliance/

# 2. Ejecutar tests
forge test

# 3. Ver gas report
forge test --gas-report | less

# 4. Leer código principal
# - src/TokenCloneable.sol
# - src/TokenCloneFactory.sol
# - src/compliance/ComplianceAggregator.sol
```

### Opción 2: Deploy Local

```bash
# Terminal 1: Iniciar Anvil
anvil

# Terminal 2: Deploy y usar
cd sc

# Deploy token factory
forge script script/DeployTokenCloneFactory.s.sol --rpc-url localhost --broadcast

# Deploy compliance aggregator
forge script script/DeployComplianceAggregator.s.sol --rpc-url localhost --broadcast

# Crear un token
forge script script/CreateTokenWithCloneFactory.s.sol --rpc-url localhost --broadcast
```

### Opción 3: Ejecutar un Test Específico

```bash
cd sc

# Test de token clone factory
forge test --match-test test_CreateToken -vvvv

# Test de compliance aggregator
forge test --match-test test_TokenCanAddModuleThroughAggregator -vvvv

# Test completo de integración
forge test --match-test test_CompleteTransferFlow -vvvv
```

---

## 📋 Checklist del Estudiante

### Antes de Empezar

```
[ ] Tengo Foundry instalado (forge, cast, anvil)
[ ] Entiendo Solidity básico (variables, funciones, mappings)
[ ] Sé qué es ERC-20
[ ] Tengo editor de código configurado (VSCode + Solidity extension)
[ ] He clonado el repositorio
[ ] Puedo ejecutar forge build y forge test
```

### Después de Semana 1

```
[ ] Entiendo qué es un RWA token
[ ] Puedo explicar el sistema de Identity y Claims
[ ] Sé cómo funcionan los módulos de compliance
[ ] He leído y entendido TokenCloneable.sol
[ ] He ejecutado todos los tests y entiendo qué verifican
[ ] He implementado al menos 1 módulo de compliance simple
```

### Después de Semana 2

```
[ ] Entiendo el patrón Clone Factory
[ ] Sé la diferencia entre Token y TokenCloneable
[ ] Puedo explicar por qué ahorra gas
[ ] Entiendo el ComplianceAggregator
[ ] He deployado el sistema completo en Anvil
[ ] He creado tokens usando el factory
[ ] He configurado compliance usando el aggregator
```

### Después de Semana 3

```
[ ] He completado mi proyecto RWA
[ ] Tengo mínimo 30 tests pasando
[ ] Coverage >80% (objetivo del curso; cobertura real medida: 67,5 % total / 86,3 % de `src/`)
[ ] Documentación completa
[ ] Sistema deployado en testnet
[ ] Gas profiling realizado
```

---

## 🆘 ¿Dónde Buscar Ayuda?

### Por Tipo de Pregunta

| Pregunta | Documento |
|----------|-----------|
| "¿Qué es ERC-3643?" | GUIA_ESTUDIANTE.md → Conceptos Fundamentales |
| "¿Cómo funciona Clone Factory?" | GUIA_ESTUDIANTE.md → Patrones de Diseño |
| "¿Cómo uso el Aggregator?" | GUIA_ESTUDIANTE.md → ComplianceAggregator |
| "¿Cómo implemento un módulo?" | REFERENCIA_TECNICA.md → Templates |
| "¿Qué ejercicios puedo hacer?" | EJERCICIOS_PRACTICOS.md |
| "¿Cómo escribo tests?" | REFERENCIA_TECNICA.md → Testing |
| "Error en mi código" | REFERENCIA_TECNICA.md → Debugging |

### Por Nivel de Detalle

**Overview rápido:**
- README.md (proyecto completo)
- START_HERE.md (este archivo)

**Tutorial paso a paso:**
- GUIA_ESTUDIANTE.md ⭐
- EJERCICIOS_PRACTICOS.md

**Referencia técnica:**
- REFERENCIA_TECNICA.md ⭐
- Código fuente con comentarios

---

## 🎯 Rutas de Aprendizaje

### Ruta A: "Quiero Entender Todo" (Recomendada)

```
Semana 1: Fundamentos
  ├─ Día 1-2: Identity System
  ├─ Día 3-4: Compliance Modules
  └─ Día 5-7: Token Principal

Semana 2: Patrones Avanzados
  ├─ Día 1-3: Clone Factory
  ├─ Día 4-6: Compliance Aggregator
  └─ Día 7: Integration

Semana 3-4: Proyecto Final
  ├─ Diseño
  ├─ Implementación
  ├─ Testing
  └─ Documentación
```

### Ruta B: "Solo lo Esencial" (Rápida)

```
Semana 1:
  ├─ Día 1: Overview general
  ├─ Día 2-3: TokenCloneable.sol y compliance
  ├─ Día 4: Clone Factory
  └─ Día 5-7: Proyecto simple

Semana 2:
  ├─ Testing
  ├─ Deployment
  └─ Presentación
```

### Ruta C: "Focus en Compliance" (Especializada)

```
Semana 1:
  ├─ ICompliance interface
  ├─ Estudiar 3 módulos existentes
  ├─ Implementar 3 módulos nuevos
  └─ ComplianceAggregator

Semana 2:
  ├─ Módulos avanzados
  ├─ Integration testing
  └─ Proyecto de compliance
```

---

## 📚 Estructura del Proyecto

### Archivos Principales

```
📁 sc/
  │
  ├─ 📄 START_HERE.md ⭐ (Este archivo)
  ├─ 📄 GUIA_ESTUDIANTE.md ⭐ (Guía principal)
  ├─ 📄 EJERCICIOS_PRACTICOS.md (Ejercicios)
  ├─ 📄 REFERENCIA_TECNICA.md (Templates y snippets)
  │
  ├─ 📁 src/
  │   ├─ TokenCloneable.sol ⭐ (Token clonable)
  │   ├─ TokenCloneFactory.sol (Factory de tokens)
  │   ├─ IdentityCloneable.sol (Identity clonable)
  │   ├─ IdentityCloneFactory.sol (Factory de identities)
  │   ├─ IdentityRegistry.sol (Registro de identidades)
  │   ├─ TrustedIssuersRegistry.sol (Emisores autorizados)
  │   ├─ ClaimTopicsRegistry.sol / ClaimTopicsRegistryCloneable.sol
  │   ├─ ICompliance.sol / IClaimTopicsRegistry.sol (interfaces)
  │   └─ 📁 compliance/
  │       ├─ ComplianceAggregator.sol ⭐ (Aggregador)
  │       ├─ MaxBalanceCompliance.sol (Ejemplo 1)
  │       ├─ MaxHoldersCompliance.sol (Ejemplo 2)
  │       └─ TransferLockCompliance.sol (Ejemplo 3)
  │
  ├─ 📁 test/
  │   └─ 24 suites de tests (420 tests totales)
  │
  └─ 📁 script/
      └─ 7 scripts Solidity (.s.sol) + deploy.sh + ci/
```

---

## 🎓 Niveles de Aprendizaje

### Nivel 1: Principiante (Si eres nuevo en Solidity)

**Prerequisitos:**
- Aprende Solidity básico primero (CryptoZombies, Solidity docs)
- Entiende qué es blockchain
- Conoce conceptos de OOP

**Empieza con:**
1. Leer GUIA_ESTUDIANTE.md → Conceptos Fundamentales
2. Estudiar MaxBalanceCompliance.sol (el más simple)
3. Implementar módulo simple (EJERCICIOS_PRACTICOS.md → Ejercicio 1.1)

### Nivel 2: Intermedio (Ya conoces Solidity)

**Empieza con:**
1. Leer GUIA_ESTUDIANTE.md completo
2. Estudiar TokenCloneable.sol
3. Estudiar Clone Factory
4. Implementar módulo intermedio (EJERCICIOS_PRACTICOS.md → Ejercicio 2.x)

### Nivel 3: Avanzado (Experiencia en DeFi/Smart Contracts)

**Empieza con:**
1. Review rápido de arquitectura
2. Focus en patrones avanzados (Clone Factory, Aggregator)
3. Implementar proyecto final completo
4. Contribuir mejoras al proyecto

---

## 💡 Tips de Estudio

### 1. Lee el Código en el Orden Correcto

```
Orden recomendado:
1. ICompliance.sol (interface, simple)
2. MaxBalanceCompliance.sol (módulo simple)
3. IdentityCloneable.sol (concepto de claims)
4. IdentityRegistry.sol (registry pattern)
5. TokenCloneable.sol (integra todo)
6. TokenCloneable.sol (variante cloneable)
7. ComplianceAggregator.sol (patrón avanzado)
```

### 2. Usa los Tests como Tutoriales

```bash
# Los tests muestran CÓMO usar cada contrato
forge test --match-contract MaxBalanceComplianceTest -vvv

# Cada test es un ejemplo de uso
# Lee los tests para ver:
# - Cómo configurar el contrato
# - Cómo llamar las funciones
# - Qué resultados esperar
```

### 3. Experimenta en Anvil

```bash
# Terminal 1
anvil

# Terminal 2
cd sc

# Deploy algo
forge script script/DeployTokenCloneFactory.s.sol --rpc-url localhost --broadcast

# Interactúa con cast
cast call CONTRACT_ADDRESS "name()" --rpc-url localhost

# Modifica, prueba, rompe, aprende
```

### 4. Dibuja Diagramas

```
Dibuja en papel o herramienta digital:
- Flujo de datos (quién llama a quién)
- Jerarquía de contratos
- Flujo de una transferencia
- Estado de un módulo de compliance

Herramientas: Excalidraw, draw.io, papel
```

### 5. Escribe Mientras Lees

```
No solo leas, escribe:
- Copia código a mano (aprenderás más)
- Modifica parámetros y ve qué pasa
- Implementa variaciones
- Rompe el código intencionalmente y arréglalo
```

---

## 🔍 Conceptos Clave a Dominar

### 1. Identity Verification

```
Wallet ──► IdentityRegistry ──► Identity Contract ──► Claims
  │              │                    │                  │
  │              │                    │                  └─ Emitidos por Trusted Issuers
  │              │                    └─ Almacena claims del usuario
  │              └─ Mapea wallet → identity
  └─ Usuario que quiere invertir

Para que un usuario pueda recibir tokens:
1. Debe tener Identity registrado en IdentityRegistry
2. Identity debe tener Claims requeridos (definidos en ClaimTopicsRegistry)
3. Claims deben ser de Trusted Issuers (en TrustedIssuersRegistry)
```

### 2. Compliance Flow

```
Transfer Request
    │
    ├─► isVerified(from)? ──► Identity check
    ├─► isVerified(to)? ──► Identity check
    ├─► paused()? ──► Global pause check
    ├─► frozen[from]? ──► Account freeze check
    ├─► frozen[to]? ──► Account freeze check
    └─► complianceModules? ──► Each module.canTransfer()
            │
            ├─► Module 1: MaxBalance ✓
            ├─► Module 2: MaxHolders ✓
            └─► Module 3: TransferLock ✓
                    │
                    └─► ALL must be ✓
```

### 3. Clone Factory Mechanism

```
Step 1: Deploy Implementation (una vez)
  Implementation = new TokenCloneable()
  Cost: ~5.7M gas

Step 2: Create Clones (muchas veces)
  clone = implementation.clone()
  Cost: ~365K gas por clone
  
Clone Structure (45 bytes):
  - 10 bytes: Clone opcode
  - 20 bytes: Implementation address
  - 15 bytes: Return logic

Cuando llamas clone.transfer():
  1. Clone recibe llamada
  2. Clone hace delegatecall(implementation)
  3. Código en implementation se ejecuta
  4. Storage del clone se usa
  5. Resultado retorna al caller
```

### 4. Modular Compliance

```
Token ──► ComplianceAggregator
              │
              ├─ tokenModules[token] = [Module A, Module B, Module C]
              │
              └─ canTransfer() delega a TODOS:
                    │
                    ├─► Module A.canTransfer() → true/false
                    ├─► Module B.canTransfer() → true/false
                    └─► Module C.canTransfer() → true/false
                            │
                            └─► Return true solo si TODOS true
```

---

## 🎯 Objetivos de Aprendizaje Específicos

Al completar este proyecto, deberías poder:

### Smart Contract Development

- [ ] Implementar un ERC-20 compliant token
- [ ] Usar OpenZeppelin contracts como base
- [ ] Implementar access control con roles
- [ ] Crear y usar interfaces (ICompliance)
- [ ] Override funciones correctamente
- [ ] Emitir y escuchar eventos
- [ ] Optimizar gas consumption

### Advanced Patterns

- [ ] Implementar Clone Factory (EIP-1167)
- [ ] Crear contratos Initializable
- [ ] Usar delegatecall correctamente
- [ ] Implementar proxy patterns
- [ ] Diseñar arquitecturas modulares
- [ ] Gestionar dependencies entre contratos

### Testing

- [ ] Escribir tests unitarios con Foundry
- [ ] Escribir tests de integración
- [ ] Usar fuzzing efectivamente
- [ ] Medir y optimizar gas
- [ ] Alcanzar >80% coverage (objetivo del curso; cobertura real medida: 67,5 % total / 86,3 % de `src/`)
- [ ] Debuggear contratos complejos

### Deployment

- [ ] Escribir scripts de deployment
- [ ] Deployar en local (Anvil)
- [ ] Deployar en testnet
- [ ] Verificar contratos en Etherscan
- [ ] Gestionar addresses deployadas
- [ ] Usar variables de entorno

---

## 📖 Glosario Express

| Término | Definición Rápida |
|---------|-------------------|
| **RWA** | Real World Asset tokenizado en blockchain |
| **ERC-3643** | Estándar para security tokens (tokens regulados) |
| **Claim** | Afirmación verificable (ej: "usuario pasó KYC") |
| **Compliance** | Reglas que deben cumplirse para operar |
| **Clone** | Copia ligera de contrato (EIP-1167) |
| **Aggregator** | Contrato que centraliza módulos |
| **Initializable** | Patrón para contratos cloneables |
| **delegatecall** | Ejecuta código en contexto del caller |

---

## 🚀 Primer Paso Ahora Mismo

```bash
# 1. Abre este archivo en tu editor
code GUIA_ESTUDIANTE.md

# 2. Lee las primeras 3 secciones (30 min)

# 3. Ejecuta los tests
cd sc
forge test -vv

# 4. Lee el código de MaxBalanceCompliance.sol
code src/compliance/MaxBalanceCompliance.sol

# 5. Implementa tu primer módulo
# (Usa template de REFERENCIA_TECNICA.md)
```

---

## 📞 Recursos de Soporte

### Documentación

- **GUIA_ESTUDIANTE.md** - Tu guía principal ⭐
- **EJERCICIOS_PRACTICOS.md** - Ejercicios con soluciones
- **REFERENCIA_TECNICA.md** - Templates y snippets
- **Código fuente** - Está bien comentado, léelo

### Comunidad

- [Foundry Discord](https://discord.gg/foundry)
- [OpenZeppelin Forum](https://forum.openzeppelin.com/)
- [Ethereum StackExchange](https://ethereum.stackexchange.com/)

### Herramientas

- [Foundry Book](https://book.getfoundry.sh/) - Documentación oficial
- [Solidity Docs](https://docs.soliditylang.org/) - Lenguaje
- [OpenZeppelin Docs](https://docs.openzeppelin.com/) - Librerías

---

## ✅ Próximos Pasos

```
┌─────────────────────────────────────────┐
│  1. ✅ Lee GUIA_ESTUDIANTE.md           │
│     (Conceptos fundamentales)           │
│                                         │
│  2. ✅ Ejecuta forge test               │
│     (Ve que todo funciona)              │
│                                         │
│  3. ✅ Lee MaxBalanceCompliance.sol     │
│     (Módulo más simple)                 │
│                                         │
│  4. ✅ Implementa tu primer módulo      │
│     (EJERCICIOS_PRACTICOS.md)           │
│                                         │
│  5. ✅ Continúa con TokenCloneable.sol   │
│     (Integra todo)                      │
│                                         │
│  6. 🚀 Proyecto final                   │
│     (Tu RWA Platform)                   │
└─────────────────────────────────────────┘
```

---

**¡Éxito en tu aprendizaje! 🎓🚀**

> "La mejor manera de aprender es haciendo. No solo leas, implementa." - Vitalik Buterin

**Empieza ahora:** Abre `GUIA_ESTUDIANTE.md` y comienza tu viaje. 📚

