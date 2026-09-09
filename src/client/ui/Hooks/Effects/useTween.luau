
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local React = require(ReplicatedStorage.Packages.React)

return function<T>(initial: T, options: any?, deps: {any}?)
    local binding, setBinding = React.useBinding(initial)
    local tween = React.useMemo(function()
        return Ripple.createTween(initial, options)
    end, TableUtil.Assign({ initial }, deps or {}) :: {any})
    React.useEffect(function()
        setBinding(initial)
        local dc = tween:onChange(setBinding)
        return function()
            dc()
            tween:destroy()
        end
    end, { tween } :: {any})
    return binding, tween
end