import { Request as IRequest } from 'itty-router';
import { ICollectionRequest } from '../types';

export const post = async (request: Request & IRequest, _event: FetchEvent) => {
  const payload = await request.json<ICollectionRequest>();
  const value = JSON.stringify({
    ...payload,
    collectionContract: payload.collectionContract.toLowerCase(),
  });
  await COLLECTIONS.put(
    `collection:v1:${payload.collectionContract.toLowerCase()}`,
    value,
  );
  return new Response(value);
};

export const get = async (_request: Request & IRequest, _event: FetchEvent) => {
  const { keys } = await COLLECTIONS.list();
  const res = [];
  for (const key of keys) {
    const value = await COLLECTIONS.get(key.name);
    if (value) {
      res.push(JSON.parse(value));
    }
  }
  return new Response(JSON.stringify(res));
};
