-- Base ownership, kaiju slot management, income ticks, growth, collection,
-- lock/barrier, sell, rebirth, go-home, and offline income.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))
local Kaiju = require(Shared:WaitForChild("Kaiju"))
local KaijuModel = require(Shared:WaitForChild("KaijuModel"))

local Server = script.Parent
local Data = require(Server:WaitForChild("Data"))
local Map = require(Server:WaitForChild("Map"))

-- ---------------------------------------------------------------------------
-- Types
-- ---------------------------------------------------------------------------

type SlotEntry = {
	Id: string,
	Growth: number,
	Mutation: string?,
}

type BaseInfo = {
	Index: number,
	Model: Model,
	Pads: { BasePart },
	CollectPlate: BasePart,
	LockButton: BasePart,
	Barrier: BasePart,
	Zone: BasePart,
	Sign: BasePart,
	Spawn: CFrame,
}

-- ---------------------------------------------------------------------------
-- Module table
-- ---------------------------------------------------------------------------

local Bases = {}

local kaijuAddedEvent = Instance.new("BindableEvent")
kaijuAddedEvent.Name = "BasesKaijuAdded"
Bases.kaijuAdded = kaijuAddedEvent

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------

-- Owner mapping: baseIndex -> Player
local ownerByBase: { [number]: Player } = {}
-- Reverse mapping: Player -> baseIndex
local baseByPlayer: { [Player]: number } = {}
-- Models placed on pads: [Player] -> { [slotNumber] -> Model }
local slotModels: { [Player]: { [number]: Model } } = {}
-- Lock state: baseIndex -> endTick (os.clock when lock expires)
local lockEndTimes: { [number]: number } = {}
-- Lock cooldown: baseIndex -> next allowed lock time (os.clock)
local lockCooldowns: { [number]: number } = {}
-- Anti-spam: per-player cooldown trackers
local collectCooldowns: { [Player]: number } = {}
local goHomeCooldowns: { [Player]: number } = {}
local rebirthCooldowns: { [Player]: number } = {}
local sellCooldowns: { [Player]: number } = {}

-- Previous stage index per slot for detecting stage changes
local prevStageIdx: { [Player]: { [number]: number } } = {}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function isAlive(player: Player): boolean
	local char = player.Character
	if not char then
		return false
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function teleportTo(player: Player, cf: CFrame)
	local char = player.Character
	if char then
		local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			root.CFrame = cf
		end
	end
end

local function notify(player: Player, kind: string, text: string)
	Net.event("Notify"):FireClient(player, kind, text)
end

-- Set the Owner label on the Sign SurfaceGui
local function setSignText(base: BaseInfo, text: string)
	local sign = base.Sign
	local gui = sign:FindFirstChild("SurfaceGui")
	if gui then
		local label = gui:FindFirstChild("Owner") :: TextLabel?
		if label then
			label.Text = text
		end
	end
end

-- Create / update the BillboardGui on CollectPlate showing bank amount
local function updateBankDisplay(base: BaseInfo, bank: number)
	local plate = base.CollectPlate
	local tag = plate:FindFirstChild("Tag") :: BillboardGui?
	if not tag then
		return
	end
	local label = tag:FindFirstChild("Label") :: TextLabel?
	if label then
		if bank > 0 then
			label.Text = "💰 " .. Format.money(bank)
		else
			label.Text = "💰 COLLECT"
		end
	end
end

-- Update the LockButton billboard to show remaining time or default text
local function updateLockDisplay(base: BaseInfo, remaining: number?)
	local button = base.LockButton
	local tag = button:FindFirstChild("Tag") :: BillboardGui?
	if not tag then
		return
	end
	local label = tag:FindFirstChild("Label") :: TextLabel?
	if label then
		if remaining and remaining > 0 then
			label.Text = "🔒 " .. Format.time(remaining)
		else
			label.Text = "🔒 LOCK"
		end
	end
end

-- Compute total income/s for a player across all slots
local function computeTotalIncome(player: Player): number
	local profile = Data.get(player)
	if not profile then
		return 0
	end
	local total = 0
	for _, entry in profile.Slots do
		total += Kaiju.incomeOf(entry, profile.Rebirths)
	end
	return total
end

-- Refresh the Income attribute on a player
local function refreshIncomeAttribute(player: Player)
	player:SetAttribute("Income", computeTotalIncome(player))
end

-- ---------------------------------------------------------------------------
-- Slot / model management
-- ---------------------------------------------------------------------------

-- Place a kaiju model on its pad (anchored, standing on the pad surface)
-- Pads beyond the owner's unlocked count are greyed out with a lock, so a base that
-- "looks" half empty doesn't confuse players when the conveyor says it's full.
local PAD_COLOR = Color3.fromRGB(54, 58, 66)
local PAD_LOCKED_COLOR = Color3.fromRGB(28, 30, 34)
local padLabelColors: { [BasePart]: Color3 } = {}

local function refreshPads(base: BaseInfo, unlocked: number)
	for i, pad in base.Pads do
		local gui = pad:FindFirstChild("PadGui")
		local label = gui and gui:FindFirstChild("SlotNumber") :: TextLabel?
		if label and not padLabelColors[pad] then
			padLabelColors[pad] = label.TextColor3
		end
		local open = i <= unlocked
		pad.Color = if open then PAD_COLOR else PAD_LOCKED_COLOR
		pad.Transparency = if open then 0 else 0.45
		if label then
			label.Text = if open then "#" .. i else "🔒 Rebirth"
			label.TextColor3 = if open then padLabelColors[pad] else Color3.fromRGB(140, 140, 150)
		end
	end
end

local function placeModelOnPad(player: Player, slot: number, entry: SlotEntry): Model?
	local baseIdx = baseByPlayer[player]
	if not baseIdx then
		return nil
	end
	local base = Map.Bases[baseIdx]
	if not base then
		return nil
	end
	local pad = base.Pads[slot]
	if not pad then
		return nil
	end

	local def = Kaiju.get(entry.Id)
	if not def then
		return nil
	end

	local _, stage = Config.stageFor(entry.Growth)
	local scale = stage.Scale or 1
	local model = KaijuModel.build(def, scale, entry.Mutation)

	-- Position: model bottom sits on top of pad
	local padTop = pad.Position.Y + (pad.Size.Y / 2)
	local root = model.PrimaryPart
	if root then
		local rootHalfY = root.Size.Y / 2
		model:PivotTo(CFrame.new(pad.Position.X, padTop + rootHalfY, pad.Position.Z))
		-- Anchor every part in the model so it stays on the pad
		for _, desc in model:GetDescendants() do
			if desc:IsA("BasePart") then
				desc.Anchored = true
			end
		end
	end

	-- Update Tag info
	local incomeText = Format.rate(Kaiju.incomeOf(entry, (Data.get(player) :: any).Rebirths))
	local stageText = "Stage " .. stage.Name
	KaijuModel.setInfo(model, incomeText, stageText)

	-- Add ProximityPrompt "Sell" for the owner
	local sellPrompt = Instance.new("ProximityPrompt")
	sellPrompt.Name = "SellPrompt"
	sellPrompt.ActionText = "Sell"
	sellPrompt.ObjectText = def.Name
	sellPrompt.HoldDuration = 0.5
	sellPrompt.MaxActivationDistance = 10
	sellPrompt.RequiresLineOfSight = false
	sellPrompt:SetAttribute("OwnerId", player.UserId) -- client shows Sell only to the owner
	if root then
		sellPrompt.Parent = root
	end

	sellPrompt.Triggered:Connect(function(triggerPlayer: Player)
		-- Server-side owner check + cooldown
		local now = os.clock()
		if sellCooldowns[triggerPlayer] and now < sellCooldowns[triggerPlayer] then
			return
		end
		sellCooldowns[triggerPlayer] = now + 0.5

		if triggerPlayer ~= player then
			return
		end

		local profile = Data.get(player)
		if not profile then
			return
		end

		local currentEntry = profile.Slots[slot]
		if not currentEntry then
			return
		end

		local currentDef = Kaiju.get(currentEntry.Id)
		if not currentDef then
			return
		end

		local refund = math.floor(currentDef.Price * Config.SellRefund)
		Bases.removeKaiju(player, slot)
		Data.addMoney(player, refund)
		Net.event("Cash"):FireClient(player, refund, pad.Position + Vector3.new(0, 3, 0))
		notify(player, "good", "Sold " .. currentDef.Name .. " for " .. Format.money(refund))
		refreshIncomeAttribute(player)
	end)

	model.Name = entry.Id .. "_slot" .. slot
	model.Parent = base.Model

	-- Store
	if not slotModels[player] then
		slotModels[player] = {}
	end
	slotModels[player][slot] = model

	-- Track stage
	local stageIdx, _ = Config.stageFor(entry.Growth)
	if not prevStageIdx[player] then
		prevStageIdx[player] = {}
	end
	prevStageIdx[player][slot] = stageIdx

	-- Fire kaijuAdded so Carry can attach Steal prompts
	Bases.kaijuAdded:Fire(player, slot, model)

	return model
end

-- Remove a kaiju model from a pad and return its entry
local function removeModelFromPad(player: Player, slot: number)
	if slotModels[player] and slotModels[player][slot] then
		local model = slotModels[player][slot]
		slotModels[player][slot] = nil
		model:Destroy()
	end
	if prevStageIdx[player] then
		prevStageIdx[player][slot] = nil
	end
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function Bases.baseOf(player: Player): BaseInfo?
	local idx = baseByPlayer[player]
	if idx then
		return Map.Bases[idx]
	end
	return nil
end

function Bases.ownerOf(base: BaseInfo): Player?
	return ownerByBase[base.Index]
end

function Bases.isLocked(base: BaseInfo): boolean
	local endTime = lockEndTimes[base.Index]
	return endTime ~= nil and os.clock() < endTime
end

function Bases.unlockedSlots(player: Player): number
	local profile = Data.get(player)
	local rebirths = if profile then profile.Rebirths else 0
	local count = Config.StartSlots + rebirths * Config.SlotsPerRebirth
	return math.min(count, Config.MaxSlots)
end

function Bases.addKaiju(player: Player, entry: SlotEntry): number?
	local profile = Data.get(player)
	if not profile then
		return nil
	end
	local maxSlots = Bases.unlockedSlots(player)
	-- Find first free unlocked slot (slots whose kaiju is being carried by a thief stay reserved)
	local reserved = profile.Reserved or {}
	for i = 1, maxSlots do
		if not profile.Slots[i] and not reserved[i] then
			profile.Slots[i] = entry
			placeModelOnPad(player, i, entry)
			refreshIncomeAttribute(player)
			return i
		end
	end
	return nil -- no space
end

function Bases.removeKaiju(player: Player, slot: number): SlotEntry?
	local profile = Data.get(player)
	if not profile then
		return nil
	end
	local entry = profile.Slots[slot]
	if not entry then
		return nil
	end
	profile.Slots[slot] = nil
	removeModelFromPad(player, slot)
	refreshIncomeAttribute(player)
	return entry
end

-- Stealing keeps the victim's slot reserved while the kaiju is carried, so it is still
-- saved with the victim's profile and can always go back to the same pad.
function Bases.takeForSteal(owner: Player, slot: number): SlotEntry?
	local profile = Data.get(owner)
	local entry = Bases.removeKaiju(owner, slot)
	if profile and entry then
		profile.Reserved = profile.Reserved or {}
		profile.Reserved[slot] = entry
	end
	return entry
end

-- Put a stolen kaiju back on its pad. False if the reservation is gone (owner left or rebirthed).
function Bases.returnStolen(owner: Player, slot: number, entry: SlotEntry): boolean
	local profile = Data.get(owner)
	if not profile or not profile.Reserved or profile.Reserved[slot] ~= entry then
		return false
	end
	profile.Reserved[slot] = nil
	profile.Slots[slot] = entry
	placeModelOnPad(owner, slot, entry)
	refreshIncomeAttribute(owner)
	return true
end

-- The thief got it home: the victim loses the kaiju for good. False if the reservation is gone.
function Bases.releaseStolen(owner: Player, slot: number, entry: SlotEntry): boolean
	local profile = Data.get(owner)
	if not profile or not profile.Reserved or profile.Reserved[slot] ~= entry then
		return false
	end
	profile.Reserved[slot] = nil
	return true
end

function Bases.hasFreeSlot(player: Player): boolean
	local profile = Data.get(player)
	if not profile then
		return false
	end
	local reserved = profile.Reserved or {}
	for i = 1, Bases.unlockedSlots(player) do
		if not profile.Slots[i] and not reserved[i] then
			return true
		end
	end
	return false
end

function Bases.slotModel(player: Player, slot: number): Model?
	if slotModels[player] then
		return slotModels[player][slot]
	end
	return nil
end

-- ---------------------------------------------------------------------------
-- Base assignment / release
-- ---------------------------------------------------------------------------

local function assignBase(player: Player)
	-- Data.loaded is a BindableEvent, which passes a copy of the profile table;
	-- always work on the live profile so offline income is not lost.
	local profile = Data.get(player)
	if not profile then
		return
	end
	-- Find a free base
	for _, base in Map.Bases do
		if not ownerByBase[base.Index] then
			ownerByBase[base.Index] = player
			baseByPlayer[player] = base.Index
			player:SetAttribute("BaseIndex", base.Index)
			setSignText(base, player.Name)
			refreshPads(base, Bases.unlockedSlots(player))

			-- Offline income
			local now = os.time()
			local offlineSeconds = math.min(now - (profile.LastOnline or now), Config.OfflineCapSeconds)
			if offlineSeconds > 5 then
				-- Compute income from saved slots
				local offlineIncome = 0
				for _, entry in profile.Slots do
					offlineIncome += Kaiju.incomeOf(entry, profile.Rebirths)
				end
				local earned = math.floor(offlineIncome * offlineSeconds * Config.OfflineRate)
				if earned > 0 then
					profile.Bank += earned
					notify(player, "good", "Welcome back! Offline earnings: " .. Format.money(earned))
				end
			end

			-- Place saved kaiju on pads
			for slot, entry in profile.Slots do
				placeModelOnPad(player, slot, entry)
			end

			-- Update displays
			updateBankDisplay(base, profile.Bank)
			refreshIncomeAttribute(player)

			-- Teleport to base spawn
			if isAlive(player) then
				teleportTo(player, base.Spawn)
			end

			-- Teleport on every CharacterAdded
			player.CharacterAdded:Connect(function(char)
				-- Wait a moment for the character to load
				local hum = char:WaitForChild("Humanoid", 5)
				if hum then
					char:WaitForChild("HumanoidRootPart", 5)
					task.wait(0.1)
					local currentBase = Bases.baseOf(player)
					if currentBase then
						teleportTo(player, currentBase.Spawn)
					end
				end
			end)

			return
		end
	end

	-- No free bases: notify and leave at lobby
	notify(player, "bad", "Server is full — no free base available.")
end

local function releaseBase(player: Player)
	local baseIdx = baseByPlayer[player]
	if not baseIdx then
		return
	end
	local base = Map.Bases[baseIdx]

	-- Update LastOnline for offline income calc
	local profile = Data.get(player)
	if profile then
		profile.LastOnline = os.time()
	end

	-- Destroy all kaiju models on pads
	if slotModels[player] then
		for slot, model in slotModels[player] do
			model:Destroy()
		end
		slotModels[player] = nil
	end
	prevStageIdx[player] = nil

	-- Clear ownership
	ownerByBase[baseIdx] = nil
	baseByPlayer[player] = nil
	lockEndTimes[baseIdx] = nil
	lockCooldowns[baseIdx] = nil

	-- Clear cooldowns
	collectCooldowns[player] = nil
	goHomeCooldowns[player] = nil
	rebirthCooldowns[player] = nil
	sellCooldowns[player] = nil

	-- Reset sign
	if base then
		setSignText(base, "Available")
		refreshPads(base, Config.MaxSlots)
		updateBankDisplay(base, 0)
		updateLockDisplay(base, nil)
	end
end

-- ---------------------------------------------------------------------------
-- CollectPlate touch handler
-- ---------------------------------------------------------------------------

local function setupCollectPlate(base: BaseInfo)
	base.CollectPlate.Touched:Connect(function(hit: BasePart)
		local char = hit.Parent
		if not char then
			return
		end
		local player = Players:GetPlayerFromCharacter(char)
		if not player then
			return
		end
		-- Only the owner can collect
		if ownerByBase[base.Index] ~= player then
			return
		end
		-- Anti-spam
		local now = os.clock()
		if collectCooldowns[player] and now < collectCooldowns[player] then
			return
		end
		collectCooldowns[player] = now + 0.3

		local profile = Data.get(player)
		if not profile or profile.Bank <= 0 then
			return
		end

		local amount = profile.Bank
		profile.Bank = 0
		Data.addMoney(player, amount)
		updateBankDisplay(base, 0)
		Net.event("Cash"):FireClient(player, amount, base.CollectPlate.Position + Vector3.new(0, 3, 0))
	end)
end

-- ---------------------------------------------------------------------------
-- LockButton touch handler
-- ---------------------------------------------------------------------------

local function setupLockButton(base: BaseInfo)
	base.LockButton.Touched:Connect(function(hit: BasePart)
		local char = hit.Parent
		if not char then
			return
		end
		local player = Players:GetPlayerFromCharacter(char)
		if not player then
			return
		end
		-- Only owner
		if ownerByBase[base.Index] ~= player then
			return
		end
		-- Cannot re-lock while locked
		if Bases.isLocked(base) then
			return
		end
		-- Cooldown between locks
		local now = os.clock()
		if lockCooldowns[base.Index] and now < lockCooldowns[base.Index] then
			return
		end

		lockEndTimes[base.Index] = now + Config.LockSeconds
		lockCooldowns[base.Index] = now + Config.LockSeconds + Config.LockCooldown
		base.Barrier.Transparency = 0.4
		notify(player, "info", "Base locked for " .. Format.time(Config.LockSeconds))
	end)
end

-- ---------------------------------------------------------------------------
-- Barrier / Zone enforcement (Heartbeat)
-- ---------------------------------------------------------------------------

local function pushPlayerOutOfZone(player: Player, base: BaseInfo)
	local char = player.Character
	if not char then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	-- Bases are walled except for the entrance, so push out through the barrier
	local barrierPos = base.Barrier.Position
	local outward = barrierPos - base.Zone.Position
	outward = Vector3.new(outward.X, 0, outward.Z).Unit
	local target = Vector3.new(barrierPos.X, root.Position.Y, barrierPos.Z) + outward * 6
	root.AssemblyLinearVelocity = outward * 40
	root.CFrame = CFrame.lookAt(target, target + outward)
end

local function isInsideZone(position: Vector3, zone: BasePart): boolean
	local rel = zone.CFrame:PointToObjectSpace(position)
	local halfSize = zone.Size / 2
	return math.abs(rel.X) <= halfSize.X
		and math.abs(rel.Y) <= halfSize.Y
		and math.abs(rel.Z) <= halfSize.Z
end

-- ---------------------------------------------------------------------------
-- Remotes: GoHome, Rebirth
-- ---------------------------------------------------------------------------

local function setupRemotes()
	-- GoHome
	Net.event("GoHome").OnServerEvent:Connect(function(player: Player)
		-- Teleporting home with a stolen kaiju would deliver it instantly
		if player:GetAttribute("Carrying") then
			notify(player, "bad", "You can't teleport home while carrying a kaiju!")
			return
		end
		local now = os.clock()
		if goHomeCooldowns[player] and now < goHomeCooldowns[player] then
			notify(player, "bad", "GoHome on cooldown")
			return
		end
		goHomeCooldowns[player] = now + Config.HomeCooldown

		local base = Bases.baseOf(player)
		if not base then
			return
		end
		if not isAlive(player) then
			return
		end
		teleportTo(player, base.Spawn)
		notify(player, "info", "Teleported home!")
	end)

	-- Rebirth
	Net.event("Rebirth").OnServerEvent:Connect(function(player: Player)
		local now = os.clock()
		if rebirthCooldowns[player] and now < rebirthCooldowns[player] then
			notify(player, "bad", "Rebirth on cooldown")
			return
		end
		rebirthCooldowns[player] = now + 2

		local profile = Data.get(player)
		if not profile then
			return
		end

		local cost = Config.rebirthCost(profile.Rebirths)
		if profile.Money < cost then
			notify(player, "bad", "Need " .. Format.money(cost) .. " to rebirth")
			return
		end

		-- Perform rebirth: reset money to the starting amount (not 0, or the player could
		-- never afford a kaiju again), clear slots, increment rebirths
		Data.setMoney(player, Config.StartMoney)
		profile.Bank = 0
		-- Kaiju being carried off by thieves are wiped too; their delivery is cancelled
		profile.Reserved = {}

		-- Remove all kaiju models
		local baseIdx = baseByPlayer[player]
		if baseIdx then
			local base = Map.Bases[baseIdx]
			if slotModels[player] then
				for slot, model in slotModels[player] do
					model:Destroy()
				end
				slotModels[player] = nil
			end
			if prevStageIdx[player] then
				prevStageIdx[player] = nil
			end
			-- Clear profile slots
			profile.Slots = {}
			if base then
				updateBankDisplay(base, 0)
			end
		end

		Data.setRebirths(player, profile.Rebirths + 1)
		refreshIncomeAttribute(player)
		local rebirthBase = Bases.baseOf(player)
		if rebirthBase then
			refreshPads(rebirthBase, Bases.unlockedSlots(player))
		end
		notify(player, "good", "Rebirth #" .. profile.Rebirths .. "! +50% income, +" .. Config.SlotsPerRebirth .. " slot(s)")
	end)
end

-- ---------------------------------------------------------------------------
-- Income tick + growth loop (Heartbeat-driven accumulator)
-- ---------------------------------------------------------------------------

local incomeAccumulator = 0
local INCOME_TICK = Config.IncomeTick

local function onHeartbeat(dt: number)
	local clockNow = os.clock()

	-- Income accumulator
	incomeAccumulator += dt
	local doIncomeTick = incomeAccumulator >= INCOME_TICK
	if doIncomeTick then
		incomeAccumulator -= INCOME_TICK
	end

	for _, base in Map.Bases do
		local owner = ownerByBase[base.Index]

		-- Lock timer: update display and expire
		if lockEndTimes[base.Index] then
			local remaining = lockEndTimes[base.Index] - clockNow
			if remaining <= 0 then
				lockEndTimes[base.Index] = nil
				base.Barrier.Transparency = 0.8
				updateLockDisplay(base, nil)
			else
				updateLockDisplay(base, remaining)
			end
		end

		-- Barrier enforcement: push non-owners out when locked
		if Bases.isLocked(base) and owner then
			for _, otherPlayer in Players:GetPlayers() do
				if otherPlayer ~= owner then
					local char = otherPlayer.Character
					if char then
						local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root and isInsideZone(root.Position, base.Zone) then
							pushPlayerOutOfZone(otherPlayer, base)
						end
					end
				end
			end
		end

		-- Income tick + growth for owned bases
		if owner and doIncomeTick then
			local profile = Data.get(owner)
			if profile then
				local tickIncome = 0
				local needRefreshIncome = false

				for slot, entry in profile.Slots do
					-- Growth
					local oldStageIdx = if prevStageIdx[owner] then prevStageIdx[owner][slot] else nil
					entry.Growth += INCOME_TICK

					-- Check for stage change
					local newStageIdx, newStage = Config.stageFor(entry.Growth)

					if oldStageIdx and newStageIdx ~= oldStageIdx then
						-- Stage changed: rebuild model with new scale
						removeModelFromPad(owner, slot)
						placeModelOnPad(owner, slot, entry)
						needRefreshIncome = true
					else
						-- Update tag info (income may change due to growth, but stage same)
						if prevStageIdx[owner] then
							prevStageIdx[owner][slot] = newStageIdx
						end
						local model = if slotModels[owner] then slotModels[owner][slot] else nil
						if model then
							local incomeVal = Kaiju.incomeOf(entry, profile.Rebirths)
							KaijuModel.setInfo(
								model,
								Format.rate(incomeVal),
								"Stage " .. newStage.Name
							)
						end
					end

					-- Accumulate income for this tick
					tickIncome += Kaiju.incomeOf(entry, profile.Rebirths)
				end

				if tickIncome > 0 then
					profile.Bank += tickIncome * INCOME_TICK
					updateBankDisplay(base, profile.Bank)
				end

				if needRefreshIncome then
					refreshIncomeAttribute(owner)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------
-- Init
-- ---------------------------------------------------------------------------

function Bases.init()
	-- Subscribe to Data.loaded to assign bases when profiles load
	Data.loaded.Event:Connect(function(player: Player)
		assignBase(player)
	end)

	-- Release base when player leaves
	Players.PlayerRemoving:Connect(function(player: Player)
		releaseBase(player)
	end)

	-- Set up CollectPlate and LockButton touch handlers for all bases
	for _, base in Map.Bases do
		setupCollectPlate(base)
		setupLockButton(base)
		setSignText(base, "Available")
		refreshPads(base, Config.MaxSlots)
	end

	-- Set up remote event handlers
	setupRemotes()

	-- Start Heartbeat loop for income ticks, growth, lock timers, and barrier enforcement
	RunService.Heartbeat:Connect(onHeartbeat)
end

return Bases
