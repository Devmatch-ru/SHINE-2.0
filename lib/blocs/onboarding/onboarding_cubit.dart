import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class OnboardingState {}

class OnboardingInitial extends OnboardingState {}

class OnboardingRequired extends OnboardingState {}

class OnboardingComplete extends OnboardingState {}

class OnboardingCubit extends Cubit<OnboardingState> {
  static const _shownKey = 'onboarding_shown';

  OnboardingCubit() : super(OnboardingInitial()) {
    _loadFlag();
  }

  Future<void> _loadFlag() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(_shownKey) ?? false;
    emit(shown ? OnboardingComplete() : OnboardingRequired());
  }

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shownKey, true);
    emit(OnboardingComplete());
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_shownKey);
    emit(OnboardingRequired());
  }
}
