
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local React = require(ReplicatedStorage.Packages.React)

return function<T>(initial: T, options: any?, deps: {any}?)
    local binding, setBinding = React.useBinding(initial)
    local spring = React.useMemo(function()
        return Ripple.createSpring(initial, options)
    end, TableUtil.Assign({ initial }, deps or {}) :: {any})
    React.useEffect(function()
        setBinding(initial)
        local dc = spring:onChange(setBinding)
        return function()
            dc()
            spring:destroy()
        end
    end, { spring } :: {any})
    return binding, spring
end