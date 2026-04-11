import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/pregnancy_log_service.dart';
import 'pregnancy_log_screen.dart';

class PregnancyHistoryScreen extends StatefulWidget {
  const PregnancyHistoryScreen({super.key});

  @override
  State<PregnancyHistoryScreen> createState() => _PregnancyHistoryScreenState();
}

class _PregnancyHistoryScreenState extends State<PregnancyHistoryScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Set<String> _loggedDates = {};
  String? _selectedDayInsight;
  bool _isLoadingInsight = false;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _fetchHistoryData();
    _fetchInsightForDay(_selectedDay!);
  }

  Future<void> _fetchHistoryData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final dates = await PregnancyLogService.getAllLoggedDates(uid);
      if (mounted) {
        setState(() {
          _loggedDates = dates;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      print('HistoryScreen: Error fetching history: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _fetchInsightForDay(DateTime date) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoadingInsight = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final insight = await PregnancyLogService.getPregnancyInsight(uid, dateStr);
      if (mounted) {
        setState(() {
          _selectedDayInsight = insight;
        });
      }
    } catch (e) {
      print('HistoryScreen: Error fetching insight: $e');
    } finally {
      if (mounted) setState(() => _isLoadingInsight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text(
          'Lifestyle History',
          style: TextStyle(color: Color(0xFF2E4A6B), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2E4A6B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingHistory
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3A6EA8)))
          : Column(
              children: [
                _buildCalendarCard(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildDetailsSection(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCalendarCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now(),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          if (!isSameDay(_selectedDay, selectedDay)) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            _fetchInsightForDay(selectedDay);
          }
        },
        onFormatChanged: (format) {
          setState(() => _calendarFormat = format);
        },
        eventLoader: (day) {
          final dateStr = DateFormat('yyyy-MM-dd').format(day);
          return _loggedDates.contains(dateStr) ? ['logged'] : [];
        },
        calendarStyle: CalendarStyle(
          markerDecoration: const BoxDecoration(
            color: Color(0xFF3A6EA8),
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: const Color(0xFF3A6EA8).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(color: Color(0xFF3A6EA8), fontWeight: FontWeight.bold),
          selectedDecoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF3A6EA8), Color(0xFF2E4A6B)]),
            shape: BoxShape.circle,
          ),
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2E4A6B)),
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay!);
    final hasLogs = _loggedDates.contains(dateStr);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMMM dd, yyyy').format(_selectedDay!),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A2B3C),
              ),
            ),
            if (hasLogs)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F4F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'LOGGED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E7D6B),
                    letterSpacing: 1,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        
        // Edit Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PregnancyLogScreen(editDate: _selectedDay),
                ),
              );
              _fetchHistoryData(); // Refresh calendar dots
            },
            icon: Icon(hasLogs ? Icons.edit_rounded : Icons.add_rounded, size: 20),
            label: Text(hasLogs ? 'Edit Lifestyle Logs' : 'Add Lifestyle Logs'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF3A6EA8),
              side: const BorderSide(color: Color(0xFF3A6EA8), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Insight Section
        const Text(
          'AI INSIGHT FOR THIS DAY',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF7A8FA6),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        _isLoadingInsight
            ? const Center(child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(color: Color(0xFF3A6EA8)),
              ))
            : _selectedDayInsight != null
                ? Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.blue.withOpacity(0.1)),
                    ),
                    child: MarkdownBody(
                      data: _selectedDayInsight!,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF2E4A6B)),
                        h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2B3C)),
                      ),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.grey, size: 40),
                        SizedBox(height: 12),
                        Text(
                          'No AI analysis found for this date.\nLogs from this day contribute to your overall health analysis.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF7A8FA6), fontSize: 13, height: 1.4),
                        ),
                      ],
                    ),
                  ),
        const SizedBox(height: 40),
      ],
    );
  }
}
