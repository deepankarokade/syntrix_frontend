import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/user_session.dart';
import '../../services/ai_service.dart';
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
  String _userCondition = 'General healthy eating';
  String _userSymptoms = 'None';

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
        _userCondition = data['lifeStage'] ?? 'None';
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

    final contextData = await AiService.getGroundingContext();

    final messages = [
      {"role": "system", "content": AiService.dietSystemPrompt},
      {
        "role": "user",
        "content": "Grounded User Data:\n$contextData\n\n"
                  "Request: Generate a diet plan for region: $region. "
                  "Condition Context: $_userCondition. "
                  "Current Symptoms detected from logs: $_userSymptoms. "
                  "Strictly follow the medical grounding provided for this specific condition."
      },
    ];

    final response = await AiService.sendMessage(messages: messages, isDiet: true);

    // Save preferences and the plan for next time
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'region': region,
        'activeDietPlan': response,
      }, SetOptions(merge: true));
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _activePlan = response;
        _tabController.animateTo(1);
      });
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
          const SizedBox(height: 12),
          _infoTag('Detected Condition: ${_userCondition.toUpperCase()}'),
          _infoTag('Current Symptoms: $_userSymptoms'),
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
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No active plan. Generate one first!', style: TextStyle(color: Color(0xFF7A8FA6))),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('YOUR TAILORED DIET', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFD68A3D), letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: MarkdownBody(
              data: _activePlan!,
              styleSheet: MarkdownStyleSheet(
                h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A2B3C)),
                h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3A6EA8)),
                p: const TextStyle(fontSize: 15, color: Color(0xFF3D5166), height: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 32),
          TextButton.icon(
            onPressed: () => _tabController.animateTo(0),
            icon: const Icon(Icons.refresh),
            label: const Text('Update Plan'),
          ),
        ],
      ),
    );
  }
}
