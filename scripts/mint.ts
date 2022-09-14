// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from 'hardhat';

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const ERC721M = await ethers.getContractFactory('ERC721M');
  const contract = ERC721M.attach('0xd5C9cf472C2c34bfdc9f2473F422505398eD76EC');
  const [stageInfo] = await contract.getStageInfo(0);
  const quantity = 3;
  console.log(stageInfo);
  const tx = await contract.mint(ethers.BigNumber.from(quantity), [], {
    value: stageInfo.price.mul(quantity),
  });

  await tx.wait();

  console.log('Minted:', tx.hash);
  console.log('New total supply:', (await contract.totalSupply()).toNumber());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
