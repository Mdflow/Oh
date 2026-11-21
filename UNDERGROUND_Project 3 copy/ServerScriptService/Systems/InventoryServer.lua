--[[
	UNDERGROUND — Inventory Server
	Manages packages, items, vehicle garage, and hideout storage.
	Server-authoritative with weight/space limits.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)
local PlayerDataServer = require(script.Parent.PlayerDataServer)

local InventoryServer = {}

-- ============================================
-- INVENTORY LIMITS
-- ============================================

local function GetInventoryCapacity(userId: number): number
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return 20 end

	local baseCapacity = 20
	local hideoutBonus = 0

	for _, tier in ipairs(Constants.Economy.HideoutTiers) do
		if tier.Name == profile.HideoutTier then
			hideoutBonus = tier.Storage or 0
			break
		end
	end

	return baseCapacity + hideoutBonus
end

local function GetVehicleCapacity(userId: number): number
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return 5 end

	local baseCapacity = 5
	local hideoutBonus = 0

	for _, tier in ipairs(Constants.Economy.HideoutTiers) do
		if tier.Name == profile.HideoutTier then
			hideoutBonus = tier.Vehicles or 0
			break
		end
	end

	return baseCapacity + hideoutBonus
end

local function GetPackageWeight(packageData: any): number
	return packageData.Weight or 1
end

local function GetTotalInventoryWeight(userId: number): number
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return 0 end

	local total = 0
	for _, pkg in ipairs(profile.Inventory) do
		total += GetPackageWeight(pkg)
	end
	return total
end

-- ============================================
-- PACKAGE MANAGEMENT
-- ============================================

--[[
	Create a new package instance with proper initialization.
]]
function InventoryServer.CreatePackage(packageType: string, rarity: string, contractId: string?): any
	local typeData = Constants.PackageTypes[packageType]
	local rarityData = Constants.GetPackageRarity(rarity)

	if not typeData or not rarityData then
		return nil
	end

	local package = {
		Id = Utils.GenerateUUID(),
		Type = packageType,
		Rarity = rarity,

		-- Value
		BaseValue = math.floor(100 * rarityData.ValueMultiplier), -- Base 100 * multiplier
		CurrentValue = math.floor(100 * rarityData.ValueMultiplier),

		-- Physical
		Weight = rarityData.Weight,
		Size = Vector3.new(2, 1.5, 1), -- Default size

		-- Condition
		Condition = 100,
		MaxCondition = 100,

		-- Contract link
		ContractId = contractId,

		-- Metadata
		SpawnedAt = os.time(),
		PickedUpAt = nil,
		DeliveredAt = nil,
		DamageHistory = {},
		SpecialFlags = typeData.Special and { typeData.Special } or {},
	}

	-- Apply type-specific properties
	if typeData.Special == "Fragile" then
		package.MaxCondition = 80
		package.Condition = 80
	elseif typeData.Special == "Timed" then
		package.TimeLimit = 300 -- 5 minutes base
	elseif typeData.Special == "Hot" then
		package.HeatMultiplier = 1.5
	elseif typeData.Special == "Cold" then
		package.RequiresCooling = true
		package.Temperature = 0 -- Celsius
	elseif typeData.Special == "Live" then
		package.MaxGForce = 2.0
	elseif typeData.Special == "Explosive" then
		package.NoCrash = true
	elseif typeData.Special == "Data" then
		package.SignalJammer = true
	end

	return package
end

--[[
	Spawn a package in the world at a specific location.
]]
function InventoryServer.SpawnPackage(packageData: any, position: Vector3, district: string): any
	-- This would create the physical package model in Workspace
	-- For now, just return the data with position
	packageData.WorldPosition = position
	packageData.District = district
	packageData.IsInWorld = true

	return packageData
end

--[[
	Player picks up a package from the world.
]]
function InventoryServer.PickupPackage(userId: number, packageId: string): (boolean, any?, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, nil, "Player not found" end

	-- Check capacity
	if #profile.Inventory >= GetInventoryCapacity(userId) then
		return false, nil, "Inventory full"
	end

	-- Check weight
	local packageData = FindWorldPackage(packageId)
	if not packageData then
		return false, nil, "Package not found"
	end

	local currentWeight = GetTotalInventoryWeight(userId)
	if currentWeight + GetPackageWeight(packageData) > GetInventoryCapacity(userId) * 2 then -- Weight limit = 2x slot count
		return false, nil, "Too heavy to carry"
	end

	-- Remove from world
	RemoveWorldPackage(packageId)

	-- Update package state
	packageData.PickedUpAt = os.time()
	packageData.IsInWorld = false
	packageData.WorldPosition = nil

	-- Add to inventory
	PlayerDataServer.AddToInventory(userId, packageData)

	return true, packageData, nil
end

--[[
	Player drops a package from inventory.
]]
function InventoryServer.DropPackage(userId: number, packageId: string, position: Vector3): (boolean, any?, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, nil, "Player not found" end

	-- Find and remove from inventory
	local packageData = PlayerDataServer.RemoveFromInventory(userId, packageId)
	if not packageData then
		return false, nil, "Package not in inventory"
	end

	-- Update state
	packageData.PickedUpAt = nil
	packageData.IsInWorld = true
	packageData.WorldPosition = position

	-- Add to world
	AddWorldPackage(packageData)

	return true, packageData, nil
end

--[[
	Transfer package between players (trading).
]]
function InventoryServer.TransferPackage(fromUserId: number, toUserId: number, packageId: string): (boolean, string?)
	local fromProfile = PlayerDataServer.GetProfile(fromUserId)
	local toProfile = PlayerDataServer.GetProfile(toUserId)

	if not fromProfile or not toProfile then
		return false, "Player not found"
	end

	-- Check if recipient has space
	if #toProfile.Inventory >= GetInventoryCapacity(toUserId) then
		return false, "Recipient inventory full"
	end

	-- Remove from sender
	local packageData = PlayerDataServer.RemoveFromInventory(fromUserId, packageId)
	if not packageData then
		return false, "Package not found in sender inventory"
	end

	-- Add to recipient
	PlayerDataServer.AddToInventory(toUserId, packageData)

	return true, nil
end

-- ============================================
-- VEHICLE GARAGE
-- ============================================

function InventoryServer.GetGarage(userId: number): { any }
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return {} end
	return profile.VehicleGarage
end

function InventoryServer.SetActiveVehicle(userId: number, vehicleId: string): (boolean, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, "Player not found" end

	-- Find vehicle
	local vehicle = Utils.Find(profile.VehicleGarage, function(v) return v.Id == vehicleId end)
	if not vehicle then
		return false, "Vehicle not found"
	end

	-- Deactivate current
	for _, v in ipairs(profile.VehicleGarage) do
		v.IsActive = (v.Id == vehicleId)
	end

	return true, nil
end

function InventoryServer.GetActiveVehicle(userId: number): any?
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return nil end

	return Utils.Find(profile.VehicleGarage, function(v) return v.IsActive end)
end

function InventoryServer.RefuelVehicle(userId: number, vehicleId: string, amount: number?): (boolean, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, "Player not found" end

	local vehicle = Utils.Find(profile.VehicleGarage, function(v) return v.Id == vehicleId end)
	if not vehicle then return false, "Vehicle not found" end

	local maxFuel = 100
	-- Get vehicle stats for fuel capacity
	local category = Constants.GetVehicleCategory(vehicle.Category)
	if category and category.Stats then
		maxFuel = category.Stats.Fuel
	end

	local refillAmount = amount or maxFuel
	vehicle.Fuel = math.min(maxFuel, vehicle.Fuel + refillAmount)

	return true, nil
end

function InventoryServer.RepairVehicle(userId: number, vehicleId: string): (boolean, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, "Player not found" end

	local vehicle = Utils.Find(profile.VehicleGarage, function(v) return v.Id == vehicleId end)
	if not vehicle then return false, "Vehicle not found" end

	vehicle.Durability = 100

	return true, nil
end

function InventoryServer.ApplyVehicleDamage(userId: number, vehicleId: string, damage: number): boolean
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false end

	local vehicle = Utils.Find(profile.VehicleGarage, function(v) return v.Id == vehicleId end)
	if not vehicle then return false end

	vehicle.Durability = math.max(0, vehicle.Durability - damage)

	-- Check for destruction
	if vehicle.Durability <= 0 then
		vehicle.Durability = 0
		Signals.GameSignals.VehicleDestroyed:Fire(userId, vehicleId)
	end

	Signals.GameSignals.VehicleDamaged:Fire(userId, vehicleId, vehicle.Durability)
	return true
end

function InventoryServer.ApplyVehicleFuelConsumption(userId: number, vehicleId: string, amount: number): boolean
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false end

	local vehicle = Utils.Find(profile.VehicleGarage, function(v) return v.Id == vehicleId end)
	if not vehicle then return false end

	vehicle.Fuel = math.max(0, vehicle.Fuel - amount)

	if vehicle.Fuel <= 0 then
		vehicle.Fuel = 0
		-- Vehicle stalls
		Signals.GameSignals.FuelChanged:Fire(userId, vehicleId, 0)
	end

	return true
end

-- ============================================
-- PACKAGE CONDITION
-- ============================================

function InventoryServer.ApplyPackageDamage(userId: number, packageId: string, damage: number, cause: string): boolean
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false end

	local package = Utils.Find(profile.Inventory, function(p) return p.Id == packageId end)
	if not package then return false end

	local oldCondition = package.Condition
	package.Condition = math.max(0, package.Condition - damage)

	-- Record damage
	table.insert(package.DamageHistory, {
		Time = os.time(),
		Amount = damage,
		Cause = cause,
		OldCondition = oldCondition,
		NewCondition = package.Condition,
	})

	-- Check for destruction
	if package.Condition <= 0 then
		package.Condition = 0
		-- Package destroyed - remove from inventory
		PlayerDataServer.RemoveFromInventory(userId, packageId)
		return false -- Package destroyed
	end

	return true
end

function InventoryServer.GetPackageCondition(userId: number, packageId: string): number?
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return nil end

	local package = Utils.Find(profile.Inventory, function(p) return p.Id == packageId end)
	return package and package.Condition
end

-- ============================================
-- HIDEOUT STORAGE
-- ============================================

function InventoryServer.StorePackageInHideout(userId: number, packageId: string): (boolean, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, "Player not found" end

	-- Check hideout capacity
	local tierConfig
	for _, tier in ipairs(Constants.Economy.HideoutTiers) do
		if tier.Name == profile.HideoutTier then
			tierConfig = tier
			break
		end
	end

	if not tierConfig then return false, "No hideout" end

	local currentStored = #(profile.PackageStorage or {})
	if currentStored >= tierConfig.Storage then
		return false, "Storage full"
	end

	-- Remove from inventory
	local packageData = PlayerDataServer.RemoveFromInventory(userId, packageId)
	if not packageData then return false, "Package not found" end

	-- Add to storage
	profile.PackageStorage = profile.PackageStorage or {}
	table.insert(profile.PackageStorage, packageData)

	return true, nil
end

function InventoryServer.RetrievePackageFromHideout(userId: number, packageId: string): (boolean, any?, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, nil, "Player not found" end

	-- Check inventory space
	if #profile.Inventory >= GetInventoryCapacity(userId) then
		return false, nil, "Inventory full"
	end

	-- Find in storage
	local packageData, index = Utils.Find(profile.PackageStorage or {}, function(p) return p.Id == packageId end)
	if not packageData then return false, nil, "Package not in storage" end

	-- Remove from storage
	table.remove(profile.PackageStorage, index)

	-- Add to inventory
	PlayerDataServer.AddToInventory(userId, packageData)

	return true, packageData, nil
end

function InventoryServer.GetHideoutPackages(userId: number): { any }
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return {} end
	return profile.PackageStorage or {}
end

-- ============================================
-- VEHICLE STORAGE IN HIDEOUT
-- ============================================

function InventoryServer.StoreVehicleInHideout(userId: number, vehicleId: string): (boolean, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, "Player not found" end

	-- Check hideout vehicle capacity
	local tierConfig
	for _, tier in ipairs(Constants.Economy.HideoutTiers) do
		if tier.Name == profile.HideoutTier then
			tierConfig = tier
			break
		end
	end

	if not tierConfig then return false, "No hideout" end

	local currentStored = #(profile.HideoutVehicles or {})
	if currentStored >= tierConfig.Vehicles then
		return false, "Vehicle storage full"
	end

	-- Find and remove from garage
	local vehicleData, index = Utils.Find(profile.VehicleGarage, function(v) return v.Id == vehicleId end)
	if not vehicleData then return false, "Vehicle not found" end

	table.remove(profile.VehicleGarage, index)

	-- Add to hideout
	profile.HideoutVehicles = profile.HideoutVehicles or {}
	table.insert(profile.HideoutVehicles, vehicleData)

	return true, nil
end

function InventoryServer.RetrieveVehicleFromHideout(userId: number, vehicleId: string): (boolean, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, "Player not found" end

	-- Check garage space
	if #profile.VehicleGarage >= GetVehicleCapacity(userId) then
		return false, "Garage full"
	end

	local vehicleData, index = Utils.Find(profile.HideoutVehicles or {}, function(v) return v.Id == vehicleId end)
	if not vehicleData then return false, "Vehicle not in storage" end

	table.remove(profile.HideoutVehicles, index)
	table.insert(profile.VehicleGarage, vehicleData)

	return true, nil
end

function InventoryServer.GetHideoutVehicles(userId: number): { any }
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return {} end
	return profile.HideoutVehicles or {}
end

-- ============================================
-- PACKAGE VALUE DECAY
-- ============================================

--[[
	Update package values over time (for timed contracts, heat exposure, etc.)
	Called periodically by a server loop.
]]
function InventoryServer.UpdatePackageValues()
	for userId, profile in pairs(PlayerDataServer.GetAllProfiles()) do
		for _, package in ipairs(profile.Inventory) do
			-- Timed packages lose value over time
			if package.SpecialFlags and Utils.Contains(package.SpecialFlags, "Timed") then
				local age = os.time() - (package.PickedUpAt or package.SpawnedAt)
				local decayRate = 0.01 -- 1% per minute
				local decay = math.floor(package.BaseValue * decayRate * (age / 60))
				package.CurrentValue = math.max(1, package.CurrentValue - decay)
			end

			-- Hot packages gain heat exposure value bonus? No, they lose condition faster
			if package.SpecialFlags and Utils.Contains(package.SpecialFlags, "Hot") then
				-- Condition degrades faster when carried with high heat
				-- Handled in delivery session
			end
		end
	end
end

-- ============================================
-- WORLD PACKAGE MANAGEMENT (Server-side)
-- ============================================

local worldPackages = {} -- [packageId] = packageData

function AddWorldPackage(packageData: any)
	worldPackages[packageData.Id] = packageData
end

function RemoveWorldPackage(packageId: string)
	worldPackages[packageId] = nil
end

function FindWorldPackage(packageId: string): any?
	return worldPackages[packageId]
end

function GetWorldPackagesInDistrict(district: string): { any }
	local result = {}
	for _, pkg in pairs(worldPackages) do
		if pkg.District == district and pkg.IsInWorld then
			table.insert(result, pkg)
		end
	end
	return result
end

function GetAllWorldPackages(): { any }
	local result = {}
	for _, pkg in pairs(worldPackages) do
		if pkg.IsInWorld then
			table.insert(result, pkg)
		end
	end
	return result
end

-- ============================================
- PERIODIC CLEANUP
-- ============================================

task.spawn(function()
	while true do
		task.wait(60) -- Every minute
		InventoryServer.UpdatePackageValues()

		-- Clean up abandoned world packages (older than 10 minutes)
		local now = os.time()
		for id, pkg in pairs(worldPackages) do
			if pkg.IsInWorld and pkg.SpawnedAt and (now - pkg.SpawnedAt) > 600 then
				-- Despawn abandoned package
				worldPackages[id] = nil
			end
		end
	end
end)

Utils.DebugLog("InventoryServer initialized")

return InventoryServer