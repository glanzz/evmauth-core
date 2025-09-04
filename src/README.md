# EVMAuth Contract Architecture

### Overview

The EVMAuth contract system is designed with a modular, composable architecture that separates concerns into focused base contracts. This approach provides flexibility while maintaining a clean inheritance structure.

The architecture consists of:

- **Base Contracts**: Modular components that handle specific functionality (e.g. access control, purchasing, token expiry)
- **Base EVMAuth Contract**: Combines all base contracts into a unified authorization state management system
- **Token Standard Implementations**: `EVMAuth1155` and `EVMAuth6909` extend `EVMAuth` with their respective token standards

### Base Contracts Hierarchy

```mermaid
classDiagram
    class TokenAccessControl {
        <<abstract>>
        +UPGRADE_MANAGER_ROLE
        +ACCESS_MANAGER_ROLE
        +TOKEN_MANAGER_ROLE
        +MINTER_ROLE
        +BURNER_ROLE
        +TREASURER_ROLE
        +freezeAccount(account)
        +unfreezeAccount(account)
        <<inherited from Pausable>>
        +pause()
        +unpause()
        +paused()
        <<inherited from AccessControl>>
        +hasRole(role, account)
        +grantRole(role, account)
        +revokeRole(role, account)
        +renounceRole(role, account)
    }
    
    class AccountFreezable {
        <<abstract>>
        -frozenAccounts mapping
        +isFrozen(address)
        +frozenAccounts()
        #_freezeAccount(address)
        #_unfreezeAccount(address)
    }
    
    class TokenEnumerable {
        <<abstract>>
        -nextTokenId
        -tokenExists mapping
        +nextTokenID()
        +isValid(id)
        #_claimNextTokenID()
    }
    
    class TokenTransferable {
        <<abstract>>
        -transferable mapping
        +isTransferable(id)
        #_setTransferable(id, bool)
    }
    
    class TokenEphemeral {
        <<abstract>>
        -ttl mapping
        -balanceRecords mapping
        +balanceOf(account, id)
        +tokenTTL(id)
        +balanceRecordsOf(account, id)
        +pruneBalanceRecords(account, id)
        #_setTTL(id, ttl)
    }
    
    class TokenPurchasable {
        <<abstract>>
        -treasury address
        -prices mapping
        -erc20Prices mapping
        +treasury()
        +tokenPrice(id)
        +tokenERC20Price(id, token)
        +tokenERC20Prices(id)
        +isAcceptedERC20PaymentToken(id, token)
        +purchase(id, amount)
        +purchaseFor(receiver, id, amount)
        +purchaseWithERC20(token, id, amount)
        +purchaseWithERC20For(receiver, token, id, amount)
        #_setPrice(id, price)
        #_setERC20Price(id, token, price)
        #_setERC20Prices(id, prices[])
        #_mintPurchasedTokens(to, id, amount)
    }
    
    class EVMAuth {
        <<abstract>>
        +EVMAuthTokenConfig struct
        +createToken(config)
        +updateToken(id, config)
        +tokenConfig(id)
        +tokenConfigs(ids[])
        +setPrice(id, price)
        +setERC20Price(id, token, price)
        +setERC20Prices(id, prices[])
        +setTTL(id, ttl)
        +setTransferable(id, bool)
        #_authorizeUpgrade(newImplementation)
    }
    
    AccessControlDefaultAdminRulesUpgradeable <|-- TokenAccessControl
    PausableUpgradeable <|-- TokenAccessControl
    AccountFreezable <|-- TokenAccessControl
    TokenAccessControl <|-- EVMAuth
    TokenEnumerable <|-- EVMAuth
    TokenTransferable <|-- EVMAuth
    TokenEphemeral <|-- EVMAuth
    TokenPurchasable <|-- EVMAuth
    UUPSUpgradeable <|-- EVMAuth
```

### EVMAuth1155 Implementation

```mermaid
classDiagram
    class EVMAuth {
        <<abstract>>
        +createToken(config)
        +updateToken(id, config)
        +tokenConfig(id)
        +tokenConfigs(ids[])
        +setPrice(id, price)
        +setERC20Price(id, token, price)
        +setERC20Prices(id, prices[])
        +setTTL(id, ttl)
        +setTransferable(id, bool)
        +tokenPrice(id)
        +tokenERC20Price(id, token)
        +tokenERC20Prices(id)
        +tokenTTL(id)
        +isTransferable(id)
        +purchase(id, amount)
        +purchaseWithERC20(token, id, amount)
        +freezeAccount(account)
        +unfreezeAccount(account)
    }
    
    class ERC1155Upgradeable {
        +balanceOf(account, id)
        +balanceOfBatch(accounts[], ids[])
        +setApprovalForAll(operator, approved)
        +isApprovedForAll(account, operator)
        +safeTransferFrom(from, to, id, amount, data)
        +safeBatchTransferFrom(from, to, ids[], amounts[], data)
    }
    
    class ERC1155SupplyUpgradeable {
        +totalSupply(id)
        +totalSupply()
        +exists(id)
    }
    
    class ERC1155URIStorageUpgradeable {
        +uri(id)
        #_setURI(id, uri)
        #_setBaseURI(baseURI)
    }
    
    class EVMAuth1155 {
        +initialize(delay, admin, treasury, uri)
        +mint(to, id, amount, data)
        +mintBatch(to, ids[], amounts[], data)
        +burn(from, id, amount)
        +burnBatch(from, ids[], amounts[])
        +setBaseURI(uri)
        +setTokenURI(id, uri)
        +purchaseFor(recipient, id, amount)
        +purchaseWithERC20For(token, recipient, id, amount)
        +balanceRecordsOf(account, id)
        +pruneBalanceRecords(account, id)
        +isValid(account, id)
        +supportsInterface(interfaceId)
        #_update(from, to, ids[], amounts[])
        #_mintPurchasedTokens(to, id, amount)
    }
    
    ERC1155Upgradeable <|-- ERC1155SupplyUpgradeable
    ERC1155Upgradeable <|-- ERC1155URIStorageUpgradeable
    ERC1155SupplyUpgradeable <|-- EVMAuth1155
    ERC1155URIStorageUpgradeable <|-- EVMAuth1155
    EVMAuth <|-- EVMAuth1155
```

### EVMAuth6909 Implementation

```mermaid
classDiagram
    class EVMAuth {
        <<abstract>>
        +createToken(config)
        +updateToken(id, config)
        +tokenConfig(id)
        +tokenConfigs(ids[])
        +setPrice(id, price)
        +setERC20Price(id, token, price)
        +setERC20Prices(id, prices[])
        +setTTL(id, ttl)
        +setTransferable(id, bool)
        +tokenPrice(id)
        +tokenERC20Price(id, token)
        +tokenERC20Prices(id)
        +tokenTTL(id)
        +isTransferable(id)
        +purchase(id, amount)
        +purchaseWithERC20(token, id, amount)
        +freezeAccount(account)
        +unfreezeAccount(account)
    }
    
    class ERC6909Upgradeable {
        +balanceOf(account, id)
        +allowance(owner, spender, id)
        +isOperator(owner, spender)
        +transfer(to, id, amount)
        +transferFrom(from, to, id, amount)
        +approve(spender, id, amount)
        +setOperator(operator, approved)
    }
    
    class ERC6909TokenSupplyUpgradeable {
        +totalSupply(id)
    }
    
    class ERC6909MetadataUpgradeable {
        +name(id)
        +symbol(id)
        +decimals(id)
        #_setTokenMetadata(id, name, symbol, decimals)
    }
    
    class ERC6909ContentURIUpgradeable {
        +contractURI()
        +tokenURI(id)
        #_setContractURI(uri)
        #_setTokenURI(id, uri)
    }
    
    class EVMAuth6909 {
        +initialize(delay, admin, treasury, uri)
        +mint(to, id, amount)
        +burn(from, id, amount)
        +setContractURI(uri)
        +setTokenURI(id, uri)
        +setTokenMetadata(id, name, symbol, decimals)
        +purchaseFor(recipient, id, amount)
        +purchaseWithERC20For(token, recipient, id, amount)
        +balanceRecordsOf(account, id)
        +pruneBalanceRecords(account, id)
        +isValid(account, id)
        +supportsInterface(interfaceId)
        #_update(from, to, id, amount)
        #_mintPurchasedTokens(to, id, amount)
    }
    
    ERC6909Upgradeable <|-- ERC6909TokenSupplyUpgradeable
    ERC6909Upgradeable <|-- ERC6909MetadataUpgradeable
    ERC6909Upgradeable <|-- ERC6909ContentURIUpgradeable
    ERC6909TokenSupplyUpgradeable <|-- EVMAuth6909
    ERC6909MetadataUpgradeable <|-- EVMAuth6909
    ERC6909ContentURIUpgradeable <|-- EVMAuth6909
    EVMAuth <|-- EVMAuth6909
```

### Base Contract Descriptions

#### TokenAccessControl
Provides role-based access control with six distinct roles, pausable functionality, and account freezing capabilities. Extends OpenZeppelin's AccessControlDefaultAdminRulesUpgradeable for secure admin transfer with time delays.

#### AccountFreezable
Enables freezing and unfreezing of individual accounts, preventing them from transferring or receiving tokens. Maintains a list of frozen accounts for transparency.

#### TokenEnumerable
Manages token ID generation and tracks which token IDs have been created. Provides a sequential ID system starting from 1.

#### TokenTransferable
Controls whether individual token types can be transferred between accounts. Each token ID can be configured as transferable or non-transferable.

#### TokenEphemeral
Implements time-to-live (TTL) functionality for tokens. Tokens with a TTL expire after the specified duration, with automatic pruning of expired balance records. Uses an efficient time-bucket system for gas optimization.

#### TokenPurchasable
Handles direct token purchases with both native currency and ERC-20 tokens. Supports per-token pricing in multiple currencies, with revenue sent to a configurable treasury address. Includes reentrancy protection for secure purchases.

#### EVMAuth
The main abstract contract that combines all base functionality and provides a unified interface for token configuration. Defines the EVMAuthTokenConfig structure that encapsulates price, ERC-20 prices, TTL, and transferability settings for each token type.

[ERC-1155]: https://eips.ethereum.org/EIPS/eip-1155
[ERC-6909]: https://eips.ethereum.org/EIPS/eip-6909
[ERC-7201]: https://eips.ethereum.org/EIPS/eip-7201
[for ERC-1155]: https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions
[for ERC-6909]: https://eips.ethereum.org/EIPS/eip-6909#content-uri-extension
[for role management]: https://docs.openzeppelin.com/contracts/5.x/api/access#AccessControlDefaultAdminRules
[transfer delay]: https://docs.openzeppelin.com/contracts/5.x/api/access#AccessControlDefaultAdminRules-defaultAdminDelay--
[UUPS]: https://docs.openzeppelin.com/contracts-stylus/0.3.0-rc.1/uups-proxy
