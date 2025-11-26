import { Router } from 'express';
import { AnalyticsController } from '../controllers/AnalyticsController';
import { authenticateToken } from '../middleware/auth';
import { Database } from '../database/Database';

function createAnalyticsRoutes(database: Database): Router {
  const router = Router();
  const analyticsController = new AnalyticsController(database);

  // All analytics routes require authentication
  router.use(authenticateToken);

  // Get user transaction summary
  router.get('/summary', (req, res) => analyticsController.getSummary(req, res));

  // Get category spending analytics
  router.get('/categories', (req, res) => analyticsController.getCategoryAnalytics(req, res));

  // Get monthly spending trends
  router.get('/trends', (req, res) => analyticsController.getTrends(req, res));

  // Get comprehensive dashboard data
  router.get('/dashboard', (req, res) => analyticsController.getDashboard(req, res));

  return router;
}

export default createAnalyticsRoutes;
