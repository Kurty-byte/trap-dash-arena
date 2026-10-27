import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/main.dart';

void main() {
  testWidgets('TrapDashApp launches and renders title and landscape prompt',
      (WidgetTester tester) async {
    await tester.pumpWidget(const TrapDashApp());

    expect(find.text('TRAP DASH ARENA'), findsOneWidget);
    expect(find.text('Phase 1 Configured (Landscape 1280x720)'), findsOneWidget);
  });
}
