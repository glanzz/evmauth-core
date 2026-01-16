#!/bin/bash
set -e

# Load environment variables
export PRIVATE_KEY=$(grep "^PRIVATE_KEY=" .env | cut -d= -f2 | tr -d '[:space:]')
export BASE_SEPOLIA=$(grep "^BASE_SEPOLIA=" .env | cut -d= -f2 | tr -d '[:space:]')

echo "=== EVMAuth Gas Measurement Script ==="
echo "Network: Base Sepolia"
echo "Measuring gas costs for both EVMAuth1155 and EVMAuth6909"
echo ""

# Run gas measurement
~/.foundry/bin/forge script script/MeasureGasCosts.s.sol:MeasureGasCosts \
  --rpc-url "$BASE_SEPOLIA" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  --legacy \
  -vv

echo ""
echo "Gas measurement complete!"
echo "Results have been printed above and saved to broadcast logs"
