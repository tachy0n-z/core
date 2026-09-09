
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Modules
local SessionDataContext = require(ReplicatedStorage.Client.UI.Providers.SessionData.SessionDataContext)
local SessionDataService = require(ReplicatedStorage.Shared.Services.SessionDataService)
local Connect = require(ReplicatedStorage.Shared.Helpers.Connect)
local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)

-- Hooks
local useService = require(ReplicatedStorage.Client.UI.Hooks.Control.useService)

-- References
local localPlayer = Players.LocalPlayer

return function(player: Player?): Types.SessionDataRecord?
    if player == nil or player == localPlayer then
        return React.useContext(SessionDataContext)
    end
    local sessionDataService = useService(SessionDataService)
    local session, setSession = React.useState(nil :: any?)
    React.useEffect(function(): (() -> ())?
        if not sessionDataService then
            setSession(nil)
            return
        end
        local conns = {
            sessionDataService.Added:Connect(function(other: Player): ()
                if other == player then
                    setSession(sessionDataService:Get(other))
                end
            end),
            sessionDataService.Removing:Connect(function(other: Player): ()
                if other == player then
                    setSession(nil)
                end
            end)
        }
        setSession(sessionDataService:Get(player))
        return function(): ()
            Connect.Disconnect(conns, true)
        end
    end, { sessionDataService, player } :: {any})
    return session
end