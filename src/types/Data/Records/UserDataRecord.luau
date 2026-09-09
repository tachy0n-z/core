
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- References
local Types = script:FindFirstAncestor("Types")

-- Modules
local UserDataTemplate = require(ReplicatedStorage.Config.UserDataTemplate)
local Record = require(Types.Data.Record)
local Type = require(Types.Core.Type)

export type UserDataRecord = Record.Record<typeof(UserDataTemplate)>
local UserDataRecordMethods = Type.methods("UserDataRecord", {} :: UserDataRecord, Record.Methods)

local UserDataRecordClass = {}

function UserDataRecordClass.new(data: any?): UserDataRecord
    return Record.new(UserDataTemplate, data, UserDataRecordMethods)
end

return Type.class(UserDataRecordClass, UserDataRecordMethods)