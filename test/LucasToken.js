const { expect } = require("chai");
const { ethers } = require("hardhat");
const { parseEther } = require("ethers"); // Direct import for Ethers v6

describe("LucasToken", function () {
  let token, owner, addr1, addr2;

  beforeEach(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();
    const LucasToken = await ethers.getContractFactory("LucasToken");
    token = await LucasToken.deploy(owner.address);
  });

  it("Should deploy with correct initial supply", async function () {
    const ownerBalance = await token.balanceOf(owner.address);
    expect(ownerBalance).to.equal(parseEther("1000000")); // Updated
  });

  it("Should allow token purchase", async function () {
    await token.connect(addr1).buyTokens(parseEther("1000"), { // Updated
      value: parseEther("1"), // Updated
    });
    const addr1Balance = await token.balanceOf(addr1.address);
    expect(addr1Balance).to.equal(parseEther("1000")); // Updated
  });

  it("Should distribute and claim profits", async function () {
    await token.connect(addr1).buyTokens(parseEther("1000"), { // Updated
      value: parseEther("1"), // Updated
    });

    await token.announceDistribution();
    await ethers.provider.send("evm_increaseTime", [86400]); // Fast forward 1 day
    await ethers.provider.send("evm_mine", []);
    await token.distributeProfit({ value: parseEther("1") }); // Updated

    await ethers.provider.send("evm_increaseTime", [86400]); // Wait min holding period
    await ethers.provider.send("evm_mine", []);
    const addr1BalanceBefore = await ethers.provider.getBalance(addr1.address);
    await token.connect(addr1).claimProfit(0);
    const addr1BalanceAfter = await ethers.provider.getBalance(addr1.address);
    expect(addr1BalanceAfter).to.be.above(addr1BalanceBefore);
  });

  it("Should handle token transfers", async function () {
    await token.transfer(addr1.address, parseEther("500")); // Updated
    const addr1Balance = await token.balanceOf(addr1.address);
    expect(addr1Balance).to.equal(parseEther("500")); // Updated
  });
});