// =============================================================================
// PCOS Risk Prediction — Flutter TFLite Integration
// =============================================================================
import 'tflite_stub.dart' if (dart.library.io) 'package:tflite_flutter/tflite_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Feature lists (must match Python training order exactly)
// ─────────────────────────────────────────────────────────────────────────────
const List<String> basicFeatures = [
  'Age (yrs)', 'BMI', 'Cycle(R/I)', 'Cycle length(days)',
  'Weight gain(Y/N)', 'Hair growth(Y/N)', 'Pimples(Y/N)',
  'Hair loss(Y/N)', 'Skin darkening (Y/N)', 'Fast food (Y/N)',
  'Reg.Exercise(Y/N)', 'RBS(mg/dl)', 'TSH (mIU/L)',
  'Hb(g/dl)', 'Waist:Hip Ratio',
];

const List<String> advancedFeatures = [
  'Age (yrs)', 'BMI', 'Cycle(R/I)', 'Cycle length(days)',
  'Weight gain(Y/N)', 'Hair growth(Y/N)', 'Pimples(Y/N)',
  'Hair loss(Y/N)', 'Skin darkening (Y/N)', 'Fast food (Y/N)',
  'Reg.Exercise(Y/N)', 'LH(mIU/mL)', 'FSH(mIU/mL)',
  'LH/FSH Ratio', 'AMH(ng/mL)', 'PRL(ng/mL)', 'PRG(ng/mL)',
  'TSH (mIU/L)', 'RBS(mg/dl)', 'Waist:Hip Ratio',
];

// Hormonal features — presence of any non-zero value triggers advanced model
const Set<String> hormonalFeatures = {
  'LH(mIU/mL)', 'FSH(mIU/mL)', 'AMH(ng/mL)', 'PRL(ng/mL)', 'PRG(ng/mL)',
};

// ─────────────────────────────────────────────────────────────────────────────
// StandardScaler parameters extracted from trained Python scalers
// ─────────────────────────────────────────────────────────────────────────────
const List<double> _basicMean = [
  31.416666666666668, 24.24722221824858, 0.28703703703703703,
  4.956018518518518, 0.3587962962962963, 0.26851851851851855,
  0.49074074074074076, 0.4675925925925926, 0.30787037037037035,
  0.5162037037037037, 0.24305555555555555, 99.46342591886167,
  3.070990748772467, 11.172407415178087, 0.890347220417526,
];

const List<double> _basicScale = [
  5.427766405083052, 4.0931618438973185, 0.4523790185298555,
  1.526133725400634, 0.4796472808849806, 0.44318881273238037,
  0.49991425876640855, 0.4989486546180165, 0.461612614015672,
  0.4997373710122969, 0.4289283768522839, 15.430613978454318,
  3.9600359016549347, 0.8716572401744972, 0.04625432868134379,
];

const List<double> _advancedMean = [
  31.416666666666668, 24.24722221824858, 0.28703703703703703,
  4.956018518518518, 0.3587962962962963, 0.26851851851851855,
  0.49074074074074076, 0.4675925925925926, 0.30787037037037035,
  0.5162037037037037, 0.24305555555555555, 2.742421291552967,
  17.052062514376033, 0.5537396754284769, 5.730655077137743,
  23.578310196667356, 0.47199305428054045, 3.070990748772467,
  99.46342591886167, 0.890347220417526,
];

const List<double> _advancedScale = [
  5.427766405083052, 4.0931618438973185, 0.4523790185298555,
  1.526133725400634, 0.4796472808849806, 0.44318881273238037,
  0.49991425876640855, 0.4989486546180165, 0.461612614015672,
  0.4997373710122969, 0.4289283768522839, 2.337817803519644,
  242.5740602434877, 0.467836479222898, 5.9845641480444005,
  13.69396405415259, 1.2686536044628467, 3.9600359016549347,
  15.430613978454318, 0.04625432868134379,
];

// ─────────────────────────────────────────────────────────────────────────────
// Result model
// ─────────────────────────────────────────────────────────────────────────────
enum RiskCategory { low, moderate, high }

class PcosResult {
  final double riskScore;
  final int riskPercentage;
  final RiskCategory category;
  final String modelUsed;
  final List<MapEntry<String, double>> topFeatures;
  final Map<String, double> rawFeatures;

  const PcosResult({
    required this.riskScore,
    required this.riskPercentage,
    required this.category,
    required this.modelUsed,
    required this.topFeatures,
    required this.rawFeatures,
  });

  String get categoryLabel {
    switch (category) {
      case RiskCategory.low:      return 'Low';
      case RiskCategory.moderate: return 'Moderate';
      case RiskCategory.high:     return 'High';
    }
  }

  @override
  String toString() =>
      'PcosResult(score: $riskScore, $riskPercentage%, '
      '${category.name}, model: $modelUsed)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Predictor
// ─────────────────────────────────────────────────────────────────────────────
class PcosPredictor {
  Interpreter? _basicInterpreter;
  Interpreter? _advancedInterpreter;
  bool _initialized = false;

  Future<void> initialize() async {
    final options = InterpreterOptions();
    _basicInterpreter = await Interpreter.fromAsset(
      'assets/models/basic_model.tflite',
      options: options,
    );
    _advancedInterpreter = await Interpreter.fromAsset(
      'assets/models/advanced_model.tflite',
      options: options,
    );
    _initialized = true;
    print('PcosPredictor: models loaded successfully.');
  }

  void dispose() {
    _basicInterpreter?.close();
    _advancedInterpreter?.close();
  }

  /// Main entry point.
  /// [input] keys are feature names; values are already preprocessed doubles.
  PcosResult predict(Map<String, double> input, {int topN = 5}) {
    assert(_initialized, 'Call initialize() before predict()');

    // Decide which model to use based on whether hormonal markers are present
    final useAdvanced = hormonalFeatures.any(
      (k) => (input[k] ?? 0.0) > 0.0,
    );

    final featureList = useAdvanced ? advancedFeatures : basicFeatures;
    final mean        = useAdvanced ? _advancedMean    : _basicMean;
    final scale       = useAdvanced ? _advancedScale   : _basicScale;
    final interpreter = useAdvanced ? _advancedInterpreter! : _basicInterpreter!;
    final modelName   = useAdvanced ? 'advanced' : 'basic';

    // Build raw vector in the exact training column order
    final rawVec = featureList.map((f) => input[f] ?? 0.0).toList();

    // Apply StandardScaler: z = (x - mean) / scale
    final scaledVec = List<double>.generate(
      rawVec.length,
      (i) => (rawVec[i] - mean[i]) / scale[i],
    );

    // Run inference — input shape [1, num_features], output shape [1, 1]
    final inputTensor  = [scaledVec.map((v) => v.toDouble()).toList()];
    final outputTensor = [List<double>.filled(1, 0.0)];
    interpreter.run(inputTensor, outputTensor);

    final prob = (outputTensor[0][0]).clamp(0.0, 1.0);
    print('PcosPredictor: model=$modelName, raw_prob=$prob');

    // ── Directional Feature Importance ──
    // Determine if the overall prediction leans towards High/Moderate risk or Low risk
    final isHighRisk = prob >= 0.50;

    // Defines whether a high value of a feature INCREASES (1) or DECREASES (-1) PCOS risk.
    const Map<String, int> featureDirections = {
      'Age (yrs)': -1,
      'BMI': 1,
      'Cycle(R/I)': 1,
      'Cycle length(days)': 1,
      'Weight gain(Y/N)': 1,
      'Hair growth(Y/N)': 1,
      'Pimples(Y/N)': 1,
      'Hair loss(Y/N)': 1,
      'Skin darkening (Y/N)': 1,
      'Fast food (Y/N)': 1,
      'Reg.Exercise(Y/N)': -1,
      'LH(mIU/mL)': 1,
      'FSH(mIU/mL)': 1,
      'LH/FSH Ratio': 1,
      'AMH(ng/mL)': 1,
      'PRL(ng/mL)': 1,
      'PRG(ng/mL)': 1,
      'TSH (mIU/L)': 1,
      'RBS(mg/dl)': 1,
      'Waist:Hip Ratio': 1,
      'Hb(g/dl)': 0, // Neutral
    };

    final indexed = List.generate(
      featureList.length,
      (i) {
        final feature = featureList[i];
        final zScore = scaledVec[i];
        final direction = featureDirections[feature] ?? 1;

        double importance = 0.0;
        if (direction != 0) {
          if (isHighRisk) {
            // Match detrimental anomalies (e.g. high BMI, low exercise)
            if (zScore * direction > 0) importance = (zScore * direction);
          } else {
            // Match protective/healthy behavior (e.g. low BMI, high exercise)
            if (zScore * direction < 0) importance = -(zScore * direction);
          }
        }
        
        // ── BOOSTER for Advanced Markers ──
        // If we are in the advanced model, give a small boost to hormonal markers 
        // to ensure they appear in the top features list even if mathematically 
        // secondary to high-variance features like BMI.
        if (useAdvanced && hormonalFeatures.contains(feature) && importance > 0) {
          importance += 1.5; // Strategic boost
        }
        else if (useAdvanced && feature == 'LH/FSH Ratio' && importance > 0) {
          importance += 1.5;
        }

        return MapEntry(feature, importance);
      },
    )..sort((a, b) => b.value.compareTo(a.value));

    // Filter out features with 0 importance, then take top N
    final topFeatures = indexed.where((e) => e.value > 0).take(topN).toList();

    return PcosResult(
      riskScore:      double.parse(prob.toStringAsFixed(4)),
      riskPercentage: (prob * 100).round(),
      category:       _categorize(prob),
      modelUsed:      modelName,
      topFeatures:    topFeatures,
      rawFeatures:    input,
    );
  }

  RiskCategory _categorize(double p) {
    if (p < 0.35) return RiskCategory.low;
    if (p < 0.65) return RiskCategory.moderate;
    return RiskCategory.high;
  }
}
