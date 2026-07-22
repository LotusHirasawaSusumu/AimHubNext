# AimHubNext

A modular aimbot and visual assistance engine for Roblox, rebuilt with a clean architecture and the Rayfield UI library.

**Original project:** Aim Hub by c0rroison
**Modified by:** CookieLee

well use https://raw.githubusercontent.com/LotusHirasawaSusumu/AimHubNext/refs/heads/onlyc/main.lua
Dont use Main branch its not good

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Project Structure](#project-structure)
- [Usage](#usage)
- [Localization](#localization)
- [Configuration](#configuration)
- [Credits & Community](#credits--community)
- [Disclaimer](#disclaimer)

---

## Overview

AimHubNext is a heavily restructured fork of c0rroison's Aim Hub. The entire UI layer has been rewritten to use the **Rayfield UI** library in place of the original hand-rolled interface. The codebase has been split into discrete modules covering core state management, engine logic (aimbot, ESP, chams, rage, anti-aim), hook injection (silent aim), and UI construction.

Engine version: **v39**

---

## Features

### Aim Lock

| Feature | Description |
|---|---|
| System Master | Global on/off toggle for the entire engine |
| Wall Check | Raycast-based visibility filtering with exclusion lists |
| Auto Shoot | Automatic mouse click when locked onto a target, respects fire rate mode |
| Silent Aim | Redirects `mouse.Hit` without moving the camera |
| FOV Filter | Restricts targeting to a screen-pixel radius circle |
| Target Indicator | Dot on target plus a line drawn from the crosshair |
| FOV Pulse | Animated breathing effect on the FOV circle while aiming |
| Auto Switch | Re-acquires a new target after an elimination |
| Aim Mode | Toggle (press E) or Hold (hold E) |
| Priority | Closest distance, lowest HP, or nearest to crosshair |
| Fire Rate | Normal (0.15s), Fast (0.06s), Uzi (0.01s) |
| Smoothness | 1 (very slow) through 100 (instant snap) |
| FOV Radius | Pixel radius for target filtering |
| Max Distance | Maximum stud range (default 1000) |
| Prediction | Leading shots on moving targets |

### Rage Mode

| Feature | Description |
|---|---|
| Rage Master | Enables snap aim, hitbox expansion, kill aura, and anti-aim simultaneously |
| Snap Aim | Instant camera lock with no smoothing |
| Hitbox Expander | Client-side hitbox scaling, updated every 0.5s |
| Kill Aura | Auto-attacks nearby enemies at 0.15s intervals |
| Anti-Aim | 8 CS2-style rotation manipulation modes |
| Resolver | Forces aim to the real Head position, bypassing enemy anti-aim |
| Configurable per-feature: hitbox target part, expansion size (studs), aura range, AA speed, AA pitch |

### Visuals / ESP

| Feature | Description |
|---|---|
| Dual CHAMS | Green for visible targets, red for targets behind walls (raycast-based) |
| Legacy ESP | Single-color team-based outlines when CHAMS is disabled |
| FOV Circle | On-screen threat boundary ring |
| Opacity controls for visible chams, occluded chams, and legacy ESP |

### Customization

- Target part selection (Head / Torso) for legit mode
- Accent color swapping
- UI background transparency
- Frame border width

### Settings

- Save and load configuration
- Reset to defaults
- Unload engine
- Copy Discord invite link

---

## Project Structure

```
AimHubNext/
├── main.lua                   -- Entry point, bootstraps all modules
├── core/
│   ├── i18n.lua               -- Internationalization (English, Chinese)
│   ├── state.lua              -- Shared state and configuration values
│   ├── services.lua           -- Roblox service references
│   ├── styles.lua             -- Visual style constants
│   ├── utils.lua              -- Utility functions
│   └── lifecycle.lua          -- Engine startup and teardown
├── engine/
│   ├── drawings.lua           -- Drawing API primitives (FOV circle, indicator)
│   ├── chams.lua              -- Dual-color CHAMS rendering
│   ├── esp.lua                -- Legacy ESP outlines
│   ├── antiaim.lua            -- Anti-aim rotation logic
│   ├── rage.lua               -- Rage mode systems (snap, hitbox, aura)
│   └── aimbot.lua             -- Core aimbot loop and targeting
├── hooks/
│   └── silentaim.lua          -- mouse.Hit hook for silent aim
└── ui/
    ├── window.lua             -- Rayfield window creation
    ├── builder.lua            -- UI element construction helpers
    ├── tabs.lua               -- Tab definitions and layout
    └── discord.lua            -- Discord invite modal
```

---

## Usage

Execute the following in any Roblox script executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/LotusHirasawaSusumu/AimHubNext/refs/heads/main/main.lua"))()
```

That is the entire setup. The script fetches all required modules from the repository and initializes the engine automatically. The Rayfield UI menu will appear in-game once loading completes.

### Default Keybinds

| Key | Action |
|---|---|
| **E** | Activate aim lock (toggle or hold, depending on setting) |
| **RShift** | Minimize / restore the menu |

---

## Localization

AimHubNext ships with two languages:

| Code | Language |
|---|---|
| `en` | English (default) |
| `zh` | Simplified Chinese |

The language can be changed programmatically through the `i18n` module:

```lua
local i18n = require(path.to.core.i18n)
i18n.SetLanguage("zh")
```

Unknown language codes fall back to English automatically. Every UI string is routed through `i18n.T(key)`, so adding a new language only requires inserting another table in `core/i18n.lua`.

---

## Configuration

Settings are stored client-side and can be managed from the **Settings** tab:

- **SAVE CONFIG** -- persists current settings
- **RESET DEFAULTS** -- reverts all values to factory state
- **UNLOAD ENGINE** -- cleanly disconnects all hooks, removes drawings, and destroys the UI

---

## Credits & Community

- **c0rroison** -- original Aim Hub author
- **CookieLee** -- AimHubNext mod, architecture rewrite, Rayfield UI migration
- **Rayfield** -- UI library

Discord: [https://discord.gg/8jSF8vSvbJ](https://discord.gg/8jSF8vSvbJ)

This Mod Line2Dc: [https://discord.com/users/1379293542723092480](https://discord.com/users/1379293542723092480)

---

## Disclaimer

This project is provided for educational and research purposes only. Using exploits or cheat software in Roblox violates the Roblox Terms of Service and may result in account termination. The authors assume no responsibility for any consequences resulting from the use of this software.
