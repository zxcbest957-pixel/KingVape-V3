local License = ... or {}
local vape = {
    ActiveBinds = {},
    Categories = {},
    FavoriteCount = 0,
    GUIColor = {
        Hue = 0.46,
        Sat = 0.96,
        Value = 0.52
    },
    HeldKeybinds = {},
    Loaded = false,
    Libraries = {},
    Modules = {},
    Place = game.PlaceId,
    Profile = "default",
    RainbowSliders = {},
    Settings = {},
    SettingToggleNotifications = {},
    ThreadFix = setthreadidentity and true or false,
    ToggleNotifications = {},
    Version = "4.22",
    Windows = {}
}

local Run = function(Callback: () -> ())
    Callback()
end
local cloneref = cloneref or function(Reference: Instance)
    return Reference
end
local TweenService = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local TextService = cloneref(game:GetService("TextService"))
local GuiService = cloneref(game:GetService("GuiService"))
local RunService = cloneref(game:GetService("RunService"))
local HttpService = cloneref(game:GetService("HttpService"))
local Lighting = cloneref(game:GetService("Lighting"))

local FontSize: GetTextBoundsParams = Instance.new("GetTextBoundsParams")
FontSize.Width = math.huge
local NotificationCache = {}
local NotificationList = {}
local Notifications
local GetVapeAsset
local VapeColors
local Components
local ClickGUI
local ScaledGUI
local BlurEffect
local BlurFocus
local BlurTween
local GlassConnection
local GlassShown: boolean = true
local GlassParts = {}
local ToolBlur
local Tooltip
local TextGUI
local Scale = {Scale = 1}
local BlurInfo: TweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local GUI
local SortQueued: boolean = false
local BuildClock: number = os.clock()
local BuildBudget: number = 0.004

local function YieldBuild(Budget: number?)
    if os.clock() - BuildClock > (Budget or BuildBudget) then
        BuildBudget = math.clamp(task.wait() * 0.75, 0.004, 0.02)
        BuildClock = os.clock()
    end
end

local isfile = isfile or function(FilePath: string)
    local Success, Data = pcall(function()
        return readfile(FilePath)
    end)

    return Success and Data ~= nil and Data ~= ""
end

local function LoadJSON(FilePath: string)
    local Success, Data = pcall(function()
        return HttpService:JSONDecode(readfile(FilePath))
    end)

    return Success and type(Data) == "table" and Data or nil
end

local function WriteJSON(FilePath: string, Data)
    local Success, Encoded = pcall(HttpService.JSONEncode, HttpService, Data)
    if not Success then
        return false, Encoded
    end

    return pcall(writefile, FilePath, Encoded)
end

local NotificationsOff = isfile("kingvape/profiles/notifications.txt") and readfile("kingvape/profiles/notifications.txt") == "false"
local LoadFailures: number = 0
local DeferredLoads: number = 0
local LoadGeneration: number = 0
local LoadCalled: boolean = false
local CanSave: boolean = true
local NeedsSave: boolean = false
local function AttemptLoad(Object, Data, Name: string)
    local Success, Error = pcall(Object.Load, Object, Data)
    if not Success then
        LoadFailures += 1
        warn(`[catvape] failed to load {Name}: {Error}`)
    end
end

local function FinishLoad()
    if not LoadCalled or DeferredLoads > 0 or vape.Loaded == nil then
        return
    end

    vape.Loaded = CanSave

    if SortQueued then
        vape:SortCategories(true)
    end

    if vape.Downloader then
        vape.Downloader:Destroy()
        vape.Downloader = nil
    end

    if NeedsSave then
        NeedsSave = false
        vape:Save()
    end
end

local FeatureTags
local function GetFeatureTag(Name: string)
    if not FeatureTags then
        FeatureTags = {}

        if not isfile("kingvape/features.json") then
            pcall(function()
                writefile("kingvape/features.json", game:HttpGet("https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/main/features.json", true))
            end)
        end

        local Features = LoadJSON("kingvape/features.json")
        for Tag: string, v: string in {updated = "updated", new = "added"} do
            local List = Features and Features[v]

            if type(List) == "table" then
                for _, Feature: any in List do
                    if type(Feature) == "string" then
                        FeatureTags[Feature] = Tag
                    end
                end
            end
        end
    end

    return FeatureTags[Name]
end

local Color = {}
local UIPallet = {}
do
    function Color.Dark(Color: Color3, Amount: number)
        local Hue, Sat, Val = Color:ToHSV()
        return Color3.fromHSV(Hue, Sat, math.clamp(select(3, UIPallet.Main:ToHSV()) > 0.5 and Val + Amount or Val - Amount, 0, 1))
    end

    function Color.Light(Color: Color3, Amount: number)
        local Hue, Sat, Val = Color:ToHSV()
        return Color3.fromHSV(Hue, Sat, math.clamp(select(3, UIPallet.Main:ToHSV()) > 0.5 and Val - Amount or Val + Amount, 0, 1))
    end

    function vape:Color(Hue: number)
        local Sat: number = 0.74 + (0.26 * math.min(Hue / 0.045, 1))

        if Hue > 0.577 then
            Sat = 1 - (0.48 * math.min((Hue - 0.577) / 0.088, 1))
        end

        if Hue > 0.674 then
            Sat = 0.52 + (0.48 * math.min((Hue - 0.674) / 0.149, 1))
        end

        if Hue > 0.869 then
            Sat = 1 - (0.26 * math.min((Hue - 0.869) / 0.131, 1))
        end

        return Hue, Sat, 1
    end

    function vape:TextColor(Hue: number, Sat: number, Val: number)
        if Val >= 0.7 and (Sat < 0.6 or Hue > 0.04 and Hue < 0.56) then
            return Color3.new(0.19, 0.19, 0.19)
        end

        return Color3.new(1, 1, 1)
    end
end

local BoundsCache, OldCache = {}, {}
local BoundsCount: number = 0

local function GetFontBounds(Text: string, Size: number, FontFace, Width: number?)
    local Key = typeof(FontFace) == "Font" and `{Text}|{Size}|{Width or 0}|{FontFace.Family}|{FontFace.Weight.Name}|{FontFace.Style.Name}`
    if Key then
        local Cached: Vector2? = BoundsCache[Key] or OldCache[Key]
        if Cached then
            if not BoundsCache[Key] then
                BoundsCache[Key] = Cached
                BoundsCount += 1
            end
            return Cached
        end
    end

    FontSize.Text = Text
    FontSize.Size = Size
    FontSize.Width = Width or math.huge
    if typeof(FontFace) == "Font" then
        FontSize.Font = FontFace
    end

    local Bounds: Vector2 = TextService:GetTextBoundsAsync(FontSize)

    if Key then
        if BoundsCount > 2048 then
            OldCache, BoundsCache = BoundsCache, {}
            BoundsCount = 0
        end

        BoundsCache[Key] = Bounds
        BoundsCount += 1
    end

    return Bounds
end

do
    local VapeAssets: {[string]: string} = {
        ["kingvape/assets/new/add.png"] = "rbxassetid://121642387707174",
        ["kingvape/assets/new/aim.png"] = "rbxassetid://122207028123421",
        ["kingvape/assets/new/allowedicon.png"] = "rbxassetid://112336790299036",
        ["kingvape/assets/new/allowediconmini.png"] = "rbxassetid://90142384730147",
        ["kingvape/assets/new/back.png"] = "rbxassetid://80523803497740",
        ["kingvape/assets/new/backmini.png"] = "rbxassetid://85859225495272",
        ["kingvape/assets/new/bind.png"] = "rbxassetid://81399857677684",
        ["kingvape/assets/new/bindbkg.png"] = "rbxassetid://101996225428926",
        ["kingvape/assets/new/blatant.png"] = "rbxassetid://126929923309265",
        ["kingvape/assets/new/blur.png"] = "rbxassetid://79246816170155",
        ["kingvape/assets/new/blurnoti.png"] = "rbxassetid://124705876663719",
        ["kingvape/assets/new/cheat_switch.png"] = "rbxassetid://99437817306124",
        ["kingvape/assets/new/close.png"] = "rbxassetid://121816018671466",
        ["kingvape/assets/new/closemini.png"] = "rbxassetid://108320409341289",
        ["kingvape/assets/new/closetiny.png"] = "rbxassetid://71393233149714",
        ["kingvape/assets/new/colorpreview.png"] = "rbxassetid://140438628568318",
        ["kingvape/assets/new/combat.png"] = "rbxassetid://94762732349053",
        ["kingvape/assets/new/combo_display.png"] = "rbxassetid://97746985576116",
        ["kingvape/assets/new/compassarrow.png"] = "rbxassetid://100463923923900",
        ["kingvape/assets/new/customtheme.png"] = "rbxassetid://91756736022800",
        ["kingvape/assets/new/discord.png"] = "rbxassetid://99871463341003",
        ["kingvape/assets/new/dislike.png"] = "rbxassetid://135092704977606",
        ["kingvape/assets/new/downexpand.png"] = "rbxassetid://94197751291504",
        ["kingvape/assets/new/downexpandslider.png"] = "rbxassetid://90289944682645",
        ["kingvape/assets/new/edit.png"] = "rbxassetid://105801951237137",
        ["kingvape/assets/new/editlarge.png"] = "rbxassetid://119233876755282",
        ["kingvape/assets/new/empty.png"] = "rbxassetid://89525157373515",
        ["kingvape/assets/new/expandarrow.png"] = "rbxassetid://86360332526471",
        ["kingvape/assets/new/expandright.png"] = "rbxassetid://14368316544",
        ["kingvape/assets/new/expandup.png"] = "rbxassetid://14368317595",
        ["kingvape/assets/new/favoritesicon.png"] = "rbxassetid://133471112203189",
        ["kingvape/assets/new/friends.png"] = "rbxassetid://92957214042038",
        ["kingvape/assets/new/hide.png"] = "rbxassetid://129675456133478",
        ["kingvape/assets/new/inventory.png"] = "rbxassetid://93264756888499",
        ["kingvape/assets/new/key_down.png"] = "rbxassetid://",
        ["kingvape/assets/new/key_left.png"] = "rbxassetid://",
        ["kingvape/assets/new/key_lmb.png"] = "rbxassetid://",
        ["kingvape/assets/new/key_mmb.png"] = "rbxassetid://",
        ["kingvape/assets/new/key_right.png"] = "rbxassetid://",
        ["kingvape/assets/new/key_rmb.png"] = "rbxassetid://",
        ["kingvape/assets/new/key_up.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_atmosphere.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_bedalarm.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_bedbreakeffect.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_breadcrumbs.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_bullettracers.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_cape.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_chinahat.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_cleankit.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_clock.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_compass.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_coords.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_crosshair.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_damageindicator.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_disguise.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_fflageditor.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_fixguis.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_fov.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_fps.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_fpsboost.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_fpsunlocker.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_hideshield.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_hitcolor.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_hitfix.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_hitsound.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_interface.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_keystrokes.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_killeffect.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_killsound.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_memory.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_mode_icon.png"] = "rbxassetid://102858626075156",
        ["kingvape/assets/new/legit_ping.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_potionstatus.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_reachdisplay.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_songbeats.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_soundchanger.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_speedmeter.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_switch.png"] = "rbxassetid://127508881124779",
        ["kingvape/assets/new/legit_timechanger.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_uicleanup.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_viewmodel.png"] = "rbxassetid://",
        ["kingvape/assets/new/legit_wineffect.png"] = "rbxassetid://",
        ["kingvape/assets/new/like.png"] = "rbxassetid://80039972048538",
        ["kingvape/assets/new/min.png"] = "rbxassetid://82175054487146",
        ["kingvape/assets/new/newhide.png"] = "rbxassetid://74295679301920",
        ["kingvape/assets/new/noti_alert.png"] = "rbxassetid://82356478726846",
        ["kingvape/assets/new/noti_info.png"] = "rbxassetid://102614825645099",
        ["kingvape/assets/new/noti_warning.png"] = "rbxassetid://119631730212167",
        ["kingvape/assets/new/notification.png"] = "rbxassetid://90300780458781",
        ["kingvape/assets/new/npcs.png"] = "rbxassetid://104434365485227",
        ["kingvape/assets/new/overlaydots.png"] = "rbxassetid://78012624671930",
        ["kingvape/assets/new/overlays.png"] = "rbxassetid://136535637407545",
        ["kingvape/assets/new/overlayslarge.png"] = "rbxassetid://127574141208160",
        ["kingvape/assets/new/pin.png"] = "rbxassetid://92459145800579",
        ["kingvape/assets/new/players.png"] = "rbxassetid://105137446428129",
        ["kingvape/assets/new/profiles.png"] = "rbxassetid://126051451865127",
        ["kingvape/assets/new/profilesicon.png"] = "rbxassetid://14397465323",
        ["kingvape/assets/new/profileworld.png"] = "rbxassetid://122650686344133",
        ["kingvape/assets/new/radar.png"] = "rbxassetid://97983828696086",
        ["kingvape/assets/new/rainbow_1.png"] = "rbxassetid://101329996188554",
        ["kingvape/assets/new/rainbow_2.png"] = "rbxassetid://72739074644654",
        ["kingvape/assets/new/rainbow_3.png"] = "rbxassetid://100716555253397",
        ["kingvape/assets/new/rainbow_4.png"] = "rbxassetid://133424174227092",
        ["kingvape/assets/new/range.png"] = "rbxassetid://107794917650053",
        ["kingvape/assets/new/rangearrow.png"] = "rbxassetid://14368348640",
        ["kingvape/assets/new/rangeindicator.png"] = "rbxassetid://107038094175283",
        ["kingvape/assets/new/render.png"] = "rbxassetid://125472576898654",
        ["kingvape/assets/new/search.png"] = "rbxassetid://115611852955611",
        ["kingvape/assets/new/settingdots.png"] = "rbxassetid://130896840048276",
        ["kingvape/assets/new/settings.png"] = "rbxassetid://73820177347303",
        ["kingvape/assets/new/settingsmini.png"] = "rbxassetid://115732118290997",
        ["kingvape/assets/new/show.png"] = "rbxassetid://85547987939285",
        ["kingvape/assets/new/star.png"] = "rbxassetid://96102671351955",
        ["kingvape/assets/new/sword_header.png"] = "rbxassetid://121706791793204",
        ["kingvape/assets/new/targetinfo.png"] = "rbxassetid://121604266095276",
        ["kingvape/assets/new/targetnpc1.png"] = "rbxassetid://14497400332",
        ["kingvape/assets/new/targetplayers1.png"] = "rbxassetid://14497396015",
        ["kingvape/assets/new/targetstab.png"] = "rbxassetid://14497393895",
        ["kingvape/assets/new/textgui.png"] = "rbxassetid://99438663817412",
        ["kingvape/assets/new/textguiline.png"] = "rbxassetid://",
        ["kingvape/assets/new/theme.png"] = "rbxassetid://111525258317113",
        ["kingvape/assets/new/triangle.png"] = "rbxassetid://75441874213844",
        ["kingvape/assets/new/utility.png"] = "rbxassetid://108303206513893",
        ["kingvape/assets/new/v4.png"] = "rbxassetid://102549752760489",
        ["kingvape/assets/new/v4mini.png"] = "rbxassetid://115213099001611",
        ["kingvape/assets/new/vape.png"] = "rbxassetid://92153855792786",
        ["kingvape/assets/new/vapelogo.png"] = "rbxassetid://126205920310261",
        ["kingvape/assets/new/vapelogomini.png"] = "rbxassetid://109041903452149",
        ["kingvape/assets/new/world.png"] = "rbxassetid://118917453153459"
    }

    local function CreateDownloader(Text: string)
        if vape.Loaded ~= true and vape.gui then
            local Downloader: TextLabel? = vape.Downloader
            if not Downloader then
                Downloader = Instance.new("TextLabel")
                Downloader.BackgroundTransparency = 1
                Downloader.FontFace = UIPallet.Font
                Downloader.Size = UDim2.new(1, 0, 0, 40)
                Downloader.TextColor3 = Color3.new(1, 1, 1)
                Downloader.TextSize = 20
                Downloader.TextStrokeTransparency = 0
                Downloader.Parent = vape.gui
                vape.Downloader = Downloader
            end

            Downloader.Text = `Downloading {Text}`
        end
    end

    local function DownloadFile(FilePath: string, Callback: ((string) -> any)?)
        if not isfile(FilePath) then
            CreateDownloader(FilePath)

            local Success, Data = pcall(function()
                return game:HttpGet(`https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/main/{select(1, FilePath:gsub("kingvape/", ""))}`, true)
            end)

            if not Success or Data == "404: Not Found" then
                error(Data)
            end

            if FilePath:find(".lua", 1, true) then
                Data = `--This watermark is used to delete the file if its cached, remove it to make the file persist after vape updates.\n{Data}`
            end

            writefile(FilePath, Data)
        end

        return (Callback or readfile)(FilePath)
    end

    local AssetCache, AssetFailed = {}

    GetVapeAsset = getcustomasset and function(FilePath: string)
        local Asset: string? = AssetCache[FilePath]

        if Asset == nil then
            Asset = DownloadFile(FilePath, function()
                local Success, Result = pcall(getcustomasset, FilePath)
                if Success then
                    return Result
                end

                if not AssetFailed then
                    AssetFailed = true
                    task.spawn(function()
                        repeat task.wait() until vape.Loaded ~= false
                        if vape.Loaded then
                            vape:CreateNotification("Vape", `Your executor could not load custom assets, so icons and fonts use backups ({Result})`, 15, "warning")
                        end
                    end)
                end
                return VapeAssets[FilePath] or ""
            end)
            AssetCache[FilePath] = Asset
        end

        return Asset
    end or function(FilePath: string)
        return VapeAssets[FilePath] or ""
    end
end

local Tween = setmetatable({}, {
    __index = function()
        return {}
    end
})

do
    function Tween:Tween(Object: Instance, Info: TweenInfo, Goal: {[string]: any}, Index)
        Index = self[Index or "tweens"]
        if Index[Object] then
            Index[Object]:Cancel()
            Index[Object] = nil
        end

        if Object.Parent and (Object:IsA("UIStroke") or Object.Visible) then
            Index[Object] = TweenService:Create(Object, Info, Goal)
            Index[Object].Completed:Once(function()
                if Index then
                    Index[Object] = nil
                    Index = nil
                end
            end)

            Index[Object]:Play()
        else
            for Property: string, Value: any in Goal do
                Object[Property] = Value
            end
        end
    end

    function Tween:Cancel(Object: Instance, Index)
        Index = self[Index or "tweens"]

        if Index[Object] then
            Index[Object]:Cancel()
            Index[Object] = nil
        end
    end
end

UIPallet = {
    Main = Color3.fromRGB(26, 25, 26),
    Text = Color3.fromRGB(200, 200, 200),
    Font = Font.fromEnum(Enum.Font.Arial),
    FontSemiBold = Font.fromEnum(Enum.Font.Arial, Enum.FontWeight.SemiBold),
    FontBold = Font.fromEnum(Enum.Font.Arial, Enum.FontWeight.Bold),
    FontDisplay = Font.new(Font.fromEnum(Enum.Font.Roboto).Family, Enum.FontWeight.Medium),
    DisplayScale = 0.845,
    Tween = TweenInfo.new(0.16, Enum.EasingStyle.Linear)
}

do
    local Success, Family = pcall(function()
        local Regular: string = GetVapeAsset("kingvape/assets/new/proxima.ttf")
        local Bold: string = GetVapeAsset("kingvape/assets/new/proximabd.ttf")
        if Regular == "" or Bold == "" then return end

        writefile("kingvape/assets/new/proxima.json", HttpService:JSONEncode({
            name = "Proxima",
            faces = {
                {name = "Regular", weight = 400, style = "normal", assetId = Regular},
                {name = "SemiBold", weight = 600, style = "normal", assetId = Bold},
                {name = "Bold", weight = 700, style = "normal", assetId = Bold}
            }
        }))

        return getcustomasset("kingvape/assets/new/proxima.json")
    end)

    if Success and Family and Family ~= "" then
        UIPallet.Font = Font.new(Family, Enum.FontWeight.Regular)
    end

    local DisplaySuccess, DisplayFamily = pcall(function()
        local Regular: string = GetVapeAsset("kingvape/assets/new/bahnschrift.ttf")
        if Regular == "" then return end

        writefile("kingvape/assets/new/bahnschrift.json", HttpService:JSONEncode({
            name = "Bahnschrift",
            faces = {
                {name = "Regular", weight = 400, style = "normal", assetId = Regular}
            }
        }))

        return getcustomasset("kingvape/assets/new/bahnschrift.json")
    end)

    if DisplaySuccess and DisplayFamily and DisplayFamily ~= "" then
        UIPallet.FontDisplay = Font.new(DisplayFamily, Enum.FontWeight.Regular)
        UIPallet.DisplayScale = 0.845
    else
        UIPallet.DisplayScale = 1
    end

    local Data = isfile("kingvape/profiles/color.txt") and LoadJSON("kingvape/profiles/color.txt")
    if Data then
        UIPallet.Main = Data.Main and Color3.fromRGB(unpack(Data.Main)) or UIPallet.Main
        UIPallet.Text = Data.Text and Color3.fromRGB(unpack(Data.Text)) or UIPallet.Text
        UIPallet.Font = Data.Font and Font.new(
            Data.Font:find("rbxasset") and Data.Font
            or string.format("rbxasset://fonts/families/%s.json", Data.Font)
        ) or UIPallet.Font
    end

    UIPallet.FontSemiBold = Font.new(UIPallet.Font.Family, Enum.FontWeight.SemiBold)
    UIPallet.FontBold = Font.new(UIPallet.Font.Family, Enum.FontWeight.Bold)
    FontSize.Font = UIPallet.Font
end

VapeColors = {
    Primary = Color3.fromRGB(209, 209, 209),
    Secondary = Color3.fromRGB(163, 163, 163),
    Muted = Color3.fromRGB(89, 88, 89),
    Icon = Color3.fromRGB(122, 122, 122),
    IconHover = Color.Light(Color3.fromRGB(122, 122, 122), 0.35),
    Panel = Color3.fromRGB(31, 30, 31),
    Raised = Color3.fromRGB(40, 39, 40),
    Outline = Color3.fromRGB(54, 53, 54),
    Input = Color3.fromRGB(20, 20, 20),
    Accent = Color3.fromRGB(5, 134, 105),
    AccentHover = Color3.fromRGB(6, 161, 126),
    Danger = Color3.fromRGB(250, 50, 56),
    Favorite = Color3.fromRGB(236, 129, 44),
    Share = Color3.fromRGB(236, 170, 118)
}

vape.Libraries = {
	color = Color,
	getfontbounds = GetFontBounds,
	getvapeasset = GetVapeAsset,
	tween = Tween,
	uipallet = UIPallet,
	vapecolors = VapeColors,
}

local function AddBlur(Parent: Instance, Notification: boolean?, Old: boolean?)
    local Blur
    if Old then
        Blur = Instance.new("ImageLabel")
        Blur.Name = "Blur"
        Blur.Size = UDim2.new(1, 89, 1, 52)
        Blur.Position = UDim2.fromOffset(-48, -31)
        Blur.BackgroundTransparency = 1
        Blur.Image = GetVapeAsset(`kingvape/assets/new/{Notification and "blurnoti" or "blur"}.png`)
        Blur.ScaleType = Enum.ScaleType.Slice
        Blur.SliceCenter = Rect.new(52, 31, 261, 502)
        Blur.Parent = Parent
    else
        Blur = Instance.new("UIShadow")
        Blur.BlurRadius = UDim.new(0, 13)
        Blur.Transparency = 0.25
        Blur.Parent = Parent
    end

    return Blur
end

local function AddShadow(Parent: Instance, Blur: number?, Transparency: number?)
    local Shadow: UIShadow = Instance.new("UIShadow")
    Shadow.Name = "Shadow"
    Shadow.Color = Color3.new()
    Shadow.Offset = UDim2.new()
    Shadow.Spread = UDim2.new()
    Shadow.BlurRadius = UDim.new(0, Blur or 16)
    Shadow.Transparency = Transparency or 0.404
    Shadow.Parent = Parent

    return Shadow
end

local function AddCorner(Parent: Instance, Radius: UDim?)
    local Corner: UICorner = Instance.new("UICorner")
    Corner.CornerRadius = Radius or UDim.new(0, 5)
    Corner.Parent = Parent

    return Corner
end

local function AddCloseButton(Parent: Instance, Mini: boolean?, Offset: UDim2?)
    local Close: ImageButton = Instance.new("ImageButton")
    Close.AutoButtonColor = false
    Close.BackgroundColor3 = Color3.new(1, 1, 1)
    Close.BackgroundTransparency = 1
    Close.Image = GetVapeAsset(`kingvape/assets/new/{Mini and "closemini" or "close"}.png`)
    Close.ImageColor3 = Color.Light(UIPallet.Text, 0.2)
    Close.ImageTransparency = 0.5
    Close.Name = "Close"
    Close.Position = Offset or (Mini and UDim2.new(1, -28, 0, 11) or UDim2.new(1, -35, 0, 9))
    Close.Size = Mini and UDim2.fromOffset(20, 20) or UDim2.fromOffset(24, 24)
    Close.Parent = Parent
    AddCorner(Close, UDim.new(1, 0))

    Close.MouseEnter:Connect(function()
        Close.ImageTransparency = 0.3
        Tween:Tween(Close, UIPallet.Tween, {
            BackgroundTransparency = 0.6
        })
    end)

    Close.MouseLeave:Connect(function()
        Close.ImageTransparency = 0.5
        Tween:Tween(Close, UIPallet.Tween, {
            BackgroundTransparency = 1
        })
    end)

    return Close
end

local function AddDragHandler(Gui: GuiObject, Window)
    Gui.InputBegan:Connect(function(Input: InputObject)
        if vape.ThreadFix then
            setthreadidentity(8)
        end

        if Window and not Window.Visible then return end

        if
            (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch)
            and (Input.Position.Y - Gui.AbsolutePosition.Y < 40 or Window)
        then
            local DragPosition: Vector2 = Vector2.new(
                Gui.AbsolutePosition.X - Input.Position.X,
                Gui.AbsolutePosition.Y - Input.Position.Y + GuiService:GetGuiInset().Y
            ) / Scale.Scale

            local ReleaseConnection
            local MoveConnection: RBXScriptConnection = UserInputService.InputChanged:Connect(function(NewInput: InputObject)
                if vape.ThreadFix then
                    setthreadidentity(8)
                end

                if NewInput.UserInputType == (Input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
                    local Position: Vector3 = NewInput.Position
                    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                        DragPosition = (DragPosition // 3) * 3
                        Position = (Position // 3) * 3
                    end

                    Gui.Position = UDim2.fromOffset((Position.X / Scale.Scale) + DragPosition.X, (Position.Y / Scale.Scale) + DragPosition.Y)
                end
            end)

            ReleaseConnection = Input.Changed:Connect(function()
                if Input.UserInputState == Enum.UserInputState.End then
                    MoveConnection:Disconnect()
                    ReleaseConnection:Disconnect()
                    vape:QueueSave()
                end
            end)
        end
    end)
end

local function AddMaid(Object)
    Object.Connections = {}

    function Object:Clean(Callback)
        if typeof(Callback) == "Instance" then
            table.insert(self.Connections, {
                Disconnect = function()
                    Callback:ClearAllChildren()
                    Callback:Destroy()
                end
            })
        elseif type(Callback) == "thread" then
            table.insert(self.Connections, {
                Disconnect = function()
                    if coroutine.status(Callback) ~= "dead" then
                        task.cancel(Callback)
                    end
                end
            })
        elseif type(Callback) == "function" then
            table.insert(self.Connections, {
                Disconnect = Callback
            })
        else
            table.insert(self.Connections, Callback)
        end
    end
end

local function AddTooltip(Gui: GuiObject, Text: string?, CustomText: (() -> string)?, VisibleCheck: (() -> boolean)?)
    if not Text then return end

    local function TooltipMoved(X: number, Y: number)
        if VisibleCheck and VisibleCheck() then
            return
        end

        local IsRight: boolean = X + 16 + Tooltip.Size.X.Offset > (Scale.Scale * 1920)
        Tooltip.Position = UDim2.fromOffset(
            (IsRight and X - (Tooltip.Size.X.Offset * Scale.Scale) - 16 or X + 16) / Scale.Scale,
            ((Y + 11) - (Tooltip.Size.Y.Offset / 2)) / Scale.Scale
        )

        Tooltip.Visible = ToolBlur.Enabled
    end

    local function Callback()
        local NewText: string = CustomText()
        Tooltip.Text = NewText
        local TooltipSize: Vector2 = GetFontBounds(Tooltip.ContentText, Tooltip.TextSize, UIPallet.Font)
        Tooltip.Size = UDim2.fromOffset(TooltipSize.X + 10, TooltipSize.Y + 10)
    end

    Gui.MouseEnter:Connect(function(X: number, Y: number)
        if VisibleCheck and VisibleCheck() then
            return
        end

        Tooltip.Text = Text
        local TooltipSize: Vector2 = GetFontBounds(Tooltip.ContentText, Tooltip.TextSize, UIPallet.Font)
        Tooltip.Size = UDim2.fromOffset(TooltipSize.X + 10, TooltipSize.Y + 10)
        TooltipMoved(X, Y)

        if CustomText then
            vape.CurrentTooltip = Callback
            Callback()
        end
    end)
    Gui.MouseMoved:Connect(TooltipMoved)
    Gui.MouseLeave:Connect(function()
        if VisibleCheck and VisibleCheck() then
            return
        end

        Tooltip.Visible = false
        vape.CurrentTooltip = nil
    end)
end

local function BuildOptionsView(Module, Parent: Instance, Order: number)
    local Frame: Frame = Instance.new("Frame")
    Frame.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.02)
    Frame.BorderSizePixel = 0
    Frame.LayoutOrder = Order
    Frame.Name = `{Module.Name}Children`
    Frame.Size = UDim2.new(1, 0, 0, 0)
    Frame.Visible = false
    Frame.Parent = Parent
    local Layout: UIListLayout = Instance.new("UIListLayout")
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.Parent = Frame

    Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if vape.ThreadFix then
            setthreadidentity(8)
        end

        Frame.Size = UDim2.new(1, 0, 0, Layout.AbsoluteContentSize.Y / Scale.Scale)
    end)

    if Module.CreateOptionsView then
        Module:CreateOptionsView(Frame)
    end

    return Frame
end

local function ConvertBind(Bind)
    if type(Bind) ~= "table" then
        return {Keys = {}}
    end

    if Bind.Keys then
        return Bind
    end

    if Bind.Mobile then
        return {Keys = {}, Mobile = {X = Bind.X, Y = Bind.Y}}
    end

    return {Keys = Bind}
end

local function StripLegacyMax(Container)
    for _, v: any in Container or {} do
        for _, Option: any in v.Options or {} do
            if type(Option) == "table" then
                Option.Max = nil
            end
        end
    end
end

local function ReadProfile(Profile: string)
    local FilePath: string = `kingvape/profiles/{Profile}{vape.Place}.txt`
    if not isfile(FilePath) then
        return nil
    end

    local Data = LoadJSON(FilePath)
    if not Data then
        return false
    end

    Data.Categories = Data.Categories or {}
    Data.Modules = Data.Modules or {}
    Data.Legit = Data.Legit or {}

    if Data.v ~= 1 then
        for _, Module: any in Data.Modules do
            Module.Bind = ConvertBind(Module.Bind)
            Module.Visible = true
        end

        StripLegacyMax(Data.Modules)
        StripLegacyMax(Data.Categories)
        StripLegacyMax(Data.Legit)
    end

    return Data
end

local function FindLegacy(Container, Name)
    Name = Name:gsub(" ", "")
    for Key: string, v: any in Container do
        if Key:gsub(" ", "") == Name or (v.ConfigName or ""):gsub(" ", "") == Name then
            return v
        end
    end
end

local function LoadNew(Container, List, Existing)
    for Name: string, Data: any in List do
        local Component = Container[Name] or FindLegacy(Container, Name)

        if Component and not Existing[Component] then
            if vape.ThreadFix then
                setthreadidentity(8)
            end

            AttemptLoad(Component, Data, Name)
        end
    end
end

local function CreateSignal()
    local Signal = {
        Connections = {}
    }

    function Signal:Connect(Callback)
        table.insert(self.Connections, Callback)

        return {
            Disconnect = function()
                local Index: number? = table.find(Signal.Connections, Callback)
                if Index then
                    table.remove(Signal.Connections, Index)
                end
            end
        }
    end

    function Signal:Fire(...)
        for _, Callback: (...any) -> ...any in self.Connections do
            task.spawn(Callback, ...)
        end
    end

    return Signal
end

local function CheckKeybinds(Compare: {string}, Target, Key: string)
    if type(Target) == "table" then
        if table.find(Target, Key) then
            for _, TargetKey: any in Target do
                if not table.find(Compare, TargetKey) then
                    return false
                end
            end

            return true
        end
    end

    return false
end

local function IsFinite(Value)
    return type(Value) == "number" and Value == Value and Value ~= math.huge and Value ~= -math.huge
end

local function GetTableSize(Dictionary: {[any]: any})
    local Size: number = 0
    for _ in Dictionary do
        Size += 1
    end

    return Size
end

local function ListenProperty(Source: Instance, Destination, Property: string, Object: Instance)
    Destination[Property] = Source[Property]
    local Connection: RBXScriptConnection = Source:GetPropertyChangedSignal(Property):Connect(function()
        Destination[Property] = Source[Property]
    end)

    Object.Destroying:Once(function()
        Connection:Disconnect()
    end)
end

local function LoopClean(Object)
    for Key: any, Value: any in Object do
        if type(Value) == "table" then
            LoopClean(Value)
        end

        Object[Key] = nil
    end
end

local function RandomString()
    local Array: {string} = {}
    for i: number = 1, math.random(10, 100) do
        Array[i] = string.char(math.random(32, 126))
    end

    return table.concat(Array)
end

local function IsRendered(Object: Instance?)
    while Object do
        if Object:IsA("LayerCollector") then
            return Object.Enabled
        end

        if Object:IsA("GuiObject") and not Object.Visible then
            return false
        end

        Object = Object.Parent
    end

    return false
end

local function RefreshGlass()
    if vape.HUDBlur and not vape.HUDBlur.Enabled then
        if GlassShown then
            GlassShown = false
            for _, v: {Frame: GuiObject, Mesh: SpecialMesh, Part: Part} in GlassParts do
                v.Part.Parent = nil
            end
        end

        return
    end

    GlassShown = true
    local Camera: Camera = workspace.CurrentCamera
    local Offset: number = ((Camera.ViewportSize.Y * 48) / 2560) + 8
    local CameraCFrame: CFrame = Camera.CFrame
    local XVector, YVector, ZVector = CameraCFrame.XVector, CameraCFrame.YVector, CameraCFrame.ZVector

    for _, v: {Frame: GuiObject, Mesh: SpecialMesh, Part: Part} in GlassParts do
        local Frame: GuiObject = v.Frame

        if Frame.BackgroundTransparency >= 1 or not IsRendered(Frame) then
            v.Part.Parent = nil
            continue
        end

        local Size: Vector2 = Frame.AbsoluteSize - Vector2.new(Offset, Offset)
        local Corner: Vector2 = Frame.AbsolutePosition + Vector2.new(Offset / 2, Offset / 2)

        if Size.X <= 0 or Size.Y <= 0 then
            v.Part.Parent = nil
            continue
        end

        local TopLeft = Camera:ScreenPointToRay(Corner.X, Corner.Y)
        local BottomRight = Camera:ScreenPointToRay(Corner.X + Size.X, Corner.Y + Size.Y)
        TopLeft = TopLeft.Origin + (TopLeft.Direction * 0.001)
        BottomRight = BottomRight.Origin + (BottomRight.Direction * 0.001)
        local Delta: Vector3 = BottomRight - TopLeft

        if v.Part.Parent ~= Camera then
            v.Part.Parent = Camera
        end

        v.Part.CFrame = CFrame.fromMatrix((TopLeft + BottomRight) / 2, XVector, YVector, ZVector)
        v.Mesh.Scale = Vector3.new(Delta:Dot(XVector), -Delta:Dot(YVector), 0)
    end
end

local function AddGlass(Frame: GuiObject)
    if UserInputService.TouchEnabled then return end

    local GlassPart: Part = Instance.new("Part")
    GlassPart.Anchored = true
    GlassPart.CanCollide = false
    GlassPart.CanQuery = false
    GlassPart.CanTouch = false
    GlassPart.CastShadow = false
    GlassPart.Color = Color3.new()
    GlassPart.Locked = true
    GlassPart.Material = Enum.Material.Glass
    GlassPart.Name = RandomString()
    GlassPart.Size = Vector3.new(1, 1, 0)
    GlassPart.Transparency = 0.98
    local GlassMesh: SpecialMesh = Instance.new("SpecialMesh")
    GlassMesh.MeshType = Enum.MeshType.Brick
    GlassMesh.Offset = Vector3.new(0, 0, -0.000001)
    GlassMesh.Parent = GlassPart

    if #GlassParts == 0 then
        GlassConnection = RunService.RenderStepped:Connect(function()
            if vape.ThreadFix then
                setthreadidentity(8)
            end

            RefreshGlass()
        end)
    end

    table.insert(GlassParts, {Frame = Frame, Mesh = GlassMesh, Part = GlassPart})

    return GlassPart
end

local function RemoveTags(Text: string)
    Text = Text:gsub("<br%s*/>", "\n")
    return Text:gsub("<[^<>]->", "")
end

local function ParseTimestamp(Value)
    if type(Value) == "number" then return Value end
    if type(Value) ~= "string" then return 0 end

    local Year, Month, Day, Hour, Minute, Second = Value:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if not Year then return tonumber(Value) or 0 end

    return os.time({
        year = tonumber(Year),
        month = tonumber(Month),
        day = tonumber(Day),
        hour = tonumber(Hour),
        min = tonumber(Minute),
        sec = tonumber(Second)
    })
end

local function ParseFilename(Entry)
    local Id, Name = tostring(Entry.filename or ""):match("^%((%d+)%)%-%((.+)%)%.json$")

    return Name or (Entry.config_name ~= "unknown" and Entry.config_name) or "Unnamed", (Entry.discord_username ~= "unknown" and Entry.discord_username) or Id or "unknown"
end

local AvatarCache = {}
local AvatarPlaceholder: string = "rbxasset://textures/ui/GuiImagePlaceholder.png"

local function ApplyAvatar(Image: ImageLabel, Url: string?)
    Image.Image = AvatarPlaceholder
    if type(Url) ~= "string" or not Url:find("^https?://") then return end

    Url = Url:gsub("%.webp", ".png")
    if AvatarCache[Url] then
        Image.Image = AvatarCache[Url]
        return
    end

    task.spawn(function()
        if vape.ThreadFix then
            setthreadidentity(8)
        end

        if not isfolder("kingvape/assets/pfp") then
            makefolder("kingvape/assets/pfp")
        end

        local FilePath: string = `kingvape/assets/pfp/{Url:gsub("%W", ""):sub(-48)}.png`
        if not isfile(FilePath) then
            local Success, Response = pcall(request, {Url = Url, Method = "GET"})
            if not Success or not Response or not Response.Body or Response.Body == "" then return end
            writefile(FilePath, Response.Body)
        end

        local Success, Asset = pcall(getcustomasset, FilePath)
        if not Success or not Asset then return end

        AvatarCache[Url] = Asset
        if Image.Parent then
            Image.Image = Asset
        end
    end)
end

local function RelativeDays(Uploaded)
    local Days: number = math.floor((os.time() - (tonumber(Uploaded) or os.time())) / 86400)
    if Days <= 0 then return "Today" end
    return `{Days}{Days == 1 and " day ago" or " days ago"}`
end

function vape:BlurCheck()
    if self.ThreadFix then
        setthreadidentity(8)
    end

    local Enabled: boolean = (ClickGUI.Visible or (self.Legit and self.Legit.Window.Visible) or GuiService:GetErrorType() ~= Enum.ConnectionError.OK) and self.Blur.Enabled or false

    if self.ThreadFix then
        RunService:SetRobloxGuiFocused(Enabled)
    end

    if not BlurEffect then
        BlurEffect = Instance.new("BlurEffect")
        BlurEffect.Enabled = false
        BlurEffect.Name = RandomString()
        BlurEffect.Size = 0
        BlurEffect.Parent = Lighting
        BlurFocus = Instance.new("DepthOfFieldEffect")
        BlurFocus.FarIntensity = 0
        BlurFocus.InFocusRadius = 0.1
        BlurFocus.Name = RandomString()
        BlurFocus.NearIntensity = 1
        BlurFocus.Parent = Lighting
        self.BlurEffects = self.BlurEffects or {}
        table.insert(self.BlurEffects, BlurEffect)
        table.insert(self.BlurEffects, BlurFocus)
    end

    BlurEffect.Enabled = true

    if BlurTween then
        BlurTween:Cancel()
    end

    BlurTween = TweenService:Create(BlurEffect, BlurInfo, {
        Size = Enabled and (self.BlurIntensity and self.BlurIntensity.Value or 24) or 0
    })
    BlurTween:Play()

    if not Enabled then
        task.delay(0.3, function()
            if self.ThreadFix then
                setthreadidentity(8)
            end

            if BlurEffect then
                BlurEffect.Enabled = BlurEffect.Size > 0.5
            end
        end)
    end
end

function vape:CreateCategory(Properties)
    local Category = Components.Category(Properties)
    YieldBuild()

    return Category
end

function vape:CreateCategoryList(Properties)
    local List = Components.CategoryList(Properties)
    YieldBuild()

    return List
end

local function ReflowNotifications()
    local Offset: number = 32

    for _, v: any in NotificationList do
        Offset += v.Height
        if Tween.Tween and v.Object.Position.Y.Offset ~= 0 then
            Tween:Tween(v.Object, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
                Position = UDim2.new(1, 0, 1, -Offset)
            })
        else
            v.Object.Position = UDim2.new(1, 0, 1, -Offset)
        end
        Offset += 3
    end
end

local function BuildNotification()
    local Notification: ImageLabel = Instance.new("ImageLabel")
    Notification.BackgroundTransparency = 1
    Notification.Image = GetVapeAsset("kingvape/assets/new/notification.png")
    Notification.Position = UDim2.new(1, 0, 1, 0)
    Notification.ScaleType = Enum.ScaleType.Slice
    Notification.SliceCenter = Rect.new(7, 7, 9, 9)
    Notification.ZIndex = 5
    Notification.Parent = Notifications
    AddBlur(Notification, true, true)
    local IconShadow: ImageLabel = Instance.new("ImageLabel")
    IconShadow.BackgroundTransparency = 1
    IconShadow.ImageColor3 = Color3.new()
    IconShadow.ImageTransparency = 0.5
    IconShadow.Position = UDim2.fromOffset(-5, -8)
    IconShadow.Size = UDim2.fromOffset(60, 60)
    IconShadow.ZIndex = 5
    IconShadow.Parent = Notification
    local Icon: ImageLabel = IconShadow:Clone()
    Icon.ImageColor3 = Color3.new(1, 1, 1)
    Icon.ImageTransparency = 0
    Icon.Position = UDim2.fromOffset(-1, -1)
    Icon.Parent = IconShadow
    local Title: TextLabel = Instance.new("TextLabel")
    Title.BackgroundTransparency = 1
    Title.FontFace = UIPallet.FontSemiBold
    Title.Position = UDim2.fromOffset(46, 16)
    Title.RichText = true
    Title.Size = UDim2.new(1, -56, 0, 20)
    Title.TextSize = 14
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.TextYAlignment = Enum.TextYAlignment.Top
    Title.ZIndex = 5
    Title.Parent = Notification
    local TextShadow: TextLabel = Title:Clone()
    TextShadow.FontFace = UIPallet.Font
    TextShadow.Position = UDim2.fromOffset(47, 44)
    TextShadow.RichText = false
    TextShadow.TextColor3 = Color3.new()
    TextShadow.TextTransparency = 0.5
    TextShadow.TextWrapped = true
    TextShadow.Parent = Notification
    local Text: TextLabel = TextShadow:Clone()
    Text.Position = UDim2.fromOffset(-1, -1)
    Text.RichText = true
    Text.TextColor3 = Color3.fromRGB(170, 170, 170)
    Text.TextTransparency = 0
    Text.Parent = TextShadow
    local Progress: Frame = Instance.new("Frame")
    Progress.BorderSizePixel = 0
    Progress.Position = UDim2.new(0, 3, 1, -4)
    Progress.Size = UDim2.new(1, -13, 0, 1)
    Progress.ZIndex = 5
    Progress.Parent = Notification

    return {
        Height = 75,
        Icon = Icon,
        IconShadow = IconShadow,
        Object = Notification,
        Progress = Progress,
        Text = Text,
        TextShadow = TextShadow,
        Title = Title
    }
end

local function StartNotification(Entry, Title: string, Text: string, Duration: number, Type: string?)
    local Plain: string = RemoveTags(Text)
    local LineHeight: number = GetFontBounds("A", 14, UIPallet.Font).Y
    local Bounds: Vector2 = GetFontBounds(Plain, 14, UIPallet.Font, 200)
    local Count: number = math.max(math.round(Bounds.Y / LineHeight), 1)
    local Accent: Color3 = Type == "alert" and Color3.fromRGB(250, 50, 56)
        or Type == "warning" and Color3.fromRGB(236, 129, 44)
        or Color3.new(1, 1, 1)
    Entry.Text.LineHeight = 16.8 / LineHeight
    Entry.Text.Text = Text
    Entry.Text.Size = UDim2.fromOffset(200, Count * 16.8 + 2)
    while not Entry.Text.TextFits and Count < math.round(Bounds.Y / LineHeight) + 2 do
        Count += 1
        Entry.Text.Size = UDim2.fromOffset(200, Count * 16.8 + 2)
    end
    Entry.Height = 75 + ((Count - 1) * 16.8)
    Entry.Icon.Image = GetVapeAsset(`kingvape/assets/new/noti_{Type or "info"}.png`)
    Entry.IconShadow.Image = Entry.Icon.Image
    Entry.Object.Size = UDim2.fromOffset(math.max(Bounds.X + 80, GetFontBounds(RemoveTags(Title), 14, UIPallet.FontSemiBold).X + 66, 266), Entry.Height)
    Entry.Progress.BackgroundColor3 = Accent
    Entry.Progress.Size = UDim2.new(1, -13, 0, 1)
    Entry.Text.Size = UDim2.fromOffset(200, Count * 16.8)
    Entry.TextShadow.LineHeight = Entry.Text.LineHeight
    Entry.TextShadow.Size = Entry.Text.Size
    Entry.TextShadow.Text = Plain
    Entry.Title.Text = `<stroke joins='round' thickness='0.3' transparency='0.5'>{Title}</stroke>`
    Entry.Title.TextColor3 = Type == "alert" and Accent or Color3.new(1, 1, 1)
    ReflowNotifications()

    if Tween.Tween then
        Tween:Tween(Entry.Object, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
            AnchorPoint = Vector2.new(1, 0)
        }, "tweenstwo")

        Tween:Tween(Entry.Progress, TweenInfo.new(Duration, Enum.EasingStyle.Linear), {
            Size = UDim2.fromOffset(0, 1)
        })
    end

    return task.delay(Duration, function()
        if vape.ThreadFix then
            setthreadidentity(8)
        end

        if Tween.Tween then
            Tween:Tween(Entry.Object, TweenInfo.new(0.4, Enum.EasingStyle.Exponential), {
                AnchorPoint = Vector2.new(0, 0)
            }, "tweenstwo")
        end

        task.wait(0.2)
        local Index: number? = table.find(NotificationList, Entry)
        if Index then
            table.remove(NotificationList, Index)
        end

        if Entry.Reuse then
            NotificationCache[Entry.Reuse] = nil
        end

        Entry.Object:ClearAllChildren()
        Entry.Object:Destroy()
        ReflowNotifications()
    end)
end

function vape:CreateNotification(Title: string, Text: string, Duration: number, Type: string?, Reuse)
    if not self.Notifications.Enabled or (NotificationsOff and not LoadCalled) then
        return
    end

    task.delay(0, function()
        if self.ThreadFix then
            setthreadidentity(8)
        end

        local Entry = Reuse and NotificationCache[Reuse]
        if Entry and Entry.Object.Parent and table.find(NotificationList, Entry) then
            task.cancel(Entry.Thread)
            Entry.Thread = StartNotification(Entry, Title, Text, Duration, Type)

            return
        end

        Entry = BuildNotification()
        table.insert(NotificationList, Entry)
        Entry.Thread = StartNotification(Entry, Title, Text, Duration, Type)

        if Reuse then
            Entry.Reuse = Reuse
            NotificationCache[Reuse] = Entry
        end
    end)
end

function vape:CreateOverlay(Properties)
    return Components.Overlay(Properties)
end

local DefaultGUI, DefaultMain

local function CollectConfig(GuiData, MainData, Skip)
    for _, Category: any in vape.Categories do
        local Target = Category.Type == "Overlay" and MainData or GuiData

        if Target and (not Skip or not Skip[Category]) then
            Category:Save(Target.Categories)
        end
    end

    if not MainData then return end

    for _, Module: any in vape.Modules do
        if not Skip or not Skip[Module] then
            Module:Save(MainData.Modules)
        end
    end

    for _, Module: any in vape.Legit.Modules do
        if not Skip or not Skip[Module] then
            Module:Save(MainData.Legit)
        end
    end
end

local function SaveDefaults(Main: boolean?, Skip)
    if not DefaultGUI then
        DefaultGUI = {Categories = {}}
        CollectConfig(DefaultGUI)
    end

    if not Main then return end

    if not DefaultMain then
        DefaultMain = {Modules = {}, Categories = {}, Legit = {}}
        CollectConfig(nil, DefaultMain)
    elseif Skip then
        CollectConfig(nil, DefaultMain, Skip)
    end
end

function vape:Load(SkipGui: boolean?, Profile: string?)
    if self.ThreadFix then
        setthreadidentity(8)
    end

    self.Loaded = false
    SaveDefaults()
    LoadFailures = 0
    LoadGeneration += 1
    CanSave = true
    NeedsSave = false

    local Generation: number = LoadGeneration
    local LoadBudget: number? = SkipGui and 0.0015 or nil
    local GuiData = {Categories = {}}
    local OldProfile: string = self.Profile
    local ToggleCount: number = 0
    local ResolvedCount, MissingCount = 0, 0

    if isfile(`kingvape/profiles/{game.GameId}.gui.txt`) then
        GuiData = LoadJSON(`kingvape/profiles/{game.GameId}.gui.txt`)
        if not GuiData then
            local Profiles = {}
            for _, v: string in listfiles("kingvape/profiles") do
                local Name: string? = v:match(`([^/\\]+){vape.Place}%.txt$`)
                if Name then
                    table.insert(Profiles, {Name = Name, Bind = {Keys = {}}})
                end
            end

            local Success, Raw = pcall(readfile, `kingvape/profiles/{game.GameId}.gui.txt`)
            if Success then
                writefile(`kingvape/profiles/{game.GameId}.gui.corrupt.txt`, Raw)
            end
            GuiData = {Categories = {Profiles = {List = Profiles}}, v = 1}
            self:CreateNotification("Vape", `Your GUI settings were corrupted and got reset, the old file was saved as {game.GameId}.gui.corrupt.txt`, 15, "alert")
        end

        GuiData.Categories = GuiData.Categories or {}

        if GuiData.v ~= 1 then
            GuiData.Categories.Main = nil

            if GuiData.Profiles then
                local Profiles = {}

                for _, v: any in GuiData.Profiles do
                    table.insert(Profiles, {
                        Name = v.Name,
                        Bind = ConvertBind(v.Bind)
                    })
                end

                GuiData.Categories.Profiles = GuiData.Categories.Profiles or {}
                GuiData.Categories.Profiles.List = Profiles
            end

            if GuiData.Keybind and self.GUIBind then
                self.GUIBind:SetBind(GuiData.Keybind)
            end

            StripLegacyMax(GuiData.Categories)
        end

        self.Profile = Profile or GuiData.Profile or "default"
        if self.ProfileLabel then
            self.ProfileLabel.Text = #self.Profile > 10 and `{self.Profile:sub(1, 10)}...` or self.Profile
            self.ProfileLabel.Size = UDim2.fromOffset(GetFontBounds(self.ProfileLabel.Text, self.ProfileLabel.TextSize, self.ProfileLabel.FontFace).X + 16, 24)
        end

        if not SkipGui then
            for Name: string, Data: any in GuiData.Categories do
                local Category = self.Categories[Name]
                if Category then
                    if self.ThreadFix then
                        setthreadidentity(8)
                    end

                    AttemptLoad(Category, Data, Name)
                end
            end
        end
    end

    if not self.Categories.Profiles:GetValue("default") then
        self.Categories.Profiles:ChangeValue("default", true)
    end

    SaveDefaults(true)
    local MainData = ReadProfile(self.Profile)
    if MainData == false then
        MainData = {Categories = {}, Modules = {}, Legit = {}}
        self:CreateNotification("Vape", `Failed to load {self.Profile} profile, saving is off until you fix or delete it`, 15, "alert")
        CanSave = false
    end

    if MainData then
        for Name: string, Data: any in MainData.Categories do
            local Category = self.Categories[Name]
            if Category then
                if self.ThreadFix then
                    setthreadidentity(8)
                end

                AttemptLoad(Category, Data, Name)
                YieldBuild(LoadBudget)

                if LoadGeneration ~= Generation then return end
            end
        end

        for Name: string, Data: any in MainData.Modules do
            local Module = self.Modules[Name] or FindLegacy(self.Modules, Name)
            if Module then
                if self.ThreadFix then
                    setthreadidentity(8)
                end

                AttemptLoad(Module, Data, Name)
                ToggleCount += Module.Enabled and 1 or 0
                ResolvedCount += 1
                YieldBuild(LoadBudget)

                if LoadGeneration ~= Generation then return end
            else
                MissingCount += 1
            end
        end

        if MissingCount > ResolvedCount then
            CanSave = false
            self:CreateNotification("Vape", `{MissingCount} of your saved modules are missing, the script did not fully load. Saving is off so your config is not overwritten, rejoin to fix it`, 20, "alert")
        end

        for Name: string, Data: any in MainData.Legit do
            local Module = self.Legit.Modules[Name] or FindLegacy(self.Legit.Modules, Name)
            if Module then
                if self.ThreadFix then
                    setthreadidentity(8)
                end

                AttemptLoad(Module, Data, Name)
                YieldBuild(LoadBudget)

                if LoadGeneration ~= Generation then return end
            end
        end

        self:UpdateTextGUI(true)
    else
        NeedsSave = true
    end

    if self.Profile ~= OldProfile and SkipGui then
        self:CreateNotification(`Profile swap to <font color="#FFAA00">{self.Profile}</font>`, `{ToggleCount} modules enabled`, 3)
    end

    if LoadFailures > 0 then
        self:CreateNotification("Vape", `{LoadFailures} settings failed to load, check the developer console (F9) for the errors`, 15, "alert")
    end

    self:SortCategories(true)
    LoadCalled = true
    FinishLoad()
    GUI.Enabled = true

    if (not UserInputService.KeyboardEnabled or UserInputService.TouchEnabled or shared.VapeDeveloper) and not SkipGui and not self.VapeButton then
        local Hide: boolean = not shared.VapeDeveloper and isfile("kingvape/profiles/hidebutton.txt") and readfile("kingvape/profiles/hidebutton.txt") == "true"
        local Inset = GuiService:GetGuiInset()
        local Button: TextButton = Instance.new("TextButton")
        Button.BackgroundColor3 = Color3.new()
        Button.BackgroundTransparency = Hide and 1 or 0.35
        Button.Name = "VapeButton"
        Button.Position = UDim2.new(1, -90, 0, 4)
        Button.Size = UDim2.fromOffset(32, 32)
        Button.Text = ""
        Button.Parent = GUI
        self.VapeButton = Button
        AddCorner(Button, UDim.new(0, 8))
        
        local Image: ImageLabel = Instance.new("ImageLabel")
        Image.AnchorPoint = Vector2.new(0.5, 0.5)
        Image.BackgroundTransparency = 1
        Image.Image = GetVapeAsset("kingvape/assets/new/vape.png")
        Image.ImageTransparency = Hide and 1 or 0
        Image.Name = "Icon"
        Image.Position = UDim2.fromScale(0.5, 0.5)
        Image.Size = UDim2.fromOffset(22, 22)
        Image.Parent = Button
        self:Clean(Button)

        Button.MouseButton1Click:Connect(function()
            self.GUIBind.Triggered:Fire(true)
        end)

        task.spawn(function()
            if self.ThreadFix then
                setthreadidentity(8)
            end

            local PlayerGui: PlayerGui = cloneref(game:GetService("Players")).LocalPlayer.PlayerGui
            local ActiveFollow: (() -> ())?

            local function BindTopBar(TopBarGui: Instance)
                local TopBar = TopBarGui:WaitForChild("TopBarApp", 15)
                if not TopBar or not Button.Parent then return end

                local Layout = TopBar:FindFirstChildWhichIsA("UIListLayout")

                local function Follow()
                    local Origin: Vector2 = GUI.AbsolutePosition
                    local Bounds: Vector2 = GUI.AbsoluteSize
                    local Left: number = Layout and TopBar.AbsolutePosition.X + TopBar.AbsoluteSize.X - Layout.AbsoluteContentSize.X or TopBar.AbsolutePosition.X
                    local Top: number = TopBar.AbsolutePosition.Y
                    if self.SearchBar.Object.Visible and Left - 40 < self.SearchBar.Object.AbsolutePosition.X + self.SearchBar.Object.AbsoluteSize.X and Left - 8 > self.SearchBar.Object.AbsolutePosition.X then
                        Left = self.SearchBar.Object.AbsolutePosition.X
                    end

                    local X: number = Left - 40
                    local FreeLeft: number = GuiService.TopbarInset.Min.X - GuiService:GetGuiInset().X
                    if X < FreeLeft then
                        X, Top = math.max(Left, FreeLeft), Top + (Layout and Layout.AbsoluteContentSize.Y or TopBar.AbsoluteSize.Y) + 8
                    end

                    Button.Position = UDim2.fromOffset(math.clamp(X - Origin.X, 0, math.max(Bounds.X - 32, 0)), math.clamp(Top - Origin.Y, 0, math.max(Bounds.Y - 32, 0)))
                end

                ActiveFollow = Follow
                self:Clean(TopBar:GetPropertyChangedSignal("AbsolutePosition"):Connect(Follow))
                self:Clean(TopBar:GetPropertyChangedSignal("AbsoluteSize"):Connect(Follow))

                if Layout then
                    self:Clean(Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(Follow))
                end
                Follow()
            end

            self:Clean(GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
                if ActiveFollow then
                    ActiveFollow()
                end
            end))

            self:Clean(PlayerGui.ChildAdded:Connect(function(Child: Instance)
                if Child.Name == "TopBarAppGui" then
                    BindTopBar(Child)
                end
            end))

            local TopBarGui: Instance? = PlayerGui:WaitForChild("TopBarAppGui", 15)
            if TopBarGui then
                BindTopBar(TopBarGui)
            end
        end)
    end
end

local function DeferLoad(Callback: () -> ())
    DeferredLoads += 1

    task.spawn(function()
        if vape.ThreadFix then
            setthreadidentity(8)
        end

        local Existing: {[any]: boolean} = {}
        for _, Container: any in {vape.Modules, vape.Legit.Modules, vape.Categories} do
            for _, Component: any in Container do
                Existing[Component] = true
            end
        end

        local Failures: number = LoadFailures
        local Success, Error = pcall(Callback)
        if not Success then
            warn(`[catvape] failed to run deferred load: {Error}`)
        end

        SaveDefaults(true, Existing)

        Success, Error = pcall(function()
            for _, Container: any in {vape.Modules, vape.Legit.Modules} do
                for _, Module: any in Container do
                    if not Existing[Module] then
                        vape:AddOptionBinds(Module)
                    end
                end
            end

            local MainData = vape.Loaded ~= nil and ReadProfile(vape.Profile)
            if type(MainData) == "table" then
                LoadNew(vape.Modules, MainData.Modules, Existing)
                LoadNew(vape.Legit.Modules, MainData.Legit, Existing)
                LoadNew(vape.Categories, MainData.Categories, Existing)
                vape:UpdateTextGUI(true)
            end
        end)

        if not Success then
            warn(`[catvape] failed to load deferred settings: {Error}`)
        end

        if LoadFailures > Failures then
            vape:CreateNotification("Vape", `{LoadFailures - Failures} settings failed to load, check the developer console (F9) for the errors`, 15, "alert")
        end

        DeferredLoads -= 1
        FinishLoad()
    end)
end

function vape:LoadOptions(Object, Data)
    for Name: string, v: any in Data or {} do
        local Component = Object.Options[Name]

        if Component then
            if self.ThreadFix then
                setthreadidentity(8)
            end

            AttemptLoad(Component, v, Name)
        end
    end
end

function vape:LoadGUI()
	AddMaid(vape)
	GUI = Instance.new("ScreenGui")
	GUI.Enabled = false
	GUI.Name = RandomString()
	GUI.DisplayOrder = 9999999
	GUI.ZIndexBehavior = Enum.ZIndexBehavior.Global
	GUI.IgnoreGuiInset = true
	
	if false then
	    local Holder: Folder = Instance.new("Folder")
	    Holder.Parent = cloneref(game:GetService("CoreGui"))
	    GUI.OnTopOfCoreBlur = true
	    GUI.Parent = (gethui and gethui()) or cloneref(game:GetService("CoreGui"))
	    vape.holder = Holder
	else
	    pcall(function() GUI.OnTopOfCoreBlur = true; end)
	    GUI.Parent = cloneref(game:GetService("Players")).LocalPlayer.PlayerGui
	    GUI.ResetOnSpawn = false
	    vape.holder = GUI
	end
	vape.gui = GUI
	
	ScaledGUI = Instance.new("Frame")
	ScaledGUI.BackgroundTransparency = 1
	ScaledGUI.Name = "ScaledGui"
	ScaledGUI.Size = UDim2.fromScale(1, 1)
	ScaledGUI.Parent = GUI
	ClickGUI = Instance.new("Frame")
	ClickGUI.BackgroundTransparency = 1
	ClickGUI.Name = "ClickGui"
	ClickGUI.Size = UDim2.fromScale(1, 1)
	ClickGUI.Visible = false
	ClickGUI.Parent = ScaledGUI
	local ScarcityBanner: TextLabel = Instance.new("TextLabel")
	ScarcityBanner.BackgroundTransparency = 1
	ScarcityBanner.FontFace = UIPallet.Font
	ScarcityBanner.Position = UDim2.fromScale(0, 0.8)
	ScarcityBanner.Size = UDim2.fromScale(1, 0.022)
	ScarcityBanner.Text = "Thank you for choosing catvape - catvape.dev"
	ScarcityBanner.TextColor3 = Color3.new(1, 1, 1)
	ScarcityBanner.TextScaled = true
	ScarcityBanner.TextStrokeTransparency = 0.5
	ScarcityBanner.Parent = ClickGUI
	local Modal: TextButton = Instance.new("TextButton")
	Modal.BackgroundTransparency = 1
	Modal.Modal = true
	Modal.Text = ""
	Modal.Parent = ClickGUI
	local Cursor: ImageLabel = Instance.new("ImageLabel")
	Cursor.BackgroundTransparency = 1
	Cursor.Image = "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png"
	Cursor.Size = UDim2.fromOffset(64, 64)
	Cursor.Visible = false
	Cursor.Parent = GUI
	Notifications = Instance.new("Folder")
	Notifications.Name = "Notifications"
	Notifications.Parent = ScaledGUI
	Tooltip = Instance.new("TextLabel")
	Tooltip.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.02)
	Tooltip.FontFace = UIPallet.Font
	Tooltip.Position = UDim2.fromScale(-1, -1)
	Tooltip.RichText = true
	Tooltip.Text = ""
	Tooltip.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
	Tooltip.TextSize = 12
	Tooltip.Visible = false
	Tooltip.ZIndex = 5
	Tooltip.Parent = ScaledGUI
	ToolBlur = AddBlur(Tooltip)
	AddCorner(Tooltip)
	Scale = Instance.new("UIScale")
	Scale.Scale = math.max(GUI.AbsoluteSize.X / 1920, UserInputService:GetPlatform() == Enum.Platform.OSX and 1 or 0.4)
	Scale.Parent = ScaledGUI
	vape.guiscale = Scale
	ScaledGUI.Size = UDim2.fromScale(1 / Scale.Scale, 1 / Scale.Scale)
	Components.GUI({})
	
	vape:CreateCategory({
	    Name = "Combat",
	    Icon = GetVapeAsset("kingvape/assets/new/combat.png"),
	    Size = UDim2.fromOffset(13, 14)
	})
	vape:CreateCategory({
	    Name = "Blatant",
	    Icon = GetVapeAsset("kingvape/assets/new/blatant.png"),
	    Size = UDim2.fromOffset(14, 14)
	})
	vape:CreateCategory({
	    Name = "Render",
	    Icon = GetVapeAsset("kingvape/assets/new/render.png"),
	    Size = UDim2.fromOffset(15, 14)
	})
	vape:CreateCategory({
	    Name = "Utility",
	    Icon = GetVapeAsset("kingvape/assets/new/utility.png"),
	    Size = UDim2.fromOffset(15, 14)
	})
	vape:CreateCategory({
	    Name = "World",
	    Icon = GetVapeAsset("kingvape/assets/new/world.png"),
	    Size = UDim2.fromOffset(14, 14)
	})
	vape:CreateCategory({
	    Name = "Inventory",
	    Icon = GetVapeAsset("kingvape/assets/new/inventory.png"),
	    Size = UDim2.fromOffset(15, 14)
	})
	vape:CreateCategory({
	    Name = "Kits",
	    Icon = GetVapeAsset("kingvape/assets/new/friends.png"),
	    Size = UDim2.fromOffset(17, 16)
	})
	vape.Categories.Main:CreateDivider({
	    Text = "misc"
	})
	
	do
	    local Friends
	    local FriendsColor = {
	        Hue = 1,
	        Sat = 1,
	        Value = 1
	    }
	
	    Friends = vape:CreateCategoryList({
	        Name = "Friends",
	        Icon = GetVapeAsset("kingvape/assets/new/friends.png"),
	        Size = UDim2.fromOffset(17, 16),
	        Placeholder = "Roblox username",
	        Color = Color3.fromRGB(5, 134, 105),
	        Function = function()
	            Friends.Update:Fire()
	            Friends.ColorUpdate:Fire(FriendsColor.Hue, FriendsColor.Sat, FriendsColor.Value)
	        end
	    })
	    Friends.Update = Instance.new("BindableEvent")
	    Friends.ColorUpdate = Instance.new("BindableEvent")
	    Friends:CreateToggle({
	        Name = "Recolor visuals",
	        Darker = true,
	        Default = true,
	        Function = function()
	            Friends.Update:Fire()
	            Friends.ColorUpdate:Fire(FriendsColor.Hue, FriendsColor.Sat, FriendsColor.Value)
	        end
	    })
	    FriendsColor = Friends:CreateColorSlider({
	        Name = "Friends color",
	        Darker = true,
	        Function = function(Hue: number, Sat: number, Val: number)
	            for _, v: Instance in Friends.Object.Children:GetChildren() do
	                local Dot = v:FindFirstChild("Dot")
	                if Dot and Dot.BackgroundColor3 ~= Color.Light(UIPallet.Main, 0.37) then
	                    Dot.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
	                    Dot.Dot.BackgroundColor3 = Dot.BackgroundColor3
	                end
	            end
	
	            Friends.ColorUpdate:Fire(Hue, Sat, Val)
	        end
	    })
	    Friends:CreateToggle({
	        Name = "Use friends",
	        Darker = true,
	        Default = true,
	        Function = function()
	            Friends.Update:Fire()
	            Friends.ColorUpdate:Fire(FriendsColor.Hue, FriendsColor.Sat, FriendsColor.Value)
	        end
	    })
	    vape:Clean(Friends.Update)
	    vape:Clean(Friends.ColorUpdate)
	end
	
	local ImportConfig
	local Profiles = vape:CreateCategoryList({
	    Name = "Profiles",
	    Icon = GetVapeAsset("kingvape/assets/new/profiles.png"),
	    Size = UDim2.fromOffset(17, 10),
	    Position = UDim2.fromOffset(12, 16),
	    Placeholder = "Type name",
	    Profiles = true
	})
	Profiles:CreateButton({
	    Name = "Sync to current profile",
	    Function = function()
	        vape:Save()
	        vape:CreateNotification(`Synced to <font color="#FFAA00">{vape.Profile}</font>`, "Every module and option was written to the profile", 3)
	    end,
	    Tooltip = "Writes every module and option you currently have set into the profile you are on"
	})
	Profiles:CreateButton({
	    Name = "Reset current profile",
	    Function = function()
	        vape.Save = function() end
	        if isfile(`kingvape/profiles/{vape.Profile}{vape.Place}.txt`) and delfile then
	            delfile(`kingvape/profiles/{vape.Profile}{vape.Place}.txt`)
	        end
	
	        shared.vapereload = true
	        if shared.VapeDeveloper then
	            loadstring(readfile("kingvape/init.lua"), "init")(License)
	        else
	            loadstring(game:HttpGet("https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/main/init.lua", true), "init")(License)
	        end
	    end,
	    Tooltip = "This will set your profile to the default settings of Vape"
	})
	Profiles:CreateButton({
	    Name = "Export config",
	    Function = function()
	        local Text, Error = vape:ExportConfig()
	
	        if not Text then
	            vape:CreateNotification("Vape", `Could not export your config, {Error}`, 10, "alert")
	            return
	        end
	
	        writefile("kingvape/profiles/export.txt", Text)
	
	        if setclipboard then
	            setclipboard(Text)
	        end
	
	        vape:CreateNotification("Config exported", `{#Text} characters copied to your clipboard and saved to kingvape/profiles/export.txt`, 6)
	    end,
	    Tooltip = "Packs every module, option and gui setting for this game into one line of text and copies it to your clipboard"
	})
	ImportConfig = Profiles:CreateTextBox({
	    Name = "Import config",
	    Function = function(Enter: boolean)
	        if not Enter or ImportConfig.Value == "" then return end
	
	        local Text: string = ImportConfig.Value
	        ImportConfig:SetValue("")
	
	        local Success, Result = vape:ImportConfig(Text)
	
	        if Success then
	            vape:CreateNotification("Config imported", `Loaded {Result and Result ~= "" and `<font color="#FFAA00">{Result}</font>` or "the config"} into <font color="#FFAA00">{vape.Profile}</font>`, 5)
	        else
	            vape:CreateNotification("Vape", `Could not import that config, {Result}`, 10, "alert")
	        end
	    end,
	    Placeholder = "Paste config here",
	    Tooltip = "Paste an exported config and press enter, it overwrites the profile you are on"
	})
	
	local Targets
	Targets = vape:CreateCategoryList({
	    Name = "Targets",
	    Icon = GetVapeAsset("kingvape/assets/new/friends.png"),
	    Size = UDim2.fromOffset(17, 16),
	    Placeholder = "Roblox username",
	    Function = function()
	        Targets.Update:Fire()
	    end
	})
	Targets.Update = Instance.new("BindableEvent")
	vape:Clean(Targets.Update)
	
	Components.LegitWindow()
	vape.SearchBar = Components.SearchBar()
	vape.Categories.Main:CreateOverlayBar()
	
	vape:CreateCategory({
	    Name = "Favorites",
	    Icon = GetVapeAsset("kingvape/assets/new/favoritesicon.png"),
	    Size = UDim2.fromOffset(14, 14),
	    Position = UDim2.fromOffset(850, 465),
	    NoButton = true
	})
	vape.Categories.Favorites.Paint = vape.PaintFavorites
	
	Components.PublicProfiles()
	
	local General = vape.Categories.Main.Settings:CreateSettingsPane({Name = "General"})
	local SettingConnections = {}
	vape.MultiKeybind = General:CreateToggle({
	    Name = "Enable Multi-Keybinding",
	    Tooltip = "Allows multiple keys to be bound to a module (eg. G + H)"
	})
	local OptionKeybinds
	local function AddOptionBinds(Module)
	    for _, Component: any in Module.Options do
	        if Component.Type == "Toggle" then
	            local Bind = Components.Bind({
	                Module = true
	            }, nil, Component)
	            Bind.Object.Position = UDim2.new(1, -40, 0, 5)
	
	            table.insert(SettingConnections, Bind.Triggered:Connect(function(IsDown: boolean)
	                if Bind.Hold then
	                    if Component.Enabled ~= IsDown then
	                        if vape.SettingToggleNotifications.Enabled then
	                            vape:CreateNotification(Module.Name, `{Component.Name} {not Component.Enabled and "<font color='#00AA00'>ON</font>" or "<font color='#FF5A5A'>OFF</font>"}`, 1.5)
	                        end
	
	                        Component:Toggle()
	                    end
	                else
	                    if vape.SettingToggleNotifications.Enabled then
	                        vape:CreateNotification(Module.Name, `{Component.Name} {not Component.Enabled and "<font color='#00AA00'>ON</font>" or "<font color='#FF5A5A'>OFF</font>"}`, 1.5)
	                    end
	
	                    Component:Toggle()
	                end
	            end))
	
	            table.insert(SettingConnections, Component.Object.MouseEnter:Connect(function()
	                Bind:SetVisible(true)
	            end))
	
	            table.insert(SettingConnections, Component.Object.MouseLeave:Connect(function()
	                Bind:SetVisible(false)
	            end))
	        end
	    end
	end
	
	function vape:AddOptionBinds(Module)
	    if not OptionKeybinds or not OptionKeybinds.Enabled then
	        return
	    end
	
	    AddOptionBinds(Module)
	end
	
	OptionKeybinds = General:CreateToggle({
	    Name = "Allow setting keybinds",
	    Function = function(Callback: boolean)
	        if Callback then
	            for _, Container: any in {vape.Modules, vape.Legit.Modules} do
	                for _, Module: any in Container do
	                    AddOptionBinds(Module)
	                end
	            end
	        else
	            for _, Container: any in {vape.Modules, vape.Legit.Modules} do
	                for _, Module: any in Container do
	                    for _, Component: any in Module.Options do
	                        if Component.Bind then
	                            Component.Bind:Destroy()
	                        end
	                    end
	                end
	            end
	
	            for _, Connection: RBXScriptConnection in SettingConnections do
	                Connection:Disconnect()
	            end
	            table.clear(SettingConnections)
	        end
	    end,
	    Tooltip = "Hover a toggle setting to bind it to a key"
	})
	
	General:CreateButton({
	    Name = "Self destruct",
	    Function = function()
	        vape:Uninject()
	    end,
	    Tooltip = "Removes vape from the current game"
	})
	
	General:CreateButton({
	    Name = "Reinject",
	    Function = function()
	        shared.vapereload = true
	        if shared.VapeDeveloper then
	            loadstring(readfile("kingvape/init.lua"), "init")(License)
	        else
	            loadstring(game:HttpGet("https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/main/init.lua", true), "init")(License)
	        end
	    end,
	    Tooltip = "Reloads vape for debugging purposes"
	})
	
	local Modules = vape.Categories.Main.Settings:CreateSettingsPane({Name = "Modules"})
	Modules:CreateToggle({
	    Name = "Teams by server",
	    Tooltip = "Ignore players on your team designated by the server",
	    Default = true,
	    Function = function()
	        if vape.Libraries.entity and vape.Libraries.entity.Running then
	            vape.Libraries.entity.refresh()
	        end
	    end
	})
	
	Modules:CreateToggle({
	    Name = "Use team color",
	    Tooltip = "Uses the TeamColor property on players for render modules",
	    Default = true,
	    Function = function()
	        if vape.Libraries.entity and vape.Libraries.entity.Running then
	            vape.Libraries.entity.refresh()
	        end
	    end
	})
	
	local GUIPane = vape.Categories.Main.Settings:CreateSettingsPane({Name = "GUI"})
	vape.Blur = GUIPane:CreateToggle({
	    Name = "Blur background",
	    Function = function(Callback: boolean)
	        if vape.BlurIntensity then
	            vape.BlurIntensity.Object.Visible = Callback
	        end
	
	        vape:BlurCheck()
	    end,
	    Default = true,
	    Tooltip = "Blur the background of the GUI"
	})
	
	vape.BlurIntensity = GUIPane:CreateSlider({
	    Name = "Blur intensity",
	    Min = 1,
	    Max = 56,
	    Default = 24,
	    Function = function()
	        vape:BlurCheck()
	    end,
	    Darker = true,
	    Tooltip = "How strongly the world behind the GUI is blurred"
	})
	
	vape.HUDBlur = GUIPane:CreateToggle({
	    Name = "HUD blur",
	    Default = true,
	    Tooltip = "Frosted backdrop behind HUD panels, turn it off for more fps"
	})
	
	GUIPane:CreateToggle({
	    Name = "GUI bind indicator",
	    Default = true,
	    Tooltip = "Displays a message indicating your GUI upon injecting.\nI.E. 'Press RSHIFT to open GUI'"
	})
	
	GUIPane:CreateToggle({
	    Name = "Show tooltips",
	    Function = function(Enabled: boolean)
	        Tooltip.Visible = false
	        ToolBlur.Enabled = Enabled
	    end,
	    Default = true,
	    Tooltip = "Toggles visibility of these"
	})
	
	GUIPane:CreateToggle({
	    Name = "Show legit mode",
	    Function = function(Enabled: boolean)
	        ClickGUI.Search.Legit.Visible = Enabled
	        ClickGUI.Search.LegitDivider.Visible = Enabled
	        ClickGUI.Search.TextBox.Size = UDim2.new(1, Enabled and -50 or -10, 0, 37)
	        ClickGUI.Search.TextBox.Position = UDim2.fromOffset(Enabled and 50 or 10, 0)
	    end,
	    Default = true,
	    Tooltip = "Shows the button to switch to the legit mod menu"
	})
	
	local ScaleSlider = {Object = {}, Value = 1}
	vape.Scale = GUIPane:CreateToggle({
	    Name = "Auto rescale",
	    Default = true,
	    Function = function(Callback: boolean)
	        ScaleSlider.Object.Visible = not Callback
	        if Callback then
	            Scale.Scale = math.max(GUI.AbsoluteSize.X / 1920, UserInputService:GetPlatform() == Enum.Platform.OSX and 1 or 0.4)
	        else
	            Scale.Scale = ScaleSlider.Value
	        end
	    end,
	    Tooltip = "Automatically rescales the gui using the screens resolution"
	})
	
	ScaleSlider = GUIPane:CreateSlider({
	    Name = "Scale",
	    Min = 0.1,
	    Max = 2,
	    Decimal = 10,
	    Function = function(Val: number, Final: boolean?)
	        if Final and not vape.Scale.Enabled then
	            Scale.Scale = Val
	        end
	    end,
	    Default = 1,
	    Darker = true,
	    Visible = false
	})
	
	vape.RainbowSpeed = GUIPane:CreateSlider({
	    Name = "Rainbow speed",
	    Min = 0.1,
	    Max = 10,
	    Decimal = 10,
	    Default = 1,
	    Tooltip = "Adjusts the speed of rainbow values"
	})
	
	vape.RainbowUpdateSpeed = GUIPane:CreateSlider({
	    Name = "Rainbow update rate",
	    Min = 1,
	    Max = 144,
	    Default = 60,
	    Tooltip = "Adjusts the update rate of rainbow values",
	    Suffix = "hz"
	})
	
	if not UserInputService.KeyboardEnabled or UserInputService.TouchEnabled or shared.VapeDeveloper then
	    GUIPane:CreateToggle({
	        Name = "Hide Vape Button",
	        Default = isfile("kingvape/profiles/hidebutton.txt") and readfile("kingvape/profiles/hidebutton.txt") == "true",
	        Function = function(Enabled: boolean)
	            if vape.VapeButton then
	                vape.VapeButton.BackgroundTransparency = Enabled and 1 or 0.35
	                vape.VapeButton.Icon.ImageTransparency = Enabled and 1 or 0
	            end
	
	            writefile("kingvape/profiles/hidebutton.txt", tostring(Enabled))
	        end,
	        Tooltip = "Hides the button that opens the GUI"
	    })
	end
	GUIPane:CreateDropdown({
	    Name = "Search bar style",
	    List = {"Floating", "None"},
	    Default = "Floating",
	    Function = function(Value: string)
	        vape.SearchBar.Object.Visible = Value == "Floating"
	    end,
	    Tooltip = "Switch between search bar styles"
	})
	
	vape.RainbowMode = GUIPane:CreateDropdown({
	    Name = "Rainbow Mode",
	    List = {"Normal", "Gradient", "Retro"},
	    Tooltip = "Normal - Smooth color fade\nGradient - Gradient color fade\nRetro - Static color"
	})
	
	GUIPane:CreateButton({
	    Name = "Reset GUI positions",
	    Function = function()
	        for _, Category: any in vape.Categories do
	            Category.Object.Position = UDim2.fromOffset(6, 42)
	        end
	    end,
	    Tooltip = "This will reset your GUI back to the default"
	})
	
	GUIPane:CreateButton({
	    Name = "Sort GUI",
	    Function = function()
	        local Priority: {[string]: number} = {
	            GUICategory = 1,
	            CombatCategory = 2,
	            BlatantCategory = 3,
	            RenderCategory = 4,
	            UtilityCategory = 5,
	            WorldCategory = 6,
	            InventoryCategory = 7,
	            FriendsCategory = 8,
	            ProfilesCategory = 9
	        }
	
	        local Categories = {}
	        for _, Category: any in vape.Categories do
	            if Category.Type ~= "Overlay" then
	                table.insert(Categories, Category)
	            end
	        end
	
	        table.sort(Categories, function(A, B)
	            return (Priority[A.Object.Name] or 99) < (Priority[B.Object.Name] or 99)
	        end)
	
	        local Index: number = 0
	        for _, Category: any in Categories do
	            if Category.Object.Visible then
	                Category.Object.Position = UDim2.fromOffset(6 + (Index % 8 * 230), 60 + (Index > 7 and 360 or 0))
	                Index += 1
	            end
	        end
	    end,
	    Tooltip = "Sorts GUI by category order"
	})
	
	local NotificationPane = vape.Categories.Main.Settings:CreateSettingsPane({Name = "Notifications"})
	vape.Notifications = NotificationPane:CreateToggle({
	    Name = "Notifications",
	    Function = function(Enabled: boolean)
	        pcall(writefile, "kingvape/profiles/notifications.txt", tostring(Enabled))
	
	        if vape.ToggleNotifications.Object then
	            vape.ToggleNotifications.Object.Visible = Enabled
	        end
	
	        if vape.SettingToggleNotifications.Object then
	            vape.SettingToggleNotifications.Object.Visible = Enabled
	        end
	    end,
	    Tooltip = "Shows notifications",
	    Default = true
	})
	
	vape.ToggleNotifications = NotificationPane:CreateToggle({
	    Name = "Toggle alert",
	    Tooltip = "Notifies you if a module is enabled/disabled.",
	    Default = true,
	    Darker = true
	})
	vape.SettingToggleNotifications = NotificationPane:CreateToggle({
	    Name = "Setting toggle alert",
	    Tooltip = "Notifies you when a bound setting is toggled.",
	    Default = true,
	    Darker = true
	})
	
	vape.GUIColor = vape.Categories.Main.Settings:CreateGUISlider({
	    Name = "GUI Theme",
	    Function = function(Hue: number, Sat: number, Val: number)
	        vape:UpdateGUI(Hue, Sat, Val, true)
	    end
	})
	
	vape.GUIBind = vape.Categories.Main.Settings:CreateBind({
	    Name = "Rebind GUI",
	    Default = {"RightShift"},
	    NoRemove = true,
	    Tooltip = "Change the bind of the GUI"
	})
	
	Run(function()
		local Sort
		local FontOption
		local ColorSlider
		local ColorMode
		local Scale
		local Shadow
		local Gradient
		local GradientV4
		local Animations
		local Watermark
		local Background
		local BackgroundTransparency
		local BackgroundTint
		local HideModules
		local HideModulesList
		local HideRender
		local CustomText
		local CustomTextBox
		local CustomTextFont
		local CustomTextColor
		local CustomTextColorSlider
		local Labels = {}
		local Rows, RowStyle = {}, nil
		local Info: TweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Exponential)
		
		TextGUI = vape:CreateOverlay({
		    Name = "Text GUI",
		    Icon = GetVapeAsset("kingvape/assets/new/textgui.png"),
		    Size = UDim2.fromOffset(16, 12),
		    Position = UDim2.fromOffset(12, 14),
		    Function = function()
		        vape:UpdateTextGUI()
		    end
		})
		Sort = TextGUI:CreateDropdown({
		    Name = "Sort",
		    List = {"Alphabetical", "Length"},
		    Function = function()
		        vape:UpdateTextGUI()
		    end
		})
		FontOption = TextGUI:CreateFont({
		    Name = "Font",
		    Default = "Vape",
		    Function = function()
		        vape:UpdateTextGUI()
		    end
		})
		ColorMode = TextGUI:CreateDropdown({
		    Name = "Color Mode",
		    List = {"Match GUI color", "Custom color"},
		    Function = function(Value: string)
		        ColorSlider.Object.Visible = Value == "Custom color"
		        vape:UpdateTextGUI()
		    end
		})
		ColorSlider = TextGUI:CreateColorSlider({
		    Name = "Text GUI color",
		    Function = function()
		        vape:UpdateGUI(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
		    end,
		    Darker = true,
		    Visible = false
		})
		TextGUI:CreateSlider({
		    Name = "Scale",
		    Min = 0,
		    Max = 2,
		    Decimal = 10,
		    Default = 1,
		    Function = function(Val: number)
		        Scale.Scale = Val
		        vape:UpdateTextGUI()
		    end
		})
		Shadow = TextGUI:CreateToggle({
		    Name = "Shadow",
		    Tooltip = "Renders shadowed text.",
		    Function = function()
		        vape:UpdateTextGUI()
		    end
		})
		Gradient = TextGUI:CreateToggle({
		    Name = "Gradient",
		    Tooltip = "Renders a gradient",
		    Function = function(Callback: boolean)
		        GradientV4.Object.Visible = Callback
		        vape:UpdateTextGUI()
		    end
		})
		GradientV4 = TextGUI:CreateToggle({
		    Name = "V4 Gradient",
		    Function = function()
		        vape:UpdateTextGUI()
		    end,
		    Darker = true,
		    Visible = false
		})
		Animations = TextGUI:CreateToggle({
		    Name = "Animations",
		    Tooltip = "Use animations on text gui",
		    Function = function()
		        vape:UpdateTextGUI()
		    end
		})
		Watermark = TextGUI:CreateToggle({
		    Name = "Watermark",
		    Tooltip = "Renders a vape watermark",
		    Function = function()
		        vape:UpdateTextGUI()
		    end
		})
		Background = TextGUI:CreateToggle({
		    Name = "Render background",
		    Function = function(Callback: boolean)
		        BackgroundTransparency.Object.Visible = Callback
		        BackgroundTint.Object.Visible = Callback
		        vape:UpdateTextGUI()
		    end
		})
		BackgroundTransparency = TextGUI:CreateSlider({
		    Name = "Transparency",
		    Min = 0,
		    Max = 1,
		    Default = 0.5,
		    Decimal = 10,
		    Function = function()
		        vape:UpdateTextGUI()
		    end,
		    Darker = true,
		    Visible = false
		})
		BackgroundTint = TextGUI:CreateToggle({
		    Name = "Tint",
		    Function = function()
		        vape:UpdateTextGUI()
		    end,
		    Darker = true,
		    Visible = false
		})
		HideModules = TextGUI:CreateToggle({
		    Name = "Hide modules",
		    Tooltip = "Allows you to blacklist certain modules from being shown.",
		    Function = function(Enabled: boolean)
		        HideModulesList.Object.Visible = Enabled
		        vape:UpdateTextGUI()
		    end
		})
		HideModulesList = TextGUI:CreateTextList({
		    Name = "Blacklist",
		    Tooltip = "Name of module to hide.",
		    Color = Color3.fromRGB(250, 50, 56),
		    Function = function()
		        vape:UpdateTextGUI()
		    end,
		    Visible = false,
		    Darker = true
		})
		HideRender = TextGUI:CreateToggle({
		    Name = "Hide render",
		    Function = function()
		        vape:UpdateTextGUI()
		    end
		})
		CustomText = TextGUI:CreateToggle({
		    Name = "Add custom text",
		    Function = function(Enabled: boolean)
		        CustomTextBox.Object.Visible = Enabled
		        CustomTextFont.Object.Visible = Enabled
		        CustomTextColor.Object.Visible = Enabled
		        CustomTextColorSlider.Object.Visible = CustomTextColor.Enabled and Enabled
		        vape:UpdateTextGUI()
		    end
		})
		CustomTextBox = TextGUI:CreateTextBox({
		    Name = "Custom text",
		    Function = function()
		        vape:UpdateTextGUI()
		    end,
		    Darker = true,
		    Visible = false
		})
		CustomTextFont = TextGUI:CreateFont({
		    Name = "Custom Font",
		    Default = "Vape",
		    Function = function()
		        vape:UpdateTextGUI()
		    end,
		    Darker = true,
		    Visible = false
		})
		CustomTextColor = TextGUI:CreateToggle({
		    Name = "Set custom text color",
		    Function = function(Enabled: boolean)
		        CustomTextColorSlider.Object.Visible = Enabled
		        vape:UpdateGUI(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
		    end,
		    Darker = true,
		    Visible = false
		})
		CustomTextColorSlider = TextGUI:CreateColorSlider({
		    Name = "Color of custom text",
		    Function = function(AfterLoad)
		        vape:UpdateGUI(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
		    end,
		    Darker = true,
		    Visible = false
		})
		
		Scale = Instance.new("UIScale")
		Scale.Parent = TextGUI.Children
		local Logo: ImageLabel = Instance.new("ImageLabel")
		Logo.BackgroundColor3 = Color3.new()
		Logo.BackgroundTransparency = 1
		Logo.BorderSizePixel = 0
		Logo.Image = GetVapeAsset("kingvape/assets/new/vapelogo.png")
		Logo.Name = "Logo"
		Logo.Position = UDim2.new(1, -142, 0, 3)
		Logo.Size = UDim2.fromOffset(81, 24)
		Logo.Visible = false
		Logo.Parent = TextGUI.Children
		local LogoV4: ImageLabel = Instance.new("ImageLabel")
		LogoV4.BackgroundColor3 = Color3.new()
		LogoV4.BackgroundTransparency = 1
		LogoV4.BorderSizePixel = 0
		LogoV4.Image = GetVapeAsset("kingvape/assets/new/v4.png")
		LogoV4.Name = "Logo2"
		LogoV4.Position = UDim2.new(1, -1, 0, 0)
		LogoV4.Size = UDim2.fromOffset(35, 24)
		LogoV4.Parent = Logo
		local LogoShadow: ImageLabel = Logo:Clone()
		LogoShadow.ImageColor3 = Color3.new()
		LogoShadow.ImageTransparency = 0.333
		LogoShadow.Position = UDim2.fromOffset(1, 1)
		LogoShadow.Visible = true
		LogoShadow.ZIndex = 0
		LogoShadow.Parent = Logo
		LogoShadow.Logo2.ImageColor3 = Color3.new()
		LogoShadow.Logo2.ImageTransparency = 0.333
		LogoShadow.Logo2.ZIndex = 0
		local LogoGradient: UIGradient = Instance.new("UIGradient")
		LogoGradient.Rotation = 90
		LogoGradient.Parent = Logo
		local LogoGradient2: UIGradient = Instance.new("UIGradient")
		LogoGradient2.Rotation = 90
		LogoGradient2.Parent = LogoV4
		local LabelCustom: TextLabel = Instance.new("TextLabel")
		LabelCustom.BackgroundTransparency = 1
		LabelCustom.BorderSizePixel = 0
		LabelCustom.FontFace = Font.new(CustomTextFont.Value.Family, Enum.FontWeight.Bold)
		LabelCustom.Position = UDim2.fromOffset(5, 2)
		LabelCustom.Text = ""
		LabelCustom.TextSize = 22
		LabelCustom.Visible = false
		LabelCustom.RichText = true
		local LabelCustomShadow: TextLabel = LabelCustom:Clone()
		LabelCustomShadow.TextColor3 = Color3.new()
		LabelCustomShadow.TextTransparency = 0.333
		LabelCustomShadow.Parent = TextGUI.Children
		LabelCustom.Parent = TextGUI.Children
		local LabelHolder: Frame = Instance.new("Frame")
		LabelHolder.Name = "Holder"
		LabelHolder.Size = UDim2.fromScale(1, 1)
		LabelHolder.Position = UDim2.fromOffset(5, 37)
		LabelHolder.BackgroundTransparency = 1
		LabelHolder.Parent = TextGUI.Children
		local ListLayout: UIListLayout = Instance.new("UIListLayout")
		ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		ListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
		ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		ListLayout.Parent = LabelHolder
		
		LabelCustom:GetPropertyChangedSignal("Position"):Connect(function()
		    LabelCustomShadow.Position = UDim2.new(
		        LabelCustom.Position.X.Scale,
		        LabelCustom.Position.X.Offset + 1,
		        0,
		        LabelCustom.Position.Y.Offset + 1
		    )
		end)
		
		LabelCustom:GetPropertyChangedSignal("FontFace"):Connect(function()
		    LabelCustomShadow.FontFace = LabelCustom.FontFace
		end)
		
		LabelCustom:GetPropertyChangedSignal("Text"):Connect(function()
		    LabelCustomShadow.Text = LabelCustom.ContentText
		end)
		
		LabelCustom:GetPropertyChangedSignal("Size"):Connect(function()
		    LabelCustomShadow.Size = LabelCustom.Size
		end)
		
		local OldRight: boolean = TextGUI.Children.AbsolutePosition.X > (GUI.AbsoluteSize.X / 2)
		vape:Clean(TextGUI.Children:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    local IsRight: boolean = TextGUI.Children.AbsolutePosition.X > (GUI.AbsoluteSize.X / 2)
		    if OldRight ~= IsRight then
		        vape:UpdateTextGUI()
		        OldRight = IsRight
		    end
		end))
		
		local function CreateRow(Name: string, IsRight: boolean)
		    local BackgroundFrame, ColorLine
		    local Holder: Frame = Instance.new("Frame")
		    Holder.BackgroundTransparency = 1
		    Holder.ClipsDescendants = true
		    Holder.Name = Name
		    Holder.Size = UDim2.fromOffset()
		    Holder.Parent = LabelHolder
		
		    if Background.Enabled then
		        BackgroundFrame = Instance.new("Frame")
		        BackgroundFrame.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.15)
		        BackgroundFrame.BackgroundTransparency = BackgroundTransparency.Value
		        BackgroundFrame.BorderSizePixel = 0
		        BackgroundFrame.Size = UDim2.new(1, 0, 1, 0)
		        BackgroundFrame.Parent = Holder
		        local Corner: UICorner = Instance.new("UICorner")
		        Corner.Parent = BackgroundFrame
		        local BottomLine: Frame = Instance.new("Frame")
		        BottomLine.BackgroundColor3 = Color3.new()
		        BottomLine.BackgroundTransparency = 0.928 + (0.072 * math.clamp((BackgroundTransparency.Value - 0.5) / 0.5, 0, 1))
		        BottomLine.BorderSizePixel = 0
		        BottomLine.Position = UDim2.new(0, 0, 1, -1)
		        BottomLine.Size = UDim2.new(1, 0, 0, 1)
		        BottomLine.Parent = BackgroundFrame
		        local TopLine: Frame = BottomLine:Clone()
		        TopLine.Position = UDim2.new()
		        TopLine.Name = "Line"
		        TopLine.Parent = BackgroundFrame
		        local ColorHolder: Frame = Instance.new("Frame")
		        ColorHolder.BackgroundTransparency = 1
		        ColorHolder.BorderSizePixel = 0
		        ColorHolder.ClipsDescendants = true
		        ColorHolder.Name = "Color"
		        ColorHolder.Position = IsRight and UDim2.new(1, -4, 0, 0) or UDim2.new()
		        ColorHolder.Size = UDim2.new(0, 4, 1, 0)
		        ColorHolder.Parent = BackgroundFrame
		        ColorLine = Instance.new("ImageLabel")
		        ColorLine.BackgroundTransparency = 1
		        ColorLine.BorderSizePixel = 0
		        ColorLine.Image = GetVapeAsset("kingvape/assets/new/textguiline.png")
		        ColorLine.Position = UDim2.fromOffset(IsRight and -4 or 0, 0)
		        ColorLine.ScaleType = Enum.ScaleType.Slice
		        ColorLine.SliceCenter = Rect.new(0, 4, 8, 5)
		        ColorLine.Size = UDim2.new(0, 8, 1, 0)
		        ColorLine.Parent = ColorHolder
		
		        if ColorLine.Image == "" then
		            ColorHolder.BackgroundTransparency = 0
		            local ColorCorner: UICorner = Instance.new("UICorner")
		            ColorCorner.CornerRadius = UDim.new(0, 2)
		            ColorCorner.Parent = ColorHolder
		        end
		    end
		
		    local Label: TextLabel = Instance.new("TextLabel")
		    Label.BackgroundTransparency = 1
		    Label.BorderSizePixel = 0
		    Label.FontFace = FontOption.Value
		    Label.Position = UDim2.fromOffset(IsRight and 5 or 9, 2)
		    Label.TextSize = 18
		    Label.RichText = true
		
		    local ShadowLabel: TextLabel?
		    if Shadow.Enabled then
		        ShadowLabel = Label:Clone()
		        ShadowLabel.Position = UDim2.fromOffset(Label.Position.X.Offset + 1, Label.Position.Y.Offset + 1)
		        ShadowLabel.TextColor3 = Color3.new()
		        ShadowLabel.Parent = Holder
		    end
		
		    Label.Parent = Holder
		
		    return {Object = Holder, Background = BackgroundFrame, Color = ColorLine, Text = Label, Shadow = ShadowLabel}
		end
		
		function vape:UpdateTextGUI(AfterLoad: boolean?)
		    if not AfterLoad and not vape.Loaded then return end
		    if TextGUI.Button.Enabled then
		        local IsRight: boolean = TextGUI.Children.AbsolutePosition.X > (GUI.AbsoluteSize.X / 2)
		
		        Logo.Visible = Watermark.Enabled
		        Logo.Position = IsRight and UDim2.new(1 / Scale.Scale, -113, 0, 6) or UDim2.fromOffset(0, 6)
		        LogoShadow.Visible = Shadow.Enabled
		        LabelCustom.Text = CustomTextBox.Value
		        LabelCustom.FontFace = Font.new(CustomTextFont.Value.Family, Enum.FontWeight.Bold)
		        LabelCustom.Visible = LabelCustom.Text ~= "" and CustomText.Enabled
		        LabelCustomShadow.Visible = LabelCustom.Visible and Shadow.Enabled
		        ListLayout.HorizontalAlignment = IsRight and Enum.HorizontalAlignment.Right or Enum.HorizontalAlignment.Left
		        if LabelCustom.Visible then
		            local Size: Vector2 = GetFontBounds(LabelCustom.ContentText, LabelCustom.TextSize, LabelCustom.FontFace)
		            LabelCustom.Size = UDim2.fromOffset(Size.X, Size.Y)
		            LabelCustom.Position = UDim2.new(IsRight and 1 / Scale.Scale or 0, IsRight and -Size.X or 0, 0, (Logo.Visible and 36 or 8))
		        end
		
		        LabelHolder.Size = UDim2.fromScale(1 / Scale.Scale, 1)
		        LabelHolder.Position = UDim2.fromOffset(IsRight and 3 or 0, 11 + (Logo.Visible and Logo.Size.Y.Offset or 0) + (LabelCustom.Visible and LabelCustom.Size.Y.Offset + 8 or 0) + (Background.Enabled and 3 or 0))
		
		        local Style: string = `{Background.Enabled}|{BackgroundTransparency.Value}|{Shadow.Enabled}|{IsRight}|{FontOption.Value.Family}|{FontOption.Value.Weight.Name}|{FontOption.Value.Style.Name}`
		        if Style ~= RowStyle then
		            for _, Row: any in Rows do
		                Row.Object:Destroy()
		            end
		            table.clear(Rows)
		            RowStyle = Style
		        end
		
		        local Previous = {}
		        for _, Label: any in Labels do
		            if Label.Enabled then
		                table.insert(Previous, Label.Object.Name)
		            end
		        end
		        table.clear(Labels)
		
		        local Shown: {[string]: boolean} = {}
		        for Name: string, Module: any in vape.Modules do
		            if HideModules.Enabled and table.find(HideModulesList.ListEnabled, Name) then
		                continue
		            end
		
		            if HideRender.Enabled and Module.Category == "Render" then
		                continue
		            end
		
		            if Module.Enabled or table.find(Previous, Name) then
		                Shown[Name] = true
		                local Row = Rows[Name]
		                if not Row then
		                    Row = CreateRow(Name, IsRight)
		                    Rows[Name] = Row
		                end
		
		                local Label: TextLabel = Row.Text
		                local Text: string = `{Name}{Module.ExtraText and ` <font color='#A8A8A8'>{Module.ExtraText()}</font>` or ""}`
		                if Label.Text ~= Text then
		                    Label.Text = Text
		                    local Size: Vector2 = GetFontBounds(Label.ContentText, Label.TextSize, Label.FontFace)
		                    Label.Size = UDim2.fromOffset(Size.X, Size.Y)
		                    if Row.Shadow then
		                        Row.Shadow.Text = Label.ContentText
		                        Row.Shadow.Size = Label.Size
		                    end
		                end
		
		                local Holder: Frame = Row.Object
		                local TweenSize: UDim2 = UDim2.fromOffset(Label.Size.X.Offset + 16, Label.Size.Y.Offset + 6)
		                if Animations.Enabled then
		                    if not table.find(Previous, Name) then
		                        Tween:Tween(Holder, Info, {
		                            Size = TweenSize
		                        })
		                    else
		                        Holder.Size = TweenSize
		                        if not Module.Enabled then
		                            Tween:Tween(Holder, Info, {
		                                Size = UDim2.fromOffset()
		                            })
		                        end
		                    end
		                else
		                    Holder.Size = Module.Enabled and TweenSize or UDim2.fromOffset()
		                end
		
		                table.insert(Labels, {
		                    Background = Row.Background,
		                    Color = Row.Color,
		                    Enabled = Module.Enabled,
		                    Object = Holder,
		                    Text = Label,
		                    Size = Module.Enabled and TweenSize or UDim2.fromOffset()
		                })
		            end
		        end
		
		        for Name: string, Row: any in Rows do
		            if not Shown[Name] then
		                Row.Object:Destroy()
		                Rows[Name] = nil
		            end
		        end
		
		        if Sort.Value == "Alphabetical" then
		            table.sort(Labels, function(A, B)
		                return A.Text.Text < B.Text.Text
		            end)
		        else
		            table.sort(Labels, function(A, B)
		                return A.Text.Size.X.Offset > B.Text.Size.X.Offset
		            end)
		        end
		
		        for i: number, Label: any in Labels do
		            if Label.Color then
		                local Top: number = (not Labels[i - 1] or (Labels[i - 1].Size.X.Offset < Label.Size.X.Offset)) and 4 or 0
		                local Bottom: number = (not Labels[i + 1] or (Labels[i + 1].Size.X.Offset < Label.Size.X.Offset)) and 4 or 0
		                local CapTop: number = i == 1 and 0 or 4
		                local CapBottom: number = i == #Labels and 0 or 4
		
		                Label.Background.Line.Visible = i ~= 1
		                Label.Color.Position = UDim2.fromOffset(IsRight and -4 or 0, -CapTop)
		                Label.Color.Size = UDim2.new(0, 8, 1, CapTop + CapBottom)
		
		                Label.Background.UICorner.TopLeftRadius = UDim.new(0, Top)
		                Label.Background.UICorner.TopRightRadius = UDim.new(0, Top)
		                Label.Background.UICorner.BottomLeftRadius = UDim.new(0, Bottom)
		                Label.Background.UICorner.BottomRightRadius = UDim.new(0, Bottom)
		            end
		
		            Label.Object.LayoutOrder = i
		        end
		    end
		
		    self:UpdateGUI(self.GUIColor.Hue, self.GUIColor.Sat, self.GUIColor.Value, true)
		end
		
		function TextGUI:UpdateColor(Hue: number, Sat: number, Val: number, Default: boolean?)
		    LogoGradient.Color = ColorSequence.new({
		        ColorSequenceKeypoint.new(0, Color3.fromHSV(Hue, Sat, Val)),
		        ColorSequenceKeypoint.new(1, Gradient.Enabled and Color3.fromHSV(vape:Color((Hue - 0.075) % 1)) or Color3.fromHSV(Hue, Sat, Val))
		    })
		    LogoGradient2.Color = Gradient.Enabled and GradientV4.Enabled and LogoGradient.Color or ColorSequence.new({
		        ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		        ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1))
		    })
		    LabelCustom.TextColor3 = CustomTextColor.Enabled and Color3.fromHSV(CustomTextColorSlider.Hue, CustomTextColorSlider.Sat, CustomTextColorSlider.Value) or LogoGradient.Color.Keypoints[2].Value
		
		    local CustomColor: Color3? = ColorMode.Value == "Custom color" and Color3.fromHSV(ColorSlider.Hue, ColorSlider.Sat, ColorSlider.Value) or nil
		    for i: number, Label: any in Labels do
		        Label.Text.TextColor3 = CustomColor or (vape.GUIColor.Rainbow and Color3.fromHSV(vape:Color((Hue - ((Gradient.Enabled and i + 2 or i) * 0.025)) % 1)) or LogoGradient.Color.Keypoints[2].Value)
		
		        if Label.Color then
		            Label.Color.ImageColor3 = Label.Text.TextColor3
		            Label.Color.Parent.BackgroundColor3 = Label.Text.TextColor3
		        end
		
		        if BackgroundTint.Enabled and Label.Background then
		            Label.Background.BackgroundColor3 = Color.Dark(Label.Text.TextColor3, 0.75)
		        end
		    end
		end
	end)
	
	Run(function()
		local TargetInfo = {
		    Targets = setmetatable({}, {__mode = "k"}),
		    Health = 0,
		    MaxHealth = 0,
		    Stats = {},
		    TargetChanged = CreateSignal()
		}
		local TargetInfoOverlay
		local BackgroundTransparency = {
		    Value = 0.5,
		    Object = {Visible = {}}
		}
		local BorderColor
		local BKGColor
		local CustomColor
		local DisplayName
		
		TargetInfoOverlay = vape:CreateOverlay({
		    Name = "Target Info",
		    Icon = GetVapeAsset("kingvape/assets/new/targetinfo.png"),
		    Size = UDim2.fromOffset(14, 14),
		    Position = UDim2.fromOffset(12, 14),
		    CategorySize = 240,
		    Function = function(Callback: boolean)
		        if Callback then
		            TargetInfoOverlay:Clean(RunService.RenderStepped:Connect(function()
		                if vape.ThreadFix then
		                    setthreadidentity(8)
		                end
		
		                TargetInfo:Update()
		            end))
		        end
		    end
		})
		
		local Holder: Frame = Instance.new("Frame")
		Holder.Size = UDim2.fromOffset(240, 89)
		Holder.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.1)
		Holder.BackgroundTransparency = 0.5
		Holder.Parent = TargetInfoOverlay.Children
		TargetInfo.Object = Holder
		AddGlass(Holder)
		AddCorner(Holder)
		local Headshot: ImageLabel = Instance.new("ImageLabel")
		Headshot.Size = UDim2.fromOffset(26, 27)
		Headshot.Position = UDim2.fromOffset(19, 17)
		Headshot.BackgroundColor3 = UIPallet.Main
		Headshot.Image = "rbxthumb://type=AvatarHeadShot&id=1&w=420&h=420"
		Headshot.Parent = Holder
		AddCorner(Headshot)
		local HurtFlash: Frame = Instance.new("Frame")
		HurtFlash.Size = UDim2.fromScale(1, 1)
		HurtFlash.BackgroundTransparency = 1
		HurtFlash.BackgroundColor3 = Color3.new(1, 0, 0)
		HurtFlash.Parent = Headshot
		AddCorner(HurtFlash)
		local HeadshotBlur = AddBlur(Headshot)
		HeadshotBlur.Enabled = false
		local Name: TextLabel = Instance.new("TextLabel")
		Name.Size = UDim2.fromOffset(145, 20)
		Name.Position = UDim2.fromOffset(54, 20)
		Name.BackgroundTransparency = 1
		Name.Text = "Target name"
		Name.TextXAlignment = Enum.TextXAlignment.Left
		Name.TextYAlignment = Enum.TextYAlignment.Top
		Name.TextScaled = true
		Name.TextColor3 = Color.Light(UIPallet.Text, 0.4)
		Name.TextStrokeTransparency = 1
		Name.FontFace = UIPallet.Font
		local NameShadow: TextLabel = Name:Clone()
		NameShadow.Position = UDim2.fromOffset(55, 21)
		NameShadow.TextColor3 = Color3.new()
		NameShadow.TextTransparency = 0.65
		NameShadow.Visible = false
		NameShadow.Parent = Holder
		for _, Property: string in {"Size", "Text", "FontFace"} do
		    Name:GetPropertyChangedSignal(Property):Connect(function()
		        NameShadow[Property] = Name[Property]
		    end)
		end
		Name.Parent = Holder
		local HealthBKG: Frame = Instance.new("Frame")
		HealthBKG.Name = "HealthBKG"
		HealthBKG.Size = UDim2.fromOffset(200, 9)
		HealthBKG.Position = UDim2.fromOffset(20, 56)
		HealthBKG.BackgroundColor3 = UIPallet.Main
		HealthBKG.BorderSizePixel = 0
		HealthBKG.Parent = Holder
		AddCorner(HealthBKG, UDim.new(1, 0))
		local Health: Frame = HealthBKG:Clone()
		Health.Size = UDim2.fromScale(0.8, 1)
		Health.Position = UDim2.new()
		Health.BackgroundColor3 = Color3.fromHSV(1 / 2.5, 0.89, 0.75)
		Health.Parent = HealthBKG
		Health:GetPropertyChangedSignal("Size"):Connect(function()
		    Health.Visible = Health.Size.X.Scale > 0.01
		end)
		local Armor: Frame = Health:Clone()
		Armor.Size = UDim2.new()
		Armor.Position = UDim2.fromScale(1, 0)
		Armor.AnchorPoint = Vector2.new(1, 0)
		Armor.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
		Armor.Visible = false
		Armor.Parent = HealthBKG
		Armor:GetPropertyChangedSignal("Size"):Connect(function()
		    Armor.Visible = Armor.Size.X.Scale > 0.01
		end)
		local HealthBlur = AddBlur(HealthBKG)
		HealthBlur.Enabled = false
		local Stroke: UIStroke = Instance.new("UIStroke")
		Stroke.Enabled = false
		Stroke.Color = Color3.fromHSV(0.44, 1, 1)
		Stroke.Parent = Holder
		
		TargetInfoOverlay:CreateFont({
		    Name = "Font",
		    Default = "Arial",
		    Function = function(FontFace: Font)
		        Name.FontFace = FontFace
		    end
		})
		DisplayName = TargetInfoOverlay:CreateToggle({
		    Name = "Use Displayname",
		    Default = true
		})
		TargetInfoOverlay:CreateToggle({
		    Name = "Render Background",
		    Function = function(Callback: boolean)
		        Holder.BackgroundTransparency = Callback and BackgroundTransparency.Value or 1
		        NameShadow.Visible = not Callback
		        HealthBlur.Enabled = not Callback
		        HeadshotBlur.Enabled = not Callback
		        BackgroundTransparency.Object.Visible = Callback
		    end,
		    Default = true
		})
		BackgroundTransparency = TargetInfoOverlay:CreateSlider({
		    Name = "Transparency",
		    Min = 0,
		    Max = 1,
		    Default = 0.5,
		    Decimal = 10,
		    Function = function(Val: number)
		        Holder.BackgroundTransparency = Val
		    end,
		    Darker = true
		})
		CustomColor = TargetInfoOverlay:CreateToggle({
		    Name = "Custom Color",
		    Function = function(Callback: boolean)
		        BKGColor.Object.Visible = Callback
		        if Callback then
		            Holder.BackgroundColor3 = Color3.fromHSV(BKGColor.Hue, BKGColor.Sat, BKGColor.Value)
		            Headshot.BackgroundColor3 = Color3.fromHSV(BKGColor.Hue, BKGColor.Sat, math.max(BKGColor.Value - 0.1, 0.075))
		            HealthBKG.BackgroundColor3 = Headshot.BackgroundColor3
		        else
		            Holder.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.1)
		            Headshot.BackgroundColor3 = UIPallet.Main
		            HealthBKG.BackgroundColor3 = UIPallet.Main
		        end
		    end
		})
		BKGColor = TargetInfoOverlay:CreateColorSlider({
		    Name = "Color",
		    Function = function(Hue: number, Sat: number, Val: number)
		        if CustomColor.Enabled then
		            Holder.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
		            Headshot.BackgroundColor3 = Color3.fromHSV(Hue, Sat, math.max(Val - 0.1, 0))
		            HealthBKG.BackgroundColor3 = Headshot.BackgroundColor3
		        end
		    end,
		    Darker = true,
		    Visible = false
		})
		TargetInfoOverlay:CreateToggle({
		    Name = "Border",
		    Function = function(Callback: boolean)
		        Stroke.Enabled = Callback
		        BorderColor.Object.Visible = Callback
		    end
		})
		BorderColor = TargetInfoOverlay:CreateColorSlider({
		    Name = "Border Color",
		    Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
		        Stroke.Color = Color3.fromHSV(Hue, Sat, Val)
		        Stroke.Transparency = 1 - Opacity
		    end,
		    Darker = true,
		    Visible = false
		})
		
		function TargetInfo:CreateStat(Properties)
		    local Pill: Frame = Instance.new("Frame")
		    Pill.BackgroundColor3 = VapeColors.Input
		    Pill.Name = Properties.Name
		    Pill.Position = UDim2.fromOffset(176, 8)
		    Pill.Size = UDim2.fromOffset(Properties.Icon and 44 or 28, 20)
		    Pill.Visible = false
		    Pill.Parent = Holder
		    AddCorner(Pill, UDim.new(0, 4))
		    local Label: TextLabel = Instance.new("TextLabel")
		    Label.BackgroundTransparency = 1
		    Label.FontFace = UIPallet.Font
		    Label.Name = "Value"
		    Label.Position = UDim2.fromOffset(Properties.Icon and 20 or 2, 0)
		    Label.Size = UDim2.fromOffset(Properties.Icon and 16 or 18, 20)
		    Label.Text = Properties.Signed and "+0" or "0"
		    Label.TextColor3 = Properties.Tint and Color3.new(1, 1, 1) or VapeColors.Primary
		    Label.TextSize = 14
		    Label.TextTransparency = Properties.Tint and 0.294 or 0
		    Label.TextXAlignment = Enum.TextXAlignment.Right
		    Label.Parent = Pill
		
		    local Stat = {
		        Label = Label,
		        Object = Pill,
		        Signed = Properties.Signed,
		        Tint = Properties.Tint,
		        Value = 0
		    }
		
		    if Properties.Icon then
		        local Icon: ImageLabel = Instance.new("ImageLabel")
		        Icon.AnchorPoint = Vector2.new(0, 0.5)
		        Icon.BackgroundTransparency = 1
		        Icon.Image = Properties.Icon
		        Icon.ImageColor3 = VapeColors.Primary
		        Icon.Name = "Icon"
		        Icon.Position = UDim2.new(0, 6, 0.5, 0)
		        Icon.Size = Properties.IconSize
		        Icon.Parent = Pill
		        Stat.Icon = Icon
		    end
		
		    Stat.Toggle = TargetInfoOverlay:CreateToggle({
		        Name = Properties.Name,
		        Default = Properties.Default,
		        Tooltip = Properties.Tooltip,
		        Function = function()
		            TargetInfo:Layout()
		        end
		    })
		    table.insert(self.Stats, Stat)
		    self:Layout()
		
		    return Stat
		end
		
		function TargetInfo:Layout()
		    local Total: number = 0
		
		    for _, v: any in self.Stats do
		        v.Object.Visible = v.Toggle.Enabled
		        Total += v.Toggle.Enabled and v.Object.Size.X.Offset + 4 or 0
		    end
		
		    local Offset: number = 224 - Total
		    local Shift: number = Total > 0 and 28 or 0
		
		    for _, v: any in self.Stats do
		        if v.Object.Visible then
		            v.Object.Position = UDim2.fromOffset(Offset, 8)
		            Offset += v.Object.Size.X.Offset + 4
		        end
		    end
		
		    Holder.Size = UDim2.fromOffset(240, 89 + Shift)
		    Headshot.Position = UDim2.fromOffset(19, 17 + Shift)
		    Name.Position = UDim2.fromOffset(54, 20 + Shift)
		    NameShadow.Position = UDim2.fromOffset(55, 21 + Shift)
		    HealthBKG.Position = UDim2.fromOffset(20, 56 + Shift)
		end
		
		function TargetInfo:SetStat(Stat, Value: number)
		    local Shade: Color3 = Value > 0 and Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value) or (Value < 0 and VapeColors.Danger or VapeColors.Primary)
		    Stat.Value = Value
		    Stat.Label.Text = Stat.Signed and string.format("%+d", math.clamp(Value, -9, 9)) or tostring(math.abs(Value))
		
		    if Stat.Tint then
		        Stat.Object.BackgroundColor3 = Value ~= 0 and Shade or VapeColors.Input
		        return
		    end
		
		    Stat.Label.TextColor3 = Shade
		    Stat.Icon.ImageColor3 = Shade
		end
		
		function TargetInfo:Update()
		    local Libraries = vape.Libraries
		    if not Libraries then return end
		
		    local Accent: Color3 = Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
		
		    if self.StatColor ~= Accent then
		        self.StatColor = Accent
		
		        for _, v: any in self.Stats do
		            self:SetStat(v, v.Value)
		        end
		    end
		
		    local Cloned = table.clone(self.Targets)
		    for Target: any, Expire: number in Cloned do
		        if Expire < tick() then
		            self.Targets[Target] = nil
		        end
		    end
		    table.clear(Cloned)
		
		    local Entity, Highest = nil, tick()
		    for Target: any, Level: number in self.Targets do
		        if Level > Highest then
		            Entity = Target
		            Highest = Level
		        end
		    end
		
		    Holder.Visible = Entity ~= nil or ClickGUI.Visible
		    if Entity then
		        Name.Text = Entity.Player and (DisplayName.Enabled and Entity.Player.DisplayName or Entity.Player.Name) or Entity.Character and Entity.Character.Name or Name.Text
		        Headshot.Image = `rbxthumb://type=AvatarHeadShot&id={Entity.Player and Entity.Player.UserId or 1}&w=420&h=420`
		
		        if not Entity.Character then
		            Entity.Health = Entity.Health or 0
		            Entity.MaxHealth = Entity.MaxHealth or 100
		        end
		
		        if Entity.Health ~= self.Health or Entity.MaxHealth ~= self.MaxHealth then
		            local Percent: number = math.max(Entity.Health / Entity.MaxHealth, 0)
		
		            Tween:Tween(Health, TweenInfo.new(0.3), {
		                Size = UDim2.fromScale(math.min(Percent, 1), 1), BackgroundColor3 = Color3.fromHSV(math.clamp(Percent / 2.5, 0, 1), 0.89, 0.75)
		            })
		
		            Tween:Tween(Armor, TweenInfo.new(0.3), {
		                Size = UDim2.fromScale(math.clamp(Percent - 1, 0, 0.8), 1)
		            })
		
		            if self.Health > Entity.Health and self.LastTarget == Entity then
		                Tween:Cancel(HurtFlash)
		                HurtFlash.BackgroundTransparency = 0.3
		                Tween:Tween(HurtFlash, TweenInfo.new(0.5), {
		                    BackgroundTransparency = 1
		                })
		            end
		
		            self.Health = Entity.Health
		            self.MaxHealth = Entity.MaxHealth
		        end
		
		        if not Entity.Character then
		            table.clear(Entity)
		        end
		
		        if self.LastTarget ~= Entity then
		            for _, v: any in self.Stats do
		                self:SetStat(v, 0)
		            end
		
		            self.TargetChanged:Fire(Entity)
		        end
		
		        self.LastTarget = Entity
		    end
		end
		
		vape.Libraries.targetinfo = TargetInfo
	end)
	
	vape:Clean(task.spawn(function()
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    local Hue: number = 0
	    repeat
	        for _, Component: any in vape.RainbowSliders do
	            if Component.Type == "GUISlider" then
	                pcall(Component.SetValue, Component, vape:Color(Hue))
	            else
	                pcall(Component.SetValue, Component, Hue)
	            end
	        end
	
	        local Delta: number = task.wait(1 / vape.RainbowUpdateSpeed.Value)
	        Hue = (Hue + (Delta * (0.2 * vape.RainbowSpeed.Value))) % 1
	    until false
	end))
	
	local CursorConnection
	vape:Clean(ClickGUI:GetPropertyChangedSignal("Visible"):Connect(function()
	    vape:UpdateGUI(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value, true)
	
	    if ClickGUI.Visible and UserInputService.MouseEnabled then
	        if CursorConnection then
	            CursorConnection:Disconnect()
	        end
	
	        CursorConnection = RunService.RenderStepped:Connect(function()
	            if vape.ThreadFix then
	                setthreadidentity(8)
	            end
	
	            local IsVisible: boolean = ClickGUI.Visible
	            for _, Window: Frame in vape.Windows do
	                IsVisible = IsVisible or Window.Visible
	            end
	
	            if not IsVisible then
	                Cursor.Visible = false
	                CursorConnection:Disconnect()
	                CursorConnection = nil
	                return
	            end
	
	            Cursor.Visible = not UserInputService.MouseIconEnabled
	            if Cursor.Visible then
	                local MouseLocation: Vector2 = UserInputService:GetMouseLocation()
	                Cursor.Position = UDim2.fromOffset(MouseLocation.X - 31, MouseLocation.Y - 32)
	            end
	        end)
	    end
	end))
	
	vape:Clean(function()
	    if CursorConnection then
	        CursorConnection:Disconnect()
	    end
	end)
	
	vape:Clean(GUI:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    if vape.Scale.Enabled then
	        Scale.Scale = math.max(GUI.AbsoluteSize.X / 1920, UserInputService:GetPlatform() == Enum.Platform.OSX and 1 or 0.4)
	    end
	end))
	
	vape:Clean(Scale:GetPropertyChangedSignal("Scale"):Connect(function()
	    ScaledGUI.Size = UDim2.fromScale(1 / Scale.Scale, 1 / Scale.Scale)
	
	    for _, v: GuiObject in ScaledGUI:QueryDescendants("GuiObject >> [Visible = true]") do
	        v.Visible = false
	        v.Visible = true
	    end
	end))
	
	vape:Clean(vape.GUIBind.Triggered:Connect(function()
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    for _, Window: Frame in self.Windows do
	        Window.Visible = false
	    end
	
	    for _, Module: any in self.Modules do
	        if Module.Bind.Mobile then
	            Module.Bind.Mobile.Visible = ClickGUI.Visible
	        end
	    end
	
	    ClickGUI.Visible = not ClickGUI.Visible
	    vape:BlurCheck()
	end))
	
	vape:Clean(UserInputService.InputBegan:Connect(function(Input: InputObject)
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    if vape.CurrentTooltip and Input.KeyCode == Enum.KeyCode.LeftShift then
	        vape.CurrentTooltip()
	    end
	
	    if not UserInputService:GetFocusedTextBox() and Input.KeyCode ~= Enum.KeyCode.Unknown then
	        table.insert(vape.HeldKeybinds, Input.KeyCode.Name)
	        if vape.Binding then return end
	
	        for _, Bind: any in vape.ActiveBinds do
	            if CheckKeybinds(vape.HeldKeybinds, Bind.Keys, Input.KeyCode.Name) then
	                Bind.Triggered:Fire(true)
	            end
	        end
	    end
	end))
	
	vape:Clean(UserInputService.InputEnded:Connect(function(Input: InputObject)
	    if vape.ThreadFix then
	        setthreadidentity(8)
	    end
	
	    if vape.CurrentTooltip and Input.KeyCode == Enum.KeyCode.LeftShift then
	        vape.CurrentTooltip()
	    end
	
	    if not UserInputService:GetFocusedTextBox() and Input.KeyCode ~= Enum.KeyCode.Unknown then
	        if vape.Binding then
	            if not vape.MultiKeybind.Enabled then
	                vape.HeldKeybinds = {Input.KeyCode.Name}
	            end
	
	            vape.Binding:SetBind(vape.HeldKeybinds, true)
	            vape.Binding = nil
	        else
	            for _, Bind: any in vape.ActiveBinds do
	                if Bind.Hold and CheckKeybinds(vape.HeldKeybinds, Bind.Keys, Input.KeyCode.Name) then
	                    Bind.Triggered:Fire(false)
	                end
	            end
	        end
	    end
	
	    local Index: number? = table.find(vape.HeldKeybinds, Input.KeyCode.Name)
	    if Index then
	        table.remove(vape.HeldKeybinds, Index)
	    end
	end))
end

function vape:Remove(Name: string)
    local Container = (self.Modules[Name] and self.Modules or self.Legit.Modules[Name] and self.Legit.Modules or self.Categories)
    if Container and Container[Name] then
        local Component = Container[Name]
        local IsModule: boolean = Component.Type == "Module"
        if self.ThreadFix then
            setthreadidentity(8)
        end

        if Component.Destroy then
            Component:Destroy()
        end

        for _, Child: string in {"Object", "Children", "Toggle", "Button"} do
            Child = typeof(Component[Child]) == "table" and Component[Child].Object or Component[Child]

            if typeof(Child) == "Instance" then
                Child:ClearAllChildren()
                Child:Destroy()
            end
        end

        LoopClean(Component)
        Container[Name] = nil

        if IsModule then
            self:SortCategories()
        end
    end
end

function vape:Save(NewProfile: string?)
    if not self.Loaded then
        return
    end

    if self.ThreadFix then
        setthreadidentity(8)
    end

    local GuiData = {
        Categories = {},
        Profile = NewProfile or self.Profile,
        v = 1
    }

    local MainData = {
        Modules = {},
        Categories = {},
        Legit = {},
        v = 1
    }

    local Success, Error = pcall(CollectConfig, GuiData, MainData)

    if not Success then
        if not self.SaveFailed then
            self.SaveFailed = true
            self:CreateNotification("Vape", `Failed to save your config, {Error}`, 10, "alert")
        end

        return
    end

    local GuiSuccess, GuiError = WriteJSON(`kingvape/profiles/{game.GameId}.gui.txt`, GuiData)
    local MainSuccess, MainError = WriteJSON(`kingvape/profiles/{self.Profile}{self.Place}.txt`, MainData)

    if GuiSuccess and MainSuccess then
        self.SaveFailed = nil
    elseif not self.SaveFailed then
        self.SaveFailed = true
        self:CreateNotification("Vape", `Failed to save your config, {GuiError or MainError}`, 10, "alert")
    end
end

local function DiffConfig(Current, Defaults)
    local Reference = typeof(Defaults) == "table" and Defaults or nil
    local Out

    for Key: any, v: any in Current do
        local Other = Reference and Reference[Key]

        if typeof(v) == "table" and typeof(Other) == "table" and #v == 0 and #Other == 0 then
            local Inner = DiffConfig(v, Other)

            if Inner then
                Out = Out or {}
                Out[Key] = Inner
            end
        elseif typeof(v) == "table" then
            local Encoded: string = pcall(HttpService.JSONEncode, HttpService, v) and HttpService:JSONEncode(v) or ""

            if Encoded ~= (typeof(Other) == "table" and HttpService:JSONEncode(Other) or "") then
                Out = Out or {}
                Out[Key] = v
            end
        elseif v ~= Other then
            Out = Out or {}
            Out[Key] = v
        end
    end

    return Out
end

local function MergeConfig(Defaults, Patch)
    local Out = {}

    for Key: any, v: any in Defaults do
        Out[Key] = typeof(v) == "table" and MergeConfig(v, nil) or v
    end

    for Key: any, v: any in Patch or {} do
        if typeof(v) == "table" and typeof(Out[Key]) == "table" and #v == 0 and #Out[Key] == 0 then
            Out[Key] = MergeConfig(Out[Key], v)
        else
            Out[Key] = v
        end
    end

    return Out
end

function vape:ExportConfig()
    if not DefaultMain then
        return nil, "your config has not finished loading yet"
    end

    local GuiData = {Categories = {}}
    local MainData = {Modules = {}, Categories = {}, Legit = {}}
    local Success, Error = pcall(CollectConfig, GuiData, MainData)

    if not Success then
        return nil, tostring(Error)
    end

    GuiData.Categories.Profiles = nil

    local Blob = {
        v = 1,
        Place = self.Place,
        Profile = self.Profile,
        Main = DiffConfig(MainData, DefaultMain),
        GUI = GuiData
    }

    local Text
    Success, Text = pcall(HttpService.JSONEncode, HttpService, Blob)

    if not Success then
        return nil, tostring(Text)
    end

    local Packed: string = `CVCF1:{#Text}:{base64encode(lz4compress(Text))}`
    local Verified, RoundTrip = pcall(function()
        return lz4decompress(base64decode(Packed:match("^CVCF1:%d+:(.+)$")), #Text)
    end)

    return (Verified and RoundTrip == Text) and Packed or Text
end

function vape:ImportConfig(Text: string)
    if not DefaultMain then
        return false, "your config has not finished loading yet"
    end

    Text = tostring(Text):gsub("^%s+", ""):gsub("%s+$", "")
    local Size, Body = Text:match("^CVCF1:(%d+):(.+)$")

    if Size then
        local Success, Unpacked = pcall(function()
            return lz4decompress(base64decode(Body), tonumber(Size))
        end)

        if not Success or not Unpacked then
            return false, "that text is not a catvape config"
        end

        Text = Unpacked
    end

    local Success, Blob = pcall(HttpService.JSONDecode, HttpService, Text)
    if not Success or typeof(Blob) ~= "table" or typeof(Blob.Main) ~= "table" then
        return false, "that text is not a catvape config"
    end

    if Blob.Place and Blob.Place ~= self.Place then
        return false, "that config is for a different game"
    end

    local MainData = MergeConfig(DefaultMain, Blob.Main)
    local GuiData = MergeConfig(DefaultGUI, Blob.GUI)
    MainData.v = 1
    GuiData.v = 1
    GuiData.Profile = self.Profile
    GuiData.Categories.Profiles = nil

    local GuiExisting = LoadJSON(`kingvape/profiles/{game.GameId}.gui.txt`)
    if GuiExisting and GuiExisting.Categories then
        GuiData.Categories.Profiles = GuiExisting.Categories.Profiles
    end

    self.Loaded = false
    local MainSuccess: boolean = WriteJSON(`kingvape/profiles/{self.Profile}{self.Place}.txt`, MainData)
    local GuiSuccess: boolean = WriteJSON(`kingvape/profiles/{game.GameId}.gui.txt`, GuiData)

    if not MainSuccess or not GuiSuccess then
        self.Loaded = CanSave
        return false, "your executor could not write the config files"
    end

    self:Load()

    return true, Blob.Profile
end

function vape:QueueSave()
    if not self.Loaded then
        if LoadCalled and DeferredLoads > 0 then
            NeedsSave = true
        end

        return
    end

    self.SaveTime = os.clock() + 2

    if self.SaveQueued then
        return
    end

    self.SaveQueued = true

    local function Flush()
        if vape.ThreadFix then
            setthreadidentity(8)
        end

        local Remaining: number = self.SaveTime - os.clock()
        if Remaining > 0 then
            task.delay(Remaining, Flush)

            return
        end

        self.SaveQueued = nil

        if self.Loaded then
            self:Save()
        end
    end

    task.delay(2, Flush)
end

function vape:SaveOptions(Object)
    local Data = {}
    for _, Component: any in Object.Options do
        if not Component.Save then
            continue
        end

        Component:Save(Data)
    end

    return Data
end

function vape:SortCategories(Immediate: boolean?)
    if not Immediate and not self.Loaded then
        SortQueued = true
        return
    end

    SortQueued = false
    local Sorting = {}
    for _, Module: any in self.Modules do
        Sorting[Module.Category] = Sorting[Module.Category] or {}
        table.insert(Sorting[Module.Category], Module.Name)
    end

    for _, Sort: {string} in Sorting do
        table.sort(Sort, function(A: string, B: string)
            if self.Modules[A].Top ~= self.Modules[B].Top then
                return self.Modules[A].Top
            end
            if self.Modules[A].Paid ~= self.Modules[B].Paid then
                return self.Modules[A].Paid
            end
            return A < B
        end)
        for i: number, Name: string in Sort do
            local Module = self.Modules[Name]
            Module.Index = i

            if Module.Object.LayoutOrder ~= i then
                Module.Object.LayoutOrder = i
                Module.Children.LayoutOrder = i
            end
        end
    end
end

function vape:Uninject()
    self:Save()
    self.Loaded = nil

    for _, Module: any in self.Modules do
        if Module.Enabled then
            Module:Toggle()
        end
    end

    for _, Module: any in self.Legit.Modules do
        if Module.Enabled then
            Module:Toggle()
        end
    end

    for _, Category: any in self.Categories do
        if Category.Type == "Overlay" and Category.Button.Enabled then
            Category.Button:Toggle()
        end
    end

    for _, Connection: RBXScriptConnection in self.Connections do
        pcall(function()
            Connection:Disconnect()
        end)
    end

    if self.ThreadFix then
        setthreadidentity(8)
        ClickGUI.Visible = false
        self:BlurCheck()
    end

    if BlurEffect then
        BlurEffect:Destroy()
        BlurFocus:Destroy()
        BlurEffect = nil
    end

    if GlassConnection then
        GlassConnection:Disconnect()
        GlassConnection = nil
    end

    for _, v: {Frame: GuiObject, Mesh: SpecialMesh, Part: Part} in GlassParts do
        v.Part:Destroy()
    end
    table.clear(GlassParts)

    GUI:ClearAllChildren()
    GUI:Destroy()
    table.clear(self.Connections)
    table.clear(self.Libraries)
    LoopClean(self)

    shared.vape = nil
    shared.vapereload = nil
    shared.VapeIndependent = nil
end

function vape:UpdateGUI(Hue: number, Sat: number, Val: number, Default: boolean?)
    if vape.Loaded == nil then return end
    if not Default and vape.GUIColor.Rainbow then return end

    if TextGUI.Button.Enabled then
        TextGUI:UpdateColor(Hue, Sat, Val, Default)
    end

    if self.PublicProfiles then
        for _, v: GuiObject in self.PublicProfiles.Accents do
            if v:GetAttribute("Accent") ~= false then
                v.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)

                if v:IsA("TextButton") and v.BackgroundTransparency == 0 then
                    v.TextColor3 = self:TextColor(Hue, Sat, Val)
                end
            end
        end
    end

    if not ClickGUI.Visible and not vape.Legit.Window.Visible and not (self.PublicProfiles and self.PublicProfiles.Window.Visible) then return end
    local IsRainbow: boolean? = vape.GUIColor.Rainbow and vape.RainbowMode.Value ~= "Retro"

    for _, Component: any in vape.Categories do
        Component:Color(Hue, Sat, Val, IsRainbow)
    end

    for _, Component: any in vape.Modules do
        Component:Color(Hue, Sat, Val, IsRainbow)
    end

    for _, Component: any in vape.Overlays.Options do
        if Component.Color then
            Component:Color(Hue, Sat, Val, IsRainbow)
        end
    end

    for _, Pane: any in vape.Settings do
        for _, Component: any in Pane.Options do
            if Component.Color then
                Component:Color(Hue, Sat, Val, IsRainbow)
            end
        end
    end

    if vape.Legit.Window.Visible then
        for _, Component: any in vape.Legit.Modules do
            Component:Color(Hue, Sat, Val, IsRainbow)
        end
    end
end

Components = {
	Bind = function(Props, Children, API)
		local Component = {
		    Hold = Props.Hold or false,
		    Keys = {},
		    Triggered = CreateSignal(),
		    Type = "Bind"
		}
		
		local Bind: TextButton = Instance.new("TextButton")
		Bind.AnchorPoint = Vector2.new(1, 0)
		Bind.AutoButtonColor = false
		Bind.BackgroundColor3 = Color3.new(1, 1, 1)
		Bind.BackgroundTransparency = 0.92
		Bind.BorderSizePixel = 0
		Bind.Name = "Bind"
		Bind.Size = UDim2.fromOffset(20, 20)
		Bind.Visible = false
		Bind.Text = ""
		AddCorner(Bind, UDim.new(0, 4))
		AddTooltip(Bind, "", function()
		    local HoldText: string = `Bind functionality = {Component.Hold and "Enable while held" or "Toggle"}`
		    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		        HoldText = `<font color='#FF5A5A'>{HoldText}</font>`
		    end
		
		    return `Click to bind\nShift click to modify bind functionality\n{HoldText}`
		end)
		local Icon: ImageLabel = Instance.new("ImageLabel")
		Icon.BackgroundTransparency = 1
		Icon.Image = GetVapeAsset("kingvape/assets/new/bind.png")
		Icon.ImageColor3 = Color.Dark(UIPallet.Text, 0.43)
		Icon.Name = "Icon"
		Icon.Position = UDim2.new(0.5, -5, 0, 5)
		Icon.Size = UDim2.fromOffset(10, 10)
		Icon.Parent = Bind
		local Label: TextLabel = Instance.new("TextLabel")
		Label.BackgroundTransparency = 1
		Label.FontFace = UIPallet.Font
		Label.Position = UDim2.fromOffset(-1, 0)
		Label.Size = UDim2.fromScale(1, 1)
		Label.Text = ""
		Label.TextColor3 = Color.Dark(UIPallet.Text, 0.43)
		Label.TextSize = 12
		Label.Visible = false
		Label.Parent = Bind
		local Cover: ImageLabel?
		local CoverLabel: TextLabel?
		
		if Props.Module then
		    if Props.Cover then
		        Cover = Instance.new("ImageLabel")
		        Cover.BackgroundTransparency = 1
		        Cover.Image = GetVapeAsset("kingvape/assets/new/bindbkg.png")
		        Cover.Name = "Cover"
		        Cover.ScaleType = Enum.ScaleType.Slice
		        Cover.SliceCenter = Rect.new(0, 0, 141, 40)
		        Cover.Size = UDim2.fromOffset(154, 40)
		        Cover.Visible = false
		        Cover.Parent = API.Object
		        CoverLabel = Instance.new("TextLabel")
		        CoverLabel.BackgroundTransparency = 1
		        CoverLabel.FontFace = UIPallet.Font
		        CoverLabel.Name = "Text"
		        CoverLabel.Size = UDim2.new(1, -10, 1, -3)
		        CoverLabel.Text = "PRESS A KEY TO BIND"
		        CoverLabel.TextColor3 = UIPallet.Text
		        CoverLabel.TextSize = 11
		        CoverLabel.Parent = Cover
		    end
		
		    Bind.Position = UDim2.new(1, -36, 0, 10)
		    Bind.Parent = API.Object
		    Component.Object = Bind
		else
		    local Holder: TextButton = Instance.new("TextButton")
		    Holder.AutoButtonColor = false
		    Holder.BackgroundColor3 = Color.Dark(Children.BackgroundColor3, Props.Darker and 0.02 or 0)
		    Holder.BorderSizePixel = 0
		    Holder.FontFace = UIPallet.Font
		    Holder.Size = UDim2.new(1, 0, 0, 40)
		    Holder.Text = `          {Props.Name}`
		    Holder.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		    Holder.TextSize = 14
		    Holder.TextXAlignment = Enum.TextXAlignment.Left
		    Holder.Visible = Props.Visible == nil or Props.Visible
		    Holder.Parent = Children
		    AddTooltip(Holder, Props.Tooltip)
		    Bind.Position = UDim2.new(1, -10, 0, 10)
		    Bind.Visible = true
		    Bind.Parent = Holder
		    Component.Object = Holder
		end
		
		function Component:CreateMobileButton(Position: Vector2)
		    self:DestroyMobileButton()
		
		    local IsHeld: boolean = false
		    local Button: TextButton = Instance.new("TextButton")
		    Button.AnchorPoint = Vector2.new(0.5, 0.5)
		    Button.BackgroundColor3 = API.Enabled and Color3.new(0, 0.7, 0) or Color3.new()
		    Button.BackgroundTransparency = 0.5
		    Button.Font = Enum.Font.Gotham
		    Button.Position = UDim2.fromOffset(Position.X, Position.Y)
		    Button.Size = UDim2.fromOffset(40, 40)
		    Button.Text = API.Name or "Button"
		    Button.TextColor3 = Color3.new(1, 1, 1)
		    Button.TextScaled = true
		    Button.Parent = GUI
		    local Constraint: UITextSizeConstraint = Instance.new("UITextSizeConstraint")
		    Constraint.MaxTextSize = 16
		    Constraint.Parent = Button
		    AddCorner(Button, UDim.new(1, 0))
		
		    Button.MouseButton1Down:Connect(function()
		        IsHeld = true
		
		        local HoldTime, HoldPosition = os.clock(), UserInputService:GetMouseLocation()
		        repeat
		            IsHeld = (UserInputService:GetMouseLocation() - HoldPosition).Magnitude < 6
		
		            task.wait()
		        until (os.clock() - HoldTime) > 1 or not IsHeld
		
		        if IsHeld then
		            self:DestroyMobileButton()
		        end
		    end)
		
		    Button.MouseButton1Up:Connect(function()
		        IsHeld = false
		    end)
		
		    Button.MouseButton1Click:Connect(function()
		        self.Triggered:Fire(true)
		        Button.BackgroundColor3 = API.Enabled and Color3.new(0, 0.7, 0) or Color3.new()
		    end)
		
		    self.Mobile = Button
		    vape:QueueSave()
		end
		
		function Component:Destroy()
		    Bind:Destroy()
		    Bind:ClearAllChildren()
		
		    if self.Object then
		        self.Object:Destroy()
		        self.Object:ClearAllChildren()
		    end
		
		    if self.Mobile then
		        self.Mobile:Destroy()
		        self.Mobile = nil
		    end
		
		    local Index: number? = table.find(vape.ActiveBinds, self)
		    if Index then
		        table.remove(vape.ActiveBinds, Index)
		    end
		end
		
		function Component:DestroyMobileButton()
		    if self.Mobile then
		        self.Mobile:Destroy()
		        self.Mobile = nil
		        vape:QueueSave()
		    end
		end
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    self.Hold = Data.Hold
		    self:SetBind(Data.Keys)
		
		    if Data.Mobile then
		        self:CreateMobileButton(Vector2.new(Data.Mobile.X, Data.Mobile.Y))
		    end
		end
		
		function Component:Save(Data)
		    Data[Props and Props.Name or "Bind"] = {
		        Keys = self.Keys,
		        Mobile = self.Mobile and {
		            X = self.Mobile.Position.X.Offset,
		            Y = self.Mobile.Position.Y.Offset
		        },
		        Hold = self.Hold
		    }
		end
		
		function Component:SetBind(Keys: {string}, Mouse: boolean?)
		    if Props and Props.NoRemove and #Keys <= 0 then
		        Keys = Props.Default
		    end
		
		    self.Binding = nil
		    self.Keys = table.clone(Keys)
		
		    if Mouse then
		        Icon.Image = GetVapeAsset("kingvape/assets/new/edit.png")
		
		        if Cover then
		            CoverLabel.Text = #Keys <= 0 and "BIND REMOVED" or "BOUND TO"
		            Cover.Size = UDim2.fromOffset(GetFontBounds(CoverLabel.Text, CoverLabel.TextSize, CoverLabel.FontFace).X + 20, 40)
		
		            task.delay(1, function()
		                if vape.ThreadFix then
		                    setthreadidentity(8)
		                end
		
		                Cover.Visible = false
		            end)
		        end
		    end
		
		    if #Keys <= 0 then
		        Label.Visible = false
		        Icon.Visible = true
		        Bind.Size = UDim2.fromOffset(20, 20)
		
		        local Index: number? = table.find(vape.ActiveBinds, Component)
		        if Index then
		            table.remove(vape.ActiveBinds, Index)
		        end
		    else
		        Bind.Visible = true
		        Label.Visible = true
		        Icon.Visible = false
		        Label.Text = table.concat(Keys, " + "):upper()
		        Bind.Size = UDim2.fromOffset(math.max(GetFontBounds(Label.Text, Label.TextSize, Label.FontFace).X + 10, 20), 20)
		
		        if not table.find(vape.ActiveBinds, Component) then
		            table.insert(vape.ActiveBinds, Component)
		        end
		    end
		
		    vape:QueueSave()
		end
		
		function Component:SetColor(NewColor: Color3)
		    Icon.ImageColor3 = NewColor
		    Label.TextColor3 = NewColor
		end
		
		function Component:SetParent(Parent: Instance)
		    Bind.Parent = Parent
		
		    if Cover then
		        Cover.Parent = Parent
		    end
		end
		
		function Component:SetVisible(Visible: boolean)
		    Bind.Visible = #self.Keys > 0 or Visible
		end
		
		Bind.MouseEnter:Connect(function()
		    Label.Visible = false
		    Icon.Visible = not Label.Visible
		    Icon.Image = GetVapeAsset(Component.Binding and "kingvape/assets/new/close.png" or "kingvape/assets/new/edit.png")
		
		    if not Props.Cover or not API.Enabled then
		        Icon.ImageColor3 = Color.Dark(UIPallet.Text, 0.16)
		    end
		end)
		
		Bind.MouseLeave:Connect(function()
		    Label.Visible = #Component.Keys > 0
		    Icon.Visible = not Label.Visible
		    Icon.Image = GetVapeAsset(Component.Binding and "kingvape/assets/new/close.png" or "kingvape/assets/new/bind.png")
		
		    if not Props.Cover or not API.Enabled then
		        Icon.ImageColor3 = Color.Dark(UIPallet.Text, 0.43)
		    end
		end)
		
		Bind.MouseButton1Click:Connect(function()
		    if vape.Binding then
		        if vape.Binding == Component then
		            Component:SetBind({}, true)
		            vape.Binding = nil
		        end
		
		        return
		    end
		
		    if Props.Module and UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		        Component.Hold = not Component.Hold
		        if vape.CurrentTooltip then
		            vape.CurrentTooltip()
		        end
		
		        vape:QueueSave()
		
		        return
		    end
		
		    if Cover then
		        CoverLabel.Text = "PRESS A KEY TO BIND"
		        Cover.Size = UDim2.fromOffset(GetFontBounds(CoverLabel.Text, CoverLabel.TextSize, CoverLabel.FontFace).X + 20, 40)
		        Cover.Visible = true
		    end
		
		    Component.Binding = true
		    Icon.Image = GetVapeAsset("kingvape/assets/new/close.png")
		    vape.Binding = Component
		end)
		
		if Props.Module then
		    API.Bind = Component
		else
		    if Props.Default then
		        Component:SetBind(Props.Default)
		    end
		
		    API.Options[Props.Name] = Component
		end
		
		return Component
	end,
	Button = function(Props, Children, API)
		local Button: TextButton = Instance.new("TextButton")
		Button.AutoButtonColor = false
		Button.BackgroundColor3 = Color.Dark(Children.BackgroundColor3, Props.Darker and 0.02 or 0)
		Button.BorderSizePixel = 0
		Button.Size = UDim2.new(1, 0, 0, 31)
		Button.Text = ""
		Button.Parent = Children
		AddTooltip(Button, Props.Tooltip)
		local Holder: Frame = Instance.new("Frame")
		Holder.BackgroundColor3 = Color.Light(UIPallet.Main, 0.05)
		Holder.Position = UDim2.fromOffset(10, 2)
		Holder.Size = UDim2.fromOffset(200, 27)
		Holder.Parent = Button
		AddCorner(Holder)
		local Title: TextLabel = Instance.new("TextLabel")
		Title.BackgroundColor3 = UIPallet.Main
		Title.FontFace = UIPallet.Font
		Title.Position = UDim2.fromOffset(2, 2)
		Title.Size = UDim2.new(1, -4, 1, -4)
		Title.Text = Props.Name
		Title.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		Title.TextSize = 14
		Title.Parent = Holder
		AddCorner(Title, UDim.new(0, 4))
		Props.Function = Props.Function or function() end
		
		Button.MouseEnter:Connect(function()
		    Tween:Tween(Holder, UIPallet.Tween, {
		        BackgroundColor3 = Color.Light(UIPallet.Main, 0.0875)
		    })
		end)
		
		Button.MouseLeave:Connect(function()
		    Tween:Tween(Holder, UIPallet.Tween, {
		        BackgroundColor3 = Color.Light(UIPallet.Main, 0.05)
		    })
		end)
		
		Button.MouseButton1Click:Connect(Props.Function)
	end,
	Category = function(Props, Children, API)
		local Component = {
		    Expanded = false,
		    Name = Props.Name,
		    Type = "Category"
		}
		
		if Props.NoButton then
		    Component.Standalone = false
		end
		
		local Window: TextButton = Instance.new("TextButton")
		Window.AutoButtonColor = false
		Window.BackgroundColor3 = UIPallet.Main
		Window.Name = `{Props.Name}Category`
		Window.Position = Props.Position or UDim2.fromOffset(236, 60)
		Window.Size = UDim2.fromOffset(220, 41)
		Window.Text = ""
		Window.Visible = false
		Window.Parent = ClickGUI
		AddBlur(Window)
		AddCorner(Window)
		AddDragHandler(Window)
		local Icon: ImageLabel = Instance.new("ImageLabel")
		Icon.BackgroundTransparency = 1
		Icon.Image = Props.Icon
		Icon.ImageColor3 = UIPallet.Text
		Icon.Position = UDim2.fromOffset(12, (Icon.Size.X.Offset > 20 and 14 or 13))
		Icon.Size = Props.Size
		Icon.Parent = Window
		local Title: TextLabel = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.FontFace = UIPallet.Font
		Title.Size = UDim2.new(1, -(Props.Size.X.Offset > 18 and 40 or 33), 0, 41)
		Title.Position = UDim2.fromOffset(math.abs(Title.Size.X.Offset), 0)
		Title.Text = Props.Name
		Title.TextColor3 = UIPallet.Text
		Title.TextSize = 13
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Parent = Window
		local PencilButton: TextButton = Instance.new("TextButton")
		PencilButton.BackgroundTransparency = 1
		PencilButton.Position = UDim2.new(1, -49, 0, 0)
		PencilButton.Size = UDim2.fromOffset(20, 40)
		PencilButton.Text = ""
		PencilButton.Visible = false
		PencilButton.Parent = Window
		AddTooltip(PencilButton, "Edit hidden modules")
		local Pencil: ImageLabel = Instance.new("ImageLabel")
		Pencil.BackgroundTransparency = 1
		Pencil.Image = GetVapeAsset("kingvape/assets/new/editlarge.png")
		Pencil.ImageColor3 = Color3.fromRGB(140, 140, 140)
		Pencil.Size = UDim2.fromOffset(12, 12)
		Pencil.Position = UDim2.fromOffset(4, 14)
		Pencil.Parent = PencilButton
		local HiddenCount: TextLabel = Instance.new("TextLabel")
		HiddenCount.BackgroundTransparency = 1
		HiddenCount.FontFace = UIPallet.Font
		HiddenCount.Name = "HiddenCount"
		HiddenCount.Position = UDim2.new(1, -73, 0, 0)
		HiddenCount.Size = UDim2.fromOffset(24, 41)
		HiddenCount.Text = ""
		HiddenCount.TextColor3 = VapeColors.Secondary
		HiddenCount.TextSize = 13
		HiddenCount.TextXAlignment = Enum.TextXAlignment.Right
		HiddenCount.Visible = false
		HiddenCount.Parent = Window
		local ArrowButton: TextButton = Instance.new("TextButton")
		ArrowButton.BackgroundTransparency = 1
		ArrowButton.Position = UDim2.new(1, -29, 0, 0)
		ArrowButton.Size = UDim2.fromOffset(27, 40)
		ArrowButton.Text = ""
		ArrowButton.Parent = Window
		local Arrow: ImageLabel = Instance.new("ImageLabel")
		Arrow.BackgroundTransparency = 1
		Arrow.Image = GetVapeAsset("kingvape/assets/new/downexpand.png")
		Arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
		Arrow.Size = UDim2.fromOffset(9, 4)
		Arrow.Position = UDim2.fromOffset(9, 18)
		Arrow.Rotation = 180
		Arrow.Parent = ArrowButton
		local Done: TextButton = Instance.new("TextButton")
		Done.BackgroundTransparency = 1
		Done.FontFace = UIPallet.Font
		Done.Position = UDim2.new(1, -73, 0, 0)
		Done.Size = UDim2.fromOffset(42, 40)
		Done.Text = "DONE"
		Done.TextColor3 = Color3.fromRGB(140, 140, 140)
		Done.TextSize = 12
		Done.Visible = false
		Done.Parent = Window
		Component.Done = Done
		local Children: ScrollingFrame = Instance.new("ScrollingFrame")
		Children.BackgroundTransparency = 1
		Children.BorderSizePixel = 0
		Children.CanvasSize = UDim2.new()
		Children.Name = "Children"
		Children.Position = UDim2.fromOffset(0, 37)
		Children.ScrollBarThickness = 2
		Children.ScrollBarImageTransparency = 0.75
		Children.Size = UDim2.new(1, 0, 1, -41)
		Children.Visible = false
		Children.Parent = Window
		local Divider: Frame = Instance.new("Frame")
		Divider.BackgroundColor3 = Color3.new(1, 1, 1)
		Divider.BackgroundTransparency = 0.928
		Divider.BorderSizePixel = 0
		Divider.Position = UDim2.fromOffset(0, 37)
		Divider.Size = UDim2.new(1, 0, 0, 1)
		Divider.Visible = false
		Divider.Parent = Window
		local Stroke: UIStroke = Instance.new("UIStroke")
		Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		Stroke.Color = Color3.fromRGB(85, 85, 85)
		Stroke.Transparency = 0.8
		Stroke.Parent = Window
		local WindowList: UIListLayout = Instance.new("UIListLayout")
		WindowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		WindowList.SortOrder = Enum.SortOrder.LayoutOrder
		WindowList.Parent = Children
		
		function Component:Color(Hue: number, Sat: number, Val: number, IsRainbow: boolean)
		    if self.Paint then
		        self.Paint()
		    end
		end
		
		function Component:Expand()
		    self.Expanded = not self.Expanded
		    Children.Visible = self.Expanded
		    Arrow.Rotation = self.Expanded and 0 or 180
		    Window.Size = UDim2.fromOffset(220, self.Expanded and math.min(41 + WindowList.AbsoluteContentSize.Y / Scale.Scale, 601) or 41)
		    Divider.Visible = Children.CanvasPosition.Y > 10 and Children.Visible
		    vape:QueueSave()
		end
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    if Data.Enabled and self.Button then
		        self.Button:Toggle()
		    end
		
		    if (Data.Expanded or false) ~= self.Expanded then
		        self:Expand()
		    end
		
		    if self.Standalone ~= nil then
		        if Data.Standalone then
		            self:SetStandalone(true)
		        elseif Data.StandaloneSet and self.Standalone then
		            self:SetStandalone(false)
		        end
		    end
		
		    if Data.Position then
		        Window.Position = UDim2.fromOffset(Data.Position.X, Data.Position.Y)
		    end
		end
		
		function Component:MirrorModule(Module)
		    local Row = Module.Object:Clone()
		    Row.LayoutOrder = (Module.FavoriteIndex or 0) * 2
		    Row.Name = Module.Name
		    Row.Parent = Children
		    AddTooltip(Row, Module.Tooltip)
		    local RowBind = Row:FindFirstChild("Bind")
		    local RowIndicators = Row:FindFirstChild("Indicators")
		
		    if RowBind then
		        RowBind:Destroy()
		    end
		
		    if RowIndicators then
		        RowIndicators:Destroy()
		    end
		
		    local RowDots = Row:FindFirstChild("Dots")
		    local RowEdit = Row:FindFirstChild("Edit")
		    local Options = BuildOptionsView(Module, Children, Row.LayoutOrder + 1)
		    local Hovered: boolean = false
		
		    local function Paint()
		        local Lit: boolean = Hovered or Options.Visible
		        Row.BackgroundColor3 = Module.Enabled and Module.Object.BackgroundColor3 or (Lit and Color.Light(UIPallet.Main, 0.02) or UIPallet.Main)
		        Row.TextColor3 = Module.Enabled and Module.Object.TextColor3 or (Lit and UIPallet.Text or Color.Dark(UIPallet.Text, 0.16))
		    end
		
		    local function ToggleOptions()
		        Options.Visible = not Options.Visible
		        Paint()
		    end
		
		    for _, v: string in {"Text", "Visible"} do
		        ListenProperty(Module.Object, Row, v, Row)
		    end
		
		    for _, v: string in {"Color", "Enabled"} do
		        ListenProperty(Module.Object.UIGradient, Row.UIGradient, v, Row)
		    end
		
		    for _, v: string in {"BackgroundColor3", "TextColor3"} do
		        local Connection: RBXScriptConnection = Module.Object:GetPropertyChangedSignal(v):Connect(Paint)
		
		        Row.Destroying:Once(function()
		            Connection:Disconnect()
		        end)
		    end
		
		    if RowDots then
		        ListenProperty(Module.Object.Dots.Dots, RowDots.Dots, "ImageColor3", Row)
		
		        RowDots.MouseButton1Click:Connect(ToggleOptions)
		
		        RowDots.MouseButton2Click:Connect(ToggleOptions)
		    end
		
		    if RowEdit then
		        ListenProperty(Module.Edit, RowEdit, "Visible", Row)
		        ListenProperty(Module.Edit.EditBox, RowEdit.EditBox, "BackgroundTransparency", Row)
		        ListenProperty(Module.Edit.EditBox.UIStroke, RowEdit.EditBox.UIStroke, "Color", Row)
		
		        RowEdit.MouseButton1Click:Connect(function()
		            Module:SetVisible(not Module.Visible)
		        end)
		    end
		
		    Row:GetPropertyChangedSignal("Visible"):Connect(function()
		        if not Row.Visible then
		            Options.Visible = false
		        end
		    end)
		
		    Row.MouseEnter:Connect(function()
		        Hovered = true
		        Paint()
		    end)
		
		    Row.MouseLeave:Connect(function()
		        Hovered = false
		        Paint()
		    end)
		
		    Row.MouseButton1Click:Connect(function()
		        if vape.EditGUI then
		            return
		        end
		
		        Module:Toggle()
		        Paint()
		    end)
		
		    Row.MouseButton2Click:Connect(ToggleOptions)
		
		    Row.Destroying:Once(function()
		        Options:Destroy()
		    end)
		    Paint()
		
		    return Row
		end
		
		function Component:Save(Data)
		    Data[Props.Name] = {
		        Enabled = self.Button and self.Button.Enabled,
		        Expanded = self.Expanded,
		        Position = {
		            X = Window.Position.X.Offset,
		            Y = Window.Position.Y.Offset
		        },
		        Standalone = self.Standalone,
		        StandaloneSet = self.StandaloneSet
		    }
		end
		
		function Component:SetStandalone(State: boolean, ByUser: boolean?)
		    self.Standalone = State
		    self.StandaloneSet = self.StandaloneSet or ByUser
		    Window.Visible = State
		
		    if self.Paint then
		        self.Paint()
		    end
		end
		
		function Component:UpdateHidden()
		    local Count: number = 0
		
		    for _, Module: any in vape.Modules do
		        if Module.Category == Props.Name and not Module.Visible then
		            Count += 1
		        end
		    end
		
		    if Count > 0 then
		        Pencil.Image = GetVapeAsset("kingvape/assets/new/newhide.png")
		        Pencil.Position = UDim2.fromOffset(3, 14)
		        Pencil.Size = UDim2.fromOffset(14, 12)
		    else
		        Pencil.Image = GetVapeAsset("kingvape/assets/new/editlarge.png")
		        Pencil.Position = UDim2.fromOffset(4, 14)
		        Pencil.Size = UDim2.fromOffset(12, 12)
		    end
		
		    HiddenCount.Text = Count > 0 and tostring(Count) or ""
		    HiddenCount.Visible = Count > 0 and PencilButton.Visible
		end
		
		for ComponentName: string, Constructor: (...any) -> ...any in Components do
		    Component[`Create{ComponentName}`] = function(_, Properties)
		        return Constructor(Properties, Children, Component)
		    end
		end
		
		ArrowButton.MouseButton1Click:Connect(function()
		    Component:Expand()
		end)
		
		ArrowButton.MouseButton2Click:Connect(function()
		    Component:Expand()
		end)
		
		ArrowButton.MouseEnter:Connect(function()
		    Arrow.ImageColor3 = Color3.fromRGB(220, 220, 220)
		end)
		
		ArrowButton.MouseLeave:Connect(function()
		    Arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
		end)
		
		Done.MouseButton1Click:Connect(function()
		    vape.EditGUI = false
		    PencilButton.Visible = true
		
		    for _, Category: any in vape.Categories do
		        if Category.Type == "Category" then
		            Category.Done.Visible = false
		            Category:UpdateHidden()
		        end
		    end
		
		    for _, Module: any in vape.Modules do
		        Module.Object.Visible = Module.Visible
		        Module.Object.Text = `{string.rep(" ", 12)}{Module.Name}`
		        Module.Edit.Visible = false
		    end
		end)
		
		Done.MouseEnter:Connect(function()
		    Done.TextColor3 = Color3.fromRGB(220, 220, 220)
		end)
		
		Done.MouseLeave:Connect(function()
		    Done.TextColor3 = Color3.fromRGB(140, 140, 140)
		end)
		
		PencilButton.MouseButton1Click:Connect(function()
		    vape.EditGUI = true
		    PencilButton.Visible = false
		
		    for _, Category: any in vape.Categories do
		        if Category.Type == "Category" then
		            Category.Done.Visible = true
		        end
		    end
		
		    for _, Module: any in vape.Modules do
		        Module.Object.Visible = true
		        Module.Object.Text = `{string.rep(" ", 50)}{Module.Name}`
		        Module.Edit.Visible = true
		    end
		end)
		
		PencilButton.MouseButton2Click:Connect(function()
		    Component:Expand()
		end)
		
		PencilButton.MouseEnter:Connect(function()
		    Pencil.ImageColor3 = Color3.fromRGB(220, 220, 220)
		end)
		
		PencilButton.MouseLeave:Connect(function()
		    Pencil.ImageColor3 = Color3.fromRGB(140, 140, 140)
		end)
		
		Window.MouseEnter:Connect(function()
		    PencilButton.Visible = not vape.EditGUI
		    Component:UpdateHidden()
		end)
		
		Window.MouseLeave:Connect(function()
		    PencilButton.Visible = false
		    HiddenCount.Visible = false
		end)
		
		Window.InputBegan:Connect(function(Input: InputObject)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    if Input.Position.Y < Window.AbsolutePosition.Y + 41 and Input.UserInputType == Enum.UserInputType.MouseButton2 then
		        Component:Expand()
		    end
		end)
		
		Children:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    Divider.Visible = Children.CanvasPosition.Y > 10 and Children.Visible
		end)
		
		WindowList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    Children.CanvasSize = UDim2.fromOffset(0, WindowList.AbsoluteContentSize.Y / Scale.Scale)
		    if Component.Expanded then
		        Window.Size = UDim2.fromOffset(220, math.min(41 + WindowList.AbsoluteContentSize.Y / Scale.Scale, 601))
		    end
		end)
		
		if Props.Expanded then
		    Component:Expand()
		end
		
		if not Props.NoButton then
		    Component.Button = vape.Categories.Main:CreateGUIButton({
		        Name = Props.Name,
		        Icon = Props.Icon,
		        Size = Props.Size,
		        Window = Window
		    })
		end
		
		Component.Object = Window
		vape.Categories[Props.Name] = Component
		
		return Component
	end,
	CategoryList = function(Props, Children, API)
		local Component = {
		    Expanded = false,
		    List = {},
		    ListEnabled = {},
		    Objects = {},
		    Options = {},
		    Type = "CategoryList"
		}
		Props.Color = Props.Color or Color3.fromRGB(5, 134, 105)
		
		local Window: TextButton = Instance.new("TextButton")
		Window.AutoButtonColor = false
		Window.BackgroundColor3 = UIPallet.Main
		Window.Name = `{Props.Name}CategoryList`
		Window.Position = UDim2.fromOffset(240, 46)
		Window.Size = UDim2.fromOffset(220, 45)
		Window.Text = ""
		Window.Visible = false
		Window.Parent = ClickGUI
		AddBlur(Window)
		AddCorner(Window)
		AddDragHandler(Window)
		local Icon: ImageLabel = Instance.new("ImageLabel")
		Icon.BackgroundTransparency = 1
		Icon.Image = Props.Icon
		Icon.ImageColor3 = UIPallet.Text
		Icon.Name = "Icon"
		Icon.Size = Props.Size
		Icon.Position = Props.Position or UDim2.fromOffset(12, (Props.Size.X.Offset > 20 and 13 or 12))
		Icon.Parent = Window
		local Title: TextLabel = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.FontFace = UIPallet.Font
		Title.Name = "Title"
		Title.Size = UDim2.new(1, -(Props.Size.X.Offset > 20 and 44 or 36), 0, 20)
		Title.Position = UDim2.fromOffset(math.abs(Title.Size.X.Offset), 12)
		Title.Text = Props.Name
		Title.TextColor3 = UIPallet.Text
		Title.TextSize = 13
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Parent = Window
		local ArrowButton: TextButton = Instance.new("TextButton")
		ArrowButton.BackgroundTransparency = 1
		ArrowButton.Name = "Arrow"
		ArrowButton.Position = UDim2.new(1, -40, 0, 0)
		ArrowButton.Size = UDim2.fromOffset(40, 40)
		ArrowButton.Text = ""
		ArrowButton.Parent = Window
		local Arrow: ImageLabel = Instance.new("ImageLabel")
		Arrow.Name = "Arrow"
		Arrow.Size = UDim2.fromOffset(9, 4)
		Arrow.Position = UDim2.fromOffset(15, 20)
		Arrow.BackgroundTransparency = 1
		Arrow.Image = GetVapeAsset("kingvape/assets/new/downexpand.png")
		Arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
		Arrow.Rotation = 180
		Arrow.Parent = ArrowButton
		local Children: ScrollingFrame = Instance.new("ScrollingFrame")
		Children.Name = "Children"
		Children.Size = UDim2.new(1, 0, 1, -45)
		Children.Position = UDim2.fromOffset(0, 45)
		Children.BackgroundTransparency = 1
		Children.BorderSizePixel = 0
		Children.Visible = false
		Children.ScrollBarThickness = 2
		Children.ScrollBarImageTransparency = 0.75
		Children.CanvasSize = UDim2.new()
		Children.Parent = Window
		local ChildrenTwo: Frame = Instance.new("Frame")
		ChildrenTwo.BackgroundTransparency = 1
		ChildrenTwo.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.02)
		ChildrenTwo.Visible = false
		ChildrenTwo.Parent = Children
		local Settings: ImageButton = Instance.new("ImageButton")
		Settings.AutoButtonColor = false
		Settings.BackgroundTransparency = 1
		Settings.Image = GetVapeAsset("kingvape/assets/new/settings.png")
		Settings.ImageColor3 = Color.Dark(UIPallet.Text, 0.43)
		Settings.Name = "Settings"
		Settings.Position = UDim2.new(1, -56, 0, 15)
		Settings.Size = UDim2.fromOffset(14, 14)
		Settings.Parent = Window
		local Divider: Frame = Instance.new("Frame")
		Divider.BackgroundColor3 = Color3.new(1, 1, 1)
		Divider.BackgroundTransparency = 0.928
		Divider.BorderSizePixel = 0
		Divider.Name = "Divider"
		Divider.Position = UDim2.fromOffset(0, 41)
		Divider.Size = UDim2.new(1, 0, 0, 1)
		Divider.Visible = false
		Divider.Parent = Window
		local Stroke: UIStroke = Instance.new("UIStroke")
		Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		Stroke.Color = Color3.fromRGB(85, 85, 85)
		Stroke.Transparency = 0.8
		Stroke.Parent = Window
		local WindowList: UIListLayout = Instance.new("UIListLayout")
		WindowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		WindowList.Padding = UDim.new(0, 4)
		WindowList.SortOrder = Enum.SortOrder.LayoutOrder
		WindowList.Parent = Children
		local WindowListTwo: UIListLayout = Instance.new("UIListLayout")
		WindowListTwo.HorizontalAlignment = Enum.HorizontalAlignment.Center
		WindowListTwo.SortOrder = Enum.SortOrder.LayoutOrder
		WindowListTwo.Parent = ChildrenTwo
		local AddBackground: Frame = Instance.new("Frame")
		AddBackground.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		AddBackground.Position = UDim2.fromOffset(10, 45)
		AddBackground.Size = UDim2.fromOffset(200, 31)
		AddBackground.Parent = Children
		AddCorner(AddBackground)
		local AddBox: Frame = AddBackground:Clone()
		AddBox.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.02)
		AddBox.Position = UDim2.fromOffset(1, 1)
		AddBox.Size = UDim2.new(1, -2, 1, -2)
		AddBox.Parent = AddBackground
		local AddValue: TextBox = Instance.new("TextBox")
		AddValue.BackgroundTransparency = 1
		AddValue.ClearTextOnFocus = false
		AddValue.FontFace = UIPallet.Font
		AddValue.PlaceholderText = Props.Placeholder or "Add entry..."
		AddValue.PlaceholderColor3 = Color3.new(0.8, 0.8, 0.8)
		AddValue.Position = UDim2.fromOffset(10, 0)
		AddValue.Size = UDim2.new(1, -35, 1, 0)
		AddValue.Text = ""
		AddValue.TextColor3 = Color3.new(1, 1, 1)
		AddValue.TextSize = 13
		AddValue.TextXAlignment = Enum.TextXAlignment.Left
		AddValue.Parent = AddBackground
		local AddButton: ImageButton = Instance.new("ImageButton")
		AddButton.AnchorPoint = Vector2.new(0, 0.5)
		AddButton.BackgroundTransparency = 1
		AddButton.Image = GetVapeAsset("kingvape/assets/new/add.png")
		AddButton.ImageColor3 = Props.Color
		AddButton.ImageTransparency = 0.3
		AddButton.Name = "AddButton"
		AddButton.Position = UDim2.new(1, -26, 0.5, 0)
		AddButton.Size = UDim2.fromOffset(16, 16)
		AddButton.Parent = AddBackground
		local RowPaints = {}
		
		if Props.Profiles then
		    local AddRow: Frame = Instance.new("Frame")
		    AddRow.BackgroundTransparency = 1
		    AddRow.LayoutOrder = AddBackground.LayoutOrder
		    AddRow.Name = "AddRow"
		    AddRow.Size = UDim2.new(1, -20, 0, 40)
		    AddRow.Parent = Children
		
		    AddBackground.LayoutOrder = AddRow.LayoutOrder + 1
		    AddBackground.Position = UDim2.fromOffset(0, 0)
		    AddBackground.Size = UDim2.fromOffset(200, 31)
		    AddBackground.Visible = false
		    AddValue.Size = UDim2.new(1, -35, 1, 0)
		    AddValue.TextSize = 15
		
		    local function AccentColor()
		        return Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
		    end
		
		    local function AccentTextColor()
		        return vape:TextColor(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
		    end
		
		    local function AddRowButton(Name: string, Asset: string, Text: string, AccentIcon: boolean, Tooltip: string, IconOffset: number)
		        local IconX: number = 16 + (IconOffset * 2)
		        local LabelX: number = IconX + 13
		        local Width: number = GetFontBounds(Text, 11, UIPallet.Font).X
		        local Button: TextButton = Instance.new("TextButton")
		        Button.AutoButtonColor = false
		        Button.BackgroundColor3 = AccentColor()
		        Button.BackgroundTransparency = 1
		        Button.Name = Name
		        Button.Position = UDim2.fromOffset(0, 5)
		        Button.Size = UDim2.fromOffset(Width + 40, 29)
		        Button.Text = ""
		        Button.Parent = AddRow
		        AddCorner(Button, UDim.new(0, 3))
		        AddTooltip(Button, Tooltip)
		        local Stroke: UIStroke = Instance.new("UIStroke")
		        Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		        Stroke.Color = VapeColors.Outline
		        Stroke.Thickness = 1
		        Stroke.Transparency = 0.624
		        Stroke.Parent = Button
		        local Icon: ImageLabel = Instance.new("ImageLabel")
		        Icon.AnchorPoint = Vector2.new(0.5, 0.5)
		        Icon.BackgroundTransparency = 1
		        Icon.Image = GetVapeAsset(Asset)
		        Icon.ImageColor3 = AccentIcon and AccentColor() or VapeColors.Icon
		        Icon.Name = "Icon"
		        Icon.Position = UDim2.new(0, IconX, 0.5, 0)
		        Icon.Size = UDim2.fromOffset(13, 13)
		        Icon.Parent = Button
		        local Label: TextLabel = Instance.new("TextLabel")
		        Label.BackgroundTransparency = 1
		        Label.FontFace = UIPallet.Font
		        Label.Position = UDim2.fromOffset(LabelX, 0)
		        Label.Size = UDim2.new(1, -LabelX, 1, 0)
		        Label.Text = Text
		        Label.TextColor3 = VapeColors.Secondary
		        Label.TextSize = 11
		        Label.TextXAlignment = Enum.TextXAlignment.Left
		        Label.Parent = Button
		
		        local Hovered: boolean = false
		
		        local function Paint(Accent: Color3?, Contrast: Color3?)
		            Accent = Accent or AccentColor()
		            Contrast = Contrast or AccentTextColor()
		            Button.BackgroundColor3 = Accent
		            Label.TextColor3 = Hovered and Contrast or VapeColors.Secondary
		            Icon.ImageColor3 = Hovered and Contrast or (AccentIcon and Accent or VapeColors.Icon)
		        end
		
		        table.insert(RowPaints, Paint)
		
		        Button.MouseEnter:Connect(function()
		            Hovered = true
		            Paint()
		
		            Tween:Tween(Button, UIPallet.Tween, {
		                BackgroundTransparency = 0
		            })
		        end)
		        Button.MouseLeave:Connect(function()
		            Hovered = false
		            Paint()
		
		            Tween:Tween(Button, UIPallet.Tween, {
		                BackgroundTransparency = 1
		            })
		        end)
		
		        return Button
		    end
		
		    local CreateButton: TextButton = AddRowButton("CreateNew", "kingvape/assets/new/add.png", "CREATE NEW", true, "Create a new profile", 2)
		
		    local NewProfile: Frame = Instance.new("Frame")
		    NewProfile.BackgroundColor3 = UIPallet.Main
		    NewProfile.BorderSizePixel = 0
		    NewProfile.Name = "NewProfile"
		    NewProfile.Size = UDim2.new(1, 0, 1, 0)
		    NewProfile.Visible = false
		    NewProfile.ZIndex = 3
		    NewProfile.Parent = Window
		
		    local Back: TextButton = Instance.new("TextButton")
		    Back.AutoButtonColor = true
		    Back.BackgroundColor3 = Color.Light(UIPallet.Main, 0.06)
		    Back.Name = "Back"
		    Back.Position = UDim2.fromOffset(14, 15)
		    Back.Size = UDim2.fromOffset(15, 15)
		    Back.Text = ""
		    Back.ZIndex = 4
		    Back.Parent = NewProfile
		    AddCorner(Back, UDim.new(1, 0))
		    local BackIcon: ImageLabel = Instance.new("ImageLabel")
		    BackIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		    BackIcon.BackgroundTransparency = 1
		    BackIcon.Image = GetVapeAsset("kingvape/assets/new/back.png")
		    BackIcon.ImageColor3 = UIPallet.Text
		    BackIcon.Position = UDim2.fromScale(0.5, 0.5)
		    BackIcon.Size = UDim2.fromScale(1, 1)
		    BackIcon.ZIndex = 5
		    BackIcon.Parent = Back
		
		    local NewTitle: TextLabel = Instance.new("TextLabel")
		    NewTitle.BackgroundTransparency = 1
		    NewTitle.FontFace = UIPallet.Font
		    NewTitle.Position = UDim2.fromOffset(36, 12)
		    NewTitle.Size = UDim2.fromOffset(150, 20)
		    NewTitle.Text = "New Profile"
		    NewTitle.TextColor3 = UIPallet.Text
		    NewTitle.TextSize = 13
		    NewTitle.TextXAlignment = Enum.TextXAlignment.Left
		    NewTitle.ZIndex = 4
		    NewTitle.Parent = NewProfile
		
		    local NewArrowButton: TextButton = Instance.new("TextButton")
		    NewArrowButton.BackgroundTransparency = 1
		    NewArrowButton.Name = "Arrow"
		    NewArrowButton.Position = UDim2.new(1, -40, 0, 0)
		    NewArrowButton.Size = UDim2.fromOffset(40, 40)
		    NewArrowButton.Text = ""
		    NewArrowButton.ZIndex = 4
		    NewArrowButton.Parent = NewProfile
		    local NewArrow: ImageLabel = Instance.new("ImageLabel")
		    NewArrow.BackgroundTransparency = 1
		    NewArrow.Image = GetVapeAsset("kingvape/assets/new/expandup.png")
		    NewArrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
		    NewArrow.Name = "Arrow"
		    NewArrow.Position = UDim2.fromOffset(20, 19)
		    NewArrow.Size = UDim2.fromOffset(9, 4)
		    NewArrow.ZIndex = 5
		    NewArrow.Parent = NewArrowButton
		    local NameBackground: Frame = AddBackground:Clone()
		    NameBackground.Name = "NameBox"
		    NameBackground.Position = UDim2.fromOffset(10, 42)
		    NameBackground.Size = UDim2.new(1, -20, 0, 36)
		    NameBackground.Visible = true
		    NameBackground.ZIndex = 4
		    for _, v: Instance in NameBackground:GetDescendants() do
		        if v:IsA("GuiObject") then v.ZIndex = 5 end
		    end
		    NameBackground.Parent = NewProfile
		    local NameBox = NameBackground:FindFirstChildWhichIsA("TextBox")
		    local NameAdd = NameBackground:FindFirstChild("AddButton")
		    NameAdd.ImageColor3 = AccentColor()
		    table.insert(RowPaints, function(Accent: Color3)
		        NameAdd.ImageColor3 = Accent
		    end)
		
		    local CountLabel: TextLabel = Instance.new("TextLabel")
		    CountLabel.BackgroundTransparency = 1
		    CountLabel.FontFace = UIPallet.FontSemiBold
		    CountLabel.Name = "Count"
		    CountLabel.Position = UDim2.fromOffset(10, 94)
		    CountLabel.RichText = true
		    CountLabel.Size = UDim2.fromOffset(150, 16)
		    CountLabel.Text = ""
		    CountLabel.TextColor3 = VapeColors.Muted
		    CountLabel.TextSize = 12
		    CountLabel.TextXAlignment = Enum.TextXAlignment.Left
		    CountLabel.ZIndex = 4
		    CountLabel.Parent = NewProfile
		
		    local EditAll: TextButton = Instance.new("TextButton")
		    EditAll.AutoButtonColor = false
		    EditAll.BackgroundTransparency = 1
		    EditAll.FontFace = UIPallet.Font
		    EditAll.Name = "EditAll"
		    EditAll.Position = UDim2.new(1, -60, 0, 94)
		    EditAll.Size = UDim2.fromOffset(50, 16)
		    EditAll.Text = "edit all"
		    EditAll.TextColor3 = VapeColors.Secondary
		    EditAll.TextSize = 12
		    EditAll.TextXAlignment = Enum.TextXAlignment.Right
		    EditAll.ZIndex = 4
		    EditAll.Parent = NewProfile
		
		    local ModuleList: ScrollingFrame = Instance.new("ScrollingFrame")
		    ModuleList.BackgroundTransparency = 1
		    ModuleList.BorderSizePixel = 0
		    ModuleList.CanvasSize = UDim2.new()
		    ModuleList.Name = "Modules"
		    ModuleList.Position = UDim2.fromOffset(8, 114)
		    ModuleList.ScrollBarImageTransparency = 1
		    ModuleList.ScrollBarThickness = 0
		    ModuleList.Size = UDim2.new(1, -16, 1, -123)
		    ModuleList.ZIndex = 4
		    ModuleList.Parent = NewProfile
		    local ModuleLayout: UIListLayout = Instance.new("UIListLayout")
		    ModuleLayout.Padding = UDim.new(0, 4)
		    ModuleLayout.SortOrder = Enum.SortOrder.LayoutOrder
		    ModuleLayout.Parent = ModuleList
		    local ModulePadding: UIPadding = Instance.new("UIPadding")
		    ModulePadding.PaddingLeft = UDim.new(0, 2)
		    ModulePadding.PaddingTop = UDim.new(0, 2)
		    ModulePadding.Parent = ModuleList
		
		    local OpenEditor
		
		    local function ListModules(Query: string, AffectedOnly: boolean)
		        local List = {}
		        for Name: string, v: any in vape.Modules do
		            local Rank: number = v.Bind.Keys[1] and 1 or (v.Enabled and 2 or 3)
		            if (Rank < 3 or not AffectedOnly) and (Query == "" or tostring(Name):lower():find(Query, 1, true)) then
		                table.insert(List, {Name = tostring(Name), Module = v, Rank = Rank})
		            end
		        end
		        table.sort(List, function(A, B)
		            if A.Rank ~= B.Rank then
		                return A.Rank < B.Rank
		            end
		
		            return A.Name < B.Name
		        end)
		
		        return List
		    end
		
		    local function AddModuleChip(Row, Text, Width, Offset, Accent)
		        local Chip: Frame = Instance.new("Frame")
		        Chip.AnchorPoint = Vector2.new(1, 0.5)
		        Chip.BackgroundColor3 = Accent and AccentColor() or VapeColors.Outline
		        Chip.BackgroundTransparency = Accent and 0 or 0.5
		        Chip.BorderSizePixel = 0
		        Chip.Name = "Chip"
		        Chip.Position = UDim2.new(1, -Offset, 0.5, 0)
		        Chip.Size = UDim2.fromOffset(Width, 16)
		        Chip.ZIndex = 5
		        Chip.Parent = Row
		        AddCorner(Chip, UDim.new(0, 4))
		        local ChipText: TextLabel = Instance.new("TextLabel")
		        ChipText.BackgroundTransparency = 1
		        ChipText.FontFace = UIPallet.FontBold
		        ChipText.Name = "Text"
		        ChipText.Size = UDim2.fromScale(1, 1)
		        ChipText.Text = Text
		        ChipText.TextColor3 = Accent and AccentTextColor() or VapeColors.Secondary
		        ChipText.TextSize = 10
		        ChipText.ZIndex = 6
		        ChipText.Parent = Chip
		
		        return Chip
		    end
		
		    local RefreshId: number = 0
		
		    local function RefreshModules()
		        if vape.ThreadFix then
		            setthreadidentity(8)
		        end
		
		        RefreshId += 1
		        local Id: number = RefreshId
		        local BuildClock: number = os.clock()
		
		        for _, v: Instance in ModuleList:GetChildren() do
		            if v:IsA("TextButton") then
		                v:Destroy()
		            end
		        end
		
		        local List = ListModules("", false)
		        CountLabel.Text = `<font color="rgb(209,209,209)">{#ListModules("", true)}</font> AFFECTED MODULES`
		
		        for i: number, v: {Name: string, Module: any, Rank: number} in List do
		            if Id ~= RefreshId then return end
		
		            local Bind: string = v.Module.Bind.Keys[1] and tostring(v.Module.Bind.Keys[1]):upper() or ""
		            local Offset: number = 12
		            local Row: TextButton = Instance.new("TextButton")
		            Row.AutoButtonColor = false
		            Row.BackgroundColor3 = VapeColors.Panel
		            Row.BorderSizePixel = 0
		            Row.LayoutOrder = i
		            Row.Name = v.Name
		            Row.Position = UDim2.fromOffset(10, 0)
		            Row.Size = UDim2.new(1, -22, 0, 36)
		            Row.Text = ""
		            Row.ZIndex = 4
		            Row.Parent = ModuleList
		            AddCorner(Row, UDim.new(0, 3))
		            local RowStroke: UIStroke = Instance.new("UIStroke")
		            RowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		            RowStroke.Color = VapeColors.Outline
		            RowStroke.Enabled = false
		            RowStroke.Thickness = 2
		            RowStroke.Transparency = 0.2
		            RowStroke.Parent = Row
		            local Label: TextLabel = Instance.new("TextLabel")
		            Label.BackgroundTransparency = 1
		            Label.FontFace = UIPallet.Font
		            Label.Name = "Label"
		            Label.Position = UDim2.fromOffset(10, 0)
		            Label.Size = UDim2.new(1, -50, 1, 0)
		            Label.Text = v.Name
		            Label.TextColor3 = VapeColors.Primary
		            Label.TextSize = 14
		            Label.TextTruncate = Enum.TextTruncate.AtEnd
		            Label.TextXAlignment = Enum.TextXAlignment.Left
		            Label.ZIndex = 5
		            Label.Parent = Row
		
		            if v.Module.Enabled then
		                AddModuleChip(Row, "ON", 28, Offset, true)
		                Offset += 32
		            end
		
		            if Bind ~= "" then
		                AddModuleChip(Row, Bind, math.max(16, GetFontBounds(Bind, 10, UIPallet.FontBold).X) + 12, Offset, false)
		            end
		
		            Row.MouseEnter:Connect(function()
		                RowStroke.Enabled = true
		            end)
		            Row.MouseLeave:Connect(function()
		                RowStroke.Enabled = false
		            end)
		            Row.MouseButton1Click:Connect(function()
		                OpenEditor(v.Name)
		            end)
		
		            if os.clock() - BuildClock > 0.004 then
		                task.wait()
		                BuildClock = os.clock()
		            end
		        end
		
		        ModuleList.CanvasSize = UDim2.fromOffset(0, (#List * 40) + 4)
		    end
		
		    local Editor: Frame = Instance.new("Frame")
		    Editor.BackgroundColor3 = UIPallet.Main
		    Editor.Name = "ModuleEditor"
		    Editor.Position = UDim2.new(0.5, -336, 0.5, -190)
		    Editor.Size = UDim2.fromOffset(672, 380)
		    Editor.Visible = false
		    Editor.Parent = ScaledGUI
		    AddShadow(Editor)
		    AddCorner(Editor)
		    AddDragHandler(Editor)
		    table.insert(vape.Windows, Editor)
		
		    local EditorSide: Frame = Instance.new("Frame")
		    EditorSide.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		    EditorSide.BorderSizePixel = 0
		    EditorSide.Name = "Sidebar"
		    EditorSide.Size = UDim2.fromOffset(244, 380)
		    EditorSide.Parent = Editor
		    AddCorner(EditorSide)
		    local SideEdge: Frame = Instance.new("Frame")
		    SideEdge.BackgroundColor3 = EditorSide.BackgroundColor3
		    SideEdge.BorderSizePixel = 0
		    SideEdge.Name = "Edge"
		    SideEdge.Position = UDim2.fromOffset(238, 0)
		    SideEdge.Size = UDim2.fromOffset(6, 380)
		    SideEdge.Parent = EditorSide
		
		    local EditorTitle: TextLabel = Instance.new("TextLabel")
		    EditorTitle.BackgroundTransparency = 1
		    EditorTitle.FontFace = UIPallet.FontSemiBold
		    EditorTitle.Name = "Title"
		    EditorTitle.Position = UDim2.fromOffset(24, 21)
		    EditorTitle.Size = UDim2.fromOffset(200, 28)
		    EditorTitle.Text = ""
		    EditorTitle.TextColor3 = Color3.new(1, 1, 1)
		    EditorTitle.TextSize = 19
		    EditorTitle.TextTruncate = Enum.TextTruncate.AtEnd
		    EditorTitle.TextXAlignment = Enum.TextXAlignment.Left
		    EditorTitle.Parent = EditorSide
		
		    local SearchBackground: Frame = Instance.new("Frame")
		    SearchBackground.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.015)
		    SearchBackground.BorderSizePixel = 0
		    SearchBackground.Name = "Search"
		    SearchBackground.Position = UDim2.fromOffset(24, 57)
		    SearchBackground.Size = UDim2.fromOffset(176, 32)
		    SearchBackground.Parent = EditorSide
		    AddCorner(SearchBackground)
		    local SearchStroke: UIStroke = Instance.new("UIStroke")
		    SearchStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		    SearchStroke.Color = Color.Light(UIPallet.Main, 0.06)
		    SearchStroke.Parent = SearchBackground
		    local SearchIcon: ImageLabel = Instance.new("ImageLabel")
		    SearchIcon.BackgroundTransparency = 1
		    SearchIcon.Image = GetVapeAsset("kingvape/assets/new/search.png")
		    SearchIcon.ImageColor3 = Color3.fromRGB(122, 122, 122)
		    SearchIcon.Name = "Icon"
		    SearchIcon.Position = UDim2.fromOffset(12, 9)
		    SearchIcon.Size = UDim2.fromOffset(12, 12)
		    SearchIcon.Parent = SearchBackground
		    local SearchBox: TextBox = Instance.new("TextBox")
		    SearchBox.BackgroundTransparency = 1
		    SearchBox.ClearTextOnFocus = false
		    SearchBox.FontFace = UIPallet.Font
		    SearchBox.PlaceholderColor3 = Color3.fromRGB(122, 122, 122)
		    SearchBox.PlaceholderText = "Search modules..."
		    SearchBox.Position = UDim2.fromOffset(33, 0)
		    SearchBox.Size = UDim2.new(1, -44, 1, 0)
		    SearchBox.Text = ""
		    SearchBox.TextColor3 = UIPallet.Text
		    SearchBox.TextSize = 13
		    SearchBox.TextXAlignment = Enum.TextXAlignment.Left
		    SearchBox.Parent = SearchBackground
		
		    local FilterButton: TextButton = Instance.new("TextButton")
		    FilterButton.AutoButtonColor = false
		    FilterButton.BackgroundColor3 = SearchBackground.BackgroundColor3
		    FilterButton.Name = "Filter"
		    FilterButton.Position = UDim2.fromOffset(204, 57)
		    FilterButton.Size = UDim2.fromOffset(32, 32)
		    FilterButton.Text = ""
		    FilterButton.Parent = EditorSide
		    AddCorner(FilterButton)
		    local FilterStroke: UIStroke = SearchStroke:Clone()
		    FilterStroke.Parent = FilterButton
		    local FilterIcon: Frame = Instance.new("Frame")
		    FilterIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		    FilterIcon.BackgroundTransparency = 1
		    FilterIcon.Name = "Icon"
		    FilterIcon.Position = UDim2.fromScale(0.5, 0.5)
		    FilterIcon.Size = UDim2.fromOffset(12, 10)
		    FilterIcon.Parent = FilterButton
		    local FilterBars: {Frame} = {}
		    for i: number, Width: number in {12, 8, 4} do
		        local Bar: Frame = Instance.new("Frame")
		        Bar.AnchorPoint = Vector2.new(0.5, 0)
		        Bar.BackgroundColor3 = Color3.fromRGB(171, 171, 171)
		        Bar.BorderSizePixel = 0
		        Bar.Name = `Bar{i}`
		        Bar.Position = UDim2.new(0.5, 0, 0, (i - 1) * 4)
		        Bar.Size = UDim2.fromOffset(Width, 2)
		        Bar.Parent = FilterIcon
		        AddCorner(Bar, UDim.new(1, 0))
		        table.insert(FilterBars, Bar)
		    end
		
		    local EditorCount: TextLabel = Instance.new("TextLabel")
		    EditorCount.BackgroundTransparency = 1
		    EditorCount.FontFace = UIPallet.FontBold
		    EditorCount.Name = "Count"
		    EditorCount.Position = UDim2.fromOffset(28, 101)
		    EditorCount.RichText = true
		    EditorCount.Size = UDim2.fromOffset(160, 24)
		    EditorCount.Text = ""
		    EditorCount.TextColor3 = VapeColors.Muted
		    EditorCount.TextSize = 13
		    EditorCount.TextXAlignment = Enum.TextXAlignment.Left
		    EditorCount.Parent = EditorSide
		
		    local ResetAll: TextButton = Instance.new("TextButton")
		    ResetAll.AutoButtonColor = false
		    ResetAll.BackgroundTransparency = 1
		    ResetAll.FontFace = UIPallet.Font
		    ResetAll.Name = "ResetAll"
		    ResetAll.Position = UDim2.fromOffset(158, 101)
		    ResetAll.Size = UDim2.fromOffset(70, 24)
		    ResetAll.Text = "Reset all"
		    ResetAll.TextColor3 = VapeColors.Secondary
		    ResetAll.TextSize = 12
		    ResetAll.TextXAlignment = Enum.TextXAlignment.Right
		    ResetAll.Parent = EditorSide
		
		    local EditorList: ScrollingFrame = Instance.new("ScrollingFrame")
		    EditorList.BackgroundTransparency = 1
		    EditorList.BorderSizePixel = 0
		    EditorList.CanvasSize = UDim2.new()
		    EditorList.Name = "Modules"
		    EditorList.Position = UDim2.fromOffset(24, 129)
		    EditorList.ScrollBarImageTransparency = 1
		    EditorList.ScrollBarThickness = 0
		    EditorList.Size = UDim2.fromOffset(216, 243)
		    EditorList.Parent = EditorSide
		    local EditorLayout: UIListLayout = Instance.new("UIListLayout")
		    EditorLayout.Padding = UDim.new(0, 2)
		    EditorLayout.SortOrder = Enum.SortOrder.LayoutOrder
		    EditorLayout.Parent = EditorList
		    local EditorPadding: UIPadding = Instance.new("UIPadding")
		    EditorPadding.PaddingLeft = UDim.new(0, 2)
		    EditorPadding.PaddingTop = UDim.new(0, 2)
		    EditorPadding.Parent = EditorList
		
		    local ModuleTitle: TextLabel = Instance.new("TextLabel")
		    ModuleTitle.BackgroundTransparency = 1
		    ModuleTitle.FontFace = UIPallet.FontSemiBold
		    ModuleTitle.Name = "ModuleTitle"
		    ModuleTitle.Position = UDim2.fromOffset(260, 28)
		    ModuleTitle.Size = UDim2.fromOffset(260, 26)
		    ModuleTitle.Text = ""
		    ModuleTitle.TextColor3 = Color3.new(1, 1, 1)
		    ModuleTitle.TextSize = 17
		    ModuleTitle.TextTruncate = Enum.TextTruncate.AtEnd
		    ModuleTitle.TextXAlignment = Enum.TextXAlignment.Left
		    ModuleTitle.Parent = Editor
		
		    local function AddChip(Parent: Instance, Name: string, Width: number)
		        local Chip: Frame = Instance.new("Frame")
		        Chip.BackgroundColor3 = Color.Light(UIPallet.Main, 0.09)
		        Chip.BorderSizePixel = 0
		        Chip.Name = Name
		        Chip.Size = UDim2.fromOffset(Width, 17)
		        Chip.Visible = false
		        Chip.Parent = Parent
		        AddCorner(Chip, UDim.new(0, 4))
		        local Text: TextLabel = Instance.new("TextLabel")
		        Text.BackgroundTransparency = 1
		        Text.FontFace = UIPallet.FontSemiBold
		        Text.Name = "Text"
		        Text.Size = UDim2.fromScale(1, 1)
		        Text.Text = ""
		        Text.TextColor3 = Color3.fromRGB(171, 171, 171)
		        Text.TextSize = 10
		        Text.ZIndex = 2
		        Text.Parent = Chip
		        return Chip, Text
		    end
		
		    local function ChipWidth(Text: string)
		        return math.max(GetFontBounds(Text, 10, UIPallet.FontSemiBold).X + 14, 22)
		    end
		
		    local StateChip, StateText = AddChip(Editor, "State", 28)
		    local BindChip, BindText = AddChip(Editor, "Bind", 22)
		
		    local ResetModule: TextButton = Instance.new("TextButton")
		    ResetModule.AutoButtonColor = false
		    ResetModule.BackgroundColor3 = Color.Light(UIPallet.Main, 0.034)
		    ResetModule.FontFace = UIPallet.FontSemiBold
		    ResetModule.Name = "ResetModule"
		    ResetModule.Position = UDim2.fromOffset(540, 28)
		    ResetModule.Size = UDim2.fromOffset(104, 20)
		    ResetModule.Text = "RESET THIS MODULE"
		    ResetModule.TextColor3 = Color3.fromRGB(171, 171, 171)
		    ResetModule.TextSize = 10
		    ResetModule.Visible = false
		    ResetModule.Parent = Editor
		    AddCorner(ResetModule, UDim.new(0, 4))
		
		    local SettingsCaption: TextLabel = Instance.new("TextLabel")
		    SettingsCaption.BackgroundTransparency = 1
		    SettingsCaption.FontFace = UIPallet.FontBold
		    SettingsCaption.Name = "Caption"
		    SettingsCaption.Position = UDim2.fromOffset(260, 56)
		    SettingsCaption.Size = UDim2.fromOffset(200, 14)
		    SettingsCaption.Text = "SETTINGS"
		    SettingsCaption.TextColor3 = VapeColors.Muted
		    SettingsCaption.TextSize = 12
		    SettingsCaption.TextXAlignment = Enum.TextXAlignment.Left
		    SettingsCaption.Visible = false
		    SettingsCaption.Parent = Editor
		
		    local SettingsList: ScrollingFrame = Instance.new("ScrollingFrame")
		    SettingsList.BackgroundTransparency = 1
		    SettingsList.BorderSizePixel = 0
		    SettingsList.CanvasSize = UDim2.new()
		    SettingsList.Name = "Settings"
		    SettingsList.Position = UDim2.fromOffset(260, 70)
		    SettingsList.ScrollBarImageTransparency = 1
		    SettingsList.ScrollBarThickness = 0
		    SettingsList.Size = UDim2.fromOffset(412, 302)
		    SettingsList.Parent = Editor
		    local SettingsLayout: UIListLayout = Instance.new("UIListLayout")
		    SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		    SettingsLayout.Parent = SettingsList
		
		    local EditorClose = AddCloseButton(Editor, false, UDim2.new(1, -35, 0, 8))
		
		    local TargetsScrim: TextButton = Instance.new("TextButton")
		    TargetsScrim.AutoButtonColor = false
		    TargetsScrim.BackgroundColor3 = Color3.new()
		    TargetsScrim.BackgroundTransparency = 0.45
		    TargetsScrim.Name = "TargetsScrim"
		    TargetsScrim.Size = UDim2.fromScale(1, 1)
		    TargetsScrim.Text = ""
		    TargetsScrim.Visible = false
		    TargetsScrim.ZIndex = 8
		    TargetsScrim.Parent = Editor
		    AddCorner(TargetsScrim)
		
		    local TargetsPanel: Frame = Instance.new("Frame")
		    TargetsPanel.BackgroundColor3 = Color.Light(UIPallet.Main, 0.07)
		    TargetsPanel.BorderSizePixel = 0
		    TargetsPanel.Name = "TargetsPanel"
		    TargetsPanel.Size = UDim2.fromOffset(220, 113)
		    TargetsPanel.Visible = false
		    TargetsPanel.ZIndex = 9
		    TargetsPanel.Parent = Editor
		    AddCorner(TargetsPanel, UDim.new(0, 6))
		
		    local function AddResetButton(Row: Instance, Y: number, Callback)
		        local Reset: TextButton = Instance.new("TextButton")
		        Reset.AutoButtonColor = false
		        Reset.BackgroundTransparency = 1
		        Reset.Name = "Reset"
		        Reset.Position = UDim2.fromOffset(368, Y)
		        Reset.Size = UDim2.fromOffset(18, 18)
		        Reset.Text = ""
		        Reset.Parent = Row
		        local Ring: Frame = Instance.new("Frame")
		        Ring.AnchorPoint = Vector2.new(0.5, 0.5)
		        Ring.BackgroundTransparency = 1
		        Ring.Name = "Ring"
		        Ring.Position = UDim2.fromScale(0.5, 0.5)
		        Ring.Size = UDim2.fromOffset(12, 12)
		        Ring.Parent = Reset
		        AddCorner(Ring, UDim.new(1, 0))
		        local RingStroke: UIStroke = Instance.new("UIStroke")
		        RingStroke.Color = Color3.fromRGB(128, 128, 128)
		        RingStroke.Thickness = 1.3
		        RingStroke.Parent = Ring
		        local Gap: Frame = Instance.new("Frame")
		        Gap.BackgroundColor3 = UIPallet.Main
		        Gap.BorderSizePixel = 0
		        Gap.Name = "Gap"
		        Gap.Position = UDim2.fromOffset(6, -2)
		        Gap.Size = UDim2.fromOffset(6, 5)
		        Gap.Parent = Ring
		        local Head: ImageLabel = Instance.new("ImageLabel")
		        Head.BackgroundTransparency = 1
		        Head.Image = GetVapeAsset("kingvape/assets/new/range.png")
		        Head.ImageColor3 = RingStroke.Color
		        Head.Name = "Head"
		        Head.Position = UDim2.fromOffset(7, -1)
		        Head.Rotation = 180
		        Head.Size = UDim2.fromOffset(5, 6)
		        Head.Parent = Ring
		
		        Reset.MouseEnter:Connect(function()
		            RingStroke.Color = Color3.new(1, 1, 1)
		            Head.ImageColor3 = RingStroke.Color
		        end)
		        Reset.MouseLeave:Connect(function()
		            RingStroke.Color = Color3.fromRGB(128, 128, 128)
		            Head.ImageColor3 = RingStroke.Color
		        end)
		        Reset.MouseButton1Click:Connect(Callback)
		
		        return Reset
		    end
		
		    local function AddRowLabel(Row: Instance, Text: string, Size: number, Y: number, Height: number)
		        local Label: TextLabel = Instance.new("TextLabel")
		        Label.BackgroundTransparency = 1
		        Label.FontFace = UIPallet.Font
		        Label.Name = "Label"
		        Label.Position = UDim2.fromOffset(0, Y)
		        Label.Size = UDim2.fromOffset(240, Height)
		        Label.Text = Text
		        Label.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		        Label.TextSize = Size
		        Label.TextTruncate = Enum.TextTruncate.AtEnd
		        Label.TextXAlignment = Enum.TextXAlignment.Left
		        Label.Parent = Row
		        return Label
		    end
		
		    local function AddValueLabel(Row: Instance, Text, Y: number)
		        local Label: TextLabel = Instance.new("TextLabel")
		        Label.BackgroundTransparency = 1
		        Label.FontFace = UIPallet.Font
		        Label.Name = "Value"
		        Label.Position = UDim2.fromOffset(197, Y)
		        Label.Size = UDim2.fromOffset(160, 22)
		        Label.Text = Text
		        Label.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		        Label.TextSize = 12
		        Label.TextXAlignment = Enum.TextXAlignment.Right
		        Label.Parent = Row
		        return Label
		    end
		
		    local function AddTogglePill(Parent: Instance, X: number, Y: number, Enabled: boolean)
		        local Pill: TextButton = Instance.new("TextButton")
		        Pill.AutoButtonColor = false
		        Pill.BackgroundColor3 = Enabled and AccentColor() or Color.Light(UIPallet.Main, 0.14)
		        Pill.Name = "Toggle"
		        Pill.Position = UDim2.fromOffset(X, Y)
		        Pill.Size = UDim2.fromOffset(25, 13)
		        Pill.Text = ""
		        Pill.Parent = Parent
		        AddCorner(Pill, UDim.new(1, 0))
		        local Knob: Frame = Instance.new("Frame")
		        Knob.BackgroundColor3 = Enabled and AccentTextColor() or Color3.new(1, 1, 1)
		        Knob.BorderSizePixel = 0
		        Knob.Name = "Knob"
		        Knob.Position = UDim2.fromOffset(Enabled and 14 or 2, 2)
		        Knob.Size = UDim2.fromOffset(9, 9)
		        Knob.Parent = Pill
		        AddCorner(Knob, UDim.new(1, 0))
		        return Pill, Knob
		    end
		
		    local function TrackRatio(Ratio: number)
		        return math.clamp(Ratio, 0.04, 0.96)
		    end
		
		    local function AddSliderTrack(Row: Instance, Y: number)
		        local Track: Frame = Instance.new("Frame")
		        Track.BackgroundColor3 = Color.Light(UIPallet.Main, 0.09)
		        Track.BorderSizePixel = 0
		        Track.Name = "Track"
		        Track.Position = UDim2.fromOffset(0, Y)
		        Track.Size = UDim2.fromOffset(357, 3)
		        Track.Parent = Row
		        AddCorner(Track, UDim.new(1, 0))
		        local Fill: Frame = Instance.new("Frame")
		        Fill.BackgroundColor3 = AccentColor()
		        Fill.BorderSizePixel = 0
		        Fill.Name = "Fill"
		        Fill.Parent = Track
		        AddCorner(Fill, UDim.new(1, 0))
		        return Track, Fill
		    end
		
		    local function AddDragInput(Row, Track, Callback)
		        Row.InputBegan:Connect(function(Input: InputObject)
		            if vape.ThreadFix then
		                setthreadidentity(8)
		            end
		
		            if
		                (Input.UserInputType ~= Enum.UserInputType.MouseButton1 and Input.UserInputType ~= Enum.UserInputType.Touch)
		                or (Input.Position.Y - Row.AbsolutePosition.Y) < (26 * Scale.Scale)
		            then
		                return
		            end
		
		            Callback(math.clamp((Input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1), true)
		            local MoveConnection: RBXScriptConnection = UserInputService.InputChanged:Connect(function(NewInput: InputObject)
		                if vape.ThreadFix then
		                    setthreadidentity(8)
		                end
		
		                if NewInput.UserInputType == (Input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
		                    Callback(math.clamp((NewInput.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1), false)
		                end
		            end)
		
		            local ReleaseConnection
		            ReleaseConnection = Input.Changed:Connect(function()
		                if Input.UserInputState == Enum.UserInputState.End then
		                    MoveConnection:Disconnect()
		                    ReleaseConnection:Disconnect()
		                    Callback(nil, false, true)
		                end
		            end)
		        end)
		    end
		
		    local function GetOptions(Module)
		        local Order = Module.Children and Module.Children:GetChildren() or {}
		        local List = {}
		        for Name: string, v: any in Module.Options do
		            table.insert(List, {
		                Name = tostring(Name),
		                Option = v,
		                Order = table.find(Order, v.Object) or 1000
		            })
		        end
		        table.sort(List, function(A, B)
		            return A.Order < B.Order
		        end)
		
		        return List
		    end
		
		    local function SameList(List: {any}, Other: {any})
		        if #List ~= #Other then return false end
		        for _, v: any in List do
		            if not table.find(Other, v) then return false end
		        end
		
		        return true
		    end
		
		    local function IsDefault(Option)
		        if Option.Type == "Toggle" then
		            return Option.Enabled == Option.Default
		        elseif Option.Type == "Slider" then
		            return Option.Value == Option.Default
		        elseif Option.Type == "TwoSlider" then
		            return Option.ValueMin == Option.DefaultMin and Option.ValueMax == Option.DefaultMax
		        elseif Option.Type == "Dropdown" or Option.Type == "TextBox" then
		            return Option.Value == Option.Default
		        elseif Option.Type == "TextList" then
		            return SameList(Option.List, Option.Default) and SameList(Option.ListEnabled, Option.Default)
		        elseif Option.Type == "Targets" then
		            return Option.Players.Enabled == Option.Default.Players and Option.NPCs.Enabled == Option.Default.NPCs and Option.Invisible.Enabled == Option.Default.Invisible and Option.Walls.Enabled == Option.Default.Walls and Option.Priority.Value == Option.Default.Priority
		        end
		
		        return true
		    end
		
		    local function ResetOption(Option)
		        if Option.Type == "Toggle" then
		            if Option.Enabled ~= Option.Default then
		                Option:Toggle()
		            end
		        elseif Option.Type == "Slider" then
		            Option:SetValue(Option.Default, nil, true)
		        elseif Option.Type == "TwoSlider" then
		            Option:SetValue(false, Option.DefaultMin)
		            Option:SetValue(true, Option.DefaultMax)
		        elseif Option.Type == "Dropdown" then
		            Option:SetValue(Option.Default, true)
		        elseif Option.Type == "TextBox" then
		            Option:SetValue(Option.Default or "")
		        elseif Option.Type == "TextList" then
		            Option:Load({List = table.clone(Option.Default), ListEnabled = table.clone(Option.Default)})
		        elseif Option.Type == "Targets" then
		            Option:Load(Option.Default)
		        end
		        vape:QueueSave()
		    end
		
		    local SelectedModule
		    local SelectedName
		    local ExpandedOption
		    local RefreshEditor
		    local RefreshSettings
		
		    local function AddToggleRow(Entry, Order: number, ListIcon: string?)
		        local Option = Entry.Option
		        local Row: Frame = Instance.new("Frame")
		        Row.BackgroundTransparency = 1
		        Row.LayoutOrder = Order
		        Row.Name = Entry.Name
		        Row.Size = UDim2.new(1, 0, 0, 30)
		        Row.Parent = SettingsList
		        AddRowLabel(Row, Entry.Name, 13, 0, 30)
		
		        if ListIcon then
		            local Icon: ImageLabel = Instance.new("ImageLabel")
		            Icon.BackgroundTransparency = 1
		            Icon.Image = ListIcon
		            Icon.Name = "ListIcon"
		            Icon.Position = UDim2.fromOffset(315, 9)
		            Icon.Size = UDim2.fromOffset(14, 12)
		            Icon.Parent = Row
		        end
		
		        local Pill, Knob = AddTogglePill(Row, 332, 9, Option.Enabled)
		        if not IsDefault(Option) then
		            AddResetButton(Row, 6, function()
		                ResetOption(Option)
		                RefreshSettings()
		            end)
		        end
		
		        Pill.MouseButton1Click:Connect(function()
		            Option:Toggle()
		            vape:QueueSave()
		
		            Tween:Tween(Pill, UIPallet.Tween, {
		                BackgroundColor3 = Option.Enabled and AccentColor() or Color.Light(UIPallet.Main, 0.14)
		            })
		
		            Tween:Tween(Knob, UIPallet.Tween, {
		                Position = UDim2.fromOffset(Option.Enabled and 14 or 2, 2),
		                BackgroundColor3 = Option.Enabled and AccentTextColor() or Color3.new(1, 1, 1)
		            })
		
		            RefreshSettings()
		        end)
		    end
		
		    local function AddSliderRow(Entry, Order: number)
		        local Option = Entry.Option
		        local Row: TextButton = Instance.new("TextButton")
		        Row.AutoButtonColor = false
		        Row.BackgroundTransparency = 1
		        Row.LayoutOrder = Order
		        Row.Name = Entry.Name
		        Row.Size = UDim2.new(1, 0, 0, 50)
		        Row.Text = ""
		        Row.Parent = SettingsList
		        AddRowLabel(Row, Entry.Name, 12, 4, 22)
		
		        local function FormatValue()
		            local Suffix = type(Option.Suffix) == "function" and Option.Suffix(Option.Value) or Option.Suffix
		            return Suffix and `{Option.Value} {Suffix}` or tostring(Option.Value)
		        end
		
		        local ValueLabel: TextLabel = AddValueLabel(Row, FormatValue(), 4)
		        local Range: number = math.max(Option.Max - Option.Min, 1e-6)
		        local Track, Fill = AddSliderTrack(Row, 36)
		        Fill.Size = UDim2.fromScale(TrackRatio((Option.Value - Option.Min) / Range), 1)
		        local Knob: Frame = Instance.new("Frame")
		        Knob.AnchorPoint = Vector2.new(0.5, 0.5)
		        Knob.BackgroundColor3 = AccentColor()
		        Knob.BorderSizePixel = 0
		        Knob.Name = "Knob"
		        Knob.Position = UDim2.fromScale(1, 0.5)
		        Knob.Size = UDim2.fromOffset(13, 13)
		        Knob.ZIndex = 2
		        Knob.Parent = Fill
		        AddCorner(Knob, UDim.new(1, 0))
		
		        local HadReset: boolean = not IsDefault(Option)
		        if HadReset then
		            AddResetButton(Row, 12, function()
		                ResetOption(Option)
		                RefreshSettings()
		            end)
		        end
		
		        Row.MouseEnter:Connect(function()
		            Tween:Tween(Knob, UIPallet.Tween, {
		                Size = UDim2.fromOffset(15, 15)
		            })
		        end)
		        Row.MouseLeave:Connect(function()
		            Tween:Tween(Knob, UIPallet.Tween, {
		                Size = UDim2.fromOffset(13, 13)
		            })
		        end)
		
		        AddDragInput(Row, Track, function(Ratio: number?, _, Final: boolean?)
		            if Final then
		                Option:SetValue(Option.Value, nil, true)
		                vape:QueueSave()
		                if HadReset == IsDefault(Option) then
		                    RefreshSettings()
		                end
		
		                return
		            end
		            Option:SetValue(math.floor((Option.Min + Range * Ratio) * Option.Decimal) / Option.Decimal, Ratio)
		            ValueLabel.Text = FormatValue()
		
		            Tween:Tween(Fill, UIPallet.Tween, {
		                Size = UDim2.fromScale(TrackRatio(Ratio), 1)
		            })
		        end)
		    end
		
		    local function AddTwoSliderRow(Entry, Order: number)
		        local Option = Entry.Option
		        local Row: TextButton = Instance.new("TextButton")
		        Row.AutoButtonColor = false
		        Row.BackgroundTransparency = 1
		        Row.LayoutOrder = Order
		        Row.Name = Entry.Name
		        Row.Size = UDim2.new(1, 0, 0, 50)
		        Row.Text = ""
		        Row.Parent = SettingsList
		        AddRowLabel(Row, Entry.Name, 12, 4, 22)
		
		        local MaxWidth: number = GetFontBounds(tostring(Option.ValueMax), 12, UIPallet.Font).X
		        local MaxValue: TextLabel = AddValueLabel(Row, Option.ValueMax, 4)
		        local Arrow: ImageLabel = Instance.new("ImageLabel")
		        Arrow.BackgroundTransparency = 1
		        Arrow.Name = "Arrow"
		        Arrow.Position = UDim2.fromOffset(339 - MaxWidth, 12)
		        Arrow.Size = UDim2.fromOffset(12, 6)
		        Arrow.Image = GetVapeAsset("kingvape/assets/new/rangearrow.png")
		        Arrow.ImageColor3 = Color.Light(UIPallet.Main, 0.2)
		        Arrow.Parent = Row
		        local MinValue: TextLabel = AddValueLabel(Row, Option.ValueMin, 4)
		        MinValue.Position = UDim2.fromOffset(161 - MaxWidth, 4)
		
		        local Range: number = math.max(Option.Max - Option.Min, 1e-6)
		        local MinRatio: number = TrackRatio((Option.ValueMin - Option.Min) / Range)
		        local MaxRatio: number = TrackRatio((Option.ValueMax - Option.Min) / Range)
		        local Track, Fill = AddSliderTrack(Row, 36)
		        Fill.Position = UDim2.fromScale(MinRatio, 0)
		        Fill.Size = UDim2.fromScale(math.max(MaxRatio - MinRatio, 0), 1)
		
		        local function AddKnob(Name: string, Edge: number, Flipped: boolean)
		            local Knob: ImageLabel = Instance.new("ImageLabel")
		            Knob.AnchorPoint = Vector2.new(0.5, 0.5)
		            Knob.BackgroundTransparency = 1
		            Knob.Image = GetVapeAsset("kingvape/assets/new/range.png")
		            Knob.ImageColor3 = AccentColor()
		            Knob.Name = Name
		            Knob.Position = UDim2.fromScale(Edge, 0.5)
		            Knob.Rotation = Flipped and 180 or 0
		            Knob.Size = UDim2.fromOffset(9, 16)
		            Knob.ZIndex = 2
		            Knob.Parent = Fill
		
		            Knob.MouseEnter:Connect(function()
		                Tween:Tween(Knob, UIPallet.Tween, {
		                    Size = UDim2.fromOffset(11, 18)
		                })
		            end)
		            Knob.MouseLeave:Connect(function()
		                Tween:Tween(Knob, UIPallet.Tween, {
		                    Size = UDim2.fromOffset(9, 16)
		                })
		            end)
		
		            return Knob
		        end
		
		        AddKnob("KnobMin", 0, false)
		        AddKnob("KnobMax", 1, true)
		
		        local HadReset: boolean = not IsDefault(Option)
		        if HadReset then
		            AddResetButton(Row, 12, function()
		                ResetOption(Option)
		                RefreshSettings()
		            end)
		        end
		
		        local EditingMax: boolean = false
		        AddDragInput(Row, Track, function(Ratio: number?, Began: boolean?, Final: boolean?)
		            if Final then
		                vape:QueueSave()
		                if HadReset == IsDefault(Option) then
		                    RefreshSettings()
		                end
		
		                return
		            end
		            if Began then
		                EditingMax = math.abs(Ratio - MaxRatio) <= math.abs(Ratio - MinRatio)
		            end
		            Option:SetValue(EditingMax, math.floor((Option.Min + Range * Ratio) * Option.Decimal) / Option.Decimal)
		            MinRatio = TrackRatio((Option.ValueMin - Option.Min) / Range)
		            MaxRatio = TrackRatio((Option.ValueMax - Option.Min) / Range)
		            MinValue.Text = Option.ValueMin
		            MaxValue.Text = Option.ValueMax
		
		            Tween:Tween(Fill, UIPallet.Tween, {
		                Position = UDim2.fromScale(MinRatio, 0),
		                Size = UDim2.fromScale(math.max(MaxRatio - MinRatio, 0), 1)
		            })
		        end)
		    end
		
		    local function AddDropdownRow(Entry, Order: number, Expanded: boolean)
		        local Option = Entry.Option
		        local Options: {string} = Option.List or {}
		        local Row: Frame = Instance.new("Frame")
		        Row.BackgroundTransparency = 1
		        Row.LayoutOrder = Order
		        Row.Name = Entry.Name
		        Row.Size = UDim2.new(1, 0, 0, Expanded and 40 + (#Options * 26) or 40)
		        Row.Parent = SettingsList
		
		        local Background: Frame = Instance.new("Frame")
		        Background.BackgroundColor3 = Color.Light(UIPallet.Main, 0.034)
		        Background.BorderSizePixel = 0
		        Background.Name = "BKG"
		        Background.Position = UDim2.fromOffset(0, 4)
		        Background.Size = UDim2.new(0, 357, 1, -9)
		        Background.Parent = Row
		        AddCorner(Background, UDim.new(0, 6))
		        local Button: TextButton = Instance.new("TextButton")
		        Button.AutoButtonColor = false
		        Button.BackgroundColor3 = UIPallet.Main
		        Button.Name = "Dropdown"
		        Button.Position = UDim2.fromOffset(1, 1)
		        Button.Size = UDim2.new(1, -2, 1, -2)
		        Button.Text = ""
		        Button.Parent = Background
		        AddCorner(Button, UDim.new(0, 6))
		        local Title: TextLabel = Instance.new("TextLabel")
		        Title.BackgroundTransparency = 1
		        Title.FontFace = UIPallet.Font
		        Title.Name = "Title"
		        Title.Position = UDim2.fromOffset(14, 0)
		        Title.Size = UDim2.new(1, -44, 0, 29)
		        Title.Text = `{Entry.Name} - {Option.Value}`
		        Title.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		        Title.TextSize = 13
		        Title.TextTruncate = Enum.TextTruncate.AtEnd
		        Title.TextXAlignment = Enum.TextXAlignment.Left
		        Title.Parent = Button
		        local Arrow: ImageLabel = Instance.new("ImageLabel")
		        Arrow.BackgroundTransparency = 1
		        Arrow.Image = GetVapeAsset("kingvape/assets/new/expandright.png")
		        Arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
		        Arrow.Name = "Arrow"
		        Arrow.Position = UDim2.new(1, -17, 0, 11)
		        Arrow.Rotation = Expanded and 270 or 90
		        Arrow.Size = UDim2.fromOffset(4, 8)
		        Arrow.Parent = Button
		
		        Row.MouseEnter:Connect(function()
		            Tween:Tween(Background, UIPallet.Tween, {
		                BackgroundColor3 = Color.Light(UIPallet.Main, 0.0875)
		            })
		        end)
		        Row.MouseLeave:Connect(function()
		            Tween:Tween(Background, UIPallet.Tween, {
		                BackgroundColor3 = Color.Light(UIPallet.Main, 0.034)
		            })
		        end)
		
		        if not IsDefault(Option) then
		            AddResetButton(Row, 11, function()
		                ResetOption(Option)
		                RefreshSettings()
		            end)
		        end
		
		        Button.MouseButton1Click:Connect(function()
		            ExpandedOption = not Expanded and Entry.Name or nil
		            RefreshSettings()
		        end)
		
		        if not Expanded then return end
		
		        for i: number, v: string in Options do
		            local Choice: TextButton = Instance.new("TextButton")
		            Choice.AutoButtonColor = false
		            Choice.BackgroundColor3 = UIPallet.Main
		            Choice.BorderSizePixel = 0
		            Choice.Name = v
		            Choice.Position = UDim2.fromOffset(0, 29 + ((i - 1) * 26))
		            Choice.Size = UDim2.new(1, 0, 0, 26)
		            Choice.Text = ""
		            Choice.Parent = Button
		            local ChoiceText: TextLabel = Instance.new("TextLabel")
		            ChoiceText.BackgroundTransparency = 1
		            ChoiceText.FontFace = UIPallet.Font
		            ChoiceText.Name = "Text"
		            ChoiceText.Position = UDim2.fromOffset(14, 0)
		            ChoiceText.Size = UDim2.new(1, -28, 1, 0)
		            ChoiceText.Text = v
		            ChoiceText.TextColor3 = v == Option.Value and Color3.new(1, 1, 1) or Color.Dark(UIPallet.Text, 0.16)
		            ChoiceText.TextSize = 13
		            ChoiceText.TextTruncate = Enum.TextTruncate.AtEnd
		            ChoiceText.TextXAlignment = Enum.TextXAlignment.Left
		            ChoiceText.Parent = Choice
		
		            Choice.MouseEnter:Connect(function()
		                Tween:Tween(Choice, UIPallet.Tween, {
		                    BackgroundColor3 = Color.Light(UIPallet.Main, 0.04)
		                })
		            end)
		            Choice.MouseLeave:Connect(function()
		                Tween:Tween(Choice, UIPallet.Tween, {
		                    BackgroundColor3 = UIPallet.Main
		                })
		            end)
		            Choice.MouseButton1Click:Connect(function()
		                Option:SetValue(v, true)
		                vape:QueueSave()
		                ExpandedOption = nil
		                RefreshSettings()
		            end)
		        end
		    end
		
		    local function ShowTargets(Option, RowY: number)
		        for _, v: Instance in TargetsPanel:GetChildren() do
		            if not v:IsA("UICorner") then
		                v:Destroy()
		            end
		        end
		
		        local function AddTargetTab(Name: string, Toggle, Asset: string, Size: UDim2, X: number)
		            local Tab: TextButton = Instance.new("TextButton")
		            Tab.AutoButtonColor = false
		            Tab.BackgroundColor3 = Toggle.Enabled and AccentColor() or Color.Light(UIPallet.Main, 0.12)
		            Tab.Name = Name
		            Tab.Position = UDim2.fromOffset(X, 12)
		            Tab.Size = UDim2.fromOffset(61, 28)
		            Tab.Text = ""
		            Tab.ZIndex = 10
		            Tab.Parent = TargetsPanel
		            AddCorner(Tab, UDim.new(0, 5))
		            local Icon: ImageLabel = Instance.new("ImageLabel")
		            Icon.AnchorPoint = Vector2.new(0.5, 0.5)
		            Icon.BackgroundTransparency = 1
		            Icon.Image = GetVapeAsset(Asset)
		            Icon.ImageColor3 = Toggle.Enabled and AccentTextColor() or Color3.fromRGB(171, 171, 171)
		            Icon.Name = "Icon"
		            Icon.Position = UDim2.fromScale(0.5, 0.5)
		            Icon.Size = Size
		            Icon.ZIndex = 11
		            Icon.Parent = Tab
		
		            Tab.MouseButton1Click:Connect(function()
		                Toggle:Toggle()
		                vape:QueueSave()
		                RefreshSettings()
		            end)
		        end
		
		        AddTargetTab("Players", Option.Players, "kingvape/assets/new/targetplayers1.png", UDim2.fromOffset(15, 16), 12)
		        AddTargetTab("NPCs", Option.NPCs, "kingvape/assets/new/targetnpc1.png", UDim2.fromOffset(12, 16), 79)
		
		        local function AddTargetToggle(Name: string, Toggle, Y: number)
		            local Label: TextLabel = Instance.new("TextLabel")
		            Label.BackgroundTransparency = 1
		            Label.FontFace = UIPallet.Font
		            Label.Name = Name
		            Label.Position = UDim2.fromOffset(14, Y)
		            Label.Size = UDim2.new(1, -70, 0, 22)
		            Label.Text = Name
		            Label.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		            Label.TextSize = 13
		            Label.TextXAlignment = Enum.TextXAlignment.Left
		            Label.ZIndex = 10
		            Label.Parent = TargetsPanel
		
		            local Pill, Knob = AddTogglePill(TargetsPanel, 181, Y + 4, Toggle.Enabled)
		            Pill.ZIndex = 10
		            Knob.ZIndex = 11
		            Pill.MouseButton1Click:Connect(function()
		                Toggle:Toggle()
		                vape:QueueSave()
		                RefreshSettings()
		            end)
		        end
		
		        AddTargetToggle("Ignore invisible", Option.Invisible, 52)
		        AddTargetToggle("Ignore behind walls", Option.Walls, 84)
		
		        TargetsPanel.Position = UDim2.fromOffset(332, 134 + RowY - SettingsList.CanvasPosition.Y)
		        TargetsPanel.Visible = true
		        TargetsScrim.Visible = true
		    end
		
		    local function AddTargetsRow(Entry, Order: number, RowY: number, Expanded: boolean)
		        local Option = Entry.Option
		        local Row: Frame = Instance.new("Frame")
		        Row.BackgroundTransparency = 1
		        Row.LayoutOrder = Order
		        Row.Name = Entry.Name
		        Row.Size = UDim2.new(1, 0, 0, 50)
		        Row.Parent = SettingsList
		
		        local Background: Frame = Instance.new("Frame")
		        Background.BackgroundColor3 = Color.Light(UIPallet.Main, 0.06)
		        Background.BorderSizePixel = 0
		        Background.Name = "BKG"
		        Background.Position = UDim2.fromOffset(0, 9)
		        Background.Size = UDim2.fromOffset(357, 32)
		        Background.Parent = Row
		        AddCorner(Background, UDim.new(0, 6))
		        local Inner: Frame = Instance.new("Frame")
		        Inner.BackgroundColor3 = UIPallet.Main
		        Inner.BorderSizePixel = 0
		        Inner.Name = "Inner"
		        Inner.Position = UDim2.fromOffset(1, 1)
		        Inner.Size = UDim2.new(1, -2, 1, -2)
		        Inner.Parent = Background
		        AddCorner(Inner, UDim.new(0, 6))
		
		        local Tag: Frame = Instance.new("Frame")
		        Tag.BackgroundColor3 = Color.Light(UIPallet.Main, 0.055)
		        Tag.BorderSizePixel = 0
		        Tag.Name = "Tag"
		        Tag.Size = UDim2.fromOffset(81, 30)
		        Tag.Parent = Inner
		        AddCorner(Tag, UDim.new(0, 6))
		        local TagIcon: ImageLabel = Instance.new("ImageLabel")
		        TagIcon.BackgroundTransparency = 1
		        TagIcon.Image = GetVapeAsset("kingvape/assets/new/targetstab.png")
		        TagIcon.ImageColor3 = Color3.fromRGB(171, 171, 171)
		        TagIcon.Name = "Icon"
		        TagIcon.Position = UDim2.fromOffset(14, 9)
		        TagIcon.Size = UDim2.fromOffset(15, 12)
		        TagIcon.Parent = Tag
		        local TagText: TextLabel = Instance.new("TextLabel")
		        TagText.BackgroundTransparency = 1
		        TagText.FontFace = UIPallet.Font
		        TagText.Name = "Text"
		        TagText.Position = UDim2.fromOffset(36, 0)
		        TagText.Size = UDim2.new(1, -36, 1, 0)
		        TagText.Text = Entry.Name
		        TagText.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		        TagText.TextSize = 13
		        TagText.TextXAlignment = Enum.TextXAlignment.Left
		        TagText.Parent = Tag
		
		        local Targets: {string} = {}
		        if Option.Players.Enabled then table.insert(Targets, "Players") end
		        if Option.NPCs.Enabled then table.insert(Targets, "NPCs") end
		        local ValueText: TextLabel = Instance.new("TextLabel")
		        ValueText.BackgroundTransparency = 1
		        ValueText.FontFace = UIPallet.Font
		        ValueText.Name = "Value"
		        ValueText.Position = UDim2.fromOffset(95, 0)
		        ValueText.Size = UDim2.new(1, -150, 1, 0)
		        ValueText.Text = #Targets > 0 and table.concat(Targets, ", ") or "None"
		        ValueText.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		        ValueText.TextSize = 13
		        ValueText.TextTruncate = Enum.TextTruncate.AtEnd
		        ValueText.TextXAlignment = Enum.TextXAlignment.Left
		        ValueText.Parent = Inner
		
		        local Edit: TextButton = Instance.new("TextButton")
		        Edit.AutoButtonColor = false
		        Edit.BackgroundTransparency = 1
		        Edit.FontFace = UIPallet.Font
		        Edit.Name = "Edit"
		        Edit.Position = UDim2.new(1, -50, 0, 0)
		        Edit.Size = UDim2.fromOffset(40, 32)
		        Edit.Text = "edit"
		        Edit.TextColor3 = Color3.fromRGB(171, 171, 171)
		        Edit.TextSize = 12
		        Edit.TextXAlignment = Enum.TextXAlignment.Right
		        Edit.Parent = Inner
		
		        if not IsDefault(Option) then
		            AddResetButton(Row, 16, function()
		                ResetOption(Option)
		                RefreshSettings()
		            end)
		        end
		
		        Edit.MouseButton1Click:Connect(function()
		            ExpandedOption = not Expanded and Entry.Name or nil
		            RefreshSettings()
		        end)
		
		        if Expanded then
		            ShowTargets(Option, RowY)
		        end
		    end
		
		    local function AddTextListRow(Entry, Order: number)
		        local Option = Entry.Option
		        local Row: Frame = Instance.new("Frame")
		        Row.BackgroundTransparency = 1
		        Row.LayoutOrder = Order
		        Row.Name = Entry.Name
		        Row.Size = UDim2.new(1, 0, 0, 48)
		        Row.Parent = SettingsList
		
		        local Card: Frame = Instance.new("Frame")
		        Card.BackgroundColor3 = Color.Light(UIPallet.Main, 0.045)
		        Card.BorderSizePixel = 0
		        Card.Name = "Card"
		        Card.Position = UDim2.fromOffset(26, 2)
		        Card.Size = UDim2.fromOffset(331, 40)
		        Card.Parent = Row
		        AddCorner(Card, UDim.new(0, 6))
		        local Icon: ImageLabel = Instance.new("ImageLabel")
		        Icon.BackgroundTransparency = 1
		        Icon.Name = "Icon"
		        Icon.Position = UDim2.fromOffset(14, 14)
		        Icon.Size = UDim2.fromOffset(14, 12)
		        Icon.Image = Option.Icon or GetVapeAsset("kingvape/assets/new/allowedicon.png")
		        Icon.Parent = Card
		        local Title: TextLabel = Instance.new("TextLabel")
		        Title.BackgroundTransparency = 1
		        Title.FontFace = UIPallet.Font
		        Title.Name = "Title"
		        Title.Position = UDim2.fromOffset(38, 6)
		        Title.Size = UDim2.new(1, -80, 0, 16)
		        Title.Text = Entry.Name
		        Title.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		        Title.TextSize = 13
		        Title.TextTruncate = Enum.TextTruncate.AtEnd
		        Title.TextXAlignment = Enum.TextXAlignment.Left
		        Title.Parent = Card
		        local Items: TextLabel = Instance.new("TextLabel")
		        Items.BackgroundTransparency = 1
		        Items.FontFace = UIPallet.Font
		        Items.Name = "Items"
		        Items.Position = UDim2.fromOffset(38, 21)
		        Items.Size = UDim2.new(1, -80, 0, 14)
		        Items.Text = #Option.ListEnabled > 0 and table.concat(Option.ListEnabled, ", ") or "None"
		        Items.TextColor3 = Color.Dark(UIPallet.Text, 0.43)
		        Items.TextSize = 11
		        Items.TextTruncate = Enum.TextTruncate.AtEnd
		        Items.TextXAlignment = Enum.TextXAlignment.Left
		        Items.Parent = Card
		        local Amount: TextLabel = Instance.new("TextLabel")
		        Amount.BackgroundTransparency = 1
		        Amount.FontFace = UIPallet.Font
		        Amount.Name = "Amount"
		        Amount.Size = UDim2.new(1, -20, 1, 0)
		        Amount.Text = #Option.List
		        Amount.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		        Amount.TextSize = 13
		        Amount.TextXAlignment = Enum.TextXAlignment.Right
		        Amount.Parent = Card
		
		        if not IsDefault(Option) then
		            AddResetButton(Row, 13, function()
		                ResetOption(Option)
		                RefreshSettings()
		            end)
		        end
		    end
		
		    local function AddColorRow(Entry, Order: number)
		        local Option = Entry.Option
		        local Row: Frame = Instance.new("Frame")
		        Row.BackgroundTransparency = 1
		        Row.LayoutOrder = Order
		        Row.Name = Entry.Name
		        Row.Size = UDim2.new(1, 0, 0, 30)
		        Row.Parent = SettingsList
		        AddRowLabel(Row, Entry.Name, 13, 0, 30)
		
		        local Swatch: Frame = Instance.new("Frame")
		        Swatch.BackgroundColor3 = Color3.fromHSV(Option.Hue, Option.Sat, Option.Value)
		        Swatch.BorderSizePixel = 0
		        Swatch.Name = "Color"
		        Swatch.Position = UDim2.fromOffset(332, 9)
		        Swatch.Size = UDim2.fromOffset(26, 14)
		        Swatch.Parent = Row
		        AddCorner(Swatch, UDim.new(0, 4))
		    end
		
		    local function AddValueRow(Entry, Order: number, Text: string)
		        local Row: Frame = Instance.new("Frame")
		        Row.BackgroundTransparency = 1
		        Row.LayoutOrder = Order
		        Row.Name = Entry.Name
		        Row.Size = UDim2.new(1, 0, 0, 30)
		        Row.Parent = SettingsList
		        AddRowLabel(Row, Entry.Name, 13, 0, 30)
		        local ValueLabel: TextLabel = AddValueLabel(Row, Text, 4)
		        ValueLabel.TextColor3 = Color.Dark(UIPallet.Text, 0.43)
		    end
		
		    function RefreshSettings()
		        for _, v: Instance in SettingsList:GetChildren() do
		            if not v:IsA("UIListLayout") then
		                v:Destroy()
		            end
		        end
		        TargetsScrim.Visible = false
		        TargetsPanel.Visible = false
		
		        local Module = SelectedModule
		        SettingsCaption.Visible = Module ~= nil
		        ResetModule.Visible = Module ~= nil
		        ModuleTitle.Text = Module and SelectedName or ""
		        StateChip.Visible = Module ~= nil
		        BindChip.Visible = Module ~= nil and Module.Bind.Keys[1] ~= nil
		
		        if not Module then
		            SettingsList.CanvasSize = UDim2.new()
		            return
		        end
		
		        local NameWidth: number = GetFontBounds(SelectedName, 17, UIPallet.FontSemiBold).X
		        StateText.Text = Module.Enabled and "ON" or "OFF"
		        StateChip.BackgroundColor3 = Module.Enabled and AccentColor() or Color.Light(UIPallet.Main, 0.09)
		        StateChip.Position = UDim2.fromOffset(272 + NameWidth, 32)
		        StateChip.Size = UDim2.fromOffset(ChipWidth(StateText.Text), 18)
		        StateText.TextColor3 = Module.Enabled and AccentTextColor() or Color3.fromRGB(171, 171, 171)
		
		        BindText.Text = Module.Bind.Keys[1] and tostring(Module.Bind.Keys[1]):upper() or ""
		        BindChip.Position = UDim2.fromOffset(278 + NameWidth + StateChip.Size.X.Offset, 32)
		        BindChip.Size = UDim2.fromOffset(ChipWidth(BindText.Text), 18)
		
		        local Options = GetOptions(Module)
		        local Y: number = 0
		        for i: number, v: {Name: string, Option: any, Order: number} in Options do
		            local Following = Options[i + 1]
		            local Option = v.Option
		            if Option.Type == "Toggle" then
		                local SubList = Following and Following.Option.Type == "TextList"
		                AddToggleRow(v, i, SubList and (Following.Option.Icon or GetVapeAsset("kingvape/assets/new/allowedicon.png")) or nil)
		                Y += 30
		            elseif Option.Type == "Slider" then
		                AddSliderRow(v, i)
		                Y += 50
		            elseif Option.Type == "TwoSlider" then
		                AddTwoSliderRow(v, i)
		                Y += 50
		            elseif Option.Type == "Dropdown" then
		                local Expanded: boolean = ExpandedOption == v.Name
		                AddDropdownRow(v, i, Expanded)
		                Y += Expanded and 40 + (#(Option.List or {}) * 26) or 40
		            elseif Option.Type == "Targets" then
		                AddTargetsRow(v, i, Y, ExpandedOption == v.Name)
		                Y += 50
		            elseif Option.Type == "TextList" then
		                AddTextListRow(v, i)
		                Y += 48
		            elseif Option.Type == "ColorSlider" then
		                AddColorRow(v, i)
		                Y += 30
		            elseif Option.Type == "TextBox" then
		                AddValueRow(v, i, tostring(Option.Value))
		                Y += 30
		            end
		        end
		
		        SettingsList.CanvasSize = UDim2.fromOffset(0, Y)
		    end
		
		    local function AddEditorRow(Entry, Order: number, Selected: boolean)
		        local Row: TextButton = Instance.new("TextButton")
		        Row.AutoButtonColor = false
		        Row.BackgroundColor3 = Color.Light(UIPallet.Main, 0.06)
		        Row.BackgroundTransparency = Selected and 0 or 1
		        Row.LayoutOrder = Order
		        Row.Name = Entry.Name
		        Row.Size = UDim2.new(1, -4, 0, 34)
		        Row.Text = ""
		        Row.Parent = EditorList
		        AddCorner(Row)
		        local Stroke: UIStroke = Instance.new("UIStroke")
		        Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		        Stroke.Color = Color.Light(UIPallet.Main, 0.13)
		        Stroke.Enabled = Selected
		        Stroke.Parent = Row
		        local Label: TextLabel = Instance.new("TextLabel")
		        Label.BackgroundTransparency = 1
		        Label.FontFace = UIPallet.Font
		        Label.Name = "Label"
		        Label.Position = UDim2.fromOffset(10, 0)
		        Label.Size = UDim2.new(1, -58, 1, 0)
		        Label.Text = Entry.Name
		        Label.TextColor3 = Selected and Color3.new(1, 1, 1) or Color3.fromRGB(171, 171, 171)
		        Label.TextSize = 13
		        Label.TextTruncate = Enum.TextTruncate.AtEnd
		        Label.TextXAlignment = Enum.TextXAlignment.Left
		        Label.Parent = Row
		        local Chevron: ImageLabel = Instance.new("ImageLabel")
		        Chevron.AnchorPoint = Vector2.new(1, 0.5)
		        Chevron.BackgroundTransparency = 1
		        Chevron.Image = GetVapeAsset("kingvape/assets/new/expandright.png")
		        Chevron.ImageColor3 = Color3.fromRGB(122, 122, 122)
		        Chevron.Name = "Chevron"
		        Chevron.Position = UDim2.new(1, -12, 0.5, 0)
		        Chevron.Size = UDim2.fromOffset(5, 9)
		        Chevron.Parent = Row
		
		        local BindName: string = Entry.Module.Bind.Keys[1] and tostring(Entry.Module.Bind.Keys[1]):upper() or ""
		        if Entry.Module.Enabled or BindName ~= "" then
		            local Chip, ChipText = AddChip(Row, "Chip", 22)
		            ChipText.Text = Entry.Module.Enabled and "ON" or BindName
		            Chip.AnchorPoint = Vector2.new(1, 0.5)
		            Chip.Position = UDim2.new(1, -28, 0.5, 0)
		            Chip.Size = UDim2.fromOffset(ChipWidth(ChipText.Text), 18)
		            Chip.Visible = true
		            if Entry.Module.Enabled then
		                Chip.BackgroundColor3 = AccentColor()
		                ChipText.TextColor3 = AccentTextColor()
		            end
		        end
		
		        Row.MouseEnter:Connect(function()
		            if not Selected then
		                Tween:Tween(Row, UIPallet.Tween, {
		                    BackgroundTransparency = 0.55
		                })
		            end
		        end)
		        Row.MouseLeave:Connect(function()
		            if not Selected then
		                Tween:Tween(Row, UIPallet.Tween, {
		                    BackgroundTransparency = 1
		                })
		            end
		        end)
		        Row.MouseButton1Click:Connect(function()
		            SelectedName = Entry.Name
		            SelectedModule = Entry.Module
		            ExpandedOption = nil
		            RefreshEditor()
		        end)
		    end
		
		    local AffectedOnly: boolean = false
		
		    local function GetModules()
		        return ListModules(SearchBox.Text:lower(), AffectedOnly)
		    end
		
		    function RefreshEditor()
		        for _, v: Instance in EditorList:GetChildren() do
		            if v:IsA("TextButton") then
		                v:Destroy()
		            end
		        end
		
		        local Active = GetModules()
		        EditorCount.Text = `<font color="rgb(209,209,209)">{#ListModules("", true)}</font> AFFECTED MODULES`
		
		        if SelectedName and not vape.Modules[SelectedName] then
		            SelectedName = nil
		            SelectedModule = nil
		        end
		
		        for i: number, v: {Name: string, Module: any, Rank: number} in Active do
		            AddEditorRow(v, i, v.Name == SelectedName)
		        end
		
		        EditorList.CanvasSize = UDim2.fromOffset(0, (#Active * 36) + 4)
		        RefreshSettings()
		    end
		
		    function OpenEditor(Target)
		        EditorTitle.Text = vape.Profile or "Profile"
		        SearchBox.Text = ""
		        ExpandedOption = nil
		
		        local Active = GetModules()
		        SelectedName = typeof(Target) == "string" and Target or (Active[1] and Active[1].Name)
		        SelectedModule = SelectedName and vape.Modules[SelectedName]
		
		        RefreshEditor()
		        Editor.Position = UDim2.new(0.5, -336, 0.5, -190)
		        Editor.Visible = true
		    end
		
		    SearchBox:GetPropertyChangedSignal("Text"):Connect(RefreshEditor)
		
		    TargetsScrim.MouseButton1Click:Connect(function()
		        ExpandedOption = nil
		        RefreshSettings()
		    end)
		
		    FilterButton.MouseButton1Click:Connect(function()
		        AffectedOnly = not AffectedOnly
		        for _, v: Frame in FilterBars do
		            v.BackgroundColor3 = AffectedOnly and AccentColor() or Color3.fromRGB(171, 171, 171)
		        end
		        RefreshEditor()
		    end)
		
		    ResetModule.MouseEnter:Connect(function()
		        Tween:Tween(ResetModule, UIPallet.Tween, {
		            BackgroundColor3 = Color.Light(UIPallet.Main, 0.075)
		        })
		    end)
		    ResetModule.MouseLeave:Connect(function()
		        Tween:Tween(ResetModule, UIPallet.Tween, {
		            BackgroundColor3 = Color.Light(UIPallet.Main, 0.034)
		        })
		    end)
		    ResetModule.MouseButton1Click:Connect(function()
		        if SelectedModule then
		            for _, v: {Name: string, Option: any, Order: number} in GetOptions(SelectedModule) do
		                ResetOption(v.Option)
		            end
		            ExpandedOption = nil
		            RefreshSettings()
		        end
		    end)
		
		    ResetAll.MouseEnter:Connect(function()
		        ResetAll.TextColor3 = Color3.new(1, 1, 1)
		    end)
		    ResetAll.MouseLeave:Connect(function()
		        ResetAll.TextColor3 = Color3.fromRGB(171, 171, 171)
		    end)
		    ResetAll.MouseButton1Click:Connect(function()
		        for _, v: {Name: string, Module: any, Rank: number} in ListModules("", true) do
		            for _, Entry: {Name: string, Option: any, Order: number} in GetOptions(v.Module) do
		                ResetOption(Entry.Option)
		            end
		        end
		        ExpandedOption = nil
		        RefreshEditor()
		    end)
		
		    EditAll.MouseButton1Click:Connect(function()
		        OpenEditor()
		    end)
		    EditorClose.MouseButton1Click:Connect(function()
		        Editor.Visible = false
		    end)
		
		    CreateButton.MouseButton1Click:Connect(function()
		        RefreshModules()
		        NameBox.Text = ""
		        NewProfile.Visible = true
		        NameBox:CaptureFocus()
		    end)
		
		    Back.MouseButton1Click:Connect(function()
		        NewProfile.Visible = false
		    end)
		
		    NameAdd.MouseButton1Click:Connect(function()
		        if NameBox.Text == "" then return end
		        Component:ChangeValue(NameBox.Text)
		        NameBox.Text = ""
		        NewProfile.Visible = false
		    end)
		
		    local PublicButton: TextButton = AddRowButton("Public", "kingvape/assets/new/profileworld.png", "PUBLIC", false, "Browse public profiles", 1)
		    PublicButton.Position = UDim2.new(1, -PublicButton.Size.X.Offset, 0, PublicButton.Position.Y.Offset)
		
		    PublicButton.MouseButton1Click:Connect(function()
		        local Public = vape.PublicProfiles
		        if not Public then return end
		        Public.Window.Position = UDim2.new(0.5, -356, 0.5, -214)
		        Public.Window.Visible = true
		    end)
		
		    NewArrowButton.MouseButton1Click:Connect(function()
		        Component:Expand()
		        NewArrow.Rotation = Arrow.Rotation
		    end)
		end
		
		local CursedPadding: Frame = Instance.new("Frame")
		CursedPadding.BackgroundTransparency = 1
		CursedPadding.Size = UDim2.fromOffset()
		CursedPadding.Parent = Children
		Props.Function = Props.Function or function() end
		
		function Component:CreateProfile(Value: string, Data)
		    local Profile = {
		        Name = Value
		    }
		
		    Profile.Bind = Components.Bind({
		        Module = true,
		        Cover = true
		    }, nil, Profile)
		    Profile.Bind.Object.Position = UDim2.new(1, -30, 0, 7)
		    Profile.Bind.Triggered:Connect(function(IsPressed: boolean)
		        if IsPressed and vape.Profile ~= Value then
		            vape:Save(Value)
		            vape:Load(true)
		            self:ChangeValue()
		        end
		    end)
		
		    if Data then
		        Profile.Bind:Load(Data)
		    end
		
		    table.insert(self.List, Profile)
		end
		
		function Component:ChangeValue(Value: string?, SkipGUI: boolean?)
		    if Value then
		        if Props.Profiles then
		            local Index, Profile = self:GetValue(Value)
		            if Index then
		                if Value ~= "default" then
		                    Profile.Bind:Destroy()
		                    table.remove(self.List, Index)
		
		                    if isfile(`kingvape/profiles/{Value}{vape.Place}.txt`) and delfile then
		                        delfile(`kingvape/profiles/{Value}{vape.Place}.txt`)
		                    end
		                end
		            else
		                self:CreateProfile(Value)
		            end
		        else
		            local Index: number? = table.find(self.List, Value)
		            if Index then
		                table.remove(self.List, Index)
		
		                Index = table.find(self.ListEnabled, Value)
		                if Index then
		                    table.remove(self.ListEnabled, Index)
		                end
		            else
		                table.insert(self.List, Value)
		                table.insert(self.ListEnabled, Value)
		            end
		        end
		    end
		
		    Props.Function()
		    for _, v: any in self.Objects do
		        v:Destroy()
		    end
		    table.clear(self.Objects)
		    self.Selected = nil
		
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    for _, Entry: any in self.List do
		        if Props.Profiles then
		            local Object: TextButton = Instance.new("TextButton")
		            Object.Name = Entry.Name
		            Object.Size = UDim2.fromOffset(200, 32)
		            Object.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		            Object.AutoButtonColor = false
		            Object.Text = ""
		            Object.Parent = Children
		            AddCorner(Object)
		            local Stroke: UIStroke = Instance.new("UIStroke")
		            Stroke.Color = Color.Light(UIPallet.Main, 0.1)
		            Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		            Stroke.Enabled = false
		            Stroke.Parent = Object
		            local Label: TextLabel = Instance.new("TextLabel")
		            Label.Name = "Title"
		            Label.Size = UDim2.new(1, -10, 1, 0)
		            Label.Position = UDim2.fromOffset(10, 0)
		            Label.BackgroundTransparency = 1
		            Label.Text = Entry.Name
		            Label.TextXAlignment = Enum.TextXAlignment.Left
		            Label.TextColor3 = Color.Dark(UIPallet.Text, 0.4)
		            Label.TextSize = 15
		            Label.FontFace = UIPallet.Font
		            Label.Parent = Object
		            local DotsButton: TextButton = Instance.new("TextButton")
		            DotsButton.BackgroundTransparency = 1
		            DotsButton.Name = "Dots"
		            DotsButton.Position = UDim2.new(1, -25, 0, 0)
		            DotsButton.Size = UDim2.fromOffset(25, 32)
		            DotsButton.Text = ""
		            DotsButton.Parent = Object
		            local Dots: ImageLabel = Instance.new("ImageLabel")
		            Dots.BackgroundTransparency = 1
		            Dots.Image = GetVapeAsset("kingvape/assets/new/settingdots.png")
		            Dots.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		            Dots.Name = "Dots"
		            Dots.Position = UDim2.fromOffset(11, 9)
		            Dots.Size = UDim2.fromOffset(3, 16)
		            Dots.Parent = DotsButton
		            Entry.Bind:SetParent(Object)
		            Entry.Enabled = Entry.Name == vape.Profile
		
		            DotsButton.MouseButton1Click:Connect(function()
		                if not Entry.Enabled then
		                    Component:ChangeValue(Entry.Name)
		                end
		            end)
		
		            DotsButton.MouseEnter:Connect(function()
		                if not Entry.Enabled then
		                    Dots.ImageColor3 = UIPallet.Text
		                end
		            end)
		
		            DotsButton.MouseLeave:Connect(function()
		                if not Entry.Enabled then
		                    Dots.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		                end
		            end)
		
		            Object.MouseButton1Click:Connect(function()
		                vape:Save(Entry.Name)
		                vape:Load(true)
		                self:ChangeValue()
		            end)
		
		            Object.MouseEnter:Connect(function()
		                Entry.Bind:SetVisible(true)
		            end)
		
		            Object.MouseLeave:Connect(function()
		                Entry.Bind:SetVisible(false)
		            end)
		
		            if Entry.Enabled then
		                self.Selected = Object
		            else
		                Entry.Bind:SetColor(Color.Dark(UIPallet.Text, 0.43))
		            end
		
		            table.insert(self.Objects, {
		                Destroy = function()
		                    Entry.Bind:SetParent(nil)
		                    Object:Destroy()
		                end
		            })
		        else
		            local IsEnabled: number? = table.find(self.ListEnabled, Entry)
		            local Object: TextButton = Instance.new("TextButton")
		            Object.Name = Entry
		            Object.Size = UDim2.fromOffset(200, 31)
		            Object.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		            Object.AutoButtonColor = false
		            Object.Text = ""
		            Object.Parent = Children
		            AddCorner(Object)
		            local Background: Frame = Instance.new("Frame")
		            Background.BackgroundColor3 = UIPallet.Main
		            Background.Position = UDim2.fromOffset(1, 1)
		            Background.Size = UDim2.new(1, -2, 1, -2)
		            Background.Visible = false
		            Background.Parent = Object
		            AddCorner(Background)
		            local Dot: Frame = Instance.new("Frame")
		            Dot.BackgroundColor3 = IsEnabled and Props.Color or Color.Light(UIPallet.Main, 0.37)
		            Dot.Position = UDim2.fromOffset(10, 12)
		            Dot.Size = UDim2.fromOffset(10, 11)
		            Dot.Parent = Object
		            AddCorner(Dot, UDim.new(1, 0))
		            local DotInner: Frame = Dot:Clone()
		            DotInner.BackgroundColor3 = IsEnabled and Props.Color or Color.Light(UIPallet.Main, 0.02)
		            DotInner.Position = UDim2.fromOffset(1, 1)
		            DotInner.Size = UDim2.fromOffset(8, 9)
		            DotInner.Parent = Dot
		            local Label: TextLabel = Instance.new("TextLabel")
		            Label.BackgroundTransparency = 1
		            Label.FontFace = UIPallet.Font
		            Label.Position = UDim2.fromOffset(30, 0)
		            Label.Size = UDim2.new(1, -30, 1, 0)
		            Label.Text = Entry
		            Label.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		            Label.TextSize = 15
		            Label.TextXAlignment = Enum.TextXAlignment.Left
		            Label.Parent = Object
		            local Close: ImageButton = Instance.new("ImageButton")
		            Close.AutoButtonColor = false
		            Close.BackgroundColor3 = Color3.new(1, 1, 1)
		            Close.BackgroundTransparency = 1
		            Close.Image = GetVapeAsset("kingvape/assets/new/closetiny.png")
		            Close.ImageColor3 = Color.Light(UIPallet.Text, 0.2)
		            Close.ImageTransparency = 0.5
		            Close.Position = UDim2.new(1, -27, 0, 8)
		            Close.Size = UDim2.fromOffset(18, 17)
		            Close.Parent = Object
		            AddCorner(Close, UDim.new(1, 0))
		
		            Close.MouseEnter:Connect(function()
		                Close.ImageTransparency = 0.3
		
		                Tween:Tween(Close, UIPallet.Tween, {
		                    BackgroundTransparency = 0.6
		                })
		            end)
		
		            Close.MouseLeave:Connect(function()
		                Close.ImageTransparency = 0.5
		
		                Tween:Tween(Close, UIPallet.Tween, {
		                    BackgroundTransparency = 1
		                })
		            end)
		
		            Close.MouseButton1Click:Connect(function()
		                Component:ChangeValue(Entry)
		            end)
		
		            Object.MouseEnter:Connect(function()
		                Background.Visible = true
		            end)
		
		            Object.MouseLeave:Connect(function()
		                Background.Visible = false
		            end)
		
		            Object.MouseButton1Click:Connect(function()
		                local Index: number? = table.find(self.ListEnabled, Entry)
		                if Index then
		                    table.remove(self.ListEnabled, Index)
		                    Dot.BackgroundColor3 = Color.Light(UIPallet.Main, 0.37)
		                    DotInner.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		                else
		                    table.insert(self.ListEnabled, Entry)
		                    Dot.BackgroundColor3 = Props.Color
		                    DotInner.BackgroundColor3 = Props.Color
		                end
		
		                Props.Function()
		            end)
		
		            table.insert(self.Objects, Object)
		        end
		    end
		
		    if not SkipGUI then
		        vape:UpdateGUI(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
		    end
		end
		
		function Component:Color(Hue: number, Sat: number, Val: number, IsRainbow: boolean)
		    for _, Option: any in self.Options do
		        if Option.Color then
		            Option:Color(Hue, Sat, Val, IsRainbow)
		        end
		    end
		
		    AddButton.ImageColor3 = IsRainbow and Color3.fromHSV(vape:Color(Hue % 1)) or Color3.fromHSV(Hue, Sat, Val)
		
		    for _, v: (Color3?, Color3?) -> () in RowPaints do
		        v(AddButton.ImageColor3, vape.GUIColor.Rainbow and Color3.new(0.19, 0.19, 0.19) or vape:TextColor(Hue, Sat, Val))
		    end
		
		    if self.Selected then
		        self.Selected.BackgroundColor3 = IsRainbow and Color3.fromHSV(vape:Color(Hue % 1)) or Color3.fromHSV(Hue, Sat, Val)
		        self.Selected.Title.TextColor3 = vape.GUIColor.Rainbow and Color3.new(0.19, 0.19, 0.19) or vape:TextColor(Hue, Sat, Val)
		        self.Selected.Dots.Dots.ImageColor3 = self.Selected.Title.TextColor3
		        self.Selected.Bind.Icon.ImageColor3 = self.Selected.Title.TextColor3
		        self.Selected.Bind.TextLabel.TextColor3 = self.Selected.Title.TextColor3
		    end
		end
		
		function Component:Expand()
		    self.Expanded = not self.Expanded
		    Children.Visible = self.Expanded
		    Arrow.Rotation = self.Expanded and 0 or 180
		    Window.Size = UDim2.fromOffset(220, self.Expanded and math.min(51 + WindowList.AbsoluteContentSize.Y / Scale.Scale, 611) or 45)
		    Divider.Visible = Children.CanvasPosition.Y > 10 and Children.Visible
		    vape:QueueSave()
		end
		
		function Component:GetValue(Name: string)
		    for i: number, Profile: any in self.List do
		        if Profile.Name == Name then
		            return i, Profile
		        end
		    end
		end
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    vape:LoadOptions(self, Data.Options)
		
		    if Data.Enabled then
		        self.Button:Toggle()
		    end
		
		    if Data.Expanded then
		        self:Expand()
		    end
		
		    if Props.Profiles then
		        for _, v: any in Data.List or {} do
		            if not self:GetValue(v.Name) then
		                self:CreateProfile(v.Name, v.Bind)
		            end
		        end
		
		        self:ChangeValue(nil, true)
		    else
		        if Data.List and (#self.List > 0 or #Data.List > 0) then
		            self.List = Data.List or {}
		            self.ListEnabled = Data.ListEnabled or {}
		            self:ChangeValue(nil, true)
		        end
		    end
		
		    if Data.Position then
		        Window.Position = UDim2.fromOffset(Data.Position.X, Data.Position.Y)
		    end
		end
		
		function Component:Save(Data)
		    Data[Props.Name] = {
		        Enabled = self.Button.Enabled,
		        Expanded = self.Expanded,
		        List = self.List,
		        ListEnabled = self.ListEnabled,
		        Options = vape:SaveOptions(self),
		        Position = {
		            X = Window.Position.X.Offset,
		            Y = Window.Position.Y.Offset
		        }
		    }
		
		    if Props.Profiles then
		        local NewList: {any} = {}
		
		        for _, Profile: any in self.List do
		            local Entry = {
		                Name = Profile.Name
		            }
		
		            Profile.Bind:Save(Entry)
		            table.insert(NewList, Entry)
		        end
		
		        Data[Props.Name].List = NewList
		    end
		end
		
		for ComponentName: string, Constructor: (...any) -> ...any in Components do
		    Component[`Create{ComponentName}`] = function(_, Properties)
		        return Constructor(Properties, ChildrenTwo, Component)
		    end
		end
		
		AddButton.MouseEnter:Connect(function()
		    AddButton.ImageTransparency = 0
		end)
		
		AddButton.MouseLeave:Connect(function()
		    AddButton.ImageTransparency = 0.3
		end)
		
		AddButton.MouseButton1Click:Connect(function()
		    if not table.find(Component.List, AddValue.Text) then
		        Component:ChangeValue(AddValue.Text)
		        AddValue.Text = ""
		    end
		end)
		
		ArrowButton.MouseEnter:Connect(function()
		    Arrow.ImageColor3 = Color3.fromRGB(220, 220, 220)
		end)
		
		ArrowButton.MouseLeave:Connect(function()
		    Arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
		end)
		
		ArrowButton.MouseButton1Click:Connect(function()
		    Component:Expand()
		end)
		
		ArrowButton.MouseButton2Click:Connect(function()
		    Component:Expand()
		end)
		
		AddValue.FocusLost:Connect(function(Enter: boolean)
		    if Enter and not table.find(Component.List, AddValue.Text) then
		        Component:ChangeValue(AddValue.Text)
		        AddValue.Text = ""
		    end
		end)
		
		AddValue.MouseEnter:Connect(function()
		    Tween:Tween(AddBackground, UIPallet.Tween, {
		        BackgroundColor3 = Color.Light(UIPallet.Main, 0.14)
		    })
		end)
		
		AddValue.MouseLeave:Connect(function()
		    Tween:Tween(AddBackground, UIPallet.Tween, {
		        BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		    })
		end)
		
		Children:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    Divider.Visible = Children.CanvasPosition.Y > 10 and Children.Visible
		end)
		
		Settings.MouseEnter:Connect(function()
		    Settings.ImageColor3 = UIPallet.Text
		end)
		
		Settings.MouseLeave:Connect(function()
		    Settings.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		end)
		
		Settings.MouseButton1Click:Connect(function()
		    ChildrenTwo.Visible = not ChildrenTwo.Visible
		end)
		
		Window.InputBegan:Connect(function(Input: InputObject)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    if Input.Position.Y < Window.AbsolutePosition.Y + 41 and Input.UserInputType == Enum.UserInputType.MouseButton2 then
		        Component:Expand()
		    end
		end)
		
		WindowList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    Children.CanvasSize = UDim2.fromOffset(0, WindowList.AbsoluteContentSize.Y / Scale.Scale)
		    if Component.Expanded then
		        Window.Size = UDim2.fromOffset(220, math.min(51 + WindowList.AbsoluteContentSize.Y / Scale.Scale, 611))
		    end
		end)
		
		WindowListTwo:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    ChildrenTwo.Size = UDim2.fromOffset(220, WindowListTwo.AbsoluteContentSize.Y / Scale.Scale)
		end)
		
		Component.Button = vape.Categories.Main:CreateGUIButton({
		    Name = Props.Name,
		    Icon = Props.CategoryIcon,
		    Size = Props.CategorySize,
		    Window = Window
		})
		
		Component.Object = Window
		vape.Categories[Props.Name] = Component
		
		return Component
	end,
	ColorSlider = function(Props, Children, API)
		local Component = {
		    Type = "ColorSlider",
		    Hue = Props.DefaultHue or 0.44,
		    Sat = Props.DefaultSat or 1,
		    Value = Props.DefaultValue or 1,
		    Opacity = Props.DefaultOpacity or 1,
		    Rainbow = false,
		    Index = 0
		}
		
		local function CreateExtraSlider(Name: string, GradientColor: ColorSequence)
		    local ColorSliderCustom: TextButton = Instance.new("TextButton")
		    ColorSliderCustom.AutoButtonColor = false
		    ColorSliderCustom.BackgroundColor3 = Color.Dark(Children.BackgroundColor3, Props.Darker and 0.02 or 0)
		    ColorSliderCustom.BorderSizePixel = 0
		    ColorSliderCustom.Size = UDim2.new(1, 0, 0, 50)
		    ColorSliderCustom.Text = ""
		    ColorSliderCustom.Visible = false
		    ColorSliderCustom.Parent = Children
		    local Title: TextLabel = Instance.new("TextLabel")
		    Title.BackgroundTransparency = 1
		    Title.FontFace = UIPallet.Font
		    Title.Position = UDim2.fromOffset(10, 2)
		    Title.Size = UDim2.fromOffset(60, 30)
		    Title.Text = Name
		    Title.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		    Title.TextSize = 11
		    Title.TextXAlignment = Enum.TextXAlignment.Left
		    Title.Parent = ColorSliderCustom
		    local Holder: Frame = Instance.new("Frame")
		    Holder.BackgroundColor3 = Color3.new(1, 1, 1)
		    Holder.BorderSizePixel = 0
		    Holder.Name = "Holder"
		    Holder.Position = UDim2.fromOffset(10, 37)
		    Holder.Size = UDim2.new(1, -20, 0, 2)
		    Holder.Parent = ColorSliderCustom
		    local Gradient: UIGradient = Instance.new("UIGradient")
		    Gradient.Color = GradientColor
		    Gradient.Parent = Holder
		    local Fill: Frame = Instance.new("Frame")
		    Fill.BackgroundTransparency = 1
		    Fill.Name = "Fill"
		    Fill.Size = UDim2.fromScale(math.clamp(Name == "Saturation" and Component.Sat or Name == "Vibrance" and Component.Value or Component.Opacity, 0.04, 0.96), 1)
		    Fill.Parent = Holder
		    local KnobHolder: Frame = Instance.new("Frame")
		    KnobHolder.AnchorPoint = Vector2.new(0.5, 0.5)
		    KnobHolder.BackgroundColor3 = ColorSliderCustom.BackgroundColor3
		    KnobHolder.BorderSizePixel = 0
		    KnobHolder.Position = UDim2.fromScale(1, 0.5)
		    KnobHolder.Size = UDim2.fromOffset(24, 4)
		    KnobHolder.Parent = Fill
		    local Knob: Frame = Instance.new("Frame")
		    Knob.AnchorPoint = Vector2.new(0.5, 0.5)
		    Knob.BackgroundColor3 = UIPallet.Text
		    Knob.Position = UDim2.fromScale(0.5, 0.5)
		    Knob.Size = UDim2.fromOffset(14, 14)
		    Knob.Parent = KnobHolder
		    AddCorner(Knob, UDim.new(1, 0))
		
		    ColorSliderCustom.InputBegan:Connect(function(Input: InputObject)
		        if vape.ThreadFix then
		            setthreadidentity(8)
		        end
		
		        if
		            (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch)
		            and (Input.Position.Y - ColorSliderCustom.AbsolutePosition.Y) > (20 * Scale.Scale)
		        then
		            local ReleaseConnection
		            local MoveConnection: RBXScriptConnection = UserInputService.InputChanged:Connect(function(NewInput: InputObject)
		                if vape.ThreadFix then
		                    setthreadidentity(8)
		                end
		
		                if NewInput.UserInputType == (Input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
		                    local NewValue: number = math.clamp((NewInput.Position.X - Holder.AbsolutePosition.X) / Holder.AbsoluteSize.X, 0, 1)
		                    Component:SetValue(nil, Name == "Saturation" and NewValue or nil, Name == "Vibrance" and NewValue or nil, Name == "Opacity" and NewValue or nil)
		                end
		            end)
		
		            ReleaseConnection = Input.Changed:Connect(function()
		                if Input.UserInputState == Enum.UserInputState.End then
		                    MoveConnection:Disconnect()
		                    ReleaseConnection:Disconnect()
		                end
		            end)
		        end
		    end)
		
		    ColorSliderCustom.MouseEnter:Connect(function()
		        Tween:Tween(Knob, UIPallet.Tween, {
		            Size = UDim2.fromOffset(16, 16)
		        })
		    end)
		
		    ColorSliderCustom.MouseLeave:Connect(function()
		        Tween:Tween(Knob, UIPallet.Tween, {
		            Size = UDim2.fromOffset(14, 14)
		        })
		    end)
		
		    return ColorSliderCustom
		end
		
		local ColorSlider: TextButton = Instance.new("TextButton")
		ColorSlider.AutoButtonColor = false
		ColorSlider.BackgroundColor3 = Color.Dark(Children.BackgroundColor3, Props.Darker and 0.02 or 0)
		ColorSlider.BorderSizePixel = 0
		ColorSlider.Size = UDim2.new(1, 0, 0, 50)
		ColorSlider.Text = ""
		ColorSlider.Visible = Props.Visible == nil or Props.Visible
		ColorSlider.Parent = Children
		Component.Object = ColorSlider
		AddTooltip(ColorSlider, Props.Tooltip)
		local Title: TextLabel = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.FontFace = UIPallet.Font
		Title.Position = UDim2.fromOffset(10, 2)
		Title.Size = UDim2.fromOffset(60, 30)
		Title.Text = Props.Name
		Title.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		Title.TextSize = 11
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Parent = ColorSlider
		local CustomBox: TextBox = Instance.new("TextBox")
		CustomBox.BackgroundTransparency = 1
		CustomBox.FontFace = UIPallet.Font
		CustomBox.Position = UDim2.new(1, -69, 0, 9)
		CustomBox.Size = UDim2.fromOffset(60, 15)
		CustomBox.Text = ""
		CustomBox.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		CustomBox.TextSize = 11
		CustomBox.TextXAlignment = Enum.TextXAlignment.Right
		CustomBox.Visible = false
		CustomBox.Parent = ColorSlider
		local Holder: Frame = Instance.new("Frame")
		Holder.BackgroundColor3 = Color3.new(1, 1, 1)
		Holder.BorderSizePixel = 0
		Holder.Position = UDim2.fromOffset(10, 39)
		Holder.Size = UDim2.new(1, -20, 0, 2)
		Holder.Parent = ColorSlider
		local RainbowTable: {ColorSequenceKeypoint} = {}
		for Hue: number = 0, 1, 0.1 do
		    table.insert(RainbowTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)))
		end
		local Gradient: UIGradient = Instance.new("UIGradient")
		Gradient.Color = ColorSequence.new(RainbowTable)
		Gradient.Parent = Holder
		local Fill: Frame = Instance.new("Frame")
		Fill.BackgroundTransparency = 1
		Fill.Size = UDim2.fromScale(math.clamp(Component.Hue, 0.04, 0.96), 1)
		Fill.Parent = Holder
		local KnobHolder: Frame = Instance.new("Frame")
		KnobHolder.AnchorPoint = Vector2.new(0.5, 0.5)
		KnobHolder.BackgroundColor3 = ColorSlider.BackgroundColor3
		KnobHolder.BorderSizePixel = 0
		KnobHolder.Position = UDim2.fromScale(1, 0.5)
		KnobHolder.Size = UDim2.fromOffset(24, 4)
		KnobHolder.Parent = Fill
		local Knob: Frame = Instance.new("Frame")
		Knob.AnchorPoint = Vector2.new(0.5, 0.5)
		Knob.BackgroundColor3 = UIPallet.Text
		Knob.Position = UDim2.fromScale(0.5, 0.5)
		Knob.Size = UDim2.fromOffset(14, 14)
		Knob.Parent = KnobHolder
		AddCorner(Knob, UDim.new(1, 0))
		local Preview: ImageButton = Instance.new("ImageButton")
		Preview.BackgroundTransparency = 1
		Preview.Image = GetVapeAsset("kingvape/assets/new/colorpreview.png")
		Preview.ImageColor3 = Color3.fromHSV(Component.Hue, Component.Sat, Component.Value)
		Preview.ImageTransparency = 1 - Component.Opacity
		Preview.Position = UDim2.new(1, -22, 0, 10)
		Preview.Size = UDim2.fromOffset(12, 12)
		Preview.Parent = ColorSlider
		local Expand: TextButton = Instance.new("TextButton")
		Expand.BackgroundTransparency = 1
		Expand.Position = UDim2.fromOffset(GetFontBounds(Title.Text, Title.TextSize, Title.FontFace).X + 11, 7)
		Expand.Size = UDim2.fromOffset(17, 13)
		Expand.Text = ""
		Expand.Parent = ColorSlider
		local Icon: ImageLabel = Instance.new("ImageLabel")
		Icon.BackgroundTransparency = 1
		Icon.Image = GetVapeAsset("kingvape/assets/new/downexpandslider.png")
		Icon.ImageColor3 = Color.Dark(UIPallet.Text, 0.43)
		Icon.Position = UDim2.fromOffset(4, 4)
		Icon.Size = UDim2.fromOffset(10, 5)
		Icon.Parent = Expand
		local Rainbow: TextButton = Instance.new("TextButton")
		Rainbow.BackgroundTransparency = 1
		Rainbow.Position = UDim2.new(1, -42, 0, 10)
		Rainbow.Size = UDim2.fromOffset(12, 12)
		Rainbow.Text = ""
		Rainbow.Parent = ColorSlider
		local Ring1: ImageLabel = Instance.new("ImageLabel")
		Ring1.BackgroundTransparency = 1
		Ring1.Image = GetVapeAsset("kingvape/assets/new/rainbow_1.png")
		Ring1.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		Ring1.Size = UDim2.fromOffset(12, 12)
		Ring1.Parent = Rainbow
		local Ring2: ImageLabel = Instance.fromExisting(Ring1)
		Ring2.Image = GetVapeAsset("kingvape/assets/new/rainbow_2.png")
		Ring2.Parent = Rainbow
		local Ring3: ImageLabel = Instance.fromExisting(Ring1)
		Ring3.Image = GetVapeAsset("kingvape/assets/new/rainbow_3.png")
		Ring3.Parent = Rainbow
		local Ring4: ImageLabel = Instance.fromExisting(Ring1)
		Ring4.Image = GetVapeAsset("kingvape/assets/new/rainbow_4.png")
		Ring4.Parent = Rainbow
		Props.Function = Props.Function or function() end
		
		local SaturationSlider: TextButton = CreateExtraSlider("Saturation", ColorSequence.new({
		    ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, Component.Value)),
		    ColorSequenceKeypoint.new(1, Color3.fromHSV(Component.Hue, 1, Component.Value))
		}))
		
		local VibranceSlider: TextButton = CreateExtraSlider("Vibrance", ColorSequence.new({
		    ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
		    ColorSequenceKeypoint.new(1, Color3.fromHSV(Component.Hue, Component.Sat, 1))
		}))
		
		local OpacitySlider: TextButton = CreateExtraSlider("Opacity", ColorSequence.new({
		    ColorSequenceKeypoint.new(0, Color.Dark(UIPallet.Main, 0.02)),
		    ColorSequenceKeypoint.new(1, Color3.fromHSV(Component.Hue, Component.Sat, Component.Value))
		}))
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    local Hue: number = Data.Hue or self.Hue
		    local Sat: number = Data.Sat or self.Sat
		    local Value: number = Data.Value or self.Value
		    local Opacity: number = Data.Opacity or self.Opacity
		
		    if (Data.Rainbow or false) ~= self.Rainbow then
		        self:Toggle()
		    end
		
		    if self.Hue ~= Hue or self.Sat ~= Sat or self.Value ~= Value or self.Opacity ~= Opacity then
		        self:SetValue(Hue, Sat, Value, Opacity)
		    end
		end
		
		function Component:Save(Data)
		    Data[Props.Name] = {
		        Hue = self.Hue,
		        Sat = self.Sat,
		        Value = self.Value,
		        Opacity = self.Opacity,
		        Rainbow = self.Rainbow
		    }
		end
		
		function Component:SetValue(Hue: number?, Sat: number?, Val: number?, Opacity: number?)
		    self.Hue = Hue or self.Hue
		    self.Sat = Sat or self.Sat
		    self.Value = Val or self.Value
		    self.Opacity = Opacity or self.Opacity
		    Preview.ImageColor3 = Color3.fromHSV(self.Hue, self.Sat, self.Value)
		    Preview.ImageTransparency = 1 - self.Opacity
		
		    SaturationSlider.Holder.UIGradient.Color = ColorSequence.new({
		        ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, self.Value)),
		        ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, 1, self.Value))
		    })
		
		    VibranceSlider.Holder.UIGradient.Color = ColorSequence.new({
		        ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
		        ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, self.Sat, 1))
		    })
		
		    OpacitySlider.Holder.UIGradient.Color = ColorSequence.new({
		        ColorSequenceKeypoint.new(0, Color.Dark(UIPallet.Main, 0.02)),
		        ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, self.Sat, self.Value))
		    })
		
		    if self.Rainbow then
		        Fill.Size = UDim2.fromScale(math.clamp(self.Hue, 0.04, 0.96), 1)
		    else
		        Tween:Tween(Fill, UIPallet.Tween, {
		            Size = UDim2.fromScale(math.clamp(self.Hue, 0.04, 0.96), 1)
		        })
		    end
		
		    if Sat then
		        Tween:Tween(SaturationSlider.Holder.Fill, UIPallet.Tween, {
		            Size = UDim2.fromScale(math.clamp(self.Sat, 0.04, 0.96), 1)
		        })
		    end
		
		    if Val then
		        Tween:Tween(VibranceSlider.Holder.Fill, UIPallet.Tween, {
		            Size = UDim2.fromScale(math.clamp(self.Value, 0.04, 0.96), 1)
		        })
		    end
		
		    if Opacity then
		        Tween:Tween(OpacitySlider.Holder.Fill, UIPallet.Tween, {
		            Size = UDim2.fromScale(math.clamp(self.Opacity, 0.04, 0.96), 1)
		        })
		    end
		
		    if not self.Rainbow then
		        vape:QueueSave()
		    end
		
		    Props.Function(self.Hue, self.Sat, self.Value, self.Opacity)
		end
		
		function Component:Toggle()
		    self.Rainbow = not self.Rainbow
		
		    if self.Rainbow then
		        table.insert(vape.RainbowSliders, self)
		
		        Ring1.ImageColor3 = Color3.fromRGB(5, 127, 100)
		        task.delay(0.1, function()
		            if vape.ThreadFix then
		                setthreadidentity(8)
		            end
		
		            if not self.Rainbow then return end
		            Ring2.ImageColor3 = Color3.fromRGB(228, 125, 43)
		            task.delay(0.1, function()
		                if vape.ThreadFix then
		                    setthreadidentity(8)
		                end
		
		                if not self.Rainbow then return end
		                Ring3.ImageColor3 = Color3.fromRGB(225, 46, 52)
		            end)
		        end)
		    else
		        local Index: number? = table.find(vape.RainbowSliders, self)
		        if Index then
		            table.remove(vape.RainbowSliders, Index)
		        end
		
		        Ring3.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		        task.delay(0.1, function()
		            if vape.ThreadFix then
		                setthreadidentity(8)
		            end
		
		            if self.Rainbow then return end
		            Ring2.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		            task.delay(0.1, function()
		                if vape.ThreadFix then
		                    setthreadidentity(8)
		                end
		
		                if self.Rainbow then return end
		                Ring1.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		            end)
		        end)
		    end
		
		    vape:QueueSave()
		end
		
		Preview.MouseButton1Click:Connect(function()
		    Preview.Visible = false
		    CustomBox.Visible = true
		    CustomBox:CaptureFocus()
		
		    local CurrentColor: Color3 = Color3.fromHSV(Component.Hue, Component.Sat, Component.Value)
		    CustomBox.Text = `{math.round(CurrentColor.R * 255)}, {math.round(CurrentColor.G * 255)}, {math.round(CurrentColor.B * 255)}`
		end)
		
		local DoubleClick: number = os.clock()
		ColorSlider.InputBegan:Connect(function(Input: InputObject)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    if
		        (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch)
		        and (Input.Position.Y - ColorSlider.AbsolutePosition.Y) > (20 * Scale.Scale)
		    then
		        local ReleaseConnection
		        local MoveConnection: RBXScriptConnection = UserInputService.InputChanged:Connect(function(NewInput: InputObject)
		            if vape.ThreadFix then
		                setthreadidentity(8)
		            end
		
		            if NewInput.UserInputType == (Input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
		                Component:SetValue(math.clamp((NewInput.Position.X - Holder.AbsolutePosition.X) / Holder.AbsoluteSize.X, 0, 1))
		            end
		        end)
		
		        ReleaseConnection = Input.Changed:Connect(function()
		            if Input.UserInputState == Enum.UserInputState.End then
		                MoveConnection:Disconnect()
		                ReleaseConnection:Disconnect()
		            end
		        end)
		
		        if DoubleClick > os.clock() then
		            Component:Toggle()
		        else
		            Component:SetValue(math.clamp((Input.Position.X - Holder.AbsolutePosition.X) / Holder.AbsoluteSize.X, 0, 1))
		        end
		
		        DoubleClick = os.clock() + 0.3
		    end
		end)
		
		ColorSlider.MouseEnter:Connect(function()
		    Tween:Tween(Knob, UIPallet.Tween, {
		        Size = UDim2.fromOffset(16, 16)
		    })
		end)
		
		ColorSlider.MouseLeave:Connect(function()
		    Tween:Tween(Knob, UIPallet.Tween, {
		        Size = UDim2.fromOffset(14, 14)
		    })
		end)
		
		ColorSlider:GetPropertyChangedSignal("Visible"):Connect(function()
		    SaturationSlider.Visible = Icon.Rotation == 180 and ColorSlider.Visible
		    VibranceSlider.Visible = SaturationSlider.Visible
		    OpacitySlider.Visible = SaturationSlider.Visible
		end)
		
		Expand.MouseEnter:Connect(function()
		    Icon.ImageColor3 = Color.Dark(UIPallet.Text, 0.16)
		end)
		
		Expand.MouseLeave:Connect(function()
		    Icon.ImageColor3 = Color.Dark(UIPallet.Text, 0.43)
		end)
		
		Expand.MouseButton1Click:Connect(function()
		    SaturationSlider.Visible = not SaturationSlider.Visible
		    VibranceSlider.Visible = SaturationSlider.Visible
		    OpacitySlider.Visible = SaturationSlider.Visible
		    Icon.Rotation = SaturationSlider.Visible and 180 or 0
		end)
		
		Rainbow.MouseButton1Click:Connect(function()
		    Component:Toggle()
		end)
		
		CustomBox.FocusLost:Connect(function(Enter: boolean)
		    Preview.Visible = true
		    CustomBox.Visible = false
		
		    if Enter then
		        local Success, Parsed = pcall(function()
		            local Commas: {string} = CustomBox.Text:split(",")
		            return tonumber(Commas[1]) and Color3.fromRGB(tonumber(Commas[1]), tonumber(Commas[2]), tonumber(Commas[3])) or Color3.fromHex(CustomBox.Text)
		        end)
		
		        if Success then
		            if Component.Rainbow then
		                Component:Toggle()
		            end
		
		            Component:SetValue(Parsed:ToHSV())
		        end
		    end
		end)
		
		API.Options[Props.Name] = Component
		
		return Component
	end,
	Divider = function(Props, Children, API)
		local Divider: Frame = Instance.new("Frame")
		Divider.Size = UDim2.new(1, 0, 0, 1)
		Divider.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		Divider.BorderSizePixel = 0
		Divider.Parent = Children
		
		if Props and Props.Text then
		    local Label: TextLabel = Instance.new("TextLabel")
		    Label.Size = UDim2.fromOffset(218, 27)
		    Label.BackgroundTransparency = 1
		    Label.Text = `            {Props.Text:upper()}`
		    Label.TextXAlignment = Enum.TextXAlignment.Left
		    Label.TextColor3 = Color.Dark(UIPallet.Text, 0.43)
		    Label.TextSize = 9
		    Label.FontFace = UIPallet.Font
		    Label.Parent = Children
		    Divider.BackgroundTransparency = 1
		    Divider.Parent = Label
		end
	end,
	Dropdown = function(Props, Children, API)
		local Component = {
		    Default = Props.Default or Props.List[1] or "None",
		    Index = 0,
		    List = Props.List,
		    Type = "Dropdown",
		    Value = Props.List[1] or "None"
		}
		
		local Dropdown: TextButton = Instance.new("TextButton")
		Dropdown.AutoButtonColor = false
		Dropdown.BackgroundColor3 = Color.Dark(Children.BackgroundColor3, Props.Darker and 0.02 or 0)
		Dropdown.BorderSizePixel = 0
		Dropdown.Size = UDim2.new(1, 0, 0, 40)
		Dropdown.Text = ""
		Dropdown.Visible = Props.Visible == nil or Props.Visible
		Dropdown.Parent = Children
		Component.Object = Dropdown
		AddTooltip(Dropdown, Props.Tooltip or Props.Name)
		local Holder: Frame = Instance.new("Frame")
		Holder.BackgroundColor3 = Color.Light(UIPallet.Main, 0.034)
		Holder.Position = UDim2.fromOffset(10, 4)
		Holder.Size = UDim2.new(1, -20, 1, -11)
		Holder.Parent = Dropdown
		AddCorner(Holder, UDim.new(0, 6))
		local Button: TextButton = Instance.new("TextButton")
		Button.AutoButtonColor = false
		Button.BackgroundColor3 = UIPallet.Main
		Button.Position = UDim2.fromOffset(1, 1)
		Button.Size = UDim2.new(1, -2, 1, -2)
		Button.Text = ""
		Button.Parent = Holder
		local Title: TextLabel = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.FontFace = UIPallet.Font
		Title.Size = UDim2.new(1, 0, 0, 29)
		Title.Text = `         {Props.Name} - {Component.Value}`
		Title.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		Title.TextSize = 13
		Title.TextTruncate = Enum.TextTruncate.AtEnd
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Parent = Button
		AddCorner(Button, UDim.new(0, 6))
		local Arrow: ImageLabel = Instance.new("ImageLabel")
		Arrow.BackgroundTransparency = 1
		Arrow.Image = GetVapeAsset("kingvape/assets/new/expandarrow.png")
		Arrow.ImageColor3 = Color3.fromRGB(140, 140, 140)
		Arrow.Position = UDim2.new(1, -17, 0, 11)
		Arrow.Rotation = 90
		Arrow.Size = UDim2.fromOffset(4, 8)
		Arrow.Parent = Button
		Props.Function = Props.Function or function() end
		local DropdownChildren: Frame?
		
		function Component:Change(List: {string}?)
		    Props.List = List or {}
		    if not table.find(Props.List, self.Value) then
		        self:SetValue(self.Value)
		    end
		end
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    if Data.Value and self.Value ~= Data.Value then
		        self:SetValue(Data.Value)
		    end
		end
		
		function Component:Save(Data)
		    Data[Props.Name] = {
		        Value = self.Value
		    }
		end
		
		function Component:SetValue(Value, IsClick: boolean?)
		    self.Value = table.find(Props.List, Value) and Value or Props.List[1] or "None"
		    Title.Text = `         {Props.Name} - {self.Value}`
		
		    if DropdownChildren then
		        Arrow.Rotation = 90
		        DropdownChildren:Destroy()
		        DropdownChildren = nil
		        Dropdown.Size = UDim2.new(1, 0, 0, 40)
		    end
		
		    vape:QueueSave()
		    Props.Function(self.Value, IsClick)
		end
		
		Button.MouseButton1Click:Connect(function()
		    if not DropdownChildren then
		        Arrow.Rotation = 270
		        Dropdown.Size = UDim2.new(1, 0, 0, 43 + (#Props.List - 1) * 26)
		        DropdownChildren = Instance.new("Frame")
		        DropdownChildren.BackgroundTransparency = 1
		        DropdownChildren.Position = UDim2.fromOffset(0, 27)
		        DropdownChildren.Size = UDim2.new(1, 0, 0, (#Props.List - 1) * 26)
		        DropdownChildren.Parent = Button
		
		        local Index: number = 0
		        for _, v: string in Props.List do
		            if v == Component.Value then continue end
		            local Entry: TextButton = Instance.new("TextButton")
		            Entry.AutoButtonColor = false
		            Entry.BackgroundColor3 = UIPallet.Main
		            Entry.BorderSizePixel = 0
		            Entry.FontFace = UIPallet.Font
		            Entry.Position = UDim2.fromOffset(0, Index * 26)
		            Entry.Size = UDim2.new(1, 0, 0, 26)
		            Entry.Text = `         {v}`
		            Entry.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		            Entry.TextSize = 13
		            Entry.TextTruncate = Enum.TextTruncate.AtEnd
		            Entry.TextXAlignment = Enum.TextXAlignment.Left
		            Entry.Parent = DropdownChildren
		
		            Entry.MouseEnter:Connect(function()
		                Entry.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		                Entry.TextColor3 = UIPallet.Text
		            end)
		
		            Entry.MouseLeave:Connect(function()
		                Entry.BackgroundColor3 = UIPallet.Main
		                Entry.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		            end)
		
		            Entry.MouseButton1Click:Connect(function()
		                Component:SetValue(v, true)
		            end)
		
		            Index += 1
		        end
		    else
		        Component:SetValue(Component.Value, true)
		    end
		end)
		
		Dropdown.MouseEnter:Connect(function()
		    Tween:Tween(Holder, UIPallet.Tween, {
		        BackgroundColor3 = Color.Light(UIPallet.Main, 0.0875)
		    })
		end)
		
		Dropdown.MouseLeave:Connect(function()
		    Tween:Tween(Holder, UIPallet.Tween, {
		        BackgroundColor3 = Color.Light(UIPallet.Main, 0.034)
		    })
		end)
		
		API.Options[Props.Name] = Component
		
		return Component
	end,
	Font = function(Props, Children, API)
		local Fonts: {string} = {
		    Props.Default or "Vape",
		    "Custom"
		}
		
		for _, v: EnumItem in Enum.Font:GetEnumItems() do
		    if not table.find(Fonts, v.Name) then
		        table.insert(Fonts, v.Name)
		    end
		end
		
		local Component = {
		    Value = Fonts[1] == "Vape" and UIPallet.Font or Font.fromEnum(Enum.Font[Fonts[1]])
		}
		local FontDropdown
		local FontBox
		Props.Function = Props.Function or function() end
		
		FontDropdown = Components.Dropdown({
		    Name = Props.Name,
		    List = Fonts,
		    Function = function(Val: string)
		        FontBox.Object.Visible = Val == "Custom" and FontDropdown.Object.Visible
		        if Val == "Vape" then
		            Component.Value = UIPallet.Font
		            Props.Function(Component.Value)
		        elseif Val ~= "Custom" then
		            Component.Value = Font.fromEnum(Enum.Font[Val])
		            Props.Function(Component.Value)
		        else
		            pcall(function()
		                Component.Value = Font.fromId(tonumber(FontBox.Value))
		            end)
		
		            Props.Function(Component.Value)
		        end
		    end,
		    Darker = Props.Darker,
		    Visible = Props.Visible
		}, Children, API)
		Component.Object = FontDropdown.Object
		
		FontBox = Components.TextBox({
		    Name = `{Props.Name} Asset`,
		    Placeholder = "font (rbxasset)",
		    Function = function()
		        if FontDropdown.Value == "Custom" then
		            pcall(function()
		                Component.Value = Font.fromId(tonumber(FontBox.Value))
		            end)
		
		            Props.Function(Component.Value)
		        end
		    end,
		    Visible = false,
		    Darker = true
		}, Children, API)
		
		FontDropdown.Object:GetPropertyChangedSignal("Visible"):Connect(function()
		    FontBox.Object.Visible = FontDropdown.Object.Visible and FontDropdown.Value == "Custom"
		end)
		
		return Component
	end,
	GUI = function(Props, Children, API)
		local Component = {
		    Buttons = {},
		    Type = "MainWindow"
		}
		
		local Window: TextButton = Instance.new("TextButton")
		Window.AutoButtonColor = false
		Window.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.02)
		Window.Name = "GUICategory"
		Window.Position = UDim2.fromOffset(6, 60)
		Window.Text = ""
		Window.Parent = ClickGUI
		Component.Object = Window
		AddBlur(Window)
		AddCorner(Window)
		AddDragHandler(Window)
		local Logo: ImageLabel = Instance.new("ImageLabel")
		Logo.BackgroundTransparency = 1
		Logo.Image = GetVapeAsset("kingvape/assets/new/vapelogomini.png")
		Logo.ImageColor3 = select(3, UIPallet.Main:ToHSV()) > 0.5 and UIPallet.Text or Color3.new(1, 1, 1)
		Logo.Name = "VapeLogo"
		Logo.Position = UDim2.fromOffset(12, 11)
		Logo.Size = UDim2.fromOffset(55, 16)
		Logo.Parent = Window
		local V4Logo: ImageLabel = Instance.new("ImageLabel")
		V4Logo.BackgroundTransparency = 1
		V4Logo.Image = GetVapeAsset("kingvape/assets/new/v4mini.png")
		V4Logo.Name = "V4Logo"
		V4Logo.Position = UDim2.new(1, -1, 0, 0)
		V4Logo.Size = UDim2.fromOffset(23, 16)
		V4Logo.Parent = Logo
		local Children: Frame = Instance.new("Frame")
		Children.BackgroundTransparency = 1
		Children.Position = UDim2.fromOffset(0, 37)
		Children.Size = UDim2.new(1, 0, 1, -33)
		Children.Parent = Window
		local WindowList: UIListLayout = Instance.new("UIListLayout")
		WindowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		WindowList.SortOrder = Enum.SortOrder.LayoutOrder
		WindowList.Parent = Children
		local SettingsButton: TextButton = Instance.new("TextButton")
		SettingsButton.BackgroundTransparency = 1
		SettingsButton.Position = UDim2.new(1, -40, 0, 0)
		SettingsButton.Size = UDim2.fromOffset(40, 40)
		SettingsButton.Text = ""
		SettingsButton.Parent = Window
		AddTooltip(SettingsButton, "Open settings")
		local SettingsIcon: ImageLabel = Instance.new("ImageLabel")
		SettingsIcon.BackgroundTransparency = 1
		SettingsIcon.Image = GetVapeAsset("kingvape/assets/new/settings.png")
		SettingsIcon.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		SettingsIcon.Position = UDim2.fromOffset(15, 12)
		SettingsIcon.Size = UDim2.fromOffset(14, 14)
		SettingsIcon.Parent = SettingsButton
		local Discord: ImageButton = Instance.new("ImageButton")
		Discord.BackgroundTransparency = 1
		Discord.Image = GetVapeAsset("kingvape/assets/new/discord.png")
		Discord.Position = UDim2.new(1, -56, 0, 11)
		Discord.Size = UDim2.fromOffset(16, 16)
		Discord.Parent = Window
		AddTooltip(Discord, "Join discord")
		local Stroke: UIStroke = Instance.new("UIStroke")
		Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		Stroke.Color = Color3.fromRGB(85, 85, 85)
		Stroke.Transparency = 0.8
		Stroke.Parent = Window
		local SettingsPane = Components.SettingsPane({
		    Name = "Settings",
		    Main = true
		}, Window, Component)
		Component.Settings = SettingsPane
		
		function Component:Color(Hue: number, Sat: number, Val: number, IsRainbow: boolean)
		    V4Logo.ImageColor3 = Color3.fromHSV(Hue, Sat, Val)
		
		    for _, Button: any in self.Buttons do
		        if Button.Enabled then
		            Button.Object.TextColor3 = IsRainbow and Color3.fromHSV(vape:Color((Hue - (Button.Index * 0.025)) % 1)) or Color3.fromHSV(Hue, Sat, Val)
		
		            if Button.Icon then
		                Button.Icon.ImageColor3 = Button.Object.TextColor3
		            end
		        end
		    end
		end
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    for Name: string, PaneData: any in Data.Settings do
		        local Pane = vape.Settings[Name]
		        if Pane then
		            Pane:Load(PaneData)
		        end
		    end
		
		    if Data.Position then
		        Window.Position = UDim2.fromOffset(Data.Position.X, Data.Position.Y)
		    end
		end
		
		function Component:Save(Data)
		    Data.Main = {
		        Position = {
		            X = Window.Position.X.Offset,
		            Y = Window.Position.Y.Offset
		        },
		        Settings = {}
		    }
		
		    for Name: string, Pane: any in vape.Settings do
		        Pane:Save(Data.Main.Settings)
		    end
		end
		
		for ComponentName: string, Constructor: (...any) -> ...any in Components do
		    Component[`Create{ComponentName}`] = function(_, Properties)
		        return Constructor(Properties, Children, Component)
		    end
		end
		
		Discord.MouseButton1Click:Connect(function()
		    task.spawn(function()
		        local Body: string = HttpService:JSONEncode({
		            nonce = HttpService:GenerateGUID(false),
		            args = {
		                invite = {code = "VZEQJxMSnG"},
		                code = "VZEQJxMSnG"
		            },
		            cmd = "INVITE_BROWSER"
		        })
		
		        for i: number = 1, 14 do
		            task.spawn(function()
		                pcall(function()
		                    request({
		                        Method = "POST",
		                        Url = `http://127.0.0.1:64{53 + i}/rpc?v=1`,
		                        Headers = {
		                            ["Content-Type"] = "application/json",
		                            Origin = "https://discord.com"
		                        },
		                        Body = Body
		                    })
		                end)
		            end)
		        end
		    end)
		
		    task.spawn(function()
		        if vape.ThreadFix then
		            setthreadidentity(8)
		        end
		
		        Tooltip.Text = "Copied!"
		        setclipboard("https://discord.gg/VZEQJxMSnG")
		    end)
		end)
		
		SettingsButton.MouseEnter:Connect(function()
		    SettingsIcon.ImageColor3 = UIPallet.Text
		end)
		
		SettingsButton.MouseLeave:Connect(function()
		    SettingsIcon.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		end)
		
		SettingsButton.MouseButton1Click:Connect(function()
		    SettingsPane.Object.Visible = true
		end)
		
		WindowList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    Window.Size = UDim2.fromOffset(220, 42 + WindowList.AbsoluteContentSize.Y / Scale.Scale)
		    for _, Button: any in Component.Buttons do
		        if Button.Icon then
		            Button.Object.Text = `{string.rep(" ", 39 * Scale.Scale)}{Button.Name}`
		        end
		    end
		end)
		
		vape.Categories.Main = Component
		
		return Component
	end,
	GUIButton = function(Props, Children, API)
		local Component = {
		    Enabled = false,
		    Index = GetTableSize(API.Buttons),
		    Name = Props.Name
		}
		
		local Button: TextButton = Instance.new("TextButton")
		Button.AutoButtonColor = false
		Button.BackgroundColor3 = UIPallet.Main
		Button.BorderSizePixel = 0
		Button.FontFace = UIPallet.Font
		Button.Name = Props.Name
		Button.Size = UDim2.fromOffset(220, 40)
		Button.Text = `{Props.Icon and string.rep(" ", 39) or Props.Window and string.rep(" ", 17) or string.rep(" ", 10)}{Props.Name}`
		Button.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		Button.TextSize = 14
		Button.TextXAlignment = Enum.TextXAlignment.Left
		Button.Parent = Children
		Component.Object = Button
		
		local Icon: ImageLabel?
		if Props.Icon then
		    Icon = Instance.new("ImageLabel")
		    Icon.BackgroundTransparency = 1
		    Icon.Image = Props.Icon
		    Icon.ImageColor3 = Color.Dark(UIPallet.Text, 0.16)
		    Icon.Position = UDim2.fromOffset(16, 13)
		    Icon.Size = Props.Size
		    Icon.Parent = Button
		    Component.Icon = Icon
		end
		
		if Props.Name == "Profiles" then
		    local Label: TextLabel = Instance.new("TextLabel")
		    Label.AnchorPoint = Vector2.new(1, 0)
		    Label.BackgroundColor3 = Color.Light(UIPallet.Main, 0.04)
		    Label.FontFace = UIPallet.Font
		    Label.Position = UDim2.new(1, -36, 0, 8)
		    Label.Size = UDim2.fromOffset(53, 24)
		    Label.Text = "default"
		    Label.TextColor3 = Color.Dark(UIPallet.Text, 0.29)
		    Label.TextSize = 12
		    Label.Parent = Button
		    AddCorner(Label)
		    vape.ProfileLabel = Label
		end
		
		local Arrow: ImageLabel = Instance.new("ImageLabel")
		Arrow.BackgroundTransparency = 1
		Arrow.Image = GetVapeAsset("kingvape/assets/new/expandarrow.png")
		Arrow.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		Arrow.Name = "Arrow"
		Arrow.Position = UDim2.new(1, -20, 0, 16)
		Arrow.Size = UDim2.fromOffset(4, 8)
		Arrow.Parent = Button
		
		function Component:Destroy()
		    Button:Destroy()
		    Button:ClearAllChildren()
		end
		
		function Component:Toggle()
		    if Props.Window then
		        self.Enabled = not self.Enabled
		        Tween:Tween(Arrow, UIPallet.Tween, {
		            Position = UDim2.new(1, self.Enabled and -14 or -20, 0, 16)
		        })
		
		        Button.TextColor3 = self.Enabled and Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value) or UIPallet.Text
		        if Icon then
		            Icon.ImageColor3 = Button.TextColor3
		        end
		
		        Button.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		        Props.Window.Visible = self.Enabled
		        vape:QueueSave()
		    else
		        Props.Function()
		    end
		end
		
		Button.MouseEnter:Connect(function()
		    if not Component.Enabled then
		        Button.TextColor3 = UIPallet.Text
		        if Icon then
		            Icon.ImageColor3 = UIPallet.Text
		        end
		
		        Button.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		    end
		end)
		
		Button.MouseLeave:Connect(function()
		    if not Component.Enabled then
		        Button.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		        if Icon then
		            Icon.ImageColor3 = Color.Dark(UIPallet.Text, 0.16)
		        end
		
		        Button.BackgroundColor3 = UIPallet.Main
		    end
		end)
		
		Button.MouseButton1Click:Connect(function()
		    Component:Toggle()
		end)
		
		API.Buttons[Props.Name] = Component
		
		return Component
	end,
	GUISlider = function(Props, Children, API)
		local Component = {
		    CustomColor = false,
		    Hue = 0.46,
		    Notch = 4,
		    Rainbow = false,
		    Sat = 0.96,
		    Type = "GUISlider",
		    Value = 0.52
		}
		local Colors: {Color3} = {
		    Color3.fromRGB(250, 50, 56),
		    Color3.fromRGB(242, 99, 33),
		    Color3.fromRGB(252, 179, 22),
		    Color3.fromRGB(5, 133, 104),
		    Color3.fromRGB(47, 122, 229),
		    Color3.fromRGB(126, 84, 217),
		    Color3.fromRGB(232, 96, 152)
		}
		local ColorPositions: {number} = {
		    4,
		    33,
		    62,
		    90,
		    119,
		    148,
		    177
		}
		
		local function CreateSlider(Name: string, GradientColor: ColorSequence)
		    local Slider: TextButton = Instance.new("TextButton")
		    Slider.Name = `{Props.Name}Slider{Name}`
		    Slider.Size = UDim2.fromOffset(220, 50)
		    Slider.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.02)
		    Slider.BorderSizePixel = 0
		    Slider.AutoButtonColor = false
		    Slider.Visible = false
		    Slider.Text = ""
		    Slider.Parent = Children
		    local Title: TextLabel = Instance.new("TextLabel")
		    Title.BackgroundTransparency = 1
		    Title.FontFace = UIPallet.Font
		    Title.Position = UDim2.fromOffset(10, 2)
		    Title.Size = UDim2.fromOffset(60, 30)
		    Title.Text = Name
		    Title.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		    Title.TextSize = 11
		    Title.TextXAlignment = Enum.TextXAlignment.Left
		    Title.Parent = Slider
		    local Holder: Frame = Instance.new("Frame")
		    Holder.BackgroundColor3 = Color3.new(1, 1, 1)
		    Holder.BorderSizePixel = 0
		    Holder.Name = "Holder"
		    Holder.Position = UDim2.fromOffset(10, 37)
		    Holder.Size = UDim2.new(1, -20, 0, 2)
		    Holder.Parent = Slider
		    local Gradient: UIGradient = Instance.new("UIGradient")
		    Gradient.Color = GradientColor
		    Gradient.Parent = Holder
		    local Fill: Frame = Instance.new("Frame")
		    Fill.BackgroundTransparency = 1
		    Fill.Name = "Fill"
		    Fill.Size = UDim2.fromScale(math.clamp(1, 0.04, 0.96), 1)
		    Fill.Parent = Holder
		    local KnobHolder: Frame = Instance.new("Frame")
		    KnobHolder.AnchorPoint = Vector2.new(0.5, 0.5)
		    KnobHolder.BackgroundColor3 = Slider.BackgroundColor3
		    KnobHolder.BorderSizePixel = 0
		    KnobHolder.Position = UDim2.fromScale(1, 0.5)
		    KnobHolder.Size = UDim2.fromOffset(24, 4)
		    KnobHolder.Parent = Fill
		    local Knob: Frame = Instance.new("Frame")
		    Knob.AnchorPoint = Vector2.new(0.5, 0.5)
		    Knob.BackgroundColor3 = UIPallet.Text
		    Knob.Position = UDim2.fromScale(0.5, 0.5)
		    Knob.Size = UDim2.fromOffset(14, 14)
		    Knob.Parent = KnobHolder
		    AddCorner(Knob, UDim.new(1, 0))
		
		    if Name == "Custom color" then
		        local Reset: TextButton = Instance.new("TextButton")
		        Reset.BackgroundTransparency = 1
		        Reset.FontFace = UIPallet.Font
		        Reset.Position = UDim2.new(1, -52, 0, 5)
		        Reset.Size = UDim2.fromOffset(45, 20)
		        Reset.Text = "RESET"
		        Reset.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		        Reset.TextSize = 11
		        Reset.Parent = Slider
		
		        Reset.MouseButton1Click:Connect(function()
		            Component:SetValue(nil, nil, nil, 4)
		        end)
		    end
		
		    Slider.InputBegan:Connect(function(Input: InputObject)
		        if vape.ThreadFix then
		            setthreadidentity(8)
		        end
		
		        if
		            (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch)
		            and (Input.Position.Y - Slider.AbsolutePosition.Y) > (20 * Scale.Scale)
		        then
		            local ReleaseConnection
		            local MoveConnection: RBXScriptConnection = UserInputService.InputChanged:Connect(function(NewInput: InputObject)
		                if vape.ThreadFix then
		                    setthreadidentity(8)
		                end
		
		                if NewInput.UserInputType == (Input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
		                    local Value: number = math.clamp((NewInput.Position.X - Holder.AbsolutePosition.X) / Holder.AbsoluteSize.X, 0, 1)
		                    Component:SetValue(
		                        Name == "Custom color" and Value or nil,
		                        Name == "Saturation" and Value or nil,
		                        Name == "Vibrance" and Value or nil,
		                        Name == "Opacity" and Value or nil
		                    )
		                end
		            end)
		
		            ReleaseConnection = Input.Changed:Connect(function()
		                if Input.UserInputState == Enum.UserInputState.End then
		                    MoveConnection:Disconnect()
		                    ReleaseConnection:Disconnect()
		                end
		            end)
		        end
		    end)
		
		    Slider.MouseEnter:Connect(function()
		        Tween:Tween(Knob, UIPallet.Tween, {
		            Size = UDim2.fromOffset(16, 16)
		        })
		    end)
		
		    Slider.MouseLeave:Connect(function()
		        Tween:Tween(Knob, UIPallet.Tween, {
		            Size = UDim2.fromOffset(14, 14)
		        })
		    end)
		
		    return Slider
		end
		
		local Slider: TextButton = Instance.new("TextButton")
		Slider.AutoButtonColor = false
		Slider.BackgroundTransparency = 1
		Slider.Name = `{Props.Name}Slider`
		Slider.Size = UDim2.fromOffset(220, 50)
		Slider.Text = ""
		Slider.Parent = Children
		Component.Object = Slider
		local Title: TextLabel = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.FontFace = UIPallet.Font
		Title.Name = "Title"
		Title.Position = UDim2.fromOffset(10, 2)
		Title.Size = UDim2.fromOffset(60, 30)
		Title.Text = Props.Name
		Title.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		Title.TextSize = 11
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Parent = Slider
		local Holder: Frame = Instance.new("Frame")
		Holder.BackgroundTransparency = 1
		Holder.BorderSizePixel = 0
		Holder.Name = "Slider"
		Holder.Position = UDim2.fromOffset(10, 37)
		Holder.Size = UDim2.fromOffset(200, 2)
		Holder.Parent = Slider
		local ColorOffset: number = 0
		for i: number, ColorValue: Color3 in Colors do
		    local ColorFrame: Frame = Instance.new("Frame")
		    ColorFrame.BackgroundColor3 = ColorValue
		    ColorFrame.BorderSizePixel = 0
		    ColorFrame.Position = UDim2.fromOffset(ColorOffset, 0)
		    ColorFrame.Size = UDim2.fromOffset(27 + (((i + 1) % 2) == 0 and 1 or 0), 2)
		    ColorFrame.Parent = Holder
		    ColorOffset += (ColorFrame.Size.X.Offset + 1)
		end
		local Preview: ImageButton = Instance.new("ImageButton")
		Preview.BackgroundTransparency = 1
		Preview.Image = GetVapeAsset("kingvape/assets/new/colorpreview.png")
		Preview.ImageColor3 = Color3.fromHSV(Component.Hue, Component.Sat, Component.Value)
		Preview.Position = UDim2.new(1, -22, 0, 10)
		Preview.Size = UDim2.fromOffset(12, 12)
		Preview.Parent = Slider
		local CustomBox: TextBox = Instance.new("TextBox")
		CustomBox.BackgroundTransparency = 1
		CustomBox.FontFace = UIPallet.Font
		CustomBox.Position = UDim2.new(1, -69, 0, 9)
		CustomBox.Size = UDim2.fromOffset(60, 15)
		CustomBox.Text = ""
		CustomBox.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		CustomBox.TextSize = 11
		CustomBox.TextXAlignment = Enum.TextXAlignment.Right
		CustomBox.Visible = false
		CustomBox.Parent = Slider
		local Expand: TextButton = Instance.new("TextButton")
		Expand.BackgroundTransparency = 1
		Expand.Position = UDim2.new(0, GetFontBounds(Title.Text, Title.TextSize, Title.FontFace).X + 11, 0, 7)
		Expand.Size = UDim2.fromOffset(17, 13)
		Expand.Text = ""
		Expand.Parent = Slider
		local Icon: ImageLabel = Instance.new("ImageLabel")
		Icon.BackgroundTransparency = 1
		Icon.Image = GetVapeAsset("kingvape/assets/new/downexpandslider.png")
		Icon.ImageColor3 = Color.Dark(UIPallet.Text, 0.43)
		Icon.Position = UDim2.fromOffset(4, 4)
		Icon.Size = UDim2.fromOffset(10, 5)
		Icon.Parent = Expand
		local Rainbow: TextButton = Instance.new("TextButton")
		Rainbow.BackgroundTransparency = 1
		Rainbow.Position = UDim2.new(1, -42, 0, 10)
		Rainbow.Size = UDim2.fromOffset(12, 12)
		Rainbow.Text = ""
		Rainbow.Parent = Slider
		local Ring1: ImageLabel = Instance.new("ImageLabel")
		Ring1.BackgroundTransparency = 1
		Ring1.Image = GetVapeAsset("kingvape/assets/new/rainbow_1.png")
		Ring1.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		Ring1.Size = UDim2.fromOffset(12, 12)
		Ring1.Parent = Rainbow
		local Ring2: ImageLabel = Instance.fromExisting(Ring1)
		Ring2.Image = GetVapeAsset("kingvape/assets/new/rainbow_2.png")
		Ring2.Parent = Rainbow
		local Ring3: ImageLabel = Instance.fromExisting(Ring1)
		Ring3.Image = GetVapeAsset("kingvape/assets/new/rainbow_3.png")
		Ring3.Parent = Rainbow
		local Ring4: ImageLabel = Instance.fromExisting(Ring1)
		Ring4.Image = GetVapeAsset("kingvape/assets/new/rainbow_4.png")
		Ring4.Parent = Rainbow
		local Knob: ImageLabel = Instance.new("ImageLabel")
		Knob.BackgroundTransparency = 1
		Knob.Image = GetVapeAsset("kingvape/assets/new/theme.png")
		Knob.ImageColor3 = Colors[4]
		Knob.Name = "Knob"
		Knob.Position = UDim2.fromOffset(ColorPositions[4] - 3, -5)
		Knob.Size = UDim2.fromOffset(26, 12)
		Knob.Parent = Holder
		Props.Function = Props.Function or function() end
		local RainbowTable: {ColorSequenceKeypoint} = {}
		for Hue: number = 0, 1, 0.1 do
		    table.insert(RainbowTable, ColorSequenceKeypoint.new(Hue, Color3.fromHSV(Hue, 1, 1)))
		end
		
		local CustomColorSlider: TextButton = CreateSlider("Custom color", ColorSequence.new(RainbowTable))
		local SaturationSlider: TextButton = CreateSlider("Saturation", ColorSequence.new({
		    ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, Component.Value)),
		    ColorSequenceKeypoint.new(1, Color3.fromHSV(Component.Hue, 1, Component.Value))
		}))
		
		local VibranceSlider: TextButton = CreateSlider("Vibrance", ColorSequence.new({
		    ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
		    ColorSequenceKeypoint.new(1, Color3.fromHSV(Component.Hue, Component.Sat, 1))
		}))
		
		local NormalKnob: string = GetVapeAsset("kingvape/assets/new/theme.png")
		local RainbowKnob: string = GetVapeAsset("kingvape/assets/new/customtheme.png")
		local RainbowThread: thread?
		local CurrentNotch: number?
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    if Data.Rainbow then
		        self:Toggle()
		    end
		
		    if self.Rainbow or Data.CustomColor then
		        self:SetValue(Data.Hue, Data.Sat, Data.Value)
		    else
		        self:SetValue(nil, nil, nil, Data.Notch)
		    end
		end
		
		function Component:Save(Data)
		    Data[Props.Name] = {
		        Hue = self.Hue,
		        Sat = self.Sat,
		        Value = self.Value,
		        Notch = self.Notch,
		        CustomColor = self.CustomColor,
		        Rainbow = self.Rainbow
		    }
		end
		
		function Component:SetValue(Hue: number?, Sat: number?, Val: number?, Notch: number?)
		    if Notch then
		        if self.Rainbow then
		            self:Toggle()
		        end
		
		        self.CustomColor = false
		        Hue, Sat, Val = Colors[Notch]:ToHSV()
		    else
		        self.CustomColor = true
		    end
		
		    self.Hue = Hue or self.Hue
		    self.Sat = Sat or self.Sat
		    self.Value = Val or self.Value
		    self.Notch = Notch
		    Preview.ImageColor3 = Color3.fromHSV(self.Hue, self.Sat, self.Value)
		
		    SaturationSlider.Holder.UIGradient.Color = ColorSequence.new({
		        ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, self.Value)),
		        ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, 1, self.Value))
		    })
		
		    VibranceSlider.Holder.UIGradient.Color = ColorSequence.new({
		        ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 0, 0)),
		        ColorSequenceKeypoint.new(1, Color3.fromHSV(self.Hue, self.Sat, 1))
		    })
		
		    local NewNotch: number? = (self.Rainbow or self.CustomColor) and 4 or Notch or CurrentNotch
		    if self.Rainbow or self.CustomColor then
		        Knob.Image = RainbowKnob
		        Knob.ImageColor3 = Color3.new(1, 1, 1)
		
		        if NewNotch ~= CurrentNotch then
		            Tween:Tween(Knob, UIPallet.Tween, {
		                Position = UDim2.fromOffset(ColorPositions[4] - 3, -5)
		            })
		        end
		    else
		        Knob.Image = NormalKnob
		        Knob.ImageColor3 = Color3.fromHSV(self.Hue, self.Sat, self.Value)
		
		        if NewNotch ~= CurrentNotch then
		            Tween:Tween(Knob, UIPallet.Tween, {
		                Position = UDim2.fromOffset(ColorPositions[Notch or 4] - 3, -5)
		            })
		        end
		    end
		
		    CurrentNotch = NewNotch
		    if self.Rainbow then
		        if Hue then
		            CustomColorSlider.Holder.Fill.Size = UDim2.fromScale(math.clamp(self.Hue, 0.04, 0.96), 1)
		        end
		
		        if Sat then
		            SaturationSlider.Holder.Fill.Size = UDim2.fromScale(math.clamp(self.Sat, 0.04, 0.96), 1)
		        end
		
		        if Val then
		            VibranceSlider.Holder.Fill.Size = UDim2.fromScale(math.clamp(self.Value, 0.04, 0.96), 1)
		        end
		    else
		        if Hue then
		            Tween:Tween(CustomColorSlider.Holder.Fill, UIPallet.Tween, {
		                Size = UDim2.fromScale(math.clamp(self.Hue, 0.04, 0.96), 1)
		            })
		        end
		
		        if Sat then
		            Tween:Tween(SaturationSlider.Holder.Fill, UIPallet.Tween, {
		                Size = UDim2.fromScale(math.clamp(self.Sat, 0.04, 0.96), 1)
		            })
		        end
		
		        if Val then
		            Tween:Tween(VibranceSlider.Holder.Fill, UIPallet.Tween, {
		                Size = UDim2.fromScale(math.clamp(self.Value, 0.04, 0.96), 1)
		            })
		        end
		    end
		
		    if not self.Rainbow then
		        vape:QueueSave()
		    end
		
		    Props.Function(self.Hue, self.Sat, self.Value)
		end
		
		function Component:Toggle()
		    self.Rainbow = not self.Rainbow
		    if RainbowThread then
		        task.cancel(RainbowThread)
		    end
		
		    if self.Rainbow then
		        Knob.Image = RainbowKnob
		        table.insert(vape.RainbowSliders, self)
		
		        Ring1.ImageColor3 = Color3.fromRGB(5, 127, 100)
		        RainbowThread = task.delay(0.1, function()
		            if vape.ThreadFix then
		                setthreadidentity(8)
		            end
		
		            Ring2.ImageColor3 = Color3.fromRGB(228, 125, 43)
		            RainbowThread = task.delay(0.1, function()
		                if vape.ThreadFix then
		                    setthreadidentity(8)
		                end
		
		                Ring3.ImageColor3 = Color3.fromRGB(225, 46, 52)
		                RainbowThread = nil
		            end)
		        end)
		    else
		        self:SetValue(nil, nil, nil, 4)
		        Knob.Image = NormalKnob
		        local Index: number? = table.find(vape.RainbowSliders, self)
		        if Index then
		            table.remove(vape.RainbowSliders, Index)
		        end
		
		        Ring3.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		        RainbowThread = task.delay(0.1, function()
		            if vape.ThreadFix then
		                setthreadidentity(8)
		            end
		
		            Ring2.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		            RainbowThread = task.delay(0.1, function()
		                if vape.ThreadFix then
		                    setthreadidentity(8)
		                end
		
		                Ring1.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		                RainbowThread = nil
		            end)
		        end)
		    end
		
		    vape:QueueSave()
		end
		
		Expand.MouseEnter:Connect(function()
		    Icon.ImageColor3 = Color.Dark(UIPallet.Text, 0.16)
		end)
		
		Expand.MouseLeave:Connect(function()
		    Icon.ImageColor3 = Color.Dark(UIPallet.Text, 0.43)
		end)
		
		Expand.MouseButton1Click:Connect(function()
		    CustomColorSlider.Visible = not CustomColorSlider.Visible
		    SaturationSlider.Visible = CustomColorSlider.Visible
		    VibranceSlider.Visible = SaturationSlider.Visible
		    Icon.Rotation = SaturationSlider.Visible and 180 or 0
		end)
		
		Preview.MouseButton1Click:Connect(function()
		    Preview.Visible = false
		    CustomBox.Visible = true
		    CustomBox:CaptureFocus()
		    local CurrentColor: Color3 = Color3.fromHSV(Component.Hue, Component.Sat, Component.Value)
		    CustomBox.Text = `{math.round(CurrentColor.R * 255)}, {math.round(CurrentColor.G * 255)}, {math.round(CurrentColor.B * 255)}`
		end)
		
		Slider.InputBegan:Connect(function(Input: InputObject)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    if
		        (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch)
		        and (Input.Position.Y - Slider.AbsolutePosition.Y) > (20 * Scale.Scale)
		    then
		        local ReleaseConnection
		        local MoveConnection: RBXScriptConnection = UserInputService.InputChanged:Connect(function(NewInput: InputObject)
		            if vape.ThreadFix then
		                setthreadidentity(8)
		            end
		
		            if NewInput.UserInputType == (Input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
		                Component:SetValue(nil, nil, nil, math.clamp(math.round((NewInput.Position.X - Holder.AbsolutePosition.X) / Scale.Scale / 27), 1, 7))
		            end
		        end)
		
		        ReleaseConnection = Input.Changed:Connect(function()
		            if Input.UserInputState == Enum.UserInputState.End then
		                MoveConnection:Disconnect()
		                ReleaseConnection:Disconnect()
		            end
		        end)
		
		        Component:SetValue(nil, nil, nil, math.clamp(math.round((Input.Position.X - Holder.AbsolutePosition.X) / Scale.Scale / 27), 1, 7))
		    end
		end)
		
		Rainbow.MouseButton1Click:Connect(function()
		    Component:Toggle()
		end)
		
		CustomBox.FocusLost:Connect(function(Enter: boolean)
		    Preview.Visible = true
		    CustomBox.Visible = false
		
		    if Enter then
		        local Success, Parsed = pcall(function()
		            local Commas: {string} = CustomBox.Text:split(",")
		            return tonumber(Commas[1]) and Color3.fromRGB(tonumber(Commas[1]), tonumber(Commas[2]), tonumber(Commas[3])) or Color3.fromHex(CustomBox.Text)
		        end)
		
		        if Success then
		            if Component.Rainbow then
		                Component:Toggle()
		            end
		
		            Component:SetValue(Parsed:ToHSV())
		        end
		    end
		end)
		
		API.Options[Props.Name] = Component
		
		return Component
	end,
	ImageToggle = function(Props, Children, API)
		local Component = {
		    Enabled = false,
		    Index = GetTableSize(API.Options),
		    Type = "ImageToggle"
		}
		
		local IsHover: boolean = false
		local Toggle: TextButton = Instance.new("TextButton")
		Toggle.AutoButtonColor = false
		Toggle.BackgroundColor3 = Color.Dark(Children.BackgroundColor3, Props.Darker and 0.02 or 0)
		Toggle.BorderSizePixel = 0
		Toggle.FontFace = UIPallet.Font
		Toggle.Size = UDim2.new(1, 0, 0, 40)
		Toggle.Text = `{string.rep(" ", 33 * Scale.Scale)}{Props.Name}`
		Toggle.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		Toggle.TextSize = 14
		Toggle.TextXAlignment = Enum.TextXAlignment.Left
		Toggle.Visible = Props.Visible == nil or Props.Visible
		Toggle.Parent = Children
		Component.Object = Toggle
		local Icon: ImageLabel = Instance.new("ImageLabel")
		Icon.BackgroundTransparency = 1
		Icon.Image = Props.Icon
		Icon.ImageColor3 = UIPallet.Text
		Icon.Name = "Icon"
		Icon.Position = Props.Position
		Icon.Size = Props.Size
		Icon.Parent = Toggle
		local Holder: Frame = Instance.new("Frame")
		Holder.BackgroundColor3 = Color.Light(UIPallet.Main, 0.14)
		Holder.Name = "Knob"
		Holder.Position = UDim2.new(1, -30, 0, 14)
		Holder.Size = UDim2.fromOffset(22, 12)
		Holder.Parent = Toggle
		AddCorner(Holder, UDim.new(1, 0))
		local Knob: Frame = Instance.new("Frame")
		Knob.BackgroundColor3 = UIPallet.Main
		Knob.Position = UDim2.fromOffset(2, 2)
		Knob.Size = UDim2.fromOffset(8, 8)
		Knob.Parent = Holder
		AddCorner(Knob, UDim.new(1, 0))
		Props.Function = Props.Function or function() end
		
		function Component:Color(Hue: number, Sat: number, Val: number, IsRainbow: boolean)
		    if self.Enabled then
		        Tween:Cancel(Holder)
		        Holder.BackgroundColor3 = IsRainbow and Color3.fromHSV(vape:Color((Hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(Hue, Sat, Val)
		    end
		end
		
		function Component:Toggle()
		    local IsRainbow: boolean = vape.GUIColor.Rainbow and vape.RainbowMode.Value ~= "Retro"
		    self.Enabled = not self.Enabled
		
		    Tween:Tween(Holder, UIPallet.Tween, {
		        BackgroundColor3 = self.Enabled and (IsRainbow and Color3.fromHSV(vape:Color((vape.GUIColor.Hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)) or (IsHover and Color.Light(UIPallet.Main, 0.37) or Color.Light(UIPallet.Main, 0.14))
		    })
		
		    Tween:Tween(Knob, UIPallet.Tween, {
		        Position = UDim2.fromOffset(self.Enabled and 12 or 2, 2)
		    })
		
		    vape:QueueSave()
		    Props.Function(self.Enabled)
		end
		
		Scale:GetPropertyChangedSignal("Scale"):Connect(function()
		    Toggle.Text = `{string.rep(" ", 33 * Scale.Scale)}{Props.Name}`
		end)
		
		Toggle.MouseEnter:Connect(function()
		    IsHover = true
		
		    if not Component.Enabled then
		        Tween:Tween(Holder, UIPallet.Tween, {
		            BackgroundColor3 = Color.Light(UIPallet.Main, 0.37)
		        })
		    end
		end)
		
		Toggle.MouseLeave:Connect(function()
		    IsHover = false
		
		    if not Component.Enabled then
		        Tween:Tween(Holder, UIPallet.Tween, {
		            BackgroundColor3 = Color.Light(UIPallet.Main, 0.14)
		        })
		    end
		end)
		
		Toggle.MouseButton1Click:Connect(function()
		    Component:Toggle()
		end)
		
		if Props.Default then
		    Component:Toggle()
		end
		
		API.Options[Props.Name] = Component
		
		return Component
	end,
	LegitModule = function(Props, Children, API)
		vape:Remove(Props.Name)
		local Component = {
		    Category = Props.Category or "Game",
		    ConfigName = Props.ConfigName or Props.Name,
		    Enabled = false,
		    Favorited = false,
		    Legit = true,
		    Name = Props.Name,
		    Options = {},
		    Type = "LegitModule"
		}
		local Dashes: {Frame} = {}
		local DashHolder: Frame?
		local Editor: Frame?
		local EditorPane: Frame?
		local Connections: {RBXScriptConnection} = {}
		local ObjectStroke: UIStroke?
		
		local function AddDash(X: number, Y: number, Width: number, Height: number)
		    local Dash: Frame? = table.remove(Dashes)
		    if not Dash then
		        Dash = Instance.new("Frame")
		        Dash.BackgroundColor3 = VapeColors.AccentHover
		        Dash.BorderSizePixel = 0
		    end
		
		    Dash.Position = UDim2.fromOffset(X, Y)
		    Dash.Size = UDim2.fromOffset(Width, Height)
		    Dash.Parent = DashHolder
		end
		
		local function RefreshDashes()
		    local Size: UDim2 = Component.Children.Size
		    local Right: number = Size.X.Offset + 38
		    local Bottom: number = math.max(52, Size.Y.Offset) + 14
		
		    for _, v: Frame in DashHolder:GetChildren() do
		        v.Parent = nil
		        table.insert(Dashes, v)
		    end
		
		    for X: number = 0, Right, 4 do
		        AddDash(X, 0, 2, 2)
		        AddDash(X, Bottom, 2, 2)
		    end
		
		    for Y: number = 4, Bottom - 4, 4 do
		        AddDash(0, Y, 2, 2)
		        AddDash(Right, Y, 2, 2)
		    end
		end
		
		local Button: TextButton = Instance.new("TextButton")
		Button.AutoButtonColor = false
		Button.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		Button.Name = Props.Name
		Button.Text = ""
		Button.Parent = Children
		Component.Object = Button
		AddTooltip(Button, Props.Tooltip, nil, function()
		    return vape.LegitVisible
		end)
		AddCorner(Button)
		local Icon: ImageLabel = Instance.new("ImageLabel")
		Icon.BackgroundTransparency = 1
		Icon.Image = Props.Icon or ""
		Icon.ImageColor3 = VapeColors.Icon
		Icon.Name = "Icon"
		Icon.Position = UDim2.fromOffset(18, 12)
		Icon.Size = UDim2.fromOffset(16, 16)
		Icon.Parent = Button
		local Title: TextLabel = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.FontFace = UIPallet.Font
		Title.Position = UDim2.fromOffset(16, 81)
		Title.Size = UDim2.new(1, -16, 0, 20)
		Title.Text = Props.Name
		Title.TextColor3 = Color.Dark(UIPallet.Text, 0.31)
		Title.TextSize = 13
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Parent = Button
		local Holder: Frame = Instance.new("Frame")
		Holder.BackgroundColor3 = Color.Light(UIPallet.Main, 0.14)
		Holder.Position = UDim2.new(1, -57, 0, 15)
		Holder.Size = UDim2.fromOffset(22, 12)
		Holder.Parent = Button
		AddCorner(Holder, UDim.new(1, 0))
		local Knob: Frame = Instance.new("Frame")
		Knob.BackgroundColor3 = UIPallet.Main
		Knob.Position = UDim2.fromOffset(2, 2)
		Knob.Size = UDim2.fromOffset(8, 8)
		Knob.Parent = Holder
		AddCorner(Knob, UDim.new(1, 0))
		local DotsButton: TextButton = Instance.new("TextButton")
		DotsButton.BackgroundTransparency = 1
		DotsButton.Name = "Dots"
		DotsButton.Position = UDim2.new(1, -27, 0, 9)
		DotsButton.Size = UDim2.fromOffset(14, 24)
		DotsButton.Text = ""
		DotsButton.Parent = Button
		local Dots: ImageLabel = Instance.new("ImageLabel")
		Dots.BackgroundTransparency = 1
		Dots.Image = GetVapeAsset("kingvape/assets/new/overlaydots.png")
		Dots.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		Dots.Name = "Dots"
		Dots.Position = UDim2.fromOffset(6, 6)
		Dots.Size = UDim2.fromOffset(2, 12)
		Dots.Parent = DotsButton
		local Shadow: TextButton = Instance.new("TextButton")
		Shadow.Name = "Shadow"
		Shadow.Size = UDim2.new(1, 0, 1, -5)
		Shadow.BackgroundColor3 = Color3.new()
		Shadow.BackgroundTransparency = 1
		Shadow.AutoButtonColor = false
		Shadow.ClipsDescendants = true
		Shadow.Visible = false
		Shadow.Text = ""
		Shadow.Parent = API.Window
		AddCorner(Shadow)
		local SettingsPane: TextButton = Instance.new("TextButton")
		SettingsPane.Size = UDim2.new(0, 220, 1, 0)
		SettingsPane.Position = UDim2.fromScale(1, 0)
		SettingsPane.BackgroundColor3 = UIPallet.Main
		SettingsPane.AutoButtonColor = false
		SettingsPane.Text = ""
		SettingsPane.Parent = Shadow
		local SettingsTitle: TextLabel = Instance.new("TextLabel")
		SettingsTitle.Name = "Title"
		SettingsTitle.Size = UDim2.new(1, -36, 0, 20)
		SettingsTitle.Position = UDim2.fromOffset(36, 12)
		SettingsTitle.BackgroundTransparency = 1
		SettingsTitle.Text = Props.Name
		SettingsTitle.TextXAlignment = Enum.TextXAlignment.Left
		SettingsTitle.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		SettingsTitle.TextSize = 13
		SettingsTitle.FontFace = UIPallet.Font
		SettingsTitle.Parent = SettingsPane
		local Back: ImageButton = Instance.new("ImageButton")
		Back.Name = "Back"
		Back.Size = UDim2.fromOffset(16, 16)
		Back.Position = UDim2.fromOffset(11, 13)
		Back.BackgroundTransparency = 1
		Back.Image = GetVapeAsset("kingvape/assets/new/back.png")
		Back.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		Back.Parent = SettingsPane
		AddCorner(SettingsPane)
		local Favorite: TextButton = Instance.new("TextButton")
		Favorite.AutoButtonColor = false
		Favorite.BackgroundTransparency = 1
		Favorite.Name = "Favorite"
		Favorite.Position = UDim2.fromOffset(186, 8)
		Favorite.Size = UDim2.fromOffset(22, 26)
		Favorite.Text = ""
		Favorite.Parent = SettingsPane
		AddTooltip(Favorite, "Add module to favorites")
		local FavoriteIcon: ImageLabel = Instance.new("ImageLabel")
		FavoriteIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		FavoriteIcon.BackgroundTransparency = 1
		FavoriteIcon.Image = GetVapeAsset("kingvape/assets/new/star.png")
		FavoriteIcon.ImageColor3 = VapeColors.Icon
		FavoriteIcon.Name = "Icon"
		FavoriteIcon.Position = UDim2.fromScale(0.5, 0.5)
		FavoriteIcon.Size = UDim2.fromOffset(16, 15)
		FavoriteIcon.Parent = Favorite
		local SettingsChildren: ScrollingFrame = Instance.new("ScrollingFrame")
		SettingsChildren.BackgroundColor3 = UIPallet.Main
		SettingsChildren.BorderSizePixel = 0
		SettingsChildren.CanvasSize = UDim2.new()
		SettingsChildren.Name = "Children"
		SettingsChildren.Position = UDim2.fromOffset(0, 41)
		SettingsChildren.ScrollBarThickness = 2
		SettingsChildren.ScrollBarImageTransparency = 0.75
		SettingsChildren.Size = UDim2.new(1, 0, 1, -45)
		SettingsChildren.Parent = SettingsPane
		local WindowList: UIListLayout = Instance.new("UIListLayout")
		WindowList.SortOrder = Enum.SortOrder.LayoutOrder
		WindowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		WindowList.Parent = SettingsChildren
		if Props.Size then
		    local ModuleChildren: Frame = Instance.new("Frame")
		    ModuleChildren.BackgroundTransparency = 1
		    ModuleChildren.Name = Props.Name
		    ModuleChildren.Size = Props.Size
		    ModuleChildren.Visible = false
		    ModuleChildren.Parent = ScaledGUI
		    Component.Children = ModuleChildren
		    AddDragHandler(ModuleChildren, API.Window)
		    AddGlass(ModuleChildren)
		    ObjectStroke = Instance.new("UIStroke")
		    ObjectStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		    ObjectStroke.Color = VapeColors.AccentHover
		    ObjectStroke.Thickness = 0
		    ObjectStroke.Transparency = 0.412
		    ObjectStroke.Parent = ModuleChildren
		    Editor = Instance.new("Frame")
		    Editor.BackgroundTransparency = 1
		    Editor.Name = "Editor"
		    Editor.Size = UDim2.fromScale(1, 1)
		    Editor.Visible = false
		    Editor.Parent = ModuleChildren
		    DashHolder = Instance.new("Frame")
		    DashHolder.BackgroundTransparency = 1
		    DashHolder.Name = "Dashes"
		    DashHolder.Position = UDim2.fromOffset(-4, -7)
		    DashHolder.Parent = Editor
		    local EditorLabel: TextLabel = Instance.new("TextLabel")
		    EditorLabel.BackgroundTransparency = 1
		    EditorLabel.FontFace = UIPallet.Font
		    EditorLabel.Name = "Label"
		    EditorLabel.Position = UDim2.fromOffset(0, -24)
		    EditorLabel.Size = UDim2.fromOffset(220, 20)
		    EditorLabel.Text = Props.Name
		    EditorLabel.TextColor3 = Color3.new(1, 1, 1)
		    EditorLabel.TextSize = 14
		    EditorLabel.TextXAlignment = Enum.TextXAlignment.Left
		    EditorLabel.Parent = Editor
		    local EditorShadow: TextLabel = EditorLabel:Clone()
		    EditorShadow.Name = "Shadow"
		    EditorShadow.Position = UDim2.fromOffset(1, -23)
		    EditorShadow.TextColor3 = Color3.new()
		    EditorShadow.TextTransparency = 0.608
		    EditorShadow.ZIndex = 0
		    EditorShadow.Parent = Editor
		    local CloseButton: TextButton = Instance.new("TextButton")
		    CloseButton.AutoButtonColor = false
		    CloseButton.BackgroundColor3 = VapeColors.Panel
		    CloseButton.BackgroundTransparency = 0.45
		    CloseButton.Name = "Close"
		    CloseButton.Position = UDim2.new(1, 4, 0, -1)
		    CloseButton.Size = UDim2.fromOffset(26, 26)
		    CloseButton.Text = ""
		    CloseButton.Parent = Editor
		    AddCorner(CloseButton, UDim.new(0, 3))
		    AddTooltip(CloseButton, `Disable {Props.Name}`, nil, function()
		        return Editor.Visible
		    end)
		    local CloseStroke: UIStroke = Instance.new("UIStroke")
		    CloseStroke.Color = VapeColors.Outline
		    CloseStroke.Parent = CloseButton
		    local CloseIcon: ImageLabel = Instance.new("ImageLabel")
		    CloseIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		    CloseIcon.BackgroundTransparency = 1
		    CloseIcon.Image = GetVapeAsset("kingvape/assets/new/closetiny.png")
		    CloseIcon.ImageColor3 = VapeColors.Secondary
		    CloseIcon.Name = "Icon"
		    CloseIcon.Position = UDim2.fromScale(0.5, 0.5)
		    CloseIcon.Size = UDim2.fromOffset(16, 16)
		    CloseIcon.Parent = CloseButton
		    local SettingsButton: TextButton = CloseButton:Clone()
		    SettingsButton.BackgroundColor3 = UIPallet.Main
		    SettingsButton.Name = "Settings"
		    SettingsButton.Position = UDim2.new(1, 4, 0, 30)
		    SettingsButton.Parent = Editor
		    AddTooltip(SettingsButton, `Open {Props.Name} settings`, nil, function()
		        return Editor.Visible or EditorPane.Visible
		    end)
		    local SettingsIcon: ImageLabel = SettingsButton.Icon
		    SettingsIcon.Image = GetVapeAsset("kingvape/assets/new/settingdots.png")
		    SettingsIcon.Size = UDim2.fromOffset(2, 11)
		    EditorPane = Instance.new("Frame")
		    EditorPane.BackgroundColor3 = UIPallet.Main
		    EditorPane.Name = "Settings"
		    EditorPane.Size = UDim2.fromOffset(220, 120)
		    EditorPane.Visible = false
		    EditorPane.Parent = ModuleChildren
		    AddBlur(EditorPane)
		    AddCorner(EditorPane)
		    local EditorDots: ImageLabel = Instance.new("ImageLabel")
		    EditorDots.BackgroundTransparency = 1
		    EditorDots.Image = GetVapeAsset("kingvape/assets/new/settingdots.png")
		    EditorDots.AnchorPoint = Vector2.new(0.5, 0.5)
		    EditorDots.ImageColor3 = VapeColors.Secondary
		    EditorDots.Name = "Dots"
		    EditorDots.Position = UDim2.fromOffset(17, 20)
		    EditorDots.Size = UDim2.fromOffset(2, 11)
		    EditorDots.Parent = EditorPane
		    local EditorTitle: TextLabel = SettingsTitle:Clone()
		    EditorTitle.Parent = EditorPane
		    local EditorClose: ImageButton = Instance.new("ImageButton")
		    EditorClose.BackgroundTransparency = 1
		    EditorClose.Image = GetVapeAsset("kingvape/assets/new/closetiny.png")
		    EditorClose.AnchorPoint = Vector2.new(0.5, 0.5)
		    EditorClose.ImageColor3 = VapeColors.Secondary
		    EditorClose.Name = "Close"
		    EditorClose.Position = UDim2.fromOffset(197, 20)
		    EditorClose.Size = UDim2.fromOffset(24, 24)
		    EditorClose.Parent = EditorPane
		
		    CloseButton.MouseButton1Click:Connect(function()
		        Component:Toggle()
		    end)
		
		    CloseButton.MouseEnter:Connect(function()
		        CloseIcon.ImageColor3 = VapeColors.Primary
		
		        Tween:Tween(CloseButton, UIPallet.Tween, {
		            BackgroundColor3 = VapeColors.Panel,
		            BackgroundTransparency = 0
		        })
		    end)
		
		    CloseButton.MouseLeave:Connect(function()
		        CloseIcon.ImageColor3 = VapeColors.Secondary
		
		        Tween:Tween(CloseButton, UIPallet.Tween, {
		            BackgroundColor3 = VapeColors.Panel,
		            BackgroundTransparency = 0.45
		        })
		    end)
		
		    ModuleChildren.InputBegan:Connect(function(Input: InputObject)
		        if not API.Window.Visible then return end
		
		        if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
		            Component:Select(true)
		        end
		    end)
		
		    ModuleChildren.MouseEnter:Connect(function()
		        if API.Window.Visible and not Editor.Visible then
		            ObjectStroke.Thickness = 2
		        end
		    end)
		
		    ModuleChildren.MouseLeave:Connect(function()
		        ObjectStroke.Thickness = 0
		    end)
		
		    ModuleChildren:GetPropertyChangedSignal("Size"):Connect(function()
		        if Editor.Visible then
		            RefreshDashes()
		        end
		    end)
		
		    EditorClose.MouseButton1Click:Connect(function()
		        SettingsChildren.Parent = SettingsPane
		        EditorPane.Visible = false
		    end)
		
		    EditorClose.MouseEnter:Connect(function()
		        EditorClose.ImageColor3 = VapeColors.Primary
		    end)
		
		    EditorClose.MouseLeave:Connect(function()
		        EditorClose.ImageColor3 = VapeColors.Secondary
		    end)
		
		    SettingsButton.MouseButton1Click:Connect(function()
		        Component:ShowSettings(not EditorPane.Visible)
		    end)
		
		    SettingsButton.MouseEnter:Connect(function()
		        SettingsIcon.ImageColor3 = VapeColors.Primary
		
		        Tween:Tween(SettingsButton, UIPallet.Tween, {
		            BackgroundColor3 = VapeColors.Panel,
		            BackgroundTransparency = 0
		        })
		    end)
		
		    SettingsButton.MouseLeave:Connect(function()
		        SettingsIcon.ImageColor3 = VapeColors.Secondary
		
		        Tween:Tween(SettingsButton, UIPallet.Tween, {
		            BackgroundColor3 = UIPallet.Main,
		            BackgroundTransparency = 0.45
		        })
		    end)
		end
		Props.Function = Props.Function or function() end
		AddMaid(Component)
		
		function Component:Color(Hue: number, Sat: number, Val: number, IsRainbow: boolean)
		    if self.Enabled then
		        Tween:Cancel(Holder)
		        Holder.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
		        Icon.ImageColor3 = Color3.fromHSV(Hue, Sat, Val)
		    end
		
		    for _, Option: any in self.Options do
		        if Option.Color then
		            Option:Color(Hue, Sat, Val, IsRainbow)
		        end
		    end
		end
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    vape:LoadOptions(self, Data.Options)
		    self:SetFavorite(Data.Favorited or false)
		
		    if self.Enabled ~= (Data.Enabled or false) then
		        self:Toggle()
		    end
		
		    if Data.Position and self.Children then
		        self.Children.Position = UDim2.fromOffset(Data.Position.X, Data.Position.Y)
		    end
		end
		
		function Component:RefreshSettings()
		    if not EditorPane or not EditorPane.Visible then return end
		
		    EditorPane.Size = UDim2.fromOffset(220, math.clamp(WindowList.AbsoluteContentSize.Y / Scale.Scale, 0, 360) + 45)
		end
		
		function Component:Destroy()
		    for _, Connection: RBXScriptConnection in Connections do
		        Connection:Disconnect()
		    end
		    table.clear(Connections)
		
		    for _, Object: Instance in {SettingsChildren, Shadow} do
		        if typeof(Object) == "Instance" then
		            Object:Destroy()
		        end
		    end
		end
		
		function Component:Save(Data)
		    Data[Props.Name] = {
		        Enabled = self.Enabled,
		        Favorited = self.Favorited,
		        Options = vape:SaveOptions(self),
		        Position = self.Children and {
		            X = self.Children.Position.X.Offset,
		            Y = self.Children.Position.Y.Offset
		        } or nil
		    }
		end
		
		function Component:Select(State: boolean)
		    if not Editor then return end
		
		    if State then
		        if API.Selected == self then return end
		
		        if API.Selected then
		            API.Selected:Select(false)
		        end
		
		        API.Selected = self
		        ObjectStroke.Thickness = 0
		        RefreshDashes()
		    elseif API.Selected == self then
		        API.Selected = nil
		    end
		
		    if not State and EditorPane.Visible then
		        self:ShowSettings(false)
		        Shadow.Visible = false
		        SettingsPane.Position = UDim2.fromScale(1, 0)
		    end
		
		    Editor.Visible = State
		end
		
		function Component:SetFavorite(State: boolean)
		    self.Favorited = State
		    FavoriteIcon.ImageColor3 = State and VapeColors.Favorite or VapeColors.Icon
		    API:Refresh()
		    vape:QueueSave()
		end
		
		function Component:ShowSettings(Anchored: boolean)
		    if Anchored then
		        local ModuleChildren: Frame = self.Children
		        local Flip: boolean = ModuleChildren.AbsolutePosition.X + ModuleChildren.AbsoluteSize.X + (224 * Scale.Scale) > GUI.AbsoluteSize.X
		        SettingsChildren.Parent = EditorPane
		        EditorPane.Position = Flip and UDim2.new(0, -216, 0, 30) or UDim2.new(1, 4, 0, 30)
		        EditorPane.Visible = true
		        self:RefreshSettings()
		
		        return
		    end
		
		    if EditorPane then
		        EditorPane.Visible = false
		    end
		
		    SettingsChildren.Parent = SettingsPane
		    Shadow.Visible = true
		
		    Tween:Tween(Shadow, UIPallet.Tween, {
		        BackgroundTransparency = 0.5
		    })
		
		    Tween:Tween(SettingsPane, UIPallet.Tween, {
		        Position = UDim2.new(1, -220, 0, 0)
		    })
		end
		
		function Component:Toggle()
		    self.Enabled = not self.Enabled
		    if self.Children then
		        self.Children.Visible = self.Enabled
		
		        if not self.Enabled then
		            self:Select(false)
		        end
		    end
		
		    Title.TextColor3 = self.Enabled and Color.Light(UIPallet.Text, 0.2) or Color.Dark(UIPallet.Text, 0.31)
		    Button.BackgroundColor3 = self.Enabled and Color.Light(UIPallet.Main, 0.05) or Button.BackgroundColor3
		    Icon.ImageColor3 = self.Enabled and Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value) or VapeColors.Icon
		
		    Tween:Tween(Holder, UIPallet.Tween, {
		        BackgroundColor3 = self.Enabled and Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value) or Color.Light(UIPallet.Main, 0.14)
		    })
		
		    Tween:Tween(Knob, UIPallet.Tween, {
		        Position = UDim2.fromOffset(self.Enabled and 12 or 2, 2)
		    })
		
		    if not self.Enabled then
		        for _, v: RBXScriptConnection in self.Connections do
		            v:Disconnect()
		        end
		        table.clear(self.Connections)
		    end
		
		    vape:QueueSave()
		    task.spawn(function()
		        local Success, Error = xpcall(Props.Function, function(ErrorMessage)
		            return `{ErrorMessage}\n{debug.traceback(nil, 2)}`
		        end, self.Enabled)
		
		        if not Success then
		            warn(`[catvape] {Props.Name} errored turning {self.Enabled and "on" or "off"} : {Error}`)
		            vape:CreateNotification("Vape", `{Props.Name} errored, check your console`, 10, "alert")
		        end
		    end)
		end
		
		for ComponentName: string, Constructor: (...any) -> ...any in Components do
		    Component[`Create{ComponentName}`] = function(_, Properties)
		        return Constructor(Properties, SettingsChildren, Component)
		    end
		end
		
		table.insert(Connections, API.Window:GetPropertyChangedSignal("Visible"):Connect(function()
		    if not API.Window.Visible then
		        Component:Select(false)
		    end
		end))
		
		Back.MouseEnter:Connect(function()
		    Back.ImageColor3 = UIPallet.Text
		end)
		
		Back.MouseLeave:Connect(function()
		    Back.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		end)
		
		Back.MouseButton1Click:Connect(function()
		    Tween:Tween(Shadow, UIPallet.Tween, {
		        BackgroundTransparency = 1
		    })
		
		    Tween:Tween(SettingsPane, UIPallet.Tween, {
		        Position = UDim2.fromScale(1, 0)
		    })
		
		    task.delay(0.2, function()
		        if vape.ThreadFix then
		            setthreadidentity(8)
		        end
		
		        Shadow.Visible = false
		    end)
		end)
		
		Button.MouseEnter:Connect(function()
		    if not Component.Enabled then
		        Button.BackgroundColor3 = Color.Light(UIPallet.Main, 0.05)
		        Icon.ImageColor3 = VapeColors.IconHover
		    end
		end)
		
		Button.MouseLeave:Connect(function()
		    if not Component.Enabled then
		        Button.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		        Icon.ImageColor3 = VapeColors.Icon
		    end
		end)
		
		Button.MouseButton1Click:Connect(function()
		    Component:Toggle()
		end)
		
		Button.MouseButton2Click:Connect(function()
		    Component:ShowSettings(false)
		end)
		
		DotsButton.MouseButton1Click:Connect(function()
		    Component:ShowSettings(false)
		end)
		
		Favorite.MouseButton1Click:Connect(function()
		    Component:SetFavorite(not Component.Favorited)
		end)
		
		Favorite.MouseEnter:Connect(function()
		    if not Component.Favorited then
		        FavoriteIcon.ImageColor3 = VapeColors.IconHover
		    end
		end)
		
		Favorite.MouseLeave:Connect(function()
		    if not Component.Favorited then
		        FavoriteIcon.ImageColor3 = VapeColors.Icon
		    end
		end)
		
		DotsButton.MouseEnter:Connect(function()
		    Dots.ImageColor3 = UIPallet.Text
		end)
		
		DotsButton.MouseLeave:Connect(function()
		    Dots.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		end)
		
		Shadow.MouseButton1Click:Connect(function()
		    Tween:Tween(Shadow, UIPallet.Tween, {
		        BackgroundTransparency = 1
		    })
		
		    Tween:Tween(SettingsPane, UIPallet.Tween, {
		        Position = UDim2.fromScale(1, 0)
		    })
		
		    task.delay(0.2, function()
		        if vape.ThreadFix then
		            setthreadidentity(8)
		        end
		
		        Shadow.Visible = false
		    end)
		end)
		
		Shadow:GetPropertyChangedSignal("Visible"):Connect(function()
		    Tooltip.Visible = false
		    vape.LegitVisible = Shadow.Visible
		end)
		
		table.insert(Connections, WindowList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		    if not Component.RefreshSettings then return end
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    SettingsChildren.CanvasSize = UDim2.fromOffset(0, WindowList.AbsoluteContentSize.Y / Scale.Scale)
		    Component:RefreshSettings()
		end))
		
		API.Modules[Props.Name] = Component
		API:Refresh()
		
		local Sorting: {string} = {}
		for _, Module: any in API.Modules do
		    table.insert(Sorting, Module.Name)
		end
		table.sort(Sorting)
		
		for i: number, Name: string in Sorting do
		    API.Modules[Name].Object.LayoutOrder = i
		end
		
		return Component
	end,
	LegitWindow = function(Props, Children, API)
		local Component = {
		    Group = "All",
		    Modules = {},
		    Search = "",
		    Tabs = {}
		}
		
		local Window: Frame = Instance.new("Frame")
		Window.BackgroundColor3 = UIPallet.Main
		Window.Position = UDim2.new(0.5, -350, 0.5, -190)
		Window.Size = UDim2.fromOffset(700, 380)
		Window.Name = "LegitGUI"
		Window.Visible = false
		Window.Parent = ScaledGUI
		table.insert(vape.Windows, Window)
		Component.Window = Window
		AddBlur(Window)
		AddCorner(Window)
		AddDragHandler(Window)
		local Modal: TextButton = Instance.new("TextButton")
		Modal.BackgroundTransparency = 1
		Modal.Modal = true
		Modal.Text = ""
		Modal.Parent = Window
		local Icon: ImageLabel = Instance.new("ImageLabel")
		Icon.BackgroundTransparency = 1
		Icon.Image = GetVapeAsset("kingvape/assets/new/legit_mode_icon.png")
		Icon.ImageColor3 = UIPallet.Text
		Icon.Position = UDim2.fromOffset(18, 11)
		Icon.Size = UDim2.fromOffset(16, 16)
		Icon.Parent = Window
		local Close: ImageButton = Instance.new("ImageButton")
		Close.BackgroundTransparency = 1
		Close.Image = GetVapeAsset("kingvape/assets/new/min.png")
		Close.ImageColor3 = Color.Light(UIPallet.Main, 0.24)
		Close.Position = UDim2.new(1, -31, 0, 11)
		Close.Size = UDim2.fromOffset(16, 16)
		Close.Parent = Window
		local Holder: Frame = Instance.new("Frame")
		Holder.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.02)
		Holder.Position = UDim2.new(1, -253, 0, 42)
		Holder.Size = UDim2.fromOffset(242, 29)
		Holder.Parent = Window
		AddCorner(Holder, UDim.new(0, 4))
		local Stroke: UIStroke = Instance.new("UIStroke")
		Stroke.Color = Color.Light(UIPallet.Main, 0.02)
		Stroke.Parent = Holder
		local SearchIcon: ImageLabel = Instance.new("ImageLabel")
		SearchIcon.BackgroundTransparency = 1
		SearchIcon.Image = GetVapeAsset("kingvape/assets/new/search.png")
		SearchIcon.ImageColor3 = Color.Light(UIPallet.Main, 0.42)
		SearchIcon.Position = UDim2.new(1, -25, 0, 9)
		SearchIcon.Size = UDim2.fromOffset(12, 12)
		SearchIcon.Parent = Holder
		local SearchBox: TextBox = Instance.new("TextBox")
		SearchBox.BackgroundTransparency = 1
		SearchBox.ClearTextOnFocus = false
		SearchBox.FontFace = UIPallet.Font
		SearchBox.PlaceholderColor3 = Color.Dark(UIPallet.Text, 0.16)
		SearchBox.PlaceholderText = "Search mods"
		SearchBox.Position = UDim2.fromOffset(8, 0)
		SearchBox.Size = UDim2.new(1, -8, 1, 0)
		SearchBox.Text = ""
		SearchBox.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		SearchBox.TextSize = 14
		SearchBox.TextXAlignment = Enum.TextXAlignment.Left
		SearchBox.Parent = Holder
		local Children: ScrollingFrame = Instance.new("ScrollingFrame")
		Children.BackgroundTransparency = 1
		Children.BorderSizePixel = 0
		Children.CanvasSize = UDim2.new()
		Children.Position = UDim2.fromOffset(14, 76)
		Children.ScrollBarThickness = 2
		Children.ScrollBarImageTransparency = 0.75
		Children.Size = UDim2.fromOffset(684, 301)
		Children.Parent = Window
		local Empty: Frame = Instance.new("Frame")
		Empty.BackgroundTransparency = 1
		Empty.Name = "Empty"
		Empty.Position = UDim2.fromOffset(14, 76)
		Empty.Size = UDim2.fromOffset(684, 301)
		Empty.Visible = false
		Empty.Parent = Window
		local EmptyIcon: ImageLabel = Instance.new("ImageLabel")
		EmptyIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		EmptyIcon.BackgroundTransparency = 1
		EmptyIcon.Image = GetVapeAsset("kingvape/assets/new/empty.png")
		EmptyIcon.ImageColor3 = VapeColors.Primary
		EmptyIcon.Position = UDim2.new(0.5, -8, 0.5, -30)
		EmptyIcon.Size = UDim2.fromOffset(53, 40)
		EmptyIcon.Parent = Empty
		local EmptyLabel: TextLabel = Instance.new("TextLabel")
		EmptyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		EmptyLabel.BackgroundTransparency = 1
		EmptyLabel.FontFace = UIPallet.Font
		EmptyLabel.Position = UDim2.new(0.5, -8, 0.5, 15)
		EmptyLabel.Size = UDim2.fromOffset(200, 20)
		EmptyLabel.Text = "No Favorites"
		EmptyLabel.TextColor3 = VapeColors.Muted
		EmptyLabel.TextSize = 16
		EmptyLabel.Parent = Empty
		local WindowList: UIGridLayout = Instance.new("UIGridLayout")
		WindowList.CellSize = UDim2.fromOffset(163, 114)
		WindowList.CellPadding = UDim2.fromOffset(6, 6)
		WindowList.FillDirectionMaxCells = 4
		WindowList.SortOrder = Enum.SortOrder.LayoutOrder
		WindowList.Parent = Children
		
		local TabX: number = 25
		
		for _, TabName: string in {"Favorite", "All", "HUD", "Game"} do
		    local Tab: TextButton = Instance.new("TextButton")
		    Tab.AutoButtonColor = false
		    Tab.BackgroundTransparency = 1
		    Tab.FontFace = UIPallet.Font
		    Tab.Name = TabName
		    Tab.Position = UDim2.fromOffset(TabX, 46)
		    Tab.Size = UDim2.fromOffset(GetFontBounds(TabName, 12, UIPallet.Font).X, 20)
		    Tab.Text = TabName
		    Tab.TextColor3 = TabName == Component.Group and Color3.new(1, 1, 1) or VapeColors.Secondary
		    Tab.TextSize = 12
		    Tab.Parent = Window
		    local Underline: Frame = Instance.new("Frame")
		    Underline.BackgroundTransparency = 1
		    Underline.Name = "Underline"
		    Underline.Position = UDim2.fromOffset(0, 17)
		    Underline.Size = UDim2.new(1, 2, 0, 2)
		    Underline.Visible = TabName == Component.Group
		    Underline.Parent = Tab
		
		    for i: number = 0, (Tab.Size.X.Offset + 2) // 4 do
		        local Mark: Frame = Instance.new("Frame")
		        Mark.BackgroundColor3 = VapeColors.Primary
		        Mark.BorderSizePixel = 0
		        Mark.Position = UDim2.fromOffset(i * 4, 0)
		        Mark.Size = UDim2.fromOffset(2, 2)
		        Mark.Parent = Underline
		    end
		
		    TabX += Tab.Size.X.Offset + 35
		    Component.Tabs[TabName] = Tab
		
		    Tab.MouseButton1Click:Connect(function()
		        Component.Group = TabName
		
		        for Name: string, Button: TextButton in Component.Tabs do
		            Button.TextColor3 = Name == TabName and Color3.new(1, 1, 1) or VapeColors.Secondary
		            Button.Underline.Visible = Name == TabName
		        end
		
		        Component:Refresh()
		    end)
		end
		
		for ComponentName: string, Constructor: (...any) -> ...any in Components do
		    Component[`Create{ComponentName}`] = function(_, Properties)
		        return Constructor(Properties, Children, Component)
		    end
		end
		
		function Component:CreateModule(Properties)
		    return Components.LegitModule(Properties, Children, Component)
		end
		
		function Component:Refresh()
		    local Shown: number = 0
		
		    for Name: string, v: any in self.Modules do
		        v.Object.Visible = (self.Search == "" or Name:lower():find(self.Search, 1, true) ~= nil) and (self.Group == "All" or self.Group == v.Category or (self.Group == "Favorite" and v.Favorited)) or false
		        Shown += v.Object.Visible and 1 or 0
		    end
		
		    Empty.Visible = Shown == 0 and self.Group == "Favorite"
		end
		
		local function VisibleCheck()
		    for _, Module: any in Component.Modules do
		        if Module.Children then
		            local Visible: boolean = ClickGUI.Visible
		
		            Module.Children.Visible = (not Visible or Window.Visible) and Module.Enabled
		        end
		    end
		end
		
		SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		    Component.Search = SearchBox.Text:lower()
		    Component:Refresh()
		end)
		
		Close.MouseButton1Click:Connect(function()
		    Window.Visible = false
		    ClickGUI.Visible = true
		end)
		
		Close.MouseEnter:Connect(function()
		    Close.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		end)
		
		Close.MouseLeave:Connect(function()
		    Close.ImageColor3 = Color.Light(UIPallet.Main, 0.24)
		end)
		
		vape:Clean(ClickGUI:GetPropertyChangedSignal("Visible"):Connect(VisibleCheck))
		
		Holder.MouseEnter:Connect(function()
		    Tween:Tween(Stroke, UIPallet.Tween, {
		        Color = Color.Light(UIPallet.Main, 0.0875)
		    })
		end)
		
		Holder.MouseLeave:Connect(function()
		    Tween:Tween(Stroke, UIPallet.Tween, {
		        Color = Color.Light(UIPallet.Main, 0.02)
		    })
		end)
		
		Window:GetPropertyChangedSignal("Visible"):Connect(function()
		    vape:UpdateGUI(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
		    vape:BlurCheck()
		    VisibleCheck()
		end)
		
		WindowList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    Children.CanvasSize = UDim2.fromOffset(0, WindowList.AbsoluteContentSize.Y / Scale.Scale)
		end)
		
		vape.Legit = Component
		
		return Component
	end,
	Module = function(Props, Children, API)
		vape:Remove(Props.Name)
		local Component = {
		    Category = API.Name,
		    ConfigName = Props.ConfigName or Props.Name,
		    Enabled = false,
		    ExtraText = Props.ExtraText,
		    Favorited = false,
		    Highlighted = false,
		    Index = GetTableSize(vape.Modules),
		    Name = Props.Name,
		    OptionSpecs = {},
		    Options = {},
		    Paid = false,
		    Tags = {},
		    Tooltip = Props.Tooltip,
		    Top = Props.Top == true,
		    Visible = true
		}
		
		local IsHover: boolean = false
		local Button: TextButton = Instance.new("TextButton")
		Button.AutoButtonColor = false
		Button.BackgroundColor3 = UIPallet.Main
		Button.BorderSizePixel = 0
		Button.FontFace = UIPallet.Font
		Button.Name = Props.Name
		Button.Size = UDim2.fromOffset(220, 40)
		Button.Text = `{string.rep(" ", 12)}{Props.Name}`
		Button.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		Button.TextSize = 14
		Button.TextXAlignment = Enum.TextXAlignment.Left
		Button.Parent = Children
		Component.Object = Button
		AddTooltip(Button, Props.Tooltip)
		local Gradient: UIGradient = Instance.new("UIGradient")
		Gradient.Enabled = false
		Gradient.Rotation = 90
		Gradient.Parent = Button
		local Highlight: UIStroke = Instance.new("UIStroke")
		Highlight.Color = VapeColors.Favorite
		Highlight.Enabled = false
		Highlight.LineJoinMode = Enum.LineJoinMode.Miter
		Highlight.Name = "Highlight"
		Highlight.Parent = Button
		local ModuleChildren: Frame = Instance.new("Frame")
		ModuleChildren.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.02)
		ModuleChildren.BorderSizePixel = 0
		ModuleChildren.Name = `{Props.Name}Children`
		ModuleChildren.Size = UDim2.new(1, 0, 0, 0)
		ModuleChildren.Visible = false
		local WindowList: UIListLayout = Instance.new("UIListLayout")
		WindowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		WindowList.SortOrder = Enum.SortOrder.LayoutOrder
		WindowList.Parent = ModuleChildren
		local DotsButton: TextButton = Instance.new("TextButton")
		DotsButton.BackgroundTransparency = 1
		DotsButton.Name = "Dots"
		DotsButton.Position = UDim2.new(1, -25, 0, 0)
		DotsButton.Size = UDim2.fromOffset(25, 40)
		DotsButton.Text = ""
		DotsButton.Parent = Button
		local Dots: ImageLabel = Instance.new("ImageLabel")
		Dots.BackgroundTransparency = 1
		Dots.Image = GetVapeAsset("kingvape/assets/new/settingdots.png")
		Dots.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		Dots.Name = "Dots"
		Dots.Position = UDim2.fromOffset(4, 12)
		Dots.Size = UDim2.fromOffset(3, 16)
		Dots.Parent = DotsButton
		local Indicators: Frame = Instance.new("Frame")
		Indicators.AnchorPoint = Vector2.new(0, 0.5)
		Indicators.BackgroundTransparency = 1
		Indicators.Name = "Indicators"
		Indicators.Position = UDim2.new(0, 187, 0.5, 0)
		Indicators.Size = UDim2.fromOffset(0, 21)
		Indicators.Parent = Button
		local IndicatorList: UIListLayout = Instance.new("UIListLayout")
		IndicatorList.FillDirection = Enum.FillDirection.Horizontal
		IndicatorList.HorizontalAlignment = Enum.HorizontalAlignment.Right
		IndicatorList.Padding = UDim.new(0, 5)
		IndicatorList.SortOrder = Enum.SortOrder.LayoutOrder
		IndicatorList.VerticalAlignment = Enum.VerticalAlignment.Center
		IndicatorList.Parent = Indicators
		local Favorite: TextButton = Instance.new("TextButton")
		Favorite.AutoButtonColor = false
		Favorite.BackgroundTransparency = 1
		Favorite.LayoutOrder = -1
		Favorite.Name = "Favorite"
		Favorite.Size = UDim2.fromOffset(18, 21)
		Favorite.Text = ""
		Favorite.Visible = false
		Favorite.Parent = Indicators
		AddTooltip(Favorite, "Add module to favorites")
		local FavoriteIcon: ImageLabel = Instance.new("ImageLabel")
		FavoriteIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		FavoriteIcon.BackgroundTransparency = 1
		FavoriteIcon.Image = GetVapeAsset("kingvape/assets/new/star.png")
		FavoriteIcon.ImageColor3 = VapeColors.Icon
		FavoriteIcon.Name = "Icon"
		FavoriteIcon.Position = UDim2.fromScale(0.5, 0.5)
		FavoriteIcon.Size = UDim2.fromOffset(16, 15)
		FavoriteIcon.Parent = Favorite
		local Divider: Frame = Instance.new("Frame")
		Divider.BackgroundColor3 = Color3.new(0.19, 0.19, 0.19)
		Divider.BackgroundTransparency = 0.52
		Divider.BorderSizePixel = 0
		Divider.Name = "Divider"
		Divider.Position = UDim2.new(0, 0, 1, -1)
		Divider.Size = UDim2.new(1, 0, 0, 1)
		Divider.Visible = false
		Divider.Parent = Button
		local Edit: TextButton = Instance.new("TextButton")
		Edit.AutoButtonColor = false
		Edit.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.02)
		Edit.BorderSizePixel = 0
		Edit.Name = "Edit"
		Edit.Size = UDim2.fromOffset(40, 40)
		Edit.Text = ""
		Edit.Visible = false
		Edit.Parent = Button
		local EditBox: Frame = Instance.new("Frame")
		EditBox.BorderSizePixel = 0
		EditBox.Name = "EditBox"
		EditBox.Position = UDim2.fromOffset(16, 16)
		EditBox.Size = UDim2.fromOffset(8, 8)
		EditBox.Parent = Edit
		local EditBorder: UIStroke = Instance.new("UIStroke")
		EditBorder.BorderOffset = UDim.new(0, 1)
		EditBorder.LineJoinMode = Enum.LineJoinMode.Miter
		EditBorder.Parent = EditBox
		Props.Function = Props.Function or function() end
		Component.Edit = Edit
		Component.Children = ModuleChildren
		AddMaid(Component)
		
		local function UpdateIndicators()
		    local BindObject = Component.Bind and Component.Bind.Object
		    Indicators.Position = UDim2.new(0, (BindObject and BindObject.Visible) and (179 - BindObject.Size.X.Offset) or 187, 0.5, 0)
		    Favorite.Visible = Component.Favorited or IsHover or ModuleChildren.Visible
		end
		
		Props.Tags = Props.Tags or {}
		local FeatureTag: string? = GetFeatureTag(Props.Name)
		
		if FeatureTag and not table.find(Props.Tags, FeatureTag) then
		    table.insert(Props.Tags, FeatureTag)
		end
		
		for i: number, Tag: string in Props.Tags do
		    Tag = Tag:upper()
		    Props.Tags[i] = Tag:lower()
		    Component.Paid = Component.Paid or Tag == "PAID"
		    local Indicator: TextLabel = Instance.new("TextLabel")
		    Indicator.BackgroundColor3 = Color3.new(1, 1, 1)
		    Indicator.FontFace = UIPallet.FontSemiBold
		    Indicator.LayoutOrder = i - 1
		    Indicator.Name = Tag
		    Indicator.Size = UDim2.fromOffset(GetFontBounds(RemoveTags(Tag), 11, UIPallet.FontSemiBold).X + 10, 15)
		    Indicator.Text = Tag
		    Indicator.TextColor3 = Color3.new()
		    Indicator.TextSize = 11
		    Indicator.TextTransparency = 1
		    Indicator.Visible = Tag ~= "MATCHED"
		    Indicator.Parent = Indicators
		    AddCorner(Indicator, UDim.new(0, 4))
		    local Label: TextLabel = Indicator:Clone()
		    Label.AnchorPoint = Vector2.new()
		    Label.BackgroundTransparency = 1
		    Label.Name = "Text"
		    Label.Position = UDim2.new()
		    Label.Size = UDim2.fromScale(1, 1)
		    Label.TextTransparency = 0
		    Label.Parent = Indicator
		    table.insert(Component.Tags, Indicator)
		end
		
		function Component:Color(Hue: number, Sat: number, Val: number, IsRainbow: boolean)
		    if self.Enabled then
		        Button.BackgroundColor3 = IsRainbow and Color3.fromHSV(vape:Color((Hue - (self.Index * 0.025)) % 1)) or Color3.fromHSV(Hue, Sat, Val)
		        Button.TextColor3 = vape.GUIColor.Rainbow and Color3.new(0.19, 0.19, 0.19) or vape:TextColor(Hue, Sat, Val)
		        Button.UIGradient.Enabled = IsRainbow and vape.RainbowMode.Value == "Gradient"
		
		        if Button.UIGradient.Enabled then
		            Button.BackgroundColor3 = Color3.new(1, 1, 1)
		            Button.UIGradient.Color = ColorSequence.new({
		                ColorSequenceKeypoint.new(0, Color3.fromHSV(vape:Color((Hue - (self.Index * 0.025)) % 1))),
		                ColorSequenceKeypoint.new(1, Color3.fromHSV(vape:Color((Hue - ((self.Index + 1) * 0.025)) % 1)))
		            })
		        end
		
		        self.Bind:SetColor(self.Object.TextColor3)
		        Dots.ImageColor3 = self.Object.TextColor3
		    end
		
		    if self.Visible then
		        EditBox.BackgroundColor3 = IsRainbow and Color3.fromHSV(vape:Color((Hue - (self.Index * 0.025)) % 1)) or Color3.fromHSV(Hue, Sat, Val)
		        EditBorder.Color = EditBox.BackgroundColor3
		    end
		
		    for _, Option: any in self.Options do
		        if Option.Color then
		            Option:Color(Hue, Sat, Val, IsRainbow)
		        end
		    end
		
		    for _, v: TextLabel in self.Tags do
		        v.BackgroundColor3 = IsRainbow and Color3.fromHSV(vape:Color((Hue - (self.Index * 0.025)) % 1)) or self.Enabled and Color3.new(1, 1, 1) or Color3.fromHSV(Hue, Sat, Val)
		        v.BackgroundTransparency = (IsRainbow or not self.Enabled) and 0 or 0.85
		        v:FindFirstChild("Text").TextColor3 = vape.GUIColor.Rainbow and Color3.new(0.19, 0.19, 0.19) or vape:TextColor(Hue, Sat, Val)
		    end
		end
		
		function Component:CreateOptionsView(Parent: Frame)
		    local View = setmetatable({Options = {}}, {__index = self})
		    local Mirrors = {}
		
		    local function ReadState(Option, Name: string)
		        local State = {}
		        Option:Save(State)
		
		        if State[Name] ~= nil then
		            return State[Name]
		        end
		
		        local _, Only = next(State)
		        return Only
		    end
		
		    local function SameState(A, B)
		        if A == nil or B == nil then
		            return A == B
		        end
		
		        for Key: any, v: any in A do
		            local Other = B[Key]
		
		            if typeof(v) == "table" then
		                if typeof(Other) ~= "table" or #v ~= #Other then
		                    return false
		                end
		
		                for i: number, Entry: any in v do
		                    if Other[i] ~= Entry then
		                        return false
		                    end
		                end
		            elseif Other ~= v then
		                return false
		            end
		        end
		
		        return true
		    end
		
		    for _, Spec: any in self.OptionSpecs do
		        local Settings = table.clone(Spec.Settings)
		        Settings.Function = function() end
		
		        local Mirror = Components[Spec.Type](Settings, Parent, View)
		        local Key
		
		        for OptionName: string, Option: any in View.Options do
		            if Option == Mirror then
		                Key = OptionName
		                break
		            end
		        end
		
		        local Canonical = Key and self.Options[Key]
		        if Canonical and Canonical.Save and Mirror.Save and Mirror.Load then
		            table.insert(Mirrors, {
		                Name = Key,
		                Canonical = Canonical,
		                Mirror = Mirror,
		                Last = ReadState(Mirror, Key)
		            })
		        else
		            Settings.Function = Spec.Settings.Function
		        end
		    end
		
		    task.spawn(function()
		        repeat
		            if not Parent.Visible then
		                task.wait(0.5)
		                continue
		            end
		
		            if vape.ThreadFix then
		                setthreadidentity(8)
		            end
		
		            for _, Entry: any in Mirrors do
		                local MirrorState = ReadState(Entry.Mirror, Entry.Name)
		
		                if not SameState(MirrorState, Entry.Last) then
		                    Entry.Canonical:Load(MirrorState)
		                    Entry.Last = MirrorState
		                else
		                    local CanonicalState = ReadState(Entry.Canonical, Entry.Name)
		
		                    if not SameState(CanonicalState, MirrorState) then
		                        Entry.Mirror:Load(CanonicalState)
		                        Entry.Last = ReadState(Entry.Mirror, Entry.Name)
		                    end
		                end
		            end
		
		            task.wait()
		        until not Parent.Parent
		    end)
		
		    return View
		end
		
		function Component:Destroy()
		    self.Bind:Destroy()
		
		    for _, Option: any in self.Options do
		        if Option.Type == "Bind" then
		            Option:Destroy()
		        end
		    end
		end
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    vape:LoadOptions(self, Data.Options)
		    self.Bind:Load(Data.Bind or {Keys = {}})
		
		    if Data.Favorited then
		        self:SetFavorite(Data.Favorited)
		    end
		
		    if self.Enabled ~= ((Data.Enabled or false) and not self.Bind.Hold) then
		        self:Toggle(true)
		    end
		
		    if self.Visible ~= Data.Visible then
		        self:SetVisible(Data.Visible, true)
		    end
		end
		
		function Component:Save(Data)
		    Data[Props.Name] = {
		        Enabled = self.Enabled,
		        Favorited = self.FavoriteIndex,
		        Options = vape:SaveOptions(self),
		        Visible = self.Visible
		    }
		
		    self.Bind:Save(Data[Props.Name])
		end
		
		function Component:SetFavorite(State)
		    local Order: number? = typeof(State) == "number" and State or nil
		    self.Favorited = State and true or false
		    self.FavoriteIndex = self.Favorited and (Order or (vape.FavoriteCount + 1)) or nil
		
		    if self.FavoriteIndex then
		        vape.FavoriteCount = math.max(vape.FavoriteCount, self.FavoriteIndex)
		    end
		
		    FavoriteIcon.ImageColor3 = self.Favorited and VapeColors.Favorite or VapeColors.Icon
		    UpdateIndicators()
		
		    local Favorites = vape.Categories.Favorites
		    if Favorites then
		        if self.Favorited and not self.FavoriteRow then
		            self.FavoriteRow = Favorites:MirrorModule(self)
		        elseif not self.Favorited and self.FavoriteRow then
		            self.FavoriteRow:Destroy()
		            self.FavoriteRow = nil
		        end
		    end
		
		    vape:QueueSave()
		end
		
		function Component:SetHighlight(Order: number?)
		    self.Highlighted = Order and true or false
		    Highlight.Enabled = self.Highlighted
		    Button.LayoutOrder = Order and (-1000 + (Order * 2)) or self.Index
		    ModuleChildren.LayoutOrder = Order and (Button.LayoutOrder + 1) or self.Index
		end
		
		function Component:SetVisible(IsVisible: boolean, IsLoad: boolean?)
		    self.Visible = IsVisible
		    EditBox.BackgroundTransparency = IsVisible and 0 or 1
		    EditBorder.Color = IsVisible and EditBox.BackgroundColor3 or Color.Light(UIPallet.Main, 0.37)
		
		    if IsLoad and not vape.EditGUI then
		        Button.Visible = IsVisible
		    end
		
		    if API.UpdateHidden then
		        API:UpdateHidden()
		    end
		
		    vape:QueueSave()
		end
		
		function Component:Toggle()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    self.Enabled = not self.Enabled
		    Divider.Visible = self.Enabled
		    Gradient.Enabled = self.Enabled
		    Button.TextColor3 = (IsHover or ModuleChildren.Visible) and UIPallet.Text or Color.Dark(UIPallet.Text, 0.16)
		    Button.BackgroundColor3 = (IsHover or ModuleChildren.Visible) and Color.Light(UIPallet.Main, 0.02) or UIPallet.Main
		    Dots.ImageColor3 = self.Enabled and Color3.fromRGB(50, 50, 50) or Color.Light(UIPallet.Main, 0.37)
		    Component.Bind:SetColor(Color.Dark(UIPallet.Text, 0.43))
		
		    if not self.Enabled then
		        for _, v: RBXScriptConnection in self.Connections do
		            v:Disconnect()
		        end
		        table.clear(self.Connections)
		    end
		
		    if not vape.TextGUIThread then
		        vape.TextGUIThread = task.defer(function()
		            if vape.ThreadFix then
		                setthreadidentity(8)
		            end
		
		            if vape.Loaded ~= nil then
		                vape:UpdateTextGUI()
		            end
		
		            vape.TextGUIThread = nil
		        end)
		    end
		
		    vape:QueueSave()
		    task.spawn(function()
		        local Success, Error = xpcall(Props.Function, function(ErrorMessage)
		            return `{ErrorMessage}\n{debug.traceback(nil, 2)}`
		        end, self.Enabled)
		
		        if not Success then
		            warn(`[catvape] {Props.Name} errored turning {self.Enabled and "on" or "off"} : {Error}`)
		            vape:CreateNotification("Vape", `{Props.Name} errored, check your console`, 10, "alert")
		        end
		    end)
		end
		
		for ComponentName: string, Constructor: (...any) -> ...any in Components do
		    Component[`Create{ComponentName}`] = function(_, Properties)
		        if not Properties.Module then
		            table.insert(Component.OptionSpecs, {Type = ComponentName, Settings = Properties})
		        end
		
		        return Constructor(Properties, ModuleChildren, Component)
		    end
		end
		
		local function MountChildren()
		    if ModuleChildren.Parent then return end
		
		    ModuleChildren.Parent = Children
		    ModuleChildren.Size = UDim2.new(1, 0, 0, WindowList.AbsoluteContentSize.Y / Scale.Scale)
		end
		
		local function ToggleChildren()
		    MountChildren()
		    ModuleChildren.Visible = not ModuleChildren.Visible
		    UpdateIndicators()
		end
		
		Button.MouseEnter:Connect(function()
		    IsHover = true
		    if not Component.Enabled and not ModuleChildren.Visible then
		        Button.TextColor3 = UIPallet.Text
		        Button.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		    end
		
		    Component.Bind:SetVisible(IsHover or ModuleChildren.Visible)
		    UpdateIndicators()
		end)
		
		Button.MouseLeave:Connect(function()
		    IsHover = false
		    if not Component.Enabled and not ModuleChildren.Visible then
		        Button.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		        Button.BackgroundColor3 = UIPallet.Main
		    end
		
		    Component.Bind:SetVisible(IsHover or ModuleChildren.Visible)
		    UpdateIndicators()
		end)
		
		Button.MouseButton1Click:Connect(function()
		    if vape.EditGUI then
		        return
		    end
		
		    Component:Toggle()
		end)
		
		Button.MouseButton2Click:Connect(ToggleChildren)
		
		DotsButton.MouseButton1Click:Connect(ToggleChildren)
		
		DotsButton.MouseButton2Click:Connect(ToggleChildren)
		
		DotsButton.MouseEnter:Connect(function()
		    if not Component.Enabled then
		        Dots.ImageColor3 = UIPallet.Text
		    end
		end)
		
		DotsButton.MouseLeave:Connect(function()
		    if not Component.Enabled then
		        Dots.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		    end
		end)
		
		Edit.MouseButton1Click:Connect(function()
		    Component:SetVisible(not Component.Visible)
		end)
		
		Favorite.MouseButton1Click:Connect(function()
		    Component:SetFavorite(not Component.Favorited)
		end)
		
		Favorite.MouseEnter:Connect(function()
		    if not Component.Favorited then
		        FavoriteIcon.ImageColor3 = VapeColors.IconHover
		    end
		end)
		
		Favorite.MouseLeave:Connect(function()
		    FavoriteIcon.ImageColor3 = Component.Favorited and VapeColors.Favorite or VapeColors.Icon
		end)
		
		WindowList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    ModuleChildren.Size = UDim2.new(1, 0, 0, WindowList.AbsoluteContentSize.Y / Scale.Scale)
		end)
		
		local Bind = Component:CreateBind({
		    Module = true,
		    Cover = true
		})
		
		Bind.Object:GetPropertyChangedSignal("Size"):Connect(UpdateIndicators)
		
		Bind.Object:GetPropertyChangedSignal("Visible"):Connect(UpdateIndicators)
		
		Bind.Triggered:Connect(function(IsDown: boolean)
		    if Bind.Hold then
		        if Component.Enabled ~= IsDown then
		            if vape.ToggleNotifications.Enabled then
		                vape:CreateNotification(Props.Name, (not Component.Enabled and "<font color='#00AA00'>Enabled</font>" or "<font color='#FF5555'>Disabled</font>"), 1.5, nil, Props.Name)
		            end
		
		            Component:Toggle(true)
		        end
		    else
		        if vape.ToggleNotifications.Enabled then
		            vape:CreateNotification(Props.Name, (not Component.Enabled and "<font color='#00AA00'>Enabled</font>" or "<font color='#FF5555'>Disabled</font>"), 1.5, nil, Props.Name)
		        end
		
		        Component:Toggle(true)
		    end
		end)
		
		if UserInputService.TouchEnabled then
		    local IsHeld: boolean = false
		
		    Button.MouseButton1Down:Connect(function()
		        IsHeld = true
		        local HoldTime, HoldPosition = os.clock(), UserInputService:GetMouseLocation()
		        repeat
		            IsHeld = (UserInputService:GetMouseLocation() - HoldPosition).Magnitude < 3
		            task.wait()
		        until (os.clock() - HoldTime) > 1 or not IsHeld or not ClickGUI.Visible
		
		        if IsHeld and ClickGUI.Visible then
		            if vape.ThreadFix then
		                setthreadidentity(8)
		            end
		
		            ClickGUI.Visible = false
		            Tooltip.Visible = false
		            vape:BlurCheck()
		            for _, Module: any in vape.Modules do
		                if Module.Bind.Mobile then
		                    Module.Bind.Mobile.Visible = true
		                end
		            end
		
		            local Connection
		            Connection = UserInputService.InputBegan:Connect(function(Input: InputObject)
		                if Input.UserInputType == Enum.UserInputType.Touch then
		                    if vape.ThreadFix then
		                        setthreadidentity(8)
		                    end
		
		                    Bind:CreateMobileButton(Input.Position + Vector3.new(0, GuiService:GetGuiInset().Y, 0))
		                    ClickGUI.Visible = true
		                    vape:BlurCheck()
		
		                    for _, Module: any in vape.Modules do
		                        if Module.Bind.Mobile then
		                            Module.Bind.Mobile.Visible = false
		                        end
		                    end
		
		                    Connection:Disconnect()
		                end
		            end)
		        end
		    end)
		
		    Button.MouseButton1Up:Connect(function()
		        IsHeld = false
		    end)
		end
		
		vape.Modules[Props.Name] = Component
		
		vape:SortCategories()
		
		return Component
	end,
	Overlay = function(Props, Children, API)
		local Window: TextButton
		local Component
		Component = {
		    Button = vape.Overlays:CreateImageToggle({
		        Name = Props.Name,
		        Function = function(Callback: boolean)
		            Window.Visible = Callback and (ClickGUI.Visible or Component.Pinned)
		
		            if not Callback then
		                for _, v: RBXScriptConnection in Component.Connections do
		                    v:Disconnect()
		                end
		                table.clear(Component.Connections)
		            end
		
		            if Props.Function then
		                task.spawn(Props.Function, Callback)
		            end
		        end,
		        Icon = Props.Icon,
		        Size = Props.Size,
		        Position = Props.Position
		    }),
		    Expanded = false,
		    Pinned = false,
		    Options = {},
		    Type = "Overlay"
		}
		
		Window = Instance.new("TextButton")
		Window.AutoButtonColor = false
		Window.BackgroundColor3 = UIPallet.Main
		Window.Name = `{Props.Name}Overlay`
		Window.Position = UDim2.fromOffset(240, 46)
		Window.Size = UDim2.fromOffset(Props.CategorySize or 220, 41)
		Window.Text = ""
		Window.Visible = false
		Window.Parent = ScaledGUI
		Component.Object = Window
		local Blur = AddBlur(Window)
		AddCorner(Window)
		AddDragHandler(Window)
		local Icon: ImageLabel = Instance.new("ImageLabel")
		Icon.BackgroundTransparency = 1
		Icon.Image = Props.Icon
		Icon.ImageColor3 = UIPallet.Text
		Icon.Position = UDim2.fromOffset(12, (Icon.Size.X.Offset > 14 and 14 or 13))
		Icon.Size = Props.Size
		Icon.Parent = Window
		local Title: TextLabel = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.FontFace = UIPallet.Font
		Title.Size = UDim2.new(1, -32, 0, 41)
		Title.Position = UDim2.fromOffset(math.abs(Title.Size.X.Offset), 0)
		Title.Text = Props.Name
		Title.TextColor3 = UIPallet.Text
		Title.TextSize = 13
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Parent = Window
		local Pin: ImageButton = Instance.new("ImageButton")
		Pin.Name = "Pin"
		Pin.Size = UDim2.fromOffset(14, 14)
		Pin.Position = UDim2.new(1, -37, 0, 14)
		Pin.BackgroundTransparency = 1
		Pin.AutoButtonColor = false
		Pin.Image = GetVapeAsset("kingvape/assets/new/pin.png")
		Pin.ImageColor3 = Color.Dark(UIPallet.Text, 0.43)
		Pin.Parent = Window
		local DotsButton: TextButton = Instance.new("TextButton")
		DotsButton.Name = "Dots"
		DotsButton.Size = UDim2.fromOffset(17, 40)
		DotsButton.Position = UDim2.new(1, -17, 0, 0)
		DotsButton.BackgroundTransparency = 1
		DotsButton.Text = ""
		DotsButton.Parent = Window
		local Dots: ImageLabel = Instance.new("ImageLabel")
		Dots.BackgroundTransparency = 1
		Dots.Image = GetVapeAsset("kingvape/assets/new/overlaydots.png")
		Dots.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		Dots.Position = UDim2.fromOffset(5, 15)
		Dots.Size = UDim2.fromOffset(2, 12)
		Dots.Parent = DotsButton
		local CustomChildren: Frame = Instance.new("Frame")
		CustomChildren.BackgroundTransparency = 1
		CustomChildren.Position = UDim2.fromScale(0, 1)
		CustomChildren.Size = UDim2.new(1, 0, 0, 200)
		CustomChildren.Parent = Window
		local Children: ScrollingFrame = Instance.new("ScrollingFrame")
		Children.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.02)
		Children.BorderSizePixel = 0
		Children.CanvasSize = UDim2.new()
		Children.Position = UDim2.fromOffset(0, 37)
		Children.Size = UDim2.new(1, 0, 1, -41)
		Children.ScrollBarThickness = 2
		Children.ScrollBarImageTransparency = 0.75
		Children.Visible = false
		Children.Parent = Window
		local Stroke: UIStroke = Instance.new("UIStroke")
		Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		Stroke.Color = Color3.fromRGB(85, 85, 85)
		Stroke.Transparency = 0.8
		Stroke.Parent = Window
		local WindowList: UIListLayout = Instance.new("UIListLayout")
		WindowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		WindowList.SortOrder = Enum.SortOrder.LayoutOrder
		WindowList.Parent = Children
		AddMaid(Component)
		
		function Component:Color(Hue: number, Sat: number, Val: number, IsRainbow: boolean)
		    for _, Option: any in self.Options do
		        if Option.Color then
		            Option:Color(Hue, Sat, Val, IsRainbow)
		        end
		    end
		end
		
		function Component:Expand(VisibleCheck: boolean?)
		    if VisibleCheck and not Blur.Enabled then return end
		
		    self.Expanded = not self.Expanded
		    Children.Visible = self.Expanded
		    Dots.ImageColor3 = self.Expanded and UIPallet.Text or Color.Light(UIPallet.Main, 0.37)
		
		    if self.Expanded then
		        Window.Size = UDim2.fromOffset(Window.Size.X.Offset, math.min(41 + WindowList.AbsoluteContentSize.Y / Scale.Scale, 601))
		    else
		        Window.Size = UDim2.fromOffset(Window.Size.X.Offset, 41)
		    end
		end
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    vape:LoadOptions(self, Data.Options)
		
		    if self.Button.Enabled ~= (Data.Enabled or false) then
		        self.Button:Toggle()
		    end
		
		    if self.Pinned ~= (Data.Pinned or false) then
		        self:Pin()
		        self:Update()
		    end
		
		    if Data.Position then
		        Window.Position = UDim2.fromOffset(Data.Position.X, Data.Position.Y)
		    end
		end
		
		function Component:Pin()
		    self.Pinned = not self.Pinned
		    Pin.ImageColor3 = self.Pinned and UIPallet.Text or Color.Dark(UIPallet.Text, 0.43)
		    vape:QueueSave()
		end
		
		function Component:Save(Data)
		    Data[Props.Name] = {
		        Enabled = self.Button.Enabled,
		        Options = vape:SaveOptions(self),
		        Pinned = self.Pinned,
		        Position = {
		            X = Window.Position.X.Offset,
		            Y = Window.Position.Y.Offset
		        }
		    }
		end
		
		function Component:Update()
		    Window.Visible = self.Button.Enabled and (ClickGUI.Visible or self.Pinned)
		    if self.Expanded then
		        self:Expand()
		    end
		
		    if ClickGUI.Visible then
		        Window.Size = UDim2.fromOffset(Window.Size.X.Offset, 41)
		        Window.BackgroundTransparency = 0
		        Blur.Enabled = true
		        Stroke.Enabled = true
		        Icon.Visible = true
		        Title.Visible = true
		        Pin.Visible = true
		        DotsButton.Visible = true
		    else
		        Window.Size = UDim2.fromOffset(Window.Size.X.Offset, 0)
		        Window.BackgroundTransparency = 1
		        Blur.Enabled = false
		        Stroke.Enabled = false
		        Icon.Visible = false
		        Title.Visible = false
		        Pin.Visible = false
		        DotsButton.Visible = false
		    end
		end
		
		for ComponentName: string, Constructor: (...any) -> ...any in Components do
		    Component[`Create{ComponentName}`] = function(_, Properties)
		        return Constructor(Properties, Children, Component)
		    end
		end
		
		vape:Clean(ClickGUI:GetPropertyChangedSignal("Visible"):Connect(function()
		    Component:Update()
		end))
		
		DotsButton.MouseEnter:Connect(function()
		    if not Children.Visible then
		        Dots.ImageColor3 = UIPallet.Text
		    end
		end)
		
		DotsButton.MouseLeave:Connect(function()
		    if not Children.Visible then
		        Dots.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		    end
		end)
		
		DotsButton.MouseButton1Click:Connect(function()
		    Component:Expand(true)
		end)
		
		DotsButton.MouseButton2Click:Connect(function()
		    Component:Expand(true)
		end)
		
		Pin.MouseButton1Click:Connect(function()
		    Component:Pin()
		end)
		
		Window.MouseButton2Click:Connect(function()
		    Component:Expand(true)
		end)
		
		WindowList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    Children.CanvasSize = UDim2.fromOffset(0, WindowList.AbsoluteContentSize.Y / Scale.Scale)
		    if Component.Expanded then
		        Window.Size = UDim2.fromOffset(Window.Size.X.Offset, math.min(41 + WindowList.AbsoluteContentSize.Y / Scale.Scale, 601))
		    end
		end)
		
		Component.Children = CustomChildren
		vape.Categories[Props.Name] = Component
		
		return Component
	end,
	OverlayBar = function(Props, Children, API)
		local Component = {
		    Options = {},
		    Type = "OverlayBar"
		}
		
		local Bar: Frame = Instance.new("Frame")
		Bar.Name = "Overlays"
		Bar.Size = UDim2.fromOffset(220, 36)
		Bar.BackgroundColor3 = UIPallet.Main
		Bar.BorderSizePixel = 0
		Bar.Parent = Children
		Components.Divider(nil, Bar)
		local Button: ImageButton = Instance.new("ImageButton")
		Button.AutoButtonColor = false
		Button.BackgroundTransparency = 1
		Button.Image = GetVapeAsset("kingvape/assets/new/overlays.png")
		Button.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		Button.Position = UDim2.new(1, -34, 0, 7)
		Button.Size = UDim2.fromOffset(24, 24)
		Button.Parent = Bar
		AddCorner(Button, UDim.new(1, 0))
		AddTooltip(Button, "Open overlays menu")
		local Favorites: ImageButton = Instance.new("ImageButton")
		Favorites.AutoButtonColor = false
		Favorites.BackgroundTransparency = 1
		Favorites.Name = "Favorites"
		Favorites.Position = UDim2.new(1, -58, 0, 7)
		Favorites.Size = UDim2.fromOffset(24, 24)
		Favorites.Parent = Bar
		AddCorner(Favorites, UDim.new(1, 0))
		AddTooltip(Favorites, "Favorites")
		local FavoritesIcon: ImageLabel = Instance.new("ImageLabel")
		FavoritesIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		FavoritesIcon.BackgroundTransparency = 1
		FavoritesIcon.Image = GetVapeAsset("kingvape/assets/new/favoritesicon.png")
		FavoritesIcon.ImageColor3 = VapeColors.Icon
		FavoritesIcon.Name = "Icon"
		FavoritesIcon.Position = UDim2.fromScale(0.5, 0.5)
		FavoritesIcon.ScaleType = Enum.ScaleType.Fit
		FavoritesIcon.Size = UDim2.fromOffset(12, 11)
		FavoritesIcon.Parent = Favorites
		local Shadow: TextButton = Instance.new("TextButton")
		Shadow.AutoButtonColor = false
		Shadow.BackgroundColor3 = Color3.new()
		Shadow.BackgroundTransparency = 1
		Shadow.ClipsDescendants = true
		Shadow.Name = "Shadow"
		Shadow.Size = UDim2.new(1, 0, 1, -5)
		Shadow.Text = ""
		Shadow.Visible = false
		Shadow.Parent = API.Object
		AddCorner(Shadow)
		local Window: Frame = Instance.new("Frame")
		Window.BackgroundColor3 = UIPallet.Main
		Window.Position = UDim2.fromScale(0, 1)
		Window.Size = UDim2.fromOffset(220, 42)
		Window.Parent = Shadow
		AddCorner(Window)
		local Icon: ImageLabel = Instance.new("ImageLabel")
		Icon.BackgroundTransparency = 1
		Icon.Image = GetVapeAsset("kingvape/assets/new/overlayslarge.png")
		Icon.ImageColor3 = UIPallet.Text
		Icon.Position = UDim2.fromOffset(10, 13)
		Icon.Size = UDim2.fromOffset(14, 12)
		Icon.Parent = Window
		local Title: TextLabel = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.FontFace = UIPallet.Font
		Title.Position = UDim2.fromOffset(36, 0)
		Title.Size = UDim2.new(1, -36, 0, 38)
		Title.Text = "Overlays"
		Title.TextColor3 = UIPallet.Text
		Title.TextSize = 15
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Parent = Window
		local Close: ImageButton = AddCloseButton(Window, false, UDim2.new(1, -35, 0, 7))
		local Divider: Frame = Instance.new("Frame")
		Divider.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		Divider.BorderSizePixel = 0
		Divider.Position = UDim2.fromOffset(0, 37)
		Divider.Size = UDim2.new(1, 0, 0, 1)
		Divider.Parent = Window
		local ChildrenToggle: Frame = Instance.new("Frame")
		ChildrenToggle.BackgroundColor3 = UIPallet.Main
		ChildrenToggle.BackgroundTransparency = 1
		ChildrenToggle.Position = UDim2.fromOffset(0, 38)
		ChildrenToggle.Parent = Window
		local WindowList: UIListLayout = Instance.new("UIListLayout")
		WindowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		WindowList.SortOrder = Enum.SortOrder.LayoutOrder
		WindowList.Parent = ChildrenToggle
		
		for ComponentName: string, Constructor: (...any) -> ...any in Components do
		    Component[`Create{ComponentName}`] = function(_, Properties)
		        return Constructor(Properties, ChildrenToggle, Component)
		    end
		end
		
		local function PaintFavorites()
		    local Category = vape.Categories.Favorites
		    FavoritesIcon.ImageColor3 = (Category and Category.Standalone) and VapeColors.Favorite or VapeColors.Icon
		end
		
		vape.PaintFavorites = PaintFavorites
		
		Button.MouseEnter:Connect(function()
		    Button.ImageColor3 = UIPallet.Text
		    Tween:Tween(Button, UIPallet.Tween, {
		        BackgroundTransparency = 0.9
		    })
		end)
		
		Button.MouseLeave:Connect(function()
		    Button.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		    Tween:Tween(Button, UIPallet.Tween, {
		        BackgroundTransparency = 1
		    })
		end)
		
		Button.MouseButton1Click:Connect(function()
		    Shadow.Visible = true
		    Tween:Tween(Shadow, UIPallet.Tween, {
		        BackgroundTransparency = 0.5
		    })
		
		    Tween:Tween(Window, UIPallet.Tween, {
		        Position = UDim2.new(0, 0, 1, -(Window.Size.Y.Offset))
		    })
		end)
		
		Close.MouseButton1Click:Connect(function()
		    Tween:Tween(Shadow, UIPallet.Tween, {
		        BackgroundTransparency = 1
		    })
		
		    Tween:Tween(Window, UIPallet.Tween, {
		        Position = UDim2.fromScale(0, 1)
		    })
		
		    task.delay(0.2, function()
		        if vape.ThreadFix then
		            setthreadidentity(8)
		        end
		
		        Shadow.Visible = false
		    end)
		end)
		
		Favorites.MouseButton1Click:Connect(function()
		    local Category = vape.Categories.Favorites
		    if not Category then return end
		
		    Category:SetStandalone(not Category.Standalone)
		    PaintFavorites()
		    vape:QueueSave()
		end)
		
		Favorites.MouseEnter:Connect(function()
		    local Category = vape.Categories.Favorites
		    FavoritesIcon.ImageColor3 = (Category and Category.Standalone) and Color3.fromRGB(255, 160, 84) or VapeColors.IconHover
		end)
		
		Favorites.MouseLeave:Connect(PaintFavorites)
		
		Shadow.MouseButton1Click:Connect(function()
		    Tween:Tween(Shadow, UIPallet.Tween, {
		        BackgroundTransparency = 1
		    })
		
		    Tween:Tween(Window, UIPallet.Tween, {
		        Position = UDim2.fromScale(0, 1)
		    })
		
		    task.delay(0.2, function()
		        if vape.ThreadFix then
		            setthreadidentity(8)
		        end
		
		        Shadow.Visible = false
		    end)
		end)
		
		WindowList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    Window.Size = UDim2.fromOffset(220, math.min(37 + WindowList.AbsoluteContentSize.Y / Scale.Scale, 605))
		    ChildrenToggle.Size = UDim2.fromOffset(220, Window.Size.Y.Offset - 5)
		end)
		
		vape.Overlays = Component
		
		return Component
	end,
	PublicProfiles = function(Props, Children, API)
		local Component = {Configs = {}, Cards = {}, Owned = {}, Accents = {}, Sort = "rated", Search = ""}
		
		local function AccentColor()
		    local GUIColor = vape.GUIColor
		    if not GUIColor then return Color3.fromRGB(5, 133, 102) end
		    return Color3.fromHSV(GUIColor.Hue, GUIColor.Sat, GUIColor.Value)
		end
		
		local function AccentTextColor()
		    local GUIColor = vape.GUIColor
		    if not GUIColor then return Color3.new(1, 1, 1) end
		    return vape:TextColor(GUIColor.Hue, GUIColor.Sat, GUIColor.Value)
		end
		
		local Sorts = {
		    rated = function(A, B)
		        if (A.likes or 0) == (B.likes or 0) then
		            return A.Uploaded > B.Uploaded
		        end
		
		        return (A.likes or 0) > (B.likes or 0)
		    end,
		    downloaded = function(A, B)
		        if (A.downloads or 0) == (B.downloads or 0) then
		            return A.Uploaded > B.Uploaded
		        end
		
		        return (A.downloads or 0) > (B.downloads or 0)
		    end,
		    newest = function(A, B)
		        return A.Uploaded > B.Uploaded
		    end
		}
		
		local Window: Frame = Instance.new("Frame")
		Window.BackgroundColor3 = UIPallet.Main
		Window.Name = "PublicProfilesGUI"
		Window.Position = UDim2.new(0.5, -356, 0.5, -214)
		Window.Size = UDim2.fromOffset(712, 428)
		Window.Visible = false
		Window.Parent = ScaledGUI
		AddShadow(Window)
		AddCorner(Window)
		AddDragHandler(Window)
		local Modal: TextButton = Instance.new("TextButton")
		Modal.BackgroundTransparency = 1
		Modal.Modal = true
		Modal.Text = ""
		Modal.Parent = Window
		local Icon: ImageLabel = Instance.new("ImageLabel")
		Icon.BackgroundTransparency = 1
		Icon.Name = "Icon"
		Icon.Position = UDim2.fromOffset(10, 13)
		Icon.Size = UDim2.fromOffset(16, 10)
		Icon.Image = GetVapeAsset("kingvape/assets/new/profilesicon.png")
		Icon.ImageColor3 = VapeColors.Primary
		Icon.Parent = Window
		local Title: TextLabel = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.FontFace = UIPallet.Font
		Title.Name = "Title"
		Title.Position = UDim2.fromOffset(36, 0)
		Title.Size = UDim2.fromOffset(200, 36)
		Title.Text = "Public Profiles"
		Title.TextColor3 = VapeColors.Primary
		Title.TextSize = 14
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Parent = Window
		local Close: ImageButton = AddCloseButton(Window, false, UDim2.new(1, -35, 0, 6))
		local Divider: Frame = Instance.new("Frame")
		Divider.BackgroundColor3 = VapeColors.Outline
		Divider.BackgroundTransparency = 0.5
		Divider.BorderSizePixel = 0
		Divider.Name = "Divider"
		Divider.Position = UDim2.fromOffset(0, 38)
		Divider.Size = UDim2.new(1, 0, 0, 1)
		Divider.Parent = Window
		
		local OwnedLabel: TextLabel = Instance.new("TextLabel")
		OwnedLabel.BackgroundTransparency = 1
		OwnedLabel.FontFace = UIPallet.FontBold
		OwnedLabel.Name = "OwnedLabel"
		OwnedLabel.Position = UDim2.fromOffset(12, 44)
		OwnedLabel.Size = UDim2.fromOffset(174, 24)
		OwnedLabel.Text = "YOUR PUBLIC PROFILES"
		OwnedLabel.TextColor3 = VapeColors.Muted
		OwnedLabel.TextSize = 11
		OwnedLabel.TextXAlignment = Enum.TextXAlignment.Left
		OwnedLabel.Parent = Window
		
		local Collapse: TextButton = Instance.new("TextButton")
		Collapse.AutoButtonColor = false
		Collapse.BackgroundTransparency = 1
		Collapse.Name = "Collapse"
		Collapse.Position = UDim2.fromOffset(176, 48)
		Collapse.Size = UDim2.fromOffset(20, 24)
		Collapse.Text = ""
		Collapse.Parent = Window
		local CollapseIcon: ImageLabel = Instance.new("ImageLabel")
		CollapseIcon.AnchorPoint = Vector2.new(0.5, 0)
		CollapseIcon.BackgroundTransparency = 1
		CollapseIcon.Image = GetVapeAsset("kingvape/assets/new/hide.png")
		CollapseIcon.ImageColor3 = VapeColors.Icon
		CollapseIcon.Position = UDim2.fromOffset(10, 0)
		CollapseIcon.Size = UDim2.fromOffset(10, 8)
		CollapseIcon.Parent = Collapse
		AddTooltip(Collapse, "Hide your published profiles")
		
		local Publish: TextButton = Instance.new("TextButton")
		Publish.AutoButtonColor = false
		Publish.BackgroundColor3 = AccentColor()
		Publish.FontFace = UIPallet.FontBold
		Publish.Name = "Publish"
		Publish.Position = UDim2.fromOffset(12, 72)
		Publish.Size = UDim2.fromOffset(184, 28)
		Publish.Text = "CREATE NEW"
		Publish.TextColor3 = AccentTextColor()
		Publish.TextSize = 11
		Publish.Parent = Window
		AddCorner(Publish, UDim.new(0, 4))
		table.insert(Component.Accents, Publish)
		
		local Owned: ScrollingFrame = Instance.new("ScrollingFrame")
		Owned.BackgroundTransparency = 1
		Owned.BorderSizePixel = 0
		Owned.CanvasSize = UDim2.new()
		Owned.Name = "Owned"
		Owned.Position = UDim2.fromOffset(12, 104)
		Owned.ScrollBarThickness = 0
		Owned.Size = UDim2.fromOffset(184, 318)
		Owned.Parent = Window
		local OwnedLayout: UIListLayout = Instance.new("UIListLayout")
		OwnedLayout.Padding = UDim.new(0, 4)
		OwnedLayout.SortOrder = Enum.SortOrder.LayoutOrder
		OwnedLayout.Parent = Owned
		
		local OwnedEmpty: TextLabel = Instance.new("TextLabel")
		OwnedEmpty.BackgroundTransparency = 1
		OwnedEmpty.FontFace = UIPallet.Font
		OwnedEmpty.Name = "OwnedEmpty"
		OwnedEmpty.Position = UDim2.fromOffset(12, 108)
		OwnedEmpty.Size = UDim2.fromOffset(184, 20)
		OwnedEmpty.Text = "Nothing published yet"
		OwnedEmpty.TextColor3 = VapeColors.Muted
		OwnedEmpty.TextSize = 12
		OwnedEmpty.TextXAlignment = Enum.TextXAlignment.Left
		OwnedEmpty.Visible = false
		OwnedEmpty.Parent = Window
		
		local ResultsLabel: TextLabel = Instance.new("TextLabel")
		ResultsLabel.BackgroundTransparency = 1
		ResultsLabel.FontFace = UIPallet.FontBold
		ResultsLabel.Name = "ResultsLabel"
		ResultsLabel.Position = UDim2.fromOffset(216, 44)
		ResultsLabel.Size = UDim2.fromOffset(300, 14)
		ResultsLabel.Text = "ALL PUBLIC PROFILES"
		ResultsLabel.TextColor3 = VapeColors.Muted
		ResultsLabel.TextSize = 11
		ResultsLabel.TextXAlignment = Enum.TextXAlignment.Left
		ResultsLabel.Parent = Window
		
		local SearchBackground: Frame = Instance.new("Frame")
		SearchBackground.BackgroundTransparency = 1
		SearchBackground.BorderSizePixel = 0
		SearchBackground.Name = "Search"
		SearchBackground.Position = UDim2.fromOffset(216, 67)
		SearchBackground.Size = UDim2.fromOffset(478, 40)
		SearchBackground.Parent = Window
		AddCorner(SearchBackground, UDim.new(0, 4))
		local SearchStroke: UIStroke = Instance.new("UIStroke")
		SearchStroke.Color = VapeColors.Outline
		SearchStroke.Thickness = 1.5
		SearchStroke.Transparency = 0.25
		SearchStroke.Parent = SearchBackground
		local SearchIcon: ImageLabel = Instance.new("ImageLabel")
		SearchIcon.AnchorPoint = Vector2.new(0.5, 0.5)
		SearchIcon.BackgroundTransparency = 1
		SearchIcon.BorderSizePixel = 0
		SearchIcon.Image = GetVapeAsset("kingvape/assets/new/search.png")
		SearchIcon.ImageColor3 = VapeColors.Icon
		SearchIcon.Position = UDim2.new(0, 18, 0.5, 0)
		SearchIcon.Size = UDim2.fromOffset(12, 12)
		SearchIcon.Parent = SearchBackground
		local SearchBox: TextBox = Instance.new("TextBox")
		SearchBox.BackgroundTransparency = 1
		SearchBox.BorderSizePixel = 0
		SearchBox.ClearTextOnFocus = false
		SearchBox.FontFace = UIPallet.Font
		SearchBox.PlaceholderColor3 = VapeColors.Primary
		SearchBox.PlaceholderText = "Search Profile / Username"
		SearchBox.Position = UDim2.fromOffset(38, 0)
		SearchBox.Size = UDim2.new(1, -58, 1, 0)
		SearchBox.Text = ""
		SearchBox.TextColor3 = VapeColors.Secondary
		SearchBox.TextSize = 13
		SearchBox.TextXAlignment = Enum.TextXAlignment.Left
		SearchBox.Parent = SearchBackground
		
		local SortFrame: Frame = Instance.new("Frame")
		SortFrame.BackgroundTransparency = 1
		SortFrame.BorderSizePixel = 0
		SortFrame.Name = "Sorts"
		SortFrame.Position = UDim2.fromOffset(216, 119)
		SortFrame.Size = UDim2.fromOffset(480, 28)
		SortFrame.Parent = Window
		local SortLayout: UIListLayout = Instance.new("UIListLayout")
		SortLayout.FillDirection = Enum.FillDirection.Horizontal
		SortLayout.Padding = UDim.new(0, 2)
		SortLayout.SortOrder = Enum.SortOrder.LayoutOrder
		SortLayout.Parent = SortFrame
		
		local Children: ScrollingFrame = Instance.new("ScrollingFrame")
		Children.BackgroundTransparency = 1
		Children.BorderSizePixel = 0
		Children.CanvasSize = UDim2.new()
		Children.Name = "Children"
		Children.Position = UDim2.fromOffset(216, 161)
		Children.ScrollBarImageColor3 = VapeColors.Outline
		Children.ScrollBarImageTransparency = 0.5
		Children.ScrollBarThickness = 4
		Children.Size = UDim2.fromOffset(482, 267)
		Children.Parent = Window
		local GridLayout: UIGridLayout = Instance.new("UIGridLayout")
		GridLayout.CellPadding = UDim2.fromOffset(6, 6)
		GridLayout.CellSize = UDim2.fromOffset(156, 144)
		GridLayout.SortOrder = Enum.SortOrder.LayoutOrder
		GridLayout.Parent = Children
		
		local Empty: TextLabel = Instance.new("TextLabel")
		Empty.BackgroundTransparency = 1
		Empty.FontFace = UIPallet.Font
		Empty.Name = "Empty"
		Empty.Position = UDim2.fromOffset(216, 255)
		Empty.Size = UDim2.fromOffset(482, 20)
		Empty.Text = "No profiles found"
		Empty.TextColor3 = VapeColors.Secondary
		Empty.TextSize = 12
		Empty.Visible = false
		Empty.Parent = Window
		
		local function SetCollapsed(State: boolean)
		    Component.Collapsed = State
		    OwnedLabel.Visible = not State
		    Publish.Visible = not State
		    Owned.Visible = not State
		    OwnedEmpty.Visible = not State and #Component.Owned == 0
		    CollapseIcon.Image = GetVapeAsset(`kingvape/assets/new/{State and "show" or "hide"}.png`)
		    Collapse.Position = UDim2.fromOffset(State and 12 or 176, 48)
		    ResultsLabel.Position = UDim2.fromOffset(State and 50 or 216, 44)
		    SearchBackground.Position = UDim2.fromOffset(State and 50 or 216, 67)
		    SearchBackground.Size = UDim2.fromOffset(State and 646 or 478, 40)
		    SortFrame.Position = UDim2.fromOffset(State and 50 or 216, 119)
		    Children.Position = UDim2.fromOffset(State and 50 or 216, 161)
		    Children.Size = UDim2.fromOffset(State and 648 or 482, 267)
		    Empty.Position = UDim2.fromOffset(State and 50 or 216, 255)
		end
		
		Component.Window = Window
		table.insert(vape.Windows, Window)
		
		local Overlay: TextButton = Instance.new("TextButton")
		Overlay.AutoButtonColor = false
		Overlay.BackgroundColor3 = Color3.new()
		Overlay.BackgroundTransparency = 0.49
		Overlay.Name = "Overlay"
		Overlay.Size = UDim2.fromScale(1, 1)
		Overlay.Text = ""
		Overlay.Visible = false
		Overlay.ZIndex = 4
		Overlay.Parent = Window
		AddCorner(Overlay)
		
		local function MakePanel(Name: string, Height: number, Width: number?)
		    local Panel: Frame = Instance.new("Frame")
		    Panel.AnchorPoint = Vector2.new(0.5, 0.5)
		    Panel.BackgroundColor3 = Color3.fromRGB(33, 32, 33)
		    Panel.Name = Name
		    Panel.Position = UDim2.fromScale(0.5, 0.5)
		    Panel.Size = UDim2.fromOffset(Width or 440, Height)
		    Panel.Visible = false
		    Panel.ZIndex = 5
		    Panel.Parent = Window
		    AddShadow(Panel)
		    AddCorner(Panel)
		    local Stroke: UIStroke = Instance.new("UIStroke")
		    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		    Stroke.Color = Color3.fromRGB(42, 40, 42)
		    Stroke.Parent = Panel
		    return Panel
		end
		
		local function MakeAction(Parent: Instance, Text: string, Accent: boolean, Y: number, Width: number, X: number)
		    local Button: TextButton = Instance.new("TextButton")
		    Button.AutoButtonColor = false
		    Button.BackgroundColor3 = Accent and AccentColor() or VapeColors.Panel
		    Button.BackgroundTransparency = Accent and 0 or 1
		    Button.FontFace = UIPallet.FontBold
		    Button.Position = UDim2.fromOffset(X, Y)
		    Button.Size = UDim2.fromOffset(Width, 30)
		    Button.Text = Text
		    Button.TextColor3 = Accent and AccentTextColor() or VapeColors.Secondary
		    Button.TextSize = 13
		    Button.ZIndex = 6
		    Button.Parent = Parent
		    AddCorner(Button, UDim.new(0, 4))
		    if Accent then
		        table.insert(Component.Accents, Button)
		    end
		
		    return Button
		end
		
		local Details: Frame = MakePanel("Details", 338, 672)
		Details.BackgroundColor3 = UIPallet.Main
		local Sidebar: Frame = Instance.new("Frame")
		Sidebar.BackgroundColor3 = UIPallet.Main
		Sidebar.BorderSizePixel = 0
		Sidebar.Name = "Sidebar"
		Sidebar.Size = UDim2.fromOffset(224, 338)
		Sidebar.ZIndex = 6
		Sidebar.Parent = Details
		AddCorner(Sidebar)
		
		local DetailName: TextLabel = Instance.new("TextLabel")
		DetailName.BackgroundTransparency = 1
		DetailName.FontFace = UIPallet.FontSemiBold
		DetailName.Position = UDim2.fromOffset(16, 16)
		DetailName.Size = UDim2.fromOffset(192, 24)
		DetailName.Text = ""
		DetailName.TextColor3 = Color3.new(1, 1, 1)
		DetailName.TextSize = 18
		DetailName.TextTruncate = Enum.TextTruncate.AtEnd
		DetailName.TextXAlignment = Enum.TextXAlignment.Left
		DetailName.ZIndex = 7
		DetailName.Parent = Sidebar
		
		local Avatar: ImageLabel = Instance.new("ImageLabel")
		Avatar.BackgroundColor3 = Color.Light(UIPallet.Main, 0.06)
		Avatar.Image = AvatarPlaceholder
		Avatar.Position = UDim2.fromOffset(16, 48)
		Avatar.Size = UDim2.fromOffset(20, 20)
		Avatar.ZIndex = 7
		Avatar.Parent = Sidebar
		AddCorner(Avatar, UDim.new(1, 0))
		
		local DetailAuthor: TextLabel = Instance.new("TextLabel")
		DetailAuthor.BackgroundTransparency = 1
		DetailAuthor.FontFace = UIPallet.FontBold
		DetailAuthor.Position = UDim2.fromOffset(44, 48)
		DetailAuthor.Size = UDim2.fromOffset(160, 20)
		DetailAuthor.Text = ""
		DetailAuthor.TextColor3 = Color3.fromRGB(171, 171, 171)
		DetailAuthor.TextSize = 12
		DetailAuthor.TextTruncate = Enum.TextTruncate.AtEnd
		DetailAuthor.TextXAlignment = Enum.TextXAlignment.Left
		DetailAuthor.ZIndex = 7
		DetailAuthor.Parent = Sidebar
		
		local function ClearList(Container: Instance)
		    for _, v: Instance in Container:GetChildren() do
		        if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then
		            v:Destroy()
		        end
		    end
		end
		
		local function AddRow(Parent: Instance, Text: string, Y: number, IsSelected: boolean?, OnClick, Order: number?)
		    local Row = OnClick and Instance.new("TextButton") or Instance.new("Frame")
		    Row.LayoutOrder = Order or 0
		    if OnClick then
		        Row.AutoButtonColor = false
		        Row.Text = ""
		        Row.MouseButton1Click:Connect(function()
		            OnClick(Row)
		        end)
		    end
		    Row.BackgroundColor3 = Color.Light(UIPallet.Main, 0.05)
		    Row.BackgroundTransparency = IsSelected and 0 or 1
		    Row.BorderSizePixel = 0
		    Row.Position = UDim2.fromOffset(0, Y)
		    Row.Size = UDim2.fromOffset(224, 36)
		    Row.ZIndex = 7
		    Row.Parent = Parent
		    local RowText: TextLabel = Instance.new("TextLabel")
		    RowText.BackgroundTransparency = 1
		    RowText.FontFace = UIPallet.Font
		    RowText.Position = UDim2.fromOffset(16, 0)
		    RowText.Size = UDim2.fromOffset(174, 36)
		    RowText.Text = Text
		    RowText.TextColor3 = IsSelected and Color3.new(1, 1, 1) or Color3.fromRGB(171, 171, 171)
		    RowText.TextSize = 13
		    RowText.TextTruncate = Enum.TextTruncate.AtEnd
		    RowText.TextXAlignment = Enum.TextXAlignment.Left
		    RowText.ZIndex = 8
		    RowText.Parent = Row
		    local Chevron: TextLabel = Instance.new("TextLabel")
		    Chevron.BackgroundTransparency = 1
		    Chevron.FontFace = UIPallet.Font
		    Chevron.Position = UDim2.fromOffset(196, 0)
		    Chevron.Size = UDim2.fromOffset(20, 36)
		    Chevron.Text = ">"
		    Chevron.TextColor3 = Color3.fromRGB(120, 120, 120)
		    Chevron.TextSize = 13
		    Chevron.ZIndex = 8
		    Chevron.Parent = Row
		    return Row
		end
		
		local function FillModules(List: ScrollingFrame, Count: TextLabel, Source: string?, OnClick)
		    ClearList(List)
		
		    local Active, Rows = {}, {}
		    local Decoded = Source and select(2, pcall(HttpService.JSONDecode, HttpService, Source))
		    for ModuleName: any, v: any in (type(Decoded) == "table" and Decoded.Modules or {}) do
		        if type(v) == "table" and v.Enabled then
		            table.insert(Active, tostring(ModuleName))
		        end
		    end
		    table.sort(Active)
		
		    Count.Text = `<font color="rgb(255,255,255)">{#Active}</font> AFFECTED MODULES`
		    for i: number, ModuleName: string in Active do
		        Rows[ModuleName] = AddRow(List, ModuleName, 0, false, OnClick and function()
		            OnClick(ModuleName)
		        end or nil, i)
		    end
		    List.CanvasSize = UDim2.fromOffset(0, #Active * 36)
		
		    return Decoded, Rows
		end
		
		local DetailsRow
		
		local ModuleCount: TextLabel = Instance.new("TextLabel")
		ModuleCount.BackgroundTransparency = 1
		ModuleCount.FontFace = UIPallet.FontBold
		ModuleCount.Position = UDim2.fromOffset(16, 126)
		ModuleCount.RichText = true
		ModuleCount.Size = UDim2.fromOffset(192, 16)
		ModuleCount.Text = ""
		ModuleCount.TextColor3 = Color3.fromRGB(171, 171, 171)
		ModuleCount.TextSize = 11
		ModuleCount.TextXAlignment = Enum.TextXAlignment.Left
		ModuleCount.ZIndex = 7
		ModuleCount.Parent = Sidebar
		
		local ModuleList: ScrollingFrame = Instance.new("ScrollingFrame")
		ModuleList.BackgroundTransparency = 1
		ModuleList.BorderSizePixel = 0
		ModuleList.CanvasSize = UDim2.new()
		ModuleList.Name = "Modules"
		ModuleList.Position = UDim2.fromOffset(0, 148)
		ModuleList.ScrollBarThickness = 0
		ModuleList.Size = UDim2.fromOffset(224, 182)
		ModuleList.ZIndex = 7
		ModuleList.Parent = Sidebar
		local ModuleLayout: UIListLayout = Instance.new("UIListLayout")
		ModuleLayout.Padding = UDim.new(0, 0)
		ModuleLayout.SortOrder = Enum.SortOrder.LayoutOrder
		ModuleLayout.Parent = ModuleList
		
		local DetailTitle: TextLabel = Instance.new("TextLabel")
		DetailTitle.BackgroundTransparency = 1
		DetailTitle.FontFace = UIPallet.FontBold
		DetailTitle.Position = UDim2.fromOffset(244, 22)
		DetailTitle.Size = UDim2.fromOffset(200, 20)
		DetailTitle.Text = "Details"
		DetailTitle.TextColor3 = VapeColors.Primary
		DetailTitle.TextSize = 14
		DetailTitle.TextXAlignment = Enum.TextXAlignment.Left
		DetailTitle.ZIndex = 6
		DetailTitle.Parent = Details
		
		local Created: TextLabel = Instance.new("TextLabel")
		Created.BackgroundTransparency = 1
		Created.FontFace = UIPallet.Font
		Created.Position = UDim2.fromOffset(244, 62)
		Created.Size = UDim2.fromOffset(412, 18)
		Created.Text = ""
		Created.TextColor3 = VapeColors.Muted
		Created.TextSize = 13
		Created.TextXAlignment = Enum.TextXAlignment.Left
		Created.ZIndex = 6
		Created.Parent = Details
		
		local function AddStat(X: number, Width: number, Label: string)
		    local Box: Frame = Instance.new("Frame")
		    Box.BackgroundColor3 = Color3.new(1, 1, 1)
		    Box.BackgroundTransparency = 0.98
		    Box.BorderSizePixel = 0
		    Box.Position = UDim2.fromOffset(X, 96)
		    Box.Size = UDim2.fromOffset(Width, 58)
		    Box.ZIndex = 6
		    Box.Parent = Details
		    AddCorner(Box, UDim.new(0, 3))
		    local Value: TextLabel = Instance.new("TextLabel")
		    Value.BackgroundTransparency = 1
		    Value.FontFace = UIPallet.FontBold
		    Value.Position = UDim2.fromOffset(0, 11)
		    Value.Size = UDim2.new(1, 0, 0, 20)
		    Value.Text = ""
		    Value.TextColor3 = VapeColors.Primary
		    Value.TextSize = 14
		    Value.ZIndex = 7
		    Value.Parent = Box
		    local Caption: TextLabel = Instance.new("TextLabel")
		    Caption.BackgroundTransparency = 1
		    Caption.FontFace = UIPallet.FontBold
		    Caption.Position = UDim2.fromOffset(0, 33)
		    Caption.Size = UDim2.new(1, 0, 0, 14)
		    Caption.Text = Label
		    Caption.TextColor3 = Color3.fromRGB(115, 113, 115)
		    Caption.TextSize = 10
		    Caption.ZIndex = 7
		    Caption.Parent = Box
		
		    return Box, Value
		end
		
		local LikesBox, LikesValue = AddStat(245, 131, "Positive reviews")
		local UpdatedBox, UpdatedValue = AddStat(384, 131, "Last updated")
		local DownloadsBox, DownloadsValue = AddStat(523, 131, "Downloads")
		
		local DetailDescription: TextLabel = Instance.new("TextLabel")
		DetailDescription.BackgroundTransparency = 1
		DetailDescription.FontFace = UIPallet.Font
		DetailDescription.Position = UDim2.fromOffset(244, 174)
		DetailDescription.Size = UDim2.fromOffset(412, 80)
		DetailDescription.Text = ""
		DetailDescription.TextColor3 = VapeColors.Secondary
		DetailDescription.TextSize = 13
		DetailDescription.TextWrapped = true
		DetailDescription.TextXAlignment = Enum.TextXAlignment.Left
		DetailDescription.TextYAlignment = Enum.TextYAlignment.Top
		DetailDescription.ZIndex = 6
		DetailDescription.Parent = Details
		
		local ModuleTitle: TextLabel = Instance.new("TextLabel")
		ModuleTitle.BackgroundTransparency = 1
		ModuleTitle.FontFace = UIPallet.FontSemiBold
		ModuleTitle.Position = UDim2.fromOffset(244, 20)
		ModuleTitle.Size = UDim2.fromOffset(412, 26)
		ModuleTitle.Text = ""
		ModuleTitle.TextColor3 = Color3.new(1, 1, 1)
		ModuleTitle.TextSize = 18
		ModuleTitle.TextXAlignment = Enum.TextXAlignment.Left
		ModuleTitle.Visible = false
		ModuleTitle.ZIndex = 6
		ModuleTitle.Parent = Details
		
		local OptionList: ScrollingFrame = Instance.new("ScrollingFrame")
		OptionList.BackgroundTransparency = 1
		OptionList.BorderSizePixel = 0
		OptionList.CanvasSize = UDim2.new()
		OptionList.Name = "Options"
		OptionList.Position = UDim2.fromOffset(244, 52)
		OptionList.ScrollBarThickness = 0
		OptionList.Size = UDim2.fromOffset(412, 212)
		OptionList.Visible = false
		OptionList.ZIndex = 6
		OptionList.Parent = Details
		local OptionLayout: UIListLayout = Instance.new("UIListLayout")
		OptionLayout.Padding = UDim.new(0, 0)
		OptionLayout.SortOrder = Enum.SortOrder.LayoutOrder
		OptionLayout.Parent = OptionList
		
		local DetailView: {GuiObject} = {DetailTitle, Created, LikesBox, UpdatedBox, DownloadsBox, DetailDescription}
		local SelectModule
		local UploadSource: string?
		
		local function ShowDetails(ShowModule: boolean)
		    for _, v: GuiObject in DetailView do
		        v.Visible = not ShowModule
		    end
		    ModuleTitle.Visible = ShowModule
		    OptionList.Visible = ShowModule
		end
		
		local function FormatOption(Value)
		    if type(Value) ~= "table" then return tostring(Value) end
		    if Value.List then return `{#Value.List} items` end
		    if Value.Value ~= nil then
		        if type(Value.Value) == "number" then
		            return tostring(math.floor(Value.Value * 10 + 0.5) / 10)
		        end
		
		        return tostring(Value.Value)
		    end
		    if Value.Min and Value.Max then
		        return `{math.floor(Value.Min * 10 + 0.5) / 10} - {math.floor(Value.Max * 10 + 0.5) / 10}`
		    end
		    if Value.Enabled ~= nil then return Value.Enabled and "ON" or "OFF" end
		
		    local EnabledCount: number = 0
		    for _, v: any in Value do
		        if v == true then EnabledCount += 1 end
		    end
		
		    return EnabledCount > 0 and `{EnabledCount} on` or "-"
		end
		
		local function AddOptionRow(Parent: Instance, Name: string, Value, Index: number)
		    local Row: Frame = Instance.new("Frame")
		    Row.BackgroundTransparency = 1
		    Row.LayoutOrder = Index
		    Row.Size = UDim2.fromOffset(412, 30)
		    Row.ZIndex = 7
		    Row.Parent = Parent
		    local Label: TextLabel = Instance.new("TextLabel")
		    Label.BackgroundTransparency = 1
		    Label.FontFace = UIPallet.Font
		    Label.Size = UDim2.fromOffset(282, 30)
		    Label.Text = Name
		    Label.TextColor3 = Color3.fromRGB(171, 171, 171)
		    Label.TextSize = 13
		    Label.TextTruncate = Enum.TextTruncate.AtEnd
		    Label.TextXAlignment = Enum.TextXAlignment.Left
		    Label.ZIndex = 8
		    Label.Parent = Row
		    local Text: string = FormatOption(Value)
		    local Pill: Frame = Instance.new("Frame")
		    Pill.BackgroundColor3 = Color.Light(UIPallet.Main, 0.06)
		    Pill.BorderSizePixel = 0
		    Pill.Position = UDim2.new(1, -math.max(#Text * 7 + 16, 34), 0, 5)
		    Pill.Size = UDim2.fromOffset(math.max(#Text * 7 + 16, 34), 20)
		    Pill.ZIndex = 8
		    Pill.Parent = Row
		    AddCorner(Pill, UDim.new(0, 4))
		    local PillText: TextLabel = Instance.new("TextLabel")
		    PillText.BackgroundTransparency = 1
		    PillText.FontFace = UIPallet.Font
		    PillText.Size = UDim2.fromScale(1, 1)
		    PillText.Text = Text
		    PillText.TextColor3 = Color3.fromRGB(200, 200, 200)
		    PillText.TextSize = 11
		    PillText.ZIndex = 9
		    PillText.Parent = Pill
		end
		
		DetailsRow = AddRow(Sidebar, "Details", 80, true, function()
		    if SelectModule then
		        SelectModule(nil)
		    end
		end)
		
		local Download: TextButton = MakeAction(Details, "Download", true, 289, 288, 374)
		
		local function AddThumb(Parent: Instance, Flipped: boolean)
		    local Thumb: ImageLabel = Instance.new("ImageLabel")
		    Thumb.AnchorPoint = Vector2.new(0.5, 0.5)
		    Thumb.BackgroundTransparency = 1
		    Thumb.Image = GetVapeAsset(`kingvape/assets/new/{Flipped and "dislike" or "like"}.png`)
		    Thumb.ImageColor3 = VapeColors.Icon
		    Thumb.Name = "Thumb"
		    Thumb.Position = UDim2.fromScale(0.5, 0.5)
		    Thumb.Size = UDim2.fromOffset(13, 11)
		    Thumb.ZIndex = 8
		    Thumb.Parent = Parent
		
		    return Thumb
		end
		
		local VoteFrame: Frame = Instance.new("Frame")
		VoteFrame.BackgroundTransparency = 1
		VoteFrame.BorderSizePixel = 0
		VoteFrame.ClipsDescendants = true
		VoteFrame.Name = "Votes"
		VoteFrame.Position = UDim2.fromOffset(254, 289)
		VoteFrame.Size = UDim2.fromOffset(90, 30)
		VoteFrame.ZIndex = 6
		VoteFrame.Parent = Details
		AddCorner(VoteFrame, UDim.new(0, 3))
		local VoteStroke: UIStroke = Instance.new("UIStroke")
		VoteStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		VoteStroke.Color = VapeColors.Outline
		VoteStroke.Transparency = 0.5
		VoteStroke.Parent = VoteFrame
		
		local VoteDivider: Frame = Instance.new("Frame")
		VoteDivider.BackgroundColor3 = VapeColors.Outline
		VoteDivider.BackgroundTransparency = 0.5
		VoteDivider.BorderSizePixel = 0
		VoteDivider.Name = "Divider"
		VoteDivider.Position = UDim2.fromOffset(45, 0)
		VoteDivider.Size = UDim2.fromOffset(1, 30)
		VoteDivider.ZIndex = 8
		VoteDivider.Parent = VoteFrame
		
		local function AddVote(Name: string, X: number, Width: number, Flipped: boolean)
		    local Button: TextButton = Instance.new("TextButton")
		    Button.AutoButtonColor = false
		    Button.BackgroundColor3 = Color.Light(UIPallet.Main, 0.0875)
		    Button.BackgroundTransparency = 1
		    Button.Name = Name
		    Button.Position = UDim2.fromOffset(X, 0)
		    Button.Size = UDim2.fromOffset(Width, 30)
		    Button.Text = ""
		    Button.ZIndex = 7
		    Button.Parent = VoteFrame
		
		    Button.MouseEnter:Connect(function()
		        Tween:Tween(Button, UIPallet.Tween, {
		            BackgroundTransparency = 0
		        })
		    end)
		    Button.MouseLeave:Connect(function()
		        Tween:Tween(Button, UIPallet.Tween, {
		            BackgroundTransparency = 1
		        })
		    end)
		
		    return Button, AddThumb(Button, Flipped)
		end
		
		local Like, LikeThumb = AddVote("Like", 0, 45, false)
		local Dislike, DislikeThumb = AddVote("Dislike", 46, 44, true)
		
		local DetailClose: ImageButton = AddCloseButton(Details, false, UDim2.new(1, -35, 0, 12))
		DetailClose.ZIndex = 6
		
		local Uploader: Frame = MakePanel("Uploader", 338, 672)
		Uploader.BackgroundColor3 = UIPallet.Main
		local UploadSide: Frame = Instance.new("Frame")
		UploadSide.BackgroundColor3 = Color.Light(UIPallet.Main, 0.034)
		UploadSide.BorderSizePixel = 0
		UploadSide.Name = "Sidebar"
		UploadSide.Size = UDim2.fromOffset(224, 338)
		UploadSide.ZIndex = 6
		UploadSide.Parent = Uploader
		AddCorner(UploadSide)
		
		local UploadTitle: TextLabel = Instance.new("TextLabel")
		UploadTitle.BackgroundTransparency = 1
		UploadTitle.FontFace = UIPallet.FontSemiBold
		UploadTitle.Position = UDim2.fromOffset(16, 16)
		UploadTitle.Size = UDim2.fromOffset(192, 24)
		UploadTitle.Text = "New Profile"
		UploadTitle.TextColor3 = Color3.new(1, 1, 1)
		UploadTitle.TextSize = 18
		UploadTitle.TextXAlignment = Enum.TextXAlignment.Left
		UploadTitle.ZIndex = 7
		UploadTitle.Parent = UploadSide
		
		local Derived: TextLabel = Instance.new("TextLabel")
		Derived.BackgroundTransparency = 1
		Derived.FontFace = UIPallet.FontBold
		Derived.Position = UDim2.fromOffset(16, 46)
		Derived.RichText = true
		Derived.Size = UDim2.fromOffset(192, 16)
		Derived.Text = ""
		Derived.TextColor3 = Color3.fromRGB(140, 140, 140)
		Derived.TextSize = 11
		Derived.TextTruncate = Enum.TextTruncate.AtEnd
		Derived.TextXAlignment = Enum.TextXAlignment.Left
		Derived.ZIndex = 7
		Derived.Parent = UploadSide
		
		AddRow(UploadSide, "Details", 80, true)
		
		local UploadCount: TextLabel = ModuleCount:Clone()
		UploadCount.Parent = UploadSide
		local UploadModules: ScrollingFrame = Instance.new("ScrollingFrame")
		UploadModules.BackgroundTransparency = 1
		UploadModules.BorderSizePixel = 0
		UploadModules.CanvasSize = UDim2.new()
		UploadModules.Name = "Modules"
		UploadModules.Position = UDim2.fromOffset(0, 148)
		UploadModules.ScrollBarThickness = 0
		UploadModules.Size = UDim2.fromOffset(224, 182)
		UploadModules.ZIndex = 7
		UploadModules.Parent = UploadSide
		local UploadLayout: UIListLayout = Instance.new("UIListLayout")
		UploadLayout.Padding = UDim.new(0, 0)
		UploadLayout.SortOrder = Enum.SortOrder.LayoutOrder
		UploadLayout.Parent = UploadModules
		
		local function AddCaption(Parent: Instance, Text: string, Y: number)
		    local Caption: TextLabel = Instance.new("TextLabel")
		    Caption.BackgroundTransparency = 1
		    Caption.FontFace = UIPallet.FontBold
		    Caption.Position = UDim2.fromOffset(244, Y)
		    Caption.Size = UDim2.fromOffset(412, 14)
		    Caption.Text = Text
		    Caption.TextColor3 = Color3.fromRGB(115, 113, 115)
		    Caption.TextSize = 11
		    Caption.TextXAlignment = Enum.TextXAlignment.Left
		    Caption.ZIndex = 6
		    Caption.Parent = Parent
		    return Caption
		end
		
		local function AddInput(Parent: Instance, Placeholder: string, Y: number)
		    local Box: TextBox = Instance.new("TextBox")
		    Box.BackgroundTransparency = 1
		    Box.ClearTextOnFocus = false
		    Box.FontFace = UIPallet.Font
		    Box.PlaceholderColor3 = VapeColors.Secondary
		    Box.PlaceholderText = Placeholder
		    Box.Position = UDim2.fromOffset(244, Y)
		    Box.Size = UDim2.fromOffset(412, 26)
		    Box.Text = ""
		    Box.TextColor3 = VapeColors.Primary
		    Box.TextSize = 13
		    Box.TextXAlignment = Enum.TextXAlignment.Left
		    Box.ZIndex = 6
		    Box.Parent = Parent
		    local Line: Frame = Instance.new("Frame")
		    Line.BackgroundColor3 = VapeColors.Outline
		    Line.BackgroundTransparency = 0.5
		    Line.BorderSizePixel = 0
		    Line.Position = UDim2.fromOffset(244, Y + 30)
		    Line.Size = UDim2.fromOffset(412, 1)
		    Line.ZIndex = 6
		    Line.Parent = Parent
		    return Box
		end
		
		AddCaption(Uploader, "NAME", 24)
		local NameBox: TextBox = AddInput(Uploader, "Enter profile name...", 42)
		AddCaption(Uploader, "DESCRIPTION", 90)
		local DescriptionBox: TextBox = AddInput(Uploader, "Add Description (optional)", 108)
		AddCaption(Uploader, "PREFERENCES", 156)
		
		local AnonymousLabel: TextLabel = Instance.new("TextLabel")
		AnonymousLabel.BackgroundTransparency = 1
		AnonymousLabel.FontFace = UIPallet.Font
		AnonymousLabel.Position = UDim2.fromOffset(244, 180)
		AnonymousLabel.Size = UDim2.fromOffset(412, 20)
		AnonymousLabel.Text = "Upload anonymously"
		AnonymousLabel.TextColor3 = VapeColors.Secondary
		AnonymousLabel.TextSize = 13
		AnonymousLabel.TextXAlignment = Enum.TextXAlignment.Left
		AnonymousLabel.ZIndex = 6
		AnonymousLabel.Parent = Uploader
		
		local function AddToggle(Parent: Instance, Y: number)
		    local ToggleAPI = {Enabled = false}
		
		    local Button: TextButton = Instance.new("TextButton")
		    Button.AutoButtonColor = false
		    Button.BackgroundColor3 = Color3.fromRGB(54, 53, 54)
		    Button.Position = UDim2.fromOffset(632, Y)
		    Button.Size = UDim2.fromOffset(25, 14)
		    Button.Text = ""
		    Button.ZIndex = 6
		    Button.Parent = Parent
		    AddCorner(Button, UDim.new(1, 0))
		    local Knob: Frame = Instance.new("Frame")
		    Knob.BackgroundColor3 = UIPallet.Main
		    Knob.BorderSizePixel = 0
		    Knob.Position = UDim2.fromOffset(4, 3)
		    Knob.Size = UDim2.fromOffset(8, 8)
		    Knob.ZIndex = 7
		    Knob.Parent = Button
		    AddCorner(Knob, UDim.new(1, 0))
		
		    function ToggleAPI:Set(State: boolean)
		        self.Enabled = State
		
		        Tween:Tween(Knob, UIPallet.Tween, {
		            Position = UDim2.fromOffset(State and 14 or 4, 3)
		        })
		
		        Tween:Tween(Button, UIPallet.Tween, {
		            BackgroundColor3 = State and AccentColor() or Color3.fromRGB(54, 53, 54)
		        })
		    end
		
		    Button.MouseButton1Click:Connect(function()
		        ToggleAPI:Set(not ToggleAPI.Enabled)
		    end)
		
		    return ToggleAPI
		end
		
		local AnonymousToggle = AddToggle(Uploader, 181)
		
		local Confirm: TextButton = MakeAction(Uploader, "PUBLISH", true, 289, 120, 534)
		local Cancel: TextButton = MakeAction(Uploader, "CANCEL", false, 289, 80, 454)
		local UploadClose: ImageButton = AddCloseButton(Uploader, false, UDim2.new(1, -35, 0, 12))
		UploadClose.ZIndex = 6
		
		local Editor: Frame = MakePanel("Editor", 338, 672)
		Editor.BackgroundColor3 = UIPallet.Main
		local EditorSide: Frame = Instance.new("Frame")
		EditorSide.BackgroundColor3 = UIPallet.Main
		EditorSide.BorderSizePixel = 0
		EditorSide.Name = "Sidebar"
		EditorSide.Size = UDim2.fromOffset(224, 338)
		EditorSide.ZIndex = 6
		EditorSide.Parent = Editor
		AddCorner(EditorSide)
		
		local EditorTitle: TextLabel = UploadTitle:Clone()
		EditorTitle.Text = ""
		EditorTitle.Parent = EditorSide
		
		local EditorDerived: TextButton = Instance.new("TextButton")
		EditorDerived.AutoButtonColor = false
		EditorDerived.BackgroundTransparency = 1
		EditorDerived.FontFace = UIPallet.FontBold
		EditorDerived.Name = "Derived"
		EditorDerived.Position = UDim2.fromOffset(16, 46)
		EditorDerived.RichText = true
		EditorDerived.Size = UDim2.fromOffset(192, 16)
		EditorDerived.Text = ""
		EditorDerived.TextColor3 = Color3.fromRGB(140, 140, 140)
		EditorDerived.TextSize = 11
		EditorDerived.TextTruncate = Enum.TextTruncate.AtEnd
		EditorDerived.TextXAlignment = Enum.TextXAlignment.Left
		EditorDerived.ZIndex = 7
		EditorDerived.Parent = EditorSide
		
		local SelectEditorModule
		local EditorDetailsRow = AddRow(EditorSide, "Details", 80, true, function()
		    SelectEditorModule(nil)
		end)
		
		local EditorCount: TextLabel = ModuleCount:Clone()
		EditorCount.Parent = EditorSide
		local EditorModules: ScrollingFrame = Instance.new("ScrollingFrame")
		EditorModules.BackgroundTransparency = 1
		EditorModules.BorderSizePixel = 0
		EditorModules.CanvasSize = UDim2.new()
		EditorModules.Name = "Modules"
		EditorModules.Position = UDim2.fromOffset(0, 148)
		EditorModules.ScrollBarThickness = 0
		EditorModules.Size = UDim2.fromOffset(224, 182)
		EditorModules.ZIndex = 7
		EditorModules.Parent = EditorSide
		local EditorModulesLayout: UIListLayout = Instance.new("UIListLayout")
		EditorModulesLayout.Padding = UDim.new(0, 0)
		EditorModulesLayout.SortOrder = Enum.SortOrder.LayoutOrder
		EditorModulesLayout.Parent = EditorModules
		
		local EditorSettings: Frame = Instance.new("Frame")
		EditorSettings.BackgroundTransparency = 1
		EditorSettings.Name = "Settings"
		EditorSettings.Size = UDim2.fromScale(1, 1)
		EditorSettings.ZIndex = 6
		EditorSettings.Parent = Editor
		
		AddCaption(EditorSettings, "DESCRIPTION", 24)
		local EditorDescription: TextBox = AddInput(EditorSettings, "Add Description (optional)", 42)
		AddCaption(EditorSettings, "PREFERENCES", 90)
		
		local EditorAnonymousLabel: TextLabel = AnonymousLabel:Clone()
		EditorAnonymousLabel.Position = UDim2.fromOffset(244, 114)
		EditorAnonymousLabel.Parent = EditorSettings
		local EditorAnonymous = AddToggle(EditorSettings, 115)
		
		AddCaption(EditorSettings, "STATS", 162)
		
		local EditorStats: TextLabel = Instance.new("TextLabel")
		EditorStats.BackgroundTransparency = 1
		EditorStats.FontFace = UIPallet.Font
		EditorStats.Position = UDim2.fromOffset(244, 180)
		EditorStats.Size = UDim2.fromOffset(412, 20)
		EditorStats.Text = ""
		EditorStats.TextColor3 = UIPallet.Text
		EditorStats.TextSize = 13
		EditorStats.TextXAlignment = Enum.TextXAlignment.Left
		EditorStats.ZIndex = 6
		EditorStats.Parent = EditorSettings
		
		local EditorModuleTitle: TextLabel = ModuleTitle:Clone()
		EditorModuleTitle.Parent = Editor
		
		local EditorOptions: ScrollingFrame = Instance.new("ScrollingFrame")
		EditorOptions.BackgroundTransparency = 1
		EditorOptions.BorderSizePixel = 0
		EditorOptions.CanvasSize = UDim2.new()
		EditorOptions.Name = "Options"
		EditorOptions.Position = UDim2.fromOffset(244, 52)
		EditorOptions.ScrollBarThickness = 0
		EditorOptions.Size = UDim2.fromOffset(412, 212)
		EditorOptions.Visible = false
		EditorOptions.ZIndex = 6
		EditorOptions.Parent = Editor
		local EditorOptionsLayout: UIListLayout = Instance.new("UIListLayout")
		EditorOptionsLayout.Padding = UDim.new(0, 0)
		EditorOptionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		EditorOptionsLayout.Parent = EditorOptions
		
		local Update: TextButton = MakeAction(Editor, "UPDATE", true, 289, 120, 534)
		local EditorCancel: TextButton = MakeAction(Editor, "CANCEL", false, 289, 80, 454)
		local EditorRemove: TextButton = MakeAction(Editor, "REMOVE", false, 289, 100, 254)
		EditorRemove.BackgroundTransparency = 1
		EditorRemove.TextColor3 = VapeColors.Danger
		EditorRemove.TextXAlignment = Enum.TextXAlignment.Left
		local EditorClose: ImageButton = AddCloseButton(Editor, false, UDim2.new(1, -35, 0, 12))
		EditorClose.ZIndex = 6
		
		local SourceMenu, SourceCatcher, SourceAction
		
		local function SetSourceMenu(State: boolean)
		    if not SourceMenu then return end
		    SourceMenu.Visible = State
		    SourceCatcher.Visible = State
		end
		
		local function ShowPanel(Panel: Frame?)
		    Overlay.Visible = Panel ~= nil
		    Details.Visible = Panel == Details
		    Uploader.Visible = Panel == Uploader
		    Editor.Visible = Panel == Editor
		    SetSourceMenu(false)
		end
		
		local Editing
		local EditorSource: string?
		local OpenEditor
		local Selected
		local Dislikes: {[string]: boolean} = {}
		local Voting: boolean = false
		
		local function PaintThumb(Thumb: ImageLabel, Tint: Color3)
		    Tween:Tween(Thumb, UIPallet.Tween, {
		        ImageColor3 = Tint
		    })
		end
		
		local function RenderVotes(Entry)
		    LikesValue.Text = tostring(Entry.likes or 0)
		    PaintThumb(LikeThumb, Entry.liked and AccentColor() or VapeColors.Icon)
		    PaintThumb(DislikeThumb, Dislikes[Entry.filename] and Color3.fromRGB(255, 89, 94) or VapeColors.Icon)
		end
		
		local function SendLike(Entry, Wanted: boolean)
		    local Liked, Likes = Entry.liked, Entry.likes or 0
		    Entry.liked = Wanted
		    Entry.likes = math.max(Likes + (Wanted and 1 or -1), 0)
		    Voting = true
		    RenderVotes(Entry)
		
		    task.spawn(function()
		        local Response = request({
		            Url = "https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/main/configs/like",
		            Method = "POST",
		            Headers = {
		                ["Content-Type"] = "application/json"
		            },
		            Body = HttpService:JSONEncode({
		                key = License.Key or "_key",
		                filename = Entry.filename,
		                like = Wanted
		            })
		        })
		        Voting = false
		
		        if Response and Response.Body then
		            local Body = HttpService:JSONDecode(HttpService:JSONDecode(Response.Body).response)
		            Entry.liked = Body.liked == true
		            Entry.likes = math.max(Likes + ((Entry.liked and 1 or 0) - (Liked and 1 or 0)), 0)
		        else
		            Entry.liked, Entry.likes = Liked, Likes
		            vape:CreateNotification("Cat", `Failed to {Wanted and "like" or "unlike"} "{Entry.Name}"`, 8, "warning")
		        end
		
		        if Selected == Entry then
		            RenderVotes(Entry)
		        end
		    end)
		end
		
		local function AddCard(Entry)
		    local Name: string = Entry.Name
		    local Author: string = Entry.Author
		
		    local Card: TextButton = Instance.new("TextButton")
		    Card.AutoButtonColor = false
		    Card.BackgroundColor3 = VapeColors.Panel
		    Card.Name = Name
		    Card.Text = ""
		    Card.Parent = Children
		    AddCorner(Card, UDim.new(0, 4))
		    local Stroke: UIStroke = Instance.new("UIStroke")
		    Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		    Stroke.Color = VapeColors.Panel
		    Stroke.Thickness = 2
		    Stroke.Parent = Card
		    local Label: TextLabel = Instance.new("TextLabel")
		    Label.BackgroundTransparency = 1
		    Label.FontFace = UIPallet.FontBold
		    Label.Position = UDim2.fromOffset(16, 16)
		    Label.Size = UDim2.fromOffset(100, 20)
		    Label.Text = Name
		    Label.TextColor3 = VapeColors.Primary
		    Label.TextSize = 14
		    Label.TextWrapped = true
		    Label.TextXAlignment = Enum.TextXAlignment.Left
		    Label.TextYAlignment = Enum.TextYAlignment.Top
		    Label.Parent = Card
		    local AuthorLabel: TextLabel = Instance.new("TextLabel")
		    AuthorLabel.BackgroundTransparency = 1
		    AuthorLabel.FontFace = UIPallet.Font
		    AuthorLabel.Position = UDim2.fromOffset(16, 42)
		    AuthorLabel.Size = UDim2.fromOffset(124, 16)
		    AuthorLabel.Text = Author
		    AuthorLabel.TextColor3 = VapeColors.Muted
		    AuthorLabel.TextSize = 12
		    AuthorLabel.TextTruncate = Enum.TextTruncate.AtEnd
		    AuthorLabel.TextXAlignment = Enum.TextXAlignment.Left
		    AuthorLabel.Parent = Card
		    local Likes: string = tostring(Entry.likes or 0)
		    local Pill: Frame = Instance.new("Frame")
		    Pill.BackgroundColor3 = Color3.fromRGB(44, 42, 44)
		    Pill.BorderSizePixel = 0
		    Pill.Position = UDim2.fromOffset(16, 108)
		    Pill.Size = UDim2.fromOffset(38 + GetFontBounds(Likes, 11, UIPallet.FontBold).X, 20)
		    Pill.Parent = Card
		    AddCorner(Pill, UDim.new(0, 9))
		    local PillThumb: ImageLabel = AddThumb(Pill, false)
		    PillThumb.Position = UDim2.fromOffset(16, 9)
		    PillThumb.Size = UDim2.fromOffset(12, 10)
		    PillThumb.ZIndex = 2
		    local PillText: TextLabel = Instance.new("TextLabel")
		    PillText.BackgroundTransparency = 1
		    PillText.FontFace = UIPallet.FontBold
		    PillText.Position = UDim2.fromOffset(29, 0)
		    PillText.Size = UDim2.new(1, -29, 1, 0)
		    PillText.Text = Likes
		    PillText.TextColor3 = VapeColors.Muted
		    PillText.TextSize = 11
		    PillText.TextXAlignment = Enum.TextXAlignment.Left
		    PillText.ZIndex = 2
		    PillText.Parent = Pill
		
		    Card.MouseEnter:Connect(function()
		        Tween:Tween(Card, UIPallet.Tween, {
		            BackgroundColor3 = Color3.fromRGB(35, 34, 35)
		        })
		
		        TweenService:Create(Stroke, UIPallet.Tween, {Color = Color3.fromRGB(43, 42, 43)}):Play()
		    end)
		    Card.MouseLeave:Connect(function()
		        Tween:Tween(Card, UIPallet.Tween, {
		            BackgroundColor3 = VapeColors.Panel
		        })
		
		        TweenService:Create(Stroke, UIPallet.Tween, {Color = VapeColors.Panel}):Play()
		    end)
		    Card.MouseButton1Click:Connect(function()
		        Selected = Entry
		        DetailName.Text = Name
		        DetailAuthor.Text = `By {Author}`
		        ApplyAvatar(Avatar, Entry.discord_pfp)
		        Created.Text = `Created: {Entry.Uploaded and os.date("%b %d, %Y", Entry.Uploaded) or "unknown"}`
		        UpdatedValue.Text = RelativeDays(Entry.Uploaded)
		        DownloadsValue.Text = tostring(Entry.downloads or 0)
		        RenderVotes(Entry)
		        DetailDescription.Text = (Entry.description and Entry.description ~= "" and Entry.description ~= "unknown") and Entry.description or "No description provided"
		
		        ClearList(ModuleList)
		
		        local Active: {string} = {}
		        local Decoded = Entry.config and select(2, pcall(HttpService.JSONDecode, HttpService, Entry.config))
		        for ModuleName: any, v: any in (type(Decoded) == "table" and Decoded.Modules or {}) do
		            if type(v) == "table" and v.Enabled then
		                table.insert(Active, tostring(ModuleName))
		            end
		        end
		        table.sort(Active)
		
		        ModuleCount.Text = `<font color="rgb(255,255,255)">{#Active}</font> AFFECTED MODULES`
		
		        local Rows = {}
		        local function SelectRow(Chosen: string?)
		            for ModuleName: string, Row: TextButton in Rows do
		                local IsChosen: boolean = ModuleName == Chosen
		                Row.BackgroundTransparency = IsChosen and 0 or 1
		                Row.TextLabel.TextColor3 = IsChosen and Color3.new(1, 1, 1) or Color3.fromRGB(171, 171, 171)
		            end
		            DetailsRow.BackgroundTransparency = Chosen and 1 or 0
		            DetailsRow.TextLabel.TextColor3 = Chosen and Color3.fromRGB(171, 171, 171) or Color3.new(1, 1, 1)
		
		            if not Chosen then
		                ShowDetails(false)
		                return
		            end
		
		            ModuleTitle.Text = Chosen
		            ClearList(OptionList)
		
		            local Options = Decoded.Modules[Chosen].Options or {}
		            local Names: {string} = {}
		            for OptionName: any in Options do
		                table.insert(Names, tostring(OptionName))
		            end
		            table.sort(Names)
		            for i: number, OptionName: string in Names do
		                AddOptionRow(OptionList, OptionName, Options[OptionName], i)
		            end
		            OptionList.CanvasSize = UDim2.fromOffset(0, #Names * 30)
		            ShowDetails(true)
		        end
		
		        SelectModule = SelectRow
		        for i: number, ModuleName: string in Active do
		            Rows[ModuleName] = AddRow(ModuleList, ModuleName, 0, false, function()
		                SelectRow(ModuleName)
		            end, i)
		        end
		        ModuleList.CanvasSize = UDim2.fromOffset(0, #Active * 36)
		        SelectRow(nil)
		
		        ShowPanel(Details)
		    end)
		
		    table.insert(Component.Cards, Card)
		end
		
		local function ClearCards()
		    for _, v: Frame in Component.Cards do
		        v:Destroy()
		    end
		    table.clear(Component.Cards)
		end
		
		local function ShowSkeletons()
		    ClearCards()
		    Empty.Visible = false
		
		    for _ = 1, 6 do
		        local Card: Frame = Instance.new("Frame")
		        Card.BackgroundColor3 = VapeColors.Panel
		        Card.Parent = Children
		        AddCorner(Card, UDim.new(0, 4))
		
		        for _, v: {number} in {{120, 20, 10, 10}, {60, 20, 10, 34}, {50, 20, 15, 108}} do
		            local Bar: Frame = Instance.new("Frame")
		            Bar.BackgroundColor3 = VapeColors.Raised
		            Bar.BorderSizePixel = 0
		            Bar.Position = UDim2.fromOffset(v[3], v[4])
		            Bar.Size = UDim2.fromOffset(v[1], v[2])
		            Bar.Parent = Card
		            AddCorner(Bar, UDim.new(0, 3))
		        end
		
		        table.insert(Component.Cards, Card)
		    end
		end
		
		local function AddOwned(Entry, Order: number)
		    local Row: TextButton = Instance.new("TextButton")
		    Row.AutoButtonColor = false
		    Row.BackgroundColor3 = VapeColors.Panel
		    Row.BorderSizePixel = 0
		    Row.LayoutOrder = Order
		    Row.Name = Entry.Name
		    Row.Size = UDim2.fromOffset(184, 36)
		    Row.Text = ""
		    Row.Parent = Owned
		    AddCorner(Row, UDim.new(0, 3))
		    local Label: TextLabel = Instance.new("TextLabel")
		    Label.BackgroundTransparency = 1
		    Label.FontFace = UIPallet.Font
		    Label.Position = UDim2.fromOffset(14, 0)
		    Label.Size = UDim2.fromOffset(156, 36)
		    Label.Text = Entry.Name
		    Label.TextColor3 = VapeColors.Secondary
		    Label.TextSize = 14
		    Label.TextTruncate = Enum.TextTruncate.AtEnd
		    Label.TextXAlignment = Enum.TextXAlignment.Left
		    Label.Parent = Row
		
		    Row.MouseEnter:Connect(function()
		        Tween:Tween(Row, UIPallet.Tween, {
		            BackgroundColor3 = VapeColors.Raised
		        })
		
		        Label.TextColor3 = VapeColors.Primary
		    end)
		    Row.MouseLeave:Connect(function()
		        Tween:Tween(Row, UIPallet.Tween, {
		            BackgroundColor3 = VapeColors.Panel
		        })
		
		        Label.TextColor3 = VapeColors.Secondary
		    end)
		    Row.MouseButton1Click:Connect(function()
		        OpenEditor(Entry)
		    end)
		
		    table.insert(Component.Owned, Row)
		end
		
		local function RenderOwned()
		    for _, v: TextButton in Component.Owned do
		        v:Destroy()
		    end
		    table.clear(Component.Owned)
		
		    local Count: number = 0
		    for _, v: any in Component.Configs do
		        if v.mine then
		            Count += 1
		            AddOwned(v, Count)
		        end
		    end
		
		    OwnedEmpty.Visible = Count == 0 and not Component.Collapsed
		    Owned.CanvasSize = UDim2.fromOffset(0, Count * 40)
		end
		
		local function Render()
		    ClearCards()
		
		    local Filtered = {}
		    local Query: string = Component.Search:lower()
		    for _, v: any in Component.Configs do
		        local Name: string = v.Name:lower()
		        local Author: string = v.Author:lower()
		        if Query == "" or Name:find(Query, 1, true) or Author:find(Query, 1, true) then
		            table.insert(Filtered, v)
		        end
		    end
		
		    table.sort(Filtered, Sorts[Component.Sort])
		    for _, v: any in Filtered do
		        AddCard(v)
		    end
		    Empty.Visible = #Filtered == 0
		end
		
		local function Refresh()
		    ShowSkeletons()
		
		    local Response = request({
		        Url = "https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/main/configs/get",
		        Method = "POST",
		        Headers = {
		            ["Content-Type"] = "application/json"
		        },
		        Body = HttpService:JSONEncode({key = License.Key or "_key"})
		    })
		    local Payload = Response and Response.Body and HttpService:JSONDecode(HttpService:JSONDecode(Response.Body).response)
		    local Configs = Payload and Payload.configs
		    table.clear(Component.Configs)
		    Component.Viewer = Payload and Payload.viewer
		
		    if Configs then
		        for _, v: any in Configs do
		            if v.config_name then
		                v.Uploaded = ParseTimestamp(v.uploaded_at)
		                v.Name, v.Author = ParseFilename(v)
		                v.likes = tonumber(v.likes) or 0
		                v.liked = v.liked == true
		                v.mine = v.mine == true
		                table.insert(Component.Configs, v)
		            end
		        end
		    end
		    RenderOwned()
		    Render()
		end
		
		Component.Refresh = Refresh
		
		local function AddSort(Name: string, Label: string, Order: number)
		    local Text: string = Label:upper()
		    local IsSelected: boolean = Component.Sort == Name
		    local Button: TextButton = Instance.new("TextButton")
		    Button.AutoButtonColor = false
		    Button.BackgroundColor3 = IsSelected and AccentColor() or UIPallet.Main
		    Button.FontFace = UIPallet.FontBold
		    Button.LayoutOrder = Order
		    Button.Name = Name
		    Button.Size = UDim2.fromOffset(GetFontBounds(Text, 11, UIPallet.FontBold).X + 30, 28)
		    Button.Text = Text
		    Button.TextColor3 = IsSelected and AccentTextColor() or VapeColors.Muted
		    Button.TextSize = 11
		    Button.Parent = SortFrame
		    Button:SetAttribute("Accent", IsSelected)
		    AddCorner(Button, UDim.new(0, 14))
		    table.insert(Component.Accents, Button)
		
		    Button.MouseEnter:Connect(function()
		        if Component.Sort ~= Name then
		            Tween:Tween(Button, UIPallet.Tween, {
		                BackgroundColor3 = VapeColors.Outline
		            })
		        end
		    end)
		    Button.MouseLeave:Connect(function()
		        if Component.Sort ~= Name then
		            Tween:Tween(Button, UIPallet.Tween, {
		                BackgroundColor3 = UIPallet.Main
		            })
		        end
		    end)
		    Button.MouseButton1Click:Connect(function()
		        Component.Sort = Name
		        for _, v: Instance in SortFrame:GetChildren() do
		            if v:IsA("TextButton") then
		                local IsActive: boolean = v.Name == Name
		                v:SetAttribute("Accent", IsActive)
		                v.BackgroundColor3 = IsActive and AccentColor() or UIPallet.Main
		                v.TextColor3 = IsActive and AccentTextColor() or VapeColors.Muted
		            end
		        end
		        Render()
		    end)
		end
		
		AddSort("rated", "Top Rated", 1)
		AddSort("downloaded", "Most Downloaded", 2)
		AddSort("newest", "Newest", 3)
		
		for _, v: GuiButton in {DetailClose, UploadClose, Cancel, Overlay} do
		    v.MouseButton1Click:Connect(ShowPanel)
		end
		
		SourceCatcher = Instance.new("TextButton")
		SourceCatcher.AutoButtonColor = false
		SourceCatcher.BackgroundTransparency = 1
		SourceCatcher.Name = "CreateFromCatcher"
		SourceCatcher.Size = UDim2.fromScale(1, 1)
		SourceCatcher.Text = ""
		SourceCatcher.Visible = false
		SourceCatcher.ZIndex = 8
		SourceCatcher.Parent = Window
		SourceMenu = Instance.new("Frame")
		SourceMenu.Active = true
		SourceMenu.BackgroundColor3 = AccentColor()
		SourceMenu.BorderSizePixel = 0
		SourceMenu.Name = "CreateFrom"
		SourceMenu.Position = UDim2.fromOffset(96, 60)
		SourceMenu.Size = UDim2.fromOffset(216, 60)
		SourceMenu.Visible = false
		SourceMenu.ZIndex = 9
		SourceMenu.Parent = Window
		AddCorner(SourceMenu)
		table.insert(Component.Accents, SourceMenu)
		
		local SourceTitle: TextLabel = Instance.new("TextLabel")
		SourceTitle.BackgroundTransparency = 1
		SourceTitle.FontFace = UIPallet.FontSemiBold
		SourceTitle.Position = UDim2.fromOffset(0, 14)
		SourceTitle.Size = UDim2.new(1, 0, 0, 20)
		SourceTitle.Text = "Create from..."
		SourceTitle.TextColor3 = AccentTextColor()
		SourceTitle.TextSize = 14
		SourceTitle.ZIndex = 10
		SourceTitle.Parent = SourceMenu
		
		local SourceList: ScrollingFrame = Instance.new("ScrollingFrame")
		SourceList.BackgroundTransparency = 1
		SourceList.BorderSizePixel = 0
		SourceList.CanvasSize = UDim2.new()
		SourceList.Position = UDim2.fromOffset(0, 40)
		SourceList.ScrollBarThickness = 0
		SourceList.Size = UDim2.fromOffset(216, 20)
		SourceList.ZIndex = 10
		SourceList.Parent = SourceMenu
		local SourceLayout: UIListLayout = Instance.new("UIListLayout")
		SourceLayout.Padding = UDim.new(0, 0)
		SourceLayout.SortOrder = Enum.SortOrder.LayoutOrder
		SourceLayout.Parent = SourceList
		
		local function ProfileSource(Profile: string?)
		    if not Profile then
		        vape:Save(vape.Profile)
		    end
		
		    local FilePath: string = `kingvape/profiles/{Profile or vape.Profile}{vape.Place}.txt`
		    return isfile(FilePath) and readfile(FilePath) or nil
		end
		
		local function OpenUploader(Profile: string?)
		    SetSourceMenu(false)
		    NameBox.Text = ""
		    DescriptionBox.Text = ""
		    AnonymousToggle:Set(false)
		    Derived.Text = `DERIVED FROM <font color="rgb(255,255,255)">{Profile or "Current settings"}</font>`
		
		    UploadSource = ProfileSource(Profile)
		    FillModules(UploadModules, UploadCount, UploadSource)
		    ShowPanel(Uploader)
		end
		
		local EditorRows, EditorDecoded = {}, nil
		
		function SelectEditorModule(Chosen: string?)
		    for ModuleName: string, Row: TextButton in EditorRows do
		        local IsChosen: boolean = ModuleName == Chosen
		        Row.BackgroundTransparency = IsChosen and 0 or 1
		        Row.TextLabel.TextColor3 = IsChosen and Color3.new(1, 1, 1) or Color3.fromRGB(171, 171, 171)
		    end
		    EditorDetailsRow.BackgroundTransparency = Chosen and 1 or 0
		    EditorDetailsRow.TextLabel.TextColor3 = Chosen and Color3.fromRGB(171, 171, 171) or Color3.new(1, 1, 1)
		
		    EditorSettings.Visible = not Chosen
		    EditorModuleTitle.Visible = Chosen ~= nil
		    EditorOptions.Visible = Chosen ~= nil
		
		    if not Chosen then return end
		
		    EditorModuleTitle.Text = Chosen
		    ClearList(EditorOptions)
		
		    local Options = EditorDecoded.Modules[Chosen].Options or {}
		    local Names: {string} = {}
		    for OptionName: any in Options do
		        table.insert(Names, tostring(OptionName))
		    end
		    table.sort(Names)
		    for i: number, OptionName: string in Names do
		        AddOptionRow(EditorOptions, OptionName, Options[OptionName], i)
		    end
		    EditorOptions.CanvasSize = UDim2.fromOffset(0, #Names * 30)
		end
		
		local function SetEditorModules(Source: string?)
		    EditorDecoded, EditorRows = FillModules(EditorModules, EditorCount, Source, SelectEditorModule)
		    SelectEditorModule(nil)
		end
		
		local function SetEditorSource(Profile: string?)
		    SetSourceMenu(false)
		    EditorSource = ProfileSource(Profile)
		    EditorDerived.Text = `DERIVED FROM <font color="rgb(255,255,255)">{Profile or "Current settings"}</font>`
		    SetEditorModules(EditorSource)
		end
		
		function OpenEditor(Entry)
		    Editing = Entry
		    EditorSource = nil
		    EditorTitle.Text = Entry.Name
		    EditorDescription.Text = (Entry.description ~= "unknown" and Entry.description) or ""
		    EditorDerived.Text = 'DERIVED FROM <font color="rgb(255,255,255)">Published copy</font>'
		    EditorStats.Text = `{Entry.likes or 0} positive reviews    {Entry.downloads or 0} downloads`
		    EditorAnonymous:Set(Entry.discord_username == "unknown")
		
		    SetEditorModules(Entry.config)
		    ShowPanel(Editor)
		end
		
		local function AddSource(Text: string, Profile: string?, Order: number)
		    local Row: TextButton = Instance.new("TextButton")
		    Row.AutoButtonColor = true
		    Row.BackgroundColor3 = AccentColor()
		    Row.BorderSizePixel = 0
		    Row.LayoutOrder = Order
		    Row.Size = UDim2.fromOffset(216, 30)
		    Row.Text = ""
		    Row.ZIndex = 10
		    Row.Parent = SourceList
		    local Plus: TextLabel = Instance.new("TextLabel")
		    Plus.BackgroundTransparency = 1
		    Plus.FontFace = UIPallet.Font
		    Plus.Position = UDim2.fromOffset(16, 0)
		    Plus.Size = UDim2.fromOffset(20, 30)
		    Plus.Text = "+"
		    Plus.TextColor3 = AccentTextColor()
		    Plus.TextSize = 16
		    Plus.ZIndex = 11
		    Plus.Parent = Row
		    local Label: TextLabel = Instance.new("TextLabel")
		    Label.BackgroundTransparency = 1
		    Label.FontFace = UIPallet.Font
		    Label.Position = UDim2.fromOffset(40, 0)
		    Label.Size = UDim2.fromOffset(160, 30)
		    Label.Text = Text
		    Label.TextColor3 = AccentTextColor()
		    Label.TextSize = 13
		    Label.TextTruncate = Enum.TextTruncate.AtEnd
		    Label.TextXAlignment = Enum.TextXAlignment.Left
		    Label.ZIndex = 11
		    Label.Parent = Row
		    Row.MouseButton1Click:Connect(function()
		        SourceAction(Profile)
		    end)
		
		    return Row
		end
		
		local function ShowSourceMenu(Action, MenuTitle: string, X: number, Y: number)
		    SourceAction = Action
		
		    for _, v: Instance in SourceList:GetChildren() do
		        if v:IsA("TextButton") or v:IsA("TextLabel") then
		            v:Destroy()
		        end
		    end
		
		    SourceTitle.Text = MenuTitle
		    SourceTitle.TextColor3 = AccentTextColor()
		    AddSource("Current settings", nil, 1)
		
		    local Caption: TextLabel = Instance.new("TextLabel")
		    Caption.BackgroundTransparency = 1
		    Caption.FontFace = UIPallet.FontBold
		    Caption.LayoutOrder = 2
		    Caption.Size = UDim2.fromOffset(216, 24)
		    Caption.Text = "      PRIVATE PROFILES"
		    Caption.TextColor3 = AccentTextColor()
		    Caption.TextSize = 11
		    Caption.TextTransparency = 0.35
		    Caption.TextXAlignment = Enum.TextXAlignment.Left
		    Caption.ZIndex = 11
		    Caption.Parent = SourceList
		
		    local Count: number = 0
		    for _, v: any in vape.Categories.Profiles.List do
		        Count += 1
		        AddSource(v.Name, v.Name, 2 + Count)
		    end
		
		    local Height: number = 30 + 24 + Count * 30
		    SourceList.CanvasSize = UDim2.fromOffset(0, Height)
		    SourceList.Size = UDim2.fromOffset(216, math.min(Height, 210))
		    SourceMenu.Position = UDim2.fromOffset(X, Y)
		    SourceMenu.Size = UDim2.fromOffset(216, 40 + math.min(Height, 210) + 10)
		    SetSourceMenu(true)
		end
		
		local Loading: boolean = false
		
		Close.MouseButton1Click:Connect(function()
		    Window.Visible = false
		    ClickGUI.Visible = true
		end)
		
		Collapse.MouseButton1Click:Connect(function()
		    SetCollapsed(not Component.Collapsed)
		end)
		
		Collapse.MouseEnter:Connect(function()
		    CollapseIcon.ImageColor3 = VapeColors.IconHover
		end)
		
		Collapse.MouseLeave:Connect(function()
		    CollapseIcon.ImageColor3 = VapeColors.Icon
		end)
		
		Confirm.MouseButton1Click:Connect(function()
		    if NameBox.Text == "" then
		        vape:CreateNotification("Cat", "No profile name provided", 5, "warning")
		        return
		    end
		
		    if not UploadSource then
		        vape:CreateNotification("Cat", "That profile has no saved settings yet", 8, "warning")
		        return
		    end
		
		    ShowPanel(nil)
		    vape:CreateNotification("Cat", "Publishing profile", 5, "info")
		
		    local Response = request({
		        Url = "https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/main/configs/set",
		        Method = "POST",
		        Headers = {
		            ["Content-Type"] = "application/json"
		        },
		        Body = HttpService:JSONEncode({
		            key = License.Key or "_key",
		            config_name = NameBox.Text,
		            config = UploadSource,
		            description = DescriptionBox.Text,
		            anonymous = AnonymousToggle.Enabled
		        })
		    })
		
		    if Response and Response.StatusCode and Response.StatusCode >= 200 and Response.StatusCode < 300 then
		        vape:CreateNotification("Cat", `Published "{NameBox.Text}"`, 10, "info")
		        Refresh()
		    else
		        local Decoded = Response and Response.Body and select(2, pcall(HttpService.JSONDecode, HttpService, Response.Body))
		        local Reason = type(Decoded) == "table" and type(Decoded.errors) == "table" and type(Decoded.errors[1]) == "table" and select(2, next(Decoded.errors[1]))
		        vape:CreateNotification("Cat", Reason and `Failed to publish profile: {Reason}` or "Failed to publish profile", 10, "warning")
		    end
		end)
		
		Dislike.MouseButton1Click:Connect(function()
		    if Voting or not Selected or not Selected.filename then return end
		    local Entry = Selected
		    local Disliked: boolean = not Dislikes[Entry.filename]
		    Dislikes[Entry.filename] = Disliked or nil
		
		    if Disliked and Entry.liked then
		        SendLike(Entry, false)
		        return
		    end
		    RenderVotes(Entry)
		end)
		
		Download.MouseButton1Click:Connect(function()
		    if not Selected then return end
		    local Entry = Selected
		    local Content = Entry.config or (Entry.metadata and Entry.metadata.content)
		    if not Content then
		        vape:CreateNotification("Cat", `Could not fetch "{Entry.Name}"`, 8, "warning")
		        return
		    end
		
		    local Profile: string = `{Entry.Name} (@{Entry.Author})`
		    local Profiles = vape.Categories.Profiles
		    if not Profiles:GetValue(Profile) then
		        Profiles:CreateProfile(Profile)
		    end
		
		    vape:Save(Profile)
		    writefile(`kingvape/profiles/{Profile}{vape.Place}.txt`, Content)
		    vape:Load(true, Profile)
		    Profiles:ChangeValue()
		    ShowPanel(nil)
		    vape:CreateNotification("Cat", `Downloaded "{Entry.Name}" by {Entry.Author}`, 8, "info")
		end)
		
		EditorCancel.MouseButton1Click:Connect(function()
		    ShowPanel(nil)
		end)
		
		EditorClose.MouseButton1Click:Connect(function()
		    ShowPanel(nil)
		end)
		
		EditorDerived.MouseButton1Click:Connect(function()
		    ShowSourceMenu(SetEditorSource, "Update from...", 43, 96)
		end)
		
		EditorRemove.MouseButton1Click:Connect(function()
		    if not Editing then return end
		    local Entry = Editing
		
		    ShowPanel(nil)
		    local Response = request({
		        Url = "https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/main/configs/delete",
		        Method = "POST",
		        Headers = {
		            ["Content-Type"] = "application/json"
		        },
		        Body = HttpService:JSONEncode({
		            key = License.Key or "_key",
		            config_name = Entry.config_name
		        })
		    })
		    local Body = Response and Response.Body and HttpService:JSONDecode(HttpService:JSONDecode(Response.Body).response)
		
		    if Body and Body.success then
		        vape:CreateNotification("Cat", `Removed "{Entry.Name}"`, 8, "info")
		        Refresh()
		    else
		        vape:CreateNotification("Cat", `Failed to remove "{Entry.Name}"`, 8, "warning")
		    end
		end)
		
		GridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    Children.CanvasSize = UDim2.fromOffset(0, GridLayout.AbsoluteContentSize.Y / Scale.Scale)
		end)
		
		Like.MouseButton1Click:Connect(function()
		    if Voting or not Selected or not Selected.filename then return end
		    local Entry = Selected
		    Dislikes[Entry.filename] = nil
		    SendLike(Entry, not Entry.liked)
		end)
		
		Publish.MouseButton1Click:Connect(function()
		    ShowSourceMenu(OpenUploader, "Create from...", 57, 77)
		end)
		
		SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		    Component.Search = SearchBox.Text
		    Render()
		end)
		
		SourceCatcher.MouseButton1Click:Connect(function()
		    local MousePosition: Vector2 = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
		    local Origin, Size = SourceMenu.AbsolutePosition, SourceMenu.AbsoluteSize
		    if MousePosition.X >= Origin.X and MousePosition.X <= Origin.X + Size.X and MousePosition.Y >= Origin.Y and MousePosition.Y <= Origin.Y + Size.Y then
		        return
		    end
		    SetSourceMenu(false)
		end)
		
		Update.MouseButton1Click:Connect(function()
		    if not Editing then return end
		    local Entry = Editing
		    local Content = EditorSource or Entry.config
		
		    if not Content then
		        vape:CreateNotification("Cat", `Could not read the settings for "{Entry.Name}"`, 8, "warning")
		        return
		    end
		
		    ShowPanel(nil)
		    vape:CreateNotification("Cat", `Updating "{Entry.Name}"`, 5, "info")
		
		    local Response = request({
		        Url = "https://raw.githubusercontent.com/zxcbest957-pixel/KingVape-V3/main/configs/set",
		        Method = "POST",
		        Headers = {
		            ["Content-Type"] = "application/json"
		        },
		        Body = HttpService:JSONEncode({
		            key = License.Key or "_key",
		            config_name = Entry.config_name,
		            config = Content,
		            description = EditorDescription.Text,
		            anonymous = EditorAnonymous.Enabled
		        })
		    })
		
		    if Response and Response.StatusCode and Response.StatusCode >= 200 and Response.StatusCode < 300 then
		        vape:CreateNotification("Cat", `Updated "{Entry.Name}"`, 10, "info")
		        Refresh()
		    else
		        vape:CreateNotification("Cat", `Failed to update "{Entry.Name}"`, 10, "warning")
		    end
		end)
		
		Window:GetPropertyChangedSignal("Visible"):Connect(function()
		    vape:UpdateGUI(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
		    if Window.Visible and not Loading then
		        Loading = true
		        task.spawn(function()
		            if vape.ThreadFix then
		                setthreadidentity(8)
		            end
		
		            Refresh()
		            Loading = false
		        end)
		    end
		end)
		
		ShowPanel(nil)
		vape.PublicProfiles = Component
		
		return Component
	end,
	SearchBar = function(Props, Children, API)
		local Component = {
		    Type = "SearchBar"
		}
		
		local Search: Frame = Instance.new("Frame")
		Search.AnchorPoint = Vector2.new(0.5, 0)
		Search.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.02)
		Search.Name = "Search"
		Search.Position = UDim2.new(0.5, 0, 0, 13)
		Search.Size = UDim2.fromOffset(220, 37)
		Search.Parent = ClickGUI
		Component.Object = Search
		AddBlur(Search)
		AddCorner(Search)
		local Icon: ImageLabel = Instance.new("ImageLabel")
		Icon.BackgroundTransparency = 1
		Icon.Image = GetVapeAsset("kingvape/assets/new/search.png")
		Icon.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		Icon.Position = UDim2.new(1, -25, 0, 11)
		Icon.Size = UDim2.fromOffset(14, 14)
		Icon.Parent = Search
		local LegitIcon: ImageButton = Instance.new("ImageButton")
		LegitIcon.BackgroundTransparency = 1
		LegitIcon.Image = GetVapeAsset("kingvape/assets/new/legit_switch.png")
		LegitIcon.Name = "Legit"
		LegitIcon.Position = UDim2.fromOffset(8, 11)
		LegitIcon.Size = UDim2.fromOffset(29, 16)
		LegitIcon.Parent = Search
		local V4Logo: ImageLabel = vape.Categories.Main.Object.VapeLogo.V4Logo
		ListenProperty(V4Logo, LegitIcon, "ImageColor3", LegitIcon)
		local LegitDivider: Frame = Instance.new("Frame")
		LegitDivider.BackgroundColor3 = Color.Light(UIPallet.Main, 0.14)
		LegitDivider.BorderSizePixel = 0
		LegitDivider.Name = "LegitDivider"
		LegitDivider.Position = UDim2.fromOffset(43, 13)
		LegitDivider.Size = UDim2.fromOffset(2, 12)
		LegitDivider.Parent = Search
		local SearchBox: TextBox = Instance.new("TextBox")
		SearchBox.BackgroundTransparency = 1
		SearchBox.ClearTextOnFocus = false
		SearchBox.FontFace = UIPallet.Font
		SearchBox.PlaceholderText = ""
		SearchBox.Position = UDim2.fromOffset(50, 0)
		SearchBox.Size = UDim2.new(1, -50, 0, 37)
		SearchBox.Text = ""
		SearchBox.TextColor3 = UIPallet.Text
		SearchBox.TextSize = 12
		SearchBox.TextXAlignment = Enum.TextXAlignment.Left
		SearchBox.Parent = Search
		local Children: ScrollingFrame = Instance.new("ScrollingFrame")
		Children.BackgroundTransparency = 1
		Children.BorderSizePixel = 0
		Children.CanvasSize = UDim2.new()
		Children.Position = UDim2.fromOffset(0, 34)
		Children.ScrollBarThickness = 2
		Children.ScrollBarImageTransparency = 0.75
		Children.Size = UDim2.new(1, 0, 1, -37)
		Children.Parent = Search
		local Divider: Frame = Instance.new("Frame")
		Divider.BackgroundColor3 = Color3.new(1, 1, 1)
		Divider.BackgroundTransparency = 0.928
		Divider.BorderSizePixel = 0
		Divider.Position = UDim2.fromOffset(0, 33)
		Divider.Size = UDim2.new(1, 0, 0, 1)
		Divider.Visible = false
		Divider.Parent = Search
		local Stroke: UIStroke = Instance.new("UIStroke")
		Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		Stroke.Color = Color3.fromRGB(85, 85, 85)
		Stroke.Transparency = 0.8
		Stroke.Parent = Search
		local WindowList: UIListLayout = Instance.new("UIListLayout")
		WindowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		WindowList.SortOrder = Enum.SortOrder.LayoutOrder
		WindowList.Parent = Children
		local LegitReturn: TextButton = Instance.new("TextButton")
		LegitReturn.AnchorPoint = Vector2.new(0.5, 0)
		LegitReturn.AutoButtonColor = false
		LegitReturn.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.02)
		LegitReturn.Name = "LegitReturn"
		LegitReturn.Position = UDim2.new(0.5, 0, 0, 13)
		LegitReturn.Size = UDim2.fromOffset(44, 32)
		LegitReturn.Text = ""
		LegitReturn.Visible = false
		LegitReturn.Parent = ScaledGUI
		Component.LegitReturn = LegitReturn
		AddBlur(LegitReturn)
		AddCorner(LegitReturn)
		AddTooltip(LegitReturn, "Return to cheat mode")
		local LegitReturnStroke: UIStroke = Instance.new("UIStroke")
		LegitReturnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		LegitReturnStroke.Color = Color3.fromRGB(85, 85, 85)
		LegitReturnStroke.Transparency = 0.8
		LegitReturnStroke.Parent = LegitReturn
		local LegitReturnIcon: ImageLabel = Instance.new("ImageLabel")
		LegitReturnIcon.BackgroundTransparency = 1
		LegitReturnIcon.Image = GetVapeAsset("kingvape/assets/new/cheat_switch.png")
		LegitReturnIcon.Name = "Icon"
		LegitReturnIcon.Position = UDim2.fromOffset(8, 9)
		LegitReturnIcon.Size = UDim2.fromOffset(29, 15)
		LegitReturnIcon.Parent = LegitReturn
		ListenProperty(V4Logo, LegitReturnIcon, "ImageColor3", LegitReturnIcon)
		
		SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
		    for _, Object: Instance in Children:GetChildren() do
		        if Object:IsA("TextButton") then
		            Object:Destroy()
		        end
		    end
		
		    if SearchBox.Text == "" then return end
		
		    local Order: number = 0
		
		    for Name: string, Module: any in vape.Modules do
		        if Name:lower():find(SearchBox.Text:lower(), 1, true) then
		            local Button = Module.Object:Clone()
		            local Options
		            Order += 1
		            Button.Bind:Destroy()
		            Button.Indicators.Favorite:Destroy()
		            Button.LayoutOrder = Order * 2
		
		            local function ToggleOptions()
		                if not Options then
		                    Options = BuildOptionsView(Module, Children, Button.LayoutOrder + 1)
		                end
		
		                Options.Visible = not Options.Visible
		            end
		
		            Button.Dots.MouseButton1Click:Connect(ToggleOptions)
		
		            Button.Dots.MouseButton2Click:Connect(ToggleOptions)
		
		            Button.Destroying:Once(function()
		                if Options then
		                    Options:Destroy()
		                end
		            end)
		
		            Button.MouseButton1Click:Connect(function()
		                Module:Toggle()
		            end)
		
		            Button.MouseButton2Click:Connect(ToggleOptions)
		
		            for _, Property: string in {"Text", "TextColor3", "BackgroundColor3"} do
		                ListenProperty(Module.Object, Button, Property, Button)
		            end
		
		            ListenProperty(Module.Object.UIGradient, Button.UIGradient, "Color", Button)
		            ListenProperty(Module.Object.UIGradient, Button.UIGradient, "Enabled", Button)
		            ListenProperty(Module.Object.Dots.Dots, Button.Dots.Dots, "ImageColor3", Button)
		
		            Button.Parent = Children
		        end
		    end
		end)
		
		Children:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    Divider.Visible = Children.CanvasPosition.Y > 10 and Children.Visible
		end)
		
		LegitIcon.MouseButton1Click:Connect(function()
		    ClickGUI.Visible = false
		    vape.Legit.Window.Visible = true
		    vape.Legit.Window.Position = UDim2.new(0.5, -350, 0.5, -194)
		end)
		
		LegitIcon.MouseEnter:Connect(function()
		    Tween:Tween(LegitIcon, UIPallet.Tween, {
		        ImageColor3 = Color.Light(V4Logo.ImageColor3, 0.45)
		    })
		end)
		
		LegitIcon.MouseLeave:Connect(function()
		    Tween:Tween(LegitIcon, UIPallet.Tween, {
		        ImageColor3 = V4Logo.ImageColor3
		    })
		end)
		
		LegitReturn.MouseButton1Click:Connect(function()
		    vape.Legit.Window.Visible = false
		    ClickGUI.Visible = true
		end)
		
		LegitReturn.MouseEnter:Connect(function()
		    Tween:Tween(LegitReturnIcon, UIPallet.Tween, {
		        ImageColor3 = Color.Light(V4Logo.ImageColor3, 0.45)
		    })
		end)
		
		LegitReturn.MouseLeave:Connect(function()
		    Tween:Tween(LegitReturnIcon, UIPallet.Tween, {
		        ImageColor3 = V4Logo.ImageColor3
		    })
		end)
		
		vape:Clean(vape.Legit.Window:GetPropertyChangedSignal("Visible"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    LegitReturn.Visible = vape.Legit.Window.Visible
		end))
		
		WindowList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    Children.CanvasSize = UDim2.fromOffset(0, WindowList.AbsoluteContentSize.Y / Scale.Scale)
		    Search.Size = UDim2.fromOffset(220, math.min(37 + WindowList.AbsoluteContentSize.Y / Scale.Scale, 437))
		end)
		
		return Component
	end,
	SettingsPane = function(Props, Children, API)
		local Component = {
		    Buttons = {},
		    Options = {},
		    Parent = API.Parent or Children,
		    Type = "SettingsPane"
		}
		
		local Pane: TextButton = Instance.new("TextButton")
		Pane.AutoButtonColor = false
		Pane.BackgroundColor3 = Props.Main and Color.Dark(UIPallet.Main, 0.02) or UIPallet.Main
		Pane.Size = UDim2.fromScale(1, 1)
		Pane.Text = ""
		Pane.Visible = false
		Pane.Parent = Component.Parent
		local Title: TextLabel = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.FontFace = UIPallet.Font
		Title.Name = "Title"
		Title.Size = UDim2.new(1, -36, 0, 20)
		Title.Position = UDim2.fromOffset(math.abs(Title.Size.X.Offset), 11)
		Title.Text = Props.Name
		Title.TextColor3 = UIPallet.Text
		Title.TextSize = 13
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Parent = Pane
		local Close: ImageButton = AddCloseButton(Pane, true)
		local Back: ImageButton = Instance.new("ImageButton")
		Back.BackgroundTransparency = 1
		Back.Image = GetVapeAsset("kingvape/assets/new/backmini.png")
		Back.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		Back.Position = UDim2.fromOffset(12, 14)
		Back.Size = UDim2.fromOffset(14, 14)
		Back.Parent = Pane
		AddCorner(Pane)
		local SettingsChildren: Frame = Instance.new("Frame")
		SettingsChildren.BackgroundColor3 = UIPallet.Main
		SettingsChildren.BorderSizePixel = 0
		SettingsChildren.Name = "Children"
		SettingsChildren.Position = UDim2.fromOffset(0, 41)
		SettingsChildren.Size = UDim2.new(1, 0, 1, -57)
		SettingsChildren.Parent = Pane
		local Divider: Frame = Instance.new("Frame")
		Divider.BackgroundColor3 = Color3.new(1, 1, 1)
		Divider.BackgroundTransparency = 0.928
		Divider.BorderSizePixel = 0
		Divider.Name = "Divider"
		Divider.Size = UDim2.new(1, 0, 0, 1)
		Divider.Parent = SettingsChildren
		local ListLayout: UIListLayout = Instance.new("UIListLayout")
		ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		ListLayout.Parent = SettingsChildren
		if Props.Main then
		    local VersionLabel: TextLabel = Instance.new("TextLabel")
		    VersionLabel.BackgroundTransparency = 1
		    VersionLabel.FontFace = UIPallet.Font
		    VersionLabel.Name = "Version"
		    VersionLabel.Position = UDim2.new(0, 0, 1, -16)
		    VersionLabel.Size = UDim2.new(1, 0, 0, 16)
		    VersionLabel.Text = `Vape {vape.Version} {isfile("kingvape/profiles/commit.txt") and readfile("kingvape/profiles/commit.txt"):sub(1, 6) or ""} `
		    VersionLabel.TextColor3 = Color.Dark(UIPallet.Text, 0.43)
		    VersionLabel.TextSize = 10
		    VersionLabel.TextXAlignment = Enum.TextXAlignment.Right
		    VersionLabel.Parent = Pane
		else
		    API:CreateGUIButton({
		        Name = Props.Name,
		        Function = function()
		            Pane.Visible = true
		        end
		    })
		end
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    vape:LoadOptions(self, Data)
		end
		
		function Component:Save(Data)
		    Data[Props.Name] = vape:SaveOptions(self)
		end
		
		for ComponentName: string, Constructor: (...any) -> ...any in Components do
		    Component[`Create{ComponentName}`] = function(_, Properties)
		        local Option = Constructor(Properties, SettingsChildren, Component)
		        YieldBuild()
		
		        return Option
		    end
		end
		
		Back.MouseEnter:Connect(function()
		    Back.ImageColor3 = UIPallet.Text
		end)
		
		Back.MouseLeave:Connect(function()
		    Back.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		end)
		
		Back.MouseButton1Click:Connect(function()
		    Pane.Visible = false
		end)
		
		Close.MouseButton1Click:Connect(function()
		    Pane.Visible = false
		end)
		
		ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    Pane.Size = UDim2.new(1, 0, 0, math.max(45 + ListLayout.AbsoluteContentSize.Y, Component.Parent.AbsoluteSize.Y) / Scale.Scale)
		end)
		
		Component.Object = Pane
		vape.Settings[Props.Name] = Component
		
		return Component
	end,
	Slider = function(Props, Children, API)
		local Component = {
		    Decimal = Props.Decimal or 1,
		    Default = Props.Default or Props.Min,
		    Index = GetTableSize(API.Options),
		    Max = Props.Max,
		    Min = Props.Min,
		    Suffix = Props.Suffix,
		    Type = "Slider",
		    Value = Props.Default or Props.Min,
		}
		
		local Slider: TextButton = Instance.new("TextButton")
		Slider.AutoButtonColor = false
		Slider.BackgroundColor3 = Color.Dark(Children.BackgroundColor3, Props.Darker and 0.02 or 0)
		Slider.BorderSizePixel = 0
		Slider.Size = UDim2.new(1, 0, 0, 50)
		Slider.Text = ""
		Slider.Visible = Props.Visible == nil or Props.Visible
		Slider.Parent = Children
		Component.Object = Slider
		AddTooltip(Slider, Props.Tooltip)
		local Title: TextLabel = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.FontFace = UIPallet.Font
		Title.Position = UDim2.fromOffset(10, 2)
		Title.Size = UDim2.fromOffset(60, 30)
		Title.Text = Props.Name
		Title.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		Title.TextSize = 11
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Parent = Slider
		local ValueLabel: TextButton = Instance.new("TextButton")
		ValueLabel.BackgroundTransparency = 1
		ValueLabel.FontFace = UIPallet.Font
		ValueLabel.Position = UDim2.new(1, -69, 0, 9)
		ValueLabel.Size = UDim2.fromOffset(60, 15)
		ValueLabel.Text = `{Component.Value}{Props.Suffix and ` {type(Props.Suffix) == "function" and Props.Suffix(Component.Value) or Props.Suffix}` or ""}`
		ValueLabel.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		ValueLabel.TextSize = 11
		ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
		ValueLabel.Parent = Slider
		local CustomBox: TextBox = Instance.new("TextBox")
		CustomBox.BackgroundTransparency = 1
		CustomBox.ClearTextOnFocus = false
		CustomBox.FontFace = UIPallet.Font
		CustomBox.Position = ValueLabel.Position
		CustomBox.Size = ValueLabel.Size
		CustomBox.Text = Component.Value
		CustomBox.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		CustomBox.TextSize = 11
		CustomBox.TextXAlignment = Enum.TextXAlignment.Right
		CustomBox.Visible = false
		CustomBox.Parent = Slider
		local Holder: Frame = Instance.new("Frame")
		Holder.BackgroundColor3 = Color.Light(UIPallet.Main, 0.034)
		Holder.BorderSizePixel = 0
		Holder.Position = UDim2.fromOffset(10, 37)
		Holder.Size = UDim2.new(1, -20, 0, 2)
		Holder.Parent = Slider
		local Fill: Frame = Instance.new("Frame")
		Fill.BackgroundColor3 = Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
		Fill.BorderSizePixel = 0
		Fill.Size = UDim2.fromScale(math.clamp((Component.Value - Props.Min) / (Props.Max - Props.Min), 0.04, 0.96), 1)
		Fill.Parent = Holder
		local KnobHolder: Frame = Instance.new("Frame")
		KnobHolder.AnchorPoint = Vector2.new(0.5, 0.5)
		KnobHolder.BackgroundColor3 = Slider.BackgroundColor3
		KnobHolder.BorderSizePixel = 0
		KnobHolder.Position = UDim2.fromScale(1, 0.5)
		KnobHolder.Size = UDim2.fromOffset(24, 4)
		KnobHolder.Parent = Fill
		local Knob: Frame = Instance.new("Frame")
		Knob.AnchorPoint = Vector2.new(0.5, 0.5)
		Knob.BackgroundColor3 = Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
		Knob.Position = UDim2.fromScale(0.5, 0.5)
		Knob.Size = UDim2.fromOffset(14, 14)
		Knob.Parent = KnobHolder
		AddCorner(Knob, UDim.new(1, 0))
		Props.Function = Props.Function or function() end
		Props.Decimal = Props.Decimal or 1
		
		function Component:Color(Hue: number, Sat: number, Val: number, IsRainbow: boolean)
		    Fill.BackgroundColor3 = IsRainbow and Color3.fromHSV(vape:Color((Hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(Hue, Sat, Val)
		    Knob.BackgroundColor3 = Fill.BackgroundColor3
		end
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    local NewValue = Data.Value == Data.Max and Data.Max ~= self.Max and self.Max or Data.Value
		    if type(NewValue) == "number" then
		        NewValue = math.clamp(NewValue, self.Min, self.Max)
		    end
		
		    if self.Value ~= NewValue then
		        self:SetValue(NewValue, nil, true)
		    end
		end
		
		function Component:Save(Data)
		    Data[Props.Name] = {
		        Value = self.Value,
		        Max = self.Max
		    }
		end
		
		function Component:SetValue(Value: number, Position: number?, WasReleased: boolean?)
		    if not IsFinite(Value) then
		        return
		    end
		
		    Tween:Tween(Fill, UIPallet.Tween, {
		        Size = UDim2.fromScale(math.clamp(Position or math.clamp((Value - Props.Min) / (Props.Max - Props.Min), 0, 1), 0.04, 0.96), 1)
		    })
		
		    if self.Value ~= Value or WasReleased then
		        self.Value = Value
		        ValueLabel.Text = `{self.Value}{Props.Suffix and ` {type(Props.Suffix) == "function" and Props.Suffix(self.Value) or Props.Suffix}` or ""}`
		        vape:QueueSave()
		        Props.Function(Value, WasReleased)
		    end
		end
		
		Slider.InputBegan:Connect(function(Input: InputObject)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    if
		        (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch)
		        and (Input.Position.Y - Slider.AbsolutePosition.Y) > (20 * Scale.Scale)
		    then
		        local NewPosition: number = math.clamp((Input.Position.X - Holder.AbsolutePosition.X) / Holder.AbsoluteSize.X, 0, 1)
		        local LastPosition: number = NewPosition
		
		        local ReleaseConnection
		        local MoveConnection: RBXScriptConnection = UserInputService.InputChanged:Connect(function(NewInput: InputObject)
		            if vape.ThreadFix then
		                setthreadidentity(8)
		            end
		
		            if NewInput.UserInputType == (Input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
		                local NewPosition: number = math.clamp((NewInput.Position.X - Holder.AbsolutePosition.X) / Holder.AbsoluteSize.X, 0, 1)
		                Component:SetValue(math.floor((Props.Min + (Props.Max - Props.Min) * NewPosition) * Props.Decimal) / Props.Decimal, NewPosition)
		                LastPosition = NewPosition
		            end
		        end)
		
		        ReleaseConnection = Input.Changed:Connect(function()
		            if Input.UserInputState == Enum.UserInputState.End then
		                MoveConnection:Disconnect()
		                ReleaseConnection:Disconnect()
		                Component:SetValue(Component.Value, LastPosition, true)
		            end
		        end)
		
		        Component:SetValue(math.floor((Props.Min + (Props.Max - Props.Min) * NewPosition) * Props.Decimal) / Props.Decimal, NewPosition)
		    end
		end)
		
		Slider.MouseEnter:Connect(function()
		    Tween:Tween(Knob, UIPallet.Tween, {
		        Size = UDim2.fromOffset(16, 16)
		    })
		end)
		
		Slider.MouseLeave:Connect(function()
		    Tween:Tween(Knob, UIPallet.Tween, {
		        Size = UDim2.fromOffset(14, 14)
		    })
		end)
		
		ValueLabel.MouseButton1Click:Connect(function()
		    ValueLabel.Visible = false
		    CustomBox.Visible = true
		    CustomBox.Text = Component.Value
		    CustomBox:CaptureFocus()
		end)
		
		CustomBox.FocusLost:Connect(function(Enter: boolean)
		    ValueLabel.Visible = true
		    CustomBox.Visible = false
		
		    if Enter and tonumber(CustomBox.Text) then
		        Component:SetValue(tonumber(CustomBox.Text), nil, true)
		    end
		end)
		
		API.Options[Props.Name] = Component
		
		return Component
	end,
	Targets = function(Props, Children, API)
		local Component = {
		    Default = {
		        Players = Props.Players and true or false,
		        NPCs = Props.NPCs and true or false,
		        Invisible = Props.Invisible and true or false,
		        Walls = Props.Walls and true or false,
		        Priority = "Players"
		    },
		    Index = GetTableSize(API.Options),
		    Type = "Targets"
		}
		
		local Targets: TextButton = Instance.new("TextButton")
		Targets.AutoButtonColor = false
		Targets.BackgroundColor3 = Color.Dark(Children.BackgroundColor3, Props.Darker and 0.02 or 0)
		Targets.BorderSizePixel = 0
		Targets.Size = UDim2.new(1, 0, 0, 50)
		Targets.Text = ""
		Targets.Visible = Props.Visible == nil or Props.Visible
		Targets.Parent = Children
		Component.Object = Targets
		AddTooltip(Targets, Props.Tooltip)
		local Holder: Frame = Instance.new("Frame")
		Holder.BackgroundColor3 = Color.Light(UIPallet.Main, 0.034)
		Holder.Position = UDim2.fromOffset(10, 4)
		Holder.Size = UDim2.new(1, -20, 1, -9)
		Holder.Parent = Targets
		AddCorner(Holder, UDim.new(0, 4))
		local Button: TextButton = Instance.new("TextButton")
		Button.AutoButtonColor = false
		Button.BackgroundColor3 = UIPallet.Main
		Button.Position = UDim2.fromOffset(1, 1)
		Button.Size = UDim2.new(1, -2, 1, -2)
		Button.Text = ""
		Button.Parent = Holder
		local Title: TextLabel = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.FontFace = UIPallet.Font
		Title.Position = UDim2.fromOffset(5, 6)
		Title.Size = UDim2.new(1, -5, 0, 15)
		Title.Text = "Target:"
		Title.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		Title.TextSize = 15
		Title.TextTruncate = Enum.TextTruncate.AtEnd
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Parent = Button
		local Items: TextLabel = Instance.new("TextLabel")
		Items.BackgroundTransparency = 1
		Items.FontFace = UIPallet.Font
		Items.Position = UDim2.fromOffset(5, 21)
		Items.Size = UDim2.new(1, -5, 0, 15)
		Items.Text = "Ignore none"
		Items.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		Items.TextSize = 11
		Items.TextTruncate = Enum.TextTruncate.AtEnd
		Items.TextXAlignment = Enum.TextXAlignment.Left
		Items.Parent = Button
		AddCorner(Button, UDim.new(0, 4))
		local IconHolder: Frame = Instance.new("Frame")
		IconHolder.BackgroundTransparency = 1
		IconHolder.Position = UDim2.fromOffset(52, 8)
		IconHolder.Size = UDim2.fromOffset(65, 12)
		IconHolder.Parent = Button
		local Layout: UIListLayout = Instance.new("UIListLayout")
		Layout.FillDirection = Enum.FillDirection.Horizontal
		Layout.Padding = UDim.new(0, 6)
		Layout.Parent = IconHolder
		local TargetsWindow: TextButton = Instance.new("TextButton")
		TargetsWindow.AutoButtonColor = false
		TargetsWindow.BackgroundColor3 = UIPallet.Main
		TargetsWindow.BorderSizePixel = 0
		TargetsWindow.Position = UDim2.fromOffset(456, 139)
		TargetsWindow.Size = UDim2.fromOffset(220, 145)
		TargetsWindow.Text = ""
		TargetsWindow.Visible = false
		TargetsWindow.Parent = ClickGUI
		Component.Window = TargetsWindow
		AddBlur(TargetsWindow)
		AddCorner(TargetsWindow)
		local Icon: ImageLabel = Instance.new("ImageLabel")
		Icon.BackgroundTransparency = 1
		Icon.Image = GetVapeAsset("kingvape/assets/new/aim.png")
		Icon.Position = UDim2.fromOffset(10, 15)
		Icon.Size = UDim2.fromOffset(18, 12)
		Icon.Parent = TargetsWindow
		local WindowTitle: TextLabel = Instance.new("TextLabel")
		WindowTitle.BackgroundTransparency = 1
		WindowTitle.FontFace = UIPallet.Font
		WindowTitle.Size = UDim2.new(1, -36, 0, 20)
		WindowTitle.Position = UDim2.fromOffset(math.abs(WindowTitle.Size.X.Offset), 11)
		WindowTitle.Text = "Target settings"
		WindowTitle.TextColor3 = UIPallet.Text
		WindowTitle.TextSize = 13
		WindowTitle.TextXAlignment = Enum.TextXAlignment.Left
		WindowTitle.Parent = TargetsWindow
		local Close: ImageButton = AddCloseButton(TargetsWindow)
		Props.Function = Props.Function or function() end
		
		function Component:Color(Hue: number, Sat: number, Val: number, IsRainbow: boolean)
		    if TargetsWindow.Visible then
		        Holder.BackgroundColor3 = IsRainbow and Color3.fromHSV(vape:Color((Hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(Hue, Sat, Val)
		    end
		
		    if self.Players.Enabled then
		        Tween:Cancel(self.Players.Object.Frame)
		        self.Players.Object.Frame.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
		    end
		
		    if self.NPCs.Enabled then
		        Tween:Cancel(self.NPCs.Object.Frame)
		        self.NPCs.Object.Frame.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
		    end
		
		    if self.Invisible.Enabled then
		        Tween:Cancel(self.Invisible.Object.Holder)
		        self.Invisible.Object.Holder.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
		    end
		
		    if self.Walls.Enabled then
		        Tween:Cancel(self.Walls.Object.Holder)
		        self.Walls.Object.Holder.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
		    end
		end
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    if self.Players.Enabled ~= Data.Players then
		        self.Players:Toggle()
		    end
		
		    if self.NPCs.Enabled ~= Data.NPCs then
		        self.NPCs:Toggle()
		    end
		
		    if self.Invisible.Enabled ~= Data.Invisible then
		        self.Invisible:Toggle()
		    end
		
		    if self.Walls.Enabled ~= Data.Walls then
		        self.Walls:Toggle()
		    end
		
		    if Data.Priority and self.Priority.Value ~= Data.Priority then
		        self.Priority:SetValue(Data.Priority)
		    end
		end
		
		function Component:Save(Data)
		    Data.Targets = {
		        Players = self.Players.Enabled,
		        NPCs = self.NPCs.Enabled,
		        Invisible = self.Invisible.Enabled,
		        Walls = self.Walls.Enabled,
		        Priority = self.Priority.Value
		    }
		end
		
		function Component:UpdateText()
		    local NewText: {string} = {}
		
		    if self.Players.Enabled then
		        table.insert(NewText, "Players")
		    end
		
		    if self.NPCs.Enabled then
		        table.insert(NewText, "NPCs")
		    end
		
		    Title.Text = `Target: {#NewText > 0 and table.concat(NewText, ", ") or "Nothing"}`
		    Title.TextColor3 = #NewText > 0 and UIPallet.Text or Color3.fromRGB(255, 90, 90)
		end
		
		Component.Players = Components.TargetsButton({
		    Position = UDim2.fromOffset(11, 45),
		    Icon = GetVapeAsset("kingvape/assets/new/players.png"),
		    IconSize = UDim2.fromOffset(16, 16),
		    IconParent = IconHolder,
		    Targets = Component,
		    Tooltip = "Target players",
		    Function = Props.Function
		}, TargetsWindow, IconHolder)
		
		Component.NPCs = Components.TargetsButton({
		    Position = UDim2.fromOffset(112, 45),
		    Icon = GetVapeAsset("kingvape/assets/new/npcs.png"),
		    IconSize = UDim2.fromOffset(12, 16),
		    IconParent = IconHolder,
		    Targets = Component,
		    Tooltip = "Target NPCs",
		    Function = Props.Function
		}, TargetsWindow, IconHolder)
		
		Component.Invisible = Components.Toggle({
		    Name = "Ignore invisible",
		    Function = function()
		        local NewText: {string} = {}
		
		        if Component.Invisible.Enabled then
		            table.insert(NewText, "invisible")
		        end
		
		        if Component.Walls.Enabled then
		            table.insert(NewText, "behind walls")
		        end
		
		        Items.Text = `Ignore {#NewText > 0 and table.concat(NewText, ", ") or "none"}`
		        Props.Function()
		    end
		}, TargetsWindow, {Options = {}})
		Component.Invisible.Object.Position = UDim2.fromOffset(0, 81)
		
		Component.Walls = Components.Toggle({
		    Name = "Ignore behind walls",
		    Function = function()
		        local NewText: {string} = {}
		
		        if Component.Invisible.Enabled then
		            table.insert(NewText, "invisible")
		        end
		
		        if Component.Walls.Enabled then
		            table.insert(NewText, "behind walls")
		        end
		
		        Items.Text = `Ignore {#NewText > 0 and table.concat(NewText, ", ") or "none"}`
		        Props.Function()
		    end
		}, TargetsWindow, {Options = {}})
		Component.Walls.Object.Position = UDim2.fromOffset(0, 111)
		
		Component.Priority = Components.Dropdown({
		    Name = "Priority",
		    List = {"Players", "NPCs", "None", "Closest", "Farthest", "Lowest health", "Highest health", "Crosshair"},
		    Function = Props.Function,
		    Tooltip = "Which target gets picked first when more than one is in range\nPlayers / NPCs - that kind wins, the modules own sorting breaks the tie\nClosest / Farthest - by range\nLowest / Highest health - finish someone off, or go for the healthy one\nCrosshair - whoever is nearest the middle of your screen"
		}, TargetsWindow, {Options = {}})
		Component.Priority.Object.Position = UDim2.fromOffset(0, 141)
		TargetsWindow.Size = UDim2.fromOffset(220, 145 + Component.Priority.Object.Size.Y.Offset)
		
		Component.Priority.Object:GetPropertyChangedSignal("Size"):Connect(function()
		    TargetsWindow.Size = UDim2.fromOffset(220, 145 + Component.Priority.Object.Size.Y.Offset)
		end)
		
		if Props.Players then
		    Component.Players:Toggle()
		end
		
		if Props.NPCs then
		    Component.NPCs:Toggle()
		end
		
		if Props.Invisible then
		    Component.Invisible:Toggle()
		end
		
		if Props.Walls then
		    Component.Walls:Toggle()
		end
		
		Close.MouseButton1Click:Connect(function()
		    TargetsWindow.Visible = false
		end)
		
		Button.MouseButton1Click:Connect(function()
		    TargetsWindow.Visible = not TargetsWindow.Visible
		    Tween:Cancel(Holder)
		
		    Holder.BackgroundColor3 = TargetsWindow.Visible and Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value) or Color.Light(UIPallet.Main, 0.37)
		end)
		
		Targets.MouseEnter:Connect(function()
		    if not TargetsWindow.Visible then
		        Tween:Tween(Holder, UIPallet.Tween, {
		            BackgroundColor3 = Color.Light(UIPallet.Main, 0.37)
		        })
		    end
		end)
		
		Targets.MouseLeave:Connect(function()
		    if not TargetsWindow.Visible then
		        Tween:Tween(Holder, UIPallet.Tween, {
		            BackgroundColor3 = Color.Light(UIPallet.Main, 0.034)
		        })
		    end
		end)
		
		Targets:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    local ActualPosition: Vector2 = (Targets.AbsolutePosition + Vector2.new(0, 60)) / Scale.Scale
		    TargetsWindow.Position = UDim2.fromOffset(ActualPosition.X + 223, ActualPosition.Y)
		end)
		
		API.Options.Targets = Component
		
		return Component
	end,
	TargetsButton = function(Props, Children, API)
		local Component = {
		    Enabled = false,
		    Type = "TargetsButton"
		}
		
		local TargetsButton: TextButton = Instance.new("TextButton")
		TargetsButton.AutoButtonColor = false
		TargetsButton.BackgroundColor3 = Color.Light(UIPallet.Main, 0.05)
		TargetsButton.Position = Props.Position
		TargetsButton.Size = UDim2.fromOffset(98, 31)
		TargetsButton.Text = ""
		TargetsButton.Visible = Props.Visible == nil or Props.Visible
		TargetsButton.Parent = Children
		Component.Object = TargetsButton
		AddCorner(TargetsButton)
		AddTooltip(TargetsButton, Props.Tooltip)
		local Holder: Frame = Instance.new("Frame")
		Holder.BackgroundColor3 = UIPallet.Main
		Holder.Position = UDim2.fromOffset(1, 1)
		Holder.Size = UDim2.new(1, -2, 1, -2)
		Holder.Parent = TargetsButton
		AddCorner(Holder)
		local Icon: ImageLabel = Instance.new("ImageLabel")
		Icon.AnchorPoint = Vector2.new(0.5, 0.5)
		Icon.BackgroundTransparency = 1
		Icon.Image = Props.Icon
		Icon.ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		Icon.Position = UDim2.fromScale(0.5, 0.5)
		Icon.Size = Props.IconSize
		Icon.Parent = Holder
		Props.Function = Props.Function or function() end
		
		function Component:Toggle()
		    self.Enabled = not self.Enabled
		
		    Tween:Tween(Holder, UIPallet.Tween, {
		        BackgroundColor3 = self.Enabled and Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value) or UIPallet.Main
		    })
		
		    Tween:Tween(Icon, UIPallet.Tween, {
		        ImageColor3 = self.Enabled and Color3.new(1, 1, 1) or Color.Light(UIPallet.Main, 0.37)
		    })
		
		    Props.Targets:UpdateText()
		    vape:QueueSave()
		    Props.Function(self.Enabled)
		end
		
		TargetsButton.MouseEnter:Connect(function()
		    if not Component.Enabled then
		        Tween:Tween(Holder, UIPallet.Tween, {
		            BackgroundColor3 = Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value - 0.25)
		        })
		
		        Tween:Tween(Icon, UIPallet.Tween, {
		            ImageColor3 = Color3.new(1, 1, 1)
		        })
		    end
		end)
		
		TargetsButton.MouseLeave:Connect(function()
		    if not Component.Enabled then
		        Tween:Tween(Holder, UIPallet.Tween, {
		            BackgroundColor3 = UIPallet.Main
		        })
		
		        Tween:Tween(Icon, UIPallet.Tween, {
		            ImageColor3 = Color.Light(UIPallet.Main, 0.37)
		        })
		    end
		end)
		
		TargetsButton.MouseButton1Click:Connect(function()
		    Component:Toggle()
		end)
		
		return Component
	end,
	TextBox = function(Props, Children, API)
		local Component = {
		    Index = 0,
		    Type = "TextBox",
		    Value = Props.Default or ""
		}
		
		local TextBox: TextButton = Instance.new("TextButton")
		TextBox.AutoButtonColor = false
		TextBox.BackgroundColor3 = Color.Dark(Children.BackgroundColor3, Props.Darker and 0.02 or 0)
		TextBox.BorderSizePixel = 0
		TextBox.Size = UDim2.new(1, 0, 0, 58)
		TextBox.Text = ""
		TextBox.Visible = Props.Visible == nil or Props.Visible
		TextBox.Parent = Children
		Component.Object = TextBox
		AddTooltip(TextBox, Props.Tooltip)
		local Title: TextLabel = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.FontFace = UIPallet.Font
		Title.Position = UDim2.fromOffset(10, 3)
		Title.Size = UDim2.new(1, -10, 0, 20)
		Title.Text = Props.Name
		Title.TextColor3 = UIPallet.Text
		Title.TextSize = 12
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Parent = TextBox
		local Holder: Frame = Instance.new("Frame")
		Holder.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		Holder.Position = UDim2.fromOffset(10, 23)
		Holder.Size = UDim2.new(1, -20, 0, 29)
		Holder.Parent = TextBox
		AddCorner(Holder, UDim.new(0, 4))
		local InputBox: TextBox = Instance.new("TextBox")
		InputBox.BackgroundTransparency = 1
		InputBox.ClearTextOnFocus = false
		InputBox.FontFace = UIPallet.Font
		InputBox.PlaceholderColor3 = Color.Dark(UIPallet.Text, 0.31)
		InputBox.PlaceholderText = Props.Placeholder or "Click to set"
		InputBox.Position = UDim2.fromOffset(8, 0)
		InputBox.Size = UDim2.new(1, -8, 1, 0)
		InputBox.Text = Props.Default or ""
		InputBox.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		InputBox.TextSize = 12
		InputBox.TextXAlignment = Enum.TextXAlignment.Left
		InputBox.Parent = Holder
		Props.Function = Props.Function or function() end
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    if self.Value ~= Data.Value then
		        self:SetValue(Data.Value)
		    end
		end
		
		function Component:Save(Data)
		    Data[Props.Name] = {
		        Value = self.Value
		    }
		end
		
		local Writing: boolean = false
		
		function Component:SetValue(Val: string, Enter: boolean?)
		    if Writing then return end
		
		    Writing = true
		    self.Value = Val
		    InputBox.Text = Val
		    Writing = false
		    vape:QueueSave()
		    Props.Function(Enter)
		end
		
		TextBox.MouseButton1Click:Connect(function()
		    InputBox:CaptureFocus()
		end)
		
		InputBox.FocusLost:Connect(function(Enter: boolean)
		    Component:SetValue(InputBox.Text, Enter)
		end)
		
		InputBox:GetPropertyChangedSignal("Text"):Connect(function()
		    Component:SetValue(InputBox.Text)
		end)
		
		API.Options[Props.Name] = Component
		
		return Component
	end,
	TextList = function(Props, Children, API)
		local Component = {
		    Default = Props.Default and table.clone(Props.Default) or {},
		    Icon = Props.Icon,
		    Index = GetTableSize(API.Options),
		    List = Props.Default and table.clone(Props.Default) or {},
		    ListEnabled = Props.Default and table.clone(Props.Default) or {},
		    Objects = {},
		    Type = "TextList",
		    Window = {Visible = false}
		}
		
		Props.Color = Props.Color or Color3.fromRGB(5, 134, 105)
		local TextList: TextButton = Instance.new("TextButton")
		TextList.AutoButtonColor = false
		TextList.BackgroundColor3 = Color.Dark(Children.BackgroundColor3, Props.Darker and 0.02 or 0)
		TextList.BorderSizePixel = 0
		TextList.Size = UDim2.new(1, 0, 0, 50)
		TextList.Text = ""
		TextList.Visible = Props.Visible == nil or Props.Visible
		TextList.Parent = Children
		Component.Object = TextList
		AddTooltip(TextList, Props.Tooltip)
		local Holder: Frame = Instance.new("Frame")
		Holder.BackgroundColor3 = Color.Light(UIPallet.Main, 0.034)
		Holder.Position = UDim2.fromOffset(10, 4)
		Holder.Size = UDim2.new(1, -20, 1, -9)
		Holder.Parent = TextList
		AddCorner(Holder, UDim.new(0, 4))
		local Button: TextButton = Instance.new("TextButton")
		Button.AutoButtonColor = false
		Button.BackgroundColor3 = UIPallet.Main
		Button.Position = UDim2.fromOffset(1, 1)
		Button.Size = UDim2.new(1, -2, 1, -2)
		Button.Text = ""
		Button.Parent = Holder
		local Icon: ImageLabel = Instance.new("ImageLabel")
		Icon.BackgroundTransparency = 1
		Icon.Image = GetVapeAsset("kingvape/assets/new/allowediconmini.png")
		Icon.Position = UDim2.fromOffset(10, 14)
		Icon.Size = UDim2.fromOffset(14, 12)
		Icon.Parent = Button
		local Title: TextLabel = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.FontFace = UIPallet.Font
		Title.Position = UDim2.fromOffset(35, 6)
		Title.Size = UDim2.new(1, -35, 0, 15)
		Title.Text = Props.Name
		Title.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		Title.TextSize = 15
		Title.TextTruncate = Enum.TextTruncate.AtEnd
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Parent = Button
		local Amount: TextLabel = Instance.fromExisting(Title)
		Amount.Position = UDim2.fromOffset(0, 6)
		Amount.Size = UDim2.new(1, -13, 0, 15)
		Amount.Text = "0"
		Amount.TextXAlignment = Enum.TextXAlignment.Right
		Amount.Parent = Button
		local Items: TextLabel = Instance.fromExisting(Title)
		Items.Position = UDim2.fromOffset(35, 21)
		Items.Text = "None"
		Items.TextColor3 = Color.Dark(UIPallet.Text, 0.43)
		Items.TextSize = 11
		Items.Parent = Button
		AddCorner(Button, UDim.new(0, 4))
		local TextListWindow: TextButton = Instance.new("TextButton")
		TextListWindow.AutoButtonColor = false
		TextListWindow.BackgroundColor3 = UIPallet.Main
		TextListWindow.BorderSizePixel = 0
		TextListWindow.Position = UDim2.fromOffset(456, 227)
		TextListWindow.Size = UDim2.fromOffset(220, 85)
		TextListWindow.Text = ""
		TextListWindow.Visible = false
		TextListWindow.Parent = API.Legit and vape.Legit.Window or ClickGUI
		Component.Window = TextListWindow
		AddBlur(TextListWindow)
		AddCorner(TextListWindow)
		local WindowIcon: ImageLabel = Instance.new("ImageLabel")
		WindowIcon.BackgroundTransparency = 1
		WindowIcon.Image = GetVapeAsset("kingvape/assets/new/allowedicon.png")
		WindowIcon.Position = UDim2.fromOffset(10, 13)
		WindowIcon.Size = UDim2.fromOffset(19, 16)
		WindowIcon.Parent = TextListWindow
		local WindowTitle: TextLabel = Instance.new("TextLabel")
		WindowTitle.BackgroundTransparency = 1
		WindowTitle.FontFace = UIPallet.Font
		WindowTitle.Position = UDim2.fromOffset(36, 11)
		WindowTitle.Size = UDim2.new(1, -36, 0, 20)
		WindowTitle.Text = Props.Name
		WindowTitle.TextColor3 = UIPallet.Text
		WindowTitle.TextSize = 13
		WindowTitle.TextXAlignment = Enum.TextXAlignment.Left
		WindowTitle.Parent = TextListWindow
		local Close: ImageButton = AddCloseButton(TextListWindow)
		local BoxHolder: Frame = Instance.new("Frame")
		BoxHolder.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		BoxHolder.Position = UDim2.fromOffset(10, 45)
		BoxHolder.Size = UDim2.fromOffset(200, 31)
		BoxHolder.Parent = TextListWindow
		AddCorner(BoxHolder)
		local BoxInner: Frame = Instance.new("Frame")
		BoxInner.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.02)
		BoxInner.Position = UDim2.fromOffset(1, 1)
		BoxInner.Size = UDim2.new(1, -2, 1, -2)
		BoxInner.Parent = BoxHolder
		AddCorner(BoxInner)
		local InputBox: TextBox = Instance.new("TextBox")
		InputBox.BackgroundTransparency = 1
		InputBox.ClearTextOnFocus = false
		InputBox.FontFace = UIPallet.Font
		InputBox.PlaceholderText = Props.Placeholder or "Add entry..."
		InputBox.PlaceholderColor3 = Color3.new(0.8, 0.8, 0.8)
		InputBox.Position = UDim2.fromOffset(10, 0)
		InputBox.Size = UDim2.new(1, -35, 1, 0)
		InputBox.Text = ""
		InputBox.TextColor3 = Color3.new(1, 1, 1)
		InputBox.TextSize = 13
		InputBox.TextXAlignment = Enum.TextXAlignment.Left
		InputBox.Parent = BoxHolder
		local AddButton: ImageButton = Instance.new("ImageButton")
		AddButton.BackgroundTransparency = 1
		AddButton.Image = GetVapeAsset("kingvape/assets/new/add.png")
		AddButton.ImageColor3 = Props.Color
		AddButton.ImageTransparency = 0.3
		AddButton.Position = UDim2.new(1, -26, 0, 8)
		AddButton.Size = UDim2.fromOffset(16, 16)
		AddButton.Parent = BoxHolder
		Props.Function = Props.Function or function() end
		
		function Component:Color(Hue: number, Sat: number, Val: number, IsRainbow: boolean)
		    if TextListWindow.Visible then
		        Holder.BackgroundColor3 = IsRainbow and Color3.fromHSV(vape:Color((Hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(Hue, Sat, Val)
		    end
		end
		
		function Component:ChangeValue(Value: string?)
		    if Value then
		        local Index: number? = table.find(self.List, Value)
		        if Index then
		            table.remove(self.List, Index)
		
		            Index = table.find(self.ListEnabled, Value)
		            if Index then
		                table.remove(self.ListEnabled, Index)
		            end
		        else
		            table.insert(self.List, Value)
		            table.insert(self.ListEnabled, Value)
		        end
		    end
		
		    vape:QueueSave()
		    Props.Function(self.List)
		    for _, v: TextButton in self.Objects do
		        v:Destroy()
		    end
		    table.clear(self.Objects)
		    TextListWindow.Size = UDim2.fromOffset(220, 85 + (#self.List * 35))
		    Amount.Text = #self.List
		    Items.Text = #self.ListEnabled > 0 and table.concat(self.ListEnabled, ", ") or "None"
		
		    for i: number, Entry: string in self.List do
		        local IsEnabled: number? = table.find(self.ListEnabled, Entry)
		        local Object: TextButton = Instance.new("TextButton")
		        Object.AutoButtonColor = false
		        Object.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		        Object.Position = UDim2.fromOffset(10, 47 + (i * 35))
		        Object.Size = UDim2.fromOffset(200, 31)
		        Object.Text = ""
		        Object.Parent = TextListWindow
		        AddCorner(Object)
		        local Background: Frame = Instance.new("Frame")
		        Background.BackgroundColor3 = UIPallet.Main
		        Background.Position = UDim2.fromOffset(1, 1)
		        Background.Size = UDim2.new(1, -2, 1, -2)
		        Background.Visible = false
		        Background.Parent = Object
		        AddCorner(Background)
		        local Dot: Frame = Instance.new("Frame")
		        Dot.BackgroundColor3 = IsEnabled and Props.Color or Color.Light(UIPallet.Main, 0.37)
		        Dot.Position = UDim2.fromOffset(10, 12)
		        Dot.Size = UDim2.fromOffset(10, 11)
		        Dot.Parent = Object
		        AddCorner(Dot, UDim.new(1, 0))
		        local DotInner: Frame = Dot:Clone()
		        DotInner.BackgroundColor3 = IsEnabled and Props.Color or Color.Light(UIPallet.Main, 0.02)
		        DotInner.Position = UDim2.fromOffset(1, 1)
		        DotInner.Size = UDim2.fromOffset(8, 9)
		        DotInner.Parent = Dot
		        local Label: TextLabel = Instance.new("TextLabel")
		        Label.BackgroundTransparency = 1
		        Label.FontFace = UIPallet.Font
		        Label.Position = UDim2.fromOffset(30, 0)
		        Label.Size = UDim2.new(1, -30, 1, 0)
		        Label.Text = Entry
		        Label.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		        Label.TextSize = 15
		        Label.TextXAlignment = Enum.TextXAlignment.Left
		        Label.Parent = Object
		        local RemoveButton: ImageButton = Instance.new("ImageButton")
		        RemoveButton.AutoButtonColor = false
		        RemoveButton.BackgroundColor3 = Color3.new(1, 1, 1)
		        RemoveButton.BackgroundTransparency = 1
		        RemoveButton.Image = GetVapeAsset("kingvape/assets/new/closetiny.png")
		        RemoveButton.ImageColor3 = Color.Light(UIPallet.Text, 0.2)
		        RemoveButton.ImageTransparency = 0.5
		        RemoveButton.Position = UDim2.new(1, -27, 0, 8)
		        RemoveButton.Size = UDim2.fromOffset(18, 17)
		        RemoveButton.Parent = Object
		        AddCorner(RemoveButton, UDim.new(1, 0))
		
		        RemoveButton.MouseEnter:Connect(function()
		            RemoveButton.ImageTransparency = 0.3
		            Tween:Tween(RemoveButton, UIPallet.Tween, {
		                BackgroundTransparency = 0.6
		            })
		        end)
		
		        RemoveButton.MouseLeave:Connect(function()
		            RemoveButton.ImageTransparency = 0.5
		            Tween:Tween(RemoveButton, UIPallet.Tween, {
		                BackgroundTransparency = 1
		            })
		        end)
		
		        RemoveButton.MouseButton1Click:Connect(function()
		            self:ChangeValue(Entry)
		        end)
		
		        Object.MouseEnter:Connect(function()
		            Background.Visible = true
		        end)
		
		        Object.MouseLeave:Connect(function()
		            Background.Visible = false
		        end)
		
		        Object.MouseButton1Click:Connect(function()
		            local EnabledIndex: number? = table.find(self.ListEnabled, Entry)
		            if EnabledIndex then
		                table.remove(self.ListEnabled, EnabledIndex)
		                Dot.BackgroundColor3 = Color.Light(UIPallet.Main, 0.37)
		                DotInner.BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		            else
		                table.insert(self.ListEnabled, Entry)
		                Dot.BackgroundColor3 = Props.Color
		                DotInner.BackgroundColor3 = Props.Color
		            end
		
		            Items.Text = #self.ListEnabled > 0 and table.concat(self.ListEnabled, ", ") or "None"
		            vape:QueueSave()
		            Props.Function()
		        end)
		
		        table.insert(self.Objects, Object)
		    end
		end
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    self.List = Data.List or {}
		    self.ListEnabled = Data.ListEnabled or {}
		    self:ChangeValue()
		end
		
		function Component:Save(Data)
		    Data[Props.Name] = {
		        List = self.List,
		        ListEnabled = self.ListEnabled
		    }
		end
		
		AddButton.MouseEnter:Connect(function()
		    AddButton.ImageTransparency = 0
		end)
		
		AddButton.MouseLeave:Connect(function()
		    AddButton.ImageTransparency = 0.3
		end)
		
		AddButton.MouseButton1Click:Connect(function()
		    if InputBox.Text ~= "" and not table.find(Component.List, InputBox.Text) then
		        Component:ChangeValue(InputBox.Text)
		        InputBox.Text = ""
		    end
		end)
		
		InputBox.FocusLost:Connect(function(Enter: boolean)
		    if Enter and InputBox.Text ~= "" and not table.find(Component.List, InputBox.Text) then
		        Component:ChangeValue(InputBox.Text)
		        InputBox.Text = ""
		    end
		end)
		
		InputBox.MouseEnter:Connect(function()
		    Tween:Tween(BoxHolder, UIPallet.Tween, {
		        BackgroundColor3 = Color.Light(UIPallet.Main, 0.14)
		    })
		end)
		
		InputBox.MouseLeave:Connect(function()
		    Tween:Tween(BoxHolder, UIPallet.Tween, {
		        BackgroundColor3 = Color.Light(UIPallet.Main, 0.02)
		    })
		end)
		
		Close.MouseButton1Click:Connect(function()
		    TextListWindow.Visible = false
		end)
		
		Button.MouseButton1Click:Connect(function()
		    TextListWindow.Visible = not TextListWindow.Visible
		
		    Tween:Cancel(Holder)
		    Holder.BackgroundColor3 = TextListWindow.Visible and Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value) or Color.Light(UIPallet.Main, 0.37)
		end)
		
		TextList.MouseEnter:Connect(function()
		    if not TextListWindow.Visible then
		        Tween:Tween(Holder, UIPallet.Tween, {
		            BackgroundColor3 = Color.Light(UIPallet.Main, 0.37)
		        })
		    end
		end)
		
		TextList.MouseLeave:Connect(function()
		    if not TextListWindow.Visible then
		        Tween:Tween(Holder, UIPallet.Tween, {
		            BackgroundColor3 = Color.Light(UIPallet.Main, 0.034)
		        })
		    end
		end)
		
		TextList:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    local ActualPosition: Vector2 = (TextList.AbsolutePosition - (API.Legit and vape.Legit.Window.AbsolutePosition or -GuiService:GetGuiInset())) / Scale.Scale
		    TextListWindow.Position = UDim2.fromOffset(ActualPosition.X + 223, ActualPosition.Y)
		end)
		
		if Props.Default then
		    Component:ChangeValue()
		end
		
		API.Options[Props.Name] = Component
		
		return Component
	end,
	Toggle = function(Props, Children, API)
		local Component = {
		    Default = Props.Default and true or false,
		    Enabled = false,
		    Index = GetTableSize(API.Options),
		    Name = Props.Name,
		    Type = "Toggle"
		}
		
		local IsHover: boolean = false
		local Toggle: TextButton = Instance.new("TextButton")
		Toggle.AutoButtonColor = false
		Toggle.BackgroundColor3 = Color.Dark(Children.BackgroundColor3, Props.Darker and 0.02 or 0)
		Toggle.BorderSizePixel = 0
		Toggle.FontFace = UIPallet.Font
		Toggle.Size = UDim2.new(1, 0, 0, 30)
		Toggle.Text = `          {Props.Name}`
		Toggle.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		Toggle.TextSize = 14
		Toggle.TextXAlignment = Enum.TextXAlignment.Left
		Toggle.Visible = Props.Visible == nil or Props.Visible
		Toggle.Parent = Children
		Component.Object = Toggle
		AddTooltip(Toggle, Props.Tooltip)
		local Holder: Frame = Instance.new("Frame")
		Holder.BackgroundColor3 = Color.Light(UIPallet.Main, 0.14)
		Holder.Name = "Holder"
		Holder.Position = UDim2.new(1, -30, 0, 9)
		Holder.Size = UDim2.fromOffset(22, 12)
		Holder.Parent = Toggle
		AddCorner(Holder, UDim.new(1, 0))
		local Knob: Frame = Instance.new("Frame")
		Knob.BackgroundColor3 = UIPallet.Main
		Knob.Position = UDim2.fromOffset(2, 2)
		Knob.Size = UDim2.fromOffset(8, 8)
		Knob.Parent = Holder
		AddCorner(Knob, UDim.new(1, 0))
		Props.Function = Props.Function or function() end
		
		function Component:Color(Hue: number, Sat: number, Val: number, IsRainbow: boolean)
		    if self.Enabled then
		        Tween:Cancel(Holder)
		        Holder.BackgroundColor3 = IsRainbow and Color3.fromHSV(vape:Color((Hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(Hue, Sat, Val)
		    end
		end
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    if self.Enabled ~= (Data.Enabled or false) then
		        self:Toggle()
		    end
		
		    if self.Bind and Data.Bind then
		        self.Bind:Load(Data.Bind)
		    end
		end
		
		function Component:Save(Data)
		    Data[Props.Name] = {
		        Enabled = self.Enabled
		    }
		
		    if self.Bind then
		        self.Bind:Save(Data[Props.Name])
		    end
		end
		
		function Component:Toggle()
		    local IsRainbow: boolean = vape.GUIColor.Rainbow and vape.RainbowMode.Value ~= "Retro"
		    self.Enabled = not self.Enabled
		
		    Tween:Tween(Holder, UIPallet.Tween, {
		        BackgroundColor3 = self.Enabled and (IsRainbow and Color3.fromHSV(vape:Color((vape.GUIColor.Hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)) or (IsHover and Color.Light(UIPallet.Main, 0.37) or Color.Light(UIPallet.Main, 0.14))
		    })
		
		    Tween:Tween(Knob, UIPallet.Tween, {
		        Position = UDim2.fromOffset(self.Enabled and 12 or 2, 2)
		    })
		
		    vape:QueueSave()
		    Props.Function(self.Enabled)
		end
		
		Toggle.MouseEnter:Connect(function()
		    IsHover = true
		
		    if not Component.Enabled then
		        Tween:Tween(Holder, UIPallet.Tween, {
		            BackgroundColor3 = Color.Light(UIPallet.Main, 0.37)
		        })
		    end
		end)
		
		Toggle.MouseLeave:Connect(function()
		    IsHover = false
		
		    if not Component.Enabled then
		        Tween:Tween(Holder, UIPallet.Tween, {
		            BackgroundColor3 = Color.Light(UIPallet.Main, 0.14)
		        })
		    end
		end)
		
		Toggle.MouseButton1Click:Connect(function()
		    Component:Toggle()
		end)
		
		if Props.Default then
		    Component:Toggle()
		end
		
		API.Options[Props.Name] = Component
		
		return Component
	end,
	TwoSlider = function(Props, Children, API)
		local Component = {
		    Decimal = Props.Decimal or 1,
		    DefaultMin = Props.DefaultMin or Props.Min,
		    DefaultMax = Props.DefaultMax or 10,
		    Index = GetTableSize(API.Options),
		    Max = Props.Max,
		    Min = Props.Min,
		    Type = "TwoSlider",
		    ValueMin = Props.DefaultMin or Props.Min,
		    ValueMax = Props.DefaultMax or 10
		}
		
		local TwoSlider: TextButton = Instance.new("TextButton")
		TwoSlider.AutoButtonColor = false
		TwoSlider.BackgroundColor3 = Color.Dark(Children.BackgroundColor3, Props.Darker and 0.02 or 0)
		TwoSlider.BorderSizePixel = 0
		TwoSlider.Size = UDim2.new(1, 0, 0, 50)
		TwoSlider.Text = ""
		TwoSlider.Visible = Props.Visible == nil or Props.Visible
		TwoSlider.Parent = Children
		Component.Object = TwoSlider
		AddTooltip(TwoSlider, Props.Tooltip)
		local Title: TextLabel = Instance.new("TextLabel")
		Title.BackgroundTransparency = 1
		Title.FontFace = UIPallet.Font
		Title.Position = UDim2.fromOffset(10, 2)
		Title.Size = UDim2.fromOffset(60, 30)
		Title.Text = Props.Name
		Title.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		Title.TextSize = 11
		Title.TextXAlignment = Enum.TextXAlignment.Left
		Title.Parent = TwoSlider
		local MaxValue: TextButton = Instance.new("TextButton")
		MaxValue.BackgroundTransparency = 1
		MaxValue.FontFace = UIPallet.Font
		MaxValue.Position = UDim2.new(1, -69, 0, 9)
		MaxValue.Size = UDim2.fromOffset(60, 15)
		MaxValue.Text = Component.ValueMax
		MaxValue.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		MaxValue.TextSize = 11
		MaxValue.TextXAlignment = Enum.TextXAlignment.Right
		MaxValue.Parent = TwoSlider
		local MinValue: TextButton = MaxValue:Clone()
		MinValue.Position = UDim2.new(1, -125, 0, 9)
		MinValue.Text = Component.ValueMin
		MinValue.Parent = TwoSlider
		local CustomMax: TextBox = Instance.new("TextBox")
		CustomMax.BackgroundTransparency = 1
		CustomMax.ClearTextOnFocus = false
		CustomMax.FontFace = UIPallet.Font
		CustomMax.Position = MaxValue.Position
		CustomMax.Size = UDim2.fromOffset(60, 15)
		CustomMax.Text = Component.ValueMax
		CustomMax.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
		CustomMax.TextSize = 11
		CustomMax.TextXAlignment = Enum.TextXAlignment.Right
		CustomMax.Visible = false
		CustomMax.Parent = TwoSlider
		local CustomMin: TextBox = CustomMax:Clone()
		CustomMin.Position = MinValue.Position
		CustomMin.Parent = TwoSlider
		local Holder: Frame = Instance.new("Frame")
		Holder.BackgroundColor3 = Color.Light(UIPallet.Main, 0.034)
		Holder.BorderSizePixel = 0
		Holder.Position = UDim2.fromOffset(10, 37)
		Holder.Size = UDim2.new(1, -20, 0, 2)
		Holder.Parent = TwoSlider
		local Fill: Frame = Instance.new("Frame")
		Fill.BackgroundColor3 = Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
		Fill.BorderSizePixel = 0
		Fill.Position = UDim2.fromScale(math.clamp((Component.ValueMin - Props.Min) / (Props.Max - Props.Min), 0.04, 0.96), 0)
		Fill.Size = UDim2.fromScale(math.clamp(math.clamp((Component.ValueMax - Props.Min) / (Props.Max - Props.Min), 0.04, 0.96) - Fill.Position.X.Scale, 0, 1), 1)
		Fill.Parent = Holder
		local Knob: Frame = Instance.new("Frame")
		Knob.AnchorPoint = Vector2.new(0.5, 0.5)
		Knob.BackgroundColor3 = TwoSlider.BackgroundColor3
		Knob.BorderSizePixel = 0
		Knob.Position = UDim2.fromScale(0, 0.5)
		Knob.Size = UDim2.fromOffset(16, 4)
		Knob.Parent = Fill
		local KnobImage: ImageLabel = Instance.new("ImageLabel")
		KnobImage.AnchorPoint = Vector2.new(0.5, 0.5)
		KnobImage.BackgroundTransparency = 1
		KnobImage.Image = GetVapeAsset("kingvape/assets/new/range.png")
		KnobImage.ImageColor3 = Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
		KnobImage.Position = UDim2.fromScale(0.5, 0.5)
		KnobImage.Size = UDim2.fromOffset(9, 16)
		KnobImage.Parent = Knob
		local KnobMax: Frame = Knob:Clone()
		KnobMax.Position = UDim2.fromScale(1, 0.5)
		KnobMax.Parent = Fill
		local KnobMaxImage: ImageLabel = KnobMax.ImageLabel
		KnobMaxImage.Rotation = 180
		local Arrow: ImageLabel = Instance.new("ImageLabel")
		Arrow.BackgroundTransparency = 1
		Arrow.Image = GetVapeAsset("kingvape/assets/new/rangeindicator.png")
		Arrow.ImageColor3 = Color.Light(UIPallet.Main, 0.14)
		Arrow.Position = UDim2.new(1, -56, 0, 10)
		Arrow.Size = UDim2.fromOffset(12, 6)
		Arrow.Parent = TwoSlider
		Props.Function = Props.Function or function() end
		Props.Decimal = Props.Decimal or 1
		local RandomGenerator: Random = Random.new()
		
		function Component:Color(Hue: number, Sat: number, Val: number, IsRainbow: boolean)
		    Fill.BackgroundColor3 = IsRainbow and Color3.fromHSV(vape:Color((Hue - (self.Index * 0.075)) % 1)) or Color3.fromHSV(Hue, Sat, Val)
		    KnobImage.ImageColor3 = Fill.BackgroundColor3
		    KnobMaxImage.ImageColor3 = Fill.BackgroundColor3
		end
		
		function Component:GetRandomValue()
		    return RandomGenerator:NextNumber(Component.ValueMin, Component.ValueMax)
		end
		
		function Component:Load(Data)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    local ValueMin: number = Data.ValueMin or self.ValueMin
		    local ValueMax: number = Data.ValueMax or self.ValueMax
		
		    if self.ValueMin ~= ValueMin then
		        self:SetValue(false, ValueMin)
		    end
		
		    if self.ValueMax ~= ValueMax then
		        self:SetValue(true, ValueMax)
		    end
		end
		
		function Component:Save(Data)
		    Data[Props.Name] = {
		        ValueMin = self.ValueMin,
		        ValueMax = self.ValueMax
		    }
		end
		
		function Component:SetValue(IsMax: boolean, Value: number)
		    if not IsFinite(Value) then
		        return
		    end
		
		    self[IsMax and "ValueMax" or "ValueMin"] = Value
		    MaxValue.Text = self.ValueMax
		    MinValue.Text = self.ValueMin
		
		    local MinScale: number = math.clamp(math.clamp((self.ValueMin - Props.Min) / (Props.Max - Props.Min), 0, 1), 0.04, 0.96)
		    Tween:Tween(Fill, TweenInfo.new(0.1), {
		        Position = UDim2.fromScale(MinScale, 0),
		        Size = UDim2.fromScale(math.clamp(math.clamp((self.ValueMax - Props.Min) / (Props.Max - Props.Min), 0.04, 0.96) - MinScale, 0, 1), 1)
		    })
		
		    vape:QueueSave()
		end
		
		Knob.MouseEnter:Connect(function()
		    Tween:Tween(KnobImage, UIPallet.Tween, {
		        Size = UDim2.fromOffset(11, 18)
		    })
		end)
		
		Knob.MouseLeave:Connect(function()
		    Tween:Tween(KnobImage, UIPallet.Tween, {
		        Size = UDim2.fromOffset(9, 16)
		    })
		end)
		
		KnobMax.MouseEnter:Connect(function()
		    Tween:Tween(KnobMaxImage, UIPallet.Tween, {
		        Size = UDim2.fromOffset(11, 18)
		    })
		end)
		
		KnobMax.MouseLeave:Connect(function()
		    Tween:Tween(KnobMaxImage, UIPallet.Tween, {
		        Size = UDim2.fromOffset(9, 16)
		    })
		end)
		
		TwoSlider.InputBegan:Connect(function(Input: InputObject)
		    if vape.ThreadFix then
		        setthreadidentity(8)
		    end
		
		    if
		        (Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch)
		        and (Input.Position.Y - TwoSlider.AbsolutePosition.Y) > (20 * Scale.Scale)
		    then
		        local MaxCheck: boolean = (Input.Position.X - KnobMax.AbsolutePosition.X) > -10
		        local NewPosition: number = math.clamp((Input.Position.X - Holder.AbsolutePosition.X) / Holder.AbsoluteSize.X, 0, 1)
		
		        local ReleaseConnection
		        local MoveConnection: RBXScriptConnection = UserInputService.InputChanged:Connect(function(NewInput: InputObject)
		            if vape.ThreadFix then
		                setthreadidentity(8)
		            end
		
		            if NewInput.UserInputType == (Input.UserInputType == Enum.UserInputType.MouseButton1 and Enum.UserInputType.MouseMovement or Enum.UserInputType.Touch) then
		                local NewPosition: number = math.clamp((NewInput.Position.X - Holder.AbsolutePosition.X) / Holder.AbsoluteSize.X, 0, 1)
		                Component:SetValue(MaxCheck, math.floor((Props.Min + (Props.Max - Props.Min) * NewPosition) * Props.Decimal) / Props.Decimal, NewPosition)
		            end
		        end)
		
		        ReleaseConnection = Input.Changed:Connect(function()
		            if Input.UserInputState == Enum.UserInputState.End then
		                MoveConnection:Disconnect()
		                ReleaseConnection:Disconnect()
		            end
		        end)
		
		        Component:SetValue(MaxCheck, math.floor((Props.Min + (Props.Max - Props.Min) * NewPosition) * Props.Decimal) / Props.Decimal, NewPosition)
		    end
		end)
		
		MaxValue.MouseButton1Click:Connect(function()
		    MaxValue.Visible = false
		    CustomMax.Visible = true
		    CustomMax.Text = Component.ValueMax
		    CustomMax:CaptureFocus()
		end)
		
		MinValue.MouseButton1Click:Connect(function()
		    MinValue.Visible = false
		    CustomMin.Visible = true
		    CustomMin.Text = Component.ValueMin
		    CustomMin:CaptureFocus()
		end)
		
		CustomMax.FocusLost:Connect(function(Enter: boolean)
		    MaxValue.Visible = true
		    CustomMax.Visible = false
		
		    if Enter and tonumber(CustomMax.Text) then
		        Component:SetValue(true, tonumber(CustomMax.Text))
		    end
		end)
		
		CustomMin.FocusLost:Connect(function(Enter: boolean)
		    MinValue.Visible = true
		    CustomMin.Visible = false
		
		    if Enter and tonumber(CustomMin.Text) then
		        Component:SetValue(false, tonumber(CustomMin.Text))
		    end
		end)
		
		API.Options[Props.Name] = Component
		
		return Component
	end,
}

vape.Components = setmetatable(Components, {
    __newindex = function(_, Index: string, Callback)
        rawset(Components, Index, Callback)

        for _, Module: any in vape.Modules do
            rawset(Module, `Create{Index}`, function(_, Properties)
                if not Properties.Module then
                    table.insert(Module.OptionSpecs, {Type = Index, Settings = Properties})
                end

                return Callback(Properties, Module.Children, Module)
            end)
        end

        if vape.Legit then
            for _, Module: any in vape.Legit.Modules do
                rawset(Module, `Create{Index}`, function(_, Properties)
                    return Callback(Properties, Module.Children, Module)
                end)
            end
        end
    end
})

vape:LoadGUI()

local DeferHandout = DeferLoad
local function RunPremium(Source: string, License)
    local Chunk, Error = loadstring(Source, "premium")
    if not Chunk then
        error(Error or "unknown")
    end

    local Claim = DeferHandout
    DeferHandout = nil
    return Chunk(License, Claim)
end

return vape, RunPremium