--[[
	UNDERGROUND — Contract Server
	Procedural contract generation, acceptance, tracking, and completion.
	The core gameplay loop driver.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)
local PlayerDataServer = require(script.Parent.PlayerDataServer)
local InventoryServer = require(script.Parent.InventoryServer)
local EconomyServer = require(script.Parent.EconomyServer)

local ContractServer = {}

-- ============================================
-- CONTRACT STATE
-- ============================================

local activeContracts = {} -- [contractId] = ContractInstance
local availableContracts = {} -- [districtId] = { ContractInstance }
local playerActiveContracts = {} -- [userId] = contractId
local deliverySessions = {} -- [contractId] = DeliverySession
local contractGeneratorThread = nil

local CONTRACT_REFRESH_INTERVAL = 30 -- seconds
local MAX_CONTRACTS_PER_DISTRICT = 8
local MAX_ACTIVE_CONTRACTS_PER_PLAYER = 1

-- ============================================
-- CONTRACT GENERATION
-- ============================================

local function GetPickupLocations(district: string): { Vector3 }
	-- In production, these would be predefined spawn points in the map
	-- For now, return district-appropriate zones
	local districtData = Constants.GetDistrict(district)
	if not districtData then return {} end

	-- This would reference actual spawn points in the map
	-- Placeholder: return district center with some variance
	local districtCenters = {
		Downtown = Vector3.new(0, 10, 0),
		Industrial = Vector3.new(500, 10, 500),
		Residential = Vector3.new(-500, 10, -500),
		Commercial = Vector3.new(0, 10, 500),
		Warehouse = Vector3.new(-500, 10, 500),
		UndergroundParking = Vector3.new(0, -50, 0),
		RestrictedZone = Vector3.new(1000, 10, 1000),
	}

	local center = districtCenters[district] or Vector3.new(0, 10, 0)
	local locations = {}

	for i = 1, 5 do
		local offset = Utils.RandomInRadius(100)
		table.insert(locations, center + offset)
	end

	return locations
end

local function GetDropoffLocations(district: string): { Vector3 }
	-- Similar to pickup but different zones
	local pickupLocations = GetPickupLocations(district)
	local dropoffLocations = {}

	for _, loc in ipairs(pickupLocations) do
		local offset = Utils.RandomInRadius(200)
		table.insert(dropoffLocations, loc + offset)
	end

	return dropoffLocations
end

local function CalculatePathDistance(start: Vector3, finish: Vector3): number
	-- Use PathfindingService for accurate distance
	local path = PathfindingService:CreatePath({
		AgentRadius = 3,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 10,
	})

	local success = pcall(function()
		path:ComputeAsync(start, finish)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		local distance = 0
		for i = 2, #waypoints do
			distance += (waypoints[i].Position - waypoints[i-1].Position).Magnitude
		end
		return distance
	end

	-- Fallback: straight line distance
	return (finish - start).Magnitude
end

local function GenerateWaypoints(start: Vector3, finish: Vector3): { Vector3 }
	local path = PathfindingService:CreatePath({
		AgentRadius = 3,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 15,
	})

	pcall(function()
		path:ComputeAsync(start, finish)
	end)

	if path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		local positions = {}
		for _, wp in ipairs(waypoints) do
			table.insert(positions, wp.Position)
		end
		return positions
	end

	-- Fallback: direct path
	return { start, finish }
end

-- ============================================
-- CONTRACT CREATION
-- ============================================

function ContractServer.CreateContract(districtId: string?, playerLevel: number?): any
	playerLevel = playerLevel or 1
	districtId = districtId or "Downtown"

	local districtData = Constants.GetDistrict(districtId)
	if not districtData then return nil end

	-- Determine available contract types based on level
	local availableTypes = {}
	for _, contractType in pairs(Constants.ContractTypes) do
		if (contractType.MinLevel or 1) <= (playerLevel or 1) then
			table.insert(availableTypes, contractType)
		end
	end

	if #availableTypes == 0 then return nil end

	-- Weighted random selection
	local contractTypeData = Utils.WeightedRandom(availableTypes, function(ct)
		-- Higher level = more chance for better contracts
		local baseWeight = 1
		if ct.Id == "Standard" then return 10 end
		if ct.Id == "Express" then return 5 end
		if ct.Id == "Fragile" then return 5 end
		if ct.Id == "Covert" then return 3 end
		if ct.Id == "Hot" then return 2 end
		if ct.Id == "Convoy" then return 1 end
		if ct.Id == "BlackMarket" then return 1 end
		return 1
	end)

	if not contractTypeData then return nil end

	-- Select rarity (higher level = better rarity chances)
	local rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
	local rarityWeights = { 50, 25, 15, 7, 3 }
	if playerLevel >= 10 then rarityWeights = { 30, 25, 20, 15, 10 } end
	if playerLevel >= 25 then rarityWeights = { 20, 20, 20, 20, 20 } end

	local rarity = Utils.WeightedRandom(rarities, function(r)
		for i, rar in ipairs(rarities) do
			if rar == r then return rarityWeights[i] end
		end
		return 1
	end)

	-- Select package type
	local packageTypes = { "Standard", "Fragile", "Timed", "Hot", "Cold", "Live", "Explosive", "Data", "Artifact", "Prototype" }
	local packageType = packageTypes[math.random(#packageTypes)]

	-- Generate locations
	local pickupLocations = GetPickupLocations(districtId)
	local dropoffLocations = GetDropoffLocations(districtId)

	local pickupPos = pickupLocations[math.random(#pickupLocations)]
	local dropoffPos = dropoffLocations[math.random(#dropoffLocations)]

	-- Generate waypoints
	local waypoints = GenerateWaypoints(pickupPos, dropoffPos)

	-- Calculate distance and time
	local distance = 0
	for i = 2, #waypoints do
		distance += (waypoints[i] - waypoints[i-1]).Magnitude
	end

	local estimatedTime = distance / 20 -- ~20 studs/sec average speed

	-- Create package
	local packageData = InventoryServer.CreatePackage(packageType, rarity)
	if not packageData then return nil end

	-- Calculate rewards
	local baseReward = math.floor(100 * Constants.GetPackageRarity(rarity).ValueMultiplier * contractTypeData.RewardMultiplier)
	local distanceBonus = math.floor(distance * Constants.Economy.DistanceRewardPerStud)

	local contract = {
		Id = Utils.GenerateUUID(),
		Type = contractTypeData.Id,
		DisplayName = contractTypeData.DisplayName,

		-- Package
		PackageId = packageData.Id,
		PackageRarity = rarity,
		PackageType = packageType,

		-- Locations
		PickupLocation = pickupPos,
		PickupDistrict = districtId,
		DropoffLocation = dropoffPos,
		DropoffDistrict = districtId, -- Could be different district

		-- Route
		Waypoints = waypoints,
		EstimatedDistance = distance,
		EstimatedTime = estimatedTime,

		-- Timing
		CreatedAt = os.time(),
		ExpiresAt = os.time() + (contractTypeData.TimeMultiplier * estimatedTime * 2) + 300, -- Base time + buffer
		AcceptedAt = nil,
		StartedAt = nil,
		CompletedAt = nil,

		-- Rewards
		BaseReward = baseReward,
		DistanceBonus = distanceBonus,
		TimeBonus = 0, -- Calculated on completion
		ConditionBonus = 0, -- Calculated on completion
		TotalReward = baseReward + distanceBonus,
		XPReward = math.floor((baseReward + distanceBonus) * 0.1),

		-- State
		Status = "Available",
		AssignedPlayer = nil,
		Competitors = {},

		-- Risk
		HeatGain = contractTypeData.HeatGain,
		RiskLevel = districtData.SurveillanceLevel,
		RequiresVehicle = nil,
		RequiresUpgrade = nil,

		-- Special
		IsCompetitive = (contractTypeData.Id == "Convoy" or contractTypeData.Id == "BlackMarket"),
		IsEvent = false,
		EventId = nil,
	}

	-- Apply contract type specific modifications
	if contractTypeData.Id == "Express" then
		contract.ExpiresAt = os.time() + estimatedTime * 1.5
		contract.TotalReward = math.floor(contract.TotalReward * 1.5)
		contract.XPReward = math.floor(contract.XPReward * 1.5)
	elseif contractTypeData.Id == "Covert" then
		contract.HeatGain = 0
		contract.RequiresVehicle = "Sedan" -- Prefer inconspicuous
	elseif contractTypeData.Id == "Hot" then
		contract.HeatGain = 3
		contract.RequiresUpgrade = "Armor"
	elseif contractTypeData.Id == "Convoy" then
		contract.RequiresVehicle = "Van"
		contract.RequiresUpgrade = "Storage"
	elseif contractTypeData.Id == "BlackMarket" then
		contract.HeatGain = 4
		contract.RequiresUpgrade = "Stealth"
	end

	return contract
end

-- ============================================
-- CONTRACT BOARD REFRESH
-- ============================================

function ContractServer.RefreshContractBoard(districtId: string?)
	local targetDistricts = districtId and { districtId } or Constants.DistrictOrder

	for _, distId in ipairs(targetDistricts) do
		local currentCount = #(availableContracts[distId] or {})

		while currentCount < MAX_CONTRACTS_PER_DISTRICT do
			-- Generate contracts for different player levels (1-100)
			-- In production, would tailor to online players' levels
			local level = math.random(1, 50)
			local contract = ContractServer.CreateContract(distId, level)

			if contract then
				availableContracts[distId] = availableContracts[distId] or {}
				table.insert(availableContracts[distId], contract)
				currentCount += 1
			else
				break
			end
		end

		-- Notify players in district
		ContractServer.BroadcastContractBoard(distId)
	end
end

function ContractServer.BroadcastContractBoard(districtId: string)
	local contracts = availableContracts[districtId] or {}

	-- Send to all players in district
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = PlayerDataServer.GetProfile(player.UserId)
		if profile and profile.CurrentDistrict == districtId then
			local remote = ReplicatedStorage:FindFirstChild("Remotes", true)
			if remote then
				local updateRemote = remote:FindFirstChild("ContractBoardUpdate")
				if updateRemote then
					updateRemote:FireClient(player, districtId, contracts)
				end
			end
		end
	end
end

-- ============================================
-- CONTRACT ACCEPTANCE
-- ============================================

function ContractServer.AcceptContract(userId: number, contractId: string): (boolean, any?, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, nil, "Player not found" end

	-- Check if player already has active contract
	if playerActiveContracts[userId] then
		return false, nil, "Already have an active contract"
	end

	-- Find contract in available pools
	local contract = nil
	local sourceDistrict = nil

	for distId, contracts in pairs(availableContracts) do
		for i, c in ipairs(contracts) do
			if c.Id == contractId then
				contract = c
				sourceDistrict = distId
				table.remove(contracts, i)
				break
			end
		end
		if contract then break end
	end

	if not contract then
		return false, nil, "Contract not found or already taken"
	end

	-- Check requirements
	if contract.RequiresVehicle then
		local activeVehicle = InventoryServer.GetActiveVehicle(userId)
		if not activeVehicle or activeVehicle.Category ~= contract.RequiresVehicle then
			return false, nil, "Requires " .. contract.RequiresVehicle .. " category vehicle"
		end
	end

	if contract.RequiresUpgrade then
		local activeVehicle = InventoryServer.GetActiveVehicle(userId)
		if not activeVehicle or (activeVehicle.Upgrades[contract.RequiresUpgrade] or 0) == 0 then
			return false, nil, "Requires " .. contract.RequiresUpgrade .. " upgrade"
		end
	end

	-- Update contract state
	contract.Status = "Accepted"
	contract.AssignedPlayer = userId
	contract.AcceptedAt = os.time()

	-- Create delivery session
	local session = {
		ContractId = contractId,
		PlayerId = userId,
		VehicleId = InventoryServer.GetActiveVehicle(userId) and InventoryServer.GetActiveVehicle(userId).Id,

		StartTime = os.time(),
		LastCheckpoint = 0,
		CheckpointsPassed = {},

		CurrentHeat = PlayerDataServer.GetProfile(userId).HeatLevel or 0,
		HeatGain = contract.HeatGain,

		DistanceTraveled = 0,
		TimeElapsed = 0,

		ConditionAtStart = 100,
		CurrentCondition = 100,

		PoliceEngaged = false,
		Pursuers = {},

		RouteDeviations = 0,
		SpeedViolations = 0,
		Collisions = 0,
	}

	deliverySessions[contractId] = session
	playerActiveContracts[userId] = contractId
	activeContracts[contractId] = contract

	-- Update player profile
	PlayerDataServer.UpdateProfile(userId, { ActiveContract = contract })

	-- Spawn package in world if not already there
	local pickupPos = contract.PickupLocation
	InventoryServer.SpawnPackage({
		Id = contract.PackageId,
		Type = contract.PackageType,
		Rarity = contract.PackageRarity,
		WorldPosition = pickupPos,
		District = contract.PickupDistrict,
		IsInWorld = true,
	}, pickupPos, contract.PickupDistrict)

	-- Notify client
	local player = Players:GetPlayerByUserId(userId)
	if player then
		local remote = ReplicatedStorage:FindFirstChild("Remotes", true)
		if remote then
			local contractAccepted = remote:FindFirstChild("ContractAccepted")
			if contractAccepted then
				contractAccepted:FireClient(player, contract, session)
			end
		end
	end

	Signals.GameSignals.ContractAccepted:Fire(userId, contract, session)

	return true, contract, nil
end

-- ============================================
- DELIVERY PROGRESS TRACKING
-- ============================================

function ContractServer.UpdateDeliveryProgress(userId: number, progressData: any)
	local contractId = playerActiveContracts[userId]
	if not contractId then return end

	local session = deliverySessions[contractId]
	if not session then return end

	-- Update session data
	session.DistanceTraveled = progressData.DistanceTraveled or session.DistanceTraveled
	session.TimeElapsed = progressData.TimeElapsed or session.TimeElapsed
	session.CurrentHeat = progressData.CurrentHeat or session.CurrentHeat
	session.CurrentCondition = progressData.CurrentCondition or session.CurrentCondition
	session.RouteDeviations = progressData.RouteDeviations or session.RouteDeviations
	session.SpeedViolations = progressData.SpeedViolations or session.SpeedViolations
	session.Collisions = progressData.Collisions or session.Collisions

	-- Check waypoint progress
	if progressData.CheckpointIndex and progressData.CheckpointIndex > session.LastCheckpoint then
		session.LastCheckpoint = progressData.CheckpointIndex
		table.insert(session.CheckpointsPassed, progressData.CheckpointIndex)
	end

	-- Update active contract
	local contract = activeContracts[playerActiveContracts[userId]]
	if contract then
		contract.Status = "Active"
		contract.StartedAt = contract.StartedAt or os.time()
	end

	-- Broadcast progress
	Signals.GameSignals.DeliveryProgress:Fire(userId, session)
end

-- ============================================
- DELIVERY COMPLETION
-- ============================================

function ContractServer.CompleteDelivery(userId: number, contractId: string, condition: number): (boolean, any?, string?)
	local session = deliverySessions[contractId]
	if not session or session.PlayerId ~= userId then
		return false, nil, "Invalid delivery session"
	end

	local contract = activeContracts[contractId]
	if not contract then return false, nil, "Contract not found" end

	if contract.Status == "Completed" or contract.Status == "Failed" then
		return false, nil, "Contract already resolved"
	end

	-- Update contract
	contract.Status = "Completed"
	contract.CompletedAt = os.time()

	-- Calculate rewards
	local deliveryData = {
		PlayerId = userId,
		VehicleCategory = InventoryServer.GetActiveVehicle(userId) and InventoryServer.GetActiveVehicle(userId).Category,
		TimeElapsed = os.time() - (session.StartTime or os.time()),
		ConditionAtStart = session.ConditionAtStart,
		CurrentCondition = condition,
		CurrentHeat = session.CurrentHeat,
	}

	local rewards = EconomyServer.CalculateDeliveryReward(contract, deliveryData)

	-- Apply rewards
	EconomyServer.ApplyDeliveryRewards(userId, rewards)

	-- Apply heat
	if contract.HeatGain > 0 then
		PlayerDataServer.AddHeat(userId, contract.HeatGain, "DeliveryComplete")
	end

	-- Update stats
	local profile = PlayerDataServer.GetProfile(userId)
	if profile then
		profile.Stats.TotalDistance = (profile.Stats.TotalDistance or 0) + (contract.EstimatedDistance or 0)
	end

	-- Cleanup
	deliverySessions[contractId] = nil
	playerActiveContracts[userId] = nil
	activeContracts[contractId] = nil

	-- Remove package from world if still there
	-- (Package should have been picked up already)

	-- Notify client
	local player = Players:GetPlayerByUserId(userId)
	if player then
		local remote = ReplicatedStorage:FindFirstChild("Remotes", true)
		if remote then
			local deliveryComplete = remote:FindFirstChild("DeliveryComplete")
			if deliveryComplete then
				deliveryComplete:FireClient(player, rewards, contract)
			end
		end
	end

	Signals.GameSignals.DeliveryCompleted:Fire(userId, contract, rewards)
	Signals.GameSignals.ContractCompleted:Fire(userId, contract)

	return true, rewards, nil
end

function ContractServer.FailDelivery(userId: number, contractId: string, reason: string): (boolean, string?)
	local session = deliverySessions[contractId]
	if not session or session.PlayerId ~= userId then
		return false, "Invalid delivery session"
	end

	local contract = activeContracts[contractId]
	if not contract then return false, "Contract not found" end

	contract.Status = "Failed"
	contract.CompletedAt = os.time()

	-- Apply penalties
	EconomyServer.ApplyContractFailure(userId, contract, reason)

	-- Apply heat penalty
	PlayerDataServer.AddHeat(userId, 2, "DeliveryFailed:" .. reason)

	-- Cleanup
	deliverySessions[contractId] = nil
	playerActiveContracts[userId] = nil
	activeContracts[contractId] = nil

	-- Notify client
	local player = Players:GetPlayerByUserId(userId)
	if player then
		local remote = ReplicatedStorage:FindFirstChild("Remotes", true)
		if remote then
			local deliveryFailed = remote:FindFirstChild("DeliveryFailed")
			if deliveryFailed then
				deliveryFailed:FireClient(player, reason)
			end
		end
	end

	Signals.GameSignals.DeliveryFailed:Fire(userId, contract, reason)
	Signals.GameSignals.ContractFailed:Fire(userId, contract, reason)

	return true, nil
end

-- ============================================
- CONTRACT EXPIRATION
-- ============================================

task.spawn(function()
	while true do
		task.wait(30) -- Check every 30 seconds

		local now = os.time()
		for distId, contracts in pairs(availableContracts) do
			for i = #contracts, 1, -1 do
				local contract = contracts[i]
				if contract.ExpiresAt and now >= contract.ExpiresAt then
					-- Contract expired
					table.remove(contracts, i)
					ContractServer.BroadcastContractBoard(distId)
				end
			end
		end

		-- Check active contracts for expiration
		for contractId, contract in pairs(activeContracts) do
			if contract.ExpiresAt and now >= contract.ExpiresAt then
				if contract.Status == "Accepted" or contract.Status == "Active" then
					local userId = contract.AssignedPlayer
					ContractServer.FailDelivery(userId, contractId, "TimeExpired")
				end
			end
		end
	end
end)

-- ============================================
- HELPER FUNCTIONS
-- ============================================

function ContractServer.GetActiveContract(userId: number): any?
	local contractId = playerActiveContracts[userId]
	return contractId and activeContracts[contractId]
end

function ContractServer.GetDeliverySession(userId: number): any?
	local contractId = playerActiveContracts[userId]
	return contractId and deliverySessions[contractId]
end

function ContractServer.GetAvailableContracts(districtId: string?): { any }
	if districtId then
		return availableContracts[districtId] or {}
	end

	-- Return all
	local all = {}
	for _, contracts in pairs(availableContracts) do
		for _, c in ipairs(contracts) do
			table.insert(all, c)
		end
	end
	return all
end

function ContractServer.CancelContract(userId: number, contractId: string): (boolean, string?)
	local contract = activeContracts[contractId]
	if not contract or contract.AssignedPlayer ~= userId then
		return false, "Contract not found or not yours"
	end

	if contract.Status == "Completed" or contract.Status == "Failed" then
		return false, "Contract already resolved"
	end

	-- Penalty for cancellation
	EconomyServer.ApplyContractFailure(userId, contract, "Cancelled")

	-- Cleanup
	deliverySessions[contractId] = nil
	playerActiveContracts[userId] = nil
	activeContracts[contractId] = nil

	return true, nil
end

-- ============================================
- EVENT CONTRACTS
-- ============================================

function ContractServer.CreateEventContract(eventData: any): any
	local contract = ContractServer.CreateContract(eventData.District, eventData.Level)
	if not contract then return nil end

	contract.IsEvent = true
	contract.EventId = eventData.Id
	contract.TotalReward = math.floor(contract.TotalReward * (eventData.RewardMultiplier or 1.5))
	contract.XPReward = math.floor(contract.XPReward * (eventData.XPMultiplier or 1.5))
	contract.ExpiresAt = os.time() + (eventData.Duration or 3600)

	return contract
end

-- ============================================
- INITIALIZATION
-- ============================================

-- Initial contract board population
task.spawn(function()
	task.wait(5) -- Wait for other systems
	ContractServer.RefreshContractBoard()
end)

-- Periodic refresh
task.spawn(function()
	while true do
		task.wait(CONTRACT_REFRESH_INTERVAL)
		ContractServer.RefreshContractBoard()
	end
end)

Utils.DebugLog("ContractServer initialized")

return ContractServer