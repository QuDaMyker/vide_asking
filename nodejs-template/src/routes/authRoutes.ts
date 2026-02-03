import { Router } from 'express';
import { AuthController } from '../controllers/authController';
import { registerValidation, loginValidation } from '../validators/authValidator';
import { validateRequest } from '../middleware/validateRequest';
import { authenticate } from '../middleware/authenticate';

import { authLimiter } from '../middleware/rateLimiter';

const router = Router();
const authController = new AuthController();

// Public routes
router.post('/register', authLimiter, registerValidation, validateRequest, authController.register);
router.post('/login', authLimiter, loginValidation, validateRequest, authController.login);
router.post('/refresh-token', authController.refreshToken);

// Protected routes
router.get('/profile', authenticate, authController.getProfile);

export default router;
