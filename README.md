# Turnkey Governor
Turnkey Governor is a repository used to simply deploy OpenZeppelin Governor and ERC-20 token with safe defaults.

## Requirements
- git
- node
- pnpm
- forge (foundry)

## Deploy Guide

#### Install
```shell
git submodule update --init --recursive
pnpm i
cp .env.sample .env
```

#### Setup environment
```shell
PRIVATE_KEY="ENTER YOUR PRIVATE KEY 0x..."
CHAIN_ID=ENTER_CHAIN_ID
RPC_URL="RPC URL https://..."
ETHERSCAN_API_KEY=API_KEY_FROM_ETHERSCAN
```
#### Fund wallet
Fund the wallet for the private key on the network you would like to deploy to.

#### Edit `deployment.config.json`:
JSON keys must be ordered alphabetically
  ```json
  {
    "governor": {
      "name": "Turnkey Governor", // name of the governor contract
      "proposalThreshold": 1000000000000000000, // minimum number of tokens required to make a proposal in wei (10**18)
      "quorumPercentage": 4, // minimum voting percentage of totalSupply required for a proposal to pass
      "votingDelay": 7200, // minimum waiting time for a proposal to being voting (in seconds)
      "voteExtension": 86400, // seconds to extend proposal if a late quorum arrives (in seconds)
      "votingPeriod": 50400 // time period in which a voting proposal is active (in seconds)
    },
    "token": {
      "name": "Turnkey", // token name
      "owner": "0x0000000000000000000000000000000000000000", // owner of the token, can enable transfers
      "symbol": "ABC" // token symbol
    }
  }
```

#### Test Deploy Contracts
```
pnpm deploy:test
```
If you are successful in this stage, move to the next step

#### Deploy Contracts
```
pnpm deploy:prod
```

#### Verify Contracts on Etherscan
```
pnpm verify
```

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.