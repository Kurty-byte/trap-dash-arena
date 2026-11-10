# Product Requirements Document (PRD): Trap Dash Arena
**Course:** ITSD 85 – Special Topics in Software Development  
**Project Type:** Mobile Game with Level Progression and Offline/Online Multiplayer  
**Target Platform:** Android (Primary APK) / iOS & Desktop (Compatible)  
**Engine & Stack:** Flutter + Flame Engine (BSD/MIT Open-Source Stack)  
**Orientation & Resolution:** Fixed Landscape ($1280\times720$ logical viewport)

---

## 1. Executive Summary & One-Page GDD (Phase 1 / Checkpoint 1 Ready)

> *Note: Subsections 1.1 through 1.11 directly mirror `docs/GDD.md` and reflect the final implemented architecture of Trap Dash Arena.*

### 1.1 Pitch
*Trap Dash Arena* is a deceptive 2D precision action-platformer inspired by *Level Devil* and *Trap Adventure 2* where players navigate five increasingly treacherous trap-filled dungeons—either solo offline or in a frantic $2\text{--}5$ player local Wi-Fi score-rush—to reach the exit portal before their time or lives run out.

### 1.2 Genre and Target Players
* **Genre:** 2D Deceptive Trap Platformer / Competitive Score-Rush Arcade.
* **Target Players:** Ages $15\text{--}25$; casual-to-midcore mobile gamers who enjoy the humor and surprise of *Trap Adventure 2* and *Level Devil*, paired with bite-sized competitive multiplayer races with classmates.

### 1.3 Core Mechanic & Touch Controls
* **Core Loop (Every $2\text{--}4$ Seconds):** The player runs across enclosed chambers, jumps over sudden or moving floor gaps, baits deceptive environmental traps (multi-behavior spikes, control inverter zones, betrayal warp portals, crumbling floors, ceiling drops, patrol saws), triggers mid-stage checkpoints, and enters the exit portal.
* **Touch Controls (`TouchControlsOverlay`, Fixed Landscape):**
  * **Left Thumb:** Dual on-screen wireframe chevron pads (`Move Left`, `Move Right`) positioned in the bottom-left safe zone, hit target $148\times124\text{ px}$ ($\ge 120\times120\text{ px}$ requirement).
  * **Right Thumb:** Large wireframe pentagon `Jump` pad in the bottom-right safe zone, hit target $156\times128\text{ px}$, paired with $0.10\text{s}$ coyote time, $0.10\text{s}$ jump buffering, and asymmetric rise/fall gravity.

### 1.4 Goal, Win Condition, and Lose Condition
* **Level Goal:** Explicitly displayed on the top-center `HudOverlay` banner throughout each level alongside room progression indicator squares.
* **Win Condition:** Touch the `ExitPortal` hitbox while $t_{\text{left}} > 0$ and $\text{Hearts} \ge 1$ (and required keys collected). Triggers the `Player.enterDoor` animation and `ResultOverlay` (`ResultScreen`), awards $1\text{--}3$ stars, unlocks level $n+1$ in Offline Mode, and saves to device storage via `SharedPreferences`.
* **Lose Condition (Offline):** Either $\text{Hearts} = 0$ or $t_{\text{left}} \le 0.0\text{s}$. Triggers `ResultOverlay` (`"TRY AGAIN"`) with `RETRY` and `MENU` buttons (`NEXT` is hidden).
* **Win/Lose Condition (Online $2\text{--}5$ Players):** All players compete on the same selected level simultaneously. Clients stream live `score_event` and `player_finished` payloads; when all active players finish or are eliminated, the Host device adjudicates the winner with the highest deterministic score and broadcasts `announce_winner`.

### 1.5 Level Plan (Difficulty Curve)

Levels $1\text{--}4$ are 3-room enclosed dungeon chambers ($3 \times 1280\text{ px}$ wide with smooth exponential room-by-room camera panning and passage checkpoints). Level $5$ is a 1-room high-density master gauntlet. `ChamberLoader` loads Tiled `.tmx` maps (`Level01.tmx`–`Level05.tmx`) with deterministic programmatic chamber fallbacks (`_buildLevel1`–`_buildLevel5`).

| Level No. | Rooms | Explicit HUD Goal Text (`LevelConfig`) | What is New or Harder (Mechanics & Traps) | Time / Life Limit |
| :--- | :---: | :--- | :--- | :--- |
| **Level 1** | $3$ | *"Cross 3 Platforms & Reach the Exit in 90s"* | **Deceptive Floor Gaps:** Introduces `SuddenGap` floor openings, `MovingGapFloor` (`chase` mode & anti-second-guessing `hesitation` mode), and $2$ passage `CheckpointFlag`s. | $90\text{s}$ / $5$ Hearts |
| **Level 2** | $3$ | *"Outsmart the Deceptive Spikes & Exit in 75s"* | **Multi-Behavior Spikes:** Introduces `TrapSpike` variants (`stationary`, `slideRightOnJump`, `proximityPopUp`, `riseOnProximity`, `doubleSlideTrap`) paired with chasing and hesitation floor gaps and $2$ checkpoints. | $75\text{s}$ / $5$ Hearts |
| **Level 3** | $3$ | *"Survive Inverted Controls & Exit in 70s"* | **Control Inversion & Ambushes:** Introduces `ControlInverterZone` (walk & grounded triggers with overhead arrow indicator), `SuddenGap` islands, rear-ambush `remotePopUp` spikes, a 4-step inverted staircase, and a plateau hesitation gap. | $70\text{s}$ / $4$ Hearts |
| **Level 4** | $3$ | *"Master the Deceptive Warps & Exit in 60s"* | **Betrayal Warps & Portal Gauntlet:** Slender pillars with spike-arming `WarpPortal`s, multi-pass shifting bridge warp, fleeing upper warp, and Room 3's 5-step binary `PortalGauntletController` (`[left, right, right, left, right]`). | $60\text{s}$ / $3$ Hearts |
| **Level 5** | $1$ | *"Conquer the Master Gauntlet in 60s"* | **Master Gauntlet:** High-density chamber combining `ReverseSpring`, `FakeFloor` ($0.30\text{s}$ crumble shake), `FallingBlock` ceiling drops, `MovingSaw` blades, `DisappearingPlatform`, bonus `PickupItem` coins, and $1$ mid checkpoint. | $60\text{s}$ / $3$ Hearts |

### 1.6 Unlocking and Star Rating Rules
* **Level Unlocking Rule:** Level $1$ is unlocked by default. Level $n+1$ remains locked (displaying a padlock icon and disabled button state in `LevelSelectScreen`) until Level $n$ is cleared in Offline Mode.
* **Star Calculation Formula (`LevelController.calculateStars`):** Upon clearing a level, stars ($1\text{--}3$) are awarded using remaining time ($t_{\text{left}}$ relative to $t_{\text{limit}}$) and remaining hearts ($H_{\text{left}}$):
  * **$3$ Stars:** Cleared with $t_{\text{left}} > 0.50 \times t_{\text{limit}}$ AND $H_{\text{left}} \ge \min(3, \text{initialHearts} - 1)$.
  * **$2$ Stars:** Cleared with $t_{\text{left}} > 0.25 \times t_{\text{limit}}$ OR $H_{\text{left}} \ge 2$.
  * **$1$ Star:** Level cleared under any other valid condition.

### 1.7 Offline Mode
* **Primary Mode (Solo Campaign):** Playable $100\%$ in Airplane Mode with zero network calls. Players progress through Levels $1\text{--}5$, earning stars and unlocking stages locally.
* **Bonus Offline AI Option (`SimpleAI` Pace-Bot Ghost):** Players can toggle **Offline AI Rival Bot** in `SettingsScreen`, spawning a translucent ghost runner (`BOT` badge) that traverses the chamber and increments its score (`+35 pts` per step) at level-scaled intervals ($\text{delay} = \max(0.8, 3.0 - 0.4 \times (\text{level} - 1))$).

### 1.8 Online Mode ($2\text{--}5$ Player Score-Based Competition)
* **Match Type:** Real-time competitive score-rush across $2\text{ to }5$ devices over local Wi-Fi/Hotspot (`LocalWsTransport` / `NetManager` on port `7777`).
* **How Competition Works:** Every player runs the chosen level simultaneously on their own screen. Players compete on a live **Match Scoreboard** rendered in `HudOverlay`:
  * Reaching a Checkpoint: $+100\text{ pts}$
  * Collecting a Coin/Key: $+50\text{ pts}$
  * Triggering/Surviving a Trap Bait: $+25\text{ pts}$
  * Dying to a Trap or Pit (Respawns at last checkpoint): $-25\text{ pts}$ (base score floored at $0$)
  * Reaching the Exit Portal: $+300\text{ pts} + (\lceil t_{\text{left}} \rceil \times 10\text{ pts})$
* **Network Payload Sent:** Lightweight JSON event packets (`join_lobby`, `lobby_state`, `start_match`, `score_event`, `player_finished`, `announce_winner`, `peer_disconnected`). Online matches do not overwrite offline level unlocks.

### 1.9 Screens & Overlays List
1. `TitleScreen` (Game logo, hazard background, `"TAP ANYWHERE TO START"`)
2. `MainMenuScreen` (`PLAY`, `SETTINGS`, `CREDITS`)
3. `ModeSelectScreen` (`PLAY OFFLINE`, `PLAY ONLINE`, back button)
4. `LevelSelectScreen` (5-level grid with padlock icons, $1\text{--}3$ star indicators, back button)
5. `LobbyScreen` (Player nickname display, `HOST GAME` showing local IP + one-tap copy, IP input + `JOIN GAME` with $5\text{s}$ timeout, connected player list for $2\text{--}5$ players, Host level selector & `START MATCH` button)
6. `GameScreen` + `HudOverlay` + `TouchControlsOverlay` (Flame `GameWidget` canvas + top bezel HUD for Pause/Restart, Hearts/Dev toggle, Room progress squares, Goal text banner, Pace-Bot score, Timer, Score, and live Online Scoreboard)
7. `RespawnOverlay` (`"YOU DIED"` modal showing remaining hearts and `RESPAWN` button / `Space` prompt)
8. `PauseOverlay` (`RESUME`, `RESTART`, `SOUND: ON/OFF` toggle, `QUIT TO MENU`)
9. `ResultOverlay` (`ResultScreen`: Win/Lose banner, animated Star rating, Score/Time/Hearts breakdown, Online Leaderboard table, `RETRY` / `NEXT` / `MENU` buttons)
10. `SettingsScreen` & `CreditsScreen` (Sound Mute toggle, High-Contrast Trap Tells toggle, Offline AI Bot toggle, Player Nickname editor, Reset Progress confirmation, and full CC0/Open-Source asset attribution)

### 1.10 Art and Sound Style + Asset Sources and Licenses
* **Visual Style:** *Level Devil*-inspired minimalist monotone palette (`AppPalette`: `#FFE478` chamber yellow, `#B8693D` solid brown walls, `#080402` black player silhouette, `#FF1744` high-contrast warning red) so traps and player hitboxes are unmistakable on mobile screens.
* **Asset Sources & Licenses (100% Free & Open Source):**
  * **Graphics:** Minimalist monotone sprites (`assets/game/`), HUD icons by Thomas / Mewily (`mewily.itch.io`), *Kenney.nl Pixel Platformer Pack* (CC0 1.0 Universal), and custom sprites created in *LibreSprite* (GPLv2).
  * **Audio:** Retro sound effects (`jump.wav`, `trap_trigger.wav`, `hurt.wav`, `win.wav`, `unlock.wav`) generated in *jsfxr* (CC0); background chiptune music (`bgm.mp3`) from *OpenGameArt.org* (CC0 / CC-BY, credited in `docs/CREDITS.md`).
  * **Typography:** *Press Start 2P* and *Atkinson Hyperlegible* (SIL Open Font License).

### 1.11 Risks and Mitigations
* **Risk 1 (Playtest Frustration):** Unforgiving traps could cause playtesters to take $>4$ formal attempts on early levels.
  * *Mitigation:* Give players $3\text{--}5$ Hearts and $2$ mid-level checkpoints per attempt (`RespawnOverlay`), plus visual/audio tells and a High-Contrast Trap Tells accessibility toggle.
* **Risk 2 (Multiplayer Desync with 2–5 Players):** Syncing $5$ physics bodies at $60\text{ FPS}$ over mobile hotspot can lag.
  * *Mitigation:* Sync discrete score events (`score_event`), normalized horizontal progress ($0.0\text{--}1.0$), and finish notifications (`player_finished`) rather than frame-by-frame physics bodies.

---

## 2. Lab Requirements Mapping (ITSD 85 Compliance)

This matrix maps every mandatory requirement (`R1`–`R10`), bonus item, and rubric criterion from the **ITSD 85 Lab Manual** to its exact design and technical implementation in *Trap Dash Arena*.

| Lab Req ID | Lab Requirement Description | How *Trap Dash Arena* Complies (Flutter + Flame Implementation) | Acceptance / Verification Method |
| :--- | :--- | :--- | :--- |
| **R1** | At least $5$ levels, each harder or different from the last (more enemies, less time, new mechanic, bigger map). | $5$ distinct Tiled maps (`Level01.tmx`–`Level05.tmx`) and programmatic builders (`_buildLevel1`–`_buildLevel5` in `ChamberLoader`). Progression introduces new trap classes per stage (Sudden/Moving Floor Gaps $\rightarrow$ Multi-Behavior Spikes $\rightarrow$ Control Inverter Zones $\rightarrow$ Betrayal Warp Portals & 5-Step Gauntlet $\rightarrow$ Combined Master Gauntlet) while shrinking the timer from $90\text{s}$ to $60\text{s}$ and Hearts from $5$ to $3$. | Instructor plays Levels $1\text{--}3$ live; demo video and unit tests (`level1_dungeon_test.dart`–`level4_dungeon_test.dart`) verify chamber progression. |
| **R2** | Clear goal per level shown to the player (e.g., *"Collect 10 stars in 60 seconds"*). | `HudOverlay` displays a prominent top-center banner throughout gameplay reading `controller.config.goalText` (e.g., *"Cross 3 Platforms & Reach the Exit in 90s"*) beneath room progression indicator squares. | Goal text visibly rendered on the HUD as soon as any level starts. |
| **R3** | Win and lose conditions with a result screen (stars, score or time) and Retry / Next / Menu buttons. | `LevelController.endLevel(bool won)` pauses the engine and shows `ResultOverlay` (`ResultScreen`). Displays `"LEVEL CLEARED!"` or `"TRY AGAIN"`, $0\text{--}3$ stars, score/time/hearts breakdown, and `RETRY`, `NEXT` (shown only on win for Levels $1\text{--}4$), and `MENU` buttons. | Lose all hearts on a trap to show Lose Result screen; clear the stage to show Win Result screen and `NEXT` button. |
| **R4** | Level unlocking: level $n+1$ stays locked until level $n$ is cleared. | `GameState.isUnlocked(level)` checks `level <= unlockedLevel`. In `LevelSelectScreen`, levels $> \text{unlockedLevel}$ render a padlock icon and disable tap navigation (`onTap: null`). | Open `LevelSelectScreen` with `kDevMode = false`: Level $1$ is open, Levels $2\text{--}5$ show lock icons and cannot be started. |
| **R5** | Progress is saved on the device and survives closing the app. | `GameState.completeLevel()` persists `unlocked_level` and JSON-encoded `best_stars` immediately to device flash storage via Flutter's `SharedPreferences`. | Clear Level $1$, force-close the app from Android Recents, reopen: Level $2$ remains unlocked with saved stars. |
| **R6** | Offline mode playable in airplane mode (solo, versus computer, or two players on one device). | Selecting `PLAY OFFLINE` sets `GameState.mode = 'offline'` and loads local assets and `SharedPreferences` with zero network dependencies. Includes both Solo Campaign and optional `SimpleAI` Pace-Bot ghost runner mode. | Enable Airplane Mode on the phone, play Offline Mode, clear a level, verify saving and zero network errors. |
| **R7** | Online mode where two players on two devices play the same match in real time or turn by turn. | Supports **$2\text{ to }5$ players** in a real-time score-based match via `NetManager` and `LocalWsTransport` (`HttpServer` + `WebSocket` on port `7777`, `maxClients = 4`). Host broadcasts level and seed; clients stream live `score_event` updates; Host adjudicates the winner (`announce_winner`). | Connect $2\text{--}5$ phones on the same Wi-Fi/hotspot, run a full match, and verify live HUD leaderboard updates and unified winner screen. |
| **R8** | Mode selection on the main menu (Offline/Online) and a clear message when the online server cannot be reached. | `ModeSelectScreen` presents `PLAY OFFLINE` and `PLAY ONLINE` buttons. `NetManager.joinGame()` enforces a $5\text{-second}$ connection timeout and `try/catch` socket handler; if Wi-Fi is off or host IP is unreachable, `LobbyScreen` displays an `ArcadeDialog` with `"Cannot reach host. Check that you are on the same Wi-Fi."` and stays responsive. | Turn off Wi-Fi, tap `PLAY ONLINE` $\rightarrow$ `JOIN`: game displays the exact error modal with zero crash or freeze. |
| **R9** | Runs on a real phone (Android APK or iOS build), in one fixed orientation, with touch controls. | Built as a native Android APK, locked to `DeviceOrientation.landscapeLeft` / `landscapeRight` ($1280\times720$), with multi-touch `Listener` wireframe pads in `TouchControlsOverlay` for Left ($148\times124$), Right ($148\times124$), and Jump ($156\times128$). | Installed and verified on physical Android phones. |
| **R10** | Basic polish: title screen, pause menu, sound on/off option, readable text on small screens. | Full screen flow implemented; in-level `PauseOverlay` pauses the Flame engine (`game.pauseEngine()`); global audio mute saved in `SharedPreferences` via `AudioManager`; accessible typography; Android system back gesture handled via `PopScope`; `CREDITS.md` and `CreditsScreen` included. | Verified across UI flow tests (`screens_flow_test.dart`, `enclosed_overlays_test.dart`). |
| **Bonus** | Star ratings ($1\text{--}3$), tutorial hints, accessibility options, player names/leaderboard. | Includes $1\text{--}3$ star calculation, `HintArrow` component & overhead inverted-control arrow tell, **High-Contrast Trap Tells** accessibility toggle (`highContrastTells`), and custom player nicknames on the $2\text{--}5$ player scoreboard. | Up to $+10$ bonus points on the Lab Work Rubric. |

---

## 3. Detailed Functional Specifications

### 3.1 Trap Mechanics & The "Fair Rage Game" System (Playtest Optimization)
To capture the hilarious surprise of *Level Devil* and *Trap Adventure 2* while guaranteeing fair completion rates on **Playtest Statement 4** (*"Each level felt a little harder than the last, but fair"*):
1. **Heart Pool, Shard Death Cycle & Checkpoint Respawn:**
   * Each level attempt grants the player $3\text{ to }5$ **Hearts** and features $1\text{ to }2$ **Checkpoints** (`CheckpointFlag`).
   * When a trap or pit claims the player, `Player.takeDamage()` triggers a $0.40\text{s}$ shard disintegration burst (`PlayerShardEffect`), trauma camera shake, and `hurt.wav`, deducting $1$ Heart (`-25 pts`).
   * While Hearts $> 0$, `RespawnOverlay` prompts the player to respawn. Confirming respawn resets chamber hazards to their initial state and reintegrates the player at `lastCheckpointPosition` over $0.38\text{s}$ with $0.5\text{s}$ invulnerability.
   * A formal "Failed Attempt" (`endLevel(false)`) only occurs if all Hearts are depleted or the timer reaches $0.0\text{s}$.
2. **Deceptive Hazard Classes & Telegraphs:**
   * **Sudden & Moving Floor Gaps (`SuddenGap`, `MovingGapFloor`):** Floors split open on proximity, chase the runner horizontally (`MovingGapMode.chase`), or creep forward and snap beneath the player if they hesitate or retreat (`MovingGapMode.hesitation`).
   * **Multi-Behavior Spikes (`TrapSpike`):** Supports `stationary`, `proximityPopUp` (jitters before thrusting upward), `slideRightOnJump`, `riseOnProximity`, `doubleSlideTrap`, `remotePopUp`, and `oscillateTwice`.
   * **Control Inverter Zones (`ControlInverterZone`):** Flips horizontal movement direction (`controlsInverted`) and displays an overhead arrow visual cue above the player.
   * **Deceptive Warp Portals (`WarpPortal`, `PortalGauntletController`):** Portals that arm spikes on prior pillars, shift mid-jump, flee across platforms, or challenge the player to a 5-step binary portal gauntlet.
   * **Classic Gauntlet Hazards (`FakeFloor`, `FallingBlock`, `MovingSaw`, `DisappearingPlatform`, `ReverseSpring`):** Crumbling floor slabs ($0.30\text{s}$ shake), ceiling drop blocks, patrol saws, blinking platforms, and reverse springs.
   * **High-Contrast Trap Tells (`SettingsScreen`):** Renders `AppPalette.warningRed` outlines/edges on deceptive floor gaps, fake floors, and spikes.

### 3.2 Scoring System Specification ($2\text{--}5$ Player Online & Offline Score)
Every action updates the player's match score in `LevelController` according to the deterministic formula:

$$\text{Score} = \max\big(0,\, (C \times 100) + (K \times 50) + (B \times 25) - (D \times 25)\big) + E_{\text{bonus}}$$

Where:
* $C =$ Number of Checkpoints activated ($+100\text{ pts}$ each, one-time per checkpoint ID).
* $K =$ Number of Coins/Keys collected ($+50\text{ pts}$ each).
* $B =$ Number of Traps successfully baited/survived without taking damage ($+25\text{ pts}$ each, one-time per `trapId`).
* $D =$ Number of Trap/Pit Deaths ($-25\text{ pts}$ penalty per hit, base score floored at $0$).
* $E_{\text{bonus}} = 300 + (\lceil t_{\text{left}} \rceil \times 10)$ awarded upon entering the `ExitPortal`.

**Match End Rules in $2\text{--}5$ Player Mode (`NetManager`):**
* **Host Authority:** Clients never declare themselves the winner. Clients send `score_event` and `player_finished` JSON payloads to the Host.
* **Winner Adjudication:** Once all connected players in `NetManager.players` have reported `player_finished` (either by clearing the exit portal or losing all hearts/time), the Host sorts the scoreboard descending by score, selects `winnerId`, and broadcasts `announce_winner` to all peers.

### 3.3 Screen Flow & Navigation Architecture
* `TitleScreen` $\rightarrow$ `MainMenuScreen` $\rightarrow$ (`SettingsScreen` | `CreditsScreen` | `ModeSelectScreen`).
* **Offline Branch:** `ModeSelectScreen` $\rightarrow$ `LevelSelectScreen` (Locked levels show padlock icon) $\rightarrow$ `GameScreen (Level n)` $\rightarrow$ `Cleared?`
  * If **Yes**: `Unlock level n+1 & save stars/progress` $\rightarrow$ `ResultOverlay (RETRY, NEXT, MENU)`.
  * If **No**: `ResultOverlay (RETRY, MENU; NEXT hidden)`.
* **Online Branch:** `ModeSelectScreen` $\rightarrow$ `LobbyScreen (Host or Join by IP)` $\rightarrow$ `Connected?`
  * If **Yes** ($2\text{--}5$ players ready): Host taps `START MATCH` $\rightarrow$ `GameScreen` (Live scores synced via `NetManager`) $\rightarrow$ `ResultOverlay` (Host broadcasts `announce_winner` & final leaderboard).
  * If **No** ($5\text{s}$ Timeout / Wi-Fi off / Host unreachable): `ArcadeDialog` error modal (`"Cannot reach host. Check that you are on the same Wi-Fi."`), returning safely to `LobbyScreen`.

---

## 4. Technical Architecture (Flutter + Flame Implementation)

### 4.1 Project Directory Structure

```text
trap_dash_arena/
├── android/                                # Android manifest with INTERNET & ACCESS_NETWORK_STATE
├── assets/
│   ├── audio/                              # BGM (bgm.mp3) and SFX (.wav)
│   ├── fonts/                              # OFL fonts (Press Start 2P, Atkinson Hyperlegible)
│   ├── game/                               # Level Devil monotone sprites & HUD sheet
│   ├── images/                             # Pixel platformer sprites & tiles
│   └── tiles/                              # Level01.tmx .. Level05.tmx (Tiled map files)
├── docs/
│   ├── GDD.md                              # One-page Game Design Document
│   ├── tda_prd.md                          # This Product Requirements Document
│   ├── CREDITS.md                          # Asset attributions & licenses
│   └── playtest/                           # Anonymized T1..T5 forms & observation sheets
├── lib/
│   ├── main.dart                           # App entry, landscape lock, devMode flag, Flame/Audio init
│   ├── autoload/                           # Global singletons
│   │   ├── audio_manager.dart              # Singleton: BGM lifecycle, AudioPool SFX, mute persistence
│   │   ├── game_state.dart                 # Singleton: save/load progress, stars, unlocked_level, settings
│   │   ├── match_transport.dart            # Transport abstraction for WebSocket multiplayer
│   │   ├── net_manager.dart                # Singleton: 2-5 player WebSocket Host/Join (port 7777)
│   │   └── palette.dart                    # AppPalette color constants
│   ├── game/
│   │   ├── trap_dash_game.dart             # FlameGame root class (camera, collision, level loader)
│   │   ├── chamber_loader.dart             # Tiled .tmx loader & programmatic level builders
│   │   ├── level_config.dart               # Level 1-5 configuration metadata
│   │   ├── level_controller.dart           # Timer, hearts, score, star formula, endLevel adjudication
│   │   ├── simple_ai.dart                  # Offline Pace-Bot ghost rival runner
│   │   └── actors/                         # 19 Flame actor & trap components
│   └── ui/                                 # 13 Flutter screens/overlays + 7 custom arcade widgets
├── test/                                   # 21 unit and widget test files
└── pubspec.yaml
```

### 4.2 Core Persistence Implementation (`lib/autoload/game_state.dart`)
The IEEE Paper guidelines require including **Listing 1: save/unlock code ($\le 20\text{ lines}$)** that satisfies **R4/R5**:

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

### 4.3 $2\text{--}5$ Player Networking Architecture (`lib/autoload/net_manager.dart`)
* **Port & Capacity:** Uses `defaultPort = 7777` and `maxClients = 4` ($1\text{ Host} + \text{up to } 4\text{ Guests} = 5\text{ Players}$).
* **Lobby & Match Flow (`LobbyScreen` & `NetManager`):**
  1. Host taps **HOST GAME**: binds `HttpServer.bind(InternetAddress.anyIPv4, 7777)` upgraded via `WebSocketTransformer`. Displays the Host's local IPv4 address (with one-tap clipboard copy) and a live list of connected players ($1/5 \dots 5/5$).
  2. Guests enter the Host IP and tap **JOIN GAME**.
  3. **5-Second Timeout (Requirement R8):** `WebSocket.connect('ws://$host:$port').timeout(const Duration(seconds: 5))` catches any timeout or socket exception and throws `SocketException('Cannot reach host. Check that you are on the same Wi-Fi.')`, which `LobbyScreen` displays in a non-crashing `ArcadeDialog`.
  4. **Match Start:** Host selects a level ($1\text{--}5$) and taps **START MATCH**, broadcasting `start_match` with level, seed, and player map.
  5. **Mid-Match Disconnect Handling:** If a Guest disconnects mid-game, the Host removes them from active players, broadcasts `peer_disconnected`, and checks if all remaining active players have finished to adjudicate the winner without hanging.

---

## 5. Playtesting, QA & IEEE Paper Compliance

### 5.1 Designing for the 15-Item Playtest Form (Phase 8)
At least $5$ external testers (`T1`–`T5`, documented in `docs/playtest/README.md`) evaluated the game using the 15-item Likert scale ($1\text{--}5$), achieving an overall aggregate mean of **$M = 4.52$ ($SD = 0.46$)** with all items $\ge 4.00$:

| Likert Item # | Survey Focus | Feature Implemented in *Trap Dash Arena* |
| :--- | :--- | :--- |
| **Q1** | Clear level objective from HUD banner | Persistent top-center `HudOverlay` goal banner + room progression squares ($M = 4.80$). |
| **Q2 & Q3** | Responsive touch controls & fair ledge jumps | Wireframe `Listener` pads ($148\times124$ / $156\times128$), $0.10\text{s}$ coyote time, and $0.10\text{s}$ jump buffer ($M = 4.40\text{ / }4.60$). |
| **Q4, Q5, Q6** | Fair difficulty curve, trap telegraphs, and checkpoint respawns | $3\text{--}5$ Heart pool, $1\text{--}2$ checkpoints per stage, `RespawnOverlay`, and trap tells ($M = 4.20\text{--}4.80$). |
| **Q7** | Offline Pace-Bot rival pressure | `SimpleAI` translucent ghost runner and live `BOT` HUD counter ($M = 4.20$). |
| **Q8, Q9, Q10** | Smooth local Wi-Fi multiplayer, score sync, and clear error modals | Port `7777` WebSocket sync, one-tap IP copy, and 5s timeout `ArcadeDialog` ($M = 4.40\text{--}4.60$). |
| **Q11, Q12, Q13** | High-contrast trap tells, readable typography, and monotone aesthetic | `highContrastTells` warning outlines, *Press Start 2P* / *Atkinson Hyperlegible*, and *Level Devil* palette ($M = 4.40\text{--}5.00$). |

### 5.2 Ethics & Data Privacy Compliance
* In full compliance with the **Philippine Data Privacy Act of 2012 (RA 10173)**, no tester names, faces, or phone numbers are stored in the repository; testers are logged strictly as `T1`, `T2`, `T3`, `T4`, `T5` in `docs/playtest/README.md`.
