import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { WBTC, DAI, USDT, WETH } from "../tokens";

export function shouldPerformCorrectQuote(): void {
  it("test with a stable pair DAI:USDT", async function () {
    const amount = ethers.utils.parseUnits("1000",18);

    const expectedAmountToReceive0 =
      await this.uniswap.callStatic.quoteExactInputSingle(
        DAI,
        USDT,
        500,
        amount,
        0
      );

      console.log("Lens quoter result DAI -> USDT", ethers.utils.formatUnits(expectedAmountToReceive0, 6));

      const expectedAmountToReceive1 = await this.quoter.estimateMaxSwapUniswapV3(
        DAI,
        USDT,
        amount,
        500
      );

      console.log("On-chain quoter result DAI -> USDT", ethers.utils.formatUnits(expectedAmountToReceive1, 6));
  
      const minimum = expectedAmountToReceive0.lt(expectedAmountToReceive1) ? expectedAmountToReceive0 : expectedAmountToReceive1;
      const maximum = expectedAmountToReceive0.gt(expectedAmountToReceive1) ? expectedAmountToReceive0 : expectedAmountToReceive1;
  
      expect((maximum - minimum) / minimum < 0.01, "Oracle price mismatch");
  });

  it("test with a non stable pair WBTC:USDT", async function () {
    const amount = ethers.utils.parseUnits("10", 8);

    const expectedAmountToReceive0 =
      await this.uniswap.callStatic.quoteExactInputSingle(
        WBTC,
        USDT,
        3000,
        amount,
        0
      );

      console.log("Lens quoter result WBTC -> USDT", ethers.utils.formatUnits(expectedAmountToReceive0, 6));

      const expectedAmountToReceive1 = await this.quoter.estimateMaxSwapUniswapV3(
        WBTC,
        USDT,
        amount,
        3000
      );

      console.log("On-chain quoter result WBTC -> USDT", ethers.utils.formatUnits(expectedAmountToReceive1, 6));
  
      const minimum = expectedAmountToReceive0.lt(expectedAmountToReceive1) ? expectedAmountToReceive0 : expectedAmountToReceive1;
      const maximum = expectedAmountToReceive0.gt(expectedAmountToReceive1) ? expectedAmountToReceive0 : expectedAmountToReceive1;
  
      expect((maximum - minimum) / minimum < 0.01, "Oracle price mismatch");
  });

  it("test with a big swap WETH:DAI", async function () {
    const amount = ethers.utils.parseUnits("1000", 18);

    const expectedAmountToReceive0 =
      await this.uniswap.callStatic.quoteExactInputSingle(
        WETH,
        DAI,
        3000,
        amount,
        0
      );

      console.log("Lens quoter result WETH -> DAI", ethers.utils.formatUnits(expectedAmountToReceive0, 18));

      const expectedAmountToReceive1 = await this.quoter.estimateMaxSwapUniswapV3(
        WETH,
        DAI,
        amount,
        3000
      );

      console.log("On-chain quoter result WETH -> DAI", ethers.utils.formatUnits(expectedAmountToReceive1, 18));
  
      const minimum = expectedAmountToReceive0.lt(expectedAmountToReceive1) ? expectedAmountToReceive0 : expectedAmountToReceive1;
      const maximum = expectedAmountToReceive0.gt(expectedAmountToReceive1) ? expectedAmountToReceive0 : expectedAmountToReceive1;
  
      expect((maximum - minimum) / minimum < 0.01, "Oracle price mismatch");
  });

}
