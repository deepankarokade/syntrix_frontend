import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/notification_service.dart';

class MedicineScheduleScreen extends StatefulWidget {
  const MedicineScheduleScreen({super.key});

  @override
  State<MedicineScheduleScreen> createState() => _MedicineScheduleScreenState();
}

class _MedicineScheduleScreenState extends State<MedicineScheduleScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lunchTimeController = TextEditingController();
  String _selectedFrequency = 'Once a day';
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isLoading = true;
  List<Map<String, dynamic>> _medicines = [];

  @override
  void initState() {
    super.initState();
    NotificationService().init();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data['lunchTime'] != null) {
          _lunchTimeController.text = data['lunchTime'];
        }
      }

      final meds = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('medicines')
          .get();
      
      setState(() {
        _medicines = meds.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching meds: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addMedicine() async {
    if (_nameController.text.isEmpty) return;

    final newMed = {
      'name': _nameController.text,
      'frequency': _selectedFrequency,
      'reminderTime': '${_reminderTime.hour}:${_reminderTime.minute}',
      'createdAt': FieldValue.serverTimestamp(),
      'takenToday': false,
    };

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('medicines')
        .add(newMed);

    // Schedule notification
    final now = DateTime.now();
    final scheduledDate = DateTime(now.year, now.month, now.day, _reminderTime.hour, _reminderTime.minute);
    
    // Use a hash of name as id for now
    NotificationService().scheduleNotification(
      _nameController.text.hashCode,
      'Medicine Reminder',
      'It is time to take your ${_nameController.text}',
      scheduledDate,
    );

    _nameController.clear();
    _fetchData();
    Navigator.pop(context);
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Medicine',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Medicine Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                prefixIcon: const Icon(Icons.medication),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Frequency', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: ['Once a day', 'Twice a day', 'After Meals'].map((f) {
                bool isSelected = _selectedFrequency == f;
                return ChoiceChip(
                  label: Text(f),
                  selected: isSelected,
                  onSelected: (val) => setState(() => _selectedFrequency = f),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reminder Time', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_reminderTime.format(context)),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                final time = await showTimePicker(context: context, initialTime: _reminderTime);
                if (time != null) setState(() => _reminderTime = time);
              },
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E4A6B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _addMedicine,
                child: const Text('Save Schedule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Medicine Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF1A2B3C),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildLunchTimeCard(),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('DAILY MEDICINES', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF7A8FA6), letterSpacing: 1.5, fontSize: 12)),
                  IconButton(onPressed: _showAddDialog, icon: const Icon(Icons.add_circle, color: Color(0xFF3A6EA8))),
                ],
              ),
              const SizedBox(height: 16),
              if (_medicines.isEmpty) 
                const Center(child: Text('No medicines scheduled yet.'))
              else
                ..._medicines.map((m) => _buildMedCard(m)),
            ],
          ),
    );
  }

  Widget _buildLunchTimeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              const Text('SET LUNCH TIME', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A2B3C))),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Reminders for "After Lunch" meds depend on this.', style: TextStyle(fontSize: 12, color: Color(0xFF7A8FA6))),
          const SizedBox(height: 16),
          TextField(
            controller: _lunchTimeController,
            readOnly: true,
            onTap: () async {
              final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
              if (time != null) {
                final timeStr = time.format(context);
                setState(() => _lunchTimeController.text = timeStr);
                await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({'lunchTime': timeStr});
              }
            },
            decoration: InputDecoration(
              hintText: 'e.g. 1:30 PM',
              suffixIcon: const Icon(Icons.edit, size: 18),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedCard(Map<String, dynamic> m) {
    bool taken = m['takenToday'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: taken ? const Color(0xFFF1F5F9) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: taken ? Colors.transparent : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: taken ? Colors.grey[200] : const Color(0xFFECF4FF),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.medication, color: taken ? Colors.grey : const Color(0xFF3A6EA8)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, decoration: taken ? TextDecoration.lineThrough : null)),
                Text('${m['frequency']} • Reminder: ${m['reminderTime']}', style: const TextStyle(fontSize: 12, color: Color(0xFF7A8FA6))),
              ],
            ),
          ),
          Checkbox(
            value: taken,
            onChanged: (val) async {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('medicines')
                  .doc(m['id'])
                  .update({'takenToday': val});
              _fetchData();
              if (val == true) {
                _showSuccessSnackBar(m['name']);
              }
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Great! You took your $name.'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
