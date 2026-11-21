--[[
	UNDERGROUND — Main Server Initialization
	Initializes all server systems in correct dependency order.
	This script should be placed in ServerScriptService as a Script.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Load all server systems
local PlayerDataServer = require(script.Parent.Systems.PlayerDataServer)
local EconomyServer = require(script.Parent.Systems.EconomyServer)
local InventoryServer = require(script.Parent.Systems.InventoryServer)
local ContractServer = require(script.Parent.Systems.ContractServer)
local VehicleServer = require(script.Parent.Systems.VehicleServer)
local HeatServer = require(script.Parent.Systems.HeatServer)
local PoliceAI = require(script.Parent.Systems.PoliceAI)
local MapManager = require(script.Parent.Systems.MapManager)

-- ============================================
- GLOBAL REFERENCES
- ============================================

-- Make systems globally accessible for cross-system communication
_G.PlayerDataServer = PlayerDataServer
_G.EconomyServer = EconomyServer
_G.InventoryServer = InventoryServer
_G.ContractServer = ContractServer
_G.VehicleServer = VehicleServer
_G.HeatServer = HeatServer
_G.PoliceAI = PoliceAI
_G.MapManager = MapManager

-- Spawned vehicles reference (used by PoliceAI, ContractServer, etc.)
_G.spawnedVehicles = _G.spawnedVehicles or {}

-- ============================================
- SYSTEM INITIALIZATION ORDER
- ============================================

local function InitializeSystems()
	print("=== UNDERGROUND Server Initialization ===")

	-- Phase 1: Core infrastructure (no dependencies)
	print("[1/8] Initializing PlayerDataServer...")
	-- PlayerDataServer auto-initializes on require

	print("[2/8] Initializing EconomyServer...")
	-- EconomyServer auto-initializes on require

	print("[3/8] Initializing InventoryServer...")
	-- InventoryServer auto-initializes on require

	print("[4/8] Initializing MapManager...")
	-- MapManager auto-initializes on require

	-- Phase 2: Gameplay systems (depend on core)
	print("[5/8] Initializing ContractServer...")
	-- ContractServer auto-initializes on require

	print("[6/8] Initializing VehicleServer...")
	-- VehicleServer auto-initializes on require

	print("[7/8] Initializing HeatServer...")
	-- HeatServer auto-initializes on require

	print("[8/8] Initializing PoliceAI...")
	-- PoliceAI auto-initializes on require

	-- Cross-system connections
	SetupCrossSystemConnections()

	print("=== All Systems Initialized Successfully ===")
end

function SetupCrossSystemConnections()
	-- Economy -> Contract rewards
	-- Already connected via signals

	-- Heat -> Police
	-- Already connected via signals

	-- Contract -> Inventory (package pickup)
	-- Already connected via signals

	-- Vehicle -> Economy (fuel costs, repairs)
	-- Already connected via signals

	-- Police -> Heat (pursuit increases heat)
	-- Already connected via signals

	print("Cross-system connections established")
end

-- ============================================
- GLOBAL UTILITY FUNCTIONS
- ============================================

-- Get player profile by userId
function _G.GetPlayerProfile(userId)
	return _G.PlayerDataServer.GetProfile(userId)
end

-- Get player's active vehicle
function _G.GetPlayerActiveVehicle(userId)
	local profile = _G.GetPlayerProfile(userId)
	if not profile then return nil end

	return profile.ActiveVehicle and _G.InventoryServer.GetActiveVehicle(userId)
end

-- Get player's current district
function _G.GetPlayerDistrict(userId)
	local profile = _G.GetPlayerProfile(userId)
	return profile and profile.CurrentDistrict or "Residential"
end

-- Check if player is in pursuit
function _G.IsPlayerInPursuit(userId)
	return _G.PoliceAI.GetActivePursuits()[userId] ~= nil
end

-- Get player's heat level
function _G.GetPlayerHeat(userId)
	return _G.HeatServer.GetHeat(userId)
end

-- ============================================
- ADMIN COMMANDS
- ============================================

local function SetupAdminCommands()
	local Players = game:GetService("Players")

	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			if not player:GetAttribute("IsAdmin") then return end

			local args = string.split(message, " ")
			local command = args[1]:lower()

			if command == "!givecash" then
				local target = args[2] and Players:FindFirstChild(args[2]) or player
				local amount = tonumber(args[3]) or 10000
				_G.EconomyServer.AddCash(target.UserId, amount, "AdminCommand")
			elseif command == "!givexp" then
				local target = args[2] and Players:FindFirstChild(args[2]) or player
				local amount = tonumber(args[3]) or 1000
				_G.PlayerDataServer.AddXP(target.UserId, amount, "AdminCommand")
			elseif command == "!setlevel" then
				local target = args[2] and Players:FindFirstChild(args[2]) or player
				local level = tonumber(args[3]) or 1
				-- Would set level directly
			elseif command == "!setheat" then
				local target = args[2] and Players:FindFirstChild(args[2]) or player
				local level = tonumber(args[3]) or 0
				_G.HeatServer.SetHeat(target.UserId, level, "AdminCommand")
			elseif command == "!spawnvehicle" then
				local category = args[2] or "Starter"
				local model = args[3] or "Default"
				_G.EconomyServer.PurchaseVehicle(player.UserId, category, model)
			elseif command == "!spawnpolice" then
				local heat = tonumber(args[2]) or 3
				_G.PoliceAI.DeployHelicopter(player.UserId)
			elseif command == "!resetdata" then
				local target = args[2] and Players:FindFirstChild(args[2]) or player
				_G.PlayerDataServer.WipeData(target.UserId)
				target:Kick("Data reset by admin")
			elseif command == "!spawnpackage" then
				local district = args[2] or "Downtown"
				_G.ContractServer.RefreshContractBoard(district)
			end
		end)
	end
end

SetupAdminCommands()

-- ============================================
- PERFORMANCE MONITORING
- ============================================

local function StartPerformanceMonitoring()
	task.spawn(function()
		while true do
			task.wait(30)

			local stats = {
				Players = #game.Players:GetPlayers(),
				ServerMemory = game:GetService("Stats"):GetTotalMemoryUsageMb(),
				PhysicsTime = game:GetService("Stats").PhysicsTime,
				FrameTime = game:GetService("Stats").FrameTime,
				ActiveVehicles = 0,
				ActiveContracts = 0,
				PoliceUnits = 0,
			}

			for _ in pairs(_G.spawnedVehicles or {}) do
				stats.ActiveVehicles = stats.ActiveVehicles + 1
			end

			for _ in pairs(_G.ContractServer.GetAllActiveContracts() or {}) do
				stats.ActiveContracts = stats.ActiveContracts + 1
			end

			for _ in pairs(_G.PoliceAI.GetAllUnits() or {}) do
				stats.PoliceUnits = stats.PoliceUnits + 1
			end

			-- Log if performance degrades
			if stats.FrameTime > 0.022 then -- > 22ms = below 45 FPS
				warn("[PERFORMANCE] High frame time:", stats.FrameTime)
			end

			if stats.ServerMemory > 800 then -- > 800 MB
				warn("[PERFORMANCE] High memory usage:", stats.ServerMemory .. " MB")
			end
		end
	end
end

StartPerformanceMonitoring()

-- ============================================
- GRACEFUL SHUTDOWN
- ============================================

game:BindToClose(function()
	print("=== Server Shutting Down ===")

	-- Save all player data
	for userId, profile in pairs(_G.PlayerDataServer.GetAllProfiles()) do
		local lockId = _G.PlayerDataServer.GetLockId and _G.PlayerDataServer.GetLockId(userId)
		if lockId then
			_G.PlayerDataServer.ForceSave(userId)
		end
	end

	-- Despawn all vehicles
	for vehicleId, vehicleEntry in pairs(_G.spawnedVehicles) do
		if vehicleEntry.Model then
			vehicleEntry.Model:Destroy()
		end
	end

	-- Clean up police units
	for _, unit in pairs(_G.PoliceAI.GetAllUnits()) do
		if unit.Model then unit.Model:Destroy() end
	end

	print("=== Shutdown Complete ===")
end)

print("=== UNDERGROUND MainServer Loaded ===")