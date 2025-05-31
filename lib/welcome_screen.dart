import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get device dimensions for responsiveness
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      body: Container(
        width: screenWidth,
        height: screenHeight,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: const Color(0xFF010101),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
        ),
        child: Stack(
          children: [
            // Wave-like background pattern
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      Color(0xFF010101), // Dark base
                      Color(0xFF1A1A1A), // Slightly lighter for wave effect
                    ],
                  ),
                ),
              ),
            ),
            // Robot graphic
            Positioned(
              left: (screenWidth - 200) / 2, // Center for width 200
              top: screenHeight * 0.24, // Approx 200/844
              child: const Image(
                image: AssetImage('assets/robot.png'),
                width: 200,
                height: 200,
              ),
            ),
            // Personal AI Buddy badge
            Positioned(
              left: (screenWidth - 152) / 2, // Approx centered (text width + padding)
              top: screenHeight * 0.076, // 64/844
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: ShapeDecoration(
                  color: const Color(0xFFC6F432),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: const Text(
                  'Personal AI Buddy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF010101),
                    fontSize: 14,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            // Tagline
            Positioned(
              left: (screenWidth - 278) / 2, // Approx centered for text width
              top: screenHeight * 0.556, // 469/844
              child: const Text(
                'Speak. Capture. Understand.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xE5F7FF00),
                  fontSize: 20,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Welcome text
            Positioned(
              left: (screenWidth - 310) / 2, // Center for width 310
              top: screenHeight * 0.701, // 591/844
              child: const SizedBox(
                width: 310,
                height: 95,
                child: Text(
                  'Welcome to\nEchoType!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    height: 1.16,
                    letterSpacing: 1.60,
                  ),
                ),
              ),
            ),
            // Get Started button
            Positioned(
              left: (screenWidth - 342) / 2, // Center for width 342
              top: screenHeight * 0.828, // 698/844
              child: SizedBox(
                width: 342,
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/main_menu');
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Get Started!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF010101),
                      fontSize: 20,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
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
}