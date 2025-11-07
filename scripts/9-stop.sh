#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "Stopping BesuChain nodes..."

# Read nodes configuration
if [ -f "nodes.json" ]; then
  NODES_CONFIG="nodes.json"
else
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

NODE_NAMES=$(jq -r '.nodes | keys[]' "$NODES_CONFIG")

for NODE_NAME in $NODE_NAMES; do
  echo ""
  echo "=== Stopping $NODE_NAME ==="

  LOCATION=$(jq -r ".nodes[\"$NODE_NAME\"].location" "$NODES_CONFIG")

  if [ "$LOCATION" == "local" ]; then
    # Local node
    NODE_DIR=".runtime/$NODE_NAME"

    if [ -d "$NODE_DIR" ]; then
      cd "$NODE_DIR"
      docker-compose down
      cd - > /dev/null
      echo "  ✓ Stopped locally"
    else
      echo "  Node directory not found, skipping"
    fi

  else
    # Remote node
    HOST=$(jq -r ".nodes[\"$NODE_NAME\"].host" "$NODES_CONFIG")
    USER=$(jq -r ".nodes[\"$NODE_NAME\"].user // \"ubuntu\"" "$NODES_CONFIG")

    ssh "$USER@$HOST" "cd /opt/besu && docker-compose down" || echo "  Failed to stop remote node"

    echo "  ✓ Stopped on $USER@$HOST"
  fi
done

# Cleanup
if [ -f ".nodes.default.json" ]; then
  rm ".nodes.default.json"
fi

echo ""
echo "=== All Nodes Stopped ==="
echo ""
echo "To remove all blockchain data:"
echo "  Local: cd .runtime/<node-name> && docker-compose down -v"
echo "  Remote: ssh user@host 'cd /opt/besu && docker-compose down -v'"
