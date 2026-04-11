import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/pregnancy_log_service.dart';

class PregnancyLogScreen extends StatefulWidget {
  final DateTime? editDate;
  final String? initialSlot;

  const PregnancyLogScreen({super.key, this.editDate, this.initialSlot});

  @override
  State<PregnancyLogScreen> createState() => _PregnancyLogScreenState();
}

class _PregnancyLogScreenState extends State<PregnancyLogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _selectedDate;
  bool _isSaving = false;
  bool _isLoading = true;

  // Answers for each time slot
  final Map<String, dynamic> _morningAnswers = {};
  final Map<String, dynamic> _afternoonAnswers = {};
  final Map<String, dynamic> _nightAnswers = {};

  // Text controllers for text fields
  final Map<String, TextEditingController> _textControllers = {};

  // For multiselect items
  final Map<String, List<String>> _multiSelectAnswers = {};

  // Track which slots are already saved
  final Map<String, bool> _slotSaved = {
    'morning': false,
    'afternoon': false,
    'night': false,
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.editDate ?? DateTime.now();

    int initialIndex = 0;
    if (widget.initialSlot != null) {
      switch (widget.initialSlot!.toLowerCase()) {
        case 'afternoon':
          initialIndex = 1;
          break;
        case 'night':
          initialIndex = 2;
          break;
        default:
          initialIndex = 0;
      }
    } else {
      // Auto-select based on current time
      final hour = DateTime.now().hour;
      if (hour >= 17) {
        initialIndex = 2;
      } else if (hour >= 12) {
        initialIndex = 1;
      }
    }

    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _initializeTextControllers();
    _loadExistingLogs();
  }

  void _initializeTextControllers() {
    for (final q in PregnancyLogService.morningQuestions) {
      if (q['type'] == 'text') {
        _textControllers['morning_${q['key']}'] = TextEditingController();
      }
    }
    for (final q in PregnancyLogService.afternoonQuestions) {
      if (q['type'] == 'text') {
        _textControllers['afternoon_${q['key']}'] = TextEditingController();
      }
    }
    for (final q in PregnancyLogService.nightQuestions) {
      if (q['type'] == 'text') {
        _textControllers['night_${q['key']}'] = TextEditingController();
      }
      if (q['type'] == 'multiselect') {
        _multiSelectAnswers[q['key']] = [];
      }
    }
  }

  Future<void> _loadExistingLogs() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final logs = await PregnancyLogService.getTodayLogs(uid);

      if (logs.containsKey('morning')) {
        _morningAnswers.addAll(logs['morning']!);
        _slotSaved['morning'] = true;
        _populateTextControllers('morning', logs['morning']!);
      }
      if (logs.containsKey('afternoon')) {
        _afternoonAnswers.addAll(logs['afternoon']!);
        _slotSaved['afternoon'] = true;
        _populateTextControllers('afternoon', logs['afternoon']!);
      }
      if (logs.containsKey('night')) {
        _nightAnswers.addAll(logs['night']!);
        _slotSaved['night'] = true;
        _populateTextControllers('night', logs['night']!);
        // Restore multiselect
        for (final q in PregnancyLogService.nightQuestions) {
          if (q['type'] == 'multiselect' && logs['night']![q['key']] != null) {
            _multiSelectAnswers[q['key']] =
                List<String>.from(logs['night']![q['key']]);
          }
        }
      }
    } catch (e) {
      print('PregnancyLog: Error loading existing logs: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _populateTextControllers(String slot, Map<String, dynamic> data) {
    data.forEach((key, value) {
      final ctrlKey = '${slot}_$key';
      if (_textControllers.containsKey(ctrlKey) && value != null) {
        _textControllers[ctrlKey]!.text = value.toString();
      }
    });
  }

  Map<String, dynamic> _getAnswersForSlot(String slot) {
    switch (slot) {
      case 'morning':
        return _morningAnswers;
      case 'afternoon':
        return _afternoonAnswers;
      case 'night':
        return _nightAnswers;
      default:
        return {};
    }
  }

  List<Map<String, dynamic>> _getQuestionsForSlot(String slot) {
    switch (slot) {
      case 'morning':
        return PregnancyLogService.morningQuestions;
      case 'afternoon':
        return PregnancyLogService.afternoonQuestions;
      case 'night':
        return PregnancyLogService.nightQuestions;
      default:
        return [];
    }
  }

  Future<void> _saveCurrentSlot() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final slots = ['morning', 'afternoon', 'night'];
    final currentSlot = slots[_tabController.index];
    final answers = _getAnswersForSlot(currentSlot);

    // Collect text fields
    for (final q in _getQuestionsForSlot(currentSlot)) {
      if (q['type'] == 'text') {
        final ctrl = _textControllers['${currentSlot}_${q['key']}'];
        if (ctrl != null && ctrl.text.isNotEmpty) {
          answers[q['key']] = ctrl.text.trim();
        }
      }
      if (q['type'] == 'multiselect') {
        answers[q['key']] = _multiSelectAnswers[q['key']] ?? [];
      }
    }

    setState(() => _isSaving = true);

    try {
      await PregnancyLogService.savePregnancyLog(
        uid: uid,
        date: _selectedDate,
        timeSlot: currentSlot,
        answers: answers,
      );

      setState(() {
        _slotSaved[currentSlot] = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text('${currentSlot[0].toUpperCase()}${currentSlot.substring(1)} log saved! ✨'),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D6B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        // Auto-advance to next slot if available
        if (_tabController.index < 2) {
          _tabController.animateTo(_tabController.index + 1);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving log: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final ctrl in _textControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pregnancy Lifestyle Log',
              style: TextStyle(
                color: Color(0xFF2E4A6B),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            Text(
              DateFormat('EEEE, MMMM dd').format(_selectedDate),
              style: const TextStyle(
                color: Color(0xFF7A8FA6),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF7A8FA6),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              tabs: [
                _buildTab('🌅 Morning', _slotSaved['morning'] == true),
                _buildTab('☀️ Afternoon', _slotSaved['afternoon'] == true),
                _buildTab('🌙 Night', _slotSaved['night'] == true),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF3A6EA8)),
                  const SizedBox(height: 16),
                  Text('Loading your logs...',
                      style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildQuestionList('morning'),
                _buildQuestionList('afternoon'),
                _buildQuestionList('night'),
              ],
            ),
    );
  }

  Tab _buildTab(String text, bool saved) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          if (saved) ...[
            const SizedBox(width: 4),
            const Icon(Icons.check_circle, size: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionList(String slot) {
    final questions = _getQuestionsForSlot(slot);
    final answers = _getAnswersForSlot(slot);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final q = questions[index];
              return _buildQuestionCard(q, slot, answers, index);
            },
          ),
        ),
        // Save button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveCurrentSlot,
              style: ElevatedButton.styleFrom(
                backgroundColor: _slotSaved[slot] == true
                    ? const Color(0xFF2E7D6B)
                    : Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _slotSaved[slot] == true
                              ? Icons.update
                              : Icons.save_rounded,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _slotSaved[slot] == true
                              ? 'Update ${slot[0].toUpperCase()}${slot.substring(1)} Log'
                              : 'Save ${slot[0].toUpperCase()}${slot.substring(1)} Log',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(
    Map<String, dynamic> q,
    String slot,
    Map<String, dynamic> answers,
    int index,
  ) {
    final key = q['key'] as String;
    final question = q['question'] as String;
    final type = q['type'] as String;
    final icon = q['icon'] as String? ?? '📋';

    return AnimatedContainer(
      duration: Duration(milliseconds: 200 + (index * 50)),
      curve: Curves.easeOut,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.displayLarge?.color,
                  ),
                ),
              ),
              if (answers.containsKey(key))
                const Icon(Icons.check_circle, color: Color(0xFF2E7D6B), size: 18),
            ],
          ),
          const SizedBox(height: 12),
          // Answer widget based on type
          _buildAnswerWidget(type, q, key, slot, answers),
        ],
      ),
    );
  }

  Widget _buildAnswerWidget(
    String type,
    Map<String, dynamic> q,
    String key,
    String slot,
    Map<String, dynamic> answers,
  ) {
    switch (type) {
      case 'select':
      case 'severity':
        return _buildSelectOptions(q, key, answers);
      case 'yesno':
        return _buildYesNo(key, answers);
      case 'text':
        return _buildTextInput(q, slot, key);
      case 'multiselect':
        return _buildMultiSelect(q, key, answers);
      default:
        return const SizedBox();
    }
  }

  Widget _buildSelectOptions(
    Map<String, dynamic> q,
    String key,
    Map<String, dynamic> answers,
  ) {
    final options = (q['options'] as List).cast<String>();
    final selected = answers[key];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected == opt;
        return GestureDetector(
          onTap: () {
            setState(() {
              answers[key] = opt;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF3A6EA8)
                  : const Color(0xFFF4F6FA),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? null
                  : Border.all(color: const Color(0xFFE8EDF3)),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF5A7EA0),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildYesNo(String key, Map<String, dynamic> answers) {
    final selected = answers[key];
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => answers[key] = true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: selected == true
                    ? const Color(0xFF2E7D6B)
                    : const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(12),
                border: selected == true
                    ? null
                    : Border.all(color: const Color(0xFFE8EDF3)),
              ),
              child: Center(
                child: Text(
                  '✅ Yes',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected == true
                        ? Colors.white
                        : const Color(0xFF5A7EA0),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => answers[key] = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: selected == false
                    ? const Color(0xFFB5616A)
                    : const Color(0xFFF4F6FA),
                borderRadius: BorderRadius.circular(12),
                border: selected == false
                    ? null
                    : Border.all(color: const Color(0xFFE8EDF3)),
              ),
              child: Center(
                child: Text(
                  '❌ No',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected == false
                        ? Colors.white
                        : const Color(0xFF5A7EA0),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextInput(Map<String, dynamic> q, String slot, String key) {
    final ctrl = _textControllers['${slot}_$key'];
    return TextField(
      controller: ctrl,
      maxLines: 2,
      decoration: InputDecoration(
        hintText: q['hint'] ?? 'Type here...',
        hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3A6EA8), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF1A2B3C),
      ),
    );
  }

  Widget _buildMultiSelect(
    Map<String, dynamic> q,
    String key,
    Map<String, dynamic> answers,
  ) {
    final options = (q['options'] as List).cast<String>();
    final selected = _multiSelectAnswers[key] ?? [];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selected.contains(opt);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (opt == 'None') {
                _multiSelectAnswers[key] = ['None'];
              } else {
                _multiSelectAnswers[key]?.remove('None');
                if (isSelected) {
                  _multiSelectAnswers[key]?.remove(opt);
                } else {
                  _multiSelectAnswers[key]?.add(opt);
                }
              }
              answers[key] = _multiSelectAnswers[key];
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? (opt == 'None'
                      ? const Color(0xFF2E7D6B)
                      : const Color(0xFFE57373))
                  : const Color(0xFFF4F6FA),
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? null
                  : Border.all(color: const Color(0xFFE8EDF3)),
            ),
            child: Text(
              opt,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF5A7EA0),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
