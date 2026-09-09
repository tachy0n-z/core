
-- Core/
local Signal = require(script.Core.Signal)
export type Connection = Signal.Connection
export type Signal<A... = ...any> = Signal.Signal<A...>
local Type = require(script.Core.Type)
export type Type<T = {}> = Type.Type<T>
local Enum = require(script.Core.Enum)
export type Enum<M = {}, T = {}> = Enum.Enum<M, T>
local Service = require(script.Core.Service)
export type Service<T = {}> = Service.Service<T>
local Library = require(script.Core.Library)
export type Library<T = any> = Library.Library<T>
export type StaticLibrary<T = any> = Library.StaticLibrary<T>
export type LazyLibrary<T = any> = Library.LazyLibrary<T>
local Pool = require(script.Core.Pool)
export type Pool<T = Instance> = Pool.Pool<T>
local Adapter = require(script.Core.Adapter)
export type Adapter<I = Instance, O = any, P = any, T = {}> = Adapter.Adapter<I, O, P, T>

-- Data/
local Record = require(script.Data.Record)
export type Record<T = {}> = Record.Record<T>
local Definition = require(script.Data.Definition)
export type DefinitionSubClass<T = {}, M = {}> = Definition.DefinitionSubClass<T, M>
-- Data/Wraps/
local ValueWrap = require(script.Data.Wraps.ValueWrap)
export type ValueWrap<T = any> = ValueWrap.ValueWrap<T>
local TableWrap = require(script.Data.Wraps.TableWrap)
export type TableWrap<K, V> = TableWrap.TableWrap<K, V>
-- Data/Records/
local UserDataRecord = require(script.Data.Records.UserDataRecord)
export type UserDataRecord = UserDataRecord.UserDataRecord
local SessionDataRecord = require(script.Data.Records.SessionDataRecord)
export type SessionDataRecord = SessionDataRecord.SessionDataRecord

local Types = {
    Signal = Signal,
    Type = Type,
    Enum = Enum,
    Service = Service,
    Library = Library,
    Pool = Pool,
    Adapter = Adapter,
    Record = Record,
    Definition = Definition,
    ValueWrap = ValueWrap,
    TableWrap = TableWrap,
    UserDataRecord = UserDataRecord,
    SessionDataRecord = SessionDataRecord
}

-- Aliases
Types.Is = Type.Is
Types.IsClass = Type.IsClass
Types.IsMethods = Type.IsMethods

Types.Validator = (function(type: any): (obj: any) -> boolean
    local typeName = typeof(type) == "string"
        and type
        or type._typeName
    return function(obj: any): boolean
        return Type.Is(obj) and obj:IsA(typeName)
    end
end) ::
    ((typeName: string) -> (obj: any) -> boolean) &
    ((typeMethods: Type) -> (obj: any) -> boolean)

return table.freeze(Types)