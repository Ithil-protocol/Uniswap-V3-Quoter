// SPDX-License-Identifier: MIT
pragma solidity >=0.8.6;
pragma experimental ABIEncoderV2;

import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { IUniswapV3Pool } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import { TickMath } from "./libraries/TickMath.sol";
import { IQuoter } from "./interfaces/IQuoter.sol";
import { UniswapV3Quoter } from "./UniswapV3Quoter.sol";

contract Quoter is IQuoter, UniswapV3Quoter {
    IUniswapV3Factory internal constant uniV3Factory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    // This should be equal to quoteExactInputSingle(_fromToken, _toToken, _poolFee, _amount, 0)
    // todo: add price limit
    function estimateAmountOut(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        uint24 _poolFee,
        uint32 secondsAgo
    ) public view override returns (uint256) {
        address pool = uniV3Factory.getPool(_fromToken, _toToken, _poolFee);

        return _estimateOutputSingle(_toToken, _fromToken, _amount, pool, secondsAgo);
    }

    // This should be equal to quoteExactOutputSingle(_fromToken, _toToken, _poolFee, _amount, 0)
    // todo: add price limit
    function estimateAmountIn(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        uint24 _poolFee,
        uint32 secondsAgo
    ) public view override returns (uint256) {
        address pool = uniV3Factory.getPool(_fromToken, _toToken, _poolFee);

        return _estimateInputSingle(_fromToken, _toToken, _amount, pool, secondsAgo);
    }

    // todo: add price limit
    function _estimateOutputSingle(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        address _pool,
        uint32 secondsAgo
    ) internal view returns (uint256 amountOut) {
        bool zeroForOne = _fromToken > _toToken;
        // todo: price limit?
        (int256 amount0, int256 amount1) = quoteSwapExactAmount(
            _pool,
            int256(_amount),
            zeroForOne ? (TickMath.MIN_SQRT_RATIO + 1) : (TickMath.MAX_SQRT_RATIO - 1),
            zeroForOne,
            secondsAgo
        );
        if (zeroForOne) amountOut = amount1 > 0 ? uint256(amount1) : uint256(-amount1);
        else amountOut = amount0 > 0 ? uint256(amount0) : uint256(-amount0);
    }

    // todo: add price limit
    function _estimateInputSingle(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        address _pool,
        uint32 secondsAgo
    ) internal view returns (uint256 amountOut) {
        bool zeroForOne = _fromToken < _toToken;
        // todo: price limit?
        (int256 amount0, int256 amount1) = quoteSwap(
            _pool,
            -int256(_amount),
            zeroForOne ? (TickMath.MIN_SQRT_RATIO + 1) : (TickMath.MAX_SQRT_RATIO - 1),
            zeroForOne,
            secondsAgo
        );
        if (zeroForOne) amountOut = amount0 > 0 ? uint256(amount0) : uint256(-amount0);
        else amountOut = amount1 > 0 ? uint256(amount1) : uint256(-amount1);
    }

    // For future reference
    function _findBestFee(address token0, address token1) internal view returns (uint24 fee) {
        uint128 bestLiquidity = 0;
        uint16[4] memory fees = [100, 500, 3000, 10000];

        for (uint8 i = 0; i < 4; i++) {
            try IUniswapV3Pool(uniV3Factory.getPool(token0, token1, uint24(fees[i]))).liquidity() returns (
                uint128 nextLiquidity
            ) {
                if (nextLiquidity > bestLiquidity) {
                    bestLiquidity = nextLiquidity;
                    fee = fees[i];
                }
            } catch {}
        }

        require(bestLiquidity > 0, "No pool found for the token pair");
    }
}
