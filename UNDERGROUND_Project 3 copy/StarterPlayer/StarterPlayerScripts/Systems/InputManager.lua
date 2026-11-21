--[[
	UNDERGROUND — Input Manager
	Unified input handling for Keyboard/Mouse, Gamepad, and Touch.
	Provides unified vehicle input and UI navigation.
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local Constants = require(game.ReplicatedStorage.Shared.Constants)
local Signals = require(game.ReplicatedStorage.Shared.Signals)
local Utils = require(game.ReplicatedStorage.Shared.Utils)

local InputManager = {}

-- ============================================
- STATE
- ============================================

local currentInputMode = "KeyboardMouse" -- "KeyboardMouse", "Gamepad", "Touch"
local vehicleInput = {
	Throttle = 0,
	Brake = 0,
	Steer = 0,
	Handbrake = false,
	Gear = 0,
}

local keyStates = {}
local actionHandlers = {}
local touchControls = {}
local gamepadConnected = false

local VEHICLE_ACTIONS = {
	"Throttle",
	"Brake",
	"SteerLeft",
	"SteerRight",
	"Handbrake",
	"ShiftUp",
	"ShiftDown",
	"ToggleCamera",
	"ToggleLights",
	"Horn",
	"UseNitro",
}

local UI_NAVIGATION_ACTIONS = {
	"NavigateUp",
	"NavigateDown",
	"NavigateLeft",
	"NavigateRight",
	"Confirm",
	"Cancel",
	"Back",
}

-- ============================================
- INPUT MODE DETECTION
- ============================================

local function DetectInputMode()
	local lastInputType = UserInputService:GetLastInputType()

	if lastInputType == Enum.UserInputType.Gamepad1
		or lastInputType == Enum.UserInputType.Gamepad2
		or lastInputType == Enum.UserInputType.Gamepad3
		or lastInputType == Enum.UserInputType.Gamepad4 then
		return "Gamepad"
	elseif lastInputType == Enum.UserInputType.Touch then
		return "Touch"
	else
		return "KeyboardMouse"
	end
end

local function OnLastInputTypeChanged(lastInputType: Enum.UserInputType)
	local newMode = "KeyboardMouse"

	if lastInputType == Enum.UserInputType.Gamepad1
		or lastInputType == Enum.UserInputType.Gamepad2
		or lastInputType == Enum.UserInputType.Gamepad3
		or lastInputType == Enum.UserInputType.Gamepad4 then
		newMode = "Gamepad"
	elseif lastInputType == Enum.UserInputType.Touch then
		newMode = "Touch"
	else
		newMode = "KeyboardMouse"
	end

	if newMode ~= currentInputMode then
		currentInputMode = newMode
		InputManager.OnInputModeChanged(currentInputMode)
		Signals.GameSignals.InputModeChanged:Fire(currentInputMode)
	end
end

-- ============================================
- VEHICLE INPUT BINDINGS
- ============================================

local function BindVehicleActions()
	-- Keyboard/Mouse
	ContextActionService:BindActionAtPriority("Vehicle_Throttle", function(_, state, input)
		if state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change then
			vehicleInput.Throttle = 1
		elseif state == Enum.UserInputState.End then
			vehicleInput.Throttle = 0
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.W)

	ContextActionService:BindActionAtPriority("Vehicle_Brake", function(_, state, input)
		if state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change then
			vehicleInput.Brake = 1
		elseif state == Enum.UserInputState.End then
			vehicleInput.Brake = 0
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.S)

	ContextActionService:BindActionAtPriority("Vehicle_SteerLeft", function(_, state, input)
		if state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change then
			vehicleInput.Steer = -1
		elseif state == Enum.UserInputState.End then
			vehicleInput.Steer = 0
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.A)

	ContextActionService:BindActionAtPriority("Vehicle_SteerRight", function(_, state, input)
		if state == Enum.UserInputState.Begin or state == Enum.UserInputState.Change then
			vehicleInput.Steer = 1
		elseif state == Enum.UserInputState.End then
			vehicleInput.Steer = 0
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.D)

	ContextActionService:BindActionAtPriority("Vehicle_Handbrake", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			vehicleInput.Handbrake = true
		elseif state == Enum.UserInputState.End then
			vehicleInput.Handbrake = false
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space)

	ContextActionService:BindActionAtPriority("Vehicle_ShiftUp", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			vehicleInput.Gear = math.min(vehicleInput.Gear + 1, 5)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.E)

	ContextActionService:BindActionAtPriority("Vehicle_ShiftDown", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			vehicleInput.Gear = math.max(vehicleInput.Gear - 1, -1)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.Q)

	ContextActionService:BindActionAtPriority("Vehicle_ToggleCamera", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.VehicleCameraToggle:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.C)

	ContextActionService:BindActionAtPriority("Vehicle_ToggleLights", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.VehicleLightsToggle:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.L)

	ContextActionService:BindActionAtPriority("Vehicle_Horn", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.VehicleHorn:Fire(true)
		elseif state == Enum.UserInputState.End then
			Signals.GameSignals.VehicleHorn:Fire(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.H)

	ContextActionService:BindActionAtPriority("Vehicle_Nitro", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.VehicleNitro:Fire(true)
		elseif state == Enum.UserInputState.End then
			Signals.GameSignals.VehicleNitro:Fire(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.LeftShift)

	-- Gamepad bindings
	ContextActionService:BindActionAtPriority("Vehicle_GamepadThrottle", function(_, state, input)
		local value = input.Position.Z
		vehicleInput.Throttle = math.max(0, -value) -- Right trigger
		vehicleInput.Brake = math.max(0, value)     -- Left trigger (negative Z)
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonL2)

	ContextActionService:BindActionAtPriority("GamepadSteer", function(_, state, input)
		vehicleInput.Steer = input.Position.X -- Left thumbstick X
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Thumbstick1)

	ContextActionService:BindActionAtPriority("GamepadHandbrake", function(_, state, input)
		vehicleInput.Handbrake = state == Enum.UserInputState.Begin
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonA)

	ContextActionService:BindActionAtPriority("GamepadShiftUp", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.VehicleShiftUp:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.ButtonR1)

	ContextActionService:BindActionAtPriority("GamepadShiftDown", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.VehicleShiftDown:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.ButtonL1)

	ContextActionService:BindActionAtPriority("GamepadNitro", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.VehicleNitro:Fire(true)
		elseif state == Enum.UserInputState.End then
			Signals.GameSignals.VehicleNitro:Fire(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.ButtonR2) -- Hold R2 for nitro (combined with throttle)

	ContextActionService:BindActionAtPriority("GamepadCamera", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.VehicleCameraToggle:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.ButtonX)

	ContextActionService:BindActionAtPriority("GamepadLights", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.VehicleLightsToggle:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.ButtonY)

	ContextActionService:BindActionAtPriority("GamepadHorn", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.VehicleHorn:Fire(true)
		elseif state == Enum.UserInputState.End then
			Signals.GameSignals.VehicleHorn:Fire(false)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.ButtonR3)
end

local function UnbindVehicleActions()
	for _, actionName in ipairs(VEHICLE_ACTIONS) do
		ContextActionService:UnbindAction("Vehicle_" .. actionName)
	end
	ContextActionService:UnbindAction("GamepadThrottle")
	ContextActionService:UnbindAction("GamepadSteer")
	ContextActionService:UnbindAction("GamepadHandbrake")
	ContextActionService:UnbindAction("GamepadShiftUp")
	ContextActionService:UnbindAction("GamepadShiftDown")
	ContextActionService:UnbindAction("GamepadNitro")
	ContextActionService:UnbindAction("GamepadCamera")
	ContextActionService:UnbindAction("GamepadLights")
	ContextActionService:UnbindAction("GamepadHorn")
end

-- ============================================
- TOUCH CONTROLS
- ============================================

local function CreateTouchControls()
	local PlayerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Remove existing
	local existing = PlayerGui:FindFirstChild("TouchControls")
	if existing then existing:Destroy() end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TouchControls"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = 10
	screenGui.Parent = PlayerGui

	-- Left side: Steering
	local steerFrame = Instance.new("Frame")
	steerFrame.Name = "Steering"
	steerFrame.Size = UDim2.new(0, 120, 0, 120)
	steerFrame.Position = UDim2.new(0, 20, 1, -140)
	steerFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	steerFrame.BackgroundTransparency = 0.3
	steerFrame.BorderSizePixel = 0
	steerFrame.Parent = screenGui

	local steerCorner = Instance.new("UICorner")
	steerCorner.CornerRadius = UDim.new(1, 0)
	steerCorner.Parent = steerFrame

	local steerKnob = Instance.new("Frame")
	steerKnob.Name = "Knob"
	steerKnob.Size = UDim2.new(0, 60, 0, 60)
	steerKnob.Position = UDim2.new(0.5, -30, 0.5, -30)
	steerKnob.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
	steerKnob.BackgroundTransparency = 0.2
	steerKnob.BorderSizePixel = 0
	steerKnob.Parent = steerFrame

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = steerKnob

	-- Right side: Throttle/Brake
	local pedalFrame = Instance.new("Frame")
	pedalFrame.Name = "Pedals"
	pedalFrame.Size = UDim2.new(0, 100, 0, 200)
	pedalFrame.Position = UDim2.new(1, -120, 1, -220)
	pedalFrame.BackgroundTransparency = 1
	pedalFrame.Parent = screenGui

	-- Brake pedal (top)
	local brakeBtn = Instance.new("TextButton")
	brakeBtn.Name = "Brake"
	brakeBtn.Size = UDim2.new(1, 0, 0.5, -10)
	pedalBtn.Position = UDim2.new(0, 0, 0, 0)
	brakeBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	brakeBtn.BackgroundTransparency = 0.3
	brakeBtn.BorderSizePixel = 0
	brakeBtn.Text = "BRAKE"
	brakeBtn.TextColor3 = Color3.new(1, 1, 1)
	brakeBtn.TextScaled = true
	brakeBtn.Font = Enum.Font.GothamBold
	brakeBtn.Parent = pedalFrame

	local brakeCorner = Instance.new("UICorner")
	brakeCorner.CornerRadius = UDim.new(0, 12)
	brakeCorner.Parent = brakeBtn

	-- Throttle pedal (bottom)
	local throttleBtn = Instance.new("TextButton")
	throttleBtn.Name = "Throttle"
	throttleBtn.Size = UDim2.new(1, 0, 0.5, -10)
	throttleBtn.Position = UDim2.new(0, 0, 0.5, 10)
	throttleBtn.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
	throttleBtn.BackgroundTransparency = 0.3
	throttleBtn.BorderSizePixel = 0
	throttleBtn.Text = "GAS"
	throttleBtn.TextColor3 = Color3.new(0, 0, 0)
	throttleBtn.TextScaled = true
	throttleBtn.Font = Enum.Font.GothamBold
	throttleBtn.Parent = pedalFrame

	local throttleCorner = Instance.new("UICorner")
	throttleCorner.CornerRadius = UDim.new(0, 12)
	throttleCorner.Parent = throttleBtn

	-- Handbrake button (center bottom)
	local handbrakeBtn = Instance.new("TextButton")
	handbrakeBtn.Name = "Handbrake"
	handbrakeBtn.Size = UDim2.new(0, 100, 0, 100)
	handbrakeBtn.Position = UDim2.new(0.5, -50, 1, -110)
	handbrakeBtn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
	handbrakeBtn.BackgroundTransparency = 0.2
	handbrakeBtn.BorderSizePixel = 0
	handbrakeBtn.Text = "⬜"
	handbrakeBtn.TextColor3 = Color3.new(0, 0, 0)
	handbrakeBtn.TextScaled = true
	handbrakeBtn.Font = Enum.Font.GothamBold
	handbrakeBtn.Parent = screenGui

	local hbCorner = Instance.new("UICorner")
	hbCorner.CornerRadius = UDim.new(1, 0)
	hbCorner.Parent = handbrakeBtn

	-- Gear shift buttons
	local gearFrame = Instance.new("Frame")
	gearFrame.Name = "GearShift"
	gearFrame.Size = UDim2.new(0, 80, 0, 160)
	gearFrame.Position = UDim2.new(1, -100, 0.5, -80)
	gearFrame.BackgroundTransparency = 1
	gearFrame.Parent = screenGui

	local shiftUp = Instance.new("TextButton")
	shiftUp.Size = UDim2.new(1, 0, 0.5, -5)
	shiftUp.Position = UDim2.new(0, 0, 0, 0)
	shiftUp.BackgroundColor3 = Color3.fromRGB(0, 255, 136)
	shiftUp.BackgroundTransparency = 0.3
	shiftUp.Text = "↑"
	shiftUp.TextColor3 = Color3.new(0, 0, 0)
	shiftUp.TextScaled = true
	shiftUp.Font = Enum.Font.GothamBold
	shiftUp.Parent = gearFrame

	local upCorner = Instance.new("UICorner")
	upCorner.CornerRadius = UDim.new(0, 12)
	upCorner.Parent = shiftUp

	local shiftDown = Instance.new("TextButton")
	shiftDown.Size = UDim2.new(1, 0, 0.5, -5)
	shiftDown.Position = UDim2.new(0, 0, 0.5, 5)
	shiftDown.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	shiftDown.BackgroundTransparency = 0.3
	shiftDown.Text = "↓"
	shiftDown.TextColor3 = Color3.new(1, 1, 1)
	shiftDown.TextScaled = true
	shiftDown.Font = Enum.Font.GothamBold
	shiftDown.Parent = gearFrame

	local downCorner = Instance.new("UICorner")
	downCorner.CornerRadius = UDim.new(0, 12)
	downCorner.Parent = shiftDown

	-- Touch event handlers
	local function SetupTouchButton(btn, actionName, isHold)
		local function onInputBegan(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				ContextActionService:CallFunction("Vehicle_" .. actionName, Enum.UserInputState.Begin, input)
			end
		end

		local function onInputEnded(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				ContextActionService:CallFunction("Vehicle_" .. actionName, Enum.UserInputState.End, input)
			end
		end

		btn.InputBegan:Connect(onInputBegan)
		btn.InputEnded:Connect(onInputEnded)

		if not isHold then
			btn.TouchTap:Connect(function()
				ContextActionService:CallFunction("Vehicle_" .. actionName, Enum.UserInputState.Begin, nil)
				task.wait(0.1)
				ContextActionService:CallFunction("Vehicle_" .. actionName, Enum.UserInputState.End, nil)
			end)
		end
	end

	SetupTouchButton(brakeBtn, "Brake", true)
	SetupTouchButton(throttleBtn, "Throttle", true)
	SetupTouchButton(handbrakeBtn, "Handbrake", true)
	SetupTouchButton(shiftUp, "ShiftUp", false)
	SetupTouchButton(shiftDown, "ShiftDown", false)

	-- Steering drag handling
	local steerCenter = Vector2.new(steerFrame.AbsolutePosition.X + 60, steerFrame.AbsolutePosition.Y + 60)
	local isDragging = false

	steerFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			isDragging = true
			UpdateSteering(input.Position)
		end
	end)

	steerFrame.InputChanged:Connect(function(input)
		if isDragging and input.UserInputType == Enum.UserInputType.Touch then
			UpdateSteering(input.Position)
		end
	end)

	steerFrame.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			isDragging = false
			vehicleInput.Steer = 0
		end
	end)

	UserInputService.TouchEnded:Connect(function(input)
		if isDragging then
			isDragging = false
			vehicleInput.Steer = 0
		end
	end)
end

local function UpdateSteering(touchPosition: Vector2)
	local steerFrame = game.Players.LocalPlayer.PlayerGui.TouchControls.Steering
	local center = Vector2.new(steerFrame.AbsolutePosition.X + 60, steerFrame.AbsolutePosition.Y + 60)
	local offset = touchPosition - center
	local distance = offset.Magnitude
	local maxRadius = 60

	if distance > maxRadius then
		offset = offset.Unit * maxRadius
	end

	-- Update knob position
	local knob = game.Players.LocalPlayer.PlayerGui.TouchControls.Steering.Knob
	knob.Position = UDim2.new(0.5, offset.X - 30, 0.5, offset.Y - 30)

	-- Calculate steer value (-1 to 1)
	vehicleInput.Steer = Utils.Clamp(offset.X / 60, -1, 1)
end

-- ============================================
- UI NAVIGATION (Gamepad)
- ============================================

local function BindUINavigation()
	ContextActionService:BindActionAtPriority("UI_NavigateUp", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.UINavigateUp:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.DPadUp, Enum.KeyCode.Up)

	ContextActionService:BindActionAtPriority("UI_NavigateDown", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.UINavigateDown:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.DPadDown, Enum.KeyCode.Down)

	ContextActionService:BindActionAtPriority("UI_NavigateLeft", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.UINavigateLeft:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.DPadLeft, Enum.KeyCode.Left)

	ContextActionService:BindActionAtPriority("UI_NavigateRight", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.UINavigateRight:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.DPadRight, Enum.KeyCode.Right)

	ContextActionService:BindActionAtPriority("UI_Confirm", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.UIConfirm:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.Return, Enum.KeyCode.ButtonA)

	ContextActionService:BindActionAtPriority("UI_Cancel", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.UICancel:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB)

	ContextActionService:BindActionAtPriority("UI_Back", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			Signals.GameSignals.UIBack:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Default.Value, Enum.KeyCode.Backspace, Enum.KeyCode.ButtonB)
end

-- ============================================
- INITIALIZATION
- ============================================

function InputManager.Initialize()
	Utils.DebugLog("InputManager initializing...")

	-- Detect initial input mode
	currentInputMode = DetectInputMode()
	Utils.DebugLog("Initial input mode:", currentInputMode)

	-- Listen for input mode changes
	UserInputService.LastInputTypeChanged:Connect(OnLastInputTypeChanged)

	-- Bind vehicle actions
	BindVehicleActions()

	-- Bind UI navigation
	BindUINavigation()

	-- Create touch controls if on mobile
	if UserInputService.TouchEnabled then
		CreateTouchControls()
	end

	-- Listen for gamepad connection changes
	UserInputService.GamepadConnected:Connect(function(gamepad)
		gamepadConnected = true
		Utils.DebugLog("Gamepad connected:", gamepad)
	end)

	UserInputService.GamepadDisconnected:Connect(function(gamepad)
		if not UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1) then
			gamepadConnected = false
		end
		Utils.DebugLog("Gamepad disconnected")
	end)

	-- Key state tracking
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed then
			keyStates[input.KeyCode] = true
		end
	end)

	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		keyStates[input.KeyCode] = false
	end)

	Utils.DebugLog("InputManager initialized")
end

-- ============================================
- PUBLIC API
- ============================================

function InputManager.GetCurrentInputMode(): string
	return currentInputMode
end

function InputManager.IsGamepadConnected(): boolean
	return gamepadConnected
end

function InputManager.GetVehicleInput(): { Throttle: number, Brake: number, Steer: number, Handbrake: boolean, Gear: number }
	return {
		Throttle = vehicleInput.Throttle,
		Brake = vehicleInput.Brake,
		Steer = vehicleInput.Steer,
		Handbrake = vehicleInput.Handbrake,
		Gear = vehicleInput.Gear,
	}
end

function InputManager.IsKeyDown(keyCode: Enum.KeyCode): boolean
	return keyStates[keyCode] == true
end

function InputManager.SetVehicleInputEnabled(enabled: boolean)
	if enabled then
		BindVehicleActions()
	else
		UnbindVehicleActions()
	end
end

function InputManager.GetCurrentInputMode(): string
	return currentInputMode
end

function InputManager.OnInputModeChanged(newMode: string)
	Utils.DebugLog("Input mode changed to:", newMode)

	if newMode == "Touch" then
		-- Show touch controls
		local touchGui = game.Players.LocalPlayer.PlayerGui:FindFirstChild("TouchControls")
		if touchGui then touchGui.Enabled = true end
	else
		-- Hide touch controls
		local touchGui = game.Players.LocalPlayer.PlayerGui:FindFirstChild("TouchControls")
		if touchGui then touchGui.Enabled = false end
	end
end

function InputManager.Cleanup()
	UnbindVehicleActions()
	for _, actionName in ipairs(UI_NAVIGATION_ACTIONS) do
		ContextActionService:UnbindAction("UI_" .. actionName)
	end
end

Utils.DebugLog("InputManager initialized")

return InputManager