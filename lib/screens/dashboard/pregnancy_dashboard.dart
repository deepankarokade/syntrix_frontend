import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../onboarding/condition_selection_screen.dart';
import '../chatbot/chatbot_screen.dart';
import '../diet/diet_planner_screen.dart';
import 'medicine_schedule_screen.dart';

class PregnancyDashboard extends StatefulWidget {
  final String userName;
  final String conditionLabel;
  final String trimester;
  final double? weight;
  final Function(int) onTabChange;

  const PregnancyDashboard({
    super.key,
    required this.userName,
    required this.conditionLabel,
    required this.trimester,
    this.weight,
    required this.onTabChange,
  });

  @override
  State<PregnancyDashboard> createState() => _PregnancyDashboardState();
}

class _PregnancyDashboardState extends State<PregnancyDashboard> {
  double? _localWeight;
  String trimester = "";
  int _pregnancyWeek = 20; // Default fallback
  double _waterLiters = 0.0;
  final double _waterGoal = 2.5; // 2.5 Liters standard
  
  bool _hasSugar = false;
  double? _lastSugarValue;
  String _sugarContext = '';

  @override
  void initState() {
    super.initState();
    trimester = widget.trimester;
    _localWeight = widget.weight;
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load weight
    final savedWeight = prefs.getDouble('userWeight');
    
    // Load trimester if empty
    String? savedTrimester;
    if (trimester.isEmpty) {
      savedTrimester = prefs.getString('selectedTrimester');
    }

    // Load pregnancy week with a robust default fallback of 1
    final int savedWeek = (prefs.getInt('pregnancyWeek') ?? 1).clamp(1, 40);

    if (mounted) {
      setState(() {
        if (savedWeight != null) _localWeight = savedWeight;
        if (savedTrimester != null) trimester = savedTrimester;
        _pregnancyWeek = savedWeek;
        _waterLiters = prefs.getDouble('water_liters_${DateTime.now().toIso8601String().split('T')[0]}') ?? 0.0;
      });
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Fetch user profile to see if they have sugar tracking enabled
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists && mounted) {
          final data = userDoc.data()!;
          setState(() {
            // If they have explicit field or if they have previously logged sugar
            _hasSugar = data['hasDiabetes'] ?? data['trackSugar'] ?? false;
          });
        }

        // Fetch latest sugar log regardless of setting to be safe
        final logs = await FirebaseFirestore.instance
            .collection('logs')
            .doc(user.uid)
            .collection('daily_entries')
            .where('bloodSugar', isNull: false)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
        
        if (logs.docs.isNotEmpty && mounted) {
          final logData = logs.docs.first.data();
          setState(() {
            _lastSugarValue = (logData['bloodSugar'] as num).toDouble();
            _sugarContext = logData['sugarContext'] ?? '';
            // If they have data, we should probably show the card anyway
            _hasSugar = true;
          });
        }
      } catch (e) {
        print("Error loading sugar data: $e");
      }
    }
  }

  void onTabChange(int index) {
    widget.onTabChange(index);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        const SizedBox(height: 18),

        // ── Top bar ──────────────────────────────────────────
        Row(
          children: [
            const Icon(Icons.face, size: 24, color: Color(0xFF2E4A6B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Serene – ${widget.conditionLabel}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E4A6B),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.settings, color: Color(0xFF2E4A6B), size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const ConditionSelectionScreen()),
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(8.0),
                child: Icon(Icons.swap_horiz, size: 20, color: Color(0xFF7A8FA6)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 22),

        // ── Greeting ─────────────────────────────────────────
        Text(
          'Welcome, ${widget.userName}',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2B3C),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          trimester.isNotEmpty ? trimester : 'Week 20 • Halfway there!',
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF7A8FA6),
            fontWeight: FontWeight.w500,
          ),
        ),

        const SizedBox(height: 24),

        GestureDetector(
          onTap: () async {
            final controller = TextEditingController(text: _lastSugarValue?.toStringAsFixed(0));
            String tempContext = _sugarContext.isEmpty ? 'Fasting' : _sugarContext;
            
            await showDialog(
              context: context,
              builder: (context) => StatefulBuilder(
                builder: (context, setDialogState) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Adjust Blood Sugar'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: tempContext,
                        decoration: InputDecoration(
                          labelText: 'Context',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        items: ['Fasting', 'Post-meal'].map((String val) {
                          return DropdownMenuItem(value: val, child: Text(val));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => tempContext = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: 'Reading (mg/dL)',
                          hintText: 'e.g. 95',
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A6EA8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;
                        if (user == null) return;
                        
                        final val = double.tryParse(controller.text) ?? 0.0;
                        final now = DateTime.now();
                        final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                        
                        // Save to Firestore
                        await FirebaseFirestore.instance
                            .collection('logs')
                            .doc(user.uid)
                            .collection('daily_entries')
                            .doc("${dateStr}_QuickUpdate")
                            .set({
                              'bloodSugar': val,
                              'sugarContext': tempContext,
                              'timestamp': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                        if (mounted) {
                          setState(() {
                            _lastSugarValue = val;
                            _sugarContext = tempContext;
                          });
                        }
                        Navigator.pop(context);
                      },
                      child: const Text('Save', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'BLOOD SUGAR STATUS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3A6EA8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Icon(Icons.water_drop, color: Colors.blue[800], size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _lastSugarValue?.toStringAsFixed(0) ?? '--',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A2B3C),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'mg/dL',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF7A8FA6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _lastSugarValue != null ? Icons.check_circle : Icons.help_outline,
                      color: _lastSugarValue != null ? Colors.green : Colors.orange,
                      size: 16
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _lastSugarValue != null 
                        ? 'Last reading ($_sugarContext) • Tap to adjust'
                        : 'No recent readings • Tap to set',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF7A8FA6)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: Container(
                          height: 28,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3A6EA8), Color(0xFF6A9ED8)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 12),
                          child: const Text(
                            'Stable',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const Expanded(flex: 4, child: SizedBox()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Baby's Size Card ─────────────────────────────────
        Builder(
          builder: (context) {
            String babySize = 'Pear';
            String babyLength = '25–30 cm';
            String babyIcon = '🍐';

            if (trimester.contains('1st')) {
              babySize = 'Lemon';
              babyLength = '7–8 cm';
              babyIcon = '🍋';
            } else if (trimester.contains('2nd')) {
              babySize = 'Papaya';
              babyLength = '25–30 cm';
              babyIcon = '🥭';
            } else if (trimester.contains('3rd')) {
              babySize = 'Watermelon';
              babyLength = '45–50 cm';
              babyIcon = '🍉';
            }

            // Due Date & Progress Calculations (Permanently fixed null safety issues)
            final int currentWeek = _pregnancyWeek;
            final int week = currentWeek.clamp(1, 40);
            final int remainingWeeks = (40 - week).clamp(0, 40);
            final int remainingDays = remainingWeeks * 7;
            
            final DateTime dueDate = DateTime.now().add(Duration(days: remainingDays));
            final double progress = (week / 40.0).clamp(0.0, 1.0);
            final String formattedDueDate = DateFormat('dd MMMM yyyy').format(dueDate);

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F8FB),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4AC2CD),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            babyIcon,
                            style: const TextStyle(fontSize: 35),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Your Baby's Size",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A2B3C),
                              ),
                            ),
                            const SizedBox(height: 4),
                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF7A8FA6),
                                ),
                                children: [
                                  const TextSpan(text: 'Baby is as big as a '),
                                  TextSpan(
                                    text: babySize,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A2B3C),
                                    ),
                                  ),
                                  TextSpan(text: ' ($babyLength).'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 16),
                  
                  // Due Date Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Expected Due Date",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF3A6EA8),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedDueDate,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A2B3C),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "$remainingWeeks weeks left",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFB5616A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  
                  // Progress Bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Journey progress",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            "${(progress * 100).toInt()}% completed",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2E7D6B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: Colors.white,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4AC2CD)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // ── Weight & Activity Row ────────────────────────────
        Row(
          children: [
            Expanded(
              child: _smallCard(
                icon: Icons.monitor_weight,
                iconColor: Colors.brown,
                label: 'WEIGHT',
                value: _localWeight != null ? '${_localWeight!.toStringAsFixed(1)} kg' : 'Add weight',
                subValue: _localWeight != null ? '+0.2kg this week' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _smallCard(
                icon: Icons.directions_run,
                iconColor: Colors.teal,
                label: 'ACTIVITY',
                value: '4,280 steps',
                showProgress: true,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ── Medicine Reminder Card ──────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_active, color: Color(0xFFB5616A), size: 24),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NEXT MEDICINE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7A8FA6),
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Folic Acid • After Lunch',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2B3C),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MedicineScheduleScreen()),
                  );
                },
                child: const Text('View All'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Hydration Card ───────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DAILY HYDRATION',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3A6EA8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_waterLiters.toStringAsFixed(1)}L / ${_waterGoal.toStringAsFixed(1)}L',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A2B3C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _waterLiters >= _waterGoal 
                        ? 'Goal Reached! 🌟' 
                        : '${(_waterGoal - _waterLiters).toStringAsFixed(1)}L remaining',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF7A8FA6)),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final controller = TextEditingController();
                      await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('Add Water (Liters)'),
                          content: TextField(
                            controller: controller,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'e.g. 0.5',
                              suffixText: 'L',
                              filled: true,
                              fillColor: Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A6EA8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                              onPressed: () async {
                                final val = double.tryParse(controller.text) ?? 0.0;
                                setState(() {
                                  _waterLiters += val;
                                });
                                final prefs = await SharedPreferences.getInstance();
                                prefs.setDouble('water_liters_${DateTime.now().toIso8601String().split('T')[0]}', _waterLiters);
                                Navigator.pop(context);
                              },
                              child: const Text('Add', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F0F8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_circle_outline, color: Color(0xFF3A6EA8), size: 28),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 60,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (_waterLiters / _waterGoal).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A6EA8),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Insight card ──────────────────────────────────────

        const SizedBox(height: 24),

        // ── Quick Actions ─────────────────────────────────────
        const Text(
          'QUICK ACTIONS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7A8FA6),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              _quickAction(
                icon: Icons.medical_services_outlined,
                label: 'Med\nSchedule',
                color: const Color(0xFF3A6EA8),
                bgColor: const Color(0xFFE8F0F8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MedicineScheduleScreen()),
                  );
                },
              ),
              const SizedBox(width: 16),
              _quickAction(
                icon: Icons.chat_bubble_outline,
                label: 'AI Chat',
                color: const Color(0xFFB5616A),
                bgColor: const Color(0xFFFFECEC),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ChatbotScreen()),
                  );
                },
              ),
              const SizedBox(width: 16),
              _quickAction(
                icon: Icons.restaurant_menu,
                label: 'Meal Plan',
                color: const Color(0xFF2E7D6B),
                bgColor: const Color(0xFFE0F4F0),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DietPlannerScreen()),
                  );
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF3D5166),
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? subValue,
    bool showProgress = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF7A8FA6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2B3C),
            ),
          ),
          if (subValue != null) ...[
            const SizedBox(height: 4),
            Text(
              subValue,
              style: const TextStyle(fontSize: 11, color: Color(0xFF7A8FA6)),
            ),
          ],
          if (showProgress) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: 0.6,
                backgroundColor: Colors.grey[100],
                color: Colors.teal,
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
