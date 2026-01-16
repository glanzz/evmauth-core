#!/bin/bash
set -e

# Load environment variables
export PRIVATE_KEY=$(grep "^PRIVATE_KEY=" .env | cut -d= -f2 | tr -d '[:space:]')
export BASE_SEPOLIA=$(grep "^BASE_SEPOLIA=" .env | cut -d= -f2 | tr -d '[:space:]')
export ETHERSCAN_API_KEY=$(grep "^ETHERSCAN_API_KEY=" .env | cut -d= -f2 | tr -d '[:space:]')

echo "=== EVMAuth Deployment Script ==="
echo "Network: Base Sepolia"
echo "RPC: $BASE_SEPOLIA"
echo "Private Key Length: ${#PRIVATE_KEY}"
echo ""

# Deploy EVMAuth1155
echo "Deploying EVMAuth1155..."
~/.foundry/bin/forge script script/ExampleDeploy.s.sol:Deploy1155 \
  --rpc-url "$BASE_SEPOLIA" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  --verify \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  -vvv

echo ""
echo "Deployment complete! Check deployments/deploy-1155-log.txt for details."
