import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { time } from '@nomicfoundation/hardhat-network-helpers';
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
      /* refundable= */ true,
    );
    await da.deployed();

    [owner, readonly] = await ethers.getSigners();
    ownerConn = da.connect(owner);
    readonlyConn = da.connect(readonly);
  });

  describe('set config', function () {
    it('can set the config', async () => {
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
    });

    it('reverts on invalid config time', async () => {
      const startAmountInWei = 100;
      const endAmountInWei = 10;
      let startTime = 2000;
      const endTime = 2000;
      const roundUp = true;

      await expect(
        ownerConn.setConfig(
          startAmountInWei,
          endAmountInWei,
          startTime,
          startTime,
          roundUp,
        ),
      ).to.be.revertedWith('InvalidStartEndTime');

      startTime = 0;
      await expect(
        ownerConn.setConfig(
          startAmountInWei,
          endAmountInWei,
          startTime,
          endTime,
          roundUp,
        ),
      ).to.be.revertedWith('InvalidStartEndTime');
    });

    it('reverts on invalid amount', async () => {
      const startAmountInWei = 0;
      const endAmountInWei = 10;
      const startTime = 2000;
      const endTime = 1664833933;
      const roundUp = true;

      await expect(
        ownerConn.setConfig(
          startAmountInWei,
          endAmountInWei,
          startTime,
          endTime,
          roundUp,
        ),
      ).to.be.revertedWith('InvalidAmountInWei');
    });

    it('reverts if not owner', async () => {
      const startAmountInWei = 0;
      const endAmountInWei = 10;
      const startTime = 2000;
      const endTime = 1664833933;
      const roundUp = true;

      await expect(
        readonlyConn.setConfig(
          startAmountInWei,
          endAmountInWei,
          startTime,
          endTime,
          roundUp,
        ),
      ).to.be.revertedWith('Ownable');
    });
  });

  describe('Get current price', function () {
    const getRandomInt = (max: number) => Math.floor(Math.random() * max);

    const runs = [
      {
        name: 'increasing, start point, round up',
        startAmountInWei: 100,
        endAmountInWei: 200,
        startTimeOffst: 0,
        endTimeOffset: 1000,
        roundUp: true,
        expectedPrice: 100,
      },
      {
        name: 'increasing, start point, round down',
        startAmountInWei: 1,
        endAmountInWei: 100,
        startTimeOffst: 0,
        endTimeOffset: 1000,
        roundUp: false,
        expectedPrice: 1,
      },
      {
        name: 'increasing, mid point, round up',
        startAmountInWei: 100,
        endAmountInWei: 201,
        startTimeOffst: -1000,
        endTimeOffset: 1000,
        roundUp: true,
        expectedPrice: 151,
      },
      {
        name: 'increasing, mid point, round down',
        startAmountInWei: 100,
        endAmountInWei: 201,
        startTimeOffst: -1000,
        endTimeOffset: 1000,
        roundUp: false,
        expectedPrice: 150,
      },
      {
        name: 'increasing, 25th point, round up',
        startAmountInWei: 100,
        endAmountInWei: 901,
        startTimeOffst: -250,
        endTimeOffset: 750,
        roundUp: true,
        expectedPrice: 301,
      },
      {
        name: 'increasing, 75th point, round down',
        startAmountInWei: 100,
        endAmountInWei: 901,
        startTimeOffst: -750,
        endTimeOffset: 250,
        roundUp: false,
        expectedPrice: 700,
      },
      {
        name: 'increasing, end point, round up',
        startAmountInWei: 100,
        endAmountInWei: 200,
        startTimeOffst: -1000,
        endTimeOffset: 0,
        roundUp: true,
        expectedPrice: 200,
      },
      {
        name: 'increasing, end point, round down',
        startAmountInWei: 100,
        endAmountInWei: 200,
        startTimeOffst: -1000,
        endTimeOffset: 0,
        roundUp: false,
        expectedPrice: 200,
      },

      {
        name: 'decreasing, start point, round up',
        startAmountInWei: 100,
        endAmountInWei: 99,
        startTimeOffst: 0,
        endTimeOffset: 999,
        roundUp: true,
        expectedPrice: 100,
      },
      {
        name: 'decreasing, start point, round down',
        startAmountInWei: 100,
        endAmountInWei: 1,
        startTimeOffst: 0,
        endTimeOffset: 1000,
        roundUp: false,
        expectedPrice: 100,
      },
      {
        name: 'decreasing, mid point, round up',
        startAmountInWei: 100,
        endAmountInWei: 99,
        startTimeOffst: -1000,
        endTimeOffset: 1000,
        roundUp: true,
        expectedPrice: 100,
      },
      {
        name: 'decreasing, mid point, round down',
        startAmountInWei: 100,
        endAmountInWei: 99,
        startTimeOffst: -1000,
        endTimeOffset: 1000,
        roundUp: false,
        expectedPrice: 99,
      },
      {
        name: 'decreasing, 25th point, round up',
        startAmountInWei: 100,
        endAmountInWei: 1,
        startTimeOffst: -100,
        endTimeOffset: 300,
        roundUp: true,
        expectedPrice: 76,
      },
      {
        name: 'decreasing, 75th point, round down',
        startAmountInWei: 100,
        endAmountInWei: 1,
        startTimeOffst: -30,
        endTimeOffset: 10,
        roundUp: false,
        expectedPrice: 25,
      },
      {
        name: 'decreasing, end point, round up',
        startAmountInWei: 100,
        endAmountInWei: 1,
        startTimeOffst: -1000,
        endTimeOffset: 0,
        roundUp: true,
        expectedPrice: 1,
      },
      {
        name: 'decreasing, end point, round down',
        startAmountInWei: 100,
        endAmountInWei: 2,
        startTimeOffst: -1000,
        endTimeOffset: 0,
        roundUp: false,
        expectedPrice: 2,
      },

      {
        name: 'same, start point, round up',
        startAmountInWei: 100,
        endAmountInWei: 100,
        startTimeOffst: 0,
        endTimeOffset: 999,
        roundUp: true,
        expectedPrice: 100,
      },
      {
        name: 'same, mid point, round down',
        startAmountInWei: 99,
        endAmountInWei: 99,
        startTimeOffst: -1000,
        endTimeOffset: 1000,
        roundUp: false,
        expectedPrice: 99,
      },
      {
        name: 'same, 25th point, round up',
        startAmountInWei: 99,
        endAmountInWei: 99,
        startTimeOffst: -100,
        endTimeOffset: 300,
        roundUp: true,
        expectedPrice: 99,
      },
      {
        name: 'same, 75th point, round down',
        startAmountInWei: 101,
        endAmountInWei: 101,
        startTimeOffst: -30,
        endTimeOffset: 10,
        roundUp: false,
        expectedPrice: 101,
      },
      {
        name: 'same, random point, round up',
        startAmountInWei: 100,
        endAmountInWei: 100,
        startTimeOffst: -1 * getRandomInt(100),
        endTimeOffset: getRandomInt(100),
        roundUp: true,
        expectedPrice: 100,
      },
      {
        name: 'same, end point, round down',
        startAmountInWei: 100,
        endAmountInWei: 100,
        startTimeOffst: -1000,
        endTimeOffset: 0,
        roundUp: false,
        expectedPrice: 100,
      },
    ];

    runs.forEach((run) => {
      it(run.name, async () => {
        const latestTime = await time.latest();
        // Set a large offset 1000s so we won't accidently set the next block time to the past.
        const nextBlockTime = latestTime + 1000;
        const startTime = nextBlockTime + run.startTimeOffst;
        const endTime = nextBlockTime + run.endTimeOffset;

        await ownerConn.setConfig(
          run.startAmountInWei,
          run.endAmountInWei,
          startTime,
          endTime,
          run.roundUp,
        );

        await time.increaseTo(nextBlockTime);

        expect(await readonlyConn.getCurrentPriceInWei()).to.be.equal(
          run.expectedPrice,
        );
      });
    });
  });

  describe('Bid', function () {
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

      // Second claim will fail
      await expect(readonlyConn.claimRefund()).to.be.revertedWith(
        'UserAlreadyClaimed',
      );
    });

    it('can make bids for non-refundable type of DA', async () => {
      const DA = await ethers.getContractFactory('DutchAuction');
      const da = await DA.deploy(
        'Test',
        'TEST',
        '',
        1000,
        0,
        ethers.constants.AddressZero,
        /* refundable= */ false,
      );
      await da.deployed();

      [owner, readonly] = await ethers.getSigners();
      ownerConn = da.connect(owner);
      readonlyConn = da.connect(readonly);

      await ethers.provider.send('hardhat_setBalance', [
        readonly.address,
        ONE_ETH,
      ]);

      const startAmountInWei = 20;
      const endAmountInWei = 10;
      const currentTime = await time.latest();
      const startTime = currentTime - 1000;
      const endTime = currentTime + 1000;
      const roundUp = true;

      await ownerConn.setConfig(
        startAmountInWei,
        endAmountInWei,
        startTime,
        endTime,
        roundUp,
      );

      await expect(readonlyConn.bid(1, { value: 15 }))
        .to.emit(readonlyConn, 'Transfer')
        .to.emit(readonlyConn, 'Bid')
        .withArgs(readonly.address, 1, 15);

      await expect(readonlyConn.claimRefund()).to.be.revertedWith(
        'NotRefundable',
      );
    });

    it('reverts if after auction closes', async () => {
      const startAmountInWei = 20;
      const endAmountInWei = 10;
      const currentTime = await time.latest();
      const startTime = currentTime - 1000;
      const endTime = currentTime + 1000;
      const roundUp = true;

      await ownerConn.setConfig(
        startAmountInWei,
        endAmountInWei,
        startTime,
        endTime,
        roundUp,
      );

      await time.increaseTo(endTime + 1);

      await expect(readonlyConn.bid(1, { value: 100 })).to.be.revertedWith(
        'InvalidStartEndTime',
      );
    });

    it('reverts if before auction starts', async () => {
      const startAmountInWei = 20;
      const endAmountInWei = 10;
      const currentTime = await time.latest();
      const startTime = currentTime + 1000;
      const endTime = currentTime + 2000;
      const roundUp = true;

      await ownerConn.setConfig(
        startAmountInWei,
        endAmountInWei,
        startTime,
        endTime,
        roundUp,
      );

      await time.increaseTo(startTime - 10);

      await expect(readonlyConn.bid(1, { value: 100 })).to.be.revertedWith(
        'InvalidStartEndTime',
      );
    });

    it('reverts if no enough supply', async () => {
      const startAmountInWei = 20;
      const endAmountInWei = 10;
      const currentTime = await time.latest();
      const startTime = currentTime - 1000;
      const endTime = currentTime + 1000;
      const roundUp = true;

      await ownerConn.setConfig(
        startAmountInWei,
        endAmountInWei,
        startTime,
        endTime,
        roundUp,
      );

      // Total supply is 1000.
      await expect(readonlyConn.bid(1001, { value: 100 })).to.be.revertedWith(
        'NoSupplyLeft',
      );
    });

    it('reverts if not send enough value', async () => {
      const startAmountInWei = 10;
      const endAmountInWei = 10;
      const currentTime = await time.latest();
      const startTime = currentTime - 1000;
      const endTime = currentTime + 1000;
      const roundUp = true;

      await ownerConn.setConfig(
        startAmountInWei,
        endAmountInWei,
        startTime,
        endTime,
        roundUp,
      );

      // Total supply is 1000.
      await expect(
        readonlyConn.bid(1000, { value: 10 * 1000 - 1 }),
      ).to.be.revertedWith('NotEnoughValue');
    });

    it('revert if claim and auction not ended', async () => {
      const startAmountInWei = 20;
      const endAmountInWei = 10;
      const currentTime = await time.latest();
      const startTime = currentTime - 1000;
      const endTime = currentTime + 1000;
      const roundUp = true;

      await ownerConn.setConfig(
        startAmountInWei,
        endAmountInWei,
        startTime,
        endTime,
        roundUp,
      );

      // Total supply is 1000.
      await expect(readonlyConn.claimRefund()).to.be.revertedWith('NotEnded');
    });
  });
});
