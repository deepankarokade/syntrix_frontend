import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../onboarding/condition_selection_screen.dart';
import '../../services/cloudinary_service.dart';
import '../../services/email_service.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _dobController = TextEditingController();
  DateTime? _selectedDob;
  
  // Weight Selection State
  double _currentWeight = 60.0;
  final double _minWeight = 30.0;
  final double _maxWeight = 150.0;
  late ScrollController _weightScrollController;
  final double _tickSpacing = 12.0; // 8 width + 2*2 margin
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50, // Optimize for profile pics
    );
    if (picked != null) {
      setState(() => _imageFile = picked);
    }
  }

  @override
  void initState() {
    super.initState();
    _weightController.text = _currentWeight.toInt().toString();
    _weightScrollController = ScrollController();
    
    // Schedule initial scroll after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToWeight(_currentWeight);
    });
  }

  void _scrollToWeight(double weight) {
    if (!_weightScrollController.hasClients) return;
    double offset = (weight - _minWeight) * _tickSpacing;
    _weightScrollController.jumpTo(offset);
  }

  void _updateWeightFromScroll(double offset) {
    double weight = _minWeight + (offset / _tickSpacing);
    if (weight < _minWeight) weight = _minWeight;
    if (weight > _maxWeight) weight = _maxWeight;
    
    setState(() {
      _currentWeight = weight;
      _weightController.text = weight.toInt().toString();
    });
  }


  @override
  void dispose() {
    _weightScrollController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  void _showNotification(String message, {bool isError = false}) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 300),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(50 * (1 - value), 0),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isError
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF2D7A7B),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isError ? Icons.error_outline : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }

  Future<void> _signUp() async {
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty ||
        _heightController.text.isEmpty ||
        _weightController.text.isEmpty ||
        _dobController.text.isEmpty) {
      _showNotification('Please fill in all fields', isError: true);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showNotification('Passwords do not match', isError: true);
      return;
    }

    if (_passwordController.text.length < 8) {
      _showNotification(
        'Password must be at least 8 characters long',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

    print('Starting signup...');

    try {
      // Create user with Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      print('User created: ${userCredential.user?.uid}');

      // 1. Update display name
      await userCredential.user?.updateDisplayName(_nameController.text.trim());
      print('Display name updated');

      // 2. Send welcome email (fire-and-forget — won't block signup)
      EmailService.sendWelcomeEmail(
        toName: _nameController.text.trim(),
        toEmail: _emailController.text.trim(),
      );

      // 3. Save user data to Firestore
      final user = userCredential.user;
      if (user != null) {
        String? photoUrl;

        // Upload profile picture if picked
        if (_imageFile != null) {
          final bytes = await _imageFile!.readAsBytes();
          photoUrl = await CloudinaryService.uploadFile(
            bytes,
            'profile_${user.uid}.${_imageFile!.path.split('.').last}',
          );
        }

        print('Signup: Saving to Firestore for UID: ${user.uid}');
        try {
          // Background sync to avoid blocking the UI on slow internet
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'name': _nameController.text.trim(),
                'email': user.email,
                'photoUrl': photoUrl,
                'height': double.tryParse(_heightController.text) ?? 0,
                'weight': double.tryParse(_weightController.text) ?? 0,
                'dob': _selectedDob != null
                    ? Timestamp.fromDate(_selectedDob!)
                    : null,
                'createdAt': FieldValue.serverTimestamp(),
                'onboardingCompleted': false,
              })
              .then((_) => print('Signup: Background save for UID finished'))
              .catchError((e) => print('Signup: Background error: $e'));

          // Update Auth photoURL too
          if (photoUrl != null) {
            await user.updatePhotoURL(photoUrl);
          }

          print('Signup: Firestore save triggered in background');
        } catch (e) {
          print('Signup: Initial trigger error: $e');
        }
      }

      // 3. Finally, navigate
      if (mounted) {
        print('Signup: Navigating to ConditionSelectionScreen');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ConditionSelectionScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: ${e.code} - ${e.message}');
      String message = 'An error occurred';
      if (e.code == 'weak-password') {
        message = 'The password is too weak';
      } else if (e.code == 'email-already-in-use') {
        message = 'Email already exists';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address';
      }
      if (mounted) {
        _showNotification(message, isError: true);
      }
    } on FirebaseException catch (e) {
      print('FirebaseException (Firestore): ${e.code} - ${e.message}');
      if (mounted) {
        _showNotification('Failed to save user data', isError: true);
      }
    } catch (e) {
      print('Unexpected error during signup: $e');
      if (mounted) {
        _showNotification(
          'An unexpected error occurred: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        print('Loading state set to false');
      }
    }
  }

  /// Helper – builds a single pill-shaped text field
  Widget _buildField({
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    bool readOnly = false,
    VoidCallback? onToggleObscure,
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E4A6B).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        readOnly: readOnly,
        onTap: onTap,
        style: const TextStyle(color: Color(0xFF1A2B3C), fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 15),
          prefixIcon: Icon(icon, color: const Color(0xFF7A8FA6), size: 20),
          suffixIcon: onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: const Color(0xFFB0BEC5),
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Gradient background ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFEAEFF4),
                  Color(0xFFD6E4EC),
                  Color(0xFFC8D8E5),
                ],
              ),
            ),
          ),

          // ── Soft pink orb accent (top-right) ─────────────────────────
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFB5C2).withValues(alpha: 0.45),
                    const Color(0xFFFFB5C2).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 36),

                  // ── Profile Photo Selection ───────────────────────────
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            image: _imageFile != null
                                ? DecorationImage(
                                    image: FileImage(File(_imageFile!.path)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2E4A6B).withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: _imageFile == null
                              ? const Icon(
                                  Icons.person_add_alt_1_rounded,
                                  color: Color(0xFF2E4A6B),
                                  size: 40,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFB5616A),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Sakhi logo row ─────────────────────────────────────
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/logo/logo.png',
                          width: 36,
                          height: 36,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Sakhi',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E4A6B),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Title + subtitle ───────────────────────────────────
                  const Center(
                    child: Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A2B3C),
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Start your hormonal health journey',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF7A8FA6),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Full Name ──────────────────────────────────────────
                  const Text(
                    'Full Name',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3D5166),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _nameController,
                    icon: Icons.person_outline,
                    hint: 'Elena Gilbert',
                  ),

                  const SizedBox(height: 18),

                  // ── Date of Birth ──────────────────────────────────────
                  const Text(
                    'Date of Birth',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3D5166),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _dobController,
                    icon: Icons.calendar_today_outlined,
                    hint: 'DD/MM/YYYY',
                    readOnly: true,
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime(2000),
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDob = picked;
                          _dobController.text =
                              "${picked.day}/${picked.month}/${picked.year}";
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 18),

                  // ── Height and Weight Card ──────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Height (cm)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3D5166),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildField(
                              controller: _heightController,
                              icon: Icons.height_outlined,
                              hint: '165',
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ── Weight Selection Card ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
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
                        const Text(
                          "What is your weight?",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A2B3C),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Weight Display
                        Text(
                          "${_currentWeight.toInt()} kg",
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB5616A),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Ruler Scale
                        SizedBox(
                          height: 80,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  NotificationListener<ScrollNotification>(
                                    onNotification: (notification) {
                                      if (notification is ScrollUpdateNotification) {
                                        _updateWeightFromScroll(
                                            notification.metrics.pixels);
                                      }
                                      return true;
                                    },
                                    child: ListView.builder(
                                      controller: _weightScrollController,
                                      scrollDirection: Axis.horizontal,
                                      itemCount: (_maxWeight - _minWeight).toInt() + 1,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: constraints.maxWidth / 2 - (_tickSpacing / 2),
                                      ),
                                      itemBuilder: (context, index) {
                                        int weightValue = (_minWeight + index).toInt();
                                        bool isMajor = weightValue % 5 == 0;
                                        
                                        return Container(
                                          width: _tickSpacing,
                                          alignment: Alignment.bottomCenter,
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              if (isMajor)
                                                Padding(
                                                  padding: const EdgeInsets.only(bottom: 8.0),
                                                  child: Text(
                                                    "$weightValue",
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF7A8FA6),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              Container(
                                                width: 3,
                                                height: isMajor ? 35 : 18,
                                                decoration: BoxDecoration(
                                                  color: isMajor 
                                                      ? const Color(0xFF3D5166) 
                                                      : const Color(0xFFB0BEC5).withValues(alpha: 0.5),
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  // Center Indicator
                                  IgnorePointer(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          width: 3,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFB5616A),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Email ──────────────────────────────────────────────
                  const Text(
                    'Email',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3D5166),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _emailController,
                    icon: Icons.email_outlined,
                    hint: 'hello@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 18),

                  // ── Password ───────────────────────────────────────────
                  const Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3D5166),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _passwordController,
                    icon: Icons.lock_outline,
                    hint: '••••••••',
                    obscure: _obscurePassword,
                    onToggleObscure: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),

                  const SizedBox(height: 18),

                  // ── Confirm Password ───────────────────────────────────
                  const Text(
                    'Confirm Password',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3D5166),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildField(
                    controller: _confirmPasswordController,
                    icon: Icons.shield_outlined,
                    hint: '••••••••',
                    obscure: _obscureConfirmPassword,
                    onToggleObscure: () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Sign Up button ─────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB5616A), Color(0xFFC47A82)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFB5616A,
                            ).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Sign Up',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Terms text ─────────────────────────────────────────
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9EAEBF),
                          height: 1.6,
                        ),
                        children: [
                          TextSpan(
                            text:
                                "By creating an account, you agree to Sakhi's\n",
                          ),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: Color(0xFF7A8FA6),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: Color(0xFF7A8FA6),
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          TextSpan(text: '.'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Log In link ────────────────────────────────────────
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: Color(0xFF7A8FA6),
                            fontSize: 14,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Log In',
                            style: TextStyle(
                              color: Color(0xFFB5616A),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
