const { expect } = require("chai");
const { ethers } = require("hardhat");

import { BigNumber, Contract, ContractFactory, Signer } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ethers, network, upgrades } from "hardhat";
let MasterPool: ContractFactory;
let masterPool: Contract;
let RevPool :ContractFactory;
let revPool :Contract;
let LuckyToken:ContractFactory;
let luckyToken:Contract; 

let owner: SignerWithAddress;
let addr1: SignerWithAddress;
let addr2: SignerWithAddress;
let addr3: SignerWithAddress;
let addr4: SignerWithAddress;
let addr5: SignerWithAddress;

describe("MasterPool Test", function () {

  beforeEach(async function () {
    // Get the ContractFactory and Signers here.
    MasterPool = await ethers.getContractFactory("MasterPool");
    LuckyToken = await ethers.getContractFactory("LuckyToken");
    RevPool = await ethers.getContractFactory("RevPool");
    [owner, addr1, addr2, addr3, addr4, addr5] =await ethers.getSigners();

    masterPool = await MasterPool.deploy(
      luckyBusd,
      owner.address,
      dev.address
    )
    
    await masterPool.deployed();





  it("Should return the new greeting once it's changed", async function () {
    const Greeter = await ethers.getContractFactory("Greeter");
    const greeter = await Greeter.deploy("Hello, world!");
    await greeter.deployed();

    expect(await greeter.greet()).to.equal("Hello, world!");

    const setGreetingTx = await greeter.setGreeting("Hola, mundo!");

    // wait until the transaction is mined
    await setGreetingTx.wait();

    expect(await greeter.greet()).to.equal("Hola, mundo!");
  });
});
