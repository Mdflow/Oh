--[[
	UNDERGROUND — Type Definitions
	TypeScript-style type definitions for Luau.
	Used for documentation, IDE support, and runtime validation.
]]

-- ============================================
-- PRIMITIVE TYPES
-- ============================================
export type UUID = string
export type Timestamp = number
export type Currency = number
export type XP = number
export type Level = number
export type HeatLevel = 0 | 1 | 2 | 3 | 4 | 5

-- ============================================
-- ENUMS
-- ============================================
export type DistrictId =
	| "Downtown"
	| "Industrial"
	| "Residential"
	| "Commercial"
	| "Warehouse"
	| "UndergroundParking"
	| "RestrictedZone"

export type VehicleCategory =
	| "Starter"
	| "Sedan"
	| "Sports"
	| "SUV"
	| "Van"
	| "Truck"
	| "Premium"

export type PackageRarity =
	| "Common"
	| "Uncommon"
	| "Rare"
	| "Epic"
	| "Legendary"

export type PackageType =
	| "Standard"
	| "Fragile"
	| "Timed"
	| "Hot"
	| "Cold"
	| "Live"
	| "Explosive"
	| "Data"
	| "Artifact"
	| "Prototype"

export type ContractType =
	| "Standard"
	| "Express"
	| "Fragile"
	| "Covert"
	| "Hot"
	| "Convoy"
	| "BlackMarket"

export type UpgradeSlot =
	| "Engine"
	| "Transmission"
	| "Suspension"
	| "Armor"
	| "Tires"
	| "FuelTank"
	| "Storage"
	| "Turbo"
	| "Stealth"

export type HideoutTier =
	| "Garage"
	| "Warehouse"
	| "Compound"
	| "Bunker"
	| "HQ"

-- ============================================
-- DATA STRUCTURES
-- ============================================

-- Player Profile (saved to DataStore)
export type PlayerProfile = {
	UserId: number,
	Username: string,
	DisplayName: string,

	-- Core progression
	Level: Level,
	XP: XP,
	TotalXP: XP,
	Prestige: number,

	-- Economy
	Cash: Currency,
	LifetimeEarnings: Currency,

	-- Reputation
	SyndicateRep: number,
	CorporateRep: number,
	StreetRep: number,

	-- Unlocks
	UnlockedDistricts: { DistrictId },
	UnlockedVehicles: { VehicleCategory },
	UnlockedUpgrades: { UpgradeSlot },
	UnlockedHideoutTiers: { HideoutTier },

	-- Stats
	Stats: PlayerStats,

	-- Current state
	CurrentDistrict: DistrictId?,
	CurrentVehicle: VehicleInstance?,
	ActiveContract: ContractInstance?,
	HeatLevel: HeatLevel,

	-- Inventory
	Inventory: { PackageInstance },
	VehicleGarage: { VehicleInstance },
	PackageStorage: { PackageInstance },

	-- Hideout
	HideoutTier: HideoutTier,
	HideoutUpgrades: { [string]: number },

	-- Daily/Weekly
	DailyLoginStreak: number,
	LastLoginDate: string, -- ISO date
	WeeklyChallengesCompleted: number,

	-- Settings
	Settings: PlayerSettings,

	-- Metadata
	CreatedAt: Timestamp,
	LastSavedAt: Timestamp,
	Version: number,
}

export type PlayerStats = {
	TotalDeliveries: number,
	SuccessfulDeliveries: number,
	FailedDeliveries: number,
	TotalDistance: number,
	TotalPlaytime: number,
	PoliceEscapes: number,
	PoliceCaught: number,
	MaxHeatReached: HeatLevel,
	VehiclesOwned: number,
	ContractsCompleted: { [ContractType]: number },
	PackagesDelivered: { [PackageRarity]: number },
	LongestDelivery: number,
	FastestDelivery: number,
	MostValuableDelivery: Currency,
}

export type PlayerSettings = {
	GraphicsQuality: "Low" | "Medium" | "High" | "Auto",
	MusicVolume: number,
	SFXVolume: number,
	VoiceVolume: number,
	CameraSensitivity: number,
	InvertCameraY: boolean,
	ControllerLayout: "Default" | "Southpaw" | "Custom",
	ShowDamageNumbers: boolean,
	ShowHeatWarnings: boolean,
	AutoAcceptContracts: boolean,
	Language: string,
}

-- Vehicle Instance (owned by player)
export type VehicleInstance = {
	Id: UUID, -- Unique instance ID
	Category: VehicleCategory,
	ModelName: string, -- References Constants.VehicleModels

	-- Upgrades
	Upgrades: { [UpgradeSlot]: number }, -- Slot -> Level (0-max)

	-- Condition
	Durability: number, -- 0-100
	Fuel: number, -- 0-100

	-- Customization
	Livery: string?, -- Livery ID
	Color: Color3?,
	NeonColor: Color3?,

	-- State
	IsActive: boolean,
	SpawnLocation: Vector3?,

	-- Metadata
	PurchasedAt: Timestamp,
	TotalDistance: number,
	TotalDeliveries: number,
}

-- Package Instance (in world or inventory)
export type PackageInstance = {
	Id: UUID,
	Type: PackageType,
	Rarity: PackageRarity,

	-- Value
	BaseValue: Currency,
	CurrentValue: Currency, -- Decays with time/damage

	-- Physical
	Weight: number, -- Affects vehicle handling
	Size: Vector3,

	-- Condition
	Condition: number, -- 0-100
	MaxCondition: number,

	-- Contract link
	ContractId: UUID?,

	-- Metadata
	SpawnedAt: Timestamp,
	PickedUpAt: Timestamp?,
	DeliveredAt: Timestamp?,
	DamageHistory: { { Time: Timestamp, Amount: number, Cause: string } },
	SpecialFlags: { string }, -- e.g., "Fragile", "Timed", "Hot"
}

-- Contract Instance (active or available)
export type ContractInstance = {
	Id: UUID,
	Type: ContractType,

	-- Package
	PackageId: UUID,
	PackageRarity: PackageRarity,
	PackageType: PackageType,

	-- Locations
	PickupLocation: Vector3,
	PickupDistrict: DistrictId,
	DropoffLocation: Vector3,
	DropoffDistrict: DistrictId,

	-- Route
	Waypoints: { Vector3 },
	EstimatedDistance: number,
	EstimatedTime: number, -- Seconds

	-- Timing
	CreatedAt: Timestamp,
	ExpiresAt: Timestamp,
	AcceptedAt: Timestamp?,
	StartedAt: Timestamp?,
	CompletedAt: Timestamp?,

	-- Rewards
	BaseReward: Currency,
	DistanceBonus: Currency,
	TimeBonus: Currency,
	ConditionBonus: Currency,
	TotalReward: Currency,
	XPReward: XP,

	-- State
	Status: "Available" | "Accepted" | "Active" | "Completed" | "Failed" | "Expired",
	AssignedPlayer: number?, -- UserId
	Competitors: { number }, -- Other players who can see/compete

	-- Risk
	HeatGain: number,
	RiskLevel: number, -- 1-5
	RequiresVehicle: VehicleCategory?,
	RequiresUpgrade: UpgradeSlot?,

	-- Special
	IsCompetitive: boolean,
	IsEvent: boolean,
	EventId: string?,
}

-- Active Delivery Session (when contract is accepted)
export type DeliverySession = {
	ContractId: UUID,
	PlayerId: number,
	VehicleId: UUID,

	StartTime: Timestamp,
	LastCheckpoint: number,
	CheckpointsPassed: { number },

	CurrentHeat: HeatLevel,
	HeatGain: number,

	DistanceTraveled: number,
	TimeElapsed: number,

	ConditionAtStart: number,
	CurrentCondition: number,

	PoliceEngaged: boolean,
	Pursuers: { number }, -- Police unit IDs

	RouteDeviations: number,
	SpeedViolations: number,
	Collisions: number,
}

-- Hideout Instance
export type HideoutInstance = {
	Tier: HideoutTier,
	Level: number,

	-- Storage
	PackageCapacity: number,
	VehicleCapacity: number,
	CurrentPackages: { UUID },
	CurrentVehicles: { UUID },

	-- Upgrades
	Upgrades: { [string]: boolean }, -- e.g., "Workbench", "Armory", "IntelCenter"

	-- Passive
	PassiveIncome: Currency,
	LastIncomeCollection: Timestamp,

	-- Customization
	Theme: string?,
	Decorations: { [string]: { Position: Vector3, Rotation: Vector3 } },
}

-- Leaderboard Entry
export type LeaderboardEntry = {
	UserId: number,
	Username: string,
	DisplayName: string,
	Value: number, -- Score, cash, deliveries, etc.
	Rank: number,
	Metadata: { [string]: any }, -- Level, vehicle, etc.
	Timestamp: Timestamp,
}

-- Leaderboard Config
export type LeaderboardConfig = {
	Id: string,
	Name: string,
	Stat: string, -- e.g., "Cash", "TotalDeliveries", "MaxHeatReached"
	Order: "Descending" | "Ascending",
	ResetPeriod: "Never" | "Daily" | "Weekly" | "Monthly" | "Seasonal",
	MinEntries: number,
	MaxEntries: number,
}

-- Analytics Event
export type AnalyticsEvent = {
	EventName: string,
	UserId: number,
	Timestamp: Timestamp,
	Parameters: { [string]: any },
	SessionId: UUID,
}

-- Shop Item
export type ShopItem = {
	Id: string,
	Name: string,
	Description: string,
	Category: "Vehicle" | "Upgrade" | "Cosmetic" | "Consumable" | "Hideout" | "Bundle",
	Price: Currency,
	RobuxPrice: number?, -- If purchasable with Robux
	ProductId: number?, -- Roblox ProductId
	Requirements: { Level: number?, Reputation: { Faction: string, Amount: number }? },
	Rewards: { [string]: any },
	LimitedQuantity: number?,
	PurchaseLimit: number?, -- Per player
	Tags: { string },
}

-- Notification
export type Notification = {
	Id: UUID,
	Type: "Info" | "Success" | "Warning" | "Error" | "Contract" | "Delivery" | "LevelUp" | "Unlock" | "Event" | "Social",
	Title: string,
	Message: string,
	Icon: string?, -- Asset ID or emoji
	Duration: number?, -- Auto-dismiss after seconds
	Action: { Label: string, Callback: () -> () }?, -- Optional button
	Priority: number, -- Higher = shown first
	Timestamp: Timestamp,
	Read: boolean,
}

-- World State (server authoritative)
export type WorldState = {
	ActiveContracts: { [UUID]: ContractInstance },
	ActiveDeliveries: { [UUID]: DeliverySession },
	SpawnedPackages: { [UUID]: PackageInstance },
	ActivePolice: { [number]: PoliceUnit },
	ActiveEvents: { [string]: EventInstance },
	DistrictHeat: { [DistrictId]: HeatLevel },
	GlobalHeat: HeatLevel,
}

-- Police Unit
export type PoliceUnit = {
	Id: number,
	Type: "Patrol" | "Pursuit" | "Helicopter" | "Roadblock" | "SWAT",
	VehicleModel: Model,
	Position: Vector3,
	Target: Vector3?, -- Pursuit target
	State: "Idle" | "Patrolling" | "Investigating" | "Pursuing" | "Returning",
	HeatLevel: HeatLevel,
	District: DistrictId,
	Waypoints: { Vector3 },
	CurrentWaypoint: number,
}

-- Event Instance (live ops)
export type EventInstance = {
	Id: string,
	Type: "Heatwave" | "RarePackage" | "DoubleRewards" | "CommunityGoal" | "Seasonal",
	StartTime: Timestamp,
	EndTime: Timestamp,
	Active: boolean,
	Modifiers: { [string]: number }, -- e.g., { HeatMultiplier = 2, RewardMultiplier = 1.5 }
	Goals: { [string]: any }, -- For community goals
	Progress: number,
	Rewards: { [string]: any },
}

-- Save Data Structure (DataStore)
export type SaveData = {
	Profile: PlayerProfile,
	Vehicles: { [UUID]: VehicleInstance },
	Inventory: { PackageInstance },
	Storage: { PackageInstance },
	Garage: { VehicleInstance },
	Hideout: HideoutInstance,
	Contracts: { ContractInstance }, -- History
	Settings: PlayerSettings,
	Analytics: { SessionId: UUID, Events: { AnalyticsEvent } },
	Metadata: {
		Version: number,
		LastSave: Timestamp,
		Playtime: number,
		SessionCount: number,
	},
}

-- Remote Event Payloads
export type RemotePayloads = {
	RequestContract = { DistrictId: DistrictId? },
	AcceptContract = { ContractId: UUID },
	CompleteDelivery = { ContractId: UUID, Condition: number },
	CancelContract = { ContractId: UUID },
	PurchaseVehicle = { Category: VehicleCategory, ModelName: string, Customizations: { [string]: any }? },
	SellVehicle = { VehicleId: UUID },
	UpgradeVehicle = { VehicleId: UUID, Slot: UpgradeSlot },
	PurchaseUpgrade = { Slot: UpgradeSlot, Level: number },
	UpgradeHideout = { Tier: HideoutTier, UpgradeId: string },
	CollectHideoutIncome = {},
	RefuelVehicle = { VehicleId: UUID, Amount: number? },
	RepairVehicle = { VehicleId: UUID },
	EquipLivery = { VehicleId: UUID, LiveryId: string },
	SetVehicleColor = { VehicleId: UUID, Color: Color3 },
	RequestLeaderboard = { LeaderboardId: string },
	ReportPlayer = { TargetUserId: number, Reason: string },
	RequestSettings = {},
	UpdateSettings = { Settings: PlayerSettings },
}

-- Server -> Client Events
export type ServerToClientEvents = {
	SyncPlayerData = { Profile: PlayerProfile, Vehicles: { VehicleInstance }, Inventory: { PackageInstance } },
	ContractAdded = { Contract: ContractInstance },
	ContractUpdated = { ContractId: UUID, Updates: { [string]: any } },
	ContractRemoved = { ContractId: UUID },
	ContractAccepted = { Contract: ContractInstance, Session: DeliverySession },
	DeliveryProgress = { Session: DeliverySession },
	DeliveryComplete = { Rewards: { Cash: Currency, XP: XP }, Contract: ContractInstance },
	DeliveryFailed = { Reason: string, Penalties: { Cash: Currency?, XP: XP? } },
	HeatChanged = { Level: HeatLevel, Source: string },
	PoliceSpawned = { Unit: PoliceUnit },
	PoliceDespawned = { UnitId: number },
	PursuitStarted = { TargetId: number, Pursuers: { PoliceUnit } },
	PursuitEnded = { Escaped: boolean },
	VehicleSpawned = { Vehicle: VehicleInstance },
	VehicleDespawned = { VehicleId: UUID },
	VehicleUpdated = { VehicleId: UUID, Updates: { [string]: any } },
	LevelUp = { NewLevel: Level, Unlocks: { string } },
	PrestigeUp = { NewPrestige: number, Rewards: { [string]: any } },
	UnlockEarned = { Type: string, Id: string },
	Notification = { Notification },
	LeaderboardUpdated = { LeaderboardId: string, Entries: { LeaderboardEntry } },
	EventStarted = { Event: EventInstance },
	EventEnded = { EventId: string },
	EventProgress = { EventId: string, Progress: number },
	DailyRewardAvailable = { Day: number, Reward: { [string]: any } },
	DailyRewardClaimed = { Day: number, Reward: { [string]: any } },
	WeeklyChallengeUpdated = { Challenges: { { Id: string, Progress: number, Completed: boolean } } },
}

-- Client -> Server Events
export type ClientToServerEvents = {
	RequestContract = RemotePayloads.RequestContract,
	AcceptContract = RemotePayloads.AcceptContract,
	CompleteDelivery = RemotePayloads.CompleteDelivery,
	CancelContract = RemotePayloads.CancelContract,
	PurchaseVehicle = RemotePayloads.PurchaseVehicle,
	SellVehicle = RemotePayloads.SellVehicle,
	UpgradeVehicle = RemotePayloads.UpgradeVehicle,
	PurchaseUpgrade = RemotePayloads.PurchaseUpgrade,
	UpgradeHideout = RemotePayloads.UpgradeHideout,
	CollectHideoutIncome = RemotePayloads.CollectHideoutIncome,
	RefuelVehicle = RemotePayloads.RefuelVehicle,
	RepairVehicle = RemotePayloads.RepairVehicle,
	EquipLivery = RemotePayloads.EquipLivery,
	SetVehicleColor = RemotePayloads.SetVehicleColor,
	RequestLeaderboard = RemotePayloads.RequestLeaderboard,
	ReportPlayer = RemotePayloads.ReportPlayer,
	RequestSettings = RemotePayloads.RequestSettings,
	UpdateSettings = RemotePayloads.UpdateSettings,
}

-- ============================================
-- VALIDATION HELPERS
-- ============================================
export type ValidationResult = {
	Success: boolean,
	Error: string?,
	Data: any?,
}

-- ============================================
-- TYPE GUARDS (Runtime)
-- ============================================
-- These would be implemented as functions in a Utils module
-- export function IsValidDistrict(value: any): boolean
-- export function IsValidVehicleCategory(value: any): boolean
-- export function IsValidPackageRarity(value: any): boolean
-- etc.

return nil -- This module only exports types