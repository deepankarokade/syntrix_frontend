// =============================================================================
// HealthDataService — Firestore fetch + preprocessing pipeline
// =============================================================================
// Firestore schema used:
//   users/{uid}                       → age/dob, weight, height
//   logs/{uid}/daily_entries          → symptoms map, cycle fields, lifestyle
//   users/{uid}/reports               → metrics map (lh, fsh, amh, prl, prg, rbs, tsh, hb, whr, bmi)
// =============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cycle_prediction_service.dart';
import 'pcos_predictor.dart';

class HealthDataService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PcosPredictor _predictor = PcosPredictor();

  // ── Default fallback values when blood report data is unavailable ──────────
  static const double _defaultRbs = 85.0;   // mid-normal range (mg/dl)
  static const double _defaultTsh = 2.0;    // mid-normal range (mIU/L)
  static const double _defaultHb  = 13.5;   // mid-normal for females (g/dl)
  static const double _defaultWhr = 0.80;   // healthy WHR

  // ── Categorical encoding helpers ──────────────────────────────────────────

  /// Encodes any truthy value → 1.0, falsy → 0.0
  static double _encodeBool(dynamic value) {
    if (value == null) return 0.0;
    if (value is bool) return value ? 1.0 : 0.0;
    final s = value.toString().trim().toLowerCase();
    return (s == 'true' || s == 'yes' || s == 'y' || s == '1') ? 1.0 : 0.0;
  }

  /// Encodes severity string labels to binary (mild → 0, moderate/severe → 1).
  /// Also handles boolean true/false and plain Y/N strings.
  static double _encodeSeverity(dynamic value) {
    if (value == null) return 0.0;
    if (value is bool) return value ? 1.0 : 0.0;
    final s = value.toString().trim().toLowerCase();
    // Severity labels
    if (s == 'mild' || s == 'low' || s == 'none' || s == 'no' || s == 'n'
        || s == 'false' || s == '0') {
      return 0.0;
    }
    if (s == 'moderate' || s == 'mod' || s == 'medium' || s == 'mid'
        || s == 'severe' || s == 'sev' || s == 'high'
        || s == 'yes' || s == 'y' || s == 'true' || s == '1') {
      return 1.0;
    }
    return 0.0;
  }

  /// Encodes cycle regularity: Regular → 2.0, Irregular → 4.0 (matches CSV)
  static double _encodeCycle(dynamic value) {
    if (value == null) return 2.0; // default to regular
    final s = value.toString().trim().toLowerCase();
    if (s == 'regular' || s == 'r' || s == '2') return 2.0;
    return 4.0; // irregular
  }

  /// Safely parse any dynamic value to double, returns null if unparseable.
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Main entry: fetch all data, preprocess, run model, return result
  // ─────────────────────────────────────────────────────────────────────────
  Future<PcosResult?> fetchAndPredictRisk() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      print('HealthDataService: No authenticated user.');
      return null;
    }

    try {
      await _predictor.initialize();

      // ── Step 1: Fetch user profile ────────────────────────────────────────
      final userDoc = await _db.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};

      // Age: prefer explicit field, fallback to dob timestamp
      double age = 26.0;
      if (userData['age'] != null) {
        age = _toDouble(userData['age']) ?? 26.0;
      } else if (userData['dob'] is Timestamp) {
        final dob = (userData['dob'] as Timestamp).toDate();
        age = (DateTime.now().difference(dob).inDays / 365.25);
      }

      // BMI from weight + height (weight kg / height m²)
      final profileWeight = _toDouble(userData['weight']) ?? 65.0;
      final heightCm = _toDouble(userData['height']) ?? 160.0;
      final heightM = heightCm / 100.0;

      // ── Step 2: Fetch latest daily log entries ───────────────────────────
      final logsSnap = await _db
          .collection('logs')
          .doc(uid)
          .collection('daily_entries')
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();

      final entries = logsSnap.docs.map((d) => d.data()).toList();

      // Find the most recently logged values across the last 30 days
      double? recentWaist;
      double? recentHip;
      double? recentWeight;

      for (var entry in entries) {
        if (recentWaist == null && entry['waist'] != null) recentWaist = _toDouble(entry['waist']);
        if (recentHip == null && entry['hip'] != null) recentHip = _toDouble(entry['hip']);
        if (recentWeight == null && entry['weight'] != null) recentWeight = _toDouble(entry['weight']);
      }

      // Find the oldest logged weight in the fetched span
      double? oldestWeight;
      for (var entry in entries.reversed) {
        if (entry['weight'] != null) {
          oldestWeight = _toDouble(entry['weight']);
          break;
        }
      }

      // Current exact values
      final currentWeight = recentWeight ?? profileWeight;
      final bmi = currentWeight / (heightM * heightM);

      print('HealthDataService: age=$age, bmi=$bmi (weight: $currentWeight)');

      // Lifestyle flags from most recent entry
      final latestLog = entries.isNotEmpty ? entries.first : <String, dynamic>{};
      final symptoms = latestLog['symptoms'] as Map<String, dynamic>? ?? {};

      // Dynamically calculate weight gain (if gained ≥ 1 kg from oldest log)
      double dynamicWeightGain = 0.0;
      if (oldestWeight != null && currentWeight > oldestWeight) {
        if ((currentWeight - oldestWeight) >= 1.0) {
          dynamicWeightGain = 1.0;
        }
      }
      final manualWeightGain = _encodeBool(latestLog['weightGain'] ?? symptoms['Weight Gain']);
      final weightGain = (dynamicWeightGain == 1.0) ? 1.0 : manualWeightGain;

      final hairGrowth    = _encodeSeverity(symptoms['Hair Growth'] ?? symptoms['Hirsutism']);
      final pimples       = _encodeSeverity(symptoms['Acne'] ?? symptoms['Pimples']);
      final hairLoss      = _encodeSeverity(symptoms['Hair Loss']);
      final skinDarkening = _encodeSeverity(symptoms['Skin Darkening']);
      final fastFood      = _encodeBool(latestLog['ateFastFood']);
      final regExercise   = _encodeBool(
        latestLog['activity'] != null && latestLog['activity'] != 'None',
      );

      // ── Step 2.5: Fetch Mathematical Cycle Data ────────────────────────
      final cycleData = await CyclePredictionService.getCycleData(uid);
      final cycleType = cycleData.isIrregular ? 4.0 : 2.0;

      // Ensure the model gets the true overall Cycle Length (e.g. 28 days), not just the 5 days of bleeding
      final cycleLengthDays = cycleData.averageCycleLength.toDouble();

      // Waist-to-hip ratio from most recent logs (override default if present)
      double whr = _defaultWhr;
      if (recentWaist != null && recentHip != null && recentHip > 0) {
        whr = recentWaist / recentHip;
      }

      print('HealthDataService: cycleType=$cycleType, cycleDays=$cycleLengthDays, whr=$whr');

      // ── Step 3: Fetch latest blood report ────────────────────────────────
      final reportsSnap = await _db
          .collection('users')
          .doc(uid)
          .collection('reports')
          .orderBy('uploadedAt', descending: true)
          .limit(1)
          .get();

      Map<String, dynamic> metrics = {};
      if (reportsSnap.docs.isNotEmpty) {
        final reportData = reportsSnap.docs.first.data();
        final raw = reportData['metrics'];
        if (raw is Map) {
          metrics = Map<String, dynamic>.from(raw);
        }
      }

      // Extract hormonal markers (null = not in report)
      final lh  = _toDouble(metrics['lh']);
      final fsh = _toDouble(metrics['fsh']);
      final amh = _toDouble(metrics['amh']);
      final prl = _toDouble(metrics['prl']);
      final prg = _toDouble(metrics['prg']);

      // Basic blood markers with defaults
      final rbs = _toDouble(metrics['rbs']) ?? _defaultRbs;
      final tsh = _toDouble(metrics['tsh']) ?? _defaultTsh;
      final hb  = _toDouble(metrics['hb'])  ?? _defaultHb;
      // WHR from report overrides log if present
      if (_toDouble(metrics['whr']) != null) {
        whr = _toDouble(metrics['whr'])!;
      }

      print('HealthDataService: lh=$lh, fsh=$fsh, amh=$amh, rbs=$rbs, tsh=$tsh, hb=$hb');

      // ── Step 4: Build model input map ────────────────────────────────────
      final bool hasHormonalData = (lh != null || fsh != null || amh != null
          || prl != null || prg != null);

      double lhfshRatio = 0.0;
      if (lh != null && fsh != null && fsh > 0) {
        lhfshRatio = lh / fsh;
      }

      final Map<String, double> featureMap = {
        'Age (yrs)':            age,
        'BMI':                  bmi,
        'Cycle(R/I)':           cycleType,
        'Cycle length(days)':   cycleLengthDays,
        'Weight gain(Y/N)':     weightGain,
        'Hair growth(Y/N)':     hairGrowth,
        'Pimples(Y/N)':         pimples,
        'Hair loss(Y/N)':       hairLoss,
        'Skin darkening (Y/N)': skinDarkening,
        'Fast food (Y/N)':      fastFood,
        'Reg.Exercise(Y/N)':    regExercise,
        'RBS(mg/dl)':           rbs,
        'TSH (mIU/L)':          tsh,
        'Hb(g/dl)':             hb,
        'Waist:Hip Ratio':      whr,
        // Advanced hormonal markers (only populated if report exists)
        'LH(mIU/mL)':  ?lh,
        'FSH(mIU/mL)': ?fsh,
        if (hasHormonalData)  'LH/FSH Ratio': lhfshRatio,
        'AMH(ng/mL)':  ?amh,
        'PRL(ng/mL)':  ?prl,
        'PRG(ng/mL)':  ?prg,
      };

      print('HealthDataService: hasHormonalData=$hasHormonalData, '
          'features=${featureMap.length}');

      // ── Step 5: Run prediction ────────────────────────────────────────────
      final result = _predictor.predict(featureMap);
      print('HealthDataService: result=$result');
      return result;

    } catch (e, stack) {
      print('HealthDataService ERROR: $e\n$stack');
      return null;
    }
  }
}
