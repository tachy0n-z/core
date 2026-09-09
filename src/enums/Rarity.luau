
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Enum = require(ReplicatedStorage.Shared.Types.Core.Enum)

return Enum.new(script.Name, {
    Common = 1,
    Uncommon = 2,
    Rare = 3,
    Mystical = 4
}, {
    -- Data
    Colours = {
        Common = Color3.fromRGB(255, 255, 255),
        Uncommon = Color3.fromRGB(0, 255, 0),
        Rare = Color3.fromRGB(0, 0, 255),
        Mystical = Color3.fromRGB(255, 0, 255)
    } :: {[number]: Color3},

    -- Methods
    GetColour = function(self: any, rarity: number): Color3
        local name = self:GetName(rarity)
        return name and self.Colours[name] or Color3.fromRGB(255, 255, 255)
    end
})