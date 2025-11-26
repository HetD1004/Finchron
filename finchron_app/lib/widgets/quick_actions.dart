import 'package:flutter/material.dart';
import '../themes/app_colors.dart';
import '../screens/add_transaction_screen.dart';
import '../models/transaction.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  context,
                  'Add Income',
                  Icons.add_circle,
                  AppColors.income,
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AddTransactionScreen(
                          defaultType: TransactionType.income,
                        ),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  context,
                  'Add Expense',
                  Icons.remove_circle,
                  AppColors.expense,
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AddTransactionScreen(
                          defaultType: TransactionType.expense,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
