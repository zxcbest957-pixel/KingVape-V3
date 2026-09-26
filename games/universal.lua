local loadstring = function(...)
    local str = ...
    if typeof(str) ~= 'string' or str == '' or str == '404: Not Found' then
        return function() return {} end
    end
    local Chunk, Error = loadstring(...)
    if Error and vape then
        vape:CreateNotification("Vape", `Failed to load : {Error}`, 30, "alert")
    end
    return Chunk or function() return {} end
end
local isfile = isfile or function(File: string)
    local Success, Contents = pcall(function()
        return readfile(File)
    end)
    return Success and Contents ~= nil and Contents ~= ""
end
local isfolder = isfolder or function() return true end
local makefolder = makefolder or function() end

local function ensureFolder(filePath: string)
    local parts = filePath:split("/")
    if #parts > 1 then
        local current = ""
        for i = 1, #parts - 1 do
            current = current .. (i > 1 and "/" or "") .. parts[i]
            if not isfolder(current) then
                pcall(makefolder, current)
            end
        end
    end
end

local function DownloadFile(Path: string, Func)
    local content
    if isfile(Path) then
        pcall(function() content = readfile(Path) end)
    end
    if not content or content == "" or content == "404: Not Found" or typeof(content) ~= "string" then
        local relPath = select(1, Path:gsub("kingvape/", ""))
        local url = "https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/main/" .. relPath
        local cdnUrl = "https://cdn.jsdelivr.net/gh/zxcbest957-pixel/KingVape-V3@main/" .. relPath
        local Success, Response = pcall(function()
            return game:HttpGet(url, true)
        end)
        if not Success or not Response or Response == "" or Response == "404: Not Found" then
            pcall(function()
                Response = game:HttpGet(cdnUrl, true)
            end)
        end
        if Response and typeof(Response) == "string" and Response ~= "404: Not Found" and Response ~= "" then
            content = Response
            if Path:find("%.lua") and not content:find("--This watermark") then
                content = "--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n" .. content
            end
            pcall(function()
                ensureFolder(Path)
                writefile(Path, content)
            end)
        end
    end
    if typeof(content) ~= "string" then content = "" end
    if Func then
        local suc, res = pcall(Func, Path)
        return suc and res or content
    end
    return content
end
local BuildClock: number = os.clock()
local BuildBudget: number = 0.004
local Run = function(Func)
    Func()

    if os.clock() - BuildClock > BuildBudget then
        BuildBudget = math.clamp(task.wait() * 0.75, 0.004, 0.02)
        BuildClock = os.clock()
    end
end
local queue_on_teleport = queue_on_teleport or function() end
local cloneref = cloneref or function(Reference: Instance)
    return Reference
end

local Players: Players = cloneref(game:GetService("Players"))
local ReplicatedStorage: ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService: RunService = cloneref(game:GetService("RunService"))
local UserInputService: UserInputService = cloneref(game:GetService("UserInputService"))
local TweenService: TweenService = cloneref(game:GetService("TweenService"))
local Lighting: Lighting = cloneref(game:GetService("Lighting"))
local MarketplaceService: MarketplaceService = cloneref(game:GetService("MarketplaceService"))
local ProximityPromptService: ProximityPromptService = cloneref(game:GetService("ProximityPromptService"))
local TeleportService: TeleportService = cloneref(game:GetService("TeleportService"))
local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local GuiService: GuiService = cloneref(game:GetService("GuiService"))
local GroupService: GroupService = cloneref(game:GetService("GroupService"))
local TextChatService: TextChatService = cloneref(game:GetService("TextChatService"))
local ContextActionService: ContextActionService = cloneref(game:GetService("ContextActionService"))
local CoreGui: CoreGui = cloneref(game:GetService("CoreGui"))
local Stats: Stats = cloneref(game:GetService("Stats"))

local isnetworkowner = identifyexecutor and table.find({"AWP", "Nihon"}, ({identifyexecutor()})[1]) and isnetworkowner or function()
    return true
end
local Camera: Camera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA("Camera")
local LocalPlayer: Player = Players.LocalPlayer
local AssetFunction = getcustomasset

local vape = shared.vape
local Tween = vape.Libraries.tween
local TargetInfo = vape.Libraries.targetinfo
local GetFontBounds = vape.Libraries.getfontbounds
local GetVapeAsset = vape.Libraries.getvapeasset
local UIPallet = vape.Libraries.uipallet

local TargetStrafeVector, SpiderShift, WaypointFolder
local Spider = {Enabled = false}
local Phase = {Enabled = false}

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

local function CalculateMoveVector(Vector: Vector3)
    local Cosine, Sine
    local _, _, _, R00, R01, R02, _, _, R12, _, _, R22 = Camera.CFrame:GetComponents()
    if R12 < 1 and R12 > -1 then
        Cosine = R22
        Sine = R02
    else
        Cosine = R00
        Sine = -R01 * math.sign(R12)
    end
    Vector = Vector3.new((Cosine * Vector.X + Sine * Vector.Z), 0, (Cosine * Vector.Z - Sine * Vector.X)) / math.sqrt(Cosine * Cosine + Sine * Sine)
    return Vector.Unit == Vector.Unit and Vector.Unit or Vector3.zero
end

local function IsFriend(Player: Player, Recolor: boolean?)
    if vape.Categories.Friends.Options["Use friends"].Enabled then
        local Friend: boolean? = table.find(vape.Categories.Friends.ListEnabled, Player.Name) and true
        if Recolor then
            Friend = Friend and vape.Categories.Friends.Options["Recolor visuals"].Enabled
        end
        return Friend
    end
    return nil
end

local function IsTarget(Player: Player)
    return table.find(vape.Categories.Targets.ListEnabled, Player.Name) and true
end

local function CanClick()
    local MousePosition: Vector2 = (UserInputService:GetMouseLocation() - GuiService:GetGuiInset())
    for _, v: GuiObject in LocalPlayer.PlayerGui:GetGuiObjectsAtPosition(MousePosition.X, MousePosition.Y) do
        local ScreenGui: ScreenGui? = v:FindFirstAncestorOfClass("ScreenGui")
        if v.Active and v.Visible and ScreenGui and ScreenGui.Enabled then
            return false
        end
    end
    for _, v: GuiObject in CoreGui:GetGuiObjectsAtPosition(MousePosition.X, MousePosition.Y) do
        local ScreenGui: ScreenGui? = v:FindFirstAncestorOfClass("ScreenGui")
        if v.Active and v.Visible and ScreenGui and ScreenGui.Enabled then
            return false
        end
    end
    return (not vape.gui.ScaledGui.ClickGui.Visible) and (not UserInputService:GetFocusedTextBox())
end

local function GetTableSize(Table: {[any]: any})
    local Count: number = 0
    for _ in Table do
        Count += 1
    end
    return Count
end

local function GetTool()
    return LocalPlayer.Character and LocalPlayer.Character:FindFirstChildWhichIsA("Tool", true) or nil
end

local function SendNotification(...)
    return vape:CreateNotification(...)
end

local function RemoveTags(Text: string)
    Text = Text:gsub("<br%s*/>", "\n")
    return (Text:gsub("<[^<>]->", ""))
end

local function RakNetCheck(ModuleName: string)
    if not (raknet and raknet.add_send_hook and pcall(raknet.add_send_hook, function() end)) then
        SendNotification(ModuleName, "This feature requires raknet! (risky feature, please do not use on mains.)", 10, "warning")
        return false
    end

    return true
end

local Visited, Attempted, TeleportSwitch = {}, {}, false
local CacheExpire, Cache = tick()
local function HopServer(Pointer: string?, Filter: string)
    Visited = shared.vapeserverhoplist and shared.vapeserverhoplist:split("/") or {}
    if not table.find(Visited, game.JobId) then
        table.insert(Visited, game.JobId)
    end
    if not Pointer then
        SendNotification("Vape", "Searching for an available server.", 2)
    end

    local Success, HttpData = pcall(function()
        return CacheExpire < tick() and game:HttpGet(`https://games.roblox.com/v1/games/{game.PlaceId}/servers/Public?sortOrder={Filter == "Ascending" and 1 or 2}&excludeFullGames=true&limit=100{Pointer and `&cursor={Pointer}` or ""}`) or Cache
    end)
    local Data = Success and HttpService:JSONDecode(HttpData) or nil
    if Data and Data.data then
        for _, v: any in Data.data do
            if tonumber(v.playing) < Players.MaxPlayers and not table.find(Visited, v.id) and not table.find(Attempted, v.id) then
                CacheExpire, Cache = tick() + 60, HttpData
                table.insert(Attempted, v.id)

                SendNotification("Vape", "Found! Teleporting.", 5)
                TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id)
                return
            end
        end

        if Data.nextPageCursor then
            HopServer(Data.nextPageCursor, Filter)
        else
            SendNotification("Vape", "Failed to find an available server.", 5, "warning")
        end
    else
        SendNotification("Vape", `Failed to grab servers. ({Data and Data.errors[1].message or "no data"})`, 5, "warning")
    end
end

vape:Clean(LocalPlayer.OnTeleport:Connect(function()
    if not TeleportSwitch then
        TeleportSwitch = true
        queue_on_teleport(`shared.vapeserverhoplist = '{table.concat(Visited, "/")}'\nshared.vapeserverhopprevious = '{game.JobId}'`)
    end
end))

local FrictionTable, OldFriction, Entity = {}, {}
local function UpdateVelocity()
    if GetTableSize(FrictionTable) > 0 then
        if Entity.isAlive then
            for _, v: Instance in Entity.character.Character:GetChildren() do
                if v:IsA("BasePart") and v.Name ~= "HumanoidRootPart" and not OldFriction[v] then
                    OldFriction[v] = v.CustomPhysicalProperties or "none"
                    v.CustomPhysicalProperties = PhysicalProperties.new(0.0001, 0.2, 0.5, 1, 1)
                end
            end
        end
    else
        for Part: BasePart, v: any in OldFriction do
            Part.CustomPhysicalProperties = v ~= "none" and v or nil
        end
        table.clear(OldFriction)
    end
end

local function MotorMove(Target: BasePart, Offset: CFrame)
    local Part: Part = Instance.new("Part")
    Part.Anchored = true
    Part.Parent = workspace
    local Motor: Motor6D = Instance.new("Motor6D")
    Motor.Part0 = Target
    Motor.Part1 = Part
    Motor.C1 = Offset
    Motor.Parent = Part
    task.delay(0, Part.Destroy, Part)
end

local Hash = loadstring(DownloadFile("kingvape/libraries/hash.lua"), "hash")()
local PredictionLib = loadstring(DownloadFile("kingvape/libraries/prediction.lua"), "prediction")()
Entity = loadstring(DownloadFile("kingvape/libraries/entity.lua"), "entitylibrary")()
local Render = loadstring(DownloadFile("kingvape/libraries/render.lua"), "render")()
local Whitelist = {
    alreadychecked = {},
    customtags = {},
    tagcallback = {},
    data = {WhitelistedUsers = {}},
    hashes = setmetatable({}, {
        __index = function(self, Key: string)
            if not Hash then
                return ""
            end
            local Result: string = Hash.sha512(`{Key}SelfReport`)
            rawset(self, Key, Result)
            return Result
        end
    }),
    hooked = false,
    loaded = false,
    localprio = 0,
    said = {}
}
vape.Libraries.entity = Entity
vape.Libraries.whitelist = Whitelist
vape.Libraries.prediction = PredictionLib
vape.Libraries.hash = Hash
vape.Libraries.render = Render
vape.Libraries.auraanims = {
    Normal = {
        {CFrame = CFrame.new(-0.17, -0.14, -0.12) * CFrame.Angles(math.rad(-53), math.rad(50), math.rad(-64)), Time = 0.1},
        {CFrame = CFrame.new(-0.55, -0.59, -0.1) * CFrame.Angles(math.rad(-161), math.rad(54), math.rad(-6)), Time = 0.08},
        {CFrame = CFrame.new(-0.62, -0.68, -0.07) * CFrame.Angles(math.rad(-167), math.rad(47), math.rad(-1)), Time = 0.03},
        {CFrame = CFrame.new(-0.56, -0.86, 0.23) * CFrame.Angles(math.rad(-167), math.rad(49), math.rad(-1)), Time = 0.03}
    },
    Random = {},
    ["Horizontal Spin"] = {
        {CFrame = CFrame.Angles(math.rad(-10), math.rad(-90), math.rad(-80)), Time = 0.12},
        {CFrame = CFrame.Angles(math.rad(-10), math.rad(180), math.rad(-80)), Time = 0.12},
        {CFrame = CFrame.Angles(math.rad(-10), math.rad(90), math.rad(-80)), Time = 0.12},
        {CFrame = CFrame.Angles(math.rad(-10), 0, math.rad(-80)), Time = 0.12}
    },
    ["Vertical Spin"] = {
        {CFrame = CFrame.Angles(math.rad(-90), 0, math.rad(15)), Time = 0.12},
        {CFrame = CFrame.Angles(math.rad(180), 0, math.rad(15)), Time = 0.12},
        {CFrame = CFrame.Angles(math.rad(90), 0, math.rad(15)), Time = 0.12},
        {CFrame = CFrame.Angles(0, 0, math.rad(15)), Time = 0.12}
    },
    Exhibition = {
        {CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.1},
        {CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.2}
    },
    ["Exhibition Old"] = {
        {CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.15},
        {CFrame = CFrame.new(0.69, -0.7, 0.6) * CFrame.Angles(math.rad(-30), math.rad(50), math.rad(-90)), Time = 0.05},
        {CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.1},
        {CFrame = CFrame.new(0.7, -0.71, 0.59) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.05},
        {CFrame = CFrame.new(0.63, -0.1, 1.37) * CFrame.Angles(math.rad(-84), math.rad(50), math.rad(-38)), Time = 0.15}
    }
}

local SpeedMethods
local SpeedMethodList = {"Velocity"}
SpeedMethods = {
    Velocity = function(Options, MoveDirection: Vector3)
        local Root: BasePart = Entity.character.RootPart
        Root.AssemblyLinearVelocity = (MoveDirection * Options.Value.Value) + Vector3.new(0, Root.AssemblyLinearVelocity.Y, 0)
    end,
    Impulse = function(Options, MoveDirection: Vector3)
        local Root: BasePart = Entity.character.RootPart
        local Difference: Vector3 = ((MoveDirection * Options.Value.Value) - Root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
        if Difference.Magnitude > (MoveDirection == Vector3.zero and 10 or 2) then
            Root:ApplyImpulse(Difference * Root.AssemblyMass)
        end
    end,
    CFrame = function(Options, MoveDirection: Vector3, Delta: number)
        local Root: BasePart = Entity.character.RootPart
        local Destination: Vector3 = (MoveDirection * math.max(Options.Value.Value - Entity.character.Humanoid.WalkSpeed, 0) * Delta)
        if Options.WallCheck.Enabled then
            Options.rayCheck.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
            Options.rayCheck.CollisionGroup = Root.CollisionGroup
            local Ray: RaycastResult? = workspace:Raycast(Root.Position, Destination, Options.rayCheck)
            if Ray then
                Destination = ((Ray.Position + Ray.Normal) - Root.Position)
            end
        end
        Root.CFrame += Destination
    end,
    TP = function(Options, MoveDirection: Vector3)
        if Options.TPTiming < tick() then
            Options.TPTiming = tick() + Options.TPFrequency.Value
            SpeedMethods.CFrame(Options, MoveDirection, 1)
        end
    end,
    WalkSpeed = function(Options)
        if not Options.WalkSpeed then
            Options.WalkSpeed = Entity.character.Humanoid.WalkSpeed
        end
        Entity.character.Humanoid.WalkSpeed = Options.Value.Value
    end,
    Pulse = function(Options, MoveDirection: Vector3)
        local Root: BasePart = Entity.character.RootPart
        local Delta: number = math.max(Options.Value.Value - Entity.character.Humanoid.WalkSpeed, 0)
        Delta = Delta * (1 - math.min((tick() % (Options.PulseLength.Value + Options.PulseDelay.Value)) / Options.PulseLength.Value, 1))
        Root.AssemblyLinearVelocity = (MoveDirection * (Entity.character.Humanoid.WalkSpeed + Delta)) + Vector3.new(0, Root.AssemblyLinearVelocity.Y, 0)
    end
}
for Method: string in SpeedMethods do
    if not table.find(SpeedMethodList, Method) then
        table.insert(SpeedMethodList, Method)
    end
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
                    return {
                        Disconnect = function() end
                    }
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
        if vape.Settings.Modules.Options["Teams by server"].Enabled then
            if not LocalPlayer.Team then
                return true
            end
            if not Ent.Player.Team then
                return true
            end
            if Ent.Player.Team ~= LocalPlayer.Team then
                return true
            end
            return #Ent.Player.Team:GetPlayers() == #Players:GetPlayers()
        end
        return true
    end

    Entity.getEntityColor = function(Ent)
        Ent = Ent.Player
        if not (Ent and vape.Settings.Modules.Options["Use team color"].Enabled) then
            return
        end
        if IsFriend(Ent, true) then
            return Color3.fromHSV(vape.Categories.Friends.Options["Friends color"].Hue, vape.Categories.Friends.Options["Friends color"].Sat, vape.Categories.Friends.Options["Friends color"].Value)
        end
        return tostring(Ent.TeamColor) ~= "White" and Ent.TeamColor.Color or nil
    end

    vape:Clean(function()
        Entity.kill()
        Entity = nil
    end)
    vape:Clean(Render.uninstall)
    vape:Clean(vape.Categories.Friends.Update.Event:Connect(function()
        Entity.refresh()
    end))
    vape:Clean(vape.Categories.Targets.Update.Event:Connect(function()
        Entity.refresh()
    end))
    vape:Clean(Entity.Events.LocalAdded:Connect(UpdateVelocity))
    vape:Clean(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        Camera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA("Camera")
    end))
end)

Run(function()
    function Whitelist:get(Player: Player)
        local PlayerHash: string = self.hashes[`{Player.Name}{Player.UserId}`]
        for _, v: any in self.data.WhitelistedUsers do
            if v.hash == PlayerHash then
                return v.level, v.attackable or Whitelist.localprio >= v.level, v.tags
            end
        end

        return 0, true
    end

    function Whitelist:isingame()
        for _, v: Player in Players:GetPlayers() do
            if self:get(v) ~= 0 then
                return true
            end
        end

        return false
    end

    function Whitelist:tag(Player: Player, Text: boolean?, Rich: boolean?)
        local PlayerTags, NewTag = table.clone(select(3, self:get(Player)) or self.customtags[Player.Name] or {}), ""
        for _, v: (...any) -> ...any in self.tagcallback do
            v(Player, PlayerTags, Rich)
        end

        if not Text then
            return PlayerTags
        end

        for _, v: any in PlayerTags do
            NewTag = `{NewTag}{Rich and v.color and `<font color="#{v.color:ToHex()}">[{v.text}]</font>` or `[{RemoveTags(v.text)}]`} `
        end

        return NewTag
    end

    function Whitelist:getplayer(Argument: string?, Player: Player)
        if Argument == "default" and self.localprio == 0 then
            return true
        end

        if Argument == "private" and self.localprio == 1 then
            return true
        end

        if Argument == "others" and Player ~= LocalPlayer then
            return true
        end

        if Argument and LocalPlayer.Name:lower():sub(1, Argument:len()) == Argument:lower() then
            return true
        end

        return false
    end

    local OldUninject
    function Whitelist:playeradded(Player: Player, Joined: boolean?)
        if self:get(Player) ~= 0 then
            if self.alreadychecked[Player.UserId] then
                return
            end
            self.alreadychecked[Player.UserId] = true
            self:hook()

            if self.localprio == 0 then
                OldUninject = vape.Uninject
                vape.Uninject = function()
                    SendNotification("Vape", "No escaping the private members :)", 10)
                end
            end
        end
    end

    function Whitelist:process(Message: string, Player: Player)
        if self.localprio < self:get(Player) or Player == LocalPlayer then
            local Arguments: {string} = Message:split(" ")
            table.remove(Arguments, 1)

            if self:getplayer(Arguments[1], Player) then
                table.remove(Arguments, 1)
                for Command: string, v: (...any) -> ...any in self.commands do
                    if Message:sub(1, Command:len() + 1):lower() == `;{Command:lower()}` then
                        v(Arguments, Player)
                        return true
                    end
                end
            end
        end

        return false
    end

    function Whitelist:newchat(Properties, Player: Player, Skip: boolean)
        Properties.PrefixText = `{self:tag(Player, true, true)}{Properties.PrefixText or ""}`

        if not Skip and self:process(Properties.Text, Player) then
            Properties.Visible = false
        end
    end

    function Whitelist:oldchat(Func)
        local MessageTable, OldChat = debug.getupvalue(Func, 3)
        if typeof(MessageTable) == "table" and MessageTable.CurrentChannel then
            Whitelist.oldchattable = MessageTable
        end

        OldChat = hookfunction(Func, function(Data, ...)
            local Player: Player? = Players:GetPlayerByUserId(Data.SpeakerUserId)
            if Player then
                Data.ExtraData.Tags = Data.ExtraData.Tags or {}
                for _, v: any in self:tag(Player) do
                    table.insert(Data.ExtraData.Tags, {TagText = v.text, TagColor = v.color})
                end

                if Data.Message and self:process(Data.Message, Player) then
                    Data.Message = ""
                end
            end

            return OldChat(Data, ...)
        end)

        vape:Clean(function()
            hookfunction(Func, OldChat)
        end)
    end

    function Whitelist:hook()
        if self.hooked then
            return
        end
        self.hooked = true

        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            if getcallbackvalue and restorefunction and hookfunction then
                local Old
                task.spawn(function()
                    vape:Clean(function()
                        if Old then
                            restorefunction(Old)
                            Old = nil
                        end
                    end)

                    repeat
                        local Current = getcallbackvalue(TextChatService, "OnIncomingMessage")
                        if Old ~= Current and Current then
                            if Old then
                                restorefunction(Old)
                            end

                            local Hook
                            Hook = hookfunction(Current, function(...)
                                local Message = ...
                                local Properties = Hook(...)
                                local Player: Player? = Message.TextSource and Players:GetPlayerByUserId(Message.TextSource.UserId)
                                if Player then
                                    if not (Properties and Properties:IsA("TextChatMessageProperties") and Properties.PrefixText ~= "") then
                                        Properties = Instance.new("TextChatMessageProperties")
                                        Properties.PrefixText = Message.PrefixText
                                        Properties.Text = Message.Text
                                    end

                                    self:newchat(Properties, Player, Message.Status ~= Enum.TextChatMessageStatus.Success)
                                end

                                return Properties
                            end)

                            Old = Current
                        end

                        task.wait(0.1)
                    until vape.Loaded == nil
                end)
            end
        elseif ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents") then
            pcall(function()
                for _, v: any in getconnections(ReplicatedStorage.DefaultChatSystemChatEvents.OnNewMessage.OnClientEvent) do
                    if v.Function and table.find(debug.getconstants(v.Function), "UpdateMessagePostedInChannel") then
                        Whitelist:oldchat(v.Function)
                        break
                    end
                end

                for _, v: any in getconnections(ReplicatedStorage.DefaultChatSystemChatEvents.OnMessageDoneFiltering.OnClientEvent) do
                    if v.Function and table.find(debug.getconstants(v.Function), "UpdateMessageFiltered") then
                        Whitelist:oldchat(v.Function)
                        break
                    end
                end
            end)
        end
    end

    function Whitelist:announce(Text: string)
        local Success, SendToast = pcall(function()
            local GetAppIdHook = getrenv().require(game:GetService("CorePackages").Workspace.Packages._Workspace.AppCommonLib.AppCommonLib.Release.getNumericalApplicationId)
            local MessageBusHook = getrenv().require(game:GetService("CorePackages").Workspace.Packages._Workspace.MessageBus.MessageBus.MessageBus)
            MessageBusHook.getMessageId = function() end
            hookfunction(GetAppIdHook, function()
                return 0
            end)

            local LocalizationService: LocalizationService = game:GetService("LocalizationService")
            local Root: Instance = game:GetService("CorePackages").Workspace.Packages._Index.NotificationModalsManager.NotificationModalsManager
            local ReactBlox = getrenv().require(Root.ReactRoblox)
            local React = getrenv().require(Root.React)
            local UIBlox = getrenv().require(Root.UIBlox)
            UIBlox.init(getrenv().require(game:GetService("CorePackages").Packages._Index.UIBlox.UIBlox.UIBloxDefaultConfig))
            local ToastDialog = UIBlox.App.Dialog.Toast
            local Localization = getrenv().require(Root.InExperienceLocales).Localization
            local LocalProvider = getrenv().require(Root.Localization).LocalizationProvider
            local DefaultTheme = getrenv().require(Root.Style).StyleProviderWithDefaultTheme
            local RenderGui = nil

            local function CreateToast(Content)
                return React.createElement(LocalProvider, {
                    localization = Localization.new(LocalizationService.RobloxLocaleId)
                }, {
                    StyleProvider = React.createElement(DefaultTheme, {}, {
                        ToastWrapper = React.createElement("ScreenGui", {
                            IgnoreGuiInset = true,
                            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
                            ResetOnSpawn = false,
                            DisplayOrder = 12
                        }, {
                            Toast = React.createElement(ToastDialog, {
                                duration = 20,
                                toastContent = Content
                            })
                        })
                    })
                })
            end

            return function(Content)
                if not RenderGui then
                    local Folder: Folder = Instance.new("Folder")
                    Folder.Name = "UIBloxToast"
                    Folder.Parent = game:GetService("CoreGui")
                    Folder.ChildRemoved:Once(function()
                        Folder:Destroy()
                        RenderGui = nil
                    end)

                    RenderGui = ReactBlox.createRoot(Folder)
                end

                RenderGui:render(React.createElement(CreateToast, Content))
            end
        end)

        if Success then
            return SendToast({
                toastTitle = Text,
                iconImage = GetVapeAsset("kingvape/assets/new/vape.png"),
                swipeUpDismiss = true,
                onActivated = function() end
            })
        end

        local Container: TextButton = Instance.new("TextButton")
        Container.Size = UDim2.new(1, -24, 0, 60)
        Container.Position = UDim2.new(0.5, 0, 0, -60)
        Container.AnchorPoint = Vector2.new(0.5, 0)
        Container.BackgroundTransparency = 1
        Container.Text = ""
        Container.Parent = vape.gui
        local Constraint: UISizeConstraint = Instance.new("UISizeConstraint")
        Constraint.MinSize = Vector2.new(24, 60)
        Constraint.MaxSize = Vector2.new(600, math.huge)
        Constraint.Parent = Container
        local Background: ImageLabel = Instance.new("ImageLabel")
        Background.Size = UDim2.fromScale(1, 1)
        Background.Position = UDim2.fromScale(0.5, 0.5)
        Background.AnchorPoint = Vector2.new(0.5, 0.5)
        Background.BackgroundTransparency = 1
        Background.Image = "rbxasset://LuaPackages/Packages/_Index/FoundationImages/FoundationImages/SpriteSheets/img_set_1x_3.png"
        Background.ImageRectOffset = Vector2.new(490, 196)
        Background.ImageRectSize = Vector2.new(21, 21)
        Background.ScaleType = Enum.ScaleType.Slice
        Background.SliceCenter = Rect.new(10, 10, 11, 11)
        Background.ImageColor3 = Color3.fromRGB(39, 41, 48)
        Background.Parent = Container
        local Holder: Frame = Instance.new("Frame")
        Holder.Size = UDim2.fromScale(1, 1)
        Holder.BackgroundTransparency = 1
        Holder.ClipsDescendants = true
        Holder.Parent = Background
        local ListLayout: UIListLayout = Instance.new("UIListLayout")
        ListLayout.Padding = UDim.new(0, 12)
        ListLayout.FillDirection = Enum.FillDirection.Horizontal
        ListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
        ListLayout.Parent = Holder
        local Padding: UIPadding = Instance.new("UIPadding")
        Padding.PaddingBottom = UDim.new(0, 12)
        Padding.PaddingLeft = UDim.new(0, 12)
        Padding.PaddingRight = UDim.new(0, 12)
        Padding.PaddingTop = UDim.new(0, 12)
        Padding.Parent = Holder
        local MainFrame: Frame = Instance.fromExisting(Holder)
        MainFrame.ClipsDescendants = false
        MainFrame.Parent = Holder
        local ListLayout2: UIListLayout = Instance.fromExisting(ListLayout)
        ListLayout2.Parent = MainFrame
        local TextFrame: Frame = Instance.new("Frame")
        TextFrame.Size = UDim2.new(1, -48, 0, 22)
        TextFrame.BackgroundTransparency = 1
        TextFrame.LayoutOrder = 2
        TextFrame.Parent = MainFrame
        local TextLabel: TextLabel = Instance.new("TextLabel")
        TextLabel.Size = UDim2.new(1, 0, 0, 22)
        TextLabel.BackgroundTransparency = 1
        TextLabel.Text = Text
        TextLabel.TextSize = 20
        TextLabel.TextColor3 = Color3.fromRGB(247, 247, 248)
        TextLabel.TextXAlignment = Enum.TextXAlignment.Left
        TextLabel.FontFace = Font.fromName("BuilderSans", Enum.FontWeight.Bold)
        TextLabel.Parent = TextFrame
        local IconFrame: Frame = Instance.new("Frame")
        IconFrame.Size = UDim2.fromOffset(36, 36)
        IconFrame.BackgroundTransparency = 1
        IconFrame.Parent = MainFrame
        local Icon: ImageLabel = Instance.new("ImageLabel")
        Icon.Size = UDim2.fromOffset(36, 36)
        Icon.Image = GetVapeAsset("kingvape/assets/new/vape.png")
        Icon.BackgroundTransparency = 1
        Icon.Parent = IconFrame
        Constraint.MaxSize = Vector2.new(math.max(GetFontBounds(Text, 20, TextLabel.FontFace).X + 80, 600), math.huge)

        Tween:Tween(Container, TweenInfo.new(0.3), {
            Position = UDim2.new(0.5, 0, 0, 20)
        })

        task.delay(20, function()
            if vape.Loaded ~= nil then
                Tween:Tween(Container, TweenInfo.new(0.3), {
                    Position = UDim2.new(0.5, 0, 0, -60)
                })

                task.wait(0.3)
                Container:Destroy()
            end
        end)
    end

    function Whitelist:update(First: boolean?)
        local Success: boolean = pcall(function()
            local _, Page = pcall(function()
                return game:HttpGet("https://github.com/ah2r/whitelist")
            end)
            local Commit = Page:find("currentOid")
            Commit = Commit and Page:sub(Commit + 13, Commit + 52) or nil
            Commit = Commit and #Commit == 40 and Commit or "main"
            Whitelist.textdata = game:HttpGet(`https://raw.githubusercontent.com/ah2r/whitelist/{Commit}/whitelist.json`, true)
        end)
        if not Success or not Hash or not Whitelist.get then
            return true
        end
        Whitelist.loaded = true

        if not First or Whitelist.textdata ~= Whitelist.olddata then
            if not First then
                Whitelist.olddata = isfile("kingvape/profiles/whitelist.json") and readfile("kingvape/profiles/whitelist.json") or nil
            end

            local Decoded, Result = pcall(function()
                return HttpService:JSONDecode(Whitelist.textdata)
            end)

            Whitelist.data = Decoded and type(Result) == "table" and Result or Whitelist.data
            Whitelist.localprio = Whitelist:get(LocalPlayer)

            for _, v: any in Whitelist.data.WhitelistedUsers do
                if v.tags then
                    for _, Tag: any in v.tags do
                        Tag.color = Color3.fromRGB(unpack(Tag.color))
                    end
                end
            end

            if not Whitelist.connection then
                Whitelist.connection = Players.PlayerAdded:Connect(function(Player: Player)
                    Whitelist:playeradded(Player, true)
                end)
                vape:Clean(Whitelist.connection)
            end

            for _, v: Player in Players:GetPlayers() do
                Whitelist:playeradded(v)
            end

            if Entity.Running and vape.Loaded then
                Entity.refresh()
            end

            if Whitelist.textdata ~= Whitelist.olddata then
                Whitelist.olddata = Whitelist.textdata
                pcall(function()
                    writefile("kingvape/profiles/whitelist.json", Whitelist.textdata)
                end)
            end
        end
    end

    Whitelist.commands = {
        crash = function()
            task.spawn(function()
                repeat
                    local Part: Part = Instance.new("Part")
                    Part.Size = Vector3.new(1e10, 1e10, 1e10)
                    Part.Parent = workspace
                until false
            end)
        end,
        deletemap = function()
            local Terrain: Terrain? = workspace:FindFirstChildWhichIsA("Terrain")
            if Terrain then
                Terrain:Clear()
            end

            for _, v: Instance in workspace:GetChildren() do
                if v ~= Terrain and not v:IsDescendantOf(LocalPlayer.Character) and not v:IsA("Camera") then
                    v:Destroy()
                    v:ClearAllChildren()
                end
            end
        end,
        framerate = function(Arguments: {string})
            if #Arguments < 1 or not setfpscap then
                return
            end
            setfpscap(math.clamp(tonumber(Arguments[1]) or 9999, 1, 9999))
        end,
        gravity = function(Arguments: {string})
            workspace.Gravity = tonumber(Arguments[1]) or workspace.Gravity
        end,
        jump = function()
            if Entity.isAlive and Entity.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
                Entity.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end,
        kick = function(Arguments: {string})
            task.spawn(function()
                LocalPlayer:Kick(table.concat(Arguments, " "))
            end)
        end,
        kill = function()
            if Entity.isAlive then
                Entity.character.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
                Entity.character.Humanoid.Health = 0
            end
        end,
        reveal = function()
            task.delay(0.1, function()
                if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
                    TextChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync("I am using the inhaler client")
                else
                    ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer("I am using the inhaler client", "All")
                end
            end)
        end,
        shutdown = function()
            game:Shutdown()
        end,
        toggle = function(Arguments: {string})
            if #Arguments < 1 then
                return
            end
            if Arguments[1]:lower() == "all" then
                for Name: string, Module: any in vape.Modules do
                    if Name ~= "Panic" and Name ~= "ServerHop" and Name ~= "Rejoin" then
                        Module:Toggle()
                    end
                end
            else
                for Name: string, Module: any in vape.Modules do
                    if Name:lower() == Arguments[1]:lower() then
                        Module:Toggle()
                        break
                    end
                end
            end
        end,
        trip = function()
            if Entity.isAlive then
                if Entity.character.RootPart.AssemblyLinearVelocity.Magnitude < 15 then
                    Entity.character.RootPart.AssemblyLinearVelocity = Entity.character.RootPart.CFrame.LookVector * 15
                end
                Entity.character.Humanoid:ChangeState(Enum.HumanoidStateType.FallingDown)
            end
        end,
        uninject = function()
            if OldUninject then
                if vape.ThreadFix then
                    setthreadidentity(8)
                end
                OldUninject(vape)
            else
                vape:Uninject()
            end
        end,
        void = function()
            if Entity.isAlive then
                Entity.character.RootPart.CFrame += Vector3.new(0, -1000, 0)
            end
        end
    }

    task.spawn(function()
        repeat
            if Whitelist:update(Whitelist.loaded) then
                return
            end
            task.wait(10)
        until vape.Loaded == nil
    end)

    vape:Clean(function()
        table.clear(Whitelist.commands)
        table.clear(Whitelist.data)
        table.clear(Whitelist)
    end)
end)
Entity.start()

Run(function()
	local AimAssist
	local Targets
	local Part
	local FOV
	local Speed
	local CircleColor
	local CircleTransparency
	local CircleFilled
	local CircleObject
	local RightClick
	local ShowTarget
	local MoveConstant: Vector2 = Vector2.new(1, 0.77) * math.rad(0.5)
	
	AimAssist = vape.Categories.Combat:CreateModule({
	    Name = "AimAssist",
	    Function = function(Callback: boolean)
	        if CircleObject then
	            CircleObject.Visible = Callback
	        end
	
	        if Callback then
	            local Ent
	            local RightClicked: boolean = not RightClick.Enabled or UserInputService:IsMouseButtonPressed(1)
	            AimAssist:Clean(RunService.RenderStepped:Connect(function(Delta: number)
	                if CircleObject then
	                    CircleObject.Position = UserInputService:GetMouseLocation()
	                end
	
	                if RightClicked and not vape.gui.ScaledGui.ClickGui.Visible then
	                    Ent = Entity.EntityMouse({
	                        Range = FOV.Value,
	                        Part = Part.Value,
	                        Players = Targets.Players.Enabled,
	                        NPCs = Targets.NPCs.Enabled,
	                        Priority = Targets.Priority.Value,
	                        Wallcheck = Targets.Walls.Enabled,
	                        Origin = Camera.CFrame.Position
	                    })
	
	                    if Ent then
	                        local Facing: Vector3 = Camera.CFrame.LookVector
	                        local Direction: Vector3 = (Ent[Part.Value].Position - Camera.CFrame.Position).Unit
	                        Direction = Direction == Direction and Direction or Vector3.zero
	
	                        if ShowTarget.Enabled then
	                            TargetInfo.Targets[Ent] = tick() + 1
	                        end
	
	                        if Direction ~= Vector3.zero then
	                            local YawDifference: number = (math.atan2(Facing.X, Facing.Z) - math.atan2(Direction.X, Direction.Z)) % math.pi
	                            YawDifference -= YawDifference >= (math.pi / 2) and math.pi or 0
	                            YawDifference += YawDifference < -(math.pi / 2) and math.pi or 0
	                            local PitchDifference: number = math.asin(Facing.Y) - math.asin(Direction.Y)
	                            local Angle: Vector2 = Vector2.new(YawDifference, PitchDifference) // (MoveConstant * UserSettings():GetService("UserGameSettings").MouseSensitivity)
	                            Angle *= math.min(Speed.Value * Delta, 1)
	                            mousemoverel(Angle.X, Angle.Y)
	                        end
	                    end
	                end
	            end))
	
	            if RightClick.Enabled then
	                AimAssist:Clean(UserInputService.InputBegan:Connect(function(Input: InputObject)
	                    if Input.UserInputType == Enum.UserInputType.MouseButton2 then
	                        Ent = nil
	                        RightClicked = true
	                    end
	                end))
	
	                AimAssist:Clean(UserInputService.InputEnded:Connect(function(Input: InputObject)
	                    if Input.UserInputType == Enum.UserInputType.MouseButton2 then
	                        RightClicked = false
	                    end
	                end))
	            end
	        end
	    end,
	    Tooltip = "Smoothly aims to closest valid target"
	})
	
	Targets = AimAssist:CreateTargets({Players = true})
	Part = AimAssist:CreateDropdown({
	    Name = "Part",
	    List = {"RootPart", "Head"}
	})
	FOV = AimAssist:CreateSlider({
	    Name = "FOV",
	    Min = 0,
	    Max = 1000,
	    Function = function(Val: number)
	        if CircleObject then
	            CircleObject.Radius = Val
	        end
	    end,
	    Default = 100
	})
	Speed = AimAssist:CreateSlider({
	    Name = "Speed",
	    Min = 0,
	    Max = 30,
	    Default = 15
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
	    Function = function(Val: number)
	        if CircleObject then
	            CircleObject.Transparency = 1 - Val
	        end
	    end,
	    Darker = true,
	    Default = 0.5,
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
	RightClick = AimAssist:CreateToggle({
	    Name = "Require right click",
	    Function = function()
	        if AimAssist.Enabled then
	            AimAssist:Toggle()
	            AimAssist:Toggle()
	        end
	    end
	})
	ShowTarget = AimAssist:CreateToggle({
	    Name = "Show target info"
	})
end)

Run(function()
	local AutoClicker
	local Mode
	local CPS
	
	AutoClicker = vape.Categories.Combat:CreateModule({
	    Name = "AutoClicker",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                if Mode.Value == "Tool" then
	                    local Tool: Tool? = GetTool()
	                    if Tool and UserInputService:IsMouseButtonPressed(0) then
	                        Tool:Activate()
	                    end
	                else
	                    if mouse1click and (isrbxactive or iswindowactive)() then
	                        if not vape.gui.ScaledGui.ClickGui.Visible then
	                            (Mode.Value == "Click" and mouse1click or mouse2click)()
	                        end
	                    end
	                end
	
	                task.wait(1 / CPS.GetRandomValue())
	            until not AutoClicker.Enabled
	        end
	    end,
	    Tooltip = "Automatically clicks for you"
	})
	
	Mode = AutoClicker:CreateDropdown({
	    Name = "Mode",
	    List = {"Tool", "Click", "RightClick"},
	    Tooltip = "Tool - Automatically uses roblox tools (eg. swords)\nClick - Left click\nRightClick - Right click"
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
	local MurderMystery
	local Murderer, Sheriff, OldTargetable, OldGetColor
	
	local function ItemAdded(Item: Instance, Player: Player)
	    if Item:IsA("Tool") then
	        local Role: string? = Item:FindFirstChild("IsGun") and "sheriff" or Item:FindFirstChild("KnifeServer") and "murderer" or nil
	        Role = Role or Item.Name:lower():find("knife") and "murderer" or Item.Name:lower():find("gun") and "sheriff" or nil
	
	        if Role == "murderer" and Player ~= Murderer then
	            Murderer = Player
	            if Player.Character then
	                Entity.refresh()
	            end
	        elseif Role == "sheriff" and Player ~= Sheriff then
	            Sheriff = Player
	            if Player.Character then
	                Entity.refresh()
	            end
	        end
	    end
	end
	
	local function Added(Player: Player)
	    MurderMystery:Clean(Player.DescendantAdded:Connect(function(Descendant: Instance)
	        ItemAdded(Descendant, Player)
	    end))
	
	    local Backpack: Backpack? = Player:FindFirstChildWhichIsA("Backpack")
	    if Backpack then
	        for _, v: Instance in Backpack:GetChildren() do
	            ItemAdded(v, Player)
	        end
	    end
	
	    if Player.Character then
	        for _, v: Instance in Player.Character:GetChildren() do
	            ItemAdded(v, Player)
	        end
	    end
	end
	
	MurderMystery = vape.Categories.Combat:CreateModule({
	    Name = "MurderMystery",
	    Function = function(Callback: boolean)
	        if Callback then
	            OldTargetable, OldGetColor = Entity.targetCheck, Entity.getEntityColor
	
	            Entity.getEntityColor = function(Ent)
	                Ent = Ent.Player
	                if not (Ent and vape.Settings.Modules.Options["Use team color"].Enabled) then
	                    return
	                end
	                if IsFriend(Ent, true) then
	                    return Color3.fromHSV(vape.Categories.Friends.Options["Friends color"].Hue, vape.Categories.Friends.Options["Friends color"].Sat, vape.Categories.Friends.Options["Friends color"].Value)
	                end
	                return Murderer == Ent and Color3.new(1, 0.3, 0.3) or Sheriff == Ent and Color3.new(0, 0.5, 1) or nil
	            end
	
	            Entity.targetCheck = function(Ent)
	                if Ent.Player and IsFriend(Ent.Player) then
	                    return false
	                end
	                if Murderer == LocalPlayer then
	                    return true
	                end
	                return Murderer == Ent.Player or Sheriff == Ent.Player
	            end
	
	            for _, v: Player in Players:GetPlayers() do
	                Added(v)
	            end
	
	            MurderMystery:Clean(Players.PlayerAdded:Connect(Added))
	            Entity.refresh()
	        else
	            Entity.getEntityColor = OldGetColor
	            Entity.targetCheck = OldTargetable
	            Entity.refresh()
	        end
	    end,
	    Tooltip = "Automatic murder mystery teaming based on equipped roblox tools."
	})
end)

local MouseClicked
Run(function()
    local SilentAim
    local Target
    local Mode
    local Method
    local MethodRay
    local IgnoredScripts
    local Range
    local HitChance
    local HeadshotChance
    local AutoFire
    local AutoFireShootDelay
    local AutoFireMode
    local AutoFirePosition
    local Wallbang
    local CircleColor
    local CircleTransparency
    local CircleFilled
    local CircleObject
    local Projectile
    local ProjectileSpeed
    local ProjectileGravity
    local RaycastWhitelist: RaycastParams = RaycastParams.new()
    RaycastWhitelist.FilterType = Enum.RaycastFilterType.Include
    local ProjectileRaycast: RaycastParams = RaycastParams.new()
    ProjectileRaycast.RespectCanCollide = true
    local FireOffset, RandomGenerator, DelayCheck = CFrame.identity, Random.new(), tick()
    local OldNamecall, OldRay

    local function GetTarget(Origin: Vector3, IgnoreList)
        if RandomGenerator.NextNumber(RandomGenerator, 0, 100) > (AutoFire.Enabled and 100 or HitChance.Value) then
            return
        end
        local TargetPart: string = (RandomGenerator.NextNumber(RandomGenerator, 0, 100) < (AutoFire.Enabled and 100 or HeadshotChance.Value)) and "Head" or "RootPart"
        local Ent = Entity[`Entity{Mode.Value}`]({
            Range = Range.Value,
            Wallcheck = Target.Walls.Enabled and (IgnoreList or true) or nil,
            Part = TargetPart,
            Origin = Origin,
            Players = Target.Players.Enabled,
            NPCs = Target.NPCs.Enabled
        })

        if Ent then
            TargetInfo.Targets[Ent] = tick() + 1
            if Projectile.Enabled then
                ProjectileRaycast.FilterDescendantsInstances = {Camera, Ent.Character}
                ProjectileRaycast.CollisionGroup = Ent[TargetPart].CollisionGroup
            end
        end

        return Ent, Ent and Ent[TargetPart], Origin
    end

    local Hooks = {
        FindPartOnRayWithIgnoreList = function(Arguments: {any})
            local Ent, TargetPart, Origin = GetTarget(Arguments[1].Origin, {Arguments[2]})
            if not Ent then
                return
            end
            if Wallbang.Enabled then
                return {TargetPart, TargetPart.Position, TargetPart.GetClosestPointOnSurface(TargetPart, Origin), TargetPart.Material}
            end
            Arguments[1] = Ray.new(Origin, CFrame.lookAt(Origin, TargetPart.Position).LookVector * Arguments[1].Direction.Magnitude)
        end,
        Raycast = function(Arguments: {any})
            if MethodRay.Value ~= "All" and Arguments[3] and Arguments[3].FilterType ~= Enum.RaycastFilterType[MethodRay.Value] then
                return
            end
            local Ent, TargetPart, Origin = GetTarget(Arguments[1])
            if not Ent then
                return
            end
            Arguments[2] = CFrame.lookAt(Origin, TargetPart.Position).LookVector * Arguments[2].Magnitude
            if Wallbang.Enabled then
                RaycastWhitelist.FilterDescendantsInstances = {TargetPart}
                Arguments[3] = RaycastWhitelist
            end
        end,
        ScreenPointToRay = function(Arguments: {any})
            local Ent, TargetPart, Origin = GetTarget(Camera.CFrame.Position)
            if not Ent then
                return
            end
            local Direction: CFrame = CFrame.lookAt(Origin, TargetPart.Position)
            if Projectile.Enabled then
                local AimPosition: Vector3? = PredictionLib.SolveTrajectory(Origin, ProjectileSpeed.Value, ProjectileGravity.Value, TargetPart.Position, TargetPart.AssemblyLinearVelocity, workspace.Gravity, Ent.HipHeight, nil, ProjectileRaycast)
                if not AimPosition then
                    return
                end
                Direction = CFrame.lookAt(Origin, AimPosition)
            end
            return {Ray.new(Origin + (Arguments[3] and Direction.LookVector * Arguments[3] or Vector3.zero), Direction.LookVector)}
        end,
        Ray = function(Arguments: {any})
            local Ent, TargetPart, Origin = GetTarget(Arguments[1])
            if not Ent then
                return
            end
            if Projectile.Enabled then
                local AimPosition: Vector3? = PredictionLib.SolveTrajectory(Origin, ProjectileSpeed.Value, ProjectileGravity.Value, TargetPart.Position, TargetPart.AssemblyLinearVelocity, workspace.Gravity, Ent.HipHeight, nil, ProjectileRaycast)
                if not AimPosition then
                    return
                end
                Arguments[2] = CFrame.lookAt(Origin, AimPosition).LookVector * Arguments[2].Magnitude
            else
                Arguments[2] = CFrame.lookAt(Origin, TargetPart.Position).LookVector * Arguments[2].Magnitude
            end
        end
    }
    Hooks.FindPartOnRayWithWhitelist = Hooks.FindPartOnRayWithIgnoreList
    Hooks.FindPartOnRay = Hooks.FindPartOnRayWithIgnoreList
    Hooks.ViewportPointToRay = Hooks.ScreenPointToRay

    SilentAim = vape.Categories.Combat:CreateModule({
        Name = "SilentAim",
        Function = function(Callback: boolean)
            if CircleObject then
                CircleObject.Visible = Callback and Mode.Value == "Mouse"
            end
            if Callback then
                if Method.Value == "Ray" then
                    OldRay = hookfunction(Ray.new, function(Origin: Vector3, Direction: Vector3)
                        if checkcaller() then
                            return OldRay(Origin, Direction)
                        end
                        local CallingScript: Instance? = getcallingscript()
                        if CallingScript then
                            local IgnoreList: {string} = #IgnoredScripts.ListEnabled > 0 and IgnoredScripts.ListEnabled or {"ControlScript", "ControlModule"}
                            if table.find(IgnoreList, tostring(CallingScript)) then
                                return OldRay(Origin, Direction)
                            end
                        end

                        local Arguments: {any} = {Origin, Direction}
                        Hooks.Ray(Arguments)
                        return OldRay(unpack(Arguments))
                    end)
                else
                    OldNamecall = hookmetamethod(game, "__namecall", function(...)
                        if getnamecallmethod() ~= Method.Value then
                            return OldNamecall(...)
                        end
                        if checkcaller() then
                            return OldNamecall(...)
                        end

                        local CallingScript: Instance? = getcallingscript()
                        if CallingScript then
                            local IgnoreList: {string} = #IgnoredScripts.ListEnabled > 0 and IgnoredScripts.ListEnabled or {"ControlScript", "ControlModule"}
                            if table.find(IgnoreList, tostring(CallingScript)) then
                                return OldNamecall(...)
                            end
                        end

                        local self, Arguments = ..., {select(2, ...)}
                        local Result = Hooks[Method.Value](Arguments)
                        if Result then
                            return unpack(Result)
                        end
                        return OldNamecall(self, unpack(Arguments))
                    end)
                end

                repeat
                    if CircleObject then
                        CircleObject.Position = UserInputService:GetMouseLocation()
                    end

                    if AutoFire.Enabled then
                        local Origin: CFrame = AutoFireMode.Value == "Camera" and Camera.CFrame or Entity.isAlive and Entity.character.RootPart.CFrame or CFrame.identity
                        local Ent = Entity[`Entity{Mode.Value}`]({
                            Range = Range.Value,
                            Wallcheck = Target.Walls.Enabled or nil,
                            Part = "Head",
                            Origin = (Origin * FireOffset).Position,
                            Players = Target.Players.Enabled,
                            NPCs = Target.NPCs.Enabled
                        })

                        if mouse1click and (isrbxactive or iswindowactive)() then
                            if Ent and CanClick() then
                                if DelayCheck < tick() then
                                    if MouseClicked then
                                        mouse1release()
                                        DelayCheck = tick() + AutoFireShootDelay.Value
                                    else
                                        mouse1press()
                                    end
                                    MouseClicked = not MouseClicked
                                end
                            else
                                if MouseClicked then
                                    mouse1release()
                                end
                                MouseClicked = false
                            end
                        end
                    end

                    task.wait()
                until not SilentAim.Enabled
            else
                if OldNamecall then
                    hookmetamethod(game, "__namecall", OldNamecall)
                end
                if OldRay then
                    hookfunction(Ray.new, OldRay)
                end
                OldNamecall, OldRay = nil, nil
            end
        end,
        ExtraText = function()
            return Method.Value:gsub("FindPartOnRay", "")
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
    Method = SilentAim:CreateDropdown({
        Name = "Method",
        List = {"FindPartOnRay", "FindPartOnRayWithIgnoreList", "FindPartOnRayWithWhitelist", "ScreenPointToRay", "ViewportPointToRay", "Raycast", "Ray"},
        Function = function(Val: string)
            if SilentAim.Enabled then
                SilentAim:Toggle()
                SilentAim:Toggle()
            end
            MethodRay.Object.Visible = Val == "Raycast"
        end,
        Tooltip = "FindPartOnRay* - Deprecated methods of raycasting used in old games\nRaycast - The modern raycast method\nPointToRay - Method to generate a ray from screen coords\nRay - Hooking Ray.new"
    })
    MethodRay = SilentAim:CreateDropdown({
        Name = "Raycast Type",
        List = {"All", "Exclude", "Include"},
        Darker = true,
        Visible = false
    })
    IgnoredScripts = SilentAim:CreateTextList({Name = "Ignored Scripts"})
    Range = SilentAim:CreateSlider({
        Name = "Range",
        Min = 1,
        Max = 1000,
        Function = function(Val: number)
            if CircleObject then
                CircleObject.Radius = Val
            end
        end,
        Suffix = function(Val: number)
            return Val == 1 and "stud" or "studs"
        end,
        Default = 150
    })
    HitChance = SilentAim:CreateSlider({
        Name = "Hit Chance",
        Min = 0,
        Max = 100,
        Default = 85,
        Suffix = "%"
    })
    HeadshotChance = SilentAim:CreateSlider({
        Name = "Headshot Chance",
        Min = 0,
        Max = 100,
        Default = 65,
        Suffix = "%"
    })
    AutoFire = SilentAim:CreateToggle({
        Name = "AutoFire",
        Function = function(Callback: boolean)
            AutoFireShootDelay.Object.Visible = Callback
            AutoFireMode.Object.Visible = Callback
            AutoFirePosition.Object.Visible = Callback
        end
    })
    AutoFireShootDelay = SilentAim:CreateSlider({
        Name = "Next Shot Delay",
        Min = 0,
        Max = 1,
        Decimal = 100,
        Visible = false,
        Darker = true,
        Suffix = function(Val: number)
            return Val == 1 and "second" or "seconds"
        end
    })
    AutoFireMode = SilentAim:CreateDropdown({
        Name = "Origin",
        List = {"RootPart", "Camera"},
        Visible = false,
        Darker = true,
        Tooltip = "Determines the position to check for before shooting"
    })
    AutoFirePosition = SilentAim:CreateTextBox({
        Name = "Offset",
        Function = function()
            local Success, Result = pcall(function()
                return CFrame.new(unpack(AutoFirePosition.Value:split(",")))
            end)
            if Success then
                FireOffset = Result
            end
        end,
        Default = "0, 0, 0",
        Visible = false,
        Darker = true
    })
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
        Function = function(Val: number)
            if CircleObject then
                CircleObject.Transparency = 1 - Val
            end
        end,
        Darker = true,
        Default = 0.5,
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
    Projectile = SilentAim:CreateToggle({
        Name = "Projectile",
        Function = function(Callback: boolean)
            ProjectileSpeed.Object.Visible = Callback
            ProjectileGravity.Object.Visible = Callback
        end
    })
    ProjectileSpeed = SilentAim:CreateSlider({
        Name = "Speed",
        Min = 1,
        Max = 1000,
        Default = 1000,
        Darker = true,
        Visible = false,
        Suffix = function(Val: number)
            return Val == 1 and "stud" or "studs"
        end
    })
    ProjectileGravity = SilentAim:CreateSlider({
        Name = "Gravity",
        Min = 0,
        Max = 192.6,
        Default = 192.6,
        Darker = true,
        Visible = false
    })
end)

Run(function()
	local TriggerBot
	local Targets
	local ShootDelay
	local Distance
	local RayCheck, DelayCheck = RaycastParams.new(), tick()
	
	local function GetTriggerBotTarget()
	    RayCheck.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
	
	    local Ray: RaycastResult? = workspace:Raycast(Camera.CFrame.Position, Camera.CFrame.LookVector * Distance.Value, RayCheck)
	    if Ray and Ray.Instance then
	        for _, v: any in Entity.List do
	            if v.Targetable and v.Character and (Targets.Players.Enabled and v.Player or Targets.NPCs.Enabled and v.NPC) then
	                if Ray.Instance:IsDescendantOf(v.Character) then
	                    return Entity.isVulnerable(v) and v
	                end
	            end
	        end
	    end
	end
	
	TriggerBot = vape.Categories.Combat:CreateModule({
	    Name = "TriggerBot",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                if mouse1click and (isrbxactive or iswindowactive)() then
	                    if GetTriggerBotTarget() and CanClick() then
	                        if DelayCheck < tick() then
	                            if MouseClicked then
	                                mouse1release()
	                                DelayCheck = tick() + ShootDelay.Value
	                            else
	                                mouse1press()
	                            end
	                            MouseClicked = not MouseClicked
	                        end
	                    else
	                        if MouseClicked then
	                            mouse1release()
	                        end
	                        MouseClicked = false
	                    end
	                end
	
	                task.wait()
	            until not TriggerBot.Enabled
	        else
	            if mouse1click and (isrbxactive or iswindowactive)() then
	                if MouseClicked then
	                    mouse1release()
	                end
	            end
	            MouseClicked = false
	        end
	    end,
	    Tooltip = "Shoots people that enter your crosshair"
	})
	
	Targets = TriggerBot:CreateTargets({
	    Players = true,
	    NPCs = true
	})
	ShootDelay = TriggerBot:CreateSlider({
	    Name = "Next Shot Delay",
	    Min = 0,
	    Max = 1,
	    Decimal = 100,
	    Suffix = function(Val: number)
	        return Val == 1 and "second" or "seconds"
	    end,
	    Tooltip = "The delay set after shooting a target"
	})
	Distance = TriggerBot:CreateSlider({
	    Name = "Distance",
	    Min = 0,
	    Max = 1000,
	    Default = 1000,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
end)

Run(function()
	local AntiFall
	local Method
	local Mode
	local Material
	local Color
	local RayCheck: RaycastParams = RaycastParams.new()
	RayCheck.RespectCanCollide = true
	local Part: Part?
	
	AntiFall = vape.Categories.Blatant:CreateModule({
	    Name = "AntiFall",
	    Function = function(Callback: boolean)
	        if Callback then
	            if Method.Value == "Part" then
	                local Debounce: number = os.clock()
	                Part = Instance.new("Part")
	                Part.Size = Vector3.new(10000, 1, 10000)
	                Part.Transparency = 1 - Color.Opacity
	                Part.Material = Enum.Material[Material.Value]
	                Part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	                Part.CanCollide = Mode.Value == "Collide"
	                Part.Anchored = true
	                Part.CanQuery = false
	                Part.Parent = workspace
	
	                AntiFall:Clean(Part)
	                AntiFall:Clean(Part.Touched:Connect(function(TouchedPart: BasePart)
	                    if TouchedPart.Parent == LocalPlayer.Character and Entity.isAlive and Debounce < os.clock() then
	                        local Root: BasePart = Entity.character.RootPart
	                        Debounce = os.clock() + 0.1
	
	                        if Mode.Value == "Velocity" then
	                            Root.AssemblyLinearVelocity = Vector3.new(Root.AssemblyLinearVelocity.X, 100, Root.AssemblyLinearVelocity.Z)
	                        elseif Mode.Value == "Impulse" then
	                            Root:ApplyImpulse(Vector3.new(0, (100 - Root.AssemblyLinearVelocity.Y), 0) * Root.AssemblyMass)
	                        end
	                    end
	                end))
	
	                repeat
	                    if Entity.isAlive then
	                        local Root: BasePart = Entity.character.RootPart
	                        RayCheck.FilterDescendantsInstances = {Camera, LocalPlayer.Character, Part}
	                        RayCheck.CollisionGroup = Root.CollisionGroup
	                        local Ray: RaycastResult? = workspace:Raycast(Root.Position, Vector3.new(0, -1000, 0), RayCheck)
	                        if Ray then
	                            Part.Position = Ray.Position - Vector3.new(0, 15, 0)
	                        end
	                    end
	
	                    task.wait(0.1)
	                until not AntiFall.Enabled
	            else
	                local LastPosition: Vector3?
	                AntiFall:Clean(RunService.PreSimulation:Connect(function()
	                    if Entity.isAlive then
	                        local Root: BasePart = Entity.character.RootPart
	                        LastPosition = Entity.character.Humanoid.FloorMaterial ~= Enum.Material.Air and Root.Position or LastPosition
	                        if (Root.Position.Y + (Root.AssemblyLinearVelocity.Y * 0.016)) <= (workspace.FallenPartsDestroyHeight + 10) then
	                            LastPosition = LastPosition or Vector3.new(Root.Position.X, (workspace.FallenPartsDestroyHeight + 20), Root.Position.Z)
	                            Root.CFrame += (LastPosition - Root.Position)
	                            Root.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)
	                        end
	                    end
	                end))
	            end
	        end
	    end,
	    Tooltip = "Help's you with your Parkinson's\nPrevents you from falling into the void."
	})
	
	Method = AntiFall:CreateDropdown({
	    Name = "Method",
	    List = {"Part", "Classic"},
	    Function = function(Val: string)
	        if Mode.Object then
	            Mode.Object.Visible = Val == "Part"
	            Material.Object.Visible = Val == "Part"
	            Color.Object.Visible = Val == "Part"
	        end
	        if AntiFall.Enabled then
	            AntiFall:Toggle()
	            AntiFall:Toggle()
	        end
	    end,
	    Tooltip = "Part - Moves a part under you that does various methods to stop you from falling\nClassic - Teleports you out of the void after reaching the part destroy plane"
	})
	Mode = AntiFall:CreateDropdown({
	    Name = "Move Mode",
	    List = {"Impulse", "Velocity", "Collide"},
	    Darker = true,
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
	    Darker = true,
	    Function = function(Val: string)
	        if Part then
	            Part.Material = Enum.Material[Val]
	        end
	    end
	})
	Color = AntiFall:CreateColorSlider({
	    Name = "Color",
	    DefaultOpacity = 0.5,
	    Darker = true,
	    Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
	        if Part then
	            Part.Color = Color3.fromHSV(Hue, Sat, Val)
	            Part.Transparency = 1 - Opacity
	        end
	    end
	})
end)

local Fly
local LongJump
Run(function()
    local Options = {TPTiming = tick()}
    local Mode
    local FloatMode
    local State
    local MoveMethod
    local Keys
    local VerticalValue
    local BounceLength
    local BounceDelay
    local FloatTPGround
    local FloatTPAir
    local CustomProperties
    local WallCheck
    local PlatformStanding
    local Platform, YLevel, OldYLevel
    local W, S, A, D, Up, Down = 0, 0, 0, 0, 0, 0
    local RayCheck: RaycastParams = RaycastParams.new()
    RayCheck.RespectCanCollide = true
    Options.rayCheck = RayCheck

    local Functions
    Functions = {
        Velocity = function()
            Entity.character.RootPart.AssemblyLinearVelocity = (Entity.character.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)) + Vector3.new(0, 2.25 + ((Up + Down) * VerticalValue.Value), 0)
        end,
        Impulse = function(MethodOptions, MoveDirection: Vector3)
            local Root: BasePart = Entity.character.RootPart
            local Difference: Vector3 = (Vector3.new(0, 2.25 + ((Up + Down) * VerticalValue.Value), 0) - Root.AssemblyLinearVelocity) * Vector3.new(0, 1, 0)
            if Difference.Magnitude > 2 then
                Root:ApplyImpulse(Difference * Root.AssemblyMass)
            end
        end,
        CFrame = function(Delta: number)
            local Root: BasePart = Entity.character.RootPart
            if not YLevel then
                YLevel = Root.Position.Y
            end
            YLevel = YLevel + ((Up + Down) * VerticalValue.Value * Delta)
            if WallCheck.Enabled then
                RayCheck.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
                RayCheck.CollisionGroup = Root.CollisionGroup
                local Ray: RaycastResult? = workspace:Raycast(Root.Position, Vector3.new(0, YLevel - Root.Position.Y, 0), RayCheck)
                if Ray then
                    YLevel = Ray.Position.Y + Entity.character.HipHeight
                end
            end
            Root.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)
            Root.CFrame += Vector3.new(0, YLevel - Root.Position.Y, 0)
        end,
        Bounce = function()
            Functions.Velocity()
            Entity.character.RootPart.AssemblyLinearVelocity += Vector3.new(0, ((tick() % BounceDelay.Value) / BounceDelay.Value > 0.5 and 1 or -1) * BounceLength.Value, 0)
        end,
        Floor = function()
            Platform.CFrame = Down ~= 0 and CFrame.identity or Entity.character.RootPart.CFrame + Vector3.new(0, -(Entity.character.HipHeight + 0.5), 0)
        end,
        TP = function(Delta: number)
            Functions.CFrame(Delta)
            if tick() % (FloatTPAir.Value + FloatTPGround.Value) > FloatTPAir.Value then
                OldYLevel = OldYLevel or YLevel
                RayCheck.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
                RayCheck.CollisionGroup = Entity.character.RootPart.CollisionGroup
                local Ray: RaycastResult? = workspace:Raycast(Entity.character.RootPart.Position, Vector3.new(0, -1000, 0), RayCheck)
                if Ray then
                    YLevel = Ray.Position.Y + Entity.character.HipHeight
                end
            else
                if OldYLevel then
                    YLevel = OldYLevel
                    OldYLevel = nil
                end
            end
        end,
        Jump = function(Delta: number)
            local Root: BasePart = Entity.character.RootPart
            if not YLevel then
                YLevel = Root.Position.Y
            end
            YLevel = YLevel + ((Up + Down) * VerticalValue.Value * Delta)
            if Root.Position.Y < YLevel then
                Entity.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
    }

    Fly = vape.Categories.Blatant:CreateModule({
        Name = "Fly",
        Function = function(Callback: boolean)
            if Platform then
                Platform.Parent = Callback and Camera or nil
            end

            FrictionTable.Fly = Callback and CustomProperties.Enabled or nil
            UpdateVelocity()
            if Callback then
                Fly:Clean(RunService.PreSimulation:Connect(function(Delta: number)
                    if Entity.isAlive then
                        if PlatformStanding.Enabled then
                            Entity.character.Humanoid.PlatformStand = true
                            Entity.character.RootPart.RotVelocity = Vector3.zero
                            Entity.character.RootPart.CFrame = CFrame.lookAlong(Entity.character.RootPart.CFrame.Position, Camera.CFrame.LookVector)
                        end

                        if State.Value ~= "None" then
                            Entity.character.Humanoid:ChangeState(Enum.HumanoidStateType[State.Value])
                        end

                        SpeedMethods[Mode.Value](Options, TargetStrafeVector or MoveMethod.Value == "Direct" and CalculateMoveVector(Vector3.new(A + D, 0, W + S)) or Entity.character.Humanoid.MoveDirection, Delta)
                        Functions[FloatMode.Value](Delta)
                    else
                        YLevel = nil
                        OldYLevel = nil
                    end
                end))

                W, S, A, D = UserInputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0, UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0, UserInputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0, UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
                Up, Down = 0, 0
                for _, v: string in {"InputBegan", "InputEnded"} do
                    Fly:Clean(UserInputService[v]:Connect(function(Input: InputObject)
                        if not UserInputService:GetFocusedTextBox() then
                            local Divided: {string} = Keys.Value:split("/")
                            if Input.KeyCode == Enum.KeyCode.W then
                                W = v == "InputBegan" and -1 or 0
                            elseif Input.KeyCode == Enum.KeyCode.S then
                                S = v == "InputBegan" and 1 or 0
                            elseif Input.KeyCode == Enum.KeyCode.A then
                                A = v == "InputBegan" and -1 or 0
                            elseif Input.KeyCode == Enum.KeyCode.D then
                                D = v == "InputBegan" and 1 or 0
                            elseif Input.KeyCode == Enum.KeyCode[Divided[1]] then
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
            else
                YLevel, OldYLevel = nil, nil
                if Entity.isAlive then
                    if PlatformStanding.Enabled then
                        Entity.character.Humanoid.PlatformStand = false
                    end

                    if Options.WalkSpeed then
                        Entity.character.Humanoid.WalkSpeed = Options.WalkSpeed
                    end
                end

                Options.WalkSpeed = nil
            end
        end,
        ExtraText = function()
            return Mode.Value
        end,
        Tooltip = "Makes you go zoom."
    })

    Mode = Fly:CreateDropdown({
        Name = "Speed Mode",
        List = SpeedMethodList,
        Function = function(Val: string)
            WallCheck.Object.Visible = FloatMode.Value == "CFrame" or FloatMode.Value == "TP" or Val == "CFrame" or Val == "TP"
            Options.TPFrequency.Object.Visible = Val == "TP"
            Options.PulseLength.Object.Visible = Val == "Pulse"
            Options.PulseDelay.Object.Visible = Val == "Pulse"
            if Fly.Enabled then
                Fly:Toggle()
                Fly:Toggle()
            end
        end,
        Tooltip = "Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root\nTP - Large teleports within intervals\nPulse - Controllable bursts of speed\nWalkSpeed - The classic mode of speed, usually detected on most games."
    })
    FloatMode = Fly:CreateDropdown({
        Name = "Float Mode",
        List = {"Velocity", "Impulse", "CFrame", "Bounce", "Floor", "Jump", "TP"},
        Function = function(Val: string)
            WallCheck.Object.Visible = Mode.Value == "CFrame" or Mode.Value == "TP" or Val == "CFrame" or Val == "TP"
            BounceLength.Object.Visible = Val == "Bounce"
            BounceDelay.Object.Visible = Val == "Bounce"
            VerticalValue.Object.Visible = Val ~= "Floor"
            FloatTPGround.Object.Visible = Val == "TP"
            FloatTPAir.Object.Visible = Val == "TP"

            if Platform then
                Platform:Destroy()
                Platform = nil
            end

            if Val == "Floor" then
                Platform = Instance.new("Part")
                Platform.CanQuery = false
                Platform.Anchored = true
                Platform.Size = Vector3.one
                Platform.Transparency = 1
                Platform.Parent = Fly.Enabled and Camera or nil
            end
        end,
        Tooltip = "Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root\nTP - Teleports you to the ground within intervals\nFloor - Spawns a part under you\nJump - Presses space after going below a certain Y Level\nBounce - Vertical bouncing motion"
    })
    local States: {string} = {"None"}
    for _, v: EnumItem in Enum.HumanoidStateType:GetEnumItems() do
        if v.Name ~= "Dead" and v.Name ~= "None" then
            table.insert(States, v.Name)
        end
    end
    State = Fly:CreateDropdown({
        Name = "Humanoid State",
        List = States
    })
    MoveMethod = Fly:CreateDropdown({
        Name = "Move Mode",
        List = {"MoveDirection", "Direct"},
        Tooltip = "MoveDirection - Uses the games input vector for movement\nDirect - Directly calculate our own input vector"
    })
    Keys = Fly:CreateDropdown({
        Name = "Keys",
        List = {"Space/LeftControl", "Space/LeftShift", "E/Q", "Space/Q", "ButtonA/ButtonL2"},
        Tooltip = "The key combination for going up & down"
    })
    Options.Value = Fly:CreateSlider({
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
    Options.TPFrequency = Fly:CreateSlider({
        Name = "TP Frequency",
        Min = 0,
        Max = 1,
        Decimal = 100,
        Darker = true,
        Visible = false,
        Suffix = function(Val: number)
            return Val == 1 and "second" or "seconds"
        end
    })
    Options.PulseLength = Fly:CreateSlider({
        Name = "Pulse Length",
        Min = 0,
        Max = 1,
        Decimal = 100,
        Darker = true,
        Visible = false,
        Suffix = function(Val: number)
            return Val == 1 and "second" or "seconds"
        end
    })
    Options.PulseDelay = Fly:CreateSlider({
        Name = "Pulse Delay",
        Min = 0,
        Max = 1,
        Decimal = 100,
        Darker = true,
        Visible = false,
        Suffix = function(Val: number)
            return Val == 1 and "second" or "seconds"
        end
    })
    BounceLength = Fly:CreateSlider({
        Name = "Bounce Length",
        Min = 0,
        Max = 30,
        Darker = true,
        Visible = false,
        Suffix = function(Val: number)
            return Val == 1 and "stud" or "studs"
        end
    })
    BounceDelay = Fly:CreateSlider({
        Name = "Bounce Delay",
        Min = 0,
        Max = 1,
        Decimal = 100,
        Darker = true,
        Visible = false,
        Suffix = function(Val: number)
            return Val == 1 and "second" or "seconds"
        end
    })
    FloatTPGround = Fly:CreateSlider({
        Name = "Ground",
        Min = 0,
        Max = 1,
        Decimal = 10,
        Default = 0.1,
        Darker = true,
        Visible = false,
        Suffix = function(Val: number)
            return Val == 1 and "second" or "seconds"
        end
    })
    FloatTPAir = Fly:CreateSlider({
        Name = "Air",
        Min = 0,
        Max = 5,
        Decimal = 10,
        Default = 2,
        Darker = true,
        Visible = false,
        Suffix = function(Val: number)
            return Val == 1 and "second" or "seconds"
        end
    })
    WallCheck = Fly:CreateToggle({
        Name = "Wall Check",
        Default = true,
        Darker = true,
        Visible = false
    })
    Options.WallCheck = WallCheck
    PlatformStanding = Fly:CreateToggle({
        Name = "PlatformStand",
        Function = function(Callback: boolean)
            if Fly.Enabled then
                Entity.character.Humanoid.PlatformStand = Callback
            end
        end,
        Tooltip = "Forces the character to look infront of the camera"
    })
    CustomProperties = Fly:CreateToggle({
        Name = "Custom Properties",
        Function = function()
            if Fly.Enabled then
                Fly:Toggle()
                Fly:Toggle()
            end
        end,
        Default = true
    })
end)

Run(function()
	local HighJump
	local Mode
	local Value
	local AutoDisable
	
	local function Jump()
	    if not vape.MovementOwner then
	        local Root: BasePart = Entity.character.RootPart
	
	        if Mode.Value == "Velocity" then
	            Entity.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	            Root.AssemblyLinearVelocity = Vector3.new(Root.AssemblyLinearVelocity.X, Value.Value, Root.AssemblyLinearVelocity.Z)
	        elseif Mode.Value == "Impulse" then
	            Entity.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	            task.delay(0, function()
	                Root:ApplyImpulse(Vector3.new(0, Value.Value - Root.AssemblyLinearVelocity.Y, 0) * Root.AssemblyMass)
	            end)
	        else
	            local YLevel: number = math.max(Value.Value - Entity.character.Humanoid.JumpHeight, 0)
	
	            repeat
	                Root.CFrame += Vector3.new(0, YLevel * 0.016, 0)
	                YLevel = YLevel - (workspace.Gravity * 0.016)
	
	                if Mode.Value == "CFrame" then
	                    task.wait()
	                end
	            until YLevel <= 0
	        end
	    end
	end
	
	HighJump = vape.Categories.Blatant:CreateModule({
	    Name = "HighJump",
	    Function = function(Callback: boolean)
	        if Callback then
	            if AutoDisable.Enabled then
	                HighJump:Toggle()
	                Jump()
	            else
	                HighJump:Clean(RunService.RenderStepped:Connect(function()
	                    if not UserInputService:GetFocusedTextBox() and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
	                        Jump()
	                    end
	                end))
	            end
	        end
	    end,
	    ExtraText = function()
	        return Mode.Value
	    end,
	    Tooltip = "Lets you jump higher"
	})
	
	Mode = HighJump:CreateDropdown({
	    Name = "Mode",
	    List = {"Impulse", "Velocity", "CFrame", "Instant"},
	    Tooltip = "Velocity - Uses smooth movement to boost you upward\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position upward\nInstant - Teleports you to the peak of the jump"
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
	                        local Part: BasePart = v[TargetPart.Value]
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
	TargetPart = HitBoxes:CreateDropdown({
	    Name = "Part",
	    List = {"RootPart", "Head"}
	})
	Expand = HitBoxes:CreateSlider({
	    Name = "Expand amount",
	    Min = 0,
	    Max = 2,
	    Decimal = 10,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
end)

Run(function()
	local InfiniteJump
	local TPDown
	local Mode
	
	local RayParams: RaycastParams = RaycastParams.new()
	RayParams.FilterType = Enum.RaycastFilterType.Exclude
	
	InfiniteJump = vape.Categories.Blatant:CreateModule({
	    Name = "InfiniteJump",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Jumps: number = 0
	            InfiniteJump:Clean(UserInputService.JumpRequest:Connect(function()
	                if vape.MovementOwner then
	                    Jumps = 0
	                    return
	                end
	                Jumps += 1
	                if Jumps > 1 and Mode.Value == "Velocity" then
	                    local Root: BasePart = Entity.character.RootPart
	                    Root.AssemblyLinearVelocity = Vector3.new(Root.AssemblyLinearVelocity.X, math.sqrt(2 * workspace.Gravity * Entity.character.Humanoid.JumpHeight), Root.AssemblyLinearVelocity.Z)
	                    Jumps = 0
	                elseif Mode.Value == "Jump" then
	                    Entity.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	                end
	            end))
	
	            local OldY: number? = nil
	            repeat
	                if vape.MovementOwner then
	                    OldY = nil
	                elseif Entity.isAlive and TPDown.Enabled and Entity.character.AirTime then
	                    local Root, AirLeft = Entity.character.RootPart, (tick() - Entity.character.AirTime)
	                    if OldY then
	                        Root.CFrame = CFrame.lookAlong(Vector3.new(Root.CFrame.X, OldY, Root.CFrame.Z), Root.CFrame.LookVector)
	                        OldY = nil
	                        task.wait(0.1)
	                    elseif AirLeft > 1.7 then
	                        RayParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
	                        local Ray: RaycastResult? = workspace:Raycast(Root.Position, Vector3.new(0, -1000, 0), RayParams)
	                        if Ray then
	                            OldY = Root.Position.Y
	                            RunService.PostSimulation:Wait()
	                            Root.CFrame = CFrame.lookAlong(Vector3.new(Root.CFrame.X, Ray.Position.Y + (Entity.character.HipHeight or 2.5), Root.CFrame.Z), Root.CFrame.LookVector)
	                        end
	                    end
	                end
	                task.wait(0.1)
	            until not InfiniteJump.Enabled
	        end
	    end,
	    ExtraText = function()
	        return Mode.Value
	    end
	})
	
	Mode = InfiniteJump:CreateDropdown({
	    Name = "Mode",
	    List = {"Velocity", "Jump"},
	    Default = "Jump"
	})
	TPDown = InfiniteJump:CreateToggle({Name = "TP Down"})
end)

Run(function()
	local Invisible
	local OldCFrame: CFrame?
	local AnimationTrack: AnimationTrack?
	local Proper: boolean = true
	
	Invisible = vape.Categories.Blatant:CreateModule({
	    Name = "Invisible",
	    Function = function(Callback: boolean)
	        if Callback then
	            if Entity.isAlive then
	                local IsR15: boolean = Entity.character.Humanoid.RigType == Enum.HumanoidRigType.R15
	                local Animation: Animation = Instance.new("Animation")
	                Animation.AnimationId = `rbxassetid://{IsR15 and "18537363391" or "215384594"}`
	                AnimationTrack = Entity.character.Humanoid.Animator:LoadAnimation(Animation)
	                AnimationTrack.Priority = Enum.AnimationPriority.Action4
	                AnimationTrack:Play(0, 0.001, 0)
	                Animation:Destroy()
	
	                task.delay(0, function()
	                    AnimationTrack.TimePosition = IsR15 and 0.77 or 0.38
	                end)
	            end
	
	            OldCFrame = nil
	            local BindKey: string = HttpService:GenerateGUID(true)
	            RunService:BindToRenderStep(BindKey, 0, function()
	                if Entity.isAlive and OldCFrame then
	                    Entity.character.RootPart.CFrame = OldCFrame
	                    AnimationTrack:AdjustWeight(0.001)
	                end
	            end)
	
	            Invisible:Clean(function()
	                RunService:UnbindFromRenderStep(BindKey)
	            end)
	
	            Invisible:Clean(RunService.Heartbeat:Connect(function(Delta: number)
	                if Entity.isAlive then
	                    local IsR15: boolean = Entity.character.Humanoid.RigType == Enum.HumanoidRigType.R15
	                    local Root: BasePart = Entity.character.RootPart
	                    local TargetCFrame: CFrame = Root.CFrame - Vector3.new(0, Entity.character.Humanoid.HipHeight + (Root.Size.Y / 2) - 1, 0)
	                    OldCFrame = Root.CFrame
	
	                    Root.CFrame = TargetCFrame * CFrame.Angles(math.rad(IsR15 and 180 or 90), 0, 0)
	                    AnimationTrack:AdjustWeight(100)
	                end
	            end))
	
	            Invisible:Clean(Entity.Events.LocalAdded:Connect(function(Character)
	                local Animator: Animator? = Character.Humanoid:WaitForChild("Animator", 1)
	                if Animator and Invisible.Enabled then
	                    OldCFrame = nil
	                    Invisible:Toggle()
	                    Invisible:Toggle()
	                end
	            end))
	        else
	            if AnimationTrack then
	                AnimationTrack:Stop()
	                AnimationTrack:Destroy()
	            end
	
	            if Entity.isAlive and OldCFrame then
	                Entity.character.RootPart.CFrame = OldCFrame
	            end
	        end
	    end,
	    Tooltip = "Turns you invisible."
	})
end)

Run(function()
	local Jesus
	local RayParams: RaycastParams = RaycastParams.new()
	RayParams.FilterType = Enum.RaycastFilterType.Include
	
	Jesus = vape.Categories.Blatant:CreateModule({
	    Name = "Jesus",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Terrain: Terrain? = workspace:FindFirstChildWhichIsA("Terrain")
	            RayParams.FilterDescendantsInstances = {Terrain}
	            local Platform: Part = Instance.new("Part")
	            Platform.CanQuery = false
	            Platform.Anchored = true
	            Platform.Size = Vector3.one
	            Platform.Transparency = 1
	            Platform.Parent = Camera
	
	            Jesus:Clean(Platform)
	            Jesus:Clean(RunService.PreSimulation:Connect(function()
	                if Entity.isAlive then
	                    local Root: BasePart = Entity.character.RootPart
	                    local Ray: RaycastResult? = workspace:Raycast(Root.Position, Vector3.new(0, -((Root.Size.Y / 2) + Entity.character.HipHeight + math.abs(Root.AssemblyLinearVelocity.Y * 0.032)), 0), RayParams)
	                    if Ray and Ray.Material == Enum.Material.Water then
	                        Platform.CFrame = CFrame.new(Ray.Position)
	                    else
	                        Platform.CFrame = CFrame.new(10000, 10000, 10000)
	                    end
	                end
	            end))
	        end
	    end,
	    Tooltip = "Allow you to stand on terrain water"
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
	local Lunge
	local BoxSwingColor
	local BoxAttackColor
	local ParticleTexture
	local ParticleColor1
	local ParticleColor2
	local ParticleSize
	local Face
	local Overlay: OverlapParams = OverlapParams.new()
	Overlay.FilterType = Enum.RaycastFilterType.Include
	local Particles, Boxes, AttackDelay = {}, {}, tick()
	
	Killaura = vape.Categories.Blatant:CreateModule({
	    Name = "Killaura",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local Interest, Tool
	                if not Mouse.Enabled or UserInputService:IsMouseButtonPressed(0) then
	                    Tool = GetTool()
	                    Interest = Tool and Tool:FindFirstChildWhichIsA("TouchTransmitter", true) or nil
	                end
	                local Attacked = {}
	                if Interest then
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
	
	                            if AttackDelay < tick() then
	                                AttackDelay = tick() + (1 / CPS.GetRandomValue())
	                                Tool:Activate()
	                            end
	
	                            if Lunge.Enabled and Tool.GripUp.X == 0 then
	                                break
	                            end
	                            if Delta.Magnitude > AttackRange.Value then
	                                continue
	                            end
	
	                            Overlay.FilterDescendantsInstances = {v.Character}
	                            for _, Part: BasePart in workspace:GetPartBoundsInBox(v.RootPart.CFrame, Vector3.new(4, 4, 4), Overlay) do
	                                firetouchinterest(Interest.Parent, Part, 1)
	                                firetouchinterest(Interest.Parent, Part, 0)
	                            end
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
	    Max = 30,
	    Default = 13,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	AttackRange = Killaura:CreateSlider({
	    Name = "Attack range",
	    Min = 1,
	    Max = 30,
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
	Lunge = Killaura:CreateToggle({Name = "Sword lunge only"})
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
	    Function = function()
	        for _, v: Part in Particles do
	            v.ParticleEmitter.Texture = ParticleTexture.Value
	        end
	    end,
	    Darker = true,
	    Default = "rbxassetid://14736249347",
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
	    Decimal = 100,
	    Function = function(Val: number)
	        for _, v: Part in Particles do
	            v.ParticleEmitter.Size = NumberSequence.new(Val)
	        end
	    end,
	    Darker = true,
	    Default = 0.2,
	    Visible = false
	})
	Face = Killaura:CreateToggle({Name = "Face target"})
end)

Run(function()
	local Mode
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
	                    local Direction: Vector3 = Entity.character.Humanoid.MoveDirection * Value.Value
	                    if Mode.Value == "Velocity" then
	                        Root.AssemblyLinearVelocity = Direction + Vector3.new(0, Root.AssemblyLinearVelocity.Y, 0)
	                    elseif Mode.Value == "Impulse" then
	                        local Difference: Vector3 = (Direction - Root.AssemblyLinearVelocity) * Vector3.new(1, 0, 1)
	                        if Difference.Magnitude > (Direction == Vector3.zero and 10 or 2) then
	                            Root:ApplyImpulse(Difference * Root.AssemblyMass)
	                        end
	                    else
	                        Root.CFrame += Direction * Delta
	                    end
	                end
	            end))
	        end
	    end,
	    ExtraText = function()
	        return Mode.Value
	    end,
	    Tooltip = "Lets you jump farther"
	})
	
	Mode = LongJump:CreateDropdown({
	    Name = "Mode",
	    List = {"Velocity", "Impulse", "CFrame"},
	    Tooltip = "Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root"
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
	local MouseTP
	local Mode
	local MovementMode
	local Length
	local Delay
	local RayCheck: RaycastParams = RaycastParams.new()
	RayCheck.RespectCanCollide = true
	
	MouseTP = vape.Categories.Blatant:CreateModule({
	    Name = "MouseTP",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Position
	            if Mode.Value == "Mouse" then
	                local MouseRay = cloneref(LocalPlayer:GetMouse()).UnitRay
	                RayCheck.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
	                MouseRay = workspace:Raycast(MouseRay.Origin, MouseRay.Direction * 10000, RayCheck)
	                Position = MouseRay and MouseRay.Position + Vector3.new(0, Entity.character.HipHeight or 2, 0)
	            elseif Mode.Value == "Waypoint" then
	                local Object, Distance, Location = nil, math.huge, UserInputService:GetMouseLocation()
	
	                for _, v: Instance in WaypointFolder:GetChildren() do
	                    local ScreenPosition, Visible = Camera:WorldToViewportPoint(v.StudsOffsetWorldSpace)
	                    if not Visible then
	                        continue
	                    end
	
	                    local Magnitude: number = (Location - Vector2.new(ScreenPosition.x, ScreenPosition.y)).Magnitude
	                    if Magnitude < Distance then
	                        Object, Distance = v, Magnitude
	                    end
	                end
	
	                local Waypoint = Object
	                Position = Waypoint and Waypoint.StudsOffsetWorldSpace
	            else
	                local Ent = Entity.EntityMouse({
	                    Range = math.huge,
	                    Part = "RootPart",
	                    Players = true
	                })
	                Position = Ent and Ent.RootPart.Position
	            end
	
	            if not Position then
	                SendNotification("MouseTP", "No position found.", 5)
	                MouseTP:Toggle()
	                return
	            end
	
	            if MovementMode.Value ~= "Lerp" then
	                MouseTP:Toggle()
	                if Entity.isAlive then
	                    if MovementMode.Value == "Motor" then
	                        MotorMove(Entity.character.RootPart, CFrame.lookAlong(Position, Entity.character.RootPart.CFrame.LookVector))
	                    else
	                        Entity.character.RootPart.CFrame = CFrame.lookAlong(Position, Entity.character.RootPart.CFrame.LookVector)
	                    end
	                end
	            else
	                MouseTP:Clean(RunService.Heartbeat:Connect(function()
	                    if Entity.isAlive then
	                        Entity.character.RootPart.AssemblyLinearVelocity = Vector3.zero
	                    end
	                end))
	
	                repeat
	                    if Entity.isAlive then
	                        local Direction: Vector3 = CFrame.lookAt(Entity.character.RootPart.Position, Position).LookVector * math.min((Entity.character.RootPart.Position - Position).Magnitude, Length.Value)
	                        Entity.character.RootPart.CFrame += Direction
	                        if (Entity.character.RootPart.Position - Position).Magnitude < 3 and MouseTP.Enabled then
	                            MouseTP:Toggle()
	                        end
	                    elseif MouseTP.Enabled then
	                        MouseTP:Toggle()
	                        SendNotification("MouseTP", "Character missing", 5, "warning")
	                    end
	
	                    task.wait(Delay.Value)
	                until not MouseTP.Enabled
	            end
	        end
	    end,
	    Tooltip = "Teleports to a selected position."
	})
	
	Mode = MouseTP:CreateDropdown({
	    Name = "Mode",
	    List = {"Mouse", "Player", "Waypoint"}
	})
	MovementMode = MouseTP:CreateDropdown({
	    Name = "Movement",
	    List = {"CFrame", "Motor", "Lerp"},
	    Function = function(Val: string)
	        Length.Object.Visible = Val == "Lerp"
	        Delay.Object.Visible = Val == "Lerp"
	    end
	})
	Length = MouseTP:CreateSlider({
	    Name = "Length",
	    Min = 0,
	    Max = 150,
	    Darker = true,
	    Visible = false,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	Delay = MouseTP:CreateSlider({
	    Name = "Delay",
	    Min = 0,
	    Max = 1,
	    Decimal = 100,
	    Darker = true,
	    Visible = false,
	    Suffix = function(Val: number)
	        return Val == 1 and "second" or "seconds"
	    end
	})
end)

Run(function()
	local Mode
	local StudLimit = {Object = {}}
	local RayCheck: RaycastParams = RaycastParams.new()
	RayCheck.RespectCanCollide = true
	local OverlapCheck: OverlapParams = OverlapParams.new()
	OverlapCheck.MaxParts = 9e9
	local Modified, FFlagChanged = {}
	local Teleported: boolean?
	
	local Functions = {
	    Part = function()
	        local Characters: {Instance} = {Camera, LocalPlayer.Character}
	        for _, v: any in Entity.List do
	            table.insert(Characters, v.Character)
	        end
	        OverlapCheck.FilterDescendantsInstances = Characters
	
	        local Parts: {BasePart} = workspace:GetPartBoundsInBox(Entity.character.RootPart.CFrame + Vector3.new(0, 1, 0), Entity.character.RootPart.Size + Vector3.new(7, Entity.character.HipHeight, 7), OverlapCheck)
	        for _, v: BasePart in Parts do
	            if v.CanCollide and (not Spider.Enabled or SpiderShift) then
	                Modified[v] = true
	                v.CanCollide = false
	            end
	        end
	
	        for Part: BasePart in Modified do
	            if not table.find(Parts, Part) then
	                Modified[Part] = nil
	                Part.CanCollide = true
	            end
	        end
	    end,
	    Character = function()
	        for _, v: Instance in LocalPlayer.Character:GetDescendants() do
	            if v:IsA("BasePart") and v.CanCollide and (not Spider.Enabled or SpiderShift) then
	                Modified[v] = true
	                v.CanCollide = Spider.Enabled and not SpiderShift
	            end
	        end
	    end,
	    CFrame = function()
	        local Characters: {Instance} = {Camera, LocalPlayer.Character}
	        for _, v: any in Entity.List do
	            table.insert(Characters, v.Character)
	        end
	        RayCheck.FilterDescendantsInstances = Characters
	        OverlapCheck.FilterDescendantsInstances = Characters
	
	        local Ray: RaycastResult? = workspace:Raycast(Entity.character.Head.CFrame.Position, Entity.character.Humanoid.MoveDirection * 1.1, RayCheck)
	        if Ray and (not Spider.Enabled or SpiderShift) then
	            local Hit: RaycastResult = Ray
	            local PartCFrame, Magnitude, Closest = Hit.Instance.CFrame, 0, Enum.NormalId.Top
	
	            for _, v: EnumItem in Enum.NormalId:GetEnumItems() do
	                local Dot: number = PartCFrame:VectorToWorldSpace(Vector3.fromNormalId(v)):Dot(Hit.Normal)
	                if Dot > Magnitude then
	                    Magnitude, Closest = Dot, v
	                end
	            end
	
	            local PhaseDirection: string = Vector3.fromNormalId(Closest).X ~= 0 and "X" or "Z"
	            if Hit.Instance.Size[PhaseDirection] <= StudLimit.Value then
	                local Root: BasePart = Entity.character.RootPart
	                local Destination: CFrame = Root.CFrame + (Hit.Normal * (-(Hit.Instance.Size[PhaseDirection]) - (Root.Size.X / 1.5)))
	                if #workspace:GetPartBoundsInBox(Destination, Vector3.one, OverlapCheck) <= 0 then
	                    if Mode.Value == "Motor" then
	                        MotorMove(Root, Destination)
	                    else
	                        Root.CFrame = Destination
	                    end
	                end
	            end
	        end
	    end,
	    FFlag = function()
	        if Teleported then
	            return
	        end
	        setfflag("AssemblyExtentsExpansionStudHundredth", "-10000")
	        FFlagChanged = true
	    end
	}
	Functions.Motor = Functions.CFrame
	
	Phase = vape.Categories.Blatant:CreateModule({
	    Name = "Phase",
	    Function = function(Callback: boolean)
	        if Callback then
	            Phase:Clean(RunService.Stepped:Connect(function()
	                if Entity.isAlive and not vape.MovementOwner then
	                    Functions[Mode.Value]()
	                end
	            end))
	
	            if Mode.Value == "FFlag" then
	                Phase:Clean(LocalPlayer.OnTeleport:Connect(function()
	                    Teleported = true
	                    setfflag("AssemblyExtentsExpansionStudHundredth", "30")
	                end))
	            end
	        else
	            if FFlagChanged then
	                setfflag("AssemblyExtentsExpansionStudHundredth", "30")
	            end
	            for Part: BasePart in Modified do
	                Part.CanCollide = true
	            end
	            table.clear(Modified)
	            FFlagChanged = nil
	        end
	    end,
	    Tooltip = "Lets you Phase/Clip through walls. (Hold shift to use Phase over spider)"
	})
	
	Mode = Phase:CreateDropdown({
	    Name = "Mode",
	    List = {"Part", "Character", "CFrame", "Motor", "FFlag"},
	    Function = function(Val: string)
	        StudLimit.Object.Visible = Val == "CFrame" or Val == "Motor"
	        if FFlagChanged then
	            setfflag("AssemblyExtentsExpansionStudHundredth", "30")
	        end
	        for Part: BasePart in Modified do
	            Part.CanCollide = true
	        end
	        table.clear(Modified)
	        FFlagChanged = nil
	    end,
	    Tooltip = "Part - Modifies parts collision status around you\nCharacter - Modifies the local collision status of the character\nCFrame - Teleports you past parts\nMotor - Same as CFrame with a bypass\nFFlag - Directly adjusts all physics collisions"
	})
	StudLimit = Phase:CreateSlider({
	    Name = "Wall Size",
	    Min = 1,
	    Max = 20,
	    Default = 5,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end,
	    Darker = true,
	    Visible = false
	})
end)

Run(function()
	local Speed
	local Mode
	local Options
	local CustomProperties
	local AutoJump
	local AutoJumpCustom
	local AutoJumpValue
	local W, S, A, D = 0, 0, 0, 0
	
	Speed = vape.Categories.Blatant:CreateModule({
	    Name = "Speed",
	    Function = function(Callback: boolean)
	        FrictionTable.Speed = Callback and CustomProperties.Enabled or nil
	        UpdateVelocity()
	        if Callback then
	            Speed:Clean(RunService.PreSimulation:Connect(function(Delta: number)
	                if Entity.isAlive and not Fly.Enabled and not vape.Modules.LongJump.Enabled then
	                    local State: Enum.HumanoidStateType = Entity.character.Humanoid:GetState()
	                    if State == Enum.HumanoidStateType.Climbing then
	                        return
	                    end
	
	                    local MoveVector: Vector3 = TargetStrafeVector or Options.MoveMethod.Value == "Direct" and CalculateMoveVector(Vector3.new(A + D, 0, W + S)) or Entity.character.Humanoid.MoveDirection
	                    SpeedMethods[Mode.Value](Options, MoveVector, Delta)
	                    if AutoJump.Enabled and Entity.character.Humanoid.FloorMaterial ~= Enum.Material.Air and MoveVector ~= Vector3.zero then
	                        if AutoJumpCustom.Enabled then
	                            local Velocity: Vector3 = Entity.character.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	                            Entity.character.RootPart.AssemblyLinearVelocity = Vector3.new(Velocity.X, AutoJumpValue.Value, Velocity.Z)
	                        else
	                            Entity.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	                        end
	                    end
	                end
	            end))
	
	            W, S, A, D = UserInputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0, UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0, UserInputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0, UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
	            for _, v: string in {"InputBegan", "InputEnded"} do
	                Speed:Clean(UserInputService[v]:Connect(function(Input: InputObject)
	                    if not UserInputService:GetFocusedTextBox() then
	                        if Input.KeyCode == Enum.KeyCode.W then
	                            W = v == "InputBegan" and -1 or 0
	                        elseif Input.KeyCode == Enum.KeyCode.S then
	                            S = v == "InputBegan" and 1 or 0
	                        elseif Input.KeyCode == Enum.KeyCode.A then
	                            A = v == "InputBegan" and -1 or 0
	                        elseif Input.KeyCode == Enum.KeyCode.D then
	                            D = v == "InputBegan" and 1 or 0
	                        end
	                    end
	                end))
	            end
	        else
	            if Options.WalkSpeed and Entity.isAlive then
	                Entity.character.Humanoid.WalkSpeed = Options.WalkSpeed
	            end
	            Options.WalkSpeed = nil
	        end
	    end,
	    ExtraText = function()
	        return Mode.Value
	    end,
	    Tooltip = "Increases your movement with various methods."
	})
	
	Mode = Speed:CreateDropdown({
	    Name = "Mode",
	    List = SpeedMethodList,
	    Function = function(Val: string)
	        Options.WallCheck.Object.Visible = Val == "CFrame" or Val == "TP"
	        Options.TPFrequency.Object.Visible = Val == "TP"
	        Options.PulseLength.Object.Visible = Val == "Pulse"
	        Options.PulseDelay.Object.Visible = Val == "Pulse"
	        if Speed.Enabled then
	            Speed:Toggle()
	            Speed:Toggle()
	        end
	    end,
	    Tooltip = "Velocity - Uses smooth physics based movement\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position of the root\nTP - Large teleports within intervals\nPulse - Controllable bursts of speed\nWalkSpeed - The classic mode of speed, usually detected on most games."
	})
	Options = {
	    MoveMethod = Speed:CreateDropdown({
	        Name = "Move Mode",
	        List = {"MoveDirection", "Direct"},
	        Tooltip = "MoveDirection - Uses the games input vector for movement\nDirect - Directly calculate our own input vector"
	    }),
	    Value = Speed:CreateSlider({
	        Name = "Speed",
	        Min = 1,
	        Max = 150,
	        Default = 50,
	        Suffix = function(Val: number)
	            return Val == 1 and "stud" or "studs"
	        end
	    }),
	    TPFrequency = Speed:CreateSlider({
	        Name = "TP Frequency",
	        Min = 0,
	        Max = 1,
	        Decimal = 100,
	        Darker = true,
	        Visible = false,
	        Suffix = function(Val: number)
	            return Val == 1 and "second" or "seconds"
	        end
	    }),
	    PulseLength = Speed:CreateSlider({
	        Name = "Pulse Length",
	        Min = 0,
	        Max = 1,
	        Decimal = 100,
	        Darker = true,
	        Visible = false,
	        Suffix = function(Val: number)
	            return Val == 1 and "second" or "seconds"
	        end
	    }),
	    PulseDelay = Speed:CreateSlider({
	        Name = "Pulse Delay",
	        Min = 0,
	        Max = 1,
	        Decimal = 100,
	        Darker = true,
	        Visible = false,
	        Suffix = function(Val: number)
	            return Val == 1 and "second" or "seconds"
	        end
	    }),
	    WallCheck = Speed:CreateToggle({
	        Name = "Wall Check",
	        Default = true,
	        Darker = true,
	        Visible = false
	    }),
	    TPTiming = tick(),
	    rayCheck = RaycastParams.new()
	}
	Options.rayCheck.RespectCanCollide = true
	CustomProperties = Speed:CreateToggle({
	    Name = "Custom Properties",
	    Function = function()
	        if Speed.Enabled then
	            Speed:Toggle()
	            Speed:Toggle()
	        end
	    end,
	    Default = true
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
	local Mode
	local Value
	local State
	local RayCheck: RaycastParams = RaycastParams.new()
	RayCheck.RespectCanCollide = true
	local Active, Truss
	
	Spider = vape.Categories.Blatant:CreateModule({
	    Name = "Spider",
	    Function = function(Callback: boolean)
	        if Callback then
	            if Truss then
	                Truss.Parent = Camera
	            end
	
	            Spider:Clean(RunService.PreSimulation:Connect(function(Delta: number)
	                if Entity.isAlive and not vape.MovementOwner then
	                    local Root: BasePart = Entity.character.RootPart
	                    local Characters: {Instance} = {Camera, LocalPlayer.Character, Truss}
	                    for _, v: any in Entity.List do
	                        table.insert(Characters, v.Character)
	                    end
	
	                    SpiderShift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
	                    RayCheck.FilterDescendantsInstances = Characters
	                    RayCheck.CollisionGroup = Root.CollisionGroup
	
	                    if Mode.Value ~= "Part" then
	                        local Direction: Vector3 = Entity.character.Humanoid.MoveDirection * 2.5
	                        local Ray: RaycastResult? = workspace:Raycast(Root.Position - Vector3.new(0, Entity.character.HipHeight - 0.5, 0), Direction, RayCheck)
	                        if Active and not Ray then
	                            Root.AssemblyLinearVelocity = Vector3.new(Root.AssemblyLinearVelocity.X, 0, Root.AssemblyLinearVelocity.Z)
	                        end
	
	                        Active = Ray
	                        if Active and Ray.Normal.Y == 0 then
	                            if not Phase.Enabled or not SpiderShift then
	                                if State.Enabled then
	                                    Entity.character.Humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
	                                end
	
	                                Root.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)
	                                if Mode.Value == "CFrame" then
	                                    Root.CFrame += Vector3.new(0, Value.Value * Delta, 0)
	                                elseif Mode.Value == "Impulse" then
	                                    Root:ApplyImpulse(Vector3.new(0, Value.Value, 0) * Root.AssemblyMass)
	                                else
	                                    Root.AssemblyLinearVelocity += Vector3.new(0, Value.Value, 0)
	                                end
	                            end
	                        end
	                    else
	                        local Ray: RaycastResult? = workspace:Raycast(Root.Position - Vector3.new(0, Entity.character.HipHeight - 0.5, 0), Entity.character.RootPart.CFrame.LookVector * 2, RayCheck)
	                        if Ray and (not Phase.Enabled or not SpiderShift) then
	                            Truss.Position = Ray.Position - Ray.Normal * 0.9 or Vector3.zero
	                        else
	                            Truss.Position = Vector3.zero
	                        end
	                    end
	                end
	            end))
	        else
	            if Truss then
	                Truss.Parent = nil
	            end
	            SpiderShift = false
	        end
	    end,
	    Tooltip = "Lets you climb up walls. (Hold shift to use Phase over spider)"
	})
	
	Mode = Spider:CreateDropdown({
	    Name = "Mode",
	    List = {"Velocity", "Impulse", "CFrame", "Part"},
	    Function = function(Val: string)
	        Value.Object.Visible = Val ~= "Part"
	        State.Object.Visible = Val ~= "Part"
	        if Truss then
	            Truss:Destroy()
	            Truss = nil
	        end
	        if Val == "Part" then
	            Truss = Instance.new("TrussPart")
	            Truss.Size = Vector3.new(2, 2, 2)
	            Truss.Transparency = 1
	            Truss.Anchored = true
	            Truss.Parent = Spider.Enabled and Camera or nil
	        end
	    end,
	    Tooltip = "Velocity - Uses smooth movement to boost you upward\nImpulse - Same as velocity while using forces instead\nCFrame - Directly adjusts the position upward\nPart - Positions a climbable part infront of you"
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
	State = Spider:CreateToggle({
	    Name = "Climb State",
	    Darker = true
	})
end)

Run(function()
	local SpinBot
	local Mode
	local XToggle
	local YToggle
	local ZToggle
	local Value
	local AngularVelocity
	
	SpinBot = vape.Categories.Blatant:CreateModule({
	    Name = "SpinBot",
	    Function = function(Callback: boolean)
	        if Callback then
	            SpinBot:Clean(RunService.PreSimulation:Connect(function()
	                if Entity.isAlive then
	                    if Mode.Value == "RotVelocity" then
	                        local OriginalRotVelocity: Vector3 = Entity.character.RootPart.RotVelocity
	                        Entity.character.Humanoid.AutoRotate = false
	                        Entity.character.RootPart.RotVelocity = Vector3.new(XToggle.Enabled and Value.Value or OriginalRotVelocity.X, YToggle.Enabled and Value.Value or OriginalRotVelocity.Y, ZToggle.Enabled and Value.Value or OriginalRotVelocity.Z)
	                    elseif Mode.Value == "CFrame" then
	                        local Angle: number = math.rad((tick() * (20 * Value.Value)) % 360)
	                        local X, Y, Z = Entity.character.RootPart.CFrame:ToOrientation()
	                        Entity.character.RootPart.CFrame = CFrame.new(Entity.character.RootPart.Position) * CFrame.Angles(XToggle.Enabled and Angle or X, YToggle.Enabled and Angle or Y, ZToggle.Enabled and Angle or Z)
	                    elseif AngularVelocity then
	                        AngularVelocity.Parent = Entity.isAlive and Entity.character.RootPart
	                        AngularVelocity.MaxTorque = Vector3.new(XToggle.Enabled and math.huge or 0, YToggle.Enabled and math.huge or 0, ZToggle.Enabled and math.huge or 0)
	                        AngularVelocity.AngularVelocity = Vector3.new(Value.Value, Value.Value, Value.Value)
	                    end
	                end
	            end))
	        else
	            if Entity.isAlive and Mode.Value == "RotVelocity" then
	                Entity.character.Humanoid.AutoRotate = true
	            end
	
	            if AngularVelocity then
	                AngularVelocity.Parent = nil
	            end
	        end
	    end,
	    Tooltip = "Makes your character spin around in circles (does not work in first person)"
	})
	
	Mode = SpinBot:CreateDropdown({
	    Name = "Mode",
	    List = {"CFrame", "RotVelocity", "BodyMover"},
	    Function = function(Val: string)
	        if AngularVelocity then
	            AngularVelocity:Destroy()
	            AngularVelocity = nil
	        end
	        AngularVelocity = Val == "BodyMover" and Instance.new("BodyAngularVelocity") or nil
	    end,
	    Tooltip = "CFrame - Directly adjusts your characters angle\nRotVelocity - Sets the rotation velocity so that you spin\nBodyMover - Uses body movers to edit your rotation velocity"
	})
	Value = SpinBot:CreateSlider({
	    Name = "Speed",
	    Min = 1,
	    Max = 100,
	    Default = 40
	})
	XToggle = SpinBot:CreateToggle({Name = "Spin X"})
	YToggle = SpinBot:CreateToggle({
	    Name = "Spin Y",
	    Default = true
	})
	ZToggle = SpinBot:CreateToggle({Name = "Spin Z"})
end)

Run(function()
	local Swim
	local Terrain: Terrain = cloneref(workspace:FindFirstChildWhichIsA("Terrain"))
	local LastRegion: Region3 = Region3.new(Vector3.zero, Vector3.zero)
	
	Swim = vape.Categories.Blatant:CreateModule({
	    Name = "Swim",
	    Function = function(Callback: boolean)
	        if Callback then
	            Swim:Clean(RunService.PreSimulation:Connect(function(Delta: number)
	                if Entity.isAlive and not vape.MovementOwner then
	                    local Root: BasePart = Entity.character.RootPart
	                    local Moving: boolean = Entity.character.Humanoid.MoveDirection ~= Vector3.zero
	                    local RootVelocity: Vector3 = Root.AssemblyLinearVelocity
	                    local Space: boolean = UserInputService:IsKeyDown(Enum.KeyCode.Space)
	
	                    if Terrain then
	                        local Factor: Vector3 = (Moving or Space) and Vector3.new(6, 6, 6) or Vector3.new(2, 1, 2)
	                        local Position: Vector3 = Root.Position - Vector3.new(0, 1, 0)
	                        local NewRegion: Region3 = Region3.new(Position - Factor, Position + Factor):ExpandToGrid(4)
	                        Terrain:ReplaceMaterial(LastRegion, 4, Enum.Material.Water, Enum.Material.Air)
	                        Terrain:FillRegion(NewRegion, 4, Enum.Material.Water)
	                        LastRegion = NewRegion
	                    end
	                elseif vape.MovementOwner and Terrain and LastRegion.Size ~= Vector3.zero then
	                    Terrain:ReplaceMaterial(LastRegion, 4, Enum.Material.Water, Enum.Material.Air)
	                    LastRegion = Region3.new(Vector3.zero, Vector3.zero)
	                end
	            end))
	        else
	            if Terrain and LastRegion then
	                Terrain:ReplaceMaterial(LastRegion, 4, Enum.Material.Water, Enum.Material.Air)
	            end
	        end
	    end,
	    Tooltip = "Lets you swim midair"
	})
end)

Run(function()
	local TargetStrafe
	local Targets
	local SearchRange
	local StrafeRange
	local YFactor
	local RayCheck: RaycastParams = RaycastParams.new()
	RayCheck.RespectCanCollide = true
	local Module, Old
	
	TargetStrafe = vape.Categories.Blatant:CreateModule({
	    Name = "TargetStrafe",
	    Function = function(Callback: boolean)
	        if Callback then
	            if not Module then
	                local Success: boolean = pcall(function()
	                    Module = require(LocalPlayer.PlayerScripts.PlayerModule).controls
	                end)
	                if not Success then
	                    Module = {}
	                end
	            end
	
	            Old = Module.moveFunction
	            local FlyMod, Ang, OldEnt = vape.Modules.Fly or {Enabled = false}
	            Module.moveFunction = function(self, Vector: Vector3, Face: boolean)
	                local WallCheck: boolean = Targets.Walls.Enabled
	                local Ent = not vape.MovementOwner and not UserInputService:IsKeyDown(Enum.KeyCode.S) and Entity.EntityPosition({
	                    Range = SearchRange.Value,
	                    Wallcheck = WallCheck,
	                    Part = "RootPart",
	                    Players = Targets.Players.Enabled,
	                    NPCs = Targets.NPCs.Enabled,
	                    Priority = Targets.Priority.Value
	                })
	
	                if Ent then
	                    local Root, TargetPos = Entity.character.RootPart, Ent.RootPart.Position
	                    RayCheck.FilterDescendantsInstances = {LocalPlayer.Character, Camera, Ent.Character}
	                    RayCheck.CollisionGroup = Root.CollisionGroup
	
	                    if FlyMod.Enabled or workspace:Raycast(TargetPos, Vector3.new(0, -70, 0), RayCheck) then
	                        local Factor, LocalPosition = 0, Root.Position
	                        if Ent ~= OldEnt then
	                            Ang = math.deg(select(2, CFrame.lookAt(TargetPos, LocalPosition):ToEulerAnglesYXZ()))
	                        end
	
	                        local YOffset: number = math.abs(LocalPosition.Y - TargetPos.Y) * (YFactor.Value / 100)
	                        local EntityPos: Vector3 = Vector3.new(TargetPos.X, LocalPosition.Y, TargetPos.Z)
	                        local NewPos: Vector3 = EntityPos + (CFrame.Angles(0, math.rad(Ang), 0).LookVector * (StrafeRange.Value - YOffset))
	                        local StartRay, EndRay = EntityPos, NewPos
	
	                        if not WallCheck and workspace:Raycast(TargetPos, (LocalPosition - TargetPos), RayCheck) then
	                            StartRay, EndRay = EntityPos + (CFrame.Angles(0, math.rad(Ang), 0).LookVector * (EntityPos - LocalPosition).Magnitude), EntityPos
	                        end
	
	                        local Ray: RaycastResult? = workspace:Blockcast(CFrame.new(StartRay), Vector3.new(1, Entity.character.HipHeight + (Root.Size.Y / 2), 1), (EndRay - StartRay), RayCheck)
	                        if (LocalPosition - NewPos).Magnitude < 3 or Ray then
	                            Factor = (8 - math.min((LocalPosition - NewPos).Magnitude, 3))
	                            if Ray then
	                                NewPos = Ray.Position + (Ray.Normal * 1.5)
	                                Factor = (LocalPosition - NewPos).Magnitude > 3 and 0 or Factor
	                            end
	                        end
	
	                        if not FlyMod.Enabled and not workspace:Raycast(NewPos, Vector3.new(0, -70, 0), RayCheck) then
	                            NewPos = EntityPos
	                            Factor = 40
	                        end
	
	                        Ang = (Ang + Factor) % 360
	                        Vector = ((NewPos - LocalPosition) * Vector3.new(1, 0, 1)).Unit
	                        Vector = Vector == Vector and Vector or Vector3.zero
	                        TargetStrafeVector = Vector
	                    else
	                        Ent = nil
	                    end
	                end
	
	                TargetStrafeVector = Ent and Vector or nil
	                OldEnt = Ent
	
	                return Old(self, Vector, Face)
	            end
	        else
	            if Module and Old then
	                Module.moveFunction = Old
	            end
	            TargetStrafeVector = nil
	        end
	    end,
	    Tooltip = "Automatically strafes around the opponent"
	})
	
	Targets = TargetStrafe:CreateTargets({
	    Players = true,
	    Walls = true
	})
	SearchRange = TargetStrafe:CreateSlider({
	    Name = "Search Range",
	    Min = 1,
	    Max = 30,
	    Default = 24,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	StrafeRange = TargetStrafe:CreateSlider({
	    Name = "Strafe Range",
	    Min = 1,
	    Max = 30,
	    Default = 18,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	YFactor = TargetStrafe:CreateSlider({
	    Name = "Y Factor",
	    Min = 0,
	    Max = 100,
	    Default = 100,
	    Suffix = "%"
	})
end)

Run(function()
	local Timer
	local Value
	
	Timer = vape.Categories.Blatant:CreateModule({
	    Name = "Timer",
	    Function = function(Callback: boolean)
	        if Callback then
	            setfflag("SimEnableStepPhysics", "True")
	            setfflag("SimEnableStepPhysicsSelective", "True")
	
	            Timer:Clean(RunService.RenderStepped:Connect(function(Delta: number)
	                if Value.Value > 1 then
	                    RunService:Pause()
	                    workspace:StepPhysics(Delta * (Value.Value - 1), {Entity.character.RootPart})
	                    RunService:Run()
	                end
	            end))
	        end
	    end,
	    Tooltip = "Change the game speed."
	})
	
	Value = Timer:CreateSlider({
	    Name = "Value",
	    Min = 1,
	    Max = 3,
	    Decimal = 10
	})
end)

Run(function()
	local Arrows
	local Targets
	local Color
	local Teammates
	local Distance
	local DistanceLimit
	local Reference = {}
	local Folder: Folder = Instance.new("Folder")
	Folder.Parent = vape.gui
	
	local function Added(Ent)
	    if not Targets.Players.Enabled and Ent.Player then
	        return
	    end
	    if not Targets.NPCs.Enabled and Ent.NPC then
	        return
	    end
	    if Teammates.Enabled and (not Ent.Targetable) and (not Ent.Friend) then
	        return
	    end
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    local Arrow: ImageLabel = Instance.new("ImageLabel")
	    Arrow.Size = UDim2.fromOffset(256, 256)
	    Arrow.Position = UDim2.fromScale(0.5, 0.5)
	    Arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	    Arrow.BackgroundTransparency = 1
	    Arrow.BorderSizePixel = 0
	    Arrow.Visible = false
	    Arrow.Image = GetVapeAsset("kingvape/assets/new/arrowmodule.png")
	    Arrow.ImageColor3 = Entity.getEntityColor(Ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	    Arrow.Parent = Folder
	    Reference[Ent] = Arrow
	end
	
	local function Removed(Ent)
	    local Arrow: ImageLabel? = Reference[Ent]
	    if Arrow then
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	
	        Reference[Ent] = nil
	        Arrow:Destroy()
	    end
	end
	
	local function ColorFunc(Hue: number, Sat: number, Val: number)
	    local DefaultColor: Color3 = Color3.fromHSV(Hue, Sat, Val)
	    for Ent: any, v: ImageLabel in Reference do
	        v.ImageColor3 = Entity.getEntityColor(Ent) or DefaultColor
	    end
	end
	
	local function Loop()
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    for Ent: any, v: ImageLabel in Reference do
	        if Distance.Enabled then
	            local EntityDistance: number = Entity.isAlive and (Entity.character.RootPart.Position - Ent.RootPart.Position).Magnitude or math.huge
	            if EntityDistance < DistanceLimit.ValueMin or EntityDistance > DistanceLimit.ValueMax then
	                v.Visible = false
	                continue
	            end
	        end
	
	        local _, RootVisible = Camera:WorldToScreenPoint(Ent.RootPart.Position)
	        v.Visible = not RootVisible
	        if RootVisible then
	            continue
	        end
	
	        local Direction: Vector3 = CFrame.lookAlong(Camera.CFrame.Position, Camera.CFrame.LookVector * Vector3.new(1, 0, 1)):PointToObjectSpace(Ent.RootPart.Position)
	        v.Rotation = math.deg(math.atan2(Direction.Z, Direction.X))
	    end
	end
	
	Arrows = vape.Categories.Render:CreateModule({
	    Name = "Arrows",
	    Function = function(Callback: boolean)
	        if Callback then
	            Arrows:Clean(Entity.Events.EntityRemoved:Connect(Removed))
	            for _, v: any in Entity.List do
	                if Reference[v] then
	                    Removed(v)
	                end
	                Added(v)
	            end
	            Arrows:Clean(Entity.Events.EntityAdded:Connect(function(Ent)
	                if Reference[Ent] then
	                    Removed(Ent)
	                end
	                Added(Ent)
	            end))
	            Arrows:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
	                ColorFunc(Color.Hue, Color.Sat, Color.Value)
	            end))
	            Arrows:Clean(RunService.RenderStepped:Connect(Loop))
	        else
	            for Ent: any in Reference do
	                Removed(Ent)
	            end
	        end
	    end,
	    Tooltip = "Draws arrows on screen when entities\nare out of your field of view."
	})
	
	Targets = Arrows:CreateTargets({
	    Players = true,
	    Function = function()
	        if Arrows.Enabled then
	            Arrows:Toggle()
	            Arrows:Toggle()
	        end
	    end
	})
	Color = Arrows:CreateColorSlider({
	    Name = "Player Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        if Arrows.Enabled then
	            ColorFunc(Hue, Sat, Val)
	        end
	    end
	})
	Teammates = Arrows:CreateToggle({
	    Name = "Priority Only",
	    Function = function()
	        if Arrows.Enabled then
	            Arrows:Toggle()
	            Arrows:Toggle()
	        end
	    end,
	    Default = true,
	    Tooltip = "Hides teammates & non targetable entities"
	})
	Distance = Arrows:CreateToggle({
	    Name = "Distance Check",
	    Function = function(Callback: boolean)
	        DistanceLimit.Object.Visible = Callback
	    end
	})
	DistanceLimit = Arrows:CreateTwoSlider({
	    Name = "Player Distance",
	    Min = 0,
	    Max = 256,
	    DefaultMin = 0,
	    DefaultMax = 64,
	    Darker = true,
	    Visible = false
	})
end)

Run(function()
	local BlurryTextures
	local Strength
	local Resolution
	local Interface
	local Core
	local World
	local BlurObject
	local AssetService: AssetService = cloneref(game:GetService("AssetService"))
	local CoreGui: CoreGui = cloneref(game:GetService("CoreGui"))
	local Sizes: {[string]: number} = {High = 150, Low = 420}
	local Properties: {[string]: string} = {
	    Decal = "Texture",
	    ImageButton = "Image",
	    ImageLabel = "Image",
	    MeshPart = "TextureID",
	    Texture = "Texture"
	}
	local Reference: {[Instance]: string} = {}
	local Watched: {[Instance]: boolean} = {}
	local Grids = {}
	local PixelCache = {}
	local Versions = setmetatable({}, {__mode = "k"})
	local ResizeToken: number = 0
	
	local function GetAssetId(ContentUri: string)
	    return ContentUri:match("^rbxassetid://(%d+)") or ContentUri:match("%?id=(%d+)") or ContentUri:match("^(%d+)$")
	end
	
	local function CanPixelate(Object)
	    if Object.Image == "" or Object.ScaleType == Enum.ScaleType.Slice or Object.ScaleType == Enum.ScaleType.Tile then
	        return false
	    end
	    return Object.AutomaticSize == Enum.AutomaticSize.None and not Object:FindFirstChildWhichIsA("UIGradient")
	end
	
	local function IsAllowed(Object: Instance)
	    if Object:IsDescendantOf(CoreGui) then
	        return Core.Enabled
	    end
	    return Interface.Enabled
	end
	
	local function ReadPixels(ContentUri: string, RectOffset: Vector2, RectSize: Vector2, Count: number)
	    local Key: string = `{ContentUri}|{RectOffset}|{RectSize}|{Count}`
	    if PixelCache[Key] ~= nil then
	        return PixelCache[Key] or nil
	    end
	
	    local Success, Image = pcall(AssetService.CreateEditableImageAsync, AssetService, Content.fromUri(ContentUri))
	    if not Success or not Image then
	        PixelCache[Key] = false
	        return nil
	    end
	
	    local Size: Vector2 = RectSize ~= Vector2.zero and RectSize or Image.Size
	    local ReadSuccess, Pixels = pcall(Image.ReadPixelsBuffer, Image, RectOffset, Size)
	    Image:Destroy()
	    if not ReadSuccess then
	        PixelCache[Key] = false
	        return nil
	    end
	
	    local Cells = {}
	    for CellY: number = 0, Count - 1 do
	        for CellX: number = 0, Count - 1 do
	            local StartX, EndX = math.floor(CellX * Size.X / Count), math.max(math.floor((CellX + 1) * Size.X / Count) - 1, math.floor(CellX * Size.X / Count))
	            local StartY, EndY = math.floor(CellY * Size.Y / Count), math.max(math.floor((CellY + 1) * Size.Y / Count) - 1, math.floor(CellY * Size.Y / Count))
	            local Step: number = math.max(math.floor((EndX - StartX + 1) / 6), 1)
	            local R, G, B, Alpha, Samples = 0, 0, 0, 0, 0
	            for Y: number = StartY, EndY, Step do
	                for X: number = StartX, EndX, Step do
	                    local Index: number = (Y * Size.X + X) * 4
	                    local PixelAlpha: number = buffer.readu8(Pixels, Index + 3) / 255
	                    R += buffer.readu8(Pixels, Index) * PixelAlpha
	                    G += buffer.readu8(Pixels, Index + 1) * PixelAlpha
	                    B += buffer.readu8(Pixels, Index + 2) * PixelAlpha
	                    Alpha += PixelAlpha
	                    Samples += 1
	                end
	            end
	            if Alpha > 0 then
	                table.insert(Cells, {X = CellX, Y = CellY, Color = Color3.fromRGB(R / Alpha, G / Alpha, B / Alpha), Alpha = Alpha / Samples})
	            end
	        end
	    end
	
	    local Result = {Aspect = Size.X / Size.Y, Cells = Cells}
	    PixelCache[Key] = Result
	    return Result
	end
	
	local function ColorGrid(Object)
	    local Grid = Grids[Object]
	    if not Grid then
	        return
	    end
	    local Tint, Visibility = Object.ImageColor3, 1 - Grid.Transparency
	    for Frame: Frame, Cell: {X: number, Y: number, Color: Color3, Alpha: number} in Grid.Frames do
	        Frame.BackgroundColor3 = Color3.new(Cell.Color.R * Tint.R, Cell.Color.G * Tint.G, Cell.Color.B * Tint.B)
	        Frame.BackgroundTransparency = 1 - Cell.Alpha * Visibility
	    end
	end
	
	local function RemoveGrid(Object)
	    local Grid = Grids[Object]
	    if not Grid then
	        return
	    end
	    Grids[Object] = nil
	    Grid.Holder:Destroy()
	    pcall(function()
	        Object.ImageTransparency = Grid.Transparency
	    end)
	end
	
	local function Pixelate(Object)
	    local Version: number = (Versions[Object] or 0) + 1
	    Versions[Object] = Version
	    RemoveGrid(Object)
	    if not CanPixelate(Object) then
	        return
	    end
	
	    local Count: number = Resolution.Value
	    local Pixels = ReadPixels(Reference[Object] or Object.Image, Object.ImageRectOffset, Object.ImageRectSize, Count)
	    if not Pixels or Versions[Object] ~= Version or not BlurryTextures.Enabled or not IsAllowed(Object) or not Object.Parent then
	        return
	    end
	
	    local Holder: Frame = Instance.new("Frame")
	    Holder.Name = "PixelGrid"
	    Holder.AnchorPoint = Vector2.new(0.5, 0.5)
	    Holder.BackgroundTransparency = 1
	    Holder.Position = UDim2.fromScale(0.5, 0.5)
	    Holder.Size = UDim2.fromScale(1, 1)
	    Holder.ZIndex = 0
	    if Object.ScaleType == Enum.ScaleType.Fit then
	        local Ratio: UIAspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
	        Ratio.AspectRatio = Pixels.Aspect
	        Ratio.Parent = Holder
	    end
	
	    local Frames = {}
	    for _, Cell: {X: number, Y: number, Color: Color3, Alpha: number} in Pixels.Cells do
	        local Frame: Frame = Instance.new("Frame")
	        Frame.BorderSizePixel = 0
	        Frame.Position = UDim2.fromScale(Cell.X / Count, Cell.Y / Count)
	        Frame.Size = UDim2.new(1 / Count, Cell.X < Count - 1 and 1 or 0, 1 / Count, Cell.Y < Count - 1 and 1 or 0)
	        Frame.Parent = Holder
	        Frames[Frame] = Cell
	    end
	
	    Grids[Object] = {Holder = Holder, Frames = Frames, Transparency = Object.ImageTransparency}
	    ColorGrid(Object)
	    Holder.Parent = Object
	    Object.ImageTransparency = 1
	end
	
	local function Watch(Object)
	    if Watched[Object] then
	        return
	    end
	    Watched[Object] = true
	    for _, PropertyName: string in {"Image", "ImageRectOffset", "ImageRectSize", "ScaleType"} do
	        BlurryTextures:Clean(Object:GetPropertyChangedSignal(PropertyName):Connect(function()
	            if IsAllowed(Object) then
	                task.spawn(Pixelate, Object)
	            end
	        end))
	    end
	    BlurryTextures:Clean(Object:GetPropertyChangedSignal("ImageColor3"):Connect(function()
	        ColorGrid(Object)
	    end))
	    BlurryTextures:Clean(Object:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
	        local Grid = Grids[Object]
	        if Grid and Object.ImageTransparency ~= 1 then
	            Grid.Transparency = Object.ImageTransparency
	            Object.ImageTransparency = 1
	            ColorGrid(Object)
	        end
	    end))
	end
	
	function BlurObject(Object: Instance)
	    local Property: string? = Properties[Object.ClassName]
	    if not Property then
	        return
	    end
	
	    if Property == "Image" then
	        if Object:IsDescendantOf(vape.gui) then
	            return
	        end
	        Watch(Object)
	        task.spawn(Pixelate, Object)
	        return
	    end
	
	    local ContentUri: string = Object[Property]
	    if ContentUri:match("^rbxthumb") then
	        return
	    end
	
	    local Id: string? = GetAssetId(ContentUri)
	    if not Id then
	        return
	    end
	    if Property == "TextureID" and Object:FindFirstChildWhichIsA("SurfaceAppearance") then
	        return
	    end
	
	    local Size: number = Sizes[Strength.Value]
	    Reference[Object] = ContentUri
	    Object[Property] = `rbxthumb://type=Asset&id={Id}&w={Size}&h={Size}`
	end
	
	local function Scan(Root: Instance)
	    local Descendants: {Instance} = Root:GetDescendants()
	    for i: number, v: Instance in Descendants do
	        if not BlurryTextures.Enabled then
	            return
	        end
	        BlurObject(v)
	
	        if i % 500 == 0 then
	            task.wait()
	        end
	    end
	end
	
	local function Restore()
	    for Object: Instance in Grids do
	        Versions[Object] = (Versions[Object] or 0) + 1
	        RemoveGrid(Object)
	    end
	
	    local Blurred = Reference
	    Reference = {}
	
	    for Object: Instance, ContentUri: string in Blurred do
	        pcall(function()
	            Object[Properties[Object.ClassName]] = ContentUri
	        end)
	    end
	end
	
	local function Refresh()
	    if not BlurryTextures.Enabled then
	        return
	    end
	    Restore()
	
	    if Interface.Enabled then
	        Scan(LocalPlayer.PlayerGui)
	    end
	
	    if Core.Enabled then
	        Scan(CoreGui)
	    end
	
	    if World.Enabled then
	        Scan(workspace)
	    end
	end
	
	BlurryTextures = vape.Categories.Render:CreateModule({
	    Name = "BlurryTextures",
	    Function = function(Callback: boolean)
	        if Callback then
	            BlurryTextures:Clean(LocalPlayer.PlayerGui.DescendantAdded:Connect(function(Object: Instance)
	                if Interface.Enabled then
	                    BlurObject(Object)
	                end
	            end))
	            BlurryTextures:Clean(CoreGui.DescendantAdded:Connect(function(Object: Instance)
	                if Core.Enabled then
	                    BlurObject(Object)
	                end
	            end))
	            BlurryTextures:Clean(workspace.DescendantAdded:Connect(function(Object: Instance)
	                if World.Enabled then
	                    BlurObject(Object)
	                end
	            end))
	            Refresh()
	        else
	            Restore()
	            table.clear(Watched)
	        end
	    end,
	    Tooltip = "Redraws every image at a fraction of its resolution so the game looks blurry."
	})
	
	Strength = BlurryTextures:CreateDropdown({
	    Name = "Strength",
	    List = {"High", "Low"},
	    Function = Refresh,
	    Tooltip = "Roblox only serves two image sizes for the world, High redraws at 150px and Low at 420px"
	})
	Resolution = BlurryTextures:CreateSlider({
	    Name = "Resolution",
	    Min = 4,
	    Max = 32,
	    Default = 12,
	    Suffix = "px",
	    Function = function()
	        ResizeToken += 1
	        local Token: number = ResizeToken
	        task.delay(0.3, function()
	            if Token ~= ResizeToken or not BlurryTextures.Enabled then
	                return
	            end
	            for Object: Instance in Watched do
	                if IsAllowed(Object) then
	                    task.spawn(Pixelate, Object)
	                end
	            end
	        end)
	    end,
	    Tooltip = "How many pixels across each interface image is redrawn with, lower looks blockier"
	})
	Interface = BlurryTextures:CreateToggle({
	    Name = "Interface",
	    Function = Refresh,
	    Default = true,
	    Tooltip = "Pixelates the images the game draws in its own menus"
	})
	Core = BlurryTextures:CreateToggle({
	    Name = "Core GUI",
	    Function = Refresh,
	    Default = true,
	    Tooltip = "Pixelates Roblox's own interface too, like the top bar, backpack and player list"
	})
	World = BlurryTextures:CreateToggle({
	    Name = "World",
	    Function = Refresh,
	    Default = true,
	    Tooltip = "Blurs the decals, textures and mesh skins around the map"
	})
end)

Run(function()
	local Chams
	local Targets
	local Mode
	local FillColor
	local OutlineColor
	local FillTransparency
	local OutlineTransparency
	local Teammates
	local Walls
	local Reference = {}
	local Folder: Folder = Instance.new("Folder")
	Folder.Parent = vape.gui
	
	local function Added(Ent)
	    if not Targets.Players.Enabled and Ent.Player then
	        return
	    end
	    if not Targets.NPCs.Enabled and Ent.NPC then
	        return
	    end
	    if Teammates.Enabled and (not Ent.Targetable) and (not Ent.Friend) then
	        return
	    end
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    if Mode.Value == "Highlight" then
	        local Cham: Highlight = Instance.new("Highlight")
	        Cham.Adornee = Ent.Character
	        Cham.DepthMode = Enum.HighlightDepthMode[Walls.Enabled and "AlwaysOnTop" or "Occluded"]
	        Cham.FillColor = Entity.getEntityColor(Ent) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
	        Cham.OutlineColor = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
	        Cham.FillTransparency = FillTransparency.Value
	        Cham.OutlineTransparency = OutlineTransparency.Value
	        Cham.Parent = Folder
	        Reference[Ent] = Cham
	    else
	        local Adornments = {}
	        for _, v: Instance in Ent.Character:GetChildren() do
	            if v:IsA("BasePart") and (Ent.NPC or v.Name:find("Arm") or v.Name:find("Leg") or v.Name:find("Hand") or v.Name:find("Feet") or v.Name:find("Torso") or v.Name == "Head") then
	                local Box = Instance.new(v.Name == "Head" and "SphereHandleAdornment" or "BoxHandleAdornment")
	                if v.Name == "Head" then
	                    Box.Radius = 0.75
	                else
	                    Box.Size = v.Size
	                end
	                Box.AlwaysOnTop = Walls.Enabled
	                Box.Adornee = v
	                Box.ZIndex = 0
	                Box.Transparency = FillTransparency.Value
	                Box.Color3 = Entity.getEntityColor(Ent) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
	                Box.Parent = Folder
	                table.insert(Adornments, Box)
	            end
	        end
	        Reference[Ent] = Adornments
	    end
	end
	
	local function Removed(Ent)
	    if Reference[Ent] then
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	        if type(Reference[Ent]) == "table" then
	            for _, v: Instance in Reference[Ent] do
	                v:Destroy()
	            end
	            table.clear(Reference[Ent])
	        else
	            Reference[Ent]:Destroy()
	        end
	        Reference[Ent] = nil
	    end
	end
	
	Chams = vape.Categories.Render:CreateModule({
	    Name = "Chams",
	    Function = function(Callback: boolean)
	        if Callback then
	            Chams:Clean(Entity.Events.EntityRemoved:Connect(Removed))
	            Chams:Clean(Entity.Events.EntityAdded:Connect(function(Ent)
	                if Reference[Ent] then
	                    Removed(Ent)
	                end
	                Added(Ent)
	            end))
	            Chams:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
	                for Ent: any, v: any in Reference do
	                    local EntityColor: Color3 = Entity.getEntityColor(Ent) or Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
	                    if type(v) == "table" then
	                        for _, Adornment: Instance in v do
	                            Adornment.Color3 = EntityColor
	                        end
	                    else
	                        v.FillColor = EntityColor
	                    end
	                end
	            end))
	
	            for _, v: any in Entity.List do
	                if Reference[v] then
	                    Removed(v)
	                end
	                Added(v)
	            end
	        else
	            for Ent: any in Reference do
	                Removed(Ent)
	            end
	        end
	    end,
	    Tooltip = "Render players through walls"
	})
	
	Targets = Chams:CreateTargets({
	    Players = true,
	    Function = function()
	        if Chams.Enabled then
	            Chams:Toggle()
	            Chams:Toggle()
	        end
	    end
	})
	Mode = Chams:CreateDropdown({
	    Name = "Mode",
	    List = {"Highlight", "BoxHandles"},
	    Function = function(Val: string)
	        OutlineColor.Object.Visible = Val == "Highlight"
	        OutlineTransparency.Object.Visible = Val == "Highlight"
	        if Chams.Enabled then
	            Chams:Toggle()
	            Chams:Toggle()
	        end
	    end
	})
	FillColor = Chams:CreateColorSlider({
	    Name = "Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        for Ent: any, v: any in Reference do
	            local EntityColor: Color3 = Entity.getEntityColor(Ent) or Color3.fromHSV(Hue, Sat, Val)
	            if type(v) == "table" then
	                for _, Adornment: Instance in v do
	                    Adornment.Color3 = EntityColor
	                end
	            else
	                v.FillColor = EntityColor
	            end
	        end
	    end
	})
	OutlineColor = Chams:CreateColorSlider({
	    Name = "Outline Color",
	    DefaultSat = 0,
	    Function = function(Hue: number, Sat: number, Val: number)
	        for _, v: any in Reference do
	            if type(v) ~= "table" then
	                v.OutlineColor = Color3.fromHSV(Hue, Sat, Val)
	            end
	        end
	    end,
	    Darker = true
	})
	FillTransparency = Chams:CreateSlider({
	    Name = "Transparency",
	    Min = 0,
	    Max = 1,
	    Function = function(Val: number)
	        for _, v: any in Reference do
	            if type(v) == "table" then
	                for _, Adornment: Instance in v do
	                    Adornment.Transparency = Val
	                end
	            else
	                v.FillTransparency = Val
	            end
	        end
	    end,
	    Decimal = 10,
	    Default = 0.5
	})
	OutlineTransparency = Chams:CreateSlider({
	    Name = "Outline Transparency",
	    Min = 0,
	    Max = 1,
	    Function = function(Val: number)
	        for _, v: any in Reference do
	            if type(v) ~= "table" then
	                v.OutlineTransparency = Val
	            end
	        end
	    end,
	    Decimal = 10,
	    Default = 0.5,
	    Darker = true
	})
	Walls = Chams:CreateToggle({
	    Name = "Render Walls",
	    Function = function(Callback: boolean)
	        for _, v: any in Reference do
	            if type(v) == "table" then
	                for _, Adornment: Instance in v do
	                    Adornment.AlwaysOnTop = Callback
	                end
	            else
	                v.DepthMode = Enum.HighlightDepthMode[Callback and "AlwaysOnTop" or "Occluded"]
	            end
	        end
	    end,
	    Default = true
	})
	Teammates = Chams:CreateToggle({
	    Name = "Priority Only",
	    Function = function()
	        if Chams.Enabled then
	            Chams:Toggle()
	            Chams:Toggle()
	        end
	    end,
	    Default = true,
	    Tooltip = "Hides teammates & non targetable entities"
	})
end)

Run(function()
	local ESP
	local Targets
	local Color
	local Method
	local BoundingBox
	local Filled
	local HealthBar
	local Name
	local DisplayName
	local Background
	local Teammates
	local Distance
	local DistanceLimit
	local Reference = {}
	local Shown = setmetatable({}, {__mode = "k"})
	local MethodUsed: string
	
	local function ESPWorldToViewport(Position: Vector3): Vector2
	    local ViewportPoint: Vector3 = Camera:WorldToViewportPoint(Position)
	    return Vector2.new(ViewportPoint.X, ViewportPoint.Y)
	end
	
	local function SetVisible(Drawings, Visible: boolean)
	    if Shown[Drawings] == Visible then
	        return
	    end
	
	    Shown[Drawings] = Visible
	    for _, v: any in Drawings do
	        v.Visible = Visible
	    end
	end
	
	local ESPAdded = {
	    Drawing2D = function(Ent)
	        if not Targets.Players.Enabled and Ent.Player then
	            return
	        end
	        if not Targets.NPCs.Enabled and Ent.NPC then
	            return
	        end
	        if Teammates.Enabled and (not Ent.Targetable) and (not Ent.Friend) then
	            return
	        end
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	
	        local EntityESP = {}
	        EntityESP.Main = Drawing.new("Square")
	        EntityESP.Main.Transparency = BoundingBox.Enabled and 1 or 0
	        EntityESP.Main.ZIndex = 2
	        EntityESP.Main.Filled = false
	        EntityESP.Main.Thickness = 1
	        EntityESP.Main.Color = Entity.getEntityColor(Ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	
	        if BoundingBox.Enabled then
	            EntityESP.Border = Drawing.new("Square")
	            EntityESP.Border.Transparency = 0.35
	            EntityESP.Border.ZIndex = 1
	            EntityESP.Border.Thickness = 1
	            EntityESP.Border.Filled = false
	            EntityESP.Border.Color = Color3.new()
	            EntityESP.Border2 = Drawing.new("Square")
	            EntityESP.Border2.Transparency = 0.35
	            EntityESP.Border2.ZIndex = 1
	            EntityESP.Border2.Thickness = 1
	            EntityESP.Border2.Filled = Filled.Enabled
	            EntityESP.Border2.Color = Color3.new()
	        end
	
	        if HealthBar.Enabled then
	            EntityESP.HealthLine = Drawing.new("Line")
	            EntityESP.HealthLine.Thickness = 1
	            EntityESP.HealthLine.ZIndex = 2
	            EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(Ent.Health / Ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
	            EntityESP.HealthBorder = Drawing.new("Line")
	            EntityESP.HealthBorder.Thickness = 3
	            EntityESP.HealthBorder.Transparency = 0.35
	            EntityESP.HealthBorder.ZIndex = 1
	            EntityESP.HealthBorder.Color = Color3.new()
	        end
	
	        if Name.Enabled then
	            if Background.Enabled then
	                EntityESP.TextBKG = Drawing.new("Square")
	                EntityESP.TextBKG.Transparency = 0.35
	                EntityESP.TextBKG.ZIndex = 0
	                EntityESP.TextBKG.Thickness = 1
	                EntityESP.TextBKG.Filled = true
	                EntityESP.TextBKG.Color = Color3.new()
	            end
	            EntityESP.Drop = Drawing.new("Text")
	            EntityESP.Drop.Color = Color3.new()
	            EntityESP.Drop.Text = Ent.Player and `{Whitelist:tag(Ent.Player, true)}{DisplayName.Enabled and Ent.Player.DisplayName or Ent.Player.Name}` or Ent.Character.Name
	            EntityESP.Drop.ZIndex = 1
	            EntityESP.Drop.Center = true
	            EntityESP.Drop.Size = 20
	            EntityESP.Text = Drawing.new("Text")
	            EntityESP.Text.Text = EntityESP.Drop.Text
	            EntityESP.Text.ZIndex = 2
	            EntityESP.Text.Color = EntityESP.Main.Color
	            EntityESP.Text.Center = true
	            EntityESP.Text.Size = 20
	        end
	
	        Reference[Ent] = EntityESP
	    end,
	    Drawing3D = function(Ent)
	        if not Targets.Players.Enabled and Ent.Player then
	            return
	        end
	        if not Targets.NPCs.Enabled and Ent.NPC then
	            return
	        end
	        if Teammates.Enabled and (not Ent.Targetable) and (not Ent.Friend) then
	            return
	        end
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	
	        local EntityESP = {}
	        EntityESP.Line1 = Drawing.new("Line")
	        EntityESP.Line2 = Drawing.new("Line")
	        EntityESP.Line3 = Drawing.new("Line")
	        EntityESP.Line4 = Drawing.new("Line")
	        EntityESP.Line5 = Drawing.new("Line")
	        EntityESP.Line6 = Drawing.new("Line")
	        EntityESP.Line7 = Drawing.new("Line")
	        EntityESP.Line8 = Drawing.new("Line")
	        EntityESP.Line9 = Drawing.new("Line")
	        EntityESP.Line10 = Drawing.new("Line")
	        EntityESP.Line11 = Drawing.new("Line")
	        EntityESP.Line12 = Drawing.new("Line")
	
	        local EntityColor: Color3 = Entity.getEntityColor(Ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	        for _, v: any in EntityESP do
	            v.Thickness = 1
	            v.Color = EntityColor
	        end
	
	        Reference[Ent] = EntityESP
	    end,
	    DrawingSkeleton = function(Ent)
	        if not Targets.Players.Enabled and Ent.Player then
	            return
	        end
	        if not Targets.NPCs.Enabled and Ent.NPC then
	            return
	        end
	        if Teammates.Enabled and (not Ent.Targetable) and (not Ent.Friend) then
	            return
	        end
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	
	        local EntityESP = {}
	        EntityESP.Head = Drawing.new("Line")
	        EntityESP.HeadFacing = Drawing.new("Line")
	        EntityESP.Torso = Drawing.new("Line")
	        EntityESP.UpperTorso = Drawing.new("Line")
	        EntityESP.LowerTorso = Drawing.new("Line")
	        EntityESP.LeftArm = Drawing.new("Line")
	        EntityESP.RightArm = Drawing.new("Line")
	        EntityESP.LeftLeg = Drawing.new("Line")
	        EntityESP.RightLeg = Drawing.new("Line")
	
	        local EntityColor: Color3 = Entity.getEntityColor(Ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	        for _, v: any in EntityESP do
	            v.Thickness = 2
	            v.Color = EntityColor
	        end
	
	        Reference[Ent] = EntityESP
	    end
	}
	
	local ESPRemoved = {
	    Drawing2D = function(Ent)
	        local EntityESP = Reference[Ent]
	        if EntityESP then
	            if vape.ThreadFix then
	                setthreadidentity(8)
	            end
	
	            Reference[Ent] = nil
	            for _, v: any in EntityESP do
	                pcall(function()
	                    v.Visible = false
	                    v:Remove()
	                end)
	            end
	        end
	    end
	}
	ESPRemoved.Drawing3D = ESPRemoved.Drawing2D
	ESPRemoved.DrawingSkeleton = ESPRemoved.Drawing2D
	
	local ESPUpdated = {
	    Drawing2D = function(Ent)
	        local EntityESP = Reference[Ent]
	        if EntityESP then
	            if vape.ThreadFix then
	                setthreadidentity(8)
	            end
	
	            if EntityESP.HealthLine then
	                EntityESP.HealthLine.Color = Color3.fromHSV(math.clamp(Ent.Health / Ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
	            end
	
	            if EntityESP.Text then
	                local Text: string = Ent.Player and `{Whitelist:tag(Ent.Player, true)}{DisplayName.Enabled and Ent.Player.DisplayName or Ent.Player.Name}` or Ent.Character.Name
	                if EntityESP.Text.Text ~= Text then
	                    EntityESP.Text.Text = Text
	                    EntityESP.Drop.Text = Text
	                end
	            end
	        end
	    end
	}
	
	local ColorFunc = {
	    Drawing2D = function(Hue: number, Sat: number, Val: number)
	        local DefaultColor: Color3 = Color3.fromHSV(Hue, Sat, Val)
	        for Ent: any, v: any in Reference do
	            v.Main.Color = Entity.getEntityColor(Ent) or DefaultColor
	            if v.Text then
	                v.Text.Color = v.Main.Color
	            end
	        end
	    end,
	    Drawing3D = function(Hue: number, Sat: number, Val: number)
	        local DefaultColor: Color3 = Color3.fromHSV(Hue, Sat, Val)
	        for Ent: any, v: any in Reference do
	            local EntityColor: Color3 = Entity.getEntityColor(Ent) or DefaultColor
	            for _, Line: any in v do
	                Line.Color = EntityColor
	            end
	        end
	    end
	}
	ColorFunc.DrawingSkeleton = ColorFunc.Drawing3D
	
	local ESPLoop = {
	    Drawing2D = function()
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	
	        local LocalPosition = Entity.isAlive and Entity.character.RootPart.Position
	        local CameraLook: Vector3 = Camera.CFrame.LookVector
	
	        for Ent: any, v: any in Reference do
	            local RootPosition: Vector3 = Ent.RootPart.Position
	
	            if Distance.Enabled then
	                local EntityDistance: number = LocalPosition and (LocalPosition - RootPosition).Magnitude or math.huge
	                if EntityDistance < DistanceLimit.ValueMin or EntityDistance > DistanceLimit.ValueMax then
	                    SetVisible(v, false)
	                    continue
	                end
	            end
	
	            local RootPos, RootVisible = Camera:WorldToViewportPoint(RootPosition)
	            SetVisible(v, RootVisible)
	            if not RootVisible then
	                continue
	            end
	
	            local Facing: CFrame = CFrame.lookAlong(RootPosition, CameraLook)
	            local TopPos: Vector3 = Camera:WorldToViewportPoint((Facing * CFrame.new(2, Ent.HipHeight, 0)).p)
	            local BottomPos: Vector3 = Camera:WorldToViewportPoint((Facing * CFrame.new(-2, -Ent.HipHeight - 1, 0)).p)
	            local SizeX, SizeY = TopPos.X - BottomPos.X, TopPos.Y - BottomPos.Y
	            local PosX, PosY = (RootPos.X - SizeX / 2), ((RootPos.Y - SizeY / 2))
	            v.Main.Position = Vector2.new(PosX // 1, PosY // 1)
	            v.Main.Size = Vector2.new(SizeX // 1, SizeY // 1)
	            if v.Border then
	                v.Border.Position = Vector2.new((PosX - 1) // 1, (PosY + 1) // 1)
	                v.Border.Size = Vector2.new((SizeX + 2) // 1, (SizeY - 2) // 1)
	                v.Border2.Position = Vector2.new((PosX + 1) // 1, (PosY - 1) // 1)
	                v.Border2.Size = Vector2.new((SizeX - 2) // 1, (SizeY + 2) // 1)
	            end
	
	            if v.HealthLine then
	                local HealthY: number = SizeY * math.clamp(Ent.Health / Ent.MaxHealth, 0, 1)
	                local HealthX: number = (PosX - 6) // 1
	                v.HealthLine.Visible = Ent.Health > 0
	                v.HealthLine.From = Vector2.new(HealthX, (PosY + (SizeY - (SizeY - HealthY))) // 1)
	                v.HealthLine.To = Vector2.new(HealthX, PosY // 1)
	                v.HealthBorder.From = Vector2.new(HealthX, (PosY + 1) // 1)
	                v.HealthBorder.To = Vector2.new(HealthX, ((PosY + SizeY) - 1) // 1)
	            end
	
	            if v.Text then
	                v.Text.Position = Vector2.new((PosX + (SizeX / 2)) // 1, (PosY + (SizeY - 28)) // 1)
	                v.Drop.Position = v.Text.Position + Vector2.new(1, 1)
	                if v.TextBKG then
	                    v.TextBKG.Size = v.Text.TextBounds + Vector2.new(8, 4)
	                    v.TextBKG.Position = v.Text.Position - Vector2.new(4 + (v.Text.TextBounds.X / 2), 0)
	                end
	            end
	        end
	    end,
	    Drawing3D = function()
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	
	        local LocalPosition = Entity.isAlive and Entity.character.RootPart.Position
	
	        for Ent: any, v: any in Reference do
	            if Distance.Enabled then
	                local EntityDistance: number = LocalPosition and (LocalPosition - Ent.RootPart.Position).Magnitude or math.huge
	                if EntityDistance < DistanceLimit.ValueMin or EntityDistance > DistanceLimit.ValueMax then
	                    SetVisible(v, false)
	                    continue
	                end
	            end
	
	            local _, RootVisible = Camera:WorldToViewportPoint(Ent.RootPart.Position)
	            SetVisible(v, RootVisible)
	            if not RootVisible then
	                continue
	            end
	
	            local RootPosition: Vector3 = Ent.RootPart.Position
	            local Point1: Vector2 = ESPWorldToViewport(RootPosition + Vector3.new(1.5, Ent.HipHeight, 1.5))
	            local Point2: Vector2 = ESPWorldToViewport(RootPosition + Vector3.new(1.5, -Ent.HipHeight, 1.5))
	            local Point3: Vector2 = ESPWorldToViewport(RootPosition + Vector3.new(-1.5, Ent.HipHeight, 1.5))
	            local Point4: Vector2 = ESPWorldToViewport(RootPosition + Vector3.new(-1.5, -Ent.HipHeight, 1.5))
	            local Point5: Vector2 = ESPWorldToViewport(RootPosition + Vector3.new(1.5, Ent.HipHeight, -1.5))
	            local Point6: Vector2 = ESPWorldToViewport(RootPosition + Vector3.new(1.5, -Ent.HipHeight, -1.5))
	            local Point7: Vector2 = ESPWorldToViewport(RootPosition + Vector3.new(-1.5, Ent.HipHeight, -1.5))
	            local Point8: Vector2 = ESPWorldToViewport(RootPosition + Vector3.new(-1.5, -Ent.HipHeight, -1.5))
	            v.Line1.From = Point1
	            v.Line1.To = Point2
	            v.Line2.From = Point3
	            v.Line2.To = Point4
	            v.Line3.From = Point5
	            v.Line3.To = Point6
	            v.Line4.From = Point7
	            v.Line4.To = Point8
	            v.Line5.From = Point1
	            v.Line5.To = Point3
	            v.Line6.From = Point1
	            v.Line6.To = Point5
	            v.Line7.From = Point5
	            v.Line7.To = Point7
	            v.Line8.From = Point7
	            v.Line8.To = Point3
	            v.Line9.From = Point2
	            v.Line9.To = Point4
	            v.Line10.From = Point2
	            v.Line10.To = Point6
	            v.Line11.From = Point6
	            v.Line11.To = Point8
	            v.Line12.From = Point8
	            v.Line12.To = Point4
	        end
	    end,
	    DrawingSkeleton = function()
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	
	        local LocalPosition = Entity.isAlive and Entity.character.RootPart.Position
	
	        for Ent: any, v: any in Reference do
	            if Distance.Enabled then
	                local EntityDistance: number = LocalPosition and (LocalPosition - Ent.RootPart.Position).Magnitude or math.huge
	                if EntityDistance < DistanceLimit.ValueMin or EntityDistance > DistanceLimit.ValueMax then
	                    SetVisible(v, false)
	                    continue
	                end
	            end
	
	            local _, RootVisible = Camera:WorldToViewportPoint(Ent.RootPart.Position)
	            SetVisible(v, RootVisible)
	            if not RootVisible then
	                continue
	            end
	
	            local IsR6: boolean = Ent.Humanoid.RigType == Enum.HumanoidRigType.R6
	            pcall(function()
	                local Offset: CFrame = IsR6 and CFrame.new(0, -0.8, 0) or CFrame.identity
	                local HeadPos: Vector2 = ESPWorldToViewport((Ent.Head.CFrame).p)
	                local HeadFront: Vector2 = ESPWorldToViewport((Ent.Head.CFrame * CFrame.new(0, 0, -0.5)).p)
	                local TopLeftTorso: Vector2 = ESPWorldToViewport((Ent.Character[(IsR6 and "Torso" or "UpperTorso")].CFrame * CFrame.new(-1.5, 0.8, 0)).p)
	                local TopRightTorso: Vector2 = ESPWorldToViewport((Ent.Character[(IsR6 and "Torso" or "UpperTorso")].CFrame * CFrame.new(1.5, 0.8, 0)).p)
	                local TopTorso: Vector2 = ESPWorldToViewport((Ent.Character[(IsR6 and "Torso" or "UpperTorso")].CFrame * CFrame.new(0, 0.8, 0)).p)
	                local BottomTorso: Vector2 = ESPWorldToViewport((Ent.Character[(IsR6 and "Torso" or "UpperTorso")].CFrame * CFrame.new(0, -0.8, 0)).p)
	                local BottomLeftTorso: Vector2 = ESPWorldToViewport((Ent.Character[(IsR6 and "Torso" or "UpperTorso")].CFrame * CFrame.new(-0.5, -0.8, 0)).p)
	                local BottomRightTorso: Vector2 = ESPWorldToViewport((Ent.Character[(IsR6 and "Torso" or "UpperTorso")].CFrame * CFrame.new(0.5, -0.8, 0)).p)
	                local LeftArm: Vector2 = ESPWorldToViewport((Ent.Character[(IsR6 and "Left Arm" or "LeftHand")].CFrame * Offset).p)
	                local RightArm: Vector2 = ESPWorldToViewport((Ent.Character[(IsR6 and "Right Arm" or "RightHand")].CFrame * Offset).p)
	                local LeftLeg: Vector2 = ESPWorldToViewport((Ent.Character[(IsR6 and "Left Leg" or "LeftFoot")].CFrame * Offset).p)
	                local RightLeg: Vector2 = ESPWorldToViewport((Ent.Character[(IsR6 and "Right Leg" or "RightFoot")].CFrame * Offset).p)
	                v.Head.From = TopTorso
	                v.Head.To = HeadPos
	                v.HeadFacing.From = HeadPos
	                v.HeadFacing.To = HeadFront
	                v.UpperTorso.From = TopLeftTorso
	                v.UpperTorso.To = TopRightTorso
	                v.Torso.From = TopTorso
	                v.Torso.To = BottomTorso
	                v.LowerTorso.From = BottomLeftTorso
	                v.LowerTorso.To = BottomRightTorso
	                v.LeftArm.From = TopLeftTorso
	                v.LeftArm.To = LeftArm
	                v.RightArm.From = TopRightTorso
	                v.RightArm.To = RightArm
	                v.LeftLeg.From = BottomLeftTorso
	                v.LeftLeg.To = LeftLeg
	                v.RightLeg.From = BottomRightTorso
	                v.RightLeg.To = RightLeg
	            end)
	        end
	    end
	}
	
	ESP = vape.Categories.Render:CreateModule({
	    Name = "ESP",
	    Function = function(Callback: boolean)
	        if Callback then
	            MethodUsed = `Drawing{Method.Value}`
	            if ESPRemoved[MethodUsed] then
	                ESP:Clean(Entity.Events.EntityRemoved:Connect(ESPRemoved[MethodUsed]))
	            end
	
	            if ESPAdded[MethodUsed] then
	                for _, v: any in Entity.List do
	                    if Reference[v] then
	                        ESPRemoved[MethodUsed](v)
	                    end
	                    ESPAdded[MethodUsed](v)
	                end
	                ESP:Clean(Entity.Events.EntityAdded:Connect(function(Ent)
	                    if Reference[Ent] then
	                        ESPRemoved[MethodUsed](Ent)
	                    end
	                    ESPAdded[MethodUsed](Ent)
	                end))
	            end
	
	            if ESPUpdated[MethodUsed] then
	                ESP:Clean(Entity.Events.EntityUpdated:Connect(ESPUpdated[MethodUsed]))
	                for _, v: any in Entity.List do
	                    ESPUpdated[MethodUsed](v)
	                end
	            end
	
	            if ColorFunc[MethodUsed] then
	                ESP:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
	                    ColorFunc[MethodUsed](Color.Hue, Color.Sat, Color.Value)
	                end))
	            end
	
	            if ESPLoop[MethodUsed] then
	                ESP:Clean(RunService.RenderStepped:Connect(ESPLoop[MethodUsed]))
	            end
	        else
	            if ESPRemoved[MethodUsed] then
	                for Ent: any in Reference do
	                    ESPRemoved[MethodUsed](Ent)
	                end
	            end
	        end
	    end,
	    Tooltip = "Extra Sensory Perception\nRenders an ESP on players."
	})
	
	Targets = ESP:CreateTargets({
	    Players = true,
	    Function = function()
	        if ESP.Enabled then
	            ESP:Toggle()
	            ESP:Toggle()
	        end
	    end
	})
	Method = ESP:CreateDropdown({
	    Name = "Mode",
	    List = {"2D", "3D", "Skeleton"},
	    Function = function(Val: string)
	        if ESP.Enabled then
	            ESP:Toggle()
	            ESP:Toggle()
	        end
	        BoundingBox.Object.Visible = (Val == "2D")
	        Filled.Object.Visible = (Val == "2D")
	        HealthBar.Object.Visible = (Val == "2D")
	        Name.Object.Visible = (Val == "2D")
	        DisplayName.Object.Visible = Name.Object.Visible and Name.Enabled
	        Background.Object.Visible = Name.Object.Visible and Name.Enabled
	    end
	})
	Color = ESP:CreateColorSlider({
	    Name = "Player Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        if ESP.Enabled and ColorFunc[MethodUsed] then
	            ColorFunc[MethodUsed](Hue, Sat, Val)
	        end
	    end
	})
	BoundingBox = ESP:CreateToggle({
	    Name = "Bounding Box",
	    Function = function()
	        if ESP.Enabled then
	            ESP:Toggle()
	            ESP:Toggle()
	        end
	    end,
	    Default = true,
	    Darker = true
	})
	Filled = ESP:CreateToggle({
	    Name = "Filled",
	    Function = function()
	        if ESP.Enabled then
	            ESP:Toggle()
	            ESP:Toggle()
	        end
	    end,
	    Darker = true
	})
	HealthBar = ESP:CreateToggle({
	    Name = "Health Bar",
	    Function = function()
	        if ESP.Enabled then
	            ESP:Toggle()
	            ESP:Toggle()
	        end
	    end,
	    Darker = true
	})
	Name = ESP:CreateToggle({
	    Name = "Name",
	    Function = function(Callback: boolean)
	        if ESP.Enabled then
	            ESP:Toggle()
	            ESP:Toggle()
	        end
	        DisplayName.Object.Visible = Callback
	        Background.Object.Visible = Callback
	    end,
	    Darker = true
	})
	DisplayName = ESP:CreateToggle({
	    Name = "Use Displayname",
	    Function = function()
	        if ESP.Enabled then
	            ESP:Toggle()
	            ESP:Toggle()
	        end
	    end,
	    Default = true,
	    Darker = true
	})
	Background = ESP:CreateToggle({
	    Name = "Show Background",
	    Function = function()
	        if ESP.Enabled then
	            ESP:Toggle()
	            ESP:Toggle()
	        end
	    end,
	    Darker = true
	})
	Teammates = ESP:CreateToggle({
	    Name = "Priority Only",
	    Function = function()
	        if ESP.Enabled then
	            ESP:Toggle()
	            ESP:Toggle()
	        end
	    end,
	    Default = true,
	    Tooltip = "Hides teammates & non targetable entities"
	})
	Distance = ESP:CreateToggle({
	    Name = "Distance Check",
	    Function = function(Callback: boolean)
	        DistanceLimit.Object.Visible = Callback
	    end
	})
	DistanceLimit = ESP:CreateTwoSlider({
	    Name = "Player Distance",
	    Min = 0,
	    Max = 256,
	    DefaultMin = 0,
	    DefaultMax = 64,
	    Darker = true,
	    Visible = false
	})
end)

Run(function()
	local Fullbright
	local Mode
	local OldSettings = {}
	local Flag: boolean?
	
	local function ChangeLighting(Property: string?)
	    if Flag then
	        return
	    end
	
	    Flag = true
	    Lighting.Ambient = Color3.new(1, 1, 1)
	    Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
	    Lighting.Brightness = 3
	    RunService.RenderStepped:Wait()
	    Flag = false
	end
	
	Fullbright = vape.Categories.Render:CreateModule({
	    Name = "Fullbright",
	    Function = function(Callback: boolean)
	        if Callback then
	            if Mode.Value == "Lighting" then
	                for _, v: string in {"Ambient", "OutdoorAmbient", "Brightness"} do
	                    OldSettings[v] = Lighting[v]
	                end
	
	                Fullbright:Clean(Lighting.Changed:Connect(ChangeLighting))
	                task.spawn(ChangeLighting)
	            else
	                local Light: PointLight = Instance.new("PointLight")
	                Light.Range = 1000
	                Fullbright:Clean(Light)
	
	                repeat
	                    Light.Parent = Entity.isAlive and Entity.character.RootPart or nil
	                    task.wait(0.1)
	                until not Fullbright.Enabled
	            end
	        else
	            Flag = false
	            for Property: string, v: any in OldSettings do
	                Lighting[Property] = v
	            end
	            table.clear(OldSettings)
	        end
	    end,
	    Tooltip = "Increase the lighting of the world around you."
	})
	
	Mode = Fullbright:CreateDropdown({
	    Name = "Mode",
	    List = {"Lighting", "PointLight"},
	    Function = function()
	        if Fullbright.Enabled then
	            Fullbright:Toggle()
	            Fullbright:Toggle()
	        end
	    end
	})
end)

Run(function()
	local GamingChair = {Enabled = false}
	local Color
	local WheelPositions: {Vector3} = {
	    Vector3.new(-0.8, -0.6, -0.18),
	    Vector3.new(0.1, -0.6, -0.88),
	    Vector3.new(0, -0.6, 0.7)
	}
	local ChairHighlight: Highlight?
	local CurrentTween: Tween?
	local MovingSound: Sound?
	local FlyingSound: Sound?
	local ChairAnimation
	local Chair: MeshPart?
	
	GamingChair = vape.Categories.Render:CreateModule({
	    Name = "GamingChair",
	    Function = function(Callback: boolean)
	        if Callback then
	            if vape.ThreadFix then
	                setthreadidentity(8)
	            end
	            Chair = Instance.new("MeshPart")
	            Chair.Color = Color3.fromRGB(21, 21, 21)
	            Chair.Size = Vector3.new(2.16, 3.6, 2.3) / Vector3.new(12.37, 20.636, 13.071)
	            Chair.CanCollide = false
	            Chair.Massless = true
	            Chair.MeshId = "rbxassetid://12972961089"
	            Chair.Material = Enum.Material.SmoothPlastic
	            Chair.Parent = workspace
	            MovingSound = Instance.new("Sound")
	            MovingSound.Volume = 0.4
	            MovingSound.Looped = true
	            MovingSound.Parent = workspace
	            FlyingSound = Instance.new("Sound")
	            FlyingSound.Volume = 0.4
	            FlyingSound.Looped = true
	            FlyingSound.Parent = workspace
	            local ChairWeld: WeldConstraint = Instance.new("WeldConstraint")
	            ChairWeld.Part0 = Chair
	            ChairWeld.Parent = Chair
	            if Entity.isAlive then
	                Chair.CFrame = Entity.character.RootPart.CFrame * CFrame.Angles(0, math.rad(-90), 0)
	                ChairWeld.Part1 = Entity.character.RootPart
	            end
	            ChairHighlight = Instance.new("Highlight")
	            ChairHighlight.FillTransparency = 1
	            ChairHighlight.OutlineColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	            ChairHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	            ChairHighlight.OutlineTransparency = 0.2
	            ChairHighlight.Parent = Chair
	            local ChairArms: MeshPart = Instance.new("MeshPart")
	            ChairArms.Color = Chair.Color
	            ChairArms.Size = Vector3.new(1.39, 1.345, 2.75) / Vector3.new(97.13, 136.216, 234.031)
	            ChairArms.CFrame = Chair.CFrame * CFrame.new(-0.169, -1.129, -0.013)
	            ChairArms.MeshId = "rbxassetid://12972673898"
	            ChairArms.CanCollide = false
	            ChairArms.Parent = Chair
	            local ChairArmsWeld: WeldConstraint = Instance.new("WeldConstraint")
	            ChairArmsWeld.Part0 = ChairArms
	            ChairArmsWeld.Part1 = Chair
	            ChairArmsWeld.Parent = Chair
	            local ChairLegs: MeshPart = Instance.new("MeshPart")
	            ChairLegs.Color = Chair.Color
	            ChairLegs.Name = "Legs"
	            ChairLegs.Size = Vector3.new(1.8, 1.2, 1.8) / Vector3.new(10.432, 8.105, 9.488)
	            ChairLegs.CFrame = Chair.CFrame * CFrame.new(0.047, -2.324, 0)
	            ChairLegs.MeshId = "rbxassetid://13003181606"
	            ChairLegs.CanCollide = false
	            ChairLegs.Parent = Chair
	            local ChairFan: MeshPart = Instance.new("MeshPart")
	            ChairFan.Color = Chair.Color
	            ChairFan.Name = "Fan"
	            ChairFan.Size = Vector3.zero
	            ChairFan.CFrame = Chair.CFrame * CFrame.new(0, -1.873, 0)
	            ChairFan.MeshId = "rbxassetid://13004977292"
	            ChairFan.CanCollide = false
	            ChairFan.Parent = Chair
	            local Trails: {Trail} = {}
	            for _, v: Vector3 in WheelPositions do
	                local StartAttachment: Attachment = Instance.new("Attachment")
	                StartAttachment.Position = v
	                StartAttachment.Parent = ChairLegs
	                local EndAttachment: Attachment = Instance.new("Attachment")
	                EndAttachment.Position = v + Vector3.new(0, 0, 0.18)
	                EndAttachment.Parent = ChairLegs
	                local Trail: Trail = Instance.new("Trail")
	                Trail.Texture = "http://www.roblox.com/asset/?id=13005168530"
	                Trail.TextureMode = Enum.TextureMode.Static
	                Trail.Transparency = NumberSequence.new(0.5)
	                Trail.Color = ColorSequence.new(Color3.new(0.5, 0.5, 0.5))
	                Trail.Attachment0 = StartAttachment
	                Trail.Attachment1 = EndAttachment
	                Trail.Lifetime = 20
	                Trail.MaxLength = 60
	                Trail.MinLength = 0.1
	                Trail.Parent = ChairLegs
	                table.insert(Trails, Trail)
	            end
	            GamingChair:Clean(Chair)
	            GamingChair:Clean(MovingSound)
	            GamingChair:Clean(FlyingSound)
	            ChairAnimation = {Stop = function() end}
	            local OldMoving: boolean = false
	            local OldFlying: boolean = false
	            repeat
	                if Entity.isAlive and Entity.character.Humanoid.Health > 0 then
	                    if not ChairAnimation.IsPlaying then
	                        local Animation: Animation = Instance.new("Animation")
	                        Animation.AnimationId = Entity.character.Humanoid.RigType == Enum.HumanoidRigType.R15 and "http://www.roblox.com/asset/?id=2506281703" or "http://www.roblox.com/asset/?id=178130996"
	                        ChairAnimation = Entity.character.Humanoid:LoadAnimation(Animation)
	                        ChairAnimation.Priority = Enum.AnimationPriority.Movement
	                        ChairAnimation.Looped = true
	                        ChairAnimation:Play()
	                    end
	                    Chair.CFrame = Entity.character.RootPart.CFrame * CFrame.Angles(0, math.rad(-90), 0)
	                    ChairWeld.Part1 = Entity.character.RootPart
	                    ChairLegs.AssemblyLinearVelocity = Vector3.zero
	                    ChairLegs.CFrame = Chair.CFrame * CFrame.new(0.047, -2.324, 0)
	                    ChairFan.AssemblyLinearVelocity = Vector3.zero
	                    ChairFan.CFrame = Chair.CFrame * CFrame.new(0.047, -1.873, 0) * CFrame.Angles(0, math.rad(tick() * 180 % 360), math.rad(180))
	                    local Moving: boolean = Entity.character.Humanoid:GetState() == Enum.HumanoidStateType.Running and Entity.character.Humanoid.MoveDirection ~= Vector3.zero
	                    local Flying = vape.Modules.Fly and vape.Modules.Fly.Enabled or vape.Modules.LongJump and vape.Modules.LongJump.Enabled or (vape.Modules.InfiniteFly or {}).Enabled
	                    if MovingSound.TimePosition > 1.9 then
	                        MovingSound.TimePosition = 0.2
	                    end
	                    MovingSound.PlaybackSpeed = (Entity.character.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude / 16
	                    for _, v: Trail in Trails do
	                        v.Enabled = not Flying and Moving
	                        v.Color = ColorSequence.new(MovingSound.PlaybackSpeed > 1.5 and Color3.new(1, 0.5, 0) or Color3.new())
	                    end
	                    if Moving ~= OldMoving then
	                        if MovingSound.IsPlaying then
	                            if not Moving then
	                                MovingSound:Stop()
	                            end
	                        else
	                            if not Flying and Moving then
	                                MovingSound:Play()
	                            end
	                        end
	                        OldMoving = Moving
	                    end
	                    if Flying ~= OldFlying then
	                        if Flying then
	                            if MovingSound.IsPlaying then
	                                MovingSound:Stop()
	                            end
	                            if not FlyingSound.IsPlaying then
	                                FlyingSound:Play()
	                            end
	                            if CurrentTween then
	                                CurrentTween:Cancel()
	                            end
	                            CurrentTween = TweenService:Create(ChairLegs, TweenInfo.new(0.15), {
	                                Size = Vector3.zero
	                            })
	                            CurrentTween.Completed:Connect(function(State: Enum.PlaybackState)
	                                if State == Enum.PlaybackState.Completed then
	                                    ChairFan.Transparency = 0
	                                    ChairLegs.Transparency = 1
	                                    CurrentTween = TweenService:Create(ChairFan, TweenInfo.new(0.15), {
	                                        Size = Vector3.new(1.534, 0.328, 1.537) / Vector3.new(791.138, 168.824, 792.027)
	                                    })
	                                    CurrentTween:Play()
	                                end
	                            end)
	                            CurrentTween:Play()
	                        else
	                            if FlyingSound.IsPlaying then
	                                FlyingSound:Stop()
	                            end
	                            if not MovingSound.IsPlaying and Moving then
	                                MovingSound:Play()
	                            end
	                            if CurrentTween then
	                                CurrentTween:Cancel()
	                            end
	                            CurrentTween = TweenService:Create(ChairFan, TweenInfo.new(0.15), {
	                                Size = Vector3.zero
	                            })
	                            CurrentTween.Completed:Connect(function(State: Enum.PlaybackState)
	                                if State == Enum.PlaybackState.Completed then
	                                    ChairFan.Transparency = 1
	                                    ChairLegs.Transparency = 0
	                                    CurrentTween = TweenService:Create(ChairLegs, TweenInfo.new(0.15), {
	                                        Size = Vector3.new(1.8, 1.2, 1.8) / Vector3.new(10.432, 8.105, 9.488)
	                                    })
	                                    CurrentTween:Play()
	                                end
	                            end)
	                            CurrentTween:Play()
	                        end
	                        OldFlying = Flying
	                    end
	                else
	                    Chair.Anchored = true
	                    ChairLegs.Anchored = true
	                    ChairFan.Anchored = true
	                    repeat
	                        task.wait()
	                    until Entity.isAlive and Entity.character.Humanoid.Health > 0
	                    Chair.Anchored = false
	                    ChairLegs.Anchored = false
	                    ChairFan.Anchored = false
	                    ChairAnimation:Stop()
	                end
	                task.wait()
	            until not GamingChair.Enabled
	        else
	            if ChairAnimation then
	                ChairAnimation:Stop()
	            end
	        end
	    end,
	    Tooltip = "Sit in the best gaming chair known to mankind."
	})
	
	Color = GamingChair:CreateColorSlider({
	    Name = "Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        if ChairHighlight then
	            ChairHighlight.OutlineColor = Color3.fromHSV(Hue, Sat, Val)
	        end
	    end
	})
end)

Run(function()
	local Health
	
	Health = vape.Categories.Render:CreateModule({
	    Name = "Health",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Label: TextLabel = Instance.new("TextLabel")
	            Label.Size = UDim2.fromOffset(100, 20)
	            Label.Position = UDim2.new(0.5, 6, 0.5, 30)
	            Label.AnchorPoint = Vector2.new(0.5, 0)
	            Label.BackgroundTransparency = 1
	            Label.Text = "100 ❤️"
	            Label.TextSize = 18
	            Label.Font = Enum.Font.Arial
	            Label.Parent = vape.gui
	            Health:Clean(Label)
	
	            repeat
	                Label.Text = Entity.isAlive and `{math.round(Entity.character.Humanoid.Health)} ❤️` or ""
	                Label.TextColor3 = Entity.isAlive and Color3.fromHSV((Entity.character.Humanoid.Health / Entity.character.Humanoid.MaxHealth) / 2.8, 0.86, 1) or Color3.new()
	                task.wait()
	            until not Health.Enabled
	        end
	    end,
	    Tooltip = "Displays your health in the center of your screen."
	})
end)

Run(function()
	local MotionBlur
	local Turning
	local Movement
	local Maximum
	local Smoothing
	
	MotionBlur = vape.Categories.Render:CreateModule({
	    Name = "MotionBlur",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Blur: BlurEffect = Instance.new("BlurEffect")
	            Blur.Size = 0
	            Blur.Parent = Lighting
	            vape.BlurEffects = vape.BlurEffects or {}
	            table.insert(vape.BlurEffects, Blur)
	            MotionBlur:Clean(Blur)
	            MotionBlur:Clean(function()
	                local Index: number? = table.find(vape.BlurEffects, Blur)
	                if Index then
	                    table.remove(vape.BlurEffects, Index)
	                end
	            end)
	
	            local LastLook, LastPosition, Size = Camera.CFrame.LookVector, Camera.CFrame.Position, 0
	            MotionBlur:Clean(RunService.RenderStepped:Connect(function(Delta: number)
	                local CameraCFrame: CFrame = Camera.CFrame
	                local Step: number = math.max(Delta, 1 / 240)
	                local Turn: number = math.deg(math.acos(math.clamp(CameraCFrame.LookVector:Dot(LastLook), -1, 1))) / Step
	                local Travel: number = (CameraCFrame.Position - LastPosition).Magnitude / Step
	                LastLook, LastPosition = CameraCFrame.LookVector, CameraCFrame.Position
	
	                local Target: number = math.min((Turn * Turning.Value * 0.002) + (Travel * Movement.Value * 0.002), Maximum.Value)
	                Size += (Target - Size) * math.clamp(Step * Smoothing.Value, 0, 1)
	                Blur.Size = Size
	            end))
	        end
	    end,
	    Tooltip = "Blurs the screen based on how fast you are turning and moving."
	})
	
	Turning = MotionBlur:CreateSlider({
	    Name = "Turn amount",
	    Min = 0,
	    Max = 10,
	    Default = 4,
	    Decimal = 10,
	    Tooltip = "How much your camera turning adds to the blur"
	})
	Movement = MotionBlur:CreateSlider({
	    Name = "Movement amount",
	    Min = 0,
	    Max = 10,
	    Default = 2,
	    Decimal = 10,
	    Tooltip = "How much your own speed adds to the blur"
	})
	Maximum = MotionBlur:CreateSlider({
	    Name = "Max blur",
	    Min = 1,
	    Max = 56,
	    Default = 14
	})
	Smoothing = MotionBlur:CreateSlider({
	    Name = "Smoothing",
	    Min = 1,
	    Max = 30,
	    Default = 12,
	    Tooltip = "How fast the blur catches up, lower trails behind for longer"
	})
end)

Run(function()
	local NameTags
	local Targets
	local Color
	local Background
	local Stroke
	local DisplayName
	local Health
	local Distance
	local DrawingToggle
	local Scale
	local FontOption
	local Teammates
	local DistanceCheck
	local DistanceLimit
	local Strings, Sizes, Reference = {}, {}, {}
	local Folder: Folder = Instance.new("Folder")
	if vape.ThreadFix then
	    setthreadidentity(8)
	end
	Folder.Parent = vape.gui
	local MethodUsed: string
	
	local Added = {
	    Normal = function(Ent)
	        if not Targets.Players.Enabled and Ent.Player then
	            return
	        end
	        if not Targets.NPCs.Enabled and Ent.NPC then
	            return
	        end
	        if Teammates.Enabled and (not Ent.Targetable) and (not Ent.Friend) then
	            return
	        end
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	
	        Strings[Ent] = Ent.Player and `{Whitelist:tag(Ent.Player, true, true)}{DisplayName.Enabled and Ent.Player.DisplayName or Ent.Player.Name}` or Ent.Character.Name
	
	        if Health.Enabled then
	            local HealthColor: Color3 = Color3.fromHSV(math.clamp(Ent.Health / Ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
	            Strings[Ent] = `{Strings[Ent]} <font color="rgb({math.floor(HealthColor.R * 255)},{math.floor(HealthColor.G * 255)},{math.floor(HealthColor.B * 255)})">{math.round(Ent.Health)}</font>`
	        end
	
	        if Distance.Enabled then
	            Strings[Ent] = `<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> {Strings[Ent]}`
	        end
	
	        local NameTag: TextLabel = Instance.new("TextLabel")
	        NameTag.TextSize = 14 * Scale.Value
	        NameTag.FontFace = FontOption.Value
	        local Size: Vector2 = GetFontBounds(RemoveTags(Strings[Ent]), NameTag.TextSize, NameTag.FontFace)
	        NameTag.Name = Ent.Player and Ent.Player.Name or Ent.Character.Name
	        NameTag.Size = UDim2.fromOffset(Size.X + 8, Size.Y + 7)
	        NameTag.AnchorPoint = Vector2.new(0.5, 1)
	        NameTag.BackgroundColor3 = Color3.new()
	        NameTag.BackgroundTransparency = Background.Value
	        NameTag.TextStrokeTransparency = Stroke.Value
	        NameTag.BorderSizePixel = 0
	        NameTag.Visible = false
	        NameTag.Text = Strings[Ent]
	        NameTag.TextColor3 = Entity.getEntityColor(Ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	        NameTag.RichText = true
	        NameTag.Parent = Folder
	        Reference[Ent] = NameTag
	    end,
	    Drawing = function(Ent)
	        if not Targets.Players.Enabled and Ent.Player then
	            return
	        end
	        if not Targets.NPCs.Enabled and Ent.NPC then
	            return
	        end
	        if Teammates.Enabled and (not Ent.Targetable) and (not Ent.Friend) then
	            return
	        end
	
	        local NameTag = {}
	        NameTag.BG = Drawing.new("Square")
	        NameTag.BG.Filled = true
	        NameTag.BG.Transparency = 1 - Background.Value
	        NameTag.BG.Color = Color3.new()
	        NameTag.BG.ZIndex = 1
	        NameTag.Text = Drawing.new("Text")
	        NameTag.Text.Size = 15 * Scale.Value
	        NameTag.Text.Font = 0
	        NameTag.Text.ZIndex = 2
	        Strings[Ent] = Ent.Player and `{Whitelist:tag(Ent.Player, true)}{DisplayName.Enabled and Ent.Player.DisplayName or Ent.Player.Name}` or Ent.Character.Name
	
	        if Health.Enabled then
	            Strings[Ent] = `{Strings[Ent]} {math.round(Ent.Health)}`
	        end
	
	        if Distance.Enabled then
	            Strings[Ent] = `[%s] {Strings[Ent]}`
	        end
	
	        NameTag.Text.Text = Strings[Ent]
	        NameTag.Text.Color = Entity.getEntityColor(Ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	        NameTag.BG.Size = Vector2.new(NameTag.Text.TextBounds.X + 8, NameTag.Text.TextBounds.Y + 7)
	        Reference[Ent] = NameTag
	    end
	}
	
	local Removed = {
	    Normal = function(Ent)
	        local NameTag = Reference[Ent]
	        if NameTag then
	            if vape.ThreadFix then
	                setthreadidentity(8)
	            end
	            Reference[Ent] = nil
	            Strings[Ent] = nil
	            Sizes[Ent] = nil
	            NameTag:Destroy()
	        end
	    end,
	    Drawing = function(Ent)
	        local NameTag = Reference[Ent]
	        if NameTag then
	            if vape.ThreadFix then
	                setthreadidentity(8)
	            end
	            Reference[Ent] = nil
	            Strings[Ent] = nil
	            Sizes[Ent] = nil
	            for _, v: any in NameTag do
	                pcall(function()
	                    v.Visible = false
	                    v:Remove()
	                end)
	            end
	        end
	    end
	}
	
	local Updated = {
	    Normal = function(Ent)
	        local NameTag = Reference[Ent]
	        if NameTag then
	            if vape.ThreadFix then
	                setthreadidentity(8)
	            end
	            Sizes[Ent] = nil
	            Strings[Ent] = Ent.Player and `{Whitelist:tag(Ent.Player, true, true)}{DisplayName.Enabled and Ent.Player.DisplayName or Ent.Player.Name}` or Ent.Character.Name
	
	            if Health.Enabled then
	                local HealthColor: Color3 = Color3.fromHSV(math.clamp(Ent.Health / Ent.MaxHealth, 0, 1) / 2.5, 0.89, 0.75)
	                Strings[Ent] = `{Strings[Ent]} <font color="rgb({math.floor(HealthColor.R * 255)},{math.floor(HealthColor.G * 255)},{math.floor(HealthColor.B * 255)})">{math.round(Ent.Health)}</font>`
	            end
	
	            if Distance.Enabled then
	                Strings[Ent] = `<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">%s</font><font color="rgb(85, 255, 85)">]</font> {Strings[Ent]}`
	            end
	
	            local Size: Vector2 = GetFontBounds(RemoveTags(Strings[Ent]), NameTag.TextSize, NameTag.FontFace)
	            NameTag.Size = UDim2.fromOffset(Size.X + 8, Size.Y + 7)
	            NameTag.Text = Strings[Ent]
	        end
	    end,
	    Drawing = function(Ent)
	        local NameTag = Reference[Ent]
	        if NameTag then
	            if vape.ThreadFix then
	                setthreadidentity(8)
	            end
	            Sizes[Ent] = nil
	            Strings[Ent] = Ent.Player and `{Whitelist:tag(Ent.Player, true)}{DisplayName.Enabled and Ent.Player.DisplayName or Ent.Player.Name}` or Ent.Character.Name
	
	            if Health.Enabled then
	                Strings[Ent] = `{Strings[Ent]} {math.round(Ent.Health)}`
	            end
	
	            if Distance.Enabled then
	                Strings[Ent] = `[%s] {Strings[Ent]}`
	                NameTag.Text.Text = Entity.isAlive and string.format(Strings[Ent], math.floor((Entity.character.RootPart.Position - Ent.RootPart.Position).Magnitude)) or Strings[Ent]
	            else
	                NameTag.Text.Text = Strings[Ent]
	            end
	
	            NameTag.BG.Size = Vector2.new(NameTag.Text.TextBounds.X + 8, NameTag.Text.TextBounds.Y + 7)
	            NameTag.Text.Color = Entity.getEntityColor(Ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	        end
	    end
	}
	
	local ColorFunc = {
	    Normal = function(Hue: number, Sat: number, Val: number)
	        local DefaultColor: Color3 = Color3.fromHSV(Hue, Sat, Val)
	        for Ent: any, v: TextLabel in Reference do
	            v.TextColor3 = Entity.getEntityColor(Ent) or DefaultColor
	        end
	    end,
	    Drawing = function(Hue: number, Sat: number, Val: number)
	        local DefaultColor: Color3 = Color3.fromHSV(Hue, Sat, Val)
	        for Ent: any, v: any in Reference do
	            v.Text.Color = Entity.getEntityColor(Ent) or DefaultColor
	        end
	    end
	}
	
	local Loop = {
	    Normal = function()
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	
	        local LocalPosition = Entity.isAlive and Entity.character.RootPart.Position
	
	        for Ent: any, v: TextLabel in Reference do
	            local RootPosition: Vector3 = Ent.RootPart.Position
	
	            if DistanceCheck.Enabled then
	                local EntityDistance: number = LocalPosition and (LocalPosition - RootPosition).Magnitude or math.huge
	                if EntityDistance < DistanceLimit.ValueMin or EntityDistance > DistanceLimit.ValueMax then
	                    v.Visible = false
	                    continue
	                end
	            end
	
	            local HeadPos, HeadVisible = Camera:WorldToViewportPoint(RootPosition + Vector3.new(0, Ent.HipHeight + 1, 0))
	            v.Visible = HeadVisible
	            if not HeadVisible then
	                continue
	            end
	
	            if Distance.Enabled then
	                local Magnitude: number = LocalPosition and math.floor((LocalPosition - RootPosition).Magnitude) or 0
	                if Sizes[Ent] ~= Magnitude then
	                    v.Text = string.format(Strings[Ent], Magnitude)
	                    local Bounds: Vector2 = GetFontBounds(RemoveTags(v.Text), v.TextSize, v.FontFace)
	                    v.Size = UDim2.fromOffset(Bounds.X + 8, Bounds.Y + 7)
	                    Sizes[Ent] = Magnitude
	                end
	            end
	            v.Position = UDim2.fromOffset(HeadPos.X, HeadPos.Y)
	        end
	    end,
	    Drawing = function()
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	
	        local LocalPosition = Entity.isAlive and Entity.character.RootPart.Position
	
	        for Ent: any, v: any in Reference do
	            local RootPosition: Vector3 = Ent.RootPart.Position
	
	            if DistanceCheck.Enabled then
	                local EntityDistance: number = LocalPosition and (LocalPosition - RootPosition).Magnitude or math.huge
	                if EntityDistance < DistanceLimit.ValueMin or EntityDistance > DistanceLimit.ValueMax then
	                    v.Text.Visible = false
	                    v.BG.Visible = false
	                    continue
	                end
	            end
	
	            local HeadPos, HeadVisible = Camera:WorldToViewportPoint(RootPosition + Vector3.new(0, Ent.HipHeight + 1, 0))
	            v.Text.Visible = HeadVisible
	            v.BG.Visible = HeadVisible
	            if not HeadVisible then
	                continue
	            end
	
	            if Distance.Enabled then
	                local Magnitude: number = LocalPosition and math.floor((LocalPosition - RootPosition).Magnitude) or 0
	                if Sizes[Ent] ~= Magnitude then
	                    v.Text.Text = string.format(Strings[Ent], Magnitude)
	                    v.BG.Size = Vector2.new(v.Text.TextBounds.X + 8, v.Text.TextBounds.Y + 7)
	                    Sizes[Ent] = Magnitude
	                end
	            end
	            v.BG.Position = Vector2.new(HeadPos.X - (v.BG.Size.X / 2), HeadPos.Y - v.BG.Size.Y)
	            v.Text.Position = v.BG.Position + Vector2.new(4, 3)
	        end
	    end
	}
	
	NameTags = vape.Categories.Render:CreateModule({
	    Name = "NameTags",
	    Function = function(Callback: boolean)
	        if Callback then
	            MethodUsed = DrawingToggle.Enabled and "Drawing" or "Normal"
	            if Removed[MethodUsed] then
	                NameTags:Clean(Entity.Events.EntityRemoved:Connect(Removed[MethodUsed]))
	            end
	
	            if Added[MethodUsed] then
	                for _, v: any in Entity.List do
	                    if Reference[v] then
	                        Removed[MethodUsed](v)
	                    end
	                    Added[MethodUsed](v)
	                end
	                NameTags:Clean(Entity.Events.EntityAdded:Connect(function(Ent)
	                    if Reference[Ent] then
	                        Removed[MethodUsed](Ent)
	                    end
	                    Added[MethodUsed](Ent)
	                end))
	            end
	
	            if Updated[MethodUsed] then
	                NameTags:Clean(Entity.Events.EntityUpdated:Connect(Updated[MethodUsed]))
	                for _, v: any in Entity.List do
	                    Updated[MethodUsed](v)
	                end
	            end
	
	            if ColorFunc[MethodUsed] then
	                NameTags:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
	                    ColorFunc[MethodUsed](Color.Hue, Color.Sat, Color.Value)
	                end))
	            end
	
	            if Loop[MethodUsed] then
	                NameTags:Clean(RunService.RenderStepped:Connect(Loop[MethodUsed]))
	            end
	        else
	            if Removed[MethodUsed] then
	                for Ent: any in Reference do
	                    Removed[MethodUsed](Ent)
	                end
	            end
	        end
	    end,
	    Tooltip = "Renders nametags on entities through walls."
	})
	
	Targets = NameTags:CreateTargets({
	    Players = true,
	    Function = function()
	        if NameTags.Enabled then
	            NameTags:Toggle()
	            NameTags:Toggle()
	        end
	    end
	})
	FontOption = NameTags:CreateFont({
	    Name = "Font",
	    Blacklist = "Arial",
	    Function = function()
	        if NameTags.Enabled then
	            NameTags:Toggle()
	            NameTags:Toggle()
	        end
	    end
	})
	Color = NameTags:CreateColorSlider({
	    Name = "Player Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        if NameTags.Enabled and ColorFunc[MethodUsed] then
	            ColorFunc[MethodUsed](Hue, Sat, Val)
	        end
	    end
	})
	Scale = NameTags:CreateSlider({
	    Name = "Scale",
	    Function = function()
	        if NameTags.Enabled then
	            NameTags:Toggle()
	            NameTags:Toggle()
	        end
	    end,
	    Default = 1,
	    Min = 0.1,
	    Max = 1.5,
	    Decimal = 10
	})
	Background = NameTags:CreateSlider({
	    Name = "Transparency",
	    Function = function()
	        if NameTags.Enabled then
	            NameTags:Toggle()
	            NameTags:Toggle()
	        end
	    end,
	    Default = 0.5,
	    Min = 0,
	    Max = 1,
	    Decimal = 10
	})
	Stroke = NameTags:CreateSlider({
	    Name = "Stroke Transparency",
	    Function = function()
	        if NameTags.Enabled then
	            NameTags:Toggle()
	            NameTags:Toggle()
	        end
	    end,
	    Default = 1,
	    Min = 0,
	    Max = 1,
	    Decimal = 10
	})
	Health = NameTags:CreateToggle({
	    Name = "Health",
	    Function = function()
	        if NameTags.Enabled then
	            NameTags:Toggle()
	            NameTags:Toggle()
	        end
	    end
	})
	Distance = NameTags:CreateToggle({
	    Name = "Distance",
	    Function = function()
	        if NameTags.Enabled then
	            NameTags:Toggle()
	            NameTags:Toggle()
	        end
	    end
	})
	DisplayName = NameTags:CreateToggle({
	    Name = "Use Displayname",
	    Function = function()
	        if NameTags.Enabled then
	            NameTags:Toggle()
	            NameTags:Toggle()
	        end
	    end,
	    Default = true
	})
	Teammates = NameTags:CreateToggle({
	    Name = "Priority Only",
	    Function = function()
	        if NameTags.Enabled then
	            NameTags:Toggle()
	            NameTags:Toggle()
	        end
	    end,
	    Default = true,
	    Tooltip = "Hides teammates & non targetable entities"
	})
	DrawingToggle = NameTags:CreateToggle({
	    Name = "Drawing",
	    Function = function()
	        if NameTags.Enabled then
	            NameTags:Toggle()
	            NameTags:Toggle()
	        end
	    end
	})
	DistanceCheck = NameTags:CreateToggle({
	    Name = "Distance Check",
	    Function = function(Callback: boolean)
	        DistanceLimit.Object.Visible = Callback
	    end
	})
	DistanceLimit = NameTags:CreateTwoSlider({
	    Name = "Player Distance",
	    Min = 0,
	    Max = 256,
	    DefaultMin = 0,
	    DefaultMax = 64,
	    Darker = true,
	    Visible = false
	})
end)

Run(function()
	local PlayerModel
	local Scale
	local Local
	local Mesh
	local Texture
	local Rotations = {}
	local Models: {[BasePart]: Part} = {}
	
	local function AddMesh(Ent)
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	    local Root: BasePart = Ent.RootPart
	    local Part: Part = Instance.new("Part")
	    Part.Size = Vector3.new(3, 3, 3)
	    Part.CFrame = Root.CFrame * CFrame.Angles(math.rad(Rotations[1].Value), math.rad(Rotations[2].Value), math.rad(Rotations[3].Value))
	    Part.CanCollide = false
	    Part.CanQuery = false
	    Part.Massless = true
	    Part.Parent = workspace
	    local ModelMesh: SpecialMesh = Instance.new("SpecialMesh")
	    ModelMesh.MeshId = Mesh.Value
	    ModelMesh.TextureId = Texture.Value
	    ModelMesh.Scale = Vector3.one * Scale.Value
	    ModelMesh.Parent = Part
	    local Weld: WeldConstraint = Instance.new("WeldConstraint")
	    Weld.Part0 = Part
	    Weld.Part1 = Root
	    Weld.Parent = Part
	    Models[Root] = Part
	end
	
	local function RemoveMesh(Ent)
	    if Models[Ent.RootPart] then
	        Models[Ent.RootPart]:Destroy()
	        Models[Ent.RootPart] = nil
	    end
	end
	
	PlayerModel = vape.Categories.Render:CreateModule({
	    Name = "PlayerModel",
	    Function = function(Callback: boolean)
	        if Callback then
	            if Local.Enabled then
	                PlayerModel:Clean(Entity.Events.LocalAdded:Connect(AddMesh))
	                PlayerModel:Clean(Entity.Events.LocalRemoved:Connect(RemoveMesh))
	                if Entity.isAlive then
	                    task.spawn(AddMesh, Entity.character)
	                end
	            end
	            PlayerModel:Clean(Entity.Events.EntityAdded:Connect(AddMesh))
	            PlayerModel:Clean(Entity.Events.EntityRemoved:Connect(RemoveMesh))
	            for _, v: any in Entity.List do
	                task.spawn(AddMesh, v)
	            end
	        else
	            for _, v: Part in Models do
	                v:Destroy()
	            end
	            table.clear(Models)
	        end
	    end,
	    Tooltip = "Change the player models to a Mesh"
	})
	
	Scale = PlayerModel:CreateSlider({
	    Name = "Scale",
	    Min = 0,
	    Max = 2,
	    Decimal = 100,
	    Function = function(Val: number)
	        for _, v: Part in Models do
	            v.Mesh.Scale = Vector3.one * Val
	        end
	    end,
	    Default = 1
	})
	for _, SliderName: string in {"Rotation X", "Rotation Y", "Rotation Z"} do
	    table.insert(Rotations, PlayerModel:CreateSlider({
	        Name = SliderName,
	        Min = 0,
	        Max = 360,
	        Function = function(Val: number)
	            for Root: BasePart, v: Part in Models do
	                v.WeldConstraint.Enabled = false
	                v.CFrame = Root.CFrame * CFrame.Angles(math.rad(Rotations[1].Value), math.rad(Rotations[2].Value), math.rad(Rotations[3].Value))
	                v.WeldConstraint.Enabled = true
	            end
	        end
	    }))
	end
	Local = PlayerModel:CreateToggle({
	    Name = "Local",
	    Function = function()
	        if PlayerModel.Enabled then
	            PlayerModel:Toggle()
	            PlayerModel:Toggle()
	        end
	    end
	})
	Mesh = PlayerModel:CreateTextBox({
	    Name = "Mesh",
	    Placeholder = "mesh id",
	    Function = function()
	        for _, v: Part in Models do
	            v.Mesh.MeshId = Mesh.Value
	        end
	    end
	})
	Texture = PlayerModel:CreateTextBox({
	    Name = "Texture",
	    Placeholder = "texture id",
	    Function = function()
	        for _, v: Part in Models do
	            v.Mesh.TextureId = Texture.Value
	        end
	    end
	})
end)

Run(function()
	local Radar
	local Targets
	local DotStyle
	local PlayerColor
	local Clamp
	local Reference = {}
	local Background: Frame
	
	local function Added(Ent)
	    if not Targets.Players.Enabled and Ent.Player then
	        return
	    end
	    if not Targets.NPCs.Enabled and Ent.NPC then
	        return
	    end
	    if (not Ent.Targetable) and (not Ent.Friend) then
	        return
	    end
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    local Dot: Frame = Instance.new("Frame")
	    Dot.Size = UDim2.fromOffset(4, 4)
	    Dot.AnchorPoint = Vector2.new(0.5, 0.5)
	    Dot.BackgroundColor3 = Entity.getEntityColor(Ent) or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
	    Dot.Parent = Background
	    local Corner: UICorner = Instance.new("UICorner")
	    Corner.CornerRadius = UDim.new(DotStyle.Value == "Circles" and 1 or 0, 0)
	    Corner.Parent = Dot
	    local Stroke: UIStroke = Instance.new("UIStroke")
	    Stroke.Color = Color3.new()
	    Stroke.Thickness = 1
	    Stroke.Transparency = 0.8
	    Stroke.Parent = Dot
	    Reference[Ent] = Dot
	end
	
	local function Removed(Ent)
	    local Dot: Frame? = Reference[Ent]
	    if Dot then
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	        Reference[Ent] = nil
	        Dot:Destroy()
	    end
	end
	
	Radar = vape:CreateOverlay({
	    Name = "Radar",
	    Icon = GetVapeAsset("kingvape/assets/new/radaricon.png"),
	    Size = UDim2.fromOffset(14, 14),
	    Position = UDim2.fromOffset(12, 13),
	    Function = function(Callback: boolean)
	        if Callback then
	            Radar:Clean(Entity.Events.EntityRemoved:Connect(Removed))
	            for _, v: any in Entity.List do
	                if Reference[v] then
	                    Removed(v)
	                end
	                Added(v)
	            end
	            Radar:Clean(Entity.Events.EntityAdded:Connect(function(Ent)
	                if Reference[Ent] then
	                    Removed(Ent)
	                end
	                Added(Ent)
	            end))
	            Radar:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
	                for Ent: any, v: Frame in Reference do
	                    v.BackgroundColor3 = Entity.getEntityColor(Ent) or Color3.fromHSV(PlayerColor.Hue, PlayerColor.Sat, PlayerColor.Value)
	                end
	            end))
	            Radar:Clean(RunService.RenderStepped:Connect(function()
	                if not Entity.isAlive then
	                    return
	                end
	
	                local Facing: CFrame = CFrame.lookAlong(Entity.character.RootPart.Position, Camera.CFrame.LookVector * Vector3.new(1, 0, 1))
	
	                for Ent: any, v: Frame in Reference do
	                    local RelativePosition: Vector3 = Facing:PointToObjectSpace(Ent.RootPart.Position)
	                    v.Position = UDim2.fromOffset(Clamp.Enabled and math.clamp(108 + RelativePosition.X, 2, 214) or 108 + RelativePosition.X, Clamp.Enabled and math.clamp(108 + RelativePosition.Z, 8, 214) or 108 + RelativePosition.Z)
	                end
	            end))
	        else
	            for Ent: any in Reference do
	                Removed(Ent)
	            end
	        end
	    end
	})
	
	Targets = Radar:CreateTargets({
	    Players = true,
	    Function = function()
	        if Radar.Button.Enabled then
	            Radar.Button:Toggle()
	            Radar.Button:Toggle()
	        end
	    end
	})
	DotStyle = Radar:CreateDropdown({
	    Name = "Dot Style",
	    List = {"Circles", "Squares"},
	    Function = function(Val: string)
	        for _, v: Frame in Reference do
	            v.UICorner.CornerRadius = UDim.new(Val == "Circles" and 1 or 0, 0)
	        end
	    end
	})
	PlayerColor = Radar:CreateColorSlider({
	    Name = "Player Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        for Ent: any, v: Frame in Reference do
	            v.BackgroundColor3 = Entity.getEntityColor(Ent) or Color3.fromHSV(Hue, Sat, Val)
	        end
	    end
	})
	Background = Instance.new("Frame")
	Background.Size = UDim2.fromOffset(216, 216)
	Background.Position = UDim2.fromOffset(2, 2)
	Background.BackgroundColor3 = Color3.new()
	Background.BackgroundTransparency = 0.5
	Background.ClipsDescendants = true
	Background.Parent = Radar.Children
	local Corner: UICorner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 8)
	Corner.Parent = Background
	local Stroke: UIStroke = Instance.new("UIStroke")
	Stroke.Thickness = 2
	Stroke.Color = Color3.new()
	Stroke.Transparency = 0.4
	Stroke.Parent = Background
	local VerticalLine: Frame = Instance.new("Frame")
	VerticalLine.Size = UDim2.new(0, 2, 1, 0)
	VerticalLine.Position = UDim2.fromScale(0.5, 0.5)
	VerticalLine.AnchorPoint = Vector2.new(0.5, 0.5)
	VerticalLine.ZIndex = 0
	VerticalLine.BackgroundColor3 = Color3.new(1, 1, 1)
	VerticalLine.BackgroundTransparency = 0.5
	VerticalLine.BorderSizePixel = 0
	VerticalLine.Parent = Background
	local HorizontalLine: Frame = VerticalLine:Clone()
	HorizontalLine.Size = UDim2.new(1, 0, 0, 2)
	HorizontalLine.Parent = Background
	local Bar: Frame = Instance.new("Frame")
	Bar.Size = UDim2.new(1, -6, 0, 4)
	Bar.Position = UDim2.fromOffset(3, 0)
	Bar.BackgroundColor3 = Color3.fromHSV(0.44, 1, 1)
	Bar.Parent = Background
	local BarCorner: UICorner = Instance.new("UICorner")
	BarCorner.CornerRadius = UDim.new(0, 8)
	BarCorner.Parent = Bar
	Radar:CreateColorSlider({
	    Name = "Bar Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        Bar.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
	    end
	})
	Radar:CreateToggle({
	    Name = "Show Background",
	    Function = function(Callback: boolean)
	        Background.BackgroundTransparency = Callback and 0.5 or 1
	        Bar.BackgroundTransparency = Callback and 0 or 1
	        Stroke.Transparency = Callback and 0.4 or 1
	    end,
	    Default = true
	})
	Radar:CreateToggle({
	    Name = "Show Cross",
	    Function = function(Callback: boolean)
	        VerticalLine.BackgroundTransparency = Callback and 0.5 or 1
	        HorizontalLine.BackgroundTransparency = Callback and 0.5 or 1
	    end,
	    Default = true
	})
	Clamp = Radar:CreateToggle({
	    Name = "Clamp Radar",
	    Default = true
	})
end)

Run(function()
	local Search
	local List
	local Color
	local FillTransparency
	local Reference: {[Instance]: BoxHandleAdornment} = {}
	local Folder: Folder = Instance.new("Folder")
	Folder.Parent = vape.gui
	
	local function Add(Object: Instance)
	    if not table.find(List.ListEnabled, Object.Name) then
	        return
	    end
	    if Object:IsA("BasePart") or Object:IsA("Model") then
	        local Size: Vector3 = Object:IsA("Model") and Object:GetExtentsSize() or Object.Size
	        local Box: BoxHandleAdornment = Instance.new("BoxHandleAdornment")
	        Box.AlwaysOnTop = true
	        Box.Adornee = Object
	        Box.Size = Size.Magnitude > 0.4 and Size or Vector3.one
	        Box.ZIndex = 0
	        Box.Transparency = FillTransparency.Value
	        Box.Color3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	        Box.Parent = Folder
	        Reference[Object] = Box
	    end
	end
	
	Search = vape.Categories.Render:CreateModule({
	    Name = "Search",
	    Function = function(Callback: boolean)
	        if Callback then
	            Search:Clean(workspace.DescendantAdded:Connect(Add))
	            Search:Clean(workspace.DescendantRemoving:Connect(function(Object: Instance)
	                if Reference[Object] then
	                    Reference[Object]:Destroy()
	                    Reference[Object] = nil
	                end
	            end))
	
	            for _, v: Instance in workspace:GetDescendants() do
	                Add(v)
	            end
	        else
	            Folder:ClearAllChildren()
	            table.clear(Reference)
	        end
	    end,
	    Tooltip = "Draws box around selected parts\nAdd parts in Search frame"
	})
	
	List = Search:CreateTextList({
	    Name = "Parts",
	    Function = function()
	        if Search.Enabled then
	            Search:Toggle()
	            Search:Toggle()
	        end
	    end
	})
	Color = Search:CreateColorSlider({
	    Name = "Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        for _, v: BoxHandleAdornment in Reference do
	            v.Color3 = Color3.fromHSV(Hue, Sat, Val)
	        end
	    end
	})
	FillTransparency = Search:CreateSlider({
	    Name = "Transparency",
	    Min = 0,
	    Max = 1,
	    Function = function(Val: number)
	        for _, v: BoxHandleAdornment in Reference do
	            v.Transparency = Val
	        end
	    end,
	    Decimal = 10
	})
end)

Run(function()
	local SessionInfo
	local FontOption
	local Hide
	local TextSize
	local BorderColor
	local Title
	local TitleOffset = {}
	local Custom
	local CustomBox
	local InfoHolder: Frame
	local InfoLabel: TextLabel
	local InfoStroke: UIStroke
	
	SessionInfo = vape:CreateOverlay({
	    Name = "Session Info",
	    Icon = GetVapeAsset("kingvape/assets/new/textguiicon.png"),
	    Size = UDim2.fromOffset(16, 12),
	    Position = UDim2.fromOffset(12, 14),
	    Function = function(Callback: boolean)
	        if Callback then
	            local TeleportedServers: boolean?
	            SessionInfo:Clean(Players.LocalPlayer.OnTeleport:Connect(function()
	                if not TeleportedServers then
	                    TeleportedServers = true
	                    queue_on_teleport(`shared.vapesessioninfo = '{HttpService:JSONEncode(vape.Libraries.sessioninfo.Objects)}'`)
	                end
	            end))
	
	            if shared.vapesessioninfo then
	                for Name: string, v: any in HttpService:JSONDecode(shared.vapesessioninfo) do
	                    if vape.Libraries.sessioninfo.Objects[Name] and v.Saved then
	                        vape.Libraries.sessioninfo.Objects[Name].Value = v.Value
	                    end
	                end
	            end
	
	            repeat
	                if vape.Libraries.sessioninfo then
	                    local Lines = {""}
	                    if Title.Enabled then
	                        Lines[1] = TitleOffset.Enabled and '<b>Session Info</b>\n<font size="4"> </font>' or "<b>Session Info</b>"
	                    end
	
	                    for Name: string, v: any in vape.Libraries.sessioninfo.Objects do
	                        Lines[v.Index] = not table.find(Hide.ListEnabled, Name) and `{Name}: {v.Function(v.Value)}` or false
	                    end
	
	                    if #Hide.ListEnabled > 0 then
	                        local Key, Value
	                        repeat
	                            local OldKey = Key
	                            Key, Value = next(Lines, Key)
	                            if Value == false then
	                                table.remove(Lines, Key)
	                                Key = OldKey
	                            end
	                        until not Key
	                    end
	
	                    if Custom.Enabled then
	                        table.insert(Lines, CustomBox.Value)
	                    end
	
	                    if not Title.Enabled then
	                        table.remove(Lines, 1)
	                    end
	                    InfoLabel.Text = table.concat(Lines, "\n")
	                    InfoLabel.FontFace = FontOption.Value
	                    InfoLabel.TextSize = TextSize.Value
	                    local Size: Vector2 = GetFontBounds(RemoveTags(InfoLabel.Text), InfoLabel.TextSize, InfoLabel.FontFace)
	                    InfoHolder.Size = UDim2.fromOffset(Size.X + 16, Size.Y + (Title.Enabled and TitleOffset.Enabled and 4 or 16))
	                end
	
	                task.wait(1)
	            until not SessionInfo.Button or not SessionInfo.Button.Enabled
	        end
	    end
	})
	
	FontOption = SessionInfo:CreateFont({
	    Name = "Font",
	    Blacklist = "Arial"
	})
	Hide = SessionInfo:CreateTextList({
	    Name = "Blacklist",
	    Tooltip = "Name of entry to hide.",
	    Icon = GetVapeAsset("kingvape/assets/new/blockedicon.png"),
	    Tab = GetVapeAsset("kingvape/assets/new/blockedtab.png"),
	    TabSize = UDim2.fromOffset(21, 16),
	    Color = Color3.fromRGB(250, 50, 56)
	})
	SessionInfo:CreateColorSlider({
	    Name = "Background Color",
	    DefaultValue = 0,
	    DefaultOpacity = 0.5,
	    Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
	        InfoHolder.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
	        InfoHolder.BackgroundTransparency = 1 - Opacity
	    end
	})
	BorderColor = SessionInfo:CreateColorSlider({
	    Name = "Border Color",
	    Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
	        InfoStroke.Color = Color3.fromHSV(Hue, Sat, Val)
	        InfoStroke.Transparency = 1 - Opacity
	    end,
	    Darker = true,
	    Visible = false
	})
	TextSize = SessionInfo:CreateSlider({
	    Name = "Text Size",
	    Min = 1,
	    Max = 30,
	    Default = 16
	})
	Title = SessionInfo:CreateToggle({
	    Name = "Title",
	    Function = function(Callback: boolean)
	        if TitleOffset.Object then
	            TitleOffset.Object.Visible = Callback
	        end
	    end,
	    Default = true
	})
	TitleOffset = SessionInfo:CreateToggle({
	    Name = "Offset",
	    Default = true,
	    Darker = true
	})
	SessionInfo:CreateToggle({
	    Name = "Border",
	    Function = function(Callback: boolean)
	        InfoStroke.Enabled = Callback
	        BorderColor.Object.Visible = Callback
	    end
	})
	Custom = SessionInfo:CreateToggle({
	    Name = "Add custom text",
	    Function = function(Enabled: boolean)
	        CustomBox.Object.Visible = Enabled
	    end
	})
	CustomBox = SessionInfo:CreateTextBox({
	    Name = "Custom text",
	    Darker = true,
	    Visible = false
	})
	InfoHolder = Instance.new("Frame")
	InfoHolder.BackgroundColor3 = Color3.new()
	InfoHolder.BackgroundTransparency = 0.5
	InfoHolder.Parent = SessionInfo.Children
	vape:Clean(SessionInfo.Children:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	    local NewSide: boolean = SessionInfo.Children.AbsolutePosition.X > (vape.gui.AbsoluteSize.X / 2)
	    InfoHolder.Position = UDim2.fromScale(NewSide and 1 or 0, 0)
	    InfoHolder.AnchorPoint = Vector2.new(NewSide and 1 or 0, 0)
	end))
	local SessionInfoCorner: UICorner = Instance.new("UICorner")
	SessionInfoCorner.CornerRadius = UDim.new(0, 5)
	SessionInfoCorner.Parent = InfoHolder
	InfoLabel = Instance.new("TextLabel")
	InfoLabel.Size = UDim2.new(1, -16, 1, -16)
	InfoLabel.Position = UDim2.fromOffset(8, 8)
	InfoLabel.BackgroundTransparency = 1
	InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
	InfoLabel.TextYAlignment = Enum.TextYAlignment.Top
	InfoLabel.TextSize = 16
	InfoLabel.TextColor3 = Color3.new(1, 1, 1)
	InfoLabel.TextStrokeColor3 = Color3.new()
	InfoLabel.TextStrokeTransparency = 0.8
	InfoLabel.Font = Enum.Font.Arial
	InfoLabel.RichText = true
	InfoLabel.Parent = InfoHolder
	InfoStroke = Instance.new("UIStroke")
	InfoStroke.Enabled = false
	InfoStroke.Color = Color3.fromHSV(0.44, 1, 1)
	InfoStroke.Parent = InfoHolder
	AddBlur(InfoHolder)
	vape.Libraries.sessioninfo = {
	    Objects = {},
	    AddItem = function(self, Name: string, StartValue, Func, Saved)
	        Func, Saved = Func or function(Val) return Val end, Saved == nil or Saved
	        self.Objects[Name] = {Function = Func, Saved = Saved, Value = StartValue or 0, Index = GetTableSize(self.Objects) + 2}
	        return {
	            Increment = function(_, Val: number?)
	                self.Objects[Name].Value += (Val or 1)
	            end,
	            Get = function()
	                return self.Objects[Name].Value
	            end
	        }
	    end
	}
	vape.Libraries.sessioninfo:AddItem("Time Played", os.clock(), function(Value: number)
	    return os.date("!%X", math.floor(os.clock() - Value))
	end)
end)

Run(function()
	local Tracers
	local Targets
	local Color
	local Transparency
	local StartPosition
	local EndPosition
	local Teammates
	local DistanceColor
	local Distance
	local DistanceLimit
	local Behind
	local Reference = {}
	
	local function Added(Ent)
	    if not Targets.Players.Enabled and Ent.Player then
	        return
	    end
	    if not Targets.NPCs.Enabled and Ent.NPC then
	        return
	    end
	    if Teammates.Enabled and (not Ent.Targetable) and (not Ent.Friend) then
	        return
	    end
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    local EntityTracer = Drawing.new("Line")
	    EntityTracer.Thickness = 1
	    EntityTracer.Transparency = 1 - Transparency.Value
	    EntityTracer.Color = Entity.getEntityColor(Ent) or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	    Reference[Ent] = EntityTracer
	end
	
	local function Removed(Ent)
	    local Tracer = Reference[Ent]
	    if Tracer then
	        if vape.ThreadFix then
	            setthreadidentity(8)
	        end
	        Reference[Ent] = nil
	        pcall(function()
	            Tracer.Visible = false
	            Tracer:Remove()
	        end)
	    end
	end
	
	local function ColorFunc(Hue: number, Sat: number, Val: number)
	    if DistanceColor.Enabled then
	        return
	    end
	    local TracerColor: Color3 = Color3.fromHSV(Hue, Sat, Val)
	    for Ent: any, v: any in Reference do
	        v.Color = Entity.getEntityColor(Ent) or TracerColor
	    end
	end
	
	local function Loop()
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    local ScreenSize: Vector2 = vape.gui.AbsoluteSize
	    local StartVector: Vector2 = StartPosition.Value == "Mouse" and UserInputService:GetMouseLocation() or Vector2.new(ScreenSize.X / 2, (StartPosition.Value == "Middle" and ScreenSize.Y / 2 or ScreenSize.Y))
	
	    local LocalPosition = Entity.isAlive and Entity.character.RootPart.Position
	
	    for Ent: any, v: any in Reference do
	        local EntityDistance = Distance.Enabled and LocalPosition and (LocalPosition - Ent.RootPart.Position).Magnitude
	        if EntityDistance then
	            if EntityDistance < DistanceLimit.ValueMin or EntityDistance > DistanceLimit.ValueMax then
	                v.Visible = false
	                continue
	            end
	        end
	
	        local TargetPosition: Vector3 = Ent[EndPosition.Value == "Torso" and "RootPart" or "Head"].Position
	        local RootPos, RootVisible = Camera:WorldToViewportPoint(TargetPosition)
	        if not RootVisible and Behind.Enabled then
	            local RelativePosition: Vector3 = Camera.CFrame:PointToObjectSpace(TargetPosition)
	            RelativePosition = CFrame.Angles(0, 0, (math.atan2(RelativePosition.Y, RelativePosition.X) + math.pi)):VectorToWorldSpace((CFrame.Angles(0, math.rad(89.9), 0):VectorToWorldSpace(Vector3.new(0, 0, -1))))
	            RootPos = Camera:WorldToViewportPoint(Camera.CFrame:pointToWorldSpace(RelativePosition))
	            RootVisible = true
	        end
	
	        local EndVector: Vector2 = Vector2.new(RootPos.X, RootPos.Y)
	        v.Visible = RootVisible
	        v.From = StartVector
	        v.To = EndVector
	        if DistanceColor.Enabled and EntityDistance then
	            v.Color = Color3.fromHSV(math.min((EntityDistance / 128) / 2.8, 0.4), 0.89, 0.75)
	        end
	    end
	end
	
	Tracers = vape.Categories.Render:CreateModule({
	    Name = "Tracers",
	    Function = function(Callback: boolean)
	        if Callback then
	            Tracers:Clean(Entity.Events.EntityRemoved:Connect(Removed))
	            for _, v: any in Entity.List do
	                if Reference[v] then
	                    Removed(v)
	                end
	                Added(v)
	            end
	            Tracers:Clean(Entity.Events.EntityAdded:Connect(function(Ent)
	                if Reference[Ent] then
	                    Removed(Ent)
	                end
	                Added(Ent)
	            end))
	            Tracers:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
	                ColorFunc(Color.Hue, Color.Sat, Color.Value)
	            end))
	            Tracers:Clean(RunService.RenderStepped:Connect(Loop))
	        else
	            for Ent: any in Reference do
	                Removed(Ent)
	            end
	        end
	    end,
	    Tooltip = "Renders tracers on players."
	})
	
	Targets = Tracers:CreateTargets({
	    Players = true,
	    Function = function()
	        if Tracers.Enabled then
	            Tracers:Toggle()
	            Tracers:Toggle()
	        end
	    end
	})
	StartPosition = Tracers:CreateDropdown({
	    Name = "Start Position",
	    List = {"Middle", "Bottom", "Mouse"},
	    Function = function()
	        if Tracers.Enabled then
	            Tracers:Toggle()
	            Tracers:Toggle()
	        end
	    end
	})
	EndPosition = Tracers:CreateDropdown({
	    Name = "End Position",
	    List = {"Head", "Torso"},
	    Function = function()
	        if Tracers.Enabled then
	            Tracers:Toggle()
	            Tracers:Toggle()
	        end
	    end
	})
	Color = Tracers:CreateColorSlider({
	    Name = "Player Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        if Tracers.Enabled then
	            ColorFunc(Hue, Sat, Val)
	        end
	    end
	})
	Transparency = Tracers:CreateSlider({
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
	DistanceColor = Tracers:CreateToggle({
	    Name = "Color by distance",
	    Function = function()
	        if Tracers.Enabled then
	            Tracers:Toggle()
	            Tracers:Toggle()
	        end
	    end
	})
	Distance = Tracers:CreateToggle({
	    Name = "Distance Check",
	    Function = function(Callback: boolean)
	        DistanceLimit.Object.Visible = Callback
	    end
	})
	DistanceLimit = Tracers:CreateTwoSlider({
	    Name = "Player Distance",
	    Min = 0,
	    Max = 256,
	    DefaultMin = 0,
	    DefaultMax = 64,
	    Darker = true,
	    Visible = false
	})
	Behind = Tracers:CreateToggle({
	    Name = "Behind",
	    Default = true
	})
	Teammates = Tracers:CreateToggle({
	    Name = "Priority Only",
	    Function = function()
	        if Tracers.Enabled then
	            Tracers:Toggle()
	            Tracers:Toggle()
	        end
	    end,
	    Default = true,
	    Tooltip = "Hides teammates & non targetable entities"
	})
end)

Run(function()
	local Waypoints
	local FontOption
	local List
	local Color
	local Scale
	local Background
	WaypointFolder = Instance.new("Folder")
	WaypointFolder.Parent = vape.gui
	
	Waypoints = vape.Categories.Render:CreateModule({
	    Name = "Waypoints",
	    Function = function(Callback: boolean)
	        if Callback then
	            for _, v: string in List.ListEnabled do
	                local Split: {string} = v:split("/")
	                local TagSize: Vector2 = GetFontBounds(RemoveTags(Split[2]), 14 * Scale.Value, FontOption.Value)
	                local Billboard: BillboardGui = Instance.new("BillboardGui")
	                Billboard.Size = UDim2.fromOffset(TagSize.X + 8, TagSize.Y + 7)
	                Billboard.StudsOffsetWorldSpace = Vector3.new(unpack(Split[1]:split(",")))
	                Billboard.AlwaysOnTop = true
	                Billboard.Parent = WaypointFolder
	                local Tag: TextLabel = Instance.new("TextLabel")
	                Tag.BackgroundColor3 = Color3.new()
	                Tag.BorderSizePixel = 0
	                Tag.Visible = true
	                Tag.RichText = true
	                Tag.FontFace = FontOption.Value
	                Tag.TextSize = 14 * Scale.Value
	                Tag.BackgroundTransparency = Background.Value
	                Tag.Size = Billboard.Size
	                Tag.Text = Split[2]
	                Tag.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	                Tag.Parent = Billboard
	            end
	        else
	            WaypointFolder:ClearAllChildren()
	        end
	    end,
	    Tooltip = "Mark certain spots with a visual indicator"
	})
	
	FontOption = Waypoints:CreateFont({
	    Name = "Font",
	    Blacklist = "Arial",
	    Function = function()
	        if Waypoints.Enabled then
	            Waypoints:Toggle()
	            Waypoints:Toggle()
	        end
	    end
	})
	List = Waypoints:CreateTextList({
	    Name = "Points",
	    Placeholder = "x, y, z/name",
	    Function = function()
	        if Waypoints.Enabled then
	            Waypoints:Toggle()
	            Waypoints:Toggle()
	        end
	    end
	})
	Waypoints:CreateButton({
	    Name = "Add current position",
	    Function = function()
	        if Entity.isAlive then
	            local Position: Vector3 = Entity.character.RootPart.Position // 1
	            List:ChangeValue(`{Position.X},{Position.Y},{Position.Z}/Waypoint {#List.List + 1}`)
	        end
	    end
	})
	Color = Waypoints:CreateColorSlider({
	    Name = "Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        for _, v: Instance in WaypointFolder:GetChildren() do
	            v.TextLabel.TextColor3 = Color3.fromHSV(Hue, Sat, Val)
	        end
	    end
	})
	Scale = Waypoints:CreateSlider({
	    Name = "Scale",
	    Function = function()
	        if Waypoints.Enabled then
	            Waypoints:Toggle()
	            Waypoints:Toggle()
	        end
	    end,
	    Default = 1,
	    Min = 0.1,
	    Max = 1.5,
	    Decimal = 10
	})
	Background = Waypoints:CreateSlider({
	    Name = "Transparency",
	    Function = function()
	        if Waypoints.Enabled then
	            Waypoints:Toggle()
	            Waypoints:Toggle()
	        end
	    end,
	    Default = 0.5,
	    Min = 0,
	    Max = 1,
	    Decimal = 10
	})
end)

Run(function()
	local ZoomUnlocker
	local Distance
	local FirstPerson
	local OldMax, OldMin
	
	ZoomUnlocker = vape.Categories.Render:CreateModule({
	    Name = "ZoomUnlocker",
	    Function = function(Callback: boolean)
	        if Callback then
	            OldMax, OldMin = LocalPlayer.CameraMaxZoomDistance, LocalPlayer.CameraMinZoomDistance
	            repeat
	                local MinZoom: number = FirstPerson.Enabled and 0.5 or math.min(OldMin, Distance.Value)
	                if LocalPlayer.CameraMinZoomDistance ~= MinZoom or LocalPlayer.CameraMaxZoomDistance ~= Distance.Value then
	                    LocalPlayer.CameraMinZoomDistance = MinZoom
	                    LocalPlayer.CameraMaxZoomDistance = Distance.Value
	                end
	                task.wait()
	            until not ZoomUnlocker.Enabled
	        else
	            LocalPlayer.CameraMinZoomDistance = OldMin
	            LocalPlayer.CameraMaxZoomDistance = OldMax
	        end
	    end,
	    Tooltip = "Removes the zoom limit the game puts on your camera"
	})
	
	Distance = ZoomUnlocker:CreateSlider({
	    Name = "Distance",
	    Min = 1,
	    Max = 500,
	    Default = 128,
	    Suffix = function(Val: number)
	        return Val > 1 and "studs" or "stud"
	    end
	})
	FirstPerson = ZoomUnlocker:CreateToggle({
	    Name = "Allow first person",
	    Default = true,
	    Tooltip = "Also unlocks zooming all the way in"
	})
end)

Run(function()
	local AnimationPlayer
	local IDBox
	local Priority
	local Speed
	local AnimationTrack, AnimationObject
	
	local function PlayAnimation(Character)
	    local PreviousTrack: AnimationTrack? = AnimationTrack
	    if PreviousTrack then
	        AnimationTrack = nil
	        PreviousTrack:Stop()
	    end
	
	    local Success, Result = pcall(function()
	        AnimationTrack = Character.Humanoid.Animator:LoadAnimation(AnimationObject)
	    end)
	
	    if Success then
	        local CurrentTrack: AnimationTrack = AnimationTrack
	        AnimationTrack.Priority = Enum.AnimationPriority[Priority.Value]
	        AnimationTrack:Play()
	        AnimationTrack:AdjustSpeed(Speed.Value)
	        AnimationPlayer:Clean(AnimationTrack.Stopped:Connect(function()
	            if CurrentTrack == AnimationTrack then
	                AnimationTrack:Play()
	            end
	        end))
	    else
	        SendNotification("AnimationPlayer", `failed to load anim : {Result or "invalid animation id"}`, 5, "warning")
	    end
	end
	
	AnimationPlayer = vape.Categories.Utility:CreateModule({
	    Name = "AnimationPlayer",
	    Function = function(Callback: boolean)
	        if Callback then
	            AnimationObject = Instance.new("Animation")
	            local Success, AnimationId = pcall(function()
	                return string.match(game:GetObjects(`rbxassetid://{IDBox.Value}`)[1].AnimationId, "%?id=(%d+)")
	            end)
	            AnimationObject.AnimationId = `rbxassetid://{Success and AnimationId or IDBox.Value}`
	
	            if Entity.isAlive then
	                PlayAnimation(Entity.character)
	            end
	            AnimationPlayer:Clean(Entity.Events.LocalAdded:Connect(PlayAnimation))
	            AnimationPlayer:Clean(AnimationObject)
	        else
	            if AnimationTrack then
	                AnimationTrack:Stop()
	            end
	        end
	    end,
	    Tooltip = "Plays a specific animation of your choosing at a certain speed"
	})
	
	IDBox = AnimationPlayer:CreateTextBox({
	    Name = "Animation",
	    Placeholder = "anim (num only)",
	    Function = function(Enter: boolean)
	        if Enter and AnimationPlayer.Enabled then
	            AnimationPlayer:Toggle()
	            AnimationPlayer:Toggle()
	        end
	    end
	})
	local Priorities: {string} = {"Action4"}
	for _, v: EnumItem in Enum.AnimationPriority:GetEnumItems() do
	    if v.Name ~= "Action4" then
	        table.insert(Priorities, v.Name)
	    end
	end
	Priority = AnimationPlayer:CreateDropdown({
	    Name = "Priority",
	    List = Priorities,
	    Function = function(Val: string)
	        if AnimationTrack then
	            AnimationTrack.Priority = Enum.AnimationPriority[Val]
	        end
	    end
	})
	Speed = AnimationPlayer:CreateSlider({
	    Name = "Speed",
	    Function = function(Val: number)
	        if AnimationTrack then
	            AnimationTrack:AdjustSpeed(Val)
	        end
	    end,
	    Min = 0.1,
	    Max = 2,
	    Decimal = 10
	})
end)

Run(function()
	local AntiRagdoll
	
	AntiRagdoll = vape.Categories.Utility:CreateModule({
	    Name = "AntiRagdoll",
	    Function = function(Callback: boolean)
	        if Entity.isAlive then
	            Entity.character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not Callback)
	        end
	
	        if Callback then
	            AntiRagdoll:Clean(Entity.Events.LocalAdded:Connect(function(Character)
	                Character.Humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	            end))
	        end
	    end,
	    Tooltip = "Prevents you from getting knocked down in a ragdoll state"
	})
end)

Run(function()
	local AutoRejoin
	local Sort
	
	AutoRejoin = vape.Categories.Utility:CreateModule({
	    Name = "AutoRejoin",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Checked: boolean?
	            AutoRejoin:Clean(GuiService.ErrorMessageChanged:Connect(function(Message: string)
	                if (not Checked or GuiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectLuaKick) and GuiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectConnectionLost and not Message:lower():find("ban") then
	                    Checked = true
	                    HopServer(nil, Sort.Value)
	                end
	            end))
	        end
	    end,
	    Tooltip = "Automatically rejoins into a new server if you get disconnected / kicked"
	})
	
	Sort = AutoRejoin:CreateDropdown({
	    Name = "Sort",
	    List = {"Descending", "Ascending"},
	    Tooltip = "Descending - Prefers full servers\nAscending - Prefers empty servers"
	})
end)

Run(function()
	local Blink
	local Type
	local AutoSend
	local AutoSendLength
	local OldPhysicsRate, OldSenderRate
	
	Blink = vape.Categories.Utility:CreateModule({
	    Name = "Blink",
	    Function = function(Callback: boolean)
	        if Callback then
	            local Teleported: boolean?
	            Blink:Clean(LocalPlayer.OnTeleport:Connect(function()
	                setfflag("PhysicsSenderMaxBandwidthBps", "38760")
	                setfflag("DataSenderRate", "60")
	                Teleported = true
	            end))
	
	            repeat
	                local PhysicsRate, SenderRate = "0", Type.Value == "All" and "-1" or "60"
	                if AutoSend.Enabled and tick() % (AutoSendLength.Value + 0.1) > AutoSendLength.Value then
	                    PhysicsRate, SenderRate = "38760", "60"
	                end
	
	                if PhysicsRate ~= OldPhysicsRate or SenderRate ~= OldSenderRate then
	                    setfflag("PhysicsSenderMaxBandwidthBps", PhysicsRate)
	                    setfflag("DataSenderRate", SenderRate)
	                    OldPhysicsRate, OldSenderRate = PhysicsRate, SenderRate
	                end
	
	                task.wait(0.03)
	            until (not Blink.Enabled and not Teleported)
	        else
	            if setfflag then
	                setfflag("PhysicsSenderMaxBandwidthBps", "38760")
	                setfflag("DataSenderRate", "60")
	            end
	            OldPhysicsRate, OldSenderRate = nil, nil
	        end
	    end,
	    Tooltip = "Chokes packets until disabled."
	})
	
	Type = Blink:CreateDropdown({
	    Name = "Type",
	    List = {"Movement Only", "All"},
	    Tooltip = "Movement Only - Only chokes movement packets\nAll - Chokes remotes & movement"
	})
	AutoSend = Blink:CreateToggle({
	    Name = "Auto send",
	    Function = function(Callback: boolean)
	        AutoSendLength.Object.Visible = Callback
	    end,
	    Tooltip = "Automatically send packets in intervals"
	})
	AutoSendLength = Blink:CreateSlider({
	    Name = "Send threshold",
	    Min = 0,
	    Max = 1,
	    Decimal = 100,
	    Darker = true,
	    Visible = false,
	    Suffix = function(Val: number)
	        return Val == 1 and "second" or "seconds"
	    end
	})
end)

Run(function()
	local ChatSpammer
	local Lines
	local Mode
	local Delay
	local Hide
	local RandomList: {string} = {}
	local OldChat
	
	ChatSpammer = vape.Categories.Utility:CreateModule({
	    Name = "ChatSpammer",
	    Function = function(Callback: boolean)
	        if Callback then
	            if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	                if Hide.Enabled and CoreGui:FindFirstChild("ExperienceChat") then
	                    ChatSpammer:Clean(CoreGui.ExperienceChat.appLayout.chatWindow.contentFrame.scrollingView.bottomLockedScrollView.scrollView.ChildAdded:Connect(function(MessageFrame: Instance)
	                        if MessageFrame.Name:sub(1, 2) == "0-" and MessageFrame.TextMessage.BodyText.Text == '<font color="#d4d4d4">You must wait before sending another message.</font>' then
	                            MessageFrame.Visible = false
	                        end
	                    end))
	                end
	            elseif ReplicatedStorage:FindFirstChild("DefaultChatSystemChatEvents") then
	                if Hide.Enabled then
	                    OldChat = hookfunction(getconnections(ReplicatedStorage.DefaultChatSystemChatEvents.OnNewSystemMessage.OnClientEvent)[1].Function, function(Data, ...)
	                        if Data.Message:find("ChatFloodDetector") then
	                            return
	                        end
	                        return OldChat(Data, ...)
	                    end)
	                end
	            else
	                SendNotification("ChatSpammer", "unsupported chat", 5, "warning")
	                ChatSpammer:Toggle()
	                return
	            end
	
	            local Index: number = 1
	            repeat
	                local Message: string = "vxpe on top"
	                if #Lines.ListEnabled > 0 then
	                    if Mode.Value == "Order" then
	                        Message = Lines.ListEnabled[Index] or Lines.ListEnabled[1]
	                        Index = (Index % #Lines.ListEnabled) + 1
	                    else
	                        if #RandomList <= 0 then
	                            RandomList = table.clone(Lines.ListEnabled)
	                        end
	
	                        local Entry: number = Random.new():NextInteger(1, #RandomList)
	                        Message = RandomList[Entry]
	                        table.remove(RandomList, Entry)
	                    end
	                end
	
	                if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
	                    TextChatService.ChatInputBarConfiguration.TargetTextChannel:SendAsync(Message)
	                else
	                    ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(Message, "All")
	                end
	
	                task.wait(Delay.Value)
	            until not ChatSpammer.Enabled
	        else
	            if OldChat then
	                hookfunction(getconnections(ReplicatedStorage.DefaultChatSystemChatEvents.OnNewSystemMessage.OnClientEvent)[1].Function, OldChat)
	            end
	        end
	    end,
	    Tooltip = "Automatically types in chat"
	})
	
	Lines = ChatSpammer:CreateTextList({
	    Name = "Lines",
	    Function = function()
	        table.clear(RandomList)
	    end
	})
	Mode = ChatSpammer:CreateDropdown({
	    Name = "Mode",
	    List = {"Random", "Order"}
	})
	Delay = ChatSpammer:CreateSlider({
	    Name = "Delay",
	    Min = 0.1,
	    Max = 10,
	    Default = 1,
	    Decimal = 10,
	    Suffix = function(Val: number)
	        return Val == 1 and "second" or "seconds"
	    end
	})
	Hide = ChatSpammer:CreateToggle({
	    Name = "Hide Flood Message",
	    Function = function()
	        if ChatSpammer.Enabled then
	            ChatSpammer:Toggle()
	            ChatSpammer:Toggle()
	        end
	    end,
	    Default = true
	})
end)

Run(function()
	local Disabler
	
	local function Added(Character)
	    for _, v: any in getconnections(Character.RootPart:GetPropertyChangedSignal("CFrame")) do
	        hookfunction(v.Function, function() end)
	    end
	
	    for _, v: any in getconnections(Character.RootPart:GetPropertyChangedSignal("Velocity")) do
	        hookfunction(v.Function, function() end)
	    end
	end
	
	Disabler = vape.Categories.Utility:CreateModule({
	    Name = "Disabler",
	    Function = function(Callback: boolean)
	        if Callback then
	            Disabler:Clean(Entity.Events.LocalAdded:Connect(Added))
	            if Entity.isAlive then
	                Added(Entity.character)
	            end
	        end
	    end,
	    Tooltip = "Disables GetPropertyChangedSignal detections for movement"
	})
end)

Run(function()
	local ConfirmTime: number = tick()
	local Panic
	
	Panic = vape.Categories.Utility:CreateModule({
	    Name = "Panic",
	    Function = function(Callback: boolean)
	        if Callback then
	            if ConfirmTime > tick() then
	                for _, v: any in vape.Modules do
	                    if v.Enabled then
	                        v:Toggle()
	                    end
	                end
	            else
	                SendNotification("Panic", "Re-enable panic to confirm", 5, "info")
	                ConfirmTime = tick() + 1
	                Panic:Toggle()
	            end
	        end
	    end,
	    Tooltip = "Disables all currently enabled modules"
	})
end)

Run(function()
	local Rejoin
	
	Rejoin = vape.Categories.Utility:CreateModule({
	    Name = "Rejoin",
	    Function = function(Callback: boolean)
	        if Callback then
	            SendNotification("Rejoin", "Rejoining...", 5)
	            Rejoin:Toggle()
	
	            if Players.NumPlayers > 1 then
	                TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId)
	            else
	                TeleportService:Teleport(game.PlaceId)
	            end
	        end
	    end,
	    Tooltip = "Rejoins the server"
	})
end)

Run(function()
	local ServerHop
	local Sort
	
	ServerHop = vape.Categories.Utility:CreateModule({
	    Name = "ServerHop",
	    Function = function(Callback: boolean)
	        if Callback then
	            ServerHop:Toggle()
	            HopServer(nil, Sort.Value)
	        end
	    end,
	    Tooltip = "Teleports into a unique server"
	})
	
	Sort = ServerHop:CreateDropdown({
	    Name = "Sort",
	    List = {"Descending", "Ascending"},
	    Tooltip = "Descending - Prefers full servers\nAscending - Prefers empty servers"
	})
	ServerHop:CreateButton({
	    Name = "Rejoin Previous Server",
	    Function = function()
	        SendNotification("ServerHop", shared.vapeserverhopprevious and "Rejoining previous server..." or "Cannot find previous server", 5)
	        if shared.vapeserverhopprevious then
	            TeleportService:TeleportToPlaceInstance(game.PlaceId, shared.vapeserverhopprevious)
	        end
	    end
	})
end)

Run(function()
	local StaffDetector
	local Mode
	local Profile
	local Users
	local Group
	local Role
	
	local function Added(Player: Player)
	    if not vape.Loaded then
	        repeat
	            task.wait()
	        until vape.Loaded
	    end
	
	    local User: number? = table.find(Users.ListEnabled, tostring(Player.UserId))
	    local Success, Rank
	    if not User then
	        for _ = 1, 3 do
	            Success, Rank = pcall(function()
	                return Player:GetRankInGroup(tonumber(Group.Value) or 0)
	            end)
	            if Success then
	                break
	            end
	        end
	    end
	
	    if User or (Success and Rank or 0) >= (tonumber(Role.Value) or 1) then
	        SendNotification("StaffDetector", `Staff Detected ({User and "blacklisted_user" or "staff_role"}): {Player.Name}`, 60, "alert")
	        Whitelist.customtags[Player.Name] = {{text = "GAME STAFF", color = Color3.new(1, 0, 0)}}
	
	        if Mode.Value == "Uninject" then
	            task.spawn(function()
	                vape:Uninject()
	            end)
	            game:GetService("StarterGui"):SetCore("SendNotification", {
	                Title = "StaffDetector",
	                Text = `Staff Detected\n{Player.Name}`,
	                Duration = 60,
	            })
	        elseif Mode.Value == "ServerHop" then
	            HopServer()
	        elseif Mode.Value == "Profile" then
	            vape.Save = function() end
	            if vape.Profile ~= Profile.Value then
	                vape.Profile = Profile.Value
	                vape:Load(true, Profile.Value)
	            end
	        elseif Mode.Value == "AutoConfig" then
	            vape.Save = function() end
	            for _, v: any in vape.Modules do
	                if v.Enabled then
	                    v:Toggle()
	                end
	            end
	        end
	    end
	end
	
	StaffDetector = vape.Categories.Utility:CreateModule({
	    Name = "StaffDetector",
	    Function = function(Callback: boolean)
	        if Callback then
	            if Group.Value == "" or Role.Value == "" then
	                local PlaceInfo = {Creator = {CreatorTargetId = tonumber(Group.Value)}}
	                if Group.Value == "" then
	                    PlaceInfo = MarketplaceService:GetProductInfo(game.PlaceId)
	                    if PlaceInfo.Creator.CreatorType ~= "Group" then
	                        local Description: {string} = PlaceInfo.Description:split("\n")
	                        for _, v: string in Description do
	                            local _, Begin = v:find("roblox.com/groups/")
	                            if Begin then
	                                local EndOf: number? = v:find("/", Begin + 1)
	                                PlaceInfo = {Creator = {
	                                    CreatorType = "Group",
	                                    CreatorTargetId = v:sub(Begin + 1, EndOf - 1)
	                                }}
	                            end
	                        end
	                    end
	
	                    if PlaceInfo.Creator.CreatorType ~= "Group" then
	                        SendNotification("StaffDetector", "Automatic Setup Failed (no group detected)", 60, "warning")
	                        return
	                    end
	                end
	
	                local GroupInfo = GroupService:GetGroupInfoAsync(PlaceInfo.Creator.CreatorTargetId)
	                Group:SetValue(PlaceInfo.Creator.CreatorTargetId)
	                local Highest: number = math.huge
	                for _, v: any in GroupInfo.Roles do
	                    local Lower: string = v.Name:lower()
	                    if (Lower:find("admin") or Lower:find("mod") or Lower:find("dev")) and v.Rank < Highest then
	                        Highest = v.Rank
	                    end
	                end
	
	                Role:SetValue(Highest)
	            end
	
	            if Group.Value == "" or Role.Value == "" then
	                return
	            end
	
	            StaffDetector:Clean(Players.PlayerAdded:Connect(Added))
	            for _, v: Player in Players:GetPlayers() do
	                task.spawn(Added, v)
	            end
	        end
	    end,
	    Tooltip = "Detects people with a staff rank ingame"
	})
	
	Mode = StaffDetector:CreateDropdown({
	    Name = "Mode",
	    List = {"Uninject", "ServerHop", "Profile", "AutoConfig", "Notify"},
	    Function = function(Val: string)
	        if Profile.Object then
	            Profile.Object.Visible = Val == "Profile"
	        end
	    end
	})
	Profile = StaffDetector:CreateTextBox({
	    Name = "Profile",
	    Default = "default",
	    Darker = true,
	    Visible = false
	})
	Users = StaffDetector:CreateTextList({
	    Name = "Users",
	    Placeholder = "player (userid)"
	})
	Group = StaffDetector:CreateTextBox({
	    Name = "Group",
	    Placeholder = "Group Id"
	})
	Role = StaffDetector:CreateTextBox({
	    Name = "Role",
	    Placeholder = "Role Rank"
	})
end)

Run(function()
	local Connections = {}
	
	vape.Categories.World:CreateModule({
	    Name = "Anti-AFK",
	    Function = function(Callback: boolean)
	        for _, Connection: any in getconnections(LocalPlayer.Idled) do
	            Connection[Callback and "Disable" or "Enable"](Connection)
	        end
	    end,
	    Tooltip = "Lets you stay ingame without getting kicked"
	})
end)

Run(function()
	local Freecam
	local Value
	local RandomKey, Module, Old = HttpService:GenerateGUID(false)
	local Controls, TouchUp = nil, 0
	
	Freecam = vape.Categories.World:CreateModule({
	    Name = "Freecam",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                task.wait(0.1)
	                for _, v: any in getconnections(Camera:GetPropertyChangedSignal("CameraType")) do
	                    if v.Function then
	                        Module = debug.getupvalue(v.Function, 1)
	                    end
	                end
	            until Module or not Freecam.Enabled
	
	            if Module and Module.activeCameraController and Freecam.Enabled then
	                Old = Module.activeCameraController.GetSubjectPosition
	                local CameraPosition: Vector3 = Old(Module.activeCameraController) or Vector3.zero
	                Module.activeCameraController.GetSubjectPosition = function()
	                    return CameraPosition
	                end
	
	                Freecam:Clean(RunService.PreSimulation:Connect(function(Delta: number)
	                    if not UserInputService:GetFocusedTextBox() then
	                        if not Controls then
	                            local Loaded, Result = pcall(function()
	                                return require(LocalPlayer.PlayerScripts:WaitForChild("PlayerModule", 5)):GetControls()
	                            end)
	                            Controls = Loaded and Result or nil
	                        end
	
	                        local Moved, Vector = pcall(function()
	                            return Controls:GetMoveVector()
	                        end)
	                        local MoveVector: Vector3 = Moved and Vector or Vector3.zero
	                        local Forward: number = (UserInputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0) + (UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0) + MoveVector.Z
	                        local Side: number = (UserInputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0) + (UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0) + MoveVector.X
	                        local Up: number = (UserInputService:IsKeyDown(Enum.KeyCode.Q) and -1 or 0) + (UserInputService:IsKeyDown(Enum.KeyCode.E) and 1 or 0) + TouchUp
	                        Delta = Delta * (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) and 0.25 or 1)
	                        CameraPosition = (CFrame.lookAlong(CameraPosition, Camera.CFrame.LookVector) * CFrame.new(Vector3.new(Side, Up, Forward) * (Value.Value * Delta))).Position
	                    end
	                end))
	
	                if UserInputService.TouchEnabled then
	                    pcall(function()
	                        local JumpButton: ImageButton = LocalPlayer.PlayerGui.TouchGui.TouchControlFrame.JumpButton
	                        Freecam:Clean(JumpButton:GetPropertyChangedSignal("ImageRectOffset"):Connect(function()
	                            TouchUp = JumpButton.ImageRectOffset.X == 146 and 1 or 0
	                        end))
	                    end)
	                end
	
	                ContextActionService:BindActionAtPriority(`FreecamKeyboard{RandomKey}`, function()
	                    return Enum.ContextActionResult.Sink
	                end, false, Enum.ContextActionPriority.High.Value,
	                    Enum.KeyCode.W,
	                    Enum.KeyCode.A,
	                    Enum.KeyCode.S,
	                    Enum.KeyCode.D,
	                    Enum.KeyCode.E,
	                    Enum.KeyCode.Q,
	                    Enum.KeyCode.Up,
	                    Enum.KeyCode.Down
	                )
	            end
	        else
	            TouchUp = 0
	            pcall(function()
	                ContextActionService:UnbindAction(`FreecamKeyboard{RandomKey}`)
	            end)
	            if Module and Old then
	                Module.activeCameraController.GetSubjectPosition = Old
	                Module = nil
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Lets you fly and clip through walls freely\nwithout moving your player server-sided."
	})
	
	Value = Freecam:CreateSlider({
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
	local Gravity
	local Mode
	local Value
	local Changed, Old = false
	
	Gravity = vape.Categories.World:CreateModule({
	    Name = "Gravity",
	    Function = function(Callback: boolean)
	        if Callback then
	            if Mode.Value == "Workspace" then
	                Old = workspace.Gravity
	                workspace.Gravity = Value.Value
	                Gravity:Clean(workspace:GetPropertyChangedSignal("Gravity"):Connect(function()
	                    if Changed then
	                        return
	                    end
	                    Changed = true
	                    Old = workspace.Gravity
	                    workspace.Gravity = Value.Value
	                    Changed = false
	                end))
	            else
	                Gravity:Clean(RunService.PreSimulation:Connect(function(Delta: number)
	                    if Entity.isAlive and Entity.character.Humanoid.FloorMaterial == Enum.Material.Air then
	                        local Root: BasePart = Entity.character.RootPart
	                        if Mode.Value == "Impulse" then
	                            Root:ApplyImpulse(Vector3.new(0, Delta * (workspace.Gravity - Value.Value), 0) * Root.AssemblyMass)
	                        else
	                            Root.AssemblyLinearVelocity += Vector3.new(0, Delta * (workspace.Gravity - Value.Value), 0)
	                        end
	                    end
	                end))
	            end
	        else
	            if Old then
	                workspace.Gravity = Old
	                Old = nil
	            end
	        end
	    end,
	    Tooltip = "Changes the rate you fall"
	})
	
	Mode = Gravity:CreateDropdown({
	    Name = "Mode",
	    List = {"Workspace", "Velocity", "Impulse"},
	    Tooltip = "Workspace - Adjusts the gravity for the entire game\nVelocity - Adjusts the local players gravity\nImpulse - Same as velocity while using forces instead"
	})
	Value = Gravity:CreateSlider({
	    Name = "Gravity",
	    Min = 0,
	    Max = 192,
	    Function = function(Val: number)
	        if Gravity.Enabled and Mode.Value == "Workspace" then
	            Changed = true
	            workspace.Gravity = Val
	            Changed = false
	        end
	    end,
	    Default = 192
	})
end)

Run(function()
	local Parkour
	
	Parkour = vape.Categories.World:CreateModule({
	    Name = "Parkour",
	    Function = function(Callback: boolean)
	        if Callback then
	            local OldFloor: Enum.Material?
	            Parkour:Clean(RunService.RenderStepped:Connect(function()
	                if Entity.isAlive then
	                    local Material: Enum.Material = Entity.character.Humanoid.FloorMaterial
	                    if Material == Enum.Material.Air and OldFloor ~= Enum.Material.Air then
	                        Entity.character.Humanoid.Jump = true
	                    end
	                    OldFloor = Material
	                end
	            end))
	        end
	    end,
	    Tooltip = "Automatically jumps after reaching the edge"
	})
end)

Run(function()
	local PromptChanger
	local Mode
	local Distance
	local Hold
	local Sight
	local Modified = setmetatable({}, {__mode = "k"})
	local Thread: thread?
	
	local function ChangePrompt(Prompt: Instance)
	    if not Prompt:IsA("ProximityPrompt") then
	        return
	    end
	
	    if not Modified[Prompt] then
	        Modified[Prompt] = {Distance = Prompt.MaxActivationDistance, Hold = Prompt.HoldDuration, Sight = Prompt.RequiresLineOfSight}
	    end
	
	    Prompt.MaxActivationDistance = Distance.Value
	    if Sight.Enabled then
	        Prompt.RequiresLineOfSight = false
	    end
	
	    if Mode.Value == "Property" then
	        Prompt.HoldDuration = Modified[Prompt].Hold * (Hold.Value / 100)
	    end
	end
	
	PromptChanger = vape.Categories.World:CreateModule({
	    Name = "PromptChanger",
	    Function = function(Callback: boolean)
	        if Callback then
	            PromptChanger:Clean(workspace.DescendantAdded:Connect(ChangePrompt))
	            for _, v: Instance in workspace:GetDescendants() do
	                ChangePrompt(v)
	            end
	
	            if Mode.Value == "Signal" then
	                PromptChanger:Clean(ProximityPromptService.PromptButtonHoldBegan:Connect(function(Prompt: ProximityPrompt, Player: Player)
	                    if Player == LocalPlayer then
	                        Thread = task.delay(Prompt.HoldDuration * (Hold.Value / 100), function()
	                            fireproximityprompt(Prompt)
	                            Thread = nil
	                        end)
	                    end
	                end))
	
	                PromptChanger:Clean(ProximityPromptService.PromptButtonHoldEnded:Connect(function(Prompt: ProximityPrompt, Player: Player)
	                    if Player == LocalPlayer and Thread then
	                        task.cancel(Thread)
	                        Thread = nil
	                    end
	                end))
	            end
	        else
	            if Thread then
	                task.cancel(Thread)
	                Thread = nil
	            end
	
	            for Prompt: ProximityPrompt, v: {Distance: number, Hold: number, Sight: boolean} in Modified do
	                Prompt.MaxActivationDistance = v.Distance
	                Prompt.HoldDuration = v.Hold
	                Prompt.RequiresLineOfSight = v.Sight
	            end
	
	            table.clear(Modified)
	        end
	    end,
	    Tooltip = "Lets you use proximity prompts from further away and hold them for less time"
	})
	
	Mode = PromptChanger:CreateDropdown({
	    Name = "Mode",
	    List = {"Property", "Signal"},
	    Function = function()
	        if PromptChanger.Enabled then
	            PromptChanger:Toggle()
	            PromptChanger:Toggle()
	        end
	    end,
	    Tooltip = "Property - Writes the hold time onto every prompt\nSignal - Leaves the prompt alone and fires it early instead"
	})
	Distance = PromptChanger:CreateSlider({
	    Name = "Distance",
	    Min = 1,
	    Max = 500,
	    Function = function(Val: number)
	        for Prompt: ProximityPrompt in Modified do
	            Prompt.MaxActivationDistance = Val
	        end
	    end,
	    Suffix = function(Val: number)
	        return Val > 1 and "studs" or "stud"
	    end,
	    Default = 50
	})
	Hold = PromptChanger:CreateSlider({
	    Name = "Hold time",
	    Min = 0,
	    Max = 100,
	    Function = function(Val: number)
	        if Mode.Value == "Property" then
	            for Prompt: ProximityPrompt, v: {Distance: number, Hold: number, Sight: boolean} in Modified do
	                Prompt.HoldDuration = v.Hold * (Val / 100)
	            end
	        end
	    end,
	    Suffix = "%",
	    Default = 0,
	    Tooltip = "How much of the original hold time you still have to wait"
	})
	Sight = PromptChanger:CreateToggle({
	    Name = "Through walls",
	    Function = function(Callback: boolean)
	        for Prompt: ProximityPrompt, v: {Distance: number, Hold: number, Sight: boolean} in Modified do
	            Prompt.RequiresLineOfSight = not Callback and v.Sight
	        end
	    end,
	    Tooltip = "Also removes the line of sight requirement"
	})
end)

Run(function()
	local RayCheck: RaycastParams = RaycastParams.new()
	RayCheck.RespectCanCollide = true
	local Module, Old
	
	vape.Categories.World:CreateModule({
	    Name = "SafeWalk",
	    Function = function(Callback: boolean)
	        if Callback then
	            if not Module then
	                local Success: boolean = pcall(function()
	                    Module = require(LocalPlayer.PlayerScripts.PlayerModule).controls
	                end)
	                if not Success then
	                    Module = {}
	                end
	            end
	
	            Old = Module.moveFunction
	            Module.moveFunction = function(self, Vector: Vector3, Face: boolean)
	                if Entity.isAlive then
	                    RayCheck.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
	                    local Root: BasePart = Entity.character.RootPart
	                    local MovePosition: Vector3 = Root.Position + Vector
	                    local Ray: RaycastResult? = workspace:Raycast(MovePosition, Vector3.new(0, -15, 0), RayCheck)
	                    if not Ray then
	                        local Ground: RaycastResult? = workspace:Blockcast(Root.CFrame, Vector3.new(3, 1, 3), Vector3.new(0, -(Entity.character.HipHeight + 1), 0), RayCheck)
	                        if Ground then
	                            Vector = (Ground.Instance:GetClosestPointOnSurface(MovePosition) - Root.Position) * Vector3.new(1, 0, 1)
	                        end
	                    end
	                end
	
	                return Old(self, Vector, Face)
	            end
	        else
	            if Module and Old then
	                Module.moveFunction = Old
	            end
	        end
	    end,
	    Tooltip = "Prevents you from walking off the edge of parts"
	})
end)

Run(function()
	local Wallhop
	local Offset
	local FPSCap
	local OverlapCheck: OverlapParams = OverlapParams.new()
	OverlapCheck.RespectCanCollide = true
	local OldFPS: number?
	local Timeout: number = os.clock()
	local SavedRotation
	
	local function DoCheck()
	    if SavedRotation then
	        Camera.CFrame = CFrame.new(Camera.CFrame.Position.X, Camera.CFrame.Position.Y, Camera.CFrame.Position.Z, unpack(SavedRotation, 4, SavedRotation.n))
	        SavedRotation = nil
	    end
	
	    local Humanoid = Entity.isAlive and Entity.character.Humanoid
	    if Humanoid and Humanoid.Jump and Humanoid.MoveDirection.Magnitude > 0 then
	        local Root: BasePart = Entity.character.RootPart
	        OverlapCheck.CollisionGroup = Root.CollisionGroup
	        OverlapCheck.FilterDescendantsInstances = {LocalPlayer.Character}
	
	        if Root.AssemblyLinearVelocity.Y < 0 and Humanoid.FloorMaterial == Enum.Material.Air then
	            local Parts: {BasePart} = workspace:GetPartBoundsInBox(CFrame.new(Root.Position - Vector3.new(0, Entity.character.HipHeight / 2, 0)), Vector3.new(3, Entity.character.HipHeight, 3), OverlapCheck)
	            local DoHop: boolean = false
	
	            for _, v: BasePart in Parts do
	                local Position: Vector3 = v:GetClosestPointOnSurface(Root.Position)
	                local Difference: number = (Root.Position.Y - Position.Y)
	                if Difference > Root.Size.Y / 2 then
	                    DoHop = true
	                    break
	                end
	            end
	
	            if DoHop and (os.clock() - Timeout) > 0.2 then
	                SavedRotation = table.pack(Camera.CFrame:GetComponents())
	                Camera.CFrame *= CFrame.Angles(0, math.rad(Offset.Value), 0)
	                Timeout = os.clock()
	            end
	        end
	    end
	end
	
	Wallhop = vape.Categories.World:CreateModule({
	    Name = "Wallhop",
	    Function = function(Callback: boolean)
	        if Callback then
	            if FPSCap.Enabled then
					OldFPS = getfpscap()
					setfpscap(60)
				end
	
	            if workspace.AuthorityMode == Enum.AuthorityMode.Server then
	                Wallhop:Clean(RunService:BindToSimulation(DoCheck))
	            else
	                Wallhop:Clean(RunService.PreRender:Connect(DoCheck))
	            end
	        else
	            if OldFPS then
	                setfpscap(OldFPS)
	                OldFPS = nil
	            end
	            SavedRotation = nil
	        end
	    end,
	    Tooltip = "Automatically rotates camera for wallhopping."
	})
	
	Offset = Wallhop:CreateSlider({
	    Name = "Offset",
	    Min = -45,
	    Max = 45,
	    Default = 45,
	    Suffix = "degrees"
	})
	FPSCap = Wallhop:CreateToggle({
		Name = "FPS Cap",
		Function = function()
			if Wallhop.Enabled then
				Wallhop:Toggle()
				Wallhop:Toggle()
			end
		end,
		Tootip = "Set the FPS to 60 while the module is enabled."
	})
end)

Run(function()
	local Xray
	local List
	local Modified: {[BasePart]: boolean} = {}
	
	local function ModifyPart(Part: Instance)
	    if Part:IsA("BasePart") and not table.find(List.ListEnabled, Part.Name) then
	        Modified[Part] = true
	        Part.LocalTransparencyModifier = 0.5
	    end
	end
	
	Xray = vape.Categories.World:CreateModule({
	    Name = "Xray",
	    Function = function(Callback: boolean)
	        if Callback then
	            Xray:Clean(workspace.DescendantAdded:Connect(ModifyPart))
	            for _, v: Instance in workspace:GetDescendants() do
	                ModifyPart(v)
	            end
	        else
	            for Part: BasePart in Modified do
	                Part.LocalTransparencyModifier = 0
	            end
	            table.clear(Modified)
	        end
	    end,
	    Tooltip = "Renders whitelisted parts through walls."
	})
	
	List = Xray:CreateTextList({
	    Name = "Part",
	    Function = function()
	        if Xray.Enabled then
	            Xray:Toggle()
	            Xray:Toggle()
	        end
	    end
	})
end)

Run(function()
	local Atmosphere
	local Toggles = {}
	local NewObjects, OldObjects = {}, {}
	local ApiDump: {[string]: {[string]: string}} = {
	    Sky = {
	        SkyboxUp = "Text",
	        SkyboxDn = "Text",
	        SkyboxLf = "Text",
	        SkyboxRt = "Text",
	        SkyboxFt = "Text",
	        SkyboxBk = "Text",
	        SunTextureId = "Text",
	        SunAngularSize = "Number",
	        MoonTextureId = "Text",
	        MoonAngularSize = "Number",
	        StarCount = "Number"
	    },
	    Atmosphere = {
	        Color = "Color",
	        Decay = "Color",
	        Density = "Number",
	        Offset = "Number",
	        Glare = "Number",
	        Haze = "Number"
	    },
	    BloomEffect = {
	        Intensity = "Number",
	        Size = "Number",
	        Threshold = "Number"
	    },
	    DepthOfFieldEffect = {
	        FarIntensity = "Number",
	        FocusDistance = "Number",
	        InFocusRadius = "Number",
	        NearIntensity = "Number"
	    },
	    SunRaysEffect = {
	        Intensity = "Number",
	        Spread = "Number"
	    },
	    ColorCorrectionEffect = {
	        TintColor = "Color",
	        Saturation = "Number",
	        Contrast = "Number",
	        Brightness = "Number"
	    }
	}
	
	local function RemoveObject(Object: Instance)
	    if not table.find(NewObjects, Object) then
	        local ClassToggle = Toggles[Object.ClassName]
	        if ClassToggle and ClassToggle.Toggle.Enabled then
	            if Object.Parent then
	                table.insert(OldObjects, Object)
	                Object.Parent = game
	            end
	        end
	    end
	end
	
	Atmosphere = vape.Legit:CreateModule({
	    Name = "Atmosphere",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_atmosphere.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            for _, v: Instance in Lighting:GetChildren() do
	                RemoveObject(v)
	            end
	
	            Atmosphere:Clean(Lighting.ChildAdded:Connect(function(Child: Instance)
	                task.defer(RemoveObject, Child)
	            end))
	
	            for ClassName: string, v: any in Toggles do
	                if v.Toggle.Enabled then
	                    local Object: Instance = Instance.new(ClassName)
	                    for Property: string, Option: any in v.Objects do
	                        if Option.Type == "ColorSlider" then
	                            Object[Property] = Color3.fromHSV(Option.Hue, Option.Sat, Option.Value)
	                        else
	                            Object[Property] = ApiDump[ClassName][Property] ~= "Number" and Option.Value or tonumber(Option.Value) or 0
	                        end
	                    end
	                    Object.Parent = Lighting
	                    table.insert(NewObjects, Object)
	                end
	            end
	        else
	            for _, v: Instance in NewObjects do
	                v:Destroy()
	            end
	
	            for _, v: Instance in OldObjects do
	                v.Parent = Lighting
	            end
	
	            table.clear(NewObjects)
	            table.clear(OldObjects)
	        end
	    end,
	    Tooltip = "Custom lighting objects"
	})
	
	for ClassName: string, Properties: {[string]: string} in ApiDump do
	    Toggles[ClassName] = {Objects = {}}
	    Toggles[ClassName].Toggle = Atmosphere:CreateToggle({
	        Name = ClassName,
	        Function = function(Callback: boolean)
	            if Atmosphere.Enabled then
	                Atmosphere:Toggle()
	                Atmosphere:Toggle()
	            end
	
	            for _, v: any in Toggles[ClassName].Objects do
	                v.Object.Visible = Callback
	            end
	        end
	    })
	
	    for Property: string, PropertyType: string in Properties do
	        if PropertyType == "Text" or PropertyType == "Number" then
	            Toggles[ClassName].Objects[Property] = Atmosphere:CreateTextBox({
	                Name = Property,
	                Function = function(Enter: boolean)
	                    if Atmosphere.Enabled and Enter then
	                        Atmosphere:Toggle()
	                        Atmosphere:Toggle()
	                    end
	                end,
	                Darker = true,
	                Default = PropertyType == "Number" and "0" or nil,
	                Visible = false
	            })
	        elseif PropertyType == "Color" then
	            Toggles[ClassName].Objects[Property] = Atmosphere:CreateColorSlider({
	                Name = Property,
	                Function = function()
	                    if Atmosphere.Enabled then
	                        Atmosphere:Toggle()
	                        Atmosphere:Toggle()
	                    end
	                end,
	                Darker = true,
	                Visible = false
	            })
	        end
	    end
	end
end)

Run(function()
	local Breadcrumbs
	local Texture
	local Lifetime
	local Thickness
	local FadeIn
	local FadeOut
	local Trail, Point, Point2
	
	Breadcrumbs = vape.Legit:CreateModule({
	    Name = "Breadcrumbs",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_breadcrumbs.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            Point = Instance.new("Attachment")
	            Point.Position = Vector3.new(0, Thickness.Value - 2.7, 0)
	            Point2 = Instance.new("Attachment")
	            Point2.Position = Vector3.new(0, -Thickness.Value - 2.7, 0)
	            Trail = Instance.new("Trail")
	            Trail.Texture = Texture.Value == "" and "http://www.roblox.com/asset/?id=14166981368" or Texture.Value
	            Trail.TextureMode = Enum.TextureMode.Static
	            Trail.Color = ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value))
	            Trail.Lifetime = Lifetime.Value
	            Trail.Attachment0 = Point
	            Trail.Attachment1 = Point2
	            Trail.FaceCamera = true
	
	            Breadcrumbs:Clean(Trail)
	            Breadcrumbs:Clean(Point)
	            Breadcrumbs:Clean(Point2)
	            Breadcrumbs:Clean(Entity.Events.LocalAdded:Connect(function(Ent)
	                Point.Parent = Ent.HumanoidRootPart
	                Point2.Parent = Ent.HumanoidRootPart
	                Trail.Parent = Camera
	            end))
	
	            if Entity.isAlive then
	                Point.Parent = Entity.character.RootPart
	                Point2.Parent = Entity.character.RootPart
	                Trail.Parent = Camera
	            end
	        else
	            Trail = nil
	            Point = nil
	            Point2 = nil
	        end
	    end,
	    Tooltip = "Shows a trail behind your character"
	})
	
	Texture = Breadcrumbs:CreateTextBox({
	    Name = "Texture",
	    Placeholder = "Texture Id",
	    Function = function(Enter: boolean)
	        if Enter and Trail then
	            Trail.Texture = Texture.Value == "" and "http://www.roblox.com/asset/?id=14166981368" or Texture.Value
	        end
	    end
	})
	FadeIn = Breadcrumbs:CreateColorSlider({
	    Name = "Fade In",
	    Function = function(Hue: number, Sat: number, Val: number)
	        if Trail then
	            Trail.Color = ColorSequence.new(Color3.fromHSV(Hue, Sat, Val), Color3.fromHSV(FadeOut.Hue, FadeOut.Sat, FadeOut.Value))
	        end
	    end
	})
	FadeOut = Breadcrumbs:CreateColorSlider({
	    Name = "Fade Out",
	    Function = function(Hue: number, Sat: number, Val: number)
	        if Trail then
	            Trail.Color = ColorSequence.new(Color3.fromHSV(FadeIn.Hue, FadeIn.Sat, FadeIn.Value), Color3.fromHSV(Hue, Sat, Val))
	        end
	    end
	})
	Lifetime = Breadcrumbs:CreateSlider({
	    Name = "Lifetime",
	    Min = 1,
	    Max = 5,
	    Decimal = 10,
	    Function = function(Val: number)
	        if Trail then
	            Trail.Lifetime = Val
	        end
	    end,
	    Suffix = function(Val: number)
	        return Val == 1 and "second" or "seconds"
	    end,
	    Default = 3
	})
	Thickness = Breadcrumbs:CreateSlider({
	    Name = "Thickness",
	    Min = 0,
	    Max = 2,
	    Decimal = 100,
	    Function = function(Val: number)
	        if Point then
	            Point.Position = Vector3.new(0, Val - 2.7, 0)
	        end
	        if Point2 then
	            Point2.Position = Vector3.new(0, -Val - 2.7, 0)
	        end
	    end,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end,
	    Default = 0.1
	})
end)

Run(function()
	local Cape
	local Texture
	local Part, Motor
	
	local function CreateMotor(Ent)
	    if Motor then
	        Motor:Destroy()
	    end
	
	    Part.Parent = Camera
	    Motor = Instance.new("Motor6D")
	    Motor.MaxVelocity = 0.08
	    Motor.Part0 = Part
	    Motor.Part1 = Ent.Character:FindFirstChild("UpperTorso") or Ent.RootPart
	    Motor.C0 = CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(-90), 0)
	    Motor.C1 = CFrame.new(0, Motor.Part1.Size.Y / 2, 0.45) * CFrame.Angles(0, math.rad(90), 0)
	    Motor.Parent = Part
	end
	
	Cape = vape.Legit:CreateModule({
	    Name = "Cape",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_cape.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            Part = Instance.new("Part")
	            Part.Size = Vector3.new(2, 4, 0.1)
	            Part.CanCollide = false
	            Part.CanQuery = false
	            Part.Massless = true
	            Part.Transparency = 0
	            Part.Material = Enum.Material.SmoothPlastic
	            Part.Color = Color3.new()
	            Part.CastShadow = false
	            Part.Parent = Camera
	            local CapeSurface: SurfaceGui = Instance.new("SurfaceGui")
	            CapeSurface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	            CapeSurface.Adornee = Part
	            CapeSurface.Parent = Part
	
	            if Texture.Value:find(".webm") then
	                local Decal: VideoFrame = Instance.new("VideoFrame")
	                Decal.Video = GetVapeAsset(Texture.Value)
	                Decal.Size = UDim2.fromScale(1, 1)
	                Decal.BackgroundTransparency = 1
	                Decal.Looped = true
	                Decal.Parent = CapeSurface
	                Decal:Play()
	            else
	                local Decal: ImageLabel = Instance.new("ImageLabel")
	                Decal.Image = Texture.Value ~= "" and (Texture.Value:find("rbxasset") and Texture.Value or AssetFunction(Texture.Value)) or "rbxassetid://14637958134"
	                Decal.Size = UDim2.fromScale(1, 1)
	                Decal.BackgroundTransparency = 1
	                Decal.Parent = CapeSurface
	            end
	
	            Cape:Clean(Part)
	            Cape:Clean(Entity.Events.LocalAdded:Connect(CreateMotor))
	            if Entity.isAlive then
	                CreateMotor(Entity.character)
	            end
	
	            repeat
	                if Motor and Entity.isAlive then
	                    local Velocity: number = math.min(Entity.character.RootPart.AssemblyLinearVelocity.Magnitude, 90)
	                    Motor.DesiredAngle = math.rad(6) + math.rad(Velocity) + (Velocity > 1 and math.abs(math.cos(tick() * 5)) / 3 or 0)
	                end
	                CapeSurface.Enabled = (Camera.CFrame.Position - Camera.Focus.Position).Magnitude > 0.6
	                Part.Transparency = (Camera.CFrame.Position - Camera.Focus.Position).Magnitude > 0.6 and 0 or 1
	                task.wait()
	            until not Cape.Enabled
	        else
	            Part = nil
	            Motor = nil
	        end
	    end,
	    Tooltip = "Add's a cape to your character"
	})
	
	Texture = Cape:CreateTextBox({
	    Name = "Texture"
	})
end)

Run(function()
	local ChinaHat
	local Material
	local Color
	local Hat: MeshPart?
	
	ChinaHat = vape.Legit:CreateModule({
	    Name = "China Hat",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_chinahat.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            if vape.ThreadFix then
	                setthreadidentity(8)
	            end
	
	            Hat = Instance.new("MeshPart")
	            Hat.Size = Vector3.new(3, 0.7, 3)
	            Hat.Name = "ChinaHat"
	            Hat.Material = Enum.Material[Material.Value]
	            Hat.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	            Hat.CanCollide = false
	            Hat.CanQuery = false
	            Hat.Massless = true
	            Hat.MeshId = "http://www.roblox.com/asset/?id=1778999"
	            Hat.Transparency = 1 - Color.Opacity
	            Hat.Parent = Camera
	            Hat.CFrame = Entity.isAlive and Entity.character.Head.CFrame + Vector3.new(0, 1, 0) or CFrame.identity
	            local Weld: WeldConstraint = Instance.new("WeldConstraint")
	            Weld.Part0 = Hat
	            Weld.Part1 = Entity.isAlive and Entity.character.Head or nil
	            Weld.Parent = Hat
	
	            ChinaHat:Clean(Hat)
	            ChinaHat:Clean(Entity.Events.LocalAdded:Connect(function(Ent)
	                if Weld then
	                    Weld:Destroy()
	                end
	                Hat.Parent = Camera
	                Hat.CFrame = Ent.Head.CFrame + Vector3.new(0, 1, 0)
	                Hat.AssemblyLinearVelocity = Vector3.zero
	                Weld = Instance.new("WeldConstraint")
	                Weld.Part0 = Hat
	                Weld.Part1 = Ent.Head
	                Weld.Parent = Hat
	            end))
	
	            repeat
	                Hat.LocalTransparencyModifier = ((Camera.CFrame.Position - Camera.Focus.Position).Magnitude <= 0.6 and 1 or 0)
	                task.wait()
	            until not ChinaHat.Enabled
	        else
	            Hat = nil
	        end
	    end,
	    Tooltip = "Puts a china hat on your character (ty mastadawn)"
	})
	
	local Materials: {string} = {"ForceField"}
	for _, v: EnumItem in Enum.Material:GetEnumItems() do
	    if v.Name ~= "ForceField" then
	        table.insert(Materials, v.Name)
	    end
	end
	Material = ChinaHat:CreateDropdown({
	    Name = "Material",
	    List = Materials,
	    Function = function(Val: string)
	        if Hat then
	            Hat.Material = Enum.Material[Val]
	        end
	    end
	})
	Color = ChinaHat:CreateColorSlider({
	    Name = "Hat Color",
	    DefaultOpacity = 0.7,
	    Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
	        if Hat then
	            Hat.Color = Color3.fromHSV(Hue, Sat, Val)
	            Hat.Transparency = 1 - Opacity
	        end
	    end
	})
end)

Run(function()
	local Clock
	local ClockType
	local ShowDate
	local TwentyFourHour
	local Background
	local BackgroundColor
	local Shadows: {[TextLabel]: TextLabel} = {}
	local SkippedTicks: {[number]: boolean} = {[8] = true, [9] = true, [10] = true, [14] = true, [15] = true, [16] = true, [20] = true, [21] = true, [22] = true}
	local LocalTime, UtcTime = os.date("*t"), os.date("!*t")
	local TimeZone: number = ((LocalTime.yday - UtcTime.yday) * 24) + LocalTime.hour - UtcTime.hour
	TimeZone = TimeZone > 12 and TimeZone - 24 or (TimeZone < -12 and TimeZone + 24 or TimeZone)
	local AmericanDate: boolean = TimeZone <= -2 and TimeZone >= -11
	local Holder, Analog, Digital, Hand
	local AnalogHour, AnalogMinute, AnalogWeekday, AnalogDate, AnalogMeridiem
	local DigitalHour, DigitalMinute, DigitalMeridiem, DigitalDate, DigitalWeekday
	
	local function AddLabel(Parent: Instance, TextSize: number, Alignment: Enum.TextXAlignment): TextLabel
	    local Label: TextLabel = Instance.new("TextLabel")
	    Label.BackgroundTransparency = 1
	    Label.FontFace = UIPallet.FontDisplay
	    Label.Size = UDim2.fromOffset(200, TextSize + 6)
	    Label.Text = ""
	    Label.TextColor3 = Color3.new(1, 1, 1)
	    Label.TextSize = TextSize
	    Label.TextXAlignment = Alignment
	    Label.Parent = Parent
	    local Shadow: TextLabel = Label:Clone()
	    Shadow.Name = "Shadow"
	    Shadow.TextColor3 = Color3.new()
	    Shadow.TextTransparency = 0.498
	    Shadow.Visible = false
	    Shadow.ZIndex = 0
	    Shadow.Parent = Parent
	    Shadows[Label] = Shadow
	
	    return Label
	end
	
	local function PlaceLabel(Label: TextLabel, X: number, CenterY: number)
	    Label.Position = UDim2.fromOffset(Label.TextXAlignment == Enum.TextXAlignment.Right and X - 200 or X, CenterY - (Label.Size.Y.Offset / 2))
	    Shadows[Label].Position = Label.Position + UDim2.fromOffset(1, 1)
	end
	
	local function RefreshSize()
	    if ClockType.Value == "Digital" then
	        Holder.Size = UDim2.fromOffset(140 + (ShowDate.Enabled and 48 or 0) + (TwentyFourHour.Enabled and 0 or 24), 64)
	        return
	    end
	
	    Holder.Size = UDim2.fromOffset(140, 130)
	end
	
	local function Update()
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    local Now = os.date("*t")
	    local Hour: number = TwentyFourHour.Enabled and Now.hour or (Now.hour > 12 and Now.hour - 12 or (Now.hour == 0 and 12 or Now.hour))
	    local HourText: string = string.format("%02d", Hour)
	    local MinuteText: string = string.format("%02d", Now.min)
	    local Meridiem: string = Now.hour >= 12 and "pm" or "am"
	    local Weekday: string = os.date("%a"):lower()
	    local DateText: string = string.format(ClockType.Value == "Digital" and "%02d / %02d" or "%02d/%02d", AmericanDate and Now.month or Now.day, AmericanDate and Now.day or Now.month)
	
	    if ClockType.Value == "Digital" then
	        DigitalHour.Text = HourText
	        DigitalMinute.Text = MinuteText
	        DigitalMeridiem.Text = Meridiem
	        DigitalDate.Text = DateText
	        DigitalWeekday.Text = Weekday
	        Shadows[DigitalHour].Text = HourText
	        Shadows[DigitalMinute].Text = MinuteText
	        Shadows[DigitalMeridiem].Text = Meridiem
	        Shadows[DigitalDate].Text = DateText
	        Shadows[DigitalWeekday].Text = Weekday
	        PlaceLabel(DigitalMeridiem, 78 + GetFontBounds(MinuteText, 48 * UIPallet.DisplayScale, UIPallet.FontDisplay).X, 46)
	        PlaceLabel(DigitalDate, Holder.Size.X.Offset - 12, 24)
	        PlaceLabel(DigitalWeekday, Holder.Size.X.Offset - 12, 40)
	
	        return
	    end
	
	    AnalogHour.Text = HourText
	    AnalogMinute.Text = MinuteText
	    AnalogWeekday.Text = Weekday
	    AnalogDate.Text = DateText
	    AnalogMeridiem.Text = Meridiem
	    Shadows[AnalogHour].Text = HourText
	    Shadows[AnalogMinute].Text = MinuteText
	    Shadows[AnalogWeekday].Text = Weekday
	    Shadows[AnalogDate].Text = DateText
	    Shadows[AnalogMeridiem].Text = Meridiem
	    Hand.Rotation = (Hour * 30) + (Now.min / 2)
	end
	
	Clock = vape.Legit:CreateModule({
	    Name = "Clock",
	    Category = "HUD",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_clock.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                Update()
	                task.wait(1)
	            until not Clock.Enabled
	        end
	    end,
	    Size = UDim2.fromOffset(140, 130),
	    Tooltip = "Draws a clock with the current real-world time"
	})
	
	ClockType = Clock:CreateDropdown({
	    Name = "Clock Type",
	    List = {"Analog", "Digital"},
	    Function = function(Value: string)
	        if Holder then
	            Analog.Visible = Value == "Analog"
	            Digital.Visible = Value == "Digital"
	            ShowDate.Object.Visible = Value == "Digital"
	            RefreshSize()
	            Update()
	        end
	    end
	})
	ShowDate = Clock:CreateToggle({
	    Name = "Show date",
	    Function = function(Callback: boolean)
	        if Holder then
	            DigitalDate.Visible = Callback
	            DigitalWeekday.Visible = Callback
	            Shadows[DigitalDate].Visible = Callback and not Background.Enabled
	            Shadows[DigitalWeekday].Visible = Callback and not Background.Enabled
	            RefreshSize()
	        end
	    end,
	    Default = true
	})
	TwentyFourHour = Clock:CreateToggle({
	    Name = "24 Hour Time",
	    Function = function(Callback: boolean)
	        if Holder then
	            AnalogMeridiem.Visible = not Callback
	            DigitalMeridiem.Visible = not Callback
	            Shadows[AnalogMeridiem].Visible = not Callback and not Background.Enabled
	            Shadows[DigitalMeridiem].Visible = not Callback and not Background.Enabled
	            RefreshSize()
	            Update()
	        end
	    end
	})
	Background = Clock:CreateToggle({
	    Name = "Render background",
	    Function = function(Callback: boolean)
	        if BackgroundColor then
	            Holder.BackgroundTransparency = Callback and 1 - BackgroundColor.Opacity or 1
	            BackgroundColor.Object.Visible = Callback
	
	            for Label: TextLabel, v: TextLabel in Shadows do
	                v.Visible = not Callback and Label.Visible
	            end
	        end
	    end,
	    Default = true
	})
	BackgroundColor = Clock:CreateColorSlider({
	    Name = "Background Color",
	    DefaultHue = 0.8333,
	    DefaultSat = 0.0385,
	    DefaultValue = 0.102,
	    DefaultOpacity = 0.4,
	    Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
	        if Holder then
	            Holder.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
	            Holder.BackgroundTransparency = Background.Enabled and 1 - Opacity or 1
	        end
	    end,
	    Darker = true
	})
	Holder = Clock.Children
	Holder.BackgroundColor3 = Color3.fromRGB(26, 25, 26)
	Holder.BackgroundTransparency = 0.6
	local HolderCorner: UICorner = Instance.new("UICorner")
	HolderCorner.CornerRadius = UDim.new(0, 4)
	HolderCorner.Parent = Holder
	Analog = Instance.new("Frame")
	Analog.BackgroundTransparency = 1
	Analog.Name = "Analog"
	Analog.Size = UDim2.fromScale(1, 1)
	Analog.Parent = Holder
	Digital = Instance.new("Frame")
	Digital.BackgroundTransparency = 1
	Digital.Name = "Digital"
	Digital.Size = UDim2.fromScale(1, 1)
	Digital.Visible = false
	Digital.Parent = Holder
	for i: number = 0, 23 do
	    if not SkippedTicks[i] then
	        local Angle: number = math.rad(i * 15) - (math.pi / 2)
	        local X: number = math.cos(Angle) * 50 + 68.5
	        local Y: number = math.sin(Angle) * 50 + 65.5
	        local Tick: Frame = Instance.new("Frame")
	        Tick.AnchorPoint = Vector2.new(0.5, 0.5)
	        Tick.BackgroundColor3 = Color3.new(1, 1, 1)
	        Tick.BorderSizePixel = 0
	        Tick.Position = UDim2.fromOffset(X, Y)
	        Tick.Size = UDim2.fromOffset(3, 3)
	        Tick.Parent = Analog
	        local Corner: UICorner = Instance.new("UICorner")
	        Corner.CornerRadius = UDim.new(1, 0)
	        Corner.Parent = Tick
	    end
	end
	Hand = Instance.new("Frame")
	Hand.AnchorPoint = Vector2.new(0.5, 1)
	Hand.BackgroundColor3 = Color3.fromRGB(6, 161, 126)
	Hand.BorderSizePixel = 0
	Hand.Name = "Hand"
	Hand.Position = UDim2.fromOffset(70, 65)
	Hand.Size = UDim2.fromOffset(4, 52)
	Hand.Parent = Analog
	AnalogHour = AddLabel(Analog, 44 * UIPallet.DisplayScale, Enum.TextXAlignment.Right)
	AnalogMinute = AddLabel(Analog, 44 * UIPallet.DisplayScale, Enum.TextXAlignment.Right)
	AnalogWeekday = AddLabel(Analog, 13 * UIPallet.DisplayScale, Enum.TextXAlignment.Left)
	AnalogDate = AddLabel(Analog, 13 * UIPallet.DisplayScale, Enum.TextXAlignment.Left)
	AnalogMeridiem = AddLabel(Analog, 13 * UIPallet.DisplayScale, Enum.TextXAlignment.Right)
	DigitalHour = AddLabel(Digital, 48 * UIPallet.DisplayScale, Enum.TextXAlignment.Right)
	DigitalMinute = AddLabel(Digital, 48 * UIPallet.DisplayScale, Enum.TextXAlignment.Left)
	DigitalMeridiem = AddLabel(Digital, 16 * UIPallet.DisplayScale, Enum.TextXAlignment.Left)
	DigitalDate = AddLabel(Digital, 16 * UIPallet.DisplayScale, Enum.TextXAlignment.Right)
	DigitalWeekday = AddLabel(Digital, 16 * UIPallet.DisplayScale, Enum.TextXAlignment.Right)
	local Colon: Frame = Instance.new("Frame")
	Colon.AnchorPoint = Vector2.new(0.5, 0.5)
	Colon.BackgroundColor3 = Color3.new(1, 1, 1)
	Colon.BorderSizePixel = 0
	Colon.Name = "Colon"
	Colon.Position = UDim2.fromOffset(70, 32)
	Colon.Size = UDim2.fromOffset(4, 4)
	Colon.Parent = Digital
	local ColonCorner: UICorner = Instance.new("UICorner")
	ColonCorner.CornerRadius = UDim.new(1, 0)
	ColonCorner.Parent = Colon
	PlaceLabel(AnalogHour, 56, 37.5)
	PlaceLabel(AnalogMinute, 130, 88.7)
	PlaceLabel(AnalogWeekday, 20, 90.5)
	PlaceLabel(AnalogDate, 20, 106.5)
	PlaceLabel(AnalogMeridiem, 130, 18.1)
	PlaceLabel(DigitalHour, 60, 34)
	PlaceLabel(DigitalMinute, 78, 34)
	ShowDate.Object.Visible = ClockType.Value == "Digital"
	Update()
end)

Run(function()
	local Compass
	local Background
	local BackgroundColor
	local Slots = {}
	local Last = {}
	local Cardinals: {[number]: string} = {[0] = "N", [45] = "NE", [90] = "E", [135] = "SE", [180] = "S", [225] = "SW", [270] = "W", [315] = "NW"}
	local TickStep: number = (616 + 8) / 1400
	local DegreeStep: number = TickStep * 10
	local StripCentre: number = TickStep + 70 * DegreeStep
	local MajorSize: UDim2 = UDim2.fromOffset(2, 12)
	local MajorPosition: UDim2 = UDim2.fromOffset(0, 32)
	local MinorSize: UDim2 = UDim2.fromOffset(2, 4)
	local MinorPosition: UDim2 = UDim2.fromOffset(0, 36)
	local PlateColor: Color3 = Color3.fromRGB(230, 230, 230)
	local MutedColor: Color3 = Color3.fromRGB(163, 163, 163)
	local WhiteColor: Color3 = Color3.new(1, 1, 1)
	local Holder, Strip, HeadingLabel
	
	local function Update()
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    local Look: Vector3 = Camera.CFrame.LookVector
	    local Heading: number = math.deg(math.atan2(Look.X, -Look.Z)) % 360
	    local Plain: boolean = not Background.Enabled
	    local Index: number = 0
	    local Degrees: number = math.floor(Heading)
	    if Degrees ~= Last.degrees then
	        Last.degrees = Degrees
	        HeadingLabel.Text = tostring(Degrees)
	    end
	
	    for Value: number = math.ceil((Heading - 70) / 5) * 5, Heading + 70, 5 do
	        Index += 1
	        local Slot = Slots[Index]
	        local Normalized: number = Value % 360
	        local Major: boolean = Normalized % 45 == 0
	        Slot.Object.Position = UDim2.fromOffset(TickStep + (Value - Heading + 70) * DegreeStep, 0)
	        Slot.Object.Visible = true
	        Slot.Bar.Position = Major and MajorPosition or MinorPosition
	        Slot.Bar.Size = Major and MajorSize or MinorSize
	        Slot.Bar.BackgroundTransparency = Major and 0.6 or 0.624
	        Slot.Label.Visible = Major or Normalized % 15 == 0
	
	        if Slot.Label.Visible and (Slot.Value ~= Normalized or Plain ~= Last.plain) then
	            Slot.Value = Normalized
	            Slot.Label.Text = Major and Cardinals[Normalized] or tostring(math.floor(Normalized))
	            Slot.Label.FontFace = (Major or Plain) and UIPallet.FontBold or UIPallet.Font
	            Slot.Label.TextColor3 = Plain and PlateColor or (Major and WhiteColor or MutedColor)
	        end
	    end
	
	    Last.plain = Plain
	
	    for SlotIndex: number, v: any in Slots do
	        if SlotIndex > Index then
	            v.Object.Visible = false
	        end
	    end
	end
	
	Compass = vape.Legit:CreateModule({
	    Name = "Compass",
	    Category = "HUD",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_compass.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            Compass:Clean(RunService.RenderStepped:Connect(Update))
	        end
	    end,
	    Size = UDim2.fromOffset(616, 60),
	    Tooltip = "Shows a compass indicating your direction"
	})
	
	Background = Compass:CreateToggle({
	    Name = "Render background",
	    Function = function(Callback: boolean)
	        if BackgroundColor then
	            Holder.BackgroundTransparency = Callback and 1 - BackgroundColor.Opacity or 1
	            BackgroundColor.Object.Visible = Callback
	        end
	    end,
	    Default = true
	})
	BackgroundColor = Compass:CreateColorSlider({
	    Name = "Background Color",
	    DefaultHue = 0.8333,
	    DefaultSat = 0.0385,
	    DefaultValue = 0.102,
	    DefaultOpacity = 0.4,
	    Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
	        if Holder then
	            Holder.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
	            Holder.BackgroundTransparency = Background.Enabled and 1 - Opacity or 1
	        end
	    end,
	    Darker = true
	})
	Holder = Compass.Children
	Holder.BackgroundColor3 = Color3.fromRGB(26, 25, 26)
	Holder.BackgroundTransparency = 0.6
	local HolderCorner: UICorner = Instance.new("UICorner")
	HolderCorner.CornerRadius = UDim.new(0, 4)
	HolderCorner.Parent = Holder
	Strip = Instance.new("Frame")
	Strip.BackgroundTransparency = 1
	Strip.ClipsDescendants = true
	Strip.Name = "Strip"
	Strip.Position = UDim2.fromOffset(0, -20)
	Strip.Size = UDim2.fromOffset(616, 80)
	Strip.Parent = Holder
	HeadingLabel = Instance.new("TextLabel")
	HeadingLabel.AnchorPoint = Vector2.new(0.5, 0)
	HeadingLabel.BackgroundTransparency = 1
	HeadingLabel.FontFace = UIPallet.FontBold
	HeadingLabel.Position = UDim2.fromOffset(StripCentre, 0)
	HeadingLabel.Size = UDim2.fromOffset(200, 16)
	HeadingLabel.TextColor3 = PlateColor
	HeadingLabel.TextSize = 12
	HeadingLabel.Parent = Strip
	local Arrow: ImageLabel = Instance.new("ImageLabel")
	Arrow.AnchorPoint = Vector2.new(0.5, 0)
	Arrow.BackgroundTransparency = 1
	Arrow.Image = GetVapeAsset("kingvape/assets/new/compassarrow.png")
	Arrow.Position = UDim2.fromOffset(StripCentre, 15)
	Arrow.Size = UDim2.fromOffset(19, 32)
	Arrow.Parent = Strip
	for i: number = 1, 29 do
	    local Slot: Frame = Instance.new("Frame")
	    Slot.BackgroundTransparency = 1
	    Slot.Size = UDim2.new()
	    Slot.Visible = false
	    Slot.Parent = Strip
	    local Bar: Frame = Instance.new("Frame")
	    Bar.AnchorPoint = Vector2.new(0.5, 0)
	    Bar.BackgroundColor3 = WhiteColor
	    Bar.BorderSizePixel = 0
	    Bar.Position = MajorPosition
	    Bar.Size = MajorSize
	    Bar.Parent = Slot
	    local Label: TextLabel = Instance.new("TextLabel")
	    Label.AnchorPoint = Vector2.new(0.5, 0)
	    Label.BackgroundTransparency = 1
	    Label.FontFace = UIPallet.FontBold
	    Label.Position = UDim2.fromOffset(0, 43)
	    Label.Size = UDim2.fromOffset(60, 20)
	    Label.TextColor3 = WhiteColor
	    Label.TextSize = 11
	    Label.Parent = Slot
	    Slots[i] = {Object = Slot, Bar = Bar, Label = Label}
	end
end)

Run(function()
	local Coords
	local DisplayType
	local Background
	local BackgroundColor
	local HorizontalAxes = {}
	local VerticalAxes = {}
	local CoordText: {string} = {}
	local Positives: {[number]: boolean} = {}
	local Last = {}
	local PositiveColor: Color3 = Color3.fromRGB(5, 134, 105)
	local NegativeColor: Color3 = Color3.fromRGB(250, 50, 56)
	local TriangleArrow: string = GetVapeAsset("kingvape/assets/new/triangle.png")
	local DigitWidth: number = GetFontBounds("0", 19, UIPallet.Font).X
	local Holder, Horizontal, Vertical
	local HorizontalMaterial, VerticalMaterial
	
	local function AddLabel(Parent: Instance, TextSize: number, TextColor: Color3): TextLabel
	    local Label: TextLabel = Instance.new("TextLabel")
	    Label.BackgroundTransparency = 1
	    Label.FontFace = UIPallet.Font
	    Label.Size = UDim2.fromOffset(200, 20)
	    Label.TextColor3 = TextColor
	    Label.TextSize = TextSize
	    Label.TextXAlignment = Enum.TextXAlignment.Left
	    Label.Parent = Parent
	
	    return Label
	end
	
	local function AddArrow(Parent: Instance)
	    local Box: Frame = Instance.new("Frame")
	    Box.BackgroundColor3 = Color3.fromRGB(26, 25, 26)
	    Box.BackgroundTransparency = 0.431
	    Box.Size = UDim2.fromOffset(16, 16)
	    Box.Parent = Parent
	    local Corner: UICorner = Instance.new("UICorner")
	    Corner.CornerRadius = UDim.new(0, 3)
	    Corner.Parent = Box
	    local Triangle: ImageLabel = Instance.new("ImageLabel")
	    Triangle.BackgroundTransparency = 1
	    Triangle.Image = TriangleArrow
	    Triangle.Size = UDim2.fromOffset(8, 4)
	    Triangle.Parent = Box
	
	    return Box, Triangle
	end
	
	local function AddDivider(Parent: Instance, Size: UDim2): Frame
	    local Divider: Frame = Instance.new("Frame")
	    Divider.BackgroundColor3 = Color3.new(1, 1, 1)
	    Divider.BackgroundTransparency = 0.8
	    Divider.BorderSizePixel = 0
	    Divider.Size = Size
	    Divider.Parent = Parent
	
	    return Divider
	end
	
	local function Update()
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    if not Entity.isAlive then
	        return
	    end
	
	    local Position: Vector3 = Entity.character.RootPart.Position
	    local Look: Vector3 = Camera.CFrame.LookVector
	    local Material: string = Entity.character.Humanoid.FloorMaterial.Name
	    local X, Y, Z = math.round(Position.X), math.round(Position.Y), math.round(Position.Z)
	    local PositiveX, PositiveZ = Look.X > 0, Look.Z > 0
	    if Last.x == X and Last.y == Y and Last.z == Z and Last.positivex == PositiveX and Last.positivez == PositiveZ and Last.material == Material and Last.display == DisplayType.Value then
	        return
	    end
	
	    Last.x, Last.y, Last.z, Last.positivex, Last.positivez, Last.material, Last.display = X, Y, Z, PositiveX, PositiveZ, Material, DisplayType.Value
	    CoordText[1] = tostring(X)
	    CoordText[2] = tostring(Y)
	    CoordText[3] = tostring(Z)
	    Positives[1] = PositiveX
	    Positives[3] = PositiveZ
	
	    if DisplayType.Value == "Vertical" then
	        for i: number, v: any in VerticalAxes do
	            v.Value.Text = CoordText[i]
	
	            if v.Triangle then
	                v.Triangle.ImageColor3 = Positives[i] and PositiveColor or NegativeColor
	                v.Triangle.Position = UDim2.fromOffset(4, Positives[i] and 5 or 6)
	                v.Triangle.Rotation = Positives[i] and 180 or 0
	            end
	        end
	
	        VerticalMaterial.Text = Material
	        return
	    end
	
	    local Offset: number = 20
	
	    for i: number, v: any in HorizontalAxes do
	        v.Label.Position = UDim2.fromOffset(Offset, 16)
	        Offset += v.Width + 5
	        v.Value.Text = CoordText[i]
	        v.Value.Position = UDim2.fromOffset(Offset, 13)
	        Offset += math.max(44, 10 + DigitWidth * #CoordText[i])
	
	        if v.Triangle then
	            v.Arrow.Position = UDim2.fromOffset(Offset - 8, 18)
	            v.Triangle.ImageColor3 = Positives[i] and PositiveColor or NegativeColor
	            v.Triangle.Position = UDim2.fromOffset(4, Positives[i] and 5 or 6)
	            v.Triangle.Rotation = Positives[i] and 180 or 0
	        end
	
	        if v.Divider then
	            Offset += v.Triangle and 20 or 0
	            v.Divider.Position = UDim2.fromOffset(Offset - 1, 18)
	            Offset += 20
	        end
	    end
	
	    HorizontalMaterial.Text = Material
	    Holder.Size = UDim2.fromOffset(Offset + 24, 70)
	end
	
	Coords = vape.Legit:CreateModule({
	    Name = "Coords",
	    Category = "HUD",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_coords.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            Coords:Clean(RunService.RenderStepped:Connect(Update))
	        end
	    end,
	    Size = UDim2.fromOffset(280, 70),
	    Tooltip = "Shows your current XYZ coordinates"
	})
	
	DisplayType = Coords:CreateDropdown({
	    Name = "Display Type",
	    List = {"Horizontal", "Vertical"},
	    Function = function(Value: string)
	        if Holder then
	            Horizontal.Visible = Value == "Horizontal"
	            Vertical.Visible = Value == "Vertical"
	            Holder.Size = UDim2.fromOffset(Value == "Vertical" and 140 or 280, Value == "Vertical" and 180 or 70)
	        end
	    end
	})
	Background = Coords:CreateToggle({
	    Name = "Render background",
	    Function = function(Callback: boolean)
	        if BackgroundColor then
	            Holder.BackgroundTransparency = Callback and 1 - BackgroundColor.Opacity or 1
	            BackgroundColor.Object.Visible = Callback
	        end
	    end,
	    Default = true
	})
	BackgroundColor = Coords:CreateColorSlider({
	    Name = "Background Color",
	    DefaultHue = 0.8333,
	    DefaultSat = 0.0385,
	    DefaultValue = 0.102,
	    DefaultOpacity = 0.4,
	    Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
	        if Holder then
	            Holder.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
	            Holder.BackgroundTransparency = Background.Enabled and 1 - Opacity or 1
	        end
	    end,
	    Darker = true
	})
	Holder = Coords.Children
	Holder.BackgroundColor3 = Color3.fromRGB(26, 25, 26)
	Holder.BackgroundTransparency = 0.6
	local HolderCorner: UICorner = Instance.new("UICorner")
	HolderCorner.CornerRadius = UDim.new(0, 4)
	HolderCorner.Parent = Holder
	Horizontal = Instance.new("Frame")
	Horizontal.BackgroundTransparency = 1
	Horizontal.Name = "Horizontal"
	Horizontal.Size = UDim2.fromScale(1, 1)
	Horizontal.Parent = Holder
	Vertical = Instance.new("Frame")
	Vertical.BackgroundTransparency = 1
	Vertical.Name = "Vertical"
	Vertical.Size = UDim2.fromScale(1, 1)
	Vertical.Visible = false
	Vertical.Parent = Holder
	for i: number, Axis: string in {"X", "Y", "Z"} do
	    local Entry = {Width = GetFontBounds(Axis, 12, UIPallet.Font).X}
	    Entry.Label = AddLabel(Horizontal, 12, Color3.new(1, 1, 1))
	    Entry.Label.Text = Axis
	    Entry.Value = AddLabel(Horizontal, 19, Color3.new(1, 1, 1))
	
	    if Axis ~= "Y" then
	        Entry.Arrow, Entry.Triangle = AddArrow(Horizontal)
	    end
	
	    if Axis ~= "Z" then
	        Entry.Divider = AddDivider(Horizontal, UDim2.fromOffset(2, 16))
	    end
	
	    HorizontalAxes[i] = Entry
	end
	for i: number, Axis: string in {"X", "Y", "Z"} do
	    local Entry = {}
	    Entry.Label = AddLabel(Vertical, 11, Color3.new(1, 1, 1))
	    Entry.Label.Text = Axis
	    Entry.Label.Position = UDim2.fromOffset(16, 16 + (i - 1) * 45)
	    Entry.Value = AddLabel(Vertical, 17, Color3.new(1, 1, 1))
	    Entry.Value.Position = UDim2.fromOffset(21 + GetFontBounds(Axis, 11, UIPallet.Font).X, 13 + (i - 1) * 45)
	
	    if Axis ~= "Y" then
	        Entry.Arrow, Entry.Triangle = AddArrow(Vertical)
	        Entry.Arrow.Position = UDim2.fromOffset(108, Axis == "X" and 18 or 105)
	    end
	
	    VerticalAxes[i] = Entry
	end
	for i: number = 1, 3 do
	    local Divider: Frame = AddDivider(Vertical, UDim2.fromOffset(110, 2))
	    Divider.Position = UDim2.fromOffset(16, 2 + i * 45)
	end
	local HorizontalLabel: TextLabel = AddLabel(Horizontal, 12, Color3.new(1, 1, 1))
	HorizontalLabel.Text = "MATERIAL:"
	HorizontalLabel.Position = UDim2.fromOffset(20, 41)
	HorizontalMaterial = AddLabel(Horizontal, 12, Color3.fromRGB(255, 160, 84))
	HorizontalMaterial.Position = UDim2.fromOffset(20 + GetFontBounds("MATERIAL: ", 12, UIPallet.Font).X, 41)
	local VerticalLabel: TextLabel = AddLabel(Vertical, 11, Color3.new(1, 1, 1))
	VerticalLabel.Text = "MATERIAL:"
	VerticalLabel.Position = UDim2.fromOffset(16, 146)
	VerticalMaterial = AddLabel(Vertical, 11, Color3.fromRGB(255, 160, 84))
	VerticalMaterial.Position = UDim2.fromOffset(24 + GetFontBounds("MATERIAL:", 11, UIPallet.Font).X, 146)
end)

Run(function()
	local Disguise
	local Mode
	local IDBox
	local Cloned: {[Instance]: boolean} = {}
	
	local function ItemAdded(Object: Instance, Manual: boolean?)
	    if (Object:IsA("Accessory") or Object:IsA("ShirtGraphic") or Object:IsA("Shirt") or Object:IsA("Pants") or Object:IsA("BodyColors") or Manual) and not Cloned[Object] then
	        Object:ClearAllChildren()
	        task.defer(Object.Destroy, Object)
	    end
	end
	
	local function LocalAdded(Ent)
	    table.clear(Cloned)
	    if Mode.Value == "Character" then
	        local Success, Description = pcall(function()
	            return Players:GetHumanoidDescriptionFromUserId(IDBox.Value == "" and 239702688 or tonumber(IDBox.Value))
	        end)
	
	        if Success and Disguise.Enabled then
	            Ent.Character.Archivable = true
	            local Clone: Model = Ent.Character:Clone()
	            Clone.Parent = game
	
	            local Original = Ent.Humanoid:WaitForChild("HumanoidDescription", 2) or {
	                HeightScale = 1,
	                SetEmotes = function() end,
	                SetEquippedEmotes = function() end
	            }
	
	            Original.JumpAnimation = Description.JumpAnimation
	            Description.HeightScale = Original.HeightScale
	            Clone:FindFirstChildWhichIsA("Humanoid"):ApplyDescriptionResetAsync(Description)
	
	            Disguise:Clean(Ent.Character.ChildAdded:Connect(ItemAdded))
	            for _, v: Instance in Ent.Character:GetChildren() do
	                ItemAdded(v)
	            end
	
	            for _, Child: Instance in Clone:GetChildren() do
	                Cloned[Child] = true
	                if Child:IsA("Accessory") then
	                    for _, v: Instance in Child:GetDescendants() do
	                        if v:IsA("Weld") and v.Part1 then
	                            v.Part1 = Ent.Character:FindFirstChild(v.Part1.Name)
	                        elseif v:IsA("RigidConstraint") then
	                            v.Attachment1 = Ent.Character:FindFirstChild(v.Attachment1.Name, true)
	                        end
	                    end
	
	                    Child.Parent = Ent.Character
	                elseif Child:IsA("ShirtGraphic") or Child:IsA("Shirt") or Child:IsA("Pants") or Child:IsA("BodyColors") then
	                    Child.Parent = Ent.Character
	                elseif Child.Name == "Head" and Ent.Head:IsA("MeshPart") and (not Ent.Head:FindFirstChild("FaceControls")) then
	                    Ent.Head.MeshId = Child.MeshId
	                end
	            end
	
	            local Face: Instance? = Ent.Character:FindFirstChild("face", true)
	            local CloneFace: Instance? = Clone:FindFirstChild("face", true)
	
	            if Face then
	                ItemAdded(Face, true)
	            end
	
	            if CloneFace then
	                CloneFace.Parent = Ent.Head
	            end
	
	            Original:SetEmotes(Description:GetEmotes())
	            Original:SetEquippedEmotes(Description:GetEquippedEmotes())
	            Description:Destroy()
	            Clone:ClearAllChildren()
	            Clone:Destroy()
	        elseif Description then
	            Description:Destroy()
	        end
	    else
	        local Success, Data = pcall(function()
	            return MarketplaceService:GetProductInfo(IDBox.Value == "" and 43 or tonumber(IDBox.Value), Enum.InfoType.Bundle)
	        end)
	
	        if Success and Disguise.Enabled then
	            if Data.BundleType == "AvatarAnimations" then
	                local Animate: Instance? = Ent.Character:FindFirstChild("Animate")
	                if not Animate then
	                    return
	                end
	
	                for _, v: any in Data.Items do
	                    local ItemType: string = v.Name:split(" ")[2]:lower()
	                    if ItemType ~= "animation" then
	                        local Loaded, Objects = pcall(function()
	                            return game:GetObjects(`rbxassetid://{v.Id}`)
	                        end)
	
	                        if Loaded then
	                            Animate[ItemType]:FindFirstChildWhichIsA("Animation").AnimationId = Objects[1]:FindFirstChildWhichIsA("Animation", true).AnimationId
	                        end
	                    end
	                end
	            else
	                SendNotification("Disguise", "that's not an animation pack", 5, "warning")
	            end
	        elseif type(Data) == "table" then
	            table.clear(Data)
	        end
	    end
	end
	
	Disguise = vape.Legit:CreateModule({
	    Name = "Disguise",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_disguise.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            Disguise:Clean(Entity.Events.LocalAdded:Connect(LocalAdded))
	            if Entity.isAlive then
	                task.spawn(LocalAdded, Entity.character)
	            end
	        else
	            table.clear(Cloned)
	        end
	    end,
	    Tooltip = "Changes your character or animation to a specific ID (animation packs or userid's only)"
	})
	
	Mode = Disguise:CreateDropdown({
	    Name = "Mode",
	    List = {"Character", "Animation"},
	    Function = function()
	        if Disguise.Enabled then
	            Disguise:Toggle()
	            Disguise:Toggle()
	        end
	    end
	})
	IDBox = Disguise:CreateTextBox({
	    Name = "Disguise",
	    Placeholder = "Disguise User Id",
	    Function = function()
	        if Disguise.Enabled then
	            Disguise:Toggle()
	            Disguise:Toggle()
	        end
	    end
	})
end)

Run(function()
	local FFlag
	local Flags
	local List
	local Prefixes: {string} = {"DFFlag", "DFInt", "DFLog", "DFString", "SFFlag", "FFlag", "FInt", "FLog", "FString"}
	local Marker: string = "CVFF1:"
	
	local function UnpackFlags(Text: string): string
	    local Size, Body = Text:match(`^{Marker}(%d+):(.+)$`)
	    if not Size then
	        return Text
	    end
	
	    local Success, Plain = pcall(function()
	        return lz4decompress(base64decode(Body), tonumber(Size))
	    end)
	    return Success and Plain or Text
	end
	
	local function Apply()
	    if not FFlag.Enabled then
	        return
	    end
	
	    local Applied: number = 0
	    for _, v: string in List.ListEnabled do
	        local Name, Value = v:match("^%s*(.-)%s*=%s*(.-)%s*$")
	        for _, Prefix: string in Prefixes do
	            if Name and Name:sub(1, #Prefix) == Prefix then
	                Name = Name:sub(#Prefix + 1)
	                break
	            end
	        end
	
	        if Name and Name ~= "" and Value ~= "" and pcall(setfflag, Name, Value) then
	            Applied += 1
	        end
	    end
	
	    if Applied > 0 then
	        SendNotification("Vape", `Applied {Applied} fflag{Applied == 1 and "" or "s"}, join a new game for them to take effect`, 12, "info")
	    end
	end
	
	local function Ingest(Text: string, Source: string)
	    Text = UnpackFlags(Text)
	    local Success, Json = pcall(function()
	        return HttpService:JSONDecode(Text)
	    end)
	
	    if not Success or typeof(Json) ~= "table" then
	        SendNotification("Vape", `{Source} is not valid fflag json`, 12, "warning")
	        return
	    end
	
	    local AddedCount, DroppedCount = 0, 0
	    for Key: any, v: any in Json do
	        local Entry: string?
	        for _, Prefix: string in Prefixes do
	            if typeof(Key) == "string" and #Key > #Prefix and Key:sub(1, #Prefix) == Prefix and (typeof(v) == "string" or typeof(v) == "number" or typeof(v) == "boolean") then
	                Entry = `{Key}={tostring(v)}`
	                break
	            end
	        end
	
	        if Entry and not table.find(List.List, Entry) then
	            table.insert(List.List, Entry)
	            table.insert(List.ListEnabled, Entry)
	            AddedCount += 1
	        elseif not Entry then
	            DroppedCount += 1
	        end
	    end
	
	    List:ChangeValue()
	    SendNotification("Vape", `Took {AddedCount} fflag{AddedCount == 1 and "" or "s"} from {Source}{DroppedCount > 0 and `, dropped {DroppedCount} it did not recognise` or ""}`, 12, AddedCount > 0 and "info" or "warning")
	end
	
	FFlag = vape.Legit:CreateModule({
	    Name = "FFlagEditor",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_fflageditor.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            Apply()
	        else
	            SendNotification("Vape", "Inorder to disable fflags you have applied, You need to restart roblox", 20, "info")
	        end
	    end
	})
	
	List = FFlag:CreateTextList({
	    Name = "Flags",
	    Function = Apply,
	    Tooltip = "One flag per entry as Name=Value, click a flag to leave it out without deleting it\nSaved with your profile, so it travels with an exported config"
	})
	Flags = FFlag:CreateTextBox({
	    Name = "FFlags",
	    Placeholder = "json format only",
	    Function = function(Enter: boolean)
	        if Enter and Flags.Value ~= "" then
	            Ingest(Flags.Value, "the box")
	            Flags:SetValue("")
	        end
	    end
	})
	FFlag:CreateButton({
	    Name = "Import from file",
	    Function = function()
	        if not isfile("kingvape/fflags.json") then
	            SendNotification("Vape", "No kingvape/fflags.json to read", 12, "warning")
	            return
	        end
	
	        Ingest(readfile("kingvape/fflags.json"), "kingvape/fflags.json")
	    end
	})
	FFlag:CreateButton({
	    Name = "Export to file",
	    Function = function()
	        local Json: {[string]: string} = {}
	        for _, v: string in List.ListEnabled do
	            local Name, Value = v:match("^%s*(.-)%s*=%s*(.-)%s*$")
	            if Name and Name ~= "" then
	                Json[Name] = Value
	            end
	        end
	
	        local Plain: string = HttpService:JSONEncode(Json)
	        local Success, Blob = pcall(function()
	            return `{Marker}{#Plain}:{base64encode(lz4compress(Plain))}`
	        end)
	
	        local Copied, Packed = Plain, false
	        if Success and UnpackFlags(Blob) == Plain then
	            Copied, Packed = Blob, true
	        end
	        writefile("kingvape/fflags.json", Plain)
	
	        if setclipboard then
	            setclipboard(Copied)
	        end
	
	        SendNotification("Vape", Packed and `Wrote kingvape/fflags.json and copied {#Copied} characters to your clipboard, {math.floor(#Copied / #Plain * 100)}% of the raw json` or `Wrote kingvape/fflags.json and copied the raw json, packing it did not read back so it was left alone`, 12, Packed and "info" or "warning")
	    end
	})
	FFlag:CreateButton({
	    Name = "Reset",
	    Function = function()
	        table.clear(List.List)
	        table.clear(List.ListEnabled)
	        List:ChangeValue()
	        SendNotification("Vape", "Cleared the list, restart roblox to drop the flags already applied", 20, "info")
	    end
	})
end)

Run(function()
	local FOV
	local Value
	local OldFOV: number
	
	FOV = vape.Legit:CreateModule({
	    Name = "FOV",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_fov.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            OldFOV = Camera.FieldOfView
	            repeat
	                Camera.FieldOfView = Value.Value
	                task.wait()
	            until not FOV.Enabled
	        else
	            Camera.FieldOfView = OldFOV
	        end
	    end,
	    Tooltip = "Adjusts camera vision"
	})
	
	Value = FOV:CreateSlider({
	    Name = "FOV",
	    Min = 30,
	    Max = 120
	})
end)

Run(function()
	local FPS
	local Label: TextLabel
	
	FPS = vape.Legit:CreateModule({
	    Name = "FPS",
	    Category = "HUD",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_fps.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            local Frames: {number} = {}
	            local StartClock: number = os.clock()
	            local UpdateTick: number = tick()
	
	            FPS:Clean(RunService.Heartbeat:Connect(function()
	                local UpdateClock: number = os.clock()
	                for i: number = #Frames, 1, -1 do
	                    Frames[i + 1] = Frames[i] >= UpdateClock - 1 and Frames[i] or nil
	                end
	
	                Frames[1] = UpdateClock
	                if UpdateTick < tick() then
	                    UpdateTick = tick() + 1
	                    Label.Text = `{math.floor(os.clock() - StartClock >= 1 and #Frames or #Frames / (os.clock() - StartClock))} FPS`
	                end
	            end))
	        end
	    end,
	    Size = UDim2.fromOffset(100, 41),
	    Tooltip = "Shows the current framerate"
	})
	
	FPS:CreateFont({
	    Name = "Font",
	    Blacklist = "Gotham",
	    Function = function(Val: Font)
	        Label.FontFace = Val
	    end
	})
	FPS:CreateColorSlider({
	    Name = "Color",
	    DefaultValue = 0,
	    DefaultOpacity = 0.5,
	    Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
	        Label.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
	        Label.BackgroundTransparency = 1 - Opacity
	    end
	})
	Label = Instance.new("TextLabel")
	Label.Size = UDim2.fromScale(1, 1)
	Label.BackgroundTransparency = 0.5
	Label.TextSize = 15
	Label.FontFace = UIPallet.Font
	Label.Text = "inf FPS"
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.BackgroundColor3 = Color3.new()
	Label.Parent = FPS.Children
	local Corner: UICorner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 4)
	Corner.Parent = Label
end)

Run(function()
	local Keystrokes
	local KeyStyle
	local MouseStyle
	local ShowSpacebar
	local ShowCpsOnly
	local Keys = {}
	local LeftClicks: {number} = {}
	local RightClicks: {number} = {}
	local ArrowIcons: {[string]: string} = {
	    W = GetVapeAsset("kingvape/assets/new/key_up.png"),
	    A = GetVapeAsset("kingvape/assets/new/key_left.png"),
	    S = GetVapeAsset("kingvape/assets/new/key_down.png"),
	    D = GetVapeAsset("kingvape/assets/new/key_right.png")
	}
	local Keybinds: {[Enum.KeyCode]: string} = {
	    [Enum.KeyCode.W] = "W",
	    [Enum.KeyCode.A] = "A",
	    [Enum.KeyCode.S] = "S",
	    [Enum.KeyCode.D] = "D",
	    [Enum.KeyCode.Space] = "Space"
	}
	local ReleasedBackground: Color3 = Color3.fromRGB(20, 20, 20)
	local PressedText: Color3 = Color3.fromRGB(20, 20, 20)
	local KeyTween: TweenInfo = TweenInfo.new(0.05, Enum.EasingStyle.Linear)
	local Holder, MouseIcons, CpsHolder, CpsBackground, CpsDivider, CpsLeft, CpsRight, CpsLabel
	local LeftMouseIcon, RightMouseIcon, MiddleMouseIcon
	
	local function AddLabel(Parent: Instance, Name: string, Text: string): TextLabel
	    local Label: TextLabel = Instance.new("TextLabel")
	    Label.BackgroundTransparency = 1
	    Label.FontFace = UIPallet.FontDisplay
	    Label.Name = Name
	    Label.Size = UDim2.fromOffset(200, 22)
	    Label.Text = Text
	    Label.TextColor3 = Color3.fromRGB(209, 209, 209)
	    Label.TextSize = 16 * UIPallet.DisplayScale
	    Label.Parent = Parent
	
	    return Label
	end
	
	local function PlaceCps(Label: TextLabel, X: number, CenterY: number, Alignment: Enum.TextXAlignment)
	    Label.Position = UDim2.fromOffset(Alignment == Enum.TextXAlignment.Right and X - 200 or X, CenterY - 11)
	    Label.TextXAlignment = Alignment
	end
	
	local function PlaceKey(Entry, X: number, Y: number, Width: number, Height: number)
	    Entry.Object.Position = UDim2.fromOffset(X, Y - 1)
	    Entry.Object.Size = UDim2.fromOffset(Width, Height + 1)
	    Entry.Label.Position = UDim2.fromOffset((Width / 2) - 100, 5.75)
	    Entry.Icon.Position = UDim2.fromOffset((Width / 2) - 4.4, 6)
	end
	
	local function PressKey(Entry, Pressed: boolean)
	    if Entry.Pressed == Pressed then
	        return
	    end
	
	    Entry.Pressed = Pressed
	    Entry.Shadow.Enabled = Pressed
	
	    Tween:Tween(Entry.Object, KeyTween, {
	        BackgroundColor3 = Pressed and Color3.new(1, 1, 1) or ReleasedBackground,
	        BackgroundTransparency = Pressed and 0 or 0.294
	    })
	
	    Tween:Tween(Entry.Bar, KeyTween, {
	        BackgroundColor3 = Pressed and PressedText or Color3.new(1, 1, 1)
	    })
	
	    Tween:Tween(Entry.Icon, KeyTween, {
	        ImageColor3 = Pressed and PressedText or Color3.new(1, 1, 1)
	    })
	
	    Tween:Tween(Entry.Label, KeyTween, {
	        TextColor3 = Pressed and PressedText or Color3.new(1, 1, 1)
	    })
	
	    if Entry.Mouse then
	        Tween:Tween(Entry.Mouse, KeyTween, {
	            ImageColor3 = Pressed and Color3.new(1, 1, 1) or ReleasedBackground,
	            ImageTransparency = Pressed and 0 or 0.294
	        })
	    end
	end
	
	local function CountClicks(Clicks: {number}): number
	    local Now: number = tick()
	    while Clicks[1] and Clicks[1] < Now do
	        table.remove(Clicks, 1)
	    end
	
	    return #Clicks
	end
	
	local function RefreshLayout()
	    if not Holder then
	        return
	    end
	
	    local IconStyle: boolean = MouseStyle.Value == "Icon"
	    local ArrowStyle: boolean = KeyStyle.Value == "Arrow"
	    local Spacebar: boolean = ShowSpacebar.Enabled
	
	    for KeyName: string, v: any in Keys do
	        v.Object.Visible = not ShowCpsOnly.Enabled and (KeyName ~= "Space" or Spacebar) and not (IconStyle and (KeyName == "LMB" or KeyName == "RMB"))
	        v.Label.Visible = not ArrowStyle or KeyName == "LMB" or KeyName == "RMB" or KeyName == "Space"
	        v.Icon.Visible = ArrowStyle and ArrowIcons[KeyName] ~= nil
	        v.Icon.Image = ArrowIcons[KeyName] or ""
	    end
	
	    MouseIcons.Visible = IconStyle and not ShowCpsOnly.Enabled
	    CpsDivider.Visible = not ShowCpsOnly.Enabled
	    CpsLabel.Visible = ShowCpsOnly.Enabled
	    CpsRight.Visible = not ShowCpsOnly.Enabled
	
	    if ShowCpsOnly.Enabled then
	        Holder.Size = UDim2.fromOffset(150, 40)
	        CpsHolder.Position = UDim2.fromOffset(0, 0)
	        CpsHolder.Size = UDim2.fromOffset(110, 20)
	        CpsBackground.Position = UDim2.fromOffset(0, 0)
	        CpsBackground.Size = UDim2.fromOffset(39 + GetFontBounds("CPS", 16 * UIPallet.DisplayScale, UIPallet.FontDisplay).X, 24)
	        PlaceCps(CpsLeft, 22, 14, Enum.TextXAlignment.Right)
	        PlaceCps(CpsLabel, 25, 14, Enum.TextXAlignment.Left)
	
	        return
	    end
	
	    local KeysY: number = IconStyle and 8 or 4
	    local MouseX: number = IconStyle and 122 or 0
	    local MouseY: number = (IconStyle and KeysY - 12 or KeysY + 80) + (Spacebar and 28 or 0)
	    local CpsWidth: number = IconStyle and 80 or 110
	    Holder.Size = UDim2.fromOffset(108 + (IconStyle and 96 or 0), (IconStyle and 80 or 144) + (Spacebar and 28 or 0))
	    PlaceKey(Keys.W, 38, KeysY - 4, 34, 34)
	    PlaceKey(Keys.A, 0, KeysY + 38, 34, 34)
	    PlaceKey(Keys.S, 38, KeysY + 38, 34, 34)
	    PlaceKey(Keys.D, 76, KeysY + 38, 34, 34)
	    PlaceKey(Keys.Space, 0, KeysY + 79, 110.5, 22)
	    PlaceKey(Keys.LMB, MouseX, MouseY, 52.7, 32)
	    PlaceKey(Keys.RMB, MouseX + 56.7, MouseY, 52.7, 32)
	    MouseIcons.Position = UDim2.fromOffset(MouseX - 4, MouseY)
	    CpsHolder.Position = UDim2.fromOffset(MouseX, MouseY + (IconStyle and 44 or 34))
	    CpsHolder.Size = UDim2.fromOffset(CpsWidth, 20)
	    CpsBackground.Position = UDim2.fromOffset(0, 4)
	    CpsBackground.Size = UDim2.fromOffset(CpsWidth, 24)
	    CpsDivider.Position = UDim2.fromOffset(CpsWidth / 2, 8)
	    PlaceCps(CpsLeft, 10, 16, Enum.TextXAlignment.Left)
	    PlaceCps(CpsRight, CpsWidth - 10, 16, Enum.TextXAlignment.Right)
	end
	
	local function Update()
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    CpsLeft.Text = tostring(CountClicks(LeftClicks))
	    CpsRight.Text = tostring(CountClicks(RightClicks))
	end
	
	local function InputChanged(Input: InputObject, Pressed: boolean)
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    local Name: string? = Keybinds[Input.KeyCode]
	    if Input.UserInputType == Enum.UserInputType.MouseButton1 then
	        Name = "LMB"
	
	        if Pressed then
	            table.insert(LeftClicks, tick() + 1)
	        end
	    elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
	        Name = "RMB"
	
	        if Pressed then
	            table.insert(RightClicks, tick() + 1)
	        end
	    end
	
	    if Name and Keys[Name] then
	        PressKey(Keys[Name], Pressed)
	    end
	end
	
	Keystrokes = vape.Legit:CreateModule({
	    Name = "Keystrokes",
	    Category = "HUD",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_keystrokes.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            Keystrokes:Clean(UserInputService.InputBegan:Connect(function(Input: InputObject)
	                InputChanged(Input, true)
	            end))
	
	            Keystrokes:Clean(UserInputService.InputEnded:Connect(function(Input: InputObject)
	                InputChanged(Input, false)
	            end))
	
	            Keystrokes:Clean(RunService.RenderStepped:Connect(Update))
	        else
	            for _, v: any in Keys do
	                PressKey(v, false)
	            end
	        end
	    end,
	    Size = UDim2.fromOffset(108, 172),
	    Tooltip = "Shows when your movement keys or mouse buttons are pressed, as well as mouse clicks per second"
	})
	
	KeyStyle = Keystrokes:CreateDropdown({
	    Name = "Key Style",
	    List = {"Keyboard", "Arrow"},
	    Function = function()
	        RefreshLayout()
	    end
	})
	MouseStyle = Keystrokes:CreateDropdown({
	    Name = "Mouse Style",
	    List = {"Button", "Icon"},
	    Function = function()
	        RefreshLayout()
	    end
	})
	ShowSpacebar = Keystrokes:CreateToggle({
	    Name = "Show Spacebar",
	    Function = function()
	        RefreshLayout()
	    end,
	    Default = true
	})
	ShowCpsOnly = Keystrokes:CreateToggle({
	    Name = "Show CPS Only",
	    Function = function()
	        RefreshLayout()
	    end
	})
	Holder = Keystrokes.Children
	for _, v: string in {"W", "A", "S", "D", "Space", "LMB", "RMB"} do
	    local Name: string = v
	    local Key: Frame = Instance.new("Frame")
	    Key.BackgroundColor3 = ReleasedBackground
	    Key.BackgroundTransparency = 0.294
	    Key.BorderSizePixel = 0
	    Key.Name = Name
	    Key.Parent = Holder
	    local Corner: UICorner = Instance.new("UICorner")
	    Corner.CornerRadius = UDim.new(0, 5)
	    Corner.Parent = Key
	    local Shadow: UIShadow = Instance.new("UIShadow")
	    Shadow.BlurRadius = UDim.new(0, 6)
	    Shadow.Color = Color3.new()
	    Shadow.Enabled = false
	    Shadow.Offset = UDim2.new()
	    Shadow.Spread = UDim2.new()
	    Shadow.Transparency = 0.404
	    Shadow.Parent = Key
	    local Label: TextLabel = Instance.new("TextLabel")
	    Label.BackgroundTransparency = 1
	    Label.FontFace = UIPallet.FontBold
	    Label.Name = "Label"
	    Label.Size = UDim2.fromOffset(200, 20)
	    Label.Text = Name == "Space" and "" or Name
	    Label.TextColor3 = Color3.new(1, 1, 1)
	    Label.TextSize = 14
	    Label.Parent = Key
	    local Icon: ImageLabel = Instance.new("ImageLabel")
	    Icon.BackgroundTransparency = 1
	    Icon.Name = "Icon"
	    Icon.Size = UDim2.fromOffset(8.8, 8.8)
	    Icon.Visible = false
	    Icon.Parent = Key
	    local Bar: Frame = Instance.new("Frame")
	    Bar.AnchorPoint = Vector2.new(0.5, 0)
	    Bar.BackgroundColor3 = Color3.new(1, 1, 1)
	    Bar.BorderSizePixel = 0
	    Bar.Name = "Bar"
	    Bar.Position = UDim2.new(0.5, 0, 0, 4)
	    Bar.Size = UDim2.fromOffset(60, 3)
	    Bar.Visible = Name == "Space"
	    Bar.Parent = Key
	    Keys[Name] = {Object = Key, Label = Label, Icon = Icon, Bar = Bar, Shadow = Shadow, Pressed = false}
	end
	MouseIcons = Instance.new("Frame")
	MouseIcons.BackgroundTransparency = 1
	MouseIcons.Name = "MouseIcons"
	MouseIcons.Size = UDim2.fromOffset(96, 48)
	MouseIcons.Visible = false
	MouseIcons.Parent = Holder
	LeftMouseIcon = Instance.new("ImageLabel")
	LeftMouseIcon.BackgroundTransparency = 1
	LeftMouseIcon.Image = GetVapeAsset("kingvape/assets/new/key_lmb.png")
	LeftMouseIcon.ImageColor3 = ReleasedBackground
	LeftMouseIcon.Name = "LMB"
	LeftMouseIcon.Size = UDim2.fromOffset(50.2, 48)
	LeftMouseIcon.Parent = MouseIcons
	RightMouseIcon = LeftMouseIcon:Clone()
	RightMouseIcon.Image = GetVapeAsset("kingvape/assets/new/key_rmb.png")
	RightMouseIcon.Name = "RMB"
	RightMouseIcon.Position = UDim2.fromOffset(40, 0)
	RightMouseIcon.Parent = MouseIcons
	MiddleMouseIcon = Instance.new("ImageLabel")
	MiddleMouseIcon.BackgroundTransparency = 1
	MiddleMouseIcon.Image = GetVapeAsset("kingvape/assets/new/key_mmb.png")
	MiddleMouseIcon.ImageColor3 = Color3.fromRGB(225, 225, 225)
	MiddleMouseIcon.Name = "MMB"
	MiddleMouseIcon.Position = UDim2.fromOffset(43, 14)
	MiddleMouseIcon.Size = UDim2.fromOffset(3.9, 13.8)
	MiddleMouseIcon.Parent = MouseIcons
	CpsHolder = Instance.new("Frame")
	CpsHolder.BackgroundTransparency = 1
	CpsHolder.Name = "CPS"
	CpsHolder.Size = UDim2.fromOffset(110, 20)
	CpsHolder.Parent = Holder
	CpsBackground = Instance.new("Frame")
	CpsBackground.BackgroundColor3 = ReleasedBackground
	CpsBackground.BackgroundTransparency = 0.294
	CpsBackground.BorderSizePixel = 0
	CpsBackground.Name = "Background"
	CpsBackground.ZIndex = 0
	CpsBackground.Parent = CpsHolder
	local CpsCorner: UICorner = Instance.new("UICorner")
	CpsCorner.CornerRadius = UDim.new(0, 5)
	CpsCorner.Parent = CpsBackground
	CpsDivider = Instance.new("Frame")
	CpsDivider.BackgroundColor3 = Color3.fromRGB(209, 209, 209)
	CpsDivider.BorderSizePixel = 0
	CpsDivider.Name = "Divider"
	CpsDivider.Size = UDim2.fromOffset(2, 18)
	CpsDivider.Parent = CpsHolder
	CpsLeft = AddLabel(CpsHolder, "Left", "0")
	CpsRight = AddLabel(CpsHolder, "Right", "0")
	CpsLabel = AddLabel(CpsHolder, "Label", "CPS")
	CpsLabel.Visible = false
	Keys.LMB.Mouse = LeftMouseIcon
	Keys.RMB.Mouse = RightMouseIcon
	RefreshLayout()
end)

Run(function()
	local Memory
	local Label: TextLabel
	
	Memory = vape.Legit:CreateModule({
	    Name = "Memory",
	    Category = "HUD",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_memory.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                Label.Text = `{math.floor(tonumber(Stats.PerformanceStats.Memory:GetValue()))} MB`
	                task.wait(1)
	            until not Memory.Enabled
	        end
	    end,
	    Size = UDim2.fromOffset(100, 41),
	    Tooltip = "A label showing the memory currently used by roblox"
	})
	
	Memory:CreateFont({
	    Name = "Font",
	    Blacklist = "Gotham",
	    Function = function(Val: Font)
	        Label.FontFace = Val
	    end
	})
	Memory:CreateColorSlider({
	    Name = "Color",
	    DefaultValue = 0,
	    DefaultOpacity = 0.5,
	    Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
	        Label.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
	        Label.BackgroundTransparency = 1 - Opacity
	    end
	})
	Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(0, 100, 0, 41)
	Label.BackgroundTransparency = 0.5
	Label.TextSize = 15
	Label.FontFace = UIPallet.Font
	Label.Text = "0 MB"
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.BackgroundColor3 = Color3.new()
	Label.Parent = Memory.Children
	local Corner: UICorner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 4)
	Corner.Parent = Label
end)

Run(function()
	local Ping
	local Label: TextLabel
	
	Ping = vape.Legit:CreateModule({
	    Name = "Ping",
	    Category = "HUD",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_ping.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                Label.Text = `{math.floor(tonumber(Stats.PerformanceStats.Ping:GetValue()))} ms`
	                task.wait(1)
	            until not Ping.Enabled
	        end
	    end,
	    Size = UDim2.fromOffset(100, 41),
	    Tooltip = "Shows the current connection speed to the roblox server"
	})
	
	Ping:CreateFont({
	    Name = "Font",
	    Blacklist = "Gotham",
	    Function = function(Val: Font)
	        Label.FontFace = Val
	    end
	})
	Ping:CreateColorSlider({
	    Name = "Color",
	    DefaultValue = 0,
	    DefaultOpacity = 0.5,
	    Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
	        Label.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
	        Label.BackgroundTransparency = 1 - Opacity
	    end
	})
	Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(0, 100, 0, 41)
	Label.BackgroundTransparency = 0.5
	Label.TextSize = 15
	Label.FontFace = UIPallet.Font
	Label.Text = "0 ms"
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.BackgroundColor3 = Color3.new()
	Label.Parent = Ping.Children
	local Corner: UICorner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 4)
	Corner.Parent = Label
end)

Run(function()
	local SongBeats
	local List
	local FOV
	local FOVValue = {}
	local Volume
	local AlreadyPicked: {string} = {}
	local BeatTick: number = os.clock()
	local OldFOV, SongObject, SongBPM, SongTween
	
	local function ChooseSong()
	    local Songs: {string} = List.ListEnabled
	    if #AlreadyPicked >= #Songs then
	        table.clear(AlreadyPicked)
	    end
	
	    if #Songs <= 0 then
	        SendNotification("SongBeats", "no songs", 10)
	        SongBeats:Toggle()
	        return
	    end
	
	    local ChosenSong: string = Songs[math.random(1, #Songs)]
	    if #Songs > 1 and table.find(AlreadyPicked, ChosenSong) then
	        repeat
	            task.wait()
	            ChosenSong = Songs[math.random(1, #Songs)]
	        until not table.find(AlreadyPicked, ChosenSong) or not SongBeats.Enabled
	    end
	    if not SongBeats.Enabled then
	        return
	    end
	
	    table.insert(AlreadyPicked, ChosenSong)
	    local Split: {string} = ChosenSong:split("/")
	    if not isfile(Split[1]) then
	        SendNotification("SongBeats", `Missing song ({Split[1]})`, 10)
	        SongBeats:Toggle()
	        return
	    end
	
	    SongObject.SoundId = AssetFunction(Split[1])
	    repeat
	        task.wait()
	    until SongObject.IsLoaded or not SongBeats.Enabled
	
	    if SongBeats.Enabled then
	        BeatTick = os.clock() + (tonumber(Split[3]) or 0)
	        SongBPM = 60 / (tonumber(Split[2]) or 50)
	        SongObject:Play()
	    end
	end
	
	SongBeats = vape.Legit:CreateModule({
	    Name = "Song Beats",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_songbeats.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            SongObject = Instance.new("Sound")
	            SongObject.Volume = Volume.Value / 100
	            SongObject.Parent = workspace
	            SongBeats:Clean(SongObject)
	            OldFOV = Camera.FieldOfView
	
	            repeat
	                if not SongObject.Playing then
	                    ChooseSong()
	                end
	
	                if BeatTick < os.clock() and SongBeats.Enabled and FOV.Enabled then
	                    BeatTick = os.clock() + SongBPM
	                    if SongTween then
	                        SongTween:Cancel()
	                    end
	
	                    Camera.FieldOfView = OldFOV - FOVValue.Value
	                    SongTween = TweenService:Create(Camera, TweenInfo.new(math.min(SongBPM, 0.2), Enum.EasingStyle.Linear), {
	                        FieldOfView = OldFOV
	                    })
	
	                    SongTween:Play()
	                end
	
	                task.wait()
	            until not SongBeats.Enabled
	        else
	            if SongTween then
	                SongTween:Cancel()
	            end
	
	            if OldFOV then
	                Camera.FieldOfView = OldFOV
	            end
	
	            table.clear(AlreadyPicked)
	        end
	    end,
	    Tooltip = "Built in mp3 player"
	})
	
	List = SongBeats:CreateTextList({
	    Name = "Songs",
	    Placeholder = "filepath/bpm/start"
	})
	FOV = SongBeats:CreateToggle({
	    Name = "Beat FOV",
	    Function = function(Callback: boolean)
	        if FOVValue.Object then
	            FOVValue.Object.Visible = Callback
	        end
	
	        if SongBeats.Enabled then
	            SongBeats:Toggle()
	            SongBeats:Toggle()
	        end
	    end,
	    Default = true
	})
	FOVValue = SongBeats:CreateSlider({
	    Name = "Adjustment",
	    Min = 1,
	    Max = 30,
	    Default = 5,
	    Darker = true
	})
	Volume = SongBeats:CreateSlider({
	    Name = "Volume",
	    Function = function(Val: number)
	        if SongObject then
	            SongObject.Volume = Val / 100
	        end
	    end,
	    Min = 1,
	    Max = 100,
	    Default = 100,
	    Suffix = "%"
	})
end)

Run(function()
	local Speedmeter
	local Label: TextLabel
	
	Speedmeter = vape.Legit:CreateModule({
	    Name = "Speedmeter",
	    Category = "HUD",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_speedmeter.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local LastPosition: Vector3 = Entity.isAlive and Entity.character.HumanoidRootPart.Position * Vector3.new(1, 0, 1) or Vector3.zero
	                local Delta: number = task.wait(0.2)
	                local NewPosition: Vector3 = Entity.isAlive and Entity.character.HumanoidRootPart.Position * Vector3.new(1, 0, 1) or Vector3.zero
	                Label.Text = `{math.round(((LastPosition - NewPosition) / Delta).Magnitude)} sps`
	            until not Speedmeter.Enabled
	        end
	    end,
	    Size = UDim2.fromOffset(100, 41),
	    Tooltip = "A label showing the average velocity in studs"
	})
	
	Speedmeter:CreateFont({
	    Name = "Font",
	    Blacklist = "Gotham",
	    Function = function(Val: Font)
	        Label.FontFace = Val
	    end
	})
	Speedmeter:CreateColorSlider({
	    Name = "Color",
	    DefaultValue = 0,
	    DefaultOpacity = 0.5,
	    Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
	        Label.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
	        Label.BackgroundTransparency = 1 - Opacity
	    end
	})
	Label = Instance.new("TextLabel")
	Label.Size = UDim2.fromScale(1, 1)
	Label.BackgroundTransparency = 0.5
	Label.TextSize = 15
	Label.FontFace = UIPallet.Font
	Label.Text = "0 sps"
	Label.TextColor3 = Color3.new(1, 1, 1)
	Label.BackgroundColor3 = Color3.new()
	Label.Parent = Speedmeter.Children
	local Corner: UICorner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 4)
	Corner.Parent = Label
end)

Run(function()
	local TimeChanger
	local Value
	local Old: string?
	
	TimeChanger = vape.Legit:CreateModule({
	    Name = "Time Changer",
	    Category = "Game",
	    Icon = GetVapeAsset("kingvape/assets/new/legit_timechanger.png"),
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = Lighting.TimeOfDay
	            repeat
	                Lighting.TimeOfDay = `{Value.Value}:00:00`
	                task.wait()
	            until not TimeChanger.Enabled
	        else
	            Lighting.TimeOfDay = Old
	            Old = nil
	        end
	    end,
	    Tooltip = "Change the time of the current world"
	})
	
	Value = TimeChanger:CreateSlider({
	    Name = "Time",
	    Min = 0,
	    Max = 24,
	    Function = function(Val: number)
	        if TimeChanger.Enabled then
	            Lighting.TimeOfDay = `{Val}:00:00`
	        end
	    end,
	    Default = 12
	})
end)