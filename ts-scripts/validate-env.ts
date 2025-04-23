#!/usr/bin/env ts-node
import * as process from 'process';

// Define ANSI color codes for console output
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
};

// Function to validate required environment variables
const validateEnvVars = (): void => {
  const requiredVars = [
    'PRIVATE_KEY',
    'CHAIN_ID',
    'RPC_URL',
    'ETHERSCAN_API_KEY',
  ];
  
  const missingVars: string[] = [];
  
  // Check each required variable
  for (const varName of requiredVars) {
    if (!process.env[varName] || process.env[varName].trim() === '') {
      missingVars.push(varName);
    }
  }
  
  // If there are missing variables, display error and exit
  if (missingVars.length > 0) {
    console.error(`${colors.red}Error: Missing required environment variables:${colors.reset}`);
    missingVars.forEach(varName => {
      console.error(`  - ${colors.yellow}${varName}${colors.reset}`);
    });
    console.error(`\n${colors.blue}Please add these variables to your .env file or set them in your environment.${colors.reset}`);
    console.error(`${colors.blue}You can reference .env.sample for the required variables.${colors.reset}`);
    process.exit(1);
  }
  
  console.log(`${colors.green}✓ All required environment variables are set.${colors.reset}`);
};

// Main function
const main = (): void => {
  try {
    validateEnvVars();
  } catch (error) {
    console.error(`${colors.red}Unexpected error during environment validation:${colors.reset}`, error);
    process.exit(1);
  }
};

// Execute the main function
main(); 