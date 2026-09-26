local Run = function(Func: () -> ())
    Func()
end
local cloneref = cloneref or function(Reference: Instance)
    return Reference
end

local Players: Players = cloneref(game:GetService("Players"))
local UserInputService: UserInputService = cloneref(game:GetService("UserInputService"))
local ReplicatedStorage: ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local ReplicatedFirst: ReplicatedFirst = cloneref(game:GetService("ReplicatedFirst"))
local CollectionService: CollectionService = cloneref(game:GetService("CollectionService"))
local RunService: RunService = cloneref(game:GetService("RunService"))
local CoreGui: CoreGui = cloneref(game:GetService("CoreGui"))

local Camera: Camera = workspace.CurrentCamera
local LocalPlayer: Player = Players.LocalPlayer
local vape = shared.vape
local Entity = vape.Libraries.entity
local TargetInfo = vape.Libraries.targetinfo
local Arena = {}

local OldHit
local Spider = {Enabled = false}
local Phase = {Enabled = false}

local function CalculateMoveVector()
    local MoveVector: Vector3 = Arena.MoveController:GetMoveVector()
    local Cos, Sin
    local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = Camera.CFrame:GetComponents()
    if R12 < 1 and R12 > -1 then
        Cos = R22
        Sin = R02
    else
        Cos = R00
        Sin = -R01 * math.sign(R12)
    end
    MoveVector = Vector3.new((Cos * MoveVector.X + Sin * MoveVector.Z), 0, (Cos * MoveVector.Z - Sin * MoveVector.X)) / math.sqrt(Cos * Cos + Sin * Sin)
    return MoveVector.Unit == MoveVector.Unit and MoveVector.Unit or Vector3.zero
end

local function SendNotification(...)
    return vape:CreateNotification(...)
end

Run(function()
    local CharacterScript = LocalPlayer.PlayerScripts.CharacterController
    local Environment = getsenv(CharacterScript)
    if not (Environment and Environment.startHit) then
        repeat
            Environment = getsenv(CharacterScript)
            task.wait()
        until Environment and Environment.startHit or vape.Loaded == nil

        if vape.Loaded == nil then
            return
        end
    end

    Arena = {
        Client = getsenv(CharacterScript),
        PlayerState = require(CharacterScript.PlayerState),
        Inventory = require(CharacterScript.Inventory),
        MoveController = require(LocalPlayer.PlayerScripts.PlayerModule):GetControls(),
        SwingFunction = debug.getupvalue(getsenv(CharacterScript).startHit, 1)
    }

    for _, v: any in getconnections(RunService.Heartbeat) do
        if v.Function and islclosure(v.Function) and debug.getconstants(v.Function)[1] == 0.05 then
            Arena.TickFunction = debug.getupvalue(v.Function, 3)
        end
    end

    for _, v: any in getconnections(ReplicatedStorage.Remotes.LoadLocalCharacter.OnClientEvent) do
        if v.Function then
            Arena.MoveFunction = debug.getupvalue(v.Function, 9)
        end
    end

    vape:Clean(function()
        table.clear(Arena)
    end)
end)

Run(function()
    local function WaitForChildOfType(Object: Instance, Name: string, Timeout: number, Property)
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

    Entity.getUpdateConnections = function(Ent)
        return {
            Ent.Player.HealthValue:GetPropertyChangedSignal("Value")
        }
    end

    Entity.addEntity = function(Character, Player, TeamFunction)
        if not Character then
            return
        end

        if Player == LocalPlayer then
            local Humanoid = {GetState = function() end, Health = 100}
            local RootPart = Camera.CameraSubject

            local Target = {
                Connections = {},
                Character = Character,
                Health = 100,
                Head = RootPart,
                Humanoid = Humanoid,
                HumanoidRootPart = RootPart,
                HipHeight = 5,
                MaxHealth = 100,
                NPC = Player == nil,
                Player = Player,
                RootPart = RootPart,
                TeamCheck = TeamFunction
            }

            Entity.character = Target
            Entity.isAlive = true
            Entity.Events.LocalAdded:Fire(Target)
            return
        end

        Entity.EntityThreads[Character] = task.spawn(function()
            local Humanoid = WaitForChildOfType(Character, "Humanoid", 10)
            local RootPart = Character:WaitForChild("Torso", 10)
            local Head = Character:WaitForChild("Head", 10) or RootPart
            local HealthValue = Player:WaitForChild("HealthValue", 10)

            if Humanoid and RootPart then
                local Target = {
                    Connections = {},
                    Character = Character,
                    Health = Player.HealthValue.Value,
                    Head = Head,
                    Humanoid = Humanoid,
                    HumanoidRootPart = RootPart,
                    Hitbox = Character.PlayerHitbox,
                    HipHeight = 3,
                    MaxHealth = 100,
                    NPC = Player == nil,
                    Player = Player,
                    RootPart = RootPart,
                    TeamCheck = TeamFunction
                }

                Target.Targetable = Entity.targetCheck(Target)
                for _, v: RBXScriptSignal in Entity.getUpdateConnections(Target) do
                    table.insert(Target.Connections, v:Connect(function()
                        Target.Health = Player.HealthValue.Value
                        Entity.Events.EntityUpdated:Fire(Target)
                    end))
                end

                table.insert(Entity.List, Target)
                Entity.Events.EntityAdded:Fire(Target)
            end

            Entity.EntityThreads[Character] = nil
        end)
    end

    Entity.addPlayer = function(Player) end

    local OldStart = Entity.start
    Entity.start = function()
        OldStart()
        if Entity.Running then
            table.insert(Entity.Connections, Camera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
                if Camera.CameraSubject then
                    Entity.addEntity(true, LocalPlayer)
                end
            end))

            if Camera.CameraSubject then
                Entity.addEntity(true, LocalPlayer)
            end

            table.insert(Entity.Connections, workspace.OtherCharacters.ChildAdded:Connect(function(Character: Instance)
                local Player = Players:FindFirstChild(Character.Name:sub(1, #Character.Name - 14))
                if Player then
                    Entity.refreshEntity(Character, Player)
                end
            end))

            for _, Character: Instance in workspace.OtherCharacters:GetChildren() do
                local Player = Players:FindFirstChild(Character.Name:sub(1, #Character.Name - 14))
                if Player then
                    Entity.refreshEntity(Character, Player)
                end
            end
        end
    end

    Entity.start()
end)

for _, v: string in {"AimAssist", "Reach", "SilentAim", "AntiFall", "Desync", "Invisible", "Jesus", "MouseTP", "Phase", "SpinBot", "Swim", "TargetStrafe", "AnimationPlayer", "AntiRagdoll", "ChatSpammer", "Disabler", "StateSpoofer", "Freecam", "Gravity", "Parkour", "SafeWalk", "MurderMystery"} do
    vape:Remove(v)
end

Run(function()
	local AutoClicker
	local CPS
	local Thread
	
	local function AutoClick()
	    if Thread then
	        task.cancel(Thread)
	    end
	
	    Thread = task.delay(1 / CPS.GetRandomValue(), function()
	        repeat
	            task.spawn(Arena.Client.startHit)
	            task.wait(1 / CPS.GetRandomValue())
	        until not AutoClicker.Enabled
	    end)
	end
	
	AutoClicker = vape.Categories.Combat:CreateModule({
	    Name = "AutoClicker",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoClicker:Clean(UserInputService.InputBegan:Connect(function(Input: InputObject)
	                if Input.UserInputType == Enum.UserInputType.MouseButton1 then
	                    AutoClick()
	                end
	            end))
	
	            AutoClicker:Clean(UserInputService.InputEnded:Connect(function(Input: InputObject)
	                if Input.UserInputType == Enum.UserInputType.MouseButton1 and Thread then
	                    task.cancel(Thread)
	                    Thread = nil
	                end
	            end))
	        else
	            if Thread then
	                task.cancel(Thread)
	                Thread = nil
	            end
	        end
	    end,
	    Tooltip = "Hold attack button to automatically click"
	})
	CPS = AutoClicker:CreateTwoSlider({
	    Name = "CPS",
	    Min = 1,
	    Max = 9,
	    DefaultMin = 7,
	    DefaultMax = 7
	})
end)

Run(function()
	local Reach
	local Value
	local Old
	
	Reach = vape.Categories.Combat:CreateModule({
	    Name = "Reach",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = debug.getupvalue(OldHit or Arena.Client.startHit, 4)
	            debug.setupvalue(OldHit or Arena.Client.startHit, 4, Old + Value.Value)
	        else
	            if Old then
	                debug.setupvalue(OldHit or Arena.Client.startHit, 4, Old)
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Extends attack reach"
	})
	Value = Reach:CreateSlider({
	    Name = "Range",
	    Min = 0,
	    Max = 6,
	    Default = 6,
	    Decimal = 10,
	    Function = function(Val: number)
	        if Reach.Enabled then
	            debug.setupvalue(OldHit or Arena.Client.startHit, 4, Old + Val)
	        end
	    end,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
end)

Run(function()
	local Sprint
	
	Sprint = vape.Categories.Combat:CreateModule({
	    Name = "Sprint",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                Arena.PlayerState.Preferences.AutoSprint = true
	                task.wait(0.016)
	            until not Sprint.Enabled
	        end
	    end,
	    Tooltip = "Sets your sprinting to true."
	})
end)

Run(function()
	local Velocity
	local Horizontal
	local Vertical
	local Chance
	local Targeting
	local Connection
	local Generator, Old = Random.new()
	
	local function VelocityFunction(...)
	    if Generator:NextNumber(0, 100) > Chance.Value then
	        return Old(...)
	    end
	
	    local Data = ...
	    local Check = (not Targeting.Enabled) or Entity.EntityPosition({
	        Range = 50,
	        Part = "RootPart",
	        Players = true
	    })
	
	    if Check and not Data.position then
	        local HorizontalScale, VerticalScale = (Horizontal.Value / 100), (Vertical.Value / 100)
	        if HorizontalScale == 0 and VerticalScale == 0 then
	            return
	        end
	        Data.vel = Vector3.new(Data.vel.X * HorizontalScale, Data.vel.Y * VerticalScale, Data.vel.Z * HorizontalScale)
	    end
	
	    return Old(...)
	end
	
	Velocity = vape.Categories.Combat:CreateModule({
	    Name = "Velocity",
	    Function = function(Callback: boolean)
	        if Callback then
	            Connection = getconnections(ReplicatedStorage.Remotes.ClientStateUpdate.OnClientEvent)[1]
	            if not Connection then
	                return
	            end
	
	            Old = hookfunction(Connection.Function, function(...)
	                return VelocityFunction(...)
	            end)
	        else
	            if Old then
	                hookfunction(Connection.Function, Old)
	            end
	            Connection = nil
	        end
	    end,
	    Tooltip = "Reduces knockback taken"
	})
	Horizontal = Velocity:CreateSlider({
	    Name = "Horizontal",
	    Min = 0,
	    Max = 100,
	    Default = 0,
	    Suffix = "%"
	})
	Vertical = Velocity:CreateSlider({
	    Name = "Vertical",
	    Min = 0,
	    Max = 100,
	    Default = 0,
	    Suffix = "%"
	})
	Chance = Velocity:CreateSlider({
	    Name = "Chance",
	    Min = 0,
	    Max = 100,
	    Default = 100,
	    Suffix = "%"
	})
	Targeting = Velocity:CreateToggle({Name = "Only when targeting"})
end)

Run(function()
	local AutoBlock
	
	AutoBlock = vape.Categories.Blatant:CreateModule({
	    Name = "AutoBlock",
	    Function = function(Callback: boolean)
	        if Callback then
	            OldHit = hookfunction(Arena.Client.startHit, function(...)
	                if debug.getupvalue(OldHit, 6) then
	                    Arena.Client.endBlockEvent:FireServer()
	                    debug.setupvalue(OldHit, 6, false)
	
	                    local Results = table.pack(OldHit(...))
	                    Arena.Client.beginBlockEvent:FireServer()
	                    debug.setupvalue(OldHit, 6, true)
	
	                    return unpack(Results, 1, Results.n)
	                else
	                    return OldHit(...)
	                end
	            end)
	        else
	            if OldHit then
	                hookfunction(Arena.Client.startHit, OldHit)
	                OldHit = nil
	            end
	        end
	    end,
	    Tooltip = "Automatically unblock and reblock before hitting"
	})
end)

local Fly
local LongJump
Run(function()
    local Keys
    local Value
    local VerticalValue
    local Up, Down = 0, 0

    Fly = vape.Categories.Blatant:CreateModule({
        Name = "Fly",
        Function = function(Callback: boolean)
            if Callback then
                Fly:Clean(RunService.PreSimulation:Connect(function(Delta: number)
                    if Entity.isAlive then
                        local MoveDirection: Vector3 = CalculateMoveVector() * Value.Value
                        local Velocity: Vector3 = debug.getupvalue(Arena.TickFunction, 6)

                        debug.setupvalue(Arena.TickFunction, 6, Vector3.new(MoveDirection.X, 1 + ((Up + Down) * VerticalValue.Value), MoveDirection.Z))
                    end
                end))

                Up, Down = 0, 0
                for _, v: string in {"InputBegan", "InputEnded"} do
                    Fly:Clean(UserInputService[v]:Connect(function(Input: InputObject)
                        if not UserInputService:GetFocusedTextBox() then
                            local KeyNames: {string} = Keys.Value:split("/")
                            if Input.KeyCode == Enum.KeyCode[KeyNames[1]] then
                                Up = v == "InputBegan" and 1 or 0
                            elseif Input.KeyCode == Enum.KeyCode[KeyNames[2]] then
                                Down = v == "InputBegan" and -1 or 0
                            end
                        end
                    end))
                end

                if UserInputService.TouchEnabled then
                    pcall(function()
                        local JumpButton: ImageButton = LocalPlayer.PlayerGui.TouchGui.TouchControlFrame.JumpButton
                        Fly:Clean(JumpButton:GetPropertyChangedSignal("ImageRectOffset"):Connect(function()
                            Up = JumpButton.ImageRectOffset.X == 146 and 1 or 0
                        end))
                    end)
                end
            end
        end,
        Tooltip = "Makes you go zoom."
    })
    Keys = Fly:CreateDropdown({
        Name = "Keys",
        List = {"Space/LeftControl", "Space/LeftShift", "E/Q", "Space/Q", "ButtonA/ButtonL2"},
        Tooltip = "The key combination for going up & down"
    })
    Value = Fly:CreateSlider({
        Name = "Speed",
        Min = 1,
        Max = 150,
        Default = 50,
        Suffix = function(Val: number)
            return Val == 1 and "stud" or "studs"
        end
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
	local AutoDisable
	
	local function Jump()
	    local OnGround = debug.getupvalue(Arena.MoveFunction, 4)
	    if OnGround then
	        local Velocity: Vector3 = debug.getupvalue(Arena.TickFunction, 6)
	        debug.setupvalue(Arena.TickFunction, 6, Vector3.new(Velocity.X, Value.Value, Velocity.Z))
	    end
	end
	
	HighJump = vape.Categories.Blatant:CreateModule({
	    Name = "HighJump",
	    Function = function(Callback: boolean)
	        if Callback then
	            if AutoDisable.Enabled then
	                Jump()
	                HighJump:Toggle()
	            else
	                HighJump:Clean(RunService.RenderStepped:Connect(function()
	                    if not UserInputService:GetFocusedTextBox() and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
	                        Jump()
	                    end
	                end))
	            end
	        end
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
	AutoDisable = HighJump:CreateToggle({
	    Name = "Auto Disable",
	    Default = true
	})
end)

Run(function()
	local HitBoxes
	local Targets
	local TargetPart
	local Expand
	local Modified: {[BasePart]: Vector3} = {}
	
	HitBoxes = vape.Categories.Blatant:CreateModule({
	    Name = "HitBoxes",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                for _, v: any in Entity.List do
	                    if v.Targetable then
	                        if not Targets.Players.Enabled and v.Player then
	                            continue
	                        end
	                        if not Targets.NPCs.Enabled and v.NPC then
	                            continue
	                        end
	                        local Part: BasePart = v.Hitbox
	                        if not Modified[Part] then
	                            Modified[Part] = Part.Size
	                        end
	
	                        Part.Size = Modified[Part] + Vector3.new(Expand.Value, Expand.Value, Expand.Value)
	                    end
	                end
	
	                task.wait()
	            until not HitBoxes.Enabled
	        else
	            for Part: BasePart, v: Vector3 in Modified do
	                Part.Size = v
	            end
	            table.clear(Modified)
	        end
	    end,
	    Tooltip = "Expands entities hitboxes"
	})
	Targets = HitBoxes:CreateTargets({Players = true})
	Expand = HitBoxes:CreateSlider({
	    Name = "Expand amount",
	    Min = 0,
	    Max = 6,
	    Decimal = 10,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
end)

Run(function()
	local Killaura
	local Targets
	local AttackRange
	local AngleSlider
	local Max
	local Mouse
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
	
	    return true, true
	end
	
	Killaura = vape.Categories.Blatant:CreateModule({
	    Name = "Killaura",
	    Function = function(Callback: boolean)
	        if Callback then
	            local CustomCFrame: CFrame?
	            local Proxy = newproxy(true)
	            local BlockFunction = OldHit or Arena.Client.startHit
	            getmetatable(Proxy).__index = function(self, Key: string)
	                if Key == "CFrame" then
	                    return CustomCFrame or Camera.CFrame
	                end
	            end
	
	            debug.setupvalue(Arena.TickFunction, 13, Proxy)
	
	            repeat
	                CustomCFrame = nil
	                local Interest: boolean = GetAttackData()
	                local Attacked = {}
	
	                if Interest then
	                    local Entities = Entity.AllPosition({
	                        Range = AttackRange.Value,
	                        Wallcheck = Targets.Walls.Enabled or nil,
	                        Part = "RootPart",
	                        Players = Targets.Players.Enabled,
	                        NPCs = Targets.NPCs.Enabled,
	                        Priority = Targets.Priority.Value,
	                        Limit = Max.Value
	                    })
	
	                    if #Entities > 0 then
	                        local SelfPosition: Vector3 = Entity.character.RootPart.Position
	                        local LocalFacing: Vector3 = Camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	                        local Reblock: boolean = false
	
	                        for _, v: any in Entities do
	                            local Delta: Vector3 = (v.RootPart.Position - SelfPosition)
	                            local Angle: number = math.acos(LocalFacing:Dot((Delta * Vector3.new(1, 0, 1)).Unit))
	                            if Angle > (math.rad(AngleSlider.Value) / 2) then
	                                continue
	                            end
	
	                            table.insert(Attacked, {
	                                Entity = v,
	                                Check = BoxAttackColor
	                            })
	                            TargetInfo.Targets[v] = tick() + 1
	
	                            if debug.getupvalue(BlockFunction, 6) then
	                                Arena.Client.endBlockEvent:FireServer()
	                                debug.setupvalue(BlockFunction, 6, false)
	                                Reblock = true
	                            end
	
	                            if AttackDelay < tick() then
	                                Arena.SwingFunction()
	                                AttackDelay = tick() + 0.11
	
	                                if vape.ThreadFix then
	                                    setthreadidentity(8)
	                                end
	                            end
	
	                            local LookCFrame: CFrame = CFrame.lookAt(SelfPosition, v.RootPart.Position)
	                            if Angle > math.rad(65) then
	                                CustomCFrame = LookCFrame
	                            end
	
	                            ReplicatedStorage.Remotes.HitRequest:FireServer(SelfPosition, LookCFrame.LookVector, v.Character, v.Player)
	                        end
	
	                        if Reblock then
	                            Arena.Client.beginBlockEvent:FireServer()
	                            debug.setupvalue(BlockFunction, 6, true)
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
	
	                task.wait(#Attacked > 0 and #Attacked * 0.07 or 0.016)
	            until not Killaura.Enabled
	        else
	            debug.setupvalue(Arena.TickFunction, 13, Camera)
	
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
	    Max = 16,
	    Default = 16,
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
	        BoxAttackColor.Object.Visible = Callback
	        if Callback then
	            for i: number = 1, 10 do
	                local Box: BoxHandleAdornment = Instance.new("BoxHandleAdornment")
	                Box.Adornee = nil
	                Box.AlwaysOnTop = true
	                Box.Size = Vector3.new(3, 7, 3)
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
	local Value
	local AutoDisable
	
	LongJump = vape.Categories.Blatant:CreateModule({
	    Name = "LongJump",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Exempt: number = tick() + 0.1
	            LongJump:Clean(RunService.PreSimulation:Connect(function(Delta: number)
	                if Entity.isAlive then
	                    local MoveDirection: Vector3 = CalculateMoveVector() * Value.Value
	                    local OnGround = debug.getupvalue(Arena.MoveFunction, 4)
	
	                    if OnGround then
	                        if Exempt < tick() and AutoDisable.Enabled then
	                            if LongJump.Enabled then
	                                LongJump:Toggle()
	                            end
	                        else
	                            debug.setupvalue(Arena.TickFunction, 6, Vector3.new(MoveDirection.X, 30, MoveDirection.Z))
	                        end
	                    end
	
	                    local Velocity: Vector3 = debug.getupvalue(Arena.TickFunction, 6)
	                    debug.setupvalue(Arena.TickFunction, 6, Vector3.new(MoveDirection.X, Velocity.Y, MoveDirection.Z))
	                end
	            end))
	        end
	    end,
	    Tooltip = "Lets you jump farther"
	})
	Value = LongJump:CreateSlider({
	    Name = "Speed",
	    Min = 1,
	    Max = 150,
	    Default = 50,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	AutoDisable = LongJump:CreateToggle({
	    Name = "Auto Disable",
	    Default = true
	})
end)

Run(function()
	local NoSlowdown
	local Old
	
	NoSlowdown = vape.Categories.Blatant:CreateModule({
	    Name = "NoSlowdown",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = debug.getupvalue(Arena.MoveFunction, 17)
	            debug.setupvalue(Arena.MoveFunction, 17, debug.getupvalue(Arena.MoveFunction, 19))
	        else
	            if Old then
	                debug.setupvalue(Arena.MoveFunction, 17, Old)
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Prevent you from slowing down when using items."
	})
end)

Run(function()
	local Speed
	local Value
	local AutoJump
	
	Speed = vape.Categories.Blatant:CreateModule({
	    Name = "Speed",
	    Function = function(Callback: boolean)
	        if Callback then
	            Speed:Clean(RunService.PreSimulation:Connect(function()
	                if not Fly.Enabled and not LongJump.Enabled then
	                    local MoveDirection: Vector3 = CalculateMoveVector() * Value.Value
	                    local OnGround = debug.getupvalue(Arena.MoveFunction, 4)
	                    local Velocity: Vector3 = debug.getupvalue(Arena.TickFunction, 6)
	
	                    debug.setupvalue(Arena.TickFunction, 6, Vector3.new(MoveDirection.X, AutoJump.Enabled and OnGround and MoveDirection.Magnitude > 0 and 20 or Velocity.Y, MoveDirection.Z))
	                end
	            end))
	        end
	    end,
	    Tooltip = "Increases your movement with various methods."
	})
	Value = Speed:CreateSlider({
	    Name = "Speed",
	    Min = 1,
	    Max = 90,
	    Default = 30,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	AutoJump = Speed:CreateToggle({
	    Name = "AutoJump"
	})
end)

Run(function()
	local Value
	local RayCheck: RaycastParams = RaycastParams.new()
	RayCheck.RespectCanCollide = true
	local Active
	
	Spider = vape.Categories.Blatant:CreateModule({
	    Name = "Spider",
	    Function = function(Callback: boolean)
	        if Callback then
	            Spider:Clean(RunService.PreSimulation:Connect(function(Delta: number)
	                if Entity.isAlive then
	                    local Root: BasePart = Entity.character.RootPart
	                    local Ignore: {Instance} = {Camera, LocalPlayer.Character}
	                    for _, v: any in Entity.List do
	                        table.insert(Ignore, v.Character)
	                    end
	
	                    SpiderShift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
	                    RayCheck.FilterDescendantsInstances = Ignore
	                    RayCheck.CollisionGroup = "Hitbox"
	
	                    local MoveVector: Vector3 = CalculateMoveVector() * 2.5
	                    local WallRay: RaycastResult? = workspace:Raycast(Root.Position - Vector3.new(0, Entity.character.HipHeight - 0.5, 0), MoveVector, RayCheck)
	                    if Active and not WallRay then
	                        Root.Velocity = Vector3.new(Root.Velocity.X, 0, Root.Velocity.Z)
	                    end
	
	                    Active = WallRay
	                    if Active and WallRay.Normal.Y == 0 then
	                        if not Phase.Enabled or not SpiderShift then
	                            local Velocity: Vector3 = debug.getupvalue(Arena.TickFunction, 6)
	                            debug.setupvalue(Arena.TickFunction, 6, Vector3.new(Velocity.X, Value.Value, Velocity.Z))
	                        end
	                    end
	                end
	            end))
	        else
	            SpiderShift = false
	        end
	    end,
	    Tooltip = "Lets you climb up walls. (Hold shift to use Phase over spider)"
	})
	Value = Spider:CreateSlider({
	    Name = "Speed",
	    Min = 0,
	    Max = 100,
	    Default = 30,
	    Darker = true,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
end)

Run(function()
	local FastBreak
	local Value
	local Old
	
	FastBreak = vape.Categories.World:CreateModule({
	    Name = "FastBreak",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = hookfunction(Arena.Client.showMiningProgress, function(Progress: number)
	                Progress *= Value.Value
	                debug.setstack(3, 5, debug.getstack(3, 5) * Value.Value)
	                return Old(Progress)
	            end)
	        else
	            if Old then
	                hookfunction(Arena.Client.showMiningProgress, Old)
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Break blocks faster when mining."
	})
	Value = FastBreak:CreateSlider({
	    Name = "Multiplier",
	    Min = 0,
	    Max = 3,
	    Default = 3,
	    Decimal = 10
	})
end)

Run(function()
	local FastPlace
	local Value
	local Old
	
	FastPlace = vape.Categories.World:CreateModule({
	    Name = "FastPlace",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = debug.getupvalue(Arena.Client.startPlaceHold, 7)
	            debug.setupvalue(Arena.Client.startPlaceHold, 7, math.max(Value.Value, 0.001))
	        else
	            if Old then
	                debug.setupvalue(Arena.Client.startPlaceHold, 7, Old)
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Place blocks faster while holding right click."
	})
	Value = FastPlace:CreateSlider({
	    Name = "Delay",
	    Min = 0,
	    Max = 0.2,
	    Default = 0,
	    Decimal = 100,
	    Function = function(Val: number)
	        if FastPlace.Enabled then
	            debug.setupvalue(Arena.Client.startPlaceHold, 7, math.max(Val, 0.001))
	        end
	    end,
	    Suffix = function(Val: number)
	        return "seconds"
	    end
	})
end)