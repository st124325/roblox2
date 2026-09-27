-- Economy and gameplay tuning. Every number a designer might want to change lives here.
local Config = {
	MaxPlayers = 8, -- one base per player

	-- Bases
	StartSlots = 6, -- pads unlocked for a new player
	MaxSlots = 12, -- pads physically built in a base
	SlotsPerRebirth = 1,
	LockSeconds = 60, -- how long the lock button keeps thieves out
	LockCooldown = 3, -- after a lock ends, before it can be pressed again

	-- Income
	IncomeTick = 1, -- seconds between income payouts into the base bank
	OfflineRate = 0.25, -- share of income earned while away
	OfflineCapSeconds = 8 * 3600,
	OfflineGrowthRate = 0.5, -- kaiju keep growing at half speed while the owner is away
	SellRefund = 0.5, -- share of the price returned when sold, times the stage's income multiplier

	-- Rebirth: cost of rebirth n (0-based) is RebirthBaseCost * RebirthCostGrowth^n
	RebirthBaseCost = 200_000_000, -- ~1 h of play (see docs/BALANCE.md)
	RebirthCostGrowth = 5,
	RebirthIncomeBonus = 0.5, -- +50% income per rebirth (additive)

	-- Conveyor
	BeltSpawnSeconds = 2.6,
	BeltSpeed = 7, -- studs per second
	BeltLength = 300,
	RarityWeights = {
		Common = 700,
		Rare = 200,
		Epic = 70,
		Legendary = 24,
		Mythic = 5,
		Secret = 1,
	},

	-- Carrying and stealing
	WalkSpeed = 24,
	StealHoldSeconds = 1.2,
	CarryTimeoutSeconds = 90, -- a stolen kaiju goes home if not delivered by then
	BonkCooldown = 1.2,
	BonkRange = 9,
	BonkStunSeconds = 1.6,
	HomeCooldown = 8,
	-- Anti-cheat: a carrier moving faster than expected * SpeedTolerance + SpeedSlack studs/s
	-- earns a strike; SpeedStrikes strikes send the kaiju home
	SpeedTolerance = 1.5,
	SpeedSlack = 6,
	SpeedStrikes = 3,

	-- Growth stages: seconds on a base to reach the stage, income multiplier, carry speed factor
	Stages = {
		{ Name = "S", Seconds = 0, Income = 1, Carry = 0.95, Scale = 1 },
		{ Name = "M", Seconds = 120, Income = 1.5, Carry = 0.85, Scale = 1.25 },
		{ Name = "L", Seconds = 600, Income = 2.25, Carry = 0.72, Scale = 1.55 },
		{ Name = "XL", Seconds = 1800, Income = 3.5, Carry = 0.6, Scale = 1.9 },
		{ Name = "Titan", Seconds = 5400, Income = 6, Carry = 0.45, Scale = 2.4 },
	},

	-- Mutations: multipliers for income boost (GDD: ×2..×10)
	MutationMultipliers = {
		Radioactive = 2,
		Golden = 3,
		Rainbow = 5,
		Galaxy = 10,
		["Радиоактивный"] = 2,
		["Золотой"] = 3,
		["Радужный"] = 5,
		["Галактический"] = 10,
	},
	Mutations = { "Radioactive", "Golden", "Rainbow", "Galaxy" },

	TutorialReward = 100, -- cash for finishing the first-session tutorial

	-- Data persistence
	StartMoney = 50,
	DataStoreName = "PlayerData_v1",
	DataAutoSaveInterval = 60,
	SessionLockTimeout = 1800,
	DataMaxRetries = 5,
	DataRetryDelay = 2,
}

function Config.stageFor(growth: number): (number, any)
	local index = 1
	for i, stage in Config.Stages do
		if growth >= stage.Seconds then
			index = i
		end
	end
	return index, Config.Stages[index]
end

function Config.rebirthCost(rebirths: number): number
	return Config.RebirthBaseCost * Config.RebirthCostGrowth ^ rebirths
end

function Config.incomeMultiplier(rebirths: number): number
	return 1 + rebirths * Config.RebirthIncomeBonus
end

return Config
