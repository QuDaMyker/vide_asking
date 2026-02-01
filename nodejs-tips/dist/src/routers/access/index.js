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
const accessController = container_1.container.get(types_1.TYPES.AccessController);
router.post('/signup', (0, asyncHandler_1.asyncHandler)(accessController.signUp.bind(accessController)));
router.post('/login', (0, asyncHandler_1.asyncHandler)(accessController.login.bind(accessController)));
router.use(authUtils_1.authenticationV2);
router.post('/logout', (0, asyncHandler_1.asyncHandler)(accessController.logout.bind(accessController)));
router.post('/handlerRefreshToken', (0, asyncHandler_1.asyncHandler)(accessController.handleRefreshToken.bind(accessController)));
exports.default = router;
//# sourceMappingURL=index.js.map