if not get_comm_channel or not create_comm_channel then
    return "1"
end

local cloneref = cloneref or function(Reference: Instance)
    return Reference
end
local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local RunService: RunService = cloneref(game:GetService("RunService"))
local IsActor = ...
local Id, CommChannel
if IsActor then
    Id, CommChannel = IsActor, get_comm_channel(IsActor)
else
    Id, CommChannel = create_comm_channel()
end
local DrawingRefs, Queued, Thread = {}, {}
IsActor = IsActor and true or false
local Classes: {[string]: {string}} = {
    Base = {
        "Visible",
        "ZIndex",
        "Transparency",
        "Color"
    },
    Line = {
        "Thickness",
        "From",
        "To"
    },
    Text = {
        "Text",
        "Size",
        "Center",
        "Outline",
        "OutlineColor",
        "Position",
        "TextBounds",
        "Font"
    },
    Image = {
        "Data",
        "Size",
        "Position",
        "Rounding"
    },
    Circle = {
        "Thickness",
        "NumSides",
        "Radius",
        "Filled",
        "Position"
    },
    Square = {
        "Thickness",
        "Size",
        "Position",
        "Filled"
    },
    Quad = {
        "Thickness",
        "PointA",
        "PointB",
        "PointC",
        "PointD",
        "Filled"
    },
    Triangle = {
        "Thickness",
        "PointA",
        "PointB",
        "PointC",
        "Filled"
    }
}

CommChannel.Event:Connect(function(...)
    local ForActor, Action = ...
    local Arguments = {select(3, ...)}
    if IsActor and ForActor then
        if Action == "new" then
            local Proxy = newproxy(true)
            local Meta = getmetatable(Proxy)
            local RealObject = {Changed = {}}

            function RealObject:Remove()
                CommChannel:Fire(false, "remove", Arguments[2])
                DrawingRefs[Arguments[2]] = nil
            end

            Meta.__index = RealObject
            Meta.__newindex = function(_, Key, Value)
                rawset(RealObject.Changed, Key, Value)
                return rawset(RealObject, Key, Value)
            end

            for Property: string, v: any in Arguments[1] do
                rawset(RealObject, Property, v)
            end
            DrawingRefs[Arguments[2]] = Proxy
            Queued[Arguments[3]] = Proxy
        elseif Action == "update" then
            for Reference: string, Changes: {[string]: any} in Arguments[1] do
                local Object = DrawingRefs[Reference]
                if Object then
                    for Property: string, Value: any in Changes do
                        rawset(getmetatable(Object).__index, Property, Value)
                    end
                end
            end
        end
    else
        if Action == "new" then
            local Object = Drawing.new(Arguments[1])
            local Reference: string = HttpService:GenerateGUID():sub(1, 6)
            local Properties = {}
            for _, v: string in Classes.Base do
                Properties[v] = Object[v]
            end
            for _, v: string in Classes[Arguments[1]] do
                Properties[v] = Object[v]
            end
            DrawingRefs[Reference] = Object
            CommChannel:Fire(true, "new", Properties, Reference, Arguments[2])
        elseif Action == "update" then
            for Reference: string, Changes: {[string]: any} in Arguments[1] do
                local Object = DrawingRefs[Reference]
                if Object then
                    for Property: string, Value: any in Changes do
                        Object[Property] = Value
                    end
                end
            end
        elseif Action == "remove" then
            local Object = DrawingRefs[Arguments[1]]
            if Object then
                pcall(function()
                    Object:Remove()
                end)
                DrawingRefs[Arguments[1]] = nil
            end
        end
    end
end)

if IsActor and not Drawing then
    Thread = task.spawn(function()
        repeat
            local Changed, HasChanges = {}
            for Reference: string, Object: any in DrawingRefs do
                for Property: string, Value: any in Object.Changed do
                    if not Changed[Reference] then
                        Changed[Reference] = {}
                        HasChanges = true
                    end
                    rawset(Changed[Reference], Property, Value)
                end
                if Changed[Reference] then
                    table.clear(Object.Changed)
                end
            end

            if HasChanges then
                CommChannel:Fire(false, "update", Changed)
            end
            RunService.RenderStepped:Wait()
        until false
    end)

    getgenv().Drawing = {
        new = function(ObjectType: string)
            local NewId: string = HttpService:GenerateGUID(true):sub(1, 6)
            CommChannel:Fire(false, "new", ObjectType, NewId)
            repeat
                task.wait()
            until Queued[NewId]
            local Object = Queued[NewId]
            Queued[NewId] = nil
            return Object
        end,
        kill = function()
            task.cancel(Thread)
            for _, v: any in DrawingRefs do
                pcall(function()
                    v:Remove()
                end)
            end
            table.clear(DrawingRefs)
        end
    }
else
    return Id
end