-- World feedback for gameplay events: sounds and particle bursts everyone nearby sees.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared:WaitForChild("Sounds"))

local Server = script.Parent
local Events = require(Server:WaitForChild("Events"))
local Bases = require(Server:WaitForChild("Bases"))

local Feedback = {}

-- One-shot sparkle burst on `part`.
function Feedback.burst(part: BasePart, color: Color3, count: number?)
	local attachment = Instance.new("Attachment")
	attachment.Parent = part
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(count or 40)
	Debris:AddItem(attachment, 2)
end

function Feedback.init()
	Events.StageUp.Event:Connect(function(player: Player, slot: number, stageName: string)
		local model = Bases.slotModel(player, slot)
		local root = model and model.PrimaryPart
		if root then
			Sounds.playAt(root, "StageUp")
			local color = if stageName == "Titan" then Color3.fromRGB(255, 80, 200) else Color3.fromRGB(255, 220, 90)
			Feedback.burst(root, color, if stageName == "Titan" then 90 else 40)
		end
	end)

	Events.Bought.Event:Connect(function(player: Player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			Sounds.playAt(root, "Buy")
		end
	end)

	Events.Stolen.Event:Connect(function(thief: Player)
		local character = thief.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			Sounds.playAt(root, "Whoosh")
			Feedback.burst(root, Color3.fromRGB(120, 255, 140), 30)
		end
	end)
end

return Feedback
