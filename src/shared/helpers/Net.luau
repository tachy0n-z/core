
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Modules
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)

-- Passes
local f = table.freeze

local function find(name: string, parent: Instance, className: string): Instance?
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA(className) and child.Name == name then
            return child
        end
    end
    return nil
end

local function findOrCreate(name: string, parent: Instance?, className: string): Instance
    local parent = parent or script
    local instance = find(name, parent, className)
    if instance ~= nil then
        return instance
    elseif RunService:IsStudio() and not RunService:IsRunning() then
        return Instance.new(className, nil) -- GC
    elseif RunService:IsServer() then
        local newInstance = Instance.new(className)
        newInstance.Name = name
        newInstance.Parent = parent
        return newInstance
    end
    task.delay(5, function(): ()
        if instance == nil then
            Pretty.Warn(`infinite yield possible waiting for {className} '{name}' in '{parent:GetFullName()}'`,
                script, "findOrCreate")
        end
    end)
    while instance == nil do
        parent.ChildAdded:Wait()
        instance = find(name, parent, className)
    end
    return instance :: Instance
end

local Net = {}

function Net.RemoteEvent(name: string, parent: Instance?): RemoteEvent
    return findOrCreate(name, parent, "RemoteEvent") :: RemoteEvent
end

function Net.UnreliableRemoteEvent(name: string, parent: Instance?): UnreliableRemoteEvent
    return findOrCreate(name, parent, "UnreliableRemoteEvent") :: UnreliableRemoteEvent
end

function Net.RemoteFunction(name: string, parent: Instance?): RemoteFunction
    return findOrCreate(name, parent, "RemoteFunction") :: RemoteFunction
end

return f(Net)