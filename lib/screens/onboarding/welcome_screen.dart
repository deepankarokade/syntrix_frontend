import 'package:flutter/material.dart';
import '../../widgets/auth_wrapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _startSplashSequence();
  }

  Future<void> _startSplashSequence() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenWelcome', true);
    
    // Removed auto-navigate timer since we added an interactive button
  }

  void _navigateToAuth() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const AuthWrapper(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: null, // Disabled screen tap since we have a button now
        child: Stack(
          children: [
            // Background Gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE4EEF5), // Light blue-grey top
                    Color(0xFFF1F5F8), // Center very light blue
                    Color(0xFFFBF1F3), // Very subtle pinkish bottom-right
                  ],
                ),
              ),
            ),

            // Main Content
            SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Central Logo
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFDCE6ED).withOpacity(0.7),
                      ),
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/images/logo/logo.png',
                        width: 170,
                        height: 170,
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Title
                    const Text(
                      'Sakhi',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF131517),
                        letterSpacing: -1.5,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Subtitle
                    const Text(
                      'Your Smart Hormonal Health\nCompanion',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        color: Color(0xFF5E6D7E),
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Get Started Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFB5616A), // dusty rose left
                                Color(0xFFC47A82), // lighter mauve right
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB5616A).withOpacity(0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _navigateToAuth,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Get Started',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Bottom "DIGITAL SANCTUARY"
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: const Color(0xFFC7D3DE),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'DIGITAL SANCTUARY',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF7A8D9F),
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 1,
                              color: const Color(0xFFC7D3DE),
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
      ),
    );
  }
}

// Custom Painter to draw the exact 3-leaf logo seen in the design
class ThreeLeavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF3F6A8F)
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0;

    // Draw center leaf pointing up
    final Path centerLeaf = Path();
    centerLeaf.moveTo(size.width * 0.5, size.height * 0.1);
    centerLeaf.quadraticBezierTo(size.width * 0.7, size.height * 0.45, size.width * 0.5, size.height * 0.7);
    centerLeaf.quadraticBezierTo(size.width * 0.3, size.height * 0.45, size.width * 0.5, size.height * 0.1);
    centerLeaf.close();

    // Draw left leaf pointing outward
    final Path leftLeaf = Path();
    leftLeaf.moveTo(size.width * 0.1, size.height * 0.45);
    leftLeaf.quadraticBezierTo(size.width * 0.45, size.height * 0.45, size.width * 0.48, size.height * 0.85);
    leftLeaf.quadraticBezierTo(size.width * 0.25, size.height * 0.85, size.width * 0.1, size.height * 0.45);
    leftLeaf.close();

    // Draw right leaf pointing outward
    final Path rightLeaf = Path();
    rightLeaf.moveTo(size.width * 0.9, size.height * 0.45);
    rightLeaf.quadraticBezierTo(size.width * 0.55, size.height * 0.45, size.width * 0.52, size.height * 0.85);
    rightLeaf.quadraticBezierTo(size.width * 0.75, size.height * 0.85, size.width * 0.9, size.height * 0.45);
    rightLeaf.close();

    // Draw stems / cutouts? In the image, there is a small gap separating them.
    // The natural drawing will overlap or be adjacent depending on bezier points.
    
    // We add a tiny gap by making the shapes slightly smaller than their boundaries natively
    
    Path combinedPath = Path.combine(PathOperation.union, centerLeaf, leftLeaf);
    combinedPath = Path.combine(PathOperation.union, combinedPath, rightLeaf);

    canvas.drawPath(combinedPath, paint);
    
    // Draw the tiny white gaps/lines slicing them to match the logo
    final Path cutoutPath = Path();
    cutoutPath.moveTo(size.width * 0.48, size.height * 0.4);
    cutoutPath.lineTo(size.width * 0.5, size.height * 0.9);
    cutoutPath.lineTo(size.width * 0.52, size.height * 0.4);
    
    final cutoutPaint = Paint()
      ..color = Colors.transparent
      ..blendMode = BlendMode.clear
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
      
    // I will actually just use the simple combined path, wait. The image has a transparent curved line separating the leaves.
    // Instead of cutting, let me refine the paths to have the gap naturally.
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
