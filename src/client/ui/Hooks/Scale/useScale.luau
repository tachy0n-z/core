
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local React = require(ReplicatedStorage.Packages.React)

-- Contexts
local ScaleContext = require(ReplicatedStorage.Client.UI.Providers.Scale.ScaleContext)

return function(): ScaleContext.ScaleContextValue
    local scale = React.useContext(ScaleContext)
    if scale == nil then
        return Pretty.Error(`can only be used inside a ScaleProvider`,
            script)
    end
    return scale
end