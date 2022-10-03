import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import chai, { expect } from 'chai';
import chaiAsPromised from 'chai-as-promised';
import { ethers } from 'hardhat';
import { BucketAuction } from '../typechain-types';

chai.use(chaiAsPromised);

const ONE_ETH = '0xDE0B6B3A7640000';

describe('BucketAuction', function () {
  let ba: BucketAuction;
  let ownerConn: BucketAuction;
  let readonlyConn: BucketAuction;
  let owner: SignerWithAddress;
  let readonly: SignerWithAddress;

  beforeEach(async () => {
    const BA = await ethers.getContractFactory('BucketAuction');
    ba = await BA.deploy('Test', 'TEST', '', /* maxMintableSupply= */ 1000, /* globalWalletLimit= */ 0, ethers.constants.AddressZero, /* minimumContributionInWei= */ 100);
    await ba.deployed();

    [owner, readonly] = await ethers.getSigners();
    ownerConn = ba.connect(owner);
    readonlyConn = ba.connect(readonly);
  });

  it('Contract can be set Active/Inactive', async () => {
    // starts as Inactive
    expect(await ownerConn.getAuctionActive()).to.be.false;

    // as an owner, we can set it to be active
    await ownerConn.setAuctionActive(true);
    expect(await ownerConn.getAuctionActive()).to.be.true;

    // as an owner, we can set it to be inactive again
    await ownerConn.setAuctionActive(false);
    expect(await ownerConn.getAuctionActive()).to.be.false;

    // as an owner, if it's mintable, we cannot set this function
    await ownerConn.setMintable(true);
    await expect(ownerConn.setAuctionActive(true)).to.be.revertedWith('Mintable');
    await ownerConn.setMintable(false); // clean up

    // as an owner, if the price is set, we cannot set this function
    await ownerConn.setPrice(100);
    await expect(ownerConn.setAuctionActive(true)).to.be.revertedWith('PriceHasBeenSet');
    await ownerConn.setPrice(0); // clean up

    // as an readonly user, we cannot set it to be active
    await expect(readonlyConn.setAuctionActive(true)).to.be.revertedWith('Ownable');
  });

  describe('Bidding', function () {
    it('Reverts if auction not active', async () => {
      // it starts as Inactive, so we cannot make bids
      await expect(readonlyConn.bid()).to.be.revertedWith('BucketAuctionNotActive');
    });

    it('Reverts if bid under minimum', async () => {
      await ownerConn.setAuctionActive(true);

      // we cannot bid under the minimum
      await expect(readonlyConn.bid({value: 10})).to.be.revertedWith('LowerThanMinBidAmount');
    });

    it('Can make bids', async () => {
      await ownerConn.setAuctionActive(true);

      await ethers.provider.send('hardhat_setBalance', [
        readonly.address,
        ONE_ETH,
      ]);
      await expect(readonlyConn.bid({value: 100})).to.emit(readonlyConn, 'Bid');
      let userData = await readonlyConn.getUserData(readonly.address);
      expect(userData.contribution).to.eq(100);
      expect(userData.tokensClaimed).to.eq(0);
      expect(userData.refundClaimed).to.eq(false);

      // we let the readonly user bid again
      await readonlyConn.bid({value: 100});
      userData = await readonlyConn.getUserData(readonly.address);
      expect(userData.contribution).to.eq(200);
      expect(userData.tokensClaimed).to.eq(0);
      expect(userData.refundClaimed).to.eq(false);
    });

    it('Revert if bid when collection is mintable', async () => {
      await ownerConn.setAuctionActive(true);

      // we cannot make bids when colleciton is mintable in the ERC721M stages
      await ownerConn.setMintable(true);
      await expect(readonlyConn.bid({value: 100})).to.be.revertedWith('Mintable');
    });
  });

  it('Can set minimum contribution', async () => {
    expect(await ownerConn.getMinimumContributionInWei()).to.be.equal(100);
    await expect(ownerConn.setMinimumContribution(999)).to.emit(ownerConn, 'SetMinimumContribution');
    expect(await readonlyConn.getMinimumContributionInWei()).to.be.equal(999);
    await expect(readonlyConn.setMinimumContribution(1999)).to.be.revertedWith('Ownable');
  });

  it('Can set price', async () => {
    // If the auction is active, then we cannot set price.
    await ownerConn.setAuctionActive(true);
    await expect(ownerConn.setPrice(200)).to.be.revertedWith('BucketAuctionActive');
    // Clean up
    await ownerConn.setAuctionActive(false);

    // If can mint, it means something weng wrong. Then we cannot set price.
    await ownerConn.setMintable(true);
    await expect(ownerConn.setPrice(200)).to.be.revertedWith('Mintable');
    // Clean up
    await ownerConn.setMintable(false);

    // If claimable, then we cannot set price.
    await ownerConn.setClaimable(true);
    await expect(ownerConn.setPrice(200)).to.be.revertedWith('CannotSetPriceIfClaimable');
    // Clean up
    await ownerConn.setClaimable(false);

    await expect(ownerConn.setPrice(200)).to.emit(ownerConn, 'SetPrice');
    expect(await readonlyConn.getPrice()).to.be.equal(200);
    await expect(readonlyConn.setPrice(200)).to.be.revertedWith('Ownable');
  });

  it('Can set claimable', async () => {
    expect(await ownerConn.getClaimable()).to.be.equal(false);

    // Only owner can set claimable
    await expect(readonlyConn.setClaimable(true)).to.be.revertedWith('Ownable');

    await ownerConn.setClaimable(true);
    expect(await ownerConn.getClaimable()).to.be.equal(true);
  });

  describe('Bucket auction calculation', function () {
    const runs = [
      {bids: [100], price: 100, refund: 0, numTokens: 1},
      {bids: [100, 1], price: 100, refund: 1, numTokens: 1},
      {bids: [100, 11, 88], price: 100, refund: 99, numTokens: 1},
      {bids: [100, 100], price: 100, refund: 0, numTokens: 2},
      {bids: [100], price: 99, refund: 1, numTokens: 1},
      {bids: [100], price: 101, refund: 100, numTokens: 0},
    ];

    runs.forEach((run) => {
      it(`Bid: ${run.bids}, price: ${run.price}`, async () => {
        await ownerConn.setAuctionActive(true);

        await ethers.provider.send('hardhat_setBalance', [
          readonly.address,
          ONE_ETH,
        ]);

        for (const bid of run.bids) {
          await expect(readonlyConn.bid({value: bid})).to.emit(readonlyConn, 'Bid');
        }

        const contribution = run.bids.reduce((a, b) => a + b, 0);
        let balance = (await ownerConn.provider.getBalance(ownerConn.address)).toNumber();
        expect(balance).to.eq(contribution);

        await ownerConn.setAuctionActive(false);
        await ownerConn.setPrice(run.price);
        await ownerConn.setClaimable(true);

        expect(await readonlyConn.amountPurchased(readonly.address)).to.be.equal(run.numTokens);
        expect(await readonlyConn.refundAmount(readonly.address)).to.be.equal(run.refund);

        await readonlyConn.claimTokensAndRefund();
        const userData = await readonlyConn.getUserData(readonly.address);
        expect(userData.contribution).to.eq(contribution);
        expect(userData.tokensClaimed).to.eq(run.numTokens);
        expect(userData.refundClaimed).to.eq(true);

        balance = (await ownerConn.provider.getBalance(ownerConn.address)).toNumber();
        expect(balance).to.eq(run.price * run.numTokens);
      })
    });
  })

  describe('User claim and refund', function () {
    it('user claimTokensAndRefund', async () => {
      // we then turn on the AuctionActive, so that we can start the bids
      await ownerConn.setAuctionActive(true);

      // we can make bids
      await ethers.provider.send('hardhat_setBalance', [
        readonly.address,
        ONE_ETH,
      ]);
      let balance = (await ownerConn.provider.getBalance(ownerConn.address)).toNumber();
      expect(balance).to.eq(0);
      await expect(readonlyConn.bid({value: 100})).to.emit(readonlyConn, 'Bid');

      balance = (await ownerConn.provider.getBalance(ownerConn.address)).toNumber();
      expect(balance).to.eq(100);

      // and then we prepare to close the auction and settle the price and refund
      await ownerConn.setAuctionActive(false);
      await ownerConn.setPrice(80);

      expect(await ownerConn.getClaimable()).to.be.false;
      await ownerConn.setClaimable(true);
      expect(await ownerConn.getClaimable()).to.be.true;

      await expect(readonlyConn.claimTokensAndRefund()).to.emit(readonlyConn, 'Transfer');
      const userData = await readonlyConn.getUserData(readonly.address);
      expect(userData.contribution).to.eq(100);
      expect(userData.tokensClaimed).to.eq(1);
      expect(userData.refundClaimed).to.eq(true);
      balance = (await ownerConn.provider.getBalance(ownerConn.address)).toNumber();
      expect(balance).to.eq(80);

      // we cannot claim again after the first successful claim
      await expect(readonlyConn.claimTokensAndRefund()).to.be.revertedWith('UserAlreadyClaimed');

      // withdraw
      await expect(ownerConn.withdraw()).to.emit(ownerConn, 'Withdraw');
      balance = (await ownerConn.provider.getBalance(ownerConn.address)).toNumber();
      expect(balance).to.eq(0);
    });

    it('user without bidding claimTokensAndRefund', async () => {
      await ownerConn.setPrice(80);
      await ownerConn.setClaimable(true);

      await expect(readonlyConn.claimTokensAndRefund()).to.not.emit(readonlyConn, 'Transfer');
      const userData = await readonlyConn.getUserData(readonly.address);
      expect(userData.contribution).to.eq(0);
      expect(userData.tokensClaimed).to.eq(0);
      expect(userData.refundClaimed).to.eq(true);
    });

    it('Reverts if price not set', async () => {
      await ownerConn.setAuctionActive(true);

      await ethers.provider.send('hardhat_setBalance', [
        readonly.address,
        ONE_ETH,
      ]);
      await expect(readonlyConn.bid({value: 100})).to.emit(readonlyConn, 'Bid');

      await ownerConn.setAuctionActive(false);
      await ownerConn.setClaimable(true);

      await expect(readonlyConn.claimTokensAndRefund()).to.be.revertedWith('PriceNotSet');
    });

    it('Reverts if not claimable', async () => {
      await ownerConn.setAuctionActive(true);

      await ethers.provider.send('hardhat_setBalance', [
        readonly.address,
        ONE_ETH,
      ]);
      await expect(readonlyConn.bid({value: 100})).to.emit(readonlyConn, 'Bid');

      await ownerConn.setAuctionActive(false);
      await ownerConn.setPrice(100);

      await expect(readonlyConn.claimTokensAndRefund()).to.be.revertedWith('NotClaimable');
    });

    it('Reverts if not enough supply', async () => {
      await ownerConn.setAuctionActive(true);

      await ethers.provider.send('hardhat_setBalance', [
        readonly.address,
        ONE_ETH,
      ]);

      await expect(readonlyConn.bid({value: 1001})).to.emit(readonlyConn, 'Bid');

      await ownerConn.setAuctionActive(false);
      // Expected tokens is 1001 whcih exceeds max mintbale supply = 1000.
      await ownerConn.setPrice(1);
      await ownerConn.setClaimable(true);

      await expect(readonlyConn.claimTokensAndRefund()).to.be.revertedWith('NoSupplyLeft');
    });

    it('Reverts if refund transfer fails', async () => {
      // TODO: set up a custom contract that refuses transfer.
    });
  });

  describe('Owner send tokens and refund', function () {
    it('sendTokensAndRefund', async () => {
      await ownerConn.setAuctionActive(true);

      await ethers.provider.send('hardhat_setBalance', [
        readonly.address,
        ONE_ETH,
      ]);

      let balance = (await ownerConn.provider.getBalance(ownerConn.address)).toNumber();
      expect(balance).to.eq(0);

      await expect(readonlyConn.bid({value: 100})).to.emit(readonlyConn, 'Bid');

      balance = (await ownerConn.provider.getBalance(ownerConn.address)).toNumber();
      expect(balance).to.eq(100);

      await ownerConn.setAuctionActive(false);
      await ownerConn.setPrice(20);
      await ownerConn.setClaimable(true);

      await expect(ownerConn.sendTokensAndRefund(readonly.address)).to.emit(readonlyConn, 'Transfer');
      const userData = await readonlyConn.getUserData(readonly.address);
      expect(userData.contribution).to.eq(100);
      expect(userData.tokensClaimed).to.eq(5);
      expect(userData.refundClaimed).to.eq(true);
      balance = (await ownerConn.provider.getBalance(ownerConn.address)).toNumber();
      expect(balance).to.eq(100);

      // user cannot claim again
      await expect(readonlyConn.claimTokensAndRefund()).to.be.revertedWith('UserAlreadyClaimed');

      // owner cannot send tokens and refund again
      await expect(ownerConn.sendTokensAndRefund(readonly.address)).to.be.revertedWith('UserAlreadyClaimed');

    });

    // Two bidders.
    it('sendTokensAndRefundBatch', async () => {
      await ownerConn.setAuctionActive(true);

      const readonly2 = await ethers.getImpersonatedSigner('0xef59F379B48f2E92aBD94ADcBf714D170967925D');
      const readonly2Address = await readonly2.getAddress();
      const readonlyConn2 = ba.connect(readonly2);

      // Fund reader and reader2 for testing
      await ethers.provider.send('hardhat_setBalance', [
        readonly.address,
        ONE_ETH,
      ]);
      await ethers.provider.send('hardhat_setBalance', [
        readonly2Address,
        ONE_ETH,
      ]);

      let balance = (await ownerConn.provider.getBalance(ownerConn.address)).toNumber();
      expect(balance).to.eq(0);

      await expect(readonlyConn.bid({value: 100})).to.emit(readonlyConn, 'Bid');
      await expect(readonlyConn2.bid({value: 200})).to.emit(readonlyConn2, 'Bid');

      balance = (await ownerConn.provider.getBalance(ownerConn.address)).toNumber();
      expect(balance).to.eq(300);

      await ownerConn.setAuctionActive(false);
      await ownerConn.setPrice(110);
      await ownerConn.setClaimable(true);

      await ownerConn.sendTokensAndRefundBatch([readonly.address, readonly2.address]);

      const userData1 = await readonlyConn.getUserData(readonly.address);
      expect(userData1.contribution).to.eq(100);
      expect(userData1.tokensClaimed).to.eq(0);
      expect(userData1.refundClaimed).to.eq(true);
      
      const userData2 = await readonlyConn.getUserData(readonly2.address);
      expect(userData2.contribution).to.eq(200);
      expect(userData2.tokensClaimed).to.eq(1);
      expect(userData2.refundClaimed).to.eq(true);

      balance = (await ownerConn.provider.getBalance(ownerConn.address)).toNumber();
      expect(balance).to.eq(110);

    })

    it('sendTokens & sendRefund', async () => {
      await ownerConn.setAuctionActive(true);

      await ethers.provider.send('hardhat_setBalance', [
        readonly.address,
        ONE_ETH,
      ]);

      await expect(readonlyConn.bid({value: 100})).to.emit(readonlyConn, 'Bid');

      await ownerConn.setAuctionActive(false);
      await ownerConn.setPrice(20);
      await ownerConn.setClaimable(true);

      // Send tokens
      await expect(ownerConn.sendTokens(readonly.address, 2)).to.emit(readonlyConn, 'Transfer');
      await expect(ownerConn.sendTokens(readonly.address, 3)).to.emit(readonlyConn, 'Transfer');
      await expect(ownerConn.sendTokens(readonly.address, 1)).to.be.revertedWith('CannotSendMoreThanUserPurchased');
      
      let userData = await readonlyConn.getUserData(readonly.address);
      expect(userData.contribution).to.eq(100);
      expect(userData.tokensClaimed).to.eq(5);
      expect(userData.refundClaimed).to.eq(false);

      // Issue refund
      await ownerConn.sendRefund(readonly.address);
      userData = await readonlyConn.getUserData(readonly.address);
      expect(userData.contribution).to.eq(100);
      expect(userData.tokensClaimed).to.eq(5);
      expect(userData.refundClaimed).to.eq(true);
    });

    it('sendTokensBatch & sendRefundBatch', async () => {
      await ownerConn.setAuctionActive(true);

      const readonly2 = await ethers.getImpersonatedSigner('0xef59F379B48f2E92aBD94ADcBf714D170967925D');
      const readonly2Address = await readonly2.getAddress();
      const readonlyConn2 = ba.connect(readonly2);

      // Fund reader and reader2 for testing
      await ethers.provider.send('hardhat_setBalance', [
        readonly.address,
        ONE_ETH,
      ]);
      await ethers.provider.send('hardhat_setBalance', [
        readonly2Address,
        ONE_ETH,
      ]);

      const balance = (await ownerConn.provider.getBalance(ownerConn.address)).toNumber();
      expect(balance).to.eq(0);

      await expect(readonlyConn.bid({value: 100})).to.emit(readonlyConn, 'Bid');
      await expect(readonlyConn2.bid({value: 200})).to.emit(readonlyConn2, 'Bid');

      await ownerConn.setAuctionActive(false);
      await ownerConn.setPrice(30);
      await ownerConn.setClaimable(true);

      // Issue refund
      await ownerConn.sendRefundBatch([readonly.address, readonly2.address]);
      
      let userData1 = await readonlyConn.getUserData(readonly.address);
      expect(userData1.contribution).to.eq(100);
      expect(userData1.tokensClaimed).to.eq(0);
      expect(userData1.refundClaimed).to.eq(true);

      let userData2 = await readonlyConn2.getUserData(readonly2.address);
      expect(userData2.contribution).to.eq(200);
      expect(userData2.tokensClaimed).to.eq(0);
      expect(userData2.refundClaimed).to.eq(true);

      // Send tokens
      await ownerConn.sendTokensBatch([readonly.address, readonly2.address]);
      
      userData1 = await readonlyConn.getUserData(readonly.address);
      expect(userData1.contribution).to.eq(100);
      expect(userData1.tokensClaimed).to.eq(3);
      expect(userData1.refundClaimed).to.eq(true);

      userData2 = await readonlyConn2.getUserData(readonly2.address);
      expect(userData2.contribution).to.eq(200);
      expect(userData2.tokensClaimed).to.eq(6);
      expect(userData2.refundClaimed).to.eq(true);
    });

    it('sendAllTokens', async () => {
      await ownerConn.setAuctionActive(true);

      await ethers.provider.send('hardhat_setBalance', [
        readonly.address,
        ONE_ETH,
      ]);

      await expect(readonlyConn.bid({value: 100})).to.emit(readonlyConn, 'Bid');

      await ownerConn.setAuctionActive(false);
      await ownerConn.setPrice(20);
      await ownerConn.setClaimable(true);

      await expect(ownerConn.sendAllTokens(readonly.address)).to.emit(readonlyConn, 'Transfer');

      const userData = await readonlyConn.getUserData(readonly.address);
      expect(userData.contribution).to.eq(100);
      expect(userData.tokensClaimed).to.eq(5);
      expect(userData.refundClaimed).to.eq(false);
    });

    it('Reverts if not owner', async () => {
      await expect(readonlyConn.sendTokens(readonly.address, 1)).to.be.revertedWith('Ownable');
      await expect(readonlyConn.sendRefund(readonly.address)).to.be.revertedWith('Ownable');
      await expect(readonlyConn.sendAllTokens(readonly.address)).to.be.revertedWith('Ownable');
      await expect(readonlyConn.sendTokensBatch([readonly.address])).to.be.revertedWith('Ownable');
      await expect(readonlyConn.sendRefundBatch([readonly.address])).to.be.revertedWith('Ownable');
      await expect(readonlyConn.sendTokensAndRefund(readonly.address)).to.be.revertedWith('Ownable');
      await expect(readonlyConn.sendTokensAndRefundBatch([readonly.address])).to.be.revertedWith('Ownable');
    });

    it('Reverts if price not set', async () => {
      await expect(ownerConn.amountPurchased(readonly.address)).to.be.revertedWith('PriceNotSet');
      await expect(ownerConn.refundAmount(readonly.address)).to.be.revertedWith('PriceNotSet');
      await expect(ownerConn.sendTokens(readonly.address, 1)).to.be.revertedWith('PriceNotSet');
      await expect(ownerConn.sendRefund(readonly.address)).to.be.revertedWith('PriceNotSet');
      await expect(ownerConn.sendAllTokens(readonly.address)).to.be.revertedWith('PriceNotSet');
      await expect(ownerConn.sendTokensBatch([readonly.address])).to.be.revertedWith('PriceNotSet');
      await expect(ownerConn.sendRefundBatch([readonly.address])).to.be.revertedWith('PriceNotSet');
      await expect(ownerConn.sendTokensAndRefund(readonly.address)).to.be.revertedWith('PriceNotSet');
      await expect(ownerConn.sendTokensAndRefundBatch([readonly.address])).to.be.revertedWith('PriceNotSet');
    });
  });
});