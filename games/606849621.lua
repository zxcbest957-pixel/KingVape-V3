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
local ReplicatedStorage: ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService: RunService = cloneref(game:GetService("RunService"))
local UserInputService: UserInputService = cloneref(game:GetService("UserInputService"))
local TextService: TextService = cloneref(game:GetService("TextService"))
local TweenService: TweenService = cloneref(game:GetService("TweenService"))
local Teams: Teams = cloneref(game:GetService("Teams"))
local CollectionService: CollectionService = cloneref(game:GetService("CollectionService"))
local ContextActionService: ContextActionService = cloneref(game:GetService("ContextActionService"))

local Camera: Camera = workspace.CurrentCamera
local LocalPlayer: Player = Players.LocalPlayer

local vape = shared.vape
local Entity = vape.Libraries.entity
local Whitelist = vape.Libraries.whitelist
local PredictionLib = vape.Libraries.prediction
local TargetInfo = vape.Libraries.targetinfo
local SessionInfo = vape.Libraries.sessioninfo
local VirtualMachine = loadstring(DownloadFile("kingvape/libraries/vm.lua"), "vm")()

local Jailbreak = {}
local InfNitro = {Enabled = false}
local LazerGodmode = {Enabled = false}

local function GetVehicle(Ent)
    if Ent.Player then
        for _, Car: Model in CollectionService:GetTagged("Vehicle") do
            for _, Seat: Instance in Car:GetChildren() do
                if (Seat.Name == "Seat" or Seat.Name == "Passenger") then
                    Seat = Seat:FindFirstChild("PlayerName")
                    if Seat and Seat.Value == Ent.Player.Name then
                        return Car
                    end
                end
            end
        end
    end
end

local function IsArrested(Name: string)
    for _, v: any in Jailbreak.CircleAction.Specs do
        if v.Name == "Arrest" and v.PlayerName == Name then
            return not v.ShouldArrest
        end
    end
    return false
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

local function IsIllegal(Ent)
    if Ent.Player and Ent.Player.Team == Teams.Prisoner then
        local Items = Ent.Player:FindFirstChild("CurrentInventory")
        Items = Items and Items.Value
        if Items then
            for _, v: Instance in Items:GetChildren() do
                if v.Name ~= "MansionInvite" then
                    return true
                end
            end
        end

        return Ent.Illegal
    end
    return true
end

local function IsTarget(Player: Player)
    return table.find(vape.Categories.Targets.ListEnabled, Player.Name) and true
end

local function SendNotification(...)
    return vape:CreateNotification(...)
end

Run(function()
    Entity.getUpdateConnections = function(Ent)
        local Humanoid: Humanoid = Ent.Humanoid
        return {
            Humanoid:GetPropertyChangedSignal("Health"),
            Humanoid:GetPropertyChangedSignal("MaxHealth"),
            {
                Connect = function()
                    Ent.Friend = Ent.Player and IsFriend(Ent.Player) or nil
                    Ent.Target = Ent.Player and IsTarget(Ent.Player) or nil
                    return {Disconnect = function() end}
                end
            },
            {
                Connect = function()
                    return Humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
                        if GetVehicle(Ent) then
                            Ent.Illegal = true
                        end
                    end)
                end
            }
        }
    end

    Entity.targetCheck = function(Ent)
        if Ent.TeamCheck then
            return Ent:TeamCheck()
        end
        if Ent.NPC then
            return true
        end
        if IsFriend(Ent.Player) then
            return false
        end
        if not select(2, Whitelist:get(Ent.Player)) then
            return false
        end
        if LocalPlayer.Team == Teams.Police then
            return Ent.Player.Team ~= Teams.Police
        else
            return Ent.Player.Team == Teams.Police
        end
        return true
    end
end)
Entity.start()

Run(function()
    local function DumpRemotes(Scripts: {Instance}, Renamed: {[string]: string})
        local Returned = {}

        for _, Script: Instance in Scripts do
            local Deserialized = VirtualMachine.luau_deserialize(getscriptbytecode(Script))

            for _, Proto: any in Deserialized.protoList do
                local Stack, Top, Code = {}, -1, Proto.code
                for i: number, Instruction: any in Code do
                    if Instruction.opcode == 4 then
                        Stack[Instruction.A] = Instruction.D
                    elseif Instruction.opcode == 5 then
                        Stack[Instruction.A] = Instruction.K
                    elseif Instruction.opcode == 6 then
                        Stack[Instruction.A] = Stack[Instruction.B]
                    elseif Instruction.opcode == 12 then
                        local Count, Import = Instruction.KC, getrenv()[Instruction.K0]

                        if Count == 1 then
                            Stack[Instruction.A] = Import
                        elseif Count == 2 then
                            Stack[Instruction.A] = Import[Instruction.K1]
                        elseif Count == 3 then
                            Stack[Instruction.A] = Import[Instruction.K1][Instruction.K2]
                        end
                    elseif Instruction.opcode == 20 then
                        local A, B, Method = Instruction.A, Instruction.B, Instruction.K
                        Stack[A + 1] = Stack[B]

                        local CallInstruction = Code[i + 2]
                        local CallA, CallB, CallC = CallInstruction.A, CallInstruction.B, CallInstruction.C
                        local Params: number = if CallB == 0 then Top - CallA else CallB - 1
                        if Method == "sub" or Method == "reverse" then
                            local Arg1, Arg2, Arg3 = table.unpack(Stack, CallA + 1, CallA + Params)
                            if Method == "reverse" and not Arg1 then
                                Arg1 = "a"
                            end

                            local Results = table.pack(string[Method](Arg1, Arg2, Arg3))
                            local ResultCount: number = Results.n - 1
                            if CallC == 0 then
                                Top = CallA + ResultCount - 1
                            else
                                ResultCount = CallC - 1
                            end

                            table.move(Results, 1, ResultCount, CallA, Stack)
                        elseif Method == "FireServer" then
                            local Name, Value = Proto.debugname == "(??)" and Script.Name or Proto.debugname, Stack[CallA + 2]
                            if Name == Value then
                                table.insert(Returned, Value)
                                continue
                            end
                            if Returned[Name] then
                                for Suffix: number = 1, 10 do
                                    if not Returned[`{Name}{Suffix}`] then
                                        Name ..= Suffix
                                        break
                                    end
                                end
                            end

                            Returned[Name] = Value
                        end
                    elseif Instruction.opcode == 49 then
                        local Concatenated: string = ""
                        for Register: number = Instruction.B, Instruction.C do
                            if type(Stack[Register]) ~= "string" then
                                continue
                            end
                            Concatenated ..= Stack[Register]
                        end
                        Stack[Instruction.A] = Concatenated
                    end
                end
            end
        end

        for Name: string, v: any in table.clone(Returned) do
            if Renamed[Name] then
                Returned[Name] = nil
                Returned[Renamed[Name]] = v
            end
        end

        return Returned
    end

    local function GetCash()
        for i: number, v: any in debug.getupvalue(Jailbreak.TeamChooseController.Init, 2) do
            if type(v) == "function" then
                for _, Constant: any in debug.getconstants(v) do
                    if tostring(Constant):find("PlusCash") then
                        return v, i
                    end
                end
            end
        end
    end

    local function ToMoney(Amount: number)
        local Prefix, Digits, Suffix = string.match(tostring(Amount), "^([^%d]*%d)(%d*)(.-)$")
        return `{Prefix}{Digits:reverse():gsub("(%d%d%d)", "%1,"):reverse()}{Suffix}$`
    end

    Jailbreak = {
        BulletEmitter = require(ReplicatedStorage.Game.ItemSystem.BulletEmitter),
        CircleAction = require(ReplicatedStorage.Module.UI).CircleAction,
        CargoController = require(ReplicatedStorage.Game.Robbery.RobberyPassengerTrain),
        FallingController = require(ReplicatedStorage.Game.Falling),
        GunController = require(ReplicatedStorage.Game.Item.Gun),
        HotbarItemSystem = require(ReplicatedStorage.Hotbar.HotbarItemSystem),
        InventoryItemSystem = require(ReplicatedStorage.Inventory.InventoryItemSystem),
        ItemSystemController = require(ReplicatedStorage.Game.ItemSystem.ItemSystem),
        PlayerUtils = require(ReplicatedStorage.Game.PlayerUtils),
        RagdollController = require(ReplicatedStorage.Module.AlexRagdoll),
        TaserController = require(ReplicatedStorage.Game.Item.Taser),
        TeamChooseController = require(ReplicatedStorage.TeamSelect.TeamChooseUI),
        VehicleController = require(ReplicatedStorage.Vehicle.VehicleUtils)
    }

    if not Jailbreak.VehicleController.toggleLocalLocked or not Jailbreak.VehicleController.NitroShopVisible then
        repeat task.wait() until (Jailbreak.VehicleController.toggleLocalLocked and Jailbreak.VehicleController.NitroShopVisible) or vape.Loaded == nil
        if vape.Loaded == nil then
            return
        end
    end
    local RemoteTable = debug.getupvalue(Jailbreak.VehicleController.toggleLocalLocked, 2)
    local FireServer, Hook = RemoteTable.FireServer

    local Remotes = DumpRemotes({
        ReplicatedStorage.Game.TrainSystem.LocomotiveFront,
        ReplicatedStorage.Game.ItemSystem.ItemSystem,
        ReplicatedStorage.Game.CashBuyUI,
        ReplicatedStorage.Game.Item.Taser,
        ReplicatedStorage.Game.Item.Gun,
        ReplicatedStorage.Game.Falling,
        LocalPlayer.PlayerScripts.LocalScript
    }, {
        Action = "Pickup",
        Action3 = "StartRob",
        Action2 = "EndRob",
        AttemptArrest = "Arrest",
        attemptPunch = "Punch",
        AttemptVehicleEject = "Eject",
        AttemptVehicleEnter = "GetIn",
        BroadcastInputBegan = "InputBegan",
        BroadcastInputEnded = "InputEnded",
        CalculateDelta = "UseNitro",
        Draw = "TaseReplicate",
        Gun = "PopTires",
        LocalScript2 = "LookAngle",
        LocalScript = "SelfDamage",
        onPressed = "FlipVehicle",
        OnJump = "GetOut",
        OnJump1 = "GetOut",
        UpdateMousePosition = "AimPosition"
    })

    local function FireHook(self, Id, ...)
        local RemoteName
        for Name: string, v: any in Remotes do
            if v == Id then
                RemoteName = Name
            end
        end

        if InfNitro.Enabled and RemoteName == "UseNitro" then
            return
        end
        if LazerGodmode.Enabled and RemoteName == "SelfDamage" then
            return
        end
        if RemoteName ~= "LookAngle" and RemoteName ~= "AimPosition" and shared.VapeDeveloper then
            local Caller = getfenv(3)
            Caller = Caller and Caller.script
            if Caller and (not RemoteName) then
                print(Id, "called with", Caller:GetFullName())
            end
            print(Id, RemoteName or Id, ...)
        end

        return Hook(self, Id, ...)
    end

    Hook = hookfunction(FireServer, function(self, Id, ...)
        return FireHook(self, Id, ...)
    end)

    function Jailbreak:FireServer(Id, ...)
        if not Remotes[Id] then
            SendNotification("Vape", `Failed to find remote ({Id})`, 10, "alert")
            return
        end

        return Hook(RemoteTable, Remotes[Id], ...)
    end

    local Arrests = SessionInfo:AddItem("Arrested")
    local MoneyMade = SessionInfo:AddItem("Money Made", 0, ToMoney, true)
    local Bounty = SessionInfo:AddItem("Bounty List", "", function()
        local Text, Board = "", workspace.MostWanted:FindFirstChild("Board", true)
        Board = Board and Board:GetChildren() or {}

        for _, v: Instance in Board do
            if v:IsA("Frame") then
                local PlayerName = v:FindFirstChild("PlayerName", true)
                local BountyLabel = v:FindFirstChild("Bounty", true)
                if PlayerName and BountyLabel then
                    Text = `{Text}\n{PlayerName.Text}: {BountyLabel.Text:gsub(" Bounty", "")}`
                end
            end
        end

        return Text
    end, false)

    local CashFunction, CashHook = GetCash()
    if CashFunction then
        CashHook = hookfunction(CashFunction, function(Amount, Text, ...)
            MoneyMade:Increment(Amount)
            if Text == "Arrest" then
                Arrests:Increment()
            end
            return CashHook(Amount, Text, ...)
        end)
    end

    vape:Clean(function()
        table.clear(Remotes)
        table.clear(Jailbreak)
        hookfunction(FireServer, Hook)
        hookfunction(CashFunction, CashHook)
    end)
end)

for _, v: string in {"Reach", "TriggerBot", "Disabler", "AntiFall", "HitBoxes", "Killaura", "MurderMystery"} do
    vape:Remove(v)
end

Run(function()
	local ForceHeadshot
	
	ForceHeadshot = vape.Categories.Combat:CreateModule({
	    Name = "ForceHeadshot",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Hook
	            Hook = hookfunction(Jailbreak.GunController.BulletEmitterOnLocalHitPlayer, function(...)
	                local ShotData = select(15, ...)
	                ShotData.isHeadshot = true
	                return Hook(...)
	            end)
	        else
	            restorefunction(Jailbreak.GunController.BulletEmitterOnLocalHitPlayer)
	        end
	    end,
	    Tooltip = "Modifies bullets to always do headshot damage."
	})
end)

Run(function()
	local SilentAim
	local Target
	local Mode
	local Range
	local HitChance
	local HeadshotChance
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local Instant
	local Hooked
	local ProjectileRaycast: RaycastParams = RaycastParams.new()
	ProjectileRaycast.RespectCanCollide = true
	
	SilentAim = vape.Categories.Combat:CreateModule({
	    Name = "SilentAim",
	    Function = function(Callback: boolean)
	        if CircleObject then
	            CircleObject.Visible = Callback and Mode.Value == "Mouse"
	        end
	
	        if Callback then
	            Hooked = Jailbreak.GunController.TransformLocalMousePosition
	            Jailbreak.GunController.TransformLocalMousePosition = function(self, Position: Vector3)
	                local Ent = Entity[`Entity{Mode.Value}`]({
	                    Range = Range.Value,
	                    Wallcheck = Target.Walls.Enabled or nil,
	                    Part = "RootPart",
	                    Origin = Entity.isAlive and Entity.character.RootPart.Position or nil,
	                    Players = Target.Players.Enabled,
	                    NPCs = Target.NPCs.Enabled
	                })
	
	                if Ent then
	                    local Item = Jailbreak.ItemSystemController:GetLocalEquipped()
	                    if Item and ((self.Tip.CFrame.Position - Ent.RootPart.Position).Magnitude / (Item.Config.BulletSpeed or 1000)) < Item.BulletEmitter.LifeSpan then
	                        ProjectileRaycast.FilterDescendantsInstances = {Camera, Ent.Character, workspace.Vehicles}
	                        ProjectileRaycast.CollisionGroup = Ent.RootPart.CollisionGroup
	                        local Solution = PredictionLib.SolveTrajectory(self.Tip.CFrame.Position, Item.Config.BulletSpeed or 1000, math.abs(Item.BulletEmitter.GravityVector.Y), Ent.RootPart.Position, Instant.Enabled and Vector3.zero or Ent.RootPart.Velocity, workspace.Gravity, Ent.HipHeight, nil, ProjectileRaycast)
	                        if Solution then
	                            TargetInfo.Targets[Ent] = tick() + 1
	                            return Solution
	                        end
	                    end
	                end
	
	                return Position
	            end
	
	            repeat
	                if CircleObject then
	                    CircleObject.Position = UserInputService:GetMouseLocation()
	                end
	
	                if Instant.Enabled then
	                    local Item = Jailbreak.ItemSystemController:GetLocalEquipped()
	                    if Item and Item.BulletEmitter then
	                        rawset(Item.BulletEmitter, "LastUpdate", tick() - (Item.BulletEmitter.LifeSpan - 0.1))
	                    end
	                end
	
	                task.wait()
	            until not SilentAim.Enabled
	        else
	            Jailbreak.GunController.TransformLocalMousePosition = Hooked
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
	Instant = SilentAim:CreateToggle({Name = "Hitscan Bullets"})
end)

Run(function()
	local AutoArrest
	local Cooldown: number = 0
	
	AutoArrest = vape.Categories.Blatant:CreateModule({
	    Name = "AutoArrest",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local Item = Jailbreak.ItemSystemController:GetLocalEquipped()
	                if Item and Item.__ClassName == "Handcuffs" then
	                    local LocalPosition: Vector3 = Entity.character.Humanoid.HumanoidUnloadServerPosition.Value
	                    local Entities = Entity.AllPosition({
	                        Players = true,
	                        Part = "RootPart",
	                        Range = 50
	                    })
	
	                    for _, Ent: any in Entities do
	                        if Ent.Player and IsIllegal(Ent) then
	                            local Vehicle = Ent.Humanoid.Sit and GetVehicle(Ent) or nil
	                            if Vehicle then
	                                Jailbreak:FireServer("Eject", Vehicle)
	                            elseif not IsArrested(Ent.Player.Name) and (LocalPosition - Ent.RootPart.Position).Magnitude < 18.4 and Cooldown < os.clock() then
	                                Jailbreak:FireServer("Arrest", Ent.Player.Name)
	                                Cooldown = os.clock() + 0.5
	                            end
	                        end
	                    end
	                end
	
	                task.wait(0.016)
	            until not AutoArrest.Enabled
	        end
	    end,
	    Tooltip = "Automatically uses handcuffs on nearby entities"
	})
end)

Run(function()
	local AutoPop
	local Range
	local TeamCheck
	local Delays: {[Model]: number} = {}
	
	local function GetEntitiesInVehicle(Car: Model)
	    local Entities = {}
	
	    for _, Seat: Instance in Car:GetChildren() do
	        if (Seat.Name == "Seat" or Seat.Name == "Passenger") then
	            Seat = Seat:FindFirstChild("PlayerName")
	            if Seat then
	                for _, Ent: any in Entity.List do
	                    if Ent.Player and Ent.Player.Name == Seat.Value then
	                        table.insert(Entities, Ent)
	                    end
	                end
	            end
	        end
	    end
	
	    return Entities
	end
	
	local function GetVehiclesNear()
	    local Allowed: {Model} = {}
	
	    if Entity.isAlive then
	        local LocalPosition: Vector3 = Entity.character.HumanoidRootPart.Position
	        for _, Car: Model in CollectionService:GetTagged("Vehicle") do
	            if Car.PrimaryPart and (Car.PrimaryPart.Position - LocalPosition).Magnitude <= Range.Value then
	                local Entities = GetEntitiesInVehicle(Car)
	                local Check: boolean = #Entities > 0
	                if TeamCheck.Enabled then
	                    for _, Ent: any in Entities do
	                        if not Ent.Targetable then
	                            Check = false
	                            break
	                        end
	                    end
	                end
	
	                if Check then
	                    table.insert(Allowed, Car)
	                end
	            end
	        end
	    end
	
	    return Allowed
	end
	
	AutoPop = vape.Categories.Blatant:CreateModule({
	    Name = "AutoPop",
	    Function = function(Callback: boolean)
	        if Callback then
	            task.spawn(function()
	                repeat
	                    local Item = Jailbreak.ItemSystemController:GetLocalEquipped()
	                    if Item and Item.BulletEmitter and Item.Model then
	                        for _, Car: Model in GetVehiclesNear() do
	                            if (Car:GetAttribute("VehicleTireHealth") or 10) <= 0 then
	                                continue
	                            end
	
	                            if (Delays[Car] or 0) > os.clock() then
	                                continue
	                            end
	
	                            Delays[Car] = os.clock() + 0.1
	                            Jailbreak:FireServer("PopTires", Car, Item.Model.Name)
	                        end
	                    end
	
	                    task.wait(0.016)
	                until not AutoPop.Enabled
	            end)
	        else
	            table.clear(Delays)
	        end
	    end,
	    Tooltip = "Automatically pops vehicles tires around you"
	})
	Range = AutoPop:CreateSlider({
	    Name = "Range",
	    Min = 1,
	    Max = 600,
	    Default = 600
	})
	TeamCheck = AutoPop:CreateToggle({Name = "Team Check"})
end)

Run(function()
	local AutoPunch
	
	AutoPunch = vape.Categories.Blatant:CreateModule({
	    Name = "AutoPunch",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                if Entity.isAlive then
	                    Jailbreak:FireServer("Punch")
	                end
	
	                task.wait(0.3)
	            until not AutoPunch.Enabled
	        end
	    end,
	    Tooltip = "Always punches people infront of you"
	})
end)

Run(function()
	local AutoTaze
	local HandCheck
	local Cooldown: number = 0
	
	AutoTaze = vape.Categories.Blatant:CreateModule({
	    Name = "AutoTaze",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local Item = Jailbreak.ItemSystemController:GetLocalEquipped()
	                Item = Item and Item.__ClassName == "Taser" or nil
	                if not HandCheck.Enabled or Item then
	                    local Ent = Entity.EntityPosition({
	                        Players = true,
	                        Part = "RootPart",
	                        Range = 50
	                    })
	
	                    if Ent and IsIllegal(Ent) and not IsArrested(Ent.Player.Name) and Cooldown < os.clock() then
	                        if Item then
	                            Jailbreak:FireServer("TaseReplicate", Ent.Head.Position)
	                        end
	
	                        Jailbreak:FireServer("Tase", Ent.Humanoid, Ent.Head, Ent.Head.Position)
	                        Cooldown = os.clock() + 10
	                    end
	                end
	
	                task.wait(0.016)
	            until not AutoTaze.Enabled
	        end
	    end,
	    Tooltip = "Immobilizes entities around you"
	})
	HandCheck = AutoTaze:CreateToggle({Name = "Hand Check"})
end)

Run(function()
	LazerGodmode = vape.Categories.Blatant:CreateModule({Name = "LazerGodmode"})
end)

Run(function()
	vape.Categories.Blatant:CreateModule({
	    Name = "NoFall",
	    Function = function(Callback: boolean)
	        debug.setconstant(debug.getupvalue(Jailbreak.FallingController.Init, 20), 9, Callback and "Archivable" or "Sit")
	    end,
	    Tooltip = "Disables ragdoll handling & fall damage"
	})
end)

Run(function()
	local NitroTable = debug.getupvalue(Jailbreak.VehicleController.NitroShopVisible, 1)
	local OldNitro: number
	
	InfNitro = vape.Categories.Utility:CreateModule({
	    Name = "InfiniteNitro",
	    Function = function(Callback: boolean)
	        if Callback then
	            OldNitro = NitroTable.Nitro
	            Jailbreak.VehicleController.updateSpdBarRatio(1)
	
	            repeat
	                NitroTable.Nitro = 250
	                task.wait(0.1)
	            until not InfNitro.Enabled
	        else
	            NitroTable.Nitro = OldNitro
	            Jailbreak.VehicleController.updateSpdBarRatio(OldNitro / 250)
	        end
	    end,
	    Tooltip = "Infinite boost for the local car"
	})
end)

Run(function()
	vape.Categories.Utility:CreateModule({
	    Name = "InstantAction",
	    Function = function(Callback: boolean)
	        debug.setconstant(Jailbreak.CircleAction.Press, 3, Callback and "Timeda" or "Timed")
	    end,
	    Tooltip = "Allows you to instantly complete ProximityPrompt actions"
	})
end)