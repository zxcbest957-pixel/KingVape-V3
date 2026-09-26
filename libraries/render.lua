local Render = {
    Fonts = {
        UI = 0,
        System = 1,
        Plex = 2,
        Monospace = 3
    },
    Objects = {},
    Old = {},
    Installed = false,
    Mobile = false
}

local cloneref = cloneref or function(Reference: Instance)
    return Reference
end
local getgenv = getgenv or function()
    return shared
end
local Players: Players = cloneref(game:GetService("Players"))
local UserInputService: UserInputService = cloneref(game:GetService("UserInputService"))
local HttpService: HttpService = cloneref(game:GetService("HttpService"))
local LocalPlayer: Player = Players.LocalPlayer
local Fonts: {[number]: Font} = {
    [0] = Font.fromEnum(Enum.Font.SourceSans),
    [1] = Font.fromEnum(Enum.Font.Code),
    [2] = Font.fromEnum(Enum.Font.Code),
    [3] = Font.fromEnum(Enum.Font.RobotoMono)
}
local Classes = {}
local Paints: {[string]: boolean} = {
    Visible = true,
    ZIndex = true,
    Color = true,
    Transparency = true,
    Outline = true,
    OutlineColor = true
}
local WedgeImage: string = "iVBORw0KGgoAAAANSUhEUgAAAQAAAAEACAYAAABccqhmAAAFeElEQVR42u3dSU4DQRQFQd//Ej5qAws2iMHGPVRVxpM+B7CcIQEebtu23TczK+5+e/9xg4BZL/6P9j8BgIBZLP6vAEDALBT/dwBAwCwS/08AQMAsEP9vAEDAbPH4/wIAAmYLx/8IABAwWzT+RwGAgNmC8T8DAATMFov/WQAgYLZQ/P8BAAJmi8T/XwAgYLZA/K8AAAGzyeN/FQAImE0c/x4AQMBs0vj3AgACZhPGvycAEDCbLP69AYCA2UTxHwEABMwmif8oACBgNkH8RwIAAbPB4z8aAAiYDRz/GQBAwGzQ+M8CAAJmA8Z/JgAQMBss/rMBgIDZQPFfAQAEzAaJ/yoAIGA2QPxXAgABs4vjvxoACJhdGP8IAEDAxB8HAAIm/jgAEDDxxwGAgIk/DgAETPxxACBg4o8DAAETfxwACJj44wBAwMQfBwACJv44ABAw8ccBgICJPw4ABEz8cQAgYOKPAwABE38cAAiY+OMAQMDEHwcAAib+OAAQMPHHAYCAiT8OAARM/HEAIGDijwMAARN/HAAImPjjAEDAxB8HAAIm/jgAEDDxxwGAgIk/DgAETPxxACBg4o8DAAHLx18HAAKWjh8AEBB//PkPAAiIHwAOAuIHgIOA+AEAARM/ACBg4gcABEz8AICAiR8AEDDxAwACJn4AQMDEDwAImPgBAAETPwAgYOIHAARM/ACAgIkfABAw8QMAAiZ+AEDAxA8ACJj4AQABEz8AIGDiBwAETPwAgICJHwAQEL8DAATE7wAAAfE7AEBA/A4AEBC/AwAExO8AAAHxOwBAQPwOABAQvwMABMTvAAAB8TsAQED8DgAQEL8DAATEDwAPAgTEDwAHAfEDwEFA/ABwEBA/ABwExA8ABwHxA8BBQPwAcBAQPwAcBMQPAAcB8QPARREQPwBcFAHxA8BFERA/AFwUAfEDwEURED8AXBQB8QPARREQPwBcFAHxA8BFERA/AFwUAfEDwEURED8AXBQB8QPARREQPwBcFAHxA8BFERA/AFwUAfEDwAHAAcD5FcABwPkjoAOA829ABwDnhUAOAM5LgR0AnDcDOQA4bwd2AHA+EMQBwPlIMAcA50NBHQCcjwV3AHC+GMQBwPlqMAcA58tBHQCcrwd3AHALxA8BALh4/BAAgIvHDwEAuHj8EACAi8cPAQC4ePwQAICLxw8BALh4/BAAgIvHDwEAuHj8EACAi8cPAQC4ePwQAICLxw8BALh4/BAAgIvHDwEAuHj8EACAi8cPAQCI3yAAAPEbBAAgfgh4fgBA/BDwXAGA+CHgACB+CDgAiB8CDgDih4ADgPgh4AAgfgg4AIgfAg4A4oeAA4D4IeAAIH4IOACIHwIOAOKHgAOA+CHgACB+CDgAiB8CAPAgiB8CAHDihwAAnPghAAAnfggAwIkfAgAQv0EAAOI3CABA/AYBAIjfIAAA8RsEACB+gwAAxG8QAID4DQIAEL9BAADiNwgAQPwGAQCI3yAAAPEbBAAgfoMAAMRvEACA+A0CABC/QQAA4jcIAED8BgEAiN8gAADxGwQAIH6DAADEbxAoAyB+g0AUAPEbBKIAiN8gEAVA/AaBKADiNwhEARC/QSAKgPgNAlEAxG8QiAIgfoNAFADxGwSiAIjfIBAFQPwGgSgA4jcIRAEQv0EgCoD4DQJRAMRvEIgCIH6DQBQA8ZtdjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjID4zcIIiN8sjMAbGq/zRXlT3IgAAAAASUVORK5CYII="
local WedgeAsset: string = ""
local ImageCache: {[string]: string} = {}
local ScreenGui: ScreenGui?
local MeasureLabel: TextLabel?

local function CreateBody(Set, Class: string)
    Set.Body = Instance.new(Class)
    Set.Body.BackgroundTransparency = 1
    Set.Body.BorderSizePixel = 0
    Set.Body.Visible = false
end

local function CreateStroke(Set, Mode: Enum.ApplyStrokeMode, Join: Enum.LineJoinMode)
    Set.Stroke = Instance.new("UIStroke")
    Set.Stroke.ApplyStrokeMode = Mode
    Set.Stroke.Color = Color3.new()
    Set.Stroke.Enabled = false
    Set.Stroke.LineJoinMode = Join
    Set.Stroke.Parent = Set.Body
    table.insert(Set.Instances, Set.Stroke)
end

local function CreateCorner(Set, Radius: UDim)
    Set.Corner = Instance.new("UICorner")
    Set.Corner.CornerRadius = Radius
    Set.Corner.Parent = Set.Body
    table.insert(Set.Instances, Set.Corner)
end

local function CreatePolygon(Set, LineCount: number, WedgeCount: number)
    for i: number = 1, LineCount do
        local Line: Frame = Instance.new("Frame")
        Line.AnchorPoint = Vector2.new(0.5, 0.5)
        Line.BorderSizePixel = 0
        Line.Visible = false
        Line.Parent = ScreenGui
        Set.Lines[i] = Line
        table.insert(Set.Instances, Line)
    end
    for i: number = 1, WedgeCount do
        local Wedge: ImageLabel = Instance.new("ImageLabel")
        Wedge.AnchorPoint = Vector2.new(0.5, 0.5)
        Wedge.BackgroundTransparency = 1
        Wedge.BorderSizePixel = 0
        Wedge.Image = WedgeAsset
        Wedge.ImageRectSize = Vector2.new(128, 128)
        Wedge.Visible = false
        Wedge.Parent = ScreenGui
        Set.Wedges[i] = Wedge
        table.insert(Set.Instances, Wedge)
    end
end

local function PaintPolygon(Set)
    local Properties = Set.Props
    local Transparency: number = 1 - math.clamp(Properties.Transparency, 0, 1)
    for _, v: Frame in Set.Lines do
        v.BackgroundColor3 = Properties.Color
        v.BackgroundTransparency = Transparency
        v.Visible = Properties.Visible and not Properties.Filled
        v.ZIndex = Properties.ZIndex
    end
    for _, v: ImageLabel in Set.Wedges do
        v.ImageColor3 = Properties.Color
        v.ImageTransparency = Transparency
        v.Visible = Properties.Visible and Properties.Filled
        v.ZIndex = Properties.ZIndex
    end
end

local function SetLine(Frame: Frame, From: Vector2, To: Vector2, Thickness: number)
    local Direction: Vector2 = To - From
    Frame.Position = UDim2.fromOffset((From.X + To.X) / 2, (From.Y + To.Y) / 2)
    Frame.Size = UDim2.fromOffset(Direction.Magnitude, Thickness)
    Frame.Rotation = math.deg(math.atan2(Direction.Y, Direction.X))
end

local function SetWedge(Set, First: number, Second: number, A: Vector2, B: Vector2, C: Vector2)
    local AB, AC, BC = B - A, C - A, C - B
    local ABDot, ACDot, BCDot = AB:Dot(AB), AC:Dot(AC), BC:Dot(BC)
    if ABDot > ACDot and ABDot > BCDot then
        A, C = C, A
    elseif ACDot > BCDot and ACDot > ABDot then
        A, B = B, A
    end

    AB, BC = B - A, C - B
    if BC.Magnitude <= 0 then
        Set.Wedges[First].Size = UDim2.new()
        Set.Wedges[Second].Size = UDim2.new()
        return
    end

    local Unit: Vector2 = BC.Unit
    local Height: number = Unit.X * AB.Y - Unit.Y * AB.X
    local Theta: number = math.deg(math.atan2(Unit.Y, Unit.X))
    local Tall: number = math.abs(Height)
    local Row: number = Height >= 0 and 128 or 0
    Set.Wedges[First].ImageRectOffset = Vector2.new(0, Row)
    Set.Wedges[First].Rotation = Theta
    Set.Wedges[First].Position = UDim2.fromOffset((A.X + B.X) / 2, (A.Y + B.Y) / 2)
    Set.Wedges[First].Size = UDim2.fromOffset(math.abs(Unit:Dot(AB)), Tall)
    Set.Wedges[Second].ImageRectOffset = Vector2.new(128, Row)
    Set.Wedges[Second].Rotation = Theta
    Set.Wedges[Second].Position = UDim2.fromOffset((A.X + C.X) / 2, (A.Y + C.Y) / 2)
    Set.Wedges[Second].Size = UDim2.fromOffset(math.abs(Unit:Dot(C - A)), Tall)
end

local function GetAsset(Data: string)
    if Data == "" or Data:find("://") then
        return Data
    end
    if not ImageCache[Data] then
        if not writefile or not getcustomasset then
            return ""
        end
        local FilePath: string = `kingvape/assets/drawing/{HttpService:GenerateGUID(false)}.png`
        writefile(FilePath, Data)
        ImageCache[Data] = getcustomasset(FilePath)
    end

    return ImageCache[Data]
end

Classes.Base = {
    Properties = {
        Visible = false,
        ZIndex = 1,
        Transparency = 1,
        Color = Color3.new()
    }
}

Classes.Line = {
    Properties = {
        From = Vector2.zero,
        To = Vector2.zero,
        Thickness = 1
    },
    Create = function(Set)
        CreateBody(Set, "Frame")
        Set.Body.AnchorPoint = Vector2.new(0.5, 0.5)
        Set.Body.Parent = ScreenGui
        table.insert(Set.Instances, Set.Body)
    end,
    Paint = function(Set)
        local Properties = Set.Props
        Set.Body.BackgroundColor3 = Properties.Color
        Set.Body.BackgroundTransparency = 1 - math.clamp(Properties.Transparency, 0, 1)
        Set.Body.Visible = Properties.Visible
        Set.Body.ZIndex = Properties.ZIndex
    end,
    Shape = function(Set)
        local Properties = Set.Props
        SetLine(Set.Body, Properties.From, Properties.To, Properties.Thickness)
    end
}

Classes.Text = {
    Properties = {
        Text = "",
        Font = 0,
        Size = 16,
        Position = Vector2.zero,
        Center = false,
        Outline = false,
        OutlineColor = Color3.new(),
        TextBounds = Vector2.zero
    },
    Create = function(Set)
        CreateBody(Set, "TextLabel")
        Set.Body.RichText = false
        Set.Body.TextWrapped = false
        Set.Body.TextXAlignment = Enum.TextXAlignment.Center
        Set.Body.TextYAlignment = Enum.TextYAlignment.Top
        CreateStroke(Set, Enum.ApplyStrokeMode.Contextual, Enum.LineJoinMode.Round)
        Set.Body.Parent = ScreenGui
        table.insert(Set.Instances, Set.Body)
    end,
    Paint = function(Set)
        local Properties = Set.Props
        local Transparency: number = 1 - math.clamp(Properties.Transparency, 0, 1)
        Set.Body.TextColor3 = Properties.Color
        Set.Body.TextTransparency = Transparency
        Set.Stroke.Enabled = Properties.Outline
        Set.Stroke.Color = Properties.OutlineColor
        Set.Stroke.Transparency = Transparency
        Set.Body.Visible = Properties.Visible
        Set.Body.ZIndex = Properties.ZIndex
    end,
    Shape = function(Set)
        local Properties = Set.Props
        MeasureLabel.FontFace = Fonts[Properties.Font] or Fonts[0]
        MeasureLabel.TextSize = Properties.Size
        MeasureLabel.Text = Properties.Text
        Properties.TextBounds = MeasureLabel.TextBounds
        Set.Body.FontFace = MeasureLabel.FontFace
        Set.Body.TextSize = Properties.Size
        Set.Body.Text = Properties.Text
        Set.Body.AnchorPoint = Vector2.new(Properties.Center and 0.5 or 0, 0)
        Set.Body.Position = UDim2.fromOffset(Properties.Position.X, Properties.Position.Y)
        Set.Body.Size = UDim2.fromOffset(Properties.TextBounds.X, Properties.TextBounds.Y)
    end
}

Classes.Image = {
    Properties = {
        Data = "",
        Size = Vector2.zero,
        Position = Vector2.zero,
        Rounding = 0,
        Color = Color3.new(1, 1, 1)
    },
    Create = function(Set)
        CreateBody(Set, "ImageLabel")
        CreateCorner(Set, UDim.new())
        Set.Body.Parent = ScreenGui
        table.insert(Set.Instances, Set.Body)
    end,
    Paint = function(Set)
        local Properties = Set.Props
        Set.Body.ImageColor3 = Properties.Color
        Set.Body.ImageTransparency = 1 - math.clamp(Properties.Transparency, 0, 1)
        Set.Body.Visible = Properties.Visible
        Set.Body.ZIndex = Properties.ZIndex
    end,
    Shape = function(Set)
        local Properties = Set.Props
        Set.Body.Position = UDim2.fromOffset(Properties.Position.X, Properties.Position.Y)
        Set.Body.Size = UDim2.fromOffset(Properties.Size.X, Properties.Size.Y)
        Set.Body.Image = GetAsset(Properties.Data)
        Set.Corner.CornerRadius = UDim.new(0, Properties.Rounding)
    end
}

Classes.Circle = {
    Properties = {
        Position = Vector2.zero,
        Radius = 0,
        NumSides = 250,
        Thickness = 1,
        Filled = false
    },
    Create = function(Set)
        CreateBody(Set, "Frame")
        Set.Body.AnchorPoint = Vector2.new(0.5, 0.5)
        CreateCorner(Set, UDim.new(0.5, 0))
        CreateStroke(Set, Enum.ApplyStrokeMode.Border, Enum.LineJoinMode.Round)
        Set.Body.Parent = ScreenGui
        table.insert(Set.Instances, Set.Body)
    end,
    Paint = function(Set)
        local Properties = Set.Props
        local Transparency: number = 1 - math.clamp(Properties.Transparency, 0, 1)
        Set.Body.BackgroundColor3 = Properties.Color
        Set.Body.BackgroundTransparency = Properties.Filled and Transparency or 1
        Set.Stroke.Enabled = not Properties.Filled
        Set.Stroke.Color = Properties.Color
        Set.Stroke.Thickness = Properties.Thickness
        Set.Stroke.Transparency = Transparency
        Set.Body.Visible = Properties.Visible
        Set.Body.ZIndex = Properties.ZIndex
    end,
    Shape = function(Set)
        local Properties = Set.Props
        local Diameter: number = Properties.Radius * 2 - (Properties.Filled and 0 or Properties.Thickness)
        Set.Body.Position = UDim2.fromOffset(Properties.Position.X, Properties.Position.Y)
        Set.Body.Size = UDim2.fromOffset(Diameter, Diameter)
    end
}

Classes.Square = {
    Properties = {
        Position = Vector2.zero,
        Size = Vector2.zero,
        Thickness = 1,
        Filled = false
    },
    Create = function(Set)
        CreateBody(Set, "Frame")
        CreateStroke(Set, Enum.ApplyStrokeMode.Border, Enum.LineJoinMode.Miter)
        Set.Body.Parent = ScreenGui
        table.insert(Set.Instances, Set.Body)
    end,
    Paint = function(Set)
        local Properties = Set.Props
        local Transparency: number = 1 - math.clamp(Properties.Transparency, 0, 1)
        Set.Body.BackgroundColor3 = Properties.Color
        Set.Body.BackgroundTransparency = Properties.Filled and Transparency or 1
        Set.Stroke.Enabled = not Properties.Filled
        Set.Stroke.Color = Properties.Color
        Set.Stroke.Thickness = Properties.Thickness
        Set.Stroke.Transparency = Transparency
        Set.Body.Visible = Properties.Visible
        Set.Body.ZIndex = Properties.ZIndex
    end,
    Shape = function(Set)
        local Properties = Set.Props
        local Inset: number = Properties.Filled and 0 or Properties.Thickness / 2
        local Corner: Vector2 = Vector2.new(math.min(Properties.Position.X, Properties.Position.X + Properties.Size.X), math.min(Properties.Position.Y, Properties.Position.Y + Properties.Size.Y))
        Set.Body.Position = UDim2.fromOffset(Corner.X + Inset, Corner.Y + Inset)
        Set.Body.Size = UDim2.fromOffset(math.abs(Properties.Size.X) - Inset * 2, math.abs(Properties.Size.Y) - Inset * 2)
    end
}

Classes.Triangle = {
    Properties = {
        PointA = Vector2.zero,
        PointB = Vector2.zero,
        PointC = Vector2.zero,
        Thickness = 1,
        Filled = false
    },
    Create = function(Set)
        CreatePolygon(Set, 3, 2)
    end,
    Paint = function(Set)
        PaintPolygon(Set)
    end,
    Shape = function(Set)
        local Properties = Set.Props
        SetLine(Set.Lines[1], Properties.PointA, Properties.PointB, Properties.Thickness)
        SetLine(Set.Lines[2], Properties.PointB, Properties.PointC, Properties.Thickness)
        SetLine(Set.Lines[3], Properties.PointC, Properties.PointA, Properties.Thickness)
        SetWedge(Set, 1, 2, Properties.PointA, Properties.PointB, Properties.PointC)
    end
}

Classes.Quad = {
    Properties = {
        PointA = Vector2.zero,
        PointB = Vector2.zero,
        PointC = Vector2.zero,
        PointD = Vector2.zero,
        Thickness = 1,
        Filled = false
    },
    Create = function(Set)
        CreatePolygon(Set, 4, 4)
    end,
    Paint = function(Set)
        PaintPolygon(Set)
    end,
    Shape = function(Set)
        local Properties = Set.Props
        SetLine(Set.Lines[1], Properties.PointA, Properties.PointB, Properties.Thickness)
        SetLine(Set.Lines[2], Properties.PointB, Properties.PointC, Properties.Thickness)
        SetLine(Set.Lines[3], Properties.PointC, Properties.PointD, Properties.Thickness)
        SetLine(Set.Lines[4], Properties.PointD, Properties.PointA, Properties.Thickness)
        SetWedge(Set, 1, 2, Properties.PointA, Properties.PointB, Properties.PointC)
        SetWedge(Set, 3, 4, Properties.PointA, Properties.PointC, Properties.PointD)
    end
}

Render.new = function(Class: string)
    local ClassData = Classes[Class]
    if not ClassData or Class == "Base" then
        return
    end

    local Set = {
        Class = Class,
        Exists = true,
        Instances = {},
        Lines = {},
        Props = table.clone(Classes.Base.Properties),
        Wedges = {}
    }
    for Property: string, v: any in ClassData.Properties do
        Set.Props[Property] = v
    end
    ClassData.Create(Set)

    local Address: string = tostring(Set):match("0x(%x+)") or "0000000000000000"
    local Proxy = newproxy(true)
    local Meta = getmetatable(Proxy)

    local function Remove()
        if not Set.Exists then
            return
        end
        Set.Exists = false
        for _, v: Instance in Set.Instances do
            v:Destroy()
        end
        table.clear(Set.Instances)
        table.clear(Set.Lines)
        table.clear(Set.Wedges)
        Render.Objects[Proxy] = nil
    end

    Meta.__index = function(_, Key)
        if Key == "Remove" or Key == "Destroy" then
            return Remove
        end
        if Key == "__OBJECT_EXISTS" then
            return Set.Exists
        end

        return Set.Props[Key]
    end
    Meta.__newindex = function(_, Key, Value)
        local Old = Set.Props[Key]
        if Old == nil or Key == "TextBounds" then
            return
        end
        if typeof(Value) ~= typeof(Old) then
            error(`invalid argument #3 to '__newindex' ({typeof(Old)} expected, got {typeof(Value)})`, 2)
        end

        Set.Props[Key] = Key == "ZIndex" and math.floor(Value) or Value
        if not Set.Exists then
            return
        end
        if Paints[Key] then
            ClassData.Paint(Set)
        elseif Key == "Filled" or Key == "Thickness" then
            ClassData.Shape(Set)
            ClassData.Paint(Set)
        else
            ClassData.Shape(Set)
        end
    end
    Meta.__tostring = function()
        return `DrawingObject: 0x{Address}`
    end

    ClassData.Shape(Set)
    ClassData.Paint(Set)
    Render.Objects[Proxy] = Set

    return Proxy
end

Render.clear = function()
    for Object: any in table.clone(Render.Objects) do
        Object:Remove()
    end
    table.clear(Render.Objects)
end

Render.install = function()
    if Render.Installed then
        return
    end
    Render.Installed = true

    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.DisplayOrder = 2147483647
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.Name = HttpService:GenerateGUID(false)
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
    if not pcall(function()
        ScreenGui.Parent = gethui and gethui() or cloneref(game:GetService("CoreGui"))
    end) then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    MeasureLabel = Instance.new("TextLabel")
    MeasureLabel.BackgroundTransparency = 1
    MeasureLabel.Size = UDim2.fromOffset(9999, 9999)
    MeasureLabel.Text = ""
    MeasureLabel.TextTransparency = 1
    MeasureLabel.TextXAlignment = Enum.TextXAlignment.Left
    MeasureLabel.TextYAlignment = Enum.TextYAlignment.Top
    MeasureLabel.Parent = ScreenGui

    if not isfolder("kingvape/assets/drawing") then
        makefolder("kingvape/assets/drawing")
    end
    if not isfile("kingvape/assets/drawing/wedge.png") then
        writefile("kingvape/assets/drawing/wedge.png", base64decode(WedgeImage))
    end
    local Success, Asset = pcall(getcustomasset, "kingvape/assets/drawing/wedge.png")
    WedgeAsset = Success and Asset or ""

    Render.Old = {
        Drawing = Drawing,
        cleardrawcache = cleardrawcache,
        isrenderobj = isrenderobj
    }
    getgenv().Drawing = {
        Fonts = Render.Fonts,
        clear = Render.clear,
        new = Render.new
    }
    getgenv().cleardrawcache = function()
        Render.clear()
        if Render.Old.cleardrawcache then
            Render.Old.cleardrawcache()
        end
    end
    getgenv().isrenderobj = function(Object)
        return Render.Objects[Object] ~= nil or (Render.Old.isrenderobj and Render.Old.isrenderobj(Object)) == true
    end
    getgenv().getrenderproperty = function(Object, Property: string)
        return Object[Property]
    end
    getgenv().setrenderproperty = function(Object, Property: string, Value)
        Object[Property] = Value
    end
end

Render.uninstall = function()
    if not Render.Installed then
        return
    end
    Render.Installed = false

    Render.clear()
    ScreenGui:Destroy()
    ScreenGui, MeasureLabel, WedgeAsset = nil, nil, ""
    getgenv().Drawing = Render.Old.Drawing
    getgenv().cleardrawcache = Render.Old.cleardrawcache
    getgenv().isrenderobj = Render.Old.isrenderobj
    table.clear(ImageCache)
end

Render.Mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
if Render.Mobile or not pcall(function()
    Drawing.new("Square"):Remove()
end) then
    Render.install()
end

return Render