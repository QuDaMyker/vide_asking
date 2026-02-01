import { Document, Model, Types } from 'mongoose';
export interface IProduct extends Document {
    product_name: string;
    product_thumb: string;
    product_description?: string;
    product_slug?: string;
    product_price: number;
    product_quantity: number;
    product_type: 'Electronic' | 'Clothing' | 'Furniture';
    product_shop: Types.ObjectId;
    product_attributes: any;
    product_ratingsAverage: number;
    product_variantions: any[];
    isDraft: boolean;
    isPublish: boolean;
    createdAt: Date;
    updatedAt: Date;
}
export interface IClothing extends Document {
    brand: string;
    size?: string;
    material?: string;
    product_shop: Types.ObjectId;
    createdAt: Date;
    updatedAt: Date;
}
export interface IElectronic extends Document {
    manufacturer: string;
    modelName?: string;
    color?: string;
    product_shop: Types.ObjectId;
    createdAt: Date;
    updatedAt: Date;
}
export interface IFurniture extends Document {
    brand: string;
    size?: string;
    material?: string;
    product_shop: Types.ObjectId;
    createdAt: Date;
    updatedAt: Date;
}
export declare const product: Model<IProduct>;
export declare const clothing: Model<IClothing>;
export declare const electronic: Model<IElectronic>;
export declare const furniture: Model<IFurniture>;
//# sourceMappingURL=product.model.d.ts.map