--[[
	UNDERGROUND — Economy Server
	Server-authoritative currency system with transaction logging, anti-exploit,
	and monetization integration.
]]

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)
local PlayerDataServer = require(script.Parent.PlayerDataServer)

local EconomyServer = {}

-- ============================================
-- TRANSACTION LOGGING
-- ============================================

local transactionLog = {} -- [userId] = { transactions }
local MAX_TRANSACTION_HISTORY = 100

local function LogTransaction(userId: number, transaction: { [string]: any })
	if not transactionLog[userId] then
		transactionLog[userId] = {}
	end

	transaction.Timestamp = os.time()
	transaction.TransactionId = Utils.GenerateUUID()

	table.insert(transactionLog[userId], 1, transaction)

	-- Trim history
	while #transactionLog[userId] > MAX_TRANSACTION_HISTORY do
		table.remove(transactionLog[userId])
	end
end

-- ============================================
-- CURRENCY OPERATIONS
-- ============================================

--[[
	Add cash to player with full validation and logging.
	Returns: success, newBalance, error
]]
function EconomyServer.AddCash(userId: number, amount: number, source: string?, metadata: { [string]: any }?): (boolean, number?, string?)
	if amount == 0 then return true, nil, "Zero amount" end

	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then
		return false, nil, "Player not found"
	end

	-- Validate amount
	if amount ~= amount or amount == math.huge or amount == -math.huge then
		return false, nil, "Invalid amount"
	end

	-- Check for overflow
	local newBalance = profile.Cash + amount
	if newBalance < 0 then
		return false, nil, "Insufficient funds"
	end
	if newBalance > 1e12 then -- 1 trillion cap
		return false, nil, "Balance overflow"
	end

	-- Apply
	local success = PlayerDataServer.AddCash(userId, amount, source)
	if not success then
		return false, nil, "Failed to update profile"
	end

	-- Log transaction
	LogTransaction(userId, {
		Type = amount > 0 and "Credit" or "Debit",
		Amount = amount,
		Source = source or "Unknown",
		NewBalance = newBalance,
		Metadata = metadata or {},
	})

	-- Fire signals
	Signals.GameSignals.CashChanged:Fire(userId, newBalance, amount, source)
	if amount > 0 then
		Signals.GameSignals.CurrencyEarned:Fire(userId, amount, source, metadata)
	else
		Signals.GameSignals.CurrencySpent:Fire(userId, -amount, source, metadata)
	end

	return true, newBalance, nil
end

--[[
	Spend cash with validation.
	Returns: success, newBalance, error
]]
function EconomyServer.SpendCash(userId: number, amount: number, source: string?, metadata: { [string]: any }?): (boolean, number?, string?)
	if amount <= 0 then return false, nil, "Invalid spend amount" end
	return EconomyServer.AddCash(userId, -amount, source, metadata)
end

--[[
	Get player's current cash balance.
]]
function EconomyServer.GetCash(userId: number): number
	local profile = PlayerDataServer.GetProfile(userId)
	return profile and profile.Cash or 0
end

-- ============================================
-- PURCHASE VALIDATION
-- ============================================

local function ValidatePurchase(userId: number, cost: number): (boolean, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, "Player not loaded" end

	if profile.Cash < cost then
		return false, "Insufficient funds"
	end

	return true, nil
end

-- ============================================
-- VEHICLE ECONOMY
-- ============================================

--[[
	Purchase a vehicle for cash.
	Returns: success, vehicleInstance, error
]]
function EconomyServer.PurchaseVehicle(userId: number, categoryName: string, modelName: string, customizations: { [string]: any }?): (boolean, any?, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, nil, "Player not found" end

	-- Validate category
	local category = Constants.GetVehicleCategory(categoryName)
	if not category then
		return false, nil, "Invalid vehicle category"
	end

	-- Check unlock
	if profile.Level < category.UnlockLevel then
		return false, nil, string.format("Requires level %d", category.UnlockLevel)
	end

	-- Check if already owns this category (limit per category)
	local ownedInCategory = 0
	for _, vehicle in ipairs(profile.VehicleGarage) do
		if vehicle.Category == categoryName then
			ownedInCategory += 1
		end
	end

	if ownedInCategory >= category.Slots then
		return false, nil, "Max vehicles for this category reached"
	end

	-- Calculate price
	local basePrice = Constants.Economy.VehicleBasePrices[categoryName] or 0
	local finalPrice = basePrice

	-- Apply first vehicle discount
	if #profile.VehicleGarage == 0 then
		finalPrice = 0
	end

	-- Validate funds
	if profile.Cash < finalPrice then
		return false, nil, "Insufficient funds"
	end

	-- Create vehicle instance
	local vehicleInstance = {
		Id = Utils.GenerateUUID(),
		Category = categoryName,
		ModelName = modelName,
		Upgrades = {}, -- All slots at level 0
		Durability = 100,
		Fuel = 100,
		Livery = customizations and customizations.Livery,
		Color = customizations and customizations.Color,
		NeonColor = customizations and customizations.NeonColor,
		IsActive = false,
		PurchasedAt = os.time(),
		TotalDistance = 0,
		TotalDeliveries = 0,
	}

	-- Deduct cash
	local success, err = EconomyServer.SpendCash(userId, finalPrice, "VehiclePurchase", {
		Category = categoryName,
		Model = modelName,
		VehicleId = vehicleInstance.Id,
	})

	if not success then
		return false, nil, err
	end

	-- Add to garage
	PlayerDataServer.AddVehicle(userId, vehicleInstance)

	Signals.GameSignals.VehicleSpawned:Fire(userId, vehicleInstance)

	return true, vehicleInstance, nil
end

--[[
	Sell a vehicle back for partial refund.
]]
function EconomyServer.SellVehicle(userId: number, vehicleId: string): (boolean, number?, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, 0, "Player not found" end

	-- Find vehicle
	local vehicleIndex, vehicle = Utils.Find(profile.VehicleGarage, function(v) return v.Id == vehicleId end)
	if not vehicle then
		return false, 0, "Vehicle not found"
	end

	-- Calculate resale value (50% of base + upgrades)
	local category = Constants.GetVehicleCategory(vehicle.Category)
	local baseRefund = (Constants.Economy.VehicleBasePrices[vehicle.Category] or 0) * 0.5

	-- Add upgrade value
	local upgradeRefund = 0
	for slot, level in pairs(vehicle.Upgrades) do
		local upgrade = Constants.VehicleUpgrades[slot]
		if upgrade then
			for lvl = 1, level do
				local cost = upgrade.BaseCost * (upgrade.CostMultiplier ^ (lvl - 1))
				upgradeRefund += cost * 0.3 -- 30% of upgrade cost
			end
		end
	end

	local totalRefund = math.floor(baseRefund + upgradeRefund)

	-- Remove vehicle
	local removedVehicle = PlayerDataServer.RemoveVehicle(userId, vehicleId)
	if not removedVehicle then
		return false, 0, "Failed to remove vehicle"
	end

	-- Refund cash
	EconomyServer.AddCash(userId, totalRefund, "VehicleSale", {
		VehicleId = vehicleId,
		Category = vehicle.Category,
		RefundAmount = totalRefund,
	})

	Signals.GameSignals.VehicleDespawned:Fire(userId, vehicleId)

	return true, totalRefund, nil
end

-- ============================================
-- UPGRADE ECONOMY
-- ============================================

function EconomyServer.PurchaseUpgrade(userId: number, vehicleId: string, slotName: string): (boolean, number?, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, 0, "Player not found" end

	-- Find vehicle
	local vehicle = Utils.Find(profile.VehicleGarage, function(v) return v.Id == vehicleId end)
	if not vehicle then
		return false, 0, "Vehicle not found"
	end

	-- Get upgrade config
	local upgrade = Constants.VehicleUpgrades[slotName]
	if not upgrade then
		return false, 0, "Invalid upgrade slot"
	end

	-- Check current level
	local currentLevel = vehicle.Upgrades[slotName] or 0
	if currentLevel >= upgrade.MaxLevel then
		return false, 0, "Already max level"
	end

	-- Check unlock requirements
	if upgrade.UnlockLevel and profile.Level < upgrade.UnlockLevel then
		return false, 0, string.format("Requires level %d", upgrade.UnlockLevel)
	end

	-- Calculate cost
	local nextLevel = currentLevel + 1
	local cost = math.floor(upgrade.BaseCost * (upgrade.CostMultiplier ^ (currentLevel - 1)))

	-- Validate funds
	if profile.Cash < cost then
		return false, 0, "Insufficient funds"
	end

	-- Apply upgrade
	vehicle.Upgrades[slotName] = nextLevel

	-- Deduct cash
	EconomyServer.SpendCash(userId, cost, "VehicleUpgrade", {
		VehicleId = vehicleId,
		Slot = slotName,
		NewLevel = nextLevel,
		Cost = cost,
	})

	Signals.GameSignals.VehicleUpgraded:Fire(profile.UserId, vehicleId, slotName, nextLevel)

	return true, nextLevel, nil
end

-- ============================================
-- HIDEOUT ECONOMY
-- ============================================

function EconomyServer.UpgradeHideout(userId: number, targetTier: string): (boolean, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, "Player not found" end

	-- Find target tier config
	local tierConfig
	local tierIndex
	for i, tier in ipairs(Constants.Economy.HideoutTiers) do
		if tier.Name == targetTier then
			tierConfig = tier
			tierIndex = i
			break
		end
	end

	if not tierConfig then
		return false, "Invalid hideout tier"
	end

	-- Check prerequisites
	if profile.Level < tierConfig.UnlockLevel then
		return false, string.format("Requires level %d", tierConfig.UnlockLevel)
	end

	-- Check current tier
	local currentIndex = 0
	for i, tier in ipairs(Constants.Economy.HideoutTiers) do
		if tier.Name == profile.HideoutTier then
			currentIndex = i
			break
		end
	end

	if tierIndex <= currentIndex then
		return false, "Already own this tier or higher"
	end

	if tierIndex ~= currentIndex + 1 then
		return false, "Must upgrade tiers sequentially"
	end

	-- Validate funds
	if profile.Cash < tierConfig.Cost then
		return false, "Insufficient funds"
	end

	-- Apply upgrade
	EconomyServer.SpendCash(userId, tierConfig.Cost, "HideoutUpgrade", {
		NewTier = targetTier,
		Cost = tierConfig.Cost,
	})

	profile.HideoutTier = targetTier

	Signals.GameSignals.HideoutUpgraded:Fire(userId, targetTier)
	Signals.GameSignals.PlayerDataChanged:Fire(userId, PlayerDataServer.GetProfile(userId))

	return true, nil
end

--[[
	Collect passive income from hideout.
]]
function EconomyServer.CollectHideoutIncome(userId: number): (boolean, number?, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, 0, "Player not found" end

	local tierConfig
	for _, tier in ipairs(Constants.Economy.HideoutTiers) do
		if tier.Name == profile.HideoutTier then
			tierConfig = tier
			break
		end
	end

	if not tierConfig or tierConfig.PassiveIncome <= 0 then
		return false, 0, "No passive income available"
	end

	-- Check cooldown (once per hour)
	local lastCollection = profile.HideoutUpgrades.LastIncomeCollection or 0
	if os.time() - lastCollection < 3600 then
		return false, 0, "Income not ready yet"
	end

	local income = tierConfig.PassiveIncome

	-- Apply bonuses
	-- TODO: Add reputation bonuses, event multipliers

	EconomyServer.AddCash(userId, income, "HideoutIncome", {
		Tier = profile.HideoutTier,
	})

	profile.HideoutUpgrades.LastIncomeCollection = os.time()

	Signals.GameSignals.HideoutIncomeReady:Fire(userId, income)

	return true, income, nil
end

-- ============================================
-- DELIVERY REWARDS
-- ============================================

--[[
	Calculate delivery reward based on contract, performance, and conditions.
	Returns: { cash, xp, breakdown }
]]
function EconomyServer.CalculateDeliveryReward(contractData: any, deliveryData: any): { cash: number, xp: number, breakdown: { [string]: number } }
	local profile = PlayerDataServer.GetProfile(deliveryData.PlayerId)
	if not profile then return { cash = 0, xp = 0, breakdown = {} } end

	local breakdown = {}

	-- Base reward from contract
	local baseReward = contractData.TotalReward or contractData.BaseReward or 0
	breakdown.Base = baseReward

	-- Distance bonus
	local distanceBonus = 0
	if contractData.EstimatedDistance then
		distanceBonus = math.floor(contractData.EstimatedDistance * Constants.Economy.DistanceRewardPerStud)
	end
	breakdown.Distance = distanceBonus

	-- Time bonus (for early completion)
	local timeBonus = 0
	if deliveryData.TimeElapsed and contractData.EstimatedTime then
		local ratio = deliveryData.TimeElapsed / contractData.EstimatedTime
		if ratio < 1 then
			timeBonus = math.floor(baseReward * Constants.Economy.TimeBonusMax * (1 - ratio))
		end
	end
	breakdown.Time = timeBonus

	-- Condition bonus
	local conditionBonus = 0
	if deliveryData.ConditionAtStart and deliveryData.CurrentCondition then
		local conditionRatio = deliveryData.CurrentCondition / deliveryData.ConditionAtStart
		if conditionRatio > 0.9 then
			conditionBonus = math.floor(baseReward * Constants.Economy.ConditionBonusMax * conditionRatio)
		end
	end
	breakdown.Condition = conditionBonus

	-- Heat penalty/bonus
	local heatMultiplier = 1.0
	if deliveryData.CurrentHeat and deliveryData.CurrentHeat > 0 then
		-- Higher heat = more risk = slight bonus
		heatMultiplier = 1 + (deliveryData.CurrentHeat * 0.05)
	end
	breakdown.HeatMultiplier = heatMultiplier

	-- Vehicle multiplier
	local vehicleMultiplier = 1.0
	if deliveryData.VehicleCategory then
		local category = Constants.GetVehicleCategory(deliveryData.VehicleCategory)
		if category and category.Stats then
			-- Better vehicles = slightly better rewards
			vehicleMultiplier = 1 + (category.Stats.Speed / 200) -- Max ~1.5x for fastest
		end
	end
	breakdown.VehicleMultiplier = vehicleMultiplier

	-- Calculate final
	local subtotal = baseReward + distanceBonus + timeBonus + conditionBonus
	local finalCash = math.floor(subtotal * heatMultiplier * vehicleMultiplier)
	breakdown.Subtotal = subtotal
	breakdown.FinalCash = finalCash

	-- XP calculation
	local baseXP = math.floor(finalCash * 0.1) -- 10% of cash as XP
	local xpMultiplier = 1.0

	-- Bonus XP for difficulty
	if contractData.RiskLevel then
		xpMultiplier += (contractData.RiskLevel - 1) * 0.1
	end

	local finalXP = math.floor(baseXP * xpMultiplier)
	breakdown.BaseXP = baseXP
	breakdown.XPMultiplier = xpMultiplier
	breakdown.FinalXP = finalXP

	return {
		cash = finalCash,
		xp = finalXP,
		breakdown = breakdown,
	}
end

--[[
	Apply delivery rewards to player.
]]
function EconomyServer.ApplyDeliveryRewards(userId: number, rewards: { cash: number, xp: number, breakdown: { [string]: number } }): boolean
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false end

	-- Apply cash
	if rewards.cash > 0 then
		EconomyServer.AddCash(userId, rewards.cash, "DeliveryReward", {
			Breakdown = rewards.breakdown,
		})
	end

	-- Apply XP
	if rewards.xp > 0 then
		PlayerDataServer.AddXP(userId, rewards.xp, "DeliveryReward")
	end

	-- Update stats
	PlayerDataServer.IncrementStat(userId, "Stats.SuccessfulDeliveries", 1)
	PlayerDataServer.IncrementStat(userId, "Stats.ContractsCompleted", 1)

	return true
end

-- ============================================
-- CONTRACT PENALTIES
-- ============================================

function EconomyServer.ApplyContractFailure(userId: number, contractData: any, reason: string): boolean
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false end

	-- Penalty: lose deposit (10% of contract value)
	local penalty = math.floor((contractData.TotalReward or 0) * 0.1)
	if penalty > 0 then
		EconomyServer.SpendCash(userId, penalty, "ContractFailure", { Reason = reason })
	end

	-- XP penalty
	local xpPenalty = math.floor(penalty * 0.1)
	if xpPenalty > 0 then
		-- Negative XP not directly supported, just don't give reward
	end

	-- Update stats
	PlayerDataServer.IncrementStat(userId, "Stats.FailedDeliveries", 1)

	return true
end

-- ============================================
-- ROBUX / MONETIZATION
-- ============================================

local productCallbacks = {}

function EconomyServer.RegisterProductCallback(productId: number, callback: (userId: number, receiptInfo: any) -> boolean)
	productCallbacks[productId] = callback
end

function EconomyServer.ProcessReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local userId = receiptInfo.PlayerId
	local productId = receiptInfo.ProductId

	local callback = productCallbacks[productId]
	if callback then
		local success = callback(userId, receiptInfo)
		if success then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	-- Default handling for known products
	local product = Constants.Economy.RobuxProducts
	for _, config in pairs(product) do
		if config.ProductId == productId then
			EconomyServer.GrantProductRewards(userId, config)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function EconomyServer.GrantProductRewards(userId: number, config: any)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return end

	if config.Rewards.Cash then
		EconomyServer.AddCash(userId, config.Rewards.Cash, "RobuxPurchase", { Product = config.Id })
	end

	if config.Rewards.XP then
		PlayerDataServer.AddXP(userId, config.Rewards.XP, "RobuxPurchase")
	end

	if config.Rewards.Livery then
		-- Add livery to unlocks
		profile.UnlockedLivery = profile.UnlockedLivery or {}
		table.insert(profile.UnlockedLivery, config.Rewards.Livery)
	end

	if config.Rewards.Vehicles then
		for _, vehicleId in ipairs(config.Rewards.Vehicles) do
			-- Grant vehicle (would need vehicle config lookup)
		end
	end

	if config.Rewards.GarageSlot then
		-- Increase garage capacity
		profile.GarageSlots = (profile.GarageSlots or 5) + config.Rewards.GarageSlot
	end

	if config.Rewards.RepBoost then
		profile.SyndicateRep = (profile.SyndicateRep or 0) + config.Rewards.RepBoost
	end

	if config.Rewards.ExclusiveContracts then
		profile.HasExclusiveContracts = true
	end

	Signals.GameSignals.NotificationQueued:Fire(userId, {
		Type = "Success",
		Title = "Purchase Complete",
		Message = "Your purchase has been processed!",
		Duration = 5,
	})
end

-- ============================================
-- DAILY / WEEKLY REWARDS
-- ============================================

function EconomyServer.ClaimDailyReward(userId: number, day: number): (boolean, any?, string?)
	local profile = PlayerDataServer.GetProfile(userId)
	if not profile then return false, nil, "Player not found" end

	if profile.DailyLoginStreak < day then
		return false, nil, "Day not unlocked yet"
	end

	-- Check if already claimed
	local claimedKey = "DailyClaimed_" .. day
	if profile[claimedKey] then
		return false, nil, "Already claimed"
	end

	local reward = Constants.Economy.DailyLoginRewards[day]
	if not reward then
		return false, nil, "Invalid day"
	end

	-- Apply rewards
	if reward.Cash then
		EconomyServer.AddCash(userId, reward.Cash, "DailyLogin", { Day = day })
	end
	if reward.XP then
		PlayerDataServer.AddXP(userId, reward.XP, "DailyLogin")
	end
	if reward.Item then
		-- Add item
	end

	profile[claimedKey] = true

	Signals.GameSignals.DailyRewardClaimed:Fire(userId, day, reward)

	return true, reward, nil
end

function EconomyServer.ClaimWeeklyReward(userId: number, challengeId: string): (boolean, any?, string?)
	-- Implementation for weekly challenges
	return false, nil, "Not implemented"
end

-- ============================================
-- LEADERBOARDS (Economy)
-- ============================================

function EconomyServer.GetTopCashLeaderboard(limit: number): { { UserId: number, Username: string, Cash: number } }
	local leaderboard = {}

	for userId, profile in pairs(PlayerDataServer.GetAllProfiles()) do
		table.insert(leaderboard, {
			UserId = userId,
			Username = profile.Username,
			Cash = profile.Cash,
		})
	end

	table.sort(leaderboard, function(a, b) return a.Cash > b.Cash end)

	local result = {}
	for i = 1, math.min(limit, #leaderboard) do
		result[i] = leaderboard[i]
		result[i].Rank = i
	end

	return result
end

-- ============================================
-- ANTI-EXPLOIT
-- ============================================

local suspiciousActivity = {} -- [userId] = { count, lastFlagged }

function EconomyServer.FlagSuspiciousActivity(userId: number, reason: string, severity: number)
	local record = suspiciousActivity[userId] or { count = 0, lastFlagged = 0, reasons = {} }
	record.count += 1
	record.lastFlagged = os.time()
	table.insert(record.reasons, { reason = reason, severity = severity, time = os.time() })
	suspiciousActivity[userId] = record

	if record.count >= 5 then
		-- Auto-kick or flag for review
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:Kick("Suspicious activity detected. Please contact support.")
		end
	end
end

function EconomyServer.ValidateTransaction(userId: number, expectedAmount: number, actualAmount: number, tolerance: number?): boolean
	tolerance = tolerance or 0.01 -- 1% tolerance
	local diff = math.abs(expectedAmount - actualAmount)
	local maxDiff = expectedAmount * tolerance
	return diff <= maxDiff
end

-- ============================================
-- INITIALIZATION
-- ============================================

MarketplaceService.ProcessReceipt = function(receiptInfo)
	return EconomyServer.ProcessReceipt(receiptInfo)
end

Utils.DebugLog("EconomyServer initialized")

return EconomyServer