
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Connect = require(ReplicatedStorage.Shared.Helpers.Connect)

-- Passes
local f = table.freeze

local Tree = {}

-- Evaluates the given path string relative to the given Instance.
-- If no instance is provided, it defaults to `game`.
function Tree.ResolvePath(path: string, instance: Instance?): Instance?
    local current = instance or game
    if not path or path == "" then
        return current
    end
    for segment in string.gmatch(path, "[^%.]+") do
        current = current:FindFirstChild(segment)
        if not current then
            return nil
        end
    end
    return current
end

-- Returns a list of all descendants of the given Instance, regardless of whether the class supports it natively.
function Tree.GetDescendants(instance: Instance): {Instance}
    local success, result = pcall(instance.GetDescendants, instance)
    if success and result ~= nil then
        return result
    end
    local descendants: {Instance} = {}
    local function delve(current: Instance): ()
        for _, child in ipairs(current:GetChildren()) do
            table.insert(descendants, child)
            delve(child)
        end
    end
    delve(instance)
    return descendants
end

-- Finds the first descendant of the given Instance that returns true with the given callback.
function Tree.FindFirstDescendant(instance: Instance, callback: (Instance) -> boolean): Instance?
    local descendants = Tree.GetDescendants(instance)
    for _, descendant in ipairs(descendants) do
        if callback(descendant) then
            return descendant
        end
    end
    return nil
end

-- Waits for a descendant of the given Instance that returns true with the given callback, up to an optional timeout (defaults to inf).
Tree.WaitForDescendant = (function(parent: Instance, callback: (Instance) -> boolean, wait: number?): Instance?
    return Connect.Wait(Tree.FindFirstDescendant(parent, callback), parent.DescendantAdded, callback, wait)
end) ::
    ((parent: Instance, callback: (Instance) -> boolean) -> Instance) &
    ((parent: Instance, callback: (Instance) -> boolean, wait: number) -> Instance?)

-- Finds the first ancestor of the given Instance that returns true with the given callback.
function Tree.FindFirstAncestor(instance: Instance, callback: (Instance) -> boolean): Instance?
    local current = instance.Parent
    while current do
        if callback(current) then
            return current
        end
        current = current.Parent
    end
    return nil
end

return f(Tree)