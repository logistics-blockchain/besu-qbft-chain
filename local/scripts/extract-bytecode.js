const fs = require('fs');
const path = require('path');

async function main() {
  const artifactPath = path.join(__dirname, '../../artifacts/contracts/DynamicMultiSigValidatorManager.sol/DynamicMultiSigValidatorManager.json');

  if (!fs.existsSync(artifactPath)) {
    console.error('Contract not compiled. Run: npx hardhat compile');
    process.exit(1);
  }

  const artifact = JSON.parse(fs.readFileSync(artifactPath, 'utf8'));

  console.log('Contract: DynamicMultiSigValidatorManager');
  console.log('\n=== Deployment Bytecode (for deployment) ===');
  console.log(artifact.bytecode);
  console.log('\n=== Deployed Bytecode (for genesis file) ===');
  console.log(artifact.deployedBytecode);

  console.log('\n=== Contract ABI ===');
  console.log(JSON.stringify(artifact.abi, null, 2));

  fs.writeFileSync(
    path.join(__dirname, '../../deployedBytecode.txt'),
    artifact.deployedBytecode
  );

  fs.writeFileSync(
    path.join(__dirname, '../../abi.json'),
    JSON.stringify(artifact.abi, null, 2)
  );

  console.log('\n=== Files Created ===');
  console.log('deployedBytecode.txt - Use this in genesis file');
  console.log('abi.json - Use this for contract interaction');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
