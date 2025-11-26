import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';

import 'themes/app_theme.dart';
import 'bloc/auth/auth_bloc.dart';
import 'bloc/transaction/transaction_bloc.dart';
import 'bloc/theme/theme_bloc.dart';
import 'bloc/theme/theme_state.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/currency_service.dart';
import 'services/date_format_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize services
  final currencyService = CurrencyService();
  await currencyService.loadSavedCurrency();

  final dateFormatService = DateFormatService();
  await dateFormatService.loadSavedFormat();

  runApp(const FinchronApp());
}

class FinchronApp extends StatelessWidget {
  const FinchronApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (context) => AuthBloc()),
        BlocProvider<TransactionBloc>(create: (context) => TransactionBloc()),
        BlocProvider<ThemeBloc>(create: (context) => ThemeBloc()),
      ],
      child: BlocBuilder<ThemeBloc, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp(
            title: 'Finchron - Finance Tracker',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeState.themeMode,
            home: const SplashScreen(),
            routes: {'/dashboard': (context) => const DashboardScreen()},
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
