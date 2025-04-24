import axios from 'axios';
import * as fs from 'fs';
import * as path from 'path';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

// Check if debug mode is enabled
const DEBUG = process.env.DEBUG === 'true';

/**
 * Gets the contract addresses from the deploy artifacts
 */
async function getContractAddresses() {
  try {
    // Need to fetch the governor and token addresses from deployment artifacts
    const deploymentDir = path.join(process.cwd(), 'broadcast', 'Deploy.s.sol');
    
    // Find the latest deployment file in the directory
    const chainId = process.env.CHAIN_ID;
    if (!chainId) {
      throw new Error('CHAIN_ID environment variable is not set');
    }
    
    const chainDir = path.join(deploymentDir, chainId);
    if (!fs.existsSync(chainDir)) {
      throw new Error(`Deployment directory for chain ID ${chainId} not found. Please deploy contracts first.`);
    }
    
    // Get the latest run file
    const files = fs.readdirSync(chainDir);
    const latestRunFile = files
      .filter(file => file.endsWith('.json') && !file.includes('dry-run'))
      .sort()
      .pop();
    
    if (!latestRunFile) {
      throw new Error('No deployment files found.');
    }
    
    const deploymentData = JSON.parse(
      fs.readFileSync(path.join(chainDir, latestRunFile), 'utf8')
    );
    
    // Extract contract addresses from the deployment data
    const transactions = deploymentData.transactions;
    
    let governorAddress: string | null = null;
    let tokenAddress: string | null = null;
    let governorDeployedAtBlock: number | null = null;
    let tokenDeployedAtBlock: number | null = null;
    
    for (const tx of transactions) {
      if (tx.contractName === 'TurnkeyGovernor' && tx.transactionType === 'CREATE') {
        governorAddress = tx.contractAddress;
        governorDeployedAtBlock = tx.blockNumber;
      }
      if (tx.contractName === 'TurnkeyERC20' && tx.transactionType === 'CREATE') {
        tokenAddress = tx.contractAddress;
        tokenDeployedAtBlock = tx.blockNumber;
      }
    }

    console.log(governorAddress, tokenAddress);
    
    if (!governorAddress || !tokenAddress) {
      throw new Error('Failed to find governor or token addresses in deployment data');
    }
    
    // Ensure we have valid block numbers, using fallbacks if not found
    if (!governorDeployedAtBlock) {
      console.warn('Warning: Governor deployment block not found, using default value');
      governorDeployedAtBlock = 8182743; // Using fallback value from the original request
    }
    
    if (!tokenDeployedAtBlock) {
      console.warn('Warning: Token deployment block not found, using default value');
      tokenDeployedAtBlock = 8182742; // Using fallback value from the original request
    }
    
    if (DEBUG) {
      console.log('Governor Address:', governorAddress);
      console.log('Token Address:', tokenAddress);
      console.log('Governor deployed at block:', governorDeployedAtBlock);
      console.log('Token deployed at block:', tokenDeployedAtBlock);
    }
    
    return {
      governorAddress,
      tokenAddress,
      governorDeployedAtBlock,
      tokenDeployedAtBlock
    };
  } catch (error) {
    console.error('Error fetching contract addresses:', error);
    process.exit(1);
  }
}

/**
 * Gets the DAO configuration to be sent to Tally
 */
async function getDaoConfig() {
  try {
    // Get the deploy.config.json
    const configPath = path.join(process.cwd(), 'deploy.config.json');
    if (!fs.existsSync(configPath)) {
      throw new Error('deploy.config.json file not found');
    }
    
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    
    // Use the governor name from config, or fallback to token name if available
    const governorName = config.governor && config.governor._name 
      ? config.governor._name 
      : (config.token && config.token._name 
        ? `${config.token._name} DAO` 
        : 'Turnkey DAO');
    
    // Create a description based on the token info if available
    const tokenInfo = config.token 
      ? `Token: ${config.token._name || 'Unknown'} (${config.token._symbol || 'Unknown'})`
      : '';
    
    const description = `A DAO created with Turnkey Governor. ${tokenInfo}`.trim();
    
    if (DEBUG) {
      console.log('Using DAO name:', governorName);
      console.log('Using description:', description);
    }
    
    return {
      name: governorName,
      description: description
    };
  } catch (error) {
    console.error('Error reading DAO configuration:', error);
    process.exit(1);
  }
}

/**
 * Publishes the DAO to Tally.xyz
 */
async function publishToTally() {
  try {
    // Get contract addresses and DAO config
    const { governorAddress, tokenAddress, governorDeployedAtBlock, tokenDeployedAtBlock } = await getContractAddresses();
    const { name, description } = await getDaoConfig();
    
    const chainId = process.env.CHAIN_ID;
    if (!chainId) {
      throw new Error('CHAIN_ID environment variable is not set');
    }
    
    // Construct the namespace based on the chain ID
    // Tally uses 'eip155:<chainId>' format for its namespaces
    const namespace = `eip155:${chainId}`;
    
    // Construct the API request
    const tallyApiUrl = 'https://api.tally.xyz/query';
    
    // The API requires a personal access token for authentication
    const token = process.env.TALLY_API_TOKEN;
    if (!token) {
      throw new Error('TALLY_API_TOKEN environment variable is not set. Please add it to your .env file.');
    }
    
    // API key is also required
    const apiKey = process.env.TALLY_API_KEY;
    if (!apiKey) {
      throw new Error('TALLY_API_KEY environment variable is not set. Please add it to your .env file.');
    }
    
    // Construct the GraphQL mutation based on the observed API call
    const mutation = `
      mutation CreateDAO($input: CreateOrganizationInput!) {
        createOrganization(input: $input) {
          id
          slug
        }
      }
    `;
    
    // Variable payload based on the observed API call
    const variables = {
      input: {
        governors: [
          {
            id: `${namespace}:${governorAddress}`,
            type: "openzeppelingovernor",
            startBlock: governorDeployedAtBlock,
            token: {
              id: `${namespace}/erc20:${tokenAddress}`,
              startBlock: tokenDeployedAtBlock
            }
          }
        ],
        name: name,
        description: description
      }
    };
    
    // Make the API request
    if (DEBUG) {
      console.log('Making API request to Tally:');
      console.log('URL:', tallyApiUrl);
      console.log('Query:', mutation.trim());
      console.log('Variables:', JSON.stringify(variables, null, 2));
      console.log('Headers:', {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token.substring(0, 10)}...`,
        'api-key': `${apiKey.substring(0, 10)}...`
      });
    }
    
    const response = await axios.post(
      tallyApiUrl,
      {
        query: mutation,
        variables: variables
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token}`,
          'api-key': apiKey
        }
      }
    );
    
    // Check if the request was successful
    if (response.data.errors) {
      if (DEBUG) {
        console.error('API Response Errors:', JSON.stringify(response.data.errors, null, 2));
      }
      throw new Error(`Tally API Error: ${JSON.stringify(response.data.errors)}`);
    }
    
    const result = response.data.data.createOrganization;
    
    console.log('✅ DAO successfully published to Tally!');
    console.log(`DAO ID: ${result.id}`);
    console.log(`DAO Slug: ${result.slug}`);
    console.log(`DAO URL: https://www.tally.xyz/gov/${result.slug}`);
    
    return result;
  } catch (error) {
    console.error('Failed to publish DAO to Tally:', error);
    process.exit(1);
  }
}

// Execute the script
publishToTally(); 