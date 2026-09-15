
-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Pretty = require(ReplicatedStorage.Shared.Helpers.Pretty)
local Tree = require(ReplicatedStorage.Shared.Helpers.Tree)

-- Passes
local f = table.freeze

local AssetBuilder = {}

-- Applies the given list of properties to the given instance.
function AssetBuilder.Apply(inst: Instance, props: {[string]: any}): Instance
    for k, v in pairs(props) do
        local success, err: string? = pcall(function(): ()
            (inst :: any)[k] = v
        end)
        if not success then
            Pretty.Warn(`failed to apply property '{k}' on instance '{inst:GetFullName()}': {err}`,
                script, "Apply")
        end
    end
    return inst
end

-- Creates an instance of the given class and applies the given properties to it.
function AssetBuilder.Create(className: string, props: {[string]: any}): Instance
    local inst = Instance.new(className)
    return AssetBuilder.Apply(inst, props)
end

-- Makes the given asset preview-ready by making it fully visible-only.
function AssetBuilder.Preview<T>(model: Instance & T, anchored: boolean?): Instance & T
    local targets = TableUtil.Extend(Tree.GetDescendants(model), { model })
    for _, inst in ipairs(targets) do
        if inst:IsA("BasePart") then
            inst.CanCollide = false
            inst.CanQuery = false
            inst.CanTouch = false
            inst.Anchored = anchored or false
            inst.Massless = true
        end
    end
    return model
end

-- Converts the given model into a tool and uses its PrimaryPart as the handle.
function AssetBuilder.Backpack(target: BasePart | Model): Tool
    -- If a basepart, construct temporary model
    local model: Model
    if target:IsA("BasePart") then
        model = Instance.new("Model")
        target.Parent = model
        model.PrimaryPart = target
        model.Name = target.Name
    else
        model = target
    end

    -- Construct tool
    local tool = Instance.new("Tool")
    tool.Name = model.Name

    -- Move primary part into tool
    local prim = model.PrimaryPart
    local descendants = model:GetDescendants()
    if prim then
        prim.Parent = tool
        prim.Name = "Handle"
        prim.CanCollide = false
        prim.Anchored = false
        model.PrimaryPart = nil
        tool.PrimaryPart = prim
    else
        return Pretty.Error(`failed to find PrimaryPart for '{model.Name}'`,
            script, "Backpack")
    end

    -- Weld all parts to primary part
    for _, part in ipairs(descendants) do
        if part:IsA("BasePart") and part ~= prim then
            local weld = Instance.new("WeldConstraint")
            weld.Part0 = prim
            weld.Part1 = part
            weld.Parent = prim
            part.CanCollide = false
            part.Anchored = false
        end
    end

    -- Finally, parent
    model.Parent = tool

    return tool
end

-- Converts an Accessory into a Model, typically for previewing purposes.
function AssetBuilder.AccessoryToModel(accessory: Accessory): Model
    local model = Instance.new("Model")
    model.Name = accessory.Name
    local handle = accessory:FindFirstChild("Handle")
    if handle and handle:IsA("BasePart") then
        handle.Parent = model
        model.PrimaryPart = handle
    else
        return Pretty.Error(`failed to find Handle for '{accessory.Name}'`,
            script, "AccessoryToModel")
    end
    for _, child in ipairs(accessory:GetChildren()) do
        child.Parent = model
    end
    accessory:Destroy()
    return model
end

-- Creates a ghost model at the given CFrame with the provided size.
-- Ghosts are essentially invisible parts that are overriden with a visualisation client-side.
function AssetBuilder.Ghost(bounds: Vector3, at: CFrame?, pivotOffset: CFrame?): Part
    return AssetBuilder.Create("Part", {
        Name = "Ghost",
        Size = bounds,
        Transparency = 1,
        Massless = true,
        CanCollide = false,
        CanQuery = true,
        CanTouch = false,
        CFrame = at or CFrame.identity,
        PivotOffset = pivotOffset or CFrame.identity
    }) :: Part
end

return f(AssetBuilder)
