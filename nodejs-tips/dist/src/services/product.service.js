"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ProductService = void 0;
const inversify_1 = require("inversify");
const error_response_1 = require("../core/error.response");
const product_model_1 = require("../models/product.model");
const mongoose_1 = require("mongoose");
const product_repo_1 = require("../models/repositories/product.repo");
const types_1 = require("../di/types");
let ProductService = class ProductService {
    constructor(productRepository) {
        this.productRepository = productRepository;
    }
    async createProduct(type, payload) {
        switch (type) {
            case 'Electronic':
                return await new Electronic(payload).createProduct();
            case 'Clothing':
                return await new Clothing(payload).createProduct();
            default:
                throw new error_response_1.BadRequestError('Invalid type product');
        }
    }
    async findAllDraftsForShop({ product_shop }) {
        const query = { product_shop: new mongoose_1.Types.ObjectId(product_shop), isDraft: true };
        return await this.productRepository.findAllDraftsForShop({ query, limit: 50, skip: 0 });
    }
    async findAllPublishForShop({ product_shop }) {
        const query = { product_shop: new mongoose_1.Types.ObjectId(product_shop), isPublish: true };
        return await this.productRepository.findAllPublishForShop({ query, limit: 50, skip: 0 });
    }
    async publishProductByShop({ product_shop, product_id, }) {
        return await this.productRepository.publishProductByShop({ product_shop, product_id });
    }
    async unPublishProductByShop({ product_shop, product_id, }) {
        return await this.productRepository.unPublishProductByShop({ product_shop, product_id });
    }
};
exports.ProductService = ProductService;
exports.ProductService = ProductService = __decorate([
    (0, inversify_1.injectable)(),
    __param(0, (0, inversify_1.inject)(types_1.TYPES.ProductRepository)),
    __metadata("design:paramtypes", [product_repo_1.ProductRepository])
], ProductService);
class Product {
    constructor({ product_name, product_thumb, product_description, product_price, product_quantity, product_type, product_shop, product_attributes, }) {
        this.product_name = product_name;
        this.product_thumb = product_thumb;
        this.product_description = product_description;
        this.product_price = product_price;
        this.product_quantity = product_quantity;
        this.product_type = product_type;
        this.product_shop = product_shop;
        this.product_attributes = product_attributes;
    }
    async createProduct(product_id) {
        const productData = {
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
        return await product_model_1.product.create(productData);
    }
}
class Clothing extends Product {
    async createProduct() {
        const newClothing = await product_model_1.clothing.create({
            ...this.product_attributes,
            product_shop: this.product_shop,
        });
        if (!newClothing)
            throw new error_response_1.BadRequestError('Create new Clothing error');
        const newProduct = await super.createProduct(newClothing._id);
        if (!newProduct)
            throw new error_response_1.BadRequestError('Create new Product error');
        return newProduct;
    }
}
class Electronic extends Product {
    async createProduct() {
        const newElectronic = await product_model_1.electronic.create({
            ...this.product_attributes,
            product_shop: this.product_shop,
        });
        if (!newElectronic)
            throw new error_response_1.BadRequestError('Create new Electronic error');
        const newProduct = await super.createProduct(newElectronic._id);
        if (!newProduct)
            throw new error_response_1.BadRequestError('Create new Product error');
        return newProduct;
    }
}
//# sourceMappingURL=product.service.js.map