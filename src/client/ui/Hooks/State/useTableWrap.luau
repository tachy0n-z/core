
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)

return function<K, V>(wrap: Types.TableWrap<K, V>): ({[K]: V}, (K, V?) -> ())
    local state, setState = React.useState(wrap:All())
    React.useEffect(function(): ()
        setState(wrap:All())
    end, { wrap })

    React.useEffect(function(): () -> ()
        local conn = wrap.Changed:Connect(function(): ()
            setState(wrap:All())
        end)
        return function(): ()
            conn:Disconnect()
        end
    end, { wrap })
    return state, function(key: K, value: V?): ()
        wrap:Set(key, value)
    end
end