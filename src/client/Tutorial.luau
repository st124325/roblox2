-- Tutorial overlay: a banner with the current instruction, a glowing beam from the player to
-- the target and a bouncing arrow above it. Driven by the server's "TutorialStep" attribute and
-- "TutorialTarget" ObjectValue (step 1 targets the nearest affordable conveyor kaiju instead).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Sounds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sounds"))

local Tutorial = {}

local player = Players.LocalPlayer

local TEXTS = {
	[1] = "Walk up to a kaiju on the conveyor and buy it!",
	[2] = "Your kaiju makes cash. Step on the cash plate to collect it!",
	[3] = "Thieves are coming! Step on the lock button to protect your base.",
	[4] = "You're ready! Steal kaiju from other bases — and bonk thieves with your bat.",
}
local STEP_COLOR = Color3.fromRGB(255, 214, 64)

local banner: Frame
local bannerText: TextLabel
local beam: Beam
local fromAttachment: Attachment
local toAttachment: Attachment
local arrow: BillboardGui
local currentStep = 0
local scanAccumulator = 0

local function makeBanner(parent: ScreenGui)
	banner = Instance.new("Frame")
	banner.Name = "TutorialBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 96)
	banner.Size = UDim2.new(0, 520, 0, 58)
	banner.BackgroundColor3 = Color3.fromRGB(24, 22, 40)
	banner.BackgroundTransparency = 0.1
	banner.Visible = false
	banner.Parent = parent

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(520, 58)
	sizeLimit.Parent = banner
	banner.Size = UDim2.new(0.92, 0, 0, 58)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = banner

	local stroke = Instance.new("UIStroke")
	stroke.Color = STEP_COLOR
	stroke.Thickness = 3
	stroke.Parent = banner

	bannerText = Instance.new("TextLabel")
	bannerText.BackgroundTransparency = 1
	bannerText.Size = UDim2.new(1, -24, 1, -8)
	bannerText.Position = UDim2.new(0, 12, 0, 4)
	bannerText.Font = Enum.Font.FredokaOne
	bannerText.TextScaled = true
	bannerText.TextColor3 = Color3.fromRGB(255, 255, 255)
	bannerText.Parent = banner

	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = 24
	textLimit.Parent = bannerText
end

local function makeGuide()
	toAttachment = Instance.new("Attachment")
	toAttachment.Name = "TutorialTo"

	beam = Instance.new("Beam")
	beam.Name = "TutorialBeam"
	beam.Color = ColorSequence.new(STEP_COLOR)
	beam.LightEmission = 1
	beam.Width0 = 0.7
	beam.Width1 = 0.7
	beam.FaceCamera = true
	beam.Segments = 20
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	beam.Attachment1 = toAttachment
	beam.Enabled = false
	beam.Parent = Workspace.Terrain

	arrow = Instance.new("BillboardGui")
	arrow.Name = "TutorialArrow"
	arrow.Size = UDim2.new(0, 80, 0, 80)
	arrow.StudsOffset = Vector3.new(0, 6, 0)
	arrow.AlwaysOnTop = true
	arrow.Enabled = false

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Text = "▼"
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = STEP_COLOR
	label.TextStrokeTransparency = 0
	label.Parent = arrow

	-- Bounce forever
	TweenService:Create(
		arrow,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ StudsOffset = Vector3.new(0, 8, 0) }
	):Play()
end

local function attachToCharacter(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end
	fromAttachment = Instance.new("Attachment")
	fromAttachment.Name = "TutorialFrom"
	fromAttachment.Parent = root
	beam.Attachment0 = fromAttachment
end

local function pointAt(part: BasePart?)
	if not part or not part:IsDescendantOf(Workspace) then
		beam.Enabled = false
		arrow.Enabled = false
		toAttachment.Parent = nil
		arrow.Adornee = nil
		return
	end
	if toAttachment.Parent ~= part then
		toAttachment.Parent = part
		arrow.Adornee = part
		arrow.Parent = part
	end
	beam.Enabled = fromAttachment ~= nil and fromAttachment.Parent ~= nil
	arrow.Enabled = true
end

-- Step 1: the nearest kaiju on the conveyor the player can afford.
local function nearestAffordableKaiju(): BasePart?
	local folder = Workspace:FindFirstChild("ConveyorKaiju")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not folder or not root then
		return nil
	end
	local money = player:GetAttribute("Money") or 0
	local best, bestDistance = nil, math.huge
	for _, model in folder:GetChildren() do
		if model:IsA("Model") and model.PrimaryPart and (model:GetAttribute("Price") or math.huge) <= money then
			local distance = (model.PrimaryPart.Position - root.Position).Magnitude
			if distance < bestDistance then
				best, bestDistance = model.PrimaryPart, distance
			end
		end
	end
	return best
end

local function targetForStep(): BasePart?
	if currentStep == 1 then
		return nearestAffordableKaiju()
	end
	local value = player:FindFirstChild("TutorialTarget") :: ObjectValue?
	local target = value and value.Value
	return if target and target:IsA("BasePart") then target else nil
end

local function onStepChanged()
	local step = player:GetAttribute("TutorialStep")
	step = if typeof(step) == "number" then step else 0
	if step == currentStep then
		return
	end
	local previous = currentStep
	currentStep = step
	local text = TEXTS[step]
	if text then
		if UserInputService.TouchEnabled and step == 1 then
			text = "Walk up to a kaiju on the conveyor and tap Buy!"
		end
		bannerText.Text = text
		banner.Visible = true
		banner.Size = UDim2.new(0.8, 0, 0, 58)
		TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0.92, 0, 0, 58),
		}):Play()
		if previous ~= 0 then
			Sounds.play("Good")
		end
	else
		banner.Visible = false
	end
	scanAccumulator = math.huge -- refresh the target right away
end

function Tutorial.init(screenGui: ScreenGui)
	makeBanner(screenGui)
	makeGuide()

	if player.Character then
		task.spawn(attachToCharacter, player.Character)
	end
	player.CharacterAdded:Connect(attachToCharacter)

	player:GetAttributeChangedSignal("TutorialStep"):Connect(onStepChanged)
	onStepChanged()

	RunService.Heartbeat:Connect(function(dt: number)
		scanAccumulator += dt
		if scanAccumulator < 0.3 then
			return
		end
		scanAccumulator = 0
		if currentStep >= 1 and currentStep <= 3 then
			pointAt(targetForStep())
		else
			pointAt(nil)
		end
	end)
end

return Tutorial
