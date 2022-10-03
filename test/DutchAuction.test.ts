import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import chai, { expect } from 'chai';
import chaiAsPromised from 'chai-as-promised';
import { ethers } from 'hardhat';
import { DutchAuction } from '../typechain-types';

chai.use(chaiAsPromised);

const ONE_ETH = '0xDE0B6B3A7640000';

describe('DutchAuction', function () {
  let ownerConn: DutchAuction;
  let readonlyConn: DutchAuction;
  let owner: SignerWithAddress;
  let readonly: SignerWithAddress;

  beforeEach(async () => {
    await ethers.provider.send('hardhat_reset', []);
    const DA = await ethers.getContractFactory('DutchAuction');
    const da = await DA.deploy(
      'Test',
      'TEST',
      '',
      1000,
      0,
      ethers.constants.AddressZero,
      true,
    );
    await da.deployed();

    [owner, readonly] = await ethers.getSigners();
    ownerConn = da.connect(owner);
    readonlyConn = da.connect(readonly);
  });

  it('can set the config for DA', async () => {
    const startAmountInWei = 100;
    const endAmountInWei = 10;
    const startTime = 2000;
    const endTime = 1664833933;
    const roundUp = true;
    await ownerConn.setConfig(
      startAmountInWei,
      endAmountInWei,
      startTime,
      endTime,
      roundUp,
    );
    const config = await readonlyConn.getConfig();
    expect(config.startAmountInWei).to.eq(startAmountInWei);
    expect(config.endAmountInWei).to.eq(endAmountInWei);
    expect(config.startTime).to.eq(startTime);
    expect(config.endTime).to.eq(endTime);
    expect(config.roundUp).to.eq(roundUp);

    // invalid config time
    await expect(
      ownerConn.setConfig(
        startAmountInWei,
        endAmountInWei,
        startTime,
        startTime,
        roundUp,
      ),
    ).to.be.revertedWith('InvalidStartEndTime');

    await expect(
      ownerConn.setConfig(0, endAmountInWei, startTime, endTime, roundUp),
    ).to.be.revertedWith('InvalidAmountInWei');
  });

  it('can make bids for refundable type of DA - happy code path without roundUp', async () => {
    const duration = 4000;
    const startAmountInWei = 100;
    const endAmountInWei = 10;
    const startTime = Math.floor(new Date().getTime() / 1000);
    const endTime = startTime + duration;
    const roundUp = false;
    await ownerConn.setConfig(
      startAmountInWei,
      endAmountInWei,
      startTime,
      endTime,
      roundUp,
    );
    await ethers.provider.send('hardhat_setBalance', [
      readonly.address,
      ONE_ETH,
    ]);

    // mock the timestamp so that we can make bids
    let now;
    let expectedSettledPrice;
    now = endTime - 1000;
    await ethers.provider.send('evm_mine', [now]);
    expectedSettledPrice = Math.floor(
      startAmountInWei -
        ((startAmountInWei - endAmountInWei) * (now - startTime)) /
          (endTime - startTime),
    );
    await expect(readonlyConn.bid(1, { value: 100 }))
      .to.emit(readonlyConn, 'Transfer')
      .to.emit(readonlyConn, 'Bid')
      .withArgs(readonly.address, 1, expectedSettledPrice);
    // mock the timestamp so that we can make bids again
    now = endTime - 900;
    await ethers.provider.send('evm_mine', [now]);
    expectedSettledPrice = Math.floor(
      startAmountInWei -
        ((startAmountInWei - endAmountInWei) * (now - startTime)) /
          (endTime - startTime),
    );
    await expect(readonlyConn.bid(1, { value: 100 }))
      .to.emit(readonlyConn, 'Transfer')
      .to.emit(readonlyConn, 'Bid')
      .withArgs(readonly.address, 1, expectedSettledPrice);

    // mock the timestamp so that we can claim refund
    now = endTime + 1000;
    await ethers.provider.send('evm_mine', [now]);
    await expect(readonlyConn.claimRefund()).to.emit(
      readonlyConn,
      'ClaimRefund',
    );
    const settledPrice = await readonlyConn.getSettledPriceInWei();
    expect(settledPrice).to.eq(expectedSettledPrice);
  });

  it('can make bids for refundable type of DA - happy code path with roundUp', async () => {
    const duration = 4000;
    const startAmountInWei = 100;
    const endAmountInWei = 10;
    const startTime = Math.floor(new Date().getTime() / 1000);
    const endTime = startTime + duration;
    const roundUp = true;
    await ownerConn.setConfig(
      startAmountInWei,
      endAmountInWei,
      startTime,
      endTime,
      roundUp,
    );
    await ethers.provider.send('hardhat_setBalance', [
      readonly.address,
      ONE_ETH,
    ]);

    // mock the timestamp so that we can make bids
    let now;
    let expectedSettledPrice;
    now = endTime - 1000;
    await ethers.provider.send('evm_mine', [now]);
    expectedSettledPrice = Math.ceil(
      startAmountInWei -
        ((startAmountInWei - endAmountInWei) * (now - startTime)) /
          (endTime - startTime),
    );
    await expect(readonlyConn.bid(1, { value: 100 }))
      .to.emit(readonlyConn, 'Transfer')
      .to.emit(readonlyConn, 'Bid')
      .withArgs(readonly.address, 1, expectedSettledPrice);
    // mock the timestamp so that we can make bids again
    now = endTime - 900;
    await ethers.provider.send('evm_mine', [now]);
    expectedSettledPrice = Math.ceil(
      startAmountInWei -
        ((startAmountInWei - endAmountInWei) * (now - startTime)) /
          (endTime - startTime),
    );
    await expect(readonlyConn.bid(1, { value: 100 }))
      .to.emit(readonlyConn, 'Transfer')
      .to.emit(readonlyConn, 'Bid')
      .withArgs(readonly.address, 1, expectedSettledPrice);

    // mock the timestamp so that we can claim refund
    now = endTime + 1000;
    await ethers.provider.send('evm_mine', [now]);

    const contractBalanceBeforeClaim = (
      await readonlyConn.provider.getBalance(ownerConn.address)
    ).toNumber();
    await expect(readonlyConn.claimRefund()).to.emit(
      readonlyConn,
      'ClaimRefund',
    );
    const contractBalanceAfterClaim = (
      await readonlyConn.provider.getBalance(ownerConn.address)
    ).toNumber();
    expect(contractBalanceAfterClaim - contractBalanceBeforeClaim).to.eq(
      -(100 * 2 - expectedSettledPrice * 2),
    );
    const settledPrice = await readonlyConn.getSettledPriceInWei();
    expect(settledPrice).to.eq(expectedSettledPrice);
  });
});
