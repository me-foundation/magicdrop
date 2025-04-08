/**
 * Validates if a given string is a valid Ethereum address.
 * @param address The string to validate.
 * @returns True if the string is a valid Ethereum address, otherwise false.
 */
export const isValidEthereumAddress = (address: string): boolean => {
    return /^0x[a-fA-F0-9]{40}$/.test(address.trim());
};

/**
 * Formats an Ethereum address by showing the first 6 and last 4 characters, separated by "...".
 * @param address The Ethereum address to format.
 * @returns The collapsed address.
 */
export const collapseAddress = (address: string): string => {
    if (!isValidEthereumAddress(address)) {
      throw new Error('Invalid Ethereum address.');
    }
  
    const prefix = address.slice(0, 6);
    const suffix = address.slice(-4);
    return `${prefix}...${suffix}`;
};
