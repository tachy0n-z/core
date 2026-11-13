
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Modules
local UserDataTemplate = require(ReplicatedStorage.Config.UserDataTemplate)
local UserDataService = require(ReplicatedStorage.Shared.Services.UserDataService)
local ProfileStore = require(ReplicatedStorage.Packages.ProfileStore)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Connect = require(ReplicatedStorage.Shared.Helpers.Connect)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)

-- Constants
local SESSION_END_MSG = "Your data was loaded elsewhere. Please rejoin in a moment."
local KICK_MSG = "Failed to load your data. Please rejoin in a moment."
local USE_MOCK = false

-- Config
local version = UserDataTemplate.Version
local store = ProfileStore.New(`PlayerData_v{tostring(version)}`)
if USE_MOCK then
    Pretty.Debug("a mock data-store is being used",
        script)
    store = store.Mock :: any
end

-- State
local activeProfiles = setmetatable({}, { __mode = "k" })
local loading: {[number]: boolean} = {}

local function load(player: Player): ()
    -- Get and validate
    local key = `Player_{tostring(player.UserId)}`
    local profile = store:StartSessionAsync(key, {
        Cancel = function(): boolean
            return not player:IsDescendantOf(Players)
        end
    })
    if not profile then
        Pretty.Warn(`failed for '{player.Name}' (couldn't load data)`,
            script, "load")
        player:Kick(KICK_MSG)
        return nil
    end

    -- Check that they haven't left!
    if not player:IsDescendantOf(Players) then
        Pretty.Warn(`failed for '{player.Name}' (left before load)`,
            script, "load")
        profile:EndSession()
        return
    end

    -- Reconcile and store
    profile:AddUserId(player.UserId)
    profile:Reconcile()
    activeProfiles[player] = profile

    -- Stop using the profile if its session is ended elsewhere (e.g. they joined another server)
    profile.OnSessionEnd:Connect(function(): ()
        if activeProfiles[player] == profile and not ProfileStore.IsClosing then
            activeProfiles[player] = nil
            UserDataService:Clear(player)
            player:Kick(SESSION_END_MSG)
        end
    end)

    -- Load into UDS
    UserDataService:Load(player, profile.Data)

    return nil
end

local function unload(player: Player): ()
    local profile = activeProfiles[player]
    activeProfiles[player] = nil

    -- Destroy the record
    UserDataService:Clear(player)

    -- Release profile
    if profile then
        profile:EndSession()
    end
end

-- Wait for UDS
UserDataService:WaitForInitialised()

-- Bind events
local connections: {any} = {
    -- Bind profile data on UDS load
    Connect.NowAndFutureAsync(TableUtil.Keys(UserDataService:All()), UserDataService.Added,
        function(player: Player): ()
            local profile = activeProfiles[player]
            if not profile then
                return Pretty.Warn(`failed to bind data for '{player.Name}' (no profile)`,
                    script, "Bind")
            end
            profile.Data = UserDataService:Get(player, true):Raw(true)
        end),

    -- Load/unload lifecycle, kicking on any error since the client waits for its data
    Connect.NowAndFutureAsync(Players:GetPlayers(), Players.PlayerAdded, function(player: Player): ()
        -- One load per user at a time, so a quick rejoin never inherits a cancelled one
        while loading[player.UserId] do
            task.wait()
        end
        loading[player.UserId] = true
        local success, err: string? = pcall(load, player)
        loading[player.UserId] = nil
        if not success then
            Pretty.Warn(`failed for '{player.Name}' ({err})`,
                script, "load")
            player:Kick(KICK_MSG)
        end
    end),
    Players.PlayerRemoving:Connect(unload)
}

-- Close on exit
game:BindToClose(function(): ()
    Connect.Disconnect(connections)
    for player in pairs(TableUtil.Copy(activeProfiles)) do
        unload(player)
    end
end)
