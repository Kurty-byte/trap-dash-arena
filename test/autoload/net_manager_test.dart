import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trap_dash_arena/autoload/match_transport.dart';
import 'package:trap_dash_arena/autoload/net_manager.dart';

/// Host-side fake that records everything NetManager sends.
class _RecordingTransport implements MatchTransport {
  final sent = <Map<String, dynamic>>[];

  @override
  Stream<Map<String, dynamic>> get incomingEvents => const Stream.empty();
  @override
  bool get isHost => true;
  @override
  bool get isConnected => true;
  @override
  Future<void> hostSession({required int port, required int maxClients}) async {}
  @override
  Future<void> joinSession(
      {required String host,
      required int port,
      Duration timeout = const Duration(seconds: 5)}) async {}
  @override
  void sendEvent(Map<String, dynamic> event) => sent.add(event);
  @override
  Future<void> disconnect() async {}
}

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

    test('return_to_lobby from peer resets state without echoing back', () async {
      final fake = _RecordingTransport();
      hostNet.setTransportForTesting(fake);
      await hostNet.startHost(nickname: 'H', port: 7793);
      hostNet.isMatchStarted.value = true;

      hostNet.handleIncomingEventForTesting({'type': 'return_to_lobby'});

      expect(hostNet.isMatchStarted.value, isFalse);
      expect(fake.sent.where((e) => e['type'] == 'return_to_lobby'), isEmpty);

      // Local tap still notifies the peer exactly once.
      hostNet.returnToLobby();
      expect(fake.sent.where((e) => e['type'] == 'return_to_lobby').length, 1);
    });

    test('guest id comes from transport (not hardcoded 2) and scores are not echoed', () async {
      final fake = _RecordingTransport();
      hostNet.setTransportForTesting(fake);
      await hostNet.startHost(nickname: 'H', port: 7794);

      hostNet.handleIncomingEventForTesting(
          {'type': 'join_lobby', 'playerId': '3', 'nickname': 'G'});
      expect(hostNet.players.value['3'], equals('G'));
      expect(fake.sent.last['assignedId'], equals('3'));

      fake.sent.clear();
      hostNet.handleIncomingEventForTesting(
          {'type': 'score_event', 'playerId': '3', 'score': 100});
      expect(hostNet.playerScores.value['3'], equals(100));
      expect(fake.sent, isEmpty);
      expect(hostNet.playerPositions.value, isEmpty);
    });

    test('second guest is refused with a clear message when lobby is full', () async {
      hostNet.setTransportForTesting(LocalWsTransport());
      await hostNet.startHost(nickname: 'H', port: 7795);
      final first = LocalWsTransport();
      await first.joinSession(host: '127.0.0.1', port: 7795);

      final second = LocalWsTransport();
      await expectLater(
        second.joinSession(host: '127.0.0.1', port: 7795),
        throwsA(isA<SocketException>().having((e) => e.message, 'message',
            contains('lobby may be full'))),
      );
      await first.disconnect();
    });

    test('discoverHosts lists a host beacon and ignores junk', () async {
      final scan = NetManager.discoverHosts(
        timeout: const Duration(milliseconds: 600),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final sender = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      final to = InternetAddress.loopbackIPv4;
      sender.send(utf8.encode('not json'), to, NetManager.discoveryPort);
      sender.send(
        utf8.encode(jsonEncode({'g': 'TDA', 'n': 'Ace', 'l': 3, 'p': 7777})),
        to,
        NetManager.discoveryPort,
      );

      final hosts = await scan;
      sender.close();

      expect(hosts.length, equals(1));
      expect(hosts.first.name, equals('Ace'));
      expect(hosts.first.level, equals(3));
      expect(hosts.first.ip, equals('127.0.0.1'));
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
