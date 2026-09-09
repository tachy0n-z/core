
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- References
local Types = script:FindFirstAncestor("Types")

-- Modules
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Signal = require(Types.Core.Signal)
local Type = require(Types.Core.Type)

-- Constants
local LINK_FLAG = "AttributeLink"

-- A reactive value wrapper that allows for easy value tracking and change detection.
export type ValueWrap<T = any> = Type.Type<{
    -- Private data
    _value: T,

    -- Events
    Changed: Signal.Signal<T, T, any?>,

    -- Helper methods
    Equals: (self: ValueWrap<T>, other: any) -> boolean,
    Add: (self: ValueWrap<T>, other: any, context: any?) -> (),
    Subtract: (self: ValueWrap<T>, other: any, context: any?) -> (),

    -- Methods
    Get: (self: ValueWrap<T>) -> T,
    Set: (self: ValueWrap<T>, value: T, context: any?) -> ()
}>
local ValueWrapMethods = Type.methods("ValueWrap", {} :: ValueWrap)

function ValueWrapMethods.Equals(self: ValueWrap, other: any): boolean
    return self._value == other
end

function ValueWrapMethods.Add(self: ValueWrap, other: any, context: any?): ()
    if typeof(self._value) ~= "number" or typeof(other) ~= "number" then
        return Pretty.Error("attempt to add non-number values",
            nil, `{self._typeName}.Add`)
    end
    self:Set(self._value + other, context)
end

function ValueWrapMethods.Subtract(self: ValueWrap, other: any, context: any?): ()
    if typeof(self._value) ~= "number" or typeof(other) ~= "number" then
        return Pretty.Error("attempt to subtract non-number values",
            nil, `{self._typeName}.Subtract`)
    end
    self:Set(self._value - other, context)
end

function ValueWrapMethods.Get(self: ValueWrap): any
    return self._value
end

function ValueWrapMethods.Set(self: ValueWrap, value: any, context: any?): ()
    if self._value == value then
        return
    end
    local old = self._value
    self._value = value
    self.Changed:Fire(self._value, old, context)
end

function ValueWrapMethods._destroy(self: ValueWrap): ()
    self.Changed:Destroy()
end

local ValueWrapClass = {}

function ValueWrapClass.new<T>(value: T): ValueWrap<T>
    local self = {
        -- Private data
        _value = value,

        -- Events
        Changed = Signal.new()
    }
    return Type.instance(self, ValueWrapMethods)
end

function ValueWrapClass.bindTable(source: any, key: any): (ValueWrap, Signal.Connection)
    if typeof(source) ~= "table" and typeof(source) ~= "Instance" then
        return Pretty.Error("invalid source, expected a table-like object",
            script, "bindTable")
    end
    local wrap = ValueWrapClass.new((source :: any)[key])
    return wrap, wrap.Changed:Connect(function(new): ()
        (source :: any)[key] = new
    end)
end

function ValueWrapClass.bindAttribute(instance: Instance, key: string): (ValueWrap, Signal.Connection)
    local wrap = ValueWrapClass.new(instance:GetAttribute(key))
    return wrap, wrap.Changed:Connect(function(new: any): ()
        instance:SetAttribute(key, new)
    end)
end

function ValueWrapClass.linkAttribute(
    instance: Instance,
    key: string,
    now: any?,
    serialise: ((any) -> any?)?,
    deserialise: ((any) -> any?)?
): (ValueWrap, {Signal.Connection | RBXScriptConnection})
    -- Normalise methods
    local serialise: any = serialise or function(value: any): any?
        return value
    end
    local deserialise: any = deserialise or function(value: any): any?
        return value
    end

    -- Create wrap
    local wrap = ValueWrapClass.new(
        if now == nil then deserialise(instance:GetAttribute(key)) else now
    )
    if now ~= nil then
        instance:SetAttribute(key, serialise(now))
    end

    local conns: {any} = {
        wrap.Changed:Connect(function(new: any?, old: any?, flag: any?)
            if flag == LINK_FLAG then
                return
            end
            instance:SetAttribute(key, serialise(new))
        end),
        instance:GetAttributeChangedSignal(key):Connect(function(): ()
            wrap:Set(deserialise(instance:GetAttribute(key)), LINK_FLAG)
        end)
    }

    return wrap, conns
end

function ValueWrapClass.bindProperty(instance: Instance, key: string): (ValueWrap, Signal.Connection)
    local success = pcall(function(): ()
        local instance: any = instance -- Loosen typing
        local value = instance[key]
        instance[key] = value -- Test if property is writable
    end)
    if not success then
        return Pretty.Error(`invalid property '{key}' for instance of type '{instance.ClassName}'`,
            script, "bindProperty")
    end
    return ValueWrapClass.bindTable(instance, key)
end

return Type.class(ValueWrapClass, ValueWrapMethods)