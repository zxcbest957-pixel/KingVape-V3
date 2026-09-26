local Run = function(Func: () -> ())
    Func()
end
local cloneref = cloneref or function(Reference: Instance)
    return Reference
end
local VapeEvents = setmetatable({}, {
    __index = function(self, Index: string)
        self[Index] = Instance.new("BindableEvent")
        return self[Index]
    end
})

local Players: Players = cloneref(game:GetService("Players"))
local UserInputService: UserInputService = cloneref(game:GetService("UserInputService"))
local ReplicatedStorage: ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local ReplicatedFirst: ReplicatedFirst = cloneref(game:GetService("ReplicatedFirst"))
local CollectionService: CollectionService = cloneref(game:GetService("CollectionService"))
local MarketplaceService: MarketplaceService = cloneref(game:GetService("MarketplaceService"))
local TextChatService: TextChatService = cloneref(game:GetService("TextChatService"))
local TweenService: TweenService = cloneref(game:GetService("TweenService"))
local RunService: RunService = cloneref(game:GetService("RunService"))
local GuiService: GuiService = cloneref(game:GetService("GuiService"))
local Teams: Teams = cloneref(game:GetService("Teams"))
local CoreGui: CoreGui = cloneref(game:GetService("CoreGui"))

local Camera: Camera = workspace.CurrentCamera
local LocalPlayer: Player = Players.LocalPlayer
local vape = shared.vape
local Entity = vape.Libraries.entity
local Whitelist = vape.Libraries.whitelist
local TargetInfo = vape.Libraries.targetinfo
local SessionInfo = vape.Libraries.sessioninfo
local GetFontBounds = vape.Libraries.getfontbounds
local GetVapeAsset = vape.Libraries.getvapeasset

local PrisonLife = {}
local Spring = {}
local TracerHook = {Hooks = {}}
local OldShoot, OldEquip
local AimTimer, ShootTimer, AimVector = os.clock(), os.clock()
local ArrestCooldown: number = os.clock()
local TempTargets = {}
local Gamepasses = {}

local function CheckPoint(Position: Vector3, Params: OverlapParams)
    for _, v: BasePart in workspace:GetPartBoundsInRadius(Position, 0, Params) do
        if v.CanCollide and (v:GetClosestPointOnSurface(Position) - Position).Magnitude <= 0 then
            return false
        end
    end

    return true
end

local function CanClick()
    local MousePosition: Vector2 = (UserInputService:GetMouseLocation() - GuiService:GetGuiInset())
    for _, v: GuiObject in LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(MousePosition.X, MousePosition.Y) do
        local Gui = v:FindFirstAncestorOfClass("ScreenGui")
        if v.Active and v.Visible and Gui and Gui.Enabled then
            return false
        end
    end
    for _, v: GuiObject in CoreGui:GetGuiObjectsAtPosition(MousePosition.X, MousePosition.Y) do
        local Gui = v:FindFirstAncestorOfClass("ScreenGui")
        if v.Active and v.Visible and Gui and Gui.Enabled then
            return false
        end
    end
    return (not vape.gui.ScaledGui.ClickGui.Visible) and (not UserInputService:GetFocusedTextBox())
end

local function IsFriend(Player: Player, Recolor: boolean?)
    if vape.Categories.Friends.Options["Use friends"].Enabled then
        local Friend = table.find(vape.Categories.Friends.ListEnabled, Player.Name) and true
        if Recolor then
            Friend = Friend and vape.Categories.Friends.Options["Recolor visuals"].Enabled
        end
        return Friend
    end
    return nil
end

local function IsTarget(Player: Player)
    return (table.find(vape.Categories.Targets.ListEnabled, Player.Name) or TempTargets[Player.Name]) and true
end

local function SendNotification(...)
    return vape:CreateNotification(...)
end

local function RemoveTags(Text: string)
    Text = Text:gsub("<br%s*/>", "\n")
    return (Text:gsub("<[^<>]->", ""))
end

local OriginScanner = {Cache = {}}
Run(function()
    local RayParams: RaycastParams = RaycastParams.new()
    local OverlapCheck: OverlapParams = OverlapParams.new()
    RayParams.CollisionGroup = "ClientBullet"
    RayParams.FilterType = Enum.RaycastFilterType.Exclude
    OverlapCheck.CollisionGroup = "ClientBullet"
    OverlapCheck.FilterType = Enum.RaycastFilterType.Exclude
    OriginScanner.Ray = RayParams

    local Positions: {Vector3} = {
        Vector3.new(0, 1, 0),
        Vector3.new(1, 0, 0),
        Vector3.new(0.7, -0.5, -0.5),
        Vector3.new(-0.1, -0.8, -0.8),
        Vector3.new(-0.8, -0.5, -0.5),
        Vector3.new(-1, 0, 0),
        Vector3.new(-0.8, 0.4, 0.4),
        Vector3.new(0, 0.7, 0.7),
        Vector3.new(0.7, 0.5, 0.5),
        Vector3.new(1, 0, 0),
        Vector3.new(0.7, 0, -0.8),
        Vector3.new(-0.1, 0, -1),
        Vector3.new(-0.8, 0, -0.8),
        Vector3.new(-1, 0, 0),
        Vector3.new(-0.8, 0, 0.7),
        Vector3.new(0, 0, 1),
        Vector3.new(0.7, 0, 0.7),
        Vector3.new(1, 0, 0),
        Vector3.new(0.7, 0.4, -0.5),
        Vector3.new(-0.1, 0.7, -0.8),
        Vector3.new(-0.8, 0.4, -0.5),
        Vector3.new(-1, -0.1, 0),
        Vector3.new(-0.8, -0.5, 0.4),
        Vector3.new(0, -0.8, 0.7),
        Vector3.new(0.7, -0.6, 0.5),
        Vector3.new(0, -1, 0)
    }

    function OriginScanner:Scan(Origin: Vector3, Target: Vector3, Extra: Vector3?, Part)
        local ScanPositions: {Vector3} = {}
        local HitboxPositions: {Vector3} = {}
        local ReturnHitbox
        local Direction: Vector3 = CFrame.lookAt(Origin * Vector3.new(1, 0, 1), Target * Vector3.new(1, 0, 1)).LookVector

        if OriginScanner.Cache[Part] then
            return table.unpack(OriginScanner.Cache[Part])
        end

        if Extra then
            if (Origin - Extra).Magnitude < 7.5 then
                table.insert(ScanPositions, Extra)
            else
                table.insert(HitboxPositions, Target)
                for _, v: Enum.NormalId in Enum.NormalId:GetEnumItems() do
                    local Normal: Vector3 = Vector3.fromNormalId(v)

                    if (Normal * Vector3.new(1, 0, 1)):Dot(-Direction) > -0.5 then
                        local Position: Vector3 = Target + Normal * 6

                        if CheckPoint(Position, OverlapCheck) then
                            table.insert(HitboxPositions, Position)
                        end
                    end
                end
            end
        end

        if #ScanPositions <= 0 then
            for _, v: Vector3 in Positions do
                if (v * Vector3.new(1, 0, 1)):Dot(Direction) > -0.5 then
                    table.insert(ScanPositions, Origin + v * 6)
                end
            end
        end

        if #HitboxPositions > 0 then
            for _, Hitbox: Vector3 in HitboxPositions do
                for _, Position: Vector3 in ScanPositions do
                    local WallRay: RaycastResult? = workspace:Raycast(Hitbox, (Position - Hitbox), RayParams)

                    if not WallRay and CheckPoint(Position, OverlapCheck) then
                        OriginScanner.Cache[Part] = {Position, Hitbox}
                        return Position, Hitbox
                    end
                end
            end
        else
            for _, Position: Vector3 in ScanPositions do
                local WallRay: RaycastResult? = workspace:Raycast(Target, (Position - Target), RayParams)

                if not WallRay and CheckPoint(Position, OverlapCheck) then
                    OriginScanner.Cache[Part] = {Position}
                    return Position
                end
            end
        end
    end

    function OriginScanner:UpdateIgnore()
        local Ignore: {Instance} = {LocalPlayer.Character}
        for _, EntityData: any in Entity.List do
            table.insert(Ignore, EntityData.Character)
        end

        RayParams.FilterDescendantsInstances = Ignore
        OverlapCheck.FilterDescendantsInstances = Ignore
    end
end)

local CheatFlags = {Flags = {}, Flagged = {}}
Run(function()
    function CheatFlags:Flag(Player: Player, FlagType: string, Limit: number)
        if CheatFlags.Flagged[Player.UserId] then
            return
        end

        if not CheatFlags.Flags[Player.UserId] then
            CheatFlags.Flags[Player.UserId] = {}
        end

        local Flags = CheatFlags.Flags[Player.UserId]
        Flags[FlagType] = (Flags[FlagType] or 0) + 1

        if Flags[FlagType] > Limit then
            CheatFlags.Flagged[Player.UserId] = true
            VapeEvents.CheatFlagged:Fire(Player, FlagType)
        end
    end

    function CheatFlags:Clear()
        table.clear(CheatFlags.Flags)
        table.clear(CheatFlags.Flagged)
    end
end)

Run(function()
    local function GetMousePosition()
        if UserInputService.TouchEnabled then
            return Camera.ViewportSize / 2
        end
        return UserInputService.GetMouseLocation(UserInputService)
    end

    Entity.getUpdateConnections = function(EntityData)
        local Humanoid: Humanoid = EntityData.Humanoid
        return {
            Humanoid:GetPropertyChangedSignal("Health"),
            Humanoid:GetPropertyChangedSignal("MaxHealth"),
            EntityData.Character:GetAttributeChangedSignal("Trespassing"),
            EntityData.Character:GetAttributeChangedSignal("Hostile"),
            EntityData.Player:GetAttributeChangedSignal("InnocentKills"),
            {
                Connect = function()
                    EntityData.Friend = EntityData.Player and IsFriend(EntityData.Player) or nil
                    EntityData.Target = EntityData.Player and IsTarget(EntityData.Player) or nil
                    return {Disconnect = function() end}
                end
            }
        }
    end

    Entity.targetCheck = function(EntityData)
        if EntityData.TeamCheck then
            return EntityData:TeamCheck()
        end
        if EntityData.NPC then
            return true
        end
        if IsFriend(EntityData.Player) then
            return false
        end
        if not select(2, Whitelist:get(EntityData.Player)) then
            return false
        end
        if vape.Settings.Modules.Options["Teams by server"].Enabled then
            return LocalPlayer.Team ~= EntityData.Player.Team and EntityData.Player.Team ~= Teams.Neutral
        end
        return true
    end

    Entity.isVulnerable = function(EntityData, AttackCheck: boolean?)
        if AttackCheck and LocalPlayer.Team == Teams.Guards and EntityData.Player.Team == Teams.Inmates and not EntityData.Character:GetAttribute("Hostile") then
            return false
        end

        return EntityData.Health > 0 and EntityData.Humanoid:GetState() ~= Enum.HumanoidStateType.Dead and EntityData.SpawnTime < os.clock() and not EntityData.Character.FindFirstChildWhichIsA(EntityData.Character, "ForceField") and (EntityData.Player.Team ~= Teams.Inmates or (EntityData.Character:GetAttribute("Trespassing") or EntityData.Character:GetAttribute("Hostile")))
    end

    Entity.EntityMouse = function(EntitySettings)
        if Entity.isAlive then
            local MouseLocation, SortingTable = EntitySettings.MouseOrigin or GetMousePosition(), {}
            local LocalPosition: Vector3 = EntitySettings.Origin or Entity.character.HumanoidRootPart.Position
            for _, EntityData: any in Entity.List do
                if not EntitySettings.Players and EntityData.Player then
                    continue
                end
                if not EntitySettings.NPCs and EntityData.NPC then
                    continue
                end
                if not EntityData.Targetable then
                    continue
                end
                local Position, Visible = Camera.WorldToViewportPoint(Camera, EntityData[EntitySettings.Part].Position)
                if not Visible then
                    continue
                end
                local Distance: number = (MouseLocation - Vector2.new(Position.x, Position.y)).Magnitude
                if Distance > EntitySettings.Range then
                    continue
                end
                if Entity.isVulnerable(EntityData, EntitySettings.AttackCheck) then
                    if EntitySettings.RangePosition then
                        local PositionDistance: number = (EntityData[EntitySettings.Part].Position - LocalPosition).Magnitude
                        if PositionDistance > EntitySettings.RangePosition then
                            continue
                        end
                    end

                    table.insert(SortingTable, {
                        Entity = EntityData,
                        Magnitude = EntityData.Target and -1 or Distance
                    })
                end
            end

            table.sort(SortingTable, EntitySettings.Sort or function(A, B)
                return A.Magnitude < B.Magnitude
            end)

            for _, v: {Entity: any, Magnitude: number} in SortingTable do
                if EntitySettings.Wallcheck then
                    if Entity.Wallcheck(EntitySettings.Origin, v.Entity[EntitySettings.Part].Position, EntitySettings.Wallbang, v.Entity[EntitySettings.Part]) then
                        continue
                    end
                end
                table.clear(EntitySettings)
                table.clear(SortingTable)
                return v.Entity
            end
            table.clear(SortingTable)
        end
        table.clear(EntitySettings)
    end

    Entity.EntityPosition = function(EntitySettings)
        if Entity.isAlive then
            local LocalPosition, SortingTable = EntitySettings.Origin or Entity.character.HumanoidRootPart.Position, {}
            for _, EntityData: any in Entity.List do
                if not EntitySettings.Players and EntityData.Player then
                    continue
                end
                if not EntitySettings.NPCs and EntityData.NPC then
                    continue
                end
                if not EntityData.Targetable then
                    continue
                end
                local Distance: number = (EntityData[EntitySettings.Part].Position - LocalPosition).Magnitude
                if Distance > EntitySettings.Range then
                    continue
                end
                if Entity.isVulnerable(EntityData, EntitySettings.AttackCheck) then
                    table.insert(SortingTable, {
                        Entity = EntityData,
                        Magnitude = EntityData.Target and -1 or Distance
                    })
                end
            end

            table.sort(SortingTable, EntitySettings.Sort or function(A, B)
                return A.Magnitude < B.Magnitude
            end)

            for _, v: {Entity: any, Magnitude: number} in SortingTable do
                if EntitySettings.Wallcheck then
                    if Entity.Wallcheck(LocalPosition, v.Entity[EntitySettings.Part].Position, EntitySettings.Wallbang, v.Entity[EntitySettings.Part]) then
                        continue
                    end
                end
                table.clear(EntitySettings)
                table.clear(SortingTable)
                return v.Entity
            end
            table.clear(SortingTable)
        end
        table.clear(EntitySettings)
    end

    Entity.AllPosition = function(EntitySettings)
        local Returned = {}
        if Entity.isAlive then
            local LocalPosition, SortingTable = EntitySettings.Origin or Entity.character.HumanoidRootPart.Position, {}
            for _, EntityData: any in Entity.List do
                if not EntitySettings.Players and EntityData.Player then
                    continue
                end
                if not EntitySettings.NPCs and EntityData.NPC then
                    continue
                end
                if not EntityData.Targetable then
                    continue
                end
                local Distance: number = (EntityData[EntitySettings.Part].Position - LocalPosition).Magnitude
                if Distance > EntitySettings.Range then
                    continue
                end
                if Entity.isVulnerable(EntityData, EntitySettings.AttackCheck) then
                    table.insert(SortingTable, {
                        Entity = EntityData,
                        Magnitude = EntityData.Target and -1 or Distance
                    })
                end
            end

            table.sort(SortingTable, EntitySettings.Sort or function(A, B)
                return A.Magnitude < B.Magnitude
            end)

            for _, v: {Entity: any, Magnitude: number} in SortingTable do
                if EntitySettings.Wallcheck then
                    if Entity.Wallcheck(LocalPosition, v.Entity[EntitySettings.Part].Position, EntitySettings.Wallbang, v.Entity[EntitySettings.Part]) then
                        continue
                    end
                end
                table.insert(Returned, v.Entity)
                if #Returned >= (EntitySettings.Limit or math.huge) then
                    break
                end
            end
            table.clear(SortingTable)
        end
        table.clear(EntitySettings)
        return Returned
    end

    Entity.getEntityColor = function(Ent)
        if not (Ent.Player and vape.Settings.Modules.Options["Use team color"].Enabled) then
            return
        end
        if IsFriend(Ent.Player, true) then
            return Color3.fromHSV(vape.Categories.Friends.Options["Friends color"].Hue, vape.Categories.Friends.Options["Friends color"].Sat, vape.Categories.Friends.Options["Friends color"].Value)
        end

        local EntityColor: Color3? = tostring(Ent.Player.TeamColor) ~= "White" and Ent.Player.TeamColor.Color or nil
        if Ent.Player.Team == Teams.Inmates and (Ent.Character:GetAttribute("Hostile") or Ent.Character:GetAttribute("Trespassing")) then
            return Color3.new(EntityColor.R, EntityColor.G * 0.5, EntityColor.B * 0.5)
        end

        return EntityColor
    end

    Entity.Wallcheck = function(Origin: Vector3, Position: Vector3, CheckPosition, Part)
        local WallRay: RaycastResult? = workspace.Raycast(workspace, Position, (Origin - Position), OriginScanner.Ray)
        if WallRay then
            return not CheckPosition or not OriginScanner:Scan(CheckPosition, Position, WallRay.Position + WallRay.Normal * 0.01, Part)
        end

        return false
    end
end)
Entity.start()

Run(function()
    PrisonLife = {
        GunTracers = require(ReplicatedStorage.SharedModules.GunTracers)
    }

    local Gui = LocalPlayer.PlayerGui:WaitForChild("Home", 10)
    Gui = Gui and Gui.hud.ActionArea
    if vape.Loaded == nil then
        return
    end

    local function GetShootFunction()
        for _, v: any in getconnections(Gui.InputBegan) do
            if v.Function then
                PrisonLife.Shoot = debug.getupvalue(v.Function, 2)
                PrisonLife.Reload = debug.getupvalue(PrisonLife.Shoot, 2)
                PrisonLife.Bullet = debug.getupvalue(PrisonLife.Shoot, 16)
                PrisonLife.PlaySound = debug.getupvalue(PrisonLife.Reload, 3)
                break
            end
        end

        for _, v: any in getconnections(LocalPlayer.CharacterAdded) do
            if v.Function and debug.info(v.Function, "s"):find("GunController") then
                PrisonLife.Equip = debug.getupvalue(v.Function, 3)
                break
            end
        end

        for _, v: any in getconnections(LocalPlayer:GetAttributeChangedSignal("BackpackEnabled")) do
            PrisonLife.SwitchUpdate = debug.getupvalue(debug.getupvalue(v.Function, 10), 5)
            PrisonLife.SwitchTable = debug.getupvalue(debug.getupvalue(v.Function, 8), 2)
            break
        end
    end

    GetShootFunction()
    if not (PrisonLife.Bullet and PrisonLife.SwitchTable) then
        repeat
            GetShootFunction()
            task.wait()
        until PrisonLife.Bullet and PrisonLife.SwitchTable or vape.Loaded == nil

        if vape.Loaded == nil then
            table.clear(PrisonLife)
        end
    end

    local Kills = SessionInfo:AddItem("Kills")
    local Deaths = SessionInfo:AddItem("Deaths")
    local Arrests = SessionInfo:AddItem("Arrests")
    local CheatersKicked = SessionInfo:AddItem("Cheaters Kicked")
    local Cheaters = SessionInfo:AddItem("Cheater List", "", function()
        local Text: string = ""
        for _, Player: Player in Players:GetPlayers() do
            if CheatFlags.Flagged[Player.UserId] then
                Text = `{Text}\n{Player.DisplayName ~= Player.Name and `{Player.DisplayName} ({Player.Name})` or Player.Name}`
            end
        end

        return Text
    end, false)

    vape:Clean(ReplicatedStorage.Killfeed.ChildAdded:Connect(function(Entry: Instance)
        local Names: {string} = {}

        local Start = Entry.Name:find("@")
        local EndIndex = Entry.Name:find(")")
        table.insert(Names, Entry.Name:sub(Start + 1, EndIndex - 1))

        Start = Entry.Name:find("killed ") + 7
        EndIndex = Entry.Name:find(" ", Start)
        table.insert(Names, Entry.Name:sub(Start, EndIndex - 1))

        VapeEvents.PlayerKill:Fire(unpack(Names))
        if Names[1] == LocalPlayer.Name then
            Kills:Increment()
        elseif Names[2] == LocalPlayer.Name then
            Deaths:Increment()
        end
    end))

    vape:Clean(VapeEvents.Arrested.Event:Connect(function()
        Arrests:Increment()
    end))

    vape:Clean(ReplicatedStorage.Remotes.MessageReceived.OnClientEvent:Connect(function(Message: string)
        if Message:find("kicked") then
            CheatersKicked:Increment()

            task.defer(function()
                VapeEvents.CheaterKicked:Fire(Message:sub(1, Message:find(" ")))
            end)
        end
    end))

    vape:Clean(Entity.Events.EntityUpdated:Connect(function(Ent)
        if Ent.Player and Ent.Player.Team == Teams.Inmates then
            vape.Categories.Friends.ColorUpdate:Fire()
        end
    end))

    table.insert(Whitelist.tagcallback, function(Player, PlayerTag, Rich: boolean)
        if Player then
            local Ent = Entity.getEntity(Player)
            if Ent then
                if CheatFlags.Flagged[Player.UserId] then
                    table.insert(PlayerTag, {text = Rich and "⚠️" or "Cheater"})
                end

                if Player.Team == Teams.Inmates then
                    if Ent.Character:GetAttribute("Hostile") then
                        table.insert(PlayerTag, {text = Rich and "💢" or "Hostile"})
                    elseif Ent.Character:GetAttribute("Trespassing") then
                        table.insert(PlayerTag, {text = Rich and "🔗" or "Trespassing"})
                    end
                elseif Player.Team == Teams.Guards then
                    local Count: number = Player:GetAttribute("InnocentKills") or 0
                    if Count > 0 then
                        table.insert(PlayerTag, {
                            text = tostring(Count),
                            color = Color3.fromHSV(math.clamp(1 - (Count / 2), 0, 1) / 2.5, 0.89, 0.75)
                        })
                    end
                end
            end
        end
    end)

    task.spawn(function()
        Gamepasses = {
            ["Riot Police"] = MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, 643697197),
            Mafia = MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, 1443271),
            Sniper = MarketplaceService:UserOwnsGamePassAsync(LocalPlayer.UserId, 699360089)
        }
    end)

    OriginScanner:UpdateIgnore()
    for _, v: string in {"EntityAdded", "LocalAdded"} do
        vape:Clean(Entity.Events[v]:Connect(function()
            OriginScanner:UpdateIgnore()
        end))
    end

    vape:Clean(RunService.RenderStepped:Connect(function()
        table.clear(OriginScanner.Cache)
    end))

    vape:Clean(function()
        table.clear(PrisonLife)
    end)
end)

do
    Spring.__index = Spring

    function Spring.new(Properties)
        local TypeRefined = Properties or {}

        local self = setmetatable({
            Target = Vector3.new(),
            Position = Vector3.new(),
            Velocity = Vector3.new(),

            Mass = TypeRefined.Mass or 5,
            Force = TypeRefined.Force or 50,
            Damping = TypeRefined.Damping or 4,
            Speed = TypeRefined.Speed or 4,
        }, Spring)

        return self
    end

    function Spring:Update(DeltaTime: number)
        local IterationsThisFrame: number = DeltaTime / ((1 / 60) / 8)
        local ScaledDeltaTime: number = DeltaTime * self.Speed / IterationsThisFrame

        for _ = 1, math.round(IterationsThisFrame) do
            local IterationForce: Vector3 = self.Target - self.Position
            local Acceleration: Vector3 = (IterationForce * self.Force) / self.Mass

            Acceleration -= self.Velocity * self.Damping

            self.Velocity += Acceleration * ScaledDeltaTime
            self.Position += self.Velocity * ScaledDeltaTime
        end

        return self.Position
    end
end

do
    local OldTracer, OldTracerTaser, OldTracerSniper

    local function Hook(...)
        if debug.info(3, "s") ~= "ReplicatedStorage.Scripts.Replication.ClientReplicator" then
            for _, v: any in TracerHook.Hooks do
                if v[2](...) then
                    return
                end
            end
        end

        return OldTracer(...)
    end

    local function HookTaser(...)
        if debug.info(3, "s") ~= "ReplicatedStorage.Scripts.Replication.ClientReplicator" then
            for _, v: any in TracerHook.Hooks do
                if v[2](...) then
                    return
                end
            end
        end

        return OldTracerTaser(...)
    end

    local function HookSniper(...)
        if debug.info(3, "s") ~= "ReplicatedStorage.Scripts.Replication.ClientReplicator" then
            for _, v: any in TracerHook.Hooks do
                if v[2](...) then
                    return
                end
            end
        end

        return OldTracerSniper(...)
    end

    function TracerHook:Add(Key: string, Callback, Priority: number?)
        table.insert(self.Hooks, {Key, Callback, Priority or 0})
        table.sort(self.Hooks, function(A, B)
            return A[3] < B[3]
        end)

        if not OldTracer then
            OldTracer = hookfunction(PrisonLife.GunTracers.createBullet, function(...)
                return Hook(...)
            end)

            OldTracerTaser = hookfunction(PrisonLife.GunTracers.createTaser, function(...)
                return HookTaser(...)
            end)

            OldTracerSniper = hookfunction(PrisonLife.GunTracers.createSniper, function(...)
                return HookSniper(...)
            end)
        end
    end

    function TracerHook:Remove(Key: string)
        for i: number, v: any in self.Hooks do
            if v[1] == Key then
                table.remove(self.Hooks, i)
                break
            end
        end

        if OldTracer and not next(self.Hooks) then
            if restorefunction then
                restorefunction(PrisonLife.GunTracers.createBullet)
                restorefunction(PrisonLife.GunTracers.createTaser)
                restorefunction(PrisonLife.GunTracers.createSniper)
            else
                hookfunction(PrisonLife.GunTracers.createBullet, OldTracer)
                hookfunction(PrisonLife.GunTracers.createTaser, OldTracerTaser)
                hookfunction(PrisonLife.GunTracers.createSniper, OldTracerSniper)
            end

            OldTracer = nil
            OldTracerTaser = nil
            OldTracerSniper = nil
        end
    end
end

for _, v: string in {"Reach", "Jesus", "MurderMystery"} do
    vape:Remove(v)
end

local MouseClicked
Run(function()
    local SilentAim
    local Target
    local Mode
    local Range
    local HitChance
    local HeadshotChance
    local AutoFire = {Enabled = false}
    local AutoFireRate
    local AutoFireTaser
    local Wallbang
    local CircleColor
    local CircleTransparency
    local CircleFilled
    local CircleObject
    local RayParams: RaycastParams = RaycastParams.new()
    RayParams.CollisionGroup = "ClientBullet"
    RayParams.FilterType = Enum.RaycastFilterType.Exclude
    local FireOffset, Generator, DelayCheck = CFrame.identity, Random.new(), tick()
    local Old

    local function GetTarget(Origin: Vector3, Limit: number, AttackCheck: boolean)
        if Generator.NextNumber(Generator, 0, 100) > (AutoFire.Enabled and 100 or HitChance.Value) then
            return
        end
        local TargetPart: string = (Generator.NextNumber(Generator, 0, 100) < (AutoFire.Enabled and 100 or HeadshotChance.Value)) and "Head" or "RootPart"
        local Ent = Entity[`Entity{Mode.Value}`]({
            Range = Mode.Value == "Position" and math.min(Range.Value, Limit) or Range.Value,
            RangePosition = Limit,
            AttackCheck = AttackCheck,
            Wallcheck = Target.Walls.Enabled and true or nil,
            Wallbang = Wallbang.Enabled and Entity.character.RootPart.Position or nil,
            Part = TargetPart,
            Origin = Origin,
            Players = Target.Players.Enabled,
            NPCs = Target.NPCs.Enabled
        })

        if Ent then
            TargetInfo.Targets[Ent] = tick() + 1
        end

        return Ent, Ent and Ent[TargetPart], Origin
    end

    local function Hook(...)
        local ShotOrigin, Direction = ...
        local GunData = debug.getupvalue(OldShoot or PrisonLife.Shoot, 10)
        local Ent, TargetPart, Origin = GetTarget(ShotOrigin, GunData and GunData.Range or 1000, not GunData or GunData.Behavior ~= "Taser")

        if not Ent then
            return Old(...)
        end

        local Args = table.pack(...)
        Args[2] = TargetPart.Position
        AimTimer = os.clock() + 0.3
        AimVector = Args[2]

        if Wallbang.Enabled then
            local Ignore: {Instance} = {LocalPlayer.Character}
            for _, v: any in Entity.List do
                table.insert(Ignore, v.Character)
            end
            RayParams.FilterDescendantsInstances = Ignore
            local WallRay: RaycastResult? = workspace:Raycast(Args[2], (Origin - Args[2]), RayParams)

            if WallRay then
                local NewOrigin, Hitbox = OriginScanner:Scan(Entity.character.RootPart.Position, Args[2], WallRay.Position + WallRay.Normal * 0.01, TargetPart)

                if NewOrigin then
                    for i: number, v: any in debug.getstack(3) do
                        if v == Origin then
                            debug.setstack(3, i, NewOrigin)
                        end
                    end

                    Args[1] = NewOrigin
                    if Hitbox then
                        return TargetPart, Hitbox
                    end
                end
            end
        end

        return Old(unpack(Args, 1, Args.n))
    end

    SilentAim = vape.Categories.Combat:CreateModule({
        Name = "SilentAim",
        Function = function(Callback: boolean)
            if CircleObject then
                CircleObject.Visible = Callback and Mode.Value == "Mouse"
            end

            if Callback then
                Old = hookfunction(PrisonLife.Bullet, function(...)
                    return Hook(...)
                end)

                local AutoFireTimer: number = os.clock()
                repeat
                    if CircleObject then
                        CircleObject.Position = UserInputService:GetMouseLocation()
                    end

                    if AutoFire.Enabled and AutoFireTimer < os.clock() then
                        AutoFireTimer = os.clock() + (1 / AutoFireRate.Value)

                        local Tool = LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
                        local GunData = debug.getupvalue(OldShoot or PrisonLife.Shoot, 10)
                        local Ammo = Tool and Tool:GetAttribute("Local_CurrentAmmo") or 0
                        if GunData and Ammo > 0 and not Tool:GetAttribute("Local_IsShooting") then
                            local Limit: number = GunData.Range or 1000
                            local IsTaser = GunData and GunData.Behavior == "Taser"
                            local Ent = Entity[`Entity{Mode.Value}`]({
                                Range = Mode.Value == "Position" and math.min(Range.Value, Limit) or Range.Value,
                                RangePosition = Limit,
                                AttackCheck = not IsTaser,
                                Wallcheck = Target.Walls.Enabled and true or nil,
                                Wallbang = Wallbang.Enabled and Entity.isAlive and Entity.character.RootPart.Position or nil,
                                Part = "Head",
                                Origin = Entity.isAlive and Entity.character.Head.Position or Vector3.zero,
                                Players = Target.Players.Enabled
                            })

                            if Ent and Entity.character.Humanoid.Health > 0 then
                                if not ((IsTaser or AutoFireTaser.Enabled) and (Ent.Character:GetAttribute("Tased") or Ent.Character:GetAttribute("Arrested"))) then
                                    AutoFireTimer = os.clock() + (Ammo > 1 and GunData.FireRate or 1 / AutoFireRate.Value)
                                    local Input = {UserInputState = Enum.UserInputState.Begin, UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.zero}
                                    task.spawn(PrisonLife.Shoot, Input)
                                    Input.UserInputState = Enum.UserInputState.End
                                end
                            end
                        end
                    end

                    task.wait()
                until not SilentAim.Enabled
            else
                if Old then
                    if restorefunction then
                        restorefunction(PrisonLife.Bullet)
                    else
                        hookfunction(PrisonLife.Bullet, Old)
                    end
                    Old = nil
                end
            end
        end,
        ExtraText = function()
            return "PrisonLife"
        end,
        Tooltip = "Silently adjusts your aim towards the enemy"
    })
    Target = SilentAim:CreateTargets({
        Players = true,
        Walls = true
    })
    Mode = SilentAim:CreateDropdown({
        Name = "Mode",
        List = {"Mouse", "Position"},
        Function = function(Val: string)
            if CircleObject then
                CircleObject.Visible = SilentAim.Enabled and Val == "Mouse"
            end
        end,
        Tooltip = "Mouse - Checks for entities near the mouses position\nPosition - Checks for entities near the local character"
    })
    Range = SilentAim:CreateSlider({
        Name = "Range",
        Min = 1,
        Max = 1000,
        Default = 150,
        Function = function(Val: number)
            if CircleObject then
                CircleObject.Radius = Val
            end
        end,
        Suffix = function(Val: number)
            return Val == 1 and "stud" or "studs"
        end
    })
    HitChance = SilentAim:CreateSlider({
        Name = "Hit Chance",
        Min = 0,
        Max = 100,
        Default = 85,
        Suffix = "%"
    })
    HeadshotChance = SilentAim:CreateSlider({
        Name = "Headshot Chance",
        Min = 0,
        Max = 100,
        Default = 65,
        Suffix = "%"
    })
    AutoFire = SilentAim:CreateToggle({
        Name = "AutoFire",
        Function = function(Callback: boolean)
            AutoFireRate.Object.Visible = Callback
            AutoFireTaser.Object.Visible = Callback
        end,
        Tooltip = "Automatically fires guns when the specified target conditions are met."
    })
    AutoFireRate = SilentAim:CreateSlider({
        Name = "Update rate",
        Min = 1,
        Max = 120,
        Default = 60,
        Visible = false,
        Darker = true,
        Suffix = "hz"
    })
    AutoFireTaser = SilentAim:CreateToggle({
        Name = "Ignore Tased",
        Visible = false,
        Darker = true
    })
    Wallbang = SilentAim:CreateToggle({
        Name = "Wallbang",
        Tooltip = "Allow you to shoot people through walls when specific conditions are met.\n(If the entity has a valid hitbox position exposed or if the shoot position can be moved past walls (eg hugging walls))"
    })
    SilentAim:CreateToggle({
        Name = "Range Circle",
        Function = function(Callback: boolean)
            if Callback then
                CircleObject = Drawing.new("Circle")
                CircleObject.Filled = CircleFilled.Enabled
                CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
                CircleObject.Position = vape.gui.AbsoluteSize / 2
                CircleObject.Radius = Range.Value
                CircleObject.NumSides = 100
                CircleObject.Transparency = 1 - CircleTransparency.Value
                CircleObject.Visible = SilentAim.Enabled and Mode.Value == "Mouse"
            else
                pcall(function()
                    CircleObject.Visible = false
                    CircleObject:Remove()
                end)
            end
            CircleColor.Object.Visible = Callback
            CircleTransparency.Object.Visible = Callback
            CircleFilled.Object.Visible = Callback
        end
    })
    CircleColor = SilentAim:CreateColorSlider({
        Name = "Circle Color",
        Function = function(Hue: number, Sat: number, Val: number)
            if CircleObject then
                CircleObject.Color = Color3.fromHSV(Hue, Sat, Val)
            end
        end,
        Darker = true,
        Visible = false
    })
    CircleTransparency = SilentAim:CreateSlider({
        Name = "Transparency",
        Min = 0,
        Max = 1,
        Decimal = 10,
        Default = 0.5,
        Function = function(Val: number)
            if CircleObject then
                CircleObject.Transparency = 1 - Val
            end
        end,
        Darker = true,
        Visible = false
    })
    CircleFilled = SilentAim:CreateToggle({
        Name = "Circle Filled",
        Function = function(Callback: boolean)
            if CircleObject then
                CircleObject.Filled = Callback
            end
        end,
        Darker = true,
        Visible = false
    })
end)

Run(function()
	local TriggerBot
	local Targets
	local RayParams: RaycastParams = RaycastParams.new()
	RayParams.CollisionGroup = "ClientBullet"
	RayParams.FilterType = Enum.RaycastFilterType.Exclude
	
	local function GetTriggerBotTarget()
	    RayParams.FilterDescendantsInstances = {LocalPlayer.Character}
	    if Entity.isAlive then
	        local Tool = debug.getupvalue(OldShoot or PrisonLife.Shoot, 1)
	        local Data = debug.getupvalue(OldShoot or PrisonLife.Shoot, 10)
	
	        if Tool and Data and Data.Range then
	            local PositionX, PositionY
	            if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
	                PositionX = Camera.ViewportSize.X / 2
	                PositionY = Camera.ViewportSize.Y / 2
	            else
	                local Location: Vector2 = UserInputService:GetMouseLocation()
	                PositionX = Location.X
	                PositionY = Location.Y
	            end
	
	            local HitPosition
	            local UnitRay: Ray = Camera:ViewportPointToRay(PositionX, PositionY)
	            local Hit: RaycastResult? = workspace:Raycast(UnitRay.Origin, UnitRay.Direction * 1500, RayParams)
	            local Victim
	
	            for _, Ent: any in Entity.List do
	                if Ent.Targetable and Ent.Character and (Targets.Players.Enabled and Ent.Player or Targets.NPCs.Enabled and Ent.NPC) and Entity.isVulnerable(Ent, true) and Hit and Hit.Instance:IsDescendantOf(Ent.Character) then
	                    Victim = Ent
	                    break
	                end
	            end
	
	            if Victim then
	                local Origin: Vector3 = Entity.character.Head.Position
	                local HitCheck: RaycastResult? = workspace:Raycast(Origin, (Hit.Position - Origin), RayParams)
	                if HitCheck and HitCheck.Instance:IsDescendantOf(Victim.Character) and (Hit.Position - Origin).Magnitude <= Data.Range then
	                    return Victim
	                end
	            end
	        end
	    end
	end
	
	TriggerBot = vape.Categories.Combat:CreateModule({
	    Name = "TriggerBot",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                if GetTriggerBotTarget() then
	                    local Input = {UserInputState = Enum.UserInputState.Begin, UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.zero}
	                    task.spawn(PrisonLife.Shoot, Input)
	                    Input.UserInputState = Enum.UserInputState.End
	                end
	
	                task.wait()
	            until not TriggerBot.Enabled
	        end
	    end,
	    Tooltip = "Shoots people that enter your crosshair"
	})
	Targets = TriggerBot:CreateTargets({
	    Players = true,
	    NPCs = true
	})
end)

Run(function()
	local AntiInvisible
	local Threads: {[AnimationTrack]: thread} = {}
	local Whitelist: {[string]: boolean} = {
	    ["http://www.roblox.com/asset/?id=125750702"] = true,
	    ["http://www.roblox.com/asset/?id=128777973"] = true,
	    ["http://www.roblox.com/asset/?id=128853357"] = true,
	    ["http://www.roblox.com/asset/?id=129423030"] = true,
	    ["http://www.roblox.com/asset/?id=129423131"] = true,
	    ["http://www.roblox.com/asset/?id=129967390"] = true,
	    ["http://www.roblox.com/asset/?id=129967478"] = true,
	    ["http://www.roblox.com/asset/?id=178130996"] = true,
	    ["http://www.roblox.com/asset/?id=180426354"] = true,
	    ["http://www.roblox.com/asset/?id=180435571"] = true,
	    ["http://www.roblox.com/asset/?id=180435792"] = true,
	    ["http://www.roblox.com/asset/?id=180436148"] = true,
	    ["http://www.roblox.com/asset/?id=180436334"] = true,
	    ["http://www.roblox.com/asset/?id=182393478"] = true,
	    ["http://www.roblox.com/asset/?id=182435998"] = true,
	    ["http://www.roblox.com/asset/?id=182436842"] = true,
	    ["http://www.roblox.com/asset/?id=182436935"] = true,
	    ["http://www.roblox.com/asset/?id=182491037"] = true,
	    ["http://www.roblox.com/asset/?id=182491065"] = true,
	    ["http://www.roblox.com/asset/?id=182491248"] = true,
	    ["http://www.roblox.com/asset/?id=182491277"] = true,
	    ["http://www.roblox.com/asset/?id=182491368"] = true,
	    ["http://www.roblox.com/asset/?id=182491423"] = true,
	    ["rbxassetid://279227693"] = true,
	    ["rbxassetid://279229192"] = true,
	    ["rbxassetid://287112271"] = true,
	    ["rbxassetid://388723916"] = true,
	    ["rbxassetid://388726667"] = true,
	    ["rbxassetid://389472570"] = true,
	    ["rbxassetid://405194080"] = true,
	    ["rbxassetid://405212265"] = true,
	    ["rbxassetid://481088553"] = true,
	    ["rbxassetid://481089053"] = true,
	    ["rbxassetid://484200742"] = true,
	    ["rbxassetid://484926359"] = true,
	    ["rbxassetid://83690472549256"] = true,
	    ["rbxassetid://107176344504758"] = true,
	    ["rbxassetid://111090572475133"] = true,
	    ["rbxassetid://113267949064300"] = true,
	    ["rbxassetid://131326339350805"] = true
	}
	
	local function AnimationAdded(Track: AnimationTrack, Player: Player?)
	    if not Whitelist[Track.Animation.AnimationId] and Player then
	        if Threads[Track] then
	            task.cancel(Threads[Track])
	        end
	
	        CheatFlags:Flag(Player, "invalid animation", 1)
	        Threads[Track] = task.spawn(function()
	            repeat
	                Track:AdjustWeight(0, 0)
	                task.wait()
	            until not (Track.IsPlaying and AntiInvisible.Enabled)
	
	            Threads[Track] = nil
	        end)
	    end
	end
	
	local function EntityAdded(Ent)
	    local Animator: Animator? = Ent.Humanoid:WaitForChild("Animator", 5)
	
	    if Animator and AntiInvisible.Enabled then
	        AntiInvisible:Clean(Animator.AnimationPlayed:Connect(function(Track: AnimationTrack)
	            AnimationAdded(Track, Ent.Player)
	        end))
	
	        for _, Track: AnimationTrack in Animator:GetPlayingAnimationTracks() do
	            task.spawn(AnimationAdded, Track, Ent.Player)
	        end
	    end
	end
	
	for _, v: Animation in ReplicatedStorage:QueryDescendants("Animation") do
	    Whitelist[v.AnimationId] = true
	end
	
	AntiInvisible = vape.Categories.Blatant:CreateModule({
	    Name = "AntiInvisible",
	    Function = function(Callback: boolean)
	        if Callback then
	            AntiInvisible:Clean(Entity.Events.EntityAdded:Connect(EntityAdded))
	            for _, v: any in Entity.List do
	                task.spawn(EntityAdded, v)
	            end
	        else
	            for _, v: thread in Threads do
	                task.cancel(v)
	            end
	            table.clear(Threads)
	        end
	    end,
	    Tooltip = "Prevent people from using animations outside of the game's scope"
	})
end)

Run(function()
	local AntiKillPlane
	
	AntiKillPlane = vape.Categories.Blatant:CreateModule({
	    Name = "AntiKillPlane",
	    Function = function(Callback: boolean)
	        if Callback then
	            AntiKillPlane:Clean(RunService.Heartbeat:Connect(function()
	                if Entity.isAlive then
	                    local Root: BasePart = Entity.character.RootPart
	                    local Offset: number = math.min(Root.Position.Y, 179.99) - Root.Position.Y
	                    Root.CFrame += Vector3.new(0, Offset, 0)
	
	                    if math.abs(Offset) > 0 and Root.AssemblyLinearVelocity.Y > 0 then
	                        Root.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)
	                    end
	                end
	            end))
	        end
	    end,
	    Tooltip = "Prevents you from touching the kill plane"
	})
end)

Run(function()
	local AntiRiotShield
	
	AntiRiotShield = vape.Categories.Blatant:CreateModule({
	    Name = "AntiRiotShield",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                for _, Ent: any in Entity.List do
	                    local Shield = Ent.Character:FindFirstChild("RiotShieldPart")
	                    if Shield then
	                        Shield.CanQuery = false
	                    end
	                end
	
	                task.wait(0.05)
	            until not AntiRiotShield.Enabled
	        else
	            for _, Ent: any in Entity.List do
	                local Shield = Ent.Character:FindFirstChild("RiotShieldPart")
	                if Shield then
	                    Shield.CanQuery = true
	                end
	            end
	        end
	    end,
	    Tooltip = "Allow you to shoot through riot shields."
	})
end)

Run(function()
	local AntiTaze
	local Old, Connection
	
	local function EntityAdded(Ent)
	    Connection = getconnections(ReplicatedStorage.GunRemotes.PlayerTased.OnClientEvent)[1]
	    if not (Connection and Connection.Function) then
	        repeat
	            Connection = getconnections(ReplicatedStorage.GunRemotes.PlayerTased.OnClientEvent)[1]
	            task.wait()
	        until Connection and Connection.Function or not AntiTaze.Enabled
	    end
	
	    if Connection and AntiTaze.Enabled then
	        Old = hookfunction(Connection.Function, function()
	            local Character: Model? = LocalPlayer.Character
	            LocalPlayer:SetAttribute("BackpackEnabled", false)
	            if Entity.isAlive then
	                Entity.character.Humanoid:UnequipTools()
	            end
	
	            task.wait(3.5)
	            if LocalPlayer.Character == Character then
	                LocalPlayer:SetAttribute("BackpackEnabled", true)
	            end
	        end)
	    end
	end
	
	AntiTaze = vape.Categories.Blatant:CreateModule({
	    Name = "AntiTaze",
	    Function = function(Callback: boolean)
	        if Callback then
	            AntiTaze:Clean(Entity.Events.LocalAdded:Connect(EntityAdded))
	            if Entity.isAlive then
	                task.spawn(EntityAdded, Entity.character)
	            end
	        else
	            if Old and Connection.Function then
	                hookfunction(Connection.Function, Old)
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Prevent you from getting tazed"
	})
end)

Run(function()
	local AutoArrest
	local Range
	local HandCheck
	local CooldownBar
	local Toggles = {}
	local CooldownHolder, CooldownFrame, CooldownLabel
	
	AutoArrest = vape.Categories.Blatant:CreateModule({
	    Name = "AutoArrest",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local Check = ArrestCooldown < os.clock()
	                if HandCheck.Enabled then
	                    local Tool = Entity.isAlive and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
	                    Check = Check and Tool and Tool.Name == "Handcuffs"
	                end
	
	                if Check then
	                    local Entities = Entity.AllPosition({
	                        Range = Range.Value,
	                        Players = true,
	                        Part = "RootPart",
	                        TargetCheck = true
	                    })
	
	                    for _, Ent: any in Entities do
	                        if not Ent.Character:GetAttribute("Arrested") then
	                            local Toggle = Ent.Player.Team and Toggles[Ent.Player.Team.Name]
	                            if Toggle and not Toggle.Enabled then
	                                continue
	                            end
	
	                            if Ent.Player.Team == Teams.Inmates and Ent.Character:GetAttribute("Hostile") and not Ent.Character:GetAttribute("Tased") then
	                                continue
	                            end
	
	                            if ReplicatedStorage.Remotes.ArrestPlayer:InvokeServer(Ent.Player, 1) then
	                                ArrestCooldown = os.clock() + 7
	                                VapeEvents.Arrested:Fire()
	                                SendNotification("AutoArrest", `Arrested {Ent.Player.Name}`, 7)
	                            end
	
	                            break
	                        end
	                    end
	                end
	
	                if CooldownHolder then
	                    CooldownHolder.Visible = ArrestCooldown > os.clock()
	
	                    if CooldownHolder.Visible then
	                        local Remaining: number = (ArrestCooldown - os.clock())
	                        CooldownFrame.Size = UDim2.new(math.clamp(Remaining / 7, 0, 1), -2, 1, -2)
	                        CooldownLabel.Text = `{math.round(Remaining * 10) / 10}s`
	                    end
	                end
	
	                task.wait(0.05)
	            until not AutoArrest.Enabled
	        else
	            if CooldownHolder then
	                CooldownHolder.Visible = false
	            end
	        end
	    end,
	    Tooltip = "Automatically uses handcuffs on nearby entities"
	})
	Range = AutoArrest:CreateSlider({
	    Name = "Range",
	    Min = 1,
	    Max = 8,
	    Default = 8,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	HandCheck = AutoArrest:CreateToggle({
	    Name = "Hand Check",
	    Tooltip = "Only arrest if you have handcuffs equipped."
	})
	CooldownBar = AutoArrest:CreateToggle({
	    Name = "Cooldown Bar",
	    Function = function(Callback: boolean)
	        if Callback then
	            CooldownHolder = Instance.new("Frame")
	            CooldownHolder.Visible = false
	            CooldownHolder.BorderSizePixel = 0
	            CooldownHolder.BackgroundTransparency = 0.7
	            CooldownHolder.AnchorPoint = Vector2.new(0.5, 0)
	            CooldownHolder.BackgroundColor3 = Color3.new(1, 1, 1)
	            CooldownHolder.Size = UDim2.new(0.1, 0, 0, 5)
	            CooldownHolder.Position = UDim2.fromScale(0.5, 0.55)
	            CooldownHolder.Parent = vape.gui
	            CooldownFrame = Instance.new("Frame")
	            CooldownFrame.BorderSizePixel = 0
	            CooldownFrame.BackgroundTransparency = 0.3
	            CooldownFrame.BackgroundColor3 = Color3.new(1, 1, 1)
	            CooldownFrame.Size = UDim2.new(1, -2, 1, -2)
	            CooldownFrame.Position = UDim2.fromOffset(1, 1)
	            CooldownFrame.Parent = CooldownHolder
	            CooldownLabel = Instance.new("TextLabel")
	            CooldownLabel.Size = UDim2.new(1, 0, 0, 14)
	            CooldownLabel.Position = UDim2.fromOffset(0, 10)
	            CooldownLabel.BackgroundTransparency = 1
	            CooldownLabel.TextColor3 = Color3.new(1, 1, 1)
	            CooldownLabel.TextScaled = true
	            CooldownLabel.TextStrokeTransparency = 0
	            CooldownLabel.Font = Enum.Font.Arial
	            CooldownLabel.Parent = CooldownHolder
	        else
	            if CooldownFrame then
	                CooldownFrame:Destroy()
	                CooldownFrame = nil
	            end
	        end
	    end,
	    Tooltip = "Show the cooldown for arresting"
	})
	
	for _, v: string in {"Inmates", "Criminals"} do
	    Toggles[v] = AutoArrest:CreateToggle({
	        Name = `Arrest {v}`,
	        Default = true
	    })
	end
end)

Run(function()
	local AutoReset
	
	AutoReset = vape.Categories.Blatant:CreateModule({
	    Name = "AutoReset",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoReset:Clean(LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
	                if LocalPlayer.Team == Teams.Criminals and Entity.isAlive then
	                    Entity.character.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
	                end
	            end))
	        end
	    end,
	    Tooltip = "Automatically reset after becoming a criminal."
	})
end)

Run(function()
	local AutoTaser
	local Range
	local VelocityCheck
	local Cooldown: number = 0
	
	AutoTaser = vape.Categories.Blatant:CreateModule({
	    Name = "AutoTaser",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local Backpack = LocalPlayer:FindFirstChildWhichIsA("Backpack")
	                local Taser = Backpack and Backpack:FindFirstChild("Taser")
	
	                if Taser and (Taser:GetAttribute("CurrentAmmo") or 1) > 0 and Cooldown < os.clock() and (ArrestCooldown - os.clock()) < 3 then
	                    if not VelocityCheck.Enabled or Entity.isAlive and Entity.character.RootPart.AssemblyLinearVelocity.Magnitude < 40 then
	                        local Entities = Entity.AllPosition({
	                            Range = Range.Value,
	                            AttackCheck = false,
	                            Wallcheck = true,
	                            Part = "Head",
	                            Origin = Entity.isAlive and Entity.character.Head.Position or Vector3.zero,
	                            Players = true
	                        })
	
	                        for _, Ent: any in Entities do
	                            if not (Ent.Character:GetAttribute("Tased") or Ent.Character:GetAttribute("Arrested")) then
	                                Cooldown = os.clock() + 2
	                                local Equipped = LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
	                                if Equipped then
	                                    Equipped.Parent = Backpack
	                                end
	
	                                Taser.Parent = LocalPlayer.Character
	                                break
	                            end
	                        end
	                    end
	                end
	
	                task.wait(0.05)
	            until not AutoTaser.Enabled
	        end
	    end,
	    Tooltip = "Automatically taze people around you. (only works with SilentAim AutoFire with Position Mode enabled)"
	})
	Range = AutoTaser:CreateSlider({
	    Name = "Range",
	    Min = 1,
	    Max = 52,
	    Default = 52,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	VelocityCheck = AutoTaser:CreateToggle({
	    Name = "Velocity Check",
	    Default = true
	})
end)

Run(function()
	local FenceGodmode
	
	FenceGodmode = vape.Categories.Blatant:CreateModule({
	    Name = "FenceGodmode",
	    Function = function(Callback: boolean)
	        for _, Fence: BasePart in workspace.Prison_Fences:QueryDescendants("BasePart:has(> TouchTransmitter)") do
	            Fence.CanTouch = not Callback
	        end
	    end,
	    Tooltip = "Ignore damage from standing ontop of fences."
	})
end)

Run(function()
	local GunModifications
	local Spread
	local FireRate
	local Automatic
	local OldData, Old = {}
	local OldHook
	
	local function Modify()
	    local Data = debug.getupvalue(OldShoot or PrisonLife.Shoot, 10)
	    if Data and GunModifications.Enabled then
	        if Old ~= Data then
	            OldData = table.clone(Data)
	            Old = Data
	        end
	
	        Data.SpreadRadius = Spread.Enabled and 0 or OldData.SpreadRadius
	        Data.FireRate = (OldData.FireRate or 0) * (FireRate.Value / 100)
	        Data.AutoFire = Automatic.Enabled or OldData.AutoFire
	    end
	end
	
	
	GunModifications = vape.Categories.Blatant:CreateModule({
	    Name = "GunModifications",
	    Function = function(Callback: boolean)
	        if Callback then
	            OldEquip = hookfunction(PrisonLife.Equip, function(...)
	                local Results = table.pack(OldEquip(...))
	                Modify()
	                return unpack(Results, 1, Results.n)
	            end)
	
	            Modify()
	        else
	            if OldEquip then
	                if restorefunction then
	                    restorefunction(PrisonLife.Equip)
	                else
	                    hookfunction(PrisonLife.Equip, OldEquip)
	                end
	                OldEquip = nil
	            end
	
	            if Old then
	                for Key: string, v: any in OldData do
	                    Old[Key] = v
	                end
	                table.clear(OldData)
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Apply various modifications to enhance any firearm"
	})
	FireRate = GunModifications:CreateSlider({
	    Name = "FireRate Multiplier",
	    Min = 1,
	    Max = 100,
	    Default = 100,
	    Suffix = "%",
	    Function = Modify
	})
	Spread = GunModifications:CreateToggle({
	    Name = "No Spread",
	    Function = Modify
	})
	Automatic = GunModifications:CreateToggle({
	    Name = "Full Automatic",
	    Function = Modify
	})
end)

Run(function()
	local Killaura
	local Targets
	local AttackRange
	local AngleSlider
	local Max
	local Mouse
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Overlay: OverlapParams = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	local Particles, Boxes, AttackDelay = {}, {}, tick()
	
	local function GetAttackData()
	    if Mouse.Enabled then
	        if not UserInputService:IsMouseButtonPressed(0) then
	            return false
	        end
	    end
	
	    return true
	end
	
	Killaura = vape.Categories.Blatant:CreateModule({
	    Name = "Killaura",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local CanAttack: boolean = GetAttackData()
	                local Attacked = {}
	                if CanAttack then
	                    local Entities = Entity.AllPosition({
	                        Range = AttackRange.Value,
	                        Wallcheck = Targets.Walls.Enabled or nil,
	                        Part = "RootPart",
	                        Players = Targets.Players.Enabled,
	                        NPCs = Targets.NPCs.Enabled,
	                        Priority = Targets.Priority.Value,
	                        Limit = Max.Value,
	                        AttackCheck = true
	                    })
	
	                    if #Entities > 0 then
	                        local SelfPosition: Vector3 = Entity.character.RootPart.Position
	                        local LocalFacing: Vector3 = Entity.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	
	                        for _, v: any in Entities do
	                            local Delta: Vector3 = (v.RootPart.Position - SelfPosition)
	                            local Angle: number = math.acos(LocalFacing:Dot((Delta * Vector3.new(1, 0, 1)).Unit))
	                            if Angle > (math.rad(AngleSlider.Value) / 2) then
	                                continue
	                            end
	                            if LocalPlayer.Team == Teams.Guards and v.Player.Team == Teams.Inmates and not v.Character:GetAttribute("Hostile") then
	                                continue
	                            end
	
	                            table.insert(Attacked, {
	                                Entity = v,
	                                Check = BoxAttackColor
	                            })
	                            TargetInfo.Targets[v] = tick() + 1
	                            ReplicatedStorage.meleeEvent:FireServer(v.Player, 1, 1)
	                        end
	                    end
	                end
	
	                for i: number, v: BoxHandleAdornment in Boxes do
	                    v.Adornee = Attacked[i] and Attacked[i].Entity.RootPart or nil
	                    if v.Adornee then
	                        v.Color3 = Color3.fromHSV(Attacked[i].Check.Hue, Attacked[i].Check.Sat, Attacked[i].Check.Value)
	                        v.Transparency = 1 - Attacked[i].Check.Opacity
	                    end
	                end
	
	                for i: number, v: Part in Particles do
	                    v.Position = Attacked[i] and Attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
	                    v.Parent = Attacked[i] and Camera or nil
	                end
	
	                if Face.Enabled and Attacked[1] then
	                    local TargetPosition: Vector3 = Attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
	                    Entity.character.RootPart.CFrame = CFrame.lookAt(Entity.character.RootPart.Position, Vector3.new(TargetPosition.X, Entity.character.RootPart.Position.Y + 0.01, TargetPosition.Z))
	                end
	
	                task.wait(0.05)
	            until not Killaura.Enabled
	        else
	            for _, v: BoxHandleAdornment in Boxes do
	                v.Adornee = nil
	            end
	
	            for _, v: Part in Particles do
	                v.Parent = nil
	            end
	        end
	    end,
	    Tooltip = "Attack players around you\nwithout aiming at them."
	})
	Targets = Killaura:CreateTargets({Players = true})
	AttackRange = Killaura:CreateSlider({
	    Name = "Attack range",
	    Min = 1,
	    Max = 12,
	    Default = 12,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	AngleSlider = Killaura:CreateSlider({
	    Name = "Max angle",
	    Min = 1,
	    Max = 360,
	    Default = 360
	})
	Max = Killaura:CreateSlider({
	    Name = "Max targets",
	    Min = 1,
	    Max = 10,
	    Default = 10
	})
	Mouse = Killaura:CreateToggle({Name = "Require mouse down"})
	Killaura:CreateToggle({
	    Name = "Show target",
	    Function = function(Callback: boolean)
	        BoxSwingColor.Object.Visible = Callback
	        BoxAttackColor.Object.Visible = Callback
	        if Callback then
	            for i: number = 1, 10 do
	                local Box: BoxHandleAdornment = Instance.new("BoxHandleAdornment")
	                Box.Adornee = nil
	                Box.AlwaysOnTop = true
	                Box.Size = Vector3.new(3, 5, 3)
	                Box.CFrame = CFrame.new(0, -0.5, 0)
	                Box.ZIndex = 0
	                Box.Parent = vape.gui
	                Boxes[i] = Box
	            end
	        else
	            for _, v: BoxHandleAdornment in Boxes do
	                v:Destroy()
	            end
	            table.clear(Boxes)
	        end
	    end
	})
	BoxSwingColor = Killaura:CreateColorSlider({
	    Name = "Target Color",
	    Darker = true,
	    DefaultHue = 0.6,
	    DefaultOpacity = 0.5,
	    Visible = false
	})
	BoxAttackColor = Killaura:CreateColorSlider({
	    Name = "Attack Color",
	    Darker = true,
	    DefaultOpacity = 0.5,
	    Visible = false
	})
	Killaura:CreateToggle({
	    Name = "Target particles",
	    Function = function(Callback: boolean)
	        ParticleTexture.Object.Visible = Callback
	        ParticleColor1.Object.Visible = Callback
	        ParticleColor2.Object.Visible = Callback
	        ParticleSize.Object.Visible = Callback
	        if Callback then
	            for i: number = 1, 10 do
	                local Part: Part = Instance.new("Part")
	                Part.Size = Vector3.new(2, 4, 2)
	                Part.Anchored = true
	                Part.CanCollide = false
	                Part.Transparency = 1
	                Part.CanQuery = false
	                Part.Parent = Killaura.Enabled and Camera or nil
	                local Emitter: ParticleEmitter = Instance.new("ParticleEmitter")
	                Emitter.Brightness = 1.5
	                Emitter.Size = NumberSequence.new(ParticleSize.Value)
	                Emitter.Shape = Enum.ParticleEmitterShape.Sphere
	                Emitter.Texture = ParticleTexture.Value
	                Emitter.Transparency = NumberSequence.new(0)
	                Emitter.Lifetime = NumberRange.new(0.4)
	                Emitter.Speed = NumberRange.new(16)
	                Emitter.Rate = 128
	                Emitter.Drag = 16
	                Emitter.ShapePartial = 1
	                Emitter.Color = ColorSequence.new({
	                    ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
	                    ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
	                })
	                Emitter.Parent = Part
	                Particles[i] = Part
	            end
	        else
	            for _, v: Part in Particles do
	                v:Destroy()
	            end
	            table.clear(Particles)
	        end
	    end
	})
	ParticleTexture = Killaura:CreateTextBox({
	    Name = "Texture",
	    Default = "rbxassetid://14736249347",
	    Function = function()
	        for _, v: Part in Particles do
	            v.ParticleEmitter.Texture = ParticleTexture.Value
	        end
	    end,
	    Darker = true,
	    Visible = false
	})
	ParticleColor1 = Killaura:CreateColorSlider({
	    Name = "Color Begin",
	    Function = function(Hue: number, Sat: number, Val: number)
	        for _, v: Part in Particles do
	            v.ParticleEmitter.Color = ColorSequence.new({
	                ColorSequenceKeypoint.new(0, Color3.fromHSV(Hue, Sat, Val)),
	                ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
	            })
	        end
	    end,
	    Darker = true,
	    Visible = false
	})
	ParticleColor2 = Killaura:CreateColorSlider({
	    Name = "Color End",
	    Function = function(Hue: number, Sat: number, Val: number)
	        for _, v: Part in Particles do
	            v.ParticleEmitter.Color = ColorSequence.new({
	                ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
	                ColorSequenceKeypoint.new(1, Color3.fromHSV(Hue, Sat, Val))
	            })
	        end
	    end,
	    Darker = true,
	    Visible = false
	})
	ParticleSize = Killaura:CreateSlider({
	    Name = "Size",
	    Min = 0,
	    Max = 1,
	    Default = 0.2,
	    Decimal = 100,
	    Function = function(Val: number)
	        for _, v: Part in Particles do
	            v.ParticleEmitter.Size = NumberSequence.new(Val)
	        end
	    end,
	    Darker = true,
	    Visible = false
	})
	Face = Killaura:CreateToggle({Name = "Face target"})
end)

Run(function()
	local NoJumpCooldown
	local Old
	
	local function EntityAdded(Ent)
	    Old = getconnections(Ent.Humanoid:GetPropertyChangedSignal("Jump"))[1]
	    if not Old then
	        repeat
	            Old = getconnections(Ent.Humanoid:GetPropertyChangedSignal("Jump"))[1]
	            task.wait()
	        until Old or not NoJumpCooldown.Enabled
	
	        if not NoJumpCooldown.Enabled then
	            return
	        end
	    end
	
	    if Old then
	        Old:Disable()
	    end
	end
	
	NoJumpCooldown = vape.Categories.Blatant:CreateModule({
	    Name = "NoJumpCooldown",
	    Function = function(Callback: boolean)
	        if Callback then
	            NoJumpCooldown:Clean(Entity.Events.LocalAdded:Connect(EntityAdded))
	            if Entity.isAlive then
	                task.spawn(EntityAdded, Entity.character)
	            end
	        else
	            if Old then
	                Old:Enable()
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Remove the stamina cooldown from jumping"
	})
end)

Run(function()
	local VehicleFly
	local Mode
	local Speed
	local Welds = {}
	local Up, Down = 0, 0
	
	VehicleFly = vape.Categories.Blatant:CreateModule({
	    Name = "VehicleFly",
	    Function = function(Callback: boolean)
	        if Callback then
	            Up, Down = 0, 0
	            for _, v: string in {"InputBegan", "InputEnded"} do
	                VehicleFly:Clean(UserInputService[v]:Connect(function(Input: InputObject)
	                    if not UserInputService:GetFocusedTextBox() then
	                        if Input.KeyCode == Enum.KeyCode.E then
	                            Up = v == "InputBegan" and 1 or 0
	                        elseif Input.KeyCode == Enum.KeyCode.Q then
	                            Down = v == "InputBegan" and -1 or 0
	                        end
	                    end
	                end))
	            end
	
	            if Mode.Value == "Part" then
	                local Part: Part = Instance.new("Part")
	                Part.Size = Vector3.new(50, 1, 50)
	                Part.Anchored = true
	                Part.CanQuery = false
	                Part.Transparency = 1
	
	                VehicleFly:Clean(Part)
	                repeat
	                    local Seat = Entity.isAlive and Entity.character.Humanoid.SeatPart
	                    if Seat then
	                        Part.CFrame = CFrame.new(Seat.Position - Vector3.new(0, 2.2 - (Up + Down), 0))
	                        Part.Parent = workspace
	                    else
	                        Part.Parent = nil
	                    end
	
	                    task.wait(0.05)
	                until not VehicleFly.Enabled
	            else
	                local InCar: boolean = false
	                local OldSeat
	                VehicleFly:Clean(RunService.PreSimulation:Connect(function(Delta: number)
	                    local Seat = Entity.isAlive and Entity.character.Humanoid.SeatPart
	                    local Root = Seat and Entity.character.RootPart
	
	                    if Root then
	                        if Seat ~= OldSeat then
	                            InCar = Seat:IsDescendantOf(workspace.CarContainer) and Seat:IsA("VehicleSeat")
	                            if InCar then
	                                Welds = Seat.Parent.Parent.Wheels:QueryDescendants("Rotate")
	                                for _, v: Rotate in Welds do
	                                    v.Enabled = false
	                                end
	                            end
	
	                            OldSeat = Seat
	                        end
	
	                        if InCar then
	                            Root.AssemblyLinearVelocity = Vector3.new(0, 2.25, 0)
	                            Root.CFrame = CFrame.lookAlong(Root.Position, Camera.CFrame.LookVector) + (Entity.character.Humanoid.MoveDirection + Vector3.new(0, Up + Down, 0)) * Speed.Value * Delta
	                            Camera.CameraSubject = Entity.character.Humanoid
	                        end
	                    elseif OldSeat then
	                        for _, v: Rotate in Welds do
	                            v.Enabled = true
	                        end
	                        OldSeat = nil
	                    end
	                end))
	            end
	        else
	            for _, v: Rotate in Welds do
	                v.Enabled = true
	            end
	            table.clear(Welds)
	        end
	    end,
	    Tooltip = "Allow you to fly with a vehicle"
	})
	Mode = VehicleFly:CreateDropdown({
	    Name = "Mode",
	    List = {"CFrame", "Part"},
	    Function = function(Val: string)
	        Speed.Object.Visible = Val == "CFrame"
	        if VehicleFly.Enabled then
	            VehicleFly:Toggle()
	            VehicleFly:Toggle()
	        end
	    end
	})
	Speed = VehicleFly:CreateSlider({
	    Name = "Speed",
	    Min = 1,
	    Max = 100,
	    Default = 60,
	    Darker = true
	})
end)

Run(function()
	local VehicleSpeed
	local Speed
	local OldSeat
	local Seats = {}
	
	VehicleSpeed = vape.Categories.Blatant:CreateModule({
	    Name = "VehicleSpeed",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local Seat = Entity.isAlive and Entity.character.Humanoid.SeatPart
	                if Seat then
	                    if Seat ~= OldSeat then
	                        if Seat:IsDescendantOf(workspace.CarContainer) then
	                            Seats = Seat.Parent.Parent:QueryDescendants("VehicleSeat")
	                        end
	
	                        OldSeat = Seat
	                    end
	
	                    for _, v: VehicleSeat in Seats do
	                        v.MaxSpeed = Speed.Value
	                        v.Torque = 4
	                    end
	                end
	
	                task.wait()
	            until not VehicleSpeed.Enabled
	        else
	            table.clear(Seats)
	        end
	    end,
	    Tooltip = "Increase vehicle speed"
	})
	Speed = VehicleSpeed:CreateSlider({
	    Name = "Speed",
	    Min = 80,
	    Max = 200,
	    Default = 140
	})
end)

Run(function()
	local VehicleWallbang
	local Modified: {[BasePart]: boolean} = {}
	
	local function Modify(Part: Instance)
	    if Part:IsA("BasePart") then
	        if not Modified[Part] then
	            Modified[Part] = Part.CanQuery
	        end
	
	        Part.CanQuery = false
	    end
	end
	
	VehicleWallbang = vape.Categories.Blatant:CreateModule({
	    Name = "VehicleWallbang",
	    Function = function(Callback: boolean)
	        if Callback then
	            VehicleWallbang:Clean(workspace.CarContainer.DescendantAdded:Connect(Modify))
	            for _, Part: BasePart in workspace.CarContainer:QueryDescendants("BasePart") do
	                Modify(Part)
	            end
	        else
	            for Part: BasePart, v: boolean in Modified do
	                Part.CanQuery = v
	            end
	            table.clear(Modified)
	        end
	    end,
	    Tooltip = "Allow you to shoot through vehicles."
	})
end)

Run(function()
	local C4ESP
	local FillColor
	local OutlineColor
	local FillTransparency
	local OutlineTransparency
	local Reference = {}
	local Folder: Folder = Instance.new("Folder")
	Folder.Parent = vape.gui
	
	local function Added(Object: Instance)
	    local Highlight: Highlight = Instance.new("Highlight")
	    Highlight.Adornee = Object
	    Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	    Highlight.FillColor = Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
	    Highlight.OutlineColor = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
	    Highlight.FillTransparency = FillTransparency.Value
	    Highlight.OutlineTransparency = OutlineTransparency.Value
	    Highlight.Parent = Folder
	
	    Reference[Object] = Highlight
	end
	
	local function Removed(Object: Instance)
	    if Reference[Object] then
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	
	        Reference[Object]:Destroy()
	        Reference[Object] = nil
	    end
	end
	
	C4ESP = vape.Categories.Render:CreateModule({
	    Name = "C4ESP",
	    Function = function(Callback: boolean)
	        if Callback then
	            C4ESP:Clean(CollectionService:GetInstanceAddedSignal("C4"):Connect(Added))
	            C4ESP:Clean(CollectionService:GetInstanceRemovedSignal("C4"):Connect(Removed))
	
	            for _, Object: Instance in CollectionService:GetTagged("C4") do
	                task.spawn(Added, Object)
	            end
	        else
	            for _, v: Highlight in Reference do
	                v:Destroy()
	            end
	            table.clear(Reference)
	        end
	    end,
	    Tooltip = "Display all C4's placed"
	})
	FillColor = C4ESP:CreateColorSlider({
	    Name = "Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        for _, v: Highlight in Reference do
	            v.FillColor = Color3.fromHSV(Hue, Sat, Val)
	        end
	    end
	})
	OutlineColor = C4ESP:CreateColorSlider({
	    Name = "Outline Color",
	    DefaultSat = 0,
	    Function = function(Hue: number, Sat: number, Val: number)
	        for _, v: Highlight in Reference do
	            v.OutlineColor = Color3.fromHSV(Hue, Sat, Val)
	        end
	    end
	})
	FillTransparency = C4ESP:CreateSlider({
	    Name = "Transparency",
	    Min = 0,
	    Max = 1,
	    Default = 0.5,
	    Function = function(Val: number)
	        for _, v: Highlight in Reference do
	            v.FillTransparency = Val
	        end
	    end,
	    Decimal = 10
	})
	OutlineTransparency = C4ESP:CreateSlider({
	    Name = "Outline Transparency",
	    Min = 0,
	    Max = 1,
	    Default = 0.5,
	    Function = function(Val: number)
	        for _, v: Highlight in Reference do
	            v.OutlineTransparency = Val
	        end
	    end,
	    Decimal = 10
	})
end)

Run(function()
	local CameraPhase
	local Old
	
	CameraPhase = vape.Categories.Render:CreateModule({
	    Name = "CameraPhase",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Popper = require(LocalPlayer.PlayerScripts.PlayerModule.CameraModule.ZoomController.Popper)
	            Old = debug.getupvalue(debug.getupvalue(Popper, 3), 7)
	            debug.setconstant(Old, 16, 0)
	        else
	            if Old then
	                debug.setconstant(Old, 16, 0.25)
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Allow the camera to phase through walls."
	})
end)

Run(function()
	local KillNotifications
	
	KillNotifications = vape.Categories.Render:CreateModule({
	    Name = "KillNotifications",
	    Function = function(Callback: boolean)
	        if Callback then
	            KillNotifications:Clean(VapeEvents.PlayerKill.Event:Connect(function(Killer: string, Victim: string)
	                if Victim == LocalPlayer.Name and Killer ~= LocalPlayer.Name then
	                    SendNotification("KillNotifications", `{Killer} killed you!`, 5)
	                end
	            end))
	        end
	    end,
	    Tooltip = "Sends a notification of who killed you."
	})
end)

Run(function()
	local AutoDetonate
	local SafeCheck
	local LocalC4
	local Ticks: number = 0
	local RayParams: RaycastParams = RaycastParams.new()
	RayParams.CollisionGroup = "ClientBullet"
	RayParams.FilterType = Enum.RaycastFilterType.Exclude
	
	AutoDetonate = vape.Categories.Utility:CreateModule({
	    Name = "AutoDetonate",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoDetonate:Clean(CollectionService:GetInstanceAddedSignal("C4"):Connect(function(Object: Instance)
	                if Object:GetAttribute("UserId") == LocalPlayer.UserId then
	                    LocalC4 = Object
	                end
	            end))
	
	            for _, Object: Instance in CollectionService:GetTagged("C4") do
	                if Object:GetAttribute("UserId") == LocalPlayer.UserId then
	                    LocalC4 = Object
	                end
	            end
	
	            repeat
	                local Backpack = LocalPlayer:FindFirstChildWhichIsA("Backpack")
	
	                if Backpack and LocalC4 then
	                    local Tool = Backpack:FindFirstChild("C4 Explosive")
	
	                    if Tool then
	                        local Ent = Entity.EntityPosition({
	                            Players = true,
	                            Part = "RootPart",
	                            Range = 25,
	                            Origin = LocalC4.Position
	                        })
	
	                        if Ent then
	                            RayParams.FilterDescendantsInstances = {Ent.Character, LocalPlayer.Character, LocalC4}
	
	                            local RootOffset: Vector3 = (Entity.character.RootPart.Position - LocalC4.Position)
	                            local Obstruction = workspace:Raycast(LocalC4.Position, (Ent.RootPart.Position - LocalC4.Position), RayParams)
	                            if SafeCheck.Enabled and not Obstruction then
	                                Obstruction = not (workspace:Raycast(LocalC4.Position, RootOffset, RayParams) or RootOffset.Magnitude > 40)
	                            end
	
	                            if not Obstruction then
	                                Ticks += 1
	                                if Ticks > 3 then
	                                    local Equipped = LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
	                                    if Equipped then
	                                        Equipped.Parent = Backpack
	                                    end
	
	                                    Tool.Parent = LocalPlayer.Character
	                                    task.spawn(function()
	                                        ReplicatedStorage.Remotes.C4.ActivateC4:InvokeServer()
	                                    end)
	                                    Tool.Parent = Backpack
	
	                                    if Equipped then
	                                        Equipped.Parent = LocalPlayer.Character
	                                    end
	                                end
	
	                                task.wait(0.05)
	                                continue
	                            end
	                        end
	                    end
	                end
	
	                Ticks = 0
	                task.wait(0.05)
	            until not AutoDetonate.Enabled
	        end
	    end,
	    Tooltip = "Automatically detonate when enemies are nearby."
	})
	SafeCheck = AutoDetonate:CreateToggle({
	    Name = "Safety Check"
	})
end)

Run(function()
	local AutoReload
	local HotSwap
	local Thread, OldPlaySound
	local Priority: {[string]: number} = {
	    M4A1 = 1,
	    ["AK-47"] = 1,
	    MP5 = 1,
	    FAL = 1,
	    ["Remington 870"] = 2,
	    M9 = 3,
	    Revolver = 4
	}
	
	local function GetWeapon()
	    local Weapons: {Instance} = {}
	    local Backpack = LocalPlayer:FindFirstChildWhichIsA("Backpack")
	    if Backpack then
	        for _, Tool: Instance in Backpack:GetChildren() do
	            if Tool:GetAttribute("FireRate") and (Tool:GetAttribute("Local_ReloadSession") or 0) <= 0 and Tool.Name ~= "Taser" and Tool.Name ~= "M700" then
	                table.insert(Weapons, Tool)
	            end
	        end
	
	        table.sort(Weapons, function(A: Instance, B: Instance)
	            return (Priority[A.Name] or 100) < (Priority[B.Name] or 100)
	        end)
	
	        return Weapons[1]
	    end
	end
	
	AutoReload = vape.Categories.Utility:CreateModule({
	    Name = "AutoReload",
	    Function = function(Callback: boolean)
	        if Callback then
	            TracerHook:Add("AutoReload", function(...)
	                if Thread then
	                    return
	                end
	
	                Thread = task.defer(function()
	                    Thread = nil
	
	                    local Tool = debug.getupvalue(PrisonLife.Shoot, 1)
	                    if Tool and Tool:GetAttribute("Local_CurrentAmmo") <= 0 then
	                        task.spawn(PrisonLife.Reload)
	
	                        if HotSwap.Enabled then
	                            local Weapon = GetWeapon()
	
	                            if Weapon then
	                                Tool.Parent = LocalPlayer.Backpack
	                                Weapon.Parent = LocalPlayer.Character
	                            end
	                        end
	                    end
	                end)
	            end)
	
	            OldPlaySound = hookfunction(PrisonLife.PlaySound, function(SoundName: string)
	                local SoundObject = debug.getupvalue(PrisonLife.Shoot, 1)
	                SoundObject = SoundObject and SoundObject:FindFirstChild("Handle")
	                SoundObject = SoundObject and SoundObject:FindFirstChild(SoundName)
	
	                if SoundObject then
	                    local Clone = SoundObject:Clone()
	                    Clone.Parent = SoundObject.Parent
	                    Clone:Play()
	                    task.delay(5, Clone.Destroy, Clone)
	                end
	            end)
	        else
	            TracerHook:Remove("AutoReload")
	            if OldPlaySound then
	                if restorefunction then
	                    restorefunction(PrisonLife.PlaySound)
	                else
	                    hookfunction(PrisonLife.PlaySound, OldPlaySound)
	                end
	                OldPlaySound = nil
	            end
	        end
	    end,
	    Tooltip = "Automatically reload after reaching 0 bullets"
	})
	HotSwap = AutoReload:CreateToggle({
	    Name = "Auto Swap",
	    Tooltip = "Automatically swap weapons when reloading"
	})
end)

Run(function()
	local AutoToxic
	local Toggles, Lists, Cloned, Presets = {}, {}, {}, {}
	
	local function SendMessage(Name: string, Target: string?, Default: string)
	    local Message = Default
	    if #Lists[Name].ListEnabled > 0 then
	        if #Cloned[Name] <= 0 then
	            Cloned[Name] = table.clone(Lists[Name].ListEnabled)
	        end
	
	        local Entry: number = Random.new():NextInteger(1, #Cloned[Name])
	        Message = Cloned[Name][Entry]
	        table.remove(Cloned[Name], Entry)
	    end
	
	    if not Message then
	        return
	    end
	
	    Message = Message and Message:gsub("<obj>", Target or "") or ""
	    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	        if TextChatService:CanUserChatAsync(LocalPlayer.UserId) then
	            TextChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(Message)
	        else
	            TextChatService.ChatInputBarConfiguration.TargetTextChannel:SendPresetAsync(Presets[Message] or Presets["So close"])
	        end
	    else
	        ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(Message, "All")
	    end
	end
	
	AutoToxic = vape.Categories.Utility:CreateModule({
	    Name = "AutoToxic",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoToxic:Clean(VapeEvents.CheaterKicked.Event:Connect(function(PlayerName: string)
	                SendMessage("Kicked", PlayerName, "skill issue cheat | <obj>")
	            end))
	        end
	    end,
	    Tooltip = "Says a message after a cheater gets kicked with CheatDetector enabled."
	})
	for _, v: string in {"Kicked"} do
	    Cloned[v] = {}
	    Toggles[v] = AutoToxic:CreateToggle({
	        Name = `{v} `,
	        Function = function(Callback: boolean)
	            if Lists[v] then
	                Lists[v].Object.Visible = Callback
	            end
	        end,
	        Default = true
	    })
	    Lists[v] = AutoToxic:CreateTextList({
	        Name = v,
	        Darker = true,
	        Function = function()
	            table.clear(Cloned[v])
	        end
	    })
	end
	
	pcall(function()
	    for _, Group: any in TextChatService:GetPresetsAsync().categoryGroups do
	        for _, Category: any in Group.categories do
	            for _, Preset: any in Category.messages do
	                Presets[Preset.value] = Preset.presetId
	            end
	        end
	    end
	end)
end)

Run(function()
	local CheatDetector
	local AddTarget
	local Overlap: OverlapParams = OverlapParams.new()
	Overlap.CollisionGroup = "Players"
	Overlap.FilterDescendantsInstances = {workspace.CarContainer, workspace.Doors}
	Overlap.FilterType = Enum.RaycastFilterType.Exclude
	local CarOverlap: OverlapParams = OverlapParams.new()
	CarOverlap.FilterDescendantsInstances = {workspace.CarContainer}
	CarOverlap.FilterType = Enum.RaycastFilterType.Include
	CarOverlap.MaxParts = 1
	
	local WhitelistStates = {
	    [Enum.HumanoidStateType.Running] = true,
	    [Enum.HumanoidStateType.Jumping] = true,
	    [Enum.HumanoidStateType.Freefall] = true,
	    [Enum.HumanoidStateType.Landed] = true,
	    [Enum.HumanoidStateType.FallingDown] = true,
	    [Enum.HumanoidStateType.GettingUp] = true,
	    [Enum.HumanoidStateType.Climbing] = true,
	    [Enum.HumanoidStateType.Seated] = true,
	    [Enum.HumanoidStateType.Ragdoll] = true,
	    [Enum.HumanoidStateType.Dead] = true,
	    [Enum.HumanoidStateType.None] = true
	}
	
	CheatDetector = vape.Categories.Utility:CreateModule({
	    Name = "CheatDetector",
	    Function = function(Callback: boolean)
	        if Callback then
	            CheatDetector:Clean(VapeEvents.CheatFlagged.Event:Connect(function(Player: Player, FlagName: string)
	                SendNotification("CheatDetector", `This player may be cheating! ({FlagName}): {Player.Name}`, 60, "warning")
	                if AddTarget.Enabled then
	                    TempTargets[Player.Name] = true
	                end
	
	                local Ent = Entity.getEntity(Player)
	                if Ent then
	                    Entity.Events.EntityUpdated:Fire(Ent)
	                    if AddTarget.Enabled then
	                        Ent.Target = true
	                    end
	                end
	            end))
	
	            repeat
	                for _, Ent: any in Entity.List do
	                    if Ent.Health > 0 and Ent.Player then
	                        if not CheckPoint(Ent.Head.Position, Overlap) then
	                            CheatFlags:Flag(Ent.Player, "phase/noclip", 20)
	                        end
	
	                        if not WhitelistStates[Ent.Humanoid:GetState()] then
	                            CheatFlags:Flag(Ent.Player, `invalid state {Ent.Humanoid:GetState().Name}`, 1)
	                        end
	
	                        local Velocity: Vector3 = Ent.RootPart.AssemblyLinearVelocity
	                        if not Ent.Humanoid.SeatPart then
	                            if (Velocity * Vector3.new(1, 0, 1)).Magnitude > 26 then
	                                if #workspace:GetPartBoundsInRadius(Ent.RootPart.Position, 30, CarOverlap) <= 0 then
	                                    CheatFlags:Flag(Ent.Player, "speed", 20)
	                                end
	                            end
	
	                            if Velocity.Y > 50 then
	                                CheatFlags:Flag(Ent.Player, "highjump", 20)
	                            end
	                        end
	                    end
	                end
	
	                task.wait(0.05)
	            until not CheatDetector.Enabled
	        else
	            CheatFlags:Clear()
	        end
	    end,
	    Tooltip = "Sends alerts for any possible cheaters."
	})
	AddTarget = CheatDetector:CreateToggle({
	    Name = "Temporary Target",
	    Tooltip = "Add temporary combat module priority for cheaters.",
	    Default = true
	})
end)

Run(function()
	local Disabler
	local Old
	
	local function EntityAdded(Ent)
	    task.defer(function()
	        Old = getconnections(Ent.Head:GetPropertyChangedSignal("CanCollide"))[1]
	        if Old then
	            Old:Disable()
	        end
	    end)
	end
	
	Disabler = vape.Categories.Utility:CreateModule({
	    Name = "Disabler",
	    Function = function(Callback: boolean)
	        if Callback then
	            Disabler:Clean(Entity.Events.LocalAdded:Connect(EntityAdded))
	            if Entity.isAlive then
	                task.spawn(EntityAdded, Entity.character)
	            end
	        else
	            if Old then
	                Old:Enable()
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Fixes phase with Character mode.",
	    ExtraText = function()
	        return "Phase"
	    end
	})
end)

Run(function()
	local AutoArmor
	local Pickups: {Instance} = {}
	
	AutoArmor = vape.Categories.Inventory:CreateModule({
	    Name = "AutoArmor",
	    Function = function(Callback: boolean)
	        if Callback then
	            Pickups = workspace.Prison_ITEMS.clothes:GetChildren()
	
	            AutoArmor:Clean(workspace.Prison_ITEMS.clothes.ChildAdded:Connect(function(Object: Instance)
	                table.insert(Pickups, Object)
	            end))
	
	            AutoArmor:Clean(workspace.Prison_ITEMS.clothes.ChildRemoved:Connect(function(Object: Instance)
	                local Index: number? = table.find(Pickups, Object)
	                if Index then
	                    table.remove(Pickups, Index)
	                end
	            end))
	
	            repeat
	                if Entity.isAlive and Entity.character.Humanoid.MaxHealth <= 100 then
	                    local LocalPosition: Vector3 = Entity.character.RootPart.Position
	
	                    for _, v: Instance in Pickups do
	                        if (v:GetPivot().Position - LocalPosition).Magnitude < 10 and Gamepasses[v:GetAttribute("RequiredGamepass")] and AutoArmor.Enabled then
	                            if v.Name == "Light Vest" and Gamepasses[LocalPlayer.Team == Teams.Criminals and "Mafia" or "Riot Police"] then
	                                continue
	                            end
	
	                            ReplicatedStorage.Remotes.InteractWithItem:InvokeServer(v:FindFirstChildWhichIsA("BasePart"))
	                        end
	                    end
	                end
	
	                task.wait(0.05)
	            until not AutoArmor.Enabled
	        else
	            table.clear(Pickups)
	        end
	    end,
	    Tooltip = "Automatically equip armor from the wall."
	})
end)

Run(function()
	local AutoHeal
	local HealItems: {[string]: boolean} = {
	    Breakfast = true,
	    Lunch = true,
	    Dinner = true
	}
	
	AutoHeal = vape.Categories.Inventory:CreateModule({
	    Name = "AutoHeal",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local Ent = Entity.isAlive and Entity.character
	                if Ent and Ent.Humanoid.Health <= 85 then
	                    local HealTool
	                    local Backpack = LocalPlayer:FindFirstChildWhichIsA("Backpack")
	                    if Backpack then
	                        for _, v: Instance in Backpack:GetChildren() do
	                            if HealItems[v.Name] then
	                                HealTool = v
	                            end
	                        end
	
	                        if HealTool and (os.clock() - (HealTool:GetAttribute("Client_LastConsumedAt") or 0)) >= 3 then
	                            local Equipped = Ent.Character:FindFirstChildWhichIsA("Tool")
	                            if Equipped then
	                                Equipped.Parent = Backpack
	                            end
	
	                            HealTool.Parent = Ent.Character
	                            HealTool:SetAttribute("Quantity", HealTool:GetAttribute("Quantity") - 1)
	                            HealTool:SetAttribute("Client_LastConsumedAt", os.clock())
	                            SendNotification("AutoHeal", `Quantity: {HealTool:GetAttribute("Quantity")}`, 3)
	                            ReplicatedStorage.Remotes.EatFood:FireServer()
	                            HealTool.Parent = Backpack
	
	                            if Equipped then
	                                Equipped.Parent = Ent.Character
	                            end
	                        end
	                    end
	                end
	
	                task.wait(0.05)
	            until not AutoHeal.Enabled
	        end
	    end,
	    Tooltip = "Automatically heal damage with consumables."
	})
end)

Run(function()
	local AutoHotbar
	local SortList: {[string]: number} = {}
	
	local function DoSorting()
	    table.sort(PrisonLife.SwitchTable, function(A, B)
	        return (SortList[A.Tool.name] or 999 + A.Slot) < (SortList[B.Tool.name] or 999 + B.Slot)
	    end)
	
	    task.spawn(PrisonLife.SwitchUpdate)
	end
	
	local function EntityAdded()
	    local Backpack = LocalPlayer:FindFirstChildWhichIsA("Backpack")
	    if Backpack then
	        AutoHotbar:Clean(Backpack.ChildAdded:Connect(function(Tool: Instance)
	            if SortList[Tool.Name] then
	                task.defer(DoSorting)
	            end
	        end))
	    end
	
	    DoSorting()
	end
	
	AutoHotbar = vape.Categories.Inventory:CreateModule({
	    Name = "AutoHotbar",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoHotbar:Clean(Entity.Events.LocalAdded:Connect(EntityAdded))
	            if Entity.isAlive then
	                task.spawn(EntityAdded)
	            end
	        end
	    end,
	    Tooltip = "Automatically sort hotbar entries"
	})
	AutoHotbar:CreateTextList({
	    Name = "Sort Order",
	    Default = {"1/AK-47", "1/MP5", "1/M4A1", "2/Remington 870", "2/M700", "3/M9", "3/Revolver", "4/Taser"},
	    Function = function(List: {string})
	        table.clear(SortList)
	        for _, Entry: string in List do
	            local Parts: {string} = Entry:split("/")
	            local Priority: number? = tonumber(Parts[1])
	            SortList[Parts[2]] = Priority or 999
	        end
	    end
	})
end)

Run(function()
	local AutoPickup
	local Lists = {}
	local Items = {}
	local SortedPickups = {Guard = {}, Prisoner = {}, Criminal = {}}
	
	local function AddPickup(Object: Instance)
	    if Object:IsA("Model") and Object.Name ~= "Model" and Object:GetAttribute("ToolName") then
	        table.insert(Items, {Object, Object.Name == "TouchGiver"})
	    end
	end
	
	AutoPickup = vape.Categories.Inventory:CreateModule({
	    Name = "AutoPickup",
	    Function = function(Callback: boolean)
	        if Callback then
	            for _, Object: Instance in workspace:GetChildren() do
	                task.spawn(AddPickup, Object)
	            end
	
	            for _, Object: Instance in workspace:QueryDescendants("Model > .TouchGiver") do
	                task.spawn(AddPickup, Object)
	            end
	
	            AutoPickup:Clean(workspace.ChildAdded:Connect(AddPickup))
	            AutoPickup:Clean(workspace.ChildRemoved:Connect(function(Object: Instance)
	                for i: number, Entry: any in Items do
	                    if Entry[1] == Object then
	                        table.remove(Items, i)
	                        break
	                    end
	                end
	            end))
	
	            repeat
	                if Entity.isAlive then
	                    local LocalPosition: Vector3 = Entity.character.RootPart.Position
	                    local Backpack = LocalPlayer:FindFirstChildWhichIsA("Backpack")
	
	                    if Backpack then
	                        for _, v: any in Items do
	                            if v[1].PrimaryPart and (v[1].PrimaryPart.Position - LocalPosition).Magnitude < 12 then
	                                local ToolName = v[1]:GetAttribute("ToolName")
	                                if v[2] then
	                                    local Found: boolean = false
	                                    for _, Entry: string in SortedPickups[LocalPlayer.Team == Teams.Guards and "Guard" or (LocalPlayer.Team == Teams.Criminals and "Criminal" or "Prisoner")] do
	                                        if not Backpack:FindFirstChild(Entry) then
	                                            Found = ToolName ~= Entry
	                                            break
	                                        end
	                                    end
	
	                                    if Found then
	                                        continue
	                                    end
	                                end
	
	                                if not Backpack:FindFirstChild(ToolName) then
	                                    ReplicatedStorage.Remotes.GiverPressed:FireServer(v[1])
	                                end
	                            end
	                        end
	                    end
	                end
	
	                task.wait(0.05)
	            until not AutoPickup.Enabled
	        else
	            table.clear(Items)
	        end
	    end,
	    Tooltip = "Automatically grab item pickups"
	})
	
	for _, v: string in {"Prisoner", "Guard", "Criminal"} do
	    AutoPickup:CreateTextList({
	        Name = `{v} Pickups`,
	        Default = {v == "Criminal" and "1/AK-47" or "1/MP5", "2/Remington 870"},
	        Placeholder = "priority/item",
	        Function = function(List: {string})
	            table.clear(SortedPickups[v])
	            for _, Entry: string in List do
	                local Parts: {string} = Entry:split("/")
	                local Priority: number? = tonumber(Parts[1])
	                SortedPickups[v][Priority or 999] = Parts[2]
	            end
	        end
	    })
	end
end)

Run(function()
	local BulletTracers
	local Material
	local Color
	local Lifetime
	local Fade
	local DrawingToggle
	local DrawingObjects = {}
	
	BulletTracers = vape.Legit:CreateModule({
	    Name = "BulletTracers",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_bullettracers.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            TracerHook:Add("BulletTracers", function(...)
	                local Origin, Direction = ...
	                if vtool then
	                    Origin = vtool.Muzzle.Position
	                end
	
	                local Velocity: Vector3 = CFrame.lookAt(Origin, Direction).LookVector * 1000
	                if DrawingToggle.Enabled then
	                    local Line = Drawing.new("Line")
	                    Line.Thickness = 2
	                    Line.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	                    DrawingObjects[Line] = {Origin, Origin + Velocity, os.clock()}
	                    task.delay(Lifetime.Value, function()
	                        DrawingObjects[Line] = nil
	                        Line.Visible = false
	                        Line:Remove()
	                    end)
	                else
	                    local Tracer: Part = Instance.new("Part")
	                    Tracer.Size = Vector3.new(0.1, 0.1, Velocity.Magnitude)
	                    Tracer.CFrame = CFrame.lookAt(Origin + (Velocity / 2), Origin + Velocity)
	                    Tracer.CanCollide = false
	                    Tracer.CanQuery = false
	                    Tracer.Anchored = true
	                    Tracer.Material = Enum.Material[Material.Value]
	                    Tracer.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	                    Tracer.Transparency = 1 - Color.Opacity
	                    Tracer.Parent = workspace
	                    if Fade.Enabled then
	                        local Tween: Tween = TweenService:Create(Tracer, TweenInfo.new(Lifetime.Value), {
	                            Transparency = 1
	                        })
	                        Tween.Completed:Connect(function()
	                            Tween:Destroy()
	                        end)
	                        Tween:Play()
	                    end
	
	                    task.delay(Lifetime.Value, Tracer.Destroy, Tracer)
	                end
	
	                return true
	            end, 1)
	
	            if DrawingToggle.Enabled then
	                BulletTracers:Clean(RunService.RenderStepped:Connect(function()
	                    for Line: any, Data: any in DrawingObjects do
	                        local FromPoint, FromVisible = Camera:WorldToViewportPoint(Data[1])
	                        local ToPoint, ToVisible = Camera:WorldToViewportPoint(Data[2])
	                        if FromVisible and ToVisible then
	                            Line.Visible = true
	                            Line.From = Vector2.new(FromPoint.X, FromPoint.Y)
	                            Line.To = Vector2.new(ToPoint.X, ToPoint.Y)
	                            if Fade.Enabled then
	                                Line.Transparency = Color.Opacity * (1 - math.clamp((os.clock() - Data[3]) / Lifetime.Value, 0, 1))
	                            end
	                        else
	                            Line.Visible = false
	                        end
	                    end
	                end))
	            end
	        else
	            TracerHook:Remove("BulletTracers")
	        end
	    end,
	    Tooltip = "Allow you to customize bullet tracers."
	})
	local Materials: {string} = {"SmoothPlastic"}
	for _, v: EnumItem in Enum.Material:GetEnumItems() do
	    if v.Name ~= "SmoothPlastic" then
	        table.insert(Materials, v.Name)
	    end
	end
	Material = BulletTracers:CreateDropdown({
	    Name = "Material",
	    List = Materials
	})
	Color = BulletTracers:CreateColorSlider({
	    Name = "Tracer Color",
	    DefaultOpacity = 0.5
	})
	Lifetime = BulletTracers:CreateSlider({
	    Name = "Lifetime",
	    Min = 0,
	    Max = 0.5,
	    Default = 0.2,
	    Decimal = 10
	})
	Fade = BulletTracers:CreateToggle({
	    Name = "Fade",
	    Default = true
	})
	DrawingToggle = BulletTracers:CreateToggle({
	    Name = "Drawing",
	    Function = function()
	        if BulletTracers.Enabled then
	            BulletTracers:Toggle()
	            BulletTracers:Toggle()
	        end
	    end
	})
end)

Run(function()
	local Crosshair
	local Image
	local Old
	
	Crosshair = vape.Legit:CreateModule({
	    Name = "Crosshair",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_crosshair.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            debug.setconstant(OldEquip or PrisonLife.Equip, 30, Image.Value:find("rbxasset") and Image.Value or isfile(Image.Value) and getcustomasset(Image.Value) or "")
	        else
	            debug.setconstant(OldEquip or PrisonLife.Equip, 30, "rbxassetid://98794608762931")
	        end
	    end,
	    Tooltip = "Change the crosshair icon"
	})
	Image = Crosshair:CreateTextBox({
	    Name = "Image",
	    Placeholder = "assetid",
	    Function = function()
	        if Crosshair.Enabled then
	            debug.setconstant(OldEquip or PrisonLife.Equip, 30, Image.Value:find("rbxasset") and Image.Value or isfile(Image.Value) and getcustomasset(Image.Value) or "")
	        end
	    end
	})
end)

Run(function()
	local DamageIndicator
	local FontOption
	local ColorV
	local Size
	local TargetEntity, LastEntity
	local TargetHealth, TargetTimer = 0, 0
	local Indicator, IndicatorPart, IndicatorThread
	
	local function RenderStepForLoop(StartValue: number, EndValue: number, Increment: number, Callback)
	    while true do
	        if EndValue >= StartValue then
	            if Callback(StartValue) then
	                return
	            else
	                local StartTick: number = tick()
	                RunService.RenderStepped:Wait()
	                StartValue = StartValue + Increment * (tick() - StartTick) * 60
	            end
	        else
	            Callback(EndValue)
	            return
	        end
	    end
	end
	
	local function CreateIndicator(Damage: number, Position: Vector3)
	    if IndicatorThread then
	        task.cancel(IndicatorThread)
	        Indicator.Text = math.ceil(tonumber(Indicator.Text) + Damage)
	        IndicatorPart.Position = Position
	    else
	        IndicatorPart = Instance.new("Part")
	        IndicatorPart.Size = Vector3.zero
	        IndicatorPart.Position = Position
	        IndicatorPart.CanCollide = false
	        IndicatorPart.CanQuery = false
	        IndicatorPart.Anchored = true
	        IndicatorPart.Parent = workspace
	        local Billboard: BillboardGui = Instance.new("BillboardGui")
	        Billboard.Adornee = IndicatorPart
	        Billboard.Size = UDim2.new(15, 250, 15, 250)
	        Billboard.AlwaysOnTop = true
	        Billboard.Parent = IndicatorPart
	        Indicator = Instance.new("TextLabel")
	        Indicator.BackgroundTransparency = 1
	        Indicator.TextStrokeTransparency = 0
	        Indicator.Size = UDim2.fromScale(1, 0.075)
	        Indicator.Position = UDim2.fromScale(0.5, 0.5)
	        Indicator.AnchorPoint = Vector2.new(0.5, 0.5)
	        Indicator.Text = math.ceil(Damage)
	        Indicator.TextColor3 = Color3.fromHSV(ColorV.Hue, ColorV.Sat, ColorV.Value)
	        Indicator.TextScaled = true
	        Indicator.Font = Enum.Font[FontOption.Value]
	        Indicator.Parent = Billboard
	    end
	
	    if IndicatorThread then
	        task.cancel(IndicatorThread)
	        IndicatorThread = nil
	    end
	
	    IndicatorThread = task.spawn(function()
	        local Sign: number = math.sign(math.random() - 0.5)
	        RenderStepForLoop(0, 100, 3, function(Value: number)
	            local Percent: number = Value / 100
	            local SineValue: number = TweenService:GetValue(Percent, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	            local BackValue: number = TweenService:GetValue(Percent, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	            local Scale: number = 1 - 0.5 * BackValue
	            Indicator.Position = UDim2.new(0.5 + 0.125 * SineValue * Sign, 0, 0.5 + 0.125 * BackValue, 0)
	            Indicator.Size = UDim2.new(1 * Scale, 0, 0.075 * Scale * (v197 and 1 or 0.75), 0)
	            Indicator.Rotation = Percent ^ 4 * 260 * Sign
	        end)
	
	        IndicatorPart:Destroy()
	        IndicatorPart = nil
	        IndicatorThread = nil
	    end)
	end
	
	DamageIndicator = vape.Legit:CreateModule({
	    Name = "DamageIndicator",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_damageindicator.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            TracerHook:Add("DamageIndicator", function(...)
	                local Part = debug.getstack(4, 17)
	                if typeof(Part) == "Instance" then
	                    for _, v: any in Entity.List do
	                        if Part:IsDescendantOf(v.Character) and Entity.isVulnerable(v, true) then
	                            if TargetTimer <= os.clock() or v ~= TargetEntity then
	                                TargetHealth = v.Health
	                            end
	
	                            TargetEntity = v
	                            TargetTimer = os.clock() + 0.5
	                            break
	                        end
	                    end
	                end
	            end)
	
	            DamageIndicator:Clean(Entity.Events.EntityUpdated:Connect(function(Ent)
	                if Ent == TargetEntity and TargetTimer > os.clock() then
	                    if Ent ~= LastEntity then
	                        if Indicator then
	                            Indicator.Text = "0"
	                        end
	
	                        LastEntity = Ent
	                    end
	
	                    if TargetHealth > Ent.Health then
	                        CreateIndicator(TargetHealth - Ent.Health, Ent.Head.Position + Vector3.new(0, 2, 0))
	                        TargetHealth = Ent.Health
	                    end
	                end
	            end))
	        else
	            TracerHook:Remove("DamageIndicator")
	        end
	    end,
	    Tooltip = "Add custom damage indicators for gun damage."
	})
	local FontItems: {string} = {"GothamBlack"}
	for _, v: EnumItem in Enum.Font:GetEnumItems() do
	    if v.Name ~= "GothamBlack" then
	        table.insert(FontItems, v.Name)
	    end
	end
	FontOption = DamageIndicator:CreateDropdown({
	    Name = "Font",
	    List = FontItems,
	    Function = function(Val: string)
	        if Indicator then
	            Indicator.Font = Enum.Font[Val]
	        end
	    end
	})
	ColorV = DamageIndicator:CreateColorSlider({
	    Name = "Color",
	    DefaultHue = 0,
	    Function = function(Hue: number, Sat: number, Val: number)
	        if Indicator then
	            Indicator.TextColor3 = Color3.fromHSV(Hue, Sat, Val)
	        end
	    end
	})
end)

Run(function()
	local HitSound
	local Value
	local Volume
	local PitchShift
	local Old, Sounds = nil, {}
	
	HitSound = vape.Legit:CreateModule({
	    Name = "HitSound",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_hitsound.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            local Played
	            TracerHook:Add("HitSound", function(...)
	                local Part = debug.getstack(4, 17)
	                if typeof(Part) == "Instance" then
	                    for _, v: any in Entity.List do
	                        if Part:IsDescendantOf(v.Character) and Entity.isVulnerable(v, true) then
	                            if #Sounds > 0 and not Played then
	                                local Sound: Sound = Instance.new("Sound")
	                                Sound.SoundId = Sounds[math.random(1, #Sounds)]
	                                Sound.PlayOnRemove = true
	                                Sound.PlaybackSpeed = PitchShift.Enabled and 1 + ((0.5 - math.random()) / 10) or 1
	                                Sound.Volume = Volume.Value
	                                Sound.Parent = workspace
	                                Sound:Destroy()
	                                Played = task.defer(function()
	                                    Played = nil
	                                end)
	                            end
	
	                            break
	                        end
	                    end
	                end
	            end)
	        else
	            TracerHook:Remove("HitSound")
	        end
	    end,
	    Tooltip = "Custom hit sound"
	})
	Value = HitSound:CreateTextList({
	    Name = "Sounds",
	    Placeholder = "sound id (roblox or file path)",
	    Function = function(List)
	        table.clear(Sounds)
	        for i: number, v: string in List or {} do
	            Sounds[i] = v:find("rbxasset") and v or isfile(v) and getcustomasset(v) or nil
	        end
	    end
	})
	Volume = HitSound:CreateSlider({
	    Name = "Volume",
	    Min = 0,
	    Max = 2,
	    Default = 1,
	    Decimal = 10
	})
	PitchShift = HitSound:CreateToggle({
	    Name = "Pitch Shift"
	})
end)

Run(function()
	local KillSound
	local Value
	local Volume
	local PitchShift
	local Old, Sounds = nil, {}
	
	KillSound = vape.Legit:CreateModule({
	    Name = "KillSound",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_killsound.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            KillSound:Clean(VapeEvents.PlayerKill.Event:Connect(function(PlayerName: string)
	                if PlayerName == LocalPlayer.Name and #Sounds > 0 then
	                    local Sound: Sound = Instance.new("Sound")
	                    Sound.SoundId = Sounds[math.random(1, #Sounds)]
	                    Sound.PlayOnRemove = true
	                    Sound.PlaybackSpeed = PitchShift.Enabled and 1 + ((0.5 - math.random()) / 10) or 1
	                    Sound.Volume = Volume.Value
	                    Sound.Parent = workspace
	                    Sound:Destroy()
	                end
	            end))
	        end
	    end,
	    Tooltip = "Custom kill sound"
	})
	Value = KillSound:CreateTextList({
	    Name = "Sounds",
	    Placeholder = "sound id (roblox or file path)",
	    Function = function(List)
	        table.clear(Sounds)
	        for i: number, v: string in List or {} do
	            Sounds[i] = v:find("rbxasset") and v or isfile(v) and getcustomasset(v) or nil
	        end
	    end
	})
	Volume = KillSound:CreateSlider({
	    Name = "Volume",
	    Min = 0,
	    Max = 2,
	    Default = 1,
	    Decimal = 10
	})
	PitchShift = KillSound:CreateToggle({
	    Name = "Pitch Shift"
	})
end)

Run(function()
	local Viewmodel
	local Depth
	local Horizontal
	local Vertical
	local Sway
	local ForceField
	local ColorSl
	local Handle
	local OldTool
	local MoveSpring = Spring.new()
	local AimSpring = Spring.new({Speed = 15})
	
	local function ToolAdded(Tool: Instance?)
	    if Tool and Tool:IsA("Tool") then
	        if OldTool then
	            for _, v: Instance in OldTool:QueryDescendants("BasePart, Texture, Decal") do
	                v.LocalTransparencyModifier = 0
	            end
	        end
	
	        if vtool then
	            vtool:Destroy()
	        end
	
	        OldTool = Tool
	        vtool = Tool:Clone()
	        Handle = vtool:FindFirstChild("Handle")
	        vtool.Parent = Camera
	
	        for _, v: BasePart in vtool:QueryDescendants("BasePart") do
	            v.Material = ForceField.Enabled and Enum.Material.ForceField or v.Material
	            v.Color = ForceField.Enabled and Color3.fromHSV(ColorSl.Hue, ColorSl.Sat, ColorSl.Value) or v.Color
	        end
	
	        for _, v: Instance in OldTool:QueryDescendants("BasePart, Texture, Decal") do
	            v.LocalTransparencyModifier = 1
	        end
	    end
	end
	
	local function EntityAdded(Ent)
	    if vtool then
	        vtool:Destroy()
	        vtool = nil
	        Handle = nil
	    end
	
	    Viewmodel:Clean(Ent.Character.ChildAdded:Connect(ToolAdded))
	    Viewmodel:Clean(Ent.Character.ChildRemoved:Connect(function(Child: Instance)
	        if Child == OldTool then
	            if vtool then
	                vtool:Destroy()
	                vtool = nil
	            end
	
	            for _, v: Instance in OldTool:QueryDescendants("BasePart, Texture, Decal") do
	                v.LocalTransparencyModifier = 0
	            end
	
	            OldTool = nil
	        end
	    end))
	
	    ToolAdded(Ent.Character:FindFirstChildWhichIsA("Tool"))
	end
	
	Viewmodel = vape.Legit:CreateModule({
	    Name = "Viewmodel",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_viewmodel.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            TracerHook:Add("Viewmodel", function(...)
	                ShootTimer = os.clock() + 0.3
	            end, 0)
	
	            Viewmodel:Clean(Entity.Events.LocalAdded:Connect(EntityAdded))
	            if Entity.isAlive then
	                task.spawn(EntityAdded, Entity.character)
	            end
	
	            Viewmodel:Clean(RunService.RenderStepped:Connect(function(Delta: number)
	                if Handle then
	                    MoveSpring.Target = Entity.isAlive and Entity.character.RootPart.AssemblyLinearVelocity * 0.005 or Vector3.zero
	                    if Sway.Enabled then
	                        if MoveSpring.Target.Magnitude > 0.1 then
	                            MoveSpring.Target += (Camera.CFrame * CFrame.new(math.sin(tick() * 10) * 0.06, 0, 0)).Position - Camera.CFrame.Position
	                        else
	                            MoveSpring.Target += (Camera.CFrame * CFrame.new(0, math.sin(tick()) * 0.04, 0)).Position - Camera.CFrame.Position
	                        end
	                    end
	
	                    local ViewCFrame: CFrame = (Camera.CFrame * CFrame.new(Horizontal.Value, Vertical.Value, -Depth.Value)) + MoveSpring:Update(Delta)
	                    AimSpring.Target = AimTimer > os.clock() and CFrame.lookAt(ViewCFrame.Position, AimVector).LookVector or Camera.CFrame.LookVector
	                    Handle.CFrame = CFrame.lookAlong(ViewCFrame.Position, AimSpring:Update(Delta)) * (CFrame.Angles(math.rad(math.max(ShootTimer - os.clock(), 0) * 10), 0, 0) * CFrame.new(0, 0, math.max(ShootTimer - os.clock(), 0)))
	                    Handle.AssemblyLinearVelocity = Vector3.zero
	                end
	            end))
	        else
	            TracerHook:Remove("Viewmodel")
	
	            if OldTool then
	                for _, v: Instance in OldTool:QueryDescendants("BasePart, Texture, Decal") do
	                    v.LocalTransparencyModifier = 0
	                end
	                OldTool = nil
	            end
	
	            if vtool then
	                vtool:Destroy()
	                vtool = nil
	                Handle = nil
	            end
	        end
	    end,
	    Tooltip = "Custom viewmodel for guns"
	})
	Depth = Viewmodel:CreateSlider({
	    Name = "Depth",
	    Min = 0,
	    Max = 3,
	    Default = 3,
	    Decimal = 10
	})
	Horizontal = Viewmodel:CreateSlider({
	    Name = "Horizontal",
	    Min = 0,
	    Max = 2,
	    Default = 2,
	    Decimal = 10
	})
	Vertical = Viewmodel:CreateSlider({
	    Name = "Vertical",
	    Min = -1.5,
	    Max = 2,
	    Default = -1.5,
	    Decimal = 10
	})
	Sway = Viewmodel:CreateToggle({
	    Name = "Sway Effect",
	    Default = true
	})
	ForceField = Viewmodel:CreateToggle({
	    Name = "ForceField Effect",
	    Function = function(Callback: boolean)
	        ColorSl.Object.Visible = Callback
	        if Callback and Viewmodel.Enabled then
	            Viewmodel:Toggle()
	            Viewmodel:Toggle()
	        end
	    end
	})
	ColorSl = Viewmodel:CreateColorSlider({
	    Name = "Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        if vtool then
	            for _, v: BasePart in vtool:QueryDescendants("BasePart") do
	                v.Color = Color3.fromHSV(Hue, Sat, Val)
	            end
	        end
	    end,
	    Visible = false
	})
end)