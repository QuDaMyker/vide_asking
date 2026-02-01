import { Document, Model, Types } from 'mongoose';
export interface IKeyToken extends Document {
    user: Types.ObjectId;
    publicKey: string;
    privateKey: string;
    refreshTokensUsed: string[];
    refreshToken: string;
    createdAt: Date;
    updatedAt: Date;
}
export declare const keytokenModel: Model<IKeyToken>;
//# sourceMappingURL=keytoken.model.d.ts.map