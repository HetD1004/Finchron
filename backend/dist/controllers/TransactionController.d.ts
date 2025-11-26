import { Response } from 'express';
import { AuthenticatedRequest } from '../middleware/auth';
export declare class TransactionController {
    private db;
    constructor();
    getTransactions(req: AuthenticatedRequest, res: Response): Promise<void>;
    getTransaction(req: AuthenticatedRequest, res: Response): Promise<void>;
    createTransaction(req: AuthenticatedRequest, res: Response): Promise<void>;
    updateTransaction(req: AuthenticatedRequest, res: Response): Promise<void>;
    deleteTransaction(req: AuthenticatedRequest, res: Response): Promise<void>;
}
//# sourceMappingURL=TransactionController.d.ts.map