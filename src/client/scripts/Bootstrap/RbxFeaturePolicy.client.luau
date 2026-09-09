
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- Modules
local Satchel = require(ReplicatedStorage.Packages.Satchel)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)

-- Passes
local f = table.freeze

-- Constants
local TOGGLES = f{
    [Enum.CoreGuiType.Backpack] = false
}

-- Attempt to toggle
for coreGuiType, enabled in pairs(TOGGLES) do
    local success, err: string? = pcall(function(): ()
        StarterGui:SetCoreGuiEnabled(coreGuiType, enabled)
    end)
    if not success then
        Pretty.Warn(`failed to toggle '{coreGuiType.Name}' to {enabled}: {err}`,
            script)
    end
end

-- Finally, enable Satchel
Satchel:SetBackpackEnabled(true)
