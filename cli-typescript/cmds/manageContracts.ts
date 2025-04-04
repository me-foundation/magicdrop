import { Command } from 'commander';
// import { setupContract, freezeThawContract, setGlobalWalletLimitContract, setMaxMintableSupplyContract, setMintableContract, setStagesContract, setTimestampExpiryContract, transferOwnershipContract, setRoyaltiesContract, setBaseUriContract, setUriContract, setTokenUriSuffixContract, setCosignerContract, withdrawContract, manageAuthorizedMintersContract } from '../utils/contractActions';
import { rawlist } from '@inquirer/prompts';

const handleAction = async (action: string) => {
    // switch (action) {
    //     case 'Initialize contract':
    //         setupContract();
    //         break;
    //     case 'Freeze/Thaw Contract':
    //         freezeThawContract();
    //         break;
    //     case 'Set Global Wallet Limit':
    //         setGlobalWalletLimitContract();
    //         break;
    //     case 'Set Max Mintable Supply':
    //         setMaxMintableSupplyContract();
    //         break;
    //     case 'Set Mintable (ERC721 Only)':
    //         setMintableContract();
    //         break;
    //     case 'Set Stages':
    //         setStagesContract();
    //         break;
    //     case 'Set Timestamp Expiry':
    //         setTimestampExpiryContract();
    //         break;
    //     case 'Transfer Ownership':
    //         transferOwnershipContract();
    //         break;
    //     case 'Set Royalties':
    //         setRoyaltiesContract();
    //         break;
    //     case 'Set Base URI (ERC721 Only)':
    //         setBaseUriContract();
    //         break;
    //     case 'Set URI (ERC1155 Only)':
    //         setUriContract();
    //         break;
    //     case 'Set Token URI Suffix (ERC721 Only)':
    //         setTokenUriSuffixContract();
    //         break;
    //     case 'Set Cosigner':
    //         setCosignerContract();
    //         break;
    //     case 'Withdraw Contract Balance':
    //         withdrawContract();
    //         break;
    //     case 'Manage Authorized Minters':
    //         manageAuthorizedMintersContract();
    //         break;
    //     case 'Go to Main Menu':
    //         // Logic to go back to main menu
    //         console.log('Returning to Main Menu...');
    //         break;
    //     default:
    //         console.log('Invalid option selected.');
    // }
}

export const manageContracts = (program: Command) => {
    program
        .command('manage-contracts')
        .description('Manage existing contracts')
        .action(async () => {
            const answer = await rawlist({
                    message: 'Select an action:',
                    choices: [
                        { value: 'Initialize contract' },
                        { value: 'Freeze/Thaw Contract' },
                        { value: 'Set Global Wallet Limit' },
                        { value: 'Set Max Mintable Supply' },
                        { value: 'Set Mintable (ERC721 Only)' },
                        { value: 'Set Stages' },
                        { value: 'Set Timestamp Expiry' },
                        { value: 'Transfer Ownership' },
                        { value: 'Set Royalties' },
                        { value: 'Set Base URI (ERC721 Only)' },
                        { value: 'Set URI (ERC1155 Only)' },
                        { value: 'Set Token URI Suffix (ERC721 Only)' },
                        { value: 'Set Cosigner' },
                        { value: 'Withdraw Contract Balance' },
                        { value: 'Manage Authorized Minters' },
                        { value: 'Go to Main Menu' }
                    ]
                })
                
            await handleAction(answer);
        });
};

export default manageContracts;