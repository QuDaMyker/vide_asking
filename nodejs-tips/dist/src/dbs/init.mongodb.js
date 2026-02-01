"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.Database = void 0;
const mongoose_1 = __importDefault(require("mongoose"));
class Database {
    constructor(config) {
        this.config = config;
        this.connect();
    }
    connect(type = 'mongodb') {
        const { host, name, port } = this.config.db;
        const connectString = `mongodb://${host}:${port}/${name}`;
        if (process.env.NODE_ENV === 'dev') {
            mongoose_1.default.set('debug', true);
        }
        mongoose_1.default
            .connect(connectString, {
            maxPoolSize: 50,
        })
            .then(() => {
            console.log(`Connected MongoDB Success`);
        })
            .catch((err) => console.log(`Error Connect! ${err}`));
    }
    static getInstance(config) {
        if (!Database.instance) {
            Database.instance = new Database(config);
        }
        return Database.instance;
    }
}
exports.Database = Database;
//# sourceMappingURL=init.mongodb.js.map