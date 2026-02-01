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
exports.ProductController = void 0;
const inversify_1 = require("inversify");
const success_response_1 = require("../core/success.response");
const product_service_1 = require("../services/product.service");
const types_1 = require("../di/types");
let ProductController = class ProductController {
    constructor(productService) {
        this.productService = productService;
        this.createProduct = async (req, res, next) => {
            return new success_response_1.SuccessResponse({
                message: 'Create Product success',
                metadata: await this.productService.createProduct(req.body.product_type, {
                    ...req.body,
                    product_shop: req.user.userId,
                }),
            }).send(res);
        };
        this.getAllDraftsForShop = async (req, res, next) => {
            return new success_response_1.SuccessResponse({
                message: 'Get All Drafts For Shop Success',
                metadata: await this.productService.findAllDraftsForShop({
                    product_shop: req.user.userId,
                }),
            }).send(res);
        };
        this.getAllPublishForShop = async (req, res, next) => {
            return new success_response_1.SuccessResponse({
                message: 'Get All Published For Shop Success',
                metadata: await this.productService.findAllPublishForShop({
                    product_shop: req.user.userId,
                }),
            }).send(res);
        };
        this.publishProductByShop = async (req, res, next) => {
            return new success_response_1.SuccessResponse({
                message: 'Publish Product Success',
                metadata: await this.productService.publishProductByShop({
                    product_shop: req.user.userId,
                    product_id: req.params.id,
                }),
            }).send(res);
        };
        this.unPublishProductByShop = async (req, res, next) => {
            return new success_response_1.SuccessResponse({
                message: 'UnPublish Product Success',
                metadata: await this.productService.unPublishProductByShop({
                    product_shop: req.user.userId,
                    product_id: req.params.id,
                }),
            }).send(res);
        };
    }
};
exports.ProductController = ProductController;
exports.ProductController = ProductController = __decorate([
    (0, inversify_1.injectable)(),
    __param(0, (0, inversify_1.inject)(types_1.TYPES.ProductService)),
    __metadata("design:paramtypes", [product_service_1.ProductService])
], ProductController);
//# sourceMappingURL=product.controller.js.map