--!strict
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))

local Hud = {}

-- State variables
local currentMoney: number = 0
local displayMoney: number = 0
local currentIncome: number = 0
local currentRebirths: number = 0

local homeCooldownEndTime: number = 0
local homeCooldownTotal: number = 0
local rebirthPulsing: boolean = false

local onHomeCallback: (() -> ())?
local onRebirthCallback: (() -> ())?

-- UI references
local screenGui: ScreenGui?
local moneyLabel: TextLabel
local moneyCard: Frame
local moneyStroke: UIStroke
local activeMoneyTween: Tween?

local incomeLabel: TextLabel
local rebirthsLabel: TextLabel

local homeButton: TextButton
local homeStroke: UIStroke
local homeScale: UIScale
local homeCooldownOverlay: Frame
local homeCooldownText: TextLabel

local rebirthButton: TextButton
local rebirthStroke: UIStroke
local rebirthGradient: UIGradient
local rebirthScale: UIScale
local rebirthTitleLabel: TextLabel
local rebirthCostLabel: TextLabel
local rebirthPerkLabel: TextLabel

-- Shakes a UI element horizontally for tactile error feedback
local function shakeButton(button: any)
	task.spawn(function()
		local origPos: any = button.Position
		for _ = 1, 3 do
			button.Position = origPos + UDim2.new(0, 4, 0, 0)
			task.wait(0.035)
			button.Position = origPos - UDim2.new(0, 4, 0, 0)
			task.wait(0.035)
		end
		button.Position = origPos
	end)
end

-- Loops a gentle pulse on the Rebirth button stroke when affordable
local function pulseRebirthStroke()
	while rebirthPulsing and rebirthStroke and rebirthStroke.Parent do
		local tweenDown = TweenService:Create(
			rebirthStroke,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ Transparency = 0.65 }
		)
		tweenDown:Play()
		tweenDown.Completed:Wait()

		if not rebirthPulsing or not rebirthStroke or not rebirthStroke.Parent then
			break
		end

		local tweenUp = TweenService:Create(
			rebirthStroke,
			TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
			{ Transparency = 0.15 }
		)
		tweenUp:Play()
		tweenUp.Completed:Wait()
	end
end

-- Updates visual state of the Rebirth button based on affordability
local function updateRebirthButtonState()
	if not rebirthButton then
		return
	end

	local cost = Config.rebirthCost(currentRebirths)
	local canAfford = currentMoney >= cost

	rebirthCostLabel.Text = Format.money(cost)

	if canAfford then
		rebirthButton.BackgroundColor3 = Color3.fromRGB(75, 25, 125)
		rebirthGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(125, 45, 195)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(55, 15, 95)),
		})
		rebirthStroke.Color = Color3.fromRGB(215, 115, 255)
		rebirthStroke.Transparency = 0.25

		rebirthTitleLabel.Text = "REBIRTH 👑"
		rebirthTitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		rebirthCostLabel.TextColor3 = Color3.fromRGB(255, 230, 85)
		rebirthPerkLabel.Text = "+50% $/s & +1 Slot"
		rebirthPerkLabel.TextColor3 = Color3.fromRGB(225, 195, 255)

		if not rebirthPulsing then
			rebirthPulsing = true
			task.spawn(pulseRebirthStroke)
		end
	else
		rebirthPulsing = false
		rebirthButton.BackgroundColor3 = Color3.fromRGB(26, 28, 36)
		rebirthGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 38, 48)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 24, 30)),
		})
		rebirthStroke.Color = Color3.fromRGB(58, 62, 75)
		rebirthStroke.Transparency = 0.65

		rebirthTitleLabel.Text = "REBIRTH"
		rebirthTitleLabel.TextColor3 = Color3.fromRGB(140, 145, 160)
		rebirthCostLabel.TextColor3 = Color3.fromRGB(170, 175, 185)
		rebirthPerkLabel.Text = "Need " .. Format.money(cost - currentMoney) .. " more"
		rebirthPerkLabel.TextColor3 = Color3.fromRGB(225, 95, 95)
	end
end

-- Smooth animated counter for money changes
local function animateMoney(target: number)
	if activeMoneyTween then
		activeMoneyTween:Cancel()
		activeMoneyTween = nil
	end

	local old = displayMoney
	local diff = target - old
	if math.abs(diff) < 1 then
		displayMoney = target
		moneyLabel.Text = Format.money(target)
		return
	end

	local nv = Instance.new("NumberValue")
	nv.Value = old

	local duration = math.clamp(0.2 + math.log10(math.abs(diff) + 1) * 0.08, 0.25, 0.6)
	local tween = TweenService:Create(
		nv,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = target }
	)
	activeMoneyTween = tween

	nv.Changed:Connect(function(val)
		displayMoney = val
		moneyLabel.Text = Format.money(math.floor(val))
	end)

	tween.Completed:Connect(function()
		displayMoney = target
		moneyLabel.Text = Format.money(target)
		nv:Destroy()
		activeMoneyTween = nil
	end)

	tween:Play()

	-- Subtle tactile punch animation on money card
	if target > old then
		local strokePop = TweenService:Create(
			moneyStroke,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Color = Color3.fromRGB(120, 255, 170), Transparency = 0.1 }
		)
		strokePop:Play()
		task.delay(0.25, function()
			if moneyStroke and moneyStroke.Parent then
				TweenService:Create(
					moneyStroke,
					TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Color = Color3.fromRGB(46, 213, 115), Transparency = 0.5 }
				):Play()
			end
		end)
	end
end

-- Initialize the entire HUD hierarchy
function Hud.init(player: Player): ScreenGui
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local gui = Instance.new("ScreenGui")
	gui.Name = "MainHud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10
	gui.IgnoreGuiInset = false

	-- Responsive scale adapter
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "MobileAdaptiveScale"
	uiScale.Parent = gui

	local function updateScale()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local viewport = camera.ViewportSize
		if viewport.X <= 0 or viewport.Y <= 0 then
			return
		end

		local scaleX = viewport.X / 1150
		local scaleY = viewport.Y / 700
		local scale = math.clamp(math.min(scaleX, scaleY), 0.65, 1.25)
		uiScale.Scale = scale
	end

	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local newCam = workspace.CurrentCamera
		if newCam then
			newCam:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
			updateScale()
		end
	end)
	updateScale()

	----------------------------------------------------------------------------
	-- 1. Top Stats Bar (Money, Income, Rebirths)
	----------------------------------------------------------------------------
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.Position = UDim2.new(0.5, 0, 0, 10)
	topBar.Size = UDim2.new(0, 530, 0, 50)
	topBar.BackgroundTransparency = 1
	topBar.Parent = gui

	local topLayout = Instance.new("UIListLayout")
	topLayout.FillDirection = Enum.FillDirection.Horizontal
	topLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	topLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topLayout.Padding = UDim.new(0, 10)
	topLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topLayout.Parent = topBar

	-- A. Money Card
	moneyCard = Instance.new("Frame")
	moneyCard.Name = "MoneyCard"
	moneyCard.LayoutOrder = 1
	moneyCard.Size = UDim2.new(0, 190, 0, 48)
	moneyCard.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	moneyCard.BackgroundTransparency = 0.15
	moneyCard.BorderSizePixel = 0
	moneyCard.Parent = topBar

	local moneyCorner = Instance.new("UICorner")
	moneyCorner.CornerRadius = UDim.new(0, 12)
	moneyCorner.Parent = moneyCard

	moneyStroke = Instance.new("UIStroke")
	moneyStroke.Thickness = 1.5
	moneyStroke.Color = Color3.fromRGB(46, 213, 115)
	moneyStroke.Transparency = 0.5
	moneyStroke.Parent = moneyCard

	local moneyGradient = Instance.new("UIGradient")
	moneyGradient.Rotation = 90
	moneyGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 36, 48)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 20, 28)),
	})
	moneyGradient.Parent = moneyCard

	local moneyIcon = Instance.new("TextLabel")
	moneyIcon.Name = "Icon"
	moneyIcon.Size = UDim2.new(0, 36, 1, 0)
	moneyIcon.Position = UDim2.new(0, 8, 0, 0)
	moneyIcon.BackgroundTransparency = 1
	moneyIcon.Font = Enum.Font.GothamBold
	moneyIcon.TextSize = 22
	moneyIcon.Text = "💵"
	moneyIcon.Parent = moneyCard

	moneyLabel = Instance.new("TextLabel")
	moneyLabel.Name = "Value"
	moneyLabel.Size = UDim2.new(1, -48, 1, 0)
	moneyLabel.Position = UDim2.new(0, 44, 0, 0)
	moneyLabel.BackgroundTransparency = 1
	moneyLabel.Font = Enum.Font.GothamBlack
	moneyLabel.TextSize = 20
	moneyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	moneyLabel.TextXAlignment = Enum.TextXAlignment.Left
	moneyLabel.Text = "$0"
	moneyLabel.Parent = moneyCard

	-- B. Income Card
	local incomeCard = Instance.new("Frame")
	incomeCard.Name = "IncomeCard"
	incomeCard.LayoutOrder = 2
	incomeCard.Size = UDim2.new(0, 150, 0, 48)
	incomeCard.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	incomeCard.BackgroundTransparency = 0.15
	incomeCard.BorderSizePixel = 0
	incomeCard.Parent = topBar

	local incomeCorner = Instance.new("UICorner")
	incomeCorner.CornerRadius = UDim.new(0, 12)
	incomeCorner.Parent = incomeCard

	local incomeStroke = Instance.new("UIStroke")
	incomeStroke.Thickness = 1.5
	incomeStroke.Color = Color3.fromRGB(54, 162, 235)
	incomeStroke.Transparency = 0.5
	incomeStroke.Parent = incomeCard

	local incomeGradient = Instance.new("UIGradient")
	incomeGradient.Rotation = 90
	incomeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 36, 52)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 20, 28)),
	})
	incomeGradient.Parent = incomeCard

	local incomeIcon = Instance.new("TextLabel")
	incomeIcon.Name = "Icon"
	incomeIcon.Size = UDim2.new(0, 32, 1, 0)
	incomeIcon.Position = UDim2.new(0, 8, 0, 0)
	incomeIcon.BackgroundTransparency = 1
	incomeIcon.Font = Enum.Font.GothamBold
	incomeIcon.TextSize = 20
	incomeIcon.Text = "⚡"
	incomeIcon.Parent = incomeCard

	incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "Value"
	incomeLabel.Size = UDim2.new(1, -44, 1, 0)
	incomeLabel.Position = UDim2.new(0, 40, 0, 0)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Font = Enum.Font.GothamBold
	incomeLabel.TextSize = 16
	incomeLabel.TextColor3 = Color3.fromRGB(110, 210, 255)
	incomeLabel.TextXAlignment = Enum.TextXAlignment.Left
	incomeLabel.Text = "+$0/s"
	incomeLabel.Parent = incomeCard

	-- C. Rebirths Card
	local rebirthsCard = Instance.new("Frame")
	rebirthsCard.Name = "RebirthsCard"
	rebirthsCard.LayoutOrder = 3
	rebirthsCard.Size = UDim2.new(0, 150, 0, 48)
	rebirthsCard.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	rebirthsCard.BackgroundTransparency = 0.15
	rebirthsCard.BorderSizePixel = 0
	rebirthsCard.Parent = topBar

	local rebirthsCorner = Instance.new("UICorner")
	rebirthsCorner.CornerRadius = UDim.new(0, 12)
	rebirthsCorner.Parent = rebirthsCard

	local rebirthsStroke = Instance.new("UIStroke")
	rebirthsStroke.Thickness = 1.5
	rebirthsStroke.Color = Color3.fromRGB(165, 94, 234)
	rebirthsStroke.Transparency = 0.5
	rebirthsStroke.Parent = rebirthsCard

	local rebirthsGradient = Instance.new("UIGradient")
	rebirthsGradient.Rotation = 90
	rebirthsGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 26, 52)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 20, 28)),
	})
	rebirthsGradient.Parent = rebirthsCard

	local rebirthsIcon = Instance.new("TextLabel")
	rebirthsIcon.Name = "Icon"
	rebirthsIcon.Size = UDim2.new(0, 32, 1, 0)
	rebirthsIcon.Position = UDim2.new(0, 8, 0, 0)
	rebirthsIcon.BackgroundTransparency = 1
	rebirthsIcon.Font = Enum.Font.GothamBold
	rebirthsIcon.TextSize = 20
	rebirthsIcon.Text = "👑"
	rebirthsIcon.Parent = rebirthsCard

	rebirthsLabel = Instance.new("TextLabel")
	rebirthsLabel.Name = "Value"
	rebirthsLabel.Size = UDim2.new(1, -44, 1, 0)
	rebirthsLabel.Position = UDim2.new(0, 40, 0, 0)
	rebirthsLabel.BackgroundTransparency = 1
	rebirthsLabel.Font = Enum.Font.GothamBold
	rebirthsLabel.TextSize = 15
	rebirthsLabel.TextColor3 = Color3.fromRGB(220, 175, 255)
	rebirthsLabel.TextXAlignment = Enum.TextXAlignment.Left
	rebirthsLabel.Text = "0 Rebirths"
	rebirthsLabel.Parent = rebirthsCard

	----------------------------------------------------------------------------
	-- 2. Action Buttons (Left Side: Home & Rebirth)
	----------------------------------------------------------------------------
	local actionContainer = Instance.new("Frame")
	actionContainer.Name = "ActionContainer"
	actionContainer.AnchorPoint = Vector2.new(0, 0.5)
	actionContainer.Position = UDim2.new(0, 20, 0.5, 0)
	actionContainer.Size = UDim2.new(0, 160, 0, 150)
	actionContainer.BackgroundTransparency = 1
	actionContainer.Parent = gui

	local actionLayout = Instance.new("UIListLayout")
	actionLayout.FillDirection = Enum.FillDirection.Vertical
	actionLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	actionLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionLayout.Padding = UDim.new(0, 12)
	actionLayout.SortOrder = Enum.SortOrder.LayoutOrder
	actionLayout.Parent = actionContainer

	-- A. Home Button
	homeButton = Instance.new("TextButton")
	homeButton.Name = "HomeButton"
	homeButton.LayoutOrder = 1
	homeButton.Size = UDim2.new(1, 0, 0, 60)
	homeButton.BackgroundColor3 = Color3.fromRGB(25, 32, 46)
	homeButton.AutoButtonColor = false
	homeButton.Text = ""
	homeButton.ClipsDescendants = true
	homeButton.Parent = actionContainer

	local homeCorner = Instance.new("UICorner")
	homeCorner.CornerRadius = UDim.new(0, 12)
	homeCorner.Parent = homeButton

	homeStroke = Instance.new("UIStroke")
	homeStroke.Thickness = 1.5
	homeStroke.Color = Color3.fromRGB(60, 150, 240)
	homeStroke.Transparency = 0.4
	homeStroke.Parent = homeButton

	local homeGradient = Instance.new("UIGradient")
	homeGradient.Rotation = 45
	homeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(35, 60, 95)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 26, 42)),
	})
	homeGradient.Parent = homeButton

	homeScale = Instance.new("UIScale")
	homeScale.Scale = 1.0
	homeScale.Parent = homeButton

	local homeIcon = Instance.new("TextLabel")
	homeIcon.Name = "Icon"
	homeIcon.Size = UDim2.new(0, 36, 1, 0)
	homeIcon.Position = UDim2.new(0, 8, 0, 0)
	homeIcon.BackgroundTransparency = 1
	homeIcon.Font = Enum.Font.GothamBold
	homeIcon.TextSize = 22
	homeIcon.Text = "🏠"
	homeIcon.Parent = homeButton

	local homeTitle = Instance.new("TextLabel")
	homeTitle.Name = "Title"
	homeTitle.Size = UDim2.new(1, -48, 0, 24)
	homeTitle.Position = UDim2.new(0, 44, 0, 8)
	homeTitle.BackgroundTransparency = 1
	homeTitle.Font = Enum.Font.GothamBlack
	homeTitle.TextSize = 16
	homeTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	homeTitle.TextXAlignment = Enum.TextXAlignment.Left
	homeTitle.Text = "HOME"
	homeTitle.Parent = homeButton

	local homeSubtitle = Instance.new("TextLabel")
	homeSubtitle.Name = "Subtitle"
	homeSubtitle.Size = UDim2.new(1, -48, 0, 18)
	homeSubtitle.Position = UDim2.new(0, 44, 0, 32)
	homeSubtitle.BackgroundTransparency = 1
	homeSubtitle.Font = Enum.Font.GothamMedium
	homeSubtitle.TextSize = 11
	homeSubtitle.TextColor3 = Color3.fromRGB(170, 205, 240)
	homeSubtitle.TextXAlignment = Enum.TextXAlignment.Left
	homeSubtitle.Text = "Teleport to Base"
	homeSubtitle.Parent = homeButton

	-- Visual Cooldown Overlay for Home Button
	homeCooldownOverlay = Instance.new("Frame")
	homeCooldownOverlay.Name = "CooldownOverlay"
	homeCooldownOverlay.Size = UDim2.new(1, 0, 0, 0)
	homeCooldownOverlay.Position = UDim2.new(0, 0, 1, 0)
	homeCooldownOverlay.AnchorPoint = Vector2.new(0, 1)
	homeCooldownOverlay.BackgroundColor3 = Color3.fromRGB(10, 12, 18)
	homeCooldownOverlay.BackgroundTransparency = 0.35
	homeCooldownOverlay.BorderSizePixel = 0
	homeCooldownOverlay.Visible = false
	homeCooldownOverlay.ZIndex = 5
	homeCooldownOverlay.Parent = homeButton

	local cdCorner = Instance.new("UICorner")
	cdCorner.CornerRadius = UDim.new(0, 12)
	cdCorner.Parent = homeCooldownOverlay

	homeCooldownText = Instance.new("TextLabel")
	homeCooldownText.Name = "TimerText"
	homeCooldownText.Size = UDim2.new(1, 0, 1, 0)
	homeCooldownText.BackgroundTransparency = 1
	homeCooldownText.Font = Enum.Font.GothamBlack
	homeCooldownText.TextSize = 17
	homeCooldownText.TextColor3 = Color3.fromRGB(255, 220, 100)
	homeCooldownText.Text = ""
	homeCooldownText.ZIndex = 6
	homeCooldownText.Parent = homeButton

	-- Home Button Interaction Tweens
	homeButton.MouseEnter:Connect(function()
		if os.clock() >= homeCooldownEndTime then
			TweenService:Create(homeScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1.04,
			}):Play()
		end
	end)
	homeButton.MouseLeave:Connect(function()
		TweenService:Create(homeScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.0,
		}):Play()
	end)
	homeButton.MouseButton1Down:Connect(function()
		if os.clock() >= homeCooldownEndTime then
			TweenService:Create(homeScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 0.96,
			}):Play()
		end
	end)
	homeButton.MouseButton1Up:Connect(function()
		TweenService:Create(homeScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.0,
		}):Play()
	end)
	homeButton.Activated:Connect(function()
		if os.clock() < homeCooldownEndTime then
			shakeButton(homeButton)
			return
		end
		if onHomeCallback then
			onHomeCallback()
		end
	end)

	-- B. Rebirth Button
	rebirthButton = Instance.new("TextButton")
	rebirthButton.Name = "RebirthButton"
	rebirthButton.LayoutOrder = 2
	rebirthButton.Size = UDim2.new(1, 0, 0, 72)
	rebirthButton.BackgroundColor3 = Color3.fromRGB(26, 28, 36)
	rebirthButton.AutoButtonColor = false
	rebirthButton.Text = ""
	rebirthButton.ClipsDescendants = true
	rebirthButton.Parent = actionContainer

	local rebCorner = Instance.new("UICorner")
	rebCorner.CornerRadius = UDim.new(0, 12)
	rebCorner.Parent = rebirthButton

	rebirthStroke = Instance.new("UIStroke")
	rebirthStroke.Thickness = 2.0
	rebirthStroke.Color = Color3.fromRGB(58, 62, 75)
	rebirthStroke.Transparency = 0.65
	rebirthStroke.Parent = rebirthButton

	rebirthGradient = Instance.new("UIGradient")
	rebirthGradient.Rotation = 45
	rebirthGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(36, 38, 48)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 24, 30)),
	})
	rebirthGradient.Parent = rebirthButton

	rebirthScale = Instance.new("UIScale")
	rebirthScale.Scale = 1.0
	rebirthScale.Parent = rebirthButton

	rebirthTitleLabel = Instance.new("TextLabel")
	rebirthTitleLabel.Name = "Title"
	rebirthTitleLabel.Size = UDim2.new(1, -16, 0, 20)
	rebirthTitleLabel.Position = UDim2.new(0, 10, 0, 7)
	rebirthTitleLabel.BackgroundTransparency = 1
	rebirthTitleLabel.Font = Enum.Font.GothamBlack
	rebirthTitleLabel.TextSize = 14
	rebirthTitleLabel.TextColor3 = Color3.fromRGB(140, 145, 160)
	rebirthTitleLabel.TextXAlignment = Enum.TextXAlignment.Left
	rebirthTitleLabel.Text = "REBIRTH"
	rebirthTitleLabel.Parent = rebirthButton

	rebirthCostLabel = Instance.new("TextLabel")
	rebirthCostLabel.Name = "Cost"
	rebirthCostLabel.Size = UDim2.new(1, -16, 0, 22)
	rebirthCostLabel.Position = UDim2.new(0, 10, 0, 27)
	rebirthCostLabel.BackgroundTransparency = 1
	rebirthCostLabel.Font = Enum.Font.GothamBlack
	rebirthCostLabel.TextSize = 16
	rebirthCostLabel.TextColor3 = Color3.fromRGB(170, 175, 185)
	rebirthCostLabel.TextXAlignment = Enum.TextXAlignment.Left
	rebirthCostLabel.Text = "$1.0M"
	rebirthCostLabel.Parent = rebirthButton

	rebirthPerkLabel = Instance.new("TextLabel")
	rebirthPerkLabel.Name = "Perk"
	rebirthPerkLabel.Size = UDim2.new(1, -16, 0, 16)
	rebirthPerkLabel.Position = UDim2.new(0, 10, 0, 49)
	rebirthPerkLabel.BackgroundTransparency = 1
	rebirthPerkLabel.Font = Enum.Font.GothamMedium
	rebirthPerkLabel.TextSize = 10
	rebirthPerkLabel.TextColor3 = Color3.fromRGB(225, 95, 95)
	rebirthPerkLabel.TextXAlignment = Enum.TextXAlignment.Left
	rebirthPerkLabel.Text = "Need $1.0M more"
	rebirthPerkLabel.Parent = rebirthButton

	-- Rebirth Button Interaction Tweens
	rebirthButton.MouseEnter:Connect(function()
		local cost = Config.rebirthCost(currentRebirths)
		if currentMoney >= cost then
			TweenService:Create(rebirthScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 1.04,
			}):Play()
		end
	end)
	rebirthButton.MouseLeave:Connect(function()
		TweenService:Create(rebirthScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.0,
		}):Play()
	end)
	rebirthButton.MouseButton1Down:Connect(function()
		local cost = Config.rebirthCost(currentRebirths)
		if currentMoney >= cost then
			TweenService:Create(rebirthScale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Scale = 0.96,
			}):Play()
		end
	end)
	rebirthButton.MouseButton1Up:Connect(function()
		TweenService:Create(rebirthScale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.0,
		}):Play()
	end)
	rebirthButton.Activated:Connect(function()
		if onRebirthCallback then
			onRebirthCallback()
		end
	end)

	gui.Parent = playerGui
	screenGui = gui

	updateRebirthButtonState()

	return gui
end

function Hud.setMoney(amount: number)
	currentMoney = amount
	animateMoney(amount)
	updateRebirthButtonState()
end

function Hud.setIncome(amount: number)
	currentIncome = amount
	if incomeLabel then
		incomeLabel.Text = "+" .. Format.rate(amount)
	end
end

function Hud.setRebirths(amount: number)
	currentRebirths = amount
	if rebirthsLabel then
		rebirthsLabel.Text = amount .. " Rebirth" .. (if amount == 1 then "" else "s")
	end
	updateRebirthButtonState()
end

function Hud.getMoney(): number
	return currentMoney
end

function Hud.getIncome(): number
	return currentIncome
end

function Hud.getRebirths(): number
	return currentRebirths
end

function Hud.onHomeClicked(callback: () -> ())
	onHomeCallback = callback
end

function Hud.onRebirthClicked(callback: () -> ())
	onRebirthCallback = callback
end

function Hud.triggerHomeCooldown(duration: number)
	homeCooldownTotal = duration
	homeCooldownEndTime = os.clock() + duration
	homeCooldownOverlay.Visible = true

	task.spawn(function()
		while os.clock() < homeCooldownEndTime do
			local remaining = math.max(0, homeCooldownEndTime - os.clock())
			local ratio = remaining / homeCooldownTotal
			homeCooldownOverlay.Size = UDim2.new(1, 0, ratio, 0)
			homeCooldownText.Text = string.format("%.1fs", remaining)
			task.wait(0.05)
		end

		homeCooldownOverlay.Visible = false
		homeCooldownText.Text = ""

		-- Ready highlight flash
		if homeStroke and homeStroke.Parent then
			local flash = TweenService:Create(
				homeStroke,
				TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Color = Color3.fromRGB(120, 220, 255), Transparency = 0.1 }
			)
			flash:Play()
			flash.Completed:Connect(function()
				if homeStroke and homeStroke.Parent then
					TweenService:Create(
						homeStroke,
						TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
						{ Color = Color3.fromRGB(60, 150, 240), Transparency = 0.4 }
					):Play()
				end
			end)
		end
	end)
end

function Hud.shakeRebirthButton()
	if rebirthButton then
		shakeButton(rebirthButton)
	end
end

function Hud.getScreenGui(): ScreenGui?
	return screenGui
end

return Hud
