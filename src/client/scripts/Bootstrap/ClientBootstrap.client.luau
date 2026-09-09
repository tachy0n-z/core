
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Modules
local LifecycleService = require(ReplicatedStorage.Shared.Services.LifecycleService)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)

-- Constants
local KICK_MESSAGE = "Failed to load. Please rejoin."

-- References
local localPlayer = Players.LocalPlayer

if not LifecycleService:Initialise() then
    localPlayer:Kick(KICK_MESSAGE)
    return Pretty.Error("failed to initialise LifecycleService",
        script)
end
