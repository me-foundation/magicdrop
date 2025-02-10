import { Wallet } from 'zksync-ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { Deployer } from '@matterlabs/hardhat-zksync';
import { vars } from 'hardhat/config';

// An example of a deploy script that will deploy and call a simple contract.
export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script`);

  // Initialize the wallet using your private key.
  const wallet = new Wallet(vars.get('DEPLOYER_PRIVATE_KEY'));

  // Create deployer object and load the artifact of the contract we want to deploy.
  const deployer = new Deployer(hre, wallet);
  // Load contract
  const erc1155MagicDropCloneableArtifact = await deployer.loadArtifact(
    'contracts/nft/erc1155m/zksync/ERC1155MagicDropCloneable.sol:ERC1155MagicDropCloneable',
  );

  // Deploy this contract. The returned object will be of a `Contract` type,
  // similar to the ones in `ethers`.
  const erc1155MagicDropCloneable = await deployer.deploy(
    erc1155MagicDropCloneableArtifact,
  );
  const erc1155MagicDropCloneableAddress =
    await erc1155MagicDropCloneable.getAddress();

  console.log(
    `${erc1155MagicDropCloneableArtifact.contractName} was deployed to ${erc1155MagicDropCloneableAddress}`,
  );
}
