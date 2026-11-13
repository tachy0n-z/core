
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Ripple = require(ReplicatedStorage.Packages.Ripple)
local React = require(ReplicatedStorage.Packages.React)

return function<T>(initial: T, options: any?, deps: {any}?)
    local binding, setBinding = React.useBinding(initial)
    local memoDeps: {any} = { initial }
    for i: number, dep in pairs(deps or {}) do
        memoDeps[i + 1] = dep -- By position, so nil deps keep their place
    end
    local motion = React.useMemo(function()
        return Ripple.createMotion(initial, options)
    end, memoDeps)
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