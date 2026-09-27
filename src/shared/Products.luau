-- Everything sold for Robux. Create each pass / developer product in the Creator Hub
-- (Monetization tab of the experience) and paste its id into `Id`. While an id is 0 the item
-- is granted for free in Studio (test mode) and shows "Soon" in a live game.
local Products = {}

export type Pass = { Id: number, Name: string, Desc: string, Price: number, Icon: string, Order: number }
export type Item = {
	Id: number,
	Name: string,
	Desc: string,
	Price: number,
	Icon: string,
	Order: number,
	Seconds: number?, -- cash packs: this many seconds of the buyer's current income...
	Min: number?, -- ...but never less than this
}

Products.Passes = {
	DoubleCash = { Id = 0, Name = "2x Cash", Desc = "Double income from every kaiju, forever", Price = 199, Icon = "💰", Order = 1 },
	VIP = { Id = 0, Name = "VIP", Desc = "+1 pad, +20% income and a VIP tag", Price = 249, Icon = "👑", Order = 2 },
	AutoCollect = { Id = 0, Name = "Auto Collect", Desc = "Cash goes straight to your wallet", Price = 99, Icon = "🧲", Order = 3 },
	ExtraSlots = { Id = 0, Name = "+2 Pads", Desc = "Two more kaiju on your base", Price = 149, Icon = "🧱", Order = 4 },
	FastLegs = { Id = 0, Name = "Fast Legs", Desc = "Run 25% faster (not while carrying)", Price = 99, Icon = "👟", Order = 5 },
} :: { [string]: Pass }

Products.Items = {
	StarterPack = {
		Id = 0,
		Name = "Starter Pack",
		Desc = "1 h of cash + 30 min Shield + Grow Boost. Once, first 24 h only!",
		Price = 99,
		Icon = "🎁",
		Order = 0,
		Seconds = 3600,
		Min = 25_000,
	},
	UnlockPad = { Id = 0, Name = "Unlock a Pad", Desc = "Open your next locked pad right now (kept after rebirth)", Price = 49, Icon = "🔓", Order = 1 },
	Shield10 = { Id = 0, Name = "Shield 10 min", Desc = "Nobody can enter your base", Price = 29, Icon = "🛡️", Order = 1 },
	Shield30 = { Id = 0, Name = "Shield 30 min", Desc = "Nobody can enter your base", Price = 69, Icon = "🛡️", Order = 2 },
	GrowBoost = { Id = 0, Name = "Grow Boost", Desc = "+15 min of growth for every kaiju", Price = 49, Icon = "🌱", Order = 3 },
	CashRain = {
		Id = 0,
		Name = "Cash Rain",
		Desc = "2x cash for EVERYONE on the server for 5 min — with your name on it",
		Price = 199,
		Icon = "💸",
		Order = 4,
	},
	CashSmall = { Id = 0, Name = "Pile of Cash", Desc = "10 min of your income", Price = 49, Icon = "💵", Order = 5, Seconds = 600, Min = 1_000 },
	CashMedium = { Id = 0, Name = "Bag of Cash", Desc = "1 h of your income", Price = 199, Icon = "💰", Order = 6, Seconds = 3600, Min = 10_000 },
	CashLarge = { Id = 0, Name = "Vault of Cash", Desc = "4 h of your income", Price = 499, Icon = "🏦", Order = 7, Seconds = 4 * 3600, Min = 100_000 },
	CashHuge = { Id = 0, Name = "Cash Tsunami", Desc = "16 h of your income", Price = 1499, Icon = "🌊", Order = 8, Seconds = 16 * 3600, Min = 1_000_000 },
} :: { [string]: Item }

-- Gifting a pass is a developer product per pass (passes themselves can't be bought for someone else).
Products.Gifts = {
	DoubleCash = { Id = 0 },
	VIP = { Id = 0 },
	AutoCollect = { Id = 0 },
	ExtraSlots = { Id = 0 },
	FastLegs = { Id = 0 },
} :: { [string]: { Id: number } }

-- Unlocking pads for cash: the n-th bought pad (1-based) costs PadBaseCost * PadCostGrowth^(n-1)
Products.PadBaseCost = 50_000
Products.PadCostGrowth = 50

function Products.padCost(alreadyBought: number): number
	return Products.PadBaseCost * Products.PadCostGrowth ^ alreadyBought
end

-- Rewarded video ads (AdService). Each reward is a developer product (Roblox recommends
-- rewards worth 3-10 Robux); ads only run once the game has 2,000+ monthly visitors.
export type AdReward = { Id: number, Name: string, Desc: string, Icon: string, Seconds: number?, Min: number? }
Products.AdRewards = {
	AdCash = { Id = 0, Name = "Free Cash", Desc = "10 min of your income", Icon = "💵", Seconds = 600, Min = 500 },
	AdShield = { Id = 0, Name = "Free Shield 5 min", Desc = "Nobody can enter your base", Icon = "🛡️" },
	AdDoubleOffline = { Id = 0, Name = "Double Offline Cash", Desc = "Get your offline earnings again", Icon = "🌙" },
} :: { [string]: AdReward }
Products.AdCooldownSeconds = 180 -- per player, per reward

Products.StarterWindowSeconds = 24 * 3600
Products.CashRainSeconds = 300
Products.ShieldOfferCooldown = 300 -- after being robbed, offer a Shield at most this often

-- Cash granted by a pack for a player earning `income` per second.
function Products.cashFor(item: Item, income: number): number
	return math.floor(math.max(item.Min or 0, income * (item.Seconds or 0)))
end

return Products
