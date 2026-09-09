
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- References
local Types = script:FindFirstAncestor("Types")

-- Modules
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Type = require(Types.Core.Type)

export type Connection = {
    -- Private data
    _callback: (...any) -> (),

    -- Data
    Connected: boolean,
    Disconnect: (self: Connection) -> ()
}

-- A custom signal implementation that bypasses the instance-bound nature of RBXScriptSignal and has better typing.
export type Signal<A... = ...any> = Type.Type<{
    -- Private data
    _connections: {[Connection]: true},

    -- Firing methods
    Fire: (self: Signal<A...>, A...) -> (),
    FireAsync: (self: Signal<A...>, A...) -> (),
    FireDeferred: (self: Signal<A...>, n: number, A...) -> (),

    -- Binding methods
    Connect: (self: Signal<A...>, callback: (A...) -> ()) -> Connection,
    Once: (self: Signal<A...>, callback: (A...) -> ()) -> Connection,
    Wait: (self: Signal<A...>) -> (A...),
    DisconnectAll: (self: Signal<A...>) -> ()
}>
local SignalMethods = Type.methods("Signal", {} :: Signal)

-- Fires the signal, calling all connected callbacks with the provided arguments.
function SignalMethods.Fire(self: Signal, ...: any): ()
    for _, connection in ipairs(TableUtil.Keys(self._connections)) do
        if connection.Connected then
            local success, err: string? = pcall(connection._callback, ...)
            if not success then
                Pretty.Warn(`error while firing signal: {err}`,
                    nil, `{self._typeName}.Fire`)
            end
        else
            self._connections[connection] = nil
        end
    end
end

-- Calls Fire in a new thread.
function SignalMethods.FireAsync(self: Signal, ...: any): ()
    task.spawn(function(...): ()
        self:Fire(...)
    end, ...)
end

-- Calls Fire after a delay of n seconds in a new thread.
function SignalMethods.FireDeferred(self: Signal, n: number, ...: any): ()
    task.delay(n, function(...): ()
        self:Fire(...)
    end, ...)
end

-- Connects a callback to the signal.
function SignalMethods.Connect(self: Signal, callback: (...any) -> ()): Connection
    -- Construct connection object
    local connection: Connection
    connection = setmetatable({
        _callback = callback,
        Connected = true,
        Disconnect = function(_: Connection): ()
            if not connection.Connected then
                return Pretty.Debug("attempted to disconnect an already disconnected connection",
                    nil, "Connection.Disconnect")
            end
            self._connections[connection] = nil
            connection.Connected = false
        end
    }, {
        __newindex = function(_, key: any, value: any): ()
            Pretty.Debug(`attempt to set '{tostring(key)}' on a connection object`,
                nil, "Connection.__newindex")
        end
    }) :: any
    
    -- Store
    self._connections[connection] = true

    return connection
end

-- Connects a callback to the signal that will only be called once.
function SignalMethods.Once(self: Signal, callback: (...any) -> ()): Connection
    local connection: Connection
    connection = self:Connect(function(...: any): ()
        if connection.Connected then
            connection:Disconnect()
            callback(...)
        end
    end)
    return connection
end

-- Yields the current thread until the signal is fired, returning the arguments passed to the signal.
function SignalMethods.Wait(self: Signal): (...any)
    local thread = coroutine.running()
    local connection: Connection
    connection = self:Connect(function(...: any): ()
        if connection.Connected then
            connection:Disconnect()
            local success = coroutine.resume(thread, ...)
            if not success then
                Pretty.Warn(`error while resuming thread`,
                    nil, `{self._typeName}.Wait`)
            end
        end
    end)
    return coroutine.yield()
end

-- Disconnects all connections from the signal.
function SignalMethods.DisconnectAll(self: Signal): ()
    for _, connection in ipairs(TableUtil.Keys(self._connections)) do
        connection.Connected = false
    end
    table.clear(self._connections)
end

function SignalMethods._destroy(self: Signal): ()
    self:DisconnectAll()
end

local SignalClass = {}

SignalClass.new = (function(witness: any?): Signal
    return Type.instance({ _connections = {} }, SignalMethods)
end) ::
    (() -> Signal) &
    (<A...>(witness: (A...) -> ()) -> Signal<A...>)

return Type.class(SignalClass, SignalMethods)