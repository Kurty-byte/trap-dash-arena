# Product Requirements Document (PRD): Trap Dash Arena
**Course:** ITSD 85 – Special Topics in Software Development  
**Project Type:** Mobile Game with Level Progression and Offline/Online Multiplayer  
**Target Platform:** Android (Primary APK) / iOS (Compatible)  
**Engine & Stack:** Flutter + Flame Engine (BSD/MIT Open-Source Stack)  
**Orientation & Resolution:** Landscape ($1280\times720$ logical viewport)

---

## 1. Executive Summary & One-Page GDD (Phase 1 / Checkpoint 1 Ready)

> *Note: Subsections 1.1 through 1.11 directly mirror the mandatory `docs/GDD.md` template from Step 1.2 of the lab manual so you can copy this section directly into your repository for Week 1 approval.*

### 1.1 Pitch
*Trap Dash Arena* is a deceptive 2D precision action-platformer where players must navigate five increasingly treacherous trap-filled dungeons—either solo offline or in a frantic $2\text{--}5$ player online score-rush—to reach the exit portal before their time or lives run out.

### 1.2 Genre and Target Players
* **Genre:** 2D Deceptive Trap Platformer / Competitive Score-Rush Arcade.
* **Target Players:** Ages $15\text{--}25$; casual-to-midcore mobile gamers who enjoy the humor and surprise of *Trap Adventure 2* and *Level Devil*, paired with bite-sized competitive multiplayer races with classmates.

### 1.3 Core Mechanic & Touch Controls
* **Core Loop (Every $2\text{--}4$ Seconds):** The player runs, jumps, baits out deceptive environmental traps (hidden spikes, crumbling tiles, sudden ceiling drops), triggers mid-stage checkpoints, and collects bonus coins on the way to the exit portal.
* **Touch Controls (Fixed Landscape):**
  * **Left Thumb:** Dual on-screen directional buttons (`Move Left`, `Move Right`) positioned in the bottom-left safe zone, minimum size $120\times120\text{ px}$ ($\approx 9\text{ mm}$).
  * **Right Thumb:** Large `Jump` button (supports variable jump height based on hold duration) in the bottom-right safe zone.

### 1.4 Goal, Win Condition, and Lose Condition
* **Level Goal:** Explicitly displayed on the HUD banner at the start of each level (e.g., *"Reach the Exit Portal within $60\text{s}$ before losing all $5$ Hearts"*).
* **Win Condition:** Touch the `ExitPortal` hitbox while $t_{\text{left}} > 0$ and $\text{Hearts} \ge 1$. Triggers the Result Screen, awards $1\text{--}3$ stars, unlocks level $n+1$, and saves to device storage.
* **Lose Condition (Offline):** Either $\text{Hearts} = 0$ (after hitting traps $5$ times) or $t_{\text{left}} \le 0.0\text{s}$. Triggers the Result Screen (`Try Again`) with `Retry` and `Menu` buttons (`Next` is disabled).
* **Win/Lose Condition (Online $2\text{--}5$ Players):** All players compete on the same seeded trap stage simultaneously. The winner is the first player to reach the `Target Score` (or the player with the highest score when a player crosses the Exit Portal / the $60\text{s}$ match timer expires), adjudicated strictly by the Host device (Option A) or Nakama Server (Option B).

### 1.5 Level Plan (Difficulty Curve)

| Level No. | Explicit HUD Goal Text | What is New or Harder (Mechanics & Traps) | Time / Life Limit |
| :--- | :--- | :--- | :--- |
| **Level 1** | *"Reach the Exit Portal in $90\text{s}$ (Watch for cracked tiles!)"* | **Tutorial & Basics:** Static spikes, $2$ visibly cracked crumbling floor tiles, generous checkpoint halfway, first-time hint arrows. | $90\text{s}$ / $5$ Hearts |
| **Level 2** | *"Collect $5$ Keys & Reach the Exit in $75\text{s}$"* | **Pop-Up Spikes:** Introduces proximity-triggered floor spikes (with a $0.35\text{s}$ shake telegraph) and required key pickups. | $75\text{s}$ / $5$ Hearts |
| **Level 3** | *"Survive the Falling Corridor & Exit in $70\text{s}$"* | **Gravity Traps:** Introduces dropping ceiling blocks and a fake exit portal that jumps to the real platform when approached. | $70\text{s}$ / $4$ Hearts |
| **Level 4** | *"Dodge the Moving Saws & Exit in $60\text{s}$"* | **Dynamic Hazards:** Combines patrol sawblades, disappearing platforms, and pop-up spikes with tighter jump windows. | $60\text{s}$ / $3$ Hearts |
| **Level 5** | *"Conquer the Master Gauntlet in $60\text{s}$"* | **Full Trap Adventure Chaos:** High-density gauntlet combining fake floors, ceiling drops, moving saws, and reverse-gravity springs. | $60\text{s}$ / $3$ Hearts |

### 1.6 Unlocking and Star Rating Rules
* **Level Unlocking Rule:** Level $1$ is unlocked by default. Level $n+1$ remains locked (displaying a padlock icon and disabled button state) until Level $n$ is cleared in Offline Mode.
* **Star Calculation Formula:** Upon clearing a level, stars ($1\text{--}3$) are awarded using remaining time ($t_{\text{left}}$ relative to $t_{\text{limit}}$) and remaining hearts ($H_{\text{left}}$):
  * **$3$ Stars:** Cleared with $t_{\text{left}} > 0.50 \times t_{\text{limit}}$ AND $H_{\text{left}} \ge 3$.
  * **$2$ Stars:** Cleared with $t_{\text{left}} > 0.25 \times t_{\text{limit}}$ OR $H_{\text{left}} \ge 2$.
  * **$1$ Star:** Level cleared under any other valid condition.

### 1.7 Offline Mode
* **Primary Mode (Solo Campaign):** Playable $100\%$ in Airplane Mode with zero network calls. Players progress through Levels $1\text{--}5$, earning stars and unlocking stages locally.
* **Bonus Offline AI Option (Pace-Bot Ghost):** Players can toggle a "Race vs. AI Bot" option in Offline Mode, where a simulated AI score counter (`SimpleAI`) increments its score at level-scaled intervals ($\text{delay} = \max(0.8, 3.0 - 0.4 \times (\text{level} - 1))$), challenging the player to beat the bot's score before the level ends.

### 1.8 Online Mode ($2\text{--}5$ Player Score-Based Competition)
* **Match Type:** Real-time competitive score-rush across $2\text{ to }5$ devices over local Wi-Fi/Hotspot (Option A: Local WebSocket Host & Join) or Internet Matchmaking (Option B Bonus: Nakama Server).
* **How Competition Works:** Every player runs the chosen level simultaneously on their own screen. Instead of heavy physics collisions between players, players compete on a live **Match Scoreboard** updated in real time:
  * Reaching a Checkpoint: $+100\text{ pts}$
  * Collecting a Trap Coin: $+50\text{ pts}$
  * Triggering/Surviving a Trap Bait: $+25\text{ pts}$
  * Dying to a Trap (Respawns at last checkpoint): $-25\text{ pts}$
  * Reaching the Exit Portal: $+300\text{ pts} + (\lceil t_{\text{left}} \rceil \times 10\text{ pts})$
* **Network Payload Sent:** Lightweight JSON event packets (`start_match`, `score_event`, `player_progress_x`, `announce_winner`, `peer_disconnected`). Online matches do not overwrite offline level unlocks.

### 1.9 Screens List
1. `TitleScreen` (Game logo, "Tap to Start")
2. `MainMenuScreen` (Play, Settings, Credits)
3. `ModeSelectScreen` (Play Offline, Play Online, Back)
4. `LevelSelectScreen` (3-column grid for Levels $1\text{--}5$, lock icons, star counts, Back)
5. `LobbyScreen` (Player name input, Host Game button showing local IP, IP text field + Join Game button with $5\text{s}$ timeout, connected player list for $2\text{--}5$ players, Host "Start Match" button)
6. `GameScreen` (Flame `GameWidget` canvas + Flutter HUD overlay for Goal text, Timer, Hearts, Live Scoreboard, and Pause button)
7. `PauseMenuOverlay` (Resume, Restart, Sound On/Off toggle, Quit to Menu)
8. `ResultScreen` (Win/Lose banner, Star rating, Score breakdown, Leaderboard table for Online mode, Retry / Next / Menu buttons)
9. `SettingsScreen` & `CreditsScreen` (Sound/Music toggle, Trap Visual Cue accessibility toggle, full CC0/Open-Source asset attribution)

### 1.10 Art and Sound Style + Asset Sources and Licenses
* **Visual Style:** Clean, high-contrast 16-bit pixel art so traps and player hitboxes are unmistakable on small phone screens.
* **Asset Sources & Licenses (100% Free & Open Source):**
  * **Graphics:** *Kenney.nl Pixel Platformer Pack* (CC0 1.0 Universal) and custom sprites created in *LibreSprite* (GPLv2).
  * **Audio:** Retro sound effects (`jump.wav`, `trap_trigger.wav`, `hurt.wav`, `win.wav`, `unlock.wav`) generated in *jsfxr* (CC0); background chiptune music (`.ogg`) from *OpenGameArt.org* (CC0 / CC-BY 4.0, credited in `docs/CREDITS.md`).
  * **Typography:** *Press Start 2P* and *Atkinson Hyperlegible* via *Google Fonts* (SIL Open Font License, minimum $28\text{ px}$ body text equivalent).

### 1.11 Risks and Simpler Fallbacks
* **Risk 1 (Playtest Frustration):** *Trap Adventure 2*-style invisible traps could cause external playtesters to take $>4$ attempts on Levels $1\text{--}3$ or rate fairness $<3.5/5.0$.
  * *Mitigation/Fallback:* Give players $5$ Hearts and mid-level checkpoints per attempt, and include subtle visual tells (cracked pixels, $0.35\text{s}$ rumble before spikes pop up) in Levels $1\text{--}3$.
* **Risk 2 (Multiplayer Desync with 2–5 Players):** Syncing $5$ physics bodies at $60\text{ FPS}$ over mobile hotspot can lag.
  * *Mitigation/Fallback:* Sync only discrete score events (`score_event`) and normalized horizontal progress ($0\%\text{--}100\%$ progress bar at the top of the HUD) rather than frame-by-frame physics bodies.

---

## 2. Requirements Mapping for Lab Compliance

This matrix maps every mandatory requirement (`R1`–`R10`), bonus item, and rubric criterion from the **ITSD 85 Lab Manual** to its exact design and technical implementation in *Trap Dash Arena*.

| Lab Req ID | Lab Requirement Description | How *Trap Dash Arena* Complies (Flutter + Flame Implementation) | Acceptance / Verification Method |
| :--- | :--- | :--- | :--- |
| **R1** | At least $5$ levels, each harder or different from the last (more enemies, less time, new mechanic, bigger map). | $5$ distinct Tiled map files (`Level01.tmx` to `Level05.tmx`). Progression introduces new trap classes per stage (Crumbling Tiles $\rightarrow$ Proximity Spikes $\rightarrow$ Falling Ceilings $\rightarrow$ Moving Saws $\rightarrow$ Combined Gauntlet) while shrinking the timer from $90\text{s}$ to $60\text{s}$ and Hearts from $5$ to $3$. | Instructor plays Levels $1\text{--}3$ live; demo video showcases Levels $4\text{--}5$. |
| **R2** | Clear goal per level shown to the player (e.g., *"Collect 10 stars in 60 seconds"*). | `HudOverlay` displays a prominent top-center banner on level start and throughout gameplay reading `levelConfig.goalText` (e.g., *"Collect 5 Keys & Reach the Exit in 75s"*). | Goal text visibly rendered on the HUD as soon as any level starts. |
| **R3** | Win and lose conditions with a result screen (stars, score or time) and Retry / Next / Menu buttons. | `endLevel(bool won)` transitions to `ResultScreen`. Shows `"Level Cleared!"` or `"Try Again"`, $0\text{--}3$ animated stars, final score/time, and `Retry`, `Next` (disabled on loss or Level $5$), and `Menu` buttons. | Purposefully lose all hearts on a trap to show Lose Result screen; clear the stage to show Win Result screen and `Next` button. |
| **R4** | Level unlocking: level $n+1$ stays locked until level $n$ is cleared. | `GameState.isUnlocked(level)` checks `level <= unlockedLevel`. In `LevelSelectScreen`, levels $> \text{unlockedLevel}$ render a padlock icon and set `onPressed: null` (disabled). | Open `LevelSelectScreen` on fresh install: Level $1$ is open, Levels $2\text{--}5$ show lock icons and cannot be tapped. |
| **R5** | Progress is saved on the device and survives closing the app. | `GameState.completeLevel()` persists `unlocked_level` and `best_stars` immediately to device flash storage via Flutter's `SharedPreferences` (`user://` equivalent). | Clear Level $2$, force-close the app from Android Recents, reopen: Level $3$ remains unlocked with saved stars. |
| **R6** | Offline mode playable in airplane mode (solo, versus computer, or two players on one device). | Selecting `Play Offline` sets `GameState.mode = "offline"` and loads local assets and `SharedPreferences` with zero network dependencies. Includes both Solo Campaign and optional `SimpleAI` Pace-Bot mode (for maximum rubric credit). | Enable Airplane Mode on the phone, play Offline Mode, clear a level, verify saving and zero network errors. |
| **R7** | Online mode where two players on two devices play the same match in real time or turn by turn. | Supports **$2\text{ to }5$ players** in a real-time score-based match. Option A uses Dart's `HttpServer` + `WebSocket` on port `7777` (`MAX_CLIENTS = 4`). Host broadcasts level number and random seed; clients send live score events; Host decides the winner. | Connect $2$ (up to $5$) phones on the same Wi-Fi/hotspot, run a full match, and verify live score updates and unified winner screen. |
| **R8** | Mode selection on the main menu (Offline/Online) and a clear message when the online server cannot be reached. | `ModeSelectScreen` presents large `Play Offline` and `Play Online` buttons. `NetManager.joinGame()` uses a $5\text{-second}$ connection timeout and `try/catch` socket handler; if Wi-Fi is off or host IP is unreachable, an error dialog displays `"Cannot reach host. Check that you are on the same Wi-Fi."` and returns safely to Lobby/Mode Select. | Turn off Wi-Fi, tap `Play Online` $\rightarrow$ `Join`: game displays the friendly error modal with zero crash or freeze. |
| **R9** | Runs on a real phone (Android APK or iOS build), in one fixed orientation, with touch controls. | Built as a native Android APK (`com.itsd85.<teamname>.trapdash`), locked to `DeviceOrientation.landscapeLeft` / `landscapeRight` ($1280\times720$), with multi-touch `Listener` buttons for Left, Right, and Jump. | Installed on $2+$ physical Android phones; documented in the Phase 7 Phone Test Matrix. |
| **R10** | Basic polish: title screen, pause menu, sound on/off option, readable text on small screens. | Full screen flow implemented; in-level `PauseMenuOverlay` pauses the Flame engine (`game.pauseEngine()`); global audio mute saved in `GameState`; fonts $\ge 28\text{ px}$ equivalent; Android system back gesture handled via `PopScope`; `CREDITS.md` and in-game Credits screen included. | Verified against the Phase 6 & Demo checklist. |
| **Bonus** | Star ratings ($1\text{--}3$), tutorial hints, accessibility options, player names/leaderboard, Option B (Nakama). | Includes $1\text{--}3$ star calculation, Level $1$ tutorial signposts, "High-Contrast Trap Tells" accessibility toggle, custom player nicknames on the $2\text{--}5$ player scoreboard, and modular `NakamaService` support. | Up to $+10$ bonus points on the Lab Work Rubric. |

---

## 3. Detailed Functional Specifications

### 3.1 Trap Mechanics & The "Fair Rage Game" System (Playtest Optimization)
In classic *Trap Adventure 2*, a single touch of a hidden spike causes an instant Game Over, requiring $20+$ attempts per room. However, **Phase 8 (Step 8.4)** of your lab manual states that *"a level cleared by fewer than $60\%$ of players, or needing more than $4$ attempts on average, is probably too hard — unless it is the final level"*.

To capture the hilarious surprise of *Trap Adventure 2* while guaranteeing high scores on **Playtest Statement 4** (*"Each level felt a little harder than the last, but fair"*):
1. **Heart & Checkpoint System (Within a Single Attempt):**
   * Each level attempt grants the player $3\text{ to }5$ **Hearts** and features $1\text{ to }2$ **Checkpoints**.
   * When a trap surprises the player, a comedic screen-shake and death sound play, the player loses $1$ Heart, the triggered trap remains visibly revealed, and the player immediately respawns at their last Checkpoint.
   * A formal "Failed Attempt" (`endLevel(false)`) only occurs if all Hearts are depleted or the timer reaches $0.0\text{s}$. This allows playtesters to fall for $3\text{ or }4$ hilarious traps and still clear Levels $1\text{--}3$ on their $1\text{st}$ or $2\text{nd}$ formal attempt!
2. **Subtle Visual Telegraphing ("Tells"):**
   * **Crumbling Fake Floors:** Have a $2\text{-pixel}$ hairline crack texture and emit dust particles for $0.30\text{s}$ when stepped on before falling.
   * **Hidden Pop-Up Spikes:** Display tiny pixel tips poking $2\text{ px}$ out of the floor and jitter briefly ($0.25\text{s}$) when the player enters a $48\text{ px}$ trigger radius before thrusting upward.
   * **Falling Ceiling Blocks:** Slightly discolored brick tint; triggers when the player crosses the warning sensor line below, giving players enough speed to dash past or bait and step back.

### 3.2 Scoring System Specification ($2\text{--}5$ Player Online & Offline Score)
To make the $2\text{--}5$ player competitive mode exciting, every action updates the player's match score according to the following deterministic formula:

$$\text{Score} = (C \times 100) + (K \times 50) + (B \times 25) - (D \times 25) + E_{\text{bonus}}$$

Where:
* $C =$ Number of Checkpoints activated ($+100\text{ pts}$ each, one-time per checkpoint).
* $K =$ Number of Coins/Keys collected ($+50\text{ pts}$ each).
* $B =$ Number of Traps successfully baited/triggered without taking damage ($+25\text{ pts}$ each).
* $D =$ Number of Trap Deaths/Respawns ($-25\text{ pts}$ penalty per hit, floor at $0\text{ total score}$).
* $E_{\text{bonus}} = 300 + (\lceil t_{\text{left}} \rceil \times 10)$ awarded upon touching the `ExitPortal`.

**Match End Rules in $2\text{--}5$ Player Mode:**
* **Target Score / Portal Rush:** When the first player reaches the `ExitPortal` (or hits `targetScore`), the Host triggers a $10\text{-second}$ sudden-death countdown for remaining players to finish, or immediately ends the match if all players have either finished or depleted their hearts.
* **Host Authority:** Clients never declare themselves the winner. Clients send `@rpc`-equivalent JSON event messages (`report_score`) to the Host. The Host updates `scores[playerId]`, broadcasts the updated scoreboard to all $2\text{--}5$ phones, and emits `announce_winner` when the match concludes.

### 3.3 Screen Flow & Navigation Architecture
The application strictly implements the state machine diagram from **Page 6** of the lab manual:
* `TitleScreen` $\rightarrow$ `MainMenuScreen` $\rightarrow$ (`SettingsScreen` | `CreditsScreen` | `ModeSelectScreen`).
* **Offline Branch:** `ModeSelectScreen` $\rightarrow$ `LevelSelectScreen` (Locked levels show padlock icon) $\rightarrow$ `GameScreen (Level n)` $\rightarrow$ `Cleared?`
  * If **Yes**: `Unlock level n+1 & save stars/progress` $\rightarrow$ `ResultScreen (Retry, Next, Menu)`.
  * If **No**: Straight to `ResultScreen (Retry, Menu; Next disabled)`.
* **Online Branch:** `ModeSelectScreen` $\rightarrow$ `LobbyScreen (Host or Join by IP / Nakama)` $\rightarrow$ `Connected?`
  * If **Yes** ($2\text{--}5$ players ready): `Online Match (Moves/ progress & scores sent live)` $\rightarrow$ `Online Result (Host or server picks the winner)`.
  * If **No** (Timeout / Wi-Fi off / Host disconnected): `Connection Error Modal (Clear message, return safely to Mode Select / Lobby)`.

---

## 4. Technical Architecture (Flutter + Flame Equivalents to Lab Code)

### 4.1 Project Directory Structure
Mapped directly from Phase 2 (Page 9) of the lab manual into standard Flutter conventions:

```text
trap_dash_arena/
├── android/                        # Android manifest with INTERNET & ACCESS_NETWORK_STATE
├── assets/
│   ├── images/                     # Spritesheets, trap tiles, padlock icon, UI buttons
│   ├── audio/                      # BGM (.ogg) and SFX (.wav)
│   ├── tiles/                      # Level01.tmx .. Level05.tmx (Tiled map files)
│   └── fonts/                      # OFL fonts
├── docs/
│   ├── GDD.md                      # One-page Game Design Document (Checkpoint 1)
│   ├── PRD.md                      # This Product Requirements Document
│   ├── CREDITS.md                  # Asset attributions & licenses (Checkpoint 6)
│   ├── paper.pdf                   # IEEE 2-column research paper (Final submission)
│   ├── screenshots/                # Phone screenshots of all screens
│   └── playtest/                   # Anonymized T1..Tn forms & observation sheets
├── lib/
│   ├── main.dart                   # App entry, landscape lock, global Flame/Audio init
│   ├── autoload/                   # Equivalent to Godot Autoloads
│   │   ├── game_state.dart         # Singleton: save/load progress, stars, unlocked_level
│   │   ├── net_manager.dart        # Singleton: 2-5 player WebSocket Host/Join & Nakama
│   │   └── audio_manager.dart      # Singleton: BGM loop & SFX mute persistence
│   ├── game/
│   │   ├── trap_dash_game.dart     # FlameGame root class (camera, collision, level loader)
│   │   ├── level_controller.dart   # Equivalent to Level.gd (timer, score, end_level)
│   │   ├── simple_ai.dart          # Equivalent to SimpleAI.gd for offline vs. AI mode
│   │   └── actors/
│   │       ├── player.dart         # PositionComponent + hitbox + platformer physics
│   │       ├── trap_spike.dart     # Proximity pop-up spike component
│   │       ├── fake_floor.dart     # Crumbling tile component
│   │       ├── falling_block.dart  # Ceiling drop trap component
│   │       ├── moving_saw.dart     # Patrol hazard component
│   │       └── exit_portal.dart    # Goal trigger component
│   └── ui/
│       ├── title_screen.dart
│       ├── main_menu_screen.dart
│       ├── mode_select_screen.dart
│       ├── level_select_screen.dart
│       ├── lobby_screen.dart
│       ├── result_screen.dart
│       ├── pause_overlay.dart
│       └── credits_screen.dart
└── pubspec.yaml
```

### 4.2 Core Persistence Implementation (`lib/autoload/game_state.dart`)
The IEEE Paper guidelines (Section IV, Page 33) require including **Listing 1: save/unlock code ($\le 20\text{ lines}$)**. Below is the clean Dart equivalent of `GameState.gd` that satisfies both **R4/R5** and the paper listing requirement:

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
To upgrade the lab manual's 2-player `Net.gd` script to support **$2\text{ to }5$ players** while meeting all **R7/R8** error-handling checks:
* **Port & Capacity:** Uses `const int PORT = 7777` and `const int MAX_CLIENTS = 4` ($1\text{ Host} + \text{up to } 4\text{ Guests} = 5\text{ Players}$).
* **Lobby Flow (`LobbyScreen`):**
  1. Host taps **Host Game**: binds `HttpServer.bind(InternetAddress.anyIPv4, 7777)` upgraded via `WebSocketTransformer`. Displays the Host's local Wi-Fi IP (`192.168.x.x` or `10.x.x.x` or `172.x.x.x`) and a live list of connected players ($1/5 \dots 5/5$).
  2. Guests enter their nickname, type the Host IP, and tap **Join Game**.
  3. **5-Second Timeout (Requirement R8):** `WebSocket.connect('ws://$ip:7777').timeout(const Duration(seconds: 5))` catches any timeout, socket exception, or airplane-mode state and immediately invokes `_fail("Cannot reach host. Check that you are on the same Wi-Fi.")`, displaying a non-crashing modal and returning cleanly.
  4. **Match Start:** Once $\ge 1$ Guest is connected ($2\text{--}5$ players total), the Host's **Start Match** button unlocks. Tapping it broadcasts:
     ```json
     {"type": "start_match", "level": 1, "seed": 948271, "players": {"1": "HostName", "2": "GuestA", "3": "GuestB"}}
     ```
  5. **Mid-Match Disconnect Handling:** If any Guest disconnects mid-game, the Host removes them from active runners and notifies remaining players; if only $1$ player remains or the Host disconnects, all phones catch `onDone`/`onError`, end the match safely, and return to `ModeSelectScreen` with `"The host/other players left the game."`

---

## 5. Playtesting, QA & IEEE Paper Compliance Strategy

### 5.1 Designing for the 15-Item Playtest Form (Phase 8)
In Week 5, at least $5$ external testers will evaluate your game using the 15-item Likert scale ($1\text{--}5$). Any item scoring $< 3.5$ is graded as a problem area. Our PRD specifically targets the most vulnerable items:

| Likert Item # | Statement from Lab Manual | PRD Feature Built to Guarantee Score $\ge 4.0$ |
| :--- | :--- | :--- |
| **Item 2** | *"I understood the goal of each level without help."* | Animated goal banner at the start of every stage + visual arrow pointing to keys/exit in Level $1$. |
| **Item 3** | *"The touch controls were easy and responsive."* | Fixed $120\times120\text{ px}$ buttons with visual press feedback, $0.1\text{s}$ coyote time (allows jumping just after leaving a ledge), and $0.1\text{s}$ jump buffering. |
| **Item 4** | *"Each level felt a little harder than the last, but fair."* | $5\text{-Heart}$ life pool + mid-stage checkpoints + subtle visual/audio trap tells in Levels $1\text{--}3$ so players never feel cheated. |
| **Item 8 & 9** | *"Joining an online match was easy"* & *"The online match felt responsive."* | Clear IP display on Host screen, 1-tap Join, and event-driven score synchronization (zero rubber-banding or movement lag). |
| **Item 12** | *"Text and buttons were easy to read and tap."* | Minimum $28\text{ px}$ body text, high-contrast UI panels, and safe-area padding away from camera notches. |

### 5.2 Ethics & Data Privacy Compliance
* All playtest participants will sign a short consent form before testing (and guardian consent if under $18$).
* In full compliance with the **Philippine Data Privacy Act of 2012 (RA 10173)** and Page 34 of the lab manual, no tester names, faces, or phone numbers will be stored in the Git repository or paper; testers will be logged strictly as `T1`, `T2`, `T3`, `T4`, `T5`.

---

## 6. Five-Week Implementation & Checkpoint Roadmap

| Week | Lab Phases | Key Deliverables & Team Milestones | Checkpoints Due |
| :--- | :--- | :--- | :--- |
| **Week 1** | Phases 1–2 | Finalize `docs/GDD.md`, draw Level $1$ paper prototype (photo), initialize Flutter + Flame Git repo (`itsd85-lab<no>-<section>-<teamname>`), set up `feature/*` branches. | **Checkpoint 1** (GDD + Paper Prototype) & **Checkpoint 2** (Repo runs on all team PCs) |
| **Week 2** | Phase 3 (Part 1) | Implement `Player` physics, `TrapSpike`, `FakeFloor`, `GameState` (`SharedPreferences`), and playable `Level01.tmx`. Export and install first debug APK on a team phone. | **Level 1 Playable on a Real Phone** |
| **Week 3** | Phases 3–4 | Build `Level02.tmx`–`Level05.tmx`, `LevelSelectScreen` with padlocks, `ResultScreen` with $1\text{--}3$ stars, `ModeSelectScreen`, and `SimpleAI` Pace-Bot. Run Airplane Mode test. | **Checkpoint 3** (Unlock/Save video) & **Checkpoint 4** (Airplane Mode video) |
| **Week 4** | Phases 5–7 | Build `NetManager` ($2\text{--}5$ player WebSocket Host/Join + $5\text{s}$ timeout error handling), `LobbyScreen`, live scoreboard, `PauseMenuOverlay`, audio toggles, `CREDITS.md`, and test across $2+$ physical phones. | **Checkpoint 5** (Online match + Wi-Fi off error video), **Checkpoint 6** (UI screenshots + Credits), **Checkpoint 7** (APK + Phone Test Matrix) |
| **Week 5** | Phase 8 & Paper | **Feature Freeze.** Run playtests with $5+$ external testers, calculate Likert $M$ and $SD$ + completion rates, implement $3+$ verified fixes, retest with $2$ new players, record $2\text{--}3\text{ min}$ demo video, write $5\text{--}7\text{ page}$ IEEE paper, tag `v1.0` release on GitHub. | **Checkpoint 8** (Playtest analysis & fixes), **Final GitHub Release `v1.0`**, **IEEE Paper PDF**, & **7-Min Live Demo** |