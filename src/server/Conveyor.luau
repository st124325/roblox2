-- Conveyor belt: spawn kaiju models every BeltSpawnSeconds, slide them along
-- Map.Belt via Heartbeat + PivotTo, and let players buy them with a ProximityPrompt.
-- Bought kaiju goes directly into the buyer's base (no carry phase).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Kaiju = require(Shared:WaitForChild("Kaiju"))
local KaijuModel = require(Shared:WaitForChild("KaijuModel"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))

local Server = script.Parent
local Data = require(Server:WaitForChild("Data"))
local Events = require(Server:WaitForChild("Events"))
local Map = require(Server:WaitForChild("Map"))
local Bases = require(Server:WaitForChild("Bases"))

local Conveyor = {}

-- Active models currently riding the belt
local riding: { [Model]: { def: any, progress: number, totalDist: number, rootHalfY: number } } = {}

local beltStart: Vector3
local beltFinish: Vector3
local beltDir: Vector3
local beltDist: number

local rng = Random.new()
local conveyorFolder: Folder

-- ── helpers ────────────────────────────────────────────────────────────────────

-- Pivot for a model whose Root is rootHalfY tall above its bottom: feet on the belt, facing travel direction
local function positionOnBelt(progress: number, rootHalfY: number): CFrame
	local pos = beltStart + beltDir * progress + Vector3.new(0, rootHalfY, 0)
	return CFrame.lookAt(pos, pos + beltDir)
end

local function removeFromBelt(model: Model)
	riding[model] = nil
	model:Destroy()
end

-- ── purchase handler ──────────────────────────────────────────────────────────

local function onPromptTriggered(prompt: ProximityPrompt, player: Player)
	-- The prompt lives on the model's Root part
	local model = prompt:FindFirstAncestorOfClass("Model")
	local info = if model then riding[model] else nil
	if not info then
		return -- already bought or gone
	end

	local def = info.def
	local profile = Data.get(player)
	if not profile then
		return
	end

	-- Check money
	if profile.Money < def.Price then
		Net.event("Notify"):FireClient(player, "bad", "Not enough money! Need " .. Format.money(def.Price))
		return
	end

	-- Check slot availability
	local entry = { Id = def.Id, Growth = 0, Mutation = nil }
	local slot = Bases.addKaiju(player, entry)
	if not slot then
		local unlocked = Bases.unlockedSlots(player)
		Net.event("Notify"):FireClient(player, "bad", "Base full (" .. unlocked .. "/" .. unlocked .. ")! Sell a kaiju or Rebirth to unlock more slots.")
		return
	end

	-- Deduct money
	Data.addMoney(player, -def.Price)

	-- Track stats
	profile.Stats.Bought += 1
	Events.Bought:Fire(player, def.Id)

	-- Remove from conveyor
	removeFromBelt(model :: Model)

	Net.event("Notify"):FireClient(player, "good", "Bought " .. def.Name .. "!")
end

-- ── spawning ──────────────────────────────────────────────────────────────────

local function spawnKaiju()
	local def = Kaiju.roll(rng)

	local model = KaijuModel.build(def, 1, nil)
	model.Name = "BeltKaiju_" .. def.Id
	model:SetAttribute("Price", def.Price) -- the tutorial beam points at an affordable one

	local root = model.PrimaryPart
	if not root then
		model:Destroy()
		return
	end
	local rootHalfY = root.Size.Y / 2

	-- Set all parts anchored (belt models don't need physics)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
		end
	end

	model:PivotTo(positionOnBelt(0, rootHalfY))
	model.Parent = conveyorFolder

	-- Proximity prompt for buying
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Buy"
	prompt.ActionText = "Buy " .. Format.money(def.Price)
	prompt.ObjectText = def.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	prompt.Triggered:Connect(function(player: Player)
		onPromptTriggered(prompt, player)
	end)

	riding[model] = {
		def = def,
		progress = 0,
		totalDist = beltDist,
		rootHalfY = rootHalfY,
	}
end

-- ── main loop ─────────────────────────────────────────────────────────────────

local function startSpawnLoop()
	task.spawn(function()
		while true do
			task.wait(Config.BeltSpawnSeconds)
			spawnKaiju()
		end
	end)
end

local function onHeartbeat(dt: number)
	local speed = Config.BeltSpeed
	local step = speed * dt

	for model, info in riding do
		info.progress += step
		if info.progress >= info.totalDist then
			removeFromBelt(model)
		else
			model:PivotTo(positionOnBelt(info.progress, info.rootHalfY))
		end
	end
end

-- ── public API ────────────────────────────────────────────────────────────────

function Conveyor.init()
	local belt = Map.Belt
	beltStart = belt.Start
	beltFinish = belt.Finish
	local delta = beltFinish - beltStart
	beltDist = delta.Magnitude
	beltDir = delta.Unit

	-- Workspace folder for belt kaiju
	conveyorFolder = Instance.new("Folder")
	conveyorFolder.Name = "ConveyorKaiju"
	conveyorFolder.Parent = Workspace

	RunService.Heartbeat:Connect(onHeartbeat)
	startSpawnLoop()

	-- Clean up belt models for players who leave mid-purchase (no action needed,
	-- prompts simply become inactive). Nothing to clean per-player here.
end

return Conveyor
