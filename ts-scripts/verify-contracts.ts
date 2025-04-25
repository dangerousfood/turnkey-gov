import { exec } from 'child_process';
import { promises as fs } from 'node:fs';
import * as process from 'process';
import * as path from 'path';

// Define ANSI color codes for console output
const colors = {
  reset: '\x1b[0m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
};

const THREE_SECONDS = 3000;

// Define command line arguments interface
interface CommandLineArgs {
  chainId: string;
  etherscan: string;
  rpcUrl: string;
  target?: string;
  script?: string;
  contracts?: string;
}

// Parse command line arguments
const parseArgs = async (): Promise<CommandLineArgs> => {
  const args: Partial<CommandLineArgs> = {};
  
  // Check for help flag
  if (process.argv.includes('--help')) {
    showHelp();
    process.exit(0);
  }
  
  // Process command line arguments
  for (let i = 2; i < process.argv.length; i++) {
    const arg = process.argv[i];
    if (arg.startsWith('--')) {
      const key = arg.slice(2).split('=')[0];
      const value = arg.includes('=') ? arg.split('=')[1] : process.argv[++i];
      args[key as keyof CommandLineArgs] = value;
    }
  }
  
  // Validate required arguments
  if (!args.chainId) {
    throw new Error('Missing required argument: --chainId');
  }
  if (!args.etherscan) {
    throw new Error('Missing required argument: --etherscan');
  }
  if (!args.rpcUrl) {
    throw new Error('Missing required argument: --rpcUrl');
  }
  
  // Set defaults for optional arguments
  args.target = args.target || 'latest';
  
  // If script is not provided, find the first script in the script folder
  if (!args.script) {
    args.script = await findDefaultScript();
  }
  
  // At this point, args.script is guaranteed to be defined
  return {
    chainId: args.chainId!,
    etherscan: args.etherscan!,
    rpcUrl: args.rpcUrl!,
    target: args.target,
    script: args.script,
    contracts: args.contracts
  };
};

// Function to find the default script
const findDefaultScript = async (): Promise<string> => {
  try {
    // Read all files in the script directory
    const scriptDir = './script';
    const files = await fs.readdir(scriptDir);
    
    // Filter for .sol files
    const solFiles = files.filter(file => file.endsWith('.sol'));
    
    if (solFiles.length === 0) {
      throw new Error('No deploy scripts found in the script directory');
    }
    
    // Check if Deploy.s.sol exists and use it as default
    if (solFiles.includes('Deploy.s.sol')) {
      return 'Deploy.s.sol';
    }
    
    // Otherwise, use the first .sol file
    return solFiles[0];
  } catch (error) {
    console.error(`${colors.red}Error finding default script:${colors.reset}`, error);
    throw new Error('Failed to find a default script. Please specify a script with --script');
  }
};

// Function to display help information
const showHelp = (): void => {
  console.log(`
${colors.cyan}Contract Verification Script${colors.reset}
${colors.yellow}Usage:${colors.reset}
  ts-node ts-scripts/verify-contracts.ts [options]

${colors.yellow}Required Options:${colors.reset}
  --chainId=<id>         The chain ID of the network (e.g., 1 for Ethereum mainnet, 11155111 for Sepolia)
  --etherscan=<key>      Your Etherscan API key
  --rpcUrl=<url>         RPC URL for the network

${colors.yellow}Optional Options:${colors.reset}
  --target=<target>      Target deployment by block number (default: 'latest')
  --script=<script>      Deployment script name (default: 'Deploy.s.sol')
  --contracts=<list>     Comma-separated list of specific contracts to verify
  --help                 Display this help message

${colors.yellow}Examples:${colors.reset}
  # Verify all contracts from the latest deployment on Sepolia
  ts-node ts-scripts/verify-contracts.ts --chainId=11155111 --etherscan=YOUR_API_KEY --rpcUrl=https://sepolia.infura.io/v3/YOUR_PROJECT_ID

  # Verify specific contracts from a deployment
  ts-node ts-scripts/verify-contracts.ts --chainId=1 --etherscan=YOUR_API_KEY --rpcUrl=https://mainnet.infura.io/v3/YOUR_PROJECT_ID --contracts=UngovernableGovernor,UngovernableERC20
  `);
};

const getCompilerVersion = async(contractName: string): Promise<string> => {
  try {
    const data = await fs.readFile(`./out/${contractName}.sol/${contractName}.json`);
    const abi = JSON.parse(data.toString());
    return abi.metadata.compiler.version;
  } catch (error) {
    console.error(`Error reading compiler version for ${contractName}:`, error);
    throw error;
  }
}

// New function to get optimizer runs
const getOptimizerRuns = async(contractName: string): Promise<number | undefined> => {
  try {
    const data = await fs.readFile(`./out/${contractName}.sol/${contractName}.json`);
    const abi = JSON.parse(data.toString());
    
    // Check if optimizer settings exist and have runs property
    if (abi.metadata?.settings?.optimizer?.runs !== undefined) {
      return abi.metadata.settings.optimizer.runs;
    }
    return undefined;
  } catch (error) {
    console.error(`Error reading optimizer runs for ${contractName}:`, error);
    return undefined;
  }
}

const verifyContractsWithDeployedConfig = async () => {
  try {
    console.log(`${colors.yellow}Starting contract verification process...${colors.reset}`);
    
    // Get command line arguments
    try {
      var args = await parseArgs();
    } catch (error: unknown) {
      const errorMessage = error instanceof Error 
        ? error.message 
        : 'An unknown error occurred';
      console.error(`${colors.red}${errorMessage}${colors.reset}`);
      showHelp();
      process.exit(1);
    }
    
    console.log(`${colors.blue}Using deploy script: ${args.script}${colors.reset}`);
    
    // Determine the run file path based on target
    const runFile = args.target === 'latest' 
      ? 'run-latest.json' 
      : `run-${args.target}.json`;
    
    const filePath = path.join('./broadcast', args.script!, args.chainId, runFile);
    console.log(`${colors.blue}Reading deployment data from: ${filePath}${colors.reset}`);
    
    const data = await fs.readFile(filePath);
    const runLatest = JSON.parse(data.toString());
    const deployedConfig = runLatest.transactions.reduce((acc: Record<string, any>, transaction: any) => {
      if(transaction.transactionType === 'CREATE' && transaction.contractName !== null){
        acc[transaction.contractName] = {
          address: transaction.contractAddress,
          constructorArgs: transaction.arguments
        };
      }
      return acc;
    }, {});

    // Parse target contracts if specified
    let targetContracts: string[] = [];
    if (args.contracts) {
      targetContracts = args.contracts.split(',').map(contract => contract.trim());
      
      // Validate that all specified contracts exist in the deployment config
      for (const contract of targetContracts) {
        if (!deployedConfig[contract]) {
          throw new Error(`Specified contract "${contract}" not found in deployment data. Available contracts: ${Object.keys(deployedConfig).join(', ')}`);
        }
      }
      
      console.log(`${colors.blue}Verifying specific contracts: ${targetContracts.join(', ')}${colors.reset}`);
    } else {
      targetContracts = Object.keys(deployedConfig);
      console.log(`${colors.blue}Found ${targetContracts.length} contracts to verify${colors.reset}`);
    }

    for (const key of targetContracts) {
      await verifyContractWithTimeout(key, deployedConfig[key].address, `${deployedConfig[key].constructorArgs.join(' ')}`, args);
    }
    console.log(`${colors.green}Verification process completed!${colors.reset}`);
  } catch (error) {
    console.error(`${colors.red}Error verifying contracts with deployed config:${colors.reset}`, error);
    throw error;
  }
}

const verifyContractWithTimeout = async (
  contractName: string, 
  address: string, 
  constructorArgs: string, 
  args: CommandLineArgs
) => {
  await new Promise((resolve) => {
    setTimeout(async () => {
      await verifyContract(contractName, address, constructorArgs, args);
      resolve(true);
    }, THREE_SECONDS);
  });
};

const verifyContract = async(
  contractName: string,
  address: string,
  constructorArgs: string,
  args: CommandLineArgs
) => {
  console.log(`${colors.cyan}Verifying ${contractName} at ${address}${colors.reset}`);

  try {
    const compilerVersion = await getCompilerVersion(contractName);
    const optimizerRuns = await getOptimizerRuns(contractName);
    
    // Create a simpler command that doesn't rely on shell interpretation
    // Use an array format for exec to avoid shell parsing issues
    const command = [
      'forge', 'verify-contract',
      address,
      contractName,
      '--compiler-version', compilerVersion,
      '--watch',
      '--verifier', 'etherscan',
      '--etherscan-api-key', args.etherscan,
      '--chain-id', args.chainId,
      '--rpc-url', args.rpcUrl
    ];
    
    // Add optimizer runs if available
    if (optimizerRuns !== undefined) {
      command.push('--num-of-optimizations', optimizerRuns.toString());
    }
    
    // Get constructor types for the abi-encode command
    const constructorTypes = await getConstructorTypes(contractName);
    
    // Add constructor arguments if they exist
    if (constructorTypes.length > 0) {
      // Build the full command as a string for better shell handling
      const fullCommand = `${command.join(' ')} --constructor-args "$(cast abi-encode 'constructor(${constructorTypes.join(',')})' ${constructorArgs})"`;
      
      exec(fullCommand, (err, stdout) => {
        if (err) {
          console.error(`${colors.red}Error:${colors.reset}`, err);
        }
        console.log(`${colors.green}${stdout}${colors.reset}`);
      });
    } else {
      // No constructor arguments
      exec(command.join(' '), (err, stdout) => {
        if (err) {
          console.error(`${colors.red}Error:${colors.reset}`, err);
        }
        console.log(`${colors.green}${stdout}${colors.reset}`);
      });
    }
  } catch (error) {
    console.error(`${colors.red}Error verifying contract ${contractName}:${colors.reset}`, error);
    throw error;
  }
}

// New function to get constructor types
const getConstructorTypes = async(contractName: string) => {
  const data = await fs.readFile(`./out/${contractName}.sol/${contractName}.json`);
  const abi = JSON.parse(data.toString());
  const constructor = abi.abi.find((method: any) => method.type === 'constructor');
  if (!constructor) return [];
  
  return constructor.inputs.map((input: any) => input.type);
}

verifyContractsWithDeployedConfig()
