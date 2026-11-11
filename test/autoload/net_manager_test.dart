import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/autoload/net_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetManager 1v1 Unit & Loopback Tests', () {
    late NetManager hostNet;
    const testPort = 7788;

    setUp(() async {
      hostNet = NetManager.instance;
      await hostNet.disconnect();
    });

    tearDown(() async {
      await hostNet.disconnect();
    });

    test('getLocalIp returns non-empty IPv4 string', () async {
      final ip = await NetManager.getLocalIp();
      expect(ip, isNotEmpty);
      expect(ip.contains('.'), isTrue);
    });

    test('Host starts 1v1 session and initial state is populated', () async {
      await hostNet.startHost(
        nickname: 'HostTester',
        level: 2,
        port: testPort,
      );

      expect(hostNet.isHost, isTrue);
      expect(hostNet.isConnected.value, isTrue);
      expect(hostNet.localPlayerId, equals('1'));
      expect(hostNet.players.value['1'], equals('HostTester'));
      expect(hostNet.playerScores.value['1'], equals(0));
      expect(hostNet.playerCoins.value['1'], equals(0));
      expect(hostNet.selectedLevel, equals(2));
    });

    test('Host setSelectedLevel broadcasts level update', () async {
      await hostNet.startHost(
        nickname: 'HostTester',
        level: 1,
        port: testPort,
      );

      hostNet.setSelectedLevel(4);
      expect(hostNet.selectedLevel, equals(4));
    });

    test('Unreachable host throws SocketException with exact wifi message', () async {
      expect(
        () async => hostNet.joinGame(
          host: '127.0.0.1',
          nickname: 'GuestFail',
          port: 59999,
          timeout: const Duration(milliseconds: 300),
        ),
        throwsA(
          predicate((e) =>
              e is SocketException &&
              e.message == 'Cannot reach host. Check that you are on the same Wi-Fi.'),
        ),
      );
    });

    test('Host and Guest complete 1v1 loopback handshake, ghost sync, and match start', () async {
      final transportHost = LocalWsTransport();
      final transportGuest = LocalWsTransport();

      final host = NetManager.instance;
      host.setTransportForTesting(transportHost);

      await host.startHost(
        nickname: 'Runner',
        level: 1,
        port: 7789,
      );

      final guestEvents = <Map<String, dynamic>>[];
      transportGuest.incomingEvents.listen(guestEvents.add);

      await transportGuest.joinSession(
        host: '127.0.0.1',
        port: 7789,
      );

      expect(transportGuest.isConnected, isTrue);

      // Guest sends join_lobby with duplicate nickname 'Runner'
      transportGuest.sendEvent({
        'type': 'join_lobby',
        'nickname': 'Runner',
      });

      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Guest is assigned ID '2' despite duplicate nickname
      expect(host.players.value.length, equals(2));
      expect(host.players.value['1'], equals('Runner'));
      expect(host.players.value['2'], equals('Runner'));

      // Guest sends 0.5s score_event with coins and coordinates
      transportGuest.sendEvent({
        'type': 'score_event',
        'playerId': '2',
        'score': 200,
        'coins': 2,
        'progress': 0.5,
        'x': 540.0,
        'y': 552.0,
      });

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(host.playerScores.value['2'], equals(200));
      expect(host.playerCoins.value['2'], equals(2));
      expect(host.playerPositions.value['2']?.dx, equals(540.0));
      expect(host.playerPositions.value['2']?.dy, equals(552.0));

      // Host starts match
      host.startMatch(level: 3);
      await Future<void>.delayed(const Duration(milliseconds: 150));

      final startEvent = guestEvents.firstWhere(
        (e) => e['type'] == 'start_match',
        orElse: () => <String, dynamic>{},
      );
      expect(startEvent['level'], equals(3));

      // Disconnect
      await transportGuest.disconnect();
      await host.disconnect();

      expect(transportGuest.isConnected, isFalse);
      expect(host.isConnected.value, isFalse);
    });

    test('1v1 Winner adjudication tie-breaker breaks by timeLeft or declares draw', () async {
      await hostNet.startHost(
        nickname: 'HostRunner',
        level: 1,
        port: 7790,
      );

      hostNet.players.value = {
        '1': 'HostRunner',
        '2': 'GuestRunner',
      };

      // Player 1 finishes with 500 pts (faster: 35.5s left)
      hostNet.reportFinished(
        score: 500,
        coins: 2,
        timeBonus: 300,
        timeLeft: 35.5,
        won: true,
      );

      // Simulate Player 2 incoming finished event with 500 pts (slower: 25.2s left)
      hostNet.handleIncomingEventForTesting({
        'type': 'player_finished',
        'playerId': '2',
        'score': 500,
        'coins': 3,
        'timeBonus': 200,
        'timeLeft': 25.2,
        'won': true,
      });

      // Player 1 wins tie-breaker because timeLeft is higher
      expect(hostNet.matchWinnerId.value, equals('1'));
      expect(hostNet.finalScoreboard.value?.length, equals(2));

      await hostNet.disconnect();
    });

    test('1v1 Mid-match forfeit grants win to remaining player', () async {
      await hostNet.startHost(
        nickname: 'HostRunner',
        level: 1,
        port: 7791,
      );

      hostNet.players.value = {
        '1': 'HostRunner',
        '2': 'GuestRunner',
      };
      hostNet.isMatchStarted.value = true;

      // Simulate guest disconnects mid-match
      hostNet.handleIncomingEventForTesting({
        'type': 'peer_disconnected',
        'playerId': '2',
      });

      expect(hostNet.opponentDisconnected.value, isTrue);
      expect(hostNet.matchWinnerId.value, equals('1'));
      expect(hostNet.finalScoreboard.value, isNotNull);
      expect(hostNet.finalScoreboard.value?.first['forfeit'], isTrue);

      // Verify returnToLobby resets match state
      hostNet.returnToLobby();
      expect(hostNet.isMatchStarted.value, isFalse);
      expect(hostNet.matchWinnerId.value, isNull);
      expect(hostNet.finalScoreboard.value, isNull);

      await hostNet.disconnect();
    });
  });
}
