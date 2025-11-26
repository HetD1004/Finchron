"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const helmet_1 = __importDefault(require("helmet"));
const morgan_1 = __importDefault(require("morgan"));
const compression_1 = __importDefault(require("compression"));
const express_rate_limit_1 = __importDefault(require("express-rate-limit"));
const dotenv_1 = __importDefault(require("dotenv"));
const path_1 = __importDefault(require("path"));
const Database_1 = require("./database/Database");
const logger_1 = require("./utils/logger");
const errorHandler_1 = require("./middleware/errorHandler");
const notFoundHandler_1 = require("./middleware/notFoundHandler");
// Route imports
const authRoutes_1 = __importDefault(require("./routes/authRoutes"));
const userRoutes_1 = __importDefault(require("./routes/userRoutes"));
const transactionRoutes_1 = __importDefault(require("./routes/transactionRoutes"));
const analyticsRoutes_1 = __importDefault(require("./routes/analyticsRoutes"));
const healthRoutes_1 = __importDefault(require("./routes/healthRoutes"));
// Load environment variables
dotenv_1.default.config();
class Server {
    constructor() {
        this.app = (0, express_1.default)();
        this.port = parseInt(process.env.PORT || '3000', 10);
        this.database = new Database_1.Database();
        this.initializeMiddleware();
        this.initializeRoutes();
        this.initializeErrorHandling();
    }
    initializeMiddleware() {
        // Security middleware
        this.app.use((0, helmet_1.default)({
            contentSecurityPolicy: {
                directives: {
                    defaultSrc: ["'self'"],
                    styleSrc: ["'self'", "'unsafe-inline'"],
                    scriptSrc: ["'self'"],
                    imgSrc: ["'self'", "data:", "https:"],
                },
            },
        }));
        // CORS configuration
        this.app.use((0, cors_1.default)({
            origin: process.env.CORS_ORIGIN?.split(',') || '*',
            credentials: true,
            methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
            allowedHeaders: ['Content-Type', 'Authorization', 'x-requested-with'],
        }));
        // Rate limiting
        const limiter = (0, express_rate_limit_1.default)({
            windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '900000', 10), // 15 minutes
            max: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100', 10), // limit each IP to 100 requests per windowMs
            message: {
                error: 'Too many requests from this IP, please try again later.',
            },
            standardHeaders: true,
            legacyHeaders: false,
        });
        this.app.use('/api', limiter);
        // Body parsing middleware
        this.app.use((0, compression_1.default)());
        this.app.use(express_1.default.json({ limit: '10mb' }));
        this.app.use(express_1.default.urlencoded({ extended: true, limit: '10mb' }));
        // Logging middleware
        if (process.env.NODE_ENV === 'development') {
            this.app.use((0, morgan_1.default)('dev'));
        }
        else {
            this.app.use((0, morgan_1.default)('combined'));
        }
        // Static files
        this.app.use('/uploads', express_1.default.static(path_1.default.join(__dirname, '..', 'uploads')));
    }
    initializeRoutes() {
        const apiVersion = process.env.API_VERSION || 'v1';
        const baseUrl = `/api/${apiVersion}`;
        // Health check route
        this.app.use(`${baseUrl}/health`, healthRoutes_1.default);
        // API routes
        this.app.use(`${baseUrl}/auth`, authRoutes_1.default);
        this.app.use(`${baseUrl}/users`, userRoutes_1.default);
        this.app.use(`${baseUrl}/transactions`, transactionRoutes_1.default);
        this.app.use(`${baseUrl}/analytics`, analyticsRoutes_1.default);
        // Root route
        this.app.get('/', (req, res) => {
            res.json({
                message: 'Finchron API Server',
                version: '1.0.0',
                status: 'running',
                timestamp: new Date().toISOString(),
                endpoints: {
                    health: `${baseUrl}/health`,
                    auth: `${baseUrl}/auth`,
                    users: `${baseUrl}/users`,
                    transactions: `${baseUrl}/transactions`,
                    analytics: `${baseUrl}/analytics`,
                },
            });
        });
    }
    initializeErrorHandling() {
        // 404 handler
        this.app.use(notFoundHandler_1.notFoundHandler);
        // Global error handler
        this.app.use(errorHandler_1.errorHandler);
    }
    async start() {
        try {
            // Initialize database
            await this.database.initialize();
            logger_1.logger.info('Database initialized successfully');
            // Start server
            this.app.listen(this.port, () => {
                logger_1.logger.info(`🚀 Finchron API Server running on port ${this.port}`);
                logger_1.logger.info(`📊 Environment: ${process.env.NODE_ENV}`);
                logger_1.logger.info(`🔗 API Base URL: http://localhost:${this.port}/api/${process.env.API_VERSION || 'v1'}`);
                logger_1.logger.info(`📚 Health Check: http://localhost:${this.port}/api/${process.env.API_VERSION || 'v1'}/health`);
            });
        }
        catch (error) {
            logger_1.logger.error('Failed to start server:', error);
            process.exit(1);
        }
    }
    getApp() {
        return this.app;
    }
    async stop() {
        try {
            await this.database.close();
            logger_1.logger.info('Server stopped gracefully');
        }
        catch (error) {
            logger_1.logger.error('Error stopping server:', error);
        }
    }
}
// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
    logger_1.logger.error('Uncaught Exception:', error);
    process.exit(1);
});
// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
    logger_1.logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
    process.exit(1);
});
// Graceful shutdown
process.on('SIGTERM', async () => {
    logger_1.logger.info('SIGTERM signal received: closing HTTP server');
    // Add graceful shutdown logic here
    process.exit(0);
});
process.on('SIGINT', async () => {
    logger_1.logger.info('SIGINT signal received: closing HTTP server');
    // Add graceful shutdown logic here
    process.exit(0);
});
// Start server if this file is run directly
if (require.main === module) {
    const server = new Server();
    server.start();
}
exports.default = Server;
//# sourceMappingURL=server.js.map