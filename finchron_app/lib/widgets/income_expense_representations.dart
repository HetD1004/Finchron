import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../themes/app_colors.dart';
import '../services/currency_service.dart';

class IncomeExpenseRepresentations extends StatefulWidget {
  final double income;
  final double expense;
  final RepresentationType type;

  const IncomeExpenseRepresentations({
    super.key,
    required this.income,
    required this.expense,
    this.type = RepresentationType.circularProgress,
  });

  @override
  State<IncomeExpenseRepresentations> createState() =>
      _IncomeExpenseRepresentationsState();
}

class _IncomeExpenseRepresentationsState
    extends State<IncomeExpenseRepresentations>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _flipController;
  late Animation<double> _animation;
  late Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _flipController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyService = CurrencyService();
    final netAmount = widget.income - widget.expense;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Income vs Expenses',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: netAmount >= 0
                        ? AppColors.income.withOpacity(0.1)
                        : AppColors.expense.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: netAmount >= 0
                          ? AppColors.income
                          : AppColors.expense,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    'Net: ${currencyService.formatAmount(netAmount)}',
                    style: TextStyle(
                      color: netAmount >= 0
                          ? AppColors.income
                          : AppColors.expense,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Dynamic content based on representation type
            _buildRepresentation(currencyService),
          ],
        ),
      ),
    );
  }

  Widget _buildRepresentation(CurrencyService currencyService) {
    switch (widget.type) {
      case RepresentationType.circularProgress:
        return _buildCircularProgressRepresentation(currencyService);
      case RepresentationType.balanceScale:
        return _buildBalanceScaleRepresentation(currencyService);
      case RepresentationType.donutChart:
        return _buildDonutChartRepresentation(currencyService);
      case RepresentationType.cardFlip:
        return _buildCardFlipRepresentation(currencyService);
      case RepresentationType.thermometer:
        return _buildThermometerRepresentation(currencyService);
      case RepresentationType.liquidProgress:
        return _buildLiquidProgressRepresentation(currencyService);
    }
  }

  // 1. Circular Progress Representation
  Widget _buildCircularProgressRepresentation(CurrencyService currencyService) {
    final total = widget.income + widget.expense;
    final incomePercentage = total > 0 ? widget.income / total : 0.0;
    final expensePercentage = total > 0 ? widget.expense / total : 0.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Income Circle
                _buildCircularIndicator(
                  'Income',
                  widget.income,
                  incomePercentage * _animation.value,
                  AppColors.income,
                  Icons.trending_up,
                  currencyService,
                ),
                // Expense Circle
                _buildCircularIndicator(
                  'Expenses',
                  widget.expense,
                  expensePercentage * _animation.value,
                  AppColors.expense,
                  Icons.trending_down,
                  currencyService,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildComparisonBar(currencyService),
          ],
        );
      },
    );
  }

  Widget _buildCircularIndicator(
    String label,
    double amount,
    double progress,
    Color color,
    IconData icon,
    CurrencyService currencyService,
  ) {
    return SizedBox(
      width: 140, // Fixed width to prevent overflow
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              children: [
                // Background circle
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.1),
                  ),
                ),
                // Progress circle
                Center(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: color.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                // Center content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: color, size: 24),
                      const SizedBox(height: 4),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            currencyService.formatAmount(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 2. Balance Scale Representation
  Widget _buildBalanceScaleRepresentation(CurrencyService currencyService) {
    final double balanceAngle = widget.income > widget.expense
        ? -0.1
        : widget.expense > widget.income
            ? 0.1
            : 0.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          children: [
            SizedBox(
              height: 200,
              child: CustomPaint(
                size: const Size(300, 200),
                painter: BalanceScalePainter(
                  incomeAmount: widget.income,
                  expenseAmount: widget.expense,
                  animation: _animation.value,
                  balanceAngle: balanceAngle,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildScaleData(
                  'Income',
                  widget.income,
                  AppColors.income,
                  Icons.trending_up,
                  currencyService,
                ),
                _buildScaleData(
                  'Expenses',
                  widget.expense,
                  AppColors.expense,
                  Icons.trending_down,
                  currencyService,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildScaleData(
    String label,
    double amount,
    Color color,
    IconData icon,
    CurrencyService currencyService,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Text(
          currencyService.formatAmount(amount),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // 3. Donut Chart Representation
  Widget _buildDonutChartRepresentation(CurrencyService currencyService) {
    final total = widget.income + widget.expense;
    if (total == 0) return const Center(child: Text('No data available'));

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          children: [
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 60,
                  sections: [
                    PieChartSectionData(
                      color: AppColors.income,
                      value: widget.income * _animation.value,
                      title: '',
                      radius: 40,
                    ),
                    PieChartSectionData(
                      color: AppColors.expense,
                      value: widget.expense * _animation.value,
                      title: '',
                      radius: 40,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDonutLegend(
                  'Income',
                  widget.income,
                  (widget.income / total * 100),
                  AppColors.income,
                  currencyService,
                ),
                _buildDonutLegend(
                  'Expenses',
                  widget.expense,
                  (widget.expense / total * 100),
                  AppColors.expense,
                  currencyService,
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildDonutLegend(
    String label,
    double amount,
    double percentage,
    Color color,
    CurrencyService currencyService,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            Text(
              currencyService.formatAmount(amount),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 4. Card Flip Representation
  Widget _buildCardFlipRepresentation(CurrencyService currencyService) {
    return AnimatedBuilder(
      animation: _flipAnimation,
      builder: (context, child) {
        final showIncome = _flipAnimation.value < 0.5;
        return SizedBox(
          height: 200,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(showIncome ? 0 : math.pi),
            child: showIncome
                ? _buildFlipCard(
                    'Total Income',
                    widget.income,
                    AppColors.income,
                    Icons.trending_up,
                    currencyService,
                  )
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _buildFlipCard(
                      'Total Expenses',
                      widget.expense,
                      AppColors.expense,
                      Icons.trending_down,
                      currencyService,
                    ),
                  ),
          ),
        );
      },
    );
  }

  Widget _buildFlipCard(
    String label,
    double amount,
    Color color,
    IconData icon,
    CurrencyService currencyService,
  ) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.8),
            color,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 48),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            currencyService.formatAmount(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // 5. Thermometer Representation
  Widget _buildThermometerRepresentation(CurrencyService currencyService) {
    final maxAmount = math.max(widget.income, widget.expense);
    final incomeHeight = maxAmount > 0 ? (widget.income / maxAmount) : 0.0;
    final expenseHeight = maxAmount > 0 ? (widget.expense / maxAmount) : 0.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildThermometer(
              'Income',
              widget.income,
              incomeHeight * _animation.value,
              AppColors.income,
              currencyService,
            ),
            _buildThermometer(
              'Expenses',
              widget.expense,
              expenseHeight * _animation.value,
              AppColors.expense,
              currencyService,
            ),
          ],
        );
      },
    );
  }

  Widget _buildThermometer(
    String label,
    double amount,
    double height,
    Color color,
    CurrencyService currencyService,
  ) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          currencyService.formatAmount(amount),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              FractionallySizedBox(
                heightFactor: height,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        color,
                        color.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 6. Liquid Progress Representation
  Widget _buildLiquidProgressRepresentation(CurrencyService currencyService) {
    final total = widget.income + widget.expense;
    final incomeRatio = total > 0 ? widget.income / total : 0.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          children: [
            SizedBox(
              height: 200,
              child: CustomPaint(
                size: const Size(300, 200),
                painter: LiquidProgressPainter(
                  incomeRatio: incomeRatio,
                  animation: _animation.value,
                  income: widget.income,
                  expense: widget.expense,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildLiquidLegend(currencyService),
          ],
        );
      },
    );
  }

  Widget _buildLiquidLegend(CurrencyService currencyService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem(
          'Income',
          widget.income,
          AppColors.income,
          Icons.trending_up,
          currencyService,
        ),
        _buildLegendItem(
          'Expenses',
          widget.expense,
          AppColors.expense,
          Icons.trending_down,
          currencyService,
        ),
      ],
    );
  }

  Widget _buildLegendItem(
    String label,
    double amount,
    Color color,
    IconData icon,
    CurrencyService currencyService,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            Text(
              currencyService.formatAmount(amount),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComparisonBar(CurrencyService currencyService) {
    final total = widget.income + widget.expense;
    final incomePercentage = total > 0 ? (widget.income / total * 100) : 0.0;
    final expensePercentage = total > 0 ? (widget.expense / total * 100) : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          _buildComparisonRow(
            label: 'Income',
            amount: widget.income,
            percentage: incomePercentage,
            color: AppColors.income,
            icon: Icons.trending_up,
            currencyService: currencyService,
          ),
          const SizedBox(height: 16),
          _buildComparisonRow(
            label: 'Expenses',
            amount: widget.expense,
            percentage: expensePercentage,
            color: AppColors.expense,
            icon: Icons.trending_down,
            currencyService: currencyService,
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow({
    required String label,
    required double amount,
    required double percentage,
    required Color color,
    required IconData icon,
    required CurrencyService currencyService,
  }) {
    return Container(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon and label section
          SizedBox(
            width: 80,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Progress bar section
          Expanded(
            child: Container(
              height: 24,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  // Progress fill
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withOpacity(0.8), color],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  // Percentage text
                  Center(
                    child: Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: percentage > 50 ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Amount section
          SizedBox(
            width: 80,
            child: Text(
              currencyService.formatAmount(amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

enum RepresentationType {
  circularProgress,
  balanceScale,
  donutChart,
  cardFlip,
  thermometer,
  liquidProgress,
}

// Custom Painter for Balance Scale
class BalanceScalePainter extends CustomPainter {
  final double incomeAmount;
  final double expenseAmount;
  final double animation;
  final double balanceAngle;

  BalanceScalePainter({
    required this.incomeAmount,
    required this.expenseAmount,
    required this.animation,
    required this.balanceAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.grey[600]!;

    final fillPaint = Paint()..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height * 0.3);
    
    // Draw base
    canvas.drawLine(
      Offset(size.width * 0.2, size.height * 0.9),
      Offset(size.width * 0.8, size.height * 0.9),
      paint,
    );
    
    // Draw pole
    canvas.drawLine(
      center,
      Offset(center.dx, size.height * 0.9),
      paint,
    );

    // Calculate balance beam angle
    final beamAngle = balanceAngle * animation;
    final beamLength = size.width * 0.3;

    // Draw balance beam
    final beamStart = Offset(
      center.dx - beamLength * math.cos(beamAngle),
      center.dy + beamLength * math.sin(beamAngle),
    );
    final beamEnd = Offset(
      center.dx + beamLength * math.cos(beamAngle),
      center.dy - beamLength * math.sin(beamAngle),
    );

    canvas.drawLine(beamStart, beamEnd, paint);

    // Draw income pan (left)
    fillPaint.color = AppColors.income.withOpacity(0.7);
    final incomeCenter = Offset(
      beamStart.dx,
      beamStart.dy + 20,
    );
    canvas.drawCircle(incomeCenter, 30, fillPaint);

    // Draw expense pan (right)
    fillPaint.color = AppColors.expense.withOpacity(0.7);
    final expenseCenter = Offset(
      beamEnd.dx,
      beamEnd.dy + 20,
    );
    canvas.drawCircle(expenseCenter, 30, fillPaint);

    // Draw fulcrum
    fillPaint.color = Colors.grey[600]!;
    canvas.drawCircle(center, 8, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Custom Painter for Liquid Progress
class LiquidProgressPainter extends CustomPainter {
  final double incomeRatio;
  final double animation;
  final double income;
  final double expense;

  LiquidProgressPainter({
    required this.incomeRatio,
    required this.animation,
    required this.income,
    required this.expense,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    
    // Background
    final backgroundPaint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      backgroundPaint,
    );

    // Income liquid (bottom)
    final incomeHeight = size.height * incomeRatio * animation;
    final incomeRect = Rect.fromLTWH(
      0,
      size.height - incomeHeight,
      size.width,
      incomeHeight,
    );
    
    final incomePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.income.withOpacity(0.6),
          AppColors.income,
        ],
      ).createShader(incomeRect);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(incomeRect, const Radius.circular(16)),
      incomePaint,
    );

    // Expense liquid (top)
    final expenseHeight = size.height * (1 - incomeRatio) * animation;
    final expenseRect = Rect.fromLTWH(0, 0, size.width, expenseHeight);
    
    final expensePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.expense,
          AppColors.expense.withOpacity(0.6),
        ],
      ).createShader(expenseRect);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(expenseRect, const Radius.circular(16)),
      expensePaint,
    );

    // Border
    final borderPaint = Paint()
      ..color = Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      borderPaint,
    );

    // Wave effect for income
    if (incomeHeight > 0) {
      final wavePaint = Paint()
        ..color = AppColors.income.withOpacity(0.8)
        ..style = PaintingStyle.fill;

      final path = Path();
      final waveY = size.height - incomeHeight;
      
      path.moveTo(0, waveY);
      for (double x = 0; x <= size.width; x += 1) {
        final y = waveY + math.sin((x / 20) + (animation * 2 * math.pi)) * 3;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();

      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}