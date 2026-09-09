
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local React = require(ReplicatedStorage.Packages.React)

export type ScaleToken =
    "xs" | "sm" | "md" | "lg" | "xl"

export type ScaleContextValue = {
    scaleFactor: number,
    getSpacingPx: (token: ScaleToken) -> number,
    getSpacingUDim: (token: ScaleToken) -> UDim
}

local ScaleContext = React.createContext(nil :: ScaleContextValue?)

return ScaleContext