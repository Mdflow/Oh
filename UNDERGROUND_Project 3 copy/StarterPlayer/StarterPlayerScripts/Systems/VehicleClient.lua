--[[
	UNDERGROUND — Vehicle Client
	Local vehicle physics, camera, input handling, and visual effects.
	Runs at 60Hz for smooth driving experience.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)
local InputManager = require(script.Parent.InputManager)

local VehicleClient = {}

-- ============================================
- STATE
- ============================================

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local activeVehicleId = nil
local activeVehicleModel = nil
local vehicleData = nil
local vehicleSeat = nil

local currentSpeed = 0
local currentRPM = 0
local currentGear = 0
local isEngineRunning = false

local nitroActive = false
local nitroCooldown = 0
local maxNitro = 100
local currentNitro = 100

local cameraMode = "ThirdPerson" -- "FirstPerson", "ThirdPerson", "Cinematic"
local cameraDistance = 15
local cameraHeight = 5
local cameraAngle = 0

local driftActive = false
local driftAngle = 0
local driftSmoke = {}

local engineSound = nil
local tireSounds = {}
local nitroSound = nil
local collisionSound = nil

local particleEmitters = {}
local lightConnections = {}

local vehiclePhysicsParams = {
	Mass = 1500,
	MaxSpeed = 60,
	MaxRPM = 8000,
	IdleRPM = 800,
	RedlineRPM = 7500,
	GearRatios = { 3.5, 2.2, 1.5, 1.1, 0.8 },
	FinalDrive = 3.5,
	WheelRadius = 0.35,
	BrakeForce = 50000,
	HandbrakeForce = 30000,
	Downforce = 500,
	DragCoefficient = 0.32,
}

-- ============================================
- VEHICLE SPAWNING / DESPAWNING
- ============================================

function VehicleClient.OnVehicleSpawned(vehicleData: any, model: Model)
	Utils.DebugLog("Vehicle spawned:", vehicleData.Id)

	activeVehicleId = vehicleData.Id
	activeVehicleModel = model
	vehicleData = vehicleData

	-- Store physics params from vehicle data
	if vehicleData.Category then
		local category = Constants.GetVehicleCategory(vehicleData.Category)
		if category and category.Stats then
			vehiclePhysicsParams.MaxSpeed = category.Stats.Speed
			vehiclePhysicsParams.MaxRPM = 8000
		end
	end

	-- Setup vehicle
	VehicleClient.SetupVehicle(model)
	VehicleClient.SetupCamera()
	VehicleClient.SetupSounds()
	VehicleClient.SetupParticles()
	VehicleClient.SetupLights()

	-- Start engine
	VehicleClient.StartEngine()

	-- Bind input
	InputManager.SetVehicleInputEnabled(true)

	Signals.GameSignals.VehicleClientReady:Fire(vehicleData)
end

function VehicleClient.OnVehicleDespawned(vehicleId: string)
	if activeVehicleId ~= vehicleId then return end

	Utils.DebugLog("Vehicle despawned:", vehicleId)

	VehicleClient.StopEngine()
	VehicleClient.Cleanup()
	InputManager.SetVehicleInputEnabled(false)

	activeVehicleId = nil
	activeVehicleModel = nil
	vehicleData = nil
	vehicleSeat = nil
	isEngineRunning = false
end

function VehicleClient.OnVehicleUpdated(vehicleId: string, updates: { [string]: any })
	if activeVehicleId ~= vehicleId then return end

	-- Update local vehicle data
	for key, value in pairs(updates) do
		vehicleData[key] = value
	end

	-- Apply visual changes
	if updates.Fuel then
		VehicleClient.UpdateFuelDisplay(updates.Fuel)
	end
	if updates.Durability then
		VehicleClient.UpdateDurabilityDisplay(updates.Durability)
	end
	if upgrades then
		VehicleClient.UpdateUpgradesDisplay(updates.Upgrades)
	end
end

-- ============================================
- VEHICLE SETUP
- ============================================

function VehicleClient.SetupVehicle(model: Model)
	local chassis = model.PrimaryPart
	if not chassis then return end

	-- Find vehicle seat
	vehicleSeat = model:FindFirstChild("VehicleSeat", true)
	if not vehicleSeat then
		-- Find any Seat
		for _, descendant in ipairs(model:GetDescendants()) do
			if descendant:IsA("VehicleSeat") then
				vehicleSeat = descendant
				break
			end
		end
	end

	if vehicleSeat then
		-- Configure seat
		vehicleSeat.HeadsUpDisplay = false
		vehicleSeat.MaxSpeed = 0 -- We control speed manually
		vehicleSeat.Torque = 0 -- We control torque manually
	end

	-- Configure wheels
	for _, wheel in ipairs(model:GetDescendants()) do
		if wheel.Name:match("Wheel") and wheel:IsA("BasePart") then
			wheel.CustomPhysicalProperties = PhysicalProperties.new(1.5, 0.9, 0.05, 100, 0.5)
		end
	end

	-- Set up collision groups
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Vehicles"
		end
	end
end

function VehicleClient.SetupCamera()
	Camera.CameraType = Enum.CameraType.Scriptable
	Camera.CameraSubject = nil
end

function VehicleClient.SetupSounds()
	local model = activeVehicleModel
	if not model then return end

	local chassis = model.PrimaryPart
	if not chassis then return end

	-- Engine sound
	engineSound = Instance.new("Sound")
	engineSound.Name = "EngineSound"
	engineSound.SoundId = "rbxassetid://1841638860" -- Generic engine
	engineSound.Volume = 0.5
	engineSound.Pitch = 1
	engineSound.Looped = true
	engineSound.RollOffMode = Enum.RollOffMode.Linear
	engineSound.RollOffMinDistance = 10
	engineSound.RollOffMaxDistance = 200
	engineSound.Parent = model.PrimaryPart

	-- Tire sounds
	for _, wheel in ipairs(activeVehicleModel:GetDescendants()) do
		if wheel.Name:match("Wheel") and wheel:IsA("BasePart") then
			local tireSound = Instance.new("Sound")
			tireSound.Name = "TireSound"
			tireSound.SoundId = "rbxassetid://1841638862" -- Tire screech
			tireSound.Volume = 0
			tireSound.Pitch = 1
			tireSound.Looped = true
			tireSound.RollOffMode = Enum.RollOffMode.Linear
			tireSound.RollOffMinDistance = 5
			tireSound.RollOffMaxDistance = 50
			tireSound.Parent = wheel
			tireSound:Play()
			table.insert(tireSounds, tireSound)
		end
	end

	-- Nitro sound
	nitroSound = Instance.new("Sound")
	nitroSound.Name = "NitroSound"
	nitroSound.SoundId = "rbxassetid://1841638863" -- Nitro hiss
	nitroSound.Volume = 0
	nitroSound.Pitch = 1.2
	nitroSound.Looped = true
	nitroSound.Parent = model.PrimaryPart

	-- Collision sound
	collisionSound = Instance.new("Sound")
	collisionSound.Name = "CollisionSound"
	collisionSound.SoundId = "rbxassetid://1841638864" -- Metal impact
	collisionSound.Volume = 0.5
	collisionSound.Pitch = 1
	collisionSound.Parent = model.PrimaryPart
end

function VehicleClient.SetupParticles()
	local model = activeVehicleModel
	if not model then return end

	-- Exhaust particles
	local exhaustPoints = model:GetDescendants()
	for _, part in ipairs(model:GetDescendants()) do
		if part.Name:match("Exhaust") and part:IsA("BasePart") then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = "rbxassetid://241625913"
			emitter.Color = ColorSequence.new(Color3.fromRGB(50, 50, 50), Color3.fromRGB(20, 20, 20))
			emitter.Size = NumberSequence.new(0.5, 1)
			emitter.Lifetime = NumberRange.new(0.2, 0.5)
			emitter.Rate = 20
			emitter.Speed = NumberRange.new(5, 10)
			emitter.SpreadAngle = Vector2.new(10, 10)
			emitter.Acceleration = Vector3.new(0, 5, 0)
			emitter.Drag = 2
			emitter.Enabled = false
			emitter.Parent = part
			table.insert(particleEmitters, emitter)
		end
	end

	-- Brake lights
	for _, part in ipairs(activeVehicleModel:GetDescendants()) do
		if part.Name:match("BrakeLight") and part:IsA("BasePart") then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 0, 0)
			light.Range = 10
			light.Brightness = 2
			light.Enabled = false
			light.Parent = part
		end
	end
end

function VehicleClient.SetupLights()
	-- Headlights
	for _, part in ipairs(activeVehicleModel:GetDescendants()) do
		if part.Name:match("Headlight") and part:IsA("BasePart") then
			local spotlight = Instance.new("SpotLight")
			spotlight.Color = Color3.fromRGB(255, 255, 220)
			spotlight.Range = 80
			spotlight.Brightness = 3
			spotlight.Angle = 40
			spotlight.Face = Enum.NormalId.Front
			spotlight.Enabled = false
			spotlight.Parent = part
		end

		if part.Name:match("BrakeLight") and part:IsA("BasePart") then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 0, 0)
			light.Range = 15
			light.Brightness = 3
			light.Enabled = false
			light.Parent = part
		end

		if part.Name:match("ReverseLight") and part:IsA("BasePart") then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 255, 255)
			light.Range = 10
			light.Brightness = 1
			light.Enabled = false
			light.Parent = part
		end
	end
end

-- ============================================
- ENGINE MANAGEMENT
- ============================================

function VehicleClient.StartEngine()
	if isEngineRunning then return end

	isEngineRunning = true
	currentRPM = vehiclePhysicsParams.IdleRPM

	if engineSound then
		engineSound:Play()
	end

	Signals.GameSignals.VehicleEngineStarted:Fire()
end

function VehicleClient.StopEngine()
	if not isEngineRunning then return end

	isEngineRunning = false
	currentRPM = 0

	if engineSound then
		engineSound:Stop()
	end

	-- Stop all particle emitters
	for _, emitter in ipairs(particleEmitters) do
		emitter.Enabled = false
	end

	Signals.GameSignals.VehicleEngineStopped:Fire()
end

function VehicleClient.ToggleEngine()
	if isEngineRunning then
		VehicleClient.StopEngine()
	else
		VehicleClient.StartEngine()
	end
end

-- ============================================
- PHYSICS UPDATE (60Hz)
- ============================================

RunService.Heartbeat:Connect(function(dt)
	if not activeVehicleModel or not activeVehicleModel.PrimaryPart then return end
	if not isEngineRunning then return end

	local chassis = activeVehicleModel.PrimaryPart
	if not chassis then return end

	-- Get input
	local input = InputManager.GetVehicleInput()
	local throttle = input.Throttle
	local brake = input.Brake
	local steer = input.Steer
	local handbrake = input.Handbrake

	-- Gear shifting
	VehicleClient.UpdateGear()

	-- Calculate RPM
	VehicleClient.UpdateRPM(dt)

	-- Engine force
	VehicleClient.ApplyEngineForce(throttle, dt)

	-- Braking
	if brake > 0 then
		VehicleClient.ApplyBrake(brake, dt)
	end

	-- Handbrake
	if handbrake then
		VehicleClient.ApplyHandbrake(dt)
	end

	-- Steering
	if math.abs(steer) > 0.01 then
		VehicleClient.ApplySteering(steer, dt)
	end

	-- Drift detection
	VehicleClient.UpdateDrift()

	-- Aero
	VehicleClient.ApplyAero(dt)

	-- Downforce
	VehicleClient.ApplyDownforce(dt)

	-- Update sounds
	VehicleClient.UpdateSounds()

	-- Update particles
	VehicleClient.UpdateParticles()

	-- Update lights
	VehicleClient.UpdateLights()

	-- Update camera
	VehicleClient.UpdateCamera()

	-- Update HUD
	VehicleClient.UpdateHUD()

	-- Send input to server (handled in ClientBootstrap)
end

function VehicleClient.UpdateGear()
	local chassis = activeVehicleModel.PrimaryPart
	if not chassis then return end

	local speed = chassis.AssemblyLinearVelocity.Magnitude
	local currentGearRatio = vehiclePhysicsParams.GearRatios[currentGear + 1] or 1
	local finalDrive = vehiclePhysicsParams.FinalDrive

	-- Auto-shift logic (simplified)
	local targetGear = currentGear
	local gearRatio = vehiclePhysicsParams.GearRatios[currentGear + 1] or 1
	local engineRPM = currentRPM
	local wheelRPM = (chassis.AssemblyLinearVelocity.Magnitude / vehiclePhysicsParams.WheelRadius) * 60 / (2 * math.pi)
	local engineRPMFromWheels = wheelRPM * vehiclePhysicsParams.GearRatios[currentGear + 1] * vehiclePhysicsParams.FinalDrive

	-- Auto upshift
	if currentRPM > vehiclePhysicsParams.ShiftUpRPM and currentGear < #vehiclePhysicsParams.GearRatios then
		currentGear = currentGear + 1
		Signals.GameSignals.VehicleGearChanged:Fire(currentGear)
	end

	-- Auto downshift
	if currentRPM < vehiclePhysicsParams.ShiftDownRPM and currentGear > 1 then
		currentGear = currentGear - 1
		Signals.GameSignals.VehicleGearChanged:Fire(currentGear)
	end

	-- Reverse gear
	-- Manual override would be handled via input
end

function VehicleClient.UpdateRPM(dt: number)
	local chassis = activeVehicleModel.PrimaryPart
	if not chassis then return end

	local speed = chassis.AssemblyLinearVelocity.Magnitude
	local gearRatio = vehiclePhysicsParams.GearRatios[currentGear + 1] or 1
	local finalDrive = vehiclePhysicsParams.FinalDrive

	-- Calculate RPM from wheel speed
	local wheelRPM = (chassis.AssemblyLinearVelocity.Magnitude / vehiclePhysicsParams.WheelRadius) * 60 / (2 * math.pi)
	local targetRPM = wheelRPM * vehiclePhysicsParams.GearRatios[currentGear + 1] * vehiclePhysicsParams.FinalDrive

	-- Clamp to redline
	targetRPM = math.min(targetRPM, vehiclePhysicsParams.RedlineRPM)
	targetRPM = math.max(targetRPM, vehiclePhysicsParams.IdleRPM)

	-- Smooth RPM changes
	currentRPM = Utils.Lerp(currentRPM, targetRPM, 1 - math.exp(-dt * 10))

	-- Update engine sound
	if engineSound then
		engineSound.Pitch = Utils.Lerp(0.8, 2.0, Utils.Clamp(currentRPM / vehiclePhysicsParams.RedlineRPM, 0, 1))
		engineSound.Volume = Utils.Lerp(0.3, 1.0, Utils.Clamp(currentRPM / vehiclePhysicsParams.RedlineRPM, 0, 1)) * 0.5
	end
end

function VehicleClient.ApplyEngineForce(throttle: number, dt: number)
	if throttle <= 0 then return end

	local chassis = activeVehicleModel.PrimaryPart
	if not chassis then return end

	local maxSpeed = vehiclePhysicsParams.MaxSpeed
	local currentSpeed = chassis.AssemblyLinearVelocity.Magnitude
	local speedRatio = currentSpeed / maxSpeed

	-- Torque curve (peaks at mid-RPM)
	local rpmRatio = currentRPM / vehiclePhysicsParams.RedlineRPM
	local torqueMultiplier = 1 - (rpmRatio - 0.5)^2 * 2 -- Parabolic torque curve
	torqueMultiplier = math.clamp(torqueMultiplier, 0.3, 1)

	local maxForce = 50000 * torqueMultiplier
	local engineForce = -activeVehicleModel.PrimaryPart.CFrame.LookVector * maxForce * throttle

	activeVehicleModel.PrimaryPart:ApplyImpulse(engineForce * dt)
end

function VehicleClient.ApplyBrake(brake: number, dt: number)
	local chassis = activeVehicleModel.PrimaryPart
	if not chassis then return end

	local velocity = chassis.AssemblyLinearVelocity
	local speed = velocity.Magnitude

	if speed > 0.1 then
		local brakeForce = -velocity.Unit * VEHICLE_PHYSICS.BrakeForce * brake
		chassis:ApplyImpulse(brakeForce * dt)

		-- Enable brake lights
		VehicleClient.SetBrakeLights(true)
	else
		VehicleClient.SetBrakeLights(false)
	end
end

function VehicleClient.ApplyHandbrake(dt: number)
	local chassis = activeVehicleModel.PrimaryPart
	if not chassis then return end

	-- Apply lateral braking (drift)
	local lateralVelocity = chassis.CFrame.RightVector:Dot(chassis.AssemblyLinearVelocity)
	local handbrakeForce = -chassis.CFrame.RightVector * lateralVelocity * VEHICLE_PHYSICS.HandbrakeForce
	chassis:ApplyImpulse(handbrakeForce)

	-- Enable drift mode
	driftActive = true
end

function VehicleClient.ApplySteering(steer: number, dt: number)
	local chassis = activeVehicleModel.PrimaryPart
	if not chassis then return end

	local speed = chassis.AssemblyLinearVelocity.Magnitude
	if speed < 1 then return end

	-- Speed-sensitive steering
	local steerEffectiveness = Utils.Clamp(speed / 20, 0.1, 1)
	local maxSteerAngle = 45 * steerEffectiveness -- degrees
	local targetAngle = steer * maxSteerAngle

	-- Apply steering torque
	local steerTorque = steer * 100000 * steerEffectiveness
	chassis:ApplyAngularImpulse(Vector3.new(0, steer * 100000 * steerEffectiveness * dt, 0))

	-- Drift assistance
	if driftActive and math.abs(steer) > 0.5 then
		-- Counter-steer assistance
		local counterSteer = -steer * 0.3
		chassis:ApplyAngularImpulse(Vector3.new(0, counterSteer * 50000 * dt, 0))
	end
end

function VehicleClient.UpdateDrift()
	local chassis = activeVehicleModel.PrimaryPart
	if not chassis then return end

	local velocity = chassis.AssemblyLinearVelocity
	local forward = chassis.CFrame.LookVector
	local right = chassis.CFrame.RightVector

	local forwardSpeed = forward:Dot(velocity)
	local lateralSpeed = right:Dot(velocity)

	local driftAngle = math.atan2(lateralSpeed, forwardSpeed)
	driftAngle = math.deg(driftAngle)

	if math.abs(driftAngle) > 15 and math.abs(lateralSpeed) > 5 then
		if not driftActive then
			driftActive = true
			Signals.GameSignals.VehicleDriftStarted:Fire()
			VehicleClient.StartDriftEffects()
		end

		driftAngle = driftAngle
	else
		if driftActive then
			driftActive = false
			Signals.GameSignals.VehicleDriftEnded:Fire()
			VehicleClient.StopDriftEffects()
		end
	end
end

function VehicleClient.StartDriftEffects()
	-- Tire smoke
	for _, wheel in ipairs(activeVehicleModel:GetDescendants()) do
		if wheel.Name:match("Wheel") and wheel:IsA("BasePart") then
			local emitter = wheel:FindFirstChild("DriftSmoke")
			if not emitter then
				local emitter = Instance.new("ParticleEmitter")
				emitter.Name = "DriftSmoke"
				emitter.Texture = "rbxassetid://241625913"
				emitter.Color = ColorSequence.new(Color3.fromRGB(200, 200, 200), Color3.fromRGB(100, 100, 100))
				emitter.Size = NumberSequence.new(1, 2)
				emitter.Lifetime = NumberRange.new(0.2, 0.5)
				emitter.Rate = 50
				emitter.Speed = NumberRange.new(10, 20)
				emitter.SpreadAngle = Vector2.new(30, 30)
				emitter.Acceleration = Vector3.new(0, 5, 0)
				emitter.Drag = 3
				emitter.Enabled = true
				emitter.Parent = wheel
			else
				emitter.Enabled = true
			end
		end
	end

	-- Tire screech sound
	for _, sound in ipairs(tireSounds) do
		sound.Volume = 0.5
	end
end

function VehicleClient.StopDriftEffects()
	for _, wheel in ipairs(activeVehicleModel:GetDescendants()) do
		local emitter = wheel:FindFirstChild("DriftSmoke")
		if emitter then
			emitter.Enabled = false
		end
	end

	for _, sound in ipairs(tireSounds) do
		sound.Volume = 0
	end
end

function VehicleClient.ApplyAero(dt: number)
	local chassis = activeVehicleModel.PrimaryPart
	if not chassis then return end

	local velocity = chassis.AssemblyLinearVelocity
	local speed = velocity.Magnitude

	if speed > 0 then
		local dragForce = -velocity.Unit * vehiclePhysicsParams.DragCoefficient * speed * speed * 0.5
		activeVehicleModel.PrimaryPart:ApplyImpulse(dragForce * dt)
	end
end

function VehicleClient.ApplyDownforce(dt: number)
	local chassis = activeVehicleModel.PrimaryPart
	if not chassis then return end

	local speed = chassis.AssemblyLinearVelocity.Magnitude
	if speed > 10 then
		local downforce = Vector3.new(0, -vehiclePhysicsParams.Downforce * speed * speed * 0.001, 0)
		activeVehicleModel.PrimaryPart:ApplyImpulse(downforce * dt)
	end
end

-- ============================================
- SOUNDS & PARTICLES
- ============================================

function VehicleClient.UpdateSounds()
	-- Tire sounds based on slip
	local chassis = activeVehicleModel.PrimaryPart
	if not chassis then return end

	local lateralSpeed = math.abs(chassis.CFrame.RightVector:Dot(chassis.AssemblyLinearVelocity))
	local slipRatio = lateralSpeed / 20 -- Normalize

	for _, sound in ipairs(tireSounds) do
		sound.Volume = Utils.Lerp(0, 0.8, Utils.Clamp(slipRatio, 0, 1))
		sound.Pitch = Utils.Lerp(0.8, 1.2, Utils.Clamp(slipRatio, 0, 1))
	end

	-- Nitro sound
	if nitroSound then
		if nitroActive then
			if nitroSound.Volume < 0.5 then
				nitroSound.Volume = Utils.Lerp(nitroSound.Volume, 0.5, 0.1)
			end
			if not nitroSound.IsPlaying then
				nitroSound:Play()
			end
		else
			if nitroSound.Volume > 0 then
				nitroSound.Volume = Utils.Lerp(nitroSound.Volume, 0, 0.1)
			end
			if nitroSound.Volume < 0.01 then
				nitroSound:Stop()
			end
		end
	end
end

function VehicleClient.UpdateParticles()
	local chassis = activeVehicleModel.PrimaryPart
	if not chassis then return end

	local speed = chassis.AssemblyLinearVelocity.Magnitude

	-- Exhaust particles
	for _, emitter in ipairs(particleEmitters) do
		local rate = Utils.Lerp(5, 50, Utils.Clamp(speed / 50, 0, 1))
		emitter.Rate = rate
		emitter.Enabled = isEngineRunning and speed > 1
	end

	-- Drift smoke handled separately
end

function VehicleClient.UpdateLights()
	-- Headlights
	-- Brake lights
	-- Reverse lights
	-- Would check vehicle state and update light instances
end

-- ============================================
- CAMERA SYSTEM
- ============================================

function VehicleClient.UpdateCamera()
	if not activeVehicleModel or not activeVehicleModel.PrimaryPart then return end

	local chassis = activeVehicleModel.PrimaryPart
	local vehicleCFrame = chassis.CFrame
	local vehiclePosition = chassis.Position
	local vehicleVelocity = chassis.AssemblyLinearVelocity

	local targetCFrame

	if cameraMode == "FirstPerson" then
		targetCFrame = vehicleCFrame * CFrame.new(0, 2.5, 3)
	elseif cameraMode == "Cinematic" then
		-- Cinematic camera follows at fixed angle
		local angle = tick() * 0.2
		local offset = CFrame.new(math.sin(tick()) * 30, 20, math.cos(tick()) * 30)
		targetCFrame = CFrame.new(chassis.Position + Vector3.new(0, 15, 0)) * offset
	else
		-- Third person
		local distance = cameraDistance
		local height = cameraHeight
		local angle = cameraAngle

		local offset = CFrame.new(
			math.sin(cameraAngle) * cameraDistance,
			cameraHeight,
			math.cos(cameraAngle) * cameraDistance
		)

		-- Smooth follow
		local targetPos = chassis.Position + Vector3.new(0, cameraHeight, 0) + offset.Position
		local lookAt = chassis.Position + chassis.CFrame.LookVector * 10

		-- Smooth camera movement
		local currentCFrame = Camera.CFrame
		local targetCFrame = CFrame.new(targetPos, lookAt)

		Camera.CFrame = currentCFrame:Lerp(targetCFrame, 0.1)
		return
	end

	Camera.CFrame = targetCFrame
end

function VehicleClient.SetCameraMode(mode: string)
	if mode == "FirstPerson" or mode == "ThirdPerson" or mode == "Cinematic" then
		cameraMode = mode
	end
end

function VehicleClient.SetCameraDistance(distance: number)
	cameraDistance = math.clamp(distance, 5, 50)
end

function VehicleClient.SetCameraHeight(height: number)
	cameraHeight = math.clamp(height, 2, 20)
end

function VehicleClient.SetCameraAngle(angle: number)
	cameraAngle = angle
end

-- ============================================
- NITRO SYSTEM
- ============================================

function VehicleClient.ActivateNitro()
	if currentNitro <= 0 or nitroActive then return end

	nitroActive = true
	currentNitro = math.max(0, currentNitro - 1)

	-- Apply nitro force
	local chassis = activeVehicleModel.PrimaryPart
	if chassis then
		local nitroForce = -chassis.CFrame.LookVector * 100000
		chassis:ApplyImpulse(nitroForce)
	end

	-- Visual effects
	VehicleClient.StartNitroEffects()

	Signals.GameSignals.VehicleNitroActivated:Fire()
end

function VehicleClient.DeactivateNitro()
	if not nitroActive then return end

	nitroActive = false
	VehicleClient.StopNitroEffects()
end

function VehicleClient.StartNitroEffects()
	-- Flames
	for _, part in ipairs(activeVehicleModel:GetDescendants()) do
		if part.Name:match("Exhaust") and part:IsA("BasePart") then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "NitroFlames"
			emitter.Texture = "rbxassetid://241625913"
			emitter.Color = ColorSequence.new(Color3.fromRGB(255, 150, 0), Color3.fromRGB(255, 50, 0))
			emitter.Size = NumberSequence.new(1, 3)
			emitter.Lifetime = NumberRange.new(0.1, 0.3)
			emitter.Rate = 100
			emitter.Speed = NumberRange.new(20, 40)
			emitter.SpreadAngle = Vector2.new(20, 20)
			emitter.Acceleration = Vector3.new(0, 10, 0)
			emitter.Drag = 5
			emitter.Enabled = true
			emitter.Parent = part
		end
	end

	-- Screen effects
	-- Camera shake
	-- Screen blur
end

function VehicleClient.StopNitroEffects()
	for _, part in ipairs(activeVehicleModel:GetDescendants()) do
		local emitter = part:FindFirstChild("NitroFlames")
		if emitter then
			emitter.Enabled = false
			emitter:Destroy()
		end
	end
end

function VehicleClient.UpdateNitro(dt: number)
	if nitroActive then
		currentNitro = math.max(0, currentNitro - dt * 20) -- 20 per second
		if currentNitro <= 0 then
			VehicleClient.DeactivateNitro()
		end
	else
		-- Regenerate
		currentNitro = math.min(maxNitro, currentNitro + dt * 5)
	end
end

-- ============================================
- HUD UPDATES
- ============================================

function VehicleClient.UpdateHUD()
	if not activeVehicleModel or not activeVehicleModel.PrimaryPart then return end

	local chassis = activeVehicleModel.PrimaryPart
	local speed = chassis.AssemblyLinearVelocity.Magnitude * 3.6 -- Convert to km/h
	currentSpeed = speed

	-- Update UIController
	Signals.GameSignals.VehicleSpeedChanged:Fire(speed)
	Signals.GameSignals.VehicleGearChanged:Fire(currentGear)
	Signals.GameSignals.VehicleRPMChanged:Fire(currentRPM)
	Signals.GameSignals.VehicleFuelChanged:Fire(vehicleData.Fuel or 100)
	Signals.GameSignals.VehicleDurabilityChanged:Fire(vehicleData.Durability or 100)
	Signals.GameSignals.VehicleNitroChanged:Fire(currentNitro / maxNitro * 100)
end

function VehicleClient.UpdateFuelDisplay(fuel: number)
	Signals.GameSignals.VehicleFuelChanged:Fire(fuel)
end

function VehicleClient.UpdateDurabilityDisplay(durability: number)
	Signals.GameSignals.VehicleDurabilityChanged:Fire(durability)
end

function VehicleClient.UpdateUpgradesDisplay(upgrades: { [string]: number })
	-- Update vehicle physics params based on upgrades
	if upgrades.Engine then
		local engineUpgrade = Constants.VehicleUpgrades.Engine
		if engineUpgrade then
			vehiclePhysicsParams.MaxSpeed = vehiclePhysicsParams.MaxSpeed * (1 + engineUpgrade.StatBonuses.Speed / 100)
		end
	end
	-- ... other upgrades
end

-- ============================================
- COLLISION HANDLING
- ============================================

activeVehicleModel.PrimaryPart.Touched:Connect(function(hit)
	if not hit:IsA("BasePart") then return end

	local hitModel = hit:FindFirstAncestorOfClass("Model")
	if hitModel and hitModel.Name:match("Vehicle_") then
		-- Vehicle collision
		VehicleClient.HandleVehicleCollision(hitModel)
	elseif hitModel and hitModel:FindFirstChild("Humanoid") then
		-- Pedestrian collision
		VehicleClient.HandlePedestrianCollision(hitModel)
	else
		-- Environment collision
		VehicleClient.HandleEnvironmentCollision(hit)
	end
end)

function VehicleClient.HandleVehicleCollision(otherVehicle: Model)
	if collisionSound then
		collisionSound:Play()
	end

	-- Screen shake
	UIController.ShakeScreen(0.5)

	-- Damage
	VehicleClient.ApplyDamage(10)

	Signals.GameSignals.VehicleCollision:Fire()
end

function VehicleClient.HandlePedestrianCollision(character: Model)
	if collisionSound then
		collisionSound:Play()
	end

	-- Heavy penalty
	VehicleClient.ApplyDamage(5)
	HeatServer.AddHeat(Players.LocalPlayer.UserId, 5, "PedestrianCollision")

	Signals.GameSignals.PedestrianCollision:Fire()
end

function VehicleClient.HandleEnvironmentCollision(hit: BasePart)
	if collisionSound then
		collisionSound:Play()
	end

	local severity = 5
	VehicleClient.ApplyDamage(severity)
end

function VehicleClient.ApplyDamage(amount: number)
	if not vehicleData then return end

	vehicleData.Durability = math.max(0, (vehicleData.Durability or 100) - amount)
	Signals.GameSignals.VehicleDurabilityChanged:Fire(vehicleData.Durability)

	if vehicleData.Durability <= 0 then
		VehicleClient.DestroyVehicle()
	end
end

function VehicleClient.DestroyVehicle()
	VehicleClient.StopEngine()
	VehicleClient.Cleanup()
	Signals.GameSignals.VehicleDestroyed:Fire()
end

-- ============================================
- NITRO INPUT
- ============================================

Signals.GameSignals.VehicleNitro:Connect(function(active)
	if active then
		VehicleClient.ActivateNitro()
	else
		VehicleClient.DeactivateNitro()
	end
end)

-- ============================================
- CLEANUP
- ============================================

function VehicleClient.Cleanup()
	VehicleClient.StopEngine()

	-- Clean up sounds
	if engineSound then engineSound:Destroy() end
	if nitroSound then nitroSound:Destroy() end
	if collisionSound then collisionSound:Destroy() end
	for _, sound in ipairs(tireSounds) do sound:Destroy() end

	-- Clean up particles
	for _, emitter in ipairs(particleEmitters) do
		emitter:Destroy()
	end
	particleEmitters = {}

	-- Clean up lights
	for _, conn in ipairs(lightConnections) do
		conn:Disconnect()
	end
	lightConnections = {}

	-- Reset camera
	Camera.CameraType = Enum.CameraType.Custom
	Camera.CameraSubject = Player.Character and Player.Character:FindFirstChild("Humanoid")

	-- Clear particle emitters
	for _, emitter in pairs(particleEmitters) do
		emitter:Destroy()
	end
	particleEmitters = {}

	-- Clear drift smoke
	VehicleClient.StopDriftEffects()

	-- Clear nitro effects
	VehicleClient.StopNitroEffects()

	-- Reset camera
	Camera.CameraType = Enum.CameraType.Custom
	Camera.CameraSubject = Player.Character and Player.Character:FindFirstChild("Humanoid")
end

function VehicleClient.GetActiveVehicleId(): string?
	return activeVehicleId
end

function VehicleClient.GetActiveVehicleModel(): Model?
	return activeVehicleModel
end

function VehicleClient.GetVehicleData(): any
	return vehicleData
end

function VehicleClient.GetCurrentSpeed(): number
	return currentSpeed
end

function VehicleClient.GetCurrentRPM(): number
	return currentRPM
end

function VehicleClient.GetCurrentGear(): number
	return currentGear
end

function VehicleClient.GetNitroLevel(): number
	return currentNitro / 100
end

function VehicleClient.IsDrifting(): boolean
	return driftActive
end

function VehicleClient.GetDriftAngle(): number
	return driftAngle
end

Utils.DebugLog("VehicleClient initialized")

return VehicleClient