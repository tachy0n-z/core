
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local React = require(ReplicatedStorage.Packages.React)

return function<T>(initial: T, options: any?, deps: {any}?)
    local binding, setBinding = React.useBinding(initial)
    local motion = React.useMemo(function()
        return Ripple.createMotion(initial, options)
    end, TableUtil.Assign({ initial }, deps or {}) :: {any})
    React.useEffect(function()
        setBinding(initial)
        local dc = motion:onChange(setBinding)
        return function()
            dc()
            motion:destroy()
        end
    end, { motion } :: {any})
    return binding, motion
end