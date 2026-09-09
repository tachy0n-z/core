
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Modules
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Debounce = require(ReplicatedStorage.Shared.Helpers.Debounce)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Types = require(ReplicatedStorage.Shared.Types)
local Net = require(ReplicatedStorage.Shared.Helpers.Net)

-- Remotes
local ready = Net.RemoteEvent("Ready", script)
local push = Net.RemoteEvent("Push", script)
local pull = Net.RemoteFunction("Pull", script)

-- Constants
local READY_DEBOUNCE = 1
local PULL_DEBOUNCE_SERVER = .1
local PULL_DEBOUNCE_CLIENT = .5
local PULL_RETRIES = 30

-- References
local localPlayer = Players.LocalPlayer

type UserDataService = Types.Service<{
    -- Private data
    _storage: {[Player]: Types.UserDataRecord},
    _locked: {[Player]: boolean},

    -- Events
    Added: Types.Signal<Player>,
    Removing: Types.Signal<Player>,
    
    -- Helper methods
    ForEach: (self: UserDataService, callback: (Player, Types.UserDataRecord) -> ()) -> (),
    All: (self: UserDataService) -> {[Player]: Types.UserDataRecord},
    With: (self: UserDataService, player: Player, callback: (Types.UserDataRecord) -> ()) -> boolean,

    -- Methods
    Register: (self: UserDataService, player: Player, data: any) -> (),
    Clear: (self: UserDataService, player: Player) -> (),
    Load: (self: UserDataService, player: Player, data: any) -> (),
    Get:
        ((self: UserDataService, player: Player?) -> Types.UserDataRecord?) &
        ((self: UserDataService, player: Player?, assertExists: true) -> Types.UserDataRecord)
}>
local UserDataService: UserDataService = {
    -- Private data
    _storage = {},
    _locked = {},

    -- Events
    Added = Types.Signal.new(),
    Removing = Types.Signal.new()
} :: any

function UserDataService:ForEach(callback: (Player, Types.UserDataRecord) -> ()): ()
    for player, record in pairs(self._storage) do
        if self._locked[player] then
            continue
        end
        callback(player, record)
    end
end

function UserDataService:All(): {[Player]: Types.UserDataRecord}
    return TableUtil.Filter(self._storage :: any, function(_, player): boolean
        return not self._locked[player]
    end) :: any
end

function UserDataService:With(player: Player, callback: (Types.UserDataRecord) -> ()): boolean
    local record = self:Get(player)
    if record then
        callback(record)
        return true
    end
    return false
end

function UserDataService:Register(player: Player, data: any): ()
    if self._storage[player] then
        return Pretty.Debug(`attempt to register data for '{player.Name}' but already registered`,
            script, "Register")
    end

    -- Construct record
    local record = Types.UserDataRecord.new(data)

    -- If server, setup push/pull, lock until ready
    local connections: {any}
    if RunService:IsServer() then
        -- Lock and store
        self._locked[player] = true
        connections = {
            record.Changed:Connect(function(path: {any}, new: any?): ()
                if self._locked[player] then
                    return Pretty.Debug(`attempt to push data for '{player.Name}' at path '{table.concat(Pretty.Stringify(path), ".")}' but locked`,
                        script, "Register")
                end
                push:FireClient(player, path, new)
            end)
        }
        self._storage[player] = record
    end

    -- If client, wait for ready and unlock
    if RunService:IsClient() then
        connections = {
            push.OnClientEvent:Connect(function(path: {any}, value: any?): ()
                if not record:Apply(path, value) then
                    Pretty.Debug(`failed to set data for '{player.Name}' at path '{table.concat(Pretty.Stringify(path), ".")}' to '{tostring(value)}'`,
                        script, "Register")
                end
            end)
        }
        self._storage[player] = record
        self.Added:Fire(player)
    end

    -- Cleanup on removal
    connections = TableUtil.Extend(connections, {
        self.Removing:Connect(function(otherPlayer: Player): ()
            if otherPlayer == player then
                for _, connection in ipairs(connections) do
                    connection:Disconnect()
                end
            end
        end)
    })
end

function UserDataService:Clear(player: Player): ()
    if not self._storage[player] then
        return Pretty.Debug(`attempt to clear data for '{player.Name}' but not registered`,
            script, "Clear")
    end
    self._locked[player] = nil
    self.Removing:Fire(player)
    self._storage[player] = nil
end

function UserDataService:Load(player: Player, data: any): ()
    local existing = self._storage[player]
    if existing then
        return Pretty.Debug(`attempt to load data for '{player.Name}' but already registered`,
            script, "Load")
    end
    self:Register(player, data)
end

function UserDataService:Get(player: Player?, assertExists: boolean?): any
    local player = player or localPlayer
    if not player then
        return Pretty.Error(`player argument is expected in server-side context`,
            script, "Get")
    end
    local record: any? = self._storage[player]
    if self._locked[player] then
        record = nil
    end
    if not record and assertExists then
        return Pretty.Error(`attempt to get data for '{player.Name}' but not registered`,
            script, "Get")
    end
    return record
end

function UserDataService._initialise(self: UserDataService): boolean
    if RunService:IsClient() then
        -- Fetch our data
        local data = Debounce.Retry(pull.InvokeServer,
            PULL_RETRIES, PULL_DEBOUNCE_CLIENT, "table", pull)
        if not data then
            return Pretty.Error(`failed to receive our data after {PULL_RETRIES} attempts`,
                script, "_initialise")
        end
        self:Register(localPlayer, data)
        ready:FireServer() -- Start syncing!
    else
        -- Setup pull and ready
        pull.OnServerInvoke = Debounce.PerPlayerFunction(function(player: Player): any?
            local record = self._storage[player]
            if not record then
                return Pretty.Debug(`'{player.Name}' attempted to pull their data but not registered`,
                    script, "_initialise")
            end
            return record:Raw()
        end, PULL_DEBOUNCE_SERVER)
        self._trove:Add(Debounce.PerPlayerEvent(ready.OnServerEvent, function(player: Player): ()
            if not self._storage[player] then
                return Pretty.Debug(`'{player.Name}' attempted to ready their data but not registered`,
                    script, "_initialise")
            end
            if self._locked[player] then
                self._locked[player] = nil
                self.Added:Fire(player)
            end
        end, READY_DEBOUNCE))
    end
    return true
end

function UserDataService._cleanup(self: UserDataService): ()
    for player in pairs(TableUtil.Copy(self._storage)) do
        self:Clear(player)
    end
    if RunService:IsServer() then
        pull.OnServerInvoke = function(player: Player): nil
            return nil
        end
    end
    table.clear(self._storage)
    table.clear(self._locked)
end

return Types.Service.new(script, UserDataService)