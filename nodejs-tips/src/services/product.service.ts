import { injectable, inject } from 'inversify';
import { BadRequestError } from '../core/error.response';
import { product, clothing, electronic, IProduct } from '../models/product.model';
import { Types } from 'mongoose';
import { ProductRepository } from '../models/repositories/product.repo';
import { TYPES } from '../di/types';

interface ProductPayload {
  product_name: string;
  product_thumb: string;
  product_description?: string;
  product_price: number;
  product_quantity: number;
  product_type: 'Electronic' | 'Clothing' | 'Furniture';
  product_shop: Types.ObjectId;
  product_attributes: any;
}

@injectable()
export class ProductService {
  constructor(
    @inject(TYPES.ProductRepository) private productRepository: ProductRepository
  ) {}

  async createProduct(type: string, payload: ProductPayload): Promise<IProduct> {
    switch (type) {
      case 'Electronic':
        return await new Electronic(payload).createProduct();
      case 'Clothing':
        return await new Clothing(payload).createProduct();
      default:
        throw new BadRequestError('Invalid type product');
    }
  }

  async findAllDraftsForShop({ product_shop }: { product_shop: string }): Promise<IProduct[]> {
    const query = { product_shop: new Types.ObjectId(product_shop), isDraft: true };
    return await this.productRepository.findAllDraftsForShop({ query, limit: 50, skip: 0 });
  }

  async findAllPublishForShop({ product_shop }: { product_shop: string }): Promise<IProduct[]> {
    const query = { product_shop: new Types.ObjectId(product_shop), isPublish: true };
    return await this.productRepository.findAllPublishForShop({ query, limit: 50, skip: 0 });
  }

  async publishProductByShop({
    product_shop,
    product_id,
  }: {
    product_shop: string;
    product_id: string;
  }): Promise<number | null> {
    return await this.productRepository.publishProductByShop({ product_shop, product_id });
  }

  async unPublishProductByShop({
    product_shop,
    product_id,
  }: {
    product_shop: string;
    product_id: string;
  }): Promise<number | null> {
    return await this.productRepository.unPublishProductByShop({ product_shop, product_id });
  }
}

class Product {
  public product_name: string;
  public product_thumb: string;
  public product_description?: string;
  public product_price: number;
  public product_quantity: number;
  public product_type: 'Electronic' | 'Clothing' | 'Furniture';
  public product_shop: Types.ObjectId;
  public product_attributes: any;

  constructor({
    product_name,
    product_thumb,
    product_description,
    product_price,
    product_quantity,
    product_type,
    product_shop,
    product_attributes,
  }: ProductPayload) {
    this.product_name = product_name;
    this.product_thumb = product_thumb;
    this.product_description = product_description;
    this.product_price = product_price;
    this.product_quantity = product_quantity;
    this.product_type = product_type;
    this.product_shop = product_shop;
    this.product_attributes = product_attributes;
  }

  async createProduct(product_id?: Types.ObjectId): Promise<IProduct> {
    const productData: any = {
      product_name: this.product_name,
      product_thumb: this.product_thumb,
      product_description: this.product_description,
      product_price: this.product_price,
      product_quantity: this.product_quantity,
      product_type: this.product_type,
      product_shop: this.product_shop,
      product_attributes: this.product_attributes,
    };
    
    if (product_id) {
      productData.product_id = product_id;
    }
    
    return await product.create(productData);
  }
}

class Clothing extends Product {
  async createProduct(): Promise<IProduct> {
    const newClothing = await clothing.create({
      ...this.product_attributes,
      product_shop: this.product_shop,
    });
    if (!newClothing) throw new BadRequestError('Create new Clothing error');
    
    const newProduct = await super.createProduct(newClothing._id);
    if (!newProduct) throw new BadRequestError('Create new Product error');
    
    return newProduct;
  }
}

class Electronic extends Product {
  async createProduct(): Promise<IProduct> {
    const newElectronic = await electronic.create({
      ...this.product_attributes,
      product_shop: this.product_shop,
    });
    if (!newElectronic) throw new BadRequestError('Create new Electronic error');
    
    const newProduct = await super.createProduct(newElectronic._id);
    if (!newProduct) throw new BadRequestError('Create new Product error');
    
    return newProduct;
  }
}
