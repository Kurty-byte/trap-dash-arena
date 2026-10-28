import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/net_manager.dart';
import 'package:trap_dash_arena/ui/lobby_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'player_nickname': 'TestRunner',
    });
    await GameState.instance.init();
    await NetManager.instance.disconnect();
  });

  tearDown(() async {
    await NetManager.instance.disconnect();
  });

  testWidgets('LobbyScreen renders title, nickname, tabs, and switches views',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LobbyScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Verify title and tabs
    expect(find.text('MULTIPLAYER LOBBY'), findsOneWidget);
    expect(find.text('HOST MATCH'), findsOneWidget);
    expect(find.text('JOIN MATCH'), findsOneWidget);

    // Initial tab is Host Match
    expect(find.text('CREATE LOBBY'), findsOneWidget);
    expect(find.text('STAGE:'), findsOneWidget);

    // Tap Join Match tab
    await tester.tap(find.text('JOIN MATCH'));
    await tester.pumpAndSettle();

    // Verify Join View
    expect(find.text('CONNECT TO HOST'), findsOneWidget);

    // Enter empty IP and press connect -> error dialog
    await tester.tap(find.text('CONNECT TO HOST'));
    await tester.pumpAndSettle();

    expect(find.text('CONNECTION ERROR'), findsOneWidget);
    expect(find.text('Please enter the host IP address.'), findsOneWidget);

    // Dismiss dialog
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.text('CONNECTION ERROR'), findsNothing);
  });
}
