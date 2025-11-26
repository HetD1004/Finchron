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
export declare class Database {
    private db;
    private dbPath;
    constructor();
    initialize(): Promise<void>;
    private connect;
    private createTables;
    private runQuery;
    private getQuery;
    private allQuery;
    createUser(user: Omit<User, 'created_at' | 'updated_at'>): Promise<User>;
    getUserById(id: string): Promise<User | null>;
    getUserByEmail(email: string): Promise<User | null>;
    getUserByGoogleId(googleId: string): Promise<User | null>;
    updateUser(id: string, updates: Partial<User>): Promise<User>;
    createTransaction(transaction: Omit<Transaction, 'created_at' | 'updated_at'>): Promise<Transaction>;
    getTransactionById(id: string): Promise<Transaction | null>;
    getTransactionsByUserId(userId: string, limit?: number, offset?: number, filters?: {
        type?: 'income' | 'expense';
        category?: string;
        startDate?: string;
        endDate?: string;
    }): Promise<Transaction[]>;
    updateTransaction(id: string, updates: Partial<Transaction>): Promise<Transaction>;
    deleteTransaction(id: string): Promise<boolean>;
    getUserTransactionSummary(userId: string): Promise<{
        totalIncome: number;
        totalExpenses: number;
        balance: number;
        transactionCount: number;
    }>;
    getCategorySpending(userId: string, type: 'income' | 'expense'): Promise<Array<{
        category: string;
        total: number;
        count: number;
    }>>;
    getMonthlySpending(userId: string): Promise<Array<{
        month: string;
        income: number;
        expenses: number;
    }>>;
    close(): Promise<void>;
}
//# sourceMappingURL=Database.d.ts.map