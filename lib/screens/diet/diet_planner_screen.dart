import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../services/ai_service.dart';
import '../../services/user_session.dart';

class DietPlannerScreen extends StatefulWidget {
  const DietPlannerScreen({super.key});

  @override
  State<DietPlannerScreen> createState() => _DietPlannerScreenState();
}

class _DietPlannerScreenState extends State<DietPlannerScreen> {
  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _symptomsController = TextEditingController();
  String _activityLevel = 'Moderate';

  bool _isLoading = false;
  String? _dietPlanResponse;

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
      _dietPlanResponse = null;
    });

    final contextData = await AiService.getGroundingContext();

    final messages = [
      {"role": "system", "content": AiService.dietSystemPrompt},
      {
        "role": "user",
        "content": "Grounded User Data:\n$contextData\n\n"
                  "Request: Generate a diet plan for region: $region. "
                  "Target Activity Level: $_activityLevel. "
                  "Additional User Notes: ${_symptomsController.text.isEmpty ? 'None' : _symptomsController.text}. "
                  "Strictly follow the medical grounding provided above."
      },
    ];

    final response = await AiService.sendMessage(messages: messages, isDiet: true);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _dietPlanResponse = response;
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
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF2E4A6B)),
      ),
      body: _dietPlanResponse != null ? _buildResultView() : _buildFormView(),
    );
  }

  Widget _buildFormView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Personalized Diet Generation',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A2B3C)),
        ),
        const SizedBox(height: 8),
        Text(
          "We use your profile data (Condition: ${UserSession.condition ?? 'None'}) to tailor this plan.",
          style: const TextStyle(color: Color(0xFF7A8FA6), fontSize: 13),
        ),
        const SizedBox(height: 20),
        _buildTextField('Region/Location (e.g. South India, New York, Mediterranean)', _regionController),
        const SizedBox(height: 16),
        _buildTextField('Current Symptoms (Optional)', _symptomsController, maxLines: 3),
        const SizedBox(height: 16),
        const Text('Activity Level', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3D5166))),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _activityLevel,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          items: ['Low', 'Moderate', 'High'].map((String level) {
            return DropdownMenuItem<String>(
              value: level,
              child: Text(level),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _activityLevel = val);
          },
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _isLoading ? null : _generateDietPlan,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3A6EA8),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Generate Diet Plan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3D5166))),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildResultView() {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: MarkdownBody(
                  data: _dietPlanResponse!,
                  styleSheet: MarkdownStyleSheet(
                    h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A2B3C)),
                    h2: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3A6EA8)),
                    p: const TextStyle(fontSize: 15, color: Color(0xFF3D5166), height: 1.5),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: () => setState(() => _dietPlanResponse = null),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB5616A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Adjust Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}
