--[[
	UNDERGROUND — UI Controller
	Central UI management: screen transitions, HUD, theming, animations.
	Uses a custom UI framework built on Fusion/React-like patterns.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)

local UIController = {}

-- ============================================
- STATE
- ============================================

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local currentScreen = nil
local screenStack = {}
local screenInstances = {}
local isTransitioning = false

local hudElements = {}
local activeToasts = {}
local notificationQueue = {}

local theme = Constants.UITheme
local screenSize = Vector2.new(1920, 1080)

-- ============================================
- THEME HELPERS
- ============================================

local function GetColor(name: string): Color3
	return theme.Colors[name] or Color3.new(1, 1, 1)
end

local function GetFont(name: string): Enum.Font
	return theme.Fonts[name] or Enum.Font.GothamMedium
end

local function GetCorner(radius: string): UDim
	return theme.CornerRadius[radius] or UDim.new(0, 8)
end

local function GetSpacing(size: string): number
	return theme.Spacing[size] or 16
end

local function CreateTween(object: Instance, properties: { [string]: any }, duration: number?, easingStyle: Enum.EasingStyle?, easingDirection: Enum.EasingDirection?): Tween
	duration = duration or theme.Animation.Normal
	easingStyle = easingStyle or theme.Animation.Easing
	easingDirection = easingDirection or theme.Animation.EasingDirection

	local tweenInfo = TweenInfo.new(duration, easingStyle, easingDirection)
	return TweenService:Create(object, tweenInfo, properties)
end

-- ============================================
- BASE UI ELEMENT CREATORS
- ============================================

local function CreateFrame(properties: { [string]: any }, children: { Instance }?): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = properties.BackgroundColor3 or GetColor("Surface")
	frame.BackgroundTransparency = properties.BackgroundTransparency or 0
	frame.BorderSizePixel = 0
	frame.Size = properties.Size or UDim2.new(1, 0, 1, 0)
	frame.Position = properties.Position or UDim2.new(0, 0, 0, 0)
	frame.AnchorPoint = properties.AnchorPoint or Vector2.new(0, 0)
	frame.Name = properties.Name or "Frame"
	frame.Visible = properties.Visible ~= false
	frame.ZIndex = properties.ZIndex or 1
	frame.ClipsDescendants = properties.ClipsDescendants or false

	if properties.CornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = properties.CornerRadius
		corner.Parent = frame
	end

	if properties.Stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = properties.Stroke.Color or GetColor("Border")
		stroke.Thickness = properties.Stroke.Thickness or 1
		stroke.Transparency = properties.Stroke.Transparency or 0
		stroke.Parent = frame
	end

	if children then
		for _, child in ipairs(children) do
			child.Parent = frame
		end
	end

	return frame
end

local function CreateTextLabel(properties: { [string]: any }): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = properties.Text or ""
	label.TextColor3 = properties.TextColor3 or GetColor("TextPrimary")
	label.TextSize = properties.TextSize or 16
	label.Font = properties.Font or GetFont("Body")
	label.TextXAlignment = properties.TextXAlignment or Enum.TextXAlignment.Left
	label.TextYAlignment = properties.TextYAlignment or Enum.TextYAlignment.Center
	label.TextWrapped = properties.TextWrapped or false
	label.TextTruncate = properties.TextTruncate or Enum.TextTruncate.None
	label.Size = properties.Size or UDim2.new(1, 0, 0, 20)
	label.Position = properties.Position or UDim2.new(0, 0, 0, 0)
	label.Name = properties.Name or "Label"
	label.ZIndex = properties.ZIndex or 1
	label.TextTransparency = properties.TextTransparency or 0
	return label
end

local function CreateTextButton(properties: { [string]: any }): TextButton
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = properties.BackgroundColor3 or GetColor("Primary")
	button.BackgroundTransparency = properties.BackgroundTransparency or 0
	button.BorderSizePixel = 0
	button.Text = properties.Text or ""
	button.TextColor3 = properties.TextColor3 or GetColor("TextOnPrimary")
	button.TextSize = properties.TextSize or 16
	button.Font = properties.Font or GetFont("UI")
	button.Size = properties.Size or UDim2.new(0, 120, 0, 40)
	button.Position = properties.Position or UDim2.new(0, 0, 0, 0)
	button.Name = properties.Name or "Button"
	button.ZIndex = properties.ZIndex or 1
	button.AutoButtonColor = false

	local corner = Instance.new("UICorner")
	corner.CornerRadius = GetCorner("Medium")
	corner.Parent = button

	-- Hover/press effects
	local originalColor = button.BackgroundColor3
	local hoverColor = GetColor("PrimaryHover")
	local pressColor = GetColor("PrimaryPressed")

	button.MouseEnter:Connect(function()
		CreateTween(button, { BackgroundColor3 = hoverColor }, theme.Animation.Fast):Play()
	end)

	button.MouseLeave:Connect(function()
		CreateTween(button, { BackgroundColor3 = originalColor }, theme.Animation.Fast):Play()
	end)

	button.MouseButton1Down:Connect(function()
		CreateTween(button, { BackgroundColor3 = pressColor }, theme.Animation.Fast):Play()
	end)

	button.MouseButton1Up:Connect(function()
		CreateTween(button, { BackgroundColor3 = hoverColor }, theme.Animation.Fast):Play()
	end)

	return button
end

local function CreateIconButton(icon: string, properties: { [string]: any }): ImageButton
	local button = Instance.new("ImageButton")
	button.BackgroundColor3 = properties.BackgroundColor3 or GetColor("Surface")
	button.BackgroundTransparency = properties.BackgroundTransparency or 0
	button.BorderSizePixel = 0
	button.Image = properties.Image or icon
	button.ImageColor3 = properties.ImageColor3 or GetColor("TextPrimary")
	button.Size = properties.Size or UDim2.new(0, 40, 0, 40)
	button.Position = properties.Position or UDim2.new(0, 0, 0, 0)
	button.Name = properties.Name or "IconButton"
	button.ZIndex = properties.ZIndex or 1
	button.BackgroundTransparency = properties.BackgroundTransparency or 0.5

	local corner = Instance.new("UICorner")
	corner.CornerRadius = GetCorner("Round")
	corner.Parent = button

	-- Hover effect
	button.MouseEnter:Connect(function()
		CreateTween(button, { BackgroundTransparency = 0.2 }, theme.Animation.Fast):Play()
	end)

	button.MouseLeave:Connect(function()
		CreateTween(button, { BackgroundTransparency = 0.5 }, theme.Animation.Fast):Play()
	end)

	return button
end

-- ============================================
- SCREEN MANAGEMENT
- ============================================

local function CreateScreen(screenName: string, buildFunction: (Frame) -> ()): Frame
	local screen = Instance.new("ScreenGui")
	screen.Name = screenName
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.DisplayOrder = 10
	screen.Enabled = false
	screen.Parent = PlayerGui

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.Parent = screen

	buildFunction(container)

	return screen
end

function UIController.ShowScreen(screenName: string, data: any?): boolean
	if isTransitioning then return false end
	if currentScreen == screenName then return true end

	local screen = screenInstances[screenName]
	if not screen then
		warn("Screen not found:", screenName)
		return false
	end

	isTransitioning = true

	-- Hide current screen
	if currentScreen then
		local oldScreen = screenInstances[currentScreen]
		if oldScreen then
			local container = oldScreen.Container
			local tween = CreateTween(container, { BackgroundTransparency = 1 }, theme.Animation.Normal)
			tween:Play()
			tween.Completed:Wait()
			oldScreen.Enabled = false
		end
	end

	-- Show new screen
	screen.Enabled = true
	local container = screen.Container
	container.BackgroundTransparency = 1
	CreateTween(container, { BackgroundTransparency = 0 }, theme.Animation.Normal):Play()

	-- Call OnShow callback
	if screen.OnShow then
		screen.OnShow(data)
	end

	-- Update stack
	table.insert(screenStack, currentScreen)
	currentScreen = screenName

	isTransitioning = false
	return true
end

function UIController.HideCurrentScreen(): boolean
	if not currentScreen then return false end

	local screen = screenInstances[currentScreen]
	if not screen then return false end

	isTransitioning = true

	local container = screen.Container
	local tween = CreateTween(screen.Container, { BackgroundTransparency = 1 }, theme.Animation.Normal)
	tween:Play()
	tween.Completed:Wait()

	screen.Enabled = false

	-- Pop stack
	table.remove(screenStack)
	currentScreen = screenStack[#screenStack]

	if currentScreen then
		UIController.ShowScreen(currentScreen)
	end

	isTransitioning = false
	return true
end

function UIController.GetCurrentScreen(): string?
	return currentScreen
end

-- ============================================
- HUD MANAGEMENT
- ============================================

local function BuildHUD()
	local hud = Instance.new("ScreenGui")
	hud.Name = "HUD"
	hud.ResetOnSpawn = false
	hud.IgnoreGuiInset = true
	hud.DisplayOrder = 5
	hud.Parent = PlayerGui

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(1, 0, 1, 0)
	container.BackgroundTransparency = 1
	container.Parent = hud

	-- Top Bar: Speed, Gear, Fuel, Time
	local topBar = CreateFrame({
		Name = "TopBar",
		Size = UDim2.new(1, 0, 0, 60),
		Position = UDim2.new(0, 0, 0, 10),
		BackgroundColor3 = GetColor("Surface"),
		BackgroundTransparency = 0.2,
		CornerRadius = GetCorner("Large"),
		Stroke = { Color = GetColor("Border"), Thickness = 1 },
	}, {
		-- Speed
		CreateTextLabel({
			Name = "SpeedLabel",
			Text = "0",
			TextSize = 32,
			Font = GetFont("Mono"),
			TextColor3 = GetColor("TextPrimary"),
			Size = UDim2.new(0, 100, 1, 0),
			Position = UDim2.new(0, 20, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		CreateTextLabel({
			Name = "SpeedUnit",
			Text = "KM/H",
			TextSize = 14,
			Font = GetFont("Body"),
			TextColor3 = GetColor("TextSecondary"),
			Size = UDim2.new(0, 50, 1, 0),
			Position = UDim2.new(0, 120, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		-- Gear
		CreateTextLabel({
			Name = "GearLabel",
			Text = "N",
			TextSize = 24,
			Font = GetFont("Mono"),
			TextColor3 = GetColor("Primary"),
			Size = UDim2.new(0, 40, 1, 0),
			Position = UDim2.new(0.5, -20, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
		}),

		-- Fuel
		CreateFrame({
			Name = "FuelBar",
			Size = UDim2.new(0, 150, 0, 8),
			Position = UDim2.new(1, -170, 0.5, -4),
			BackgroundColor3 = GetColor("SurfaceHover"),
			CornerRadius = GetCorner("Round"),
		}, {
			CreateFrame({
				Name = "Fill",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundColor3 = GetColor("Primary"),
				CornerRadius = GetCorner("Round"),
			}),
			CreateTextLabel({
				Name = "FuelText",
				Text = "100%",
				TextSize = 10,
				Font = GetFont("Body"),
				TextColor3 = GetColor("TextSecondary"),
				Size = UDim2.new(1, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		}),

		-- Time
		CreateTextLabel({
			Name = "TimeLabel",
			Text = "12:00",
			TextSize = 16,
			Font = GetFont("Mono"),
			TextColor3 = GetColor("TextPrimary"),
			Size = UDim2.new(0, 80, 1, 0),
			Position = UDim2.new(1, -340, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})

	topBar.Parent = container

	-- Heat Indicator (Top Right)
	local heatIndicator = CreateFrame({
		Name = "HeatIndicator",
		Size = UDim2.new(0, 120, 0, 40),
		Position = UDim2.new(1, -130, 0, 80),
		BackgroundColor3 = GetColor("Surface"),
		BackgroundTransparency = 0.2,
		CornerRadius = GetCorner("Medium"),
		Stroke = { Color = GetColor("Border"), Thickness = 1 },
	}, {
		CreateTextLabel({
			Name = "HeatLabel",
			Text = "HEAT",
			TextSize = 12,
			Font = GetFont("UI"),
			TextColor3 = Color3.fromRGB(0, 255, 136),
			Size = UDim2.new(0, 40, 1, 0),
			Position = UDim2.new(0, 10, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		CreateFrame({
			Name = "Stars",
			Size = UDim2.new(0, 60, 0, 20),
			Position = UDim2.new(0, 55, 0.5, -10),
			BackgroundTransparency = 1,
		}),
	})

	heatIndicator.Parent = container

	-- Minimap (Bottom Right)
	local minimap = CreateFrame({
		Name = "Minimap",
		Size = UDim2.new(0, 200, 0, 200),
		Position = UDim2.new(1, -210, 1, -210),
		BackgroundColor3 = GetColor("Background"),
		BackgroundTransparency = 0.1,
		CornerRadius = GetCorner("Large"),
		Stroke = { Color = GetColor("Border"), Thickness = 2 },
		ClipsDescendants = true,
	}, {
		CreateFrame({
			Name = "MapView",
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = GetColor("Background"),
			BackgroundTransparency = 0,
			ClipsDescendants = true,
		}),

		CreateTextLabel({
			Name = "DistrictLabel",
			Text = "DOWNTOWN",
			TextSize = 12,
			Font = GetFont("UI"),
			TextColor3 = Color3.fromRGB(0, 255, 136),
			Size = UDim2.new(1, -20, 0, 20),
			Position = UDim2.new(0, 10, 0, 5),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})

	minimap.Parent = container

	-- Heat Stars (Bottom Left)
	local heatStars = CreateFrame({
		Name = "HeatStars",
		Size = UDim2.new(0, 150, 0, 40),
		Position = UDim2.new(0, 10, 1, -50),
		BackgroundTransparency = 1,
	}, {
		CreateTextLabel({
			Name = "HeatText",
			Text = "HEAT",
			TextSize = 14,
			Font = GetFont("UI"),
			TextColor3 = Color3.fromRGB(255, 215, 0),
			Size = UDim2.new(0, 40, 1, 0),
			Position = UDim2.new(0, 0, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})

	for i = 1, 5 do
		local star = CreateFrame({
			Name = "Star" .. i,
			Size = UDim2.new(0, 24, 0, 24),
			Position = UDim2.new(0, 45 + (i-1)*28, 0.5, -12),
			BackgroundColor3 = Color3.fromRGB(50, 50, 50),
			BackgroundTransparency = 0,
			CornerRadius = GetCorner("Small"),
		})
		star.Parent = heatStars
	end

	heatStars.Parent = container

	-- Active Contract (Bottom Center)
	local activeContract = CreateFrame({
		Name = "ActiveContract",
		Size = UDim2.new(0, 400, 0, 80),
		Position = UDim2.new(0.5, -200, 1, -90),
		BackgroundColor3 = GetColor("Surface"),
		BackgroundTransparency = 0.1,
		CornerRadius = GetCorner("Large"),
		Stroke = { Color = GetColor("Primary"), Thickness = 2 },
		Visible = false,
	}, {
		CreateTextLabel({
			Name = "ContractType",
			Text = "STANDARD RUN",
			TextSize = 14,
			Font = GetFont("UI"),
			TextColor3 = Color3.fromRGB(0, 255, 136),
			Size = UDim2.new(1, -20, 0, 20),
			Position = UDim2.new(0, 10, 0, 5),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		CreateTextLabel({
			Name = "ContractRoute",
			Text = "Downtown → Industrial",
			TextSize = 16,
			Font = GetFont("Body"),
			TextColor3 = GetColor("TextPrimary"),
			Size = UDim2.new(1, -20, 0, 20),
			Position = UDim2.new(0, 10, 0, 25),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		CreateFrame({
			Name = "ProgressBar",
			Size = UDim2.new(1, -20, 0, 8),
			Position = UDim2.new(0, 10, 1, -18),
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			CornerRadius = UDim.new(1, 0),
		}, {
			CreateFrame({
				Name = "Fill",
				Size = UDim2.new(0, 0, 1, 0),
				BackgroundColor3 = Color3.fromRGB(0, 255, 136),
				CornerRadius = UDim.new(1, 0),
			}),
		}),

		CreateTextLabel({
			Name = "DistanceText",
			Text = "2.4 km remaining",
			TextSize = 12,
			Font = GetFont("Body"),
			TextColor3 = GetColor("TextSecondary"),
			Size = UDim2.new(1, -20, 0, 20),
			Position = UDim2.new(0, 10, 0, 50),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})

	activeContract.Parent = container

	-- Package Status (Bottom Left)
	local packageStatus = CreateFrame({
		Name = "PackageStatus",
		Size = UDim2.new(0, 200, 0, 60),
		Position = UDim2.new(0, 10, 1, -150),
		BackgroundColor3 = Color3.fromRGB(0, 255, 136),
		BackgroundTransparency = 0.1,
		CornerRadius = GetCorner("Medium"),
		Stroke = { Color = Color3.fromRGB(0, 255, 136), Thickness = 2 },
		Visible = false,
	}, {
		CreateTextLabel({
			Name = "PackageType",
			Text = "PACKAGE: STANDARD",
			TextSize = 12,
			Font = GetFont("UI"),
			TextColor3 = Color3.fromRGB(0, 255, 136),
			Size = UDim2.new(1, -10, 0, 20),
			Position = UDim2.new(0, 10, 0, 5),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		CreateFrame({
			Name = "ConditionBar",
			Size = UDim2.new(1, -20, 0, 6),
			Position = UDim2.new(0, 10, 0.5, -3),
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			CornerRadius = UDim.new(1, 0),
		}, {
			CreateFrame({
				Name = "Fill",
				Size = UDim2.new(1, 0, 1, 0),
				BackgroundColor3 = Color3.fromRGB(0, 255, 136),
				CornerRadius = UDim.new(1, 0),
			}),
		}),

		CreateTextLabel({
			Name = "ConditionText",
			Text = "100%",
			TextSize = 12,
			Font = GetFont("Mono"),
			TextColor3 = Color3.fromRGB(0, 255, 136),
			Size = UDim2.new(1, -20, 0, 20),
			Position = UDim2.new(0, 10, 1, -20),
			TextXAlignment = Enum.TextXAlignment.Right,
		}),
	})

	packageStatus.Parent = container

	hudElements = {
		TopBar = topBar,
		HeatIndicator = heatIndicator,
		Minimap = minimap,
		HeatStars = heatStars,
		ActiveContract = activeContract,
		PackageStatus = packageStatus,
	}

	hud.Parent = PlayerGui
	return hud
end

-- ============================================
- HUD UPDATE FUNCTIONS
- ============================================

function UIController.UpdateSpeed(speed: number)
	local label = hudElements.TopBar and hudElements.TopBar:FindFirstChild("SpeedLabel")
	if label then
		label.Text = tostring(math.floor(speed))
	end
end

function UIController.UpdateGear(gear: number)
	local label = hudElements.TopBar and hudElements.TopBar:FindFirstChild("GearLabel")
	if label then
		local gearText = gear == 0 and "N" or (gear < 0 and "R" or tostring(gear))
		label.Text = gearText
		label.TextColor3 = gear == 0 and GetColor("TextSecondary") or (gear < 0 and GetColor("Danger") or GetColor("Primary"))
	end
end

function UIController.UpdateFuel(percent: number)
	local fuelBar = hudElements.TopBar and hudElements.TopBar:FindFirstChild("FuelBar")
	if fuelBar then
		local fill = fuelBar:FindFirstChild("Fill")
		local text = fuelBar:FindFirstChild("FuelText")
		if fill then
			CreateTween(fill, { Size = UDim2.new(percent/100, 0, 1, 0) }, theme.Animation.Normal):Play()
		end
		if text then
			text.Text = math.floor(percent) .. "%"
		end
	end
end

function UIController.UpdateTime(timeText: string)
	local label = hudElements.TopBar and hudElements.TopBar:FindFirstChild("TimeLabel")
	if label then
		label.Text = timeText
	end
end

function UIController.UpdateHeat(level: number, effects: any?)
	-- Update heat stars
	local heatStars = hudElements.HeatStars
	if heatStars then
		for i = 1, 5 do
			local star = heatStars:FindFirstChild("Star" .. i)
			if star then
				local isActive = i <= level
				local targetColor = i <= level and GetColor("Primary") or Color3.fromRGB(50, 50, 50)
				CreateTween(star, { BackgroundColor3 = targetColor }, theme.Animation.Normal):Play()
			end
		end
	end

	-- Update heat indicator
	local heatIndicator = hudElements.HeatIndicator
	if heatIndicator then
		local stars = heatIndicator:FindFirstChild("Stars")
		if stars then
			for i = 1, 5 do
				local star = stars:FindFirstChild("Star" .. i)
				if star then
					local isActive = i <= level
					local targetColor = isActive and GetColor("Primary") or Color3.fromRGB(50, 50, 50)
					CreateTween(star, { BackgroundColor3 = targetColor }, theme.Animation.Normal):Play()
				end
			end
		end
	end

	-- Apply screen effects
	if level > 0 then
		UIController.ApplyHeatEffects(level)
	else
		UIController.ClearHeatEffects()
	end
end

function UIController.ApplyHeatEffects(level: number)
	local effects = Constants.Heat.Effects[level]
	if not effects then return end

	-- Screen color grading
	local colorCorrection = Lighting:FindFirstChild("HeatColorCorrection")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "HeatColorCorrection"
		colorCorrection.Parent = Lighting
	end

	CreateTween(colorCorrection, {
		Saturation = -0.2 * level,
		Contrast = 0.1 * level,
		Brightness = -0.05 * level,
		TintColor = effects.HUDColor,
	}, theme.Animation.Slow):Play()

	-- Vignette
	local vignette = Lighting:FindFirstChild("HeatVignette")
	if not vignette then
		vignette = Instance.new("VignetteEffect")
		vignette.Name = "HeatVignette"
		vignette.Parent = Lighting
	end

	CreateTween(vignette, {
		Intensity = 0.3 * level,
		Size = 20 + level * 10,
	}, theme.Animation.Slow):Play()

	-- Screen shake (for high heat)
	if level >= 4 then
		UIController.ShakeScreen(0.5 * (level - 3))
	end
end

function UIController.ClearHeatEffects()
	local colorCorrection = Lighting:FindFirstChild("HeatColorCorrection")
	if colorCorrection then
		CreateTween(colorCorrection, {
			Saturation = 0,
			Contrast = 0,
			Brightness = 0,
			TintColor = Color3.new(1, 1, 1),
		}, theme.Animation.Slow):Play()
	end

	local vignette = Lighting:FindFirstChild("HeatVignette")
	if vignette then
		CreateTween(vignette, { Intensity = 0 }, theme.Animation.Slow):Play()
	end
end

function UIController.ShakeScreen(intensity: number)
	-- Camera shake would be implemented here
	-- Using Camera.CFrame manipulation
end

function UIController.ShowActiveContract(contractData: any)
	local frame = hudElements.ActiveContract
	if not frame then return end

	frame.Visible = true
	frame.ContractType.Text = contractData.Type or "CONTRACT"
	frame.ContractRoute.Text = (contractData.PickupDistrict or "?") .. " → " .. (contractData.DropoffDistrict or "?")
	frame.DistanceText.Text = string.format("%.1f km remaining", contractData.DistanceRemaining or 0)

	-- Animate in
	frame.Size = UDim2.new(0, 0, 0, 80)
	CreateTween(frame, { Size = UDim2.new(0, 400, 0, 80) }, theme.Animation.Normal, Enum.EasingStyle.Back):Play()
end

function UIController.HideActiveContract()
	local frame = hudElements.ActiveContract
	if frame and frame.Visible then
		CreateTween(frame, { Size = UDim2.new(0, 0, 0, 80) }, theme.Animation.Fast):Play()
		task.wait(theme.Animation.Fast)
		frame.Visible = false
	end
end

function UIController.UpdateContractProgress(progress: number) -- 0-1
	local frame = hudElements.ActiveContract
	if frame and frame.Visible then
		local fill = frame.ProgressBar:FindFirstChild("Fill")
		if fill then
			CreateTween(fill, { Size = UDim2.new(progress, 0, 1, 0) }, theme.Animation.Normal):Play()
		end
	end
end

function UIController.ShowPackageStatus(packageData: any)
	local frame = hudElements.PackageStatus
	if not frame then return end

	frame.Visible = true
	frame.PackageType.Text = "PACKAGE: " .. (packageData.Type or "STANDARD")
	frame.ConditionText.Text = math.floor(packageData.Condition or 100) .. "%"

	local fill = frame.ConditionBar:FindFirstChild("Fill")
	if fill then
		fill.Size = UDim2.new((packageData.Condition or 100) / 100, 0, 1, 0)
	end

	frame.Visible = true
end

function UIController.HidePackageStatus()
	local frame = hudElements.PackageStatus
	if frame then frame.Visible = false end
end

function UIController.UpdateMinimap(playerPosition: Vector3, districtId: string)
	local minimap = hudElements.Minimap
	if not minimap then return end

	local label = minimap:FindFirstChild("DistrictLabel")
	if label then
		label.Text = districtId:upper()
	end

	-- Update map view (would render actual minimap)
	-- This would use a ViewportFrame or ImageLabel with map texture
end

-- ============================================
- NOTIFICATIONS / TOASTS
- ============================================

function UIController.ShowToast(notificationData: any)
	local toast = CreateFrame({
		Name = "Toast_" .. Utils.GenerateID(),
		Size = UDim2.new(0, 350, 0, 80),
		Position = UDim2.new(1, -370, 1, -100 - #activeToasts * 90),
		BackgroundColor3 = GetColor("Surface"),
		BackgroundTransparency = 0.1,
		CornerRadius = GetCorner("Medium"),
		Stroke = { Color = GetColor("Border"), Thickness = 1 },
	}, {
		CreateTextLabel({
			Name = "Title",
			Text = notificationData.Title or "Notification",
			TextSize = 16,
			Font = GetFont("UI"),
			TextColor3 = GetColor("TextPrimary"),
			Size = UDim2.new(1, -20, 0, 24),
			Position = UDim2.new(0, 15, 0, 8),
			TextXAlignment = Enum.TextXAlignment.Left,
		}),

		CreateTextLabel({
			Name = "Message",
			Text = notificationData.Message or "",
			TextSize = 14,
			Font = GetFont("Body"),
			TextColor3 = GetColor("TextSecondary"),
			Size = UDim2.new(1, -20, 0, 40),
			Position = UDim2.new(0, 15, 0, 36),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
		}),

		CreateFrame({
			Name = "ProgressBar",
			Size = UDim2.new(1, 0, 0, 3),
			Position = UDim2.new(0, 0, 1, -3),
			BackgroundColor3 = GetColor("Primary"),
			BackgroundTransparency = 0,
			CornerRadius = UDim.new(0, 0),
		}),
	})

	table.insert(activeToasts, toast)
	toast.Parent = PlayerGui

	-- Animate in
	toast.Position = UDim2.new(1, 20, toast.Position.Y.Scale, toast.Position.Y.Offset)
	CreateTween(toast, { Position = UDim2.new(1, -370, toast.Position.Y.Scale, toast.Position.Y.Offset) }, theme.Animation.Normal, Enum.EasingStyle.Back):Play()

	-- Progress bar animation
	local progressBar = toast:FindFirstChild("ProgressBar")
	if progressBar then
		progressBar.Size = UDim2.new(1, 0, 0, 3)
		CreateTween(progressBar, { Size = UDim2.new(0, 0, 0, 3) }, notificationData.Duration or 5, Enum.EasingStyle.Linear):Play()
	end

	-- Auto-remove
	task.delay(notificationData.Duration or 5, function()
		UIController.RemoveToast(toast)
	end)

	table.insert(activeToasts, toast)
end

function UIController.RemoveToast(toast: Frame)
	local index = table.find(activeToasts, toast)
	if index then
		table.remove(activeToasts, index)

		-- Reposition remaining toasts
		for i, t in ipairs(activeToasts) do
			CreateTween(t, {
				Position = UDim2.new(1, -370, 1, -100 - (i-1) * 90)
			}, theme.Animation.Normal):Play()
		end

		CreateTween(toast, { Position = UDim2.new(1, 20, toast.Position.Y.Scale, toast.Position.Y.Offset) }, theme.Animation.Fast):Play()
		task.wait(theme.Animation.Fast)
		toast:Destroy()
	end
end

function UIController.ClearAllToasts()
	for _, toast in ipairs(activeToasts) do
		toast:Destroy()
	end
	activeToasts = {}
end

-- ============================================
- LEVEL UP / UNLOCK ANIMATIONS
- ============================================

function UIController.ShowLevelUp(level: number, unlocks: { string })
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LevelUpScreen"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 100
	screenGui.Parent = PlayerGui

	local frame = CreateFrame({
		Name = "LevelUpFrame",
		Size = UDim2.new(0, 500, 0, 300),
		Position = UDim2.new(0.5, -250, 0.5, -150),
		BackgroundColor3 = GetColor("Surface"),
		BackgroundTransparency = 0.1,
		CornerRadius = GetCorner("Large"),
		Stroke = { Color = GetColor("Primary"), Thickness = 3 },
	}, {
		CreateTextLabel({
			Name = "LevelUpText",
			Text = "LEVEL UP!",
			TextSize = 48,
			Font = GetFont("Primary"),
			TextColor3 = GetColor("Primary"),
			Size = UDim2.new(1, -40, 0, 60),
			Position = UDim2.new(0, 20, 0, 20),
			TextXAlignment = Enum.TextXAlignment.Center,
		}),

		CreateTextLabel({
			Name = "LevelNumber",
			Text = "LEVEL " .. tostring(level),
			TextSize = 72,
			Font = GetFont("Primary"),
			TextColor3 = GetColor("Accent"),
			Size = UDim2.new(1, -40, 0, 80),
			Position = UDim2.new(0, 20, 0, 80),
			TextXAlignment = Enum.TextXAlignment.Center,
		}),

		CreateFrame({
			Name = "UnlocksList",
			Size = UDim2.new(1, -40, 0, 120),
			Position = UDim2.new(0, 20, 0, 170),
			BackgroundTransparency = 1,
		}),
	})

	local unlocksList = frame:FindFirstChild("UnlocksList")
	for i, unlock in ipairs(unlocks) do
		local item = CreateFrame({
			Name = "UnlockItem",
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.new(0, 0, 0, (i-1) * 35),
			BackgroundTransparency = 1,
		}, {
			CreateTextLabel({
				Text = "✦ " .. unlock,
				TextSize = 18,
				Font = GetFont("UI"),
				TextColor3 = GetColor("TextPrimary"),
				Size = UDim2.new(1, 0, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Center,
			}),
		})
		item.Parent = unlocksList
	end

	frame.Parent = PlayerGui

	-- Animate in
	frame.Size = UDim2.new(0, 0, 0, 0)
	CreateTween(frame, { Size = UDim2.new(0, 500, 0, 300) }, theme.Animation.Slow, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()

	-- Auto-close
	task.delay(5, function()
		CreateTween(frame, { Size = UDim2.new(0, 0, 0, 0) }, theme.Animation.Normal):Play()
		task.wait(theme.Animation.Normal)
		screenGui:Destroy()
	end)
end

function UIController.ShowUnlock(unlockType: string, unlockId: string)
	local unlockNames = {
		Vehicle = "New Vehicle Unlocked",
		Upgrade = "Upgrade Available",
		District = "New District Unlocked",
		Contract = "New Contract Type",
		Livery = "New Livery Unlocked",
		Hideout = "Hideout Upgraded",
	}

	local title = unlockNames[unlockType] or "New Unlock"

	local toast = CreateFrame({
		Name = "UnlockToast",
		Size = UDim2.new(0, 400, 0, 100),
		Position = UDim2.new(0.5, -200, 0.2, 0),
		BackgroundColor3 = GetColor("Surface"),
		BackgroundTransparency = 0.1,
		CornerRadius = GetCorner("Large"),
		Stroke = { Color = GetColor("Accent"), Thickness = 3 },
	}, {
		CreateTextLabel({
			Text = "🔓 " .. title,
			TextSize = 24,
			Font = GetFont("Primary"),
			TextColor3 = GetColor("Accent"),
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.new(0, 20, 0, 10),
			TextXAlignment = Enum.TextXAlignment.Center,
		}),

		CreateTextLabel({
			Text = unlockId,
			TextSize = 18,
			Font = GetFont("Body"),
			TextColor3 = GetColor("TextPrimary"),
			Size = UDim2.new(1, -20, 0, 30),
			Position = UDim2.new(0, 20, 0, 45),
			TextXAlignment = Enum.TextXAlignment.Center,
		}),

		CreateFrame({
			Name = "Glow",
			Size = UDim2.new(1, 20, 1, 20),
			Position = UDim2.new(0, -10, 0, -10),
			BackgroundColor3 = GetColor("Accent"),
			BackgroundTransparency = 0.8,
			CornerRadius = GetCorner("Large"),
			ZIndex = -1,
		}),
	})

	toast.Parent = PlayerGui

	-- Animate
	toast.Position = UDim2.new(0.5, -200, -0.2, 0)
	CreateTween(toast, { Position = UDim2.new(0.5, -200, 0.2, 0) }, theme.Animation.Normal, Enum.EasingStyle.Back):Play()

	-- Pulse glow
	local glow = toast:FindFirstChild("Glow")
	if glow then
		task.spawn(function()
			while toast.Parent do
				CreateTween(glow, { BackgroundTransparency = 0.5 }, 1):Play()
				task.wait(1)
				CreateTween(glow, { BackgroundTransparency = 0.9 }, 1):Play()
				task.wait(1)
			end
		end)
	end

	task.delay(4, function()
		CreateTween(toast, { Position = UDim2.new(0.5, -200, -0.2, 0) }, theme.Animation.Normal):Play()
		task.wait(theme.Animation.Normal)
		toast:Destroy()
	end)
end

-- ============================================
- LOADING SCREEN
- ============================================

function UIController.ShowLoadingScreen(tip: string?)
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "LoadingScreen"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 200
	screenGui.Parent = PlayerGui

	local frame = CreateFrame({
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = GetColor("Background"),
		BackgroundTransparency = 0,
	}, {
		CreateTextLabel({
			Text = "UNDERGROUND",
			TextSize = 64,
			Font = GetFont("Primary"),
			TextColor3 = GetColor("Primary"),
			Size = UDim2.new(1, 0, 0, 80),
			Position = UDim2.new(0, 0, 0.4, -40),
			TextXAlignment = Enum.TextXAlignment.Center,
		}),

		CreateFrame({
			Name = "ProgressBar",
			Size = UDim2.new(0, 400, 0, 8),
			Position = UDim2.new(0.5, -200, 0.55, 0),
			BackgroundColor3 = Color3.fromRGB(30, 30, 30),
			CornerRadius = UDim.new(1, 0),
		}, {
			CreateFrame({
				Name = "Fill",
				Size = UDim2.new(0, 0, 1, 0),
				BackgroundColor3 = GetColor("Primary"),
				CornerRadius = UDim.new(1, 0),
			}),
		}),

		CreateTextLabel({
			Name = "TipText",
			Text = tip or "Loading city sectors...",
			TextSize = 16,
			Font = GetFont("Body"),
			TextColor3 = GetColor("TextSecondary"),
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.new(0, 0, 0.65, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
		}),

		CreateTextLabel({
			Name = "ProgressText",
			Text = "0%",
			TextSize = 14,
			Font = GetFont("Mono"),
			TextColor3 = GetColor("Primary"),
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.new(0, 0, 0.55, -30),
			TextXAlignment = Enum.TextXAlignment.Center,
		}),
	})

	frame.Parent = screenGui

	return {
		ScreenGui = screenGui,
		SetProgress = function(progress: number)
			local fill = frame.ProgressBar:FindFirstChild("Fill")
			if fill then
				CreateTween(fill, { Size = UDim2.new(progress, 0, 1, 0) }, 0.3):Play()
			end
			local text = frame:FindFirstChild("ProgressText")
			if text then text.Text = math.floor(progress * 100) .. "%" end
		end,
		SetTip = function(newTip: string)
			local tipLabel = frame:FindFirstChild("TipText")
			if tipLabel then tipLabel.Text = newTip end
		end,
		Close = function()
			CreateTween(frame, { BackgroundTransparency = 1 }, theme.Animation.Normal):Play()
			for _, child in ipairs(frame:GetDescendants()) do
				if child:IsA("TextLabel") or child:IsA("Frame") then
					CreateTween(child, { BackgroundTransparency = 1, TextTransparency = 1 }, theme.Animation.Normal):Play()
				end
			end
			task.wait(theme.Animation.Normal)
			screenGui:Destroy()
		end,
	}
end

function UIController.HideLoadingScreen(loadingScreen: any)
	if loadingScreen and loadingScreen.Close then
		loadingScreen.Close()
	end
end

-- ============================================
- SCREEN BUILDERS
- ============================================

function UIController.BuildMainMenu()
	return CreateScreen("MainMenu", function(container)
		-- Background
		local bg = Instance.new("ImageLabel")
		bg.Name = "Background"
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.Image = "rbxassetid://" -- City background
		bg.ScaleType = Enum.ScaleType.Crop
		bg.BackgroundColor3 = GetColor("Background")
		bg.Parent = container

		-- Overlay
		local overlay = CreateFrame({
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = GetColor("Background"),
			BackgroundTransparency = 0.3,
		})
		overlay.Parent = container

		-- Title
		CreateTextLabel({
			Text = "UNDERGROUND",
			TextSize = 72,
			Font = GetFont("Primary"),
			TextColor3 = GetColor("Primary"),
			Size = UDim2.new(1, 0, 0, 100),
			Position = UDim2.new(0, 0, 0.2, -50),
			TextXAlignment = Enum.TextXAlignment.Center,
		}).Parent = container

		CreateTextLabel({
			Text = "Operate the underground. Deliver the impossible.",
			TextSize = 20,
			Font = GetFont("Body"),
			TextColor3 = GetColor("TextSecondary"),
			Size = UDim2.new(1, 0, 0, 40),
			Position = UDim2.new(0, 0, 0.2, 30),
			TextXAlignment = Enum.TextXAlignment.Center,
		}).Parent = container

		-- Menu Buttons
		local buttonContainer = CreateFrame({
			Name = "ButtonContainer",
			Size = UDim2.new(0, 300, 0, 300),
			Position = UDim2.new(0.5, -150, 0.55, 0),
			BackgroundTransparency = 1,
		})
		buttonContainer.Parent = container

		local buttons = {
			{ Text = "START OPERATION", Action = "Play" },
			{ Text = "GARAGE", Action = "Garage" },
			{ Text = "HIDEOUT", Action = "Hideout" },
			{ Text = "LEADERBOARDS", Action = "Leaderboards" },
			{ Text = "SETTINGS", Action = "Settings" },
		}

		for i, btnData in ipairs(buttons) do
			local btn = CreateTextButton({
				Text = btnData.Text,
				Size = UDim2.new(1, 0, 0, 50),
				Position = UDim2.new(0, 0, 0, (i-1) * 60),
			})
			btn.Parent = buttonContainer

			btn.MouseButton1Click:Connect(function()
				Signals.GameSignals.MenuAction:Fire(btnData.Action)
			end)
		end

		-- Version
		CreateTextLabel({
			Text = "v" .. Constants.GAME.Version,
			TextSize = 12,
			Font = GetFont("Mono"),
			TextColor3 = GetColor("TextMuted"),
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.new(0, 0, 1, -30),
			TextXAlignment = Enum.TextXAlignment.Center,
		}).Parent = container
	end)

	container.OnShow = function()
		-- Play menu music
	end

	return container
end

function UIController.BuildGarageScreen()
	return CreateScreen("Garage", function(container)
		-- Garage implementation would go here
	end)
end

function UIController.BuildHideoutScreen()
	return CreateScreen("Hideout", function(container)
		-- Hideout implementation
	end)
end

function UIController.BuildLeaderboardsScreen()
	return CreateScreen("Leaderboards", function(container)
		-- Leaderboards implementation
	end)
end

function UIController.BuildSettingsScreen()
	return CreateScreen("Settings", function(container)
		-- Settings implementation
	end)
end

-- ============================================
- INITIALIZATION
- ============================================

function UIController.Initialize()
	Utils.DebugLog("UIController initializing...")

	-- Build all screens
	screenInstances.MainMenu = UIController.BuildMainMenu()
	screenInstances.Garage = UIController.BuildGarageScreen()
	screenInstances.Hideout = UIController.BuildHideoutScreen()
	screenInstances.Leaderboards = UIController.BuildLeaderboardsScreen()
	screenInstances.Settings = UIController.BuildSettingsScreen()

	-- Build HUD
	BuildHUD()

	-- Show main menu initially
	UIController.ShowScreen("MainMenu")

	-- Connect signals
	Signals.GameSignals.HeatChanged:Connect(function(userId, data)
		if userId == Players.LocalPlayer.UserId then
			UIController.UpdateHeat(data.Level, data.Effects)
		end
	end)

	Signals.GameSignals.OnHeatEffectUpdate:Connect(function(data)
		UIController.OnHeatEffectUpdate(data)
	end)

	Utils.DebugLog("UIController initialized")
end

function UIController.OnDataSynced(data: any)
	-- Update HUD with initial data
	if data.Profile then
		UIController.UpdateSpeed(0)
		UIController.UpdateGear(0)
		UIController.UpdateFuel(100)
	end
end

function UIController.OnHeatChanged(data: any)
	if data.Level then
		UIController.UpdateHeat(data.Level, data.Effects)
	end
end

function UIController.OnHeatEffectUpdate(data: any)
	UIController.ApplyHeatEffects(data.Level)
end

function UIController.Cleanup()
	ClearAllToasts()
	for _, screen in pairs(screenInstances) do
		screen:Destroy()
	end
	screenInstances = {}
	currentScreen = nil
	screenStack = {}
end

Utils.DebugLog("UIController initialized")

return UIController