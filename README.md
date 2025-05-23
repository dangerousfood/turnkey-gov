# Ü̶̟̟̆̓n̷̤̪̮̈͗g̸̠̦̍͑̊̊o̷͕͇͎͋̒̉̎́ͅv̷̛̪̩̇̕e̶̙͇̝̿̕r̵͍̙͉̺̭͔̽̈͐͘͠ń̵͉̯̣̿̀ȁ̶̱͙̆̃͑̾ḃ̵̰͎̲̬͖͒l̷̦̹̫̞̟͖͑͝ẻ̴͈̺̦̤͝ Governor
Ungovernable Governor is a repository used to easily deploy OpenZeppelin Governor and ERC-20 token with safe defaults.

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

<span style="color:red">***Ungovernable does not feature a `Timelock`, `TimelockController`, or `Guardians` in the governance to ensure governance neutrality. In leu of those security features a `GovernorVotesQuorumFraction` and `GovernorPreventLateQuorum` have been added to prevent malicious voting behavior.***</span>

## Requirements
- git
- node
- pnpm
- forge (foundry)

## Deploy Guide

### 1. Install Dependencies
You can use the automated setup script which will check for required dependencies and perform the installation steps:
```shell
pnpm setup:env
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
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY
```

### 3. Fund Wallet
Fund the wallet associated with your private key on the network you plan to deploy to.

### 4. Configure Deployment
Edit the `deploy.config.json` file:
```json
{
  "governor": {
    "_initialProposalThreshold": 10000000000000000000000000,
    "_initialQuorumPercentage": 5,
    "_initialVoteExtension": 172800,
    "_initialVotingDelay": 86400,
    "_initialVotingPeriod": 604800,
    "_name": "Ungovernable Governor"
  },
  "token": {
    "_name": "Ungovernable",
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

### 9. Publishing Your DAO to Tally.xyz

Ungovernable Governor includes functionality to publish your DAO to [Tally.xyz](https://www.tally.xyz/), a popular governance platform for DAOs.

#### Prerequisites

1. You must have already deployed your Ungovernable Governor and Token contracts
2. You need to obtain a Tally API token and API key from your Tally.xyz account
3. Follow this guide on obtaining a [Tally API key](https://docs.tally.xyz/tally-features/welcome#how-to-use-the-tally-api)

#### Environment Setup

Update your `.env` file with the following Tally-specific variables:
```
TALLY_API_KEY=YOUR_TALLY_API_KEY
```

The `TALLY_API_TOKEN` is now automatically generated using Sign-In With Ethereum (SIWE) with your private key. You don't need to manually obtain it anymore.

#### Tally Configuration (Optional)

You can customize how your DAO appears on Tally.xyz by creating a `tally.config.json` file in the project root:

```json
{
  "daoName": "Your DAO Name",
  "description": "A detailed description of your DAO and its purpose."
}
```

A sample file `tally.config.sample.json` is provided that you can copy and customize:
```shell
cp tally.config.sample.json tally.config.json
```

If this file is not present, the script will use information from your `deploy.config.json` file instead.

#### Check DAO Status
To check if your DAO is already registered on Tally:
```shell
pnpm check:tally
```

#### Publish to Tally
To publish your DAO to Tally.xyz:
```shell
pnpm publish:tally
```

The script will:
1. Extract your contract addresses from deployment artifacts
2. Get DAO configuration from your `tally.config.json` or fall back to `deploy.config.json`
3. Format and submit the data to Tally
4. Return a URL to access your new DAO on Tally

You can use the debug flag for more detailed output:
```shell
pnpm publish:tally --debug
pnpm check:tally --debug
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