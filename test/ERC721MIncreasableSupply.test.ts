import { expect } from 'chai';
import { ethers } from 'hardhat';
import { ERC721MIncreasableSupply } from '../typechain-types';

describe('ERC721MIncreasableSupply', () => {
  let contract: ERC721MIncreasableSupply;

  beforeEach(async () => {
    const factory = await ethers.getContractFactory('ERC721MIncreasableSupply');
    contract = await factory.deploy(
      'test',
      'TEST',
      '.json',
      1000,
      0,
      ethers.constants.AddressZero,
      300,
      ethers.constants.AddressZero,
      ethers.constants.AddressZero,
    );
    const [owner] = await ethers.getSigners();
    contract = contract.connect(owner);
    await contract.deployed();
  });

  it('can increase max mintable supply until disableIncreaseMaxMintableSupply called', async () => {
    const currentSupply = await contract.getMaxMintableSupply();
    expect(await contract.getCanIncreaseMaxMintableSupply()).to.eq(true);
    await expect(contract.setMaxMintableSupply(currentSupply.add(1000)))
      .to.emit(contract, 'SetMaxMintableSupply')
      .withArgs(currentSupply.toNumber() + 1000);

    await expect(contract.disableIncreaseMaxMintableSupply()).to.emit(
      contract,
      'DisableIncreaseMaxMintableSupply',
    );
    expect(await contract.getCanIncreaseMaxMintableSupply()).to.eq(false);
    await expect(
      contract.setMaxMintableSupply(currentSupply.add(2000)),
    ).to.be.revertedWith('CannotIncreaseMaxMintableSupply');
  });
});
