import { IProduct } from '../models/product.model';
import { Types } from 'mongoose';
import { ProductRepository } from '../models/repositories/product.repo';
interface ProductPayload {
    product_name: string;
    product_thumb: string;
    product_description?: string;
    product_price: number;
    product_quantity: number;
    product_type: 'Electronic' | 'Clothing' | 'Furniture';
    product_shop: Types.ObjectId;
    product_attributes: any;
}
export declare class ProductService {
    private productRepository;
    constructor(productRepository: ProductRepository);
    createProduct(type: string, payload: ProductPayload): Promise<IProduct>;
    findAllDraftsForShop({ product_shop }: {
        product_shop: string;
    }): Promise<IProduct[]>;
    findAllPublishForShop({ product_shop }: {
        product_shop: string;
    }): Promise<IProduct[]>;
    publishProductByShop({ product_shop, product_id, }: {
        product_shop: string;
        product_id: string;
    }): Promise<number | null>;
    unPublishProductByShop({ product_shop, product_id, }: {
        product_shop: string;
        product_id: string;
    }): Promise<number | null>;
}
export {};
//# sourceMappingURL=product.service.d.ts.map