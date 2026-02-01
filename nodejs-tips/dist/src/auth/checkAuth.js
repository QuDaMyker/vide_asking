"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.permission = exports.apiKey = void 0;
const apiKey_service_1 = require("../services/apiKey.service");
const HEADER = {
    API_KEY: 'x-api-key',
    AUTHORIZATION: 'authorization',
};
const apiKey = async (req, res, next) => {
    try {
        const key = req.headers[HEADER.API_KEY]?.toString();
        if (!key) {
            return res.status(403).json({
                message: 'Forbidden',
            });
        }
        const apiKeyService = new apiKey_service_1.ApiKeyService();
        const objKey = await apiKeyService.findById(key);
        if (!objKey) {
            return res.status(403).json({
                message: 'Forbidden Error',
            });
        }
        req.objKey = objKey;
        return next();
    }
    catch (error) {
        return res.status(500).json({
            message: 'Internal Server Error',
        });
    }
};
exports.apiKey = apiKey;
const permission = (requiredPermission) => {
    return (req, res, next) => {
        if (!req.objKey?.permissions) {
            return res.status(403).json({
                message: 'Permission Denied',
            });
        }
        const validPermission = req.objKey.permissions.includes(requiredPermission);
        if (!validPermission) {
            return res.status(403).json({
                message: 'Permission Denied',
            });
        }
        return next();
    };
};
exports.permission = permission;
//# sourceMappingURL=checkAuth.js.map