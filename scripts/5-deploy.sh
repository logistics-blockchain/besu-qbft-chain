#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "Deploying BesuChain nodes..."

# Check prerequisites
if [ ! -f "artifacts/genesis.json" ]; then
  echo "Error: genesis.json not found. Run 'npm run deploy:all' first."
  exit 1
fi

if [ ! -d "keys" ] || [ -z "$(ls -A keys/*.key 2>/dev/null)" ]; then
  echo "Error: Node keys not found. Run 'npm run keys:generate' first."
  exit 1
fi

# Read nodes configuration
if [ -f "nodes.json" ]; then
  echo "Using nodes.json configuration"
  NODES_CONFIG="nodes.json"
else
  echo "No nodes.json found, using default local configuration"
  # Create temporary default config
  NODES_CONFIG=".nodes.default.json"
  cat > "$NODES_CONFIG" <<'EOF'
{
  "nodes": {
    "validator1": {"type": "validator", "location": "local", "port": 8545},
    "validator2": {"type": "validator", "location": "local", "port": 8546},
    "validator3": {"type": "validator", "location": "local", "port": 8547},
    "rpc1": {"type": "rpc", "location": "local", "port": 8548}
  }
}
EOF
fi

# Create runtime directory for local nodes
mkdir -p .runtime

# Get node names
NODE_NAMES=$(jq -r '.nodes | keys[]' "$NODES_CONFIG")
NODE_INDEX=1

for NODE_NAME in $NODE_NAMES; do
  echo ""
  echo "=== Deploying $NODE_NAME ==="

  # Get node configuration
  NODE_TYPE=$(jq -r ".nodes[\"$NODE_NAME\"].type" "$NODES_CONFIG")
  LOCATION=$(jq -r ".nodes[\"$NODE_NAME\"].location" "$NODES_CONFIG")

  if [ "$LOCATION" == "local" ]; then
    # Local deployment
    PORT=$(jq -r ".nodes[\"$NODE_NAME\"].port" "$NODES_CONFIG")
    NODE_DIR=".runtime/$NODE_NAME"

    echo "  Location: Local (port $PORT)"
    echo "  Type: $NODE_TYPE"

    # Create node directory and data directory
    mkdir -p "$NODE_DIR/data"

    # Copy genesis
    cp artifacts/genesis.json "$NODE_DIR/"

    # Copy node key
    cp "keys/node${NODE_INDEX}.key" "$NODE_DIR/node.key"

    # Generate docker-compose.yml with host networking
    if [ "$NODE_TYPE" == "validator" ]; then
      cat > "$NODE_DIR/docker-compose.yml" <<EOF_COMPOSE
services:
  besu-${NODE_NAME}:
    image: hyperledger/besu:latest
    container_name: besu-${NODE_NAME}
    network_mode: host
    volumes:
      - ./genesis.json:/config/genesis.json:ro
      - ./node.key:/config/node.key:ro
      - ./data:/data
    environment:
      - JAVA_OPTS=-Xmx512m -Xms256m
    command: |
      --genesis-file=/config/genesis.json
      --node-private-key-file=/config/node.key
      --data-path=/data
      --rpc-http-enabled=true
      --rpc-http-host=0.0.0.0
      --rpc-http-port=${PORT}
      --rpc-http-cors-origins="*"
      --rpc-http-api=ETH,NET,WEB3,QBFT
      --host-allowlist="*"
      --p2p-enabled=true
      --p2p-host=0.0.0.0
      --p2p-port=$((30303 + NODE_INDEX - 1))
      --min-gas-price=0
    restart: unless-stopped
EOF_COMPOSE
    else
      # RPC node
      cat > "$NODE_DIR/docker-compose.yml" <<EOF_COMPOSE
services:
  besu-${NODE_NAME}:
    image: hyperledger/besu:latest
    container_name: besu-${NODE_NAME}
    network_mode: host
    volumes:
      - ./genesis.json:/config/genesis.json:ro
      - ./node.key:/config/node.key:ro
      - ./data:/data
    environment:
      - JAVA_OPTS=-Xmx1024m -Xms512m
    command: |
      --genesis-file=/config/genesis.json
      --node-private-key-file=/config/node.key
      --data-path=/data
      --rpc-http-enabled=true
      --rpc-http-host=0.0.0.0
      --rpc-http-port=${PORT}
      --rpc-http-cors-origins="*"
      --rpc-http-api=ETH,NET,WEB3,TXPOOL,DEBUG,TRACE
      --host-allowlist="*"
      --p2p-enabled=true
      --p2p-host=0.0.0.0
      --p2p-port=$((30303 + NODE_INDEX - 1))
      --min-gas-price=0
    restart: unless-stopped
EOF_COMPOSE
    fi

    echo "  ✓ Deployed to $NODE_DIR"

  else
    # Remote deployment
    HOST=$(jq -r ".nodes[\"$NODE_NAME\"].host" "$NODES_CONFIG")
    USER=$(jq -r ".nodes[\"$NODE_NAME\"].user // \"ubuntu\"" "$NODES_CONFIG")

    echo "  Location: Remote ($USER@$HOST)"
    echo "  Type: $NODE_TYPE"

    # Create remote directory with sudo and set ownership
    ssh "$USER@$HOST" "sudo mkdir -p /opt/besu && sudo chown $USER:$USER /opt/besu"

    # Copy genesis
    scp artifacts/genesis.json "$USER@$HOST:/opt/besu/"

    # Copy node key
    scp "keys/node${NODE_INDEX}.key" "$USER@$HOST:/opt/besu/node.key"

    # Generate and copy docker-compose.yml
    if [ "$NODE_TYPE" == "validator" ]; then
      cat <<EOF_COMPOSE | ssh "$USER@$HOST" "cat > /opt/besu/docker-compose.yml"
services:
  besu-node:
    image: hyperledger/besu:latest
    container_name: besu-validator
    ports:
      - "8545:8545"
      - "30303:30303"
    volumes:
      - ./genesis.json:/config/genesis.json:ro
      - ./node.key:/config/node.key:ro
      - besu-data:/data
    environment:
      - JAVA_OPTS=-Xmx512m -Xms256m
    command: |
      --genesis-file=/config/genesis.json
      --node-private-key-file=/config/node.key
      --data-path=/data
      --rpc-http-enabled=true
      --rpc-http-host=0.0.0.0
      --rpc-http-port=8545
      --rpc-http-cors-origins="*"
      --rpc-http-api=ETH,NET,WEB3,QBFT
      --host-allowlist="*"
      --p2p-enabled=true
      --p2p-host=0.0.0.0
      --p2p-port=30303
      --min-gas-price=0
    restart: unless-stopped

volumes:
  besu-data:
EOF_COMPOSE
    else
      cat <<EOF_COMPOSE | ssh "$USER@$HOST" "cat > /opt/besu/docker-compose.yml"
services:
  besu-node:
    image: hyperledger/besu:latest
    container_name: besu-rpc
    ports:
      - "8545:8545"
      - "30303:30303"
    volumes:
      - ./genesis.json:/config/genesis.json:ro
      - ./node.key:/config/node.key:ro
      - besu-data:/data
    environment:
      - JAVA_OPTS=-Xmx1024m -Xms512m
    command: |
      --genesis-file=/config/genesis.json
      --node-private-key-file=/config/node.key
      --data-path=/data
      --rpc-http-enabled=true
      --rpc-http-host=0.0.0.0
      --rpc-http-port=8545
      --rpc-http-cors-origins="*"
      --rpc-http-api=ETH,NET,WEB3,TXPOOL,DEBUG,TRACE
      --host-allowlist="*"
      --p2p-enabled=true
      --p2p-host=0.0.0.0
      --p2p-port=30303
      --min-gas-price=0
      --rpc-http-max-active-connections=500
    restart: unless-stopped

volumes:
  besu-data:
EOF_COMPOSE
    fi

    echo "  ✓ Deployed to $USER@$HOST:/opt/besu"
  fi

  NODE_INDEX=$((NODE_INDEX + 1))
done

# Cleanup temporary config if created
if [ -f ".nodes.default.json" ]; then
  rm ".nodes.default.json"
fi

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Next steps:"
echo "  1. Start nodes: npm run start"
echo "  2. Configure peers: npm run peers"
echo "  3. Verify network: npm run verify"
