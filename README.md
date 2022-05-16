# Uniswap V3 quoter
A fully on-chain UniswapV3 *view* quoter.

## General Description
Protocols in need of using UniswapV3 on-chain have to rely on external data sources like Chainlink in order to reliably get price data, as Uniswap oracles are currently released as "lens" functions which cost gas and are quite unfeasible for constant usage.

We addressed the problem by reworking Uniswap quoting algorithm so that it can fit into a Solidity view function, hence no gas costs when calling it, while maintaining a sub-decimal precision, comparable with the lens quoter. The resulting code has been deployed to Kovan testnet and is hosted on GitHub pages.

In the future we plan to extend this oracle to support a time window moving average so that it can be reliably used to prevent MEV and front-running attacks in a fully on-chain way.

Using UniswapV3 libraries and a sprinkle of OpenZeppelin, Hardhat and ReactJS.

## How it works

Here is how the algorithm works on a general level:
1. Checks how much you can swap and the related price impact

2. If the price impact is greater than the nearest tick, the initialised liquidity is not sufficient 

3. Calculate how much you can swap within the tick, subtract the (calculated) swapped liquidity from the total amount and move to the next tick

4. Rinse and repeat until no liquidity is left

## How to use it

1. Clone the repo
   ```sh
   git clone ...this repo...
   ```
2. Install required packages both in the base and the *frontend* folder using the same command
   ```sh
   yarn install
   ```
3. Run a mainnet fork and deploy the smart contract
   ```sh
   yarn fork
   ```
4. Execute the demo frontend app
   ```sh
   cd frontend
   yarn start
   ```
5. Connect with *MetaMask* browser wallet using the following network settings
   ```
   Chain ID: 31337
   RPC URL: http://127.0.0.1:8545
   ```
   