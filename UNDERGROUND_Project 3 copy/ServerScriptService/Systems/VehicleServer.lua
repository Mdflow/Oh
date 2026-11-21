--[[
	UNDERGROUND — Vehicle Server
	Server-authoritative vehicle spawning, physics, ownership, and replication.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)
local PlayerDataServer = require(script.Parent.PlayerDataServer)
local InventoryServer = require(script.Parent.InventoryServer)

local VehicleServer = {}

-- ============================================
-- VEHICLE PHYSICS CONSTANTS
-- ============================================

local VEHICLE_PHYSICS = {
	-- Base physics properties
	Density = 2.0,
	Friction = 0.8,
	Elasticity = 0.1,
	FrictionWeight = 100,

	-- Engine
	MaxRPM = 8000,
	IdleRPM = 800,
	RedlineRPM = 7500,

	-- Transmission
	GearRatios = { 3.5, 2.2, 1.5, 1.1, 0.8 }, -- 5-speed
	FinalDrive = 3.5,
	ShiftUpRPM = 6500,
	ShiftDownRPM = 3000,

	-- Wheels
	WheelRadius = 0.35,
	WheelWidth = 0.25,
	SuspensionStiffness = 50000,
	SuspensionDamping = 5000,
	SuspensionTravel = 0.3,

	-- Aero
	DragCoefficient = 0.32,
	LiftCoefficient = 0.1,
	Downforce = 0,

	-- Braking
	BrakeForce = 50000,
	HandbrakeForce = 30000,
	BrakeBalance = 0.6, -- Front bias
}

-- Vehicle class mapping
local VehicleModels = {
	Starter = {
		Civic = { ModelName = "Starter_Civic", Stats = { Speed = 55, Acceleration = 50, Handling = 65, Durability = 60, Storage = 2, Fuel = 100 } },
		Hatchback = { ModelName = "Starter_Hatchback", Stats = { Speed = 50, Acceleration = 55, Handling = 70, Durability = 55, Storage = 3, Fuel = 100 } },
	},
	Sedan = {
		Sentinel = { ModelName = "Sedan_Sentinel", Stats = { Speed = 65, Acceleration = 60, Handling = 75, Durability = 60, Storage = 3, Fuel = 100 } },
		Premier = { ModelName = "Sedan_Premier", Stats = { Speed = 70, Acceleration = 65, Handling = 70, Durability = 65, Storage = 2, Fuel = 110 } },
	},
	Sports = {
		Viper = { ModelName = "Sports_Viper", Stats = { Speed = 95, Acceleration = 90, Handling = 85, Durability = 45, Storage = 1, Fuel = 80 } },
		GT = { ModelName = "Sports_GT", Stats = { Speed = 90, Acceleration = 85, Handling = 88, Durability = 50, Storage = 1, Fuel = 85 } },
	},
	SUV = {
		Patriot = { ModelName = "SUV_Patriot", Stats = { Speed = 55, Acceleration = 50, Handling = 55, Durability = 85, Storage = 5, Fuel = 120 } },
		Ranger = { ModelName = "SUV_Ranger", Stats = { Speed = 60, Acceleration = 55, Handling = 60, Durability = 80, Storage = 6, Fuel = 115 } },
	},
	Van = {
		Boxer = { ModelName = "Van_Boxer", Stats = { Speed = 50, Acceleration = 40, Handling = 45, Durability = 80, Storage = 8, Fuel = 110 } },
		Transit = { ModelName = "Van_Transit", Stats = { Speed = 45, Acceleration = 35, Handling = 40, Durability = 85, Storage = 10, Fuel = 120 } },
	},
	Truck = {
		Hauler = { ModelName = "Truck_Hauler", Stats = { Speed = 40, Acceleration = 30, Handling = 35, Durability = 95, Storage = 15, Fuel = 150 } },
		Tanker = { ModelName = "Truck_Tanker", Stats = { Speed = 35, Acceleration = 25, Handling = 30, Durability = 98, Storage = 12, Fuel = 180 } },
	},
	Premium = {
		Phantom = { ModelName = "Premium_Phantom", Stats = { Speed = 100, Acceleration = 95, Handling = 90, Durability = 70, Storage = 4, Fuel = 90 } },
		Specter = { ModelName = "Premium_Specter", Stats = { Speed = 98, Acceleration = 92, Handling = 92, Durability = 75, Storage = 3, Fuel = 95 } },
	},
}

-- ============================================
-- VEHICLE SPAWNING
-- ============================================

local spawnedVehicles = {} -- [vehicleId] = { model, owner, data }
local vehiclePhysicsConnections = {}

function VehicleServer.SpawnVehicle(userId: number, vehicleData: any, spawnCFrame: CFrame): (boolean, Model?, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, nil, "Player not found" end

	-- Validate ownership
	local ownedVehicle = Utils.Find(profile.VehicleGarage, function(v) return v.Id == vehicleData.Id end)
	if not ownedVehicle then
		return false, nil, "Vehicle not owned"
	end

	-- Check if already spawned
	if spawnedVehicles[vehicleData.Id] then
		return false, nil, "Vehicle already spawned"
	end

	-- Get model from ReplicatedStorage
	local modelName = ownedVehicle.ModelName or vehicleData.ModelName
	local sourceModel = ReplicatedStorage.Assets.Vehicles:FindFirstChild(modelName)
	if not sourceModel then
		-- Create procedural vehicle if model doesn't exist
		sourceModel = VehicleServer.CreateProceduralVehicle(vehicleData)
	end

	local vehicleModel = sourceModel:Clone()
	vehicleModel.Name = "Vehicle_" .. vehicleData.Id
	vehicleModel.PrimaryPart = vehicleModel:FindFirstChild("Chassis") or vehicleModel:FindFirstChild("Body")

	if not vehicleModel.PrimaryPart then
		return false, nil, "Invalid vehicle model - no PrimaryPart"
	end

	-- Set up physics
	VehicleServer.SetupVehiclePhysics(vehicleModel, vehicleData)

	-- Position
	vehicleModel:SetPrimaryPartCFrame(spawnCFrame)
	vehicleModel.Parent = Workspace.Live

	-- Set ownership
	vehicleModel:SetAttribute("OwnerId", userId)
	vehicleModel:SetAttribute("VehicleId", vehicleData.Id)
	vehicleModel:SetAttribute("Category", ownedVehicle.Category)

	-- Apply customizations
	VehicleServer.ApplyCustomizations(vehicleModel, vehicleData)

	-- Register
	spawnedVehicles[vehicleData.Id] = {
		Model = vehicleModel,
		OwnerId = userId,
		Data = vehicleData,
		LastPosition = spawnCFrame.Position,
		LastUpdate = os.time(),
	}

	-- Set up network ownership
	vehicleModel.PrimaryPart:SetNetworkOwner(Players:GetPlayerByUserId(userId))

	Signals.GameSignals.VehicleSpawned:Fire(userId, vehicleData, vehicleModel)

	return true, vehicleModel, nil
end

function VehicleServer.DespawnVehicle(userId: number, vehicleId: string): boolean
	local vehicleEntry = spawnedVehicles[vehicleId]
	if not vehicleEntry or vehicleEntry.OwnerId ~= userId then
		return false
	end

	-- Clean up physics connections
	if vehiclePhysicsConnections[vehicleId] then
		for _, conn in ipairs(vehiclePhysicsConnections[vehicleId]) do
			conn:Disconnect()
		end
		vehiclePhysicsConnections[vehicleId] = nil
	end

	-- Destroy model
	if vehicleEntry.Model then
		vehicleEntry.Model:Destroy()
	end

	spawnedVehicles[vehicleId] = nil

	Signals.GameSignals.VehicleDespawned:Fire(userId, vehicleId)
	return true
end

-- ============================================
- PHYSICS SETUP
-- ============================================

function VehicleServer.SetupVehiclePhysics(vehicleModel: Model, vehicleData: any)
	local chassis = vehicleModel.PrimaryPart
	if not chassis then return end

	-- Configure collision groups
	PhysicsService:RegisterCollisionGroup("Vehicles")
	PhysicsService:RegisterCollisionGroup("Players")
	PhysicsService:CollisionGroupSetCollidable("Vehicles", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Vehicles", "Vehicles", true)

	chassis.CollisionGroup = "Vehicles"

	-- Set physical properties
	local physProps = PhysicalProperties.new(
		VEHICLE_PHYSICS.Density,
		VEHICLE_PHYSICS.Friction,
		VEHICLE_PHYSICS.Elasticity,
		VEHICLE_PHYSICS.FrictionWeight,
		1 -- ElasticityWeight
	)

	for _, part in ipairs(vehicleModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CustomPhysicalProperties = physProps
			part.Massless = false
		end
	end

	-- Configure wheels
	for _, wheel in ipairs(vehicleModel:GetDescendants()) do
		if wheel.Name:match("Wheel") and wheel:IsA("BasePart") then
			wheel.CustomPhysicalProperties = PhysicalProperties.new(
				1.5, -- Slightly lighter
				0.9, -- High friction
				0.05,
				100,
				0.5
			)
		end
	end

	-- Create constraints for suspension
	VehicleServer.CreateSuspensionConstraints(vehicleModel, vehicleData)

	-- Set up engine sound
	VehicleServer.SetupEngineSound(vehicleModel, vehicleData)
end

function VehicleServer.CreateSuspensionConstraints(vehicleModel: Model, vehicleData: any)
	-- This would create SpringConstraints for each wheel
	-- Simplified implementation
	local chassis = vehicleModel.PrimaryPart
	if not chassis then return end

	for _, wheel in ipairs(vehicleModel:GetDescendants()) do
		if wheel.Name:match("Wheel") and wheel:IsA("BasePart") then
			-- Find attachment points
			local wheelAttachment = wheel:FindFirstChild("WheelAttachment")
			local chassisAttachment = chassis:FindFirstChild(wheel.Name .. "Attachment")

			if not wheelAttachment then
				wheelAttachment = Instance.new("Attachment")
				wheelAttachment.Name = "WheelAttachment"
				wheelAttachment.Position = Vector3.new(0, -wheel.Size.Y/2, 0)
				wheelAttachment.Parent = wheel
			end

			if not chassisAttachment then
				chassisAttachment = Instance.new("Attachment")
				chassisAttachment.Name = wheel.Name .. "Attachment"
				chassisAttachment.Parent = chassis
			end

			-- Spring constraint
			local spring = Instance.new("SpringConstraint")
			spring.Name = "Suspension_" .. wheel.Name
			spring.Attachment0 = chassisAttachment
			spring.Attachment1 = wheelAttachment
			spring.Stiffness = VEHICLE_PHYSICS.SuspensionStiffness
			spring.Damping = VEHICLE_PHYSICS.SuspensionDamping
			spring.FreeLength = VEHICLE_PHYSICS.SuspensionTravel
			spring.LimitsEnabled = true
			spring.MaxLength = VEHICLE_PHYSICS.SuspensionTravel
			spring.MinLength = 0
			spring.Parent = chassis
		end
	end
end

function VehicleServer.SetupEngineSound(vehicleModel: Model, vehicleData: any)
	local chassis = vehicleModel.PrimaryPart
	if not chassis then return end

	local sound = Instance.new("Sound")
	sound.Name = "EngineSound"
	sound.SoundId = "rbxassetid://" .. VehicleServer.GetEngineSoundId(vehicleData.Category)
	sound.Volume = 0.5
	sound.Pitch = 1
	sound.Looped = true
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 200
	sound.Parent = chassis
	sound:Play()

	-- Store for pitch control
	vehicleModel:SetAttribute("EngineSoundId", sound.SoundId)
end

function VehicleServer.GetEngineSoundId(category: string): number
	-- Return appropriate sound IDs for each category
	local sounds = {
		Starter = 1841638860,
		Sedan = 1841638860,
		Sports = 1841638861,
		SUV = 1841638862,
		Van = 1841638862,
		Truck = 1841638863,
		Premium = 1841638861,
	}
	return sounds[category] or sounds.Starter
end

-- ============================================
- VEHICLE CONTROL (Server-side validation)
-- ============================================

local vehicleInputs = {} -- [vehicleId] = { throttle, brake, steer, handbrake, gear }

function VehicleServer.ProcessVehicleInput(userId: number, vehicleId: string, inputData: any)
	local vehicleEntry = spawnedVehicles[vehicleId]
	if not vehicleEntry or vehicleEntry.OwnerId ~= userId then
		return
	end

	-- Validate and clamp inputs
	local throttle = Utils.Clamp(inputData.Throttle or 0, -1, 1)
	local brake = Utils.Clamp(inputData.Brake or 0, 0, 1)
	local steer = Utils.Clamp(inputData.Steer or 0, -1, 1)
	local handbrake = inputData.Handbrake or false
	local gear = inputData.Gear or 0

	vehicleInputs[vehicleId] = {
		Throttle = throttle,
		Brake = brake,
		Steer = steer,
		Handbrake = handbrake,
		Gear = gear,
		Timestamp = os.clock(),
	}
end

-- Physics simulation loop (runs on server for validation)
task.spawn(function()
	while true do
		local dt = task.wait(1/60)

		for vehicleId, vehicleEntry in pairs(spawnedVehicles) do
			local model = vehicleEntry.Model
			local inputs = vehicleInputs[vehicleId]

			if model and model.PrimaryPart and inputs then
				VehicleServer.SimulateVehiclePhysics(model, vehicleEntry.Data, inputs, dt)
			end
		end
	end
end)

function VehicleServer.SimulateVehiclePhysics(model: Model, vehicleData: any, inputs: any, dt: number)
	local chassis = model.PrimaryPart
	if not chassis then return end

	-- Get vehicle stats
	local category = vehicleData.Category
	local categoryData = Constants.GetVehicleCategory(category)
	local stats = categoryData and categoryData.Stats or { Speed = 60, Acceleration = 50, Handling = 60 }

	-- Calculate engine force
	local maxSpeed = stats.Speed * 0.5 -- Convert to studs/sec
	local maxForce = stats.Acceleration * 1000

	local throttle = inputs.Throttle or 0
	local brake = inputs.Brake or 0
	local steer = inputs.Steer or 0
	local handbrake = inputs.Handbrake or false

	-- Engine force
	local engineForce = Vector3.new(0, 0, 0)
	if throttle > 0 then
		local currentSpeed = chassis.AssemblyLinearVelocity.Magnitude
		local speedRatio = currentSpeed / maxSpeed
		local torqueMultiplier = 1 - speedRatio * 0.5 -- Torque drops at high speed
		engineForce = -chassis.CFrame.LookVector * maxForce * throttle * torqueMultiplier
	elseif throttle < 0 then
		-- Reverse
		engineForce = chassis.CFrame.LookVector * maxForce * 0.5 * math.abs(throttle)
	end

	-- Braking
	local brakeForce = Vector3.new(0, 0, 0)
	if brake > 0 then
		local velocity = chassis.AssemblyLinearVelocity
		local speed = velocity.Magnitude
		if speed > 0.1 then
			brakeForce = -velocity.Unit * VEHICLE_PHYSICS.BrakeForce * brake
		end
	end

	-- Handbrake (rear wheels only)
	if handbrake then
		local velocity = chassis.AssemblyLinearVelocity
		local lateralVelocity = chassis.CFrame.RightVector:Dot(velocity)
		brakeForce = brakeForce - chassis.CFrame.RightVector * lateralVelocity * VEHICLE_PHYSICS.HandbrakeForce
	end

	-- Steering (torque)
	local steerTorque = 0
	if math.abs(steer) > 0.05 then
		local speed = chassis.AssemblyLinearVelocity.Magnitude
		local steerEffectiveness = Utils.Clamp(speed / 10, 0.1, 1)
		steerTorque = steer * stats.Handling * 5000 * steerEffectiveness
	end

	-- Apply forces
	local totalForce = engineForce + brakeForce
	chassis:ApplyImpulse(totalForce * dt)

	-- Apply steering torque
	if steerTorque ~= 0 then
		chassis:ApplyAngularImpulse(Vector3.new(0, steerTorque * dt, 0))
	end

	-- Aero drag
	local velocity = chassis.AssemblyLinearVelocity
	local speed = velocity.Magnitude
	if speed > 0 then
		local dragForce = -velocity.Unit * VEHICLE_PHYSICS.DragCoefficient * speed * speed * 0.5
		chassis:ApplyImpulse(dragForce * dt)
	end

	-- Downforce (improves traction at speed)
	if VEHICLE_PHYSICS.Downforce > 0 and speed > 10 then
		local downforce = Vector3.new(0, -VEHICLE_PHYSICS.Downforce * speed * speed * 0.001, 0)
		chassis:ApplyImpulse(downforce * dt)
	end

	-- Update engine sound pitch
	VehicleServer.UpdateEngineSound(model, speed, maxSpeed)
end

function VehicleServer.UpdateEngineSound(model: Model, speed: number, maxSpeed: number)
	local sound = model.PrimaryPart and model.PrimaryPart:FindFirstChild("EngineSound")
	if sound then
		local pitch = Utils.Lerp(0.8, 2.0, Utils.Clamp(speed / maxSpeed, 0, 1))
		sound.Pitch = pitch
		sound.Volume = Utils.Lerp(0.3, 1.0, Utils.Clamp(speed / maxSpeed, 0, 1)) * 0.5
	end
end

-- ============================================
- VEHICLE CUSTOMIZATION
-- ============================================

function VehicleServer.ApplyCustomizations(model: Model, vehicleData: any)
	-- Livery
	if vehicleData.Livery then
		local liveryAsset = ReplicatedStorage.Assets.UI:FindFirstChild("Livery_" .. vehicleData.Livery)
		if liveryAsset then
			VehicleServer.ApplyLivery(model, liveryAsset)
		end
	end

	-- Color
	if vehicleData.Color then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part:GetAttribute("Paintable") then
				part.Color = vehicleData.Color
			end
		end
	end

	-- Neon
	if vehicleData.NeonColor then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part:GetAttribute("Neon") then
				part.Material = Enum.Material.Neon
				part.Color = vehicleData.NeonColor
			end
		end
	end
end

function VehicleServer.ApplyLivery(model: Model, liveryAsset: Instance)
	-- Apply decal/texture livery
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("LiverySlot") then
			-- Apply livery texture
			local decal = Instance.new("Decal")
			decal.Texture = liveryAsset.Texture or liveryAsset.Image
			decal.Face = part:GetAttribute("LiveryFace") or Enum.NormalId.Top
			decal.Parent = part
		end
	end
end

function VehicleServer.UpdateVehicleCustomization(userId: number, vehicleId: string, customizations: { [string]: any }): (boolean, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, "Player not found" end

	local vehicle = Utils.Find(profile.VehicleGarage, function(v) return v.Id == vehicleId end)
	if not vehicle then return false, "Vehicle not found" end

	-- Update stored data
	if customizations.Livery then vehicle.Livery = customizations.Livery end
	if customizations.Color then vehicle.Color = customizations.Color end
	if customizations.NeonColor then vehicle.NeonColor = customizations.NeonColor end

	-- Apply to spawned vehicle if active
	local vehicleEntry = spawnedVehicles[vehicleId]
	if vehicleEntry then
		VehicleServer.ApplyCustomizations(vehicleEntry.Model, vehicle)
	end

	return true, nil
end

-- ============================================
- PROCEDURAL VEHICLE GENERATION
-- ============================================

function VehicleServer.CreateProceduralVehicle(vehicleData: any): Model
	local model = Instance.new("Model")
	model.Name = "Procedural_" .. vehicleData.Category

	-- Create chassis
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(4, 1.5, 8)
	chassis.Anchored = false
	chassis.CanCollide = true
	chassis.Massless = false
	chassis.Parent = model

	-- Create wheels
	local wheelPositions = {
		FL = Vector3.new(-1.5, 0.5, 3),  -- Front Left
		FR = Vector3.new(1.5, 0.5, 3),   -- Front Right
		RL = Vector3.new(-1.5, 0.5, -3), -- Rear Left
		RR = Vector3.new(1.5, 0.5, -3),  -- Rear Right
	}

	for name, pos in pairs(wheelPositions) do
		local wheel = Instance.new("Part")
		wheel.Name = "Wheel_" .. name
		wheel.Shape = Enum.PartType.Cylinder
		wheel.Size = Vector3.new(0.5, 1.5, 1.5)
		wheel.Orientation = Vector3.new(0, 0, 90)
		wheel.Position = pos
		wheel.Anchored = false
		wheel.CanCollide = true
		wheel.Massless = false
		wheel.Parent = model

		-- Weld to chassis
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = chassis
		weld.Part1 = wheel
		weld.Parent = chassis

		-- Wheel attachment for suspension
		local attachment = Instance.new("Attachment")
		attachment.Name = "WheelAttachment"
		attachment.Position = Vector3.new(0, -0.75, 0)
		attachment.Parent = wheel
	end

	-- Body
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(3.5, 2, 7)
	body.Position = Vector3.new(0, 2, 0)
	body.Anchored = false
	body.CanCollide = true
	body.Massless = false
	body.Parent = model

	local bodyWeld = Instance.new("WeldConstraint")
	bodyWeld.Part0 = chassis
	bodyWeld.Part1 = body
	bodyWeld.Parent = chassis

	-- Set primary part
	model.PrimaryPart = chassis

	return model
end

-- ============================================
- VEHICLE QUERIES
-- ============================================

function VehicleServer.GetSpawnedVehicle(vehicleId: string): Model?
	local entry = spawnedVehicles[vehicleId]
	return entry and entry.Model
end

function VehicleServer.GetVehicleOwner(vehicleId: string): number?
	local entry = spawnedVehicles[vehicleId]
	return entry and entry.OwnerId
end

function VehicleServer.GetAllSpawnedVehicles(): { [string]: { Model, number, any } }
	return spawnedVehicles
end

function VehicleServer.GetVehicleSpeed(vehicleId: string): number
	local entry = spawnedVehicles[vehicleId]
	if entry and entry.Model and entry.Model.PrimaryPart then
		return entry.Model.PrimaryPart.AssemblyLinearVelocity.Magnitude
	end
	return 0
end

function VehicleServer.GetVehicleFuel(vehicleId: string): number
	local entry = spawnedVehicles[vehicleId]
	if entry and entry.Data then
		return entry.Data.Fuel or 100
	end
	return 100
end

function VehicleServer.SetVehicleFuel(vehicleId: string, fuel: number): boolean
	local entry = spawnedVehicles[vehicleId]
	if entry and entry.Data then
		entry.Data.Fuel = math.clamp(fuel, 0, 200)
		return true
	end
	return false
end

-- ============================================
- INITIALIZATION
-- ============================================

Utils.DebugLog("VehicleServer initialized")

return VehicleServer