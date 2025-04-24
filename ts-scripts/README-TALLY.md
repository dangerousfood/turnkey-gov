# Publishing Your DAO to Tally.xyz

This document explains how to use the `publish-tally` script to register your DAO on [Tally.xyz](https://www.tally.xyz/), a popular governance platform for DAOs.

## Prerequisites

1. You must have already deployed your Turnkey Governor and Token contracts.
2. You need to obtain a Tally API token and API key.

## Obtaining Tally API Credentials

To obtain your Tally API credentials:

1. Create an account on [Tally.xyz](https://www.tally.xyz/)
2. Once logged in, you can find your API key in your account settings
3. The Bearer token is associated with your login session

## Environment Variables

Make sure the following environment variables are set in your `.env` file:

```
CHAIN_ID=         # The chain ID where your contracts are deployed
TALLY_API_TOKEN=  # Your Tally.xyz Bearer token
TALLY_API_KEY=    # Your Tally.xyz API key
```

## Usage

After deploying your contracts, you can publish your DAO to Tally with:

```bash
pnpm publish-tally
```

### Debug Mode

For more verbose output, you can run the script in debug mode:

```bash
pnpm publish-tally --debug
```

## What This Script Does

1. Reads your contract addresses from deployment artifacts
2. Extracts DAO configuration from your `deploy.config.json`
3. Formats the data as required by Tally's API
4. Submits the data to the Tally API
5. Returns the URL to your new DAO on Tally

## Troubleshooting

If you encounter any issues:

1. Check that the required environment variables are set correctly
2. Verify your deployment artifacts exist in the `broadcast` directory
3. Make sure your API credentials are valid
4. Run the script with `--debug` flag for more detailed logs

## API Response

On successful creation, the script will print:
- The DAO ID
- The DAO slug
- The URL to access your DAO on Tally 