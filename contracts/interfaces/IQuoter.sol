// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;

interface IQuoter {
    function estimateAmountOut(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        uint24 _poolFee,
        uint32 secondsAgo
    ) external view returns (uint256);

    function estimateAmountIn(
        address _fromToken,
        address _toToken,
        uint256 _amount,
        uint24 _poolFee,
        uint32 secondsAgo
    ) external view returns (uint256);
}
