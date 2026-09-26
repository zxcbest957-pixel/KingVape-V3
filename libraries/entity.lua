local Entity = {
    isAlive = false,
    character = {},
    List = {},
    Connections = {},
    PlayerConnections = {},
    EntityThreads = {},
    Running = false,
    Events = setmetatable({}, {
        __index = function(self, Name: string)
            self[Name] = {
                Connections = {},
                Connect = function(Event, Callback)
                    table.insert(Event.Connections, Callback)
                    return {
                        Disconnect = function()
                            local Index: number? = table.find(Event.Connections, Callback)
                            if Index then
                                table.remove(Event.Connections, Index)
                            end
                        end
                    }
                end,
                Fire = function(Event, ...)
                    for _, v: (...any) -> ...any in Event.Connections do
                        task.spawn(v, ...)
                    end
                end,
                Destroy = function(Event)
                    table.clear(Event.Connections)
                    table.clear(Event)
                end
            }

            return self[Name]
        end
    })
}

local cloneref = cloneref or function(Reference: Instance)
    return Reference
end
local Players: Players = cloneref(game:GetService("Players"))
local UserInputService: UserInputService = cloneref(game:GetService("UserInputService"))
local LocalPlayer: Player = Players.LocalPlayer
local GameCamera: Camera = workspace.CurrentCamera

local function GetMousePosition()
    if UserInputService.TouchEnabled then
        return GameCamera.ViewportSize / 2
    end

    return UserInputService.GetMouseLocation(UserInputService)
end

local function LoopClean(Table)
    for Key: any, v: any in Table do
        if type(v) == "table" then
            LoopClean(v)
        end

        Table[Key] = nil
    end
end

local function WaitForChildOfType(Object: Instance, Name: string, Timeout: number, Property: boolean?)
    local Deadline: number = tick() + Timeout
    local Returned
    repeat
        Returned = Property and Object[Name] or Object:FindFirstChildOfClass(Name)
        if Returned or Deadline < tick() then
            break
        end
        task.wait()
    until false
    return Returned
end

Entity.targetCheck = function(Entity)
    if Entity.TeamCheck then
        return Entity:TeamCheck()
    end
    if Entity.NPC then
        return true
    end
    if not LocalPlayer.Team then
        return true
    end
    if not Entity.Player.Team then
        return true
    end
    if Entity.Player.Team ~= LocalPlayer.Team then
        return true
    end
    return #Entity.Player.Team:GetPlayers() == #Players:GetPlayers()
end

Entity.getUpdateConnections = function(Entity)
    local Humanoid: Humanoid = Entity.Humanoid
    return {
        Humanoid:GetPropertyChangedSignal("Health"),
        Humanoid:GetPropertyChangedSignal("MaxHealth")
    }
end

local ForceFields = setmetatable({}, {__mode = "k"})

Entity.isVulnerable = function(Entity)
    if Entity.Health <= 0 then
        return false
    end

    local Character: Model = Entity.Character
    local Entry = ForceFields[Character]
    if not Entry then
        Entry = {Clock = 0, Value = false}
        ForceFields[Character] = Entry
    end

    local Now: number = os.clock()
    if (Now - Entry.Clock) >= 0.05 then
        Entry.Clock = Now
        Entry.Value = Character.FindFirstChildWhichIsA(Character, "ForceField") ~= nil
    end

    return not Entry.Value
end

Entity.getEntityColor = function(Entity)
    Entity = Entity.Player
    return Entity and tostring(Entity.TeamColor) ~= "White" and Entity.TeamColor.Color or nil
end

Entity.IgnoreObject = RaycastParams.new()
Entity.IgnoreObject.RespectCanCollide = true
local IgnoreList: {Instance} = {}
Entity.Raycast = function(Origin: Vector3, Direction: Vector3, Params: RaycastParams?)
    return workspace:Raycast(Origin, Direction, Params)
end
Entity.buildIgnore = function(Extra)
    table.clear(IgnoreList)
    table.insert(IgnoreList, GameCamera)
    table.insert(IgnoreList, LocalPlayer.Character)

    for _, Entity: any in Entity.List do
        if Entity.Targetable then
            table.insert(IgnoreList, Entity.Character)
        end
    end

    if typeof(Extra) == "table" then
        for _, v: Instance in Extra do
            table.insert(IgnoreList, v)
        end
    end

    Entity.IgnoreObject.FilterDescendantsInstances = IgnoreList
    return Entity.IgnoreObject
end
Entity.Wallcheck = function(Origin: Vector3, Position: Vector3, Ignore)
    if typeof(Ignore) ~= "RaycastParams" then
        Ignore = Entity.buildIgnore(Ignore)
    end
    return Entity.Raycast(Origin, Position - Origin, Ignore)
end

Entity.Priorities = {
    Players = function(v)
        return v.Entity.Player and 0 or 1
    end,
    NPCs = function(v)
        return v.Entity.Player and 1 or 0
    end,
    Closest = function(v)
        return v.Magnitude
    end,
    Farthest = function(v)
        return -v.Magnitude
    end,
    ["Lowest health"] = function(v)
        return v.Entity.Health
    end,
    ["Highest health"] = function(v)
        return -v.Entity.Health
    end,
    Crosshair = function(v)
        local Position, Visible = GameCamera.WorldToViewportPoint(GameCamera, v.Entity.RootPart.Position)
        return Visible and (Vector2.new(Position.X, Position.Y) - (GameCamera.ViewportSize / 2)).Magnitude or math.huge
    end
}

local function DefaultSort(A, B)
    return A.Magnitude < B.Magnitude
end

local RankedSort, RankedRank
local function RankedCompare(A, B)
    local RankA, RankB = RankedRank(A), RankedRank(B)
    if RankA ~= RankB then
        return RankA < RankB
    end
    return RankedSort(A, B)
end

local Scratch, ScratchDepth = {}, 0

local function OpenScratch()
    ScratchDepth += 1
    local Slot = Scratch[ScratchDepth]
    if not Slot then
        Slot = {List = {}, Pool = {}}
        Scratch[ScratchDepth] = Slot
    end
    table.clear(Slot.List)
    return Slot
end

local function CloseScratch(Slot)
    table.clear(Slot.List)
    ScratchDepth -= 1
end

local function AddCandidate(Slot, Entity, Magnitude: number)
    local Count: number = #Slot.List + 1
    local Entry = Slot.Pool[Count]
    if not Entry then
        Entry = {}
        Slot.Pool[Count] = Entry
    end
    Entry.Entity = Entity
    Entry.Magnitude = Magnitude
    Slot.List[Count] = Entry
end

Entity.getSort = function(EntitySettings)
    local Sort = EntitySettings.Sort or DefaultSort
    local Rank = Entity.Priorities[EntitySettings.Priority]
    if not Rank then
        return Sort
    end

    RankedSort, RankedRank = Sort, Rank
    return RankedCompare
end

Entity.EntityMouse = function(EntitySettings)
    if Entity.isAlive then
        local Slot = OpenScratch()
        local MouseLocation, SortingTable = EntitySettings.MouseOrigin or GetMousePosition(), Slot.List
        for _, Ent: any in Entity.List do
            if not EntitySettings.Players and Ent.Player then
                continue
            end
            if not EntitySettings.NPCs and Ent.NPC then
                continue
            end
            if not Ent.Targetable then
                continue
            end
            local Position, Visible = GameCamera.WorldToViewportPoint(GameCamera, Ent[EntitySettings.Part].Position)
            if not Visible then
                continue
            end
            local Magnitude: number = (MouseLocation - Vector2.new(Position.x, Position.y)).Magnitude
            if Magnitude > EntitySettings.Range then
                continue
            end
            if Entity.isVulnerable(Ent) then
                AddCandidate(Slot, Ent, Ent.Target and -1 or Magnitude)
            end
        end

        table.sort(SortingTable, Entity.getSort(EntitySettings))
        local WallParams = EntitySettings.Wallcheck and Entity.buildIgnore(EntitySettings.Wallcheck) or nil
        local Found

        for _, v: {Entity: any, Magnitude: number} in SortingTable do
            if WallParams then
                if Entity.Wallcheck(EntitySettings.Origin, v.Entity[EntitySettings.Part].Position, WallParams) then
                    continue
                end
            end
            if EntitySettings.Check and not EntitySettings.Check(v.Entity) then
                continue
            end
            Found = v.Entity
            break
        end

        CloseScratch(Slot)
        table.clear(EntitySettings)
        return Found
    end
    table.clear(EntitySettings)
end

Entity.EntityPosition = function(EntitySettings)
    if Entity.isAlive then
        local Slot = OpenScratch()
        local LocalPosition, SortingTable = EntitySettings.Origin or Entity.character.HumanoidRootPart.Position, Slot.List
        for _, Ent: any in Entity.List do
            if not EntitySettings.Players and Ent.Player then
                continue
            end
            if not EntitySettings.NPCs and Ent.NPC then
                continue
            end
            if not Ent.Targetable then
                continue
            end
            local Magnitude: number = (Ent[EntitySettings.Part].Position - LocalPosition).Magnitude
            if Magnitude > EntitySettings.Range then
                continue
            end
            if Entity.isVulnerable(Ent) then
                AddCandidate(Slot, Ent, Ent.Target and -1 or Magnitude)
            end
        end

        table.sort(SortingTable, Entity.getSort(EntitySettings))
        local WallParams = EntitySettings.Wallcheck and Entity.buildIgnore(EntitySettings.Wallcheck) or nil
        local Found

        for _, v: {Entity: any, Magnitude: number} in SortingTable do
            if WallParams then
                if Entity.Wallcheck(LocalPosition, v.Entity[EntitySettings.Part].Position, WallParams) then
                    continue
                end
            end
            Found = v.Entity
            break
        end

        CloseScratch(Slot)
        table.clear(EntitySettings)
        return Found
    end
    table.clear(EntitySettings)
end

Entity.AllPosition = function(EntitySettings)
    local Returned = {}
    if Entity.isAlive then
        local Slot = OpenScratch()
        local LocalPosition, SortingTable = EntitySettings.Origin or Entity.character.HumanoidRootPart.Position, Slot.List
        for _, Ent: any in Entity.List do
            if not EntitySettings.Players and Ent.Player then
                continue
            end
            if not EntitySettings.NPCs and Ent.NPC then
                continue
            end
            if not Ent.Targetable then
                continue
            end
            local Magnitude: number = (Ent[EntitySettings.Part].Position - LocalPosition).Magnitude
            if Magnitude > EntitySettings.Range then
                continue
            end
            if Entity.isVulnerable(Ent) then
                AddCandidate(Slot, Ent, Ent.Target and -1 or Magnitude)
            end
        end

        table.sort(SortingTable, Entity.getSort(EntitySettings))
        local WallParams = EntitySettings.Wallcheck and Entity.buildIgnore(EntitySettings.Wallcheck) or nil
        local Limit: number = EntitySettings.Limit or math.huge

        for _, v: {Entity: any, Magnitude: number} in SortingTable do
            if WallParams then
                if Entity.Wallcheck(LocalPosition, v.Entity[EntitySettings.Part].Position, WallParams) then
                    continue
                end
            end
            table.insert(Returned, v.Entity)
            if #Returned >= Limit then
                break
            end
        end
        CloseScratch(Slot)
    end
    table.clear(EntitySettings)
    return Returned
end

Entity.getEntity = function(Character)
    for i: number, Ent: any in Entity.List do
        if Ent.Player == Character or Ent.Character == Character then
            return Ent, i
        end
    end
end

Entity.addEntity = function(Character: Model?, Player: Player?, TeamFunction, SpawnTime: number?)
    if not Character then
        return
    end

    Entity.EntityThreads[Character] = task.spawn(function()
        local Humanoid: Humanoid? = WaitForChildOfType(Character, "Humanoid", 10)
        local RootPart: BasePart? = Humanoid and WaitForChildOfType(Humanoid, "RootPart", workspace.StreamingEnabled and 9e9 or 10, true)
        local Head: Instance? = Character:WaitForChild("Head", 10) or RootPart

        if Humanoid and RootPart then
            local Ent = {
                Connections = {},
                Character = Character,
                Health = Humanoid.Health,
                Head = Head,
                Humanoid = Humanoid,
                HumanoidRootPart = RootPart,
                HipHeight = Humanoid.HipHeight + (RootPart.Size.Y / 2) + (Humanoid.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
                MaxHealth = Humanoid.MaxHealth,
                NPC = Player == nil,
                Player = Player,
                RootPart = RootPart,
                SpawnTime = SpawnTime or 0,
                TeamCheck = TeamFunction
            }

            if Player == LocalPlayer then
                Entity.character = Ent
                Entity.isAlive = true
                Entity.Events.LocalAdded:Fire(Ent)
            else
                Ent.Targetable = Entity.targetCheck(Ent)

                for _, Signal: RBXScriptSignal in Entity.getUpdateConnections(Ent) do
                    table.insert(Ent.Connections, Signal:Connect(function()
                        Ent.Health = Humanoid.Health
                        Ent.MaxHealth = Humanoid.MaxHealth
                        Entity.Events.EntityUpdated:Fire(Ent)
                    end))
                end

                table.insert(Entity.List, Ent)
                Entity.Events.EntityAdded:Fire(Ent)
            end
        end

        Entity.EntityThreads[Character] = nil
    end)
end

Entity.removeEntity = function(Character, IsLocal: boolean?)
    if IsLocal then
        if Entity.isAlive then
            Entity.isAlive = false
            for _, v: RBXScriptConnection in Entity.character.Connections do
                v:Disconnect()
            end
            table.clear(Entity.character.Connections)
            Entity.Events.LocalRemoved:Fire(Entity.character)
        end

        return
    end

    if Character then
        if Entity.EntityThreads[Character] then
            task.cancel(Entity.EntityThreads[Character])
            Entity.EntityThreads[Character] = nil
        end

        local Ent, Index = Entity.getEntity(Character)
        if Index then
            for _, v: RBXScriptConnection in Ent.Connections do
                v:Disconnect()
            end

            table.clear(Ent.Connections)
            table.remove(Entity.List, Index)
            Entity.Events.EntityRemoved:Fire(Ent)
        end
    end
end

Entity.refreshEntity = function(Character, Player: Player?, SpawnTime: number?)
    local Ent = Entity.getEntity(Player)
    Entity.removeEntity(Character)
    Entity.addEntity(Character, Player, Ent and Ent.TeamCheck or nil, SpawnTime)
end

Entity.addPlayer = function(Player: Player)
    if Player.Character then
        Entity.refreshEntity(Player.Character, Player)
    end

    Entity.PlayerConnections[Player] = {
        Player.CharacterAdded:Connect(function(Character: Model)
            Entity.refreshEntity(Character, Player, os.clock() + 0.4)
        end),
        Player.CharacterRemoving:Connect(function(Character: Model)
            Entity.removeEntity(Character, Player == LocalPlayer)
        end),
        Player:GetPropertyChangedSignal("Team"):Connect(function()
            if Player == LocalPlayer then
                local Cloned = table.clone(Entity.List)
                for _, Ent: any in Cloned do
                    if Ent.Targetable ~= Entity.targetCheck(Ent) then
                        Entity.refreshEntity(Ent.Character, Ent.Player)
                    end
                end

                table.clear(Cloned)
            else
                local Ent = Entity.getEntity(Player)
                if Ent then
                    Entity.refreshEntity(Ent.Character, Player)
                end
            end
        end)
    }
end

Entity.removePlayer = function(Player: Player)
    if Entity.PlayerConnections[Player] then
        for _, v: RBXScriptConnection in Entity.PlayerConnections[Player] do
            v:Disconnect()
        end

        table.clear(Entity.PlayerConnections[Player])
        Entity.PlayerConnections[Player] = nil
    end

    Entity.removeEntity(Player)
end

Entity.start = function()
    if Entity.Running then
        Entity.stop()
    end

    Entity.Connections = {
        Players.PlayerAdded:Connect(function(Player: Player)
            Entity.addPlayer(Player)
        end),
        Players.PlayerRemoving:Connect(function(Player: Player)
            Entity.removePlayer(Player)
        end),
        workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            GameCamera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA("Camera")
        end)
    }

    for _, Player: Player in Players:GetPlayers() do
        Entity.addPlayer(Player)
    end

    Entity.Running = true
end

Entity.stop = function()
    for _, v: RBXScriptConnection in Entity.Connections do
        v:Disconnect()
    end

    for _, Connections: {RBXScriptConnection} in Entity.PlayerConnections do
        for _, v: RBXScriptConnection in Connections do
            v:Disconnect()
        end
        table.clear(Connections)
    end

    Entity.removeEntity(nil, true)
    local Cloned = table.clone(Entity.List)
    for _, Ent: any in Cloned do
        Entity.removeEntity(Ent.Character)
    end

    for _, Thread: thread in Entity.EntityThreads do
        task.cancel(Thread)
    end

    table.clear(Entity.PlayerConnections)
    table.clear(Entity.EntityThreads)
    table.clear(Entity.Connections)
    table.clear(Cloned)
    Entity.Running = false
end

Entity.kill = function()
    if Entity.Running then
        Entity.stop()
    end

    for _, Event: any in Entity.Events do
        Event:Destroy()
    end

    Entity.IgnoreObject:Destroy()
    LoopClean(Entity)
end

Entity.refresh = function()
    local Cloned = table.clone(Entity.List)
    for _, Ent: any in Cloned do
        Entity.refreshEntity(Ent.Character, Ent.Player)
    end
    table.clear(Cloned)
end

Entity.start()

return Entity