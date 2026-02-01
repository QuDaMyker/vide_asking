import mongoose, { Document, Schema, Model } from 'mongoose';

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

const DOCUMENT_NAME = 'Shop';
const COLLECTION_NAME = 'Shops';

const shopSchema = new Schema<IShop>(
  {
    name: {
      type: String,
      required: true,
      unique: true,
      index: true,
      maxLength: 150,
      trim: true,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      trim: true,
    },
    password: {
      type: String,
      required: true,
    },
    status: {
      type: String,
      enum: ['active', 'inactive'],
      default: 'inactive',
    },
    verify: {
      type: Boolean,
      default: false,
    },
    roles: {
      type: [String],
      default: [],
    },
  },
  {
    collection: COLLECTION_NAME,
    timestamps: true,
  }
);

export const shopModel: Model<IShop> = mongoose.model<IShop>(DOCUMENT_NAME, shopSchema);
