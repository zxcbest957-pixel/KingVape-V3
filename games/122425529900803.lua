local Run = function(Func: () -> ())
    Func()
end
local cloneref = cloneref or function(Reference: Instance)
    return Reference
end

local CollectionService: CollectionService = cloneref(game:GetService("CollectionService"))
local ReplicatedStorage: ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService: RunService = cloneref(game:GetService("RunService"))
local TweenService: TweenService = cloneref(game:GetService("TweenService"))
local UserInputService: UserInputService = cloneref(game:GetService("UserInputService"))
local StarterPlayerScripts: StarterPlayerScripts = cloneref(game:GetService("StarterPlayer")).StarterPlayerScripts
local Players: Players = cloneref(game:GetService("Players"))

local Camera: Camera = workspace.CurrentCamera
local LocalPlayer: Player = Players.LocalPlayer
local PlayerScripts = LocalPlayer.PlayerScripts
local vape = shared.vape
local Entity = vape.Libraries.entity
local TargetInfo = vape.Libraries.targetinfo
local GetVapeAsset = vape.Libraries.getvapeasset

local function SendNotification(...)
    return vape:CreateNotification(...)
end

local Smear = {}
local function Equip(Tool: Tool, Legit: boolean?)
    if Legit then
        Entity.character.Humanoid:EquipTool(Tool)
        return
    end

    Tool.Parent = Entity.character.Character
end

local function GetItem(Item: string)
    for _, v: Instance in LocalPlayer.Backpack:GetChildren() do
        if v:GetAttribute("ItemId") == Item then
            return v, false
        end
    end
    if Entity.isAlive then
        local v: Tool? = LocalPlayer.Character:FindFirstChildOfClass("Tool")
        return (v and v:GetAttribute("ItemId") == Item and v or nil), true
    end
    return nil
end
local function SwitchItem(Item: Tool, Legit: boolean?)
    if Smear.WeaponRegistry[Item:GetAttribute("ItemId") or Item.Name] and not Legit then
        ReplicatedStorage.Events.CombatEvent:FireServer("ToolEquipped", nil, nil, Item:GetAttribute("ItemId") or Item.Name, {
            SourceCharacter = LocalPlayer.Character
        })
    else
        Equip(Item, Legit)
    end
end

local ChargeTimes: {[string]: number} = {}
local function GetCharge(Item: string): number
    if not ChargeTimes[Item] then
        local Config = Smear.WeaponConfigs.getConfig(Item)
        ChargeTimes[Item] = Config and Config.ChargeTime or 0
    end

    if ChargeTimes[Item] <= 0 then
        return 1
    end

    return math.clamp((tick() - Smear.ChargeState.GetClock().LastAttackTime) / ChargeTimes[Item], 0, 1)
end

local ViewmodelTool
local ViewmodelMotor

Run(function()
    Smear = {
        AnimationService = require(ReplicatedStorage.Shared.AnimationService),
        Net = require(ReplicatedStorage.Shared.Net),
        TankBlockEvent = ReplicatedStorage.Events.TankBlockEvent,
        GridUtil = require(ReplicatedStorage.Shared.GridUtil),
        ClientBlockBreakVisuals = require(StarterPlayerScripts.Client.ClientBlockBreakVisuals),
        OffhandEvent = ReplicatedStorage.Events.OffhandEvent,
        CombatEvent = ReplicatedStorage.Events.CombatEvent,
        SpearEvent = ReplicatedStorage.Events.SpearEvent,
        UseItemEvent = ReplicatedStorage.Events.UseItemEvent,
        KnockbackEvent = ReplicatedStorage.Events.KnockbackEvent,
        DownedEvent = ReplicatedStorage.Events.DownedEvent,
        CombatAirState = require(ReplicatedStorage.Shared.CombatAirState),
        LiquidRaycast = require(ReplicatedStorage.Shared.LiquidRaycast),
        ReviveMinigameConfig = require(ReplicatedStorage.Shared.ReviveMinigameConfig),
        PlayerKeybinds = require(PlayerScripts.Client.PlayerKeybinds),
        WeaponRegistry = debug.getupvalue(require(ReplicatedStorage.Shared.WeaponRegistry).create, 2),
        WeaponConfigs = require(ReplicatedStorage.Shared.WeaponRegistry),
        ChargeState = require(ReplicatedStorage.Shared.SharedWeaponChargeState)
    }
    Smear.BreakingEvent = Smear.Net.get("BreakingEvent")

    local Reporter, Old
    for _, v: any in getconnections(ReplicatedStorage.Events.RuntimeDiagnosticsEvent.OnClientEvent) do
        if v.Function and debug.getinfo(v.Function, "s").short_src:find("RuntimeDiagnostics") then
            Reporter = debug.getupvalue(v.Function, 1)
            Old = hookfunction(Reporter, function()
                vape:CreateNotification("Vape", "Blocked a detection attempt.", 7, "alert")
            end)
            break
        end
    end

    for _, v: Instance in workspace.Mobs:GetChildren() do
        Entity.addEntity(v)
    end
    vape:Clean(workspace.Mobs.ChildAdded:Connect(Entity.addEntity))
    vape:Clean(workspace.Mobs.ChildRemoved:Connect(Entity.removeEntity))
    vape:Clean(function()
        if Reporter then
            if restorefunction then
                restorefunction(Reporter)
            else
                hookfunction(Reporter, Old)
            end
        end

        table.clear(Smear)
    end)
end)

for _, v: string in {"SilentAim", "TriggerBot", "HighJump"} do
    vape:Remove(v)
end

Run(function()
	local Old
	
	vape.Categories.Combat:CreateModule({
	    Name = "Criticals",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
	                if self == Smear.CombatEvent and getnamecallmethod() == "FireServer" then
	                    local Data = select(5, ...)
	
	                    if type(Data) == "table" then
	                        Data.IsFalling = true
	                    end
	                end
	
	                return Old(self, ...)
	            end))
	        elseif Old then
	            hookmetamethod(game, "__namecall", Old)
	            Old = nil
	        end
	    end,
	    Tooltip = "Always hit criticals"
	})
end)

Run(function()
	local TriggerBot
	local Targets
	local ExtraDelay
	local Distance
	local Size
	local MouseDelay
	local SwitchDelay
	local AutoCharge
	local ShieldBreaker
	local Legit
	local Crit
	
	local LastTarget, MouseDeadline
	local InExtra, ExtraDeadline
	local InSwitch, SwitchDeadline
	
	local OverlapCheck: OverlapParams = OverlapParams.new()
	OverlapCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	local function GetEntity()
	    local Characters = {}
	    for _, v: any in Entity.List do
	        if v.Targetable and v.Character and (Targets.Players.Enabled and v.Player or Targets.NPCs.Enabled and v.NPC) and Entity.isVulnerable(v) then
	            Characters[v.Character] = v
	        end
	    end
	
	    OverlapCheck.FilterDescendantsInstances = {Entity.character.Character, Camera}
	
	    for _, v: BasePart in workspace:GetPartBoundsInBox(Camera.CFrame + Camera.CFrame.LookVector * (Distance.Value / 2), Vector3.new(Size.Value, Size.Value, Distance.Value), OverlapCheck) do
	        local Ent = Characters[v:FindFirstAncestorOfClass("Model")]
	
	        if Ent then
	            return Ent
	        end
	    end
	end
	
	TriggerBot = vape.Categories.Combat:CreateModule({
	    Name = "TriggerBot",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                task.wait()
	                if not Entity.isAlive then
	                    continue
	                end
	
	                local Target = GetEntity()
	                if not Target then
	                    LastTarget = nil
	                    continue
	                end
	
	                if LastTarget ~= Target then
	                    LastTarget = Target
	                    MouseDeadline = os.clock() + MouseDelay:GetRandomValue()
	                    InExtra = false
	                    continue
	                end
	
	                if not InExtra then
	                    if os.clock() >= MouseDeadline then
	                        InExtra = true
	                        ExtraDeadline = os.clock() + ExtraDelay:GetRandomValue()
	                    end
	                    continue
	                end
	
	                local Tool: Tool? = Entity.character.Character:FindFirstChildOfClass("Tool")
	                if not Tool then
	                    LastTarget = nil
	                    continue
	                end
	
	                if AutoCharge.Enabled and GetCharge(Tool:GetAttribute("ItemId") or Tool.Name) < 1 then
	                    continue
	                end
	
	                local Offhand = ShieldBreaker.Enabled and Target.Character:FindFirstChild("OffhandVisual")
	
	                if Offhand and Offhand:GetAttribute("ItemId") == "Shield" then
	                    if not InSwitch then
	                        InSwitch = true
	                        SwitchDeadline = os.clock() + SwitchDelay:GetRandomValue()
	                    end
	
	                    if os.clock() >= SwitchDeadline then
	                        local Axe, Equipped = GetItem("Axe")
	
	                        if Axe then
	                            if not Equipped then
	                                SwitchItem(Axe, Legit.Enabled)
	                            end
	
	                            local Held = Axe.Parent == Entity.character.Character and Axe or Tool
	                            Held:Activate()
	
	                            if Tool ~= Axe then
	                                SwitchItem(Tool, Legit.Enabled)
	                            end
	                        end
	
	                        InSwitch = false
	                    end
	                    continue
	                end
	
	                if Crit.Enabled and not Smear.CombatAirState.get(Entity.character.Character).IsDescending then
	                    continue
	                end
	                if os.clock() < ExtraDeadline then
	                    continue
	                end
	
	                Tool:Activate()
	                LastTarget = nil
	            until not TriggerBot.Enabled
	        else
	            LastTarget = nil
	            InExtra, InSwitch = false, false
	        end
	    end,
	    Tooltip = "Attacks whoever you aim at."
	})
	Targets = TriggerBot:CreateTargets({
	    Players = true,
	    NPCs = true
	})
	ExtraDelay = TriggerBot:CreateTwoSlider({
	    Name = "Extra Delay",
	    Min = 0,
	    Max = 1,
	    DefaultMin = 0.05,
	    DefaultMax = 0.125,
	    Decimal = 100
	})
	Distance = TriggerBot:CreateSlider({
	    Name = "Distance",
	    Min = 0,
	    Max = 32,
	    Default = 16
	})
	Size = TriggerBot:CreateSlider({
	    Name = "Size",
	    Min = 1,
	    Max = 32,
	    Default = 6
	})
	MouseDelay = TriggerBot:CreateTwoSlider({
	    Name = "Mouse Delay",
	    Min = 0,
	    Max = 1,
	    DefaultMin = 0.025,
	    DefaultMax = 0.05,
	    Decimal = 100
	})
	SwitchDelay = TriggerBot:CreateTwoSlider({
	    Name = "Switch Delay",
	    Min = 0,
	    Max = 1,
	    DefaultMin = 0.025,
	    DefaultMax = 0.075,
	    Decimal = 100
	})
	AutoCharge = TriggerBot:CreateToggle({
	    Name = "Auto Charge"
	})
	ShieldBreaker = TriggerBot:CreateToggle({
	    Name = "Shield Breaker"
	})
	Legit = TriggerBot:CreateToggle({
	    Name = "Legit Equip"
	})
	Crit = TriggerBot:CreateToggle({
	    Name = "Crits Only"
	})
end)

Run(function()
	local LumberTycoon
	local Mode
	local Range
	
	local GridSize: number = Smear.GridUtil.getGridSize()
	local GridBox: Vector3 = Vector3.new(GridSize * 0.5, GridSize * 0.5, GridSize * 0.5)
	local ScanHeight: number = 30000
	
	local OverlapCheck: OverlapParams = OverlapParams.new()
	OverlapCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	local function GetBlockId(Position: Vector3): string?
	    for _, v: BasePart in workspace:GetPartBoundsInBox(CFrame.new(Position), GridBox) do
	        local Id = v:GetAttribute("OriginalId") or v:GetAttribute("BlockId")
	        if type(Id) == "string" then
	            return Id
	        end
	    end
	end
	
	local function BreakBlock(Part: Instance)
	    if not Part:IsA("BasePart") then
	        return
	    end
	
	    if type(Part:GetAttribute("TankBlockId")) == "string" and type(Part:GetAttribute("TankAssemblyId")) == "string" then
	        Smear.ClientBlockBreakVisuals.beginDynamic(Part)
	        Smear.ClientBlockBreakVisuals.addDynamicProgress(Part, 9e9)
	        Smear.TankBlockEvent:FireServer("Mine", Part, 9e9)
	    elseif Part:GetAttribute("BlockId") or Part:GetAttribute("OriginalId") or Part:GetAttribute("Breakable") then
	        local Position: Vector3 = Smear.GridUtil.snapToGrid(Part.Position)
	
	        if GetBlockId(Position) then
	            Smear.ClientBlockBreakVisuals.begin(Position)
	            Smear.ClientBlockBreakVisuals.addProgress(Position, 9e9)
	            Smear.BreakingEvent:FireServer(Position, 9e9)
	        end
	    end
	end
	
	LumberTycoon = vape.Categories.Blatant:CreateModule({
	    Name = "👺",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                task.wait(0.05)
	                if Entity.isAlive then
	                    if Mode.Value == "Normal" then
	                        for _, v: BasePart in workspace:GetPartBoundsInRadius(Entity.character.RootPart.Position, Range.Value) do
	                            BreakBlock(v)
	                        end
	                    else
	                        local Center: Vector3 = Entity.character.RootPart.Position - Vector3.new(0, ScanHeight * 0.5, 0)
	                        local Size: Vector3 = Vector3.new(Range.Value, ScanHeight, Range.Value)
	                        OverlapCheck.FilterDescendantsInstances = {Entity.character.Character}
	
	                        for _, v: BasePart in workspace:GetPartBoundsInBox(CFrame.new(Center), Size, OverlapCheck) do
	                            BreakBlock(v)
	                        end
	                    end
	                end
	
	                Smear.ClientBlockBreakVisuals.clear()
	                Smear.ClientBlockBreakVisuals.clearDynamic()
	            until not LumberTycoon.Enabled
	        end
	    end,
	    Tooltip = "Instantly breaks every block around you."
	})
	Mode = LumberTycoon:CreateDropdown({
	    Name = "Mode",
	    List = {"Normal", "Stabshot"}
	})
	Range = LumberTycoon:CreateSlider({
	    Name = "Range",
	    Min = 0,
	    Max = 100,
	    Default = 20
	})
end)

Run(function()
	local Fly
	local Speed
	local VerticalSpeed
	
	local Up, Down = 0, 0
	local ChargeTime: number = 0
	local Launched: boolean = false
	local Freeze, FreezeTime
	local OldFriction: {[BasePart]: PhysicalProperties | string} = {}
	
	local TeleportHeight: number = 10
	local HoverSpeed: number = 2.25
	local ChargeDelay: number = 0.5
	local EquipDelay: number = 0.05
	local LaunchTimeout: number = 0.5
	local BounceLength: number = 40
	local BounceDelay: number = 0.4
	local GroundDirection: Vector3 = Vector3.new(0, -7, 0)
	
	local GroundCheck: RaycastParams = RaycastParams.new()
	GroundCheck.RespectCanCollide = true
	
	local function ApplyFriction()
	    for _, v: Instance in Entity.character.Character:GetChildren() do
	        if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" and not OldFriction[v] then
	            OldFriction[v] = v.CustomPhysicalProperties or "none"
	            v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
	        end
	    end
	end
	
	local function Launch()
	    local Charge, Equipped = GetItem("WindCharge")
	    if not Charge then
	        return
	    end
	
	    local Old: Tool? = Entity.character.Character:FindFirstChildOfClass("Tool")
	    if not Equipped then
	        SwitchItem(Charge)
	        task.wait(EquipDelay)
	
	        if not Entity.isAlive then
	            return
	        end
	    end
	
	    Launched = false
	    Freeze, FreezeTime = Entity.character.RootPart.Position, os.clock() + LaunchTimeout
	    Smear.UseItemEvent:FireServer("WindCharge", (Entity.character.Head or Entity.character.RootPart).Position, Vector3.new(0, -1, 0), Charge:GetAttribute("SelectedInventoryStackKey"))
	
	    repeat
	        task.wait()
	    until Launched or not Freeze or not Fly.Enabled or not Entity.isAlive
	    Freeze = nil
	
	    if not Entity.isAlive then
	        return
	    end
	
	    if Launched then
	        Entity.character.RootPart.CFrame += Vector3.new(0, TeleportHeight, 0)
	    end
	
	    if Old and Old ~= Charge and Old.Parent then
	        SwitchItem(Old)
	    end
	end
	
	Fly = vape.Categories.Blatant:CreateModule({
	    Name = "Fly",
	    Function = function(Callback: boolean)
	        if Callback then
	            Up = UserInputService:IsKeyDown(Enum.KeyCode.Space) and 1 or 0
	            Down = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and -1 or 0
	
	            if Entity.isAlive then
	                ApplyFriction()
	            end
	
	            Fly:Clean(Entity.Events.LocalAdded:Connect(ApplyFriction))
	
	            Fly:Clean(Smear.KnockbackEvent.OnClientEvent:Connect(function()
	                Launched = true
	                Freeze = nil
	            end))
	
	            Fly:Clean(RunService.PreSimulation:Connect(function(Delta: number)
	                if not Entity.isAlive then
	                    return
	                end
	
	                local Root: BasePart = Entity.character.RootPart
	
	                if Freeze then
	                    if os.clock() < FreezeTime then
	                        Root.CFrame = CFrame.lookAlong(Freeze, Root.CFrame.LookVector)
	                        Root.AssemblyLinearVelocity = Vector3.zero
	                        return
	                    end
	
	                    Freeze = nil
	                end
	
	                GroundCheck.FilterDescendantsInstances = {Entity.character.Character, Camera}
	                GroundCheck.CollisionGroup = Root.CollisionGroup
	
	                local Bounce: number = ((tick() % BounceDelay) / BounceDelay > 0.5 and 1 or -1) * BounceLength
	                local Move: Vector3 = Entity.character.Humanoid.MoveDirection * Speed.Value * Delta
	                local Ray: RaycastResult? = workspace:Raycast(Root.Position, Move, GroundCheck)
	
	                Root.CFrame += Ray and ((Ray.Position + Ray.Normal) - Root.Position) or Move
	                Root.AssemblyLinearVelocity = Vector3.new(0, HoverSpeed + ((Up + Down) * VerticalSpeed.Value) + Bounce, 0)
	
	                if os.clock() < ChargeTime then
	                    return
	                end
	
	                if not workspace:Raycast(Root.Position, GroundDirection, GroundCheck) then
	                    return
	                end
	
	                ChargeTime = os.clock() + ChargeDelay
	                task.spawn(Launch)
	            end))
	
	            for _, v: string in {"InputBegan", "InputEnded"} do
	                Fly:Clean(UserInputService[v]:Connect(function(Input: InputObject)
	                    if UserInputService:GetFocusedTextBox() then
	                        return
	                    end
	
	                    if Input.KeyCode == Enum.KeyCode.Space then
	                        Up = v == "InputBegan" and 1 or 0
	                    elseif Input.KeyCode == Enum.KeyCode.LeftShift then
	                        Down = v == "InputBegan" and -1 or 0
	                    end
	                end))
	            end
	        else
	            for Part: BasePart, v: PhysicalProperties | string in OldFriction do
	                Part.CustomPhysicalProperties = v ~= "none" and v or nil
	            end
	
	            table.clear(OldFriction)
	            Up, Down = 0, 0
	            ChargeTime = 0
	            Freeze = nil
	            Launched = false
	        end
	    end,
	    Tooltip = "Makes you go zoom, space & leftshift to go up and down."
	})
	Speed = Fly:CreateSlider({
	    Name = "Speed",
	    Min = 1,
	    Max = 150,
	    Default = 50,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	VerticalSpeed = Fly:CreateSlider({
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
	local Height
	local Speed
	
	local Launched, Climbing = false, false
	local StartY: number = 0
	local Freeze, FreezeTime
	
	local EquipDelay: number = 0.05
	local LaunchTimeout: number = 2
	
	local function Launch()
	    local Charge, Equipped = GetItem("WindCharge")
	    if not Charge then
	        SendNotification("HighJump", "No windcharge found", 8, "warning")
	        return
	    end
	
	    local Old: Tool? = Entity.character.Character:FindFirstChildOfClass("Tool")
	    if not Equipped then
	        SwitchItem(Charge, true)
	        task.wait(EquipDelay)
	
	        if not Entity.isAlive then
	            return
	        end
	    end
	
	    Launched = false
	    Freeze, FreezeTime = Entity.character.RootPart.Position, os.clock() + LaunchTimeout
	    Smear.UseItemEvent:FireServer("WindCharge", Entity.character.RootPart.Position, Vector3.new(0, -1, 0), Charge:GetAttribute("SelectedInventoryStackKey"))
	
	    repeat
	        task.wait()
	    until Launched or not Freeze or not HighJump.Enabled or not Entity.isAlive
	    Freeze = nil
	
	    if not Entity.isAlive then
	        return
	    end
	
	    if Old and Old ~= Charge and Old.Parent then
	        SwitchItem(Old, true)
	    end
	
	    return Launched
	end
	
	HighJump = vape.Categories.Blatant:CreateModule({
	    Name = "HighJump",
	    Function = function(Callback: boolean)
	        if Callback then
	            if not Entity.isAlive then
	                HighJump:Toggle()
	                return
	            end
	
	            StartY = Entity.character.RootPart.Position.Y
	            Climbing = false
	
	            HighJump:Clean(Smear.KnockbackEvent.OnClientEvent:Connect(function()
	                Launched, Climbing = true, true
	                Freeze = nil
	            end))
	
	            HighJump:Clean(RunService.PreSimulation:Connect(function()
	                if not Entity.isAlive then
	                    return
	                end
	
	                local Root: BasePart = Entity.character.RootPart
	
	                if Freeze then
	                    if os.clock() < FreezeTime then
	                        Root.CFrame = CFrame.lookAlong(Freeze, Root.CFrame.LookVector)
	                        Root.AssemblyLinearVelocity = Vector3.zero
	                        return
	                    end
	
	                    Freeze = nil
	                end
	
	                if not Climbing then
	                    return
	                end
	
	                if Root.Position.Y - StartY >= Height.Value then
	                    HighJump:Toggle()
	                    return
	                end
	
	                Root.AssemblyLinearVelocity = Vector3.new(Root.AssemblyLinearVelocity.X, Speed.Value, Root.AssemblyLinearVelocity.Z)
	            end))
	
	            task.spawn(function()
	                if not Launch() and HighJump.Enabled then
	                    HighJump:Toggle()
	                end
	            end)
	        else
	            Freeze = nil
	            Launched, Climbing = false, false
	        end
	    end,
	    Tooltip = "Rides a wind charge straight up."
	})
	Height = HighJump:CreateSlider({
	    Name = "Height",
	    Min = 10,
	    Max = 150,
	    Default = 50,
	    Suffix = "studs"
	})
	Speed = HighJump:CreateSlider({
	    Name = "Speed",
	    Min = 1,
	    Max = 150,
	    Default = 50,
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
	local Speed
	local Mouse
	local Legit
	local AutoCharge
	local ShieldBreaker
	local BoxColor
	local Face
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	
	local Animations, ArmC0, ActiveTween = vape.Libraries.auraanims
	local Attacking: boolean = false
	local Boxes: {BoxHandleAdornment} = {}
	local AttackDelay = setmetatable({}, {__mode = "k"})
	
	local function GetWeapon(): Tool?
	    local Tool: Tool? = Entity.character.Character:FindFirstChildOfClass("Tool")
	    if Tool and Smear.WeaponRegistry[Tool:GetAttribute("ItemId") or Tool.Name] then
	        return Tool
	    end
	
	    for _, v: Instance in LocalPlayer.Backpack:GetChildren() do
	        if Smear.WeaponRegistry[v:GetAttribute("ItemId") or v.Name] then
	            return v
	        end
	    end
	end
	
	local function GetHitbox(Character: Model): BasePart?
	    for _, v: Instance in Character:GetChildren() do
	        if v:IsA("BasePart") and (CollectionService:HasTag(v, "CombatHitbox") or CollectionService:HasTag(v, "PlayerHitbox")) then
	            return v
	        end
	    end
	    return Character:FindFirstChild("HumanoidRootPart")
	end
	
	Killaura = vape.Categories.Blatant:CreateModule({
	    Name = "Killaura",
	    Function = function(Callback: boolean)
	        if Callback then
	            if Animation.Enabled then
	                task.spawn(function()
	                    local Started: boolean = false
	
	                    repeat
	                        local Motor = ViewmodelMotor
	
	                        if Motor then
	                            if Attacking and not Started then
	                                local First: boolean = not Started
	
	                                if First then
	                                    ArmC0 = Motor.C0
	                                end
	
	                                Started = true
	
	                                if AnimationMode.Value == "Random" then
	                                    Animations.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
	                                end
	
	                                for _, v: {CFrame: CFrame, Time: number} in Animations[AnimationMode.Value] do
	                                    ActiveTween = TweenService:Create(Motor, TweenInfo.new(First and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
	                                        C0 = ArmC0 * v.CFrame
	                                    })
	                                    ActiveTween:Play()
	                                    ActiveTween.Completed:Wait()
	                                    First = false
	
	                                    if not Killaura.Enabled or not Attacking then
	                                        break
	                                    end
	                                end
	                            elseif Started then
	                                Started = false
	                                ActiveTween = TweenService:Create(Motor, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
	                                    C0 = ArmC0
	                                })
	                                ActiveTween:Play()
	                            end
	                        end
	
	                        if not Started then
	                            task.wait(1 / 60)
	                        end
	                    until not Killaura.Enabled or not Animation.Enabled
	                end)
	            end
	
	            repeat
	                task.wait(0.016)
	                local Attacked = {}
	
	                if Entity.isAlive and not (Mouse.Enabled and not UserInputService:IsMouseButtonPressed(0)) then
	                    local Tool: Tool? = GetWeapon()
	
	                    if Tool then
	                        local LocalPosition: Vector3 = Entity.character.RootPart.Position
	                        local Facing: Vector3 = Entity.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	                        local Charge: number = GetCharge(Tool:GetAttribute("ItemId") or Tool.Name)
	                        local State = Smear.CombatAirState.get(Entity.character.Character)
	                        local Item: string = Tool:GetAttribute("ItemId") or Tool.Name
	
	                        for _, v: any in Entity.AllPosition({
	                            Range = AttackRange.Value,
	                            Wallcheck = Targets.Walls.Enabled or nil,
	                            Part = "RootPart",
	                            Players = Targets.Players.Enabled,
	                            NPCs = Targets.NPCs.Enabled,
	                            Priority = Targets.Priority.Value,
	                            Limit = Max.Value
	                        }) do
	                            local Delta: Vector3 = (v.RootPart.Position - LocalPosition) * Vector3.new(1, 0, 1)
	                            if Delta.Magnitude > 0 and math.acos(math.clamp(Facing.Unit:Dot(Delta.Unit), -1, 1)) > (math.rad(AngleSlider.Value) / 2) then
	                                continue
	                            end
	
	                            table.insert(Attacked, v)
	                            TargetInfo.Targets[v] = tick() + 1
	
	                            local Hitbox: BasePart? = GetHitbox(v.Character)
	                            if not Hitbox then
	                                continue
	                            end
	
	                            local Weapon, WeaponItem, WeaponCharge = Tool, Item, Charge
	
	                            local Offhand = ShieldBreaker.Enabled and v.Character:FindFirstChild("OffhandVisual")
	
	                            if Offhand and Offhand:GetAttribute("ItemId") == "Shield" then
	                                local Axe = GetItem("Axe")
	
	                                if Axe then
	                                    Weapon = Axe
	                                    WeaponItem = Axe:GetAttribute("ItemId") or Axe.Name
	                                    WeaponCharge = GetCharge(WeaponItem)
	                                end
	                            end
	
	                            if (AutoCharge.Enabled and WeaponCharge < 1) or not AutoCharge.Enabled and os.clock() - (AttackDelay[v.Character] or 0) < (1 / Speed.Value) then
	                                continue
	                            end
	                            AttackDelay[v.Character] = os.clock()
	
	                            if Weapon.Parent ~= Entity.character.Character and (Legit.Enabled or Weapon ~= Tool) then
	                                SwitchItem(Weapon, true)
	                            end
	
	                            if AutoCharge.Enabled then
	                                Smear.ChargeState.GetClock().LastAttackTime = tick()
	                            end
	
	                            Smear.CombatEvent:FireServer(v.Humanoid, Hitbox, WeaponCharge, WeaponItem, {
	                                SourceCharacter = Entity.character.Character,
	                                IsFalling = State.IsDescending
	                            })
	
	                            if Weapon ~= Tool then
	                                SwitchItem(Tool, true)
	                            end
	                        end
	
	                        if Face.Enabled and Attacked[1] then
	                            local Root: BasePart = Entity.character.RootPart
	                            local TargetPosition: Vector3 = Attacked[1].RootPart.Position
	                            Root.CFrame = CFrame.lookAt(Root.Position, Vector3.new(TargetPosition.X, Root.Position.Y + 0.01, TargetPosition.Z))
	                        end
	                    end
	                end
	
	                if vape.ThreadFix then
	                    setthreadidentity(8)
	                end
	                Attacking = Attacked[1] ~= nil
	
	                for i: number, v: BoxHandleAdornment in Boxes do
	                    v.Adornee = Attacked[i] and Attacked[i].RootPart or nil
	                    v.Color3 = Color3.fromHSV(BoxColor.Hue, BoxColor.Sat, BoxColor.Value)
	                    v.Transparency = 1 - BoxColor.Opacity
	                end
	            until not Killaura.Enabled
	        else
	            Attacking = false
	
	            local Motor = ArmC0 and ViewmodelMotor
	
	            if Motor then
	                ActiveTween = TweenService:Create(Motor, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
	                    C0 = ArmC0
	                })
	                ActiveTween:Play()
	            end
	
	            for _, v: BoxHandleAdornment in Boxes do
	                v.Adornee = nil
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
	    Max = 32,
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
	Speed = Killaura:CreateSlider({
	    Name = "Attack speed",
	    Min = 1,
	    Max = 20,
	    Default = 12,
	    Suffix = "cps"
	})
	Max = Killaura:CreateSlider({
	    Name = "Max targets",
	    Min = 1,
	    Max = 10,
	    Default = 10
	})
	Mouse = Killaura:CreateToggle({Name = "Require mouse down"})
	Legit = Killaura:CreateToggle({Name = "Legit Switch"})
	ShieldBreaker = Killaura:CreateToggle({
	    Name = "Shield Breaker",
	    Tooltip = "Swap to your axe for targets that are blocking."
	})
	AutoCharge = Killaura:CreateToggle({
	    Name = "Auto Charge",
	    Tooltip = "Wait for a full charge before swinging so every hit deals full damage."
	})
	Face = Killaura:CreateToggle({Name = "Face target"})
	Animation = Killaura:CreateToggle({
	    Name = "Custom Animation",
	    Function = function(Callback: boolean)
	        AnimationMode.Object.Visible = Callback
	        AnimationSpeed.Object.Visible = Callback
	        AnimationTween.Object.Visible = Callback
	
	        if Killaura.Enabled then
	            Killaura:Toggle()
	            Killaura:Toggle()
	        end
	    end
	})
	Killaura:CreateToggle({
	    Name = "Show target",
	    Function = function(Callback: boolean)
	        if BoxColor then
	            BoxColor.Object.Visible = Callback
	        end
	
	        if Callback then
	            if vape.ThreadFix then
	                setthreadidentity(8)
	            end
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
	BoxColor = Killaura:CreateColorSlider({
	    Name = "Target Color",
	    Darker = true,
	    DefaultOpacity = 0.5,
	    Visible = false
	})
	local AnimationNames: {string} = {"Normal"}
	for Name: string in Animations do
	    if Name ~= "Normal" then
	        table.insert(AnimationNames, Name)
	    end
	end
	AnimationMode = Killaura:CreateDropdown({
	    Name = "Animation Mode",
	    List = AnimationNames,
	    Darker = true,
	    Visible = false
	})
	AnimationSpeed = Killaura:CreateSlider({
	    Name = "Animation Speed",
	    Min = 0,
	    Max = 2,
	    Default = 1,
	    Decimal = 10,
	    Darker = true,
	    Visible = false
	})
	AnimationTween = Killaura:CreateToggle({
	    Name = "No Tween",
	    Darker = true,
	    Visible = false
	})
end)

Run(function()
	local LongJump
	local Value
	local AutoDisable
	local Old
	
	local JumpTick, JumpSpeed = tick(), 0
	local FreezeTick, JumpTimeout = 0, 2
	local Methods = {
	    WindCharge = function()
	        if Entity.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
	            local Item, Equipped = GetItem("WindCharge")
	            if not Item then
	                SendNotification("LongJump", "No windcharge found", 8, "warning")
	                return false
	            end
	            if not Equipped then
	                SwitchItem(Item, true)
	            end
	            Smear.UseItemEvent:FireServer("WindCharge", Entity.character.RootPart.Position, Vector3.new(0, -1, 0), Item:GetAttribute("SelectedInventoryStackKey"))
	
	            local Launched: boolean = false
	            local Connection: RBXScriptConnection = ReplicatedStorage.Events.KnockbackEvent.OnClientEvent:Connect(function()
	                Launched = true
	            end)
	
	            local Timeout: number = tick() + JumpTimeout
	            repeat
	                task.wait()
	            until Launched or tick() >= Timeout or not LongJump.Enabled or not Entity.isAlive
	            Connection:Disconnect()
	
	            if not Launched then
	                return false
	            end
	
	            Entity.character.RootPart.AssemblyLinearVelocity = Vector3.zero
	            JumpTick, JumpSpeed = tick() + 3, Value.Value
	            return true
	        end
	        return false
	    end
	}
	
	LongJump = vape.Categories.Blatant:CreateModule({
	    Name = "LongJump",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = LocalPlayer.Character:FindFirstChildOfClass("Tool")
	            local Start: Vector3? = Entity.isAlive and Entity.character.RootPart.Position or nil
	            FreezeTick = tick() + JumpTimeout
	            task.spawn(function()
	                local Success: boolean = false
	                for _, v: () -> boolean in Methods do
	                    if v() then
	                        Success = true
	
	                        if Old then
	                            SwitchItem(Old, true)
	                        end
	                        break
	                    end
	                end
	                if not Success then
	                    SendNotification("LongJump", "Couldn't find a compatible item to longjump", 8, "info")
	                    LongJump:Toggle()
	                end
	            end)
	            local Direction: Vector3 = Entity.character.RootPart.CFrame.LookVector
	            LongJump:Clean(RunService.PreSimulation:Connect(function(Delta: number)
	                local Root: BasePart? = Entity.isAlive and Entity.character.RootPart or nil
	
	                if Root then
	                    if JumpTick > tick() then
	                        local Destination: Vector3 = (Direction * math.max(((JumpTick - tick()) > 1.1 and JumpSpeed or 0), 0) * Delta) * Vector3.new(1, 0, 1)
	                        local Velocity: number = tick() > (JumpTick - 1.1) and -25 or 15
	                        Root.CFrame += Destination
	                        Root.AssemblyLinearVelocity = (Direction * (tick() > JumpTick and 32 or JumpSpeed)) + Vector3.new(0, Velocity, 0)
	                        Start = nil
	                    else
	                        if Start then
	                            if tick() < FreezeTick then
	                                Root.CFrame = CFrame.lookAlong(Start, Root.CFrame.LookVector)
	                                Root.AssemblyLinearVelocity = Vector3.zero
	                            else
	                                Start = nil
	                            end
	                        end
	                        JumpSpeed = 0
	                    end
	                else
	                    Start = nil
	                end
	            end))
	        else
	            JumpTick, JumpSpeed = tick(), 0
	            FreezeTick = 0
	            if Old then
	                if Entity.isAlive then
	                    SwitchItem(Old, true)
	                end
	                Old = nil
	            end
	        end
	    end,
	    ExtraText = function()
	        return "wemmbu bypaass"
	    end,
	    Tooltip = "Lets you jump farther"
	})
	Value = LongJump:CreateSlider({
	    Name = "Jump Speed",
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
	local NoFall
	
	local RayParams: RaycastParams = RaycastParams.new()
	
	NoFall = vape.Categories.Blatant:CreateModule({
	    Name = "NoFall",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Tracked, ExtraGravity = 0, 0
	            NoFall:Clean(RunService.PreSimulation:Connect(function(Delta: number)
	                if Entity.isAlive then
	                    local Root: BasePart = Entity.character.RootPart
	                    if Root.AssemblyLinearVelocity.Y < -40 then
	                        RayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
	                        RayParams.CollisionGroup = Root.CollisionGroup
	
	                        local RootSize: number = Root.Size.Y / 2.5 + Entity.character.HipHeight
	                        local Ray: RaycastResult? = workspace:Blockcast(Root.CFrame, Vector3.new(3, 3, 3), Vector3.new(0, (Tracked * 0.1) - RootSize, 0), RayParams)
	                        if not Ray then
	                            Root.AssemblyLinearVelocity = Vector3.new(Root.AssemblyLinearVelocity.X, -41, Root.AssemblyLinearVelocity.Z)
	                            Root.CFrame = Root.CFrame + Vector3.new(0, ExtraGravity * Delta, 0)
	                            ExtraGravity = ExtraGravity + -workspace.Gravity * Delta
	                        end
	                    else
	                        ExtraGravity = 0
	                    end
	                end
	            end))
	        end
	    end,
	    Tooltip = "Prevents you from taking fall damage."
	})
end)

Run(function()
	local AutoMace
	local Targets
	local Distance
	local Spoof
	local FallDistance
	local OnlyFall
	local Aim
	local Delay
	local Max
	
	local MaceRange: number = 16
	local MinFallDistance: number = 6
	local LandedWindow: number = 0.25
	local AttackInterval: number = 0.25
	local SmashAnimation: string = "rbxassetid://90330371628268"
	
	local Attempt: number = 0
	local Ready: boolean = false
	local LastAttack: number = 0
	local StartY, CurrentFallDistance = 0, 0
	local LastFall, LastFallSpeed, LastFallTime = 0, 0, -math.huge
	local InDelay, DelayTime = false, 0
	
	local RayCheck: RaycastParams = RaycastParams.new()
	RayCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	local function SetReady(State: boolean)
	    if Ready == State then
	        return
	    end
	
	    Ready = State
	    Smear.CombatEvent:FireServer("SetMaceSmashReady", State, nil, "Mace", {
	        SourceCharacter = Entity.character.Character
	    })
	end
	
	local function SampleMiss(Origin: CFrame, Data)
	    local Ignore: {Instance} = {Entity.character.Character}
	    for _, v: string in {"Effects", "Pickups"} do
	        local Folder: Instance? = workspace:FindFirstChild(v)
	
	        if Folder then
	            table.insert(Ignore, Folder)
	        end
	    end
	
	    local Direction: Vector3 = Origin.LookVector * MaceRange
	    Data.SmashMissRayOrigin = Origin.Position
	    Data.SmashMissTipPosition = Origin.Position + Direction
	
	    for _ = 1, 8 do
	        RayCheck.FilterDescendantsInstances = Ignore
	
	        local Ray: RaycastResult? = workspace:Raycast(Origin.Position, Direction, RayCheck)
	        if not Ray then
	            return
	        end
	
	        local Model: Model? = Ray.Instance:FindFirstAncestorOfClass("Model")
	        if not CollectionService:HasTag(Ray.Instance, "CombatHitbox") and not CollectionService:HasTag(Ray.Instance, "PlayerHitbox") and not Smear.LiquidRaycast.isLiquidPart(Ray.Instance) and not (Model and Model:FindFirstChildWhichIsA("Humanoid")) and (Ray.Instance:GetAttribute("BlockId") or Ray.Instance:GetAttribute("OriginalId") or Ray.Instance:GetAttribute("Breakable")) then
	            Data.SmashMissImpactPosition = Ray.Position
	            Data.SmashMissImpactIsBlock = true
	            return
	        end
	
	        table.insert(Ignore, Model or Ray.Instance)
	    end
	end
	
	local function GetHitbox(Character: Model): BasePart?
	    for _, v: Instance in Character:GetChildren() do
	        if v:IsA("BasePart") and (CollectionService:HasTag(v, "CombatHitbox") or CollectionService:HasTag(v, "PlayerHitbox")) then
	            return v
	        end
	    end
	    return Character:FindFirstChild("HumanoidRootPart")
	end
	
	AutoMace = vape.Categories.Utility:CreateModule({
	    Name = "AutoMace",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                task.wait()
	                if not Entity.isAlive then
	                    continue
	                end
	
	                local Mace: Tool? = Entity.character.Character:FindFirstChildWhichIsA("Tool")
	                if not Mace or Mace.Name ~= "Mace" or LocalPlayer:GetAttribute("IsBlocking") then
	                    SetReady(false)
	                    continue
	                end
	
	                local State = Smear.CombatAirState.get(Entity.character.Character)
	                local Position: Vector3 = Entity.character.RootPart.Position
	
	                if State.IsAirborne then
	                    StartY = math.max(StartY, Position.Y)
	                    CurrentFallDistance = math.max(StartY - Position.Y, 0)
	                else
	                    StartY = Position.Y
	                    CurrentFallDistance = 0
	                end
	
	                local Smashing: boolean = not OnlyFall.Enabled or (State.IsDescending and CurrentFallDistance > MinFallDistance)
	                if Smashing then
	                    LastFall = CurrentFallDistance
	                    LastFallSpeed = State.FallSpeed
	                    LastFallTime = os.clock()
	                end
	
	                SetReady(Smashing)
	
	                if not Smashing and not (LastFall > MinFallDistance and os.clock() - LastFallTime <= LandedWindow) then
	                    InDelay = false
	                    continue
	                end
	
	                if os.clock() - LastAttack < AttackInterval then
	                    InDelay = false
	                    continue
	                end
	
	                local Entities = Entity.AllPosition({
	                    Range = math.clamp(Distance.Value, 0, 32),
	                    Wallcheck = Targets.Walls.Enabled or nil,
	                    Part = "RootPart",
	                    Players = Targets.Players.Enabled,
	                    NPCs = Targets.NPCs.Enabled,
	                    Priority = Targets.Priority.Value,
	                    Limit = Max.Value
	                })
	
	                if #Entities == 0 then
	                    InDelay = false
	                    continue
	                end
	
	                if not InDelay then
	                    InDelay = true
	                    DelayTime = os.clock() + Delay:GetRandomValue()
	                    continue
	                end
	
	                if os.clock() < DelayTime then
	                    continue
	                end
	                InDelay = false
	
	                local AimCFrame: CFrame = CFrame.new((Entity.character.Head or Entity.character.RootPart).Position, Entities[1].RootPart.Position)
	                if Aim.Enabled then
	                    Camera.CFrame = CFrame.new(Camera.CFrame.Position, Entities[1].RootPart.Position)
	                end
	
	                Attempt += 1
	                LastAttack = os.clock()
	
	                local Data = {
	                    SourceCharacter = Entity.character.Character,
	                    SmashAttemptId = Attempt,
	                    AimDirection = AimCFrame.LookVector,
	                    FallDistance = Spoof.Enabled and FallDistance.Value or (Smashing and CurrentFallDistance or LastFall),
	                    FallSpeed = Spoof.Enabled and math.sqrt(2 * workspace.Gravity * FallDistance.Value) or (Smashing and State.FallSpeed or LastFallSpeed)
	                }
	
	                SampleMiss(AimCFrame, Data)
	
	                local Charge = Mace:FindFirstChild("ChargeValue") and Mace.ChargeValue.Value or 1
	                Smear.CombatEvent:FireServer("BeginMaceSmash", nil, Charge, "Mace", Data)
	
	                for _, v: any in Entities do
	                    local Hitbox: BasePart? = GetHitbox(v.Character)
	                    if not Hitbox then
	                        continue
	                    end
	
	                    local HitData = table.clone(Data)
	                    HitData.ClientMaceSmashHurtbox = true
	                    HitData.ClientMaceSmashHitPosition = Hitbox.Position
	
	                    Smear.CombatEvent:FireServer(v.Humanoid, Hitbox, Charge, "Mace", HitData)
	
	                    if Spoof.Enabled then
	                        Entity.character.RootPart.AssemblyLinearVelocity = Vector3.new(0, 2.5, 0)
	                    end
	                end
	
	                Smear.AnimationService.play(Entity.character.Humanoid, SmashAnimation, Enum.AnimationPriority.Action, 0.1, 1, 1)
	
	                LastFall, LastFallSpeed, LastFallTime = 0, 0, -math.huge
	                SetReady(false)
	            until not AutoMace.Enabled
	        else
	            if Entity.isAlive then
	                SetReady(false)
	            end
	
	            Ready = false
	            LastAttack = 0
	            StartY, CurrentFallDistance = 0, 0
	            LastFall, LastFallSpeed, LastFallTime = 0, 0, -math.huge
	            InDelay, DelayTime = false, 0
	        end
	    end,
	    Tooltip = "Smashes nearby players with your mace."
	})
	Targets = AutoMace:CreateTargets({
	    Players = true,
	    Walls = true,
	    NPCs = true
	})
	Distance = AutoMace:CreateSlider({
	    Name = "Range",
	    Min = 0,
	    Max = 32,
	    Default = 20
	})
	Spoof = AutoMace:CreateToggle({
	    Name = "Spoof fall distance",
	    Function = function(Callback: boolean)
	        if FallDistance and FallDistance.Object then
	            FallDistance.Object.Visible = Callback
	        end
	    end
	})
	FallDistance = AutoMace:CreateSlider({
	    Name = "Fall distance",
	    Min = 1,
	    Max = 200,
	    Default = 100,
	    Suffix = function(Val: number)
	        return Val <= 1 and "stud" or "studs"
	    end,
	    Darker = true,
	    Visible = false
	})
	OnlyFall = AutoMace:CreateToggle({
	    Name = "Only falling",
	    Default = true
	})
	Aim = AutoMace:CreateToggle({
	    Name = "Look At Target"
	})
	Delay = AutoMace:CreateTwoSlider({
	    Name = "Delay",
	    Min = 0,
	    Max = 1,
	    DefaultMin = 0,
	    DefaultMax = 0.05,
	    Decimal = 100
	})
	Max = AutoMace:CreateSlider({
	    Name = "Max Targets",
	    Min = 1,
	    Max = 10,
	    Default = 1
	})
end)

Run(function()
	local AutoRevive
	local AutoStart
	local Delay
	local Inaccuracy
	
	local StartTimeout: number = 3.5
	
	local Handler
	local Difficulty
	local Offsets: {number} = {}
	local Pending, PendingTime = false, 0
	local AttemptStart, NextBar = 0, 1
	local InDelay, StartDelay = false, 0
	
	local function Press()
	    if not Handler then
	        for _, v: any in getconnections(Smear.PlayerKeybinds.ActionBegan) do
	            if v.Function and debug.getinfo(v.Function, "s").short_src:find("ReviveMinigame") then
	                Handler = v.Function
	                break
	            end
	        end
	    end
	
	    if Handler then
	        Handler("StartRevive")
	    else
	        firesignal(Smear.PlayerKeybinds.ActionBegan, "StartRevive")
	    end
	end
	
	local function ClearAttempt()
	    Difficulty = nil
	    Pending, PendingTime = false, 0
	    AttemptStart, NextBar = 0, 1
	    InDelay, StartDelay = false, 0
	    table.clear(Offsets)
	end
	
	local function BeginAttempt(Data)
	    Pending = false
	
	    if typeof(Data) ~= "table" or typeof(Data.Difficulty) ~= "table" or typeof(Data.Difficulty.FailureCount) ~= "number" then
	        return
	    end
	
	    local Attempt = Smear.ReviveMinigameConfig.getDifficulty(Data.Difficulty.FailureCount, Data.Difficulty.Variant == "Pact" and "Pact" or "Base")
	    if Attempt.BarCount <= 0 then
	        return
	    end
	
	    Difficulty = Attempt
	    AttemptStart, NextBar = os.clock(), 1
	
	    local Limit: number = Smear.ReviveMinigameConfig.getWindows(Attempt.Variant).Amazing * 0.4
	
	    table.clear(Offsets)
	    for i: number = 1, Attempt.BarCount do
	        Offsets[i] = (math.random() < 0.5 and -1 or 1) * math.min(Inaccuracy:GetRandomValue(), Limit)
	    end
	end
	
	AutoRevive = vape.Categories.Utility:CreateModule({
	    Name = "AutoRevive",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoRevive:Clean(Smear.DownedEvent.OnClientEvent:Connect(function(Action: string, Data)
	                if Action == "ReviveStarted" then
	                    BeginAttempt(Data)
	                elseif Action == "ReviveStartRejected" or Action == "ReviveCancelled" or Action == "ReviveOutcome" then
	                    ClearAttempt()
	                end
	            end))
	
	            repeat
	                local Step: number = task.wait()
	                if not LocalPlayer:GetAttribute("IsDowned") then
	                    if Difficulty or Pending or InDelay then
	                        ClearAttempt()
	                    end
	                    continue
	                end
	
	                if Difficulty then
	                    if not LocalPlayer:GetAttribute("InReviveMinigame") then
	                        ClearAttempt()
	                        continue
	                    end
	
	                    local Beat: number = AttemptStart + Difficulty.LeadTime + ((NextBar - 1) * Difficulty.BarGap)
	                    local Now: number = os.clock() + (Step * 0.5)
	
	                    if Now < Beat + Offsets[NextBar] then
	                        continue
	                    end
	
	                    if Now - Beat <= Difficulty.GoodWindow then
	                        Press()
	                    end
	
	                    NextBar += 1
	                    if NextBar > Difficulty.BarCount then
	                        Difficulty = nil
	                    end
	                    continue
	                end
	
	                if not AutoStart.Enabled or LocalPlayer:GetAttribute("InReviveMinigame") then
	                    InDelay = false
	                    continue
	                end
	
	                if Pending then
	                    if os.clock() - PendingTime < StartTimeout then
	                        continue
	                    end
	                    Pending = false
	                end
	
	                if not InDelay then
	                    InDelay = true
	                    StartDelay = os.clock() + Delay:GetRandomValue()
	                    continue
	                end
	
	                if os.clock() < StartDelay then
	                    continue
	                end
	
	                InDelay = false
	                Pending, PendingTime = true, os.clock()
	                Press()
	            until not AutoRevive.Enabled
	        else
	            ClearAttempt()
	            Handler = nil
	        end
	    end,
	    Tooltip = "Plays the downed revive minigame for you, hitting every beat as it crosses the marker."
	})
	AutoStart = AutoRevive:CreateToggle({
	    Name = "Auto start",
	    Default = true,
	    Function = function(Callback: boolean)
	        if Delay and Delay.Object then
	            Delay.Object.Visible = Callback
	        end
	    end
	})
	Delay = AutoRevive:CreateTwoSlider({
	    Name = "Start delay",
	    Min = 0,
	    Max = 1,
	    DefaultMin = 0.2,
	    DefaultMax = 0.4,
	    Decimal = 100,
	    Darker = true
	})
	Inaccuracy = AutoRevive:CreateTwoSlider({
	    Name = "Inaccuracy",
	    Min = 0,
	    Max = 0.02,
	    DefaultMin = 0,
	    DefaultMax = 0.01,
	    Decimal = 1000
	})
end)

Run(function()
	local PickupRange
	local Range
	local UseWhitelist
	local Whitelist
	local Enchantments
	
	local function IsAllowed(Item: Instance): boolean
	    if not UseWhitelist.Enabled then
	        return true
	    end
	    if not table.find(Whitelist.ListEnabled, (Item:GetAttribute("ItemId") or Item.Name:gsub("Pickup_", "")):lower()) then
	        return false
	    end
	    if table.find(Enchantments.ListEnabled, "all") or not Smear.WeaponRegistry[Item:GetAttribute("ItemId")] then
	        return true
	    end
	
	    for _, v: string in (Item:GetAttribute("Enchantments") or ""):split(",") do
	        if table.find(Enchantments.ListEnabled, v) then
	            return true
	        end
	    end
	    return false
	end
	
	PickupRange = vape.Categories.Utility:CreateModule({
	    Name = "PickupRange",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                task.wait(0.1)
	                if not Entity.isAlive then
	                    continue
	                end
	
	                for _, v: Instance in workspace.Pickups:GetChildren() do
	                    local Interest: Instance? = v:FindFirstChild("TouchInterest", true)
	
	                    if Interest and LocalPlayer:DistanceFromCharacter(Interest.Parent.Position) <= Range.Value and IsAllowed(v) then
	                        firetouchinterest(Interest.Parent, Entity.character.RootPart, 0)
	                        firetouchinterest(Interest.Parent, Entity.character.RootPart, 1)
	                    end
	                end
	            until not PickupRange.Enabled
	        end
	    end,
	    Tooltip = "Picks up items from further away."
	})
	Range = PickupRange:CreateSlider({
	    Name = "Range",
	    Min = 1,
	    Max = 20,
	    Default = 20,
	    Suffix = function(Val: number)
	        return Val <= 1 and "stud" or "studs"
	    end
	})
	UseWhitelist = PickupRange:CreateToggle({
	    Name = "Use whitelist",
	    Default = true,
	    Function = function(Callback: boolean)
	        if Whitelist then
	            Whitelist.Object.Visible = Callback
	            Enchantments.Object.Visible = Callback
	        end
	    end
	})
	Whitelist = PickupRange:CreateTextList({
	    Name = "Whitelist",
	    Default = {"totemofundying"},
	    Darker = true
	})
	Enchantments = PickupRange:CreateTextList({
	    Name = "Enchantments",
	    Default = {"windburst"},
	    Darker = true
	})
end)

Run(function()
	local FastBreak
	local Value
	
	local FireServer = Smear.BreakingEvent.FireServer
	local Old
	
	FastBreak = vape.Categories.World:CreateModule({
	    Name = "FastBreak",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = hookfunction(FireServer, function(self, Position: Vector3, Progress: number, ...)
	                if self == Smear.BreakingEvent and not vape.Modules["👺"].Enabled then
	                    return Old(self, Position, Value.Value, ...)
	                end
	
	                return Old(self, Position, Progress, ...)
	            end)
	        elseif Old then
	            hookfunction(FireServer, Old)
	            Old = nil
	        end
	    end,
	    Tooltip = "Break blocks faster when mining."
	})
	Value = FastBreak:CreateSlider({
	    Name = "Harvest Spees",
	    Min = 14,
	    Max = 30,
	    Default = 14,
	    Decimal = 10
	})
end)

Run(function()
	local AutoTotem
	local Delay
	local ExtraDelay
	local TotemCount
	
	local Label: TextLabel?
	local OffhandSlot: Instance?
	local TotemDelay: number
	local InDelay: boolean = false
	
	local function CountTotems(): number
	    local Total: number = 0
	    for _, v: Instance in LocalPlayer.Backpack:GetChildren() do
	        if v:GetAttribute("ItemId") == "TotemOfUndying" then
	            Total += 1
	        end
	    end
	    return Total
	end
	
	AutoTotem = vape.Categories.Inventory:CreateModule({
	    Name = "AutoTotem",
	    Function = function(Callback: boolean)
	        if Label then
	            Label.Visible = Callback
	        end
	
	        if Callback then
	            repeat
	                task.wait()
	                if not (OffhandSlot and OffhandSlot.Parent) then
	                    OffhandSlot = LocalPlayer.PlayerGui:FindFirstChild("OffhandSlot", true)
	                end
	
	                if not Entity.isAlive or not OffhandSlot then
	                    continue
	                end
	
	                if Label and TotemCount.Enabled then
	                    Label.Text = tostring(CountTotems())
	                end
	
	                if OffhandSlot:GetAttribute("ItemId") then
	                    continue
	                end
	
	                local Totem = GetItem("TotemOfUndying")
	                if not Totem then
	                    continue
	                end
	
	                if not InDelay then
	                    InDelay = true
	                    TotemDelay = os.clock() + Delay:GetRandomValue() + (math.random() < 0.18 and math.random() * ExtraDelay:GetRandomValue() or 0)
	                end
	
	                if os.clock() >= TotemDelay then
	                    Smear.OffhandEvent:FireServer("Set", Totem.Name, Totem)
	                    InDelay = false
	                end
	            until not AutoTotem.Enabled
	        else
	            InDelay = false
	        end
	    end,
	    Tooltip = "Moves a totem into your offhand whenever it empties."
	})
	Delay = AutoTotem:CreateTwoSlider({
	    Name = "Delay",
	    Min = 0,
	    Max = 1,
	    DefaultMin = 0.22,
	    DefaultMax = 0.34,
	    Decimal = 100
	})
	ExtraDelay = AutoTotem:CreateTwoSlider({
	    Name = "ExtraDelay",
	    Min = 0,
	    Max = 1,
	    DefaultMin = 0.22,
	    DefaultMax = 0.34,
	    Decimal = 100
	})
	TotemCount = AutoTotem:CreateToggle({
	    Name = "TotemCount",
	    Function = function(Callback: boolean)
	        if Callback then
	            Label = Instance.new("TextLabel")
	            Label.Name = "TotemCount"
	            Label.AnchorPoint = Vector2.new(0.5, 0)
	            Label.BackgroundTransparency = 1
	            Label.Font = Enum.Font.Arial
	            Label.Position = UDim2.new(0.5, 6, 0.5, 60)
	            Label.RichText = true
	            Label.Size = UDim2.fromOffset(100, 20)
	            Label.Text = "0"
	            Label.TextColor3 = Color3.fromRGB(0, 255, 0)
	            Label.TextSize = 18
	            Label.Visible = AutoTotem.Enabled
	            Label.Parent = vape.gui
	        elseif Label then
	            Label:Destroy()
	            Label = nil
	        end
	    end
	})
end)

Run(function()
	local SpearLunge
	local Mode
	local ChargeDelay
	local Legit
	local EquipDelay
	
	local MinHorizontal: number = 0.08
	
	local function Lunge()
	    if not Entity.isAlive then
	        return
	    end
	
	    local Spear, Equipped = GetItem("Spear")
	    if not Spear then
	        SendNotification("SpearLunge", "No Spear found in your hotbar.", 5, "alert")
	        return
	    end
	
	    local Cooldown = LocalPlayer:GetAttribute("SpearBoostCooldownEnd")
	    if Cooldown and tick() < Cooldown then
	        return
	    end
	
	    local Direction: Vector3 = Camera.CFrame.LookVector
	    if Mode.Value == "Boost" and Vector3.new(Direction.X, 0, Direction.Z).Magnitude < MinHorizontal then
	        return
	    end
	
	    local Old: Tool? = Entity.character.Character:FindFirstChildOfClass("Tool")
	    if not Equipped then
	        SwitchItem(Spear, Legit.Enabled)
	
	        if Legit.Enabled then
	            task.wait(EquipDelay.Value)
	        end
	    end
	
	    if Mode.Value == "LookBoost" then
	        Smear.SpearEvent:FireServer("StartCharge")
	        task.wait(ChargeDelay.Value)
	    end
	
	    Smear.SpearEvent:FireServer(Mode.Value, Direction)
	
	    if Old and Old ~= Spear then
	        if Legit.Enabled then
	            task.wait(EquipDelay.Value)
	        end
	
	        SwitchItem(Old, Legit.Enabled)
	    end
	end
	
	SpearLunge = vape.Categories.Inventory:CreateModule({
	    Name = "SpearLunge",
	    Function = function(Callback: boolean)
	        if Callback then
	            Lunge()
	            SpearLunge:Toggle()
	        end
	    end,
	    Tooltip = "Swaps to your spear, lunges and swaps back to your old item."
	})
	Mode = SpearLunge:CreateDropdown({
	    Name = "Method",
	    List = {"LookBoost", "Boost"}
	})
	ChargeDelay = SpearLunge:CreateSlider({
	    Name = "Charge Delay",
	    Min = 0,
	    Max = 0.5,
	    Default = 0.05,
	    Decimal = 100
	})
	Legit = SpearLunge:CreateToggle({
	    Name = "Legit Equip",
	    Function = function(Callback: boolean)
	        if EquipDelay then
	            EquipDelay.Object.Visible = Callback
	        end
	    end
	})
	EquipDelay = SpearLunge:CreateSlider({
	    Name = "Equip Delay",
	    Min = 0,
	    Max = 0.5,
	    Default = 0.05,
	    Decimal = 100,
	    Visible = false
	})
end)

Run(function()
	local Viewmodel
	local Hands
	local Horizontal
	local Vertical
	local Depth
	local OldTool
	
	local function SetArms(Hidden: boolean)
	    if not Entity.isAlive then
	        return
	    end
	
	    for _, v: string in {"Right Arm", "Left Arm"} do
	        local Part: BasePart? = Entity.character.Character:FindFirstChild(v)
	
	        if Part then
	            Part.LocalTransparencyModifier = Hidden and 1 or 0
	            Part.Transparency = Hidden and 1 or 0
	        end
	    end
	end
	
	local function NewTool(Object: Instance)
	    if not Object:IsA("Tool") or not Object:FindFirstChild("Handle") then
	        return
	    end
	
	    OldTool = Object
	    ViewmodelTool = OldTool.Handle:Clone()
	    ViewmodelTool.CanCollide = false
	    ViewmodelTool.CanQuery = false
	    ViewmodelTool.Massless = true
	    ViewmodelTool.Anchored = true
	
	    for _, v: Instance in ViewmodelTool:GetDescendants() do
	        if v:IsA("BaseScript") or v:IsA("Sound") then
	            v:Destroy()
	        end
	    end
	
	    ViewmodelTool.Parent = Camera
	    ViewmodelTool.LocalTransparencyModifier = 0
	    OldTool.Handle.LocalTransparencyModifier = 1
	end
	
	local function NewCharacter(Entity)
	    Viewmodel:Clean(Entity.Character.ChildAdded:Connect(NewTool))
	    Viewmodel:Clean(Entity.Character.ChildRemoved:Connect(function(Object: Instance)
	        if Object == OldTool then
	            ViewmodelTool:Destroy()
	            ViewmodelTool = nil
	            OldTool = nil
	        end
	    end))
	
	    local Tool: Tool? = Entity.Character:FindFirstChildOfClass("Tool")
	    if Tool then
	        NewTool(Tool)
	    end
	end
	
	Viewmodel = vape.Legit:CreateModule({
	    Name = "Viewmodel",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_viewmodel.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            ViewmodelMotor = Instance.new("Motor6D")
	            vape:Clean(ViewmodelMotor)
	            vape:Clean(RunService.RenderStepped:Connect(function()
	                local Swing: Instance? = Camera:FindFirstChild("LocalFirstPersonWeaponSwing")
	
	                if Swing then
	                    for _, v: Instance in Swing:GetDescendants() do
	                        if v:IsA("BasePart") and (Hands.Enabled or v:FindFirstAncestorWhichIsA("Tool")) then
	                            v.LocalTransparencyModifier = 1
	                            v.Transparency = 1
	                        end
	                    end
	                end
	
	                if OldTool and OldTool.Parent then
	                    OldTool.Handle.LocalTransparencyModifier = 1
	                end
	
	                if Hands.Enabled then
	                    SetArms(true)
	                end
	
	                if ViewmodelTool then
	                    local DefaultCFrame: CFrame = ((CFrame.new(2.06, -2.44, -2.24) * CFrame.new(0.6 + Horizontal.Value, -0.2 + Vertical.Value, -0.6 - Depth.Value)) * CFrame.Angles(math.rad(99), math.rad(2), math.rad(-4))) * ViewmodelMotor.C0
	                    local OffsetCFrame: CFrame = (CFrame.new(0, -0.15, -1.56) * CFrame.Angles(math.rad(-90), math.rad(-90), math.rad(-50)))
	                    ViewmodelTool.CFrame = ((Camera.CFrame * DefaultCFrame) * OffsetCFrame)
	                end
	            end))
	            vape:Clean(Entity.Events.LocalAdded:Connect(NewCharacter))
	
	            if Entity.isAlive then
	                NewCharacter(Entity.character)
	            end
	        else
	            SetArms(false)
	
	            if ViewmodelTool then
	                ViewmodelTool:Destroy()
	                ViewmodelTool = nil
	            end
	
	            if OldTool and OldTool.Parent then
	                OldTool.Handle.LocalTransparencyModifier = 0
	            end
	
	            OldTool = nil
	        end
	    end,
	    Tooltip = "Replaces the default viewmodel"
	})
	Hands = Viewmodel:CreateToggle({
	    Name = "Hide hands",
	    Default = true,
	    Function = function(Callback: boolean)
	        if not Callback and Viewmodel.Enabled then
	            SetArms(false)
	        end
	    end
	})
	Horizontal = Viewmodel:CreateSlider({
	    Name = "Horizontal",
	    Min = -4,
	    Max = 4,
	    Default = 0,
	    Decimal = 100
	})
	Vertical = Viewmodel:CreateSlider({
	    Name = "Vertical",
	    Min = -4,
	    Max = 4,
	    Default = 0,
	    Decimal = 100
	})
	Depth = Viewmodel:CreateSlider({
	    Name = "Depth",
	    Min = -4,
	    Max = 4,
	    Default = 0,
	    Decimal = 100
	})
end)