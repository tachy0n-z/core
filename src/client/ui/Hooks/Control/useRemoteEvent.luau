
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Modules
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local React = require(ReplicatedStorage.Packages.React)
local Net = require(ReplicatedStorage.Shared.Helpers.Net)

return function(name: string): (...any) -> ()
    local remote = React.useMemo(function(): RemoteEvent?
        if RunService:IsRunning() or RunService:IsRunMode() then
            return Net.RemoteEvent(name)
        end
        return nil
    end, { name })
    return function(...: any): ()
        if remote then
            remote:FireServer(...)
        else
            Pretty.Print(`{name}:FireServer({table.concat({...}, ", ")})`,
                script)
        end
    end
end