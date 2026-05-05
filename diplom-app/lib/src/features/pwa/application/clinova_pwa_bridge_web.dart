// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// Web-only bridge; uses dart:html until package:web migration is done project-wide.

import 'dart:html' as html;

bool clinovaPwaIsStandalone() {
  try {
    if (html.window.matchMedia('(display-mode: standalone)').matches) {
      return true;
    }
    final nav = html.window.navigator;
    final standalone = (nav as dynamic).standalone;
    return standalone == true;
  } catch (_) {
    return false;
  }
}

Future<bool> clinovaPwaPromptInstall() async {
  try {
    final w = html.window as dynamic;
    final result = await w.clinovaPromptInstall() as Object?;
    return result == true;
  } catch (_) {
    return false;
  }
}

void clinovaPwaOnInstallAvailable(void Function() callback) {
  html.window.addEventListener('clinova-pwa-install-available', (Object? _) {
    callback();
  });
}

String clinovaPwaUserAgent() => html.window.navigator.userAgent;
