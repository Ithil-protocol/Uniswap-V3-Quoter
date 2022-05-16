import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import type { Fixture } from "ethereum-waffle";

import type { Quoter } from "../src/types/Quoter";

declare module "mocha" {
  export interface Context {
    quoter: Quoter;
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
    signers: Signers;
  }
}

export interface Signers {
  trader: SignerWithAddress;
}
