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
local RunService: RunService = cloneref(game:GetService("RunService"))
local CoreGui: CoreGui = cloneref(game:GetService("CoreGui"))

local Camera: Camera = workspace.CurrentCamera
local LocalPlayer: Player = Players.LocalPlayer
local vape = shared.vape
local Entity = vape.Libraries.entity
local TargetInfo = vape.Libraries.targetinfo
local MapObject
local LeaderStats

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

local function SendNotification(...)
    return vape:CreateNotification(...)
end

local function WaitForChildOfType(Object: Instance, Name: string, Timeout: number, Property: boolean?)
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
    LeaderStats = LocalPlayer:FindFirstChild("TempPlayerStatsModule")
    if not LeaderStats then
        repeat
            LeaderStats = LocalPlayer:FindFirstChild("TempPlayerStatsModule")
            task.wait()
        until LeaderStats or vape.Loaded == nil

        if vape.Loaded == nil then
            return
        end
    end

    local MapValue: ObjectValue = ReplicatedStorage.CurrentMap
    local function UpdateMap()
        if MapValue.Value then
            MapObject = MapValue.Value
            VapeEvents.MapAdded:Fire(MapObject)
        elseif MapObject then
            VapeEvents.MapRemoved:Fire(MapObject)
            MapObject = nil
        end
    end

    vape:Clean(MapValue:GetPropertyChangedSignal("Value"):Connect(UpdateMap))
    if MapValue.Value then
        UpdateMap()
    end
end)

Run(function()
    Entity.addEntity = function(Character: Model, Player: Player?, TeamFunc)
        if not Character then
            return
        end
        Entity.EntityThreads[Character] = task.spawn(function()
            local Humanoid: Humanoid? = WaitForChildOfType(Character, "Humanoid", 10)
            local RootPart = Humanoid and WaitForChildOfType(Humanoid, "RootPart", workspace.StreamingEnabled and 9e9 or 10, true)
            local Head = Character:WaitForChild("Head", 10) or RootPart
            local PlayerStats = Player:WaitForChild("TempPlayerStatsModule", 10) or {IsBeast = {GetPropertyChangedSignal = function() return {Connect = function() end} end}}

            if Humanoid and RootPart then
                local Target = {
                    Connections = {},
                    Character = Character,
                    Health = Humanoid.Health,
                    Head = Head,
                    Humanoid = Humanoid,
                    HumanoidRootPart = RootPart,
                    IsBeast = PlayerStats.IsBeast.Value,
                    HipHeight = Humanoid.HipHeight + (RootPart.Size.Y / 2) + (Humanoid.RigType == Enum.HumanoidRigType.R6 and 2 or 0),
                    MaxHealth = Humanoid.MaxHealth,
                    NPC = Player == nil,
                    Player = Player,
                    RootPart = RootPart,
                    TeamCheck = TeamFunc
                }

                if Player == LocalPlayer then
                    Entity.character = Target
                    Entity.isAlive = true
                    Entity.Events.LocalAdded:Fire(Target)
                else
                    Target.Targetable = Entity.targetCheck(Target)

                    table.insert(Target.Connections, PlayerStats.IsBeast:GetPropertyChangedSignal("Value"):Connect(function()
                        Entity.refreshEntity(Target.Character, Target.Player)
                    end))

                    for _, v: RBXScriptSignal in Entity.getUpdateConnections(Target) do
                        table.insert(Target.Connections, v:Connect(function()
                            Target.Health = Humanoid.Health
                            Target.MaxHealth = Humanoid.MaxHealth
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

    Entity.getEntityColor = function(Ent)
        if not (Ent.Player and vape.Settings.Modules.Options["Use team color"].Enabled) then
            return
        end
        if IsFriend(Ent.Player, true) then
            return Color3.fromHSV(vape.Categories.Friends.Options["Friends color"].Hue, vape.Categories.Friends.Options["Friends color"].Sat, vape.Categories.Friends.Options["Friends color"].Value)
        end
        return Ent.IsBeast and Color3.new(1, 0.2, 0.2) or Color3.new(0.3, 1, 0.3)
    end

    Entity.start()
end)

for _, v: string in {"AimAssist", "Reach", "SilentAim", "TriggerBot", "AntiFall", "Invisible", "Jesus", "Killaura", "AntiRagdoll", "Disabler", "MurderMystery"} do
    vape:Remove(v)
end

Run(function()
	local NoSlowdown
	local Old
	
	NoSlowdown = vape.Categories.Blatant:CreateModule({
	    Name = "NoSlowdown",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                for _, v: any in getconnections(UserInputService.JumpRequest) do
	                    if v.Function and debug.info(v.Function, "s"):find("PowersLocalScript") then
	                        Old = v
	                        v:Disable()
	                    end
	                end
	
	                task.wait(0.1)
	            until not NoSlowdown.Enabled
	        else
	            if Old then
	                Old:Enable()
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Prevent slowing down when jumping as the beast"
	})
end)

Run(function()
	local PhaseHammer
	local Old
	
	local function GetEnvironment(ClubScript: Instance)
	    local Environment = getsenv(ClubScript)
	    if not (Environment and Environment.OnClick) then
	        repeat
	            Environment = getsenv(ClubScript)
	            task.wait()
	        until Environment and Environment.OnClick or not PhaseHammer.Enabled
	    end
	
	    return PhaseHammer.Enabled and Environment
	end
	
	local function AddHammer(Hammer: Instance?)
	    if Hammer and Hammer.Name == "Hammer" then
	        local ClubScript: Instance? = Hammer:WaitForChild("LocalClubScript", 3)
	        if ClubScript and PhaseHammer.Enabled then
	            local Environment = GetEnvironment(ClubScript)
	            if not Environment then
	                return
	            end
	
	            Old = Environment.OnClick
	            debug.setconstant(debug.getproto(Old, 1), 7, 0)
	        end
	    end
	end
	
	local function AddEntity(Ent)
	    PhaseHammer:Clean(Ent.Character.ChildAdded:Connect(AddHammer))
	    AddHammer(Ent.Character:FindFirstChild("Hammer"))
	end
	
	PhaseHammer = vape.Categories.Blatant:CreateModule({
	    Name = "PhaseHammer",
	    Function = function(Callback: boolean)
	        if Callback then
	            PhaseHammer:Clean(Entity.Events.LocalAdded:Connect(AddEntity))
	            if Entity.isAlive then
	                task.spawn(AddEntity, Entity.character)
	            end
	        else
	            if Old then
	                debug.setconstant(debug.getproto(Old, 1), 7, 0.95)
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Allow your hammer to clip through walls"
	})
end)

Run(function()
	local RestrainBeast
	
	RestrainBeast = vape.Categories.Blatant:CreateModule({
	    Name = "RestrainBeast",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                for _, v: any in Entity.List do
	                    local Remote = v.IsBeast and v.Character:FindFirstChild("HammerEvent", true)
	                    if Remote and Remote:IsA("RemoteEvent") then
	                        Remote:FireServer("HammerClick", true)
	                    end
	                end
	
	                task.wait(0.1)
	            until not RestrainBeast.Enabled
	        end
	    end,
	    Tooltip = "Force the beast to be unable to hook onto survivors"
	})
end)

Run(function()
	local SlowBeast
	
	SlowBeast = vape.Categories.Blatant:CreateModule({
	    Name = "SlowBeast",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                for _, v: any in Entity.List do
	                    local Remote = v.IsBeast and v.Character:FindFirstChild("PowersEvent", true)
	                    if Remote and Remote:IsA("RemoteEvent") then
	                        Remote:FireServer("Jumped")
	                    end
	                end
	
	                task.wait(0.1)
	            until not SlowBeast.Enabled
	        end
	    end,
	    Tooltip = "Force the beast to be slowed"
	})
end)

Run(function()
	local SpamBeast
	
	SpamBeast = vape.Categories.Blatant:CreateModule({
	    Name = "SpamBeast",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                for _, v: any in Entity.List do
	                    local Remote = v.IsBeast and v.Character:FindFirstChild("PowersEvent", true)
	                    if Remote and Remote:IsA("RemoteEvent") then
	                        Remote:FireServer("Input")
	                    end
	                end
	
	                task.wait(0.1)
	            until not SpamBeast.Enabled
	        end
	    end,
	    Tooltip = "Force the beast to use abilities"
	})
end)

Run(function()
	local ComputerESP
	local FillColor
	local OutlineColor
	local FillTransparency
	local OutlineTransparency
	local Reference: {[Model]: Highlight} = {}
	local Folder: Folder = Instance.new("Folder")
	Folder.Parent = vape.gui
	
	local function Added(Computer: Model)
	    local Screen: BasePart = Computer:FindFirstChild("Screen")
	    local Highlight: Highlight = Instance.new("Highlight")
	    Highlight.Adornee = Computer
	    Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	    Highlight.FillColor = Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
	    Highlight.OutlineColor = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
	    Highlight.FillTransparency = FillTransparency.Value
	    Highlight.OutlineTransparency = OutlineTransparency.Value
	    Highlight.Parent = Folder
	    Highlight.Enabled = Screen.Color ~= Color3.fromRGB(40, 127, 71)
	
	    ComputerESP:Clean(Screen:GetPropertyChangedSignal("Color"):Connect(function()
	        Highlight.Enabled = Screen.Color ~= Color3.fromRGB(40, 127, 71)
	    end))
	
	    Reference[Computer] = Highlight
	end
	
	local function Removed(Computer: Model)
	    if Reference[Computer] then
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	
	        Reference[Computer]:Destroy()
	        Reference[Computer] = nil
	    end
	end
	
	local function MapAdded(Map: Instance)
	    local Status: StringValue = ReplicatedStorage.GameStatus
	    if Status.Value:find("LOADING") or Status.Value:find("START") then
	        repeat
	            task.wait()
	        until not (Status.Value:find("LOADING") or Status.Value:find("START")) or not ComputerESP.Enabled
	
	        if not ComputerESP.Enabled then
	            return
	        end
	    end
	
	    for _, v: Instance in Map:GetChildren() do
	        if v.Name == "ComputerTable" then
	            task.spawn(Added, v)
	        end
	    end
	end
	
	ComputerESP = vape.Categories.Render:CreateModule({
	    Name = "ComputerESP",
	    Function = function(Callback: boolean)
	        if Callback then
	            ComputerESP:Clean(VapeEvents.MapAdded.Event:Connect(MapAdded))
	            ComputerESP:Clean(VapeEvents.MapRemoved.Event:Connect(function()
	                for _, v: Highlight in Reference do
	                    v:Destroy()
	                end
	                table.clear(Reference)
	            end))
	
	            if MapObject then
	                task.spawn(MapAdded, MapObject)
	            end
	        else
	            for _, v: Highlight in Reference do
	                v:Destroy()
	            end
	            table.clear(Reference)
	        end
	    end,
	    Tooltip = "Show nearby uncompleted computers."
	})
	FillColor = ComputerESP:CreateColorSlider({
	    Name = "Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        for _, v: Highlight in Reference do
	            v.FillColor = Color3.fromHSV(Hue, Sat, Val)
	        end
	    end
	})
	OutlineColor = ComputerESP:CreateColorSlider({
	    Name = "Outline Color",
	    DefaultSat = 0,
	    Function = function(Hue: number, Sat: number, Val: number)
	        for _, v: Highlight in Reference do
	            v.OutlineColor = Color3.fromHSV(Hue, Sat, Val)
	        end
	    end
	})
	FillTransparency = ComputerESP:CreateSlider({
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
	OutlineTransparency = ComputerESP:CreateSlider({
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
	local AutoComputer
	local Connection, Old
	
	local function GetConnection(Event)
	    local ChangedConnection = getconnections(LeaderStats.TimingGoalPosition.Changed)[1]
	    if not ChangedConnection then
	        repeat
	            ChangedConnection = getconnections(LeaderStats.TimingGoalPosition.Changed)[1]
	            task.wait()
	        until ChangedConnection or not AutoComputer.Enabled
	    end
	
	    return AutoComputer.Enabled and ChangedConnection
	end
	
	AutoComputer = vape.Categories.Utility:CreateModule({
	    Name = "AutoComputer",
	    Function = function(Callback: boolean)
	        if Callback then
	            Connection = GetConnection()
	            if not Connection then
	                return
	            end
	
	            Old = hookfunction(Connection.Function, function(...)
	                if LocalPlayer.TempPlayerStatsModule.TimingGoalPosition.Value > 0 then
	                    ReplicatedStorage.RemoteEvent:FireServer("SetPlayerMinigameResult", true)
	                end
	            end)
	        else
	            if Old and Connection.Function then
	                hookfunction(Connection.Function, Old)
	            end
	            Connection = nil
	        end
	    end,
	    Tooltip = "Automatically complete the computer skill check."
	})
end)