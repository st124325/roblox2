-- Server-side gameplay signals, so systems like the tutorial, offers and analytics can react
-- to what happens without the core modules knowing about them.
local function signal(): BindableEvent
	return Instance.new("BindableEvent")
end

local Events = {
	Bought = signal(), -- (player, kaijuId) bought from the conveyor
	Collected = signal(), -- (player, amount) collected the base bank
	Locked = signal(), -- (player) pressed the lock button
	Sold = signal(), -- (player, kaijuId, amount)
	Stolen = signal(), -- (thief, victim, kaijuId) delivered a stolen kaiju
	Robbed = signal(), -- (victim, thief, kaijuId) someone grabbed the victim's kaiju
	StageUp = signal(), -- (player, slot, stageName)
	Rebirthed = signal(), -- (player, rebirths)
}

return Events
