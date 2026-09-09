
-- Services
local RunService = game:GetService("RunService")

-- Passes
local f = table.freeze

local function findOrCreate(name: string, parent: Instance?, className: string): Instance
    local parent = parent or script
    local instance: Instance? = nil
    for _, child in ipairs(parent:GetChildren()) do
        if child:IsA(className) and child.Name == name then
            instance = child
            break
        end
    end
    if instance ~= nil then
        return instance
    elseif RunService:IsStudio() and not RunService:IsRunning() then
        return Instance.new(className, nil) -- GC
    elseif RunService:IsServer() then
        local newInstance = Instance.new(className, parent)
        newInstance.Name = name
        return newInstance
    else
        return parent:WaitForChild(name)
    end
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