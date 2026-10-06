import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';

class RelayApp extends ConsumerWidget {
  const RelayApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: appName,
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
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
