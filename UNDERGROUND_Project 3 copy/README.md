# UNDERGROUND — Roblox Game Project

> A professionally architected Roblox game built following the Tizzy RBLX development methodology.

## 🎮 Game Concept

**UNDERGROUND** — You operate an underground package delivery business in a massive metropolitan city. The core hook: **"The more valuable your package, the more dangerous the delivery."**

Players discover valuable packages, accept delivery contracts, prepare vehicles/equipment, choose routes through a detailed city, avoid police surveillance, compete for lucrative opportunities, and expand their criminal enterprise.

---

## 📁 Project Structure

```
UNDERGROUND_Project/
├── GDD.md                           # Game Design Document (this is your bible)
├── README.md                        # This file
├── ReplicatedStorage/
│   ├── Shared/
│   │   ├── Constants.lua            # ALL game constants, enums, configs
│   │   ├── Types.lua                # TypeScript-style type definitions
│   │   ├── Utils.lua                # Math, string, table, validation utilities
│   │   └── Signals.lua              # Event system (Signal, Property, EventBus, NetworkSignal)
│   ├── Remotes/
│   │   └── RemoteEvents.lua         # All RemoteEvents/RemoteFunctions definitions
│   └── Assets/                      # Models, UI, sounds (populated at runtime)
├── ServerScriptService/
│   ├── MainServer.lua               # Server initialization (place as Script)
│   └── Systems/
│       ├── PlayerDataServer.lua     # DataStore v2, session locking, profiles
│       ├── EconomyServer.lua        # Currency, transactions, vehicles, hideouts
│       ├── InventoryServer.lua      # Packages, garage, hideout storage
│       ├── ContractServer.lua       # Procedural contracts, delivery tracking
│       ├── VehicleServer.lua        # Server-authoritative vehicle physics
│       ├── HeatServer.lua           # 0-5 star heat system, police response
│       ├── PoliceAI.lua             # Patrols, pursuits, roadblocks, helicopters
│       └── MapManager.lua           # Districts, POIs, navigation, streaming
├── StarterPlayer/
│   └── StarterPlayerScripts/
│       ├── MainClient.lua           # Client initialization (LocalScript)
│       ├── ClientBootstrap.lua      # Remote setup, system loading
│       └── Systems/
│           ├── UIController.lua     # HUD, screens, toasts, animations
│           ├── InputManager.lua     # Keyboard/Mouse/Gamepad/Touch unified
│           ├── VehicleClient.lua    # Local physics, camera, sounds, nitro
│           ├── ContractClient.lua   # Contract board, GPS, delivery tracking
│           ├── MapClient.lua        # Minimap, GPS, district tracking
│           ├── HeatClient.lua       # Heat UI, pursuit music, sirens
│           ├── ProgressionClient.lua # XP, levels, prestige, stats panel
│           ├── SocialClient.lua     # Friends, parties, leaderboards, chat
│           ├── NotificationsClient.lua # Toasts, achievement popups
│           └── SettingsClient.lua   # Graphics, audio, controls, accessibility
└── TizzyRBLX_Vault/                 # Knowledge vault from Tizzy RBLX YouTube
    ├── 00_INDEX.md                  # Vault entry point
    ├── Concepts/                    # Core mental models
    ├── Workflows/                   # Step-by-step processes
    ├── Videos/                      # Video notes with timestamps
    ├── Tools/                       # External tool references
    ├── Queries/                     # Dataview queries
    └── Canvas/                      # Visual diagrams
```

---

## 🚀 Quick Start

### Server Setup
1. Place `ServerScriptService/MainServer.lua` as a **Script** in `ServerScriptService`
2. Create folder `ServerScriptService/Systems` and place all system files there
3. Create `ReplicatedStorage/Remotes` folder - remotes auto-created on server start
4. Create `ReplicatedStorage/Shared` and place shared modules there
4. Create `ReplicatedStorage/Assets/Vehicles`, `Packages`, `Police`, `UI` folders

### Client Setup
1. Place `StarterPlayer/StarterPlayerScripts/MainClient.lua` as a **LocalScript** in `StarterPlayerScripts`
2. Create `StarterPlayerScripts/Systems` folder and place all client systems there

### First Run
1. Start Play Solo in Roblox Studio
2. Server creates all RemoteEvents/RemoteFunctions automatically
2. Client initializes all 10 systems in dependency order
3. Main Menu appears - click "START OPERATION" to begin

---

## 🏗️ Architecture Principles (from Tizzy RBLX Vault)

### Game Design Building Blocks
| Block | UNDERGROUND Implementation |
|-------|---------------------------|
| **Fantasy** | "Underground courier in a neon city" |
| **Unique Mechanic** | Dynamic Risk-Reward Routing (package value = difficulty) |
| **Level Design** | Surface city + Underground network (GTA + BedWars hybrid) |
| **Tension** | Heat system (0-5 stars), police pursuit, time pressure, PvP competition |
| **Progression** | Vehicles, hideouts, reputation, collection index |

### 5 Viral Guarantees
1. **Clickable Fantasy** — "I deliver secret packages while dodging cops" ✓
2. **Great Onboarding** — Interactive first delivery, zero UI tutorial ✓
3. **Socialization** — Competitive contracts, visible couriers, leaderboards ✓
4. **Simple + Depth** — Drive → Deliver → Upgrade, infinite route mastery ✓
5. **Clippable** — Police chases, nitro boosts, near-miss deliveries ✓

### Pareto Principle (20% Innovation)
- 80% proven: Delivery loop, vehicle progression, police heat
- 20% novel: Dynamic risk-reward routing, surface/underground dual layer, package-type mechanics

### Purple Ocean Strategy
- High demand: Delivery games, driving games, crime games
- Poor execution: No dynamic routing, no dual-layer map, static difficulty
- **Our mutation**: Package value = real-time gameplay difficulty

---

## 🔧 Key Systems Overview

### Server Systems

| System | Responsibility | Key Features |
|--------|---------------|--------------|
| **PlayerDataServer** | DataStore v2, session locking | Auto-save, backup, migration, offline protection |
| **EconomyServer** | Cash, vehicles, hideouts, Robux | Transaction logging, anti-exploit, product callbacks |
| **InventoryServer** | Packages, garage, hideout storage | Weight limits, condition decay, hideout tiers |
| **ContractServer** | Procedural generation, delivery tracking | 7 contract types, 5 rarities, competitive contracts |
| **VehicleServer** | Server-authoritative physics | 7 categories, 25+ models, upgrades, nitro |
| **HeatServer** | 0-5 star system, decay, thresholds | District heat, global heat, source tracking |
| **PoliceAI** | Patrols, pursuit, roadblocks, SWAT | Scales with heat, predictive pathfinding |
| **MapManager** | 7 districts, POIs, navigation | StreamingEnabled, pathfinding, weather/time |

### Client Systems

| System | Responsibility | Key Features |
|--------|---------------|--------------|
| **UIController** | HUD, screens, transitions | Neon theme, toast system, level-up animations |
| **InputManager** | Unified KB/M/Gamepad/Touch | Vehicle bindings, UI navigation, touch steering |
| **VehicleClient** | Local physics, camera, sounds | 60Hz simulation, drift, nitro, engine sounds |
| **ContractClient** | Contract board, GPS, delivery flow | Dynamic waypoints, competitive contracts |
| **MapClient** | Minimap, GPS, district tracking | ViewportFrame camera, police/POI markers |
| **HeatClient** | Heat UI, pursuit music, sirens | Screen effects, pursuit UI, siren sounds |
| **ProgressionClient** | XP bar, levels, prestige, stats | Floating XP, level-up animation, stats panel |
| **SocialClient** | Friends, parties, leaderboards | Party invites, chat, leaderboards |
| **NotificationsClient** | Toasts, achievement popups | Queue system, auto-dismiss, history |
| **SettingsClient** | 7 categories, 100+ settings | Live apply, persistence, accessibility |

---

## 📊 Development Workflow (Per Vault)

### Phase 1: Assets First (Week 1-2)
```
Map blockout → Key buildings → Vehicle bases → Package models → Police assets → UI mockups
```

### Phase 2: Core Loop (Week 2-3)
```
Player spawn → Find package → Accept contract → Deliver → Reward → Repeat
```

### Phase 3: Risk & Tension (Week 3-4)
```
Heat system → Police patrols → Pursuit AI → Roadblocks → Helicopters → SWAT
```

### Phase 4: Progression (Week 4-5)
```
Vehicle dealership → Upgrades → Hideout tiers → Reputation → Daily/weekly missions
```

### Phase 5: Multiplayer (Week 5-6)
```
Competitive contracts → Leaderboards → Party system → Shared events
```

### Phase 6: Polish (Week 6-7)
```
PBR materials → Lighting → Weather → Sound design → Animations → Performance
```

---

## 🎯 Key Implementation Details

### DataStore v2 Pattern (PlayerDataServer)
```lua
-- Session locking prevents data corruption
local lockId = GenerateLockId()
AcquireSessionLock(userId) -- Returns lockId or fails
-- ... modify profile ...
SavePlayerData(userId, profile, lockId) -- Atomic with lock verification
ReleaseSessionLock(userId, lockId)
```

### Signal System (Signals.lua)
```lua
-- Fire and forget
Signals.GameSignals.ContractAccepted:Fire(userId, contract, session)

-- With callback
local connection = Signals.GameSignals.HeatChanged:Connect(function(level)
    UIController.UpdateHeat(level)
end)
connection:Disconnect() -- Cleanup
```

### Scientific Method for Updates (ContractServer/EconomyServer)
```lua
-- Hypothesis: "If I add multi-server collection, Avg Play Time ↑"
-- Evidence: 1) Player feedback 2) Competitor has it 3) 2:30 retention drop-off
-- Ship → Wait 7 days → Verify → Keep/Revert
```

### Vehicle Physics (VehicleServer/Client)
```lua
-- Server-authoritative, client-predicted
-- Server: Authoritative position, collision, damage
-- Client: Input prediction, camera, sounds, particles
-- Reconciliation: Server corrects position every 200ms
```

---

## 🎨 Art Direction

### Visual Style
- **Cyberpunk/Neon Noir** — Dark charcoal backgrounds, neon green/cyan accents
- **PBR Materials** — Metallic car paint, wet asphalt reflections, neon glow
- **Lighting** — Night cycle dominant, volumetric fog, dynamic shadows
- **Weather** — Rain, fog, clear — affects visibility and handling

### UI Theme (Constants.UITheme)
```lua
Colors = {
    Background = "#0D0D0D",
    Surface = "#1A1A1A",
    Primary = "#00FF88",    -- Neon green
    Secondary = "#00AAFF",  -- Cyan
    Accent = "#FFD700",     -- Gold
    Danger = "#FF3333",
    Warning = "#FFDD00",
}
```

---

## 📈 Success Metrics (Target)

| Metric | Target | Measurement |
|--------|--------|-------------|
| **D1 Retention** | >40% | Analytics → Engagement |
| **D7 Retention** | >15% | Analytics → Engagement |
| **Avg Session** | >12 min | Analytics → Engagement |
| **Payer Conversion** | >3% | Monetization → Overview |
| **ARPPU** | >$15 | Monetization → Overview |
| **PTR/QPTR** | >2.5% | Acquisition → Home Recs |
| **Co-play Rate** | >20% | Acquisition → Similar Players |

---

## 🛠️ Development Commands

### Admin Commands (In-Game Chat)
```
!givecash [player] [amount]    -- Give cash
!givexp [player] [amount]      -- Give XP
!setheat [player] [0-5]        -- Set heat level
!spawnvehicle [category] [model] -- Spawn vehicle
!spawnpolice [heat]            -- Deploy police
!spawnpackage [district]       -- Refresh contract board
!resetdata [player]            -- Wipe player data
```

### Debug Keys (In-Game)
| Key | Action |
|-----|--------|
| F1 | Toggle debug mode |
| F2 | Toggle stats panel |
| F3 | Toggle contract board |
| F4 | Toggle garage |
| F5 | Toggle hideout |
| F6 | Toggle leaderboards |
| F7 | Toggle settings |
| F8 | Toggle social panel |
| F9 | Toggle contract board |
| F10 | Toggle stats |
| Ctrl+Shift+R | Reload UI |
| Ctrl+Shift+C | Clear notifications |
| Ctrl+Shift+S | Save settings |

---

## 📦 Deployment Checklist

### Pre-Launch
- [ ] All 8 server systems tested in Play Solo
- [ ] All 10 client systems tested in Play Solo
- [ ] DataStore v2 migration tested
- [ ] Cross-system integration verified
- [ ] Mobile/Console/PC tested
- [ ] Performance: 60 FPS on mid-tier mobile
- [ ] Memory < 600 MB on mobile
- [ ] All RemoteEvents/Functions created
- [ ] Analytics events firing correctly
- [ ] Monetization products configured
- [ ] Beta Mode enabled for launch

### Launch Week
- [ ] Beta Mode → Disable after stats optimized
- [ ] $16/day ads for 7 days
- [ ] Monitor Home Impressions > Ad Impressions
- [ ] Daily patches for critical bugs
- [ ] Weekly content updates scheduled
- [ ] Community Discord active
- [ ] Admin abuses/events scheduled

---

## 📚 References

### Tizzy RBLX Knowledge Vault
All development principles sourced from `@tizzyrblx12` YouTube channel (21.2K subs, 37.8K median views):
- Game Design Building Blocks
- Blue Ocean / Red Ocean / Purple Ocean Strategy
- 5 Viral Game Guarantees
- Pareto Principle (20% Innovation)
- Scientific Method for Game Updates
- Coal's 3-Item Checklist
- Games to Watch Method
- Live Ops Weekly Cycle
- Personal Branding for Hiring
- T-Shaped Employees
- AI Prototyping Hack

### External Tools
- **RoTrends** — CCU tracking, genre trends
- **Creator Exchange** — Keyword research, gap analysis
- **qptr.io** — Thumbnail mobile/desktop/console preview
- **Prepublish.ai** — Transcripts, hook analysis, channel scanner
- **Trello + Loom** — Project management, async communication

---

## 📄 License & Credits

**Game Design & Architecture**: Based on Tizzy RBLX methodology
**Code Architecture**: Custom modular Luau architecture
**Art Direction**: Cyberpunk/Neon Noir aesthetic
**Target Platform**: Roblox (PC, Mobile, Console, Tablet)

---

*Built with the Tizzy RBLX methodology: "Simple scales, fancy fails."*