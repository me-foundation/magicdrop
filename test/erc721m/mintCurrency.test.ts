import { ERC721CM, ERC721M } from '../../typechain-types';
import { Contract, Signer } from 'ethers';
import { ethers } from 'hardhat';
import { expect } from 'chai';

describe('ERC721M: Mint Currency', () => {
  let erc721M: ERC721M;
  let contract: ERC721M;
  let erc20: Contract;
  let owner: Signer;
  let fundReceiver: Signer;
  let minter: Signer;
  const mintPrice = 50;
  const mintFee = 10;
  const mintQty = 3;
  const mintCost = (mintPrice + mintFee) * mintQty;

  describe('deployed with ERC-20 token as mint currency', function () {
    beforeEach(async function () {
      [owner, minter, fundReceiver] = await ethers.getSigners();

      // Deploy the ERC20 token contract that will be used for minting
      const Token = await ethers.getContractFactory('MockERC20');
      erc20 = await Token.deploy(10000);
      await erc20.deployed();

      // Deploy the ERC721M contract
      const ERC721M = await ethers.getContractFactory('ERC721M');
      erc721M = await ERC721M.deploy(
        'Test',
        'TEST',
        '',
        1000,
        0,
        ethers.constants.AddressZero,
        60,
        erc20.address,
        fundReceiver.getAddress(),
      );
      await erc721M.deployed();


      contract = erc721M.connect(owner);

      const block = await ethers.provider.getBlock(
        await ethers.provider.getBlockNumber(),
      );
      // +10 is a number bigger than the count of transactions up to mint
      const stageStart = block.timestamp + 10;
      // Set stages
      await contract.setStages([
        {
          price: mintPrice,
          mintFee: mintFee,
          walletLimit: 0,
          merkleRoot: ethers.utils.hexZeroPad('0x0', 32),
          maxStageSupply: 5,
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageStart + 10000,
        },
      ]);
      await contract.setMaxMintableSupply(999);
      await contract.setMintable(true);

      // Setup the test context: Update block.timestamp to comply to the stage being active
      await ethers.provider.send('evm_mine', [stageStart - 1]);
    });

    it('should read the correct erc20 token address', async function () {
      expect(await contract.getMintCurrency()).to.equal(erc20.address);
    });

    describe('mint', function () {
      it('should revert mint if not enough token allowance', async function () {
        // Give minter some mock tokens
        const minterBalance = 1000;
        const minterAddress = await minter.getAddress();

        await erc20.mint(minterAddress, minterBalance);

        // mint should revert
        await expect(
          erc721M
            .connect(minter)
            .mint(mintQty, 0, [ethers.utils.hexZeroPad('0x', 32)], 0, '0x00'),
        ).to.be.revertedWith(`ERC20InsufficientAllowance("${erc721M.address}", 0, ${mintCost})`);
      });

      it('should revert mint if not enough token balance', async function () {
        // Give minter some mock tokens
        const minterBalance = 1;
        await erc20.mint(await minter.getAddress(), minterBalance);

        // approve contract for erc-20 transfer
        await erc20.connect(minter).approve(erc721M.address, mintCost);

        // mint should revert
        await expect(
          erc721M
            .connect(minter)
            .mint(mintQty, 0, [ethers.utils.hexZeroPad('0x', 32)], 0, '0x00'),
        ).to.be.revertedWith('ERC20InsufficientBalance');
      });

      it('should transfer the ERC20 tokens and mint when all conditions are met', async function () {
        // Give minter some mock tokens
        const minterBalance = 1000;
        await erc20.mint(await minter.getAddress(), minterBalance);

        // approve contract for erc-20 transfer
        await erc20.connect(minter).approve(erc721M.address, mintCost);

        // Mint tokens
        await erc721M
          .connect(minter)
          .mint(mintQty, 0, [ethers.utils.hexZeroPad('0x', 32)], 0, '0x00');

        const postMintBalance = await erc20.balanceOf(
          await minter.getAddress(),
        );
        expect(postMintBalance).to.equal(minterBalance - mintCost);

        const contractBalance = await erc20.balanceOf(contract.address);
        expect(contractBalance).to.equal(mintCost);

        const totalMintedByMinter = await contract.totalMintedByAddress(
          await minter.getAddress(),
        );
        expect(totalMintedByMinter.toNumber()).to.equal(mintQty);

        const totalSupply = await contract.totalSupply();
        expect(totalSupply.toNumber()).to.equal(mintQty);
      });
    });

    describe('withdrawERC20', function () {
      it('should transfer the correct amount of ERC20 tokens to the owner', async function () {
        // First, send some ERC20 tokens to the contract
        const initialAmount = 10;
        await erc20.mint(erc721M.address, initialAmount);

        // Then, call the withdrawERC20 function from the owner's account
        await erc721M.connect(owner).withdrawERC20();

        // Get the balance of fundReceiver
        const fundReceiverBalance = await erc20.balanceOf(await fundReceiver.getAddress());

        expect(fundReceiverBalance).to.equal(initialAmount);
      });
    });

    it('should revert if a non-owner tries to withdraw', async function () {
      // Try to call withdrawERC20 from another account
      const mintAddress = await minter.getAddress();
      await expect(erc721M.connect(minter).withdrawERC20()).to.be.revertedWith(
        `OwnableUnauthorizedAccount("${mintAddress}")`,
      );
    });
  });

  describe('deployed with zero address as mint currency', function () {
    beforeEach(async function () {
      // Deploy the ERC721M contract
      const ERC721M = await ethers.getContractFactory('ERC721M');
      erc721M = await ERC721M.deploy(
        'Test',
        'TEST',
        '',
        1000,
        0,
        ethers.constants.AddressZero,
        60,
        ethers.constants.AddressZero,
        fundReceiver.getAddress(),
      );
      await erc721M.deployed();

      [owner, minter] = await ethers.getSigners();

      contract = erc721M.connect(owner);
    });

    describe('withdrawERC20', function () {
      it("should not change the contract's balance", async function () {
        // Get initial balance
        const initialBalance = await ethers.provider.getBalance(
          contract.address,
        );

        // Expect withdrawERC20 to revert
        await expect(contract.withdrawERC20()).to.be.revertedWith(
          'WrongMintCurrency',
        );

        // Get final balance
        const finalBalance = await ethers.provider.getBalance(erc721M.address);

        // The initial and final balances should be the same
        expect(initialBalance).to.equal(finalBalance);
      });
    });
  });
});

describe('ERC721CM: Mint Currency', () => {
  let erc721CM: ERC721CM;
  let contract: ERC721CM;
  let erc20: Contract;
  let owner: Signer;
  let fundReceiver: Signer;
  let minter: Signer;
  const mintPrice = 50;
  const mintFee = 10;
  const mintQty = 3;
  const mintCost = (mintPrice + mintFee) * mintQty;

  describe('deployed with ERC-20 token as mint currency', function () {
    beforeEach(async function () {
      [owner, minter, fundReceiver] = await ethers.getSigners();

      // Deploy the ERC20 token contract that will be used for minting
      const Token = await ethers.getContractFactory('MockERC20');
      erc20 = await Token.deploy(10000);
      await erc20.deployed();

      // Deploy the ERC721M contract
      const ERC721CM = await ethers.getContractFactory('ERC721CM');
      erc721CM = await ERC721CM.deploy(
        'Test',
        'TEST',
        '',
        1000,
        0,
        ethers.constants.AddressZero,
        60,
        erc20.address,
        fundReceiver.getAddress(),
      );
      await erc721CM.deployed();

      contract = erc721CM.connect(owner);

      const block = await ethers.provider.getBlock(
        await ethers.provider.getBlockNumber(),
      );
      // +10 is a number bigger than the count of transactions up to mint
      const stageStart = block.timestamp + 10;
      // Set stages
      await contract.setStages([
        {
          price: mintPrice,
          mintFee: mintFee,
          walletLimit: 0,
          merkleRoot: ethers.utils.hexZeroPad('0x0', 32),
          maxStageSupply: 5,
          startTimeUnixSeconds: stageStart,
          endTimeUnixSeconds: stageStart + 10000,
        },
      ]);
      await contract.setMaxMintableSupply(999);
      await contract.setMintable(true);

      // Setup the test context: Update block.timestamp to comply to the stage being active
      await ethers.provider.send('evm_mine', [stageStart - 1]);
    });

    it('should read the correct erc20 token address', async function () {
      expect(await contract.getMintCurrency()).to.equal(erc20.address);
    });

    describe('mint', function () {
      it('should revert mint if not enough token allowance', async function () {
        // Give minter some mock tokens
        const minterBalance = 1000;
        const minterAddress = await minter.getAddress();

        await erc20.mint(minterAddress, minterBalance);

        // mint should revert
        await expect(
          erc721CM
            .connect(minter)
            .mint(mintQty, 0, [ethers.utils.hexZeroPad('0x', 32)], 0, '0x00'),
        ).to.be.revertedWith(`ERC20InsufficientAllowance("${erc721CM.address}", 0, ${mintCost})`);
      });

      it('should revert mint if not enough token balance', async function () {
        // Give minter some mock tokens
        const minterBalance = 1;
        const minterAddress = await minter.getAddress();

        await erc20.mint(minterAddress, minterBalance);

        // approve contract for erc-20 transfer
        await erc20.connect(minter).approve(erc721CM.address, mintCost);

        // mint should revert
        await expect(
          erc721CM
            .connect(minter)
            .mint(mintQty, 0, [ethers.utils.hexZeroPad('0x', 32)], 0, '0x00'),
        ).to.be.revertedWith(`ERC20InsufficientBalance("${minterAddress}", ${minterBalance}, ${mintCost})`);
      });

      it('should transfer the ERC20 tokens and mint when all conditions are met', async function () {
        // Give minter some mock tokens
        const minterBalance = 1000;
        await erc20.mint(await minter.getAddress(), minterBalance);

        // approve contract for erc-20 transfer
        await erc20.connect(minter).approve(erc721CM.address, mintCost);

        // Mint tokens
        await erc721CM
          .connect(minter)
          .mint(mintQty, 0, [ethers.utils.hexZeroPad('0x', 32)], 0, '0x00');

        const postMintBalance = await erc20.balanceOf(
          await minter.getAddress(),
        );
        expect(postMintBalance).to.equal(minterBalance - mintCost);

        const contractBalance = await erc20.balanceOf(contract.address);
        expect(contractBalance).to.equal(mintCost);

        const totalMintedByMinter = await contract.totalMintedByAddress(
          await minter.getAddress(),
        );
        expect(totalMintedByMinter.toNumber()).to.equal(mintQty);

        const totalSupply = await contract.totalSupply();
        expect(totalSupply.toNumber()).to.equal(mintQty);
      });
    });

    describe('withdrawERC20', function () {
      it('should transfer the correct amount of ERC20 tokens to the owner', async function () {
        // First, send some ERC20 tokens to the contract
        const initialAmount = 10;
        await erc20.mint(erc721CM.address, initialAmount);

        // Then, call the withdrawERC20 function from the owner's account
        await erc721CM.connect(owner).withdrawERC20();

        // Get the fundReceiver's balance
        const fundReceiverBalance = await erc20.balanceOf(await fundReceiver.getAddress());

        expect(fundReceiverBalance).to.equal(initialAmount);
      });
    });

    it('should revert if a non-owner tries to withdraw', async function () {
      // Try to call withdrawERC20 from another account
      const mintAddress = await minter.getAddress();
      await expect(erc721CM.connect(minter).withdrawERC20()).to.be.revertedWith(
        `OwnableUnauthorizedAccount("${mintAddress}")`,
      );
    });
  });

  describe('deployed with zero address as mint currency', function () {
    beforeEach(async function () {
      [owner, minter, fundReceiver] = await ethers.getSigners();

      // Deploy the ERC721M contract
      const ERC721CM = await ethers.getContractFactory('ERC721CM');
      erc721CM = await ERC721CM.deploy(
        'Test',
        'TEST',
        '',
        1000,
        0,
        ethers.constants.AddressZero,
        60,
        ethers.constants.AddressZero,
        fundReceiver.getAddress(),
      );
      await erc721CM.deployed();

      contract = erc721CM.connect(owner);
    });

    describe('withdrawERC20', function () {
      it("should not change the contract's balance", async function () {
        // Get initial balance
        const initialBalance = await ethers.provider.getBalance(
          contract.address,
        );

        // Expect withdrawERC20 to revert
        await expect(contract.withdrawERC20()).to.be.revertedWith(
          'WrongMintCurrency',
        );

        // Get final balance
        const finalBalance = await ethers.provider.getBalance(erc721CM.address);

        // The initial and final balances should be the same
        expect(initialBalance).to.equal(finalBalance);
      });
    });
  });
});
