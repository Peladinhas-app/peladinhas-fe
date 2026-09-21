import 'package:flutter_test/flutter_test.dart';
import 'package:peladinhas/main.dart';

void main() {
  testWidgets('shows the Peladinhas match demo shell', (tester) async {
    await tester.pumpWidget(const PeladinhasApp());

    expect(find.text('Peladinhas'), findsOneWidget);
    expect(find.text('Create match'), findsOneWidget);
    expect(find.text('Match details'), findsOneWidget);
    expect(find.text('Player result'), findsOneWidget);
  });
}
