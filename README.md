# Besu QBFT Chain

Private Ethereum network implementation using [Hyperledger Besu](https://besu.hyperledger.org/) with QBFT consensus.

## Overview

This repository provides a complete setup for deploying a private Ethereum network with:

- **QBFT Consensus** - Byzantine fault tolerant consensus mechanism
- **Zero Gas Configuration** - Free transactions for all network participants
- **Full EVM Compatibility** - Support for latest Solidity versions and EVM features
- **Local Development** - Quick setup for testing and development
- **Cloud Deployment** - Production-ready infrastructure configurations

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
├── local/              Local development setup
│   ├── config/         Network generation configuration
│   ├── scripts/        Setup, start, stop, verify scripts
│   └── examples/       Client integration examples
├── cloud/              Cloud deployment
│   ├── terraform/      Infrastructure as code
│   ├── docker/         Container configurations
│   └── scripts/        Deployment automation
└── tools/              Utility scripts
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

### Add Validators Dynamically

Add new validators to a running network using block header voting:

```bash
# Generate new validator keys
./tools/generate-validator-key.sh

# Vote to add validator (from each existing validator)
./tools/vote-add-validator.sh 0xNEW_VALIDATOR_ADDRESS

# Check voting status
./tools/check-pending-votes.sh

# Get current validators
./tools/get-validators.sh
```

See [docs/VALIDATOR_MANAGEMENT.md](docs/VALIDATOR_MANAGEMENT.md) for detailed instructions.

### Onboard External Validators

Generate a complete package for external validators to join the network:

```bash
# Network operators: Generate validator package
./tools/generate-validator-package.sh

# Distribute package to validator candidate
# Validator runs: ./setup-validator.sh
# Validator sends their address back
# Network operators vote to approve
```

See [docs/EXTERNAL_VALIDATOR_GUIDE.md](docs/EXTERNAL_VALIDATOR_GUIDE.md) for complete onboarding workflow.

### Remove Validators

```bash
# Vote to remove validator
./tools/vote-remove-validator.sh 0xVALIDATOR_ADDRESS
```

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
