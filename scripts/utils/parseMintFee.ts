import { ethers } from 'ethers';

const mintFee = process.argv[2];
if (!mintFee) {
    console.error('No mint fee provided');
    throw new Error('No mint fee provided');
}

try {
    const parsedFee = ethers.utils.parseEther(mintFee);
    console.log(parsedFee.toString());
} catch (error: any) {
    console.error('Failed to parse mint fee:', error.message);
    throw new Error('Failed to parse mint fee');
}