import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/transaction/transaction_bloc.dart';
import '../bloc/transaction/transaction_event.dart';
import '../bloc/transaction/transaction_state.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../themes/app_colors.dart';
import '../widgets/balance_card.dart';
import '../widgets/quick_actions.dart';
import '../widgets/spending_chart.dart';
import '../widgets/recent_transactions.dart';
import '../services/image_service.dart';
import 'transactions_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'ai_assistant_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  
  // Lazy load screens to prevent simultaneous data loading
  Widget _getCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return DashboardContent(
          onSwitchToTransactions: () {
            setState(() {
              _currentIndex = 1; // Switch to transactions tab
            });
          },
        );
      case 1:
        return const TransactionsScreen();
      case 2:
        return const AnalyticsScreen();
      case 3:
        return const SettingsScreen();
      default:
        return const DashboardContent();
    }
  }

  @override
  void initState() {
    super.initState();
    // Load transactions immediately when dashboard opens
    Future.microtask(() {
      if (mounted) {
        context.read<TransactionBloc>().add(LoadTransactions());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getCurrentScreen(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0 || _currentIndex == 1
          ? FloatingActionButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AIAssistantScreen(),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.psychology, color: Colors.white, size: 32),
            )
          : null,
    );
  }
}

class DashboardContent extends StatelessWidget {
  final VoidCallback? onSwitchToTransactions;
  
  const DashboardContent({
    super.key,
    this.onSwitchToTransactions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            context.read<TransactionBloc>().add(LoadTransactions());
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with user info
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, authState) {
                    String userName = 'User';
                    String? profilePictureUrl;
                    String? userId;
                    
                    if (authState is AuthAuthenticated) {
                      userName = authState.user.name.isNotEmpty 
                          ? authState.user.name 
                          : authState.user.email.split('@').first;
                      profilePictureUrl = authState.user.profilePictureUrl;
                      userId = authState.user.id;
                    } else if (authState is AuthSuccess) {
                      userName = authState.user.name.isNotEmpty 
                          ? authState.user.name 
                          : authState.user.email.split('@').first;
                      profilePictureUrl = authState.user.profilePictureUrl;
                      userId = authState.user.id;
                    }
                    
                    return _buildHeader(context, userName, profilePictureUrl, userId);
                  },
                ),
                const SizedBox(height: 24),

                // Balance Cards
                BlocBuilder<TransactionBloc, TransactionState>(
                  builder: (context, state) {
                    if (state is TransactionLoading) {
                      return _buildSkeletonBalanceCard(context);
                    } else if (state is TransactionLoaded) {
                      return BalanceCard(
                        balance: state.balance,
                        totalIncome: state.totalIncome,
                        totalExpense: state.totalExpense,
                      );
                    }
                    return const BalanceCard(
                      balance: 0.0,
                      totalIncome: 0.0,
                      totalExpense: 0.0,
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Quick Actions
                const QuickActions(),
                const SizedBox(height: 24),

                // Spending Chart
                const SpendingChart(),
                const SizedBox(height: 24),

                // Recent Transactions
                RecentTransactions(
                  onViewAllPressed: onSwitchToTransactions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    String userName,
    String? profilePictureUrl,
    String? userId,
  ) {
    final now = DateTime.now();
    final hour = now.hour;
    String greeting;

    if (hour < 12) {
      greeting = 'Good Morning';
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
    } else {
      greeting = 'Good Evening';
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userName.isNotEmpty ? userName : 'User',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Profile avatar with dynamic loading from Firestore
        FutureBuilder<Widget>(
          future: ImageService().getProfileImageWidget(
            profilePictureUrl: profilePictureUrl,
            userId: userId,
            userName: userName,
            radius: 24,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return snapshot.data!;
            }
            // Show loading indicator while fetching image
            return CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
  
  Widget _buildSkeletonBalanceCard(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ),
    );
  }
}
