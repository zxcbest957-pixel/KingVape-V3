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
local RunService: RunService = cloneref(game:GetService("RunService"))

local Camera: Camera = workspace.CurrentCamera
local LocalPlayer: Player = Players.LocalPlayer
local vape = shared.vape
local Entity = vape.Libraries.entity
local TargetInfo = vape.Libraries.targetinfo
local PredictionLib = vape.Libraries.prediction

local BridgeDuel = {}
local Store = {
    blocks = {},
    serverBlocks = {}
}

local function GetTool(): Tool?
    return LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool", true) or nil
end

local function SendNotification(...)
    return vape:CreateNotification(...)
end

local function ParsePositions(Part: Instance, Func: (Vector3) -> ())
    if Part:IsA("Part") then
        local Start: Vector3 = -(Part.Size / 2) + Vector3.new(1.5, 1.5, 1.5)
        for X: number = 0, Part.Size.X - 1, 3 do
            for Y: number = 0, Part.Size.Y - 1, 3 do
                for Z: number = 0, Part.Size.Z - 1, 3 do
                    local Position: Vector3 = Start + Vector3.new(X, Y, Z)
                    Position = Part.CFrame:PointToWorldSpace(Position)
                    Position = Vector3.new(math.round(Position.X), math.round(Position.Y), math.round(Position.Z))
                    Func(Position)
                end
            end
        end
    end
end

Run(function()
    local Knit = require(ReplicatedStorage.Modules.Knit.Client)
    if not debug.getupvalue(Knit.Start, 1) then
        repeat
            task.wait()
        until debug.getupvalue(Knit.Start, 1)
    end

    BridgeDuel = setmetatable({
        BedwarsShop = require(ReplicatedStorage.Constants.BedWarsShop),
        BedwarsUpgrades = require(ReplicatedStorage.Constants.BedWarsTeamUpgrades),
        Blink = require(ReplicatedStorage.Blink.Client),
        BreakTimes = require(ReplicatedStorage.Constants.Blocks),
        BowClient = require(ReplicatedStorage.Client.Components.All.Tools.BowClient),
        CombatConstants = require(ReplicatedStorage.Constants.Melee),
        Communication = require(ReplicatedStorage.Client.Communication),
        Knit = Knit,
        Entity = require(ReplicatedStorage.Modules.Entity),
        ServerData = require(ReplicatedStorage.Modules.ServerData),
    }, {
        __index = function(self, Index: string)
            rawset(self, Index, Index:find("Service") and Knit.GetService(Index) or Knit.GetController(Index))
            return rawget(self, Index)
        end
    })

    task.spawn(function()
        local Map: Instance? = workspace:WaitForChild("Map", 99999)
        if Map and vape.Loaded ~= nil then
            vape:Clean(Map.DescendantAdded:Connect(function(Part: Instance)
                ParsePositions(Part, function(Position: Vector3)
                    Store.blocks[Position] = Part
                end)
            end))
            vape:Clean(Map.DescendantRemoving:Connect(function(Part: Instance)
                ParsePositions(Part, function(Position: Vector3)
                    if Store.blocks[Position] == Part then
                        Store.blocks[Position] = nil
                        Store.serverBlocks[Position] = nil
                    end
                end)
            end))
            for _, v: Instance in Map:GetDescendants() do
                ParsePositions(v, function(Position: Vector3)
                    Store.blocks[Position] = v
                    Store.serverBlocks[Position] = v
                end)
            end
        end
    end)

    vape:Clean(function()
        table.clear(Store.blocks)
        table.clear(Store)
    end)
end)

for _, v: string in {"Reach", "SilentAim", "Disabler", "HitBoxes", "MurderMystery", "AutoRejoin"} do
    vape:Remove(v)
end

Run(function()
	local AutoClicker
	local CPS
	
	AutoClicker = vape.Categories.Combat:CreateModule({
	    Name = "AutoClicker",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local Tool: Tool? = GetTool()
	                if Tool and UserInputService:IsMouseButtonPressed(0) then
	                    Tool:Activate()
	                end
	
	                task.wait(1 / CPS.GetRandomValue())
	            until not AutoClicker.Enabled
	        end
	    end,
	    Tooltip = "Automatically clicks for you"
	})
	CPS = AutoClicker:CreateTwoSlider({
	    Name = "CPS",
	    Min = 1,
	    Max = 20,
	    DefaultMin = 8,
	    DefaultMax = 12
	})
end)

Run(function()
	--[[local old
	
	vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			if callback then
				--old = rawget(bd.CombatConstants, 'REACH_IN_STUDS')
				--rawset(bd.CombatConstants, 'REACH_IN_STUDS', 18)
				--rawset(bd.Entity.LocalEntity, 'Reach', 18)
			else
				--rawset(bd.CombatConstants, 'REACH_IN_STUDS', old)
				--rawset(bd.Entity.LocalEntity, 'Reach', old)
				--old = nil
			end
		end,
		Tooltip = 'Extends attack reach'
	})]]
end)

Run(function()
	local Velocity
	local Horizontal
	local Vertical
	local Chance
	local Targeting
	local Old
	local Connection
	
	local function VelocityFunction(KnockbackVelocity: Vector3, ...)
	    if Random.new():NextNumber(0, 100) > Chance.Value then
	        return Old(KnockbackVelocity, ...)
	    end
	
	    local Check = (not Targeting.Enabled) or Entity.EntityPosition({
	        Range = 50,
	        Part = "RootPart",
	        Players = true
	    })
	
	    if Check then
	        local HorizontalScale, VerticalScale = (Horizontal.Value / 100), (Vertical.Value / 100)
	        if HorizontalScale == 0 and VerticalScale == 0 then
	            return
	        end
	        KnockbackVelocity = Vector3.new(KnockbackVelocity.X * HorizontalScale, KnockbackVelocity.Y * VerticalScale, KnockbackVelocity.Z * HorizontalScale)
	    end
	
	    return Old(KnockbackVelocity, ...)
	end
	
	Velocity = vape.Categories.Combat:CreateModule({
	    Name = "Velocity",
	    Function = function(Callback: boolean)
	        if Callback then
	            Connection = getconnections(BridgeDuel.CombatService.KnockBackApplied._re.OnClientEvent)[1]
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
	local Old
	
	vape.Categories.Blatant:CreateModule({
	    Name = "Criticals",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = hookfunction(BridgeDuel.Blink.item_action.attack_entity.fire, function(...)
	                local Data = ...
	                if type(Data) == "table" then
	                    rawset(Data, "is_crit", true)
	                end
	
	                return Old(...)
	            end)
	        else
	            hookfunction(BridgeDuel.Blink.item_action.attack_entity.fire, Old)
	            Old = nil
	        end
	    end,
	    Tooltip = "Always hit criticals"
	})
end)

Run(function()
	local Old
	
	vape.Categories.Blatant:CreateModule({
	    Name = "InvMove",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = hookfunction(BridgeDuel.MovementController.AddSpeedOverride, function(...)
	                if select(2, ...) == "MenuOpen" then
	                    return
	                end
	
	                return Old(...)
	            end)
	
	            BridgeDuel.MovementController:RemoveSpeedOverride("MenuOpen")
	        else
	            if Old then
	                hookfunction(BridgeDuel.MovementController.AddSpeedOverride, Old)
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Allows you to have continuous movement in menus"
	})
end)

Run(function()
	local Killaura
	local Targets
	local CPS
	local SwingRange
	local AttackRange
	local AngleSlider
	local Max
	local Mouse
	local Swing
	local Block
	local AutoBlock
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local LegitAura
	local Particles, Boxes, AttackDelay, SwingDelay, ClickDelay = {}, {}, tick(), tick(), tick()
	local PlayerMouse: Mouse = cloneref(LocalPlayer:GetMouse())
	
	local function GetAttackData()
	    if Mouse.Enabled then
	        if not UserInputService:IsMouseButtonPressed(0) then
	            return false
	        end
	    end
	    if LegitAura.Enabled then
	        if ClickDelay < tick() then
	            return false
	        end
	    end
	
	    return GetTool()
	end
	
	Killaura = vape.Categories.Blatant:CreateModule({
	    Name = "Killaura",
	    Function = function(Callback: boolean)
	        if Callback then
	            if LegitAura.Enabled then
	                Killaura:Clean(UserInputService.InputBegan:Connect(function(Input: InputObject)
	                    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
	                        ClickDelay = tick() + 0.1
	                    end
	                end))
	            end
	
	            repeat
	                local Tool = GetAttackData()
	                local Attacked = {}
	
	                if Tool and Tool:HasTag("Sword") then
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
	                        local SelfPosition: Vector3 = Entity.character.RootPart.Position
	                        local LocalFacing: Vector3 = Entity.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	
	                        if AutoBlock.Enabled and not BridgeDuel.Entity.LocalEntity.IsBlocking then
	                            firesignal(PlayerMouse.Button2Down)
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
	                            if Block.Enabled then
	                                if BridgeDuel.Entity.LocalEntity.IsBlocking then
	                                    continue
	                                end
	                            end
	
	                            if not Swing.Enabled and SwingDelay < tick() then
	                                SwingDelay = tick() + 0.25
	                                Entity.character.Humanoid.Animator:LoadAnimation(Tool.Animations.Swing):Play()
	
	                                if vape.ThreadFix then
	                                    setthreadidentity(2)
	                                end
	                                BridgeDuel.ViewmodelController:PlayAnimation(Tool.Name)
	                                if vape.ThreadFix then
	                                    setthreadidentity(8)
	                                end
	                            end
	
	                            if Delta.Magnitude > AttackRange.Value then
	                                continue
	                            end
	                            if AttackDelay < tick() then
	                                AttackDelay = tick() + (1 / CPS.GetRandomValue())
	                                local GameEntity = BridgeDuel.Entity.FindByCharacter(v.Character)
	                                if GameEntity then
	                                    BridgeDuel.Blink.item_action.attack_entity.fire({
	                                        target_entity_id = GameEntity.Id,
	                                        is_crit = Entity.character.RootPart.AssemblyLinearVelocity.Y < 0,
	                                        weapon_name = Tool.Name,
	                                        extra = {
	                                            rizz = "Bro.",
	                                            owo = "What's this? OwO",
	                                            those = nil,
	                                            those = workspace.Name == "Okay"
	                                        }
	                                    })
	                                end
	                            end
	                        end
	                    else
	                        if AutoBlock.Enabled and BridgeDuel.Entity.LocalEntity.IsBlocking then
	                            firesignal(PlayerMouse.Button2Up)
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
	
	                task.wait()
	            until not Killaura.Enabled
	        else
	            if AutoBlock.Enabled and BridgeDuel.Entity.LocalEntity.IsBlocking then
	                firesignal(PlayerMouse.Button2Up)
	            end
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
	CPS = Killaura:CreateTwoSlider({
	    Name = "Attacks per Second",
	    Min = 1,
	    Max = 20,
	    DefaultMin = 12,
	    DefaultMax = 12
	})
	SwingRange = Killaura:CreateSlider({
	    Name = "Swing range",
	    Min = 1,
	    Max = 16,
	    Default = 16,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
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
	Swing = Killaura:CreateToggle({Name = "No Swing"})
	Block = Killaura:CreateToggle({Name = "No Block"})
	AutoBlock = Killaura:CreateToggle({Name = "AutoBlock"})
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
	    Default = 0.14,
	    Decimal = 100,
	    Function = function(Val: number)
	        for _, v: Part in Particles do
	            v.ParticleEmitter.Size = NumberSequence.new(Val)
	        end
	    end,
	    Darker = true,
	    Visible = false
	})
	LegitAura = Killaura:CreateToggle({
	    Name = "Swing only",
	    Function = function()
	        if Killaura.Enabled then
	            Killaura:Toggle()
	            Killaura:Toggle()
	        end
	    end,
	    Tooltip = "Only attacks while swinging manually"
	})
end)

Run(function()
	local Old
	
	vape.Categories.Blatant:CreateModule({
	    Name = "NoFall",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = hookfunction(BridgeDuel.Blink.player_state.take_fall_damage.fire, function() end)
	        else
	            hookfunction(BridgeDuel.Blink.player_state.take_fall_damage.fire, Old)
	            Old = nil
	        end
	    end,
	    Tooltip = "Prevents taking fall damage."
	})
end)

Run(function()
	local Old
	
	vape.Categories.Blatant:CreateModule({
	    Name = "NoSlowdown",
	    Function = function(Callback: boolean)
	        local Proto = debug.getproto(BridgeDuel.MovementController.KnitStart, 7)
	
	        if Callback then
	            Old = debug.getconstants(Proto)
	            for i: number, v: any in Old do
	                if type(v) == "string" and (v:find("Client") or v == "IsChargingBow") and v ~= "ClientSneaking" then
	                    debug.setconstant(Proto, i, "IsSpectating")
	                end
	            end
	        else
	            for i: number, v: any in Old do
	                debug.setconstant(Proto, i, v)
	            end
	            table.clear(Old)
	        end
	    end,
	    Tooltip = "Prevents slowing down when using items."
	})
end)

Run(function()
	local TargetPart
	local FOV
	local Old
	local RayCheck: RaycastParams = RaycastParams.new()
	RayCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	local function AimFunction(...)
	    local Ent = Entity.EntityMouse({
	        Range = FOV.Value,
	        Part = "RootPart",
	        Players = true
	    })
	
	    if Ent then
	        RayCheck.FilterDescendantsInstances = {Ent.Character, Camera}
	        RayCheck.CollisionGroup = Ent[TargetPart.Value].CollisionGroup
	        local OffsetPosition: CFrame = Entity.character.Head.CFrame
	        local AimPosition: Vector3? = PredictionLib.SolveTrajectory(OffsetPosition.Position, 180, 60, Ent[TargetPart.Value].Position, Ent[TargetPart.Value].Velocity, workspace.Gravity, Ent.HipHeight, nil, RayCheck)
	
	        if AimPosition then
	            TargetInfo.Targets[Ent] = tick() + 1
	            return OffsetPosition.Position + CFrame.new(OffsetPosition.Position, AimPosition).LookVector * 100
	        end
	    end
	
	    return Old(...)
	end
	
	local ProjectileAimbot = vape.Categories.Blatant:CreateModule({
	    Name = "ProjectileAimbot",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = hookfunction(debug.getupvalue(BridgeDuel.BowClient.Start, 11), function(...)
	                return AimFunction(...)
	            end)
	        else
	            hookfunction(debug.getupvalue(BridgeDuel.BowClient.Start, 11), Old)
	            Old = nil
	        end
	    end,
	    Tooltip = "Silently adjusts your aim towards the enemy"
	})
	TargetPart = ProjectileAimbot:CreateDropdown({
	    Name = "Part",
	    List = {"RootPart", "Head"}
	})
	FOV = ProjectileAimbot:CreateSlider({
	    Name = "FOV",
	    Min = 1,
	    Max = 1000,
	    Default = 1000
	})
end)

Run(function()
	local AutoPlay
	local Delay
	
	AutoPlay = vape.Categories.Utility:CreateModule({
	    Name = "AutoPlay",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoPlay:Clean(BridgeDuel.Blink.game_state.team_won.on(function()
	                if BridgeDuel.ServerData.Submode ~= "Playground" then
	                    BridgeDuel.MatchController:EnterQueue(BridgeDuel.ServerData.Submode)
	                end
	            end))
	        end
	    end,
	    Tooltip = "Automatically queues after the match ends."
	})
end)

Run(function()
	local Scaffold
	local Expand
	local Tower
	local Downwards
	local Diagonal
	local LimitItem
	local Adjacent, LastPosition = {}, Vector3.zero
	
	for X: number = -3, 3, 3 do
	    for Y: number = -3, 3, 3 do
	        for Z: number = -3, 3, 3 do
	            local Offset: Vector3 = Vector3.new(X, Y, Z)
	            if Offset.Y ~= 0 and (Offset.X ~= 0 or Offset.Z ~= 0) then
	                continue
	            end
	
	            if Offset ~= Vector3.zero then
	                table.insert(Adjacent, Offset)
	            end
	        end
	    end
	end
	
	local function GetBlocksInPoints(Start: Vector3, End: Vector3): {Vector3}
	    local List: {Vector3} = {}
	    for X: number = Start.X, End.X, 3 do
	        for Y: number = Start.Y, End.Y, 3 do
	            for Z: number = Start.Z, End.Z, 3 do
	                local Position: Vector3 = Vector3.new(X, Y, Z)
	                if Store.blocks[Position] then
	                    table.insert(List, Position)
	                end
	            end
	        end
	    end
	    return List
	end
	
	local function RoundPosition(Position: Vector3): Vector3
	    return Vector3.new(math.round(Position.X / 3) * 3, math.round(Position.Y / 3) * 3, math.round(Position.Z / 3) * 3)
	end
	
	local function NearCorner(CheckPosition: Vector3, Position: Vector3): Vector3
	    local StartPosition: Vector3 = CheckPosition - Vector3.new(3, 3, 3)
	    local EndPosition: Vector3 = CheckPosition + Vector3.new(3, 3, 3)
	    local Check: Vector3 = CheckPosition + (Position - CheckPosition).Unit * 100
	    if math.abs(Check.Y - StartPosition.Y) > 3 then
	        return Vector3.new(CheckPosition.X, math.clamp(Check.Y, StartPosition.Y, EndPosition.Y), CheckPosition.Z)
	    end
	    return Vector3.new(math.clamp(Check.X, StartPosition.X, EndPosition.X), math.clamp(Check.Y, StartPosition.Y, EndPosition.Y), math.clamp(Check.Z, StartPosition.Z, EndPosition.Z))
	end
	
	local function BlockProximity(Position: Vector3): Vector3?
	    local Magnitude, Returned = 60
	    local Blocks: {Vector3} = GetBlocksInPoints(Position - Vector3.new(21, 21, 21), Position + Vector3.new(21, 21, 21))
	    for _, v: Vector3 in Blocks do
	        local BlockPosition: Vector3 = NearCorner(v, Position)
	        local NewMagnitude: number = (Position - BlockPosition).Magnitude
	        if NewMagnitude < Magnitude then
	            Magnitude, Returned = NewMagnitude, BlockPosition
	        end
	    end
	    table.clear(Blocks)
	    return Returned
	end
	
	local function CheckAdjacent(Position: Vector3): boolean
	    for _, v: Vector3 in Adjacent do
	        if Store.blocks[Position + v] then
	            return true
	        end
	    end
	    return false
	end
	
	local function GetBlock()
	    local Tool: Tool? = GetTool()
	    if Tool and Tool:HasTag("Blocks") then
	        local BlockType: string = Tool.Name == "Blocks" and "Clay" or Tool.Name:sub(1, -6)
	        return BlockType, BlockType == "Clay" and "Blocks" or ("%*Block"):format(BlockType)
	    end
	
	    if LimitItem.Enabled then
	        return
	    end
	    for _, v: Instance in LocalPlayer.Backpack:GetChildren() do
	        if v:IsA("Tool") and v:HasTag("Blocks") then
	            local BlockType: string = v.Name == "Blocks" and "Clay" or v.Name:sub(1, -6)
	            return BlockType, BlockType == "Clay" and "Blocks" or ("%*Block"):format(BlockType)
	        end
	    end
	end
	
	Scaffold = vape.Categories.Utility:CreateModule({
	    Name = "Scaffold",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                if Entity.isAlive then
	                    local BlockType, BlockName = GetBlock()
	
	                    if BlockType then
	                        local Root: BasePart = Entity.character.RootPart
	                        if Tower.Enabled and UserInputService:IsKeyDown(Enum.KeyCode.Space) and (not UserInputService:GetFocusedTextBox()) then
	                            Root.Velocity = Vector3.new(Root.Velocity.X, 38, Root.Velocity.Z)
	                        end
	
	                        for i: number = Expand.Value, 1, -1 do
	                            local CurrentPosition: Vector3 = RoundPosition(Root.Position - Vector3.new(0, Entity.character.HipHeight + (Downwards.Enabled and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4.5 or 1.5), 0) + Entity.character.Humanoid.MoveDirection * (i * 3))
	                            if Diagonal.Enabled then
	                                if math.abs(math.round(math.deg(math.atan2(-Entity.character.Humanoid.MoveDirection.X, -Entity.character.Humanoid.MoveDirection.Z)) / 45) * 45) % 90 == 45 then
	                                    local Delta: Vector3 = (LastPosition - CurrentPosition)
	                                    if ((Delta.X == 0 and Delta.Z ~= 0) or (Delta.X ~= 0 and Delta.Z == 0)) and ((LastPosition - Root.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 then
	                                        CurrentPosition = LastPosition
	                                    end
	                                end
	                            end
	
	                            local Block = Store.blocks[CurrentPosition]
	                            if not Block then
	                                local BlockPosition: Vector3? = CheckAdjacent(CurrentPosition) and CurrentPosition or BlockProximity(CurrentPosition)
	                                if BlockPosition then
	                                    local Fake: BasePart = ReplicatedStorage.Assets.Blocks[BlockType]:Clone()
	                                    Fake.Name = "TempBlock"
	                                    Fake.Position = BlockPosition
	                                    Fake:AddTag("TempBlock")
	                                    Fake:AddTag("Block")
	                                    Fake.Parent = workspace.Map
	                                    BridgeDuel.EffectsController:PlaySound(BlockPosition)
	                                    BridgeDuel.Entity.LocalEntity:RemoveTool(BlockName, 1)
	
	                                    task.spawn(function()
	                                        local Success, PlacedBlock = BridgeDuel.Blink.item_action.place_block.invoke({
	                                            position = BlockPosition,
	                                            block_type = BlockType,
	                                            extra = {
	                                                rizz = "Bro.",
	                                                owo = "What's this? OwO",
	                                                those = nil,
	                                                those = workspace.Name == "Ok"
	                                            }
	                                        })
	                                        Fake:Destroy()
	                                        if not (Success or PlacedBlock) then
	                                            BridgeDuel.Entity.LocalEntity:AddTool(BlockName, 1)
	                                        end
	                                    end)
	                                end
	                            end
	                            LastPosition = CurrentPosition
	                        end
	                    end
	                end
	                task.wait(0.03)
	            until not Scaffold.Enabled
	        end
	    end,
	    Tooltip = "Helps you make bridges/scaffold walk."
	})
	Expand = Scaffold:CreateSlider({
	    Name = "Expand",
	    Min = 1,
	    Max = 6
	})
	Tower = Scaffold:CreateToggle({
	    Name = "Tower",
	    Default = true
	})
	Downwards = Scaffold:CreateToggle({
	    Name = "Downwards",
	    Default = true
	})
	Diagonal = Scaffold:CreateToggle({
	    Name = "Diagonal",
	    Default = true
	})
	LimitItem = Scaffold:CreateToggle({Name = "Limit to items"})
end)

Run(function()
	local Breaker
	local Range
	local OnlyPlayer
	
	local function GetBlocksInPoints(Start: Vector3, End: Vector3)
	    local List = {}
	    for X: number = Start.X, End.X, 3 do
	        for Y: number = Start.Y, End.Y, 3 do
	            for Z: number = Start.Z, End.Z, 3 do
	                local Position: Vector3 = Vector3.new(X, Y, Z)
	                if Store.blocks[Position] then
	                    List[Position] = Store.blocks[Position]
	                end
	            end
	        end
	    end
	    return List
	end
	
	local function GetPickaxe(): string?
	    for Name: string in BridgeDuel.Entity.LocalEntity.Inventory do
	        if Name:find("Pickaxe") then
	            return Name
	        end
	    end
	end
	
	Breaker = vape.Categories.World:CreateModule({
	    Name = "Breaker",
	    Function = function(Callback: boolean)
	        if Callback then
	            local BreakBlock
	            local BreakTime: number = 0
	            local LastBreak
	
	            repeat
	                BreakBlock = nil
	
	                if Entity.isAlive then
	                    local Pickaxe: string? = GetPickaxe()
	
	                    if Pickaxe then
	                        local Position: Vector3 = (Entity.character.RootPart.Position // 3) * 3
	                        local RangeVector: Vector3 = Vector3.new(3, 3, 3) * Range.Value
	
	                        for BlockPosition: Vector3, Block: BasePart in GetBlocksInPoints(Position - RangeVector, Position + RangeVector) do
	                            if Block and Block.Name == "Block" and (Block.Parent.Name == "Bed" and LocalPlayer.Team and Block.Parent:GetAttribute("Team") ~= LocalPlayer.Team.Name) then
	                                BreakBlock = Block
	                                break
	                            end
	                        end
	
	                        if BreakBlock ~= LastBreak then
	                            if BreakBlock then
	                                BreakTime = os.clock() + BridgeDuel.BreakTimes[BreakBlock:GetAttribute("block_type") or "Clay"]
	                                BridgeDuel.Blink.item_action.start_break_block.fire({
	                                    position = BreakBlock.Position,
	                                    pickaxe_name = Pickaxe,
	                                    timestamp = workspace:GetServerTimeNow()
	                                })
	                            else
	                                BridgeDuel.Blink.item_action.stop_break_block.fire(false)
	                            end
	                            LastBreak = BreakBlock
	                        elseif BreakBlock and BreakTime < os.clock() then
	                            BridgeDuel.Blink.item_action.stop_break_block.fire(true)
	                            BreakTime = math.huge
	                        end
	                    end
	                end
	
	                task.wait(1 / 60)
	            until not Breaker.Enabled
	        end
	    end,
	    Tooltip = "Breaks enemy blocks around you"
	})
	Range = Breaker:CreateSlider({
	    Name = "Break range",
	    Min = 1,
	    Max = 5,
	    Default = 5,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
end)

Run(function()
	local AutoBuy
	local Sword
	local Armor
	local Pickaxe
	local Upgrades
	local NPCs: {[Instance]: boolean} = {}
	local UpgradeToggles = {}
	local Functions = {}
	local Callbacks = {Functions}
	local NPCTick: number = tick()
	
	local function CanBuy(Item, CurrencyTable, Amount: number?): boolean
	    return (CurrencyTable[Item.currency or "Iron"] or 0) >= (Item.cost * (Amount or 1))
	end
	
	local function BuyItem(Item, ItemTier: number, ItemCategory: string?, CurrencyTable)
	    SendNotification("AutoBuy", `Bought {Item.name}`, 3)
	    task.spawn(function()
	        BridgeDuel.Blink.player_state.bedwars_buy_item.invoke({
	            item = ItemCategory or Item.name,
	            tier = ItemTier
	        })
	    end)
	    CurrencyTable[Item.currency or "Iron"] -= Item.cost
	end
	
	local function BuyTier(Category, CurrencyTable)
	    local NextItem, ItemTier
	    for i: number, v: any in Category.tiers do
	        if CurrencyTable[v.name] then
	            NextItem, ItemTier = Category.tiers[i + 1], i + 1
	            break
	        end
	    end
	
	    if NextItem and CanBuy(NextItem, CurrencyTable) then
	        BuyItem(NextItem, ItemTier, Category.name, CurrencyTable)
	    end
	end
	
	local function BuyUpgrade(Upgrade: string, CurrencyTable): boolean
	    local UpgradeItem = BridgeDuel.BedwarsUpgrades[Upgrade]
	    local LocalTeam = BridgeDuel.Entity.LocalEntity.Team or {Name = ""}
	    local TeamUpgrades = BridgeDuel.Communication.team_upgrades.value[LocalTeam.Name] or {}
	    local CurrentTier: number = (TeamUpgrades[Upgrade] or 0) + 1
	    local Bought: boolean = false
	
	    for i: number = CurrentTier, #UpgradeItem.tiers do
	        local Tier = UpgradeItem.tiers[i]
	
	        if CanBuy({currency = "Diamond", cost = Tier.cost}, CurrencyTable) then
	            SendNotification("AutoBuy", `Bought {Upgrade} {i}`, 3)
	            task.spawn(function()
	                BridgeDuel.Blink.player_state.bedwars_buy_upgrade.invoke(Upgrade)
	            end)
	            CurrencyTable.Diamond -= Tier.cost
	            Bought = true
	        else
	            break
	        end
	    end
	
	    return Bought
	end
	
	local function GetShopNPC()
	    local Shop, Items, UpgradeShop, NewId = nil, false, false, nil
	    if Entity.isAlive then
	        local LocalPosition: Vector3 = Entity.character.RootPart.Position
	        for NPC: Instance, IsUpgrade: boolean in NPCs do
	            if (NPC.Position - LocalPosition).Magnitude <= 10 then
	                Shop = true
	                Items = Items or not IsUpgrade
	                UpgradeShop = IsUpgrade or UpgradeShop
	            end
	        end
	    end
	    return Shop, Items, UpgradeShop
	end
	
	AutoBuy = vape.Categories.Inventory:CreateModule({
	    Name = "AutoBuy",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoBuy:Clean(CollectionService:GetInstanceAddedSignal("menu_opener"):Connect(function(Object: Instance)
	                NPCs[Object.Parent] = Object:GetAttribute("menu") == "TeamUpgrades"
	            end))
	
	            for _, v: Instance in CollectionService:GetTagged("menu_opener") do
	                NPCs[v.Parent] = v:GetAttribute("menu") == "TeamUpgrades"
	            end
	
	            repeat
	                local NPC, Shop, UpgradeShop, NewId = GetShopNPC()
	
	                if NPC and NPCTick <= tick() then
	                    local CurrencyTable = table.clone(BridgeDuel.Entity.LocalEntity.Inventory)
	                    for _, CallbackList: {(...any) -> ...any} in Callbacks do
	                        for _, BuyCallback: (...any) -> ...any in CallbackList do
	                            BuyCallback(CurrencyTable, Shop, UpgradeShop)
	                        end
	                    end
	                    NPCTick = tick() + 0.4
	                end
	
	                task.wait(0.1)
	            until not AutoBuy.Enabled
	        else
	            table.clear(NPCs)
	        end
	    end,
	    Tooltip = "Automatically buys items when you go near the shop"
	})
	Sword = AutoBuy:CreateToggle({
	    Name = "Buy Sword",
	    Function = function(Callback: boolean)
	        NPCTick = tick()
	        Functions[2] = Callback and function(CurrencyTable, Shop: boolean)
	            if not Shop then
	                return
	            end
	            BuyTier(BridgeDuel.BedwarsShop[2].items[1], CurrencyTable)
	        end or nil
	    end,
	    Default = true
	})
	Armor = AutoBuy:CreateToggle({
	    Name = "Buy Armor",
	    Function = function(Callback: boolean)
	        NPCTick = tick()
	        Functions[1] = Callback and function(CurrencyTable, Shop: boolean)
	            if not Shop then
	                return
	            end
	            BuyTier(BridgeDuel.BedwarsShop[2].items[2], CurrencyTable)
	        end or nil
	    end,
	    Default = true
	})
	Pickaxe = AutoBuy:CreateToggle({
	    Name = "Buy Pickaxe",
	    Function = function(Callback: boolean)
	        NPCTick = tick()
	        Functions[3] = Callback and function(CurrencyTable, Shop: boolean)
	            if not Shop then
	                return
	            end
	            BuyTier(BridgeDuel.BedwarsShop[3].items[1], CurrencyTable)
	        end or nil
	    end
	})
	Upgrades = AutoBuy:CreateToggle({
	    Name = "Buy Upgrades",
	    Function = function(Callback: boolean)
	        for _, v: any in UpgradeToggles do
	            v.Object.Visible = Callback
	        end
	    end,
	    Default = true
	})
	local Count: number = 0
	for Upgrade: string, v: any in BridgeDuel.BedwarsUpgrades do
	    local ToggleCount: number = Count
	    table.insert(UpgradeToggles, AutoBuy:CreateToggle({
	        Name = `Buy {Upgrade}`,
	        Function = function(Callback: boolean)
	            NPCTick = tick()
	            Functions[5 + ToggleCount + (Upgrade == "ArmorProtection" and 20 or 0)] = Callback and function(CurrencyTable, Shop: boolean, UpgradeShop: boolean)
	                if not UpgradeShop then
	                    return
	                end
	                return BuyUpgrade(Upgrade, CurrencyTable)
	            end or nil
	        end,
	        Darker = true,
	        Default = (Upgrade == "ArmorProtection" or Upgrade == "SwordDamage")
	    }))
	    Count += 1
	end
end)