import { drizzle } from 'drizzle-orm/node-postgres';
import { migrate } from 'drizzle-orm/node-postgres/migrator';
import { Pool } from 'pg';
import { config } from '../config';
import { logger } from '../utils/logger';

async function runMigrations() {
  const pool = new Pool({
    host: config.database.host,
    port: config.database.port,
    database: config.database.name,
    user: config.database.user,
    password: config.database.password,
  });

  const db = drizzle(pool);

  try {
    logger.info('Running migrations...');
    await migrate(db, { migrationsFolder: './drizzle' });
    logger.info('Migrations completed successfully');
  } catch (error) {
    logger.error('Migration failed:', error);
    throw error;
  } finally {
    await pool.end();
  }
}

runMigrations();
