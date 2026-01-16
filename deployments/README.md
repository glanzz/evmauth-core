# Deployment Records

This directory contains records of contract deployments across different networks.

## Structure

- `testnet-deployment.md` - Base Sepolia and Ethereum Sepolia testnet deployments
- `mainnet-deployment.md` - Production deployments (when ready)

## Purpose

Deployment records serve as:

1. **Reference**: Quick lookup of deployed contract addresses
2. **Audit Trail**: Historical record of all deployments
3. **Documentation**: Context for each deployment (date, parameters, purpose)
4. **Recovery**: Information needed to interact with or upgrade contracts

## Template

Each deployment record should include:

- Deployment date and time
- Network details (name, chain ID, RPC URL)
- Deployer address
- Contract addresses (proxy and implementation)
- Transaction hashes
- Block numbers
- Etherscan/block explorer links
- Configuration parameters (admin delay, roles, treasury)
- Gas costs
- Verification status

See `../TESTNET_DEPLOYMENT.md` for detailed deployment instructions.
