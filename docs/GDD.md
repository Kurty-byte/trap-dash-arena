# One-Page Game Design Document (GDD): Trap Dash Arena
**Course:** ITSD 85 – Special Topics in Software Development  
**Project Type:** Mobile Game with Level Progression and Offline/Online Multiplayer  
**Target Platform:** Android (Primary APK) / iOS (Compatible)  
**Engine & Stack:** Flutter + Flame Engine (BSD/MIT Open-Source Stack)  
**Orientation & Resolution:** Fixed Landscape (1280x720 logical viewport)

---

## 1. Pitch
*Trap Dash Arena* is a deceptive 2D precision action-platformer where players navigate five increasingly treacherous trap-filled dungeons—either solo offline or in a frantic 2–5 player online score-rush—to reach the exit portal before time or lives run out.

## 2. Genre and Target Players
* **Genre:** 2D Deceptive Trap Platformer / Competitive Score-Rush Arcade.
* **Target Players:** Ages 15–25; casual-to-midcore mobile gamers who enjoy the humor and surprise of *Trap Adventure 2* and *Level Devil*, paired with bite-sized competitive multiplayer races.

## 3. Core Mechanic & Touch Controls
* **Core Loop (Every 2–4 Seconds):** Run, jump, bait deceptive environmental traps (hidden spikes, crumbling tiles, sudden ceiling drops), trigger checkpoints, and collect bonus coins on the way to the exit portal.
* **Touch Controls (Fixed Landscape):**
  * **Left Thumb:** Dual on-screen directional buttons (`Move Left`, `Move Right`) positioned in the bottom-left safe zone, minimum size $120\times120\text{ px}$.
  * **Right Thumb:** Large `Jump` button (variable jump height based on hold duration) in the bottom-right safe zone.

## 4. Goal, Win Condition, and Lose Condition
* **Level Goal:** Explicitly displayed on the HUD banner at start of each level (e.g., *"Reach the Exit Portal within 60s before losing all 5 Hearts"*).
* **Win Condition:** Touch `ExitPortal` hitbox while $t_{\text{left}} > 0$ and $\text{Hearts} \ge 1$ (and required keys collected). Triggers Result Screen, awards 1–3 stars, unlocks level $n+1$, and saves to device storage.
* **Lose Condition (Offline):** Either $\text{Hearts} = 0$ or $t_{\text{left}} \le 0.0\text{s}$. Triggers Result Screen (`Try Again`) with `Retry` and `Menu` (`Next` is disabled).
* **Win/Lose Condition (Online 2–5 Players):** All players compete on identical seeded trap stages simultaneously. Winner has highest score when match ends or 10s sudden-death concludes after first portal clear.

## 5. Level Plan (Difficulty Curve)

| Level No. | Explicit HUD Goal Text | Mechanics & Traps | Time / Life Limit |
| :--- | :--- | :--- | :--- |
| **Level 1** | *"Reach the Exit Portal in 90s (Watch for cracked tiles!)"* | Static spikes, 2 crumbling floor tiles, mid checkpoint, hint arrows. | 90s / 5 Hearts |
| **Level 2** | *"Collect 5 Keys & Reach the Exit in 75s"* | Proximity-triggered floor spikes (0.30s jitter telegraph), 5 key pickups. | 75s / 5 Hearts |
| **Level 3** | *"Survive the Falling Corridor & Exit in 70s"* | Dropping ceiling blocks, decoy fake exit portal. | 70s / 4 Hearts |
| **Level 4** | *"Dodge the Moving Saws & Exit in 60s"* | Patrol sawblades, disappearing platforms, tighter jump windows. | 60s / 3 Hearts |
| **Level 5** | *"Conquer the Master Gauntlet in 60s"* | Gauntlet combining fake floors, ceiling drops, moving saws, reverse springs. | 60s / 3 Hearts |

## 6. Unlocking and Star Rating Rules
* **Level Unlocking Rule:** Level 1 unlocked by default. Level $n+1$ stays locked until Level $n$ is cleared in Offline Mode.
* **Star Calculation Formula:**
  * **3 Stars:** Cleared with $t_{\text{left}} > 0.50 \times t_{\text{limit}}$ AND $H_{\text{left}} \ge \min(3, \text{initialHearts} - 1)$.
  * **2 Stars:** Cleared with $t_{\text{left}} > 0.25 \times t_{\text{limit}}$ OR $H_{\text{left}} \ge 2$.
  * **1 Star:** Cleared under any other valid condition.

## 7. Offline Mode
* **Solo Campaign:** 100% playable in Airplane Mode with zero network calls.
* **Race vs. AI Bot (SimpleAI):** Simulated score counter increments score at level-scaled intervals ($\text{delay} = \max(0.8, 3.0 - 0.4 \times (\text{level} - 1))$).

## 8. Online Mode (2–5 Player Score-Rush)
* **Match Type:** Real-time competitive score-rush across 2–5 devices over local Wi-Fi/Hotspot (port 7777).
* **Score Formula:** $\text{Score} = \max(0, 100C + 50K + 25B - 25D) + E_{\text{bonus}}$
* **Payloads:** JSON event packets (`start_match`, `score_event`, `announce_winner`, `peer_disconnected`).
