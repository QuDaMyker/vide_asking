import { IShop } from '../models/shop.model';
export interface IShopService {
    findByEmail(params: {
        email: string;
        select?: any;
    }): Promise<IShop | null>;
}
export declare class ShopService implements IShopService {
    findByEmail({ email, select, }: {
        email: string;
        select?: any;
    }): Promise<IShop | null>;
}
//# sourceMappingURL=shop.service.d.ts.map