
-- Services
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Modules
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Bootstrap = require(ReplicatedStorage.Shared.Helpers.Bootstrap)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Types = require(ReplicatedStorage.Shared.Types)

-- Passes
local f = table.freeze

-- Constants
local TIMEOUT = 30

type LifecycleService = Types.Service<{
    -- Data
    Services: {Types.Service},
    Targets: {Folder},
}>
local LifecycleService: LifecycleService = {
    Services = {},
    Targets = f{
        ReplicatedStorage.Shared.Services,
        RunService:IsServer()
            and ServerScriptService.Services
            or ReplicatedStorage.Client.Services
    }
} :: any

function LifecycleService._initialise(self: LifecycleService): boolean
    -- Attempt require
    local services, failed = Bootstrap.RequireAll({ script }, table.unpack(self.Targets))
    if next(failed) ~= nil then
        Pretty.Warn(`failed to require Service(s): {table.concat(failed, ", ")}`,
            script, "_initialise")
        return false
    end

    -- Attempt initialise
    local attempt = Bootstrap.InitialiseAll(TIMEOUT, table.unpack(services))
    if next(attempt.Failures) ~= nil then
        local names = TableUtil.Map(attempt.Failures, function(service: any): string
            return service.Name
        end)
        Pretty.Warn(`failed to initialise Service(s): {table.concat(names, ", ")}`,
            script, "_initialise")
        return false
    end

    local rounded = math.round(attempt.TimeTaken * 100) / 100
    Pretty.Debug(`successfully initialised {#services} Service(s) in {rounded}s`,
        script, "_initialise")

    self.Services = services

    return true
end

function LifecycleService._cleanup(self: LifecycleService): ()
    local attempt = Bootstrap.CleanupAll(TIMEOUT, table.unpack(self.Services))
    if next(attempt.Failures) ~= nil then
        local names = TableUtil.Map(attempt.Failures, function(service: any): string
            return service.Name
        end)
        Pretty.Warn(`failed to cleanup Service(s): {table.concat(names, ", ")}`,
            script, "_cleanup")
    end

    local rounded = math.round(attempt.TimeTaken * 100) / 100
    Pretty.Debug(`successfully cleaned up {#self.Services} Service(s) in {rounded}s`,
        script, "_cleanup")

    table.clear(self.Services)
end

return Types.Service.new(script, LifecycleService)