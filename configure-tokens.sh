#!/bin/bash
set -e

# Load environment variables
export PRIVATE_KEY=$(grep "^PRIVATE_KEY=" .env | cut -d= -f2 | tr -d '[:space:]')
export BASE_SEPOLIA=$(grep "^BASE_SEPOLIA=" .env | cut -d= -f2 | tr -d '[:space:]')
export EVMAUTH1155_PROXY=$(grep "^EVMAUTH1155_PROXY=" .env | cut -d= -f2 | tr -d '[:space:]')
export EVMAUTH6909_PROXY=$(grep "^EVMAUTH6909_PROXY=" .env | cut -d= -f2 | tr -d '[:space:]')

echo "=== Token Configuration Script ==="
echo "Network: Base Sepolia"
echo "EVMAuth1155: $EVMAUTH1155_PROXY"
echo "EVMAuth6909: $EVMAUTH6909_PROXY"
echo ""

# Configure EVMAuth1155
echo "Configuring EVMAuth1155 tokens..."
~/.foundry/bin/forge script script/ConfigureTokens.s.sol:ConfigureTokens1155 \
  --rpc-url "$BASE_SEPOLIA" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  -vv

echo ""
echo "Configuring EVMAuth6909 tokens..."
~/.foundry/bin/forge script script/ConfigureTokens.s.sol:ConfigureTokens6909 \
  --rpc-url "$BASE_SEPOLIA" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  -vv

echo ""
echo "Token configuration complete!"
