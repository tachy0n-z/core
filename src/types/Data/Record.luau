
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- References
local Types = script:FindFirstAncestor("Types")

-- Modules
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Signal = require(Types.Core.Signal)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Type = require(Types.Core.Type)

type RecordPath = {string | number}

-- State shared between a record and all of its mirrors.
type RecordState = {
    Root: any,
    Changed: Signal.Signal<RecordPath, any?, any?>,
    Mirrors: {[any]: any},
    Paths: {[any]: RecordPath},
    Shared: {[any]: true}
}

-- Essentially a managed table that controls access via metatables and provides granular, path-based change events.
export type Record<T = {}> = Type.Type<T & {
    -- Private data
    _mirrors: {[any]: any},
    _data: T,
    _raw: T,

    -- Events
    Changed: Signal.Signal<RecordPath, any?, any?>,

    -- Helper methods
    GetChangedSignalUnderPath: (self: Record<T>, path: RecordPath) -> Signal.Signal<RecordPath, any?, any?>,
    GetChangedSignalAtPath: (self: Record<T>, path: RecordPath) -> Signal.Signal<any?, any?>,
    Raw: (self: Record<T>, noClone: boolean?) -> T,

    -- Methods
    Unwrap: <K, V>(self: Record<T>, obj: {[K]: V}?) -> {[K]: V},
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

    local current = self._data -- Not self, so keys named like methods are still reachable
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
    if #path == 0 then
        return self
    end
    local current = self._data -- Not self, so keys named like methods are still reachable
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

-- Returns true if both paths are the same.
local function isSamePath(a: RecordPath, b: RecordPath): boolean
    if #a ~= #b then
        return false
    end
    for i, key in ipairs(a) do
        if b[i] ~= key then
            return false
        end
    end
    return true
end

-- Returns the value at the given path, regardless of whether anything along it is shared.
local function resolve(state: RecordState, path: RecordPath): any?
    local current = state.Root
    for _, key in ipairs(path) do
        if typeof(current) ~= "table" then
            return nil
        end
        current = current[key]
    end
    return current
end

-- Returns true if the given path still leads to the given raw table, without passing through a shared table.
local function isCurrent(state: RecordState, raw: any, path: RecordPath): boolean
    local current = state.Root
    for _, key in ipairs(path) do
        current = current[key]
        if typeof(current) ~= "table" or state.Shared[current] then
            return false
        end
    end
    return current == raw
end

-- Collects every path from the given table to the target table.
local function search(current: any, target: any, path: RecordPath, found: {RecordPath}): {RecordPath}
    for key, value in pairs(current) do
        if typeof(value) ~= "table" then
            continue
        end
        local subPath = TableUtil.Extend(path, { key })
        if value == target then
            table.insert(found, subPath)
        else
            search(value, target, subPath, found)
        end
    end
    return found
end

-- Returns every path the given raw table lives at, only searching if its last known path is outdated.
local function locate(state: RecordState, raw: any): {RecordPath}
    if raw == state.Root then
        return { {} }
    end
    local path = state.Paths[raw]
    if path and isCurrent(state, raw, path) then
        return { path }
    end
    local found = search(state.Root, raw, {}, {})
    if #found == 1 then
        -- Only one way to it, so nothing along that way is shared
        local current = state.Root
        for _, key in ipairs(found[1]) do
            current = current[key]
            state.Shared[current] = nil
        end
    elseif #found > 1 then
        state.Shared[raw] = true
    else
        state.Shared[raw] = nil
    end
    state.Paths[raw] = found[1]
    return found
end

-- Records where the given table (and any within it) now lives, noting any that also live elsewhere.
local function track(state: RecordState, value: any, path: RecordPath): ()
    local known = state.Paths[value]
    if known and not isSamePath(known, path) and resolve(state, known) == value then
        state.Shared[value] = true
    else
        state.Paths[value] = path
    end
    for key, sub in pairs(value) do
        if typeof(sub) == "table" then
            track(state, sub, TableUtil.Extend(path, { key }))
        end
    end
end

-- Iterates over the given raw table, returning mirrors in place of nested tables.
local function iterate(raw: any, mirror: any): (any, any) -> (any, any)
    return function(_, key: any): (any, any)
        local nextKey, value = next(raw, key)
        if typeof(value) == "table" then
            value = mirror[nextKey]
        end
        return nextKey, value
    end
end

local RecordClass = {}

function RecordClass.newIndex(raw: any, state: RecordState): (any, any) -> any?
    return function(_, key: any): any?
        local v = raw[key]
        if typeof(v) == "table" then
            local path = if raw == state.Root then {} else state.Paths[raw] or {}
            state.Paths[v] = TableUtil.Extend(path, { key })
            return RecordClass.newMirror(v, state)
        else
            return v
        end
    end
end

function RecordClass.newNewIndex(raw: any, state: RecordState): (any, any, any) -> ()
    return function(_, key: any, value: any): ()
        if key == "_raw" then
            return Pretty.Error("attempt to set private property '_raw'",
                script, "newNewIndex")
        end
        -- If value is a table, check if its a mirror
        if typeof(value) == "table" then
            local extractedRaw = rawget(value, "_raw")
            if extractedRaw and state.Mirrors[extractedRaw] == value then
                value = extractedRaw
            end
        end
        local old = raw[key]
        if old == value then
            return
        end
        raw[key] = value

        -- Fire for every path this table lives at (usually just the one)
        local paths = locate(state, raw)
        if #paths == 0 then
            return Pretty.Debug(`attempt to set '{tostring(key)}' on a table that is no longer part of the record`,
                script, "newNewIndex")
        end
        if typeof(value) == "table" then
            track(state, value, TableUtil.Extend(paths[1], { key }))
        end
        for _, path in ipairs(paths) do
            state.Changed:Fire(TableUtil.Extend(path, { key }), value, old)
        end
    end
end

function RecordClass.newMirror(raw: any, state: RecordState): any
    if state.Mirrors[raw] then
        return state.Mirrors[raw]
    end
    local mirror = {}
    setmetatable(mirror, {
        __index = RecordClass.newIndex(raw, state),
        __newindex = RecordClass.newNewIndex(raw, state),
        __len = function(): number
            return #raw
        end,
        __iter = function(this: any): ...any
            if this ~= mirror then
                return next, this -- A copy (e.g. from table.clone), so only its own fields
            end
            return iterate(raw, mirror)
        end
    })
    rawset(mirror :: any, "_raw", raw)
    state.Mirrors[raw] = mirror
    return table.freeze(mirror)
end

RecordClass.new = (function<T>(template: any, data: any?, methods: any?): any
    -- Reconcile against the template
    local raw = TableUtil.Reconcile(data or {}, template)

    -- Choose methods
    local methods = methods or RecordMethods

    -- Construct data, accessed through a root mirror so it is tracked like any other table
    local changed = Signal.new()
    local mirrors = setmetatable({}, {
        __mode = "k"
    }) :: any
    local rootMirror = RecordClass.newMirror(raw, {
        Root = raw,
        Changed = changed,
        Mirrors = mirrors,
        Paths = setmetatable({}, { __mode = "k" }) :: any,
        Shared = setmetatable({}, { __mode = "k" }) :: any
    })

    -- Construct self
    local self: Record = Type.instance({
        -- Private data
        _mirrors = mirrors,
        _data = rootMirror,
        _raw = raw,
        
        -- Events
        Changed = changed
    }, methods)

    -- Setup metatable
    setmetatable(self, {
        _typeMethods = methods,
        __index = function(_, key: any): any?
            local method = methods[key]
            if method ~= nil then
                return method
            end
            return rootMirror[key]
        end,
        __newindex = function(_, key: any, value: any?): ()
            rootMirror[key] = value
        end,
        __len = function(): number
            return #raw
        end,
        __iter = function(this: any): ...any
            if this ~= self then
                return next, this -- A copy (e.g. from table.clone), so only its own fields
            end
            return iterate(raw, rootMirror)
        end
    })

    return self :: any
end) ::
    (<T>(template: T, data: any?) -> Record<T>) &
    (<T>(template: any, data: any?, methods: T) -> T)

return Type.class(RecordClass, RecordMethods)