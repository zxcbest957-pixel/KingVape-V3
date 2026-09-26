local loadstring = function(...)
    local Chunk, Message = loadstring(...)
    if Message and vape then
        vape:CreateNotification("Vape", `Failed to load : {Message}`, 30, "alert")
    end
    return Chunk
end
local isfile = isfile or function(File: string)
    local Success, Result = pcall(function()
        return readfile(File)
    end)
    return Success and Result ~= nil and Result ~= ""
end
local function DownloadFile(FilePath: string, Func)
    if not isfile(FilePath) then
        local Success, Result = pcall(function()
            return game:HttpGet(`https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/main/{select(1, FilePath:gsub("kingvape/", ""))}`, true)
        end)
        if not Success or Result == "404: Not Found" then
            error(Result)
        end
        if FilePath:find(".lua") then
            Result = `--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n{Result}`
        end
        writefile(FilePath, Result)
    end
    return (Func or readfile)(FilePath)
end
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
local TextChatService: TextChatService = cloneref(game:GetService("TextChatService"))
local RunService: RunService = cloneref(game:GetService("RunService"))
local CoreGui: CoreGui = cloneref(game:GetService("CoreGui"))

local Camera: Camera = workspace.CurrentCamera
local LocalPlayer: Player = Players.LocalPlayer
local vape = shared.vape
local Entity = vape.Libraries.entity
local TargetInfo = vape.Libraries.targetinfo
local SessionInfo = vape.Libraries.sessioninfo
local Whitelist = vape.Libraries.whitelist
local GetVapeAsset = vape.Libraries.getvapeasset
local DrawingActor = loadstring(DownloadFile("kingvape/libraries/drawing.lua"), "drawing")(...)
local Redliner = {Teams = {}}
local StartTime: number = os.clock()
local TargetStrafeVector
local LatestHash: string = "c401462bc7f7f49e53b4a8da2de5b57bc2d7e14df1b773e5ccd1bcddb28db9c843b8902d2c93738a2f042e533d3d4971"
local RedlineBoxes = {
    {
        boxtype = "redliner_melee",
        data = {
            size = Vector3.new(17.75, 14, 22),
            offset = CFrame.new(0, 0, -11)
        }
    },
    {
        boxtype = "redliner_charged_melee",
        data = {
            size = Vector3.new(39, 14, 35),
            offset = CFrame.new(0, -0.5, -9)
        }
    }
}

local function AddVelocity(Velocity: Vector3)
    if Redliner[Redliner.MoveController] and typeof(Redliner[Redliner.MoveController][Redliner.LaunchpadFunction]) == "function" then
        local Pad: Model = Instance.new("Model")
        local Origin: Part = Instance.new("Part")
        Origin.Name = "Origin"
        Origin.CFrame = CFrame.new(100, 100, 100)
        Origin.Parent = Pad
        local Goal: Part = Instance.new("Part")
        Goal.Name = "LaunchGoal"
        Goal.CFrame = CFrame.new(100, 100, 100) + (Velocity.Unit == Velocity.Unit and Velocity.Unit or Vector3.zero)
        Goal.Parent = Pad
        Redliner[Redliner.MoveController][Redliner.LaunchpadFunction](Redliner[Redliner.MoveController], Pad, {
            base_strength = Velocity.Magnitude,
            max_strength = Velocity.Magnitude
        })

        Pad:Destroy()
        Pad:ClearAllChildren()
    end
end

local function CastHitbox(Data, Origin: CFrame)
    local HitHurtboxes: {BasePart} = {}
    local Params: OverlapParams = OverlapParams.new()
    Params.FilterType = Enum.RaycastFilterType.Include
    Params.RespectCanCollide = false
    Params.FilterDescendantsInstances = CollectionService:GetTagged("Hurtbox")

    for _, v: BasePart in Params.FilterDescendantsInstances do
        v.Transparency = 0
    end

    for _, Hit: BasePart in workspace:GetPartBoundsInBox(Origin * Data.offset, Data.size, Params) do
        if Hit:FindFirstAncestorWhichIsA("Model") ~= LocalPlayer.Character then
            table.insert(HitHurtboxes, Hit)
        end
    end

    return HitHurtboxes
end

local function SearchForPacket(Func, Unreliable)
    for _, v: number | string | boolean in debug.getconstants(Func) do
        if rawget(Unreliable and Redliner.Packets.unreliablePackets or Redliner.Packets, v) then
            return v
        end
    end
end

local function GetIndicators()
    return Redliner[Redliner.IndicatorController] and Redliner[Redliner.IndicatorController][Redliner.IndicatorTable] or {}
end

local function IsFriend(Player, Recolor)
    if vape.Categories.Friends.Options["Use friends"].Enabled then
        local Friend = table.find(vape.Categories.Friends.ListEnabled, Player.Name) and true
        if Recolor then
            Friend = Friend and vape.Categories.Friends.Options["Recolor visuals"].Enabled
        end
        return Friend
    end
    return nil
end

local function IsTarget(Player)
    return table.find(vape.Categories.Targets.ListEnabled, Player.Name) and true
end

local function SendNotification(...)
    return vape:CreateNotification(...)
end

local function WarningRoutine(Hash: string)
    local FilePath: string = "kingvape/profiles/agreementhash.txt"
    if (isfile(FilePath) and readfile(FilePath) or "") ~= Hash then
        local Box: TextLabel = Instance.new("TextLabel")
        Box.Size = UDim2.fromScale(1, 1)
        Box.BackgroundColor3 = Color3.new()
        Box.BackgroundTransparency = 0.5
        Box.Text = "⚠️WARNING⚠️\nThe game's update hash is not the same as the current script hash, this ⚠️MAY⚠️ mean the game developer has added detections.\nBy clicking OK, you agree to all risks of using this product.\n\n- 7GrandDad"
        Box.TextColor3 = Color3.new(1, 1, 1)
        Box.TextScaled = true
        Box.Font = Enum.Font.Arial
        Box.Parent = vape.gui
        local Button: TextButton = Instance.new("TextButton")
        Button.AnchorPoint = Vector2.new(0.5, 0.5)
        Button.Size = UDim2.fromScale(0.2, 0.05)
        Button.Position = UDim2.fromScale(0.5, 0.95)
        Button.BackgroundColor3 = Color3.new()
        Button.Text = "OK"
        Button.TextColor3 = Color3.new(1, 1, 1)
        Button.TextScaled = true
        Button.Font = Enum.Font.Arial
        Button.Parent = Box

        Button.MouseButton1Click:Connect(function()
            writefile(FilePath, Hash)
            Box:Destroy()
        end)

        Box.Destroying:Wait()
    end
end

if not select(1, ...) then
    if run_on_actor then
        local OldReload = shared.vapereload
        vape.Load = function()
            task.delay(0.1, function()
                vape:Uninject()
            end)
        end

        task.spawn(function()
            repeat
                task.wait()
            until not shared.vape
            local ExecutionString: string = `loadfile('kingvape/main.lua')({DrawingActor})`
            for Key: string, v: any in shared do
                if type(v) == "string" then
                    ExecutionString = `{string.format("shared.%s = '%s'", Key, v)}\n{ExecutionString}`
                elseif type(v) == "boolean" then
                    ExecutionString = `{string.format("shared.%s = %s", Key, tostring(v))}\n{ExecutionString}`
                end
            end
            if OldReload then
                ExecutionString = `shared.vapereload = true\n{ExecutionString}`
            end

            if getactorthreads and run_on_thread then
                for _, v: thread in getactorthreads() do
                    run_on_thread(v, ExecutionString)
                    return
                end
            elseif getactorstates then
                for _, v: any in getactorstates() do
                    if type(v) ~= "thread" then
                        v:Execute(ExecutionString)
                        return
                    end
                end
            end

            for _, v: Actor in (getdeletedactors or getactors)() do
                run_on_actor(v, ExecutionString)
                return
            end

            LocalPlayer:Kick(`Failed to find actor, Executor: {identifyexecutor()}`)
        end)
    else
        vape.Load = function()
            SendNotification("Vape", "Missing actor functions.", 10, "alert")
        end
    end

    return
end

Run(function()
    local function WaitForChildOfType(Object, Name: string, Timeout: number, Property)
        local CheckTick: number = tick() + Timeout
        local Returned
        repeat
            Returned = Property and Object[Name] or Object:FindFirstChildOfClass(Name)
            if Returned or CheckTick < tick() then
                break
            end
            task.wait()
        until false
        return Returned
    end

    Entity.addEntity = function(Character, Player, TeamFunc, SpawnTime)
        if not Character then
            return
        end
        Entity.EntityThreads[Character] = task.spawn(function()
            local Humanoid = WaitForChildOfType(Character, "Humanoid", 10)
            local HumanoidRootPart = Humanoid and WaitForChildOfType(Humanoid, "RootPart", workspace.StreamingEnabled and 9e9 or 10, true)
            local Head = Character:WaitForChild("Head", 10) or HumanoidRootPart
            local Hitbox = Character:FindFirstChild("Head_Hurtbox", true)

            if Humanoid and HumanoidRootPart then
                local Ent = {
                    Connections = {},
                    Character = Character,
                    Health = Humanoid.Health,
                    Head = Head,
                    Hitbox = Hitbox or HumanoidRootPart,
                    Humanoid = Humanoid,
                    HumanoidRootPart = HumanoidRootPart,
                    HipHeight = Humanoid.HipHeight + (HumanoidRootPart.Size.Y / 2) + (Humanoid.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
                    MaxHealth = Humanoid.MaxHealth,
                    NPC = Player == nil,
                    Player = Player,
                    RootPart = HumanoidRootPart,
                    SpawnTime = SpawnTime or 0,
                    TeamCheck = TeamFunc
                }

                if Player == LocalPlayer then
                    Entity.character = Ent
                    Entity.isAlive = true
                    Entity.Events.LocalAdded:Fire(Ent)
                else
                    Ent.Targetable = Entity.targetCheck(Ent)

                    for _, v: RBXScriptSignal in Entity.getUpdateConnections(Ent) do
                        table.insert(Ent.Connections, v:Connect(function()
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

    if game.PlaceId == 126691165749976 then
        Entity.targetCheck = function(Ent)
            if Ent.NPC then
                return true
            end
            if IsFriend(Ent.Player) then
                return false
            end
            if not select(2, Whitelist:get(Ent.Player)) then
                return false
            end
            if vape.Settings.Modules.Options["Teams by server"].Enabled then
                if not Redliner.Teams[tostring(LocalPlayer.UserId)] then
                    return true
                end
                return Redliner.Teams[tostring(Ent.Player.UserId)] ~= Redliner.Teams[tostring(LocalPlayer.UserId)]
            end

            return true
        end

        local function UpdatePlayer(Player)
            Player = Players:GetPlayerByUserId(tonumber(Player.Name))

            if Player and Entity.Running then
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
                    if Ent and Ent.Targetable ~= Entity.targetCheck(Ent) then
                        Entity.refreshEntity(Ent.Character, Player)
                    end
                end
            end
        end

        local function ProcessPlayer(PlayerObject: Instance)
            if tonumber(PlayerObject.Name) then
                Redliner.Teams[PlayerObject.Name] = PlayerObject:GetAttribute("team_id")
                task.spawn(UpdatePlayer, PlayerObject)

                vape:Clean(PlayerObject:GetAttributeChangedSignal("team_id"):Connect(function()
                    Redliner.Teams[PlayerObject.Name] = PlayerObject:GetAttribute("team_id")
                    task.spawn(UpdatePlayer, PlayerObject)
                end))
            end
        end

        local function ProcessMatch(Match: Instance?)
            if Match and Match.Name == "Match" then
                vape:Clean(Match.DescendantAdded:Connect(ProcessPlayer))
                for _, v: Instance in Match:GetDescendants() do
                    ProcessPlayer(v)
                end
            end
        end

        vape:Clean(ReplicatedStorage.ReadOnly.ChildAdded:Connect(ProcessMatch))
        task.spawn(ProcessMatch, ReplicatedStorage.ReadOnly:FindFirstChild("Match"))
    end
end)
Entity.start()

Run(function()
    local Root

    for _ = 1, 3 do
        local DoBreak
        for _, v: ModuleScript in getloadedmodules() do
            if v:GetFullName() == "Start.Client.ClientRoot" then
                DoBreak = true
                break
            end
        end

        if DoBreak then
            break
        end

        task.wait(0.5)
    end

    for _, v: ModuleScript in getloadedmodules() do
        if v:GetFullName() == "Start.Client.ClientRoot" then
            if getscripthash(v) ~= LatestHash then
                WarningRoutine(getscripthash(v))

                if vape.Loaded == nil then
                    return
                end
            end

            Root = require(v)
            if not rawget(Root, "loaded") then
                repeat
                    task.wait()
                until rawget(Root, "loaded") or vape.Loaded == nil
            end

            if vape.Loaded == nil then
                return
            end
        end
    end

    if not Root then
        LocalPlayer:Kick("Failed to find root class, please contact 7GrandDad on discord.")
        return
    end

    local ClassList = rawget(Root, "Classes") or {}
    Redliner = setmetatable({
        CEnum = require(ReplicatedStorage.Assets.ModuleScripts.CEnum),
        Packets = require(ReplicatedStorage.Assets.ModuleScripts.Packets),
        Packet = debug.getupvalue(getrawmetatable(require(ReplicatedStorage.Assets.ModuleScripts.Packets.Packet)).__call, 3),
        Util = require(ReplicatedStorage.Assets.SharedClasses.Util),
        Teams = Redliner.Teams
    }, {
        __index = function(self, Index)
            return rawget(ClassList, Index)
        end
    })

    local DumpList = {
        Constants = {
            ShootFunction = function(Constants, Func, Module: ModuleScript)
                for _, Constant: number | string | boolean in Constants do
                    if Constant == "ViewportPointToRay" and debug.info(Func, "n"):sub(1, 1) == "_" then
                        Redliner.ShootFunction = require(Module)[debug.info(Func, "n")]
                        break
                    end
                end
            end,
            ActionController = function(Constants, Func, Module: ModuleScript)
                for _, Constant: number | string | boolean in Constants do
                    if Constant == "getAction FAILED FOR : " and debug.info(Func, "n"):sub(1, 1) == "_" then
                        Redliner.ActionController = Module.Name
                        Redliner.ActionFunction = require(Module)[debug.info(Func, "n")]
                        break
                    end
                end
            end,
            IndicatorController = function(Constants, Func, Module: ModuleScript)
                for _, Constant: number | string | boolean in Constants do
                    if Constant == "INVALID crosshair_name : " then
                        Redliner.IndicatorController = Module.Name
                        break
                    end
                end
            end,
            ActionEventPacket = function(Constants, Func, Module: ModuleScript)
                local Found
                for _, Constant: number | string | boolean in Constants do
                    if Constant == "OnClientEvent" then
                        Found = true
                    elseif Constant == "onKill" and Found then
                        Redliner.ActionEventPacket = SearchForPacket(Func, true)
                        if Redliner.ActionEventPacket then
                            Redliner.ActionEventPacket = Redliner.Packets.unreliablePackets[Redliner.ActionEventPacket]
                        end

                        break
                    end
                end
            end,
            LaunchpadFunction = function(Constants, Func, Module: ModuleScript)
                local Found
                for _, Constant: number | string | boolean in Constants do
                    if Constant == -0.007 then
                        Found = true
                    elseif Constant == "augment" and Found then
                        local Candidates = {}
                        for _, Constant: number | string | boolean in Constants do
                            if tostring(Constant):sub(1, 2) == "_x" then
                                table.insert(Candidates, Constant)
                            end
                        end

                        Redliner.LaunchpadFunction = Candidates[9]
                        break
                    end
                end
            end
        },
        Protos = {
            AttackPacket = function(Protos, Func, Module: ModuleScript)
                for _, Proto: (...any) -> ...any in Protos do
                    if debug.info(Proto, "n") == "redlinerMelee" then
                        Redliner.AttackPacket = SearchForPacket(Proto)
                        if Redliner.AttackPacket then
                            Redliner.AttackPacket = Redliner.Packets[Redliner.AttackPacket].Name
                        end

                        break
                    end
                end
            end,
            IndicatorTable = function(Protos, Func, Module: ModuleScript)
                for _, Proto: (...any) -> ...any in Protos do
                    if debug.info(Proto, "n") == "removeShotIndicator" then
                        for _, Constant: number | string | boolean in debug.getconstants(Proto) do
                            if tostring(Constant):sub(1, 1) == "_" then
                                Redliner.IndicatorTable = Constant
                                break
                            end
                        end

                        break
                    end
                end
            end,
            DashVariables = function(Protos, Func, Module: ModuleScript)
                for _, Proto: (...any) -> ...any in Protos do
                    local DoBreak: boolean = false
                    local Found: boolean = false
                    for _, Constant: number | string | boolean in debug.getconstants(Proto) do
                        if Constant == "onDeath" then
                            Found = true
                        elseif Constant == "Fire" and Found then
                            DoBreak = true
                        end
                    end

                    if DoBreak then
                        local Candidates = {}
                        for _, Constant: number | string | boolean in debug.getconstants(Proto) do
                            if tostring(Constant):sub(1, 2) == "_x" then
                                table.insert(Candidates, Constant)
                            end
                        end

                        Redliner.MoveController = Candidates[3]
                        Redliner.DashRecoverVariable = Candidates[4]
                        Redliner.DashVariable = Candidates[5]
                        break
                    end
                end
            end
        }
    }

    for _, v: BaseScript | ModuleScript in getscripts() do
        if v:GetFullName():sub(1, 5) == "Start" and v:IsA("ModuleScript") then
            local Closure = getscriptclosure(v)
            local Protos = debug.getprotos(Closure)

            if Protos[1] then
                if debug.info(Protos[1], "l") == 3 and #debug.info(Protos[1], "n") <= 2 then
                    continue
                end
            end

            for _, Func: (...any) -> ...any in debug.getprotos(Closure) do
                for Name: string, Dumper: (...any) -> ...any in DumpList.Constants do
                    if not Redliner[Name] then
                        Dumper(debug.getconstants(Func), Func, v)
                    end
                end

                for Name: string, Dumper: (...any) -> ...any in DumpList.Protos do
                    if not Redliner[Name] then
                        Dumper(debug.getprotos(Func), Func, v)
                    end
                end
            end
        end
    end

    local Kills = SessionInfo:AddItem("Kills")
    local Deaths = SessionInfo:AddItem("Deaths")
    local Games = SessionInfo:AddItem("Games")
    local Wins = SessionInfo:AddItem("Wins")

    if game.PlaceId == 126691165749976 then
        task.delay(1, function()
            Games:Increment()
        end)
    end

    if Redliner.ActionEventPacket then
        vape:Clean(Redliner.ActionEventPacket.OnClientEvent:Connect(function(Data)
            if type(Data) == "table" then
                task.spawn(function()
                    local Attacker: Player? = Data.agent and (Players:GetPlayerFromCharacter(Data.agent) or Players:FindFirstChild(Data.agent.Name))
                    local Victim: Player? = Data.victim and (Players:GetPlayerFromCharacter(Data.victim) or Players:FindFirstChild(Data.victim.Name))

                    if Data.action == "killed" then
                        if Attacker == LocalPlayer then
                            VapeEvents.PlayerKill:Fire()
                            Kills:Increment()
                        elseif Victim == LocalPlayer then
                            Deaths:Increment()
                        end
                    elseif Data.action == "hit" and Attacker == LocalPlayer then
                        VapeEvents.Hit:Fire()
                    end
                end)
            end
        end))
    end

    vape:Clean(VapeEvents.MatchEnded.Event:Connect(function(Won: boolean)
        if Won then
            Wins:Increment()
        end
    end))

    vape:Clean(LocalPlayer.PlayerGui.ChildAdded:Connect(function(Object: Instance)
        if Object.Name == "MatchResultsScreen" then
            local Results: Instance = Object
            Object = Object:FindFirstChild("Subtext", true)
            Object = Object and Object:FindFirstChildWhichIsA("TextLabel")

            if Object then
                Object:GetPropertyChangedSignal("Text"):Wait()
                VapeEvents.MatchEnded:Fire(Object.Text:find("WON") and true or false, Results)
            end
        end
    end))
end)

local SendHook = {Hooks = {}}
do
    local OldSend

    local function Hook(...)
        local Args = table.pack(...)
        for _, v: any in SendHook.Hooks do
            if v[2](Args) then
                return
            end
        end

        return OldSend(unpack(Args, 1, Args.n))
    end

    function SendHook:DoHook()
        if not OldSend and next(self.Hooks) then
            OldSend = hookfunction(Redliner.Packet.Fire, function(...)
                return Hook(...)
            end)
        end
    end

    function SendHook:Add(Key, Handler, Priority: number?)
        table.insert(self.Hooks, {Key, Handler, Priority or 0})
        table.sort(self.Hooks, function(A, B)
            return A[3] < B[3]
        end)

        if not OldSend then
            if (os.clock() - StartTime) < 2 then
                task.defer(function()
                    task.delay(2, function()
                        self:DoHook()
                    end)
                end)
            else
                self:DoHook()
            end
        end
    end

    function SendHook:Remove(Key)
        for i: number, v: any in self.Hooks do
            if v[1] == Key then
                table.remove(self.Hooks, i)
                break
            end
        end

        if OldSend and not next(self.Hooks) then
            if restorefunction then
                restorefunction(Redliner.Packet.Fire)
            else
                hookfunction(Redliner.Packet.Fire, OldSend)
            end

            OldSend = nil
        end
    end
end

for _, v: string in {"Reach", "TriggerBot", "AntiFall", "Desync", "HitBoxes", "Invisible", "Jesus", "MouseTP", "Spider", "SpinBot", "Swim", "TargetStrafe", "AntiRagdoll", "Disabler", "StateSpoofer", "Parkour", "SafeWalk", "MurderMystery"} do
    vape:Remove(v)
end

Run(function()
	local Reach
	
	Reach = vape.Categories.Combat:CreateModule({
	    Name = "Reach",
	    Function = function(Callback: boolean)
	        if Callback then
	            SendHook:Add("Reach", function(Args)
	                local self = Args[1]
	                if self and rawget(self, "Name") == Redliner.AttackPacket then
	                    if typeof(Args[4]) == "string" then
	                        for _, Box: any in RedlineBoxes do
	                            if #CastHitbox(Box.data, CFrame.lookAlong(Entity.character.RootPart.Position + Vector3.new(0, 2, 0), Args[5])) > 0 then
	                                Args[4] = Box.boxtype
	                                break
	                            end
	                        end
	                    end
	                end
	            end, 2)
	        else
	            SendHook:Remove("Reach")
	        end
	    end,
	    Tooltip = "Extends attack reach by picking the best hitbox type. (RISKY)"
	})
end)

Run(function()
	local SilentAim
	local Target
	local Range
	local HitChance
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local Old
	
	local function Hook(...)
	    if debug.info(4, "s"):find("Gun") then
	        local Ent = Entity.EntityMouse({
	            Range = Range.Value,
	            Part = "RootPart",
	            Players = Target.Players.Enabled,
	            NPCs = Target.NPCs.Enabled
	        })
	
	        if Ent then
	            TargetInfo.Targets[Ent] = tick() + 1
	            return CFrame.lookAt(Camera.CFrame.Position, Ent.Head.Position).LookVector
	        end
	    end
	
	    return Old(...)
	end
	
	SilentAim = vape.Categories.Combat:CreateModule({
	    Name = "SilentAim",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = hookfunction(Redliner.ShootFunction, function(...)
	                return Hook(...)
	            end)
	
	            repeat
	                if CircleObject then
	                    CircleObject.Position = UserInputService:GetMouseLocation()
	                end
	
	                task.wait()
	            until not SilentAim.Enabled
	        else
	            if Old then
	                if restorefunction then
	                    restorefunction(Redliner.ShootFunction)
	                else
	                    hookfunction(Redliner.ShootFunction, Old)
	                end
	                Old = nil
	            end
	        end
	    end,
	    ExtraText = function()
	        return "Redliner"
	    end,
	    Tooltip = "Silently adjusts your aim towards the enemy"
	})
	Target = SilentAim:CreateTargets({Players = true})
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
	            CircleObject.Visible = SilentAim.Enabled
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
	local AntiParry
	local Animations: {[string]: boolean} = {
	    [ReplicatedStorage.Assets.Animations:FindFirstChild("3P_Parry", true).AnimationId] = true
	}
	
	AntiParry = vape.Categories.Blatant:CreateModule({
	    Name = "AntiParry",
	    Function = function(Callback: boolean)
	        if Callback then
	            SendHook:Add("AntiParry", function(Args)
	                local self = Args[1]
	                if self and rawget(self, "Name") == Redliner.AttackPacket and typeof(Args[5]) == "Vector3" then
	                    local Origin: CFrame = CFrame.lookAlong(Entity.character.RootPart.Position + Vector3.new(0, 2, 0), Args[5])
	                    for _, Box: any in RedlineBoxes do
	                        if Box.boxtype == Args[4] then
	                            local Results: {BasePart} = CastHitbox(Box.data, Origin)
	                            for _, Hit: BasePart in Results do
	                                local Character: Model? = Hit:FindFirstAncestorWhichIsA("Model")
	                                local Animator = Character and Character:FindFirstChild("Animator", true)
	
	                                if Animator and Animator:IsA("Animator") then
	                                    for _, Track: AnimationTrack in Animator:GetPlayingAnimationTracks() do
	                                        if Track.IsPlaying and Animations[Track.Animation.AnimationId] then
	                                            task.spawn(function()
	                                                SendNotification("AntiParry", "Parry found, blocking hit.", 1)
	                                            end)
	
	                                            return true
	                                        end
	                                    end
	                                end
	                            end
	
	                            break
	                        end
	                    end
	                end
	            end, 3)
	        else
	            SendHook:Remove("AntiParry")
	        end
	    end,
	    Tooltip = "Ignores all targets with the parrying animation"
	})
end)

Run(function()
	local AutoParry
	
	AutoParry = vape.Categories.Blatant:CreateModule({
	    Name = "AutoParry",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Cooldown: number = os.clock()
	
	            repeat
	                if Cooldown < os.clock() then
	                    local DoParry
	                    for Shooter: Model, v: any in next, GetIndicators() do
	                        if v.indicator_type == "surefire_bullet" then
	                            local LocalPosition: Vector3 = Camera.CFrame.Position
	                            local TargetPosition: Vector3 = (((Shooter:FindFirstChild("Head") and Shooter.Head.Position or Shooter.PrimaryPart and Shooter.PrimaryPart.Position or Shooter:GetPivot().Position) - LocalPosition) * Vector3.new(1, 0, 1)).Unit
	                            local Difference: number = 1 - (workspace.CurrentCamera.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit:Dot(TargetPosition)
	                            local TimeDifference: number = (v.expected_shot_time - os.clock())
	
	                            if math.abs(Difference) <= v.parry_range and TimeDifference < 0.2 and TimeDifference > 0 and v.indicator_ui.Visible then
	                                DoParry = true
	                            end
	                        elseif v.indicator_type == "timing_only" and Players.NumPlayers <= 2 then
	                            local TimeDifference: number = (v.expected_shot_time - os.clock())
	
	                            if TimeDifference < 0 and TimeDifference > -0.2 and v.indicator_ui.Visible then
	                                DoParry = true
	                            end
	                        end
	                    end
	
	                    if DoParry then
	                        Cooldown = os.clock() + 0.2
	
	                        task.spawn(function()
	                            Redliner.ActionFunction(Redliner[Redliner.ActionController], "PARRY").Pressed:Fire()
	                        end)
	                    end
	                end
	
	                task.wait(0.05)
	            until not AutoParry.Enabled
	        end
	    end,
	    Tooltip = "lol"
	})
end)

local Fly
local LongJump
Run(function()
    local Value
    local VerticalValue
    local Up, Down = 0, 0

    Fly = vape.Categories.Blatant:CreateModule({
        Name = "Fly",
        Function = function(Callback: boolean)
            if Callback then
                Fly:Clean(RunService.PreSimulation:Connect(function(Delta: number)
                    AddVelocity(Vector3.new(0, 3.5 + (Up + Down) * VerticalValue.Value, 0))
                end))

                Up, Down = 0, 0
                for _, v: string in {"InputBegan", "InputEnded"} do
                    Fly:Clean(UserInputService[v]:Connect(function(Input: InputObject)
                        if not UserInputService:GetFocusedTextBox() then
                            if Input.KeyCode == Enum.KeyCode.Space then
                                Up = v == "InputBegan" and 1 or 0
                            elseif Input.KeyCode == Enum.KeyCode.LeftAlt then
                                Down = v == "InputBegan" and -1 or 0
                            end
                        end
                    end))
                end
            end
        end,
        ExtraText = function()
            return "Redliner"
        end,
        Tooltip = "Makes you go zoom."
    })
    VerticalValue = Fly:CreateSlider({
        Name = "Vertical Speed",
        Min = 1,
        Max = 150,
        Default = 50,
        Suffix = function(Val: number)
            return Val == 1 and "stud" or "studs"
        end
    })
end)

Run(function()
	local HighJump
	local Value
	
	HighJump = vape.Categories.Blatant:CreateModule({
	    Name = "HighJump",
	    Function = function(Callback: boolean)
	        if Callback then
	            HighJump:Toggle()
	            AddVelocity(Vector3.new(0, Value.Value, 0))
	        end
	    end,
	    ExtraText = function()
	        return "Redliner"
	    end,
	    Tooltip = "Lets you jump higher"
	})
	Value = HighJump:CreateSlider({
	    Name = "Velocity",
	    Min = 1,
	    Max = 150,
	    Default = 50,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
end)

Run(function()
	local InfiniteDash
	
	InfiniteDash = vape.Categories.Blatant:CreateModule({
	    Name = "InfiniteDash",
	    Function = function(Callback: boolean)
	        if Callback then
	            if Redliner[Redliner.MoveController] and type(Redliner[Redliner.MoveController][Redliner.DashVariable]) == "number" and type(Redliner[Redliner.MoveController][Redliner.DashRecoverVariable]) == "number" then
	                InfiniteDash:Clean(RunService.PreSimulation:Connect(function()
	                    rawset(Redliner[Redliner.MoveController], Redliner.DashVariable, 3)
	                    rawset(Redliner[Redliner.MoveController], Redliner.DashRecoverVariable, 3)
	                end))
	            end
	        end
	    end,
	    Tooltip = "Allows you to dash infinitely."
	})
end)

Run(function()
	local Killaura
	local Targets
	local AttackRange
	local AngleSlider
	local AutoSwing
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Overlay: OverlapParams = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	Overlay.RespectCanCollide = false
	local Particles, Boxes = {}, {}
	local Animations: {[string]: boolean} = {
	    [ReplicatedStorage.Assets.Animations:FindFirstChild("3P_Parry", true).AnimationId] = true
	}
	
	local function GetTarget()
	    local SelfPosition: Vector3 = Entity.isAlive and Entity.character.RootPart.Position or Vector3.zero
	    local LocalFacing: Vector3 = Camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	    local Ent = Entity.EntityPosition({
	        Range = AttackRange.Value,
	        Part = "RootPart",
	        Players = Targets.Players.Enabled,
	        NPCs = Targets.NPCs.Enabled,
	        Priority = Targets.Priority.Value
	    })
	
	    if Ent then
	        local Delta: Vector3 = (Ent.RootPart.Position - SelfPosition)
	        local Angle: number = math.acos(LocalFacing:Dot((Delta * Vector3.new(1, 0, 1)).Unit))
	        if Angle > (math.rad(AngleSlider.Value) / 2) then
	            return
	        end
	
	        return Ent
	    end
	end
	
	local function ShouldAttack(Ent)
	    if Players.NumPlayers <= 2 then
	        for _, v: any in next, GetIndicators() do
	            if v.indicator_type == "surefire_bullet" or v.indicator_type == "timing_only" then
	                local TimeDifference: number = (v.expected_shot_time - os.clock())
	                if TimeDifference < 0.4 then
	                    return false
	                end
	            end
	        end
	    end
	
	    local Animator = Ent.Humanoid:FindFirstChildWhichIsA("Animator")
	    if Animator then
	        for _, Track: AnimationTrack in Animator:GetPlayingAnimationTracks() do
	            if Track.IsPlaying and Animations[Track.Animation.AnimationId] then
	                return false
	            end
	        end
	    end
	
	    local Origin: CFrame = CFrame.lookAt(Entity.character.RootPart.Position + Vector3.new(0, 2, 0), Ent.RootPart.Position)
	    for _, Box: any in RedlineBoxes do
	        if #CastHitbox(Box.data, Origin) > 0 then
	            return true
	        end
	    end
	
	    return false
	end
	
	Killaura = vape.Categories.Blatant:CreateModule({
	    Name = "Killaura",
	    Function = function(Callback: boolean)
	        if Callback then
	            SendHook:Add("Killaura", function(Args)
	                local self = Args[1]
	                if self and rawget(self, "Name") == Redliner.AttackPacket and typeof(Args[5]) == "Vector3" then
	                    local Ent = GetTarget()
	
	                    if Ent then
	                        local Origin: CFrame = CFrame.lookAt(Entity.character.RootPart.Position + Vector3.new(0, 2, 0), Ent.Hitbox.Position)
	                        for _, Box: any in RedlineBoxes do
	                            if #CastHitbox(Box.data, Origin) > 0 then
	                                Args[5] = Origin.LookVector
	                                break
	                            end
	                        end
	                    end
	                end
	            end, 1)
	
	            repeat
	                local Attacked = {}
	                if game.PlaceId ~= 94987506187454 then
	                    local Ent = GetTarget()
	
	                    if Ent and ShouldAttack(Ent) then
	                        table.insert(Attacked, {
	                            Entity = Ent,
	                            Check = BoxAttackColor
	                        })
	
	                        TargetInfo.Targets[Ent] = tick() + 1
	                        if AutoSwing.Enabled then
	                            task.spawn(function()
	                                Redliner.ActionFunction(Redliner[Redliner.ActionController], "MELEE").Pressed:Fire()
	                            end)
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
	
	                task.wait(0.016)
	            until not Killaura.Enabled
	        else
	            SendHook:Remove("Killaura")
	
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
	    Max = 40,
	    Default = 40,
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
	AutoSwing = Killaura:CreateToggle({
	    Name = "Auto Swing",
	    Default = true
	})
	Killaura:CreateToggle({
	    Name = "Show target",
	    Function = function(Callback: boolean)
	        BoxAttackColor.Object.Visible = Callback
	        if Callback then
	            for i: number = 1, 10 do
	                local Adornment: BoxHandleAdornment = Instance.new("BoxHandleAdornment")
	                Adornment.Adornee = nil
	                Adornment.AlwaysOnTop = true
	                Adornment.Size = Vector3.new(3, 5, 3)
	                Adornment.CFrame = CFrame.new(0, -0.5, 0)
	                Adornment.ZIndex = 0
	                Adornment.Parent = vape.gui
	                Boxes[i] = Adornment
	            end
	        else
	            for _, v: BoxHandleAdornment in Boxes do
	                v:Destroy()
	            end
	            table.clear(Boxes)
	        end
	    end
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
end)

Run(function()
	local AutoQueue
	
	AutoQueue = vape.Categories.Utility:CreateModule({
	    Name = "AutoQueue",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoQueue:Clean(VapeEvents.MatchEnded.Event:Connect(function(_, Results)
	                task.defer(function()
	                    firesignal(Results.Main.requeuebutton.Activated)
	                end)
	            end))
	        end
	    end,
	    Tooltip = "Automatically requeue after the match ends."
	})
end)

Run(function()
	local AutoToxic
	local GG
	local Toggles, Lists, Cloned, Presets = {}, {}, {}, {}
	
	local function SendMessage(Name: string, Object, Default: string)
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
	
	    Message = Message and Message:gsub("<obj>", Object or "") or ""
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
	            AutoToxic:Clean(VapeEvents.MatchEnded.Event:Connect(function(Won: boolean)
	                if GG.Enabled then
	                    if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	                        if TextChatService:CanUserChatAsync(LocalPlayer.UserId) then
	                            TextChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync("gg")
	                        else
	                            TextChatService.ChatInputBarConfiguration.TargetTextChannel:SendPresetAsync(Presets["Good game"])
	                        end
	                    else
	                        ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer("gg", "All")
	                    end
	                end
	
	                if Won then
	                    if Toggles.Win.Enabled then
	                        SendMessage("Win", nil, "yall garbage")
	                    end
	                end
	            end))
	        end
	    end,
	    Tooltip = "Says a message after a certain action"
	})
	GG = AutoToxic:CreateToggle({
	    Name = "AutoGG",
	    Default = true
	})
	for _, v: string in {"Win"} do
	    Cloned[v] = {}
	    Toggles[v] = AutoToxic:CreateToggle({
	        Name = `{v} `,
	        Function = function(Callback: boolean)
	            if Lists[v] then
	                Lists[v].Object.Visible = Callback
	            end
	        end
	    })
	    Lists[v] = AutoToxic:CreateTextList({
	        Name = v,
	        Darker = true,
	        Visible = false,
	        Function = function()
	            table.clear(Cloned[v])
	        end
	    })
	end
	
	pcall(function()
	    for _, Group: any in TextChatService:GetPresetsAsync().categoryGroups do
	        for _, Category: any in Group.categories do
	            for _, Message: any in Category.messages do
	                Presets[Message.value] = Message.presetId
	            end
	        end
	    end
	end)
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
	            HitSound:Clean(VapeEvents.Hit.Event:Connect(function()
	                if #Sounds > 0 then
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
	    Tooltip = "Custom hit sound"
	})
	Value = HitSound:CreateTextList({
	    Name = "Sounds",
	    Placeholder = "sound id (roblox or file path)",
	    Function = function(List: {string}?)
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
	            KillSound:Clean(VapeEvents.PlayerKill.Event:Connect(function()
	                if #Sounds > 0 then
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
	    Function = function(List: {string}?)
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