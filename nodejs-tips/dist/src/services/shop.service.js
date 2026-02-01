"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ShopService = void 0;
const inversify_1 = require("inversify");
const shop_model_1 = require("../models/shop.model");
let ShopService = class ShopService {
    async findByEmail({ email, select = {
        email: 1,
        password: 1,
        name: 1,
        status: 1,
        roles: 1,
    }, }) {
        return await shop_model_1.shopModel.findOne({ email }).select(select).lean();
    }
};
exports.ShopService = ShopService;
exports.ShopService = ShopService = __decorate([
    (0, inversify_1.injectable)()
], ShopService);
//# sourceMappingURL=shop.service.js.map