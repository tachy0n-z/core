
-- Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- References
local Types = script:FindFirstAncestor("Types")

-- Modules
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Connect = require(ReplicatedStorage.Shared.Helpers.Connect)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Signal = require(Types.Core.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Type = require(Types.Core.Type)

export type Adapter<I = Instance, O = any, P = any, T = {}> = Type.Type<T & {
    -- Private data
    _allowedClasses: {string},
    _trove: typeof(Trove.new()),
    _cache: {[I]: O},
    _reverse: {[any]: {[I]: true}},

    -- Public data
    Tag: string,

    -- Events
    Added: Signal.Signal<I>,
    Removing: Signal.Signal<I>,

    -- User-defined methods
    _transform: (I) -> O?,
    _release: ((I, O) -> ())?,
    _install: ((I, P) -> boolean)?,

    -- Private methods
    _addReverse: (self: Adapter<I, O, P, T>, instance: I, state: O) -> (),
    _removeReverse: (self: Adapter<I, O, P, T>, instance: I, state: O) -> (),

    -- Transformation methods
    Transform: (self: Adapter<I, O, P, T>, instance: I) -> O?,
    Release: (self: Adapter<I, O, P, T>, instance: I) -> (),
    Install: (self: Adapter<I, O, P, T>, instance: I, params: P) -> O?,

    -- Helper methods
    IsAllowedClass: (self: Adapter<I, O, P, T>, className: string | Instance) -> boolean,

    -- Query methods
    FindByState:
        ((self: Adapter<I, O, P, T>, state: O) -> I?) &
        ((self: Adapter<I, O, P, T>, state: O, throw: true) -> I),
    FindAllByState: (self: Adapter<I, O, P, T>, state: O) -> {I},

    -- Getters
    All: (self: Adapter<I, O, P, T>, raw: boolean?) -> {[I]: O},
    Get:
        ((self: Adapter<I, O, P, T>, instance: I) -> O?) &
        ((self: Adapter<I, O, P, T>, instance: I, throw: true) -> O)
}>
local AdapterMethods = Type.methods("Adapter", {} :: Adapter)

function AdapterMethods:_addReverse(instance: Instance, state: any): ()
    local reverse: {[any]: {[Instance]: true}} = self._reverse :: any
    local bucket = reverse[state]
    if not bucket then
        bucket = {}
        reverse[state] = bucket
    end
    bucket[instance] = true
end

function AdapterMethods:_removeReverse(instance: Instance, state: any): ()
    local reverse: {[any]: {[Instance]: true}} = self._reverse :: any
    local bucket = reverse[state]
    if not bucket then
        return
    end
    bucket[instance] = nil
    if next(bucket) == nil then
        reverse[state] = nil
    end
end

function AdapterMethods.Transform(self: Adapter, instance: Instance): any?
    -- Check class
    if not self:IsAllowedClass(instance) then
        return Pretty.Warn(`attempted to transform {instance:GetFullName()} but it is not an allowed class`,
            nil, `{self._typeName}.Transform`)
    end

    -- Is it here?
    local existing = self._cache[instance]
    if existing ~= nil then
        return existing
    end

    -- Transform it
    local success, result = pcall(self._transform, instance)
    if not success then
        return Pretty.Error(`failed to transform {instance:GetFullName()}: {result}`,
            nil, `{self._typeName}.Transform`)
    elseif result == nil then
        return Pretty.Warn(`transform returned nil for {instance:GetFullName()}`,
            nil, `{self._typeName}.Transform`)
    end

    -- Store and return
    self._cache[instance] = result
    self:_addReverse(instance, result)
    self.Added:Fire(instance)
    return result
end

function AdapterMethods.Release(self: Adapter, instance: Instance): ()
    local existing = self._cache[instance]
    if existing == nil then
        return Pretty.Warn(`attempted to release {instance:GetFullName()} but it is not in cache`,
            nil, `{self._typeName}.Release`)
    end
    if self._release ~= nil then
        local success, err: string? = pcall(self._release, instance, existing)
        if not success then
            Pretty.Warn(`failed to release {instance:GetFullName()}: {err}`,
                nil, `{self._typeName}.Release`)
        end
    end
    self:_removeReverse(instance, existing)
    self.Removing:Fire(instance)
    self._cache[instance] = nil
end

function AdapterMethods.Install(self: Adapter, instance: Instance, params: any): any?
    -- Check class
    if not self:IsAllowedClass(instance) then
        return Pretty.Warn(`attempted to install {instance:GetFullName()} but it is not an allowed class`,
            nil, `{self._typeName}.Install`)
    end

    -- Check if existing
    local existing = self._cache[instance]
    if existing ~= nil then
        return Pretty.Warn(`attempted to install {instance:GetFullName()} but it is already in cache`,
            nil, `{self._typeName}.Install`)
    elseif not self._install then
        return Pretty.Warn(`'{self.Tag}' Adapter does not support installation`,
            nil, `{self._typeName}.Install`)
    end

    -- Run
    local success, resp = pcall(self._install, instance, params)
    if not success then
        return Pretty.Warn(`errored whilst installing {instance:GetFullName()}: {resp}`,
            nil, `{self._typeName}.Install`)
    elseif not resp then
        return Pretty.Warn(`failed to install {instance:GetFullName()}`,
            nil, `{self._typeName}.Install`)
    end

    -- Transform, then add tag
    local result = self:Transform(instance)
    if result then
        CollectionService:AddTag(instance, self.Tag)
    else
        return Pretty.Warn(`failed to transform {instance:GetFullName()} after installation`,
            nil, `{self._typeName}.Install`)
    end
    return result
end

function AdapterMethods.IsAllowedClass(self: Adapter, className: string | Instance): boolean
    for _, allowed in ipairs(self._allowedClasses) do
        if typeof(className) == "Instance" and className:IsA(allowed) then
            return true
        elseif typeof(className) == "string" and className == allowed then
            return true
        end
    end
    return false
end

function AdapterMethods.FindByState(self: Adapter, state: any, throw: boolean?): any
    local bucket = self._reverse[state]
    local k = bucket and next(bucket) or nil
    if k == nil and throw then
        return Pretty.Error(`attempted to find by state but no matching instance found`,
            nil, `{self._typeName}.FindByState`)
    end
    return k
end

function AdapterMethods.FindAllByState(self: Adapter, state: any): {Instance}
    local found = {}
    local bucket = self._reverse[state]
    if not bucket then
        return found
    end
    for instance in pairs(bucket) do
        table.insert(found, instance)
    end
    return found
end

function AdapterMethods.All(self: Adapter, raw: boolean?): {[Instance]: any}
    return raw and self._cache or TableUtil.Copy(self._cache)
end

function AdapterMethods.Get(self: Adapter, instance: Instance, throw: boolean?): any
    local result = self._cache[instance]
    if result == nil and throw then
        return Pretty.Error(`attempted to get {instance:GetFullName()} but it is not in cache`,
            nil, `{self._typeName}.Get`)
    end
    return result
end

function AdapterMethods._destroy(self: Adapter): ()
    for instance in pairs(TableUtil.Copy(self._cache)) do
        self:Release(instance)
    end
    self._trove:Destroy()
    self.Added:Destroy()
    self.Removing:Destroy()
end

local AdapterClass = {}

function AdapterClass.new<T>(
    source: { Name: string },
    from: T,
    allowedClasses: {string}?
): T
    if typeof(from) ~= "table" then
        return Pretty.Error("expected table for adapter creation, got " .. typeof(from),
            script, "Adapter")
    end

    -- Just like Service!
    local middle = {
        -- Private data
        _allowedClasses = allowedClasses or { "Instance" },
        _trove = Trove.new(),
        _cache = {},
        _reverse = {},

        -- Public data
        Tag = source.Name,

        -- Events
        Added = Signal.new(),
        Removing = Signal.new()
    }

    setmetatable(middle, { __index = AdapterMethods })
    setmetatable(from :: any, { __index = middle })
    
    -- Now construct type instance
    local adapter = Type.instance(from, nil)

    -- If we're in studio, do not setup connections
    if RunService:IsStudio() and not RunService:IsRunning() then
        Pretty.Debug(`adapter '{adapter.Tag}' is not being initialised in Studio`,
            script, "Adapter")
        return adapter
    end

    -- Setup connections
    middle._trove:Add(Connect.NowAndFutureAsync(
        CollectionService:GetTagged(adapter.Tag),
        CollectionService:GetInstanceAddedSignal(adapter.Tag),
        function(instance: Instance): ()
            adapter:Transform(instance)
        end
    ))
    middle._trove:Add(CollectionService:GetInstanceRemovedSignal(adapter.Tag):Connect(function(instance: Instance): ()
        adapter:Release(instance)
    end))

    return adapter
end

return Type.class(AdapterClass, AdapterMethods)