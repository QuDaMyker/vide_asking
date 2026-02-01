import mongoose from 'mongoose';
import { IConfig } from '../config/config.mongodb';

export class Database {
  private static instance: Database;
  private config: IConfig;

  constructor(config: IConfig) {
    this.config = config;
    this.connect();
  }

  connect(type: string = 'mongodb'): void {
    const { host, name, port } = this.config.db;
    const connectString = `mongodb://${host}:${port}/${name}`;

    if (process.env.NODE_ENV === 'dev') {
      mongoose.set('debug', true);
    }

    mongoose
      .connect(connectString, {
        maxPoolSize: 50,
      })
      .then(() => {
        console.log(`Connected MongoDB Success`);
      })
      .catch((err) => console.log(`Error Connect! ${err}`));
  }

  static getInstance(config: IConfig): Database {
    if (!Database.instance) {
      Database.instance = new Database(config);
    }
    return Database.instance;
  }
}
