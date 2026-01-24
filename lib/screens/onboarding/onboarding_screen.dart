import 'package:flutter/material.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import '../auth/auth.dart';

import 'package:get/get.dart';
import '../../controllers/language_controller.dart';
import '../../utils/language/sentence_manager.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final LanguageController _languageController = Get.find<LanguageController>();
  int _currentPage = 0;

  List<OnboardingSlide> get _slides {
    final s = SentenceManager(
            currentLanguage: _languageController.selectedLanguage.value)
        .sentences;
    return [
      OnboardingSlide(
        title: s.onboardingTitle1,
        description: s.onboardingDesc1,
        icon: Icons.task_alt,
      ),
      OnboardingSlide(
        title: s.onboardingTitle2,
        description: s.onboardingDesc2,
        icon: Icons.chat_bubble_outline,
      ),
      OnboardingSlide(
        title: s.onboardingTitle3,
        description: s.onboardingDesc3,
        icon: Icons.psychology_outlined,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      NavigationService().navigateToReplacement(const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: SafeArea(
        child: Obx(() {
          // Re-render when language changes
          final slides = _slides;
          final s = SentenceManager(
                  currentLanguage: _languageController.selectedLanguage.value)
              .sentences;

          return Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: slides.length,
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green.shade400,
                                  Colors.green.shade700,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Icon(
                              slide.icon,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            slide.title,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            slide.description,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade400,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        slides.length,
                        (index) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentPage == index
                                ? Colors.green.shade400
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      text: _currentPage == slides.length - 1
                          ? s.getStarted
                          : s.next,
                      onPressed: _handleNext,
                    ),
                    const SizedBox(height: 16),
                    CustomButton(
                      text: s.skip,
                      onPressed: () {
                        NavigationService().navigateToReplacement(
                          const LoginScreen(),
                        );
                      },
                      isOutlined: true,
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class OnboardingSlide {
  final String title;
  final String description;
  final IconData icon;

  OnboardingSlide({
    required this.title,
    required this.description,
    required this.icon,
  });
}
