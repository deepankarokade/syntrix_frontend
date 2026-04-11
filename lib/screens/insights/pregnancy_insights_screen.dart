import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../services/ai_service.dart';
import '../../services/pregnancy_log_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class PregnancyInsightsScreen extends StatefulWidget {
  final int pregnancyWeek;
  const PregnancyInsightsScreen({super.key, this.pregnancyWeek = 24});

  @override
  State<PregnancyInsightsScreen> createState() =>
      _PregnancyInsightsScreenState();
}

class _PregnancyInsightsScreenState extends State<PregnancyInsightsScreen>
    with SingleTickerProviderStateMixin {
  int _currentWeek = 24;
  String _trimester = '2nd Trimester';
  DateTime? _dueDate;
  int _remainingDays = 0;
  int _remainingWeeks = 0;

  String? _aiInsight;
  bool _isLoadingAi = false;
  bool _isLoadingInfo = true;

  late TabController _tabController;

  // Lifestyle summary data
  Map<String, int> _lifestyleSummary = {};
  int _totalLogsCount = 0;

  @override
  void initState() {
    super.initState();
    _currentWeek = widget.pregnancyWeek;
    _tabController = TabController(length: 2, vsync: this);
    _loadPregnancyInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPregnancyInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _isLoadingInfo = false);
      return;
    }

    try {
      // Load from SharedPreferences as fallback
      final prefs = await SharedPreferences.getInstance();
      int? savedWeek = prefs.getInt("pregnancyWeek");

      // Try to get detailed pregnancy info
      final info = await PregnancyLogService.getPregnancyInfo(uid);

      // Load lifestyle logs summary
      final logs = await PregnancyLogService.getRecentLogs(uid, days: 14);
      _totalLogsCount = logs.length;

      // Calculate lifestyle summary
      _calculateLifestyleSummary(logs);

      if (mounted) {
        setState(() {
          _currentWeek = info['currentWeek'] ?? savedWeek ?? _currentWeek;
          _trimester = info['trimester'] ?? _trimester;
          _dueDate = info['dueDate'];
          _remainingDays = info['remainingDays'] ?? 0;
          _remainingWeeks = info['remainingWeeks'] ?? 0;
          _isLoadingInfo = false;
        });
      }
    } catch (e) {
      print('PregnancyInsights: Error loading info: $e');
      if (mounted) setState(() => _isLoadingInfo = false);
    }
  }

  void _calculateLifestyleSummary(List<Map<String, dynamic>> logs) {
    int skippedMeals = 0;
    int junkFood = 0;
    int lowWater = 0;
    int missedVitamins = 0;
    int poorSleep = 0;
    int goodDays = 0;
    int exerciseDays = 0;

    for (final log in logs) {
      final answers = log['answers'] as Map<String, dynamic>? ?? {};
      final slot = log['timeSlot'] ?? '';

      if (slot == 'morning') {
        if (answers['breakfast'] == false) skippedMeals++;
        if (answers['prenatalVitamin'] == false) missedVitamins++;
        if (answers['morningExercise'] != null &&
            answers['morningExercise'] != 'None') {
          exerciseDays++;
        }
        if (answers['morningMood'] == '😊 Great') goodDays++;
      }
      if (slot == 'afternoon') {
        if (answers['lunch'] == false) skippedMeals++;
      }
      if (slot == 'night') {
        if (answers['junkFood'] == true) junkFood++;
        if (answers['totalWater'] == 'Less than 4 glasses') lowWater++;
        if (answers['sleepQuality'] == 'Poor' ||
            answers['sleepQuality'] == 'Fair') {
          poorSleep++;
        }
      }
    }

    _lifestyleSummary = {
      'skippedMeals': skippedMeals,
      'junkFood': junkFood,
      'lowWater': lowWater,
      'missedVitamins': missedVitamins,
      'poorSleep': poorSleep,
      'goodDays': goodDays,
      'exerciseDays': exerciseDays,
    };
  }

  Future<void> _fetchAiInsights() async {
    setState(() => _isLoadingAi = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not logged in');

      // Get general health context
      String contextStr = await AiService.getGroundingContext();

      // Get pregnancy lifestyle context
      String pregnancyContext =
          await PregnancyLogService.buildPregnancyAIContext(uid);

      String prompt =
          """
You are an EXPERT prenatal healthcare AI assistant. Analyze the following comprehensive pregnancy data and provide detailed clinical insights.

PREGNANCY STATUS:
- Current Week: $_currentWeek
- Trimester: $_trimester
- Estimated Due Date: ${_dueDate != null ? DateFormat('MMMM dd, yyyy').format(_dueDate!) : 'Not calculated'}
- Remaining Days: $_remainingDays days ($_remainingWeeks weeks)

GENERAL HEALTH DATA:
$contextStr

DETAILED PREGNANCY LIFESTYLE LOGS:
$pregnancyContext

PROVIDE THE FOLLOWING IN YOUR RESPONSE (use Markdown formatting):

## 📅 Due Date & Progress
- Exact due date calculation
- Current gestational age details
- Key milestones for week $_currentWeek

## 🚨 Lifestyle Warnings
- Critically analyze the lifestyle logs
- Flag any DANGEROUS patterns (skipped meals, junk food, no vitamins, poor sleep, dehydration, caffeine)
- Rate overall lifestyle as: EXCELLENT / GOOD / NEEDS IMPROVEMENT / CONCERNING
- Explain WHY certain habits are harmful for the baby

## 💡 Personalized Recommendations
- Specific changes to make based on the log data
- Week-specific advice for week $_currentWeek
- Exercise recommendations safe for current trimester
- Stress management tips based on reported stress levels

## 🍽️ Nutrition Alert
- Based on food logs, identify nutritional gaps
- Suggest specific foods to add
- Highlight any foods to AVOID based on what she's eating

## 👶 Baby Development
- What's happening with baby at week $_currentWeek
- Size comparison
- Key development milestones this week

Be direct, specific, and use the ACTUAL log data — don't be generic. If she's eating junk food, CALL IT OUT. If she's missing vitamins, WARN HER.
""";

      String? result = await AiService.sendMessage(
        messages: [
          {"role": "user", "content": prompt},
        ],
        isDiet: true,
      );

      if (mounted && result != null) {
        setState(() => _aiInsight = result);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _aiInsight =
              "Failed to load AI pregnancy analysis. Please try again.",
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingAi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingInfo) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Theme.of(context).primaryColor),
            const SizedBox(height: 16),
            Text(
              'Loading pregnancy data...',
              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
            ),
          ],
        ),
      ),
    );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 280,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).primaryColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(background: _buildHeroHeader()),
            title: innerBoxIsScrolled
                ? Text(
                    'Week $_currentWeek • $_trimester',
                    style: const TextStyle(fontSize: 14, color: Colors.white),
                  )
                : null,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
            ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).primaryColor,
                  ),
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: '📊 Overview'),
                    Tab(text: '🤖 AI Analysis'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [_buildOverviewTab(), _buildAIAnalysisTab()],
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    double progress = _currentWeek / 40.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Theme.of(context).colorScheme.secondary, Theme.of(context).primaryColor],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 50, 24, 70),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Text('🤰', style: TextStyle(fontSize: 30)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Week $_currentWeek',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _trimester,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Progress bar
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pregnancy Progress',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${(progress * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF4AC2CD),
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_dueDate != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.event, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Due: ${DateFormat('MMM dd, yyyy').format(_dueDate!)} • $_remainingDays days left',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Due Date Card
          _buildDueDateCard(),
          const SizedBox(height: 16),

          // Lifestyle Score Cards
          _buildLifestyleScoreCards(),
          const SizedBox(height: 20),

          // Lifestyle Summary
          Text(
            'LIFESTYLE SUMMARY (14 DAYS)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).textTheme.bodySmall?.color,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          _buildLifestyleGrid(),
          const SizedBox(height: 20),

          // Week-specific Info
          _buildWeekInfoCard(),
          const SizedBox(height: 20),

          // Quick Tips
          _buildQuickTipsCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildDueDateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.secondary,
            Theme.of(context).primaryColor,
          ],
        ),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESTIMATED DUE DATE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _dueDate != null
                        ? DateFormat('MMMM dd, yyyy').format(_dueDate!)
                        : 'Not yet calculated',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text('📅', style: TextStyle(fontSize: 28)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _countdownTile('$_remainingWeeks', 'Weeks\nLeft'),
              const SizedBox(width: 12),
              _countdownTile('$_remainingDays', 'Days\nLeft'),
              const SizedBox(width: 12),
              _countdownTile(
                '${(40 - _currentWeek).clamp(0, 40)}',
                'Weeks\nTo Go',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _countdownTile(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLifestyleScoreCards() {
    int score = 100;
    int meals = _lifestyleSummary['skippedMeals'] ?? 0;
    int junk = _lifestyleSummary['junkFood'] ?? 0;
    int water = _lifestyleSummary['lowWater'] ?? 0;
    int vitamins = _lifestyleSummary['missedVitamins'] ?? 0;
    int sleep = _lifestyleSummary['poorSleep'] ?? 0;

    score -= meals * 5;
    score -= junk * 8;
    score -= water * 7;
    score -= vitamins * 6;
    score -= sleep * 5;
    score = score.clamp(0, 100);

    String rating = 'EXCELLENT';
    Color ratingColor = Theme.of(context).primaryColor;
    if (score < 40) {
      rating = 'CONCERNING';
      ratingColor = Theme.of(context).colorScheme.error;
    } else if (score < 60) {
      rating = 'NEEDS WORK';
      ratingColor = Colors.orange; // Keeping orange as a semantic warning unless directed otherwise, but using Theme error for Concerning
    } else if (score < 80) {
      rating = 'GOOD';
      ratingColor = Theme.of(context).colorScheme.secondary;
    }

    if (_totalLogsCount == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).primaryColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Start logging your daily lifestyle to see your health score and get personalized AI insights!',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          // Score circle
          SizedBox(
            width: 90,
            height: 90,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    value: score / 100.0,
                    strokeWidth: 8,
                    backgroundColor: const Color(0xFFF4F6FA),
                    valueColor: AlwaysStoppedAnimation<Color>(ratingColor),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: ratingColor,
                      ),
                    ),
                    Text(
                      'SCORE',
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).textTheme.bodySmall?.color, // Will replace this in a moment
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ratingColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    rating,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: ratingColor,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lifestyle Health Score',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Based on $_totalLogsCount lifestyle logs over 14 days',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLifestyleGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: [
        _metricCard(
          '🥗',
          'Meals Skipped',
          '${_lifestyleSummary['skippedMeals'] ?? 0}',
          (_lifestyleSummary['skippedMeals'] ?? 0) > 3
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).primaryColor,
        ),
        _metricCard(
          '🍔',
          'Junk Food Days',
          '${_lifestyleSummary['junkFood'] ?? 0}',
          (_lifestyleSummary['junkFood'] ?? 0) > 2
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).primaryColor,
        ),
        _metricCard(
          '💧',
          'Low Water Days',
          '${_lifestyleSummary['lowWater'] ?? 0}',
          (_lifestyleSummary['lowWater'] ?? 0) > 3
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).primaryColor,
        ),
        _metricCard(
          '💊',
          'Missed Vitamins',
          '${_lifestyleSummary['missedVitamins'] ?? 0}',
          (_lifestyleSummary['missedVitamins'] ?? 0) > 3
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).primaryColor,
        ),
        _metricCard(
          '😴',
          'Poor Sleep Days',
          '${_lifestyleSummary['poorSleep'] ?? 0}',
          (_lifestyleSummary['poorSleep'] ?? 0) > 3
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).primaryColor,
        ),
        _metricCard(
          '🧘',
          'Exercise Days',
          '${_lifestyleSummary['exerciseDays'] ?? 0}',
          (_lifestyleSummary['exerciseDays'] ?? 0) >= 3
              ? Theme.of(context).primaryColor
              : Colors.orange,
        ),
      ],
    );
  }

  Widget _metricCard(
    String emoji,
    String label,
    String value,
    Color valueColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: valueColor,
                ),
              ),
            ],
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekInfoCard() {
    String babySize = _getBabySizeForWeek(_currentWeek);
    String development = _getBabyDevelopmentForWeek(_currentWeek);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
          const Text(
            'WEEK SNAPSHOT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3A6EA8),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    _getBabyEmojiForWeek(_currentWeek),
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Baby is the size of a $babySize',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      development,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTipsCard() {
    List<Map<String, String>> tips = _getTipsForWeek(_currentWeek);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK TIPS FOR THIS WEEK',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).textTheme.bodySmall?.color,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        ...tips.map(
          (tip) => Container(
            margin: const EdgeInsets.only(bottom: 10),
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
            child: Row(
              children: [
                Text(tip['icon']!, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip['title']!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tip['desc']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAIAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Generate button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.secondary,
                  Theme.of(context).primaryColor
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                const SizedBox(height: 12),
                const Text(
                  'AI Pregnancy Analysis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Analyzes your lifestyle logs, predicts risks, and gives personalized recommendations',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoadingAi ? null : _fetchAiInsights,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoadingAi
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _aiInsight != null
                                ? '🔄 Regenerate Analysis'
                                : '✨ Generate AI Analysis',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // AI Response
          if (_aiInsight != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF3A6EA8).withValues(alpha: 0.15),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: MarkdownBody(
                data: _aiInsight!,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                    height: 1.6,
                  ),
                  h1: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                  h2: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                  h3: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                  listBullet: TextStyle(color: Theme.of(context).primaryColor),
                  strong: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),

          if (_aiInsight == null && !_isLoadingAi)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap "Generate AI Analysis" to get personalized pregnancy insights based on your lifestyle logs, due date analysis, and health recommendations.',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── Helper data methods ──

  String _getBabySizeForWeek(int week) {
    if (week <= 4) return 'Poppy Seed';
    if (week <= 6) return 'Sweet Pea';
    if (week <= 8) return 'Raspberry';
    if (week <= 10) return 'Prune';
    if (week <= 12) return 'Lime';
    if (week <= 14) return 'Lemon';
    if (week <= 16) return 'Avocado';
    if (week <= 18) return 'Bell Pepper';
    if (week <= 20) return 'Banana';
    if (week <= 22) return 'Papaya';
    if (week <= 24) return 'Corn on the Cob';
    if (week <= 26) return 'Lettuce';
    if (week <= 28) return 'Eggplant';
    if (week <= 30) return 'Coconut';
    if (week <= 32) return 'Squash';
    if (week <= 34) return 'Pineapple';
    if (week <= 36) return 'Honeydew Melon';
    if (week <= 38) return 'Pumpkin';
    return 'Watermelon';
  }

  String _getBabyEmojiForWeek(int week) {
    if (week <= 8) return '🫐';
    if (week <= 12) return '🍋';
    if (week <= 16) return '🥑';
    if (week <= 20) return '🍌';
    if (week <= 24) return '🌽';
    if (week <= 28) return '🍆';
    if (week <= 32) return '🥥';
    if (week <= 36) return '🍈';
    return '🍉';
  }

  String _getBabyDevelopmentForWeek(int week) {
    if (week <= 8) {
      return 'Vital organs are forming. Heart begins to beat.';
    }
    if (week <= 12) {
      return 'Fingers and toes are formed. Baby starts moving.';
    }
    if (week <= 16) {
      return 'Baby can make facial expressions. Bones hardening.';
    }
    if (week <= 20) {
      return 'You may start feeling kicks! Baby develops hearing.';
    }
    if (week <= 24) {
      return 'Baby responds to sounds. Lungs developing rapidly.';
    }
    if (week <= 28) {
      return 'Eyes can open. Baby practices breathing movements.';
    }
    if (week <= 32) {
      return 'Baby gains weight rapidly. Brain developing fast.';
    }
    if (week <= 36) {
      return 'Baby is preparing for birth. Head may engage in pelvis.';
    }
    return 'Baby is full term! Ready to meet you any day now!';
  }

  List<Map<String, String>> _getTipsForWeek(int week) {
    List<Map<String, String>> tips = [
      {
        'icon': '💧',
        'title': 'Stay Hydrated',
        'desc': 'Drink 8-10 glasses of water daily',
      },
      {
        'icon': '💊',
        'title': 'Prenatal Vitamins',
        'desc': 'Take folic acid and iron supplements daily',
      },
    ];

    if (week <= 12) {
      tips.addAll([
        {
          'icon': '🤢',
          'title': 'Morning Sickness',
          'desc': 'Eat small, frequent meals. Ginger tea helps!',
        },
        {
          'icon': '😴',
          'title': 'Rest Well',
          'desc': 'Your body needs extra rest in the first trimester',
        },
      ]);
    } else if (week <= 26) {
      tips.addAll([
        {
          'icon': '🏃',
          'title': 'Stay Active',
          'desc': 'Light walking and yoga are great for 2nd trimester',
        },
        {
          'icon': '🥛',
          'title': 'Calcium Rich Food',
          'desc': "Baby's bones are forming—eat dairy, leafy greens",
        },
      ]);
    } else {
      tips.addAll([
        {
          'icon': '👶',
          'title': 'Count Baby Kicks',
          'desc': 'Feel for 10 movements in 2 hours after meals',
        },
        {
          'icon': '🛏️',
          'title': 'Sleep on Side',
          'desc': 'Left side sleeping improves blood flow to baby',
        },
      ]);
    }
    return tips;
  }
}
