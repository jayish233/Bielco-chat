import 'package:chatapp/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpRelay(
  WidgetTester t,
  Widget child, {
  TargetPlatform platform = TargetPlatform.iOS,
  bool isWeb = false,
  Brightness brightness = Brightness.light,
  List<Override> overrides = const [],
}) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        theme: buildRelayTheme(brightness, platform: platform, isWeb: isWeb),
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  // Let AnimatedTheme finish when switching theme between pumps.
  await t.pump(const Duration(milliseconds: 300));
}
