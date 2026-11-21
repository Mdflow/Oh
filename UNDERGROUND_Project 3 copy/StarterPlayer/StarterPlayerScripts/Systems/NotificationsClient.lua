--[[
	UNDERGROUND — Notifications Client
	Toast notifications, achievement popups, event alerts, system messages.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)
local UIController = require(script.Parent.UIController)

local NotificationsClient = {}

-- ============================================
- STATE
- ============================================

local notificationQueue = {}
local activeNotifications = {}
local notificationHistory = {}
local maxActiveNotifications = 5
local maxHistory = 50

local notificationContainer = nil
local notificationSounds = {}

-- ============================================
- SOUND SETUP
- ============================================

local function SetupSounds()
	notificationSounds = {
		Success = "rbxassetid://", -- Pleasant ding
		Error = "rbxassetid://",   -- Error buzz
		Warning = "rbxassetid://", -- Alert sound
		Info = "rbxassetid://",    -- Soft chime
		Achievement = "rbxassetid://", -- Fanfare
		LevelUp = "rbxassetid://", -- Level up fanfare
		Unlock = "rbxassetid://",  -- Unlock sound
		DeliveryComplete = "rbxassetid://", -- Cash register
		ContractAccepted = "rbxassetid://", -- Confirm
		ContractFailed = "rbxassetid://", -- Fail sound
		HeatUp = "rbxassetid://", -- Alert
		HeatDown = "rbxassetid://", -- Relief
		PursuitStart = "rbxassetid://", -- Siren
		PursuitEnd = "rbxassetid://", -- Relief
		DailyReward = "rbxassetid://", -- Coin sound
		WeeklyComplete = "rbxassetid://", -- Fanfare
		EventStart = "rbxassetid://", -- Alert
		EventEnd = "rbxassetid://", -- Calm
		Purchase = "rbxassetid://", -- Cash register
		VehiclePurchase = "rbxassetid://", -- Engine rev
		Upgrade = "rbxassetid://", -- Upgrade sound
	}
end

function NotificationsClient.PlaySound(notificationType: string)
	local soundId = notificationSounds[notificationType]
	if not soundId or soundId == "" then return end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.5
	sound.Parent = SoundService
	sound:Play()

	game:GetService("Debris"):AddItem(sound, 5)
end

-- ============================================
- NOTIFICATION CONTAINER
- ============================================

function NotificationsClient.Initialize()
	Utils.DebugLog("NotificationsClient initializing...")

	SetupSounds()
	NotificationsClient.BuildNotificationContainer()

	-- Signals
	Signals.GameSignals.NotificationQueued:Connect(function(data)
		NotificationsClient.QueueNotification(data)
	end)

	Utils.DebugLog("NotificationsClient initialized")
end

function NotificationsClient.BuildNotificationContainer()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "NotificationContainer"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 50
	screenGui.Parent = Players.LocalPlayer.PlayerGui

	local container = Instance.new("Frame")
	container.Name = "Container"
	container.Size = UDim2.new(0, 380, 1, -100)
	container.Position = UDim2.new(1, -390, 0, 50)
	container.BackgroundTransparency = 1
	container.Parent = screenGui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 10)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = container

	notificationContainer = container
end

-- ============================================
- NOTIFICATION CREATION
- ============================================

local NOTIFICATION_COLORS = {
	Success = Color3.fromRGB(0, 255, 136),
	Error = Color3.fromRGB(255, 50, 50),
	Warning = Color3.fromRGB(255, 215, 0),
	Info = Color3.fromRGB(0, 170, 255),
	Achievement = Color3.fromRGB(255, 215, 0),
	Delivery = Color3.fromRGB(0, 255, 136),
	Contract = Color3.fromRGB(0, 170, 255),
	Heat = Color3.fromRGB(255, 100, 0),
	Pursuit = Color3.fromRGB(255, 100, 0),
	Event = Color3.fromRGB(255, 100, 0),
	Social = Color3.fromRGB(170, 0, 255),
	Economy = Color3.fromRGB(255, 215, 0),
	Progression = Color3.fromRGB(255, 215, 0),
}

local NOTIFICATION_ICONS = {
	Success = "✅",
	Error = "❌",
	Warning = "⚠️",
	Info = "ℹ️",
	Achievement = "🏆",
	Delivery = "📦",
	Contract = "📋",
	Heat = "🔥",
	Pursuit = "🚨",
	Event = "🎪",
	Social = "👥",
	Economy = "💰",
	Progression = "⭐",
	DeliveryComplete = "📦",
	ContractAccepted = "📋",
	ContractFailed = "📋",
	LevelUp = "⭐",
	Unlock = "🔓",
	DailyReward = "🎁",
	WeeklyComplete = "✅",
	EventStart = "🎪",
	EventEnd = "🎪",
	Purchase = "💰",
	VehiclePurchase = "🚗",
	Upgrade = "⬆️",
}

function NotificationsClient.QueueNotification(data: any)
	-- Validate
	if not data.Type or not data.Title then return end

	-- Check duplicate suppression
	if data.SuppressDuplicates and NotificationsClient.IsDuplicate(data) then
		return
	end

	-- Create notification object
	local notification = {
		Id = Utils.GenerateID("notif"),
		Type = data.Type,
		Title = data.Title,
		Message = data.Message or "",
		Duration = data.Duration or 5,
		Icon = data.Icon or NOTIFICATION_ICONS[data.Type] or "ℹ️",
		Color = data.Color or NOTIFICATION_COLORS[data.Type] or Color3.fromRGB(200, 200, 200),
		Action = data.Action,
		Timestamp = os.time(),
		Dismissed = false,
	}

	-- Add to queue
	table.insert(notificationQueue, notification)

	-- Play sound
	NotificationsClient.PlaySound(data.Type)

	-- Show immediately if under limit
	if #activeNotifications < maxActiveNotifications then
		NotificationsClient.ShowNotification(notification)
	else
		-- Will be shown when slot opens
	end

	-- Add to history
	table.insert(notificationHistory, 1, notification)
	while #notificationHistory > maxHistory do
		table.remove(notificationHistory)
	end
end

function NotificationsClient.ShowNotification(notification: any)
	-- Create UI
	local frame = Instance.new("Frame")
	frame.Name = "Notification_" .. notification.Id
	frame.Size = UDim2.new(1, 0, 0, 90)
	frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	frame.BackgroundTransparency = 0.1
	frame.BorderSizePixel = 0
	frame.LayoutOrder = notification.Timestamp
	frame.Parent = notificationContainer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = notification.Color
	stroke.Thickness = 2
	stroke.Transparency = 0.5
	stroke.Parent = frame

	-- Icon + Type badge
	local iconFrame = Instance.new("Frame")
	iconFrame.Size = UDim2.new(0, 50, 0, 50)
	iconFrame.Position = UDim2.new(0, 15, 0.5, -25)
	iconFrame.BackgroundColor3 = notification.Color
	iconFrame.BackgroundTransparency = 0.2
	iconFrame.BorderSizePixel = 0
	iconFrame.Parent = frame

	local iconCorner = Instance.new("UICorner")
	iconCorner.CornerRadius = UDim.new(1, 0)
	iconCorner.Parent = iconFrame

	Instance.new("TextLabel", {
		Text = notification.Icon,
		TextSize = 24,
		Font = Enum.Font.GothamBold,
		TextColor3 = notification.Color,
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Parent = iconFrame,
	})

	-- Title
	Instance.new("TextLabel", {
		Text = notification.Title,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, -90, 0, 24),
		Position = UDim2.new(0, 80, 0, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = frame,
	})

	-- Message
	Instance.new("TextLabel", {
		Text = notification.Message,
		TextSize = 13,
		Font = Enum.Font.GothamMedium,
		TextColor3 = Color3.fromRGB(180, 180, 180),
		Size = UDim2.new(1, -90, 0, 36),
		Position = UDim2.new(0, 80, 0, 38),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		BackgroundTransparency = 1,
		Parent = frame,
	})

	-- Action button
	if notification.Action then
		local actionBtn = Instance.new("TextButton")
		actionBtn.Text = notification.Action.Label
		actionBtn.TextSize = 11
		actionBtn.Font = Enum.Font.GothamBold
		actionBtn.TextColor3 = Color3.new(0, 0, 0)
		actionBtn.Size = UDim2.new(0, 80, 0, 28)
		actionBtn.Position = UDim2.new(1, -95, 1, -38)
		actionBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
		actionBtn.BorderSizePixel = 0
		actionBtn.Parent = frame

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 6)
		btnCorner.Parent = actionBtn

		actionBtn.MouseButton1Click:Connect(function()
			if notification.Action.Callback then
				notification.Action.Callback()
			end
			NotificationsClient.DismissNotification(notification.Id)
		end)
	end

	-- Progress bar (auto-dismiss)
	local progressBar = Instance.new("Frame")
	progressBar.Name = "ProgressBar"
	progressBar.Size = UDim2.new(1, 0, 0, 3)
	progressBar.Position = UDim2.new(0, 0, 1, -3)
	progressBar.BackgroundColor3 = notification.Color
	progressBar.BorderSizePixel = 0
	progressBar.Parent = frame

	local barCorner = Instance.new("UICorner")
	barCorner.CornerRadius = UDim.new(0, 0)
	barCorner.Parent = progressBar

	-- Animate in
	frame.Position = UDim2.new(1, 50, frame.Position.Y.Scale, frame.Position.Y.Offset)
	game:GetService("TweenService"):Create(frame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, frame.Position.Y.Scale, frame.Position.Y.Offset),
	}):Play()

	-- Progress bar animation
	local duration = notification.Duration or 5
	game:GetService("TweenService"):Create(progressBar, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		Size = UDim2.new(0, 0, 0, 3),
	}):Play()

	-- Auto-dismiss
	task.delay(duration, function()
		if not notification.Dismissed then
			NotificationsClient.DismissNotification(notification.Id)
		end
	end)

	-- Store reference
	notification.Frame = frame
	table.insert(activeNotifications, notification)

	-- Reposition others
	NotificationsClient.RepositionNotifications()
end

function NotificationsClient.DismissNotification(notificationId: string)
	for i, notification in ipairs(activeNotifications) do
		if notification.Id == notificationId then
			notification.Dismissed = true

			if notification.Frame then
				game:GetService("TweenService"):Create(notification.Frame, TweenInfo.new(0.3), {
					Position = UDim2.new(1, 50, notification.Frame.Position.Y.Scale, notification.Frame.Position.Y.Offset),
					BackgroundTransparency = 1,
				}):Play()

				task.wait(0.3)
				notification.Frame:Destroy()
			end

			table.remove(activeNotifications, i)
			NotificationsClient.RepositionNotifications()
			break
		end
	end
end

function NotificationsClient.RepositionNotifications()
	for i, notification in ipairs(activeNotifications) do
		if notification.Frame then
			game:GetService("TweenService"):Create(notification.Frame, TweenInfo.new(0.3), {
				LayoutOrder = i,
			}):Play()
		end
	end
end

function NotificationsClient.DismissAll()
	for i = #activeNotifications, 1, -1 do
		NotificationsClient.DismissNotification(activeNotifications[i].Id)
	end
end

function NotificationsClient.IsDuplicate(notification: any): boolean
	for _, existing in ipairs(activeNotifications) do
		if existing.Title == notification.Title and existing.Message == notification.Message then
			return true
		end
	end
	for _, history in ipairs(notificationHistory) do
		if history.Title == notification.Title and history.Message == notification.Message then
			if os.time() - history.Timestamp < 5 then -- Within 5 seconds
				return true
			end
		end
	end
	return false
end

-- ============================================
- CONVENIENCE METHODS
- ============================================

function NotificationsClient.ShowSuccess(title: string, message: string, duration: number?)
	NotificationsClient.QueueNotification({
		Type = "Success",
		Title = title,
		Message = message,
		Duration = duration or 4,
	})
end

function NotificationsClient.ShowError(title: string, message: string, duration: number?)
	NotificationsClient.QueueNotification({
		Type = "Error",
		Title = title,
		Message = message,
		Duration = duration or 5,
	})
end

function NotificationsClient.ShowWarning(title: string, message: string, duration: number?)
	NotificationsClient.QueueNotification({
		Type = "Warning",
		Title = title,
		Message = message,
		Duration = duration or 5,
	})
end

function NotificationsClient.ShowInfo(title: string, message: string, duration: number?)
	NotificationsClient.QueueNotification({
		Type = "Info",
		Title = title,
		Message = message,
		Duration = duration or 4,
	})
end

function NotificationsClient.ShowAchievement(title: string, message: string, duration: number?)
	NotificationsClient.QueueNotification({
		Type = "Achievement",
		Title = title,
		Message = message,
		Duration = duration or 6,
	})
end

function NotificationsClient.ShowDeliveryComplete(rewards: any)
	NotificationsClient.QueueNotification({
		Type = "Delivery",
		Title = "DELIVERY COMPLETE",
		Message = "Earned $" .. Utils.FormatCurrency(rewards.cash) .. " + " .. rewards.xp .. " XP",
		Duration = 5,
	})
end

function NotificationsClient.ShowLevelUp(level: number, unlocks: { string })
	NotificationsClient.QueueNotification({
		Type = "LevelUp",
		Title = "LEVEL UP! LVL " .. level,
		Message = "Unlocks: " .. table.concat(unlocks, ", "),
		Duration = 6,
	})
end

function NotificationsClient.ShowUnlock(unlockType: string, unlockId: string)
	local unlockNames = {
		Vehicle = "New Vehicle Unlocked",
		Upgrade = "Upgrade Available",
		District = "New District Unlocked",
		Contract = "New Contract Type",
		Livery = "New Livery Unlocked",
		Hideout = "Hideout Upgraded",
	}

	NotificationsClient.QueueNotification({
		Type = "Unlock",
		Title = unlockNames[unlockType] or "NEW UNLOCK",
		Message = unlockId,
		Duration = 5,
	})
end

function NotificationsClient.ShowDailyReward(day: number, reward: any)
	NotificationsClient.QueueNotification({
		Type = "DailyReward",
		Title = "DAILY LOGIN - DAY " .. day,
		Message = "Claimed: " .. (reward.Cash and "$" .. Utils.FormatCurrency(reward.Cash) .. " " or "") .. (reward.XP and reward.XP .. " XP" or "") .. (reward.Item and reward.Item or ""),
		Duration = 5,
	})
end

function NotificationsClient.ShowEvent(event: any)
	NotificationsClient.QueueNotification({
		Type = "Event",
		Title = event.Name .. " STARTED!",
		Message = event.Description or "Special event is now active!",
		Duration = 10,
	})
end

function NotificationsClient.ShowContractAccepted(contract: any)
	NotificationsClient.QueueNotification({
		Type = "Contract",
		Title = "CONTRACT ACCEPTED",
		Message = contract.Type .. " | " .. contract.PickupDistrict .. " → " .. contract.DropoffDistrict,
		Duration = 4,
	})
end

function NotificationsClient.ShowContractFailed(reason: string)
	NotificationsClient.QueueNotification({
		Type = "ContractFailed",
		Title = "CONTRACT FAILED",
		Message = reason,
		Duration = 5,
	})
end

function NotificationsClient.ShowHeatUp(level: number)
	NotificationsClient.QueueNotification({
		Type = "Heat",
		Title = "HEAT LEVEL " .. level,
		Message = "Police response escalating!",
		Duration = 4,
	})
end

function NotificationsClient.ShowPursuitStarted(data: any)
	NotificationsClient.QueueNotification({
		Type = "Pursuit",
		Title = "PURSUIT INITIATED",
		Message = data.PursuerCount .. " police unit(s) in pursuit!",
		Duration = 5,
	})
end

function NotificationsClient.ShowPursuitEnded(escaped: boolean)
	if escaped then
		NotificationsClient.ShowSuccess("PURSUIT EVADDED", "You lost the police!")
	else
		NotificationsClient.ShowError("BUSTED", "Police caught up to you.")
	end
end

function NotificationsClient.ShowVehiclePurchase(vehicleName: string)
	NotificationsClient.QueueNotification({
		Type = "VehiclePurchase",
		Title = "VEHICLE PURCHASED",
		Message = vehicleName .. " added to garage!",
		Duration = 4,
	})
end

function NotificationsClient.ShowUpgradeComplete(upgradeName: string)
	NotificationsClient.QueueNotification({
		Type = "Upgrade",
		Title = "UPGRADE COMPLETE",
		Message = upgradeName .. " installed!",
		Duration = 3,
	})
end

function NotificationsClient.ShowWeeklyComplete(rewards: any)
	NotificationsClient.QueueNotification({
		Type = "WeeklyComplete",
		Title = "WEEKLY CHALLENGE COMPLETE",
		Message = "Rewards: " .. (rewards.Cash and "$" .. Utils.FormatCurrency(rewards.Cash) .. " " or "") .. (rewards.XP and rewards.XP .. " XP" or ""),
		Duration = 6,
	})
end

-- ============================================
- HISTORY / SETTINGS
- ============================================

function NotificationsClient.GetHistory(): { any }
	return notificationHistory
end

function NotificationsClient.ClearHistory()
	notificationHistory = {}
end

function NotificationsClient.SetMaxActive(max: number)
	maxActiveNotifications = math.clamp(max, 1, 10)
end

function NotificationsClient.SetSoundEnabled(enabled: boolean)
	-- Would toggle notification sounds
end

function NotificationsClient.Cleanup()
	NotificationsClient.DismissAll()
	if notificationContainer then
		notificationContainer:Destroy()
	end
end

Utils.DebugLog("NotificationsClient initialized")

return NotificationsClient