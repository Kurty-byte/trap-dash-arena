# AGENTS.md — Development & Architecture Guide for AI Agents

## 1. Project Overview & Identity
* **Project Name:** Trap Dash Arena
* **Course:** ITSD 85 – Special Topics in Software Development
* **Genre:** 2D Deceptive Trap Platformer / Competitive Score-Rush Arcade
* **Target Audience:** Ages 15–25; mobile gamers who enjoy *Trap Adventure 2* and *Level Devil* paired with local competitive multiplayer.
* **Platform:** Android (Primary APK, package `com.itsd85.<teamname>.trapdash`) / iOS & Desktop compatible.
* **Engine & Framework:** Flutter + Flame Engine (BSD/MIT Open-Source Stack).
* **Display & Orientation:** Fixed Landscape (`1280x720` logical viewport, locked to `DeviceOrientation.landscapeLeft` / `landscapeRight` with `SystemUiMode.immersiveSticky`).
* **Visual Aesthetic:** *Level Devil*-inspired high-contrast minimalist monotone palette (`AppPalette`: yellow chamber background `#FFE478`, solid brown walls `#B8693D`, dark brown accents `#8A4824`, black player silhouette `#080402`, warning red `#FF1744`).

---

## 2. Technical Stack & Dependencies

| Area | Technology / Dependency | Purpose |
| :--- | :--- | :--- |
| **Framework** | `flutter` (SDK `^3.13.5`) | UI overlays, arcade navigation transitions, application lifecycle |
| **Game Engine** | `flame` (`^1.22.0`) | Game loop, room-panning camera, collision detection, 2D kinematics |
| **Tilemaps** | `flame_tiled` (`^1.21.0`) | Loading Tiled `.tmx` maps (`Level01.tmx`–`Level05.tmx`) with programmatic fallback |
| **Local Storage** | `shared_preferences` (`^2.3.3`) | Persistence of `unlocked_level`, `best_stars`, `audio_muted`, `high_contrast_tells`, `ai_bot_enabled`, `player_nickname` |
| **Audio** | `flame_audio` (`^2.10.6`) | Menu BGM (`bgm.mp3`) and pooled low-latency SFX (`.wav`) |
| **Networking** | Dart `dart:io` (`HttpServer`, `WebSocket`) | 2–5 player local Wi-Fi / hotspot real-time score & progress sync (`MatchTransport` / `LocalWsTransport`) |
| **Fonts** | `PressStart2P`, `AtkinsonHyperlegible` | Accessible arcade UI typography ($\ge 28\text{ px}$ body text equivalent) |

---

## 3. Project Directory Structure & Conventions

AI agents working in this repository must maintain the following file and module layout:

```text
trap_dash_arena/
├── android/                                # Android manifest (INTERNET & ACCESS_NETWORK_STATE permissions)
├── assets/
│   ├── audio/                              # jsfxr SFX (.wav) and chiptune menu BGM (bgm.mp3)
│   ├── fonts/                              # OFL typography (Press Start 2P, Atkinson Hyperlegible)
│   ├── game/                               # Level Devil monotone sprites (player, door, obstacle, sew, spring, coin, button, bomb, teleport, hud, icon)
│   ├── images/                             # Kenney Pixel Platformer sprites & LibreSprite tiles
│   └── tiles/                              # Tiled map files (Level01.tmx .. Level05.tmx)
├── docs/
│   ├── GDD.md                              # One-page Game Design Document (Checkpoint 1)
│   ├── tda_prd.md                          # Comprehensive Product Requirements Document
│   ├── CREDITS.md                          # Open-source and CC0 asset attributions
│   └── playtest/                           # Anonymized T1..T5 test forms & observation sheets
├── lib/
│   ├── main.dart                           # Entry point: landscape lock, devMode flag, Flame & async audio init
│   ├── autoload/                           # Global singletons / state managers (Godot Autoload equivalent)
│   │   ├── audio_manager.dart              # Singleton: BGM lifecycle, AudioPool SFX, NoopAudioBackend for tests
│   │   ├── game_state.dart                 # Singleton: level unlocks, star ratings, settings, SharedPreferences persistence
│   │   ├── match_transport.dart            # Abstract transport interface for multiplayer session testing
│   │   ├── net_manager.dart                # Singleton: 2-5 player WebSocket host/join (port 7777), scoreboard adjudication
│   │   └── palette.dart                    # Centralized AppPalette color constants
│   ├── game/
│   │   ├── trap_dash_game.dart             # FlameGame root: 1280x720 fixed camera, room panning, trauma shake, overlays
│   │   ├── chamber_loader.dart             # Tiled .tmx loader with cached maps & deterministic programmatic builders
│   │   ├── level_config.dart               # Static metadata (goalText, timeLimit, initialHearts, roomCount) for Levels 1-5
│   │   ├── level_controller.dart           # Level loop: timer, hearts, live scoring, star calculation, win/lose adjudication
│   │   ├── simple_ai.dart                  # Offline Pace-Bot ghost rival runner & simulated score counter
│   │   └── actors/                         # Flame game components
│   │       ├── chamber_background.dart     # Enclosed room & tunnel yellow backdrop renderer
│   │       ├── checkpoint_flag.dart        # Mid-stage respawn flag (+100 pts once per checkpoint)
│   │       ├── control_inverter_zone.dart  # Deceptive zone flipping horizontal input (normal <-> inverted)
│   │       ├── disappearing_platform.dart  # Timed blinking platform hazard
│   │       ├── exit_portal.dart            # Level exit door trigger (supports fake-first teleport bait)
│   │       ├── fake_floor.dart             # Crumbling floor tile component (0.30s shake before drop)
│   │       ├── falling_block.dart          # Dropping ceiling spike/bomb block component
│   │       ├── ground_block.dart           # Solid chamber wall/floor geometry & AABB collision resolver
│   │       ├── hint_arrow.dart             # Visual directional signpost component
│   │       ├── moving_gap_floor.dart       # Dynamic floor gap (chase mode & anti-second-guessing hesitation mode)
│   │       ├── moving_saw.dart             # Patrol sawblade hazard component
│   │       ├── pickup_item.dart            # Collectible coin/key component (+50 pts)
│   │       ├── player.dart                 # Player PositionComponent with asymmetric gravity, coyote/buffer, shard death cycle
│   │       ├── player_shard_effect.dart    # Disintegration & checkpoint reintegration particle burst effect
│   │       ├── portal_gauntlet_controller.dart # Level 4 Room 3 5-step binary portal gauntlet & wrong-choice traps
│   │       ├── reverse_spring.dart         # Deceptive backward-launching spring trap
│   │       ├── sudden_gap.dart             # Proximity-triggered instant floor opening trap
│   │       ├── trap_spike.dart             # Multi-behavior spike hazard (stationary, pop-up, slide, rise, remote, oscillate)
│   │       └── warp_portal.dart            # Teleport portal (supports betrayal spikes, multi-pass shifts, and fleeing)
│   └── ui/                                 # Flutter screens & Flame HUD overlays
│       ├── credits_screen.dart             # Open-source asset credits screen
│       ├── game_screen.dart                # GameWidget host registering Hud, TouchControls, Respawn, Pause, Result overlays
│       ├── hud_overlay.dart                # Top bezel HUD: Pause/Restart, Hearts/Dev toggle, Room squares, Goal banner, Timer, Score
│       ├── level_select_screen.dart        # 5-level selection grid with padlocks and 1-3 star indicators
│       ├── lobby_screen.dart               # Host/Join UI, IP copy, 2-5 player lobby list, 5s timeout error modal
│       ├── main_menu_screen.dart           # Play, Settings, Credits navigation
│       ├── mode_select_screen.dart         # Play Offline vs. Play Online selection
│       ├── pause_overlay.dart              # Resume, Restart, Audio mute toggle, Quit to Menu
│       ├── respawn_overlay.dart            # Mid-attempt death modal ("YOU DIED", remaining hearts, tap/Space to respawn)
│       ├── result_screen.dart              # Win/Lose banner, stars, score breakdown, online leaderboard, Retry/Next/Menu
│       ├── settings_screen.dart            # Sound mute, High-Contrast Trap Tells, Offline AI Bot toggle, Nickname, Reset
│       ├── title_screen.dart               # Title logo, animated background, "Tap to Start"
│       ├── touch_controls_overlay.dart     # Wireframe Left/Right chevron pads and Jump pentagon pad
│       └── widgets/                        # Reusable arcade UI components
│           ├── arcade_dialog.dart
│           ├── arcade_page_route.dart
│           ├── hazard_background.dart
│           ├── hud_sprite.dart
│           ├── square_back_button.dart
│           ├── square_toggle.dart
│           └── vertical_flip_ticker.dart
├── test/                                   # 21 unit and widget test suites (autoload, game physics/levels, UI flows)
└── pubspec.yaml                            # Flutter dependencies and asset registrations
```

---

## 4. Core Game Mechanics & Design Rules

### 4.1 "Fair Rage" System (Playtest Compliance)
To prevent frustrating trial-and-error traps while maintaining comedic *Level Devil* / *Trap Adventure* surprise:
1. **Heart Pool, Shard Death Cycle & Checkpoint Respawn:**
   * Each level attempt grants $3\text{ to }5$ Hearts and includes $1\text{ to }2$ Checkpoints (`CheckpointFlag`).
   * Hitting a hazard or falling below pit depth ($y > 732$) triggers a $0.40\text{s}$ shard disintegration burst (`PlayerShardEffect`), trauma screen-shake, `hurt.wav`, and deducts $1$ Heart (unless `devMode` is enabled).
   * If Hearts remain ($> 0$), `RespawnOverlay` appears (`"YOU DIED"`). Tapping `RESPAWN` (or pressing `Space`/`Enter`/`R`) resets all chamber traps to their initial state and reintegrates the player at `lastCheckpointPosition` over $0.38\text{s}$ with $0.5\text{s}$ spawn invulnerability.
   * Failed attempts (`endLevel(false)`) only occur when Hearts hit $0$ or the level timer expires ($t_{\text{left}} \le 0.0\text{s}$).
2. **Deceptive Hazards & Telegraphs ("Tells"):**
   * **Sudden & Moving Floor Gaps (`SuddenGap`, `MovingGapFloor`):** Floors open on approach (`SuddenGap`), chase the runner horizontally (`MovingGapMode.chase`), or creep forward and snap under the player if they hesitate or retreat (`MovingGapMode.hesitation`).
   * **Multi-Behavior Spikes (`TrapSpike`):** Supports 7 distinct behaviors: `stationary`, `proximityPopUp` (jitters before thrusting up), `slideRightOnJump` (slides forward to catch airborne jumpers), `riseOnProximity` (launches upward to punish jumping), `doubleSlideTrap` (boomerang slide right then left), `remotePopUp` (ambush spike triggered from afar), and `oscillateTwice`.
   * **Control Inverter Zones (`ControlInverterZone`):** Invisible or grounded trigger zones that flip horizontal controls (`controlsInverted`). When inverted, an overhead directional arrow indicator renders above the player's head.
   * **Deceptive Warp Portals (`WarpPortal`, `PortalGauntletController`):** Portals that arm spikes on previous pillars, shift position mid-jump, flee across platforms, or test the player across a 5-step binary portal gauntlet (`safePattern: [left, right, right, left, right]`).
   * **Classic Gauntlet Hazards (`FakeFloor`, `FallingBlock`, `MovingSaw`, `DisappearingPlatform`, `ReverseSpring`):** Crumbling tiles ($0.30\text{s}$ shake before falling), ceiling drop blocks, patrol saws, blinking platforms, and backward-flinging springs.
   * **Accessibility Toggle:** In `SettingsScreen`, players can enable **High-Contrast Trap Tells** (`GameState.instance.highContrastTells`) to render `AppPalette.warningRed` outlines and edges on deceptive traps.

### 4.2 Touch & Keyboard Controls
* **Left Thumb Safe Zone (`TouchControlsOverlay`):** Dual wireframe chevron pads (`Move Left`, `Move Right`), $148\times124\text{ px}$ hit target ($148\times62\text{ px}$ visual polygon).
* **Right Thumb Safe Zone (`TouchControlsOverlay`):** Wireframe upward pentagon `Jump` pad, $156\times128\text{ px}$ hit target ($156\times68\text{ px}$ visual polygon).
* **Keyboard Controls (`TrapDashGame.onKeyEvent`):** `A`/`D` or `ArrowLeft`/`ArrowRight` to move, `W`/`ArrowUp`/`Space` to jump, `Escape` to toggle pause, `Space`/`Enter`/`R` to respawn, and `F1` (or tapping the HUD hearts row) to toggle `devMode`.
* **Kinematic Feel & Buffers (`Player`):**
  * Horizontal speed: `240.0 px/s`; Jump velocity: `-659.0 px/s` (fixed jump height; `cutJump()` preserves upward velocity).
  * Asymmetric gravity: `1938.0 px/s²` rising, `3488.0 px/s²` falling (clamped at `750.0 px/s` max fall speed).
  * Buffers: $0.10\text{s}$ **coyote time** and $0.10\text{s}$ **jump buffering** (also buffers jump input during the final $0.10\text{s}$ of checkpoint reintegration).

---

## 5. Level Specifications & Progression Curve

Levels 1–4 are multi-room enclosed dungeon chambers (`roomCount: 3`, each room $1280\text{ px}$ wide connected by passage tunnels with checkpoints, smooth exponential camera panning). Level 5 is a single-room high-density master gauntlet (`roomCount: 1`). `ChamberLoader` loads `assets/tiles/Level01.tmx`–`Level05.tmx` and falls back to deterministic programmatic chamber builders (`_buildLevel1`–`_buildLevel5`).

| Level | Rooms | Explicit HUD Goal Text (`LevelConfig`) | Core Mechanics & Deceptive Hazards | Time Limit / Life Pool |
| :--- | :---: | :--- | :--- | :--- |
| **Level 1** | $3$ | `"Cross 3 Platforms & Reach the Exit in 90s"` | **Deceptive Floor Gaps:** `SuddenGap` openings, `MovingGapFloor` (`chase` & `hesitation` modes), 2 passage `CheckpointFlag`s. | $90\text{s}$ / $5$ Hearts |
| **Level 2** | $3$ | `"Outsmart the Deceptive Spikes & Exit in 75s"` | **Multi-Behavior Spikes:** Stationary spikes, chasing & hesitation floor gaps, `TrapSpike` (`slideRightOnJump`, `proximityPopUp`, `riseOnProximity`, `doubleSlideTrap`), 2 checkpoints. | $75\text{s}$ / $5$ Hearts |
| **Level 3** | $3$ | `"Survive Inverted Controls & Exit in 70s"` | **Control Inversion & Ambushes:** `ControlInverterZone` (walk & grounded triggers), `SuddenGap` islands, rear-ambush `remotePopUp` spikes, 4-step inverted staircase, plateau hesitation gap, 2 checkpoints. | $70\text{s}$ / $4$ Hearts |
| **Level 4** | $3$ | `"Master the Deceptive Warps & Exit in 60s"` | **Betrayal Warps & Portal Gauntlet:** Slender pillars with spike-arming `WarpPortal`s, multi-pass shifting bridge warp, fleeing upper warp, Room 3 5-step `PortalGauntletController`, 2 checkpoints. | $60\text{s}$ / $3$ Hearts |
| **Level 5** | $1$ | `"Conquer the Master Gauntlet in 60s"` | **Master Gauntlet:** Combines `ReverseSpring`, `FakeFloor`, `FallingBlock`, `MovingSaw`, `DisappearingPlatform`, bonus `PickupItem` coins, 1 mid checkpoint. | $60\text{s}$ / $3$ Hearts |

### 5.1 Progression & Star Rating Rules
* **Unlock Rule:** Level 1 is unlocked by default (`unlockedLevel = 1`). Level $n+1$ stays locked until Level $n$ is cleared in Offline Mode (`GameState.instance.isUnlocked(level)` also returns `true` when `devMode` is enabled).
* **Star Calculation Formula (`LevelController.calculateStars`):**
  * **3 Stars:** Cleared with $t_{\text{left}} > 0.50 \times t_{\text{limit}}$ **AND** $H_{\text{left}} \ge \min(3, \text{initialHearts} - 1)$.
  * **2 Stars:** Cleared with $t_{\text{left}} > 0.25 \times t_{\text{limit}}$ **OR** $H_{\text{left}} \ge 2$.
  * **1 Star:** Cleared under any other valid win condition.

---

## 6. Game State & Persistence (`GameState`)

Implemented as a singleton in `lib/autoload/game_state.dart`, managing level unlocks, star ratings, user settings (`highContrastTells`, `aiBotEnabled`, `playerNickname`), and `devMode`.

For the **IEEE Paper Listing 1 ($\le 20\text{ lines}$)** requirement, the core persistence logic reduces to:

```dart
class GameState {
  static final GameState instance = GameState._();
  GameState._();

  static const int totalLevels = 5;
  int unlockedLevel = 1;
  Map<int, int> bestStars = {};
  int currentLevel = 1;
  String mode = 'offline'; // 'offline' or 'online'
  Map<String, dynamic> lastResult = {};

  bool isUnlocked(int level) => level <= unlockedLevel;

  Future<void> completeLevel(int level, int stars) async {
    bestStars[level] = stars > (bestStars[level] ?? 0) ? stars : (bestStars[level] ?? 0);
    if (level == unlockedLevel && level < totalLevels) unlockedLevel = level + 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('unlocked_level', unlockedLevel);
    await prefs.setString('best_stars', jsonEncode(bestStars.map((k, v) => MapEntry('$k', v))));
  }
}
```

> **Note on `kDevMode` (`lib/main.dart`):** `const bool kDevMode = true;` initializes `GameState.instance.devMode` at startup (can be toggled live via `F1` or tapping the HUD hearts row). Set `kDevMode = false` for standard progression locking and timer/heart enforcement.

---

## 7. Multiplayer & Networking Architecture (`NetManager`)

### 7.1 Architecture & Scope
* **Player Capacity:** $2\text{ to }5$ players ($1\text{ Host} + \text{up to } 4\text{ Guests}$, `NetManager.maxClients = 4`).
* **Protocol & Port:** Dart `HttpServer` + `WebSocket` on port `7777` via `MatchTransport` / `LocalWsTransport`.
* **Sync Strategy:** Event-driven score race; no frame-by-frame physics replication. Each client runs their stage locally and transmits score changes immediately (and normalized progress at up to $4\text{ Hz}$ when changed by $\ge 1\%$).

### 7.2 Deterministic Score Formula (`LevelController`)
$$\text{Score} = \max\big(0,\, (C \times 100) + (K \times 50) + (B \times 25) - (D \times 25)\big) + E_{\text{bonus}}$$
* $C$: Checkpoints reached ($+100\text{ pts}$ each, once per checkpoint ID).
* $K$: Coins/Keys collected ($+50\text{ pts}$ each).
* $B$: Traps baited/survived without damage ($+25\text{ pts}$ each, once per `trapId`).
* $D$: Trap deaths / respawns ($-25\text{ pts}$ penalty applied to `_baseScore`, floored at $0$).
* $E_{\text{bonus}}$: Portal exit bonus $= 300 + (\lceil t_{\text{left}} \rceil \times 10)$ upon clearing the exit door.

### 7.3 Network Protocol & Event Payloads
Lightweight JSON messages exchanged over WebSocket:
* `join_lobby`: Guest sends nickname upon connecting:
  ```json
  {"type": "join_lobby", "nickname": "GuestA"}
  ```
* `lobby_state`: Host broadcasts connected player map and selected level:
  ```json
  {"type": "lobby_state", "level": 1, "players": {"1": "HostName", "2": "GuestA"}}
  ```
* `start_match`: Host broadcasts level, seed, and players:
  ```json
  {"type": "start_match", "level": 1, "seed": 948271, "players": {"1": "HostName", "2": "GuestA"}}
  ```
* `score_event`: Client/Host reports score and normalized progress ($0.0\text{--}1.0$):
  ```json
  {"type": "score_event", "playerId": "2", "score": 250, "progress": 0.65}
  ```
* `player_finished`: Client reports completion or elimination:
  ```json
  {"type": "player_finished", "playerId": "2", "score": 850, "won": true}
  ```
* `announce_winner`: Host adjudicates and broadcasts final winner and sorted scoreboard once all active players finish:
  ```json
  {"type": "announce_winner", "winnerId": "1", "scoreboard": [{"id": "1", "name": "HostName", "score": 850}]}
  ```
* `peer_disconnected`: Broadcast when a player drops.

### 7.4 Critical Error Handling (Requirement R8)
* **5-Second Connection Timeout:** `WebSocket.connect('ws://$host:$port').timeout(const Duration(seconds: 5))`
* **Graceful Failure:** Any network exception or timeout throws `SocketException` with the exact user-facing message (`NetManager.errorWifiMessage`):
  `"Cannot reach host. Check that you are on the same Wi-Fi."`
* **Safe Fallback:** `LobbyScreen` catches the error, displays an `ArcadeDialog` modal with the message, and never crashes or freezes.

---

## 8. Offline & AI Mode Specifications

* **Airplane Mode Compliance:** Offline solo mode (`GameState.instance.mode == 'offline'`) runs $100\%$ locally with zero network calls.
* **SimpleAI Pace-Bot Ghost (`lib/game/simple_ai.dart`):** Optional offline rival toggled in `SettingsScreen` (`GameState.instance.aiBotEnabled`). Spawns a translucent ghost runner silhouette (`BOT` badge) that advances toward `exitX` and increments its simulated score (`+35 pts` and `+5%` progress per step) at level-scaled intervals:
  $$\text{Interval delay} = \max(0.8,\, 3.0 - 0.4 \times (\text{level} - 1))$$

---

## 9. Lab Requirements Mapping (ITSD 85 Compliance)

| Requirement ID | Requirement Summary | Implementation & Verification Criteria |
| :--- | :--- | :--- |
| **R1** | $\ge 5$ distinct levels with increasing difficulty | Levels 1–5 in `assets/tiles/Level01.tmx`–`Level05.tmx` & `ChamberLoader` (`_buildLevel1`–`_buildLevel5`): progresses from 3-room gap chambers (90s/5H) $\rightarrow$ deceptive spikes (75s/5H) $\rightarrow$ inverted controls (70s/4H) $\rightarrow$ warp portals & 5-step gauntlet (60s/3H) $\rightarrow$ master hazard gauntlet (60s/3H). |
| **R2** | Clear goal text displayed on HUD per level | Prominent top-center banner in `HudOverlay` displaying `controller.config.goalText` alongside room progression indicator squares. |
| **R3** | Win/Lose conditions with Result screen | `LevelController.endLevel(bool won)` pauses engine and shows `ResultOverlay` (`ResultScreen`) with $0\text{--}3$ stars, score/time/hearts breakdown, `RETRY`, `NEXT` (win only on Levels 1–4), and `MENU`. |
| **R4** | Level unlocking ($n+1$ locked until $n$ cleared) | `GameState.isUnlocked(level)` checks `level <= unlockedLevel`; `LevelSelectScreen` renders padlock icons and disables locked level tiles. |
| **R5** | Persistence survives closing application | `GameState.completeLevel()` persists `unlocked_level` & JSON-encoded `best_stars` via `SharedPreferences` (plus settings in `GameState.init()`). |
| **R6** | Offline mode in Airplane Mode | Fully functional in Airplane Mode with zero network dependencies; includes toggleable `SimpleAI` ghost runner & live HUD `BOT` score counter. |
| **R7** | Real-time 2–5 player multiplayer | `NetManager` & `LocalWsTransport` Host/Join on port `7777` (`maxClients = 4`), live HUD leaderboard in `HudOverlay`, Host adjudicates winner (`announce_winner`) and renders final standings in `ResultOverlay`. |
| **R8** | Mode select & connection error handling | `ModeSelectScreen` (`Play Offline` / `Play Online`); 5s timeout in `LocalWsTransport.joinSession` displays `"Cannot reach host. Check that you are on the same Wi-Fi."` via `ArcadeDialog`. |
| **R9** | Touch controls, fixed orientation on real phone | Fixed landscape (`1280x720`), multi-touch `Listener` pads in `TouchControlsOverlay` (`148x124` Left/Right, `156x128` Jump), Android APK build. |
| **R10** | Polish: title, pause, sound toggle, font size | `TitleScreen`, `PauseOverlay` (`pauseEngine()`/`resumeEngine()`), `RespawnOverlay`, `AudioManager` persisted mute toggle, accessible typography, `CREDITS.md` & `CreditsScreen`. |
| **Bonus** | Stars, hints, a11y, player nicknames | $1\text{--}3$ star formula (`calculateStars`), `HintArrow` component & overhead inverted-control tell, `highContrastTells` warning outlines, custom `playerNickname` in `SettingsScreen`/`LobbyScreen`. |

---

## 10. Developer Guidelines & Agent Rules

### 10.1 Coding Principles
1. **Separation of Concerns:** Keep Flutter UI (`lib/ui/`) strictly separate from Flame Game logic (`lib/game/`). Use Flame's overlay system (`game.overlays.add/remove`) to display HUD, touch controls, respawn prompts, pause menus, and results.
2. **Deterministic Mechanics:** All trap triggers, speeds, and timers must be frame-rate independent using Flame's `dt` (delta time).
3. **No Network Crashes:** Always wrap network I/O in `try/catch` and enforce strict connection timeouts (`5s`).
4. **Data Privacy:** Never hardcode or commit personal tester information. In playtest documents and code, identify testers strictly as `T1`, `T2`, `T3`, `T4`, `T5` (RA 10173 compliance).

### 10.2 Build & Verification Commands

```powershell
# Fetch dependencies
flutter pub get

# Run static analysis
dart analyze

# Run unit and widget tests
flutter test

# Run game on connected device/emulator
flutter run

# Build release Android APK
flutter build apk --release
```
