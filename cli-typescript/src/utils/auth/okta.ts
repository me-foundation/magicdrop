/**
 * Authenticate using okta
 *
 * TODO: we forked this file from cli/ to unblock eth tooling. Refactor this into a shared lib.
 */

import axios from 'axios';
import { createHash, randomBytes } from 'crypto';
import express from 'express';
import open from 'open';
import { stringify } from 'querystring';

export const OKTA = {
  oktaOrgUrl: 'https://magiceden.okta.com',
  clientId: '0oaczwrqrdhJTKiuC696',
  scopes: 'openid email profile offline_access',
};

const redirectUri = 'http://localhost:30033/login/callback';

/**
 * Okta PKCE config
 */
export const getInfo = async (accessToken: string): Promise<boolean> => {
  const client = axios.create({
    baseURL: OKTA.oktaOrgUrl,
  });

  const info = await client
    .post(
      '/oauth2/v1/introspect',
      stringify({
        token: accessToken,
        client_id: OKTA.clientId,
        token_type_hint: 'access_token',
      }),
    )
    .then((res) => res.data);

  return info;
};

export const validToken = async (
  token: string,
  tokenType: 'access_token' | 'refresh_token',
): Promise<boolean> => {
  const client = axios.create({
    baseURL: OKTA.oktaOrgUrl,
  });

  const info = await client
    .post<IAuth['info']>(
      '/oauth2/v1/introspect',
      stringify({
        token: token,
        client_id: OKTA.clientId,
        token_type_hint: tokenType,
      }),
    )
    .then((res) => res.data);

  return info!.active;
};

export const refresh = async (
  refreshToken: string,
): Promise<IAuth['refresh']> => {
  const client = axios.create({
    baseURL: OKTA.oktaOrgUrl,
  });

  const token = await client
    .post(
      '/oauth2/v1/token',
      stringify({
        grant_type: 'refresh_token',
        redirect_uri: redirectUri,
        scope: OKTA.scopes,
        client_id: OKTA.clientId,
        refresh_token: refreshToken,
      }),
    )
    .then((res) => res.data);

  return token;
};

export const authenticate = async (): Promise<IAuth> => {
  const verifier = randomBytes(64).toString('base64url');
  const verifierSha = base64url(
    createHash('sha256').update(verifier).digest('base64'),
  );

  const code: string = await new Promise((resolve, reject) => {
    const server = express()
      .get('/login/callback', (req, res) => {
        try {
          resolve(req.query.code as string);
          res.json({ message: 'Thank you. You can close this tab.' });
        } catch (err) {
          reject(err);
        } finally {
          server.close();
        }
      })
      .listen(30033);

    open(
      `${OKTA.oktaOrgUrl}/oauth2/v1/authorize?${stringify({
        client_id: OKTA.clientId,
        response_type: 'code',
        scope: OKTA.scopes,
        redirect_uri: redirectUri,
        state: randomBytes(32).toString('base64url'),
        code_challenge_method: 'S256',
        code_challenge: verifierSha,
      })}`,
    );
  });

  const client = axios.create({
    baseURL: OKTA.oktaOrgUrl,
  });

  const token = (await client
    .post<{ access_token: string }>(
      '/oauth2/v1/token',
      stringify({
        grant_type: 'authorization_code',
        redirect_uri: redirectUri,
        client_id: OKTA.clientId,
        code,
        code_verifier: verifier,
      }),
    )
    .then((res) => res.data)) as IAuth['token'];

  return { code, token } as unknown as IAuth;
};

const base64url = (str: string) =>
  str.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

export type IAuth = {
  code: string;

  token: {
    token_type: string;
    expires_in: number;
    access_token: string;
    scope: string;
    refresh_token: string;
    id_token: string;
  };

  user?: {
    sub: string;
    name: string;
    locale: string;
    email: string;
    preferred_username: string;
    given_name: string;
    family_name: string;
    zoneinfo: string;
    updated_at: number;
    email_verified: boolean;
  };

  info?: {
    active: boolean;
    scope: string;
    username: string;
    exp: number;
    iat: number;
    sub: string;
    aud: string;
    iss: string;
    jti: string;
    token_type: string;
    client_id: string;
    uid: string;
  };

  refresh?: {
    token_type: string;
    expires_in: number;
    access_token: string;
    scope: string;
    refresh_token: string;
    id_token: string;
  };
};
