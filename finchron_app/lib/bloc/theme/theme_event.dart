abstract class ThemeEvent {}

class ToggleTheme extends ThemeEvent {}

class SetThemeMode extends ThemeEvent {
  final bool isDarkMode;

  SetThemeMode(this.isDarkMode);
}
