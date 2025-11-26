"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const AnalyticsController_1 = require("../controllers/AnalyticsController");
const auth_1 = require("../middleware/auth");
const router = (0, express_1.Router)();
const analyticsController = new AnalyticsController_1.AnalyticsController();
// All analytics routes require authentication
router.use(auth_1.authenticateToken);
// Get user transaction summary
router.get('/summary', (req, res) => analyticsController.getSummary(req, res));
// Get category spending analytics
router.get('/categories', (req, res) => analyticsController.getCategoryAnalytics(req, res));
// Get monthly spending trends
router.get('/trends', (req, res) => analyticsController.getTrends(req, res));
// Get comprehensive dashboard data
router.get('/dashboard', (req, res) => analyticsController.getDashboard(req, res));
exports.default = router;
//# sourceMappingURL=analyticsRoutes.js.map