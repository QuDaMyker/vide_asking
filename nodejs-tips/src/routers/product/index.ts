import express, { Router } from 'express';
import { container } from '../../di/container';
import { ProductController } from '../../controllers/product.controller';
import { asyncHandler } from '../../helpers/asyncHandler';
import { authentication } from '../../auth/authUtils';
import { TYPES } from '../../di/types';

const router: Router = express.Router();
const productController = container.get<ProductController>(TYPES.ProductController);

router.use(authentication);

router.post('', asyncHandler(productController.createProduct.bind(productController)));
router.post('/publish/:id', asyncHandler(productController.publishProductByShop.bind(productController)));
router.post('/unpublish/:id', asyncHandler(productController.unPublishProductByShop.bind(productController)));

router.get('/drafts/all', asyncHandler(productController.getAllDraftsForShop.bind(productController)));
router.get('/publishs/all', asyncHandler(productController.getAllPublishForShop.bind(productController)));

export default router;
