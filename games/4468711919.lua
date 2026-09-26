local Run = function(Func: () -> ())
    Func()
end
local cloneref = cloneref or function(Reference: Instance)
    return Reference
end

local Players: Players = cloneref(game:GetService("Players"))
local RunService: RunService = cloneref(game:GetService("RunService"))

local LocalPlayer: Player = Players.LocalPlayer
local vape = shared.vape

local Golf = {}

Run(function()
    Golf = {
        CameraController = require(LocalPlayer.PlayerScripts.Controllers.CameraController),
        GameController = require(LocalPlayer.PlayerScripts.Controllers.GameController),
        MechanicsController = require(LocalPlayer.PlayerScripts.Controllers.MechanicsController)
    }

    vape:Clean(function()
        table.clear(Golf)
    end)
end)

Run(function()
	local GolfAssist
	local Aim
	local LegitAim
	local AimSpeed
	local Power
	local LegitPower
	local PowerSpeed
	local AutoShoot
	local Legit
	local Strokes
	local Path
	local Samples
	local Color
	
	local Folder, Anchor, Old
	local Best, Origin, Current, Field, Solved, Latency, Fired, Pending, Spin, Driven, Unsynced
	local Parts: {Part} = {}
	local Events = {}
	local Connections: {RBXScriptConnection} = {}
	local SolveId: number = 0
	
	local function GetField(Hole: Instance, Finish: BasePart, Group: string)
	    local Area: number = 0
	    for _, v: Instance in Hole.Green:GetDescendants() do
	        if v:IsA("BasePart") then
	            Area += v.Size.X * v.Size.Z
	        end
	    end
	
	    local Spacing: number = math.max(3, math.sqrt(Area / 4000))
	    local Include: RaycastParams = RaycastParams.new()
	    Include.FilterType = Enum.RaycastFilterType.Include
	    local Nodes, Cells = {}, {}
	    for _, v: Instance in Hole.Green:GetDescendants() do
	        if v:IsA("BasePart") and v.CanCollide then
	            Include.FilterDescendantsInstances = {v}
	            for X: number = 0, math.floor(v.Size.X / Spacing) do
	                for Z: number = 0, math.floor(v.Size.Z / Spacing) do
	                    local Point: Vector3 = v.CFrame * Vector3.new(X * Spacing - v.Size.X * 0.5, 0, Z * Spacing - v.Size.Z * 0.5)
	                    local Hit: RaycastResult? = workspace:Raycast(Point + Vector3.new(0, v.Size.Magnitude, 0), Vector3.new(0, -v.Size.Magnitude * 2, 0), Include)
	                    if Hit and Hit.Normal.Y > 0.3 then
	                        local Node = {position = Hit.Position + Vector3.new(0, 1, 0), distance = math.huge, links = {}, index = #Nodes + 1}
	                        local Key: string = `{math.floor(Node.position.X / (Spacing * 1.5))},{math.floor(Node.position.Z / (Spacing * 1.5))}`
	                        Cells[Key] = Cells[Key] or {}
	                        table.insert(Cells[Key], Node)
	                        table.insert(Nodes, Node)
	                    end
	                end
	            end
	        end
	    end
	
	    local Params: RaycastParams = RaycastParams.new()
	    Params.RespectCanCollide = true
	    Params.CollisionGroup = Group
	    for _, v: any in Nodes do
	        local X, Z = math.floor(v.position.X / (Spacing * 1.5)), math.floor(v.position.Z / (Spacing * 1.5))
	        for CellX: number = X - 1, X + 1 do
	            for CellZ: number = Z - 1, Z + 1 do
	                for _, Neighbor: any in Cells[`{CellX},{CellZ}`] or {} do
	                    local Offset: Vector3 = Neighbor.position - v.position
	                    if Neighbor.index > v.index and Offset.Magnitude <= Spacing * 1.5 and math.abs(Offset.Y) <= Spacing and not workspace:Raycast(v.position, Offset, Params) then
	                        table.insert(v.links, Neighbor)
	                        table.insert(Neighbor.links, v)
	                    end
	                end
	            end
	        end
	        if v.index % 500 == 0 then
	            task.wait()
	        end
	    end
	
	    local Queue = {}
	    for _, v: any in Nodes do
	        if (v.position - Finish.Position).Magnitude <= Spacing * 2 + Finish.Size.Magnitude * 0.5 then
	            v.distance = (v.position - Finish.Position).Magnitude
	            table.insert(Queue, v)
	        end
	    end
	    local Head: number = 1
	    while Queue[Head] do
	        for _, v: any in Queue[Head].links do
	            if Queue[Head].distance + (v.position - Queue[Head].position).Magnitude < v.distance then
	                v.distance = Queue[Head].distance + (v.position - Queue[Head].position).Magnitude
	                table.insert(Queue, v)
	            end
	        end
	        Head += 1
	    end
	
	    return {cells = Cells, size = Spacing * 1.5, finish = Finish.Position}
	end
	
	local function GetDistance(Position: Vector3): number
	    local X, Z = math.floor(Position.X / Field.size), math.floor(Position.Z / Field.size)
	    local Closest: number = math.huge
	    for CellX: number = X - 1, X + 1 do
	        for CellZ: number = Z - 1, Z + 1 do
	            for _, v: any in Field.cells[`{CellX},{CellZ}`] or {} do
	                if math.abs(v.position.Y - Position.Y) <= Field.size then
	                    Closest = math.min(Closest, v.distance + (v.position - Position).Magnitude)
	                end
	            end
	        end
	    end
	
	    return Closest < math.huge and Closest or (Position - Field.finish).Magnitude
	end
	
	local function GetDelay(Shot): number
	    if Unsynced then
	        return 0
	    end
	
	    local Offset: number = Driven and Driven.ReceiveAge > 0 and (Latency or LocalPlayer:GetNetworkPing()) or 0
	    if Spin then
	        return (Shot.launched - Offset - os.clock()) % Spin
	    end
	
	    local Event
	    for _, v: any in Events do
	        if not Event or v[1] <= Shot.launched then
	            Event = v
	        end
	    end
	    if not Event then
	        return 0
	    end
	
	    local First, Last, Count
	    for _, v: any in Events do
	        if v[2] == Event[2] and v[3] == Event[3] then
	            First, Last, Count = First or v[1], v[1], (Count or 0) + 1
	        end
	    end
	    if Count < 2 then
	        return 0
	    end
	
	    return (Last - (os.clock() + Offset - (Shot.launched - Event[1]))) % ((Last - First) / (Count - 1))
	end
	
	local function Launch(Shots, Limit: number, Context)
	    for _, v: any in Shots do
	        local Part: Part = Instance.new("Part")
	        Part.Anchored = true
	        Part.Shape = Enum.PartType.Ball
	        Part.Size = Context.ball.Part.Size
	        Part.CustomPhysicalProperties = Context.ball.Part.CurrentPhysicalProperties
	        Part.CollisionGroup = Context.ball.Part.CollisionGroup
	        Part.CanQuery = false
	        Part.CanTouch = false
	        Part.Transparency = 1
	        Part.CFrame = CFrame.new(Context.ball.Part.Position)
	        local Attachment: Attachment = Instance.new("Attachment")
	        Attachment.Parent = Part
	        local Align: AlignOrientation = Instance.new("AlignOrientation")
	        Align.Attachment0 = Attachment
	        Align.Attachment1 = Anchor
	        Align.RigidityEnabled = true
	        Align.Parent = Part
	        Part.Parent = Folder
	        v.part, v.path, v.approach = Part, {Part.Position}, math.huge
	    end
	
	    local Params: RaycastParams = RaycastParams.new()
	    Params.RespectCanCollide = true
	    Params.CollisionGroup = Context.ball.Part.CollisionGroup
	    local Half: Vector3 = Context.finish.Size * 0.5
	    local Began, Done = os.clock(), false
	    repeat
	        RunService.Heartbeat:Wait()
	        local Moving: boolean = false
	        for _, v: any in Shots do
	            if v.part and Context.id == SolveId then
	                if not v.launched then
	                    if os.clock() - Began >= (v.delay or 0) then
	                        v.part.Anchored = false
	                        v.part.AssemblyLinearVelocity = CFrame.Angles(0, v.yaw, 0).LookVector * v.power * 2
	                        v.launched = os.clock()
	                    end
	                    Moving = true
	                    continue
	                end
	
	                local Position: Vector3 = v.part.Position
	                local Relative: Vector3 = Context.finish.CFrame:PointToObjectSpace(Position)
	                v.approach = math.min(v.approach, (Position - Context.finish.Position).Magnitude)
	                if (Position - v.path[#v.path]).Magnitude > 1 then
	                    table.insert(v.path, Position)
	                end
	
	                if not v.part.Parent or Position.Y < Context.floor then
	                    v.result = "oob"
	                elseif (Relative - Relative:Max(-Half):Min(Half)).Magnitude <= v.part.Size.X * 0.5 then
	                    v.result = "holed"
	                    table.insert(v.path, Position)
	                    Done = Context.racing
	                elseif v.part.AssemblyLinearVelocity.Magnitude < 0.1 then
	                    v.still = v.still or os.clock()
	                    if os.clock() - v.still > 0.25 then
	                        local Hit: RaycastResult? = workspace:Raycast(Position, Vector3.new(0, -v.part.Size.Y, 0), Params)
	                        v.result = Hit and Hit.Instance:IsDescendantOf(Context.hole.Green) and "rest" or "oob"
	                    end
	                else
	                    v.still = nil
	                end
	
	                if v.result then
	                    v.part:Destroy()
	                    v.part, v.time = nil, os.clock() - v.launched
	                else
	                    Moving = true
	                end
	            end
	        end
	    until Done or not Moving or os.clock() - Began > Limit
	
	    for _, v: any in Shots do
	        if v.part then
	            v.part:Destroy()
	            v.part = nil
	        end
	    end
	end
	
	local function Solve(Ball)
	    SolveId += 1
	    local Id: number = SolveId
	    Origin, Best, Solved = Ball.Part.Position, nil, nil
	
	    local Params: RaycastParams = RaycastParams.new()
	    Params.RespectCanCollide = true
	    Params.CollisionGroup = Ball.Part.CollisionGroup
	    local Hit: RaycastResult? = workspace:Raycast(Origin, Vector3.new(0, -Ball.Part.Size.Y, 0), Params)
	    local Hole = Hit and Hit.Instance
	    while Hole and Hole.Parent and Hole.Parent.Name ~= "Holes" do
	        Hole = Hole.Parent
	    end
	    local Finish = Hole and Hole:FindFirstChild("Finish")
	    Finish = Finish and Finish:FindFirstChildWhichIsA("BasePart", true)
	    if not Finish or not Hole:FindFirstChild("Green") then
	        return
	    end
	
	    if Hole ~= Current then
	        Field = GetField(Hole, Finish, Ball.Part.CollisionGroup)
	        if Id ~= SolveId then
	            return
	        end
	
	        Current, Spin, Driven, Unsynced = Hole, nil, nil, false
	        for _, v: RBXScriptConnection in Connections do
	            v:Disconnect()
	        end
	        table.clear(Connections)
	        table.clear(Events)
	        for _, v: Instance in Hole:GetDescendants() do
	            if v:IsA("AlignPosition") or v:IsA("AlignOrientation") then
	                Driven = v.Attachment0 and v.Attachment0.Parent or Driven
	                table.insert(Connections, v:GetPropertyChangedSignal("Attachment1"):Connect(function()
	                    table.insert(Events, {os.clock(), v, v.Attachment1})
	                    if #Events > 200 then
	                        table.remove(Events, 1)
	                    end
	                end))
	            elseif v:IsA("AngularVelocity") and v.AngularVelocity.Magnitude > 0.001 then
	                Driven = v.Attachment0 and v.Attachment0.Parent or Driven
	                Unsynced = Unsynced or Spin and math.abs(Spin - math.pi * 2 / v.AngularVelocity.Magnitude) > 0.01
	                Spin = math.pi * 2 / v.AngularVelocity.Magnitude
	            elseif v:IsA("Constraint") and not v:IsA("AngularVelocity") then
	                Unsynced = true
	            end
	        end
	        Unsynced = Unsynced or Spin and #Connections > 0
	    end
	
	    local Floor: number = Finish.Position.Y
	    for _, v: Instance in Hole.Green:GetDescendants() do
	        if v:IsA("BasePart") then
	            Floor = math.min(Floor, v.Position.Y - v.Size.Magnitude * 0.5)
	        end
	    end
	
	    local Remaining: number = Legit.Enabled and Strokes.Value - Golf.GameController.CurrentGame:GetGamePlayer(LocalPlayer):Get("Strokes") or 1
	    local Target: number? = Remaining > 1 and math.min(GetDistance(Origin) * (Remaining - 1) / Remaining, 10 * (Remaining - 1)) or nil
	    local Penalty: number = GetDistance(Origin) + 100
	    local Context = {id = Id, ball = Ball, hole = Hole, finish = Finish, floor = Floor - 50, racing = Golf.GameController.CurrentGame:Get("Settings Win Condition") == "Quickest Time"}
	    local MaxPower: number = Golf.MechanicsController:GetMaxPower()
	    local MinPower: number = Golf.MechanicsController:GetThresholdPower()
	    local Yaws: number = math.max(math.floor(Samples.Value / 7), 8)
	    local YawStep, PowerStep = math.pi * 2 / Yaws, MaxPower * 0.16
	    local Shots, Results, Limit = {}, {}, Context.racing and 6 or 12
	    for YawIndex: number = 1, Yaws do
	        for PowerIndex: number, Fraction: number in {0.08, 0.16, 0.26, 0.38, 0.54, 0.74, 1} do
	            table.insert(Shots, {yaw = YawIndex * YawStep, power = math.max(Fraction * MaxPower, MinPower), seed = 0, i = YawIndex, j = PowerIndex})
	        end
	    end
	
	    for Pass: number = 1, 4 do
	        Launch(Shots, math.min(Limit, 12), Context)
	        if Id ~= SolveId then
	            return
	        end
	
	        for _, v: any in Shots do
	            v.score = v.result == "holed" and (Target and Penalty or 0) or v.result == "rest" and math.abs(GetDistance(v.path[#v.path]) - (Target or 0)) or Penalty
	        end
	        for _, v: any in Shots do
	            local Total, Count = 0, 0
	            for _, Other: any in Shots do
	                if Other ~= v and Other.seed == v.seed and math.abs(Other.i - v.i) <= 1 and math.abs(Other.j - v.j) <= 1 then
	                    Total, Count = Total + Other.score, Count + 1
	                end
	            end
	            v.risk = v.score + (Count > 0 and Total / Count * 0.1 or 0)
	            if v.score < Penalty then
	                table.insert(Results, v)
	                if not Best or v.risk < Best.risk then
	                    Best = v
	                end
	            end
	        end
	
	        if Best then
	            for i: number, Part: Part in Parts do
	                Part.Position = Best.path[math.ceil(i * #Best.path / #Parts)]
	                Part.Transparency = Path.Enabled and 0.35 or 1
	            end
	        end
	        if Pass == 4 or Context.racing or Pass > 1 and Best and Best.risk == 0 then
	            break
	        end
	
	        table.sort(Shots, function(A, B)
	            return math.min(A.score, Target and math.huge or A.approach * 4) < math.min(B.score, Target and math.huge or B.approach * 4)
	        end)
	        YawStep, PowerStep = YawStep / 2.5, PowerStep / 2.5
	        local Seeds = {}
	        for _, v: any in Shots do
	            if #Seeds >= 5 - Pass then
	                break
	            end
	            local Fresh: boolean = true
	            for _, Seed: any in Seeds do
	                if math.abs(Seed.yaw - v.yaw) < YawStep * 3 and math.abs(Seed.power - v.power) < PowerStep * 3 then
	                    Fresh = false
	                    break
	                end
	            end
	            if Fresh then
	                table.insert(Seeds, v)
	            end
	        end
	
	        Shots, Limit = {}, 1
	        for _, v: any in Seeds do
	            Limit = math.max(Limit, (v.time or 12) * 1.5 + 1)
	            for Cell: number = 0, 24 do
	                table.insert(Shots, {yaw = v.yaw + (Cell % 5 - 2) * YawStep, power = math.clamp(v.power + (Cell // 5 - 2) * PowerStep, MinPower, MaxPower), seed = v, i = Cell % 5, j = Cell // 5})
	            end
	        end
	    end
	
	    for _, v: any in Events do
	        local Paired: boolean = false
	        for _, Other: any in Events do
	            if Other[2] == Events[1][2] and math.abs(Other[1] - v[1]) < 0.2 then
	                Paired = true
	                break
	            end
	        end
	        if not Paired then
	            Unsynced = true
	            break
	        end
	    end
	
	    if Unsynced and Best and not Context.racing then
	        table.sort(Results, function(A, B)
	            return A.risk < B.risk
	        end)
	        Shots = {}
	        for _, v: any in Results do
	            if #Shots >= 48 then
	                break
	            end
	            for DelaySeconds: number = 0, 7 do
	                table.insert(Shots, {yaw = v.yaw, power = v.power, delay = DelaySeconds, seed = v})
	            end
	        end
	
	        Launch(Shots, 20, Context)
	        if Id ~= SolveId then
	            return
	        end
	
	        Best = nil
	        for _, v: any in Shots do
	            v.seed.average = (v.seed.average or 0) + (v.result == "holed" and (Target and Penalty or 0) or v.result == "rest" and math.abs(GetDistance(v.path[#v.path]) - (Target or 0)) or Penalty) / 8
	        end
	        for _, v: any in Shots do
	            if not Best or v.seed.average < Best.average then
	                Best = v.seed
	            end
	        end
	        for i: number, v: Part in Parts do
	            v.Position = Best.path[math.ceil(i * #Best.path / #Parts)]
	            v.Transparency = Path.Enabled and 0.35 or 1
	        end
	    end
	    Solved = Best ~= nil
	end
	
	GolfAssist = vape.Categories.Utility:CreateModule({
	    Name = "GolfAssist",
	    Function = function(Callback: boolean)
	        if Callback then
	            Folder = Instance.new("Folder")
	            Folder.Name = "catvapegolf"
	            Folder.Parent = workspace
	            Anchor = Instance.new("Attachment")
	            Anchor.Parent = workspace.Terrain
	
	            for i: number = 1, 50 do
	                local Part: Part = Instance.new("Part")
	                Part.Anchored = true
	                Part.CanCollide = false
	                Part.CanQuery = false
	                Part.CanTouch = false
	                Part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	                Part.Material = Enum.Material.Neon
	                Part.Shape = Enum.PartType.Ball
	                Part.Size = Vector3.new(0.6, 0.6, 0.6)
	                Part.Transparency = 1
	                Part.Parent = Folder
	                Parts[i] = Part
	            end
	
	            Old = Golf.MechanicsController.ShootWithParams
	            Golf.MechanicsController.ShootWithParams = function(self, Yaw: number, ShotPower: number, Pitch: number)
	                if Pending then
	                    return
	                end
	
	                local Shot = Best
	                Pending = true
	                task.delay(Shot and GetDelay(Shot) or 0, function()
	                    Pending, Fired = nil, os.clock()
	                    Old(self, Shot and (Aim.Enabled or AutoShoot.Enabled) and Shot.yaw or Yaw, Shot and (Power.Enabled or AutoShoot.Enabled) and Shot.power or ShotPower, Pitch)
	                end)
	            end
	
	            GolfAssist:Clean(RunService.RenderStepped:Connect(function(Delta: number)
	                local Golfer = Golf.MechanicsController.LocalGolfer
	                local Ball = Golfer and Golfer.Ball
	                if Fired and Ball and Ball.Part.AssemblyLinearVelocity.Magnitude > 1 then
	                    Latency, Fired = os.clock() - Fired, nil
	                end
	                if Origin and (not Ball or (Ball.Part.Position - Origin).Magnitude > 0.5) then
	                    SolveId += 1
	                    Origin, Best, Solved = nil, nil, nil
	                    for _, v: Part in Parts do
	                        v.Transparency = 1
	                    end
	                end
	                if not Origin and Ball and Golfer:CanShoot() and Golfer:Get("ShootingDirection") == "Forward" then
	                    task.spawn(Solve, Ball)
	                end
	                if not Best then
	                    return
	                end
	
	                local Camera = Golf.CameraController:GetCamera("Classic")
	                local Turn: number = (Best.yaw - Camera.Rotation.Y + math.pi) % (math.pi * 2) - math.pi
	                if Golf.MechanicsController.IsAiming then
	                    if Aim.Enabled or AutoShoot.Enabled then
	                        Camera.Rotation = Vector2.new(Camera.Rotation.X, Camera.Rotation.Y + (LegitAim.Enabled and Turn * math.min(Delta * AimSpeed.Value, 1) or Turn))
	                    end
	                    if Power.Enabled or AutoShoot.Enabled then
	                        Golf.MechanicsController:SetPower(LegitPower.Enabled and Golf.MechanicsController.Power + math.clamp(Best.power - Golf.MechanicsController.Power, -PowerSpeed.Value * Delta, PowerSpeed.Value * Delta) or Best.power)
	                    end
	                end
	
	                if AutoShoot.Enabled and not Pending and not Fired and Golfer:CanShoot() then
	                    if not Golf.MechanicsController.IsAiming then
	                        Golf.MechanicsController:SetAiming(true)
	                    elseif Solved and math.abs(Turn) < 0.002 and math.abs(Golf.MechanicsController.Power - Best.power) < 0.01 and GetDelay(Best) < 0.1 then
	                        Solved = nil
	                        Golf.MechanicsController:Shoot()
	                    end
	                end
	            end))
	        else
	            Golf.MechanicsController.ShootWithParams = Old
	            SolveId += 1
	            Origin, Best, Current, Field, Solved = nil, nil, nil, nil, nil
	            for _, v: RBXScriptConnection in Connections do
	                v:Disconnect()
	            end
	            table.clear(Connections)
	            table.clear(Events)
	            if Folder then
	                Folder:Destroy()
	                Folder = nil
	            end
	            if Anchor then
	                Anchor:Destroy()
	                Anchor = nil
	            end
	            table.clear(Parts)
	        end
	    end,
	    Tooltip = "Tests every shot on a copy of your ball, draws the one that sinks it in the fewest strokes and lines your aim and power up on it. Shots are timed to trapdoors and spinning obstacles, and on holes that mix them it picks the shot that works whenever you take it."
	})
	
	Aim = GolfAssist:CreateToggle({
	    Name = "Aim",
	    Default = true,
	    Tooltip = "Turns your camera onto the best line while you aim and shoots down it exactly."
	})
	LegitAim = GolfAssist:CreateToggle({
	    Name = "Legit aim",
	    Tooltip = "Eases your camera onto the line instead of snapping to it."
	})
	AimSpeed = GolfAssist:CreateSlider({
	    Name = "Aim speed",
	    Min = 1,
	    Max = 20,
	    Default = 5,
	    Tooltip = "How quickly Legit aim settles onto the line."
	})
	Power = GolfAssist:CreateToggle({
	    Name = "Power",
	    Default = true,
	    Tooltip = "Holds your power bar on the best power while you aim."
	})
	LegitPower = GolfAssist:CreateToggle({
	    Name = "Legit power",
	    Tooltip = "Drags your power bar up to the best power instead of setting it straight away."
	})
	PowerSpeed = GolfAssist:CreateSlider({
	    Name = "Power speed",
	    Min = 10,
	    Max = 200,
	    Default = 60,
	    Suffix = "/s",
	    Tooltip = "How much power Legit power adds every second."
	})
	AutoShoot = GolfAssist:CreateToggle({
	    Name = "Auto shoot",
	    Tooltip = "Aims and takes the best shot for you as soon as it is found. In racing it takes the first shot that sinks it."
	})
	Legit = GolfAssist:CreateToggle({
	    Name = "Legit",
	    Tooltip = "Plans each hole to go in on the stroke set below instead of always going for a hole in one."
	})
	Strokes = GolfAssist:CreateSlider({
	    Name = "Strokes",
	    Min = 1,
	    Max = 5,
	    Default = 2,
	    Tooltip = "Which stroke Legit sinks the ball on. The shots before it leave the ball a sensible distance out."
	})
	Path = GolfAssist:CreateToggle({
	    Name = "Path",
	    Function = function(Callback: boolean)
	        for _, v: Part in Parts do
	            v.Transparency = Callback and Best and 0.35 or 1
	        end
	    end,
	    Default = true,
	    Tooltip = "Draws where the best shot goes."
	})
	Samples = GolfAssist:CreateSlider({
	    Name = "Samples",
	    Min = 70,
	    Max = 700,
	    Default = 700,
	    Tooltip = "How many shots are tested at once in the first pass. More finds tighter lines, but costs frames while it searches."
	})
	Color = GolfAssist:CreateColorSlider({
	    Name = "Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        for _, v: Part in Parts do
	            v.Color = Color3.fromHSV(Hue, Sat, Val)
	        end
	    end,
	    DefaultHue = 0.44
	})
end)