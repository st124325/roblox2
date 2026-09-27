-- Robux purchases: game passes, developer products, gifts, the starter pack, the server-wide
-- Cash Rain, pad unlocks (cash or Robux) and contextual offers.
--
-- Receipts are idempotent: every granted PurchaseId is remembered in profile.Meta.Receipts and
-- the profile is saved before Roblox is told the purchase was granted.
-- Items whose id is still 0 are granted for free in Studio so everything can be tested before
-- the products exist; in a live game they show as unavailable.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Products = require(Shared:WaitForChild("Products"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local Server = script.Parent
local Data = require(Server:WaitForChild("Data"))
local Events = require(Server:WaitForChild("Events"))
local Bases = require(Server:WaitForChild("Bases"))

local Shop = {}

local IS_STUDIO = RunService:IsStudio()
local MAX_RECEIPTS = 60
local FAST_LEGS_BONUS = 1.25
local VIP_INCOME = 1.2

local notifyEvent = Net.event("Notify")
local offerEvent = Net.event("Offer")
local announceEvent = Net.event("Announce")

-- product id -> ("Item" | "Gift", key)
local productById: { [number]: { Kind: string, Key: string } } = {}
local passById: { [number]: string } = {}
-- Passes owned through Roblox (checked once per session) — Meta.Passes holds gifted/test ones
local ownedPasses: { [Player]: { [string]: boolean } } = {}
local pendingGift: { [Player]: { Pass: string, Target: number } } = {}
local lastShieldOffer: { [Player]: number } = {}
local cashRainEnds = 0 -- os.clock()

local function notify(player: Player, kind: string, text: string)
	notifyEvent:FireClient(player, kind, text)
end

local function meta(player: Player): { [string]: any }?
	local profile = Data.get(player)
	return profile and profile.Meta
end

function Shop.hasPass(player: Player, key: string): boolean
	local owned = ownedPasses[player]
	if owned and owned[key] then
		return true
	end
	local m = meta(player)
	return m ~= nil and type(m.Passes) == "table" and m.Passes[key] == true
end

local function cashRainActive(): boolean
	return os.clock() < cashRainEnds
end

local function applyWalkSpeed(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	-- Carrying sets its own (slower) speed and restores this one afterwards
	if humanoid and not player:GetAttribute("Carrying") then
		humanoid.WalkSpeed = Config.WalkSpeed * (if Shop.hasPass(player, "FastLegs") then FAST_LEGS_BONUS else 1)
	end
end

local function applyVipTag(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or head:FindFirstChild("VipTag") or not Shop.hasPass(player, "VIP") then
		return
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "VipTag"
	tag.Size = UDim2.new(0, 70, 0, 26)
	tag.StudsOffset = Vector3.new(0, 2.6, 0)
	tag.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "👑 VIP"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 215, 60)
	label.TextStrokeTransparency = 0.2
	label.Parent = tag
	tag.Parent = head
end

-- Re-apply every pass effect (after a purchase, a gift or a respawn).
local function applyPasses(player: Player)
	for key in Products.Passes do
		player:SetAttribute("Pass_" .. key, Shop.hasPass(player, key))
	end
	applyWalkSpeed(player)
	applyVipTag(player)
	Bases.refresh(player)
end

local function grantPass(player: Player, key: string)
	local m = meta(player)
	if not m then
		return
	end
	m.Passes = if type(m.Passes) == "table" then m.Passes else {}
	m.Passes[key] = true
	applyPasses(player)
end

local function currentIncome(player: Player): number
	local income = player:GetAttribute("Income")
	return if type(income) == "number" then income else 0
end

local function startCashRain(buyer: Player)
	local now = os.clock()
	cashRainEnds = math.max(cashRainEnds, now) + Products.CashRainSeconds
	Workspace:SetAttribute("CashRainEnds", Workspace:GetServerTimeNow() + (cashRainEnds - now))
	Workspace:SetAttribute("CashRainBy", buyer.DisplayName)
	announceEvent:FireAllClients("💸 " .. buyer.DisplayName .. " started a CASH RAIN! 2x cash for everyone!")
	for _, player in Players:GetPlayers() do
		Bases.refresh(player)
	end
	task.delay(cashRainEnds - now + 0.1, function()
		if not cashRainActive() then
			Workspace:SetAttribute("CashRainEnds", nil)
			Workspace:SetAttribute("CashRainBy", nil)
			for _, player in Players:GetPlayers() do
				Bases.refresh(player)
			end
		end
	end)
end

local function unlockPad(player: Player)
	local m = meta(player)
	if not m then
		return
	end
	m.BoughtPads = (tonumber(m.BoughtPads) or 0) + 1
	Bases.refresh(player)
end

local function grantCash(player: Player, amount: number)
	Data.addMoney(player, amount)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	Net.event("Cash"):FireClient(player, amount, if root then root.Position + Vector3.new(0, 4, 0) else nil)
end

-- Give the player what they paid for. Must never fail once the purchase is real.
local function grantItem(player: Player, key: string)
	local item = Products.Items[key]
	local m = meta(player)
	if not item or not m then
		return
	end
	if key == "Shield10" or key == "Shield30" then
		Bases.lockFor(player, if key == "Shield10" then 600 else 1800)
		notify(player, "good", "🛡️ Shield up for " .. Format.time(Bases.lockRemaining(player)))
	elseif key == "GrowBoost" then
		local profile = Data.get(player)
		for _, entry in (profile :: any).Slots do
			entry.Growth += 900
		end
		notify(player, "good", "🌱 Your kaiju grew 15 minutes!")
	elseif key == "CashRain" then
		startCashRain(player)
	elseif key == "UnlockPad" then
		unlockPad(player)
		notify(player, "good", "🔓 Pad unlocked!")
	elseif key == "StarterPack" then
		m.StarterBought = true
		player:SetAttribute("StarterEnds", nil)
		grantCash(player, Products.cashFor(item, currentIncome(player)))
		Bases.lockFor(player, 1800)
		local profile = Data.get(player)
		for _, entry in (profile :: any).Slots do
			entry.Growth += 900
		end
		notify(player, "good", "🎁 Starter Pack opened! Cash, Shield and Grow Boost are yours.")
	elseif item.Seconds then
		local amount = Products.cashFor(item, currentIncome(player))
		grantCash(player, amount)
		notify(player, "good", item.Icon .. " +" .. Format.money(amount))
	end
end

local function grantGift(buyer: Player, passKey: string)
	local gift = pendingGift[buyer]
	pendingGift[buyer] = nil
	local target = gift and gift.Pass == passKey and Players:GetPlayerByUserId(gift.Target)
	local pass = Products.Passes[passKey]
	if target and not Shop.hasPass(target, passKey) then
		grantPass(target, passKey)
		notify(buyer, "good", "🎁 You gifted " .. pass.Name .. " to " .. target.DisplayName .. "!")
		notify(target, "good", "🎁 " .. buyer.DisplayName .. " gifted you " .. pass.Name .. "!")
		announceEvent:FireAllClients("🎁 " .. buyer.DisplayName .. " gifted " .. pass.Name .. " to " .. target.DisplayName .. "!")
	elseif not Shop.hasPass(buyer, passKey) then
		-- Friend left before the purchase went through: the buyer keeps the pass
		grantPass(buyer, passKey)
		notify(buyer, "info", "Your friend left, so " .. pass.Name .. " is yours instead!")
	else
		-- Nobody to give it to: pay it out as cash so the Robux aren't wasted
		local amount = Products.cashFor(Products.Items.CashMedium, currentIncome(buyer))
		grantCash(buyer, amount)
		notify(buyer, "info", "Your friend left, so you got " .. Format.money(amount) .. " instead.")
	end
end

local function processReceipt(info): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local profile = player and Data.get(player)
	if not player or not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries when they're back
	end
	local m = profile.Meta
	m.Receipts = if type(m.Receipts) == "table" then m.Receipts else {}
	local receiptKey = tostring(info.PurchaseId)
	if m.Receipts[receiptKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product = productById[info.ProductId]
	if not product then
		warn("[Shop] unknown product id " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if product.Kind == "Gift" then
		grantGift(player, product.Key)
	else
		grantItem(player, product.Key)
	end
	Sounds.playAt(player.Character and player.Character:FindFirstChild("HumanoidRootPart") or Workspace, "Buy")

	-- Remember the receipt, keeping only the newest ones
	m.Receipts[receiptKey] = os.time()
	local count, oldestKey, oldestTime = 0, nil, math.huge
	for k, t in m.Receipts do
		count += 1
		if t < oldestTime then
			oldestKey, oldestTime = k, t
		end
	end
	if count > MAX_RECEIPTS and oldestKey then
		m.Receipts[oldestKey] = nil
	end

	m.Spent = (tonumber(m.Spent) or 0) + (info.CurrencySpent or 0)
	if Data.save(player) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- The grant stays recorded in memory, so a retry in this server won't grant twice
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Client asks to buy something: prompt Roblox, or grant directly in Studio test mode.
local function onBuy(player: Player, kind: any, key: any)
	if type(key) ~= "string" then
		return
	end
	if kind == "Pass" then
		local pass = Products.Passes[key]
		if not pass or Shop.hasPass(player, key) then
			return
		end
		if pass.Id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.Id)
		elseif IS_STUDIO then
			grantPass(player, key)
			notify(player, "good", "[Studio test] " .. pass.Name .. " granted")
		else
			notify(player, "info", pass.Name .. " is coming soon!")
		end
	elseif kind == "Item" then
		local item = Products.Items[key]
		if not item then
			return
		end
		local m = meta(player)
		if key == "StarterPack" and m and m.StarterBought then
			notify(player, "bad", "You already opened the Starter Pack.")
			return
		end
		if key == "UnlockPad" and Bases.unlockedSlots(player) >= Config.MaxSlots then
			notify(player, "bad", "All pads are already unlocked!")
			return
		end
		if item.Id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, item.Id)
		elseif IS_STUDIO then
			grantItem(player, key)
			notify(player, "info", "[Studio test] " .. item.Name .. " granted")
		else
			notify(player, "info", item.Name .. " is coming soon!")
		end
	end
end

local function onGift(player: Player, passKey: any, targetUserId: any)
	local pass = type(passKey) == "string" and Products.Passes[passKey]
	local gift = type(passKey) == "string" and Products.Gifts[passKey]
	local target = type(targetUserId) == "number" and Players:GetPlayerByUserId(targetUserId)
	if not pass or not gift or not target or target == player then
		return
	end
	if Shop.hasPass(target, passKey) then
		notify(player, "bad", target.DisplayName .. " already has " .. pass.Name .. ".")
		return
	end
	pendingGift[player] = { Pass = passKey, Target = target.UserId }
	if gift.Id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, gift.Id)
	elseif IS_STUDIO then
		grantGift(player, passKey)
	else
		notify(player, "info", "Gifting is coming soon!")
	end
end

-- Pads: the next locked one can be opened with cash (price grows fast) or Robux.
local function padCostFor(player: Player): number
	local m = meta(player)
	return Products.padCost(if m then tonumber(m.BoughtPads) or 0 else 0)
end

local function onPadUnlock(player: Player)
	if Bases.unlockedSlots(player) >= Config.MaxSlots then
		return
	end
	local profile = Data.get(player)
	local cost = padCostFor(player)
	if profile and profile.Money >= cost then
		Data.addMoney(player, -cost)
		unlockPad(player)
		notify(player, "good", "🔓 Pad unlocked for " .. Format.money(cost) .. "!")
	else
		offerEvent:FireClient(player, "UnlockPad", "Need " .. Format.money(cost) .. " — or unlock it right now:")
	end
end

local function onPlayerLoaded(player: Player)
	local m = meta(player)
	if not m then
		return
	end
	-- Starter pack window starts on the very first join
	if not m.FirstJoin then
		m.FirstJoin = os.time()
	end
	local starterLeft = Products.StarterWindowSeconds - (os.time() - m.FirstJoin)
	if not m.StarterBought and starterLeft > 0 then
		player:SetAttribute("StarterEnds", Workspace:GetServerTimeNow() + starterLeft)
	end

	-- Real game pass ownership (skipped for passes without an id yet)
	local owned = {}
	for key, pass in Products.Passes do
		if pass.Id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			owned[key] = ok and has == true
		end
	end
	ownedPasses[player] = owned
	applyPasses(player)
end

function Shop.init()
	for key, item in Products.Items do
		if item.Id ~= 0 then
			productById[item.Id] = { Kind = "Item", Key = key }
		end
	end
	for key, gift in Products.Gifts do
		if gift.Id ~= 0 then
			productById[gift.Id] = { Kind = "Gift", Key = key }
		end
	end
	for key, pass in Products.Passes do
		if pass.Id ~= 0 then
			passById[pass.Id] = key
		end
	end

	-- Hooks into Bases
	function Bases.multiplierFor(player: Player): number
		local multiplier = 1
		if Shop.hasPass(player, "DoubleCash") then
			multiplier *= 2
		end
		if Shop.hasPass(player, "VIP") then
			multiplier *= VIP_INCOME
		end
		if cashRainActive() then
			multiplier *= 2
		end
		return multiplier
	end
	function Bases.autoCollectFor(player: Player): boolean
		return Shop.hasPass(player, "AutoCollect")
	end
	function Bases.extraSlotsFor(player: Player): number
		local m = meta(player)
		return (if Shop.hasPass(player, "VIP") then 1 else 0)
			+ (if Shop.hasPass(player, "ExtraSlots") then 2 else 0)
			+ (if m then tonumber(m.BoughtPads) or 0 else 0)
	end
	function Bases.padUnlockText(player: Player): string?
		return "Unlock " .. Format.money(padCostFor(player))
	end
	Bases.onPadUnlock = onPadUnlock

	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
		local key = passById[passId]
		if purchased and key then
			ownedPasses[player] = ownedPasses[player] or {}
			ownedPasses[player][key] = true
			applyPasses(player)
			notify(player, "good", "Thanks! " .. Products.Passes[key].Name .. " is active.")
		end
	end)

	Net.event("Buy").OnServerEvent:Connect(onBuy)
	Net.event("Gift").OnServerEvent:Connect(onGift)

	Data.loaded.Event:Connect(function(player: Player)
		-- Bases assigns the base on the same signal; pads need it for the unlock prompt
		task.delay(0.5, function()
			if player.Parent == Players then
				onPlayerLoaded(player)
			end
		end)
	end)
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			character:WaitForChild("Humanoid", 5)
			character:WaitForChild("Head", 5)
			task.wait(0.2)
			applyWalkSpeed(player)
			applyVipTag(player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		ownedPasses[player] = nil
		pendingGift[player] = nil
		lastShieldOffer[player] = nil
	end)

	-- Just got robbed: the best moment to offer a Shield
	Events.Robbed.Event:Connect(function(victim: Player)
		local now = os.clock()
		if lastShieldOffer[victim] and now - lastShieldOffer[victim] < Products.ShieldOfferCooldown then
			return
		end
		lastShieldOffer[victim] = now
		task.delay(1.5, function()
			if victim.Parent == Players then
				offerEvent:FireClient(victim, "Shield10", "Stop the thieves! Lock your base:")
			end
		end)
	end)
end

return Shop
