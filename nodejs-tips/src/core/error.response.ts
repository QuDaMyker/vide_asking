export const StatusCode = {
  FORBIDDEN: 403,
  CONFLICT: 409,
  UNAUTHORIZED: 401,
  NOT_FOUND: 404,
  BAD_REQUEST: 400,
} as const;

export const ReasonStatusCode = {
  FORBIDDEN: 'Forbidden',
  CONFLICT: 'Conflict Error',
  UNAUTHORIZED: 'Unauthorized',
  NOT_FOUND: 'Not found',
  BAD_REQUEST: 'Bad Request',
} as const;

export class ErrorResponse extends Error {
  public status: number;

  constructor(message: string, status: number) {
    super(message);
    this.status = status;
    this.name = this.constructor.name;
    Error.captureStackTrace(this, this.constructor);
  }
}

export class ConflictRequestError extends ErrorResponse {
  constructor(
    message: string = ReasonStatusCode.CONFLICT,
    statusCode: number = StatusCode.CONFLICT
  ) {
    super(message, statusCode);
  }
}

export class BadRequestError extends ErrorResponse {
  constructor(
    message: string = ReasonStatusCode.BAD_REQUEST,
    statusCode: number = StatusCode.BAD_REQUEST
  ) {
    super(message, statusCode);
  }
}

export class AuthFailureError extends ErrorResponse {
  constructor(
    message: string = ReasonStatusCode.UNAUTHORIZED,
    statusCode: number = StatusCode.UNAUTHORIZED
  ) {
    super(message, statusCode);
  }
}

export class NotFoundError extends ErrorResponse {
  constructor(
    message: string = ReasonStatusCode.NOT_FOUND,
    statusCode: number = StatusCode.NOT_FOUND
  ) {
    super(message, statusCode);
  }
}

export class ForbiddenError extends ErrorResponse {
  constructor(
    message: string = ReasonStatusCode.FORBIDDEN,
    statusCode: number = StatusCode.FORBIDDEN
  ) {
    super(message, statusCode);
  }
}
