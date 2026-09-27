-- Server entry point. Order matters: the map must exist before bases are assigned,
-- and bases must be listening before the first profile loads.
local Server = script.Parent

local Map = require(Server.Map)
local Localization = require(Server.Localization)
local Data = require(Server.Data)
local Bases = require(Server.Bases)
local Conveyor = require(Server.Conveyor)
local Carry = require(Server.Carry)
local Tutorial = require(Server.Tutorial)
local Feedback = require(Server.Feedback)
local Shop = require(Server.Shop)

Localization.init()
require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("KaijuModel")).preload()
Map.build()
Bases.init()
Carry.init()
Conveyor.init()
Tutorial.init()
Feedback.init()
Shop.init()
Data.init()
