# Deploying Smart Contracts to Blockchain

Guide for deploying smart contracts to a running blockchain network.

## Network Configuration

- **Chain ID**: 10001
- **RPC URL**: `http://NODE_IP:8545` (use any validator or RPC node)
- **Gas Price**: 0 (private network)
- **EVM Version**: Berlin

## Prerequisites

- Funded account private key
- RPC access to any network node
- Solidity contracts compiled for Berlin EVM

## Option 1: Using Hardhat

**Setup hardhat.config.js:**

```javascript
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      evmVersion: "berlin"
    }
  },
  networks: {
    besuchain: {
      url: "http://NODE_IP:8545",
      chainId: 10001,
      accounts: ["0xYOUR_PRIVATE_KEY"],
      gasPrice: 0,
      gas: 5000000
    }
  }
};
```

**Deploy:**

```bash
npx hardhat compile
npx hardhat run scripts/deploy.js --network besuchain
```

**Example deploy script:**

```javascript
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  const Contract = await ethers.getContractFactory("YourContract");
  const contract = await Contract.deploy({
    gasPrice: 0,
    gasLimit: 5000000
  });

  await contract.waitForDeployment();
  console.log("Contract deployed to:", await contract.getAddress());
}

main().catch(console.error);
```

## Option 2: Using Foundry (Cast)

**Deploy contract:**

```bash
forge create src/Contract.sol:ContractName \
  --rpc-url http://NODE_IP:8545 \
  --private-key 0xYOUR_PRIVATE_KEY \
  --gas-price 0 \
  --gas-limit 5000000
```

**With constructor arguments:**

```bash
forge create src/Contract.sol:ContractName \
  --rpc-url http://NODE_IP:8545 \
  --private-key 0xYOUR_PRIVATE_KEY \
  --constructor-args "arg1" "arg2" \
  --gas-price 0 \
  --gas-limit 5000000
```

## Option 3: Using Viem (TypeScript)

**Note:** When using tsx or ts-node, environment variables from .env may not load automatically. Either:
- Load dotenv explicitly in your script: `import 'dotenv/config'`
- Pass env vars directly: `PRIVATE_KEY=0x... npx tsx deploy.ts`

```typescript
import { createWalletClient, createPublicClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { defineChain } from 'viem';

const besuchain = defineChain({
  id: 10001,
  name: 'BesuChain',
  network: 'besuchain',
  nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
  rpcUrls: {
    default: { http: ['http://NODE_IP:8545'] },
    public: { http: ['http://NODE_IP:8545'] }
  }
});

const account = privateKeyToAccount(process.env.PRIVATE_KEY as `0x${string}`);

const walletClient = createWalletClient({
  account,
  chain: besuchain,
  transport: http()
});

const publicClient = createPublicClient({
  chain: besuchain,
  transport: http()
});

// Deploy
const hash = await walletClient.deployContract({
  abi: CONTRACT_ABI,
  bytecode: CONTRACT_BYTECODE as `0x${string}`,
  args: [], // constructor arguments
  gasPrice: 0n,
  gas: 5000000n
});

const receipt = await publicClient.waitForTransactionReceipt({ hash });
console.log('Contract deployed to:', receipt.contractAddress);
```

## Deployment Verification

**Critical:** Always verify deployment succeeded:

```bash
# Check transaction receipt status (must be 0x1)
cast receipt TRANSACTION_HASH --rpc-url http://NODE_IP:8545

# Verify contract has bytecode
cast code CONTRACT_ADDRESS --rpc-url http://NODE_IP:8545
```

If `cast code` returns `0x`, deployment failed even if you got a transaction hash.

## Interacting with Contracts

**Read contract state:**

```bash
cast call CONTRACT_ADDRESS "functionName()" --rpc-url http://NODE_IP:8545
```

**Write transaction:**

```bash
cast send CONTRACT_ADDRESS \
  "functionName(uint256)" \
  123 \
  --private-key 0xYOUR_PRIVATE_KEY \
  --rpc-url http://NODE_IP:8545 \
  --gas-price 0
```

## Important Considerations

**Gas Price:**
- BesuChain configured with min-gas-price=0
- Recommended: explicitly set `gasPrice: 0n` or `--gas-price 0`
- Note: `gasPrice: 1` also works on this network

**Gas Limits:**
- Gas estimation may fail on private networks
- Use explicit gas limits: 3000000-5000000 depending on contract size
- Calculate from bytecode: `bytes × 200 + buffer`

**EVM Version:**
- Contracts must compile for Berlin EVM
- Solidity 0.8.24+ defaults to Cancun - must override in compiler settings
- Set `evmVersion: "berlin"` in Hardhat/Foundry config

**Deployment Failures:**
- Silent failures common - no error messages
- Always check receipt.status and contract bytecode
- Use `debug_traceTransaction` if deployment fails without clear error

## Example: Complete Deployment Flow

**Using Viem/TypeScript (Tested):**

```bash
# 1. Set up environment
export DEPLOYER_PRIVATE_KEY=0xYOUR_KEY
export BESU_RPC_URL=http://130.61.22.253:8545

# 2. Deploy
npx tsx deploy-script.ts
# Or with inline env vars:
DEPLOYER_PRIVATE_KEY=0xKEY BESU_RPC_URL=http://IP:8545 npx tsx deploy-script.ts

# 3. Verify deployment
curl -X POST --data '{"jsonrpc":"2.0","method":"eth_getCode","params":["CONTRACT_ADDRESS","latest"],"id":1}' \
  http://130.61.22.253:8545 | jq -r '.result'
# Should return bytecode starting with 0x6080... (not 0x)
```

**Using Foundry:**

```bash
# 1. Compile for Berlin
forge build --evm-version berlin

# 2. Deploy
forge create src/MyContract.sol:MyContract \
  --rpc-url http://130.61.22.253:8545 \
  --private-key 0xYOUR_KEY \
  --gas-price 0 \
  --gas-limit 5000000

# 3. Verify deployment
curl -X POST --data '{"jsonrpc":"2.0","method":"eth_getCode","params":["CONTRACT_ADDRESS","latest"],"id":1}' \
  http://130.61.22.253:8545 | jq -r '.result'
```

## Troubleshooting

**Transaction reverts with no error:**
- Check EVM version matches (Berlin)
- Increase gas limit
- Verify constructor arguments are correct

**Gas estimation failed:**
- Normal for private networks
- Always use explicit gas limits

**Contract has no code after deployment:**
- Check transaction receipt status is 0x1
- If 0x0, deployment reverted - check EVM compatibility
- Use debug_traceTransaction to find exact failure point

**INVALID opcode error:**
- Contract compiled for wrong EVM version
- Recompile with `evmVersion: "berlin"`
