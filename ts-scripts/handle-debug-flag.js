/**
 * Helper script to handle the --debug flag for deploy commands
 * Usage: node handle-debug-flag.js deploy:test [--debug]
 */

const { execSync } = require('child_process');

// Get the command from the first argument
const command = process.argv[2];

if (!command) {
  console.error('Error: No command specified');
  console.error('Usage: node handle-debug-flag.js <command> [--debug]');
  process.exit(1);
}

// Check if --debug flag is present in any of the arguments
const hasDebugFlag = process.argv.some(arg => arg === '--debug');

// Determine which script to run based on the debug flag
const scriptToRun = hasDebugFlag ? `${command}:debug` : `${command}:no-debug`;

console.log(`Running: pnpm ${scriptToRun}`);

try {
  // Execute the appropriate script
  execSync(`pnpm ${scriptToRun}`, { stdio: 'inherit' });
} catch (error) {
  console.error(`Error executing command: ${error.message}`);
  process.exit(1);
} 