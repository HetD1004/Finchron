import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class DateFormatService {
  static final DateFormatService _instance = DateFormatService._internal();
  factory DateFormatService() => _instance;
  DateFormatService._internal();

  static const String _dateFormatKey = 'dateFormat';

  // Available date format options
  static const Map<String, String> dateFormats = {
    'MM/dd/yyyy': 'MM/dd/yyyy',
    'dd/MM/yyyy': 'dd/MM/yyyy',
    'yyyy-MM-dd': 'yyyy-MM-dd',
  };

  String _currentFormat = 'MM/dd/yyyy';

  String get currentFormat => _currentFormat;

  Future<void> loadSavedFormat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentFormat = prefs.getString(_dateFormatKey) ?? 'MM/dd/yyyy';
    } catch (e) {
      _currentFormat = 'MM/dd/yyyy';
    }
  }

  Future<void> setFormat(String format) async {
    if (dateFormats.containsKey(format)) {
      _currentFormat = format;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_dateFormatKey, format);
      } catch (e) {
        // Handle error if needed
      }
    }
  }

  // Format a date using the current user preference
  String formatDate(DateTime date) {
    return DateFormat(_currentFormat).format(date);
  }

  // Format a date with a specific pattern while respecting the base format preference
  String formatDateWithPattern(
    DateTime date, {
    bool showTime = false,
    bool shortMonth = false,
  }) {
    String pattern;

    if (showTime) {
      switch (_currentFormat) {
        case 'dd/MM/yyyy':
          pattern = shortMonth ? 'MMM d, yyyy • h:mm a' : 'dd/MM/yyyy • h:mm a';
          break;
        case 'yyyy-MM-dd':
          pattern = shortMonth ? 'MMM d, yyyy • h:mm a' : 'yyyy-MM-dd • h:mm a';
          break;
        default:
          pattern = shortMonth ? 'MMM d, yyyy • h:mm a' : 'MM/dd/yyyy • h:mm a';
      }
    } else if (shortMonth) {
      pattern = 'MMM d, yyyy';
    } else {
      pattern = _currentFormat;
    }

    return DateFormat(pattern).format(date);
  }

  // Format date range
  String formatDateRange(DateTime start, DateTime end) {
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return formatDate(start);
    }

    // For ranges, use short format
    final startStr = DateFormat('MMM d').format(start);
    final endStr = DateFormat('MMM d').format(end);

    if (start.year == end.year) {
      return '$startStr - $endStr';
    } else {
      return '${DateFormat('MMM d, yyyy').format(start)} - ${DateFormat('MMM d, yyyy').format(end)}';
    }
  }
}
