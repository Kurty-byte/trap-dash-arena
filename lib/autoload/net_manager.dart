import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:trap_dash_arena/autoload/match_transport.dart';

/// WebSocket implementation of [MatchTransport] for local Wi-Fi / hotspot.
class LocalWsTransport implements MatchTransport {
  HttpServer? _server;
  final Map<String, WebSocket> _clientSockets = {};
  WebSocket? _guestSocket;

  bool _isHost = false;
  bool _isConnected = false;
  int _nextClientId = 2;

  final StreamController<Map<String, dynamic>> _incomingEventsController =
      StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get incomingEvents =>
      _incomingEventsController.stream;

  @override
  bool get isHost => _isHost;

  @override
  bool get isConnected => _isConnected;

  @override
  Future<void> hostSession({required int port, required int maxClients}) async {
    await disconnect();
    _isHost = true;
    _nextClientId = 2;

    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    _server?.idleTimeout = null;
    _isConnected = true;

    _server!.listen(
      (HttpRequest request) {
        if (!WebSocketTransformer.isUpgradeRequest(request)) {
          request.response.statusCode = HttpStatus.badRequest;
          request.response.close();
          return;
        }

        if (_clientSockets.length >= maxClients) {
          request.response.statusCode = HttpStatus.serviceUnavailable;
          request.response.close();
          return;
        }

        WebSocketTransformer.upgrade(request).then((socket) {
          // Ping so half-open Wi-Fi drops close the socket (-> forfeit path).
          socket.pingInterval = const Duration(seconds: 2);
          final clientId = '${_nextClientId++}';
          _clientSockets[clientId] = socket;

          // Notify internal listeners of new socket
          _incomingEventsController.add({
            'type': '_internal_client_connected',
            'clientId': clientId,
          });

          socket.listen(
            (data) {
              try {
                final Map<String, dynamic> msg = jsonDecode(data.toString());
                msg['playerId'] = clientId;
                _incomingEventsController.add(msg);
              } catch (_) {}
            },
            onDone: () {
              _clientSockets.remove(clientId);
              _incomingEventsController.add({
                'type': 'peer_disconnected',
                'playerId': clientId,
              });
            },
            onError: (_) {
              _clientSockets.remove(clientId);
              _incomingEventsController.add({
                'type': 'peer_disconnected',
                'playerId': clientId,
              });
            },
          );
        }).catchError((_) {});
      },
      onError: (_) {
        disconnect();
      },
    );
  }

  @override
  Future<void> joinSession({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await disconnect();
    _isHost = false;

    try {
      final socket = await WebSocket.connect(
        'ws://$host:$port',
      ).timeout(timeout);

      socket.pingInterval = const Duration(seconds: 2);
      _guestSocket = socket;
      _isConnected = true;

      socket.listen(
        (data) {
          try {
            final Map<String, dynamic> msg = jsonDecode(data.toString());
            _incomingEventsController.add(msg);
          } catch (_) {}
        },
        onDone: () {
          _isConnected = false;
          _incomingEventsController.add({
            'type': '_internal_connection_closed',
          });
        },
        onError: (_) {
          _isConnected = false;
          _incomingEventsController.add({
            'type': '_internal_connection_closed',
          });
        },
      );
    } on TimeoutException {
      await disconnect();
      throw const SocketException(
        'Cannot reach host. Check that you are on the same Wi-Fi.',
      );
    } catch (e) {
      await disconnect();
      // Reached a server that refused the upgrade: our host answers 503 when full.
      throw SocketException(
        e is WebSocketException
            ? 'Host refused the connection. The lobby may be full.'
            : 'Cannot reach host. Check that you are on the same Wi-Fi.',
      );
    }
  }

  @override
  void sendEvent(Map<String, dynamic> event) {
    final payload = jsonEncode(event);
    if (_isHost) {
      for (final client in _clientSockets.values) {
        try {
          client.add(payload);
        } catch (_) {}
      }
    } else {
      try {
        _guestSocket?.add(payload);
      } catch (_) {}
    }
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _isHost = false;

    for (final client in List.of(_clientSockets.values)) {
      try {
        await client.close();
      } catch (_) {}
    }
    _clientSockets.clear();

    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;

    try {
      await _guestSocket?.close();
    } catch (_) {}
    _guestSocket = null;
  }
}

/// A host heard on the LAN via its UDP beacon.
class DiscoveredHost {
  final String ip;
  final String name;
  final int level;
  final int port;
  const DiscoveredHost(this.ip, this.name, this.level, this.port);
}

/// Singleton manager for 1v1 (2-player) real-time local multiplayer ghost race.
class NetManager {
  static final NetManager instance = NetManager._();
  NetManager._();

  static const int defaultPort = 7777;
  static const int discoveryPort = 7778;

  Timer? _beacon;
  RawDatagramSocket? _beaconSocket;

  /// Host: broadcast a tiny UDP beacon every second while the lobby has room.
  Future<void> _startBeacon(int port) async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      _beaconSocket = socket;
      _beacon = Timer.periodic(const Duration(seconds: 1), (_) {
        if (players.value.length >= 2) return; // full: stop advertising
        socket.send(
          utf8.encode(jsonEncode({
            'g': 'TDA',
            'n': localNickname,
            'l': selectedLevel,
            'p': port,
          })),
          InternetAddress('255.255.255.255'),
          discoveryPort,
        );
      });
    } catch (_) {
      // Discovery is optional; manual IP entry still works.
    }
  }

  /// Guest: listen for host beacons for [timeout] and return who answered.
  /// shortcut: UDP broadcast only, so it misses hosts on networks that block broadcast; manual IP is the fallback.
  static Future<List<DiscoveredHost>> discoverHosts({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final found = <String, DiscoveredHost>{};
    RawDatagramSocket? socket;
    try {
      final s = socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
      );
      final sub = s.listen((event) {
        if (event != RawSocketEvent.read) return;
        final d = s.receive();
        if (d == null) return;
        try {
          final m = jsonDecode(utf8.decode(d.data)) as Map<String, dynamic>;
          if (m['g'] != 'TDA') return;
          found[d.address.address] = DiscoveredHost(
            d.address.address,
            (m['n'] as String?) ?? 'Host',
            (m['l'] as int?) ?? 1,
            (m['p'] as int?) ?? defaultPort,
          );
        } catch (_) {}
      });
      await Future<void>.delayed(timeout);
      await sub.cancel();
    } catch (_) {
      // Bind failed: report whatever we have (nothing).
    } finally {
      socket?.close();
    }
    return found.values.toList();
  }
  static const int maxClients = 1; // Strict 1v1: 1 Host + 1 Guest = 2 players max
  static const String errorWifiMessage =
      'Cannot reach host. Check that you are on the same Wi-Fi.';

  MatchTransport _transport = LocalWsTransport();
  StreamSubscription? _eventSubscription;

  // State
  String localPlayerId = '1';
  String localNickname = 'Runner';
  int selectedLevel = 1;

  final ValueNotifier<Map<String, String>> players =
      ValueNotifier<Map<String, String>>({});
  final ValueNotifier<Map<String, int>> playerScores =
      ValueNotifier<Map<String, int>>({});
  final ValueNotifier<Map<String, int>> playerCoins =
      ValueNotifier<Map<String, int>>({});
  final ValueNotifier<Map<String, double>> playerProgress =
      ValueNotifier<Map<String, double>>({});
  final ValueNotifier<Map<String, Offset>> playerPositions =
      ValueNotifier<Map<String, Offset>>({});
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isMatchStarted = ValueNotifier<bool>(false);
  final ValueNotifier<String?> matchWinnerId = ValueNotifier<String?>(null);
  final ValueNotifier<List<Map<String, dynamic>>?> finalScoreboard =
      ValueNotifier<List<Map<String, dynamic>>?>(null);
  final ValueNotifier<bool> opponentDisconnected = ValueNotifier<bool>(false);

  String _guestId = '2'; // id the transport stamped on the guest (host side)

  final Set<String> _finishedPlayers = {};
  final Map<String, Map<String, dynamic>> _finishDetails = {};

  bool get isHost => _transport.isHost;

  /// Replace transport for testing.
  @visibleForTesting
  void setTransportForTesting(MatchTransport customTransport) {
    _transport = customTransport;
  }

  /// Injects an incoming event for unit testing.
  @visibleForTesting
  void handleIncomingEventForTesting(Map<String, dynamic> event) {
    _handleIncomingEvent(event);
  }

  /// Resolve local IPv4 address for hosting display.
  static Future<String> getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.type == InternetAddressType.IPv4) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  /// Host a new match lobby on [port].
  Future<void> startHost({
    required String nickname,
    int level = 1,
    int port = defaultPort,
  }) async {
    await disconnect();

    localNickname = nickname;
    localPlayerId = '1';
    selectedLevel = level;
    _finishedPlayers.clear();
    _finishDetails.clear();

    players.value = {'1': nickname};
    playerScores.value = {'1': 0};
    playerCoins.value = {'1': 0};
    playerProgress.value = {'1': 0.0};
    playerPositions.value = {}; // empty until a real position arrives (no ghost snap to 0,0)
    isMatchStarted.value = false;
    matchWinnerId.value = null;
    finalScoreboard.value = null;
    opponentDisconnected.value = false;

    await _transport.hostSession(port: port, maxClients: maxClients);
    isConnected.value = true;
    _listenToEvents();
    await _startBeacon(port);
  }

  /// Join an existing host session.
  Future<void> joinGame({
    required String host,
    required String nickname,
    int port = defaultPort,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await disconnect();

    localNickname = nickname;
    localPlayerId = '2'; // In 1v1 guest is always ID '2'
    _finishedPlayers.clear();
    _finishDetails.clear();

    players.value = {};
    playerScores.value = {};
    playerCoins.value = {};
    playerProgress.value = {};
    playerPositions.value = {};
    isMatchStarted.value = false;
    matchWinnerId.value = null;
    finalScoreboard.value = null;
    opponentDisconnected.value = false;

    try {
      await _transport.joinSession(
        host: host,
        port: port,
        timeout: timeout,
      );
      isConnected.value = true;
      _listenToEvents();

      // Send join lobby request to host
      _transport.sendEvent({
        'type': 'join_lobby',
        'nickname': nickname,
      });
    } catch (_) {
      await disconnect();
      rethrow;
    }
  }

  /// Allows Host to change stage (1–5) and broadcast to Guest.
  void setSelectedLevel(int level) {
    selectedLevel = level;
    if (isHost && isConnected.value) {
      _broadcastLobbyState();
    }
  }

  void _listenToEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = _transport.incomingEvents.listen(_handleIncomingEvent);
  }

  void _handleIncomingEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;

    if (isHost) {
      _handleHostEvent(event, type);
    } else {
      _handleGuestEvent(event, type);
    }
  }

  void _handleHostEvent(Map<String, dynamic> event, String? type) {
    switch (type) {
      case '_internal_client_connected':
        break;

      case 'join_lobby':
        final clientId = event['playerId'] as String? ?? '2';
        _guestId = clientId;
        final clientNick = (event['nickname'] as String?) ?? 'Guest';
        final updated = Map<String, String>.from(players.value);
        updated[clientId] = clientNick;
        players.value = updated;

        final updatedScores = Map<String, int>.from(playerScores.value);
        updatedScores[clientId] = 0;
        playerScores.value = updatedScores;

        final updatedCoins = Map<String, int>.from(playerCoins.value);
        updatedCoins[clientId] = 0;
        playerCoins.value = updatedCoins;

        final updatedProg = Map<String, double>.from(playerProgress.value);
        updatedProg[clientId] = 0.0;
        playerProgress.value = updatedProg;

        _broadcastLobbyState();
        break;

      case 'score_event':
        final senderId = event['playerId'] as String? ?? '2';
        final score = event['score'] as int? ?? 0;
        final coins = event['coins'] as int? ?? 0;
        final prog = (event['progress'] as num?)?.toDouble() ?? 0.0;
        final x = (event['x'] as num?)?.toDouble();
        final y = (event['y'] as num?)?.toDouble();

        final updatedScores = Map<String, int>.from(playerScores.value);
        updatedScores[senderId] = score;
        playerScores.value = updatedScores;

        final updatedCoins = Map<String, int>.from(playerCoins.value);
        updatedCoins[senderId] = coins;
        playerCoins.value = updatedCoins;

        final updatedProg = Map<String, double>.from(playerProgress.value);
        updatedProg[senderId] = prog;
        playerProgress.value = updatedProg;

        if (x != null && y != null) {
          final updatedPos = Map<String, Offset>.from(playerPositions.value);
          updatedPos[senderId] = Offset(x, y);
          playerPositions.value = updatedPos;
        }
        // No relay: 1v1, the only client is the sender (echo would clobber its score).
        break;

      case 'player_finished':
        final senderId = event['playerId'] as String? ?? '2';
        final score = event['score'] as int? ?? 0;
        final coins = event['coins'] as int? ?? 0;
        final timeBonus = event['timeBonus'] as int? ?? 0;
        final timeLeft = (event['timeLeft'] as num?)?.toDouble() ?? 0.0;
        final won = event['won'] as bool? ?? false;

        _finishedPlayers.add(senderId);
        _finishDetails[senderId] = {
          'score': score,
          'coins': coins,
          'timeBonus': timeBonus,
          'timeLeft': timeLeft,
          'won': won,
        };

        final updatedScores = Map<String, int>.from(playerScores.value);
        updatedScores[senderId] = score;
        playerScores.value = updatedScores;

        final updatedCoins = Map<String, int>.from(playerCoins.value);
        updatedCoins[senderId] = coins;
        playerCoins.value = updatedCoins;

        if (_finishedPlayers.length >= players.value.length) {
          _adjudicateAndBroadcastWinner();
        }
        break;

      case 'peer_disconnected':
        final droppedId = event['playerId'] as String?;
        if (droppedId != null) {
          final droppedName = players.value[droppedId] ?? 'Guest';
          final updated = Map<String, String>.from(players.value);
          updated.remove(droppedId);
          players.value = updated;

          _transport.sendEvent({
            'type': 'peer_disconnected',
            'playerId': droppedId,
          });

          if (!isMatchStarted.value) {
            _broadcastLobbyState();
          } else if (finalScoreboard.value == null) {
            // Mid-match forfeit: Guest left, Host wins automatically!
            opponentDisconnected.value = true;
            final board = [
              {
                'id': '1',
                'name': localNickname,
                'score': playerScores.value['1'] ?? 0,
                'coins': playerCoins.value['1'] ?? 0,
                'timeBonus': _finishDetails['1']?['timeBonus'] ?? 0,
                'timeLeft': _finishDetails['1']?['timeLeft'] ?? 0.0,
                'won': true,
                'forfeit': true,
              },
              {
                'id': droppedId,
                'name': droppedName,
                'score': playerScores.value[droppedId] ?? 0,
                'coins': playerCoins.value[droppedId] ?? 0,
                'timeBonus': 0,
                'timeLeft': 0.0,
                'won': false,
                'forfeit': true,
              }
            ];
            matchWinnerId.value = '1';
            finalScoreboard.value = board;
          }
        }
        break;

      case 'return_to_lobby':
        _resetForLobby(); // reset only; echoing would bounce forever
        break;
    }
  }

  void _handleGuestEvent(Map<String, dynamic> event, String? type) {
    switch (type) {
      case 'lobby_state':
        final rawPlayers = event['players'] as Map<String, dynamic>? ?? {};
        final Map<String, String> parsed = {};
        rawPlayers.forEach((k, v) => parsed[k] = v.toString());
        players.value = parsed;

        localPlayerId = event['assignedId']?.toString() ?? '2';

        if (event.containsKey('level')) {
          selectedLevel = event['level'] as int? ?? 1;
        }
        break;

      case 'start_match':
        selectedLevel = event['level'] as int? ?? 1;
        isMatchStarted.value = true;
        matchWinnerId.value = null;
        finalScoreboard.value = null;
        opponentDisconnected.value = false;
        _finishedPlayers.clear();
        _finishDetails.clear();
        _zeroScores();
        break;

      case 'score_event':
        final senderId = event['playerId'] as String?;
        final score = event['score'] as int? ?? 0;
        final coins = event['coins'] as int? ?? 0;
        final prog = (event['progress'] as num?)?.toDouble() ?? 0.0;
        final x = (event['x'] as num?)?.toDouble();
        final y = (event['y'] as num?)?.toDouble();

        if (senderId != null) {
          final updatedScores = Map<String, int>.from(playerScores.value);
          updatedScores[senderId] = score;
          playerScores.value = updatedScores;

          final updatedCoins = Map<String, int>.from(playerCoins.value);
          updatedCoins[senderId] = coins;
          playerCoins.value = updatedCoins;

          final updatedProg = Map<String, double>.from(playerProgress.value);
          updatedProg[senderId] = prog;
          playerProgress.value = updatedProg;

          if (x != null && y != null) {
            final updatedPos = Map<String, Offset>.from(playerPositions.value);
            updatedPos[senderId] = Offset(x, y);
            playerPositions.value = updatedPos;
          }
        }
        break;

      case 'announce_winner':
        matchWinnerId.value = event['winnerId'] as String?;
        final rawBoard = event['scoreboard'] as List<dynamic>? ?? [];
        finalScoreboard.value = rawBoard
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        break;

      case 'peer_disconnected':
      case '_internal_connection_closed':
        if (isMatchStarted.value && finalScoreboard.value == null) {
          // Mid-match forfeit: Host disconnected, Guest wins automatically!
          opponentDisconnected.value = true;
          final board = [
            {
              'id': localPlayerId,
              'name': localNickname,
              'score': playerScores.value[localPlayerId] ?? 0,
              'coins': playerCoins.value[localPlayerId] ?? 0,
              'timeBonus': _finishDetails[localPlayerId]?['timeBonus'] ?? 0,
              'timeLeft': _finishDetails[localPlayerId]?['timeLeft'] ?? 0.0,
              'won': true,
              'forfeit': true,
            },
            {
              'id': '1',
              'name': players.value['1'] ?? 'Host',
              'score': playerScores.value['1'] ?? 0,
              'coins': playerCoins.value['1'] ?? 0,
              'timeBonus': 0,
              'timeLeft': 0.0,
              'won': false,
              'forfeit': true,
            }
          ];
          matchWinnerId.value = localPlayerId;
          finalScoreboard.value = board;
          isConnected.value = false; // stop sending on the dead socket
        } else if (finalScoreboard.value != null) {
          // Keep the final board visible; just mark the link dead.
          isConnected.value = false;
        } else {
          disconnect();
        }
        break;

      case 'return_to_lobby':
        _resetForLobby(); // reset only; echoing would bounce forever
        break;
    }
  }

  void _broadcastLobbyState() {
    _transport.sendEvent({
      'type': 'lobby_state',
      'assignedId': _guestId,
      'level': selectedLevel,
      'players': players.value,
    });
  }

  /// Host starts match for both peers.
  void startMatch({int? level}) {
    if (!isHost) return;

    if (level != null) selectedLevel = level;
    final seed = DateTime.now().millisecondsSinceEpoch % 1000000;
    _finishedPlayers.clear();
    _finishDetails.clear();
    isMatchStarted.value = true;
    matchWinnerId.value = null;
    finalScoreboard.value = null;
    opponentDisconnected.value = false;
    _zeroScores();

    _transport.sendEvent({
      'type': 'start_match',
      'level': selectedLevel,
      'seed': seed,
      'players': players.value,
    });
  }

  /// Send local score, coins, progress, and position update (every 0.5s).
  void sendScore({
    required int score,
    int coins = 0,
    required double progress,
    double? x,
    double? y,
  }) {
    if (!isConnected.value) return;

    final updatedScores = Map<String, int>.from(playerScores.value);
    updatedScores[localPlayerId] = score;
    playerScores.value = updatedScores;

    final updatedCoins = Map<String, int>.from(playerCoins.value);
    updatedCoins[localPlayerId] = coins;
    playerCoins.value = updatedCoins;

    final updatedProg = Map<String, double>.from(playerProgress.value);
    updatedProg[localPlayerId] = progress;
    playerProgress.value = updatedProg;

    if (x != null && y != null) {
      final updatedPos = Map<String, Offset>.from(playerPositions.value);
      updatedPos[localPlayerId] = Offset(x, y);
      playerPositions.value = updatedPos;
    }

    _transport.sendEvent({
      'type': 'score_event',
      'playerId': localPlayerId,
      'score': score,
      'coins': coins,
      'progress': progress,
      if (x != null && y != null) ...{
        'x': x,
        'y': y,
      },
    });
  }

  /// Report local player finished or eliminated.
  void reportFinished({
    required int score,
    int coins = 0,
    int timeBonus = 0,
    double timeLeft = 0.0,
    required bool won,
  }) {
    if (!isConnected.value) return;

    _finishedPlayers.add(localPlayerId);
    _finishDetails[localPlayerId] = {
      'score': score,
      'coins': coins,
      'timeBonus': timeBonus,
      'timeLeft': timeLeft,
      'won': won,
    };

    final updatedScores = Map<String, int>.from(playerScores.value);
    updatedScores[localPlayerId] = score;
    playerScores.value = updatedScores;

    final updatedCoins = Map<String, int>.from(playerCoins.value);
    updatedCoins[localPlayerId] = coins;
    playerCoins.value = updatedCoins;

    _transport.sendEvent({
      'type': 'player_finished',
      'playerId': localPlayerId,
      'score': score,
      'coins': coins,
      'timeBonus': timeBonus,
      'timeLeft': timeLeft,
      'won': won,
    });

    if (isHost && _finishedPlayers.length >= players.value.length) {
      _adjudicateAndBroadcastWinner();
    }
  }

  void _adjudicateAndBroadcastWinner() {
    final List<Map<String, dynamic>> board = [];
    players.value.forEach((id, name) {
      final details = _finishDetails[id] ?? {};
      board.add({
        'id': id,
        'name': name,
        'score': playerScores.value[id] ?? (details['score'] as int? ?? 0),
        'coins': playerCoins.value[id] ?? (details['coins'] as int? ?? 0),
        'timeBonus': details['timeBonus'] as int? ?? 0,
        'timeLeft': (details['timeLeft'] as num?)?.toDouble() ?? 0.0,
        'won': details['won'] as bool? ?? false,
      });
    });

    // 1v1 Tie-breaker rule:
    // 1. Highest score
    // 2. If score tied: player who cleared the stage (won == true) beats eliminated player
    // 3. If both won and score tied: player with higher unrounded timeLeft (faster clear)
    // 4. If still tied: declare 'draw'
    board.sort((a, b) {
      final scoreCmp = (b['score'] as int).compareTo(a['score'] as int);
      if (scoreCmp != 0) return scoreCmp;

      final aWon = a['won'] as bool;
      final bWon = b['won'] as bool;
      if (aWon != bWon) return aWon ? -1 : 1;

      final aTime = a['timeLeft'] as double;
      final bTime = b['timeLeft'] as double;
      final timeCmp = bTime.compareTo(aTime);
      if (timeCmp != 0) return timeCmp;

      return 0;
    });

    String winnerId = '1';
    if (board.length >= 2) {
      final p1 = board[0];
      final p2 = board[1];
      if (p1['score'] == p2['score'] &&
          p1['won'] == p2['won'] &&
          (p1['timeLeft'] as double) == (p2['timeLeft'] as double)) {
        winnerId = 'draw';
      } else {
        winnerId = p1['id'] as String;
      }
    } else if (board.isNotEmpty) {
      winnerId = board.first['id'] as String;
    }

    matchWinnerId.value = winnerId;
    finalScoreboard.value = board;

    _transport.sendEvent({
      'type': 'announce_winner',
      'winnerId': winnerId,
      'scoreboard': board,
    });
  }

  /// Rematch: Reset match state so both players return to lobby cleanly.
  void returnToLobby() {
    _resetForLobby();
    if (isConnected.value) {
      _transport.sendEvent({
        'type': 'return_to_lobby',
        'level': selectedLevel,
      });
    }
  }

  /// Local-only lobby reset (never sends, so the peer's handler can reuse it).
  void _resetForLobby() {
    isMatchStarted.value = false;
    matchWinnerId.value = null;
    finalScoreboard.value = null;
    opponentDisconnected.value = false;
    _finishedPlayers.clear();
    _finishDetails.clear();
    _zeroScores();
  }

  /// Zero every player's score/coins/progress; positions stay empty until reported.
  void _zeroScores() {
    final ids = players.value.keys;
    playerScores.value = {for (final id in ids) id: 0};
    playerCoins.value = {for (final id in ids) id: 0};
    playerProgress.value = {for (final id in ids) id: 0.0};
    playerPositions.value = {};
  }

  /// Disconnect and reset all state.
  Future<void> disconnect() async {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _beacon?.cancel();
    _beacon = null;
    _beaconSocket?.close();
    _beaconSocket = null;

    await _transport.disconnect();

    isConnected.value = false;
    isMatchStarted.value = false;
    players.value = {};
    playerScores.value = {};
    playerCoins.value = {};
    playerProgress.value = {};
    playerPositions.value = {};
    matchWinnerId.value = null;
    finalScoreboard.value = null;
    opponentDisconnected.value = false;
    _finishedPlayers.clear();
    _finishDetails.clear();
  }
}
