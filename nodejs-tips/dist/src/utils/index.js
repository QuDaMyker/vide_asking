"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.unGetSelectData = exports.getSelectData = exports.getInfoData = void 0;
const lodash_1 = __importDefault(require("lodash"));
const getInfoData = ({ fields = [], object = {} }) => {
    return lodash_1.default.pick(object, fields);
};
exports.getInfoData = getInfoData;
const getSelectData = (select = []) => {
    return Object.fromEntries(select.map((el) => [el, 1]));
};
exports.getSelectData = getSelectData;
const unGetSelectData = (select = []) => {
    return Object.fromEntries(select.map((el) => [el, 0]));
};
exports.unGetSelectData = unGetSelectData;
//# sourceMappingURL=index.js.map