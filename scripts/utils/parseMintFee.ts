import { ethers } from 'ethers';

export const parseMintFee = (mintFee: number) => ethers.utils.parseEther(mintFee.toString());