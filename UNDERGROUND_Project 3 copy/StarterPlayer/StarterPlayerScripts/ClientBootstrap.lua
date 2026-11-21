--[[
	UNDERGROUND — Client Bootstrap
	Initializes all client systems, loads modules, sets up Remotes.
	Entry point for all client-side logic.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)

local ClientBootstrap = {}

-- ============================================
-- MODULE REFERENCES
-- ============================================

local ClientSystems = {}
local Remotes = {}
local RemoteFunctions = {}

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- ============================================
- REMOTE SETUP
-- ============================================

local function SetupRemotes()
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
	if not remotesFolder then
		warn("Remotes folder not found!")
		return
	end

	-- RemoteEvents
	for _, remote in ipairs(remotesFolder:GetChildren()) do
		if remote:IsA("RemoteEvent") then
			Remotes[remote.Name] = remote
		elseif remote:IsA("RemoteFunction") then
			RemoteFunctions[remote.Name] = remote
		end
	end

	Utils.DebugLog("Remotes loaded:", Utils.TableLength(Remotes), "events,", Utils.TableLength(RemoteFunctions), "functions")
end

-- ============================================
- SYSTEM LOADING
-- ============================================

local function LoadClientSystems()
	-- Load in dependency order
	local systemLoadOrder = {
		"InputManager",
		"UIController",
		"VehicleClient",
		"ContractClient",
		"MapClient",
		"HeatClient",
		"ProgressionClient",
		"SocialClient",
		"NotificationsClient",
		"SettingsClient",
	}

	for _, systemName in ipairs(systemLoadOrder) do
		local success, system = pcall(function()
			return require(script.Parent.Systems[systemName])
		end)

		if success and system then
			ClientSystems[systemName] = system
			if system.Initialize then
				system.Initialize()
			end
			Utils.DebugLog("Loaded client system:", systemName)
		else
			warn("Failed to load client system:", systemName, system)
		end
	end
end

-- ============================================
- REMOTE EVENT HANDLERS
-- ============================================

local function ConnectRemoteHandlers()
	-- Player Data Sync
	local syncRemote = Remotes.SyncPlayerData
	if syncRemote then
		syncRemote.OnClientEvent:Connect(function(data)
			ClientBootstrap.OnPlayerDataSynced(data)
		end)
	end

	-- Contract Events
	local contractAdded = Remotes.ContractAdded
	if contractAdded then
		contractAdded.OnClientEvent:Connect(function(contract)
			if ClientSystems.ContractClient then
				ClientSystems.ContractClient.OnContractAdded(contract)
			end
		end)
	end

	local contractUpdate = Remotes.ContractUpdated
	if contractUpdate then
		contractUpdate.OnClientEvent:Connect(function(contractId, updates)
			if ClientSystems.ContractClient then
				ClientSystems.ContractClient.OnContractUpdated(contractId, updates)
			end
		end)
	end

	local contractRemoved = Remotes.ContractRemoved
	if contractRemoved then
		contractRemoved.OnClientEvent:Connect(function(contractId)
			if ClientSystems.ContractClient then
				ClientSystems.ContractClient.OnContractRemoved(contractId)
			end
		end)
	end

	local contractAccepted = Remotes.ContractAccepted
	if contractAccepted then
		contractAccepted.OnClientEvent:Connect(function(contract, session)
			if ClientSystems.ContractClient then
				ClientSystems.ContractClient.OnContractAccepted(contract, session)
			end
		end)
	end

	local deliveryProgress = Remotes.DeliveryProgress
	if deliveryProgress then
		deliveryProgress.OnClientEvent:Connect(function(session)
			if ClientSystems.ContractClient then
				ClientSystems.ContractClient.OnDeliveryProgress(session)
			end
			if ClientSystems.VehicleClient then
				ClientSystems.VehicleClient.OnDeliveryProgress(session)
			end
		end)
	end

	local deliveryComplete = Remotes.DeliveryComplete
	if deliveryComplete then
		deliveryComplete.OnClientEvent:Connect(function(rewards, contract)
			if ClientSystems.ContractClient then
				ClientSystems.ContractClient.OnDeliveryComplete(rewards, contract)
			end
			if ClientSystems.NotificationsClient then
				ClientSystems.NotificationsClient.ShowDeliveryComplete(rewards)
			end
			if ClientSystems.ProgressionClient then
				ClientSystems.ProgressionClient.OnXPGained(rewards.xp)
			end
		end)
	end

	local deliveryFailed = Remotes.DeliveryFailed
	if deliveryFailed then
		deliveryFailed.OnClientEvent:Connect(function(reason)
			if ClientSystems.ContractClient then
				ClientSystems.ContractClient.OnDeliveryFailed(reason)
			end
			if ClientSystems.NotificationsClient then
				ClientSystems.NotificationsClient.ShowError("Delivery Failed: " .. reason)
			end
		end)
	end

	-- Heat Events
	local heatChanged = Remotes.HeatChanged
	if heatChanged then
		heatChanged.OnClientEvent:Connect(function(data)
			if ClientSystems.HeatClient then
				ClientSystems.HeatClient.OnHeatChanged(data)
			end
			if ClientSystems.UIController then
				ClientSystems.UIController.OnHeatChanged(data)
			end
		end)
	end

	local heatEffectUpdate = Remotes.HeatEffectUpdate
	if heatEffectUpdate then
		heatEffectUpdate.OnClientEvent:Connect(function(data)
			if ClientSystems.HeatClient then
				ClientSystems.HeatClient.OnHeatEffectUpdate(data)
			end
			if ClientSystems.UIController then
				ClientSystems.UIController.OnHeatEffectUpdate(data)
			end
		end)
	end

	-- Police Events
	local policeSpawned = Remotes.PoliceSpawned
	if policeSpawned then
		policeSpawned.OnClientEvent:Connect(function(unit)
			if ClientSystems.MapClient then
				ClientSystems.MapClient.OnPoliceSpawned(unit)
			end
		end)
	end

	local policeDespawned = Remotes.PoliceDespawned
	if policeDespawned then
		policeDespawned.OnClientEvent:Connect(function(unitId)
			if ClientSystems.MapClient then
				ClientSystems.MapClient.OnPoliceDespawned(unitId)
			end
		end)
	end

	local pursuitStart = Remotes.PursuitStarted
	if pursuitStart then
		pursuitStart.OnClientEvent:Connect(function(data)
			if ClientSystems.HeatClient then
				ClientSystems.HeatClient.OnPursuitStarted(data)
			end
			if ClientSystems.UIController then
				ClientSystems.UIController.OnPursuitStarted(data)
			end
		end)
	end

	local pursuitEnd = Remotes.PursuitEnded
	if pursuitEnd then
		pursuitEnd.OnClientEvent:Connect(function(escaped)
			if ClientSystems.HeatClient then
				ClientSystems.HeatClient.OnPursuitEnded(escaped)
			end
			if ClientSystems.UIController then
				ClientSystems.UIController.OnPursuitEnded(escaped)
			end
		end)
	end

	-- Vehicle Events
	local vehicleSpawned = Remotes.VehicleSpawned
	if vehicleSpawned then
		vehicleSpawned.OnClientEvent:Connect(function(vehicleData, model)
			if ClientSystems.VehicleClient then
				ClientSystems.VehicleClient.OnVehicleSpawned(vehicleData, model)
			end
		end)
	end

	local vehicleDespawned = Remotes.VehicleDespawned
	if vehicleDespawned then
		vehicleDespawned.OnClientEvent:Connect(function(vehicleId)
			if ClientSystems.VehicleClient then
				ClientSystems.VehicleClient.OnVehicleDespawned(vehicleId)
			end
		end)
	end

	local vehicleUpdate = Remotes.VehicleUpdated
	if vehicleUpdate then
		vehicleUpdate.OnClientEvent:Connect(function(vehicleId, updates)
			if ClientSystems.VehicleClient then
				ClientSystems.VehicleClient.OnVehicleUpdated(vehicleId, updates)
			end
		end)
	end

	-- Progression
	local levelUp = Remotes.LevelUp
	if levelUp then
		levelUp.OnClientEvent:Connect(function(newLevel, unlocks)
			if ClientSystems.ProgressionClient then
				ClientSystems.ProgressionClient.OnLevelUp(newLevel, unlocks)
			end
			if ClientSystems.NotificationsClient then
				ClientSystems.NotificationsClient.ShowLevelUp(newLevel, unlocks)
			end
		end)
	end

	local prestigeUp = Remotes.PrestigeUp
	if prestigeUp then
		prestigeUp.OnClientEvent:Connect(function(newPrestige, rewards)
			if ClientSystems.ProgressionClient then
				ClientSystems.ProgressionClient.OnPrestigeUp(newPrestige, rewards)
			end
			if ClientSystems.NotificationsClient then
				ClientSystems.NotificationsClient.ShowPrestigeUp(newPrestige, rewards)
			end
		end)
	end

	local unlockEarned = Remotes.UnlockEarned
	if unlockEarned then
		unlockEarned.OnClientEvent:Connect(function(unlockType, unlockId)
			if ClientSystems.ProgressionClient then
				ClientSystems.ProgressionClient.OnUnlockEarned(unlockType, unlockId)
			end
			if ClientSystems.NotificationsClient then
				ClientSystems.NotificationsClient.ShowUnlock(unlockType, unlockId)
			end
		end)
	end

	-- Notifications
	local notification = Remotes.Notification
	if notification then
		notification.OnClientEvent:Connect(function(notifData)
			if ClientSystems.NotificationsClient then
				ClientSystems.NotificationsClient.QueueNotification(notifData)
			end
		end)
	end

	-- Leaderboards
	local leaderboardUpdate = Remotes.LeaderboardUpdated
	if leaderboardUpdate then
		leaderboardUpdate.OnClientEvent:Connect(function(leaderboardId, entries)
			if ClientSystems.SocialClient then
				ClientSystems.SocialClient.OnLeaderboardUpdated(leaderboardId, entries)
			end
		end)
	end

	-- Events
	local eventStarted = Remotes.EventStarted
	if eventStarted then
		eventStarted.OnClientEvent:Connect(function(event)
			if ClientSystems.NotificationsClient then
				ClientSystems.NotificationsClient.ShowEvent(event)
			end
			if ClientSystems.ContractClient then
				ClientSystems.ContractClient.OnEventStarted(event)
			end
		end)
	end

	local eventEnded = Remotes.EventEnded
	if eventEnded then
		eventEnded.OnClientEvent:Connect(function(eventId)
			if ClientSystems.ContractClient then
				ClientSystems.ContractClient.OnEventEnded(eventId)
			end
		end)
	end

	local eventProgress = Remotes.EventProgress
	if eventProgress then
		eventProgress.OnClientEvent:Connect(function(eventId, progress)
			if ClientSystems.ContractClient then
				ClientSystems.ContractClient.OnEventProgress(eventId, progress)
			end
		end)
	end

	-- Daily Rewards
	local dailyRewardAvailable = Remotes.DailyRewardAvailable
	if dailyRewardAvailable then
		dailyRewardAvailable.OnClientEvent:Connect(function(day, reward)
			if ClientSystems.NotificationsClient then
				ClientSystems.NotificationsClient.ShowDailyReward(day, reward)
			end
		end)
	end

	local dailyRewardClaimed = Remotes.DailyRewardClaimed
	if dailyRewardClaimed then
		dailyRewardClaimed.OnClientEvent:Connect(function(day, reward)
			if ClientSystems.NotificationsClient then
				ClientSystems.NotificationsClient.ShowDailyRewardClaimed(day, reward)
			end
		end)
	end

	-- Weekly Challenges
	local weeklyChallengeUpdate = Remotes.WeeklyChallengeUpdated
	if weeklyChallengeUpdate then
		weeklyChallengeUpdate.OnClientEvent:Connect(function(challenges)
			if ClientSystems.ContractClient then
				ClientSystems.ContractClient.OnWeeklyChallengesUpdated(challenges)
			end
		end)
	end

	-- Settings
	local settingsSync = Remotes.RequestSettings
	if settingsSync then
		settingsSync.OnClientEvent:Connect(function(settings)
			if ClientSystems.SettingsClient then
				ClientSystems.SettingsClient.OnSettingsReceived(settings)
			end
		end)
	end

	Utils.DebugLog("All remote handlers connected")
end

-- ============================================
- SERVER REQUESTS
-- ============================================

function ClientBootstrap.RequestContract(districtId: string?)
	local remote = RemoteFunctions.RequestContract
	if remote then
		return remote:InvokeServer(districtId)
	end
end

function ClientBootstrap.AcceptContract(contractId: string)
	local remote = Remotes.AcceptContract
	if remote then
		remote:FireServer(contractId)
	end
end

function ClientBootstrap.CompleteDelivery(contractId: string, condition: number)
	local remote = Remotes.CompleteDelivery
	if remote then
		remote:FireServer(contractId, condition)
	end
end

function ClientBootstrap.CancelContract(contractId: string)
	local remote = Remotes.CancelContract
	if remote then
		remote:FireServer(contractId)
	end
end

function ClientBootstrap.PurchaseVehicle(category: string, modelName: string, customizations: any?)
	local remote = RemoteFunctions.PurchaseVehicle
	if remote then
		return remote:InvokeServer(category, modelName, customizations)
	end
end

function ClientBootstrap.SellVehicle(vehicleId: string)
	local remote = Remotes.SellVehicle
	if remote then
		remote:FireServer(vehicleId)
	end
end

function ClientBootstrap.UpgradeVehicle(vehicleId: string, slot: string)
	local remote = Remotes.UpgradeVehicle
	if remote then
		remote:FireServer(vehicleId, slot)
	end
end

function ClientBootstrap.PurchaseUpgrade(slot: string, level: number)
	local remote = Remotes.PurchaseUpgrade
	if remote then
		remote:FireServer(slot, level)
	end
end

function ClientBootstrap.UpgradeHideout(tier: string, upgradeId: string)
	local remote = Remotes.UpgradeHideout
	if remote then
		remote:FireServer(tier, upgradeId)
	end
end

function ClientBootstrap.CollectHideoutIncome()
	local remote = Remotes.CollectHideoutIncome
	if remote then
		remote:FireServer()
	end
end

function ClientBootstrap.RefuelVehicle(vehicleId: string, amount: number?)
	local remote = Remotes.RefuelVehicle
	if remote then
		remote:FireServer(vehicleId, amount)
	end
end

function ClientBootstrap.RepairVehicle(vehicleId: string)
	local remote = Remotes.RepairVehicle
	if remote then
		remote:FireServer(vehicleId)
	end
end

function ClientBootstrap.EquipLivery(vehicleId: string, liveryId: string)
	local remote = Remotes.EquipLivery
	if remote then
		remote:FireServer(vehicleId, liveryId)
	end
end

function ClientBootstrap.SetVehicleColor(vehicleId: string, color: Color3)
	local remote = Remotes.SetVehicleColor
	if remote then
		remote:FireServer(vehicleId, color)
	end
end

function ClientBootstrap.RequestLeaderboard(leaderboardId: string)
	local remote = RemoteFunctions.RequestLeaderboard
	if remote then
		return remote:InvokeServer(leaderboardId)
	end
end

function ClientBootstrap.ReportPlayer(targetUserId: number, reason: string)
	local remote = Remotes.ReportPlayer
	if remote then
		remote:FireServer(targetUserId, reason)
	end
end

function ClientBootstrap.RequestSettings()
	local remote = RemoteFunctions.RequestSettings
	if remote then
		return remote:InvokeServer()
	end
end

function ClientBootstrap.UpdateSettings(settings: any)
	local remote = Remotes.UpdateSettings
	if remote then
		remote:FireServer(settings)
	end
end

-- ============================================
- DATA SYNC HANDLER
-- ============================================

function ClientBootstrap.OnPlayerDataSynced(data: any)
	Utils.DebugLog("Player data synced")

	-- Initialize all systems with data
	for _, system in pairs(ClientSystems) do
		if system.OnDataSynced then
			system.OnDataSynced(data)
		end
	end

	-- Update UI
	if ClientSystems.UIController then
		ClientSystems.UIController.OnDataSynced(data)
	end

	-- Fire signal
	Signals.GameSignals.PlayerLoaded:Fire(data)
end

-- ============================================
- VEHICLE INPUT FORWARDING
-- ============================================

local lastVehicleInput = {}
local INPUT_SEND_RATE = 1/30 -- 30 Hz

RunService.Heartbeat:Connect(function(dt)
	local vehicleId = ClientBootstrap.GetActiveVehicleId()
	if not vehicleId then return end

	local now = os.clock()
	local lastSent = lastVehicleInput[vehicleId] or 0

	if now - lastSent >= INPUT_SEND_RATE then
		local input = ClientBootstrap.GetCurrentVehicleInput()
		if input then
			local remote = Remotes.VehicleInput
			if remote then
				remote:FireServer(vehicleId, input)
			end
			lastVehicleInput[vehicleId] = now
		end
	end
end)

function ClientBootstrap.GetActiveVehicleId(): string?
	-- Get from VehicleClient
	if ClientSystems.VehicleClient then
		return ClientSystems.VehicleClient.GetActiveVehicleId()
	end
	return nil
end

function ClientBootstrap.GetCurrentVehicleInput(): any?
	-- Get from InputManager
	if ClientSystems.InputManager then
		return ClientSystems.InputManager.GetVehicleInput()
	end
	return nil
end

-- ============================================
- INITIALIZATION
-- ============================================

function ClientBootstrap.Initialize()
	Utils.DebugLog("ClientBootstrap initializing...")

	-- Wait for ReplicatedStorage to be ready
	if not ReplicatedStorage:FindFirstChild("Shared") then
		ReplicatedStorage:WaitForChild("Shared", 10)
	end

	SetupRemotes()
	LoadClientSystems()
	ConnectRemoteHandlers()

	-- Request initial settings
	ClientBootstrap.RequestSettings()

	Utils.DebugLog("ClientBootstrap initialized")
end

-- ============================================
- CLEANUP
-- ============================================

function ClientBootstrap.Cleanup()
	for _, system in pairs(ClientSystems) do
		if system.Cleanup then
			system.Cleanup()
		end
	end
	ClientSystems = {}
end

-- Auto-initialize
ClientBootstrap.Initialize()

return ClientBootstrap