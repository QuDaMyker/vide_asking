import { Request, Response, NextFunction } from 'express';
import { IKeyToken } from '../models/keytoken.model';
export interface TokenPayload {
    userId: string;
    email: string;
}
export interface AuthRequest extends Request {
    keyStore?: IKeyToken;
    user?: any;
    refreshToken?: string;
}
export declare const createTokenPair: (payload: TokenPayload, publicKey: string, privateKey: string) => Promise<{
    accessToken: string;
    refreshToken: string;
}>;
export declare const authentication: (req: Request, res: Response, next: NextFunction) => void;
export declare const authenticationV2: (req: Request, res: Response, next: NextFunction) => void;
export declare const verifyJWT: (token: string, keySecret: string) => any;
//# sourceMappingURL=authUtils.d.ts.map