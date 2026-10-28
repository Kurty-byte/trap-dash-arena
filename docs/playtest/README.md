# Trap Dash Arena — Anonymized Playtest Records & Observation Sheets

## Data Privacy & Ethics Compliance (RA 10173)
In strict compliance with the **Philippine Data Privacy Act of 2012 (Republic Act No. 10173)** and ITSD 85 Course Guidelines:
* No personal identifying information (real names, contact numbers, biometric data, faces) is stored in this repository.
* Participants are recorded solely as anonymized identifiers: `T1`, `T2`, `T3`, `T4`, `T5`.
* Informed consent was obtained prior to session observation.

---

## Participant Profiles (Anonymized)

| Tester ID | Age Group | Mobile Gaming Frequency | Platformer Experience | Testing Environment |
| :--- | :--- | :--- | :--- | :--- |
| **T1** | 18–20 | Daily ($>2\text{ hrs}$) | High (*Level Devil*, *Geometry Dash*) | Android (Realme 8, Android 12) |
| **T2** | 21–25 | Casual ($2\text{--}4\text{ hrs/wk}$) | Moderate (*Super Mario*, *Badland*) | Android (Samsung Galaxy A53, Android 13) |
| **T3** | 18–20 | Daily ($>2\text{ hrs}$) | High (*Trap Adventure 2*, *Celeste*) | Android (Xiaomi Poco X3, Android 12) |
| **T4** | 21–25 | Occasional ($<2\text{ hrs/wk}$) | Novice (*Subway Surfers*, *Candy Crush*) | Android (Google Pixel 6a, Android 14) |
| **T5** | 18–20 | Moderate ($4\text{--}7\text{ hrs/wk}$) | Moderate (*Dead Cells*, *Hollow Knight*) | Android (OnePlus Nord CE, Android 13) |

---

## 15-Item Likert Evaluation Results (Scale 1–5)
*Target benchmark: Mean $M \ge 3.5$ on all items (items $< 3.5$ flag required design iterations).*

| # | Survey Statement | T1 | T2 | T3 | T4 | T5 | Mean ($M$) | SD | Status |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Q1** | The objective of each level was clear from the HUD banner. | 5 | 5 | 4 | 5 | 5 | **4.80** | 0.45 | Passed |
| **Q2** | Touch controls (move & jump) felt responsive with no missed inputs. | 5 | 4 | 4 | 4 | 5 | **4.40** | 0.55 | Passed |
| **Q3** | The coyote time and jump buffer made jumping off ledges feel fair. | 5 | 5 | 5 | 4 | 4 | **4.60** | 0.55 | Passed |
| **Q4** | Each level felt a little harder than the last, but fair. | 4 | 4 | 5 | 4 | 4 | **4.20** | 0.45 | Passed |
| **Q5** | Subtle trap telegraphs (cracked tiles, spike rumbles) rewarded awareness. | 5 | 4 | 5 | 4 | 4 | **4.40** | 0.55 | Passed |
| **Q6** | Checkpoint respawns and heart pools prevented excessive frustration. | 5 | 5 | 4 | 5 | 5 | **4.80** | 0.45 | Passed |
| **Q7** | The offline Pace-Bot rival added competitive pressure to solo play. | 4 | 4 | 4 | 4 | 5 | **4.20** | 0.45 | Passed |
| **Q8** | Local Wi-Fi / hotspot multiplayer connected smoothly. | 5 | 4 | 5 | 4 | 4 | **4.40** | 0.55 | Passed |
| **Q9** | Real-time score events and progress synced accurately across devices. | 5 | 4 | 5 | 4 | 5 | **4.60** | 0.55 | Passed |
| **Q10** | Error messages for disconnected or unreachable host were clear. | 5 | 5 | 4 | 4 | 5 | **4.60** | 0.55 | Passed |
| **Q11** | The high-contrast trap tells accessibility toggle improved visibility. | 4 | 5 | 4 | 5 | 4 | **4.40** | 0.55 | Passed |
| **Q12** | Game UI typography and button sizes were easy to read and tap. | 5 | 5 | 5 | 5 | 4 | **4.80** | 0.45 | Passed |
| **Q13** | Monotone minimalist visual aesthetic gave a cohesive arcade feel. | 5 | 5 | 5 | 5 | 5 | **5.00** | 0.00 | Passed |
| **Q14** | Sound effects and background music enhanced the gameplay experience. | 4 | 4 | 4 | 4 | 4 | **4.00** | 0.00 | Passed |
| **Q15** | Overall, I would recommend Trap Dash Arena to friends. | 5 | 4 | 5 | 4 | 5 | **4.60** | 0.55 | Passed |
| **ALL**| **Overall Aggregate Average** | — | — | — | — | — | **4.52** | **0.46** | **Target Achieved** |

---

## Qualitative Observations & Verified Fixes

### Observation 1 (Level 3 Falling Corridor)
* **Tester Note (T4):** Falling ceiling hazard initially felt too sudden on the second platform corridor.
* **Tuning Applied:** Adjusted trigger distance sensor line by $+12\text{ px}$ and added a $0.25\text{s}$ ceiling vibration rattle before the bomb drops.

### Observation 2 (Multiplayer Host IP Entry)
* **Tester Note (T2):** Typing the full IP manually on a small phone was prone to minor typos.
* **Tuning Applied:** Added a one-tap clipboard copy button directly next to the Host IP banner in `LobbyScreen`.

### Observation 3 (Visual Accessibility)
* **Tester Note (T5):** Appreciated the "High-Contrast Trap Tells" mode for highlighting crumbling fake floor boundaries and sawblades with warning red outlines.
