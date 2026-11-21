# UNDERGROUND — Game Design Document v1.0

> **Core Loop**: Player explores city → Discovers packages → Accepts contracts → Prepares vehicle/equipment → Chooses route → Transports through city → Avoids police/surveillance → Completes delivery → Earns money/XP → Invests in business expansion → Repeat

---

## 1. CORE FANTASY (The Primary Verb)

**"Operate an underground delivery business"**

- **Kid-at-Lunch Test**: "I deliver secret packages across the city while dodging cops" ✓
- **Third-Grade Reading Level**: "Underground Delivery" / "Secret Courier" / "City Runner"
- **Emotional Hook**: Risk vs Reward, Freedom vs Surveillance, Small Business vs System
- **Clickable Fantasy**: Neon-noir aesthetic, high-stakes deliveries, vehicle customization, city mastery

---

## 2. UNIQUE MECHANIC (The 20% Twist)

**"Dynamic Risk-Reward Routing"**

- Package value **directly determines** gameplay difficulty in real-time
- **Not just numbers** — Different deliveries spawn **different gameplay challenges**:
  - Low-value: Standard traffic, minimal patrols
  - Medium: Timed checkpoints, roving police cars
  - High: Helicopter surveillance, roadblocks, pursuit mechanics
  - Extreme: Multi-phase contracts, rival couriers, environmental hazards
- **Player Agency**: Choose route (highway vs alleys vs underground), vehicle, timing, equipment
- **Readability**: "Hot pursuit" = familiar from Need for Speed/GTA; "Heat level" = understood from Payday/GTA

---

## 3. LEVEL DESIGN (Proven Patterns + 20% Twist)

### Pattern 1: Linear Run (Escape Tsunami style)
- **Contract Path**: Pickup → Waypoints → Dropoff
- **Pressure Valves**: Safe zones (parking garages, hideouts, tunnels) where heat drops

### Pattern 2: Sky Islands → **Underground Network** (Grow a Garden 2 + BedWars hybrid)
- **Surface City**: High traffic, high surveillance, fast travel
- **Underground**: Tunnels, sewers, parking garages, maintenance shafts — Low surveillance, slower, maze-like
- **Verticality**: Multi-level highways, overpasses, underground connections
- **Void Mechanic**: Falling off elevated highways = respawn penalty (BedWars style)

### Districts (Each = Distinct Gameplay)
| District | Atmosphere | Gameplay Purpose |
|----------|------------|------------------|
| **Downtown** | Neon, vertical, dense | High-value contracts, heavy surveillance, vertical routing |
| **Industrial** | Gritty, wide roads, factories | Vehicle spawns, chop shops, bulk deliveries |
| **Residential** | Quiet, narrow streets | Low-heat routes, hideouts, shortcuts |
| **Commercial** | Glass towers, plazas | Mid-value, timed checkpoints, rooftop access |
| **Warehouse** | Loading docks, containers | Package spawns, storage, vehicle depots |
| **Underground Parking** | Dim, maze-like | Heat cooldown, shortcuts, player hideouts |
| **Restricted Zones** | High security, checkpoints | Extreme contracts, best rewards, highest risk |

---

## 4. TENSION (Stacked Types)

| Tension Type | Implementation | Visibility |
|--------------|----------------|------------|
| **PvE Chase** | Police cars, helicopters, drones pursue | Visible in first 30s (first contract) |
| **Time Pressure** | Contract timers, decaying package value | Always visible on HUD |
| **Heat System** | 0-5 stars — more stars = more aggressive response | Persistent HUD element |
| **Social/FOMO** | Other couriers visible, leaderboards, rare package alerts | Map markers, notifications |
| **Resource Pressure** | Fuel, vehicle health, equipment durability | Visible on vehicle HUD |

---

## 5. PROGRESSION (Long Game)

| Layer | System | Depth Source |
|-------|--------|--------------|
| **Money** | Cash from deliveries | Volume × Risk multiplier |
| **XP/Levels** | Per delivery + bonuses | Unlocks districts, vehicles, contracts |
| **Heat Management** | Legal fronts, bribes, safehouses | Meta-progression |
| **Vehicle Collection** | 7 categories × variants | Handling, storage, speed, durability |
| **Hideout Evolution** | 5 tiers: Garage → Warehouse → Compound → Bunker → HQ | Visual + functional upgrades |
| **Reputation** | Faction standing (Syndicate, Corp, Street) | Exclusive contracts, gear, safe passage |
| **Collection Index** | Package types, vehicle liveries, routes | Completionist drive |

---

## SYSTEMS REQUIRED (Programmer SOW)

| System | Description | Reference Game | Complexity |
|--------|-------------|----------------|------------|
| **Player Data & Save** | DataStore v2, session locking, backup | Blox Fruits | 3 |
| **Currency & Economy** | Server-authoritative, anti-exploit, logging | Pet Simulator X | 4 |
| **Inventory & Packages** | Weight/value/rarity, stackable, metadata | Pet Simulator X | 3 |
| **Contract Board** | Dynamic generation, rarity, expiration, competition | Uber Driver / Cargo Sim | 4 |
| **Vehicle System** | Physics tuning, upgrades, storage, fuel, damage | Car Dealership Tycoon | 5 |
| **Map & Districts** | StreamingEnabled, district boundaries, POI system | Brookhaven | 3 |
| **Police AI** | Patrols, pursuit, heat scaling, roadblocks | Need for Speed Heat | 5 |
| **Heat/Suspicion** | 0-5 stars, decay, actions that raise/lower | GTA / Payday | 4 |
| **Contract Generation** | Procedural, balanced, district-aware, competitive | Uber / DoorDash | 4 |
| **Progression/XP** | Levels, unlocks, reputation, daily/weekly | Blox Fruits | 3 |
| **Multiplayer/Replication** | Player visibility, competitive contracts, leaderboards | Brookhaven | 4 |
| **UI Framework** | React-like (Roact/Fusion), mobile-first, theming | Pet Simulator X | 4 |
| **Analytics/Telemetry** | Funnel events, retention hooks, A/B ready | Custom | 3 |
| **Admin/Moderation** | Kick, ban, give, stats wipe, heat reset | Standard | 2 |

---

## ASSETS REQUIRED (Builder/Artist SOW)

| Category | Count | Style Reference | Priority |
|----------|-------|-----------------|----------|
| **City Blocks** | 7 districts × 4-6 blocks | GTA V / Cyberpunk 2077 | P0 |
| **Road Network** | Highways, streets, alleys, tunnels | Cities: Skylines | P0 |
| **Buildings** | 50+ unique exteriors, 10+ interiors | GTA V | P0 |
| **Vehicles** | 25+ models (7 categories) | Forza / GTA V | P0 |
| **Vehicle Interiors** | 25+ detailed cockpits | Forza Horizon 5 | P1 |
| **Packages** | 15+ variants × 5 rarities | Cyberpunk item design | P0 |
| **Police Assets** | Cars, helicopters, drones, barriers | Need for Speed Heat | P0 |
| **Hideout Interiors** | 5 tiers × 3 rooms each | Payday 3 safehouse | P1 |
| **Props/Details** | 200+ (neon signs, traffic lights, debris) | Cyberpunk 2077 | P1 |
| **VFX/SFX** | 100+ (neon glow, rain, engine, sirens) | Cyberpunk / GTA | P1 |
| **UI Assets** | Icons, frames, animations, fonts | Cyberpunk 2077 / Death Stranding | P0 |

---

## MVP SCOPE (Launch Targets)

- [ ] **Core Loop**: Explore → Find Package → Contract → Deliver → Reward → Repeat
- [ ] **2 Districts**: Downtown + Industrial (fully playable)
- [ ] **3 Vehicle Categories**: Starter, Sedan, Van (with upgrades)
- [ ] **Heat System**: 0-3 stars, basic patrols, pursuit
- [ ] **Contract Types**: Standard, Timed, Fragile (3 types)
- [ ] **Progression**: Levels 1-15, 5 vehicles, 3 hideout tiers
- [ ] **Save/Load**: Full persistence
- [ ] **Mobile + Console**: Tested, zero friction
- [ ] **Beta Mode**: Enabled at launch
- [ ] **Funnel Tracking**: Every micro-step
- [ ] **Monetization**: Starter Pack (19 R$, double first delivery)

---

## MONETIZATION (Post-MVP)

| Product | Price | Type | Value |
|---------|-------|------|-------|
| **Starter Pack** | 19 R$ | Consumable | Double first 5 deliveries + exclusive livery |
| **Vehicle Pack: Sports** | 299 R$ | Gamepass | 3 sports cars + garage slot |
| **Vehicle Pack: Heavy** | 399 R$ | Gamepass | 2 trucks + 1 armored van |
| **Hideout: Penthouse** | 499 R$ | Gamepass | Premium hideout + passive income |
| **Syndicate Pass** | 799 R$ | Gamepass | Exclusive contracts + reputation boost |
| **Fuel/Repair Bundles** | 49-199 R$ | Consumable | Convenience (non-P2W) |
| **Cosmetic Liveries** | 99-299 R$ | Gamepass | Visual only |

---

## RETENTION HOOKS (Live Ops Ready)

| Hook | Frequency | Implementation |
|------|-----------|----------------|
| **Daily Contracts** | Daily | 3 rotating special contracts |
| **Weekly Challenge** | Weekly | "Deliver 50 packages in Industrial" |
| **Login Streak** | Daily | Escalating rewards (Day 7 = rare livery) |
| **Delivery Streak** | Per session | Bonus for consecutive no-fail deliveries |
| **Heat Events** | Weekend | "Heatwave" — double rewards, triple heat |
| **Rare Package Alert** | Random | Server-wide notification, competition |
| **Leaderboard Seasons** | Monthly | Top 100 = exclusive cosmetic |

---

## TECHNICAL ARCHITECTURE

```
ServerScriptService/
├── Systems/
│   ├── PlayerDataServer.lua      -- DataStore v2, session management
│   ├── EconomyServer.lua         -- Currency, transactions, logging
│   ├── InventoryServer.lua       -- Packages, items, weight/value
│   ├── ContractServer.lua        -- Generation, assignment, completion
│   ├── VehicleServer.lua         -- Spawning, ownership, physics sync
│   ├── HeatServer.lua            -- Heat calculation, police spawning
│   ├── ProgressionServer.lua     -- XP, levels, unlocks, reputation
│   ├── MultiplayerServer.lua     -- Player visibility, competition
│   └── AnalyticsServer.lua       -- Funnel events, telemetry
│
├── AI/
│   ├── PolicePatrol.lua          -- Waypoint patrols, district awareness
│   ├── PolicePursuit.lua         -- Chase behavior, roadblocks, spikes
│   └── TrafficAI.lua             -- Civilian traffic, yield behavior
│
└── Managers/
    ├── MapManager.lua            -- District streaming, POI registration
    ├── ContractGenerator.lua     -- Procedural contract creation
    └── EventManager.lua          -- Live ops events, seasonal content

ReplicatedStorage/
├── Shared/
│   ├── Constants.lua             -- All game constants, enums, config
│   ├── Types.lua                 -- TypeScript-style type definitions
│   ├── Utils.lua                 -- Math, string, table utilities
│   └── Signals.lua               -- Custom signal/event system
│
├── Modules/
│   ├── VehiclePhysics.lua        -- Shared physics constants, tuning
│   ├── ContractUtils.lua         -- Shared contract calculations
│   ├── HeatUtils.lua             -- Heat math, decay, thresholds
│   └── FormatUtils.lua           -- Currency, time, number formatting
│
├── Remotes/
│   ├── RequestContract.OnClientInvoke
│   ├── AcceptContract.OnServerEvent
│   ├── CompleteDelivery.OnServerEvent
│   ├── PurchaseVehicle.OnServerEvent
│   ├── UpgradeVehicle.OnServerEvent
│   ├── UpgradeHideout.OnServerEvent
│   ├── SyncPlayerData.OnClientEvent
│   ├── HeatChanged.OnClientEvent
│   ├── PoliceSpawned.OnClientEvent
│   └── ContractExpired.OnClientEvent
│
├── Assets/
│   ├── Vehicles/                 -- Vehicle models (cloned by server)
│   ├── Packages/                 -- Package models
│   ├── Police/                   -- Police vehicles, barriers
│   └── UI/                       -- UI prefabs (if using Fusion/Roact)

StarterPlayer/
├── StarterPlayerScripts/
│   ├── ClientBootstrap.lua       -- Initialization, module loading
│   ├── Systems/
│   │   ├── VehicleClient.lua     -- Input, camera, local physics
│   │   ├── ContractClient.lua    -- Contract UI, markers, navigation
│   │   ├── HeatClient.lua        -- Heat HUD, warnings, effects
│   │   ├── MapClient.lua         -- Minimap, district markers, GPS
│   │   ├── ProgressionClient.lua -- XP bar, level up effects
│   │   └── SocialClient.lua      -- Player list, leaderboards
│   ├── UI/
│   │   ├── UIController.lua      -- Screen management, transitions
│   │   ├── HUD.lua               -- Main gameplay HUD
│   │   ├── ContractBoard.lua     -- Contract selection UI
│   │   ├── VehicleDealership.lua -- Vehicle browsing/purchase
│   │   ├── Garage.lua            -- Vehicle management
│   │   ├── HideoutUI.lua         -- Hideout upgrades
│   │   ├── Inventory.lua         -- Package/inventory management
│   │   ├── Leaderboards.lua      -- Global/friend leaderboards
│   │   ├── Settings.lua          -- Graphics, controls, audio
│   │   └── Notifications.lua     -- Toast, alerts, rare package
│   └── Input/
│       └── InputManager.lua      -- Mobile/PC/Console unified input

StarterGui/
├── LoadingScreen.lua
├── MainMenu.lua
└── OnboardingFlow.lua

Workspace/
├── Map/
│   ├── Districts/                -- District folders (streamed)
│   ├── Roads/                    -- Road network (PathfindingService)
│   ├── Spawns/                   -- Player spawns, vehicle spawns
│   ├── PackageSpawns/            -- Package spawn points
│   ├── ContractBoards/           -- Physical contract board locations
│   ├── Hideouts/                 -- Hideout entrances/interiors
│   ├── PoliceStations/           -- Police spawn points
│   └── Navigation/               -- Pathfinding nodes, links
├── Live/                         -- Runtime instances (vehicles, packages)
└── Effects/                      -- Global lighting, atmosphere, weather
```

---

## DEVELOPMENT PHASES (Per Vault Workflow)

### Phase 1: Assets First (Week 1-2) — NO PROGRAMMER
- Map blockout (greybox) — 2 districts, road network, spawn points
- Key buildings (hero pieces) — 10 unique exteriors
- Vehicle base models — 3 categories, physics-ready
- Package models — 5 variants × 3 rarities
- Police assets — Car, helicopter, barriers
- UI mockups — All screens in Figma/Canva, mobile-tested

### Phase 2: Core Loop (Week 2-3)
- Player spawn → Find package → Contract → Deliver → Reward
- Contract board (physical + UI)
- Basic police patrols (no pursuit yet)
- Currency, XP, save/load
- Vehicle spawning + basic driving

### Phase 3: Risk & Tension (Week 3-4)
- Heat system (0-5 stars)
- Police pursuit AI
- Roadblocks, spikes, helicopter
- High-risk contracts
- Escape mechanics (underground, hideouts)

### Phase 4: Progression (Week 4-5)
- Vehicle dealership + upgrades
- Hideout system + upgrades
- Reputation/factions
- Daily/weekly missions

### Phase 5: Multiplayer (Week 5-6)
- Competitive contracts
- Leaderboards
- Player visibility
- Shared city events

### Phase 6: Polish (Week 6-7)
- Graphics: PBR, lighting, weather, neon
- Sound: Engine, sirens, ambient, music
- Animations: Character, vehicle, UI
- Performance: StreamingEnabled, LODs, culling
- Mobile/Console certification

---

## SUCCESS METRICS (Scientific Method)

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

## COMPETITIVE ANALYSIS (Purple Ocean Validation)

| Competitor | Fantasy | Gap We Exploit |
|------------|---------|----------------|
| **Delivery Simulators** | "Drive truck from A to B" | No risk, no city mastery, no heat system |
| **Car Dealership Tycoons** | "Buy cars, show off" | No purpose for vehicles, no gameplay loop |
| **Police/Robber Games** | "Chase or be chased" | No business progression, no routing strategy |
| **GTA-style RP** | "Live in city" | High friction, no clear loop, pay-to-win |

**Our Mutation**: **Risk-Reward Routing** — Package value changes the *gameplay*, not just the payout. Real-time heat management. City mastery matters. Vehicles are tools, not trophies.

---

## LAUNCH STRATEGY

1. **Beta Mode** → Optimize D1/Playtime/Heat balance with ads ($16/day)
2. **Thumbnail Testing** → 10 variants (Before/After vehicle, First-person cockpit, Chase scene)
3. **Title**: "Underground Courier" / "City Runner: Underground" / "Heat: Underground Delivery"
4. **Ads** → $16/day, 7 days, 20 creatives, stop when Home > Ads impressions
5. **Live Ops** → Weekly updates from Day 1 (Saturday launch cycle)

---

*Document Version: 1.0 | Author: Producer | Status: APPROVED FOR DEVELOPMENT*