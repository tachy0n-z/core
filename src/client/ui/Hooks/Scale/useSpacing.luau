
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Contexts
local ScaleContext = require(ReplicatedStorage.Client.UI.Providers.Scale.ScaleContext)

-- Hooks
local useScale = require(ReplicatedStorage.Client.UI.Hooks.Scale.useScale)

return (function(token: ScaleContext.ScaleToken, px: boolean?): any
    local scale = useScale()
    if px then
        return scale.getSpacingPx(token)
    else
        return scale.getSpacingUDim(token)
    end
end) ::
    ((token: ScaleContext.ScaleToken) -> UDim) &
    ((token: ScaleContext.ScaleToken, px: true) -> number)