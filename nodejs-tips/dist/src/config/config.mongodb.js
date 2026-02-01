"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.Config = void 0;
const inversify_1 = require("inversify");
let Config = class Config {
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
        const selectedConfig = configs[env] || configs.dev;
        this.app = selectedConfig.app;
        this.db = selectedConfig.db;
        console.log('Config loaded:', selectedConfig);
    }
};
exports.Config = Config;
exports.Config = Config = __decorate([
    (0, inversify_1.injectable)(),
    __metadata("design:paramtypes", [])
], Config);
//# sourceMappingURL=config.mongodb.js.map