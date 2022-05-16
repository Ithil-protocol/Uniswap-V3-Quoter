import { task } from "hardhat/config";
import { TaskArguments } from "hardhat/types";

import { Quoter } from "../src/types/Quoter";
import { Quoter__factory } from "../src/types/factories/Quoter__factory";

task("deploy").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const quoterFactory: Quoter__factory = <Quoter__factory>await ethers.getContractFactory("Quoter");
  const quoter: Quoter = <Quoter>await quoterFactory.deploy();
  await quoter.deployed();
  console.log("Quoter deployed to: ", quoter.address);
});
