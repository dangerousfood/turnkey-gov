# Turnkey Governor
Turnkey Governor is a repository used to easily deploy OpenZeppelin Governor and ERC-20 token with safe defaults.

## Overview
This repository provides a streamlined way to deploy:
- An ERC-20 token with governance capabilities (based on OpenZeppelin's ERC20Votes)
- A Governor contract (based on OpenZeppelin's Governor with various extensions)

The ERC-20 token includes:
- Initial transfer pausing (can be enabled later)
- Blacklisting capabilities
- Support for delegation and voting

The Governor contract includes:
- Simple counting mechanism (one token = one vote)
- Quorum fraction calculation
- Configurable proposal threshold
- Vote extension to prevent late quorum issues

## Requirements
- git
- node
- pnpm
- forge (foundry)

## Deploy Guide

### 1. Install Dependencies
You can use the automated setup script which will check for required dependencies and perform the installation steps:
```shell
pnpm env-setup
```

Or manually:
```shell
git submodule update --init --recursive
pnpm i
cp .env.sample .env
```

### 2. Configure Environment
Edit the `.env` file:
```
PRIVATE_KEY=YOUR_PRIVATE_KEY_HERE
CHAIN_ID=CHAIN_ID_HERE
RPC_URL=RPC_URL_HERE
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY_HERE
```

### 3. Fund Wallet
Fund the wallet associated with your private key on the network you plan to deploy to.

### 4. Configure Deployment
Edit the `deploy.config.json` file:
```json
{
  "governor": {
    "_initialProposalThreshold": 1000000000000000000, 
    "_initialQuorumPercentage": 4, 
    "_initialVoteExtension": 172800, 
    "_initialVotingDelay": 86400, 
    "_initialVotingPeriod": 604800, 
    "_name": "Turnkey Governor"
  },
  "token": {
    "_name": "Turnkey",
    "_symbol": "ABC"
  }
}
```

Configuration parameters:
- `_initialProposalThreshold`: Minimum number of tokens required to make a proposal (in wei)
- `_initialQuorumPercentage`: Minimum voting percentage of totalSupply required for a proposal to pass (0-100)
- `_initialVoteExtension`: Seconds to extend proposal if a late quorum arrives
- `_initialVotingDelay`: Time before a proposal can be voted on (in seconds)
- `_initialVotingPeriod`: Duration a proposal is active for voting (in seconds)
- `_name`: Name for the Governor contract and token
- `_symbol`: Token symbol

### 5. Test Deployment
To verify your configuration works properly, run:
```shell
pnpm deploy:test
```

For additional debug information during deployment, add the `--debug` flag:
```shell
pnpm deploy:test --debug
```

### 6. Production Deployment
If the test deployment is successful, deploy to production:
```shell
pnpm deploy:prod
```
This will deploy and automatically attempt to verify your contracts.

You can also enable debug mode for production deployment:
```shell
pnpm deploy:prod --debug
```

### 7. Optional: Manual Contract Verification
If verification fails during deployment, you can verify manually:
```shell
pnpm verify
```

### 8. Transfer Control to Governance
To transfer token administration to the governance contract:
```shell
pnpm renounce:test  # Test the transfer first
pnpm renounce:prod  # Execute the actual transfer
```

The debug flag works with these commands as well:
```shell
pnpm renounce:test --debug
pnpm renounce:prod --debug
```

## License
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.