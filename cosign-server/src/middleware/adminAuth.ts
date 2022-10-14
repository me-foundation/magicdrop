import { Request as IRequest } from 'itty-router';

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

export const adminAuth = async (
  request: Request & IRequest,
  _event: FetchEvent,
) => {
  if (
    !cryptoTimingSafeEqualStr(
      request.headers.get('x-admin-key') || '',
      ADMIN_KEY,
    )
  ) {
    return new Response(`Unauthorized`, { status: 401 });
  }
};
