import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
        });
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
    } catch (_) {
      await disconnect();
      throw const SocketException(
        'Cannot reach host. Check that you are on the same Wi-Fi.',
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

/// Singleton manager for 2–5 player real-time local multiplayer.
class NetManager {
  static final NetManager instance = NetManager._();
  NetManager._();

  static const int defaultPort = 7777;
  static const int maxClients = 4; // 1 Host + 4 Guests = 5 players max
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
  final ValueNotifier<Map<String, double>> playerProgress =
      ValueNotifier<Map<String, double>>({});
  final ValueNotifier<bool> isConnected = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isMatchStarted = ValueNotifier<bool>(false);
  final ValueNotifier<String?> matchWinnerId = ValueNotifier<String?>(null);
  final ValueNotifier<List<Map<String, dynamic>>?> finalScoreboard =
      ValueNotifier<List<Map<String, dynamic>>?>(null);

  final Set<String> _finishedPlayers = {};

  bool get isHost => _transport.isHost;

  /// Replace transport for testing.
  @visibleForTesting
  void setTransportForTesting(MatchTransport customTransport) {
    _transport = customTransport;
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

    players.value = {'1': nickname};
    playerScores.value = {'1': 0};
    playerProgress.value = {'1': 0.0};
    isMatchStarted.value = false;
    matchWinnerId.value = null;
    finalScoreboard.value = null;

    await _transport.hostSession(port: port, maxClients: maxClients);
    isConnected.value = true;
    _listenToEvents();
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
    _finishedPlayers.clear();

    players.value = {};
    playerScores.value = {};
    playerProgress.value = {};
    isMatchStarted.value = false;
    matchWinnerId.value = null;
    finalScoreboard.value = null;

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
        // Waiting for join_lobby message from client
        break;

      case 'join_lobby':
        final clientId = event['playerId'] as String?;
        final clientNick = (event['nickname'] as String?) ?? 'Guest';
        if (clientId != null) {
          final updated = Map<String, String>.from(players.value);
          updated[clientId] = clientNick;
          players.value = updated;

          final updatedScores = Map<String, int>.from(playerScores.value);
          updatedScores[clientId] = 0;
          playerScores.value = updatedScores;

          final updatedProg = Map<String, double>.from(playerProgress.value);
          updatedProg[clientId] = 0.0;
          playerProgress.value = updatedProg;

          // Broadcast updated lobby state to all clients
          _broadcastLobbyState();
        }
        break;

      case 'score_event':
        final senderId = event['playerId'] as String?;
        final score = event['score'] as int? ?? 0;
        final prog = (event['progress'] as num?)?.toDouble() ?? 0.0;
        if (senderId != null) {
          final updatedScores = Map<String, int>.from(playerScores.value);
          updatedScores[senderId] = score;
          playerScores.value = updatedScores;

          final updatedProg = Map<String, double>.from(playerProgress.value);
          updatedProg[senderId] = prog;
          playerProgress.value = updatedProg;

          // Relay score event to other clients
          _transport.sendEvent(event);
        }
        break;

      case 'player_finished':
        final senderId = event['playerId'] as String?;
        final score = event['score'] as int? ?? 0;
        if (senderId != null) {
          _finishedPlayers.add(senderId);
          final updatedScores = Map<String, int>.from(playerScores.value);
          updatedScores[senderId] = score;
          playerScores.value = updatedScores;

          // If all active players finished, announce winner
          if (_finishedPlayers.length >= players.value.length) {
            _adjudicateAndBroadcastWinner();
          }
        }
        break;

      case 'peer_disconnected':
        final droppedId = event['playerId'] as String?;
        if (droppedId != null) {
          final updated = Map<String, String>.from(players.value);
          updated.remove(droppedId);
          players.value = updated;

          _transport.sendEvent({
            'type': 'peer_disconnected',
            'playerId': droppedId,
          });

          if (!isMatchStarted.value) {
            _broadcastLobbyState();
          } else {
            _finishedPlayers.remove(droppedId);
            if (_finishedPlayers.length >= players.value.length &&
                players.value.isNotEmpty) {
              _adjudicateAndBroadcastWinner();
            }
          }
        }
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

        if (event.containsKey('assignedId')) {
          localPlayerId = event['assignedId'].toString();
        } else {
          // Find own id by matching nickname if not explicitly assigned
          for (final entry in parsed.entries) {
            if (entry.value == localNickname) {
              localPlayerId = entry.key;
              break;
            }
          }
        }

        if (event.containsKey('level')) {
          selectedLevel = event['level'] as int? ?? 1;
        }
        break;

      case 'start_match':
        selectedLevel = event['level'] as int? ?? 1;
        isMatchStarted.value = true;
        matchWinnerId.value = null;
        finalScoreboard.value = null;
        _finishedPlayers.clear();

        // Initialize score map
        final Map<String, int> scores = {};
        final Map<String, double> progs = {};
        for (final id in players.value.keys) {
          scores[id] = 0;
          progs[id] = 0.0;
        }
        playerScores.value = scores;
        playerProgress.value = progs;
        break;

      case 'score_event':
        final senderId = event['playerId'] as String?;
        final score = event['score'] as int? ?? 0;
        final prog = (event['progress'] as num?)?.toDouble() ?? 0.0;
        if (senderId != null) {
          final updatedScores = Map<String, int>.from(playerScores.value);
          updatedScores[senderId] = score;
          playerScores.value = updatedScores;

          final updatedProg = Map<String, double>.from(playerProgress.value);
          updatedProg[senderId] = prog;
          playerProgress.value = updatedProg;
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
        final droppedId = event['playerId'] as String?;
        if (droppedId != null) {
          final updated = Map<String, String>.from(players.value);
          updated.remove(droppedId);
          players.value = updated;
        }
        break;

      case '_internal_connection_closed':
        disconnect();
        break;
    }
  }

  void _broadcastLobbyState() {
    _transport.sendEvent({
      'type': 'lobby_state',
      'level': selectedLevel,
      'players': players.value,
    });
  }

  /// Host starts match for all connected peers.
  void startMatch({int? level}) {
    if (!isHost) return;

    if (level != null) selectedLevel = level;
    final seed = DateTime.now().millisecondsSinceEpoch % 1000000;
    _finishedPlayers.clear();
    isMatchStarted.value = true;
    matchWinnerId.value = null;
    finalScoreboard.value = null;

    final Map<String, int> scores = {};
    final Map<String, double> progs = {};
    for (final id in players.value.keys) {
      scores[id] = 0;
      progs[id] = 0.0;
    }
    playerScores.value = scores;
    playerProgress.value = progs;

    _transport.sendEvent({
      'type': 'start_match',
      'level': selectedLevel,
      'seed': seed,
      'players': players.value,
    });
  }

  /// Send local score & progress update.
  void sendScore({required int score, required double progress}) {
    if (!isConnected.value) return;

    if (playerScores.value[localPlayerId] != score) {
      final updatedScores = Map<String, int>.from(playerScores.value);
      updatedScores[localPlayerId] = score;
      playerScores.value = updatedScores;
    }

    if ((progress - (playerProgress.value[localPlayerId] ?? 0.0)).abs() >= 0.005) {
      final updatedProg = Map<String, double>.from(playerProgress.value);
      updatedProg[localPlayerId] = progress;
      playerProgress.value = updatedProg;
    }

    _transport.sendEvent({
      'type': 'score_event',
      'playerId': localPlayerId,
      'score': score,
      'progress': progress,
    });
  }

  /// Report local player finished or eliminated.
  void reportFinished({required int score, required bool won}) {
    if (!isConnected.value) return;

    _finishedPlayers.add(localPlayerId);
    final updatedScores = Map<String, int>.from(playerScores.value);
    updatedScores[localPlayerId] = score;
    playerScores.value = updatedScores;

    _transport.sendEvent({
      'type': 'player_finished',
      'playerId': localPlayerId,
      'score': score,
      'won': won,
    });

    if (isHost && _finishedPlayers.length >= players.value.length) {
      _adjudicateAndBroadcastWinner();
    }
  }

  void _adjudicateAndBroadcastWinner() {
    final List<Map<String, dynamic>> board = [];
    players.value.forEach((id, name) {
      board.add({
        'id': id,
        'name': name,
        'score': playerScores.value[id] ?? 0,
      });
    });

    // Sort descending by score
    board.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    final winnerId = board.isNotEmpty ? board.first['id'] as String : '1';

    matchWinnerId.value = winnerId;
    finalScoreboard.value = board;

    _transport.sendEvent({
      'type': 'announce_winner',
      'winnerId': winnerId,
      'scoreboard': board,
    });
  }

  /// Disconnect and reset all state.
  Future<void> disconnect() async {
    _eventSubscription?.cancel();
    _eventSubscription = null;

    await _transport.disconnect();

    isConnected.value = false;
    isMatchStarted.value = false;
    players.value = {};
    playerScores.value = {};
    playerProgress.value = {};
    matchWinnerId.value = null;
    finalScoreboard.value = null;
    _finishedPlayers.clear();
  }
}
