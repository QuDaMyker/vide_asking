"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.furniture = exports.electronic = exports.clothing = exports.product = void 0;
const mongoose_1 = __importStar(require("mongoose"));
const slugify_1 = __importDefault(require("slugify"));
const DOCUMENT_NAME = 'Product';
const COLLECTION_NAME = 'Products';
const productSchema = new mongoose_1.Schema({
    product_name: {
        type: String,
        required: true,
    },
    product_thumb: {
        type: String,
        required: true,
    },
    product_description: {
        type: String,
    },
    product_slug: {
        type: String,
    },
    product_price: {
        type: Number,
        required: true,
    },
    product_quantity: {
        type: Number,
        required: true,
    },
    product_type: {
        type: String,
        required: true,
        enum: ['Electronic', 'Clothing', 'Furniture'],
    },
    product_shop: {
        type: mongoose_1.Schema.Types.ObjectId,
        ref: 'Shop',
    },
    product_attributes: {
        type: mongoose_1.Schema.Types.Mixed,
        required: true,
    },
    product_ratingsAverage: {
        type: Number,
        default: 4.5,
        min: [1, 'Rating must be above 1.0'],
        max: [5, 'Rating must be below 5.0'],
        set: (value) => Math.round(value * 10) / 10,
    },
    product_variantions: [mongoose_1.Schema.Types.Mixed],
    isDraft: {
        type: Boolean,
        default: true,
        index: true,
        select: false,
    },
    isPublish: {
        type: Boolean,
        default: false,
        index: true,
        select: false,
    },
}, {
    timestamps: true,
    collection: COLLECTION_NAME,
});
productSchema.index({ product_name: 'text', product_description: 'text' });
productSchema.pre('save', function (next) {
    this.product_slug = (0, slugify_1.default)(this.product_name, { lower: true });
    next();
});
const clothingSchema = new mongoose_1.Schema({
    brand: {
        type: String,
        required: true,
    },
    size: String,
    material: String,
    product_shop: { type: mongoose_1.Schema.Types.ObjectId, ref: 'Shop' },
}, {
    collection: 'Clothes',
    timestamps: true,
});
const electronicSchema = new mongoose_1.Schema({
    manufacturer: {
        type: String,
        required: true,
    },
    modelName: String,
    color: String,
    product_shop: { type: mongoose_1.Schema.Types.ObjectId, ref: 'Shop' },
}, {
    collection: 'Electronics',
    timestamps: true,
});
const furnitureSchema = new mongoose_1.Schema({
    brand: {
        type: String,
        required: true,
    },
    size: String,
    material: String,
    product_shop: { type: mongoose_1.Schema.Types.ObjectId, ref: 'Shop' },
}, {
    collection: 'Funitures',
    timestamps: true,
});
exports.product = mongoose_1.default.model(DOCUMENT_NAME, productSchema);
exports.clothing = mongoose_1.default.model('Clothing', clothingSchema);
exports.electronic = mongoose_1.default.model('Electronic', electronicSchema);
exports.furniture = mongoose_1.default.model('Funitures', furnitureSchema);
//# sourceMappingURL=product.model.js.map