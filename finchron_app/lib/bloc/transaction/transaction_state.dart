import 'package:equatable/equatable.dart';
import '../../models/transaction.dart';

abstract class TransactionState extends Equatable {
  const TransactionState();

  @override
  List<Object?> get props => [];
}

class TransactionInitial extends TransactionState {}

class TransactionLoading extends TransactionState {}

class TransactionLoaded extends TransactionState {
  final List<Transaction> transactions;
  final double totalIncome;
  final double totalExpense;
  final double balance;

  const TransactionLoaded({
    required this.transactions,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
  });

  @override
  List<Object?> get props => [transactions, totalIncome, totalExpense, balance];
}

class TransactionError extends TransactionState {
  final String message;

  const TransactionError({required this.message});

  @override
  List<Object?> get props => [message];
}

class TransactionAdded extends TransactionState {
  final Transaction transaction;

  const TransactionAdded({required this.transaction});

  @override
  List<Object?> get props => [transaction];
}

class TransactionUpdated extends TransactionState {
  final Transaction transaction;

  const TransactionUpdated({required this.transaction});

  @override
  List<Object?> get props => [transaction];
}

class TransactionDeleted extends TransactionState {
  final String transactionId;

  const TransactionDeleted({required this.transactionId});

  @override
  List<Object?> get props => [transactionId];
}
