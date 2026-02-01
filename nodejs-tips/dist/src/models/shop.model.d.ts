import { Document, Model } from 'mongoose';
export interface IShop extends Document {
    name: string;
    email: string;
    password: string;
    status: 'active' | 'inactive';
    verify: boolean;
    roles: string[];
    createdAt: Date;
    updatedAt: Date;
}
export declare const shopModel: Model<IShop>;
//# sourceMappingURL=shop.model.d.ts.map