import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing pregnancy lifestyle logs stored in Firebase.
/// Handles structured morning/afternoon/night questionnaire data
/// and provides aggregated data for AI insights.
class PregnancyLogService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Morning Questions ──────────────────────────────────────────────────
  static const List<Map<String, dynamic>> morningQuestions = [
    {
      'key': 'wakeUpTime',
      'question': 'What time did you wake up?',
      'type': 'select',
      'options': ['Before 5 AM', '5-6 AM', '6-7 AM', '7-8 AM', 'After 8 AM'],
      'icon': '🌅',
    },
    {
      'key': 'morningNausea',
      'question': 'How is your morning sickness?',
      'type': 'severity',
      'options': ['None', 'Mild', 'Moderate', 'Severe'],
      'icon': '🤢',
    },
    {
      'key': 'breakfast',
      'question': 'Did you eat breakfast?',
      'type': 'yesno',
      'icon': '🥣',
    },
    {
      'key': 'breakfastType',
      'question': 'What did you have for breakfast?',
      'type': 'text',
      'hint': 'e.g. Oatmeal with fruits, toast, eggs...',
      'icon': '🍳',
    },
    {
      'key': 'morningWater',
      'question': 'How many glasses of water so far?',
      'type': 'select',
      'options': ['0', '1', '2', '3', '4+'],
      'icon': '💧',
    },
    {
      'key': 'morningExercise',
      'question': 'Did you do any morning exercise/yoga?',
      'type': 'select',
      'options': ['None', 'Light Walk', 'Yoga', 'Stretching', 'Other'],
      'icon': '🧘',
    },
    {
      'key': 'prenatalVitamin',
      'question': 'Did you take your prenatal vitamins?',
      'type': 'yesno',
      'icon': '💊',
    },
    {
      'key': 'morningMood',
      'question': 'How are you feeling this morning?',
      'type': 'select',
      'options': ['😊 Great', '😐 Okay', '😞 Low', '😰 Anxious', '😤 Irritable'],
      'icon': '🎭',
    },
  ];

  // ── Afternoon Questions ────────────────────────────────────────────────
  static const List<Map<String, dynamic>> afternoonQuestions = [
    {
      'key': 'lunch',
      'question': 'Did you eat lunch on time?',
      'type': 'yesno',
      'icon': '🍱',
    },
    {
      'key': 'lunchType',
      'question': 'What did you have for lunch?',
      'type': 'text',
      'hint': 'e.g. Rice, dal, vegetables, roti...',
      'icon': '🥗',
    },
    {
      'key': 'afternoonSnack',
      'question': 'Did you have a healthy snack?',
      'type': 'select',
      'options': ['None', 'Fruits', 'Nuts', 'Yogurt', 'Juice', 'Junk Food'],
      'icon': '🍎',
    },
    {
      'key': 'afternoonWater',
      'question': 'Water intake since morning?',
      'type': 'select',
      'options': ['1-2 glasses', '3-4 glasses', '5-6 glasses', '7+ glasses'],
      'icon': '💧',
    },
    {
      'key': 'energyLevel',
      'question': 'How is your energy level?',
      'type': 'severity',
      'options': ['Very Low', 'Low', 'Normal', 'Good'],
      'icon': '⚡',
    },
    {
      'key': 'babyMovement',
      'question': 'Did you feel baby movements today?',
      'type': 'select',
      'options': ['Not yet', 'A few', 'Normal', 'Very Active', 'Unusually Quiet'],
      'icon': '👶',
    },
    {
      'key': 'afternoonRest',
      'question': 'Did you take a rest/nap?',
      'type': 'select',
      'options': ['No', '15-30 min', '30-60 min', '1+ hour'],
      'icon': '😴',
    },
    {
      'key': 'swelling',
      'question': 'Any swelling in feet/hands?',
      'type': 'severity',
      'options': ['None', 'Mild', 'Moderate', 'Severe'],
      'icon': '🦶',
    },
    {
      'key': 'stressLevel',
      'question': 'Stress level this afternoon?',
      'type': 'severity',
      'options': ['Calm', 'Mild Stress', 'Moderate', 'High Stress'],
      'icon': '🧠',
    },
  ];

  // ── Night Questions ────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> nightQuestions = [
    {
      'key': 'dinner',
      'question': 'Did you eat dinner?',
      'type': 'yesno',
      'icon': '🍽️',
    },
    {
      'key': 'dinnerType',
      'question': 'What did you have for dinner?',
      'type': 'text',
      'hint': 'e.g. Chapati, sabzi, dal, rice...',
      'icon': '🥘',
    },
    {
      'key': 'dinnerTime',
      'question': 'What time did you eat dinner?',
      'type': 'select',
      'options': ['Before 7 PM', '7-8 PM', '8-9 PM', '9-10 PM', 'After 10 PM'],
      'icon': '🕗',
    },
    {
      'key': 'totalWater',
      'question': 'Total water intake today?',
      'type': 'select',
      'options': ['Less than 4 glasses', '4-6 glasses', '7-8 glasses', '9-10 glasses', '10+ glasses'],
      'icon': '💧',
    },
    {
      'key': 'nightKicks',
      'question': 'Baby kick count this evening?',
      'type': 'select',
      'options': ['None felt', '1-5', '5-10', '10-20', '20+'],
      'icon': '🤰',
    },
    {
      'key': 'nightPain',
      'question': 'Any pain or discomfort?',
      'type': 'multiselect',
      'options': ['None', 'Back Pain', 'Pelvic Pain', 'Leg Cramps', 'Headache', 'Contractions', 'Heartburn'],
      'icon': '⚠️',
    },
    {
      'key': 'caffeine',
      'question': 'Did you consume caffeine today?',
      'type': 'select',
      'options': ['None', '1 cup tea/coffee', '2 cups', '3+ cups'],
      'icon': '☕',
    },
    {
      'key': 'junkFood',
      'question': 'Did you eat junk/processed food?',
      'type': 'yesno',
      'icon': '🍔',
    },
    {
      'key': 'screenTime',
      'question': 'Screen time before bed?',
      'type': 'select',
      'options': ['None', 'Less than 30 min', '30-60 min', '1-2 hours', '2+ hours'],
      'icon': '📱',
    },
    {
      'key': 'sleepQuality',
      'question': 'How was your sleep last night?',
      'type': 'severity',
      'options': ['Poor', 'Fair', 'Good', 'Excellent'],
      'icon': '🌙',
    },
    {
      'key': 'todaySummary',
      'question': 'Anything else to note about today?',
      'type': 'text',
      'hint': 'Any concerns, symptoms, or feelings...',
      'icon': '📝',
    },
  ];

  /// Save a pregnancy lifestyle log for a specific time slot
  static Future<void> savePregnancyLog({
    required String uid,
    required DateTime date,
    required String timeSlot, // 'morning', 'afternoon', 'night'
    required Map<String, dynamic> answers,
  }) async {
    final dateStr =
        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final docId = "${dateStr}_pregnancy_${timeSlot.toLowerCase()}";

    await _db
        .collection('pregnancy_logs')
        .doc(uid)
        .collection('daily_lifestyle')
        .doc(docId)
        .set({
      'date': dateStr,
      'timeSlot': timeSlot,
      'answers': answers,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fetch today's pregnancy logs for all 3 time slots
  static Future<Map<String, Map<String, dynamic>>> getTodayLogs(String uid) async {
    final now = DateTime.now();
    final dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    Map<String, Map<String, dynamic>> result = {};

    for (final slot in ['morning', 'afternoon', 'night']) {
      final docId = "${dateStr}_pregnancy_$slot";
      final doc = await _db
          .collection('pregnancy_logs')
          .doc(uid)
          .collection('daily_lifestyle')
          .doc(docId)
          .get();
      if (doc.exists) {
        result[slot] = doc.data()?['answers'] as Map<String, dynamic>? ?? {};
      }
    }
    return result;
  }

  /// Fetch pregnancy logs for the last N days (for AI context)
  static Future<List<Map<String, dynamic>>> getRecentLogs(String uid, {int days = 14}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    
    final snapshot = await _db
        .collection('pregnancy_logs')
        .doc(uid)
        .collection('daily_lifestyle')
        .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoff))
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['docId'] = doc.id;
      return data;
    }).toList();
  }

  /// Build comprehensive pregnancy context string for AI
  static Future<String> buildPregnancyAIContext(String uid) async {
    final logs = await getRecentLogs(uid, days: 14);

    if (logs.isEmpty) {
      return "No pregnancy lifestyle logs found for the last 14 days.";
    }

    StringBuffer ctx = StringBuffer();
    ctx.writeln("PREGNANCY LIFESTYLE LOGS (LAST 14 DAYS):");
    ctx.writeln("=" * 50);

    // Group by date
    Map<String, List<Map<String, dynamic>>> byDate = {};
    for (final log in logs) {
      final date = log['date'] ?? 'Unknown';
      byDate.putIfAbsent(date, () => []);
      byDate[date]!.add(log);
    }

    for (final entry in byDate.entries) {
      ctx.writeln("\n📅 Date: ${entry.key}");
      for (final log in entry.value) {
        final slot = log['timeSlot'] ?? 'Unknown';
        final answers = log['answers'] as Map<String, dynamic>? ?? {};
        ctx.writeln("  ⏰ $slot:");
        answers.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            ctx.writeln("    - $key: $value");
          }
        });
      }
    }

    // Analyze patterns
    ctx.writeln("\nLIFESTYLE PATTERN ANALYSIS:");
    _analyzePatterns(logs, ctx);

    return ctx.toString();
  }

  /// Analyze lifestyle patterns for red flags and recommendations
  static void _analyzePatterns(List<Map<String, dynamic>> logs, StringBuffer ctx) {
    int skippedMeals = 0;
    int junkFoodDays = 0;
    int lowWaterDays = 0;
    int poorSleepDays = 0;
    int noExerciseDays = 0;
    int highCaffeineDays = 0;
    int noVitaminDays = 0;
    int highStressDays = 0;
    int severeNauseaDays = 0;
    int painReportDays = 0;

    Set<String> processedDates = {};

    for (final log in logs) {
      final answers = log['answers'] as Map<String, dynamic>? ?? {};
      final date = log['date'] ?? '';
      final slot = log['timeSlot'] ?? '';

      if (slot == 'morning') {
        if (answers['breakfast'] == false || answers['breakfast'] == 'No') skippedMeals++;
        if (answers['morningExercise'] == 'None') noExerciseDays++;
        if (answers['prenatalVitamin'] == false || answers['prenatalVitamin'] == 'No') noVitaminDays++;
        if (answers['morningNausea'] == 'Severe') severeNauseaDays++;
      }

      if (slot == 'afternoon') {
        if (answers['lunch'] == false || answers['lunch'] == 'No') skippedMeals++;
        if (answers['stressLevel'] == 'High Stress' || answers['stressLevel'] == 'Moderate') highStressDays++;
        if (answers['swelling'] == 'Moderate' || answers['swelling'] == 'Severe') {
          if (!processedDates.contains('swell_$date')) {
            painReportDays++;
            processedDates.add('swell_$date');
          }
        }
      }

      if (slot == 'night') {
        if (answers['dinner'] == false || answers['dinner'] == 'No') skippedMeals++;
        if (answers['junkFood'] == true || answers['junkFood'] == 'Yes') junkFoodDays++;
        if (answers['totalWater'] == 'Less than 4 glasses') lowWaterDays++;
        if (answers['sleepQuality'] == 'Poor' || answers['sleepQuality'] == 'Fair') poorSleepDays++;
        if (answers['caffeine'] == '3+ cups' || answers['caffeine'] == '2 cups') highCaffeineDays++;
        final pain = answers['nightPain'];
        if (pain != null && pain is List && !pain.contains('None') && pain.isNotEmpty) {
          if (!processedDates.contains('pain_$date')) {
            painReportDays++;
            processedDates.add('pain_$date');
          }
        }
      }
    }

    ctx.writeln("⚠️ RED FLAGS DETECTED:");
    if (skippedMeals > 3) ctx.writeln("  - Frequently skipping meals ($skippedMeals times in 14 days)");
    if (junkFoodDays > 2) ctx.writeln("  - Consuming junk food frequently ($junkFoodDays days)");
    if (lowWaterDays > 3) ctx.writeln("  - LOW water intake on $lowWaterDays days — DEHYDRATION risk");
    if (poorSleepDays > 3) ctx.writeln("  - Poor sleep quality on $poorSleepDays days");
    if (noExerciseDays > 5) ctx.writeln("  - No morning exercise on $noExerciseDays days");
    if (highCaffeineDays > 2) ctx.writeln("  - HIGH caffeine intake on $highCaffeineDays days — RISKY for pregnancy");
    if (noVitaminDays > 3) ctx.writeln("  - Missed prenatal vitamins on $noVitaminDays days");
    if (highStressDays > 3) ctx.writeln("  - High stress levels reported on $highStressDays days");
    if (severeNauseaDays > 3) ctx.writeln("  - Severe nausea on $severeNauseaDays days — consult doctor");
    if (painReportDays > 3) ctx.writeln("  - Pain/discomfort reported on $painReportDays days");
    
    if (skippedMeals <= 3 && junkFoodDays <= 2 && lowWaterDays <= 3 && poorSleepDays <= 3) {
      ctx.writeln("  ✅ Overall lifestyle patterns look healthy!");
    }
  }

  /// Calculate estimated due date from LMP or conception date
  static DateTime? calculateDueDate({DateTime? lmpDate, int? pregnancyWeek}) {
    if (lmpDate != null) {
      // Naegele's Rule: LMP + 280 days (40 weeks)
      return lmpDate.add(const Duration(days: 280));
    }
    if (pregnancyWeek != null && pregnancyWeek > 0) {
      final remainingWeeks = 40 - pregnancyWeek;
      return DateTime.now().add(Duration(days: remainingWeeks * 7));
    }
    return null;
  }

  /// Get the current pregnancy week from profile
  static Future<Map<String, dynamic>> getPregnancyInfo(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data() ?? {};

    int currentWeek = 24; // default
    DateTime? lmpDate;
    DateTime? dueDate;

    if (data['lmpDate'] != null) {
      if (data['lmpDate'] is Timestamp) {
        lmpDate = (data['lmpDate'] as Timestamp).toDate();
      }
    }

    if (data['pregnancyWeek'] != null) {
      currentWeek = int.tryParse(data['pregnancyWeek'].toString()) ?? 24;
    }

    // Calculate due date
    dueDate = calculateDueDate(lmpDate: lmpDate, pregnancyWeek: currentWeek);

    // Calculate current week from LMP if available
    if (lmpDate != null) {
      currentWeek = (DateTime.now().difference(lmpDate).inDays / 7).floor();
      if (currentWeek < 1) currentWeek = 1;
      if (currentWeek > 42) currentWeek = 42;
    }

    String trimester = '1st Trimester';
    if (currentWeek >= 14 && currentWeek <= 26) {
      trimester = '2nd Trimester';
    } else if (currentWeek >= 27) {
      trimester = '3rd Trimester';
    }

    return {
      'currentWeek': currentWeek,
      'trimester': trimester,
      'lmpDate': lmpDate,
      'dueDate': dueDate,
      'remainingWeeks': dueDate != null
          ? ((dueDate.difference(DateTime.now()).inDays) / 7).ceil()
          : (40 - currentWeek),
      'remainingDays': dueDate != null
          ? dueDate.difference(DateTime.now()).inDays
          : (40 - currentWeek) * 7,
    };
  }
}
