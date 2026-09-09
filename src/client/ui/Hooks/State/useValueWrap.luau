
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)

return function<T>(wrap: Types.ValueWrap<T>): (T, (T | (T) -> T) -> ())
    local state, setState = React.useState(wrap:Get())
    React.useEffect(function(): ()
        setState(wrap:Get())
    end, { wrap })

    React.useEffect(function(): () -> ()
        local conn = wrap.Changed:Connect(function(newValue: T): ()
            setState(newValue)
        end)
        return function(): ()
            conn:Disconnect()
        end
    end, { wrap })
    return state, function(newValue: T | (T) -> T): ()
        if typeof(newValue) == "function" then
            wrap:Set(newValue(wrap:Get()))
        else
            wrap:Set(newValue)
        end
    end
end