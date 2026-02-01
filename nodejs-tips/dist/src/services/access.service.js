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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AccessService = exports.RoleShop = void 0;
const inversify_1 = require("inversify");
const shop_model_1 = require("../models/shop.model");
const bcrypt_1 = __importDefault(require("bcrypt"));
const crypto_1 = __importDefault(require("crypto"));
const keyToken_service_1 = require("./keyToken.service");
const authUtils_1 = require("../auth/authUtils");
const utils_1 = require("../utils");
const error_response_1 = require("../core/error.response");
const shop_service_1 = require("./shop.service");
const types_1 = require("../di/types");
exports.RoleShop = {
    SHOP: 'SHOP',
    WRITER: 'WRITER',
    EDITOR: 'EDITOR',
    ADMIN: 'ADMIN',
};
let AccessService = class AccessService {
    constructor(keyTokenService, shopService) {
        this.keyTokenService = keyTokenService;
        this.shopService = shopService;
    }
    async handlerRefreshTokenV2({ refreshToken, user, keyStore, }) {
        const { userId, email } = user;
        if (keyStore.refreshTokensUsed?.includes(refreshToken)) {
            await this.keyTokenService.deleteKeyById(userId);
            throw new error_response_1.ForbiddenError('Something went wrong');
        }
        if (keyStore.refreshToken !== refreshToken) {
            throw new error_response_1.AuthFailureError('Shop not registered 1');
        }
        const foundShop = await this.shopService.findByEmail({ email });
        if (!foundShop) {
            throw new error_response_1.AuthFailureError('Shop not registered 2');
        }
        const tokens = await (0, authUtils_1.createTokenPair)({
            userId: userId,
            email: email,
        }, keyStore.publicKey, keyStore.privateKey);
        await keyStore.updateOne({
            $set: {
                refreshToken: tokens.refreshToken,
            },
            $addToSet: {
                refreshTokensUsed: refreshToken,
            },
        });
        return {
            user,
            tokens,
        };
    }
    async handlerRefreshToken(refreshToken) {
        const foundToken = await this.keyTokenService.findByRefreshTokenUsed(refreshToken);
        if (foundToken) {
            const { userId, email } = (0, authUtils_1.verifyJWT)(refreshToken, foundToken.privateKey);
            console.log({ userId, email });
            await this.keyTokenService.deleteKeyById(foundToken.user.toString());
            throw new error_response_1.ForbiddenError('Something went wrong');
        }
        const holderToken = await this.keyTokenService.findByRefreshToken(refreshToken);
        if (!holderToken) {
            throw new error_response_1.AuthFailureError('Shop not registered 1');
        }
        const { userId, email } = (0, authUtils_1.verifyJWT)(refreshToken, holderToken.privateKey);
        const foundShop = await this.shopService.findByEmail({ email });
        if (!foundShop) {
            throw new error_response_1.AuthFailureError('Shop not registered 2');
        }
        const tokens = await (0, authUtils_1.createTokenPair)({
            userId: userId,
            email: email,
        }, holderToken.publicKey, holderToken.privateKey);
        await holderToken.updateOne({
            $set: {
                refreshToken: tokens.refreshToken,
            },
            $addToSet: {
                refreshTokensUsed: refreshToken,
            },
        });
        return {
            user: {
                userId,
                email,
            },
            tokens,
        };
    }
    async logout(keyStore) {
        const delKey = await this.keyTokenService.removeKeyById(keyStore);
        return delKey !== null;
    }
    async login({ email, password, refreshToken, }) {
        const foundShop = await this.shopService.findByEmail({ email });
        if (!foundShop) {
            throw new error_response_1.BadRequestError('Shop not found!');
        }
        const match = await bcrypt_1.default.compare(password, foundShop.password);
        if (!match) {
            throw new error_response_1.AuthFailureError('Authentication error');
        }
        const privateKey = crypto_1.default.randomBytes(64).toString('hex');
        const publicKey = crypto_1.default.randomBytes(64).toString('hex');
        const userId = foundShop._id.toString();
        const tokens = await (0, authUtils_1.createTokenPair)({
            userId: userId,
            email: foundShop.email,
        }, publicKey, privateKey);
        await this.keyTokenService.createKeyToken({
            userId: userId,
            publicKey: publicKey,
            privateKey: privateKey,
            refreshToken: tokens.refreshToken,
        });
        return {
            shop: (0, utils_1.getInfoData)({
                fields: ['_id', 'name', 'email', 'createdAt'],
                object: foundShop,
            }),
            tokens: tokens,
        };
    }
    async signUp({ name, email, password, }) {
        const holderShop = await shop_model_1.shopModel.findOne({ email }).lean();
        if (holderShop) {
            throw new error_response_1.BadRequestError('Error: Shop already existed!');
        }
        const passwordHash = await bcrypt_1.default.hash(password, 10);
        const newShop = await shop_model_1.shopModel.create({
            name: name,
            email: email,
            password: passwordHash,
            roles: [exports.RoleShop.SHOP],
        });
        if (newShop) {
            const privateKey = crypto_1.default.randomBytes(64).toString('hex');
            const publicKey = crypto_1.default.randomBytes(64).toString('hex');
            const keyStore = await this.keyTokenService.createKeyToken({
                userId: newShop._id.toString(),
                publicKey: publicKey,
                privateKey: privateKey,
                refreshToken: '',
            });
            if (!keyStore) {
                throw new error_response_1.BadRequestError('Error: Failed to create key token!');
            }
            const tokens = await (0, authUtils_1.createTokenPair)({
                userId: newShop._id.toString(),
                email: newShop.email,
            }, publicKey, privateKey);
            await this.keyTokenService.createKeyToken({
                userId: newShop._id.toString(),
                publicKey: publicKey,
                privateKey: privateKey,
                refreshToken: tokens.refreshToken,
            });
            return {
                shop: (0, utils_1.getInfoData)({
                    fields: ['_id', 'name', 'email', 'createdAt'],
                    object: newShop,
                }),
                tokens: tokens,
            };
        }
        return {
            code: 201,
            metadata: null,
        };
    }
};
exports.AccessService = AccessService;
exports.AccessService = AccessService = __decorate([
    (0, inversify_1.injectable)(),
    __param(0, (0, inversify_1.inject)(types_1.TYPES.KeyTokenService)),
    __param(1, (0, inversify_1.inject)(types_1.TYPES.ShopService)),
    __metadata("design:paramtypes", [keyToken_service_1.KeyTokenService,
        shop_service_1.ShopService])
], AccessService);
//# sourceMappingURL=access.service.js.map