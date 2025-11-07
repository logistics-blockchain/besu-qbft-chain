# Blockchain Deployment Guide

## Overview

This guide covers deployment to local and remote environments.

## Architecture

- **Consensus**: QBFT (Byzantine Fault Tolerant)
- **Chain ID**: 10001
- **Block Time**: 5 seconds
- **Validator Contract**: DynamicMultiSigValidatorManager (multi-sig governance)
- **EVM Version**: Berlin
- **Gas Price**: 0 (private network)

## Prerequisites

### Hardware Requirements
- RAM: 4GB minimum
- Storage: 50GB minimum, grows with chain history

### Local Requirements
- Docker and Docker Compose
- Node.js 18+
- jq (JSON processor)
- openssl

### Remote Requirements
- Ubuntu 22.04+ servers with Docker installed
- SSH access with key authentication
- Minimum 50GB storage per node
- Open ports: 8545 (RPC), 30303 (P2P)

## Configuration

### Node Configuration

Create `nodes.json` in the project root before starting deployment. The number of nodes is fully dynamic and all scripts adapt automatically based on the nodes defined in this file. Minimum 3 validators recommended for QBFT consensus.

**Local Deployment** (development/testing)
```json
{
  "nodes": {
    "validator1": {"type": "validator", "location": "local", "port": 8545},
    "validator2": {"type": "validator", "location": "local", "port": 8546},
    "validator3": {"type": "validator", "location": "local", "port": 8547},
    "rpc1": {"type": "rpc", "location": "local", "port": 8548}
  }
}
```

**Remote Deployment** (production)
```json
{
  "nodes": {
    "validator1": {"type": "validator", "location": "remote", "host": "IP_ADDRESS", "user": "ubuntu"},
    "validator2": {"type": "validator", "location": "remote", "host": "IP_ADDRESS", "user": "ubuntu"},
    "validator3": {"type": "validator", "location": "remote", "host": "IP_ADDRESS", "user": "ubuntu"},
    "rpc1": {"type": "rpc", "location": "remote", "host": "IP_ADDRESS", "user": "ubuntu"}
  }
}
```

### Node Types

- **validator**: Participates in consensus, validates blocks
- **rpc**: Non-validator node for RPC queries (more memory, full API access)

## Deployment Steps

### 1. Install Dependencies

```bash
npm install
```

### 2. Generate All Genesis Components

This command generates keys, compiles contracts, calculates storage, and creates the genesis file:

```bash
npm run deploy:all
```

This executes:
- Key generation for all configured nodes
- Contract compilation (DynamicMultiSigValidatorManager)
- Storage slot calculation for genesis deployment
- Genesis file generation with embedded contract

**Output Files:**
- `keys/node*.key` - Private keys for each node
- `keys/validator-addresses.json` - Derived addresses
- `artifacts/DynamicMultiSigValidatorManager.json` - Contract ABI and bytecode
- `artifacts/storage-slots.json` - Calculated storage for genesis
- `artifacts/genesis.json` - Final genesis configuration

### 3. Deploy to Nodes

Copy genesis, keys, and docker-compose configuration to all nodes:

```bash
npm run deploy
```

**Local Deployment:**
- Creates `.runtime/<node-name>/` directories
- Copies genesis and node keys
- Generates docker-compose.yml with host networking

**Remote Deployment:**
- Creates `/opt/besu/` directory on each server
- Copies files via SCP
- Generates docker-compose.yml for cloud deployment

### 4. Start Nodes

```bash
npm run start
```

Starts Docker containers on all configured nodes. Wait for initialization.

### 5. Configure Peer Discovery

```bash
npm run peers
```

This critical step:
- Extracts enode identifiers from running nodes
- Generates `static-nodes.json` for each node (containing peers)
- Restarts nodes to apply peer configuration

Wait 15 seconds after completion for peer discovery.

### 6. Verify Network

```bash
npm run verify
```

Checks:
- Peer connections (should see N-1 peers per node in N-node network)
- Block numbers across all nodes
- Block production over 10 second interval

**Expected Output:**
```
=== Peer Counts ===
  validator1: 3 peers
  validator2: 3 peers
  validator3: 3 peers
  rpc1: 3 peers

=== Block Numbers ===
  validator1: Block #45
  validator2: Block #45
  validator3: Block #45
  rpc1: Block #45

=== Network Health ===
  Block production working: 2 blocks in 10 seconds
```

## Management Commands

### Stop Network

```bash
npm run stop
```

Stops all Docker containers but preserves blockchain data.

### Complete Reset

Stop containers and delete all blockchain data:

**Local:**
```bash
cd .runtime/<node-name>
docker-compose down -v
```

**Remote:**
```bash
ssh user@host "cd /opt/besu && docker-compose down -v"
```

### View Logs

**Local:**
```bash
docker logs besu-<node-name> -f
```

**Remote:**
```bash
ssh user@host "docker logs besu-validator -f"
# or
ssh user@host "docker logs besu-rpc -f"
```

## RPC Access

### Local Nodes
- validator1: `http://localhost:8545`
- validator2: `http://localhost:8546`
- validator3: `http://localhost:8547`
- rpc1: `http://localhost:8548`

### Remote Nodes
- `http://NODE_IP:8545`

### Health Checks

**Peer Count:**
```bash
curl -X POST --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' http://localhost:8545
```

**Block Number:**
```bash
curl -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545
```

**Query Validators:**
```bash
cast call 0x0000000000000000000000000000000000009999 "getValidators()" --rpc-url http://localhost:8545
```

## Validator Contract

The DynamicMultiSigValidatorManager contract is deployed at genesis to address `0x0000000000000000000000000000000000009999`.

### Features
- Multi-signature governance for validator management
- Application workflow for new validators
- Admin management with threshold voting
- Proposal system for changes

### Key Functions
- `getValidators()` - Returns current validator set
- `getAdmins()` - Returns current admin set
- `applyToBeValidator(organization, email)` - Submit validator application
- `proposeApproval(candidate, reason)` - Admin proposes validator approval
- `signValidatorProposal(proposalId)` - Admin signs proposal
- Automatic execution when threshold reached

### Initial State
- First validator becomes initial admin
- All validators from genesis configured
- Multi-sig threshold: (adminCount / 2) + 1

## Troubleshooting

### Nodes Stay at Block 0

**Symptom:** Block number doesn't increase

**Check:**
1. Peer count: `npm run verify`
2. If peers = 0, peer discovery failed
3. Re-run: `npm run peers`

### Genesis Hash Mismatch

**Symptom:** Nodes can't sync, logs show genesis mismatch

**Solution:** All nodes must have identical genesis.json. Redeploy:
```bash
npm run deploy
```

### Container Fails to Start

**Check logs:**
```bash
docker logs besu-<node-name>
```

**Common issues:**
- Invalid node key format (must be raw hex without 0x prefix)
- Port already in use
- Insufficient memory (validators need 512MB, RPC nodes need 1GB)

### Peer Discovery Fails

**Verify enode reachability:**
```bash
curl http://NODE_IP:8545
```

If unreachable, check firewall rules for ports 8545 and 30303.

### Remote Deployment SSH Issues

**Ensure SSH access:**
```bash
ssh -o ConnectTimeout=10 ubuntu@NODE_IP "echo test"
```

Configure SSH keys if password prompt appears.

### Docker Desktop (Mac/Windows) - RPC Not Accessible

**Symptom:** Containers running and healthy, nodes producing blocks in logs, but `curl http://localhost:8545` fails with "Connection refused"

**Cause:** Docker Desktop on Mac/Windows doesn't support true host networking mode. Despite `network_mode: host` in docker-compose, ports aren't exposed to the host machine.

**Verification:**
```bash
# Check containers are healthy and producing blocks
docker logs besu-validator1 2>&1 | grep -E "Imported|Produced"

# If blocks are being produced, network is working
```

**Solutions:**

1. **Check logs directly** - Network is functional even if RPC inaccessible from host:
```bash
docker logs besu-validator1 | tail -50
```

2. **Use port mapping instead** (remove `network_mode: host` and add `ports:` section):
```yaml
services:
  besu-validator1:
    image: hyperledger/besu:latest
    ports:
      - "8545:8545"
      - "30304:30304"
    # Remove network_mode: host
```

3. **For local development on Mac/Windows**, use Linux VM or deploy to remote Linux servers where host networking works correctly.

**Note:** The deployment scripts currently generate host networking configuration which works on Linux but not Docker Desktop.

## File Locations

### Development Machine
- Configuration: `nodes.json`
- Keys: `keys/node*.key`
- Genesis: `artifacts/genesis.json`
- Local runtime: `.runtime/<node-name>/`

### Remote Servers
- Deployment directory: `/opt/besu/`
- Genesis: `/opt/besu/genesis.json`
- Node key: `/opt/besu/node.key`
- Blockchain data: Docker volume `besu_besu-data`
- Static peers: Container `/data/static-nodes.json`

## Network Reset Procedure

Complete network reset (starting fresh):

```bash
# 1. Stop all nodes and remove data
npm run stop
# For remote nodes, also run:
ssh user@host "cd /opt/besu && docker-compose down -v"

# 2. Clear local artifacts (optional, for genesis changes)
rm -rf artifacts/*.json keys/*.key keys/*.json

# 3. Regenerate everything
npm run deploy:all

# 4. Deploy to nodes
npm run deploy

# 5. Start network
npm run start

# 6. Configure peers
npm run peers

# 7. Verify
npm run verify
```

## Security

- Use firewall rules to restrict RPC access
- Implement HTTPS reverse proxy for RPC endpoints
- Backup node keys securely
