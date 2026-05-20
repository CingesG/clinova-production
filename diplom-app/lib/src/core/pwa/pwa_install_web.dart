import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

extension type _NavigatorStandalone(JSObject _) implements JSObject {
  external JSBoolean? get standalone;
}

extension type WindowInstallGlobals(JSObject _) implements JSObject {
  external JSObject? get clinovaDeferredInstallPrompt;
  external JSObject? get deferredInstallPrompt;
  external JSFunction? get clinovaPromptInstall;
  external JSFunction? get clinovaDismissInstallBanner;
}

WindowInstallGlobals _winInstall() =>
    WindowInstallGlobals(web.window as JSObject);

bool pwaIsWebStandalone() {
  if (web.window.matchMedia('(display-mode: standalone)').matches) {
    return true;
  }
  if (web.window.matchMedia('(display-mode: minimal-ui)').matches) {
    return true;
  }
  try {
    final s =
        _NavigatorStandalone(web.window.navigator as JSObject).standalone;
    return s?.toDart == true;
  } catch (_) {
    return false;
  }
}

bool pwaIsDeferredInstallPromptAvailable() {
  try {
    final w = _winInstall();
    final deferred =
        w.clinovaDeferredInstallPrompt ?? w.deferredInstallPrompt;
    return deferred != null;
  } catch (_) {
    return false;
  }
}

/// localStorage mirror for banner dismiss (persists across refresh).
bool pwaIsInstallBannerDismissedInBrowserStorage() {
  try {
    final raw = web.window.localStorage.getItem(
      'clinova_install_banner_dismissed',
    );
    return raw == 'true';
  } catch (_) {
    return false;
  }
}

bool pwaIsPwaMarkedInstalledInBrowserStorage() {
  try {
    final raw = web.window.localStorage.getItem('clinova_pwa_installed');
    return raw == 'true';
  } catch (_) {
    return false;
  }
}

void pwaDismissInstallBannerInBrowserStorage() {
  try {
    web.window.localStorage.setItem(
      'clinova_install_banner_dismissed',
      'true',
    );
  } catch (_) {}
  try {
    final fn = _winInstall().clinovaDismissInstallBanner;
    fn?.callAsFunction(web.window as JSObject);
  } catch (_) {}
}

Stream<void> pwaInstallPromptAvailableStream() {
  late StreamController<void> controller;

  void onPrompt(web.Event _) {
    if (pwaIsDeferredInstallPromptAvailable() && !controller.isClosed) {
      controller.add(null);
    }
  }

  final jsPrompt = onPrompt.toJS;

  controller = StreamController<void>(
    onCancel: () {
      web.window.removeEventListener(
        'clinova-pwa-install-available',
        jsPrompt,
      );
    },
  );

  web.window.addEventListener('clinova-pwa-install-available', jsPrompt);
  web.window.addEventListener('clinova-install-available', jsPrompt);

  scheduleMicrotask(() {
    if (pwaIsDeferredInstallPromptAvailable() && !controller.isClosed) {
      controller.add(null);
    }
  });

  return controller.stream;
}

Stream<void> pwaAppInstalledStream() {
  late StreamController<void> controller;

  void onInstalled(web.Event _) {
    if (!controller.isClosed) {
      controller.add(null);
    }
  }

  final js = onInstalled.toJS;

  controller = StreamController<void>(
    onCancel: () {
      web.window.removeEventListener('clinova-pwa-installed', js);
      web.window.removeEventListener('clinova-app-installed', js);
    },
  );

  web.window.addEventListener('clinova-pwa-installed', js);
  web.window.addEventListener('clinova-app-installed', js);

  return controller.stream;
}

/// Invokes `window.clinovaPromptInstall()` installed from [web/index.html].
Future<bool> pwaPromptInstall() async {
  try {
    final fn = _winInstall().clinovaPromptInstall;
    if (fn == null) return false;
    final out = fn.callAsFunction(web.window as JSObject);
    if (out == null) return false;
    final awaited = await (out as JSPromise<JSBoolean>).toDart;
    return awaited.toDart;
  } catch (_) {
    return false;
  }
}

String pwaFallbackInstallSnackMessage() =>
    'Суулгах боломжгүй байна. Chrome цэс / address bar дээрх Install Clinova-г дарна уу.';

String pwaFallbackInstallHint() {
  final ua = web.window.navigator.userAgent;
  if (RegExp(r'iPhone|iPad|iPod', caseSensitive: false).hasMatch(ua)) {
    return 'Safari / Chrome iOS: Share (Хуваалцах) → «Нүүр дэлгэцэд нэмэх».';
  }
  if (RegExp(r'SamsungBrowser', caseSensitive: false).hasMatch(ua)) {
    return 'Samsung Internet: цэс → «Нүүр дэлгэцэд нэмэх» / Install app.';
  }
  if (RegExp(r'Android', caseSensitive: false).hasMatch(ua)) {
    return 'Цэс (⋮) → Install app эсвэл «Нүүр дэлгэцэд нэмэх».';
  }
  return 'Chrome: address bar баруун дахь суулгах тэмдэг эсвэл цэс (⋮) → Install Clinova.';
}
