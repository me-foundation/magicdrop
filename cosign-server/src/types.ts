export interface ICosignRequest {
  collectionContract: string;
  minter: string;
  qty: number;
  chainId: number;
  nonce: number;
}

export interface ICollectionRequest {
  collectionContract: string;
  startTimeUnixSeconds?: number; // unix timestamp in seconds
  endTimeUnixSeconds?: number; // unix timestamp in seconds
}
