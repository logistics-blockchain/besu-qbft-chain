# Besu QBFT Chain

Private EVM network implementation using [Hyperledger Besu](https://besu.hyperledger.org/) with QBFT consensus.

## Overview

This repository provides a complete setup for deploying a private EVM network with:

- **QBFT Consensus** - Byzantine fault tolerant consensus mechanism
- **Smart Contract Validator Management** - On-chain governance with multi-signature approval for new validators
- **Progressive Decentralization** - Start with single admin, scale to multi-sig governance
- **Zero Gas Configuration** - Free transactions for all network participants
- **Full EVM Compatibility** - Support for latest Solidity versions and EVM features
- **Cancun Fork Support** - Includes London, Shanghai, and Cancun upgrades from genesis

## Quick Start

### Prerequisites

- [Hyperledger Besu](https://besu.hyperledger.org/) (latest version)
- Java 17 or higher
- curl and jq for verification scripts

**macOS installation:**
```bash
brew tap hyperledger/besu
brew install hyperledger/besu/besu
```

### Ethereum Fork Compatibility

This network includes the following Ethereum upgrades activated from genesis:

- **Berlin** - EIP-2565, EIP-2929, EIP-2718, EIP-2930
- **London** - EIP-1559 base fee mechanism (configured for zero gas)
- **Shanghai** - EVM improvements and validator withdrawals support
- **Cancun** - EIP-4844 (blob transactions), EIP-1153 (transient storage), EIP-5656 (MCOPY), EIP-6780 (SELFDESTRUCT changes), EIP-7516 (BLOBBASEFEE opcode)

All upgrades are configured in the genesis file with activation at block 0. This ensures full compatibility with modern Ethereum tooling and smart contracts. Requires Hyperledger Besu 24.1.2 or later.

### Local Development Setup

```bash
# Generate validator keys and genesis file
./local/scripts/setup.sh

# Start QBFT network
./local/scripts/start.sh

# Verify network is running
./local/scripts/verify.sh

# Check network health
./tools/health-check.sh
```

The primary RPC endpoint will be available at `http://localhost:8545`

### Stop Network

```bash
./local/scripts/stop.sh
```

## Usage

### Connect with Web3 Libraries

Network configuration details (chain ID, RPC endpoints) are displayed when starting the network and can be found in the configuration files.

**Viem:**
```typescript
import { createPublicClient, http, defineChain } from 'viem';

const besuChain = defineChain({
  id: /* see genesis.json */,
  name: 'Besu QBFT',
  nativeCurrency: { decimals: 18, name: 'Ether', symbol: 'ETH' },
  rpcUrls: {
    default: { http: ['http://127.0.0.1:8545'] }
  }
});

const client = createPublicClient({
  chain: besuChain,
  transport: http()
});
```

**Hardhat:**
```typescript
networks: {
  besu: {
    url: "http://127.0.0.1:8545",
    chainId: /* see genesis.json */,
    gasPrice: 0
  }
}
```

See [local/examples/](local/examples/) for complete integration examples.

### Important: Zero Gas Transactions

This network is configured with zero base fee. Explicitly set `gasPrice: 0` in all transactions:

```typescript
await walletClient.sendTransaction({
  to: '0x...',
  value: parseEther('1'),
  gasPrice: 0n  // Required
});
```

## Project Structure

```
besu-qbft-chain/
├── contracts/          Smart contracts
│   └── DynamicMultiSigValidatorManager.sol
├── test/               Contract unit tests
│   └── DynamicMultiSigValidatorManager.test.js
├── local/              Local development setup
│   ├── config/         Network generation configuration
│   ├── scripts/        Setup, start, stop, verify scripts
│   │   ├── generate-2validator-genesis.js
│   │   ├── generate-4validator-genesis.js
│   │   ├── extract-bytecode.js
│   │   ├── start-contract-network.sh
│   │   └── stop-contract-network.sh
│   └── examples/       Client integration examples
├── cloud/              Cloud deployment
│   ├── terraform/      Infrastructure as code
│   ├── docker/         Container configurations
│   └── scripts/        Deployment automation
├── tools/              Utility scripts
│   ├── generate-validator-key.sh
│   ├── health-check.sh
│   ├── reset-chain.sh
│   ├── query-validators.js
│   └── test-validator-approval.js
├── docs/               Documentation
│   └── CONTRACT_VALIDATOR_MANAGEMENT.md
├── package.json        Node.js dependencies and scripts
└── hardhat.config.js   Hardhat configuration for testing
```

## Cloud Deployment

Deploy to cloud infrastructure using Terraform:

```bash
# Configure Terraform variables
cd cloud/terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your cloud provider credentials

# Provision infrastructure
terraform init
terraform apply

# Deploy Besu nodes
cd ../scripts/
./deploy.sh
```

## Monitoring

### Check Network Health

```bash
./tools/health-check.sh
```

### View Logs

```bash
# Follow node logs
tail -f besu-data/node*.log

# Search for errors
grep ERROR besu-data/node*.log
```

### Query Network Status

```bash
# Current block number
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Peer count
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}'
```

## Validator Management

Validators are managed via an on-chain smart contract with multi-signature governance:

```bash
# Compile contract and extract bytecode
npm run compile

# Generate genesis with contract (2 validators)
npm run generate:genesis-2

# Start contract-managed network
./local/scripts/start-contract-network.sh

# Query current validators from contract
node tools/query-validators.js

# Test validator approval workflow
node tools/test-validator-approval.js
```

**Features:**
- Multi-signature approval (dynamic threshold)
- On-chain audit trail of all validator changes
- Progressive decentralization (1 → N admins)
- Application submission with metadata
- Proposal-based approval workflow

See [docs/CONTRACT_VALIDATOR_MANAGEMENT.md](docs/CONTRACT_VALIDATOR_MANAGEMENT.md) for detailed documentation.

## Maintenance

### Reset Chain Data

Remove all blockchain data while preserving validator keys:

```bash
./tools/reset-chain.sh
```

### Update Besu Version

```bash
brew upgrade hyperledger/besu/besu
./local/scripts/stop.sh
./local/scripts/start.sh
```

## Testing

### Unit Tests

Test the validator management contract:

```bash
# Install dependencies
npm install

# Run unit tests
npm test

# Run unit tests with coverage
npm run test:coverage
```

**Test Coverage:**
- 36 comprehensive tests
- Admin management (add/remove, threshold calculation)
- Validator proposals (create/sign/execute)
- Access control and permissions
- Progressive decentralization (1 → 5 admins)

### Integration Tests

Test with live Besu network:

```bash
# Generate genesis and start network
npm run generate:genesis-2
./local/scripts/start-contract-network.sh

# Query validators from contract
node tools/query-validators.js

# Test approval workflow
node tools/test-validator-approval.js

# Stop network
./local/scripts/stop-contract-network.sh
```

## Security Considerations

This configuration is designed for development and testing environments.

**Development configuration includes:**
- Private keys stored in plaintext
- All RPC APIs exposed without authentication
- CORS enabled for all origins
- Admin APIs accessible

**For production deployments:**
- Use hardware security modules for key management
- Enable authentication and TLS for RPC endpoints
- Implement onchain permissioning
- Configure proper firewall rules
- Use monitoring and alerting systems

## Documentation

- [Hyperledger Besu Documentation](https://besu.hyperledger.org/)
- [Private Networks Guide](https://besu.hyperledger.org/private-networks)
- [Public Networks Guide](https://besu.hyperledger.org/public-networks)

## License

MIT License - See [LICENSE](LICENSE) for details.
