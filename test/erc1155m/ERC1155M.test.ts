import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import chai, { assert, expect } from 'chai';
import chaiAsPromised from 'chai-as-promised';
import { ethers } from 'hardhat';
import { MerkleTree } from 'merkletreejs';
import { ERC1155M } from '../../typechain-types';
import { BigNumber, Contract } from 'ethers';

const { getAddress, parseEther } = ethers.utils;
const MINT_FEE_RECEIVER = '0x0B98151bEdeE73f9Ba5F2C7b72dEa02D38Ce49Fc';
const ZERO_PROOF = ethers.utils.hexZeroPad('0x00', 32);
const PAYMENT_ADDRESS = '0x0000000000000000000000000000000000000000';
const WALLET_1 = '0x0764844ac95ABCa4F6306E592c7D9C9f3615f590';
const WALLET_2 = '0xef59F379B48f2E92aBD94ADcBf714D170967925D';

chai.use(chaiAsPromised);

describe('ERC1155M', function () {
  let contract: ERC1155M;
  let readonlyContract: ERC1155M;
  let owner: SignerWithAddress;
  let fundReceiver: SignerWithAddress;
  let readonly: SignerWithAddress;

  this.beforeAll(async () => {
    [owner, readonly, fundReceiver] = await ethers.getSigners();
  })

  const getCosignSignature = async (
    contractInstance: ERC1155M,
    cosigner: SignerWithAddress,
    minter: string,
    timestamp: number,
    tokenId: number,
    qty: number,
    waiveMintFee: boolean,
  ) => {
    const nonce = await contractInstance.getCosignNonce(minter, tokenId);
    const chainId = await ethers.provider.getNetwork().then((n) => n.chainId);

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

    const factory = await ethers.getContractFactory('ERC1155M');
    const erc1155M = await factory.deploy(
      'test-collection',
      'TEST',
      'https://example/{id}.json',
      [100],
      [0],
      ethers.constants.AddressZero,
      60,
      PAYMENT_ADDRESS,
      fundReceiver.address,
      WALLET_1,
      10,
    );
    await erc1155M.deployed();

    contract = erc1155M.connect(owner);
    readonlyContract = erc1155M.connect(readonly);

  });

  it('withdraws balance by owner', async () => {
    // Send 100 wei to contract address for testing.
    await ethers.provider.send('hardhat_setBalance', [
      contract.address,
      '0x64', // 100 wei
    ]);
    expect(
      (await contract.provider.getBalance(contract.address)).toNumber(),
    ).to.equal(100);

    await expect(() => contract.withdraw()).to.changeEtherBalances(
      [contract, owner, fundReceiver],
      [-100, 0, 100],
    );

    expect(
      (await contract.provider.getBalance(contract.address)).toNumber(),
    ).to.equal(0);

    // readonlyContract should not be able to withdraw
    await expect(readonlyContract.withdraw()).to.be.revertedWith(
      'Unauthorized',
    );
  });

  describe('Configure stages', function () {
    it('cannot set stages with readonly address', async () => {
      await expect(
        readonlyContract.setStages([
          {
            price: [parseEther('0.5')],
            mintFee: [parseEther('0.01')],
            walletLimit: [3],
            merkleRoot: [ethers.utils.hexZeroPad('0x1', 32)],
            maxStageSupply: [5],
            startTimeUnixSeconds: 0,
            endTimeUnixSeconds: 1,
          },
        ]),
      ).to.be.revertedWith('Unauthorized');
    });

    it('cannot set stages with insufficient gap', async () => {
      await expect(
        contract.setStages([
          {
            price: [parseEther('0.5')],
            mintFee: [parseEther('0.01')],
            walletLimit: [3],
            merkleRoot: [ethers.utils.hexZeroPad('0x1', 32)],
            maxStageSupply: [5],
            startTimeUnixSeconds: 0,
            endTimeUnixSeconds: 1,
          },
          {
            price: [parseEther('0.6')],
            mintFee: [parseEther('0.01')],
            walletLimit: [4],
            merkleRoot: [ethers.utils.hexZeroPad('0x2', 32)],
            maxStageSupply: [10],
            startTimeUnixSeconds: 61,
            endTimeUnixSeconds: 62,
          },
        ]),
      ).to.be.revertedWith('InsufficientStageTimeGap');
    });

    it('cannot set stages due to startTimeUnixSeconds is not smaller than endTimeUnixSeconds', async () => {
      await expect(
        contract.setStages([
          {
            price: [parseEther('0.5')],
            mintFee: [parseEther('0')],
            walletLimit: [3],
            merkleRoot: [ethers.utils.hexZeroPad('0x1', 32)],
            maxStageSupply: [5],
            startTimeUnixSeconds: 0,
            endTimeUnixSeconds: 0,
          },
        ]),
      ).to.be.revertedWith('InvalidStartAndEndTimestamp');

      await expect(
        contract.setStages([
          {
            price: [parseEther('0.5')],
            mintFee: [parseEther('0')],
            walletLimit: [3],
            merkleRoot: [ethers.utils.hexZeroPad('0x1', 32)],
            maxStageSupply: [5],
            startTimeUnixSeconds: 1,
            endTimeUnixSeconds: 0,
          },
          {
            price: [parseEther('0.6')],
            mintFee: [parseEther('0')],
            walletLimit: [4],
            merkleRoot: [ethers.utils.hexZeroPad('0x2', 32)],
            maxStageSupply: [10],
            startTimeUnixSeconds: 62,
            endTimeUnixSeconds: 61,
          },
        ]),
      ).to.be.revertedWith('InvalidStartAndEndTimestamp');
    });

    it('cannot set stages with invalid arg size', async () => {
      await expect(
        contract.setStages([
          {
            price: [parseEther('0.5')],
            mintFee: [parseEther('0')],
            walletLimit: [3, 99],
            merkleRoot: [ethers.utils.hexZeroPad('0x1', 32)],
            maxStageSupply: [5],
            startTimeUnixSeconds: 0,
            endTimeUnixSeconds: 1,
          },
        ]),
      ).to.be.revertedWith('InvalidStageArgsLength');

      await expect(
        contract.setStages([
          {
            price: [parseEther('0.5')],
            mintFee: [parseEther('0')],
            walletLimit: [3],
            merkleRoot: [ethers.utils.hexZeroPad('0x1', 32)],
            maxStageSupply: [5, 0],
            startTimeUnixSeconds: 0,
            endTimeUnixSeconds: 1,
          },
        ]),
      ).to.be.revertedWith('InvalidStageArgsLength');

      await expect(
        contract.setStages([
          {
            price: [parseEther('0.5')],
            mintFee: [parseEther('0')],
            walletLimit: [3],
            merkleRoot: [ethers.utils.hexZeroPad('0x1', 32)],
            maxStageSupply: [5],
            startTimeUnixSeconds: 0,
            endTimeUnixSeconds: 1,
          },
          {
            price: [parseEther('0.6'), parseEther('0')],
            mintFee: [parseEther('0')],
            walletLimit: [4],
            merkleRoot: [ethers.utils.hexZeroPad('0x2', 32)],
            maxStageSupply: [10],
            startTimeUnixSeconds: 360,
            endTimeUnixSeconds: 361,
          },
        ]),
      ).to.be.revertedWith('InvalidStageArgsLength');
    });

    it('set / reset stages', async () => {
      await contract.setStages([
        {
          price: [parseEther('0.5')],
          mintFee: [parseEther('0.01')],
          walletLimit: [3],
          merkleRoot: [ethers.utils.hexZeroPad('0x1', 32)],
          maxStageSupply: [5],
          startTimeUnixSeconds: 0,
          endTimeUnixSeconds: 1,
        },
        {
          price: [parseEther('0.6')],
          mintFee: [parseEther('0.01')],
          walletLimit: [4],
          merkleRoot: [ethers.utils.hexZeroPad('0x2', 32)],
          maxStageSupply: [10],
          startTimeUnixSeconds: 361,
          endTimeUnixSeconds: 362,
        },
      ]);

      expect(await contract.getNumberStages()).to.equal(2);

      let [stageInfo, walletMintedCount, stageMintedCount] =
        await contract.getStageInfo(0);
      expect(stageInfo.price).to.eql([parseEther('0.5')]);
      expect(stageInfo.walletLimit).to.eql([3]);
      expect(stageInfo.maxStageSupply).to.eql([5]);
      expect(stageInfo.merkleRoot).to.eql([ethers.utils.hexZeroPad('0x1', 32)]);
      expect(walletMintedCount).to.eql([BigNumber.from(0)]);
      expect(stageMintedCount).to.eql([BigNumber.from(0)]);

      [stageInfo, walletMintedCount, stageMintedCount] =
        await contract.getStageInfo(1);
      expect(stageInfo.price).to.eql([parseEther('0.6')]);
      expect(stageInfo.walletLimit).to.eql([4]);
      expect(stageInfo.maxStageSupply).to.eql([10]);
      expect(stageInfo.merkleRoot).to.eql([ethers.utils.hexZeroPad('0x2', 32)]);
      expect(walletMintedCount).to.eql([BigNumber.from(0)]);
      expect(stageMintedCount).to.eql([BigNumber.from(0)]);

      // Update to one stage
      await contract.setStages([
        {
          price: [parseEther('0.6')],
          mintFee: [parseEther('0.06')],
          walletLimit: [4],
          merkleRoot: [ethers.utils.hexZeroPad('0x3', 32)],
          maxStageSupply: [0],
          startTimeUnixSeconds: 0,
          endTimeUnixSeconds: 1,
        },
      ]);

      expect(await contract.getNumberStages()).to.equal(1);
      [stageInfo, walletMintedCount, stageMintedCount] =
        await contract.getStageInfo(0);
      expect(stageInfo.price).to.eql([parseEther('0.6')]);
      expect(stageInfo.walletLimit).to.eql([4]);
      expect(stageInfo.maxStageSupply).to.eql([0]);
      expect(stageInfo.merkleRoot).to.eql([ethers.utils.hexZeroPad('0x3', 32)]);
      expect(walletMintedCount).to.eql([BigNumber.from(0)]);
      expect(stageMintedCount).to.eql([BigNumber.from(0)]);

      // Add another stage
      await contract.setStages([
        {
          price: [parseEther('0.6')],
          mintFee: [parseEther('0.06')],
          walletLimit: [4],
          merkleRoot: [ethers.utils.hexZeroPad('0x3', 32)],
          maxStageSupply: [0],
          startTimeUnixSeconds: 0,
          endTimeUnixSeconds: 1,
        },
        {
          price: [parseEther('0.7')],
          mintFee: [parseEther('0.07')],
          walletLimit: [5],
          merkleRoot: [ethers.utils.hexZeroPad('0x4', 32)],
          maxStageSupply: [5],
          startTimeUnixSeconds: 361,
          endTimeUnixSeconds: 362,
        },
      ]);

      expect(await contract.getNumberStages()).to.equal(2);
      [stageInfo, walletMintedCount, stageMintedCount] =
        await contract.getStageInfo(1);
      expect(stageInfo.price).to.eql([parseEther('0.7')]);
      expect(stageInfo.walletLimit).to.eql([5]);
      expect(stageInfo.maxStageSupply).to.eql([5]);
      expect(stageInfo.merkleRoot).to.eql([ethers.utils.hexZeroPad('0x4', 32)]);
      expect(walletMintedCount).to.eql([BigNumber.from(0)]);
      expect(stageMintedCount).to.eql([BigNumber.from(0)]);
    });

    it('get stage info', async () => {
      await contract.setStages([
        {
          price: [parseEther('0.5')],
          mintFee: [parseEther('0.05')],
          walletLimit: [3],
          merkleRoot: [ethers.utils.hexZeroPad('0x1', 32)],
          maxStageSupply: [5],
          startTimeUnixSeconds: 0,
          endTimeUnixSeconds: 1,
        },
      ]);

      expect(await contract.getNumberStages()).to.equal(1);

      const [stageInfo, walletMintedCount, stageMintedCount] =
        await contract.getStageInfo(0);
      expect(stageInfo.price).to.eql([parseEther('0.5')]);
      expect(stageInfo.walletLimit).to.eql([3]);
      expect(stageInfo.maxStageSupply).to.eql([5]);
      expect(stageInfo.merkleRoot).to.eql([ethers.utils.hexZeroPad('0x1', 32)]);
      expect(walletMintedCount).to.eql([BigNumber.from(0)]);
      expect(stageMintedCount).to.eql([BigNumber.from(0)]);
    });

    it('get stage info reverts for non-existent stage', async () => {
      await contract.setStages([
        {
          price: [parseEther('0.5')],
          mintFee: [parseEther('0.05')],
          walletLimit: [3],
          merkleRoot: [ethers.utils.hexZeroPad('0x1', 32)],
          maxStageSupply: [5],
          startTimeUnixSeconds: 0,
          endTimeUnixSeconds: 1,
        },
      ]);

      const getStageInfo = readonlyContract.getStageInfo(1);
      await expect(getStageInfo).to.be.revertedWith('InvalidStage');
    });

    it('can find active stage', async () => {
      await contract.setStages([
        {
          price: [parseEther('0.5')],
          mintFee: [parseEther('0.01')],
          walletLimit: [3],
          merkleRoot: [ethers.utils.hexZeroPad('0x1', 32)],
          maxStageSupply: [5],
          startTimeUnixSeconds: 20,
          endTimeUnixSeconds: 21,
        },
        {
          price: [parseEther('0.6')],
          mintFee: [parseEther('0.01')],
          walletLimit: [4],
          merkleRoot: [ethers.utils.hexZeroPad('0x2', 32)],
          maxStageSupply: [10],
          startTimeUnixSeconds: 361,
          endTimeUnixSeconds: 362,
        },
      ]);

      expect(await contract.getNumberStages()).to.equal(2);
      expect(await contract.getActiveStageFromTimestamp(20)).to.equal(0);
      expect(await contract.getActiveStageFromTimestamp(361)).to.equal(1);

      await expect(contract.getActiveStageFromTimestamp(1)).to.be.revertedWith(
        'InvalidStage',
      );
      await expect(contract.getActiveStageFromTimestamp(70)).to.be.revertedWith(
        'InvalidStage',
      );
      await expect(
        contract.getActiveStageFromTimestamp(363),
      ).to.be.revertedWith('InvalidStage');
    });
  });

  describe('Single token minting', function () {
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
          price: [parseEther('0.4')],
          mintFee: [parseEther('0.1')],
          walletLimit: [10],
          merkleRoot: [ZERO_PROOF],
          maxStageSupply: [5],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);
    });

    it('revert if contract without stages', async () => {
      // Reset stages to empty
      await contract.setStages([]);

      const mint = contract.mint(0, 1, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0.5'),
      });

      await expect(mint).to.be.revertedWith('InvalidStage');
    });

    it('revert if incorrect (less) amount sent', async () => {
      let mint;
      mint = contract.mint(0, 5, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('2.499'),
      });
      await expect(mint).to.be.revertedWith('NotEnoughValue');

      mint = contract.mint(0, 1, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0.499999'),
      });
      await expect(mint).to.be.revertedWith('NotEnoughValue');
    });

    it('revert on reentrancy', async () => {
      const reentrancyFactory = await ethers.getContractFactory(
        'ERC1155MTestReentrantExploit',
      );
      const reentrancyExploiter = await reentrancyFactory.deploy(
        contract.address,
      );
      await reentrancyExploiter.deployed();

      await expect(
        reentrancyExploiter.exploit(0, 1, [], {
          value: parseEther('0.5'),
        }),
      ).to.be.revertedWith('Reentrancy');
    });

    it('set max mintable supply', async () => {
      await contract.setMaxMintableSupply(0, 99);
      expect(await contract.getMaxMintableSupply(0)).to.equal(99);

      // can set the mintable supply again with the same value
      await contract.setMaxMintableSupply(0, 99);
      expect(await contract.getMaxMintableSupply(0)).to.equal(99);

      // can set the mintable supply again with the lower value
      await contract.setMaxMintableSupply(0, 98);
      expect(await contract.getMaxMintableSupply(0)).to.equal(98);

      // can not set the mintable supply with higher value
      await expect(contract.setMaxMintableSupply(0, 100)).to.be.rejectedWith(
        'CannotIncreaseMaxMintableSupply',
      );

      // can not set the mintable supply for a non-existent token
      await expect(contract.setMaxMintableSupply(1, 100)).to.be.rejectedWith(
        'InvalidTokenId',
      );

      // readonlyContract should not be able to set max mintable supply
      await expect(
        readonlyContract.setMaxMintableSupply(0, 99),
      ).to.be.revertedWith('Unauthorized');

      // can not set the mintable supply lower than the total supply
      await contract.ownerMint(owner.address, 0, 10);
      await expect(contract.setMaxMintableSupply(0, 9)).to.be.rejectedWith(
        'NewSupplyLessThanTotalSupply',
      );
    });

    it('enforces max mintable supply', async () => {
      await contract.setStages([
        {
          price: [parseEther('0.01')],
          mintFee: [parseEther('0')],
          walletLimit: [0],
          merkleRoot: [ZERO_PROOF],
          maxStageSupply: [0],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      // Mint 101 tokens (1 over MaxMintableSupply)
      const mint = contract.mint(0, 101, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('1'),
      });
      await expect(mint).to.be.revertedWith('NoSupplyLeft');
    });

    it('mint with wallet limit', async () => {
      await contract.setStages([
        {
          price: [parseEther('0.01')],
          mintFee: [parseEther('0')],
          walletLimit: [10],
          merkleRoot: [ZERO_PROOF],
          maxStageSupply: [0],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      // Mint 10 tokens - wallet limit
      await contract.mint(0, 10, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0.1'),
      });

      // Mint one more should fail
      await expect(
        contract.mint(0, 1, 0, [ZERO_PROOF], 0, '0x00', {
          value: parseEther('0.01'),
        }),
      ).to.be.revertedWith('WalletStageLimitExceeded');
    });

    it('mint with limited stage supply', async () => {
      await contract.setStages([
        {
          price: [parseEther('0.01')],
          mintFee: [parseEther('0')],
          walletLimit: [0],
          merkleRoot: [ZERO_PROOF],
          maxStageSupply: [10],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      // Mint 10 tokens - stage limit
      await contract.mint(0, 10, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0.1'),
      });

      // Mint one more should fail
      const mint = contract.mint(0, 1, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0.01'),
      });

      await expect(mint).to.be.revertedWith('StageSupplyExceeded');
    });

    it('mint with free stage', async () => {
      await contract.setStages([
        {
          price: [0],
          mintFee: [0],
          walletLimit: [0],
          merkleRoot: [ZERO_PROOF],
          maxStageSupply: [100],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      const contractBalanceInitial = await ethers.provider.getBalance(
        contract.address,
      );
      const mintFeeReceiverBalanceInitial =
        await ethers.provider.getBalance(MINT_FEE_RECEIVER);

      await readonlyContract.mint(0, 1, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0'),
      });
      const [stageInfo, walletMintedCount, stagedMintedCount] =
        await readonlyContract.getStageInfo(0);
      expect(stageInfo.maxStageSupply).to.eql([100]);
      expect(walletMintedCount).to.eql([BigNumber.from(1)]);
      expect(stagedMintedCount).to.eql([BigNumber.from(1)]);

      const contractBalancePost = await ethers.provider.getBalance(
        contract.address,
      );
      expect(contractBalancePost.sub(contractBalanceInitial)).to.equal(0);

      const mintFeeReceiverBalancePost =
        await ethers.provider.getBalance(MINT_FEE_RECEIVER);
      expect(
        mintFeeReceiverBalancePost.sub(mintFeeReceiverBalanceInitial),
      ).to.equal(0);
    });

    it('mint with free stage with mint fee', async () => {
      await contract.setStages([
        {
          price: [0],
          mintFee: [parseEther('0.1')],
          walletLimit: [0],
          merkleRoot: [ZERO_PROOF],
          maxStageSupply: [100],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      const contractBalanceInitial = await ethers.provider.getBalance(
        contract.address,
      );
      const mintFeeReceiverBalanceInitial =
        await ethers.provider.getBalance(MINT_FEE_RECEIVER);

      await readonlyContract.mint(0, 1, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0.1'),
      });

      await contract.withdraw();

      const [stageInfo, walletMintedCount, stagedMintedCount] =
        await readonlyContract.getStageInfo(0);
      expect(stageInfo.maxStageSupply).to.eql([100]);
      expect(walletMintedCount).to.eql([BigNumber.from(1)]);
      expect(stagedMintedCount).to.eql([BigNumber.from(1)]);

      const contractBalancePost = await ethers.provider.getBalance(
        contract.address,
      );
      expect(contractBalancePost.sub(contractBalanceInitial)).to.equal(0);

      const mintFeeReceiverBalancePost =
        await ethers.provider.getBalance(MINT_FEE_RECEIVER);
      expect(
        mintFeeReceiverBalancePost.sub(mintFeeReceiverBalanceInitial),
      ).to.equal(parseEther('0.1'));
    });

    it('mint with mint fee waived', async () => {
      const [_owner, minter, cosigner] = await ethers.getSigners();
      const block = await ethers.provider.getBlock(
        await ethers.provider.getBlockNumber(),
      );
      await contract.setCosigner(cosigner.address);

      const timestamp = stageStart + 1;

      let sig = getCosignSignature(
        contract,
        cosigner,
        minter.address,
        timestamp,
        0,
        1,
        false,
      );

      await expect(
        readonlyContract.mint(
          0,
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          timestamp,
          sig,
          {
            value: ethers.utils.parseEther('0.4'), // price = 0.4, mintFee = 0.1
          },
        ),
      ).to.be.rejectedWith('NotEnoughValue');

      sig = getCosignSignature(
        contract,
        cosigner,
        minter.address,
        timestamp,
        0,
        1,
        true,
      );
      await readonlyContract.mint(
        0,
        1,
        0,
        [ethers.utils.hexZeroPad('0x', 32)],
        timestamp,
        sig,
        {
          value: ethers.utils.parseEther('0.4'), // price = 0.4, mintFee = 0.1
        },
      );
      const [stageInfo, walletMintedCount, stagedMintedCount] =
        await readonlyContract.getStageInfo(0);
      expect(walletMintedCount).to.eql([BigNumber.from(1)]);
      expect(stagedMintedCount).to.eql([BigNumber.from(1)]);
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

      // Set stages
      await contract.setStages([
        {
          price: [parseEther('0.1')],
          mintFee: [0],
          walletLimit: [10],
          merkleRoot: [root],
          maxStageSupply: [5],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      // Mint 1 token with valid proof
      await contract.mint(0, 1, 0, proof, 0, '0x00', {
        value: parseEther('0.1'),
      });
      const totalMinted = await contract.totalMintedByAddress(signerAddress);
      expect(totalMinted).to.eql([BigNumber.from(1)]);

      // Mint 1 token with someone's else proof should be reverted
      await expect(
        readonlyContract.mint(0, 1, 0, proof, 0, '0x00', {
          value: parseEther('0.1'),
        }),
      ).to.be.rejectedWith('InvalidProof');
    });

    it('reverts on invalid Merkle proof', async () => {
      const root = ethers.utils.hexZeroPad('0x1', 32);
      const proof = [ethers.utils.hexZeroPad('0x1', 32)];

      await contract.setStages([
        {
          price: [parseEther('0.5')],
          mintFee: [parseEther('0')],
          walletLimit: [10],
          merkleRoot: [root],
          maxStageSupply: [5],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      // Mint 1 token with invalid proof
      const mint = contract.mint(0, 1, 0, proof, 0, '0x00', {
        value: parseEther('0.5'),
      });
      await expect(mint).to.be.revertedWith('InvalidProof');
    });

    it('mint with limit', async () => {
      const ownerAddress = await owner.getAddress();
      const readerAddress = await readonly.getAddress();
      const leaves = [
        ethers.utils.solidityKeccak256(
          ['address', 'uint32'],
          [ownerAddress, 2],
        ),
        ethers.utils.solidityKeccak256(
          ['address', 'uint32'],
          [readerAddress, 5],
        ),
      ];

      const merkleTree = new MerkleTree(leaves, ethers.utils.keccak256, {
        sortPairs: true,
        hashLeaves: false,
      });
      const root = merkleTree.getHexRoot();
      const ownerLeaf = ethers.utils.solidityKeccak256(
        ['address', 'uint32'],
        [ownerAddress, 2],
      );
      const readerLeaf = ethers.utils.solidityKeccak256(
        ['address', 'uint32'],
        [readerAddress, 5],
      );
      const ownerProof = merkleTree.getHexProof(ownerLeaf);
      const readerProof = merkleTree.getHexProof(readerLeaf);

      // Set stages
      await contract.setStages([
        {
          price: [parseEther('0.1')],
          mintFee: [0],
          walletLimit: [10],
          merkleRoot: [root],
          maxStageSupply: [100],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      // Owner mints 1 token with valid proof
      await contract.mint(0, 1, 2, ownerProof, 0, '0x00', {
        value: parseEther('0.1'),
      });

      expect(await contract.totalMintedByAddress(owner.getAddress())).to.eql([
        BigNumber.from(1),
      ]);

      // Owner mints 1 token with wrong limit and should be reverted.
      await expect(
        contract.mint(0, 1, 3, ownerProof, 0, '0x00', {
          value: parseEther('0.1'),
        }),
      ).to.be.rejectedWith('InvalidProof');

      // Owner mints 2 tokens with valid proof and reverts.
      await expect(
        contract.mint(0, 2, 2, ownerProof, 0, '0x00', {
          value: parseEther('0.2'),
        }),
      ).to.be.rejectedWith('WalletStageLimitExceeded');

      // Owner mints 1 token with valid proof. Now owner reaches the limit.
      await contract.mint(0, 1, 2, ownerProof, 0, '0x00', {
        value: parseEther('0.1'),
      });
      expect(await contract.totalMintedByAddress(owner.getAddress())).to.eql([
        BigNumber.from(2),
      ]);

      // Owner tries to mint more and reverts.
      await expect(
        contract.mint(0, 1, 2, ownerProof, 0, '0x00', {
          value: parseEther('0.1'),
        }),
      ).to.be.rejectedWith('WalletStageLimitExceeded');

      // Reader mints 6 tokens with valid proof and reverts.
      await expect(
        readonlyContract.mint(0, 6, 5, readerProof, 0, '0x00', {
          value: parseEther('0.6'),
        }),
      ).to.be.rejectedWith('WalletStageLimitExceeded');

      // Reader mints 5 tokens with valid proof.
      await readonlyContract.mint(0, 5, 5, readerProof, 0, '0x00', {
        value: parseEther('0.5'),
      });

      // Reader mints 1 token with valid proof and reverts.
      await expect(
        readonlyContract.mint(0, 1, 5, readerProof, 0, '0x00', {
          value: parseEther('0.1'),
        }),
      ).to.be.rejectedWith('WalletStageLimitExceeded');
    });

    it('mint by owner', async () => {
      const [owner, address1] = await ethers.getSigners();
      await contract.ownerMint(owner.address, 0, 5);

      const [, walletMintedCount, stageMintedCount] =
        await contract.getStageInfo(0);

      expect(walletMintedCount).to.eql([BigNumber.from(0)]);
      expect(stageMintedCount).to.eql([BigNumber.from(0)]);

      const ownerBalance = await contract.balanceOf(owner.address, 0);
      expect(ownerBalance.toNumber()).to.equal(5);

      await contract.ownerMint(address1.address, 0, 5);
      const [, address1Minted, address1StageMintedCount] =
        await readonlyContract.getStageInfo(0, {
          from: address1.address,
        });
      expect(address1Minted).to.eql([BigNumber.from(0)]);
      expect(address1StageMintedCount).to.eql([BigNumber.from(0)]);

      const address1Balance = await contract.balanceOf(address1.address, 0);
      expect(address1Balance.toNumber()).to.equal(5);

      expect(await contract['totalSupply()'].apply(0)).to.equal(10);
    });

    it('mints by owner - invalid cases', async () => {
      await expect(
        contract.ownerMint(readonly.address, 0, 101),
      ).to.be.revertedWith('NoSupplyLeft');
    });

    it('mint with cosigner signature', async () => {
      const [_owner, minter, cosigner] = await ethers.getSigners();
      const block = await ethers.provider.getBlock(
        await ethers.provider.getBlockNumber(),
      );
      await contract.setCosigner(cosigner.address);

      const timestamp = stageStart + 1;
      const sig = getCosignSignature(
        contract,
        cosigner,
        minter.address,
        timestamp,
        0,
        1,
        false,
      );
      await readonlyContract.mint(
        0,
        1,
        0,
        [ethers.utils.hexZeroPad('0x', 32)],
        timestamp,
        sig,
        {
          value: ethers.utils.parseEther('0.5'),
        },
      );
      const [stageInfo, walletMintedCount, stagedMintedCount] =
        await readonlyContract.getStageInfo(0);
      expect(walletMintedCount).to.eql([BigNumber.from(1)]);
      expect(stagedMintedCount).to.eql([BigNumber.from(1)]);
    });

    it('mint with cosign - invalid sigs', async () => {
      const [_owner, minter, cosigner] = await ethers.getSigners();
      await contract.setCosigner(cosigner.address);

      const timestamp = stageStart + 1;
      const sig = await getCosignSignature(
        contract,
        cosigner,
        minter.address,
        timestamp,
        0,
        1,
        false,
      );

      // invalid because of unexpected timestamp
      await expect(
        readonlyContract.mint(
          0,
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          timestamp + 1,
          sig,
          {
            value: ethers.utils.parseEther('0.5'),
          },
        ),
      ).to.be.revertedWith('InvalidCosignSignature');

      // invalid because of unexptected sig
      await expect(
        readonlyContract.mint(
          0,
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          timestamp,
          sig + '00',
          {
            value: ethers.utils.parseEther('0.5'),
          },
        ),
      ).to.be.revertedWith('InvalidCosignSignature');

      await expect(
        readonlyContract.mint(
          0,
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          timestamp,
          '0x00',
          {
            value: ethers.utils.parseEther('0.5'),
          },
        ),
      ).to.be.revertedWith('InvalidCosignSignature');

      await expect(
        readonlyContract.mint(
          0,
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          timestamp,
          '0',
          {
            value: ethers.utils.parseEther('0.5'),
          },
        ),
      ).to.be.rejectedWith('invalid arrayify');

      await expect(
        readonlyContract.mint(
          0,
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          timestamp,
          '',
          {
            value: ethers.utils.parseEther('0.5'),
          },
        ),
      ).to.be.rejectedWith('invalid arrayify');
    });
  });

  describe('Multi token minting', function () {
    let stageStart = 0;
    let stageEnd = 0;

    beforeEach(async () => {
      const factory = await ethers.getContractFactory('ERC1155M');
      const erc1155M = await factory.deploy(
        'collection',
        'symbol',
        'https://example/{id}.json',
        [100, 200, 300],
        [0, 0, 10],
        ethers.constants.AddressZero,
        60,
        PAYMENT_ADDRESS,
        fundReceiver.address,
        WALLET_1,
        10,
      );
      await erc1155M.deployed();

      contract = erc1155M.connect(owner);
      readonlyContract = erc1155M.connect(readonly);

      // Get an estimated stage start time
      const block = await ethers.provider.getBlock(
        await ethers.provider.getBlockNumber(),
      );
      stageStart = block.timestamp;
      // +100 is a number bigger than the count of transactions needed for this test
      stageEnd = stageStart + 100;

      await contract.setStages([
        {
          price: [parseEther('0.1'), parseEther('0.2'), parseEther('0.2')],
          mintFee: [parseEther('0.1'), parseEther('0.1'), parseEther('0.1')],
          walletLimit: [10, 5, 3],
          merkleRoot: [ZERO_PROOF, ZERO_PROOF, ZERO_PROOF],
          maxStageSupply: [100, 200, 300],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);
    });

    it('mint with wallet limit', async () => {
      // Mint 10 token A - wallet limit
      await contract.mint(0, 10, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('2'),
      });

      // Mint 5 token B - wallet limit
      await contract.mint(1, 5, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('1.5'),
      });

      // Mint 3 token C - wallet limit
      await contract.mint(2, 3, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0.9'),
      });

      // Mint one more should fail
      await expect(
        contract.mint(0, 1, 0, [ZERO_PROOF], 0, '0x00', {
          value: parseEther('0.2'),
        }),
      ).to.be.revertedWith('WalletStageLimitExceeded');

      await expect(
        contract.mint(1, 1, 0, [ZERO_PROOF], 0, '0x00', {
          value: parseEther('0.3'),
        }),
      ).to.be.revertedWith('WalletStageLimitExceeded');

      await expect(
        contract.mint(2, 1, 0, [ZERO_PROOF], 0, '0x00', {
          value: parseEther('0.3'),
        }),
      ).to.be.revertedWith('WalletStageLimitExceeded');
    });

    it('mint with limited stage supply', async () => {
      await contract.setStages([
        {
          price: [parseEther('0.1'), parseEther('0.2'), parseEther('0.2')],
          mintFee: [parseEther('0.1'), parseEther('0.1'), parseEther('0.1')],
          walletLimit: [0, 0, 0],
          merkleRoot: [ZERO_PROOF, ZERO_PROOF, ZERO_PROOF],
          maxStageSupply: [30, 20, 10],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      // Mint 30 token A - stage limit
      await contract.mint(0, 30, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('6'),
      });

      // Mint 20 token B - stage limit
      await contract.mint(1, 20, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('6'),
      });

      // Mint 10 token C - stage limit
      await contract.mint(2, 10, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('3'),
      });

      // Mint one more should fail
      await expect(
        contract.mint(0, 1, 0, [ZERO_PROOF], 0, '0x00', {
          value: parseEther('0.2'),
        }),
      ).to.be.revertedWith('StageSupplyExceeded');

      await expect(
        contract.mint(1, 1, 0, [ZERO_PROOF], 0, '0x00', {
          value: parseEther('0.3'),
        }),
      ).to.be.revertedWith('StageSupplyExceeded');

      await expect(
        contract.mint(2, 1, 0, [ZERO_PROOF], 0, '0x00', {
          value: parseEther('0.3'),
        }),
      ).to.be.revertedWith('StageSupplyExceeded');
    });

    it('mint with free stage', async () => {
      await contract.setStages([
        {
          price: [0, 0, 0],
          mintFee: [0, 0, 0],
          walletLimit: [0, 0, 0],
          merkleRoot: [ZERO_PROOF, ZERO_PROOF, ZERO_PROOF],
          maxStageSupply: [10, 10, 0],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      const contractBalanceInitial = await ethers.provider.getBalance(
        contract.address,
      );
      const mintFeeReceiverBalanceInitial =
        await ethers.provider.getBalance(MINT_FEE_RECEIVER);

      await readonlyContract.mint(1, 5, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0'),
      });

      await readonlyContract.mint(2, 10, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0'),
      });

      const [stageInfo, walletMintedCount, stagedMintedCount] =
        await readonlyContract.getStageInfo(0);
      expect(stageInfo.maxStageSupply).to.eql([10, 10, 0]);
      expect(walletMintedCount).to.eql([
        BigNumber.from(0),
        BigNumber.from(5),
        BigNumber.from(10),
      ]);
      expect(stagedMintedCount).to.eql([
        BigNumber.from(0),
        BigNumber.from(5),
        BigNumber.from(10),
      ]);

      const contractBalancePost = await ethers.provider.getBalance(
        contract.address,
      );
      expect(contractBalancePost.sub(contractBalanceInitial)).to.equal(0);

      const mintFeeReceiverBalancePost =
        await ethers.provider.getBalance(MINT_FEE_RECEIVER);
      expect(
        mintFeeReceiverBalancePost.sub(mintFeeReceiverBalanceInitial),
      ).to.equal(0);
    });

    it('mint with free stage with mint fee', async () => {
      await contract.setStages([
        {
          price: [0, 0, 0],
          mintFee: [parseEther('0.1'), parseEther('0.2'), parseEther('0.3')],
          walletLimit: [0, 0, 0],
          merkleRoot: [ZERO_PROOF, ZERO_PROOF, ZERO_PROOF],
          maxStageSupply: [100, 100, 100],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      const contractBalanceInitial = await ethers.provider.getBalance(
        contract.address,
      );
      const mintFeeReceiverBalanceInitial =
        await ethers.provider.getBalance(MINT_FEE_RECEIVER);

      await readonlyContract.mint(0, 1, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0.1'),
      });

      await readonlyContract.mint(1, 1, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0.2'),
      });

      await readonlyContract.mint(2, 1, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0.3'),
      });

      await contract.withdraw();

      const [_, walletMintedCount, stagedMintedCount] =
        await readonlyContract.getStageInfo(0);
      expect(walletMintedCount).to.eql([
        BigNumber.from(1),
        BigNumber.from(1),
        BigNumber.from(1),
      ]);
      expect(stagedMintedCount).to.eql([
        BigNumber.from(1),
        BigNumber.from(1),
        BigNumber.from(1),
      ]);

      const contractBalancePost = await ethers.provider.getBalance(
        contract.address,
      );
      expect(contractBalancePost.sub(contractBalanceInitial)).to.equal(0);

      const mintFeeReceiverBalancePost =
        await ethers.provider.getBalance(MINT_FEE_RECEIVER);
      expect(
        mintFeeReceiverBalancePost.sub(mintFeeReceiverBalanceInitial),
      ).to.equal(parseEther('0.6'));
    });

    it('mint with mint fee waived', async () => {
      await contract.setStages([
        {
          price: [0, 0, 0],
          mintFee: [parseEther('0.1'), parseEther('0.2'), parseEther('0.3')],
          walletLimit: [0, 0, 0],
          merkleRoot: [ZERO_PROOF, ZERO_PROOF, ZERO_PROOF],
          maxStageSupply: [100, 100, 100],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      const [_owner, minter, cosigner] = await ethers.getSigners();

      await contract.setCosigner(cosigner.address);

      const timestamp = stageStart + 1;

      let sig = getCosignSignature(
        contract,
        cosigner,
        minter.address,
        timestamp,
        2,
        1,
        false,
      );

      await expect(
        readonlyContract.mint(
          2,
          1,
          0,
          [ethers.utils.hexZeroPad('0x', 32)],
          timestamp,
          sig,
          {
            value: ethers.utils.parseEther('0'), // price = 0, mintFee = 0.3
          },
        ),
      ).to.be.rejectedWith('NotEnoughValue');

      sig = getCosignSignature(
        contract,
        cosigner,
        minter.address,
        timestamp,
        2,
        1,
        true,
      );
      await readonlyContract.mint(
        2,
        1,
        0,
        [ethers.utils.hexZeroPad('0x', 32)],
        timestamp,
        sig,
        {
          value: ethers.utils.parseEther('0'), // price = 0, mintFee = 0.3
        },
      );
      const [stageInfo, walletMintedCount, stagedMintedCount] =
        await readonlyContract.getStageInfo(0);
      expect(walletMintedCount).to.eql([
        BigNumber.from(0),
        BigNumber.from(0),
        BigNumber.from(1),
      ]);
      expect(walletMintedCount).to.eql([
        BigNumber.from(0),
        BigNumber.from(0),
        BigNumber.from(1),
      ]);
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

      // Set stages
      await contract.setStages([
        {
          price: [parseEther('0.1'), parseEther('0.1'), parseEther('0.1')],
          mintFee: [0, 0, 0],
          walletLimit: [10, 10, 0],
          merkleRoot: [ZERO_PROOF, root, ZERO_PROOF],
          maxStageSupply: [0, 0, 0],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      // Mint 1 token A
      await contract.mint(0, 1, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0.1'),
      });

      // Mint 1 token B with valid proof
      await contract.mint(1, 1, 0, proof, 0, '0x00', {
        value: parseEther('0.1'),
      });

      // Mint 1 token C
      await contract.mint(2, 1, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0.1'),
      });

      const totalMinted = await contract.totalMintedByAddress(signerAddress);
      expect(totalMinted).to.eql([
        BigNumber.from(1),
        BigNumber.from(1),
        BigNumber.from(1),
      ]);

      // Mint 1 token B with someone's else proof should be reverted
      await expect(
        readonlyContract.mint(1, 1, 0, proof, 0, '0x00', {
          value: parseEther('0.1'),
        }),
      ).to.be.rejectedWith('InvalidProof');
    });

    it('mint with limit', async () => {
      const ownerAddress = await owner.getAddress();
      const readerAddress = await readonly.getAddress();
      const leaves = [
        ethers.utils.solidityKeccak256(
          ['address', 'uint32'],
          [ownerAddress, 2],
        ),
        ethers.utils.solidityKeccak256(
          ['address', 'uint32'],
          [readerAddress, 5],
        ),
      ];

      const merkleTree = new MerkleTree(leaves, ethers.utils.keccak256, {
        sortPairs: true,
        hashLeaves: false,
      });
      const root = merkleTree.getHexRoot();
      const ownerLeaf = ethers.utils.solidityKeccak256(
        ['address', 'uint32'],
        [ownerAddress, 2],
      );
      const readerLeaf = ethers.utils.solidityKeccak256(
        ['address', 'uint32'],
        [readerAddress, 5],
      );
      const ownerProof = merkleTree.getHexProof(ownerLeaf);
      const readerProof = merkleTree.getHexProof(readerLeaf);

      // Set stages
      await contract.setStages([
        {
          price: [parseEther('0.1'), parseEther('0.1'), parseEther('0.1')],
          mintFee: [0, 0, 0],
          walletLimit: [10, 10, 10],
          merkleRoot: [ZERO_PROOF, root, ZERO_PROOF],
          maxStageSupply: [0, 0, 0],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      // Owner mints 1 token B with valid proof
      await contract.mint(1, 1, 2, ownerProof, 0, '0x00', {
        value: parseEther('0.1'),
      });

      expect(await contract.totalMintedByAddress(owner.getAddress())).to.eql([
        BigNumber.from(0),
        BigNumber.from(1),
        BigNumber.from(0),
      ]);

      // Owner mints 1 token B with wrong limit and should be reverted.
      await expect(
        contract.mint(1, 1, 3, ownerProof, 0, '0x00', {
          value: parseEther('0.1'),
        }),
      ).to.be.rejectedWith('InvalidProof');

      // Owner mints 2 token B with valid proof and reverts.
      await expect(
        contract.mint(1, 2, 2, ownerProof, 0, '0x00', {
          value: parseEther('0.2'),
        }),
      ).to.be.rejectedWith('WalletStageLimitExceeded');

      // Owner mints 1 token B with valid proof. Now owner reaches the limit.
      await contract.mint(1, 1, 2, ownerProof, 0, '0x00', {
        value: parseEther('0.1'),
      });
      expect(await contract.totalMintedByAddress(owner.getAddress())).to.eql([
        BigNumber.from(0),
        BigNumber.from(2),
        BigNumber.from(0),
      ]);

      // Owner tries to mint more and reverts.
      await expect(
        contract.mint(1, 1, 2, ownerProof, 0, '0x00', {
          value: parseEther('0.1'),
        }),
      ).to.be.rejectedWith('WalletStageLimitExceeded');

      // Reader mints 6 token B with valid proof and reverts.
      await expect(
        readonlyContract.mint(1, 6, 5, readerProof, 0, '0x00', {
          value: parseEther('0.6'),
        }),
      ).to.be.rejectedWith('WalletStageLimitExceeded');

      // Reader mints 5 token B with valid proof.
      await readonlyContract.mint(1, 5, 5, readerProof, 0, '0x00', {
        value: parseEther('0.5'),
      });

      // Reader mints 1 token B with valid proof and reverts.
      await expect(
        readonlyContract.mint(1, 1, 5, readerProof, 0, '0x00', {
          value: parseEther('0.1'),
        }),
      ).to.be.rejectedWith('WalletStageLimitExceeded');
    });

    it('mints by owner', async () => {
      const [owner] = await ethers.getSigners();
      await contract.ownerMint(owner.address, 1, 5);

      const [, walletMintedCount, stageMintedCount] =
        await contract.getStageInfo(0);

      expect(walletMintedCount).to.eql([
        BigNumber.from(0),
        BigNumber.from(0),
        BigNumber.from(0),
      ]);
      expect(stageMintedCount).to.eql([
        BigNumber.from(0),
        BigNumber.from(0),
        BigNumber.from(0),
      ]);

      expect(await contract.balanceOf(owner.address, 0)).to.equal(0);
      expect(await contract.balanceOf(owner.address, 1)).to.equal(5);
      expect(await contract.balanceOf(owner.address, 2)).to.equal(0);

      await contract.ownerMint(owner.address, 2, 10);

      expect(await contract.balanceOf(owner.address, 0)).to.equal(0);
      expect(await contract.balanceOf(owner.address, 1)).to.equal(5);
      expect(await contract.balanceOf(owner.address, 2)).to.equal(10);
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
          price: [parseEther('0.4')],
          mintFee: [parseEther('0.1')],
          walletLimit: [10],
          merkleRoot: [ZERO_PROOF],
          maxStageSupply: [5],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);
    });

    it('revert if not authorized minter', async () => {
      const mint = contract.authorizedMint('0xef59F379B48f2E92aBD94ADcBf714D170967925D', 0, 1, 1, [ZERO_PROOF], {
        value: parseEther('1'),
      });
      await expect(mint).to.be.revertedWith('NotAuthorized');
    });

    it('authorized mint', async () => {
      const recipient = '0xef59F379B48f2E92aBD94ADcBf714D170967925D';
      const reservoirSigner = await ethers.getImpersonatedSigner('0xf70da97812CB96acDF810712Aa562db8dfA3dbEF');
      const reservoirAddress = await reservoirSigner.getAddress();

      // Send some wei to impersonated account
      await ethers.provider.send('hardhat_setBalance', [
        reservoirAddress,
        '0xFFFFFFFFFFFFFFFF',
      ]);

      const reservoirConn = contract.connect(reservoirSigner);

      await expect(reservoirConn.authorizedMint('0xef59F379B48f2E92aBD94ADcBf714D170967925D', 0, 1, 1, [ZERO_PROOF], {
        value: parseEther('1'),
      })).to.be.revertedWith('NotAuthorized');

      await contract.addAuthorizedMinter(reservoirAddress);

      await reservoirConn.authorizedMint('0xef59F379B48f2E92aBD94ADcBf714D170967925D', 0, 1, 1, [ZERO_PROOF], {
        value: parseEther('1'),
      });

      const totalMinted = await contract.totalMintedByAddress(recipient);
      expect(totalMinted).to.eql([BigNumber.from(1)]);

      await contract.removeAuthorizedMinter(reservoirAddress);
      await expect(reservoirConn.authorizedMint('0xef59F379B48f2E92aBD94ADcBf714D170967925D', 0, 1, 1, [ZERO_PROOF], {
        value: parseEther('1'),
      })).to.be.revertedWith('NotAuthorized');
    });
  });

  describe('Token URI', function () {
    it('returns uri', async () => {
      expect(await contract.uri(0)).to.eql('https://example/{id}.json');
      expect(await contract.uri(1)).to.eql('https://example/{id}.json');
      expect(await contract.uri(999)).to.eql('https://example/{id}.json');

    });

    it('updates uri', async () => {
      expect(await contract.uri(0)).to.eql('https://example/{id}.json');
      await contract.setURI('https://new/{id}.json');
      expect(await contract.uri(10)).to.eql('https://new/{id}.json');
    });
  });

  describe('Global wallet limit', function () {
    it('validates global wallet limit in constructor', async () => {
      const factory = await ethers.getContractFactory('ERC1155M');
      await expect(
        factory.deploy(
          'collection',
          'symbol',
          'https://example/{id}.json',
          [100],
          [101],
          ethers.constants.AddressZero,
          60,
          PAYMENT_ADDRESS,
          fundReceiver.address,
          WALLET_1,
          10,
        ),
      ).to.be.revertedWith('GlobalWalletLimitOverflow');
    });

    it('validates the size of global wallet limit of max mintable supply in constructor', async () => {
      const factory = await ethers.getContractFactory('ERC1155M');
      await expect(
        factory.deploy(
          'collection',
          'symbol',
          'https://example/{id}.json',
          [100],
          [0, 0],
          ethers.constants.AddressZero,
          60,
          PAYMENT_ADDRESS,
          fundReceiver.address,
          WALLET_1,
          10,
        ),
      ).to.be.revertedWith('InvalidLimitArgsLength');
    });

    it('sets global wallet limit', async () => {
      await contract.setGlobalWalletLimit(0, 2);
      expect((await contract.getGlobalWalletLimit(0)).toNumber()).to.equal(2);

      await expect(contract.setGlobalWalletLimit(0, 101)).to.be.revertedWith(
        'GlobalWalletLimitOverflow',
      );

      await expect(contract.setGlobalWalletLimit(1, 100)).to.be.rejectedWith(
        'InvalidTokenId',
      )
    });

    it('enforces global wallet limit', async () => {
      await contract.setGlobalWalletLimit(0, 2);
      expect((await contract.getGlobalWalletLimit(0)).toNumber()).to.equal(2);

      const block = await ethers.provider.getBlock(
        await ethers.provider.getBlockNumber(),
      );
      // +10 is a number bigger than the count of transactions up to mint
      const stageStart = block.timestamp;
      const stageEnd = stageStart + 100;
      // Set stages
      await contract.setStages([
        {
          price: [parseEther('0.1')],
          mintFee: [parseEther('0.01')],
          walletLimit: [0],
          merkleRoot: [ZERO_PROOF],
          maxStageSupply: [100],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      await contract.mint(0, 2, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0.22'),
      });

      await expect(
        contract.mint(0, 1, 0, [ZERO_PROOF], 0, '0x00', {
          value: parseEther('0.11'),
        }),
      ).to.be.revertedWith('WalletGlobalLimitExceeded');
    });
  });

  describe('Enforce transferablity', function () {
    it('set transferable', async () => {
      await expect(contract.setTransferable(false))
        .to.emit(contract, 'SetTransferable')
        .withArgs(false);

      await expect(contract.setTransferable(true))
        .to.emit(contract, 'SetTransferable')
        .withArgs(true);
    });

    it('can mint and burn when not transferable', async () => {
      await expect(contract.setTransferable(false))
        .to.emit(contract, 'SetTransferable')
        .withArgs(false);

      const block = await ethers.provider.getBlock(
        await ethers.provider.getBlockNumber(),
      );
      const stageStart = block.timestamp;
      const stageEnd = stageStart + 100;

      await contract.setStages([
        {
          price: [parseEther('0.1')],
          mintFee: [parseEther('0.01')],
          walletLimit: [0],
          merkleRoot: [ZERO_PROOF],
          maxStageSupply: [100],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);

      // Can mint
      await contract.mint(0, 3, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0.33'),
      });

      expect(await contract.balanceOf(owner.address, 0)).to.eql(BigNumber.from(3));

      // Cannot transfer
      await expect(contract.safeTransferFrom(owner.address, readonly.address, 0, 1, '0x00')).to.be.revertedWith('NotTransferable');
      expect(await contract.balanceOf(owner.address, 0)).to.eql(BigNumber.from(3));

      // Open transfer
      await expect(contract.setTransferable(true))
        .to.emit(contract, 'SetTransferable')
        .withArgs(true);

      // Can mint
      await contract.mint(0, 2, 0, [ZERO_PROOF], 0, '0x00', {
        value: parseEther('0.22'),
      });

      expect(await contract.balanceOf(owner.address, 0)).to.eql(BigNumber.from(5));

      // Can transfer
      await contract.safeTransferFrom(owner.address, readonly.address, 0, 4, '0x00');
      expect(await contract.balanceOf(owner.address, 0)).to.eql(BigNumber.from(1));
      expect(await contract.balanceOf(readonly.address, 0)).to.eql(BigNumber.from(4));
    });
  });

  describe('Royalty info', function () {
    beforeEach(async () => {
      const factory = await ethers.getContractFactory('ERC1155M');
      const erc1155M = await factory.deploy(
        'collection',
        'symbol',
        'https://example/{id}.json',
        [100, 200],
        [0, 0],
        ethers.constants.AddressZero,
        60,
        PAYMENT_ADDRESS,
        fundReceiver.address,
        WALLET_1,
        10,
      );
      await erc1155M.deployed();

      contract = erc1155M.connect(owner);
      readonlyContract = erc1155M.connect(readonly);
    });

    it('Set default royalty', async () => {
      let royaltyInfo = await contract.royaltyInfo(0, 1000);
      expect(royaltyInfo[0]).to.equal(WALLET_1);
      expect(royaltyInfo[1].toNumber()).to.equal(1);

      royaltyInfo = await contract.royaltyInfo(1, 9999);
      expect(royaltyInfo[0]).to.equal(WALLET_1);
      expect(royaltyInfo[1].toNumber()).to.equal(9);

      await contract.setDefaultRoyalty(WALLET_2, 0);

      royaltyInfo = await contract.royaltyInfo(0, 1000);
      expect(royaltyInfo[0]).to.equal(WALLET_2);
      expect(royaltyInfo[1].toNumber()).to.equal(0);

      royaltyInfo = await contract.royaltyInfo(1, 9999);
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

      await contract.setTokenRoyalty(1, WALLET_2, 100);

      royaltyInfo = await contract.royaltyInfo(0, 1000);
      expect(royaltyInfo[0]).to.equal(WALLET_1);
      expect(royaltyInfo[1].toNumber()).to.equal(1);

      royaltyInfo = await contract.royaltyInfo(1, 9999);
      expect(royaltyInfo[0]).to.equal(WALLET_2);
      expect(royaltyInfo[1].toNumber()).to.equal(99);
    });

    it('Non-owner update reverts', async () => {
      await expect(
        readonlyContract.setTokenRoyalty(1, WALLET_2, 100),
      ).to.be.revertedWith('Unauthorized');

      await expect(
        readonlyContract.setDefaultRoyalty(WALLET_2, 0),
      ).to.be.revertedWith('Unauthorized');
    });
  });

  describe('ERC20 minting', () => {
    let erc20: Contract;

    const mintPrice = 50;
    const mintFee = 10;
    const mintQty = 3;
    const mintCost = (mintPrice + mintFee) * mintQty;

    beforeEach(async () => {
      // Deploy the ERC20 token contract that will be used for minting
      const Token = await ethers.getContractFactory('MockERC20');
      erc20 = await Token.deploy(10000);
      await erc20.deployed();

      const factory = await ethers.getContractFactory('ERC1155M');
      const erc1155M = await factory.deploy(
        'collection',
        'symbol',
        'https://example/{id}.json',
        [10],
        [0],
        ethers.constants.AddressZero,
        60,
        erc20.address,
        fundReceiver.address,
        WALLET_1,
        10,
      );
      await erc1155M.deployed();

      contract = erc1155M.connect(owner);
      readonlyContract = erc1155M.connect(readonly);

      // Get an estimated stage start time
      const block = await ethers.provider.getBlock(
        await ethers.provider.getBlockNumber(),
      );
      const stageStart = block.timestamp;
      // +100 is a number bigger than the count of transactions needed for this test
      const stageEnd = stageStart + 100;

      await contract.setStages([
        {
          price: [mintPrice],
          mintFee: [mintFee],
          walletLimit: [0],
          merkleRoot: [ZERO_PROOF],
          maxStageSupply: [0],
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageEnd,
        },
      ]);
    });

    it('should read the correct erc20 token address', async function () {
      expect(await contract.getMintCurrency()).to.equal(erc20.address);
    });

    it('should revert mint if not enough token allowance', async function () {
      // Give minter some mock tokens
      const minterBalance = 1000;
      const minterAddress = await owner.getAddress();

      await erc20.mint(minterAddress, minterBalance);

      // mint should revert
      await expect(
        contract
          .mint(0, mintQty, 0, [ethers.utils.hexZeroPad('0x', 32)], 0, '0x00',),
      ).to.be.revertedWith(`ERC20InsufficientAllowance("${contract.address}", 0, ${mintCost})`);
    });

    it('should revert mint if not enough token balance', async function () {
      // Give minter some mock tokens
      const minterBalance = 1;
      const minterAddress = await owner.getAddress();

      await erc20.mint(minterAddress, minterBalance);

      // approve contract for erc-20 transfer
      await erc20.connect(owner).approve(contract.address, mintCost);

      // mint should revert
      await expect(
        contract
          .mint(0, mintQty, 0, [ethers.utils.hexZeroPad('0x', 32)], 0, '0x00'),
      ).to.be.revertedWith(`ERC20InsufficientBalance("${minterAddress}", ${minterBalance}, ${mintCost})`);
    });

    it('should transfer the ERC20 tokens and mint when all conditions are met', async function () {
      // Give minter some mock tokens
      const minterBalance = 1000;
      await erc20.mint(await readonly.getAddress(), minterBalance);

      // approve contract for erc-20 transfer
      await erc20.connect(readonly).approve(readonlyContract.address, mintCost);

      // Mint tokens
      await readonlyContract
        .mint(0, mintQty, 0, [ethers.utils.hexZeroPad('0x', 32)], 0, '0x00');

      const postMintBalance = await erc20.balanceOf(
        await readonly.getAddress(),
      );
      expect(postMintBalance).to.equal(minterBalance - mintCost);

      const contractBalance = await erc20.balanceOf(contract.address);
      expect(contractBalance).to.equal(mintCost);

      const totalMintedByMinter = await contract.totalMintedByAddress(
        await readonly.getAddress(),
      );
      expect(totalMintedByMinter[0].toNumber()).to.equal(mintQty);

      const totalSupply = await contract["totalSupply()"]();
      expect(totalSupply.toNumber()).to.equal(mintQty);
    });

    it('should transfer the correct amount of ERC20 tokens to the owner', async function () {
      // First, send some ERC20 tokens to the contract
      const initialAmount = 10;
      await erc20.mint(contract.address, initialAmount);

      // Then, call the withdrawERC20 function from the owner's account
      await contract.withdrawERC20();

      // Get the fundReceiver's balance
      const fundReceiverBalance = await erc20.balanceOf(await fundReceiver.getAddress());

      expect(fundReceiverBalance).to.equal(initialAmount);
    });

    it('should revert if a non-owner tries to withdraw', async function () {
      // Try to call withdrawERC20 from another account
      const nonOwnerAddress = await readonly.getAddress();
      await expect(readonlyContract.withdrawERC20()).to.be.revertedWith(
        'Unauthorized',
      );
    });
  });

  it('Supports the right interfaces', async () => {
    expect(await contract.supportsInterface('0x01ffc9a7')).to.be.true; // IERC165
    expect(await contract.supportsInterface('0x2a55205a')).to.be.true; // IERC2981
    expect(await contract.supportsInterface('0xd9b67a26')).to.be.true; // IERC1155
    expect(await contract.supportsInterface('0x0e89341c')).to.be.true; // IERC1155MetadataURI
  });
});
