
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- References
local Types = script:FindFirstAncestor("Types")

-- Modules
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Type = require(Types.Core.Type)

-- Passes
local f = table.freeze

-- A custom Enum type that supports any value types and a nice API.
-- Members are stored directly on the enum table. Can hold extra data or methods.
export type Enum<M = {}, T = {}> = Type.Type<M & T & {
    -- Private data
    _members: M,
    _names: {string},
    _values: {number},

    -- Public data
    Name: string,

    -- Helper methods
    All: (self: Enum<M, T>) -> M,
    Names: (self: Enum<M, T>) -> {string},
    Values: (self: Enum<M, T>) -> {number},

    -- Check methods
    GetName: (self: Enum<M, T>, value: number) -> string?,
    GetValue: (self: Enum<M, T>, name: string) -> any?
}>
local EnumMethods = Type.methods("Enum", {} :: Enum)

function EnumMethods.All(self: Enum): any
    return self._members
end

function EnumMethods.Names(self: Enum): {string}
    return self._names
end

function EnumMethods.Values(self: Enum): {any}
    return self._values
end

function EnumMethods.GetName(self: Enum, value: any): string?
    local _, name = TableUtil.Find(self._members, function(otherValue): boolean
        return value == otherValue
    end)
    return name
end

function EnumMethods.GetValue(self: Enum, name: string): any?
    return self._members[name]
end

local EnumClass = {}

function EnumClass.new<M, T>(name: string, members: M, extra: T?): Enum<M, T>
    -- Copy, no shared
    local members = f(TableUtil.Copy(members :: any, true))
    local extra = extra and TableUtil.Copy(extra :: any, true) or nil

    -- Construct base enum
    local enum: any = setmetatable({
        -- Private data
        _names = f(TableUtil.Keys(members :: any)),
        _values = f(TableUtil.Values(members :: any)),
        _members = members,

        -- Public data
        Name = name
    }, { __index = extra or EnumMethods })

    -- If extra provided, setup EnumMethods for that
    if extra then
        setmetatable(extra :: any, { __index = EnumMethods })
    end

    -- Append members directly to enum
    for k, v in pairs(members :: any) do
        if enum[k] then
            return Pretty.Error(`for '{name}' failed because member name '{k}' is reserved`,
                script, "new")
        elseif typeof(v) ~= "number" then
            return Pretty.Error(`for '{name}' failed because member '{k}' has invalid value type '{typeof(v)}' (expected number)`,
                script, "new")
        else
            enum[k] = v
        end
    end

    return Type.instance(enum, nil)
end

return Type.class(EnumClass, EnumMethods)