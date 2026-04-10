import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../services/step_tracker_service.dart';

class StepTrackerScreen extends StatefulWidget {
  const StepTrackerScreen({super.key});

  @override
  State<StepTrackerScreen> createState() => _StepTrackerScreenState();
}

class _StepTrackerScreenState extends State<StepTrackerScreen>
    with SingleTickerProviderStateMixin {
  final StepTrackerService _stepService = StepTrackerService();
  final int _dailyGoal = 8000;

  int _steps = 0;
  String _status = 'stopped';
  List<Map<String, dynamic>> _weeklyData = [];
  bool _isLoading = true;

  late AnimationController _animationController;
  late Animation<double> _animation;

  StreamSubscription? _stepSub;
  StreamSubscription? _statusSub;

  // Timer to save to Firestore every 5 mins
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _initTracker();
  }

  Future<void> _initTracker() async {
    await _stepService.initialize();
    _steps = _stepService.todaySteps;

    _stepSub = _stepService.stepCountStream.listen((steps) {
      if (mounted) setState(() => _steps = steps);
      _animationController.forward(from: 0);
    });

    _statusSub = _stepService.pedestrianStatusStream.listen((status) {
      if (mounted) setState(() => _status = status);
    });

    _weeklyData = await _stepService.getWeeklySteps();

    _saveTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _stepService.saveStepsToFirestore();
    });

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _stepSub?.cancel();
    _statusSub?.cancel();
    _saveTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  double get _progress => (_steps / _dailyGoal).clamp(0.0, 1.0);
  int get _remainingSteps => max(0, _dailyGoal - _steps);
  double get _caloriesBurned => _steps * 0.04; // Approx
  double get _distanceKm => _steps * 0.000762;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D7A7B),
        foregroundColor: Colors.white,
        title: const Text('Step Tracker'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              await _stepService.saveStepsToFirestore();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Steps synced! ✅')));
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2D7A7B)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildStatusBadge(),
                  const SizedBox(height: 24),
                  _buildCircularProgress(),
                  const SizedBox(height: 24),
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  _buildWeeklyChart(),
                  const SizedBox(height: 24),
                  _buildHealthTip(),
                ],
              ),
            ),
    );
  }

  // ✅ Walking/Stopped badge
  Widget _buildStatusBadge() {
    final isWalking = _status == 'walking';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isWalking
            ? const Color(0xFF2D7A7B).withOpacity(0.1)
            : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isWalking ? const Color(0xFF2D7A7B) : Colors.grey,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isWalking ? Icons.directions_walk : Icons.pause_circle_outline,
            color: isWalking ? const Color(0xFF2D7A7B) : Colors.grey,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isWalking ? 'You are walking 🚶‍♀️' : 'Standing still',
            style: TextStyle(
              color: isWalking ? const Color(0xFF2D7A7B) : Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ Big circular step counter
  Widget _buildCircularProgress() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 240,
                height: 240,
                child: CustomPaint(
                  painter: _CircularProgressPainter(
                    progress: _progress,
                    color: const Color(0xFF2D7A7B),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_walk,
                    color: Color(0xFF2D7A7B),
                    size: 32,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_steps',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D7A7B),
                    ),
                  ),
                  const Text(
                    'steps',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_remainingSteps left',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ Stats cards
  Widget _buildStatsRow() {
    return Row(
      children: [
        _statCard('🔥 Calories', '${_caloriesBurned.toStringAsFixed(0)} kcal'),
        const SizedBox(width: 12),
        _statCard('📍 Distance', '${_distanceKm.toStringAsFixed(2)} km'),
        const SizedBox(width: 12),
        _statCard('🎯 Goal', '$_dailyGoal steps'),
      ],
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D7A7B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Weekly bar chart
  Widget _buildWeeklyChart() {
    if (_weeklyData.isEmpty) return const SizedBox();

    final maxSteps = _weeklyData
        .map((e) => e['steps'] as int)
        .fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Activity',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D7A7B),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weeklyData.map((data) {
              final steps = data['steps'] as int;
              final heightRatio = maxSteps == 0 ? 0.0 : steps / maxSteps;
              final isGoalMet = steps >= _dailyGoal;

              return Column(
                children: [
                  Text(
                    '${(steps / 1000).toStringAsFixed(1)}k',
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 32,
                    height: 80 * heightRatio + 4,
                    decoration: BoxDecoration(
                      color: isGoalMet
                          ? const Color(0xFF2D7A7B)
                          : const Color(0xFF2D7A7B).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data['day'],
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D7A7B),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Goal achieved',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D7A7B).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'In progress',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ Hormonal health tip
  Widget _buildHealthTip() {
    String tip;
    if (_steps < 3000) {
      tip =
          '💡 Light walking helps regulate cortisol levels. Even a 10-min walk can improve hormonal balance!';
    } else if (_steps < 6000) {
      tip =
          '✨ Great start! Regular walking supports estrogen metabolism and reduces PMS symptoms.';
    } else if (_steps < 8000) {
      tip =
          '🌟 Almost there! Consistent activity helps maintain insulin sensitivity, key for PCOS management.';
    } else {
      tip =
          '🎉 Goal achieved! Regular activity is proven to reduce hot flashes and improve mood during menopause.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2D7A7B).withOpacity(0.1),
            const Color(0xFF2D7A7B).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2D7A7B).withOpacity(0.2)),
      ),
      child: Text(
        tip,
        style: TextStyle(color: Colors.teal[800], fontSize: 13, height: 1.5),
      ),
    );
  }
}

// ✅ Custom painter for circular progress
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CircularProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi,
      false,
      Paint()
        ..color = color.withOpacity(0.1)
        ..strokeWidth = 14
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Progress arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = color
        ..strokeWidth = 14
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) => old.progress != progress;
}
