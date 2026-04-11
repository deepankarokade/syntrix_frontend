import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/notification_service.dart';

class MedicineManagementScreen extends StatefulWidget {
  const MedicineManagementScreen({super.key});

  @override
  State<MedicineManagementScreen> createState() => _MedicineManagementScreenState();
}

class _MedicineManagementScreenState extends State<MedicineManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _medicineNameCtrl = TextEditingController();
  final TextEditingController _dosageCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  // Meal times
  TimeOfDay _breakfastTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _lunchTime = const TimeOfDay(hour: 13, minute: 0);
  TimeOfDay _dinnerTime = const TimeOfDay(hour: 20, minute: 0);

  // Medicine timing
  String _selectedTiming = 'Morning'; // Morning, Afternoon, Night
  String _selectedMealRelation = 'After Food'; // Before Food, After Food
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMealTimes();
  }

  @override
  void dispose() {
    _medicineNameCtrl.dispose();
    _dosageCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMealTimes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('meal_times')
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          if (data['breakfast'] != null) {
            final parts = (data['breakfast'] as String).split(':');
            _breakfastTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
          if (data['lunch'] != null) {
            final parts = (data['lunch'] as String).split(':');
            _lunchTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
          if (data['dinner'] != null) {
            final parts = (data['dinner'] as String).split(':');
            _dinnerTime = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading meal times: $e');
    }
  }

  Future<void> _saveMealTimes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('settings')
          .doc('meal_times')
          .set({
        'breakfast': '${_breakfastTime.hour}:${_breakfastTime.minute}',
        'lunch': '${_lunchTime.hour}:${_lunchTime.minute}',
        'dinner': '${_dinnerTime.hour}:${_dinnerTime.minute}',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Meal times saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving meal times: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('medicines')
          .add({
        'name': _medicineNameCtrl.text.trim(),
        'dosage': _dosageCtrl.text.trim(),
        'timing': _selectedTiming,
        'mealRelation': _selectedMealRelation,
        'notes': _notesCtrl.text.trim(),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Schedule notification if it's "Before Food"
      if (_selectedMealRelation == 'Before Food') {
        await NotificationService().scheduleDailyMedicineReminders(
          medicineName: _medicineNameCtrl.text.trim(),
          dosage: _dosageCtrl.text.trim(),
          timing: _selectedTiming,
          mealRelation: _selectedMealRelation,
          mealTimes: {
            'breakfast': '${_breakfastTime.hour}:${_breakfastTime.minute}',
            'lunch': '${_lunchTime.hour}:${_lunchTime.minute}',
            'dinner': '${_dinnerTime.hour}:${_dinnerTime.minute}',
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedMealRelation == 'Before Food'
                  ? '✓ Medicine added! Daily reminder set 15 min before ${_selectedTiming.toLowerCase()}'
                  : '✓ Medicine added successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _medicineNameCtrl.clear();
        _dosageCtrl.clear();
        _notesCtrl.clear();
        setState(() {
          _selectedTiming = 'Morning';
          _selectedMealRelation = 'After Food';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding medicine: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMedicine(String docId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('medicines')
          .doc(docId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Medicine deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _editMedicine(String docId, Map<String, dynamic> currentData) async {
    final nameCtrl = TextEditingController(text: currentData['name']);
    final dosageCtrl = TextEditingController(text: currentData['dosage']);
    final notesCtrl = TextEditingController(text: currentData['notes'] ?? '');
    String selectedTiming = currentData['timing'] ?? 'Morning';
    String selectedMealRelation = currentData['mealRelation'] ?? 'After Food';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Medicine'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Medicine Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dosageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dosage',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'When to take?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7A8FA6),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['Morning', 'Afternoon', 'Night'].map((timing) {
                    final isSelected = selectedTiming == timing;
                    return ChoiceChip(
                      label: Text(timing),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() => selectedTiming = timing);
                      },
                      selectedColor: const Color(0xFF2E4A6B),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF7A8FA6),
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Relation to meal?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7A8FA6),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['Before Food', 'After Food'].map((relation) {
                    final isSelected = selectedMealRelation == relation;
                    return ChoiceChip(
                      label: Text(relation),
                      selected: isSelected,
                      onSelected: (selected) {
                        setDialogState(() => selectedMealRelation = relation);
                      },
                      selectedColor: const Color(0xFF2E4A6B),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF7A8FA6),
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || dosageCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in required fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .collection('medicines')
                      .doc(docId)
                      .update({
                    'name': nameCtrl.text.trim(),
                    'dosage': dosageCtrl.text.trim(),
                    'timing': selectedTiming,
                    'mealRelation': selectedMealRelation,
                    'notes': notesCtrl.text.trim(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  // Reschedule notification if it's "Before Food"
                  if (selectedMealRelation == 'Before Food') {
                    await NotificationService().scheduleDailyMedicineReminders(
                      medicineName: nameCtrl.text.trim(),
                      dosage: dosageCtrl.text.trim(),
                      timing: selectedTiming,
                      mealRelation: selectedMealRelation,
                      mealTimes: {
                        'breakfast': '${_breakfastTime.hour}:${_breakfastTime.minute}',
                        'lunch': '${_lunchTime.hour}:${_lunchTime.minute}',
                        'dinner': '${_dinnerTime.hour}:${_dinnerTime.minute}',
                      },
                    );
                  }

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✓ Medicine updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB5616A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    dosageCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _selectTime(BuildContext context, String mealType) async {
    TimeOfDay initialTime;
    switch (mealType) {
      case 'Breakfast':
        initialTime = _breakfastTime;
        break;
      case 'Lunch':
        initialTime = _lunchTime;
        break;
      case 'Dinner':
        initialTime = _dinnerTime;
        break;
      default:
        initialTime = const TimeOfDay(hour: 12, minute: 0);
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null && mounted) {
      setState(() {
        switch (mealType) {
          case 'Breakfast':
            _breakfastTime = picked;
            break;
          case 'Lunch':
            _lunchTime = picked;
            break;
          case 'Dinner':
            _dinnerTime = picked;
            break;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: const Text('Medicine Management'),
        elevation: 0,
      ),
      body: user == null
          ? const Center(child: Text('Please login to manage medicines'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meal Times Section
                  _buildSectionHeader('Meal Times', Icons.restaurant),
                  const SizedBox(height: 12),
                  _buildMealTimeCard(),
                  const SizedBox(height: 12),
                  
                  // Test Notification Button (only on mobile)
                  if (!kIsWeb)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await NotificationService().scheduleTestNotification();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Test notification scheduled in 10 seconds!'),
                                backgroundColor: Colors.blue,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.notifications_active),
                        label: const Text('Test Notification (10 sec)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2E4A6B),
                          side: const BorderSide(color: Color(0xFF2E4A6B)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Add Medicine Section
                  _buildSectionHeader('Add Medicine', Icons.add_circle),
                  const SizedBox(height: 12),
                  _buildAddMedicineForm(),
                  const SizedBox(height: 24),

                  // Medicine List Section
                  _buildSectionHeader('Your Medicines', Icons.medication),
                  const SizedBox(height: 12),
                  _buildMedicineList(user.uid),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2E4A6B), size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A2B3C),
          ),
        ),
      ],
    );
  }

  Widget _buildMealTimeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMealTimeRow('Breakfast', _breakfastTime, '🍳'),
          const Divider(height: 24),
          _buildMealTimeRow('Lunch', _lunchTime, '🍱'),
          const Divider(height: 24),
          _buildMealTimeRow('Dinner', _dinnerTime, '🍽️'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveMealTimes,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB5616A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Save Meal Times',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealTimeRow(String mealType, TimeOfDay time, String emoji) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            mealType,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A2B3C),
            ),
          ),
        ),
        InkWell(
          onTap: () => _selectTime(context, mealType),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2E4A6B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF2E4A6B).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Text(
                  time.format(context),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E4A6B),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.access_time,
                  size: 18,
                  color: Color(0xFF2E4A6B),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddMedicineForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Medicine Name
            TextFormField(
              controller: _medicineNameCtrl,
              decoration: InputDecoration(
                labelText: 'Medicine Name *',
                hintText: 'e.g., Folic Acid',
                prefixIcon: const Icon(Icons.medication, color: Color(0xFF2E4A6B)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2E4A6B), width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter medicine name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Dosage
            TextFormField(
              controller: _dosageCtrl,
              decoration: InputDecoration(
                labelText: 'Dosage *',
                hintText: 'e.g., 1 tablet, 5ml',
                prefixIcon: const Icon(Icons.local_pharmacy, color: Color(0xFF2E4A6B)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2E4A6B), width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter dosage';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Timing Selection
            const Text(
              'When to take?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A8FA6),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Morning', 'Afternoon', 'Night'].map((timing) {
                final isSelected = _selectedTiming == timing;
                return ChoiceChip(
                  label: Text(timing),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedTiming = timing);
                  },
                  selectedColor: const Color(0xFF2E4A6B),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF7A8FA6),
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Meal Relation Selection
            const Text(
              'Relation to meal?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A8FA6),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Before Food', 'After Food'].map((relation) {
                final isSelected = _selectedMealRelation == relation;
                return ChoiceChip(
                  label: Text(relation),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedMealRelation = relation);
                  },
                  selectedColor: const Color(0xFF2E4A6B),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF7A8FA6),
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Any special instructions...',
                prefixIcon: const Icon(Icons.note, color: Color(0xFF2E4A6B)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2E4A6B), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Add Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _addMedicine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB5616A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Add Medicine',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineList(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('medicines')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF2E4A6B)),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: const [
                Icon(
                  Icons.medication_outlined,
                  size: 64,
                  color: Color(0xFF7A8FA6),
                ),
                SizedBox(height: 16),
                Text(
                  'No medicines added yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF7A8FA6),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Add your first medicine above',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7A8FA6),
                  ),
                ),
              ],
            ),
          );
        }

        // Sort documents by createdAt in memory
        final docs = snapshot.data!.docs;
        docs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); // Descending order
        });

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return _buildMedicineCard(
              docId: doc.id,
              data: data,
              name: data['name'] ?? '',
              dosage: data['dosage'] ?? '',
              timing: data['timing'] ?? '',
              mealRelation: data['mealRelation'] ?? '',
              notes: data['notes'] ?? '',
            );
          },
        );
      },
    );
  }

  Widget _buildMedicineCard({
    required String docId,
    required Map<String, dynamic> data,
    required String name,
    required String dosage,
    required String timing,
    required String mealRelation,
    required String notes,
  }) {
    IconData timingIcon;
    Color timingColor;

    switch (timing) {
      case 'Morning':
        timingIcon = Icons.wb_sunny;
        timingColor = Colors.orange;
        break;
      case 'Afternoon':
        timingIcon = Icons.wb_sunny_outlined;
        timingColor = Colors.amber;
        break;
      case 'Night':
        timingIcon = Icons.nightlight_round;
        timingColor = Colors.indigo;
        break;
      default:
        timingIcon = Icons.access_time;
        timingColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E4A6B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.medication,
                  color: Color(0xFF2E4A6B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2B3C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dosage,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7A8FA6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _editMedicine(docId, data),
                icon: const Icon(Icons.edit_outlined, color: Color(0xFF2E4A6B)),
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: () => _deleteMedicine(docId),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(
                icon: timingIcon,
                label: timing,
                color: timingColor,
              ),
              const SizedBox(width: 8),
              _buildInfoChip(
                icon: Icons.restaurant,
                label: mealRelation,
                color: Colors.teal,
              ),
            ],
          ),
          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F9F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.note,
                    size: 16,
                    color: Color(0xFF7A8FA6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notes,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7A8FA6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
