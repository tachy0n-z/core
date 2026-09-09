
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Signal = require(ReplicatedStorage.Shared.Types.Core.Signal)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)

-- Constants
local DEFAULT_CAPACITY = 60

local Debounce = {}

-- Runs the provided callback every n fires of the provided event.
Debounce.Every = (function<A...>(ev: any, callback: (A...) -> (), n: number): any
	local count = 0
	return ev:Connect(function(...: A...): ()
		count += 1
		if count % n == 0 then
			local success, err: string? = pcall(callback, ...)
			if not success then
				Pretty.Warn(`error while executing callback: {err}`,
					script, "Every")
			end
		end
	end)
end) ::
	(<A...>(ev: RBXScriptSignal<A...>, callback: (A...) -> (), n: number) -> RBXScriptConnection) &
	(<A...>(ev: Signal.Signal<A...>, callback: (A...) -> (), n: number) -> Signal.Connection)

-- A table is generated (of the given capacity) for the provided event that tracks its first argument on every fire.
-- An average is calculated on every fire and passed to the avChange method.
-- Capacity defaults to DEFAULT_CAPACITY.
Debounce.Track = (function(ev: any, avChange: (v: number) -> (), capacity: number?): any
	local cap = DEFAULT_CAPACITY
	if capacity ~= nil and capacity > 0 then
		cap = capacity
	end

	-- Vars
	local buffer = {}
	local index = 1
	local count = 0
	local sum = 0

	return ev:Connect(function(n: number, ...: any): ()
		if typeof(n) == "number" then
			if count >= cap then
				sum -= buffer[index]
			else
				count += 1
			end
			buffer[index] = n
			sum += n
			index = (index % cap) + 1
			avChange(sum / count)
		end
	end)
end) ::
	((ev: RBXScriptSignal<number>, avChange: (v: number) -> (), capacity: number?) -> RBXScriptConnection) &
	((ev: Signal.Signal<number>, avChange: (v: number) -> (), capacity: number?) -> Signal.Connection)

-- Sets up a halt for the provided signal.
-- Does not run the provided callback if the event fires again whilst the callback is still being ran.
Debounce.Halt = (function<A...>(ev: any, callback: (A...) -> ()): any
	local debounced = false
	return ev:Connect(function(...: A...): ()
		if debounced then return end
		debounced = true
		local success, err: string? = pcall(callback, ...)
		if not success then
			Pretty.Warn(`error while executing callback: {err}`,
				script, "Halt")
		end
		debounced = false
	end)
end) ::
	(<A...>(ev: RBXScriptSignal<A...>, callback: (A...) -> ()) -> RBXScriptConnection) &
	(<A...>(ev: Signal.Signal<A...>, callback: (A...) -> ()) -> Signal.Connection)

-- Sets up a debounce for the provided signal.
Debounce.Event = (function<A...>(ev: any, callback: (A...) -> (), debounce: number): any
	local debounced = false
	return ev:Connect(function(...: A...): ()
		if debounced then return end
		debounced = true
		local success, err: string? = pcall(callback, ...)
		if not success then
			Pretty.Warn(`error while executing callback: {err}`,
				script, "Event")
		end
		task.delay(debounce, function(): ()
			debounced = false
		end)
	end)
end) ::
	(<A...>(ev: RBXScriptSignal<A...>, callback: (A...) -> (), debounce: number) -> RBXScriptConnection) &
	(<A...>(ev: Signal.Signal<A...>, callback: (A...) -> (), debounce: number) -> Signal.Connection)

-- Sets up a debounce for the provided signal but only activates the debounce if the callback returns true.
Debounce.EventConditional = (function<A...>(ev: any, callback: (A...) -> boolean, debounce: number): any
	local debounced = false
	return ev:Connect(function(...: A...): ()
		if debounced then return end
		local success, resp = pcall(callback, ...)
		if not success then
			Pretty.Warn(`error while executing callback: {resp}`,
				script, "EventConditional")
		end
		if success and resp then
			debounced = true
			task.delay(debounce, function(): ()
				debounced = false
			end)
		end
	end)
end) ::
	(<A...>(ev: RBXScriptSignal<A...>, callback: (A...) -> boolean, debounce: number) -> RBXScriptConnection) &
	(<A...>(ev: Signal.Signal<A...>, callback: (A...) -> boolean, debounce: number) -> Signal.Connection)

-- Sets up a per-player debounce for the provided signal.
Debounce.PerPlayerEvent = (function<A...>(ev: any, callback: (Player, A...) -> (), debounce: number): any
	local debounces = setmetatable({}, { __mode = "k" })
	return ev:Connect(function(player: Player, ...: A...): ()
		if debounces[player] then return end
		debounces[player] = true
		local success, err: string? = pcall(callback, player, ...)
		if not success then
			Pretty.Warn(`error while executing callback: {err}`,
				script, "PerPlayerEvent")
		end
		task.delay(debounce, function(): ()
			debounces[player] = nil
		end)
	end)
end) ::
	(<A...>(ev: RBXScriptSignal<(Player, A...)>, callback: (Player, A...) -> (), debounce: number) -> RBXScriptConnection) &
	(<A...>(ev: Signal.Signal<(Player, A...)>, callback: (Player, A...) -> (), debounce: number) -> Signal.Connection)

-- Returns a debounced wrapper for the provided function for use with Bindable/Remote events.
function Debounce.Function<T, A...>(callback: (A...) -> T, debounce: number): (A...) -> T?
	local debounced = false
	return function(...: A...): T?
		if debounced then return nil end
		debounced = true
		local success, result = pcall(callback, ...)
		if not success then
			Pretty.Warn(`error while executing callback: {result}`,
				script, "Function")
		end
		task.delay(debounce, function(): ()
			debounced = false
		end)
		return success and result or nil
	end
end

-- Returns a per-player debounced wrapper for the provided function for use with Bindable/Remote events.
function Debounce.PerPlayerFunction<T, A...>(callback: (player: Player, A...) -> T, debounce: number): (player: Player, A...) -> T?
	local debounces = setmetatable({}, { __mode = "k" })
	return function(player: Player, ...: A...): T?
		if debounces[player] then return nil end
		debounces[player] = true
		local success, result = pcall(callback, player, ...)
		if not success then
			Pretty.Warn(`error while executing callback: {result}`,
				script, "PerPlayerFunction")
		end
		task.delay(debounce, function(): ()
			debounces[player] = nil
		end)
		return success and result or nil
	end
end

-- Attempts to call the provided function with the provided arguments and retries if it fails.
-- Provide the expected return type name if nil does not signify failure/debounce.
function Debounce.Retry<T, A...>(
	target: (A...) -> T,
	retries: number,
	debounce: number?,
	expected: string?,
	...: A...
): T?
	-- If retries is below 0, set to math.huge for practical infinity
	retries = retries < 0 and math.huge or retries
	local function isExpected(data: any): boolean
		if expected == nil then
			return data ~= nil
		end
		return typeof(data) == expected
	end

	local data = nil
	for i = 1, retries, 1 do
		local success, someData = pcall(target, ...)
		if not success then
			Pretty.Warn(`error while executing callback: {someData}`,
				script, "Retry")
		end
		if success and isExpected(someData) then
			data = someData
			break
		elseif i < retries and (debounce or 0) > 0 then
			task.wait(debounce)
		end
	end
	return isExpected(data) and data or nil
end

-- Wraps the given function and calls it the given number of times until its return value is not nil.
-- The function will be called at most `retries` times, and will wait `debounce` seconds between calls.
function Debounce.WrapRetry<T, A...>(
	target: (A...) -> T?,
	retries: number,
	debounce: number?,
	expected: string?
): (A...) -> T?
	return function(...: A...): T?
		return Debounce.Retry(target, retries, debounce, expected, ...)
	end
end

return table.freeze(Debounce)