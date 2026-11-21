--[[
	UNDERGROUND — Player Data Server
	DataStore v2 implementation with session locking, backup, and migration.
	Server-authoritative player data management.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)

local PlayerDataServer = {}

-- ============================================
-- DATASTORE CONFIGURATION
-- ============================================

local DATASTORE_NAME = Constants.GAME.DataStoreKey
local PLAYER_DATA_KEY = Constants.GAME.PlayerDataKey
local GLOBAL_DATA_KEY = Constants.GAME.GlobalDataKey
local BACKUP_SUFFIX = "_backup"
local VERSION_KEY = "_version"

local dataStore = DataStoreService:GetDataStore(DATASTORE_NAME)
local globalDataStore = DataStoreService:GetDataStore(DATASTORE_NAME .. "_Global")

-- Session locking
local activeSessions = {} -- [userId] = { lockId, lastHeartbeat }
local LOCK_TIMEOUT = 30 -- seconds
local HEARTBEAT_INTERVAL = 10 -- seconds
local SAVE_INTERVAL = 60 -- seconds
local MAX_RETRIES = 3
local RETRY_DELAY = 2

-- ============================================
-- DEFAULT PLAYER PROFILE
-- ============================================

local function CreateDefaultProfile(player: Player)
	return {
		UserId = player.UserId,
		Username = player.Name,
		DisplayName = player.DisplayName,

		-- Core progression
		Level = 1,
		XP = 0,
		TotalXP = 0,
		Prestige = 0,

		-- Economy
		Cash = Constants.Economy.StartingCash,
		LifetimeEarnings = 0,

		-- Reputation
		SyndicateRep = 0,
		CorporateRep = 0,
		StreetRep = 0,

		-- Unlocks
		UnlockedDistricts = { "Residential", "Downtown" },
		UnlockedVehicles = { "Starter" },
		UnlockedUpgrades = {},
		UnlockedHideoutTiers = { "Garage" },

		-- Stats
		Stats = {
			TotalDeliveries = 0,
			SuccessfulDeliveries = 0,
			FailedDeliveries = 0,
			TotalDistance = 0,
			TotalPlaytime = 0,
			PoliceEscapes = 0,
			PoliceCaught = 0,
			MaxHeatReached = 0,
			VehiclesOwned = 1,
			ContractsCompleted = {},
			PackagesDelivered = {},
			LongestDelivery = 0,
			FastestDelivery = math.huge,
			MostValuableDelivery = 0,
		},

		-- Current state
		CurrentDistrict = "Residential",
		CurrentVehicle = nil,
		ActiveContract = nil,
		HeatLevel = 0,

		-- Inventory
		Inventory = {},
		VehicleGarage = {},
		PackageStorage = {},

		-- Hideout
		HideoutTier = "Garage",
		HideoutUpgrades = {},

		-- Daily/Weekly
		DailyLoginStreak = 0,
		LastLoginDate = nil,
		WeeklyChallengesCompleted = 0,

		-- Settings
		Settings = {
			GraphicsQuality = "Auto",
			MusicVolume = 0.7,
			SFXVolume = 0.8,
			VoiceVolume = 0.5,
			CameraSensitivity = 1.0,
			InvertCameraY = false,
			ControllerLayout = "Default",
			ShowDamageNumbers = true,
			ShowHeatWarnings = true,
			AutoAcceptContracts = false,
			Language = "en",
		},

		-- Metadata
		CreatedAt = os.time(),
		LastSavedAt = os.time(),
		Version = 1,
	}
end

-- ============================================
-- SESSION LOCKING
-- ============================================

local function GenerateLockId(): string
	return Utils.GenerateUUID()
end

local function AcquireSessionLock(userId: number): (boolean, string?)
	local lockId = GenerateLockId()
	local key = tostring(userId)
	local success, result = pcall(function()
		return dataStore:UpdateAsync(key .. "_lock", function(old)
			if old and old.lockId and old.expiry > os.time() then
				-- Lock is held by another session
				return nil -- Don't overwrite
			end
			return {
				lockId = lockId,
				expiry = os.time() + LOCK_TIMEOUT,
				serverId = game.JobId,
			}
		end)
	end)

	if success and result and result.lockId == lockId then
		activeSessions[userId] = { lockId = lockId, lastHeartbeat = os.time() }
		return true, lockId
	end

	return false, "Failed to acquire lock"
end

local function ReleaseSessionLock(userId: number, lockId: string): boolean
	local key = tostring(userId)
	local success = pcall(function()
		dataStore:UpdateAsync(key .. "_lock", function(old)
			if old and old.lockId == lockId then
				return nil -- Release lock
			end
			return old -- Keep existing lock
		end)
	end)

	activeSessions[userId] = nil
	return success
end

local function HeartbeatSessionLock(userId: number, lockId: string): boolean
	local session = activeSessions[userId]
	if not session or session.lockId ~= lockId then return false end

	local key = tostring(userId)
	local success = pcall(function()
		dataStore:UpdateAsync(key .. "_lock", function(old)
			if old and old.lockId == lockId then
				old.expiry = os.time() + LOCK_TIMEOUT
				return old
			end
			return old
		end)
	end)

	if success then
		session.lastHeartbeat = os.time()
	end
	return success
end

-- ============================================
-- DATA LOADING
-- ============================================

local function LoadPlayerData(userId: number): (boolean, any?)
	local key = tostring(userId)
	local attempts = 0

	while attempts < MAX_RETRIES do
		local success, result = pcall(function()
			return dataStore:GetAsync(key)
		end)

		if success then
			if result then
				-- Validate and migrate if needed
				result = MigrateProfile(result)
				return true, result
			else
				-- New player
				return true, nil
			end
		end

		attempts += 1
		if attempts < MAX_RETRIES then
			task.wait(RETRY_DELAY * attempts)
		end
	end

	return false, "Max retries exceeded"
end

local function LoadBackupData(userId: number): (boolean, any?)
	local key = tostring(userId) .. BACKUP_SUFFIX
	local success, result = pcall(function()
		return dataStore:GetAsync(key)
	end)

	if success and result then
		return true, result
	end
	return false, nil
end

-- ============================================
-- PROFILE MIGRATION
-- ============================================

local CURRENT_VERSION = 1

function MigrateProfile(profile: any): any
	if not profile then return CreateDefaultProfile({ UserId = 0, Name = "", DisplayName = "" }) end

	local version = profile.Version or 0

	if version < 1 then
		-- Version 1: Initial release
		profile.Version = 1
		-- Ensure all required fields exist
		profile = Utils.DeepMerge(CreateDefaultProfile({ UserId = profile.UserId, Name = profile.Username, DisplayName = profile.DisplayName }), profile)
	end

	-- Future migrations would go here
	-- if version < 2 then ... end

	return profile
end

-- ============================================
-- DATA SAVING
-- ============================================

local function SavePlayerData(userId: number, profile: any, lockId: string): (boolean, string?)
	local key = tostring(userId)
	local backupKey = key .. BACKUP_SUFFIX

	-- Update metadata
	profile.LastSavedAt = os.time()
	profile.Version = CURRENT_VERSION

	local attempts = 0
	while attempts < MAX_RETRIES do
		local success, result = pcall(function()
			-- Use UpdateAsync for atomic save with lock verification
			return dataStore:UpdateAsync(key, function(old)
				-- Verify lock still valid
				if old and old._lock and old._lock.lockId ~= lockId then
					error("Lock mismatch - another session owns this data")
				end
				return profile
			end)
		end)

		if success then
			-- Also save backup
			pcall(function()
				dataStore:SetAsync(backupKey, profile)
			end)
			return true, nil
		end

		attempts += 1
		if attempts < MAX_RETRIES then
			task.wait(RETRY_DELAY * attempts)
		end
	end

	return false, "Max retries exceeded"
end

-- ============================================
-- PLAYER LIFECYCLE
-- ============================================

local playerProfiles = {} -- [userId] = profile
local playerLocks = {} -- [userId] = lockId
local playerSaveThreads = {} -- [userId] = thread

local function OnPlayerAdded(player: Player)
	Utils.DebugLog("Player joining:", player.Name)

	-- Acquire session lock
	local success, lockId = AcquireSessionLock(player.UserId)
	if not success then
		player:Kick("Unable to load your data. Please try again in a moment.")
		return
	end

	playerLocks[player.UserId] = lockId

	-- Load profile
	local loadSuccess, profile = LoadPlayerData(player.UserId)
	if not loadSuccess then
		-- Try backup
		local backupSuccess, backupProfile = LoadBackupData(player.UserId)
		if backupSuccess and backupProfile then
			profile = backupProfile
			Utils.DebugWarn("Loaded backup data for", player.Name)
		else
			profile = CreateDefaultProfile(player)
			Utils.DebugLog("Created new profile for", player.Name)
		end
	end

	-- Update username/display name in case they changed
	profile.Username = player.Name
	profile.DisplayName = player.DisplayName

	-- Store profile
	playerProfiles[player.UserId] = profile

	-- Fire loaded signal
	Signals.GameSignals.PlayerLoaded:Fire(player, profile)

	-- Sync to client
	SyncPlayerDataToClient(player, profile)

	-- Start auto-save loop
	StartAutoSave(player.UserId)

	-- Handle daily login
	HandleDailyLogin(player, profile)
end

local function OnPlayerRemoving(player: Player)
	Utils.DebugLog("Player leaving:", player.Name)

	local userId = player.UserId
	local profile = playerProfiles[userId]
	local lockId = playerLocks[userId]

	if profile and lockId then
		-- Stop auto-save
		StopAutoSave(userId)

		-- Final save
		local success, err = SavePlayerData(userId, profile, lockId)
		if not success then
			Utils.DebugWarn("Failed to save data for", player.Name, ":", err)
		end
	end

	-- Cleanup
	playerProfiles[userId] = nil
	playerLocks[userId] = nil
	activeSessions[userId] = nil

	Signals.GameSignals.PlayerUnloaded:Fire(player)
end

-- ============================================
-- AUTO-SAVE & HEARTBEAT
-- ============================================

function StartAutoSave(userId: number)
	local thread = task.spawn(function()
		while playerProfiles[userId] do
			task.wait(SAVE_INTERVAL)
			if not playerProfiles[userId] then break end

			local profile = playerProfiles[userId]
			local lockId = playerLocks[userId]
			if lockId then
				local success, err = SavePlayerData(userId, profile, lockId)
				if not success then
					Utils.DebugWarn("Auto-save failed for", userId, ":", err)
				end
			end
		end
	end)
	playerSaveThreads[userId] = thread
end

function StopAutoSave(userId: number)
	local thread = playerSaveThreads[userId]
	if thread then
		task.cancel(thread)
		playerSaveThreads[userId] = nil
	end
end

-- Heartbeat for session lock
task.spawn(function()
	while true do
		task.wait(HEARTBEAT_INTERVAL)
		for userId, session in pairs(activeSessions) do
			if playerLocks[userId] then
				HeartbeatSessionLock(userId, session.lockId)
			end
		end
	end
end)

-- ============================================
-- DATA ACCESS
-- ============================================

function PlayerDataServer.GetProfile(userId: number): any?
	return playerProfiles[userId]
end

function PlayerDataServer.GetProfileAsync(userId: number): any?
	local profile = playerProfiles[userId]
	if profile then return profile end

	-- Try loading if not cached
	local success, profile = LoadPlayerData(userId)
	if success and profile then
		playerProfiles[userId] = profile
		return profile
	end
	return nil
end

function PlayerDataServer.UpdateProfile(userId: number, updates: { [string]: any }): boolean
	local profile = playerProfiles[userId]
	if not profile then return false end

	for key, value in pairs(updates) do
		profile[key] = value
	end

	Signals.GameSignals.PlayerDataChanged:Fire(userId, profile)
	return true
end

function PlayerDataServer.IncrementStat(userId: number, statPath: string, amount: number?): boolean
	local profile = playerProfiles[userId]
	if not profile then return false end

	amount = amount or 1
	local keys = Utils.Split(statPath, ".")
	local current = profile

	for i = 1, #keys - 1 do
		local key = keys[i]
		if not current[key] then current[key] = {} end
		current = current[key]
	end

	local finalKey = keys[#keys]
	current[finalKey] = (current[finalKey] or 0) + amount

	Signals.GameSignals.PlayerDataChanged:Fire(userId, profile)
	return true
end

-- ============================================
-- PROGRESSION
-- ============================================

function PlayerDataServer.AddXP(userId: number, amount: number, source: string?)
	local profile = playerProfiles[userId]
	if not profile then return end

	profile.XP += amount
	profile.TotalXP += amount

	-- Check for level up
	local xpForNext = CalculateXPForLevel(profile.Level + 1)
	while profile.XP >= xpForNext do
		LevelUp(userId)
		xpForNext = CalculateXPForLevel(profile.Level + 1)
	end

	Signals.GameSignals.XPGained:Fire(profile.UserId, amount, source)
	Signals.GameSignals.PlayerDataChanged:Fire(userId, profile)
end

function CalculateXPForLevel(level: number): number
	if level <= 1 then return 0 end
	local xp = 0
	for i = 1, level - 1 do
		xp += Constants.Progression.BaseXP * (Constants.Progression.XPMultiplier ^ (i - 1))
	end
	return math.floor(xp)
end

function LevelUp(userId: number)
	local profile = playerProfiles[userId]
	if not profile then return end

	profile.Level += 1
	profile.XP = profile.XP - CalculateXPForLevel(profile.Level)

	-- Check unlocks
	local unlocks = Constants.GetLevelUnlocks(profile.Level)
	for _, unlock in ipairs(unlocks) do
		Signals.GameSignals.UnlockEarned:Fire(userId, unlock)
	end

	Signals.GameSignals.LevelUp:Fire(userId, profile.Level, unlocks)
	Signals.GameSignals.PlayerDataChanged:Fire(userId, profile)
end

-- ============================================
-- ECONOMY
-- ============================================

function PlayerDataServer.AddCash(userId: number, amount: number, source: string?): boolean
	local profile = playerProfiles[userId]
	if not profile then return false end

	if amount < 0 and profile.Cash + amount < 0 then
		return false -- Insufficient funds
	end

	profile.Cash += amount
	if amount > 0 then
		profile.LifetimeEarnings += amount
	end

	Signals.GameSignals.CashChanged:Fire(userId, profile.Cash, amount, source)
	Signals.GameSignals.CurrencyEarned:Fire(userId, amount, source)
	Signals.GameSignals.PlayerDataChanged:Fire(userId, profile)
	return true
end

function PlayerDataServer.SpendCash(userId: number, amount: number, source: string?): boolean
	return PlayerDataServer.AddCash(userId, -amount, source)
end

-- ============================================
-- INVENTORY MANAGEMENT
-- ============================================

function PlayerDataServer.AddToInventory(userId: number, packageData: any): boolean
	local profile = playerProfiles[userId]
	if not profile then return false end

	table.insert(profile.Inventory, packageData)
	Signals.GameSignals.PlayerDataChanged:Fire(userId, profile)
	return true
end

function PlayerDataServer.RemoveFromInventory(userId: number, packageId: string): any?
	local profile = playerProfiles[userId]
	if not profile then return nil end

	for i, pkg in ipairs(profile.Inventory) do
		if pkg.Id == packageId then
			table.remove(profile.Inventory, i)
			Signals.GameSignals.PlayerDataChanged:Fire(userId, profile)
			return pkg
		end
	end
	return nil
end

function PlayerDataServer.AddVehicle(userId: number, vehicleData: any): boolean
	local profile = playerProfiles[userId]
	if not profile then return false end

	table.insert(profile.VehicleGarage, vehicleData)
	profile.Stats.VehiclesOwned += 1

	Signals.GameSignals.PlayerDataChanged:Fire(userId, profile)
	return true
end

function PlayerDataServer.RemoveVehicle(userId: number, vehicleId: string): any?
	local profile = playerProfiles[userId]
	if not profile then return nil end

	for i, vehicle in ipairs(profile.VehicleGarage) do
		if vehicle.Id == vehicleId then
			table.remove(profile.VehicleGarage, i)
			Signals.GameSignals.PlayerDataChanged:Fire(userId, profile)
			return vehicle
		end
	end
	return nil
end

-- ============================================
-- HEAT MANAGEMENT
-- ============================================

function PlayerDataServer.SetHeatLevel(userId: number, level: number, source: string?)
	local profile = playerProfiles[userId]
	if not profile then return end

	level = math.clamp(level, 0, Constants.Heat.MaxStars)
	local oldLevel = profile.HeatLevel
	profile.HeatLevel = level

	if level > oldLevel then
		Signals.GameSignals.HeatLevelUp:Fire(userId, level, source)
	elseif level < oldLevel then
		Signals.GameSignals.HeatLevelDown:Fire(userId, level, source)
	end

	Signals.GameSignals.HeatChanged:Fire(userId, level, oldLevel, source)
	Signals.GameSignals.PlayerDataChanged:Fire(userId, profile)
end

function PlayerDataServer.AddHeat(userId: number, amount: number, source: string?)
	local profile = playerProfiles[userId]
	if not profile then return end

	local newLevel = math.clamp(profile.HeatLevel + amount, 0, Constants.Heat.MaxStars)
	PlayerDataServer.SetHeatLevel(userId, newLevel, source)
end

-- ============================================
-- SYNC TO CLIENT
-- ============================================

local RemoteEvents = {}

function SyncPlayerDataToClient(player: Player, profile: any)
	-- Send initial full sync
	local remote = GetRemoteEvent("SyncPlayerData")
	if remote then
		remote:FireClient(player, {
			Profile = profile,
			-- Vehicles and inventory would be sent separately or included
		})
	end
end

function GetRemoteEvent(name: string): RemoteEvent?
	local remote = ReplicatedStorage:FindFirstChild("Remotes", true)
	if remote then
		return remote:FindFirstChild(name)
	end
	return nil
end

-- ============================================
-- DAILY LOGIN
-- ============================================

function HandleDailyLogin(player: Player, profile: any)
	local today = os.date("%Y-%m-%d")
	local lastLogin = profile.LastLoginDate

	if lastLogin == today then
		return -- Already logged in today
	end

	local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
	local isConsecutive = (lastLogin == yesterday)

	if isConsecutive then
		profile.DailyLoginStreak += 1
	else
		profile.DailyLoginStreak = 1
	end

	profile.LastLoginDate = today

	-- Give daily reward
	local reward = Constants.Economy.DailyLoginRewards[math.min(profile.DailyLoginStreak, 7)]
	if reward then
		if reward.Cash then
			PlayerDataServer.AddCash(player.UserId, reward.Cash, "DailyLogin")
		end
		if reward.XP then
			PlayerDataServer.AddXP(player.UserId, reward.XP, "DailyLogin")
		end
		if reward.Item then
			-- Add item to inventory
		end

		Signals.GameSignals.NotificationQueued:Fire(player.UserId, {
			Type = "Success",
			Title = "Daily Login",
			Message = string.format("Day %d streak! Claimed rewards.", profile.DailyLoginStreak),
			Duration = 5,
		})
	end

	profile.LastLoginDate = today
end

-- ============================================
-- ADMIN / DEBUG
-- ============================================

function PlayerDataServer.ForceSave(userId: number): boolean
	local profile = playerProfiles[userId]
	local lockId = playerLocks[userId]
	if not profile or not lockId then return false end

	local success, err = SavePlayerData(userId, profile, lockId)
	return success
end

function PlayerDataServer.WipeData(userId: number): boolean
	local key = tostring(userId)
	local backupKey = key .. BACKUP_SUFFIX
	local lockKey = key .. "_lock"

	local success = pcall(function()
		dataStore:RemoveAsync(key)
		dataStore:RemoveAsync(backupKey)
		dataStore:RemoveAsync(lockKey)
	end)

	if success then
		playerProfiles[userId] = nil
		playerLocks[userId] = nil
		activeSessions[userId] = nil
	end

	return success
end

function PlayerDataServer.GetAllProfiles(): { [number]: any }
	return playerProfiles
end

-- ============================================
-- INITIALIZATION
-- ============================================

Players.PlayerAdded:Connect(OnPlayerAdded)
Players.PlayerRemoving:Connect(OnPlayerRemoving)

-- Handle game shutdown
game:BindToClose(function()
	Utils.DebugLog("Game shutting down, saving all players...")
	for userId, profile in pairs(playerProfiles) do
		local lockId = playerLocks[userId]
		if lockId then
			SavePlayerData(userId, profile, lockId)
		end
	end
	task.wait(2) -- Give time for saves
end)

Utils.DebugLog("PlayerDataServer initialized")

return PlayerDataServer