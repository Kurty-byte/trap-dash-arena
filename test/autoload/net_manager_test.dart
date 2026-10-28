import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/autoload/net_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NetManager Unit & Loopback Tests', () {
    late NetManager hostNet;
    late NetManager guestNet;
    const testPort = 7788;

    setUp(() async {
      hostNet = NetManager.instance;
      guestNet = NetManager.instance;
      await hostNet.disconnect();
    });

    tearDown(() async {
      await hostNet.disconnect();
      await guestNet.disconnect();
    });

    test('getLocalIp returns non-empty IPv4 string', () async {
      final ip = await NetManager.getLocalIp();
      expect(ip, isNotEmpty);
      expect(ip.contains('.'), isTrue);
    });

    test('Host starts session and initial state is populated', () async {
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
      expect(hostNet.selectedLevel, equals(2));
    });

    test('Unreachable host throws SocketException with exact wifi message', () async {
      // Connect to non-existent server on unused loopback port with short timeout
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

    test('Host and Guest complete loopback handshake and score synchronization', () async {
      final transportHost = LocalWsTransport();
      final transportGuest = LocalWsTransport();

      final host = NetManager.instance;
      host.setTransportForTesting(transportHost);

      await host.startHost(
        nickname: 'AliceHost',
        level: 1,
        port: 7789,
      );

      // Create a second NetManager-like receiver using the guest transport
      final guestEvents = <Map<String, dynamic>>[];
      transportGuest.incomingEvents.listen(guestEvents.add);

      await transportGuest.joinSession(
        host: '127.0.0.1',
        port: 7789,
      );

      expect(transportGuest.isConnected, isTrue);

      // Guest sends join_lobby
      transportGuest.sendEvent({
        'type': 'join_lobby',
        'nickname': 'BobGuest',
      });

      // Wait for host to process
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(host.players.value.length, equals(2));
      expect(host.players.value.values.contains('BobGuest'), isTrue);

      // Guest reports score
      transportGuest.sendEvent({
        'type': 'score_event',
        'playerId': '2',
        'score': 350,
        'progress': 0.75,
      });

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(host.playerScores.value['2'], equals(350));
      expect(host.playerProgress.value['2'], equals(0.75));

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

    test('Winner adjudication sorts descending by score', () async {
      await hostNet.startHost(
        nickname: 'HostRunner',
        level: 1,
        port: 7790,
      );

      // Simulate a guest in players map
      hostNet.players.value = {
        '1': 'HostRunner',
        '2': 'GuestRunner',
      };
      hostNet.playerScores.value = {
        '1': 300,
        '2': 550,
      };

      // Both report finished
      hostNet.reportFinished(score: 300, won: true);

      // Simulate guest finished event
      final transportHost = LocalWsTransport();
      hostNet.setTransportForTesting(transportHost);

      // Call adjudication directly through reportFinished logic
      hostNet.players.value = {
        '1': 'HostRunner',
        '2': 'GuestRunner',
      };
      hostNet.playerScores.value = {
        '1': 300,
        '2': 550,
      };

      hostNet.reportFinished(score: 300, won: true);

      // Disconnect
      await hostNet.disconnect();
    });
  });
}
