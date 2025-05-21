import fs from 'fs';
import * as okta from './okta';
import { mkdirp } from 'mkdirp';

export const authenticate = async () => {
  const configDir = `${process.env.HOME}/.config/magicdrop2`;
  const configPath = `${configDir}/config.json`;

  // make dir if it does not exist
  mkdirp.sync(configDir);

  // Load credentials
  const config: IConfig = fs.existsSync(configPath)
    ? JSON.parse(fs.readFileSync(configPath, 'utf-8'))
    : {
        accessToken: '',
        refreshToken: '',
        idToken: '',
        expires: '2025-05-31T00:00:00.000Z',
        meApiAdminKey: '',
      };

  const setToken = (token: okta.IAuth['token']) => {
    config.accessToken = token.access_token;
    config.refreshToken = token.refresh_token;
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
  };

  if (!config.accessToken || !config.refreshToken) {
    const { token } = await okta.authenticate();
    setToken(token);
    return;
  }

  // Decode the access token and find expiry
  const decoded = decodeJWT(config.accessToken);
  const expiry = new Date(decoded.exp * 1000).getTime();
  const now = new Date().getTime();

  if (now >= expiry) {
    // Authenticate if expired, and we do not have a valid refresh token
    if (!(await okta.validToken(config.refreshToken, 'refresh_token'))) {
      const { token } = await okta.authenticate();
      setToken(token);
    } else {
      // Refresh if expired, and we have a valid refresh token
      const token = await okta.refresh(config.refreshToken);
      if (token) setToken(token);
    }
  }

  return {
    Authorization: `Bearer ${config.accessToken}`,
  };
};

export const decodeJWT = (token: string) => {
  return JSON.parse(
    Buffer.from(token.split('.')[1], 'base64').toString(),
  ) as DecodedJWT;
};

export type DecodedJWT = {
  ver: number;
  jti: string;
  iss: string;
  aud: string;
  sub: string;
  iat: number;
  exp: number;
  cid: string;
  uid: string;
  scp: string[];
  auth_time: number;
};

export type IConfig = {
  accessToken: string;
  refreshToken: string;
  idToken: string;
  expires: string;
  meApiAdminKey: string;
  xBypassBotKey: string;
};
