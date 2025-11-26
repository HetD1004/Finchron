import { Router } from 'express';
import { TransactionController } from '../controllers/TransactionController';
import { authenticateToken } from '../middleware/auth';
import { Database } from '../database/Database';

function createTransactionRoutes(database: Database): Router {
  const router = Router();
  const transactionController = new TransactionController(database);

  // All transaction routes require authentication
  router.use(authenticateToken);

  // Get all transactions for authenticated user
  router.get('/', (req, res) => transactionController.getTransactions(req, res));

  // Create new transaction
  router.post('/', (req, res) => transactionController.createTransaction(req, res));

  // Get specific transaction by ID
  router.get('/:id', (req, res) => transactionController.getTransaction(req, res));

  // Update specific transaction
  router.put('/:id', (req, res) => transactionController.updateTransaction(req, res));

  // Delete specific transaction
  router.delete('/:id', (req, res) => transactionController.deleteTransaction(req, res));

  return router;
}

export default createTransactionRoutes;
