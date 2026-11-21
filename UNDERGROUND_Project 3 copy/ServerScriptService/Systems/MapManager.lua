--[[
	UNDERGROUND — Map Manager
	Handles district streaming, POI registration, navigation mesh, and world state.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)

local MapManager = {}

-- ============================================
-- MAP STATE
-- ============================================

local districtBounds = {} -- [districtId] = { Min, Max }
local pointsOfInterest = {} -- [poiId] = POI
local navigationNodes = {} -- For pathfinding optimization
local packageSpawnPoints = {} -- [districtId] = { Vector3 }
local contractBoardLocations = {} -- [districtId] = { Vector3 }
local hideoutEntrances = {} -- [districtId] = { Vector3 }
local vehicleSpawnPoints = {} -- [districtId] = { Vector3 }
local policeStations = {} -- [districtId] = Vector3
local gasStations = {} -- [districtId] = { Vector3 }
local vehicleDealerships = {} -- [districtId] = { Vector3 }

local streamingEnabled = true

-- ============================================
-- DISTRICT BOUNDS
-- ============================================

-- Define district boundaries (in production, these would be read from map)
local DISTRICT_BOUNDS = {
	Downtown = {
		Min = Vector3.new(-200, -50, -200),
		Max = Vector3.new(200, 200, 200),
		Center = Vector3.new(0, 50, 0),
	},
	Industrial = {
		Min = Vector3.new(300, -50, 300),
		Max = Vector3.new(700, 100, 700),
		Center = Vector3.new(500, 25, 500),
	},
	Residential = {
		Min = Vector3.new(-700, -50, -700),
		Max = Vector3.new(-300, 100, -300),
		Center = Vector3.new(-500, 25, -500),
	},
	Commercial = {
		Min = Vector3.new(-200, -50, 300),
		Max = Vector3.new(200, 150, 700),
		Center = Vector3.new(0, 75, 500),
	},
	Warehouse = {
		Min = Vector3.new(-700, -50, 300),
		Max = Vector3.new(-300, 50, 700),
		Center = Vector3.new(-500, 0, 500),
	},
	UndergroundParking = {
		Min = Vector3.new(-200, -150, -200),
		Max = Vector3.new(200, -50, 200),
		Center = Vector3.new(0, -100, 0),
	},
	RestrictedZone = {
		Min = Vector3.new(800, -50, 800),
		Max = Vector3.new(1200, 100, 1200),
		Center = Vector3.new(1000, 25, 1000),
	},
}

function MapManager.Initialize()
	-- Register district bounds
	for districtId, bounds in pairs(DISTRICT_BOUNDS) do
		districtBounds[districtId] = {
			Min = bounds.Min,
			Max = bounds.Max,
			Center = bounds.Center,
		}
	end

	-- Initialize POI collections
	MapManager.RegisterDefaultPOIs()
	MapManager.RegisterSpawnPoints()

	Utils.DebugLog("MapManager initialized")
end

-- ============================================
- POINT OF INTEREST REGISTRATION
-- ============================================

function MapManager.RegisterDefaultPOIs()
	-- Contract Boards
	for _, districtId in ipairs(Constants.DistrictOrder) do
		local bounds = DISTRICT_BOUNDS[districtId]
		if bounds then
			local poiId = "ContractBoard_" .. districtId
			pointsOfInterest[poiId] = {
				Id = poiId,
				Type = "ContractBoard",
				District = districtId,
				Position = districtId == "Downtown" and Vector3.new(50, 10, 50) or Vector3.new(0, 10, 0), -- Relative to center
				DistrictCenter = DISTRICT_BOUNDS[districtId].Center,
				InteractDistance = 15,
				Data = { District = districtId },
			}

			contractBoardLocations[districtId] = DISTRICT_BOUNDS[districtId].Center + Vector3.new(50, 10, 50)
		end
	end

	-- Hideout Entrances
	for _, districtId in ipairs(Constants.DistrictOrder) do
		local poiId = "Hideout_" .. districtId
		pointsOfInterest[poiId] = {
			Id = poiId,
			Type = "HideoutEntrance",
			District = districtId,
			Position = Vector3.new(0, 0, -100), -- Relative
			DistrictCenter = DISTRICT_BOUNDS[districtId].Center,
			InteractDistance = 20,
			Data = { District = districtId },
		}

		hideoutEntrances[districtId] = DISTRICT_BOUNDS[districtId].Center + Vector3.new(0, 0, -100)
	end

	-- Vehicle Dealerships
	for _, districtId in ipairs(Constants.DistrictOrder) do
		if districtId == "Industrial" or districtId == "Downtown" then
			local poiId = "Dealership_" .. districtId
			pointsOfInterest[poiId] = {
				Id = poiId,
				Type = "VehicleDealership",
				District = districtId,
				Position = Vector3.new(-50, 10, -50),
				DistrictCenter = DISTRICT_BOUNDS[districtId].Center,
				InteractDistance = 20,
				Data = { District = districtId },
			}

			vehicleDealerships[districtId] = DISTRICT_BOUNDS[districtId].Center + Vector3.new(-50, 10, -50)
		end
	end

	-- Gas Stations
	for _, districtId in ipairs(Constants.DistrictOrder) do
		if districtId ~= "RestrictedZone" then
			local poiId = "GasStation_" .. districtId
			pointsOfInterest[poiId] = {
				Id = poiId,
				Type = "GasStation",
				District = districtId,
				Position = Vector3.new(100, 10, 100),
				DistrictCenter = DISTRICT_BOUNDS[districtId].Center,
				InteractDistance = 15,
				Data = { District = districtId },
			}

			gasStations[districtId] = DISTRICT_BOUNDS[districtId].Center + Vector3.new(100, 10, 100)
		end
	end

	-- Police Stations
	for _, districtId in ipairs(Constants.DistrictOrder) do
		if districtId ~= "UndergroundParking" then
			policeStations[districtId] = DISTRICT_BOUNDS[districtId].Center + Vector3.new(100, 10, 100)
		end
	end
end

function MapManager.RegisterSpawnPoints()
	-- Package spawn points per district
	for _, districtId in ipairs(Constants.DistrictOrder) do
		local bounds = DISTRICT_BOUNDS[districtId]
		if bounds then
			packageSpawnPoints[districtId] = {}

			-- Generate 20 spawn points per district
			for i = 1, 20 do
				local x = math.random(bounds.Min.X + 20, bounds.Max.X - 20)
				local z = math.random(bounds.Min.Z + 20, bounds.Max.Z - 20)
				local y = 10 -- Ground level

				table.insert(packageSpawnPoints[districtId], Vector3.new(x, 10, z))
			end
		end
	end

	-- Vehicle spawn points (near dealerships and hideouts)
	for _, districtId in ipairs(Constants.DistrictOrder) do
		vehicleSpawnPoints[districtId] = {}

		local bounds = DISTRICT_BOUNDS[districtId]
		if bounds then
			for i = 1, 10 do
				local angle = (i / 10) * math.pi * 2
				local radius = 50
				local center = DISTRICT_BOUNDS[districtId].Center
				local pos = center + Vector3.new(math.cos(i * 0.6) * radius, 10, math.sin(i * 0.6) * radius)
				table.insert(vehicleSpawnPoints[districtId], pos)
			end
		end
	end

	-- Player spawn points
	-- Default spawn in Residential (safe zone)
	-- Additional spawns unlocked per district
end

-- ============================================
- DISTRICT MANAGEMENT
-- ============================================

function MapManager.GetDistrictBounds(districtId: string): { Min: Vector3, Max: Vector3, Center: Vector3 }?
	return districtBounds[districtId]
end

function MapManager.GetDistrictForPosition(position: Vector3): string?
	for districtId, bounds in pairs(districtBounds) do
		if position.X >= bounds.Min.X and position.X <= bounds.Max.X and
		   position.Z >= bounds.Min.Z and position.Z <= bounds.Max.Z then
			return bounds -- Return the district data
		end
	end
	return "Residential" -- Default safe zone
end

function MapManager.GetDistrictCenter(districtId: string): Vector3?
	local bounds = districtBounds[districtId]
	return bounds and bounds.Center
end

function MapManager.IsPositionInDistrict(position: Vector3, districtId: string): boolean
	local bounds = districtBounds[districtId]
	if not bounds then return false end

	return position.X >= bounds.Min.X and position.X <= bounds.Max.X and
	       position.Z >= bounds.Min.Z and position.Z <= bounds.Max.Z
end

function MapManager.GetAllDistricts(): { string }
	return Constants.DistrictOrder
end

function MapManager.GetDistrictData(districtId: string): any
	return Constants.GetDistrict(districtId)
end

-- ============================================
- POINT OF INTEREST QUERIES
-- ============================================

function MapManager.GetPOIsInDistrict(districtId: string, poiType: string?): { any }
	local result = {}
	for _, poi in pairs(pointsOfInterest) do
		if poi.District == districtId and (not poiType or poi.Type == poiType) then
			table.insert(poi, poi)
		end
	end
	return result
end

function MapManager.GetNearestPOI(position: Vector3, poiType: string?, maxDistance: number?): any?
	maxDistance = maxDistance or 1000
	local nearest = nil
	local nearestDist = maxDistance

	for _, poi in pairs(pointsOfInterest) do
		if not poiType or poi.Type == poiType then
			local poiPos = poi.DistrictCenter + poi.Position
			local dist = (poiPos - position).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearest = poi
			end
		end
	end

	return nearest
end

function MapManager.GetContractBoardLocation(districtId: string): Vector3?
	return contractBoardLocations[districtId]
end

function MapManager.GetHideoutEntrance(districtId: string): Vector3?
	return hideoutEntrances[districtId]
end

function MapManager.GetVehicleDealership(districtId: string): Vector3?
	return vehicleDealerships[districtId]
end

function MapManager.GetGasStation(districtId: string): Vector3?
	return gasStations[districtId]
end

function MapManager.GetPoliceStation(districtId: string): Vector3?
	return policeStations[districtId]
end

function MapManager.GetVehicleSpawnPoint(districtId: string): Vector3?
	local points = vehicleSpawnPoints[districtId]
	if points and #points > 0 then
		return points[math.random(#points)]
	end
	return nil
end

function MapManager.GetPackageSpawnPoint(districtId: string): Vector3?
	local points = packageSpawnPoints[districtId]
	if points and #points > 0 then
		return points[math.random(#points)]
	end
	return nil
end

function MapManager.GetRandomPackageSpawnPoint(): Vector3?
	-- Pick random district, then random point
	local districtId = Constants.DistrictOrder[math.random(#Constants.DistrictOrder)]
	return MapManager.GetPackageSpawnPoint(districtId)
end

-- ============================================
- NAVIGATION / PATHFINDING
-- ============================================

local navigationGraph = {} -- Precomputed navigation graph

function MapManager.BuildNavigationGraph()
	-- Precompute navigation graph for faster pathfinding
	-- Nodes at intersections, POIs, and key locations
	navigationGraph = {}

	-- Add district centers as nodes
	for districtId, bounds in pairs(DISTRICT_BOUNDS) do
		table.insert(navigationGraph, {
			Id = "Center_" .. districtId,
			Position = bounds.Center,
			Type = "DistrictCenter",
			District = districtId,
			Connections = {},
		})
	end

	-- Add POIs as nodes
	for _, poi in pairs(pointsOfInterest) do
		table.insert(navigationGraph, {
			Id = poi.Id,
			Position = DISTRICT_BOUNDS[poi.District].Center + poi.Position,
			Type = poi.Type,
			District = poi.District,
			Connections = {},
		})
	end

	-- Build connections (simplified: connect nearby nodes)
	for i, nodeA in ipairs(navigationGraph) do
		for j = i + 1, #navigationGraph do
			local nodeB = navigationGraph[j]
			local dist = (nodeA.Position - nodeB.Position).Magnitude
			if dist < 500 then -- Connect if within 500 studs
				table.insert(nodeA.Connections, nodeB.Id)
				table.insert(navigationGraph[j].Connections, nodeA.Id)
			end
		end
	end
end

function MapManager.FindPath(startPos: Vector3, endPos: Vector3, agentRadius: number?): { Vector3 }?
	agentRadius = agentRadius or 3

	local path = PathfindingService:CreatePath({
		AgentRadius = agentRadius,
		AgentHeight = 5,
		AgentCanJump = true,
		AgentCanClimb = true,
		WaypointSpacing = 10,
	})

	local success = pcall(function()
		path:ComputeAsync(startPos, endPos)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		local positions = {}
		for _, wp in ipairs(waypoints) do
			table.insert(positions, wp.Position)
		end
		return positions
	end

	-- Fallback
	return { startPos, endPos }
end

function MapManager.GetStraightLineDistance(start: Vector3, endPos: Vector3): number
	return (endPos - start).Magnitude
end

function MapManager.GetRoadDistance(start: Vector3, endPos: Vector3): number
	local path = MapManager.FindPath(start, endPos)
	if not path or #path < 2 then
		return (endPos - start).Magnitude
	end

	local distance = 0
	for i = 2, #path do
		distance += (path[i] - path[i-1]).Magnitude
	end
	return distance
end

-- ============================================
- STREAMING / LOADING
-- ============================================

function MapManager.GetStreamingRegions(): { { Center: Vector3, Radius: number, District: string } }
	local regions = {}
	for districtId, bounds in pairs(DISTRICT_BOUNDS) do
		table.insert(regions, {
			Center = bounds.Center,
			Radius = math.max((bounds.Max.X - bounds.Min.X), (bounds.Max.Z - bounds.Min.Z)) / 2 + 100,
			District = districtId,
		})
	end
	return regions
end

function MapManager.ShouldStreamIn(position: Vector3, playerDistrict: string?): boolean
	-- Always stream player's current district + adjacent
	local currentDistrict = MapManager.GetDistrictForPosition(position)
	if not playerDistrict then return true end

	if currentDistrict == playerDistrict then return true end

	-- Check if adjacent
	local adjacentDistricts = MapManager.GetAdjacentDistricts(playerDistrict)
	for _, adj in ipairs(adjacentDistricts) do
		if adj == currentDistrict then return true end
	end

	return false
end

function MapManager.GetAdjacentDistricts(districtId: string): { string }
	local adjacency = {
		Downtown = { "Industrial", "Residential", "Commercial", "Warehouse", "UndergroundParking" },
		Industrial = { "Downtown", "Warehouse", "RestrictedZone" },
		Residential = { "Downtown", "UndergroundParking" },
		Commercial = { "Downtown", "Warehouse", "RestrictedZone" },
		Warehouse = { "Downtown", "Industrial", "Commercial", "RestrictedZone" },
		UndergroundParking = { "Downtown", "Residential" },
		RestrictedZone = { "Industrial", "Commercial", "Warehouse" },
	}
	return adjacency[districtId] or {}
end

-- ============================================
- PACKAGE SPAWNING
-- ============================================

function MapManager.SpawnPackagesForDistrict(districtId: string, count: number): { Vector3 }
	local points = packageSpawnPoints[districtId]
	if not points or #points == 0 then return {} end

	count = math.min(count, #points)
	local selected = {}
	local available = Utils.ShallowCopy(points)

	for i = 1, count do
		if #available == 0 then break end
		local idx = math.random(#available)
		table.insert(selected, available[idx])
		table.remove(available, idx)
	end

	return selected
end

function MapManager.GetPackageSpawnPointNear(position: Vector3, radius: number): Vector3?
	local districtId = MapManager.GetDistrictForPosition(position)
	if not districtId then return nil end

	local points = packageSpawnPoints[districtId]
	if not points then return nil end

	local nearest = nil
	local nearestDist = math.huge

	for _, point in ipairs(packageSpawnPoints[districtId]) do
		local dist = (point - position).Magnitude
		if dist < radius and dist < nearestDist then
			nearestDist = dist
			nearest = point
		end
	end

	return nearest
end

-- ============================================
- VEHICLE SPAWNING
-- ============================================

function MapManager.GetVehicleSpawnPoint(districtId: string, preferredType: string?): Vector3?
	local points = vehicleSpawnPoints[districtId]
	if not points or #points == 0 then return nil end

	-- Try to find spawn point appropriate for vehicle type
	-- For now, just return random
	return points[math.random(#points)]
end

function MapManager.GetPlayerSpawnPoint(districtId: string): Vector3?
	-- Safe spawn points per district
	local safeSpawns = {
		Residential = Vector3.new(-500, 15, -500),
		Downtown = Vector3.new(0, 20, 0),
		Industrial = Vector3.new(500, 15, 500),
		Commercial = Vector3.new(0, 20, 500),
		Warehouse = Vector3.new(-500, 10, 500),
		UndergroundParking = Vector3.new(0, -40, 0),
		RestrictedZone = Vector3.new(1000, 20, 1000),
	}

	return safeSpawns[districtId] or safeSpawns.Residential
end

-- ============================================
- EVENT LOCATIONS
-- ============================================

function MapManager.GetEventLocation(eventType: string): Vector3?
	-- Special locations for events
	local eventLocations = {
		StreetRace = {
			Vector3.new(-500, 10, -500), -- Residential loop
			Vector3.new(500, 10, 500),   -- Industrial straight
			Vector3.new(0, 10, 0),       -- Downtown circuit
		},
		TimeTrial = {
			Vector3.new(0, 10, 0),       -- Downtown
			Vector3.new(500, 10, 500),   -- Industrial
		},
		PackageDrop = {
			Vector3.new(-500, 10, -500),
			Vector3.new(500, 10, 500),
			Vector3.new(0, 10, 500),     -- Commercial
			Vector3.new(-500, 10, 500),  -- Warehouse
		},
		PoliceRaid = {
			Vector3.new(1000, 10, 1000), -- Restricted Zone
			Vector3.new(-500, 10, 500),  -- Warehouse
		},
	}

	local locations = eventLocations[eventType]
	if locations then
		return locations[math.random(#locations)]
	end
	return nil
end

-- ============================================
- WEATHER / TIME
-- ============================================

local currentWeather = "Clear"
local currentTimeOfDay = 12 -- 0-24

function MapManager.GetCurrentWeather(): string
	return currentWeather
end

function MapManager.SetWeather(weather: string)
	currentWeather = weather
	Signals.GameSignals.WeatherChanged:Fire(weather)
end

function MapManager.GetTimeOfDay(): number
	return currentTimeOfDay
end

function MapManager.SetTimeOfDay(hour: number)
	currentTimeOfDay = math.clamp(hour, 0, 24)
	Signals.GameSignals.TimeOfDayChanged:Fire(currentTimeOfDay)
end

function MapManager.IsNight(): boolean
	return currentTimeOfDay < 6 or currentTimeOfDay > 20
end

function MapManager.GetLightingSettings(): { [string]: any }
	local isNight = MapManager.IsNight()
	local weather = currentWeather

	return {
		Ambient = isNight and Color3.fromRGB(20, 20, 40) or Color3.fromRGB(100, 100, 100),
		OutdoorAmbient = isNight and Color3.fromRGB(10, 10, 30) or Color3.fromRGB(80, 80, 90),
		ColorShift_Top = isNight and Color3.fromRGB(0, 0, 50) or Color3.fromRGB(50, 50, 60),
		ColorShift_Bottom = isNight and Color3.fromRGB(50, 0, 0) or Color3.fromRGB(100, 80, 60),
		FogStart = weather == "Foggy" and 50 or 200,
		FogEnd = weather == "Foggy" and 200 or 1000,
		FogColor = Color3.fromRGB(50, 50, 70),
		Brightness = isNight and 0.5 or 2,
		ClockTime = currentTimeOfDay,
		GeographicLatitude = 40,
		EnvironmentDiffuseScale = 0.5,
		EnvironmentSpecularScale = 0.5,
	}
end

-- ============================================
- INITIALIZATION
-- ============================================

MapManager.Initialize()

-- Build navigation graph after a delay
task.spawn(function()
	task.wait(5)
	MapManager.BuildNavigationGraph()
end)

Utils.DebugLog("MapManager initialized")

return MapManager