-- First-session tutorial: buy a kaiju -> collect cash -> lock the base -> final tip.
-- Progress is saved in profile.Meta.Tutorial; the client draws the banner and the guide beam
-- from the player's "TutorialStep" attribute and "TutorialTarget" ObjectValue.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))

local Server = script.Parent
local Data = require(Server:WaitForChild("Data"))
local Events = require(Server:WaitForChild("Events"))
local Bases = require(Server:WaitForChild("Bases"))

local Tutorial = {}

local STEP_BUY, STEP_COLLECT, STEP_LOCK, STEP_TIP, STEP_DONE = 1, 2, 3, 4, 5
local TIP_SECONDS = 10

local function targetFor(player: Player, step: number): Instance?
	local base = Bases.baseOf(player)
	if not base then
		return nil
	end
	if step == STEP_COLLECT then
		return base.CollectPlate
	elseif step == STEP_LOCK then
		return base.LockButton
	end
	return nil -- step 1 points at a conveyor kaiju, chosen on the client
end

local function targetValue(player: Player): ObjectValue
	local value = player:FindFirstChild("TutorialTarget") :: ObjectValue?
	if not value then
		local created = Instance.new("ObjectValue")
		created.Name = "TutorialTarget"
		created.Parent = player
		value = created
	end
	return value :: ObjectValue
end

local function setStep(player: Player, step: number)
	local profile = Data.get(player)
	if not profile then
		return
	end
	profile.Meta.Tutorial = step
	player:SetAttribute("TutorialStep", step)
	targetValue(player).Value = targetFor(player, step)

	if step == STEP_TIP then
		Data.addMoney(player, Config.TutorialReward)
		Net.event("Notify"):FireClient(player, "good", "Tutorial complete! +" .. Format.money(Config.TutorialReward))
		task.delay(TIP_SECONDS, function()
			local current = Data.get(player)
			if current and current.Meta.Tutorial == STEP_TIP then
				setStep(player, STEP_DONE)
			end
		end)
	end
end

local function advance(player: Player, from: number)
	local profile = Data.get(player)
	if profile and (profile.Meta.Tutorial or STEP_BUY) == from then
		setStep(player, from + 1)
	end
end

function Tutorial.init()
	Data.loaded.Event:Connect(function(player: Player)
		local profile = Data.get(player)
		if not profile then
			return
		end
		local step = tonumber(profile.Meta.Tutorial) or STEP_BUY
		-- Players from before the tutorial existed skip what they've clearly done
		if step == STEP_BUY and profile.Stats.Bought > 0 then
			step = STEP_COLLECT
		end
		if step == STEP_TIP then
			step = STEP_DONE
		end
		-- The base is assigned by another Data.loaded listener; give it a moment
		task.delay(1, function()
			if player.Parent == Players then
				setStep(player, step)
			end
		end)
	end)

	Events.Bought.Event:Connect(function(player: Player)
		advance(player, STEP_BUY)
	end)
	Events.Collected.Event:Connect(function(player: Player)
		advance(player, STEP_COLLECT)
	end)
	Events.Locked.Event:Connect(function(player: Player)
		advance(player, STEP_LOCK)
	end)
end

return Tutorial
