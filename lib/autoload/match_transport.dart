import 'dart:async';

/// Abstract transport contract for 2–5 player local multiplayer matches.
abstract class MatchTransport {
  /// Stream of incoming JSON event payloads.
  Stream<Map<String, dynamic>> get incomingEvents;

  /// Whether this peer is the match host.
  bool get isHost;

  /// Whether this transport currently has an active connection/session.
  bool get isConnected;

  /// Start a host session on [port] accepting up to [maxClients] guests.
  Future<void> hostSession({required int port, required int maxClients});

  /// Join an existing host session at [host]:[port] with [timeout].
  Future<void> joinSession({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 5),
  });

  /// Send an event payload to peers or host.
  void sendEvent(Map<String, dynamic> event);

  /// Disconnect and terminate the session.
  Future<void> disconnect();
}
