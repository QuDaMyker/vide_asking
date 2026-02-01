import 'reflect-metadata';
import { config } from './config';
import { logger } from './utils/logger';
import { container } from './di/container';
import { App } from './app';

async function bootstrap() {
  try {
    logger.info('Starting application...');
    logger.info(`Environment: ${config.nodeEnv}`);
    logger.info(`Port: ${config.port}`);

    const app = container.resolve(App);
    await app.start();

    // Graceful shutdown
    process.on('SIGTERM', async () => {
      logger.info('SIGTERM signal received: closing HTTP server');
      await app.stop();
      process.exit(0);
    });

    process.on('SIGINT', async () => {
      logger.info('SIGINT signal received: closing HTTP server');
      await app.stop();
      process.exit(0);
    });
  } catch (error) {
    logger.error('Failed to start application:', error);
    process.exit(1);
  }
}

bootstrap();
