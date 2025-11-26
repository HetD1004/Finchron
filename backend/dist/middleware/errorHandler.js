"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.errorHandler = void 0;
const logger_1 = require("../utils/logger");
const errorHandler = (err, req, res, next) => {
    // Log the error
    logger_1.logger.error('Error occurred:', {
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
    const errorResponse = {
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
exports.errorHandler = errorHandler;
//# sourceMappingURL=errorHandler.js.map