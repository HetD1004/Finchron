import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/transaction/transaction_bloc.dart';
import '../bloc/transaction/transaction_state.dart';
import '../bloc/transaction/transaction_event.dart';
import '../models/transaction.dart';
import '../themes/app_colors.dart';
import '../services/currency_service.dart';
import '../services/date_format_service.dart';
import 'add_transaction_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _searchController = TextEditingController();
  final _dateFormatService = DateFormatService();
  TransactionType? _filterType;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    // Always ensure data is loaded when this screen is accessed
    Future.microtask(() {
      if (mounted) {
        final currentState = context.read<TransactionBloc>().state;
        if (currentState is! TransactionLoaded &&
            currentState is! TransactionLoading) {
          print('TransactionsScreen: Loading transactions...');
          context.read<TransactionBloc>().add(LoadTransactions());
        } else {
          print('TransactionsScreen: Transactions already loaded or loading');
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddTransactionScreen(),
                ),
              );
            },
            tooltip: 'Add Transaction',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(),
          Expanded(
            child: BlocBuilder<TransactionBloc, TransactionState>(
              builder: (context, state) {
                if (state is TransactionLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is TransactionError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${state.message}',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.read<TransactionBloc>().add(
                              LoadTransactions(),
                            );
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                } else if (state is TransactionLoaded) {
                  final filteredTransactions = _filterTransactions(
                    state.transactions,
                  );

                  if (filteredTransactions.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _hasActiveFilters()
                                ? 'No transactions match your filters'
                                : 'No transactions yet',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _hasActiveFilters()
                                ? 'Try adjusting your filters'
                                : 'Tap the + button to add your first transaction',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                          if (_hasActiveFilters()) ...[
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _clearFilters,
                              child: const Text('Clear Filters'),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = filteredTransactions[index];
                      return _buildTransactionItem(transaction);
                    },
                  );
                } else {
                  return const Center(child: Text('Something went wrong'));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search transactions...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
          if (_hasActiveFilters()) ...[
            const SizedBox(height: 12),
            _buildActiveFilters(),
          ],
        ],
      ),
    );
  }

  Widget _buildActiveFilters() {
    return Wrap(
      spacing: 8,
      children: [
        if (_filterType != null)
          Chip(
            label: Text(_filterType!.name.toUpperCase()),
            onDeleted: () {
              setState(() {
                _filterType = null;
              });
            },
            backgroundColor: _filterType == TransactionType.income
                ? AppColors.income.withOpacity(0.1)
                : AppColors.expense.withOpacity(0.1),
          ),
        if (_dateRange != null)
          Chip(
            label: Text(
              _dateFormatService.formatDateRange(
                _dateRange!.start,
                _dateRange!.end,
              ),
            ),
            onDeleted: () {
              setState(() {
                _dateRange = null;
              });
            },
          ),
      ],
    );
  }

  Widget _buildTransactionItem(Transaction transaction) {
    final currencyService = CurrencyService();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: Key(transaction.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.delete, color: Colors.white, size: 24),
              SizedBox(height: 4),
              Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        confirmDismiss: (direction) => _showDeleteConfirmation(transaction),
        onDismissed: (direction) {
          // This will only be called if confirmDismiss returns true
          context.read<TransactionBloc>().add(
            DeleteTransaction(transactionId: transaction.id),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Transaction deleted'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Undo',
                textColor: Colors.white,
                onPressed: () {
                  // Note: Implementing undo would require storing the deleted transaction
                  // and re-adding it. For now, we'll just reload transactions.
                  context.read<TransactionBloc>().add(LoadTransactions());
                },
              ),
            ),
          );
        },
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor:
                (transaction.type == TransactionType.income
                        ? AppColors.income
                        : AppColors.expense)
                    .withOpacity(0.1),
            child: Icon(
              _getCategoryIcon(transaction.category),
              color: transaction.type == TransactionType.income
                  ? AppColors.income
                  : AppColors.expense,
            ),
          ),
          title: Text(
            transaction.category.name.toUpperCase(),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (transaction.notes != null && transaction.notes!.isNotEmpty)
                Text(transaction.notes!),
              Text(
                _dateFormatService.formatDateWithPattern(
                  transaction.date,
                  showTime: true,
                  shortMonth: true,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${transaction.type == TransactionType.income ? '+' : '-'}${currencyService.currentSymbol}${transaction.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: transaction.type == TransactionType.income
                          ? AppColors.income
                          : AppColors.expense,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 20, color: Colors.grey[600]),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              AddTransactionScreen(transaction: transaction),
                        ),
                      );
                      break;
                    case 'delete':
                      _confirmAndDeleteTransaction(transaction);
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) =>
                    AddTransactionScreen(transaction: transaction),
              ),
            );
          },
        ),
      ),
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

  List<Transaction> _filterTransactions(List<Transaction> transactions) {
    var filtered = transactions;

    // Filter by search text
    if (_searchController.text.isNotEmpty) {
      final searchText = _searchController.text.toLowerCase();
      filtered = filtered.where((transaction) {
        return transaction.category.name.toLowerCase().contains(searchText) ||
            (transaction.notes?.toLowerCase().contains(searchText) ?? false);
      }).toList();
    }

    // Filter by type
    if (_filterType != null) {
      filtered = filtered.where((transaction) {
        return transaction.type == _filterType;
      }).toList();
    }

    // Filter by date range
    if (_dateRange != null) {
      filtered = filtered.where((transaction) {
        return transaction.date.isAfter(
              _dateRange!.start.subtract(const Duration(days: 1)),
            ) &&
            transaction.date.isBefore(
              _dateRange!.end.add(const Duration(days: 1)),
            );
      }).toList();
    }

    // Sort by date (newest first)
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return filtered;
  }

  bool _hasActiveFilters() {
    return _filterType != null || _dateRange != null;
  }

  void _clearFilters() {
    setState(() {
      _filterType = null;
      _dateRange = null;
      _searchController.clear();
    });
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Transactions'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Transaction Type'),
              trailing: DropdownButton<TransactionType?>(
                value: _filterType,
                hint: const Text('All'),
                items: [
                  const DropdownMenuItem<TransactionType?>(
                    value: null,
                    child: Text('All'),
                  ),
                  ...TransactionType.values.map((type) {
                    return DropdownMenuItem<TransactionType>(
                      value: type,
                      child: Text(type.name.toUpperCase()),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterType = value;
                  });
                  Navigator.of(context).pop();
                },
              ),
            ),
            ListTile(
              title: const Text('Date Range'),
              trailing: TextButton(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _dateRange,
                  );
                  if (picked != null) {
                    setState(() {
                      _dateRange = picked;
                    });
                    Navigator.of(context).pop();
                  }
                },
                child: Text(_dateRange != null ? 'Change' : 'Select'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _clearFilters();
              Navigator.of(context).pop();
            },
            child: const Text('Clear All'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteConfirmation(Transaction transaction) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red[700]),
              const SizedBox(width: 8),
              const Text('Delete Transaction'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Are you sure you want to delete this transaction?'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(transaction.category),
                      color: transaction.type == TransactionType.income
                          ? AppColors.income
                          : AppColors.expense,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transaction.category.name.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (transaction.notes != null &&
                              transaction.notes!.isNotEmpty)
                            Text(
                              transaction.notes!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          Text(
                            '${transaction.type == TransactionType.income ? '+' : '-'}\$${transaction.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: transaction.type == TransactionType.income
                                  ? AppColors.income
                                  : AppColors.expense,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _confirmAndDeleteTransaction(Transaction transaction) async {
    final confirmed = await _showDeleteConfirmation(transaction);
    if (confirmed == true) {
      context.read<TransactionBloc>().add(
        DeleteTransaction(transactionId: transaction.id),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction deleted'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
