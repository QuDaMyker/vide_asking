"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
require("reflect-metadata");
const app_1 = __importDefault(require("./app"));
const container_1 = require("./di/container");
const types_1 = require("./di/types");
const config = container_1.container.get(types_1.TYPES.Config);
const PORT = config.app.port || 3055;
const server = app_1.default.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
process.on('SIGINT', () => {
    server.close(() => console.log('Server closed'));
    process.exit(0);
});
//# sourceMappingURL=server.js.map