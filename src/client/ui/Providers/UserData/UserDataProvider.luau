
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)

-- Contexts
local UserDataContext = require(ReplicatedStorage.Client.UI.Providers.UserData.UserDataContext)

-- Passes
local e = React.createElement

type Props = {
    record: Types.UserDataRecord?,
    children: any?
}

local function UserDataProvider(props: Props)
    return e(UserDataContext.Provider, {
        value = props.record
    }, props.children)
end

return UserDataProvider