local Run = function(Func: () -> ())
    Func()
end
local cloneref = cloneref or function(Reference: Instance)
    return Reference
end

local Players: Players = cloneref(game:GetService("Players"))
local UserInputService: UserInputService = cloneref(game:GetService("UserInputService"))
local ReplicatedStorage: ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local CollectionService: CollectionService = cloneref(game:GetService("CollectionService"))
local TextChatService: TextChatService = cloneref(game:GetService("TextChatService"))
local RunService: RunService = cloneref(game:GetService("RunService"))
local GuiService: GuiService = cloneref(game:GetService("GuiService"))
local CoreGui: CoreGui = cloneref(game:GetService("CoreGui"))

local Camera: Camera = workspace.CurrentCamera
local LocalPlayer: Player = Players.LocalPlayer
local vape = shared.vape
local Entity = vape.Libraries.entity
local Whitelist = vape.Libraries.whitelist
local PredictionLib = vape.Libraries.prediction
local TargetInfo = vape.Libraries.targetinfo
local SessionInfo = vape.Libraries.sessioninfo
local GetVapeAsset = vape.Libraries.getvapeasset

local Blockwars = {}
local Blocks = {}
local BlockTimes: {[Model]: number} = {}
local AnticheatBypass
local BypassRoot
local IsAttacking

local function ApplySpeed(Speed: number, Delta: number)
    local Root: BasePart = Entity.character.RootPart
    local Destination: Vector3 = (Entity.character.Humanoid.MoveDirection * math.max((Speed + (Entity.character.Humanoid.WalkSpeed - 16)) - Entity.character.Humanoid.WalkSpeed, 0) * Delta)
    local RayCheck: RaycastParams = RaycastParams.new()
    RayCheck.RespectCanCollide = true
    RayCheck.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    RayCheck.CollisionGroup = Root.CollisionGroup

    local Ray: RaycastResult? = workspace:Raycast(Root.Position, Destination, RayCheck)
    if Ray then
        Destination = ((Ray.Position + Ray.Normal) - Root.Position)
    end
    Root.CFrame += Destination
end

local function Collection(Tags, Module, CustomAdd, CustomRemove)
    Tags = typeof(Tags) ~= "table" and {Tags} or Tags
    local Objects, Connections = {}, {}

    for _, Tag: string in Tags do
        table.insert(Connections, CollectionService:GetInstanceAddedSignal(Tag):Connect(function(Object: Instance)
            if CustomAdd then
                CustomAdd(Objects, Object, Tag)
                return
            end
            table.insert(Objects, Object)
        end))
        table.insert(Connections, CollectionService:GetInstanceRemovedSignal(Tag):Connect(function(Object)
            if CustomRemove then
                CustomRemove(Objects, Object, Tag)
                return
            end
            Object = table.find(Objects, Object)
            if Object then
                table.remove(Objects, Object)
            end
        end))

        for _, v: Instance in CollectionService:GetTagged(Tag) do
            if CustomAdd then
                CustomAdd(Objects, v, Tag)
                continue
            end
            table.insert(Objects, v)
        end
    end

    local CleanFunc = function(self)
        for _, v: RBXScriptConnection in Connections do
            v:Disconnect()
        end
        table.clear(Connections)
        table.clear(Objects)
        table.clear(self)
    end
    if Module then
        Module:Clean(CleanFunc)
    end
    return Objects, CleanFunc
end

local function GetInventory(): {Instance}
    local Inventory: {Instance} = {}
    local Backpack: Backpack? = LocalPlayer:FindFirstChildWhichIsA("Backpack")
    if Backpack then
        Inventory = Backpack:GetChildren()
    end

    local Equipped: Tool? = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
    if Equipped then
        table.insert(Inventory, Equipped)
    end

    return Inventory
end

local function GetTool(): Tool?
    return LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool")
end

Run(function()
    local OldStart = Entity.start
    local function CustomEntity(Ent: Instance)
        Entity.addEntity(Ent, nil, function(self)
            return (LocalPlayer.Team and LocalPlayer.Team.Name or "") ~= self.Character:GetAttribute("TeamId")
        end)
    end

    Entity.start = function()
        OldStart()
        if Entity.Running then
            for _, Ent: Instance in CollectionService:GetTagged("Attackable") do
                CustomEntity(Ent)
            end
            table.insert(Entity.Connections, CollectionService:GetInstanceAddedSignal("Attackable"):Connect(CustomEntity))
            table.insert(Entity.Connections, CollectionService:GetInstanceRemovedSignal("Attackable"):Connect(function(Ent: Instance)
                Entity.removeEntity(Ent)
            end))
        end
    end
end)
Entity.start()

Run(function()
    Blockwars = {
        RemoteIndex = require(ReplicatedStorage.Modules.RemotesIndex),
        BlockBreakConstants = require(ReplicatedStorage.Modules.Configs.BlockBreakConfig),
        ShopConfig = require(ReplicatedStorage.Modules.Configs.ShopConfig),
        Inventory = debug.getupvalue(require(ReplicatedStorage.Modules.ShopUIClient).Start, 8)
    }

    Blocks = Collection("BedWarsX_PlacedBlock", vape, function(Objects, Block: BasePart)
        Objects[Block.Position // 3] = Block
    end, function(Objects, Block: BasePart)
        Objects[Block.Position // 3] = nil
    end)

    local Kills = SessionInfo:AddItem("Kills")
    local Beds = SessionInfo:AddItem("Beds")
    local Wins = SessionInfo:AddItem("Wins")
    local Games = SessionInfo:AddItem("Games")

    task.delay(1, function()
        if workspace:GetAttribute("ServerType") ~= "Lobby" then
            Games:Increment()
        end
    end)

    vape:Clean(LocalPlayer:GetAttributeChangedSignal("RoundKills"):Connect(function()
        if LocalPlayer:GetAttribute("RoundKills") > 0 then
            Kills:Increment()
        end
    end))

    vape:Clean(Blockwars.RemoteIndex.Round_Event.OnClientEvent:Connect(function(Data)
        if type(Data) == "table" and Data.id == "final_kill" then
            if LocalPlayer.Team and LocalPlayer.Team.Name == Data.teamId then
                Wins:Increment()
            end
        end
    end))

    vape:Clean(Blockwars.RemoteIndex.Bed_Destroyed.OnClientEvent:Connect(function(Data)
        if type(Data) == "table" and Data.breakerId == LocalPlayer.UserId then
            Beds:Increment()
        end
    end))

    vape:Clean(Entity.Events.EntityAdded:Connect(function(Entity)
        BlockTimes[Entity.Character] = 0

        local Animator: Animator? = Entity.Humanoid:FindFirstChild("Animator")
        if Animator then
            table.insert(Entity.Connections, Animator.AnimationPlayed:Connect(function(Track: AnimationTrack)
                if Track.Animation.AnimationId == "rbxassetid://99664081334494" or Track.Animation.AnimationId == "rbxassetid://75062274621204" then
                    BlockTimes[Entity.Character] = os.clock()
                end
            end))
        end
    end))

    vape:Clean(Entity.Events.EntityRemoved:Connect(function(Entity)
        BlockTimes[Entity.Character] = nil
    end))
end)

for _, v: string in {"AimAssist", "Reach", "SilentAim", "TriggerBot", "Jesus", "AutoRejoin", "Disabler", "PromptChanger", "SafeWalk", "MurderMystery"} do
    vape:Remove(v)
end

Run(function()
	local OverParams: RaycastParams = RaycastParams.new()
	OverParams.RespectCanCollide = true
	
	local function ClampVector(Vector: Vector3, Max: number): Vector3
	    if Vector.Magnitude > Max then
	        return Vector.Unit == Vector.Unit and Vector.Unit * Max or Vector3.zero
	    end
	
	    return Vector
	end
	
	AnticheatBypass = vape.Categories.Blatant:CreateModule({
	    Name = "AnticheatBypass",
	    Function = function(Callback: boolean)
	        if Callback then
	            BypassRoot = Instance.new("Part")
	            BypassRoot.CanCollide = false
	            BypassRoot.CanQuery = false
	            BypassRoot.Size = Vector3.new(2, 2, 1)
	            BypassRoot.Material = Enum.Material.SmoothPlastic
	            BypassRoot.Transparency = 1
	            BypassRoot.Parent = workspace.CurrentCamera
	            AnticheatBypass:Clean(BypassRoot)
	
	            local OldCFrame, OldVelocity
	            local BindKey: string = game:GetService("HttpService"):GenerateGUID(true)
	            RunService:BindToRenderStep(BindKey, 0, function()
	                if Entity.isAlive and OldCFrame then
	                    Entity.character.RootPart.CFrame = OldCFrame
	                end
	            end)
	
	            AnticheatBypass:Clean(function()
	                RunService:UnbindFromRenderStep(BindKey)
	            end)
	
	            for _, Signal: RBXScriptSignal in {Entity.Events.LocalAdded, ReplicatedStorage.GameEvents.BedWarsRemotes.AntiCheat_Strike.OnClientEvent} do
	                AnticheatBypass:Clean(Signal:Connect(function()
	                    OldCFrame = nil
	                end))
	            end
	
	            local TeleportTimer: number = 0
	            local FallTimer: number = 0
	            AnticheatBypass:Clean(RunService.Heartbeat:Connect(function(Delta: number)
	                if Entity.isAlive then
	                    local Root: BasePart = Entity.character.RootPart
	                    if not OldCFrame then
	                        BypassRoot.CFrame = Root.CFrame
	                    end
	                    OldCFrame = Root.CFrame
	
	                    local Difference: Vector3 = (OldCFrame.Position - BypassRoot.Position) * Vector3.new(1, 0, 1)
	                    local Direction: Vector3 = Difference.Unit
	                    Direction = Direction == Direction and Difference.Magnitude > 0.1 and Direction * Entity.character.Humanoid.WalkSpeed or Vector3.zero
	                    BypassRoot.AssemblyLinearVelocity = Vector3.new(Direction.X, 0, Direction.Z)
	                    BypassRoot.CFrame = CFrame.lookAlong(Vector3.new(BypassRoot.Position.X, Root.Position.Y, BypassRoot.Position.Z), Root.CFrame.LookVector)
	                    if Difference.Magnitude > 6 and (os.clock() - TeleportTimer) > 0.75 then
	                        BypassRoot.CFrame += ClampVector(Difference, Entity.character.Humanoid.WalkSpeed)
	                        TeleportTimer = os.clock()
	                    end
	
	                    OverParams.CollisionGroup = Root.CollisionGroup
	                    OverParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
	                    local FlyCheck: RaycastResult? = workspace:Raycast(BypassRoot.Position, Vector3.new(0, -8, 0), OverParams)
	                    if not FlyCheck then
	                        if FallTimer == 0 then
	                            FallTimer = os.clock()
	                        end
	                        BypassRoot.CFrame -= Vector3.new(0, ((os.clock() - FallTimer) % 1) * 10, 0)
	                    else
	                        FallTimer = 0
	                    end
	
	                    Root.CFrame = BypassRoot.CFrame
	                    if Root.AssemblyLinearVelocity.Magnitude < 0.1 then
	                        Root.AssemblyLinearVelocity += Vector3.new(0, -0.1, 0)
	                    end
	                else
	                    BypassRoot.CFrame = CFrame.new()
	                    BypassRoot.AssemblyLinearVelocity = Vector3.zero
	                end
	            end))
	        else
	            BypassRoot = nil
	        end
	    end,
	    Tooltip = "Using various methods to bypass the Anticheat."
	})
end)

local Fly
Run(function()
    local Value
    local Keys
    local Up, Down = 0, 0
    local Platform: Part = Instance.new("Part")
    Platform.CanQuery = false
    Platform.Anchored = true
    Platform.Size = Vector3.new(4, 1, 4)
    Platform.Transparency = 1
    Platform.Parent = nil

    Fly = vape.Categories.Blatant:CreateModule({
        Name = "Fly",
        Function = function(Callback: boolean)
            if Platform then
                Platform.Parent = Callback and Camera or nil
            end

            if Callback then
                if not AnticheatBypass.Enabled then
                    AnticheatBypass:Toggle()
                end

                Fly:Clean(RunService.PreSimulation:Connect(function(Delta: number)
                    if Entity.isAlive then
                        ApplySpeed(Value.Value, Delta)
                        Platform.CFrame = Down ~= 0 and CFrame.identity or Entity.character.RootPart.CFrame + Vector3.new(0, -(Entity.character.HipHeight + 0.5), 0)
                    end
                end))

                Up, Down = 0, 0
                for _, v: string in {"InputBegan", "InputEnded"} do
                    Fly:Clean(UserInputService[v]:Connect(function(Input: InputObject)
                        if not UserInputService:GetFocusedTextBox() then
                            local Divided: {string} = Keys.Value:split("/")
                            if Input.KeyCode == Enum.KeyCode[Divided[1]] then
                                Up = v == "InputBegan" and 1 or 0
                            elseif Input.KeyCode == Enum.KeyCode[Divided[2]] then
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
        ExtraText = function()
            return "BlockWars"
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
        Max = 38,
        Default = 38,
        Suffix = function(Val: number)
            return Val == 1 and "stud" or "studs"
        end
    })
end)

Run(function()
	local Killaura
	local Targets
	local SwingRange
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
	local Particles, Boxes, AttackDelay = {}, {}, {}
	
	local function GetSword()
	    local Inventory: {Instance} = GetInventory()
	    for _, Tool: Instance in Inventory do
	        if Tool:GetAttribute("WeaponType") then
	            return Tool
	        end
	    end
	end
	
	local function GetAttackData()
	    if Mouse.Enabled then
	        if not UserInputService:IsMouseButtonPressed(0) then
	            return false
	        end
	    end
	
	    local Tool = GetSword()
	    return Tool or nil, Tool
	end
	
	Killaura = vape.Categories.Blatant:CreateModule({
	    Name = "Killaura",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                IsAttacking = false
	                local Tool = GetAttackData()
	                local Attacked = {}
	
	                if Tool then
	                    local Entities = Entity.AllPosition({
	                        Range = AttackRange.Value,
	                        Wallcheck = Targets.Walls.Enabled or nil,
	                        Origin = BypassRoot and BypassRoot.Position or nil,
	                        Part = "RootPart",
	                        Players = Targets.Players.Enabled,
	                        NPCs = Targets.NPCs.Enabled,
	                        Priority = Targets.Priority.Value,
	                        Limit = Max.Value
	                    })
	
	                    if #Entities > 0 then
	                        IsAttacking = true
	                        local SelfPosition: Vector3 = Entity.character.RootPart.Position
	                        local LocalFacing: Vector3 = Entity.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	
	                        if Tool.Parent ~= LocalPlayer.Character then
	                            Entity.character.Humanoid:EquipTool(Tool)
	                        end
	
	                        for _, v: any in Entities do
	                            local Delta: Vector3 = (v.RootPart.Position - SelfPosition)
	                            local Angle: number = math.acos(LocalFacing:Dot((Delta * Vector3.new(1, 0, 1)).Unit))
	                            if Angle > (math.rad(AngleSlider.Value) / 2) then
	                                continue
	                            end
	
	                            table.insert(Attacked, {
	                                Entity = v,
	                                Check = Delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
	                            })
	                            TargetInfo.Targets[v] = tick() + 1
	
	                            if (os.clock() - (BlockTimes[v.Character] or 0)) < 0.3 then
	                                continue
	                            end
	
	                            if (os.clock() - (AttackDelay[v.Character] or 0) < 0.03) then
	                                continue
	                            end
	
	                            ReplicatedStorage.GameEvents.CombatRemotes.Combat_FeintSwing:FireServer()
	                            ReplicatedStorage.GameEvents.CombatRemotes.Combat_RequestAttack:FireServer(Tool:GetAttribute("WeaponType"), v.Character)
	                            AttackDelay[v.Character] = os.clock()
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
	                    local Vector: Vector3 = Attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
	                    Entity.character.RootPart.CFrame = CFrame.lookAt(Entity.character.RootPart.Position, Vector3.new(Vector.X, Entity.character.RootPart.Position.Y + 0.01, Vector.Z))
	                end
	
	                task.wait(0.016)
	            until not Killaura.Enabled
	        else
	            IsAttacking = false
	
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
	Targets = Killaura:CreateTargets({
	    Players = true,
	    NPCs = true
	})
	AttackRange = Killaura:CreateSlider({
	    Name = "Attack range",
	    Min = 1,
	    Max = 13,
	    Default = 13,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	AngleSlider = Killaura:CreateSlider({
	    Name = "Max angle",
	    Min = 1,
	    Max = 360,
	    Default = 90
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
	local Speed
	local Value
	local AutoJump
	local AutoJumpCustom
	local AutoJumpValue
	
	Speed = vape.Categories.Blatant:CreateModule({
	    Name = "Speed",
	    Function = function(Callback: boolean)
	        if Callback then
	            if not AnticheatBypass.Enabled then
	                AnticheatBypass:Toggle()
	            end
	
	            Speed:Clean(RunService.PreSimulation:Connect(function(Delta: number)
	                if Entity.isAlive and not Fly.Enabled then
	                    local State: Enum.HumanoidStateType = Entity.character.Humanoid:GetState()
	                    if State == Enum.HumanoidStateType.Climbing then
	                        return
	                    end
	                    ApplySpeed(Value.Value, Delta)
	
	                    if AutoJump.Enabled and Entity.character.Humanoid.FloorMaterial ~= Enum.Material.Air and Entity.character.Humanoid.MoveDirection ~= Vector3.zero then
	                        if AutoJumpCustom.Enabled then
	                            local Velocity: Vector3 = Entity.character.RootPart.Velocity * Vector3.new(1, 0, 1)
	                            Entity.character.RootPart.Velocity = Vector3.new(Velocity.X, AutoJumpValue.Value, Velocity.Z)
	                        else
	                            Entity.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	                        end
	                    end
	                end
	            end))
	        end
	    end,
	    ExtraText = function()
	        return "BlockWars"
	    end,
	    Tooltip = "Increases your movement with various methods."
	})
	Value = Speed:CreateSlider({
	    Name = "Speed",
	    Min = 1,
	    Max = 38,
	    Default = 38,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	AutoJump = Speed:CreateToggle({
	    Name = "AutoJump",
	    Function = function(Callback: boolean)
	        AutoJumpCustom.Object.Visible = Callback
	    end
	})
	AutoJumpCustom = Speed:CreateToggle({
	    Name = "Custom Jump",
	    Function = function(Callback: boolean)
	        AutoJumpValue.Object.Visible = Callback
	    end,
	    Tooltip = "Allows you to adjust the jump power",
	    Darker = true,
	    Visible = false
	})
	AutoJumpValue = Speed:CreateSlider({
	    Name = "Jump Power",
	    Min = 1,
	    Max = 50,
	    Default = 30,
	    Darker = true,
	    Visible = false
	})
end)

Run(function()
	local AutoLeave
	
	AutoLeave = vape.Categories.Utility:CreateModule({
	    Name = "AutoLeave",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoLeave:Clean(Blockwars.RemoteIndex.Victory_Show.OnClientEvent:Connect(function()
	                ReplicatedStorage.GameEvents.BedWarsRemotes.Return_To_Lobby:FireServer()
	            end))
	        end
	    end,
	    Tooltip = "Automatically leave after the match ends."
	})
end)

Run(function()
	local AutoQueue
	
	AutoQueue = vape.Categories.Utility:CreateModule({
	    Name = "AutoQueue",
	    Function = function(Callback: boolean)
	        if Callback then
	            if workspace:GetAttribute("ServerType") == "Lobby" then
	                task.spawn(function()
	                    Blockwars.RemoteIndex.Matchmaking_Request:InvokeServer("queue")
	                end)
	            end
	        end
	    end,
	    Tooltip = "Automatically queue in the lobby."
	})
end)

Run(function()
	local AutoToxic
	local GG
	local Toggles, Lists, Cloned, Presets = {}, {}, {}, {}
	
	local function SendMessage(Name: string, Object: string?, Default: string?)
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
	            AutoToxic:Clean(Blockwars.RemoteIndex.Round_Event.OnClientEvent:Connect(function(Data)
	                if type(Data) == "table" and Data.id == "final_kill" then
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
	
	                    if LocalPlayer.Team and LocalPlayer.Team.Name == Data.teamId then
	                        if Toggles.Win.Enabled then
	                            SendMessage("Win", nil, "yall garbage")
	                        end
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
	local Breaker
	local Range
	local BreakSpeed
	local UpdateRate
	local Custom
	local Bed
	local LuckyBlock
	local IronOre
	local Effect
	local CustomHealth = {}
	local Animation
	local SelfBreak
	local InstantBreak
	local LimitItem
	local CustomList, Parts = {}, {}
	
	local function GetPick()
	    local Inventory: {Instance} = GetInventory()
	    for _, Tool: Instance in Inventory do
	        if Tool:GetAttribute("Tier") then
	            return Tool
	        end
	    end
	end
	
	local function AttemptBreak(List, LocalPosition: Vector3, Tool: Tool): boolean?
	    if not List then
	        return
	    end
	    for _, v: BasePart in List do
	        if (v.Position - LocalPosition).Magnitude < Range.Value and v:GetAttribute("BedTeamId") ~= (LocalPlayer.Team and LocalPlayer.Team.Name or "") and (v:GetAttribute("HP") or 10) > 0 then
	            if Tool.Parent ~= LocalPlayer.Character then
	                Entity.character.Humanoid:EquipTool(Tool)
	            end
	
	            if v:HasTag("BedWarsX_BedSpawn") then
	                local NotCovered: boolean = false
	                for _, Normal: Enum.NormalId in Enum.NormalId:GetEnumItems() do
	                    if Normal ~= Enum.NormalId.Bottom then
	                        if not Blocks[v.Position // 3 + Vector3.fromNormalId(Normal)] then
	                            NotCovered = true
	                            break
	                        end
	                    end
	                end
	
	                if NotCovered then
	                    Blockwars.RemoteIndex.Block_AttemptHit:FireServer({
	                        camPos = LocalPosition,
	                        hitPos = v:GetClosestPointOnSurface(LocalPosition),
	                        blockInstance = v
	                    })
	                else
	                    local AboveBlock = Blocks[v.Position // 3 + Vector3.new(0, 1, 0)]
	
	                    if AboveBlock then
	                        Blockwars.RemoteIndex.Block_AttemptHit:FireServer({
	                            camPos = LocalPosition,
	                            hitPos = AboveBlock:GetClosestPointOnSurface(LocalPosition),
	                            blockInstance = AboveBlock
	                        })
	                    end
	                end
	
	                task.wait(0.15)
	            else
	                Blockwars.RemoteIndex.Mine_AttemptHit:FireServer(v)
	            end
	
	            task.wait(0.05)
	            return true
	        end
	    end
	
	    return false
	end
	
	Breaker = vape.Categories.World:CreateModule({
	    Name = "Breaker",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Beds = Collection("BedWarsX_BedSpawn", Breaker)
	            local Generators = Collection("BedWarsX_Resource", Breaker)
	
	            repeat
	                task.wait(1 / UpdateRate.Value)
	                if not Breaker.Enabled then
	                    break
	                end
	
	                local Tool = GetPick()
	                if Entity.isAlive and Tool and not IsAttacking then
	                    local LocalPosition: Vector3 = BypassRoot and BypassRoot.Position or Entity.character.RootPart.Position
	
	                    if AttemptBreak(Beds, LocalPosition, Tool) then
	                        continue
	                    end
	                    if AttemptBreak(Generators, LocalPosition, Tool) then
	                        continue
	                    end
	                end
	            until not Breaker.Enabled
	        end
	    end,
	    Tooltip = "Break blocks around you automatically"
	})
	Range = Breaker:CreateSlider({
	    Name = "Break range",
	    Min = 1,
	    Max = 12,
	    Default = 12,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	BreakSpeed = Breaker:CreateSlider({
	    Name = "Break speed",
	    Min = 0,
	    Max = 0.3,
	    Default = 0.25,
	    Decimal = 100,
	    Suffix = "seconds"
	})
	UpdateRate = Breaker:CreateSlider({
	    Name = "Update rate",
	    Min = 1,
	    Max = 120,
	    Default = 60,
	    Suffix = "hz"
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
	            Old = hookfunction(Blockwars.BlockBreakConstants.CooldownFor, function(...)
	                return Old(...) * (Value.Value / 100)
	            end)
	        else
	            if Old then
	                hookfunction(Blockwars.BlockBreakConstants.CooldownFor, Old)
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Allow you to swing the pickaxe faster."
	})
	Value = FastBreak:CreateSlider({
	    Name = "Break Speed Percent",
	    Min = 0,
	    Max = 100,
	    Default = 50,
	    Suffix = "%"
	})
end)

Run(function()
	local AutoBuy
	local Shops = {}
	local Requirements = {
	    armor = {
	        ["Leather Armor"] = "pickaxe_iron"
	    },
	    pickaxe = {
	        ["pickaxe_gold"] = "Golden Armor",
	        ["pickaxe_diamond"] = "Diamond Armor"
	    }
	}
	
	local function BuyCategory(Ladder: string, Default: boolean?): boolean
	    local TierItems = {}
	    for _, Item: any in Blockwars.ShopConfig.Items do
	        if Item.ladder == Ladder then
	            table.insert(TierItems, Item)
	        end
	    end
	
	    table.sort(TierItems, function(A, B)
	        return (A.tier or -1) < (B.tier or -1)
	    end)
	
	    local NextTier = Default and TierItems[1] or nil
	    for _, Item: any in TierItems do
	        if Blockwars.Inventory.items[Item.id] then
	            NextTier = TierItems[table.find(TierItems, Item) + 1]
	            break
	        end
	    end
	
	    if NextTier then
	        for i: number, Currency: string in {"Block", "Gold", "Diamond"} do
	            if (NextTier.cost and NextTier.cost[Currency] or 0) > (Blockwars.Inventory[i == 1 and "blocks" or Currency:lower()] or 0) then
	                return false
	            end
	        end
	
	        if Requirements[Ladder] and Requirements[Ladder][NextTier.id] and not Blockwars.Inventory.items[Requirements[Ladder][NextTier.id]] then
	            return false
	        end
	
	        Blockwars.RemoteIndex.Shop_Purchase:InvokeServer({itemId = NextTier.id})
	        return true
	    end
	
	    return false
	end
	
	AutoBuy = vape.Categories.Inventory:CreateModule({
	    Name = "AutoBuy",
	    Function = function(Callback: boolean)
	        if Callback then
	            Shops = Collection("BedWarsX_ShopNPC")
	
	            repeat
	                if Entity.isAlive then
	                    local LocalPosition: Vector3 = Entity.character.RootPart.Position
	                    for _, Shop: BasePart in Shops do
	                        if (Shop.Position - LocalPosition).Magnitude < 20 then
	                            if BuyCategory("armor", true) then
	                                break
	                            end
	                            if BuyCategory("pickaxe") then
	                                break
	                            end
	                            if BuyCategory("sword") then
	                                break
	                            end
	                            break
	                        end
	                    end
	                end
	
	                task.wait(0.2)
	            until not AutoBuy.Enabled
	        end
	    end,
	    Tooltip = "lol"
	})
end)

Run(function()
	local FixGUIs
	
	FixGUIs = vape.Legit:CreateModule({
	    Name = "FixGUIs",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_fixguis.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            local Guis = {LocalPlayer.PlayerGui:FindFirstChild("Team_UpgradesV3", true), LocalPlayer.PlayerGui:FindFirstChild("ItemShopV3", true)}
	            if #Guis < 2 then
	                repeat
	                    Guis = {LocalPlayer.PlayerGui:FindFirstChild("Team_UpgradesV3", true), LocalPlayer.PlayerGui:FindFirstChild("ItemShopV3", true)}
	                    task.wait()
	                until #Guis >= 2 or not FixGUIs.Enabled
	
	                if not FixGUIs.Enabled then
	                    return
	                end
	            end
	
	            local Visible: boolean = false
	            local Mouse: ImageLabel = Instance.new("ImageLabel")
	            Mouse.Size = UDim2.fromOffset(20, 20)
	            Mouse.Visible = false
	            Mouse.Parent = vape.gui
	            FixGUIs:Clean(Mouse)
	
	            for _, Gui: Instance? in Guis do
	                if Gui then
	                    for _, v: TextButton in Gui:QueryDescendants("TextButton") do
	                        local Ancestor: ScrollingFrame? = v:FindFirstAncestorWhichIsA("ScrollingFrame")
	                        if not Ancestor then
	                            v.Modal = true
	                        end
	                    end
	
	                    Visible = Visible or Gui.Visible
	                    FixGUIs:Clean(Gui:GetPropertyChangedSignal("Visible"):Connect(function()
	                        Visible = Gui.Visible
	                    end))
	                end
	            end
	
	            FixGUIs:Clean(RunService.Heartbeat:Connect(function()
	                local Location: Vector2 = UserInputService:GetMouseLocation()
	                Mouse.Visible = Visible
	                if Mouse.Visible then
	                    Mouse.Position = UDim2.fromOffset(Location.X, Location.Y)
	                end
	            end))
	        end
	    end,
	    Tooltip = "Fix GUI's in first person."
	})
end)

Run(function()
	local HideShield
	local Parts: {BasePart} = {}
	
	local function Added(Entity)
	    local Shield: Instance? = Entity.Character:WaitForChild("ShieldModel", 10)
	    if Shield then
	        Parts = Shield:QueryDescendants("BasePart")
	    end
	end
	
	HideShield = vape.Legit:CreateModule({
	    Name = "HideShield",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_hideshield.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            HideShield:Clean(Entity.Events.LocalAdded:Connect(Added))
	            if Entity.isAlive then
	                task.spawn(Added, Entity.character)
	            end
	
	            repeat
	                for _, v: BasePart in Parts do
	                    v.Transparency = 1
	                end
	
	                task.wait()
	            until not HideShield.Enabled
	        else
	            table.clear(Parts)
	        end
	    end,
	    Tooltip = "Hide the shield entirely."
	})
end)