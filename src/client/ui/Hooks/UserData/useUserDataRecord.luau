
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local UserDataContext = require(ReplicatedStorage.Client.UI.Providers.UserData.UserDataContext)
local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)

return function(): Types.UserDataRecord?
    return React.useContext(UserDataContext)
end