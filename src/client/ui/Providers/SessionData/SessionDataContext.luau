
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)

local SessionDataContext = React.createContext(nil :: Types.SessionDataRecord?)

return SessionDataContext