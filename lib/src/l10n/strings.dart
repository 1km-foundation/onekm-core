import 'package:flutter/widgets.dart';

/// Supported locales: English + Hindi now; Kannada, Tamil and Telugu are
/// registered with English fallback until native review lands (shipping
/// unverified trust copy is worse than English).
const kSupportedLocales = [
  Locale('en'),
  Locale('hi'),
  Locale('kn'),
  Locale('ta'),
  Locale('te'),
];

const _reviewed = {'en', 'hi'};

/// Shared core strings (offline banner, retry, session). Per-app screens
/// own their ARB files; this covers chrome every app repeats.
class CoreStrings {
  static String of(String key, Locale locale) {
    final lang = _reviewed.contains(locale.languageCode)
        ? locale.languageCode
        : 'en';
    return _values[key]?[lang] ?? _values[key]?['en'] ?? key;
  }

  static const _values = <String, Map<String, String>>{
    'offline': {
      'en': 'You are offline. Showing saved data.',
      'hi': 'आप ऑफ़लाइन हैं। सहेजा गया डेटा दिखाया जा रहा है।',
    },
    'retry': {
      'en': 'Retry',
      'hi': 'पुनः प्रयास करें',
    },
    'cancel': {
      'en': 'Cancel',
      'hi': 'रद्द करें',
    },
    'tryAgain': {
      'en': 'Something went wrong. Try again.',
      'hi': 'कुछ गलत हो गया। पुनः प्रयास करें।',
    },
    'sessionExpired': {
      'en': 'Session expired. Please log in again.',
      'hi': 'सत्र समाप्त हो गया। कृपया फिर से लॉग इन करें।',
    },
    'loading': {
      'en': 'Loading…',
      'hi': 'लोड हो रहा है…',
    },
    'save': {
      'en': 'Save',
      'hi': 'सहेजें',
    },
    'close': {
      'en': 'Close',
      'hi': 'बंद करें',
    },
    'callSupport': {
      'en': 'Call support',
      'hi': 'सहायता को कॉल करें',
    },
  };
}
