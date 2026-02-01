import { injectable, inject } from 'inversify';
import { shopModel, IShop } from '../models/shop.model';
import bcrypt from 'bcrypt';
import crypto from 'crypto';
import { KeyTokenService } from './keyToken.service';
import { createTokenPair, verifyJWT } from '../auth/authUtils';
import { getInfoData } from '../utils';
import {
  BadRequestError,
  AuthFailureError,
  ForbiddenError,
} from '../core/error.response';
import { ShopService } from './shop.service';
import { keytokenModel, IKeyToken } from '../models/keytoken.model';
import { TYPES } from '../di/types';

export const RoleShop = {
  SHOP: 'SHOP',
  WRITER: 'WRITER',
  EDITOR: 'EDITOR',
  ADMIN: 'ADMIN',
} as const;

export interface IAccessService {
  handlerRefreshTokenV2(params: {
    refreshToken: string;
    user: any;
    keyStore: IKeyToken;
  }): Promise<{ user: any; tokens: any }>;
  handlerRefreshToken(refreshToken: string): Promise<{ user: any; tokens: any }>;
  logout(keyStore: any): Promise<boolean>;
  login(params: {
    email: string;
    password: string;
    refreshToken?: string;
  }): Promise<{ shop: any; tokens: any }>;
  signUp(params: {
    name: string;
    email: string;
    password: string;
  }): Promise<{ shop: any; tokens: any } | { code: number; metadata: null }>;
}

@injectable()
export class AccessService implements IAccessService {
  constructor(
    @inject(TYPES.KeyTokenService) private keyTokenService: KeyTokenService,
    @inject(TYPES.ShopService) private shopService: ShopService
  ) {}

  async handlerRefreshTokenV2({
    refreshToken,
    user,
    keyStore,
  }: {
    refreshToken: string;
    user: any;
    keyStore: IKeyToken;
  }): Promise<{ user: any; tokens: any }> {
    const { userId, email } = user;
    
    if (keyStore.refreshTokensUsed?.includes(refreshToken)) {
      await this.keyTokenService.deleteKeyById(userId);
      throw new ForbiddenError('Something went wrong');
    }

    if (keyStore.refreshToken !== refreshToken) {
      throw new AuthFailureError('Shop not registered 1');
    }

    const foundShop = await this.shopService.findByEmail({ email });
    if (!foundShop) {
      throw new AuthFailureError('Shop not registered 2');
    }

    const tokens = await createTokenPair(
      {
        userId: userId,
        email: email,
      },
      keyStore.publicKey,
      keyStore.privateKey
    );

    await keyStore.updateOne({
      $set: {
        refreshToken: tokens.refreshToken,
      },
      $addToSet: {
        refreshTokensUsed: refreshToken,
      },
    });

    return {
      user,
      tokens,
    };
  }

  async handlerRefreshToken(refreshToken: string): Promise<{ user: any; tokens: any }> {
    const foundToken = await this.keyTokenService.findByRefreshTokenUsed(refreshToken);
    
    if (foundToken) {
      const { userId, email } = verifyJWT(refreshToken, foundToken.privateKey);
      console.log({ userId, email });

      await this.keyTokenService.deleteKeyById(foundToken.user.toString());
      throw new ForbiddenError('Something went wrong');
    }

    const holderToken = await this.keyTokenService.findByRefreshToken(refreshToken);
    if (!holderToken) {
      throw new AuthFailureError('Shop not registered 1');
    }

    const { userId, email } = verifyJWT(refreshToken, holderToken.privateKey);

    const foundShop = await this.shopService.findByEmail({ email });
    if (!foundShop) {
      throw new AuthFailureError('Shop not registered 2');
    }

    const tokens = await createTokenPair(
      {
        userId: userId,
        email: email,
      },
      holderToken.publicKey,
      holderToken.privateKey
    );

    await holderToken.updateOne({
      $set: {
        refreshToken: tokens.refreshToken,
      },
      $addToSet: {
        refreshTokensUsed: refreshToken,
      },
    });

    return {
      user: {
        userId,
        email,
      },
      tokens,
    };
  }

  async logout(keyStore: any): Promise<boolean> {
    const delKey = await this.keyTokenService.removeKeyById(keyStore);
    return delKey !== null;
  }

  async login({
    email,
    password,
    refreshToken,
  }: {
    email: string;
    password: string;
    refreshToken?: string;
  }): Promise<{ shop: any; tokens: any }> {
    const foundShop = await this.shopService.findByEmail({ email });
    if (!foundShop) {
      throw new BadRequestError('Shop not found!');
    }

    const match = await bcrypt.compare(password, foundShop.password);
    if (!match) {
      throw new AuthFailureError('Authentication error');
    }

    const privateKey = crypto.randomBytes(64).toString('hex');
    const publicKey = crypto.randomBytes(64).toString('hex');
    const userId = foundShop._id.toString();

    const tokens = await createTokenPair(
      {
        userId: userId,
        email: foundShop.email,
      },
      publicKey,
      privateKey
    );

    await this.keyTokenService.createKeyToken({
      userId: userId,
      publicKey: publicKey,
      privateKey: privateKey,
      refreshToken: tokens.refreshToken,
    });

    return {
      shop: getInfoData({
        fields: ['_id', 'name', 'email', 'createdAt'],
        object: foundShop,
      }),
      tokens: tokens,
    };
  }

  async signUp({
    name,
    email,
    password,
  }: {
    name: string;
    email: string;
    password: string;
  }): Promise<{ shop: any; tokens: any } | { code: number; metadata: null }> {
    const holderShop = await shopModel.findOne({ email }).lean();
    if (holderShop) {
      throw new BadRequestError('Error: Shop already existed!');
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const newShop = await shopModel.create({
      name: name,
      email: email,
      password: passwordHash,
      roles: [RoleShop.SHOP],
    });

    if (newShop) {
      const privateKey = crypto.randomBytes(64).toString('hex');
      const publicKey = crypto.randomBytes(64).toString('hex');

      const keyStore = await this.keyTokenService.createKeyToken({
        userId: newShop._id.toString(),
        publicKey: publicKey,
        privateKey: privateKey,
        refreshToken: '',
      });

      if (!keyStore) {
        throw new BadRequestError('Error: Failed to create key token!');
      }

      const tokens = await createTokenPair(
        {
          userId: newShop._id.toString(),
          email: newShop.email,
        },
        publicKey,
        privateKey
      );

      await this.keyTokenService.createKeyToken({
        userId: newShop._id.toString(),
        publicKey: publicKey,
        privateKey: privateKey,
        refreshToken: tokens.refreshToken,
      });

      return {
        shop: getInfoData({
          fields: ['_id', 'name', 'email', 'createdAt'],
          object: newShop,
        }),
        tokens: tokens,
      };
    }

    return {
      code: 201,
      metadata: null,
    };
  }
}
