import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLocalePrefKey = 'clinova_locale';

/// Provided from [main] via the root [ProviderScope.overrides].
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError(
    'sharedPreferencesProvider must be overridden in main() with SharedPreferences.getInstance().',
  );
});

class LanguageController extends StateNotifier<Locale> {
  LanguageController(this._prefs) : super(const Locale('mn')) {
    _restore();
  }

  final SharedPreferences _prefs;

  void _restore() {
    final code = _prefs.getString(_kLocalePrefKey);
    if (code == 'en' || code == 'mn') {
      state = Locale(code!);
    }
  }

  Future<void> setLanguage(String code) async {
    if (code != 'en' && code != 'mn') return;
    state = Locale(code);
    await _prefs.setString(_kLocalePrefKey, code);
  }
}

final languageControllerProvider =
    StateNotifierProvider<LanguageController, Locale>(
      (ref) {
        final prefs = ref.watch(sharedPreferencesProvider);
        return LanguageController(prefs);
      },
    );
