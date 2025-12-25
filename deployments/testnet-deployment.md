# EVMAuth Testnet Deployment

**Network**: Base Sepolia (Chain ID: 84532)
**Deployment Date**: December 25, 2024
**Deployer**: 0x58498884EDF3f56E0CA94285908Bd2578D7CDbFe

## EVMAuth1155 Deployment

### Contract Addresses

- **Proxy Address**: [`0x67b8dD172f50784F6eaffe27d4f79360e44367eC`](https://sepolia.basescan.org/address/0x67b8dd172f50784f6eaffe27d4f79360e44367ec)
- **Implementation Address**: [`0x4c911fBD6fAB8d36F0693295022083281116509D`](https://sepolia.basescan.org/address/0x4c911fbd6fab8d36f0693295022083281116509d)

### Deployment Transaction

- **Transaction Hash**: `0x...` (see broadcast log)
- **Gas Used**: 7,535,132 gas
- **Gas Cost**: 0.000126 ETH (~$0.38 USD)
- **Status**: ✅ Verified on Basescan

### Configuration

- **Admin Delay**: 2 days (172,800 seconds)
- **Default Admin**: 0x58498884EDF3f56E0CA94285908Bd2578D7CDbFe
- **Treasury**: 0x58498884EDF3f56E0CA94285908Bd2578D7CDbFe

### Role Grants

All roles granted to deployer address:

| Role | Bytes32 Value | Granted To |
|------|--------------|------------|
| DEFAULT_ADMIN_ROLE | `0x0000...0000` | 0x58498884EDF3f56E0CA94285908Bd2578D7CDbFe |
| UPGRADE_MANAGER_ROLE | `0xa76ace73...fda726db5` | 0x58498884EDF3f56E0CA94285908Bd2578D7CDbFe |
| ACCESS_MANAGER_ROLE | `0x46f3eccdd88...261c9208` | 0x58498884EDF3f56E0CA94285908Bd2578D7CDbFe |
| TOKEN_MANAGER_ROLE | `0x74f7a545...59ddc6d06` | 0x58498884EDF3f56E0CA94285908Bd2578D7CDbFe |
| MINTER_ROLE | `0x9f2df0fed...c8956a6` | 0x58498884EDF3f56E0CA94285908Bd2578D7CDbFe |
| BURNER_ROLE | `0x3c11d16cb...0576a848` | 0x58498884EDF3f56E0CA94285908Bd2578D7CDbFe |
| TREASURER_ROLE | `0x3496e2e73...b86425d07` | 0x58498884EDF3f56E0CA94285908Bd2578D7CDbFe |

---

## EVMAuth6909 Deployment

### Contract Addresses

- **Proxy Address**: [`0x8B00e86C73128e4Ccc3CAB2D63F74aaA58937539`](https://sepolia.basescan.org/address/0x8b00e86c73128e4ccc3cab2d63f74aaa58937539)
- **Implementation Address**: [`0x279F599E8589A443B1BAd561f567d53733122DA5`](https://sepolia.basescan.org/address/0x279f599e8589a443b1bad561f567d53733122da5)

### Deployment Transaction

- **Transaction Hash**: `0x...` (see broadcast log)
- **Gas Used**: 6,892,914 gas
- **Gas Cost**: 0.000120 ETH (~$0.36 USD)
- **Status**: ✅ Verified on Basescan

### Configuration

- **Admin Delay**: 2 days (172,800 seconds)
- **Default Admin**: 0x58498884EDF3f56E0CA94285908Bd2578D7CDbFe
- **Treasury**: 0x58498884EDF3f56E0CA94285908Bd2578D7CDbFe

### Role Grants

All roles granted to deployer address (same as EVMAuth1155).

---

## Sample Token Types Configuration

The following 5 token types demonstrate different EVMAuth use cases:

### Token ID 1: Basic API Access
- **Price**: 0.001 ETH (~$3 USD)
- **TTL**: 7 days
- **Transferable**: No
- **Use Case**: Entry-level API access, non-transferable subscription

### Token ID 2: Premium API Access
- **Price**: 0.005 ETH (~$15 USD)
- **TTL**: 30 days
- **Transferable**: Yes
- **Use Case**: Premium tier with secondary market capability

### Token ID 3: AI Agent License
- **Price**: 0.01 ETH (~$30 USD)
- **TTL**: 90 days
- **Transferable**: No
- **Use Case**: AI agent authentication, prevents unauthorized redistribution

### Token ID 4: Enterprise Tier
- **Price**: 0.05 ETH (~$150 USD)
- **TTL**: 365 days (1 year)
- **Transferable**: Yes
- **Use Case**: Long-term enterprise access with transferability

### Token ID 5: Developer Credits
- **Price**: 0.0001 ETH (~$0.30 USD per credit)
- **TTL**: Unlimited (0 = no expiration)
- **Transferable**: Yes
- **Use Case**: Pay-per-use credits that don't expire

> **Note**: Token configuration script is available at `script/ConfigureTokens.s.sol`.
> Run with: `./configure-tokens.sh` (requires TOKEN_MANAGER_ROLE)

---

## Deployment Summary

| Metric | EVMAuth1155 | EVMAuth6909 | Difference |
|--------|-------------|-------------|------------|
| **Deployment Gas** | 7,535,132 | 6,892,914 | -642,218 (-8.5%) |
| **Contract Size** | 24,516 bytes | 22,247 bytes | -2,269 bytes |
| **Size Margin** | 60 bytes | 2,329 bytes | +2,269 bytes |
| **Verification** | ✅ Pass | ✅ Pass | - |

**Total Deployment Cost**: 0.000246 ETH (~$0.74 USD)

---

## Post-Deployment Testing

- [x] Both contracts deployed successfully
- [x] Both contracts verified on Basescan
- [x] Proxy pattern working (UUPS upgradeable)
- [x] All roles granted correctly
- [ ] Token creation tested
- [ ] Purchase flow tested
- [ ] Transfer restrictions verified
- [ ] TTL expiration tested
- [ ] Balance enumeration tested

---

## Network Information

**Base Sepolia Testnet**:
- RPC URL: https://sepolia.base.org
- Chain ID: 84532
- Block Explorer: https://sepolia.basescan.org
- Faucet: https://faucet.quicknode.com/base/sepolia

---

## Useful Commands

### Check Balances
```bash
# Check EVMAuth1155 balance
cast call 0x67b8dD172f50784F6eaffe27d4f79360e44367eC \
  "balanceOf(address,uint256)" <ADDRESS> <TOKEN_ID> \
  --rpc-url https://sepolia.base.org

# Check EVMAuth6909 balance
cast call 0x8B00e86C73128e4Ccc3CAB2D63F74aaA58937539 \
  "balanceOf(address,uint256)" <ADDRESS> <TOKEN_ID> \
  --rpc-url https://sepolia.base.org
```

### Purchase Tokens
```bash
# Purchase from EVMAuth1155 (requires TOKEN_MANAGER_ROLE to create token first)
cast send 0x67b8dD172f50784F6eaffe27d4f79360e44367eC \
  "purchase(uint256,uint256)" <TOKEN_ID> <AMOUNT> \
  --value 0.001ether \
  --private-key $PRIVATE_KEY \
  --rpc-url https://sepolia.base.org
```

### View Token Configuration
```bash
# Get token config from EVMAuth1155
cast call 0x67b8dD172f50784F6eaffe27d4f79360e44367eC \
  "getTokenConfig(uint256)" <TOKEN_ID> \
  --rpc-url https://sepolia.base.org
```

---

## Next Steps

1. ✅ Deploy both contracts
2. ✅ Verify on Basescan
3. ⏳ Configure sample token types
4. ⏳ Test token purchase flow
5. ⏳ Test transfer restrictions
6. ⏳ Test TTL expiration
7. ⏳ Update paper with testnet results
