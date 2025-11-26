import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger';

interface ErrorWithStatus extends Error {
  status?: number;
  statusCode?: number;
}

export const errorHandler = (
  err: ErrorWithStatus,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  // Log the error
  logger.error('Error occurred:', {
    message: err.message,
    stack: err.stack,
    url: req.url,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
  });

  // Set default error status
  const status = err.status || err.statusCode || 500;
  const message = err.message || 'Internal Server Error';

  // Don't leak error details in production
  const isDevelopment = process.env.NODE_ENV === 'development';
  
  const errorResponse: any = {
    error: {
      message,
      status,
      timestamp: new Date().toISOString(),
    },
  };

  // Include stack trace only in development
  if (isDevelopment) {
    errorResponse.error.stack = err.stack;
    errorResponse.error.details = err;
  }

  res.status(status).json(errorResponse);
};
