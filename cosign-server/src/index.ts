import { Wallet } from '@ethersproject/wallet';
import { keccak256 } from '@ethersproject/solidity';
import { arrayify } from '@ethersproject/bytes';
import { Router, Request as IRequest } from 'itty-router';
import { dd } from './datadog';
import { ICollectionRequest, ICosignRequest } from './types';

const router = Router();

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

router.get('/', () => new Response('ERC721M Cosign Server v0.0.2'));
router.post(
  '/collections',
  async (request: Request & IRequest, event: FetchEvent) => {
    if (
      !cryptoTimingSafeEqualStr(
        request.headers.get('x-admin-key') || '',
        ADMIN_KEY,
      )
    ) {
      return new Response(`Unauthorized`, { status: 401 });
    }

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
  },
);

router.get(
  '/collections',
  async (request: Request & IRequest, event: FetchEvent) => {
    if (
      !cryptoTimingSafeEqualStr(
        request.headers.get('x-admin-key') || '',
        ADMIN_KEY,
      )
    ) {
      return new Response('Unauthorized', { status: 401 });
    }

    const { keys } = await COLLECTIONS.list();
    const res = [];
    for (const key of keys) {
      const value = await COLLECTIONS.get(key.name);
      if (value) {
        res.push(JSON.parse(value));
      }
    }
    return new Response(JSON.stringify(res));
  },
);

router.post(
  '/cosign',
  async (request: Request & IRequest, event: FetchEvent) => {
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
  },
);

// 404 for everything else
router.all('*', () => new Response('Not Found.', { status: 404 }));

// attach the router "handle" to the event handler
addEventListener('fetch', (event) => {
  if (event.request.method.toLowerCase() === 'options') {
    event.respondWith(handleOptions(event.request));
  } else {
    event.respondWith(
      router
        .handle(event.request, event)
        .catch((err) => errorHandler(err, event))
        .then((response) => {
          response.headers.set('Access-Control-Allow-Origin', '*');
          response.headers.set(
            'Access-Control-Allow-Methods',
            'GET,HEAD,POST,OPTIONS',
          );
          response.headers.set('Access-Control-Max-Age', '86400');
          response.headers.set('Access-Control-Allow-Headers', '*');

          return response;
        }),
    );
  }
});

/**
 * Generic Error Handler
 */
const errorHandler = (error: any, event: FetchEvent) => {
  dd(
    event,
    {
      message: error.message,
      error: {
        message: error.message,
        stack: error.stack,
        code: error.code,
      },
    },
    'error',
  );
  return new Response(error.message || 'Internal Server Error', {
    status: error.status || 500,
  });
};

function handleOptions(_request: Request) {
  return new Response(null, {
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET,HEAD,POST,OPTIONS',
      'Access-Control-Max-Age': '86400',
      'Access-Control-Allow-Headers': '*',
    },
  });
}
