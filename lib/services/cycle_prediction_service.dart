import 'package:cloud_firestore/cloud_firestore.dart';

class CycleData {
  final int cycleDay;
  final String phaseName;
  final DateTime nextPeriodDate;
  final int daysToNextPeriod;
  final bool isIrregular;
  final int averageCycleLength;
  final int averagePeriodLength;
  final DateTime? lastPeriodStartDate;

  CycleData({
    required this.cycleDay,
    required this.phaseName,
    required this.nextPeriodDate,
    required this.daysToNextPeriod,
    required this.isIrregular,
    required this.averageCycleLength,
    required this.averagePeriodLength,
    this.lastPeriodStartDate,
  });

  factory CycleData.empty() {
    final now = DateTime.now();
    final strippedNow = DateTime(now.year, now.month, now.day);
    return CycleData(
      cycleDay: 0,
      phaseName: 'Tracking Needed',
      nextPeriodDate: strippedNow.add(const Duration(days: 28)),
      daysToNextPeriod: 28,
      isIrregular: false,
      averageCycleLength: 28,
      averagePeriodLength: 5,
      lastPeriodStartDate: null,
    );
  }
}

class CyclePredictionService {
  static Future<CycleData> getCycleData(String uid) async {
    try {
      final entriesCol = FirebaseFirestore.instance
          .collection('logs')
          .doc(uid)
          .collection('daily_entries');

      final snapshot = await entriesCol
          .orderBy('timestamp', descending: true)
          .limit(180)
          .get();

      // Only trust explicit isOnPeriod==true — NOT periodPhase field
      // (periodPhase is user-entered and unreliable for cycle calculations)
      Map<String, bool> periodDayMap = {};
      for (var doc in snapshot.docs) {
        var data = doc.data();
        if (data['isOnPeriod'] == true) {
          try {
            String dateStr = doc.id.split('_').first;
            DateTime.parse(dateStr); // validate format
            periodDayMap[dateStr] = true; // deduplicate multiple logs per day
          } catch (e) { /* ignore malformed */ }
        }
      }
      List<DateTime> periodDays = periodDayMap.keys.map((s) {
        final d = DateTime.parse(s);
        return DateTime(d.year, d.month, d.day);
      }).toList();

      return calculateFromPeriodDays(periodDays);
    } catch (e) {
      print("CyclePredictionService error: $e");
      return CycleData.empty();
    }
  }

  static CycleData calculateFromPeriodDays(List<DateTime> periodDays) {
    if (periodDays.isEmpty) return CycleData.empty();

    // Sort ascending for chronological processing
    periodDays.sort((a, b) => a.compareTo(b));

    // --- Build consecutive-day blocks ---
    List<List<DateTime>> allBlocks = [];
    List<DateTime> currentBlock = [periodDays.first];

    for (int i = 1; i < periodDays.length; i++) {
      final current = periodDays[i];
      final previous = currentBlock.last;
      if (current.difference(previous).inDays.abs() <= 1) {
        currentBlock.add(current);
      } else {
        allBlocks.add(currentBlock);
        currentBlock = [current];
      }
    }
    allBlocks.add(currentBlock);

    // Use all blocks — single-day logs are valid period markers (user may only log Day 1)
    final blocks = allBlocks;

    // If no blocks at all, fall back to empty
    if (blocks.isEmpty) return CycleData.empty();

    List<DateTime> startDates = [];
    List<int> blockLengths = [];
    for (var b in blocks) {
      startDates.add(b.first);
      blockLengths.add(b.length);
    }

    print('CyclePrediction: found ${blocks.length} valid period blocks');
    print('CyclePrediction: start dates = ${startDates.map((d) => "${d.year}-${d.month}-${d.day}").toList()}');

    // Averages
    int averagePeriodLength = 5;
    if (blockLengths.isNotEmpty) {
      int count = 0;
      int sum = 0;
      for (int i = blockLengths.length - 1; i >= 0 && count < 3; i--) {
        sum += blockLengths[i];
        count++;
      }
      averagePeriodLength = (sum / count).round();
    }

    int averageCycleLength = 28;
    bool isIrregular = false;
    if (startDates.length >= 2) {
      int count = 0;
      int sum = 0;
      List<int> lengths = [];
      for (int i = startDates.length - 1; i > 0 && count < 3; i--) {
        int diff = startDates[i].difference(startDates[i - 1]).inDays;
        if (diff > 15 && diff < 90) {
          sum += diff;
          lengths.add(diff);
          count++;
        }
      }
      if (count > 0) {
        averageCycleLength = (sum / count).round();
      }

      if (lengths.length >= 2) {
        int maxDiff = lengths.reduce((a, b) => a > b ? a : b);
        int minDiff = lengths.reduce((a, b) => a < b ? a : b);
        if (maxDiff - minDiff > 8) isIrregular = true;
      }
      if (averageCycleLength > 35 || averageCycleLength < 21) isIrregular = true;
    }

    DateTime lastStartDate = startDates.last;
    final now = DateTime.now();
    final strippedNow = DateTime(now.year, now.month, now.day);

    int cycleDay = strippedNow.difference(lastStartDate).inDays + 1;
    // If cycleDay exceeds averageCycleLength, the next period is overdue — cap at averageCycleLength
    if (cycleDay < 1) cycleDay = 1;
    if (cycleDay > averageCycleLength) cycleDay = averageCycleLength;

    // Future prediction
    DateTime nextPeriodDate = lastStartDate.add(Duration(days: averageCycleLength));
    int daysToNextPeriod = nextPeriodDate.difference(strippedNow).inDays;

    // Phase — always math-based from cycleDay
    String phaseName;
    if (cycleDay >= 1 && cycleDay <= 5) {
      phaseName = "Menstrual Phase";
    } else if (cycleDay >= 6 && cycleDay <= 13) {
      phaseName = "Follicular Phase";
    } else if (cycleDay == 14) {
      phaseName = "Ovulation Phase";
    } else {
      phaseName = "Luteal Phase";
    }

    print('CyclePrediction: lastStart=${lastStartDate.year}-${lastStartDate.month}-${lastStartDate.day}, cycleDay=$cycleDay, avgCycle=$averageCycleLength, phase=$phaseName, daysToNext=$daysToNextPeriod');

    return CycleData(
      cycleDay: cycleDay,
      phaseName: phaseName,
      nextPeriodDate: nextPeriodDate,
      daysToNextPeriod: daysToNextPeriod,
      isIrregular: isIrregular,
      averageCycleLength: averageCycleLength,
      averagePeriodLength: averagePeriodLength,
      lastPeriodStartDate: lastStartDate,
    );
  }
}
