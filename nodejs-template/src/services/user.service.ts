import { injectable, inject } from 'tsyringe';
import { UserRepository } from '../repositories/user.repository';
import { User, NewUser } from '../db/schema';
import { AppError } from '../middlewares/error.middleware';

@injectable()
export class UserService {
  constructor(
    @inject('UserRepository') private userRepository: UserRepository,
  ) {}

  async getAllUsers(): Promise<Omit<User, 'password'>[]> {
    const users = await this.userRepository.findAll();
    return users.map(({ password, ...user }) => user);
  }

  async getUserById(id: number): Promise<Omit<User, 'password'>> {
    const user = await this.userRepository.findById(id);
    if (!user) {
      throw new AppError('User not found', 404);
    }

    const { password, ...userWithoutPassword } = user;
    return userWithoutPassword;
  }

  async updateUser(
    id: number,
    userData: Partial<NewUser>,
  ): Promise<Omit<User, 'password'>> {
    const user = await this.userRepository.update(id, userData);
    if (!user) {
      throw new AppError('User not found', 404);
    }

    const { password, ...userWithoutPassword } = user;
    return userWithoutPassword;
  }

  async deleteUser(id: number): Promise<void> {
    const deleted = await this.userRepository.delete(id);
    if (!deleted) {
      throw new AppError('User not found', 404);
    }
  }
}
