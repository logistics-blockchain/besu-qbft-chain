# Besu QBFT Chain

Private blockchain network using Hyperledger Besu with QBFT consensus and contract-based validator management.

## Features

- QBFT Byzantine Fault Tolerant consensus
- Dynamic multi-signature validator governance
- Automated genesis generation with embedded contracts
- Flexible deployment (local, remote)
- Berlin EVM compatibility

## Architecture

- Chain ID: 10002
- Block Time: 5 seconds
- EVM Version: Berlin
- Validator Contract: `0x0000000000000000000000000000000000009999`
- Multi-signature governance for validator management

## Requirements

- Docker and Docker Compose
- Node.js 18+
- jq, openssl
- 4GB RAM minimum per node
- 50GB storage minimum per node

## Documentation

**Getting Started:**
- [Joining an Existing Network](docs/ADD_NEW_VALIDATOR.md) - Join a running network as validator

**Deployment:**
- [Blockchain Deployment Guide](docs/BLOCKCHAIN_DEPLOYMENT.md) - Deploy new network from scratch
- [Deploy Smart Contracts](docs/DEPLOY_SMART_CONTRACTS.md) - Contract deployment guide

## References

- [Hyperledger Besu Documentation](https://besu.hyperledger.org/)
- [Private Networks Guide](https://besu.hyperledger.org/private-networks)
- [Public Networks Guide](https://besu.hyperledger.org/public-networks)
