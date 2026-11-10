# One-Page Game Design Document (GDD): Trap Dash Arena
**Course:** ITSD 85 – Special Topics in Software Development  
**Project Type:** Mobile Game with Level Progression and Offline/Online Multiplayer  
**Target Platform:** Android (Primary APK) / iOS & Desktop (Compatible)  
**Engine & Stack:** Flutter + Flame Engine (BSD/MIT Open-Source Stack)  
**Orientation & Resolution:** Fixed Landscape ($1280\times720$ logical viewport)

---

## 1. Pitch
*Trap Dash Arena* is a deceptive 2D precision action-platformer inspired by *Level Devil* and *Trap Adventure 2* where players navigate five increasingly treacherous trap-filled dungeons—either solo offline (with an optional AI pace-bot rival) or in a frantic 2–5 player local Wi-Fi score-rush—to reach the exit portal before time or lives run out.

## 2. Genre and Target Players
* **Genre:** 2D Deceptive Trap Platformer / Competitive Score-Rush Arcade.
* **Target Players:** Ages 15–25; casual-to-midcore mobile gamers who enjoy comedic surprise traps, tight platforming, and bite-sized competitive multiplayer races.

## 3. Core Mechanic & Touch Controls
* **Core Loop (Every 2–4 Seconds):** Run across multi-room enclosed chambers, jump over sudden and chasing floor gaps, bait deceptive environmental traps (multi-behavior spikes, control inverter zones, betrayal warp portals, ceiling drops), trigger mid-stage checkpoints, and reach the exit portal.
* **Touch Controls (`TouchControlsOverlay`, Fixed Landscape):**
  * **Left Thumb:** Dual wireframe directional chevron pads (`Move Left`, `Move Right`) in the bottom-left safe zone ($148\times124\text{ px}$ touch hit target).
  * **Right Thumb:** Large wireframe pentagon `Jump` pad in the bottom-right safe zone ($156\times128\text{ px}$ touch hit target), paired with $0.10\text{s}$ coyote time, $0.10\text{s}$ jump buffering, and asymmetric rise/fall gravity.

## 4. Goal, Win Condition, and Lose Condition
* **Level Goal:** Explicitly displayed on the top-center `HudOverlay` banner throughout each level alongside room progression indicator squares.
* **Win Condition:** Enter the `ExitPortal` doorway while $t_{\text{left}} > 0$ and $\text{Hearts} \ge 1$ (and any required keys collected). Triggers `ResultOverlay` (`ResultScreen`), awards 1–3 stars, unlocks level $n+1$ in Offline Mode, and persists progress via `SharedPreferences`.
* **Death & Respawn ("Fair Rage" Loop):** Hitting a trap or falling into a pit triggers a shard disintegration burst, deducts $1$ Heart (`-25 pts`), and displays `RespawnOverlay` (`"YOU DIED"`). Tapping `RESPAWN` resets chamber traps and reintegrates the player at the last activated `CheckpointFlag`.
* **Lose Condition (Offline):** Either $\text{Hearts} = 0$ or $t_{\text{left}} \le 0.0\text{s}$. Triggers `ResultOverlay` (`"TRY AGAIN"`) with `RETRY` and `MENU` (`NEXT` is hidden).
* **Win/Lose Condition (Online 2–5 Players):** All connected players compete on the chosen stage simultaneously. When all active players finish or are eliminated, the Host adjudicates the winner with the highest deterministic score and broadcasts the final leaderboard (`announce_winner`).

## 5. Level Plan (Difficulty Curve)

| Level No. | Rooms | Explicit HUD Goal Text (`LevelConfig`) | Mechanics & Deceptive Traps | Time / Life Limit |
| :--- | :---: | :--- | :--- | :--- |
| **Level 1** | 3 | *"Cross 3 Platforms & Reach the Exit in 90s"* | **Deceptive Floor Gaps:** `SuddenGap` openings, `MovingGapFloor` (`chase` & `hesitation` modes), 2 passage checkpoints. | 90s / 5 Hearts |
| **Level 2** | 3 | *"Outsmart the Deceptive Spikes & Exit in 75s"* | **Multi-Behavior Spikes:** Stationary spikes, chasing/hesitation floor gaps, `TrapSpike` (`slideRightOnJump`, `proximityPopUp`, `riseOnProximity`, `doubleSlideTrap`), 2 checkpoints. | 75s / 5 Hearts |
| **Level 3** | 3 | *"Survive Inverted Controls & Exit in 70s"* | **Control Inversion:** `ControlInverterZone` (walk & grounded triggers with overhead arrow tell), `SuddenGap` islands, rear-ambush `remotePopUp` spikes, inverted staircase & plateau hesitation gap, 2 checkpoints. | 70s / 4 Hearts |
| **Level 4** | 3 | *"Master the Deceptive Warps & Exit in 60s"* | **Warp Portals & Gauntlet:** Slender pillars with spike-arming `WarpPortal`s, multi-pass shifting bridge warp, fleeing upper warp, Room 3 5-step `PortalGauntletController`, 2 checkpoints. | 60s / 3 Hearts |
| **Level 5** | 1 | *"Conquer the Master Gauntlet in 60s"* | **Master Gauntlet:** High-density chamber combining `ReverseSpring`, `FakeFloor`, `FallingBlock`, `MovingSaw`, `DisappearingPlatform`, bonus coins, and 1 mid checkpoint. | 60s / 3 Hearts |

## 6. Unlocking and Star Rating Rules
* **Level Unlocking Rule:** Level 1 is unlocked by default. Level $n+1$ stays locked until Level $n$ is cleared in Offline Mode.
* **Star Calculation Formula (`LevelController.calculateStars`):**
  * **3 Stars:** Cleared with $t_{\text{left}} > 0.50 \times t_{\text{limit}}$ AND $H_{\text{left}} \ge \min(3, \text{initialHearts} - 1)$.
  * **2 Stars:** Cleared with $t_{\text{left}} > 0.25 \times t_{\text{limit}}$ OR $H_{\text{left}} \ge 2$.
  * **1 Star:** Cleared under any other valid win condition.

## 7. Offline Mode
* **Solo Campaign:** 100% playable in Airplane Mode with zero network calls.
* **Race vs. AI Bot (`SimpleAI`):** Optional toggle in `SettingsScreen` that spawns a visible translucent ghost runner (`BOT` tag) and increments its simulated score (`+35 pts` per step) at level-scaled intervals ($\text{delay} = \max(0.8, 3.0 - 0.4 \times (\text{level} - 1))$).

## 8. Online Mode (2–5 Player Score-Rush)
* **Match Type:** Real-time competitive score-rush across 2–5 devices over local Wi-Fi/Hotspot (`HttpServer` + `WebSocket` on port `7777`, 5s connection timeout).
* **Score Formula:** $\text{Score} = \max(0, 100C + 50K + 25B - 25D) + E_{\text{bonus}}$, where $E_{\text{bonus}} = 300 + (\lceil t_{\text{left}} \rceil \times 10)$.
* **Payloads:** JSON event packets (`join_lobby`, `lobby_state`, `start_match`, `score_event`, `player_finished`, `announce_winner`, `peer_disconnected`).
