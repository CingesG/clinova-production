import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/clinova_backdrop.dart';
import '../../pwa/presentation/install_app_banner.dart';

class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({
    super.key,
    required this.body,
    this.leading,
  });

  final Widget body;
  final Widget? leading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ClinovaBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (kIsWeb) const PwaWebAutoInstallTrigger(),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    ?leading,
                    const Spacer(),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: body,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
