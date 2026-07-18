#!/bin/bash

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
RPC_URL="https://besu1.proyectos.codecrypto.academy"
KEYS_FILE="$HOME/.foundry/keys.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SC_DIR="$SCRIPT_DIR/sc"

echo -e "${BLUE}🚀 RWA Smart Contracts - Deployment a Besu${NC}"
echo "=========================================="
echo ""

# Verificar que jq está instalado
if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ jq no está instalado${NC}"
    echo "Por favor instala jq: brew install jq"
    exit 1
fi

# Verificar que el archivo de keys existe
if [ ! -f "$KEYS_FILE" ]; then
    echo -e "${RED}❌ No se encuentra el archivo de keys: $KEYS_FILE${NC}"
    exit 1
fi

# Extraer la clave privada
echo -e "${YELLOW}📝 Extrayendo clave privada...${NC}"
PRIVATE_KEY=$(cat "$KEYS_FILE" | jq -r ".accounts[0].private_key")

if [ -z "$PRIVATE_KEY" ] || [ "$PRIVATE_KEY" == "null" ]; then
    echo -e "${RED}❌ No se pudo extraer la clave privada del archivo${NC}"
    exit 1
fi

# Extraer la dirección de la cuenta
ACCOUNT_ADDRESS=$(cat "$KEYS_FILE" | jq -r ".accounts[0].address")
echo -e "${GREEN}✓ Clave privada extraída${NC}"
echo -e "  Dirección: $ACCOUNT_ADDRESS"
echo ""

# Verificar que forge está instalado
if ! command -v forge &> /dev/null; then
    echo -e "${RED}❌ Forge no está instalado${NC}"
    echo "Por favor instala Foundry: https://book.getfoundry.sh/getting-started/installation"
    exit 1
fi

# Cambiar al directorio de contratos
cd "$SC_DIR"

# Verificar conexión con la red
echo -e "${YELLOW}📡 Verificando conexión con Besu...${NC}"
if ! curl -s -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    "$RPC_URL" > /dev/null 2>&1; then
    echo -e "${RED}❌ No se puede conectar a $RPC_URL${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Conexión establecida${NC}"
echo ""

# Compilar contratos
echo -e "${YELLOW}🔨 Compilando contratos...${NC}"
forge build --silent
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error compilando contratos${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Contratos compilados${NC}"
echo ""

# Desplegar TokenCloneFactory
echo -e "${YELLOW}📦 Paso 1: Desplegando TokenCloneFactory...${NC}"
TOKEN_FACTORY_OUTPUT=$(forge script script/DeployTokenCloneFactory.s.sol:DeployTokenCloneFactory \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vv 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error desplegando TokenCloneFactory${NC}"
    echo "$TOKEN_FACTORY_OUTPUT"
    exit 1
fi

TOKEN_FACTORY_ADDRESS=$(echo "$TOKEN_FACTORY_OUTPUT" | grep "TokenCloneFactory deployed at:" | grep -oE '0x[a-fA-F0-9]{40}' | head -1)
if [ -z "$TOKEN_FACTORY_ADDRESS" ]; then
    # Intentar extraer de otra forma si no se encuentra
    TOKEN_FACTORY_ADDRESS=$(echo "$TOKEN_FACTORY_OUTPUT" | grep -oE 'Contract Address: 0x[a-fA-F0-9]{40}' | grep -oE '0x[a-fA-F0-9]{40}' | head -1)
fi
if [ -z "$TOKEN_FACTORY_ADDRESS" ]; then
    echo -e "${RED}❌ No se pudo extraer la dirección de TokenCloneFactory${NC}"
    exit 1
fi
echo -e "${GREEN}✓ TokenCloneFactory desplegado${NC}"
echo "  Dirección: $TOKEN_FACTORY_ADDRESS"
echo ""

# Desplegar IdentityCloneFactory
echo -e "${YELLOW}📦 Paso 2: Desplegando IdentityCloneFactory...${NC}"
export PRIVATE_KEY="$PRIVATE_KEY"
IDENTITY_FACTORY_OUTPUT=$(forge script script/DeployIdentityCloneFactory.s.sol:DeployIdentityCloneFactory \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vv 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error desplegando IdentityCloneFactory${NC}"
    echo "$IDENTITY_FACTORY_OUTPUT"
    exit 1
fi

IDENTITY_FACTORY_ADDRESS=$(echo "$IDENTITY_FACTORY_OUTPUT" | grep "IdentityCloneFactory deployed at:" | grep -oE '0x[a-fA-F0-9]{40}' | head -1)
if [ -z "$IDENTITY_FACTORY_ADDRESS" ]; then
    # Intentar extraer de otra forma si no se encuentra
    IDENTITY_FACTORY_ADDRESS=$(echo "$IDENTITY_FACTORY_OUTPUT" | grep -oE 'Contract Address: 0x[a-fA-F0-9]{40}' | grep -oE '0x[a-fA-F0-9]{40}' | head -1)
fi
if [ -z "$IDENTITY_FACTORY_ADDRESS" ]; then
    echo -e "${RED}❌ No se pudo extraer la dirección de IdentityCloneFactory${NC}"
    exit 1
fi
echo -e "${GREEN}✓ IdentityCloneFactory desplegado${NC}"
echo "  Dirección: $IDENTITY_FACTORY_ADDRESS"
echo ""

# Desplegar ClaimTopicsRegistryCloneFactory
echo -e "${YELLOW}📦 Paso 3: Desplegando ClaimTopicsRegistryCloneFactory...${NC}"
export DEPLOYER_ADDRESS="$ACCOUNT_ADDRESS"
CLAIM_TOPICS_OUTPUT=$(forge script script/DeployClaimTopicsRegistryCloneFactory.s.sol:DeployClaimTopicsRegistryCloneFactory \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vv 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error desplegando ClaimTopicsRegistryCloneFactory${NC}"
    echo "$CLAIM_TOPICS_OUTPUT"
    exit 1
fi

CLAIM_TOPICS_ADDRESS=$(echo "$CLAIM_TOPICS_OUTPUT" | grep "ClaimTopicsRegistryCloneFactory deployed at:" | grep -oE '0x[a-fA-F0-9]{40}' | head -1)
if [ -z "$CLAIM_TOPICS_ADDRESS" ]; then
    # Intentar extraer de otra forma si no se encuentra
    CLAIM_TOPICS_ADDRESS=$(echo "$CLAIM_TOPICS_OUTPUT" | grep -oE 'Contract Address: 0x[a-fA-F0-9]{40}' | grep -oE '0x[a-fA-F0-9]{40}' | tail -1)
fi
if [ -z "$CLAIM_TOPICS_ADDRESS" ]; then
    echo -e "${RED}❌ No se pudo extraer la dirección de ClaimTopicsRegistryCloneFactory${NC}"
    exit 1
fi
echo -e "${GREEN}✓ ClaimTopicsRegistryCloneFactory desplegado${NC}"
echo "  Dirección: $CLAIM_TOPICS_ADDRESS"
echo ""

# Desplegar ComplianceAggregator
echo -e "${YELLOW}📦 Paso 4: Desplegando ComplianceAggregator...${NC}"
COMPLIANCE_OUTPUT=$(forge script script/DeployComplianceAggregator.s.sol:DeployComplianceAggregator \
    --rpc-url "$RPC_URL" \
    --broadcast \
    --private-key "$PRIVATE_KEY" \
    -vv 2>&1)

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Error desplegando ComplianceAggregator${NC}"
    echo "$COMPLIANCE_OUTPUT"
    exit 1
fi

COMPLIANCE_ADDRESS=$(echo "$COMPLIANCE_OUTPUT" | grep "ComplianceAggregator deployed at:" | grep -oE '0x[a-fA-F0-9]{40}' | head -1)
if [ -z "$COMPLIANCE_ADDRESS" ]; then
    # Intentar extraer de otra forma si no se encuentra
    COMPLIANCE_ADDRESS=$(echo "$COMPLIANCE_OUTPUT" | grep -oE 'Contract Address: 0x[a-fA-F0-9]{40}' | grep -oE '0x[a-fA-F0-9]{40}' | head -1)
fi
if [ -z "$COMPLIANCE_ADDRESS" ]; then
    echo -e "${RED}❌ No se pudo extraer la dirección de ComplianceAggregator${NC}"
    exit 1
fi
echo -e "${GREEN}✓ ComplianceAggregator desplegado${NC}"
echo "  Dirección: $COMPLIANCE_ADDRESS"
echo ""

# Resumen final
echo -e "${BLUE}==========================================${NC}"
echo -e "${GREEN}✅ Deployment completado exitosamente${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""
echo "Direcciones desplegadas:"
echo "  TokenCloneFactory:              $TOKEN_FACTORY_ADDRESS"
echo "  IdentityCloneFactory:           $IDENTITY_FACTORY_ADDRESS"
echo "  ClaimTopicsRegistryCloneFactory: $CLAIM_TOPICS_ADDRESS"
echo "  ComplianceAggregator:           $COMPLIANCE_ADDRESS"
echo ""
echo "Red: $RPC_URL"
echo "Cuenta: $ACCOUNT_ADDRESS"
echo ""

