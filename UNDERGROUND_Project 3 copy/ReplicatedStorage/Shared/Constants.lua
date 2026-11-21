--[[
	UNDERGROUND — Shared Constants
	All game configuration, enums, and constants in one place.
	Single source of truth for both client and server.
]]

local Constants = {}

-- ============================================
-- GAME METADATA
-- ============================================
Constants.GAME = {
	Name = "UNDERGROUND",
	Version = "1.0.0",
	PlaceId = game.PlaceId,
	-- DataStore keys
	DataStoreKey = "Underground_v1",
	PlayerDataKey = "PlayerData",
	GlobalDataKey = "GlobalData",
	-- Analytics
	AnalyticsEnabled = true,
	BetaMode = true, -- Set false for full launch
}

-- ============================================
-- DISTRICTS
-- ============================================
Constants.Districts = {
	Downtown = {
		Id = 1,
		Name = "Downtown",
		DisplayName = "DOWNTOWN",
		Color = Color3.fromHex("#00FFFF"), -- Cyan
		HeatMultiplier = 1.5,
		ContractValueMultiplier = 1.3,
		SurveillanceLevel = 4,
		UnlockLevel = 1,
		Description = "Neon canyons. High risk, high reward.",
		Landmarks = {"Central Plaza", "Skyway Towers", "Neon Alley", "Metro Hub"},
	},
	Industrial = {
		Id = 2,
		Name = "Industrial",
		DisplayName = "INDUSTRIAL",
		Color = Color3.fromHex("#FF8800"), -- Orange
		HeatMultiplier = 1.0,
		ContractValueMultiplier = 1.0,
		SurveillanceLevel = 2,
		UnlockLevel = 3,
		Description = "Wide roads, heavy cargo. Vehicle paradise.",
		Landmarks = {"Freight Yard", "Refinery", "Container Port", "Chop Shop"},
	},
	Residential = {
		Id = 3,
		Name = "Residential",
		DisplayName = "RESIDENTIAL",
		Color = Color3.fromHex("#00FF88"), -- Mint
		HeatMultiplier = 0.7,
		ContractValueMultiplier = 0.8,
		SurveillanceLevel = 1,
		UnlockLevel = 1,
		Description = "Quiet streets. Perfect for cooling off.",
		Landmarks = {"Suburbia", "Park District", "School Zone", "Safehouse Row"},
	},
	Commercial = {
		Id = 4,
		Name = "Commercial",
		DisplayName = "COMMERCIAL",
		Color = Color3.fromHex("#FF00AA"), -- Magenta
		HeatMultiplier = 1.2,
		ContractValueMultiplier = 1.1,
		SurveillanceLevel = 3,
		UnlockLevel = 5,
		Description = "Glass towers, timed drops. Precision required.",
		Landmarks = {"Financial District", "Shopping Arcade", "Rooftop Network", "Data Center"},
	},
	Warehouse = {
		Id = 5,
		Name = "Warehouse",
		DisplayName = "WAREHOUSE",
		Color = Color3.fromHex("#8844FF"), -- Purple
		HeatMultiplier = 0.9,
		ContractValueMultiplier = 1.2,
		SurveillanceLevel = 2,
		UnlockLevel = 8,
		Description = "Bulk storage. High volume, hidden routes.",
		Landmarks = {"Container Maze", "Cold Storage", "Loading Docks", "Underground Vault"},
	},
	UndergroundParking = {
		Id = 6,
		Name = "UndergroundParking",
		DisplayName = "UNDERGROUND",
		Color = Color3.fromHex("#FFFFFF"), -- White
		HeatMultiplier = 0.5,
		ContractValueMultiplier = 0.9,
		SurveillanceLevel = 1,
		UnlockLevel = 10,
		Description = "The deep city. Heat vanishes here.",
		Landmarks = {"Tunnel Network", "Maintenance Shafts", "Black Market", "Hidden Garage"},
	},
	RestrictedZone = {
		Id = 7,
		Name = "RestrictedZone",
		DisplayName = "RESTRICTED",
		Color = Color3.fromHex("#FF0000"), -- Red
		HeatMultiplier = 2.5,
		ContractValueMultiplier = 2.0,
		SurveillanceLevel = 5,
		UnlockLevel = 20,
		Description = "Maximum security. Elite couriers only.",
		Landmarks = {"Government Complex", "Secure Facility", "Black Site", "Helipad"},
	},
}

-- Ordered list for iteration
Constants.DistrictOrder = {
	"Downtown", "Industrial", "Residential", "Commercial",
	"Warehouse", "UndergroundParking", "RestrictedZone"
}

-- ============================================
-- VEHICLE CATEGORIES
-- ============================================
Constants.VehicleCategories = {
	Starter = {
		Id = 1,
		Name = "Starter",
		DisplayName = "STARTER",
		BasePrice = 0, -- Free first vehicle
		UnlockLevel = 1,
		Slots = 1,
		Color = Color3.fromHex("#888888"),
	},
	Sedan = {
		Id = 2,
		Name = "Sedan",
		DisplayName = "SEDAN",
		BasePrice = 5000,
		UnlockLevel = 3,
		Slots = 2,
		Color = Color3.fromHex("#00AAFF"),
		Stats = { Speed = 65, Acceleration = 60, Handling = 75, Durability = 60, Storage = 3, Fuel = 100 },
	},
	Sports = {
		Id = 3,
		Name = "Sports",
		DisplayName = "SPORTS",
		BasePrice = 25000,
		UnlockLevel = 8,
		Slots = 2,
		Color = Color3.fromHex("#FF3333"),
		Stats = { Speed = 95, Acceleration = 90, Handling = 85, Durability = 45, Storage = 1, Fuel = 80 },
	},
	SUV = {
		Id = 4,
		Name = "SUV",
		DisplayName = "SUV",
		BasePrice = 15000,
		UnlockLevel = 5,
		Slots = 3,
		Color = Color3.fromHex("#66CC00"),
		Stats = { Speed = 55, Acceleration = 50, Handling = 55, Durability = 85, Storage = 5, Fuel = 120 },
	},
	Van = {
		Id = 5,
		Name = "Van",
		DisplayName = "VAN",
		BasePrice = 12000,
		UnlockLevel = 4,
		Slots = 4,
		Color = Color3.fromHex("#FFAA00"),
		Stats = { Speed = 50, Acceleration = 40, Handling = 45, Durability = 80, Storage = 8, Fuel = 110 },
	},
	Truck = {
		Id = 6,
		Name = "Truck",
		DisplayName = "HEAVY",
		BasePrice = 50000,
		UnlockLevel = 15,
		Slots = 2,
		Color = Color3.fromHex("#FF6600"),
		Stats = { Speed = 40, Acceleration = 30, Handling = 35, Durability = 95, Storage = 15, Fuel = 150 },
	},
	Premium = {
		Id = 7,
		Name = "Premium",
		DisplayName = "ELITE",
		BasePrice = 150000,
		UnlockLevel = 25,
		Slots = 1,
		Color = Color3.fromHex("#FFD700"),
		Stats = { Speed = 100, Acceleration = 95, Handling = 90, Durability = 70, Storage = 4, Fuel = 90 },
	},
}

Constants.VehicleCategoryOrder = {"Starter", "Sedan", "Sports", "SUV", "Van", "Truck", "Premium"}

-- ============================================
-- VEHICLE UPGRADE SLOTS
-- ============================================
Constants.VehicleUpgrades = {
	Engine = {
		Id = "Engine",
		DisplayName = "ENGINE",
		MaxLevel = 5,
		BaseCost = 1000,
		CostMultiplier = 2.5,
		StatBonuses = { Speed = 5, Acceleration = 5 },
		Description = "Increases top speed and acceleration",
	},
	Transmission = {
		Id = "Transmission",
		DisplayName = "TRANSMISSION",
		MaxLevel = 4,
		BaseCost = 1500,
		CostMultiplier = 2.2,
		StatBonuses = { Acceleration = 8, Handling = 3 },
		Description = "Faster gear shifts, better power delivery",
	},
	Suspension = {
		Id = "Suspension",
		DisplayName = "SUSPENSION",
		MaxLevel = 4,
		BaseCost = 1200,
		CostMultiplier = 2.0,
		StatBonuses = { Handling = 10, Durability = 5 },
		Description = "Better cornering, absorbs impacts",
	},
	Armor = {
		Id = "Armor",
		DisplayName = "ARMOR",
		MaxLevel = 5,
		BaseCost = 2000,
		CostMultiplier = 2.5,
		StatBonuses = { Durability = 15 },
		Description = "Reinforced chassis, bullet resistance",
	},
	Tires = {
		Id = "Tires",
		DisplayName = "TIRES",
		MaxLevel = 3,
		BaseCost = 800,
		CostMultiplier = 1.8,
		StatBonuses = { Handling = 8, Speed = 3 },
		Description = "High-grip compounds for any surface",
	},
	FuelTank = {
		Id = "FuelTank",
		DisplayName = "FUEL TANK",
		MaxLevel = 3,
		BaseCost = 1000,
		CostMultiplier = 2.0,
		StatBonuses = { Fuel = 25 },
		Description = "Extended range between refuels",
	},
	Storage = {
		Id = "Storage",
		DisplayName = "CARGO EXPANSION",
		MaxLevel = 2,
		BaseCost = 3000,
		CostMultiplier = 3.0,
		StatBonuses = { Storage = 2 },
		Description = "Additional package slots",
	},
	Turbo = {
		Id = "Turbo",
		DisplayName = "TURBO",
		MaxLevel = 1,
		BaseCost = 10000,
		CostMultiplier = 1.0,
		StatBonuses = { Speed = 15, Acceleration = 10 },
		Description = "Nitrous injection system - limited use",
		UnlockLevel = 10,
	},
	Stealth = {
		Id = "Stealth",
		DisplayName = "STEALTH TECH",
		MaxLevel = 3,
		BaseCost = 5000,
		CostMultiplier = 2.5,
		StatBonuses = { HeatReduction = 15 },
		Description = "Reduces heat gain from deliveries",
		UnlockLevel = 12,
	},
}

-- ============================================
-- PACKAGE SYSTEM
-- ============================================
Constants.PackageRarities = {
	Common = {
		Id = 1,
		Name = "Common",
		DisplayName = "STANDARD",
		Color = Color3.fromHex("#AAAAAA"),
		ValueMultiplier = 1.0,
		HeatMultiplier = 1.0,
		Weight = 1,
		SpawnChance = 0.50,
		Description = "Routine deliveries. Low risk, steady income.",
	},
	Uncommon = {
		Id = 2,
		Name = "Uncommon",
		DisplayName = "SENSITIVE",
		Color = Color3.fromHex("#00AAFF"),
		ValueMultiplier = 1.5,
		HeatMultiplier = 1.2,
		Weight = 2,
		SpawnChance = 0.25,
		Description = "Requires care. Moderate heat attraction.",
	},
	Rare = {
		Id = 3,
		Name = "Rare",
		DisplayName = "HIGH-VALUE",
		Color = Color3.fromHex("#AA00FF"),
		ValueMultiplier = 2.5,
		HeatMultiplier = 1.5,
		Weight = 3,
		SpawnChance = 0.15,
		Description = "Valuable cargo. Police take notice.",
	},
	Epic = {
		Id = 4,
		Name = "Epic",
		DisplayName = "CLASSIFIED",
		Color = Color3.fromHex("#FF6600"),
		ValueMultiplier = 4.0,
		HeatMultiplier = 2.0,
		Weight = 4,
		SpawnChance = 0.07,
		Description = "Government secrets. Heavy surveillance.",
	},
	Legendary = {
		Id = 5,
		Name = "Legendary",
		DisplayName = "GHOST",
		Color = Color3.fromHex("#FFD700"),
		ValueMultiplier = 7.5,
		HeatMultiplier = 3.0,
		Weight = 5,
		SpawnChance = 0.03,
		Description = "Mythical cargo. City-wide manhunt.",
	},
}

Constants.PackageRarityOrder = {"Common", "Uncommon", "Rare", "Epic", "Legendary"}

-- Package types (flavor + special mechanics)
Constants.PackageTypes = {
	Standard = { Name = "Standard", Icon = "📦", Special = nil },
	Fragile = { Name = "Fragile", Icon = "⚠️", Special = "SpeedLimit", SpeedLimit = 40, Penalty = 0.5 },
	Timed = { Name = "Timed", Icon = "⏱️", Special = "TimeLimit", TimeMultiplier = 1.0, Penalty = 0.3 },
	Hot = { Name = "Hot", Icon = "🔥", Special = "HeatGain", HeatMultiplier = 1.5 },
	Cold = { Name = "Cold", Icon = "❄️", Special = "TempControl", RequiresCooling = true },
	Live = { Name = "Live Cargo", Icon = "💓", Special = "Careful", MaxGForce = 2.0 },
	Explosive = { Name = "Explosive", Icon = "💣", Special = "NoCrash", CrashPenalty = 1.0 },
	Data = { Name = "Data Drive", Icon = "💾", Special = "NoWifi", SignalJammer = true },
	Artifact = { Name = "Artifact", Icon = "🏺", Special = "Curse", RandomEvents = true },
	Prototype = { Name = "Prototype", Icon = "⚙️", Special = "Tech", UnlocksTech = true },
}

-- ============================================
-- CONTRACT SYSTEM
-- ============================================
Constants.ContractTypes = {
	Standard = {
		Id = "Standard",
		DisplayName = "STANDARD RUN",
		Description = "Pick up and deliver. No complications.",
		TimeMultiplier = 1.0,
		HeatGain = 1,
		RewardMultiplier = 1.0,
		MinLevel = 1,
	},
	Express = {
		Id = "Express",
		DisplayName = "EXPRESS",
		Description = "Tight deadline. Speed is everything.",
		TimeMultiplier = 0.6,
		HeatGain = 2,
		RewardMultiplier = 1.5,
		MinLevel = 3,
	},
	Fragile = {
		Id = "Fragile",
		DisplayName = "FRAGILE CARGO",
		Description = "Handle with care. No sudden movements.",
		TimeMultiplier = 1.2,
		HeatGain = 1,
		RewardMultiplier = 1.3,
		MinLevel = 2,
	},
	Covert = {
		Id = "Covert",
		DisplayName = "COVERT OPS",
		Description = "Stay off radar. Underground routes only.",
		TimeMultiplier = 1.5,
		HeatGain = 0, -- No heat if successful
		RewardMultiplier = 2.0,
		MinLevel = 10,
	},
	Hot = {
		Id = "Hot",
		DisplayName = "HOT PACKAGE",
		Description = "Already flagged. Police know you have it.",
		TimeMultiplier = 1.0,
		HeatGain = 3,
		RewardMultiplier = 2.5,
		MinLevel = 15,
	},
	Convoy = {
		Id = "Convoy",
		DisplayName = "CONVOY",
		Description = "Multi-vehicle run. Coordinate or fail.",
		TimeMultiplier = 1.3,
		HeatGain = 2,
		RewardMultiplier = 3.0,
		MinLevel = 20,
		RequiresParty = true,
	},
	BlackMarket = {
		Id = "BlackMarket",
		DisplayName = "BLACK MARKET",
		Description = "Illegal goods. Maximum risk, maximum reward.",
		TimeMultiplier = 1.2,
		HeatGain = 4,
		RewardMultiplier = 5.0,
		MinLevel = 30,
	},
}

-- ============================================
-- HEAT SYSTEM
-- ============================================
Constants.Heat = {
	MaxStars = 5,
	BaseDecayRate = 0.5, -- Stars per minute when not gaining
	DecayDelay = 10, -- Seconds after last gain before decay starts

	-- Heat gain sources
	Gains = {
		StandardDelivery = 1,
		ExpressDelivery = 2,
		CovertDelivery = 0, -- If successful
		CovertFailure = 3,
		HotDelivery = 3,
		ConvoyDelivery = 2,
		BlackMarketDelivery = 4,
		PoliceSpotted = 1,
		CollisionCivilian = 1,
		CollisionPolice = 2,
		EnterRestrictedZone = 2,
		SpeedingInZone = 1,
		Crash = 1,
		KillCivilian = 5, -- Instant max heat
	},

	-- Heat thresholds (stars required)
	Thresholds = {
		PatrolSpawn = 1, -- Police cars start patrolling
		HelicopterSpawn = 2, -- Helicopter surveillance
		Roadblocks = 3, -- Roadblocks on highways
		SpikeStrips = 3, -- Spike strips deployed
		SWAT = 4, -- SWAT vehicles, aggressive pursuit
		CityLockdown = 5, -- All exits blocked, maximum aggression
	},

	-- Visual/audio cues per level
	Effects = {
		[1] = { HUDColor = Color3.fromHex("#00FF88"), MusicIntensity = 0.2, SirenDistance = 200 },
		[2] = { HUDColor = Color3.fromHex("#FFDD00"), MusicIntensity = 0.4, SirenDistance = 400 },
		[3] = { HUDColor = Color3.fromHex("#FF8800"), MusicIntensity = 0.6, SirenDistance = 600 },
		[4] = { HUDColor = Color3.fromHex("#FF3300"), MusicIntensity = 0.8, SirenDistance = 800 },
		[5] = { HUDColor = Color3.fromHex("#FF0000"), MusicIntensity = 1.0, SirenDistance = 1000 },
	},
}

-- ============================================
-- POLICE AI
-- ============================================
Constants.Police = {
	Patrol = {
		VehicleCount = 8, -- Per district
		PatrolSpeed = 30,
		DetectionRange = 80,
		ReactionTime = 1.5,
	},
	Pursuit = {
		MaxPursuers = 4,
		PursuitSpeed = 80,
		RamThreshold = 0.7, -- Aggression 0-1
		BoxInAttempts = 3,
		GiveUpTime = 120, -- Seconds after losing sight
		GiveUpDistance = 500,
	},
	Helicopter = {
		SpawnHeat = 2,
		SpotlightRange = 100,
		TrackDuration = 30,
		CallBackupDelay = 10,
	},
	Roadblock = {
		SpawnHeat = 3,
		SetupTime = 5,
		Duration = 60,
		LaneCount = 2,
	},
	SpikeStrip = {
		SpawnHeat = 3,
		DeployTime = 2,
		EffectiveRange = 20,
		TireDamage = 100, -- Instant flat
	},
	SWAT = {
		SpawnHeat = 4,
		VehicleSpeed = 85,
		RamDamage = 50,
		OfficerCount = 4,
		WeaponRange = 50,
	},
}

-- ============================================
-- PROGRESSION
-- ============================================
Constants.Progression = {
	MaxLevel = 100,
	XPCurve = "Exponential", -- Linear, Exponential, Logarithmic
	BaseXP = 100,
	XPMultiplier = 1.15,

	-- Level unlocks
	LevelUnlocks = {
		[1] = { "Starter Vehicle", "Residential District", "Standard Contracts" },
		[3] = { "Sedan Category", "Express Contracts" },
		[4] = { "Van Category", "Fragile Contracts" },
		[5] = { "SUV Category", "Industrial District" },
		[8] = { "Sports Category", "Covert Contracts", "Commercial District" },
		[10] = { "Stealth Tech Upgrades", "Turbo Upgrade" },
		[12] = { "Warehouse District" },
		[15] = { "Truck Category", "Hot Contracts" },
		[18] = { "Restricted Zone Access" },
		[20] = { "Premium Category", "Convoy Contracts" },
		[25] = { "Black Market Contracts" },
		[30] = { "Elite Vehicle Skins" },
		[50] = { "Legendary Package Access" },
		[75] = { "Master Courier Title" },
		[100] = { "City Kingpin Title", "Golden Vehicle" },
	},

	-- Prestige system (post-100)
	Prestige = {
		Enabled = true,
		MaxPrestige = 10,
		XPMultiplierPerPrestige = 0.1, -- 10% bonus XP per prestige
		Rewards = { "Prestige Livery", "Prestige Title", "Stat Bonus" },
	},
}

-- ============================================
-- ECONOMY
-- ============================================
Constants.Economy = {
	StartingCash = 500,
	StartingXP = 0,

	-- Delivery rewards (base, before multipliers)
	BaseDeliveryReward = 100,
	DistanceRewardPerStud = 0.05,
	TimeBonusMax = 0.5, -- 50% bonus for fast delivery
	ConditionBonusMax = 0.3, -- 30% bonus for perfect condition

	-- Vehicle costs
	VehicleBasePrices = {
		Starter = 0,
		Sedan = 5000,
		Sports = 25000,
		SUV = 15000,
		Van = 12000,
		Truck = 50000,
		Premium = 150000,
	},

	-- Upgrade costs (base, see VehicleUpgrades for multipliers)
	UpgradeBaseCosts = {
		Engine = 1000,
		Transmission = 1500,
		Suspension = 1200,
		Armor = 2000,
		Tires = 800,
		FuelTank = 1000,
		Storage = 3000,
		Turbo = 10000,
		Stealth = 5000,
	},

	-- Hideout costs
	HideoutTiers = {
		{ Name = "Garage", Cost = 0, Storage = 5, Vehicles = 2, PassiveIncome = 0, UnlockLevel = 1 },
		{ Name = "Warehouse", Cost = 10000, Storage = 15, Vehicles = 4, PassiveIncome = 100, UnlockLevel = 5 },
		{ Name = "Compound", Cost = 50000, Storage = 30, Vehicles = 6, PassiveIncome = 500, UnlockLevel = 12 },
		{ Name = "Bunker", Cost = 200000, Storage = 50, Vehicles = 8, PassiveIncome = 2000, UnlockLevel = 20 },
		{ Name = "HQ", Cost = 1000000, Storage = 100, Vehicles = 12, PassiveIncome = 10000, UnlockLevel = 40 },
	},

	-- Daily/Weekly rewards
	DailyLoginRewards = {
		{ Day = 1, Cash = 100, XP = 50 },
		{ Day = 2, Cash = 200, XP = 100 },
		{ Day = 3, Cash = 300, XP = 150, Item = "FuelCan" },
		{ Day = 4, Cash = 400, XP = 200 },
		{ Day = 5, Cash = 500, XP = 250, Item = "RepairKit" },
		{ Day = 6, Cash = 750, XP = 350, Item = "StealthModule" },
		{ Day = 7, Cash = 1500, XP = 500, Item = "ExclusiveLivery" },
	},

	-- Robux products
	RobuxProducts = {
		StarterPack = { Price = 19, ProductId = 1234567890, Rewards = { Cash = 5000, XP = 1000, Livery = "Neon_Starter", DoubleDeliveries = 5 } },
		VehiclePackSports = { Price = 299, ProductId = 1234567891, Rewards = { Vehicles = {"Sports_1", "Sports_2", "Sports_3"}, GarageSlot = 1 } },
		VehiclePackHeavy = { Price = 399, ProductId = 1234567892, Rewards = { Vehicles = {"Truck_1", "ArmoredVan_1"}, GarageSlot = 1 } },
		HideoutPenthouse = { Price = 499, ProductId = 1234567893, Rewards = { HideoutTier = "Penthouse", PassiveIncome = 500 } },
		SyndicatePass = { Price = 799, ProductId = 1234567894, Rewards = { RepBoost = 5000, ExclusiveContracts = true, Livery = "Syndicate_Gold" } },
	},
}

-- ============================================
-- UI THEME
-- ============================================
Constants.UITheme = {
	Colors = {
		Background = Color3.fromHex("#0D0D0D"), -- Near black
		Surface = Color3.fromHex("#1A1A1A"), -- Dark charcoal
		SurfaceHover = Color3.fromHex("#242424"),
		SurfacePressed = Color3.fromHex("#151515"),
		Primary = Color3.fromHex("#00FF88"), -- Neon green
		PrimaryHover = Color3.fromHex("#00CC6E"),
		PrimaryPressed = Color3.fromHex("#00AA5E"),
		Secondary = Color3.fromHex("#00AAFF"), -- Cyan
		Accent = Color3.fromHex("#FFD700"), -- Gold
		Danger = Color3.fromHex("#FF3333"),
		Warning = Color3.fromHex("#FFDD00"),
		TextPrimary = Color3.fromHex("#FFFFFF"),
		TextSecondary = Color3.fromHex("#AAAAAA"),
		TextMuted = Color3.fromHex("#666666"),
		TextOnPrimary = Color3.fromHex("#000000"),
		Border = Color3.fromHex("#333333"),
		BorderFocus = Color3.fromHex("#00FF88"),
		Overlay = Color3.fromHex("#000000CC"),
		Success = Color3.fromHex("#00FF88"),
		Error = Color3.fromHex("#FF3333"),
		Info = Color3.fromHex("#00AAFF"),
	},

	Fonts = {
		Primary = Enum.Font.GothamBlack,
		Secondary = Enum.Font.GothamBold,
		Body = Enum.Font.GothamMedium,
		Mono = Enum.Font.RobotoMono,
		UI = Enum.Font.GothamSemibold,
	},

	CornerRadius = {
		Small = UDim.new(0, 4),
		Medium = UDim.new(0, 8),
		Large = UDim.new(0, 16),
		Round = UDim.new(1, 0),
	},

	Spacing = {
		XS = 4,
		SM = 8,
		MD = 16,
		LG = 24,
		XL = 32,
		XXL = 48,
	},

	Animation = {
		Fast = 0.1,
		Normal = 0.2,
		Slow = 0.3,
		Easing = Enum.EasingStyle.Quad,
		EasingDirection = Enum.EasingDirection.Out,
	},

	Shadows = {
		Elevation1 = { Offset = Vector2.new(0, 2), Blur = 4, Transparency = 0.8 },
		Elevation2 = { Offset = Vector2.new(0, 4), Blur = 8, Transparency = 0.6 },
		Elevation3 = { Offset = Vector2.new(0, 8), Blur = 16, Transparency = 0.4 },
		Elevation4 = { Offset = Vector2.new(0, 16), Blur = 24, Transparency = 0.3 },
	},
}

-- ============================================
-- MOBILE / CONSOLE SETTINGS
-- ============================================
Constants.Platform = {
	Mobile = {
		TouchTargetMinSize = 48, -- pixels
		JoystickSize = 120,
		ButtonSize = 56,
		FontSizeMultiplier = 1.15,
		HUDScale = 1.0,
		ShowVirtualButtons = true,
		SimplifyUI = true,
		ReduceParticles = true,
		ShadowQuality = 1,
	},
	Console = {
		DeadZone = 0.15,
		VibrationEnabled = true,
		FontSizeMultiplier = 1.25,
		HUDScale = 1.15,
		TextDistance = 3, -- meters for 10ft UI
		CursorSpeed = 800,
		AutoAimAssist = 0.3,
	},
	PC = {
		KeyboardHints = true,
		MouseSensitivity = 1.0,
		FOV = 90,
		HUDScale = 1.0,
	},
}

-- ============================================
-- PERFORMANCE SETTINGS
-- ============================================
Constants.Performance = {
	StreamingEnabled = true,
	StreamingMinRadius = 200,
	StreamingMaxRadius = 800,
	StreamingTargetRadius = 400,

	LOD = {
		VehicleHigh = 200,
		VehicleMedium = 500,
		VehicleLow = 1000,
		BuildingHigh = 300,
		BuildingMedium = 800,
		BuildingLow = 1500,
		PropHigh = 100,
		PropMedium = 300,
		PropLow = 600,
	},

	MaxParts = 200000,
	MaxVehicles = 50,
	MaxPolice = 20,
	MaxPackages = 100,
	MaxEffects = 200,

	CullingEnabled = true,
	FrustumCulling = true,
	OcclusionCulling = true,
}

-- ============================================
-- ANALYTICS EVENTS
-- ============================================
Constants.AnalyticsEvents = {
	-- Funnel events
	"Game_Start",
	"Onboarding_Complete",
	"First_Package_Found",
	"First_Contract_Accepted",
	"First_Delivery_Complete",
	"First_Vehicle_Purchased",
	"First_Hideout_Upgrade",
	"Level_5_Reached",
	"Level_10_Reached",
	"Level_25_Reached",
	"Level_50_Reached",
	"Prestige_1",

	-- Gameplay events
	"Contract_Accepted",
	"Contract_Completed",
	"Contract_Failed",
	"Contract_Expired",
	"Delivery_Complete",
	"Delivery_Failed_Crash",
	"Delivery_Failed_Police",
	"Delivery_Failed_Time",
	"Delivery_Failed_Damage",
	"Police_Pursuit_Start",
	"Police_Pursuit_Escape",
	"Police_Pursuit_Caught",
	"Heat_Level_Changed",
	"Heat_Max_Reached",
	"Vehicle_Purchased",
	"Vehicle_Upgraded",
	"Vehicle_Sold",
	"Hideout_Upgraded",
	"Package_Picked_Up",
	"Package_Delivered",
	"Package_Damaged",
	"Package_Lost",

	-- Social events
	"Contract_Competitive_Won",
	"Contract_Competitive_Lost",
	"Party_Formed",
	"Party_Joined",
	"Leaderboard_Top100",
	"Leaderboard_Top10",
	"Leaderboard_Top1",

	-- Monetization
	"StarterPack_Purchased",
	"VehiclePack_Purchased",
	"HideoutPack_Purchased",
	"SyndicatePass_Purchased",
	"Consumable_Purchased",
	"Robux_Spent",

	-- Retention
	"Daily_Login",
	"Weekly_Challenge_Complete",
	"Streak_7_Days",
	"Streak_30_Days",
	"Returning_Player_Day_1",
	"Returning_Player_Day_7",
	"Returning_Player_Day_30",
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================
function Constants.GetDistrict(idOrName)
	if type(idOrName) == "number" then
		for _, name in ipairs(Constants.DistrictOrder) do
			if Constants.Districts[name].Id == idOrName then
				return Constants.Districts[name], name
			end
		end
	else
		return Constants.Districts[idOrName], idOrName
	end
	return nil
end

function Constants.GetVehicleCategory(idOrName)
	if type(idOrName) == "number" then
		for _, name in ipairs(Constants.VehicleCategoryOrder) do
			if Constants.VehicleCategories[name].Id == idOrName then
				return Constants.VehicleCategories[name], name
			end
		end
	else
		return Constants.VehicleCategories[idOrName], idOrName
	end
	return nil
end

function Constants.GetPackageRarity(idOrName)
	if type(idOrName) == "number" then
		for _, name in ipairs(Constants.PackageRarityOrder) do
			if Constants.PackageRarities[name].Id == idOrName then
				return Constants.PackageRarities[name], name
			end
		end
	else
		return Constants.PackageRarities[idOrName], idOrName
	end
	return nil
end

function Constants.GetHeatEffect(level)
	level = math.clamp(level, 1, 5)
	return Constants.Heat.Effects[level]
end

function Constants.GetLevelUnlocks(level)
	return Constants.Progression.LevelUnlocks[level] or {}
end

function Constants.CalculateXPForLevel(level)
	if level <= 1 then return 0 end
	local xp = 0
	for i = 1, level - 1 do
		xp = xp + Constants.Progression.BaseXP * (Constants.Progression.XPMultiplier ^ (i - 1))
	end
	return math.floor(xp)
end

function Constants.FormatCurrency(amount)
	if amount >= 1000000 then
		return string.format("%.1fM", amount / 1000000)
	elseif amount >= 1000 then
		return string.format("%.1fK", amount / 1000)
	else
		return tostring(amount)
	end
end

function Constants.FormatTime(seconds)
	if seconds >= 3600 then
		return string.format("%dh %dm", math.floor(seconds / 3600), math.floor((seconds % 3600) / 60))
	elseif seconds >= 60 then
		return string.format("%dm %ds", math.floor(seconds / 60), seconds % 60)
	else
		return string.format("%ds", seconds)
	end
end

return Constants