
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Modules
local Connect = require(ReplicatedStorage.Shared.Helpers.Connect)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Types = require(ReplicatedStorage.Shared.Types)

-- Constants
local MAX_WAIT_TIMEOUT = 15 -- seconds
local READY_ATTRIBUTE = `_{script.Name}_Ready`
local BLOCK_PREFIX = `_{script.Name}_`

-- References
local localPlayer = Players.LocalPlayer

type SessionDataService = Types.Service<{
    -- Private data
    _storage: {[Player]: Types.SessionDataRecord},

    -- Events
    Added: Types.Signal<Player>,
    Removing: Types.Signal<Player>,

    -- Helper methods
    All: (self: SessionDataService) -> {[Player]: Types.SessionDataRecord},
    With: (self: SessionDataService, player: Player, callback: (Types.SessionDataRecord) -> ()) -> boolean,

    -- Methods
    Install: (self: SessionDataService, player: Player) -> (),
    Parse: (self: SessionDataService, player: Player) -> (),
    Clear: (self: SessionDataService, player: Player) -> (),
    Get:
        ((self: SessionDataService, player: Player?) -> Types.SessionDataRecord?) &
        ((self: SessionDataService, player: Player?, assertExists: true) -> Types.SessionDataRecord)
}>
local SessionDataService: SessionDataService = {
    -- Private data
    _storage = {},

    -- Events
    Added = Types.Signal.new(),
    Removing = Types.Signal.new()
} :: any

function SessionDataService.All(self: SessionDataService): {[Player]: Types.SessionDataRecord}
    return table.clone(self._storage)
end

function SessionDataService.With(self: SessionDataService, player: Player, callback: (Types.SessionDataRecord) -> ()): boolean
    local record = self:Get(player)
    if record then
        callback(record)
        return true
    end
    return false
end

function SessionDataService.Install(self: SessionDataService, player: Player): ()
    if self._storage[player] then
        return Pretty.Debug(`already installed for '{player.Name}'`,
            script, "Install")
    end

    -- Create record
    local record = Types.SessionDataRecord.new(nil, BLOCK_PREFIX)

    -- Setup reflection
    local conns: {any}
    conns = {
        self._trove:Add(record:ReflectTo(player), "Disconnect"),
        self._trove:Add(record.Destroying:Once(function(): ()
            for _, conn in ipairs(conns) do
                self._trove:Remove(conn)
            end
        end), "Disconnect")
    }

    -- Notify client of readiness
    player:SetAttribute(READY_ATTRIBUTE, true)

    -- Add and fire
    self._storage[player] = record
    self.Added:Fire(player)
end

function SessionDataService.Parse(self: SessionDataService, player: Player): ()
    -- Check if already parsed
    local record = self:Get(player)
    if record then
        return Pretty.Debug(`already parsed for '{player.Name}'`,
            script, "Parse")
    end

    -- Wait for readiness
    local ready = player:GetAttribute(READY_ATTRIBUTE) == true
    local conn = player:GetAttributeChangedSignal(READY_ATTRIBUTE):Connect(function(): ()
        ready = player:GetAttribute(READY_ATTRIBUTE) == true
    end)
    local now = os.clock()
    repeat
        RunService.Heartbeat:Wait()
    until
        ready or
        not player:IsDescendantOf(game) or
        os.clock() - now > MAX_WAIT_TIMEOUT
    if conn.Connected then
        conn:Disconnect()
    end

    -- Timed out?
    if os.clock() - now > MAX_WAIT_TIMEOUT then
        return Pretty.Warn(`timed out waiting for readiness of '{player.Name}'`,
            script, "Parse")
    end

    -- Check if still valid
    if not player:IsDescendantOf(game) then
        return Pretty.Debug(`player '{player.Name}' is no longer valid`,
            script, "Parse")
    end

    -- Create record
    local record = Types.SessionDataRecord.new(nil, BLOCK_PREFIX)

    -- Reflect from player
    local conns: {any}
    conns = {
        self._trove:Add(record:ReflectFrom(player)),
        self._trove:Add(record.Destroying:Once(function(): ()
            for _, conn in ipairs(conns) do
                self._trove:Remove(conn)
            end
        end), "Disconnect")
    }

    -- Add and fire
    self._storage[player] = record
    self.Added:Fire(player)
end

function SessionDataService.Clear(self: SessionDataService, player: Player): ()
    local record = self:Get(player)
    if not record then
        return Pretty.Debug(`attempt to clear data for '{player.Name}' but not registered`,
            script, "Clear")
    end

    -- Remove and fire
    self._storage[player] = nil
    self.Removing:Fire(player)

    -- Destroy record
    record:Destroy()
end

function SessionDataService.Get(self: SessionDataService, player: Player?, assertExists: boolean?): any
    local player = player or Players.LocalPlayer
    if not player then
        return Pretty.Error(`player argument is expected in server-side context`,
            script, "Get")
    end
    local record = self._storage[player]
    if not record and assertExists then
        return Pretty.Error(`attempt to get data for '{player.Name}' but not registered`,
            script, "Get")
    end
    return record
end

function SessionDataService._initialise(self: SessionDataService): boolean
    if RunService:IsServer() then
        -- If server-side, install session data for all current and future players
        self._trove:Add(Connect.NowAndFutureAsync(Players:GetPlayers(), Players.PlayerAdded,
            function(player: Player): ()
                self:Install(player)
            end))
        self._trove:Add(Players.PlayerRemoving:Connect(function(player: Player): ()
            self:Clear(player)
        end))
    else
        -- Client-side: parse!
        self._trove:Add(Connect.NowAndFutureAsync(Players:GetPlayers(), Players.PlayerAdded,
            function(player: Player): ()
                self:Parse(player)
            end))
        self._trove:Add(Players.PlayerRemoving:Connect(function(player: Player): ()
            self:Clear(player)
        end))

        -- Wait for ours to be ready
        if not self:Get() then
            local last: Player? = nil
            repeat
                last = self.Added:Wait()
            until
                last == localPlayer or
                self:Get() ~= nil
        end
    end
    return true
end

function SessionDataService._cleanup(self: SessionDataService): ()
    for player in pairs(self:All()) do
        self:Clear(player)
    end
    table.clear(self._storage)
end

return Types.Service.new(script, SessionDataService)