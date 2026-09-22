import 'package:flutter_test/flutter_test.dart';
import 'package:peladinhas/main.dart';

void main() {
  testWidgets('shows clear configuration guidance when Supabase is missing', (tester) async {
    await tester.pumpWidget(const PeladinhasApp(hasSupabaseConfig: false));

    expect(find.text('Peladinhas authentication configuration is missing'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
  });
}
