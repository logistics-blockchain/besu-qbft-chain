#!/bin/bash
# Generate a validator package for external validators to join the network
# Run this on an existing network node

set -e

echo "=== Generate Validator Package ==="
echo ""

# Check prerequisites
if [ ! -f "besu-network/genesis.json" ]; then
    echo "Error: Genesis file not found. Start the network first."
    exit 1
fi

# Get bootnode enode
BOOTNODE_ENODE=$(grep "Enode URL" besu-data/node0.log 2>/dev/null | grep -o 'enode://[^[:space:]]*' | head -1)

if [ -z "$BOOTNODE_ENODE" ]; then
    echo "Error: Could not find bootnode enode. Is the network running?"
    echo "Trying to extract from running node..."

    # Try getting from RPC
    ENODE_RESPONSE=$(curl -s -X POST http://localhost:8545 \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"admin_nodeInfo","params":[],"id":1}')

    BOOTNODE_ENODE=$(echo "$ENODE_RESPONSE" | jq -r '.result.enode' 2>/dev/null)

    if [ -z "$BOOTNODE_ENODE" ] || [ "$BOOTNODE_ENODE" = "null" ]; then
        echo "Error: Could not retrieve bootnode enode."
        echo "Please ensure the network is running and try again."
        exit 1
    fi
fi

# Get chain ID from genesis
CHAIN_ID=$(jq -r '.config.chainId' besu-network/genesis.json)

# Create package directory
PACKAGE_DIR="validator-package-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$PACKAGE_DIR"

echo "Creating validator package in: $PACKAGE_DIR"
echo ""

# Copy genesis file
cp besu-network/genesis.json "$PACKAGE_DIR/"

# Create network config file
cat > "$PACKAGE_DIR/network-config.json" <<EOF
{
  "chainId": $CHAIN_ID,
  "bootnode": "$BOOTNODE_ENODE",
  "rpcEndpoint": "http://localhost:8545",
  "p2pPort": 30303,
  "networkType": "QBFT",
  "gasPrice": 0
}
EOF

# Create validator setup script
cat > "$PACKAGE_DIR/setup-validator.sh" <<'SETUP_SCRIPT'
#!/bin/bash
# Validator Setup Script
# Run this to set up your validator node

set -e

echo "=== Validator Setup ==="
echo ""

# Check if Besu is installed
if ! command -v besu &> /dev/null; then
    echo "Besu not found. Installing via Homebrew..."
    if command -v brew &> /dev/null; then
        brew tap hyperledger/besu
        brew install hyperledger/besu/besu
    else
        echo "Homebrew not found. Please install Besu manually:"
        echo "  https://besu.hyperledger.org/"
        exit 1
    fi
fi

echo "Besu found: $(besu --version | head -n 1)"
echo ""

# Generate validator keypair
echo "Generating validator keypair..."
VALIDATOR_DIR="validator-data"
mkdir -p "$VALIDATOR_DIR"

besu --data-path="$VALIDATOR_DIR" public-key export-address --to="$VALIDATOR_DIR/address.txt"

VALIDATOR_ADDRESS=$(cat "$VALIDATOR_DIR/address.txt")

echo ""
echo "[OK] Validator keypair generated"
echo ""
echo "Your validator address: $VALIDATOR_ADDRESS"
echo ""
echo "=============================================="
echo "IMPORTANT - Next Steps:"
echo "=============================================="
echo ""
echo "1. Send this address to the network operators:"
echo "   $VALIDATOR_ADDRESS"
echo ""
echo "2. Wait for network operators to vote you in"
echo "   (Requires >50% of existing validators to approve)"
echo ""
echo "3. Once approved, start your validator:"
echo "   ./start-validator.sh"
echo ""
echo "4. Monitor your validator:"
echo "   ./check-validator-status.sh"
echo ""
echo "=============================================="
echo ""

# Save address to config
echo "$VALIDATOR_ADDRESS" > validator-address.txt

echo "Setup complete!"
SETUP_SCRIPT

chmod +x "$PACKAGE_DIR/setup-validator.sh"

# Create start validator script
cat > "$PACKAGE_DIR/start-validator.sh" <<'START_SCRIPT'
#!/bin/bash
# Start Validator Node

set -e

if [ ! -f "validator-address.txt" ]; then
    echo "Error: Validator not set up. Run ./setup-validator.sh first"
    exit 1
fi

VALIDATOR_ADDRESS=$(cat validator-address.txt)
BOOTNODE=$(jq -r '.bootnode' network-config.json)
CHAIN_ID=$(jq -r '.chainId' network-config.json)

echo "=== Starting Validator Node ==="
echo ""
echo "Validator Address: $VALIDATOR_ADDRESS"
echo "Chain ID: $CHAIN_ID"
echo "Bootnode: $BOOTNODE"
echo ""

# Check if already running
if [ -f "validator.pid" ]; then
    PID=$(cat validator.pid)
    if ps -p $PID > /dev/null 2>&1; then
        echo "Validator is already running (PID: $PID)"
        exit 1
    fi
fi

# Start validator
echo "Starting validator node..."

besu --genesis-file=genesis.json \
  --data-path=validator-data \
  --node-private-key-file=validator-data/key \
  --rpc-http-enabled \
  --rpc-http-api=ETH,NET,QBFT \
  --rpc-http-host=0.0.0.0 \
  --rpc-http-port=8545 \
  --rpc-http-cors-origins="*" \
  --host-allowlist="*" \
  --p2p-host=0.0.0.0 \
  --p2p-port=30303 \
  --bootnodes=$BOOTNODE \
  --min-gas-price=0 \
  --miner-enabled \
  --miner-coinbase=$VALIDATOR_ADDRESS \
  > validator.log 2>&1 &

VALIDATOR_PID=$!
echo $VALIDATOR_PID > validator.pid

echo ""
echo "[OK] Validator started"
echo "  PID: $VALIDATOR_PID"
echo "  RPC: http://localhost:8545"
echo "  Logs: tail -f validator.log"
echo ""
echo "Check status: ./check-validator-status.sh"
echo "Stop validator: ./stop-validator.sh"
START_SCRIPT

chmod +x "$PACKAGE_DIR/start-validator.sh"

# Create stop validator script
cat > "$PACKAGE_DIR/stop-validator.sh" <<'STOP_SCRIPT'
#!/bin/bash
# Stop Validator Node

set -e

echo "=== Stopping Validator ==="

if [ ! -f "validator.pid" ]; then
    echo "No PID file found. Validator may not be running."
    exit 1
fi

PID=$(cat validator.pid)

if ps -p $PID > /dev/null 2>&1; then
    echo "Stopping validator (PID: $PID)..."
    kill $PID
    sleep 2

    if ps -p $PID > /dev/null 2>&1; then
        echo "Force stopping..."
        kill -9 $PID
    fi

    rm validator.pid
    echo "[OK] Validator stopped"
else
    echo "Validator not running (stale PID file)"
    rm validator.pid
fi
STOP_SCRIPT

chmod +x "$PACKAGE_DIR/stop-validator.sh"

# Create status check script
cat > "$PACKAGE_DIR/check-validator-status.sh" <<'STATUS_SCRIPT'
#!/bin/bash
# Check Validator Status

set -e

RPC_ENDPOINT="http://localhost:8545"

echo "=== Validator Status Check ==="
echo ""

# Check if process is running
if [ -f "validator.pid" ]; then
    PID=$(cat validator.pid)
    if ps -p $PID > /dev/null 2>&1; then
        echo "[OK] Process: Running (PID: $PID)"
    else
        echo "[ERROR] Process: Not running (stale PID)"
    fi
else
    echo "[ERROR] Process: Not running"
fi

echo ""

# Check RPC connectivity
echo "Checking RPC connection..."
if curl -s -f "$RPC_ENDPOINT" > /dev/null 2>&1; then
    echo "[OK] RPC: Connected"
else
    echo "[ERROR] RPC: Not accessible"
    exit 1
fi

echo ""

# Get block number
BLOCK_RESPONSE=$(curl -s -X POST "$RPC_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}')

BLOCK_HEX=$(echo "$BLOCK_RESPONSE" | jq -r '.result')
BLOCK_DEC=$((16#${BLOCK_HEX#0x}))

echo "Current Block: $BLOCK_DEC ($BLOCK_HEX)"

# Get peer count
PEER_RESPONSE=$(curl -s -X POST "$RPC_ENDPOINT" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}')

PEER_HEX=$(echo "$PEER_RESPONSE" | jq -r '.result')
PEER_DEC=$((16#${PEER_HEX#0x}))

echo "Connected Peers: $PEER_DEC"

if [ $PEER_DEC -eq 0 ]; then
    echo "[WARNING] No peers connected"
fi

echo ""

# Check if validator is in validator set
if [ -f "validator-address.txt" ]; then
    VALIDATOR_ADDRESS=$(cat validator-address.txt)

    VALIDATORS_RESPONSE=$(curl -s -X POST "$RPC_ENDPOINT" \
      -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","method":"qbft_getValidatorsByBlockNumber","params":["latest"],"id":1}')

    VALIDATORS=$(echo "$VALIDATORS_RESPONSE" | jq -r '.result[]')

    if echo "$VALIDATORS" | grep -qi "$VALIDATOR_ADDRESS"; then
        echo "[OK] Status: ACTIVE VALIDATOR"
        echo "  Address: $VALIDATOR_ADDRESS"
    else
        echo "[INFO] Status: NOT IN VALIDATOR SET"
        echo "  Address: $VALIDATOR_ADDRESS"
        echo "  Waiting for network operators to vote you in..."
    fi
fi

echo ""
echo "Status check complete"
STATUS_SCRIPT

chmod +x "$PACKAGE_DIR/check-validator-status.sh"

# Create README
cat > "$PACKAGE_DIR/README.md" <<EOF
# Validator Setup Package

This package contains everything you need to join the network as a validator.

## Prerequisites

- **Hyperledger Besu** (will be installed automatically if using Homebrew)
- **Java 17 or higher**
- **Linux or macOS**
- **Stable internet connection**
- **Open P2P port** (default: 30303)

## Network Information

- **Chain ID:** $CHAIN_ID
- **Consensus:** QBFT (Byzantine Fault Tolerant)
- **Gas Price:** 0 (free transactions)

## Quick Start

### 1. Setup Validator

Run the setup script to generate your validator keypair:

\`\`\`bash
./setup-validator.sh
\`\`\`

This will output your validator address. **Send this address to the network operators.**

### 2. Wait for Approval

Network operators must vote to add your validator:
- Requires >50% of existing validators to approve
- You'll be notified when approved

### 3. Start Validator

Once approved, start your validator node:

\`\`\`bash
./start-validator.sh
\`\`\`

### 4. Monitor Status

Check your validator status:

\`\`\`bash
./check-validator-status.sh
\`\`\`

View logs:

\`\`\`bash
tail -f validator.log
\`\`\`

### 5. Stop Validator

To stop your validator:

\`\`\`bash
./stop-validator.sh
\`\`\`

## Files Included

- \`genesis.json\` - Network genesis configuration
- \`network-config.json\` - Network parameters
- \`setup-validator.sh\` - Generate validator keys
- \`start-validator.sh\` - Start validator node
- \`stop-validator.sh\` - Stop validator node
- \`check-validator-status.sh\` - Check validator status

## Important Notes

### Security

- **Never share your private key** (\`validator-data/key\`)
- Keep your validator data directory secure
- Back up your private key in a secure location

### Network Requirements

- Open port **30303** (P2P)
- Open port **8545** (RPC, optional for external access)
- Stable internet connection
- Sufficient disk space (blockchain data grows over time)

### Validator Responsibilities

As a validator, you are responsible for:
- Maintaining node uptime
- Keeping Besu software updated
- Monitoring node health
- Responding to network issues

### Getting Help

If you encounter issues:
1. Check logs: \`tail -f validator.log\`
2. Verify prerequisites are met
3. Ensure P2P port is accessible
4. Contact network operators

## Maintenance

### Update Besu

\`\`\`bash
# macOS
brew upgrade hyperledger/besu/besu

# Restart validator
./stop-validator.sh
./start-validator.sh
\`\`\`

### Backup Validator Keys

\`\`\`bash
# Backup your private key
cp validator-data/key validator-key-backup.txt

# Store in secure location (hardware wallet, encrypted storage, etc.)
\`\`\`

### Monitor Performance

\`\`\`bash
# Check block production
./check-validator-status.sh

# View real-time logs
tail -f validator.log

# Check resource usage
top | grep besu
\`\`\`

## Troubleshooting

### Validator Not Connecting

- Verify bootnode enode is correct
- Check P2P port (30303) is open
- Review logs for connection errors

### Not in Validator Set

- Confirm network operators have voted you in
- Check with \`check-validator-status.sh\`
- May take a few minutes after approval

### High Resource Usage

- Normal for blockchain nodes
- Ensure adequate RAM (4GB+ recommended)
- Monitor disk space (grows over time)

## Support

Contact network operators for assistance with:
- Approval status
- Network configuration
- Technical issues
EOF

echo "[OK] Validator package created: $PACKAGE_DIR"
echo ""
echo "Package contents:"
ls -lh "$PACKAGE_DIR"
echo ""
echo "=============================================="
echo "Next Steps:"
echo "=============================================="
echo ""
echo "1. Distribute package to validator:"
echo "   tar -czf $PACKAGE_DIR.tar.gz $PACKAGE_DIR"
echo "   # Send $PACKAGE_DIR.tar.gz to validator"
echo ""
echo "2. Validator extracts and runs setup:"
echo "   tar -xzf $PACKAGE_DIR.tar.gz"
echo "   cd $PACKAGE_DIR"
echo "   ./setup-validator.sh"
echo ""
echo "3. Validator sends you their address"
echo ""
echo "4. Vote to add validator:"
echo "   ./tools/vote-add-validator.sh <VALIDATOR_ADDRESS>"
echo ""
echo "5. Validator starts their node:"
echo "   ./start-validator.sh"
echo ""
echo "=============================================="
