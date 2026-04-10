import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StepTrackerService {
  static final StepTrackerService _instance = StepTrackerService._internal();
  factory StepTrackerService() => _instance;
  StepTrackerService._internal();

  // Stream controllers
  final StreamController<int> _stepCountController =
      StreamController<int>.broadcast();
  final StreamController<String> _pedestrianStatusController =
      StreamController<String>.broadcast();

  Stream<int> get stepCountStream => _stepCountController.stream;
  Stream<String> get pedestrianStatusStream =>
      _pedestrianStatusController.stream;

  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;

  int _todaySteps = 0;
  int _initialStepCount = -1;
  String _lastResetDate = '';

  int get todaySteps => _todaySteps;

  // ✅ Request permissions
  Future<bool> requestPermissions() async {
    if (await Permission.activityRecognition.isDenied) {
      final status = await Permission.activityRecognition.request();
      return status.isGranted;
    }
    return true;
  }

  // ✅ Initialize tracker
  Future<void> initialize() async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) return;

    await _loadSavedData();
    _startListening();
  }

  void _startListening() {
    // Step count stream
    _stepCountSubscription = Pedometer.stepCountStream.listen(
      _onStepCount,
      onError: _onStepCountError,
      cancelOnError: false,
    );

    // Walking/stopped status stream
    _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
      _onPedestrianStatus,
      onError: _onPedestrianStatusError,
      cancelOnError: false,
    );
  }

  void _onStepCount(StepCount event) async {
    final today = _getTodayDate();

    // Reset steps at midnight
    if (_lastResetDate != today) {
      _initialStepCount = event.steps;
      _lastResetDate = today;
      await _saveResetData();
    }

    if (_initialStepCount == -1) {
      _initialStepCount = event.steps;
    }

    _todaySteps = event.steps - _initialStepCount;
    if (_todaySteps < 0) _todaySteps = 0;

    _stepCountController.add(_todaySteps);
    await _saveStepsLocally(_todaySteps);
    
    // Save to Firestore every 100 steps to reduce writes
    if (_todaySteps % 100 == 0) {
      await saveStepsToFirestore();
    }
  }

  void _onPedestrianStatus(PedestrianStatus event) {
    _pedestrianStatusController.add(event.status); // "walking" or "stopped"
  }

  void _onStepCountError(error) {
    _stepCountController.add(0);
  }

  void _onPedestrianStatusError(error) {
    _pedestrianStatusController.add('stopped');
  }

  // ✅ Save to Firestore daily
  Future<void> saveStepsToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final today = _getTodayDate();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('step_logs')
          .doc(today)
          .set({
            'date': today,
            'steps': _todaySteps,
            'goal': 8000,
            'goalAchieved': _todaySteps >= 8000,
            'timestamp': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving steps: $e');
    }
  }

  // ✅ Get weekly step data for chart
  Future<List<Map<String, dynamic>>> getWeeklySteps() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final List<Map<String, dynamic>> weeklyData = [];
      final now = DateTime.now();

      // Use a single query to get all data from the last 7 days
      final sevenDaysAgo = now.subtract(const Duration(days: 6));
      final sevenDaysAgoStr = _formatDate(sevenDaysAgo);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('step_logs')
          .where('date', isGreaterThanOrEqualTo: sevenDaysAgoStr)
          .get()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => throw TimeoutException('Query timed out'),
          );

      // Create a map of date -> steps for quick lookup
      final Map<String, int> stepsMap = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        stepsMap[data['date']] = data['steps'] ?? 0;
      }

      // Build the weekly data array
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final dateStr = _formatDate(date);

        weeklyData.add({
          'date': dateStr,
          'day': _getDayName(date),
          'steps': stepsMap[dateStr] ?? 0,
        });
      }

      return weeklyData;
    } catch (e) {
      print('Error getting weekly steps: $e');
      return [];
    }
  }

  // ✅ Local storage helpers
  Future<void> _saveStepsLocally(int steps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('today_steps', steps);
  }

  Future<void> _saveResetData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('initial_step_count', _initialStepCount);
    await prefs.setString('last_reset_date', _lastResetDate);
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayDate();
    final savedDate = prefs.getString('last_reset_date') ?? '';

    if (savedDate == today) {
      _initialStepCount = prefs.getInt('initial_step_count') ?? -1;
      _lastResetDate = savedDate;
      _todaySteps = prefs.getInt('today_steps') ?? 0;
    } else {
      _lastResetDate = today;
    }

    // Load today's steps from Firestore
    await _loadStepsFromFirestore();
  }

  // ✅ Load steps from Firestore on app start
  Future<void> _loadStepsFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final today = _getTodayDate();
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('step_logs')
          .doc(today)
          .get()
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () => throw TimeoutException('Query timed out'),
          );

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['steps'] != null) {
          _todaySteps = data['steps'] as int;
          _stepCountController.add(_todaySteps);
          
          // Update local storage
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('today_steps', _todaySteps);
        }
      }
    } catch (e) {
      print('Error loading steps from Firestore: $e');
    }
  }

  String _getTodayDate() => _formatDate(DateTime.now());

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _getDayName(DateTime date) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  void dispose() {
    _stepCountSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();
    _stepCountController.close();
    _pedestrianStatusController.close();
  }
}
