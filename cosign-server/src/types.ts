export interface ICosignRequest {
  collectionContract: string;
  minter: string;
  qty: number;
}

export interface ICollectionRequest {
  collectionContract: string;
  startTimeUnixSeconds?: number; // unix timestamp in seconds
  endTimeUnixSeconds?: number; // unix timestamp in seconds
}
