import { Response } from 'express';
export declare const StatusCode: {
    readonly OK: 200;
    readonly CREATED: 201;
};
export declare const ReasonStatusCode: {
    readonly OK: "Success";
    readonly CREATED: "Created";
};
interface SuccessResponseOptions {
    message?: string;
    statusCode?: number;
    reasonStatusCode?: string;
    metadata?: any;
}
export declare class SuccessResponse {
    message: string;
    status: number;
    metadata: any;
    constructor({ message, statusCode, reasonStatusCode, metadata, }: SuccessResponseOptions);
    send(res: Response, headers?: Record<string, string>): Response;
}
export declare class OK extends SuccessResponse {
    constructor({ message, metadata }: {
        message?: string;
        metadata?: any;
    });
}
interface CreatedOptions {
    message?: string;
    options?: any;
    statusCode?: number;
    reasonStatusCode?: string;
    metadata?: any;
}
export declare class CREATED extends SuccessResponse {
    options: any;
    constructor({ message, options, statusCode, reasonStatusCode, metadata, }: CreatedOptions);
}
export {};
//# sourceMappingURL=success.response.d.ts.map