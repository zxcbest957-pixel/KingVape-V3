if table.find({"Solara", "Xeno"}, ({identifyexecutor()})[1]) then
    return false
end
local BuildClock: number = os.clock()
local BuildBudget: number = 0.004
local Run = function(Func: () -> ())
    xpcall(Func, function(Message)
        warn(`[catvape] {Message}\n{debug.traceback(nil, 2)}`)
        if shared.vape then
            shared.vape:CreateNotification("Vape", `A module failed to load : {Message}`, 15, "alert")
        end
    end)

    if os.clock() - BuildClock > BuildBudget then
        BuildBudget = math.clamp(task.wait() * 0.75, 0.004, 0.02)
        BuildClock = os.clock()
    end
end
local cloneref = cloneref or function(Reference: Instance)
    return Reference
end
local Players: Players = cloneref(game:GetService("Players"))
local ReplicatedStorage: ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local UserInputService: UserInputService = cloneref(game:GetService("UserInputService"))
local TweenService: TweenService = cloneref(game:GetService("TweenService"))
local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local CoreGui: CoreGui = cloneref(game:GetService("CoreGui"))
local TeleportService: TeleportService = cloneref(game:GetService("TeleportService"))

local LocalPlayer: Player = Players.LocalPlayer
local vape = shared.vape
local Entity = vape.Libraries.entity
local SessionInfo = vape.Libraries.sessioninfo
local Bedwars = {}

local function SendNotification(...)
    return vape:CreateNotification(...)
end

Run(function()
    local function DumpRemote(Remotes: {string}): string
        local Index: number? = table.find(Remotes, "Client")
        return Index and Remotes[Index + 1] or ""
    end

    local KnitInit, Knit
    repeat
        KnitInit, Knit = pcall(function()
            return debug.getupvalue(require(LocalPlayer.PlayerScripts.TS.knit).setup, 9)
        end)
        if KnitInit then
            break
        end
        task.wait()
    until KnitInit
    if not debug.getupvalue(Knit.Start, 1) then
        repeat
            task.wait()
        until debug.getupvalue(Knit.Start, 1)
    end
    local Flamework = require(ReplicatedStorage["rbxts_include"]["node_modules"]["@flamework"].core.out).Flamework
    local Client = require(ReplicatedStorage.TS.remotes).default.Client

    Bedwars = setmetatable({
        Client = Client,
        CrateItemMeta = debug.getupvalue(Flamework.resolveDependency("client/controllers/global/reward-crate/crate-controller@CrateController").onStart, 3),
        EmoteDisplayMeta = require(ReplicatedStorage.TS.locker.emote["emote-display-meta"]).EmoteDisplayMeta,
        EmoteMeta = require(ReplicatedStorage.TS.locker.emote["emote-meta"]).EmoteMeta,
        EmoteType = require(ReplicatedStorage.TS.locker.emote["emote-type"]).EmoteType,
        Flamework = Flamework,
        GameAnimationUtil = require(ReplicatedStorage.TS.animation["animation-util"]).GameAnimationUtil,
        GamePlayerUtil = require(ReplicatedStorage.TS.player["player-util"]).GamePlayerUtil,
        AchievementUtil = require(ReplicatedStorage.TS.achievement["achievement-util"]).AchievementUtil,
        ModerationApp = require(LocalPlayer.PlayerScripts.TS.controllers.global["match-history"].ui["match-history-moderation-app"]).MatchHistoryModerationApp,
        MilestoneRewards = require(ReplicatedStorage.TS.milestones.milestones).MilestoneRewards,
        QueueMeta = require(ReplicatedStorage.TS.game["queue-meta"]).QueueMeta,
        Store = require(LocalPlayer.PlayerScripts.TS.ui.store).ClientStore
    }, {
        __index = function(self, Index: string)
            rawset(self, Index, Knit.Controllers[Index])
            return rawget(self, Index)
        end
    })

    local Kills = SessionInfo:AddItem("Kills")
    local Beds = SessionInfo:AddItem("Beds")
    local Wins = SessionInfo:AddItem("Wins")
    local Games = SessionInfo:AddItem("Games")

    vape:Clean(function()
        table.clear(Bedwars)
    end)
end)

for Name: string, v: any in vape.Modules do
    if v.Category == "Combat" then
        vape:Remove(Name)
    end
end

Run(function()
	local Sprint
	local Old: (...any) -> ...any
	
	Sprint = vape.Categories.Combat:CreateModule({
	    Name = "Sprint",
	    Function = function(Callback: boolean)
	        if Callback then
	            Old = Bedwars.SprintController.stopSprinting
	            Bedwars.SprintController.stopSprinting = function(...)
	                local Call = Old(...)
	                Bedwars.SprintController:startSprinting()
	                return Call
	            end
	
	            Sprint:Clean(Entity.Events.LocalAdded:Connect(function()
	                Bedwars.SprintController:stopSprinting()
	            end))
	
	            Bedwars.SprintController:stopSprinting()
	        else
	            Bedwars.SprintController.stopSprinting = Old
	            Bedwars.SprintController:stopSprinting()
	        end
	    end,
	    Tooltip = "Sets your sprinting to true."
	})
end)

Run(function()
	local AutoGamble
	
	AutoGamble = vape.Categories.Utility:CreateModule({
	    Name = "AutoGamble",
	    Function = function(Callback: boolean)
	        if Callback then
	            AutoGamble:Clean(Bedwars.Client:GetNamespace("RewardCrate"):Get("CrateOpened"):Connect(function(Data)
	                if Data.openingPlayer == LocalPlayer then
	                    local ItemMeta = Bedwars.CrateItemMeta[Data.reward.itemType] or {displayName = Data.reward.itemType or "unknown"}
	                    SendNotification("AutoGamble", `Won {ItemMeta.displayName}`, 5)
	                end
	            end))
	
	            repeat
	                if not Bedwars.CrateAltarController.activeCrates[1] then
	                    for _, v: any in Bedwars.Store:getState().Consumable.inventory do
	                        if v.consumable:find("crate") then
	                            Bedwars.CrateAltarController:pickCrate(v.consumable, 1)
	                            task.wait(1.2)
	                            if Bedwars.CrateAltarController.activeCrates[1] and Bedwars.CrateAltarController.activeCrates[1][2] then
	                                Bedwars.Client:GetNamespace("RewardCrate"):Get("OpenRewardCrate"):SendToServer({
	                                    crateId = Bedwars.CrateAltarController.activeCrates[1][2].attributes.crateId
	                                })
	                            end
	                            break
	                        end
	                    end
	                end
	                task.wait(1)
	            until not AutoGamble.Enabled
	        end
	    end,
	    Tooltip = "Automatically opens lucky crates, piston inspired!"
	})
end)

Run(function()
	local AutoQueue
	local QueueType
	local Leave
	
	local Categories = {}
	
	AutoQueue = vape.Categories.Utility:CreateModule({
	    Name = "AutoQueue",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local PartyData = Bedwars.Store:getState().Party
	                if PartyData.leader.userId == LocalPlayer.UserId then
	                    if PartyData.queueState == 2 and PartyData.queueData and PartyData.queueData.queueType ~= Categories[QueueType.Value] then
	                        ReplicatedStorage["events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events"].leaveQueue:FireServer()
	                    elseif PartyData.queueState < 2 then
	                        Bedwars.QueueController:joinQueue(Categories[QueueType.Value])
	                        task.wait(1)
	                    end
	                elseif Leave.Enabled then
	                    ReplicatedStorage["events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events"].leaveParty:FireServer()
	                end
	                task.wait(0.1)
	            until not AutoQueue.Enabled
	        else
	            ReplicatedStorage["events-@easy-games/lobby:shared/event/lobby-events@getEvents.Events"].leaveQueue:FireServer()
	        end
	    end
	})
	
	local List: {string} = {}
	for Queue: string, v: any in Bedwars.QueueMeta do
	    if not v.disabled and v.title and not Categories[v.title] then
	        Categories[v.title] = Queue
	        table.insert(List, v.title)
	    end
	end
	table.sort(List)
	QueueType = AutoQueue:CreateDropdown({
	    Name = "Queue Type",
	    List = List,
	    Default = "Duels (2v2)"
	})
	Leave = AutoQueue:CreateToggle({
	    Name = "Leave Party",
	    Default = true
	})
end)

Run(function()
	local ClaimRewards
	local CratesOnly
	local Notify
	
	ClaimRewards = vape.Categories.Utility:CreateModule({
	    Name = "ClaimRewards",
	    Function = function(Callback: boolean)
	        if Callback then
	            repeat
	                local Level: number = Bedwars.Store:getState().Bedwars.playerLevel or 0
	                local Claimed = Bedwars.MilestonesController.milestoneRewardsClaimed
	                if not Claimed then
	                    local State = Bedwars.Store:getState().Bedwars
	                    Claimed = State and State.milestoneRewardsClaimed or {}
	                end
	
	                for _, v: any in Bedwars.MilestoneRewards do
	                    if v.levelRequirement <= Level and not table.find(Claimed, v.id) and (not CratesOnly.Enabled or v.instantClaim) then
	                        if Bedwars.Client:Get("ClaimMilestoneReward"):CallServer(v.id) then
	                            table.insert(Claimed, v.id)
	                            if Notify.Enabled then
	                                SendNotification("ClaimRewards", `Claimed {v.description or v.id}`, 5)
	                            end
	                        end
	                        task.wait(1)
	                        if not ClaimRewards.Enabled then
	                            break
	                        end
	                    end
	                end
	
	                task.wait(5)
	            until not ClaimRewards.Enabled
	        end
	    end,
	    Tooltip = "Automatically claims every level milestone reward as soon as you unlock it"
	})
	
	CratesOnly = ClaimRewards:CreateToggle({
	    Name = "Crates only",
	    Tooltip = "Only claims the instant rewards like the lucky and diamond crates, leaves kits and cosmetics alone"
	})
	Notify = ClaimRewards:CreateToggle({
	    Name = "Notify",
	    Default = true,
	    Tooltip = "Tells you what got claimed"
	})
end)

Run(function()
	local DeviceSpoofer
	local Device
	local OldDevice, Old
	
	DeviceSpoofer = vape.Categories.Utility:CreateModule({
	    Name = "DeviceSpoofer",
	    Function = function(Callback: boolean)
	        if Callback then
	            OldDevice, Old = Bedwars.UserInputController:getUserInputType(), Bedwars.UserInputController.getUserInputType
	            Bedwars.UserInputController.getUserInputType = function()
	                return Device.Value:upper()
	            end
	            Bedwars.Client:Get("SendUserInputType"):SendToServer({userInputType = Device.Value:upper()})
	        else
	            Bedwars.UserInputController.getUserInputType = Old
	            Bedwars.Client:Get("SendUserInputType"):SendToServer({userInputType = OldDevice})
	            Old = nil
	        end
	    end,
	    Tooltip = "Spoofs the device you show up as to the server",
	    ExtraText = function()
	        return Device.Value
	    end
	})
	
	Device = DeviceSpoofer:CreateDropdown({
	    Name = "Device",
	    List = {"Mobile", "PC", "Gamepad"},
	    Function = function(Val: string)
	        if DeviceSpoofer.Enabled then
	            Bedwars.Client:Get("SendUserInputType"):SendToServer({userInputType = Val:upper()})
	        end
	    end
	})
end)

Run(function()
	local MatchDodge
	local AutoUndodge
	local UndodgeMode
	local Blacklist
	local Ping
	local Timeout
	local VetoAt
	local MaxWait
	local Advanced
	local RankAdvantage
	local DeviceCheck
	local Device
	local LowRank
	local LowRankAt
	local Guaranteed
	local Tiers: {string} = {"Bronze", "Silver", "Gold", "Platinum", "Diamond", "Emerald", "Nightmare"}
	
	MatchDodge = vape.Categories.Utility:CreateModule({
	    Name = "AutoMatchDodge",
	    Function = function(Callback: boolean)
	        writefile("kingvape/profiles/matchdodge.txt", tostring(Callback))
	        getgenv().matchDodgeActive = Callback
	    end,
	    Tooltip = "Sets the dodge checks for your next match; settings carry over from the lobby"
	})
	
	MatchDodge:CreateButton({
	    Name = "Load",
	    Function = function()
	        Bedwars.Handler:Get("PlayerConnect"):Fire(nil, TeleportService:GetLocalPlayerTeleportData())
	    end
	})
	MatchDodge:CreateToggle({
	    Name = "Rank only",
	    Tooltip = "Loads straight away when the match is not ranked"
	})
	AutoUndodge = MatchDodge:CreateToggle({
	    Name = "Auto Undodge",
	    Function = function(Callback: boolean)
	        if UndodgeMode then
	            UndodgeMode.Object.Visible = Callback
	        end
	        if Blacklist then
	            Blacklist.Object.Visible = Callback and UndodgeMode.Value == "Rank"
	        end
	        if Ping then
	            Ping.Object.Visible = Callback and UndodgeMode.Value == "Latency"
	        end
	    end,
	    Tooltip = "Automatically loads when the selected checks pass"
	})
	UndodgeMode = MatchDodge:CreateDropdown({
	    Name = "Mode",
	    List = {"Rank", "Latency"},
	    Function = function(Val: string)
	        if Blacklist then
	            Blacklist.Object.Visible = AutoUndodge.Enabled and Val == "Rank"
	        end
	        if Ping then
	            Ping.Object.Visible = AutoUndodge.Enabled and Val == "Latency"
	        end
	    end,
	    Darker = true,
	    Visible = false,
	    Tooltip = "Rank waits for opponents to load, Latency waits for your ping to reach the threshold"
	})
	Blacklist = MatchDodge:CreateTextList({
	    Name = "Rank Blacklist",
	    Placeholder = "bronze / silver / gold / platinum / diamond / emerald / nightmare",
	    Darker = true,
	    Visible = false,
	    Function = function()
	        for i: number, v: string in Blacklist.List do
	            Blacklist.List[i] = v:lower()
	        end
	        for i: number, v: string in Blacklist.ListEnabled do
	            Blacklist.ListEnabled[i] = v:lower()
	        end
	    end
	})
	Ping = MatchDodge:CreateSlider({
	    Name = "Ping",
	    Min = 50,
	    Max = 1000,
	    Default = 200,
	    Darker = true,
	    Visible = false,
	    Suffix = "ms",
	    Tooltip = "How high your ping has to be before loading"
	})
	MatchDodge:CreateToggle({
	    Name = "Rank Veto",
	    Function = function(Callback: boolean)
	        if VetoAt then
	            VetoAt.Object.Visible = Callback
	        end
	    end,
	    Tooltip = "Keeps dodging opponents at or above the selected rank, even after Max Wait"
	})
	VetoAt = MatchDodge:CreateDropdown({
	    Name = "Veto At",
	    List = Tiers,
	    Default = "Diamond",
	    Darker = true,
	    Visible = false,
	    Tooltip = "The lowest enemy rank that blocks automatic loading"
	})
	MatchDodge:CreateToggle({
	    Name = "4v5 Check",
	    Tooltip = "In 5v5 queues, waits if fewer teammates than opponents are loaded, counting you"
	})
	MaxWait = MatchDodge:CreateSlider({
	    Name = "Max Wait",
	    Min = 0,
	    Max = 120,
	    Function = function(Val: number)
	        if Timeout then
	            Timeout.Value = Val
	        end
	    end,
	    Default = 20,
	    Suffix = function(Val: number)
	        return Val == 1 and "second" or "seconds"
	    end,
	    Tooltip = "Skips the mode wait after this long. Rank vetoes, blacklist, team and Advanced checks still apply. 0 waits forever"
	})
	Timeout = MatchDodge:CreateSlider({
	    Name = "Timeout",
	    Min = 0,
	    Max = 120,
	    Function = function(Val: number)
	        MaxWait:SetValue(Val)
	    end,
	    Default = 20,
	    Visible = false
	})
	Advanced = MatchDodge:CreateToggle({
	    Name = "Advanced",
	    Function = function(Callback: boolean)
	        for _, v: any in {RankAdvantage, DeviceCheck, LowRank, Guaranteed} do
	            v.Object.Visible = Callback
	        end
	        if Device then
	            Device.Object.Visible = Callback and DeviceCheck.Enabled
	        end
	        if LowRankAt then
	            LowRankAt.Object.Visible = Callback and LowRank.Enabled
	        end
	    end,
	    Tooltip = "Enables extra conditions for automatic loading"
	})
	RankAdvantage = MatchDodge:CreateToggle({
	    Name = "Rank Advantage",
	    Darker = true,
	    Visible = false,
	    Tooltip = "Requires your team, including you, to have a higher average rank division"
	})
	DeviceCheck = MatchDodge:CreateToggle({
	    Name = "Device Check",
	    Function = function(Callback: boolean)
	        if Device then
	            Device.Object.Visible = Advanced.Enabled and Callback
	        end
	    end,
	    Darker = true,
	    Visible = false,
	    Tooltip = "Requires every opponent to use one of the selected devices"
	})
	Device = MatchDodge:CreateDropdown({
	    Name = "Device",
	    List = {"Mobile / Gamepad", "Mobile", "Gamepad", "PC"},
	    Darker = true,
	    Visible = false
	})
	LowRank = MatchDodge:CreateToggle({
	    Name = "Low Rank",
	    Function = function(Callback: boolean)
	        if LowRankAt then
	            LowRankAt.Object.Visible = Advanced.Enabled and Callback
	        end
	    end,
	    Darker = true,
	    Visible = false,
	    Tooltip = "Requires every opponent to be at or below the selected rank"
	})
	LowRankAt = MatchDodge:CreateDropdown({
	    Name = "Low Rank At",
	    List = Tiers,
	    Default = "Gold",
	    Darker = true,
	    Visible = false
	})
	Guaranteed = MatchDodge:CreateToggle({
	    Name = "Guaranteed 5v4",
	    Darker = true,
	    Visible = false,
	    Tooltip = "Waits for the match to start with 5 on your side and 4 opponents, with nobody still loading. Later reconnects can change the teams"
	})
	task.spawn(function()
	    repeat
	        task.wait()
	    until vape.Loaded or vape.Loaded == nil
	    local Last = isfile("kingvape/profiles/matchdodge.json") and readfile("kingvape/profiles/matchdodge.json")
	    if vape.Loaded and Last then
	        local Success, Result = pcall(HttpService.JSONDecode, HttpService, Last)
	        if Success and type(Result) == "table" then
	            if Result.Options and Result.Options["Max Wait"] then
	                Result.Options.Timeout = Result.Options["Max Wait"]
	            end
	            MatchDodge:Load(Result)
	        end
	    end
	
	    repeat
	        if vape.Loaded then
	            local Data = {}
	            MatchDodge:Save(Data)
	            Data.AutoMatchDodge.Favorited = nil
	            local Encoded: string = HttpService:JSONEncode(Data.AutoMatchDodge)
	            if Encoded ~= Last then
	                Last = Encoded
	                writefile("kingvape/profiles/matchdodge.json", Encoded)
	            end
	        end
	        task.wait(1)
	    until vape.Loaded == nil
	end)
end)

Run(function()
	local MatchHistory
	
	MatchHistory = vape.Categories.Utility:CreateModule({
	    Name = "ViewMatchHistory",
	    Function = function(Callback: boolean)
	        if Callback then
	            Bedwars.Flamework.resolveDependency("@easy-games/game-core:client/controllers/app-controller@AppController"):openApp({
	                appId = "MatchHistoryApp",
	                app = Bedwars.ModerationApp
	            }, {
	                player = LocalPlayer,
	                matchHistory = {}
	            })
	            MatchHistory:Toggle()
	        end
	    end
	})
end)

Run(function()
	local NameHider
	local Replacement
	local ChatTags
	local Level
	local HideOthers
	local Swapped: {[Instance]: string} = setmetatable({}, {__mode = "k"})
	local Watched: {[Instance]: RBXScriptConnection} = setmetatable({}, {__mode = "k"})
	local Patterns: {string} = {}
	local Plain: {string} = {}
	local Shortest: number = math.huge
	local TextClasses: {[string]: boolean} = {TextLabel = true, TextButton = true, TextBox = true}
	local FakeName: string = "hidden"
	local Writing: Instance?
	local OldUsername, OldDisplayName, OldClanTag, OldLevel
	
	local Refreshing: boolean = false
	
	local function QueueRefresh()
	    if Refreshing or not NameHider or not NameHider.Enabled then
	        return
	    end
	    Refreshing = true
	
	    task.delay(0.35, function()
	        Refreshing = false
	        if NameHider.Enabled then
	            NameHider:Toggle()
	            NameHider:Toggle()
	        end
	    end)
	end
	
	local function ShouldHidePlayer(Player: Player?)
	    return Player and (Player.UserId == LocalPlayer.UserId or HideOthers.Enabled)
	end
	
	local function AddPlayerNames(Player: Player)
	    for _, v: string in {Player.Name, Player.DisplayName} do
	        if v ~= "" then
	            local LowerName: string = v:lower()
	            if not table.find(Plain, LowerName) then
	                table.insert(Plain, LowerName)
	                Shortest = math.min(Shortest, #LowerName)
	            end
	        end
	        for _, Variant: string in {v, v:lower(), v:upper()} do
	            local Pattern: string = (Variant:gsub("%W", "%%%0"))
	            if Variant ~= "" and not table.find(Patterns, Pattern) then
	                table.insert(Patterns, Pattern)
	            end
	        end
	    end
	end
	
	local function IsLocal(GamePlayer): boolean
	    local Player: Player? = GamePlayer:getPlayer()
	    return Player ~= nil and Player.UserId == LocalPlayer.UserId
	end
	
	local function GetGamePlayerClass()
	    local GamePlayer = Bedwars.GamePlayerUtil and Bedwars.GamePlayerUtil.getGamePlayer(LocalPlayer)
	    local Meta = GamePlayer and getmetatable(GamePlayer)
	    return Meta and Meta.__index
	end
	
	local function HasPlayerName(Object: Instance)
	    local Ancestor: Instance? = Object.Parent
	    for _ = 1, 3 do
	        if not Ancestor then
	            return nil
	        end
	        local Label = Ancestor:FindFirstChild("PlayerName", true)
	        if Label then
	            return Label
	        end
	        Ancestor = Ancestor.Parent
	    end
	    return nil
	end
	
	local function HideLevelObject(Object: Instance)
	    if not (Level.Enabled or HideOthers.Enabled) or not TextClasses[Object.ClassName] then
	        return
	    end
	    if not Object.Name:lower():find("level", 1, true) then
	        return
	    end
	    local PlayerName = HasPlayerName(Object)
	    if not PlayerName or (not HideOthers.Enabled and not PlayerName.Text:find(FakeName, 1, true)) then
	        return
	    end
	
	    local function Apply()
	        if Writing == Object or not Object.Parent then
	            return
	        end
	        local Text = Object.Text
	        if type(Text) ~= "string" or Text == "" then
	            return
	        end
	
	        Swapped[Object] = Swapped[Object] or Text
	        Writing = Object
	        Object.Text = ""
	        Writing = nil
	    end
	
	    Apply()
	    if not Watched[Object] then
	        Watched[Object] = Object:GetPropertyChangedSignal("Text"):Connect(Apply)
	    end
	end
	
	local function HideLevelSiblings(Object: Instance?)
	    if not Object then
	        return
	    end
	    for _, v: Instance in Object:GetDescendants() do
	        HideLevelObject(v)
	    end
	end
	
	local function HideObject(Object: Instance)
	    if not TextClasses[Object.ClassName] then
	        return
	    end
	
	    local function Apply()
	        if Writing == Object then
	            return
	        end
	
	        local Text = Object.Text
	        if type(Text) ~= "string" or #Text < Shortest then
	            return
	        end
	
	        local Hit: boolean = false
	        for _, v: string in Plain do
	            if Text:find(v, 1, true) then
	                Hit = true
	                break
	            end
	        end
	        if not Hit then
	            local LowerText: string = Text:lower()
	            for _, v: string in Plain do
	                if LowerText:find(v, 1, true) then
	                    Hit = true
	                    break
	                end
	            end
	        end
	        if not Hit then
	            return
	        end
	
	        local NewText: string = Text
	        for _, v: string in Patterns do
	            if NewText:find(v) then
	                NewText = NewText:gsub(v, FakeName)
	            end
	        end
	        if NewText == Text then
	            return
	        end
	
	        Swapped[Object] = Text
	        Writing = Object
	        Object.Text = NewText
	        Writing = nil
	        HideLevelSiblings(Object.Parent)
	
	        if not Watched[Object] then
	            Watched[Object] = Object:GetPropertyChangedSignal("Text"):Connect(Apply)
	        end
	    end
	
	    Apply()
	end
	
	local function Watch(Root: Instance?)
	    if not Root then
	        return
	    end
	
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	    NameHider:Clean(Root.DescendantAdded:Connect(function(Object: Instance)
	        if NameHider.Enabled then
	            HideObject(Object)
	            HideLevelObject(Object)
	        end
	    end))
	
	    local Clock: number = os.clock()
	    for _, v: Instance in Root:GetDescendants() do
	        HideObject(v)
	        HideLevelObject(v)
	
	        if os.clock() - Clock > 0.002 then
	            task.wait()
	            if not NameHider.Enabled then
	                return
	            end
	            Clock = os.clock()
	
	            if vape.ThreadFix then
	                setthreadidentity(8)
	            end
	        end
	    end
	end
	
	NameHider = vape.Categories.Utility:CreateModule({
	    Name = "NameHider",
	    Function = function(Callback: boolean)
	        if Callback then
	            table.clear(Patterns)
	            table.clear(Plain)
	            Shortest = math.huge
	            for _, v: Player in Players:GetPlayers() do
	                if v == LocalPlayer or HideOthers.Enabled then
	                    AddPlayerNames(v)
	                end
	            end
	
	            FakeName = Replacement.Value ~= "" and Replacement.Value or "hidden"
	            for _, v: string in Patterns do
	                if FakeName:find(v) then
	                    FakeName = "hidden"
	                    break
	                end
	            end
	
	            local GamePlayer = GetGamePlayerClass()
	            if GamePlayer and not OldUsername then
	                OldUsername, OldDisplayName = GamePlayer.getUsername, GamePlayer.getDisplayName
	                OldClanTag, OldLevel = GamePlayer.getClanTag, GamePlayer.getLevel
	                GamePlayer.getUsername = function(self, ...)
	                    local Player: Player? = self:getPlayer()
	                    return ShouldHidePlayer(Player) and FakeName or OldUsername(self, ...)
	                end
	                GamePlayer.getDisplayName = function(self, ...)
	                    local Player: Player? = self:getPlayer()
	                    return ShouldHidePlayer(Player) and FakeName or OldDisplayName(self, ...)
	                end
	                GamePlayer.getClanTag = function(self, ...)
	                    return IsLocal(self) and ChatTags.Enabled and "" or OldClanTag(self, ...)
	                end
	                GamePlayer.getLevel = function(self, ...)
	                    local Player: Player? = self:getPlayer()
	                    if Player and (HideOthers.Enabled or (Player.UserId == LocalPlayer.UserId and Level.Enabled)) then
	                        return -1
	                    end
	                    return OldLevel(self, ...)
	                end
	            end
	
	            for _, v: Instance? in {LocalPlayer:FindFirstChildOfClass("PlayerGui"), CoreGui, gethui and gethui() or nil, LocalPlayer.Character} do
	                Watch(v)
	            end
	
	            NameHider:Clean(LocalPlayer.CharacterAdded:Connect(function(Character: Model)
	                if NameHider.Enabled then
	                    Watch(Character)
	                end
	            end))
	            NameHider:Clean(Players.PlayerAdded:Connect(function()
	                if HideOthers.Enabled then
	                    QueueRefresh()
	                end
	            end))
	            NameHider:Clean(Players.PlayerRemoving:Connect(function()
	                if HideOthers.Enabled then
	                    QueueRefresh()
	                end
	            end))
	        else
	            local GamePlayer = GetGamePlayerClass()
	            if OldUsername and GamePlayer then
	                GamePlayer.getUsername, GamePlayer.getDisplayName = OldUsername, OldDisplayName
	                GamePlayer.getClanTag, GamePlayer.getLevel = OldClanTag, OldLevel
	                OldUsername, OldDisplayName, OldClanTag, OldLevel = nil, nil, nil, nil
	            end
	            if vape.ThreadFix then
	                setthreadidentity(8)
	            end
	
	            for _, v: RBXScriptConnection in Watched do
	                v:Disconnect()
	            end
	            table.clear(Watched)
	
	            for Object: Instance, v: string in Swapped do
	                if Object.Parent then
	                    Writing = Object
	                    Object.Text = v
	                end
	            end
	            Writing = nil
	            table.clear(Swapped)
	        end
	    end,
	    Tooltip = "Replaces your username and display name everywhere it shows up on your screen",
	    ExtraText = function()
	        return Replacement.Value ~= "" and Replacement.Value or "hidden"
	    end
	})
	
	Replacement = NameHider:CreateTextBox({
	    Name = "Name",
	    Function = QueueRefresh,
	    Default = "hidden"
	})
	HideOthers = NameHider:CreateToggle({
	    Name = "Hide others",
	    Function = QueueRefresh,
	    Tooltip = "Hides every player's username and level"
	})
	ChatTags = NameHider:CreateToggle({
	    Name = "Hide chat tags",
	    Tooltip = "Hides your clan tag wherever it renders"
	})
	Level = NameHider:CreateToggle({
	    Name = "Hide level",
	    Function = QueueRefresh,
	    Tooltip = "Hides your level wherever it renders"
	})
end)

Run(function()
	local RegionLock
	local Regions
	
	RegionLock = vape.Categories.Utility:CreateModule({
	    Name = "RegionLock",
	    Function = function(Callback: boolean)
	        writefile("kingvape/profiles/regionlock.txt", tostring(Callback))
	        getgenv().regionLockActive = Callback
	    end,
	    Tooltip = "Stays out of matches that are not hosted in one of your selected server regions; settings carry over into the match. BedWars only hosts NA, EU and SEA and picks yours from your account country"
	})
	
	Regions = RegionLock:CreateTextList({
	    Name = "Regions",
	    Placeholder = "NA / EU / SEA",
	    Default = {"NA", "EU", "SEA"},
	    Function = function()
	        if not Regions then
	            return
	        end
	        for i: number, v: string in Regions.List do
	            Regions.List[i] = v:gsub("%s+", ""):upper()
	        end
	        for i: number, v: string in Regions.ListEnabled do
	            Regions.ListEnabled[i] = v:gsub("%s+", ""):upper()
	        end
	    end,
	    Tooltip = "Turn off the regions you do not want. AUS, OCE, AU and NZ all count as SEA, US counts as NA. Leaving every region on accepts anything"
	})
	
	task.spawn(function()
	    repeat
	        task.wait()
	    until vape.Loaded or vape.Loaded == nil
	    local Last = isfile("kingvape/profiles/regionlock.json") and readfile("kingvape/profiles/regionlock.json")
	    if vape.Loaded and Last then
	        local Success, Result = pcall(HttpService.JSONDecode, HttpService, Last)
	        if Success and type(Result) == "table" then
	            RegionLock:Load(Result)
	        end
	    end
	
	    repeat
	        if vape.Loaded then
	            local Data = {}
	            RegionLock:Save(Data)
	            Data.RegionLock.Favorited = nil
	            local Encoded: string = HttpService:JSONEncode(Data.RegionLock)
	            if Encoded ~= Last then
	                Last = Encoded
	                writefile("kingvape/profiles/regionlock.json", Encoded)
	            end
	        end
	        task.wait(1)
	    until vape.Loaded == nil
	end)
end)

Run(function()
	local SetEmote
	local Emote
	local Track: AnimationTrack?
	local Billboard: BillboardGui?
	local Moved: RBXScriptConnection?
	
	local List, EmoteTypes = {}, {}
	for EmoteType: any, v: any in Bedwars.EmoteMeta do
	    if EmoteType ~= Bedwars.EmoteType.NONE and v.name and not EmoteTypes[v.name] then
	        EmoteTypes[v.name] = EmoteType
	        table.insert(List, v.name)
	    end
	end
	table.sort(List)
	
	local function CancelEmote()
	    if Moved then
	        Moved:Disconnect()
	        Moved = nil
	    end
	    if Track then
	        Track:Stop()
	        Track:Destroy()
	        Track = nil
	    end
	    if Billboard then
	        Billboard:Destroy()
	        Billboard = nil
	    end
	
	    local Maid = Bedwars.EmoteController and Bedwars.EmoteController.emoteAudioMaids and Bedwars.EmoteController.emoteAudioMaids[LocalPlayer.UserId]
	    if Maid then
	        Maid:DoCleaning()
	    end
	
	    if Entity.isAlive and LocalPlayer.Character:GetAttribute("PlayingEmote") then
	        LocalPlayer.Character:SetAttribute("PlayingEmote", nil)
	    end
	end
	
	SetEmote = vape.Categories.Utility:CreateModule({
	    Name = "SetEmote",
	    Function = function(Callback: boolean)
	        if Callback then
	            SetEmote:Toggle()
	            if Entity.isAlive then
	                local EmoteType = EmoteTypes[Emote.Value]
	                local Meta = Bedwars.EmoteMeta[EmoteType]
	                if Meta then
	                    LocalPlayer.Character:SetAttribute("PlayingEmote", EmoteType)
	                    local PlayBeginSounds = Bedwars.EmoteController and (Bedwars.EmoteController.createEmoteBeginAudioPlayers or Bedwars.EmoteController.playEmoteBeginSounds)
	                    if PlayBeginSounds then
	                        PlayBeginSounds(Bedwars.EmoteController, EmoteType, LocalPlayer)
	                    end
	                    local Animation = Meta.animation
	                    if not Animation and Meta.emoteDisplayType then
	                        local Display = Bedwars.EmoteDisplayMeta[Meta.emoteDisplayType]
	                        Animation = Display and Display.animation
	                    end
	                    if Animation then
	                        Track = LocalPlayer.Character.Humanoid:LoadAnimation(Bedwars.GameAnimationUtil:getAnimation(Animation.type))
	                        Track.Looped = Animation.looped or false
	                        Track:Play(nil, nil, Animation.speed or 1)
	                    end
	                    if not Meta.animation then
	                        local Gui: BillboardGui = Instance.new("BillboardGui")
	                        Billboard = Gui
	                        Gui.Size = UDim2.fromScale(6, 2.5)
	                        Gui.StudsOffset = Vector3.new(0, 2, 0)
	                        Gui.AlwaysOnTop = true
	                        Gui.Adornee = LocalPlayer.Character.Head
	
	                        local Image: ImageLabel = Instance.new("ImageLabel")
	                        Image.AnchorPoint = Vector2.new(0.5, 1)
	                        Image.Position = UDim2.fromScale(0.5, 1)
	                        Image.Size = UDim2.fromScale(0, 0)
	                        Image.Image = Meta.image
	                        Image.BackgroundTransparency = 1
	                        Image.ImageTransparency = 1
	                        Image.ScaleType = Enum.ScaleType.Fit
	                        Image.Parent = Gui
	
	                        Gui.Parent = LocalPlayer.Character.Head
	                        TweenService:Create(Image, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
	                            Position = UDim2.fromScale(0.5, 0.5),
	                            Size = UDim2.fromScale(1, 1),
	                            ImageTransparency = 0
	                        }):Play()
	                    end
	                    if Meta.allowMovement then
	                        task.delay(6, CancelEmote)
	                    else
	                        Moved = LocalPlayer.Character.Humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(CancelEmote)
	                    end
	                end
	            end
	        end
	    end,
	    Tooltip = "Plays the selected emote on your character, other players can see it too"
	})
	
	Emote = SetEmote:CreateDropdown({
	    Name = "Emote",
	    List = List,
	    Default = "nightmare"
	})
end)