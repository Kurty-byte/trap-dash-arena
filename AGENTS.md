# AGENTS.md — Development & Architecture Guide for AI Agents

## 1. Project Overview & Identity
* **Project Name:** Trap Dash Arena
* **Course:** ITSD 85 – Special Topics in Software Development
* **Genre:** 2D Deceptive Trap Platformer / Competitive Score-Rush Arcade
* **Target Audience:** Ages 15–25; mobile gamers who enjoy *Trap Adventure 2* and *Level Devil* paired with local competitive multiplayer.
* **Platform:** Android (Primary APK, package `com.itsd85.<teamname>.trapdash`) / iOS compatible.
* **Engine & Framework:** Flutter + Flame Engine (BSD/MIT Open-Source Stack).
* **Display & Orientation:** Fixed Landscape (`1280x720` logical viewport, locked to `DeviceOrientation.landscapeLeft` / `landscapeRight`).

---

## 2. Technical Stack & Dependencies

| Area | Technology / Dependency | Purpose |
| :--- | :--- | :--- |
| **Framework** | `flutter` | UI overlays, menus, application lifecycle |
| **Game Engine** | `flame` | Game loop, camera, component lifecycle, 2D physics |
| **Tilemaps** | `flame_tiled` | Loading Tiled `.tmx` maps (`Level01.tmx` to `Level05.tmx`) |
| **Local Storage** | `shared_preferences` | Persistence of `unlocked_level` and `best_stars` |
| **Audio** | `flame_audio` / `audioplayers` | Background music loops (`.ogg`) and sound effects (`.wav`) |
| **Networking** | Dart `dart:io` (`HttpServer`, `WebSocket`) | 2–5 player local Wi-Fi / hotspot real-time score sync |
| **Fonts** | Press Start 2P, Atkinson Hyperlegible | Accessible UI typography ($\ge 28\text{ px}$ equivalent) |

---

## 3. Project Directory Structure & Conventions

AI agents working in this repository must maintain the following file and module layout:

```text
trap_dash_arena/
├── android/                        # Android manifest (INTERNET & ACCESS_NETWORK_STATE permissions)
├── assets/
│   ├── audio/                      # jsfxr SFX (.wav) and OpenGameArt BGM (.ogg)
│   ├── fonts/                      # OFL typography (Press Start 2P, Atkinson Hyperlegible)
│   ├── images/                     # Kenney Pixel Platformer sprites, LibreSprite tiles, icons
│   └── tiles/                      # Tiled map files (Level01.tmx .. Level05.tmx)
├── docs/
│   ├── GDD.md                      # One-page Game Design Document (Checkpoint 1)
│   ├── tda_prd.md                  # Comprehensive Product Requirements Document
│   ├── CREDITS.md                  # Open-source and CC0 asset attributions
│   ├── paper.pdf                   # IEEE 2-column research paper
│   ├── playtest/                   # Anonymized T1..T5 test forms & observation sheets
│   └── screenshots/                # Device screenshots of all screens
├── lib/
│   ├── main.dart                   # Entry point: landscape lock, Flame & audio initialization
│   ├── autoload/                   # Global singletons / state managers (Godot Autoload equivalent)
│   │   ├── audio_manager.dart      # Singleton: BGM loops, SFX triggering, mute persistence
│   │   ├── game_state.dart         # Singleton: level unlocks, star ratings, local persistence
│   │   └── net_manager.dart        # Singleton: 2-5 player WebSocket host/join, payload dispatch
│   ├── game/
│   │   ├── trap_dash_game.dart     # FlameGame root: camera, component registry, viewport scaling
│   │   ├── level_controller.dart   # Level loop: timer, live scoring, win/lose adjudication
│   │   ├── simple_ai.dart          # Offline Pace-Bot ghost counter
│   │   └── actors/                 # Flame game components
│   │       ├── exit_portal.dart    # Level exit trigger
│   │       ├── fake_floor.dart     # Crumbling floor tile component
│   │       ├── falling_block.dart  # Dropping ceiling hazard component
│   │       ├── moving_saw.dart     # Patrol sawblade hazard component
│   │       ├── player.dart         # Player PositionComponent with platformer physics
│   │       └── trap_spike.dart     # Proximity pop-up spike component
│   └── ui/                         # Flutter widgets & HUD overlays
│       ├── credits_screen.dart     # Open-source asset credits screen
│       ├── level_select_screen.dart# 3-column grid, locked padlocks, star indicators
│       ├── lobby_screen.dart       # Host/Join UI, IP entry, 2-5 player lobby list
│       ├── main_menu_screen.dart   # Play, Settings, Credits navigation
│       ├── mode_select_screen.dart # Play Offline vs. Play Online
│       ├── pause_overlay.dart      # Resume, Restart, Audio toggles, Quit
│       ├── result_screen.dart      # Win/Lose banner, stars, score breakdown, Retry/Next/Menu
│       ├── settings_screen.dart    # Audio toggles, high-contrast trap tells toggle
│       └── title_screen.dart       # Title logo, "Tap to Start"
├── test/                           # Unit and widget test suite
└── pubspec.yaml                    # Flutter dependencies and asset registrations
```

---

## 4. Core Game Mechanics & Design Rules

### 4.1 "Fair Rage" System (Playtest Compliance)
To prevent frustrating trial-and-error traps while maintaining comedic surprise:
1. **Heart Pool & Checkpoint Respawn:**
   * Each level attempt grants $3\text{ to }5$ Hearts and includes $1\text{ to }2$ Checkpoints.
   * Hitting a trap triggers screen-shake, plays `hurt.wav`, deducts $1$ Heart, leaves the trap visibly revealed, and respawns the player at the last activated Checkpoint.
   * Failed attempts (`endLevel(false)`) only occur when Hearts hit $0$ or the level timer expires ($t_{\text{left}} \le 0.0\text{s}$).
2. **Subtle Visual & Audio Telegraphs ("Tells"):**
   * **Crumbling Floors (`FakeFloor`):** Hairline $2\text{-pixel}$ crack texture; emits dust particles for $0.30\text{s}$ before falling.
   * **Hidden Pop-Up Spikes (`TrapSpike`):** Tips poke $2\text{ px}$ above ground; jitters for $0.25\text{s}$ upon player entering $48\text{ px}$ radius before thrusting upward.
   * **Dropping Ceilings (`FallingBlock`):** Slightly discolored brick tint; triggers on passing lower sensor line.
   * **Accessibility Toggle:** In `SettingsScreen`, players can enable "High-Contrast Trap Tells" to increase visibility of telegraphs.

### 4.2 Touch Controls
* **Left Thumb Safe Zone:** Two touch buttons (`Move Left`, `Move Right`), minimum $120\times120\text{ px}$ touch target ($\approx 9\text{ mm}$).
* **Right Thumb Safe Zone:** Large `Jump` button supporting variable jump height via hold duration.
* **Control Feel Buffers:** Implement $0.1\text{s}$ **coyote time** (allows jumping immediately after falling off an edge) and $0.1\text{s}$ **jump buffering** (registers early jump input before landing).

---

## 5. Level Specifications & Progression Curve

| Level | Explicit HUD Goal Text | New Mechanics & Hazards | Time Limit / Life Pool |
| :--- | :--- | :--- | :--- |
| **Level 1** | `"Reach the Exit Portal in 90s (Watch for cracked tiles!)"` | **Tutorial:** Static spikes, 2 cracked crumbling tiles, mid checkpoint, hint arrows. | $90\text{s}$ / $5$ Hearts |
| **Level 2** | `"Collect 5 Keys & Reach the Exit in 75s"` | **Pop-Up Spikes:** Proximity-triggered spikes ($0.35\text{s}$ shake), key pickups. | $75\text{s}$ / $5$ Hearts |
| **Level 3** | `"Survive the Falling Corridor & Exit in 70s"` | **Gravity Traps:** Falling ceiling blocks, fake exit portal bait. | $70\text{s}$ / $4$ Hearts |
| **Level 4** | `"Dodge the Moving Saws & Exit in 60s"` | **Dynamic Hazards:** Moving patrol saws, disappearing platforms, tighter jumps. | $60\text{s}$ / $3$ Hearts |
| **Level 5** | `"Conquer the Master Gauntlet in 60s"` | **Gauntlet:** High density combining fake floors, ceiling drops, saws, reverse springs. | $60\text{s}$ / $3$ Hearts |

### 5.1 Progression & Star Rating Rules
* **Unlock Rule:** Level 1 is unlocked by default. Level $n+1$ stays locked until Level $n$ is cleared in Offline Mode.
* **Star Calculation Formula:**
  * **3 Stars:** Cleared with $t_{\text{left}} > 0.50 \times t_{\text{limit}}$ **AND** $H_{\text{left}} \ge 3$.
  * **2 Stars:** Cleared with $t_{\text{left}} > 0.25 \times t_{\text{limit}}$ **OR** $H_{\text{left}} \ge 2$.
  * **1 Star:** Cleared under any other valid win condition.

---

## 6. Game State & Persistence (`GameState`)

Must be implemented as a singleton in `lib/autoload/game_state.dart`.  
IEEE paper requires concise implementation ($\le 20\text{ lines}$) for Listing 1:

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

---

## 7. Multiplayer & Networking Architecture (`NetManager`)

### 7.1 Architecture & Scope
* **Player Capacity:** $2\text{ to }5$ players ($1\text{ Host} + \text{up to } 4\text{ Guests}$, `MAX_CLIENTS = 4`).
* **Protocol & Port:** Dart `HttpServer` + `WebSocket` on port `7777`.
* **Sync Strategy:** Event-driven score race; no frame-by-frame physics replication. Each client runs their own stage locally and transmits milestone events.

### 7.2 Deterministic Score Formula
$$\text{Score} = (C \times 100) + (K \times 50) + (B \times 25) - (D \times 25) + E_{\text{bonus}}$$
* $C$: Checkpoints reached ($+100\text{ pts}$ each, once per checkpoint).
* $K$: Keys/Coins collected ($+50\text{ pts}$ each).
* $B$: Traps baited/survived without damage ($+25\text{ pts}$ each).
* $D$: Trap deaths / respawns ($-25\text{ pts}$ penalty, floor at $0\text{ score}$).
* $E_{\text{bonus}}$: Portal exit bonus $= 300 + (\lceil t_{\text{left}} \rceil \times 10)$.

### 7.3 Network Protocol & Event Payloads
Lightweight JSON messages exchanged over WebSocket:
* `start_match`: Host broadcasts level and seed:
  ```json
  {"type": "start_match", "level": 1, "seed": 948271, "players": {"1": "HostName", "2": "GuestA"}}
  ```
* `score_event`: Client reports delta score change:
  ```json
  {"type": "score_event", "playerId": "2", "score": 250, "progress": 0.65}
  ```
* `announce_winner`: Host broadcasts final winner and scoreboard:
  ```json
  {"type": "announce_winner", "winnerId": "1", "scoreboard": [{"id": "1", "score": 850}]}
  ```
* `peer_disconnected`: Host broadcasts when a player drops.

### 7.4 Critical Error Handling (Requirement R8)
* **5-Second Connection Timeout:** `WebSocket.connect('ws://$ip:7777').timeout(const Duration(seconds: 5))`
* **Graceful Failure:** Any network exception or timeout must display the exact user-facing message:
  `"Cannot reach host. Check that you are on the same Wi-Fi."`
* **Safe Fallback:** Never crash or freeze; dismiss the dialog and safely return the player to `ModeSelectScreen` or `LobbyScreen`.

---

## 8. Offline & AI Mode Specifications

* **Airplane Mode Compliance:** Offline solo mode must run $100\%$ with zero network access and no internet permission dependencies.
* **SimpleAI Pace-Bot Ghost:** Optional offline challenge mode running simulated opponent score:
  $$\text{Interval delay} = \max(0.8, 3.0 - 0.4 \times (\text{level} - 1))$$
  Simulates live bot score updates to race against without network connection.

---

## 9. Lab Requirements Mapping (ITSD 85 Compliance)

| Requirement ID | Requirement Summary | Verification Criteria |
| :--- | :--- | :--- |
| **R1** | $\ge 5$ distinct levels with increasing difficulty | Levels 1–5 in `assets/tiles/Level01.tmx`–`Level05.tmx` |
| **R2** | Clear goal text displayed on HUD per level | Prominent `HudOverlay` banner displaying `levelConfig.goalText` |
| **R3** | Win/Lose conditions with Result screen | Result screen with stars, score, Retry, Next (win only), Menu |
| **R4** | Level unlocking ($n+1$ locked until $n$ cleared) | Padlock icon and disabled buttons in `LevelSelectScreen` |
| **R5** | Persistence survives closing application | `SharedPreferences` saves `unlocked_level` & `best_stars` |
| **R6** | Offline mode in Airplane Mode | Fully functional in Airplane Mode; includes `SimpleAI` pace-bot |
| **R7** | Real-time 2–5 player multiplayer | Host/Join on port 7777, live scoreboard, Host adjudicates winner |
| **R8** | Mode select & connection error handling | 5s timeout modal: `"Cannot reach host. Check that you are on the same Wi-Fi."` |
| **R9** | Touch controls, fixed orientation on real phone | Fixed landscape ($1280\times720$), on-screen controls, APK build |
| **R10** | Polish: title, pause, sound toggle, font size | Pause pauses Flame engine, global mute saved, text $\ge 28\text{ px}$ |
| **Bonus** | Stars, hints, a11y, player nicknames | $1\text{--}3$ stars, Level 1 signposts, high-contrast tells, custom names |

---

## 10. Developer Guidelines & Agent Rules

### 10.1 Coding Principles
1. **Separation of Concerns:** Keep Flutter UI (`lib/ui/`) strictly separate from Flame Game logic (`lib/game/`). Use Flame's overlay system (`game.overlays.add/remove`) to display menus, pause overlays, and HUD elements.
2. **Deterministic Mechanics:** All trap triggers, speeds, and timers must be frame-rate independent using Flame's `dt` (delta time).
3. **No Network Crashes:** Always wrap network I/O in `try/catch` and enforce strict connection timeouts.
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
