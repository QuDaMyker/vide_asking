import { injectable, inject } from 'inversify';
import { Request, Response, NextFunction } from 'express';
import { SuccessResponse } from '../core/success.response';
import { ProductService } from '../services/product.service';
import { TYPES } from '../di/types';
import { AuthRequest } from '../auth/authUtils';

@injectable()
export class ProductController {
  constructor(
    @inject(TYPES.ProductService) private productService: ProductService
  ) {}

  createProduct = async (req: AuthRequest, res: Response, next: NextFunction) => {
    return new SuccessResponse({
      message: 'Create Product success',
      metadata: await this.productService.createProduct(req.body.product_type, {
        ...req.body,
        product_shop: req.user.userId,
      }),
    }).send(res);
  };

  /**
   * @description Get All Drafts For Shop
   * @param {Number} limit
   * @param {Number} skip
   * @return { JSON }
   */
  getAllDraftsForShop = async (req: AuthRequest, res: Response, next: NextFunction) => {
    return new SuccessResponse({
      message: 'Get All Drafts For Shop Success',
      metadata: await this.productService.findAllDraftsForShop({
        product_shop: req.user.userId,
      }),
    }).send(res);
  };

  /**
   * @description Get All Published Products For Shop
   * @param {Number} limit
   * @param {Number} skip
   * @return { JSON }
   */
  getAllPublishForShop = async (req: AuthRequest, res: Response, next: NextFunction) => {
    return new SuccessResponse({
      message: 'Get All Published For Shop Success',
      metadata: await this.productService.findAllPublishForShop({
        product_shop: req.user.userId,
      }),
    }).send(res);
  };

  publishProductByShop = async (req: AuthRequest, res: Response, next: NextFunction) => {
    return new SuccessResponse({
      message: 'Publish Product Success',
      metadata: await this.productService.publishProductByShop({
        product_shop: req.user.userId,
        product_id: req.params.id,
      }),
    }).send(res);
  };

  unPublishProductByShop = async (req: AuthRequest, res: Response, next: NextFunction) => {
    return new SuccessResponse({
      message: 'UnPublish Product Success',
      metadata: await this.productService.unPublishProductByShop({
        product_shop: req.user.userId,
        product_id: req.params.id,
      }),
    }).send(res);
  };
}
