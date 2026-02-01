import { injectable } from 'inversify';
import { shopModel, IShop } from '../models/shop.model';

export interface IShopService {
  findByEmail(params: { email: string; select?: any }): Promise<IShop | null>;
}

@injectable()
export class ShopService implements IShopService {
  async findByEmail({
    email,
    select = {
      email: 1,
      password: 1,
      name: 1,
      status: 1,
      roles: 1,
    },
  }: {
    email: string;
    select?: any;
  }): Promise<IShop | null> {
    return await shopModel.findOne({ email }).select(select).lean();
  }
}
