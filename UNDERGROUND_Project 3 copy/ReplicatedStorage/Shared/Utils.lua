--[[
	UNDERGROUND — Shared Utilities
	Common helper functions for math, strings, tables, validation, and formatting.
	Used by both client and server.
]]

local Constants = require(script.Parent.Constants)

local Utils = {}

-- ============================================
-- MATH UTILITIES
-- ============================================

function Utils.Lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Utils.InverseLerp(a: number, b: number, v: number): number
	if a == b then return 0 end
	return (v - a) / (b - a)
end

function Utils.Remap(v: number, a1: number, b1: number, a2: number, b2: number): number
	return Utils.Lerp(a2, b2, Utils.InverseLerp(a1, b1, v))
end

function Utils.Clamp(v: number, min: number, max: number): number
	return math.max(min, math.min(max, v))
end

function Utils.Round(num: number, decimals: number?): number
	local mult = 10 ^ (decimals or 0)
	return math.floor(num * mult + 0.5) / mult
end

function Utils.RoundToNearest(num: number, nearest: number): number
	return math.floor(num / nearest + 0.5) * nearest
end

function Utils.Distance(pos1: Vector3, pos2: Vector3): number
	return (pos1 - pos2).Magnitude
end

function Utils.Distance2D(pos1: Vector3, pos2: Vector3): number
	return Vector2.new(pos1.X - pos2.X, pos1.Z - pos2.Z).Magnitude
end

function Utils.AngleBetween(v1: Vector3, v2: Vector3): number
	return math.acos(Utils.Clamp(v1.Unit:Dot(v2.Unit), -1, 1))
end

function Utils.SignedAngle(from: Vector3, to: Vector3, axis: Vector3): number
	local angle = Utils.AngleBetween(from, to)
	local cross = from:Cross(to)
	if cross:Dot(axis) < 0 then
		return -angle
	end
	return angle
end

function Utils.EaseInOutQuad(t: number): number
	return t < 0.5 and 2 * t * t or 1 - 2 * (1 - t) * (1 - t)
end

function Utils.EaseOutQuart(t: number): number
	return 1 - (1 - t) ^ 4
end

function Utils.EaseInOutCubic(t: number): number
	return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2
end

function Utils.SpringUpdate(position: number, velocity: number, target: number, stiffness: number, damping: number, dt: number): (number, number)
	local force = stiffness * (target - position) - damping * velocity
	local newVelocity = velocity + force * dt
	local newPosition = position + newVelocity * dt
	return newPosition, newVelocity
end

-- ============================================
-- VECTOR UTILITIES
-- ============================================

function Utils.Flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

function Utils.SetY(vector: Vector3, y: number): Vector3
	return Vector3.new(vector.X, y, vector.Z)
end

function Utils.ProjectOnPlane(vector: Vector3, planeNormal: Vector3): Vector3
	return vector - vector:Dot(planeNormal) * planeNormal
end

function Utils.RandomInRadius(radius: number): Vector3
	local angle = math.random() * math.pi * 2
	local r = math.sqrt(math.random()) * radius
	return Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
end

function Utils.RandomOnSphere(radius: number): Vector3
	local u = math.random()
	local v = math.random()
	local theta = 2 * math.pi * u
	local phi = math.acos(2 * v - 1)
	local x = radius * math.sin(phi) * math.cos(theta)
	local y = radius * math.sin(phi) * math.sin(theta)
	local z = radius * math.cos(phi)
	return Vector3.new(x, y, z)
end

function Utils.GetBoundingBox(parts: { BasePart }): (Vector3, Vector3)
	local min = Vector3.new(math.huge, math.huge, math.huge)
	local max = Vector3.new(-math.huge, -math.huge, -math.huge)

	for _, part in ipairs(parts) do
		local cf, size = part.CFrame, part.Size
		local corners = {
			cf * Vector3.new(-size.X/2, -size.Y/2, -size.Z/2),
			cf * Vector3.new(size.X/2, -size.Y/2, -size.Z/2),
			cf * Vector3.new(-size.X/2, size.Y/2, -size.Z/2),
			cf * Vector3.new(size.X/2, size.Y/2, -size.Z/2),
			cf * Vector3.new(-size.X/2, -size.Y/2, size.Z/2),
			cf * Vector3.new(size.X/2, -size.Y/2, size.Z/2),
			cf * Vector3.new(-size.X/2, size.Y/2, size.Z/2),
			cf * Vector3.new(size.X/2, size.Y/2, size.Z/2),
		}

		for _, corner in ipairs(corners) do
			min = Vector3.new(math.min(min.X, corner.X), math.min(min.Y, corner.Y), math.min(min.Z, corner.Z))
			max = Vector3.new(math.max(max.X, corner.X), math.max(max.Y, corner.Y), math.max(max.Z, corner.Z))
		end
	end

	return min, max
end

-- ============================================
-- TABLE UTILITIES
-- ============================================

function Utils.DeepCopy<T>(original: T): T
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			copy[k] = Utils.DeepCopy(v)
		else
			copy[k] = v
		end
	end
	return copy
end

function Utils.DeepMerge(target: { [any]: any }, source: { [any]: any }): { [any]: any }
	for k, v in pairs(source) do
		if type(v) == "table" and type(target[k]) == "table" then
			target[k] = Utils.DeepMerge(target[k], v)
		else
			target[k] = v
		end
	end
	return target
end

function Utils.ShallowCopy<T>(original: T): T
	local copy = {}
	for k, v in pairs(original) do
		copy[k] = v
	end
	return copy
end

function Utils.TableLength(t: { [any]: any }): number
	local count = 0
	for _ in pairs(t) do count += 1 end
	return count
end

function Utils.Keys(t: { [any]: any }): { any }
	local keys = {}
	for k in pairs(t) do table.insert(keys, k) end
	return keys
end

function Utils.Values(t: { [any]: any }): { any }
	local vals = {}
	for _, v in pairs(t) do table.insert(vals, v) end
	return vals
end

function Utils.Filter<T>(t: { T }, predicate: (T) -> boolean): { T }
	local result = {}
	for _, v in ipairs(t) do
		if predicate(v) then table.insert(result, v) end
	end
	return result
end

function Utils.Map<T, U>(t: { T }, transform: (T) -> U): { U }
	local result = {}
	for _, v in ipairs(t) do
		table.insert(result, transform(v))
	end
	return result
end

function Utils.Reduce<T, U>(t: { T }, initial: U, reducer: (U, T) -> U): U
	local acc = initial
	for _, v in ipairs(t) do
		acc = reducer(acc, v)
	end
	return acc
end

function Utils.Find<T>(t: { T }, predicate: (T) -> boolean): (T?, number?)
	for i, v in ipairs(t) do
		if predicate(v) then return v, i end
	end
	return nil, nil
end

function Utils.FindIndex<T>(t: { T }, predicate: (T) -> boolean): number?
	for i, v in ipairs(t) do
		if predicate(v) then return i end
	end
	return nil
end

function Utils.Contains<T>(t: { T }, value: T): boolean
	for _, v in ipairs(t) do
		if v == value then return true end
	end
	return false
end

function Utils.Unique<T>(t: { T }): { T }
	local seen = {}
	local result = {}
	for _, v in ipairs(t) do
		if not seen[v] then
			seen[v] = true
			table.insert(result, v)
		end
	end
	return result
end

function Utils.Shuffle<T>(t: { T }): { T }
	local result = Utils.ShallowCopy(t)
	for i = #result, 2, -1 do
		local j = math.random(i)
		result[i], result[j] = result[j], result[i]
	end
	return result
end

function Utils.WeightedRandom<T>(items: { T }, weightFn: (T) -> number): T?
	local totalWeight = 0
	for _, item in ipairs(items) do
		totalWeight += weightFn(item)
	end
	if totalWeight <= 0 then return nil end

	local roll = math.random() * totalWeight
	local currentWeight = 0
	for _, item in ipairs(items) do
		currentWeight += weightFn(item)
		if roll <= currentWeight then return item end
	end
	return items[#items]
end

-- ============================================
-- STRING UTILITIES
-- ============================================

function Utils.FormatNumber(num: number, useSuffix: boolean?): string
	if not useSuffix then
		return tostring(math.floor(num))
	end

	if num >= 1e9 then
		return string.format("%.1fB", num / 1e9)
	elseif num >= 1e6 then
		return string.format("%.1fM", num / 1e6)
	elseif num >= 1e3 then
		return string.format("%.1fK", num / 1e3)
	else
		return tostring(math.floor(num))
	end
end

function Utils.FormatCurrency(amount: number): string
	return Constants.FormatCurrency(amount)
end

function Utils.FormatTime(seconds: number, short: boolean?): string
	if short then
		if seconds >= 3600 then
			return string.format("%.1fh", seconds / 3600)
		elseif seconds >= 60 then
			return string.format("%.1fm", seconds / 60)
		else
			return string.format("%.0fs", seconds)
		end
	end
	return Constants.FormatTime(seconds)
end

function Utils.FormatDate(timestamp: number, format: string?): string
	return os.date(format or "%Y-%m-%d %H:%M", timestamp)
end

function Utils.FormatTimeAgo(timestamp: number): string
	local diff = os.time() - timestamp
	if diff < 60 then
		return "just now"
	elseif diff < 3600 then
		return string.format("%dm ago", math.floor(diff / 60))
	elseif diff < 86400 then
		return string.format("%dh ago", math.floor(diff / 3600))
	elseif diff < 604800 then
		return string.format("%dd ago", math.floor(diff / 86400))
	else
		return string.format("%dw ago", math.floor(diff / 604800))
	end
end

function Utils.Truncate(str: string, maxLen: number, suffix: string?): string
	if #str <= maxLen then return str end
	return str:sub(1, maxLen - (suffix and #suffix or 3)) .. (suffix or "...")
end

function Utils.Capitalize(str: string): string
	return str:sub(1, 1):upper() .. str:sub(2):lower()
end

function Utils.TitleCase(str: string): string
	return str:gsub("(%a)([%w_']*)", function(first, rest)
		return first:upper() .. rest:lower()
	end)
end

function Utils.Split(str: string, delimiter: string): { string }
	local result = {}
	local pattern = "([^" .. delimiter .. "]+)"
	for match in str:gmatch(pattern) do
		table.insert(result, match)
	end
	return result
end

function Utils.Join(tbl: { string }, delimiter: string): string
	return table.concat(tbl, delimiter)
end

function Utils.PadLeft(str: string, length: number, char: string?): string
	char = char or " "
	return string.rep(char, math.max(0, length - #str)) .. str
end

function Utils.PadRight(str: string, length: number, char: string?): string
	char = char or " "
	return str .. string.rep(char, math.max(0, length - #str))
end

function Utils.GenerateID(prefix: string?): string
	local timestamp = os.time()
	local random = math.random(100000, 999999)
	return (prefix or "ID") .. "_" .. timestamp .. "_" .. random
end

function Utils.GenerateUUID(): string
	local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
	return template:gsub("[xy]", function(c)
		local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
		return string.format("%x", v)
	end)
end

-- ============================================
-- VALIDATION UTILITIES
-- ============================================

function Utils.ValidatePlayerProfile(data: any): (boolean, string?)
	if type(data) ~= "table" then return false, "Not a table" end
	if type(data.UserId) ~= "number" then return false, "Missing UserId" end
	if type(data.Level) ~= "number" then return false, "Missing Level" end
	if type(data.Cash) ~= "number" then return false, "Missing Cash" end
	return true, nil
end

function Utils.ValidateVehicleInstance(data: any): (boolean, string?)
	if type(data) ~= "table" then return false, "Not a table" end
	if type(data.Id) ~= "string" then return false, "Missing Id" end
	if type(data.Category) ~= "string" then return false, "Missing Category" end
	if type(data.Upgrades) ~= "table" then return false, "Missing Upgrades" end
	return true, nil
end

function Utils.ValidatePackageInstance(data: any): (boolean, string?)
	if type(data) ~= "table" then return false, "Not a table" end
	if type(data.Id) ~= "string" then return false, "Missing Id" end
	if type(data.Rarity) ~= "string" then return false, "Missing Rarity" end
	if type(data.Type) ~= "string" then return false, "Missing Type" end
	return true, nil
end

function Utils.ValidateContractInstance(data: any): (boolean, string?)
	if type(data) ~= "table" then return false, "Not a table" end
	if type(data.Id) ~= "string" then return false, "Missing Id" end
	if type(data.Type) ~= "string" then return false, "Missing Type" end
	if type(data.Status) ~= "string" then return false, "Missing Status" end
	return true, nil
end

function Utils.SanitizeInput(input: string, maxLength: number?): string
	local clean = input:gsub("[<>\"'&]", "")
	if maxLength and #clean > maxLength then
		clean = clean:sub(1, maxLength)
	end
	return clean
end

function Utils.IsValidUsername(name: string): boolean
	return #name >= 3 and #name <= 20 and name:match("^[%w_]+$") ~= nil
end

-- ============================================
-- COLOR UTILITIES
-- ============================================

function Utils.LerpColor(c1: Color3, c2: Color3, t: number): Color3
	return Color3.new(
		Utils.Lerp(c1.R, c2.R, t),
		Utils.Lerp(c1.G, c2.G, t),
		Utils.Lerp(c1.B, c2.B, t)
	)
end

function Utils.ColorFromHex(hex: string): Color3
	hex = hex:gsub("#", "")
	if #hex == 3 then
		hex = hex:gsub("(.)", "%1%1")
	end
	local r = tonumber(hex:sub(1, 2), 16) / 255
	local g = tonumber(hex:sub(3, 4), 16) / 255
	local b = tonumber(hex:sub(5, 6), 16) / 255
	return Color3.new(r, g, b)
end

function Utils.ColorToHex(color: Color3): string
	return string.format("#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

function Utils.Brighten(color: Color3, amount: number): Color3
	return Color3.new(
		Utils.Clamp(color.R + amount, 0, 1),
		Utils.Clamp(color.G + amount, 0, 1),
		Utils.Clamp(color.B + amount, 0, 1)
	)
end

function Utils.Darken(color: Color3, amount: number): Color3
	return Color3.new(
		Utils.Clamp(color.R - amount, 0, 1),
		Utils.Clamp(color.G - amount, 0, 1),
		Utils.Clamp(color.B - amount, 0, 1)
	)
end

function Utils.Saturate(color: Color3, amount: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, Utils.Clamp(s * amount, 0, 1), v)
end

-- ============================================
-- INSTANCE UTILITIES
-- ============================================

function Utils.Create(className: string, properties: { [string]: any }, children: { Instance }?): Instance
	local instance = Instance.new(className)
	for prop, value in pairs(properties) do
		instance[prop] = value
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	return instance
end

function Utils.DestroyChildren(parent: Instance, className: string?)
	for _, child in ipairs(parent:GetChildren()) do
		if not className or child:IsA(className) then
			child:Destroy()
		end
	end
end

function Utils.GetDescendantsOfClass(parent: Instance, className: string): { Instance }
	local result = {}
	for _, descendant in ipairs(parent:GetDescendants()) do
		if descendant:IsA(className) then
			table.insert(result, descendant)
		end
	end
	return result
end

function Utils.WaitForChildOfClass(parent: Instance, className: string, timeout: number?): Instance?
	local start = tick()
	while true do
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA(className) then return child end
		end
		if timeout and tick() - start > timeout then return nil end
		task.wait(0.1)
	end
end

function Utils.CloneWithProperties(source: Instance, properties: { [string]: any }): Instance
	local clone = source:Clone()
	for prop, value in pairs(properties) do
		clone[prop] = value
	end
	return clone
end

-- ============================================
-- TIME UTILITIES
-- ============================================

function Utils.GetServerTime(): number
	return workspace:GetServerTimeNow()
end

function Utils.GetUnixTime(): number
	return os.time()
end

function Utils.TimeUntil(targetTimestamp: number): number
	return math.max(0, targetTimestamp - Utils.GetUnixTime())
end

function Utils.IsExpired(timestamp: number): boolean
	return Utils.GetUnixTime() >= timestamp
end

function Utils.AddTime(base: number, seconds: number): number
	return base + seconds
end

function Utils.StartOfDay(timestamp: number?): number
	local t = timestamp or Utils.GetUnixTime()
	return t - (t % 86400)
end

function Utils.EndOfDay(timestamp: number?): number
	return Utils.StartOfDay(timestamp) + 86400
end

function Utils.StartOfWeek(timestamp: number?): number
	local t = timestamp or Utils.GetUnixTime()
	local day = os.date("*t", t).wday -- 1 = Sunday
	return Utils.StartOfDay(t) - (day - 1) * 86400
end

-- ============================================
-- BITWISE UTILITIES (for flags)
-- ============================================

function Utils.SetFlag(flags: number, flag: number): number
	return bit32.bor(flags, flag)
end

function Utils.ClearFlag(flags: number, flag: number): number
	return bit32.band(flags, bit32.bnot(flag))
end

function Utils.HasFlag(flags: number, flag: number): boolean
	return bit32.band(flags, flag) ~= 0
end

function Utils.ToggleFlag(flags: number, flag: number): number
	return bit32.bxor(flags, flag)
end

-- ============================================
-- DEBUG / DEVELOPMENT
-- ============================================

Utils.DebugEnabled = false

function Utils.DebugLog(...)
	if Utils.DebugEnabled then
		print("[DEBUG]", os.date("%H:%M:%S"), ...)
	end
end

function Utils.DebugWarn(...)
	if Utils.DebugEnabled then
		warn("[DEBUG]", os.date("%H:%M:%S"), ...)
	end
end

function Utils.Assert(condition: boolean, message: string)
	if not condition then
		error("[ASSERTION FAILED] " .. message, 2)
	end
end

function Utils.TryCatch(fn: () -> any, onError: (string) -> ()): (boolean, any?)
	local success, result = pcall(fn)
	if not success then
		onError(result)
		return false, nil
	end
	return true, result
end

function Utils.Retry(fn: () -> any, maxAttempts: number?, delay: number?): (boolean, any?)
	maxAttempts = maxAttempts or 3
	delay = delay or 0.5

	for attempt = 1, maxAttempts do
		local success, result = pcall(fn)
		if success then return true, result end

		if attempt < maxAttempts then
			task.wait(delay * attempt) -- Exponential backoff
		end
	end
	return false, nil
end

-- ============================================
-- PERFORMANCE MONITORING
-- ============================================

local _perfMarks = {}

function Utils.PerfBegin(label: string)
	_perfMarks[label] = os.clock()
end

function Utils.PerfEnd(label: string): number
	local start = _perfMarks[label]
	if not start then return 0 end
	local elapsed = os.clock() - start
	_perfMarks[label] = nil
	return elapsed * 1000 -- milliseconds
end

function Utils.PerfPrint(label: string)
	local ms = Utils.PerfEnd(label)
	print(string.format("[PERF] %s: %.2fms", label, ms))
	return ms
end

-- ============================================
-- EXPORT
-- ============================================

return Utils