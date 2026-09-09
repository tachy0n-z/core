
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- References
local Types = script:FindFirstAncestor("Types")

-- Modules
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Signal = require(Types.Core.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Type = require(Types.Core.Type)

-- Used across all service-style modules in the project.
-- Provides a standardised structure for initialisation and cleanup.
export type Service<T = {}> = Type.Type<T & {
    -- Private data
    _trove: typeof(Trove.new()),
    _isInitialised: boolean,
    _deps: {any},

    -- Public data
    Name: string,

    -- Events
    InitialiseDone: Signal.Signal<number>,
    CleanupDone: Signal.Signal<number>,

    -- User-defined methods
    _initialise: ((self: any, ...any) -> boolean)?,
    _cleanup: ((self: any) -> ())?,

    -- Dependency methods
    GetDependencies: (self: Service<T>) -> {any},
    HasDependency: (self: Service<T>, dep: any) -> boolean,

    -- Lifecycle methods
    WaitForInitialised: (self: Service<T>) -> (),
    IsInitialised: (self: Service<T>) -> boolean,
    Initialise: (self: Service<T>, ...any) -> (boolean, number),
    Cleanup: (self: Service<T>) -> number
}>
local ServiceMethods = Type.methods("Service", {} :: Service)

-- Returns a list of other Service instances that this service depends on.
function ServiceMethods.GetDependencies(self: Service): {any}
    return table.clone(self._deps)
end

-- Returns whether this service depends on the given service.
function ServiceMethods.HasDependency(self: Service, dep: any): boolean
    return table.find(self._deps, dep) ~= nil
end

-- Waits until the service is initialised.
function ServiceMethods.WaitForInitialised(self: Service): ()
    if not self._isInitialised then
        self.InitialiseDone:Wait()
    end
end

-- Returns whether the service is initialised.
function ServiceMethods.IsInitialised(self: Service): boolean
    return self._isInitialised
end

-- Safely initialises this service.
function ServiceMethods.Initialise(self: Service, ...: any): (boolean, number)
    if self._isInitialised then
        return true, 0
    end
    for _, dep: Service in ipairs(self._deps) do
        dep:WaitForInitialised()
    end

    -- Track time for listeners
    local now = os.clock()
    
    -- Attempt initialisation
    if self._initialise then
        local success, resp = pcall(self._initialise, self, ...)
        now = os.clock() - now
        if not success then
            Pretty.Warn("failed with error: " .. tostring(resp),
                nil, `{self.Name}.Initialise`)
            return false, now
        elseif not resp then
            return false, now
        end
    else
        now = os.clock() - now
    end

    -- Fire for listeners
    self._isInitialised = true
    self.InitialiseDone:Fire(now)

    return true, now
end

-- Safely cleans up after this service.
function ServiceMethods.Cleanup(self: Service): number
    if not self._isInitialised then
        return 0
    end

    -- Track time for listeners
    local now = os.clock()

    -- Attempt cleanup
    if self._cleanup then
        local success, err: string? = pcall(self._cleanup, self)
        if not success then
            Pretty.Warn("failed with error: " .. tostring(err),
                nil, `{self.Name}.Cleanup`)
        end
    end
    now = os.clock() - now

    -- Clear all connections
    self._trove:Clean()

    -- Fire for listeners
    self._isInitialised = false
    self.CleanupDone:Fire(now)

    return now
end

-- Destroys this service and all of its connections.
function ServiceMethods._destroy(self: Service): ()
    -- Make sure all clean
    self:Cleanup()
    self._trove:Destroy()

    -- Destroy all evs
    self.InitialiseDone:Destroy()
    self.CleanupDone:Destroy()
end

local ServiceClass = {}

function ServiceClass.new<T>(source: { Name: string }, from: T, deps: {any}?): T
    if typeof(from) ~= "table" then
        return Pretty.Error("expected table for service creation, got " .. typeof(from),
            script, "Service")
    end

    -- Construct middle
    local middle = {
        -- Private data
        _trove = Trove.new(),
        _isInitialised = false,
        _deps = deps or {},

        -- Public data
        Name = source.Name,

        -- Events
        InitialiseDone = Signal.new(),
        CleanupDone = Signal.new()
    }

    -- Setup metatable chain
    setmetatable(middle, { __index = ServiceMethods })
    setmetatable(from :: any, { __index = middle })

    return Type.instance(from, nil)
end

return Type.class(ServiceClass, ServiceMethods)