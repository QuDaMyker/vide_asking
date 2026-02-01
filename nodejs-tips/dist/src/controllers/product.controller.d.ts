import { Response, NextFunction } from 'express';
import { ProductService } from '../services/product.service';
import { AuthRequest } from '../auth/authUtils';
export declare class ProductController {
    private productService;
    constructor(productService: ProductService);
    createProduct: (req: AuthRequest, res: Response, next: NextFunction) => Promise<Response<any, Record<string, any>>>;
    getAllDraftsForShop: (req: AuthRequest, res: Response, next: NextFunction) => Promise<Response<any, Record<string, any>>>;
    getAllPublishForShop: (req: AuthRequest, res: Response, next: NextFunction) => Promise<Response<any, Record<string, any>>>;
    publishProductByShop: (req: AuthRequest, res: Response, next: NextFunction) => Promise<Response<any, Record<string, any>>>;
    unPublishProductByShop: (req: AuthRequest, res: Response, next: NextFunction) => Promise<Response<any, Record<string, any>>>;
}
//# sourceMappingURL=product.controller.d.ts.map