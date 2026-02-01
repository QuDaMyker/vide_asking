export interface IConfig {
  app: {
    port: number;
  };
  db: {
    host: string;
    port: number;
    name: string;
  };
}

class Config implements IConfig {
  public app: { port: number };
  public db: { host: string; port: number; name: string };

  constructor() {
    const env = process.env.NODE_ENV || 'dev';
    const configs = {
      dev: {
        app: {
          port: parseInt(process.env.DEV_APP_PORT || '3052', 10),
        },
        db: {
          host: process.env.DEV_DB_HOST || 'localhost',
          port: parseInt(process.env.DEV_DB_PORT || '27017', 10),
          name: process.env.DEV_DB_NAME || 'dbDev',
        },
      },
      pro: {
        app: {
          port: parseInt(process.env.PRO_APP_PORT || '3052', 10),
        },
        db: {
          host: process.env.PRO_DB_HOST || 'localhost',
          port: parseInt(process.env.PRO_DB_PORT || '27018', 10),
          name: process.env.PRO_DB_NAME || 'dbPro',
        },
      },
    };

    const selectedConfig = configs[env as keyof typeof configs] || configs.dev;
    this.app = selectedConfig.app;
    this.db = selectedConfig.db;

    console.log('Config loaded:', selectedConfig);
  }
}

export const config = new Config();
