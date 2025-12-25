# Testnet Deployment Summary for Paper

## Deployment Details (Base Sepolia)

**Date**: December 25, 2024
**Network**: Base Sepolia (Chain ID: 84532)
**Deployer**: 0x58498884EDF3f56E0CA94285908Bd2578D7CDbFe

### EVMAuth1155
- **Proxy**: [0x67b8dD172f50784F6eaffe27d4f79360e44367eC](https://sepolia.basescan.org/address/0x67b8dd172f50784f6eaffe27d4f79360e44367ec)
- **Implementation**: [0x4c911fBD6fAB8d36F0693295022083281116509D](https://sepolia.basescan.org/address/0x4c911fbd6fab8d36f0693295022083281116509d)
- **Gas**: 7,535,132 (0.000126 ETH)

### EVMAuth6909
- **Proxy**: [0x8B00e86C73128e4Ccc3CAB2D63F74aaA58937539](https://sepolia.basescan.org/address/0x8b00e86c73128e4ccc3cab2d63f74aaa58937539)
- **Implementation**: [0x279F599E8589A443B1BAd561f567d53733122DA5](https://sepolia.basescan.org/address/0x279f599e8589a443b1bad561f567d53733122da5)
- **Gas**: 6,892,914 (0.000120 ETH)

## Key Findings for Paper

### Deployment Gas Costs
- **EVMAuth1155**: 7.5M gas
- **EVMAuth6909**: 6.9M gas
- **Difference**: 642K gas (8.5% lower for 6909)

### Contract Sizes
- **EVMAuth1155**: 24,516 bytes (60 bytes margin)
- **EVMAuth6909**: 22,247 bytes (2,329 bytes margin)

### Verification
- Both contracts successfully verified on Basescan
- Proxy pattern (UUPS) working correctly
- All 7 roles configured and granted

### Sample Token Configurations
Demonstrated 5 real-world use cases:
1. Basic API Access: 0.001 ETH, 7 days, non-transferable
2. Premium API Access: 0.005 ETH, 30 days, transferable
3. AI Agent License: 0.01 ETH, 90 days, non-transferable
4. Enterprise Tier: 0.05 ETH, 365 days, transferable
5. Developer Credits: 0.0001 ETH, unlimited, transferable

## Paper Updates Needed

### Section 4.4 (Deployment Considerations)
- ✅ Add actual deployment gas costs from testnet
- ✅ Confirm contract sizes match compiled artifacts
- ✅ Update with verification status

### Section 5 (Evaluation)
- Add testnet deployment as real-world validation
- Include Base Sepolia network information
- Reference verified contracts on Basescan

### Section 6 (Discussion)
- Mention successful multi-network deployment capability
- Highlight verification success on block explorer

### Abstract
- Update "deploy to Base testnet" → "deployed and verified on Base Sepolia testnet"
