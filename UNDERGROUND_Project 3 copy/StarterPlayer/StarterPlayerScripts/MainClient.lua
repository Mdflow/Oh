--[[
	UNDERGROUND — Main Client Initialization
	Initializes all client systems in correct dependency order.
	This script should be placed in StarterPlayerScripts as a LocalScript.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Load all client systems
local ClientBootstrap = require(script.Parent.ClientBootstrap)
local UIController = require(script.Parent.Systems.UIController)
local InputManager = require(script.Parent.Systems.InputManager)
local VehicleClient = require(script.Parent.Systems.VehicleClient)
local ContractClient = require(script.Parent.Systems.ContractClient)
local MapClient = require(script.Parent.Systems.MapClient)
local HeatClient = require(script.Parent.Systems.HeatClient)
local ProgressionClient = require(script.Parent.Systems.ProgressionClient)
local SocialClient = require(script.Parent.Systems.SocialClient)
local NotificationsClient = require(script.Parent.Systems.NotificationsClient)
local SettingsClient = require(script.Parent.Systems.SettingsClient)

-- ============================================
- GLOBAL REFERENCES
- ============================================

-- Make systems globally accessible
_G.ClientBootstrap = ClientBootstrap
_G.UIController = UIController
_G.InputManager = InputManager
_G.VehicleClient = VehicleClient
_G.ContractClient = ContractClient
_G.MapClient = MapClient
_G.HeatClient = HeatClient
_G.ProgressionClient = ProgressionClient
_G.SocialClient = SocialClient
_G.NotificationsClient = NotificationsClient
_G.SettingsClient = SettingsClient

-- ============================================
- INITIALIZATION
- ============================================

local function InitializeClient()
	print("=== UNDERGROUND Client Initialization ===")

	-- Wait for ReplicatedStorage to be ready
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
	if not remotesFolder then
		warn("Remotes folder not found!")
		return
	end

	-- Initialize systems in dependency order
	print("[1/10] Initializing InputManager...")
	InputManager.Initialize()

	print("[2/10] Initializing UIController...")
	UIController.Initialize()

	print("[3/10] Initializing VehicleClient...")
	VehicleClient.Initialize()

	print("[4/10] Initializing ContractClient...")
	ContractClient.Initialize()

	print("[5/10] Initializing MapClient...")
	MapClient.Initialize()

	print("[6/10] Initializing HeatClient...")
	HeatClient.Initialize()

	print("[7/10] Initializing ProgressionClient...")
	ProgressionClient.Initialize()

	print("[8/10] Initializing SocialClient...")
	SocialClient.Initialize()

	print("[9/10] Initializing NotificationsClient...")
	NotificationsClient.Initialize()

	print("[10/10] Initializing SettingsClient...")
	SettingsClient.Initialize()

	-- Cross-system connections
	SetupCrossSystemConnections()

	-- Request initial data sync
	ClientBootstrap.RequestSettings()

	print("=== All Client Systems Initialized ===")
end

function SetupCrossSystemConnections()
	-- VehicleClient -> UIController (HUD updates)
	-- Already connected via signals

	-- ContractClient -> VehicleClient (delivery tracking)
	-- Already connected via signals

	-- HeatClient -> UIController (visual effects)
	-- Already connected via signals

	-- MapClient -> ContractClient (GPS)
	-- Already connected via signals

	-- ProgressionClient -> UIController (level up, unlocks)
	-- Already connected via signals

	-- SocialClient -> UIController (toasts, party UI)
	-- Already connected via signals

	-- NotificationsClient -> UIController (toasts)
	-- Already connected via signals

	-- SettingsClient -> All systems (settings changes)
	-- Already connected via signals

	print("Cross-system connections established")
end

-- ============================================
- GLOBAL UTILITY FUNCTIONS
- ============================================

-- Get active vehicle
function _G.GetActiveVehicle()
	return _G.VehicleClient.GetActiveVehicleModel()
end

-- Get active vehicle ID
function _G.GetActiveVehicleId()
	return _G.VehicleClient.GetActiveVehicleId()
end

-- Get vehicle data
function _G.GetVehicleData()
	return _G.VehicleClient.GetVehicleData()
end

-- Get current speed
function _G.GetCurrentSpeed()
	return _G.VehicleClient.GetCurrentSpeed()
end

-- Get current heat level
function _G.GetCurrentHeat()
	return _G.HeatClient.GetCurrentHeat and _G.HeatClient.GetCurrentHeat() or 0
end

-- Get active contract
function _G.GetActiveContract()
	return _G.ContractClient.GetActiveContract and _G.ContractClient.GetActiveContract() or nil
end

-- Get current district
function _G.GetCurrentDistrict()
	return _G.MapClient.GetCurrentDistrict and _G.MapClient.GetCurrentDistrict() or "Residential"
end

-- Check if in pursuit
function _G.IsInPursuit()
	return _G.HeatClient.IsInPursuit and _G.HeatClient.IsInPursuit() or false
end

-- Open/close UI panels
function _G.ToggleGarage()
	UIController.ShowScreen("Garage")
end

function _G.ToggleHideout()
	UIController.ShowScreen("Hideout")
end

function _G.ToggleLeaderboards()
	UIController.ShowScreen("Leaderboards")
end

function _G.ToggleSettings()
	UIController.ShowScreen("Settings")
end

function _G.ToggleSocial()
	_G.SocialClient.ToggleSocialPanel()
end

function _G.ToggleContractBoard(district)
	_G.ContractClient.ToggleContractBoard(district)
end

function _G.ToggleStats()
	_G.ProgressionClient.ToggleStatsPanel()
end

-- ============================================
- DEBUG COMMANDS
- ============================================

local function SetupDebugCommands()
	local UserInputService = game:GetService("UserInputService")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end

		-- F1: Toggle debug mode
		if input.KeyCode == Enum.KeyCode.F1 then
			_G.DebugMode = not _G.DebugMode
			print("Debug mode:", _G.DebugMode)
		end

		-- F2: Toggle stats panel
		if input.KeyCode == Enum.KeyCode.F2 then
			_G.ProgressionClient.ToggleStatsPanel()
		end

		-- F3: Toggle contract board
		if input.KeyCode == Enum.KeyCode.F3 then
			_G.ToggleContractBoard()
		end

		-- F4: Toggle garage
		if input.KeyCode == Enum.KeyCode.F4 then
			_G.ToggleGarage()
		end

		-- F5: Toggle hideout
		if input.KeyCode == Enum.KeyCode.F5 then
			_G.ToggleHideout()
		end

		-- F6: Toggle leaderboards
		if input.KeyCode == Enum.KeyCode.F6 then
			_G.ToggleLeaderboards()
		end

		-- F7: Toggle settings
		if input.KeyCode == Enum.KeyCode.F7 then
			_G.ToggleSettings()
		end

		-- F8: Toggle social
		if input.KeyCode == Enum.KeyCode.F8 then
			_G.ToggleSocial()
		end

		-- F9: Toggle contract board
		if input.KeyCode == Enum.KeyCode.F9 then
			_G.ToggleContractBoard()
		end

		-- F10: Toggle stats
		if input.KeyCode == Enum.KeyCode.F10 then
			_G.ToggleStats()
		end

		-- Ctrl+Shift+R: Reload UI
		if input.KeyCode == Enum.KeyCode.R and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			print("Reloading UI...")
			UIController.Cleanup()
			UIController.Initialize()
		end

		-- Ctrl+Shift+C: Clear notifications
		if input.KeyCode == Enum.KeyCode.C and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			_G.NotificationsClient.DismissAll()
		end

		-- Ctrl+Shift+S: Save settings
		if input.KeyCode == Enum.KeyCode.S and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
			_G.SettingsClient.SaveSettings()
		end
	end)
end

SetupDebugCommands()

-- ============================================
- PERFORMANCE MONITORING
- ============================================

local function StartClientPerformanceMonitoring()
	local RunService = game:GetService("RunService")
	local Stats = game:GetService("Stats")

	task.spawn(function()
		while true do
			task.wait(30)

			local stats = {
				FPS = 1 / RunService.RenderStepped:Wait(),
				Memory = Stats:GetTotalMemoryUsageMb(),
				Ping = Stats.Network.ServerStatsItem["Data Ping"] and Stats.Network.ServerStatsItem["Data Ping"]:GetValue() or 0,
				PacketLoss = Stats.Network.ServerStatsItem["Packet Loss"] and Stats.Network.ServerStatsItem["Packet Loss"]:GetValue() or 0,
				ActiveVehicles = 0,
				ActiveContracts = 0,
			}

			-- Log performance issues
			if stats.FPS < 30 then
				warn("[PERFORMANCE] Low FPS:", math.floor(stats.FPS))
			end

			if stats.Memory > 600 then
				warn("[PERFORMANCE] High memory:", stats.Memory .. " MB")
			end

			if stats.Ping > 200 then
				warn("[PERFORMANCE] High ping:", stats.Ping .. "ms")
			end
		end
	end
end

StartClientPerformanceMonitoring()

-- ============================================
- GRACEFUL SHUTDOWN
- ============================================

game:BindToClose(function()
	print("=== Client Shutting Down ===")

	-- Cleanup all systems
	_G.SettingsClient.Cleanup()
	_G.NotificationsClient.Cleanup()
	_G.SocialClient.Cleanup()
	_G.ProgressionClient.Cleanup()
	_G.HeatClient.Cleanup()
	_G.MapClient.Cleanup()
	_G.ContractClient.Cleanup()
	_G.VehicleClient.Cleanup()
	_G.InputManager.Cleanup()
	_G.UIController.Cleanup()

	print("=== Client Shutdown Complete ===")
end)

-- ============================================
- START INITIALIZATION
- ============================================

InitializeClient()

print("=== UNDERGROUND Client Loaded ===")