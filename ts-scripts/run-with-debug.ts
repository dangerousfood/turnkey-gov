import { execSync } from 'child_process';

/**
 * Helper script to handle the --debug flag for commands
 * This script allows commands to be run like: pnpm deploy:prod --debug
 */

type CommandOption = {
  normal: string;
  debug: string;
};

type CommandMap = {
  [key: string]: CommandOption;
};

// Map of command arguments to actual command implementations
const COMMANDS: CommandMap = {
  'deploy:test': {
    normal: "dotenv -e .env -- bash -c 'ts-node ts-scripts/validate-env.ts && forge script script/Deploy.s.sol --chain-id \"$CHAIN_ID\" --rpc-url \"$RPC_URL\" --private-key \"$PRIVATE_KEY\"'",
    debug: "DEBUG=true dotenv -e .env -- bash -c 'ts-node ts-scripts/validate-env.ts && forge script script/Deploy.s.sol --chain-id \"$CHAIN_ID\" --rpc-url \"$RPC_URL\" --private-key \"$PRIVATE_KEY\"'"
  },
  'deploy:prod': {
    normal: "dotenv -e .env -- bash -c 'ts-node ts-scripts/validate-env.ts && forge script script/Deploy.s.sol --chain-id \"$CHAIN_ID\" --rpc-url \"$RPC_URL\" --private-key \"$PRIVATE_KEY\" --broadcast --slow' && pnpm verify",
    debug: "DEBUG=true dotenv -e .env -- bash -c 'ts-node ts-scripts/validate-env.ts && forge script script/Deploy.s.sol --chain-id \"$CHAIN_ID\" --rpc-url \"$RPC_URL\" --private-key \"$PRIVATE_KEY\" --broadcast --slow' && pnpm verify"
  },
  'renounce:test': {
    normal: "dotenv -e .env -- bash -c 'ts-node ts-scripts/validate-env.ts && forge script script/RenounceToGovernance.s.sol --chain-id \"$CHAIN_ID\" --rpc-url \"$RPC_URL\" --private-key \"$PRIVATE_KEY\" --slow'",
    debug: "DEBUG=true dotenv -e .env -- bash -c 'ts-node ts-scripts/validate-env.ts && forge script script/RenounceToGovernance.s.sol --chain-id \"$CHAIN_ID\" --rpc-url \"$RPC_URL\" --private-key \"$PRIVATE_KEY\" --slow'"
  },
  'renounce:prod': {
    normal: "dotenv -e .env -- bash -c 'ts-node ts-scripts/validate-env.ts && forge script script/RenounceToGovernance.s.sol --chain-id \"$CHAIN_ID\" --rpc-url \"$RPC_URL\" --private-key \"$PRIVATE_KEY\" --broadcast --slow'",
    debug: "DEBUG=true dotenv -e .env -- bash -c 'ts-node ts-scripts/validate-env.ts && forge script script/RenounceToGovernance.s.sol --chain-id \"$CHAIN_ID\" --rpc-url \"$RPC_URL\" --private-key \"$PRIVATE_KEY\" --broadcast --slow'"
  },
  'publish:tally': {
    normal: "dotenv -e .env -- ts-node ts-scripts/validate-env.ts && ts-node ts-scripts/publish-tally.ts",
    debug: "DEBUG=true dotenv -e .env -- ts-node ts-scripts/validate-env.ts && ts-node ts-scripts/publish-tally.ts"
  },
  'check:tally': {
    normal: "dotenv -e .env -- ts-node ts-scripts/validate-env.ts && ts-node ts-scripts/check-tally-dao.ts",
    debug: "DEBUG=true dotenv -e .env -- ts-node ts-scripts/validate-env.ts && ts-node ts-scripts/check-tally-dao.ts"
  }
};

// Get the command from the first argument
const commandArg = process.argv[2];

if (!commandArg || !COMMANDS[commandArg]) {
  console.error(`Error: Invalid or missing command: ${commandArg}`);
  console.error(`Available commands: ${Object.keys(COMMANDS).join(', ')}`);
  process.exit(1);
}

// Check if --debug flag is present in any of the arguments
const hasDebugFlag = process.argv.some(arg => arg === '--debug');

// Determine which command variant to run
const commandToRun = hasDebugFlag ? COMMANDS[commandArg].debug : COMMANDS[commandArg].normal;

// Log what's happening
if (hasDebugFlag) {
  console.log('Running command in DEBUG mode');
}

try {
  // Execute the command
  execSync(commandToRun, { stdio: 'inherit' });
} catch (error) {
  console.error(`Error executing command: ${error}`);
  process.exit(1);
} 