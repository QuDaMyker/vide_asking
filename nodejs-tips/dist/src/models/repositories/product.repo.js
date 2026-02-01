"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ProductRepository = void 0;
const inversify_1 = require("inversify");
const mongoose_1 = require("mongoose");
const product_model_1 = require("../product.model");
const utils_1 = require("../../utils");
let ProductRepository = class ProductRepository {
    async findAllDraftsForShop({ query, limit, skip }) {
        return await product_model_1.product
            .find(query)
            .populate('product_shop', 'name email -_id')
            .sort({ updatedAt: -1 })
            .skip(skip)
            .limit(limit)
            .lean()
            .exec();
    }
    async findAllPublishForShop({ query, limit, skip }) {
        return await product_model_1.product
            .find(query)
            .populate('product_shop', 'name email -_id')
            .sort({ updatedAt: -1 })
            .skip(skip)
            .limit(limit)
            .lean()
            .exec();
    }
    async publishProductByShop({ product_shop, product_id, }) {
        const foundShop = await product_model_1.product.findOne({
            product_shop: new mongoose_1.Types.ObjectId(product_shop),
            _id: new mongoose_1.Types.ObjectId(product_id),
        });
        if (!foundShop)
            return null;
        foundShop.isDraft = false;
        foundShop.isPublish = true;
        const { modifiedCount } = await foundShop.updateOne(foundShop);
        return modifiedCount;
    }
    async unPublishProductByShop({ product_shop, product_id, }) {
        const foundShop = await product_model_1.product.findOne({
            product_shop: new mongoose_1.Types.ObjectId(product_shop),
            _id: new mongoose_1.Types.ObjectId(product_id),
        });
        if (!foundShop)
            return null;
        foundShop.isDraft = true;
        foundShop.isPublish = false;
        const { modifiedCount } = await foundShop.updateOne(foundShop);
        return modifiedCount;
    }
    async searchProduct({ keySearch }) {
        const regexSearch = new RegExp(keySearch);
        const results = await product_model_1.product
            .find({ isPublish: true, $text: { $search: regexSearch.source } }, { score: { $meta: 'textScore' } })
            .sort({ score: { $meta: 'textScore' } })
            .lean()
            .exec();
        return results;
    }
    async findAllProducts({ limit, sort, page, filter, select, }) {
        const skip = (page - 1) * limit;
        const sortBy = sort === 'ctime' ? { _id: -1 } : { _id: 1 };
        const products = await product_model_1.product
            .find(filter)
            .sort(sortBy)
            .skip(skip)
            .limit(limit)
            .select((0, utils_1.getSelectData)(select))
            .lean()
            .exec();
        return products;
    }
    async findProduct({ product_id, unSelect, }) {
        return await product_model_1.product
            .findById(product_id)
            .select((0, utils_1.unGetSelectData)(unSelect))
            .lean()
            .exec();
    }
};
exports.ProductRepository = ProductRepository;
exports.ProductRepository = ProductRepository = __decorate([
    (0, inversify_1.injectable)()
], ProductRepository);
//# sourceMappingURL=product.repo.js.map