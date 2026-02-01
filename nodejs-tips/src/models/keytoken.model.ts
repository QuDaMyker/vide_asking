import mongoose, { Document, Schema, Model, Types } from 'mongoose';

export interface IKeyToken extends Document {
  user: Types.ObjectId;
  publicKey: string;
  privateKey: string;
  refreshTokensUsed: string[];
  refreshToken: string;
  createdAt: Date;
  updatedAt: Date;
}

const DOCUMENT_NAME = 'Key';
const COLLECTION_NAME = 'Keys';

const keyTokenSchema = new Schema<IKeyToken>(
  {
    user: {
      type: Schema.Types.ObjectId,
      required: true,
      ref: 'Shop',
    },
    publicKey: {
      type: String,
      required: true,
      trim: true,
    },
    privateKey: {
      type: String,
      required: true,
      trim: true,
    },
    refreshTokensUsed: {
      type: [String],
      default: [],
    },
    refreshToken: {
      type: String,
      required: true,
    },
  },
  {
    collection: COLLECTION_NAME,
    timestamps: true,
  }
);

export const keytokenModel: Model<IKeyToken> = mongoose.model<IKeyToken>(
  DOCUMENT_NAME,
  keyTokenSchema
);
