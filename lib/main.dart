import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env.dart';
import 'core/ui/config_error_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = resolveEnv();
  try {
    checkEnv(url: env.url, anonKey: env.anonKey);
  } on StateError catch (e) {
    runApp(ConfigErrorApp(message: e.message));
    return;
  }
  await Supabase.initialize(url: env.url, publishableKey: env.anonKey);
  runApp(const ProviderScope(child: RelayApp()));
}
