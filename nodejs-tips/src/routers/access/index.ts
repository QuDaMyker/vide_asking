import express, { Router } from 'express';
import { container } from '../../di/container';
import { AccessController } from '../../controllers/access.controller';
import { asyncHandler } from '../../helpers/asyncHandler';
import { authenticationV2 } from '../../auth/authUtils';
import { TYPES } from '../../di/types';

const router: Router = express.Router();
const accessController = container.get<AccessController>(TYPES.AccessController);

router.post('/signup', asyncHandler(accessController.signUp.bind(accessController)));
router.post('/login', asyncHandler(accessController.login.bind(accessController)));

router.use(authenticationV2);

router.post('/logout', asyncHandler(accessController.logout.bind(accessController)));
router.post('/handlerRefreshToken', asyncHandler(accessController.handleRefreshToken.bind(accessController)));

export default router;
