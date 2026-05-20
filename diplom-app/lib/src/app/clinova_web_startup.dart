import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import '../core/theme/clinova_theme.dart';
import '../core/web/web_startup_loader.dart';
import '../features/settings/presentation/language_controller.dart';
import '../features/splash/presentation/web_instant_splash.dart';
import 'app.dart';

/// Web-only: paints splash immediately while [SharedPreferences] loads in parallel.
class ClinovaWebStartup extends StatefulWidget {
  const ClinovaWebStartup({super.key});

  @override
  State<ClinovaWebStartup> createState() => _ClinovaWebStartupState();
}

class _ClinovaWebStartupState extends State<ClinovaWebStartup> {
  late final Future<SharedPreferences> _prefsFuture =
      SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      hideWebHtmlStartupLoader();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SharedPreferences>(
      future: _prefsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ClinovaTheme.light(),
            home: const WebInstantSplash(),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ClinovaTheme.light(),
            home: const _WebStartupError(),
          );
        }
        return ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(snapshot.data!),
          ],
          child: const ClinovaApp(),
        );
      },
    );
  }
}

class _WebStartupError extends StatelessWidget {
  const _WebStartupError();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Clinova эхлүүлэхэд алдаа гарлаа.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF344054),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Хуудсыг дахин ачааллана уу.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667085)),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => web.window.location.reload(),
                child: const Text('Дахин ачаалах'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
