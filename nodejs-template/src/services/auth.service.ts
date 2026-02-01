import { injectable, inject } from 'tsyringe';
import jwt from 'jsonwebtoken';
import bcrypt from 'bcrypt';
import { config } from '../config';
import { UserRepository } from '../repositories/user.repository';
import { AppError } from '../middlewares/error.middleware';
import { NewUser } from '../db/schema';

interface AuthTokens {
  accessToken: string;
  refreshToken: string;
}

@injectable()
export class AuthService {
  constructor(
    @inject('UserRepository') private userRepository: UserRepository,
  ) {}

  async register(userData: NewUser): Promise<{ userId: number; tokens: AuthTokens }> {
    const existingUser = await this.userRepository.findByEmail(userData.email);
    if (existingUser) {
      throw new AppError('User already exists', 409);
    }

    const hashedPassword = await bcrypt.hash(userData.password, 10);
    const user = await this.userRepository.create({
      ...userData,
      password: hashedPassword,
    });

    const tokens = this.generateTokens(user.id, user.email);

    return { userId: user.id, tokens };
  }

  async login(email: string, password: string): Promise<{ userId: number; tokens: AuthTokens }> {
    const user = await this.userRepository.findByEmail(email);
    if (!user) {
      throw new AppError('Invalid credentials', 401);
    }

    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
      throw new AppError('Invalid credentials', 401);
    }

    if (!user.isActive) {
      throw new AppError('Account is deactivated', 403);
    }

    const tokens = this.generateTokens(user.id, user.email);

    return { userId: user.id, tokens };
  }

  async refreshToken(refreshToken: string): Promise<AuthTokens> {
    try {
      const decoded = jwt.verify(refreshToken, config.jwt.refreshSecret) as {
        userId: number;
        email: string;
      };

      const user = await this.userRepository.findById(decoded.userId);
      if (!user || !user.isActive) {
        throw new AppError('Invalid refresh token', 401);
      }

      return this.generateTokens(user.id, user.email);
    } catch (error) {
      throw new AppError('Invalid refresh token', 401);
    }
  }

  private generateTokens(userId: number, email: string): AuthTokens {
    const accessToken = jwt.sign({ userId, email }, config.jwt.secret, {
      expiresIn: Number(config.jwt.expiresIn),
    });

    const refreshToken = jwt.sign({ userId, email }, config.jwt.refreshSecret, {
      expiresIn: Number(config.jwt.refreshExpiresIn),
    });

    return { accessToken, refreshToken };
  }
}
