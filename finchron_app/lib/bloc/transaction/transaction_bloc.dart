import 'package:flutter_bloc/flutter_bloc.dart';
import 'transaction_event.dart';
import 'transaction_state.dart';
import '../../services/transaction_service.dart';
import '../../models/transaction.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  final TransactionService _transactionService = TransactionService();

  TransactionBloc() : super(TransactionInitial()) {
    on<LoadTransactions>(_onLoadTransactions);
    on<AddTransaction>(_onAddTransaction);
    on<UpdateTransaction>(_onUpdateTransaction);
    on<DeleteTransaction>(_onDeleteTransaction);
    on<FilterTransactions>(_onFilterTransactions);
  }

  Future<void> _onLoadTransactions(
    LoadTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    print('TransactionBloc: LoadTransactions event received');
    emit(TransactionLoading());

    try {
      print('TransactionBloc: Initializing transaction service...');
      await _transactionService.initialize();

      print('TransactionBloc: Getting transactions...');
      final transactions = await _transactionService.getTransactions();
      print('TransactionBloc: Retrieved ${transactions.length} transactions');

      // Calculate totals
      double totalIncome = 0.0;
      double totalExpense = 0.0;

      for (final transaction in transactions) {
        if (transaction.type == TransactionType.income) {
          totalIncome += transaction.amount;
        } else {
          totalExpense += transaction.amount;
        }
      }

      final balance = totalIncome - totalExpense;
      print('TransactionBloc: Calculated totals - Income: $totalIncome, Expense: $totalExpense, Balance: $balance');

      emit(
        TransactionLoaded(
          transactions: transactions,
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          balance: balance,
        ),
      );
    } catch (e) {
      emit(TransactionError(message: e.toString()));
    }
  }

  Future<void> _onAddTransaction(
    AddTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      final addedTransaction = await _transactionService.addTransaction(
        event.transaction,
      );
      
      // Update state incrementally instead of full reload
      if (state is TransactionLoaded) {
        final currentState = state as TransactionLoaded;
        final updatedTransactions = List<Transaction>.from(currentState.transactions)
          ..insert(0, addedTransaction); // Add to beginning for newest first
        
        // Recalculate totals incrementally
        double newTotalIncome = currentState.totalIncome;
        double newTotalExpense = currentState.totalExpense;
        
        if (addedTransaction.type == TransactionType.income) {
          newTotalIncome += addedTransaction.amount;
        } else {
          newTotalExpense += addedTransaction.amount;
        }
        
        final newBalance = newTotalIncome - newTotalExpense;
        
        emit(TransactionLoaded(
          transactions: updatedTransactions,
          totalIncome: newTotalIncome,
          totalExpense: newTotalExpense,
          balance: newBalance,
        ));
      } else {
        // If not loaded yet, emit the added transaction and trigger a load
        emit(TransactionAdded(transaction: addedTransaction));
        add(LoadTransactions());
      }
    } catch (e) {
      emit(TransactionError(message: e.toString()));
    }
  }

  Future<void> _onUpdateTransaction(
    UpdateTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      final updatedTransaction = await _transactionService.updateTransaction(
        event.transaction,
      );
      
      // Update state incrementally instead of full reload
      if (state is TransactionLoaded) {
        final currentState = state as TransactionLoaded;
        final updatedTransactions = currentState.transactions.map((transaction) {
          return transaction.id == updatedTransaction.id 
              ? updatedTransaction 
              : transaction;
        }).toList();
        
        // Recalculate totals
        double totalIncome = 0.0;
        double totalExpense = 0.0;
        
        for (final transaction in updatedTransactions) {
          if (transaction.type == TransactionType.income) {
            totalIncome += transaction.amount;
          } else {
            totalExpense += transaction.amount;
          }
        }
        
        final balance = totalIncome - totalExpense;
        
        emit(TransactionLoaded(
          transactions: updatedTransactions,
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          balance: balance,
        ));
      } else {
        emit(TransactionUpdated(transaction: updatedTransaction));
        add(LoadTransactions());
      }
    } catch (e) {
      emit(TransactionError(message: e.toString()));
    }
  }

  Future<void> _onDeleteTransaction(
    DeleteTransaction event,
    Emitter<TransactionState> emit,
  ) async {
    try {
      await _transactionService.deleteTransaction(event.transactionId);
      
      // Update state incrementally instead of full reload
      if (state is TransactionLoaded) {
        final currentState = state as TransactionLoaded;
        
        // Find the transaction to remove for total calculation
        final transactionToRemove = currentState.transactions
            .firstWhere((t) => t.id == event.transactionId, orElse: () => 
                Transaction(
                  id: '',
                  userId: '',
                  amount: 0,
                  type: TransactionType.expense,
                  category: TransactionCategory.others,
                  date: DateTime.now(),
                  notes: '',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ));
        
        final updatedTransactions = currentState.transactions
            .where((transaction) => transaction.id != event.transactionId)
            .toList();
        
        // Recalculate totals by removing the deleted transaction
        double newTotalIncome = currentState.totalIncome;
        double newTotalExpense = currentState.totalExpense;
        
        if (transactionToRemove.id.isNotEmpty) {
          if (transactionToRemove.type == TransactionType.income) {
            newTotalIncome -= transactionToRemove.amount;
          } else {
            newTotalExpense -= transactionToRemove.amount;
          }
        }
        
        final newBalance = newTotalIncome - newTotalExpense;
        
        emit(TransactionLoaded(
          transactions: updatedTransactions,
          totalIncome: newTotalIncome,
          totalExpense: newTotalExpense,
          balance: newBalance,
        ));
      } else {
        emit(TransactionDeleted(transactionId: event.transactionId));
        add(LoadTransactions());
      }
    } catch (e) {
      emit(TransactionError(message: e.toString()));
    }
  }

  Future<void> _onFilterTransactions(
    FilterTransactions event,
    Emitter<TransactionState> emit,
  ) async {
    emit(TransactionLoading());

    try {
      final allTransactions = await _transactionService.getTransactions();

      // Apply filters manually
      var filteredTransactions = allTransactions.where((transaction) {
        // Filter by type
        if (event.type != null && transaction.type != event.type) {
          return false;
        }

        // Filter by category
        if (event.category != null && transaction.category != event.category) {
          return false;
        }

        // Filter by date range
        if (event.startDate != null &&
            transaction.date.isBefore(event.startDate!)) {
          return false;
        }

        if (event.endDate != null && transaction.date.isAfter(event.endDate!)) {
          return false;
        }

        return true;
      }).toList();

      // Calculate totals for filtered transactions
      double totalIncome = 0;
      double totalExpense = 0;

      for (final transaction in filteredTransactions) {
        if (transaction.type == TransactionType.income) {
          totalIncome += transaction.amount;
        } else {
          totalExpense += transaction.amount;
        }
      }

      emit(
        TransactionLoaded(
          transactions: filteredTransactions,
          totalIncome: totalIncome,
          totalExpense: totalExpense,
          balance: totalIncome - totalExpense,
        ),
      );
    } catch (e) {
      emit(TransactionError(message: e.toString()));
    }
  }
}
