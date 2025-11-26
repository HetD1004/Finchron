"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const TransactionController_1 = require("../controllers/TransactionController");
const auth_1 = require("../middleware/auth");
const router = (0, express_1.Router)();
const transactionController = new TransactionController_1.TransactionController();
// All transaction routes require authentication
router.use(auth_1.authenticateToken);
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
exports.default = router;
//# sourceMappingURL=transactionRoutes.js.map