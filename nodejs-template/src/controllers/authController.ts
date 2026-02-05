import { Request, Response, NextFunction } from 'express';
import { AuthService } from '../services/authService';
import { AuthRequest } from '../middleware/authenticate';

const authService = new AuthService();

export class AuthController {
  async register(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await authService.register(req.body);
      
      return res.status(201).json({
        status: 'success',
        data: result
      });
    } catch (error) {
      return next(error);
    }
  }

  async login(req: Request, res: Response, next: NextFunction) {
    try {
      const result = await authService.login(req.body);
      
      return res.status(200).json({
        status: 'success',
        data: result
      });
    } catch (error) {
      return next(error);
    }
  }

  async refreshToken(req: Request, res: Response, next: NextFunction) {
    try {
      const { refreshToken } = req.body;
      
      if (!refreshToken) {
        return res.status(400).json({
          status: 'error',
          message: 'Refresh token is required'
        });
      }

      const result = await authService.refreshToken(refreshToken);
      
      return res.status(200).json({
        status: 'success',
        data: result
      });
    } catch (error) {
      return next(error);
    }
  }

  async getProfile(req: AuthRequest, res: Response, next: NextFunction) {
    try {
      const result = await authService.getProfile(req.userId!);
      
      return res.status(200).json({
        status: 'success',
        data: result
      });
    } catch (error) {
      return next(error);
    }
  }
}
