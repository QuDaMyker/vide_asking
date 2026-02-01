import { Container } from 'inversify';
import { TYPES } from './types';

// Import services
import { AccessService } from '../services/access.service';
import { KeyTokenService } from '../services/keyToken.service';
import { ShopService } from '../services/shop.service';
import { ApiKeyService } from '../services/apiKey.service';
import { ProductService } from '../services/product.service';

// Import repositories
import { ProductRepository } from '../models/repositories/product.repo';

// Import controllers
import { AccessController } from '../controllers/access.controller';
import { ProductController } from '../controllers/product.controller';

const container = new Container();

// Note: Config is not bound here to avoid circular dependency
// It's used directly where needed

// Bind Services
container.bind<AccessService>(TYPES.AccessService).to(AccessService).inSingletonScope();
container.bind<KeyTokenService>(TYPES.KeyTokenService).to(KeyTokenService).inSingletonScope();
container.bind<ShopService>(TYPES.ShopService).to(ShopService).inSingletonScope();
container.bind<ApiKeyService>(TYPES.ApiKeyService).to(ApiKeyService).inSingletonScope();
container.bind<ProductService>(TYPES.ProductService).to(ProductService).inSingletonScope();

// Bind Repositories
container.bind<ProductRepository>(TYPES.ProductRepository).to(ProductRepository).inSingletonScope();

// Bind Controllers
container.bind<AccessController>(TYPES.AccessController).to(AccessController).inSingletonScope();
container.bind<ProductController>(TYPES.ProductController).to(ProductController).inSingletonScope();

export { container };
