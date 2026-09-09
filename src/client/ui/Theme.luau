
-- Passes
local f = table.freeze

return f{
    -- Scales
    CornerRadius = f{
        Small = UDim.new(0, 4),
        Medium = UDim.new(0, 6),
        Large = UDim.new(0, 8)
    },
    Spacing = f{
        ExtraSmall = 6,
        Small = 10,
        Medium = 14,
        Large = 20,
        ExtraLarge = 28
    },

    -- Visual
    Font = Enum.Font.SourceSans,
    Images = f{
        Icons = f{},
        Gradients = f{
            Glow = "rbxassetid://11953711609",
            GlowHeavy = "rbxassetid://15488281448",
            GlowDropdown = "rbxassetid://11953710574"
        },
        Graphics = f{
            SunburstL1 = "rbxassetid://11953710131",
            SunburstL2 = "rbxassetid://11953709957",
            SunburstL3 = "rbxassetid://11953709721",
            SunburstL4 = "rbxassetid://11953709496",
            SunburstL5 = "rbxassetid://11953709233"
        },
        Patterns = f{
            DiagonalStripes = "rbxassetid://111377288701910",
            Checkers = "rbxassetid://134185142380635",
            Connections = "rbxassetid://109917688667129",
            Studs = "rbxassetid://94773813860657"
        }
    },

    -- Effects
    Sounds = f{}
}