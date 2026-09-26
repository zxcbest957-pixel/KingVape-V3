local Run = function(Func: () -> ())
    Func()
end
local cloneref = cloneref or function(Reference: Instance)
    return Reference
end

local Players: Players = cloneref(game:GetService("Players"))
local RunService: RunService = cloneref(game:GetService("RunService"))
local CollectionService: CollectionService = cloneref(game:GetService("CollectionService"))
local ReplicatedStorage: ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))

local LocalPlayer: Player = Players.LocalPlayer
local vape = shared.vape

local TowerOfHell = {}

Run(function()
    TowerOfHell = {
        Controls = require(LocalPlayer.PlayerScripts.PlayerModule).controls
    }

    vape:Clean(function()
        table.clear(TowerOfHell)
    end)
end)

Run(function()
	local AutoPlay
	local Path
	local Color
	
	local Folder, Probe, Rig, Route, Step, Began, Launched, Airborne, Peak, Aim, Bent, Waited, Movement, Planning, Building, Built, Tower, Escape, Sunk, Hovered, Old
	local Slip: Vector3 = Vector3.zero
	local Nodes, Cells, Sections, Moving, Hazards, Platforms, Trusses, Blocked, Parts, Tracks, Demos, Strikes, Watched = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
	local Version, Changed, Sampled, Checked = 0, 0, 0, 0
	local Overlap: OverlapParams = OverlapParams.new()
	Overlap.RespectCanCollide = true
	Overlap.FilterType = Enum.RaycastFilterType.Include
	local KillOverlap: OverlapParams = OverlapParams.new()
	KillOverlap.FilterType = Enum.RaycastFilterType.Include
	local FinishOverlap: OverlapParams = OverlapParams.new()
	FinishOverlap.FilterType = Enum.RaycastFilterType.Include
	local Params: RaycastParams = RaycastParams.new()
	Params.RespectCanCollide = true
	Params.FilterType = Enum.RaycastFilterType.Include
	local KillParams: RaycastParams = RaycastParams.new()
	KillParams.FilterType = Enum.RaycastFilterType.Include
	local Include: RaycastParams = RaycastParams.new()
	Include.FilterType = Enum.RaycastFilterType.Include
	
	local function Push(Heap, Item)
	    table.insert(Heap, Item)
	    local Index: number = #Heap
	    while Index > 1 and Heap[Index // 2][2] > Item[2] do
	        Heap[Index] = Heap[Index // 2]
	        Index //= 2
	    end
	    Heap[Index] = Item
	end
	
	local function Pop(Heap)
	    local Top, Last = Heap[1], table.remove(Heap)
	    if Heap[1] then
	        local Index: number = 1
	        while Index * 2 <= #Heap do
	            local Child: number = Index * 2
	            if Child < #Heap and Heap[Child + 1][2] < Heap[Child][2] then
	                Child += 1
	            end
	            if Heap[Child][2] >= Last[2] then
	                break
	            end
	            Heap[Index] = Heap[Child]
	            Index = Child
	        end
	        Heap[Index] = Last
	    end
	    return Top
	end
	
	local function GetRig()
	    local Root: BasePart = LocalPlayer.Character.HumanoidRootPart
	    local Humanoid: Humanoid? = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	    local Low, High = Vector3.one * math.huge, Vector3.one * -math.huge
	    local CollideLow, CollideHigh, LegLow, LegHigh = Low, High, Low, High
	    for _, v: BasePart in LocalPlayer.Character:GetChildren() do
	        if v:IsA("BasePart") then
	            local LocalFrame: CFrame = Root.CFrame:ToObjectSpace(v.CFrame)
	            local Half: Vector3 = ((LocalFrame.RightVector * v.Size.X):Abs() + (LocalFrame.UpVector * v.Size.Y):Abs() + (LocalFrame.LookVector * v.Size.Z):Abs()) * 0.5
	            Low, High = Low:Min(LocalFrame.Position - Half), High:Max(LocalFrame.Position + Half)
	            if LocalFrame.Position.Y - Half.Y < -1.2 then
	                LegLow, LegHigh = LegLow:Min(LocalFrame.Position - Half), LegHigh:Max(LocalFrame.Position + Half)
	            end
	            if v.CanCollide then
	                CollideLow, CollideHigh = CollideLow:Min(LocalFrame.Position - Half), CollideHigh:Max(LocalFrame.Position + Half)
	            end
	        end
	    end
	
	    local Width: number = math.max(-CollideLow.X, CollideHigh.X, -CollideLow.Z, CollideHigh.Z) * 2 - 0.4
	    local Hover: number = Humanoid.RigType == Enum.HumanoidRigType.R15 and Humanoid.HipHeight + Root.Size.Y / 2 or Root.Size.Y / 2 + 2
	    return {
	        hover = Hover,
	        lift = Hover + CollideLow.Y - 0.25,
	        slope = math.max(math.cos(math.rad(Humanoid.MaxSlopeAngle)), 0.25),
	        speed = Humanoid.WalkSpeed,
	        gravity = workspace.Gravity,
	        jump = Rig and Rig.jump or math.max(Humanoid.JumpPower, math.sqrt(2 * workspace.Gravity * Humanoid.JumpHeight)),
	        size = Vector3.new(Width, CollideHigh.Y - CollideLow.Y, Width),
	        offset = Vector3.new(0, (CollideLow.Y + CollideHigh.Y) / 2, 0),
	        kills = {
	            {Vector3.new(math.max(-LegLow.X, LegHigh.X) * 2 + 0.4, -1 - Low.Y + 0.3, math.max(-LegLow.Z, LegHigh.Z) * 2 + 1), Vector3.new(0, (Low.Y - 1.3) / 2, 0)},
	            {Vector3.new(math.max(-Low.X, High.X) * 2 + 0.4, High.Y + 1.2, math.max(-Low.Z, High.Z) * 2 + 1.8), Vector3.new(0, (High.Y - 0.8) / 2, 0)}
	        }
	    }
	end
	
	local function GetFloor(Position: Vector3): RaycastResult?
	    return workspace:Blockcast(CFrame.new(Position), Vector3.new(Rig.size.X, 0.2, Rig.size.Z), Vector3.new(0, -Rig.hover - 1.5, 0), Params)
	end
	
	local function GetRunway(Point: Vector3, Direction: Vector3, Limit: number)
	    local Distance: number = 0
	    for i: number = 1, 6 do
	        local Ahead: Vector3 = Point + Direction * (i * 0.25)
	        Probe.Size, Probe.CFrame = Rig.kills[1][1], CFrame.lookAt(Vector3.zero, Direction) + Ahead + Vector3.new(0, Rig.hover, 0) + Rig.kills[1][2]
	        if i * 0.25 > Limit or workspace:GetPartsInPart(Probe, KillOverlap)[1] then
	            return Distance, false
	        elseif not workspace:Raycast(Ahead + Vector3.new(0, 0.5, 0), Vector3.new(0, -1.5, 0), Params) then
	            return workspace:Raycast(Ahead - Direction * 0.125 + Vector3.new(0, 0.5, 0), Vector3.new(0, -1.5, 0), Params) and Distance + 0.125 or Distance, true
	        end
	        Distance = i * 0.25
	    end
	    return Distance, false
	end
	
	local function GetNodes()
	    local Current, Snapshot, Clock, Group, Count, Recorded, Rungs = Version, {}, os.clock(), LocalPlayer.Character.HumanoidRootPart.CollisionGroup, 0, 0, {}
	    table.clear(Nodes)
	    table.clear(Cells)
	    table.clear(Sections)
	    table.clear(Moving)
	    table.clear(Hazards)
	    table.clear(Platforms)
	    table.clear(Trusses)
	    table.clear(Blocked)
	    for _, v: BasePart in workspace.tower:GetDescendants() do
	        if v:IsA("BasePart") then
	            Snapshot[v] = v.CFrame
	        end
	    end
	    task.wait(1)
	    for Part: BasePart, v: CFrame in Snapshot do
	        if (Part.Position - v.Position).Magnitude > 0.05 or Part.CFrame.LookVector:Dot(v.LookVector) < 0.9999 or not Part:IsGrounded() then
	            Moving[Part] = true
	        end
	    end
	
	    local Kills: {Instance} = CollectionService:GetTagged("LobbyPortal")
	    for _, v: Instance in ReplicatedStorage.GameValues.killbricksDisabled.Value and {} or CollectionService:GetTagged("KillBrick") do
	        table.insert(Kills, v)
	    end
	    Overlap.CollisionGroup = Group
	    Params.CollisionGroup = Group
	    Overlap.FilterDescendantsInstances = {workspace.tower}
	    Params.FilterDescendantsInstances = {workspace.tower}
	    KillOverlap.FilterDescendantsInstances = Kills
	    KillParams.FilterDescendantsInstances = Kills
	    table.clear(Watched)
	    for _, v: Instance in Kills do
	        if Moving[v] then
	            Hazards[v] = {part = v, linear = Vector3.zero, angular = Vector3.zero, center = v.Position}
	        else
	            Watched[v] = v.CFrame
	        end
	    end
	    FinishOverlap.FilterDescendantsInstances = {workspace.tower.finishes}
	    local Box, Extents = workspace.tower.finishes:GetBoundingBox()
	    local Recorder: RBXScriptConnection = RunService.Heartbeat:Connect(function()
	        if os.clock() - Recorded > 0.25 then
	            Recorded = os.clock()
	            for _, v: any in Platforms do
	                table.insert(v.track, v.part.CFrame)
	            end
	        end
	    end)
	
	    for _, Section: Instance in workspace.tower.sections:GetChildren() do
	        if Section:FindFirstChild("i") then
	            Sections[Section.i.Value] = Section
	            for _, v: BasePart in Section:GetDescendants() do
	                if v:IsA("BasePart") and v.CanCollide and not CollectionService:HasTag(v, "KillBrick") and v.Position.Y - (math.abs(v.CFrame.RightVector.Y) * v.Size.X + math.abs(v.CFrame.UpVector.Y) * v.Size.Y + math.abs(v.CFrame.LookVector.Y) * v.Size.Z) / 2 < Box.Y + Extents.Y / 2 + 2 then
	                    local Half: Vector3 = ((v.CFrame.RightVector * v.Size.X):Abs() + (v.CFrame.UpVector * v.Size.Y):Abs() + (v.CFrame.LookVector * v.Size.Z):Abs()) * 0.5
	                    local Footprint: number = math.abs(v.CFrame.UpVector.Y) >= math.max(math.abs(v.CFrame.RightVector.Y), math.abs(v.CFrame.LookVector.Y)) and math.min(v.Size.X, v.Size.Z) or math.abs(v.CFrame.RightVector.Y) >= math.abs(v.CFrame.LookVector.Y) and math.min(v.Size.Y, v.Size.Z) or math.min(v.Size.X, v.Size.Y)
	                    local Spacing: number = Footprint > 16 and 2 or 1
	                    local Columns, Rows = math.max(math.floor(Half.X * 2 / Spacing), 1) - 1, math.max(math.floor(Half.Z * 2 / Spacing), 1) - 1
	                    local Platform
	                    if Moving[v] then
	                        Count += 1
	                        Platform = {part = v, samples = {}, track = {}, swept = {}, linear = Vector3.zero, angular = Vector3.zero, center = v.Position}
	                        Platform.node = {position = v.Position, section = Section.i.Value, links = {}, border = true, index = -Count, island = -Count, platform = Platform}
	                    end
	                    Include.FilterDescendantsInstances = {v}
	                    for X: number = v.Position.X - Columns * Spacing / 2, v.Position.X + Columns * Spacing / 2 + 0.01, Spacing do
	                        for Z: number = v.Position.Z - Rows * Spacing / 2, v.Position.Z + Rows * Spacing / 2 + 0.01, Spacing do
	                            local Hit: RaycastResult? = workspace:Raycast(Vector3.new(X, v.Position.Y + Half.Y + 0.1, Z), Vector3.new(0, -Half.Y * 2 - 0.2, 0), Include)
	                            if Hit and Hit.Normal.Y > Rig.slope and Platform then
	                                table.insert(Platform.samples, v.CFrame:PointToObjectSpace(Hit.Position))
	                            elseif Hit and Hit.Normal.Y > Rig.slope then
	                                Probe.Size, Probe.CFrame = Vector3.new(1, 0.2, 1), CFrame.new(Hit.Position + Vector3.new(0, 0.2, 0))
	                                local Buried: {BasePart} = workspace:GetPartsInPart(Probe, Overlap)
	                                local Safe: boolean = not Buried[1] or Buried[1] == v and not Buried[2]
	                                Probe.Size, Probe.CFrame = Rig.size, CFrame.new(Hit.Position + Vector3.new(0, Rig.hover + (1 - Hit.Normal.Y) * 2, 0) + Rig.offset)
	                                Safe = Safe and not workspace:GetPartsInPart(Probe, Overlap)[1]
	                                for _, Kill: {Vector3} in Rig.kills do
	                                    if not Safe then
	                                        break
	                                    end
	                                    Probe.Size, Probe.CFrame = Vector3.new(Kill[1].Z, Kill[1].Y, Kill[1].Z), CFrame.new(Hit.Position + Vector3.new(0, Rig.hover, 0) + Kill[2])
	                                    Safe = not workspace:GetPartsInPart(Probe, KillOverlap)[1]
	                                end
	                                if Safe then
	                                    local Node = {
	                                        position = Hit.Position,
	                                        section = Section.i.Value,
	                                        spacing = Spacing,
	                                        links = {},
	                                        index = #Nodes + 1,
	                                        belt = CollectionService:HasTag(v, "Conveyor") and v.AssemblyLinearVelocity or nil,
	                                        finish = workspace:GetPartsInPart(Probe, FinishOverlap)[1] ~= nil
	                                    }
	                                    local Key: string = `{Hit.Position.X // 4},{Hit.Position.Y // 4},{Hit.Position.Z // 4}`
	                                    Cells[Key] = Cells[Key] or {}
	                                    table.insert(Cells[Key], Node)
	                                    table.insert(Nodes, Node)
	                                end
	                            end
	                            if os.clock() - Clock > 0.004 then
	                                task.wait()
	                                Clock = os.clock()
	                                if Current ~= Version then
	                                    Recorder:Disconnect()
	                                    return
	                                end
	                            end
	                        end
	                    end
	                    if Platform and Platform.samples[1] then
	                        Platforms[v] = Platform
	                    end
	                    if not Platform and (v:IsA("TrussPart") and math.abs((v.Size.Y >= math.max(v.Size.X, v.Size.Z) and v.CFrame.UpVector or v.Size.X >= v.Size.Z and v.CFrame.RightVector or v.CFrame.LookVector).Y) > 0.85 or Half.Y <= 0.8) then
	                        local Key: string = `{math.floor(v.Position.X + 0.5)},{math.floor(v.Position.Z + 0.5)}`
	                        Rungs[Key] = Rungs[Key] or {}
	                        table.insert(Rungs[Key], {v.Position, Half, v:IsA("TrussPart")})
	                    end
	                end
	            end
	        end
	    end
	
	    for _, Stack: {any} in Rungs do
	        table.sort(Stack, function(A, B)
	            return A[1].Y < B[1].Y
	        end)
	        local First: number = 1
	        for i: number, Rung: any in Stack do
	            local Gap: number? = Stack[i + 1] and Stack[i + 1][1].Y - Stack[i + 1][2].Y - Rung[1].Y - Rung[2].Y
	            if not Gap or Gap > 2.5 or Gap < 0.2 and not (Rung[3] and Stack[i + 1][3]) then
	                if i - First >= 2 or Rung[3] and Rung[1].Y + Rung[2].Y - Stack[First][1].Y + Stack[First][2].Y >= 4 then
	                    table.insert(Trusses, {position = Stack[First][1], half = Rung[2] * Vector3.new(1, 0, 1), bottom = Stack[First][1].Y - Stack[First][2].Y, top = Rung[1].Y + Rung[2].Y})
	                end
	                First = i + 1
	            end
	        end
	    end
	
	    for _, v: any in Nodes do
	        for CellX: number = v.position.X // 4 - 1, v.position.X // 4 + 1 do
	            for CellY: number = v.position.Y // 4 - 1, v.position.Y // 4 + 1 do
	                for CellZ: number = v.position.Z // 4 - 1, v.position.Z // 4 + 1 do
	                    for _, Other: any in Cells[`{CellX},{CellY},{CellZ}`] or {} do
	                        local Offset: Vector3 = Other.position - v.position
	                        local Flat: Vector3 = Offset * Vector3.new(1, 0, 1)
	                        if Other.index > v.index and math.abs(Offset.Y) <= math.max(1.2, Flat.Magnitude * math.sqrt(1 - Rig.slope * Rig.slope) / Rig.slope) and Flat.Magnitude > 0.1 and Flat.Magnitude <= math.max(v.spacing, Other.spacing) * 1.5 then
	                            local Hit: RaycastResult? = workspace:Raycast((v.position + Other.position) / 2 + Vector3.new(0, 1.5, 0), Vector3.new(0, -3, 0), Params)
	                            local Safe = Hit and Hit.Normal.Y > Rig.slope and (math.abs(Offset.Y) <= 1.2 or Hit.Normal.Y < 0.95)
	                            for _, Kill: {Vector3} in Rig.kills do
	                                if not Safe then
	                                    break
	                                end
	                                Probe.Size, Probe.CFrame = Kill[1], CFrame.lookAt(v.position, v.position + Flat) + Vector3.new(0, Rig.hover, 0) + Kill[2]
	                                Safe = not workspace:GetPartsInPart(Probe, KillOverlap)[1]
	                                Probe.CFrame += Offset
	                                Safe = Safe and not workspace:GetPartsInPart(Probe, KillOverlap)[1]
	                            end
	                            if Safe then
	                                table.insert(v.links, Other)
	                                table.insert(Other.links, v)
	                            end
	                        end
	                    end
	                end
	            end
	        end
	        if os.clock() - Clock > 0.004 then
	            task.wait()
	            Clock = os.clock()
	            if Current ~= Version then
	                Recorder:Disconnect()
	                return
	            end
	        end
	    end
	    Recorder:Disconnect()
	
	    local Island: number = 0
	    for _, v: any in Nodes do
	        local Directions: number = 0
	        for _, Link: any in v.links do
	            Directions = bit32.bor(Directions, bit32.lshift(1, math.floor(math.atan2(Link.position.Z - v.position.Z, Link.position.X - v.position.X) / math.pi * 4 + 8.5) % 8))
	        end
	        v.border = Directions ~= 255
	        if not v.island then
	            Island += 1
	            v.island = Island
	            local Queue, Head = {v}, 1
	            while Queue[Head] do
	                for _, Link: any in Queue[Head].links do
	                    if not Link.island then
	                        Link.island = Island
	                        table.insert(Queue, Link)
	                    end
	                end
	                Head += 1
	            end
	        end
	    end
	
	    for _, v: any in Platforms do
	        local Total: Vector3 = Vector3.zero
	        for _, Frame: CFrame in v.track do
	            for i: number, Sample: Vector3 in v.samples do
	                if i % math.ceil(#v.samples / 5) == 0 then
	                    table.insert(v.swept, Frame * Sample)
	                    Total += Frame * Sample
	                end
	            end
	        end
	        v.node.position = v.swept[1] and Total / #v.swept or v.part.Position
	    end
	
	    return Current == Version
	end
	
	local function GetJumps(Node)
	    local Candidates, Counts = {}, {}
	    Node.jumps = {}
	    for i: number, v: Vector3 in Node.platform and Node.platform.swept or {Node.position} do
	        if i % 3 == 1 or not Node.platform then
	            for CellX: number = v.X // 4 - 4, v.X // 4 + 4 do
	                for CellY: number = (v.Y - 12) // 4, (v.Y + 10) // 4 do
	                    for CellZ: number = v.Z // 4 - 4, v.Z // 4 + 4 do
	                        for _, Other: any in Cells[`{CellX},{CellY},{CellZ}`] or {} do
	                            if Other.island ~= Node.island and ((Other.position - v) * Vector3.new(1, 0, 1)).Magnitude <= 14 then
	                                table.insert(Candidates, {Other, ((Other.position - v) * Vector3.new(1, 0, 1)).Magnitude, v, Other.position})
	                            end
	                        end
	                    end
	                end
	            end
	            for _, Platform: any in Platforms do
	                if Platform.node ~= Node then
	                    for _, Swept: Vector3 in Platform.swept do
	                        if Swept.Y - v.Y > -12 and Swept.Y - v.Y < 10 and ((Swept - v) * Vector3.new(1, 0, 1)).Magnitude <= 14 then
	                            table.insert(Candidates, {Platform.node, ((Swept - v) * Vector3.new(1, 0, 1)).Magnitude, v, Swept})
	                        end
	                    end
	                end
	            end
	        end
	    end
	    table.sort(Candidates, function(A, B)
	        return A[2] < B[2]
	    end)
	
	    for _, v: any in Trusses do
	        local Reach: number = (((Node.position - v.position) * Vector3.new(1, 0, 1)):Abs() - v.half):Max(Vector3.zero).Magnitude
	        if not Node.platform and Reach <= 7.5 and Node.position.Y > v.bottom - 6 and Node.position.Y < v.top - 1 then
	            for CellX: number = (v.position.X - v.half.X - 4) // 4, (v.position.X + v.half.X + 4) // 4 do
	                for CellY: number = Node.position.Y // 4, (v.top + 2) // 4 do
	                    for CellZ: number = (v.position.Z - v.half.Z - 4) // 4, (v.position.Z + v.half.Z + 4) // 4 do
	                        for _, Other: any in Cells[`{CellX},{CellY},{CellZ}`] or {} do
	                            local Count = Counts[Other.island] or {0, 0, {}}
	                            Counts[Other.island] = Count
	                            if Count[1] < 2 and Other.island ~= Node.island and Other.position.Y > Node.position.Y + 1.5 and Other.position.Y < v.top + 2.5 and (((Other.position - v.position) * Vector3.new(1, 0, 1)):Abs() - v.half):Max(Vector3.zero).Magnitude <= 3.5 then
	                                Count[1] += 1
	                                table.insert(Node.jumps, {from = Node, node = Other, time = (Other.position.Y - Node.position.Y) / (Rig.speed * 0.7) + Reach / Rig.speed + 1, delay = 0, jump = 0, climb = v})
	                            end
	                        end
	                    end
	                end
	            end
	        end
	    end
	
	    for _, v: any in Candidates do
	        local Dynamic = Node.platform or v[1].platform
	        local Count = Counts[v[1].island] or {0, 0, {}}
	        Counts[v[1].island] = Count
	        local Fresh: boolean = true
	        for _, Used: Vector3 in Count[3] do
	            Fresh = Fresh and (Used - v[4]).Magnitude > 1.5
	        end
	        if Count[1] < 2 and Count[2] < (Dynamic and 12 or 8) and Fresh then
	            Count[2] += 1
	            table.insert(Count[3], v[4])
	            local Offset: Vector3 = v[4] - v[3]
	            local Direction: Vector3 = Offset * Vector3.new(1, 0, 1)
	            Direction = Direction.Magnitude > 0.01 and Direction.Unit or Vector3.zAxis
	            local Edge: number = Node.platform and 0 or GetRunway(v[3], Direction, v[2] - 0.5)
	            local Origin: Vector3 = v[3] + Direction * Edge + Vector3.new(0, Rig.hover, 0)
	            Offset -= Direction * Edge
	            local Land, Lip = 0, false
	            if not v[1].platform then
	                Land, Lip = GetRunway(v[4], -Direction, (Offset * Vector3.new(1, 0, 1)).Magnitude - 0.5)
	            end
	            Offset -= Direction * (Land + (Lip and 0.35 or 0))
	            local Flat: Vector3 = Offset * Vector3.new(1, 0, 1)
	            local Facing: CFrame = CFrame.lookAt(Vector3.zero, Direction)
	            local Move, Found, Safe = Flat.Magnitude / Rig.speed, nil, true
	            for _, Kill: {Vector3} in Rig.kills do
	                Probe.Size, Probe.CFrame = Kill[1], Facing + Origin + Kill[2]
	                Safe = Safe and (Node.platform or not workspace:GetPartsInPart(Probe, KillOverlap)[1])
	            end
	            for _, Jump: number in {Rig.jump, 0} do
	                if Safe and not Found and Jump * Jump - 2 * Rig.gravity * (Offset.Y - Rig.lift + 0.1) >= 0 and (Jump > 0 or Offset.Y < -1) then
	                    local Time: number = (Jump + math.sqrt(Jump * Jump - 2 * Rig.gravity * (Offset.Y - Rig.lift))) / Rig.gravity
	                    local Stop: number = math.min(Time, Jump * Jump - 2 * Rig.gravity * (Offset.Y + 0.3) >= 0 and (Jump + math.sqrt(Jump * Jump - 2 * Rig.gravity * (Offset.Y + 0.3))) / Rig.gravity or Time)
	                    if Dynamic and Move <= Time - 0.05 then
	                        Found = {from = Node, node = v[1], time = Time, delay = 0, jump = Jump, takeoff = Edge}
	                    elseif not Dynamic then
	                        local Bends, BendIndex = {Origin + Flat / 2}, 1
	                        while Bends[BendIndex] and not Found do
	                            local Bend: Vector3 = Bends[BendIndex]
	                            local First, Second = Bend - Origin, Origin + Flat - Bend
	                            local Length: number = First.Magnitude + Second.Magnitude
	                            if Length / Rig.speed <= Time - 0.02 then
	                                for _, StartDelay: number in Jump > 0 and {math.max(Time - Length / Rig.speed - 0.06, 0), 0} or {0} do
	                                    local Last, Clear = Origin, true
	                                    for i: number = 1, math.ceil(Stop / 0.04) do
	                                        local Elapsed: number = math.min(i * 0.04, Stop)
	                                        local Travelled: number = math.clamp((Elapsed - StartDelay) * Rig.speed, 0, Length)
	                                        local Segment: Vector3 = Travelled < First.Magnitude and First or Second
	                                        local Turn: CFrame = CFrame.lookAt(Vector3.zero, Segment.Magnitude > 0.01 and Segment or Direction)
	                                        local Point: Vector3 = (Travelled < First.Magnitude and Origin + (First.Magnitude > 0.01 and First.Unit or Vector3.zero) * Travelled or Bend + (Second.Magnitude > 0.01 and Second.Unit or Vector3.zero) * (Travelled - First.Magnitude)) + Vector3.new(0, Jump * Elapsed - Rig.gravity * Elapsed * Elapsed / 2, 0)
	                                        local Hit = (Point - Last).Magnitude > 0.001 and workspace:Blockcast(CFrame.new(Last + Rig.offset), Rig.size, Point - Last, Params)
	                                        if Hit and BendIndex == 1 and not Bends[2] and math.max(Hit.Instance.Size.X, Hit.Instance.Size.Z) <= 24 then
	                                            for _, Sign: Vector3 in {Vector3.new(1, 0, 1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(-1, 0, -1)} do
	                                                local Corner: Vector3 = Hit.Instance.CFrame * (Hit.Instance.Size / 2 * Sign + Sign * 1.3)
	                                                table.insert(Bends, Vector3.new(Corner.X, Origin.Y, Corner.Z))
	                                            end
	                                            for _, EndPoint: Vector3 in {Origin, Origin + Flat} do
	                                                local Pad: Vector3 = Hit.Instance.Size / 2 + Vector3.new(1.3, 0, 1.3)
	                                                local Relative: Vector3 = Hit.Instance.CFrame:PointToObjectSpace(EndPoint)
	                                                Relative = Vector3.new(math.clamp(Relative.X, -Pad.X, Pad.X), 0, math.clamp(Relative.Z, -Pad.Z, Pad.Z))
	                                                local Outline: Vector3 = Hit.Instance.CFrame * (Pad.X - math.abs(Relative.X) < Pad.Z - math.abs(Relative.Z) and Vector3.new(Relative.X >= 0 and Pad.X or -Pad.X, 0, Relative.Z) or Vector3.new(Relative.X, 0, Relative.Z >= 0 and Pad.Z or -Pad.Z))
	                                                table.insert(Bends, Vector3.new(Outline.X, Origin.Y, Outline.Z))
	                                            end
	                                        end
	                                        if Hit or (Point - Last).Magnitude > 0.001 and (workspace:Blockcast(Turn + Last + Rig.kills[1][2], Rig.kills[1][1], Point - Last, KillParams) or workspace:Blockcast(Turn + Last + Rig.kills[2][2], Rig.kills[2][1], Point - Last, KillParams)) then
	                                            Clear = false
	                                            break
	                                        end
	                                        Last = Point
	                                    end
	                                    if Clear then
	                                        Found = {from = Node, node = v[1], time = Time, delay = StartDelay, jump = Jump, takeoff = Edge, bend = BendIndex > 1 and Bend - Vector3.new(0, Rig.hover, 0) or nil}
	                                        break
	                                    end
	                                end
	                            end
	                            BendIndex += 1
	                        end
	                    end
	                end
	            end
	            if Found then
	                Count[1] += 1
	                table.insert(Node.jumps, Found)
	            end
	        end
	    end
	
	    return Node.jumps
	end
	
	local function GetPath(Start, Goals)
	    local Current, Target = Version, Sections[Start.section + 1] and Sections[Start.section + 1]:FindFirstChild("start")
	    Target = Target and Target.Position or workspace.tower.finishes:GetPivot().Position
	    local Heap, Costs, Parents, Closed, Clock, Count = {{Start, 0}}, {[Start] = 0}, {}, {}, os.clock(), 0
	    while Heap[1] and Current == Version and Count < 60000 do
	        local Node = Pop(Heap)[1]
	        if not Closed[Node] then
	            Closed[Node] = true
	            if Node.section > Start.section or Node.finish or Goals and Goals[Node] then
	                local List = {}
	                while Parents[Node] do
	                    table.insert(List, 1, Parents[Node])
	                    Node = Parents[Node].from
	                end
	                return List
	            end
	
	            for _, v: any in Node.links do
	                local Flat: Vector3 = (v.position - Node.position) * Vector3.new(1, 0, 1)
	                local Speed: number = Rig.speed + (Node.belt and Node.belt:Dot(Flat.Unit) or 0)
	                local Cost: number = Costs[Node] + Flat.Magnitude / math.max(Speed, 0.1)
	                if Speed > 3 and Cost < (Costs[v] or math.huge) and (Blocked[`{Node.index},{v.index}`] or 0) < 2 then
	                    Costs[v], Parents[v] = Cost, {from = Node, node = v, time = Flat.Magnitude / Speed}
	                    Push(Heap, {v, Cost + (Target - v.position).Magnitude / Rig.speed * 2})
	                end
	            end
	            if Node.border then
	                for _, v: any in Node.jumps or GetJumps(Node) do
	                    local Cost: number = Costs[Node] + v.time + ((Node.platform or v.node.platform) and 1.5 or 0.3)
	                    if Cost < (Costs[v.node] or math.huge) and (Blocked[`{Node.index},{v.node.index}`] or 0) < 2 then
	                        Costs[v.node], Parents[v.node] = Cost, v
	                        Push(Heap, {v.node, Cost + (Target - v.node.position).Magnitude / Rig.speed * 2})
	                    end
	                end
	            end
	
	            Count += 1
	            if os.clock() - Clock > 0.004 then
	                task.wait()
	                Clock = os.clock()
	            end
	        end
	    end
	
	    return nil
	end
	
	local function GetDemo(Samples, Feet: Vector3)
	    local List, Index, Distance = {}, nil, 24
	    local function Anchor(Sample, Position: Vector3, Name: string, Snap: boolean?)
	        for Part: BasePart, v: CFrame in Sample.frames or {} do
	            if Platforms[Part] and (v:PointToObjectSpace(Position):Abs() - Part.Size / 2):Max(Vector3.zero).Magnitude < 1.5 then
	                return {position = Position, index = Name, part = Part, frame = v, offset = v:PointToObjectSpace(Position)}
	            end
	        end
	        if Snap and not workspace:Raycast(Position + Vector3.new(0, 1, 0), Vector3.new(0, -3.5, 0), Params) then
	            local Best, BestDistance = nil, 2.5
	            for CellX: number = Position.X // 4 - 1, Position.X // 4 + 1 do
	                for CellY: number = Position.Y // 4 - 1, Position.Y // 4 do
	                    for CellZ: number = Position.Z // 4 - 1, Position.Z // 4 + 1 do
	                        for _, v: any in Cells[`{CellX},{CellY},{CellZ}`] or {} do
	                            local Flat: number = ((v.position - Position) * Vector3.new(1, 0, 1)).Magnitude
	                            if Flat < BestDistance and v.position.Y > Position.Y - 3.5 and v.position.Y < Position.Y + 1 then
	                                Best, BestDistance = v, Flat
	                            end
	                        end
	                    end
	                end
	            end
	            Position = Best and Best.position or Position
	        end
	        return {position = Position, index = Name}
	    end
	    for SampleIndex: number, v: any in Samples do
	        local Offset: Vector3 = v.position - Vector3.new(0, Rig.hover, 0) - Feet
	        if v.grounded and math.abs(Offset.Y) < 3 and (Offset * Vector3.new(1, 0, 1)).Magnitude < 4 then
	            Index = SampleIndex
	        end
	    end
	    if not Index then
	        for SampleIndex: number, v: any in Samples do
	            local Offset: Vector3 = v.position - Vector3.new(0, Rig.hover, 0) - Feet
	            if v.grounded and math.abs(Offset.Y) < 3 and (Offset * Vector3.new(1, 0, 1)).Magnitude < Distance and workspace:Blockcast(CFrame.new(Feet + Offset * 0.5 + Vector3.new(0, 1, 0)), Vector3.new(Rig.size.X, 0.2, Rig.size.Z), Vector3.new(0, -4, 0), Params) then
	                Index, Distance = SampleIndex, (Offset * Vector3.new(1, 0, 1)).Magnitude
	            end
	        end
	    end
	    if not Index then
	        return nil
	    end
	
	    local Last: Vector3 = Feet
	    while Samples[Index] do
	        local Finish: number = Index
	        while Samples[Finish] and not Samples[Finish].grounded do
	            Finish += 1
	        end
	        if not Samples[Finish] then
	            break
	        end
	
	        local Rise: number = math.max(Index - 1, 1)
	        for SampleIndex: number = Rise, Finish - 1 do
	            if Samples[SampleIndex + 1].position.Y - Samples[SampleIndex].position.Y > 0.5 then
	                Rise = SampleIndex
	                break
	            end
	        end
	        while Rise > Index and not workspace:Blockcast(CFrame.new(Samples[Rise].position - Vector3.new(0, Rig.hover - 1, 0)), Vector3.new(Rig.size.X, 0.2, Rig.size.Z), Vector3.new(0, -3.5, 0), Params) do
	            Rise -= 1
	        end
	        local Takeoff, Landing = Samples[Rise].position - Vector3.new(0, Rig.hover, 0), Samples[Finish].position - Vector3.new(0, Rig.hover, 0)
	        for _, v: any in Trusses do
	            if v.bottom < Landing.Y + 1 and v.top > Landing.Y and (((Landing - v.position) * Vector3.new(1, 0, 1)):Abs() - v.half):Max(Vector3.zero).Magnitude < 2.5 and not workspace:Raycast(Landing + Vector3.new(0, 0.5, 0), Vector3.new(0, -1.5, 0), Params) then
	                Landing = Vector3.new(v.position.X, Landing.Y, v.position.Z) + ((Landing - v.position) * Vector3.new(1, 0, 1)):Max(-v.half):Min(v.half)
	            end
	        end
	        local Line, Duration = (Landing - Takeoff) * Vector3.new(1, 0, 1), Samples[Finish].time - Samples[Rise].time
	        local Apex, Spread, Climb = Takeoff.Y, 0, nil
	        for SampleIndex: number = Index, Finish do
	            local Offset: Vector3 = (Samples[SampleIndex].position - Vector3.new(0, Rig.hover, 0) - Takeoff) * Vector3.new(1, 0, 1)
	            Apex, Spread = math.max(Apex, Samples[SampleIndex].position.Y - Rig.hover), math.max(Spread, Offset.Magnitude)
	        end
	        for _, v: any in Trusses do
	            if Finish > Index and Landing.Y - Takeoff.Y > 4 and v.bottom < Landing.Y and v.top > Takeoff.Y and (Spread < 3 and (((Samples[(Index + Finish) // 2].position - v.position) * Vector3.new(1, 0, 1)):Abs() - v.half):Max(Vector3.zero).Magnitude < 3 or Landing.Y - Takeoff.Y > Rig.jump * Rig.jump / Rig.gravity / 2 + Rig.lift and (((Landing - v.position) * Vector3.new(1, 0, 1)):Abs() - v.half):Max(Vector3.zero).Magnitude < 3) then
	                Climb = v
	            end
	        end
	
	        if Climb or Finish > Index and Duration <= 1.6 and Line.Magnitude <= 14 and Line.Magnitude <= Rig.speed * Duration + 2 then
	            for SampleIndex: number = Index, Rise do
	                local Position: Vector3 = Samples[SampleIndex].position - Vector3.new(0, Rig.hover, 0)
	                if (Position - Last).Magnitude >= 2 then
	                    local Offset: Vector3 = (Position - Last) * Vector3.new(1, 0, 1)
	                    table.insert(List, Offset.Magnitude > 0.1 and workspace:Blockcast(CFrame.lookAt(Last, Last + Offset) + Vector3.new(0, Rig.hover, 0) + Rig.kills[1][2], Rig.kills[1][1], Position - Last, KillParams) and {from = Anchor(Samples[SampleIndex], Last, `hop{SampleIndex}`, true), node = Anchor(Samples[SampleIndex], Position, `demo{SampleIndex}`, true), time = 0.6, delay = 0, jump = Rig.jump, takeoff = 0} or {node = Anchor(Samples[SampleIndex], Position, `demo{SampleIndex}`, true), time = (Position - Last).Magnitude / Rig.speed})
	                    Last = Position
	                end
	            end
	            local Nearby, Phase = {}, {}
	            for Part: BasePart, v: CFrame in Samples[Rise].frames or {} do
	                local Along: number = math.clamp((v.Position - Takeoff):Dot(Landing - Takeoff) / math.max((Landing - Takeoff).Magnitude ^ 2, 0.001), 0, 1)
	                local Gap: number = (v.Position - Takeoff:Lerp(Landing, Along)).Magnitude - Part.Size.Magnitude / 2
	                if Gap < 6 then
	                    table.insert(Nearby, {Part, v, Gap})
	                end
	            end
	            table.sort(Nearby, function(A, C)
	                return A[3] < C[3]
	            end)
	            for Rank: number, v: any in Nearby do
	                if Rank > 2 then
	                    break
	                end
	                Phase[v[1]] = v[2]
	            end
	            local Jump, JumpDelay, AirPath = not Climb and Apex > Takeoff.Y + 1 and Rig.jump or 0, 0, {}
	            if Jump > 0 and Samples[Rise + 1] then
	                local Airtime: number = (Jump - math.sqrt(math.max(Jump * Jump - 2 * Rig.gravity * math.max(Samples[Rise + 1].position.Y - Samples[Rise].position.Y, 0), 0))) / Rig.gravity
	                local Gap: number = math.max(Samples[Rise + 1].time - Samples[Rise].time, 0.001)
	                local LaunchTime: number = Samples[Rise + 1].time - math.min(Airtime, Gap)
	                Takeoff = Vector3.new(0, Takeoff.Y, 0) + Samples[Rise].position:Lerp(Samples[Rise + 1].position, 1 - math.min(Airtime, Gap) / Gap) * Vector3.new(1, 0, 1)
	                JumpDelay = ((Samples[Rise + 1].position - Samples[Rise].position) * Vector3.new(1, 0, 1)).Magnitude / Gap < 6 and 0.06 or 0
	                table.insert(AirPath, {0, Takeoff * Vector3.new(1, 0, 1)})
	                for SampleIndex: number = Rise + 1, Finish do
	                    table.insert(AirPath, {Samples[SampleIndex].time - LaunchTime, Samples[SampleIndex].position * Vector3.new(1, 0, 1)})
	                end
	            end
	            local From, Node, Edge = Anchor(Samples[Rise], Takeoff, `demo{Rise}`, true), Anchor(Samples[Finish], Landing, `demo{Finish}`), 0
	            local Direction: Vector3 = (Landing - From.position) * Vector3.new(1, 0, 1)
	            for Nudge: number = 1, Jump > 0 and not From.part and Direction.Magnitude > 2 and 6 or 0 do
	                local Point: Vector3 = From.position + Direction.Unit * (Nudge * 0.25)
	                Probe.Size, Probe.CFrame = Rig.kills[1][1], CFrame.lookAt(Vector3.zero, Direction) + Point + Vector3.new(0, Rig.hover, 0) + Rig.kills[1][2]
	                if not workspace:Raycast(Point + Vector3.new(0, 0.5, 0), Vector3.new(0, -1.5, 0), Params) or workspace:GetPartsInPart(Probe, KillOverlap)[1] then
	                    break
	                end
	                Edge = Nudge * 0.25
	            end
	            table.insert(List, {from = From, node = Node, time = Duration, delay = JumpDelay, jump = Jump, takeoff = Edge, path = AirPath[2] and not From.part and not Node.part and AirPath or nil, climb = Climb, phase = Nearby[1] and Phase or nil})
	            Last = Landing
	        else
	            for SampleIndex: number = Index, Finish do
	                local Position: Vector3 = Samples[SampleIndex].position - Vector3.new(0, Rig.hover, 0)
	                if (Position - Last).Magnitude >= 2 then
	                    local Offset: Vector3 = (Position - Last) * Vector3.new(1, 0, 1)
	                    table.insert(List, Offset.Magnitude > 0.1 and workspace:Blockcast(CFrame.lookAt(Last, Last + Offset) + Vector3.new(0, Rig.hover, 0) + Rig.kills[1][2], Rig.kills[1][1], Position - Last, KillParams) and {from = Anchor(Samples[SampleIndex], Last, `hop{SampleIndex}`, true), node = Anchor(Samples[SampleIndex], Position, `demo{SampleIndex}`, true), time = 0.6, delay = 0, jump = Rig.jump, takeoff = 0} or {node = Anchor(Samples[SampleIndex], Position, `demo{SampleIndex}`, true), time = (Position - Last).Magnitude / Rig.speed})
	                    Last = Position
	                end
	            end
	        end
	        Index = Finish + 1
	    end
	
	    return List[1] and List or nil
	end
	
	local function GetDanger(From: Vector3, To: Vector3, Duration: number, Jump: number?)
	    for Part: BasePart in Hazards do
	        if Part.Parent and ((Part.Position - From) * Vector3.new(1, 0, 1)).Magnitude < (To - From).Magnitude + Part.Size.Magnitude / 2 + 12 then
	            local Center, Angular = Hazards[Part].center, Hazards[Part].angular
	            for Slice: number = 0, 8 do
	                local Elapsed: number = Duration * Slice / 8
	                local Frame: CFrame = CFrame.new(Center + Hazards[Part].linear * Elapsed) * CFrame.fromAxisAngle(Angular.Magnitude > 0.0001 and Angular.Unit or Vector3.yAxis, Angular.Magnitude * Elapsed) * (Part.CFrame - Center)
	                local Point: Vector3 = From:Lerp(To, Slice / 8)
	                if Jump then
	                    local Height: number = From.Y + Jump * Elapsed - Rig.gravity * Elapsed * Elapsed / 2
	                    Point = Vector3.new(Point.X, Elapsed > Jump / Rig.gravity and math.max(Height, To.Y) or Height, Point.Z)
	                end
	                for _, v: number in {1.5, 0, -1.5, -2.8} do
	                    if (Frame:PointToObjectSpace(Point + Vector3.new(0, v, 0)):Abs() - Part.Size / 2):Max(Vector3.zero).Magnitude < 1.2 then
	                        return true, v < 0
	                    end
	                end
	            end
	        end
	    end
	
	    return false, false
	end
	
	AutoPlay = vape.Categories.Utility:CreateModule({
	    Name = "AutoPlay",
	    Function = function(Callback: boolean)
	        if Callback then
	            Folder = Instance.new("Folder")
	            Folder.Name = "catvapetower"
	            Folder.Parent = workspace
	            Probe = Instance.new("Part")
	            Probe.Anchored = true
	            for i: number = 1, 80 do
	                local Part: Part = Instance.new("Part")
	                Part.Anchored = true
	                Part.CanCollide = false
	                Part.CanQuery = false
	                Part.CanTouch = false
	                Part.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	                Part.Material = Enum.Material.Neon
	                Part.Shape = Enum.PartType.Ball
	                Part.Size = Vector3.new(0.5, 0.5, 0.5)
	                Part.Transparency = 1
	                Part.Parent = Folder
	                Parts[i] = Part
	            end
	
	            Old = TowerOfHell.Controls.moveFunction
	            TowerOfHell.Controls.moveFunction = function(self, Vector: Vector3, Face: boolean)
	                return Old(self, Movement or Vector3.zero, false)
	            end
	
	            AutoPlay:Clean(LocalPlayer.CharacterAdded:Connect(function()
	                Route, Launched = nil, nil
	            end))
	            AutoPlay:Clean(RunService.Heartbeat:Connect(function()
	                if not Rig or os.clock() - Sampled < 0.066 then
	                    return
	                end
	                if os.clock() - Checked > 0.5 then
	                    Checked = os.clock()
	                    for Part: BasePart, v: CFrame in Watched do
	                        if (Part.Position - v.Position).Magnitude > 0.05 or Part.CFrame.LookVector:Dot(v.LookVector) < 0.9999 then
	                            Hazards[Part], Watched[Part] = {part = Part, linear = Vector3.zero, angular = Vector3.zero, center = Part.Position}, nil
	                        end
	                    end
	                end
	                Sampled = os.clock()
	                local Frames: {[BasePart]: CFrame} = {}
	                for Part: BasePart in Hazards do
	                    Frames[Part] = Part.CFrame
	                end
	                for Part: BasePart in Platforms do
	                    Frames[Part] = Part.CFrame
	                end
	                for _, v: Player in Players:GetPlayers() do
	                    local Root = v ~= LocalPlayer and v.Character and v.Character:FindFirstChild("HumanoidRootPart")
	                    local Section = Root and v.Character:FindFirstChild("currentSection")
	                    if Section then
	                        local Track = Tracks[v] or {}
	                        local Last, Entrance = Track[#Track], Track[1] and Sections[Track[1].section] and Sections[Track[1].section]:FindFirstChild("start")
	                        Tracks[v] = Track
	                        if Last and Entrance and Section.Value == Last.section + 1 and (Root.Position - Last.position).Magnitude < 25 and #Track > (Last.time - Track[1].time) * 8 and Track[1].position.Y - Rig.hover > Entrance.Position.Y - 2 then
	                            local Valid, Rising = Last.time - Track[1].time > 1.5, 0
	                            for i: number = 2, #Track do
	                                Rising = Track[i].velocity > 30 and Rising + 1 or 0
	                                if Rising >= 3 or ((Track[i].position - Track[i - 1].position) * Vector3.new(1, 0, 1)).Magnitude / math.max(Track[i].time - Track[i - 1].time, 0.001) > 45 then
	                                    Valid = false
	                                end
	                            end
	                            if Valid then
	                                local List = Demos[Last.section] or {}
	                                Demos[Last.section] = List
	                                table.insert(List, {samples = table.clone(Track), duration = Last.time - Track[1].time})
	                                table.sort(List, function(A, C)
	                                    return A.duration < C.duration
	                                end)
	                                if #List > 6 then
	                                    table.remove(List)
	                                end
	                            end
	                        end
	                        if Last and ((Root.Position - Last.position).Magnitude > 25 or Section.Value ~= Last.section) then
	                            table.clear(Track)
	                        end
	                        local Hit, Previous, Velocity = workspace:Blockcast(Root.CFrame, Vector3.new(Rig.size.X, 0.2, Rig.size.Z), Vector3.new(0, -Rig.hover - 0.1, 0), Params), Track[#Track], Root.AssemblyLinearVelocity.Y
	                        local Grounded: boolean = Hit ~= nil and Hit.Normal.Y > 0.5 or Previous ~= nil and math.abs(Velocity) < 0.5 and math.abs(Previous.velocity) < 0.5
	                        if Previous and not Previous.grounded and not Grounded and Velocity - Previous.velocity > 8 then
	                            if Previous.position.Y < Root.Position.Y then
	                                Previous.grounded = true
	                            else
	                                Grounded = true
	                            end
	                        end
	                        table.insert(Track, {time = os.clock(), position = Root.Position, velocity = Velocity, grounded = Grounded, section = Section.Value, frames = Frames})
	                        if #Track > 3000 then
	                            table.remove(Track, 1)
	                        end
	                    end
	                end
	            end))
	
	            AutoPlay:Clean(RunService.PreSimulation:Connect(function(Delta: number)
	                local Humanoid: Humanoid? = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	                local Root = Humanoid and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	                if not Root or Humanoid.Health <= 0 then
	                    Route, Launched, Movement = nil, nil, nil
	                    return
	                end
	
	                local Grounded: boolean = Humanoid.FloorMaterial ~= Enum.Material.Air
	                Hovered = not Grounded and math.abs(Root.AssemblyLinearVelocity.Y) < 1 and (Hovered or os.clock()) or nil
	                local Settled = Grounded or Hovered and os.clock() - Hovered > 0.5
	                if Built and workspace:FindFirstChild("tower") ~= Tower then
	                    Version, Changed, Built, Route = Version + 1, os.clock(), nil, nil
	                end
	                if not Built then
	                    Movement = Vector3.zero
	                    if not Building and Settled and os.clock() - Changed > 2 and workspace:FindFirstChild("tower") and workspace.tower:FindFirstChild("sections") and workspace.tower:FindFirstChild("finishes") then
	                        Building = true
	                        task.spawn(function()
	                            if Tower ~= workspace.tower then
	                                Tower = workspace.tower
	                                AutoPlay:Clean(Tower.sections.ChildAdded:Connect(function()
	                                    Version, Changed, Built, Route = Version + 1, os.clock(), nil, nil
	                                end))
	                                AutoPlay:Clean(Tower.sections.ChildRemoved:Connect(function()
	                                    Version, Changed, Built, Route = Version + 1, os.clock(), nil, nil
	                                end))
	                                table.clear(Tracks)
	                                table.clear(Demos)
	                                table.clear(Strikes)
	                            end
	                            Rig = GetRig()
	                            Built = GetNodes()
	                            Building = nil
	                        end)
	                    end
	                    return
	                end
	
	                for _, Registry: any in {Platforms, Hazards} do
	                    for _, v: any in Registry do
	                        if not v.stamp or os.clock() - v.stamp >= 0.1 then
	                            local Previous: CFrame = v.frame or v.part.CFrame
	                            local Axis, Angle = (v.part.CFrame.Rotation * Previous.Rotation:Inverse()):ToAxisAngle()
	                            local Elapsed: number = v.stamp and os.clock() - v.stamp or 1
	                            v.linear = v.linear:Lerp((v.part.Position - Previous.Position) / Elapsed, 0.6)
	                            v.angular = v.angular:Lerp(Axis * Angle / Elapsed, 0.6)
	                            v.frame, v.stamp = v.part.CFrame, os.clock()
	                        end
	                        v.center = v.part.Position
	                    end
	                end
	
	                local Feet: Vector3 = Root.Position - Vector3.new(0, Rig.hover, 0)
	                local Floor = Grounded and GetFloor(Root.Position)
	                Slip = Floor and Floor.Instance.Anchored and Floor.Instance.AssemblyLinearVelocity.Magnitude > 1 and Slip:Lerp((Root.AssemblyLinearVelocity - Humanoid.MoveDirection * Rig.speed) * Vector3.new(1, 0, 1), 0.1) or Vector3.zero
	                local Drift: Vector3 = Slip.Magnitude > 3 and Slip or Vector3.zero
	                local Entrance = Sections[2] and Sections[2]:FindFirstChild("start")
	                if Entrance and LocalPlayer.Character:FindFirstChild("currentSection") and LocalPlayer.Character.currentSection.Value == 1 and Feet.Y < Entrance.Position.Y - 18 and not (Route and os.clock() - Began < 3) then
	                    Sunk = Sunk or os.clock()
	                    if os.clock() - Sunk > 4 then
	                        Humanoid.Health = 0
	                    end
	                else
	                    Sunk = nil
	                end
	                local Threat, Low = GetDanger(Root.Position, Root.Position, 0.35)
	                if Grounded and not Launched and Threat and Low then
	                    Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	                end
	                local Entry = Route and Route[Step]
	                if Entry then
	                    for _, v: any in {Entry.from or Entry.node, Entry.node} do
	                        if v.part then
	                            v.position = v.part.CFrame * v.offset
	                        end
	                    end
	                end
	                if not Entry then
	                    local Lead = Escape and (Escape - Feet) * Vector3.new(1, 0, 1)
	                    Movement = Lead and Lead.Magnitude > 0.5 and Lead.Unit or Humanoid:GetState() == Enum.HumanoidStateType.Climbing and Root.CFrame.LookVector * Vector3.new(1, 0, 1) or Vector3.zero
	                    if Escape and Grounded and Escape.Y > Feet.Y + 1 then
	                        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	                    end
	                    for _, v: Part in Parts do
	                        v.Transparency = 1
	                    end
	                    if not Planning and Settled then
	                        Planning = true
	                        task.spawn(function()
	                            local Hit: RaycastResult? = GetFloor(Root.Position)
	                            local Start, Distance, Nearest = Hit and Platforms[Hit.Instance] and Platforms[Hit.Instance].node, 3, nil
	                            for CellX: number = Feet.X // 4 - 2, Feet.X // 4 + 2 do
	                                for CellY: number = Feet.Y // 4 - 2, Feet.Y // 4 + 2 do
	                                    for CellZ: number = Feet.Z // 4 - 2, Feet.Z // 4 + 2 do
	                                        for _, v: any in Cells[`{CellX},{CellY},{CellZ}`] or {} do
	                                            local Flat: number = ((v.position - Feet) * Vector3.new(1, 0, 1)).Magnitude
	                                            if not (Start and Start.platform) and Flat < Distance and math.abs(v.position.Y - Feet.Y) < 2 then
	                                                Start, Distance = v, Flat
	                                            end
	                                            if (Grounded or v.position.Y > Feet.Y - 3) and (not Nearest or (v.position - Feet).Magnitude < (Nearest.position - Feet).Magnitude) then
	                                                Nearest = v
	                                            end
	                                        end
	                                    end
	                                end
	                            end
	                            if not Start and not Nearest then
	                                for _, v: any in Nodes do
	                                    if (v.position - Feet).Magnitude < 60 and (Grounded or v.position.Y > Feet.Y - 3) and (not Nearest or (v.position - Feet).Magnitude < (Nearest.position - Feet).Magnitude) then
	                                        Nearest = v
	                                    end
	                                end
	                            end
	
	                            local Section = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("currentSection")
	                            local Candidates = Section and Demos[math.max(Section.Value, Start and Start.section or 0)]
	                            local List = (not Candidates or (Strikes[Section.Value] or 0) < 3) and Start and GetPath(Start)
	                            if List then
	                                table.insert(List, 1, {node = Start})
	                            else
	                                for Attempt: number = 1, Candidates and #Candidates or 0 do
	                                    List = List or GetDemo(Candidates[((Strikes[Section.Value] or 0) + Attempt - 1) % #Candidates + 1].samples, Feet)
	                                end
	                                if not List and Start and Candidates then
	                                    local Goals = {}
	                                    for _, v: any in Candidates do
	                                        for SampleIndex: number = 1, #v.samples, 3 do
	                                            local Position: Vector3 = v.samples[SampleIndex].position - Vector3.new(0, Rig.hover, 0)
	                                            for _, Other: any in v.samples[SampleIndex].grounded and Cells[`{Position.X // 4},{Position.Y // 4},{Position.Z // 4}`] or {} do
	                                                if ((Other.position - Position) * Vector3.new(1, 0, 1)).Magnitude < 1.5 and math.abs(Other.position.Y - Position.Y) < 1.5 then
	                                                    Goals[Other] = v
	                                                end
	                                            end
	                                        end
	                                    end
	                                    local GoalPath = next(Goals) and GetPath(Start, Goals)
	                                    local Goal = GoalPath and (GoalPath[1] and GoalPath[#GoalPath].node or Start)
	                                    local Demo = Goal and Goals[Goal] and GetDemo(Goals[Goal].samples, Goal.position)
	                                    if GoalPath and (Demo or not Goals[Goal]) then
	                                        List = GoalPath
	                                        table.insert(List, 1, {node = Start})
	                                        for _, v: any in Demo or {} do
	                                            table.insert(List, v)
	                                        end
	                                    end
	                                end
	                            end
	                            Escape = not List and not Start and Nearest and Nearest.position or nil
	                            if List and Built then
	                                Route, Step, Began, Launched = List, Start and Start.platform and List[1].node == Start and 2 or 1, os.clock(), nil
	                                for i: number, v: Part in Parts do
	                                    v.Position = List[math.ceil(i * #List / #Parts)].node.position + Vector3.new(0, 0.25, 0)
	                                    v.Transparency = Path.Enabled and 0.3 or 1
	                                end
	                            else
	                                task.wait(1)
	                            end
	                            Planning = nil
	                        end)
	                    end
	                    return
	                end
	
	                local Target, Source = Entry.node.platform, Entry.from and Entry.from.platform
	                local Flat: Vector3 = (Entry.node.position - Feet) * Vector3.new(1, 0, 1)
	                if os.clock() - Began > (Entry.time or 0) + ((Target or Source) and 12 or 2.5) or Feet.Y < math.min(Entry.node.position.Y, Entry.from and Entry.from.position.Y or Feet.Y) - 6 then
	                    if Entry.from then
	                        Blocked[`{Entry.from.index},{Entry.node.index}`] = (Blocked[`{Entry.from.index},{Entry.node.index}`] or 0) + 2
	                    end
	                    if LocalPlayer.Character:FindFirstChild("currentSection") then
	                        Strikes[LocalPlayer.Character.currentSection.Value] = (Strikes[LocalPlayer.Character.currentSection.Value] or 0) + 1
	                    end
	                    Route, Launched, Waited = nil, nil, nil
	                    return
	                end
	
	                if not Entry.jump then
	                    local Danger = Entry.node.part and not (Floor and Floor.Instance == Entry.node.part) and ((Entry.node.part.CFrame:PointToObjectSpace(Feet):Abs() - Entry.node.part.Size / 2) * Vector3.new(1, 0, 1)):Max(Vector3.zero).Magnitude > 1.5 or Flat.Magnitude > 0.1 and GetDanger(Root.Position, Root.Position + Flat.Unit * math.min(Flat.Magnitude, 4), 0.8)
	                    Waited, Began = Danger and (Waited or os.clock()) or nil, Danger and (os.clock() - (Waited or os.clock()) < 10 and os.clock() or 0) or Began
	                    local Climbing, Above = Humanoid:GetState() == Enum.HumanoidStateType.Climbing, Entry.node.position.Y > Feet.Y + 1.2
	                    Movement = not Danger and (Flat.Magnitude > 0.1 and Flat.Unit or Climbing and Above and Root.CFrame.LookVector * Vector3.new(1, 0, 1)) or Vector3.zero
	                    if Grounded and not Climbing and not Danger and (Above and Flat.Magnitude < 2 or Flat.Magnitude > 1 and Drift:Dot(Flat.Unit) < -Rig.speed * 0.5 or Flat.Magnitude > 1 and os.clock() - Began > 0.6 and Root.AssemblyLinearVelocity:Dot(Flat.Unit) < 2) then
	                        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	                    end
	                    if Flat.Magnitude < 0.8 and math.abs(Entry.node.position.Y - Feet.Y) < 2 then
	                        Step, Began = Step + 1, os.clock()
	                    end
	                elseif Entry.climb and not Launched then
	                    local Lead: Vector3 = (Entry.from.position - Feet) * Vector3.new(1, 0, 1)
	                    local Synced: boolean = true
	                    if Entry.phase and os.clock() - (Waited or os.clock()) < 6 and not (Floor and Platforms[Floor.Instance]) then
	                        for Part: BasePart, v: CFrame in Entry.phase do
	                            if (Part.Position - v.Position).Magnitude > 2 or Part.CFrame.LookVector:Dot(v.LookVector) < 0.94 then
	                                Synced = false
	                            end
	                        end
	                    end
	                    Waited, Began = not Synced and (Waited or os.clock()) or nil, not Synced and (os.clock() - (Waited or os.clock()) < 12 and os.clock() or 0) or Began
	                    Movement = Lead.Magnitude > 0.1 and Lead.Unit or Vector3.zero
	                    if Lead.Magnitude < 0.6 and Grounded and Synced then
	                        Launched = os.clock()
	                    end
	                elseif Entry.climb then
	                    local Core: Vector3 = Entry.climb.half - Vector3.new(1, 0, 1) * math.min(Entry.climb.half.X, Entry.climb.half.Z)
	                    local Axis: Vector3 = (Entry.climb.position + ((Feet - Entry.climb.position) * Vector3.new(1, 0, 1)):Max(-Core):Min(Core) - Feet) * Vector3.new(1, 0, 1)
	                    if Feet.Y < Entry.node.position.Y + 0.6 and not (Grounded and Feet.Y > Entry.node.position.Y - 0.5) then
	                        Movement = Axis.Magnitude > 0.1 and Axis.Unit or Vector3.zero
	                        if Grounded and ((((Feet - Entry.climb.position) * Vector3.new(1, 0, 1)):Abs() - Entry.climb.half):Max(Vector3.zero).Magnitude > 1.2 or Feet.Y + 4.5 < Entry.climb.bottom) then
	                            Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	                        end
	                        if Humanoid:GetState() == Enum.HumanoidStateType.Climbing and Root.AssemblyLinearVelocity.Y < 1 and Axis.Magnitude > 1 and os.clock() - Launched > 1 then
	                            Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	                            Launched = os.clock()
	                        end
	                    else
	                        Movement = Flat.Magnitude > 0.1 and Flat.Unit or Vector3.zero
	                        if Humanoid:GetState() == Enum.HumanoidStateType.Climbing and (((Entry.node.position - Entry.climb.position) * Vector3.new(1, 0, 1)):Abs() - Entry.climb.half):Max(Vector3.zero).Magnitude > 0.5 then
	                            Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	                        end
	                    end
	                    if Grounded and Feet.Y > Entry.node.position.Y - 1 and Flat.Magnitude < 1.5 then
	                        Step, Began, Launched = Step + 1, os.clock(), nil
	                    end
	                elseif not Launched then
	                    local Direction: Vector3 = (Entry.node.position - Entry.from.position) * Vector3.new(1, 0, 1)
	                    Direction = Direction.Magnitude > 0.01 and Direction.Unit or Vector3.zero
	                    local Takeoff: Vector3 = Source and Source.part.Position or Entry.from.position + Direction * Entry.takeoff
	                    local Lead: Vector3 = (Takeoff - Feet) * Vector3.new(1, 0, 1)
	                    local Lateral: Vector3 = Lead - Direction * Lead:Dot(Direction)
	                    local Settle = Source or Entry.delay > 0.05 or os.clock() - Began > 1.5
	                    if Settle then
	                        Movement = Lead.Magnitude > (Source and 0.4 or 0.1) and Lead.Unit * math.clamp(Lead.Magnitude * 1.5, 0.3, 1) or Vector3.zero
	                    else
	                        Movement = (Lead:Dot(Direction) > 1.5 or Lateral.Magnitude > 0.35 or Lead:Dot(Direction) < -0.5) and Lead.Magnitude > 0.1 and Lead.Unit or (Lead + Direction * 2).Magnitude > 0.1 and (Lead + Direction * 2).Unit or Vector3.zero
	                    end
	                    if Grounded and Lead.Magnitude > 0.8 and Drift:Dot(Lead.Unit) < -Rig.speed * 0.5 then
	                        Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	                    end
	                    if Grounded and (Source or Settle and Lead.Magnitude < 0.35 or not Settle and Lead.Magnitude < 0.8 and Lead:Dot(Direction) <= 0.15 and Lateral.Magnitude < 0.35 and Root.AssemblyLinearVelocity:Dot(Direction) > -1 or Lead.Magnitude < 1.5 and Drift.Magnitude > Rig.speed * 0.5) then
	                        local Choice = not Target and not Source and {}
	                        if Target then
	                            for _, v: Vector3 in Target.samples do
	                                local Point: Vector3 = Target.part.CFrame * v
	                                local Reach: number = Entry.jump * Entry.jump - 2 * Rig.gravity * (Point.Y - Feet.Y - Rig.lift + 0.1)
	                                if Reach >= 0 then
	                                    local Time: number = (Entry.jump + math.sqrt(Reach)) / Rig.gravity
	                                    Point = Target.center + Target.linear * Time + CFrame.fromAxisAngle(Target.angular.Magnitude > 0.0001 and Target.angular.Unit or Vector3.yAxis, Target.angular.Magnitude * Time) * (Point - Target.center)
	                                    if Rig.speed * Time - ((Point - Feet) * Vector3.new(1, 0, 1)).Magnitude > 1.2 and (not Choice or v.Magnitude < Choice[1].Magnitude) then
	                                        local Safe: boolean = true
	                                        for _, Kill: {Vector3} in Rig.kills do
	                                            Probe.Size, Probe.CFrame = Kill[1], CFrame.new(Point + Vector3.new(0, Rig.hover, 0) + Kill[2])
	                                            Safe = Safe and not workspace:GetPartsInPart(Probe, KillOverlap)[1]
	                                        end
	                                        if Safe then
	                                            Choice = {v}
	                                        end
	                                    end
	                                end
	                            end
	                        elseif Source then
	                            local Reach: number = Entry.jump * Entry.jump - 2 * Rig.gravity * (Entry.node.position.Y - Feet.Y - Rig.lift + 0.1)
	                            Choice = Reach >= 0 and Rig.speed * (Entry.jump + math.sqrt(Reach)) / Rig.gravity - Flat.Magnitude > 1 and {}
	                        end
	                        local Synced: boolean = true
	                        if Entry.phase and os.clock() - (Waited or os.clock()) < 6 and not (Floor and Platforms[Floor.Instance]) then
	                            for Part: BasePart, v: CFrame in Entry.phase do
	                                if (Part.Position - v.Position).Magnitude > 2 or Part.CFrame.LookVector:Dot(v.LookVector) < 0.94 then
	                                    Synced = false
	                                end
	                            end
	                        end
	                        local Motion = Entry.node.part and Platforms[Entry.node.part]
	                        if Motion and not (Floor and Floor.Instance == Entry.node.part) then
	                            local Elapsed: number = Entry.time or 0.5
	                            local Predicted: CFrame = CFrame.new(Motion.center + Motion.linear * Elapsed) * CFrame.fromAxisAngle(Motion.angular.Magnitude > 0.0001 and Motion.angular.Unit or Vector3.yAxis, Motion.angular.Magnitude * Elapsed) * Entry.node.part.CFrame.Rotation
	                            Synced = (Predicted.Position - Entry.node.frame.Position).Magnitude < 2 and Predicted.LookVector:Dot(Entry.node.frame.LookVector) > 0.94
	                        end
	                        local Danger = Choice and (not Synced or GetDanger(Root.Position, Entry.node.position + Vector3.new(0, Rig.hover, 0), Entry.time or 0.5, Entry.jump > 0 and Entry.jump or nil))
	                        Waited, Began = Danger and (Waited or os.clock()) or nil, Danger and (os.clock() - (Waited or os.clock()) < 10 and os.clock() or 0) or Began
	                        if Choice and not Danger then
	                            Launched, Airborne, Peak, Aim, Bent = os.clock(), nil, 0, Choice[1], nil
	                            if Entry.jump > 0 then
	                                Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	                            end
	                        end
	                    end
	                else
	                    local Elapsed: number = os.clock() - Launched
	                    local Velocity: Vector3 = Root.AssemblyLinearVelocity
	                    local Destination: Vector3 = Entry.node.position
	                    if Target and Aim then
	                        local Point: Vector3 = Target.part.CFrame * Aim
	                        local Reach: number = Velocity.Y * Velocity.Y + 2 * Rig.gravity * (Feet.Y - Point.Y + (Velocity.Y * Velocity.Y + 2 * Rig.gravity * (Feet.Y - Point.Y) < 0 and Rig.lift or 0))
	                        local Time: number = Reach >= 0 and (Velocity.Y + math.sqrt(Reach)) / Rig.gravity or 0
	                        Destination = Target.center + Target.linear * Time + CFrame.fromAxisAngle(Target.angular.Magnitude > 0.0001 and Target.angular.Unit or Vector3.yAxis, Target.angular.Magnitude * Time) * (Point - Target.center)
	                    end
	                    Flat = (Destination - Feet) * Vector3.new(1, 0, 1)
	                    local Chase: Vector3 = Flat / 0.12 + (Target and Target.linear * Vector3.new(1, 0, 1) or Vector3.zero)
	                    Airborne, Peak = Airborne or not Grounded, math.max(Peak, Velocity.Y)
	                    Bent = Bent or not Entry.bend or ((Feet - Entry.bend) * Vector3.new(1, 0, 1)):Dot((Entry.node.position - Entry.bend) * Vector3.new(1, 0, 1)) > 0 or ((Entry.bend - Feet) * Vector3.new(1, 0, 1)).Magnitude < 0.8
	                    Movement = Elapsed >= Entry.delay and (not Bent and ((Entry.bend - Feet) * Vector3.new(1, 0, 1)).Unit or Chase.Magnitude > 1 and Chase / math.max(Chase.Magnitude, Rig.speed)) or Vector3.zero
	                    if Entry.path then
	                        local Point: Vector3 = Entry.path[#Entry.path][2]
	                        for i: number = 2, #Entry.path do
	                            if Entry.path[i][1] >= Elapsed + 0.1 + Entry.takeoff / Rig.speed then
	                                Point = Entry.path[i - 1][2]:Lerp(Entry.path[i][2], math.clamp((Elapsed + 0.1 + Entry.takeoff / Rig.speed - Entry.path[i - 1][1]) / math.max(Entry.path[i][1] - Entry.path[i - 1][1], 0.001), 0, 1))
	                                break
	                            end
	                        end
	                        local Lead: Vector3 = (Point - Feet) * Vector3.new(1, 0, 1)
	                        Movement = Lead.Magnitude > 0.1 and Lead.Unit * math.clamp(Lead.Magnitude / 0.1 / Rig.speed, 0, 1) or Vector3.zero
	                    end
	                    if Humanoid:GetState() == Enum.HumanoidStateType.Climbing and Feet.Y <= Destination.Y - 1 and Flat.Magnitude < 1 then
	                        Movement = Root.CFrame.LookVector * Vector3.new(1, 0, 1)
	                    end
	                    if (Grounded or Humanoid:GetState() == Enum.HumanoidStateType.Climbing and Feet.Y > Destination.Y - 1) and (Airborne or Elapsed > 0.3 and Flat.Magnitude < 1 and math.abs(Destination.Y - Feet.Y) < 1) then
	                        if Entry.jump > 0 and Peak > 20 and Peak < 150 then
	                            Rig.jump = math.max(Rig.jump, Peak)
	                        end
	                        Launched = nil
	                        local Hit, Support = GetFloor(Root.Position), not Target and workspace:Raycast(Destination + Vector3.new(0, 1, 0), Vector3.new(0, -4, 0), Params)
	                        if Target and Hit and Hit.Instance == Target.part or not Target and (Flat.Magnitude < 2.5 and math.abs(Destination.Y - Feet.Y) < 1.5 or Flat.Magnitude < 6 and Hit and Support and Hit.Instance == Support.Instance) then
	                            Step, Began = Step + 1, os.clock()
	                        else
	                            Blocked[`{Entry.from.index},{Entry.node.index}`] = (Blocked[`{Entry.from.index},{Entry.node.index}`] or 0) + 1
	                            if LocalPlayer.Character:FindFirstChild("currentSection") then
	                                Strikes[LocalPlayer.Character.currentSection.Value] = (Strikes[LocalPlayer.Character.currentSection.Value] or 0) + 1
	                            end
	                            Route = nil
	                        end
	                    end
	                end
	
	                if Grounded and not Launched and Movement and Drift.Magnitude > 1 then
	                    Movement -= Drift / Rig.speed
	                    Movement = Movement.Magnitude > 1 and Movement.Unit or Movement
	                end
	            end))
	        else
	            TowerOfHell.Controls.moveFunction = Old
	            Route, Rig, Built, Tower, Launched, Aim, Bent, Movement, Planning, Building, Escape, Sunk, Hovered = nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil
	            Version += 1
	            table.clear(Nodes)
	            table.clear(Cells)
	            table.clear(Sections)
	            table.clear(Moving)
	            table.clear(Hazards)
	            table.clear(Platforms)
	            table.clear(Trusses)
	            table.clear(Blocked)
	            table.clear(Parts)
	            table.clear(Tracks)
	            table.clear(Demos)
	            table.clear(Strikes)
	            table.clear(Watched)
	            if Folder then
	                Folder:Destroy()
	                Folder = nil
	            end
	            if Probe then
	                Probe:Destroy()
	                Probe = nil
	            end
	        end
	    end,
	    Tooltip = "Climbs the tower for you by walking and jumping like a player. It maps every section, plans the jumps it can actually make, times jumps onto moving platforms and steers around kill bricks."
	})
	
	Path = AutoPlay:CreateToggle({
	    Name = "Path",
	    Function = function(Callback: boolean)
	        for _, v: Part in Parts do
	            v.Transparency = Callback and Route and 0.3 or 1
	        end
	    end,
	    Default = true,
	    Tooltip = "Draws the route it is following."
	})
	Color = AutoPlay:CreateColorSlider({
	    Name = "Color",
	    Function = function(Hue: number, Sat: number, Val: number)
	        for _, v: Part in Parts do
	            v.Color = Color3.fromHSV(Hue, Sat, Val)
	        end
	    end,
	    DefaultHue = 0.44
	})
end)