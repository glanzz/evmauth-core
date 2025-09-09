# EVMAuth Deployment Scripts

Deploy upgradeable `EVMAuth1155` and `EVMAuth6909` contracts using Foundry.

## Prerequisites

- [Foundry](https://getfoundry.sh) installed
- RPC URLs configured in `foundry.toml` for target networks
- Private key or wallet configuration for deployment

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

**NOTE:** It is STRONGLY [recommended to use a hardware wallet or password protected key store](https://getfoundry.sh/guides/best-practices/key-management/) for production deployments.

### Using Anvil

To run your own Ethereum node locally for testing, you can use [Anvil](https://getfoundry.sh/anvil/overview):

```sh
anvil
```

Or, you can specify a network to fork from:

```sh
anvil --fork-url sepolia  # or `radius-testnet`, `base-sepolia`, or any RPC URL
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
forge script script/DeployExample.s.sol:DeployExample1155 \
  --rpc-url radius-testnet \
  --private-key $PRIVATE_KEY \
  --broadcast
```

You can write your own script with custom initialization parameters by extending `BaseDeploy1155`, as illustrated in `DeployExample.s.sol`.

### Deploy EVMAuth6909

To deploy the `EVMAuth6909` contract ([ERC-6909]) using the example script, run:

```sh
forge script script/DeployExample.s.sol:DeployExample6909 \
  --rpc-url radius-testnet \
  --private-key $PRIVATE_KEY \
  --broadcast
```

You can write your own script with custom initialization parameters by extending `BaseDeploy6909`, as illustrated in `DeployExample.s.sol`.

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

# Cast Command Cheat Sheet

## Decode Return Values

To decode the return value of any call, use this pattern:

```sh
cast decode-abi "f()(bool)" $(cast call $PROXY "myFunc()" --rpc-url $RPC)
```

...where `f()(bool)` is the function signature with return types, and `myFunc()` is the function being called.

You need to include parameter types and call data if the function takes parameters:

```sh
cast decode-abi "f(uint256)(bytes32)" $(cast call $PROXY "myFunc(uint256)" 42 --rpc-url $RPC)
```

In the example above, `42` is the parameter being passed to `myFunc` and `bytes32` is the return type, which is decoded by `cast decode-abi`.

## Send ETH

```sh
cast send $TO_ADDRESS --value 1ether --private-key $PRIVATE_KEY --rpc-url radius-testnet
```

For Radius Testnet, you can use the `--gas-price 0` flag to avoid needing enough value to cover gas fees.

## Check ETH Balance

```sh
cast balance $ADDRESS --rpc-url radius-testnet
```

## EVMAuth View Functions (Read-Only)

### Role Constants

```sh
cast call $PROXY "DEFAULT_ADMIN_ROLE()" --rpc-url $RPC
cast call $PROXY "MINTER_ROLE()" --rpc-url $RPC
cast call $PROXY "BURNER_ROLE()" --rpc-url $RPC
cast call $PROXY "TOKEN_MANAGER_ROLE()" --rpc-url $RPC
cast call $PROXY "ACCESS_MANAGER_ROLE()" --rpc-url $RPC
cast call $PROXY "TREASURER_ROLE()" --rpc-url $RPC
cast call $PROXY "UPGRADE_MANAGER_ROLE()" --rpc-url $RPC
cast call $PROXY "ACCOUNT_FROZEN_STATUS()" --rpc-url $RPC
cast call $PROXY "ACCOUNT_UNFROZEN_STATUS()" --rpc-url $RPC
```

### Token Info

```sh
cast call $PROXY "exists(uint256)" $TOKEN_ID --rpc-url $RPC
cast call $PROXY "name(uint256)" $TOKEN_ID --rpc-url $RPC
cast call $PROXY "symbol(uint256)" $TOKEN_ID --rpc-url $RPC
cast call $PROXY "decimals(uint256)" $TOKEN_ID --rpc-url $RPC
cast call $PROXY "tokenURI(uint256)" $TOKEN_ID --rpc-url $RPC
cast call $PROXY "nextTokenID()" --rpc-url $RPC
```

### Balances

```sh
cast call $PROXY "balanceOf(address,uint256)" $ADDRESS $TOKEN_ID --rpc-url $RPC
cast call $PROXY "balanceRecordsOf(address,uint256)" $ADDRESS 1 --rpc-url $RPC
```

### Token Config

```sh
cast call $PROXY "tokenConfig(uint256)" $TOKEN_ID --rpc-url $RPC
cast call $PROXY "tokenPrice(uint256)" $TOKEN_ID --rpc-url $RPC
cast call $PROXY "tokenTTL(uint256)" $TOKEN_ID --rpc-url $RPC
cast call $PROXY "isTransferable(uint256)" $TOKEN_ID --rpc-url $RPC

# ERC20 pricing
cast call $PROXY "tokenERC20Prices(uint256)" $TOKEN_ID --rpc-url $RPC
cast call $PROXY "isAcceptedERC20PaymentToken(uint256,address)" $TOKEN_ID $ERC20_ADDRESS --rpc-url $RPC
```

### Access control

```sh
cast call $PROXY "hasRole(bytes32,address)" $ROLE_HASH $ADDRESS --rpc-url $RPC
cast call $PROXY "getRoleAdmin(bytes32)" $ROLE_HASH --rpc-url $RPC
cast call $PROXY "defaultAdmin()" --rpc-url $RPC
cast call $PROXY "defaultAdminDelay()" --rpc-url $RPC
cast call $PROXY "defaultAdminDelayIncreaseWait()" --rpc-url $RPC
cast call $PROXY "pendingDefaultAdmin()" --rpc-url $RPC
cast call $PROXY "pendingDefaultAdminDelay()" --rpc-url $RPC
cast call $PROXY "isFrozen(address)" $ADDRESS --rpc-url $RPC
cast call $PROXY "frozenAccounts()" --rpc-url $RPC
```

### Contract info

```sh
cast call $PROXY "owner()" --rpc-url $RPC
cast call $PROXY "treasury()" --rpc-url $RPC
cast call $PROXY "contractURI()" --rpc-url $RPC
cast call $PROXY "paused()" --rpc-url $RPC
```

### Approvals

EVMAuth6909 ([ERC-6909]) only:

```sh
cast call $PROXY "allowance(address,address,uint256)" $OWNER_ADDRESS $SPENDER_ADDRESS $TOKEN_ID --rpc-url $RPC
cast call $PROXY "isOperator(address,address)" $OWNER_ADDRESS $SPENDER_ADDRESS --rpc-url $RPC
```

## EVMAuth State-Changing Functions (Require Private Key)

### Token Management

These operations require the `TOKEN_MANAGER_ROLE`.

```sh
# Create new token — costs 1 ETH, has no ERC20 payment tokens, a TTL of 1 day, and is transferable
cast send $PROXY "createToken((uint256,(address,uint256)[],uint256,bool))" \
  "(1000000000000000000, [], 86400, true)" \
  --rpc-url $RPC --private-key $PRIVATE_KEY

# Update token config — costs 0 ETH, adds an ERC20 payment token, sets a TTL of 2 days, and makes it non-transferable
cast send $PROXY "updateToken(uint256,(uint256,(address,uint256)[],uint256,bool))" \
  1 "(0, [(0x036CbD53842c5426634e7929541eC2318f3dCF7e, 1000000)], 172800, true)" \
  --rpc-url $RPC --private-key $PRIVATE_KEY

# [ERC-6909] Set token metadata
cast send $PROXY "setTokenMetadata(uint256,string,string,uint8)" \
  $TOKEN_ID $TOKEN_NAME $TOKEN_SYMBOL $TOKEN_DECIMALS \
  --rpc-url $RPC --private-key $PRIVATE_KEY

# Set token URI
cast send $PROXY "setTokenURI(uint256,string)" \
  $TOKEN_ID $TOKEN_URI \
  --rpc-url $RPC --private-key $PRIVATE_KEY
```

### Minting & Burning

These operations require either the `MINTER_ROLE` or `BURNER_ROLE`.

```sh
cast send $PROXY "mint(address,uint256,uint256)" \
  $TO_ADDRESS $TOKEN_ID $TOKEN_AMOUNT \
  --rpc-url $RPC --private-key $PRIVATE_KEY

cast send $PROXY "burn(address,uint256,uint256)" \
  $FROM_ADDRESS $TOKEN_ID $TOKEN_AMOUNT \
  --rpc-url $RPC --private-key $PRIVATE_KEY
```

### Purchasing Tokens

```sh
# Purchase with ETH
cast send $PROXY "purchase(uint256,uint256)" \
  $TOKEN_ID $TOKEN_AMOUNT \
  --value 0.1ether \
  --rpc-url $RPC --private-key $PRIVATE_KEY

cast send $PROXY "purchaseFor(address,uint256,uint256)" \
  $TO_ADDRESS $TOKEN_ID $TOKEN_AMOUNT \
  --value 0.1ether \
  --rpc-url $RPC --private-key $PRIVATE_KEY

# Purchase with ERC20
cast send $PROXY "purchaseWithERC20(address,uint256,uint256)" \
  $ERC20_ADDRESS $TOKEN_ID $TOKEN_AMOUNT \
  --rpc-url $RPC --private-key $PRIVATE_KEY

cast send $PROXY "purchaseWithERC20For(address,address,uint256,uint256)" \
  $TO_ADDRESS $ERC20_ADDRESS $TOKEN_ID $TOKEN_AMOUNT \
  --rpc-url $RPC --private-key $PRIVATE_KEY
```

### Transfers & Approvals

Transfers can only be performed if the token type is transferable; call `tokenConfig(id)` to confirm.

```sh
cast send $PROXY "transfer(address,uint256,uint256)" \
  $TO_ADDRESS $TOKEN_ID $TOKEN_AMOUNT \
  --rpc-url $RPC --private-key $PRIVATE_KEY

cast send $PROXY "transferFrom(address,address,uint256,uint256)" \
  $FROM_ADDRESS $TO_ADDRESS $TOKEN_ID $TOKEN_AMOUNT \
  --rpc-url $RPC --private-key $PRIVATE_KEY

# [ERC-6909] Approve allowance for spender
cast send $PROXY "approve(address,uint256,uint256)" \
  $SPENDER_ADDRESS $TOKEN_ID $TOKEN_ALLOWANCE \
  --rpc-url $RPC --private-key $PRIVATE_KEY

# [ERC-6909] Set or unset operator to allow spending all tokens on behalf of owner
cast send $PROXY "setOperator(address,bool)" \
  $OPERATOR_ADDRESS true \
  --rpc-url $RPC --private-key $PRIVATE_KEY
```

### Access Control

These operations require the `DEFAULT_ADMIN_ROLE`.

```sh
cast send $PROXY "grantRole(bytes32,address)" \
  $ROLE_HASH $TO_ADDRESS \
  --rpc-url $RPC --private-key $PRIVATE_KEY

cast send $PROXY "revokeRole(bytes32,address)" \
  $ROLE_HASH $TO_ADDRESS \
  --rpc-url $RPC --private-key $PRIVATE_KEY

cast send $PROXY "renounceRole(bytes32,address)" \
  $ROLE_HASH $TO_ADDRESS \
  --rpc-url $RPC --private-key $PRIVATE_KEY
```

### Admin Transfer

These operations require the `DEFAULT_ADMIN_ROLE`.

```sh
cast send $PROXY "beginDefaultAdminTransfer(address)" \
  $TO_ADDRESS \
  --rpc-url $RPC --private-key $PRIVATE_KEY

# This can only be called after a configurable delay period
cast send $PROXY "acceptDefaultAdminTransfer()" \
  --rpc-url $RPC --private-key $PRIVATE_KEY

cast send $PROXY "cancelDefaultAdminTransfer()" \
  --rpc-url $RPC --private-key $PRIVATE_KEY

# This does not take effect until after the previously configured delay period
cast send $PROXY "changeDefaultAdminDelay(uint48)" \
  86400 \
  --rpc-url $RPC --private-key $PRIVATE_KEY

cast send $PROXY "rollbackDefaultAdminDelay()" \
  --rpc-url $RPC --private-key $PRIVATE_KEY
```

### Account Management

These operations require the `ACCESS_MANAGER_ROLE`.

```sh
cast send $PROXY "freezeAccount(address)" \
  0xAccountToFreeze \
  --rpc-url $RPC --private-key $PRIVATE_KEY

cast send $PROXY "unfreezeAccount(address)" \
  0xAccountToUnfreeze \
  --rpc-url $RPC --private-key $PRIVATE_KEY
```

### Treasury Management

These operations require the `TREASURER_ROLE`.

```sh
cast send $PROXY "setTreasury(address)" \
  $NEW_TREASURY_ADDRESS \
  --rpc-url $RPC --private-key $PRIVATE_KEY
```

### Contract Settings

```sh
# [ERC-6909] Set contract metadata URI
cast send $PROXY "setContractURI(string)" \
  "https://..." \
  --rpc-url $RPC --private-key $PRIVATE_KEY
```

### Maintenance

```sh
# Pruning happens automatically during minting, burning, and transferring,
# but can be manually triggered if needed.
cast send $PROXY "pruneBalanceRecords(address,uint256)" \
  $ADDRESS $TOKEN_ID \
  --rpc-url $RPC --private-key $PRIVATE_KEY
```

[ERC-1155]: https://eips.ethereum.org/EIPS/eip-1155
[ERC-6909]: https://eips.ethereum.org/EIPS/eip-6909
