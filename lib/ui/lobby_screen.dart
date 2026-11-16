import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:trap_dash_arena/autoload/audio_manager.dart';
import 'package:trap_dash_arena/autoload/game_state.dart';
import 'package:trap_dash_arena/autoload/net_manager.dart';
import 'package:trap_dash_arena/autoload/palette.dart';
import 'package:trap_dash_arena/ui/game_screen.dart';
import 'package:trap_dash_arena/ui/widgets/arcade_dialog.dart';
import 'package:trap_dash_arena/ui/widgets/arcade_page_route.dart';
import 'package:trap_dash_arena/ui/widgets/square_back_button.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final NetManager _net = NetManager.instance;
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _isHostTab = true;
  String _hostIp = 'Fetching IP...';
  int _selectedLevel = 1;
  bool _isConnecting = false;
  bool _scanning = false;
  List<DiscoveredHost>? _hosts;

  @override
  void initState() {
    super.initState();
    _nameController.text = GameState.instance.playerNickname;
    _loadHostIp();

    _net.isMatchStarted.addListener(_onMatchStartedChanged);
  }

  @override
  void dispose() {
    _net.isMatchStarted.removeListener(_onMatchStartedChanged);
    _ipController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadHostIp() async {
    final ip = await NetManager.getLocalIp();
    if (mounted) {
      setState(() {
        _hostIp = ip;
      });
    }
  }

  void _onMatchStartedChanged() {
    if (_net.isMatchStarted.value && mounted) {
      GameState.instance.setMode('online');
      AudioManager.instance.playSfx('unlock.wav');
      Navigator.of(context).push(
        ArcadePageRoute(
          page: GameScreen(levelNumber: _net.selectedLevel),
        ),
      ).then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _handleStartHost() async {
    final nick = _nameController.text.trim().isEmpty
        ? 'Host'
        : _nameController.text.trim();
    await GameState.instance.setPlayerNickname(nick);
    AudioManager.instance.playSfx('unlock.wav');

    try {
      await _net.startHost(
        nickname: nick,
        level: _selectedLevel,
      );
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) _showErrorDialog('Could not open port ${NetManager.defaultPort}. Close other apps using it.');
    }
  }

  Future<void> _handleScan() async {
    setState(() {
      _scanning = true;
      _hosts = null;
    });
    final found = await NetManager.discoverHosts();
    if (mounted) {
      setState(() {
        _scanning = false;
        _hosts = found;
      });
    }
  }

  void _quickJoin(DiscoveredHost h) {
    _ipController.text = '${h.ip}:${h.port}';
    _handleConnectGuest();
  }

  Future<void> _handleConnectGuest() async {
    // Accept a pasted "ip:port" as well as a bare ip.
    final parts = _ipController.text.trim().split(':');
    final ip = parts.first;
    final port = (parts.length > 1 ? int.tryParse(parts.last) : null) ??
        NetManager.defaultPort;
    if (ip.isEmpty) {
      _showErrorDialog('Please enter the host IP address.');
      return;
    }

    final nick = _nameController.text.trim().isEmpty
        ? 'Guest'
        : _nameController.text.trim();
    await GameState.instance.setPlayerNickname(nick);
    AudioManager.instance.playSfx('unlock.wav');

    setState(() => _isConnecting = true);

    try {
      await _net.joinGame(
        host: ip,
        port: port,
        nickname: nick,
        timeout: const Duration(seconds: 5),
      );
      if (mounted) setState(() => _isConnecting = false);
    } on SocketException catch (e) {
      if (mounted) {
        setState(() => _isConnecting = false);
        _showErrorDialog(e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isConnecting = false);
        _showErrorDialog(NetManager.errorWifiMessage);
      }
    }
  }

  void _showErrorDialog(String message) {
    showArcadeDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppPalette.yellowBackground,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: AppPalette.brownSolid, width: 3),
        ),
        title: const Text(
          'CONNECTION ERROR',
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 14,
            color: AppPalette.warningRed,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'AtkinsonHyperlegible',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppPalette.playerBlack,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.brownSolid,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                side: BorderSide(color: AppPalette.playerBlack, width: 2),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'OK',
              style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.yellowBackground,
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content
            Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'MULTIPLAYER LOBBY',
                      style: TextStyle(
                        fontFamily: 'PressStart2P',
                        fontSize: 22,
                        color: AppPalette.playerBlack,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '1v1 Local Hotspot / Wi-Fi Race (Coin + Time Scoring)',
                      style: TextStyle(
                        fontFamily: 'AtkinsonHyperlegible',
                        fontSize: 15,
                        color: AppPalette.textDark,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Nickname input row
                    Container(
                      width: 520,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppPalette.yellowBackground,
                        border: Border.all(
                            color: AppPalette.brownSolid, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'NAME: ',
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 12,
                              color: AppPalette.playerBlack,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              maxLength: 12,
                              decoration: const InputDecoration(
                                isDense: true,
                                counterText: '',
                                border: InputBorder.none,
                                hintText: 'Enter name',
                              ),
                              style: const TextStyle(
                                fontFamily: 'AtkinsonHyperlegible',
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppPalette.playerBlack,
                              ),
                              onSubmitted: (val) {
                                GameState.instance.setPlayerNickname(val.trim());
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Tab selector (HOST vs JOIN)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTabButton('HOST MATCH', _isHostTab, () async {
                          if (!_isHostTab) {
                            await _net.disconnect();
                            setState(() => _isHostTab = true);
                          }
                        }),
                        const SizedBox(width: 12),
                        _buildTabButton('JOIN MATCH', !_isHostTab, () async {
                          if (_isHostTab) {
                            await _net.disconnect();
                            setState(() => _isHostTab = false);
                          }
                        }),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // View Body
                    _isHostTab ? _buildHostView() : _buildJoinView(),
                  ],
                ),
              ),
            ),

            // Back button placed on top of Stack
            Positioned(
              top: 14,
              left: 14,
              child: SquareBackButton(
                onPressed: () {
                  unawaited(_net.disconnect());
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        height: 40,
        decoration: BoxDecoration(
          color: active ? AppPalette.brownSolid : AppPalette.yellowBackground,
          border: Border.all(color: AppPalette.playerBlack, width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 11,
            color: active ? Colors.white : AppPalette.playerBlack,
          ),
        ),
      ),
    );
  }

  Widget _buildHostView() {
    return ValueListenableBuilder<bool>(
      valueListenable: _net.isConnected,
      builder: (context, connected, _) {
        final isHosting = connected && _net.isHost;

        return Container(
          width: 520,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppPalette.yellowBackground,
            border: Border.all(color: AppPalette.brownSolid, width: 2.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // IP display banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppPalette.yellowBackground,
                  border: Border.all(color: AppPalette.brownSolid, width: 1.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HOST IP ADDRESS:',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 10,
                            color: AppPalette.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_hostIp:${NetManager.defaultPort}',
                          style: const TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 13,
                            color: AppPalette.playerBlack,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20, color: AppPalette.brownSolid),
                      tooltip: 'Copy IP',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _hostIp));
                        showArcadeToast(
                          context,
                          message: 'Host IP copied to clipboard!',
                          icon: Icons.copy_sharp,
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Stage picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'STAGE:',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 11,
                      color: AppPalette.playerBlack,
                    ),
                  ),
                  Row(
                    children: List.generate(5, (index) {
                      final lvl = index + 1;
                      final isSel = _selectedLevel == lvl;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedLevel = lvl);
                          _net.setSelectedLevel(lvl);
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: BoxDecoration(
                            color: isSel ? AppPalette.brownSolid : AppPalette.yellowBackground,
                            border: Border.all(color: AppPalette.playerBlack, width: 2),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$lvl',
                            style: TextStyle(
                              fontFamily: 'PressStart2P',
                              fontSize: 12,
                              color: isSel ? Colors.white : AppPalette.playerBlack,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Host / Start button
              if (!isHosting)
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.brownSolid,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        side: BorderSide(color: AppPalette.playerBlack, width: 2),
                      ),
                    ),
                    onPressed: _handleStartHost,
                    child: const Text(
                      'CREATE LOBBY',
                      style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
                    ),
                  ),
                )
              else ...[
                _buildPlayerList(),
                const SizedBox(height: 12),
                ValueListenableBuilder<Map<String, String>>(
                  valueListenable: _net.players,
                  builder: (context, playersMap, _) {
                    final readyToStart = playersMap.length >= 2;
                    return SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: readyToStart ? AppPalette.brownDark : Colors.grey,
                          foregroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            side: BorderSide(color: AppPalette.playerBlack, width: 2),
                          ),
                        ),
                        onPressed: readyToStart
                            ? () {
                                AudioManager.instance.playSfx('unlock.wav');
                                _net.startMatch(level: _selectedLevel);
                              }
                            : null,
                        child: Text(
                          readyToStart
                              ? 'START MATCH (2/2)'
                              : 'WAITING FOR RIVAL (${playersMap.length}/2)',
                          style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildJoinView() {
    return ValueListenableBuilder<bool>(
      valueListenable: _net.isConnected,
      builder: (context, connected, _) {
        final isConnected = connected && !_net.isHost;

        return Container(
          width: 520,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppPalette.yellowBackground,
            border: Border.all(color: AppPalette.brownSolid, width: 2.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isConnected) ...[
                // IP Input
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppPalette.yellowBackground,
                    border: Border.all(color: AppPalette.brownSolid, width: 2),
                  ),
                  child: TextField(
                    controller: _ipController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Enter Host IP (e.g. 192.168.1.5)',
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 12,
                      color: AppPalette.playerBlack,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Connect button
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.brownSolid,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        side: BorderSide(color: AppPalette.playerBlack, width: 2),
                      ),
                    ),
                    onPressed: _isConnecting ? null : _handleConnectGuest,
                    child: _isConnecting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'CONNECT TO HOST',
                            style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
                          ),
                  ),
                ),
                const SizedBox(height: 10),

                // Quick match: scan LAN for open hosts
                SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppPalette.brownDark,
                      foregroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        side: BorderSide(color: AppPalette.playerBlack, width: 2),
                      ),
                    ),
                    onPressed: (_isConnecting || _scanning) ? null : _handleScan,
                    child: _scanning
                        ? const Text(
                            'SCANNING...',
                            style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
                          )
                        : const Text(
                            'FIND HOSTS',
                            style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
                          ),
                  ),
                ),
                if (_hosts != null) ...[
                  const SizedBox(height: 8),
                  if (_hosts!.isEmpty)
                    const Text(
                      'No open hosts found. Enter the IP manually.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'AtkinsonHyperlegible',
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppPalette.textDark,
                      ),
                    ),
                  for (final h in _hosts!)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.yellowBackground,
                          foregroundColor: AppPalette.playerBlack,
                          shape: const RoundedRectangleBorder(
                            side: BorderSide(color: AppPalette.brownSolid, width: 2),
                          ),
                        ),
                        onPressed: _isConnecting ? null : () => _quickJoin(h),
                        child: Text(
                          '${h.name}  -  STAGE ${h.level}  (${h.ip})',
                          style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ] else ...[
                // Connected state
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppPalette.yellowBackground,
                    border: Border.all(color: AppPalette.brownSolid, width: 2),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'CONNECTED TO HOST!',
                        style: TextStyle(
                          fontFamily: 'PressStart2P',
                          fontSize: 12,
                          color: AppPalette.playerBlack,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ValueListenableBuilder<Map<String, String>>(
                        valueListenable: _net.players,
                        builder: (context, players, child) {
                          return Text(
                            'Stage: ${_net.selectedLevel}',
                            style: const TextStyle(
                              fontFamily: 'AtkinsonHyperlegible',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppPalette.textDark,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildPlayerList(),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'Waiting for host to start...',
                    style: TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      color: AppPalette.brownDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlayerList() {
    return ValueListenableBuilder<Map<String, String>>(
      valueListenable: _net.players,
      builder: (context, playersMap, _) {
        final entries = playersMap.entries.toList();

        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppPalette.yellowBackground,
            border: Border.all(color: AppPalette.playerBlack, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PLAYERS IN LOBBY (${entries.length}/2):',
                style: const TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 10,
                  color: AppPalette.playerBlack,
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(2, (i) {
                if (i < entries.length) {
                  final isHostSlot = entries[i].key == '1';
                  final isMe = entries[i].key == _net.localPlayerId;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          isHostSlot ? Icons.star : Icons.person,
                          size: 16,
                          color: isHostSlot ? AppPalette.brownSolid : AppPalette.playerBlack,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entries[i].value} ${isMe ? "(You)" : ""}',
                          style: TextStyle(
                            fontFamily: 'PressStart2P',
                            fontSize: 11,
                            color: isMe ? AppPalette.brownSolid : AppPalette.playerBlack,
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 16,
                          color: AppPalette.brownDark.withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Waiting for rival...',
                          style: TextStyle(
                            fontFamily: 'AtkinsonHyperlegible',
                            fontSize: 14,
                            color: AppPalette.brownDark.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }
              }),
            ],
          ),
        );
      },
    );
  }
}
