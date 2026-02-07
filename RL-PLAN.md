# RoboHope - Phased RL Implementation Plan

## Project Overview

**RoboHope** is a top-down shooter/RTS-lite hybrid made in Godot 3.x. The player helps robotic allies collect resources, build factories, and construct a rocket to escape.

### Core Game Loop
1. **Player** moves, shoots, and mines (Wood/Stone/Crystal).
2. **Factories** produce BuildBots/DefenceBots and the **Rocket** (win condition).
3. **Bots** autonomously gather and defend.
4. **Enemies** spawn from Nests and attack everything.
5. **Goal**: Collect 5 crystals (from destroyed nests), deposit them, and build the Rocket.

### Game Over Conditions
- **Loss**: Player Health ≤ 0
- **Loss**: All Factories destroyed
- **Win**: Rocket launched (Requires 5 crystals + 20 wood/stone at a factory)

### Action Design: Granular Control
While initial phases uses simplified actions for testing, the **target design** prioritizes **multi-discrete/granular control** as requested, allowing:
- Precise movement angles (not just 8-way)
- Independent aiming (360° laser sweep)
- Strategic logic for factory interactions (Deposit/Build/Upgrade)

---

## Architecture: Godot-First

We will build a **Headless RL Server** inside Godot that exposes the game via TCP. This treats Godot as a library that an external Python process can drive.

```
[RL Agent] <---TCP JSON---> [Godot RLServer] <---> [RLInterface] <---> [Game World]
```

---

## Implementation Phases

### Phase 0: Instrument the Game (1-2 Days)
**Goal**: Query state and reset the world reliably in GDScript (no networking yet).

1. **Create `objects/RLInterface.gd` (Autoload)**
   - Acts as the central API.
   - `rl_mode`: Boolean flag from cmd args.

2. **Implement `reset_world(seed)`**
   - Reload the main scene or reset all variables.
   - Force random seed for reproducibility (to the extent possible in Godot 3).
   - Respawn player, clear enemies, regenerate resources.

3. **Implement `get_observation_v0()`**
   - Return a **flat float array** (fastest to debug).
   - Content: `[PlayerX, PlayerY, HP, Wood, Stone, Crystal, NearestEnemyX, NearestEnemyY, NearestFactoryX, NearestFactoryY]`

4. **Implement `apply_action_v0(action_id)`**
   - Start with a simplified discrete set for testing internal logic:
     - 0-8: Move (Stop + 8 directions)
     - 9: Shoot/Mine Nearest (Auto-aim)

**Milestone**: Run Godot, press a debug key, and see the game reset and print the observation vector to the console.

---

### Phase 1: The TCP Server (1 Day)
**Goal**: External processes can drive the game step-by-step.

1. **Create `objects/RLServer.gd`**
   - Listen on port 9999 (TCP).
   - Accept JSON Lines: `{"cmd": "step", "action": ...}`.
   - Send JSON Lines: `{"obs": [...], "reward": 0, "done": false}`.

2. **Implement Step Loop**
   - Decouple rendering from physics if possible (`--headless`).
   - `step(action)` should advance physics by **4 ticks** (frameskip) to speed up training.

**Milestone**: A dumb external script (or Telnet) can connect, send "reset" then "step", and receive valid JSON responses without crashing Godot.

---

### Phase 2: Rewards & Events (1-2 Days)
**Goal**: Defining what "Good" looks like. Avoid busywork rewards.

1. **Define Signals for Rewards**
   - Add signals to `Nest.gd` (`destroyed`), `Resource.gd` (`crystal_collected`), `Factory.gd` (`rocket_launched`).
   - Connect these to `RLInterface` to accumulate `step_reward`.

2. **Reward Function (v0)**
   - **Win (Rocket)**: +100.0
   - **Progress (Crystal)**: +10.0
   - **Combat (Nest Kill)**: +20.0 (Encourages clearing map)
   - **Penalty (Death)**: -10.0
   - **Time**: -0.01 per step (Encourages speed)
   - *Note: No rewards for just mining wood/stone to prevent "farming" behavior.*

**Milestone**: Manually playing the game (mapped to RL interface) logs correct reward spikes when Nests die or Crystals are found.

---

### Phase 3: Sanity Check (External)
*(Out of scope for this file, but conceptually: Training a simple PPO agent to survive)*

---

### Phase 4: Strategy Layer (Factories) (2 Days)
**Goal**: Implementing the Factory State Machine (No UI).

1. **Factory Interaction Actions**
   - Instead of simulating "Press E -> Click UI", uses direct actions gated by proximity (`if near_factory`).
   - **New Actions**:
     - `DEPOSIT`: Move partial resources to factory.
     - `SELECT_BUILD(Type)`: Set factory production (Bot/Rocket).
     - `BUY_UPGRADE(Type)`: Spend resources on stats.

2. **Expand Observation (`get_observation_v1`)**
   - Add: `[NearFactory (bool), FactoryWood, FactoryStone, CurrentBuild, RocketUnlocked]`

**Milestone**: Agent successfully deposits resources and queues a BuildBot.

---

### Phase 5: High-Fidelity & Granular Control (Final)
**Goal**: Replace simplified actions with the user's preferred Granular Control.

1. **Switch to Hybrid/Multi-Discrete Action Space**
   - **Movement**: Continuous `Vector2(x, y)` for precise angles.
   - **Aiming**: Continuous `Vector2(x, y)` for independent 360° shooting/mining.
   - **Triggers**: Discrete `[Shoot, Mine, Interact]`.

2. **Complex Observations (`get_observation_v2`)**
   - Upgrade to a richer feature set (e.g., raycasts for walls, relative positions of top-5 nearest enemies).

**Milestone**: Agent kites enemies effectively using non-cardinal movement and independent aiming.

---

## Detailed Specs (Phase 0/1)

### Observation Vector v0 (Flat Array)
| Index | Name | Normalization |
|-------|------|---------------|
| 0-1 | Player Global Pos (x,y) | Map Size |
| 2 | Player HP | / Max HP |
| 3 | Player Wood | / 20 |
| 4 | Player Stone | / 20 |
| 5 | Player Crystal | / 5 |
| 6 | Can Shoot (Cooldown) | 0 or 1 |
| 7-8 | Nearest Enemy Rel (x,y) | / View Range |
| 9-10 | Nearest Factory Rel (x,y) | / Map Size |
| 11 | Nearest Factory HP | / Max HP |

### Action Space v0 (Discrete - For Testing)
`0`: NOOP
`1-8`: Move Cardinal+Diagonals
`9`: Shoot Enemy (Auto-aim)
`10`: Mine Resource (Auto-aim)
`11`: Interact (Deposit/Menu placeholder)

### Action Space vTarget (Hybrid - The Goal)
- **Move**: `Box(-1, 1, shape=(2,))`
- **Aim**: `Box(-1, 1, shape=(2,))`
- **Actions**: `MultiDiscrete([Shoot, Mine, Interact, BuildOption...])`
