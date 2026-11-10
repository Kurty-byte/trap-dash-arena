# Trap Dash Arena

**Trap Dash Arena** is a 2D deceptive trap platformer and 2–5 player local Wi-Fi score-rush arcade game built with **Flutter** and the **Flame Engine** for **ITSD 85 – Special Topics in Software Development**.

Inspired by *Level Devil* and *Trap Adventure 2*, players navigate five increasingly treacherous trap-filled dungeons—either solo offline (with an optional AI ghost rival) or in a real-time 2–5 player local multiplayer race—to reach the exit portal before time or hearts run out.

---

## Key Features

* **5 Deceptive Dungeon Levels:** Progresses through four 3-room enclosed dungeon chambers (`roomCount: 3`, smooth room-by-room camera panning) and a final high-density Master Gauntlet (`roomCount: 1`).
* **"Fair Rage" Respawn Loop:** Each attempt grants $3\text{--}5$ Hearts and $1\text{--}2$ mid-stage Checkpoints (`CheckpointFlag`). Dying triggers a shard disintegration burst (`PlayerShardEffect`), trauma camera shake, and `RespawnOverlay` (`"YOU DIED"`), resetting chamber traps and reintegrating the runner at the last checkpoint.
* **Rich Deceptive Hazard Suite:**
  * `SuddenGap` & `MovingGapFloor` (chasing floor gaps and anti-second-guessing hesitation gaps).
  * `TrapSpike` with 7 behaviors (`stationary`, `proximityPopUp`, `slideRightOnJump`, `riseOnProximity`, `doubleSlideTrap`, `remotePopUp`, `oscillateTwice`).
  * `ControlInverterZone` (flips horizontal controls with an overhead arrow tell).
  * `WarpPortal` & `PortalGauntletController` (betrayal spike warps, shifting bridge warps, fleeing warps, and a 5-step binary portal gauntlet).
  * `FakeFloor`, `FallingBlock`, `MovingSaw`, `DisappearingPlatform`, and `ReverseSpring`.
* **Offline Solo & Pace-Bot Ghost (`SimpleAI`):** 100% playable in Airplane Mode with optional translucent ghost rival runner (`BOT` badge) and live score counter.
* **2–5 Player Real-Time Local Multiplayer (`NetManager`):** Host/Join over local Wi-Fi or mobile hotspot (`HttpServer` + `WebSocket` on port `7777`, 5-second connection timeout, live HUD leaderboard, and Host-adjudicated winner scoreboard).
* **Accessibility & Polish:** High-Contrast Trap Tells toggle (`AppPalette.warningRed` outlines), persisted audio mute (`AudioManager`), custom player nicknames, and responsive wireframe touch controls ($0.10\text{s}$ coyote time & $0.10\text{s}$ jump buffer).

---

## Level Progression

| Level | Rooms | HUD Goal Text (`LevelConfig`) | Core Mechanics & Traps | Time / Hearts |
| :--- | :---: | :--- | :--- | :--- |
| **Level 1** | 3 | `"Cross 3 Platforms & Reach the Exit in 90s"` | `SuddenGap`, `MovingGapFloor` (`chase` & `hesitation` modes), 2 checkpoints | 90s / 5 Hearts |
| **Level 2** | 3 | `"Outsmart the Deceptive Spikes & Exit in 75s"` | Multi-behavior `TrapSpike`s (`stationary`, `slideRightOnJump`, `proximityPopUp`, `riseOnProximity`, `doubleSlideTrap`), chasing/hesitation gaps, 2 checkpoints | 75s / 5 Hearts |
| **Level 3** | 3 | *"Survive Inverted Controls & Exit in 70s"* | `ControlInverterZone` (walk & grounded triggers), `SuddenGap` islands, rear-ambush `remotePopUp` spikes, inverted staircase, 2 checkpoints | 70s / 4 Hearts |
| **Level 4** | 3 | `"Master the Deceptive Warps & Exit in 60s"` | Spike-arming `WarpPortal`s, multi-pass bridge warp, fleeing warp, 5-step `PortalGauntletController`, 2 checkpoints | 60s / 3 Hearts |
| **Level 5** | 1 | `"Conquer the Master Gauntlet in 60s"` | `ReverseSpring`, `FakeFloor`, `FallingBlock`, `MovingSaw`, `DisappearingPlatform`, bonus coins, 1 mid checkpoint | 60s / 3 Hearts |

---

## Lab Requirements Mapping (ITSD 85 Compliance)

| Requirement ID | Requirement Summary | Implementation & Verification Criteria |
| :--- | :--- | :--- |
| **R1** | $\ge 5$ distinct levels with increasing difficulty | Levels 1–5 in `assets/tiles/Level01.tmx`–`Level05.tmx` & `ChamberLoader` (`_buildLevel1`–`_buildLevel5`), decreasing time limits ($90\text{s} \rightarrow 60\text{s}$) and hearts ($5 \rightarrow 3$). |
| **R2** | Clear goal text displayed on HUD per level | Top-center banner in `HudOverlay` displaying `controller.config.goalText` and room progression squares. |
| **R3** | Win/Lose conditions with Result screen | `ResultOverlay` (`ResultScreen`) with $0\text{--}3$ stars, score/time/hearts breakdown, `RETRY`, `NEXT` (win only on Levels 1–4), and `MENU`. |
| **R4** | Level unlocking ($n+1$ locked until $n$ cleared) | `GameState.isUnlocked(level)` checks `level <= unlockedLevel`; `LevelSelectScreen` renders padlock icons and disables locked stages. |
| **R5** | Persistence survives closing application | `SharedPreferences` saves `unlocked_level`, `best_stars`, `audio_muted`, `high_contrast_tells`, `ai_bot_enabled`, and `player_nickname`. |
| **R6** | Offline mode in Airplane Mode | Zero network dependencies in Offline Mode; includes toggleable `SimpleAI` Pace-Bot ghost runner. |
| **R7** | Real-time 2–5 player multiplayer | `NetManager` & `LocalWsTransport` Host/Join on port `7777` (`maxClients = 4`), live HUD leaderboard, Host adjudicates winner (`announce_winner`). |
| **R8** | Mode select & connection error handling | `ModeSelectScreen` (`PLAY OFFLINE` / `PLAY ONLINE`); 5s timeout displays `"Cannot reach host. Check that you are on the same Wi-Fi."` via `ArcadeDialog`. |
| **R9** | Touch controls, fixed orientation on real phone | Locked landscape (`1280x720`), multi-touch `Listener` pads in `TouchControlsOverlay` (`148x124` Left/Right, `156x128` Jump), Android APK build. |
| **R10** | Polish: title, pause, sound toggle, font size | `TitleScreen`, `PauseOverlay` (`pauseEngine()`), `RespawnOverlay`, persisted mute toggle, accessible typography, `docs/CREDITS.md` & `CreditsScreen`. |
| **Bonus** | Stars, hints, a11y, player nicknames | $1\text{--}3$ stars (`calculateStars`), `HintArrow` & overhead inverted-control tell, `highContrastTells` warning outlines, custom player nicknames. |

---

## Documentation Index

* [Architecture & Agent Guide (`AGENTS.md`)](AGENTS.md)
* [One-Page Game Design Document (`docs/GDD.md`)](docs/GDD.md)
* [Product Requirements Document (`docs/tda_prd.md`)](docs/tda_prd.md)
* [Open-Source Asset Credits (`docs/CREDITS.md`)](docs/CREDITS.md)
* [Anonymized Playtest Records (`docs/playtest/README.md`)](docs/playtest/README.md)

---

## Build & Verification Commands

```powershell
# Fetch dependencies
flutter pub get

# Run static analysis
dart analyze

# Run unit and widget test suite
flutter test

# Run game on connected device or desktop
flutter run

# Build release Android APK
flutter build apk --release
```
