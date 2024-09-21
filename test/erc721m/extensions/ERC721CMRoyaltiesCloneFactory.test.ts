import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import chai, { expect } from 'chai';
import chaiAsPromised from 'chai-as-promised';
import { ethers } from 'hardhat';
import { ERC721CMRoyaltiesCloneFactory } from '../../../typechain-types';
import { isAddress } from 'ethers/lib/utils';

chai.use(chaiAsPromised);

describe('ERC721CMRoyaltiesCloneFactory', function () {
  let cloneFactory: ERC721CMRoyaltiesCloneFactory;
  let owner: SignerWithAddress;

  beforeEach(async () => {
    const contractFactory =
        await ethers.getContractFactory('ERC721CMRoyaltiesCloneFactory');
    cloneFactory = await contractFactory.deploy();
    await cloneFactory.deployed();

    [owner] = await ethers.getSigners();
    cloneFactory.connect(owner);
  });

  it('creates clone', async () => {
    await expect(createClone(cloneFactory)).to.emit(cloneFactory, 'CreateClone');
  });

  it('creates multiple clones', async () => {
    const clones = new Set<string>();
    for (let i = 0; i < 10; i++) {
        const tx = await createClone(cloneFactory);
    
        const receipt = await tx.wait();
        const event = receipt.events!.find(event => event.event === 'CreateClone')!;
        const cloneAddress = event.args![0];
        expect(isAddress(cloneAddress)).to.be.true;
        clones.add(cloneAddress);
    }
    expect(clones.size).to.be.equal(10);
  });

  it('can mint on clone', async () => {
    const tx = await createClone(cloneFactory);

    const receipt = await tx.wait();
    const event = receipt.events!.find(event => event.event === 'CreateClone')!;
    const cloneAddress = event.args![0];

    const contractFactory =
        await ethers.getContractFactory('ERC721CMRoyaltiesInitializable');
    const erc721Clone = contractFactory.attach(cloneAddress);

    expect(await erc721Clone.totalSupply()).to.equal(0);
    await erc721Clone.ownerMint(3, owner.address);
    expect(await erc721Clone.totalSupply()).to.equal(3);
  });

  it('can mint on multiple clones', async () => {
    const clones = [];
    for (let i = 0; i < 10; i++) {
        const tx = await createClone(cloneFactory);
    
        const receipt = await tx.wait();
        const event = receipt.events!.find(event => event.event === 'CreateClone')!;
        const cloneAddress = event.args![0];
        expect(isAddress(cloneAddress)).to.be.true;
        clones.push(cloneAddress);
    }

    for (let i = 0; i < clones.length; i++) {
        const contractFactory =
            await ethers.getContractFactory('ERC721CMRoyaltiesInitializable');
        const erc721Clone = contractFactory.attach(clones[i]);

        expect(await erc721Clone.totalSupply()).to.equal(0);
        await erc721Clone.ownerMint(i + 1, owner.address);
        expect(await erc721Clone.totalSupply()).to.equal(i + 1);
    }
  });
});

function createClone(factory: ERC721CMRoyaltiesCloneFactory) {
    return factory.create(
    'TestCollection',
    'TestSymbol',
    '.json',
    1000,
    0,
    '0x0000000000000000000000000000000000000000',
    '0x0000000000000000000000000000000000000000',
    '0xef59F379B48f2E92aBD94ADcBf714D170967925D',
    '0xef59F379B48f2E92aBD94ADcBf714D170967925D',
    100,
    );
}
