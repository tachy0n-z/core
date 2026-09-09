
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

-- Modules
local SessionDataService = require(ReplicatedStorage.Shared.Services.SessionDataService)
local UserDataService = require(ReplicatedStorage.Shared.Services.UserDataService)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local React = require(ReplicatedStorage.Packages.React)
local Types = require(ReplicatedStorage.Shared.Types)

-- Components
local App = require(ReplicatedStorage.Client.UI.App)

-- Passes
local e = React.createElement

-- References
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- The wrapper used to pass our UserDataRecord and SessionDataRecord to the App component.
local function Wrapper(props: {})
    -- Wait for our record patiently
    local record, setRecord = React.useState(nil :: any?)
    React.useEffect(function(): () -> ()
        local conn = UserDataService.Added:Connect(function(owner: Player): ()
            if owner == localPlayer then
                setRecord(UserDataService:Get(owner, true))
            end
        end)
        setRecord(UserDataService:Get())
        return function(): ()
            conn:Disconnect()
        end
    end, {})

    -- Wait for our session patiently
    local session, setSession = React.useState(nil :: any?)
    React.useEffect(function(): () -> ()
        local conn = SessionDataService.Added:Connect(function(owner: Player): ()
            if owner == localPlayer then
                setSession(SessionDataService:Get(owner, true))
            end
        end)
        setSession(SessionDataService:Get())
        return function(): ()
            conn:Disconnect()
        end
    end, {})

    return e(App, {
        sessionDataRecord = session,
        userDataRecord = record,
        useFrame = true
    })
end

type UIMountService = Types.Service<{
    -- Private data
    _mount: ScreenGui?,
    _root: any?
}>
local UIMountService: UIMountService = {} :: any

function UIMountService._initialise(self: UIMountService): boolean
    -- Construct mount target
    local mount = Instance.new("ScreenGui", playerGui)
    mount.Name = "Mount"
    mount.ResetOnSpawn = false
    mount.IgnoreGuiInset = true
    mount.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    self._mount = mount

    -- Attempt to mount React tree
    local root = ReactRoblox.createRoot(mount)
    local success, err: string? = pcall(function(): ()
        root:render(e(Wrapper, {}))
    end)
    if not success then
        Pretty.Warn(`failed to mount: {err}`,
            script, "_initialise")
        return false
    end
    self._root = root

    return true
end

function UIMountService._cleanup(self: UIMountService): ()
    -- Unmount React tree
    if self._root then
        self._root:unmount()
        self._root = nil
    end

    -- Destroy target
    if self._mount then
        self._mount:Destroy()
        self._mount = nil
    end
end

return Types.Service.new(script, UIMountService)