import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import type { Quoter } from "../../src/types/Quoter";
import { Signers } from "../types";
import { shouldObservePastQuote, shouldPerformCorrectQuote } from "./Quoter.behavior";

import { abi } from "@uniswap/v3-periphery/artifacts/contracts/lens/Quoter.sol/Quoter.json";

describe("Tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.trader = signers[0];

    const quoterArtifact: Artifact = await artifacts.readArtifact("Quoter");
    this.quoter = <Quoter>await waffle.deployContract(this.signers.trader, quoterArtifact, []);

    this.uniswap = await ethers.getContractAt(abi, "0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6");
  });

  describe("Quoter Integration Tests", function () {
    shouldPerformCorrectQuote();
    shouldObservePastQuote();
  });
});
