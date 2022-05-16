// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

interface IUniswapV3Quoter {

    struct PoolState {
        // the current price
        uint160 sqrtPriceX96;
        // the current tick
        int24 tick;
        // the tick spacing
        int24 tickSpacing;
        // the pool's fee
        uint24 fee;
        // the pool's liquidity
        uint128 liquidity;
        // whether the pool is locked
        bool unlocked;
    }
    
    // accumulated protocol fees in token0/token1 units
    struct ProtocolFees {
        uint128 token0;
        uint128 token1;
    }

    // the top level state of the swap, the results of which are recorded in storage at the end
    struct SwapState {
        // the amount remaining to be swapped in/out of the input/output asset
        int256 amountSpecifiedRemaining;
        // the amount already swapped out/in of the output/input asset
        int256 amountCalculated;
        // current sqrt(price)
        uint160 sqrtPriceX96;
        // the tick associated with the current price
        int24 tick;
        // the current liquidity in range
        uint128 liquidity;
    }

    struct StepComputations {
        // the price at the beginning of the step
        uint160 sqrtPriceStartX96;
        // the next tick to swap to from the current tick in the swap direction
        int24 tickNext;
        // whether tickNext is initialized or not
        bool initialized;
        // sqrt(price) for the next tick (1/0)
        uint160 sqrtPriceNextX96;
        // how much is being swapped in in this step
        uint256 amountIn;
        // how much is being swapped out
        uint256 amountOut;
        // how much fee is being paid in
        uint256 feeAmount;
    }

    struct InitialState {
        address poolAddress;
        PoolState poolState;
        uint256 feeGrowthGlobal0X128;
        uint256 feeGrowthGlobal1X128;
    }

    struct NextTickPassage {
        int24 tick;
        int24 tickSpacing;
    }
}
