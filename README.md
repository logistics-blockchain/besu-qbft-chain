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

- [Hyperledger Besu](https://besu.hyperledger.org/stable/public-networks/get-started/install) (latest version)
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

# Start 4-node QBFT network
./local/scripts/start.sh

# Verify network is running
./local/scripts/verify.sh

# Check network health
./tools/health-check.sh
```

The network will be available at `http://localhost:8545`

### Stop Network

```bash
./local/scripts/stop.sh
```

## Network Configuration

| Parameter | Value |
|-----------|-------|
| Chain ID | 10001 |
| Consensus | QBFT |
| Validators | 4 |
| Block Time | 2 seconds |
| Gas Price | 0 |

### RPC Endpoints

- **Node 0** (main): `http://localhost:8545` (HTTP), `ws://localhost:8546` (WebSocket)
- **Node 1**: `http://localhost:8547`
- **Node 2**: `http://localhost:8548`
- **Node 3**: `http://localhost:8549`

## Usage

### Connect with Web3 Libraries

**Viem:**
```typescript
import { createPublicClient, http, defineChain } from 'viem';

const besuLocal = defineChain({
  id: 10001,
  name: 'Besu Local',
  nativeCurrency: { decimals: 18, name: 'Ether', symbol: 'ETH' },
  rpcUrls: {
    default: { http: ['http://127.0.0.1:8545'] }
  }
});

const client = createPublicClient({
  chain: besuLocal,
  transport: http()
});
```

**Hardhat:**
```typescript
networks: {
  besuLocal: {
    url: "http://127.0.0.1:8545",
    chainId: 10001,
    gasPrice: 0
  }
}
```

See [local/examples/](local/examples/) for complete integration examples.

### Important: Zero Gas Transactions

This network requires explicitly setting `gasPrice: 0` in all transactions:

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

See [cloud/README.md](cloud/README.md) for detailed instructions.

## Monitoring

### Check Network Health

```bash
./tools/health-check.sh
```

### View Logs

```bash
# Follow node logs
tail -f besu-data/node0.log

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
- Increase validator count for higher fault tolerance

## Documentation

- [Hyperledger Besu Documentation](https://besu.hyperledger.org/)
- [QBFT Consensus](https://besu.hyperledger.org/stable/private-networks/concepts/poa)
- [JSON-RPC API Reference](https://besu.hyperledger.org/stable/public-networks/reference/api)
- [Private Network Configuration](https://besu.hyperledger.org/stable/private-networks)

## License

MIT License - See [LICENSE](LICENSE) for details.
