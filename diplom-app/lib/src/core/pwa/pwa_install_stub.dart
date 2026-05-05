import 'dart:async';

bool pwaIsWebStandalone() => false;

bool pwaIsDeferredInstallPromptAvailable() => false;

Stream<void> pwaInstallPromptAvailableStream() => const Stream.empty();

Future<bool> pwaPromptInstall() async => false;

Stream<void> pwaAppInstalledStream() => const Stream.empty();

String pwaFallbackInstallHint() => '';
