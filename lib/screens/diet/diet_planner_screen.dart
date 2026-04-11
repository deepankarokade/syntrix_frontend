import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/ai_service.dart';
import '../../services/pregnancy_log_service.dart';
import '../../services/health_data_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DietPlannerScreen extends StatefulWidget {
  const DietPlannerScreen({super.key});

  @override
  State<DietPlannerScreen> createState() => _DietPlannerScreenState();
}

class _DietPlannerScreenState extends State<DietPlannerScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _regionController = TextEditingController();
  
  bool _isLoading = false;
  bool _fetchingProfile = true;
  String? _activePlan;
  String _userCondition = 'pcos'; // Default to something common if not loaded
  String _userSymptoms = 'None';
  final List<String> _conditions = ['pcos', 'pregnant', 'menopause', 'none'];

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _fetchingProfile = false);
      return;
    }

    try {
      // 1. Fetch condition from profile
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        final rawStage = data['lifeStage'] as String?;
        print("Diet: Loaded lifeStage from Firebase: '$rawStage'");
        _userCondition = rawStage?.toLowerCase() ?? 'none';
        if (!_conditions.contains(_userCondition)) _userCondition = 'none';
        print("Diet: Using condition: $_userCondition");
        if (data['region'] != null) _regionController.text = data['region'];
        _activePlan = data['activeDietPlan'];
        if (_activePlan != null) {
          _tabController.index = 1;
        }
      }

      // 2. Fetch symptoms from latest log
      final logs = await FirebaseFirestore.instance
          .collection('logs')
          .doc(user.uid)
          .collection('daily_entries')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      
      if (logs.docs.isNotEmpty && mounted) {
        final logData = logs.docs.first.data();
        // Extract symptoms if present
        if (logData['symptoms'] != null) {
          if (logData['symptoms'] is Map) {
            final symMap = logData['symptoms'] as Map;
            _userSymptoms = symMap.keys.where((k) => symMap[k] != 'None').join(', ');
          } else if (logData['symptoms'] is String) {
            _userSymptoms = logData['symptoms'];
          }
        }
      }
    } catch (e) {
      print("Error loading profile for diet: $e");
    } finally {
      if (mounted) setState(() => _fetchingProfile = false);
    }
  }

  Future<void> _generateDietPlan() async {
    final region = _regionController.text.trim();
    if (region.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your region for localized food recommendations.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print("Diet: Starting generation for condition=$_userCondition, region=$region");
      final contextData = await AiService.getGroundingContext();
      print("Diet: Got grounding context (${contextData.length} chars)");

      String systemPrompt = AiService.dietSystemPrompt;
      String extraContext = '';

      // Use pregnancy-specific diet prompt if pregnant
      if (_userCondition == 'pregnant') {
        systemPrompt = AiService.pregnancyDietSystemPrompt;
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            final pregInfo = await PregnancyLogService.getPregnancyInfo(user.uid);
            final pregContext = await PregnancyLogService.buildPregnancyAIContext(user.uid);
            extraContext = '''

PREGNANCY STATUS:
- Current Week: ${pregInfo['currentWeek']}
- Trimester: ${pregInfo['trimester']}
- Remaining Weeks: ${pregInfo['remainingWeeks']}

PREGNANCY LIFESTYLE LOGS:
$pregContext''';
          } catch (e) {
            print('Diet: Error fetching pregnancy info: $e');
          }
        }
      } else if (_userCondition == 'pcos' || _userCondition == 'pcod' || _userCondition == 'general') {
        try {
          final healthService = HealthDataService();
          final pcosResult = await healthService.fetchAndPredictRisk();
          if (pcosResult != null) {
            extraContext = '''
\nPCOS/PCOD RISK ASSESSMENT:
- Risk Percentage: ${pcosResult.riskPercentage}%
- Category: ${pcosResult.category}
- Contributing Factors: ${pcosResult.topFeatures.map((f) => f.key).join(', ')}
''';
          }
        } catch (e) {
          print('Diet: Error fetching PCOS risk: $e');
        }
      }

      final messages = [
        {"role": "system", "content": systemPrompt},
        {
          "role": "user",
          "content": "Grounded User Data:\n$contextData\n\n"
                    "$extraContext\n\n"
                    "Selected Goal/Condition: $_userCondition. "
                    "Requested Region: $region. "
                    "Current Symptoms detected from logs: $_userSymptoms. "
                    "Strictly generate the plan for the SELECTED CONDITION: $_userCondition."
        },
      ];

      print("Diet: Sending request to AI...");
      final response = await AiService.sendMessage(messages: messages, isDiet: true);
      print("Diet: Got response: ${response != null ? '${response.length} chars' : 'NULL'}");

      if (response == null || response.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate diet plan. Please try again.'), backgroundColor: Colors.red),
          );
        }
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // Save preferences and the plan for next time
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'region': region,
          'lifeStage': _userCondition,
          'activeDietPlan': response,
          'dietPlanTimestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print("Diet: Saved to Firestore");
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _activePlan = response;
          _tabController.animateTo(1);
        });
      }
    } catch (e) {
      print("Diet: ERROR - $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('AI Diet Planner', style: TextStyle(color: Color(0xFF2E4A6B), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF3A6EA8),
          unselectedLabelColor: const Color(0xFF7A8FA6),
          indicatorColor: const Color(0xFF3A6EA8),
          tabs: const [
            Tab(text: 'Planner'),
            Tab(text: 'My Active Plan'),
          ],
        ),
      ),
      body: _fetchingProfile 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPlannerForm(),
                _buildActivePlanView(),
              ],
            ),
    );
  }

  Widget _buildPlannerForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tell us your location',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A2B3C)),
          ),
          const SizedBox(height: 8),
          const Text(
            "We'll fetch your current health condition and symptoms automatically to create the best plan for you.",
            style: TextStyle(fontSize: 15, color: Color(0xFF7A8FA6), height: 1.4),
          ),
          const SizedBox(height: 32),
          _buildTextField('Region (e.g. South India, Europe)', _regionController),
          const SizedBox(height: 20),
          const Text('Your Current Health Goal/Condition', 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2E4A6B))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _userCondition,
                isExpanded: true,
                items: _conditions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() => _userCondition = newValue);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          _infoTag('Current Symptoms (from logs): $_userSymptoms'),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _isLoading ? null : _generateDietPlan,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A6EA8),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Generate Meal Plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _infoTag(String text) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF7A8FA6), fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF3A6EA8), width: 2)),
      ),
    );
  }

  Widget _buildActivePlanView() {
    if (_activePlan == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[200]),
            const SizedBox(height: 16),
            const Text('No active plan found', style: TextStyle(color: Color(0xFF7A8FA6), fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _tabController.animateTo(0),
              child: const Text('Generate Now'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ACTIVE DIET STRATEGY', 
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF3A6EA8), letterSpacing: 1.5)),
                  Text('Personalized for $_userCondition', 
                    style: const TextStyle(fontSize: 14, color: Color(0xFF7A8FA6))),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.verified_user, color: Color(0xFF1976D2), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Using a card for the main content to make it look "premium"
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: MarkdownBody(
              data: _activePlan!,
              styleSheet: MarkdownStyleSheet(
                h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1A3B5D), height: 1.4),
                h2: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Color(0xFF3A6EA8), height: 1.6),
                p: const TextStyle(fontSize: 15, color: Color(0xFF4A5F75), height: 1.6),
                listBullet: const TextStyle(color: Color(0xFF3A6EA8)),
                tableBorder: TableBorder.all(color: Colors.grey.shade200, width: 1),
                tableHead: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A3B5D)),
                tableBody: const TextStyle(fontSize: 14, color: Color(0xFF4A5F75)),
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          Center(
            child: Column(
              children: [
                const Text('Plan needs update? Your health markers change daily.', 
                  style: TextStyle(fontSize: 13, color: Color(0xFF7A8FA6))),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _tabController.animateTo(0),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('REGNERATE DAILY PLAN'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3A6EA8),
                    side: const BorderSide(color: Color(0xFF3A6EA8)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
}
