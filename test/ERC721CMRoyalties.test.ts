import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import chai, { expect } from 'chai';
import chaiAsPromised from 'chai-as-promised';
import { ethers } from 'hardhat';
import { ERC721CMRoyalties } from '../typechain-types';

chai.use(chaiAsPromised);

const WALLET_1 = '0x0764844ac95ABCa4F6306E592c7D9C9f3615f590';
const WALLET_2 = '0xef59F379B48f2E92aBD94ADcBf714D170967925D';

describe('ERC721CMRoyalties', function () {
  let erc721cmRoyalties: ERC721CMRoyalties;
  let connection: ERC721CMRoyalties;
  let owner: SignerWithAddress;

  beforeEach(async () => {
    const ERC721CMRoyalties =
      await ethers.getContractFactory('ERC721CMRoyalties');
    erc721cmRoyalties = await ERC721CMRoyalties.deploy(
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
    connection = erc721cmRoyalties.connect(owner);
  });

  it('Set default royalty', async () => {
    let royaltyInfo = await connection.royaltyInfo(0, 1000);
    expect(royaltyInfo[0]).to.equal(WALLET_1);
    expect(royaltyInfo[1].toNumber()).to.equal(1);

    royaltyInfo = await connection.royaltyInfo(1, 9999);
    expect(royaltyInfo[0]).to.equal(WALLET_1);
    expect(royaltyInfo[1].toNumber()).to.equal(9);

    royaltyInfo = await connection.royaltyInfo(1111, 9999999999);
    expect(royaltyInfo[0]).to.equal(WALLET_1);
    expect(royaltyInfo[1].toNumber()).to.equal(9999999);

    await connection.setDefaultRoyalty(WALLET_2, 0);

    royaltyInfo = await connection.royaltyInfo(0, 1000);
    expect(royaltyInfo[0]).to.equal(WALLET_2);
    expect(royaltyInfo[1].toNumber()).to.equal(0);

    royaltyInfo = await connection.royaltyInfo(1, 9999);
    expect(royaltyInfo[0]).to.equal(WALLET_2);
    expect(royaltyInfo[1].toNumber()).to.equal(0);

    royaltyInfo = await connection.royaltyInfo(1111, 9999999999);
    expect(royaltyInfo[0]).to.equal(WALLET_2);
    expect(royaltyInfo[1].toNumber()).to.equal(0);
  });

  it('Set token royalty', async () => {
    let royaltyInfo = await connection.royaltyInfo(0, 1000);
    expect(royaltyInfo[0]).to.equal(WALLET_1);
    expect(royaltyInfo[1].toNumber()).to.equal(1);

    royaltyInfo = await connection.royaltyInfo(1, 9999);
    expect(royaltyInfo[0]).to.equal(WALLET_1);
    expect(royaltyInfo[1].toNumber()).to.equal(9);

    royaltyInfo = await connection.royaltyInfo(1111, 9999999999);
    expect(royaltyInfo[0]).to.equal(WALLET_1);
    expect(royaltyInfo[1].toNumber()).to.equal(9999999);

    await connection.setTokenRoyalty(1, WALLET_2, 100);

    royaltyInfo = await connection.royaltyInfo(0, 1000);
    expect(royaltyInfo[0]).to.equal(WALLET_1);
    expect(royaltyInfo[1].toNumber()).to.equal(1);

    royaltyInfo = await connection.royaltyInfo(1, 9999);
    expect(royaltyInfo[0]).to.equal(WALLET_2);
    expect(royaltyInfo[1].toNumber()).to.equal(99);

    royaltyInfo = await connection.royaltyInfo(1111, 9999999999);
    expect(royaltyInfo[0]).to.equal(WALLET_1);
    expect(royaltyInfo[1].toNumber()).to.equal(9999999);
  });

  it('Non-owner update reverts', async () => {
    const [_, nonOwner] = await ethers.getSigners();
    const nonOwnerConnection = erc721cmRoyalties.connect(nonOwner);

    await expect(
      nonOwnerConnection.setTokenRoyalty(1, WALLET_2, 100),
    ).to.be.revertedWith('OwnableUnauthorizedAccount');

    await expect(
      nonOwnerConnection.setDefaultRoyalty(WALLET_2, 0),
    ).to.be.revertedWith('OwnableUnauthorizedAccount');
  });

  it('Supports the right interfaces', async () => {
    expect(await erc721cmRoyalties.supportsInterface('0x01ffc9a7')).to.be.true; // IERC165
    expect(await erc721cmRoyalties.supportsInterface('0x80ac58cd')).to.be.true; // IERC721
    expect(await erc721cmRoyalties.supportsInterface('0x5b5e139f')).to.be.true; // IERC721Metadata
    expect(await erc721cmRoyalties.supportsInterface('0x2a55205a')).to.be.true; // IERC2981
  });
});
