--!strict
local TweenService = game:GetService("TweenService")

local Toasts = {}

local toastContainer: Frame?
local activeToasts: { Frame } = {}
local screenGuiRef: ScreenGui?

-- Color schemes for each kind
local KIND_COLORS = {
	good = {
		accent = Color3.fromRGB(46, 213, 115),
		stroke = Color3.fromRGB(46, 213, 115),
		icon = "✅",
	},
	bad = {
		accent = Color3.fromRGB(255, 71, 87),
		stroke = Color3.fromRGB(255, 71, 87),
		icon = "⚠️",
	},
	info = {
		accent = Color3.fromRGB(54, 162, 235),
		stroke = Color3.fromRGB(54, 162, 235),
		icon = "ℹ️",
	},
}

function Toasts.init(parentGui: ScreenGui)
	screenGuiRef = parentGui

	local container = Instance.new("Frame")
	container.Name = "ToastContainer"
	container.AnchorPoint = Vector2.new(1, 0)
	container.Position = UDim2.new(1, -20, 0, 70)
	container.Size = UDim2.new(0, 320, 0.7, 0)
	container.BackgroundTransparency = 1
	container.ClipsDescendants = false
	container.Parent = parentGui

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Vertical
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = container

	toastContainer = container
end

-- Dismiss an active toast card with animation
local function dismissToast(toast: Frame)
	local idx = table.find(activeToasts, toast)
	if idx then
		table.remove(activeToasts, idx)
	end

	if not toast.Parent then
		return
	end

	local slideOut = TweenService:Create(
		toast,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{
			Position = UDim2.new(1, 40, 0, 0),
			BackgroundTransparency = 1,
		}
	)

	-- Fade children
	for _, child in toast:GetDescendants() do
		if child:IsA("TextLabel") then
			TweenService:Create(child, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				TextTransparency = 1,
				TextStrokeTransparency = 1,
			}):Play()
		elseif child:IsA("UIStroke") then
			TweenService:Create(child, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 1,
			}):Play()
		elseif child:IsA("Frame") then
			TweenService:Create(child, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			}):Play()
		end
	end

	slideOut:Play()
	slideOut.Completed:Connect(function()
		toast:Destroy()
	end)
end

-- Show a modern toast notification
function Toasts.show(kind: string, text: string)
	if not toastContainer then
		return
	end

	-- Enforce maximum of 4 concurrent toasts
	if #activeToasts >= 4 then
		local oldest = activeToasts[1]
		if oldest then
			dismissToast(oldest)
		end
	end

	local theme = KIND_COLORS[kind] or KIND_COLORS.info

	local toast = Instance.new("Frame")
	toast.Name = "ToastCard"
	toast.Size = UDim2.new(1, 0, 0, 56)
	toast.Position = UDim2.new(1, 50, 0, 0)
	toast.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	toast.BackgroundTransparency = 0.15
	toast.BorderSizePixel = 0
	toast.ClipsDescendants = true

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = toast

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = theme.stroke
	stroke.Transparency = 0.35
	stroke.Parent = toast

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 45
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(26, 32, 46)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(16, 20, 28)),
	})
	gradient.Parent = toast

	-- Left accent indicator bar
	local accentBar = Instance.new("Frame")
	accentBar.Name = "AccentBar"
	accentBar.Size = UDim2.new(0, 4, 1, 0)
	accentBar.Position = UDim2.new(0, 0, 0, 0)
	accentBar.BackgroundColor3 = theme.accent
	accentBar.BorderSizePixel = 0
	accentBar.Parent = toast

	local accentCorner = Instance.new("UICorner")
	accentCorner.CornerRadius = UDim.new(0, 4)
	accentCorner.Parent = accentBar

	-- Icon
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Name = "Icon"
	iconLabel.Size = UDim2.new(0, 36, 1, 0)
	iconLabel.Position = UDim2.new(0, 6, 0, 0)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextSize = 20
	iconLabel.Text = theme.icon
	iconLabel.Parent = toast

	-- Message
	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Message"
	textLabel.Size = UDim2.new(1, -50, 1, -8)
	textLabel.Position = UDim2.new(0, 44, 0, 4)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.GothamMedium
	textLabel.TextSize = 13
	textLabel.TextColor3 = Color3.fromRGB(242, 245, 252)
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.TextYAlignment = Enum.TextYAlignment.Center
	textLabel.TextWrapped = true
	textLabel.Text = text
	textLabel.Parent = toast

	toast.Parent = toastContainer
	table.insert(activeToasts, toast)

	-- Slide in animation
	local slideIn = TweenService:Create(
		toast,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, 0, 0, 0) }
	)
	slideIn:Play()

	-- Auto-dismiss after 3.8 seconds
	task.delay(3.8, function()
		if toast.Parent then
			dismissToast(toast)
		end
	end)
end

-- Big Red Alert on Robbed: Screen pulse vignette + prominent warning banner
function Toasts.showRobbedAlert(thiefName: string, kaijuName: string)
	if not screenGuiRef then
		return
	end

	-- 1. Full-screen Red Vignette Pulse
	local vignette = Instance.new("Frame")
	vignette.Name = "RobbedVignette"
	vignette.Size = UDim2.new(1, 0, 1, 0)
	vignette.Position = UDim2.new(0, 0, 0, 0)
	vignette.BackgroundColor3 = Color3.fromRGB(220, 20, 30)
	vignette.BackgroundTransparency = 1
	vignette.ZIndex = 40
	vignette.Parent = screenGuiRef

	task.spawn(function()
		-- Pulse 1
		local p1 = TweenService:Create(
			vignette,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0.72 }
		)
		p1:Play()
		p1.Completed:Wait()

		local p2 = TweenService:Create(
			vignette,
			TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		)
		p2:Play()
		p2.Completed:Wait()

		-- Pulse 2
		local p3 = TweenService:Create(
			vignette,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 0.78 }
		)
		p3:Play()
		p3.Completed:Wait()

		local p4 = TweenService:Create(
			vignette,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		)
		p4:Play()
		p4.Completed:Wait()

		vignette:Destroy()
	end)

	-- 2. Big Red Emergency Banner
	local banner = Instance.new("Frame")
	banner.Name = "RobbedBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 75)
	banner.Size = UDim2.new(0, 480, 0, 96)
	banner.BackgroundColor3 = Color3.fromRGB(35, 12, 18)
	banner.BackgroundTransparency = 0.05
	banner.BorderSizePixel = 0
	banner.ZIndex = 50

	local bannerCorner = Instance.new("UICorner")
	bannerCorner.CornerRadius = UDim.new(0, 14)
	bannerCorner.Parent = banner

	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Thickness = 2.5
	bannerStroke.Color = Color3.fromRGB(255, 55, 70)
	bannerStroke.Transparency = 0.1
	bannerStroke.Parent = banner

	local bannerGradient = Instance.new("UIGradient")
	bannerGradient.Rotation = 90
	bannerGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 20, 32)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 10, 16)),
	})
	bannerGradient.Parent = banner

	local bannerScale = Instance.new("UIScale")
	bannerScale.Scale = 0.3
	bannerScale.Parent = banner

	-- Title Header
	local headerLabel = Instance.new("TextLabel")
	headerLabel.Name = "Header"
	headerLabel.Size = UDim2.new(1, 0, 0, 30)
	headerLabel.Position = UDim2.new(0, 0, 0, 8)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Font = Enum.Font.GothamBlack
	headerLabel.TextSize = 21
	headerLabel.TextColor3 = Color3.fromRGB(255, 225, 80)
	headerLabel.Text = "🚨 KAIJU STOLEN! 🚨"
	headerLabel.Parent = banner

	-- Detail Message
	local detailLabel = Instance.new("TextLabel")
	detailLabel.Name = "Detail"
	detailLabel.Size = UDim2.new(1, -24, 0, 26)
	detailLabel.Position = UDim2.new(0, 12, 0, 38)
	detailLabel.BackgroundTransparency = 1
	detailLabel.Font = Enum.Font.GothamBold
	detailLabel.TextSize = 15
	detailLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	detailLabel.RichText = true
	detailLabel.Text = `<font color="#FFEAA7"><b>{thiefName}</b></font> stole your <font color="#FF7675"><b>{kaijuName}</b></font>!`
	detailLabel.Parent = banner

	-- Action Hint
	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.Size = UDim2.new(1, -24, 0, 22)
	hintLabel.Position = UDim2.new(0, 12, 0, 64)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.GothamMedium
	hintLabel.TextSize = 12
	hintLabel.TextColor3 = Color3.fromRGB(255, 200, 200)
	hintLabel.Text = "Equip your Bonk Bat and hit them before they deliver it!"
	hintLabel.Parent = banner

	banner.Parent = screenGuiRef

	-- Bounce entrance animation
	local bounceTween = TweenService:Create(
		bannerScale,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1.0 }
	)
	bounceTween:Play()

	-- Gentle shake effect
	task.spawn(function()
		local basePos = banner.Position
		for _ = 1, 3 do
			banner.Position = basePos + UDim2.new(0, 5, 0, 0)
			task.wait(0.04)
			banner.Position = basePos - UDim2.new(0, 5, 0, 0)
			task.wait(0.04)
		end
		banner.Position = basePos
	end)

	-- Pulsing stroke loop
	local isAlive = true
	task.spawn(function()
		while isAlive and banner.Parent do
			local pulseDown = TweenService:Create(
				bannerStroke,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ Transparency = 0.6 }
			)
			pulseDown:Play()
			pulseDown.Completed:Wait()

			if not isAlive or not banner.Parent then
				break
			end

			local pulseUp = TweenService:Create(
				bannerStroke,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
				{ Transparency = 0.1 }
			)
			pulseUp:Play()
			pulseUp.Completed:Wait()
		end
	end)

	-- Stay visible for 5.0 seconds, then exit smoothly
	task.delay(5.0, function()
		isAlive = false
		if not banner.Parent then
			return
		end

		local exitTween = TweenService:Create(
			banner,
			TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{
				Position = UDim2.new(0.5, 0, 0, 30),
				BackgroundTransparency = 1,
			}
		)

		for _, child in banner:GetDescendants() do
			if child:IsA("TextLabel") then
				TweenService:Create(child, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					TextTransparency = 1,
				}):Play()
			elseif child:IsA("UIStroke") then
				TweenService:Create(child, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					Transparency = 1,
				}):Play()
			end
		end

		exitTween:Play()
		exitTween.Completed:Connect(function()
			banner:Destroy()
		end)
	end)
end

return Toasts
