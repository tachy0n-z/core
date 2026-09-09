
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Modules
local Types = require(ReplicatedStorage.Shared.Types)

-- Passes
local f = table.freeze

-- The shape returned by all initialise/cleanup helpers.
type Attempt<T = any> = {
    -- Essential
    TimeTaken: number,
    Total: number,

    -- Breakdown
    Successful: {T},
    Failures: {T},
    Errors: {[T]: string}
}

-- Constructs a new attempt object with the given data.
local function newAttempt<T>(start: number?, successful: {T}?, failures: {T}?, errors: {[T]: string}?): Attempt<T>
    return f({
        TimeTaken = start and os.clock() - start or 0,
        Total = #(successful or {}) + #(failures or {}),
        Successful = f(successful or {}),
        Failures = f(failures or {}),
        Errors = f(errors or {})
    })
end

local Bootstrap = {}

-- Requires all children under the given instance(s) and returns a list of successful and failed requires.
function Bootstrap.RequireAll(ignore: {Instance}, ...: Folder): ({Types.Service}, {string})
    local folders = {...}
    if #folders == 0 then
        return {}, {}
    end
    local successful, failures = {}, {}
    for _, folder in ipairs(folders) do
        for _, child in ipairs(folder:GetChildren()) do
            if table.find(ignore, child) ~= nil then
                continue
            end
            local success, resp = pcall(require, child)
            if not success then
                table.insert(failures, child.Name)
            elseif not Types.Is(resp) or not resp:IsA("Service") then
                table.insert(failures, child.Name)
            else
                table.insert(successful, resp)
            end
        end
    end
    return successful, failures
end

-- Initialises a list of services, returning an attempt object with the results.
function Bootstrap.InitialiseAll(timeout: number, ...: Types.Service<any>): Attempt
    timeout = math.clamp(timeout, 1, math.huge)

    -- Pack
    local services = {...}

    -- Setup state
    local now = os.clock()
    local successful: {any} = {}
    local failures: {any} = {}
    local errors: {[any]: string} = {}

    -- Attempt initialisation for each service
    local tasks = {}
    for i, service in ipairs(services) do
        tasks[i] = task.spawn(function(): ()
            local success, resp: any = pcall(function(): boolean
                return service:Initialise()
            end)
            if not success then
                errors[service] = resp
                table.insert(failures, service)
            elseif not resp then
                table.insert(failures, service)
            else
                table.insert(successful, service)
            end
        end)
    end
    
    -- Wait for completion
    repeat
        RunService.Heartbeat:Wait()
    until
        #successful + #failures == #services or
        os.clock() - now > timeout

    -- Cancel tasks
    for _, t in pairs(tasks) do
        task.cancel(t)
    end

    -- Insert errors for any services that didn't finish
    local successful = table.clone(successful)
    local failures = table.clone(failures)
    local errors = table.clone(errors)
    for _, service in ipairs(services) do
        if table.find(successful, service) == nil and table.find(failures, service) == nil then
            errors[service] = `timed out after {timeout} seconds`
            table.insert(failures, service)
        end
    end
    
    return newAttempt(now, successful, failures, errors)
end

-- Cleans up after a list of services, returning an attempt object with the results.
function Bootstrap.CleanupAll(timeout: number, ...: Types.Service<any>): Attempt
    local timeout = math.clamp(timeout, 1, math.huge)

    -- Pack
    local services = {...}

    -- Setup state
    local now = os.clock()
    local successful: {any} = {}
    local failures: {any} = {}
    local errors: {[any]: string} = {}

    -- Attempt cleanup for each service
    local tasks = {}
    for i, service in ipairs(services) do
        tasks[i] = task.spawn(function(): ()
            local success, err: string? = pcall(function(): ()
                service:Cleanup()
            end)
            if not success then
                errors[service] = err or "unknown error"
                table.insert(failures, service)
            else
                table.insert(successful, service)
            end
        end)
    end
    
    -- Wait for completion
    repeat
        RunService.Heartbeat:Wait()
    until
        #successful + #failures == #services or
        os.clock() - now > timeout

    -- Cancel tasks
    for _, t in pairs(tasks) do
        task.cancel(t)
    end

    -- Insert errors for any services that didn't finish
    local successful = table.clone(successful)
    local failures = table.clone(failures)
    local errors = table.clone(errors)
    for _, service in ipairs(services) do
        if table.find(successful, service) == nil and table.find(failures, service) == nil then
            errors[service] = `timed out after {timeout} seconds`
            table.insert(failures, service)
        end
    end
    
    return newAttempt(now, successful, failures, errors)
end

-- Returns true if all of the given services have been initialised, false otherwise.
function Bootstrap.DependNow(...: Types.Service<any>): boolean
    for _, service in ipairs({...}) do
        if not service:IsInitialised() then
            return false
        end
    end
    return true
end

-- Yields until the given services have been initialised.
function Bootstrap.DependUpon(...: Types.Service<any>): ()
    for _, service in ipairs({...}) do
        service:WaitForInitialised()
    end
end

-- Spawns a new task that will yield until the given services have been initialised, then calls the given function.
function Bootstrap.DependAndThen(f: () -> (), ...: Types.Service<any>): ()
    task.spawn(function(...: Types.Service<any>): ()
        Bootstrap.DependUpon(...)
        f()
    end, ...)
end

return f(Bootstrap)