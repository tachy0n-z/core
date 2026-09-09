
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- References
local Types = script:FindFirstAncestor("Types")

-- Modules
local SessionDataTemplate = require(ReplicatedStorage.Config.SessionDataTemplate)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Signal = require(Types.Core.Signal)
local Record = require(Types.Data.Record)
local Type = require(Types.Core.Type)

-- Passes
local f = table.freeze

-- Constants
local PATH_SEPARATOR = "/"
local ALLOWED_TYPES = f{
    ["string"] = true,
    ["boolean"] = true,
    ["number"] = true,
    ["BrickColor"] = true,
    ["CFrame"] = true,
    ["Color3"] = true,
    ["ColorSequence"] = true,
    ["NumberRange"] = true,
    ["NumberSequence"] = true,
    ["Rect"] = true,
    ["UDim"] = true,
    ["UDim2"] = true,
    ["Vector2"] = true,
    ["Vector3"] = true,
    ["nil"] = true
}

export type SessionDataRecord = Record.Record<typeof(SessionDataTemplate)> & {
    -- Public data
    BlockPrefix: string?,

    -- Attribute methods
    IsBlockedPath: (self: SessionDataRecord, path: {any} | string) -> boolean,
    ConstructAttribute: (self: SessionDataRecord, path: {any}) -> string,
    ParseAttribute: (self: SessionDataRecord, attribute: string) -> {any},

    -- Reflection methods
    ReflectTo: (self: SessionDataRecord, instance: Instance) -> Signal.Connection,
    ReflectFrom: (self: SessionDataRecord, instance: Instance) -> RBXScriptConnection
}
local SessionDataRecordMethods = Type.methods("SessionDataRecord", {} :: SessionDataRecord, Record.Methods)

-- Returns true if replication should not take place for the given path.
function SessionDataRecordMethods.IsBlockedPath(self: SessionDataRecord, path: {any} | string): boolean
    if self.BlockPrefix == nil then
        return false
    end
    local complete: {any}
    if typeof(path) == "string" then
        complete = self:ParseAttribute(path)
    else
        complete = path
    end
    for _, field in ipairs(complete) do
        if tostring(field):sub(1, #self.BlockPrefix) == self.BlockPrefix then
            return true
        end
    end
    return false
end

-- Constructs a path string from the given table of keys and value.
function SessionDataRecordMethods.ConstructAttribute(self: SessionDataRecord, path: {any}): string
    local new = {}
    for _, key in ipairs(path) do
        table.insert(new, tostring(key))
    end
    return table.concat(new, PATH_SEPARATOR)
end

-- Parses the given path string into a table of keys and a boolean indicating whether the path is for a table value.
function SessionDataRecordMethods.ParseAttribute(self: SessionDataRecord, attribute: string): {any}
    local path = {}
    for _, key in ipairs(attribute:split(PATH_SEPARATOR)) do
        table.insert(path, tonumber(key) or key)
    end
    return path
end

-- Reflects the current values and any future changes to this record the given instance via attributes.
function SessionDataRecordMethods.ReflectTo(self: SessionDataRecord, instance: Instance): Signal.Connection
    local function apply(path: {any}, value: any): ()
        if self:IsBlockedPath(path) then
            return
        end
        if typeof(value) == "table" then
            for key, subValue in pairs(self:Unwrap(value)) do
                apply(TableUtil.Extend(path, { key }), subValue)
            end
        elseif ALLOWED_TYPES[typeof(value)] then
            local attribute = self:ConstructAttribute(path)
            instance:SetAttribute(attribute, value)
        else
            Pretty.Debug(`skipping key of type '{typeof(value)}' for '{instance:GetFullName()}' (incompatible with attributes)`,
                script, "ReflectTo")
        end
    end
    apply({}, self)
    return self.Changed:Connect(function(path: {any}, value: any?): ()
        if self:IsBlockedPath(path) then
            return
        end
        if not ALLOWED_TYPES[typeof(value)] then
            Pretty.Debug(`skipping key of type '{typeof(value)}' for '{instance:GetFullName()}' (incompatible with attributes)`,
                script, "ReflectTo")
            return
        end
        instance:SetAttribute(self:ConstructAttribute(path), value)
    end)
end

-- Reflects the current values and any future changes from the given instance to this record via attributes.
function SessionDataRecordMethods.ReflectFrom(self: SessionDataRecord, instance: Instance): RBXScriptConnection
    for path, value in pairs(instance:GetAttributes()) do
        if self:IsBlockedPath(path) then
            continue
        end
        self:Apply(self:ParseAttribute(path), value)
    end
    return instance.AttributeChanged:Connect(function(name: string): ()
        if self:IsBlockedPath(name) then
            return
        end
        local path = self:ParseAttribute(name)
        local value = instance:GetAttribute(name)
        self:Apply(path, value)
    end)
end

local SessionDataRecordClass = {}

function SessionDataRecordClass.new(data: any?, blockPrefix: string?): SessionDataRecord
    local record: any = Record.new(SessionDataTemplate, data, SessionDataRecordMethods)
    if blockPrefix then
        rawset(record, "BlockPrefix", blockPrefix)
    end
    return record
end

return Type.class(SessionDataRecordClass, SessionDataRecordMethods)