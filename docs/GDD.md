# Game Design Document: Iron Front
**Target Platform:** Android (Landscape Only)  
**Genre:** Offline 2D Top-Down Real-Time Tactics / RTS-Lite  
**Engine:** Godot 4 (GDScript, Mobile/Compatibility Renderer)  
**Target Hardware:** Mid-range Android smartphones (Snapdragon 680 / 720G, Mali-G52/G57, 4GB RAM)  
**Monetization & Network:** 100% Offline, Premium/Free Single-Player, Zero Ads SDK, Zero Telemetry  

---

## 1. Executive Summary & Core Loop

### 1.1 High Concept
*Iron Front* is a streamlined, WWII-inspired top-down real-time tactics war game designed specifically for touchscreen mobile play in landscape mode. It strips out tedious base micromanagement in favor of fast-paced tactical positioning, directional armor combat (front/side/rear), territory control, and combined-arms doctrine. Matches are designed to last 3 to 7 minutes.

### 1.2 Core Gameplay Loop
```
   ┌────────────────────────────────────────────────────────┐
   │                  Mission Briefing                      │
   │      (Intel, primary/secondary goals, terrain)         │
   └──────────────────────────┬─────────────────────────────┘
                              ▼
   ┌────────────────────────────────────────────────────────┐
   │                 Tactical Deployment                    │
   │    (Establish Forward HQ, deploy initial battle group)  │
   └──────────────────────────┬─────────────────────────────┘
                              ▼
   ┌────────────────────────────────────────────────────────┐
   │             Territory Control & Economy                │
   │    (Capture Supply Nodes, produce tanks/infantry)      │
   └──────────────────────────┬─────────────────────────────┘
                              ▼
   ┌────────────────────────────────────────────────────────┐
   │                 Real-Time Combat                       │
   │  (Flank weak rear armor, combined-arms maneuvers)      │
   └──────────────────────────┬─────────────────────────────┘
                              ▼
   ┌────────────────────────────────────────────────────────┐
   │               Mission Victory / Debrief                │
   │         (Earn War Bonds based on performance)          │
   └──────────────────────────┬─────────────────────────────┘
                              ▼
   ┌────────────────────────────────────────────────────────┐
   │                     Upgrade Shop                       │
   │    (Unlock chassis armor, APCR shells, engine speed)   │
   └──────────────────────────┬─────────────────────────────┘
                              │
                              └────────► Next Mission
```

---

## 2. Resource Economy: "Supply" (Single-Resource System)

To ensure fluid gameplay without desktop-style micromanagement, *Iron Front* utilizes a single unified resource: **Supply ($S$)**.

* **Starting Supply:** 250 $S$ provided at mission start.
* **Passive Base Generation:** Forward HQ generates $+6\ S/\text{sec}$.
* **Supply Capture Nodes (Oil Derricks / Depots):** Neutral structures scattered across the map. Capturing a node grants $+4\ S/\text{sec}$ and expands radar vision.
* **Salvage Mechanic:** Destroyed armored vehicles leave wrecks that Combat Engineers can reclaim for a one-time refund of 30% of the unit's original cost.
* **Resource Cap:** Soft cap of 1,200 $S$ prevents passive hoarding and encourages proactive attacks.

---

## 3. Buildings & Infrastructure

Base construction is restricted to 4 functional military structures placed via a simplified grid footprint around the Forward HQ territory.

| Building | HP | Cost ($S$) | Build Time | Footprint | Primary Function & Strategic Value |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Forward HQ (Command Bunker)** | 1,200 | 0 (Pre-built) | 0s | $3\times3$ | Base command center. Generates baseline $+6\ S/\text{sec}$, trains Combat Engineers, and reveals base radar circle. Destruction causes mission failure. |
| **Barracks** | 600 | 150 | 8s | $2\times2$ | Mobilizes light personnel: Rifle Squads and Anti-Tank Teams. Required to field capture forces. |
| **Motor Pool** | 850 | 250 | 14s | $3\times3$ | Manufactures mechanized armor: Scout Cars, Medium Tanks, and Heavy Vanguard Tanks. Requires Barracks to unlock. |
| **Bunker Emplacement** | 500 | 120 | 10s | $1\times1$ | Defensive strongpoint equipped with twin heavy machine guns and light anti-armor plating. Automatically engages targets in a 260px arc. |

---

## 4. Unit Roster & Balance Statistics

Units feature directional armor: **Front (F)**, **Side (S)**, and **Rear (R)**. Incoming rounds calculate angle of incidence; rear hits deal up to 1.8x damage by bypassing thick frontal glacis plates.

| Unit Name | Role | HP | Front / Side / Rear Armor | Damage | Armor Pen | Range | Speed | Cost ($S$) | Build Time | Counter Profile |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Combat Engineer** | Support / Capture | 75 | 4 / 4 / 4 | 8 | 6 | 160 px | 90 px/s | 50 | 4s | Captures nodes (5s), repairs vehicles (15 HP/s). Vulnerable to all combat units. |
| **Rifle Squad** | Anti-Personnel Screen | 90 | 6 / 6 / 6 | 14 | 8 | 210 px | 95 px/s | 75 | 5s | High rate of fire vs infantry and unarmored targets. Deflected by medium/heavy armor. |
| **Anti-Tank Team** | Armor Hunter | 70 | 6 / 6 / 6 | 55 | 65 | 270 px | 75 px/s | 110 | 8s | High penetration shaped-charge rockets. Shuts down tanks; vulnerable to rifle fire and artillery. |
| **Scout Car** | Fast Recon / Flanker | 150 | 22 / 14 / 10 | 20 | 22 | 240 px | 150 px/s | 140 | 7s | Rapid speed for flanking and harassment. Large vision radius (380 px). Deflects small arms. |
| **Medium Tank (M4 Cruiser)** | Main Battle Line | 240 | 55 / 32 / 18 | 45 | 48 | 290 px | 105 px/s | 260 | 12s | Workhorse of the army. Independent rotating turret (3.6 rad/s). Balanced mobility and firepower. |
| **Heavy Tank (Vanguard)** | Breakthrough Juggernaut | 420 | 95 / 60 / 32 | 90 | 85 | 340 px | 65 px/s | 460 | 20s | Devastating 88mm cannon and impenetrable frontal armor. Slow turn rate (1.6 rad/s); vulnerable to rear encirclement. |

---

## 5. Upgrade Shop (Meta-Progression)

Players earn **War Bonds ($\text{WB}$)** by completing missions (100 $\text{WB}$ per mission clear, +25 $\text{WB}$ for completing bonus objectives). Upgrades are permanent across the campaign and can be respecced for free between missions.

```
                  ┌───────────────────────────────┐
                  │       Upgrade Shop Tree       │
                  └───────────────┬───────────────┘
          ┌───────────────────────┼───────────────────────┐
          ▼                       ▼                       ▼
   [ Armor Branch ]      [ Firepower Branch ]     [ Logistics Branch ]
   • Sloped Plating       • APCR Tungsten Core    • High-Torque Gearbox
   • Spall Liners         • High-Explosive HE     • Field Radios
   • Reactive Sponsons    • Muzzle Brakes         • Automated Salvage
```

### 5.1 Upgrade Catalog

| Branch | Upgrade Tier | Cost ($\text{WB}$) | Effect |
| :--- | :--- | :---: | :--- |
| **Armor** | Tier 1: Sloped Plating | 75 | +15% frontal armor value to all armored vehicles. |
| | Tier 2: Spall Liners | 150 | -25% damage taken from explosive splash/indirect artillery fire. |
| | Tier 3: Reactive Sponsons | 250 | First hit against vehicle side armor is completely absorbed (cooldown: 20s). |
| **Firepower** | Tier 1: Tungsten Core APCR | 75 | +20% armor penetration on all tank and anti-tank munitions. |
| | Tier 2: High-Explosive Charges | 150 | Cannon shells gain 24px splash radius damaging infantry caught nearby. |
| | Tier 3: Gyrostabilizers | 250 | Turret traverse speed +35%; removes accuracy penalty while firing on the move. |
| **Logistics** | Tier 1: High-Torque Gearbox | 75 | Vehicle top speed and acceleration increased by +15%. |
| | Tier 2: Field Radios | 150 | Increases all unit vision radius by +20% and reveals stealth units. |
| | Tier 3: Automated Salvage | 250 | Engineers recover 60% of wrecked unit costs (up from 30%); base supply income $+3\ S/\text{sec}$. |

---

## 6. 10-Mission Campaign Outline

The campaign follows the Allied liberation across Western Europe, escalating from small skirmishes to combined-arms fortress sieges.

```
Mission Curve:
Difficulty (1-10)
10 |                                                   [M10: Citadel]
 9 |                                           [M9: Steel Ridge]
 8 |                                   [M8: Night Bastion]
 7 |                           [M7: Crossroads]
 6 |                   [M6: Panzer Flank]
 5 |               [M5: Redoubt]
 4 |           [M4: St. Claire]
 3 |       [M3: Valley Run]
 2 |   [M2: Convoy Ambush]
 1 | [M1: Beachhead]
   +-------------------------------------------------------------------->
    M1   M2   M3   M4   M5   M6   M7   M8   M9   M10 (Campaign Progression)
```

| M# | Mission Codename | Map Size | Primary Objective | Secondary Objective | Enemy Forces Profile | Diff (1-10) |
| :-: | :--- | :---: | :--- | :--- | :--- | :-: |
| **01** | Operation Beachhead | $1600\times1000$ | Capture 2 Supply Depots and eliminate patrol. | Complete in under 2m 30s. | Rifle Squads, Bunker Emplacement | 1 |
| **02** | Convoy Ambush | $1800\times1200$ | Intercept and destroy 4 enemy supply halftracks. | Suffer zero unit losses. | Scout Cars, Rifle Squads | 2 |
| **03** | Iron Valley | $2000\times1400$ | Destroy the Forward Motor Pool before reinforcements arrive. | Capture all 3 resource nodes. | Scout Cars, Medium Tanks, AT Teams | 3 |
| **04** | St. Claire Outskirts | $2200\times1500$ | Defend Allied HQ against 4 timed assault waves. | Keep HQ above 75% HP. | Mixed Infantry, Medium Tanks | 4 |
| **05** | The Redoubt | $2400\times1600$ | Crack 3 hardened concrete bunker positions. | Destroy bunkers without losing armor. | Heavy Bunkers, AT Teams, Artillery | 5 |
| **06** | Panzer Flank | $2600\times1800$ | Encircle and neutralize enemy heavy tank patrol. | Execute 3 successful rear armor kills. | Tiger Heavy Tanks, Scout Cars | 6 |
| **07** | Crossroads Defense | $2600\times1800$ | Hold northern and southern bridges for 4 minutes. | Never lose control of northern bridge. | Heavy Armor, Mechanized Waves | 7 |
| **08** | Night Bastion | $2800\times2000$ | Infiltrate radar perimeter and destroy power sub-stations. | Complete without triggering base siren. | Stealth Patrols, AT Nests, Spotters | 8 |
| **09** | Steel Ridge | $3000\times2200$ | 50v50 Armored clash across open ridgeline. | Achieve 3:1 Kill/Loss ratio. | Dual Motor Pools, Heavy Battlegroups | 9 |
| **10** | Fortress Eisen | $3200\times2400$ | Level the Axis Command Citadel in multi-stage siege. | Destroy all auxiliary production plants. | Elite Vanguard, Super-Heavy Defense | 10 |

---

## 7. Touch Controls & Mobile Ergonomics

Designed specifically for 2-thumb handheld landscape ergonomics on 16:9 to 20:9 mobile displays.

```
┌────────────────────────────────────────────────────────────────────────┐
│ [TOP BAR]  Mission: Operation Beachhead  |  Supply: 420 (+10/s) | 60 FPS│
├──────────────┬──────────────────────────────────────────┬──────────────┤
│              │                                          │  [MINIMAP]   │
│              │                                          │  (Radar Blips)
│              │                                          │              │
│              │              BATTLEFIELD VIEW            ├──────────────┤
│              │                                          │ PRODUCTION   │
│              │   • Tap Unit: Select                     │  [BARRACKS]  │
│              │   • Drag Box: Multi-Select Platoon       │  [FACTORY]   │
│              │   • Tap Ground: Move/Attack-Move         │  [BUNKER]    │
│              │   • Tap Enemy: Focus Fire Target         │              │
│              │   • 2-Finger Pinch: Zoom In/Out          ├──────────────┤
│              │   • 2-Finger Drag: Pan Viewport          │ TACTICAL     │
│              │                                          │ COMMANDS     │
│ [UNIT CARD]  │                                          │  [MOVE]      │
│  M4 Sherman  │                                          │  [A-MOVE]    │
│  F:55 S:32 R:18                                         │  [HALT]      │
│  HP: [████ ] │                                          │  [ALLIED]    │
└──────────────┴──────────────────────────────────────────┴──────────────┘
```

### 7.1 Gesture Mapping
* **Single Tap on Friendly Unit:** Selects unit, plays radio acknowledgment chirp, reveals selection ring.
* **Single Tap on Enemy Unit (with friendly units selected):** Issues high-priority **Target Focus** order; turrets automatically slew toward target.
* **Single Tap on Ground (with friendly units selected):** Issues move or attack-move order based on active command toggle.
* **Single Finger Drag on Empty Ground:** Draws semi-transparent tactical green selection rectangle. Selects all friendly units inside upon release.
* **Two-Finger Pinch:** Smooth camera zoom ($0.5\times$ overview to $1.8\times$ close-up inspection).
* **Two-Finger Swipe:** Traverses viewport across map coordinates with boundary clamping.
* **Minimap Tap:** Instantly centers camera on tapped coordinates.

---

## 8. Milestone Production Roadmap (8 Milestones)

| Milestone | Phase Focus | Key Deliverables & Acceptance Criteria |
| :-: | :--- | :--- |
| **M1** | Core Architecture & Input | • Godot 4 landscape project configuration, viewport scaling rules.<br>• Touch gesture interpreter (tap, drag-box, 2-finger pan/zoom).<br>• Camera bounding controller with inertia. |
| **M2** | Unit State Machine & Armor | • `UnitData` resource class & `Unit.gd` entity base.<br>• State machine: `IDLE`, `MOVE`, `ATTACK_MOVE`, `ATTACK`, `DESTROYED`.<br>• Angle-of-incidence directional armor calculation (Front/Side/Rear). |
| **M3** | Combat & Object Pooling | • Zero-allocation `ObjectPool` for projectiles, explosions, and shockwaves.<br>• Weapon reload timers, independent turret traverse, and recoil animations.<br>• Line-of-sight and targeting ranges. |
| **M4** | Base Building & Resource Flow | • Single resource economy: Supply generation, consumption, and storage cap.<br>• Grid placement controller with collision footprints for 4 buildings.<br>• Capture node mechanics with 5s countdown timers. |
| **M5** | Mobile 60 FPS Optimization | • 2D Spatial Hash Grid (`SpatialGrid.gd`) replacing $O(N^2)$ checks.<br>• AI update tick staggering (180–240ms intervals).<br>• Stable 60 FPS benchmark with 100 simultaneous units on Snapdragon 680. |
| **M6** | Tactical UI & Audio Synthesis | • Mobile HUD: Minimap radar, unit armor inspection card, touch command deck.<br>• Offline audio synthesis (`AudioTrack` / native sound bus): Cannon booms, machine guns, radio clicks.<br>• Mission briefing and Victory/Defeat debrief overlays. |
| **M7** | Campaign Missions 1–10 & AI | • 10 hand-crafted campaign maps with distinct victory/defeat triggers.<br>• Enemy AI Director: Wave generation, flank routing, target prioritization.<br>• Meta-progression: War Bonds tracking and persistent Upgrade Shop. |
| **M8** | Polish, Balance & Android Export | • Armor/damage balance pass across all 6 unit types.<br>• Touch accessibility verification (minimum 48dp target sizes).<br>• Final signed Android APK export with custom adaptive launcher icon. |
