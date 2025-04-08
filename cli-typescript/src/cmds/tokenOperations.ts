import { rawlist } from '@inquirer/prompts';
import { Command } from 'commander';

const tokenOperations = (program: Command) => {
    program
        .command('token-operations')
        .description('Perform operations related to tokens')
        .action(async () => {
            const option = await rawlist({
                message: "'Select an operation:",
                choices: [
                    { name: '1. Owner Mint', value: '1' },
                    { name: '2. Send ERC721 Batch', value: '2' },
                    { name: '3. Go to Main Menu', value: '3' },
                ]
            });

            switch (option) {
                case '1':
                    await ownerMint();
                    break;
                case '2':
                    await sendERC721Batch();
                    break;
                case '3':
                    // Logic to go to main menu
                    break;
                default:
                    console.log('Invalid option. Please try again.');
            }
        });
};

const ownerMint = async () => {
    // Logic for owner minting
    console.log('Owner minting...');
};

const sendERC721Batch = async () => {
    // Logic for sending ERC721 batch
    console.log('Sending ERC721 batch...');
};

export default tokenOperations;