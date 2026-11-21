--[[
	UNDERGROUND — Map Client
	Minimap rendering, GPS navigation, district tracking, and world markers.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)

local MapClient = {}

-- ============================================
- STATE
- ============================================

local minimapFrame = nil
local minimapViewport = nil
local minimapCamera = nil
local playerMarker = nil
local gpsMarker = nil
local poiMarkers = {}
local policeMarkers = {}
local districtBoundary = nil

local currentDistrict = "Residential"
local minimapScale = 1
local minimapRotation = 0
local followPlayer = true

local MAP_SIZE = 200 -- studs per pixel ratio
local MINIMAP_SIZE = 200 -- pixels

-- ============================================
- MINIMAP SETUP
- ============================================

function MapClient.Initialize()
	Utils.DebugLog("MapClient initializing...")

	-- Minimap is built in UIController, we just enhance it
	SetupMinimapCamera()
	SetupPlayerMarker()
	SetupDistrictBoundary()
	RegisterMarkers()

	-- Signals
	Signals.GameSignals.PoliceSpawned:Connect(function(unit)
		MapClient.OnPoliceSpawned(unit)
	end)

	Signals.GameSignals.PoliceDespawned:Connect(function(unitId)
		MapClient.OnPoliceDespawned(unitId)
	end)

	Signals.GameSignals.GPSWaypointUpdated:Connect(function(waypoint, index, total)
		MapClient.UpdateGPSMarker(waypoint, index, total)
	end)

	Signals.GameSignals.GPSArrivedAtDropoff:Connect(function()
		MapClient.OnArrivedAtDropoff()
	end)

	-- Update loop
	RunService.RenderStepped:Connect(function(dt)
		MapClient.UpdateMinimap(dt)
	end)

	Utils.DebugLog("MapClient initialized")
end

function MapClient.SetupMinimapCamera()
	-- The minimap uses a ViewportFrame with a camera
	minimapFrame = Players.LocalPlayer.PlayerGui:WaitForChild("HUD", 5)
	if not minimapFrame then return end

	minimapFrame = minimapFrame:WaitForChild("Container", 5)
	if not minimapFrame then return end

	minimapViewport = minimapFrame:WaitForChild("Minimap", 5)
	if not minimapViewport then return end

	minimapViewport = minimapViewport:FindFirstChild("MapView")
	if not minimapViewport then return end

	-- Create camera for minimap
	minimapCamera = Instance.new("Camera")
	minimapCamera.FieldOfView = 70
	minimapCamera.CameraType = Enum.CameraType.Scriptable
	minimapViewport.CurrentCamera = minimapCamera
	minimapCamera.Parent = minimapViewport

	-- Position camera above map center
	local mapCenter = Vector3.new(0, 500, 0)
	minimapCamera.CFrame = CFrame.new(mapCenter + Vector3.new(0, 800, 0), mapCenter)
end

function MapClient.SetupPlayerMarker()
	if not minimapViewport then return end

	-- Create player marker (arrow)
	playerMarker = Instance.new("ImageLabel")
	playerMarker.Name = "PlayerMarker"
	playerMarker.Size = UDim2.new(0, 24, 0, 24)
	playerMarker.BackgroundTransparency = 1
	playerMarker.Image = "rbxassetid://" -- Arrow icon
	playerMarker.ImageColor3 = Color3.fromRGB(0, 255, 136)
	playerMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	playerMarker.ZIndex = 10
	playerMarker.Parent = minimapViewport
end

function MapClient.SetupDistrictBoundary()
	if not minimapViewport then return end

	-- Draw district boundaries
	districtBoundary = Instance.new("Frame")
	districtBoundary.Name = "DistrictBoundary"
	districtBoundary.Size = UDim2.new(1, 0, 1, 0)
	districtBoundary.BackgroundTransparency = 1
	districtBoundary.Parent = minimapViewport

	-- Draw each district boundary
	for districtId, bounds in pairs(Constants.DistrictBounds or {}) do
		local boundary = Instance.new("Frame")
		boundary.Name = "Boundary_" .. districtId
		boundary.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
		boundary.BackgroundTransparency = 0.8
		boundary.BorderSizePixel = 1
		boundary.BorderColor3 = Color3.fromRGB(0, 255, 136)
		boundary.ZIndex = 5
		boundary.Parent = districtBoundary

		-- Position and size based on world bounds
		-- Would need to convert world coordinates to minimap coordinates
	end
end

function MapClient.RegisterMarkers()
	-- POI markers would be registered here
	poiMarkers = {}
	policeMarkers = {}
end

-- ============================================
- MINIMAP UPDATE
- ============================================

function MapClient.UpdateMinimap(dt: number)
	if not minimapViewport or not minimapCamera then return end

	local player = Players.LocalPlayer
	local character = player.Character
	if not character or not character.PrimaryPart then return end

	local playerPos = character.PrimaryPart.Position

	-- Update camera position (follow player)
	if followPlayer then
		local cameraHeight = 800
		local targetPos = character.PrimaryPart.Position + Vector3.new(0, 800, 0)
		minimapCamera.CFrame = minimapCamera.CFrame:Lerp(CFrame.new(targetPos, character.PrimaryPart.Position), 0.1)
	end

	-- Update player marker rotation
	if playerMarker then
		local character = Players.LocalPlayer.Character
		if character and character.PrimaryPart then
			local rotation = character.PrimaryPart.Orientation.Y
			playerMarker.Rotation = -rotation
		end
	end

	-- Update GPS marker
	-- Update POI markers
	-- Update police markers
end

-- ============================================
- GPS NAVIGATION
- ============================================

local gpsMarker = nil
local currentWaypointIndex = 1
local totalWaypoints = 0

function MapClient.UpdateGPSMarker(waypoint: Vector3, index: number, total: number)
	currentWaypointIndex = index
	totalWaypoints = total

	-- Update GPS marker on minimap
	if not gpsMarker then
		gpsMarker = Instance.new("ImageLabel")
		gpsMarker.Name = "GPSMarker"
		gpsMarker.Size = UDim2.new(0, 32, 0, 32)
		gpsMarker.BackgroundTransparency = 1
		gpsMarker.Image = "rbxassetid://" -- Flag/checkpoint icon
		gpsMarker.ImageColor3 = Color3.fromRGB(255, 215, 0)
		gpsMarker.AnchorPoint = Vector2.new(0.5, 0.5)
		gpsMarker.ZIndex = 15
		gpsMarker.Parent = minimapViewport
	end

	-- Convert world position to minimap position
	local screenPos = MapClient.WorldToMinimap(waypoint)
	if screenPos then
		gpsMarker.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
		gpsMarker.Visible = true
	end

	-- Update waypoint counter
	Signals.GameSignals.GPSWaypointIndexChanged:Fire(index, total)
end

function MapClient.OnArrivedAtDropoff()
	if gpsMarker then
		gpsMarker.Visible = false
	end

	-- Show arrival effect
	Signals.GameSignals.GPSArrivedAtDropoff:Fire()
end

function MapClient.UpdateGPSMarkerVisibility(visible: boolean)
	if gpsMarker then
		gpsMarker.Visible = visible
	end
end

-- ============================================
- POLICE MARKERS
- ============================================

function MapClient.OnPoliceSpawned(unit: any)
	local marker = Instance.new("ImageLabel")
	marker.Name = "PoliceMarker_" .. unit.Id
	marker.Size = UDim2.new(0, 16, 0, 16)
	marker.BackgroundTransparency = 1
	marker.Image = "rbxassetid://" -- Police car icon
	marker.ImageColor3 = Color3.fromRGB(0, 100, 255)
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.ZIndex = 8
	marker.Parent = minimapViewport

	policeMarkers[unit.Id] = marker

	-- Update position in update loop
end

function MapClient.OnPoliceDespawned(unitId: number)
	local marker = policeMarkers[unitId]
	if marker then
		marker:Destroy()
		policeMarkers[unitId] = nil
	end
end

-- ============================================
- POI MARKERS
- ============================================

function MapClient.AddPOIMarker(poiId: string, position: Vector3, icon: string, color: Color3)
	local marker = Instance.new("ImageLabel")
	marker.Name = "POIMarker_" .. poiId
	marker.Size = UDim2.new(0, 20, 0, 20)
	marker.BackgroundTransparency = 1
	marker.Image = "rbxassetid://" .. icon
	marker.ImageColor3 = color
	marker.AnchorPoint = Vector2.new(0.5, 0.5)
	marker.ZIndex = 6
	marker.Parent = minimapViewport

	local screenPos = MapClient.WorldToMinimap(position)
	if screenPos then
		marker.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
	end

	poiMarkers[poiId] = marker
end

function MapClient.RemovePOIMarker(poiId: string)
	local marker = poiMarkers[poiId]
	if marker then
		marker:Destroy()
		poiMarkers[poiId] = nil
	end
end

function MapClient.UpdatePOIMarker(poiId: string, position: Vector3)
	local marker = poiMarkers[poiId]
	if marker then
		local screenPos = MapClient.WorldToMinimap(position)
		if screenPos then
			marker.Position = UDim2.new(0, screenPos.X, 0, screenPos.Y)
		end
	end
end

-- ============================================
- COORDINATE CONVERSION
- ============================================

function MapClient.WorldToMinimap(worldPosition: Vector3): Vector2?
	if not minimapViewport then return nil end

	-- Get camera viewport size
	local viewportSize = minimapViewport.AbsoluteSize
	if viewportSize.X == 0 or viewportSize.Y == 0 then return nil end

	-- Convert world position to screen position
	local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(worldPosition)
	if not onScreen then return nil end

	-- Convert to minimap coordinates
	local minimapAbsPos = minimapViewport.AbsolutePosition
	local minimapAbsSize = minimapViewport.AbsoluteSize

	local relativeX = (screenPos.X - minimapAbsPos.X) / minimapAbsSize.X
	local relativeY = (screenPos.Y - minimapAbsPos.Y) / minimapAbsSize.Y

	-- Clamp to minimap bounds
	relativeX = math.clamp(relativeX, 0, 1)
	relativeY = math.clamp(relativeY, 0, 1)

	return Vector2.new(relativeX * minimapAbsSize.X, relativeY * minimapAbsSize.Y)
end

function MapClient.MinimapToWorld(minimapPosition: Vector2): Vector3?
	-- Reverse conversion
	return nil
end

-- ============================================
- DISTRICT TRACKING
- ============================================

function MapClient.GetCurrentDistrict(): string
	local character = Players.LocalPlayer.Character
	if not character or not character.PrimaryPart then return "Residential" end

	local position = character.PrimaryPart.Position
	return MapClient.GetDistrictForPosition(position)
end

function MapClient.GetDistrictForPosition(position: Vector3): string
	for districtId, bounds in pairs(Constants.DistrictBounds or {}) do
		if position.X >= bounds.Min.X and position.X <= bounds.Max.X and
		   position.Z >= bounds.Min.Z and position.Z <= bounds.Max.Z then
			return districtId
		end
	end
	return "Residential"
end

function MapClient.OnDistrictChanged(newDistrict: string, oldDistrict: string)
	currentDistrict = newDistrict

	-- Update UI
	Signals.GameSignals.DistrictChanged:Fire(newDistrict, oldDistrict)

	-- Update minimap boundary highlight
	UpdateDistrictHighlight(newDistrict)
end

function UpdateDistrictHighlight(districtId: string)
	if not districtBoundary then return end

	for _, child in ipairs(districtBoundary:GetChildren()) do
		if child:IsA("Frame") then
			local isActive = child.Name == "Boundary_" .. districtId
			child.BackgroundTransparency = isActive and 0.5 or 0.8
			child.BorderSizePixel = isActive and 2 or 1
		end
	end
end

-- ============================================
- FULL MAP SCREEN
- ============================================

function MapClient.OpenFullMap()
	-- Would open a full-screen map screen
	UIController.ShowScreen("FullMap")
end

function MapClient.CloseFullMap()
	UIController.HideCurrentScreen()
end

function MapClient.SetWaypoint(position: Vector3)
	-- Set custom waypoint for navigation
	Signals.GameSignals.CustomWaypointSet:Fire(position)
end

function MapClient.ClearWaypoint()
	Signals.GameSignals.CustomWaypointCleared:Fire()
end

-- ============================================
- ZOOM / PAN CONTROLS
- ============================================

local zoomLevel = 1
local MIN_ZOOM = 0.5
local MAX_ZOOM = 3

function MapClient.ZoomIn()
	zoomLevel = math.min(zoomLevel + 0.25, MAX_ZOOM)
	ApplyZoom()
end

function MapClient.ZoomOut()
	zoomLevel = math.max(zoomLevel - 0.25, MIN_ZOOM)
	ApplyZoom()
end

function MapClient.SetZoom(level: number)
	zoomLevel = math.clamp(level, MIN_ZOOM, MAX_ZOOM)
	ApplyZoom()
end

function ApplyZoom()
	if minimapCamera then
		minimapCamera.FieldOfView = 70 / zoomLevel
	end
end

function MapClient.ToggleFollowPlayer()
	followPlayer = not followPlayer
end

function MapClient.SetFollowPlayer(enabled: boolean)
	followPlayer = enabled
end

-- ============================================
- CLEANUP
- ============================================

function MapClient.Cleanup()
	if minimapCamera then minimapCamera:Destroy() end
	if playerMarker then playerMarker:Destroy() end
	if gpsMarker then gpsMarker:Destroy() end

	for _, marker in pairs(poiMarkers) do marker:Destroy() end
	for _, marker in pairs(policeMarkers) do marker:Destroy() end

	poiMarkers = {}
	policeMarkers = {}
end

Utils.DebugLog("MapClient initialized")

return MapClient