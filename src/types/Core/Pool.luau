
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- References
local Types = script:FindFirstAncestor("Types")

-- Modules
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Type = require(Types.Core.Type)

-- A collection of objects that can be reused to avoid unnecessary instantiation and destruction.
export type Pool<T = Instance> = Type.Type<{
    -- Private data
    _parent: Instance?,
    _inUse: {[T]: boolean?},
    _pool: {T},
    _free: {T},

    -- User-defined methods
    _create: () -> T,
    _reset: ((T) -> ())?,

    -- Helper methods
    GetSize: (self: Pool<T>) -> number,
    GetAvailable: (self: Pool<T>) -> number,
    GetInUse: (self: Pool<T>) -> number,
    IsInUse: (self: Pool<T>, obj: T) -> boolean,

    -- Control methods
    Acquire:
        ((self: Pool<T>) -> T?) &
        ((self: Pool<T>, grow: boolean) -> T),
    Release: (self: Pool<T>, obj: T) -> (),
    Shrink: (self: Pool<T>) -> (),
    Grow: (self: Pool<T>, n: number?) -> ()
}>
local PoolMethods = Type.methods("Pool", {} :: Pool)

function PoolMethods.GetSize(self: Pool): number
    return #self._pool
end

function PoolMethods.GetAvailable(self: Pool): number
    return #self._free
end

function PoolMethods.GetInUse(self: Pool): number
    return #self._pool - #self._free
end

function PoolMethods.IsInUse(self: Pool, obj: any): boolean
    return self._inUse[obj] == true
end

-- Acquires an object from the pool. If no objects are available, it will return nil.
-- If grow is true, it will create a new object and add it to the pool.
function PoolMethods.Acquire(self: Pool, grow: boolean?): any
    local obj = table.remove(self._free)
    if obj then
        self._inUse[obj] = true
        return obj
    end
    if grow then
        self:Grow()
        return self:Acquire(false)
    end
    return nil
end

-- Releases an object back into the pool.
function PoolMethods.Release(self: Pool, obj: any): ()
    if not self._inUse[obj] then
        return
    end
    if self._reset then
        local success, err: string? = pcall(self._reset, obj)
        if not success then
            Pretty.Warn(`error while resetting object: {err}`,
                nil, `{self._typeName}.Release`)
        end
    end
    self._inUse[obj] = nil
    if self._parent then
        obj.Parent = self._parent
    end
    table.insert(self._free, obj)
end

-- Collapses the pool by removing all objects that are not in use.
function PoolMethods.Shrink(self: Pool): ()
    local newFree = {}
    for i = #self._pool, 1, -1 do
        local obj = self._pool[i]
        if not self._inUse[obj] then
            table.remove(self._pool, i)
            self._inUse[obj] = nil
            pcall(obj.Destroy, obj)
        end
    end
    self._free = newFree
end

-- Grows the pool by creating n new objects and adding them to the pool.
function PoolMethods.Grow(self: Pool, n: number?): ()
    n = n or 1
    for i = 1, (n or 1) do
        local obj = self._create()
        if self._parent then
            obj.Parent = self._parent
        end
        table.insert(self._pool, obj)
        table.insert(self._free, obj)
    end
end

function PoolMethods._destroy(self: Pool): ()
    for _, obj in ipairs(self._pool) do
        pcall(obj.Destroy, obj)
    end
    table.clear(self._pool)
    table.clear(self._inUse)
    table.clear(self._free)
end

local PoolClass = {}

PoolClass.new = (function<T>(param: any, initialSize: number?, reset: ((Instance & T) -> ())?, parent: Instance?): Pool<T>
    -- Figure out create function
    local create: () -> Instance
    if typeof(param) == "string" then
        create = function(): Instance
            return Instance.new(param)
        end
    elseif typeof(param) == "function" then
        create = param
    elseif typeof(param) == "Instance" then
        create = function(): Instance
            return param:Clone()
        end
    else
        return Pretty.Error(`invalid parameter type '{typeof(param)}'`,
            script, "new")
    end

    -- Make initial pool
    local initialSize = math.max(initialSize or 0, 0)
    local pool = {}
    local free = {}
    for i = 1, initialSize do
        local obj = create()
        obj.Parent = parent or obj.Parent
        table.insert(pool, obj)
        table.insert(free, obj)
    end

    -- Construct self
    return Type.instance({
        _parent = parent,
        _inUse = {},
        _pool = pool,
        _free = free,
        _create = create,
        _reset = reset,
    }, PoolMethods) :: any
end) ::
    (<T>(typeName: string, initialSize: number?, reset: ((Instance & T) -> ())?, parent: Instance?) -> Pool<T>) &
    (<T>(create: () -> Instance & T, initialSize: number?, reset: ((Instance & T) -> ())?, parent: Instance?) -> Pool<T>) &
    (<T>(template: Instance & T, initialSize: number?, reset: ((Instance & T) -> ())?, parent: Instance?) -> Pool<T>)

return Type.class(PoolClass, PoolMethods)