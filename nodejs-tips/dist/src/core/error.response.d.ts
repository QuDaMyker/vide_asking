export declare const StatusCode: {
    readonly FORBIDDEN: 403;
    readonly CONFLICT: 409;
    readonly UNAUTHORIZED: 401;
    readonly NOT_FOUND: 404;
    readonly BAD_REQUEST: 400;
};
export declare const ReasonStatusCode: {
    readonly FORBIDDEN: "Forbidden";
    readonly CONFLICT: "Conflict Error";
    readonly UNAUTHORIZED: "Unauthorized";
    readonly NOT_FOUND: "Not found";
    readonly BAD_REQUEST: "Bad Request";
};
export declare class ErrorResponse extends Error {
    status: number;
    constructor(message: string, status: number);
}
export declare class ConflictRequestError extends ErrorResponse {
    constructor(message?: string, statusCode?: number);
}
export declare class BadRequestError extends ErrorResponse {
    constructor(message?: string, statusCode?: number);
}
export declare class AuthFailureError extends ErrorResponse {
    constructor(message?: string, statusCode?: number);
}
export declare class NotFoundError extends ErrorResponse {
    constructor(message?: string, statusCode?: number);
}
export declare class ForbiddenError extends ErrorResponse {
    constructor(message?: string, statusCode?: number);
}
//# sourceMappingURL=error.response.d.ts.map