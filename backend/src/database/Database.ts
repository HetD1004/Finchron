import sqlite3 from 'sqlite3';
import { Database as SqliteDatabase } from 'sqlite3';
import path from 'path';
import fs from 'fs';
import { logger } from '../utils/logger';

export interface User {
  id: string;
  email: string;
  name: string;
  password_hash: string;
  profile_picture_url?: string;
  google_id?: string;
  created_at: string;
  updated_at: string;
}

export interface Transaction {
  id: string;
  user_id: string;
  type: 'income' | 'expense';
  category: string;
  amount: number;
  notes?: string;
  date: string;
  created_at: string;
  updated_at: string;
}

export class Database {
  private db: SqliteDatabase | null = null;
  private dbPath: string;

  constructor() {
    this.dbPath = process.env.DB_PATH || './data/finchron.db';
  }

  async initialize(): Promise<void> {
    try {
      // Create data directory if it doesn't exist
      const dataDir = path.dirname(this.dbPath);
      if (!fs.existsSync(dataDir)) {
        fs.mkdirSync(dataDir, { recursive: true });
      }

      // Initialize SQLite database
      await this.connect();
      await this.createTables();
      
      logger.info('Database initialized successfully');
    } catch (error) {
      logger.error('Failed to initialize database:', error);
      throw error;
    }
  }

  private async connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.db = new sqlite3.Database(this.dbPath, (err) => {
        if (err) {
          logger.error('Error opening database:', err);
          reject(err);
        } else {
          logger.info(`Connected to SQLite database at ${this.dbPath}`);
          resolve();
        }
      });
    });
  }

  private async createTables(): Promise<void> {
    if (!this.db) {
      throw new Error('Database not connected');
    }

    const userTableQuery = `
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        password_hash TEXT,
        profile_picture_url TEXT,
        google_id TEXT UNIQUE,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `;

    const transactionTableQuery = `
      CREATE TABLE IF NOT EXISTS transactions (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        type TEXT CHECK(type IN ('income', 'expense')) NOT NULL,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        notes TEXT,
        date DATETIME NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    `;

    const indexQueries = [
      'CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON transactions(user_id)',
      'CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date)',
      'CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type)',
      'CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category)',
      'CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)',
      'CREATE INDEX IF NOT EXISTS idx_users_google_id ON users(google_id)',
    ];

    try {
      await this.runQuery(userTableQuery);
      await this.runQuery(transactionTableQuery);
      
      for (const indexQuery of indexQueries) {
        await this.runQuery(indexQuery);
      }
      
      logger.info('Database tables created successfully');
    } catch (error) {
      logger.error('Error creating tables:', error);
      throw error;
    }
  }

  private runQuery(query: string, params: any[] = []): Promise<any> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not connected'));
        return;
      }

      this.db.run(query, params, function(err) {
        if (err) {
          reject(err);
        } else {
          resolve({ lastID: this.lastID, changes: this.changes });
        }
      });
    });
  }

  private getQuery(query: string, params: any[] = []): Promise<any> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not connected'));
        return;
      }

      this.db.get(query, params, (err, row) => {
        if (err) {
          reject(err);
        } else {
          resolve(row);
        }
      });
    });
  }

  private allQuery(query: string, params: any[] = []): Promise<any[]> {
    return new Promise((resolve, reject) => {
      if (!this.db) {
        reject(new Error('Database not connected'));
        return;
      }

      this.db.all(query, params, (err, rows) => {
        if (err) {
          reject(err);
        } else {
          resolve(rows);
        }
      });
    });
  }

  // User operations
  async createUser(user: Omit<User, 'created_at' | 'updated_at'>): Promise<User> {
    const query = `
      INSERT INTO users (id, email, name, password_hash, profile_picture_url, google_id)
      VALUES (?, ?, ?, ?, ?, ?)
    `;
    
    await this.runQuery(query, [
      user.id,
      user.email,
      user.name,
      user.password_hash,
      user.profile_picture_url || null,
      user.google_id || null,
    ]);

    const createdUser = await this.getUserById(user.id);
    if (!createdUser) {
      throw new Error('Failed to create user');
    }
    return createdUser;
  }

  async getUserById(id: string): Promise<User | null> {
    const query = 'SELECT * FROM users WHERE id = ?';
    return this.getQuery(query, [id]);
  }

  async getUserByEmail(email: string): Promise<User | null> {
    const query = 'SELECT * FROM users WHERE email = ?';
    return this.getQuery(query, [email]);
  }

  async getUserByGoogleId(googleId: string): Promise<User | null> {
    const query = 'SELECT * FROM users WHERE google_id = ?';
    return this.getQuery(query, [googleId]);
  }

  async updateUser(id: string, updates: Partial<User>): Promise<User> {
    const setClause = Object.keys(updates)
      .map(key => `${key} = ?`)
      .join(', ');
    
    const query = `UPDATE users SET ${setClause}, updated_at = CURRENT_TIMESTAMP WHERE id = ?`;
    const params = [...Object.values(updates), id];
    
    await this.runQuery(query, params);
    const updatedUser = await this.getUserById(id);
    if (!updatedUser) {
      throw new Error('User not found');
    }
    return updatedUser;
  }

  // Transaction operations
  async createTransaction(transaction: Omit<Transaction, 'created_at' | 'updated_at'>): Promise<Transaction> {
    const query = `
      INSERT INTO transactions (id, user_id, type, category, amount, notes, date)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `;
    
    await this.runQuery(query, [
      transaction.id,
      transaction.user_id,
      transaction.type,
      transaction.category,
      transaction.amount,
      transaction.notes || null,
      transaction.date,
    ]);

    const createdTransaction = await this.getTransactionById(transaction.id);
    if (!createdTransaction) {
      throw new Error('Failed to create transaction');
    }
    return createdTransaction;
  }

  async getTransactionById(id: string): Promise<Transaction | null> {
    const query = 'SELECT * FROM transactions WHERE id = ?';
    return this.getQuery(query, [id]);
  }

  async getTransactionsByUserId(
    userId: string,
    limit: number = 100,
    offset: number = 0,
    filters?: {
      type?: 'income' | 'expense';
      category?: string;
      startDate?: string;
      endDate?: string;
    }
  ): Promise<Transaction[]> {
    let query = 'SELECT * FROM transactions WHERE user_id = ?';
    const params: any[] = [userId];

    if (filters) {
      if (filters.type) {
        query += ' AND type = ?';
        params.push(filters.type);
      }
      if (filters.category) {
        query += ' AND category = ?';
        params.push(filters.category);
      }
      if (filters.startDate) {
        query += ' AND date >= ?';
        params.push(filters.startDate);
      }
      if (filters.endDate) {
        query += ' AND date <= ?';
        params.push(filters.endDate);
      }
    }

    query += ' ORDER BY date DESC, created_at DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);

    return this.allQuery(query, params);
  }

  async updateTransaction(id: string, updates: Partial<Transaction>): Promise<Transaction> {
    const setClause = Object.keys(updates)
      .map(key => `${key} = ?`)
      .join(', ');
    
    const query = `UPDATE transactions SET ${setClause}, updated_at = CURRENT_TIMESTAMP WHERE id = ?`;
    const params = [...Object.values(updates), id];
    
    await this.runQuery(query, params);
    const updatedTransaction = await this.getTransactionById(id);
    if (!updatedTransaction) {
      throw new Error('Transaction not found');
    }
    return updatedTransaction;
  }

  async deleteTransaction(id: string): Promise<boolean> {
    const query = 'DELETE FROM transactions WHERE id = ?';
    const result = await this.runQuery(query, [id]);
    return result.changes > 0;
  }

  // Analytics operations
  async getUserTransactionSummary(userId: string): Promise<{
    totalIncome: number;
    totalExpenses: number;
    balance: number;
    transactionCount: number;
  }> {
    const query = `
      SELECT 
        SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as total_income,
        SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as total_expenses,
        COUNT(*) as transaction_count
      FROM transactions 
      WHERE user_id = ?
    `;
    
    const result = await this.getQuery(query, [userId]);
    
    return {
      totalIncome: result.total_income || 0,
      totalExpenses: result.total_expenses || 0,
      balance: (result.total_income || 0) - (result.total_expenses || 0),
      transactionCount: result.transaction_count || 0,
    };
  }

  async getCategorySpending(userId: string, type: 'income' | 'expense'): Promise<Array<{
    category: string;
    total: number;
    count: number;
  }>> {
    const query = `
      SELECT 
        category,
        SUM(amount) as total,
        COUNT(*) as count
      FROM transactions 
      WHERE user_id = ? AND type = ?
      GROUP BY category
      ORDER BY total DESC
    `;
    
    return this.allQuery(query, [userId, type]);
  }

  async getMonthlySpending(userId: string): Promise<Array<{
    month: string;
    income: number;
    expenses: number;
  }>> {
    const query = `
      SELECT 
        strftime('%Y-%m', date) as month,
        SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) as income,
        SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) as expenses
      FROM transactions 
      WHERE user_id = ?
      GROUP BY strftime('%Y-%m', date)
      ORDER BY month DESC
      LIMIT 12
    `;
    
    return this.allQuery(query, [userId]);
  }

  async close(): Promise<void> {
    return new Promise((resolve) => {
      if (this.db) {
        this.db.close((err) => {
          if (err) {
            logger.error('Error closing database:', err);
          } else {
            logger.info('Database connection closed');
          }
          resolve();
        });
      } else {
        resolve();
      }
    });
  }
}
