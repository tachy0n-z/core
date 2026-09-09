
-- Constants
local WARN_ICON = "⚠️"
local ERROR_ICON = "🛑"
local DEBUG_ICON = "🐛"

local Pretty = {}

function Pretty.Prefix(source: { Name: string }?, funcName: string?): string
    local prefix = ""
    if source then
        prefix ..= `[{source.Name}] `
    end
    if funcName then
        prefix ..= `{funcName}(...) `
    end
    return prefix
end

function Pretty.Print(text: string, source: { Name: string }?, funcName: string?): ()
    print(Pretty.Prefix(source, funcName) .. text)
end

function Pretty.Debug(text: string, source: { Name: string }?, funcName: string?): ()
    print(DEBUG_ICON .. " " .. Pretty.Prefix(source, funcName) .. text)
end

function Pretty.Warn(text: string, source: { Name: string }?, funcName: string?): ()
    warn(WARN_ICON .. " " .. Pretty.Prefix(source, funcName) .. text)
end

function Pretty.Error(text: string, source: { Name: string }?, funcName: string?): ...any
    error(ERROR_ICON .. " " .. Pretty.Prefix(source, funcName) .. text)
end

function Pretty.Stringify(value: any | {any}): {string}
    if typeof(value) == "table" then
        local result = {}
        for key, sub in ipairs(value) do
            if typeof(sub) == "table" then
                for kk, ss in ipairs(Pretty.Stringify(sub)) do
                    table.insert(result, ss)
                end
            else
                table.insert(result, tostring(sub))
            end
        end
        return result
    else
        return { tostring(value) }
    end
end

return table.freeze(Pretty)