import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import compression from 'compression';
import rateLimit from 'express-rate-limit';
import dotenv from 'dotenv';
import path from 'path';

import { Database } from '././database/Database';
import { logger } from '././utils/logger';
import { errorHandler } from './middleware/errorHandler';
import { notFoundHandler } from './middleware/notFoundHandler';


import createAuthRoutes from '././routes/authRoutes';
import userRoutes from '././routes/userRoutes';
import createTransactionRoutes from '././routes/transactionRoutes';
import createAnalyticsRoutes from '././routes/analyticsRoutes';
import healthRoutes from './/routes/healthRoutes';


dotenv.config();

class Server {
  private app: express.Application;
  private port: number;
  private database: Database;

  constructor() {
    this.app = express();
    this.port = parseInt(process.env.PORT || '3000', 10);
    this.database = new Database();
    
    this.initializeMiddleware();
    this.initializeRoutes();
    this.initializeErrorHandling();
  }

  private initializeMiddleware(): void {
    // Security middleware
    this.app.use(helmet({
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
    this.app.use(cors({
      origin: process.env.CORS_ORIGIN?.split(',') || '*',
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'x-requested-with'],
    }));

    // Rate limiting
    const limiter = rateLimit({
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
    this.app.use(compression());
    this.app.use(express.json({ limit: '10mb' }));
    this.app.use(express.urlencoded({ extended: true, limit: '10mb' }));

    if (process.env.NODE_ENV === 'development') {
      this.app.use(morgan('dev'));
    } else {
      this.app.use(morgan('combined'));
    }

    // Static files
    this.app.use('/uploads', express.static(path.join(__dirname, '..', 'uploads')));
  }

  private initializeRoutes(): void {
    const apiVersion = process.env.API_VERSION || 'v1';
    const baseUrl = `/api/${apiVersion}`;

    // Health check route
    this.app.use(`${baseUrl}/health`, healthRoutes);

    // API routes
    this.app.use(`${baseUrl}/auth`, createAuthRoutes(this.database));
    this.app.use(`${baseUrl}/users`, userRoutes);
    this.app.use(`${baseUrl}/transactions`, createTransactionRoutes(this.database));
    this.app.use(`${baseUrl}/analytics`, createAnalyticsRoutes(this.database));

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

  private initializeErrorHandling(): void {
    // 404 handler
    this.app.use(notFoundHandler);

    // Global error handler
    this.app.use(errorHandler);
  }

  public async start(): Promise<void> {
    try {
      // Initialize database
      await this.database.initialize();
      logger.info('Database initialized successfully');

      // Start server - listen on all interfaces (0.0.0.0) for real device access
      this.app.listen(this.port, '0.0.0.0', () => {
        logger.info(`🚀 Finchron API Server running on port ${this.port}`);
        logger.info(`📊 Environment: ${process.env.NODE_ENV}`);
        logger.info(`🔗 API Base URL: http://localhost:${this.port}/api/${process.env.API_VERSION || 'v1'}`);
        logger.info(`🌐 Network Access: http://192.168.29.84:${this.port}/api/${process.env.API_VERSION || 'v1'}`);
        logger.info(`📚 Health Check: http://localhost:${this.port}/api/${process.env.API_VERSION || 'v1'}/health`);
      });
    } catch (error) {
      logger.error('Failed to start server:', error);
      process.exit(1);
    }
  }

  public getApp(): express.Application {
    return this.app;
  }

  public async stop(): Promise<void> {
    try {
      await this.database.close();
      logger.info('Server stopped gracefully');
    } catch (error) {
      logger.error('Error stopping server:', error);
    }
  }
}

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  process.exit(1);
});

// Handle unhandled promise rejections
process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
  process.exit(1);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  // Add graceful shutdown logic here
  process.exit(0);
});

process.on('SIGINT', async () => {
  logger.info('SIGINT signal received: closing HTTP server');
  // Add graceful shutdown logic here
  process.exit(0);
});

// Start server if this file is run directly
if (require.main === module) {
  const server = new Server();
  server.start();
}

export default Server;
