
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- References
local Types = script:FindFirstAncestor("Types")
local _Enum = Enum

-- Modules
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Type = require(Types.Core.Type)
local Enum = require(Types.Core.Enum)

-- Passes
local f = table.freeze

type Value = {
    TypeName: string,
    Nullable: boolean,
    Default: (any | (() -> any))?,
    Validator: ((any) -> boolean)?
}

type Processors = {
    [{
        Table: any,
        Key: any
    }]: ((any) -> any)
}

export type DefinitionSubClass<T = {}, M = {}> = {
    -- Data
    Methods: M,
    Template: T,

    -- Methods
    new: (data: T) -> M?
}

local DefinitionClass = {}

function DefinitionClass.newValueFactory<T>(witness: T): (() -> T) & ((T) -> T?) & ((nil) -> T?)
    return function(...: any): any
        local args = {...}
        local count = select("#", ...)
        local default = count > 0 and args[1] or nil
        return f{
            TypeName = typeof(witness),
            Nullable = count > 0 and args[1] == nil,
            Default = default ~= nil and function(): T
                if typeof(default) == "table" then
                    return TableUtil.Copy(default)
                else
                    return default
                end
            end or nil
        }
    end
end

-- Primitives
DefinitionClass.String = DefinitionClass.newValueFactory("")
DefinitionClass.Number = DefinitionClass.newValueFactory(0)
DefinitionClass.Boolean = DefinitionClass.newValueFactory(false)
DefinitionClass.Table = DefinitionClass.newValueFactory({})
DefinitionClass.Vector2 = DefinitionClass.newValueFactory(Vector2.zero)
DefinitionClass.Vector3 = DefinitionClass.newValueFactory(Vector3.zero)
DefinitionClass.CFrame = DefinitionClass.newValueFactory(CFrame.identity)
DefinitionClass.Color3 = DefinitionClass.newValueFactory(Color3.fromRGB(0, 0, 0))
DefinitionClass.Ray = DefinitionClass.newValueFactory(Ray.new(Vector3.zero, Vector3.zero))
DefinitionClass.UDim = DefinitionClass.newValueFactory(UDim.new(0, 0))
DefinitionClass.UDim2 = DefinitionClass.newValueFactory(UDim2.new(0, 0, 0, 0))
DefinitionClass.Rect = DefinitionClass.newValueFactory(Rect.new(0, 0, 0, 0))
DefinitionClass.NumberRange = DefinitionClass.newValueFactory(NumberRange.new(0, 0))
DefinitionClass.NumberSequence = DefinitionClass.newValueFactory(NumberSequence.new(0))
DefinitionClass.ColorSequence = DefinitionClass.newValueFactory(ColorSequence.new(Color3.fromRGB(0, 0, 0)))
DefinitionClass.PhysicalProperties = DefinitionClass.newValueFactory(PhysicalProperties.new(1, 1, 1))
DefinitionClass.Axes = DefinitionClass.newValueFactory(Axes.new())
DefinitionClass.BrickColor = DefinitionClass.newValueFactory(BrickColor.new("White"))
DefinitionClass.Faces = DefinitionClass.newValueFactory(Faces.new())
DefinitionClass.Vector3int16 = DefinitionClass.newValueFactory(Vector3int16.new(0, 0, 0))
DefinitionClass.Region3 = DefinitionClass.newValueFactory(Region3.new(Vector3.zero, Vector3.zero))
DefinitionClass.Region3int16 = DefinitionClass.newValueFactory(Region3int16.new(Vector3int16.new(0, 0, 0), Vector3int16.new(0, 0, 0)))
DefinitionClass.DateTime = DefinitionClass.newValueFactory(DateTime.now())
DefinitionClass.Font = DefinitionClass.newValueFactory(Font.fromEnum(_Enum.Font.SourceSans))
DefinitionClass.RaycastParams = DefinitionClass.newValueFactory(RaycastParams.new())
DefinitionClass.OverlapParams = DefinitionClass.newValueFactory(OverlapParams.new())
DefinitionClass.TweenInfo = DefinitionClass.newValueFactory(TweenInfo.new())

-- Custom
DefinitionClass.Instance = (function(...: any): any
    local args = {...}
    local count = select("#", ...)
    return f{
        TypeName = "Instance",
        Nullable = count > 0 and args[1] == nil,
        Default = args[1] ~= nil and function(): Instance
            return args[1]:Clone()
        end,
        Validator = function(value: any): boolean
            local v = args[1]
            if typeof(v) == "Instance" then
                return value:IsA(v.ClassName)
            else
                return typeof(value) == "Instance"
            end
        end
    }
end) ::
    (() -> Instance) &
    (<T>(Instance & T) -> (Instance & T)?) &
    ((nil) -> Instance?)
DefinitionClass.CustomType = (function<T>(...: any): any
    local args = {...}
    local count = select("#", ...)
    return f{
        TypeName = "table",
        Nullable = count > 1 and args[2] == nil,
        Default = count > 1 and args[2] ~= nil and function(): T
            local origin = args[2]
            return origin:IsCopyable()
                and origin:Copy(true)
                or origin
        end,
        Validator = function(value: any): boolean
            return
                Type.Is(value) and
                value:IsA(args[1]:GetTypeName())
        end
    }
end) ::
    (<T>(methods: T) -> T) &
    (<T>(methods: T, default: T) -> T?) &
    (<T>(methods: T, default: nil) -> T?)
DefinitionClass.CustomEnum = (function(...: any): any
    local args = {...}
    local count = select("#", ...)
    return f{
        TypeName = "number",
        Nullable = count > 1 and args[2] == nil,
        Default = args[2],
        Validator = function(value: any): boolean
            return typeof(value) == "number" and args[1]:GetName(value) ~= nil
        end
    }
end) ::
    ((enum: Enum.Enum<any>) -> number) &
    ((enum: Enum.Enum<any>, default: number) -> number?) &
    ((enum: Enum.Enum<any>, default: nil) -> number?)
DefinitionClass.EnumItem = (function(...: any): any
    local args = {...}
    local count = select("#", ...)
    return f{
        TypeName = "EnumItem",
        Nullable = count > 1 and args[2] == nil,
        Default = args[2],
        Validator = function(value: any): boolean
            return typeof(value) == "EnumItem" and
                TableUtil.Find(args[1]:GetEnumItems(), function(v): boolean
                    return v == value
                end) ~= nil
        end
    }
end) ::
    ((enum: Enum) -> EnumItem) &
    ((enum: Enum, default: EnumItem) -> EnumItem?) &
    ((enum: Enum, default: nil) -> EnumItem?)

function DefinitionClass.Processor<T>(fn: (any) -> T): nil
    return fn :: any
end

-- Helpers
function DefinitionClass.SetDefault<T>(value: T, default: any): T
    if typeof(value) ~= "table" or typeof(value.TypeName) ~= "string" then
        return Pretty.Error("expected a Value shape for value",
            script, "SetDefault")
    end
    return f(TableUtil.Assign(value, {
        Default = default
    })) :: any
end

-- Turns the given data into a viable object based on the given template.
-- Returns the object if successful, or nil if the data is invalid.
function DefinitionClass.construct(data: any, template: any): (any?, Processors?)
    if typeof(data) ~= "table" or typeof(template) ~= "table" then
        return nil
    end

    -- Processors run last
    local processors: {[{ 
        Table: any,
        Key: any
    }]: (any) -> any} = {}

    for key, value in pairs(template) do
        -- If it is a processor, defer
        if typeof(value) == "function" then
            processors[{
                Table = data,
                Key = key
            }] = value
            continue
        end

        -- Get target data value, check if nested
        local dataValue = data[key]
        if typeof(value) ~= "table" then
            return nil
        elseif typeof(value.TypeName) ~= "string" then -- Assume it's a nested template
            if typeof(dataValue) ~= "table" then
                return nil
            end
            local nested, nestedProcessors = DefinitionClass.construct(dataValue, value)
            if nested == nil then
                return nil
            else
                data[key] = nested -- Just in case
            end
            if nestedProcessors then
                for path, processor in pairs(nestedProcessors) do
                    processors[path] = processor
                end
            end
            continue
        end

        -- Default if nil
        if dataValue == nil then
            if value.Nullable then
                data[key] = nil
                continue
            elseif value.Default ~= nil then
                local default: any
                if typeof(value.Default) == "function" then
                    default = value.Default()
                else
                    default = value.Default
                end
                data[key] = default
                dataValue = data[key]
            else
                return nil
            end
        end

        -- Check against type
        if typeof(dataValue) ~= value.TypeName and value.TypeName ~= "any" then
            return nil
        end

        -- Check against validator
        if value.Validator and not value.Validator(dataValue) then
            return nil
        end
    end

    return data, processors
end

-- Creates a new Definition subclass with the given template and methods.
function DefinitionClass.new<T, M>(template: T, methods: M): DefinitionSubClass<T, M>
    if typeof(template) ~= "table" or typeof(methods) ~= "table" then
        return Pretty.Error(`expects a table for both template and methods, got {typeof(template)} and {typeof(methods)}`,
            script, "new")
    elseif not Type.IsMethods(methods) then
        return Pretty.Error(`expected a valid Type methods object`,
            script, "new")
    end
    return Type.class({
        Template = template,
        new = function(data: T): M?
            local constructed, processors = DefinitionClass.construct(data, template)
            if not constructed then
                return nil
            end
            constructed = Type.instance(constructed, methods)
            if processors then
                for path, processor in pairs(processors) do
                    path.Table[path.Key] = processor(constructed)
                end
            end
            return constructed
        end
    }, methods)
end

return f(DefinitionClass)