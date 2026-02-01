"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyJWT = exports.authenticationV2 = exports.authentication = exports.createTokenPair = void 0;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const asyncHandler_1 = require("../helpers/asyncHandler");
const error_response_1 = require("../core/error.response");
const keyToken_service_1 = require("../services/keyToken.service");
const HEADER = {
    API_KEY: 'x-api-key',
    AUTHORIZATION: 'authorization',
    CLIENT_ID: 'x-client-id',
    REFRESH_TOKEN: 'refreshtoken',
};
const createTokenPair = async (payload, publicKey, privateKey) => {
    try {
        const accessToken = jsonwebtoken_1.default.sign(payload, publicKey, {
            algorithm: 'HS512',
            expiresIn: '2 days',
        });
        const refreshToken = jsonwebtoken_1.default.sign(payload, privateKey, {
            algorithm: 'HS512',
            expiresIn: '7 days',
        });
        jsonwebtoken_1.default.verify(accessToken, publicKey, (err, decode) => {
            if (err) {
                console.log(`error verify::`, err);
            }
            else {
                console.log(`decode verify::`, decode);
            }
        });
        return {
            accessToken,
            refreshToken,
        };
    }
    catch (error) {
        throw error;
    }
};
exports.createTokenPair = createTokenPair;
exports.authentication = (0, asyncHandler_1.asyncHandler)(async (req, res, next) => {
    const userId = req.headers[HEADER.CLIENT_ID];
    if (!userId)
        throw new error_response_1.AuthFailureError('Invalid request');
    const keyTokenService = new keyToken_service_1.KeyTokenService();
    const keyStore = await keyTokenService.findByUserId(userId);
    if (!keyStore)
        throw new error_response_1.NotFoundError('Not found');
    const accessToken = req.headers[HEADER.AUTHORIZATION];
    if (!accessToken)
        throw new error_response_1.AuthFailureError('Invalid request');
    try {
        const decodeUser = jsonwebtoken_1.default.verify(accessToken, keyStore.publicKey);
        if (userId !== decodeUser.userId) {
            throw new error_response_1.AuthFailureError('Invalid user');
        }
        req.keyStore = keyStore;
        req.user = decodeUser;
        next();
    }
    catch (error) {
        console.log(error);
        throw new error_response_1.BadRequestError('Bad request');
    }
});
exports.authenticationV2 = (0, asyncHandler_1.asyncHandler)(async (req, res, next) => {
    const userId = req.headers[HEADER.CLIENT_ID];
    if (!userId)
        throw new error_response_1.AuthFailureError('Invalid request');
    const keyTokenService = new keyToken_service_1.KeyTokenService();
    const keyStore = await keyTokenService.findByUserId(userId);
    if (!keyStore)
        throw new error_response_1.NotFoundError('Not found');
    if (req.headers[HEADER.REFRESH_TOKEN]) {
        try {
            const refreshToken = req.headers[HEADER.REFRESH_TOKEN];
            const decodeUser = jsonwebtoken_1.default.verify(refreshToken, keyStore.privateKey);
            if (userId !== decodeUser.userId) {
                throw new error_response_1.AuthFailureError('Invalid user');
            }
            req.keyStore = keyStore;
            req.user = decodeUser;
            req.refreshToken = refreshToken;
            return next();
        }
        catch (error) {
            console.log(error);
            throw new error_response_1.BadRequestError('Bad request');
        }
    }
    const accessToken = req.headers[HEADER.AUTHORIZATION];
    if (!accessToken)
        throw new error_response_1.AuthFailureError('Invalid request');
    try {
        const decodeUser = jsonwebtoken_1.default.verify(accessToken, keyStore.publicKey);
        if (userId !== decodeUser.userId) {
            throw new error_response_1.AuthFailureError('Invalid user');
        }
        req.keyStore = keyStore;
        req.user = decodeUser;
        next();
    }
    catch (error) {
        console.log(error);
        throw new error_response_1.BadRequestError('Bad request');
    }
});
const verifyJWT = (token, keySecret) => {
    return jsonwebtoken_1.default.verify(token, keySecret);
};
exports.verifyJWT = verifyJWT;
//# sourceMappingURL=authUtils.js.map