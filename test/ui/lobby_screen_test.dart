import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/match_transport.dart';
import 'package:trap_dash_arena/autoload/net_manager.dart';
import 'package:trap_dash_arena/ui/lobby_screen.dart';

class FakeMatchTransport implements MatchTransport {
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();
  bool _isHost = false;
  bool _isConnected = false;

  @override
  Stream<Map<String, dynamic>> get incomingEvents => _controller.stream;

  @override
  bool get isHost => _isHost;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> hostSession({required int port, required int maxClients}) async {
    _isHost = true;
    _isConnected = true;
  }

  @override
  Future<void> joinSession({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    _isHost = false;
    _isConnected = true;
  }

  @override
  void sendEvent(Map<String, dynamic> event) {}

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _isHost = false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'player_nickname': 'TestRunner',
    });
    await GameState.instance.init();
    NetManager.instance.setTransportForTesting(FakeMatchTransport());
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

  testWidgets('LobbyScreen Host creates lobby, selects stage, and updates ready state for 1v1',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LobbyScreen(),
      ),
    );
    await tester.pumpAndSettle();

    // Tap stage 3
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    // Tap CREATE LOBBY
    await tester.tap(find.text('CREATE LOBBY'));
    await tester.pumpAndSettle();

    // Verify 1v1 lobby list shows 1/2 players and waiting state
    expect(find.text('PLAYERS IN LOBBY (1/2):'), findsOneWidget);
    expect(find.text('WAITING FOR RIVAL (1/2)'), findsOneWidget);
    expect(find.text('Waiting for rival...'), findsOneWidget);

    // Can change stage while hosting
    await tester.tap(find.text('4'));
    await tester.pumpAndSettle();
    expect(NetManager.instance.selectedLevel, equals(4));

    // Simulate 2nd player joining
    NetManager.instance.players.value = {
      '1': 'TestRunner',
      '2': 'RivalPlayer',
    };
    await tester.pumpAndSettle();

    expect(find.text('PLAYERS IN LOBBY (2/2):'), findsOneWidget);
    expect(find.text('START MATCH (2/2)'), findsOneWidget);

    await NetManager.instance.disconnect();
  });
}
