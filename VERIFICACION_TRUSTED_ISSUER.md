# 🔐 Verificación de Trusted Issuer

## 📋 Proceso Completo

### Fase 1: Configuración Inicial (Setup)

```solidity
// ===== PASO 1: Crear TrustedIssuersRegistry =====
TrustedIssuersRegistry trustedIssuersRegistry = new TrustedIssuersRegistry(admin);

// ===== PASO 2: Agregar emisores confiables =====
address kycProvider = 0x123...;  // Proveedor KYC (ej: Onfido, Jumio)
address amlProvider = 0x456...;  // Proveedor AML (ej: Chainalysis)

// KYC Provider puede emitir topics 1 (KYC) y 2 (AML)
uint256[] memory kycTopics = [1, 2];
trustedIssuersRegistry.addTrustedIssuer(kycProvider, kycTopics);

// AML Provider solo puede emitir topic 2 (AML)
uint256[] memory amlTopics = [2];
trustedIssuersRegistry.addTrustedIssuer(amlProvider, amlTopics);

// Investor Accreditation Provider puede emitir topic 3
uint256[] memory accreditedTopics = [3];
trustedIssuersRegistry.addTrustedIssuer(accreditationProvider, accreditedTopics);
```

**Estado del Registry después del setup:**
```
TrustedIssuersRegistry {
    trustedIssuers: {
        0x123... (kycProvider) → true,
        0x456... (amlProvider) → true,
        0x789... (accreditationProvider) → true
    },
    issuerClaimTopics: {
        0x123... → [1, 2],
        0x456... → [2],
        0x789... → [3]
    },
    trustedIssuersList: [0x123..., 0x456..., 0x789...]
}
```

### Fase 2: Emisión de Claims

```solidity
// ===== Inversor obtiene su Identity =====
address investor = 0xABC...;
address identityContract = identityFactory.createIdentity(investor);

// ===== KYC Provider emite claim =====
// El KYC provider verifica al inversor off-chain y luego:
vm.prank(investor); // El owner de la identity agrega el claim
IdentityCloneable(identityContract).addClaim(
    1,              // topic: KYC
    1,              // scheme: ECDSA
    kycProvider,    // issuer: 0x123...
    signature,      // firma del issuer
    data,           // datos del claim
    "https://..."  // URI con más info
);

// ===== AML Provider emite claim =====
IdentityCloneable(identityContract).addClaim(
    2,              // topic: AML
    1,              // scheme: ECDSA
    amlProvider,    // issuer: 0x456...
    signature,
    data,
    "https://..."
);
```

**Estado de la Identity después:**
```
IdentityCloneable {
    claims: {
        1 (KYC) → {
            0x123... (kycProvider) → Claim {
                topic: 1,
                issuer: 0x123...,
                signature: 0x...,
                data: 0x...
            }
        },
        2 (AML) → {
            0x456... (amlProvider) → Claim {
                topic: 2,
                issuer: 0x456...,
                signature: 0x...,
                data: 0x...
            }
        }
    }
}
```

### Fase 3: Verificación en Transfer

Cuando un usuario intenta transferir tokens:

```solidity
token.transfer(recipient, 100);
```

El Token ejecuta `isVerified(recipient)`:

```
┌─────────────────────────────────────────────────────────────┐
│ PASO 1: Obtener topics requeridos por este token           │
└─────────────────────────────────────────────────────────────┘
TokenCloneable.isVerified(0xABC...)
    │
    ├─► ClaimTopicsRegistry.getClaimTopics()
    │       └─► retorna: [1, 2]  (KYC y AML requeridos)
    │
┌─────────────────────────────────────────────────────────────┐
│ PASO 2: Obtener Identity del inversor                      │
└─────────────────────────────────────────────────────────────┘
    ├─► IdentityRegistry.getIdentity(0xABC...)
    │       └─► retorna: 0xDEF... (address del IdentityCloneable)
    │
┌─────────────────────────────────────────────────────────────┐
│ PASO 3: Para CADA topic requerido, verificar               │
└─────────────────────────────────────────────────────────────┘
    │
    ├─► Para topic 1 (KYC):
    │   │
    │   ├─► TrustedIssuersRegistry.getTrustedIssuers()
    │   │       └─► retorna: [0x123..., 0x456..., 0x789...]
    │   │
    │   ├─► Para cada trusted issuer:
    │   │   │
    │   │   ├─► Issuer 0x123... (kycProvider):
    │   │   │   │
    │   │   │   ├─► TrustedIssuersRegistry.hasClaimTopic(0x123..., 1)
    │   │   │   │       └─► retorna: true ✓ (puede emitir topic 1)
    │   │   │   │
    │   │   │   ├─► IdentityCloneable(0xDEF).claimExists(1, 0x123...)
    │   │   │   │       └─► retorna: true ✓ (claim existe)
    │   │   │   │
    │   │   │   └─► ✅ CLAIM VÁLIDO ENCONTRADO (break loop)
    │   │   │
    │   └─► hasValidClaim = true ✅
    │
    ├─► Para topic 2 (AML):
    │   │
    │   ├─► TrustedIssuersRegistry.getTrustedIssuers()
    │   │       └─► retorna: [0x123..., 0x456..., 0x789...]
    │   │
    │   ├─► Para cada trusted issuer:
    │   │   │
    │   │   ├─► Issuer 0x123... (kycProvider):
    │   │   │   │
    │   │   │   ├─► TrustedIssuersRegistry.hasClaimTopic(0x123..., 2)
    │   │   │   │       └─► retorna: true ✓ (puede emitir topic 2)
    │   │   │   │
    │   │   │   ├─► IdentityCloneable(0xDEF).claimExists(2, 0x123...)
    │   │   │   │       └─► retorna: false ❌ (no tiene claim de 0x123)
    │   │   │   │
    │   │   ├─► Issuer 0x456... (amlProvider):
    │   │   │   │
    │   │   │   ├─► TrustedIssuersRegistry.hasClaimTopic(0x456..., 2)
    │   │   │   │       └─► retorna: true ✓ (puede emitir topic 2)
    │   │   │   │
    │   │   │   ├─► IdentityCloneable(0xDEF).claimExists(2, 0x456...)
    │   │   │   │       └─► retorna: true ✓ (claim existe)
    │   │   │   │
    │   │   │   └─► ✅ CLAIM VÁLIDO ENCONTRADO (break loop)
    │   │   │
    │   └─► hasValidClaim = true ✅
    │
    └─► TODOS LOS TOPICS VERIFICADOS ✅
        TRANSFER PERMITIDO 🎉
```

## 🔐 Capas de Seguridad

### 1. **Trusted Issuer Registry** (Quién puede emitir)
```solidity
// Solo el admin del Token puede agregar/remover trusted issuers
trustedIssuersRegistry.addTrustedIssuer(issuer, topics);
```

### 2. **Scope de Topics** (Qué puede emitir cada issuer)
```solidity
// KYC Provider solo puede emitir [1, 2]
// NO puede emitir topic 3 (Accredited Investor)
trustedIssuersRegistry.hasClaimTopic(kycProvider, 3) // → false
```

### 3. **Identity Ownership** (Quién puede agregar claims)
```solidity
// Solo el owner de la Identity puede agregar claims
IdentityCloneable.addClaim(...) // → onlyOwner
```

### 4. **Doble Verificación** (Issuer + Claim)
```solidity
// Verifica AMBOS:
1. ¿El issuer es trusted Y puede emitir este topic?
2. ¿El claim existe en la identity del inversor?
```

## 🚨 Casos de Ataque Prevenidos

### Ataque 1: Issuer No Confiable
```solidity
// ❌ Atacante intenta emitir claim desde su propia address
address attacker = 0x999...;
identity.addClaim(1, 1, attacker, sig, data, "");

// ✅ BLOQUEADO: attacker no está en TrustedIssuersRegistry
trustedIssuersRegistry.isTrustedIssuer(attacker) // → false
```

### Ataque 2: Issuer Fuera de Scope
```solidity
// ❌ AML Provider intenta emitir claim de Accredited Investor
identity.addClaim(3, 1, amlProvider, sig, data, "");

// ✅ BLOQUEADO: amlProvider no puede emitir topic 3
trustedIssuersRegistry.hasClaimTopic(amlProvider, 3) // → false
```

### Ataque 3: Claim Falso
```solidity
// ❌ Usuario agrega claim de issuer que no lo emitió realmente
identity.addClaim(1, 1, kycProvider, fakeSig, fakeData, "");

// ✅ DETECTADO: 
// - La signature puede verificarse off-chain
// - El URI puede consultarse para validación
// - El issuer puede revocar claims
```

### Ataque 4: Suplantación de Identity
```solidity
// ❌ Usuario intenta usar Identity de otro
token.transfer(victim, 100);

// ✅ BLOQUEADO: IdentityRegistry vincula wallet→identity
// El Token consulta la identity registrada para msg.sender
// No puede usar la identity de otro
```

## 📊 Diagrama de Actores

```
┌─────────────────────────────────────────────────────────────┐
│                    ACTORES DEL SISTEMA                      │
└─────────────────────────────────────────────────────────────┘

TOKEN ADMIN (Owner del Token)
│
├─► Controla: TrustedIssuersRegistry
│   ├─► Agrega/Remueve trusted issuers
│   └─► Define qué topics puede emitir cada issuer
│
├─► Controla: ClaimTopicsRegistry (del token)
│   └─► Define qué topics son requeridos
│
└─► Controla: IdentityRegistry
    └─► Registra wallet → identity


TRUSTED ISSUERS (KYC Providers)
│
├─► NO controlan el registry (no pueden auto-agregarse)
│
├─► Verifican inversores off-chain
│
└─► Emiten claims que se agregan a Identities
    └─► El inversor (owner de su Identity) agrega el claim


INVERSOR (Usuario Final)
│
├─► Controla: Su propia Identity
│   ├─► Puede agregar claims (firmados por issuers)
│   └─► Puede remover claims
│
└─► Interactúa: Con el Token
    ├─► Transfer solo funciona si tiene claims válidos
    └─► De trusted issuers en los topics requeridos
```

## 🔄 Flujo Temporal

```
TIEMPO →

T0: Setup
    ├─► Deploy TrustedIssuersRegistry
    └─► Admin agrega KYC/AML providers

T1: Onboarding Inversor
    ├─► Inversor crea cuenta en KYC provider
    ├─► KYC provider verifica (off-chain)
    └─► KYC provider firma claim

T2: Claim Issuance
    ├─► Inversor crea Identity
    ├─► Inversor agrega claim a su Identity
    └─► IdentityRegistry.registerIdentity(wallet, identity)

T3: Trading
    ├─► Inversor intenta transfer
    ├─► Token verifica trusted issuer
    └─► Transfer ejecutado o rechazado

T4: Renovación (ej: cada año)
    ├─► KYC provider re-verifica inversor
    ├─► Se actualiza claim o se emite nuevo
    └─► Inversor continúa trading

T5: Revocación (si es necesario)
    ├─► Admin remueve trusted issuer, o
    ├─► Inversor remueve claim, o
    ├─► Admin remueve identity del registry
    └─► Inversor NO puede transferir
```

## 💡 Mejores Prácticas

### ✅ DO

1. **Segregar responsabilidades**
   ```solidity
   // Un issuer para KYC, otro para AML, otro para Accreditation
   addTrustedIssuer(kycProvider, [1]);
   addTrustedIssuer(amlProvider, [2]);
   addTrustedIssuer(accreditationProvider, [3]);
   ```

2. **Limitar scope de cada issuer**
   ```solidity
   // Solo dar los topics que realmente puede verificar
   addTrustedIssuer(kycProvider, [1]); // NO [1,2,3,4,5]
   ```

3. **Auditar cambios**
   ```solidity
   // Los eventos permiten tracking on-chain
   event TrustedIssuerAdded(address issuer, uint256[] topics);
   event TrustedIssuerRemoved(address issuer);
   ```

4. **Verificación off-chain**
   ```solidity
   // Además de on-chain, verificar signatures y URIs
   claim.signature → verificar firma ECDSA
   claim.uri → consultar endpoint para validación adicional
   ```

### ❌ DON'T

1. **No agregar issuers no auditados**
   ```solidity
   // ❌ Mal: agregar cualquier address
   addTrustedIssuer(randomAddress, [1,2,3]);
   
   // ✅ Bien: solo issuers verificados y con due diligence
   addTrustedIssuer(onboardedKycProvider, [1]);
   ```

2. **No dar demasiados permisos**
   ```solidity
   // ❌ Mal: un issuer con todos los topics
   addTrustedIssuer(provider, [1,2,3,4,5,6,7,8,9]);
   
   // ✅ Bien: permisos específicos
   addTrustedIssuer(provider, [1]); // Solo KYC
   ```

3. **No olvidar actualizar cuando expiren**
   ```solidity
   // Implementar lógica para claims con expiración
   // O proceso manual de renovación
   ```

## 🎯 Resumen

**La verificación de Trusted Issuer es un sistema de tres capas:**

1. **Whitelist** - Solo issuers aprobados en TrustedIssuersRegistry
2. **Scope** - Cada issuer solo puede emitir topics específicos  
3. **Validación** - El Token verifica que el claim existe y viene de un issuer válido

**Esto garantiza que:**
- ✅ Solo claims de fuentes confiables son aceptados
- ✅ Cada issuer está limitado a su área de expertise
- ✅ Los inversores no pueden falsificar claims
- ✅ El sistema es auditable y transparente

