import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import chai, { assert, expect } from 'chai';
import chaiAsPromised from 'chai-as-promised';
import { ethers } from 'hardhat';
import {
  ERC721MCallback,
  TestStaking,
  TestStaking__factory,
} from '../typechain-types';

chai.use(chaiAsPromised);

describe('ERC721MCallback', () => {
  let contract: ERC721MCallback;
  let readonlyContract: ERC721MCallback;
  let stakingContract: TestStaking;
  let readonlyStakingContract: TestStaking;
  let owner: SignerWithAddress;
  let readonly: SignerWithAddress;

  beforeEach(async () => {
    const factory = await ethers.getContractFactory('ERC721MCallback');
    const erc721mCallback = await factory.deploy(
      'Test',
      'TST',
      '.json',
      100,
      0,
      ethers.constants.AddressZero,
    );
    await erc721mCallback.deployed();

    const [ownerSigner, readonlySigner] = await ethers.getSigners();
    owner = ownerSigner;
    readonly = readonlySigner;
    contract = erc721mCallback.connect(ownerSigner);
    readonlyContract = erc721mCallback.connect(readonlySigner);

    const stakingFactory = await ethers.getContractFactory('TestStaking');
    stakingContract = await stakingFactory.deploy(erc721mCallback.address);
    await stakingContract.deployed();

    readonlyStakingContract = stakingContract.connect(readonlySigner);
  });

  describe('Setting callbacks', () => {
    it('Can set callbacks', async () => {
      await contract.setCallbackInfos([
        {
          callbackContract: stakingContract.address,
          callbackFunction: '0x00000000',
        },
      ]);

      let callbackInfos = await readonlyContract.getCallbackInfos();
      expect(callbackInfos.length).to.equal(1);
      expect(callbackInfos[0].callbackContract).to.equal(
        stakingContract.address,
      );
      expect(callbackInfos[0].callbackFunction).to.equal('0x00000000');

      await contract.setCallbackInfos([
        {
          callbackContract: stakingContract.address,
          callbackFunction: '0x00000000',
        },
        {
          callbackContract: owner.address,
          callbackFunction: '0x00000001',
        },
      ]);

      callbackInfos = await readonlyContract.getCallbackInfos();
      expect(callbackInfos.length).to.equal(2);
      expect(callbackInfos[0].callbackContract).to.equal(
        stakingContract.address,
      );
      expect(callbackInfos[0].callbackFunction).to.equal('0x00000000');
      expect(callbackInfos[1].callbackContract).to.equal(owner.address);
      expect(callbackInfos[1].callbackFunction).to.equal('0x00000001');
    });
  });

  describe('Minting', () => {
    it('Callbacks should be triggered', async () => {
      await contract.setStages([
        {
          price: ethers.utils.parseEther('0.1'),
          walletLimit: 0,
          maxStageSupply: 0,
          merkleRoot: ethers.utils.hexZeroPad('0x', 32),
          startTimeUnixSeconds: 0,
          endTimeUnixSeconds: 1,
        },
      ]);
      await contract.setMintable(true);
      const stakeFunctionSelector = new ethers.utils.Interface(
        TestStaking__factory.abi,
      )
        .encodeFunctionData('stakeFor', [ethers.constants.AddressZero, 0])
        .slice(0, 10);
      await contract.setCallbackInfos([
        {
          callbackContract: stakingContract.address,
          callbackFunction: stakeFunctionSelector,
        },
      ]);
      await contract.setOnMintApprovals([stakingContract.address]);

      expect(await contract.getOnMintApprovals()).to.deep.equal([
        stakingContract.address,
      ]);

      await readonlyContract.mintWithCallbacks(
        1,
        [],
        0,
        '0x',
        [
          '0x' +
            new ethers.utils.Interface(TestStaking__factory.abi)
              .encodeFunctionData('stakeFor', [readonly.address, 0])
              .slice(10),
        ],
        {
          value: ethers.utils.parseEther('0.1'),
        },
      );

      expect(await contract.totalSupply()).to.equal(1);
      expect(await contract.balanceOf(readonly.address)).to.equal(0);
      expect(await contract.balanceOf(stakingContract.address)).to.equal(1);
      expect(await stakingContract.isStaked(readonly.address, 0)).to.equal(
        true,
      );

      // Unstake
      await readonlyStakingContract.unstake(0);

      expect(await contract.balanceOf(readonly.address)).to.equal(1);
      expect(await contract.balanceOf(stakingContract.address)).to.equal(0);
      expect(await stakingContract.isStaked(readonly.address, 0)).to.equal(
        false,
      );
    });

    it('Reverts when not enough callbacks passed', async () => {
      await contract.setStages([
        {
          price: ethers.utils.parseEther('0.1'),
          walletLimit: 0,
          maxStageSupply: 0,
          merkleRoot: ethers.utils.hexZeroPad('0x', 32),
          startTimeUnixSeconds: 0,
          endTimeUnixSeconds: 1,
        },
      ]);
      await contract.setMintable(true);
      const stakeFunctionSelector = new ethers.utils.Interface(
        TestStaking__factory.abi,
      )
        .encodeFunctionData('stakeFor', [ethers.constants.AddressZero, 0])
        .slice(0, 10);
      await contract.setCallbackInfos([
        {
          callbackContract: stakingContract.address,
          callbackFunction: stakeFunctionSelector,
        },
      ]);
      await contract.setOnMintApprovals([stakingContract.address]);

      await expect(
        readonlyContract.mintWithCallbacks(1, [], 0, '0x', [], {
          value: ethers.utils.parseEther('0.1'),
        }),
      ).to.be.revertedWith('InvalidCallbackDatasLength');
    });

    it('Reverts when callback fails', async () => {
      await contract.setStages([
        {
          price: ethers.utils.parseEther('0.1'),
          walletLimit: 0,
          maxStageSupply: 0,
          merkleRoot: ethers.utils.hexZeroPad('0x', 32),
          startTimeUnixSeconds: 0,
          endTimeUnixSeconds: 1,
        },
      ]);
      await contract.setMintable(true);
      const stakeFunctionSelector = new ethers.utils.Interface(
        TestStaking__factory.abi,
      )
        .encodeFunctionData('stakeFor', [ethers.constants.AddressZero, 0])
        .slice(0, 10);
      await contract.setCallbackInfos([
        {
          callbackContract: stakingContract.address,
          callbackFunction: stakeFunctionSelector,
        },
      ]);
      await contract.setOnMintApprovals([stakingContract.address]);

      await expect(
        readonlyContract.mintWithCallbacks(1, [], 0, '0x', ['0x1234'], {
          value: ethers.utils.parseEther('0.1'),
        }),
      ).to.be.revertedWith('CallbackFailed');
    });

    it('can mint normally', async () => {
      await contract.setStages([
        {
          price: ethers.utils.parseEther('0.1'),
          walletLimit: 0,
          maxStageSupply: 0,
          merkleRoot: ethers.utils.hexZeroPad('0x', 32),
          startTimeUnixSeconds: 0,
          endTimeUnixSeconds: 1,
        },
      ]);
      await contract.setMintable(true);

      await readonlyContract.mint(1, [], 0, '0x', {
        value: ethers.utils.parseEther('0.1'),
      });

      expect(await readonlyContract.balanceOf(readonly.address)).to.equal(1);
      expect(await readonlyContract.totalSupply()).to.equal(1);
      expect(
        await readonlyContract.balanceOf(stakingContract.address),
      ).to.equal(0);
    });
  });
});
