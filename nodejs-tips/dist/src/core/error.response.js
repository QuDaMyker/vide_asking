"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ForbiddenError = exports.NotFoundError = exports.AuthFailureError = exports.BadRequestError = exports.ConflictRequestError = exports.ErrorResponse = exports.ReasonStatusCode = exports.StatusCode = void 0;
exports.StatusCode = {
    FORBIDDEN: 403,
    CONFLICT: 409,
    UNAUTHORIZED: 401,
    NOT_FOUND: 404,
    BAD_REQUEST: 400,
};
exports.ReasonStatusCode = {
    FORBIDDEN: 'Forbidden',
    CONFLICT: 'Conflict Error',
    UNAUTHORIZED: 'Unauthorized',
    NOT_FOUND: 'Not found',
    BAD_REQUEST: 'Bad Request',
};
class ErrorResponse extends Error {
    constructor(message, status) {
        super(message);
        this.status = status;
        this.name = this.constructor.name;
        Error.captureStackTrace(this, this.constructor);
    }
}
exports.ErrorResponse = ErrorResponse;
class ConflictRequestError extends ErrorResponse {
    constructor(message = exports.ReasonStatusCode.CONFLICT, statusCode = exports.StatusCode.CONFLICT) {
        super(message, statusCode);
    }
}
exports.ConflictRequestError = ConflictRequestError;
class BadRequestError extends ErrorResponse {
    constructor(message = exports.ReasonStatusCode.BAD_REQUEST, statusCode = exports.StatusCode.BAD_REQUEST) {
        super(message, statusCode);
    }
}
exports.BadRequestError = BadRequestError;
class AuthFailureError extends ErrorResponse {
    constructor(message = exports.ReasonStatusCode.UNAUTHORIZED, statusCode = exports.StatusCode.UNAUTHORIZED) {
        super(message, statusCode);
    }
}
exports.AuthFailureError = AuthFailureError;
class NotFoundError extends ErrorResponse {
    constructor(message = exports.ReasonStatusCode.NOT_FOUND, statusCode = exports.StatusCode.NOT_FOUND) {
        super(message, statusCode);
    }
}
exports.NotFoundError = NotFoundError;
class ForbiddenError extends ErrorResponse {
    constructor(message = exports.ReasonStatusCode.FORBIDDEN, statusCode = exports.StatusCode.FORBIDDEN) {
        super(message, statusCode);
    }
}
exports.ForbiddenError = ForbiddenError;
//# sourceMappingURL=error.response.js.map