# Cast Command Cheat Sheet

This is a reference guide for using `cast` commands with a deployed EVMAuth contract. Replace the placeholder variables (e.g., `$PROXY`, `$RPC`, `$PRIVATE_KEY`, etc.) with your actual values, or set them as environment variables.

**NOTE:** It is STRONGLY [recommended to use a hardware wallet or password protected key store](https://getfoundry.sh/guides/best-practices/key-management/) for private keys.

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
cast send $TO_ADDRESS --value 1ether --private-key $PRIVATE_KEY --rpc-url $RPC
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
