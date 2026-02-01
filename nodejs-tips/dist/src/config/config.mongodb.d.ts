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
export declare class Config implements IConfig {
    app: {
        port: number;
    };
    db: {
        host: string;
        port: number;
        name: string;
    };
    constructor();
}
//# sourceMappingURL=config.mongodb.d.ts.map