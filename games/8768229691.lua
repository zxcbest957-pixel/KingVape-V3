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
local CollectionService: CollectionService = cloneref(game:GetService("CollectionService"))
local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local CoreGui: CoreGui = cloneref(game:GetService("CoreGui"))
local TweenService: TweenService = cloneref(game:GetService("TweenService"))
local RunService: RunService = cloneref(game:GetService("RunService"))

local Camera: Camera = workspace.CurrentCamera
local LocalPlayer: Player = Players.LocalPlayer
local AssetFunction = getcustomasset

local vape = shared.vape
local Entity = vape.Libraries.entity
local TargetInfo = vape.Libraries.targetinfo
local SessionInfo = vape.Libraries.sessioninfo
local UIPallet = vape.Libraries.uipallet
local Tween = vape.Libraries.tween
local Color = vape.Libraries.color
local Whitelist = vape.Libraries.whitelist
local PredictionLib = vape.Libraries.prediction
local GetVapeAsset = vape.Libraries.getvapeasset

local Skywars, Remotes = {}, {}
local Store = {
    blocks = {},
    hand = {},
    inventory = {},
    tools = {},
    noShoot = tick()
}
local ViewmodelTool
local ViewmodelMotor

local function Collection(Tags, Module, CustomAdd, CustomRemove)
    Tags = typeof(Tags) ~= "table" and {Tags} or Tags
    local Objects, Connections = {}, {}

    for _, Tag: string in Tags do
        table.insert(Connections, CollectionService:GetInstanceAddedSignal(Tag):Connect(function(v)
            if CustomAdd then
                CustomAdd(Objects, v, Tag)
                return
            end
            table.insert(Objects, v)
        end))
        table.insert(Connections, CollectionService:GetInstanceRemovedSignal(Tag):Connect(function(v)
            if CustomRemove then
                CustomRemove(Objects, v, Tag)
                return
            end
            v = table.find(Objects, v)
            if v then
                table.remove(Objects, v)
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

local function GetItem(ItemType: string)
    for _, Item: any in Store.inventory do
        if Item.Type == ItemType then
            return Item
        end
    end
end

local function GetSword()
    local BestSword, BestSwordSlot, BestSwordDamage = nil, nil, 0
    for Slot: any, Item: any in Store.inventory do
        Item = Skywars.ItemMeta[Item.Type]
        local SwordDamage: number = Item.Melee and Item.Melee.Damage or 0
        if SwordDamage > BestSwordDamage then
            BestSword, BestSwordSlot, BestSwordDamage = Item, Slot, SwordDamage
        end
    end
    return BestSword, BestSwordSlot
end

local function GetPickaxe()
    local BestPick, BestPickSlot, BestPickDamage = nil, nil, math.huge
    for Slot: any, Item: any in Store.inventory do
        Item = Skywars.ItemMeta[Item.Type]
        local PickDamage: number = Item.Pickaxe and Item.Pickaxe.TimeMultiplier or math.huge
        if PickDamage < BestPickDamage then
            BestPick, BestPickSlot, BestPickDamage = Item, Slot, PickDamage
        end
    end
    return BestPick, BestPickSlot
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

local function ParsePositions(Block: Instance, Callback)
    if Block:IsA("Part") and Block.Size // 1 == Block.Size then
        local Start: Vector3 = (Block.Position - (Block.Size / 2)) + Vector3.new(1.5, 1.5, 1.5)
        for X: number = 0, Block.Size.X - 1, 3 do
            for Y: number = 0, Block.Size.Y - 1, 3 do
                for Z: number = 0, Block.Size.Z - 1, 3 do
                    Callback(Start + Vector3.new(X, Y, Z))
                end
            end
        end
    end
end

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

Run(function()
    Entity.addPlayer = function(Player: Player)
        if Player.Character then
            Entity.refreshEntity(Player.Character, Player)
        end
        Entity.PlayerConnections[Player] = {
            Player.CharacterAdded:Connect(function(Character: Model)
                Entity.refreshEntity(Character, Player)
            end),
            Player.CharacterRemoving:Connect(function(Character: Model)
                Entity.removeEntity(Character, Player == LocalPlayer)
            end),
            Player:GetAttributeChangedSignal("TeamId"):Connect(function()
                for _, v: any in Entity.List do
                    if v.Targetable ~= Entity.targetCheck(v) then
                        Entity.refreshEntity(v.Character, v.Player)
                    end
                end

                if Player == LocalPlayer then
                    Entity.start()
                else
                    Entity.refreshEntity(Player.Character, Player)
                end
            end)
        }
    end

    Entity.addEntity = function(Character, Player, TeamFunc)
        if not Character then
            return
        end
        Entity.EntityThreads[Character] = task.spawn(function()
            local Humanoid = WaitForChildOfType(Character, "Humanoid", 10)
            local HumanoidRootPart = Humanoid and WaitForChildOfType(Humanoid, "RootPart", workspace.StreamingEnabled and 9e9 or 10, true)
            local Head = Character:WaitForChild("Head", 10) or HumanoidRootPart

            if Humanoid and HumanoidRootPart then
                local Target = {
                    Connections = {},
                    Character = Character,
                    Health = (Player:GetAttribute("Health") or 100),
                    Head = Head,
                    Humanoid = Humanoid,
                    HumanoidRootPart = HumanoidRootPart,
                    HipHeight = Humanoid.HipHeight + (HumanoidRootPart.Size.Y / 2) + (Humanoid.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
                    MaxHealth = 100,
                    NPC = Player == nil,
                    Player = Player,
                    RootPart = HumanoidRootPart,
                    TeamCheck = TeamFunc
                }

                if Player == LocalPlayer then
                    Target.GroundPosition = Vector3.zero
                    Entity.character = Target
                    Entity.isAlive = true
                    Entity.Events.LocalAdded:Fire(Target)
                else
                    Target.Targetable = (TeamFunc or Entity.targetCheck)(Target)

                    for _, v: RBXScriptSignal in Entity.getUpdateConnections(Target) do
                        table.insert(Target.Connections, v:Connect(function()
                            Target.Health = (Player:GetAttribute("Health") or 100)
                            Entity.Events.EntityUpdated:Fire(Target)
                        end))
                    end

                    table.insert(Entity.List, Target)
                    Entity.Events.EntityAdded:Fire(Target)
                end
            end
            Entity.EntityThreads[Character] = nil
        end)
    end

    Entity.getUpdateConnections = function(Ent)
        return {
            Ent.Player:GetAttributeChangedSignal("Health"),
            {
                Connect = function()
                    Ent.Friend = Ent.Player and IsFriend(Ent.Player) or nil
                    Ent.Target = Ent.Player and IsTarget(Ent.Player) or nil
                    return {Disconnect = function() end}
                end
            }
        }
    end

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
        return LocalPlayer:GetAttribute("TeamId") ~= Ent.Player:GetAttribute("TeamId")
    end

    Entity.getEntityColor = function(Ent)
        Ent = Ent.Player
        if not (Ent and vape.Settings.Modules.Options["Use team color"].Enabled) then
            return
        end
        if IsFriend(Ent, true) then
            return Color3.fromHSV(vape.Categories.Friends.Options["Friends color"].Hue, vape.Categories.Friends.Options["Friends color"].Sat, vape.Categories.Friends.Options["Friends color"].Value)
        end
        return Skywars.TeamController:getTeamColour(Ent:GetAttribute("TeamId"))
    end
end)
Entity.start()

Run(function()
    local Flamework = require(ReplicatedStorage["rbxts_include"]["node_modules"]["@flamework"].core.out).Flamework
    local ControllerTable = {}

    if not debug.getupvalue(Flamework.ignite, 1) then
        repeat
            task.wait()
        until debug.getupvalue(Flamework.ignite, 1)
    end

    local function SearchFunction(Name: string, Key, Func)
        for _, Constant: number | string | boolean in debug.getconstants(Func) do
            if tostring(Constant):find("-") == 9 then
                Remotes[`{rawget(Remotes, Key) and `{Name}:` or ""}{Key}`] = Constant
            end
        end
    end

    for Id: any, Controller: any in debug.getupvalue(Flamework.ignite, 2).idToObj do
        local Name: string = tostring(Controller)
        ControllerTable[Name] = Flamework.resolveDependency(Id)
        for Key: string, Method: any in Controller do
            if type(Method) == "function" then
                SearchFunction(Name, Key, Method)

                for _, Proto: (...any) -> ...any in debug.getprotos(Method) do
                    SearchFunction(Name, Key, Proto)
                end
            end
        end
    end

    local RoactCheck = ReplicatedStorage["rbxts_include"]["node_modules"]["@rbxts"]:FindFirstChild("roact")
    Skywars = setmetatable({
        CameraUtil = require(LocalPlayer.PlayerScripts.TS.util["camera-util"]).CameraUtil,
        FireOrigin = debug.getupvalue(ControllerTable.ProjectileController.chargeBow, 11).ORIGIN_OFFSET,
        Gravity = debug.getupvalue(ControllerTable.ProjectileController.chargeBow, 13).WORLD_ACCELERATION.Y,
        ItemMeta = debug.getupvalue(ControllerTable.HotbarController.getSword, 1),
        Remotes = debug.getupvalue(ControllerTable.MeleeController.strikeDesktop, 6),
        Roact = require(RoactCheck and RoactCheck.src or ReplicatedStorage["rbxts_include"]["node_modules"]["@rbxts"].ReactLua["node_modules"]["@jsdotlua"]["roact-compat"]),
        Store = require(LocalPlayer.PlayerScripts.TS.ui.rodux["global-store"]).GlobalStore,
        Shop = require(ReplicatedStorage.TS.game.shop["game-shop"]).Shops
    }, {
        __index = function(self, Index)
            rawset(self, Index, ControllerTable[Index])
            return rawget(self, Index)
        end
    })

    local Kills = SessionInfo:AddItem("Kills")
    local Eggs = SessionInfo:AddItem("Eggs")
    local Wins = SessionInfo:AddItem("Wins")
    local Games = SessionInfo:AddItem("Games")

    task.delay(1, function()
        Games:Increment()
    end)

    local function UpdateStore(NewStore, OldStore)
        if NewStore.GameCurrency ~= OldStore.GameCurrency then
            VapeEvents.CurrencyChange:Fire(table.clone(NewStore.GameCurrency.Quantities))
        end

        if NewStore.ActiveSlot ~= OldStore.ActiveSlot then
            Store.hand = NewStore.Inventory.Contents[NewStore.ActiveSlot]
            Store.hand = Store.hand and Skywars.ItemMeta[Store.hand.Type] or {}
        end

        if NewStore.Inventory ~= OldStore.Inventory then
            Store.inventory = NewStore.Inventory.Contents
            Store.hand = NewStore.Inventory.Contents[NewStore.ActiveSlot]
            Store.hand = Store.hand and Skywars.ItemMeta[Store.hand.Type] or {}
            Store.tools.sword = GetSword()
            Store.tools.pickaxe = GetPickaxe()
            VapeEvents.InventoryAmountChanged:Fire()
        end

        if OldStore.Profile and OldStore.Profile.WasTeleporting and NewStore.Profile.Stats ~= OldStore.Profile.Stats then
            if NewStore.Profile.Stats.Kills ~= OldStore.Profile.Stats.Kills and OldStore.Profile.Stats.Kills then
                Kills:Increment()
            end

            if NewStore.Profile.Stats.Wins ~= OldStore.Profile.Stats.Wins and OldStore.Profile.Stats.Wins then
                Wins:Increment()
            end
        end
    end

    local StoreChanged = Skywars.Store.changed:connect(UpdateStore)
    UpdateStore(Skywars.Store:getState(), {})

    task.spawn(function()
        repeat
            if Entity.isAlive then
                Entity.character.GroundPosition = Entity.character.Humanoid.FloorMaterial ~= Enum.Material.Air and Entity.character.RootPart.Position or Entity.character.GroundPosition
            end
            task.wait()
        until vape.Loaded == nil
    end)

    vape:Clean(workspace.BlockContainer.DescendantAdded:Connect(function(v)
        ParsePositions(v, function(Position: Vector3)
            Store.blocks[Position] = v
        end)
    end))
    vape:Clean(workspace.BlockContainer.DescendantRemoving:Connect(function(v)
        ParsePositions(v, function(Position: Vector3)
            Store.blocks[Position] = nil
        end)
    end))
    for _, v: Instance in workspace.BlockContainer:GetDescendants() do
        ParsePositions(v, function(Position: Vector3)
            Store.blocks[Position] = v
        end)
    end

    vape:Clean(function()
        for _, v: BindableEvent in VapeEvents do
            v:Destroy()
        end
        table.clear(ControllerTable)
        table.clear(Remotes)
        table.clear(VapeEvents)
        table.clear(Skywars)
        table.clear(Store.blocks)
        table.clear(Store)
        StoreChanged:disconnect()
        StoreChanged = nil
    end)
end)

for _, v: string in {"Reach", "TriggerBot", "Disabler", "SilentAim", "AutoRejoin", "Rejoin", "ServerHop", "MurderMystery"} do
    vape:Remove(v)
end

Run(function()
	local AutoClicker
	local CPS
	local Blocks
	local BlocksCPS = {Object = {}}
	local Thread
	local Old
	
	local function AutoClick()
	    Thread = task.delay(1 / 8, function()
	        repeat
	            local Held = Store.hand
	            if Held then
	                if Held.Rewrite and Blocks.Enabled then
	                    local Block = Skywars.ItemMeta[Held.Rewrite.Type:gsub("{TeamId}", Skywars.TeamController:getPlayerTeamId(LocalPlayer) or "White")]
	                    local RayResult = Skywars.BlockRaycastController:executeRaycast(UserInputService:GetMouseLocation(), 1, 0, Block)
	                    if RayResult and RayResult.BlockPosition then
	                        Skywars.BlockController:placeBlock(RayResult.BlockPosition, Held.Name, Block, RayResult.Rotation)
	                    end
	                elseif Held.Melee then
	                    Skywars.MeleeController:strike(Held)
	                end
	            end
	
	            task.wait(1 / (Held and Held.Rewrite and BlocksCPS or CPS).GetRandomValue())
	        until not AutoClicker.Enabled
	    end)
	end
	
	AutoClicker = vape.Categories.Combat:CreateModule({
	    Name = "AutoClicker",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoClicker:Clean(UserInputService.InputBegan:Connect(function(Input: InputObject, GameProcessed: boolean)
	                if not GameProcessed and Input.UserInputType == Enum.UserInputType.MouseButton1 then
	                    AutoClick()
	                end
	            end))
	
	            AutoClicker:Clean(UserInputService.InputEnded:Connect(function(Input: InputObject)
	                if Input.UserInputType == Enum.UserInputType.MouseButton1 and Thread then
	                    task.cancel(Thread)
	                    Thread = nil
	                end
	            end))
	        end
	    end,
	    Tooltip = "Hold attack button to automatically click"
	})
	CPS = AutoClicker:CreateTwoSlider({
	    Name = "CPS",
	    Min = 1,
	    Max = 9,
	    DefaultMin = 9,
	    DefaultMax = 9
	})
	Blocks = AutoClicker:CreateToggle({
	    Name = "Place Blocks",
	    Default = true,
	    Function = function(Callback: boolean)
	        BlocksCPS.Object.Visible = Callback
	    end
	})
	BlocksCPS = AutoClicker:CreateTwoSlider({
	    Name = "Block CPS",
	    Min = 1,
	    Max = 20,
	    DefaultMin = 9,
	    DefaultMax = 9,
	    Darker = true
	})
end)

Run(function()
	local Sprint
	local Old
	
	Sprint = vape.Categories.Combat:CreateModule({
	    Name = "Sprint",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = Skywars.SprintingController.disableSprinting
	            Skywars.SprintingController.disableSprinting = function(Controller, ...)
	                local Result = Old(Controller, ...)
	
	                if not Controller.canSprint then
	                    task.spawn(function()
	                        repeat
	                            task.wait(0.1)
	                        until Controller.canSprint or not Sprint.Enabled
	
	                        if Sprint.Enabled then
	                            Skywars.SprintingController:enableSprinting(Controller)
	                        end
	                    end)
	                else
	                    Skywars.SprintingController:enableSprinting(Controller)
	                end
	
	                return Result
	            end
	
	            Sprint:Clean(Entity.Events.LocalAdded:Connect(function()
	                Skywars.SprintingController:disableSprinting()
	            end))
	
	            Skywars.SprintingController:disableSprinting()
	        else
	            Skywars.SprintingController.disableSprinting = Old
	            Skywars.SprintingController:disableSprinting()
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
	local RandomGenerator, Old = Random.new()
	
	local function VelocityFunction(...)
	    if RandomGenerator:NextNumber(0, 100) > Chance.Value then
	        return Old(...)
	    end
	
	    local Args = table.pack(...)
	    local Check = (not Targeting.Enabled) or Entity.EntityPosition({
	        Range = 50,
	        Part = "RootPart",
	        Players = true
	    })
	
	    if Check then
	        local HorizontalFactor, VerticalFactor = (Horizontal.Value / 100), (Vertical.Value / 100)
	        if HorizontalFactor == 0 and VerticalFactor == 0 then
	            return
	        end
	        Args[1] = Vector3.new(Args[1].X * HorizontalFactor, Args[1].Y * VerticalFactor, Args[1].Z * HorizontalFactor)
	    end
	
	    return Old(unpack(Args, 1, Args.n))
	end
	
	Velocity = vape.Categories.Combat:CreateModule({
	    Name = "Velocity",
	    Function = function(Callback: boolean)
	        if Callback then
	            Connection = getconnections(debug.getupvalue(debug.getupvalue(Skywars.Remotes[Remotes["PlayerVelocityController:onStart"]].connect, 1).fireClient, 1).OnClientEvent)[1]
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
	local AntiFall
	local Mode
	local Material
	local Color
	local Part
	
	local function GetLowGround()
	    local LowestY: number = math.huge
	    for Position: Vector3 in Store.blocks do
	        if Position.Y < LowestY and not Store.blocks[Position + Vector3.new(0, 3, 0)] then
	            LowestY = Position.Y
	        end
	    end
	    return LowestY
	end
	
	AntiFall = vape.Categories.Blatant:CreateModule({
	    Name = "AntiFall",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Position, Debounce = GetLowGround(), tick()
	            if Position ~= math.huge then
	                local Middle = next(Store.blocks)
	                Part = Instance.new("Part")
	                Part.Size = Vector3.new(10000, 1, 10000)
	                Part.Transparency = 1 - Color.Opacity
	                Part.Material = Enum.Material[Material.Value]
	                Part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	                Part.Position = Vector3.new(Middle.X, Position - 2, Middle.Z)
	                Part.CanCollide = Mode.Value == "Collide"
	                Part.Anchored = true
	                Part.CanQuery = false
	                Part.Parent = workspace
	                AntiFall:Clean(Part)
	                AntiFall:Clean(Part.Touched:Connect(function(TouchedPart: BasePart)
	                    if TouchedPart.Parent == LocalPlayer.Character and Entity.isAlive and Debounce < tick() then
	                        local Root = Entity.character.RootPart
	                        Debounce = tick() + 0.1
	                        if Mode.Value == "Velocity" then
	                            Root.Velocity = Vector3.new(Root.Velocity.X, 100, Root.Velocity.Z)
	                        end
	                    end
	                end))
	            end
	        end
	    end,
	    Tooltip = "Help's you with your Parkinson's\nPrevents you from falling into the void."
	})
	Mode = AntiFall:CreateDropdown({
	    Name = "Move Mode",
	    List = {"Velocity", "Collide"},
	    Function = function(Val: string)
	        if Part then
	            Part.CanCollide = Val == "Collide"
	        end
	    end,
	    Tooltip = "Velocity - Launches you upward after touching\nCollide - Allows you to walk on the part"
	})
	local Materials: {string} = {"ForceField"}
	for _, v: EnumItem in Enum.Material:GetEnumItems() do
	    if v.Name ~= "ForceField" then
	        table.insert(Materials, v.Name)
	    end
	end
	Material = AntiFall:CreateDropdown({
	    Name = "Material",
	    List = Materials,
	    Function = function(Val: string)
	        if Part then
	            Part.Material = Enum.Material[Val]
	        end
	    end
	})
	Color = AntiFall:CreateColorSlider({
	    Name = "Color",
	    DefaultOpacity = 0.5,
	    Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
	        if Part then
	            Part.Color = Color3.fromHSV(Hue, Sat, Val)
	            Part.Transparency = 1 - Opacity
	        end
	    end
	})
end)

Run(function()
	local InvMove
	local Old
	
	InvMove = vape.Categories.Blatant:CreateModule({
	    Name = "InvMove",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = Skywars.FocusedController.enableFocus
	            Skywars.FocusedController.enableFocus = function(self, Screen, ...)
	                return Old(self, true, ...)
	            end
	        else
	            Skywars.FocusedController.enableFocus = Old
	            Old = nil
	        end
	    end,
	    Tooltip = "Allows you to have continuous movement in menus"
	})
end)

Run(function()
	local Killaura
	local Targets
	local AttackRange
	local AngleCheck
	local Max
	local Mouse
	local Limit
	local Swing
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local AnimTween
	local Attacking
	local Particles, Boxes = {}, {}
	local Animations, ArmC0 = vape.Libraries.auraanims
	
	local function GetAttackData()
	    if Mouse.Enabled then
	        if not UserInputService:IsMouseButtonPressed(0) then
	            return false
	        end
	    end
	
	    return (not Limit.Enabled) and Store.tools.sword or Store.hand
	end
	
	Killaura = vape.Categories.Blatant:CreateModule({
	    Name = "Killaura",
	    Function = function(Callback: boolean)
	        if Callback then
	            if Animation.Enabled then
	                task.spawn(function()
	                    local Started: boolean = false
	                    repeat
	                        if ViewmodelMotor then
	                            if Attacking then
	                                if not ArmC0 then
	                                    ArmC0 = ViewmodelMotor.C0
	                                end
	                                local First: boolean = not Started
	                                Started = true
	
	                                if AnimationMode.Value == "Random" then
	                                    Animations.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
	                                end
	
	                                for _, v: {CFrame: CFrame, Time: number} in Animations[AnimationMode.Value] do
	                                    AnimTween = TweenService:Create(ViewmodelMotor, TweenInfo.new(First and (AnimationTween.Enabled and 0.001 or 0.1) or v.Time / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
	                                        C0 = ArmC0 * v.CFrame
	                                    })
	                                    AnimTween:Play()
	                                    AnimTween.Completed:Wait()
	                                    First = false
	                                    if (not Killaura.Enabled) or (not Attacking) then
	                                        break
	                                    end
	                                end
	                            elseif Started then
	                                Started = false
	                                AnimTween = TweenService:Create(ViewmodelMotor, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
	                                    C0 = ArmC0
	                                })
	                                AnimTween:Play()
	                            end
	                        end
	
	                        if not Started then
	                            task.wait(1 / 60)
	                        end
	                    until (not Killaura.Enabled) or (not Animation.Enabled)
	                end)
	            end
	
	            repeat
	                local Attacked = {}
	                local Tool = GetAttackData()
	                if Tool and Tool.Melee then
	                    local Entities = Entity.AllPosition({
	                        Range = AttackRange.Value,
	                        Wallcheck = Targets.Walls.Enabled or nil,
	                        Part = "RootPart",
	                        Players = Targets.Players.Enabled,
	                        NPCs = Targets.NPCs.Enabled,
	                        Priority = Targets.Priority.Value,
	                        Limit = Max.Value
	                    })
	                    local Switched: boolean = false
	
	                    if #Entities > 0 then
	                        local LocalFacing: Vector3 = Entity.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
	                        Store.noShoot = tick() + 1
	
	                        for _, v: any in Entities do
	                            local Delta: Vector3 = (v.RootPart.Position - Entity.character.RootPart.Position)
	                            local Angle: number = math.acos(LocalFacing:Dot((Delta * Vector3.new(1, 0, 1)).Unit))
	                            if Angle > (math.rad(AngleCheck.Value) / 2) then
	                                continue
	                            end
	                            table.insert(Attacked, v)
	                            TargetInfo.Targets[v] = tick() + 1
	
	                            if not Swing.Enabled then
	                                Skywars.MeleeController:playAnimation(LocalPlayer.Character, Tool)
	                            end
	
	                            if not Switched then
	                                Switched = true
	                                Skywars.Remotes[Remotes.updateActiveItem]:fire(Tool.Name)
	                            end
	
	                            Skywars.Remotes[Remotes.strikeDesktop]:fire(v.Player)
	                        end
	                    end
	
	                    if Switched then
	                        Skywars.Remotes[Remotes.updateActiveItem]:fire(Store.hand.Name)
	                    end
	                end
	
	                Attacking = #Attacked > 0
	                if Attacking and vape.ThreadFix then
	                    setthreadidentity(8)
	                end
	
	                for i: number, v: BoxHandleAdornment in Boxes do
	                    v.Adornee = Attacked[i] and Attacked[i].RootPart or nil
	                    if v.Adornee then
	                        v.Color3 = Color3.fromHSV(BoxAttackColor.Hue, BoxAttackColor.Sat, BoxAttackColor.Value)
	                        v.Transparency = 1 - BoxAttackColor.Opacity
	                    end
	                end
	
	                for i: number, v: Part in Particles do
	                    v.Position = Attacked[i] and Attacked[i].RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
	                    v.Parent = Attacked[i] and Camera or nil
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
	            if ArmC0 and ViewmodelMotor then
	                AnimTween = TweenService:Create(ViewmodelMotor, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
	                    C0 = ArmC0
	                })
	                AnimTween:Play()
	            end
	        end
	    end,
	    Tooltip = "Attack players around you\nwithout aiming at them."
	})
	Targets = Killaura:CreateTargets({Players = true})
	AttackRange = Killaura:CreateSlider({
	    Name = "Attack range",
	    Min = 1,
	    Max = 18,
	    Default = 18,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	AngleCheck = Killaura:CreateSlider({
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
	Animation = Killaura:CreateToggle({
	    Name = "Custom Animation",
	    Function = function(Callback: boolean)
	        AnimationMode.Object.Visible = Callback
	        AnimationTween.Object.Visible = Callback
	        AnimationSpeed.Object.Visible = Callback
	        if Killaura.Enabled then
	            Killaura:Toggle()
	            Killaura:Toggle()
	        end
	    end
	})
	local AnimationNames: {string} = {}
	for Name: string in Animations do
	    table.insert(AnimationNames, Name)
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
	Limit = Killaura:CreateToggle({
	    Name = "Limit to items",
	    Tooltip = "Only attacks when the sword is held"
	})
end)

Run(function()
	local NoFall
	local RayCheck: RaycastParams = RaycastParams.new()
	
	NoFall = vape.Categories.Blatant:CreateModule({
	    Name = "NoFall",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local WaitDelay: number = 0
	                if Entity.isAlive then
	                    local Humanoid = Entity.character.Humanoid
	                    if (Entity.character.GroundPosition.Y - Entity.character.RootPart.Position.Y) > 10 then
	                        RayCheck.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
	                        local RayResult: RaycastResult? = workspace:Raycast(Entity.character.RootPart.Position, Vector3.new(0, -(Entity.character.HipHeight + 10), 0), RayCheck)
	                        if not RayResult then
	                            Humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)
	                            task.wait(0.1)
	                            Humanoid:ChangeState(Enum.HumanoidStateType.Running)
	                            WaitDelay = 0.05
	                        end
	                    end
	                end
	                task.wait(WaitDelay)
	            until not NoFall.Enabled
	        end
	    end,
	    Tooltip = "Prevents taking fall damage."
	})
end)

Run(function()
	local Old, OldCheck
	
	vape.Categories.Blatant:CreateModule({
	    Name = "NoSlowdown",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = Skywars.HumanoidController.addSpeedModifier
	            OldCheck = Skywars.SprintingController.setCanSprint
	
	            Skywars.HumanoidController.addSpeedModifier = function(self, Index, Speed: number)
	                Speed = math.max(Speed, 1)
	                return Old(self, Index, Speed)
	            end
	
	            Skywars.SprintingController.setCanSprint = function(self, CanSprint: boolean)
	                return OldCheck(self, true)
	            end
	
	            for i: number, v: number in Skywars.HumanoidController.speedModifiers do
	                if v < 1 then
	                    Skywars.HumanoidController:removeSpeedModifier(i)
	                end
	            end
	
	            Skywars.SprintingController:setCanSprint(true)
	            Skywars.SprintingController:enableSprinting()
	        else
	            Skywars.HumanoidController.addSpeedModifier = Old
	            Skywars.SprintingController.setCanSprint = OldCheck
	            Old = nil
	            OldCheck = nil
	        end
	    end,
	    Tooltip = "Prevents slowing down when using items."
	})
end)

Run(function()
	local TargetPart
	local FOV
	local Old, OldMobile
	local RayCheck: RaycastParams = RaycastParams.new()
	RayCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	local function AimFunction(...)
	    if Store.hand and Store.hand.Ranged then
	        local Ent = Entity.EntityMouse({
	            Range = FOV.Value,
	            Part = "RootPart",
	            Players = true
	        })
	
	        if Ent then
	            RayCheck.FilterDescendantsInstances = {Ent.Character, Camera}
	            RayCheck.CollisionGroup = Ent[TargetPart.Value].CollisionGroup
	            local OffsetCFrame: CFrame = Entity.character.RootPart.CFrame * Skywars.FireOrigin
	            local Calculated = PredictionLib.SolveTrajectory(OffsetCFrame.Position, 200, math.abs(Skywars.Gravity), Ent[TargetPart.Value].Position, Ent[TargetPart.Value].Velocity, workspace.Gravity, Ent.HipHeight, nil, RayCheck)
	
	            if Calculated then
	                TargetInfo.Targets[Ent] = tick() + 1
	                return CFrame.new(OffsetCFrame.Position, Calculated).LookVector
	            end
	        end
	    end
	
	    return Old(...)
	end
	
	local ProjectileAimbot = vape.Categories.Blatant:CreateModule({
	    Name = "ProjectileAimbot",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = hookfunction(Skywars.CameraUtil.getCursorDirection, function(...)
	                return AimFunction(...)
	            end)
	
	            OldMobile = hookfunction(Skywars.CameraUtil.getDirection, function(...)
	                return AimFunction(...)
	            end)
	        else
	            hookfunction(Skywars.CameraUtil.getCursorDirection, Old)
	            hookfunction(Skywars.CameraUtil.getDirection, OldMobile)
	            Old = nil
	            OldMobile = nil
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
	local ProjectileAura
	local Targets
	local Range
	local List
	local RayCheck: RaycastParams = RaycastParams.new()
	RayCheck.FilterType = Enum.RaycastFilterType.Exclude
	local FireDelays = {}
	
	local function GetProjectiles()
	    local Items = {}
	    for _, Item: any in Store.inventory do
	        Item = Skywars.ItemMeta[Item.Type]
	        if Item.Ranged and table.find(List.ListEnabled, Item.Ranged.ProjectileType) and GetItem(Item.Ranged.ProjectileType) then
	            table.insert(Items, Item)
	        end
	    end
	    return Items
	end
	
	ProjectileAura = vape.Categories.Blatant:CreateModule({
	    Name = "ProjectileAura",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local Ent = Entity.EntityPosition({
	                    Part = "RootPart",
	                    Range = Range.Value,
	                    Players = Targets.Players.Enabled,
	                    NPCs = Targets.NPCs.Enabled,
	                    Priority = Targets.Priority.Value,
	                    Wallcheck = Targets.Walls.Enabled
	                })
	
	                if Ent then
	                    local OffsetCFrame: CFrame = Entity.character.RootPart.CFrame * Skywars.FireOrigin
	                    for _, Item: any in GetProjectiles() do
	                        if (FireDelays[Item] or 0) < tick() then
	                            RayCheck.FilterDescendantsInstances = {Ent.Character, Camera}
	                            RayCheck.CollisionGroup = Ent.RootPart.CollisionGroup
	                            local Calculated = PredictionLib.SolveTrajectory(OffsetCFrame.Position, 200, math.abs(Skywars.Gravity), Ent.RootPart.Position, Ent.RootPart.Velocity, workspace.Gravity, Ent.HipHeight, nil, RayCheck)
	
	                            if Calculated then
	                                TargetInfo.Targets[Ent] = tick() + 1
	                                FireDelays[Item] = tick() + 0.5
	                                Skywars.Remotes[Remotes.updateActiveItem]:fire(Item.Name)
	                                Skywars.Remotes[Remotes.chargeBow]:fire(CFrame.new(OffsetCFrame.Position, Calculated).LookVector, 1)
	                                Skywars.Remotes[Remotes.updateActiveItem]:fire(Store.hand.Name)
	                                break
	                            end
	                        end
	                    end
	                end
	
	                task.wait(0.1)
	            until not ProjectileAura.Enabled
	        end
	    end,
	    Tooltip = "Shoots people around you"
	})
	Targets = ProjectileAura:CreateTargets({
	    Players = true,
	    Walls = true
	})
	List = ProjectileAura:CreateTextList({
	    Name = "Projectiles",
	    Default = {"Arrow", "Snowball", "Capybara"}
	})
	Range = ProjectileAura:CreateSlider({
	    Name = "Range",
	    Min = 1,
	    Max = 50,
	    Default = 50,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
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
	            local Vector: Vector3 = Vector3.new(X, Y, Z)
	            if Vector.Y ~= 0 and (Vector.X ~= 0 or Vector.Z ~= 0) then
	                continue
	            end
	
	            if Vector ~= Vector3.zero then
	                table.insert(Adjacent, Vector)
	            end
	        end
	    end
	end
	
	local function GetBlocksInPoints(StartPosition: Vector3, EndPosition: Vector3)
	    local List: {Vector3} = {}
	    for X: number = StartPosition.X, EndPosition.X, 3 do
	        for Y: number = StartPosition.Y, EndPosition.Y, 3 do
	            for Z: number = StartPosition.Z, EndPosition.Z, 3 do
	                local Vector: Vector3 = Vector3.new(X, Y, Z)
	                if Store.blocks[Vector] then
	                    table.insert(List, Vector)
	                end
	            end
	        end
	    end
	    return List
	end
	
	local function RoundPos(Vector: Vector3)
	    return Vector3.new(math.round(Vector.X / 3) * 3, math.round(Vector.Y / 3) * 3, math.round(Vector.Z / 3) * 3)
	end
	
	local function NearCorner(CheckPosition: Vector3, Position: Vector3)
	    local StartPosition: Vector3 = CheckPosition - Vector3.new(3, 3, 3)
	    local EndPosition: Vector3 = CheckPosition + Vector3.new(3, 3, 3)
	    local Check: Vector3 = CheckPosition + (Position - CheckPosition).Unit * 100
	    if math.abs(Check.Y - StartPosition.Y) > 3 then
	        return Vector3.new(CheckPosition.X, math.clamp(Check.Y, StartPosition.Y, EndPosition.Y), CheckPosition.Z)
	    end
	
	    return Vector3.new(math.clamp(Check.X, StartPosition.X, EndPosition.X), math.clamp(Check.Y, StartPosition.Y, EndPosition.Y), math.clamp(Check.Z, StartPosition.Z, EndPosition.Z))
	end
	
	local function BlockProximity(Position: Vector3)
	    local Magnitude, Returned = 60
	    local Blocks = GetBlocksInPoints(Position - Vector3.new(21, 21, 21), Position + Vector3.new(21, 21, 21))
	
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
	
	local function CheckAdjacent(Position: Vector3)
	    for _, v: Vector3 in Adjacent do
	        if Store.blocks[Position + v] then
	            return true
	        end
	    end
	    return false
	end
	
	local function GetBlock()
	    for Slot: any, Item: any in Store.inventory do
	        Item = Skywars.ItemMeta[Item.Type]
	        if Item.Rewrite then
	            return Item, Slot
	        end
	    end
	end
	
	Scaffold = vape.Categories.Utility:CreateModule({
	    Name = "Scaffold",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                if Entity.isAlive then
	                    local Wool = (not LimitItem.Enabled) and GetBlock() or Store.hand.Rewrite and Store.hand
	                    if Wool then
	                        local Root = Entity.character.RootPart
	                        if Tower.Enabled and UserInputService:IsKeyDown(Enum.KeyCode.Space) and (not UserInputService:GetFocusedTextBox()) then
	                            Root.Velocity = Vector3.new(Root.Velocity.X, 38, Root.Velocity.Z)
	                        end
	
	                        for i: number = Expand.Value, 1, -1 do
	                            local CurrentPosition: Vector3 = RoundPos(Root.Position - Vector3.new(0, Entity.character.HipHeight + (Downwards.Enabled and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4.5 or 1.5), 0) + Entity.character.Humanoid.MoveDirection * (i * 3))
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
	                                    local Block = Skywars.ItemMeta[Wool.Rewrite.Type:gsub("{TeamId}", Skywars.TeamController:getPlayerTeamId(LocalPlayer) or "White")]
	                                    Skywars.BlockController:placeBlock(BlockPosition, Wool.Name, Block, Vector3.zero)
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
	local BreakerPart
	local BreakerUI
	local BreakerRef = Skywars.Roact.createRef()
	
	local function Clean()
	    if not BreakerUI then
	        return
	    end
	    if BreakerPart then
	        BreakerPart:Destroy()
	    end
	
	    Skywars.Roact.unmount(BreakerUI)
	    BreakerUI = nil
	    BreakerPart = nil
	end
	
	local function CustomHealthbar(Block: Model, Health: number, MaxHealth: number, ChangeHealth: number)
	    if not BreakerPart then
	        local Create = Skywars.Roact.createElement
	        local Percent: number = math.clamp(Health / MaxHealth, 0, 1)
	        local CleanCheck: boolean = true
	        local Part: Part = Instance.new("Part")
	        Part.Size = Vector3.one
	        Part.CFrame = Block.PrimaryPart.CFrame
	        Part.Transparency = 1
	        Part.Anchored = true
	        Part.CanCollide = false
	        Part.Parent = workspace
	        BreakerPart = Part
	
	        BreakerUI = Skywars.Roact.mount(Create("BillboardGui", {
	            Size = UDim2.fromOffset(249, 102),
	            StudsOffset = Vector3.new(0, 2.5, 0),
	            Adornee = Part,
	            MaxDistance = 40,
	            AlwaysOnTop = true
	        }, {
	            Create("Frame", {
	                Size = UDim2.fromOffset(160, 50),
	                Position = UDim2.fromOffset(44, 32),
	                BackgroundColor3 = Color3.new(),
	                BackgroundTransparency = 0.5
	            }, {
	                Create("UICorner", {CornerRadius = UDim.new(0, 5)}),
	                Create("ImageLabel", {
	                    Size = UDim2.new(1, 89, 1, 52),
	                    Position = UDim2.fromOffset(-48, -31),
	                    BackgroundTransparency = 1,
	                    Image = GetVapeAsset("kingvape/assets/new/blur.png"),
	                    ScaleType = Enum.ScaleType.Slice,
	                    SliceCenter = Rect.new(52, 31, 261, 502)
	                }),
	                Create("TextLabel", {
	                    Size = UDim2.fromOffset(145, 14),
	                    Position = UDim2.fromOffset(13, 12),
	                    BackgroundTransparency = 1,
	                    Text = Block.Name,
	                    TextXAlignment = Enum.TextXAlignment.Left,
	                    TextYAlignment = Enum.TextYAlignment.Top,
	                    TextColor3 = Color3.new(),
	                    TextScaled = true,
	                    Font = Enum.Font.Arial
	                }),
	                Create("TextLabel", {
	                    Size = UDim2.fromOffset(145, 14),
	                    Position = UDim2.fromOffset(12, 11),
	                    BackgroundTransparency = 1,
	                    Text = Block.Name,
	                    TextXAlignment = Enum.TextXAlignment.Left,
	                    TextYAlignment = Enum.TextYAlignment.Top,
	                    TextColor3 = Color.Dark(UIPallet.Text, 0.16),
	                    TextScaled = true,
	                    Font = Enum.Font.Arial
	                }),
	                Create("Frame", {
	                    Size = UDim2.fromOffset(138, 4),
	                    Position = UDim2.fromOffset(12, 32),
	                    BackgroundColor3 = UIPallet.Main
	                }, {
	                    Create("UICorner", {CornerRadius = UDim.new(1, 0)}),
	                    Create("Frame", {
	                        [Skywars.Roact.Ref] = BreakerRef,
	                        Size = UDim2.fromScale(Percent, 1),
	                        BackgroundColor3 = Color3.fromHSV(math.clamp(Percent / 2.5, 0, 1), 0.89, 0.75)
	                    }, {Create("UICorner", {CornerRadius = UDim.new(1, 0)})})
	                })
	            })
	        }), Part)
	
	        task.delay(5, Clean)
	    end
	
	    local Progress: number = math.clamp((Health - ChangeHealth) / MaxHealth, 0, 1)
	    if Progress == 0 then
	        Clean()
	        return
	    end
	
	    task.delay(0, function()
	        local Fill = BreakerRef:getValue()
	        if Fill then
	            TweenService:Create(Fill, TweenInfo.new(0.3), {
	                Size = UDim2.fromScale(Progress, 1),
	                BackgroundColor3 = Color3.fromHSV(math.clamp(Progress / 2.5, 0, 1), 0.89, 0.75)
	            }):Play()
	        end
	    end)
	end
	
	Breaker = vape.Categories.World:CreateModule({
	    Name = "Breaker",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Eggs = Collection("egg", Breaker)
	            local CurrentBlock
	            local OldBlockHealth: number = 0
	
	            repeat
	                if Entity.isAlive and Store.hand then
	                    local LocalPosition: Vector3 = Entity.character.RootPart.Position
	                    for _, v: Model in Eggs do
	                        if v.PrimaryPart and (LocalPosition - v.PrimaryPart.Position).Magnitude < Range.Value then
	                            local Health: number = v:GetAttribute("Health") or 0
	                            if v:GetAttribute("TeamId") == LocalPlayer:GetAttribute("TeamId") then
	                                continue
	                            end
	                            if CurrentBlock ~= v then
	                                OldBlockHealth = Health
	                                CurrentBlock = v
	                            end
	
	                            if Health ~= OldBlockHealth then
	                                CustomHealthbar(v, OldBlockHealth, 100, OldBlockHealth - Health)
	                                OldBlockHealth = Health
	                            end
	
	                            Store.noShoot = tick() + 1
	                            if Health <= 0 then
	                                continue
	                            end
	
	                            if Store.hand.Melee then
	                                Skywars.Remotes[Remotes["MeleeController:attemptStrikeDesktop"]]:fire(v)
	                            elseif Store.hand.Pickaxe then
	                                Skywars.Remotes[Remotes.hitBlock]:fire((v.PrimaryPart.Position + Vector3.new(0, 1.5, 0)) // 1)
	                            end
	                        end
	                    end
	                end
	
	                task.wait(0.016)
	            until not Breaker.Enabled
	        end
	    end,
	    Tooltip = "Automatically destroys eggs around you"
	})
	Range = Breaker:CreateSlider({
	    Name = "Break range",
	    Min = 1,
	    Max = 40,
	    Default = 40,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
end)

Run(function()
	local ChestSteal
	local Range
	local Open
	local Delay = {}
	
	ChestSteal = vape.Categories.World:CreateModule({
	    Name = "ChestSteal",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Chests = Collection("block:chest", ChestSteal)
	            ChestSteal:Clean(Skywars.Remotes[Remotes["ChestController:onStart"]]:connect(function(self, Items)
	                if Delay[self] then
	                    return
	                end
	
	                for _, Item: any in Items do
	                    Skywars.Remotes[Remotes.updateChest]:fire(self, Item.Type, -Item.Quantity)
	                end
	
	                Skywars.Remotes[Remotes.closeChest]:fire(self)
	                Delay[self] = true
	            end))
	
	            repeat
	                if Entity.isAlive and not Open.Enabled then
	                    local LocalPosition: Vector3 = Entity.character.RootPart.Position
	                    for _, v: Model in Chests do
	                        if v.PrimaryPart and (LocalPosition - v.PrimaryPart.Position).Magnitude <= Range.Value and not Delay[v] then
	                            Skywars.Remotes[Remotes.openChest]:fire(v)
	                        end
	                    end
	                end
	
	                task.wait(0.1)
	            until not ChestSteal.Enabled
	        end
	    end,
	    Tooltip = "Grabs items from near chests."
	})
	Range = ChestSteal:CreateSlider({
	    Name = "Range",
	    Min = 0,
	    Max = 10,
	    Default = 10,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	Open = ChestSteal:CreateToggle({Name = "GUI Check"})
end)

Run(function()
	local AutoBuy
	local Sword
	local Armor
	local Pickaxe
	local Upgrades
	local UpgradeObjects = {}
	local Functions = {}
	
	local function BuyCheck(CurrencyTable)
	    for _, v: (...any) -> ...any in Functions do
	        v(CurrencyTable)
	    end
	end
	
	local function BuyUpgrade(Name: string?, Upgrade, CurrencyTable)
	    local CurrentItem
	    for ShopIndex: number, ShopItem: any in Upgrade.Items do
	        if ShopItem.ItemType == Name then
	            CurrentItem = ShopIndex
	        end
	    end
	
	    if not CurrentItem then
	        return
	    end
	
	    for i: number = CurrentItem + 1, #Upgrade.Items do
	        local NextItem = Upgrade.Items[i]
	        if NextItem and CurrencyTable[NextItem.CurrencyType] >= NextItem.Price then
	            Skywars.Remotes[Remotes.purchaseItemUpgrade]:fire("Blacksmith", Upgrade.ItemIndex)
	            CurrencyTable[NextItem.CurrencyType] -= NextItem.Price
	        end
	    end
	end
	
	local function BuyTeamUpgrade(Upgrade, CurrencyTable)
	    local CurrentItem: number = Skywars.Store:getState().TeamUpgrades[Upgrade.Name] or 0
	    for i: number = CurrentItem + 1, #Upgrade.Tiers do
	        local NextItem = Upgrade.Tiers[i]
	        if NextItem and CurrencyTable[NextItem.CurrencyType] >= NextItem.Price then
	            Skywars.Remotes[Remotes.purchaseTeamUpgrade]:fire("Merchant", Upgrade.ItemIndex)
	            CurrencyTable[NextItem.CurrencyType] -= NextItem.Price
	        end
	    end
	end
	
	AutoBuy = vape.Categories.Inventory:CreateModule({
	    Name = "AutoBuy",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoBuy:Clean(VapeEvents.CurrencyChange.Event:Connect(BuyCheck))
	            BuyCheck(table.clone(Skywars.Store:getState().GameCurrency.Quantities))
	        end
	    end,
	    Tooltip = "Automatically buys items when you go near the shop"
	})
	Sword = AutoBuy:CreateToggle({
	    Name = "Buy Sword",
	    Function = function(Callback: boolean)
	        Functions[2] = Callback and function(CurrencyTable, Shop, UpgradeList)
	            BuyUpgrade(Store.tools.sword and Store.tools.sword.Name, Skywars.Shop.Blacksmith.ItemUpgrades[2], CurrencyTable)
	        end or nil
	    end,
	    Default = true
	})
	Armor = AutoBuy:CreateToggle({
	    Name = "Buy Armor",
	    Function = function(Callback: boolean)
	        Functions[1] = Callback and function(CurrencyTable, Shop, UpgradeList)
	            if LocalPlayer.Character then
	                for _, v: Instance in LocalPlayer.Character:GetChildren() do
	                    if v:GetAttribute("Armour") and v.Name:find("Chestplate") then
	                        BuyUpgrade(v.Name, Skywars.Shop.Blacksmith.ItemUpgrades[1], CurrencyTable)
	                        break
	                    end
	                end
	            end
	        end or nil
	    end,
	    Default = true
	})
	Pickaxe = AutoBuy:CreateToggle({
	    Name = "Buy Pickaxe",
	    Function = function(Callback: boolean)
	        Functions[3] = Callback and function(CurrencyTable, Shop, UpgradeList)
	            BuyUpgrade(Store.tools.pickaxe and Store.tools.pickaxe.Name, Skywars.Shop.Blacksmith.ItemUpgrades[3], CurrencyTable)
	        end or nil
	    end,
	    Default = true
	})
	Upgrades = AutoBuy:CreateToggle({
	    Name = "Buy Upgrades",
	    Function = function(Callback: boolean)
	        for _, v: any in UpgradeObjects do
	            v.Object.Visible = Callback
	        end
	    end,
	    Default = true
	})
	for i: number, v: any in Skywars.Shop.Merchant.TeamUpgrades do
	    table.insert(UpgradeObjects, AutoBuy:CreateToggle({
	        Name = `Buy {v.Name}`,
	        Function = function(Callback: boolean)
	            Functions[4 + i] = Callback and function(CurrencyTable, Shop, UpgradeList)
	                BuyTeamUpgrade(v, CurrencyTable)
	            end or nil
	        end,
	        Darker = true,
	        Default = (v.Name == "Generator" or v.Name == "Vampyrism")
	    }))
	end
end)

Run(function()
	local AutoConsume
	
	local function ConsumeCheck()
	    if (LocalPlayer:GetAttribute("Shield") or 0) <= 0 and GetItem("Shield") then
	        Skywars.Remotes[Remotes.updateActiveItem]:fire("Shield")
	        Skywars.Remotes[Remotes.usePowerUp]:fire()
	        Skywars.Remotes[Remotes.updateActiveItem]:fire(Store.hand.Name)
	    end
	end
	
	AutoConsume = vape.Categories.Inventory:CreateModule({
	    Name = "AutoConsume",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoConsume:Clean(VapeEvents.InventoryAmountChanged.Event:Connect(ConsumeCheck))
	            AutoConsume:Clean(LocalPlayer:GetAttributeChangedSignal("Shield"):Connect(ConsumeCheck))
	            ConsumeCheck()
	        end
	    end,
	    Tooltip = "Automatically uses shield potions."
	})
end)

Run(function()
	local Viewmodel
	local OldTool
	
	local function NewCharacter(Ent)
	    Viewmodel:Clean(Ent.Character.ChildAdded:Connect(function(Child: Instance)
	        if Child:IsA("Tool") then
	            OldTool = Child
	            ViewmodelTool = OldTool.Handle:Clone()
	            ViewmodelTool.CanCollide = false
	            ViewmodelTool.Massless = true
	            ViewmodelTool.Anchored = true
	            ViewmodelTool:ClearAllChildren()
	            ViewmodelTool.Parent = Camera
	            ViewmodelTool.LocalTransparencyModifier = 0
	            OldTool.Handle.LocalTransparencyModifier = 1
	        end
	    end))
	
	    Viewmodel:Clean(Ent.Character.ChildRemoved:Connect(function(Child: Instance)
	        if Child == OldTool then
	            ViewmodelTool:Destroy()
	            ViewmodelTool = nil
	            OldTool = nil
	        end
	    end))
	end
	
	Viewmodel = vape.Legit:CreateModule({
	    Name = "Viewmodel",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_viewmodel.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            ViewmodelMotor = Instance.new("Motor6D")
	            Viewmodel:Clean(ViewmodelMotor)
	            Viewmodel:Clean(RunService.RenderStepped:Connect(function()
	                if ViewmodelTool then
	                    local ViewCFrame: CFrame = ((CFrame.new(2.06, -2.44, -2.24) * CFrame.new(0.6, -0.2, -0.6)) * CFrame.Angles(math.rad(99), math.rad(2), math.rad(-4))) * ViewmodelMotor.C0
	                    local OffsetCFrame: CFrame = (CFrame.new(0, -0.15, -1.56) * CFrame.Angles(math.rad(-90), math.rad(-90), 0))
	                    ViewmodelTool.CFrame = ((Camera.CFrame * ViewCFrame) * OffsetCFrame)
	                end
	            end))
	            Viewmodel:Clean(Entity.Events.LocalAdded:Connect(NewCharacter))
	            if Entity.isAlive then
	                NewCharacter(Entity.character)
	            end
	        else
	            if ViewmodelTool then
	                ViewmodelTool:Destroy()
	            end
	        end
	    end,
	    Tooltip = "Replaces the default viewmodel"
	})
end)