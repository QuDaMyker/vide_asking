import JWT from 'jsonwebtoken';
import { Request, Response, NextFunction } from 'express';
import { asyncHandler } from '../helpers/asyncHandler';
import {
  AuthFailureError,
  NotFoundError,
  BadRequestError,
} from '../core/error.response';
import { KeyTokenService } from '../services/keyToken.service';
import { IKeyToken } from '../models/keytoken.model';

const HEADER = {
  API_KEY: 'x-api-key',
  AUTHORIZATION: 'authorization',
  CLIENT_ID: 'x-client-id',
  REFRESH_TOKEN: 'refreshtoken',
};

export interface TokenPayload {
  userId: string;
  email: string;
}

export interface AuthRequest extends Request {
  keyStore?: IKeyToken;
  user?: any;
  refreshToken?: string;
}

export const createTokenPair = async (
  payload: TokenPayload,
  publicKey: string,
  privateKey: string
): Promise<{ accessToken: string; refreshToken: string }> => {
  try {
    const accessToken = JWT.sign(payload, publicKey, {
      algorithm: 'HS512',
      expiresIn: '2 days',
    });

    const refreshToken = JWT.sign(payload, privateKey, {
      algorithm: 'HS512',
      expiresIn: '7 days',
    });

    JWT.verify(accessToken, publicKey, (err, decode) => {
      if (err) {
        console.log(`error verify::`, err);
      } else {
        console.log(`decode verify::`, decode);
      }
    });

    return {
      accessToken,
      refreshToken,
    };
  } catch (error) {
    throw error;
  }
};

export const authentication = asyncHandler(
  async (req: AuthRequest, res: Response, next: NextFunction) => {
    const userId = req.headers[HEADER.CLIENT_ID] as string;
    if (!userId) throw new AuthFailureError('Invalid request');

    const keyTokenService = new KeyTokenService();
    const keyStore = await keyTokenService.findByUserId(userId);
    if (!keyStore) throw new NotFoundError('Not found');

    const accessToken = req.headers[HEADER.AUTHORIZATION] as string;
    if (!accessToken) throw new AuthFailureError('Invalid request');

    try {
      const decodeUser = JWT.verify(accessToken, keyStore.publicKey) as any;
      if (userId !== decodeUser.userId) {
        throw new AuthFailureError('Invalid user');
      }

      req.keyStore = keyStore;
      req.user = decodeUser;
      next();
    } catch (error) {
      console.log(error);
      throw new BadRequestError('Bad request');
    }
  }
);

export const authenticationV2 = asyncHandler(
  async (req: AuthRequest, res: Response, next: NextFunction) => {
    const userId = req.headers[HEADER.CLIENT_ID] as string;
    if (!userId) throw new AuthFailureError('Invalid request');

    const keyTokenService = new KeyTokenService();
    const keyStore = await keyTokenService.findByUserId(userId);
    if (!keyStore) throw new NotFoundError('Not found');

    if (req.headers[HEADER.REFRESH_TOKEN]) {
      try {
        const refreshToken = req.headers[HEADER.REFRESH_TOKEN] as string;
        const decodeUser = JWT.verify(refreshToken, keyStore.privateKey) as any;
        if (userId !== decodeUser.userId) {
          throw new AuthFailureError('Invalid user');
        }

        req.keyStore = keyStore;
        req.user = decodeUser;
        req.refreshToken = refreshToken;
        return next();
      } catch (error) {
        console.log(error);
        throw new BadRequestError('Bad request');
      }
    }

    const accessToken = req.headers[HEADER.AUTHORIZATION] as string;
    if (!accessToken) throw new AuthFailureError('Invalid request');

    try {
      const decodeUser = JWT.verify(accessToken, keyStore.publicKey) as any;
      if (userId !== decodeUser.userId) {
        throw new AuthFailureError('Invalid user');
      }

      req.keyStore = keyStore;
      req.user = decodeUser;
      next();
    } catch (error) {
      console.log(error);
      throw new BadRequestError('Bad request');
    }
  }
);

export const verifyJWT = (token: string, keySecret: string): any => {
  return JWT.verify(token, keySecret);
};
