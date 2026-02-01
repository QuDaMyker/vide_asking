import { Router } from 'express';
import { container } from '../di/container';
import { UserController } from '../controllers/user.controller';
import { authenticate } from '../middlewares/auth.middleware';
import { validate } from '../middlewares/validation.middleware';
import { updateUserSchema, getUserSchema } from '../validators/user.validator';

const router = Router();
const userController = container.resolve(UserController);

// All user routes require authentication
router.use(authenticate);

router.get('/', userController.getAllUsers);
router.get('/:id', validate(getUserSchema), userController.getUserById);
router.put('/:id', validate(updateUserSchema), userController.updateUser);
router.delete('/:id', validate(getUserSchema), userController.deleteUser);

export default router;
