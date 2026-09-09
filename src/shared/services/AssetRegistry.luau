
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Modules
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Types = require(ReplicatedStorage.Shared.Types)

-- Passes
local f = table.freeze

-- Constants
local STUDIO_INCOMPATIBLE = f{}

type AssetRegistry = Types.Service<{
    -- Libraries
    -- e.g. Items: Types.StaticLibrary<Types.ItemDef>,

    -- Methods
    Flat: (self: AssetRegistry) -> {[string]: Types.StaticLibrary<any>}
}>
local AssetRegistry: AssetRegistry = {
    -- Libraries
    -- e.g. Items = Types.Library.newStatic(require, ReplicatedStorage.Shared.Assets.Items)
} :: any

-- Iterates over self and returns a flat dictionary of all libraries.
function AssetRegistry:Flat(): {[string]: Types.StaticLibrary<any>}
    local all = {}
    local function delve(t: any): ()
        for k, v in pairs(t) do
            if all[k] ~= nil then
                Pretty.Warn(`duplicate key '{k}' found, unique keys are preferred, skipping`,
                    script, "Flat")
            elseif Types.Is(v) and v:IsA("Library") then
                all[k] = v
            elseif typeof(v) == "table" then
                delve(v)
            end
        end
    end
    delve(self)
    return all
end

function AssetRegistry._initialise(self: AssetRegistry)
    for key, lib in pairs(self:Flat()) do
        if
            (RunService:IsStudio() and not RunService:IsRunning()) and
            table.find(STUDIO_INCOMPATIBLE, key) ~= nil
        then
            Pretty.Debug(`library '{key}' is incompatible with Studio, skipping`,
                script, "_initialise")
            continue
        end
        if not lib:IsBound() then
            local last = lib:GetLastBound()
            if not last then
                Pretty.Warn(`a library was not bound and has no last bound value, skipping`,
                    script, "_initialise")
                continue
            end
            lib:Bind(last)
        end
        local count = lib:Populate()
        Pretty.Debug(`successfully populated '{key}' with {count} entries`,
            script, "_initialise")
    end
    return true
end

function AssetRegistry._cleanup(self: AssetRegistry): ()
    for _, lib in pairs(self:Flat()) do
        lib:Unbind()
    end
end

return Types.Service.new(script, AssetRegistry)