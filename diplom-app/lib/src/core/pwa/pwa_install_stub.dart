import 'dart:async';

bool pwaIsWebStandalone() => false;

bool pwaIsDeferredInstallPromptAvailable() => false;

bool pwaIsInstallBannerDismissedInBrowserStorage() => false;

bool pwaIsPwaMarkedInstalledInBrowserStorage() => false;

void pwaDismissInstallBannerInBrowserStorage() {}

Stream<void> pwaInstallPromptAvailableStream() => const Stream.empty();

Future<bool> pwaPromptInstall() async => false;

Stream<void> pwaAppInstalledStream() => const Stream.empty();

String pwaFallbackInstallHint() => '';

String pwaFallbackInstallSnackMessage() => '';
