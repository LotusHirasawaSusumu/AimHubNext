# AimHubNext

AimHubNext is a collection of Roblox tools intended to provide aim-enhancement utilities. It began as a restart of "Aim Hub Suite" and is provided as an open-source project for learning and experimentation.

Important note
- Use this project only in accordance with the terms and rules of the platforms you use. Misuse of tools that affect game behavior can violate terms of service and cause account sanctions.

Status
- Scaffolded: project structure and placeholder files have been added.
- Development: implementation pending — modules are present as placeholders for your content.

What you'll find here
- A lightweight project layout dividing core utilities, engine (game logic), UI components, and hooks.

Repository structure

```
AimHubNext/
├── main.lua              ← Entry point, loads all modules
├── core/
│   ├── state.lua         ← Global state, settings, defaults
│   ├── i18n.lua          ← Multi-language support
│   ├── services.lua      ← Roblox service references
│   ├── styles.lua        ← UI colors/styles
│   └── utils.lua         ← Shared utility functions
├── engine/
│   ├── aimbot.lua        ← Aimbot core logic
│   ├── chams.lua         ← Dual chams system
│   ├── esp.lua           ← Legacy ESP
│   ├── antiaim.lua       ← Anti-aim system
│   └── rage.lua          ← Rage mode (hitbox, killaura)
├── ui/
│   ├── builder.lua       ← UI component builders
│   ├── layout.lua        ← Main window layout
│   ├── tabs.lua          ← Tab registration
│   └── discord.lua       ← Discord prompt modal
└── hooks/
    └── silentaim.lua     ← Silent aim metamethod hook
```

Getting started
1. Clone the repository.
2. Open and fill the module files under each folder with your implementation (this repo currently contains placeholders).

Contributing
- Feel free to open issues and pull requests. Label clearly what each change does and keep commits small.

License
- Add a LICENSE file to declare the project's license.
