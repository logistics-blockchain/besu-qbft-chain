#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "Starting BesuChain nodes..."

# Read nodes configuration
if [ -f "nodes.json" ]; then
  NODES_CONFIG="nodes.json"
else
  # Create temporary default config
  NODES_CONFIG=".nodes.default.json"
  cat > "$NODES_CONFIG" <<'EOF'
{
  "nodes": {
    "validator1": {"type": "validator", "location": "local", "port": 8545},
    "validator2": {"type": "validator", "location": "local", "port": 8546},
    "validator3": {"type": "validator", "location": "local", "port": 8547},
    "non-validator1": {"type": "non-validator", "location": "local", "port": 8548}
  }
}
EOF
fi

# Get node names
NODE_NAMES=$(jq -r '.nodes | keys[]' "$NODES_CONFIG")

for NODE_NAME in $NODE_NAMES; do
  echo ""
  echo "=== Starting $NODE_NAME ==="

  LOCATION=$(jq -r ".nodes[\"$NODE_NAME\"].location" "$NODES_CONFIG")

  if [ "$LOCATION" == "local" ]; then
    # Local node
    NODE_DIR=".runtime/$NODE_NAME"

    if [ ! -d "$NODE_DIR" ]; then
      echo "  Error: $NODE_DIR not found. Run 'npm run deploy' first."
      continue
    fi

    cd "$NODE_DIR"
    docker-compose up -d
    cd - > /dev/null

    echo "  ✓ Started locally"

  else
    # Remote node
    HOST=$(jq -r ".nodes[\"$NODE_NAME\"].host" "$NODES_CONFIG")
    USER=$(jq -r ".nodes[\"$NODE_NAME\"].user // \"ubuntu\"" "$NODES_CONFIG")

    ssh "$USER@$HOST" "cd /opt/besu && docker-compose up -d"

    echo "  ✓ Started on $USER@$HOST"
  fi
done

# Cleanup temporary config if created
if [ -f ".nodes.default.json" ]; then
  rm ".nodes.default.json"
fi

echo ""
echo "=== All Nodes Started ==="
echo ""
echo "Wait 15-20 seconds for nodes to initialize"
echo ""
echo "Next steps:"
echo "  1. Configure peers: npm run peers"
echo "  2. Verify network: npm run verify"
