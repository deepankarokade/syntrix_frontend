import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../home/home_screen.dart';
import '../../services/user_session.dart';
import '../../services/cycle_prediction_service.dart';

class LogEntryScreen extends StatefulWidget {
  final DateTime? editDate;
  final String? editSlot;
  final Map<String, dynamic>? existingData;

  const LogEntryScreen({
    super.key,
    this.editDate,
    this.editSlot,
    this.existingData,
  });

  @override
  State<LogEntryScreen> createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends State<LogEntryScreen> {
  final user = FirebaseAuth.instance.currentUser;

  // ── User Profile State ──
  String? _lifeStage = 'General Tracking';
  bool _isPeriodActive = false;
  bool _loadingProfile = true;

  late DateTime _selectedLogDate;

  bool _isOnPeriod = false;
  String _periodDay = 'Day 1';
  String? _flowIntensity = 'Medium';
  String? _selectedPhase;
  final Map<String, String> _selectedSymptoms = {};
  String? _selectedMood;
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _bloodSugarCtrl = TextEditingController();
  final TextEditingController _waistCtrl = TextEditingController();
  final TextEditingController _hipCtrl = TextEditingController();
  String _sugarContext = 'Fasting';
  String _selectedSleep = '7h';
  String _selectedActivity = 'Medium';
  String _selectedTime = 'Morning';
  bool _tookMedication = false;
  bool _ateFastFood = false;
  bool _irregularBleeding = false;
  bool _spotting = false;
  final TextEditingController _medicationNameCtrl = TextEditingController();

  // Calendar picker state
  Map<String, Map<String, dynamic>> _periodLogs = {};
  DateTime? _predictedNextPeriod;

  // ── Pregnancy-specific fields ──
  String _nausea = 'None';
  String _swelling = 'None';
  bool _tookPrenatalVitamins = false;
  final TextEditingController _babyKicksCtrl = TextEditingController();
  final TextEditingController _contractionNotesCtrl = TextEditingController();
  final TextEditingController _pregMorningCtrl = TextEditingController();
  final TextEditingController _pregAfternoonCtrl = TextEditingController();
  final TextEditingController _pregNightCtrl = TextEditingController();

  final List<Map<String, String>> _moods = [
    {'emoji': '😢', 'label': 'Sad'},
    {'emoji': '😐', 'label': 'Neutral'},
    {'emoji': '😊', 'label': 'Happy'},
    {'emoji': '🤩', 'label': 'Energetic'},
    {'emoji': '😴', 'label': 'Tired'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedLogDate = widget.editDate ?? DateTime.now();
    _fetchUserProfile();
    _fetchPeriodLogs();
    if (widget.existingData != null) {
      _populateEditData();
    }
  }

  void _populateEditData() {
    final data = widget.existingData!;
    setState(() {
      _selectedTime = widget.editSlot ?? 'Morning';
      _isOnPeriod = data['isOnPeriod'] == true;
      _periodDay = data['periodDay'] ?? 'Day 1';
      _flowIntensity = data['flowIntensity'] ?? 'Medium';
      _selectedPhase = data['periodPhase'];
      _selectedMood = data['mood'];
      if (data['weight'] != null) _weightCtrl.text = data['weight'].toString();
      if (data['bloodSugar'] != null) {
        _bloodSugarCtrl.text = data['bloodSugar'].toString();
      }
      _sugarContext = data['sugarContext'] ?? 'Fasting';
      _selectedSleep = data['sleep'] ?? '7h';
      _selectedActivity = data['activity'] ?? 'Medium';
      _tookMedication = data['medication'] != null;
      if (_tookMedication) _medicationNameCtrl.text = data['medication'];

      if (data['hip'] != null) _hipCtrl.text = data['hip'].toString();
      _ateFastFood = data['ateFastFood'] == true;
      _irregularBleeding = data['irregularBleeding'] == true;
      _spotting = data['spotting'] == true;

      if (data['symptoms'] != null) {
        _selectedSymptoms.clear();
        (data['symptoms'] as Map).forEach((k, v) {
          _selectedSymptoms[k.toString()] = v.toString();
        });
      }
    });
  }

  Future<void> _fetchPeriodLogs() async {
    if (user == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('logs')
          .doc(user!.uid)
          .collection('daily_entries')
          .get();
      Map<String, Map<String, dynamic>> logs = {};
      for (var doc in snapshot.docs) {
        String dateStr = doc.id.split('_').first;
        var data = doc.data();
        if (logs[dateStr] == null || data['isOnPeriod'] == true) {
          logs[dateStr] = data;
        }
      }
      final cycleData = await CyclePredictionService.getCycleData(user!.uid);
      if (mounted) {
        setState(() {
          _periodLogs = logs;
          _predictedNextPeriod = cycleData.nextPeriodDate;
        });
      }
    } catch (e) {
      print('Log entry: error loading period logs: $e');
    }
  }

  Future<void> _fetchUserProfile() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _lifeStage = data['lifeStage'] ?? 'General Tracking';
          _isPeriodActive = data['isPeriodActive'] ?? false;
          _loadingProfile = false;
        });
      }
    } catch (e) {
      print("Error fetching profile for logging: $e");
      setState(() => _loadingProfile = false);
    }
  }

  List<String> _getSymptomsForCondition() {
    switch (_lifeStage?.toLowerCase()) {
      case 'pcos':
        return ['Acne', 'Fatigue', 'Bloating', 'Cramps', 'Mood Swings', 'Headache', 'Facial Hair', 'Hair Loss', 'Skin Darkening', 'Weight Gain', 'Irregular Periods'];
      case 'pregnant':
        return ['Nausea', 'Back Pain', 'Fatigue', 'Headache', 'Heartburn', 'Insomnia', 'Mood Swings', 'Leg Cramps', 'Shortness of Breath', 'Dizziness', 'Constipation'];
      case 'menopause':
        return ['Hot Flashes', 'Night Sweats', 'Fatigue', 'Joint Pain', 'Vaginal Dryness', 'Mood Swings', 'Insomnia', 'Brain Fog', 'Headache', 'Weight Gain', 'Anxiety'];
      default:
        return ['Acne', 'Fatigue', 'Bloating', 'Cramps', 'Mood Swings', 'Headache', 'Hair Loss', 'Hot Flashes', 'Night Sweats', 'Joint Pain'];
    }
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _bloodSugarCtrl.dispose();
    _medicationNameCtrl.dispose();
    _babyKicksCtrl.dispose();
    _contractionNotesCtrl.dispose();
    _pregMorningCtrl.dispose();
    _pregAfternoonCtrl.dispose();
    _pregNightCtrl.dispose();
    super.dispose();
  }

  // ── Validation & Save ──
  Future<void> _saveLog() async {
    if (user == null) return;

    // Weight Validation
    final weight = double.tryParse(_weightCtrl.text);
    if (weight != null && (weight < 30 || weight > 200)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight must be between 30 and 200 kg')),
      );
      return;
    }

    // Blood Sugar Validation
    final sugar = double.tryParse(_bloodSugarCtrl.text);
    if (sugar != null && (sugar < 20 || sugar > 600)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Blood Sugar must be between 20 and 600 mg/dL'),
        ),
      );
      return;
    }

    try {
      final now = _selectedLogDate;
      final dateStr =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

      // Use a flat collection for high-performance fetching
      final entriesCol = FirebaseFirestore.instance
          .collection('logs')
          .doc(user!.uid)
          .collection('daily_entries');
      final docId = "${dateStr}_$_selectedTime";

      await entriesCol.doc(docId).set({
        'timestamp': FieldValue.serverTimestamp(),
        'timeOfLog': _selectedTime,
        'isOnPeriod': (_lifeStage != 'Pregnancy') ? _isOnPeriod : null,
        'periodDay': (_lifeStage != 'Pregnancy' && _isOnPeriod)
            ? _periodDay
            : null,
        'flowIntensity': (_lifeStage != 'Pregnancy' && _isOnPeriod)
            ? _flowIntensity
            : null,
        'symptoms': _selectedSymptoms,
        'mood': _selectedMood,
        'weight': weight,
        'bloodSugar': sugar,
        'sugarContext': _sugarContext,
        'sleep': _selectedSleep,
        'activity': _selectedActivity,
        'waist': double.tryParse(_waistCtrl.text) ?? 0.0,
        'hip': double.tryParse(_hipCtrl.text) ?? 0.0,
        'ateFastFood': _ateFastFood,
        'irregularBleeding': _lifeStage == 'menopause' ? _irregularBleeding : null,
        'spotting': _lifeStage == 'menopause' ? _spotting : null,
        'medication': _tookMedication ? _medicationNameCtrl.text.trim() : null,
        'periodPhase': _isOnPeriod ? 'Menstrual' : _selectedPhase,
        // Pregnancy-specific fields
        'nausea': _lifeStage?.toLowerCase() == 'pregnant' ? _nausea : null,
        'swelling': _lifeStage?.toLowerCase() == 'pregnant' ? _swelling : null,
        'babyKicks': _lifeStage?.toLowerCase() == 'pregnant' ? (int.tryParse(_babyKicksCtrl.text) ?? 0) : null,
        'contractionNotes': _lifeStage?.toLowerCase() == 'pregnant' ? _contractionNotesCtrl.text.trim() : null,
        'prenatalVitamins': _lifeStage?.toLowerCase() == 'pregnant' ? _tookPrenatalVitamins : null,
        'pregnancyLifestyle': _lifeStage?.toLowerCase() == 'pregnant' ? {
          'morning': _pregMorningCtrl.text.trim(),
          'afternoon': _pregAfternoonCtrl.text.trim(),
          'night': _pregNightCtrl.text.trim(),
        } : null,
        'lifeStageAtLog': _lifeStage,
      }, SetOptions(merge: true));

      // ── Update Global Weight ──
      if (weight != null) {
        // 1. Update Firestore Users Collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .update({'weight': weight});

        // 2. Update Local Cache
        UserSession.update(newWeight: weight.toString());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Log saved successfully!'),
            backgroundColor: Colors.teal,
          ),
        );
        // Redirect back up to the Home Screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      print("Error saving log entry: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfile) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Add Log',
          style: TextStyle(
            color: Color(0xFF2E4A6B),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
              const SizedBox(height: 24),
              const Text(
                'Track Your Health',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2B3C),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showCustomDatePicker(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_outlined, color: Color(0xFF3A6EA8), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Date: ${DateFormat('MMMM dd, yyyy').format(_selectedLogDate)} (Tap to change)",
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF3A6EA8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── [ CYCLE ] (Hidden if Pregnant or Menopause) ─────────
              if (_lifeStage != 'pregnant' && _lifeStage != 'menopause' && _lifeStage != 'Pregnancy') ...[
                _sectionHeader('CYCLE'),
                const SizedBox(height: 16),
                _labeledContainer(
                  label: 'On Period Today?',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _choiceButton(
                            'Yes',
                            _isOnPeriod,
                            () => setState(() => _isOnPeriod = true),
                          ),
                          const SizedBox(width: 12),
                          _choiceButton(
                            'No',
                            !_isOnPeriod,
                            () => setState(() => _isOnPeriod = false),
                          ),
                        ],
                      ),
                      if (_isOnPeriod) ...[
                        const SizedBox(height: 24),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Current Day',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7A8FA6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _segmentSelector(
                          options: [
                            'Day 1',
                            'Day 2',
                            'Day 3',
                            'Day 4',
                            'Day 5',
                            'Day 6',
                            'Day 7+',
                          ],
                          selected: _periodDay,
                          onSelect: (val) => setState(() => _periodDay = val),
                        ),
                        const SizedBox(height: 24),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Flow Intensity',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7A8FA6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _segmentSelector(
                          options: ['Low', 'Medium', 'High'],
                          selected: _flowIntensity,
                          onSelect: (val) =>
                              setState(() => _flowIntensity = val),
                        ),
                      ] else ...[
                        const SizedBox(height: 24),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Current Cycle Phase (Optional)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF7A8FA6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _segmentSelector(
                          options: ['Follicular', 'Ovulation', 'Luteal'],
                          selected: _selectedPhase,
                          onSelect: (val) =>
                              setState(() => _selectedPhase = val),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // ── [ MENOPAUSE SPECIFIC ] ────────────────────────────
              if (_lifeStage == 'menopause') ...[
                _sectionHeader('POST-MENOPAUSE STATUS'),
                const SizedBox(height: 16),
                _labeledContainer(
                  label: 'Bleeding / Spotting Status',
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _choiceButton(
                            'Irregular Bleeding',
                            _irregularBleeding,
                            () => setState(() => _irregularBleeding = !_irregularBleeding),
                          ),
                          const SizedBox(width: 12),
                          _choiceButton(
                            'Spotting',
                            _spotting,
                            () => setState(() => _spotting = !_spotting),
                          ),
                        ],
                      ),
                      if (_irregularBleeding || _spotting)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Note: Bleeding after menopause should be discussed with a doctor.',
                            style: TextStyle(color: Color(0xFFB5616A), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // ── [ PREGNANCY SPECIFIC ] ─────────────────────────────
              if (_lifeStage?.toLowerCase() == 'pregnant') ...[
                _sectionHeader('PREGNANCY TRACKING'),
                const SizedBox(height: 16),
                _labeledContainer(
                  label: 'Nausea / Morning Sickness',
                  child: _segmentSelector(
                    options: ['None', 'Mild', 'Moderate', 'Severe'],
                    selected: _nausea,
                    onSelect: (val) => setState(() => _nausea = val),
                  ),
                ),
                const SizedBox(height: 12),
                _labeledContainer(
                  label: 'Swelling (Feet/Hands)',
                  child: _segmentSelector(
                    options: ['None', 'Mild', 'Moderate', 'Severe'],
                    selected: _swelling,
                    onSelect: (val) => setState(() => _swelling = val),
                  ),
                ),
                const SizedBox(height: 12),
                _inputCard(
                  icon: Icons.child_care_rounded,
                  label: 'Baby Kicks (approx count)',
                  controller: _babyKicksCtrl,
                  suffix: 'kicks',
                  hint: '0',
                ),
                const SizedBox(height: 12),
                _labeledContainer(
                  label: 'Prenatal Vitamins Taken?',
                  child: Row(
                    children: [
                      _choiceButton('Yes', _tookPrenatalVitamins, () => setState(() => _tookPrenatalVitamins = true)),
                      const SizedBox(width: 12),
                      _choiceButton('No', !_tookPrenatalVitamins, () => setState(() => _tookPrenatalVitamins = false)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _labeledContainer(
                  label: 'Contraction / Discomfort Notes',
                  child: TextField(
                    controller: _contractionNotesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Any contractions, pelvic pressure, etc.',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _labeledContainer(
                  label: 'Morning Lifestyle Notes',
                  child: TextField(
                    controller: _pregMorningCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Morning sickness, hydration, exercise',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _labeledContainer(
                  label: 'Afternoon Lifestyle Notes',
                  child: TextField(
                    controller: _pregAfternoonCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Diet changes, energy levels',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _labeledContainer(
                  label: 'Night Lifestyle Notes',
                  child: TextField(
                    controller: _pregNightCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Sleep quality, fetal movement',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],

              // ── [ SYMPTOMS ] ───────────────────────────────────────
              _sectionHeader('SYMPTOMS'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _getSymptomsForCondition().map(_buildSymptomChip).toList(),
              ),
              const SizedBox(height: 32),

              // ── [ MOOD ] ───────────────────────────────────────────
              _sectionHeader('MOOD'),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _moods.map((m) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: _moodIcon(m['emoji']!, m['label']!),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),

              // ── [ BODY ] ───────────────────────────────────────────
              _sectionHeader('BODY'),
              const SizedBox(height: 16),
              _inputCard(
                icon: Icons.monitor_weight_outlined,
                label: 'Weight (30-200 kg)',
                controller: _weightCtrl,
                suffix: 'kg',
                hint: '0.0',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _inputCard(
                      icon: Icons.straighten_rounded,
                      label: 'Waist (cm)',
                      controller: _waistCtrl,
                      suffix: 'cm',
                      hint: '0',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _inputCard(
                      icon: Icons.straighten_rounded,
                      label: 'Hip (cm)',
                      controller: _hipCtrl,
                      suffix: 'cm',
                      hint: '0',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── [ METABOLIC ] ──────────────────────────────────────
              _sectionHeader('METABOLIC'),
              const SizedBox(height: 16),
              _labeledContainer(
                label: 'Blood Sugar Tracker (20-600 mg/dL)',
                child: Column(
                  children: [
                    _segmentSelector(
                      options: ['Fasting', 'Post-meal'],
                      selected: _sugarContext,
                      onSelect: (val) => setState(() => _sugarContext = val),
                    ),
                    const SizedBox(height: 16),
                    _inputCard(
                      icon: Icons.opacity_rounded,
                      label: 'Current Reading',
                      controller: _bloodSugarCtrl,
                      suffix: 'mg/dL',
                      hint: '0',
                      iconColor: Colors.red.shade400,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── [ LIFESTYLE ] ──────────────────────────────────────
              _sectionHeader('LIFESTYLE'),
              const SizedBox(height: 16),
              _labeledContainer(
                label: 'Time of Log',
                child: _segmentSelector(
                  options: ['Morning', 'Afternoon', 'Night'],
                  selected: _selectedTime,
                  onSelect: (val) => setState(() => _selectedTime = val),
                ),
              ),
              const SizedBox(height: 12),
              _labeledContainer(
                label: 'Sleep Duration',
                child: _segmentSelector(
                  options: ['<5h', '6h', '7h', '8h', '9h>'],
                  selected: _selectedSleep,
                  onSelect: (val) => setState(() => _selectedSleep = val),
                ),
              ),
              const SizedBox(height: 12),
              _labeledContainer(
                label: 'Activity Level',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _activityIcon(Icons.directions_walk_rounded, 'Low'),
                    _activityIcon(Icons.accessibility_new_rounded, 'Medium'),
                    _activityIcon(Icons.fitness_center_rounded, 'High'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _labeledContainer(
                label: 'Diet: Ate Fast Food?',
                child: Row(
                  children: [
                    _choiceButton(
                      'Yes',
                      _ateFastFood,
                      () => setState(() => _ateFastFood = true),
                    ),
                    const SizedBox(width: 12),
                    _choiceButton(
                      'No',
                      !_ateFastFood,
                      () => setState(() => _ateFastFood = false),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── [ OPTIONAL ] ──────────────────────────────────────
              _sectionHeader('OPTIONAL'),
              const SizedBox(height: 16),
              _labeledContainer(
                label: 'Did you take medication today?',
                child: Column(
                  children: [
                    Row(
                      children: [
                        _choiceButton(
                          'Yes',
                          _tookMedication,
                          () => setState(() => _tookMedication = true),
                        ),
                        const SizedBox(width: 12),
                        _choiceButton(
                          'No',
                          !_tookMedication,
                          () => setState(() => _tookMedication = false),
                        ),
                      ],
                    ),
                    if (_tookMedication) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _medicationNameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Enter medication name...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _saveLog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E4A6B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Log Entry',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
    );
  }

  // ── Helper UI Components ──


  void _showCustomDatePicker() {
    DateTime sheetMonth = DateTime(_selectedLogDate.year, _selectedLogDate.month);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final today = DateTime.now();
            final firstDay = DateTime(sheetMonth.year, sheetMonth.month, 1);
            final daysInMonth = DateTime(sheetMonth.year, sheetMonth.month + 1, 0).day;
            final startWeekday = firstDay.weekday % 7; // 0=Sun

            List<Widget> dayCells = [];
            // Empty leading cells
            for (int i = 0; i < startWeekday; i++) {
              dayCells.add(const SizedBox());
            }
            for (int d = 1; d <= daysInMonth; d++) {
              final dt = DateTime(sheetMonth.year, sheetMonth.month, d);
              final dateStr = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
              final logData = _periodLogs[dateStr];
              final isOnPeriod = logData != null && logData['isOnPeriod'] == true;
              final hasLog = logData != null;
              final isToday = dt.year == today.year && dt.month == today.month && dt.day == today.day;
              final isSelected = dt.year == _selectedLogDate.year && dt.month == _selectedLogDate.month && dt.day == _selectedLogDate.day;
              final isFuture = dt.isAfter(today);

              // Predicted window: next period ± 2 days
              bool isPredicted = false;
              if (_predictedNextPeriod != null && !isOnPeriod) {
                final diff = dt.difference(_predictedNextPeriod!).inDays.abs();
                isPredicted = diff <= 2;
              }

              Color bgColor = Colors.transparent;
              Color textColor = isFuture ? const Color(0xFFB0BEC5) : const Color(0xFF1A2B3C);
              BoxBorder? border;

              if (isOnPeriod) {
                bgColor = const Color(0xFFFFCDD2);
                textColor = const Color(0xFFB5616A);
              } else if (isPredicted) {
                bgColor = const Color(0xFFFFECEC);
                textColor = const Color(0xFFB5616A);
              } else if (hasLog) {
                bgColor = const Color(0xFFE3F2FD);
                textColor = const Color(0xFF1E5BB1);
              }

              if (isToday) {
                border = Border.all(color: const Color(0xFF1E5BB1), width: 2);
              }
              if (isSelected) {
                bgColor = const Color(0xFF1E5BB1);
                textColor = Colors.white;
                border = null;
              }

              dayCells.add(
                GestureDetector(
                  onTap: isFuture ? null : () {
                    setSheetState(() {});
                    setState(() => _selectedLogDate = dt);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: bgColor,
                      shape: BoxShape.circle,
                      border: border,
                    ),
                    child: Center(
                      child: Text(
                        '$d',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected || isToday ? FontWeight.w700 : FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF4F6FA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDDE5EE),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Month navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Color(0xFF1E5BB1)),
                        onPressed: () => setSheetState(() {
                          sheetMonth = DateTime(sheetMonth.year, sheetMonth.month - 1);
                        }),
                      ),
                      Text(
                        DateFormat('MMMM yyyy').format(sheetMonth),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E5BB1),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Color(0xFF1E5BB1)),
                        onPressed: sheetMonth.isBefore(DateTime(today.year, today.month))
                            ? null
                            : () => setSheetState(() {
                                sheetMonth = DateTime(sheetMonth.year, sheetMonth.month + 1);
                              }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Calendar card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Days of week header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                              .map((d) => SizedBox(
                                    width: 36,
                                    child: Center(
                                      child: Text(d,
                                        style: const TextStyle(
                                          color: Color(0xFFA0B1C5),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                        // Grid
                        GridView.count(
                          crossAxisCount: 7,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1,
                          children: dayCells,
                        ),
                        const SizedBox(height: 12),
                        // Legend
                        Wrap(
                          spacing: 14,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _legendDot(const Color(0xFFFFCDD2), 'Period'),
                            _legendDot(const Color(0xFFFFECEC), 'Predicted'),
                            _legendDot(const Color(0xFFE3F2FD), 'Logged'),
                            _legendDot(Colors.white, 'Today', border: const Color(0xFF1E5BB1)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _legendDot(Color color, String label, {Color? border}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: border != null ? Border.all(color: border, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF7A8FA6))),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Color(0xFF1A2B3C),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _labeledContainer({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7A8FA6),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _segmentSelector({
    required List<String> options,
    required String? selected,
    required Function(String) onSelect,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: options.map((opt) {
          bool isSelected = selected == opt;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  opt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF1A2B3C)
                        : const Color(0xFF7A8FA6),
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSymptomChip(String label) {
    bool isSelected = _selectedSymptoms.containsKey(label);
    String severity = _selectedSymptoms[label] ?? 'Mild';

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedSymptoms.remove(label);
          } else {
            _selectedSymptoms[label] = 'Mild';
          }
        });
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFB1D6E2) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF7DA6B8)
                    : const Color(0xFFF0F4F8),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF2E4A6B)
                    : const Color(0xFF5A7EA0),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          if (isSelected) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: ['Mild', 'Mod', 'Sev'].map((s) {
                bool isS = severity.startsWith(s);
                return GestureDetector(
                  onTap: () => setState(
                    () => _selectedSymptoms[label] = s == 'Mod'
                        ? 'Moderate'
                        : (s == 'Sev' ? 'Severe' : 'Mild'),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isS ? const Color(0xFF2E4A6B) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF0F4F8)),
                    ),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 9,
                        color: isS ? Colors.white : const Color(0xFF2E4A6B),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionCard(
    IconData icon,
    String label,
    Color color,
    Color bgColor, {
    bool disabled = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: disabled ? Colors.grey.withValues(alpha: 0.1) : bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: disabled ? Colors.grey : const Color(0xFF1A2B3C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moodIcon(String emoji, String label) {
    bool isSelected = _selectedMood == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedMood = label),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFECF4FF) : Colors.white,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: const Color(0xFF7DA6B8), width: 2)
                  : Border.all(color: const Color(0xFFF0F4F8)),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected
                  ? const Color(0xFF2E4A6B)
                  : const Color(0xFF7A8FA6),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputCard({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    String? suffix,
    String? hint,
    Color? iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor ?? const Color(0xFF7DA6B8), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7A8FA6),
                  ),
                ),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2B3C),
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                    suffixText: suffix,
                    suffixStyle: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF7A8FA6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activityIcon(IconData icon, String label) {
    bool isSelected = _selectedActivity == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedActivity = label),
      child: Column(
        children: [
          Icon(
            icon,
            color: isSelected
                ? const Color(0xFF2E4A6B)
                : const Color(0xFFD0DCE7),
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isSelected
                  ? const Color(0xFF2E4A6B)
                  : const Color(0xFF7A8FA6),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _choiceButton(String text, bool active, VoidCallback onTap) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? const Color(0xFF2E4A6B) : Colors.white,
          foregroundColor: active ? Colors.white : const Color(0xFF2E4A6B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: const Color(0xFFF0F4F8)),
          ),
        ),
        child: Text(text),
      ),
    );
  }
}
