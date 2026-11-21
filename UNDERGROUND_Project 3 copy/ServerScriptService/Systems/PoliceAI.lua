--[[
	UNDERGROUND — Police AI System
	Patrols, pursuits, roadblocks, helicopters, and SWAT teams.
	Scales with heat level and district.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)
local HeatServer = require(script.Parent.HeatServer)

local PoliceAI = {}

-- ============================================
-- POLICE STATE
-- ============================================

local policeUnits = {} -- [unitId] = PoliceUnit
local patrolRoutes = {} -- [districtId] = { waypoints }
local activePursuits = {} -- [targetUserId] = { pursuers, startTime }
local roadblocks = {} -- [roadblockId] = Roadblock
local spikeStrips = {} -- [stripId] = SpikeStrip
local helicopters = {} -- [heliId] = Helicopter

local nextUnitId = 1
local nextRoadblockId = 1
local nextSpikeStripId = 1
local nextHeliId = 1

-- ============================================
-- PATROL ROUTES
-- ============================================

local function GeneratePatrolRoutes(districtId: string): { Vector3 }
	-- In production, these would be predefined in the map
	-- For now, generate around district center
	local centers = {
		Downtown = Vector3.new(0, 10, 0),
		Industrial = Vector3.new(500, 10, 500),
		Residential = Vector3.new(-500, 10, -500),
		Commercial = Vector3.new(0, 10, 500),
		Warehouse = Vector3.new(-500, 10, 500),
		UndergroundParking = Vector3.new(0, -50, 0),
		RestrictedZone = Vector3.new(1000, 10, 1000),
	}

	local center = centers[districtId] or Vector3.new(0, 10, 0)
	local waypoints = {}

	-- Generate a loop around the district
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		local radius = 150 + math.random() * 50
		local pos = center + Vector3.new(math.cos(angle) * radius, 10, math.sin(angle) * radius)
		table.insert(waypoints, pos)
	end

	return waypoints
end

-- Initialize patrol routes for all districts
for _, distId in ipairs(Constants.DistrictOrder) do
	patrolRoutes[distId] = GeneratePatrolRoutes(distId)
end

-- ============================================
-- POLICE UNIT CREATION
-- ============================================

local function CreatePoliceModel(unitType: string): Model
	local model = Instance.new("Model")
	model.Name = "Police_" .. unitType

	-- Base chassis
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(4, 1.5, 8)
	chassis.Anchored = false
	chassis.CanCollide = true
	chassis.Massless = false
	chassis.BrickColor = BrickColor.new("Really black")
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.Parent = model

	-- Lights
	local lightBar = Instance.new("Part")
	lightBar.Name = "LightBar"
	lightBar.Size = Vector3.new(3.5, 0.3, 1)
	lightBar.Position = Vector3.new(0, 2.5, 0)
	lightBar.Anchored = false
	lightBar.CanCollide = false
	lightBar.Massless = true
	lightBar.Transparency = 1
	lightBar.Parent = model

	-- Light attachments
	for _, pos in ipairs({ Vector3.new(-1.5, 2.5, 0), Vector3.new(1.5, 2.5, 0) }) do
		local attachment = Instance.new("Attachment")
		attachment.Name = "Light_" .. (pos.X > 0 and "Right" or "Left")
		attachment.Position = pos
		attachment.Parent = lightBar

		-- Point lights for sirens
		local pointLight = Instance.new("PointLight")
		pointLight.Color = Color3.fromRGB(0, 0, 255)
		pointLight.Range = 30
		pointLight.Brightness = 2
		pointLight.Enabled = false
		pointLight.Parent = attachment

		local pointLight2 = Instance.new("PointLight")
		pointLight2.Color = Color3.fromRGB(255, 0, 0)
		pointLight2.Range = 30
		pointLight2.Brightness = 2
		pointLight2.Enabled = false
		pointLight2.Parent = attachment
	end

	lightBar.Parent = model

	-- Wheels
	for _, pos in ipairs({
		Vector3.new(-1.5, 0.5, 3), Vector3.new(1.5, 0.5, 3),
		Vector3.new(-1.5, 0.5, -3), Vector3.new(1.5, 0.5, -3)
	}) do
		local wheel = Instance.new("Part")
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(0.5, 1.5, 1.5)
		wheel.Orientation = Vector3.new(0, 0, 90)
		wheel.Position = pos
		wheel.Anchored = false
		wheel.CanCollide = true
		wheel.Massless = false
		wheel.BrickColor = BrickColor.new("Really black")
		wheel.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = model.PrimaryPart or model:FindFirstChild("Chassis")
		weld.Part1 = wheel
		weld.Parent = model
	end

	-- Set primary part
	local chassis = model:FindFirstChild("Chassis")
	if not chassis then
		chassis = Instance.new("Part")
		chassis.Name = "Chassis"
		chassis.Size = Vector3.new(4, 1.5, 8)
		chassis.Anchored = false
		chassis.CanCollide = true
		chassis.Massless = false
		chassis.Parent = model
	end

	model.PrimaryPart = model:FindFirstChild("Chassis") or model:FindFirstChild("Chassis")
	return model
end

local function CreatePoliceUnit(unitType: string, districtId: string): any
	local unitId = nextUnitId
	nextUnitId += 1

	local model = CreatePoliceModel(unitType)
	model.Name = "PoliceUnit_" .. unitId
	model.Parent = Workspace.Live

	-- Setup physics
	local chassis = model.PrimaryPart
	if chassis then
		chassis.CollisionGroup = "Vehicles"
		chassis:SetNetworkOwner(nil) -- Server-owned
	end

	local unit = {
		Id = unitId,
		Type = unitType, -- "Patrol", "Pursuit", "Helicopter", "Roadblock", "SWAT"
		Model = model,
		District = districtId,
		State = "Idle", -- "Idle", "Patrolling", "Investigating", "Pursuing", "Returning", "Roadblock", "SpikeStrip"
		Waypoints = patrolRoutes[districtId] or {},
		CurrentWaypoint = 1,
		Target = nil, -- Vector3 or Player
		HeatLevel = 0,
		PatrolSpeed = Constants.Police.Patrol.VehicleCount,
		PursuitSpeed = Constants.Police.Pursuit.PursuitSpeed,
		DetectionRange = Constants.Police.Patrol.DetectionRange,
		LastSeenTarget = nil,
		LastSeenTime = 0,
		PursuitStartTime = 0,
		RoadblockId = nil,
		SpikeStripId = nil,
		HeliId = nil,
		CreatedAt = os.time(),
	}

	policeUnits[unitId] = unit

	-- Set up physics for vehicle units
	if unitType ~= "Helicopter" then
		PoliceAI.SetupVehiclePhysics(unit.Model)
		unit.Model.Parent = Workspace.Live
	end

	return unit
end

function PoliceAI.SetupVehiclePhysics(model: Model)
	local chassis = model.PrimaryPart
	if not chassis then return end

	chassis.CollisionGroup = "Vehicles"
	PhysicsService:CollisionGroupSetCollidable("Vehicles", "Players", false)

	-- Physical properties
	local physProps = PhysicalProperties.new(2.0, 0.8, 0.1, 100, 1)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CustomPhysicalProperties = PhysicalProperties.new(2.0, 0.8, 0.1, 100, 1)
		end
	end

	-- Network ownership (server-authoritative for AI)
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part:SetNetworkOwner(nil)
		end
	end
end

-- ============================================
-- PATROL SPAWNING
-- ============================================

local function GetDistrictHeat(districtId: string): number
	return HeatServer.GetDistrictHeat(districtId)
end

function PoliceAI.SpawnPatrols()
	for _, districtId in ipairs(Constants.DistrictOrder) do
		local heat = HeatServer.GetDistrictHeat(districtId)
		local patrolCount = math.floor(Constants.Police.Patrol.VehicleCount * (1 + heat * 0.5))

		-- Count existing patrols in district
		local currentCount = 0
		for _, unit in pairs(policeUnits) do
			if unit.Type == "Patrol" and unit.District == districtId then
				count = count + 1
			end
		end

		-- Spawn needed patrols
		while count < patrolCount do
			local unit = CreatePoliceUnit("Patrol", districtId)
			unit.State = "Patrolling"
			unit.CurrentWaypoint = math.random(1, #(patrolRoutes[unit.District] or {1}))
		end
	end
end

-- ============================================
-- PATROL AI
-- ============================================

local function PatrolUpdate(unit: any, dt: number)
	local waypoints = patrolRoutes[unit.District]
	if not waypoints or #waypoints == 0 then return end

	local model = unit.Model
	if not model or not model.PrimaryPart then return end

	local currentWp = unit.Waypoints[unit.CurrentWaypoint]
	if not currentWp then
		unit.CurrentWaypoint = 1
		return
	end

	local chassis = unit.Model.PrimaryPart
	if not chassis then return end

	-- Move to waypoint
	local targetPos = unit.Waypoints[unit.CurrentWaypoint]
	local direction = (currentWp - model.PrimaryPart.Position).Unit
	local distance = (currentWp - model.PrimaryPart.Position).Magnitude

	-- Check if reached waypoint
	if distance < 10 then
		unit.CurrentWaypoint = unit.CurrentWaypoint + 1
		if unit.CurrentWaypoint > #patrolRoutes[unit.District] then
			unit.CurrentWaypoint = 1
		end
		return
	end

	-- Steer towards waypoint
	local chassis = unit.Model.PrimaryPart
	local targetDirection = (currentWp - model.PrimaryPart.Position).Unit
	local forward = model.PrimaryPart.CFrame.LookVector

	-- Simple steering
	local angle = math.atan2(direction.X, direction.Z) - math.atan2(forward.X, forward.Z)
	local steerAmount = math.clamp(angle * 5, -1, 1)

	-- Apply movement
	local speed = 30 -- Patrol speed
	local force = -unit.Model.PrimaryPart.CFrame.LookVector * 50000
	unit.Model.PrimaryPart:ApplyImpulse(Vector3.new(0, 0, -1) * 50000)

	-- Steering torque
	local steerTorque = angle * 50000
	unit.Model.PrimaryPart:ApplyAngularImpulse(Vector3.new(0, angle * 50000, 0))

	-- Scan for suspicious activity
	ScanForSuspects(unit)
end

-- ============================================
- DETECTION SYSTEM
-- ============================================

function ScanForSuspects(unit: any)
	local model = unit.Model
	if not model or not model.PrimaryPart then return end

	local searchRadius = Constants.Police.Patrol.DetectionRange * (1 + unit.HeatLevel * 0.5)
	local position = unit.Model.PrimaryPart.Position

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if not character or not character.PrimaryPart then continue end

		-- Check if player is in vehicle
		local isInVehicle = false
		local vehicleEntry = nil
		for _, vehEntry in pairs(_G.spawnedVehicles or {}) do
			if vehEntry.OwnerId == player.UserId then
				isInVehicle = true
				break
			end
		end

		if not isInVehicle then continue end -- Only care about vehicles

		-- Check heat level
		local heat = HeatServer.GetHeat(player.UserId)
		if heat == 0 then continue end -- Ignore zero heat

		-- Distance check
		local vehicleEntry = _G.spawnedVehicles[player.UserId]
		if not vehicleEntry or not vehicleEntry.Model or not vehicleEntry.Model.PrimaryPart then continue end

		local distance = (vehicleEntry.Model.PrimaryPart.Position - unit.Model.PrimaryPart.Position).Magnitude
		if distance > unit.DetectionRange then continue end

		-- Line of sight check (raycast)
		local origin = unit.Model.PrimaryPart.Position + Vector3.new(0, 3, 0)
		local direction = (vehicleEntry.Model.PrimaryPart.Position - unit.Model.PrimaryPart.Position).Unit
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = { unit.Model }
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude

		local raycast = workspace:Raycast(unit.Model.PrimaryPart.Position, direction * 100, RaycastParams.new())
		if raycast and raycast.Instance then
			-- Check if hit the target vehicle
			local hitModel = raycast.Instance:FindFirstAncestorOfClass("Model")
			if hitModel and hitModel.Name:match("Vehicle_") then
				-- Detected!
				OnSuspectDetected(unit, player.UserId, vehicleEntry.Model.PrimaryPart.Position)
			end
		end
	end
end

function OnSuspectDetected(unit: any, targetUserId: number, targetPosition: Vector3)
	unit.LastSeenTarget = targetPosition
	unit.LastSeenTime = os.time()

	-- If patrol, initiate pursuit
	if unit.State == "Patrolling" then
		InitiatePursuit(unit.Id, targetUserId, targetPosition)
	end
end

-- ============================================
- PURSUIT SYSTEM
-- ============================================

function InitiatePursuit(unitId: number, targetUserId: number, targetPosition: Vector3)
	local unit = policeUnits[unitId]
	if not unit then return end

	unit.State = "Pursuing"
	unit.Target = targetUserId
	unit.PursuitStartTime = os.time()

	-- Register pursuit
	activePursuits[targetUserId] = activePursuits[targetUserId] or { pursuers = {}, startTime = os.time() }
	table.insert(activePursuits[targetUserId].pursuers, unit.Id)

	-- Notify heat server
	HeatServer.AddHeat(targetUserId, 2, "PolicePursuit")

	-- Notify client
	local player = Players:GetPlayerByUserId(targetUserId)
	if player then
		local remote = ReplicatedStorage:FindFirstChild("Remotes", true)
		if remote then
			local pursuitStart = remote:FindFirstChild("PursuitStarted")
			if pursuitStart then
				pursuitStart:FireClient(player, {
					PursuerCount = 1,
					PursuerTypes = { "Patrol" },
					Intensity = 1,
				})
			end
		end
	end

	Signals.GameSignals.PursuitStarted:Fire(targetUserId, unit.Id)
end

local function PursuitUpdate(unit: any, dt: number)
	local targetUserId = unit.Target
	if not targetUserId then
		unit.State = "Returning"
		return
	end

	-- Get target vehicle
	local vehicleEntry = _G.spawnedVehicles[unit.Target]
	if not vehicleEntry or not vehicleEntry.Model or not vehicleEntry.Model.PrimaryPart then
		unit.State = "Returning"
		return
	end

	local targetPos = vehicleEntry.Model.PrimaryPart.Position
	local model = unit.Model
	if not model or not model.PrimaryPart then return end

	-- Check pursuit timeout
	if os.time() - unit.PursuitStartTime > Constants.Police.Pursuit.GiveUpTime then
		unit.State = "Returning"
		return
	end

	-- Check distance
	local distance = (unit.Model.PrimaryPart.Position - vehicleEntry.Model.PrimaryPart.Position).Magnitude
	if distance > Constants.Police.Pursuit.GiveUpDistance then
		unit.State = "Returning"
		return
	end

	-- Pursuit logic
	local model = unit.Model
	local targetVehicle = _G.spawnedVehicles[unit.Target].Model
	if not targetVehicle or not targetVehicle.PrimaryPart then return end

	local targetPos = targetVehicle.PrimaryPart.Position
	local unitPos = unit.Model.PrimaryPart.Position
	local direction = (targetVehicle.PrimaryPart.Position - unit.Model.PrimaryPart.Position).Unit

	-- Predictive targeting (lead the target)
	local targetVelocity = _G.spawnedVehicles[unit.Target].Model.PrimaryPart.AssemblyLinearVelocity
	local predictedPos = targetVehicle.PrimaryPart.Position + targetVelocity * 1.5

	-- Pathfind to predicted position
	local path = PathfindingService:CreatePath({
		AgentRadius = 3,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 10,
	})

	pcall(function()
		path:ComputeAsync(unit.Model.PrimaryPart.Position, predictedPos)
	end)

	if path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		if #waypoints > 1 then
			local nextWp = waypoints[2].Position
			local direction = (nextWp - unit.Model.PrimaryPart.Position).Unit
			local angle = math.atan2(direction.X, direction.Z) - math.atan2(unit.Model.PrimaryPart.CFrame.LookVector.X, unit.Model.PrimaryPart.CFrame.LookVector.Z)
			local steerAmount = math.clamp(angle * 8, -1, 1)

			-- Apply movement
			local chassis = unit.Model.PrimaryPart
			local speed = Constants.Police.Pursuit.PursuitSpeed
			unit.Model.PrimaryPart:ApplyImpulse(-unit.Model.PrimaryPart.CFrame.LookVector * 80000)

			-- Steering
			local steerTorque = angle * 100000
			unit.Model.PrimaryPart:ApplyAngularImpulse(Vector3.new(0, angle * 100000, 0))

			-- Ram attempt
			local distance = (unit.Model.PrimaryPart.Position - targetVehicle.PrimaryPart.Position).Magnitude
			if distance < 15 and math.random() < Constants.Police.Pursuit.RamThreshold then
				-- Ram attempt
				local ramForce = (targetVehicle.PrimaryPart.Position - unit.Model.PrimaryPart.Position).Unit * 100000
				targetVehicle.PrimaryPart:ApplyImpulse(ramForce)
			end

			-- Box-in maneuver
			if #_G.policeUnits > 1 and math.random() < 0.1 then
				AttemptBoxIn(unit)
			end
		end
	end
end

function AttemptBoxIn(unit: any)
	-- Find other pursuing units
	local pursuers = {}
	for _, otherUnit in pairs(policeUnits) do
		if otherUnit.Id ~= unit.Id and otherUnit.State == "Pursuing" and otherUnit.Target == unit.Target then
			table.insert(pursuers, otherUnit)
		end
	end

	if #pursuers >= 1 then
		-- Coordinate box-in
		-- This would position units around the target
	end
end

-- ============================================
- ROADBLOCKS & SPIKE STRIPS
-- ============================================

function PoliceAI.DeployRoadblock(position: Vector3, direction: Vector3, heatLevel: number): string?
	if heatLevel < Constants.Police.Roadblock.SpawnHeat then return nil end

	local roadblockId = "RB_" .. nextRoadblockId
	nextRoadblockId += 1

	-- Create roadblock model
	local model = Instance.new("Model")
	model.Name = "Roadblock_" .. nextRoadblockId
	model.Parent = Workspace.Live

	-- Create barriers
	for i = 1, Constants.Police.Roadblock.LaneCount do
		local barrier = Instance.new("Part")
		barrier.Name = "Barrier_" .. i
		barrier.Size = Vector3.new(6, 3, 2)
		barrier.BrickColor = BrickColor.new("Really black")
		barrier.Material = Enum.Material.Concrete
		barrier.Anchored = true
		barrier.Parent = model

		-- Position across road
		local perp = Vector3.new(-direction.Z, 0, direction.X)
		barrier.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0) + (i - 1.5) * perp * 3, position + direction * 10)

		-- Warning lights
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 100, 0)
		light.Range = 20
		light.Brightness = 3
		light.Parent = barrier
	end

	-- Warning signs
	for _, offset in ipairs({ -50, -100, -200 }) do
		local sign = Instance.new("Part")
		sign.Size = Vector3.new(4, 3, 0.5)
		sign.Anchored = true
		sign.Parent = model
		sign.CFrame = CFrame.new(position - direction * math.abs(offset), position + direction * 10)
	end

	local roadblock = {
		Id = "RB_" .. nextRoadblockId,
		Model = model,
		Position = position,
		Direction = direction,
		SpawnTime = os.time(),
		Duration = Constants.Police.Roadblock.Duration,
		LaneCount = Constants.Police.Roadblock.LaneCount,
	}

	roadblocks[roadblock.Id] = roadblock

	-- Auto-remove after duration
	task.delay(Constants.Police.Roadblock.Duration, function()
		roadblocks[roadblock.Id] = nil
		if roadblock.Model then roadblock.Model:Destroy() end
	end)

	return roadblock.Id
end

function PoliceAI.DeploySpikeStrip(position: Vector3, direction: Vector3, heatLevel: number): string?
	if heatLevel < Constants.Police.SpikeStrip.SpawnHeat then return nil end

	local stripId = "SS_" .. nextSpikeStripId
	nextSpikeStripId += 1

	local model = Instance.new("Model")
	model.Name = "SpikeStrip_" .. nextSpikeStripId
	model.Parent = Workspace.Live

	-- Create spike strip
	local strip = Instance.new("Part")
	strip.Name = "Strip"
	strip.Size = Vector3.new(6, 0.2, 2)
	strip.Anchored = true
	strip.CFrame = CFrame.new(position, position + direction * 10)
	strip.Transparency = 0.8
	strip.BrickColor = BrickColor.new("Dark stone grey")
	strip.Material = Enum.Material.Metal
	strip.Parent = model

	-- Visual indicators
	for i = 1, 12 do
		local spike = Instance.new("Part")
		spike.Size = Vector3.new(0.2, 0.5, 0.2)
		spike.Shape = Enum.PartType.Wedge
		spike.CFrame = model.PrimaryPart.CFrame * CFrame.new((i - 6.5) * 0.5, 0, 0)
		spike.Anchored = true
		spike.BrickColor = BrickColor.new("Dark stone grey")
		spike.Parent = model
	end

	local stripObj = {
		Id = "SS_" .. nextSpikeStripId,
		Model = model,
		Position = position,
		Direction = direction,
		DeployTime = os.time(),
	}

	spikeStrips[stripObj.Id] = stripObj

	-- Check for vehicles hitting spikes
	task.spawn(function()
		while spikeStrips[stripObj.Id] do
			task.wait(0.1)
			for _, vehEntry in pairs(_G.spawnedVehicles or {}) do
				if vehEntry.Model and vehEntry.Model.PrimaryPart then
					local dist = (vehEntry.Model.PrimaryPart.Position - position).Magnitude
					if dist < 5 then
						-- Check if crossing the strip
						local vehPos = vehEntry.Model.PrimaryPart.Position
						local toVeh = (vehEntry.Model.PrimaryPart.Position - position).Unit
						local dot = toVeh:Dot(direction)
						if dot > 0.5 then -- Moving across strip
							-- Pop tires!
							PopVehicleTires(vehEntry.Model)
						end
					end
				end
			end
		end
	end)

	return stripId
end

function PopVehicleTires(vehicleModel: Model)
	-- Find wheel parts and flatten them
	for _, part in ipairs(vehicleModel:GetDescendants()) do
		if part.Name:match("Wheel") and part:IsA("BasePart") then
			-- Flatten tire
			part.Size = Vector3.new(part.Size.X, 0.1, part.Size.Z)
			part.Material = Enum.Material.Metal
			part.Color = Color3.fromRGB(50, 50, 50)

			-- Add spark effects
			local spark = Instance.new("ParticleEmitter")
			spark.Texture = "rbxassetid://241625913"
			spark.Color = ColorSequence.new(Color3.fromRGB(255, 150, 0))
			spark.Size = NumberSequence.new(0.5)
			spark.Lifetime = NumberRange.new(0.5, 1)
			spark.Speed = NumberRange.new(5, 10)
			spark.SpreadAngle = Vector2.new(45, 45)
			spark.Parent = part
			spark:Emit(20)

			-- Vehicle handling debuff
			-- This would be handled by the vehicle physics system
		end
	end
end

-- ============================================
- HELICOPTER AI
-- ============================================

function PoliceAI.DeployHelicopter(targetUserId: number, position: Vector3): string?
	local heliId = "HELI_" .. nextHeliId
	nextHeliId += 1

	local model = Instance.new("Model")
	model.Name = "Helicopter_" .. nextHeliId
	model.Parent = Workspace.Live

	-- Helicopter body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(6, 2, 10)
	body.Anchored = true
	body.CanCollide = false
	body.BrickColor = BrickColor.new("Really black")
	body.Parent = model

	-- Rotors
	local mainRotor = Instance.new("Part")
	mainRotor.Name = "MainRotor"
	mainRotor.Size = Vector3.new(12, 0.2, 0.5)
	mainRotor.Anchored = false
	mainRotor.CanCollide = false
	mainRotor.Massless = true
	mainRotor.Parent = model

	local tailRotor = Instance.new("Part")
	tailRotor.Name = "TailRotor"
	tailRotor.Size = Vector3.new(2, 0.1, 0.5)
	tailRotor.Anchored = false
	tailRotor.CanCollide = false
	tailRotor.Massless = true
	tailRotor.Parent = model

	-- Searchlight
	local spotlight = Instance.new("SpotLight")
	spotlight.Color = Color3.fromRGB(255, 255, 255)
	spotlight.Range = 100
	spotlight.Brightness = 5
	spotlight.Angle = 30
	spotlight.Face = Enum.NormalId.Bottom
	spotlight.Parent = model

	-- Searchlight attachment
	local lightAttach = Instance.new("Attachment")
	lightAttach.Name = "SearchlightAttach"
	lightAttach.Position = Vector3.new(0, -5, 0)
	lightAttach.Parent = model

	-- Setup
	model.PrimaryPart = model:FindFirstChild("Body") or Instance.new("Part")
	model:SetPrimaryPartCFrame(CFrame.new(position + Vector3.new(0, 100, 0)))

	local heli = {
		Id = "HELI_" .. nextHeliId,
		Model = model,
		Target = targetUserId,
		Position = position + Vector3.new(0, 100, 0),
		State = "Tracking",
		Altitude = 100,
		Speed = 50,
		SpotlightTarget = nil,
	}

	helicopters[heli.Id] = heli
	nextHeliId += 1

	-- Track target
	task.spawn(function()
		while helicopters[heli.Id] do
			task.wait(0.1)
			local targetEntry = _G.spawnedVehicles[targetUserId]
			if targetEntry and targetEntry.Model and targetEntry.Model.PrimaryPart then
				local targetPos = targetEntry.Model.PrimaryPart.Position
				heli.Position = Vector3.new(targetPos.X, 100, targetPos.Z)
				heli.Model:SetPrimaryPartCFrame(CFrame.new(heli.Position, targetEntry.Model.PrimaryPart.Position))
			else
				break -- Target lost
			end
		end
		helicopters[heli.Id] = nil
		if heli.Model then heli.Model:Destroy() end
	end)

	return heli.Id
end

-- ============================================
- SWAT DEPLOYMENT
-- ============================================

function PoliceAI.DeploySWAT(targetUserId: number, position: Vector3)
	-- Spawn SWAT vehicle
	local model = Instance.new("Model")
	model.Name = "SWAT_Vehicle"
	model.Parent = Workspace.Live

	-- Heavy armored vehicle
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(5, 2.5, 10)
	chassis.BrickColor = BrickColor.new("Really black")
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.Anchored = false
	chassis.Massless = false
	chassis.Parent = model

	-- Turret
	local turret = Instance.new("Part")
	turret.Name = "Turret"
	turret.Size = Vector3.new(2, 2, 2)
	turret.Shape = Enum.PartType.Ball
	turret.Position = Vector3.new(0, 3, 0)
	turret.Anchored = false
	turret.CanCollide = false
	turret.Massless = true
	turret.Parent = model

	-- Officers (visual only)
	for i = 1, Constants.Police.SWAT.OfficerCount do
		local officer = Instance.new("Part")
		officer.Size = Vector3.new(1, 2, 1)
		officer.BrickColor = BrickColor.new("Dark stone grey")
		officer.Position = Vector3.new(math.random(-2, 2), 3, math.random(-3, 3))
		officer.Anchored = false
		officer.CanCollide = false
		officer.Massless = true
		officer.Parent = model
	end

	model.PrimaryPart = model:FindFirstChild("Chassis") or Instance.new("Part")
	model:SetPrimaryPartCFrame(CFrame.new(position))
	model.Parent = Workspace.Live

	-- SWAT AI would go here - aggressive pursuit, breaching, etc.
end

-- ============================================
- MAIN UPDATE LOOP
-- ============================================

local function UpdatePolice(dt: number)
	-- Update patrol units
	for _, unit in pairs(policeUnits) do
		if unit.State == "Patrolling" then
			PatrolUpdate(unit, dt)
		elseif unit.State == "Pursuing" then
			PursuitUpdate(unit, dt)
		elseif unit.State == "Returning" then
			ReturnToStationUpdate(unit, dt)
		end
	end

	-- Update roadblocks
	for id, rb in pairs(roadblocks) do
		if os.time() - rb.SpawnTime > rb.Duration then
			if rb.Model then rb.Model:Destroy() end
			roadblocks[id] = nil
		end
	end

	-- Update spike strips
	for id, strip in pairs(spikeStrips) do
		if os.time() - strip.DeployTime > 300 then -- 5 min max
			if strip.Model then strip.Model:Destroy() end
			spikeStrips[id] = nil
		end
	end

	-- Update helicopters
	for id, heli in pairs(helicopters) do
		-- Handled in spawn coroutine
	end
end

function ReturnToStationUpdate(unit: any, dt: number)
	-- Return to police station
	local stationPos = GetPoliceStation(unit.District)
	if not stationPos then
		unit.State = "Idle"
		return
	end

	local model = unit.Model
	if not model or not model.PrimaryPart then return end

	local direction = (stationPos - model.PrimaryPart.Position).Unit
	local distance = (stationPos - model.PrimaryPart.Position).Magnitude

	if distance < 20 then
		unit.State = "Idle"
		unit.CurrentWaypoint = 1
		return
	end

	-- Move to station
	local model = unit.Model
	local chassis = model.PrimaryPart
	if not chassis then return end

	local direction = (stationPos - model.PrimaryPart.Position).Unit
	local angle = math.atan2(direction.X, direction.Z) - math.atan2(chassis.CFrame.LookVector.X, chassis.CFrame.LookVector.Z)
	local steerAmount = math.clamp(angle * 5, -1, 1)

	chassis:ApplyImpulse(-chassis.CFrame.LookVector * 50000)
	chassis:ApplyAngularImpulse(Vector3.new(0, angle * 50000, 0))
end

function GetPoliceStation(districtId: string): Vector3?
	local stations = {
		Downtown = Vector3.new(100, 10, 100),
		Industrial = Vector3.new(600, 10, 600),
		Residential = Vector3.new(-400, 10, -400),
		Commercial = Vector3.new(100, 10, 600),
		Warehouse = Vector3.new(-400, 10, 600),
		UndergroundParking = Vector3.new(0, -30, 0),
		RestrictedZone = Vector3.new(1100, 10, 1100),
	}
	return stations[districtId]
end

-- ============================================
- MAIN UPDATE LOOP
-- ============================================

task.spawn(function()
	while true do
		local dt = task.wait(1/30) -- 30 Hz for AI

		-- Update all police units
		for _, unit in pairs(policeUnits) do
			if unit.State == "Patrolling" then
				PatrolUpdate(unit, dt)
			elseif unit.State == "Pursuing" then
				PursuitUpdate(unit, dt)
			elseif unit.State == "Returning" then
				ReturnToStationUpdate(unit, dt)
			end
		end

		-- Maintain patrol counts
		PoliceAI.SpawnPatrols()

		-- Clean up destroyed units
		for id, unit in pairs(policeUnits) do
			if not unit.Model or not unit.Model.Parent then
				policeUnits[id] = nil
			end
		end
	end
end)

-- ============================================
- PUBLIC API
-- ============================================

function PoliceAI.GetUnitsInDistrict(districtId: string): { any }
	local result = {}
	for _, unit in pairs(policeUnits) do
		if unit.District == districtId then
			table.insert(result, unit)
		end
	end
	return result
end

function PoliceAI.GetActivePursuits(): { [number]: any }
	return activePursuits
end

function PoliceAI.GetPursuersForTarget(targetUserId: number): { any }
	local pursuit = activePursuits[targetUserId]
	if not pursuit then return {} end

	local pursuers = {}
	for _, unitId in ipairs(pursuit.pursuers) do
		local unit = policeUnits[unitId]
		if unit then table.insert(pursuers, unit) end
	end
	return pursuers
end

function PoliceAI.RequestRoadblock(position: Vector3, direction: Vector3): string?
	local heat = HeatServer.GetGlobalHeat()
	return PoliceAI.DeployRoadblock(position, direction, heat)
end

function PoliceAI.RequestSpikeStrip(position: Vector3, direction: Vector3): string?
	local heat = HeatServer.GetGlobalHeat()
	return PoliceAI.DeploySpikeStrip(position, direction, heat)
end

function PoliceAI.RequestHelicopter(targetUserId: number): string?
	local heat = HeatServer.GetHeat(targetUserId)
	if heat >= Constants.Police.Helicopter.SpawnHeat then
		local vehicleEntry = _G.spawnedVehicles[targetUserId]
		if vehicleEntry and vehicleEntry.Model and vehicleEntry.Model.PrimaryPart then
			return PoliceAI.DeployHelicopter(targetUserId, vehicleEntry.Model.PrimaryPart.Position)
		end
	end
	return nil
end

function PoliceAI.RequestSWAT(targetUserId: number): boolean
	local heat = HeatServer.GetHeat(targetUserId)
	if heat >= Constants.Police.SWAT.SpawnHeat then
		local vehicleEntry = _G.spawnedVehicles[targetUserId]
		if vehicleEntry and vehicleEntry.Model and vehicleEntry.Model.PrimaryPart then
			PoliceAI.DeploySWAT(targetUserId, vehicleEntry.Model.PrimaryPart.Position)
			return true
		end
	end
	return false
end

function PoliceAI.GetUnitsInDistrict(districtId: string): { any }
	local result = {}
	for _, unit in pairs(policeUnits) do
		if unit.District == districtId then
			table.insert(result, unit)
		end
	end
	return result
end

function PoliceAI.GetActivePursuits(): { [number]: any }
	return activePursuits
end

-- ============================================
- INITIALIZATION
-- ============================================

-- Initial patrol spawn
task.spawn(function()
	task.wait(10)
	PoliceAI.SpawnPatrols()
end)

Utils.DebugLog("PoliceAI initialized")

return PoliceAI