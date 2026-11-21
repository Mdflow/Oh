--[[
	UNDERGROUND — Remote Events Definition
	All RemoteEvents and RemoteFunctions used for client-server communication.
	This file documents the expected remotes; actual instances created at runtime.
]]

-- ============================================
- REMOTE EVENTS (Server -> Client)
- ============================================

local RemoteEvents = {
	-- Player Data
	SyncPlayerData = "RemoteEvent", -- Server -> Client: Full player data sync

	-- Contracts
	ContractAdded = "RemoteEvent", -- Server -> Client: New contract available
	ContractUpdated = "RemoteEvent", -- Server -> Client: Contract data changed
	ContractRemoved = "RemoteEvent", -- Server -> Client: Contract expired/removed
	ContractAccepted = "RemoteEvent", -- Server -> Client: Contract accepted, delivery started
	ContractBoardUpdate = "RemoteEvent", -- Server -> Client: Contract board refresh
	DeliveryProgress = "RemoteEvent", -- Server -> Client: Delivery progress update
	DeliveryComplete = "RemoteEvent", -- Server -> Client: Delivery finished successfully
	DeliveryFailed = "RemoteEvent", -- Server -> Client: Delivery failed

	-- Heat & Police
	HeatChanged = "RemoteEvent", -- Server -> Client: Heat level changed
	HeatEffectUpdate = "RemoteEvent", -- Server -> Client: Heat visual effects
	HeatUpdate = "RemoteEvent", -- Server -> Client: Heat level update
	PoliceSpawned = "RemoteEvent", -- Server -> Client: Police unit spawned
	PoliceDespawned = "RemoteEvent", -- Server -> Client: Police unit despawned
	PursuitStarted = "RemoteEvent", -- Server -> Client: Police pursuit initiated
	PursuitEnded = "RemoteEvent", -- Server -> Client: Pursuit ended

	-- Vehicles
	VehicleSpawned = "RemoteEvent", -- Server -> Client: Vehicle spawned
	VehicleDespawned = "RemoteEvent", -- Server -> Client: Vehicle despawned
	VehicleUpdated = "RemoteEvent", -- Server -> Client: Vehicle data updated

	-- Progression
	LevelUp = "RemoteEvent", -- Server -> Client: Level up
	PrestigeUp = "RemoteEvent", -- Server -> Client: Prestige up
	UnlockEarned = "RemoteEvent", -- Server -> Client: New unlock
	XPGained = "RemoteEvent", -- Server -> Client: XP gained

	-- Economy
	CashChanged = "RemoteEvent", -- Server -> Client: Cash amount changed
	CurrencyEarned = "RemoteEvent", -- Server -> Client: Currency earned
	CurrencySpent = "RemoteEvent", -- Server -> Client: Currency spent

	-- Hideout
	HideoutUpgraded = "RemoteEvent", -- Server -> Client: Hideout upgraded
	HideoutIncomeReady = "RemoteEvent", -- Server -> Client: Passive income ready

	-- Social
	FriendOnline = "RemoteEvent", -- Server -> Client: Friend came online
	FriendOffline = "RemoteEvent", -- Server -> Client: Friend went offline
	FriendRequestReceived = "RemoteEvent", -- Server -> Client: Friend request
	FriendRequestAccepted = "RemoteEvent", -- Server -> Client: Friend request accepted
	PartyInvited = "RemoteEvent", -- Server -> Client: Party invitation
	PartyJoined = "RemoteEvent", -- Server -> Client: Joined party
	PartyLeft = "RemoteEvent", -- Server -> Client: Left party
	LeaderboardUpdated = "RemoteEvent", -- Server -> Client: Leaderboard data

	-- Events
	EventStarted = "RemoteEvent", -- Server -> Client: Event started
	EventEnded = "RemoteEvent", -- Server -> Client: Event ended
	EventProgress = "RemoteEvent", -- Server -> Client: Event progress

	-- Notifications
	Notification = "RemoteEvent", -- Server -> Client: Show notification

	-- Daily/Weekly
	DailyRewardAvailable = "RemoteEvent", -- Server -> Client: Daily reward ready
	DailyRewardClaimed = "RemoteEvent", -- Server -> Client: Daily reward claimed
	WeeklyChallengeUpdated = "RemoteEvent", -- Server -> Client: Weekly challenges updated

	-- Settings
	SettingsChanged = "RemoteEvent", -- Server -> Client: Setting changed

	-- Vehicle
	VehicleSpeedChanged = "RemoteEvent", -- Client -> Server/Client: Speed update
	VehicleGearChanged = "RemoteEvent", -- Client -> Server/Client: Gear change
	VehicleRPMChanged = "RemoteEvent", -- Client -> Server/Client: RPM update
	VehicleFuelChanged = "RemoteEvent", -- Client -> Server/Client: Fuel update
	VehicleDurabilityChanged = "RemoteEvent", -- Client -> Server/Client: Durability update
	VehicleNitroChanged = "RemoteEvent", -- Client -> Server/Client: Nitro update
	VehicleCollision = "RemoteEvent", -- Client -> Server/Client: Collision
	VehicleEngineStarted = "RemoteEvent", -- Client -> Server/Client: Engine start
	VehicleEngineStopped = "RemoteEvent", -- Client -> Server/Client: Engine stop
	VehicleGearChanged = "RemoteEvent", -- Client -> Server/Client: Gear change
	VehicleCameraToggle = "RemoteEvent", -- Client -> Server/Client: Camera toggle
	VehicleLightsToggle = "RemoteEvent", -- Client -> Server/Client: Lights toggle
	VehicleHorn = "RemoteEvent", -- Client -> Server/Client: Horn
	VehicleNitro = "RemoteEvent", -- Client -> Server/Client: Nitro
	VehicleShiftUp = "RemoteEvent", -- Client -> Server/Client: Shift up
	VehicleShiftDown = "RemoteEvent", -- Client -> Server/Client: Shift down

	-- UI Navigation
	UINavigateUp = "RemoteEvent", -- Client -> Server: UI nav up
	UINavigateDown = "RemoteEvent", -- Client -> Server: UI nav down
	UINavigateLeft = "RemoteEvent", -- Client -> Server: UI nav left
	UINavigateRight = "RemoteEvent", -- Client -> Server: UI nav right
	UIConfirm = "RemoteEvent", -- Client -> Server: UI confirm
	UICancel = "RemoteEvent", -- Client -> Server: UI cancel
	UIBack = "RemoteEvent", -- Client -> Server: UI back

	-- Menu
	MenuAction = "RemoteEvent", -- Client -> Server: Menu action

	-- Chat
	ChatMessageReceived = "RemoteEvent", -- Server -> Client: Chat message

	-- Heat
	HeatUpdate = "RemoteEvent", -- Server -> Client: Heat level update
	HeatEffectUpdate = "RemoteEvent", -- Server -> Client: Heat effects

	-- Police
	PoliceSpawned = "RemoteEvent", -- Server -> Client: Police spawned
	PoliceDespawned = "RemoteEvent", -- Server -> Client: Police despawned
	PursuitStarted = "RemoteEvent", -- Server -> Client: Pursuit started
	PursuitEnded = "RemoteEvent", -- Server -> Client: Pursuit ended

	-- GPS
	GPSWaypointUpdated = "RemoteEvent", -- Server -> Client: GPS waypoint
	GPSArrivedAtDropoff = "RemoteEvent", -- Server -> Client: Arrived at dropoff
	GPSWaypointIndexChanged = "RemoteEvent", -- Server -> Client: Waypoint index

	-- District
	DistrictChanged = "RemoteEvent", -- Server -> Client: District changed

	-- Weather/Time
	WeatherChanged = "RemoteEvent", -- Server -> Client: Weather
	TimeOfDayChanged = "RemoteEvent", -- Server -> Client: Time

	-- Custom Waypoint
	CustomWaypointSet = "RemoteEvent", -- Server -> Client: Custom waypoint
	CustomWaypointCleared = "RemoteEvent", -- Server -> Client: Waypoint cleared

	-- Weather
	WeatherChanged = "RemoteEvent", -- Server -> Client: Weather change
	TimeOfDayChanged = "RemoteEvent", -- Server -> Client: Time change

	-- Input Mode
	InputModeChanged = "RemoteEvent", -- Server -> Client: Input mode

	-- Vehicle Input
	VehicleInput = "RemoteEvent", -- Client -> Server: Vehicle input

	-- Debug
	DebugLog = "RemoteEvent", -- Server -> Client: Debug log
	ErrorOccurred = "RemoteEvent", -- Server -> Client: Error
}

-- ============================================
- REMOTE FUNCTIONS (Client -> Server, returns value)
- ============================================

local RemoteFunctions = {
	-- Settings
	RequestSettings = "RemoteFunction", -- Client -> Server: Get settings
	UpdateSettings = "RemoteFunction", -- Client -> Server: Update settings

	-- Contracts
	RequestContract = "RemoteFunction", -- Client -> Server: Get contract board
	AcceptContract = "RemoteFunction", -- Client -> Server: Accept contract
	CompleteDelivery = "RemoteFunction", -- Client -> Server: Complete delivery
	CancelContract = "RemoteFunction", -- Client -> Server: Cancel contract

	-- Vehicles
	PurchaseVehicle = "RemoteFunction", -- Client -> Server: Buy vehicle
	SellVehicle = "RemoteFunction", -- Client -> Server: Sell vehicle
	UpgradeVehicle = "RemoteFunction", -- Client -> Server: Upgrade vehicle
	PurchaseUpgrade = "RemoteFunction", -- Client -> Server: Purchase upgrade
	UpgradeHideout = "RemoteFunction", -- Client -> Server: Upgrade hideout
	CollectHideoutIncome = "RemoteFunction", -- Client -> Server: Collect income
	RefuelVehicle = "RemoteFunction", -- Client -> Server: Refuel
	RepairVehicle = "RemoteFunction", -- Client -> Server: Repair
	EquipLivery = "RemoteFunction", -- Client -> Server: Equip livery
	SetVehicleColor = "RemoteFunction", -- Client -> Server: Set color

	-- Leaderboards
	RequestLeaderboard = "RemoteFunction", -- Client -> Server: Get leaderboard

	-- Social
	SendFriendRequest = "RemoteFunction", -- Client -> Server: Send friend request
	AcceptFriendRequest = "RemoteFunction", -- Client -> Server: Accept friend request
	DeclineFriendRequest = "RemoteFunction", -- Client -> Server: Decline friend request
	RemoveFriend = "RemoteFunction", -- Client -> Server: Remove friend
	CreateParty = "RemoteFunction", -- Client -> Server: Create party
	InviteToParty = "RemoteFunction", -- Client -> Server: Invite to party
	JoinParty = "RemoteFunction", -- Client -> Server: Join party
	LeaveParty = "RemoteFunction", -- Client -> Server: Leave party
	KickFromParty = "RemoteFunction", -- Client -> Server: Kick from party

	-- Chat
	SendChatMessage = "RemoteFunction", -- Client -> Server: Send message

	-- Reporting
	ReportPlayer = "RemoteFunction", -- Client -> Server: Report player

	-- Contracts
	CancelContract = "RemoteFunction", -- Client -> Server: Cancel contract
}

-- ============================================
- REMOTE CREATION SCRIPT
- ============================================

-- This script should run once on server startup to create all remotes
local function CreateRemotes()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local remotesFolder = Instance.new("Folder")
	remotesFolder.Name = "Remotes"
	remotesFolder.Parent = ReplicatedStorage

	-- Create RemoteEvents
	for name, _ in pairs(RemoteEvents) do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotesFolder
	end

	-- Create RemoteFunctions
	for name, _ in pairs(RemoteFunctions) do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = remotesFolder
	end

	-- Assets folder for UI/Models
	local assetsFolder = Instance.new("Folder")
	assetsFolder.Name = "Assets"
	assetsFolder.Parent = ReplicatedStorage

	-- Vehicles
	local vehiclesFolder = Instance.new("Folder")
	vehiclesFolder.Name = "Vehicles"
	vehiclesFolder.Parent = assetsFolder

	-- Packages
	local packagesFolder = Instance.new("Folder")
	packagesFolder.Name = "Packages"
	packagesFolder.Parent = assetsFolder

	-- Police
	local policeFolder = Instance.new("Folder")
	policeFolder.Name = "Police"
	policeFolder.Parent = assetsFolder

	-- UI Assets
	local uiFolder = Instance.new("Folder")
	uiFolder.Name = "UI"
	uiFolder.Parent = assetsFolder

	print("All remotes and asset folders created successfully!")
end

-- Run on server
if game:GetService("RunService"):IsServer() then
	CreateRemotes()
end

return {
	RemoteEvents = RemoteEvents,
	RemoteFunctions = RemoteFunctions,
}