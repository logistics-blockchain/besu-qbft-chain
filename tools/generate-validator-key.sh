#!/bin/bash
# Generate a new validator key pair for adding to the network

set -e

echo "=== Generate New Validator Key ==="
echo ""

# Check if Besu is installed
if ! command -v besu &> /dev/null; then
    echo "Error: Besu not found. Please install Besu first."
    exit 1
fi

# Create directory for new validator
NEW_VALIDATOR_DIR="new-validator-$(date +%s)"
mkdir -p "$NEW_VALIDATOR_DIR"

# Generate key pair
besu --data-path="$NEW_VALIDATOR_DIR" public-key export-address --to="$NEW_VALIDATOR_DIR/address.txt"

# Extract address
VALIDATOR_ADDRESS=$(cat "$NEW_VALIDATOR_DIR/address.txt")

echo "New validator key generated!"
echo ""
echo "Address: $VALIDATOR_ADDRESS"
echo "Private key: $NEW_VALIDATOR_DIR/key"
echo ""
echo "Next steps:"
echo "  1. Vote to add this validator: ./tools/vote-add-validator.sh $VALIDATOR_ADDRESS"
echo "  2. Start the validator node: ./tools/start-new-validator.sh $NEW_VALIDATOR_DIR"
echo ""
echo "IMPORTANT: Keep the private key secure!"
