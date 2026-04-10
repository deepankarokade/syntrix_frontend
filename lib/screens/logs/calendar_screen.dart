import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:convert';
import 'log_entry_screen.dart';
<<<<<<< HEAD
import '../report/reports_screen.dart';
=======
import '../../services/ai_service.dart';
>>>>>>> c17f6bc22157ef04b53aefab6a65c568a69c6146

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  final user = FirebaseAuth.instance.currentUser;
  Map<String, Map<String, dynamic>> _logs = {};
  Map<String, dynamic> _dayDetails = {};
  DateTime? _predictedNextPeriodDate;
  bool _loading = true;
  bool _loadingDetails = false;
  int _selectedTab = 0; // 0 = Logs, 1 = Reports
  List<Map<String, dynamic>> _reportsList = [];
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _fetchMonthLogs();
    _fetchDayDetails(_selectedDate);
  }

  Future<void> _fetchDayDetails(DateTime date) async {
    if (user == null) return;
    setState(() {
      _selectedDate = date;
      _loadingDetails = true;
      _dayDetails = {};
    });

    try {
      String dateStr = DateFormat('yyyy-MM-dd').format(date);
      // ... existing code ...
      final entriesCol = FirebaseFirestore.instance
          .collection('logs')
          .doc(user!.uid)
          .collection('daily_entries');

      final morning = await entriesCol.doc("${dateStr}_Morning").get();
      final afternoon = await entriesCol.doc("${dateStr}_Afternoon").get();
      final night = await entriesCol.doc("${dateStr}_Night").get();

      // Fetch reports for this day too
      final reportsSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('reports')
          .where('date', isEqualTo: dateStr)
          .get();

      if (mounted) {
        setState(() {
          if (morning.exists) _dayDetails['Morning'] = morning.data();
          if (afternoon.exists) _dayDetails['Afternoon'] = afternoon.data();
          if (night.exists) _dayDetails['Night'] = night.data();
          _reportsList = reportsSnap.docs
              .map((d) => {'_docId': d.id, ...d.data()})
              .toList();
          _loadingDetails = false;
        });
      }
    } catch (e) {
      print("Error fetching day details: $e");
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  Future<void> _fetchMonthLogs() async {
    if (user == null) return;
    setState(() => _loading = true);

    try {
      final entriesCol = FirebaseFirestore.instance
          .collection('logs')
          .doc(user!.uid)
          .collection('daily_entries');

      final snapshot = await entriesCol.get();
      Map<String, Map<String, dynamic>> fetchedLogs = {};
      DateTime? lastPeriodDate;
      List<DateTime> periodDates = [];

      for (var doc in snapshot.docs) {
        String dateStr = doc.id.split('_').first;
        var data = doc.data();
        if (fetchedLogs[dateStr] == null ||
            data['periodPhase'] == 'Menstrual') {
          fetchedLogs[dateStr] = data;
        }

        if (data['isOnPeriod'] == true || data['periodPhase'] == 'Menstrual') {
          DateTime logDate = DateTime.parse(dateStr);
          periodDates.add(logDate);
          if (lastPeriodDate == null || logDate.isAfter(lastPeriodDate)) {
            lastPeriodDate = logDate;
          }
        }
      }

      DateTime? predictedDate;
      if (lastPeriodDate != null) {
        predictedDate = lastPeriodDate.add(const Duration(days: 28));
      }

      if (mounted) {
        setState(() {
          _logs = fetchedLogs;
          _predictedNextPeriodDate = predictedDate;
          _loading = false;
        });
      }

      // Add AI prediction for calendar
      if (periodDates.isNotEmpty) {
        periodDates.sort();
        List<String> startDates = [];
        DateTime? lastStart;
        for (var d in periodDates) {
          if (lastStart == null || d.difference(lastStart).inDays > 10) {
            startDates.add("\${d.year}-\${d.month.toString().padLeft(2, '0')}-\${d.day.toString().padLeft(2, '0')}");
            lastStart = d;
          }
        }

        final now = DateTime.now();
        String todayStr = "\${now.year}-\${now.month.toString().padLeft(2, '0')}-\${now.day.toString().padLeft(2, '0')}";

        String aiPrompt = '''
You are a Medical AI calculating the menstrual cycle.
Past period start dates: \${startDates.join(', ')}
Today's date: \$todayStr

Please analyze these dates, predict the next cycle start date based on patterns.
Respond ONLY with a valid JSON matching exactly this structure, no markdown, no extra text:
{
  "predictedNextPeriodDate": "<YYYY-MM-DD>"
}
''';
        try {
          final aiResponse = await AiService.sendMessage(
            messages: [{"role": "user", "content": aiPrompt}],
          );
          if (aiResponse != null && mounted) {
            String cleanJSON = aiResponse.replaceAll('```json', '').replaceAll('```', '').trim();
            Map<String, dynamic> aiData = jsonDecode(cleanJSON);
            DateTime aiNextDate = DateTime.parse(aiData['predictedNextPeriodDate']);
            setState(() {
              _predictedNextPeriodDate = aiNextDate;
            });
          }
        } catch(e) {
          print("AI calendar prediction error: \$e");
        }
      }
    } catch (e) {
      print("Error fetching month logs: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _nextMonth() {
    // Only allow future months if requested, but "upto today" might apply to selection
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
    _fetchMonthLogs();
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _fetchMonthLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Stack(
        children: [
          SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_rounded,
                        color: Color(0xFF1E5BB1),
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    'Log Period',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E5BB1),
                    ),
                  ),
                ],
              ),
            ),

            // ── Month Selector ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_left,
                      color: Color(0xFF1E5BB1),
                    ),
                    onPressed: _prevMonth,
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(_currentMonth),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E5BB1),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF1E5BB1),
                    ),
                    onPressed: _nextMonth,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Calendar Card ──────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: _loading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(40),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : Column(
                              children: [
                                _buildDaysOfWeek(),
                                const SizedBox(height: 20),
                                _buildCalendarGrid(),
                                const SizedBox(height: 32),
                                // Legend
                                _buildLegend(),
                              ],
                            ),
                    ),
                    const SizedBox(height: 32),

                    // ── Day Details Section ──────────────────────────
                    _buildDayDetailsHeader(),
                    const SizedBox(height: 16),
                    // ── Tab Switcher: Logs | Reports ─────────────────
                    _buildTabSwitcher(),
                    const SizedBox(height: 16),
                    if (_selectedTab == 0)
                      // LOGS TAB
                      (_loadingDetails
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _dayDetails.isEmpty
                          ? _buildEmptyState('No logs for this day',
                              Icons.event_note_rounded)
                          : Column(
                              children: _dayDetails.entries
                                  .map((e) => _buildLogCard(e.key, e.value))
                                  .toList(),
                            ))
                    else
                      // REPORTS TAB
                      _buildReportsTab(),
                    const SizedBox(height: 40),
                  ],
                ),
              ), // SingleChildScrollView
            ), // Expanded
          ], // Outer Column children
        ), // Outer Column
      ), // SafeArea
      if (_isDownloading)
        Container(
          color: Colors.black.withOpacity(0.3),
          child: const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Opening Report...',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ),
    ], // Stack children
  ), // Stack
);
  }

  Future<void> _downloadAndOpenFile(String url, String fileName) async {
    if (url.isEmpty) return;

    setState(() => _isDownloading = true);

    try {
      // 1. Get Temporary Directory
      final tempDir = await getTemporaryDirectory();
      final filePath = "${tempDir.path}/$fileName";

      // 2. Download the file
      final response = await http.get(Uri.parse(url));
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      // 3. Open the file
      final result = await OpenFilex.open(filePath);

      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file: ${result.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download report')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }



  Widget _buildDaysOfWeek() {
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days
          .map(
            (day) => Text(
              day,
              style: const TextStyle(
                color: Color(0xFFA0B1C5),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    final daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    final firstWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0

    List<Widget> dayWidgets = [];

    // Empty spaces for previous month
    for (int i = 0; i < firstWeekday; i++) {
      dayWidgets.add(const SizedBox());
    }

    // Actual days
    for (int i = 1; i <= daysInMonth; i++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, i);
      final dateStr =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final log = _logs[dateStr];
      final isToday =
          date.day == now.day &&
          date.month == now.month &&
          date.year == now.year;
      final isSelected =
          date.day == _selectedDate.day &&
          date.month == _selectedDate.month &&
          date.year == _selectedDate.year;
      final isFuture = date.isAfter(now);
      final hasPeriod = log != null && log['isOnPeriod'] == true;
      final hasLogs = log != null;

      bool isPredictedPeriod = false;
      if (_predictedNextPeriodDate != null) {
        int diff = date.difference(_predictedNextPeriodDate!).inDays;
        // Ignore time constraints or exactly match the days spanning logic
        if (diff >= 0 && diff < 5) {
          isPredictedPeriod = true;
        }
      }

      dayWidgets.add(
        GestureDetector(
          onTap: isFuture ? null : () => _fetchDayDetails(date),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(4),
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1E5BB1)
                    : (hasPeriod
                          ? const Color(0xFFFFC6C6)
                          : (isPredictedPeriod
                                ? const Color(0xFFFFE5E5)
                                : (hasLogs
                                      ? const Color(0xFFECF4FF)
                                      : Colors.transparent))),
                shape: BoxShape.circle,
                border: isToday && !isSelected
                    ? Border.all(color: const Color(0xFF1E5BB1), width: 1.5)
                    : null,
              ),
              child: Text(
                i.toString(),
                style: TextStyle(
                  color: isFuture
                      ? const Color(0xFFDEE5EE)
                      : (isSelected
                            ? Colors.white
                            : (hasPeriod
                                  ? const Color(0xFFB5616A)
                                  : (isPredictedPeriod
                                        ? const Color(0xFFD98A95)
                                        : const Color(0xFF1A1F26)))),
                  fontWeight: (isSelected || isToday || hasPeriod || isPredictedPeriod)
                      ? FontWeight.bold
                      : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          children: dayWidgets,
        );
      },
    );
  }

  Widget _buildLegend() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem(const Color(0xFFFFC6C6), 'Period'),
          const SizedBox(width: 16),
          _legendItem(const Color(0xFFFFE5E5), 'Predicted'),
          const SizedBox(width: 16),
          _legendItem(const Color(0xFFECF4FF), 'Recorded'),
          const SizedBox(width: 16),
          _legendItem(const Color(0xFFFFFFFF), 'Normal', border: true),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label, {bool border = false}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: border ? Border.all(color: const Color(0xFFDEE5EE)) : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF7A8FA6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildDayDetailsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          DateFormat('EEEE, d MMMM').format(_selectedDate),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A2B3C),
          ),
        ),
        if (_dayDetails.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFECF4FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "${_dayDetails.length} Logs",
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1E5BB1),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFECF4FF),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(child: _tabOption('Logs', 0, Icons.event_note_rounded)),
          Expanded(
              child: _tabOption('Reports', 1, Icons.description_outlined)),
        ],
      ),
    );
  }

  Widget _tabOption(String label, int index, IconData icon) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: isSelected
                    ? const Color(0xFF1E5BB1)
                    : const Color(0xFF7A8FA6)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF1E5BB1)
                    : const Color(0xFF7A8FA6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    if (_reportsList.isEmpty) {
      return _buildEmptyState(
          'No reports for this day', Icons.description_outlined);
    }
    return Column(
      children: _reportsList.map((report) => _buildReportCard(report)).toList(),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final docId = report['_docId'] as String?;
    final title = report['reportName'] ?? 'Health Report';
    final metrics = report['metrics'] as Map<String, dynamic>? ?? {};
    final urls = report['reportUrls'] as List<dynamic>? ?? [];
    final date = report['date'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header with Edit button ───────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECF4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.health_and_safety_outlined,
                  color: Color(0xFF2E4A6B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2B3C),
                      ),
                    ),
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7A8FA6),
                        ),
                      ),
                  ],
                ),
              ),
              // Edit button
              if (docId != null)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportsScreen(
                          existingData: report,
                          reportDocId: docId,
                        ),
                      ),
                    ).then((_) => _fetchDayDetails(_selectedDate));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: Color(0xFF2E4A6B),
                    ),
                  ),
                ),
            ],
          ),

          if (metrics.isNotEmpty) ...[
            const Divider(height: 24, thickness: 0.5),

            // ── Basic ────────────────────────────────────────
            if (metrics['age'] != null || metrics['bmi'] != null)
              _reportSection('BASIC', [
                if (metrics['age'] != null)
                  _reportChip('Age', '${metrics['age']} yrs'),
                if (metrics['bmi'] != null)
                  _reportChip('BMI', '${metrics['bmi']}'),
              ]),


            // ── Blood & Hormones ─────────────────────────────
            () {
              final hormoneEntries = <Widget>[];
              for (final kv in {
                'rbs': 'RBS mg/dL',
                'tsh': 'TSH mIU/L',
                'hb': 'Hb g/dL',
                'whr': 'WHR',
                'lh': 'LH mIU/mL',
                'fsh': 'FSH mIU/mL',
                'amh': 'AMH ng/mL',
                'prl': 'PRL ng/mL',
                'prg': 'PRG ng/mL',
              }.entries) {
                if (metrics[kv.key] != null) {
                  hormoneEntries
                      .add(_reportChip(kv.value, '${metrics[kv.key]}'));
                }
              }
              if (hormoneEntries.isEmpty) return const SizedBox.shrink();
              return _reportSection('BLOOD & HORMONES', hormoneEntries);
            }(),

          ],

          // ── Attached Files ──────────────────────────────────
          if (urls.isNotEmpty) ...[
            const Divider(height: 24, thickness: 0.5),
            const Text(
              'ATTACHED FILES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7A8FA6),
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 10),
            ...urls.map((url) {
              final uri = url.toString();
              final fileName = uri.split('/').last.split('?').first;
              final ext = fileName.split('.').last.toUpperCase();
              final isImage = ['JPG', 'JPEG', 'PNG'].contains(ext);
              return GestureDetector(
                onTap: () {
                  if (isImage) {
                    _showImageViewer(uri, fileName);
                  } else {
                    _downloadAndOpenFile(uri, fileName);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isImage
                            ? Icons.image_outlined
                            : Icons.picture_as_pdf_outlined,
                        size: 18,
                        color: isImage
                            ? const Color(0xFF3A6EA8)
                            : const Color(0xFFB5616A),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A2B3C),
                          ),
                        ),
                      ),
                      Icon(
                        isImage
                            ? Icons.zoom_in_rounded
                            : Icons.open_in_new_rounded,
                        size: 14,
                        color: const Color(0xFF7A8FA6),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// Shows a full-screen image viewer dialog for uploaded images.
  void _showImageViewer(String url, String title) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Title bar ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Image ──
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: double.infinity,
                    height: 300,
                    color: const Color(0xFF1A2B3C),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: const Color(0xFF1A2B3C),
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportSection(String title, List<Widget> chips) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7A8FA6),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }

  Widget _reportChip(String label, String value, {bool positive = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: positive
            ? const Color(0xFFE8F5EE)
            : const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF7A8FA6),
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: positive
                    ? const Color(0xFF2E7D6B)
                    : const Color(0xFF1A2B3C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState([
    String message = 'No logs for this day',
    IconData icon = Icons.event_note_rounded,
  ]) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(icon,
              size: 48, color: const Color(0xFFDEE5EE).withOpacity(0.8)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF7A8FA6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(String timeSlot, Map<String, dynamic> data) {
    // Determine prominent color based on period
    bool isOnPeriod = data['isOnPeriod'] == true;
    Color accentColor = isOnPeriod
        ? const Color(0xFFB5616A)
        : const Color(0xFF1E5BB1);
    Color lightAccent = isOnPeriod
        ? const Color(0xFFFFECEC)
        : const Color(0xFFECF4FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: lightAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      timeSlot == 'Morning'
                          ? Icons.wb_sunny_rounded
                          : (timeSlot == 'Afternoon'
                                ? Icons.wb_cloudy_rounded
                                : Icons.nights_stay_rounded),
                      size: 16,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    timeSlot,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A2B3C),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LogEntryScreen(
                            editDate: _selectedDate,
                            editSlot: timeSlot,
                            existingData: data,
                          ),
                        ),
                      );
                    },
                    child: Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: const Color(0xFF1E5BB1).withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              if (isOnPeriod)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC6C6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Period",
                    style: TextStyle(
                      color: Color(0xFFB5616A),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const Divider(height: 24, thickness: 0.5),

          // Metrics Grid
          Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              if (data['mood'] != null)
                _metricItem(Icons.face_rounded, "Mood", data['mood']),
              if (data['weight'] != null)
                _metricItem(
                  Icons.monitor_weight_rounded,
                  "Weight",
                  "${data['weight']} kg",
                ),
              if (data['bloodSugar'] != null)
                _metricItem(
                  Icons.opacity_rounded,
                  "Sugar",
                  "${data['bloodSugar']} mg/dL",
                ),
              if (data['sleep'] != null)
                _metricItem(Icons.bedtime_rounded, "Sleep", data['sleep']),
              if (data['activity'] != null)
                _metricItem(
                  Icons.fitness_center_rounded,
                  "Activity",
                  data['activity'],
                ),
              if (isOnPeriod && data['periodDay'] != null)
                _metricItem(
                  Icons.calendar_today_rounded,
                  "Day",
                  data['periodDay'],
                ),
            ],
          ),

          if (data['symptoms'] != null &&
              (data['symptoms'] as Map).isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              "Symptoms",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A8FA6),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (data['symptoms'] as Map).entries
                  .map((e) => _symptomTag(e.key, e.value))
                  .toList(),
            ),
          ],

          if (data['medication'] != null &&
              data['medication'].toString().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.medication_rounded,
                    size: 14,
                    color: Color(0xFF5A7EA0),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Meds: ${data['medication']}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5A7EA0),
                        fontWeight: FontWeight.w500,
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

  Widget _metricItem(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF7A8FA6)),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF7A8FA6)),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1F26),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _symptomTag(String label, String severity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F6FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "$label ($severity)",
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF2E4A6B),
        ),
      ),
    );
  }
}
