
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Modules
local Connect = require(ReplicatedStorage.Shared.Helpers.Connect)
local Theme = require(ReplicatedStorage.Client.UI.Theme)
local React = require(ReplicatedStorage.Packages.React)

-- Contexts
local ScaleContext = require(ReplicatedStorage.Client.UI.Providers.Scale.ScaleContext)

-- Passes
local e = React.createElement
local f = table.freeze

-- Constants
local BASE_SIZE = Vector2.new(1920, 1080)
local SPACINGS: {[ScaleContext.ScaleToken]: number} = f{
    xs = Theme.Spacing.ExtraSmall,
    sm = Theme.Spacing.Small,
    md = Theme.Spacing.Medium,
    lg = Theme.Spacing.Large,
    xl = Theme.Spacing.ExtraLarge
}

type Props = {
    children: any?
}

local function ScaleProvider(props: Props)
    -- Keep track of active camera and viewport size
    local camera, setCamera = React.useState(Workspace.CurrentCamera)
    local vpSize, setVpSize = React.useState(camera and camera.ViewportSize or Vector2.zero)
    React.useEffect(function(): () -> ()
        local conn = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function(): ()
            setCamera(Workspace.CurrentCamera)
        end)
        return function(): ()
            conn:Disconnect()
        end
    end, {})
    React.useEffect(function(): (() -> ())?
        if not camera then
            return nil
        end
        local conn = Connect.NowAndFuture(camera.ViewportSize, camera:GetPropertyChangedSignal("ViewportSize"),
            function(...: any): ()
                setVpSize(camera.ViewportSize)
            end)
        return function(): ()
            conn:Disconnect()
        end
    end, { camera })

    -- Adjust scale factor based on camera vp size
    local scaleFactor = React.useMemo(function(): number
        if not camera then
            return 1
        end

        -- Allow for portrait scaling by using the smaller of the two ratios
        local heightRatio = vpSize.Y / BASE_SIZE.Y
        local portrait = vpSize.X < vpSize.Y
        local widthRatio = vpSize.X / (portrait and BASE_SIZE.Y or BASE_SIZE.X)
        
        return if portrait then widthRatio else heightRatio
    end, { vpSize })

    -- Provide context value
    local value = React.useMemo(function(): ScaleContext.ScaleContextValue
        local function getSpacingPx(token: ScaleContext.ScaleToken): number
            return SPACINGS[token] * scaleFactor
        end
        local function getSpacingUDim(token: ScaleContext.ScaleToken): UDim
            return UDim.new(0, getSpacingPx(token))
        end
        return {
            scaleFactor = scaleFactor,
            getSpacingPx = getSpacingPx,
            getSpacingUDim = getSpacingUDim
        }
    end, { scaleFactor })

    return e(ScaleContext.Provider, {
        value = value
    }, props.children)
end

return ScaleProvider