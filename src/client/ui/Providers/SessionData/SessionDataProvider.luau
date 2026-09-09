
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)

-- Contexts
local SessionDataContext = require(ReplicatedStorage.Client.UI.Providers.SessionData.SessionDataContext)

-- Passes
local e = React.createElement

type Props = {
    record: Types.SessionDataRecord?,
    children: any?
}

local function SessionDataProvider(props: Props)
    return e(SessionDataContext.Provider, {
        value = props.record
    }, props.children)
end

return SessionDataProvider