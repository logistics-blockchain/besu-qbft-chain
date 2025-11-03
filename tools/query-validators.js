const { ethers } = require('ethers');
const fs = require('fs');

const CONTRACT_ADDRESS = '0x0000000000000000000000000000000000009999';
const RPC_URL = 'http://localhost:8545';

const ABI = JSON.parse(fs.readFileSync('abi.json', 'utf8'));

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const contract = new ethers.Contract(CONTRACT_ADDRESS, ABI, provider);

  console.log('Querying contract at:', CONTRACT_ADDRESS);
  console.log();

  const validators = await contract.getValidators();
  console.log('Validators from contract:');
  validators.forEach((v, i) => console.log(`  ${i + 1}. ${v}`));

  console.log();
  const validatorCount = await contract.getValidatorCount();
  console.log('Validator count:', validatorCount.toString());

  console.log();
  const admins = await contract.getAdmins();
  console.log('Admins:');
  admins.forEach((a, i) => console.log(`  ${i + 1}. ${a}`));

  console.log();
  const threshold = await contract.getThreshold();
  console.log('Threshold:', threshold.toString());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
