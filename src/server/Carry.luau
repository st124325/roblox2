-- Carry module: stealing kaiju from other players' bases, carrying them overhead,
-- delivering to the thief's base, Bonk bat tool, stun, timeout, death/leave returns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Kaiju = require(Shared:WaitForChild("Kaiju"))
local KaijuModel = require(Shared:WaitForChild("KaijuModel"))
local Net = require(Shared:WaitForChild("Net"))

local Server = script.Parent
local Data = require(Server:WaitForChild("Data"))
local Map = require(Server:WaitForChild("Map"))
local Bases = require(Server:WaitForChild("Bases"))

local Carry = {}

-- ── types ─────────────────────────────────────────────────────────────────────

type CarryState = {
	thief: Player,
	owner: Player,            -- the victim (who got stolen from)
	slot: number,             -- victim's pad, reserved until the carry ends
	entry: any,               -- SlotEntry: { Id, Growth, Mutation? }
	model: Model,             -- visual model welded above thief's head
	weld: WeldConstraint,     -- attaches model to HumanoidRootPart
	startTime: number,        -- os.clock() when steal happened
	originalSpeed: number,    -- thief's normal WalkSpeed before carrying
	zoneConn: RBXScriptConnection?, -- touch listener for delivery
	fullWarnAt: number?,      -- last "no free slots" warning
}

-- ── state ─────────────────────────────────────────────────────────────────────

local carrying: { [Player]: CarryState } = {}
local bonkCooldowns: { [Player]: number } = {}  -- os.clock of last bonk
local stunned: { [Player]: number } = {}         -- os.clock stun expires

local carryFolder: Folder -- parent for carried kaiju models

-- ── helpers ───────────────────────────────────────────────────────────────────

local function getCharacter(player: Player): (Model?, any?, any?)
	local char = player.Character
	if not char then
		return nil, nil, nil
	end
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char:FindFirstChildWhichIsA("Humanoid")
	return char, hrp, hum
end

local function isAlive(player: Player): boolean
	local _, hrp, hum = getCharacter(player)
	return hrp ~= nil and hum ~= nil and (hum :: any).Health > 0
end

-- ── return stolen kaiju to its owner ──────────────────────────────────────────

-- Drop the carried model and restore the thief; does not decide where the kaiju goes.
local function endCarry(state: CarryState)
	-- Cleanup visual model
	if state.model and state.model.Parent then
		state.model:Destroy()
	end

	-- Cleanup zone connection
	if state.zoneConn then
		state.zoneConn:Disconnect()
		state.zoneConn = nil
	end

	-- Restore thief's WalkSpeed
	local _, _, hum = getCharacter(state.thief)
	if hum then
		(hum :: any).WalkSpeed = state.originalSpeed
	end

	carrying[state.thief] = nil
	state.thief:SetAttribute("Carrying", nil)
end

local function returnKaiju(state: CarryState)
	endCarry(state)
	-- The victim's pad stayed reserved, so the kaiju always fits back
	local owner = state.owner
	if Bases.returnStolen(owner, state.slot, state.entry) then
		Net.event("Notify"):FireClient(owner, "info", "Your " .. (Kaiju.get(state.entry.Id) or { Name = "Kaiju" }).Name .. " was returned!")
	end
end

-- ── deliver stolen kaiju to thief's base ──────────────────────────────────────

local function deliverKaiju(state: CarryState)
	local thief = state.thief
	local defName = (Kaiju.get(state.entry.Id) or { Name = "Kaiju" }).Name

	-- No free slot: keep carrying, the thief can sell something and come back
	if not Bases.hasFreeSlot(thief) then
		local now = os.clock()
		if not state.fullWarnAt or now - state.fullWarnAt > 3 then
			state.fullWarnAt = now
			Net.event("Notify"):FireClient(thief, "bad", "No free slots! Sell a kaiju to make room for " .. defName .. ".")
		end
		return
	end

	endCarry(state)

	-- The victim rebirthed or left mid-carry: their save keeps the kaiju, so the thief gets nothing
	if not Bases.releaseStolen(state.owner, state.slot, state.entry) then
		Net.event("Notify"):FireClient(thief, "bad", defName .. " slipped away!")
		return
	end

	-- Growth is preserved from the original
	Bases.addKaiju(thief, state.entry)

	local thiefProfile = Data.get(thief)
	if thiefProfile then
		thiefProfile.Stats.Stolen += 1
	end
	local ownerProfile = Data.get(state.owner)
	if ownerProfile then
		ownerProfile.Stats.Lost += 1
	end
	Net.event("Notify"):FireClient(thief, "good", "Delivered " .. defName .. "!")
end

-- ── attach model above thief's head ───────────────────────────────────────────

local function attachModelToThief(state: CarryState)
	local _, hrp, _ = getCharacter(state.thief)
	if not hrp then
		return
	end

	local def = Kaiju.get(state.entry.Id)
	if not def then
		return
	end

	-- Determine scale based on growth stage
	local _, stage = Config.stageFor(state.entry.Growth)
	local scale = stage.Scale or 1

	-- Build a fresh model for carry display
	local model = KaijuModel.build(def, scale, state.entry.Mutation)
	model.Name = "CarriedKaiju"

	local root = model.PrimaryPart
	if not root then
		model:Destroy()
		return
	end

	-- Position above the thief's head
	root.Anchored = false
	root.CanCollide = false
	root.Massless = true

	-- Unanchor all children
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
		end
	end

	-- Place model above head: offset Y = character head height (~2 studs) + root half-height
	local rootHalfY = root.Size.Y / 2
	local yOffset = 2.5 + rootHalfY

	model:PivotTo((hrp :: BasePart).CFrame * CFrame.new(0, yOffset, 0))
	model.Parent = carryFolder

	-- Weld model root to HumanoidRootPart
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp :: BasePart
	weld.Part1 = root
	weld.Parent = root

	state.model = model
	state.weld = weld
end

-- ── zone delivery detection ───────────────────────────────────────────────────

local function setupZoneDetection(state: CarryState)
	local base = Bases.baseOf(state.thief)
	if not base then
		return
	end

	local zone = base.Zone
	if not zone then
		return
	end

	-- Check if thief is already inside the zone (touching)
	local function checkOverlap()
		local _, hrp, _ = getCharacter(state.thief)
		if not hrp then
			return false
		end
		-- Simple AABB overlap check
		local zonePos = zone.Position
		local zoneSize = zone.Size / 2
		local charPos = (hrp :: BasePart).Position
		return math.abs(charPos.X - zonePos.X) <= zoneSize.X
			and math.abs(charPos.Y - zonePos.Y) <= zoneSize.Y
			and math.abs(charPos.Z - zonePos.Z) <= zoneSize.Z
	end

	-- Use Touched to detect when the thief enters their own zone
	state.zoneConn = zone.Touched:Connect(function(hit: BasePart)
		if not carrying[state.thief] then
			return
		end
		local hitChar = hit.Parent
		if not hitChar then
			return
		end
		local hitPlayer = Players:GetPlayerFromCharacter(hitChar)
		if hitPlayer == state.thief then
			deliverKaiju(state)
		end
	end)

	-- Also check immediately in case already overlapping
	if checkOverlap() then
		task.defer(function()
			if carrying[state.thief] then
				deliverKaiju(state)
			end
		end)
	end
end

-- ── steal handler ─────────────────────────────────────────────────────────────

local function onStealTriggered(prompt: ProximityPrompt, player: Player)
	-- Can't steal if already carrying
	if carrying[player] then
		Net.event("Notify"):FireClient(player, "bad", "Already carrying a kaiju!")
		return
	end

	-- Can't steal while stunned
	if stunned[player] and os.clock() < stunned[player] then
		return
	end

	-- Must be alive
	if not isAlive(player) then
		return
	end

	-- Identify the model and its owner from the prompt
	local model = prompt.Parent
	if not model or not model:IsA("Model") then
		-- prompt is on Root part, model is Root's parent
		model = prompt.Parent and prompt.Parent.Parent
	end
	if not model or not model:IsA("Model") then
		return
	end

	-- Find which base/slot this model belongs to
	-- Walk through all bases to find the owner and slot
	local owner: Player? = nil
	local slotNum: number? = nil

	for _, baseInfo in Map.Bases do
		local baseOwner = Bases.ownerOf(baseInfo)
		if baseOwner then
			for slot = 1, Config.MaxSlots do
				local slotModel = Bases.slotModel(baseOwner, slot)
				if slotModel and (slotModel == model or slotModel:IsAncestorOf(prompt)) then
					owner = baseOwner
					slotNum = slot
					break
				end
			end
		end
		if owner then
			break
		end
	end

	if not owner or not slotNum then
		return
	end

	-- Can't steal from yourself
	if owner == player then
		return
	end

	-- Check if base is locked
	local ownerBase = Bases.baseOf(owner)
	if ownerBase and Bases.isLocked(ownerBase) then
		Net.event("Notify"):FireClient(player, "bad", "This base is locked!")
		return
	end

	-- Remove kaiju from base (its pad stays reserved for the owner)
	local entry = Bases.takeForSteal(owner, slotNum)
	if not entry then
		return
	end

	-- Determine carry speed multiplier
	local _, stage = Config.stageFor(entry.Growth)
	local carrySpeedFactor = stage.Carry or 1

	-- Store thief's original speed
	local _, _, hum = getCharacter(player)
	if not hum then
		-- Player died between prompt trigger and processing, return kaiju
		Bases.returnStolen(owner, slotNum, entry)
		return
	end

	local originalSpeed = (hum :: any).WalkSpeed or Config.WalkSpeed

	-- Create carry state
	local state: CarryState = {
		thief = player,
		owner = owner,
		slot = slotNum,
		entry = entry,
		model = nil :: any,
		weld = nil :: any,
		startTime = os.clock(),
		originalSpeed = originalSpeed,
		zoneConn = nil,
	}

	carrying[player] = state
	player:SetAttribute("Carrying", true) -- Bases blocks GoHome while carrying

	-- Slow down thief
	hum.WalkSpeed = Config.WalkSpeed * carrySpeedFactor

	-- Build and attach visual model
	attachModelToThief(state)

	-- Notify the owner
	local defName = (Kaiju.get(entry.Id) or { Name = "Kaiju" }).Name
	Net.event("Robbed"):FireClient(owner, player.Name, defName)

	-- Setup zone delivery detection
	setupZoneDetection(state)

	-- Timeout coroutine
	task.spawn(function()
		task.wait(Config.CarryTimeoutSeconds)
		if carrying[player] and carrying[player] == state then
			Net.event("Notify"):FireClient(player, "bad", "Carry timed out! " .. defName .. " returned.")
			returnKaiju(state)
		end
	end)
end

-- ── attach steal prompts to kaiju models placed on bases ──────────────────────

local function attachStealPrompt(ownerPlayer: Player, slot: number, model: Model)
	-- Find the root part of the model to attach the prompt
	local root = model.PrimaryPart or model:FindFirstChild("Root")
	if not root then
		return
	end

	-- Remove existing steal prompt if any
	local existing = root:FindFirstChild("Steal")
	if existing then
		existing:Destroy()
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Steal"
	prompt.ActionText = "Steal"
	local profile = Data.get(ownerPlayer)
	local entry = if profile then profile.Slots[slot] else nil
	local def = if entry then Kaiju.get(entry.Id) else nil
	prompt.ObjectText = if def then def.Name else "Kaiju"
	prompt:SetAttribute("OwnerId", ownerPlayer.UserId) -- client hides Steal from the owner
	prompt.HoldDuration = Config.StealHoldSeconds
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.Parent = root

	prompt.Triggered:Connect(function(player: Player)
		onStealTriggered(prompt, player)
	end)
end

-- ── Bonk Tool ─────────────────────────────────────────────────────────────────

local BONK_TOOL_COLOR = Color3.fromRGB(160, 82, 45)
local BONK_HANDLE_COLOR = Color3.fromRGB(90, 50, 25)

local function createBonkTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Bonk"
	tool.CanBeDropped = false
	tool.RequiresHandle = true

	-- Build handle from parts (main bat shaft + head)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 3.5, 0.5)
	handle.Color = BONK_HANDLE_COLOR
	handle.Material = Enum.Material.Wood
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	-- Bat head (wider top part)
	local head = Instance.new("Part")
	head.Name = "BatHead"
	head.Size = Vector3.new(0.8, 1.2, 0.8)
	head.Color = BONK_TOOL_COLOR
	head.Material = Enum.Material.Wood
	head.Anchored = false
	head.CanCollide = false
	head.Massless = true
	head.Parent = tool

	-- Weld bat head to handle
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = head
	weld.Parent = handle

	-- Position bat head at top of handle
	head.CFrame = handle.CFrame * CFrame.new(0, 2.35, 0)

	-- Grip: hold tool by the bottom, pointing upward
	tool.GripPos = Vector3.new(0, -0.8, 0)
	tool.GripForward = Vector3.new(0, 0, -1)
	tool.GripRight = Vector3.new(1, 0, 0)
	tool.GripUp = Vector3.new(0, 1, 0)

	return tool
end

local function onBonkActivated(player: Player)
	-- Cooldown check
	local now = os.clock()
	local lastBonk = bonkCooldowns[player]
	if lastBonk and (now - lastBonk) < Config.BonkCooldown then
		return
	end
	bonkCooldowns[player] = now

	-- Must be alive
	if not isAlive(player) then
		return
	end

	local _, hrp, _ = getCharacter(player)
	if not hrp then
		return
	end

	local bonkPos = (hrp :: BasePart).Position

	-- Swing animation: quick grip rotation via Tween on the tool
	local char = player.Character
	if char then
		local tool = char:FindFirstChildWhichIsA("Tool")
		if tool then
			-- Save original grip
			local origForward = tool.GripForward
			local origRight = tool.GripRight
			local origUp = tool.GripUp

			-- Swing forward
			tool.GripForward = Vector3.new(0, -1, 0)
			tool.GripUp = Vector3.new(0, 0, 1)

			-- Return to normal after a short delay
			task.delay(0.25, function()
				if tool and tool.Parent then
					tool.GripForward = origForward
					tool.GripRight = origRight
					tool.GripUp = origUp
				end
			end)
		end
	end

	-- Bonk every other player in range: knockback + stun, and knock out a carried kaiju
	for _, target in Players:GetPlayers() do
		if target == player then
			continue
		end
		local _, targetHrp, targetHum = getCharacter(target)
		if not targetHrp or not targetHum or targetHum.Health <= 0 then
			continue
		end
		local offset = (targetHrp :: BasePart).Position - bonkPos
		if offset.Magnitude > Config.BonkRange then
			continue
		end

		local flat = Vector3.new(offset.X, 0, offset.Z)
		local push = if flat.Magnitude > 0.1 then flat.Unit else (hrp :: BasePart).CFrame.LookVector
		;(targetHrp :: BasePart).AssemblyLinearVelocity = push * 45 + Vector3.new(0, 25, 0)

		local stunEnd = now + Config.BonkStunSeconds
		stunned[target] = stunEnd
		targetHum.WalkSpeed = 0
		task.delay(Config.BonkStunSeconds, function()
			-- A newer bonk extends the stun; only the latest one restores speed
			if stunned[target] ~= stunEnd then
				return
			end
			stunned[target] = nil
			local _, _, hum = getCharacter(target)
			if hum then
				hum.WalkSpeed = Config.WalkSpeed
			end
		end)

		local state = carrying[target]
		if state then
			local defName = (Kaiju.get(state.entry.Id) or { Name = "Kaiju" }).Name
			Net.event("Notify"):FireClient(target, "bad", "Bonked! " .. defName .. " dropped!")
			Net.event("Notify"):FireClient(player, "good", "Bonked " .. target.Name .. "! " .. defName .. " goes home.")
			returnKaiju(state)
			-- returnKaiju restored the carry speed; keep the target stunned
			targetHum.WalkSpeed = 0
		end
	end
end

local function giveBonkTool(player: Player)
	-- Wait for character
	local function onCharacterAdded(char: Model)
		-- Small yield to let backpack initialize
		task.wait(0.5)
		if not player:IsDescendantOf(Players) then
			return
		end

		local backpack = player:FindFirstChildWhichIsA("Backpack")
		if not backpack then
			return
		end

		-- Don't duplicate
		if backpack:FindFirstChild("Bonk") then
			return
		end

		local tool = createBonkTool()
		tool.Parent = backpack

		tool.Activated:Connect(function()
			onBonkActivated(player)
		end)
	end

	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

-- ── death / leave cleanup ─────────────────────────────────────────────────────

local function onPlayerDied(player: Player)
	local state = carrying[player]
	if state then
		local defName = (Kaiju.get(state.entry.Id) or { Name = "Kaiju" }).Name
		Net.event("Notify"):FireClient(player, "bad", "You died! " .. defName .. " returned to owner.")
		returnKaiju(state)
	end
end

local function onPlayerRemoving(player: Player)
	-- If thief leaves, return kaiju to owner
	local state = carrying[player]
	if state then
		returnKaiju(state)
	end

	-- The victim left: their save already holds the kaiju, so drop it from the thief's hands
	for _, other in carrying do
		if other.owner == player then
			endCarry(other)
			Net.event("Notify"):FireClient(other.thief, "bad", "The owner left — the kaiju vanished!")
		end
	end

	-- Clear any state
	bonkCooldowns[player] = nil
	stunned[player] = nil
end

-- ── character tracking for death detection ────────────────────────────────────

local characterConnections: { [Player]: { RBXScriptConnection } } = {}

local function trackCharacter(player: Player, char: Model)
	-- Clean old connections
	local old = characterConnections[player]
	if old then
		for _, conn in old do
			conn:Disconnect()
		end
	end

	local conns: { RBXScriptConnection } = {}
	characterConnections[player] = conns

	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		table.insert(conns, (hum :: any).Died:Connect(function()
			onPlayerDied(player)
		end))
	end
end

-- ── public API ────────────────────────────────────────────────────────────────

function Carry.isCarrying(player: Player): boolean
	return carrying[player] ~= nil
end

function Carry.init()
	carryFolder = Instance.new("Folder")
	carryFolder.Name = "CarriedKaiju"
	carryFolder.Parent = Workspace

	-- Subscribe to Bases.kaijuAdded to attach steal prompts
	Bases.kaijuAdded.Event:Connect(function(player: Player, slot: number, model: Model)
		attachStealPrompt(player, slot, model)
	end)

	-- Handle Data.loaded: give Bonk tool when player data is ready
	Data.loaded.Event:Connect(function(player: Player, _profile: any)
		giveBonkTool(player)
	end)

	-- Track characters for death detection
	for _, player in Players:GetPlayers() do
		if player.Character then
			task.spawn(trackCharacter, player, player.Character)
		end
		player.CharacterAdded:Connect(function(char)
			trackCharacter(player, char)
		end)
	end

	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(char)
			trackCharacter(player, char)
		end)
	end)

	-- Cleanup on player leaving
	Players.PlayerRemoving:Connect(function(player: Player)
		onPlayerRemoving(player)

		-- Also return any kaiju that other thieves stole from this leaving player
		-- (already handled by returnKaiju checking owner in-game)

		-- Clean up character tracking
		local conns = characterConnections[player]
		if conns then
			for _, conn in conns do
				conn:Disconnect()
			end
			characterConnections[player] = nil
		end
	end)
end

return Carry
