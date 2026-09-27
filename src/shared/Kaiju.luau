--!strict
-- Kaiju catalog, definitions, rolling, and income calculation.

local Config = require(script.Parent.Config)

export type KaijuDef = {
	Id: string,
	Name: string, -- English (source language)
	NameRu: string?, -- Russian, served through the LocalizationTable
	Rarity: string,
	Price: number,
	Income: number,
	Body: Color3,
	Accent: Color3,
	Shape: string, -- "Dino" | "Blob" | "Crab" | "Bird" | "Tall"
}

export type SlotEntry = {
	Id: string,
	Growth: number,
	Mutation: string?,
}

local Kaiju = {}

Kaiju.Rarities = {
	"Common",
	"Rare",
	"Epic",
	"Legendary",
	"Mythic",
	"Secret",
}

Kaiju.RarityColor = {
	Common = Color3.fromRGB(190, 195, 205),
	Rare = Color3.fromRGB(35, 155, 255),
	Epic = Color3.fromRGB(165, 55, 255),
	Legendary = Color3.fromRGB(255, 175, 15),
	Mythic = Color3.fromRGB(255, 45, 85),
	Secret = Color3.fromRGB(0, 255, 200),
}

-- Catalog of 27 Kaijus across all 6 rarities and 5 shapes.
-- Payback time (Price / Income at stage S): Common 20-31s, Rare 1-2 min, Epic 4-10 min,
-- Legendary 20-40 min, Mythic 1-2 h, Secret 4-5 h. Simulated: first Legendary ~1 h, first Secret ~8-20 h.
Kaiju.List = {
	-- =========================================================================
	-- COMMON (Price: $15 - $500, Payback: 20s - 31s)
	-- =========================================================================
	{
		Id = "toastosaurus",
		Name = "Toastosaurus",
		NameRu = "Тостозавр",
		Rarity = "Common",
		Price = 15,
		Income = 0.75,
		Body = Color3.fromRGB(222, 184, 135),
		Accent = Color3.fromRGB(139, 69, 19),
		Shape = "Dino",
	},
	{
		Id = "mudpup",
		Name = "Mudpup",
		NameRu = "Грязепупс",
		Rarity = "Common",
		Price = 40,
		Income = 1.8,
		Body = Color3.fromRGB(150, 110, 80),
		Accent = Color3.fromRGB(90, 60, 40),
		Shape = "Blob",
	},
	{
		Id = "craboid",
		Name = "Craboid",
		NameRu = "Крабоид",
		Rarity = "Common",
		Price = 100,
		Income = 4,
		Body = Color3.fromRGB(230, 100, 70),
		Accent = Color3.fromRGB(255, 160, 120),
		Shape = "Crab",
	},
	{
		Id = "chirik",
		Name = "Chirpy",
		NameRu = "Чирик",
		Rarity = "Common",
		Price = 220,
		Income = 8,
		Body = Color3.fromRGB(140, 200, 120),
		Accent = Color3.fromRGB(255, 200, 50),
		Shape = "Bird",
	},
	{
		Id = "nosatik",
		Name = "Nosey",
		NameRu = "Носатик",
		Rarity = "Common",
		Price = 500,
		Income = 16,
		Body = Color3.fromRGB(160, 175, 190),
		Accent = Color3.fromRGB(240, 120, 80),
		Shape = "Tall",
	},

	-- =========================================================================
	-- RARE (Price: $2,000 - $77,000, Payback: 60s - 120s)
	-- =========================================================================
	{
		Id = "cactusaur",
		Name = "Cactusaur",
		NameRu = "Кактусозавр",
		Rarity = "Rare",
		Price = 2000,
		Income = 33,
		Body = Color3.fromRGB(60, 160, 75),
		Accent = Color3.fromRGB(255, 90, 140),
		Shape = "Dino",
	},
	{
		Id = "bubblegum_goblin",
		Name = "Bubblegum Goblin",
		NameRu = "Гоблин-Бубльгум",
		Rarity = "Rare",
		Price = 5600,
		Income = 75,
		Body = Color3.fromRGB(255, 105, 180),
		Accent = Color3.fromRGB(100, 240, 255),
		Shape = "Blob",
	},
	{
		Id = "crabburger",
		Name = "Crabburger",
		NameRu = "Крабобургер",
		Rarity = "Rare",
		Price = 15000,
		Income = 165,
		Body = Color3.fromRGB(210, 140, 60),
		Accent = Color3.fromRGB(220, 50, 40),
		Shape = "Crab",
	},
	{
		Id = "pigeon_bomber",
		Name = "Pigeon Bomber",
		NameRu = "Голубь-Бомбардир",
		Rarity = "Rare",
		Price = 34000,
		Income = 320,
		Body = Color3.fromRGB(130, 140, 155),
		Accent = Color3.fromRGB(60, 180, 160),
		Shape = "Bird",
	},
	{
		Id = "giraffecrane",
		Name = "Giraffe Crane",
		NameRu = "Жирафокран",
		Rarity = "Rare",
		Price = 77000,
		Income = 640,
		Body = Color3.fromRGB(245, 190, 40),
		Accent = Color3.fromRGB(50, 50, 50),
		Shape = "Tall",
	},

	-- =========================================================================
	-- EPIC (Price: $312K - $11.4M, Payback: 4 - 10 min)
	-- =========================================================================
	{
		Id = "pelmenisaur",
		Name = "Dumplingsaur",
		NameRu = "Пельменозавр",
		Rarity = "Epic",
		Price = 312000,
		Income = 1300,
		Body = Color3.fromRGB(245, 240, 225),
		Accent = Color3.fromRGB(90, 140, 70),
		Shape = "Dino",
	},
	{
		Id = "slime_shlepa",
		Name = "Slime Floppa",
		NameRu = "Слайм-Шлёпа",
		Rarity = "Epic",
		Price = 780000,
		Income = 2600,
		Body = Color3.fromRGB(215, 155, 95),
		Accent = Color3.fromRGB(25, 25, 30),
		Shape = "Blob",
	},
	{
		Id = "boxer_crab",
		Name = "Boxer Crab",
		NameRu = "Краб-Боксёр",
		Rarity = "Epic",
		Price = 2050000,
		Income = 5400,
		Body = Color3.fromRGB(235, 70, 50),
		Accent = Color3.fromRGB(250, 230, 60),
		Shape = "Crab",
	},
	{
		Id = "interceptor_seagull",
		Name = "Interceptor Seagull",
		NameRu = "Чайка-Перехватчик",
		Rarity = "Epic",
		Price = 5000000,
		Income = 10500,
		Body = Color3.fromRGB(235, 240, 245),
		Accent = Color3.fromRGB(40, 45, 60),
		Shape = "Bird",
	},
	{
		Id = "bananosaur",
		Name = "Bananasaur",
		NameRu = "Бананозавр",
		Rarity = "Epic",
		Price = 11400000,
		Income = 19000,
		Body = Color3.fromRGB(255, 225, 50),
		Accent = Color3.fromRGB(90, 60, 30),
		Shape = "Tall",
	},

	-- =========================================================================
	-- LEGENDARY (Price: $41M - $336M, Payback: 20 - 40 min)
	-- =========================================================================
	{
		Id = "catzilla",
		Name = "Catzilla",
		NameRu = "Котзилла",
		Rarity = "Legendary",
		Price = 41000000,
		Income = 34500,
		Body = Color3.fromRGB(50, 50, 60),
		Accent = Color3.fromRGB(80, 220, 255),
		Shape = "Dino",
	},
	{
		Id = "avocado_monster",
		Name = "Avocado Monster",
		NameRu = "Авокадо-Монстр",
		Rarity = "Legendary",
		Price = 90000000,
		Income = 60000,
		Body = Color3.fromRGB(115, 160, 45),
		Accent = Color3.fromRGB(70, 45, 25),
		Shape = "Blob",
	},
	{
		Id = "king_crab",
		Name = "King Crab",
		NameRu = "Кинг-Краб",
		Rarity = "Legendary",
		Price = 173000000,
		Income = 96000,
		Body = Color3.fromRGB(180, 30, 40),
		Accent = Color3.fromRGB(255, 205, 40),
		Shape = "Crab",
	},
	{
		Id = "grill_phoenix",
		Name = "Grill Phoenix",
		NameRu = "Гриль-Феникс",
		Rarity = "Legendary",
		Price = 336000000,
		Income = 140000,
		Body = Color3.fromRGB(255, 80, 20),
		Accent = Color3.fromRGB(255, 220, 50),
		Shape = "Bird",
	},

	-- =========================================================================
	-- MYTHIC (Price: $1.44B - $11.5B, Payback: 1 - 2 h)
	-- =========================================================================
	{
		Id = "mecha_godzilych",
		Name = "Mecha Zillo",
		NameRu = "Меха-Зиллыч",
		Rarity = "Mythic",
		Price = 1440000000,
		Income = 400000,
		Body = Color3.fromRGB(175, 185, 195),
		Accent = Color3.fromRGB(255, 40, 70),
		Shape = "Dino",
	},
	{
		Id = "black_hole_blob",
		Name = "Black Hole Blob",
		NameRu = "Чёрная Дырочка",
		Rarity = "Mythic",
		Price = 3500000000,
		Income = 700000,
		Body = Color3.fromRGB(20, 15, 30),
		Accent = Color3.fromRGB(255, 110, 230),
		Shape = "Blob",
	},
	{
		Id = "crab_armageddon",
		Name = "Crabmageddon",
		NameRu = "Краб-Армагеддон",
		Rarity = "Mythic",
		Price = 6600000000,
		Income = 1100000,
		Body = Color3.fromRGB(45, 20, 25),
		Accent = Color3.fromRGB(255, 60, 20),
		Shape = "Crab",
	},
	{
		Id = "shawarmasaur",
		Name = "Shawarmasaur",
		NameRu = "Шаурмозавр",
		Rarity = "Mythic",
		Price = 11500000000,
		Income = 1600000,
		Body = Color3.fromRGB(215, 175, 115),
		Accent = Color3.fromRGB(220, 45, 45),
		Shape = "Tall",
	},

	-- =========================================================================
	-- SECRET (Price: $43B - $216B, Payback: 4 - 5 h)
	-- =========================================================================
	{
		Id = "cosmo_capybara",
		Name = "Cosmo Capybara",
		NameRu = "Космо-Капибара",
		Rarity = "Secret",
		Price = 43000000000,
		Income = 3000000,
		Body = Color3.fromRGB(130, 95, 70),
		Accent = Color3.fromRGB(0, 255, 210),
		Shape = "Blob",
	},
	{
		Id = "giga_shlepa",
		Name = "Giga Floppa",
		NameRu = "Гига-Шлёпа",
		Rarity = "Secret",
		Price = 80000000000,
		Income = 5000000,
		Body = Color3.fromRGB(200, 140, 85),
		Accent = Color3.fromRGB(170, 0, 255),
		Shape = "Tall",
	},
	{
		Id = "baton_dragon",
		Name = "Baguette Dragon",
		NameRu = "Дракон-Батон",
		Rarity = "Secret",
		Price = 130000000000,
		Income = 8000000,
		Body = Color3.fromRGB(230, 185, 110),
		Accent = Color3.fromRGB(255, 240, 180),
		Shape = "Bird",
	},
	{
		Id = "cyber_titan_rex",
		Name = "Cyber Titan",
		NameRu = "Кибер-Титан",
		Rarity = "Secret",
		Price = 216000000000,
		Income = 12000000,
		Body = Color3.fromRGB(30, 35, 45),
		Accent = Color3.fromRGB(0, 255, 180),
		Shape = "Dino",
	},
}

-- Fast lookup tables
local byId: { [string]: KaijuDef } = {}
local byRarity: { [string]: { KaijuDef } } = {}

for _, def in Kaiju.List do
	byId[def.Id] = def
	if not byRarity[def.Rarity] then
		byRarity[def.Rarity] = {}
	end
	table.insert(byRarity[def.Rarity], def)
end

function Kaiju.get(id: string): KaijuDef?
	return byId[id]
end

function Kaiju.roll(rng: Random?): KaijuDef
	local r = rng or Random.new()
	local weights = Config.RarityWeights
	local totalWeight = 0
	for _, rarity in Kaiju.Rarities do
		totalWeight += weights[rarity] or 0
	end

	local rollValue = r:NextInteger(1, math.max(1, totalWeight))
	local accumulated = 0
	local chosenRarity = Kaiju.Rarities[1]

	for _, rarity in Kaiju.Rarities do
		local weight = weights[rarity] or 0
		accumulated += weight
		if rollValue <= accumulated then
			chosenRarity = rarity
			break
		end
	end

	local pool = byRarity[chosenRarity]
	if pool and #pool > 0 then
		return pool[r:NextInteger(1, #pool)]
	end

	return Kaiju.List[1]
end

-- What the owner gets for selling: bigger kaiju are worth more (Titan sells for 3x its price).
function Kaiju.sellValue(entry: SlotEntry): number
	local def = entry and byId[entry.Id]
	if not def then
		return 0
	end
	local _, stage = Config.stageFor(entry.Growth or 0)
	return math.floor(def.Price * Config.SellRefund * (stage.Income or 1))
end

function Kaiju.incomeOf(entry: SlotEntry, rebirths: number?): number
	if not entry or not entry.Id then
		return 0
	end
	local def = byId[entry.Id]
	if not def then
		return 0
	end

	local _, stage = Config.stageFor(entry.Growth or 0)
	local stageIncome = if stage and stage.Income then stage.Income else 1
	local rebirthMult = Config.incomeMultiplier(rebirths or 0)

	local mutationMult = 1
	if entry.Mutation and Config.MutationMultipliers then
		local mult = Config.MutationMultipliers[entry.Mutation]
		if mult then
			mutationMult = mult
		end
	end

	return def.Income * stageIncome * rebirthMult * mutationMult
end

return Kaiju
