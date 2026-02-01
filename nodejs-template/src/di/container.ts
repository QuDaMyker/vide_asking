import 'reflect-metadata';
import { container as tsyringeContainer } from 'tsyringe';
import { DatabaseService } from '../services/database.service';
import { UserService } from '../services/user.service';
import { AuthService } from '../services/auth.service';
import { UserRepository } from '../repositories/user.repository';
import { UserController } from '../controllers/user.controller';
import { AuthController } from '../controllers/auth.controller';
import { App } from '../app';

// Register services
tsyringeContainer.register('DatabaseService', {
  useClass: DatabaseService,
});

tsyringeContainer.register('UserRepository', {
  useClass: UserRepository,
});

tsyringeContainer.register('UserService', {
  useClass: UserService,
});

tsyringeContainer.register('AuthService', {
  useClass: AuthService,
});

tsyringeContainer.register('UserController', {
  useClass: UserController,
});

tsyringeContainer.register('AuthController', {
  useClass: AuthController,
});

tsyringeContainer.register('App', {
  useClass: App,
});

export const container = tsyringeContainer;
