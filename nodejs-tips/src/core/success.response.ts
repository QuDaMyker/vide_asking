import { Response } from 'express';

export const StatusCode = {
  OK: 200,
  CREATED: 201,
} as const;

export const ReasonStatusCode = {
  OK: 'Success',
  CREATED: 'Created',
} as const;

interface SuccessResponseOptions {
  message?: string;
  statusCode?: number;
  reasonStatusCode?: string;
  metadata?: any;
}

export class SuccessResponse {
  public message: string;
  public status: number;
  public metadata: any;

  constructor({
    message,
    statusCode = StatusCode.OK,
    reasonStatusCode = ReasonStatusCode.OK,
    metadata = {},
  }: SuccessResponseOptions) {
    this.message = message || reasonStatusCode;
    this.status = statusCode;
    this.metadata = metadata;
  }

  send(res: Response, headers: Record<string, string> = {}): Response {
    return res.status(this.status).json(this);
  }
}

export class OK extends SuccessResponse {
  constructor({ message, metadata = {} }: { message?: string; metadata?: any }) {
    super({ message, metadata });
  }
}

interface CreatedOptions {
  message?: string;
  options?: any;
  statusCode?: number;
  reasonStatusCode?: string;
  metadata?: any;
}

export class CREATED extends SuccessResponse {
  public options: any;

  constructor({
    message,
    options = {},
    statusCode = StatusCode.CREATED,
    reasonStatusCode = ReasonStatusCode.CREATED,
    metadata = {},
  }: CreatedOptions) {
    super({ message, statusCode, reasonStatusCode, metadata });
    this.options = options;
  }
}
