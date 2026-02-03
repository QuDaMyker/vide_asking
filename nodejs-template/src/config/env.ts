import dotenv from 'dotenv';
import path from 'path';

// Load environment-specific .env file
const env = process.env.NODE_ENV || 'development';
const envFile = `.env.${env}`;

// Load the environment-specific file
dotenv.config({ path: path.resolve(process.cwd(), envFile) });

// Fallback to .env if environment-specific file doesn't exist
dotenv.config();

interface Config {
  nodeEnv: string;
  port: number;
  database: {
    host: string;
    port: number;
    name: string;
    user: string;
    password: string;
  };
  jwt: {
    secret: string;
    expiresIn: string;
    refreshSecret: string;
    refreshExpiresIn: string;
  };
  cors: {
    origin: string;
  };
  logging: {
    level: string;
  };
  rateLimit: {
    windowMs: number;
    maxRequests: number;
  };
  security: {
    helmetEnabled: boolean;
    trustProxy: boolean;
  };
}

export const config: Config = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT || '3000', 10),
  database: {
    host: process.env.DB_HOST || 'localhost',
    port: parseInt(process.env.DB_PORT || '5432', 10),
    name: process.env.DB_NAME || 'nodejs_template_dev',
    user: process.env.DB_USER || 'postgres',
    password: process.env.DB_PASSWORD || ''
  },
  jwt: {
    secret: process.env.JWT_SECRET || 'dev_jwt_secret',
    expiresIn: process.env.JWT_EXPIRES_IN || '24h',
    refreshSecret: process.env.JWT_REFRESH_SECRET || 'dev_refresh_secret',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '7d'
  },
  cors: {
    origin: process.env.CORS_ORIGIN || '*'
  },
  logging: {
    level: process.env.LOG_LEVEL || 'debug'
  },
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10),
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100', 10)
  },
  security: {
    helmetEnabled: process.env.HELMET_ENABLED === 'true',
    trustProxy: process.env.TRUST_PROXY === 'true'
  }
};

// Validate required environment variables in production
if (config.nodeEnv === 'production') {
  const requiredEnvVars = [
    'DB_HOST',
    'DB_NAME',
    'DB_USER',
    'DB_PASSWORD',
    'JWT_SECRET',
    'JWT_REFRESH_SECRET'
  ];

  const missingEnvVars = requiredEnvVars.filter(envVar => !process.env[envVar]);

  if (missingEnvVars.length > 0) {
    throw new Error(
      `Missing required environment variables in production: ${missingEnvVars.join(', ')}`
    );
  }
}

export default config;
