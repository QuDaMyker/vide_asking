'use strict';

const { toLower } = require('lodash');
const mongoose = require('mongoose'); // Erase if already required
const slugify = require('slugify')


const DOCUMENT_NAME = 'Product';
const COLLECTION_NAME = 'Products';

// Declare the Schema of the Mongo model
const productSchema = new mongoose.Schema({
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
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Shop',
  },
  product_attributes: {
    type: mongoose.Schema.Types.Mixed,
    required: true,
  },
  product_ratingsAverage: {
    type: Number,
    default: 4.5,
    min: [1, 'Rating must be above 1.0'],
    max: [5, 'Rating must be below 5.0'],
    set: (value) => Math.round(value * 10) / 10
  },
  product_variantions: {
    type: Array,
    default: []
  },
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
  }
}, {
  timestamps: true,
  collection: COLLECTION_NAME,
});

// create index for search
productSchema.index({ product_name: 'text', product_description: 'text'})

productSchema.pre('save', function (next) {
  this.product_slug = slugify(this.product_name, { lower: true })
})

// Clothing Schema
const clothingSchema = new mongoose.Schema({
  brand: {
    type: String,
    required: true,
  },
  size: String,
  material: String,
  product_shop: {type: mongoose.Schema.Types.ObjectId, ref: 'Shop'}
}, {
  collection: 'Clothes',
  timestamps: true,
});

// Electronic Schema
const electronicSchema = new mongoose.Schema({
  manufacturer: {
    type: String,
    required: true,
  },
  model: String,
  color: String,
  product_shop: {type: mongoose.Schema.Types.ObjectId, ref: 'Shop'}
}, {
  collection: 'Electronics',
  timestamps: true,
});

const furnitureSchema = new mongoose.Schema({
  brand: {
    type: String,
    required: true,
  },
  size: String,
  material: String,
  product_shop: {type: mongoose.Schema.Types.ObjectId, ref: 'Shop'}
}, {
  collection: 'Funitures',
  timestamps: true,
});

// Export models
module.exports = {
  product: mongoose.model(DOCUMENT_NAME, productSchema),
  clothing: mongoose.model('Clothing', clothingSchema),
  electronic: mongoose.model('Electronic', electronicSchema),
  furniture: mongoose.model('Funitures', furnitureSchema),
};
