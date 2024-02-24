import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import chai, { expect } from 'chai';
import chaiAsPromised from 'chai-as-promised';
import { ethers } from 'hardhat';
import { ERC721CMRoyalties } from '../typechain-types';

chai.use(chaiAsPromised);

const WALLET_1 = '0x0764844ac95ABCa4F6306E592c7D9C9f3615f590';
const WALLET_2 = '0xef59F379B48f2E92aBD94ADcBf714D170967925D';

describe('ERC721CMRoyalties', function () {
  let contract: ERC721CMRoyalties;
  let owner: SignerWithAddress;

  beforeEach(async () => {
    const ERC721CMRoyalties = await ethers.getContractFactory('ERC721CMRoyalties');
    const erc721cmRoyalties = await ERC721CMRoyalties.deploy(
      'Test',
      'TEST',
      '',
      1000,
      0,
      ethers.constants.AddressZero,
      60,
      ethers.constants.AddressZero,
      WALLET_1, // erc2198royaltyreceiver
      10, // erc2198royaltyfeenumerator
    );
    await erc721cmRoyalties.deployed();

    [owner] = await ethers.getSigners();
    contract = erc721cmRoyalties.connect(owner);
  });

  it('Set default royalty', async () => {
    let royaltyInfo = await contract.royaltyInfo(0, 1000);
    expect(royaltyInfo[0]).to.equal(WALLET_1);
    expect(royaltyInfo[1].toNumber()).to.equal(1);

    royaltyInfo = await contract.royaltyInfo(1, 9999);
    expect(royaltyInfo[0]).to.equal(WALLET_1);
    expect(royaltyInfo[1].toNumber()).to.equal(9);

    royaltyInfo = await contract.royaltyInfo(1111, 9999999999);
    expect(royaltyInfo[0]).to.equal(WALLET_1);
    expect(royaltyInfo[1].toNumber()).to.equal(9999999);

    await contract.setDefaultRoyalty(WALLET_2, 0)

    royaltyInfo = await contract.royaltyInfo(0, 1000);
    expect(royaltyInfo[0]).to.equal(WALLET_2);
    expect(royaltyInfo[1].toNumber()).to.equal(0);

    royaltyInfo = await contract.royaltyInfo(1, 9999);
    expect(royaltyInfo[0]).to.equal(WALLET_2);
    expect(royaltyInfo[1].toNumber()).to.equal(0);

    royaltyInfo = await contract.royaltyInfo(1111, 9999999999);
    expect(royaltyInfo[0]).to.equal(WALLET_2);
    expect(royaltyInfo[1].toNumber()).to.equal(0);
  });

  it('Set token royalty', async () => {
    let royaltyInfo = await contract.royaltyInfo(0, 1000);
    expect(royaltyInfo[0]).to.equal(WALLET_1);
    expect(royaltyInfo[1].toNumber()).to.equal(1);

    royaltyInfo = await contract.royaltyInfo(1, 9999);
    expect(royaltyInfo[0]).to.equal(WALLET_1);
    expect(royaltyInfo[1].toNumber()).to.equal(9);

    royaltyInfo = await contract.royaltyInfo(1111, 9999999999);
    expect(royaltyInfo[0]).to.equal(WALLET_1);
    expect(royaltyInfo[1].toNumber()).to.equal(9999999);

    await contract.setTokenRoyalty(1, WALLET_2, 100)

    royaltyInfo = await contract.royaltyInfo(0, 1000);
    expect(royaltyInfo[0]).to.equal(WALLET_1);
    expect(royaltyInfo[1].toNumber()).to.equal(1);

    royaltyInfo = await contract.royaltyInfo(1, 9999);
    expect(royaltyInfo[0]).to.equal(WALLET_2);
    expect(royaltyInfo[1].toNumber()).to.equal(99);

    royaltyInfo = await contract.royaltyInfo(1111, 9999999999);
    expect(royaltyInfo[0]).to.equal(WALLET_1);
    expect(royaltyInfo[1].toNumber()).to.equal(9999999);
  });
});
