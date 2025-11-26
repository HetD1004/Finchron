import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../services/hybrid_data_service.dart';
import '../services/currency_service.dart';

class DataExportImportService {
  static final DataExportImportService _instance = DataExportImportService._internal();
  factory DataExportImportService() => _instance;
  DataExportImportService._internal();

  final HybridDataService _hybridDataService = HybridDataService();
  final CurrencyService _currencyService = CurrencyService();

  /// Export transaction data to CSV format
  Future<File?> exportToCSV({List<Transaction>? transactions}) async {
    try {
      // Request storage permission
      final permission = await _requestStoragePermission();
      if (!permission) {
        throw Exception('Storage permission denied');
      }

      // Get transactions if not provided
      transactions ??= await _hybridDataService.getTransactions();
      
      if (transactions.isEmpty) {
        throw Exception('No transactions to export');
      }

      // Create CSV data
      List<List<String>> csvData = [
        // Header row
        [
          'ID',
          'Date',
          'Type',
          'Category',
          'Amount',
          'Currency',
          'Notes',
          'Created At',
          'Updated At'
        ]
      ];

      // Add transaction data
      for (final transaction in transactions) {
        csvData.add([
          transaction.id,
          DateFormat('yyyy-MM-dd HH:mm:ss').format(transaction.date),
          transaction.type.toString().split('.').last,
          transaction.category.toString().split('.').last,
          transaction.amount.toStringAsFixed(2),
          _currencyService.currentCurrency,
          transaction.notes ?? '',
          DateFormat('yyyy-MM-dd HH:mm:ss').format(transaction.createdAt),
          DateFormat('yyyy-MM-dd HH:mm:ss').format(transaction.updatedAt),
        ]);
      }

      // Convert to CSV string
      String csvString = const ListToCsvConverter().convert(csvData);

      // Get app documents directory for saving (works without permissions)
      Directory? directory;
      if (Platform.isAndroid) {
        // Use external storage directory which doesn't require special permissions
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      // Create file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'finchron_transactions_$timestamp.csv';
      final file = File('${directory.path}/$fileName');

      // Write CSV data to file
      await file.writeAsString(csvString);

      return file;
    } catch (e) {
      throw Exception('Failed to export CSV: $e');
    }
  }

  /// Export transaction data to Excel format
  Future<File?> exportToExcel({List<Transaction>? transactions}) async {
    try {
      // Request storage permission
      final permission = await _requestStoragePermission();
      if (!permission) {
        throw Exception('Storage permission denied');
      }

      // Get transactions if not provided
      transactions ??= await _hybridDataService.getTransactions();
      
      if (transactions.isEmpty) {
        throw Exception('No transactions to export');
      }

      // Create Excel workbook
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Transactions'];

      // Remove default sheet if it exists
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Add header row
      sheetObject.appendRow([
        TextCellValue('ID'),
        TextCellValue('Date'),
        TextCellValue('Type'),
        TextCellValue('Category'),
        TextCellValue('Amount'),
        TextCellValue('Currency'),
        TextCellValue('Notes'),
        TextCellValue('Created At'),
        TextCellValue('Updated At'),
      ]);

      // Add transaction data
      for (final transaction in transactions) {
        sheetObject.appendRow([
          TextCellValue(transaction.id),
          TextCellValue(DateFormat('yyyy-MM-dd HH:mm:ss').format(transaction.date)),
          TextCellValue(transaction.type.toString().split('.').last),
          TextCellValue(transaction.category.toString().split('.').last),
          DoubleCellValue(transaction.amount),
          TextCellValue(_currencyService.currentCurrency),
          TextCellValue(transaction.notes ?? ''),
          TextCellValue(DateFormat('yyyy-MM-dd HH:mm:ss').format(transaction.createdAt)),
          TextCellValue(DateFormat('yyyy-MM-dd HH:mm:ss').format(transaction.updatedAt)),
        ]);
      }

      // Style the header row
      for (int col = 0; col < 9; col++) {
        var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
        cell.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: ExcelColor.blue,
          fontColorHex: ExcelColor.white,
        );
      }

      // Auto-fit columns
      for (int col = 0; col < 9; col++) {
        sheetObject.setColumnAutoFit(col);
      }

      // Get app documents directory for saving (works without permissions)
      Directory? directory;
      if (Platform.isAndroid) {
        // Use external storage directory which doesn't require special permissions
        directory = await getExternalStorageDirectory();
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      // Create file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'finchron_transactions_$timestamp.xlsx';
      final file = File('${directory.path}/$fileName');

      // Save Excel file
      List<int>? fileBytes = excel.save();
      if (fileBytes != null) {
        await file.writeAsBytes(fileBytes);
        return file;
      } else {
        throw Exception('Failed to generate Excel file');
      }
    } catch (e) {
      throw Exception('Failed to export Excel: $e');
    }
  }

  /// Import transactions from CSV file
  Future<List<Transaction>> importFromCSV() async {
    try {
      print('DataExportImportService: Starting CSV import...');
      
      // Pick CSV file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.single.path == null) {
        print('DataExportImportService: No file selected');
        throw Exception('No file selected');
      }

      final file = File(result.files.single.path!);
      print('DataExportImportService: Reading file: ${file.path}');
      
      if (!await file.exists()) {
        throw Exception('Selected file does not exist');
      }
      
      final csvString = await file.readAsString();
      print('DataExportImportService: File size: ${csvString.length} characters');

      // Parse CSV
      List<List<dynamic>> csvData;
      try {
        csvData = const CsvToListConverter().convert(csvString);
        print('DataExportImportService: Parsed ${csvData.length} rows from CSV');
      } catch (e) {
        throw Exception('Failed to parse CSV file: $e');
      }
      
      if (csvData.isEmpty) {
        throw Exception('CSV file is empty');
      }

      // Validate header - be more flexible
      List<dynamic> header = csvData.first;
      print('DataExportImportService: Header row: $header');
      
      // Check if header has essential columns
      final headerStr = header.map((h) => h.toString().toLowerCase().trim()).toList();
      bool hasAmount = headerStr.any((h) => h.contains('amount'));
      bool hasType = headerStr.any((h) => h.contains('type'));
      bool hasDate = headerStr.any((h) => h.contains('date'));
      
      bool hasValidHeader = hasAmount && hasType && hasDate;
      print('DataExportImportService: Valid header: $hasValidHeader (amount: $hasAmount, type: $hasType, date: $hasDate)');

      int startRow = hasValidHeader ? 1 : 0;
      
      List<Transaction> transactions = [];
      final now = DateTime.now();
      int skippedRows = 0;

      for (int i = startRow; i < csvData.length; i++) {
        try {
          final row = csvData[i];
          if (row.length < 3) {
            skippedRows++;
            continue; // Skip invalid rows
          }

          print('DataExportImportService: Processing row $i: $row');

          // Parse transaction data with flexible column mapping
          String id = _getValueFromRow(row, 0, '').toString();
          if (id.isEmpty) {
            id = '${DateTime.now().millisecondsSinceEpoch}_$i';
          }

          String dateStr = _getValueFromRow(row, 1, '').toString();
          DateTime date;
          try {
            date = DateTime.parse(dateStr);
          } catch (e) {
            // Try different date formats
            date = _parseFlexibleDate(dateStr) ?? now;
          }

          String typeStr = _getValueFromRow(row, 2, 'expense').toString().toLowerCase();
          TransactionType type = typeStr == 'income' ? TransactionType.income : TransactionType.expense;

          String categoryStr = _getValueFromRow(row, 3, 'others').toString().toLowerCase();
          TransactionCategory category = _parseCategory(categoryStr);

          double amount = double.tryParse(_getValueFromRow(row, 4, '0').toString()) ?? 0.0;
          if (amount == 0.0) {
            print('DataExportImportService: Warning - zero amount for row $i');
          }
          
          String notes = _getValueFromRow(row, 6, '').toString();

          // Parse created and updated dates
          DateTime createdAt = now;
          DateTime updatedAt = now;
          
          if (row.length > 7) {
            try {
              String createdStr = _getValueFromRow(row, 7, '').toString();
              if (createdStr.isNotEmpty) {
                createdAt = DateTime.parse(createdStr);
              }
            } catch (e) {
              // Use default
            }
          }
          
          if (row.length > 8) {
            try {
              String updatedStr = _getValueFromRow(row, 8, '').toString();
              if (updatedStr.isNotEmpty) {
                updatedAt = DateTime.parse(updatedStr);
              }
            } catch (e) {
              // Use default
            }
          }

          final transaction = Transaction(
            id: id,
            userId: '', // Will be set when saving
            type: type,
            category: category,
            amount: amount,
            date: date,
            notes: notes.isEmpty ? null : notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
          );

          transactions.add(transaction);
          print('DataExportImportService: Successfully parsed transaction: ${transaction.category.displayName} - \$${transaction.amount}');
        } catch (e) {
          print('DataExportImportService: Error parsing row $i: $e');
          skippedRows++;
          // Continue with next row
        }
      }

      print('DataExportImportService: Import complete - ${transactions.length} transactions imported, $skippedRows rows skipped');
      return transactions;
    } catch (e) {
      print('DataExportImportService: Import failed: $e');
      throw Exception('Failed to import CSV: $e');
    }
  }

  /// Import transactions from Excel file
  Future<List<Transaction>> importFromExcel() async {
    try {
      // Pick Excel file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result == null || result.files.single.bytes == null) {
        throw Exception('No file selected');
      }

      final bytes = result.files.single.bytes!;
      var excel = Excel.decodeBytes(bytes);

      // Get first sheet
      String sheetName = excel.tables.keys.first;
      Sheet? sheet = excel.tables[sheetName];

      if (sheet == null) {
        throw Exception('No data found in Excel file');
      }

      List<Transaction> transactions = [];
      final now = DateTime.now();
      int startRow = 0;

      // Check if first row is header
      if (sheet.rows.isNotEmpty) {
        final firstRow = sheet.rows.first;
        if (firstRow.any((cell) => cell?.value.toString().toLowerCase().contains('date') == true ||
                                 cell?.value.toString().toLowerCase().contains('amount') == true ||
                                 cell?.value.toString().toLowerCase().contains('type') == true)) {
          startRow = 1;
          startRow = 1;
        }
      }

      for (int i = startRow; i < sheet.rows.length; i++) {
        try {
          final row = sheet.rows[i];
          if (row.isEmpty || row.length < 5) continue;

          // Parse transaction data
          String id = _getCellValue(row, 0);
          if (id.isEmpty) {
            id = '${DateTime.now().millisecondsSinceEpoch}_$i';
          }

          String dateStr = _getCellValue(row, 1);
          DateTime date;
          try {
            date = DateTime.parse(dateStr);
          } catch (e) {
            date = _parseFlexibleDate(dateStr) ?? now;
          }

          String typeStr = _getCellValue(row, 2).toLowerCase();
          TransactionType type = typeStr == 'income' ? TransactionType.income : TransactionType.expense;

          String categoryStr = _getCellValue(row, 3).toLowerCase();
          TransactionCategory category = _parseCategory(categoryStr);

          double amount = double.tryParse(_getCellValue(row, 4)) ?? 0.0;
          String notes = _getCellValue(row, 6);

          // Parse created and updated dates
          DateTime createdAt = now;
          DateTime updatedAt = now;
          
          if (row.length > 7) {
            try {
              String createdStr = _getCellValue(row, 7);
              if (createdStr.isNotEmpty) {
                createdAt = DateTime.parse(createdStr);
              }
            } catch (e) {
              // Use default
            }
          }
          
          if (row.length > 8) {
            try {
              String updatedStr = _getCellValue(row, 8);
              if (updatedStr.isNotEmpty) {
                updatedAt = DateTime.parse(updatedStr);
              }
            } catch (e) {
              // Use default
            }
          }

          final transaction = Transaction(
            id: id,
            userId: '', // Will be set when saving
            type: type,
            category: category,
            amount: amount,
            date: date,
            notes: notes.isEmpty ? null : notes,
            createdAt: createdAt,
            updatedAt: updatedAt,
          );

          transactions.add(transaction);
        } catch (e) {
          print('Error parsing Excel row $i: $e');
          // Continue with next row
        }
      }

      return transactions;
    } catch (e) {
      throw Exception('Failed to import Excel: $e');
    }
  }

  /// Save imported transactions to database
  Future<int> saveImportedTransactions(List<Transaction> transactions) async {
    int savedCount = 0;
    
    for (final transaction in transactions) {
      try {
        await _hybridDataService.createTransaction(
          amount: transaction.amount,
          type: transaction.type.toString().split('.').last,
          category: transaction.category.toString().split('.').last,
          description: transaction.notes,
          date: transaction.date,
        );
        savedCount++;
      } catch (e) {
        print('Error saving transaction ${transaction.id}: $e');
        // Continue with next transaction
      }
    }
    
    return savedCount;
  }

  /// Helper method to get value from CSV row
  dynamic _getValueFromRow(List<dynamic> row, int index, dynamic defaultValue) {
    if (index < row.length && row[index] != null) {
      return row[index];
    }
    return defaultValue;
  }

  /// Helper method to get cell value from Excel row
  String _getCellValue(List<Data?> row, int index) {
    if (index < row.length && row[index] != null) {
      return row[index]!.value.toString();
    }
    return '';
  }

  /// Parse flexible date formats
  DateTime? _parseFlexibleDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    
    // Try parsing as-is first
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      // If that fails, return null since we can't format without intl package
      return null;
    }
  }

  /// Parse category string to enum
  TransactionCategory _parseCategory(String categoryStr) {
    final normalizedCategory = categoryStr.toLowerCase().trim();
    
    for (final category in TransactionCategory.values) {
      if (category.toString().split('.').last.toLowerCase() == normalizedCategory ||
          category.displayName.toLowerCase() == normalizedCategory) {
        return category;
      }
    }
    
    // Special mappings
    switch (normalizedCategory) {
      case 'food & dining':
      case 'food':
      case 'dining':
        return TransactionCategory.food;
      case 'transportation':
      case 'transport':
      case 'car':
      case 'vehicle':
        return TransactionCategory.transport;
      case 'health & fitness':
      case 'health':
      case 'medical':
        return TransactionCategory.health;
      case 'grocery':
      case 'groceries':
        return TransactionCategory.groceries;
      default:
        return TransactionCategory.others;
    }
  }

  /// Request storage permission for Android
  Future<bool> _requestStoragePermission() async {
    // For app documents directory, no special permissions are needed
    // Using getApplicationDocumentsDirectory() or getExternalStorageDirectory()
    // doesn't require WRITE_EXTERNAL_STORAGE permission on newer Android versions
    return true;
  }

  /// Show export format selection dialog
  Future<String?> showExportFormatDialog(BuildContext context) async {
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Export Format'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose the export format:'),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('CSV'),
                subtitle: const Text('Comma-separated values (Excel compatible)'),
                onTap: () => Navigator.of(context).pop('csv'),
              ),
              ListTile(
                leading: const Icon(Icons.grid_on),
                title: const Text('Excel'),
                subtitle: const Text('Microsoft Excel format (.xlsx)'),
                onTap: () => Navigator.of(context).pop('excel'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Show import format selection dialog
  Future<String?> showImportFormatDialog(BuildContext context) async {
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Import Format'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose the import format:'),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('CSV'),
                subtitle: const Text('Comma-separated values'),
                onTap: () => Navigator.of(context).pop('csv'),
              ),
              ListTile(
                leading: const Icon(Icons.grid_on),
                title: const Text('Excel'),
                subtitle: const Text('Microsoft Excel (.xlsx, .xls)'),
                onTap: () => Navigator.of(context).pop('excel'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}