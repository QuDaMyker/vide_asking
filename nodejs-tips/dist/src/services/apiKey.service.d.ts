import { IApiKey } from '../models/apiKey.model';
export interface IApiKeyService {
    findById(key: string): Promise<IApiKey | null>;
}
export declare class ApiKeyService implements IApiKeyService {
    findById(key: string): Promise<IApiKey | null>;
}
//# sourceMappingURL=apiKey.service.d.ts.map