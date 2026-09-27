-- Robux shop UI: SHOP button, a panel with Boosts / Passes / Gift tabs, the Starter Pack
-- button with its countdown, contextual offer popups and the server-wide announcement banner.
local AdService = game:GetService("AdService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Products = require(Shared:WaitForChild("Products"))
local Sounds = require(Shared:WaitForChild("Sounds"))
local Toasts = require(script.Parent:WaitForChild("Toasts"))

local ShopUi = {}

local player = Players.LocalPlayer

local COLORS = {
	Panel = Color3.fromRGB(24, 22, 40),
	Card = Color3.fromRGB(38, 35, 62),
	CardHi = Color3.fromRGB(52, 48, 84),
	Robux = Color3.fromRGB(46, 204, 113),
	Gold = Color3.fromRGB(255, 214, 64),
	Text = Color3.fromRGB(255, 255, 255),
	Sub = Color3.fromRGB(190, 185, 225),
	Owned = Color3.fromRGB(90, 90, 110),
}

local gui: ScreenGui
local panel: Frame
local list: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local currentTab = "Boosts"
local giftPass: string? = nil
local adAvailable = false
local IS_STUDIO = RunService:IsStudio()

-- Ask Roblox whether a rewarded video can play right now (Studio pretends yes for testing).
local function refreshAdAvailability(): boolean
	if IS_STUDIO then
		adAvailable = true
		return true
	end
	local ok, result = pcall(function()
		return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
	end)
	adAvailable = ok and result ~= nil and result.AdAvailabilityResult == Enum.AdAvailabilityResult.IsAvailable
	return adAvailable
end

local function watchAd(key: string)
	Sounds.play("Click")
	Net.event("WatchAd"):FireServer(key)
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2, font: Enum.Font, maxSize: number, color: Color3?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = font
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color or COLORS.Text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = maxSize
	limit.Parent = l
	return l
end

local function button(parent: Instance, text: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = color
	b.AutoButtonColor = true
	b.Font = Enum.Font.FredokaOne
	b.Text = text
	b.TextScaled = true
	b.TextColor3 = COLORS.Text
	b.Parent = parent
	corner(b, 10)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = 20
	limit.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	return b
end

local function hasPass(key: string): boolean
	return player:GetAttribute("Pass_" .. key) == true
end

local function buy(kind: string, key: string)
	Sounds.play("Click")
	Net.event("Buy"):FireServer(kind, key)
end

-- One product row: icon, name, description, price button.
local function card(order: number, icon: string, name: string, desc: string, action: string, actionColor: Color3, onClick: (() -> ())?)
	local c = Instance.new("Frame")
	c.LayoutOrder = order
	c.Size = UDim2.new(1, -8, 0, 74)
	c.BackgroundColor3 = COLORS.Card
	c.Parent = list
	corner(c, 12)

	label(c, icon, UDim2.new(0, 54, 0, 54), UDim2.new(0, 10, 0, 10), Enum.Font.GothamBold, 38).TextXAlignment =
		Enum.TextXAlignment.Center
	label(c, name, UDim2.new(1, -200, 0, 26), UDim2.new(0, 72, 0, 10), Enum.Font.FredokaOne, 22)
	label(c, desc, UDim2.new(1, -200, 0, 30), UDim2.new(0, 72, 0, 36), Enum.Font.GothamMedium, 14, COLORS.Sub).TextWrapped =
		true

	local b = button(c, action, actionColor)
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -10, 0.5, 0)
	b.Size = UDim2.new(0, 110, 0, 44)
	if onClick then
		b.Activated:Connect(onClick)
	else
		b.AutoButtonColor = false
	end
end

local function sortedKeys(tbl: { [string]: any }): { string }
	local keys = {}
	for key in tbl do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return (tbl[a].Order or 0) < (tbl[b].Order or 0)
	end)
	return keys
end

local function clearList()
	for _, child in list:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function render()
	clearList()
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == currentTab then COLORS.Gold else COLORS.Card
		b.TextColor3 = if name == currentTab then Color3.fromRGB(30, 25, 10) else COLORS.Text
	end

	if currentTab == "Boosts" then
		local income = player:GetAttribute("Income")
		income = if type(income) == "number" then income else 0
		if adAvailable then
			local reward = Products.AdRewards.AdCash
			card(-1, reward.Icon, reward.Name, "+" .. Format.money(Products.cashFor(reward :: any, income)) .. " for a short video", "📺 Watch", Color3.fromRGB(80, 120, 230), function()
				watchAd("AdCash")
			end)
		end
		for i, key in sortedKeys(Products.Items) do
			local item = Products.Items[key]
			local starterOpen = key ~= "StarterPack" or player:GetAttribute("StarterEnds") ~= nil
			if starterOpen then
				local desc = item.Desc
				if item.Seconds and key ~= "StarterPack" then
					desc = "+" .. Format.money(Products.cashFor(item, income)) .. " (" .. item.Desc .. ")"
				end
				card(i, item.Icon, item.Name, desc, "R$ " .. item.Price, COLORS.Robux, function()
					buy("Item", key)
				end)
			end
		end
	elseif currentTab == "Passes" then
		for i, key in sortedKeys(Products.Passes) do
			local pass = Products.Passes[key]
			if hasPass(key) then
				card(i, pass.Icon, pass.Name, pass.Desc, "OWNED", COLORS.Owned, nil)
			else
				card(i, pass.Icon, pass.Name, pass.Desc, "R$ " .. pass.Price, COLORS.Robux, function()
					buy("Pass", key)
				end)
			end
		end
	elseif currentTab == "Gift" then
		if not giftPass then
			label(list, "Pick a pass to gift:", UDim2.new(1, -8, 0, 28), UDim2.new(), Enum.Font.FredokaOne, 20).LayoutOrder = 0
			for i, key in sortedKeys(Products.Passes) do
				local pass = Products.Passes[key]
				card(i, pass.Icon, pass.Name, pass.Desc, "Gift 🎁", COLORS.Gold, function()
					giftPass = key
					render()
				end)
			end
		else
			local pass = Products.Passes[giftPass]
			label(list, "Gift " .. pass.Name .. " to:", UDim2.new(1, -8, 0, 28), UDim2.new(), Enum.Font.FredokaOne, 20).LayoutOrder = 0
			local any = false
			for i, other in Players:GetPlayers() do
				if other ~= player then
					any = true
					card(i, "🧑", other.DisplayName, "@" .. other.Name, "R$ " .. pass.Price, COLORS.Robux, function()
						Sounds.play("Click")
						Net.event("Gift"):FireServer(giftPass, other.UserId)
					end)
				end
			end
			if not any then
				label(list, "Nobody else is on this server yet.", UDim2.new(1, -8, 0, 40), UDim2.new(), Enum.Font.GothamMedium, 16, COLORS.Sub).LayoutOrder =
					1
			end
			card(99, "↩", "Back", "Choose another pass", "Back", COLORS.CardHi, function()
				giftPass = nil
				render()
			end)
		end
	end
end

local function openShop(tab: string?)
	if tab then
		currentTab = tab
	end
	giftPass = nil
	render()
	task.spawn(function()
		local before = adAvailable
		if refreshAdAvailability() ~= before and panel.Visible then
			render()
		end
	end)
	panel.Visible = true
	panel.Size = UDim2.new(0.85, 0, 0.72, 0)
	TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.92, 0, 0.8, 0),
	}):Play()
end

local function buildPanel()
	panel = Instance.new("Frame")
	panel.Name = "ShopPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.Size = UDim2.new(0.92, 0, 0.8, 0)
	panel.BackgroundColor3 = COLORS.Panel
	panel.Visible = false
	panel.ZIndex = 20
	panel.Parent = gui
	corner(panel, 18)
	stroke(panel, COLORS.Gold, 3)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 620)
	limit.Parent = panel

	label(panel, "🛒 SHOP", UDim2.new(1, -80, 0, 40), UDim2.new(0, 18, 0, 10), Enum.Font.FredokaOne, 32)

	local close = button(panel, "✕", Color3.fromRGB(200, 60, 70))
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.new(0, 40, 0, 40)
	close.Activated:Connect(function()
		Sounds.play("Click")
		panel.Visible = false
	end)

	local tabs = Instance.new("Frame")
	tabs.BackgroundTransparency = 1
	tabs.Position = UDim2.new(0, 14, 0, 58)
	tabs.Size = UDim2.new(1, -28, 0, 40)
	tabs.Parent = panel
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs
	for i, name in { "Boosts", "Passes", "Gift" } do
		local t = button(tabs, name, COLORS.Card)
		t.LayoutOrder = i
		t.Size = UDim2.new(1 / 3, -6, 1, 0)
		t.Activated:Connect(function()
			Sounds.play("Click")
			currentTab = name
			giftPass = nil
			render()
		end)
		tabButtons[name] = t
	end

	list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.new(0, 14, 0, 108)
	list.Size = UDim2.new(1, -28, 1, -120)
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
end

-- SHOP button in the left action column (next to HOME / REBIRTH), plus the Starter Pack button.
local function buildButtons()
	local column = gui:FindFirstChild("ActionContainer", true) :: Frame?
	local parent: Instance = column or gui

	local shop = button(parent, "🛒 SHOP", Color3.fromRGB(46, 170, 90))
	shop.Name = "ShopButton"
	shop.LayoutOrder = 3
	shop.Size = if column then UDim2.new(1, 0, 0, 52) else UDim2.new(0, 150, 0, 52)
	if not column then
		shop.Position = UDim2.new(0, 20, 0.5, 90)
	end
	stroke(shop, Color3.fromRGB(20, 90, 45), 2)
	shop.Activated:Connect(function()
		Sounds.play("Click")
		openShop()
	end)

	local starter = button(parent, "🎁 STARTER", Color3.fromRGB(230, 120, 30))
	starter.Name = "StarterButton"
	starter.LayoutOrder = 4
	starter.Size = if column then UDim2.new(1, 0, 0, 52) else UDim2.new(0, 150, 0, 52)
	if not column then
		starter.Position = UDim2.new(0, 20, 0.5, 150)
	end
	starter.Visible = false
	stroke(starter, Color3.fromRGB(120, 60, 10), 2)
	starter.Activated:Connect(function()
		buy("Item", "StarterPack")
	end)

	if column then
		column.Size = UDim2.new(column.Size.X.Scale, column.Size.X.Offset, 0, 290)
	end

	-- Countdown and a gentle pulse while the offer lasts
	local pulse = 0
	RunService.Heartbeat:Connect(function(dt: number)
		local ends = player:GetAttribute("StarterEnds")
		if type(ends) ~= "number" then
			starter.Visible = false
			return
		end
		local left = ends - Workspace:GetServerTimeNow()
		starter.Visible = left > 0
		if left > 0 then
			pulse += dt
			starter.Text = "🎁 STARTER " .. Format.time(left)
			starter.Rotation = math.sin(pulse * 4) * 2
		end
	end)
end

-- Contextual offer: a small card that slides up from the bottom.
local function showOffer(key: string, reason: string)
	local ad = Products.AdRewards[key]
	local item = Products.Items[key] or ad
	if not item or (ad and not refreshAdAvailability()) then
		return
	end
	-- A paid Shield offer also gets a free 5-minute one for watching a video
	local freeAlternative = if key == "Shield10" and refreshAdAvailability() then "AdShield" else nil
	local old = gui:FindFirstChild("OfferCard")
	if old then
		old:Destroy()
	end
	local offer = Instance.new("Frame")
	offer.Name = "OfferCard"
	offer.AnchorPoint = Vector2.new(0.5, 1)
	offer.Position = UDim2.new(0.5, 0, 1.3, 0)
	offer.Size = UDim2.new(0.9, 0, 0, 96)
	offer.BackgroundColor3 = COLORS.Panel
	offer.ZIndex = 15
	offer.Parent = gui
	corner(offer, 14)
	stroke(offer, COLORS.Gold, 3)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(460, 96)
	limit.Parent = offer

	local textWidth = if freeAlternative then -240 else -150 -- leave room for the buttons
	label(offer, reason, UDim2.new(1, textWidth, 0, 26), UDim2.new(0, 14, 0, 10), Enum.Font.GothamBold, 16, COLORS.Sub)
	label(offer, item.Icon .. " " .. item.Name, UDim2.new(1, textWidth, 0, 34), UDim2.new(0, 14, 0, 40), Enum.Font.FredokaOne, 26)

	local b = button(offer, if ad then "📺 Watch" else "R$ " .. (item :: any).Price, if ad then Color3.fromRGB(80, 120, 230) else COLORS.Robux)
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -52, 0.5, 0)
	b.Size = UDim2.new(0, 90, 0, 48)
	b.Activated:Connect(function()
		if ad then
			watchAd(key)
		else
			buy("Item", key)
		end
		offer:Destroy()
	end)
	if freeAlternative then
		local free = button(offer, "📺 Free", Color3.fromRGB(80, 120, 230))
		free.AnchorPoint = Vector2.new(1, 0.5)
		free.Position = UDim2.new(1, -148, 0.5, 0)
		free.Size = UDim2.new(0, 86, 0, 48)
		free.Activated:Connect(function()
			watchAd(freeAlternative)
			offer:Destroy()
		end)
	end
	local close = button(offer, "✕", COLORS.CardHi)
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -10, 0.5, 0)
	close.Size = UDim2.new(0, 34, 0, 34)
	close.Activated:Connect(function()
		offer:Destroy()
	end)

	TweenService:Create(offer, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, -16),
	}):Play()
	task.delay(9, function()
		if offer.Parent then
			offer:Destroy()
		end
	end)
end

-- Big banner across the top for server-wide news, and a Cash Rain countdown pill.
local function buildAnnouncements()
	local banner = label(gui, "", UDim2.new(0.9, 0, 0, 44), UDim2.new(0.05, 0, 0, 160), Enum.Font.FredokaOne, 30, COLORS.Gold)
	banner.Name = "Announcement"
	banner.TextXAlignment = Enum.TextXAlignment.Center
	banner.TextStrokeTransparency = 0.2
	banner.Visible = false
	local shown = 0
	Net.event("Announce").OnClientEvent:Connect(function(text: any)
		banner.Text = tostring(text)
		banner.Visible = true
		Sounds.play("Boom")
		shown += 1
		local mine = shown
		task.delay(6, function()
			if shown == mine then
				banner.Visible = false
			end
		end)
	end)

	local pill = label(gui, "", UDim2.new(0, 260, 0, 30), UDim2.new(0.5, -130, 0, 206), Enum.Font.FredokaOne, 20, COLORS.Robux)
	pill.Name = "CashRainTimer"
	pill.TextXAlignment = Enum.TextXAlignment.Center
	pill.BackgroundColor3 = COLORS.Panel
	pill.BackgroundTransparency = 0.2
	pill.Visible = false
	corner(pill, 15)
	RunService.Heartbeat:Connect(function()
		local ends = Workspace:GetAttribute("CashRainEnds")
		local left = if type(ends) == "number" then ends - Workspace:GetServerTimeNow() else 0
		pill.Visible = left > 0
		if left > 0 then
			pill.Text = "💸 2x CASH " .. Format.time(left)
		end
	end)
end

function ShopUi.init(screenGui: ScreenGui)
	gui = screenGui
	buildPanel()
	buildButtons()
	buildAnnouncements()

	Net.event("Offer").OnClientEvent:Connect(function(key: any, reason: any)
		if type(key) == "string" then
			task.spawn(showOffer, key, tostring(reason or "")) -- ad availability check yields
		end
	end)
	Net.event("AdResult").OnClientEvent:Connect(function(_key: any, ok: any, message: any)
		if not ok and type(message) == "string" and message ~= "" then
			Toasts.show("info", message)
		end
	end)

	-- Owned passes and income change what the panel shows
	player.AttributeChanged:Connect(function(name: string)
		if panel.Visible and (name:sub(1, 5) == "Pass_" or name == "StarterEnds") then
			render()
		end
	end)
end

ShopUi.open = openShop

return ShopUi
