import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import chai, { expect } from 'chai';
import chaiAsPromised from 'chai-as-promised';
import { ethers } from 'hardhat';
import { ERC721BatchTransfer, MockERC721A } from '../typechain-types';

chai.use(chaiAsPromised);

const addresses = {
  addr1: '0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2',
  addr2: '0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db',
  addr3: '0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB',
  addr4: '0x617F2E2fD72FD9D5503197092aC168c91465E7f2',
  addr5: '0x17F6AD8Ef982297579C203069C1DbfFE4348c372',
};

describe('ERC721BatchTransfer', function () {
  let transferContract: ERC721BatchTransfer;
  let nftContract: MockERC721A;
  let owner: SignerWithAddress;

  beforeEach(async () => {
    [owner] = await ethers.getSigners();

    const batchTransfer = await (
      await ethers.getContractFactory('ERC721BatchTransfer')
    ).deploy();
    await batchTransfer.deployed();
    transferContract = batchTransfer.connect(owner);

    const erc721a = await (
      await ethers.getContractFactory('MockERC721A')
    ).deploy();
    await erc721a.deployed();
    nftContract = erc721a.connect(owner);

    await nftContract.setApprovalForAll(transferContract.address, true);

    await nftContract.mintBatch(owner.address, 1000);

    for (let i = 0; i < 5; i++) {
      const tokenOwner = await nftContract.ownerOf(i);
      expect(tokenOwner).to.equal(owner.address);
    }
  });

  it('batchTransferToSingleWallet', async () => {
    await transferContract.batchTransferToSingleWallet(
      nftContract.address,
      addresses.addr1,
      [0, 1, 2, 3, 4],
    );
    for (let i = 0; i < 5; i++) {
      const tokenOwner = await nftContract.ownerOf(i);
      expect(tokenOwner).to.equal(addresses.addr1);
    }
  });

  it.only('batchTransferToSingleWallet max Batch', async () => {
    // old cap was 777
    const batchAmount = 834;
    const tx = await transferContract.batchTransferToSingleWallet(
      nftContract.address,
      addresses.addr1,
      Array.from({ length: batchAmount }, (_, i) => i),
    );
    const receipt = await tx.wait();

    console.log(receipt.gasUsed);

    for (let i = 0; i < batchAmount; i++) {
      const tokenOwner = await nftContract.ownerOf(i);
      expect(tokenOwner).to.equal(addresses.addr1);
    }
  });

  it('safeBatchTransferToSingleWallet', async () => {
    const tokenIds = [0, 1, 2, 3, 4];
    await transferContract.safeBatchTransferToSingleWallet(
      nftContract.address,
      addresses.addr1,
      [0, 1, 2, 3, 4],
    );
    for (let i = 0; i < tokenIds.length; i++) {
      const tokenOwner = await nftContract.ownerOf(tokenIds[i]);
      expect(tokenOwner).to.equal(addresses.addr1);
    }
  });

  it('batchTransferToMultipleWallets', async () => {
    const tokenIds = [0, 1, 2, 3, 4];
    const tos = [
      addresses.addr1,
      addresses.addr2,
      addresses.addr3,
      addresses.addr4,
      addresses.addr5,
    ];
    await transferContract.batchTransferToMultipleWallets(
      nftContract.address,
      tos,
      tokenIds,
    );
    for (let i = 0; i < tokenIds.length; i++) {
      const tokenOwner = await nftContract.ownerOf(tokenIds[i]);
      expect(tokenOwner).to.equal(tos[i]);
    }
  });

  it('safeBatchTransferToMultipleWallets', async () => {
    const tokenIds = [4, 1, 2, 0, 3];
    const tos = [
      addresses.addr1,
      addresses.addr2,
      addresses.addr2,
      addresses.addr2,
      addresses.addr4,
    ];
    await transferContract.safeBatchTransferToMultipleWallets(
      nftContract.address,
      tos,
      tokenIds,
    );
    for (let i = 0; i < tokenIds.length; i++) {
      const tokenOwner = await nftContract.ownerOf(tokenIds[i]);
      expect(tokenOwner).to.equal(tos[i]);
    }
  });

  it('revert if tokens not owned', async () => {
    const tokenIds = [0, 1, 2, 3, 4];
    const tos = [
      addresses.addr1,
      addresses.addr2,
      addresses.addr3,
      addresses.addr4,
      addresses.addr5,
    ];
    await transferContract.batchTransferToMultipleWallets(
      nftContract.address,
      tos,
      tokenIds,
    );

    await expect(
      transferContract.batchTransferToMultipleWallets(
        nftContract.address,
        tos,
        tokenIds,
      ),
    ).to.be.revertedWith('TransferFromIncorrectOwner()');
  });

  it('revert if invalid arguments', async () => {
    const tokenIds = [0, 1, 2, 3];
    const tos = [
      addresses.addr1,
      addresses.addr2,
      addresses.addr3,
      addresses.addr4,
      addresses.addr5,
    ];

    await expect(
      transferContract.batchTransferToMultipleWallets(
        nftContract.address,
        tos,
        tokenIds,
      ),
    ).to.be.revertedWith('InvalidArguments');
  });
});
