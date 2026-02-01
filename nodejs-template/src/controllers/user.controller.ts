import { Response, NextFunction } from 'express';
import { injectable, inject } from 'tsyringe';
import { UserService } from '../services/user.service';
import { AuthRequest } from '../middlewares/auth.middleware';

@injectable()
export class UserController {
  constructor(
    @inject('UserService') private userService: UserService,
  ) {}

  getAllUsers = async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
      const users = await this.userService.getAllUsers();
      res.status(200).json({
        success: true,
        data: users,
      });
    } catch (error) {
      next(error);
    }
  };

  getUserById = async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
      const id = parseInt(req.params.id.toString(), 10);
      const user = await this.userService.getUserById(id);
      res.status(200).json({
        success: true,
        data: user,
      });
    } catch (error) {
      next(error);
    }
  };

  updateUser = async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
      const id = parseInt(req.params.id.toString(), 10);
      const user = await this.userService.updateUser(id, req.body);
      res.status(200).json({
        success: true,
        message: 'User updated successfully',
        data: user,
      });
    } catch (error) {
      next(error);
    }
  };

  deleteUser = async (req: AuthRequest, res: Response, next: NextFunction) => {
    try {
      const id = parseInt(req.params.id.toString(), 10);
      await this.userService.deleteUser(id);
      res.status(200).json({
        success: true,
        message: 'User deleted successfully',
      });
    } catch (error) {
      next(error);
    }
  };
}
