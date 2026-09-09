
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- References
local Types = script:FindFirstAncestor("Types")

-- Modules
local Signal = require(Types.Core.Signal)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Type = require(Types.Core.Type)

-- A instance-bound key-value store primarily used for asset loading and caching.
-- Supports child added and removed events, so can be used outside of simple asset registry.
export type Library<T = any> = Type.Type<{
    -- Private data
    _lastBound: Instance?,
    _bound: Instance?,
    _cache: {[string]: T},
    _trove: typeof(Trove.new()),

    -- Events
    Changed: Signal.Signal<string, T?>,

    -- User-defined methods
    _load: (obj: Instance, ref: Library<T>?) -> T?,

    -- Binding methods
    GetLastBound: (self: Library<T>) -> Instance?,
    IsBound: (self: Library<T>) -> boolean,
    Bind: (self: Library<T>, obj: Instance) -> number,
    Unbind: (self: Library<T>) -> (),
    
    -- Access methods
    Exists: (self: Library<T>, key: string) -> boolean,
    All: (self: Library<T>, raw: boolean?) -> {[string]: T},
    Get:
        ((self: Library<T>, key: string) -> T?) &
        ((self: Library<T>, key: string, default: T) -> T)
}>
local LibraryMethods = Type.methods("Library", {} :: Library)

function LibraryMethods.GetLastBound(self: Library): Instance?
    return self._lastBound
end

function LibraryMethods.IsBound(self: Library): boolean
    return self._bound ~= nil
end

function LibraryMethods.Bind(self: Library, obj: Instance): number
    -- Clear prior data
    self._lastBound = self._bound
    self:Unbind()

    -- Bind to new object
    local successful = 0
    self._bound = obj
    local function load(child: Instance): ()
        if self._cache[child.Name] ~= nil then
            Pretty.Warn(`duplicate child '{child.Name}' found in '{obj:GetFullName()}', ignoring`,
                nil, `{self._typeName}.Bind`)
            return
        end
        local value = self._load(child, self)
        if value ~= nil then
            self._cache[child.Name] = value
            self.Changed:Fire(child.Name, value)
            successful += 1
        else
            Pretty.Warn(`failed to load '{child.Name}' from '{obj:GetFullName()}'`,
                nil, `{self._typeName}.Bind`)
        end
    end
    for _, child in ipairs(obj:GetChildren()) do
        load(child)
    end
    self._trove:Add(obj.ChildAdded:Connect(load))
    self._trove:Add(obj.ChildRemoved:Connect(function(child: Instance)
        if self._cache[child.Name] ~= nil then
            self._cache[child.Name] = nil
            self.Changed:Fire(child.Name, nil)
        end
    end))

    return successful
end

function LibraryMethods.Unbind(self: Library): ()
    for k in self._cache do
        self.Changed:Fire(k, nil)
    end
    table.clear(self._cache)
    self._trove:Clean()
    self._bound = nil
end

function LibraryMethods.Exists(self: Library, key: string): boolean
    return self._cache[key] ~= nil
end

function LibraryMethods.All(self: Library, raw: boolean?): {[string]: any}
    if raw then
        return self._cache
    else
        local copy = {}
        for key, value in self._cache do
            copy[key] = value
        end
        return copy
    end
end

function LibraryMethods.Get(self: Library, key: string, default: any?): any?
    local v = self._cache[key]
    return if v ~= nil then v else default
end

function LibraryMethods._destroy(self: Library): ()
    self._trove:Destroy()
    self.Changed:Destroy()
end

-- Like Library, but does not populate on bind or detect additions/removals.
export type StaticLibrary<T = any> = Library<T> & {
    -- Methods
    Populate: (self: StaticLibrary<T>) -> number
}
local StaticLibraryMethods = Type.methods("StaticLibrary", {} :: StaticLibrary, LibraryMethods)

function StaticLibraryMethods.Bind(self: Library, obj: Instance): number
    self._lastBound = self._bound
    self:Unbind()
    self._bound = obj
    return 0
end

function StaticLibraryMethods.Populate(self: StaticLibrary): number
    if not self._bound then
        Pretty.Warn("attempt to populate deferred library but not bound",
            nil, `{self._typeName}.Populate`)
        return 0
    end
    local successful = 0
    for _, child in ipairs(self._bound:GetChildren()) do
        if self._cache[child.Name] == nil then
            local value = self._load(child, self)
            if value ~= nil then
                self._cache[child.Name] = value
                self.Changed:Fire(child.Name, value)
                successful += 1
            else
                Pretty.Warn(`failed to load '{child.Name}' from '{self._bound:GetFullName()}'`,
                    nil, `{self._typeName}.Populate`)
            end
        end
    end
    return successful
end

-- Just like Library, but lazily loads values on demand instead of preloading them all at once.
-- Inherits from Library, so all methods are available.
-- All() only returns the currently loaded values, not all possible values.
export type LazyLibrary<T = any> = Library<T>
local LazyLibraryMethods = Type.methods("LazyLibrary", {} :: LazyLibrary, LibraryMethods)

function LazyLibraryMethods.Bind(self: LazyLibrary, obj: Instance): number
    -- Clear prior data
    self._lastBound = self._bound
    self:Unbind()

    -- Bind to new object
    self._bound = obj

    -- Only detect removals
    self._trove:Add(obj.ChildRemoved:Connect(function(child: Instance)
        if self._cache[child.Name] ~= nil then
            self._cache[child.Name] = nil
            self.Changed:Fire(child.Name, nil)
        end
    end))

    return 0
end

function LazyLibraryMethods.Get(self: LazyLibrary, key: string, default: any?): any?
    local v = self._cache[key]
    if v == nil and self._bound then
        local child = self._bound:FindFirstChild(key)
        if child then
            v = self._load(child, self)
            if v ~= nil then
                self._cache[key] = v
                self.Changed:Fire(key, v)
                return v
            else
                Pretty.Warn(`failed to load '{child.Name}' from '{self._bound:GetFullName()}'`,
                    nil, `{self._typeName}.Get`)
            end
        end
    end
    return if v ~= nil then v else default
end

local LibraryClass = {}

-- Creates a new Library instance.
-- Supports an optional instant bind parameter.
function LibraryClass.new<T>(load: (obj: Instance, ref: Library<T>?) -> T?, bindTo: Instance?): Library<T>
    -- Construct self
    local self: Library<T> = Type.instance({
        -- Private data
        _bound = nil,
        _cache = {},
        _trove = Trove.new(),

        -- Events
        Changed = Signal.new(),

        -- User-defined methods
        _load = load
    }, LibraryMethods) :: any

    -- Bind if requested
    if bindTo then
        self:Bind(bindTo)
    end

    return self
end

-- Creates a new StaticLibrary instance.
-- Supports an optional instant bind parameter.
function LibraryClass.newStatic<T>(load: (obj: Instance, ref: StaticLibrary<T>?) -> T?, bindTo: Instance?): StaticLibrary<T>
    -- Construct as normal
    local self = LibraryClass.new(load :: any, nil) :: any

    -- Redirect mt
    setmetatable(self, { __index = StaticLibraryMethods })
    if bindTo then
        self:Bind(bindTo)
    end

    return self
end

-- Creates a new LazyLibrary instance.
-- Supports an optional instant bind parameter.
function LibraryClass.newLazy<T>(load: (obj: Instance, ref: LazyLibrary<T>?) -> T?, bindTo: Instance?): LazyLibrary<T>
    -- Construct as normal
    local self = LibraryClass.new(load :: any, nil) :: any
    
    -- Redirect mt and bind
    setmetatable(self, { __index = LazyLibraryMethods })
    if bindTo then
        self:Bind(bindTo)
    end

    return self
end

return Type.class(LibraryClass, LibraryMethods)