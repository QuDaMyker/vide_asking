import { Request, Response, NextFunction } from 'express';
import { ApiKeyService } from '../services/apiKey.service';
import { IApiKey } from '../models/apiKey.model';

const HEADER = {
  API_KEY: 'x-api-key',
  AUTHORIZATION: 'authorization',
};

export interface ApiKeyRequest extends Request {
  objKey?: IApiKey;
}

export const apiKey = async (req: ApiKeyRequest, res: Response, next: NextFunction) => {
  try {
    const key = req.headers[HEADER.API_KEY]?.toString();
    if (!key) {
      return res.status(403).json({
        message: 'Forbidden',
      });
    }

    const apiKeyService = new ApiKeyService();
    const objKey = await apiKeyService.findById(key);
    if (!objKey) {
      return res.status(403).json({
        message: 'Forbidden Error',
      });
    }
    req.objKey = objKey;
    return next();
  } catch (error) {
    return res.status(500).json({
      message: 'Internal Server Error',
    });
  }
};

export const permission = (requiredPermission: string) => {
  return (req: ApiKeyRequest, res: Response, next: NextFunction) => {
    if (!req.objKey?.permissions) {
      return res.status(403).json({
        message: 'Permission Denied',
      });
    }

    const validPermission = req.objKey.permissions.includes(requiredPermission);
    if (!validPermission) {
      return res.status(403).json({
        message: 'Permission Denied',
      });
    }
    return next();
  };
};
