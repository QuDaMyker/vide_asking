import { IProduct } from '../product.model';
interface QueryParams {
    query: any;
    limit: number;
    skip: number;
}
export declare class ProductRepository {
    findAllDraftsForShop({ query, limit, skip }: QueryParams): Promise<IProduct[]>;
    findAllPublishForShop({ query, limit, skip }: QueryParams): Promise<IProduct[]>;
    publishProductByShop({ product_shop, product_id, }: {
        product_shop: string;
        product_id: string;
    }): Promise<number | null>;
    unPublishProductByShop({ product_shop, product_id, }: {
        product_shop: string;
        product_id: string;
    }): Promise<number | null>;
    searchProduct({ keySearch }: {
        keySearch: string;
    }): Promise<IProduct[]>;
    findAllProducts({ limit, sort, page, filter, select, }: {
        limit: number;
        sort: string;
        page: number;
        filter: any;
        select: string[];
    }): Promise<IProduct[]>;
    findProduct({ product_id, unSelect, }: {
        product_id: string;
        unSelect: string[];
    }): Promise<IProduct | null>;
}
export {};
//# sourceMappingURL=product.repo.d.ts.map