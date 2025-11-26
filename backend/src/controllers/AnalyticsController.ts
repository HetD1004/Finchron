import { Response } from 'express';
import { Database } from '../database/Database';
import { AuthenticatedRequest } from '../middleware/auth';
import { logger } from '../utils/logger';

export class AnalyticsController {
  private db: Database;

  constructor(database: Database) {
    this.db = database;
  }

  // Get user transaction summary
  async getSummary(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      if (!req.user) {
        res.status(401).json({
          error: {
            message: 'Authentication required',
            status: 401,
          },
        });
        return;
      }

      const summary = await this.db.getUserTransactionSummary(req.user.id);

      res.json({
        message: 'Summary retrieved successfully',
        data: summary,
      });
    } catch (error) {
      logger.error('Get summary error:', error);
      res.status(500).json({
        error: {
          message: 'Internal server error while retrieving summary',
          status: 500,
        },
      });
    }
  }

  // Get category spending analytics
  async getCategoryAnalytics(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      if (!req.user) {
        res.status(401).json({
          error: {
            message: 'Authentication required',
            status: 401,
          },
        });
        return;
      }

      const type = req.query.type as 'income' | 'expense';
      
      if (!type || (type !== 'income' && type !== 'expense')) {
        res.status(400).json({
          error: {
            message: 'Type parameter is required and must be either "income" or "expense"',
            status: 400,
          },
        });
        return;
      }

      const categoryData = await this.db.getCategorySpending(req.user.id, type);

      res.json({
        message: 'Category analytics retrieved successfully',
        data: {
          type,
          categories: categoryData,
        },
      });
    } catch (error) {
      logger.error('Get category analytics error:', error);
      res.status(500).json({
        error: {
          message: 'Internal server error while retrieving category analytics',
          status: 500,
        },
      });
    }
  }

  // Get monthly spending trends
  async getTrends(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      if (!req.user) {
        res.status(401).json({
          error: {
            message: 'Authentication required',
            status: 401,
          },
        });
        return;
      }

      const monthlyData = await this.db.getMonthlySpending(req.user.id);

      res.json({
        message: 'Trends retrieved successfully',
        data: {
          monthlySpending: monthlyData,
        },
      });
    } catch (error) {
      logger.error('Get trends error:', error);
      res.status(500).json({
        error: {
          message: 'Internal server error while retrieving trends',
          status: 500,
        },
      });
    }
  }

  // Get comprehensive analytics dashboard data
  async getDashboard(req: AuthenticatedRequest, res: Response): Promise<void> {
    try {
      if (!req.user) {
        res.status(401).json({
          error: {
            message: 'Authentication required',
            status: 401,
          },
        });
        return;
      }

      // Get all analytics data in parallel
      const [summary, incomeCategories, expenseCategories, monthlyTrends] = await Promise.all([
        this.db.getUserTransactionSummary(req.user.id),
        this.db.getCategorySpending(req.user.id, 'income'),
        this.db.getCategorySpending(req.user.id, 'expense'),
        this.db.getMonthlySpending(req.user.id),
      ]);

      res.json({
        message: 'Dashboard analytics retrieved successfully',
        data: {
          summary,
          categoryBreakdown: {
            income: incomeCategories,
            expenses: expenseCategories,
          },
          monthlyTrends,
        },
      });
    } catch (error) {
      logger.error('Get dashboard error:', error);
      res.status(500).json({
        error: {
          message: 'Internal server error while retrieving dashboard data',
          status: 500,
        },
      });
    }
  }
}
