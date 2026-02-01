import mongoose, { Document, Schema, Model, Types } from 'mongoose';
import slugify from 'slugify';

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

const DOCUMENT_NAME = 'Product';
const COLLECTION_NAME = 'Products';

const productSchema = new Schema<IProduct>(
  {
    product_name: {
      type: String,
      required: true,
    },
    product_thumb: {
      type: String,
      required: true,
    },
    product_description: {
      type: String,
    },
    product_slug: {
      type: String,
    },
    product_price: {
      type: Number,
      required: true,
    },
    product_quantity: {
      type: Number,
      required: true,
    },
    product_type: {
      type: String,
      required: true,
      enum: ['Electronic', 'Clothing', 'Furniture'],
    },
    product_shop: {
      type: Schema.Types.ObjectId,
      ref: 'Shop',
    },
    product_attributes: {
      type: Schema.Types.Mixed,
      required: true,
    },
    product_ratingsAverage: {
      type: Number,
      default: 4.5,
      min: [1, 'Rating must be above 1.0'],
      max: [5, 'Rating must be below 5.0'],
      set: (value: number) => Math.round(value * 10) / 10,
    },
    product_variantions: [Schema.Types.Mixed],
    isDraft: {
      type: Boolean,
      default: true,
      index: true,
      select: false,
    },
    isPublish: {
      type: Boolean,
      default: false,
      index: true,
      select: false,
    },
  },
  {
    timestamps: true,
    collection: COLLECTION_NAME,
  }
);

// Create index for search
productSchema.index({ product_name: 'text', product_description: 'text' });

productSchema.pre('save', function (this: any, next: any) {
  this.product_slug = slugify(this.product_name, { lower: true });
  next();
});

// Clothing Schema
const clothingSchema = new Schema<IClothing>(
  {
    brand: {
      type: String,
      required: true,
    },
    size: String,
    material: String,
    product_shop: { type: Schema.Types.ObjectId, ref: 'Shop' },
  },
  {
    collection: 'Clothes',
    timestamps: true,
  }
);

// Electronic Schema
const electronicSchema = new Schema<IElectronic>(
  {
    manufacturer: {
      type: String,
      required: true,
    },
    modelName: String,
    color: String,
    product_shop: { type: Schema.Types.ObjectId, ref: 'Shop' },
  },
  {
    collection: 'Electronics',
    timestamps: true,
  }
);

// Furniture Schema
const furnitureSchema = new Schema<IFurniture>(
  {
    brand: {
      type: String,
      required: true,
    },
    size: String,
    material: String,
    product_shop: { type: Schema.Types.ObjectId, ref: 'Shop' },
  },
  {
    collection: 'Funitures',
    timestamps: true,
  }
);

// Export models
export const product: Model<IProduct> = mongoose.model<IProduct>(DOCUMENT_NAME, productSchema);
export const clothing: Model<IClothing> = mongoose.model<IClothing>('Clothing', clothingSchema);
export const electronic: Model<IElectronic> = mongoose.model<IElectronic>('Electronic', electronicSchema);
export const furniture: Model<IFurniture> = mongoose.model<IFurniture>('Funitures', furnitureSchema);
