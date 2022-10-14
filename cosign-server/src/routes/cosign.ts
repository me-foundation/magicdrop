import { arrayify } from '@ethersproject/bytes';
import { keccak256 } from '@ethersproject/solidity';
import { Wallet } from '@ethersproject/wallet';
import { Router, Request as IRequest } from 'itty-router';
import { dd } from '../datadog';
import { ICosignRequest, ICollectionRequest } from '../types';

let _cosigner: Wallet | undefined;
const getCosigner = () => {
  if (_cosigner) return _cosigner;
  _cosigner = new Wallet(COSIGN_PRIVATE_KEY);
  return _cosigner;
};

const cryptoTimingSafeEqualStr = (
  a: string | undefined,
  b: string | undefined,
): Boolean => {
  try {
    if (typeof a === 'string' && typeof b === 'string') {
      const bufA = Buffer.from(a);
      const bufB = Buffer.from(b);
      return crypto.subtle.timingSafeEqual(bufA, bufB);
    }
  } catch (e: any) {
    console.error(e.message);
  }
  return false;
};

export const post = async (request: Request & IRequest, event: FetchEvent) => {
  const payload = await request.json<ICosignRequest>();

  // timestamp is unix timestamp in seconds
  const timestamp = Math.floor(new Date().getTime() / 1000);

  const collectionJSONStr = await COLLECTIONS.get(
    `collection:v1:${payload.collectionContract.toLowerCase()}`,
  );
  if (!collectionJSONStr) {
    return new Response('Collection not found', { status: 404 });
  }
  const collection = JSON.parse(collectionJSONStr) as ICollectionRequest;
  if (
    collection.startTimeUnixSeconds &&
    timestamp < collection.startTimeUnixSeconds
  ) {
    return new Response('Collection not active', { status: 403 });
  }
  if (
    collection.endTimeUnixSeconds &&
    timestamp > collection.endTimeUnixSeconds
  ) {
    return new Response('Collection not active', { status: 403 });
  }

  const cosigner = getCosigner();
  const digest = keccak256(
    ['address', 'address', 'uint32', 'address', 'uint64'],
    [
      payload.collectionContract.toLowerCase(),
      payload.minter,
      payload.qty,
      cosigner.address,
      timestamp,
    ],
  );
  const sig = await cosigner.signMessage(arrayify(digest));
  dd(event, { message: 'Cosign_Request', payload, sig, timestamp }, 'info');
  return new Response(
    JSON.stringify({ sig, timestamp, cosigner: cosigner.address }),
  );
};
