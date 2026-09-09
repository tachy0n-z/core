
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local React = require(ReplicatedStorage.Packages.React)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Types = require(ReplicatedStorage.Shared.Types)

return function<T>(raw: T): T?
    if
        typeof(raw) ~= "table" or
        not Types.Is(raw) or
        not raw:IsA("Service")
    then
        return Pretty.Error(`invalid service provided: {raw}`,
            script)
    end

    -- Make available once the service is initialised
    local service, setService = React.useState(nil :: T?)
    React.useEffect(function(): () -> ()
        if service ~= nil and service ~= raw then
            setService(nil)
        end
        if raw:IsInitialised() then
            setService(raw)
        end
        local conn = raw.InitialiseDone:Connect(function(): ()
            setService(raw)
        end)
        return function(): ()
            conn:Disconnect()
        end
    end, { raw })

    return service :: any
end