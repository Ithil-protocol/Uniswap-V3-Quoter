// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6;

import "./libraries/LowGasSafeMath.sol";
import "./libraries/SafeCast.sol";
import "./libraries/Tick.sol";
import "./libraries/TickBitmap.sol";

import "./libraries/FullMath.sol";
import "./libraries/TickMath.sol";
import "./libraries/LiquidityMath.sol";
import "./libraries/SqrtPriceMath.sol";
import "./libraries/SwapMath.sol";

import "./interfaces/IUniswapV3Quoter.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolImmutables.sol";

import "hardhat/console.sol";

contract UniswapV3Quoter is IUniswapV3Quoter {
    using LowGasSafeMath for int256;
    using SafeCast for uint256;
    using Tick for mapping(int24 => Tick.Info);

    function fetchState(address _pool, uint32 secondsAgo) internal view returns (PoolState memory poolState) {
        uint160 sqrtPriceX96;
        int24 tick;
        uint128 liquidity;
        IUniswapV3Pool pool = IUniswapV3Pool(_pool);
        int24 tickSpacing = IUniswapV3PoolImmutables(_pool).tickSpacing(); // external call
        uint24 fee = IUniswapV3PoolImmutables(_pool).fee(); // external call
        if (secondsAgo == 0) {
            (sqrtPriceX96, tick, , , , , ) = pool.slot0(); // external call
            liquidity = pool.liquidity(); // external call
        } else {
            uint32[] memory secondsAgos = new uint32[](2);
            secondsAgos[0] = secondsAgo;
            secondsAgos[1] = 0;
            (int56[] memory tickCumulatives, uint160[] memory secondsPerLiquidityCumulativeX128s) = IUniswapV3Pool(pool)
                .observe(secondsAgos);

            int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];
            uint160 secondsPerLiquidityCumulativesDelta = secondsPerLiquidityCumulativeX128s[1] -
                secondsPerLiquidityCumulativeX128s[0];

            tick = int24(tickCumulativesDelta / int32(secondsAgo));
            // Always round to negative infinity
            if (tickCumulativesDelta < 0 && (tickCumulativesDelta % int32(secondsAgo) != 0)) tick--;
            sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);
            // We are multiplying here instead of shifting to ensure that harmonicMeanLiquidity doesn't overflow uint128
            uint192 secondsAgoX160 = uint192(secondsAgo) * type(uint160).max;
            liquidity = uint128(secondsAgoX160 / (uint192(secondsPerLiquidityCumulativesDelta) << 32));
        }
        poolState = PoolState(sqrtPriceX96, tick, tickSpacing, fee, liquidity);
    }

    function setInitialState(
        PoolState memory initialPoolState,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bool zeroForOne
    )
        internal
        pure
        returns (
            SwapState memory state,
            uint128 liquidity,
            uint160 sqrtPriceX96
        )
    {
        liquidity = initialPoolState.liquidity;

        sqrtPriceX96 = initialPoolState.sqrtPriceX96;

        require(
            zeroForOne
                ? sqrtPriceLimitX96 < initialPoolState.sqrtPriceX96 && sqrtPriceLimitX96 > TickMath.MIN_SQRT_RATIO
                : sqrtPriceLimitX96 > initialPoolState.sqrtPriceX96 && sqrtPriceLimitX96 < TickMath.MAX_SQRT_RATIO,
            "SPL"
        );

        state = SwapState({
            amountSpecifiedRemaining: amountSpecified,
            amountCalculated: 0,
            sqrtPriceX96: initialPoolState.sqrtPriceX96,
            tick: initialPoolState.tick,
            liquidity: 0 // to be modified after initialization
        });
    }

    function getNextTickAndPrice(
        int24 tickSpacing,
        int24 currentTick,
        IUniswapV3Pool pool,
        bool zeroForOne
    )
        internal
        view
        returns (
            int24 tickNext,
            bool initialized,
            uint160 sqrtPriceNextX96
        )
    {
        int24 compressed = currentTick / tickSpacing;
        if (!zeroForOne) compressed++;
        if (currentTick < 0 && currentTick % tickSpacing != 0) compressed--; // round towards negative infinity

        uint256 selfResult = pool.tickBitmap(int16(compressed >> 8)); // external call

        (tickNext, initialized) = TickBitmap.nextInitializedTickWithinOneWord(
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

    function processSwapWithinTick(
        IUniswapV3Pool pool,
        PoolState memory initialPoolState,
        SwapState memory state,
        uint160 firstSqrtPriceX96,
        uint128 firstLiquidity,
        uint160 sqrtPriceLimitX96,
        bool zeroForOne,
        bool exactAmount
    )
        internal
        view
        returns (
            uint160 sqrtPriceNextX96,
            uint160 finalSqrtPriceX96,
            uint128 finalLiquidity
        )
    {
        StepComputations memory step;

        step.sqrtPriceStartX96 = firstSqrtPriceX96;

        (step.tickNext, step.initialized, sqrtPriceNextX96) = getNextTickAndPrice(
            initialPoolState.tickSpacing,
            state.tick,
            pool,
            zeroForOne
        );

        (finalSqrtPriceX96, step.amountIn, step.amountOut, step.feeAmount) = SwapMath.computeSwapStep(
            firstSqrtPriceX96,
            (zeroForOne ? sqrtPriceNextX96 < sqrtPriceLimitX96 : sqrtPriceNextX96 > sqrtPriceLimitX96)
                ? sqrtPriceLimitX96
                : sqrtPriceNextX96,
            firstLiquidity,
            state.amountSpecifiedRemaining,
            initialPoolState.fee,
            zeroForOne
        );

        if (exactAmount) {
            state.amountSpecifiedRemaining -= (step.amountIn + step.feeAmount).toInt256();
            state.amountCalculated = state.amountCalculated.sub(step.amountOut.toInt256());
        } else {
            state.amountSpecifiedRemaining += step.amountOut.toInt256();
            state.amountCalculated = state.amountCalculated.add((step.amountIn + step.feeAmount).toInt256());
        }

        if (finalSqrtPriceX96 == sqrtPriceNextX96) {
            if (step.initialized) {
                (, int128 liquidityNet, , , , , , ) = pool.ticks(step.tickNext);
                if (zeroForOne) liquidityNet = -liquidityNet;
                finalLiquidity = LiquidityMath.addDelta(firstLiquidity, liquidityNet);
            }
            state.tick = zeroForOne ? step.tickNext - 1 : step.tickNext;
        } else if (finalSqrtPriceX96 != step.sqrtPriceStartX96) {
            // recompute unless we're on a lower tick boundary (i.e. already transitioned ticks), and haven't moved
            state.tick = TickMath.getTickAtSqrtRatio(finalSqrtPriceX96);
        }
    }

    function returnedAmount(
        SwapState memory state,
        int256 amountSpecified,
        bool zeroForOne
    ) internal pure returns (int256 amount0, int256 amount1) {
        if (amountSpecified > 0) {
            (amount0, amount1) = zeroForOne
                ? (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated)
                : (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining);
        } else {
            (amount0, amount1) = zeroForOne
                ? (state.amountCalculated, amountSpecified - state.amountSpecifiedRemaining)
                : (amountSpecified - state.amountSpecifiedRemaining, state.amountCalculated);
        }
    }

    function quoteSwap(
        address poolAddress,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bool zeroForOne,
        uint32 secondsAgo
    ) internal view returns (int256 amount0, int256 amount1) {
        require(amountSpecified < 0, "QSEA");

        PoolState memory initialPoolState = fetchState(poolAddress, secondsAgo);
        uint160 sqrtPriceNextX96;

        (SwapState memory state, uint128 liquidity, uint160 sqrtPriceX96) = setInitialState(
            initialPoolState,
            amountSpecified,
            sqrtPriceLimitX96,
            zeroForOne
        );

        while (state.amountSpecifiedRemaining != 0 && sqrtPriceX96 != sqrtPriceLimitX96)
            (sqrtPriceNextX96, sqrtPriceX96, liquidity) = processSwapWithinTick(
                IUniswapV3Pool(poolAddress),
                initialPoolState,
                state,
                sqrtPriceX96,
                liquidity,
                sqrtPriceLimitX96,
                zeroForOne,
                false
            );

        (amount0, amount1) = returnedAmount(state, amountSpecified, zeroForOne);
    }

    function quoteSwapExactAmount(
        address poolAddress,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bool zeroForOne,
        uint32 secondsAgo
    ) internal view returns (int256 amount0, int256 amount1) {
        require(amountSpecified > 0, "QSEA");

        PoolState memory initialPoolState = fetchState(poolAddress, secondsAgo);
        uint160 sqrtPriceNextX96;

        (SwapState memory state, uint128 liquidity, uint160 sqrtPriceX96) = setInitialState(
            initialPoolState,
            amountSpecified,
            sqrtPriceLimitX96,
            zeroForOne
        );

        while (state.amountSpecifiedRemaining != 0 && sqrtPriceX96 != sqrtPriceLimitX96)
            (sqrtPriceNextX96, sqrtPriceX96, liquidity) = processSwapWithinTick(
                IUniswapV3Pool(poolAddress),
                initialPoolState,
                state,
                sqrtPriceX96,
                liquidity,
                sqrtPriceLimitX96,
                zeroForOne,
                true
            );

        (amount0, amount1) = returnedAmount(state, amountSpecified, zeroForOne);
    }
}
