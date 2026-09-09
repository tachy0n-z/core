
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)

return function(record: Types.Record<any>?, path: {any}): any?
    local state, setState = React.useState(if record then record:Get(path) else nil)
    React.useEffect(function(): (() -> ())?
        if record then
            setState(record:Get(path))
            local signal = record:GetChangedSignalAtPath(path)
            signal:Connect(function(newValue: any?): ()
                setState(newValue)
            end)
            return function(): ()
                signal:Destroy()
            end
        end
        setState(nil)
        return nil
    end, { record, path } :: {any})
    return state
end