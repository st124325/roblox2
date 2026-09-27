-- Server entry point. Order matters: the map must exist before bases are assigned,
-- and bases must be listening before the first profile loads.
local Server = script.Parent

local Map = require(Server.Map)
local Data = require(Server.Data)
local Bases = require(Server.Bases)
local Conveyor = require(Server.Conveyor)
local Carry = require(Server.Carry)

Map.build()
Bases.init()
Carry.init()
Conveyor.init()
Data.init()
