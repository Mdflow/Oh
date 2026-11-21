--[[
	UNDERGROUND — Progression Client
	XP bar, level up animations, unlock notifications, prestige system, stats tracking.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)
local UIController = require(script.Parent.UIController)

local ProgressionClient = {}

-- ============================================
- STATE
- ============================================

local xpBar = nil
local levelLabel = nil
local prestigeLabel = nil
local statsPanel = nil

local currentXP = 0
local currentLevel = 1
local currentPrestige = 0
local xpForNextLevel = 0

local statWidgets = {}

-- ============================================
- XP BAR UI
- ============================================

function ProgressionClient.Initialize()
	Utils.DebugLog("ProgressionClient initializing...")

	ProgressionClient.BuildXPBar()
	ProgressionClient.BuildStatsPanel()

	-- Signals
	Signals.GameSignals.XPGained:Connect(function(amount, source)
		ProgressionClient.OnXPGained(amount, source)
	end)

	Signals.GameSignals.LevelUp:Connect(function(newLevel, unlocks)
		ProgressionClient.OnLevelUp(newLevel, unlocks)
	end)

	Signals.GameSignals.PrestigeUp:Connect(function(newPrestige, rewards)
		ProgressionClient.OnPrestigeUp(newPrestige, rewards)
	end)

	Signals.GameSignals.UnlockEarned:Connect(function(unlockType, unlockId)
		ProgressionClient.OnUnlockEarned(unlockType, unlockId)
	end)

	Utils.DebugLog("ProgressionClient initialized")
end

function ProgressionClient.BuildXPBar()
	-- XP Bar is part of HUD in UIController
	-- This function ensures references are set
	xpBar = UIController.hudElements and UIController.hudElements.TopBar and UIController.hudElements.TopBar:FindFirstChild("XPBar")
	levelLabel = UIController.hudElements and UIController.hudElements.TopBar and UIController.hudElements.TopBar:FindFirstChild("LevelLabel")
end

function ProgressionClient.BuildStatsPanel()
	-- Detailed stats panel (opened via menu)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StatsPanel"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 20
	screenGui.Enabled = false
	screenGui.Parent = Players.LocalPlayer.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "StatsFrame"
	frame.Size = UDim2.new(0, 600, 0, 500)
	frame.Position = UDim2.new(0.5, -300, 0.5, -250)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	frame.BackgroundTransparency = 0.05
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
		Text = "STATISTICS",
		TextSize = 28,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(0, 255, 136),
		Size = UDim2.new(1, -40, 0, 50),
		Position = UDim2.new(0, 20, 0, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = header,
	})

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "✕"
	closeBtn.TextSize = 20
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
	closeBtn.Size = UDim2.new(0, 40, 0, 40)
	closeBtn.Position = UDim2.new(1, -50, 0, 10)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Parent = header
	closeBtn.MouseButton1Click:Connect(function()
		ProgressionClient.CloseStatsPanel()
	end)

	-- Tabs
	local tabContainer = Instance.new("Frame")
	tabContainer.Name = "TabContainer"
	tabContainer.Size = UDim2.new(1, -40, 0, 40)
	tabContainer.Position = UDim2.new(0, 20, 0, 80)
	tabContainer.BackgroundTransparency = 1
	tabContainer.Parent = frame

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.Parent = tabContainer

	local tabs = { "Overview", "Deliveries", "Vehicles", "Combat", "Economy" }
	for _, tabName in ipairs({ "Overview", "Deliveries", "Vehicles", "Combat", "Economy" }) do
		local tab = Instance.new("TextButton")
		tab.Name = "Tab_" .. tabName
		tab.Text = tabName:upper()
		tab.TextSize = 12
		tab.Font = Enum.Font.GothamBold
		tab.TextColor3 = Color3.fromRGB(150, 150, 150)
		tab.Size = UDim2.new(0, 100, 1, 0)
		tab.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		tab.BackgroundTransparency = 0.5
		tab.BorderSizePixel = 0
		tab.Parent = tabContainer

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = UDim.new(0, 8)
		tabCorner.Parent = tab

		tab.MouseButton1Click:Connect(function()
			ProgressionClient.SwitchStatsTab(tabName)
		end)
	end

	-- Content area
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, -40, 1, -140)
	contentFrame.Position = UDim2.new(0, 20, 0, 130)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = frame

	-- Stats will be populated dynamically
	local statsContainer = Instance.new("ScrollingFrame")
	statsContainer.Name = "StatsContainer"
	statsContainer.Size = UDim2.new(1, 0, 1, 0)
	statsContainer.BackgroundTransparency = 1
	statsContainer.BorderSizePixel = 0
	statsContainer.ScrollBarThickness = 6
	statsContainer.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 136)
	statsContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
	statsContainer.Parent = contentFrame

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 16)
	listLayout.Parent = statsContainer

	statsContainer.Parent = contentFrame

	statsPanel = {
		ScreenGui = screenGui,
		Frame = frame,
		StatsContainer = statsContainer,
		CurrentTab = "Overview",
	}
end

function ProgressionClient.OpenStatsPanel()
	if statsPanel and statsPanel.ScreenGui then
		statsPanel.ScreenGui.Enabled = true
		ProgressionClient.RefreshStats()
	end
end

function ProgressionClient.CloseStatsPanel()
	if statsPanel and statsPanel.ScreenGui then
		statsPanel.ScreenGui.Enabled = false
	end
end

function ProgressionClient.ToggleStatsPanel()
	if statsPanel and statsPanel.ScreenGui then
		statsPanel.ScreenGui.Enabled = not statsPanel.ScreenGui.Enabled
		if statsPanel.ScreenGui.Enabled then
			ProgressionClient.RefreshStats()
		end
	end
end

function ProgressionClient.SwitchStatsTab(tabName: string)
	if not statsPanel or not statsPanel.Frame then return end

	-- Update tab highlights
	for _, child in ipairs(statsPanel.Frame.TabContainer:GetChildren()) do
		if child:IsA("TextButton") then
			local isActive = child.Name == "Tab_" .. tabName
			child.TextColor3 = isActive and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(150, 150, 150)
			child.BackgroundTransparency = isActive and 0.2 or 0.5
		end
	end

	ProgressionClient.RefreshStatsTab(tabName)
end

function ProgressionClient.RefreshStats()
	if not statsPanel then return end
	ProgressionClient.RefreshStatsTab(statsPanel.CurrentTab or "Overview")
end

function ProgressionClient.RefreshStatsTab(tabName: string)
	if not statsPanel or not statsPanel.StatsContainer then return end

	local container = statsPanel.StatsContainer
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local profile = _G.PlayerDataServer and _G.PlayerDataServer.GetProfile(Players.LocalPlayer.UserId)
	if not profile then return end

	if tabName == "Overview" then
		ProgressionClient.BuildOverviewStats(profile)
	elseif tabName == "Deliveries" then
		ProgressionClient.BuildDeliveryStats(profile)
	elseif tabName == "Vehicles" then
		ProgressionClient.BuildVehicleStats(profile)
	elseif tabName == "Combat" then
		ProgressionClient.BuildCombatStats(profile)
	elseif tabName == "Economy" then
		ProgressionClient.BuildEconomyStats(profile)
	end
end

function ProgressionClient.BuildOverviewStats(profile: any)
	local container = statsPanel.StatsContainer

	-- Level & XP
	ProgressionClient.CreateStatCard(container, "LEVEL", tostring(profile.Level), "⭐", Color3.fromRGB(255, 215, 0))
	ProgressionClient.CreateStatCard(container, "XP", ProgressionClient.FormatXP(profile.XP) .. " / " .. ProgressionClient.FormatXP(ProgressionClient.GetXPForNextLevel(profile.Level)), "⭐", Color3.fromRGB(0, 255, 136))
	ProgressionClient.CreateStatCard(container, "PRESTIGE", tostring(profile.Prestige), "✨", Color3.fromRGB(255, 215, 0))
	ProgressionClient.CreateStatCard(container, "CASH", "$" .. Utils.FormatCurrency(profile.Cash), "💰", Color3.fromRGB(0, 255, 136))

	-- Progress bar
	local xpForNext = ProgressionClient.GetXPForNextLevel(profile.Level)
	local xpProgress = profile.XP / xpForNext
	ProgressionClient.CreateProgressCard(container, "XP PROGRESS", xpProgress, profile.XP .. " / " .. ProgressionClient.FormatXP(xpForNext))

	-- Reputation
	ProgressionClient.CreateStatCard(container, "SYNDICATE REP", tostring(profile.SyndicateRep or 0), "🤝", Color3.fromRGB(255, 100, 0))
	ProgressionClient.CreateStatCard(container, "CORPORATE REP", tostring(profile.CorporateRep or 0), "🏢", Color3.fromRGB(0, 170, 255))
	ProgressionClient.CreateStatCard(container, "STREET REP", tostring(profile.StreetRep or 0), "🏙️", Color3.fromRGB(170, 0, 255))
end

function ProgressionClient.BuildDeliveryStats(profile: any)
	local container = statsPanel.StatsContainer

	ProgressionClient.CreateStatCard(container, "TOTAL DELIVERIES", tostring(profile.Stats.TotalDeliveries or 0), "📦", Color3.fromRGB(0, 255, 136))
	ProgressionClient.CreateStatCard(container, "SUCCESSFUL", tostring(profile.Stats.SuccessfulDeliveries or 0), "✅", Color3.fromRGB(0, 255, 136))
	ProgressionClient.CreateStatCard(container, "FAILED", tostring(profile.Stats.FailedDeliveries or 0), "❌", Color3.fromRGB(255, 50, 50))
	ProgressionClient.CreateStatCard(container, "SUCCESS RATE", string.format("%.1f%%", (profile.Stats.SuccessfulDeliveries or 0) / math.max(1, profile.Stats.TotalDeliveries) * 100), "📊", Color3.fromRGB(255, 215, 0))

	ProgressionClient.CreateStatCard(container, "TOTAL DISTANCE", Utils.FormatNumber(profile.Stats.TotalDistance or 0) .. "m", "📍", Color3.fromRGB(0, 255, 136))
	ProgressionClient.CreateStatCard(container, "PLAYTIME", Utils.FormatTime(profile.Stats.TotalPlaytime or 0), "⏱️", Color3.fromRGB(255, 215, 0))
	ProgressionClient.CreateStatCard(container, "LONGEST DELIVERY", Utils.FormatNumber(profile.Stats.LongestDelivery or 0) .. "m", "🏁", Color3.fromRGB(255, 215, 0))
	ProgressionClient.CreateStatCard(container, "BEST PAYOUT", "$" .. Utils.FormatCurrency(profile.Stats.MostValuableDelivery or 0), "💰", Color3.fromRGB(255, 215, 0))

	-- Contract type breakdown
	if profile.Stats.ContractsCompleted then
		for contractType, count in pairs(profile.Stats.ContractsCompleted) do
			ProgressionClient.CreateStatCard(container, contractType:upper() .. " RUNS", tostring(count), "📋", Color3.fromRGB(200, 200, 200))
		end
	end

	-- Package rarity breakdown
	if profile.Stats.PackagesDelivered then
		for rarity, count in pairs(profile.Stats.PackagesDelivered) do
			local rarityColors = {
				Common = Color3.fromRGB(170, 170, 170),
				Uncommon = Color3.fromRGB(0, 170, 255),
				Rare = Color3.fromRGB(170, 0, 255),
				Epic = Color3.fromRGB(255, 102, 0),
				Legendary = Color3.fromRGB(255, 215, 0),
			}
			ProgressionClient.CreateStatCard(container, rarity:upper() .. " PACKAGES", tostring(count), "📦", rarityColors[rarity] or Color3.fromRGB(170, 170, 170))
		end
	end
end

function ProgressionClient.BuildVehicleStats(profile: any)
	local container = statsPanel.StatsContainer

	ProgressionClient.CreateStatCard(container, "VEHICLES OWNED", tostring(profile.Stats.VehiclesOwned or 0), "🚗", Color3.fromRGB(0, 255, 136))

	if profile.VehicleGarage then
		for _, vehicle in ipairs(profile.VehicleGarage) do
			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, 0, 0, 80)
			card.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
			card.BackgroundTransparency = 0.1
			card.BorderSizePixel = 0
			card.Parent = container

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = card

			local categoryColor = Constants.GetVehicleCategory(vehicle.Category) and Constants.GetVehicleCategory(vehicle.Category).Color or Color3.fromRGB(170, 170, 170)

			local colorBar = Instance.new("Frame")
			colorBar.Size = UDim2.new(0, 4, 1, 0)
			colorBar.BackgroundColor3 = categoryColor
			colorBar.BorderSizePixel = 0
			colorBar.Parent = card

			Instance.new("TextLabel", {
				Text = vehicle.Category:upper() .. " - " .. (vehicle.ModelName or "UNKNOWN"),
				TextSize = 16,
				Font = Enum.Font.GothamBold,
				TextColor3 = Color3.new(1, 1, 1),
				Size = UDim2.new(1, -20, 0, 24),
				Position = UDim2.new(0, 15, 0, 10),
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				Parent = card,
			})

			Instance.new("TextLabel", {
				Text = "Level " .. (vehicle.Upgrades and Utils.TableLength(vehicle.Upgrades) or 0) .. " | " .. vehicle.TotalDistance .. "m",
				TextSize = 12,
				Font = Enum.Font.GothamMedium,
				TextColor3 = Color3.fromRGB(180, 180, 180),
				Size = UDim2.new(1, -20, 0, 20),
				Position = UDim2.new(0, 15, 0, 35),
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				Parent = card,
			})

			Instance.new("TextLabel", {
				Text = vehicle.TotalDeliveries .. " deliveries",
				TextSize = 12,
				Font = Enum.Font.GothamMedium,
				TextColor3 = Color3.fromRGB(150, 150, 150),
				Size = UDim2.new(1, -20, 0, 20),
				Position = UDim2.new(0, 15, 0, 55),
				TextXAlignment = Enum.TextXAlignment.Left,
				BackgroundTransparency = 1,
				Parent = card,
			})
		end
	end
end

function ProgressionClient.BuildCombatStats(profile: any)
	local container = statsPanel.StatsContainer

	ProgressionClient.CreateStatCard(container, "POLICE ESCAPES", tostring(profile.Stats.PoliceEscapes or 0), "🏃", Color3.fromRGB(0, 255, 136))
	ProgressionClient.CreateStatCard(container, "TIMES BUSTED", tostring(profile.Stats.PoliceCaught or 0), "🚔", Color3.fromRGB(255, 50, 50))
	ProgressionClient.CreateStatCard(container, "MAX HEAT REACHED", tostring(profile.Stats.MaxHeatReached or 0) .. "★", "🔥", Color3.fromRGB(255, 100, 0))

	local escapeRate = 0
	if (profile.Stats.PoliceEscapes or 0) + (profile.Stats.PoliceCaught or 0) > 0 then
		escapeRate = (profile.Stats.PoliceEscapes or 0) / ((profile.Stats.PoliceEscapes or 0) + (profile.Stats.PoliceCaught or 0)) * 100
	end
	ProgressionClient.CreateStatCard(container, "ESCAPE RATE", string.format("%.1f%%", escapeRate), "📊", Color3.fromRGB(255, 215, 0))
end

function ProgressionClient.BuildEconomyStats(profile: any)
	local container = statsPanel.StatsContainer

	ProgressionClient.CreateStatCard(container, "LIFETIME EARNINGS", "$" .. Utils.FormatCurrency(profile.LifetimeEarnings or 0), "💰", Color3.fromRGB(255, 215, 0))
	ProgressionClient.CreateStatCard(container, "CURRENT CASH", "$" .. Utils.FormatCurrency(profile.Cash or 0), "💵", Color3.fromRGB(0, 255, 136))
	ProgressionClient.CreateStatCard(container, "HIDEOUT TIER", profile.HideoutTier or "GARAGE", "🏠", Color3.fromRGB(255, 215, 0))
	ProgressionClient.CreateStatCard(container, "DAILY LOGIN STREAK", tostring(profile.DailyLoginStreak or 0) .. " days", "🔥", Color3.fromRGB(255, 100, 0))
end

function ProgressionClient.CreateStatCard(parent: Instance, label: string, value: string, icon: string, color: Color3)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 70)
	card.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card

	local colorBar = Instance.new("Frame")
	colorBar.Size = UDim2.new(0, 4, 1, 0)
	colorBar.BackgroundColor3 = color
	colorBar.BorderSizePixel = 0
	colorBar.Parent = card

	local iconLabel = Instance.new("TextLabel")
	iconLabel.Text = icon
	iconLabel.TextSize = 24
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextColor3 = color
	iconLabel.Size = UDim2.new(0, 50, 1, 0)
	iconLabel.Position = UDim2.new(0, 15, 0, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.TextXAlignment = Enum.TextXAlignment.Center
	iconLabel.Parent = card

	Instance.new("TextLabel", {
		Text = label,
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(150, 150, 150),
		Size = UDim2.new(1, -70, 0, 20),
		Position = UDim2.new(0, 70, 0, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = card,
	})

	Instance.new("TextLabel", {
		Text = value,
		TextSize = 20,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, -70, 0, 30),
		Position = UDim2.new(0, 70, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = card,
	})
end

function ProgressionClient.CreateProgressCard(parent: Instance, label: string, progress: number, detail: string)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 70)
	card.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	card.BackgroundTransparency = 0.1
	card.BorderSizePixel = 0
	card.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = card

	Instance.new("TextLabel", {
		Text = label,
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(0, 255, 136),
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.new(0, 15, 0, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = card,
	})

	local progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.Size = UDim2.new(1, -30, 0, 12)
	progressBar.Position = UDim2.new(0, 15, 0, 35)
	progressBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	progressBar.BorderSizePixel = 0
	progressBar.Parent = card

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(1, 0)
	barCorner.Parent = progressBar

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(math.clamp(progress, 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
	fill.BorderSizePixel = 0
	fill.Parent = progressBar

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	Instance.new("TextLabel", {
		Text = detail,
		TextSize = 12,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(180, 180, 180),
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.new(0, 15, 1, -25),
		TextXAlignment = Enum.TextXAlignment.Right,
		BackgroundTransparency = 1,
		Parent = card,
	})
end

-- ============================================
- XP / LEVEL HANDLING
- ============================================

function ProgressionClient.OnXPGained(amount: number, source: string?)
	-- Update XP bar
	if xpBar then
		-- Would update visual XP bar
	end

	-- Show floating XP text
	ProgressionClient.ShowFloatingXP(amount, source)
end

function ProgressionClient.OnLevelUp(newLevel: number, unlocks: { string })
	UIController.ShowLevelUp(newLevel, unlocks)

	-- Play level up sound
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" -- Level up sound
	sound.Volume = 0.5
	sound.Parent = game:GetService("SoundService")
	sound:Play()
	game:GetService("Debris"):AddItem(sound, 5)

	-- Update level label
	if levelLabel then
		levelLabel.Text = "LVL " .. newLevel
	end
end

function ProgressionClient.OnPrestigeUp(newPrestige: number, rewards: any)
	UIController.ShowToast({
		Type = "Success",
		Title = "PRESTIGE " .. newPrestige,
		Message = "Prestige achieved! New rewards unlocked.",
		Duration = 5,
	})

	if prestigeLabel then
		prestigeLabel.Text = "P" .. newPrestige
	end
end

function ProgressionClient.OnUnlockEarned(unlockType: string, unlockId: string)
	UIController.ShowUnlock(unlockType, unlockId)
end

function ProgressionClient.ShowFloatingXP(amount: number, source: string?)
	-- Floating XP text at center of screen
	local text = Instance.new("TextLabel")
	text.Text = "+" .. Utils.FormatNumber(amount) .. " XP"
	text.TextSize = 24
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.fromRGB(0, 255, 136)
	text.Size = UDim2.new(0, 200, 0, 40)
	text.Position = UDim2.new(0.5, -100, 0.3, 0)
	text.BackgroundTransparency = 1
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.new(0, 0, 0)
	text.Parent = Players.LocalPlayer.PlayerGui

	-- Animate
	text.Position = UDim2.new(0.5, -100, 0.4, 0)
	game:GetService("TweenService"):Create(text, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -100, 0.2, 0),
		TextTransparency = 1,
	}):Play()

	task.delay(1, function()
		text:Destroy()
	end)
end

-- ============================================
- HELPER FUNCTIONS
- ============================================

function ProgressionClient.FormatXP(xp: number): string
	if xp >= 1000000 then
		return string.format("%.1fM", xp / 1000000)
	elseif xp >= 1000 then
		return string.format("%.1fK", xp / 1000)
	else
		return tostring(xp)
	end
end

function ProgressionClient.GetXPForNextLevel(level: number): number
	if level <= 1 then return Constants.Progression.BaseXP end
	local xp = 0
	for i = 1, level do
		xp += Constants.Progression.BaseXP * (Constants.Progression.XPMultiplier ^ (i - 1))
	end
	return math.floor(xp)
end

function ProgressionClient.GetXPForNextLevel(level: number): number
	return Constants.Progression.BaseXP * (Constants.Progression.XPMultiplier ^ (level - 1))
end

function ProgressionClient.OpenStatsPanel()
	if statsPanel and statsPanel.ScreenGui then
		statsPanel.ScreenGui.Enabled = true
		ProgressionClient.RefreshStats()
	end
end

function ProgressionClient.CloseStatsPanel()
	if statsPanel and statsPanel.ScreenGui then
		statsPanel.ScreenGui.Enabled = false
	end
end

function ProgressionClient.ToggleStatsPanel()
	if statsPanel and statsPanel.ScreenGui then
		statsPanel.ScreenGui.Enabled = not statsPanel.ScreenGui.Enabled
		if statsPanel.ScreenGui.Enabled then
			ProgressionClient.RefreshStats()
		end
	end
end

function ProgressionClient.Cleanup()
	if statsPanel and statsPanel.ScreenGui then
		statsPanel.ScreenGui:Destroy()
	end
end

Utils.DebugLog("ProgressionClient initialized")

return ProgressionClient