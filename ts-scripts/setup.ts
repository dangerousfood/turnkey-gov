import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Check if a command is available
 */
function commandExists(command: string): boolean {
  try {
    execSync(`command -v ${command}`, { stdio: 'ignore' });
    return true;
  } catch (error) {
    return false;
  }
}

/**
 * Print colored message
 */
function colorize(message: string, color: 'red' | 'green' | 'yellow' | 'blue'): string {
  const colors = {
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    reset: '\x1b[0m'
  };
  return `${colors[color]}${message}${colors.reset}`;
}

/**
 * Check if all required dependencies are installed
 */
function checkDependencies(): boolean {
  console.log(colorize('Checking dependencies...', 'blue'));
  
  const dependencies = [
    { name: 'git', message: 'Git is required for version control and submodules' },
    { name: 'node', message: 'Node.js is required to run JavaScript/TypeScript code' },
    { name: 'pnpm', message: 'PNPM is required for package management' },
    { name: 'forge', message: 'Forge (Foundry) is required for smart contract development' }
  ];
  
  let allDependenciesExist = true;
  
  for (const dep of dependencies) {
    if (commandExists(dep.name)) {
      console.log(colorize(`✓ ${dep.name} is installed`, 'green'));
    } else {
      console.log(colorize(`✗ ${dep.name} is not installed - ${dep.message}`, 'red'));
      allDependenciesExist = false;
    }
  }
  
  return allDependenciesExist;
}

/**
 * Run the installation steps
 */
function runInstallation() {
  console.log(colorize('\nInitializing project...', 'blue'));
  
  // Step 1: Update git submodules
  try {
    console.log(colorize('Updating git submodules...', 'yellow'));
    execSync('git submodule update --init --recursive', { stdio: 'inherit' });
  } catch (error) {
    console.error(colorize('Failed to update git submodules', 'red'));
    throw error;
  }
  
  // Step 2: Install dependencies
  try {
    console.log(colorize('Installing dependencies...', 'yellow'));
    execSync('pnpm i', { stdio: 'inherit' });
  } catch (error) {
    console.error(colorize('Failed to install dependencies', 'red'));
    throw error;
  }
  
  // Step 3: Copy .env.sample to .env if .env doesn't exist
  try {
    const envPath = path.join(process.cwd(), '.env');
    const envSamplePath = path.join(process.cwd(), '.env.sample');
    
    console.log(colorize(`Checking for .env file at: ${envPath}`, 'yellow'));
    const envExists = fs.existsSync(envPath);
    console.log(colorize(`Checking for .env.sample file at: ${envSamplePath}`, 'yellow'));
    const envSampleExists = fs.existsSync(envSamplePath);
    
    if (!envExists && envSampleExists) {
      console.log(colorize('Creating .env file from .env.sample...', 'yellow'));
      fs.copyFileSync(envSamplePath, envPath);
      
      // Verify the file was created
      if (fs.existsSync(envPath)) {
        console.log(colorize('✓ .env file created successfully', 'green'));
      } else {
        console.error(colorize('✗ Failed to create .env file', 'red'));
      }
    } else if (envExists) {
      console.log(colorize('Existing .env file detected, preserving your configuration...', 'yellow'));
    } else {
      if (!envSampleExists) {
        console.error(colorize('✗ .env.sample file not found. Cannot create .env file.', 'red'));
        console.log(colorize('You will need to create an .env file manually before running the app.', 'yellow'));
      } else {
        console.error(colorize('✗ Unknown error when handling .env files', 'red'));
      }
    }
  } catch (error: any) {
    console.error(colorize(`Failed to create .env file: ${error.message}`, 'red'));
    console.error(error);
  }
  
  console.log(colorize('\nSetup completed successfully! ✅', 'green'));
  console.log(colorize('Next steps:', 'blue'));
  console.log(' 1. Edit the .env file with your configuration');
  console.log(' 2. Fund your wallet');
  console.log(' 3. Configure deployment in deploy.config.json');
  console.log(' 4. Run deployment with `pnpm deploy:test`');
}

/**
 * Main function
 */
function main() {
  console.log(colorize('Turnkey Governor Setup', 'blue'));
  console.log(colorize('=====================', 'blue'));
  
  const dependenciesOk = checkDependencies();
  
  if (!dependenciesOk) {
    console.error(colorize('\nSetup failed: missing dependencies ❌', 'red'));
    console.log('Please install the missing dependencies and try again:');
    console.log(colorize('\nInstallation instructions:', 'yellow'));
    console.log(' • git: https://git-scm.com/downloads');
    console.log(' • node: https://nodejs.org/en/download/');
    console.log(' • pnpm: npm install -g pnpm');
    console.log(' • forge: https://book.getfoundry.sh/getting-started/installation');
    process.exit(1);
  }
  
  runInstallation();
}

// Run the main function
main(); 