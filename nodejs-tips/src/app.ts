import 'reflect-metadata';
import 'dotenv/config';
import compression from 'compression';
import express, { Application, Request, Response, NextFunction } from 'express';
import helmet from 'helmet';
import morgan from 'morgan';
import { config } from './config/config.mongodb';
import { Database } from './dbs/init.mongodb';
import router from './routers';

const app: Application = express();

// Init middleware
app.use(morgan('dev'));
app.use(helmet());
app.use(compression());

// Init database
Database.getInstance(config);

// Init routers
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/', router);

// Handle errors
app.use((req: Request, res: Response, next: NextFunction) => {
  const error: any = new Error('Not Found');
  error.status = 404;
  next(error);
});

app.use((error: any, req: Request, res: Response, next: NextFunction) => {
  const statusCode = error.status || 500;
  console.log(error);
  return res.status(statusCode).json({
    status: 'error',
    code: statusCode,
    message: error.message || 'Internal Server Error',
  });
});

export default app;
