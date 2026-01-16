import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import { ethers } from 'ethers';
import { EVMAuth } from 'evmauth';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.join(__dirname, '.env') });

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Initialize provider and EVMAuth client
const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const contractAddress = process.env.EVMAUTH_IMPLEMENTATION === '6909'
  ? process.env.EVMAUTH6909_ADDRESS
  : process.env.EVMAUTH1155_ADDRESS;

// Initialize EVMAuth SDK client
const evmAuthClient = new EVMAuth(contractAddress, provider);

// EVMAuth verification middleware
async function verifyEVMAuth(req, res, next) {
  const startTime = Date.now();

  try {
    // Extract wallet address from header
    const walletAddress = req.headers['x-wallet-address'];

    if (!walletAddress) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'Missing X-Wallet-Address header'
      });
    }

    // Validate address format
    if (!ethers.isAddress(walletAddress)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Invalid wallet address format'
      });
    }

    const tokenId = parseInt(process.env.REQUIRED_TOKEN_ID || '1');

    // Check balance using EVMAuth SDK (handles TTL automatically)
    const balance = await evmAuthClient.balanceOf(walletAddress, tokenId);

    const verificationTime = Date.now() - startTime;

    if (balance > 0n) {
      // Access granted
      req.evmauth = {
        address: walletAddress,
        tokenId,
        balance: balance.toString(),
        verificationTime
      };

      console.log(`✓ Access granted: ${walletAddress} (balance: ${balance}, ${verificationTime}ms)`);
      next();
    } else {
      // Access denied
      console.log(`✗ Access denied: ${walletAddress} (balance: 0, ${verificationTime}ms)`);
      res.status(403).json({
        error: 'Forbidden',
        message: `No valid token ${tokenId} found for this address`,
        verificationTime
      });
    }
  } catch (error) {
    const verificationTime = Date.now() - startTime;
    console.error(`✗ Verification error (${verificationTime}ms):`, error.message);

    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to verify token ownership',
      verificationTime
    });
  }
}

// Public endpoints (no auth required)
app.get('/api/v1/public/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'EVMAuth API Gateway',
    timestamp: new Date().toISOString(),
    network: {
      chainId: process.env.CHAIN_ID,
      rpcUrl: process.env.RPC_URL,
      contract: contractAddress,
      implementation: process.env.EVMAUTH_IMPLEMENTATION
    }
  });
});

app.get('/api/v1/public/info', (req, res) => {
  res.json({
    message: 'EVMAuth API Gateway - Blockchain-based API Access Control',
    requiredToken: {
      id: parseInt(process.env.REQUIRED_TOKEN_ID || '1'),
      network: 'Base Sepolia',
      contract: contractAddress
    },
    usage: {
      authentication: 'Include X-Wallet-Address header with your wallet address',
      authorization: 'Must own the required token in your wallet'
    },
    endpoints: {
      public: ['/api/v1/public/health', '/api/v1/public/info'],
      protected: ['/api/v1/protected/data', '/api/v1/protected/premium']
    }
  });
});

// Protected endpoints (require EVMAuth token)
app.get('/api/v1/protected/data', verifyEVMAuth, (req, res) => {
  res.json({
    message: 'Access granted! This is protected data.',
    accessedBy: req.evmauth.address,
    tokenId: req.evmauth.tokenId,
    balance: req.evmauth.balance,
    verificationTime: `${req.evmauth.verificationTime}ms`,
    data: {
      apiVersion: '1.0.0',
      features: ['feature-1', 'feature-2', 'feature-3'],
      timestamp: new Date().toISOString()
    }
  });
});

app.get('/api/v1/protected/premium', verifyEVMAuth, (req, res) => {
  res.json({
    message: 'Premium data access granted',
    accessedBy: req.evmauth.address,
    data: {
      premiumFeatures: ['advanced-analytics', 'priority-support', 'custom-integrations'],
      quota: {
        dailyRequests: 10000,
        rateLimit: '100 req/min'
      },
      timestamp: new Date().toISOString()
    }
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: 'Endpoint does not exist',
    availableEndpoints: {
      public: ['/api/v1/public/health', '/api/v1/public/info'],
      protected: ['/api/v1/protected/data', '/api/v1/protected/premium']
    }
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`\n🚀 EVMAuth API Gateway running on port ${PORT}`);
  console.log(`📊 Network: ${process.env.CHAIN_ID === '84532' ? 'Base Sepolia' : 'Unknown'}`);
  console.log(`📝 Contract: ${contractAddress}`);
  console.log(`🔒 Required Token ID: ${process.env.REQUIRED_TOKEN_ID || '1'}`);
  console.log(`\nEndpoints:`);
  console.log(`  Public:    http://localhost:${PORT}/api/v1/public/health`);
  console.log(`  Protected: http://localhost:${PORT}/api/v1/protected/data`);
  console.log(`\nReady to accept requests!\n`);
});

export default app;
