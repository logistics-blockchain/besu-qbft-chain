# External Validator Guide

Guide for network operators on onboarding external validators to the network.

## Overview

External validators can join the QBFT network through a voting process. This guide covers generating validator packages, the approval workflow, and ongoing validator management.

## Validator Onboarding Process

### Phase 1: Package Generation (Network Operators)

Generate a validator package containing network configuration:

```bash
./tools/generate-validator-package.sh
```

This creates a timestamped package directory with:
- Genesis file
- Network configuration
- Setup scripts
- Documentation

### Phase 2: Package Distribution

Compress and send to the validator candidate:

```bash
tar -czf validator-package-20250131-120000.tar.gz validator-package-20250131-120000/
# Send via secure channel (email, secure file transfer, etc.)
```

### Phase 3: Validator Setup (External Validator)

Validator extracts package and runs setup:

```bash
tar -xzf validator-package-20250131-120000.tar.gz
cd validator-package-20250131-120000
./setup-validator.sh
```

This generates their validator keypair and provides their address.

### Phase 4: Voting (Network Operators)

Validator sends their address to network operators. Vote to add them:

```bash
# From each existing validator node
./tools/vote-add-validator.sh 0xVALIDATOR_ADDRESS

# Or specify RPC endpoint
RPC_ENDPOINT=http://localhost:8547 ./tools/vote-add-validator.sh 0xVALIDATOR_ADDRESS
```

Voting requirements:
- **>50% of current validators** must vote
- Each validator submits one vote via their node
- Vote is included in blocks they produce
- Validator is added automatically when threshold reached

### Phase 5: Activation (External Validator)

Once approved (confirmed with `check-validator-status.sh`), start the validator:

```bash
./start-validator.sh
```

Monitor status:

```bash
./check-validator-status.sh
tail -f validator.log
```

## Package Contents

### Files Included

| File | Purpose |
|------|---------|
| `genesis.json` | Network genesis configuration |
| `network-config.json` | Chain ID, bootnode, parameters |
| `setup-validator.sh` | Generate validator keys |
| `start-validator.sh` | Start validator node |
| `stop-validator.sh` | Stop validator node |
| `check-validator-status.sh` | Check validator status |
| `README.md` | Validator instructions |

### Scripts Overview

**setup-validator.sh**
- Checks Besu installation
- Generates validator keypair
- Outputs validator address
- Creates validator-data directory

**start-validator.sh**
- Validates setup completed
- Starts Besu validator node
- Connects to bootnode
- Enables mining/consensus

**check-validator-status.sh**
- Checks process status
- Verifies RPC connectivity
- Shows current block
- Displays peer count
- Confirms validator set membership

## Network Operator Responsibilities

### Before Onboarding

1. **Vet validator candidates**
   - Technical capability
   - Infrastructure reliability
   - Commitment to uptime
   - Security practices

2. **Prepare infrastructure**
   - Ensure bootnode is stable
   - Verify network capacity
   - Plan for increased validator count

3. **Document expectations**
   - Uptime requirements
   - Update procedures
   - Communication channels
   - Incident response

### During Onboarding

1. **Generate fresh package**
   - Always use current genesis
   - Verify bootnode enode is correct
   - Test package before distribution

2. **Coordinate voting**
   - Contact existing validators
   - Confirm majority support
   - Submit votes in timely manner

3. **Monitor activation**
   - Verify validator joins network
   - Check peer connectivity
   - Confirm block participation

### After Onboarding

1. **Monitor performance**
   - Track validator uptime
   - Monitor block production
   - Check network health impact

2. **Maintain communication**
   - Regular status updates
   - Coordinate maintenance windows
   - Share network developments

3. **Provide support**
   - Answer technical questions
   - Assist with troubleshooting
   - Facilitate network upgrades

## Validator Requirements

### Technical Requirements

**Hardware:**
- CPU: 2+ cores
- RAM: 4GB+ (8GB recommended)
- Disk: 100GB+ SSD
- Network: Stable broadband

**Software:**
- Hyperledger Besu (latest stable)
- Java 17+
- Linux or macOS

**Network:**
- Open port 30303 (P2P)
- Static IP or DDNS recommended
- Firewall configured correctly

### Operational Requirements

**Uptime:**
- 99%+ availability target
- Minimal unplanned downtime
- Scheduled maintenance coordinated

**Security:**
- Private key protection
- Server hardening
- Regular security updates
- Monitoring and alerting

**Maintenance:**
- Keep Besu updated
- Monitor disk space
- Regular backups
- Log retention

## Voting Process

### Threshold Calculation

| Current Validators | Votes Needed |
|-------------------|--------------|
| 2 | 2 (both) |
| 3 | 2 |
| 4 | 3 |
| 5 | 3 |
| 6 | 4 |
| 7 | 4 |
| 8 | 5 |
| 9 | 5 |
| 10 | 6 |

Formula: Need **more than 50%** (e.g., 4/7 = 57%)

### Voting Commands

**Check current validators:**
```bash
./tools/get-validators.sh
```

**Submit vote:**
```bash
./tools/vote-add-validator.sh 0xNEW_VALIDATOR_ADDRESS
```

**Check pending votes:**
```bash
./tools/check-pending-votes.sh
```

**Vote from specific node:**
```bash
RPC_ENDPOINT=http://validator-node:8545 ./tools/vote-add-validator.sh 0xADDRESS
```

### Vote Lifecycle

1. **Proposed** - Validator submits vote
2. **Pending** - Vote included in blocks
3. **Threshold Met** - >50% votes collected
4. **Executed** - Validator added to set
5. **Active** - Validator participates in consensus

## Security Considerations

### For Network Operators

**Package Distribution:**
- Use secure channels (encrypted email, secure file transfer)
- Verify recipient identity
- Consider package integrity (checksums, signatures)

**Voting:**
- Verify validator address authenticity
- Confirm candidate vetting completed
- Document approval process

**Access Control:**
- Limit who can generate packages
- Audit validator additions
- Maintain validator registry

### For Validators

**Private Keys:**
- Never share private key
- Store securely (hardware wallet, encrypted storage)
- Back up to secure location
- Use strong passwords/encryption

**Node Security:**
- Harden server (firewall, SSH keys)
- Regular security updates
- Monitor for intrusions
- Use fail2ban or similar

**Network Security:**
- Don't expose unnecessary ports
- Use VPN for management access
- Enable logging and monitoring
- Implement rate limiting

## Troubleshooting

### Package Generation Fails

**Problem:** Cannot find genesis or bootnode

**Solutions:**
- Ensure network is running
- Check `besu-data/node0.log` exists
- Verify genesis file in `besu-network/`
- Try restarting network

### Validator Cannot Connect

**Problem:** New validator shows 0 peers

**Solutions:**
- Verify P2P port (30303) is open
- Check bootnode enode is correct
- Confirm firewall rules
- Review validator logs

### Validator Not in Set

**Problem:** Approved but not validating

**Solutions:**
- Confirm >50% voted
- Check with `qbft_getValidatorsByBlockNumber`
- Wait a few blocks after approval
- Restart validator node

### Vote Doesn't Register

**Problem:** Vote submitted but not pending

**Solutions:**
- Verify QBFT API enabled on node
- Check node is producing blocks
- Confirm validator address correct
- Review node logs for errors

## Best Practices

### Package Management

- Generate fresh packages for each candidate
- Version packages with timestamps
- Keep package generation history
- Test packages before distribution

### Validator Vetting

- Interview candidates
- Review infrastructure plans
- Test communication responsiveness
- Start with trial period

### Network Growth

- Add validators gradually
- Maintain odd validator count when possible
- Plan for geographic distribution
- Balance validator capabilities

### Documentation

- Maintain validator registry
- Document each addition
- Track validator performance
- Update procedures regularly

## Advanced Topics

### Multiple Validators from One Operator

Operator can run multiple validators:

1. Generate separate packages
2. Each validator needs unique:
   - Keypair
   - Data directory
   - P2P port
   - RPC port
3. Vote for each validator separately

### Validator Migration

Moving validator to new infrastructure:

1. Generate keys on new server
2. Vote to add new validator
3. Once active, vote to remove old validator
4. No downtime if done sequentially

### Disaster Recovery

If validator loses keys:

1. Generate new keypair
2. Request voting for new address
3. Old validator automatically excluded (cannot sign)
4. Vote to remove old address (cleanup)

## Monitoring and Metrics

### Key Metrics to Track

**Per Validator:**
- Uptime percentage
- Block production count
- Missed blocks
- Peer count
- Sync status

**Network Wide:**
- Total validators
- Consensus participation rate
- Network block time
- Validator churn rate

### Alerting

Set up alerts for:
- Validator offline
- Low peer count (<2)
- Sync issues
- High resource usage
- Security events

## Support Resources

### For Network Operators

- [Validator Management Guide](VALIDATOR_MANAGEMENT.md)
- [QBFT Consensus Documentation](https://besu.hyperledger.org/)
- Besu GitHub Issues
- Hyperledger Discord

### For External Validators

- Package README.md
- Network operator contact
- Community channels
- Technical documentation

## Appendix

### Example Workflow

Complete example of onboarding a validator:

```bash
# Network Operator: Generate package
./tools/generate-validator-package.sh
# Output: validator-package-20250131-120000/

# Network Operator: Compress and send
tar -czf validator-package.tar.gz validator-package-20250131-120000/
# Send to validator@example.com

# Validator: Extract and setup
tar -xzf validator-package.tar.gz
cd validator-package-20250131-120000
./setup-validator.sh
# Output: Validator address: 0xABCD...1234

# Validator: Send address to operators
# Email: "My validator address is 0xABCD...1234"

# Network Operator: Vote (from 3 of 4 validators)
./tools/vote-add-validator.sh 0xABCD...1234
RPC_ENDPOINT=http://localhost:8547 ./tools/vote-add-validator.sh 0xABCD...1234
RPC_ENDPOINT=http://localhost:8548 ./tools/vote-add-validator.sh 0xABCD...1234

# Network Operator: Confirm added
./tools/get-validators.sh
# Shows 5 validators including 0xABCD...1234

# Network Operator: Notify validator
# Email: "You're approved! Start your validator now."

# Validator: Start node
./start-validator.sh
# Output: ✓ Validator started!

# Validator: Check status
./check-validator-status.sh
# Output: ✓ Status: ACTIVE VALIDATOR
```

### Package Structure

```
validator-package-20250131-120000/
├── README.md                      # Validator instructions
├── genesis.json                   # Network genesis
├── network-config.json            # Network parameters
├── setup-validator.sh            # Setup script
├── start-validator.sh            # Start script
├── stop-validator.sh             # Stop script
└── check-validator-status.sh     # Status script
```

After setup:
```
validator-package-20250131-120000/
├── ...                           # Original files
├── validator-data/               # Generated
│   ├── key                       # Private key (SECURE!)
│   └── key.pub                   # Public key
├── validator-address.txt         # Public address
├── validator.pid                 # Process ID (when running)
└── validator.log                 # Node logs
```
