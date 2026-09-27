--!strict
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Format"))

local player = Players.LocalPlayer

local FloatingText = {}

-- Spawns a floating "+$X" billboard in the world that rises and fades away.
function FloatingText.spawn(amount: number, worldPosition: Vector3?)
	amount = tonumber(amount) or 0
	if amount <= 0 then
		return
	end

	-- Resolve target world position
	local spawnPos: Vector3
	if worldPosition then
		spawnPos = worldPosition
	else
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			spawnPos = root.Position + Vector3.new(0, 3, 0)
		else
			local camera = workspace.CurrentCamera
			spawnPos = if camera then camera.CFrame.Position + camera.CFrame.LookVector * 10 else Vector3.zero
		end
	end

	-- Add small random horizontal jitter so rapid consecutive cash pickups do not overlap exactly
	local jitter = Vector3.new(
		(math.random() - 0.5) * 1.8,
		(math.random() - 0.5) * 0.4,
		(math.random() - 0.5) * 1.8
	)
	local finalPos = spawnPos + jitter

	-- Create local anchor part for the billboard
	local anchor = Instance.new("Part")
	anchor.Name = "CashBillboardAnchor"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanTouch = false
	anchor.CanQuery = false
	anchor.Anchored = true
	anchor.CFrame = CFrame.new(finalPos)
	anchor.Parent = workspace

	-- Create BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CashPopup"
	billboard.Adornee = anchor
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.new(0, 180, 0, 50)
	billboard.StudsOffsetWorldSpace = Vector3.zero
	billboard.MaxDistance = 250
	billboard.ResetOnSpawn = false
	billboard.Parent = anchor

	-- Label
	local label = Instance.new("TextLabel")
	label.Name = "AmountLabel"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "+ " .. Format.money(amount)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 26
	label.TextColor3 = Color3.fromRGB(80, 255, 120)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(10, 45, 15)
	label.Parent = billboard

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Thickness = 2.5
	uiStroke.Color = Color3.fromRGB(10, 45, 15)
	uiStroke.Transparency = 0.2
	uiStroke.Parent = label

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0.5
	uiScale.Parent = label

	-- Pop scale animation (0.5 -> 1.2 -> 1.0)
	local popTween = TweenService:Create(
		uiScale,
		TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1.15 }
	)
	popTween:Play()

	popTween.Completed:Connect(function()
		if uiScale.Parent then
			TweenService:Create(
				uiScale,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Scale = 1.0 }
			):Play()
		end
	end)

	-- Float upward
	local floatTween = TweenService:Create(
		billboard,
		TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = Vector3.new(0, 5.0, 0) }
	)
	floatTween:Play()

	-- Fade out text and stroke smoothly after a short pause
	task.delay(0.65, function()
		if not label.Parent then
			return
		end
		local fadeTween = TweenService:Create(
			label,
			TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ TextTransparency = 1 }
		)
		local strokeFadeTween = TweenService:Create(
			uiStroke,
			TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Transparency = 1 }
		)
		fadeTween:Play()
		strokeFadeTween:Play()
	end)

	-- Cleanup anchor and billboard
	task.delay(1.25, function()
		anchor:Destroy()
	end)
end

return FloatingText
