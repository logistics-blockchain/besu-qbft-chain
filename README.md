# Besu QBFT Chain

Private blockchain network using Hyperledger Besu with QBFT consensus and contract-based validator management.

## Features

- QBFT Byzantine Fault Tolerant consensus
- Dynamic multi-signature validator governance
- Automated genesis generation with embedded contracts
- Flexible deployment (local, remote)
- Berlin EVM compatibility

## Architecture

- Chain ID: 10001
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

See docs folder for deployment guides.

## References

- [Hyperledger Besu Documentation](https://besu.hyperledger.org/)
- [Private Networks Guide](https://besu.hyperledger.org/private-networks)
- [Public Networks Guide](https://besu.hyperledger.org/public-networks)
