import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../constants.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Shown instead of the app when build-time config is missing, so a launch
/// without `--dart-define-from-file` explains itself rather than leaving a
/// blank window (Xcode Run, editor Run without a launch config, etc.).
class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: buildRelayTheme(
        Brightness.light,
        platform: defaultTargetPlatform,
        isWeb: kIsWeb,
      ),
      darkTheme: buildRelayTheme(
        Brightness.dark,
        platform: defaultTargetPlatform,
        isWeb: kIsWeb,
      ),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(RelaySpace.s6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Builder(
                  builder: (context) {
                    final text = Theme.of(context).textTheme;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$appName isn’t configured',
                          style: text.headlineLarge,
                        ),
                        const SizedBox(height: RelaySpace.s3),
                        SelectableText(message, style: text.bodyMedium),
                        const SizedBox(height: RelaySpace.s4),
                        SelectableText(
                          'flutter run --dart-define-from-file=env/local.json',
                          style: text.bodySmall?.copyWith(
                            fontFamily: RelayFonts.mono,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
