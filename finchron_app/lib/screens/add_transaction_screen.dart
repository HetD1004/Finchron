import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/transaction/transaction_bloc.dart';
import '../bloc/transaction/transaction_event.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../models/transaction.dart';
import '../themes/app_colors.dart';
import '../widgets/custom_button.dart';
import '../services/currency_service.dart';
import '../services/date_format_service.dart';

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction; // For editing existing transactions
  final TransactionType? defaultType; // Default transaction type

  const AddTransactionScreen({super.key, this.transaction, this.defaultType});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _currencyService = CurrencyService();
  final _dateFormatService = DateFormatService();

  TransactionType _selectedType = TransactionType.expense;
  TransactionCategory _selectedCategory = TransactionCategory.food;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _initializeEditMode();
    } else if (widget.defaultType != null) {
      _selectedType = widget.defaultType!;
    }
  }

  void _initializeEditMode() {
    final transaction = widget.transaction!;
    _amountController.text = transaction.amount.toString();
    _notesController.text = transaction.notes ?? '';
    _selectedType = transaction.type;
    _selectedCategory = transaction.category;
    _selectedDate = transaction.date;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated) {
        // User is not authenticated, show error
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to add transactions'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final userId = authState.user.id;

      final amount = double.parse(_amountController.text);
      final notes = _notesController.text.trim();

      final transaction = Transaction(
        id:
            widget.transaction?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        type: _selectedType,
        category: _selectedCategory,
        amount: amount,
        date: _selectedDate,
        notes: notes.isEmpty ? null : notes,
        createdAt: widget.transaction?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.transaction != null) {
        context.read<TransactionBloc>().add(
          UpdateTransaction(transaction: transaction),
        );
      } else {
        context.read<TransactionBloc>().add(
          AddTransaction(transaction: transaction),
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.transaction != null
                  ? 'Transaction updated successfully!'
                  : 'Transaction added successfully!',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving transaction: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction != null ? 'Edit Transaction' : 'Add Transaction',
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Transaction Type Toggle
                _buildTypeSelector(),
                const SizedBox(height: 24),

                // Amount Input
                _buildAmountInput(),
                const SizedBox(height: 24),

                // Category Selector
                _buildCategorySelector(),
                const SizedBox(height: 24),

                // Date Picker
                _buildDatePicker(),
                const SizedBox(height: 24),

                // Notes Input
                _buildNotesInput(),
                const SizedBox(height: 32),

                // Save Button
                CustomButton(
                  text: widget.transaction != null
                      ? 'Update Transaction'
                      : 'Add Transaction',
                  onPressed: _isLoading ? null : _saveTransaction,
                  isFullWidth: true,
                  isLoading: _isLoading,
                  icon: widget.transaction != null ? Icons.update : Icons.add,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transaction Type',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedType = TransactionType.income;
                      if (_selectedCategory == TransactionCategory.food ||
                          _selectedCategory == TransactionCategory.transport ||
                          _selectedCategory == TransactionCategory.shopping ||
                          _selectedCategory ==
                              TransactionCategory.entertainment) {
                        _selectedCategory = TransactionCategory.salary;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _selectedType == TransactionType.income
                          ? AppColors.income
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.trending_up,
                          color: _selectedType == TransactionType.income
                              ? Colors.white
                              : AppColors.income,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Income',
                          style: TextStyle(
                            color: _selectedType == TransactionType.income
                                ? Colors.white
                                : AppColors.income,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedType = TransactionType.expense;
                      if (_selectedCategory == TransactionCategory.salary ||
                          _selectedCategory == TransactionCategory.freelance ||
                          _selectedCategory == TransactionCategory.investment) {
                        _selectedCategory = TransactionCategory.food;
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _selectedType == TransactionType.expense
                          ? AppColors.expense
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.trending_down,
                          color: _selectedType == TransactionType.expense
                              ? Colors.white
                              : AppColors.expense,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Expense',
                          style: TextStyle(
                            color: _selectedType == TransactionType.expense
                                ? Colors.white
                                : AppColors.expense,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            hintText: '0.00',
            prefixIcon: Container(
              width: 48,
              alignment: Alignment.center,
              child: Text(
                _currencyService.currentSymbol,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _selectedType == TransactionType.income
                      ? AppColors.income
                      : AppColors.expense,
                ),
              ),
            ),
          ),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: _selectedType == TransactionType.income
                ? AppColors.income
                : AppColors.expense,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter an amount';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return 'Please enter a valid amount';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    final categories = _selectedType == TransactionType.income
        ? [
            TransactionCategory.salary,
            TransactionCategory.freelance,
            TransactionCategory.investment,
            TransactionCategory.gift,
            TransactionCategory.others,
          ]
        : [
            TransactionCategory.food,
            TransactionCategory.transport,
            TransactionCategory.shopping,
            TransactionCategory.entertainment,
            TransactionCategory.health,
            TransactionCategory.education,
            TransactionCategory.travel,
            TransactionCategory.utilities,
            TransactionCategory.groceries,
            TransactionCategory.others,
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<TransactionCategory>(
          initialValue: categories.contains(_selectedCategory)
              ? _selectedCategory
              : categories.first,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.category)),
          items: categories.map((category) {
            return DropdownMenuItem<TransactionCategory>(
              value: category,
              child: Row(
                children: [
                  Text(category.iconData, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Text(category.displayName),
                ],
              ),
            );
          }).toList(),
          onChanged: (TransactionCategory? newValue) {
            if (newValue != null) {
              setState(() {
                _selectedCategory = newValue;
              });
            }
          },
          validator: (value) {
            if (value == null) {
              return 'Please select a category';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _dateFormatService.formatDateWithPattern(
                      _selectedDate,
                      shortMonth: true,
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Notes (Optional)',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Add a note about this transaction...',
            prefixIcon: Icon(Icons.note),
          ),
        ),
      ],
    );
  }
}
