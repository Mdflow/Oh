--[[
	UNDERGROUND — Settings Client
	Graphics, audio, controls, accessibility, and gameplay settings.
	Persists to player profile via DataStore.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)
local UIController = require(script.Parent.UIController)

local SettingsClient = {}

-- ============================================
- DEFAULT SETTINGS
- ============================================

local DEFAULT_SETTINGS = {
	Graphics = {
		Quality = "Auto", -- "Low", "Medium", "High", "Auto"
		VSync = true,
		FPSCap = 60,
		Shadows = true,
		ShadowQuality = "High", -- "Low", "Medium", "High"
		AmbientOcclusion = true,
		Bloom = true,
		DepthOfField = false,
		MotionBlur = false,
		AntiAliasing = "MSAA2x", -- "Off", "FXAA", "MSAA2x", "MSAA4x"
		TextureQuality = "High", -- "Low", "Medium", "High"
		ParticleQuality = "High", -- "Low", "Medium", "High"
		WaterQuality = "High", -- "Low", "Medium", "High"
		ViewDistance = 1000,
		GrassDetail = true,
	},

	Audio = {
		MasterVolume = 0.8,
		MusicVolume = 0.6,
		SFXVolume = 0.8,
		VoiceVolume = 0.5,
		AmbienceVolume = 0.5,
		UIVolume = 0.7,
		MuteOnFocusLost = true,
		DynamicRangeCompression = true,
	},

	Controls = {
		MouseSensitivity = 1.0,
		MouseInvertY = false,
		GamepadSensitivity = 1.0,
		GamepadInvertY = false,
		GamepadDeadzone = 0.15,
		GamepadVibration = true,
		GamepadLayout = "Default", -- "Default", "Southpaw", "Custom"
		KeyboardLayout = "QWERTY", -- "QWERTY", "AZERTY", "QWERTZ", "DVORAK"
		TouchSensitivity = 1.0,
		TouchDeadzone = 0.1,
		AutoSprint = false,
		ToggleCrouch = true,
		ToggleADS = false,
		VehicleCameraMode = "ThirdPerson", -- "FirstPerson", "ThirdPerson", "Cinematic"
		VehicleCameraDistance = 15,
		VehicleCameraHeight = 5,
		VehicleCameraAngle = 0,
		ShowControllerHints = true,
	},

	Gameplay = {
		AutoAcceptContracts = false,
		ShowDamageNumbers = true,
		ShowHeatWarnings = true,
		ShowXPFloaters = true,
		ShowDamageDirection = true,
		AutoRefuel = false,
		AutoRepair = false,
		ConfirmVehicleSale = true,
		ConfirmUpgradePurchase = true,
		ConfirmContractCancel = true,
		AutoCollectHideoutIncome = false,
		ShowOtherPlayers = true,
		ShowPlayerNames = true,
		ShowPlayerHealth = false,
		ShowVehicleNames = true,
		ColorblindMode = "Off", -- "Off", "Protanopia", "Deuteranopia", "Tritanopia"
		HighContrastMode = false,
		ReduceMotion = false,
		ScreenShake = true,
		CameraShake = true,
		HitMarkers = true,
		KillFeed = true,
		ShowMinimap = true,
		MinimapRotation = "NorthUp", -- "NorthUp", "HeadingUp"
		GPSVoiceGuidance = true,
		AutoGPS = true,
	},

	Interface = {
		UIScale = 1.0,
		HUDOpacity = 0.9,
		ChatOpacity = 0.8,
		FontSize = "Normal", -- "Small", "Normal", "Large", "ExtraLarge"
		FontStyle = "Gotham", -- "Gotham", "Roboto", "SourceSans"
		ShowFPS = false,
		ShowPing = false,
		ShowMemory = false,
		CompactMode = false,
		MinimapSize = "Normal", -- "Small", "Normal", "Large"
		MinimapRotation = "NorthUp", -- "NorthUp", "HeadingUp"
		ShowCompass = true,
		ShowCoordinates = false,
		TooltipDelay = 0.5,
		AnimationSpeed = "Normal", -- "Fast", "Normal", "Slow"
		ReducedTransparency = false,
		HighContrastUI = false,
		LargeText = false,
		ButtonHints = true,
		ContextualHints = true,
		TutorialHints = true,
	},

	Accessibility = {
		TextToSpeech = false,
		SpeechToText = false,
		Subtitles = true,
		SubtitleSize = "Normal",
		SubtitleBackground = true,
		ColorblindSupport = "Off",
		HighContrast = false,
		LargeText = false,
		ReduceMotion = false,
		ScreenReader = false,
		MonoAudio = false,
		VisualAlerts = true,
		HapticFeedback = true,
		OneHandedMode = false,
		AutoWalk = false,
		AutoDrive = false,
		SimplifiedControls = false,
		HoldToInteract = false,
		TapToInteract = true,
		DoubleTapToRun = false,
		AutoTargeting = false,
		AssistMode = false,
	},

	Network = {
		Region = "Auto",
		ShowPing = true,
		ShowPacketLoss = false,
		ShowPacketStats = false,
		AllowMobileData = true,
		CompressVoiceChat = true,
		VoiceChatEnabled = true,
		PushToTalk = false,
		VoiceActivationThreshold = 0.5,
		VoiceVolume = 1.0,
		MicVolume = 1.0,
	},
}

-- ============================================
- STATE
- ============================================

local currentSettings = Utils.DeepCopy(DEFAULT_SETTINGS)
local settingsUI = {}
local settingsScreenGui = nil

-- ============================================
- INITIALIZATION
- ============================================

function SettingsClient.Initialize()
	Utils.DebugLog("SettingsClient initializing...")

	SettingsClient.LoadSettings()
	SettingsClient.ApplyAllSettings()
	SettingsClient.BuildSettingsUI()

	-- Signals
	Signals.GameSignals.SettingsChanged:Connect(function(category: string, setting: string, value: any)
		SettingsClient.OnSettingChanged(category, setting, value)
	end)

	Utils.DebugLog("SettingsClient initialized")
end

function SettingsClient.LoadSettings()
	local remote = game.ReplicatedStorage:FindFirstChild("Remotes", true)
	if remote then
		local requestRemote = remote:FindFirstChild("RequestSettings")
		if requestRemote then
			local success, settings = pcall(function()
				return requestRemote:InvokeServer()
			end)
			if success and settings then
				currentSettings = Utils.DeepMerge(Utils.DeepCopy(DEFAULT_SETTINGS), settings)
			end
		end
	end
end

function SettingsClient.SaveSettings()
	local remote = game.ReplicatedStorage:FindFirstChild("Remotes", true)
	if remote then
		local saveRemote = remote:FindFirstChild("UpdateSettings")
		if saveRemote then
			saveRemote:FireServer(currentSettings)
		end
	end
end

function SettingsClient.ApplyAllSettings()
	SettingsClient.ApplyGraphicsSettings()
	SettingsClient.ApplyAudioSettings()
	SettingsClient.ApplyControlSettings()
	SettingsClient.ApplyGameplaySettings()
	SettingsClient.ApplyInterfaceSettings()
	SettingsClient.ApplyAccessibilitySettings()
	SettingsClient.ApplyNetworkSettings()
end

-- ============================================
- APPLY SETTINGS
- ============================================

function SettingsClient.ApplyGraphicsSettings()
	local g = currentSettings.Graphics

	-- Quality level
	if g.Quality == "Low" then
		settings().Rendering.QualityLevel = 1
	elseif g.Quality == "Medium" then
		settings().Rendering.QualityLevel = 5
	elseif g.Quality == "High" then
		settings().Rendering.QualityLevel = 10
	elseif g.Quality == "Auto" then
		-- Would detect device performance
		settings().Rendering.QualityLevel = 8
	end

	-- VSync
	settings().Rendering.VSync = g.VSync

	-- FPS Cap
	if g.FPSCap > 0 then
		setfpscap(g.FPSCap)
	else
		setfpscap(0) -- Unlimited
	end

	-- Shadows
	Lighting.GlobalShadows = g.Shadows
	if g.Shadows then
		if g.ShadowQuality == "Low" then
			Lighting.ShadowSoftness = 0.5
		elseif g.ShadowQuality == "Medium" then
			Lighting.ShadowSoftness = 0.25
		else
			Lighting.ShadowSoftness = 0.1
		end
	else
		Lighting.GlobalShadows = false
	end

	-- Post-processing
	Lighting.EnvironmentDiffuseScale = g.AmbientOcclusion and 0.5 or 0
	Lighting.EnvironmentSpecularScale = g.AmbientOcclusion and 0.5 or 0

	-- Bloom
	local bloom = Lighting:FindFirstChild("Bloom")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Name = "Bloom"
		bloom.Parent = Lighting
	end
	bloom.Enabled = g.Bloom
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 0.9

	-- Depth of Field
	local dof = Lighting:FindFirstChild("DepthOfField")
	if g.DepthOfField then
		if not dof then
			dof = Instance.new("DepthOfFieldEffect")
			dof.Name = "DepthOfField"
			dof.Parent = Lighting
		end
		dof.Enabled = true
		dof.FocusDistance = 50
		dof.InFocusRadius = 10
		dof.NearIntensity = 0.1
		dof.FarIntensity = 0.1
	else
		if dof then dof.Enabled = false end
	end

	-- Motion Blur
	local motionBlur = Lighting:FindFirstChild("MotionBlur")
	if g.MotionBlur then
		if not motionBlur then
			motionBlur = Instance.new("MotionBlurEffect")
			motionBlur.Name = "MotionBlur"
			motionBlur.Parent = Lighting
		end
		motionBlur.Enabled = true
		motionBlur.Size = 2
	else
		if motionBlur then motionBlur.Enabled = false end
	end

	-- Anti-aliasing (handled by Roblox engine)

	-- Texture quality handled by QualityLevel
end

function SettingsClient.ApplyAudioSettings()
	local a = currentSettings.Audio

	SoundService.Volume = a.MasterVolume

	-- Set sound groups
	for _, soundGroup in pairs(SoundService:GetDescendants()) do
		if soundGroup:IsA("SoundGroup") then
			if soundGroup.Name == "Music" then
				soundGroup.Volume = a.MusicVolume
			elseif soundGroup.Name == "SFX" then
				soundGroup.Volume = a.SFXVolume
			elseif soundGroup.Name == "Voice" then
				soundGroup.Volume = a.VoiceVolume
			elseif soundGroup.Name == "Ambience" then
				soundGroup.Volume = a.AmbienceVolume
			elseif soundGroup.Name == "UI" then
				soundGroup.Volume = a.UIVolume
			end
		end
	end

	-- Mute on focus lost
	game:GetService("RunService"):SetRobloxFocusLostBehavior(a.MuteOnFocusLost and Enum.FocusLostBehavior.Mute or Enum.FocusLostBehavior.None)
end

function SettingsClient.ApplyControlSettings()
	local c = currentSettings.Controls

	-- Mouse
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true

	-- Gamepad
	-- Handled by InputManager

	-- Vehicle camera
	-- Handled by VehicleClient
end

function SettingsClient.ApplyGameplaySettings()
	local g = currentSettings.Gameplay

	-- UIController settings would be applied here
	UIController.SetShowDamageNumbers(g.ShowDamageNumbers)
	UIController.SetShowHeatWarnings(g.ShowHeatWarnings)
	UIController.SetShowXPFloaters(g.ShowXPFloaters)
	UIController.SetCameraShake(g.CameraShake)
end

function SettingsClient.ApplyInterfaceSettings()
	local i = currentSettings.Interface

	-- UI Scale
	local screenGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, gui in ipairs(screenGui:GetDescendants()) do
		if gui:IsA("ScreenGui") then
			gui.ScreenInsets = i.UIScale == 1.0 and Enum.ScreenInsets.None or Enum.ScreenInsets.DeviceSafeInsets
		end
	end

	-- Font size
	-- Would apply to all text elements
end

function SettingsClient.ApplyAccessibilitySettings()
	local a = currentSettings.Accessibility

	-- Colorblind
	if a.ColorblindMode ~= "Off" then
		-- Apply color correction
		local cc = Lighting:FindFirstChild("ColorblindCorrection")
		if not cc then
			cc = Instance.new("ColorCorrectionEffect")
			cc.Name = "ColorblindCorrection"
			cc.Parent = Lighting
		end

		if a.ColorblindMode == "Protanopia" then
			cc.TintColor = Color3.fromRGB(255, 200, 150)
			cc.Saturation = -0.3
		elseif a.ColorblindMode == "Deuteranopia" then
			cc.TintColor = Color3.fromRGB(200, 255, 150)
			cc.Saturation = -0.3
		elseif a.ColorblindMode == "Tritanopia" then
			cc.TintColor = Color3.fromRGB(150, 200, 255)
			cc.Saturation = -0.3
		end
		cc.Enabled = true
	else
		local cc = Lighting:FindFirstChild("ColorblindCorrection")
		if cc then cc.Enabled = false end
	end

	-- High contrast
	if a.HighContrast then
		local cc = Lighting:FindFirstChild("HighContrastCorrection")
		if not cc then
			cc = Instance.new("ColorCorrectionEffect")
			cc.Name = "HighContrastCorrection"
			cc.Parent = Lighting
		end
		cc.Contrast = 0.5
		cc.Enabled = true
	else
		local cc = Lighting:FindFirstChild("HighContrastCorrection")
		if cc then cc.Enabled = false end
	end

	-- Reduce motion
	if a.ReduceMotion then
		-- Disable non-essential animations
	end
end

function SettingsClient.ApplyNetworkSettings()
	-- Network settings applied via Roblox engine
end

-- ============================================
- SETTINGS UI
- ============================================

function SettingsClient.BuildSettingsUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SettingsPanel"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 20
	screenGui.Enabled = false
	screenGui.Parent = Players.LocalPlayer.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "SettingsFrame"
	frame.Size = UDim2.new(0, 800, 0, 600)
	frame.Position = UDim2.new(0.5, -400, 0.5, -300)
	frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
	frame.BackgroundTransparency = 0.05
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = frame

	-- Header
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundTransparency = 1
	header.Parent = frame

	Instance.new("TextLabel", {
		Text = "SETTINGS",
		TextSize = 28,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(0, 255, 136),
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.new(0, 20, 0, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = header,
	})

	-- Category sidebar
	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	sidebar.Size = UDim2.new(0, 200, 1, -80)
	sidebar.Position = UDim2.new(0, 0, 0, 70)
	sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	sidebar.BackgroundTransparency = 0.5
	sidebar.BorderSizePixel = 0
	sidebar.Parent = frame

	local sidebarLayout = Instance.new("UIListLayout")
	sidebarLayout.Padding = UDim.new(0, 4)
	sidebarLayout.Parent = sidebar

	local sidebarPadding = Instance.new("UIPadding")
	sidebarPadding.PaddingTop = UDim.new(0, 10)
	sidebarPadding.PaddingLeft = UDim.new(0, 10)
	sidebarPadding.PaddingRight = UDim.new(0, 10)
	sidebarPadding.Parent = sidebar

	-- Content area
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, -220, 1, -80)
	contentFrame.Position = UDim2.new(0, 210, 0, 70)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = frame

	-- Categories
	local categories = {
		{ Id = "Graphics", Name = "GRAPHICS", Icon = "🎨" },
		{ Id = "Audio", Name = "AUDIO", Icon = "🔊" },
		{ Id = "Controls", Name = "CONTROLS", Icon = "🎮" },
		{ Id = "Gameplay", Name = "GAMEPLAY", Icon = "⚙️" },
		{ Id = "Interface", Name = "INTERFACE", Icon = "🖥️" },
		{ Id = "Accessibility", Name = "ACCESSIBILITY", Icon = "♿" },
		{ Id = "Network", Name = "NETWORK", Icon = "🌐" },
	}

	for _, cat in ipairs(categories) do
		local btn = Instance.new("TextButton")
		btn.Name = "Category_" .. cat.Id
		btn.Text = cat.Icon .. "  " .. cat.Name
		btn.TextSize = 14
		btn.Font = Enum.Font.GothamBold
		btn.TextColor3 = Color3.fromRGB(150, 150, 150)
		btn.Size = UDim2.new(1, -20, 0, 40)
		btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		btn.BackgroundTransparency = 0.5
		btn.BorderSizePixel = 0
		btn.Parent = sidebar

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = btn

		btn.MouseButton1Click:Connect(function()
			SettingsClient.SwitchCategory(cat.Id)
		end)
	end

	-- Apply/Reset buttons
	local buttonFrame = Instance.new("Frame")
	buttonFrame.Size = UDim2.new(1, -20, 0, 50)
	buttonFrame.Position = UDim2.new(0, 10, 1, -60)
	buttonFrame.BackgroundTransparency = 1
	buttonFrame.Parent = sidebar

	local btnLayout = Instance.new("UIListLayout")
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	btnLayout.Padding = UDim.new(0, 10)
	btnLayout.Parent = buttonFrame

	local applyBtn = Instance.new("TextButton")
	applyBtn.Text = "APPLY"
	applyBtn.TextSize = 14
	applyBtn.Font = Enum.Font.GothamBold
	applyBtn.TextColor3 = Color3.new(0, 0, 0)
	applyBtn.Size = UDim2.new(0, 100, 1, 0)
	applyBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
	applyBtn.BorderSizePixel = 0
	applyBtn.Parent = buttonFrame

	local applyCorner = Instance.new("UICorner")
	applyCorner.CornerRadius = UDim.new(0, 8)
	applyCorner.Parent = applyBtn

	applyBtn.MouseButton1Click:Connect(function()
		SettingsClient.ApplyAllSettings()
		SettingsClient.SaveSettings()
		UIController.ShowToast({
			Type = "Success",
			Title = "SETTINGS APPLIED",
			Message = "Your settings have been saved.",
			Duration = 3,
		})
	end)

	local resetBtn = Instance.new("TextButton")
	resetBtn.Text = "RESET TO DEFAULTS"
	resetBtn.TextSize = 14
	resetBtn.Font = Enum.Font.GothamBold
	resetBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
	resetBtn.Size = UDim2.new(0, 150, 1, 0)
	resetBtn.BackgroundColor3 = Color3.fromRGB(40, 30, 30)
	resetBtn.BorderSizePixel = 0
	resetBtn.Parent = buttonFrame

	local resetCorner = Instance.new("UICorner")
	resetCorner.CornerRadius = UDim.new(0, 8)
	resetCorner.Parent = resetBtn

	resetBtn.MouseButton1Click:Connect(function()
		SettingsClient.ResetToDefaults()
	end)

	-- Close button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Text = "✕"
	closeBtn.TextSize = 20
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
	closeBtn.Size = UDim2.new(0, 40, 0, 40)
	closeBtn.Position = UDim2.new(1, -50, 0, 10)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Parent = frame
	closeBtn.MouseButton1Click:Connect(function()
		SettingsClient.CloseSettings()
	end)

	settingsScreenGui = screenGui
	settingsUI = {
		ScreenGui = screenGui,
		Frame = frame,
		ContentFrame = contentFrame,
		CurrentCategory = "Graphics",
	}

	-- Build category panels
	SettingsClient.BuildCategoryPanels()

	screenGui.Parent = Players.LocalPlayer.PlayerGui
end

function SettingsClient.BuildCategoryPanels()
	if not settingsUI.ContentFrame then return end

	-- Graphics Panel
	SettingsClient.BuildGraphicsPanel()
	SettingsClient.BuildAudioPanel()
	SettingsClient.BuildControlsPanel()
	SettingsClient.BuildGameplayPanel()
	SettingsClient.BuildInterfacePanel()
	SettingsClient.BuildAccessibilityPanel()
	SettingsClient.BuildNetworkPanel()

	-- Show default
	SettingsClient.SwitchCategory("Graphics")
end

function SettingsClient.BuildGraphicsPanel()
	local container = SettingsClient.CreateCategoryPanel("Graphics")

	-- Quality preset
	SettingsClient.CreateDropdownSetting(container, "Graphics.Quality", "Quality Preset", {
		"Low", "Medium", "High", "Auto"
	}, "Auto")

	SettingsClient.CreateToggleSetting(container, "Graphics.VSync", "V-Sync", true)
	SettingsClient.CreateSliderSetting(container, "Graphics.FPSCap", "FPS Cap (0 = Unlimited)", 0, 240, 60)

	SettingsClient.CreateToggleSetting(container, "Graphics.Shadows", "Shadows", true)
	SettingsClient.CreateDropdownSetting(container, "Graphics.ShadowQuality", "Shadow Quality", {
		"Low", "Medium", "High"
	}, "High")

	SettingsClient.CreateToggleSetting(container, "Graphics.AmbientOcclusion", "Ambient Occlusion", true)
	SettingsClient.CreateToggleSetting(container, "Graphics.Bloom", "Bloom", true)
	SettingsClient.CreateToggleSetting(container, "Graphics.DepthOfField", "Depth of Field", false)
	SettingsClient.CreateToggleSetting(container, "Graphics.MotionBlur", "Motion Blur", false)
	SettingsClient.CreateDropdownSetting(container, "Graphics.AntiAliasing", "Anti-Aliasing", {
		"Off", "FXAA", "MSAA2x", "MSAA4x"
	}, "MSAA2x")

	SettingsClient.CreateDropdownSetting(container, "Graphics.TextureQuality", "Texture Quality", {
		"Low", "Medium", "High"
	}, "High")

	SettingsClient.CreateDropdownSetting(container, "Graphics.ParticleQuality", "Particle Quality", {
		"Low", "Medium", "High"
	}, "High")

	SettingsClient.CreateDropdownSetting(container, "Graphics.WaterQuality", "Water Quality", {
		"Low", "Medium", "High"
	}, "High")

	SettingsClient.CreateSliderSetting(container, "Graphics.ViewDistance", "View Distance", 100, 5000, 1000)
	SettingsClient.CreateToggleSetting(container, "Graphics.GrassDetail", "Grass Detail", true)
end

function SettingsClient.BuildAudioPanel()
	local container = SettingsClient.CreateCategoryPanel("Audio")

	SettingsClient.CreateSliderSetting(container, "Audio.MasterVolume", "Master Volume", 0, 1, 0.8, 0.05)
	SettingsClient.CreateSliderSetting(container, "Audio.MusicVolume", "Music Volume", 0, 1, 0.6, 0.05)
	SettingsClient.CreateSliderSetting(container, "Audio.SFXVolume", "SFX Volume", 0, 1, 0.8, 0.05)
	SettingsClient.CreateSliderSetting(container, "Audio.VoiceVolume", "Voice Volume", 0, 1, 0.5, 0.05)
	SettingsClient.CreateSliderSetting(container, "Audio.AmbienceVolume", "Ambience Volume", 0, 1, 0.5, 0.05)
	SettingsClient.CreateSliderSetting(container, "Audio.UIVolume", "UI Volume", 0, 1, 0.7, 0.05)

	SettingsClient.CreateToggleSetting(container, "Audio.MuteOnFocusLost", "Mute on Focus Lost", true)
	SettingsClient.CreateToggleSetting(container, "Audio.DynamicRangeCompression", "Dynamic Range Compression", true)
end

function SettingsClient.BuildControlsPanel()
	local container = SettingsClient.CreateCategoryPanel("Controls")

	SettingsClient.CreateSliderSetting(container, "Controls.MouseSensitivity", "Mouse Sensitivity", 0.1, 3, 1.0, 0.05)
	SettingsClient.CreateToggleSetting(container, "Controls.MouseInvertY", "Invert Mouse Y", false)
	SettingsClient.CreateSliderSetting(container, "Controls.GamepadSensitivity", "Gamepad Sensitivity", 0.1, 3, 1.0, 0.05)
	SettingsClient.CreateToggleSetting(container, "Controls.GamepadInvertY", "Invert Gamepad Y", false)
	SettingsClient.CreateSliderSetting(container, "Controls.GamepadDeadzone", "Gamepad Deadzone", 0, 0.5, 0.15, 0.01)
	SettingsClient.CreateToggleSetting(container, "Controls.GamepadVibration", "Gamepad Vibration", true)
	SettingsClient.CreateDropdownSetting(container, "Controls.GamepadLayout", "Gamepad Layout", {
		"Default", "Southpaw", "Custom"
	}, "Default")

	SettingsClient.CreateDropdownSetting(container, "Controls.KeyboardLayout", "Keyboard Layout", {
		"QWERTY", "AZERTY", "QWERTZ", "DVORAK"
	}, "QWERTY")

	SettingsClient.CreateSliderSetting(container, "Controls.TouchSensitivity", "Touch Sensitivity", 0.1, 2, 1.0, 0.05)
	SettingsClient.CreateSliderSetting(container, "Controls.TouchDeadzone", "Touch Deadzone", 0, 0.5, 0.1, 0.01)

	SettingsClient.CreateToggleSetting(container, "Controls.AutoSprint", "Auto Sprint", false)
	SettingsClient.CreateToggleSetting(container, "Controls.ToggleCrouch", "Toggle Crouch", true)
	SettingsClient.CreateToggleSetting(container, "Controls.ToggleADS", "Toggle ADS", false)

	SettingsClient.CreateDropdownSetting(container, "Controls.VehicleCameraMode", "Vehicle Camera", {
		"FirstPerson", "ThirdPerson", "Cinematic"
	}, "ThirdPerson")

	SettingsClient.CreateSliderSetting(container, "Controls.VehicleCameraDistance", "Vehicle Camera Distance", 5, 50, 15, 1)
	SettingsClient.CreateSliderSetting(container, "Controls.VehicleCameraHeight", "Vehicle Camera Height", 2, 20, 5, 1)
	SettingsClient.CreateSliderSetting(container, "Controls.VehicleCameraAngle", "Vehicle Camera Angle", -180, 180, 0, 1)

	SettingsClient.CreateToggleSetting(container, "Controls.ShowControllerHints", "Show Controller Hints", true)
end

function SettingsClient.BuildGameplayPanel()
	local container = SettingsClient.CreateCategoryPanel("Gameplay")

	SettingsClient.CreateToggleSetting(container, "Gameplay.AutoAcceptContracts", "Auto Accept Contracts", false)
	SettingsClient.CreateToggleSetting(container, "Gameplay.ShowDamageNumbers", "Show Damage Numbers", true)
	SettingsClient.CreateToggleSetting(container, "Gameplay.ShowHeatWarnings", "Show Heat Warnings", true)
	SettingsClient.CreateToggleSetting(container, "Gameplay.ShowXPFloaters", "Show XP Floaters", true)
	SettingsClient.CreateToggleSetting(container, "Gameplay.ShowDamageDirection", "Show Damage Direction", true)
	SettingsClient.CreateToggleSetting(container, "Gameplay.AutoRefuel", "Auto Refuel", false)
	SettingsClient.CreateToggleSetting(container, "Gameplay.AutoRepair", "Auto Repair", false)
	SettingsClient.CreateToggleSetting(container, "Gameplay.ConfirmVehicleSale", "Confirm Vehicle Sale", true)
	SettingsClient.CreateToggleSetting(container, "Gameplay.ConfirmUpgradePurchase", "Confirm Upgrade Purchase", true)
	SettingsClient.CreateToggleSetting(container, "Gameplay.ConfirmContractCancel", "Confirm Contract Cancel", true)
	SettingsClient.CreateToggleSetting(container, "Gameplay.AutoCollectHideoutIncome", "Auto Collect Hideout Income", false)

	SettingsClient.CreateToggleSetting(container, "Gameplay.ShowOtherPlayers", "Show Other Players", true)
	SettingsClient.CreateToggleSetting(container, "Gameplay.ShowPlayerNames", "Show Player Names", true)
	SettingsClient.CreateToggleSetting(container, "Gameplay.ShowPlayerHealth", "Show Player Health", false)
	SettingsClient.CreateToggleSetting(container, "Gameplay.ShowVehicleNames", "Show Vehicle Names", true)

	SettingsClient.CreateDropdownSetting(container, "Gameplay.ColorblindMode", "Colorblind Mode", {
		"Off", "Protanopia", "Deuteranopia", "Tritanopia"
	}, "Off")

	SettingsClient.CreateToggleSetting(container, "Gameplay.HighContrastMode", "High Contrast Mode", false)
	SettingsClient.CreateToggleSetting(container, "Gameplay.ReduceMotion", "Reduce Motion", false)
	SettingsClient.CreateToggleSetting(container, "Gameplay.ScreenShake", "Screen Shake", true)
	SettingsClient.CreateToggleSetting(container, "Gameplay.CameraShake", "Camera Shake", true)
	SettingsClient.CreateToggleSetting(container, "Gameplay.HitMarkers", "Hit Markers", true)
	SettingsClient.CreateToggleSetting(container, "Gameplay.KillFeed", "Kill Feed", true)

	SettingsClient.CreateToggleSetting(container, "Gameplay.ShowMinimap", "Show Minimap", true)
	SettingsClient.CreateDropdownSetting(container, "Gameplay.MinimapRotation", "Minimap Rotation", {
		"NorthUp", "HeadingUp"
	}, "NorthUp")

	SettingsClient.CreateToggleSetting(container, "Gameplay.GPSVoiceGuidance", "GPS Voice Guidance", true)
	SettingsClient.CreateToggleSetting(container, "Gameplay.AutoGPS", "Auto GPS", true)
end

function SettingsClient.BuildInterfacePanel()
	local container = SettingsClient.CreateCategoryPanel("Interface")

	SettingsClient.CreateSliderSetting(container, "Interface.UIScale", "UI Scale", 0.5, 2, 1.0, 0.05)
	SettingsClient.CreateSliderSetting(container, "Interface.HUDOpacity", "HUD Opacity", 0, 1, 0.9, 0.05)
	SettingsClient.CreateSliderSetting(container, "Interface.ChatOpacity", "Chat Opacity", 0, 1, 0.8, 0.05)
	SettingsClient.CreateDropdownSetting(container, "Interface.FontSize", "Font Size", {
		"Small", "Normal", "Large", "ExtraLarge"
	}, "Normal")
	SettingsClient.CreateDropdownSetting(container, "Interface.FontStyle", "Font Style", {
		"Gotham", "Roboto", "SourceSans"
	}, "Gotham")

	SettingsClient.CreateToggleSetting(container, "Interface.ShowFPS", "Show FPS", false)
	SettingsClient.CreateToggleSetting(container, "Interface.ShowPing", "Show Ping", false)
	SettingsClient.CreateToggleSetting(container, "Interface.ShowMemory", "Show Memory", false)
	SettingsClient.CreateToggleSetting(container, "Interface.CompactMode", "Compact Mode", false)
	SettingsClient.CreateDropdownSetting(container, "Interface.MinimapSize", "Minimap Size", {
		"Small", "Normal", "Large"
	}, "Normal")
	SettingsClient.CreateDropdownSetting(container, "Interface.MinimapRotation", "Minimap Rotation", {
		"NorthUp", "HeadingUp"
	}, "NorthUp")

	SettingsClient.CreateToggleSetting(container, "Interface.ShowCompass", "Show Compass", true)
	SettingsClient.CreateToggleSetting(container, "Interface.ShowCoordinates", "Show Coordinates", false)
	SettingsClient.CreateSliderSetting(container, "Interface.TooltipDelay", "Tooltip Delay", 0, 2, 0.5, 0.1)
	SettingsClient.CreateDropdownSetting(container, "Interface.AnimationSpeed", "Animation Speed", {
		"Fast", "Normal", "Slow"
	}, "Normal")

	SettingsClient.CreateToggleSetting(container, "Interface.ReducedTransparency", "Reduced Transparency", false)
	SettingsClient.CreateToggleSetting(container, "Interface.HighContrastUI", "High Contrast UI", false)
	SettingsClient.CreateToggleSetting(container, "Interface.LargeText", "Large Text", false)
	SettingsClient.CreateToggleSetting(container, "Interface.ButtonHints", "Button Hints", true)
	SettingsClient.CreateToggleSetting(container, "Interface.ContextualHints", "Contextual Hints", true)
	SettingsClient.CreateToggleSetting(container, "Interface.TutorialHints", "Tutorial Hints", true)
end

function SettingsClient.BuildAccessibilityPanel()
	local container = SettingsClient.CreateCategoryPanel("Accessibility")

	SettingsClient.CreateToggleSetting(container, "Accessibility.TextToSpeech", "Text to Speech", false)
	SettingsClient.CreateToggleSetting(container, "Accessibility.SpeechToText", "Speech to Text", false)
	SettingsClient.CreateToggleSetting(container, "Accessibility.Subtitles", "Subtitles", true)
	SettingsClient.CreateDropdownSetting(container, "Accessibility.SubtitleSize", "Subtitle Size", {
		"Small", "Normal", "Large"
	}, "Normal")
	SettingsClient.CreateToggleSetting(container, "Accessibility.SubtitleBackground", "Subtitle Background", true)
	SettingsClient.CreateDropdownSetting(container, "Accessibility.ColorblindSupport", "Colorblind Support", {
		"Off", "Protanopia", "Deuteranopia", "Tritanopia"
	}, "Off")

	SettingsClient.CreateToggleSetting(container, "Accessibility.HighContrast", "High Contrast", false)
	SettingsClient.CreateToggleSetting(container, "Accessibility.LargeText", "Large Text", false)
	SettingsClient.CreateToggleSetting(container, "Accessibility.ReduceMotion", "Reduce Motion", false)
	SettingsClient.CreateToggleSetting(container, "Accessibility.ScreenReader", "Screen Reader", false)
	SettingsClient.CreateToggleSetting(container, "Accessibility.MonoAudio", "Mono Audio", false)
	SettingsClient.CreateToggleSetting(container, "Accessibility.VisualAlerts", "Visual Alerts", true)
	SettingsClient.CreateToggleSetting(container, "Accessibility.HapticFeedback", "Haptic Feedback", true)
	SettingsClient.CreateToggleSetting(container, "Accessibility.OneHandedMode", "One-Handed Mode", false)
	SettingsClient.CreateToggleSetting(container, "Accessibility.AutoWalk", "Auto Walk", false)
	SettingsClient.CreateToggleSetting(container, "Accessibility.AutoDrive", "Auto Drive", false)
	SettingsClient.CreateToggleSetting(container, "Accessibility.SimplifiedControls", "Simplified Controls", false)
	SettingsClient.CreateToggleSetting(container, "Accessibility.HoldToInteract", "Hold to Interact", false)
	SettingsClient.CreateToggleSetting(container, "Accessibility.TapToInteract", "Tap to Interact", true)
	SettingsClient.CreateToggleSetting(container, "Accessibility.DoubleTapToRun", "Double Tap to Run", false)
	SettingsClient.CreateToggleSetting(container, "Accessibility.AutoTargeting", "Auto Targeting", false)
	SettingsClient.CreateToggleSetting(container, "Accessibility.AssistMode", "Assist Mode", false)
end

function SettingsClient.BuildNetworkPanel()
	local container = SettingsClient.CreateCategoryPanel("Network")

	SettingsClient.CreateDropdownSetting(container, "Network.Region", "Server Region", {
		"Auto", "US East", "US West", "Europe", "Asia", "Australia"
	}, "Auto")

	SettingsClient.CreateToggleSetting(container, "Network.ShowPing", "Show Ping", true)
	SettingsClient.CreateToggleSetting(container, "Network.ShowPacketLoss", "Show Packet Loss", false)
	SettingsClient.CreateToggleSetting(container, "Network.ShowPacketStats", "Show Packet Stats", false)
	SettingsClient.CreateToggleSetting(container, "Network.AllowMobileData", "Allow Mobile Data", true)
	SettingsClient.CreateToggleSetting(container, "Network.CompressVoiceChat", "Compress Voice Chat", true)

	SettingsClient.CreateToggleSetting(container, "Network.VoiceChatEnabled", "Voice Chat Enabled", true)
	SettingsClient.CreateToggleSetting(container, "Network.PushToTalk", "Push to Talk", false)
	SettingsClient.CreateSliderSetting(container, "Network.VoiceActivationThreshold", "Voice Activation Threshold", 0, 1, 0.5, 0.05)
	SettingsClient.CreateSliderSetting(container, "Network.VoiceVolume", "Voice Chat Volume", 0, 1, 1.0, 0.05)
	SettingsClient.CreateSliderSetting(container, "Network.MicVolume", "Microphone Volume", 0, 1, 1.0, 0.05)
end

-- ============================================
- SETTING WIDGETS
- ============================================

function SettingsClient.CreateCategoryPanel(categoryId: string)
	if not settingsUI.ContentFrame then return end

	local panel = Instance.new("ScrollingFrame")
	panel.Name = "Panel_" .. categoryId
	panel.Size = UDim2.new(1, 0, 1, 0)
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.ScrollBarThickness = 6
	panel.ScrollBarImageColor3 = Color3.fromRGB(0, 255, 136)
	panel.CanvasSize = UDim2.new(0, 0, 0, 0)
	panel.Visible = false
	panel.Parent = settingsUI.ContentFrame

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 16)
	layout.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 20)
	padding.PaddingLeft = UDim.new(0, 20)
	padding.PaddingRight = UDim.new(0, 20)
	padding.PaddingBottom = UDim.new(0, 20)
	padding.Parent = panel

	return panel
end

function SettingsClient.CreateToggleSetting(parent: Instance, settingPath: string, label: string, defaultValue: boolean)
	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(1, 0, 0, 50)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	panel.BackgroundTransparency = 0.3
	panel.BorderSizePixel = 0
	panel.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	Instance.new("TextLabel", {
		Text = label,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, -80, 1, 0),
		Position = UDim2.new(0, 20, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = panel,
	})

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.new(0, 50, 0, 30)
	toggle.Position = UDim2.new(1, -60, 0.5, -15)
	toggle.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
	toggle.BorderSizePixel = 0
	toggle.Text = ""
	toggle.Parent = panel

	local toggleCorner = Instance.new("UICorner")
	toggleCorner.CornerRadius = UDim.new(1, 0)
	toggleCorner.Parent = toggle

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 24, 0, 24)
	knob.Position = UDim2.new(0, 3, 0.5, -12)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = toggle

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	-- Get current value
	local value = SettingsClient.GetSetting(settingPath)
	toggle.BackgroundColor3 = value and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(100, 100, 100)
	knob.Position = value and UDim2.new(1, -27, 0.5, -12) or UDim2.new(0, 3, 0.5, -12)

	toggle.MouseButton1Click:Connect(function()
		local newValue = not SettingsClient.GetSetting(settingPath)
		SettingsClient.SetSetting(settingPath, newValue)

		-- Animate
		game:GetService("TweenService"):Create(toggle, TweenInfo.new(0.2), {
			BackgroundColor3 = newValue and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(100, 100, 100),
		}):Play()

		game:GetService("TweenService"):Create(knob, TweenInfo.new(0.2), {
			Position = newValue and UDim2.new(1, -27, 0.5, -12) or UDim2.new(0, 3, 0.5, -12),
		}):Play()
	end)
end

function SettingsClient.CreateSliderSetting(parent: Instance, settingPath: string, label: string, min: number, max: number, defaultValue: number, step: number)
	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(1, 0, 0, 60)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	panel.BackgroundTransparency = 0.3
	panel.BorderSizePixel = 0
	panel.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	Instance.new("TextLabel", {
		Text = label,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, -60, 0, 20),
		Position = UDim2.new(0, 20, 0, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = panel,
	})

	-- Value display
	local valueLabel = Instance.new("TextLabel")
	valueLabel.Text = tostring(SettingsClient.GetSetting(settingPath) or defaultValue)
	valueLabel.TextSize = 14
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextColor3 = Color3.fromRGB(0, 255, 136)
	valueLabel.Size = UDim2.new(0, 60, 0, 20)
	valueLabel.Position = UDim2.new(1, -80, 0, 10)
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.BackgroundTransparency = 1
	valueLabel.Parent = panel

	-- Slider track
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -40, 0, 6)
	track.Position = UDim2.new(0, 20, 0, 40)
	track.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	track.BorderSizePixel = 0
	track.Parent = panel

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	-- Slider fill
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new((SettingsClient.GetSetting(settingPath) or defaultValue - min) / (max - min), 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	-- Slider knob
	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.Position = UDim2.new(fill.Size.X.Scale, -9, 0.5, -9)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.ZIndex = 2
	knob.Parent = track

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	-- Interaction
	local dragging = false

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			UpdateSlider(input.Position.X)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			UpdateSlider(input.Position.X)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	local function UpdateSlider(x: number)
		local trackPos = track.AbsolutePosition.X
		local trackSize = track.AbsoluteSize.X
		local relativeX = math.clamp(x - trackPos, 0, trackSize)
		local percent = relativeX / trackSize
		local value = min + percent * (max - min)
		value = math.floor(value / step + 0.5) * step
		value = math.clamp(value, min, max)

		fill.Size = UDim2.new(percent, 0, 1, 0)
		knob.Position = UDim2.new(percent, -9, 0.5, -9)
		valueLabel.Text = tostring(value)

		SettingsClient.SetSetting(settingPath, value)
	end
end

function SettingsClient.CreateDropdownSetting(parent: Instance, settingPath: string, label: string, options: { string }, defaultValue: string)
	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(1, 0, 0, 60)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	panel.BackgroundTransparency = 0.3
	panel.BorderSizePixel = 0
	panel.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = panel

	Instance.new("TextLabel", {
		Text = label,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, -120, 1, 0),
		Position = UDim2.new(0, 20, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = panel,
	})

	local dropdown = Instance.new("TextButton")
	dropdown.Text = SettingsClient.GetSetting(settingPath) or defaultValue
	dropdown.TextSize = 14
	dropdown.Font = Enum.Font.GothamMedium
	dropdown.TextColor3 = Color3.new(1, 1, 1)
	dropdown.Size = UDim2.new(0, 150, 0, 36)
	dropdown.Position = UDim2.new(1, -160, 0.5, -18)
	dropdown.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	dropdown.BorderSizePixel = 0
	dropdown.Parent = panel

	local dropdownCorner = Instance.new("UICorner")
	dropdownCorner.CornerRadius = UDim.new(0, 8)
	dropdownCorner.Parent = dropdown

	-- Arrow icon
	Instance.new("TextLabel", {
		Text = "▼",
		TextSize = 12,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(150, 150, 150),
		Size = UDim2.new(0, 20, 1, 0),
		Position = UDim2.new(1, -25, 0, 0),
		BackgroundTransparency = 1,
		Parent = dropdown,
	})

	-- Dropdown list (would be created on click)
	dropdown.MouseButton1Click:Connect(function()
		SettingsClient.ShowDropdown(dropdown, options, function(selected)
			dropdown.Text = selected
			SettingsClient.SetSetting(settingPath, selected)
		end)
	end)
end

function SettingsClient.ShowDropdown(anchorButton: TextButton, options: { string }, callback: (string) -> ())
	-- Would create dropdown list
end

-- ============================================
- SETTINGS MANAGEMENT
- ============================================

function SettingsClient.GetSetting(path: string): any
	local keys = Utils.Split(path, ".")
	local current = currentSettings

	for _, key in ipairs(keys) do
		if current[key] == nil then return nil end
		current = current[key]
	end

	return current
end

function SettingsClient.SetSetting(path: string, value: any)
	local keys = Utils.Split(path, ".")
	local current = currentSettings

	for i = 1, #keys - 1 do
		local key = keys[i]
		if not current[key] then current[key] = {} end
		current = current[key]
	end

	current[keys[#keys]] = value
end

function SettingsClient.SwitchCategory(categoryId: string)
	-- Hide all panels
	for _, child in ipairs(settingsUI.ContentFrame:GetChildren()) do
		if child.Name:match("^Panel_") then
			child.Visible = false
		end
	end

	-- Show selected
	local panel = settingsUI.ContentFrame:FindFirstChild("Panel_" .. categoryId)
	if panel then
		panel.Visible = true
	end

	-- Update sidebar highlights
	for _, child in ipairs(settingsUI.Frame.Sidebar:GetChildren()) do
		if child:IsA("TextButton") and child.Name:match("^Category_") then
			local isActive = child.Name == "Category_" .. categoryId
			child.TextColor3 = isActive and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(150, 150, 150)
			child.BackgroundTransparency = isActive and 0.2 or 0.5
		end
	end

	settingsUI.CurrentCategory = categoryId
end

function SettingsClient.OpenSettings()
	if not settingsScreenGui then
		SettingsClient.BuildSettingsUI()
	end
	settingsScreenGui.Enabled = true
end

function SettingsClient.CloseSettings()
	if settingsScreenGui then
		settingsScreenGui.Enabled = false
	end
end

function SettingsClient.ToggleSettings()
	if settingsScreenGui then
		settingsScreenGui.Enabled = not settingsScreenGui.Enabled
	end
end

function SettingsClient.ResetToDefaults()
	currentSettings = Utils.DeepCopy(DEFAULT_SETTINGS)
	SettingsClient.ApplyAllSettings()
	SettingsClient.SaveSettings()

	-- Refresh UI
	if settingsUI.CurrentCategory then
		SettingsClient.SwitchCategory(settingsUI.CurrentCategory)
	end

	UIController.ShowToast({
		Type = "Success",
		Title = "SETTINGS RESET",
		Message = "All settings restored to defaults.",
		Duration = 3,
	})
end

function SettingsClient.OnSettingChanged(category: string, setting: string, value: any)
	-- Update UI element
	local path = category .. "." .. setting
	SettingsClient.SetSetting(path, value)

	-- Apply immediately for some settings
	if category == "Graphics" then
		SettingsClient.ApplyGraphicsSettings()
	elseif category == "Audio" then
		SettingsClient.ApplyAudioSettings()
	elseif category == "Controls" then
		SettingsClient.ApplyControlSettings()
	elseif category == "Gameplay" then
		SettingsClient.ApplyGameplaySettings()
	elseif category == "Interface" then
		SettingsClient.ApplyInterfaceSettings()
	elseif category == "Accessibility" then
		SettingsClient.ApplyAccessibilitySettings()
	elseif category == "Network" then
		SettingsClient.ApplyNetworkSettings()
	end
end

function SettingsClient.GetCurrentSettings(): { [string]: any }
	return currentSettings
end

function SettingsClient.Cleanup()
	if settingsScreenGui then
		settingsScreenGui:Destroy()
	end
end

Utils.DebugLog("SettingsClient initialized")

return SettingsClient