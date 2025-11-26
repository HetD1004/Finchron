import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_event.dart';
import 'theme_state.dart';

class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  ThemeBloc() : super(const ThemeInitial()) {
    on<ToggleTheme>(_onToggleTheme);
    on<SetThemeMode>(_onSetThemeMode);
    _loadThemeMode();
  }

  Future<void> _onToggleTheme(
    ToggleTheme event,
    Emitter<ThemeState> emit,
  ) async {
    if (state.isDarkMode) {
      emit(const ThemeLight());
      await _saveThemeMode(false);
    } else {
      emit(const ThemeDark());
      await _saveThemeMode(true);
    }
  }

  Future<void> _onSetThemeMode(
    SetThemeMode event,
    Emitter<ThemeState> emit,
  ) async {
    if (event.isDarkMode) {
      emit(const ThemeDark());
    } else {
      emit(const ThemeLight());
    }
    await _saveThemeMode(event.isDarkMode);
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDarkMode = prefs.getBool('isDarkMode') ?? false;
      if (isDarkMode) {
        add(SetThemeMode(true));
      } else {
        add(SetThemeMode(false));
      }
    } catch (e) {
      // If loading fails, stick with default light theme
    }
  }

  Future<void> _saveThemeMode(bool isDarkMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', isDarkMode);
    } catch (e) {
      // Handle error if needed
    }
  }
}
