import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_ui.dart';
import '../application/onboarding_preferences.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _slides = [
    _OnboardingSlideData(
      imagePath: 'assets/onboarding/slide_1.png',
      title: 'Book and Manage Appointments',
      body:
          'Choose a department, select a doctor, pick an available time, and manage your appointments with ease.',
    ),
    _OnboardingSlideData(
      imagePath: 'assets/onboarding/slide_2.png',
      title: 'Track Schedules and Alerts',
      body:
          'Doctors can view upcoming visits, while timely reminders and alerts help everyone stay prepared.',
    ),
    _OnboardingSlideData(
      imagePath: 'assets/onboarding/slide_3.png',
      title: 'Access Hospital Information Quickly',
      body:
          'Find hospital details, helpful FAQs, and important support information whenever you need them.',
    ),
  ];

  late final PageController _pageController;
  int _currentIndex = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    await ref.read(onboardingRepositoryProvider).markSeen();
    ref.invalidate(onboardingSeenProvider);
    if (mounted) {
      context.go('/');
    }
  }

  Future<void> _next() async {
    if (_currentIndex == _slides.length - 1) {
      await _complete();
      return;
    }
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _currentIndex == _slides.length - 1;

    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isSaving ? null : _complete,
                    style: TextButton.styleFrom(
                      foregroundColor: AuthColors.textMuted,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    child: const Text('Skip'),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _slides.length,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Column(
                        children: [
                          const Spacer(flex: 2),
                          Expanded(
                            flex: 11,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Image.asset(
                                slide.imagePath,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: AuthColors.navy,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            slide.body,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: AuthColors.textMuted,
                              height: 1.6,
                            ),
                          ),
                          const Spacer(flex: 3),
                        ],
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      width: _currentIndex == index ? 26 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: _currentIndex == index
                            ? AuthColors.blue
                            : const Color(0xFFD7E8FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (_currentIndex > 0)
                      TextButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AuthColors.textMuted,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        child: const Text('Back'),
                      )
                    else
                      const SizedBox(width: 64),
                    const Spacer(),
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: AuthColors.button,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        child: Text(isLast ? 'Get Started' : 'Next'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.imagePath,
    required this.title,
    required this.body,
  });

  final String imagePath;
  final String title;
  final String body;
}
