import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import chai, { expect } from 'chai';
import chaiAsPromised from 'chai-as-promised';
import { ethers } from 'hardhat';
import { BucketAuction } from '../typechain-types';

chai.use(chaiAsPromised);

const ONE_ETH = '0xDE0B6B3A7640000';

describe('BucketAuction', function () {
  let ownerConn: BucketAuction;
  let readonlyConn: BucketAuction;
  let owner: SignerWithAddress;
  let readonly: SignerWithAddress;

  beforeEach(async () => {
    const BA = await ethers.getContractFactory('BucketAuction');
    const ba = await BA.deploy('Test', 'TEST', '', 1000, 0, ethers.constants.AddressZero, 100);
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

  it('Can make bids', async () => {
    // it starts as Inactive, so we cannot make bids
    await expect(readonlyConn.bid()).to.be.revertedWith('BucketAuctionNotActive');

    // we then turn on the AuctionActive, so that we can start the bids
    await ownerConn.setAuctionActive(true);

    // we cannot bid under the minimum
    await expect(readonlyConn.bid({value: 10})).to.be.revertedWith('LowerThanMinBidAmount');

    // we can make bids
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

    // we cannot make bids when colleciton is mintable in the ERC721M stages
    await ownerConn.setMintable(true);
    await expect(readonlyConn.bid({value: 100})).to.be.revertedWith('Mintable');
    await ownerConn.setMintable(false); // clean up
  })

  it('Can set minimum contribution', async () => {
    await expect(ownerConn.setMinimumContribution(200)).to.emit(ownerConn, 'SetMinimumContribution');
    await expect(readonlyConn.setMinimumContribution(200)).to.be.revertedWith('Ownable');
  });

  it('Can set price', async () => {
    // If the auction is active, then we cannot setPrice
    await ownerConn.setAuctionActive(true);
    await expect(ownerConn.setPrice(200)).to.be.revertedWith('BucketAuctionActive');
    await ownerConn.setAuctionActive(false); // clean up

    await expect(ownerConn.setPrice(200)).to.emit(ownerConn, 'SetPrice');
    await expect(readonlyConn.setPrice(200)).to.be.revertedWith('Ownable');
  });

  it('Can claimTokensAndRefund - happy path', async () => {
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
});