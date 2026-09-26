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

local Players: Players = cloneref(game:GetService("Players"))
local UserInputService: UserInputService = cloneref(game:GetService("UserInputService"))
local RunService: RunService = cloneref(game:GetService("RunService"))
local TweenService: TweenService = cloneref(game:GetService("TweenService"))
local Debris: Debris = cloneref(game:GetService("Debris"))

local Camera: Camera = workspace.CurrentCamera
local LocalPlayer: Player = Players.LocalPlayer

local vape = shared.vape
local Entity = vape.Libraries.entity
local Whitelist = vape.Libraries.whitelist
local PredictionLib = vape.Libraries.prediction
local TargetInfo = vape.Libraries.targetinfo
local SessionInfo = vape.Libraries.sessioninfo
local GetVapeAsset = vape.Libraries.getvapeasset
local DrawingActor = loadstring(DownloadFile("kingvape/libraries/drawing.lua"), "drawing")(...)
local function SendNotification(...)
    return vape:CreateNotification(...)
end

if not select(1, ...) and game.PlaceId == 5938036553 then
    if run_on_actor and getactors then
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

            for _, v: Instance in getactors() do
                if tostring(v) == "frontlines_client_actor" then
                    run_on_actor(v, ExecutionString)
                    return
                end
            end
            SendNotification("Vape", "Failed to find actor", 10, "alert")
        end)
    else
        vape.Load = function()
            SendNotification("Vape", "Missing actor functions.", 10, "alert")
        end
    end

    return
end

local Frontlines = {Functions = {}}

local function AddBlur(Parent: Instance)
    local Blur: ImageLabel = Instance.new("ImageLabel")
    Blur.Name = "Blur"
    Blur.Size = UDim2.new(1, 89, 1, 52)
    Blur.Position = UDim2.fromOffset(-48, -31)
    Blur.BackgroundTransparency = 1
    Blur.Image = GetVapeAsset("kingvape/assets/new/blur.png")
    Blur.ScaleType = Enum.ScaleType.Slice
    Blur.SliceCenter = Rect.new(52, 31, 261, 502)
    Blur.Parent = Parent
    return Blur
end

local function GetTeam(Ent)
    return Frontlines.Main.globals.cli_teams[Ent.Id]
end

local function GetKey(Id, Server)
    for Key: string, v: number in Frontlines.Main.enums[`{Server and "s" or "c"}_net_msg`] do
        if v == Id then
            return Key
        end
    end
end

local function HookEvent(Id: string, Handler)
    local Success, Result = pcall(function()
        local Func = Frontlines.Events[Frontlines.Main.exe_func_t[Id]]
        local Hook

        local function NewFunc(...)
            if Handler(...) then
                return
            end
            return Hook(...)
        end

        Hook = hookfunction(Func, function(...)
            return NewFunc(...)
        end)
        Frontlines.Functions[Func] = Hook
        return function()
            if not Frontlines.Functions[Func] then
                return
            end
            hookfunction(Func, Frontlines.Functions[Func])
            Frontlines.Functions[Func] = nil
        end
    end)

    if not Success then
        SendNotification("Vape", `Failed to hook ({Id})`, 10, "alert")
    end

    return type(Result) == "function" and Result or function() end
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

Run(function()
    repeat
        if not Frontlines.ShootFunction then
            local Garbage = getgc(true)
            for _, v: any in Garbage do
                if type(v) == "table" then
                    if rawget(v, "script") and v._G and v._G.append_exe_set then
                        Frontlines.Main = v._G
                    end
                elseif type(v) == "function" and islclosure(v) then
                    local Name: string = debug.info(v, "n")
                    if Name == "spawn_bullet" and debug.getinfo(v).nups > 11 then
                        Frontlines.ShootFunction = v
                        Frontlines.ShootRay = typeof(debug.getupvalue(v, 6)) == "RaycastParams" and debug.getupvalue(v, 6) or debug.getupvalue(v, 5)
                    elseif Name == "on_melee_hit" then
                        Frontlines.KnifeFunction = v
                    elseif Name == "spawn_throwable" then
                        Frontlines.SpawnThrowable = v
                        Frontlines.Throwables = debug.getupvalue(v, 1)
                    end
                end
            end
            table.clear(Garbage)
        end

        if not (Frontlines.ShootFunction and (game.PlaceId == 5938036553 or game.StarterGui:GetCore("ResetButtonCallback") == false)) then
            task.wait(1)
        else
            break
        end
    until vape.Loaded == nil
    if vape.Loaded == nil then
        return
    end
    Frontlines.Events = debug.getupvalue(Frontlines.Main.append_exe_set, 1)
    Frontlines.PickupBit = debug.getupvalue(Frontlines.Events[Frontlines.Main.exe_func_t.INIT_FPV_SOL_AMMO_PICKUP], 5)

    local Kills = SessionInfo:AddItem("Kills")
    local Deaths = SessionInfo:AddItem("Deaths")

    HookEvent("SET_CLI_MATCH_KILLS", function(Id)
        if Id == Frontlines.Main.globals.cli_state.fpv_sol_id then
            Kills:Increment()
        end
    end)

    HookEvent("PLAY_FPV_SOL_DEATH_SOUND", function(self, Id)
        if Id == Frontlines.Main.globals.cli_state.fpv_sol_id then
            Deaths:Increment()
        end
    end)

    HookEvent("SET_GBL_SOL_HEALTH", function(Id, Health: number)
        local Target = Entity.getEntity(Id)
        if Target then
            Target.Health = Health
            Entity.Events.EntityUpdated:Fire(Target)
        end
    end)

    HookEvent("INIT_SOLDIER_MODEL", function(Id)
        Entity.refreshEntity(Frontlines.Main.globals.soldier_models[Id], Id)
    end)

    HookEvent("DEINIT_SOL_STATE", function(Id)
        Entity.refreshEntity(Frontlines.Main.globals.soldier_models[Id], Id)
    end)

    HookEvent("SET_CLI_TEAM", function(Id)
        task.defer(function()
            Entity.refreshEntity(Frontlines.Main.globals.soldier_models[Id], Id)
        end)
    end)

    vape:Clean(Drawing.kill or function() end)
    vape:Clean(function()
        for Func: (...any) -> ...any, v: (...any) -> ...any in Frontlines.Functions do
            hookfunction(Func, v)
        end
        table.clear(Frontlines.Functions)
        table.clear(Frontlines)
    end)
end)
if vape.Loaded == nil then
    return
end

Run(function()
    Entity.Wallcheck = function(Origin: Vector3, Position: Vector3, IgnoreObject)
        local RayResult: RaycastResult? = workspace.Raycast(workspace, Origin, (Position - Origin), Frontlines.ShootRay)
        return RayResult and RayResult.Instance and (RayResult.Instance == workspace.Terrain or RayResult.Instance:IsDescendantOf(workspace.workspace)) or false
    end

    Entity.targetCheck = function(Ent)
        if Ent.Player then
            if IsFriend(Ent.Player) then
                return false
            end
            if not select(2, Whitelist:get(Ent.Player)) then
                return false
            end
        end

        return GetTeam({Id = Frontlines.Main.globals.cli_state.id}) ~= GetTeam(Ent)
    end

    Entity.getEntityColor = function(Ent)
        if not (Ent.Player and vape.Settings.Modules.Options["Use team color"].Enabled) then
            return
        end
        if IsFriend(Ent.Player, true) then
            return Color3.fromHSV(vape.Categories.Friends.Options["Friends color"].Hue, vape.Categories.Friends.Options["Friends color"].Sat, vape.Categories.Friends.Options["Friends color"].Value)
        end
        return GetTeam({Id = Frontlines.Main.globals.cli_state.id}) == GetTeam(Ent) and Color3.fromRGB(67, 140, 229) or Color3.fromRGB(234, 50, 50)
    end

    Entity.getEntity = function(Character)
        for i: number, v: any in Entity.List do
            if v.Id == Character then
                return v, i
            end
        end
    end

    Entity.addEntity = function(Character, Id, TeamFunc)
        if not Character then
            return
        end
        Entity.EntityThreads[Character] = task.spawn(function()
            local Player: Player?
            if game.PlaceId == 5938036553 then
                Player = Players:FindFirstChild(Frontlines.Main.globals.cli_names[Id])
            else
                Player = Players:GetPlayerByUserId(Frontlines.Main.globals.cli_user_ids[Id] or -1)
            end

            if not Id or not Frontlines.Main.globals.soldiers_alive[Id] then
                Entity.EntityThreads[Character] = nil
                return
            end

            local Humanoid = {
                HipHeight = 2,
                MoveDirection = Vector3.zero,
                Health = 100,
                MaxHealth = 100,
                GetState = function()
                    return Enum.HumanoidStateType.Running
                end
            }

            if Player == LocalPlayer then
                repeat
                    Humanoid = Frontlines.Main.globals.fpv_sol_instances.humanoid
                    task.wait()
                until Humanoid or not Frontlines.Main
                if not Frontlines.Main then
                    Entity.EntityThreads[Character] = nil
                    return
                end
            end

            local HumanoidRootPart: BasePart? = Character:WaitForChild("HumanoidRootPart", 10)
            local Head = HumanoidRootPart and setmetatable({Name = "Head", Size = Vector3.one, Parent = Character}, {__index = function(Table, Key: string)
                if Key == "Position" then
                    return HumanoidRootPart.Position + Vector3.new(0, 3, 0)
                elseif Key == "CFrame" then
                    return HumanoidRootPart.CFrame + Vector3.new(0, 3, 0)
                end
            end})

            if Humanoid and HumanoidRootPart then
                local Target = {
                    Connections = {},
                    Character = Character,
                    Health = Humanoid.Health,
                    Head = Head,
                    Humanoid = Humanoid,
                    HumanoidRootPart = HumanoidRootPart,
                    HipHeight = Humanoid.HipHeight + (HumanoidRootPart.Size.Y / 2) + (Humanoid.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
                    Id = Id,
                    MaxHealth = Humanoid.MaxHealth,
                    NPC = Player == nil,
                    Player = Player,
                    RootPart = HumanoidRootPart,
                    TeamCheck = TeamFunc
                }

                if Player == LocalPlayer then
                    Entity.character = Target
                    Entity.isAlive = true
                    Entity.Events.LocalAdded:Fire(Target)
                else
                    Target.Targetable = Entity.targetCheck(Target)
                    table.insert(Entity.List, Target)
                    Entity.Events.EntityAdded:Fire(Target)
                end
            end

            Entity.EntityThreads[Character] = nil
        end)
    end

    Entity.refreshEntity = function(Character, Id)
        Entity.removeEntity(Id)
        Entity.addEntity(Character, Id)
    end

    Entity.refresh = function()
        local Cloned = table.clone(Entity.List)
        for _, v: any in Cloned do
            Entity.refreshEntity(v.Character, v.Id)
        end
        table.clear(Cloned)
    end

    Entity.start = function()
        if Entity.Running then
            Entity.stop()
        end

        for Id: any, Actor: any in Frontlines.Main.soldier_actors do
            if Actor.main.model.Value then
                Entity.refreshEntity(Actor.main.model.Value, Id)
            end
        end

        table.insert(Entity.Connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            Camera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA("Camera")
        end))

        Entity.Running = true
    end
end)
Entity.start()

for _, v: string in {"Reach", "Health", "TriggerBot", "AntiFall", "AntiRagdoll", "Invisible", "Disabler", "Freecam", "Parkour", "HitBoxes", "SafeWalk", "Spider", "Swim", "GamingChair", "TargetStrafe", "Timer", "MurderMystery", "Blink", "AnimationPlayer"} do
    vape:Remove(v)
end

Run(function()
	local AimAssist
	local FOV
	local Speed
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local RayCheck: RaycastParams = RaycastParams.new()
	RayCheck.RespectCanCollide = true
	
	AimAssist = vape.Categories.Combat:CreateModule({
	    Name = "AimAssist",
	    Function = function(Callback: boolean)
	        if CircleObject then
	            CircleObject.Visible = Callback
	        end
	        if Callback then
	            repeat
	                local Delta: number = task.wait()
	                if not AimAssist.Enabled then
	                    break
	                end
	                if CircleObject then
	                    CircleObject.Position = UserInputService:GetMouseLocation()
	                end
	
	                if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
	                    local Origin: Vector3 = Entity.isAlive and Frontlines.Main.globals.fpv_sol_instances.camera_bone.WorldPosition or Vector3.zero
	                    local Ent = Entity.EntityMouse({
	                        Range = FOV.Value,
	                        Players = true,
	                        Wallcheck = true,
	                        Part = "RootPart",
	                        Origin = Origin
	                    })
	
	                    if Ent then
	                        local Gun = Frontlines.Main.globals.fpv_sol_equipment.curr_equipment
	                        if Gun and Gun.fire_params then
	                            RayCheck.FilterDescendantsInstances = {Camera, Ent.Character}
	                            RayCheck.CollisionGroup = Ent.RootPart.CollisionGroup
	                            local Velocity: number = Gun.fire_params.muzzle_velocity
	                            local TargetPosition: Vector3 = Ent.RootPart.Root_M.Spine1_M.Spine2_M.Chest_M.Neck_M.Head_M.WorldCFrame.Position
	                            local Calculated = PredictionLib.SolveTrajectory(Origin, Velocity, workspace.Gravity, TargetPosition, Vector3.zero, workspace.Gravity, Ent.HipHeight, nil, RayCheck)
	
	                            if Calculated then
	                                local ScreenPosition: Vector3 = Camera:WorldToViewportPoint(Calculated)
	                                local LocalMouse: Vector2 = (UserInputService:GetMouseLocation() - Vector2.new(ScreenPosition.X, ScreenPosition.Y)) * Delta * (Speed.Value / 10000)
	                                TargetInfo.Targets[Ent] = tick() + 1
	                                Frontlines.Main.exe_set(Frontlines.Main.exe_set_t.CTRL_SOL_ATT_ROT, LocalMouse.Y, LocalMouse.X)
	                            end
	                        end
	                    end
	                end
	            until not AimAssist.Enabled
	        end
	    end,
	    Tooltip = "Uses game functions to move the camera towards players"
	})
	FOV = AimAssist:CreateSlider({
	    Name = "FOV",
	    Min = 1,
	    Max = 1000,
	    Default = 300,
	    Function = function(Val: number)
	        if CircleObject then
	            CircleObject.Radius = Val
	        end
	    end
	})
	Speed = AimAssist:CreateSlider({
	    Name = "Speed",
	    Min = 1,
	    Max = 100,
	    Default = 10
	})
	AimAssist:CreateToggle({
	    Name = "Range Circle",
	    Function = function(Callback: boolean)
	        if Callback then
	            CircleObject = Drawing.new("Circle")
	            CircleObject.Filled = CircleFilled.Enabled
	            CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
	            CircleObject.Position = vape.gui.AbsoluteSize / 2
	            CircleObject.Radius = FOV.Value
	            CircleObject.NumSides = 100
	            CircleObject.Transparency = 1 - CircleTransparency.Value
	            CircleObject.Visible = AimAssist.Enabled
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
	CircleColor = AimAssist:CreateColorSlider({
	    Name = "Circle Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        if CircleObject then
	            CircleObject.Color = Color3.fromHSV(Hue, Sat, Val)
	        end
	    end,
	    Darker = true,
	    Visible = false
	})
	CircleTransparency = AimAssist:CreateSlider({
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
	CircleFilled = AimAssist:CreateToggle({
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
	local SilentAim
	local Target
	local Mode
	local Range
	local HitChance
	local HeadshotChance
	local AutoFire
	local Wallbang
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local ProjectileRaycast: RaycastParams = RaycastParams.new()
	ProjectileRaycast.RespectCanCollide = true
	local RandomGenerator, Old = Random.new()
	
	local function GetTarget(Origin: Vector3, Object)
	    if RandomGenerator.NextNumber(RandomGenerator, 0, 100) > (AutoFire.Enabled and 100 or HitChance.Value) then
	        return
	    end
	    local TargetPart: string = "RootPart"
	    local Ent = Entity[`Entity{Mode.Value}`]({
	        Range = Range.Value,
	        Wallcheck = Target.Walls.Enabled and (Object or true) or nil,
	        Part = TargetPart,
	        Origin = Origin,
	        Players = Target.Players.Enabled,
	        NPCs = Target.NPCs.Enabled
	    })
	    if Ent then
	        TargetInfo.Targets[Ent] = tick() + 1
	    end
	    return Ent, Ent and Ent[TargetPart]
	end
	
	local function RaycastLoop(Origin: Vector3, Position: Vector3)
	    local Returned
	    local Real = Origin
	    for _ = 1, 20 do
	        local RayResult: RaycastResult? = workspace:Raycast(Origin, (Position - Origin), Frontlines.ShootRay)
	        if RayResult and not RayResult.Instance:HasTag("SOLDIER") then
	            Returned = RayResult.Position - RayResult.Normal * 0.1
	            Origin = Returned
	        else
	            break
	        end
	    end
	    return Returned
	end
	
	SilentAim = vape.Categories.Combat:CreateModule({
	    Name = "SilentAim",
	    Function = function(Callback: boolean)
	        if CircleObject then
	            CircleObject.Visible = Callback and Mode.Value == "Mouse"
	        end
	
	        if Callback then
	            Old = hookfunction(Frontlines.ShootFunction, function(ShootId: number, Fire, Position: Vector3, Direction: Vector3, ...)
	                if not Frontlines.Main then
	                    return
	                end
	
	                local ClientState = Frontlines.Main.globals.cli_state
	                if ClientState.state == Frontlines.Main.cli_state_t.COMBAT and (ShootId % Frontlines.Main.globals.cli_id_alloc.m) == ClientState.id then
	                    local Ent, TargetPart = GetTarget(Position)
	                    if Ent then
	                        local Velocity: number = Direction.Magnitude
	                        local TargetPosition: Vector3 = TargetPart.Root_M.Spine1_M.WorldCFrame.Position
	                        ProjectileRaycast.FilterDescendantsInstances = {Camera, Ent.Character}
	                        ProjectileRaycast.CollisionGroup = TargetPart.CollisionGroup
	
	                        if Wallbang.Enabled then
	                            local Wall = RaycastLoop(Position, TargetPosition)
	                            if Wall and (Position - Wall).Magnitude < 8 then
	                                Position = Wall
	                            end
	                        end
	
	                        local Calculated = PredictionLib.SolveTrajectory(Position, Velocity, workspace.Gravity, TargetPosition, Vector3.zero, workspace.Gravity, Ent.HipHeight, nil, ProjectileRaycast)
	                        if Calculated then
	                            Direction = -CFrame.new(Position, Calculated).ZVector * Velocity
	                        end
	                    end
	                end
	
	                return Old(ShootId, Fire, Position, Direction, ...)
	            end)
	
	            local OldEnt
	            repeat
	                if CircleObject then
	                    CircleObject.Position = UserInputService:GetMouseLocation()
	                end
	
	                if AutoFire.Enabled then
	                    local Ent = Entity[`Entity{Mode.Value}`]({
	                        Range = Range.Value,
	                        Wallcheck = Target.Walls.Enabled or nil,
	                        Part = "RootPart",
	                        Origin = Entity.isAlive and Frontlines.Main.globals.fpv_sol_instances.camera_bone.WorldPosition or Vector3.zero,
	                        Players = Target.Players.Enabled,
	                        NPCs = Target.NPCs.Enabled
	                    })
	
	                    local Gun = Frontlines.Main.globals.fpv_sol_equipment.curr_equipment
	                    Ent = Gun and Gun.type ~= 2 and Ent or nil
	                    if Ent ~= OldEnt or Ent then
	                        Frontlines.Main.globals.ctrl_states.trigger = Ent and true or false
	                        if Ent then
	                            Frontlines.Main.globals.ctrl_ts.trigger = time()
	                        end
	                        OldEnt = Ent
	                    end
	                end
	
	                task.wait()
	            until not SilentAim.Enabled
	        else
	            if Old then
	                hookfunction(Frontlines.ShootFunction, Old)
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Silently adjusts your aim towards the enemy"
	})
	Target = SilentAim:CreateTargets({Players = true})
	Mode = SilentAim:CreateDropdown({
	    Name = "Mode",
	    List = {"Mouse", "Position"},
	    Function = function(Val: string)
	        if CircleObject then
	            CircleObject.Visible = SilentAim.Enabled and Val == "Mouse"
	        end
	    end
	})
	Range = SilentAim:CreateSlider({
	    Name = "Range",
	    Min = 1,
	    Max = 1000,
	    Default = 150,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end,
	    Function = function(Val: number)
	        if CircleObject then
	            CircleObject.Radius = Val
	        end
	    end
	})
	HitChance = SilentAim:CreateSlider({
	    Name = "Hit Chance",
	    Min = 0,
	    Max = 100,
	    Default = 85,
	    Suffix = "%"
	})
	AutoFire = SilentAim:CreateToggle({Name = "AutoFire"})
	Wallbang = SilentAim:CreateToggle({Name = "Wallbang"})
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
	local Sprint
	
	Sprint = vape.Categories.Combat:CreateModule({
	    Name = "Sprint",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local States = Frontlines.Main.globals.ctrl_states
	                local StateTimes = Frontlines.Main.globals.ctrl_ts
	                local SprintCheck: boolean = true
	
	                if not (States.hold_ads or (time() - StateTimes.trigger) < 0.2 or (time() - StateTimes.press_crouch) < 0.4) then
	                    if not States.hold_accel then
	                        StateTimes.press_accel_prev = time()
	                        StateTimes.press_accel = time()
	                    end
	                    States.hold_accel = true
	                end
	                task.wait(0.1)
	            until not Sprint.Enabled
	        end
	    end,
	    Tooltip = "Holds the sprint button"
	})
end)

Run(function()
	local GrenadeTP
	local Range
	
	GrenadeTP = vape.Categories.Blatant:CreateModule({
	    Name = "GrenadeTP",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                for _, v: any in Frontlines.Throwables do
	                    if v.model and v.network_ownership then
	                        local Ent = Entity.EntityPosition({
	                            Range = Range.Value,
	                            Part = "RootPart",
	                            Origin = v.model.PrimaryPart.Position,
	                            Players = true
	                        })
	
	                        if Ent then
	                            local Id
	                            for Hitbox: Instance, Hash: any in Frontlines.Main.globals.soldier_hitbox_hash do
	                                if Hitbox.Weld.Part0 == Ent.RootPart then
	                                    Id = Hash
	                                    break
	                                end
	                            end
	
	                            if Id then
	                                v.model:PivotTo(Ent.RootPart.Root_M.Spine1_M.WorldCFrame)
	                            end
	                        end
	                    end
	                end
	                task.wait(0.016)
	            until not GrenadeTP.Enabled
	        end
	    end,
	    Tooltip = "Teleports throwables near enemy players"
	})
	Range = GrenadeTP:CreateSlider({
	    Name = "Range",
	    Min = 1,
	    Max = 1000,
	    Default = 1000
	})
end)

Run(function()
	local GunModifications
	local Reload
	local Recoil
	local Spread
	local FireRate
	local Automatic
	
	GunModifications = vape.Categories.Blatant:CreateModule({
	    Name = "GunModifications",
	    Function = function(Callback: boolean)
	        if Callback then
	            GunModifications:Clean(HookEvent("START_FPV_SOL_RECOIL_ANIM", function()
	                if Recoil.Enabled then
	                    Frontlines.Main.globals.fpv_sol_recoil.attitude_delta = Vector3.zero
	                    return true
	                end
	            end))
	
	            GunModifications:Clean(HookEvent("STEP_FPV_SOL_FIREARM_SPREAD", function()
	                if Spread.Enabled then
	                    Frontlines.Main.globals.fpv_sol_spread.spread = 0
	                    return true
	                end
	            end))
	
	            repeat
	                local Gun = Frontlines.Main.globals.fpv_sol_equipment.curr_equipment
	                if Reload.Enabled then
	                    local Ammo = Frontlines.Main.globals.fpv_sol_ammo
	                    if Gun and Gun.reload_params and Ammo.ammo == 0 and Ammo.reserve > 0 then
	                        Frontlines.Main.exe_set(Frontlines.Main.exe_set_t.FPV_SOL_AMMO_IN, Gun)
	                    end
	                end
	
	                if FireRate.Enabled then
	                    if Gun and Gun.fire_params then
	                        Gun.fire_params.rpm = 4000
	                    end
	                end
	
	                if Automatic.Enabled then
	                    if Gun and Gun.fire_params then
	                        Gun.fire_params.cycle_mode = Frontlines.Main.cycle_mode.AUTO
	                    end
	                end
	
	                task.wait()
	            until not GunModifications.Enabled
	        end
	    end,
	    Tooltip = "Modifications to empower the firearm"
	})
	Reload = GunModifications:CreateToggle({Name = "Auto Reload"})
	Recoil = GunModifications:CreateToggle({Name = "No Recoil"})
	Spread = GunModifications:CreateToggle({Name = "No Spread"})
	FireRate = GunModifications:CreateToggle({Name = "Fire rate"})
	Automatic = GunModifications:CreateToggle({Name = "Full Automatic"})
end)

Run(function()
	local Killaura
	local Targets
	local SwingRange
	local AttackRange
	local Angle
	local Max
	local Mouse
	local Limit
	local Box
	local BoxSwingColor
	local BoxAttackColor
	local Particle
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Boxes = {}
	local Particles = {}
	local HitDelay: number = tick()
	local DidAttack: boolean = false
	
	local function GetAttackData()
	    if Mouse.Enabled then
	        if not UserInputService:IsMouseButtonPressed(0) then
	            return false
	        end
	    end
	
	    local Gun = Frontlines.Main.globals.fpv_sol_equipment.curr_equipment
	    local KnifeCheck: boolean = Gun and Gun.type == 2 and true or false
	    if Limit.Enabled then
	        if not KnifeCheck then
	            return false
	        end
	    end
	
	    return true, KnifeCheck
	end
	
	Killaura = vape.Categories.Blatant:CreateModule({
	    Name = "Killaura",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local Success, KnifeCheck = GetAttackData()
	                local Attacked = {}
	                local PreviousAttack = DidAttack
	                DidAttack = false
	                if Success then
	                    local Entities = Entity.AllPosition({
	                        Range = SwingRange.Value,
	                        Wallcheck = Targets.Walls.Enabled or nil,
	                        Part = "RootPart",
	                        Players = Targets.Players.Enabled,
	                        NPCs = Targets.NPCs.Enabled,
	                        Priority = Targets.Priority.Value,
	                        Limit = Max.Value
	                    })
	
	                    if #Entities > 0 then
	                        local Gun = Frontlines.Main.globals.fpv_sol_equipment.curr_equipment
	                        local LocalFacing: Vector3 = Entity.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	
	                        for _, v: any in Entities do
	                            local Delta: Vector3 = (v.RootPart.Position - Entity.character.RootPart.Position)
	                            local EntityAngle: number = math.acos(LocalFacing:Dot((Delta * Vector3.new(1, 0, 1)).Unit))
	                            if EntityAngle > (math.rad(Angle.Value) / 2) then
	                                continue
	                            end
	                            table.insert(Attacked, {Entity = v, Check = Delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor})
	                            TargetInfo.Targets[v] = tick() + 1
	
	                            if Delta.Magnitude > AttackRange.Value then
	                                continue
	                            end
	                            DidAttack = KnifeCheck
	                            if HitDelay < tick() then
	                                local Id, Part
	                                for Hitbox: Instance, HitboxId: any in Frontlines.Main.globals.soldier_hitbox_hash do
	                                    if Hitbox.Weld.Part0 == v.RootPart then
	                                        Id, Part = HitboxId, Hitbox
	                                        break
	                                    end
	                                end
	
	                                if Id then
	                                    HitDelay = tick() + 0.1
	                                    Frontlines.Main.utils.net_msg_util.c_prep_net_msg(Frontlines.Main.globals.combat_net_msg_state, Frontlines.Main.enums.c_net_msg.MELEE_HIT_SOL, Id)
	                                    if KnifeCheck then
	                                        Frontlines.Main.globals.ctrl_states.trigger = true
	                                        Frontlines.Main.globals.ctrl_ts.trigger = time()
	                                        Frontlines.Main.exe_set(Frontlines.Main.exe_set_t.FPV_SOL_MELEE_SOL_HIT, Gun, Part, Vector3.zero)
	                                        if vape.ThreadFix then
	                                            setthreadidentity(8)
	                                        end
	                                    end
	                                end
	                            end
	                        end
	                    end
	                end
	
	                if DidAttack ~= PreviousAttack and PreviousAttack then
	                    Frontlines.Main.globals.ctrl_states.trigger = false
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
	
	                task.wait()
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
	SwingRange = Killaura:CreateSlider({
	    Name = "Swing range",
	    Min = 1,
	    Max = 8,
	    Default = 8,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	AttackRange = Killaura:CreateSlider({
	    Name = "Attack range",
	    Min = 1,
	    Max = 8,
	    Default = 8,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	Angle = Killaura:CreateSlider({
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
	Limit = Killaura:CreateToggle({Name = "Knife only"})
	Box = Killaura:CreateToggle({
	    Name = "Show target",
	    Function = function(Callback: boolean)
	        BoxSwingColor.Object.Visible = Callback
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
	BoxSwingColor = Killaura:CreateColorSlider({
	    Name = "Target Color",
	    Darker = true,
	    Visible = false,
	    DefaultHue = 0.6,
	    DefaultOpacity = 0.5
	})
	BoxAttackColor = Killaura:CreateColorSlider({
	    Name = "Attack Color",
	    Darker = true,
	    Visible = false,
	    DefaultOpacity = 0.5
	})
	Particle = Killaura:CreateToggle({
	    Name = "Target particles",
	    Function = function(Callback: boolean)
	        ParticleTexture.Object.Visible = Callback
	        ParticleColor1.Object.Visible = Callback
	        ParticleColor2.Object.Visible = Callback
	        ParticleSize.Object.Visible = Callback
	        if Callback then
	            for i: number = 1, 10 do
	                local Part: Part = Instance.new("Part")
	                Part.Size = Vector3.one
	                Part.Anchored = true
	                Part.CanCollide = false
	                Part.Transparency = 1
	                Part.CanQuery = false
	                Part.Parent = Killaura.Enabled and Camera or nil
	                local Emitter: ParticleEmitter = Instance.new("ParticleEmitter")
	                Emitter.Brightness = 1.5
	                Emitter.Size = NumberSequence.new(ParticleSize.Value)
	                Emitter.Texture = ParticleTexture.Value
	                Emitter.Transparency = NumberSequence.new(0, 1)
	                Emitter.Lifetime = NumberRange.new(0.4)
	                Emitter.Rate = 1000
	                Emitter.Speed = NumberRange.new(12)
	                Emitter.Drag = 6
	                Emitter.Shape = Enum.ParticleEmitterShape.Sphere
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
	    Function = function(Val: string)
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
	    Default = 0.25,
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
	local Phase
	
	Phase = vape.Categories.Blatant:CreateModule({
	    Name = "Phase",
	    Function = function(Callback: boolean)
	        if Callback then
	            Phase:Clean(Entity.Events.LocalAdded:Connect(function()
	                local Root = Frontlines.Main.globals.fpv_sol_instances.root
	                if Root then
	                    Root.CanCollide = false
	                end
	            end))
	
	            local Root = Frontlines.Main.globals.fpv_sol_instances.root
	            if Root then
	                Root.CanCollide = false
	            end
	        else
	            local Root = Frontlines.Main.globals.fpv_sol_instances.root
	            if Root then
	                Root.CanCollide = true
	            end
	        end
	    end,
	    Tooltip = "Lets you Phase/Clip through walls."
	})
end)

Run(function()
	local SpinBot
	local Speed
	local Yaw
	local Pitch
	local AimTable = {}
	local MaxY: number = Frontlines.Main.consts.fpv_sol_movement.MAX_ATT_X
	local YawAngle, PitchAngle = 0, 90
	for _ = 1, 40 do
	    table.insert(AimTable, Vector3.zero)
	end
	
	SpinBot = vape.Categories.Blatant:CreateModule({
	    Name = "SpinBot",
	    Function = function(Callback: boolean)
	        if Callback then
	            SpinBot:Clean(HookEvent("STEP_SOL_CFRAME", function(Id)
	                if Id == Frontlines.Main.globals.cli_state.fpv_sol_id then
	                    local SoldierPosition = Frontlines.Main.globals.sol_positions[Id]
	                    local Attitude = AimTable[Frontlines.Main.globals.cli_state.fpv_sol_id]
	                    Frontlines.Main.globals.sol_root_parts[Id].Root_M.CFrame = CFrame.Angles(0, 0.5 * Attitude.y, math.rad(-90))
	                end
	            end))
	
	            debug.setupvalue(Frontlines.Events[Frontlines.Main.exe_func_t.STEP_FPV_SOL_NET_EGRESS], 3, AimTable)
	            debug.setupvalue(Frontlines.Events[Frontlines.Main.exe_func_t.STEP_TPV_SOLDIER_JOINTS], 16, AimTable)
	
	            repeat
	                for i: number, Attitude: any in Frontlines.Main.globals.sol_attitudes do
	                    AimTable[i] = Attitude
	                end
	                AimTable[Frontlines.Main.globals.cli_state.fpv_sol_id] = Vector3.new(math.clamp(math.rad(PitchAngle), -MaxY, MaxY), math.rad(YawAngle))
	                YawAngle += task.wait() * (Yaw.Value == "Clockwise" and (Speed.Value or 0) or -(Speed.Value or 0)) * 1000
	                if Pitch.Value == "Sine" then
	                    PitchAngle = math.sin(math.rad(YawAngle)) * 90
	                end
	            until not SpinBot.Enabled
	        else
	            YawAngle = 0
	            debug.setupvalue(Frontlines.Events[Frontlines.Main.exe_func_t.STEP_FPV_SOL_NET_EGRESS], 3, Frontlines.Main.globals.sol_attitudes)
	            debug.setupvalue(Frontlines.Events[Frontlines.Main.exe_func_t.STEP_TPV_SOLDIER_JOINTS], 16, Frontlines.Main.globals.sol_attitudes)
	            local Id = Frontlines.Main.globals.cli_state.fpv_sol_id
	            if Frontlines.Main.globals.sol_root_parts[Id] then
	                Frontlines.Main.globals.sol_root_parts[Id].Root_M.CFrame = CFrame.Angles(0, math.rad(90), math.rad(-90))
	            end
	        end
	    end,
	    Tooltip = "Rotates the character in a circle"
	})
	Speed = SpinBot:CreateSlider({
	    Name = "Speed",
	    Min = 0,
	    Max = 1,
	    Default = 1,
	    Decimal = 10
	})
	Yaw = SpinBot:CreateDropdown({
	    Name = "Yaw Direction",
	    List = {"Clockwise", "Counter Clockwise"}
	})
	Pitch = SpinBot:CreateDropdown({
	    Name = "Pitch Direction",
	    List = {"Up", "Down", "Forward", "Sine"},
	    Function = function(Val: string)
	        PitchAngle = Val == "Up" and 90 or Val == "Down" and -90 or 0
	    end
	})
end)

Run(function()
	local GrenadeESP
	local Background
	local Color = {}
	local Reference = {}
	local Folder: Folder = Instance.new("Folder")
	Folder.Parent = vape.gui
	local Old
	
	local function AddESP(Throwable)
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	    if not Throwable.model or Throwable.model.Name ~= "frag" then
	        return
	    end
	    local Billboard: BillboardGui = Instance.new("BillboardGui")
	    Billboard.Parent = Folder
	    Billboard.Name = Throwable.model.Name
	    Billboard.Size = UDim2.fromOffset(32, 32)
	    Billboard.AlwaysOnTop = true
	    Billboard.ClipsDescendants = false
	    Billboard.Adornee = Throwable.model.PrimaryPart
	    local Blur: ImageLabel = AddBlur(Billboard)
	    Blur.Visible = Background.Enabled
	    local Image: ImageLabel = Instance.new("ImageLabel")
	    Image.Size = UDim2.fromScale(1, 1)
	    Image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	    Image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
	    Image.BorderSizePixel = 0
	    Image.Image = "rbxassetid://12660993553"
	    Image.Parent = Billboard
	    local Corner: UICorner = Instance.new("UICorner")
	    Corner.CornerRadius = UDim.new(0, 4)
	    Corner.Parent = Image
	    Reference[Throwable.model] = Billboard
	    Throwable.model.Destroying:Connect(function()
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	        if Reference[Throwable.model] then
	            Reference[Throwable.model]:Destroy()
	            Reference[Throwable.model] = nil
	        end
	    end)
	end
	
	GrenadeESP = vape.Categories.Render:CreateModule({
	    Name = "GrenadeESP",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = hookfunction(Frontlines.SpawnThrowable, function(Id, Position, Velocity)
	                local Result = Old(Id, Position, Velocity)
	                AddESP(Frontlines.Throwables[Id])
	                return Result
	            end)
	        else
	            hookfunction(Frontlines.SpawnThrowable, Old)
	            Folder:ClearAllChildren()
	            table.clear(Reference)
	        end
	    end,
	    Tooltip = "ESP for grenades"
	})
	Background = GrenadeESP:CreateToggle({
	    Name = "Background",
	    Function = function(Callback: boolean)
	        if Color.Object then
	            Color.Object.Visible = Callback
	        end
	        for _, v: BillboardGui in Reference do
	            v.ImageLabel.BackgroundTransparency = 1 - (Callback and Color.Opacity or 0)
	            v.Blur.Visible = Callback
	        end
	    end,
	    Default = true
	})
	Color = GrenadeESP:CreateColorSlider({
	    Name = "Background Color",
	    DefaultValue = 0,
	    DefaultOpacity = 0.5,
	    Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
	        for _, v: BillboardGui in Reference do
	            v.ImageLabel.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
	            v.ImageLabel.BackgroundTransparency = 1 - Opacity
	        end
	    end,
	    Darker = true
	})
end)

Run(function()
	local NoHurtCam
	
	NoHurtCam = vape.Categories.Render:CreateModule({
	    Name = "NoHurtCam",
	    Function = function(Callback: boolean)
	        if Callback then
	            NoHurtCam:Clean(HookEvent("UPDATE_FPV_SOL_DAMAGE_GFX", function()
	                return true
	            end))
	            NoHurtCam:Clean(HookEvent("UPDATE_FPV_SOL_HEALTH_SFX", function()
	                return true
	            end))
	            NoHurtCam:Clean(HookEvent("DISPLAY_SUPPRESSION_VIGNETTE", function()
	                return true
	            end))
	        end
	    end,
	    Tooltip = "Removes camera flash after taking damage"
	})
end)

Run(function()
	local ThirdPerson
	local Distance
	local Hook: boolean = false
	
	ThirdPerson = vape.Categories.Render:CreateModule({
	    Name = "ThirdPerson",
	    Function = function(Callback: boolean)
	        if Callback then
	            ThirdPerson:Clean(HookEvent("STEP_FPV_SOL_CAMERA", function()
	                local Bone = Frontlines.Main.globals.fpv_sol_instances.camera_bone
	                local State = Frontlines.Main.globals.cli_state
	                if Bone and State.state == Frontlines.Main.cli_state_t.COMBAT then
	                    local Id = State.fpv_sol_id
	                    local Actor = Frontlines.Main.soldier_actors[Id]
	                    local CameraCFrame: CFrame = Bone.TransformedWorldCFrame
	                    if Actor then
	                        Actor.main.direction.Value = Frontlines.Main.globals.fpv_sol_dir.dir
	                    end
	
	                    Camera.CFrame = CameraCFrame * CFrame.new(0, 2, Distance.Value)
	                    Camera.Focus = CameraCFrame + CameraCFrame.LookVector
	                    Frontlines.Main.exe_set(Frontlines.Main.exe_set_t.TPV_SOLDIER_JOINT_STEP, Id)
	                    return true
	                end
	            end))
	
	            if Entity.isAlive then
	                local Character: Model = Entity.character.Character
	                for _, v: BasePart in Character:GetDescendants() do
	                    if v:IsA("BasePart") then
	                        v.LocalTransparencyModifier = v.Parent ~= Character and 1 or 0
	                    end
	                end
	            end
	
	            ThirdPerson:Clean(Entity.Events.LocalAdded:Connect(function(Ent)
	                local Id = Frontlines.Main.globals.cli_state.fpv_sol_id
	                local Actor = Frontlines.Main.soldier_actors[Id]
	                if Actor then
	                    local Gun = Frontlines.Main.globals.fpv_sol_equipment.curr_equipment
	                    Frontlines.Events[Frontlines.Main.exe_func_t.INIT_TPV_SOL_JOINTS](Id)
	                    Frontlines.Events[Frontlines.Main.exe_func_t.INIT_TPV_SOL_EQUIPMENT_JOINTS](Id, Gun)
	                    Frontlines.Events[Frontlines.Main.exe_func_t.SET_SOLDIER_ANIMATION_VALUES](Id, Gun)
	                    Actor.main.alive.Value = true
	                end
	
	                for _, v: BasePart in Ent.Character:GetDescendants() do
	                    if v:IsA("BasePart") then
	                        v.LocalTransparencyModifier = v.Parent ~= Ent.Character and 1 or 0
	                    end
	                end
	            end))
	        else
	            if Entity.isAlive then
	                local Character: Model = Entity.character.Character
	                for _, v: BasePart in Character:GetDescendants() do
	                    if v:IsA("BasePart") then
	                        v.LocalTransparencyModifier = v.Parent ~= Character and 0 or 1
	                    end
	                end
	            end
	        end
	    end,
	    Tooltip = "View your character in third person"
	})
	Distance = ThirdPerson:CreateSlider({
	    Name = "Distance",
	    Min = 1,
	    Max = 15,
	    Default = 8
	})
end)

Run(function()
	local AutoRespawn
	
	AutoRespawn = vape.Categories.Utility:CreateModule({
	    Name = "AutoRespawn",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoRespawn:Clean(HookEvent("ENTER_CLI_KILLCAM", function(Id, Health: number)
	                task.delay(0, function()
	                    Frontlines.Main.exe_set(Frontlines.Main.exe_set_t.CTRL_KILLCAM_TO_COMBAT_RELEASE)
	                end)
	            end))
	        end
	    end,
	    Tooltip = "Automatically respawns after death"
	})
end)

Run(function()
	local ChatSpammer
	local Lines
	local Mode
	local Delay
	local Hide
	local OldChat
	
	ChatSpammer = vape.Categories.Utility:CreateModule({
	    Name = "ChatSpammer",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Index: number = 1
	            repeat
	                local Message: string = (#Lines.ListEnabled > 0 and Lines.ListEnabled[math.random(1, #Lines.ListEnabled)] or "vxpe on top")
	                if Mode.Value == "Order" and #Lines.ListEnabled > 0 then
	                    Message = Lines.ListEnabled[Index] or Lines.ListEnabled[1]
	                    Index += 1
	                    if Index > #Lines.ListEnabled then
	                        Index = 1
	                    end
	                end
	                Frontlines.Main.utils.net_msg_util.c_prep_net_msg(Frontlines.Main.globals.null_net_msg_state, Frontlines.Main.enums.c_net_msg.CHAT, Message:sub(1, 100))
	                task.wait(1)
	            until not ChatSpammer.Enabled
	        end
	    end,
	    Tooltip = "Automatically types in chat"
	})
	Lines = ChatSpammer:CreateTextList({Name = "Lines"})
	Mode = ChatSpammer:CreateDropdown({
	    Name = "Mode",
	    List = {"Random", "Order"}
	})
end)

Run(function()
	local PickupRange
	local Range
	
	PickupRange = vape.Categories.Utility:CreateModule({
	    Name = "PickupRange",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                if Entity.isAlive then
	                    for _, v: number in Frontlines.Main.globals.equipment_drop_ids do
	                        local Equipment = Frontlines.Main.globals.equipments[v]
	                        if Equipment and Equipment.model and Equipment.model.PrimaryPart and (Equipment.model.PrimaryPart.Position - Entity.character.RootPart.Position).Magnitude < Range.Value then
	                            if Frontlines.Main.matrix_bit(Frontlines.PickupBit, v) == 0 then
	                                Frontlines.Main.set_matrix_bit(Frontlines.PickupBit, v, true)
	                                Frontlines.Main.utils.net_msg_util.c_prep_net_msg(Frontlines.Main.globals.combat_net_msg_state, Frontlines.Main.enums.c_net_msg.PICKUP_AMMO, v)
	                                break
	                            end
	                        end
	                    end
	                end
	
	                task.wait(0.05)
	            until not PickupRange.Enabled
	        end
	    end,
	    Tooltip = "Picks up ammo from dropped guns in the proximity"
	})
	Range = PickupRange:CreateSlider({
	    Name = "Range",
	    Min = 1,
	    Max = 20,
	    Default = 20
	})
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
	            BulletTracers:Clean(HookEvent("SPAWN_FPV_SOL_BULLET", function(Id, BulletType, Origin: Vector3, Velocity: Vector3)
	                if DrawingToggle.Enabled then
	                    local Line = Drawing.new("Line")
	                    Line.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	                    DrawingObjects[Line] = {Origin, Origin + (Velocity.Unit * 1000), tick()}
	                    task.delay(Lifetime.Value, function()
	                        DrawingObjects[Line] = nil
	                        Line.Visible = false
	                        Line:Remove()
	                    end)
	                else
	                    local Tracer: Part = Instance.new("Part")
	                    Tracer.Size = Vector3.new(0.05, 0.05, 1000)
	                    Tracer.CFrame = CFrame.lookAt(Origin + (Velocity.Unit * 500), Origin + (Velocity.Unit * 1000))
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
	                    Debris:AddItem(Tracer, Lifetime.Value)
	                end
	            end))
	
	            if DrawingToggle.Enabled then
	                BulletTracers:Clean(RunService.RenderStepped:Connect(function()
	                    for Line: any, Data: any in DrawingObjects do
	                        local From, FromVisible = Camera:WorldToViewportPoint(Data[1])
	                        local To, ToVisible = Camera:WorldToViewportPoint(Data[2])
	                        if FromVisible and ToVisible then
	                            Line.Visible = true
	                            Line.From = Vector2.new(From.X, From.Y)
	                            Line.To = Vector2.new(To.X, To.Y)
	                            if Fade.Enabled then
	                                Line.Transparency = Color.Opacity * (1 - math.clamp((tick() - Data[3]) / Lifetime.Value, 0, 1))
	                            end
	                        else
	                            Line.Visible = false
	                        end
	                    end
	                end))
	            end
	        end
	    end,
	    Tooltip = "Replacement tracers for bullets"
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