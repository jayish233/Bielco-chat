import 'package:chatapp/core/ui/config_error_app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('explains missing config instead of a blank screen', (t) async {
    await t.pumpWidget(const ConfigErrorApp(message: 'Missing SUPABASE_URL'));

    expect(find.text('Relay isn’t configured'), findsOneWidget);
    expect(find.text('Missing SUPABASE_URL'), findsOneWidget);
    expect(
      find.text('flutter run --dart-define-from-file=env/local.json'),
      findsOneWidget,
    );
  });
}
