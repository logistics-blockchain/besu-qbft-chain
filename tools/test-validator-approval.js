const { ethers } = require('ethers');
const fs = require('fs');

const CONTRACT_ADDRESS = '0x0000000000000000000000000000000000009999';
const RPC_URL = 'http://localhost:8545';

const ABI = JSON.parse(fs.readFileSync('abi.json', 'utf8'));

const adminPrivateKey = fs.readFileSync('besu-network/node0/key', 'utf8').trim();
const candidateWallet = ethers.Wallet.createRandom();

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);

  const adminWallet = new ethers.Wallet(adminPrivateKey, provider);
  const candidateWithProvider = candidateWallet.connect(provider);

  const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, provider);

  console.log('Admin address:', adminWallet.address);
  console.log('Candidate address:', candidateWallet.address);
  console.log();

  console.log('Step 1: Candidate applies to be validator...');
  const contractWithCandidate = contract.connect(candidateWithProvider);
  try {
    const applyTx = await contractWithCandidate.applyToBeValidator(
      'New Validator Org',
      'newvalidator@example.com',
      { gasLimit: 1000000 }
    );
    console.log('Application tx:', applyTx.hash);
    await applyTx.wait();
    console.log('Application submitted!');
  } catch (error) {
    console.log('Application failed:', error.message);
  }

  console.log();
  console.log('Step 2: Check application status...');
  const app = await contract.applications(candidateWallet.address);
  console.log('Application pending:', app.isPending);
  console.log('Organization:', app.organization);

  console.log();
  console.log('Step 3: Admin approves validator...');
  const contractWithAdmin = contract.connect(adminWallet);
  const approveTx = await contractWithAdmin.proposeApproval(
    candidateWallet.address,
    'Approved for testing',
    { gasLimit: 1000000 }
  );
  console.log('Approval tx:', approveTx.hash);
  await approveTx.wait();
  console.log('Validator approved!');

  console.log();
  console.log('Step 4: Verify validator was added...');
  const validators = await contract.getValidators();
  console.log('Total validators:', validators.length);
  const isValidator = await contract.isValidator(candidateWallet.address);
  console.log('Is candidate now a validator?', isValidator);

  console.log();
  console.log('Validators:');
  validators.forEach((v, i) => console.log(`  ${i + 1}. ${v}`));

  console.log();
  console.log('Candidate private key (for node5):', candidateWallet.privateKey);
  console.log('Candidate address:', candidateWallet.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
