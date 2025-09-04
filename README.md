# EVMAuth Core

![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/evmauth/evmauth-core/test.yml?label=Tests)
![GitHub Repo stars](https://img.shields.io/github/stars/evmauth/evmauth-core)

## Overview

EVMAuth is an authorization state management system for token-gating, built on top of [ERC-1155] and [ERC-6909] token standards.

A detailed overview of the contract architecture can be found here: [EVMAuth Contract Architecture](src/README.md).

### Deployment

EVMAuth can be deployed on any EVM-compatible network (e.g. Ethereum, Base, Radius) using the scripts provided in the `scripts/` directory.

When deploying the contract, you will need to specify the following parameters:

- Initial [transfer delay] for the default admin role
- Initial default admin address, [for role management]
- Initial treasury address, for receiving revenue from direct purchases
- Base token metadata URI ([for ERC-1155]) or contract URI ([for ERC-6909]) (optional, can be updated later)

### Access Control

Once you've deployed the contract, the default admin will need to grant various access roles:

- `grantRole(TOKEN_MANAGER_ROLE, address)` for accounts that can configure tokens and token metadata
- `grantRole(ACCESS_MANAGER_ROLE, address)` for accounts that can pause/unpause the contract and freeze accounts
- `grantRole(TREASURER_ROLE, address)` for accounts that can modify the treasury address where funds are collected
- `grantRole(MINTER_ROLE, address)`for accounts that can issue tokens to addresses
- `grantRole(BURNER_ROLE, address)`for accounts that can deduct tokens from addresses

### Token Configuration

An account with the `TOKEN_MANAGER_ROLE` should then create one or more new tokens by calling `createToken` with the desired configuration:

- `uint256 price`: The cost to purchase one unit of the token; 0 means the token cannot be purchased directly; set to `0` to disable native currency purchases
- `PaymentToken[] erc20Prices`: Array of `PaymentToken` structs, each containing ERC-20 `token` address and `price`; pass an empty array to disable ERC-20 token purchases
- `uint256 ttl`: Time-to-live in seconds; 0 means the token never expires; set to 0 for non-expiring tokens
- `bool transferable`: Whether the token can be transferred between accounts

An account with the `TOKEN_MANAGER_ROLE` can modify an existing token by calling `updateToken(id, EVMAuthTokenConfig)`, or any of the individual property setter functions:

- `setTokenPrice(id, uint256 price)`
- `setERC20Price(uint256 id, address token, uint256 price)`
- `setTokenERC20Prices(id, PaymentToken[] erc20Prices)`
- `setTokenTTL(id, uint256 ttl)`
- `setTokenTransferable(id, bool transferable)`

## Token Standards

### ERC-1155 vs ERC-6909

| Feature                | ERC-1155                                                                     | ERC-6909                                                                    |
|------------------------|------------------------------------------------------------------------------|-----------------------------------------------------------------------------|
| Callbacks              | Required for each transfer to contract accounts; must return specific values | Removed entirely; no callbacks required                                     |
| Batch Operations       | Included in specification (batch transfers)                                  | Excluded from specification to allow custom implementations                 |
| Permission System      | Single operator scheme: operators get unlimited allowance on all token IDs   | Hybrid scheme: allowances for specific token IDs + operators for all tokens |
| Transfer Methods       | Both transferFrom and safeTransferFrom required; no opt-out for callbacks    | Simplified transfers without mandatory recipient validation                 |
| Transfer Semantics     | Safe transfers with data parameter and receiver hooks                        | Simple transfers without hooks                                              |
| Interface Complexity   | Includes multiple features (callbacks, batching, etc.)                       | Minimized to bare essentials for multi-token management                     |
| Recipient Requirements | Contract recipients must implement callback functions with return values     | No special requirements for contract recipients                             |
| Approval Granularity   | Operators only (all-or-nothing for entire contract)                          | Granular allowances per token ID + full operators                           |
| Metadata Handling      | URI-based metadata (typically off-chain JSON)                                | On-chain name/symbol/decimals per token ID                                  |
| Supply Tracking        | Global `totalSupply()` plus per-token supply                                 | Only per-token `totalSupply(id)`                                            |

### When to Choose Which

Choose [ERC-1155] when you:
- Need NFT marketplace compatibility
- Batch operations are important
- Want receiver hook notifications
- Prefer URI-based metadata

Choose [ERC-6909] when you:
- Need ERC-20-like semantics per token
- Want granular approval control
- Need on-chain token metadata
- Prefer a simpler token transfer model

## Key Architectural Decisions

1. **Upgradability**: All contracts use the Universal Upgradeable Proxy Standard ([UUPS]) pattern for future improvements

2. **Security**:
   - Role-based access control with time-delayed admin transfers
   - Pausable operations for emergency situations
   - Account freezing capabilities
   - Reentrancy protection on purchase functions

3. **Gas Optimization**:
   - TTL implementation uses bounded arrays and time buckets for balance records
   - Automatic pruning of expired records, with manual pruning methods available
   - Efficient storage patterns for token properties, as defined in [ERC-7201]

4. **Flexibility**:
   - Alternative purchase options (native and/or ERC-20 tokens)
   - Configurable token properties (price, TTL, transferability)
   - Support for both [ERC-1155] and [ERC-6909] token standards

## SDKs & Libraries

EVMAuth provides the following SDKs and libraries for easy integration with applications and frameworks:

- [TypeScript SDK](https://github.com/evmauth/evmauth-ts)
- Python SDK (coming soon)

## Contributing

To contribute to this open source project, please follow the guidelines in the [CONTRIBUTING.md](CONTRIBUTING.md) file.

## License

The **EVMAuth** contract is released under the MIT License. See the [LICENSE](LICENSE) file for details.

[ERC-1155]: https://eips.ethereum.org/EIPS/eip-1155
[ERC-6909]: https://eips.ethereum.org/EIPS/eip-6909
