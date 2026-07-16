--!strict
-- shared/Util/Formatter.luau — display helpers (UI polish grows in later sprints).

local Formatter = {}

local SUFFIXES = { "", "K", "M", "B", "T" }

-- 1200 -> "1.2K", 5_000_000 -> "5M"
function Formatter.abbreviate(value: number): string
	local absValue = math.abs(value)
	local suffixIndex = 1
	while absValue >= 1000 and suffixIndex < #SUFFIXES do
		absValue /= 1000
		suffixIndex += 1
	end

	local sign = if value < 0 then "-" else ""
	if suffixIndex == 1 then
		return sign .. tostring(math.floor(absValue + 0.5))
	end

	local rounded = math.floor(absValue * 10) / 10
	if rounded == math.floor(rounded) then
		return string.format("%s%d%s", sign, rounded, SUFFIXES[suffixIndex])
	end
	return string.format("%s%.1f%s", sign, rounded, SUFFIXES[suffixIndex])
end

return Formatter
