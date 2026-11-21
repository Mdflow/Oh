--[[
	UNDERGROUND — Social Client
	Friends, parties, leaderboards, chat, player interactions.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Signals = require(ReplicatedStorage.Shared.Signals)
local Utils = require(ReplicatedStorage.Shared.Utils)
local UIController = require(script.Parent.UIController)

local SocialClient = {}

-- ============================================
- STATE
- ============================================

local friendsList = {} -- [userId] = { username, displayName, isOnline, lastSeen }
local friendRequests = {} -- [userId] = { sent, received }
local currentParty = nil -- { leader, members, isLeader }
local partyInvites = {} -- [userId] = { inviter, timestamp }

local leaderboards = {} -- [leaderboardId] = { entries }
local currentLeaderboard = nil

local chatChannels = {}
local currentChatChannel = "Global"

local socialUI = {}

-- ============================================
- FRIENDS SYSTEM
- ============================================

function SocialClient.Initialize()
	Utils.DebugLog("SocialClient initializing...")

	SocialClient.BuildSocialUI()

	-- Signals
	Signals.GameSignals.FriendOnline:Connect(function(userId)
		SocialClient.OnFriendOnline(userId)
	end)

	Signals.GameSignals.FriendOffline:Connect(function(userId)
		SocialClient.OnFriendOffline(userId)
	end)

	Signals.GameSignals.FriendRequestReceived:Connect(function(fromUserId)
		SocialClient.OnFriendRequestReceived(fromUserId)
	end)

	Signals.GameSignals.FriendRequestAccepted:Connect(function(userId)
		SocialClient.OnFriendRequestAccepted(userId)
	end)

	Signals.GameSignals.PartyInvited:Connect(function(inviterId)
		SocialClient.OnPartyInvited(inviterId)
	end)

	Signals.GameSignals.PartyJoined:Connect(function(partyData)
		SocialClient.OnPartyJoined(partyData)
	end)

	Signals.GameSignals.PartyLeft:Connect(function()
		SocialClient.OnPartyLeft()
	end)

	Signals.GameSignals.LeaderboardUpdated:Connect(function(leaderboardId, entries)
		SocialClient.OnLeaderboardUpdated(leaderboardId, entries)
	end)

	Utils.DebugLog("SocialClient initialized")
end

-- ============================================
- FRIENDS MANAGEMENT
- ============================================

function SocialClient.SendFriendRequest(targetUserId: number)
	local remote = game.ReplicatedStorage:FindFirstChild("Remotes", true)
	if remote then
		local requestRemote = remote:FindFirstChild("SendFriendRequest")
		if requestRemote then
			requestRemote:FireServer(targetUserId)
		end
	end
end

function SocialClient.AcceptFriendRequest(fromUserId: number)
	local remote = game.ReplicatedStorage:FindFirstChild("Remotes", true)
	if remote then
		local acceptRemote = remote:FindFirstChild("AcceptFriendRequest")
		if acceptRemote then
			requestRemote:FireServer(fromUserId)
		end
	end
end

function SocialClient.DeclineFriendRequest(fromUserId: number)
	local remote = game.ReplicatedStorage:FindFirstChild("Remotes", true)
	if remote then
		local declineRemote = remote:FindFirstChild("DeclineFriendRequest")
		if declineRemote then
			declineRemote:FireServer(fromUserId)
		end
	end
end

function SocialClient.RemoveFriend(userId: number)
	local remote = game.ReplicatedStorage:FindFirstChild("Remotes", true)
	if remote then
		local removeRemote = remote:FindFirstChild("RemoveFriend")
		if removeRemote then
			removeRemote:FireServer(userId)
		end
	end
end

function SocialClient.OnFriendOnline(userId: number)
	local friend = friendsList[userId]
	if friend then
		friend.isOnline = true
		friend.lastSeen = os.time()
	end

	UIController.ShowToast({
		Type = "Info",
		Title = "FRIEND ONLINE",
		Message = (friendsList[userId] and friendsList[userId].displayName or "A friend") .. " came online",
		Duration = 4,
	})
end

function SocialClient.OnFriendOffline(userId: number)
	local friend = friendsList[userId]
	if friend then
		friend.isOnline = false
		friend.lastSeen = os.time()
	end
end

function SocialClient.OnFriendRequestReceived(fromUserId: number)
	friendRequests[fromUserId] = { type = "received", timestamp = os.time() }

	UIController.ShowToast({
		Type = "Info",
		Title = "FRIEND REQUEST",
		Message = "You received a friend request",
		Duration = 10,
		Action = {
			Label = "VIEW",
			Callback = function()
				SocialClient.OpenFriendRequests()
			end,
		},
	})
end

function SocialClient.OnFriendRequestAccepted(userId: number)
	friendRequests[userId] = nil
	friendsList[userId] = friendsList[userId] or {}
	friendsList[userId].isOnline = true

	UIController.ShowToast({
		Type = "Success",
		Title = "FRIEND ADDED",
		Message = "You are now friends!",
		Duration = 4,
	})
end

-- ============================================
- PARTY SYSTEM
- ============================================

function SocialClient.CreateParty()
	local remote = game.ReplicatedStorage:FindFirstChild("Remotes", true)
	if remote then
		local createRemote = remote:FindFirstChild("CreateParty")
		if createRemote then
			createRemote:FireServer()
		end
	end
end

function SocialClient.InviteToParty(targetUserId: number)
	if not currentParty then
		UIController.ShowToast({
			Type = "Error",
			Title = "NO PARTY",
			Message = "Create a party first!",
			Duration = 3,
		})
		return
	end

	if not currentParty.isLeader then
		UIController.ShowToast({
			Type = "Error",
			Title = "NOT LEADER",
			Message = "Only the party leader can invite!",
			Duration = 3,
		})
		return
	end

	local remote = game.ReplicatedStorage:FindFirstChild("Remotes", true)
	if remote then
		local inviteRemote = remote:FindFirstChild("InviteToParty")
		if inviteRemote then
			inviteRemote:FireServer(targetUserId)
		end
	end
end

function SocialClient.JoinParty(leaderUserId: number)
	local remote = game.ReplicatedStorage:FindFirstChild("Remotes", true)
	if remote then
		local joinRemote = remote:FindFirstChild("JoinParty")
		if joinRemote then
			joinRemote:FireServer(leaderUserId)
		end
	end
end

function SocialClient.LeaveParty()
	local remote = game.ReplicatedStorage:FindFirstChild("Remotes", true)
	if remote then
		local leaveRemote = remote:FindFirstChild("LeaveParty")
		if leaveRemote then
			leaveRemote:FireServer()
		end
	end
end

function SocialClient.KickFromParty(targetUserId: number)
	if not currentParty or not currentParty.isLeader then return end

	local remote = game.ReplicatedStorage:FindFirstChild("Remotes", true)
	if remote then
		local kickRemote = remote:FindFirstChild("KickFromParty")
		if kickRemote then
			kickRemote:FireServer(targetUserId)
		end
	end
end

function SocialClient.OnPartyInvited(inviterId: number)
	partyInvites[inviterId] = { inviter = inviterId, timestamp = os.time() }

	UIController.ShowToast({
		Type = "Info",
		Title = "PARTY INVITE",
		Message = "You were invited to a party",
		Duration = 15,
		Action = {
			Label = "JOIN",
			Callback = function()
				SocialClient.JoinParty(inviterId)
			end,
		},
	})
end

function SocialClient.OnPartyJoined(partyData: any)
	currentParty = partyData

	UIController.ShowToast({
		Type = "Success",
		Title = "PARTY JOINED",
		Message = "You joined the party!",
		Duration = 3,
	})

	SocialClient.UpdatePartyUI()
end

function SocialClient.OnPartyLeft()
	currentParty = nil

	UIController.ShowToast({
		Type = "Info",
		Title = "PARTY LEFT",
		Message = "You left the party",
		Duration = 3,
	})

	SocialClient.UpdatePartyUI()
end

function SocialClient.UpdatePartyUI()
	-- Update party UI in social panel
end

function SocialClient.GetCurrentParty(): any
	return currentParty
end

function SocialClient.IsInParty(): boolean
	return currentParty ~= nil
end

function SocialClient.IsPartyLeader(): boolean
	return currentParty and currentParty.isLeader == true
end

function SocialClient.GetPartyMembers(): { any }
	return currentParty and currentParty.members or {}
end

-- ============================================
- LEADERBOARDS
- ============================================

function SocialClient.RequestLeaderboard(leaderboardId: string)
	local remote = game.ReplicatedStorage:FindFirstChild("Remotes", true)
	if remote then
		local requestRemote = remote:FindFirstChild("RequestLeaderboard")
		if requestRemote then
			requestRemote:FireServer(leaderboardId)
		end
	end
end

function SocialClient.OnLeaderboardUpdated(leaderboardId: string, entries: { any })
	leaderboards[leaderboardId] = entries

	if currentLeaderboard == leaderboardId then
		SocialClient.RefreshLeaderboardUI(leaderboardId)
	end
end

function SocialClient.GetLeaderboard(leaderboardId: string): { any }
	return leaderboards[leaderboardId] or {}
end

function SocialClient.SetCurrentLeaderboard(leaderboardId: string)
	currentLeaderboard = leaderboardId
	SocialClient.RequestLeaderboard(leaderboardId)
end

function SocialClient.RefreshLeaderboardUI(leaderboardId: string)
	-- Update leaderboard UI
end

-- ============================================
- CHAT SYSTEM
- ============================================

function SocialClient.SendMessage(channel: string, message: string)
	if #message == 0 or #message > 200 then return end

	local remote = game.ReplicatedStorage:FindFirstChild("Remotes", true)
	if remote then
		local chatRemote = remote:FindFirstChild("SendChatMessage")
		if chatRemote then
			chatRemote:FireServer(channel, message)
		end
	end
end

function SocialClient.OnMessageReceived(channel: string, fromUserId: number, message: string, timestamp: number)
	if not chatChannels[channel] then
		chatChannels[channel] = {}
	end

	table.insert(chatChannels[channel], {
		FromUserId = fromUserId,
		Message = message,
		Timestamp = timestamp,
	})

	-- Trim history
	while #chatChannels[channel] > 100 do
		table.remove(chatChannels[channel], 1)
	end

	-- Notify UI
	Signals.GameSignals.ChatMessageReceived:Fire(channel, fromUserId, message, timestamp)
end

function SocialClient.SetChatChannel(channel: string)
	currentChatChannel = channel
end

function SocialClient.GetChatHistory(channel: string): { any }
	return chatChannels[channel] or {}
end

function SocialClient.SendPrivateMessage(targetUserId: number, message: string)
	SocialClient.SendMessage("Whisper_" .. targetUserId, message)
end

-- ============================================
- SOCIAL UI
- ============================================

function SocialClient.BuildSocialUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "SocialPanel"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 20
	screenGui.Enabled = false
	screenGui.Parent = Players.LocalPlayer.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "SocialFrame"
	frame.Size = UDim2.new(0, 500, 0, 600)
	frame.Position = UDim2.new(0.5, -250, 0.5, -300)
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
		Text = "SOCIAL",
		TextSize = 28,
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(0, 255, 136),
		Size = UDim2.new(1, -40, 0, 40),
		Position = UDim2.new(0, 20, 0, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		Parent = header,
	})

	-- Tabs
	local tabContainer = Instance.new("Frame")
	tabContainer.Size = UDim2.new(1, -40, 0, 40)
	tabContainer.Position = UDim2.new(0, 20, 0, 50)
	tabContainer.BackgroundTransparency = 1
	tabContainer.Parent = frame

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 10)
	tabLayout.Parent = tabContainer

	for _, tabName in ipairs({ "Friends", "Party", "Leaderboards", "Chat" }) do
		local tab = Instance.new("TextButton")
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
			SocialClient.SwitchSocialTab(tabName)
		end)
	end

	-- Content
	local contentFrame = Instance.new("Frame")
	contentFrame.Name = "ContentFrame"
	contentFrame.Size = UDim2.new(1, -40, 1, -120)
	contentFrame.Position = UDim2.new(0, 20, 0, 110)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = frame

	socialUI = {
		ScreenGui = screenGui,
		Frame = frame,
		CurrentTab = "Friends",
	}

	screenGui.Parent = Players.LocalPlayer.PlayerGui
end

function SocialClient.SwitchSocialTab(tabName: string)
	if not socialUI.Frame then return end

	-- Update tab highlights
	for _, child in ipairs(socialUI.Frame:GetDescendants()) do
		if child:IsA("TextButton") and child.Name:match("^Tab_") then
			local isActive = child.Text:upper() == tabName:upper()
			child.TextColor3 = isActive and Color3.fromRGB(0, 255, 136) or Color3.fromRGB(150, 150, 150)
			child.BackgroundTransparency = isActive and 0.2 or 0.5
		end
	end

	socialUI.CurrentTab = tabName

	-- Refresh tab content
	SocialClient.RefreshSocialTab(tabName)
end

function SocialClient.RefreshSocialTab(tabName: string)
	-- Refresh the content for the active tab
end

function SocialClient.OpenSocialPanel()
	if not socialUI.ScreenGui then
		SocialClient.BuildSocialUI()
	end
	socialUI.ScreenGui.Enabled = true
end

function SocialClient.CloseSocialPanel()
	if socialUI.ScreenGui then
		socialUI.ScreenGui.Enabled = false
	end
end

function SocialClient.ToggleSocialPanel()
	if socialUI.ScreenGui then
		socialUI.ScreenGui.Enabled = not socialUI.ScreenGui.Enabled
	end
end

function SocialClient.OpenFriendRequests()
	SocialClient.OpenSocialPanel()
	SocialClient.SwitchSocialTab("Friends")
end

-- ============================================
- CLEANUP
- ============================================

function SocialClient.Cleanup()
	if socialUI.ScreenGui then
		socialUI.ScreenGui:Destroy()
	end
	socialUI = {}
	currentParty = nil
	friendsList = {}
	friendRequests = {}
	partyInvites = {}
	leaderboards = {}
	chatChannels = {}
end

Utils.DebugLog("SocialClient initialized")

return SocialClient