import dotenv from 'dotenv';
import { ethers } from 'ethers';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.join(__dirname, '.env') });

const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
const contractAddress = process.env.EVMAUTH1155_ADDRESS;

console.log('DEBUG - Contract:', contractAddress);
console.log('DEBUG - RPC:', process.env.RPC_URL);

// EVMAuth contract ABI
const ABI = [
  "function balanceOf(address account, uint256 id) view returns (uint256)",
  "function purchase(uint256 tokenId, uint256 amount) payable",
  "function tokenConfigs(uint256) view returns (uint256 price, uint256 ttl, bool transferable, bool exists)"
];

const contract = new ethers.Contract(contractAddress, ABI, wallet);

async function main() {
  console.log('\n=== EVMAuth Token Purchase ===\n');
  console.log('Wallet:', wallet.address);
  console.log('Contract:', contractAddress);
  console.log('Network: Base Sepolia\n');

  try {
    const balance = await provider.getBalance(wallet.address);
    console.log('ETH Balance:', ethers.formatEther(balance), 'ETH\n');

    const tokenId = 1;
    const price = ethers.parseEther('0.001');

    console.log('Token ID:', tokenId, '(Basic API Access)');
    console.log('Price:', ethers.formatEther(price), 'ETH\n');

    const existingBalance = await contract.balanceOf(wallet.address, tokenId);
    console.log('Current token balance:', existingBalance.toString(), '\n');

    if (existingBalance > 0n) {
      console.log('Token already owned! Skipping purchase.\n');
    } else {
      console.log('Purchasing token...');
      const tx = await contract.purchase(tokenId, 1, { value: price });
      console.log('Transaction hash:', tx.hash);

      const receipt = await tx.wait();
      console.log('Confirmed in block', receipt.blockNumber);
      console.log('Gas used:', receipt.gasUsed.toString(), '\n');
    }

    const newBalance = await contract.balanceOf(wallet.address, tokenId);
    console.log('New token balance:', newBalance.toString());

    const tokenInfo = await contract.tokenConfigs(tokenId);
    console.log('\n=== Token Information ===');
    console.log('Price:', ethers.formatEther(tokenInfo.price), 'ETH');
    console.log('TTL:', tokenInfo.ttl.toString(), 'seconds');
    console.log('Transferable:', tokenInfo.transferable);
    console.log('\nReady to test API with wallet:', wallet.address, '\n');

  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

main();
