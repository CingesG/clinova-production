import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

extension type _ClinovaWindow(JSObject _) implements JSObject {
  external JSObject? get deferredInstallPrompt;

  external JSPromise<JSBoolean> clinovaPromptInstall();
}

extension type _NavigatorStandalone(JSObject _) implements JSObject {
  external JSBoolean? get standalone;
}

_ClinovaWindow _winObj(web.Window w) => _ClinovaWindow(w as JSObject);

bool pwaIsWebStandalone() {
  if (web.window.matchMedia('(display-mode: standalone)').matches) {
    return true;
  }
  if (web.window.matchMedia('(display-mode: minimal-ui)').matches) {
    return true;
  }
  try {
    final s = _NavigatorStandalone(web.window.navigator as JSObject).standalone;
    return s?.toDart == true;
  } catch (_) {
    return false;
  }
}

bool _deferredPromptNonNull() {
  try {
    return _winObj(web.window).deferredInstallPrompt != null;
  } catch (_) {
    return false;
  }
}

bool pwaIsDeferredInstallPromptAvailable() => _deferredPromptNonNull();

Stream<void> pwaInstallPromptAvailableStream() {
  late StreamController<void> controller;

  void onPrompt(web.Event _) {
    if (_deferredPromptNonNull() && !controller.isClosed) {
      controller.add(null);
    }
  }

  final jsPrompt = onPrompt.toJS;

  controller = StreamController<void>(
    onCancel: () {
      web.window.removeEventListener('clinova-pwa-install-available', jsPrompt);
    },
  );

  web.window.addEventListener('clinova-pwa-install-available', jsPrompt);

  scheduleMicrotask(() {
    if (_deferredPromptNonNull() && !controller.isClosed) {
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
    },
  );

  web.window.addEventListener('clinova-pwa-installed', js);

  return controller.stream;
}

Future<bool> pwaPromptInstall() async {
  try {
    final r =
        await _winObj(web.window).clinovaPromptInstall().toDart;
    return r.toDart;
  } catch (_) {
    return false;
  }
}

String pwaFallbackInstallHint() {
  final ua = web.window.navigator.userAgent;
  if (RegExp(r'iPhone|iPad|iPod', caseSensitive: false).hasMatch(ua)) {
    return 'Safari / Chrome iOS: доорхоос Share (Хуваалцах) → «Нүүр дэлгэцэд нэмэх» сонгоно уу.';
  }
  if (RegExp(r'SamsungBrowser', caseSensitive: false).hasMatch(ua)) {
    return 'Samsung Internet: цэс (≡ эсвэл ⋮) → «Add page to» / Install app / «Нүүр дэлгэцэд нэмэх».';
  }
  if (RegExp(r'Android', caseSensitive: false).hasMatch(ua)) {
    return 'Хөтөчийн цэс (⋮) → «Install app» эсвэл «Нүүр дэлгэцэд нэмэх» гэж сонгоно уу.';
  }
  return 'Chrome: цэс (⋮) → «Install Clinova…», эсвэл хаягны баруун талын суулгах товчийг ашиглана уу.';
}
