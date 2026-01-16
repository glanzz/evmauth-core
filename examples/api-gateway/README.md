# EVMAuth API Gateway - Reference Implementation

A production-ready API gateway demonstrating blockchain-based access control using EVMAuth tokens.

> **Note**: For production applications, consider using the official [evmauth-ts SDK](https://github.com/evmauth/evmauth-ts) which provides type-safe contract interactions and framework integrations.

> **See Also**: [MCP Server Implementation](https://github.com/rahulmurugan/protected-coingecko-mcp-demo) for AI agent token gating with Claude Desktop.

## Overview

This API gateway replaces traditional OAuth/API key infrastructure with on-chain token ownership verification. Users authenticate by proving they own specific EVMAuth tokens in their wallet.

## Architecture

```
Client Request → API Gateway → EVMAuth Contract (RPC) → Access Decision
     ↓               ↓                   ↓
   Wallet       Middleware           balanceOf()
   Address      Verification         Active Balance
```

## Features

- ✅ **Zero Database**: No session storage, user tables, or API keys
- ✅ **Sub-100ms Verification**: Direct RPC calls to Base Sepolia
- ✅ **Automatic Expiration**: TTL handled by smart contract
- ✅ **Instant Revocation**: Account freezing via ACCESS_MANAGER_ROLE
- ✅ **Secondary Markets**: Transferable tokens enable marketplace
- ✅ **Multi-tier Access**: Different tokens for different API tiers

## Installation

```bash
cd examples/api-gateway
npm install
cp .env.example .env
# Edit .env with your configuration
```

## Configuration

Edit `.env`:

```bash
# Network
RPC_URL=https://sepolia.base.org
CHAIN_ID=84532

# Contract (use deployed testnet addresses)
EVMAUTH1155_ADDRESS=0x67b8dD172f50784F6eaffe27d4f79360e44367eC
EVMAUTH_IMPLEMENTATION=1155

# Access Control
REQUIRED_TOKEN_ID=1  # Basic API Access (0.001 ETH, 7 days)

# Server
PORT=3000
```

## Usage

### Start Server

```bash
npm start
```

### Test with Client

```bash
# In another terminal
npm test
```

## API Endpoints

### Public Endpoints (No Authentication)

#### `GET /api/v1/public/health`
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "service": "EVMAuth API Gateway",
  "network": { "chainId": "84532", "contract": "0x67..." }
}
```

#### `GET /api/v1/public/info`
API information and usage instructions.

### Protected Endpoints (Requires EVMAuth Token)

#### `GET /api/v1/protected/data`
Access protected data (requires token ownership).

**Headers:**
```
X-Wallet-Address: 0x5849888...
```

**Response (Success):**
```json
{
  "message": "Access granted!",
  "accessedBy": "0x5849888...",
  "tokenId": 1,
  "balance": "1",
  "verificationTime": "45ms",
  "data": { ... }
}
```

**Response (Denied):**
```json
{
  "error": "Forbidden",
  "message": "No valid token 1 found for this address",
  "verificationTime": "42ms"
}
```

## Testing Scenarios

The test client (`test-client.js`) demonstrates:

1. ✅ **Public Access**: Anyone can access `/public/*` endpoints
2. ✅ **Token Required**: `/protected/*` requires valid token
3. ✅ **Access Denied**: Requests without tokens are rejected
4. ✅ **Latency Measurement**: Verification typically < 100ms

## Performance Metrics

Based on testnet deployment:

| Metric | Value |
|--------|-------|
| **Verification Latency** | 40-80ms (avg: ~60ms) |
| **RPC Call** | 1 per request (`getActiveBalance`) |
| **Infrastructure** | Single Node.js process |
| **Database** | None required |
| **Scalability** | Stateless (horizontal scaling) |

## Comparison with OAuth

| Feature | EVMAuth | OAuth 2.0 |
|---------|---------|-----------|
| **Infrastructure** | 1 RPC endpoint | Auth server + DB + Session store |
| **Verification** | 1 RPC call (~60ms) | DB query + Session lookup |
| **Revocation** | Instant (on-chain) | Requires token blacklist |
| **Expiration** | Automatic (TTL) | Manual refresh token flow |
| **Cost** | RPC calls only | Server hosting + DB + Maintenance |
| **Secondary Market** | Yes (transferable tokens) | No |

## Production Considerations

### Security

- **Rate Limiting**: Add rate limits per wallet address
- **Signature Verification**: Require signed messages to prove ownership
- **HTTPS**: Always use TLS in production
- **CORS**: Configure allowed origins

### Performance

- **RPC Caching**: Cache `balanceOf` results (30-60s TTL)
- **Load Balancing**: Deploy multiple instances
- **RPC Redundancy**: Use fallback RPC providers

### Monitoring

- Track verification latency (alert if > 200ms)
- Monitor RPC provider uptime
- Log failed verification attempts

## Integration Guide

### 1. Add EVMAuth Middleware to Your API

```javascript
import { ethers } from 'ethers';

async function verifyEVMAuth(req, res, next) {
  const wallet = req.headers['x-wallet-address'];
  const balance = await contract.getActiveBalance(wallet, tokenId);

  if (balance > 0n) {
    req.user = { wallet, balance };
    next();
  } else {
    res.status(403).json({ error: 'No valid token' });
  }
}

app.get('/api/protected', verifyEVMAuth, handler);
```

### 2. Client Integration

```javascript
// User purchases token via EVMAuth contract
await evmauth.purchase(tokenId, amount, { value: price });

// Access API with wallet address
fetch('/api/protected', {
  headers: {
    'X-Wallet-Address': userWallet
  }
});
```

## Real-World Use Cases

1. **AI Agent API Access**: Non-transferable tokens prevent sharing
2. **Premium Features**: Tiered access (Basic, Premium, Enterprise)
3. **Time-Limited Access**: Automatic expiration via TTL
4. **B2B Partnerships**: Transfer enterprise licenses
5. **Pay-Per-Use**: Credits that don't expire (Token ID 5)

## License

MIT
