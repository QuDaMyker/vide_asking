import express, { Application } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import { injectable, inject } from 'tsyringe';
import { config } from './config';
import { logger } from './utils/logger';
import { DatabaseService } from './services/database.service';
import { requestLogger } from './middlewares/logger.middleware';
import { errorHandler } from './middlewares/error.middleware';
import routes from './routes';

@injectable()
export class App {
  private app: Application;
  private server: any;

  constructor(
    @inject('DatabaseService') private dbService: DatabaseService,
  ) {
    this.app = express();
    this.setupMiddlewares();
    this.setupRoutes();
    this.setupErrorHandling();
  }

  private setupMiddlewares() {
    // Security middlewares
    this.app.use(helmet());
    this.app.use(
      cors({
        origin: config.cors.origin,
        credentials: true,
      }),
    );

    // Rate limiting
    const limiter = rateLimit({
      windowMs: config.rateLimit.windowMs,
      max: config.rateLimit.maxRequests,
      message: 'Too many requests from this IP, please try again later.',
    });
    this.app.use(limiter);

    // Body parser
    this.app.use(express.json());
    this.app.use(express.urlencoded({ extended: true }));

    // Request logging
    this.app.use(requestLogger);
  }

  private setupRoutes() {
    // API routes
    this.app.use(config.apiPrefix, routes);

    // 404 handler
    this.app.use('*', (req, res) => {
      res.status(404).json({
        success: false,
        message: 'Route not found',
      });
    });
  }

  private setupErrorHandling() {
    this.app.use(errorHandler);
  }

  async start(): Promise<void> {
    try {
      // Connect to database
      await this.dbService.connect();

      // Start server
      this.server = this.app.listen(config.port, () => {
        logger.info(`Server is running on port ${config.port}`);
        logger.info(`API available at http://localhost:${config.port}${config.apiPrefix}`);
      });
    } catch (error) {
      logger.error('Failed to start server:', error);
      throw error;
    }
  }

  async stop(): Promise<void> {
    try {
      if (this.server) {
        await new Promise<void>((resolve, reject) => {
          this.server.close((err: Error) => {
            if (err) reject(err);
            else resolve();
          });
        });
        logger.info('Server stopped');
      }

      await this.dbService.disconnect();
    } catch (error) {
      logger.error('Error stopping server:', error);
      throw error;
    }
  }
}
