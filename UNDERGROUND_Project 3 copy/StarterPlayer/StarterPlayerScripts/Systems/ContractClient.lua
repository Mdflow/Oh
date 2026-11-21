--[[
	UNDERGROUND — Contract Client
	Manages contract board UI, delivery tracking, GPS navigation, and delivery flow.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)
local UIController = require(script.Parent.UIController)

local ContractClient = {}

-- ============================================
- STATE
- ============================================

local availableContracts = {} -- [districtId] = { ContractInstance }
local activeContract = nil
local deliverySession = nil
local contractBoardGui = nil
local gpsNavigation = nil

local currentDistrict = "Residential"
local gpsWaypoints = {}
local currentWaypointIndex = 1

local DELIVERY_UPDATE_RATE = 1/10 -- 10 Hz
local lastDeliveryUpdate = 0

-- ============================================
- CONTRACT BOARD UI
- ============================================

function ContractClient.BuildContractBoard()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ContractBoard"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 20
	screenGui.Enabled = false
	screenGui.Parent = Players.LocalPlayer.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "ContractBoardFrame"
	frame.Size = UDim2.new(1, -40, 1, -40)
	frame.Position = UDim2.new(0, 20, 0, 20)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 255, 136)
	stroke.Thickness = 2
	stroke.Transparency = 0.5
	stroke.Parent = frame

	-- Header
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 80)
	header.BackgroundTransparency = 1
	header.Parent = frame

	Instance.new("TextLabel", {
		Name = "Title",
		Text = "CONTRACT BOARD",
		TextSize = 32,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(0, 255, 136),
		Size = UDim2.new(1, -40, 0, 50),
		Position = UDim2.new(0, 20, 0, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = header,
	})

	Instance.new("TextLabel", {
		Name = "DistrictLabel",
		Text = "DISTRICT: DOWNTOWN",
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(180, 180, 180),
		Size = UDim2.new(1, -40, 0, 20),
		Position = UDim2.new(0, 20, 0, 55),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = header,
	})

	-- District tabs
	local tabContainer = Instance.new("Frame")
	tabContainer.Name = "TabContainer"
	tabContainer.Size = UDim2.new(1, -40, 0, 50)
	tabContainer.Position = UDim2.new(0, 20, 0, 90)
	tabContainer.BackgroundTransparency = 1
	tabContainer.Parent = frame

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.Parent = tabContainer

	local districts = { "Downtown", "Industrial", "Residential", "Commercial", "Warehouse", "UndergroundParking", "RestrictedZone" }
	for _, dist in ipairs(districts) do
		local tab = Instance.new("TextButton")
		tab.Name = "Tab_" .. dist
		tab.Text = dist:upper()
		tab.TextSize = 14
		tab.Font = Enum.Font.GothamBold
		tab.TextColor3 = Color3.fromRGB(150, 150, 150)
		tab.Size = UDim2.new(0, 120, 1, 0)
		tab.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		tab.BackgroundTransparency = 0.5
		tab.BorderSizePixel = 0
		tab.Parent = tabContainer

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, 8)
		tabCorner.Parent = tab

		tab.MouseButton1Click:Connect(function()
			ContractClient.SwitchDistrict(dist)
		end)
	end

	-- Contract list
	local listContainer = Instance.new("ScrollingFrame")
	listContainer.Name = "ContractList"
	listContainer.Size = UDim2.new(1, -40, 1, -160)
	listContainer.Position = UDim2.new(0, 20, 0, 150)
	listContainer.BackgroundTransparency = 1
	listContainer.BorderSizePixel = 0
	listContainer.ScrollBarThickness = 6
	listContainer.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 136)
	listContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	listContainer.Parent = frame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 12)
	listLayout.Parent = listContainer

	local padding = Instance.new("UIPadding")
	padding.PaddingBottom = UDim.new(0, 20)
	padding.Parent = listContainer

	contractBoardGui = {
		ScreenGui = screenGui,
		Frame = frame,
		ListContainer = listContainer,
		DistrictLabel = header.DistrictLabel,
		CurrentDistrict = "Downtown",
	}

	screenGui.Parent = Players.LocalPlayer.PlayerGui
	return screenGui
end

function ContractClient.SwitchDistrict(districtId: string)
	if not contractBoardGui then return end

	contractBoardGui.CurrentDistrict = districtId
	contractBoardGui.DistrictLabel.Text = "DISTRICT: " .. districtId:upper()

	-- Update tab highlights
	for _, child in ipairs(contractBoardGui.Frame.TabContainer:GetChildren()) do
		if child:IsA("TextButton") then
			local isActive = child.Name == "Tab_" .. districtId
			child.TextColor3 = isActive and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(150, 150, 150)
			child.BackgroundTransparency = isActive and 0.2 or 0.5
		end
	end

	-- Refresh contract list
	ContractClient.RefreshContractList()
end

function ContractClient.RefreshContractList()
	if not contractBoardGui then return end

	local list = contractBoardGui.ListContainer
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local contracts = availableContracts[contractBoardGui.CurrentDistrict] or {}
	for _, contract in ipairs(contracts) do
		ContractClient.CreateContractCard(contract)
	end
end

function ContractClient.CreateContractCard(contract: any)
	if not contractBoardGui then return end

	local list = contractBoardGui.ListContainer

	local card = Instance.new("Frame")
	card.Name = "ContractCard_" .. contract.Id
	card.Size = UDim2.new(1, 0, 0, 140)
	card.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = list

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 255, 136)
	stroke.Thickness = 1
	stroke.Transparency = 0.7
	stroke.Parent = card

	-- Rarity indicator
	local rarityColors = {
		Common = Color3.fromRGB(170, 170, 170),
		Uncommon = Color3.fromRGB(0, 170, 255),
		Rare = Color3.fromRGB(170, 0, 255),
		Epic = Color3.fromRGB(255, 102, 0),
		Legendary = Color3.fromRGB(255, 215, 0),
	}

	local rarityBar = Instance.new("Frame")
	rarityBar.Size = UDim2.new(0, 4, 1, 0)
	rarityBar.Position = UDim2.new(0, 0, 0, 0)
	rarityBar.BackgroundColor3 = rarityColors[contract.PackageRarity] or Color3.fromRGB(170, 170, 170)
	rarityBar.BorderSizePixel = 0
	rarityBar.Parent = card

	local rarityCorner = Instance.new("UICorner")
	rarityCorner.CornerRadius = UDim.new(0, 12)
	rarityCorner.Parent = rarityBar

	-- Contract type badge
	local typeBadge = Instance.new("TextLabel")
	typeBadge.Text = contract.Type:upper()
	typeBadge.TextSize = 10
	typeBadge.Font = Enum.Font.GothamBold
	typeBadge.TextColor3 = Color3.fromRGB(0, 255, 136)
	typeBadge.Size = UDim2.new(0, 100, 0, 20)
	typeBadge.Position = UDim2.new(0, 15, 0, 10)
	typeBadge.BackgroundTransparency = 1
	typeBadge.TextXAlignment = Enum.TextXAlignment.Left
	typeBadge.Parent = card

	-- Package rarity
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Text = contract.PackageRarity:upper()
	rarityLabel.TextSize = 10
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextColor3 = rarityColors[contract.PackageRarity] or Color3.fromRGB(170, 170, 170)
	rarityLabel.Size = UDim2.new(0, 80, 0, 20)
	rarityLabel.Position = UDim2.new(1, -95, 0, 10)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Right
	rarityLabel.Parent = card

	-- Route
	local routeLabel = Instance.new("TextLabel")
	routeLabel.Text = contract.PickupDistrict .. " → " .. contract.DropoffDistrict
	routeLabel.TextSize = 16
	routeLabel.Font = Enum.Font.GothamBold
	routeLabel.TextColor3 = Color3.new(1, 1, 1)
	routeLabel.Size = UDim2.new(1, -30, 0, 24)
	routeLabel.Position = UDim2.new(0, 15, 0, 35)
	routeLabel.TextXAlignment = Enum.TextXAlignment.Left
	routeLabel.BackgroundTransparency = 1
	routeLabel.Parent = card

	-- Distance & Time
	local infoFrame = Instance.new("Frame")
	infoFrame.Size = UDim2.new(1, -30, 0, 50)
	infoFrame.Position = UDim2.new(0, 15, 0, 60)
	infoFrame.BackgroundTransparency = 1
	infoLabel.Parent = card

	local infoLayout = Instance.new("UIListLayout")
	infoLayout.FillDirection = Enum.FillDirection.Horizontal
	infoLayout.Padding = UDim.new(0, 20)
	infoLayout.Parent = infoFrame

	local stats = {
		{ Label = "DISTANCE", Value = Utils.FormatNumber(contract.EstimatedDistance) .. "m", Icon = "📍" },
		{ Label = "TIME", Value = Utils.FormatTime(contract.EstimatedTime), Icon = "⏱️" },
		{ Label = "HEAT", Value = "+" .. contract.HeatGain .. "★", Icon = "🔥" },
		{ Label = "RISK", Value = string.rep("⚠", contract.RiskLevel), Icon = "⚠" },
	}

	for _, stat in ipairs(stats) do
		local statFrame = Instance.new("Frame")
		statFrame.Size = UDim2.new(0, 120, 1, 0)
		statFrame.BackgroundTransparency = 1
		statFrame.Parent = infoFrame

		Instance.new("TextLabel", {
			Text = stat.Icon .. " " .. stat.Label,
			TextSize = 10,
			Font = Enum.Font.GothamBold,
			TextColor3 = Color3.fromRGB(120, 120, 120),
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.new(0, 0, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 1,
			Parent = statFrame,
		})

		Instance.new("TextLabel", {
			Text = stat.Value,
			TextSize = 14,
			Font = Enum.Font.GothamBold,
			TextColor3 = Color3.new(1, 1, 1),
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.new(0, 0, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Center,
			BackgroundTransparency = 1,
			Parent = statFrame,
		})
	end

	-- Reward
	local rewardFrame = Instance.new("Frame")
	rewardFrame.Size = UDim2.new(0, 150, 0, 50)
	rewardFrame.Position = UDim2.new(1, -165, 0.5, -25)
	rewardFrame.BackgroundTransparency = 1
	rewardFrame.Parent = card

	Instance.new("TextLabel", {
		Text = "REWARD",
		TextSize = 10,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(120, 120, 120),
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.new(0, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 1,
		Parent = rewardFrame,
	})

	Instance.new("TextLabel", {
		Text = "$" .. Utils.FormatCurrency(contract.TotalReward) .. "  |  " .. contract.XPReward .. " XP",
		TextSize = 16,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 215, 0),
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.new(0, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 1,
		Parent = rewardFrame,
	})

	-- Accept button
	local acceptBtn = Instance.new("TextButton")
	acceptBtn.Text = "ACCEPT"
	acceptBtn.TextSize = 14
	acceptBtn.Font = Enum.Font.GothamBold
	acceptBtn.TextColor3 = Color3.new(0, 0, 0)
	acceptBtn.Size = UDim2.new(0, 120, 0, 40)
	acceptBtn.Position = UDim2.new(1, -165, 1, -50)
	acceptBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
	acceptBtn.BorderSizePixel = 0
	acceptBtn.Parent = card

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = acceptBtn

	acceptBtn.MouseButton1Click:Connect(function()
		ContractClient.RequestAcceptContract(contract.Id)
	end)

	-- Hover effects
	acceptBtn.MouseEnter:Connect(function()
		game:GetService("TweenService"):Create(acceptBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(0, 200, 100) }):Play()
	end)
	acceptBtn.MouseLeave:Connect(function()
		game:GetService("TweenService"):Create(acceptBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(0, 255, 136) }):Play()
	end)
end

-- ============================================
- CONTRACT BOARD VISIBILITY
- ============================================

function ContractClient.OpenContractBoard(districtId: string?)
	if not contractBoardGui then
		ContractClient.BuildContractBoard()
	end

	if districtId then
		ContractClient.SwitchDistrict(districtId)
	end

	contractBoardGui.ScreenGui.Enabled = true
	ContractClient.RefreshContractList()
end

function ContractClient.CloseContractBoard()
	if contractBoardGui then
		contractBoardGui.ScreenGui.Enabled = false
	end
end

function ContractClient.ToggleContractBoard()
	if contractBoardGui and contractBoardGui.ScreenGui.Enabled then
		ContractClient.CloseContractBoard()
	else
		ContractClient.OpenContractBoard()
	end
end

-- ============================================
- CONTRACT ACCEPTANCE
- ============================================

function ContractClient.RequestAcceptContract(contractId: string)
	-- Send to server
	local remote = game.ReplicatedStorage:FindFirstChild("Remotes", true)
	if remote then
		local acceptRemote = remote:FindFirstChild("AcceptContract")
		if acceptRemote then
			acceptRemote:FireServer(contractId)
		end
	end
end

function ContractClient.OnContractAccepted(contract: any, session: any)
	activeContract = contract
	deliverySession = session

	-- Close contract board
	ContractClient.CloseContractBoard()

	-- Start delivery
	ContractClient.StartDelivery(contract, session)

	-- Show active contract on HUD
	UIController.ShowActiveContract(contract)

	-- Show package status
	UIController.ShowPackageStatus({
		Type = contract.PackageType,
		Condition = 100,
	})

	-- Start GPS navigation
	ContractClient.StartGPSNavigation(contract)
end

function ContractClient.OnContractAdded(contract: any)
	availableContracts[contract.PickupDistrict] = availableContracts[contract.PickupDistrict] or {}
	table.insert(availableContracts[contract.PickupDistrict], contract)

	if contractBoardGui and contractBoardGui.CurrentDistrict == contract.PickupDistrict then
		ContractClient.CreateContractCard(contract)
	end
end

function ContractClient.OnContractUpdated(contractId: string, updates: any)
	for districtId, contracts in pairs(availableContracts) do
		for _, contract in ipairs(contracts) do
			if contract.Id == contractId then
				for key, value in pairs(updates) do
					contract[key] = value
				end
				break
			end
		end
	end

	if activeContract and activeContract.Id == contractId then
		for key, value in pairs(updates) do
			activeContract[key] = value
		end
	end
end

function ContractClient.OnContractRemoved(contractId: string)
	for districtId, contracts in pairs(availableContracts) do
		for i = #contracts, 1, -1 do
			if contracts[i].Id == contractId then
				table.remove(contracts, i)
				break
			end
		end
	end
end

-- ============================================
- DELIVERY TRACKING
- ============================================

function ContractClient.StartDelivery(contract: any, session: any)
	activeContract = contract
	deliverySession = session

	-- Initialize GPS
	ContractClient.StartGPSNavigation(contract)

	-- Start delivery update loop
	ContractClient.StartDeliveryUpdates()

	Signals.GameSignals.DeliveryStarted:Fire(contract, session)
end

function ContractClient.StartGPSNavigation(contract: any)
	-- Create GPS waypoints
	gpsWaypoints = contract.Waypoints or {}
	currentWaypointIndex = 1

	-- Show GPS on HUD
	UIController.UpdateMinimap(Vector3.new(0, 0, 0), contract.PickupDistrict)

	-- Set first waypoint as target
	ContractClient.UpdateGPSWaypoint()
end

function ContractClient.UpdateGPSWaypoint()
	if currentWaypointIndex > #gpsWaypoints then return end

	local waypoint = gpsWaypoints[currentWaypointIndex]
	-- Update GPS arrow/waypoint marker on minimap
	Signals.GameSignals.GPSWaypointUpdated:Fire(waypoint, currentWaypointIndex, #gpsWaypoints)
end

function ContractClient.OnWaypointReached()
	currentWaypointIndex += 1

	if currentWaypointIndex > #gpsWaypoints then
		-- At dropoff
		Signals.GameSignals.GPSArrivedAtDropoff:Fire()
	else
		ContractClient.UpdateGPSWaypoint()
	end
end

function ContractClient.StartDeliveryUpdates()
	task.spawn(function()
		while activeContract and deliverySession do
			task.wait(DELIVERY_UPDATE_RATE)

			if not activeContract or not deliverySession then break end

			-- Get vehicle data
			local vehicleData = _G.VehicleClient and _G.VehicleClient.GetVehicleData()
			if not vehicleData then continue end

			-- Calculate progress
			local progress = CalculateDeliveryProgress()

			-- Update session
			deliverySession.DistanceTraveled = CalculateDistanceTraveled()
			deliverySession.TimeElapsed = os.time() - (deliverySession.StartTime or os.time())
			deliverySession.CurrentCondition = GetPackageCondition()

			-- Send update to server
			ContractClient.SendDeliveryUpdate()

			-- Update UI
			UIController.UpdateContractProgress(progress)
		end
	end)
end

function ContractClient.SendDeliveryUpdate()
	local remote = game.ReplicatedStorage:FindFirstChild("Remotes", true)
	if remote then
		local updateRemote = remote:FindFirstChild("DeliveryProgress")
		if updateRemote and deliverySession then
			updateRemote:FireServer({
				DistanceTraveled = deliverySession.DistanceTraveled,
				TimeElapsed = deliverySession.TimeElapsed,
				CurrentHeat = deliverySession.CurrentHeat,
				CurrentCondition = deliverySession.CurrentCondition,
				RouteDeviations = deliverySession.RouteDeviations,
				SpeedViolations = deliverySession.SpeedViolations,
				Collisions = deliverySession.Collisions,
			})
		end
	end
end

function CalculateDeliveryProgress(): number
	if not activeContract or not gpsWaypoints or #gpsWaypoints == 0 then return 0 end

	-- Progress based on waypoint completion
	local waypointProgress = (currentWaypointIndex - 1) / #gpsWaypoints

	-- Add distance progress within current segment
	if currentWaypointIndex <= #gpsWaypoints then
		local currentWaypoint = gpsWaypoints[currentWaypointIndex]
		-- Would calculate distance to next waypoint
	end

	return math.clamp(progress, 0, 1)
end

function CalculateDistanceTraveled(): number
	-- Would track actual distance from GPS
	return 0
end

function GetPackageCondition(): number
	-- Get from InventoryServer or local tracking
	return 100
end

-- ============================================
- DELIVERY COMPLETION
- ============================================

function ContractClient.OnDeliveryComplete(rewards: any, contract: any)
	activeContract = nil
	deliverySession = nil

	-- Hide HUD elements
	UIController.HideActiveContract()
	UIController.HidePackageStatus()

	-- Show reward notification
	UIController.ShowToast({
		Type = "Success",
		Title = "DELIVERY COMPLETE",
		Message = "Earned $" .. Utils.FormatCurrency(rewards.cash) .. " and " .. rewards.xp .. " XP",
		Duration = 5,
	})

	-- Show level up if applicable
	if rewards.levelUp then
		UIController.ShowLevelUp(rewards.newLevel, rewards.unlocks)
	end

	Signals.GameSignals.DeliveryCompleted:Fire(rewards, contract)
end

function ContractClient.OnDeliveryFailed(reason: string)
	activeContract = nil
	deliverySession = nil

	UIController.HideActiveContract()
	UIController.HidePackageStatus()

	UIController.ShowToast({
		Type = "Error",
		Title = "DELIVERY FAILED",
		Message = reason,
		Duration = 5,
	})

	Signals.GameSignals.DeliveryFailed:Fire(reason)
end

function ContractClient.OnDeliveryProgress(session: any)
	deliverySession = session

	-- Update HUD
	local progress = CalculateDeliveryProgress()
	UIController.UpdateContractProgress(progress)

	-- Update package condition
	UIController.UpdatePackageStatus({
		Condition = session.CurrentCondition,
	})

	-- Update heat
	if session.CurrentHeat then
		UIController.UpdateHeat(session.CurrentHeat)
	end

	-- Check waypoint progression
	if session.CheckpointsPassed and #session.CheckpointsPassed > 0 then
		local lastCheckpoint = session.CheckpointsPassed[#session.CheckpointsPassed]
		if lastCheckpoint >= currentWaypointIndex then
			ContractClient.OnWaypointReached()
		end
	end
end

-- ============================================
- EVENTS
- ============================================

function ContractClient.OnEventStarted(event: any)
	-- Add event contracts to board
	if event.Contracts then
		for _, contract in ipairs(event.Contracts) do
			ContractClient.OnContractAdded(contract)
		end
	end
end

function ContractClient.OnEventEnded(eventId: string)
	-- Remove event contracts
end

function ContractClient.OnEventProgress(eventId: string, progress: number)
	-- Update event progress UI
end

function ContractClient.OnWeeklyChallengesUpdated(challenges: any)
	-- Update challenges UI
end

-- ============================================
- GPS NAVIGATION
- ============================================

function ContractClient.GetCurrentWaypoint(): Vector3?
	if currentWaypointIndex <= #gpsWaypoints then
		return gpsWaypoints[currentWaypointIndex]
	end
	return nil
end

function ContractClient.GetDistanceToNextWaypoint(): number?
	local waypoint = ContractClient.GetCurrentWaypoint()
	if not waypoint then return nil end

	-- Would calculate from player/vehicle position
	return 0
end

function ContractClient.GetEstimatedTimeToDropoff(): number
	if not activeContract then return 0 end
	return activeContract.EstimatedTime
end

-- ============================================
- INITIALIZATION
- ============================================

function ContractClient.Initialize()
	Utils.DebugLog("ContractClient initializing...")

	-- Build contract board UI
	ContractClient.BuildContractBoard()

	-- Connect signals
	Signals.GameSignals.ContractAccepted:Connect(function(contract, session)
		ContractClient.OnContractAccepted(contract, session)
	end)

	Signals.GameSignals.DeliveryComplete:Connect(function(rewards, contract)
		ContractClient.OnDeliveryComplete(rewards, contract)
	end)

	Signals.GameSignals.DeliveryFailed:Connect(function(reason)
		ContractClient.OnDeliveryFailed(reason)
	end)

	Signals.GameSignals.DeliveryProgress:Connect(function(session)
		ContractClient.OnDeliveryProgress(session)
	end)

	Signals.GameSignals.EventStarted:Connect(function(event)
		ContractClient.OnEventStarted(event)
	end)

	Signals.GameSignals.EventEnded:Connect(function(eventId)
		ContractClient.OnEventEnded(eventId)
	end)

	Signals.GameSignals.WeeklyChallengeUpdated:Connect(function(challenges)
		ContractClient.OnWeeklyChallengesUpdated(challenges)
	end)

	Utils.DebugLog("ContractClient initialized")
end

function ContractClient.OnDataSynced(data: any)
	if data.AvailableContracts then
		availableContracts = data.AvailableContracts
	end
	if data.ActiveContract then
		activeContract = data.ActiveContract
	end
	if data.DeliverySession then
		deliverySession = data.DeliverySession
	end
end

function ContractClient.Cleanup()
	activeContract = nil
	deliverySession = nil
	gpsWaypoints = {}
	currentWaypointIndex = 1

	if contractBoardGui then
		contractBoardGui.ScreenGui:Destroy()
		contractBoardGui = nil
	end
end

Utils.DebugLog("ContractClient initialized")

return ContractClient