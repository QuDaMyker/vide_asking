import { sequelize } from '../src/config/database';

beforeAll(async () => {
  // Connect to test database
  await sequelize.sync({ force: true });
});

afterAll(async () => {
  // Close database connection
  await sequelize.close();
});

afterEach(async () => {
  // Clean up database after each test
  const models = sequelize.models;
  for (const model of Object.values(models)) {
    await model.destroy({ where: {}, truncate: true });
  }
});
