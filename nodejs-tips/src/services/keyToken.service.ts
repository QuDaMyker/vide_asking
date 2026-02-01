import { injectable } from 'inversify';
import { Types } from 'mongoose';
import { keytokenModel, IKeyToken } from '../models/keytoken.model';

export interface IKeyTokenService {
  createKeyToken(params: {
    userId: string;
    publicKey: string;
    privateKey: string;
    refreshToken: string;
  }): Promise<string | null>;
  findByUserId(userId: string): Promise<IKeyToken | null>;
  removeKeyById(id: any): Promise<any>;
  findByRefreshTokenUsed(refreshToken: string): Promise<IKeyToken | null>;
  findByRefreshToken(refreshToken: string): Promise<IKeyToken | null>;
  deleteKeyById(userId: string): Promise<IKeyToken | null>;
}

@injectable()
export class KeyTokenService implements IKeyTokenService {
  async createKeyToken({
    userId,
    publicKey,
    privateKey,
    refreshToken,
  }: {
    userId: string;
    publicKey: string;
    privateKey: string;
    refreshToken: string;
  }): Promise<string | null> {
    try {
      const filter = { user: userId };
      const update = {
        publicKey,
        privateKey,
        refreshTokensUsed: [],
        refreshToken,
      };
      const options = { upsert: true, new: true };
      
      const tokens = await keytokenModel.findOneAndUpdate(filter, update, options);
      return tokens ? tokens.publicKey : null;
    } catch (error) {
      console.log(error);
      throw error;
    }
  }

  async findByUserId(userId: string): Promise<IKeyToken | null> {
    return await keytokenModel.findOne({ user: new Types.ObjectId(userId) });
  }

  async removeKeyById(id: any): Promise<any> {
    return await keytokenModel.deleteOne(id);
  }

  async findByRefreshTokenUsed(refreshToken: string): Promise<IKeyToken | null> {
    return await keytokenModel.findOne({ refreshTokensUsed: refreshToken }).lean();
  }

  async findByRefreshToken(refreshToken: string): Promise<IKeyToken | null> {
    return await keytokenModel.findOne({ refreshToken: refreshToken });
  }

  async deleteKeyById(userId: string): Promise<IKeyToken | null> {
    return await keytokenModel.findByIdAndDelete({ user: userId }).lean();
  }
}
