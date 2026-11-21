--[[
	UNDERGROUND — Heat Client
	Visual/audio heat effects, police pursuit UI, heat level indicators.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)
local UIController = require(script.Parent.UIController)

local HeatClient = {}

-- ============================================
- STATE
- ============================================

local currentHeatLevel = 0
local heatSources = {}
local activePursuit = false
local pursuerCount = 0
local pursuitIntensity = 0

local heatUI = {}
local pursuitUI = {}
local sirenSounds = {}
local screenEffects = {}

local PURSUIT_MUSIC = {
	[1] = "rbxassetid://", -- Low tension
	[2] = "rbxassetid://", -- Medium tension
	[3] = "rbxassetid://", -- High tension
	[4] = "rbxassetid://", -- Extreme tension
	[5] = "rbxassetid://", -- Maximum tension
}

local SIREN_SOUNDS = {
	Patrol = "rbxassetid://",
	Pursuit = "rbxassetid://",
	Helicopter = "rbxassetid://",
	SWAT = "rbxassetid://",
}

-- ============================================
- HEAT LEVEL MANAGEMENT
- ============================================

function HeatClient.OnHeatChanged(data: any)
	if data.Level then
		HeatClient.SetHeatLevel(data.Level, data.Effects)
	end
end

function HeatClient.SetHeatLevel(level: number, effects: any?)
	level = math.clamp(level, 0, Constants.Heat.MaxStars)
	local oldLevel = currentHeatLevel
	currentHeatLevel = level

	-- Update HUD
	UIController.UpdateHeat(level, effects)

	-- Level up effects
	if level > oldLevel then
		HeatClient.OnHeatLevelUp(level, effects)
	elseif level < oldLevel then
		HeatClient.OnHeatLevelDown(level)
	end

	-- Update heat sources display
	HeatClient.UpdateHeatSourcesUI()
end

function HeatClient.OnHeatLevelUp(newLevel: number, effects: any?)
	-- Screen flash
	UIController.ShowToast({
		Type = "Warning",
		Title = "HEAT LEVEL " .. newLevel,
		Message = "Police response escalating!",
		Duration = 3,
	})

	-- Screen effects
	HeatClient.ApplyLevelEffects(newLevel)

	-- Sound
	HeatClient.PlayHeatLevelUpSound(newLevel)

	-- Start pursuit music if threshold reached
	if newLevel >= 1 then
		HeatClient.StartPursuitMusic(newLevel)
	end

	Signals.GameSignals.HeatLevelUp:Fire(newLevel)
end

function HeatClient.OnHeatLevelDown(newLevel: number)
	-- Update music
	if newLevel == 0 then
		HeatClient.StopPursuitMusic()
	else
		HeatClient.UpdatePursuitMusic(newLevel)
	end

	-- Reduce screen effects
	HeatClient.ApplyLevelEffects(newLevel)

	Signals.GameSignals.HeatLevelDown:Fire(newLevel)
end

function HeatClient.ApplyLevelEffects(level: number)
	local effects = Constants.Heat.Effects[level]
	if not effects then
		HeatClient.ClearAllEffects()
		return
	end

	-- Color correction
	local colorCorrection = Lighting:FindFirstChild("HeatColorCorrection")
	if not colorCorrection then
		colorCorrection = Instance.new("ColorCorrectionEffect")
		colorCorrection.Name = "HeatColorCorrection"
		colorCorrection.Parent = Lighting
	end

	TweenService:Create(colorCorrection, TweenInfo.new(1), {
		Saturation = -0.2 * level,
		Contrast = 0.1 * level,
		Brightness = -0.05 * level,
		TintColor = effects.HUDColor,
	}):Play()

	-- Vignette
	local vignette = Lighting:FindFirstChild("HeatVignette")
	if not vignette then
		vignette = Instance.new("VignetteEffect")
		vignette.Name = "HeatVignette"
		vignette.Parent = Lighting
	end

	TweenService:Create(vignette, TweenInfo.new(1), {
		Intensity = 0.3 * level,
		Size = 20 + level * 10,
	}):Play()

	-- Blur (high heat)
	if level >= 4 then
		local blur = Lighting:FindFirstChild("HeatBlur")
		if not blur then
			blur = Instance.new("BlurEffect")
			blur.Name = "HeatBlur"
			blur.Parent = Lighting
		end

		game:GetService("TweenService"):Create(blur, TweenInfo.new(1), {
			Size = (level - 3) * 5,
		}):Play()
	else
		local blur = Lighting:FindFirstChild("HeatBlur")
		if blur then blur:Destroy() end
	end

	-- Screen shake for high heat
	if level >= 4 then
		UIController.ShakeScreen(0.5 * (level - 3))
	end
end

function HeatClient.ClearAllEffects()
	local colorCorrection = Lighting:FindFirstChild("HeatColorCorrection")
	if colorCorrection then colorCorrection:Destroy() end

	local vignette = Lighting:FindFirstChild("HeatVignette")
	if vignette then vignette:Destroy() end

	local blur = Lighting:FindFirstChild("HeatBlur")
	if blur then blur:Destroy() end
end

-- ============================================
- PURSUIT MUSIC
- ============================================

local currentPursuitMusic = nil

function HeatClient.StartPursuitMusic(level: number)
	local musicId = PURSUIT_MUSIC[level] or PURSUIT_MUSIC[1]
	if not musicId or musicId == "" then return end

	if currentPursuitMusic then
		currentPursuitMusic:Stop()
		currentPursuitMusic:Destroy()
	end

	currentPursuitMusic = Instance.new("Sound")
	currentPursuitMusic.Name = "PursuitMusic"
	currentPursuitMusic.SoundId = musicId
	currentPursuitMusic.Volume = 0.3
	currentPursuitMusic.Looped = true
	currentPursuitMusic.Parent = SoundService
	currentPursuitMusic:Play()

	-- Fade in
	currentPursuitMusic.Volume = 0
	game:GetService("TweenService"):Create(currentPursuitMusic, TweenInfo.new(2), {
		Volume = 0.3,
	}):Play()
end

function HeatClient.UpdatePursuitMusic(level: number)
	if not currentPursuitMusic then return end

	local musicId = PURSUIT_MUSIC[level] or PURSUIT_MUSIC[1]
	if currentPursuitMusic.SoundId ~= musicId then
		currentPursuitMusic:Stop()
		currentPursuitMusic.SoundId = musicId
		currentPursuitMusic:Play()
	end

	-- Adjust volume/intensity based on level
	local targetVolume = 0.2 + (level * 0.1)
	game:GetService("TweenService"):Create(currentPursuitMusic, TweenInfo.new(1), {
		Volume = math.clamp(targetVolume, 0.1, 0.6),
	}):Play()
end

function HeatClient.StopPursuitMusic()
	if currentPursuitMusic then
		game:GetService("TweenService"):Create(currentPursuitMusic, TweenInfo.new(2), {
			Volume = 0,
		}):Play()

		task.wait(2)
		if currentPursuitMusic then
			currentPursuitMusic:Stop()
			currentPursuitMusic:Destroy()
			currentPursuitMusic = nil
		end
	end
end

function HeatClient.PlayHeatLevelUpSound(level: number)
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://" -- Heat level up sound
	sound.Volume = 0.5
	sound.Parent = SoundService
	sound:Play()

	game:GetService("Debris"):AddItem(sound, 5)
end

-- ============================================
- PURSUIT UI
- ============================================

function HeatClient.OnPursuitStarted(data: any)
	activePursuit = true
	pursuerCount = data.PursuerCount or 1
	pursuitIntensity = data.Intensity or 1

	HeatClient.ShowPursuitUI(data)

	-- Start siren sounds
	HeatClient.StartSirenSounds(data.PursuerTypes or { "Patrol" })

	-- Screen effects
	UIController.ShakeScreen(0.3)

	Signals.GameSignals.PursuitStarted:Fire(data)
end

function HeatClient.OnPursuitEnded(escaped: boolean)
	activePursuit = false
	pursuerCount = 0
	pursuitIntensity = 0

	HeatClient.HidePursuitUI()

	-- Stop sirens
	HeatClient.StopSirenSounds()

	if escaped then
		UIController.ShowToast({
			Type = "Success",
			Title = "PURSUIT EVADDED",
			Message = "You lost the police!",
			Duration = 4,
		})
	else
		UIController.ShowToast({
			Type = "Error",
			Title = "BUSTED",
			Message = "Police caught up to you.",
			Duration = 4,
		})
	end

	Signals.GameSignals.PursuitEnded:Fire(escaped)
end

function HeatClient.ShowPursuitUI(data: any)
	if pursuitUI.Frame then return end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "PursuitUI"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 15
	screenGui.Parent = Players.LocalPlayer.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "PursuitFrame"
	frame.Size = UDim2.new(0, 300, 0, 100)
	frame.Position = UDim2.new(0.5, -150, 0.1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 100, 0)
	stroke.Thickness = 3
	stroke.Transparency = 0.5
	stroke.Parent = frame

	-- Warning icon
	Instance.new("TextLabel", {
		Text = "⚠ PURSUIT ACTIVE",
		TextSize = 18,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(255, 100, 0),
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.new(0, 10, 0, 10),
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 1,
		Parent = frame,
	})

	-- Pursuer count
	local pursuerLabel = Instance.new("TextLabel")
	pursuerLabel.Name = "PursuerCount"
	pursuerLabel.Text = "PURSUERS: " .. (data.PursuerCount or 1)
	pursuerLabel.TextSize = 16
	pursuerLabel.Font = Enum.Font.GothamBold
	pursuerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	pursuerLabel.Size = UDim2.new(1, -20, 0, 24)
	pursuerLabel.Position = UDim2.new(0, 10, 0, 35)
	pursuerLabel.TextXAlignment = Enum.TextXAlignment.Center
	pursuerLabel.BackgroundTransparency = 1
	pursuerLabel.Parent = frame

	-- Distance/Intensity bar
	local intensityFrame = Instance.new("Frame")
	intensityFrame.Name = "IntensityBar"
	intensityFrame.Size = UDim2.new(1, -20, 0, 12)
	intensityFrame.Position = UDim2.new(0, 10, 1, -22)
	intensityFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	intensityFrame.BorderSizePixel = 0
	intensityFrame.Parent = frame

	local intensityCorner = Instance.new("UICorner")
	intensityCorner.CornerRadius = UDim.new(1, 0)
	intensityCorner.Parent = intensityFrame

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(255, 100, 0)
	fill.BorderSizePixel = 0
	fill.Parent = intensityFrame

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	-- Pursuer types
	local typesText = "TYPES: " .. table.concat(data.PursuerTypes or { "Patrol" }, ", ")
	Instance.new("TextLabel", {
		Text = typesText,
		TextSize = 11,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(180, 180, 180),
		Size = UDim2.new(1, -20, 0, 16),
		Position = UDim2.new(0, 10, 1, -45),
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundTransparency = 1,
		Parent = frame,
	})

	pursuitUI = {
		ScreenGui = screenGui,
		Frame = frame,
		PursuerLabel = pursuerLabel,
		IntensityFill = intensityFrame.Fill,
	}

	-- Animate in
	frame.Position = UDim2.new(0.5, -150, 0.1, -100)
	game:GetService("TweenService"):Create(frame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, -150, 0.1, 0),
	}):Play()

	-- Pulse animation
	task.spawn(function()
		while pursuitUI.Frame and pursuitUI.Frame.Parent do
			game:GetService("TweenService"):Create(frame, TweenInfo.new(0.5), {
				BackgroundTransparency = 0,
			}):Play()
			task.wait(0.5)
			game:GetService("TweenService"):Create(frame, TweenInfo.new(0.5), {
				BackgroundTransparency = 0.1,
			}):Play()
			task.wait(0.5)
		end
	end)
end

function HeatClient.HidePursuitUI()
	if pursuitUI.Frame then
		game:GetService("TweenService"):Create(pursuitUI.Frame, TweenInfo.new(0.3), {
			Position = UDim2.new(0.5, -150, 0.1, -100),
		}):Play()

		task.wait(0.3)
		if pursuitUI.ScreenGui then
			pursuitUI.ScreenGui:Destroy()
		end
		pursuitUI = {}
	end
end

function HeatClient.UpdatePursuitUI(pursuerCount: number, intensity: number)
	if not pursuitUI.Frame then return end

	pursuitUI.PursuerLabel.Text = "PURSUERS: " .. pursuerCount

	-- Update intensity bar
	game:GetService("TweenService"):Create(pursuitUI.IntensityFill, TweenInfo.new(0.5), {
		Size = UDim2.new(math.clamp(intensity, 0, 1), 0, 1, 0),
	}):Play()
end

-- ============================================
- SIREN SOUNDS
- ============================================

local activeSirens = {}

function HeatClient.StartSirenSounds(pursuerTypes: { string })
	for _, pursuerType in ipairs(pursuerTypes) do
		local soundId = SIREN_SOUNDS[pursuerType] or SIREN_SOUNDS.Patrol

		local sound = Instance.new("Sound")
		sound.Name = "Siren_" .. pursuerType
		sound.SoundId = soundId
		sound.Volume = 0.4
		sound.Looped = true
		sound.RollOffMode = Enum.RollOffMode.Linear
		sound.RollOffMinDistance = 50
		sound.RollOffMaxDistance = 300
		sound.Parent = workspace
		sound:Play()

		activeSirens[pursuerType] = sound
	end
end

function HeatClient.StopSirenSounds()
	for _, sound in pairs(activeSirens) do
		sound:Stop()
		sound:Destroy()
	end
	activeSirens = {}
end

function HeatClient.UpdateSirenVolume(distance: number)
	for _, sound in pairs(activeSirens) do
		local volume = math.clamp(1 - (distance / 300), 0, 0.5)
		sound.Volume = volume
	end
end

-- ============================================
- HEAT SOURCES UI
- ============================================

function HeatClient.UpdateHeatSourcesUI()
	-- Would update a heat sources panel showing recent heat gains
end

function HeatClient.ShowHeatBreakdown()
	-- Show detailed heat breakdown UI
end

-- ============================================
- SCREEN EFFECTS
- ============================================

function HeatClient.AddScreenFlash(color: Color3, duration: number?)
	local flash = Instance.new("Frame")
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 0
	flash.BorderSizePixel = 0
	flash.ZIndex = 100
	flash.Parent = Players.LocalPlayer.PlayerGui

	game:GetService("TweenService"):Create(flash, TweenInfo.new(duration or 0.1), {
		BackgroundTransparency = 1,
	}):Play()

	task.delay(duration or 0.1, function()
		flash:Destroy()
	end)
end

function HeatClient.AddRadialBlur(intensity: number, duration: number?)
	-- Would add radial blur effect
end

function HeatClient.AddChromaticAberration(intensity: number, duration: number?)
	-- Would add chromatic aberration
end

-- ============================================
- CLEANUP
- ============================================

function HeatClient.Cleanup()
	HeatClient.ClearAllEffects()
	HeatClient.StopPursuitMusic()
	HeatClient.StopSirenSounds()

	if HeatClient.pursuitUI and HeatClient.pursuitUI.ScreenGui then
		HeatClient.pursuitUI.ScreenGui:Destroy()
	end
end

Utils.DebugLog("HeatClient initialized")

return HeatClient