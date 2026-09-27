-- Short money strings: 950 -> "950", 12500 -> "12.5K", 3.2e9 -> "3.2B".
local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

function Format.short(n: number): string
	if n ~= n then
		return "0"
	end
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end
	local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
	local scaled = n / 10 ^ (tier * 3)
	local text = if scaled >= 100 then string.format("%d", scaled) else string.format("%.1f", scaled)
	text = text:gsub("%.0$", "")
	return sign .. text .. SUFFIXES[tier + 1]
end

function Format.money(n: number): string
	return "$" .. Format.short(n)
end

-- Income per second: keeps cents for small fractional rates ($0.75/s), else like money.
function Format.rate(n: number): string
	if n > 0 and n < 100 and n ~= math.floor(n) then
		local text = string.format("%.2f", n):gsub("0+$", ""):gsub("%.$", "")
		return "$" .. text .. "/s"
	end
	return Format.money(n) .. "/s"
end

function Format.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, (seconds % 3600) // 60)
	elseif seconds >= 60 then
		return string.format("%dm %02ds", seconds // 60, seconds % 60)
	end
	return seconds .. "s"
end

return Format
