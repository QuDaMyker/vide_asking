'use strict'

const StatusCode = {
    FORBIDDEN: 403,
    CONFLICT: 409,
    UNAUTHORIZED: 401,
    NOT_FOUND: 404
}

const ReasonStatusCode = {
    FORBIDDEN: 'Bad Request',
    CONFLICT: 'Conflict Error',
    UNAUTHORIZED: 'Unauthorized',
    NOT_FOUND: 'Not found'
}

class ErrorResponse extends Error {

    constructor(message, status) {
        super(message)
        this.status = status
    }
}

class ConflictRequestError extends ErrorResponse {
    constructor( message = ReasonStatusCode.CONFLICT, statusCode = StatusCode.CONFLICT ) {
        super(message, statusCode)
    }
}

class BadRequestError extends ErrorResponse {
    constructor( message = ReasonStatusCode.BadRequestError, statusCode = StatusCode.BadRequestError ) {
        super(message, statusCode)
    }
}

class AuthFailureError extends ErrorResponse {
    constructor( message = ReasonStatusCode.UNAUTHORIZED, statusCode = StatusCode.UNAUTHORIZED ) {
        super(message, statusCode)
    }
}

class NotFoundError extends ErrorResponse {
    constructor( message = ReasonStatusCode.NOT_FOUND, statusCode = StatusCode.NOT_FOUND ) {
        super(message, statusCode)
    }
}

class ForbiddenError extends ErrorResponse {
    constructor( message = ReasonStatusCode.FORBIDDEN, statusCode = StatusCode.FORBIDDEN ) {
        super(message, statusCode)
    }
}

module.exports = {
    ConflictRequestError,
    BadRequestError,
    AuthFailureError,
    NotFoundError,
    ForbiddenError
}