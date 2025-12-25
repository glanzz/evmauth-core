# Testnet Deployment Record

> **Template**: Copy this file to `testnet-deployment.md` and fill in actual deployment details.

## Base Sepolia Deployment

### Deployment Information
- **Deployment Date**: YYYY-MM-DD HH:MM UTC
- **Deployer Address**: `0x...`
- **Network**: Base Sepolia
- **Chain ID**: 84532
- **RPC URL**: https://sepolia.base.org
- **Block Explorer**: https://sepolia.basescan.org

### EVMAuth1155 (ERC-1155 Implementation)

**Contract Addresses:**
- **Proxy Address**: `0x...` - [View on BaseScan](https://sepolia.basescan.org/address/0x...)
- **Implementation Address**: `0x...`

**Deployment Details:**
- **Block Number**: `#...`
- **Transaction Hash**: `0x...`
- **Gas Used**: `...`
- **Gas Price**: `... gwei`
- **Total Cost**: `... ETH`

**Verification:**
- **Status**: ✅ Verified / ❌ Not Verified
- **Verification Date**: YYYY-MM-DD

### EVMAuth6909 (ERC-6909 Implementation)

**Contract Addresses:**
- **Proxy Address**: `0x...` - [View on BaseScan](https://sepolia.basescan.org/address/0x...)
- **Implementation Address**: `0x...`

**Deployment Details:**
- **Block Number**: `#...`
- **Transaction Hash**: `0x...`
- **Gas Used**: `...`
- **Gas Price**: `... gwei`
- **Total Cost**: `... ETH`

**Verification:**
- **Status**: ✅ Verified / ❌ Not Verified
- **Verification Date**: YYYY-MM-DD

---

## Ethereum Sepolia Deployment

### Deployment Information
- **Deployment Date**: YYYY-MM-DD HH:MM UTC
- **Deployer Address**: `0x...`
- **Network**: Ethereum Sepolia
- **Chain ID**: 11155111
- **RPC URL**: https://ethereum-sepolia-rpc.publicnode.com
- **Block Explorer**: https://sepolia.etherscan.io

### EVMAuth1155 (ERC-1155 Implementation)

**Contract Addresses:**
- **Proxy Address**: `0x...` - [View on Etherscan](https://sepolia.etherscan.io/address/0x...)
- **Implementation Address**: `0x...`

**Deployment Details:**
- **Block Number**: `#...`
- **Transaction Hash**: `0x...`
- **Gas Used**: `...`
- **Gas Price**: `... gwei`
- **Total Cost**: `... ETH`

**Verification:**
- **Status**: ✅ Verified / ❌ Not Verified
- **Verification Date**: YYYY-MM-DD

### EVMAuth6909 (ERC-6909 Implementation)

**Contract Addresses:**
- **Proxy Address**: `0x...` - [View on Etherscan](https://sepolia.etherscan.io/address/0x...)
- **Implementation Address**: `0x...`

**Deployment Details:**
- **Block Number**: `#...`
- **Transaction Hash**: `0x...`
- **Gas Used**: `...`
- **Gas Price**: `... gwei`
- **Total Cost**: `... ETH`

**Verification:**
- **Status**: ✅ Verified / ❌ Not Verified
- **Verification Date**: YYYY-MM-DD

---

## Configuration Parameters

### Security Settings
- **Admin Transfer Delay**: 2 days (172800 seconds)
- **Default Admin**: `0x...`
- **Treasury**: `0x...`

### Role Grants
All roles initially granted to deployer address: `0x...`

- ✅ `DEFAULT_ADMIN_ROLE` (0x00)
- ✅ `UPGRADE_MANAGER_ROLE` (0xa76ace73a908083d89af9ff88e5b4f7cadb3591a80631063f68b695fda726db5)
- ✅ `ACCESS_MANAGER_ROLE` (0x46f3eccdd88dd62792ae8eed1be7b9b658477566c49fd85b0d08cf44261c9208)
- ✅ `TOKEN_MANAGER_ROLE` (0x74f7a545c65c11839a48d7453738b30c295408df2d944516167556759ddc6d06)
- ✅ `MINTER_ROLE` (0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6)
- ✅ `BURNER_ROLE` (0x3c11d16cbaffd01df69ce1c404f6340ee057498f5f00246190ea54220576a848)
- ✅ `TREASURER_ROLE` (0x3496e2e73c4d42b75d702e60d9e48102720b8691234415963a5a857b86425d07)

---

## Post-Deployment Testing

### Functional Tests
- [ ] Token creation successful
- [ ] Token purchase works (native currency)
- [ ] Token purchase works (ERC-20)
- [ ] Account freezing/unfreezing works
- [ ] Balance queries return correct values
- [ ] Ephemeral tokens expire correctly (if TTL > 0)
- [ ] Transfer control works (soulbound vs transferable)

### Security Tests
- [ ] Pause/unpause functionality verified
- [ ] Role-based access control enforced
- [ ] Upgrade mechanism tested
- [ ] Admin delay enforced

### Integration Tests
- [ ] RPC balance queries work from external services
- [ ] API gateway integration tested
- [ ] Event emission verified

---

## Known Issues / Notes

> Document any deployment issues, workarounds, or important observations

- None

---

## Next Steps

- [ ] Test API integration with deployed contracts
- [ ] Run benchmark suite
- [ ] Update paper with testnet results
- [ ] Prepare mainnet deployment plan
