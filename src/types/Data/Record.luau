
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- References
local Types = script:FindFirstAncestor("Types")

-- Modules
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local ValueWrap = require(Types.Data.Wraps.ValueWrap)
local Signal = require(Types.Core.Signal)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Type = require(Types.Core.Type)

type RecordPath = {string | number}

-- Essentially a managed table that controls access via metatables and provides granular, path-based change events.
export type Record<T = {}> = Type.Type<T & {
    -- Private data
    _mirrors: {[any]: any},
    _raw: T,

    -- Events
    Changed: Signal.Signal<RecordPath, any?, any?>,

    -- Helper methods
    GetChangedSignalUnderPath: (self: Record<T>, path: RecordPath) -> Signal.Signal<RecordPath, any?, any?>,
    GetChangedSignalAtPath: (self: Record<T>, path: RecordPath) -> Signal.Signal<any?, any?>,
    Raw: (self: Record<T>, noClone: boolean?) -> T,

    -- Methods
    Unwrap: <K, V>(self: Record<T>, obj: {[K]: V}?) -> {[K]: V},
    Track: (self: Record<T>, path: RecordPath) -> (ValueWrap.ValueWrap<any>, Signal.Signal<any?, any?>),
    Apply: (self: Record<T>, path: RecordPath, value: any?) -> (boolean, string?),
    Get: (self: Record<T>, path: RecordPath) -> any?
}>
local RecordMethods = Type.methods("Record", {} :: Record)

-- Creates a signal that fires when the value under the given path changes, including any subpaths.
function RecordMethods.GetChangedSignalUnderPath(self: Record, path: RecordPath): Signal.Signal<RecordPath, any?, any?>
    local signal = Signal.new()
    local connection: Signal.Connection
    connection = self.Changed:Connect(function(otherPath: RecordPath, newValue: any?, oldValue: any?)
        if #otherPath >= #path and TableUtil.Every(path, function(value: any, index: number): boolean
            return value == otherPath[index]
        end) then
            signal:Fire(otherPath, newValue, oldValue)
        end
    end)
    signal.Destroying:Once(function(): ()
        connection:Disconnect()
    end)
    return signal
end

-- Creates a signal that fires when the value at the given path changes.
function RecordMethods.GetChangedSignalAtPath(self: Record, path: RecordPath): Signal.Signal<any?, any?>
    local signal = Signal.new()
    local connection: Signal.Connection
    connection = self.Changed:Connect(function(otherPath: RecordPath, newValue: any?, oldValue: any?)
        if #otherPath == #path and TableUtil.Every(otherPath, function(value: any, index: number): boolean
            return value == path[index]
        end) then
            signal:Fire(newValue, oldValue)
        end
    end)
    signal.Destroying:Once(function(): ()
        connection:Disconnect()
    end)
    return signal
end

-- Used to access the raw table without going through the metatable.
-- This is mainly used for iteration over the table.
-- This is read-only; modifications to the raw table will not trigger change events.
function RecordMethods.Unwrap(self: Record, obj: {[any]: any}?): {[any]: any}
    local target = obj or self
    if typeof(target) ~= "table" then
        return target
    end

    -- Root record object
    if target == self then
        return rawget(self, "_raw") :: any
    end

    -- Mirror object
    local maybeRaw = rawget(target, "_raw")
    if typeof(maybeRaw) == "table" and self._mirrors[maybeRaw] == target then
        return maybeRaw
    end

    -- Just a plain table
    return target
end

-- Constructs and returns a ValueWrap that tracks the value at the given path.
function RecordMethods.Track(self: Record, path: RecordPath): (ValueWrap.ValueWrap<any>, Signal.Signal<any?, any?>)
    local wrap = ValueWrap.new(self:Get(path))
    local signal = self:GetChangedSignalAtPath(path)
    signal:Connect(function(new: any?, old: any?): ()
        wrap:Set(new)
    end)
    wrap.Destroying:Once(function(): ()
        if not signal:IsDestroyed() then
            signal:Destroy()
        end
    end)
    return wrap, signal
end

-- Returns the raw table, optionally without copying it.
function RecordMethods.Raw(self: Record, noClone: boolean?): any
    local raw = rawget(self, "_raw")
    if noClone then
        return raw
    else
        return TableUtil.Copy(raw, true)
    end
end

-- Safely sets the value at the given path, returning true on success.
-- Does not create intermediary tables if they don't exist, and will return false if the path is invalid.
function RecordMethods.Apply(self: Record, path: RecordPath, value: any?): (boolean, string?)
    if #path == 0 then
        return false, "empty path"
    end

    local current = self
    for i, key in ipairs(path) do
        if current == nil then
            return false, `path segment {i} ('{tostring(key)}') parent is nil`
        elseif typeof(current) ~= "table" then
            return false, `path segment {i} ('{tostring(key)}') parent is {typeof(current)}, expected table`
        elseif i == #path then
            current[key] = value
            return true, nil
        else
            current = current[key]
        end
    end
    return false, "invalid path"
end

-- Returns the value at the given path, or nil if it doesn't exist.
function RecordMethods.Get(self: Record, path: RecordPath): any?
    local current = self
    for _, key in ipairs(path) do
        if typeof(current) ~= "table" then
            return nil
        end
        current = current[key]
    end
    return current
end

function RecordMethods._destroy(self: Record): ()
    self.Changed:Destroy()
    table.clear(rawget(self, "_mirrors") :: any)
end

local RecordClass = {}

function RecordClass.newIndex(raw: any, path: RecordPath, changed: Signal.Signal, mirrors: any): (any, any) -> any?
    return function(_, key: any): any?
        local v = raw[key]
        if typeof(v) == "table" then
            local newPath = TableUtil.Extend(path, { key })
            return RecordClass.newMirror(v, newPath, changed, mirrors)
        else
            return v
        end
    end
end

function RecordClass.newNewIndex(raw: any, path: RecordPath, changed: Signal.Signal, mirrors: any): (any, any, any) -> ()
    return function(_, key: any, value: any): ()
        if key == "_raw" then
            return Pretty.Error("attempt to set private property '_raw'",
                script, "newNewIndex")
        end
        -- If value is a table, check if its a mirror
        if typeof(value) == "table" then
            local extractedRaw = rawget(value, "_raw")
            if extractedRaw and mirrors[extractedRaw] == value then
                value = extractedRaw
            end
        end
        local old = raw[key]
        if old == value then
            return
        end
        raw[key] = value
        local newPath = TableUtil.Extend(path, { key })
        changed:Fire(newPath, value, old)
    end
end

function RecordClass.newMirror(raw: any, path: RecordPath, changed: Signal.Signal, mirrors: any): any
    if mirrors[raw] then
        return mirrors[raw]
    end
    local mirror = setmetatable({}, {
        __index = RecordClass.newIndex(raw, path, changed, mirrors),
        __newindex = RecordClass.newNewIndex(raw, path, changed, mirrors)
    })
    rawset(mirror :: any, "_raw", raw)
    mirrors[raw] = mirror
    return mirror
end

RecordClass.new = (function<T>(template: any, data: any?, methods: any?): any
    -- Reconcile against the template
    local raw = TableUtil.Reconcile(data or {}, template)

    -- Choose methods
    local methods = methods or RecordMethods

    -- Construct self
    local changed = Signal.new()
    local self: Record = Type.instance({
        -- Private data
        _mirrors = setmetatable({}, {
            __mode = "k"
        }),
        _raw = raw,
        
        -- Events
        Changed = changed
    }, methods)

    -- Setup metatable
    setmetatable(self, {
        _typeMethods = methods,
        __index = function(_, key: any): any?
            if
                typeof(key) == "string" and
                key:len() > 0 and
                key:sub(1, 1) == "_" and
                key ~= "_destroy" -- Otherwise Type gets mad
            then
                return Pretty.Error(`attempt to access private property '{key}' of Record`,
                    nil, `{rawget(self, "_typeName")}.__index`)
            end
            local direct = rawget(self, key) or methods[key]
            if direct ~= nil then
                return direct
            end
            local value = self._raw[key]
            if typeof(value) == "table" then
                return RecordClass.newMirror(value, { key }, changed, self._mirrors)
            else
                return value
            end
        end,
        __newindex = RecordClass.newNewIndex(raw, {}, changed, self._mirrors)
    })

    return self :: any
end) ::
    (<T>(template: T, data: any?) -> Record<T>) &
    (<T>(template: any, data: any?, methods: T) -> T)

return Type.class(RecordClass, RecordMethods)