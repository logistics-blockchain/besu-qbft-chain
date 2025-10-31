#!/bin/bash
# Reset blockchain data (WARNING: Destructive operation)

set -e

echo "========================================"
echo "Besu Chain Reset"
echo "========================================"
echo ""
echo "WARNING: This will delete ALL blockchain data!"
echo "  - All blocks will be erased"
echo "  - All deployed contracts will be gone"
echo "  - Transaction history will be lost"
echo ""
read -p "Are you sure you want to continue? (type 'yes'): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Reset cancelled."
    exit 0
fi

echo ""
echo "Stopping Besu network..."
./local/scripts/stop.sh

echo ""
echo "Deleting blockchain data..."
rm -rf besu-data/

echo ""
echo "Blockchain data deleted."
echo ""
echo "Next steps:"
echo "  1. Start network: ./local/scripts/start.sh"
echo "  2. Redeploy contracts"
echo ""
echo "Note: Validator keys and genesis file are preserved."
