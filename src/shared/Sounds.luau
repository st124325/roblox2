-- All sounds in one place. rbxasset:// sounds ship with the Roblox client; the numeric ids are
-- public ProSoundEffects audio (Roblox's licensed SFX partner), already verified in STEEL FRONT.
-- Replace any Id with your own "rbxassetid://<number>" to change a sound.
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Sounds = {}

Sounds.List = table.freeze({
	Cash = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.45, Pitch = 1.6 },
	Buy = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.55, Pitch = 1.15 },
	Good = { Id = "rbxasset://sounds/button.wav", Volume = 0.35, Pitch = 1.3 },
	Bad = { Id = "rbxasset://sounds/button.wav", Volume = 0.4, Pitch = 0.65 },
	Click = { Id = "rbxasset://sounds/button.wav", Volume = 0.35 },
	StageUp = { Id = "rbxasset://sounds/victory.wav", Volume = 0.5, Pitch = 1.25 },
	Rebirth = { Id = "rbxasset://sounds/victory.wav", Volume = 0.7, Pitch = 0.9 },
	Alarm = { Id = "rbxassetid://9113042060", Volume = 0.8, Pitch = 1.3 },
	Bonk = { Id = "rbxassetid://9113502506", Volume = 0.7, Pitch = 1.2 },
	Whoosh = { Id = "rbxassetid://9113634642", Volume = 0.5, Pitch = 0.8 },
	Boom = { Id = "rbxasset://sounds/impact_explosion_03.mp3", Volume = 0.6, Pitch = 1.1 },
})

local function make(name: string): Sound?
	local def = Sounds.List[name]
	if not def then
		warn("[Sounds] unknown sound " .. tostring(name))
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.Id
	sound.Volume = def.Volume or 0.5
	sound.PlaybackSpeed = def.Pitch or 1
	return sound
end

-- Play a sound in the world at `part` (audible to everyone nearby when called on the server).
function Sounds.playAt(part: Instance, name: string)
	local sound = make(name)
	if not sound then
		return
	end
	sound.RollOffMaxDistance = 120
	sound.Parent = part
	sound:Play()
	Debris:AddItem(sound, 6)
end

-- Client only: play a non-positional UI sound for the local player.
function Sounds.play(name: string)
	local sound = make(name)
	if not sound then
		return
	end
	sound.Parent = SoundService
	sound:Play()
	Debris:AddItem(sound, 6)
end

return Sounds
