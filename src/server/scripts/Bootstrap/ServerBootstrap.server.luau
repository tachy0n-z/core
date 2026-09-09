
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Modules
local LifecycleService = require(ReplicatedStorage.Shared.Services.LifecycleService)
local Connect = require(ReplicatedStorage.Shared.Helpers.Connect)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)

-- Constants
local KICK_MESSAGE = "Server failed to load. Please rejoin."

-- Kicks everyone from the game and prevents anyone from joining.
local function shutdown(): ()
    Connect.NowAndFuture(Players:GetPlayers(), Players.PlayerAdded,
        function(player: Player): ()
            player:Kick(KICK_MESSAGE)
        end)
end

-- Attempt require
if not LifecycleService:Initialise() then
    shutdown()
    Pretty.Warn("failed to initialise LifecycleService",
        script)
    return
end
