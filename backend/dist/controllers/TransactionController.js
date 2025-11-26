"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TransactionController = void 0;
const uuid_1 = require("uuid");
const Database_1 = require("../database/Database");
const logger_1 = require("../utils/logger");
class TransactionController {
    constructor() {
        this.db = new Database_1.Database();
    }
    // Get all transactions for authenticated user
    async getTransactions(req, res) {
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
            const page = parseInt(req.query.page) || 1;
            const limit = parseInt(req.query.limit) || 50;
            const offset = (page - 1) * limit;
            // Parse filters
            const filters = {};
            if (req.query.type && (req.query.type === 'income' || req.query.type === 'expense')) {
                filters.type = req.query.type;
            }
            if (req.query.category) {
                filters.category = req.query.category;
            }
            if (req.query.startDate) {
                filters.startDate = req.query.startDate;
            }
            if (req.query.endDate) {
                filters.endDate = req.query.endDate;
            }
            const transactions = await this.db.getTransactionsByUserId(req.user.id, limit, offset, filters);
            res.json({
                message: 'Transactions retrieved successfully',
                data: transactions,
                pagination: {
                    page,
                    limit,
                    hasMore: transactions.length === limit,
                },
                filters,
            });
        }
        catch (error) {
            logger_1.logger.error('Get transactions error:', error);
            res.status(500).json({
                error: {
                    message: 'Internal server error while retrieving transactions',
                    status: 500,
                },
            });
        }
    }
    // Get single transaction by ID
    async getTransaction(req, res) {
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
            const { id } = req.params;
            const transaction = await this.db.getTransactionById(id);
            if (!transaction) {
                res.status(404).json({
                    error: {
                        message: 'Transaction not found',
                        status: 404,
                    },
                });
                return;
            }
            // Check if transaction belongs to authenticated user
            if (transaction.user_id !== req.user.id) {
                res.status(403).json({
                    error: {
                        message: 'Access denied',
                        status: 403,
                    },
                });
                return;
            }
            res.json({
                message: 'Transaction retrieved successfully',
                data: transaction,
            });
        }
        catch (error) {
            logger_1.logger.error('Get transaction error:', error);
            res.status(500).json({
                error: {
                    message: 'Internal server error while retrieving transaction',
                    status: 500,
                },
            });
        }
    }
    // Create new transaction
    async createTransaction(req, res) {
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
            const { type, category, amount, notes, date } = req.body;
            // Validation
            if (!type || !category || !amount || !date) {
                res.status(400).json({
                    error: {
                        message: 'Type, category, amount, and date are required',
                        status: 400,
                    },
                });
                return;
            }
            if (type !== 'income' && type !== 'expense') {
                res.status(400).json({
                    error: {
                        message: 'Type must be either "income" or "expense"',
                        status: 400,
                    },
                });
                return;
            }
            if (typeof amount !== 'number' || amount <= 0) {
                res.status(400).json({
                    error: {
                        message: 'Amount must be a positive number',
                        status: 400,
                    },
                });
                return;
            }
            // Validate date format
            const transactionDate = new Date(date);
            if (isNaN(transactionDate.getTime())) {
                res.status(400).json({
                    error: {
                        message: 'Invalid date format',
                        status: 400,
                    },
                });
                return;
            }
            // Create transaction
            const transactionId = (0, uuid_1.v4)();
            const transaction = await this.db.createTransaction({
                id: transactionId,
                user_id: req.user.id,
                type,
                category,
                amount,
                notes: notes || null,
                date: transactionDate.toISOString(),
            });
            logger_1.logger.info(`Transaction created: ${transaction.id} for user: ${req.user.id}`);
            res.status(201).json({
                message: 'Transaction created successfully',
                data: transaction,
            });
        }
        catch (error) {
            logger_1.logger.error('Create transaction error:', error);
            res.status(500).json({
                error: {
                    message: 'Internal server error while creating transaction',
                    status: 500,
                },
            });
        }
    }
    // Update existing transaction
    async updateTransaction(req, res) {
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
            const { id } = req.params;
            const { type, category, amount, notes, date } = req.body;
            // Check if transaction exists and belongs to user
            const existingTransaction = await this.db.getTransactionById(id);
            if (!existingTransaction) {
                res.status(404).json({
                    error: {
                        message: 'Transaction not found',
                        status: 404,
                    },
                });
                return;
            }
            if (existingTransaction.user_id !== req.user.id) {
                res.status(403).json({
                    error: {
                        message: 'Access denied',
                        status: 403,
                    },
                });
                return;
            }
            // Prepare updates
            const updates = {};
            if (type !== undefined) {
                if (type !== 'income' && type !== 'expense') {
                    res.status(400).json({
                        error: {
                            message: 'Type must be either "income" or "expense"',
                            status: 400,
                        },
                    });
                    return;
                }
                updates.type = type;
            }
            if (category !== undefined) {
                updates.category = category;
            }
            if (amount !== undefined) {
                if (typeof amount !== 'number' || amount <= 0) {
                    res.status(400).json({
                        error: {
                            message: 'Amount must be a positive number',
                            status: 400,
                        },
                    });
                    return;
                }
                updates.amount = amount;
            }
            if (notes !== undefined) {
                updates.notes = notes;
            }
            if (date !== undefined) {
                const transactionDate = new Date(date);
                if (isNaN(transactionDate.getTime())) {
                    res.status(400).json({
                        error: {
                            message: 'Invalid date format',
                            status: 400,
                        },
                    });
                    return;
                }
                updates.date = transactionDate.toISOString();
            }
            // Update transaction
            const updatedTransaction = await this.db.updateTransaction(id, updates);
            logger_1.logger.info(`Transaction updated: ${id} for user: ${req.user.id}`);
            res.json({
                message: 'Transaction updated successfully',
                data: updatedTransaction,
            });
        }
        catch (error) {
            logger_1.logger.error('Update transaction error:', error);
            res.status(500).json({
                error: {
                    message: 'Internal server error while updating transaction',
                    status: 500,
                },
            });
        }
    }
    // Delete transaction
    async deleteTransaction(req, res) {
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
            const { id } = req.params;
            // Check if transaction exists and belongs to user
            const existingTransaction = await this.db.getTransactionById(id);
            if (!existingTransaction) {
                res.status(404).json({
                    error: {
                        message: 'Transaction not found',
                        status: 404,
                    },
                });
                return;
            }
            if (existingTransaction.user_id !== req.user.id) {
                res.status(403).json({
                    error: {
                        message: 'Access denied',
                        status: 403,
                    },
                });
                return;
            }
            // Delete transaction
            await this.db.deleteTransaction(id);
            logger_1.logger.info(`Transaction deleted: ${id} for user: ${req.user.id}`);
            res.json({
                message: 'Transaction deleted successfully',
            });
        }
        catch (error) {
            logger_1.logger.error('Delete transaction error:', error);
            res.status(500).json({
                error: {
                    message: 'Internal server error while deleting transaction',
                    status: 500,
                },
            });
        }
    }
}
exports.TransactionController = TransactionController;
//# sourceMappingURL=TransactionController.js.map