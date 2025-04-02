import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import chai, { assert, expect } from 'chai';
import chaiAsPromised from 'chai-as-promised';
import { ethers } from 'hardhat';
import { MerkleTree } from 'merkletreejs';
import { ERC721CM } from '../../typechain-types';
import { BigNumber } from 'ethers';

const { getAddress } = ethers.utils;
const MINT_FEE_RECEIVER = '0x0B98151bEdeE73f9Ba5F2C7b72dEa02D38Ce49Fc';
const MINT_FEE = ethers.utils.parseEther('0.00002');

chai.use(chaiAsPromised);

describe('ERC721CM', function () {
  let contract: ERC721CM;
  let readonlyContract: ERC721CM;
  let owner: SignerWithAddress;
  let fundReceiver: SignerWithAddress;
  let readonly: SignerWithAddress;
  let chainId: number;

  const getCosignSignature = async (
    contractInstance: ERC721CM,
    cosigner: SignerWithAddress,
    minter: string,
    timestamp: number,
    qty: number,
    waiveMintFee: boolean,
  ) => {
    const nonce = await contractInstance.getCosignNonce(minter);
    const digestFromJs = ethers.utils.solidityKeccak256(
      [
        'address',
        'address',
        'uint32',
        'bool',
        'address',
        'uint256',
        'uint256',
        'uint256',
      ],
      [
        contractInstance.address,
        minter,
        qty,
        waiveMintFee,
        cosigner.address,
        timestamp,
        chainId,
        nonce,
      ],
    );
    return await cosigner.signMessage(ethers.utils.arrayify(digestFromJs));
  };

  beforeEach(async () => {
    [owner, readonly, fundReceiver] = await ethers.getSigners();

    const ERC721CM = await ethers.getContractFactory('contracts/nft/erc721m/ERC721CM.sol:ERC721CM');
    const erc721cm = await ERC721CM.deploy(
      'Test',
      'TEST',
      '',
      1000,
      0,
      ethers.constants.AddressZero,
      60,
      ethers.constants.AddressZero,
      fundReceiver.address,
      MINT_FEE,
    );
    await erc721cm.deployed();

    contract = erc721cm.connect(owner);
    readonlyContract = erc721cm.connect(readonly);
    chainId = await ethers.provider.getNetwork().then((n) => n.chainId);
  });


  describe('Stages', function () {
  

    it('mint with waived mint fee', async () => {
      const [_owner, minter, cosigner] = await ethers.getSigners();
      const block = await ethers.provider.getBlock(
        await ethers.provider.getBlockNumber(),
      );
      const stageStart = block.timestamp;

      await contract.setStages([
        {
          price: 0,
          walletLimit: 0,
          merkleRoot: ethers.utils.hexZeroPad('0x', 32),
          maxStageSupply: 100,
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageStart + 1000,
        },
      ]);
      await contract.setMintable(true);
      await contract.setCosigner(cosigner.address);

      const timestamp = stageStart + 100;
      let sig = getCosignSignature(
        contract,
        cosigner,
        minter.address,
        timestamp,
        1,
        false,
      );
      await expect(
        readonlyContract.mint(
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          timestamp,
          sig,
          {
            value: ethers.utils.parseEther('0'),
          },
        ),
      ).to.be.revertedWith('NotEnoughValue');

      sig = getCosignSignature(
        contract,
        cosigner,
        minter.address,
        timestamp,
        1,
        true,
      );
      await readonlyContract.mint(
        1,
        0,
        [ethers.utils.hexZeroPad('0x', 32)],
        timestamp,
        sig,
        {
          value: ethers.utils.parseEther('0'),
        },
      );
      const [stageInfo, walletMintedCount, stagedMintedCount] =
        await readonlyContract.getStageInfo(0);
      expect(stageInfo.maxStageSupply).to.equal(100);
      expect(walletMintedCount).to.equal(1);
      expect(stagedMintedCount.toNumber()).to.equal(1);
    });

    it('mint with cosign - happy path', async () => {
      const [_owner, minter, cosigner] = await ethers.getSigners();
      const block = await ethers.provider.getBlock(
        await ethers.provider.getBlockNumber(),
      );
      const stageStart = block.timestamp;

      await contract.setStages([
        {
          price: 0,
          walletLimit: 0,
          merkleRoot: ethers.utils.hexZeroPad('0x', 32),
          maxStageSupply: 100,
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageStart + 1000,
        },
      ]);
      await contract.setMintable(true);
      await contract.setCosigner(cosigner.address);

      const timestamp = stageStart + 100;
      const sig = getCosignSignature(
        contract,
        cosigner,
        minter.address,
        timestamp,
        1,
        false,
      );
      await readonlyContract.mint(
        1,
        0,
        [ethers.utils.hexZeroPad('0x', 32)],
        timestamp,
        sig,
        {
          value: ethers.utils.parseEther('0').add(MINT_FEE),
        },
      );
      const [stageInfo, walletMintedCount, stagedMintedCount] =
        await readonlyContract.getStageInfo(0);
      expect(stageInfo.maxStageSupply).to.equal(100);
      expect(walletMintedCount).to.equal(1);
      expect(stagedMintedCount.toNumber()).to.equal(1);
    });

    it('mint with cosign - invalid sigs', async () => {
      const [_owner, minter, cosigner] = await ethers.getSigners();
      await contract.setStages([
        {
          price: 0,
          walletLimit: 0,
          merkleRoot: ethers.utils.hexZeroPad('0x1', 32),
          maxStageSupply: 100,
          startTimeUnixSeconds: 0,
          endTimeUnixSeconds: 1,
        },
      ]);
      await contract.setMintable(true);
      await contract.setCosigner(cosigner.address);

      const timestamp = Math.floor(new Date().getTime() / 1000);
      const sig = await getCosignSignature(
        contract,
        cosigner,
        minter.address,
        timestamp,
        1,
        false,
      );

      // invalid because of unexpected timestamp
      await expect(
        readonlyContract.mint(
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          timestamp + 1,
          sig,
          {
            value: ethers.utils.parseEther('0').add(MINT_FEE),
          },
        ),
      ).to.be.revertedWith('InvalidCosignSignature');

      // invalid because of unexptected sig
      await expect(
        readonlyContract.mint(
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          timestamp,
          sig + '00',
          {
            value: ethers.utils.parseEther('0').add(MINT_FEE),
          },
        ),
      ).to.be.revertedWith('InvalidCosignSignature');
      await expect(
        readonlyContract.mint(
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          timestamp,
          '0x00',
          {
            value: ethers.utils.parseEther('0').add(MINT_FEE),
          },
        ),
      ).to.be.revertedWith('InvalidCosignSignature');
      await expect(
        readonlyContract.mint(
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          timestamp,
          '0',
          {
            value: ethers.utils.parseEther('0').add(MINT_FEE),
          },
        ),
      ).to.be.rejectedWith('invalid arrayify');
      await expect(
        readonlyContract.mint(
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          timestamp,
          '',
          {
            value: ethers.utils.parseEther('0').add(MINT_FEE),
          },
        ),
      ).to.be.rejectedWith('invalid arrayify');

      // invalid because of unawait expected minter
      await expect(
        contract.mint(
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          timestamp,
          sig,
          {
            value: ethers.utils.parseEther('0').add(MINT_FEE),
          },
        ),
      ).to.be.revertedWith('InvalidCosignSignature');
    });

    it('mint with cosign - timestamp out of stage', async () => {
      const [_owner, minter, cosigner] = await ethers.getSigners();
      const block = await ethers.provider.getBlock(
        await ethers.provider.getBlockNumber(),
      );
      const stageStart = block.timestamp;
      await contract.setStages([
        {
          price: 0,
          mintFee: 0,
          walletLimit: 0,
          merkleRoot: ethers.utils.hexZeroPad('0x1', 32),
          maxStageSupply: 100,
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageStart + 1000,
        },
      ]);
      await contract.setMintable(true);
      await contract.setCosigner(cosigner.address);

      const earlyTimestamp = stageStart - 1;
      let sig = getCosignSignature(
        readonlyContract,
        cosigner,
        minter.address,
        earlyTimestamp,
        1,
        false,
      );

      await expect(
        readonlyContract.mint(
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          earlyTimestamp,
          sig,
          {
            value: ethers.utils.parseEther('0').add(MINT_FEE),
          },
        ),
      ).to.be.revertedWith('InvalidStage');

      const lateTimestamp = stageStart + 1001;
      sig = getCosignSignature(
        readonlyContract,
        cosigner,
        minter.address,
        lateTimestamp,
        1,
        false,
      );

      await expect(
        readonlyContract.mint(
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          lateTimestamp,
          sig,
          {
            value: ethers.utils.parseEther('0').add(MINT_FEE),
          },
        ),
      ).to.be.revertedWith('InvalidStage');
    });

    it('mint with cosign - expired signature', async () => {
      const [_owner, minter, cosigner] = await ethers.getSigners();
      const block = await ethers.provider.getBlock(
        await ethers.provider.getBlockNumber(),
      );
      const stageStart = block.timestamp;
      await contract.setStages([
        {
          price: 0,
          walletLimit: 0,
          merkleRoot: ethers.utils.hexZeroPad('0x1', 32),
          maxStageSupply: 100,
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageStart + 1000,
        },
      ]);
      await contract.setMintable(true);
      await contract.setCosigner(cosigner.address);

      const timestamp = stageStart;
      const sig = getCosignSignature(
        readonlyContract,
        cosigner,
        minter.address,
        timestamp,
        1,
        false,
      );

      // fast forward 2 minutes
      await ethers.provider.send('evm_increaseTime', [120]);
      await ethers.provider.send('evm_mine', []);

      await expect(
        readonlyContract.mint(
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          timestamp,
          sig,
          {
            value: ethers.utils.parseEther('0').add(MINT_FEE),
          },
        ),
      ).to.be.revertedWith('TimestampExpired');
    });


    it('enforces Merkle proof if required', async () => {
      const accounts = (await ethers.getSigners()).map((signer) =>
        getAddress(signer.address).toLowerCase().trim(),
      );
      const leaves = accounts.map((account) =>
        ethers.utils.solidityKeccak256(['address', 'uint32'], [account, 0]),
      );
      const signerAddress = await ethers.provider.getSigner().getAddress();
      const merkleTree = new MerkleTree(leaves, ethers.utils.keccak256, {
        sortPairs: true,
        hashLeaves: false,
      });
      const root = merkleTree.getHexRoot();

      const leaf = ethers.utils.solidityKeccak256(
        ['address', 'uint32'],
        [signerAddress.toLowerCase().trim(), 0],
      );
      const proof = merkleTree.getHexProof(leaf);

      const block = await ethers.provider.getBlock(
        await ethers.provider.getBlockNumber(),
      );
      // +10 is a number bigger than the count of transactions up to mint
      const stageStart = block.timestamp + 10;
      // Set stages
      await contract.setStages([
        {
          price: ethers.utils.parseEther('0.5'),
          mintFee: 0,
          walletLimit: 10,
          merkleRoot: root,
          maxStageSupply: 5,
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageStart + 3,
        },
      ]);
      await contract.setMintable(true);

      // Setup the test context: Update block.timestamp to comply to the stage being active
      await ethers.provider.send('evm_mine', [stageStart - 1]);
      // Mint 1 token with valid proof
      await contract.mint(1, 0, proof, 0, '0x00', {
        value: ethers.utils.parseEther('0.5').add(MINT_FEE),
      });
      const totalMinted = await contract.totalMintedByAddress(signerAddress);
      expect(totalMinted.toNumber()).to.equal(1);

      // Mint 1 token with someone's else proof should be reverted
      await expect(
        readonlyContract.mint(1, 0, proof, 0, '0x00', {
          value: ethers.utils.parseEther('0.5').add(MINT_FEE),
        }),
      ).to.be.rejectedWith('InvalidProof');
    });

    it('reverts on invalid Merkle proof', async () => {
      const root = ethers.utils.hexZeroPad('0x1', 32);
      const proof = [ethers.utils.hexZeroPad('0x1', 32)];
      const block = await ethers.provider.getBlock(
        await ethers.provider.getBlockNumber(),
      );
      // +10 is a number bigger than the count of transactions up to mint
      const stageStart = block.timestamp + 10;
      // Set stages
      await contract.setStages([
        {
          price: ethers.utils.parseEther('0.5'),
          walletLimit: 10,
          merkleRoot: root,
          maxStageSupply: 5,
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageStart + 1,
        },
      ]);
      await contract.setMintable(true);

      // Setup the test context: Update block.timestamp to comply to the stage being active
      await ethers.provider.send('evm_mine', [stageStart - 1]);
      // Mint 1 token with invalid proof
      const mint = contract.mint(1, 0, proof, 0, '0x00', {
        value: ethers.utils.parseEther('0.5').add(MINT_FEE),
      });
      await expect(mint).to.be.revertedWith('InvalidProof');
    });



    it('mints by owner', async () => {
      await contract.setStages([
        {
          price: ethers.utils.parseEther('0.5'),
          walletLimit: 1,
          merkleRoot: ethers.utils.hexZeroPad('0x1', 32),
          maxStageSupply: 1,
          startTimeUnixSeconds: 0,
          endTimeUnixSeconds: 1,
        },
      ]);
      await contract.setMintable(true);

      const [owner, address1] = await ethers.getSigners();

      await contract.ownerMint(5, owner.address);

      const [, walletMintedCount, stagedMintedCount] =
        await contract.getStageInfo(0);
      expect(walletMintedCount).to.equal(0);
      expect(stagedMintedCount.toNumber()).to.equal(0);
      const ownerBalance = await contract.balanceOf(owner.address);
      expect(ownerBalance.toNumber()).to.equal(5);

      await contract.ownerMint(5, address1.address);
      const [, address1Minted] = await readonlyContract.getStageInfo(0, {
        from: address1.address,
      });
      expect(address1Minted).to.equal(0);

      const address1Balance = await contract.balanceOf(address1.address);
      expect(address1Balance.toNumber()).to.equal(5);

      expect((await contract.totalSupply()).toNumber()).to.equal(10);
    });

    it('mints by owner - invalid cases', async () => {
      await contract.setStages([
        {
          price: ethers.utils.parseEther('0.5'),
          walletLimit: 1,
          merkleRoot: ethers.utils.hexZeroPad('0x1', 32),
          maxStageSupply: 1,
          startTimeUnixSeconds: 0,
          endTimeUnixSeconds: 1,
        },
      ]);
      await contract.setMintable(true);
      await expect(
        contract.ownerMint(1001, readonly.address),
      ).to.be.revertedWith('NoSupplyLeft');
    });
  });

  describe('Authorized minter minting', function () {
    let stageStart = 0;
    let stageEnd = 0;

    beforeEach(async () => {
      // Get an estimated stage start time
      const block = await ethers.provider.getBlock(
        await ethers.provider.getBlockNumber(),
      );
      stageStart = block.timestamp;
      // +100 is a number bigger than the count of transactions needed for this test
      stageEnd = stageStart + 100;

      await contract.setStages([
        {
          price: ethers.utils.parseEther('0.5'),
          walletLimit: 1,
          merkleRoot: ethers.utils.hexZeroPad('0x0', 32),
          maxStageSupply: 1,
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      await contract.setMintable(true);
    });

    it('revert if not authorized minter', async () => {
      const mint = contract.authorizedMint(
        1,
        '0xef59F379B48f2E92aBD94ADcBf714D170967925D',
        0,
        [ethers.utils.hexZeroPad('0x', 32)],
        0,
        '0x00',
        {
          value: ethers.utils.parseEther('0.5').add(MINT_FEE),
        },
      );
      await expect(mint).to.be.revertedWith('NotAuthorized');
    });

    it('authorized mint', async () => {
      const recipient = '0xef59F379B48f2E92aBD94ADcBf714D170967925D';
      const reservoirSigner = await ethers.getImpersonatedSigner(
        '0xf70da97812CB96acDF810712Aa562db8dfA3dbEF',
      );
      const reservoirAddress = await reservoirSigner.getAddress();

      // Send some wei to impersonated account
      await ethers.provider.send('hardhat_setBalance', [
        reservoirAddress,
        '0xFFFFFFFFFFFFFFFF',
      ]);

      const reservoirConn = contract.connect(reservoirSigner);

      await expect(
        reservoirConn.authorizedMint(
          1,
          '0xef59F379B48f2E92aBD94ADcBf714D170967925D',
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          0,
          '0x00',
          {
            value: ethers.utils.parseEther('1').add(MINT_FEE),
          },
        ),
      ).to.be.revertedWith('NotAuthorized');

      await contract.addAuthorizedMinter(reservoirAddress);

      await reservoirConn.authorizedMint(
        1,
        '0xef59F379B48f2E92aBD94ADcBf714D170967925D',
        0,
        [ethers.utils.hexZeroPad('0x', 32)],
        0,
        '0x00',
        {
          value: ethers.utils.parseEther('1').add(MINT_FEE),
        },
      );

      const totalMinted = await contract.totalMintedByAddress(recipient);
      expect(totalMinted).to.eql(BigNumber.from(1));

      await contract.removeAuthorizedMinter(reservoirAddress);
      await expect(
        reservoirConn.authorizedMint(
          1,
          '0xef59F379B48f2E92aBD94ADcBf714D170967925D',
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          0,
          '0x00',
          {
            value: ethers.utils.parseEther('1').add(MINT_FEE),
          },
        ),
      ).to.be.revertedWith('NotAuthorized');
    });
  });


});
