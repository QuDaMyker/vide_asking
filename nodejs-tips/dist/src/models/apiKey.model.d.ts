import { Document, Model } from 'mongoose';
export interface IApiKey extends Document {
    key: string;
    status: boolean;
    permissions: string[];
    createdAt: Date;
    updatedAt: Date;
}
export declare const apiKeyModel: Model<IApiKey>;
//# sourceMappingURL=apiKey.model.d.ts.map