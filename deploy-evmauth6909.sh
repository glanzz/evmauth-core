#!/bin/bash
set -e

# Load environment variables
export PRIVATE_KEY=$(grep "^PRIVATE_KEY=" .env | cut -d= -f2 | tr -d '[:space:]')
export BASE_SEPOLIA=$(grep "^BASE_SEPOLIA=" .env | cut -d= -f2 | tr -d '[:space:]')
export ETHERSCAN_API_KEY=$(grep "^ETHERSCAN_API_KEY=" .env | cut -d= -f2 | tr -d '[:space:]')

echo "=== EVMAuth6909 Deployment Script ==="
echo "Network: Base Sepolia"
echo "RPC: $BASE_SEPOLIA"
echo ""

# Deploy EVMAuth6909
echo "Deploying EVMAuth6909..."
~/.foundry/bin/forge script script/ExampleDeploy.s.sol:Deploy6909 \
  --rpc-url "$BASE_SEPOLIA" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  --verify \
  --etherscan-api-key "$ETHERSCAN_API_KEY" \
  -vvv

echo ""
echo "Deployment complete! Check deployments/deploy-6909-log.txt for details."
