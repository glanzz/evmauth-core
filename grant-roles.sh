#!/bin/bash
set -e

# Load environment variables
export PRIVATE_KEY=$(grep "^PRIVATE_KEY=" .env | cut -d= -f2 | tr -d '[:space:]')
export BASE_SEPOLIA=$(grep "^BASE_SEPOLIA=" .env | cut -d= -f2 | tr -d '[:space:]')

echo "=== Grant Measurement Roles Script ==="
echo "Network: Base Sepolia"
echo ""

# Grant roles
~/.foundry/bin/forge script script/GrantMeasurementRoles.s.sol:GrantMeasurementRoles \
  --rpc-url "$BASE_SEPOLIA" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  --legacy \
  -vv

echo ""
echo "Role grants complete!"
