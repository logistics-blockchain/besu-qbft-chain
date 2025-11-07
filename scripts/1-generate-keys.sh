#!/bin/bash
set -e

echo "Generating node keys..."

cd "$(dirname "$0")/.."

mkdir -p keys

# Determine node count from nodes.json or use default
if [ -f "nodes.json" ]; then
  NODE_COUNT=$(jq '.nodes | length' nodes.json)
  echo "Using nodes.json: $NODE_COUNT nodes configured"
else
  NODE_COUNT=4
  echo "No nodes.json found, using default: $NODE_COUNT nodes (3 validators + 1 non-validator)"
fi

# Generate node keys
for i in $(seq 1 $NODE_COUNT); do
  if [ ! -f "keys/node${i}.key" ]; then
    openssl rand -hex 32 > "keys/node${i}.key"
    echo "Generated keys/node${i}.key"
  else
    echo "keys/node${i}.key already exists, skipping"
  fi
done

echo ""
echo "Keys generated successfully"
echo "Next step: Extract validator addresses with npm run storage:calculate"
