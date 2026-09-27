--!strict
-- Kaiju catalog, definitions, rolling, and income calculation.

local Config = require(script.Parent.Config)

export type KaijuDef = {
	Id: string,
	Name: string,
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
-- Payback time (Price / Income) starts at 20-31s for Common and increases with rarity up to ~$58M.
Kaiju.List = {
	-- =========================================================================
	-- COMMON (Price: $15 - $500, Payback: 20s - 31s)
	-- =========================================================================
	{
		Id = "toastosaurus",
		Name = "Тостозавр",
		Rarity = "Common",
		Price = 15,
		Income = 0.75,
		Body = Color3.fromRGB(222, 184, 135),
		Accent = Color3.fromRGB(139, 69, 19),
		Shape = "Dino",
	},
	{
		Id = "mudpup",
		Name = "Грязепупс",
		Rarity = "Common",
		Price = 40,
		Income = 1.8,
		Body = Color3.fromRGB(150, 110, 80),
		Accent = Color3.fromRGB(90, 60, 40),
		Shape = "Blob",
	},
	{
		Id = "craboid",
		Name = "Крабоид",
		Rarity = "Common",
		Price = 100,
		Income = 4,
		Body = Color3.fromRGB(230, 100, 70),
		Accent = Color3.fromRGB(255, 160, 120),
		Shape = "Crab",
	},
	{
		Id = "chirik",
		Name = "Чирик",
		Rarity = "Common",
		Price = 220,
		Income = 8,
		Body = Color3.fromRGB(140, 200, 120),
		Accent = Color3.fromRGB(255, 200, 50),
		Shape = "Bird",
	},
	{
		Id = "nosatik",
		Name = "Носатик",
		Rarity = "Common",
		Price = 500,
		Income = 16,
		Body = Color3.fromRGB(160, 175, 190),
		Accent = Color3.fromRGB(240, 120, 80),
		Shape = "Tall",
	},

	-- =========================================================================
	-- RARE (Price: $1,200 - $35,000, Payback: 36s - 55s)
	-- =========================================================================
	{
		Id = "cactusaur",
		Name = "Кактусозавр",
		Rarity = "Rare",
		Price = 1200,
		Income = 33,
		Body = Color3.fromRGB(60, 160, 75),
		Accent = Color3.fromRGB(255, 90, 140),
		Shape = "Dino",
	},
	{
		Id = "bubblegum_goblin",
		Name = "Гоблин-Бубльгум",
		Rarity = "Rare",
		Price = 3000,
		Income = 75,
		Body = Color3.fromRGB(255, 105, 180),
		Accent = Color3.fromRGB(100, 240, 255),
		Shape = "Blob",
	},
	{
		Id = "crabburger",
		Name = "Крабобургер",
		Rarity = "Rare",
		Price = 7500,
		Income = 165,
		Body = Color3.fromRGB(210, 140, 60),
		Accent = Color3.fromRGB(220, 50, 40),
		Shape = "Crab",
	},
	{
		Id = "pigeon_bomber",
		Name = "Голубь-Бомбардир",
		Rarity = "Rare",
		Price = 16000,
		Income = 320,
		Body = Color3.fromRGB(130, 140, 155),
		Accent = Color3.fromRGB(60, 180, 160),
		Shape = "Bird",
	},
	{
		Id = "giraffecrane",
		Name = "Жирафокран",
		Rarity = "Rare",
		Price = 35000,
		Income = 640,
		Body = Color3.fromRGB(245, 190, 40),
		Accent = Color3.fromRGB(50, 50, 50),
		Shape = "Tall",
	},

	-- =========================================================================
	-- EPIC (Price: $80,000 - $1,800,000, Payback: 61s - 95s)
	-- =========================================================================
	{
		Id = "pelmenisaur",
		Name = "Пельменозавр",
		Rarity = "Epic",
		Price = 80000,
		Income = 1300,
		Body = Color3.fromRGB(245, 240, 225),
		Accent = Color3.fromRGB(90, 140, 70),
		Shape = "Dino",
	},
	{
		Id = "slime_shlepa",
		Name = "Слайм-Шлёпа",
		Rarity = "Epic",
		Price = 180000,
		Income = 2600,
		Body = Color3.fromRGB(215, 155, 95),
		Accent = Color3.fromRGB(25, 25, 30),
		Shape = "Blob",
	},
	{
		Id = "boxer_crab",
		Name = "Краб-Боксёр",
		Rarity = "Epic",
		Price = 420000,
		Income = 5400,
		Body = Color3.fromRGB(235, 70, 50),
		Accent = Color3.fromRGB(250, 230, 60),
		Shape = "Crab",
	},
	{
		Id = "interceptor_seagull",
		Name = "Чайка-Перехватчик",
		Rarity = "Epic",
		Price = 900000,
		Income = 10500,
		Body = Color3.fromRGB(235, 240, 245),
		Accent = Color3.fromRGB(40, 45, 60),
		Shape = "Bird",
	},
	{
		Id = "bananosaur",
		Name = "Бананозавр",
		Rarity = "Epic",
		Price = 1800000,
		Income = 19000,
		Body = Color3.fromRGB(255, 225, 50),
		Accent = Color3.fromRGB(90, 60, 30),
		Shape = "Tall",
	},

	-- =========================================================================
	-- LEGENDARY (Price: $3,800,000 - $22,000,000, Payback: 110s - 157s)
	-- =========================================================================
	{
		Id = "catzilla",
		Name = "Котзилла",
		Rarity = "Legendary",
		Price = 3800000,
		Income = 34500,
		Body = Color3.fromRGB(50, 50, 60),
		Accent = Color3.fromRGB(80, 220, 255),
		Shape = "Dino",
	},
	{
		Id = "avocado_monster",
		Name = "Авокадо-Монстр",
		Rarity = "Legendary",
		Price = 7500000,
		Income = 60000,
		Body = Color3.fromRGB(115, 160, 45),
		Accent = Color3.fromRGB(70, 45, 25),
		Shape = "Blob",
	},
	{
		Id = "king_crab",
		Name = "Кинг-Краб",
		Rarity = "Legendary",
		Price = 13500000,
		Income = 96000,
		Body = Color3.fromRGB(180, 30, 40),
		Accent = Color3.fromRGB(255, 205, 40),
		Shape = "Crab",
	},
	{
		Id = "grill_phoenix",
		Name = "Гриль-Феникс",
		Rarity = "Legendary",
		Price = 22000000,
		Income = 140000,
		Body = Color3.fromRGB(255, 80, 20),
		Accent = Color3.fromRGB(255, 220, 50),
		Shape = "Bird",
	},

	-- =========================================================================
	-- MYTHIC (Price: $30,000,000 - $46,000,000, Payback: 176s - 209s)
	-- =========================================================================
	{
		Id = "mecha_godzilych",
		Name = "Меха-Годзилыч",
		Rarity = "Mythic",
		Price = 30000000,
		Income = 170000,
		Body = Color3.fromRGB(175, 185, 195),
		Accent = Color3.fromRGB(255, 40, 70),
		Shape = "Dino",
	},
	{
		Id = "black_hole_blob",
		Name = "Чёрная Дырочка",
		Rarity = "Mythic",
		Price = 36000000,
		Income = 195000,
		Body = Color3.fromRGB(20, 15, 30),
		Accent = Color3.fromRGB(255, 110, 230),
		Shape = "Blob",
	},
	{
		Id = "crab_armageddon",
		Name = "Краб-Армагеддон",
		Rarity = "Mythic",
		Price = 41000000,
		Income = 210000,
		Body = Color3.fromRGB(45, 20, 25),
		Accent = Color3.fromRGB(255, 60, 20),
		Shape = "Crab",
	},
	{
		Id = "shawarmasaur",
		Name = "Шаурмозавр",
		Rarity = "Mythic",
		Price = 46000000,
		Income = 220000,
		Body = Color3.fromRGB(215, 175, 115),
		Accent = Color3.fromRGB(220, 45, 45),
		Shape = "Tall",
	},

	-- =========================================================================
	-- SECRET (Price: $50,000,000 - $58,000,000, Payback: ~208s - 211s)
	-- =========================================================================
	{
		Id = "cosmo_capybara",
		Name = "Космо-Капибара",
		Rarity = "Secret",
		Price = 50000000,
		Income = 240000,
		Body = Color3.fromRGB(130, 95, 70),
		Accent = Color3.fromRGB(0, 255, 210),
		Shape = "Blob",
	},
	{
		Id = "giga_shlepa",
		Name = "Гига-Шлёпа",
		Rarity = "Secret",
		Price = 52500000,
		Income = 250000,
		Body = Color3.fromRGB(200, 140, 85),
		Accent = Color3.fromRGB(170, 0, 255),
		Shape = "Tall",
	},
	{
		Id = "baton_dragon",
		Name = "Дракон-Батон",
		Rarity = "Secret",
		Price = 55000000,
		Income = 260000,
		Body = Color3.fromRGB(230, 185, 110),
		Accent = Color3.fromRGB(255, 240, 180),
		Shape = "Bird",
	},
	{
		Id = "cyber_titan_rex",
		Name = "Кибер-Титан",
		Rarity = "Secret",
		Price = 58000000,
		Income = 275000,
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
