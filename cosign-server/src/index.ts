import { IHTTPMethods, Request as IRequest, Router } from 'itty-router';
import { dd } from './datadog';
import { adminAuth } from './middleware';
import * as routes from './routes';

const router = Router<IRequest, IHTTPMethods>();

router.get('/', () => new Response('ERC721M Cosign Server v0.0.2'));

router.post('/collections', adminAuth, routes.collectionRoutes.post);
router.get('/collections', adminAuth, routes.collectionRoutes.get);

router.post('/cosign', routes.cosignRoutes.post);

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
