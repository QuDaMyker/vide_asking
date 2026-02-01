import mongoose, { Document, Schema, Model } from 'mongoose';

export interface IApiKey extends Document {
  key: string;
  status: boolean;
  permissions: string[];
  createdAt: Date;
  updatedAt: Date;
}

const DOCUMENT_NAME = 'Apikey';
const COLLECTION_NAME = 'Apikeys';

const apiKeySchema = new Schema<IApiKey>(
  {
    key: {
      type: String,
      required: true,
      unique: true,
    },
    status: {
      type: Boolean,
      default: true,
    },
    permissions: {
      type: [String],
      required: true,
      enum: ['0000', '1111', '2222'],
    },
  },
  {
    timestamps: true,
    collection: COLLECTION_NAME,
  }
);

export const apiKeyModel: Model<IApiKey> = mongoose.model<IApiKey>(DOCUMENT_NAME, apiKeySchema);
