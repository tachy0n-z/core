
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)

-- Providers
local UserDataProvider = require(ReplicatedStorage.Client.UI.Providers.UserData.UserDataProvider)
local ScaleProvider = require(ReplicatedStorage.Client.UI.Providers.Scale.ScaleProvider)
local SessionDataProvider = require(ReplicatedStorage.Client.UI.Providers.SessionData.SessionDataProvider)

-- Passes
local e = React.createElement

local function App(props: {
    sessionDataRecord: Types.SessionDataRecord?,
    userDataRecord: Types.UserDataRecord?,
    useFrame: boolean?
})
    local children = {
        e(UserDataProvider, {
            record = props.userDataRecord
        }, {
            e(SessionDataProvider, {
                record = props.sessionDataRecord
            }, {
                e(ScaleProvider, {}, {
                    -- CHILDREN
                })
            })
        })
    }
    return props.useFrame and e("Frame", {
        AnchorPoint = Vector2.new(.5, .5),
        Position = UDim2.fromScale(.5, .5),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1
    }, children) or e("ScreenGui", {
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    }, children)
end

return App