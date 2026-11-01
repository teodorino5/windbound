# 🍃 WINDBOUND (Větroplav)

> **A peaceful, solarpunk-inspired sky exploration and hang-gliding adventure for Roblox.**

[![Luau](https://img.shields.io/badge/Language-Luau-00A2FF.svg)](https://luau-lang.org/)
[![Roblox](https://img.shields.io/badge/Platform-Roblox%20Studio-red.svg)](https://create.roblox.com/)
[![Blender](https://img.shields.io/badge/3D%20Pipeline-Blender%204.5-orange.svg)](https://www.blender.org/)
[![Style](https://img.shields.io/badge/Aesthetic-Solarpunk%20%7C%20Atmospheric-brightgreen.svg)]()

---

## 🪁 Overview

**WINDBOUND** places players atop the floating archipelago of **Greenwake Meadows**, where they harness deterministic 3D wind currents, soaring thermals, and aerodynamic hang-gliders to explore ancient ruins, collect mystical aerial wildlife (**Drifters**), and revitalize floating solar-wind infrastructure (**Airborne Wind Turbines**).

---

## ✨ Core Features & Mechanics

### 1. Aerodynamic Hang-Glider Flight Model
* **Realistic Lift & Drag Equations:** Dynamic physics balancing gravity, forward velocity, slipstream drag, and bank-angle lift vectors.
* **Procedural IK & Wind Reaction:**
  * Two-point `IKControl` solvers lock the avatar's hands to the glider's control bar (`GripL`, `GripR`).
  * Dynamic torso lean responding to roll, yaw, and crosswind turbulence.
  * Slipstream leg trailing with high-speed fluttering and knee bends.
* **Dual Glider Types:**
  * **Meadow Glider:** Balanced starter wing with steady glide ratio and gentle handling.
  * **Swiftleaf Glider:** Agile, high-speed wing tuned for diving through turbulent updrafts.
* **Dynamic Sizing:** Wings scale up to **3.8x** (~9.75 stud wingspan) when deployed in flight, and pack down to a compact 0.55x back mount while walking.

### 2. 3D Deterministic Wind & Updrafts
* **WindService:** Global vector wind field with Perlin turbulence and local valley draft vectors.
* **Thermal Updrafts:** Localized updraft columns generated near cliff edges and geothermal vents that lift gliders smoothly into the sky.

### 3. Solarpunk Atmosphere & Airborne Infrastructure
* **Airborne Wind Turbines (AWT):** Toroidal inflatable shroud turbines with Venturi internal flow acceleration, dual counter-rotating titanium stators, swept Y-tail stabilizers, and tether bridles.
* **Drifters (Sky Wildlife):** Ambient, passive airborne creatures hovering near updrafts, ready to be collected or bonded with during flight.

---

## 🎮 Flight Controls

| Action | PC / Keyboard | Gamepad | Mobile |
| :--- | :--- | :--- | :--- |
| **Deploy / Stow Glider** | `Space` (in air) / `G` | `ButtonA` (in air) / `ButtonY` | Glider Toggle Button |
| **Pitch Down (Dive)** | `W` | `Left Thumbstick Up` | Virtual Joystick Up |
| **Pitch Up (Flare)** | `S` | `Left Thumbstick Down` | Virtual Joystick Down |
| **Bank / Roll (Turn)** | `A` / `D` | `Left Thumbstick Left / Right` | Virtual Joystick Left / Right |
| **Airbrake / Flare** | `LeftShift` | `Left Trigger` | Airbrake Button |
| **Wind Boost / Thermal Dive** | `Space` (Hold) | `Right Trigger` | Boost Button |

---

## 📁 Repository Structure

```
windbound/
├── src/
│   ├── ReplicatedStorage/
│   │   └── Windbound/
│   │       ├── Config/
│   │       │   ├── GameConfig.luau       # Global constants, physics rates, collision tags
│   │       │   ├── KiteConfig.luau       # Glider statistics, lift coefficients, turn rates
│   │       │   └── DrifterConfig.luau    # Drifter species, spawn bounds, collection radii
│   │       ├── Modules/
│   │       │   └── WindService.luau      # 3D Perlin wind vector sampling
│   │       └── Network/
│   │           └── NetworkService.luau   # RemoteEvents & RemoteFunctions definitions
│   │
│   ├── ServerScriptService/
│   │   └── WindboundServer/
│   │       ├── ServerMain.server.luau    # Server bootstrapper & lifecycle
│   │       └── Services/
│   │           ├── KiteServerService.luau    # Glider ownership, state sync, scaling & weld management
│   │           ├── DrifterServerService.luau # Drifter spawning, lifecycle & capture validation
│   │           └── UpdraftService.server.luau # Environmental updrafts & thermal zones
│   │
│   └── StarterPlayerScripts/
│       └── WindboundClient/
│           ├── ClientMain.client.luau    # Client initialization & controller orchestration
│           ├── Controllers/
│           │   ├── KiteFlightController.luau     # Aerodynamic flight physics, IK solver & wind animation
│           │   ├── KiteCameraController.luau     # Dynamic third-person flight camera with speed FOV
│           │   ├── UIController.luau             # Altimeter, airspeed, wind gauge & stamina HUD
│           │   ├── DrifterClientController.luau  # Drifter visual effects, audio & collection prompts
│           │   └── WorldDecorationsController.client.luau # Environmental wind particles & leaves
│           └── Input/
│               └── InputManager.luau     # Unified Cross-platform input processor (PC/Gamepad/Touch)
│
└── scripts/
    └── blender/
        └── generate_flying_turbine.py    # Procedural Blender 4.5 generator for Airborne Wind Turbines
```

---

## 🛠️ Blender 3D Asset Pipeline

To generate the Airborne Wind Turbine model in Blender:
```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --python scripts/blender/generate_flying_turbine.py
```
This procedurally generates:
* `FlyingTurbine.blend` (Complete Cycles / Eevee material setup with Solarpunk shaders)
* `FlyingTurbine.fbx` (Optimized FBX ready for Roblox Studio `MeshPart` import)
* Multi-angle high-resolution preview renders.

---

## 🤝 Contributing & Coordination

1. **Issue Tracking:** Check the GitHub Issues tab for upcoming milestones:
   * **Issue #1:** Drifter 3D FBX models rigging and windweaving capture mechanics.
   * **Issue #2:** Airborne Wind Turbine in-game deployment, tether physics, and rotor sound design.
2. **Coding Standards:**
   * All Luau scripts are strictly typed (`--!strict`).
   * Preserve client/server authority boundaries (physics simulated client-side with server verification).
