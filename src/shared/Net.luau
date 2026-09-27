-- Every remote the game uses. The server creates them; clients wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"Notify", -- S->C  kind ("info" | "good" | "bad"), text
	"GoHome", -- C->S  teleport to own base
	"Rebirth", -- C->S  request a rebirth
	"Robbed", -- S->C  thiefName, kaijuName (someone grabbed your kaiju)
	"Cash", -- S->C  amount, worldPosition (floating "+$" text)
	"Buy", -- C->S  kind ("Pass" | "Item"), key
	"Gift", -- C->S  passKey, targetUserId
	"Offer", -- S->C  itemKey, reasonText (contextual purchase suggestion)
	"Announce", -- S->C  text (server-wide banner, e.g. a Cash Rain)
	"WatchAd", -- C->S  adRewardKey
	"AdResult", -- S->C  adRewardKey, ok, message
}
local FUNCTIONS = {}

local Net = {}
local folder: Folder

if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
