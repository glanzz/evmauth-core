# EVMAuth Deployment Scripts

Deploy upgradeable `EVMAuth1155` and `EVMAuth6909` contracts using Foundry.

## Prerequisites

- [Foundry](https://getfoundry.sh) installed
- RPC URLs configured in `foundry.toml` for target networks
- Private key or wallet configuration for deployment

## Quick Start

### Configure Environment

**NOTE:** It is STRONGLY [recommended to use a hardware wallet or password protected key store](https://getfoundry.sh/guides/best-practices/key-management/) for deployments used in production.

Copy the example environment file:

```sh
cp .env.example .env
```

Edit `.env` to set your private key and other parameters, then load it:

```sh
source .env
```

### Using Anvil

To run your own Ethereum node locally, you can use [Anvil](https://getfoundry.sh/anvil/overview):

```sh
anvil
```

Or, you can specify a network to fork from:

```sh
anvil --fork-url sepolia  # or `radius-testnet`, `base-sepolia`, or any RPC URL
```

Then you can specify `--rpc-url localhost` in the deployment commands below.

**NOTE:** Be sure to use the private key of a funded account from Anvil for deployment in your `.env` file.

### Deploy EVMAuth1155

```sh
forge script script/DeployEVMAuth.s.sol:DeployEVMAuth1155 \
  --rpc-url radius-testnet \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Deploy EVMAuth6909
```sh
forge script script/DeployEVMAuth.s.sol:DeployEVMAuth6909 \
  --rpc-url radius-testnet \
  --private-key $PRIVATE_KEY \
  --broadcast
```

## Environment Variables

Configure deployment parameters via environment variables:

| Variable                | Description                               | Default      |
|-------------------------|-------------------------------------------|--------------|
| `DEFAULT_ADMIN_ADDRESS` | Initial admin address with upgrade rights | `msg.sender` |
| `TREASURY_ADDRESS`      | Address to receive payment revenues       | `msg.sender` |
| `TOKEN_URI`             | Base URI for ERC-1155 token metadata      | `""` (empty) |
| `CONTRACT_URI`          | Contract metadata URI for ERC-6909        | `""` (empty) |

### Example with Custom Configuration
```sh
forge script script/DeployEVMAuth.s.sol:DeployEVMAuth1155 \
  --rpc-url radius-testnet \
  --private-key $PRIVATE_KEY \
  --broadcast
```

## Multi-Network Deployment

Deploy to multiple networks in a single transaction:

```sh
forge script script/DeployEVMAuth.s.sol:DeployMultiNetwork \
  --rpc-url radius-testnet \
  --private-key $PRIVATE_KEY \
  --broadcast
```

The `DeployMultiNetwork` script deploys to Radius Testnet and Base Sepolia `networks`, as configured in the `_setUpNetworks` method. You can modify that method, or create a script that inherits `DeployMultiNetwork` and overrides `_setUpNetworks`.

**Note:** When running `DeployMultiNetwork`, you must set either `ERC_1155=true` or `ERC_6909=true` (not both).

## Contract Architecture

All deployment scripts extend `BaseDeployEVMAuth` which:

- Deploys UUPS upgradeable proxies via OpenZeppelin
- Validates deployment parameters
- Provides hooks for post-deployment setup
- Sets a 2-day admin transfer delay for security

## Deployment Output

Each deployment logs:

- Proxy contract address
- Default admin address
- Treasury address
- Metadata URI (if configured)

Save these addresses for contract interaction and future upgrades.

## Troubleshooting

**"Invalid admin/treasury address"**: Ensure addresses are not zero addresses.

**"Either ERC_1155 or ERC_6909 env var must be set"**: Set exactly one of these to `true` for multi-network deployment.

**Compilation errors**: Run `forge build` to check for issues before deployment.
