
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Modules
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local React = require(ReplicatedStorage.Packages.React)
local Net = require(ReplicatedStorage.Shared.Helpers.Net)

return function(name: string): (...any) -> ()
    return React.useCallback(function(...: any): ()
        if RunService:IsRunning() or RunService:IsRunMode() then
            Net.RemoteEvent(name):FireServer(...)
        else
            Pretty.Print(`{name}:FireServer({table.concat(Pretty.Stringify({...}), ", ")})`,
                script)
        end
    end, { name })
end