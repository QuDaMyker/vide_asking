"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const container_1 = require("../../di/container");
const asyncHandler_1 = require("../../helpers/asyncHandler");
const authUtils_1 = require("../../auth/authUtils");
const types_1 = require("../../di/types");
const router = express_1.default.Router();
const productController = container_1.container.get(types_1.TYPES.ProductController);
router.use(authUtils_1.authentication);
router.post('', (0, asyncHandler_1.asyncHandler)(productController.createProduct.bind(productController)));
router.post('/publish/:id', (0, asyncHandler_1.asyncHandler)(productController.publishProductByShop.bind(productController)));
router.post('/unpublish/:id', (0, asyncHandler_1.asyncHandler)(productController.unPublishProductByShop.bind(productController)));
router.get('/drafts/all', (0, asyncHandler_1.asyncHandler)(productController.getAllDraftsForShop.bind(productController)));
router.get('/publishs/all', (0, asyncHandler_1.asyncHandler)(productController.getAllPublishForShop.bind(productController)));
exports.default = router;
//# sourceMappingURL=index.js.map