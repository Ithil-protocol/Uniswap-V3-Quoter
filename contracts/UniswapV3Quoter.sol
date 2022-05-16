// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

import { Tick } from "./libraries/Tick.sol";
import { TickBitmap } from "./libraries/TickBitmap.sol";
import { FullMath } from "./libraries/FullMath.sol";
import { SqrtPriceMath } from "./libraries/SqrtPriceMath.sol";
import { SwapMath } from "./libraries/SwapMath.sol";
import { TickMath } from "./libraries/TickMath.sol";
import { SafeCast } from "./libraries/SafeCast.sol";
import { LiquidityMath } from "./libraries/LiquidityMath.sol";
import { LowGasSafeMath } from "./libraries/LowGasSafeMath.sol";

import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { IUniswapV3PoolImmutables } from "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolImmutables.sol";
import { IUniswapV3Quoter } from "./interfaces/IUniswapV3Quoter.sol";

contract UniswapV3Quoter is IUniswapV3Quoter {
    using LowGasSafeMath for int256;
    using SafeCast for uint256;
    using Tick for mapping(int24 => Tick.Info);

    function fetchState(address _pool) internal view returns (
        PoolState memory poolState
        ){
        IUniswapV3Pool pool = IUniswapV3Pool(_pool);
        (uint160 sqrtPriceX96, int24 tick,,,,, bool unlocked) = pool.slot0(); // external call
        uint128 liquidity = pool.liquidity(); // external call
        int24 tickSpacing = IUniswapV3PoolImmutables(_pool).tickSpacing(); // external call
        uint24 fee = IUniswapV3PoolImmutables(_pool).fee(); // external call
        poolState = PoolState(sqrtPriceX96, tick, tickSpacing, fee, liquidity, unlocked);
    }

    function setInitialState(
        PoolState memory initialPoolState,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96, 
        bool zeroForOne) 
        internal pure returns (SwapState memory state, uint128 liquidity, uint160 sqrtPriceX96) {
        liquidity = initialPoolState.liquidity;
        
        sqrtPriceX96 = initialPoolState.sqrtPriceX96;

        require(zeroForOne 
                ? sqrtPriceLimitX96 < initialPoolState.sqrtPriceX96 && sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 > initialPoolState.sqrtPriceX96 && sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO, 'SPL');

        state =
            SwapState({
                amountSpecifiedRemaining: amountSpecified,
                amountCalculated: 0,
                sqrtPriceX96: initialPoolState.sqrtPriceX96,
                tick: initialPoolState.tick,
                liquidity: 0 // to be modified after initialization
            });
    }

    function getNextTickAndPrice(int24 tickSpacing, int24 currentTick, IUniswapV3Pool pool, bool zeroForOne) 
        internal view returns (int24 tickNext, bool initialized, uint160 sqrtPriceNextX96) {
        int24 compressed = currentTick / tickSpacing;
        if (!zeroForOne) compressed++;
        if (currentTick < 0 && currentTick % tickSpacing != 0) compressed--; // round towards negative infinity

        uint256 selfResult = pool.tickBitmap(int16(compressed >> 8)); // external call

        (tickNext, initialized) =  
            TickBitmap.nextInitializedTickWithinOneWord(
                selfResult,
                currentTick,
                tickSpacing,
                zeroForOne
                );

        if (tickNext < TickMath.MIN_TICK) {
            tickNext = TickMath.MIN_TICK;
        } else if (tickNext > TickMath.MAX_TICK) {
            tickNext = TickMath.MAX_TICK;
        }
        sqrtPriceNextX96 = TickMath.getSqrtRatioAtTick(tickNext);
    }

    function processSwapWithinTick (
        IUniswapV3Pool pool,
        PoolState memory initialPoolState,
        SwapState memory state,
        uint160 firstSqrtPriceX96, 
        uint128 firstLiquidity,
        uint160 sqrtPriceLimitX96, 
        bool zeroForOne,
        bool exactAmount) internal view returns(uint160 sqrtPriceNextX96, uint160 finalSqrtPriceX96, uint128 finalLiquidity) {
        
        StepComputations memory step;

        step.sqrtPriceStartX96 = firstSqrtPriceX96;

        (step.tickNext, step.initialized, sqrtPriceNextX96) = getNextTickAndPrice(initialPoolState.tickSpacing, state.tick, pool, zeroForOne);

        (finalSqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
            firstSqrtPriceX96,
            (zeroForOne ? sqrtPriceNextX96 < sqrtPriceLimitX96 : sqrtPriceNextX96 > sqrtPriceLimitX96) ? sqrtPriceLimitX96 : sqrtPriceNextX96,
            firstLiquidity,
            state.amountSpecifiedRemaining,
            initialPoolState.fee,
            zeroForOne
        );

        if(exactAmount){
            state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
            state.amountCalculated = state.amountCalculated.sub(step.amountOut.toInt256());
        } else {
            state.amountSpecifiedRemaining += step.amountOut.toInt256();
            state.amountCalculated = state.amountCalculated.add((step.amountIn + step.feeAmount).toInt256());
        }

        if (finalSqrtPriceX96 == sqrtPriceNextX96) {
            if (step.initialized) {
                (,int128 liquidityNet,,,,,,) = pool.ticks(step.tickNext);
                if (zeroForOne) liquidityNet = -liquidityNet;
                finalLiquidity = LiquidityMath.addDelta(firstLiquidity, liquidityNet);
            }
            state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
        } else if (finalSqrtPriceX96 != step.sqrtPriceStartX96) {
            // recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), and haven't moved
            state.tick = TickMath.getTickAtSqrtRatio(finalSqrtPriceX96);
        }
    }

    function returnedAmount (
        SwapState memory state,
        int256 amountSpecified,
        bool zeroForOne) internal pure returns(int256 amount0, int256 amount1) {
        
        if(amountSpecified > 0){
            (amount0, amount1) = zeroForOne
                    ? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
                    : (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);
        } else {
            (amount0, amount1) = zeroForOne
                ?(state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining)
                :(amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated);
        }

    }

    function quoteSwap(
        address poolAddress,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bool zeroForOne
    ) internal view returns (int256 amount0, int256 amount1) {
        bool exactAmount = amountSpecified > 0;

        PoolState memory initialPoolState = fetchState(poolAddress);
        uint160 sqrtPriceNextX96;

        (SwapState memory state, uint128 liquidity, uint160 sqrtPriceX96) = 
            setInitialState(initialPoolState, amountSpecified, sqrtPriceLimitX96, zeroForOne);
            
        while (state.amountSpecifiedRemaining != 0 && sqrtPriceX96 != sqrtPriceLimitX96)
            (sqrtPriceNextX96, sqrtPriceX96, liquidity) = 
                processSwapWithinTick(IUniswapV3Pool(poolAddress), initialPoolState, state, sqrtPriceX96, liquidity, sqrtPriceLimitX96, zeroForOne, exactAmount);

        (amount0, amount1) = returnedAmount(state, amountSpecified, zeroForOne);
    }
}
