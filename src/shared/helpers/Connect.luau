
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Modules
local Signal = require(ReplicatedStorage.Shared.Types.Core.Signal)

-- Passes
local f = table.freeze

local Connect = {}

-- Connects the given callback to all of the provided signals and returns a table of the connections.
Connect.All = (function<A...>(callback: (A...) -> (), ...: any): {any}
    local connections = {}
    for i = 1, select("#", ...) do
        local signal = select(i, ...)
        table.insert(connections, signal:Connect(callback))
    end
    return connections
end) ::
    (<A...>(callback: (A...) -> (), ...RBXScriptSignal<A...>) -> {RBXScriptConnection}) &
    (<A...>(callback: (A...) -> (), ...Signal.Signal<A...>) -> {Signal.Connection})

-- Calls the callback for the current value of now (if it exists) and whenever future fires.
Connect.NowAndFuture = (function<T>(
    now: {[any]: T} | T,
    future: any,
    callback: (T) -> (),
    useAsIs: boolean?
): any
    local connection = future:Connect(callback)
    if typeof(now) == "table" and not useAsIs then
        for _, item in pairs(now) do
            callback(item)
        end
    elseif now ~= nil then
        callback(now :: any)
    end
    return connection
end) ::
    (<T>(
        now: {[any]: T} | T,
        future: RBXScriptSignal<T>,
        callback: (T) -> (),
        useAsIs: boolean?
    ) -> RBXScriptConnection) &
    (<T>(
        now: {[any]: T} | T,
        future: Signal.Signal<T>,
        callback: (T) -> (),
        useAsIs: boolean?
    ) -> Signal.Connection)

-- The same as NowAndFuture, but fires the callback in a new thread for each item.
Connect.NowAndFutureAsync = (function<T>(
    now: {[any]: T} | T,
    future: any,
    callback: (T) -> (),
    useAsIs: boolean?
): any
    return Connect.NowAndFuture(now, future, function(value): ()
        task.spawn(callback, value)
    end, useAsIs)
end) ::
    (<T>(
        now: {[any]: T} | T,
        future: RBXScriptSignal<T>,
        callback: (T) -> (),
        useAsIs: boolean?
    ) -> RBXScriptConnection) &
    (<T>(
        now: {[any]: T} | T,
        future: Signal.Signal<T>,
        callback: (T) -> (),
        useAsIs: boolean?
    ) -> Signal.Connection)

-- Combines NowAndFuture and a corresponding "removed" signal to manage the lifecycle of items. Returns both connections.
Connect.Lifecycle = (function<T>(
    now: {[any]: T} | T,
    added: any,
    removed: any,
    setup: (T) -> (),
    cleanup: (T) -> ()
): any
    return {
        Connect.NowAndFuture(now, added, setup),
        removed:Connect(cleanup)
    }
end) ::
    (<T>(
        now: {[any]: T} | T,
        added: RBXScriptSignal<T>,
        removed: RBXScriptSignal<T>,
        setup: (T) -> (),
        cleanup: (T) -> ()
    ) -> {RBXScriptConnection}) &
    (<T>(
        now: {[any]: T} | T,
        added: Signal.Signal<T>,
        removed: Signal.Signal<T>,
        setup: (T) -> (),
        cleanup: (T) -> ()
    ) -> {Signal.Connection})

-- Connects to a signal and only fires the callback when the filter is passed.
Connect.Filtered = (function<T>(
    signal: any,
    filter: (T) -> boolean,
    callback: (T) -> ()
): any
    return signal:Connect(function(value: T): ()
        if filter(value) then
            callback(value)
        end
    end)
end) ::
    (<T>(
        signal: RBXScriptSignal<T>,
        filter: (T) -> boolean,
        callback: (T) -> ()
    ) -> RBXScriptConnection) &
    (<T>(
        signal: Signal.Signal<T>,
        filter: (T) -> boolean,
        callback: (T) -> ()
    ) -> Signal.Connection)

-- Waits until the given signal fires with a value that passes the filter, with an optional default.
function Connect.Wait<T>(
    current: ({[any]: T} | T)?,
    signal: RBXScriptSignal<T> | Signal.Signal<T>,
    filter: (T) -> boolean,
    wait: number?
): T?
    -- Detect additions
    local found: T? = nil
    local conn: any
    conn = (signal :: any):Connect(function(value): ()
        if filter(value) then
            found = value
            if conn.Connected then
                conn:Disconnect()
            end
        end
    end)

    -- Return if already found
    if typeof(current) == "table" then
        for _, item in pairs(current) do
            if filter(item) then
                found = item
                break
            end
        end
    elseif current ~= nil and filter(current) then
        found = current
    end

    -- Early exit
    if found or (wait and wait <= 0) then
        conn:Disconnect()
        return found
    end

    -- Now we wait
    local start = os.clock()
    local maxTime = math.max(wait or math.huge, 0)
    repeat
        RunService.Heartbeat:Wait()
    until found or (os.clock() - start) >= maxTime

    conn:Disconnect()
    return found
end

-- Disconnects all connections in the given table, and optionally clears the table.
Connect.Disconnect = (function(connections: {[any]: any}, clear: boolean?): ()
    for _, conn in pairs(connections) do
        if conn and conn.Connected then
            conn:Disconnect()
        end
    end
    if clear then
        table.clear(connections)
    end
end) ::
    ((connections: {[any]: RBXScriptConnection}, clear: boolean?) -> ()) &
    ((connections: {[any]: Signal.Connection}, clear: boolean?) -> ())

return f(Connect)