import { injectable, inject } from 'inversify';
import { Request, Response, NextFunction } from 'express';
import { CREATED, SuccessResponse } from '../core/success.response';
import { AccessService } from '../services/access.service';
import { TYPES } from '../di/types';
import { AuthRequest } from '../auth/authUtils';

@injectable()
export class AccessController {
  constructor(
    @inject(TYPES.AccessService) private accessService: AccessService
  ) {}

  handleRefreshToken = async (req: AuthRequest, res: Response, next: NextFunction) => {
    return new SuccessResponse({
      message: 'Get token success',
      metadata: await this.accessService.handlerRefreshTokenV2({
        refreshToken: req.refreshToken!,
        user: req.user,
        keyStore: req.keyStore!,
      }),
    }).send(res);
  };

  logout = async (req: AuthRequest, res: Response, next: NextFunction) => {
    return new SuccessResponse({
      message: 'Logout success',
      metadata: await this.accessService.logout(req.keyStore),
    }).send(res);
  };

  login = async (req: Request, res: Response, next: NextFunction) => {
    try {
      return new SuccessResponse({
        message: 'Login ok',
        metadata: await this.accessService.login(req.body),
      }).send(res);
    } catch (error) {
      next(error);
    }
  };

  signUp = async (req: Request, res: Response, next: NextFunction) => {
    try {
      console.log(`[P]::signUp::`, req.body);
      return new CREATED({
        message: 'Registered OK!',
        metadata: await this.accessService.signUp(req.body),
        options: {
          limit: 10,
        },
      }).send(res);
    } catch (err) {
      next(err);
    }
  };
}
