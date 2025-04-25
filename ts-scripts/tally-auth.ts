import axios from 'axios';
import { ethers } from 'ethers';
import * as dotenv from 'dotenv';

dotenv.config();

interface NonceResponse {
  data: {
    nonce: {
      expirationTime: string;
      issuedAt: string;
      nonce: string;
      nonceToken: string;
    }
  }
}

interface LoginResponse {
  data: {
    login: string; // This is the JWT token
  }
}

/**
 * Get a nonce from the Tally API for SIWE authentication
 */
async function getNonce(): Promise<{
  nonce: string;
  nonceToken: string;
  issuedAt: string;
  expirationTime: string;
}> {
  const tallyApiUrl = 'https://api.tally.xyz/query';
  const apiKey = process.env.TALLY_API_KEY;
  
  if (!apiKey) {
    throw new Error('TALLY_API_KEY environment variable is not set. Please add it to your .env file.');
  }

  const query = `
    query Nonce {
      nonce {
        expirationTime
        issuedAt
        nonce
        nonceToken
      }
    }`;

  try {
    const response = await axios.post<NonceResponse>(
      tallyApiUrl,
      { query },
      {
        headers: {
          'Content-Type': 'application/json',
          'api-key': apiKey
        }
      }
    );

    if (!response.data.data || !response.data.data.nonce) {
      throw new Error('Failed to get nonce from Tally API');
    }

    return response.data.data.nonce;
  } catch (error) {
    console.error('Error getting nonce from Tally API:', error);
    throw error;
  }
}

/**
 * Sign a message with the user's private key for SIWE authentication
 */
async function signMessage(message: string): Promise<string> {
  const privateKey = process.env.PRIVATE_KEY;
  
  if (!privateKey) {
    throw new Error('PRIVATE_KEY environment variable is not set. Please add it to your .env file.');
  }

  const wallet = new ethers.Wallet(privateKey);
  const signature = await wallet.signMessage(message);
  
  return signature;
}

/**
 * Create a SIWE message from the nonce and other data
 */
function createSiweMessage(nonce: string, issuedAt: string, expirationTime: string, address: string): string {
  return `www.tally.xyz wants you to sign in with your Ethereum account:
${address}

Sign in with Ethereum to Tally and agree to the Terms of Service at terms.tally.xyz

URI: https://www.tally.xyz/
Version: 1
Chain ID: 1
Nonce: ${nonce}
Issued At: ${issuedAt}
Expiration Time: ${expirationTime}`;
}

/**
 * Login to Tally with SIWE
 */
async function loginWithSiwe(): Promise<string> {
  try {
    const privateKey = process.env.PRIVATE_KEY;
    
    if (!privateKey) {
      throw new Error('PRIVATE_KEY environment variable is not set. Please add it to your .env file.');
    }

    // Get wallet address from private key
    const wallet = new ethers.Wallet(privateKey);
    const address = wallet.address;

    // Get nonce from Tally API
    const { nonce, nonceToken, issuedAt, expirationTime } = await getNonce();
    
    // Create SIWE message
    const message = createSiweMessage(nonce, issuedAt, expirationTime, address);
    
    // Sign the message
    const signature = await signMessage(message);
    
    // Send login request
    const tallyApiUrl = 'https://api.tally.xyz/query';
    const apiKey = process.env.TALLY_API_KEY;
    
    if (!apiKey) {
      throw new Error('TALLY_API_KEY environment variable is not set. Please add it to your .env file.');
    }

    const query = `
      mutation Login($message: String!, $signature: String!, $signInType: SignInType!) {
        login(message: $message, signature: $signature, signInType: $signInType)
      }`;

    const variables = {
      message,
      signature,
      signInType: "evm"
    };

    const response = await axios.post<LoginResponse>(
      tallyApiUrl,
      {
        query,
        variables
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'api-key': apiKey,
          'nonce': nonceToken
        }
      }
    );

    if (!response.data.data || !response.data.data.login) {
      throw new Error('Failed to login to Tally API');
    }

    return response.data.data.login; // This is the JWT token
  } catch (error) {
    console.error('Error logging in to Tally:', error);
    throw error;
  }
}

/**
 * Get Tally API token using SIWE authentication
 * This function will be used by other scripts to get the token
 */
export async function getTallyApiToken(): Promise<string> {
  // First, check if we already have a token in the environment
  const existingToken = process.env.TALLY_API_TOKEN;
  
  if (existingToken) {
    return existingToken;
  }
  
  // Otherwise, get a new token using SIWE
  try {
    const token = await loginWithSiwe();
    
    // Set the token in the environment for future use
    process.env.TALLY_API_TOKEN = token;
    
    return token;
  } catch (error) {
    console.error('Failed to get Tally API token:', error);
    throw error;
  }
}

// Export the function so it can be used in other scripts
export default getTallyApiToken;

// If this file is run directly, just get the token and print it
if (require.main === module) {
  getTallyApiToken()
    .then(token => {
      console.log('Successfully obtained Tally API token');
      console.log('Token:', token);
    })
    .catch(error => {
      console.error('Error:', error);
      process.exit(1);
    });
} 