# EVMAuth Deployment Scripts

Deploy upgradeable `EVMAuth1155` and `EVMAuth6909` contracts using Foundry.

## Prerequisites

- [Foundry](https://getfoundry.sh) >= v1.3 installed
- Private key or wallet configuration for deployment
- RPC URLs set as environment variables (see `.env.example`)

## Quick Start

### Configure Environment

Copy the example environment file:

```sh
cp .env.example .env
```

Edit `.env` to set your private key and other parameters, then load it:

```sh
source .env
```

**NOTE:** It is STRONGLY [recommended to use a hardware wallet or password protected key store](https://getfoundry.sh/guides/best-practices/key-management/) for private keys.

### Using Anvil

To run your own Ethereum node locally for testing, you can use [Anvil](https://getfoundry.sh/anvil/overview):

```sh
anvil
```

Or, you can specify a network to fork from:

```sh
anvil --fork-url https://ethereum-sepolia-rpc.publicnode.com  # or any RPC URL
```

Then you can specify `--rpc-url localhost` in the deployment commands below.

**NOTE:** Be sure to use the private key of a funded account in your `.env` file. There are 10 accounts listed when you start Anvil:

```text
                             _   _
                            (_) | |
      __ _   _ __   __   __  _  | |
     / _` | | '_ \  \ \ / / | | | |
    | (_| | | | | |  \ V /  | | | |
     \__,_| |_| |_|   \_/   |_| |_|

    0.3.0 (5a8bd89 2024-12-20T08:45:53.195623000Z)
    https://github.com/foundry-rs/foundry


Available Accounts
==================

(0) 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (10000.000000000000000000 ETH)
(1) 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 (10000.000000000000000000 ETH)
(2) 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC (10000.000000000000000000 ETH)
(3) 0x90F79bf6EB2c4f870365E785982E1f101E93b906 (10000.000000000000000000 ETH)
(4) 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65 (10000.000000000000000000 ETH)
(5) 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc (10000.000000000000000000 ETH)
(6) 0x976EA74026E726554dB657fA54763abd0C3a0aa9 (10000.000000000000000000 ETH)
(7) 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955 (10000.000000000000000000 ETH)
(8) 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f (10000.000000000000000000 ETH)
(9) 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720 (10000.000000000000000000 ETH)

Private Keys
==================

(0) 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
(1) 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
(2) 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
(3) 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
(4) 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a
(5) 0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba
(6) 0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e
(7) 0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356
(8) 0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97
(9) 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6
```

### Deploy EVMAuth1155

To deploy the `EVMAuth1155` contract ([ERC-1155]) using the example script, run:

```sh
forge script script/ExampleDeploy.s.sol:ExampleDeploy1155 \
  --rpc-url radius-testnet \
  --private-key $PRIVATE_KEY \
  --broadcast
```

You can write your own script with custom initialization parameters by extending `BaseDeploy1155`, as illustrated in `ExampleDeploy.s.sol`.

### Deploy EVMAuth6909

To deploy the `EVMAuth6909` contract ([ERC-6909]) using the example script, run:

```sh
forge script script/ExampleDeploy.s.sol:ExampleDeploy6909 \
  --rpc-url radius-testnet \
  --private-key $PRIVATE_KEY \
  --broadcast
```

You can write your own script with custom initialization parameters by extending `BaseDeploy6909`, as illustrated in `ExampleDeploy.s.sol`.

## Upgrades

Upgrading requires a deployed EVMAuth contract address, and the sender must have the `UPGRADE_MANAGER_ROLE`.

First, make sure you build the latest version:

```sh
forge fmt && forge clean && forge build
```

You should probably also run the tests, to be sure everything is working as expected:

```sh
forge test
```

Then, run the appropriate upgrade script for your contract.

### Upgrade EVMAuth1155

Replace `0xYourContractAddress` with your deployed contract address:

```sh
PROXY=0xYourContractAddress \
forge script script/UpgradeEVMAuth.s.sol:UpgradeEVMAuth1155 \
  --rpc-url radius-testnet \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### Upgrade EVMAuth6909

Replace `0xYourContractAddress` with your deployed contract address:

```sh
PROXY=0xYourContractAddress \
forge script script/UpgradeEVMAuth.s.sol:UpgradeEVMAuth6909 \
  --rpc-url radius-testnet \
  --private-key $PRIVATE_KEY \
  --broadcast
```

## Calling Functions

Use this [Cast Command Cheat Sheet] as a reference guide for `cast` commands to use with a deployed EVMAuth contract.

## Script Architecture

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
- Roles granted during initialization

Save these addresses for contract interaction and future upgrades.

## Troubleshooting

**"Invalid admin/treasury address"**: Ensure addresses are not zero addresses.

**Compilation errors**: Run `forge fmt && forge clean && forge build` to check for issues before deployment.

[Cast Command Cheat Sheet]: https://github.com/evmauth/evmauth-core/blob/main/CAST_COMMANDS.md
[ERC-1155]: https://eips.ethereum.org/EIPS/eip-1155
[ERC-6909]: https://eips.ethereum.org/EIPS/eip-6909
