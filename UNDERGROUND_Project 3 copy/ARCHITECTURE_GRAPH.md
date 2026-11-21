# UNDERGROUND Project Architecture Graph

> Visual representation of the UNDERGROUND Roblox game architecture. Render this in Obsidian with the Mermaid plugin enabled.

---

## 🏗️ High-Level Architecture

```mermaid
graph TB
    subgraph "🎮 GAME CORE"
        GDD[GDD.md<br/>Game Design Doc]
        README[README.md<br/>Setup Guide]
    end

    subgraph "📚 SHARED LIBRARY"
        Constants[Constants.lua<br/>500+ config lines]
        Types[Types.lua<br/>TypeScript defs]
        Utils[Utils.lua<br/>Helpers]
        Signals[Signals.lua<br/>Event System]
    end

    subgraph "🔌 REMOTE DEFINITIONS"
        Remotes[RemoteEvents.lua<br/>50+ Events + 15 Functions]
    end

    subgraph "🖥️ SERVER SYSTEMS"
        PlayerData[PlayerDataServer.lua<br/>DataStore v2 + Session Locking]
        Economy[EconomyServer.lua<br/>Currency + Vehicles + Robux]
        Inventory[InventoryServer.lua<br/>Packages + Garage + Storage]
        Contracts[ContractServer.lua<br/>7 Types + GPS + Competitive]
        Vehicles[VehicleServer.lua<br/>Auth Physics + 25 Models]
        Heat[HeatServer.lua<br/>0-5 Stars + Decay + Thresholds]
        Police[PoliceAI.lua<br/>Patrols + Pursuits + SWAT]
        MapMgr[MapManager.lua<br/>7 Districts + Pathfinding]
    end

    subgraph "🚀 SERVER ENTRY"
        MainServer[MainServer.lua<br/>Init + Cross-System + Admin]
    end

    subgraph "📱 CLIENT SYSTEMS"
        UI[UIController.lua<br/>HUD + Screens + Toasts]
        Input[InputManager.lua<br/>KB/Mouse/Gamepad/Touch]
        Vehicle[VehicleClient.lua<br/>60Hz Physics + Camera]
        Contracts[ContractClient.lua<br/>Board + GPS + Delivery]
        Map[MapClient.lua<br/>Minimap + GPS + Markers]
        Heat[HeatClient.lua<br/>Heat UI + Pursuit Music]
        Progression[ProgressionClient.lua<br/>XP + Levels + Prestige]
        Social[SocialClient.lua<br/>Friends + Party + Leaderboards]
        Notifications[NotificationsClient.lua<br/>Toasts + Achievement Popups]
        Settings[SettingsClient.lua<br/>100+ Settings + Accessibility]
    end

    subgraph "🎯 CLIENT ENTRY"
        MainClient[MainClient.lua<br/>10 Systems Init]
        Bootstrap[ClientBootstrap.lua<br/>Remotes + Signal Setup]
    end

    subgraph "🧠 TIZZY RBLX KNOWLEDGE VAULT"
        VaultIdx[00_INDEX.md<br/>Master MOC]
        Concepts[19 Concepts<br/>Building Blocks, 5 Guarantees...]
        Workflows[7 Workflows<br/>Market Research, MVP, LiveOps...]
        Videos[15 Video Notes<br/>Full transcripts + takeaways]
        Tools[6 Tools<br/>RoTrends, qptr.io, Creator Exchange...]
        Queries[4 Dataview Queries<br/>Auto-grouping]
        Canvases[4 Canvas Files<br/>Visual Diagrams]
    end

    %% Core connections
    GDD --> Constants
    README --> Constants
    Constants --> Remotes
    Constants --> PlayerData
    Constants --> Economy
    Constants --> Inventory
    Constants --> Contracts
    Constants --> Vehicles
    Constants --> Heat
    Constants --> Police
    Constants --> MapMgr
    Constants --> UI
    Constants --> Input
    Constants --> Vehicle
    Constants --> Contracts
    Constants --> Map
    Constants --> Heat
    Constants --> Progression
    Constants --> Social
    Constants --> Notifications
    Constants --> Settings
    
    Signals --> PlayerData
    Signals --> Economy
    Signals --> Inventory
    Signals --> Contracts
    Signals --> Vehicles
    Signals --> Heat
    Signals --> Police
    Signals --> MapMgr
    Signals --> UI
    Signals --> Input
    Signals --> Vehicle
    Signals --> Contracts
    Signals --> Map
    Signals --> Heat
    Signals --> Progression
    Signals --> Social
    Signals --> Notifications
    Signals --> Settings

    Remotes --> PlayerData
    Remotes --> Economy
    Remotes --> Inventory
    Remotes --> Contracts
    Remotes --> Vehicles
    Remotes --> Heat
    Remotes --> Police
    Remotes --> MapMgr
    Remotes --> UI
    Remotes --> Input
    Remotes --> Vehicle
    Remotes --> Contracts
    Remotes --> Map
    Remotes --> Heat
    Remotes --> Progression
    Remotes --> Social
    Remotes --> Notifications
    Remotes --> Settings

    MainServer --> PlayerData
    MainServer --> Economy
    MainServer --> Inventory
    MainServer --> Contracts
    MainServer --> Vehicles
    MainServer --> Heat
    MainServer --> Police
    MainServer --> MapMgr

    MainClient --> UI
    MainClient --> Input
    MainClient --> Vehicle
    MainClient --> Contracts
    MainClient --> Map
    MainClient --> Heat
    MainClient --> Progression
    MainClient --> Social
    MainClient --> Notifications
    MainClient --> Settings

    Bootstrap --> Remotes
    Bootstrap --> UI
    Bootstrap --> Input
    Bootstrap --> Vehicle
    Bootstrap --> Contracts
    Bootstrap --> Map
    Bootstrap --> Heat
    Bootstrap --> Progression
    Bootstrap --> Social
    Bootstrap --> Notifications
    Bootstrap --> Settings

    VaultIdx --> Concepts
    VaultIdx --> Workflows
    VaultIdx --> Videos
    VaultIdx --> Tools
    VaultIdx --> Queries
    VaultIdx --> Canvases

    Concepts --> Workflows
    Workflows --> Videos
    Videos --> Concepts
```

---

## 🔄 Data Flow Diagram

```mermaid
flowchart LR
    subgraph "PLAYER ACTION"
        Player[Player Input]
    end

    subgraph "CLIENT"
        InputMgr[InputManager]
        VehicleCl[VehicleClient]
        ContractCl[ContractClient]
        UI[UIController]
        MapCl[MapClient]
        HeatCl[HeatClient]
    end

    subgraph "NETWORK"
        Remotes[(RemoteEvents/Functions)]
    end

    subgraph "SERVER"
        VehicleSv[VehicleServer]
        ContractSv[ContractServer]
        HeatSv[HeatServer]
        PoliceAI[PoliceAI]
        EconomySv[EconomyServer]
        PlayerData[PlayerDataServer]
    end

    subgraph "DATA"
        DataStore[(DataStore v2)]
    end

    Player --> InputMgr
    InputMgr --> VehicleCl
    InputMgr --> ContractCl
    VehicleCl --> Remotes
    ContractCl --> Remotes
    Remotes --> VehicleSv
    Remotes --> ContractSv
    Remotes --> HeatSv
    Remotes --> PoliceAI
    Remotes --> EconomySv
    Remotes --> PlayerData
    
    VehicleSv --> DataStore
    ContractSv --> DataStore
    HeatSv --> DataStore
    PoliceAI --> DataStore
    EconomySv --> DataStore
    PlayerData --> DataStore
    
    VehicleSv --> Remotes
    ContractSv --> Remotes
    HeatSv --> Remotes
    PoliceAI --> Remotes
    EconomySv --> Remotes
    PlayerData --> Remotes
    Remotes --> VehicleCl
    Remotes --> ContractCl
    Remotes --> UI
    Remotes --> MapCl
    Remotes --> HeatCl
```

---

## 🎯 Core Gameplay Loop

```mermaid
flowchart TD
    Start([Player Joins]) --> Spawn[Spawn in Residential District]
    Spawn --> Explore[Explore City / Find Packages]
    Explore --> ContractBoard[Open Contract Board]
    ContractBoard --> SelectContract[Select Contract by Risk/Reward]
    SelectContract --> Prepare[Prepare Vehicle + Equipment]
    Prepare --> Route[Choose Route: Surface vs Underground]
    Route --> Drive[Drive to Pickup]
    Drive --> Pickup[Collect Package]
    Pickup --> Transport[Transport Through City]
    Transport --> AvoidPolice{Avoid Police?}
    AvoidPolice -->|Yes| Evade[Evade / Use Underground / Nitro]
    AvoidPolice -->|No| Chase[Police Pursuit]
    Chase --> Escape[Escape / Get Caught]
    Escape --> Dropoff[Reach Dropoff]
    Evade --> Dropoff
    Dropoff --> Complete[Complete Delivery]
    Complete --> Rewards[Earn Cash + XP + Reputation]
    Rewards --> Upgrade[Upgrade Vehicle / Hideout]
    Upgrade --> Explore
    
    style Start fill:#0f0,stroke:#0a0
    style Complete fill:#0f0,stroke:#0a0
    style Chase fill:#f00,stroke:#a00
    style Escape fill:#ff0,stroke:#aa0
```

---

## 📊 System Dependencies

```mermaid
graph LR
    subgraph "FOUNDATION"
        Constants[Constants.lua]
        Signals[Signals.lua]
        Utils[Utils.lua]
        Types[Types.lua]
    end

    subgraph "SERVER CORE"
        PlayerData[PlayerDataServer]
        Economy[EconomyServer]
        Inventory[InventoryServer]
    end

    subgraph "GAMEPLAY SYSTEMS"
        Contracts[ContractServer]
        Vehicles[VehicleServer]
        Heat[HeatServer]
        Police[PoliceAI]
        MapMgr[MapManager]
    end

    subgraph "CLIENT SYSTEMS"
        UI[UIController]
        Input[InputManager]
        Vehicle[VehicleClient]
        Contracts[ContractClient]
        Map[MapClient]
        Heat[HeatClient]
        Progression[ProgressionClient]
        Social[SocialClient]
        Notify[NotificationsClient]
        Settings[SettingsClient]
    end

    subgraph "ENTRY POINTS"
        MainServer[MainServer]
        MainClient[MainClient]
        Bootstrap[ClientBootstrap]
    end

    Constants --> PlayerData
    Constants --> Economy
    Constants --> Inventory
    Constants --> Contracts
    Constants --> Vehicles
    Constants --> Heat
    Constants --> Police
    Constants --> MapMgr
    Constants --> UI
    Constants --> Input
    Constants --> Vehicle
    Constants --> Contracts
    Constants --> Map
    Constants --> Heat
    Constants --> Progression
    Constants --> Social
    Constants --> Notify
    Constants --> Settings

    Signals --> PlayerData
    Signals --> Economy
    Signals --> Inventory
    Signals --> Contracts
    Signals --> Vehicles
    Signals --> Heat
    Signals --> Police
    Signals --> MapMgr
    Signals --> UI
    Signals --> Input
    Signals --> Vehicle
    Signals --> Contracts
    Signals --> Map
    Signals --> Heat
    Signals --> Progression
    Signals --> Social
    Signals --> Notify
    Signals --> Settings

    PlayerData --> Contracts
    Economy --> Contracts
    Inventory --> Contracts
    Contracts --> Vehicles
    Contracts --> Heat
    Contracts --> Police
    Vehicles --> Economy
    Heat --> Police
    Police --> MapMgr
    MapMgr --> Contracts

    UI --> Input
    UI --> Vehicle
    UI --> Contracts
    UI --> Map
    UI --> Heat
    UI --> Progression
    UI --> Social
    UI --> Notify
    UI --> Settings

    Input --> Vehicle
    Vehicle --> Contracts
    Contracts --> Map
    Map --> Heat
    Heat --> UI
    Progression --> Economy
    Social --> UI
    Notify --> UI
    Settings --> All

    MainServer --> PlayerData
    MainServer --> Economy
    MainServer --> Inventory
    MainServer --> Contracts
    MainServer --> Vehicles
    MainServer --> Heat
    MainServer --> Police
    MainServer --> MapMgr

    MainClient --> UI
    MainClient --> Input
    MainClient --> Vehicle
    MainClient --> Contracts
    MainClient --> Map
    MainClient --> Heat
    MainClient --> Progression
    MainClient --> Social
    MainClient --> Notify
    MainClient --> Settings

    Bootstrap --> Remotes
    Bootstrap --> UI
    Bootstrap --> Input
    Bootstrap --> Vehicle
    Bootstrap --> Contracts
    Bootstrap --> Map
    Bootstrap --> Heat
    Bootstrap --> Progression
    Bootstrap --> Social
    Bootstrap --> Notify
    Bootstrap --> Settings
```

---

## 🎨 Canvas Files (Open in Obsidian)

| Canvas File | Description |
|-------------|-------------|
| `Canvas/Game Design Theory Canvas.canvas` | Visual map of 5 building blocks + 5 guarantees |
| `Canvas/Algorithm Discovery Canvas.canvas` | Farmers market analogy + two markets + beta mode hack |
| `Canvas/Live Ops Cycle Canvas.canvas` | Weekly calendar: Sat launch → Sun plan → Mon-Wed build → Fri test → Sat launch |
| `Canvas/MVP Development Canvas.canvas` | Phase gates: Assets → Programmer → Beta Launch → Iterate |

---

## 📈 Metrics Flow (Scientific Method)

```mermaid
flowchart TD
    Identify[Identify Worst Metric<br/>vs Similar Players Benchmark] --> Qual[Qualitative Research<br/>Discord + iPad Recordings + Feedback AI]
    Qual --> Quant[Quantitative Research<br/>Funnels + Retention + Device Split]
    Quant --> Comp[Competitor Research<br/>Play Top 3 Similar Players]
    Comp --> Hypothesis[Form Hypothesis<br/>If I change X, then Y improves<br/>because: Qual + Quant + Comp]
    Hypothesis --> Ship[Ship Update<br/>Patch daily / Update weekly]
    Ship --> Verify[Wait 7-Day Rolling Window<br/>Verify Improvement]
    Verify -->|Yes| Keep[Keep Change<br/>Research Next Worst Stat]
    Verify -->|No| Revert[Revert Immediately<br/>Form New Hypothesis]
    Keep --> Identify
    Revert --> Identify
```

---

## 📱 Platform-Specific Flow

```mermaid
flowchart LR
    subgraph "PC"
        KB[Keyboard/Mouse]
        HighRes[High Res UI]
        HighFPS[60+ FPS Target]
    end

    subgraph "MOBILE"
        Touch[Touch Controls]
        LargeUI[Large Touch Targets 48px+]
        Perf[30 FPS Minimum]
    end

    subgraph "CONSOLE"
        Gamepad[Gamepad Support]
        TVUI[10ft UI - 24px+ Text]
        Vibration[Haptic Feedback]
    end

    InputMgr[InputManager] --> KB
    InputMgr --> Touch
    InputMgr --> Gamepad
    
    UIController --> HighRes
    UIController --> LargeUI
    UIController --> TVUI
    
    VehicleClient --> HighFPS
    VehicleClient --> Perf
    VehicleClient --> Vibration
```

---

## 📋 Usage in Obsidian

1. **Enable Mermaid Plugin**: Settings → Community Plugins → Mermaid → Enable
2. **Open this file** in Obsidian - diagrams will render automatically
3. **Open Canvas files** from the `Canvas/` folder for visual editing
4. **Use Dataview queries** from `Queries/` folder for auto-generated views

---

*Generated for UNDERGROUND Roblox Project | Tizzy RBLX Methodology*