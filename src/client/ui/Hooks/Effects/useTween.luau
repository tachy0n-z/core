
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
    local tween = React.useMemo(function()
        return Ripple.createTween(initial, options)
    end, memoDeps)
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