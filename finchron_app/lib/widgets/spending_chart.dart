import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/transaction/transaction_bloc.dart';
import '../bloc/transaction/transaction_state.dart';
import '../models/transaction.dart';
import '../themes/app_colors.dart';
import '../services/currency_service.dart';

class SpendingChart extends StatelessWidget {
  const SpendingChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spending Overview',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            BlocBuilder<TransactionBloc, TransactionState>(
              builder: (context, state) {
                if (state is TransactionLoading) {
                  return const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                
                if (state is TransactionLoaded) {
                  if (state.transactions.isEmpty) {
                    return const SizedBox(
                      height: 200,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.pie_chart_outline, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'No spending data yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  return _buildSpendingOverview(state.transactions);
                }
                
                return const SizedBox(
                  height: 200,
                  child: Center(
                    child: Text('Unable to load chart data'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpendingOverview(List<Transaction> transactions) {
    final currencyService = CurrencyService();
    
    // Filter expense transactions from current month
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 0);
    
    final expenseTransactions = transactions.where((transaction) {
      return transaction.type == TransactionType.expense &&
             transaction.date.isAfter(currentMonthStart.subtract(const Duration(days: 1))) &&
             transaction.date.isBefore(currentMonthEnd.add(const Duration(days: 1)));
    }).toList();

    if (expenseTransactions.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.trending_down, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'No expenses this month',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Group expenses by category
    final Map<TransactionCategory, double> categoryTotals = {};
    double totalExpenses = 0;
    
    for (final transaction in expenseTransactions) {
      categoryTotals[transaction.category] = 
          (categoryTotals[transaction.category] ?? 0) + transaction.amount;
      totalExpenses += transaction.amount;
    }

    // Sort categories by amount (highest first)
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take top 5 categories
    final topCategories = sortedCategories.take(5).toList();

    return Column(
      children: [
        // Total expenses header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.expense.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                'This Month\'s Expenses',
                style: TextStyle(
                  fontSize: 14,
                  color: const Color.fromARGB(255, 255, 255, 255),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${currencyService.currentSymbol}${totalExpenses.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.expense,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Category breakdown
        ...topCategories.map((entry) {
          final category = entry.key;
          final amount = entry.value;
          final percentage = (amount / totalExpenses * 100);
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // Category icon and name
                SizedBox(
                  width: 100,
                  child: Row(
                    children: [
                      Icon(
                        _getCategoryIcon(category),
                        size: 16,
                        color: AppColors.expense,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getCategoryName(category),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Progress bar
                Expanded(
                  child: Container(
                    height: 20,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: percentage / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.expense.withOpacity(0.7),
                                  AppColors.expense,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        Center(
                          child: Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: percentage > 50 ? Colors.grey[700] : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Amount
                SizedBox(
                  width: 70,
                  child: Text(
                    '${currencyService.currentSymbol}${amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.expense,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }),
        
        if (sortedCategories.length > 5) ...[
          const SizedBox(height: 8),
          Text(
            '+ ${sortedCategories.length - 5} more categories',
            style: TextStyle(
              fontSize: 12,
              color: const Color.fromARGB(255, 255, 255, 255),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  IconData _getCategoryIcon(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.food:
        return Icons.restaurant;
      case TransactionCategory.transport:
        return Icons.directions_car;
      case TransactionCategory.entertainment:
        return Icons.movie;
      case TransactionCategory.shopping:
        return Icons.shopping_bag;
      case TransactionCategory.health:
        return Icons.local_hospital;
      case TransactionCategory.education:
        return Icons.school;
      case TransactionCategory.travel:
        return Icons.flight;
      case TransactionCategory.utilities:
        return Icons.flash_on;
      case TransactionCategory.groceries:
        return Icons.local_grocery_store;
      case TransactionCategory.salary:
        return Icons.work;
      case TransactionCategory.freelance:
        return Icons.laptop;
      case TransactionCategory.investment:
        return Icons.trending_up;
      case TransactionCategory.gift:
        return Icons.card_giftcard;
      case TransactionCategory.others:
        return Icons.more_horiz;
    }
  }

  String _getCategoryName(TransactionCategory category) {
    switch (category) {
      case TransactionCategory.food:
        return 'Food';
      case TransactionCategory.transport:
        return 'Transport';
      case TransactionCategory.entertainment:
        return 'Entertainment';
      case TransactionCategory.shopping:
        return 'Shopping';
      case TransactionCategory.health:
        return 'Health';
      case TransactionCategory.education:
        return 'Education';
      case TransactionCategory.travel:
        return 'Travel';
      case TransactionCategory.utilities:
        return 'Utilities';
      case TransactionCategory.groceries:
        return 'Groceries';
      case TransactionCategory.salary:
        return 'Salary';
      case TransactionCategory.freelance:
        return 'Freelance';
      case TransactionCategory.investment:
        return 'Investment';
      case TransactionCategory.gift:
        return 'Gift';
      case TransactionCategory.others:
        return 'Others';
    }
  }
}
