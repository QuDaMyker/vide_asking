import { Config } from '../config/config.mongodb';
export declare class Database {
    private static instance;
    private config;
    constructor(config: Config);
    connect(type?: string): void;
    static getInstance(config: Config): Database;
}
//# sourceMappingURL=init.mongodb.d.ts.map