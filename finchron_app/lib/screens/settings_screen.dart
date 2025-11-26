import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../themes/app_colors.dart';
import '../services/currency_service.dart';
import '../services/date_format_service.dart';
import '../bloc/theme/theme_bloc.dart';
import '../bloc/theme/theme_event.dart';
import '../bloc/theme/theme_state.dart';
import 'login_screen.dart';
import 'profile_edit_screen.dart';
import 'ai_assistant_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CurrencyService _currencyService = CurrencyService();
  final DateFormatService _dateFormatService = DateFormatService();
  bool _notificationsEnabled = true;
  String _currency = 'USD';
  String _dateFormat = 'MM/dd/yyyy';

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // Load saved preferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _currencyService.loadSavedCurrency();
      await _dateFormatService.loadSavedFormat();
      setState(() {
        _currency = _currencyService.currentCurrency;
        _dateFormat = _dateFormatService.currentFormat;
        _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      });
    } catch (e) {
      print('Error loading preferences: $e');
    }
  }

  // Save currency preference
  Future<void> _saveCurrency(String currency) async {
    try {
      await _currencyService.setCurrency(currency);
      setState(() {
        _currency = currency;
      });

      // Show confirmation with currency symbol
      final symbol = _currencyService.currentSymbol;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Currency changed to $currency ($symbol)'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error saving currency: $e');
    }
  }

  // Save date format preference
  Future<void> _saveDateFormat(String dateFormat) async {
    try {
      await _dateFormatService.setFormat(dateFormat);
      setState(() {
        _dateFormat = dateFormat;
      });

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Date format changed to $dateFormat'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error saving date format: $e');
    }
  }

  // Save notifications preference
  Future<void> _saveNotifications(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notificationsEnabled', enabled);
      setState(() {
        _notificationsEnabled = enabled;
      });

      // Show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notifications ${enabled ? 'enabled' : 'disabled'}'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print('Error saving notifications setting: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSection(
                title: 'Appearance',
                children: [
                  _buildSwitchTile(
                    title: 'Dark Mode',
                    subtitle: 'Enable dark theme',
                    value: themeState.isDarkMode,
                    onChanged: (value) {
                      context.read<ThemeBloc>().add(ToggleTheme());
                    },
                    icon: Icons.dark_mode,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'Preferences',
                children: [
                  _buildDropdownTile(
                    title: 'Currency',
                    subtitle:
                        'Default currency for transactions (${_currencyService.currentSymbol})',
                    value: _currency,
                    items: _currencyService.availableCurrencies,
                    onChanged: (value) {
                      if (value != null) {
                        _saveCurrency(value);
                      }
                    },
                    icon: Icons.attach_money,
                  ),
                  _buildDropdownTile(
                    title: 'Date Format',
                    subtitle: 'How dates are displayed',
                    value: _dateFormat,
                    items: const ['MM/dd/yyyy', 'dd/MM/yyyy', 'yyyy-MM-dd'],
                    onChanged: (value) {
                      if (value != null) {
                        _saveDateFormat(value);
                      }
                    },
                    icon: Icons.calendar_today,
                  ),
                  _buildSwitchTile(
                    title: 'Notifications',
                    subtitle: 'Receive transaction reminders',
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      _saveNotifications(value);
                    },
                    icon: Icons.notifications,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'Account',
                children: [
                  _buildActionTile(
                    title: 'Edit Profile',
                    subtitle: 'Update your personal information',
                    icon: Icons.person_outline,
                    onTap: _navigateToProfile,
                  ),
                  _buildActionTile(
                    title: 'AI Assistant',
                    subtitle: 'Get financial insights and advice',
                    icon: Icons.smart_toy,
                    onTap: _navigateToAI,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'Data Management',
                children: [
                  _buildActionTile(
                    title: 'Export Data',
                    subtitle: 'Download your transaction data',
                    icon: Icons.download,
                    onTap: _exportData,
                  ),
                  _buildActionTile(
                    title: 'Import Data',
                    subtitle: 'Import transactions from file',
                    icon: Icons.upload,
                    onTap: _importData,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                title: 'About',
                children: [
                  _buildInfoTile(
                    title: 'Version',
                    subtitle: '1.0.0',
                    icon: Icons.info,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SizedBox(height: 24),

              // Logout Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.primary,
      ),
    );
  }

  Widget _buildDropdownTile({
    required String title,
    required String subtitle,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<String>(
        value: value,
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(item));
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool loading = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : AppColors.primary,
      ),
      title: Text(
        title,
        style: TextStyle(color: isDestructive ? Colors.red : null),
      ),
      subtitle: Text(subtitle),
      trailing: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
      onTap: loading ? null : onTap,
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  void _exportData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settings to export:'),
            const SizedBox(height: 8),
            Text('• Currency: $_currency (${_currencyService.currentSymbol})'),
            Text('• Date Format: $_dateFormat'),
            Text(
              '• Notifications: ${_notificationsEnabled ? 'Enabled' : 'Disabled'}',
            ),
            const SizedBox(height: 16),
            const Text(
              'Note: This would save your settings to a file in the full version.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Export completed!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _importData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Import settings from a backup file:'),
            SizedBox(height: 8),
            Text('• Restore currency preferences'),
            Text('• Restore date format settings'),
            Text('• Restore notification preferences'),
            SizedBox(height: 16),
            Text(
              'Note: This would open a file picker in the full version.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Import completed!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProfileEditScreen(),
      ),
    );
  }

  void _navigateToAI() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AIAssistantScreen(),
      ),
    );
  }

  // Logout function
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red[700]),
              const SizedBox(width: 8),
              const Text('Logout'),
            ],
          ),
          content: const Text(
            'Are you sure you want to logout? You will need to sign in again to access your account.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Clear user session data
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_token');
        await prefs.remove('user_id');
        await prefs.remove('user_email');
        await prefs.remove('userName');
        await prefs.setBool('isLoggedIn', false);

        if (mounted) {
          // Navigate to login screen and clear the navigation stack
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logged out successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error during logout: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
