"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.KeyTokenService = void 0;
const inversify_1 = require("inversify");
const mongoose_1 = require("mongoose");
const keytoken_model_1 = require("../models/keytoken.model");
let KeyTokenService = class KeyTokenService {
    async createKeyToken({ userId, publicKey, privateKey, refreshToken, }) {
        try {
            const filter = { user: userId };
            const update = {
                publicKey,
                privateKey,
                refreshTokensUsed: [],
                refreshToken,
            };
            const options = { upsert: true, new: true };
            const tokens = await keytoken_model_1.keytokenModel.findOneAndUpdate(filter, update, options);
            return tokens ? tokens.publicKey : null;
        }
        catch (error) {
            console.log(error);
            throw error;
        }
    }
    async findByUserId(userId) {
        return await keytoken_model_1.keytokenModel.findOne({ user: new mongoose_1.Types.ObjectId(userId) });
    }
    async removeKeyById(id) {
        return await keytoken_model_1.keytokenModel.deleteOne(id);
    }
    async findByRefreshTokenUsed(refreshToken) {
        return await keytoken_model_1.keytokenModel.findOne({ refreshTokensUsed: refreshToken }).lean();
    }
    async findByRefreshToken(refreshToken) {
        return await keytoken_model_1.keytokenModel.findOne({ refreshToken: refreshToken });
    }
    async deleteKeyById(userId) {
        return await keytoken_model_1.keytokenModel.findByIdAndDelete({ user: userId }).lean();
    }
};
exports.KeyTokenService = KeyTokenService;
exports.KeyTokenService = KeyTokenService = __decorate([
    (0, inversify_1.injectable)()
], KeyTokenService);
//# sourceMappingURL=keyToken.service.js.map