
-- Passes
local f = table.freeze

local NumberFormatter = {}

-- Formats seconds into a 24-hour time format (HH:MM:SS).
function NumberFormatter.To24H(seconds: number): string
	seconds = math.floor(seconds)
	local hours = math.floor(seconds / 3600)
	seconds = seconds % 3600
	local minutes = math.floor(seconds / 60)
	seconds = seconds % 60
	return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

-- Formats seconds into a minutes:seconds format (MM:SS). Hours are converted to minutes.
function NumberFormatter.ToMinutes(seconds: number): string
	-- Handle nil or non-number inputs gracefully
	if typeof(seconds) ~= "number" then
		return "0:00"
	end

	-- Handle negative values
	if seconds < 0 then
		seconds = 0
	end

	-- Calculate minutes and remaining seconds
	local minutes = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)

	-- Format seconds with leading zero if needed
	local formattedSeconds = string.format("%02d", secs)

	-- Return in MM:SS format
	return (minutes < 10 and "0" or "") .. minutes .. ":" .. formattedSeconds
end

-- Formats a number with commas as thousand separators.
function NumberFormatter.ToCommas(num: number): string
	if typeof(num) ~= "number" then
		return tostring(num)
	end
	local str = tostring(math.floor(num))
	local reversed = string.reverse(str)
	local result = ""
	for i = 1, #reversed do
		if (i - 1) % 3 == 0 and i > 1 then
			result = result .. ","
		end
		result = result .. string.sub(reversed, i, i)
	end
	return string.reverse(result)
end

-- Formats a number with an appropriate suffix (k, m, b, etc.) and specified decimal places.
function NumberFormatter.ToSuffixed(n: number, dp: number?): string
	dp = dp or 2

	-- Handle edge cases
	if n == 0 then
		return "0"
	end

	-- Define suffixes and their corresponding divisors
	local suffixes = {
		{value = 1e18, suffix = "qt"}, -- Quintillion (10^18)
		{value = 1e15, suffix = "qd"}, -- Quadrillion (10^15)
		{value = 1e12, suffix = "t"},  -- Trillion     (10^12)
		{value = 1e9,  suffix = "b"},  -- Billion      (10^9)
		{value = 1e6,  suffix = "m"},  -- Million      (10^6)
		{value = 1e3,  suffix = "k"},  -- Thousand     (10^3)
		{value = 1,    suffix = ""}    -- No suffix
	}

	-- Handle negative numbers
	local isNegative = n < 0
	n = math.abs(n)

	-- Find the appropriate suffix
	local suffix = ""
	local scaled = n
	for _, s in ipairs(suffixes) do
		if n >= s.value then
			scaled = n / s.value
			suffix = s.suffix
			break
		end
	end

	-- Format the number with specified decimal places
	local formatString
	if n < 1000 and dp > 0 then
		formatString = "%.0f"
	else
		formatString = "%." .. tostring(dp) .. "f"
	end
	local formatted = string.format(formatString, scaled)

	-- Remove trailing zeros and decimal point if unnecessary
	if dp > 0 and n >= 1000 then
		formatted = tostring(tonumber(formatted)) -- Convert to number and back to remove trailing zeros
		if formatted:match("%.0+$") then
			formatted = formatted:gsub("%.0+$", "") -- Remove .0, .00, etc
		end
	end

	-- Return with negative sign if applicable
	return (isNegative and "-" or "") .. formatted .. suffix
end

-- Formats a weight (between 0 and 1) as a percentage chance with appropriate decimal places based on its magnitude.
function NumberFormatter.FormatChance(weight: number): string
	if weight <= 0 then return "0%" end
	local percent = weight * 100
	if percent >= 1 then return string.format("%.1f%%", percent)
	elseif percent >= 0.1 then return string.format("%.2f%%", percent)
	elseif percent >= 0.01 then return string.format("%.3f%%", percent)
	elseif percent >= 0.0001 then return string.format("%.4f%%", percent)
	else return "<0.0001%" end
end

-- Formats a weight (between 0 and 1) as a "1 in X" chance, rounding to the nearest whole number and adding commas as thousand separators.
function NumberFormatter.OneInX(weight: number): string
	if weight <= 0 then return "Impossible" end
	local oneIn = 1 / weight
	if oneIn > 1e15 or math.huge == oneIn then
		return "1 in ∞"
	end
	return "1 in " .. string.format("%d", math.floor(oneIn + 0.5)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

-- Formats the given number to the specified number of decimal places.
function NumberFormatter.ToDecimalPlaces(num: number, dp: number): string
	local str = string.format("%." .. tostring(dp) .. "f", num)
	str = str:gsub("(%..-)0+$", "%1")
	str = str:gsub("%.$", "")
	return str
end

return f(NumberFormatter)