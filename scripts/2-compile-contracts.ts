#!/usr/bin/env tsx
import { execSync } from 'child_process';
import { copyFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';

console.log('Compiling validator contract...');

const rootDir = join(__dirname, '..');
const contractsDir = join(rootDir, 'contracts');
const artifactsDir = join(rootDir, 'artifacts');

// Ensure contracts directory has node_modules
if (!existsSync(join(contractsDir, 'node_modules'))) {
  console.log('Installing contract dependencies...');
  execSync('npm install', { cwd: contractsDir, stdio: 'inherit' });
}

// Compile contracts
try {
  execSync('npx hardhat compile', { cwd: contractsDir, stdio: 'inherit' });
} catch (error) {
  console.error('Compilation failed');
  process.exit(1);
}

// Ensure artifacts directory exists
if (!existsSync(artifactsDir)) {
  mkdirSync(artifactsDir, { recursive: true });
}

// Copy artifact
const artifactSource = join(
  contractsDir,
  'artifacts/src/DynamicMultiSigValidatorManager.sol/DynamicMultiSigValidatorManager.json'
);
const artifactDest = join(artifactsDir, 'DynamicMultiSigValidatorManager.json');

if (existsSync(artifactSource)) {
  copyFileSync(artifactSource, artifactDest);
  console.log('\nContract compiled successfully');
  console.log(`Artifact copied to: ${artifactDest}`);
} else {
  console.error('Error: Artifact not found after compilation');
  process.exit(1);
}
