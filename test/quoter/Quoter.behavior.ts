import { expect } from "chai";
import { ethers } from "hardhat";
import { BigNumber } from "ethers";
import { WBTC, USDT } from "../tokens";

export function shouldPerformCorrectQuote(): void {
  it("test with stable pair USDT:WBTC", async function () {
    const amount = ethers.utils.parseUnits("100000000", 6);

    const expectedAmountToReceive0 =
      await this.uniswap.callStatic.quoteExactInputSingle(
        WBTC,
        USDT,
        3000,
        amount,
        0
      );

      console.log("Lens result WBTC -> USDT", ethers.utils.formatUnits(expectedAmountToReceive0, 6));

      const expectedAmountToReceive1 = await this.quoter.estimateMaxSwapUniswapV3(
        WBTC,
        USDT,
        amount,
        3000
      );

      console.log("Quoter result WBTC -> USDT", ethers.utils.formatUnits(expectedAmountToReceive1, 6));
  
      const minimum = expectedAmountToReceive0.lt(expectedAmountToReceive1) ? expectedAmountToReceive0 : expectedAmountToReceive1;
      const maximum = expectedAmountToReceive0.gt(expectedAmountToReceive1) ? expectedAmountToReceive0 : expectedAmountToReceive1;
  
      expect((maximum - minimum) / minimum < 0.01, "Oracle price mismatch");
  });
}
