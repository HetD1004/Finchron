import { Response } from 'express';
import { AuthenticatedRequest } from '../middleware/auth';
export declare class AnalyticsController {
    private db;
    constructor();
    getSummary(req: AuthenticatedRequest, res: Response): Promise<void>;
    getCategoryAnalytics(req: AuthenticatedRequest, res: Response): Promise<void>;
    getTrends(req: AuthenticatedRequest, res: Response): Promise<void>;
    getDashboard(req: AuthenticatedRequest, res: Response): Promise<void>;
}
//# sourceMappingURL=AnalyticsController.d.ts.map