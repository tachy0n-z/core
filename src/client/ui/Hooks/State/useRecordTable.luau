
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local React = require(ReplicatedStorage.Packages.React)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Types = require(ReplicatedStorage.Shared.Types)

local function getSnapshot(record: Types.Record<any>?, path: {any}): any?
    if not record then
        return nil
    end
    local value = record:Unwrap(record:Get(path))
    if typeof(value) == "table" then
        -- Return a fresh snapshot so nested key updates trigger React re-renders
        return TableUtil.Copy(value, true)
    end
    return value
end

return function(record: Types.Record<any>?, path: {any}): any?
    local state, setState = React.useState(getSnapshot(record, path))
    React.useEffect(function(): (() -> ())?
        if record then
            setState(getSnapshot(record, path))
            local signals = {
                record:GetChangedSignalAtPath(path),
                record:GetChangedSignalUnderPath(path)
            }
            for _, sig in ipairs(signals) do
                sig:Connect(function(): ()
                    setState(getSnapshot(record, path))
                end)
            end
            return function(): ()
                for _, sig in ipairs(signals) do
                    sig:Destroy()
                end
            end
        end
        setState(nil)
        return nil
    end, { record, path } :: {any})
    return state
end