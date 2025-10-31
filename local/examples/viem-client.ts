import { createPublicClient, createWalletClient, http, defineChain } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';

// Define the Besu local chain
export const besuLocal = defineChain({
  id: 10001,
  name: 'Besu Local',
  network: 'besu-local',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: {
      http: ['http://127.0.0.1:8545'],
      webSocket: ['ws://127.0.0.1:8546'],
    },
    public: {
      http: ['http://127.0.0.1:8545'],
      webSocket: ['ws://127.0.0.1:8546'],
    },
  },
});

// Create public client for reading blockchain state
export const publicClient = createPublicClient({
  chain: besuLocal,
  transport: http('http://127.0.0.1:8545'),
});

// Create wallet client for sending transactions
// Replace with your validator private key
const PRIVATE_KEY = process.env.PRIVATE_KEY as `0x${string}`;

if (!PRIVATE_KEY) {
  throw new Error('PRIVATE_KEY environment variable not set');
}

const account = privateKeyToAccount(PRIVATE_KEY);

export const walletClient = createWalletClient({
  account,
  chain: besuLocal,
  transport: http('http://127.0.0.1:8545'),
});

// Example usage
async function example() {
  // Get current block number
  const blockNumber = await publicClient.getBlockNumber();
  console.log('Current block:', blockNumber);

  // Get account balance
  const balance = await publicClient.getBalance({
    address: account.address
  });
  console.log('Balance:', balance);

  // Send a transaction (with zero gas price)
  const hash = await walletClient.sendTransaction({
    to: '0xRecipientAddress',
    value: 1000000000000000000n, // 1 ETH in wei
    gasPrice: 0n, // Zero gas price
  });

  // Wait for transaction receipt
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  console.log('Transaction mined:', receipt);
}
