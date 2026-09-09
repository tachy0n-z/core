
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Modules
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local React = require(ReplicatedStorage.Packages.React)
local Net = require(ReplicatedStorage.Shared.Helpers.Net)

return function(name: string): (...any) -> any
    local remote = React.useMemo(function(): RemoteFunction?
        if RunService:IsRunning() or RunService:IsRunMode() then
            return Net.RemoteFunction(name)
        end
        return nil
    end, { name })
    return function(...: any): any
        if remote then
            return remote:InvokeServer(...)
        else
            return Pretty.Print(`{name}:InvokeServer({table.concat({...}, ", ")})`,
                script)
        end
    end
end