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
    
    for (const tx of transactions) {
      if (tx.contractName === 'UngovernableGovernor' && tx.transactionType === 'CREATE') {
        governorAddress = tx.contractAddress;
      }
    }
    
    if (!governorAddress) {
      throw new Error('Failed to find governor address in deployment data');
    }
    
    if (DEBUG) {
      console.log('Governor Address:', governorAddress);
    }
    
    return {
      governorAddress
    };
  } catch (error) {
    console.error('Error fetching contract addresses:', error);
    process.exit(1);
  }
}

/**
 * Checks if a DAO exists on Tally.xyz
 */
async function checkDaoOnTally() {
  try {
    // Get contract addresses
    const { governorAddress } = await getContractAddresses();
    
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
    
    // Construct the GraphQL query to search for the DAO
    const query = `
      query FindDAO($id: ID!) {
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
    
    // Variable payload for the search
    const variables = {
      id: `${namespace}:${governorAddress}`
    };
    
    // Make the API request
    if (DEBUG) {
      console.log('Making API request to Tally:');
      console.log('URL:', tallyApiUrl);
      console.log('Query:', query.trim());
      console.log('Variables:', JSON.stringify(variables, null, 2));
    }
    
    try {
      const response = await axios.post(
        tallyApiUrl,
        {
          query: query,
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
        
        // Check if the error indicates that the governor doesn't exist
        const errorsStr = JSON.stringify(response.data.errors);
        if (errorsStr.includes('not found')) {
          console.log('❌ DAO not found on Tally. You can register it using the publish-tally script.');
          return null;
        }
        
        throw new Error(`Tally API Error: ${JSON.stringify(response.data.errors)}`);
      }
      
      const result = response.data.data.governor;
      
      if (result) {
        console.log('✅ DAO found on Tally!');
        console.log('Governor ID:', result.id);
        if (result.organization) {
          console.log('Organization ID:', result.organization.id);
          console.log('Organization Name:', result.organization.name);
          console.log('Organization Slug:', result.organization.slug);
          console.log(`DAO URL: https://www.tally.xyz/gov/${result.organization.slug}`);
        } else {
          console.log('Warning: Governor exists but is not associated with an organization');
        }
      } else {
        console.log('❌ DAO not found on Tally. You can register it using the publish-tally script.');
      }
      
      return result;
    } catch (error: any) {
      if (error.response && error.response.status === 422) {
        // Handle 422 errors more gracefully
        console.log('❌ DAO not found on Tally. You can register it using the publish-tally script.');
        if (DEBUG) {
          console.log('Debug: Received 422 status code from Tally API, which likely means the DAO does not exist');
          if (error.response.data) {
            console.log('Debug: Error response data:', JSON.stringify(error.response.data, null, 2));
          }
        }
        return null;
      }
      throw error;
    }
  } catch (error) {
    console.error('Failed to check DAO on Tally:', error);
    process.exit(1);
  }
}

// Execute the script
checkDaoOnTally(); 