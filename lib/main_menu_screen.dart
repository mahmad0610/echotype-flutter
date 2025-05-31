import 'package:flutter/material.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        width: screenWidth,
        height: screenHeight,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(40),
          ),
        ),
        child: Stack(
          children: [
            // Subtle yellow-green wave gradient background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.8,
                    colors: [
                      Color(0xFF010101),
                      Color(0xFF1A1A1A),
                      Color(0xFF2A2A00),
                      Color(0xFF003300),
                    ],
                  ),
                ),
              ),
            ),
            // Greeting Text
            Positioned(
              left: screenWidth * 0.064,
              top: screenHeight * 0.171,
              child: SizedBox(
                width: screenWidth * 0.695,
                child: Text(
                  'How may I help you today?',
                  style: const TextStyle(
                    color: Color(0xFFC6F432),
                    fontSize: 32,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ),
            ),
            // Interactive Buttons
            Positioned(
              left: screenWidth * 0.028,
              top: screenHeight * 0.313,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Start Echo Note Button
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/listening');
                    },
                    child: Container(
                      width: screenWidth * 0.469,
                      height: screenHeight * 0.18,
                      padding: const EdgeInsets.all(16),
                      decoration: ShapeDecoration(
                        color: const Color(0xFFC6F432),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        shadows: const [
                          BoxShadow(
                            color: Color(0xB2DAFF37),
                            blurRadius: 200,
                            offset: Offset(-100, -100),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: ShapeDecoration(
                                color: Colors.black.withAlpha(51), // Fixed
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                              child: Image.asset(
                                'assets/microphone.png',
                                width: 24,
                                height: 24,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: SizedBox(
                              width: screenWidth * 0.387,
                              child: Text(
                                'Start Echo Note',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 32,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // View Saved Notes Button
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/notes');
                    },
                    child: Container(
                      width: screenWidth * 0.469,
                      height: screenHeight * 0.18,
                      padding: const EdgeInsets.all(16),
                      decoration: ShapeDecoration(
                        color: const Color(0xFF8F00FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: ShapeDecoration(
                                color: Colors.black.withAlpha(51), // Fixed
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100),
                                ),
                              ),
                              child: Image.asset(
                                'assets/notes.png',
                                width: 24,
                                height: 24,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: SizedBox(
                              width: screenWidth * 0.387,
                              child: Text(
                                'View Saved Notes',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 32,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // History Section
            Positioned(
              left: screenWidth * 0.021,
              top: screenHeight * 0.626,
              child: SizedBox(
                width: screenWidth * 0.959,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Opacity(
                          opacity: 0.75,
                          child: Text(
                            'History',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                              height: 1.20,
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: 0.50,
                          child: Text(
                            'See all',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400,
                              height: 1.71,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // History Cards
                    Column(
                      children: [
                        _buildHistoryCard(
                          iconAsset: 'assets/microphone.png',
                          color: const Color(0xFFC6F432),
                          text: '“Lecture on UX principles”',
                        ),
                        const SizedBox(height: 8),
                        _buildHistoryCard(
                          iconAsset: 'assets/notes.png',
                          color: const Color(0xFFC09FF8),
                          text: '“Ideas for EchoType MVP”',
                        ),
                        const SizedBox(height: 8),
                        _buildHistoryCard(
                          iconAsset: 'assets/brainstorm.png',
                          color: const Color(0xFFC09FF8),
                          text: '“Voice-to-text app concept brainstorm”',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard({
    required String iconAsset,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: const Color(0xFF171717),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: 1,
            color: Colors.white.withAlpha(66), // Fixed (0.26 opacity → 66 alpha)
          ),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: ShapeDecoration(
              color: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: Image.asset(
              iconAsset,
              width: 20,
              height: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Opacity(
              opacity: 0.75,
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w400,
                  height: 1.71,
                ),
              ),
            ),
          ),
          Opacity(
            opacity: 0.50,
            child: Icon(
              Icons.more_vert,
              color: Colors.white,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}