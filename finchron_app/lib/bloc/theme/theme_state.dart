import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

abstract class ThemeState extends Equatable {
  final ThemeMode themeMode;
  final bool isDarkMode;

  const ThemeState({required this.themeMode, required this.isDarkMode});

  @override
  List<Object> get props => [themeMode, isDarkMode];
}

class ThemeInitial extends ThemeState {
  const ThemeInitial() : super(themeMode: ThemeMode.system, isDarkMode: false);
}

class ThemeLight extends ThemeState {
  const ThemeLight() : super(themeMode: ThemeMode.light, isDarkMode: false);
}

class ThemeDark extends ThemeState {
  const ThemeDark() : super(themeMode: ThemeMode.dark, isDarkMode: true);
}

class ThemeSystem extends ThemeState {
  const ThemeSystem() : super(themeMode: ThemeMode.system, isDarkMode: false);
}
