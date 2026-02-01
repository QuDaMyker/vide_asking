import { injectable } from 'inversify';
import { Types } from 'mongoose';
import { product, clothing, electronic, furniture, IProduct } from '../product.model';
import { getSelectData, unGetSelectData } from '../../utils';

interface QueryParams {
  query: any;
  limit: number;
  skip: number;
}

@injectable()
export class ProductRepository {
  async findAllDraftsForShop({ query, limit, skip }: QueryParams): Promise<IProduct[]> {
    return await product
      .find(query)
      .populate('product_shop', 'name email -_id')
      .sort({ updatedAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean()
      .exec();
  }

  async findAllPublishForShop({ query, limit, skip }: QueryParams): Promise<IProduct[]> {
    return await product
      .find(query)
      .populate('product_shop', 'name email -_id')
      .sort({ updatedAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean()
      .exec();
  }

  async publishProductByShop({
    product_shop,
    product_id,
  }: {
    product_shop: string;
    product_id: string;
  }): Promise<number | null> {
    const foundShop = await product.findOne({
      product_shop: new Types.ObjectId(product_shop),
      _id: new Types.ObjectId(product_id),
    });

    if (!foundShop) return null;

    foundShop.isDraft = false;
    foundShop.isPublish = true;

    const { modifiedCount } = await foundShop.updateOne(foundShop);
    return modifiedCount;
  }

  async unPublishProductByShop({
    product_shop,
    product_id,
  }: {
    product_shop: string;
    product_id: string;
  }): Promise<number | null> {
    const foundShop = await product.findOne({
      product_shop: new Types.ObjectId(product_shop),
      _id: new Types.ObjectId(product_id),
    });

    if (!foundShop) return null;

    foundShop.isDraft = true;
    foundShop.isPublish = false;

    const { modifiedCount } = await foundShop.updateOne(foundShop);
    return modifiedCount;
  }

  async searchProduct({ keySearch }: { keySearch: string }): Promise<IProduct[]> {
    const regexSearch = new RegExp(keySearch);
    const results = await product
      .find(
        { isPublish: true, $text: { $search: regexSearch.source } },
        { score: { $meta: 'textScore' } }
      )
      .sort({ score: { $meta: 'textScore' } })
      .lean()
      .exec();
    return results;
  }

  async findAllProducts({
    limit,
    sort,
    page,
    filter,
    select,
  }: {
    limit: number;
    sort: string;
    page: number;
    filter: any;
    select: string[];
  }): Promise<IProduct[]> {
    const skip = (page - 1) * limit;
    const sortBy = sort === 'ctime' ? { _id: -1 as const } : { _id: 1 as const };
    const products = await product
      .find(filter)
      .sort(sortBy as any)
      .skip(skip)
      .limit(limit)
      .select(getSelectData(select))
      .lean()
      .exec();
    return products;
  }

  async findProduct({
    product_id,
    unSelect,
  }: {
    product_id: string;
    unSelect: string[];
  }): Promise<IProduct | null> {
    return await product
      .findById(product_id)
      .select(unGetSelectData(unSelect))
      .lean()
      .exec();
  }
}
