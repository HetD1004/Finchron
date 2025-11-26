import 'package:equatable/equatable.dart';
import '../../models/transaction.dart';

abstract class TransactionEvent extends Equatable {
  const TransactionEvent();

  @override
  List<Object?> get props => [];
}

class LoadTransactions extends TransactionEvent {}

class AddTransaction extends TransactionEvent {
  final Transaction transaction;

  const AddTransaction({required this.transaction});

  @override
  List<Object?> get props => [transaction];
}

class UpdateTransaction extends TransactionEvent {
  final Transaction transaction;

  const UpdateTransaction({required this.transaction});

  @override
  List<Object?> get props => [transaction];
}

class DeleteTransaction extends TransactionEvent {
  final String transactionId;

  const DeleteTransaction({required this.transactionId});

  @override
  List<Object?> get props => [transactionId];
}

class FilterTransactions extends TransactionEvent {
  final TransactionType? type;
  final TransactionCategory? category;
  final DateTime? startDate;
  final DateTime? endDate;

  const FilterTransactions({
    this.type,
    this.category,
    this.startDate,
    this.endDate,
  });

  @override
  List<Object?> get props => [type, category, startDate, endDate];
}
