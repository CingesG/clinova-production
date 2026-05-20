import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/env.dart';
import 'src/app/app.dart';
import 'src/app/clinova_web_startup.dart';
import 'src/features/settings/presentation/language_controller.dart';

Future<void> _initFirebaseOptional() async {
  try {
    if (kIsWeb && Env.firebaseWebApiKey.isNotEmpty) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: Env.firebaseWebApiKey,
          authDomain: Env.firebaseWebAuthDomain,
          projectId: Env.firebaseWebProjectId,
          storageBucket: Env.firebaseWebStorageBucket,
          messagingSenderId: Env.firebaseWebMessagingSenderId,
          appId: Env.firebaseWebAppId,
          measurementId: Env.firebaseWebMeasurementId.isEmpty
              ? null
              : Env.firebaseWebMeasurementId,
        ),
      );
      debugPrint('[Auth] Firebase initialized with web options');
    } else if (!kIsWeb) {
      await Firebase.initializeApp();
      debugPrint('[Auth] Firebase initialized with platform defaults');
    } else {
      debugPrint('[Auth] Firebase skipped on web (missing config)');
    }
  } catch (e) {
    debugPrint('[Auth] Firebase init failed: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Do not block first Flutter frame on Firebase or prefs.
    unawaited(_initFirebaseOptional());
    runApp(const ProviderScope(child: ClinovaWebStartup()));
    return;
  }

  await _initFirebaseOptional();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const ClinovaApp(),
    ),
  );
}
