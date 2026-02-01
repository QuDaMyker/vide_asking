"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CREATED = exports.OK = exports.SuccessResponse = exports.ReasonStatusCode = exports.StatusCode = void 0;
exports.StatusCode = {
    OK: 200,
    CREATED: 201,
};
exports.ReasonStatusCode = {
    OK: 'Success',
    CREATED: 'Created',
};
class SuccessResponse {
    constructor({ message, statusCode = exports.StatusCode.OK, reasonStatusCode = exports.ReasonStatusCode.OK, metadata = {}, }) {
        this.message = message || reasonStatusCode;
        this.status = statusCode;
        this.metadata = metadata;
    }
    send(res, headers = {}) {
        return res.status(this.status).json(this);
    }
}
exports.SuccessResponse = SuccessResponse;
class OK extends SuccessResponse {
    constructor({ message, metadata = {} }) {
        super({ message, metadata });
    }
}
exports.OK = OK;
class CREATED extends SuccessResponse {
    constructor({ message, options = {}, statusCode = exports.StatusCode.CREATED, reasonStatusCode = exports.ReasonStatusCode.CREATED, metadata = {}, }) {
        super({ message, statusCode, reasonStatusCode, metadata });
        this.options = options;
    }
}
exports.CREATED = CREATED;
//# sourceMappingURL=success.response.js.map