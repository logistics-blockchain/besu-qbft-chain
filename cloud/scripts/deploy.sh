#!/bin/bash
# Deploy Besu nodes to cloud instances
# This is a template - customize for your cloud provider

set -e

echo "Besu Cloud Deployment"
echo "====================="
echo ""

# Check if genesis and keys exist locally
if [ ! -f "besu-network/genesis.json" ]; then
    echo "ERROR: Genesis file not found"
    echo "Run ./local/scripts/setup.sh first to generate network files"
    exit 1
fi

# Check if SSH config is set
if [ -z "$INSTANCE_1_IP" ] || [ -z "$INSTANCE_2_IP" ]; then
    echo "ERROR: Instance IPs not set"
    echo "Export INSTANCE_1_IP and INSTANCE_2_IP environment variables"
    echo ""
    echo "Example:"
    echo "  export INSTANCE_1_IP=1.2.3.4"
    echo "  export INSTANCE_2_IP=5.6.7.8"
    exit 1
fi

echo "Deploying to instances:"
echo "  Instance 1: $INSTANCE_1_IP"
echo "  Instance 2: $INSTANCE_2_IP"
echo ""

# Copy genesis file to both instances
echo "Uploading genesis file..."
scp besu-network/genesis.json ubuntu@$INSTANCE_1_IP:/opt/besu/
scp besu-network/genesis.json ubuntu@$INSTANCE_2_IP:/opt/besu/

# Copy validator keys
echo "Uploading validator keys..."
VALIDATORS=($(ls besu-network/keys/))

# Instance 1: Validators 0 and 1
scp -r besu-network/keys/${VALIDATORS[0]} ubuntu@$INSTANCE_1_IP:/opt/besu/keys/
scp -r besu-network/keys/${VALIDATORS[1]} ubuntu@$INSTANCE_2_IP:/opt/besu/keys/

# Copy docker-compose file
echo "Uploading docker-compose configuration..."
scp cloud/docker/docker-compose.yml ubuntu@$INSTANCE_1_IP:/opt/besu/
scp cloud/docker/docker-compose.yml ubuntu@$INSTANCE_2_IP:/opt/besu/

echo ""
echo "Deployment complete!"
echo ""
echo "Next steps:"
echo "  1. SSH to instance 1: ssh ubuntu@$INSTANCE_1_IP"
echo "  2. Start node: cd /opt/besu && docker-compose up -d"
echo "  3. Check logs: docker logs -f besu-node"
echo ""
echo "Repeat for instance 2."
