
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)

-- Passes
local f = table.freeze

-- The base Type object, which all other custom types have to derive from.
-- Provides basic type information and a simple inheritance system through metatables.
export type Type<T = {}> = T & {
    -- Private data
    _typeName: string,
    _destroyed: boolean,
    
    -- Events
    _destroying: BindableEvent,
    Destroying: RBXScriptSignal<()>,

    -- Type-defined methods
    _copy: ((self: any) -> any)?,
    _destroy: ((self: any) -> ())?,

    -- Typing methods
    GetTypeName: (self: Type<T>) -> string,
    GetLayer: (self: Type<T>, typeName: string) -> any?,
    IsA:
        ((self: Type<T>, typeName: string) -> boolean) &
        ((self: Type<T>, typeLayer: any) -> boolean),

    -- Object methods
    IsCopyable: (self: Type<T>) -> boolean,
    Copy:
        ((self: Type<T>) -> Type<T>?) &
        ((self: Type<T>, throwIfDisabled: true) -> Type<T>),
    IsDestroyed: (self: Type<T>) -> boolean,
    Destroy: (self: Type<T>) -> ()
}
local TypeMethods: Type = {
    _typeName = "Type" -- For IsA
} :: any

function TypeMethods.GetTypeName(self: Type): string
    return self._typeName
end

function TypeMethods.GetLayer(self: Type, typeName: string): any?
    if typeof(self) ~= "table" then
        return nil
    end
    local mt = getmetatable(self :: any)
    if mt == nil then
        return nil
    elseif typeof(mt.__index) == "function" then
        if typeof(mt._typeMethods) ~= "table" then
            Pretty.Debug(`metatable for '{self._typeName}' has __index function but no _typeMethods table`,
                nil, `{self._typeName}.GetLayer`)
            return nil
        else
            return mt._typeMethods._typeName == typeName
                and mt._typeMethods or mt._typeMethods:GetLayer(typeName)
        end
    else
        local mt = (getmetatable(self :: any) or {}).__index
        while mt do
            if mt._typeName == typeName then
                return mt
            end
            mt = getmetatable(mt)
            if typeof(mt) ~= "table" then
                break
            end
            mt = mt.__index
        end
    end
    return nil
end

function TypeMethods.IsA(self: Type, value: any): boolean
    local target: string
    if typeof(value) == "string" then
        target = value
    elseif typeof(value) ~= "table" then
        return false
    elseif typeof(value._typeName) == "string" then
        target = value._typeName
    elseif
        typeof(value.Methods) == "table" and
        typeof(value.Methods._typeName) == "string"
    then
        target = value.Methods._typeName
    else
        return false
    end
    return self:GetLayer(target) ~= nil
end

function TypeMethods.IsCopyable(self: Type): boolean
    return typeof(self._copy) == "function"
end

function TypeMethods.Copy(self: Type, throwIfDisabled: boolean?): any
    if self._copy then
        local success, result = pcall(self._copy, self)
        if not success then
            return Pretty.Error(`failed with error: {tostring(result)}`,
                nil, `{self._typeName}.Copy`)
        elseif
            typeof(result) ~= "table" or
            not TypeMethods.IsA(result, self._typeName) or
            TypeMethods.GetTypeName(result) ~= self._typeName
        then
            return Pretty.Error(`failed to copy type '{self._typeName}', got invalid result`,
                nil, `{self._typeName}.Copy`)
        else
            return result
        end
    else
        local fn: any = throwIfDisabled and Pretty.Error or Pretty.Warn
        return fn(`type '{self._typeName}' does not support copying`,
            nil, `{self._typeName}.Copy`)
    end
end

function TypeMethods.IsDestroyed(self: Type): boolean
    return self._destroyed == true
end

function TypeMethods.Destroy(self: Type): ()
    if self:IsDestroyed() then
        return
    else
        self._destroyed = true
        self._destroying:Fire()
    end

    -- Use type-specific _destroy
    if self._destroy then
        local success, err: string? = pcall(self._destroy, self)
        if not success then
            Pretty.Warn(`failed with error: {tostring(err)}`,
                nil, `{self._typeName}.Destroy`)
        end
    end

    -- Final delete
    self._destroying:Destroy()
end

local TypeClass = {
    Methods = f(TypeMethods)
}

-- Returns true if the given object is a Type methods table.
function TypeClass.IsMethods(obj: any): boolean
    return
        typeof(obj) == "table" and
        typeof(rawget(obj, "_typeName")) == "string"
end

-- Returns true if the given object is a Type class.
function TypeClass.IsClass(obj: any): boolean
    return
        typeof(obj) == "table" and
        typeof(rawget(obj, "Methods")) == "table" and
        TypeClass.IsMethods(obj.Methods)
end

-- Returns true if the given object is a Type instance.
function TypeClass.Is(obj: any): boolean
    return
        typeof(obj) == "table" and
        TypeMethods.GetLayer(obj, "Type") ~= nil
end

-- Sets the given table's next metatable link to the TypeMethods table.
function TypeClass.methods<T>(typeName: string, from: T, inherit: any?): Type<T>
    if typeof(from) ~= "table" then
        return Pretty.Error("expected table for type methods creation, got " .. typeof(from),
            script, "methods")
    end

    from._typeName = typeName
    if inherit then
        if typeof(inherit) ~= "table" or not inherit._typeName then
            return Pretty.Error("failed due to invalid inheritance table (expected type methods)",
                script, "methods")
        end
        setmetatable(from :: any, { __index = inherit })
    else
        setmetatable(from :: any, { __index = TypeMethods })
    end

    return from :: Type<T>
end

-- Creates a new class for the given methods table.
-- It is the caller's responsibility to install constructors.
function TypeClass.class<C, T>(class: C, methods: T): C & { Methods: T }
    if typeof(class) ~= "table" then
        return Pretty.Error(`expected table for class creation, got {typeof(class)}`,
            script, "class")
    elseif typeof(methods) ~= "table" then
        return Pretty.Error(`expected table for methods, got {typeof(methods)}`,
            script, "class")
    elseif table.isfrozen(methods) then
        return Pretty.Error("methods table is already frozen, cannot create class",
            script, "class")
    end
    return f(TableUtil.Assign(class, { Methods = f(methods) })) :: any
end

-- Appends the essential Type fields to the given table and returns it.
function TypeClass.instance<T>(from: any, methods: T?): T
    if typeof(from) ~= "table" then
        return Pretty.Error(`expected table for type instance setup, got {typeof(from)}`,
            script, "instance")
    elseif (TypeClass.Is(from) and typeof(from._destroying) ~= "nil") then
        return from -- Already a Type instance, return as is
    end
    
    -- Append destroy event directly to table
    local destroying = Instance.new("BindableEvent")
    from._destroyed = false
    from._destroying = destroying
    from.Destroying = destroying.Event

    -- Add mt
    if methods then
        if
            typeof(methods) ~= "table" or
            not TypeMethods.IsA(methods, "Type")
        then
            return Pretty.Error("failed due to invalid methods table (should inherit from Type)",
                script, "instance")
        end
        setmetatable(from :: any, { __index = methods })
    else
        -- Assume the type is handling it
    end

    return from
end

return f(TypeClass)