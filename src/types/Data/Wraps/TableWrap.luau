
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- References
local Types = script:FindFirstAncestor("Types")

-- Modules
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Signal = require(Types.Core.Signal)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Type = require(Types.Core.Type)

-- A reactive table wrapper.
export type TableWrap<K = any, V = any> = Type.Type<{
    -- Private data
    _table: {[K]: V},
    
    -- Events
    Changed: Signal.Signal<K, V?, V?, any?>,
    Added: Signal.Signal<K, V, any?>,
    Removed: Signal.Signal<K, V, any?>,

    -- Helper methods
    Reconcile: (self: TableWrap<K, V>, other: {[K]: V}, context: any?) -> (),
    ForEach: (self: TableWrap<K, V>, callback: (K, V) -> ()) -> (),
    Exists: (self: TableWrap<K, V>, key: K) -> boolean,
    Keys: (self: TableWrap<K, V>) -> {K},
    Values: (self: TableWrap<K, V>) -> {V},

    -- Methods
    All: (self: TableWrap<K, V>) -> {[K]: V},
    Get:
        ((self: TableWrap<K, V>, key: K) -> V?) &
        ((self: TableWrap<K, V>, key: K, default: V) -> V),
    Set: (self: TableWrap<K, V>, key: K, value: V?, context: any?) -> (),
}>
local TableWrapMethods = Type.methods("TableWrap", {} :: TableWrap)

function TableWrapMethods.Reconcile(self: TableWrap, other: {[any]: any}, context: any?): ()
    for k, v in pairs(other) do
        self:Set(k, v, context)
    end
    for k in pairs(TableUtil.Copy(self._table)) do
        if other[k] == nil then
            self:Set(k, nil, context)
        end
    end
end

function TableWrapMethods.ForEach(self: TableWrap, callback: (any, any) -> ()): ()
    for key, value in pairs(self._table) do
        callback(key, value)
    end
end

function TableWrapMethods.Exists(self: TableWrap, key: any): boolean
    return self._table[key] ~= nil
end

function TableWrapMethods.Keys(self: TableWrap): {any}
    return TableUtil.Keys(self._table)
end

function TableWrapMethods.Values(self: TableWrap): {any}
    return TableUtil.Values(self._table)
end

function TableWrapMethods.All(self: TableWrap): {[any]: any}
    return TableUtil.Copy(self._table)
end

function TableWrapMethods.Get(self: TableWrap, key: any, default: any?): any
    local value = self._table[key]
    if value == nil then
        return default
    else
        return value
    end
end

function TableWrapMethods.Set(self: TableWrap, key: any, value: any?, context: any?): ()
    local old = self._table[key]
    if old == value then
        return
    end
    self._table[key] = value
    if value == nil then
        self.Removed:Fire(key, old, context)
    elseif old == nil then
        self.Added:Fire(key, value, context)
    end
    self.Changed:Fire(key, value, old, context)
end

function TableWrapMethods._destroy(self: TableWrap): ()
    self.Changed:Destroy()
    self.Added:Destroy()
    self.Removed:Destroy()
end

local TableWrapClass = {}

TableWrapClass.new = (function(initial: {[any]: any}?): TableWrap
    local self = {
        _table = initial or {},
        Changed = Signal.new(),
        Added = Signal.new(),
        Removed = Signal.new(),
    }
    return Type.instance(self, TableWrapMethods)
end) ::
    (() -> TableWrap) &
    (<K, V>(initial: {[K]: V}) -> TableWrap<K, V>)

function TableWrapClass.bindTable(source: any, key: any): TableWrap
    if typeof(source) ~= "table" then
        return Pretty.Error("invalid source, expected a table",
            script, "bindTable")
    end
    
    -- Find or create table
    local tbl = source[key] or {}
    if typeof(tbl) ~= "table" then
        return Pretty.Error("invalid source[key], expected a table",
            script, "bindTable")
    end
    source[key] = tbl -- Ensure a table is present

    -- Construct and return
    return TableWrapClass.new(tbl)
end

function TableWrapClass.bindAttributes(instance: Instance): (TableWrap, Signal.Connection)
    local wrap = TableWrapClass.new(instance:GetAttributes())
    return wrap, wrap.Changed:Connect(function(key: any, new: any?, old: any?): ()
        if new == nil then
            instance:SetAttribute(tostring(key), nil)
        else
            instance:SetAttribute(tostring(key), new)
        end
    end)
end

return Type.class(TableWrapClass, TableWrapMethods)