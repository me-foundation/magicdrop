import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import chai, { expect } from 'chai';
import chaiAsPromised from 'chai-as-promised';
import { ethers } from 'hardhat';
import { MagicDropTokenImplRegistry } from '../../typechain-types';

chai.use(chaiAsPromised);

const addresses = {
  addr1: '0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2',
  addr2: '0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db',
  addr3: '0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB',
  addr4: '0x617F2E2fD72FD9D5503197092aC168c91465E7f2',
  addr5: '0x17F6AD8Ef982297579C203069C1DbfFE4348c372',
};

describe('MagicDropTokenImplementationRegistry', function () {
  let owner: SignerWithAddress;
  let registry: MagicDropTokenImplRegistry;

  beforeEach(async () => {
    [owner] = await ethers.getSigners();

    const registryFactory = await ethers.getContractFactory(
      'MagicDropTokenImplRegistry',
    );

    registry = await registryFactory.deploy();
  });

  it.only('stub', async () => {
    const [_owner, minter, cosigner] = await ethers.getSigners();
    console.log(await registry.owner());
  });
});
