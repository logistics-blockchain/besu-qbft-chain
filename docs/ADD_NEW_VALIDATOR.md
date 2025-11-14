# Joining an Existing Network

Complete guide for joining a running Besu QBFT blockchain network as a validator.

---

## Prerequisites

**Request from network operator:**
- `genesis.json` - Network genesis configuration
- `static-nodes-template.json` - Existing validator enode URLs
- `DynamicMultiSigValidatorManager.json` - Contract ABI
- Block 0 hash for verification
- RPC endpoint for testing

**Your infrastructure:**
- Target server meeting hardware requirements (4GB RAM, 50GB storage)
- SSH access (for remote deployment)

**IMPORTANT:** Your genesis file must match the network's configuration exactly, including fork settings. Mismatched genesis configurations (especially fork versions like Berlin vs London vs Shanghai) will cause transaction failures and sync issues.

## Step 0: Verify Genesis File

**Your node WILL FAIL if genesis doesn't match the network.**

Verify before deploying:

```bash
# Get network genesis hash from existing node
curl -X POST --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x0",false],"id":1}' \
  http://EXISTING_NODE_IP:8545 | jq -r '.result.hash'

# Save this hash - you'll compare it with your local genesis after obtaining it
```

If hashes don't match after you get genesis: Request correct genesis from network operator and start over.

## Step 1: Get Genesis File

Retrieve the genesis file from any existing node:

```bash
# From remote node
scp ubuntu@EXISTING_NODE_IP:/opt/besu/genesis.json ./genesis.json

# Or from local deployment
cp /path/to/besuchain/artifacts/genesis.json ./genesis.json
```

**Verify genesis hash matches network:**

```bash
# Calculate hash from your genesis file using existing node
curl -X POST --data "{\"jsonrpc\":\"2.0\",\"method\":\"debug_storageRangeAt\",\"params\":[\"0x0\",0,\"0x0\",null,1],\"id\":1}" \
  http://EXISTING_NODE_IP:8545

# Simpler: Deploy test node, get block 0 hash, compare with network hash from Step 0
# Or ask network operator to confirm your genesis hash matches
```

## Step 2: Generate Node Key

```bash
openssl rand -hex 32 > node-new.key
```

Derive the validator address (needed for contract approval):

```bash
# Install viem if not available: npm install -g viem
node -e "
const {privateKeyToAccount} = require('viem/accounts');
const fs = require('fs');
const key = '0x' + fs.readFileSync('node-new.key', 'utf-8').trim();
const account = privateKeyToAccount(key);
console.log('Validator Address:', account.address);
"
```

Save the address - you'll need it for contract approval.

## Step 3: Deploy Node

**Create deployment directory:**

```bash
sudo mkdir -p /opt/besu
sudo chown $USER:$USER /opt/besu
cd /opt/besu
```

**Copy files:**

```bash
# Copy genesis and node key
cp /path/to/genesis.json /opt/besu/
cp /path/to/node-new.key /opt/besu/node.key
```

**Create docker-compose.yml:**

```yaml
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
```

**Start node:**

```bash
docker-compose up -d
```

## Step 3.5: Configure Firewall

**Open required ports:**

```bash
# Ubuntu (ufw)
sudo ufw allow 8545/tcp
sudo ufw allow 30303/tcp
sudo ufw allow 30303/udp
sudo ufw reload

# Cloud providers (Oracle Cloud, AWS, GCP, Azure):
# Update Security Group/Security List in cloud console
# - Allow TCP port 8545 (RPC access)
# - Allow TCP port 30303 (P2P)
# - Allow UDP port 30303 (P2P discovery)
```

**Verify ports are accessible:**

```bash
# From another machine, test connectivity
nc -zv YOUR_NODE_IP 8545
nc -zv YOUR_NODE_IP 30303
```

## Step 4: Configure Peer Discovery

**Get new node's enode:**

```bash
docker logs besu-validator 2>&1 | grep "enode://" | head -1
```

Extract the public key and create the enode URL:
```
enode://PUBLIC_KEY@NEW_NODE_IP:30303
```

**Add existing network peers to new node:**

Use the `static-nodes-template.json` file provided by network operator:

```bash
# Copy the template to static-nodes.json
cp static-nodes-template.json static-nodes.json

# Deploy to container
docker cp static-nodes.json besu-validator:/data/
docker-compose restart
```

Example format (get actual file from operator):
```json
[
  "enode://PUBKEY1@IP1:30303",
  "enode://PUBKEY2@IP2:30303",
  "enode://PUBKEY3@IP3:30303",
  "enode://PUBKEY4@IP4:30303"
]
```

**Add new node to existing network (recommended for production):**

For stable bidirectional connections, have the network operator add your enode to existing nodes' static-nodes.json and restart them.

**Two-way coordination (recommended):**

- **You do:** Configure your static-nodes.json with existing nodes' enodes (steps above)
- **Network operator does:** Add your enode to existing nodes' static-nodes.json and restart them

**Why bidirectional?** Ensures both sides actively maintain connection. Without it, connection might work but be less stable.

**Can it work without operator adding your enode?** Yes. Discovery is enabled by default in this network. Your node connects → existing nodes accept inbound connection. However, for production networks, bidirectional static nodes are recommended for guaranteed reconnection and more stable connections.

**Testing/development shortcut:** If coordinating with operator is difficult, you can proceed without them adding your enode. Monitor peer count - if you see expected peers (total_nodes - 1), network is working.

**Communication template for network operator:**

```
Subject: New Node Peer Configuration

My enode: enode://YOUR_PUBKEY@YOUR_IP:30303

Please add to existing nodes' static-nodes.json files and restart nodes.
```

## Step 5: Verify Synchronization

Wait 15-20 seconds for peer discovery, then check:

```bash
# Check peer count (should be total_nodes - 1)
# Example: 4 node network = 3 peers
curl -X POST --data '{"jsonrpc":"2.0","method":"net_peerCount","params":[],"id":1}' http://NEW_NODE_IP:8545

# Check block number (should match network)
curl -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://NEW_NODE_IP:8545
```

**Expected peer count:** (Total nodes - 1). If peer count is 0, check firewall and verify operator added your enode.

The node is now synced but **not yet a validator**.

## Transaction Type Warning

**Berlin fork (pre-EIP-1559) requires legacy transactions.**

All `cast send` commands in the following steps MUST include `--legacy` flag.

**Without `--legacy`:** "Max priority fee per gas exceeds max fee per gas" error

## Step 6: Get Validator Approval

The new validator must be approved through the validator contract governance process.

Choose the path that applies to your situation:

---

### Path A: You Are An Admin

If you control admin keys, you can create and sign proposals yourself.

**6a. Apply to be validator:**

```bash
cast send 0x0000000000000000000000000000000000009999 \
  "applyToBeValidator(string,string)" \
  "Your Organization" \
  "contact@yourdomain.com" \
  --private-key YOUR_NODE_PRIVATE_KEY \
  --rpc-url http://YOUR_NODE_IP:8545 \
  --gas-price 0 \
  --legacy
```

**6b. Propose your own approval (using admin key):**

```bash
cast send 0x0000000000000000000000000000000000009999 \
  "proposeApproval(address,string)" \
  YOUR_VALIDATOR_ADDRESS \
  "Self approval" \
  --private-key YOUR_ADMIN_PRIVATE_KEY \
  --rpc-url http://YOUR_NODE_IP:8545 \
  --gas-price 0 \
  --legacy
```

**6c. Get proposal ID and have other admins sign:**

```bash
# Get proposal ID
PROPOSAL_COUNT=$(cast call 0x0000000000000000000000000000000000009999 \
  "validatorProposalCount()" --rpc-url http://YOUR_NODE_IP:8545)
# Latest proposal ID = (PROPOSAL_COUNT - 1)
# Example: 0x3 = 3 decimal, latest proposal ID = 2

# Other admins sign (if multi-sig required)
cast send 0x0000000000000000000000000000000000009999 \
  "signValidatorProposal(uint256)" \
  PROPOSAL_ID \
  --private-key OTHER_ADMIN_PRIVATE_KEY \
  --rpc-url http://NODE_IP:8545 \
  --gas-price 0 \
  --legacy
```

**6d. Automatic execution:**

When threshold is reached, proposal executes automatically. Restart your node to begin validating:

```bash
docker-compose restart
```

---

### Path B: You Need Admin Approval

If you don't control admin keys, request approval from network operator.

**6a. Apply to be validator:**

```bash
cast send 0x0000000000000000000000000000000000009999 \
  "applyToBeValidator(string,string)" \
  "Your Organization" \
  "contact@yourdomain.com" \
  --private-key YOUR_NODE_PRIVATE_KEY \
  --rpc-url http://YOUR_NODE_IP:8545 \
  --gas-price 0 \
  --legacy
```

**6b. Contact network operator:**

```
Subject: Validator Approval Request

Validator Address: 0xYOUR_ADDRESS
Organization: Your Organization Name
Contact Email: contact@yourdomain.com
Enode: enode://YOUR_PUBKEY@YOUR_IP:30303

Please propose and approve my validator application.
```

**6c. Monitor approval status:**

```bash
# Check if you're in validator set
cast call 0x0000000000000000000000000000000000009999 \
  "getValidators()" \
  --rpc-url http://YOUR_NODE_IP:8545 | grep -i YOUR_ADDRESS

# Or use validator frontend UI to monitor pending proposals
```

**6d. After approval, restart node:**

Once approved (you'll see your address in validator set), restart to begin validating:

```bash
docker-compose restart
```

## Verification

Confirm the new validator is active:

```bash
cast call 0x0000000000000000000000000000000000009999 \
  "getValidators()" \
  --rpc-url http://NEW_NODE_IP:8545
```

The new validator address should appear in the returned array.

## Troubleshooting

**"Max priority fee per gas exceeds max fee per gas" error:**
- **Cause:** Network runs Berlin fork (no EIP-1559), but cast defaults to EIP-1559 transactions
- **Solution:** Add `--legacy` flag to all `cast send` commands
- **Verification:** Ensure your node's genesis matches the network exactly
- Check genesis fork config: `docker exec besu-validator cat /opt/besu/genesis.json | grep -E "berlinBlock|londonBlock|shanghaiTime"`
- Compare genesis hash with network:
  ```bash
  # Your new node
  curl -X POST --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x0",false],"id":1}' \
    http://NEW_NODE_IP:8545 | jq -r '.result.hash'

  # Existing network node (should match exactly)
  curl -X POST --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x0",false],"id":1}' \
    http://EXISTING_NODE_IP:8545 | jq -r '.result.hash'
  ```
- If hashes don't match: Obtain correct genesis from network, wipe data, redeploy

**Node stays at block 0:**
- Verify genesis hash matches: check logs for genesis hash, compare with existing nodes
- Check peer count is greater than 0

**Peer count is 0:**
- Verify enode URLs are reachable
- Check firewall allows port 30303
- Verify static-nodes.json format is valid JSON

**Not participating in consensus after approval:**
- Verify validator address matches node key address
- Check contract shows validator in approved list
- Restart node to ensure it reads updated validator set
- Check logs for QBFT consensus messages
