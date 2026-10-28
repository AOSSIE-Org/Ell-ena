import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/custom_widgets.dart';
import '../../services/navigation_service.dart';
import '../auth/auth.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late List<OnboardingSlide> _slides;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context);
    _slides = [
      OnboardingSlide(
        title: l10n.onboardingTaskManagementTitle,
        description: l10n.onboardingTaskManagementDescription,
        icon: Icons.task_alt,
      ),
      OnboardingSlide(
        title: l10n.onboardingAssistantTitle,
        description: l10n.onboardingAssistantDescription,
        icon: Icons.chat_bubble_outline,
      ),
      OnboardingSlide(
        title: l10n.onboardingContextTitle,
        description: l10n.onboardingContextDescription,
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
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _slides.length,
                itemBuilder: (context, index) {
                  final slide = _slides[index];
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
                                color: Colors.green.withValues(alpha: 0.3),
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
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          slide.description,
                          style: TextStyle(
                            fontSize: 16,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
                      _slides.length,
                      (index) => Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? Colors.green.shade400
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: _currentPage == _slides.length - 1
                        ? l10n.onboardingGetStarted
                        : l10n.onboardingNext,
                    onPressed: _handleNext,
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: l10n.onboardingSkip,
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
        ),
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
