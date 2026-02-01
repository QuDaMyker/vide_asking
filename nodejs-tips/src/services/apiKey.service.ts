import { injectable } from 'inversify';
import { apiKeyModel, IApiKey } from '../models/apiKey.model';

export interface IApiKeyService {
  findById(key: string): Promise<IApiKey | null>;
}

@injectable()
export class ApiKeyService implements IApiKeyService {
  async findById(key: string): Promise<IApiKey | null> {
    // Uncomment to create a new API key for testing
    // const newKey = await apiKeyModel.create({
    //     key: crypto.randomBytes(64).toString('hex'),
    //     status: true,
    //     permissions: ['0000']
    // })
    const objKey = await apiKeyModel.findOne({ key, status: true }).lean();
    return objKey;
  }
}
