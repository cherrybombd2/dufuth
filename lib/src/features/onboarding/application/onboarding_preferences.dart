import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _seenOnboardingKey = 'seen_onboarding';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return const OnboardingRepository();
});

final onboardingSeenProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(onboardingRepositoryProvider);
  return repository.hasSeenOnboarding();
});

class OnboardingRepository {
  const OnboardingRepository();

  Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenOnboardingKey) ?? false;
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenOnboardingKey, true);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seenOnboardingKey);
  }
}
