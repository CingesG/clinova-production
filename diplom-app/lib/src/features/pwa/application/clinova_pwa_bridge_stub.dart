/// Non-web: PWA install bridge is inert.
bool clinovaPwaIsStandalone() => false;

Future<bool> clinovaPwaPromptInstall() async => false;

void clinovaPwaOnInstallAvailable(void Function() callback) {}

String clinovaPwaUserAgent() => '';
