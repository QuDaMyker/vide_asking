export const TYPES = {
  // Core
  App: Symbol.for('App'),
  Config: Symbol.for('Config'),
  Database: Symbol.for('Database'),

  // Services
  AccessService: Symbol.for('AccessService'),
  KeyTokenService: Symbol.for('KeyTokenService'),
  ShopService: Symbol.for('ShopService'),
  ApiKeyService: Symbol.for('ApiKeyService'),
  ProductService: Symbol.for('ProductService'),

  // Repositories
  ProductRepository: Symbol.for('ProductRepository'),

  // Controllers
  AccessController: Symbol.for('AccessController'),
  ProductController: Symbol.for('ProductController'),

  // Models
  ShopModel: Symbol.for('ShopModel'),
  KeyTokenModel: Symbol.for('KeyTokenModel'),
  ApiKeyModel: Symbol.for('ApiKeyModel'),
  ProductModel: Symbol.for('ProductModel'),
};
