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
    this.sidePanel,
  });

  final Widget body;
  final Widget? leading;

  /// Shown beside [body] on wide viewports (e.g. marketing panel).
  final Widget? sidePanel;

  static const _wideBreakpoint = 960.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ClinovaBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  sidePanel != null && constraints.maxWidth >= _wideBreakpoint;
              final horizontalPad = wide ? 40.0 : 20.0;
              final topPad = wide ? 12.0 : 8.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (kIsWeb) const PwaWebAutoInstallTrigger(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(8, 4, 8, topPad),
                    child: Row(children: [?leading, const Spacer()]),
                  ),
                  Expanded(
                    child: Align(
                      alignment: wide ? Alignment.topCenter : Alignment.center,
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          horizontalPad,
                          wide ? 4 : 8,
                          horizontalPad,
                          28,
                        ),
                        child: wide
                            ? ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 1120,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 52,
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4,
                                          right: 20,
                                        ),
                                        child: sidePanel!,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 48,
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 460,
                                        ),
                                        child: body,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 520,
                                  ),
                                  child: body,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
