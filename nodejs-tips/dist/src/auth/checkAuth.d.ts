import { Request, Response, NextFunction } from 'express';
import { IApiKey } from '../models/apiKey.model';
export interface ApiKeyRequest extends Request {
    objKey?: IApiKey;
}
export declare const apiKey: (req: ApiKeyRequest, res: Response, next: NextFunction) => Promise<void | Response<any, Record<string, any>>>;
export declare const permission: (requiredPermission: string) => (req: ApiKeyRequest, res: Response, next: NextFunction) => void | Response<any, Record<string, any>>;
//# sourceMappingURL=checkAuth.d.ts.map