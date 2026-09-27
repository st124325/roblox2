-- Russian translations for text shown on kaiju tags. Roblox auto-localizes any TextLabel whose
-- text exactly matches a Source entry, for players whose language is Russian.
-- Dynamic strings (money, "Stage M · Sell $1K") stay in English for now.
local LocalizationService = game:GetService("LocalizationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kaiju = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Kaiju"))

local Localization = {}

local RARITIES_RU = {
	Common = "Обычный",
	Rare = "Редкий",
	Epic = "Эпический",
	Legendary = "Легендарный",
	Mythic = "Мифический",
	Secret = "Секретный",
}

local RARITIES_UPPER_RU = {
	Common = "ОБЫЧНЫЙ",
	Rare = "РЕДКИЙ",
	Epic = "ЭПИЧЕСКИЙ",
	Legendary = "ЛЕГЕНДАРНЫЙ",
	Mythic = "МИФИЧЕСКИЙ",
	Secret = "СЕКРЕТНЫЙ",
}

function Localization.init()
	local tbl = Instance.new("LocalizationTable")
	tbl.Name = "GameText"
	tbl.SourceLocaleId = "en-us"

	local function add(source: string, ru: string)
		local ok, err = pcall(function()
			tbl:SetEntryValue(source, source, "", "ru", ru)
		end)
		if not ok then
			warn("[Localization] " .. source .. ": " .. tostring(err))
		end
	end

	for _, def in Kaiju.List do
		if def.NameRu then
			add(def.Name, def.NameRu)
		end
	end
	for rarity, ru in RARITIES_RU do
		add(rarity, ru)
	end
	-- Tags show the rarity in capitals ("COMMON"); string.upper can't do Cyrillic, so spelled out
	for rarity, ru in RARITIES_UPPER_RU do
		add(string.upper(rarity), ru)
	end
	tbl.Parent = LocalizationService
end

return Localization
