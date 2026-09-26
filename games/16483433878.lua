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
local Blocktales = {}

local function SendNotification(...)
    return vape:CreateNotification(...)
end

Run(function()
    Blocktales = {
        Ambassador = require(ReplicatedFirst.Ambassador),
        BattleClient = getsenv(LocalPlayer.PlayerScripts.Battle.BattleClient),
        Enemy = require(ReplicatedFirst.Classes.Entities.Enemy),
        Network = require(ReplicatedFirst.Network),
        Shucky = require(ReplicatedFirst.Modules.Shucky),
        Variables = require(ReplicatedFirst.Variables)
    }

    vape:Clean(function()
        table.clear(Blocktales)
    end)
end)

for _, v: string in {"AimAssist", "Reach", "SilentAim", "TriggerBot", "AntiFall", "HitBoxes", "Invisible", "Jesus", "Killaura", "TargetStrafe", "AntiRagdoll", "Disabler", "MurderMystery", "Freecam", "ChatSpammer", "SpinBot"} do
    vape:Remove(v)
end

Run(function()
	local AutoAction
	local Attack
	local Block
	local Actions = {
	    press = function(Impact: number?, ActionTick: number)
	        if Impact and (Blocktales.Variables.window or 0) > 0 then
	            local Difference: number = (Impact - (Blocktales.Variables.window * 0.3))
	
	            if ActionTick < Impact and Difference <= ActionTick then
	                Blocktales.Ambassador.Fire("ButtonA", "down")
	                Blocktales.Ambassador.Fire("ButtonA", "up")
	            end
	        end
	    end,
	    hold = function(Impact: number?, ActionTick: number)
	        if Blocktales.Variables.promptuheld then
	            if ActionTick <= (Blocktales.Variables.promptuheld + Blocktales.Variables.holdingtime) then
	                local HoldTick: number = (tick() + 0.01 - Blocktales.Variables.atick - Blocktales.Variables.promptuheld) % Blocktales.Variables.loopfor / Blocktales.Variables.loopfor
	                if HoldTick > 0.5 then
	                    HoldTick = 1 - HoldTick
	                end
	
	                HoldTick = math.clamp(HoldTick * 2, 0, 1)
	                if HoldTick > Blocktales.Variables.greenmin + ((Blocktales.Variables.greenmax - Blocktales.Variables.greenmin) / 2) and HoldTick < Blocktales.Variables.greenmax then
	                    Blocktales.Ambassador.Fire("ButtonA", "up")
	                end
	            end
	        else
	            if Blocktales.Variables.holdfrom <= ActionTick and ActionTick <= (Blocktales.Variables.holdfrom + Blocktales.Variables.holdtimeout) then
	                Blocktales.Ambassador.Fire("ButtonA", "down")
	            end
	        end
	    end,
	    mash = function(Impact: number?, ActionTick: number)
	        if Blocktales.Variables.filled and Blocktales.Variables.filled[1] and (tick() - Blocktales.Variables.filled[1]) > 0.5 then
	            local Gui = LocalPlayer.PlayerGui.HUD.Battle.DOITNOW3
	            local Checker = Gui.Meter.checker
	            local FillBar = Gui.Meter.Fill
	            local FillPosition: number = FillBar.AbsoluteSize.X + FillBar.AbsolutePosition.X
	
	            for _, v: GuiObject in Checker:GetChildren() do
	                if not v:GetAttribute("Skipped") then
	                    local CheckPosition: number = (v.AbsolutePosition.X - 6)
	                    if FillPosition > CheckPosition + (v.AbsoluteSize.X / 2) and FillPosition <= (CheckPosition + v.AbsoluteSize.X + 12) then
	                        Blocktales.Ambassador.Fire("ButtonA", "down")
	                        Blocktales.Ambassador.Fire("ButtonA", "up")
	                        break
	                    end
	                end
	            end
	        end
	    end
	}
	
	local function IsMyTurn(): boolean
	    if Blocktales.Variables.myturn and Blocktales.Variables.arena and Blocktales.Variables.arena:GetAttribute("State") == "Attacking" then
	        if Attack.Enabled and Blocktales.Variables.itsme then
	            return true
	        end
	
	        if Block.Enabled and not Blocktales.Variables.itsme then
	            return true
	        end
	    end
	
	    return false
	end
	
	AutoAction = vape.Categories.Combat:CreateModule({
	    Name = "AutoAction",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                if IsMyTurn() then
	                    local Impact: number? = Blocktales.Variables.timehere or Blocktales.Variables.impact
	                    local ActionTick: number = tick() - (Blocktales.Variables.atick or 0)
	
	                    if Actions[Blocktales.Variables.atktype] then
	                        Actions[Blocktales.Variables.atktype](Impact, ActionTick)
	                    end
	                end
	
	                task.wait()
	            until not AutoAction.Enabled
	        end
	    end,
	    Tooltip = "Automatically dodge any incoming attacks to negate damage."
	})
	Attack = AutoAction:CreateToggle({
	    Name = "Attacks",
	    Default = true,
	    Tooltip = "Automatically input for attack moves."
	})
	Block = AutoAction:CreateToggle({
	    Name = "Block",
	    Default = true,
	    Tooltip = "Automatically dodge incoming attack moves."
	})
end)

Run(function()
	local MissCooldown
	local ConstantIndex: number = game.PlaceId ~= 16483433878 and 20 or 53
	
	MissCooldown = vape.Categories.Combat:CreateModule({
	    Name = "MissCooldown",
	    Function = function(Callback: boolean)
	        if Callback then
	            debug.setconstant(Blocktales.BattleClient.input, ConstantIndex, 0)
	        else
	            debug.setconstant(Blocktales.BattleClient.input, ConstantIndex, 0.2)
	        end
	    end,
	    Tooltip = "Remove the cooldown when missing a block or action."
	})
end)

Run(function()
	local AntiHazard
	local Old
	
	AntiHazard = vape.Categories.Blatant:CreateModule({
	    Name = "AntiHazard",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = hookfunction(Blocktales.Network.FireServer, function(...)
	                local Event = ...
	                if Event == "TakeDamage" then
	                    return
	                end
	
	                return Old(...)
	            end)
	        else
	            if Old then
	                hookfunction(Blocktales.Network.FireServer, Old)
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Prevent you from taking damage in the overworld section."
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
                    if Entity.isAlive then
                        local Root: BasePart = Entity.character.RootPart
                        local State: Enum.HumanoidStateType = Entity.character.Humanoid:GetState()
                        if State == Enum.HumanoidStateType.Climbing or Blocktales.Variables.transitioning then
                            return
                        end

                        local MoveVector: Vector3 = Entity.character.Humanoid.MoveDirection * Value.Value
                        Root.AssemblyLinearVelocity = Vector3.new(MoveVector.X, 1 + ((Up + Down) * VerticalValue.Value), MoveVector.Z)
                    end
                end))

                Up, Down = 0, 0
                for _, v: string in {"InputBegan", "InputEnded"} do
                    Fly:Clean(UserInputService[v]:Connect(function(Input: InputObject)
                        if not UserInputService:GetFocusedTextBox() then
                            if Input.KeyCode == Enum.KeyCode.Space then
                                Up = v == "InputBegan" and 1 or 0
                            elseif Input.KeyCode == Enum.KeyCode.LeftControl then
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
            return "Velocity"
        end,
        Tooltip = "Makes you go zoom."
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
	local FlyingAttack
	
	FlyingAttack = vape.Categories.Blatant:CreateModule({
	    Name = "FlyingAttack",
	    Function = function(Callback: boolean)
	        if Callback then
	            debug.setconstant(Blocktales.Shucky.PossibleFirst, 7, "_Flying")
	        else
	            debug.setconstant(Blocktales.Shucky.PossibleFirst, 7, "Flying")
	        end
	    end,
	    Tooltip = "Allow you to attack flying enemies with onground attacks."
	})
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
	                    if Entity.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
	                        if Exempt < tick() and AutoDisable.Enabled then
	                            if LongJump.Enabled then
	                                LongJump:Toggle()
	                            end
	                        else
	                            Entity.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	                        end
	                    end
	
	                    local Root: BasePart = Entity.character.RootPart
	                    local State: Enum.HumanoidStateType = Entity.character.Humanoid:GetState()
	                    if State == Enum.HumanoidStateType.Climbing or Blocktales.Variables.transitioning then
	                        return
	                    end
	
	                    local MoveVector: Vector3 = Entity.character.Humanoid.MoveDirection * Value.Value
	                    Root.AssemblyLinearVelocity = Vector3.new(MoveVector.X, Root.AssemblyLinearVelocity.Y, MoveVector.Z)
	                end
	            end))
	        end
	    end,
	    ExtraText = function()
	        return "Velocity"
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
	local PickupTP
	
	PickupTP = vape.Categories.Blatant:CreateModule({
	    Name = "PickupTP",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Old: CFrame?
	            repeat
	                if Entity.isAlive then
	                    local Success: boolean = true
	                    for _, v: BasePart in CollectionService:GetTagged("Pickup") do
	                        if not v:GetAttribute("Inactive") then
	                            if not Old then
	                                Old = Entity.character.RootPart.CFrame
	                            end
	
	                            Success = false
	                            Entity.character.RootPart.CFrame = v.CFrame
	                            break
	                        end
	                    end
	
	                    if Success and Old then
	                        Entity.character.RootPart.CFrame = Old
	                        Old = nil
	                    end
	                else
	                    Old = nil
	                end
	
	                task.wait(0.4)
	            until not PickupTP.Enabled
	        end
	    end,
	    Tooltip = "Teleport to any nearby active pickups."
	})
end)

Run(function()
	local Speed
	local Value
	
	Speed = vape.Categories.Blatant:CreateModule({
	    Name = "Speed",
	    Function = function(Callback: boolean)
	        if Callback then
	            Speed:Clean(RunService.PreSimulation:Connect(function(Delta: number)
	                if Entity.isAlive and not Fly.Enabled and not LongJump.Enabled then
	                    local Root: BasePart = Entity.character.RootPart
	                    local State: Enum.HumanoidStateType = Entity.character.Humanoid:GetState()
	                    if State == Enum.HumanoidStateType.Climbing or Blocktales.Variables.transitioning then
	                        return
	                    end
	
	                    local MoveVector: Vector3 = Entity.character.Humanoid.MoveDirection * Value.Value
	                    Root.AssemblyLinearVelocity = Vector3.new(MoveVector.X, Root.AssemblyLinearVelocity.Y, MoveVector.Z)
	                end
	            end))
	        end
	    end,
	    ExtraText = function()
	        return "Velocity"
	    end,
	    Tooltip = "Increases your movement with various methods."
	})
	Value = Speed:CreateSlider({
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
	local SpeedSpin
	local Value
	local Old
	
	SpeedSpin = vape.Categories.Blatant:CreateModule({
	    Name = "SpeedSpin",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = hookfunction(Blocktales.Shucky.HasBadge, function(...)
	                local self, Badge = ...
	                if Badge == "Speed Spin" then
	                    return Value.Value
	                end
	
	                return Old(...)
	            end)
	        else
	            if Old then
	                hookfunction(Blocktales.Shucky.HasBadge, Old)
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Spoof the amount of speed spin cards you possess."
	})
	Value = SpeedSpin:CreateSlider({
	    Name = "Card Amount",
	    Min = 0,
	    Max = 10,
	    Default = 4
	})
end)

Run(function()
	local PickupTracers
	local Color
	local Transparency
	local Bux
	local Reference = {}
	
	local function Added(Pickup: BasePart)
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    if Bux.Enabled and Pickup.Name ~= "BUX" then
	        return
	    end
	
	    local EntityTracer = Drawing.new("Line")
	    EntityTracer.Thickness = 1
	    EntityTracer.Transparency = 1 - Transparency.Value
	    EntityTracer.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	    Reference[Pickup] = EntityTracer
	end
	
	local function Removed(Pickup: BasePart)
	    local Tracer = Reference[Pickup]
	    if Tracer then
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	
	        Reference[Pickup] = nil
	        pcall(function()
	            Tracer.Visible = false
	            Tracer:Remove()
	        end)
	    end
	end
	
	local function ColorFunc(Hue: number, Sat: number, Val: number)
	    local TracerColor: Color3 = Color3.fromHSV(Hue, Sat, Val)
	    for Pickup: BasePart, EntityTracer: any in Reference do
	        EntityTracer.Color = TracerColor
	    end
	end
	
	local function Loop()
	    local ScreenSize: Vector2 = vape.gui.AbsoluteSize
	    local StartVector: Vector2 = Vector2.new(ScreenSize.X / 2, ScreenSize.Y / 2)
	
	    for Pickup: BasePart, EntityTracer: any in Reference do
	        if Pickup:GetAttribute("Inactive") then
	            EntityTracer.Visible = false
	            continue
	        end
	
	        local Position: Vector3 = Pickup.Position
	        local RootPos, RootVisible = Camera:WorldToViewportPoint(Position)
	
	        if not RootVisible then
	            local TempPosition: Vector3 = Camera.CFrame:PointToObjectSpace(Position)
	            TempPosition = CFrame.Angles(0, 0, (math.atan2(TempPosition.Y, TempPosition.X) + math.pi)):VectorToWorldSpace((CFrame.Angles(0, math.rad(89.9), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))))
	            RootPos = Camera:WorldToViewportPoint(Camera.CFrame:pointToWorldSpace(TempPosition))
	            RootVisible = true
	        end
	
	        local EndVector: Vector2 = Vector2.new(RootPos.X, RootPos.Y)
	        EntityTracer.Visible = RootVisible
	        EntityTracer.From = StartVector
	        EntityTracer.To = EndVector
	    end
	end
	
	PickupTracers = vape.Categories.Render:CreateModule({
	    Name = "PickupTracers",
	    Function = function(Callback: boolean)
	        if Callback then
	            PickupTracers:Clean(CollectionService:GetInstanceAddedSignal("Pickup"):Connect(function(Pickup: BasePart)
	                if Reference[Pickup] then
	                    Removed(Pickup)
	                end
	                Added(Pickup)
	            end))
	            PickupTracers:Clean(CollectionService:GetInstanceRemovedSignal("Pickup"):Connect(Removed))
	            for _, v: BasePart in CollectionService:GetTagged("Pickup") do
	                if Reference[v] then
	                    Removed(v)
	                end
	                Added(v)
	            end
	            PickupTracers:Clean(RunService.RenderStepped:Connect(Loop))
	        else
	            for Pickup: BasePart in Reference do
	                Removed(Pickup)
	            end
	        end
	    end,
	    Tooltip = "Renders tracers on pickups."
	})
	Color = PickupTracers:CreateColorSlider({
	    Name = "BUX Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        if PickupTracers.Enabled then
	            ColorFunc(Hue, Sat, Val)
	        end
	    end
	})
	Transparency = PickupTracers:CreateSlider({
	    Name = "Transparency",
	    Min = 0,
	    Max = 1,
	    Function = function(Val: number)
	        for _, v: any in Reference do
	            v.Transparency = 1 - Val
	        end
	    end,
	    Decimal = 10
	})
	Bux = PickupTracers:CreateToggle({
	    Name = "Bux Only",
	    Function = function()
	        if PickupTracers.Enabled then
	            PickupTracers:Toggle()
	            PickupTracers:Toggle()
	        end
	    end,
	    Tooltip = "Hides non BUX pickups"
	})
end)

Run(function()
	local AutoCamel
	
	AutoCamel = vape.Categories.Utility:CreateModule({
	    Name = "AutoCamel",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Camel: Instance? = workspace.NPCs:FindFirstChild("Abu Baba")
	            if not Camel then
	                SendNotification("AutoCamel", "Missing camel seller!", 5, "warning")
	                AutoCamel:Toggle()
	                return
	            end
	
	            local RunModule = require(Camel.Dialogue:FindFirstChild("RunScript", true).ModuleScript)
	            repeat
	                if (LocalPlayer:GetAttribute("TIX") or 0) >= 30 then
	                    RunModule:Run()
	                end
	
	                task.wait(0.5)
	            until not AutoCamel.Enabled
	        end
	    end,
	    Tooltip = "Automatically buy camels"
	})
end)

Run(function()
	local AutoCloudGrind
	
	AutoCloudGrind = vape.Categories.Utility:CreateModule({
	    Name = "AutoCloudGrind",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                if Blocktales.Variables.arena and Blocktales.Variables.arena:GetAttribute("State") == "Picking" then
	                    local ShouldRun: boolean = true
	                    for _, v: ObjectValue in Blocktales.Variables.arena.Goon:GetChildren() do
	                        local Drop = v.Value and v.Value:GetAttribute("Item_Drop")
	
	                        if Drop and Drop:find("FX ") and not Blocktales.Variables.data.CardCollection[Drop] then
	                            ShouldRun = false
	                        end
	                    end
	
	                    if ShouldRun then
	                        Blocktales.Network.FireServer("CommitToMove", "Run Away", nil, nil)
	                        task.wait(3)
	                    else
	                        workspace.Sounds.Money:Play()
	                        workspace.Sounds.Money.Ended:Wait()
	                    end
	                end
	
	                task.wait(0.05)
	            until not AutoCloudGrind.Enabled
	        end
	    end,
	    Tooltip = "Automatically grind for SFX Cards from Cloudie (floor 51)"
	})
end)

Run(function()
	local AutoFish
	local KeepList
	local Old
	
	AutoFish = vape.Categories.Utility:CreateModule({
	    Name = "AutoFish",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Fisherman: Instance? = workspace.NPCs:FindFirstChild("The Seller")
	            if not Fisherman then
	                SendNotification("AutoFish", "Missing fisherman!", 5, "warning")
	                AutoFish:Toggle()
	                return
	            end
	
	            Old = workspace.Sounds.Money.Volume
	            workspace.Sounds.Money.Volume = 0
	
	            repeat
	                local Fish = LocalPlayer.Status:GetAttribute("NextFish")
	                local Result = Blocktales.Network.InvokeServer("FishItem")
	                if Result == true then
	                    if not table.find(KeepList.ListEnabled, Fish) then
	                        Blocktales.Network.InvokeServer("UseItem", Fish, Fisherman)
	                    end
	
	                    Blocktales.Network.InvokeServer("BuyItem", Fisherman.ShopItems:GetChildren()[1], Fisherman)
	                end
	
	                task.wait()
	            until not AutoFish.Enabled
	        else
	            if Old then
	                workspace.Sounds.Money.Volume = Old
	            end
	        end
	    end,
	    Tooltip = "Automatically sell and buy fish"
	})
	KeepList = AutoFish:CreateTextList({
	    Name = "Keep List",
	    Placeholder = "item"
	})
end)

Run(function()
	local AutoPaint
	
	AutoPaint = vape.Categories.Utility:CreateModule({
	    Name = "AutoPaint",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Gui = LocalPlayer.PlayerGui.HUD.Painter
	            local Canvas = Gui:FindFirstChild("CanvasTime", true).Parent
	            local ColorPicker = Gui.ColorPicker
	
	            repeat
	                if Gui.Visible and Blocktales.Variables.paintingflag and not Blocktales.Variables.canvas:GetAttribute("Completed") then
	                    local Solution = Blocktales.Variables.canvas.Parent:FindFirstChild("Solution Easel")
	
	                    if Solution then
	                        for _, v: Instance in Solution.solution:GetDescendants() do
	                            if v:IsA("BasePart") and Blocktales.Variables.canvas[v.Parent.Name][v.Name].BrickColor ~= v.BrickColor then
	                                local Element = Canvas:FindFirstChild(`{v.Parent.Name:sub(4)}_{v.Name}`)
	                                if Element then
	                                    for _, ColorButton: GuiObject in ColorPicker:GetChildren() do
	                                        if ColorButton:GetAttribute("BGColor") == v.BrickColor.Color then
	                                            Blocktales.Ambassador.Fire("ButtonPress", ColorButton)
	                                            break
	                                        end
	                                    end
	
	                                    Blocktales.Ambassador.Fire("ButtonPress", Element)
	                                end
	
	                                break
	                            end
	                        end
	                    end
	                end
	
	                task.wait(0.05)
	            until not AutoPaint.Enabled
	        end
	    end,
	    Tooltip = "Automatically paint canvas photos"
	})
end)