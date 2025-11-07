#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "Configuring peer discovery..."

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
    "rpc1": {"type": "rpc", "location": "local", "port": 8548}
  }
}
EOF
fi

# Create temporary file for enodes
ENODES_FILE=".enodes.tmp"
> "$ENODES_FILE"

NODE_NAMES=$(jq -r '.nodes | keys[]' "$NODES_CONFIG")

echo ""
echo "=== Extracting Enodes ==="

# Extract enodes from all nodes
for NODE_NAME in $NODE_NAMES; do
  LOCATION=$(jq -r ".nodes[\"$NODE_NAME\"].location" "$NODES_CONFIG")

  if [ "$LOCATION" == "local" ]; then
    # Local node with host networking
    CONTAINER="besu-${NODE_NAME}"
    # Get host address if specified (for mixed deployments), otherwise use localhost
    HOST_ADDR=$(jq -r ".nodes[\"$NODE_NAME\"].host // \"127.0.0.1\"" "$NODES_CONFIG")

    # Calculate P2P port (30303 + index - 1)
    NODE_NUM=$(echo "$NODE_NAMES" | tr ' ' '\n' | grep -n "^$NODE_NAME$" | cut -d: -f1)
    P2P_PORT=$((30303 + NODE_NUM - 1))

    ENODE=$(docker logs "$CONTAINER" 2>&1 | grep -o 'enode://[a-f0-9]*@[0-9.]*:[0-9]*' | head -1 || echo "")

    if [ -n "$ENODE" ]; then
      # Extract public key and use configured host address with P2P port
      ENODE_PUBKEY=$(echo "$ENODE" | sed 's|enode://\([a-f0-9]*\)@.*|\1|')
      ENODE="enode://${ENODE_PUBKEY}@${HOST_ADDR}:${P2P_PORT}"

      echo "$NODE_NAME|local|$ENODE" >> "$ENODES_FILE"
      echo "  $NODE_NAME: $ENODE"
    else
      echo "  $NODE_NAME: Failed to extract enode"
    fi

  else
    # Remote node
    HOST=$(jq -r ".nodes[\"$NODE_NAME\"].host" "$NODES_CONFIG")
    USER=$(jq -r ".nodes[\"$NODE_NAME\"].user // \"ubuntu\"" "$NODES_CONFIG")

    ENODE=$(ssh "$USER@$HOST" "docker logs besu-validator 2>&1 || docker logs besu-rpc 2>&1" | grep -o 'enode://[a-f0-9]*@[0-9.]*:30303' | head -1 || echo "")

    if [ -n "$ENODE" ]; then
      # Replace internal IP with public host IP
      ENODE_PUBKEY=$(echo "$ENODE" | sed 's|enode://\([a-f0-9]*\)@.*|\1|')
      ENODE="enode://${ENODE_PUBKEY}@${HOST}:30303"
      echo "$NODE_NAME|remote|$ENODE" >> "$ENODES_FILE"
      echo "  $NODE_NAME: $ENODE"
    else
      echo "  $NODE_NAME: Failed to extract enode"
    fi
  fi
done

echo ""
echo "=== Configuring Static Nodes ==="

# For each node, create static-nodes.json with OTHER nodes' enodes
for NODE_NAME in $NODE_NAMES; do
  LOCATION=$(jq -r ".nodes[\"$NODE_NAME\"].location" "$NODES_CONFIG")

  # Build static-nodes.json (all OTHER nodes)
  STATIC_NODES="["
  FIRST=true

  while IFS='|' read -r NAME LOC ENODE; do
    if [ "$NAME" != "$NODE_NAME" ] && [ -n "$ENODE" ]; then
      if [ "$FIRST" = true ]; then
        STATIC_NODES="${STATIC_NODES}\"$ENODE\""
        FIRST=false
      else
        STATIC_NODES="${STATIC_NODES},\"$ENODE\""
      fi
    fi
  done < "$ENODES_FILE"

  STATIC_NODES="${STATIC_NODES}]"

  if [ "$LOCATION" == "local" ]; then
    # Local node - write directly to bind-mounted data directory
    NODE_DIR=".runtime/$NODE_NAME"
    echo "$STATIC_NODES" | jq '.' > "$NODE_DIR/data/static-nodes.json"

    echo "  $NODE_NAME: Configured $(echo "$STATIC_NODES" | jq '. | length') peers"

  else
    # Remote node
    HOST=$(jq -r ".nodes[\"$NODE_NAME\"].host" "$NODES_CONFIG")
    USER=$(jq -r ".nodes[\"$NODE_NAME\"].user // \"ubuntu\"" "$NODES_CONFIG")

    # Create static-nodes.json on remote
    echo "$STATIC_NODES" | jq '.' | ssh "$USER@$HOST" "cat > /opt/besu/static-nodes.json"

    # Copy to container
    ssh "$USER@$HOST" "docker cp /opt/besu/static-nodes.json besu-validator:/data/static-nodes.json 2>/dev/null || docker cp /opt/besu/static-nodes.json besu-rpc:/data/static-nodes.json"

    echo "  $NODE_NAME: Configured $(echo "$STATIC_NODES" | jq '. | length') peers"
  fi
done

echo ""
echo "=== Restarting Nodes to Apply Peer Configuration ==="

# Restart all nodes to pick up static-nodes.json
for NODE_NAME in $NODE_NAMES; do
  LOCATION=$(jq -r ".nodes[\"$NODE_NAME\"].location" "$NODES_CONFIG")

  if [ "$LOCATION" == "local" ]; then
    NODE_DIR=".runtime/$NODE_NAME"
    (cd "$NODE_DIR" && docker-compose restart > /dev/null 2>&1)
    echo "  $NODE_NAME: Restarted"
  else
    HOST=$(jq -r ".nodes[\"$NODE_NAME\"].host" "$NODES_CONFIG")
    USER=$(jq -r ".nodes[\"$NODE_NAME\"].user // \"ubuntu\"" "$NODES_CONFIG")
    ssh "$USER@$HOST" "cd /opt/besu && docker-compose restart" > /dev/null 2>&1
    echo "  $NODE_NAME: Restarted"
  fi
done

# Cleanup after restart
rm "$ENODES_FILE"
if [ -f ".nodes.default.json" ]; then
  rm ".nodes.default.json"
fi

echo ""
echo "=== Peer Configuration Complete ==="
echo ""
echo "Wait 15 seconds for nodes to discover peers"
echo ""
echo "Next step: Verify network: npm run verify"
