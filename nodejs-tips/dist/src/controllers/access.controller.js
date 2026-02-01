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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AccessController = void 0;
const inversify_1 = require("inversify");
const success_response_1 = require("../core/success.response");
const access_service_1 = require("../services/access.service");
const types_1 = require("../di/types");
let AccessController = class AccessController {
    constructor(accessService) {
        this.accessService = accessService;
        this.handleRefreshToken = async (req, res, next) => {
            return new success_response_1.SuccessResponse({
                message: 'Get token success',
                metadata: await this.accessService.handlerRefreshTokenV2({
                    refreshToken: req.refreshToken,
                    user: req.user,
                    keyStore: req.keyStore,
                }),
            }).send(res);
        };
        this.logout = async (req, res, next) => {
            return new success_response_1.SuccessResponse({
                message: 'Logout success',
                metadata: await this.accessService.logout(req.keyStore),
            }).send(res);
        };
        this.login = async (req, res, next) => {
            try {
                return new success_response_1.SuccessResponse({
                    message: 'Login ok',
                    metadata: await this.accessService.login(req.body),
                }).send(res);
            }
            catch (error) {
                next(error);
            }
        };
        this.signUp = async (req, res, next) => {
            try {
                console.log(`[P]::signUp::`, req.body);
                return new success_response_1.CREATED({
                    message: 'Registered OK!',
                    metadata: await this.accessService.signUp(req.body),
                    options: {
                        limit: 10,
                    },
                }).send(res);
            }
            catch (err) {
                next(err);
            }
        };
    }
};
exports.AccessController = AccessController;
exports.AccessController = AccessController = __decorate([
    (0, inversify_1.injectable)(),
    __param(0, (0, inversify_1.inject)(types_1.TYPES.AccessService)),
    __metadata("design:paramtypes", [access_service_1.AccessService])
], AccessController);
//# sourceMappingURL=access.controller.js.map