--[[
	UNDERGROUND — Heat Server
	Manages the 0-5 star heat/suspicion system, police response scaling,
	and district heat levels.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)
local PlayerDataServer = require(script.Parent.PlayerDataServer)

local HeatServer = {}

-- ============================================
-- HEAT STATE
-- ============================================

local playerHeat = {} -- [userId] = { level, sources, lastGain }
local districtHeat = {} -- [districtId] = level
local globalHeat = 0
local heatDecayThreads = {} -- [userId] = thread

local HEAT_DECAY_DELAY = Constants.Heat.DecayDelay
local HEAT_DECAY_RATE = Constants.Heat.BaseDecayRate -- Stars per minute

-- ============================================
-- HEAT GAIN
-- ============================================

function HeatServer.AddHeat(userId: number, amount: number, source: string?): (boolean, number?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, nil end

	local oldLevel = profile.HeatLevel or 0
	local newLevel = math.clamp(oldLevel + amount, 0, Constants.Heat.MaxStars)

	-- Track sources
	local heatRecord = playerHeat[userId] or { level = 0, sources = {}, lastGain = 0 }
	heatRecord.level = newLevel
	heatRecord.lastGain = os.time()
	table.insert(heatRecord.sources, {
		Amount = amount,
		Source = source or "Unknown",
		Time = os.time(),
		PreviousLevel = oldLevel,
		NewLevel = newLevel,
	})

	-- Keep only recent sources (last 20)
	while #heatRecord.sources > 20 do
		table.remove(heatRecord.sources, 1)
	end

	playerHeat[userId] = heatRecord

	-- Update profile
	PlayerDataServer.SetHeatLevel(userId, newLevel, source)

	-- Update district heat
	HeatServer.UpdateDistrictHeat(profile.CurrentDistrict or "Downtown", amount)

	-- Check thresholds
	HeatServer.CheckHeatThresholds(userId, oldLevel, newLevel)

	-- Start/restart decay thread
	HeatServer.StartDecayThread(userId)

	return true, newLevel
end

function HeatServer.RemoveHeat(userId: number, amount: number, source: string?): (boolean, number?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, nil end

	local oldLevel = profile.HeatLevel or 0
	local newLevel = math.clamp(oldLevel - amount, 0, Constants.Heat.MaxStars)

	local heatRecord = playerHeat[userId]
	if heatRecord then
		heatRecord.level = newLevel
		table.insert(heatRecord.sources, {
			Amount = -amount,
			Source = source or "Decay",
			Time = os.time(),
			PreviousLevel = oldLevel,
			NewLevel = newLevel,
		})
	end

	PlayerDataServer.SetHeatLevel(userId, newLevel, source)

	return true, newLevel
end

function HeatServer.SetHeat(userId: number, level: number, source: string?): (boolean, number?)
	level = math.clamp(level, 0, Constants.Heat.MaxStars)

	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, nil end

	local oldLevel = profile.HeatLevel or 0
	local heatRecord = playerHeat[userId] or { level = 0, sources = {}, lastGain = 0 }
	heatRecord.level = level

	table.insert(heatRecord.sources, {
		Amount = level - oldLevel,
		Source = source or "ManualSet",
		Time = os.time(),
		PreviousLevel = oldLevel,
		NewLevel = level,
	})

	playerHeat[userId] = heatRecord

	PlayerDataServer.SetHeatLevel(userId, level, source)

	return true, level
end

function HeatServer.GetHeat(userId: number): number
	local profile = PlayerDataServer.GetProfile(userId)
	return profile and profile.HeatLevel or 0
end

function HeatServer.GetHeatRecord(userId: number): any
	return playerHeat[userId]
end

-- ============================================
- DISTRICT HEAT
-- ============================================

function HeatServer.UpdateDistrictHeat(districtId: string, amount: number)
	local current = districtHeat[districtId] or 0
	districtHeat[districtId] = math.clamp(current + amount, 0, Constants.Heat.MaxStars)

	-- Update global heat (average of districts)
	local total = 0
	local count = 0
	for _, heat in pairs(districtHeat) do
		total += heat
		count += 1
	end
	globalHeat = count > 0 and total / count or 0

	-- Notify police system of district heat changes
	Signals.GameSignals.HeatChanged:Fire("District", districtId, districtHeat[districtId])
end

function HeatServer.GetDistrictHeat(districtId: string): number
	return districtHeat[districtId] or 0
end

function HeatServer.GetGlobalHeat(): number
	return globalHeat
end

function HeatServer.GetAllDistrictHeat(): { [string]: number }
	return districtHeat
end

-- ============================================
- HEAT DECAY
-- ============================================

function HeatServer.StartDecayThread(userId: number)
	-- Cancel existing thread
	if heatDecayThreads[userId] then
		task.cancel(heatDecayThreads[userId])
	end

	heatDecayThreads[userId] = task.spawn(function()
		-- Wait for decay delay
		task.wait(HEAT_DECAY_DELAY)

		while true do
			local profile = PlayerDataServer.GetProfile(userId)
			if not profile or (profile.HeatLevel or 0) <= 0 then
				heatDecayThreads[userId] = nil
				break
			end

			-- Check if recently gained heat
			local heatRecord = playerHeat[userId]
			if heatRecord and (os.time() - heatRecord.lastGain) < HEAT_DECAY_DELAY then
				task.wait(HEAT_DECAY_DELAY)
				continue
			end

			-- Decay heat
			HeatServer.RemoveHeat(userId, HEAT_DECAY_RATE / 60, "Decay") -- Per second

			task.wait(1) -- Check every second
		end
	end)
end

function HeatServer.StopDecayThread(userId: number)
	if heatDecayThreads[userId] then
		task.cancel(heatDecayThreads[userId])
		heatDecayThreads[userId] = nil
	end
end

-- ============================================
- THRESHOLD CHECKING
-- ============================================

function HeatServer.CheckHeatThresholds(userId: number, oldLevel: number, newLevel: number)
	local thresholds = Constants.Heat.Thresholds

	for thresholdName, thresholdLevel in pairs(thresholds) do
		if oldLevel < thresholdLevel and newLevel >= thresholdLevel then
			HeatServer.OnThresholdCrossed(userId, thresholdName, thresholdLevel)
		elseif oldLevel >= thresholdLevel and newLevel < thresholdLevel then
			HeatServer.OnThresholdDropped(userId, thresholdName, thresholdLevel)
		end
	end

	-- Visual/audio effects
	local effects = Constants.Heat.Effects[newLevel]
	if effects then
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local remote = ReplicatedStorage:FindFirstChild("Remotes", true)
			if remote then
				local heatEffect = remote:FindFirstChild("HeatEffectUpdate")
				if heatEffect then
					heatEffect:FireClient(player, effects)
				end
			end
		end
	end
end

function HeatServer.OnThresholdCrossed(userId: number, thresholdName: string, level: number)
	Utils.DebugLog("Heat threshold crossed:", userId, thresholdName, "->", level)

	-- Trigger police response
	if thresholdName == "PatrolSpawn" then
		Signals.GameSignals.PoliceSpawned:Fire(userId, "Patrol", level)
	elseif thresholdName == "HelicopterSpawn" then
		Signals.GameSignals.PoliceSpawned:Fire(userId, "Helicopter", level)
	elseif thresholdName == "Roadblocks" then
		Signals.GameSignals.PoliceSpawned:Fire(userId, "Roadblock", level)
	elseif thresholdName == "SpikeStrips" then
		Signals.GameSignals.PoliceSpawned:Fire(userId, "SpikeStrip", level)
	elseif thresholdName == "SWAT" then
		Signals.GameSignals.PoliceSpawned:Fire(userId, "SWAT", level)
	elseif thresholdName == "CityLockdown" then
		Signals.GameSignals.PoliceSpawned:Fire(userId, "Lockdown", level)
	end

	Signals.GameSignals.HeatChanged:Fire(userId, "ThresholdCrossed", thresholdName, level)
end

function HeatServer.OnThresholdDropped(userId: number, thresholdName: string, level: number)
	Utils.DebugLog("Heat threshold dropped:", userId, thresholdName, "->", level)

	-- Police de-escalation would happen here
	Signals.GameSignals.HeatChanged:Fire(userId, "ThresholdDropped", thresholdName, level)
end

-- ============================================
- HEAT EFFECTS
-- ============================================

function HeatServer.GetHeatEffects(userId: number): any
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return Constants.Heat.Effects[1] end

	local level = profile.HeatLevel or 0
	if level == 0 then return nil end

	return Constants.Heat.Effects[level] or Constants.Heat.Effects[1]
end

function HeatServer.GetHeatColor(userId: number): Color3
	local effects = HeatServer.GetHeatEffects(userId)
	return effects and effects.HUDColor or Color3.fromHex("#00FF88")
end

function HeatServer.GetHeatIntensity(userId: number): number
	local effects = HeatServer.GetHeatEffects(userId)
	return effects and effects.MusicIntensity or 0
end

function HeatServer.GetSirenDistance(userId: number): number
	local effects = HeatServer.GetHeatEffects(userId)
	return effects and effects.SirenDistance or 0
end

-- ============================================
- HEAT SOURCES
-- ============================================

--[[
	Register a heat gain source with custom behavior.
]]
function HeatServer.RegisterHeatSource(sourceName: string, config: {
	BaseAmount: number,
	Cooldown: number?, -- Seconds
	Condition: (userId: number) -> boolean?, -- Optional condition
	Stacking: boolean?, -- Whether multiple instances stack
}): boolean
	-- Store in a registry for reference
	if not HeatServer._heatSources then
		HeatServer._heatSources = {}
	end

	HeatServer._heatSources[sourceName] = config
	return true
end

-- Pre-register standard sources
HeatServer.RegisterHeatSource("StandardDelivery", { BaseAmount = 1 })
HeatServer.RegisterHeatSource("ExpressDelivery", { BaseAmount = 2 })
HeatServer.RegisterHeatSource("CovertDelivery", { BaseAmount = 0 })
HeatServer.RegisterHeatSource("CovertFailure", { BaseAmount = 3 })
HeatServer.RegisterHeatSource("HotDelivery", { BaseAmount = 3 })
HeatServer.RegisterHeatSource("ConvoyDelivery", { BaseAmount = 2 })
HeatServer.RegisterHeatSource("BlackMarketDelivery", { BaseAmount = 4 })
HeatServer.RegisterHeatSource("PoliceSpotted", { BaseAmount = 1, Cooldown = 5 })
HeatServer.RegisterHeatSource("CollisionCivilian", { BaseAmount = 1 })
HeatServer.RegisterHeatSource("CollisionPolice", { BaseAmount = 2 })
HeatServer.RegisterHeatSource("EnterRestrictedZone", { BaseAmount = 2 })
HeatServer.RegisterHeatSource("SpeedingInZone", { BaseAmount = 1, Cooldown = 3 })
HeatServer.RegisterHeatSource("Crash", { BaseAmount = 1 })
HeatServer.RegisterHeatSource("KillCivilian", { BaseAmount = 5, Cooldown = 30 })

--[[
	Gain heat from a registered source with cooldown handling.
]]
function HeatServer.GainHeatFromSource(userId: number, sourceName: string): (boolean, number?)
	local config = HeatServer._heatSources[sourceName]
	if not config then return false, 0 end

	-- Check cooldown
	if config.Cooldown then
		-- Check if recently gained from this source
		-- Would need to track per-source timestamps
	end

	-- Check condition
	if config.Condition then
		local profile = PlayerDataServer.GetProfile(userId)
		if not config.Condition(userId) then return false, 0 end
	end

	-- Apply heat
	return HeatServer.AddHeat(userId, config.BaseAmount, sourceName)
end

-- ============================================
- HEAT VISUALIZATION (Server -> Client)
-- ============================================

function HeatServer.BroadcastHeatUpdate(userId: number)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return end

	local effects = HeatServer.GetHeatEffects(userId)
	local player = Players:GetPlayerByUserId(userId)

	if player then
		local remote = ReplicatedStorage:FindFirstChild("Remotes", true)
		if remote then
			local heatUpdate = remote:FindFirstChild("HeatUpdate")
			if heatUpdate then
				heatUpdate:FireClient(player, {
					Level = profile.HeatLevel or 0,
					Effects = effects,
					Color = HeatServer.GetHeatColor(userId),
					Intensity = HeatServer.GetHeatIntensity(userId),
					SirenDistance = HeatServer.GetSirenDistance(userId),
				})
			end
		end
	end
end

-- ============================================
- INITIALIZATION
-- ============================================

Utils.DebugLog("HeatServer initialized")

return HeatServer