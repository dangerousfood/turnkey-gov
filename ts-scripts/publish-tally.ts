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
      if (tx.contractName === 'UngovernableGovernor' && tx.transactionType === 'CREATE') {
        governorAddress = tx.contractAddress;
        governorDeployedAtBlock = tx.blockNumber;
      }
      if ((tx.contractName === 'UngovernableERC20' || tx.contractName === 'UngovernableToken') && tx.transactionType === 'CREATE') {
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
    // First try to get the tally.config.json
    const tallyConfigPath = path.join(process.cwd(), 'tally.config.json');
    
    // Check if tally.config.json exists
    if (fs.existsSync(tallyConfigPath)) {
      if (DEBUG) {
        console.log('Using tally.config.json for DAO configuration');
      }
      
      const tallyConfig = JSON.parse(fs.readFileSync(tallyConfigPath, 'utf8'));
      
      // Extract the name and description directly from tally.config.json
      const name = tallyConfig.daoName || 'Ungovernable DAO';
      const description = tallyConfig.description || 'A DAO created with Ungovernable Governor.';
      
      if (DEBUG) {
        console.log('Using DAO name from tally.config.json:', name);
        console.log('Using description from tally.config.json:', description);
      }
      
      return { name, description };
    }
    
    // Fallback to the deploy.config.json if tally.config.json doesn't exist
    if (DEBUG) {
      console.log('tally.config.json not found, falling back to deploy.config.json');
    }
    
    // Get the deploy.config.json
    const configPath = path.join(process.cwd(), 'deploy.config.json');
    if (!fs.existsSync(configPath)) {
      throw new Error('Neither tally.config.json nor deploy.config.json file found');
    }
    
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    
    // Use the governor name from config, or fallback to token name if available
    const governorName = config.governor && config.governor._name 
      ? config.governor._name 
      : (config.token && config.token._name 
        ? `${config.token._name} DAO` 
        : 'Ungovernable DAO');
    
    // Create a description based on the token info if available
    const tokenInfo = config.token 
      ? `Token: ${config.token._name || 'Unknown'} (${config.token._symbol || 'Unknown'})`
      : '';
    
    const description = `A DAO created with Ungovernable Governor. ${tokenInfo}`.trim();
    
    if (DEBUG) {
      console.log('Using DAO name from deploy.config.json:', governorName);
      console.log('Using description from deploy.config.json:', description);
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
 * Checks if a DAO already exists on Tally.xyz
 */
async function checkDaoOnTally(governorAddress: string, chainId: string) {
  try {
    if (DEBUG) {
      console.log('Checking if DAO already exists on Tally...');
    }
    
    // Construct the namespace based on the chain ID
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
    
    // We need to try both the organization API and the governor API
    // Sometimes the governor exists but isn't associated with an organization yet
    
    // First, try the direct governor query
    const governorQuery = `
      query FindGovernor($id: ID!) {
        governor(id: $id) {
          id
          name
          organization {
            id
            name
            slug
          }
        }
      }
    `;
    
    // Then, try the organization search query which can find organizations by governor
    const orgSearchQuery = `
      query SearchOrganizations($governorAddress: String!) {
        organizations(where: {governorAddresses: [$governorAddress]}, first: 1) {
          id
          name
          slug
          governors {
            id
          }
        }
      }
    `;
    
    // Variable payloads
    const governorVariables = {
      id: `${namespace}:${governorAddress}`
    };
    
    const orgSearchVariables = {
      governorAddress: governorAddress.toLowerCase()
    };
    
    // Make the API requests
    if (DEBUG) {
      console.log('Making check API requests to Tally...');
    }
    
    // First try the governor direct query
    try {
      const governorResponse = await axios.post(
        tallyApiUrl,
        {
          query: governorQuery,
          variables: governorVariables
        },
        {
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`,
            'api-key': apiKey
          }
        }
      );
      
      // If we got a successful response with governor data
      if (!governorResponse.data.errors && 
          governorResponse.data.data && 
          governorResponse.data.data.governor) {
        
        const result = governorResponse.data.data.governor;
        
        if (DEBUG) {
          console.log('DAO found on Tally via governor query:', result);
        }
        
        console.log('✅ DAO already exists on Tally!');
        if (result.organization) {
          console.log('Organization ID:', result.organization.id);
          console.log('Organization Name:', result.organization.name);
          console.log('Organization Slug:', result.organization.slug);
          console.log(`DAO URL: https://www.tally.xyz/gov/${result.organization.slug}`);
        } else {
          console.log('Warning: Governor exists but is not associated with an organization');
        }
        
        return { exists: true, daoInfo: result };
      }
    } catch (error: any) {
      // If it's not a 422 error, something else went wrong
      if (!error.response || error.response.status !== 422) {
        throw error;
      }
      
      // 422 just means the governor doesn't exist in this query
      if (DEBUG) {
        console.log('Governor not found via direct query, trying organization search...');
      }
    }
    
    // If governor query failed, try the organization search
    try {
      const orgResponse = await axios.post(
        tallyApiUrl,
        {
          query: orgSearchQuery,
          variables: orgSearchVariables
        },
        {
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`,
            'api-key': apiKey
          }
        }
      );
      
      // Check if we found any organizations
      if (!orgResponse.data.errors && 
          orgResponse.data.data && 
          orgResponse.data.data.organizations && 
          orgResponse.data.data.organizations.length > 0) {
        
        const org = orgResponse.data.data.organizations[0];
        
        if (DEBUG) {
          console.log('DAO found on Tally via organization search:', org);
        }
        
        console.log('✅ DAO already exists on Tally!');
        console.log('Organization ID:', org.id);
        console.log('Organization Name:', org.name);
        console.log('Organization Slug:', org.slug);
        console.log(`DAO URL: https://www.tally.xyz/gov/${org.slug}`);
        
        return { exists: true, daoInfo: org };
      }
    } catch (error: any) {
      // Just continue if there's an error with the org search
      if (DEBUG) {
        console.log('Error or no results from organization search');
      }
    }
    
    // If we get here, the DAO wasn't found via either method
    if (DEBUG) {
      console.log('DAO not found in any Tally responses');
    }
    return { exists: false, daoInfo: null };
    
  } catch (error) {
    console.error('Error checking if DAO exists on Tally:', error);
    // We'll continue with publishing and let the publish API handle duplicates
    return { exists: false, daoInfo: null };
  }
}

/**
 * Direct check if a governor exists on Tally, without GraphQL
 * More reliable than the checkDaoOnTally function for just checking existence
 */
async function doesGovernorExist(governorAddress: string, chainId: string) {
  try {
    if (DEBUG) {
      console.log('Doing direct check if governor exists on Tally...');
    }
    
    // Construct the namespace based on the chain ID
    const namespace = `eip155:${chainId}`;
    
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
    
    // Instead of a query, let's directly use a lightweight mutation that will fail if governor exists
    // This is more reliable than queries which might fail for permission reasons
    const testMutation = `
      mutation TestCreateOrg($input: CreateOrganizationInput!) {
        createOrganization(input: $input) {
          id
        }
      }
    `;
    
    // Minimal test input
    const testVariables = {
      input: {
        governors: [
          {
            id: `${namespace}:${governorAddress}`,
            type: "openzeppelingovernor"
          }
        ],
        name: "Test DAO",
        description: "Test DAO"
      }
    };
    
    if (DEBUG) {
      console.log('Testing createOrganization mutation to check if governor exists');
    }
    
    try {
      const response = await axios.post(
        'https://api.tally.xyz/query',
        {
          query: testMutation,
          variables: testVariables
        },
        {
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${token}`,
            'api-key': apiKey
          }
        }
      );
      
      // If we got errors, check if they indicate the governor already exists
      if (response.data.errors) {
        const errorsStr = JSON.stringify(response.data.errors);
        if (errorsStr.includes('governor already exists')) {
          if (DEBUG) {
            console.log('Governor already exists (confirmed from test mutation)');
          }
          return true;
        }
      }
      
      // If no errors, or errors don't mention "governor already exists", 
      // the governor likely doesn't exist
      if (DEBUG) {
        console.log('Governor does not exist (test mutation succeeded or had other errors)');
      }
      return false;
      
    } catch (error: any) {
      // If we get a 422 status with errors mentioning "governor already exists"
      if (error.response && 
          error.response.status === 422 && 
          error.response.data && 
          error.response.data.errors) {
        
        try {
          const errorsStr = JSON.stringify(error.response.data.errors);
          if (errorsStr.includes('governor already exists')) {
            if (DEBUG) {
              console.log('Governor already exists (confirmed from error response)');
            }
            return true;
          }
        } catch (e) {
          // Error parsing the error response, assume governor doesn't exist
        }
      }
      
      // For most errors, just assume governor doesn't exist
      if (DEBUG) {
        console.log('Error during existence check, assuming governor does not exist');
      }
      return false;
    }
  } catch (error) {
    console.error('Error in direct governor check:', error);
    // Default to false to try creation
    return false;
  }
}

/**
 * Publishes the DAO to Tally.xyz
 */
async function publishToTally() {
  try {
    // Get contract addresses and DAO config
    const { governorAddress, tokenAddress, governorDeployedAtBlock, tokenDeployedAtBlock } = await getContractAddresses();
    const { name: daoName, description: daoDescription } = await getDaoConfig();
    
    const chainId = process.env.CHAIN_ID;
    if (!chainId) {
      throw new Error('CHAIN_ID environment variable is not set');
    }
    
    console.log('Using DAO name:', daoName);
    console.log('Using DAO description:', daoDescription);
    console.log('Checking if DAO already exists on Tally...');
    
    // First check if the governor exists (this check is more reliable for existence)
    const governorExists = await doesGovernorExist(governorAddress, chainId);
    
    if (governorExists) {
      console.log('✅ DAO already exists on Tally.');
      
      // Try to get the details
      const { daoInfo } = await checkDaoOnTally(governorAddress, chainId);
      if (daoInfo) {
        return daoInfo;
      } else {
        console.log('Could not retrieve DAO details. Please check manually on Tally.xyz.');
        return { exists: true };
      }
    }
    
    console.log('Creating new DAO on Tally...');
    
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
        name: daoName,
        description: daoDescription
      }
    };
    
    // Make the API request
    if (DEBUG) {
      console.log('Making publish API request to Tally:');
      console.log('URL:', tallyApiUrl);
      console.log('Query:', mutation.trim());
      console.log('Variables:', JSON.stringify(variables, null, 2));
      console.log('Headers:', {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token.substring(0, 10)}...`,
        'api-key': `${apiKey.substring(0, 10)}...`
      });
    }
    
    try {
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
        
        // Check for already exists error and handle it gracefully
        const errorsStr = JSON.stringify(response.data.errors);
        if (errorsStr.includes('governor already exists')) {
          console.log('✅ DAO already exists on Tally (confirmed during creation attempt).');
          
          // Try to get the details 
          const { daoInfo } = await checkDaoOnTally(governorAddress, chainId);
          if (daoInfo) {
            return daoInfo;
          } else {
            console.log('Could not retrieve DAO details. Please check manually on Tally.xyz.');
            return { exists: true };
          }
        }
        
        throw new Error(`Tally API Error: ${JSON.stringify(response.data.errors)}`);
      }
      
      const result = response.data.data.createOrganization;
      
      console.log('✅ DAO successfully published to Tally!');
      console.log(`DAO ID: ${result.id}`);
      console.log(`DAO Slug: ${result.slug}`);
      console.log(`DAO URL: https://www.tally.xyz/gov/${result.slug}`);
      
      return result;
    } catch (error: any) {
      // Handle specific error cases
      if (error.response && error.response.status === 422 && 
          error.response.data && error.response.data.errors) {
        
        // Try to get the error message
        let errorMessage = '';
        try {
          errorMessage = JSON.stringify(error.response.data.errors);
        } catch (e) {
          errorMessage = 'Unknown error';
        }
        
        if (errorMessage.includes('governor already exists')) {
          console.log('✅ DAO already exists on Tally (confirmed from error response).');
          
          // Try to get the details
          const { daoInfo } = await checkDaoOnTally(governorAddress, chainId);
          if (daoInfo) {
            return daoInfo;
          } else {
            console.log('Could not retrieve DAO details. Please check manually on Tally.xyz.');
            return { exists: true };
          }
        }
        
        // If it's not a "governor already exists" error, show the actual error
        console.error('Error response from Tally API:', errorMessage);
      }
      
      throw error;
    }
  } catch (error) {
    console.error('Failed to publish DAO to Tally:', error);
    process.exit(1);
  }
}

// Execute the script
publishToTally(); 