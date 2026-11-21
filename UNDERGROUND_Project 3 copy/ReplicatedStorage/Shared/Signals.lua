--[[
	UNDERGROUND — Signal/Event System
	Lightweight, typed event system for decoupled communication.
	Supports both synchronous and asynchronous connections.
]]

local Signals = {}

-- ============================================
-- SIGNAL CLASS
-- ============================================

export type Connection = {
	Disconnect: (self: Connection) -> (),
	Connected: boolean,
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	Destroy: (self: Signal<T...>) -> (),
}

-- ============================================
-- SIGNAL IMPLEMENTATION
-- ============================================

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({}, Signal)
	self._connections = {}
	self._waitingThreads = {}
	return self
end

function Signal:Connect(callback: (...any) -> ()): Connection
	local connection = {
		_callback = callback,
		_connected = true,
		_signal = self,
	}

	function connection:Disconnect()
		if not self._connected then return end
		self._connected = false

		local connections = self._signal._connections
		for i, conn in ipairs(connections) do
			if conn == self then
				table.remove(connections, i)
				break
			end
		end
	end

	table.insert(self._connections, connection)
	return connection
end

function Signal:Once(callback: (...any) -> ()): Connection
	local connection
	connection = self:Connect(function(...)
		connection:Disconnect()
		callback(...)
	end)
	return connection
end

function Signal:Fire(...: any)
	-- Fire all connected callbacks
	for _, connection in ipairs(self._connections) do
		if connection._connected then
			task.spawn(connection._callback, ...)
		end
	end

	-- Resume waiting threads
	for _, thread in ipairs(self._waitingThreads) do
		task.spawn(thread, ...)
	end
	table.clear(self._waitingThreads)
end

function Signal:Wait(...: any): ...any
	local thread = coroutine.running()
	table.insert(self._waitingThreads, thread)
	return coroutine.yield()
end

function Signal:Destroy()
	for _, connection in ipairs(self._connections) do
		connection._connected = false
	end
	table.clear(self._connections)
	table.clear(self._waitingThreads)
	setmetatable(self, nil)
end

function Signal:GetConnectionCount(): number
	local count = 0
	for _, conn in ipairs(self._connections) do
		if conn._connected then count += 1 end
	end
	return count
end

-- ============================================
-- ASYNC SIGNAL (Promise-based)
-- ============================================

export type AsyncSignal<T...> = {
	Connect: (self: AsyncSignal<T...>, callback: (T...) -> ()) -> Connection,
	Fire: (self: AsyncSignal<T...>, T...) -> (),
	Wait: (self: AsyncSignal<T...>) -> T...,
	Destroy: (self: AsyncSignal<T...>) -> (),
}

local AsyncSignal = {}
AsyncSignal.__index = AsyncSignal

function AsyncSignal.new<T...>(): AsyncSignal<T...>
	local self = setmetatable({}, AsyncSignal)
	self._callbacks = {}
	self._waitingThreads = {}
	return self
end

function AsyncSignal:Connect(callback: (...any) -> ()): Connection
	local connection = {
		_callback = callback,
		_connected = true,
		_signal = self,
	}

	function connection:Disconnect()
		if not self._connected then return end
		self._connected = false
		local callbacks = self._callbacks
		for i, cb in ipairs(callbacks) do
			if cb == connection then
				table.remove(callbacks, i)
				break
			end
		end
	end

	table.insert(self._callbacks, connection)
	return connection
end

function AsyncSignal:Fire(...: any)
	-- Fire all callbacks asynchronously
	for _, connection in ipairs(self._callbacks) do
		if connection._connected then
			task.spawn(connection._callback, ...)
		end
	end

	-- Resume waiting threads
	for _, thread in ipairs(self._waitingThreads) do
		task.spawn(thread, ...)
	end
	table.clear(self._waitingThreads)
end

function AsyncSignal:Wait(...: any): ...any
	local thread = coroutine.running()
	table.insert(self._waitingThreads, thread)
	return coroutine.yield()
end

function AsyncSignal:Destroy()
	table.clear(self._callbacks)
	table.clear(self._waitingThreads)
	setmetatable(self, nil)
end

-- ============================================
-- PROPERTY BINDER (Reactive)
-- ============================================

export type Property<T> = {
	Get: (self: Property<T>) -> T,
	Set: (self: Property<T>, value: T) -> (),
	Changed: Signal<T>,
	Destroy: (self: Property<T>) -> (),
}

local Property = {}
Property.__index = Property

function Property.new<T>(initialValue: T): Property<T>
	local self = setmetatable({}, Property)
	self._value = initialValue
	self.Changed = Signal.new()
	return self
end

function Property:Get(): any
	return self._value
end

function Property:Set(newValue: any)
	if self._value == newValue then return end
	local oldValue = self._value
	self._value = newValue
	self.Changed:Fire(newValue, oldValue)
end

function Property:Destroy()
	self.Changed:Destroy()
	setmetatable(self, nil)
end

-- ============================================
-- EVENT BUS (Global)
-- ============================================

export type EventBus = {
	Emit: (self: EventBus, eventName: string, ...any) -> (),
	On: (self: EventBus, eventName: string, callback: (...any) -> ()) -> Connection,
	Once: (self: EventBus, eventName: string, callback: (...any) -> ()) -> Connection,
	Off: (self: EventBus, eventName: string, callback: (...any) -> ()) -> (),
	Wait: (self: EventBus, eventName: string) -> ...any,
	Clear: (self: EventBus, eventName: string?) -> (),
}

local EventBus = {}
EventBus.__index = EventBus

function EventBus.new(): EventBus
	local self = setmetatable({}, EventBus)
	self._events = {} -- [eventName] = Signal
	return self
end

function EventBus:_getSignal(eventName: string): Signal
	if not self._events[eventName] then
		self._events[eventName] = Signal.new()
	end
	return self._events[eventName]
end

function EventBus:Emit(eventName: string, ...: any)
	local signal = self._events[eventName]
	if signal then
		signal:Fire(...)
	end
end

function EventBus:On(eventName: string, callback: (...any) -> ()): Connection
	return self:_getSignal(eventName):Connect(callback)
end

function EventBus:Once(eventName: string, callback: (...any) -> ()): Connection
	return self:_getSignal(eventName):Once(callback)
end

function EventBus:Off(eventName: string, callback: (...any) -> ())
	local signal = self._events[eventName]
	if signal then
		-- Note: Can't easily remove specific callback without connection object
		-- This is a limitation - user should keep Connection object
	end
end

function EventBus:Wait(eventName: string): ...any
	return self:_getSignal(eventName):Wait()
end

function EventBus:Clear(eventName: string?)
	if eventName then
		local signal = self._events[eventName]
		if signal then
			signal:Destroy()
			self._events[eventName] = nil
		end
	else
		for _, signal in pairs(self._events) do
			signal:Destroy()
		end
		table.clear(self._events)
	end
end

-- Global event bus instance
Signals.GlobalEventBus = EventBus.new()

-- ============================================
-- NETWORK SIGNALS (RemoteEvent wrappers)
-- ============================================

export type NetworkSignal<T...> = {
	FireServer: (self: NetworkSignal<T...>, T...) -> (),
	FireClient: (self: NetworkSignal<T...>, player: Player, T...) -> (),
	FireAllClients: (self: NetworkSignal<T...>, T...) -> (),
	OnServerEvent: Signal<T...>,
	OnClientEvent: Signal<T...>,
}

local NetworkSignal = {}
NetworkSignal.__index = NetworkSignal

function NetworkSignal.new(remoteEvent: RemoteEvent): NetworkSignal
	local self = setmetatable({}, NetworkSignal)
	self._remote = remoteEvent
	self.OnServerEvent = Signal.new()
	self.OnClientEvent = Signal.new()

	if game:GetService("RunService"):IsServer() then
		self._remote.OnServerEvent:Connect(function(player, ...)
			self.OnServerEvent:Fire(player, ...)
		end)
	else
		self._remote.OnClientEvent:Connect(function(...)
			self.OnClientEvent:Fire(...)
		end)
	end

	return self
end

function NetworkSignal:FireServer(...: any)
	self._remote:FireServer(...)
end

function NetworkSignal:FireClient(player: Player, ...: any)
	self._remote:FireClient(player, ...)
end

function NetworkSignal:FireAllClients(...: any)
	self._remote:FireAllClients(...)
end

function NetworkSignal:FireAllClientsExcept(exceptPlayer: Player, ...: any)
	for _, player in ipairs(game.Players:GetPlayers()) do
		if player ~= exceptPlayer then
			self._remote:FireClient(player, ...)
		end
	end
end

-- ============================================
-- REMOTE FUNCTION WRAPPER
-- ============================================

export type NetworkFunction<T..., R> = {
	InvokeServer: (self: NetworkFunction<T..., R>, T...) -> R,
	InvokeClient: (self: NetworkFunction<T..., R>, player: Player, T...) -> R,
	OnServerInvoke: (self: NetworkFunction<T..., R>, callback: (player: Player, T...) -> R) -> (),
	OnClientInvoke: (self: NetworkFunction<T..., R>, callback: (T...) -> R) -> (),
}

local NetworkFunction = {}
NetworkFunction.__index = NetworkFunction

function NetworkFunction.new(remoteFunction: RemoteFunction): NetworkFunction
	local self = setmetatable({}, NetworkFunction)
	self._remote = remoteFunction
	return self
end

function NetworkFunction:InvokeServer(...: any): any
	return self._remote:InvokeServer(...)
end

function NetworkFunction:InvokeClient(player: Player, ...: any): any
	return self._remote:InvokeClient(player, ...)
end

function NetworkFunction:OnServerInvoke(callback: (Player, ...any) -> any)
	self._remote.OnServerInvoke = callback
end

function NetworkFunction:OnClientInvoke(callback: (...any) -> any)
	self._remote.OnClientInvoke = callback
end

-- ============================================
-- FACTORY FUNCTIONS
-- ============================================

function Signals.CreateSignal<T...>(): Signal<T...>
	return Signal.new()
end

function Signals.CreateAsyncSignal<T...>(): AsyncSignal<T...>
	return AsyncSignal.new()
end

function Signals.CreateProperty<T>(initialValue: T): Property<T>
	return Property.new(initialValue)
end

function Signals.CreateEventBus(): EventBus
	return EventBus.new()
end

function Signals.CreateNetworkSignal(remoteEvent: RemoteEvent): NetworkSignal
	return NetworkSignal.new(remoteEvent)
end

function Signals.CreateNetworkFunction(remoteFunction: RemoteFunction): NetworkFunction
	return NetworkFunction.new(remoteFunction)
end

-- ============================================
-- PREDEFINED GAME SIGNALS
-- ============================================

Signals.GameSignals = {
	-- Player lifecycle
	PlayerLoaded = Signal.new(),
	PlayerUnloaded = Signal.new(),
	PlayerDataChanged = Signal.new(),

	-- Contracts
	ContractCreated = Signal.new(),
	ContractAccepted = Signal.new(),
	ContractCompleted = Signal.new(),
	ContractFailed = Signal.new(),
	ContractExpired = Signal.new(),

	-- Delivery
	DeliveryStarted = Signal.new(),
	DeliveryProgress = Signal.new(),
	DeliveryCompleted = Signal.new(),
	DeliveryFailed = Signal.new(),

	-- Heat/Police
	HeatChanged = Signal.new(),
	HeatLevelUp = Signal.new(),
	HeatLevelDown = Signal.new(),
	PoliceSpawned = Signal.new(),
	PoliceDespawned = Signal.new(),
	PursuitStarted = Signal.new(),
	PursuitEnded = Signal.new(),

	-- Vehicle
	VehicleSpawned = Signal.new(),
	VehicleDespawned = Signal.new(),
	VehicleUpgraded = Signal.new(),
	VehicleDamaged = Signal.new(),
	VehicleDestroyed = Signal.new(),
	FuelChanged = Signal.new(),

	-- Progression
	LevelUp = Signal.new(),
	XPGained = Signal.new(),
	PrestigeUp = Signal.new(),
	UnlockEarned = Signal.new(),

	-- Economy
	CashChanged = Signal.new(),
	CurrencyEarned = Signal.new(),
	CurrencySpent = Signal.new(),

	-- Hideout
	HideoutUpgraded = Signal.new(),
	HideoutIncomeReady = Signal.new(),

	-- Social
	PartyInvited = Signal.new(),
	PartyJoined = Signal.new(),
	PartyLeft = Signal.new(),
	FriendOnline = Signal.new(),
	FriendOffline = Signal.new(),

	-- UI
	ScreenOpened = Signal.new(),
	ScreenClosed = Signal.new(),
	NotificationQueued = Signal.new(),

	-- Game state
	GameStarted = Signal.new(),
	GameEnded = Signal.new(),
	RoundStarted = Signal.new(),
	RoundEnded = Signal.new(),

	-- Events
	EventStarted = Signal.new(),
	EventEnded = Signal.new(),
	EventProgress = Signal.new(),

	-- Settings
	SettingsChanged = Signal.new(),

	-- Debug
	DebugLog = Signal.new(),
	ErrorOccurred = Signal.new(),
}

-- ============================================
-- HELPER: Create all game signals at once
-- ============================================

function Signals.InitializeGameSignals(): { [string]: Signal }
	local signals = {}
	for name, signal in pairs(Signals.GameSignals) do
		signals[name] = signal
	end
	return signals
end

-- ============================================
-- EXPORT
-- ============================================

return Signals