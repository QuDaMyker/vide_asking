import { IKeyToken } from '../models/keytoken.model';
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
export declare class KeyTokenService implements IKeyTokenService {
    createKeyToken({ userId, publicKey, privateKey, refreshToken, }: {
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
//# sourceMappingURL=keyToken.service.d.ts.map