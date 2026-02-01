import express, { Router } from 'express';
import { apiKey, permission } from '../auth/checkAuth';
import accessRouter from './access';
import productRouter from './product';

const router: Router = express.Router();

router.use(apiKey);
router.use(permission('0000'));

router.use('/v1/api/auth', accessRouter);
router.use('/v1/api/product', productRouter);

export default router;
