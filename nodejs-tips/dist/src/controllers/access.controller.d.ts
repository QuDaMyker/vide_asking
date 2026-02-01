import { Request, Response, NextFunction } from 'express';
import { AccessService } from '../services/access.service';
import { AuthRequest } from '../auth/authUtils';
export declare class AccessController {
    private accessService;
    constructor(accessService: AccessService);
    handleRefreshToken: (req: AuthRequest, res: Response, next: NextFunction) => Promise<Response<any, Record<string, any>>>;
    logout: (req: AuthRequest, res: Response, next: NextFunction) => Promise<Response<any, Record<string, any>>>;
    login: (req: Request, res: Response, next: NextFunction) => Promise<Response<any, Record<string, any>> | undefined>;
    signUp: (req: Request, res: Response, next: NextFunction) => Promise<Response<any, Record<string, any>> | undefined>;
}
//# sourceMappingURL=access.controller.d.ts.map