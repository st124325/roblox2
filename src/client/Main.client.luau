--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))

local Hud = require(script.Parent:WaitForChild("Hud"))
local Toasts = require(script.Parent:WaitForChild("Toasts"))
local FloatingText = require(script.Parent:WaitForChild("FloatingText"))

local player = Players.LocalPlayer

-- 1. Initialize UI elements
local screenGui = Hud.init(player)
Toasts.init(screenGui)

-- 2. Read and apply initial attributes
local function readAttributeNumber(name: string): number
	local val = player:GetAttribute(name)
	return if typeof(val) == "number" then val else 0
end

Hud.setMoney(readAttributeNumber("Money"))
Hud.setIncome(readAttributeNumber("Income"))
Hud.setRebirths(readAttributeNumber("Rebirths"))

-- 3. Listen to attribute updates
player:GetAttributeChangedSignal("Money"):Connect(function()
	Hud.setMoney(readAttributeNumber("Money"))
end)

player:GetAttributeChangedSignal("Income"):Connect(function()
	Hud.setIncome(readAttributeNumber("Income"))
end)

player:GetAttributeChangedSignal("Rebirths"):Connect(function()
	Hud.setRebirths(readAttributeNumber("Rebirths"))
end)

-- 4. Listen to server network events
Net.event("Notify").OnClientEvent:Connect(function(kind: any, text: any)
	local kindStr = if typeof(kind) == "string" then kind else "info"
	local textStr = if typeof(text) == "string" then text else tostring(text or "")
	Toasts.show(kindStr, textStr)
end)

Net.event("Robbed").OnClientEvent:Connect(function(thiefName: any, kaijuName: any)
	local thief = if typeof(thiefName) == "string" and thiefName ~= "" then thiefName else "A thief"
	local kaiju = if typeof(kaijuName) == "string" and kaijuName ~= "" then kaijuName else "your Kaiju"
	Toasts.showRobbedAlert(thief, kaiju)
end)

Net.event("Cash").OnClientEvent:Connect(function(amount: any, worldPosition: any)
	local amountNum = if typeof(amount) == "number" then amount else tonumber(amount) or 0
	local pos = if typeof(worldPosition) == "Vector3" then worldPosition else nil
	FloatingText.spawn(amountNum, pos)
end)

-- 5. Action Button Callbacks
local rebirthConfirmUntil = 0

Hud.onHomeClicked(function()
	Net.event("GoHome"):FireServer()
	Hud.triggerHomeCooldown(Config.HomeCooldown or 8)
end)

Hud.onRebirthClicked(function()
	local money = readAttributeNumber("Money")
	local rebirths = readAttributeNumber("Rebirths")
	local cost = Config.rebirthCost(rebirths)

	if money >= cost then
		-- Rebirth wipes every kaiju, so it takes a second click within a few seconds
		local now = os.clock()
		if now < rebirthConfirmUntil then
			rebirthConfirmUntil = 0
			Net.event("Rebirth"):FireServer()
		else
			rebirthConfirmUntil = now + 4
			Toasts.show("info", "Rebirth resets your money and kaiju. Click again to confirm!")
		end
	else
		Hud.shakeRebirthButton()
		Toasts.show("bad", "Need " .. Format.money(cost - money) .. " more to Rebirth!")
	end
end)

-- 6. Base prompts: Sell is only for the owner, Steal only for everyone else
local function filterPrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local ownerId = prompt:GetAttribute("OwnerId")
	if ownerId == nil then
		return
	end
	local isMine = ownerId == player.UserId
	if prompt.Name == "SellPrompt" then
		prompt.Enabled = isMine
	elseif prompt.Name == "Steal" then
		prompt.Enabled = not isMine
	end
end

workspace.DescendantAdded:Connect(filterPrompt)
for _, descendant in workspace:GetDescendants() do
	filterPrompt(descendant)
end
