local Navigation = {}
local CellSize: number = 3
local HalfCell: number = 1.5
local KeySpan: number = 8192
local KeyHalf: number = 4096
local KeyPlane: number = 67108864
local Faces = {
    {1, 0, 0},
    {-1, 0, 0},
    {0, 1, 0},
    {0, -1, 0},
    {0, 0, 1},
    {0, 0, -1}
}
local Flats = {
    {1, 0, 0},
    {-1, 0, 0},
    {0, 0, 1},
    {0, 0, -1},
    {1, 0, 1},
    {1, 0, -1},
    {-1, 0, 1},
    {-1, 0, -1}
}
local Saves = {
    {1, 0, 0},
    {-1, 0, 0},
    {0, 0, 1},
    {0, 0, -1},
    {1, 0, 1},
    {-1, 0, -1},
    {-1, 0, 1},
    {1, 0, -1},
    {0, -1, 0}
}
local Leaps = {
    {2, 0, 1},
    {2, 0, -1},
    {-2, 0, 1},
    {-2, 0, -1},
    {1, 0, 2},
    {-1, 0, 2},
    {1, 0, -2},
    {-1, 0, -2}
}
local Corners = {}

for X: number = -1, 1 do
    for Y: number = -1, 1 do
        for Z: number = -1, 1 do
            if math.abs(X) + math.abs(Y) + math.abs(Z) > 1 then
                table.insert(Corners, {X, Y, Z})
            end
        end
    end
end

export type Grid = Vector3
export type Placement = {
    Grid: Grid,
    Position: Vector3,
    Mode: string,
    PlacementType: string,
    SupportGrid: Grid?,
    Normal: Vector3?,
    AimPosition: Vector3?,
    AimDirection: Vector3?,
    Distance: number,
    Valid: boolean,
    Reason: string?
}
export type Action = {
    Type: string,
    Grid: Grid,
    Position: Vector3,
    Time: number,
    Duration: number,
    PlacementType: string?,
    Preconditions: {[string]: any}?
}
export type Result = {
    Success: boolean,
    Partial: boolean,
    Reason: string,
    Mode: string,
    WalkingPath: {Vector3},
    BridgePath: {Placement},
    Actions: {Action},
    Cost: number,
    Distance: number,
    BlocksUsed: number,
    Damage: number
}

Navigation.GridSize = CellSize
Navigation.CellBounds = Vector3.new(CellSize - 0.1, CellSize - 0.1, CellSize - 0.1)
Navigation.Contexts = {}
Navigation.Requests = {}
Navigation.World = nil
Navigation.DebugAdapter = nil
Navigation.Profiles = {
    Default = {
        Name = "block",
        Solid = true,
        Support = true,
        Placeable = true,
        Breakable = true,
        Climbable = false,
        Replaceable = false,
        Temporary = false,
        Cost = 0
    }
}
Navigation.Config = {
    Agent = {
        Height = 5,
        Radius = 1,
        HipHeight = 3,
        BodyOffset = 1,
        HeadOffset = 2.2,
        HeadRadius = 0.6,
        WalkSpeed = 22,
        JumpVelocity = 42.6,
        Gravity = 196.2,
        Reach = 18,
        PlaceCps = 12,
        Latency = 0.08,
        MaxDrop = 27,
        ImpactLimit = 86,
        DamageScale = 0.75,
        DamageAllowance = 0,
        SafeMargin = 1,
        BlocksAvailable = math.huge
    },
    Costs = {
        Block = 1,
        Jump = 0.06,
        Drop = 0.04,
        Diagonal = 0.02,
        Risk = 0.5,
        Air = 0.25,
        Scarce = 4,
        Elevation = 0.25
    },
    Traversal = {
        Mover = "Jump",
        MaxAirTime = 1.75,
        Margin = 1,
        Rise = 1,
        Instant = false
    },
    Retreat = {
        MaxTime = 6,
        MaxSteps = 6000,
        SafeDistance = 40,
        Weights = {
            Distance = 10,
            Passage = 4,
            Escape = 2,
            Edge = 4,
            Exposure = 3,
            Time = 0.5
        }
    },
    Search = {
        MaxSteps = 40000,
        WalkSteps = 40000,
        Budget = 0.012,
        Weight = 1.3,
        BridgeWeight = 2,
        Fallback = false,
        FieldMargin = 16,
        Tolerance = 1,
        GoalDrop = 3,
        Free = true,
        BridgeWidth = 1,
        Segment = 12,
        Yield = true,
        Smooth = true,
        Bridge = true,
        Tower = true,
        JumpGap = true
    },
    Clutch = {
        Reach = 14,
        MaxFall = math.huge,
        Void = true,
        MaxBlocks = 4,
        MaxChain = 3,
        SampleTime = 0.05,
        MinSurvival = 0.55,
        ReachSteps = 16,
        Scan = 90,
        Width = 1,
        Anchored = true,
        Weights = {
            Survival = 100,
            Damage = 0.9,
            Blocks = 4,
            Escape = 6,
            Distance = 0.35
        }
    },
    Mind = {
        ThinkInterval = 0.2,
        ReactionTime = 0.18,
        ObservationLifetime = 8,
        EnemyLifetime = 12,
        FailureLifetime = 60,
        FailureCooldown = 4,
        MemoryLimit = 64,
        CommitTime = 1.5,
        SwitchMargin = 12,
        FlipWindow = 6,
        GoalTimeout = 35,
        CollectTimeout = 15,
        FightTimeout = 8,
        RecoveryLimit = 3,
        RecoveryWait = 3,
        RecoveryReset = 4,
        PostKillWait = 0.8,
        BasePreference = 12,
        JumpCommitTime = 1.2,
        RangedInterval = 1,
        ArrivalRadius = 5,
        BaseRadius = 16,
        LowHealth = 0.4,
        CriticalHealth = 0.22,
        RecoverHealth = 0.7,
        HighHealth = 0.8,
        BlockReserve = 8,
        TravelBlocks = 24,
        IronReserve = 8,
        DiamondTarget = 4,
        EmeraldTarget = 2,
        ValuableThreshold = 20,
        ResourceWeights = {iron = 0.08, diamond = 5, emerald = 15},
        EarlyTime = 180,
        LateTime = 600,
        ThreatRadius = 60,
        LethalRange = 18,
        BedThreatRadius = 35,
        SupportRadius = 24,
        HighGround = 6,
        ChaseSpeed = 3,
        UnknownDamage = 30,
        UnknownArmor = 0.25,
        UnknownEnemyHealth = 100,
        AttackInterval = 0.4,
        ForecastTime = 1.2,
        MaxThreat = 45,
        FightThreshold = 12,
        FinishSupport = 1,
        RouteRiskLimit = 65,
        SafeRouteRisk = 30,
        RouteEnemyRadius = 25,
        RouteSampleLimit = 80,
        PlanTimeout = 4,
        PlanSteps = 12000,
        ReplanInterval = 0.5,
        ReplanMargin = 0.15,
        RepathWindow = 10,
        TargetDrift = 0.25,
        TargetMargin = 1,
        VerifyInterval = 1,
        StuckTime = 2.5,
        ProgressDistance = 0.75,
        OffRoute = 6,
        BreakTimeout = 3,
        PlacementTimeout = 0.8,
        PlacementCooldown = 0.16,
        BuildLimit = 8,
        AvoidPenalty = 4,
        AvoidLifetime = 30,
        Segment = 12,
        ScanInterval = 1,
        DropInterval = 0.5,
        SurfaceLifetime = 1,
        FilterInterval = 0.5,
        ProjectileLifetime = 2,
        DebugLimit = 80,
        DebugInterval = 1,
        Priorities = {
            WaitForSpawn = 1000, Recover = 1000, WaitForInformation = 120,
            DefendBed = 245, ReturnToBase = 230, Escape = 230, BuildCover = 230,
            BuildUp = 229, SurvivalCombat = 225, Hide = 220, Finish = 290,
            Harass = 150, Reposition = 140, Fight = 120, CollectResources = 65,
            AttackBed = 70, SupportTeam = 110, CollectDrops = 85, Reassess = 1
        },
        Weights = {
            Enemy = 28, ExtraEnemy = 16, Weapon = 0.5, Elevation = 12,
            Projectile = 16, Void = 30, Narrow = 22, Uncertainty = 15,
            Support = 14, Cover = 10, Escape = 12, Health = 35,
            Equipment = 0.6, Isolation = 14, Resources = 0.35,
            NoBed = 20, Travel = 0.12, Failure = 18, Turns = 1.5,
            Jump = 6, Block = 2, Time = 0.8
        }
    }
}

local function GridAxis(Value: number): number
    return math.round(Value / CellSize)
end

local function CellKey(X: number, Y: number, Z: number): number
    return (X + KeyHalf) * KeyPlane + (Y + KeyHalf) * KeySpan + (Z + KeyHalf)
end

Navigation.CellKey = CellKey

function Navigation.WorldToGrid(Position: Vector3): Vector3
    return Vector3.new(math.round(Position.X / CellSize), math.round(Position.Y / CellSize), math.round(Position.Z / CellSize))
end

function Navigation.GridToWorld(Grid: Vector3): Vector3
    return Vector3.new(Grid.X * CellSize, Grid.Y * CellSize, Grid.Z * CellSize)
end

function Navigation.SnapToGrid(Position: Vector3): Vector3
    return Vector3.new(math.round(Position.X / CellSize) * CellSize, math.round(Position.Y / CellSize) * CellSize, math.round(Position.Z / CellSize) * CellSize)
end

function Navigation.SetGridSize(Size: number)
    CellSize = Size
    HalfCell = Size / 2
    Navigation.GridSize = Size
    Navigation.CellBounds = Vector3.new(Size - 0.1, Size - 0.1, Size - 0.1)
end

local WorldClass = {}
WorldClass.__index = WorldClass

function WorldClass.Solid(self, X: number, Y: number, Z: number): boolean
    local Key: number = CellKey(X, Y, Z)
    if self.Overlay then
        local Entry = self.Overlay[Key]
        if Entry ~= nil then
            return Entry ~= false
        end
    end

    local Learned: number? = self.Learned[Key]
    if Learned then
        if Learned > os.clock() then
            return true
        end
        self.Learned[Key] = nil
    end

    local Cached: boolean? = self.Cells[Key]
    if Cached ~= nil then
        return Cached
    end

    local Solid: boolean = self.Hooks.GetBlock and self.Hooks.GetBlock(X, Y, Z) and true or false
    if not Solid and self.Hooks.IsSolid then
        Solid = self.Hooks.IsSolid(X, Y, Z) and true or false
    end

    self.Cells[Key] = Solid
    return Solid
end

function WorldClass.Block(self, X: number, Y: number, Z: number)
    local Key: number = CellKey(X, Y, Z)
    if self.Overlay then
        local Entry = self.Overlay[Key]
        if Entry ~= nil then
            return Entry ~= false and Entry or nil
        end
    end

    local Cached = self.Blocks[Key]
    if Cached ~= nil then
        return Cached ~= false and Cached or nil
    end

    local Block = self.Hooks.GetBlock and self.Hooks.GetBlock(X, Y, Z) or false
    self.Blocks[Key] = Block
    return Block ~= false and Block or nil
end

function WorldClass.Profile(self, Block)
    if not Block then
        return nil
    end
    return self.Hooks.GetProfile and self.Hooks.GetProfile(Block) or Navigation.Profiles.Default
end

function WorldClass.Invalidate(self, X: number, Y: number, Z: number)
    if self.Land and #self.Pending >= 4096 then
        self.Land = nil
    elseif self.Land then
        table.insert(self.Pending, Vector3.new(X, Y, Z))
    end

    local Key: number = CellKey(X, Y, Z)
    if self.Cells[Key] == nil and self.Blocks[Key] == nil then
        return
    end

    self.Cells[Key] = nil
    self.Blocks[Key] = nil
    self.Revision += 1

    if self.DirtyIndex >= 512 then
        table.clear(self.Dirty)
        self.DirtyIndex = 0
        self.Flush += 1
        return
    end

    self.DirtyIndex += 1
    self.Dirty[self.DirtyIndex] = Key
end

function WorldClass.Learn(self, X: number, Y: number, Z: number, Duration: number)
    self.Learned[CellKey(X, Y, Z)] = os.clock() + Duration
    self.Cells[CellKey(X, Y, Z)] = true
    self:Invalidate(X, Y, Z)
end

function WorldClass.Touch(self)
    table.clear(self.Cells)
    table.clear(self.Blocks)
    table.clear(self.Dirty)
    self.DirtyIndex = 0
    self.Revision += 1
    self.Flush += 1
    self.Land = nil
end

function WorldClass.Columns(self, Budget: number?)
    if not self.Hooks.GetBlocks or not self.Hooks.GetBlock then
        return nil
    end

    local Slice = Budget and os.clock() + Budget
    if not self.Land then
        local Land, MinX, MaxX, MinZ, MaxZ = {}, math.huge, -math.huge, math.huge, -math.huge
        self.Land, self.Pending, self.Bounds = Land, {}, {MinX, MaxX, MinZ, MaxZ}
        for _, v: any in self.Hooks.GetBlocks() do
            local Key: number = CellKey(v.X, 0, v.Z)
            Land[Key] = math.max(Land[Key] or v.Y, v.Y)
            MinX, MaxX, MinZ, MaxZ = math.min(MinX, v.X), math.max(MaxX, v.X), math.min(MinZ, v.Z), math.max(MaxZ, v.Z)
            if Slice and os.clock() >= Slice then
                task.wait()
                Slice = os.clock() + Budget
            end
        end
        self.Bounds = {MinX, MaxX, MinZ, MaxZ}
        self.LandVersion += 1
    end

    for _, v: Vector3 in self.Pending do
        local Key: number = CellKey(v.X, 0, v.Z)
        local Top = self.Land[Key]
        if (Top or -math.huge) < v.Y and self.Hooks.GetBlock(v.X, v.Y, v.Z) then
            self.LandVersion += Top and 0 or 1
            self.Land[Key] = v.Y
            self.Bounds[1], self.Bounds[2], self.Bounds[3], self.Bounds[4] = math.min(self.Bounds[1], v.X), math.max(self.Bounds[2], v.X), math.min(self.Bounds[3], v.Z), math.max(self.Bounds[4], v.Z)
        elseif Top == v.Y and not self.Hooks.GetBlock(v.X, v.Y, v.Z) then
            local Lower: number? = nil
            for Level: number = v.Y - 1, v.Y - 64, -1 do
                if self.Hooks.GetBlock(v.X, Level, v.Z) then
                    Lower = Level
                    break
                end
            end
            self.Land[Key] = Lower
            self.LandVersion += Lower and 0 or 1
        end
    end
    table.clear(self.Pending)
    return self.Land
end

function WorldClass.Surface(self, X: number, Z: number, Floor: number): number?
    local Top: number? = self.Land and self.Land[CellKey(X, 0, Z)]
    if not Top or Top <= Floor + 1 then
        return Top
    end

    for Y: number = Floor + 1, Floor - 16, -1 do
        if self:Block(X, Y, Z) then
            local Surface: number = Y
            while Surface < Top and self:Block(X, Surface + 1, Z) do
                Surface += 1
            end
            return Surface
        end
    end

    return nil
end

function WorldClass.Field(self, From, Goal, Margin: number, Mode: string, Budget: number?)
    if not self:Columns(Budget) then
        return nil
    end

    local GoalKey: number = CellKey(Goal.x, 0, Goal.z)
    local Floor: number = Goal.y - 1
    local MinX, MaxX = math.min(self.Bounds[1], From.x, Goal.x) - Margin, math.max(self.Bounds[2], From.x, Goal.x) + Margin
    local MinZ, MaxZ = math.min(self.Bounds[3], From.z, Goal.z) - Margin, math.max(self.Bounds[4], From.z, Goal.z) + Margin
    for _, v: any in {self.FieldCache, self.FieldPrevious} do
        if v.Goal == GoalKey and v.Floor == Floor and v.Mode == Mode and v.Version == self.LandVersion and v.Box[1] <= MinX and v.Box[2] >= MaxX and v.Box[3] <= MinZ and v.Box[4] >= MaxZ then
            return v.Costs, self.Land, v.Box, v.Tops
        end
    end

    local Slice = Budget and os.clock() + Budget
    local Costs: {[number]: number} = {[GoalKey] = 0}
    local Tops: {[number]: number} = {[GoalKey] = Floor}
    local Surfaces: {[number]: number | boolean} = {}
    local Buckets: {[number]: {number}} = {[0] = {Goal.x, Goal.z}}
    local Level, Last = 0, 0

    while Level <= Last do
        local Bucket: {number}? = Buckets[Level]
        local Index: number = 1
        while Bucket and Index < #Bucket do
            local X, Z = Bucket[Index], Bucket[Index + 1]
            Index += 2

            local Column: number = CellKey(X, 0, Z)
            if Costs[Column] == Level then
                for _, v: {number} in Flats do
                    local NeighborX, NeighborZ = X + v[1], Z + v[3]
                    local Key: number = CellKey(NeighborX, 0, NeighborZ)
                    local Cost: number = Level + (self.Land[Key] and 0 or (Mode ~= "Blatant" and v[1] ~= 0 and v[3] ~= 0 and 2 or 1))
                    if NeighborX >= MinX and NeighborX <= MaxX and NeighborZ >= MinZ and NeighborZ <= MaxZ and (Costs[Key] or math.huge) > Cost then
                        if not self.Land[Key] and self.Land[Column] and Surfaces[Column] == nil then
                            Surfaces[Column] = self:Surface(X, Z, Floor) or false
                        end
                        Costs[Key] = Cost
                        Tops[Key] = not self.Land[Key] and Surfaces[Column] or Tops[Column]
                        Buckets[Cost] = Buckets[Cost] or {}
                        table.insert(Buckets[Cost], NeighborX)
                        table.insert(Buckets[Cost], NeighborZ)
                        Last = math.max(Last, Cost)
                    end
                end
            end

            if Slice and os.clock() >= Slice then
                task.wait()
                Slice = os.clock() + Budget
            end
        end

        Buckets[Level] = nil
        Level += 1
    end

    self.FieldPrevious, self.FieldCache = self.FieldCache, {Goal = GoalKey, Floor = Floor, Mode = Mode, Version = self.LandVersion, Box = {MinX, MaxX, MinZ, MaxZ}, Costs = Costs, Tops = Tops}
    return Costs, self.Land, self.FieldCache.Box, Tops
end

function WorldClass.Begin(self, Overlay)
    self.Overlay = Overlay or {}
    return self.Overlay
end

function WorldClass.Finish(self)
    self.Overlay = nil
end

function WorldClass.Write(self, X: number, Y: number, Z: number, Block)
    if self.Overlay then
        self.Overlay[CellKey(X, Y, Z)] = Block or false
    end
end

function Navigation.newWorld(Hooks)
    return setmetatable({
        Hooks = Hooks or {},
        Cells = {},
        Blocks = {},
        Learned = {},
        Dirty = {},
        DirtyIndex = 0,
        Revision = 0,
        Flush = 0,
        Pending = {},
        LandVersion = 0,
        Overlay = nil
    }, WorldClass)
end

local function FallTime(Drop: number, Speed: number, Gravity: number): number?
    local Inner: number = Speed * Speed + 2 * Gravity * Drop
    if Inner < 0 then
        return nil
    end
    return (Speed + math.sqrt(Inner)) / Gravity
end

local function ImpactSpeed(Drop: number, Speed: number, Gravity: number): number
    return math.sqrt(math.max(Speed * Speed + 2 * Gravity * Drop, 0))
end

local function FallDamage(Impact: number, Agent): number
    return Impact > Agent.ImpactLimit and (Impact - Agent.ImpactLimit) * Agent.DamageScale or 0
end

local function SafeDrop(Speed: number, Agent): number
    local Limit: number = Agent.ImpactLimit + Agent.DamageAllowance / Agent.DamageScale
    local Budget: number = (Limit * Limit - Speed * Speed) / (2 * Agent.Gravity)
    return Budget > 0 and Budget * Agent.SafeMargin or 0
end

local function JumpLand(Agent, Rise: number): number?
    local Inner: number = Agent.JumpVelocity * Agent.JumpVelocity - 2 * Agent.Gravity * Rise
    if Inner < 0 then
        return nil
    end
    return (Agent.JumpVelocity + math.sqrt(Inner)) / Agent.Gravity
end

local function JumpHeight(Agent, Elapsed: number): number
    return Agent.JumpVelocity * Elapsed - Agent.Gravity * Elapsed * Elapsed * 0.5
end

local function Traverse(Agent, Traversal, Horizontal: number, Vertical: number, Speed: number)
    local Needed: number = Horizontal + Traversal.Margin
    if Traversal.Mover == "Glide" then
        if Vertical > Traversal.Rise * CellSize then
            return false, 0, 0, "TooHigh"
        end
        local Climb: number = Traversal.Instant and 0 or math.abs(Vertical)
        local AirTime: number = (Needed + Climb) / Speed
        return AirTime <= Traversal.MaxAirTime, AirTime, Speed * Traversal.MaxAirTime - Climb - Traversal.Margin, AirTime <= Traversal.MaxAirTime and "Traversable" or "AirTime"
    end

    local AirTime: number? = JumpLand(Agent, Vertical)
    if not AirTime then
        return false, 0, 0, "TooHigh"
    end
    local Reach: number = Speed * math.min(AirTime, Traversal.MaxAirTime) - Traversal.Margin
    return Reach >= Horizontal, AirTime, Reach, Reach >= Horizontal and "Traversable" or (AirTime > Traversal.MaxAirTime and "AirTime" or "Distance")
end

local function NewContext(World, Agent, Mode: string)
    return {
        World = World,
        Agent = Agent,
        Mode = Mode,
        Fits = {},
        Stands = {},
        Height = math.max(math.ceil(Agent.Height / CellSize), 1),
        Revision = World.Revision,
        Dirty = World.DirtyIndex,
        Flush = World.Flush
    }
end

local function Refresh(Context)
    local World = Context.World
    if Context.Revision == World.Revision then
        return
    end

    if Context.Flush ~= World.Flush then
        table.clear(Context.Fits)
        table.clear(Context.Stands)
    else
        for i: number = Context.Dirty + 1, World.DirtyIndex do
            for Layer: number = -Context.Height, 1 do
                local Shifted: number = World.Dirty[i] + Layer * KeySpan
                Context.Fits[Shifted] = nil
                Context.Stands[Shifted] = nil
            end
        end
    end

    Context.Revision = World.Revision
    Context.Dirty = World.DirtyIndex
    Context.Flush = World.Flush
end

local function Fits(Context, X: number, Y: number, Z: number): boolean
    local Key: number = CellKey(X, Y, Z)
    local Cached: boolean? = Context.Fits[Key]
    if Cached ~= nil then
        return Cached
    end

    local Clear: boolean = true
    for Layer: number = 0, Context.Height - 1 do
        if Context.World:Solid(X, Y + Layer, Z) then
            Clear = false
            break
        end
    end

    Context.Fits[Key] = Clear
    return Clear
end

local function Stands(Context, X: number, Y: number, Z: number): boolean
    local Key: number = CellKey(X, Y, Z)
    local Cached: boolean? = Context.Stands[Key]
    if Cached ~= nil then
        return Cached
    end

    local Standing = Context.World:Solid(X, Y - 1, Z) and Fits(Context, X, Y, Z)
    Context.Stands[Key] = Standing
    return Standing
end

local function CanCutCorner(Context, X: number, Y: number, Z: number, DirectionX: number, DirectionZ: number): boolean
    return Fits(Context, X + DirectionX, Y, Z) and Fits(Context, X, Y, Z + DirectionZ)
end

local function TraceClear(Context, Origin: Vector3, Target: Vector3, SkipA: number, SkipB: number): boolean
    local DirectionX, DirectionY, DirectionZ = Target.X - Origin.X, Target.Y - Origin.Y, Target.Z - Origin.Z
    local X, Y, Z = GridAxis(Origin.X), GridAxis(Origin.Y), GridAxis(Origin.Z)
    local StepX, NextX, DeltaX = 0, math.huge, math.huge
    local StepY, NextY, DeltaY = 0, math.huge, math.huge
    local StepZ, NextZ, DeltaZ = 0, math.huge, math.huge

    if DirectionX ~= 0 then
        StepX = DirectionX > 0 and 1 or -1
        NextX = ((X + StepX * 0.5) * CellSize - Origin.X) / DirectionX
        DeltaX = CellSize / math.abs(DirectionX)
    end
    if DirectionY ~= 0 then
        StepY = DirectionY > 0 and 1 or -1
        NextY = ((Y + StepY * 0.5) * CellSize - Origin.Y) / DirectionY
        DeltaY = CellSize / math.abs(DirectionY)
    end
    if DirectionZ ~= 0 then
        StepZ = DirectionZ > 0 and 1 or -1
        NextZ = ((Z + StepZ * 0.5) * CellSize - Origin.Z) / DirectionZ
        DeltaZ = CellSize / math.abs(DirectionZ)
    end

    for _ = 1, 64 do
        if NextX > 1 and NextY > 1 and NextZ > 1 then
            return true
        end

        if NextX <= NextY and NextX <= NextZ then
            X, NextX = X + StepX, NextX + DeltaX
        elseif NextY <= NextZ then
            Y, NextY = Y + StepY, NextY + DeltaY
        else
            Z, NextZ = Z + StepZ, NextZ + DeltaZ
        end

        local Key: number = CellKey(X, Y, Z)
        if Key ~= SkipA and Key ~= SkipB and Context.World:Solid(X, Y, Z) then
            return false
        end
    end

    return true
end

local function BodyBlocked(Context, State, X: number, Y: number, Z: number): boolean
    local Reach: number = HalfCell + State.HeadRadius
    if math.abs(State.Head.X - X * CellSize) < Reach and math.abs(State.Head.Y - Y * CellSize) < Reach and math.abs(State.Head.Z - Z * CellSize) < Reach then
        return true
    end

    if State.BodyHeight > 1 and X == State.BodyX and Z == State.BodyZ then
        local Low: number = State.BodyY + (Context.World:Block(State.BodyX, State.BodyY + State.BodyHeight, State.BodyZ) and 0 or 1)
        if Y >= Low and Y <= State.BodyY + State.BodyHeight - 1 then
            return true
        end
    end

    return false
end

local function SupportAt(Context, X: number, Y: number, Z: number, Mode: string, Extra: number?)
    local World = Context.World
    local Best, Score = nil, -1

    for _, v: {number} in Faces do
        local SupportX, SupportY, SupportZ = X + v[1], Y + v[2], Z + v[3]
        if World:Solid(SupportX, SupportY, SupportZ) or CellKey(SupportX, SupportY, SupportZ) == Extra then
            local Block = World:Block(SupportX, SupportY, SupportZ)
            if not Block or World:Profile(Block).Support then
                local Rank: number = v[2] == 0 and 2 or (v[2] < 0 and 1 or 0)
                if Rank > Score then
                    Best, Score = v, Rank
                end
            end
        end
    end

    if Best then
        return X + Best[1], Y + Best[2], Z + Best[3], -Best[1], -Best[2], -Best[3], "Face"
    end

    if Mode ~= "Blatant" then
        return nil
    end

    for _, v: {number} in Corners do
        local SupportX, SupportY, SupportZ = X + v[1], Y + v[2], Z + v[3]
        if World:Solid(SupportX, SupportY, SupportZ) or CellKey(SupportX, SupportY, SupportZ) == Extra then
            local Block = World:Block(SupportX, SupportY, SupportZ)
            if not Block or World:Profile(Block).Support then
                local Rank: number = v[2] == 0 and 2 or (v[2] < 0 and 1 or 0)
                if Rank > Score then
                    Best, Score = v, Rank
                end
            end
        end
    end

    if Best then
        return X + Best[1], Y + Best[2], Z + Best[3], -Best[1], -Best[2], -Best[3], "Diagonal"
    end

    return nil
end

local function PlacementAt(Context, State, X: number, Y: number, Z: number, Mode: string, Extra: number?, Quick: boolean?)
    local Block = Context.World:Block(X, Y, Z)
    if Block and not Context.World:Profile(Block).Replaceable then
        return nil, "Occupied"
    elseif not Block and Context.World:Solid(X, Y, Z) then
        return nil, "Occupied"
    end

    if BodyBlocked(Context, State, X, Y, Z) then
        return nil, "Body"
    end

    local SupportX, SupportY, SupportZ, NormalX, NormalY, NormalZ, Kind = SupportAt(Context, X, Y, Z, Mode, Extra)
    if not SupportX and not Context.Floating then
        return nil, "Support"
    end

    local Aim: Vector3 = Vector3.new(X * CellSize, Y * CellSize - HalfCell, Z * CellSize)
    if SupportX and math.abs(NormalX) + math.abs(NormalY) + math.abs(NormalZ) == 1 then
        Aim = Vector3.new(SupportX * CellSize + NormalX * HalfCell, SupportY * CellSize + NormalY * HalfCell, SupportZ * CellSize + NormalZ * HalfCell)
    elseif SupportX then
        Aim = Vector3.new(math.clamp(X * CellSize, SupportX * CellSize - HalfCell, SupportX * CellSize + HalfCell), math.clamp(Y * CellSize, SupportY * CellSize - HalfCell, SupportY * CellSize + HalfCell), math.clamp(Z * CellSize, SupportZ * CellSize - HalfCell, SupportZ * CellSize + HalfCell))
    end

    local Distance: number = (Aim - State.Position).Magnitude
    if Distance > Context.Reach then
        return nil, "Reach"
    end

    if not Quick and not TraceClear(Context, State.Eye, Aim, SupportX and CellKey(SupportX, SupportY, SupportZ) or 0, CellKey(X, Y, Z)) then
        return nil, "Sight"
    end

    local Direction: Vector3 = Aim - State.Eye
    return {
        Grid = Vector3.new(X, Y, Z),
        Position = Vector3.new(X * CellSize, Y * CellSize, Z * CellSize),
        Mode = Mode,
        PlacementType = SupportX and Kind or "Float",
        SupportGrid = SupportX and Vector3.new(SupportX, SupportY, SupportZ) or nil,
        Normal = SupportX and Vector3.new(-NormalX, -NormalY, -NormalZ) or nil,
        AimPosition = Aim,
        AimDirection = Direction.Magnitude > 0 and Direction.Unit or Vector3.new(0, -1, 0),
        AimCFrame = Direction.Magnitude > 0 and CFrame.lookAt(State.Eye, Aim) or nil,
        Distance = Distance,
        Valid = true
    }
end

local function VoidSave(Context, State)
    for Depth: number = 1, 3 do
        local Y: number = GridAxis(State.Position.Y - Depth * CellSize)
        for _, v: {number} in Saves do
            if Context.World:Solid(State.CellX + v[1], Y + v[2], State.CellZ + v[3]) then
                return State.CellX, Y, State.CellZ
            end
        end
    end

    return nil
end

local function HeapPush(Heap, Node)
    local Index: number = #Heap + 1
    Heap[Index] = Node

    while Index > 1 do
        local Parent: number = Index // 2
        if Heap[Parent].f <= Heap[Index].f then
            break
        end
        Heap[Parent], Heap[Index] = Heap[Index], Heap[Parent]
        Index = Parent
    end
end

local function HeapPop(Heap)
    local Size: number = #Heap
    if Size == 0 then
        return nil
    end

    local Top = Heap[1]
    Heap[1] = Heap[Size]
    Heap[Size] = nil
    Size -= 1

    local Index: number = 1
    while true do
        local Left: number = Index * 2
        local Right: number = Left + 1
        local Best: number = Index
        if Left <= Size and Heap[Left].f < Heap[Best].f then
            Best = Left
        end
        if Right <= Size and Heap[Right].f < Heap[Best].f then
            Best = Right
        end
        if Best == Index then
            break
        end
        Heap[Index], Heap[Best] = Heap[Best], Heap[Index]
        Index = Best
    end

    return Top
end

local function Heuristic(Context, X: number, Y: number, Z: number, GoalX: number, GoalY: number, GoalZ: number): number
    local DeltaX, DeltaY, DeltaZ = math.abs(GoalX - X), (GoalY - Y) * CellSize, math.abs(GoalZ - Z)
    return (math.max(DeltaX, DeltaZ) + math.min(DeltaX, DeltaZ) * 0.4142) * CellSize * Context.FlatCost + (DeltaY > 0 and DeltaY * Context.ClimbCost or -DeltaY / CellSize * Context.DropCost)
end

local function Level(Pack, Column: number): number
    local Top: number? = Pack.field and not Pack.land[Column] and Pack.tops[Column] or nil
    return Top and math.min(Top + 1, Pack.gy + 1) or Pack.gy
end

local function Detour(From: number, To: number, Reference: number): number
    if To > From then
        return math.max(To - math.max(From, Reference), 0)
    end
    return math.max(math.min(From, Reference) - To, 0)
end

local function Walled(Context, X: number, Y: number, Z: number): boolean
    for i: number = 1, 4 do
        local Direction: {number} = Flats[i]
        if not Fits(Context, X + Direction[1], Y, Z + Direction[3]) and not Fits(Context, X + Direction[1], Y + 1, Z + Direction[3]) then
            return true
        end
    end
    return false
end

local function Estimate(Pack, X: number, Y: number, Z: number): number
    local Column: number = CellKey(X, 0, Z)
    return Heuristic(Pack.ctx, X, Y, Z, Pack.gx, Level(Pack, Column), Pack.gz) + (Pack.field and math.max((Pack.field[Column] or math.max(Pack.box[1] - X, X - Pack.box[2], Pack.box[3] - Z, Z - Pack.box[4])) - (Pack.land[Column] and 0 or 1) - Pack.span, 0) * Pack.ctx.PlaceCost or 0)
end

local function Relax(Pack, Parent, Key: number, X: number, Y: number, Z: number, Cost: number, Blocks: number, Kind: string, Damage: number, Air: number?)
    if Pack.closed[Key] then
        return
    end

    if Pack.avoid then
        Cost += Pack.avoid[Key] or 0
    end

    local Penalty: number = Pack.elevation and Y ~= Parent.y and Detour(Parent.y, Y, Level(Pack, CellKey(X, 0, Z))) * Pack.elevation or 0
    Cost += Penalty

    local Existing = Pack.nodes[Key]
    if Existing and Existing.g <= Cost then
        return
    end

    local Node = {x = X, y = Y, z = Z, g = Cost, b = Blocks, pr = Parent, mt = Kind, dmg = Damage, air = Air, ex = (Parent.ex or 0) + Penalty}
    Node.f = Cost + Estimate(Pack, X, Y, Z) * Pack.weight
    Pack.nodes[Key] = Node
    HeapPush(Pack.heap, Node)
end

local function DropTo(Context, X: number, Y: number, Z: number)
    local Agent = Context.Agent

    for Depth: number = 1, math.ceil(Agent.MaxDrop / CellSize) do
        if Context.World:Solid(X, Y - Depth - 1, Z) then
            local Drop: number = Depth * CellSize
            return Y - Depth, Drop, Context.Traversal.Instant and 0 or FallDamage(ImpactSpeed(Drop, 0, Agent.Gravity), Agent)
        end
        if not Fits(Context, X, Y - Depth, Z) then
            return nil
        end
    end

    return nil
end

local function GapLand(Context, X: number, Y: number, Z: number, DirectionX: number, DirectionZ: number, Span: number, Level: number): boolean
    local Agent = Context.Agent
    local Stride: number = CellSize * (DirectionX ~= 0 and DirectionZ ~= 0 and 1.4142 or 1)

    if Context.Traversal.Mover == "Glide" then
        local Height: number = math.max(Level, Y)
        for Layer: number = Y + 1, Height do
            if not Fits(Context, X, Layer, Z) then
                return false
            end
        end
        local Length: number = math.sqrt(DirectionX * DirectionX + DirectionZ * DirectionZ) * Span * CellSize
        for Sample: number = 0, math.ceil(Length) do
            local PointX, PointZ = (X + DirectionX * Span * math.min(Sample / Length, 1)) * CellSize, (Z + DirectionZ * Span * math.min(Sample / Length, 1)) * CellSize
            if not Fits(Context, GridAxis(PointX - Agent.Radius), Height, GridAxis(PointZ - Agent.Radius)) or not Fits(Context, GridAxis(PointX + Agent.Radius), Height, GridAxis(PointZ - Agent.Radius)) or not Fits(Context, GridAxis(PointX - Agent.Radius), Height, GridAxis(PointZ + Agent.Radius)) or not Fits(Context, GridAxis(PointX + Agent.Radius), Height, GridAxis(PointZ + Agent.Radius)) then
                return false
            end
        end
        for Layer: number = Level + 1, Y do
            if not Fits(Context, X + DirectionX * Span, Layer, Z + DirectionZ * Span) then
                return false
            end
        end
        return true
    end

    for Step: number = 1, Span do
        local Height: number = Y + math.max(math.round(JumpHeight(Agent, Step * Stride / Agent.WalkSpeed) / CellSize), Step == Span and Level - Y or -math.huge)
        if not Fits(Context, X + DirectionX * Step, Height, Z + DirectionZ * Step) then
            return false
        end
    end

    return true
end

local function Expand(Pack, Node)
    local Context = Pack.ctx
    local Agent = Context.Agent
    local X, Y, Z = Node.x, Node.y, Node.z
    local Head: boolean = Context.World:Solid(X, Y + Context.Height, Z)
    local Placed: boolean = Node.mt == "Bridge" or Node.mt == "Tower"
    local Extra: number? = Placed and CellKey(X, Y - 1, Z) or nil
    local Column: number = CellKey(X, 0, Z)
    local Top: number = Level(Pack, Column)
    local Near: boolean = math.max(math.abs(Pack.gx - X), math.abs(Pack.gz - Z)) <= Pack.gy - Y + 1
    local Rise = Pack.bridge and (Top > Y and (Placed or Near) and not (Pack.field and Pack.land[Column] and (Pack.field[Column] or 0) > 0) or Walled(Context, X, Y, Z))
    local Launch: boolean = Placed and Y <= Top and Pack.field ~= nil and (Pack.field[Column] or math.huge) <= Pack.span + 1
    local Lift: number = CellSize * Context.ClimbCost
    local Walkable: boolean = false

    for _, v: {number} in Flats do
        local DirectionX, DirectionZ = v[1], v[3]
        local Diagonal: boolean = DirectionX ~= 0 and DirectionZ ~= 0
        if Diagonal and not CanCutCorner(Context, X, Y, Z, DirectionX, DirectionZ) then
            continue
        end

        local Step: number = Diagonal and Context.DiagCost or Context.StepCost
        local TargetX, TargetZ = X + DirectionX, Z + DirectionZ
        local Level: boolean = Stands(Context, TargetX, Y, TargetZ)

        for DeltaY: number = -1, 1 do
            local TargetY: number = Y + DeltaY
            if DeltaY == 1 and (Head or Level or (Diagonal and not CanCutCorner(Context, X, TargetY, Z, DirectionX, DirectionZ))) then
                continue
            end
            if DeltaY == -1 and (Diagonal or Node.mt ~= "Bridge" or Level or Top >= Y) then
                continue
            end
            if not Fits(Context, TargetX, TargetY, TargetZ) then
                continue
            end

            local Key: number = CellKey(TargetX, TargetY, TargetZ)
            local Cost: number = Step + (DeltaY == 1 and Context.JumpCost + Lift or DeltaY == -1 and Context.DropCost or 0)

            if Stands(Context, TargetX, TargetY, TargetZ) then
                if DeltaY ~= -1 then
                    Relax(Pack, Node, Key, TargetX, TargetY, TargetZ, Node.g + Cost, Node.b, DeltaY == 1 and "Jump" or "Walk", 0)
                    Walkable = true
                end
                continue
            end

            if DeltaY == 0 then
                local Landing, Drop, Damage = DropTo(Context, TargetX, TargetY, TargetZ)
                if Landing and Damage <= Agent.DamageAllowance then
                    Relax(Pack, Node, CellKey(TargetX, Landing, TargetZ), TargetX, Landing, TargetZ, Node.g + Cost + Context.DropCost + math.sqrt(2 * Drop / Agent.Gravity) + Damage * Context.RiskCost, Node.b, "Drop", Damage)
                    Walkable = true
                    if Pack.field and Pack.land[CellKey(TargetX, 0, TargetZ)] then
                        continue
                    end
                end
            end

            if Pack.bridge and Node.b < Pack.limit and (DeltaY ~= 1 or Rise or Launch) and SupportAt(Context, TargetX, TargetY - 1, TargetZ, Context.Mode, Extra) then
                Relax(Pack, Node, Key, TargetX, TargetY, TargetZ, Node.g + Cost + Context.PlaceCost + (Node.b >= Context.Budgeted and Context.ScarceCost or 0) + (Node.mt == "Bridge" and Node.pr and (DirectionX ~= X - Node.pr.x or DirectionZ ~= Z - Node.pr.z) and Context.TurnCost or 0), Node.b + 1, "Bridge", 0)
                Walkable = true
            end
        end

        if Pack.gap and not Level and (not Head or Context.Traversal.Mover == "Glide") and (Node.mt ~= "Bridge" or DirectionX == X - Node.pr.x and DirectionZ == Z - Node.pr.z) and not Context.World:Solid(TargetX, Y - 1, TargetZ) and not Context.World:Solid(TargetX, Y - 2, TargetZ) then
            local Stride: number = CellSize * (Diagonal and 1.4142 or 1)
            local Land = Context.World.Land
            for Span: number = 2, math.floor(Context.Leap / Stride) + 1 do
                local LandX, LandZ = X + DirectionX * Span, Z + DirectionZ * Span
                local Surface = Land and Land[CellKey(LandX, 0, LandZ)]
                local Landed: boolean = false
                if Surface or not Land then
                    for LandY: number = math.min(Y + Context.Rise, Surface and Surface + 1 or math.huge), Y - Context.Dive, -1 do
                        if Stands(Context, LandX, LandY, LandZ) then
                            local Crossable, AirTime = Traverse(Agent, Context.Traversal, (Span - 1) * Stride, (LandY - Y) * CellSize, Agent.WalkSpeed)
                            local Damage: number = LandY < Y and not Context.Traversal.Instant and FallDamage(ImpactSpeed((Y - LandY) * CellSize, Context.Traversal.Mover == "Glide" and 0 or Agent.JumpVelocity, Agent.Gravity), Agent) or 0
                            if Crossable and (Node.air or 0) + AirTime <= Context.Traversal.MaxAirTime and Damage <= Agent.DamageAllowance and GapLand(Context, X, Y, Z, DirectionX, DirectionZ, Span, LandY) then
                                Relax(Pack, Node, CellKey(LandX, LandY, LandZ), LandX, LandY, LandZ, Node.g + Step * Span + Context.JumpCost + Context.AirCost * AirTime + math.max(LandY - Y, 0) * Lift + Damage * Context.RiskCost, Node.b, "Jump", Damage, (Node.air or 0) + AirTime)
                                Walkable = true
                            end
                            if LandY <= Y + 1 then
                                Landed = true
                                break
                            end
                        end
                    end
                end
                if Landed or not Fits(Context, X + DirectionX * (Span - 1), Y, Z + DirectionZ * (Span - 1)) or not Fits(Context, LandX, Y, LandZ) then
                    break
                end
            end
        end

        if Context.Traversal.Instant and not Level then
            for Height: number = 2, Context.Rise do
                if not Fits(Context, X, Y + Height, Z) then
                    break
                end
                if Stands(Context, TargetX, Y + Height, TargetZ) and (not Diagonal or CanCutCorner(Context, X, Y + Height, Z, DirectionX, DirectionZ)) then
                    Relax(Pack, Node, CellKey(TargetX, Y + Height, TargetZ), TargetX, Y + Height, TargetZ, Node.g + Step + Context.JumpCost + Height * Lift, Node.b, "Jump", 0)
                    Walkable = true
                    break
                end
            end
        end
    end

    if Pack.gap and Context.Traversal.Mover == "Glide" and Node.mt ~= "Bridge" then
        local Land = Context.World.Land
        for _, v: {number} in Leaps do
            local DirectionX, DirectionZ = v[1], v[3]
            local FirstX, FirstZ, SecondX, SecondZ = X + (math.abs(DirectionX) == 2 and DirectionX // 2 or 0), Z + (math.abs(DirectionZ) == 2 and DirectionZ // 2 or 0), X + math.sign(DirectionX), Z + math.sign(DirectionZ)
            if Stands(Context, FirstX, Y, FirstZ) or Stands(Context, SecondX, Y, SecondZ) or Context.World:Solid(FirstX, Y - 1, FirstZ) or Context.World:Solid(SecondX, Y - 1, SecondZ) then
                continue
            end

            local Stride: number = CellSize * math.sqrt(DirectionX * DirectionX + DirectionZ * DirectionZ)
            local Edge: number = Stride / math.max(math.abs(DirectionX), math.abs(DirectionZ))
            for Span: number = 1, math.floor((Context.Leap + Edge) / Stride) do
                local LandX, LandZ = X + DirectionX * Span, Z + DirectionZ * Span
                local Surface = Land and Land[CellKey(LandX, 0, LandZ)]
                local Landed: boolean = false
                if Surface or not Land then
                    for LandY: number = math.min(Y + Context.Rise, Surface and Surface + 1 or math.huge), Y - Context.Dive, -1 do
                        if Stands(Context, LandX, LandY, LandZ) then
                            local Crossable, AirTime = Traverse(Agent, Context.Traversal, Span * Stride - Edge, (LandY - Y) * CellSize, Agent.WalkSpeed)
                            local Damage: number = LandY < Y and not Context.Traversal.Instant and FallDamage(ImpactSpeed((Y - LandY) * CellSize, 0, Agent.Gravity), Agent) or 0
                            if Crossable and (Node.air or 0) + AirTime <= Context.Traversal.MaxAirTime and Damage <= Agent.DamageAllowance and GapLand(Context, X, Y, Z, DirectionX, DirectionZ, Span, LandY) then
                                Relax(Pack, Node, CellKey(LandX, LandY, LandZ), LandX, LandY, LandZ, Node.g + Context.StepCost * Span * Stride / CellSize + Context.JumpCost + Context.AirCost * AirTime + math.max(LandY - Y, 0) * Lift + Damage * Context.RiskCost, Node.b, "Jump", Damage, (Node.air or 0) + AirTime)
                                Walkable = true
                            end
                            if LandY <= Y + 1 then
                                Landed = true
                                break
                            end
                        end
                    end
                end
                if Landed then
                    break
                end
            end
        end
    end

    if Pack.tower and Node.b < Pack.limit and not Head and (Rise or not Walkable) and Fits(Context, X, Y + 1, Z) then
        Relax(Pack, Node, CellKey(X, Y + 1, Z), X, Y + 1, Z, Node.g + Context.PlaceCost + Context.JumpCost + Lift + (Node.b >= Context.Budgeted and Context.ScarceCost or 0), Node.b + 1, "Tower", 0)
    end

    local Climb = Context.World:Profile(Context.World:Block(X, Y, Z))
    if Climb and Climb.Climbable then
        for DeltaY: number = -1, 1, 2 do
            local Target = Context.World:Profile(Context.World:Block(X, Y + DeltaY, Z))
            if not Context.World:Solid(X, Y + DeltaY, Z) or (Target and Target.Climbable) then
                Relax(Pack, Node, CellKey(X, Y + DeltaY, Z), X, Y + DeltaY, Z, Node.g + Context.ClimbStep, Node.b, "Climb", 0)
            end
        end
    end
end

local function Search(Context, Blocks: number, From, Goal, Weight: number, Options, Request, Stage: string, Seed)
    local Pack = {
        ctx = Context,
        heap = {},
        nodes = {},
        closed = {},
        weight = Weight,
        gx = Goal.x,
        gy = Goal.y,
        gz = Goal.z,
        limit = Blocks,
        bridge = Stage ~= "Walk" and Options.Bridge ~= false,
        tower = Stage ~= "Walk" and Options.Tower ~= false,
        gap = Options.JumpGap ~= false,
        span = Options.JumpGap ~= false and Context.Span or 0,
        avoid = Context.Avoid,
        elevation = Context.ElevationCost > 0 and Context.ElevationCost or nil,
        reached = false,
        steps = 0
    }

    if Stage == "Bridge" then
        Pack.field, Pack.land, Pack.box, Pack.tops = Context.World:Field(From, Goal, Options.FieldMargin, Context.Mode, Options.Yield and task and Options.Budget)
    elseif Pack.gap then
        Context.World:Columns(Options.Yield and task and Options.Budget)
    end

    local Budget: number = Stage == "Walk" and Options.WalkSteps or Options.MaxSteps
    if Seed then
        for Key: number, v: any in Seed.nodes do
            if Seed.closed[Key] then
                v.f = v.g + Estimate(Pack, v.x, v.y, v.z) * Weight
                Pack.nodes[Key] = v
                HeapPush(Pack.heap, v)
                Budget += 1
            end
        end
    else
        local Start = {x = From.x, y = From.y, z = From.z, g = 0, b = 0, mt = "Start", dmg = 0}
        Start.f = Estimate(Pack, From.x, From.y, From.z) * Weight
        Pack.nodes[CellKey(From.x, From.y, From.z)] = Start
        HeapPush(Pack.heap, Start)
    end

    local Tolerance: number = Options.Tolerance * CellSize
    local Score: number = math.huge
    local Slice: number = os.clock() + Options.Budget

    while #Pack.heap > 0 and Pack.steps < Budget do
        Pack.steps += 1

        if os.clock() >= Slice then
            if Request and Request.Cancelled then
                return Pack
            end
            if Options.Yield and task then
                task.wait()
            end
            Slice = os.clock() + Options.Budget
        end

        local Node = HeapPop(Pack.heap)
        local Key: number = CellKey(Node.x, Node.y, Node.z)
        if Pack.closed[Key] then
            continue
        end
        Pack.closed[Key] = true

        local DeltaX, DeltaY, DeltaZ = (Goal.x - Node.x) * CellSize, (Goal.y - Node.y) * CellSize, (Goal.z - Node.z) * CellSize
        local Distance: number = math.sqrt(DeltaX * DeltaX + DeltaY * DeltaY + DeltaZ * DeltaZ)
        if Distance < Score then
            Pack.node, Score = Node, Distance
        end

        if Distance <= Tolerance then
            Pack.node, Pack.reached = Node, true
            return Pack
        end

        Expand(Pack, Node)
    end

    return Pack
end

local function StandPosition(Agent, X: number, Y: number, Z: number): Vector3
    return Vector3.new(X * CellSize, Y * CellSize - HalfCell + Agent.HipHeight, Z * CellSize)
end

local function BuildState(Input, Agent, World)
    if typeof(Input) == "Vector3" then
        Input = {Position = Input}
    end

    local Position: Vector3 = Input.Position
    local Head: Vector3 = Position + Vector3.new(0, Agent.HeadOffset, 0)
    local State = {
        Position = Position,
        Velocity = Input.Velocity or Vector3.zero,
        Head = Head,
        Eye = Input.Eye or (Input.Camera and Input.Camera.Position) or Head,
        Aim = Input.Aim or (Input.Camera and Input.Camera.LookVector) or nil,
        HeadRadius = Agent.HeadRadius,
        BodyHeight = Input.BodyHeight or 2,
        Feet = Position.Y - Agent.HipHeight,
        Grounded = Input.Grounded,
        Blocks = Input.BlocksAvailable or Agent.BlocksAvailable,
        CellX = GridAxis(Position.X),
        CellY = GridAxis(Position.Y - Agent.HipHeight + HalfCell),
        CellZ = GridAxis(Position.Z),
        BodyX = GridAxis(Position.X),
        BodyY = GridAxis(Position.Y - Agent.BodyOffset),
        BodyZ = GridAxis(Position.Z)
    }

    if State.Grounded == nil and World then
        State.Grounded = World:Solid(State.CellX, State.CellY - 1, State.CellZ)
    end

    return State
end

local function WriteCell(Context, X: number, Y: number, Z: number, Block)
    Context.World:Write(X, Y, Z, Block)
    local Base: number = CellKey(X, Y, Z)
    for Offset: number = -Context.Height, 1 do
        Context.Fits[Base + Offset * KeySpan] = nil
        Context.Stands[Base + Offset * KeySpan] = nil
    end
end

local function WalkLine(Context, Y: number, StartX: number, StartZ: number, EndX: number, EndZ: number): boolean
    local DeltaX, DeltaZ = EndX - StartX, EndZ - StartZ
    local Span: number = math.max(math.abs(DeltaX), math.abs(DeltaZ))
    if Span == 0 then
        return true
    end

    local LastX, LastZ = StartX, StartZ
    for Step: number = 1, Span do
        local CellX, CellZ = StartX + math.round(DeltaX * Step / Span), StartZ + math.round(DeltaZ * Step / Span)
        if not Stands(Context, CellX, Y, CellZ) then
            return false
        end
        if CellX ~= LastX and CellZ ~= LastZ and not CanCutCorner(Context, LastX, Y, LastZ, CellX - LastX, CellZ - LastZ) then
            return false
        end
        LastX, LastZ = CellX, CellZ
    end

    return true
end

local function Compile(Context, Node, Options)
    local Agent = Context.Agent
    local Nodes = {}
    local Current = Node

    while Current do
        table.insert(Nodes, 1, Current)
        Current = Current.pr
    end

    local Actions, Bridge, Walking, Depends, Planned = {}, {}, {}, {}, {}
    local Blocks, Damage, Failure = 0, 0, nil
    local LastBridge, PriorBridge = nil, nil

    Context.World:Begin()

    for i: number, v: any in Nodes do
        for Offset: number = -1, Context.Height - 1 do
            Depends[CellKey(v.x, v.y + Offset, v.z)] = true
        end

        if v.air then
            local Previous = Nodes[i - 1]
            local Length: number = math.sqrt((v.x - Previous.x) ^ 2 + (v.z - Previous.z) ^ 2) * CellSize
            for Step: number = 1, math.ceil(Length) do
                for Layer: number = 0, Context.Height - 1 do
                    Depends[CellKey(GridAxis((Previous.x + (v.x - Previous.x) * Step / Length * CellSize) * CellSize), math.max(Previous.y, v.y) + Layer, GridAxis((Previous.z + (v.z - Previous.z) * Step / Length * CellSize) * CellSize))] = true
                end
            end
        end

        if v.mt == "Bridge" or v.mt == "Tower" then
            local Previous = Nodes[i - 1]
            local Lift: number = v.mt == "Tower" and Agent.HipHeight or 0
            local From = BuildState({Position = StandPosition(Agent, Previous.x, Previous.y, Previous.z) + Vector3.new(0, Lift, 0)}, Agent)

            if Options.BridgeWidth > 1 and LastBridge and PriorBridge and v.mt == "Bridge" and (v.x - LastBridge.X ~= LastBridge.X - PriorBridge.X or v.z - LastBridge.Z ~= LastBridge.Z - PriorBridge.Z) then
                local Fill = PlacementAt(Context, From, PriorBridge.X + v.x - LastBridge.X, v.y - 1, PriorBridge.Z + v.z - LastBridge.Z, Context.Mode, nil, true)
                if Fill and Blocks < Options.BlocksAvailable then
                    Fill.Type = "PlaceBlock"
                    Fill.Duration = 1 / Agent.PlaceCps
                    Fill.ExpectedPosition = From.Position
                    Fill.Lead = math.max((Context.Reach - Fill.Distance) / Agent.WalkSpeed, 0)
                    Fill.Preconditions = {MaxDistance = Context.Reach, RequiredSupport = Fill.SupportGrid, RequiredMode = Context.Mode}
                    table.insert(Actions, Fill)
                    table.insert(Bridge, Fill)
                    WriteCell(Context, Fill.Grid.X, Fill.Grid.Y, Fill.Grid.Z, Fill)
                    Planned[CellKey(Fill.Grid.X, Fill.Grid.Y, Fill.Grid.Z)] = true
                    Blocks += 1
                end
            end

            local Placement = PlacementAt(Context, From, v.x, v.y - 1, v.z, Context.Mode, nil, Options.Quick)
            if not Placement then
                Failure = {Reason = "Placement", Index = #Actions + 1, Grid = Vector3.new(v.x, v.y - 1, v.z)}
                break
            end

            Placement.Type = "PlaceBlock"
            Placement.Duration = 1 / Agent.PlaceCps
            Placement.ExpectedPosition = From.Position
            Placement.Lead = math.max((Context.Reach - Placement.Distance) / Agent.WalkSpeed, 0)
            Placement.Preconditions = {
                MaxDistance = Context.Reach,
                RequiredSupport = Placement.SupportGrid,
                RequiredMode = Context.Mode,
                Airborne = v.mt == "Tower" or nil,
                MinHeight = v.mt == "Tower" and v.y * CellSize - HalfCell or nil
            }

            table.insert(Actions, Placement)
            table.insert(Bridge, Placement)
            WriteCell(Context, v.x, v.y - 1, v.z, Placement)
            Planned[CellKey(v.x, v.y - 1, v.z)] = true
            PriorBridge, LastBridge = LastBridge, {X = v.x, Z = v.z}
            Blocks += 1
        elseif v.mt ~= "Start" then
            PriorBridge, LastBridge = nil, nil
        end

        if v.mt ~= "Start" then
            local Previous = Nodes[i - 1]
            Damage += v.dmg
            table.insert(Actions, {
                Type = v.mt == "Bridge" and "Walk" or (v.mt == "Tower" and "Jump" or v.mt),
                Grid = Vector3.new(v.x, v.y, v.z),
                Position = StandPosition(Agent, v.x, v.y, v.z),
                Duration = math.max(v.g - Previous.g - ((v.mt == "Bridge" or v.mt == "Tower") and Context.PlaceCost + (Previous.b >= Context.Budgeted and Context.ScarceCost or 0) or 0) - (v.air and Context.JumpCost + Context.AirCost * (v.air - (Previous.air or 0)) + math.max(v.y - Previous.y, 0) * CellSize * Context.ClimbCost + v.dmg * Context.RiskCost or 0) - ((v.ex or 0) - (Previous.ex or 0)), 0),
                Damage = v.dmg,
                Cost = v.g,
                AirTime = v.air,
                Gap = v.air and math.sqrt((v.x - Previous.x) ^ 2 + (v.z - Previous.z) ^ 2) * CellSize * (1 - 1 / math.max(math.abs(v.x - Previous.x), math.abs(v.z - Previous.z))) or nil,
                Rise = v.air and v.y - Previous.y or nil,
                From = v.air and Vector3.new(Previous.x, Previous.y, Previous.z) or nil
            })
        end
    end

    Context.World:Finish()
    table.clear(Context.Fits)
    table.clear(Context.Stands)

    if Options.Smooth then
        local Index: number = 2
        while Index <= #Actions do
            local Previous, Move = Actions[Index - 1], Actions[Index]
            local From: Vector3 = Previous.From or Previous.Grid
            if Previous.Type == "Walk" and Move.Type == "Walk" and Previous.Grid.Y == Move.Grid.Y and WalkLine(Context, Move.Grid.Y, From.X, From.Z, Move.Grid.X, Move.Grid.Z) then
                Move.From = From
                Move.Duration += Previous.Duration
                table.remove(Actions, Index - 1)
            else
                Index += 1
            end
        end
    end

    local Elapsed, LastPlace = 0, -math.huge
    local Interval: number = 1 / Agent.PlaceCps

    for _, v: any in Actions do
        if v.Type == "PlaceBlock" then
            Elapsed = math.max(Elapsed, LastPlace + Interval)
            LastPlace = Elapsed
        else
            table.insert(Walking, v.Position)
        end
        v.Time = Elapsed
        Elapsed += v.Duration
    end

    local Decisions = nil
    if Options.Debug then
        Decisions = {}
        local Segment = nil
        for i: number, v: any in Nodes do
            if v.mt == "Bridge" or v.mt == "Tower" then
                if not Segment or Segment.Kind ~= v.mt then
                    Segment = {Kind = v.mt, From = Nodes[i - 1], Count = 0}
                    table.insert(Decisions, Segment)
                end
                Segment.Count += 1
                Segment.To, Segment.Next = v, Nodes[i + 1]
            else
                Segment = nil
                if v.air then
                    table.insert(Decisions, {Kind = "Jump", From = Nodes[i - 1], To = v, Count = 0})
                end
            end
        end

        for i: number, v: any in Decisions do
            local From, To = v.From, v.Next and v.Next.mt ~= "Bridge" and v.Next.mt ~= "Tower" and v.Next or v.To
            local Span: number = math.max(math.abs(To.x - From.x), math.abs(To.z - From.z))
            local Gap: number = Span > 0 and math.sqrt((To.x - From.x) ^ 2 + (To.z - From.z) ^ 2) * CellSize * (1 - 1 / Span) or 0
            local Crossable, AirTime, _, Reason = Traverse(Agent, Context.Traversal, Gap, (To.y - From.y) * CellSize, Agent.WalkSpeed)
            local Explanation: string = v.Kind == "Jump" and "gap safely traversable" or v.Kind == "Tower" and (To.y > From.y and "destination requires useful elevation before horizontal traversal" or "no walkable route") or (Crossable and "landing not standable or a detour, placing is cheaper" or Reason == "TooHigh" and "landing too high to cross without blocks" or string.format("crossing needs %.2fs, above the %.2fs limit", AirTime, Context.Traversal.MaxAirTime))
            Decisions[i] = {
                Decision = v.Kind,
                Reason = Explanation,
                CurrentGrid = Vector3.new(From.x, From.y, From.z),
                TargetGrid = Vector3.new(To.x, To.y, To.z),
                CurrentY = From.y,
                TargetY = To.y,
                Gap = Gap,
                AirTime = AirTime,
                MaxAirTime = Context.Traversal.MaxAirTime,
                RequiredBlocks = v.Count,
                AvailableBlocks = Context.Budgeted,
                AlternativeJump = Crossable,
                Summary = string.format("Decision: %s | Reason: %s | CurrentGrid: %d,%d,%d | TargetGrid: %d,%d,%d | CurrentY: %d | TargetY: %d | Gap: %.1f studs | PredictedAirTime: %.2f | MaxAllowedAirTime: %.2f | RequiredBlocks: %d | AvailableBlocks: %s | AlternativeJump: %s", v.Kind, Explanation, From.x, From.y, From.z, To.x, To.y, To.z, From.y, To.y, Gap, AirTime, Context.Traversal.MaxAirTime, v.Count, tostring(Context.Budgeted), tostring(Crossable))
            }
        end
    end

    return {
        Actions = Actions,
        BridgePath = Bridge,
        WalkingPath = Walking,
        Blocks = Blocks,
        Damage = Damage,
        Duration = Elapsed,
        Depends = Depends,
        Planned = Planned,
        Decisions = Decisions,
        Failure = Failure
    }
end

local function Standable(Context, X: number, Y: number, Z: number, Depth: number)
    for Offset: number = 0, 2 do
        if Stands(Context, X, Y + Offset, Z) then
            return X, Y + Offset, Z
        end
    end

    for Drop: number = 1, Depth do
        if Stands(Context, X, Y - Drop, Z) then
            return X, Y - Drop, Z
        end
    end

    for Radius: number = 1, 2 do
        for DeltaX: number = -Radius, Radius do
            for DeltaZ: number = -Radius, Radius do
                if math.abs(DeltaX) == Radius or math.abs(DeltaZ) == Radius then
                    for DeltaY: number = 0, Radius do
                        if Stands(Context, X + DeltaX, Y + DeltaY, Z + DeltaZ) then
                            return X + DeltaX, Y + DeltaY, Z + DeltaZ
                        end
                        if Stands(Context, X + DeltaX, Y - DeltaY, Z + DeltaZ) then
                            return X + DeltaX, Y - DeltaY, Z + DeltaZ
                        end
                    end
                end
            end
        end
    end

    return X, Y, Z
end

local function ResolveTarget(Goal)
    if typeof(Goal) == "Vector3" then
        return Goal, nil
    end
    if typeof(Goal) == "Instance" then
        return Goal:IsA("Model") and Goal:GetPivot().Position or Goal.Position, nil
    end
    if Goal.Grid then
        return Vector3.new(Goal.Grid.X * CellSize, Goal.Grid.Y * CellSize, Goal.Grid.Z * CellSize), Goal.Grid
    end
    if Goal.RootPart then
        return Goal.RootPart.Position, nil
    end
    if Goal.Character then
        return Goal.Character:GetPivot().Position, nil
    end
    return Goal.Position, nil
end

local function ArcPosition(State, Agent, Elapsed: number): Vector3
    return State.Position + State.Velocity * Elapsed - Vector3.new(0, Agent.Gravity * Elapsed * Elapsed * 0.5, 0)
end

local function FallLine(State, Agent, Height: number)
    local Drop: number = State.Feet - Height
    local Elapsed: number? = FallTime(Drop, State.Velocity.Y, Agent.Gravity)
    if not Elapsed or Elapsed <= 0 then
        return nil
    end

    local Point: Vector3 = ArcPosition(State, Agent, Elapsed)
    return GridAxis(Point.X), GridAxis(Point.Z), Elapsed, ImpactSpeed(Drop, -State.Velocity.Y, Agent.Gravity), Point
end

local Footprint = {{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}

local function LandingOf(Context, State, Agent, Config)
    local Top: number = GridAxis(State.Feet + HalfCell) - 1

    for Step: number = 0, math.ceil(Config.Scan / CellSize) do
        local Level: number = Top - Step
        local X, Z, Elapsed, Impact, Point = FallLine(State, Agent, Level * CellSize + HalfCell)
        if X then
            local Solid: boolean = Context.World:Solid(X, Level, Z)
            if not Solid then
                for _, v: {number} in Footprint do
                    local FootX, FootZ = GridAxis(Point.X + v[1] * Agent.Radius), GridAxis(Point.Z + v[2] * Agent.Radius)
                    if Context.World:Solid(FootX, Level, FootZ) then
                        Solid, X, Z = true, FootX, FootZ
                        break
                    end
                end
            end
            if Solid then
                return {Level = Level, X = X, Z = Z, Time = Elapsed, Impact = Impact, Damage = FallDamage(Impact, Agent), Point = Point}
            end
        end
    end

    return nil
end

local function EscapeScore(Context, X: number, Y: number, Z: number): number
    local Count: number = 0

    for _, v: {number} in Flats do
        if Context.World:Solid(X + v[1], Y, Z + v[3]) then
            Count += 1
        end
    end

    return Count
end

local function ClutchCandidate(Context, State, Agent, Config, Level: number, Offset: {number})
    local X, Z, Elapsed, Impact, Point = FallLine(State, Agent, Level * CellSize + HalfCell)
    if not X then
        return nil
    end

    X, Z = X + Offset[1], Z + Offset[3]
    if Context.World:Solid(X, Level, Z) then
        return nil
    end

    local Latency: number = Agent.Latency + 1 / Agent.PlaceCps
    if Elapsed <= Latency then
        return nil
    end

    local Drift: number = math.sqrt((Point.X - X * CellSize) ^ 2 + (Point.Z - Z * CellSize) ^ 2)
    if Drift > HalfCell + Agent.Radius then
        return nil
    end

    local PlaceDelay: number = 0
    local Predicted = BuildState({Position = ArcPosition(State, Agent, Latency), Velocity = State.Velocity - Vector3.new(0, Agent.Gravity * Latency, 0)}, Agent)
    local Placement, Reason = PlacementAt(Context, Predicted, X, Level, Z, Context.Mode, nil, false)

    if not Placement and Reason == "Reach" then
        for Step: number = 1, math.min(math.floor((Elapsed - Latency) / Config.SampleTime), Config.ReachSteps) do
            PlaceDelay = Step * Config.SampleTime
            Predicted = BuildState({Position = ArcPosition(State, Agent, Latency + PlaceDelay), Velocity = State.Velocity - Vector3.new(0, Agent.Gravity * (Latency + PlaceDelay), 0)}, Agent)
            Placement, Reason = PlacementAt(Context, Predicted, X, Level, Z, Context.Mode, nil, false)
            if Placement or Reason ~= "Reach" then
                break
            end
        end
    end

    if not Placement then
        return nil, Reason
    end

    local Damage: number = FallDamage(Impact, Agent)
    local Escape: number = EscapeScore(Context, X, Level, Z)
    local Reliability: number = Placement.PlacementType == "Face" and 1 or (Placement.PlacementType == "Diagonal" and 0.75 or 0.35)
    local Margin: number = math.clamp((Elapsed - Latency - PlaceDelay) / math.max(Latency, 0.05), 0, 1)
    local Reach: number = math.clamp(1.2 - Placement.Distance / Context.Reach, 0, 1)
    local Survival: number = math.min(Reliability * Margin * Reach * math.clamp(1 - Drift / (HalfCell + Agent.Radius), 0.25, 1) * (Escape > 0 and 1 or 0.85), 0.99)

    return {
        Type = (Offset[1] ~= 0 or Offset[3] ~= 0) and "Side" or (Placement.Normal and Placement.Normal.Y == 0 and "Wall" or "Direct"),
        Grid = Vector3.new(X, Level, Z),
        Placement = Placement,
        Time = Latency + PlaceDelay,
        Impact = Impact,
        Damage = Damage,
        Drift = Drift,
        Escape = Escape,
        Blocks = 1,
        Survival = Survival,
        Score = Config.Weights.Survival * Survival - Config.Weights.Damage * Damage - Config.Weights.Blocks + Config.Weights.Escape * math.min(Escape, 2) - Config.Weights.Distance * Placement.Distance
    }
end

local function ClutchColumn(Context, State, Agent, Config, Level: number)
    local Anchor = nil

    for Step: number = 1, Config.MaxChain do
        Anchor = ClutchCandidate(Context, State, Agent, Config, Level - Step, {0, 0, 0}) or ClutchCandidate(Context, State, Agent, Config, Level + Step, {0, 0, 0})
        if Anchor then
            break
        end
    end

    if not Anchor then
        return nil
    end

    Context.World:Begin()
    WriteCell(Context, Anchor.Grid.X, Anchor.Grid.Y, Anchor.Grid.Z, Anchor.Placement)
    local Deep = ClutchCandidate(Context, State, Agent, Config, Level, {0, 0, 0})
    Context.World:Finish()
    table.clear(Context.Fits)
    table.clear(Context.Stands)

    if not Deep then
        return nil
    end

    local _, _, Elapsed = FallLine(State, Agent, Level * CellSize + HalfCell)
    local Ready: number = math.max(Anchor.Time, Deep.Time) + 1 / Agent.PlaceCps
    if not Elapsed or Ready > Elapsed then
        return nil
    end

    Deep.Time = Ready
    Deep.Type = "Column"
    Deep.Chain = {Anchor.Placement, Deep.Placement}
    Deep.Blocks = 2
    Deep.Survival *= Anchor.Survival
    Deep.Score = Config.Weights.Survival * Deep.Survival - Config.Weights.Damage * Deep.Damage - Config.Weights.Blocks * 2 + Config.Weights.Escape * math.min(Deep.Escape, 2) - Config.Weights.Distance * Deep.Placement.Distance
    return Deep
end

local function ClutchPlan(Context, State, Agent, Config, Options)
    local Landing = LandingOf(Context, State, Agent, Config)
    if Landing and Landing.Damage <= Agent.DamageAllowance and not Options.Force then
        return {Reason = "Safe", Landing = Landing}
    end
    if not Landing and not Config.Void then
        return {Reason = "Safe"}
    end

    local Deepest: number = math.ceil((State.Feet - math.min(SafeDrop(State.Velocity.Y, Agent), Config.MaxFall) - HalfCell) / CellSize)
    local Top: number = GridAxis(State.Feet + HalfCell) - 1
    if Landing and Landing.Level >= Deepest then
        return {Reason = "Safe", Landing = Landing}
    end

    local Best, Settled, Partial = nil, nil, false
    for Level: number = Deepest, Top do
        local Candidate = ClutchCandidate(Context, State, Agent, Config, Level, {0, 0, 0})

        for _, v: {number} in Flats do
            local Side = ClutchCandidate(Context, State, Agent, Config, Level, v)
            if Side and (not Candidate or Side.Score > Candidate.Score) then
                Candidate = Side
            end
        end

        if not Candidate and Config.MaxBlocks > 1 then
            Candidate = ClutchColumn(Context, State, Agent, Config, Level)
        end

        if Candidate and (not Best or Candidate.Score > Best.Score) then
            Best = Candidate
        end

        if Candidate and Candidate.Survival >= Config.MinSurvival then
            Settled = Candidate
            break
        end
    end

    Best = Settled or Best

    if not Best then
        for Level: number = Deepest - 1, math.max(Deepest - Config.MaxChain * 2, Landing and Landing.Level + 1 or Deepest - Config.MaxChain * 2), -1 do
            local Candidate = ClutchCandidate(Context, State, Agent, Config, Level, {0, 0, 0})
            if Candidate and (not Best or Candidate.Damage < Best.Damage) then
                Best, Partial = Candidate, true
            end
        end
    end

    if not Best or (Landing and Partial and Best.Damage >= Landing.Damage) then
        return {Reason = Landing and "Unreachable" or "Void", Landing = Landing}
    end

    if Config.Width > 1 and Best.Blocks < Config.MaxBlocks and Best.Drift > HalfCell * 0.5 then
        local DirectionX: number = math.abs(State.Velocity.X) > math.abs(State.Velocity.Z) and (State.Velocity.X > 0 and 1 or -1) or 0
        local DirectionZ: number = DirectionX == 0 and (State.Velocity.Z > 0 and 1 or -1) or 0

        Context.World:Begin()
        WriteCell(Context, Best.Grid.X, Best.Grid.Y, Best.Grid.Z, Best.Placement)
        local Extra = PlacementAt(Context, BuildState({Position = ArcPosition(State, Agent, Best.Time)}, Agent), Best.Grid.X + DirectionX, Best.Grid.Y, Best.Grid.Z + DirectionZ, Context.Mode, nil, false)
        Context.World:Finish()
        table.clear(Context.Fits)
        table.clear(Context.Stands)

        if Extra then
            Best.Chain = {Best.Placement, Extra}
            Best.Blocks += 1
            Best.Type = "Platform"
        end
    end

    return {Best = Best, Landing = Landing, Partial = Partial}
end

local function Merge(Base, Override)
    local Merged = table.clone(Base)
    if Override then
        for Key: string, v: any in Override do
            Merged[Key] = v
        end
    end
    return Merged
end

local function ContextFor(self, World, Agent, Costs, Mode: string, Options)
    local Channel: string = Options.Channel or "default"
    local Context = self.Contexts[Channel]

    if not Context or Context.World ~= World or Context.Mode ~= Mode or Context.Height ~= math.max(math.ceil(Agent.Height / CellSize), 1) then
        Context = NewContext(World, Agent, Mode)
        self.Contexts[Channel] = Context
    else
        Refresh(Context)
    end

    Context.Agent = Agent
    Context.Avoid = Options.Avoid
    Context.Reach = Options.Reach or Agent.Reach
    Context.Floating = Options.Floating == true
    Context.StepCost = CellSize / Agent.WalkSpeed
    Context.DiagCost = Context.StepCost * 1.4142 + Costs.Diagonal
    Context.PlaceCost = 1 / Agent.PlaceCps + Costs.Block + (Options.BlockProfile and Options.BlockProfile.Cost or 0)
    Context.JumpCost = Costs.Jump
    Context.DropCost = Costs.Drop
    Context.RiskCost = Costs.Risk
    Context.FlatCost = 1 / Agent.WalkSpeed
    Context.ClimbCost = (JumpLand(Agent, CellSize) or 0.35) / CellSize
    Context.ClimbStep = CellSize / math.max(Agent.WalkSpeed * 0.5, 1)
    Context.TurnCost = Costs.Diagonal
    Context.AirCost = Costs.Air
    Context.ScarceCost = Costs.Scarce
    Context.ElevationCost = Costs.Elevation or 0
    Context.Budgeted = Options.BlocksBudget or math.huge
    Context.Traversal = Merge(self.Config.Traversal, Options.Traversal)
    Context.Dive = math.floor(Agent.MaxDrop / CellSize)
    Context.Rise = Context.Traversal.Mover == "Glide" and Context.Traversal.Rise or math.floor(Agent.JumpVelocity * Agent.JumpVelocity / (2 * Agent.Gravity) / CellSize)
    Context.Leap = select(3, Traverse(Agent, Context.Traversal, 0, Context.Traversal.Mover == "Glide" and 0 or -Context.Dive * CellSize, Agent.WalkSpeed))
    Context.Span = math.max(math.floor(select(3, Traverse(Agent, Context.Traversal, 0, 0, Agent.WalkSpeed)) / CellSize), 0)
    return Context
end

local function Route(Context, Blocks: number, From, Goal, Options, Request)
    local Walk = Options.Free and Search(Context, Blocks, From, Goal, Options.Weight, Options, Request, "Walk") or nil
    local Node, Reached, Steps = Walk and Walk.node, Walk ~= nil and Walk.reached, Walk and Walk.steps or 0

    if not Reached and (not Walk or Options.Bridge ~= false and Blocks > 0) then
        local Ratio: number = (Context.StepCost + Context.PlaceCost) / Context.StepCost
        local Stages = {{"Bridge", Options.BridgeWeight}, {"Greedy", Ratio + 0.5}, {"Greedy", Ratio + 3}}
        if Options.Fallback then
            table.insert(Stages, 2, {"Bridge", Options.Fallback})
        end
        for _, v: {string | number} in Stages do
            if Request and Request.Cancelled or v[1] == "Greedy" and (Options.Bridge == false or Blocks <= 0 or Node and Heuristic(Context, Node.x, Node.y, Node.z, Goal.x, Goal.y, Goal.z) <= Options.Tolerance * Context.StepCost) then
                break
            end

            local Pack = Search(Context, Blocks, From, Goal, v[2], Options, Request, v[1], Walk)
            Steps += Pack.steps

            if Pack.node and (not Node or Heuristic(Context, Pack.node.x, Pack.node.y, Pack.node.z, Goal.x, Goal.y, Goal.z) < Heuristic(Context, Node.x, Node.y, Node.z, Goal.x, Goal.y, Goal.z)) then
                Node = Pack.node
            end

            if Pack.reached then
                Node, Reached = Pack.node, true
                break
            end
        end
    end

    if Request and Request.Cancelled or not Reached and Node and Node.mt == "Start" then
        return nil, false, Steps
    end

    return Node, Reached, Steps
end

local RequestClass = {}
RequestClass.__index = RequestClass

function RequestClass.Cancel(self)
    self.Cancelled = true
end

function RequestClass.Await(self)
    while not self.Done and not self.Cancelled do
        task.wait()
    end
    return self.Result
end

function RequestClass.OnComplete(self, Callback)
    if self.Done then
        Callback(self.Result)
    else
        table.insert(self.Callbacks, Callback)
    end
end

local function Dispatch(self, Channel: string, Worker)
    local Request = setmetatable({Cancelled = false, Done = false, Result = nil, Callbacks = {}, Channel = Channel}, RequestClass)
    local Previous = self.Requests[Channel]
    if Previous then
        Previous.Cancelled = true
    end
    self.Requests[Channel] = Request

    task.spawn(function()
        local Result = Worker(Request)
        if Request.Cancelled then
            return
        end

        Request.Result = Result
        Request.Done = true
        if self.Requests[Channel] == Request then
            self.Requests[Channel] = nil
        end

        for _, v: (...any) -> ...any in Request.Callbacks do
            task.spawn(v, Result)
        end
    end)

    return Request
end

local PlanClass = {}
PlanClass.__index = PlanClass

local function SegmentDistance(A: Vector3, B: Vector3, Point: Vector3)
    local Segment: Vector3 = B - A
    local Length: number = Segment:Dot(Segment)
    local Raw: number = Length > 0 and (Point - A):Dot(Segment) / Length or 1
    local T: number = math.clamp(Raw, 0, 1)
    return (A + Segment * T - Point).Magnitude, T, Raw
end

local function Corridor(Context, Y: number, StartX: number, StartZ: number, EndX: number, EndZ: number, Depends): boolean
    local DeltaX, DeltaZ = EndX - StartX, EndZ - StartZ
    local Length: number = math.sqrt(DeltaX * DeltaX + DeltaZ * DeltaZ)
    if Length == 0 then
        return true
    end

    local Radius: number = Context.Agent.Radius / CellSize
    local Samples: number = math.ceil(Length * 2)
    for Sample: number = 1, Samples do
        local PointX, PointZ = StartX + DeltaX * Sample / Samples, StartZ + DeltaZ * Sample / Samples
        local CellX, CellZ = math.round(PointX), math.round(PointZ)
        if (CellX ~= StartX or CellZ ~= StartZ) and (not Stands(Context, CellX, Y, CellZ) or Context.Avoid and Context.Avoid[CellKey(CellX, Y, CellZ)]) then
            return false
        end
        for _, v: {number} in Footprint do
            if not Fits(Context, math.round(PointX + v[1] * Radius), Y, math.round(PointZ + v[2] * Radius)) then
                return false
            end
        end
        if Depends then
            for Offset: number = -1, Context.Height - 1 do
                Depends[CellKey(CellX, Y + Offset, CellZ)] = true
            end
        end
    end

    return true
end

local function WaypointsOf(Actions, Level: number?)
    local Points, Blocks = {}, nil

    for _, v: any in Actions do
        if v.Type == "PlaceBlock" then
            Blocks = Blocks or {}
            table.insert(Blocks, v)
        elseif v.Grid then
            table.insert(Points, {
                Type = v.Type == "Walk" and Level and v.Grid.Y > Level and "Jump" or v.Type,
                Grid = v.Grid,
                Position = v.Position,
                Center = v.Grid * CellSize,
                Blocks = Blocks,
                Gap = v.Gap,
                Rise = v.Rise,
                AirTime = v.AirTime,
                From = v.From,
                Duration = v.Duration,
                Damage = v.Damage,
                Cost = v.Cost
            })
            Blocks, Level = nil, v.Grid.Y
        elseif v.Position then
            table.insert(Points, {Type = v.Type or "Walk", Position = v.Position, Center = v.Position, Blocks = Blocks})
            Blocks = nil
        end
    end

    if Blocks then
        local Last = Points[#Points]
        local Position = Last and Last.Position or Blocks[#Blocks].ExpectedPosition or Blocks[#Blocks].Position
        table.insert(Points, {Type = "Wait", Position = Position, Center = Position, Blocks = Blocks})
    end

    return Points
end

local function Plain(Point, Y: number): boolean
    return Point.Type == "Walk" and Point.Grid ~= nil and Point.Blocks == nil and Point.AirTime == nil and Point.Grid.Y == Y
end

local function Refine(Context, Actions, Start: Vector3, Settings, Depends)
    local Points = WaypointsOf(Actions, Start.Y)
    local Limit: number = math.max((Settings.Segment or 12) / CellSize, 1)
    local Refined = {}
    local Anchor, AnchorCost = Start, 0
    local Index: number = 1

    while Index <= #Points do
        local Point = Points[Index]
        local Reach: number = Index

        if Anchor and Plain(Point, Anchor.Y) then
            for Ahead: number = Index + 1, #Points do
                local Candidate = Points[Ahead]
                if not Plain(Candidate, Anchor.Y) or not Corridor(Context, Anchor.Y, Anchor.X, Anchor.Z, Candidate.Grid.X, Candidate.Grid.Z) then
                    break
                end
                Reach = Ahead
            end
        end

        if Reach > Index then
            local Target = Points[Reach]
            local DeltaX, DeltaZ = Target.Grid.X - Anchor.X, Target.Grid.Z - Anchor.Z
            local Pieces: number = math.max(math.ceil(math.sqrt(DeltaX * DeltaX + DeltaZ * DeltaZ) / Limit), 1)
            local Duration, Cost = 0, Target.Cost or AnchorCost
            Corridor(Context, Anchor.Y, Anchor.X, Anchor.Z, Target.Grid.X, Target.Grid.Z, Depends)

            for Step: number = Index, Reach do
                Duration += Points[Step].Duration or 0
            end

            for Piece: number = 1, Pieces - 1 do
                local PieceX, PieceZ = Anchor.X + DeltaX * Piece / Pieces, Anchor.Z + DeltaZ * Piece / Pieces
                table.insert(Refined, {
                    Type = "Walk",
                    Grid = Vector3.new(math.round(PieceX), Anchor.Y, math.round(PieceZ)),
                    Position = StandPosition(Context.Agent, PieceX, Anchor.Y, PieceZ),
                    Center = Vector3.new(PieceX * CellSize, Anchor.Y * CellSize, PieceZ * CellSize),
                    Duration = Duration / Pieces,
                    Cost = AnchorCost + (Cost - AnchorCost) * Piece / Pieces,
                    Merged = true
                })
            end

            Target.Duration, Target.Merged, Target.From = Duration / Pieces, true, Anchor
            table.insert(Refined, Target)
            Index = Reach + 1
        else
            table.insert(Refined, Point)
            Index += 1
        end

        Anchor, AnchorCost = Refined[#Refined].Grid, Refined[#Refined].Cost or AnchorCost
    end

    return Refined
end

function Navigation.newPlan(Result, Options)
    Options = Options or {}

    local Points = Result.Waypoints or WaypointsOf(Result.Actions or {})
    return setmetatable({
        Revision = 0,
        Kind = Options.Kind or "Path",
        TargetId = Options.TargetId,
        Target = Options.Target,
        Created = Options.Now or os.clock(),
        Result = Result,
        Waypoints = Points,
        Cursor = 1,
        Origin = Options.Origin or (Points[1] and Points[1].Position),
        Cost = Result.Cost or 0,
        Blocks = Result.BlocksUsed or 0,
        World = Options.World or Result.World,
        Checked = Result.DirtyIndex or 0,
        Flush = Result.Flush,
        Expired = false
    }, PlanClass)
end

function PlanClass.Point(self)
    return self.Waypoints[self.Cursor]
end

function PlanClass.Solid(self, Grid: Vector3?): boolean
    return self.World ~= nil and Grid ~= nil and self.World:Solid(Grid.X, Grid.Y, Grid.Z)
end

function PlanClass.Placed(self, Point): boolean
    if not Point.Blocks then
        return true
    end

    for _, v: any in Point.Blocks do
        if not self:Solid(v.Grid) then
            return false
        end
    end

    return true
end

function PlanClass.Stale(self): boolean
    if self.Dirty then
        return true
    end

    local World, Result = self.World, self.Result
    if not World or not Result.Depends then
        return false
    end
    if World.Flush ~= self.Flush then
        self.Dirty = true
        return true
    end

    for i: number = self.Checked + 1, World.DirtyIndex do
        local Key: number = World.Dirty[i]
        if Result.Depends[Key] and not (Result.Planned and Result.Planned[Key]) then
            self.Dirty = true
            return true
        end
    end

    self.Checked = World.DirtyIndex
    return false
end

function PlanClass.Resume(self, Position: Vector3, Velocity: Vector3?, Airborne: boolean?)
    local Points = self.Waypoints
    if #Points == 0 then
        self.Cursor = 1
        return 1, 0
    end

    local Flat = Velocity and Velocity * Vector3.new(1, 0, 1)
    local Heading: Vector3? = Airborne and Flat and Flat.Magnitude > 4 and Flat.Unit or nil
    local Previous: Vector3 = self.Origin or Points[1].Position
    local Best, Score = 1, math.huge

    for i: number, v: any in Points do
        local Distance: number = SegmentDistance(Previous, v.Position, Position)
        if Heading then
            local Ahead: Vector3 = (v.Position - Position) * Vector3.new(1, 0, 1)
            if Ahead.Magnitude > 1 and Ahead.Unit:Dot(Heading) < -0.2 then
                Distance += Ahead.Magnitude
            end
        end
        if Distance <= Score then
            Best, Score = i, Distance
        end
        if not self:Placed(v) then
            break
        end
        Previous = v.Position
    end

    self.Cursor = Best
    return Best, Score
end

function PlanClass.Remaining(self): number
    local Points = self.Waypoints
    local Last, Before = Points[#Points], Points[self.Cursor - 1]
    if not Last or self.Cursor > #Points then
        return 0
    end
    if Last.Cost then
        return math.max(Last.Cost - (Before and Before.Cost or 0), 0)
    end
    return self.Cost * (#Points - self.Cursor + 1) / #Points
end

function PlanClass.Left(self, Position: Vector3?): number
    local Total, Previous = 0, Position
    for i: number = self.Cursor, #self.Waypoints do
        local Point: Vector3 = self.Waypoints[i].Position
        if Previous then
            Total += (Point - Previous).Magnitude
        end
        Previous = Point
    end
    return Total
end

function PlanClass.Pending(self): number
    local Count: number = 0
    for i: number = self.Cursor, #self.Waypoints do
        local Blocks = self.Waypoints[i].Blocks
        if Blocks then
            for _, v: any in Blocks do
                if not self:Solid(v.Grid) then
                    Count += 1
                end
            end
        end
    end
    return Count
end

function PlanClass.NextBlock(self, Index: number?)
    for Cursor: number = Index or self.Cursor, #self.Waypoints do
        local Blocks = self.Waypoints[Cursor].Blocks
        if Blocks then
            for _, v: any in Blocks do
                if not self:Solid(v.Grid) then
                    return v, Cursor
                end
            end
        end
    end
    return nil
end

function PlanClass.Profile(self, Position: Vector3?)
    local Land = self.World and self.World.Land
    local Profile = {Length = 0, Blocks = self:Pending(), Gaps = 0, Air = 0, Void = 0, Rise = 0, Turns = 0, Partial = self.Result.Partial == true}
    local Previous, Heading = Position or self.Origin, nil

    for i: number = self.Cursor, #self.Waypoints do
        local Point = self.Waypoints[i]
        local Step: Vector3 = Previous and Point.Position - Previous or Vector3.zero
        local Flat: Vector3 = Step * Vector3.new(1, 0, 1)
        local Grid: Vector3 = Point.Grid or Navigation.WorldToGrid(Point.Position)
        Profile.Length += Step.Magnitude
        Profile.Rise += math.max(Step.Y, 0)
        if Point.AirTime then
            Profile.Gaps += 1
            Profile.Air = math.max(Profile.Air, Point.AirTime)
        end
        if Point.Blocks or Point.AirTime or Point.Ground == false or Land and not Land[CellKey(Grid.X, 0, Grid.Z)] then
            Profile.Void += Flat.Magnitude
        end
        if Flat.Magnitude > 0.1 then
            Profile.Turns += Heading and Heading:Dot(Flat.Unit) < 0.5 and 1 or 0
            Heading = Flat.Unit
        end
        Previous = Point.Position
    end

    return Profile
end

function PlanClass.Deviation(self, Other): number
    local Mine, Theirs = self.Waypoints, Other.Waypoints
    if #Mine == 0 or #Theirs == 0 or self.Cursor > #Mine then
        return math.huge
    end

    local Worst: number = (Mine[#Mine].Position - Theirs[#Theirs].Position).Magnitude
    for i: number = Other.Cursor, math.min(Other.Cursor + 5, #Theirs) do
        local Point, Nearest = Theirs[i].Position, math.huge
        local Previous = Mine[self.Cursor - 1] and Mine[self.Cursor - 1].Position or self.Origin or Mine[1].Position
        for Cursor: number = self.Cursor, #Mine do
            Nearest = math.min(Nearest, (SegmentDistance(Previous, Mine[Cursor].Position, Point)))
            Previous = Mine[Cursor].Position
        end
        Worst = math.max(Worst, Nearest)
    end

    return Worst
end

function Navigation.SetWorld(self, World)
    self.World = World
    table.clear(self.Contexts)
end

function Navigation.FindPath(self, From, Goal, Options, Request)
    local Started: number = os.clock()
    Options = Options or {}

    local World = Options.World or self.World
    local Mode: string = Options.Mode or "Legit"
    local Agent = Merge(self.Config.Agent, Options.Agent)
    local Costs = Merge(self.Config.Costs, Options.Costs)
    local Settings = Merge(self.Config.Search, Options.Search)

    if Options.BlocksAvailable then
        Agent.BlocksAvailable = Options.BlocksAvailable
    end
    if Options.Reach then
        Agent.Reach = Options.Reach
    end
    if Options.Budget then
        Settings.Budget = Options.Budget
    end
    if Options.Yield ~= nil then
        Settings.Yield = Options.Yield
    end
    Settings.BlocksAvailable = Agent.BlocksAvailable
    Settings.Debug = Options.Debug

    local Context = ContextFor(self, World, Agent, Costs, Mode, Options)
    local State = BuildState(From, Agent, World)
    local Target, Override = ResolveTarget(Goal)
    local Revision, Dirty, Flush = World.Revision, World.DirtyIndex, World.Flush

    if Options.TargetVelocity then
        Target += Options.TargetVelocity * math.min((Target - State.Position).Magnitude / Agent.WalkSpeed, Options.MaxLead or 1.5)
    end

    local GoalCell: Vector3 = Override or Vector3.new(GridAxis(Target.X), GridAxis(Target.Y - Agent.HipHeight + HalfCell), GridAxis(Target.Z))
    local StartX, StartY, StartZ = Standable(Context, State.CellX, State.CellY, State.CellZ, math.ceil(Agent.MaxDrop / CellSize))
    local GoalX, GoalY, GoalZ = Standable(Context, GoalCell.X, GoalCell.Y, GoalCell.Z, Settings.GoalDrop)
    local Node, Reached, Steps = Route(Context, State.Blocks, {x = StartX, y = StartY, z = StartZ}, {x = GoalX, y = GoalY, z = GoalZ}, Settings, Request)

    if not Node then
        return {
            Success = false,
            Partial = false,
            Reason = Request and Request.Cancelled and "Cancelled" or "NoPath",
            Mode = Mode,
            WalkingPath = {},
            BridgePath = {},
            Actions = {},
            Cost = 0,
            Distance = 0,
            BlocksUsed = 0,
            Damage = 0,
            Steps = Steps,
            Elapsed = os.clock() - Started
        }
    end

    local Plan = Compile(Context, Node, Settings)
    local Waypoints = Refine(Context, Plan.Actions, Vector3.new(StartX, StartY, StartZ), Settings, Plan.Depends)
    local Continuous: boolean = true
    for _, v: any in Plan.BridgePath do
        if v.Lead <= 0 then
            Continuous = false
        end
    end

    return {
        Success = Reached and Plan.Failure == nil,
        Continuous = Continuous,
        Partial = not Reached or Plan.Failure ~= nil,
        Reason = Plan.Failure and Plan.Failure.Reason or (Reached and "Reached" or "Budget"),
        Mode = Mode,
        WalkingPath = Plan.WalkingPath,
        BridgePath = Plan.BridgePath,
        Actions = Plan.Actions,
        Waypoints = Waypoints,
        Cost = Node.g,
        Distance = (StandPosition(Agent, Node.x, Node.y, Node.z) - State.Position).Magnitude,
        Duration = Plan.Duration,
        BlocksUsed = Plan.Blocks,
        Damage = Plan.Damage,
        Start = Vector3.new(StartX, StartY, StartZ),
        Goal = Vector3.new(GoalX, GoalY, GoalZ),
        Steps = Steps,
        Elapsed = os.clock() - Started,
        World = World,
        Revision = Revision,
        DirtyIndex = Dirty,
        Flush = Flush,
        Depends = Plan.Depends,
        Planned = Plan.Planned,
        Decisions = Plan.Decisions,
        Failure = Plan.Failure
    }
end

function Navigation.EvaluateGap(self, Horizontal: number, Vertical: number, Options)
    Options = Options or {}

    local Agent = Merge(self.Config.Agent, Options.Agent)
    local Traversal = Merge(self.Config.Traversal, Options.Traversal)
    local Crossable, AirTime, Reach, Reason = Traverse(Agent, Traversal, Horizontal, Vertical, Options.Speed or Agent.WalkSpeed)
    return {
        Crossable = Crossable,
        AirTime = AirTime,
        MaxAirTime = Traversal.MaxAirTime,
        HorizontalDistance = Horizontal,
        VerticalDistance = Vertical,
        Reach = Reach,
        Confidence = Crossable and math.clamp((Reach - Horizontal) / CellSize, 0, 1) or 0,
        Reason = Reason
    }
end

function Navigation.FindPathAsync(self, From, Goal, Options)
    Options = Options or {}
    return Dispatch(self, Options.Channel or "default", function(Request)
        return self:FindPath(From, Goal, Options, Request)
    end)
end

function Navigation.GetBlockCosts(self, From, Goals, Options)
    Options = Options or {}

    local World = Options.World or self.World
    local Settings = Merge(self.Config.Search, Options.Search)
    if Options.Yield ~= nil then
        Settings.Yield = Options.Yield
    end

    local Position: Vector3 = typeof(From) == "Vector3" and From or From.Position
    local Origin = {x = GridAxis(Position.X), y = GridAxis(Position.Y - self.Config.Agent.HipHeight + HalfCell), z = GridAxis(Position.Z)}
    local Field, _, Box = World:Field(Origin, Origin, Settings.FieldMargin, Options.Mode or "Legit", Settings.Yield and task and Settings.Budget)
    local Costs = {}

    for Key: any, v: any in Goals do
        local Target: Vector3 = ResolveTarget(v)
        local X, Z = GridAxis(Target.X), GridAxis(Target.Z)
        Costs[Key] = Field and (Field[CellKey(X, 0, Z)] or math.max(Box[1] - X, X - Box[2], Box[3] - Z, Z - Box[4])) or 0
    end

    return Costs
end

function Navigation.FindRetreat(self, From, Threats: {Vector3}, Options, Request)
    local Started: number = os.clock()
    Options = Options or {}

    local World = Options.World or self.World
    local Mode: string = Options.Mode or "Legit"
    local Agent = Merge(self.Config.Agent, Options.Agent)
    local Settings = Merge(self.Config.Search, Options.Search)
    local Config = Merge(self.Config.Retreat, Options.Retreat)
    local Weights = Config.Weights

    if Options.Budget then
        Settings.Budget = Options.Budget
    end
    if Options.Yield ~= nil then
        Settings.Yield = Options.Yield
    end
    Settings.BlocksAvailable = 0
    Settings.Debug = Options.Debug

    local Context = ContextFor(self, World, Agent, Merge(self.Config.Costs, Options.Costs), Mode, Options)
    local State = BuildState(From, Agent, World)
    local Revision, Dirty, Flush = World.Revision, World.DirtyIndex, World.Flush
    local StartX, StartY, StartZ = Standable(Context, State.CellX, State.CellY, State.CellZ, math.ceil(Agent.MaxDrop / CellSize))
    local Pack = {ctx = Context, heap = {}, nodes = {}, closed = {}, weight = 0, gx = StartX, gy = StartY, gz = StartZ, limit = 0, bridge = false, tower = false, gap = Settings.JumpGap ~= false, avoid = Context.Avoid, reached = false, steps = 0}
    local Start = {x = StartX, y = StartY, z = StartZ, g = 0, b = 0, mt = "Start", dmg = 0, f = 0}
    local Best, Score, Nearest = nil, -math.huge, math.huge
    local Slice: number = os.clock() + Settings.Budget

    if Pack.gap then
        World:Columns(Settings.Yield and task and Settings.Budget)
    end
    Pack.nodes[CellKey(StartX, StartY, StartZ)] = Start
    HeapPush(Pack.heap, Start)

    while #Pack.heap > 0 and Pack.steps < Config.MaxSteps do
        Pack.steps += 1

        if os.clock() >= Slice then
            if Request and Request.Cancelled then
                break
            end
            if Settings.Yield and task then
                task.wait()
            end
            Slice = os.clock() + Settings.Budget
        end

        local Node = HeapPop(Pack.heap)
        local Key: number = CellKey(Node.x, Node.y, Node.z)
        if Pack.closed[Key] then
            continue
        end
        Pack.closed[Key] = true
        if Node.g > Config.MaxTime then
            break
        end

        local Position: Vector3 = StandPosition(Agent, Node.x, Node.y, Node.z)
        local Closest: number = math.huge
        for _, v: Vector3 in Threats do
            Closest = math.min(Closest, (v - Position).Magnitude)
        end
        Node.near = math.min(Node.pr and Node.pr.near or Closest, Closest)

        local Openings, Edges = 0, 0
        for _, v: {number} in Flats do
            if Stands(Context, Node.x + v[1], Node.y, Node.z + v[3]) then
                Openings += 1
            elseif not Context.World:Solid(Node.x + v[1], Node.y - 1, Node.z + v[3]) and not DropTo(Context, Node.x + v[1], Node.y, Node.z + v[3]) then
                Edges += 1
            end
        end

        local Value: number = Weights.Distance * math.min(Closest, Config.SafeDistance) / Config.SafeDistance + Weights.Passage * math.min(Node.near, Config.SafeDistance / 2) / (Config.SafeDistance / 2) + Weights.Escape * Openings / #Flats - Weights.Edge * Edges / #Flats - Weights.Time * Node.g
        if Value > Score then
            local Exposed: number = 0
            for _, v: Vector3 in Threats do
                if (v - Position).Magnitude < Config.SafeDistance * 1.5 and TraceClear(Context, v + Vector3.new(0, Agent.HeadOffset, 0), Position + Vector3.new(0, Agent.HeadOffset, 0)) then
                    Exposed += 1
                end
            end
            Value -= #Threats > 0 and Weights.Exposure * Exposed / #Threats or 0
            if Value > Score then
                Best, Score, Nearest = Node, Value, Closest
            end
        end

        Expand(Pack, Node)
    end

    if not Best or Request and Request.Cancelled then
        return {
            Success = false,
            Partial = false,
            Reason = Request and Request.Cancelled and "Cancelled" or "NoPath",
            Mode = Mode,
            WalkingPath = {},
            BridgePath = {},
            Actions = {},
            Cost = 0,
            Distance = 0,
            BlocksUsed = 0,
            Damage = 0,
            Steps = Pack.steps,
            Elapsed = os.clock() - Started
        }
    end

    local Plan = Compile(Context, Best, Settings)
    return {
        Success = Plan.Failure == nil,
        Partial = Plan.Failure ~= nil,
        Reason = Plan.Failure and Plan.Failure.Reason or "Retreat",
        Mode = Mode,
        WalkingPath = Plan.WalkingPath,
        BridgePath = Plan.BridgePath,
        Actions = Plan.Actions,
        Waypoints = Refine(Context, Plan.Actions, Vector3.new(StartX, StartY, StartZ), Settings, Plan.Depends),
        Cost = Best.g,
        Score = Score,
        Nearest = Nearest,
        Distance = (StandPosition(Agent, Best.x, Best.y, Best.z) - State.Position).Magnitude,
        Duration = Plan.Duration,
        BlocksUsed = Plan.Blocks,
        Damage = Plan.Damage,
        Start = Vector3.new(StartX, StartY, StartZ),
        Goal = Vector3.new(Best.x, Best.y, Best.z),
        Steps = Pack.steps,
        Elapsed = os.clock() - Started,
        World = World,
        Revision = Revision,
        DirtyIndex = Dirty,
        Flush = Flush,
        Depends = Plan.Depends,
        Planned = Plan.Planned,
        Decisions = Plan.Decisions,
        Failure = Plan.Failure
    }
end

function Navigation.FindClutch(self, From, Options)
    local Started: number = os.clock()
    Options = Options or {}

    local World = Options.World or self.World
    local Mode: string = Options.Mode or "Legit"
    local Agent = Merge(self.Config.Agent, Options.Agent)
    local Costs = Merge(self.Config.Costs, Options.Costs)
    local Config = Merge(self.Config.Clutch, Options.Clutch)

    if Options.BlocksAvailable then
        Agent.BlocksAvailable = Options.BlocksAvailable
        Config.MaxBlocks = math.min(Config.MaxBlocks, Options.BlocksAvailable)
    end
    if Options.DamageAllowance then
        Agent.DamageAllowance = Options.DamageAllowance
    end

    local Context = ContextFor(self, World, Agent, Costs, Mode, Options)
    Context.Reach = Options.Reach or Config.Reach
    Context.Floating = Config.Anchored == false

    local State = BuildState(From, Agent, World)
    local Plan = ClutchPlan(Context, State, Agent, Config, Options)

    if not Plan.Best then
        return {
            Success = false,
            Partial = false,
            Reason = Plan.Reason,
            Mode = Mode,
            Actions = {},
            BridgePath = {},
            WalkingPath = {},
            BlocksUsed = 0,
            Damage = Plan.Landing and Plan.Landing.Damage or 0,
            TimeToImpact = Plan.Landing and Plan.Landing.Time or math.huge,
            Survival = Plan.Reason == "Safe" and 1 or 0,
            Elapsed = os.clock() - Started
        }
    end

    local Best = Plan.Best
    local Placements = Best.Chain or {Best.Placement}
    local Interval: number = 1 / Agent.PlaceCps
    local Elapsed: number = math.max(Best.Time - (#Placements - 1) * Interval, 0)
    local Actions = {}

    for _, v: any in Placements do
        v.Type = "PlaceBlock"
        v.Time = Elapsed
        v.Duration = Interval
        v.ExpectedPosition = ArcPosition(State, Agent, Elapsed)
        v.Preconditions = {
            MaxDistance = Context.Reach,
            RequiredSupport = v.SupportGrid,
            RequiredMode = Mode,
            Airborne = true
        }
        table.insert(Actions, v)
        Elapsed += Interval
    end

    local _, _, ImpactTime = FallLine(State, Agent, Best.Grid.Y * CellSize + HalfCell)
    table.insert(Actions, {
        Type = "Land",
        Grid = Best.Grid,
        Position = StandPosition(Agent, Best.Grid.X, Best.Grid.Y + 1, Best.Grid.Z),
        Time = ImpactTime or Best.Time,
        Duration = 0,
        Damage = Best.Damage
    })

    return {
        Success = true,
        Partial = Plan.Partial == true,
        Reason = Best.Type,
        Mode = Mode,
        ClutchType = Best.Type,
        Actions = Actions,
        BridgePath = Placements,
        WalkingPath = {},
        BlocksUsed = Best.Blocks,
        Damage = Best.Damage,
        Impact = Best.Impact,
        Drift = Best.Drift,
        Survival = Best.Survival,
        Score = Best.Score,
        Grid = Best.Grid,
        TimeToImpact = Plan.Landing and Plan.Landing.Time or math.huge,
        Elapsed = os.clock() - Started,
        World = World,
        Revision = World.Revision,
        DirtyIndex = World.DirtyIndex,
        Flush = World.Flush,
        Depends = {[CellKey(Best.Grid.X, Best.Grid.Y, Best.Grid.Z)] = true}
    }
end

function Navigation.FindClutchAsync(self, From, Options)
    Options = Options or {}
    return Dispatch(self, Options.Channel or "clutch", function()
        return self:FindClutch(From, Options)
    end)
end

function Navigation.SolvePlacement(self, From, Grid: Vector3, Options)
    Options = Options or {}

    local World = Options.World or self.World
    local Mode: string = Options.Mode or "Legit"
    local Agent = Merge(self.Config.Agent, Options.Agent)
    local Context = ContextFor(self, World, Agent, Merge(self.Config.Costs, Options.Costs), Mode, Options)
    local Placement, Reason = PlacementAt(Context, BuildState(From, Agent, World), Grid.X, Grid.Y, Grid.Z, Mode, nil, Options.Quick)

    if Placement then
        return Placement
    end

    return {
        Grid = Grid,
        Position = Vector3.new(Grid.X * CellSize, Grid.Y * CellSize, Grid.Z * CellSize),
        Mode = Mode,
        PlacementType = "None",
        Distance = (Vector3.new(Grid.X * CellSize, Grid.Y * CellSize, Grid.Z * CellSize) - (From.Position or From)).Magnitude,
        Valid = false,
        Reason = Reason
    }
end

function Navigation.SolveVoid(self, From, Options)
    Options = Options or {}

    local World = Options.World or self.World
    local Mode: string = Options.Mode or "Legit"
    local Agent = Merge(self.Config.Agent, Options.Agent)
    local Context = ContextFor(self, World, Agent, Merge(self.Config.Costs, Options.Costs), Mode, Options)
    local State = BuildState(From, Agent, World)
    local Aim: Vector3 = State.Aim or (State.Velocity.Magnitude > 1 and Vector3.new(State.Velocity.X, 0, State.Velocity.Z).Unit or Vector3.new(0, -1, 0))

    for Depth: number = 1, 3 do
        local Level: number = GridAxis(State.Position.Y - Depth * CellSize)
        if World:Block(State.CellX, Level, State.CellZ) then
            local Plane: number = Level * CellSize + HalfCell
            local Drop: number = State.Eye.Y - Plane
            local Span: number = Aim.Y < -0.05 and Drop / -Aim.Y or math.huge
            local X, Z = State.CellX, State.CellZ

            if Span < math.huge then
                X, Z = GridAxis(State.Eye.X + Aim.X * Span), GridAxis(State.Eye.Z + Aim.Z * Span)
            end

            local DeltaX, DeltaZ = X - State.CellX, Z - State.CellZ
            local Steps: number = math.max(math.abs(DeltaX), math.abs(DeltaZ))
            for Step: number = 0, Steps do
                local CellX: number = State.CellX + (Steps > 0 and math.round(DeltaX * Step / Steps) or 0)
                local CellZ: number = State.CellZ + (Steps > 0 and math.round(DeltaZ * Step / Steps) or 0)
                if not World:Solid(CellX, Level, CellZ) then
                    local Placement = PlacementAt(Context, State, CellX, Level, CellZ, Mode, nil, Options.Quick)
                    if Placement then
                        Placement.PlacementType = Placement.PlacementType == "Face" and "Plane" or Placement.PlacementType
                        return Placement
                    end
                    break
                end
            end
        end
    end

    local SaveX, SaveY, SaveZ = VoidSave(Context, State)
    if SaveX then
        local Placement = PlacementAt(Context, State, SaveX, SaveY, SaveZ, Mode, nil, Options.Quick)
        if Placement then
            Placement.PlacementType = "Void"
            return Placement
        end
    end

    return nil
end

function Navigation.ValidatePath(self, Result, Options)
    Options = Options or {}

    local World = Options.World or Result.World or self.World
    local Agent = Merge(self.Config.Agent, Options.Agent)
    local Mode: string = Result.Mode or "Legit"
    local Context = ContextFor(self, World, Agent, Merge(self.Config.Costs, Options.Costs), Mode, Options)
    local Blocks: number = Options.BlocksAvailable or Agent.BlocksAvailable
    local Used: number = 0

    Context.World:Begin()

    for i: number, v: any in Result.Actions do
        if v.Type == "PlaceBlock" then
            Used += 1
            if Used > Blocks then
                Context.World:Finish()
                return false, "Inventory", i
            end

            local Placement, Reason = PlacementAt(Context, BuildState({Position = v.ExpectedPosition}, Agent), v.Grid.X, v.Grid.Y, v.Grid.Z, Mode, nil, Options.Quick)
            if not Placement then
                Context.World:Finish()
                table.clear(Context.Fits)
                table.clear(Context.Stands)
                return false, Reason, i
            end

            WriteCell(Context, v.Grid.X, v.Grid.Y, v.Grid.Z, Placement)
        elseif v.Type ~= "Land" and v.Type ~= "Wait" and not Stands(Context, v.Grid.X, v.Grid.Y, v.Grid.Z) then
            Context.World:Finish()
            table.clear(Context.Fits)
            table.clear(Context.Stands)
            return false, "Support", i
        end
    end

    Context.World:Finish()
    table.clear(Context.Fits)
    table.clear(Context.Stands)
    return true, "Valid", #Result.Actions
end

function Navigation.GetState(self, From, Options)
    Options = Options or {}

    local World = Options.World or self.World
    local Agent = Merge(self.Config.Agent, Options.Agent)
    local Config = Merge(self.Config.Clutch, Options.Clutch)
    local Context = ContextFor(self, World, Agent, Merge(self.Config.Costs, Options.Costs), Options.Mode or "Legit", Options)
    local State = BuildState(From, Agent, World)
    local Landing = LandingOf(Context, State, Agent, Config)

    if State.Grounded and State.Velocity.Y >= 0 then
        return "Normal", Landing
    end
    if not Landing then
        return "Falling", nil
    end
    if Landing.Damage > Agent.DamageAllowance then
        return State.Velocity.Y < -Agent.JumpVelocity and "Falling" or "Danger", Landing
    end

    return "Normal", Landing
end

function Navigation.IsStale(self, Result): boolean
    local World = Result.World or self.World
    if not World or World.Revision == Result.Revision then
        return false
    end
    if World.Flush ~= Result.Flush then
        return true
    end

    for i: number = Result.DirtyIndex + 1, World.DirtyIndex do
        local Key: number = World.Dirty[i]
        if Result.Depends[Key] and not (Result.Planned and Result.Planned[Key]) then
            return true
        end
    end

    return false
end

local function SurfaceKey(Position: Vector3): number
    return (math.round(Position.X) * 131071 + math.round(Position.Y)) * 131071 + math.round(Position.Z)
end

local function GearOf(ItemMeta, Inventory)
    local Sword, Armor = 0, {}

    for _, v: any in {Inventory.items, Inventory.armor} do
        for _, Stack: any in v or {} do
            local Meta = ItemMeta[type(Stack) == "table" and Stack.itemType or Stack]
            if Meta and Meta.sword then
                Sword = math.max(Sword, Meta.sword.damage or 0)
            end
            if Meta and Meta.armor then
                Armor[Meta.armor.slot] = math.max(Armor[Meta.armor.slot] or 0, Meta.armor.damageReductionMultiplier or 0)
            end
        end
    end

    return Sword, Armor
end

function Navigation.newObserver(Context, Config)
    local Observer = {}
    local Params: RaycastParams = RaycastParams.new()
    Params.RespectCanCollide = true
    local Overlap: OverlapParams = OverlapParams.new()
    Overlap.RespectCanCollide = true
    local Offsets: {Vector3} = {Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0), Vector3.new(0, 0, 3), Vector3.new(0, 0, -3)}
    local Lift: Vector3 = Vector3.new(0, 1, 0)
    local Planar: Vector3 = Vector3.new(1, 0, 1)
    local Excluded, Surfaces, Projectiles, Obstacles = {}, {}, {}, {}
    local Destinations, Beds, Drops = {}, {}, {}
    local Roster, RosterPool, BedList, Sites = {}, setmetatable({}, {__mode = "k"}), {}, {Generators = {}, Shops = {}, Upgrades = {}}
    local Cached, Tracked = 0, 0
    local NextScan, NextDrops, NextFilter, NextUpper, NextSites = 0, 0, 0, 0, 0
    local OwnBed, Base, LastCharacter, UpperExit, UpperOrigin

    Observer.Params, Observer.Overlap, Observer.Projectiles, Observer.Obstacles = Params, Overlap, Projectiles, Obstacles

    function Observer.Filter(Force: boolean?)
        local Now: number = os.clock()
        if not Force and Now < NextFilter then
            return
        end

        NextFilter = Now + Config.FilterInterval
        table.clear(Excluded)
        for _, v: Player in Context.Players:GetPlayers() do
            if v.Character then
                table.insert(Excluded, v.Character)
            end
        end
        if Context.PathModel then
            table.insert(Excluded, Context.PathModel)
        end
        if workspace.CurrentCamera then
            table.insert(Excluded, workspace.CurrentCamera)
        end
        Params.FilterDescendantsInstances = Excluded
        Overlap.FilterDescendantsInstances = Excluded
    end

    function Observer.Mark(Kind: string)
        if Kind == "beds" then
            NextScan = 0
        elseif Kind == "drops" then
            NextDrops = 0
        elseif Kind == "filter" then
            NextFilter = 0
        end
    end

    function Observer.Surface(Position: Vector3, Fresh: boolean?)
        local Key, Now = SurfaceKey(Position), os.clock()
        local Entry = Surfaces[Key]
        if Entry and not Fresh and Now - Entry.at < Config.SurfaceLifetime then
            return Entry
        end

        local Depth: Vector3 = Vector3.new(0, -(Context.Entity.character and Context.Entity.character.HipHeight or 3) - 2, 0)
        local Hit: RaycastResult? = workspace:Raycast(Position + Lift, Depth, Params)
        local Sides: number = 0
        if Hit and Hit.Normal.Y > 0.65 then
            for _, v: Vector3 in Offsets do
                local Side: RaycastResult? = workspace:Raycast(Position + v + Lift, Depth, Params)
                if Side and Side.Normal.Y > 0.65 and math.abs(Side.Position.Y - Hit.Position.Y) < 1 then
                    Sides += 1
                end
            end
        end

        if not Entry then
            Cached += 1
            if Cached > 512 then
                table.clear(Surfaces)
                Cached = 1
            end
        end
        Entry = {at = Now, safe = Hit ~= nil and Hit.Normal.Y > 0.65, narrow = Sides <= 2, nearVoid = Sides < 2, hit = Hit}
        Surfaces[Key] = Entry
        return Entry
    end

    function Observer.Ground(Position: Vector3)
        local Hit: RaycastResult? = workspace:Raycast(Position + Lift, Vector3.new(0, -(Context.Entity.character and Context.Entity.character.HipHeight or 3) - 2, 0), Params)
        return Hit ~= nil and Hit.Normal.Y > 0.65, Hit
    end

    function Observer.Label(Position: Vector3): boolean
        return workspace:Raycast(Position, Vector3.new(0, -4, 0), Params) ~= nil
    end

    function Observer.Footing(Entity): boolean
        return workspace:Raycast(Entity.RootPart.Position, Vector3.new(0, -70, 0), Params) ~= nil or Entity.RootPart.AssemblyLinearVelocity.Y > -10
    end

    function Observer.Drop(Root: BasePart, Humanoid: Humanoid)
        local Airborne: boolean = Humanoid.FloorMaterial == Enum.Material.Air and not workspace:Raycast(Root.Position, Vector3.new(0, -14, 0), Params)
        return Airborne, Airborne and Root.AssemblyLinearVelocity.Y < -12
    end

    function Observer.Gear(Inventory)
        if Context.Gear then
            return Context.Gear(Inventory)
        end
        return GearOf(Context.Bedwars.ItemMeta, Inventory)
    end

    function Observer.GearNeeded(Team)
        if Context.GearNeeded then
            return Context.GearNeeded(Team)
        end

        local ItemMeta = Context.Bedwars.ItemMeta
        local LocalTeam = Context.Player:GetAttribute("Team") or -1
        local NeedSword, NeedArmor = 0, {}
        for _, v: Player in Context.Players:GetPlayers() do
            local PlayerTeam = v:GetAttribute("Team")
            local Enemy = v ~= Context.Player and (Team and PlayerTeam == Team or not Team and PlayerTeam ~= LocalTeam)
            if Enemy and v.Team and v.Team.Name ~= "Spectators" and Context.Store.inventories[v] then
                local Sword, Armor = Observer.Gear(Context.Store.inventories[v])
                NeedSword = math.max(NeedSword, Sword)
                for Slot: number, Reduction: number in Armor do
                    NeedArmor[Slot] = math.max(NeedArmor[Slot] or 0, Reduction)
                end
            end
        end

        local Sword, Armor = Observer.Gear(Context.Store.inventory.inventory)
        if Sword < math.min(NeedSword, ItemMeta.stone_sword.sword.damage) then
            for _, v: string in {"wood_sword", "stone_sword"} do
                if ItemMeta[v].sword.damage > Sword then
                    return false, v
                end
            end
        end

        local Cap = ItemMeta.iron_chestplate.armor
        if (Armor[Cap.slot] or 0) < math.min(NeedArmor[Cap.slot] or 0, Cap.damageReductionMultiplier) then
            for _, v: string in {"leather_chestplate", "iron_chestplate"} do
                if ItemMeta[v].armor.damageReductionMultiplier > (Armor[Cap.slot] or 0) then
                    return false, v
                end
            end
        end

        if Sword < NeedSword or (Armor[Cap.slot] or 0) < (NeedArmor[Cap.slot] or 0) then
            if not Context.Item("wood_bow") then
                return false, "wood_bow"
            end
            if (Context.Item("arrow") or {amount = 0}).amount < 8 then
                return false, "arrow"
            end
        end

        return true
    end

    function Observer.Member(Team)
        for _, v: Player in Context.Players:GetPlayers() do
            if v:GetAttribute("Team") == Team and v.Team and v.Team.Name ~= "Spectators" then
                return v
            end
        end
        return nil
    end

    local function Occupied(Position: Vector3, Owner): boolean
        local Team = Context.Player:GetAttribute("Team") or -1
        for _, v: Player in Context.Players:GetPlayers() do
            local Root = v.Character and (v.Character:GetAttribute("Health") or 0) > 0 and v.Character:FindFirstChild("HumanoidRootPart")
            if v:GetAttribute("Team") ~= Team and v.Team and v.Team.Name ~= "Spectators" and (Root and (Root.Position - Position).Magnitude <= 30 or not Root and v:GetAttribute("Team") == Owner) then
                return true
            end
        end
        return false
    end

    function Observer.Bed(Team)
        if (Context.Store.queueType or ""):find("skywars") then
            return nil
        end

        local LocalTeam = Context.Player:GetAttribute("Team") or -1
        local Bed, Distance = nil, math.huge
        for _, v: BasePart in Context.Collection:GetTagged("bed") do
            local TeamId = v:GetAttribute("TeamId")
            if TeamId ~= LocalTeam and (not Team or TeamId == Team) and not v:GetAttribute(`Team{LocalTeam}NoBreak`) and Observer.Member(TeamId) then
                local Magnitude: number = Context.Player:DistanceFromCharacter(v.Position)
                if Magnitude < Distance then
                    Bed, Distance = v, Magnitude
                end
            end
        end
        return Bed
    end

    function Observer.Enemy(Range: number, Origin: Vector3?)
        Observer.Filter()
        for _, v: any in Context.Entity.AllPosition({Range = Range, Part = "RootPart", Players = true, Origin = Origin}) do
            if Observer.Footing(v) then
                return v
            end
        end
        return nil
    end

    function Observer.Threat(Range: number, Origin: Vector3)
        local Entity = Observer.Enemy(Range, Origin)
        if not Entity then
            return nil
        end

        local Offset: Vector3 = (Entity.RootPart.Position - Origin) * Planar
        local Away: number = Offset.Magnitude > 0 and (Entity.RootPart.AssemblyLinearVelocity * Planar):Dot(Offset.Unit) or 0
        return Entity, (Entity.RootPart.Position - Origin).Magnitude, Away
    end

    function Observer.Threats(Range: number)
        local Threats: {Vector3} = {}
        for _, v: any in Context.Entity.AllPosition({Range = Range, Part = "RootPart", Players = true}) do
            table.insert(Threats, v.RootPart.Position)
        end
        return Threats
    end

    function Observer.Targets()
        local LocalTeam = Context.Player:GetAttribute("Team") or -1
        local Targets = {}

        if not (Context.Store.queueType or ""):find("skywars") then
            for _, v: BasePart in Context.Collection:GetTagged("bed") do
                local TeamId = v:GetAttribute("TeamId")
                if TeamId and TeamId ~= LocalTeam and not v:GetAttribute(`Team{LocalTeam}NoBreak`) and Observer.Member(TeamId) then
                    table.insert(Targets, {Id = `bed:{TeamId}`, Kind = "bed", Part = v, Team = TeamId, Position = v.Position})
                end
            end
        end

        Observer.Filter()
        for _, v: any in Context.Entity.AllPosition({Range = 9e9, Part = "RootPart", Players = true}) do
            if Observer.Footing(v) then
                table.insert(Targets, {Id = v.RootPart, Kind = "player", Part = v.RootPart, Entity = v, Position = v.RootPart.Position})
            end
        end

        return Targets
    end

    function Observer.Beatable(Team)
        local Sword, Armor = Observer.Gear(Context.Store.inventory.inventory)
        local Target, Distance = nil, math.huge

        for _, v: Player in Context.Players:GetPlayers() do
            if v:GetAttribute("Team") == Team and v.Team and v.Team.Name ~= "Spectators" then
                local Character: Model? = v.Character
                local Root = Character and Character:FindFirstChild("HumanoidRootPart")
                local TheirSword, TheirArmor = Observer.Gear(Context.Store.inventories[v] or {})
                if Root and (Character:GetAttribute("Health") or 0) > 0 and not Character:FindFirstChildWhichIsA("ForceField") and TheirSword <= Sword and (TheirArmor[1] or 0) <= (Armor[1] or 0) then
                    local Magnitude: number = Context.Player:DistanceFromCharacter(Root.Position)
                    if Magnitude < Distance then
                        Target, Distance = Root, Magnitude
                    end
                end
            end
        end

        return Target, Distance
    end

    function Observer.Generator(Team, Origin: Vector3)
        local Generator, Distance = nil, math.huge
        for _, v: Instance in Context.Collection:GetTagged("Generator") do
            local Id: string = v:GetAttribute("Id") or ""
            if Id:find("generator") then
                local Magnitude: number = Team and Id == `{Team}_generator` and 0 or (Origin - v.Position).Magnitude
                if Magnitude <= Distance and not Occupied(v.Position, Id:match("^(.-)_generator")) then
                    Generator, Distance = v, Magnitude
                end
            end
        end
        return Generator
    end

    function Observer.Shop(Team, Origin: Vector3)
        local NPC, ShopId, Distance = nil, nil, math.huge
        for _, v: Instance in Context.Collection:GetTagged("BedwarsItemShop") do
            local Id: string = v:GetAttribute("Id") or ""
            local Merchant = v:FindFirstChild("desertMerchant")
            local Magnitude: number = Team and Id:find(`^{Team}_`) and 0 or (Origin - v.Position).Magnitude
            if Merchant and Magnitude < Distance and not Occupied(v.Position, Id:match("^(.-)_item_shop")) then
                NPC, ShopId, Distance = Merchant, Id, Magnitude
            end
        end
        return NPC, ShopId
    end

    function Observer.Roster()
        table.clear(Roster)
        local Team: string = tostring(Context.Player:GetAttribute("Team"))
        local ItemMeta = Context.Bedwars.ItemMeta
        for _, v: Player in Context.Players:GetPlayers() do
            if v == Context.Player or not v.Team or v.Team.Name == "Spectators" then
                continue
            end

            local Entry = RosterPool[v]
            if not Entry then
                Entry = {player = v, id = tostring(v.UserId)}
                RosterPool[v] = Entry
            end
            local Character: Model? = v.Character
            local Root = Character and Character:FindFirstChild("HumanoidRootPart")
            local Inventory = Context.Store.inventories[v]
            Entry.team = tostring(v:GetAttribute("Team"))
            Entry.enemy = Entry.team ~= Team
            Entry.health = Character and Character:GetAttribute("Health") or 0
            Entry.maxHealth = Character and Character:GetAttribute("MaxHealth") or 100
            Entry.alive = Root ~= nil and Entry.health > 0
            Entry.root = Root
            Entry.position = Root and Root.Position or nil
            Entry.velocity = Root and Root.AssemblyLinearVelocity or nil
            Entry.protected = Character ~= nil and Character:FindFirstChildOfClass("ForceField") ~= nil
            Entry.gearKnown = Inventory ~= nil
            Entry.sword, Entry.armor, Entry.ranged, Entry.emeralds, Entry.diamonds = 0, 0, false, 0, 0
            if Inventory then
                local Sword, Armor = Observer.Gear(Inventory)
                Entry.sword = Sword
                for _, Reduction: number in Armor do
                    Entry.armor += Reduction
                end
                Entry.armor = math.clamp(Entry.armor, 0, 0.9)
                for _, Stack: any in Inventory.items or {} do
                    local Meta = ItemMeta[Stack.itemType]
                    if Meta and Meta.projectileSource then
                        Entry.ranged = true
                    elseif Stack.itemType == "emerald" then
                        Entry.emeralds += Stack.amount or 1
                    elseif Stack.itemType == "diamond" then
                        Entry.diamonds += Stack.amount or 1
                    end
                end
            end
            table.insert(Roster, Entry)
        end
        return Roster
    end

    function Observer.Beds()
        table.clear(BedList)
        if (Context.Store.queueType or ""):find("skywars") then
            return BedList
        end

        local Team: string = tostring(Context.Player:GetAttribute("Team"))
        for _, v: BasePart in Context.Collection:GetTagged("bed") do
            local Owner: string = tostring(v:GetAttribute("TeamId"))
            table.insert(BedList, {team = Owner, part = v, position = v.Position, own = Owner == Team, locked = v:GetAttribute(`Team{Team}NoBreak`) and true or false, shield = v:GetAttribute("BedShieldEndTime") or 0})
        end
        return BedList
    end

    function Observer.Sites(Force: boolean?)
        local Now: number = os.clock()
        if not Force and Now < NextSites then
            return Sites
        end

        NextSites = Now + Config.ScanInterval
        table.clear(Sites.Generators)
        table.clear(Sites.Shops)
        table.clear(Sites.Upgrades)
        for _, v: Instance in Context.Collection:GetTagged("Generator") do
            local Id: string = v:GetAttribute("Id") or ""
            local Owner: string? = Id:match("^(.-)_generator$")
            local Resource: string? = Owner and "iron" or Id:match("^(diamond)_") or Id:match("^(emerald)_")
            if Resource then
                table.insert(Sites.Generators, {id = Id, target = v, position = v.Position, resource = Resource, owner = Owner})
            end
        end
        for _, v: Instance in Context.Collection:GetTagged("BedwarsItemShop") do
            local Merchant = v:FindFirstChild("desertMerchant")
            local Part = Merchant and Merchant.PrimaryPart
            if Part then
                local Id: string = v:GetAttribute("Id") or ""
                table.insert(Sites.Shops, {id = Id, shopId = Id, target = v, position = Part.Position + Part.CFrame.LookVector * 7, owner = Id:match("^(.-)_item_shop")})
            end
        end
        for _, v: Instance in Context.Collection:GetTagged("TeamUpgradeShopkeeper") do
            table.insert(Sites.Upgrades, {id = `upgrade:{tostring(v.Position)}`, target = v, position = v.Position + v.CFrame.LookVector * 5})
        end
        return Sites
    end

    function Observer.Stock(Into: {[string]: number})
        table.clear(Into)
        for _, v: Instance in Context.Collection:GetTagged("ItemDrop") do
            for _, Site: any in Sites.Generators do
                if v.Name == Site.resource and (v.Position - Site.position).Magnitude <= 10 then
                    Into[Site.id] = (Into[Site.id] or 0) + (v:GetAttribute("Amount") or 1)
                    break
                end
            end
        end
        return Into
    end

    function Observer.Cover(Position: Vector3): number
        local Grid: Vector3 = Navigation.WorldToGrid(Position)
        local Count: number = 0
        for X: number = -1, 1 do
            for Y: number = 0, 1 do
                for Z: number = -1, 1 do
                    if X ~= 0 or Y ~= 0 or Z ~= 0 then
                        local Block = Context.PlacedBlock((Grid + Vector3.new(X, Y, Z)) * CellSize)
                        if Block and Block.Name ~= "bed" then
                            Count += 1
                        end
                    end
                end
            end
        end
        return Count
    end

    function Observer.Track(Event)
        local Shooter = Event.shooter and Context.Players:GetPlayerFromCharacter(Event.shooter)
        if not Shooter or Shooter == Context.Player or Shooter:GetAttribute("Team") == Context.Player:GetAttribute("Team") or typeof(Event.origin) ~= "Vector3" or typeof(Event.launchVelocity) ~= "Vector3" then
            return
        end

        local Now: number = workspace:GetServerTimeNow()
        if Tracked >= 64 then
            Tracked = 0
            for Key: any, v: {origin: Vector3, velocity: Vector3, gravity: number, time: number} in Projectiles do
                if Now - v.time > Config.ProjectileLifetime then
                    Projectiles[Key] = nil
                else
                    Tracked += 1
                end
            end
        end

        local ProjectileMeta = Context.Bedwars.ProjectileMeta[Event.projectileType]
        Projectiles[Event] = {
            origin = Event.origin,
            velocity = Event.launchVelocity,
            gravity = ProjectileMeta and ProjectileMeta.gravitationalAcceleration or 196.2,
            time = Now - math.clamp(Context.Store.ping and Context.Store.ping.total or 0, 0, 0.4) / 2
        }
        Tracked += 1
    end

    function Observer.Projectile(Position: Vector3, Velocity: Vector3)
        local Now: number = workspace:GetServerTimeNow()
        for Key: any, v: {origin: Vector3, velocity: Vector3, gravity: number, time: number} in Projectiles do
            local Elapsed: number = Now - v.time
            if Elapsed > Config.ProjectileLifetime then
                Projectiles[Key] = nil
                Tracked = math.max(Tracked - 1, 0)
            else
                for Step: number = -5, 30 do
                    local Flight: number = Elapsed + Step * 0.02
                    local Offset: Vector3 = v.origin + v.velocity * Flight - Vector3.new(0, v.gravity * 0.5 * Flight * Flight, 0) - Position - Velocity * (Step * 0.02)
                    if Flight >= 0 and math.abs(Offset.Y) <= 4.5 and (Offset * Planar).Magnitude <= 4 then
                        return v
                    end
                end
            end
        end
        return nil
    end

    function Observer.Obstacle(Position: Vector3)
        Obstacles[tostring(Position)] = true
    end

    function Observer.Obstructed(From: Vector3, To: Vector3, Size: Vector3)
        if not next(Obstacles) or (To - From).Magnitude <= 0.1 then
            return false
        end
        local Hit: RaycastResult? = workspace:Blockcast(CFrame.new(From), Size, To - From, Params)
        return Hit and Obstacles[tostring(Hit.Instance.Position)] or false
    end

    function Observer.Clear()
        table.clear(Obstacles)
    end

    local function Ranked(Candidates, Valid, Limit: number)
        table.sort(Candidates, function(A, B)
            return A.score > B.score
        end)
        local Checked: number = 0
        for _, v: any in Candidates do
            if not Valid then
                return v.top
            end
            Checked += 1
            if Valid(v.top) then
                return v.top
            end
            if Checked >= Limit then
                break
            end
        end
        return nil
    end

    function Observer.Perch(Root: BasePart, HipHeight: number, Enemies, Valid)
        local Feet: RaycastResult? = workspace:Raycast(Root.Position, Vector3.new(0, -12, 0), Params)
        local FeetY: number = Feet and Feet.Position.Y or Root.Position.Y - HipHeight
        local Candidates = {}

        for OffsetX: number = -30, 30, 3 do
            for OffsetZ: number = -30, 30, 3 do
                local Top: RaycastResult? = workspace:Raycast(Vector3.new(Root.Position.X + OffsetX, FeetY + 60, Root.Position.Z + OffsetZ), Vector3.new(0, -90, 0), Params)
                local Distance: number = math.sqrt(OffsetX * OffsetX + OffsetZ * OffsetZ)
                if Top and Distance <= 30 and Top.Position.Y - FeetY >= 15 and not workspace:Raycast(Top.Position + Vector3.new(0, 0.1, 0), Vector3.new(0, 6, 0), Params) then
                    local Raised: Vector3 = Vector3.new(Root.Position.X, Top.Position.Y + HipHeight + 0.5, Root.Position.Z)
                    local Across: Vector3 = Vector3.new(Top.Position.X, Raised.Y, Top.Position.Z) - Raised
                    local Safe: boolean = not workspace:Raycast(Root.Position, Raised - Root.Position, Params) and (Across.Magnitude < 0.1 or not workspace:Blockcast(CFrame.new(Raised), Vector3.new(2, 4, 2), Across, Params))
                    for _, v: any in Enemies do
                        if not Safe then
                            break
                        end
                        Safe = (v.RootPart.Position - (Top.Position + Vector3.new(0, HipHeight, 0))).Magnitude >= 18
                    end
                    if Safe then
                        table.insert(Candidates, {top = Top.Position, score = Top.Position.Y - FeetY - Distance * 0.3})
                    end
                end
            end
        end

        return Ranked(Candidates, Valid, Config.PerchChecks or 12), FeetY
    end

    function Observer.Landing(Root: BasePart, HipHeight: number, Valid)
        local Candidates = {}

        for OffsetX: number = -30, 30, 3 do
            for OffsetZ: number = -30, 30, 3 do
                local Top: RaycastResult? = workspace:Raycast(Vector3.new(Root.Position.X + OffsetX, Root.Position.Y + 15, Root.Position.Z + OffsetZ), Vector3.new(0, -75, 0), Params)
                if Top and not workspace:Raycast(Top.Position + Vector3.new(0, 0.1, 0), Vector3.new(0, 6, 0), Params) then
                    local Height: number = math.max(Root.Position.Y, Top.Position.Y + HipHeight + 0.5)
                    local Across: Vector3 = Vector3.new(Top.Position.X, Height, Top.Position.Z) - Vector3.new(Root.Position.X, Height, Root.Position.Z)
                    if Across.Magnitude < 0.1 or not workspace:Blockcast(CFrame.new(Root.Position.X, Height, Root.Position.Z), Vector3.new(2, 4, 2), Across, Params) then
                        table.insert(Candidates, {top = Top.Position, score = -(Top.Position - Root.Position).Magnitude})
                    end
                end
            end
        end

        return Ranked(Candidates, Valid, Config.PerchChecks or 12)
    end

    function Observer.Valid(Destination)
        if Destination.target and not Destination.target.Parent then
            return false
        end
        if Destination.player then
            return Destination.player.Character == Destination.target.Parent and (Destination.target.Parent:GetAttribute("Health") or 0) > 0
                and tostring(Destination.player:GetAttribute("Team")) == Destination.owner and not Destination.target.Parent:FindFirstChildOfClass("ForceField")
        end
        return true
    end

    function Observer.Observe(Now: number)
        local Character: Model? = Context.Player.Character
        local Root = Character and Character:FindFirstChild("HumanoidRootPart")
        local Humanoid: Humanoid? = Character and Character:FindFirstChildOfClass("Humanoid")
        local Inventory = Context.Store.inventory.inventory
        local Bedwars = Context.Bedwars
        Observer.Filter(Character ~= LastCharacter)

        local Snapshot = {
            self = {
                alive = Context.Entity.isAlive and Root ~= nil and Humanoid ~= nil and Humanoid.Health > 0 and (Character:GetAttribute("Health") or Humanoid.Health) > 0,
                position = Root and Root.Position or Vector3.zero, velocity = Root and Root.AssemblyLinearVelocity or Vector3.zero,
                health = Character and Character:GetAttribute("Health") or Humanoid and Humanoid.Health,
                maxHealth = Character and Character:GetAttribute("MaxHealth") or Humanoid and Humanoid.MaxHealth,
                grounded = Humanoid and Humanoid.FloorMaterial ~= Enum.Material.Air or false,
                speed = Humanoid and Humanoid.WalkSpeed or 16, hipHeight = Context.Entity.character and Context.Entity.character.HipHeight or 3,
                jumpVelocity = Humanoid and (Humanoid.UseJumpPower and Humanoid.JumpPower or math.sqrt(2 * workspace.Gravity * Humanoid.JumpHeight)) or 42.6,
                gravity = workspace.Gravity, placeInterval = 1 / (Bedwars.SharedConstants.BLOCK_PLACE_CPS or 12),
                resources = {}, blocks = 0, projectiles = 0, utilities = {}, armor = 0, swordDamage = 0, tools = {},
                hotbar = Context.Store.inventory.hotbar, selectedItem = Context.Store.hand.tool and Context.Store.hand.tool.Name,
                inventoryCount = #Inventory.items, reservedResources = {iron = Config.IronReserve},
                blockReserve = Config.BlockReserve, inventorySpace = Context.InventorySpace and Context.InventorySpace(),
                canBuildUp = false
            },
            environment = {ownBed = OwnBed, matchEnded = Context.Store.matchState == 2, matchTime = 0, bedThreat = false, revision = Navigation.World and Navigation.World.Revision},
            enemies = {}, teammates = {}, destinations = {}, hazards = {}, canBreakBed = Context.BreakEnabled(),
            sources = {resources = "inventory", blocks = "inventory", armor = "inventory", swordDamage = "inventory", tools = "inventory", safeSurface = "raycast", nearVoid = "raycast", narrowBridge = "raycast", ownBed = "event"},
            confidence = {inventorySpace = Context.InventorySpace and 1 or 0}
        }
        local Armor = {}

        for _, v: any in {Inventory.items, Inventory.armor} do
            for _, Stack: any in v or {} do
                local ItemType: string = type(Stack) == "table" and Stack.itemType or Stack
                local Meta = Bedwars.ItemMeta[ItemType]
                if Meta and Meta.armor then
                    Armor[Meta.armor.slot] = math.max(Armor[Meta.armor.slot] or 0, Meta.armor.damageReductionMultiplier or 0)
                end
                if Meta and Meta.sword and (Meta.sword.damage or 0) > Snapshot.self.swordDamage then
                    Snapshot.self.swordDamage, Snapshot.self.weapon = Meta.sword.damage, ItemType
                    Snapshot.self.attackRange = math.min(Meta.sword.attackRange or 10, Config.LethalRange) * 0.8
                end
            end
        end
        for _, v: number in Armor do
            Snapshot.self.armor += v
        end
        Snapshot.self.armor = math.clamp(Snapshot.self.armor, 0, 0.9)

        for _, v: any in Inventory.items do
            Snapshot.self.resources[v.itemType] = (Snapshot.self.resources[v.itemType] or 0) + v.amount
            local Meta = Bedwars.ItemMeta[v.itemType]
            if Meta and Meta.block and v.itemType:find("wool") then
                Snapshot.self.blocks += v.amount
            end
            if Meta and Meta.breakBlock then
                Snapshot.self.tools[v.itemType] = Meta.breakBlock
            end
            if Meta and not Meta.block and not Meta.sword then
                table.insert(Snapshot.self.utilities, v.itemType)
            end
        end
        Snapshot.self.projectiles = #Context.Projectiles({"arrow", "snowball"})
        if not Snapshot.self.alive then
            return Snapshot
        end

        if Character ~= LastCharacter then
            LastCharacter, NextScan, NextDrops, UpperExit = Character, 0, 0, nil
        end

        local Surface = Observer.Surface(Root.Position, true)
        Snapshot.self.safeSurface, Snapshot.self.nearVoid, Snapshot.self.narrowBridge = Surface.safe, Surface.nearVoid, Surface.narrow
        Snapshot.self.airborne = not Snapshot.self.grounded
        Snapshot.self.falling = Snapshot.self.airborne and Root.AssemblyLinearVelocity.Y < -12 and not workspace:Raycast(Root.Position, Vector3.new(0, -14, 0), Params)
        Snapshot.self.fallRisk = Snapshot.self.falling or Surface.nearVoid

        local Team: string = tostring(Context.Player:GetAttribute("Team"))
        if Now >= NextScan then
            NextScan, Destinations, Beds = Now + Config.ScanInterval, {}, {}
            local FoundBed
            for _, v: BasePart in Context.Collection:GetTagged("bed") do
                local Owner: string = tostring(v:GetAttribute("TeamId"))
                Beds[Owner] = {value = true, timestamp = Now, confidence = 1, source = "event"}
                if Owner == Team then
                    FoundBed, OwnBed, Base = v, true, v.Position
                elseif not v:GetAttribute(`Team{Team}NoBreak`) then
                    table.insert(Destinations, {id = `bed:{Owner}`, kind = "enemybed", position = v.Position, target = v, owner = Owner})
                end
            end
            if not FoundBed and OwnBed == true then
                OwnBed = false
            end
            for _, v: Instance in Context.Collection:GetTagged("Generator") do
                local Id: string = v:GetAttribute("Id") or ""
                local Owner: string? = Id:match("^(.-)_generator$")
                local Resource: string? = Owner and "iron" or Id:match("^(diamond)_") or Id:match("^(emerald)_")
                if Owner == Team then
                    Base = Base or v.Position
                end
                if Resource and (not Owner or Owner == Team) then
                    table.insert(Destinations, {id = Id, kind = "generator", position = v.Position, target = v, resource = Resource, owner = Owner})
                end
            end
            for _, v: Instance in Context.Collection:GetTagged("BedwarsItemShop") do
                local Id: string = v:GetAttribute("Id") or ""
                if Id:match("^(.-)_item_shop") == Team then
                    local Merchant = v:FindFirstChild("desertMerchant")
                    local Part = Merchant and Merchant.PrimaryPart
                    if Part then
                        table.insert(Destinations, {id = Id, kind = "shop", position = Part.Position + Part.CFrame.LookVector * 7, target = v, shopId = Id})
                    end
                end
            end
            for _, v: Instance in Context.Collection:GetTagged("TeamUpgradeShopkeeper") do
                if Base and (v.Position - Base).Magnitude <= Config.BedThreatRadius then
                    table.insert(Destinations, {id = `upgrade:{tostring(v.Position)}`, kind = "upgrade", position = v.Position, target = v})
                end
            end
        end

        Snapshot.environment.ownBed, Snapshot.environment.beds, Snapshot.environment.base = OwnBed, Beds, Base
        if workspace.StreamingEnabled and OwnBed == false then
            Snapshot.environment.ownBed, Snapshot.confidence.ownBed = nil, 0
        end
        for _, v: any in Destinations do
            table.insert(Snapshot.destinations, v)
        end

        if Now >= NextDrops then
            NextDrops = Now + Config.DropInterval
            table.clear(Drops)
            for _, v: Instance in Context.Collection:GetTagged("ItemDrop") do
                if Config.ResourceWeights[v.Name] and (v.Position - Root.Position).Magnitude <= Config.SupportRadius and not workspace:Raycast(Root.Position, v.Position - Root.Position, Params) then
                    table.insert(Drops, {id = `drop:{tostring(v.Position)}`, kind = "drop", position = v.Position, target = v, resource = v.Name})
                end
            end
        end
        for _, v: any in Drops do
            if v.target.Parent then
                table.insert(Snapshot.destinations, v)
            end
        end

        if Base then
            table.insert(Snapshot.destinations, {id = "base", kind = "base", position = Base})
            Snapshot.self.insideBase = (Root.Position - Base).Magnitude <= Config.BaseRadius
        end

        for _, v: Player in Context.Players:GetPlayers() do
            if v == Context.Player or not v.Team or v.Team.Name == "Spectators" then
                continue
            end
            local Other: Model? = v.Character
            local Part = Other and Other:FindFirstChild("HumanoidRootPart")
            local Enemy: boolean = tostring(v:GetAttribute("Team")) ~= Team
            local Visible = Part and (Part.Position - Root.Position).Magnitude <= Config.ThreatRadius and not workspace:Raycast(Root.Position, Part.Position - Root.Position, Params)
            local BaseVisible = Part and Base and (Part.Position - Base).Magnitude <= Config.BedThreatRadius and not workspace:Raycast(Base + Vector3.new(0, 4, 0), Part.Position - Base - Vector3.new(0, 4, 0), Params)
            Visible = Visible or BaseVisible
            if Enemy and not Visible then
                table.insert(Snapshot.enemies, {id = tostring(v.UserId), visible = false})
            elseif Part and (Other:GetAttribute("Health") or 0) > 0 then
                local Entry = {
                    id = tostring(v.UserId), kind = Enemy and "enemy" or "teammate", position = Part.Position,
                    velocity = Part.AssemblyLinearVelocity, health = Other:GetAttribute("Health"),
                    visible = Visible, target = Part, player = v, owner = tostring(v:GetAttribute("Team")),
                    protected = Other:FindFirstChildOfClass("ForceField") ~= nil
                }
                Entry.threatensBed, Entry.confidence = BaseVisible, BaseVisible and 0.75 or 1
                if Visible and Context.Store.inventories[v] then
                    local Damage, Protection = Observer.Gear(Context.Store.inventories[v])
                    Entry.damage, Entry.armor, Entry.projectiles = Damage, 0, false
                    for _, Reduction: number in Protection do
                        Entry.armor += Reduction
                    end
                    Entry.armor = math.clamp(Entry.armor, 0, 0.9)
                    for _, Stack: any in Context.Store.inventories[v].items or {} do
                        local Meta = Bedwars.ItemMeta[Stack.itemType]
                        Entry.projectiles = Entry.projectiles or Meta and Meta.projectileSource ~= nil
                    end
                end
                table.insert(Enemy and Snapshot.enemies or Snapshot.teammates, Entry)
                if Enemy and Base and (Part.Position - Base).Magnitude <= Config.BedThreatRadius then
                    Snapshot.environment.bedThreat = true
                end
                if not Enemy then
                    table.insert(Snapshot.destinations, Entry)
                end
            end
        end

        for _, v: any in Snapshot.teammates do
            for _, Enemy: any in Snapshot.enemies do
                if Enemy.position and (Enemy.position - v.position).Magnitude <= Config.LethalRange then
                    v.underPressure = true
                end
            end
        end

        Snapshot.self.distanceToSafety = math.huge
        for _, v: any in Snapshot.destinations do
            if v.kind ~= "enemybed" then
                local Distance, Safe = (v.position - Root.Position).Magnitude, true
                for _, Enemy: any in Snapshot.enemies do
                    if Enemy.position and (v.position - Enemy.position).Magnitude <= Config.RouteEnemyRadius then
                        Safe = false
                    end
                end
                if Safe and Distance < Snapshot.self.distanceToSafety and Observer.Surface(v.position).safe then
                    Snapshot.self.distanceToSafety = Distance
                end
            end
        end
        Snapshot.self.escapeAvailable = Snapshot.self.distanceToSafety < math.huge
        Snapshot.self.canBuildCover = Surface.safe and Snapshot.self.blocks > Config.BlockReserve and not Surface.nearVoid
        Snapshot.self.buildAvailable = Snapshot.self.blocks > Config.BlockReserve and (not Context.CanPlace or Context.CanPlace())
        Snapshot.self.cover = false

        local Ranged, Nearest = false, math.huge
        for _, v: any in Snapshot.enemies do
            if v.position then
                Nearest = math.min(Nearest, (v.position - Root.Position).Magnitude)
                Ranged = Ranged or v.projectiles
                Snapshot.self.cover = Snapshot.self.cover or workspace:Raycast(Root.Position - Vector3.new(0, 2, 0), v.position - Root.Position, Params) ~= nil
            end
        end
        Snapshot.self.underPressure = Nearest <= Config.LethalRange

        if Surface.safe and not Surface.nearVoid and not Ranged and Nearest > Config.LethalRange * 0.5 and Snapshot.self.blocks >= Config.BlockReserve + 4 then
            if Now >= NextUpper or not UpperExit or (UpperOrigin - Root.Position).Magnitude > 3 then
                NextUpper, UpperExit, UpperOrigin = Now + 0.3, {}, Root.Position
                for _, v: Vector3 in Offsets do
                    local Upper: RaycastResult? = workspace:Raycast(Root.Position + v * 2 + Vector3.new(0, 8, 0), Vector3.new(0, -8, 0), Params)
                    if Upper and Upper.Normal.Y > 0.65 and Upper.Position.Y - Surface.hit.Position.Y >= 3 and Upper.Position.Y - Surface.hit.Position.Y <= 6
                        and not workspace:Raycast(Upper.Position + Vector3.new(0, 0.1, 0), Vector3.new(0, 6, 0), Params) then
                        table.insert(UpperExit, {id = `upper:{tostring(Upper.Position)}`, kind = "surface", position = Upper.Position + Vector3.new(0, Snapshot.self.hipHeight, 0)})
                    end
                end
            end
            for _, v: any in UpperExit do
                local Safe: boolean = true
                for _, Enemy: any in Snapshot.enemies do
                    if Enemy.position and (v.position - Enemy.position).Magnitude <= Config.LethalRange then
                        Safe = false
                    end
                end
                if Safe then
                    Snapshot.upperExit = v
                    Snapshot.self.canBuildUp = true
                    break
                end
            end
        end

        if next(Projectiles) then
            local Projectile = Observer.Projectile(Root.Position, Root.AssemblyLinearVelocity)
            if Projectile then
                table.insert(Snapshot.hazards, {kind = "projectile", position = Projectile.origin, velocity = Projectile.velocity})
            end
        end
        if Snapshot.self.nearVoid then
            table.insert(Snapshot.hazards, {kind = "void", position = Root.Position})
        end

        local Started = Bedwars.Store:getState().Game.startTime
        Snapshot.environment.matchTime = Started and Started > 0 and math.max(0, workspace:GetServerTimeNow() - Started) or 0
        local Geared, Missing = Observer.GearNeeded()
        local Item = Snapshot.self.blocks < Config.TravelBlocks and "wool_white" or not Geared and Missing
        if not Item and Context.Store.shopLoaded and Snapshot.environment.matchTime >= Config.EarlyTime and Snapshot.self.armor < 0.9 then
            for _, v: string in {"diamond_chestplate", "diamond_sword"} do
                local Meta = Bedwars.ItemMeta[v]
                if Meta and not Context.Item(v) and (Meta.sword and Meta.sword.damage > Snapshot.self.swordDamage or Meta.armor and (Armor[Meta.armor.slot] or 0) < Meta.armor.damageReductionMultiplier) then
                    Item = v
                    break
                end
            end
        end
        if Item and Context.Store.shopLoaded then
            local Purchase = Bedwars.Shop.getShopItem(Item, Context.Player)
            if Purchase and not Purchase.disabled and not Purchase.lockedByForge and (not Purchase.ignoredByKit or not table.find(Purchase.ignoredByKit, Context.Store.equippedKit)) then
                local Upgrade = Purchase.require and Purchase.require.teamUpgrade
                local Upgrades = Bedwars.Store:getState().Bedwars.teamUpgrades
                if not Upgrade or (Upgrades[Upgrade.upgradeId] or -1) >= Upgrade.lowestTierIndex then
                    Snapshot.purchase = {item = Item, currency = Purchase.currency, cost = Purchase.price + (Item == "wool_white" and 0 or Purchase.currency == "iron" and Config.IronReserve or 0), price = Purchase.price, data = Purchase}
                    Snapshot.self.plannedPurchase = Snapshot.purchase
                end
            end
        end
        if Bedwars.TeamUpgradeMeta and Snapshot.self.blocks >= Config.TravelBlocks and (not Snapshot.purchase or (Snapshot.self.resources.diamond or 0) >= Config.DiamondTarget) then
            local Upgrades = Bedwars.Store:getState().Bedwars.teamUpgrades[Context.Player:GetAttribute("Team")] or {}
            for _, v: string in {"ARMOR", "DAMAGE"} do
                local Meta = Bedwars.TeamUpgradeMeta[v]
                local Tier = Meta and Meta.tiers[(Upgrades[v] or 0) + 1]
                if Tier and (not Meta.disabledInQueue or not table.find(Meta.disabledInQueue, Context.Store.queueType)) and (not Tier.availableOnlyInQueue or table.find(Tier.availableOnlyInQueue, Context.Store.queueType)) then
                    Snapshot.purchase = {item = v, upgrade = true, currency = "diamond", cost = Tier.cost, price = Tier.cost, tier = (Upgrades[v] or 0) + 1}
                    break
                end
            end
        end

        return Snapshot
    end

    return Observer
end

function Navigation.newActuator(Context, Config, Observer)
    local Actuator = {}
    local Params, Overlap = Observer.Params, Observer.Overlap
    local Body: Vector3 = Vector3.new(1.8, 3.5, 1.8)
    local Planar: Vector3 = Vector3.new(1, 0, 1)
    local Logged: {[string]: number} = {}
    local NextShot: number = 0
    local Movement, JumpUntil

    function Actuator.Stop()
        Movement, JumpUntil = nil, nil
        if Context.Entity.isAlive then
            Context.Entity.character.Humanoid:Move(Vector3.zero, false)
        end
    end

    function Actuator.Move(Position: Vector3, Jump: boolean?, Kind: string?)
        Movement = {position = Position, jump = Jump, kind = Kind}
        if Jump then
            JumpUntil = os.clock() + Config.JumpCommitTime
        end
    end

    function Actuator.Update()
        if not Context.Entity.isAlive or not Context.Entity.character.RootPart.Parent then
            return
        end

        local Root: BasePart = Context.Entity.character.RootPart
        local Direction: Vector3 = Movement and (Movement.position - Root.Position) * Planar or Vector3.zero
        if Direction.Magnitude > 0.1 then
            local Jump = JumpUntil and os.clock() <= JumpUntil
            local Step: Vector3 = Direction.Unit * math.min(Direction.Magnitude, 1)
            if not Jump and (not Observer.Ground(Root.Position + Step) and Movement.kind ~= "Drop" or workspace:Blockcast(CFrame.new(Root.Position), Body, Step, Params)) then
                Direction = Vector3.zero
                Observer.Blocked = (Observer.Blocked or 0) + 1
            end
        end

        Context.Entity.character.Humanoid:Move(Direction.Magnitude > 0.1 and Direction.Unit or Vector3.zero, false)
        if Movement and Movement.jump then
            Context.Entity.character.Humanoid.Jump = true
            Movement.jump = false
        end
    end

    function Actuator.Look(Position: Vector3)
        if not Context.Entity.isAlive then
            return
        end

        local Root: BasePart = Context.Entity.character.RootPart
        local Direction: Vector3 = (Position - Root.Position) * Planar
        if Direction.Magnitude > 0.1 then
            Root.CFrame = Root.CFrame:Lerp(CFrame.lookAt(Root.Position, Root.Position + Direction), 0.25)
        end
    end

    function Actuator.ValidateMove(Action, Airborne: boolean?)
        local Root: BasePart = Context.Entity.character.RootPart
        local Direction: Vector3 = Action.Position - Root.Position
        if Direction.Magnitude < 0.1 then
            return true
        end
        if not Observer.Surface(Action.Position).safe then
            return false
        end

        local Step: Vector3 = Direction.Unit * math.min(Direction.Magnitude, 2)
        if Action.Type == "Jump" then
            return Airborne or Context.Entity.character.Humanoid.FloorMaterial ~= Enum.Material.Air and not workspace:Blockcast(CFrame.new(Root.Position), Body, Vector3.new(0, 4, 0), Params)
        end
        if Action.Type == "Drop" then
            return Root.Position.Y - Action.Position.Y <= 12 and not workspace:Blockcast(CFrame.new(Root.Position), Body, Step, Params)
        end
        return Observer.Ground(Root.Position + Step) and not workspace:Blockcast(CFrame.new(Root.Position), Body, Step, Params)
    end

    function Actuator.Block(Grid: Vector3): boolean
        local Block = Context.PlacedBlock(Grid * CellSize)
        return Block ~= nil and workspace:Raycast(Grid * CellSize + Vector3.new(0, 2, 0), Vector3.new(0, -3, 0), Params) ~= nil
    end

    function Actuator.ValidatePlacement(Placement, NextAction): boolean
        if not Context.Entity.isAlive or not Context.CanPlace() then
            return false
        end

        local Root: BasePart = Context.Entity.character.RootPart
        if (Root.Position - Placement.Position).Magnitude > 18 then
            return false
        end
        if #workspace:GetPartBoundsInBox(CFrame.new(Placement.Position), Vector3.new(2.8, 2.8, 2.8), Overlap) > 0 then
            return false
        end
        if NextAction and NextAction.Type ~= "PlaceBlock" and math.abs(NextAction.Position.Y - Placement.Position.Y) < 2 and ((NextAction.Position - Placement.Position) * Planar).Magnitude < 2 then
            return false
        end
        return true
    end

    function Actuator.Place(Position: Vector3)
        local Wool = Context.Wool()
        if Wool then
            Context.Bedwars.placeBlock(Position, Wool)
        end
    end

    function Actuator.Break(Grid: Vector3): boolean
        local Block = Context.PlacedBlock(Grid * CellSize)
        if Block and Context.Bedwars.breakBlock then
            Context.Bedwars.breakBlock(Block, true, true, nil, true)
            return true
        end
        return false
    end

    function Actuator.Build(Kind: string, Assessment, Limit: number)
        local Root: BasePart = Context.Entity.character.RootPart
        local Direction: Vector3 = Assessment.target and Assessment.target.position - Root.Position or Root.CFrame.LookVector
        local Grid: Vector3 = Navigation.WorldToGrid(Root.Position - Vector3.new(0, Context.Entity.character.HipHeight + HalfCell, 0))
        local Name: string = Kind == "BuildCover" and (Assessment.highGround and Assessment.ranged and "Roof" or Assessment.chased and "RetreatBlocker" or "Cover") or Kind
        local Pattern = Navigation.Pattern(Name, Grid, Name == "RetreatBlocker" and -Direction or Direction)
        local Result: {Vector3} = {}

        for _, v: Vector3 in Pattern or {} do
            if #Result >= Limit then
                break
            end
            if not Actuator.Block(v) then
                table.insert(Result, v)
            end
        end

        return Result
    end

    function Actuator.Attack(Destination)
        if not Observer.Valid(Destination) or not Context.Entity.isAlive then
            return
        end

        local Root: BasePart = Context.Entity.character.RootPart
        local Sword = Context.Store.tools.sword
        if not Sword or not Sword.tool or (Root.Position - Destination.target.Position).Magnitude > Config.LethalRange then
            return
        end
        if workspace:Raycast(Root.Position, Destination.target.Position - Root.Position, Params) then
            return
        end

        local Slot = Context.Hotbar(Sword.tool)
        if Slot and Context.Store.inventory.hotbarSlot ~= Slot then
            Context.Bedwars.Store:dispatch({type = "InventorySelectHotbarSlot", slot = Slot})
            return
        end
        if Context.Store.hand.tool ~= Sword.tool or not Context.CanSwing() then
            return
        end

        Actuator.Look(Destination.target.Position)
        Context.Bedwars.SwordController:swingSwordAtMouse(0.39)
    end

    function Actuator.Ranged(Destination)
        if not Destination or not Observer.Valid(Destination) or not Context.Entity.isAlive or os.clock() < NextShot then
            return
        end

        local Root: BasePart = Context.Entity.character.RootPart
        if workspace:Raycast(Root.Position, Destination.target.Position - Root.Position, Params) then
            return
        end

        local Target
        for _, v: any in Context.Entity.List do
            if v.Player == Destination.player then
                Target = v
                break
            end
        end
        if not Target then
            return
        end

        for _, v: any in Context.Projectiles({"arrow", "snowball"}) do
            local Item, Ammo, Projectile, Meta = unpack(v)
            local Slot = Context.Hotbar(Item.tool)
            if Slot and Context.Store.inventory.hotbarSlot ~= Slot then
                Context.Bedwars.Store:dispatch({type = "InventorySelectHotbarSlot", slot = Slot})
                return
            end
            if Context.Store.hand.tool == Item.tool then
                NextShot = os.clock() + math.max(Meta.fireDelaySec or 0, Config.RangedInterval)
                Context.FireProjectile(Item, Ammo, Projectile, Target)
            end
            break
        end
    end

    function Actuator.Pickup(Destination)
        if Observer.Valid(Destination) and Context.Entity.isAlive and (Context.Entity.character.RootPart.Position - Destination.target.Position).Magnitude <= Config.ArrivalRadius then
            Context.Bedwars.Handler:Get("PickupItemDrop"):Fire("CallServerAsync", {itemDrop = Destination.target})
        end
    end

    function Actuator.Buy(Destination, Purchase, Callback)
        if not Observer.Valid(Destination) or not Context.Entity.isAlive or (Context.Entity.character.RootPart.Position - Destination.position).Magnitude > Config.ArrivalRadius then
            Callback(false)
            return
        end

        local Bedwars = Context.Bedwars
        local Currency = Context.Item(Purchase.currency)
        if Purchase.upgrade then
            local Meta = Bedwars.TeamUpgradeMeta[Purchase.item]
            local Upgrades = Bedwars.Store:getState().Bedwars.teamUpgrades[Context.Player:GetAttribute("Team")] or {}
            local Tier = Meta and Meta.tiers[(Upgrades[Purchase.item] or 0) + 1]
            if Currency and Currency.amount >= Purchase.cost and Tier and Tier.cost == Purchase.price and (Upgrades[Purchase.item] or 0) + 1 == Purchase.tier then
                Bedwars.Handler:Get("RequestPurchaseTeamUpgrade"):Fire("CallServerAsync", Purchase.item):andThen(function(Success)
                    Callback(Success == true)
                end)
            else
                Callback(false)
            end
            return
        end

        local Current = Bedwars.Shop.getShopItem(Purchase.item, Context.Player)
        if not Currency or Currency.amount < Purchase.cost or not Current or Current.price ~= Purchase.price or Current.disabled or Current.lockedByForge then
            Callback(false)
            return
        end

        local Promise = Bedwars.Handler:Get("BedwarsPurchaseItem"):Fire("CallServerAsync", {shopItem = Current, shopId = Destination.shopId})
        Promise:andThen(function(Success)
            Callback(Success == true)
        end)
        if Promise.catch then
            Promise:catch(function()
                Callback(false)
            end)
        end
    end

    function Actuator.BreakBed(Destination)
        if Observer.Valid(Destination) and (Destination.target:GetAttribute("BedShieldEndTime") or 0) <= workspace:GetServerTimeNow() then
            Context.Bedwars.breakBlock(Destination.target, true, true, nil, true)
        end
    end

    function Actuator.Log(Name: string, Reason: string)
        if not Context.DebugEnabled or not Context.DebugEnabled() then
            return
        end

        local Now: number = os.clock()
        if (Logged[Name] or 0) > Now then
            return
        end
        Logged[Name] = Now + Config.DebugInterval
        warn(`[catvape] brain {Name} | {Reason}`)
    end

    return Actuator
end

function Navigation.newInterface(Context, Config)
    local Interface = Navigation.newObserver(Context, Config)
    for Key: string, v: (...any) -> ...any in Navigation.newActuator(Context, Config, Interface) do
        Interface[Key] = v
    end
    return Interface
end

local MemoryClass = {}
MemoryClass.__index = MemoryClass

local function Bound(Map, Limit: number)
    local Count, Oldest = 0, nil
    for Key: any, v: any in Map do
        Count += 1
        if not Oldest or v.timestamp < Map[Oldest].timestamp then
            Oldest = Key
        end
    end
    if Count > Limit then
        Map[Oldest] = nil
    end
end

function Navigation.newMemory(Config)
    return setmetatable({
        Config = Config,
        failures = {},
        successes = {},
        routes = {},
        surfaces = {},
        events = {},
        Version = 0
    }, MemoryClass)
end

function MemoryClass.Event(self, Entry)
    table.insert(self.events, Entry)
    if #self.events > self.Config.MemoryLimit then
        table.remove(self.events, 1)
    end
    return Entry
end

function MemoryClass.Failure(self, Key, Reason: string, Now: number, Position: Vector3?)
    local Previous = self.failures[Key]
    local Entry = self:Event({kind = "failure", key = Key, reason = Reason, timestamp = Now, position = Position})
    Entry.count = Previous and Now - Previous.timestamp < self.Config.FailureLifetime and Previous.count + 1 or 1
    self.failures[Key] = Entry
    Bound(self.failures, self.Config.MemoryLimit)
    return Entry
end

function MemoryClass.Success(self, Key, Now: number)
    local Previous = self.successes[Key]
    self.failures[Key] = nil
    self.successes[Key] = {timestamp = Now, count = Previous and Previous.count + 1 or 1}
    Bound(self.successes, self.Config.MemoryLimit)
end

function MemoryClass.Route(self, Grid: Vector3, Reason: string, Now: number)
    local Key: number = CellKey(Grid.X, Grid.Y, Grid.Z)
    local Previous = self.routes[Key]
    self.routes[Key] = {grid = Grid, reason = Reason, timestamp = Now, count = Previous and Now - Previous.timestamp < self.Config.AvoidLifetime and Previous.count + 1 or 1}
    Bound(self.routes, self.Config.MemoryLimit)
    self.Version += 1
    self:Event({kind = "route", key = Key, reason = Reason, timestamp = Now, position = Grid * CellSize})
end

function MemoryClass.Avoid(self, Now: number)
    if self.AvoidVersion == self.Version and Now - (self.AvoidAt or -math.huge) < 1 then
        return self.Avoided
    end

    local Avoid: {[number]: number}? = nil
    for Key: number, v: {grid: Vector3, reason: string, timestamp: number, count: number} in self.routes do
        if Now - v.timestamp < self.Config.AvoidLifetime then
            Avoid = Avoid or {}
            Avoid[Key] = v.count * self.Config.AvoidPenalty
        end
    end

    self.Avoided, self.AvoidVersion, self.AvoidAt = Avoid, self.Version, Now
    return Avoid
end

function MemoryClass.Surface(self, Position: Vector3, Now: number)
    local Previous = self.surfaces[#self.surfaces]
    if not Previous or (Previous.position - Position).Magnitude > self.Config.BaseRadius then
        table.insert(self.surfaces, {id = `surface:{Now}`, kind = "surface", position = Position, timestamp = Now, confidence = 1})
        if #self.surfaces > self.Config.MemoryLimit then
            table.remove(self.surfaces, 1)
        end
    end
end

function MemoryClass.Expire(self, Now: number)
    for Key: string, v: any in self.failures do
        if Now - v.timestamp > self.Config.FailureLifetime then
            self.failures[Key] = nil
        end
    end
    for Key: number, v: {grid: Vector3, reason: string, timestamp: number, count: number} in self.routes do
        if Now - v.timestamp > self.Config.AvoidLifetime then
            self.routes[Key] = nil
            self.Version += 1
        end
    end
end

local MindClass = {}
MindClass.__index = MindClass

local function DeepMerge(Base, Override)
    local Result = {}
    for Key: string, v: any in Base do
        Result[Key] = type(v) == "table" and DeepMerge(v, Override and Override[Key]) or v
    end
    for Key: string, v: any in Override or {} do
        if type(v) ~= "table" then
            Result[Key] = v
        end
    end
    return Result
end

function Navigation.newMind(Config)
    local Merged = DeepMerge(Navigation.Config.Mind, Config)
    return setmetatable({
        Config = Merged,
        WorldState = {self = {}, environment = {}, enemies = {}, teammates = {}},
        Memory = Navigation.newMemory(Merged),
        GoalStack = {},
        Debug = {},
        Revision = 0,
        Retreating = false,
        Recovery = 0,
        NextAction = 0
    }, MindClass)
end

function MindClass.Observe(self, Snapshot, Now: number)
    if self.Snapshot and self.Snapshot.environment.ownBed == true and Snapshot.environment.ownBed == false then
        self:Record("bedlost", "base", "Bed lost; switch to survival risk limits", Now)
    end

    self.Snapshot = Snapshot
    for _, v: string in {"self", "environment"} do
        for Key: string, Value: any in Snapshot[v] or {} do
            local Source = Snapshot.sources and Snapshot.sources[Key] or (v == "self" and "character" or "cache")
            self.WorldState[v][Key] = {value = Value, timestamp = Now, confidence = Snapshot.confidence and Snapshot.confidence[Key] or 1, source = Source}
        end
        for Key: string, Entry: any in self.WorldState[v] do
            if (Snapshot[v] or {})[Key] == nil then
                Entry.confidence = math.max(0, 1 - (Now - Entry.timestamp) / self.Config.ObservationLifetime)
            end
        end
    end

    for _, v: string in {"enemies", "teammates"} do
        for _, Member: any in Snapshot[v] or {} do
            if Member.visible or v == "teammates" then
                self.WorldState[v][Member.id] = {value = Member, timestamp = Now, confidence = Member.confidence or 1, source = "raycast"}
            elseif not self.WorldState[v][Member.id] then
                self.WorldState[v][Member.id] = {value = {id = Member.id}, timestamp = Now, confidence = 0, source = "cache"}
            end
        end
        for Key: any, Entry: any in self.WorldState[v] do
            Entry.confidence = Entry.value.position and math.max(0, 1 - (Now - Entry.timestamp) / self.Config.EnemyLifetime) * (Entry.value.confidence or 1) or 0
            if Now - Entry.timestamp > self.Config.EnemyLifetime then
                self.WorldState[v][Key] = nil
            end
        end
    end

    self.Memory:Expire(Now)
    if Snapshot.self.safeSurface and Snapshot.self.position then
        self.Memory:Surface(Snapshot.self.position, Now)
    end

    self.ObservedAt = Now
    self.WorldState.environment.destinations = {value = Snapshot.destinations, timestamp = Now, confidence = 1, source = "cache"}
    self.WorldState.environment.bedThreat = {value = Snapshot.environment.bedThreat, timestamp = Now, confidence = 1, source = "character"}
    for _, v: string in {"inventorySpace", "healing", "storage", "canBuildUp", "escapeAvailable", "currentTarget", "currentSubgoal", "currentRoute", "currentEscapeRoute"} do
        if not self.WorldState.self[v] then
            self.WorldState.self[v] = {timestamp = Now, confidence = 0, source = "cache"}
        end
    end
end

function MindClass.Gate(self, Ratio: number, Danger: boolean?, Pressure: boolean?): boolean
    if Ratio <= self.Config.LowHealth or Danger then
        self.Retreating = true
    elseif self.Retreating and Ratio >= self.Config.RecoverHealth and not Pressure then
        self.Retreating = false
    end
    return self.Retreating
end

function MindClass.Assess(self, Now: number)
    local State, Environment = self.Snapshot.self, self.Snapshot.environment
    local Config = self.Config
    local Ratio: number = State.health and State.maxHealth and State.maxHealth > 0 and math.clamp(State.health / State.maxHealth, 0, 1) or 0
    local Result = {ratio = Ratio, count = 0, pressure = 0, damage = 0, support = 0, valuable = 0, nearest = math.huge, ranged = false, chased = false, uncertainty = 0}

    for Resource: string, v: number in Config.ResourceWeights do
        Result.valuable += ((State.resources or {})[Resource] or 0) * v
    end
    Result.carrying = Result.valuable >= Config.ValuableThreshold

    for _, v: any in self.WorldState.teammates do
        if v.value.position and (v.value.position - State.position).Magnitude <= Config.SupportRadius and v.confidence > 0.5 then
            Result.support += 1
        end
    end

    for _, v: any in self.WorldState.enemies do
        local Enemy = v.value
        if not Enemy.position or v.confidence <= 0 then
            Result.uncertainty += 1
            continue
        end

        local Distance: number = (Enemy.position - State.position).Magnitude
        local Current = Now - v.timestamp <= Config.ThinkInterval * 2 and Enemy.visible
        if Distance < Config.ThreatRadius then
            local Proximity: number = 1 - Distance / Config.ThreatRadius
            local Damage: number = (Enemy.damage or Config.UnknownDamage) * (1 - (State.armor or 0))
            Result.pressure += Proximity * Config.Weights.Enemy * (Current and 1 or math.max(v.confidence, 0.25))
            if Current then
                if Distance <= Config.LethalRange then
                    Result.count += 1
                end
                Result.damage = math.max(Result.damage, Damage)
                Result.ranged = Result.ranged or Enemy.projectiles == true
                if Distance < Result.nearest then
                    Result.nearest, Result.target = Distance, Enemy
                end
                local Direction: Vector3 = State.position - Enemy.position
                Result.chased = Result.chased or Direction.Magnitude > 0.1 and (Enemy.velocity or Vector3.zero):Dot(Direction.Unit) > Config.ChaseSpeed
            else
                Result.uncertainty += Proximity * v.confidence
            end
        end
    end

    Result.highGround = Result.target and Result.target.position.Y - State.position.Y > Config.HighGround or false
    Result.oneHit = Result.damage > 0 and (State.health or 0) <= Result.damage
    Result.twoHits = Result.damage > 0 and (State.health or 0) <= Result.damage * 2
    Result.incoming = Result.damage * math.max(Result.count, 1) * Config.ForecastTime / Config.AttackInterval
    Result.escapeTime = State.distanceToSafety and State.distanceToSafety / math.max(State.speed or 1, 1) or math.huge
    Result.canEscape = State.escapeAvailable == true and (Result.nearest > Config.LethalRange or Result.escapeTime < (State.health or 0) / math.max(Result.incoming, 1) * Config.ForecastTime)
    Result.score = Result.pressure + math.max(Result.count - 1, 0) * Config.Weights.ExtraEnemy
        + (Result.highGround and Config.Weights.Elevation or 0)
        + (Result.ranged and Config.Weights.Projectile or 0)
        + (State.nearVoid and Config.Weights.Void or 0)
        + (State.narrowBridge and Config.Weights.Narrow or 0)
        + math.min(Result.uncertainty, 1) * Config.Weights.Uncertainty
        + (1 - Ratio) * Config.Weights.Health
        + (Environment.ownBed ~= true and Config.Weights.NoBed or 0)
        - Result.support * Config.Weights.Support
        - (State.cover and Config.Weights.Cover or 0)
        - (State.escapeAvailable and Config.Weights.Escape or 0)
    Result.healthState = (Ratio <= Config.CriticalHealth or Result.oneHit and Result.nearest <= Config.LethalRange and (State.nearVoid or Result.carrying or Result.count > 1)) and "Critical" or nil
    Result.healthState = Result.healthState or (Ratio <= Config.LowHealth and "Low" or Ratio < Config.HighHealth and "Medium" or "High")
    Result.phase = Environment.ownBed == false and "Late" or (Environment.matchTime or 0) >= Config.LateTime and "Late" or (Environment.matchTime or 0) >= Config.EarlyTime and "Mid" or "Early"

    local EnemyHealth: number = Result.target and Result.target.health or Config.UnknownEnemyHealth
    local Dealt: number = (State.swordDamage or 0) * (1 - (Result.target and Result.target.armor or Config.UnknownArmor))
    Result.fightScore = (Ratio - EnemyHealth / Config.UnknownEnemyHealth) * Config.Weights.Health
        + (Dealt - Result.damage) * Config.Weights.Equipment
        + Result.support * Config.Weights.Support + (Result.count <= 1 and Config.Weights.Isolation or 0)
        - Result.score - Result.valuable * Config.Weights.Resources
    Result.finish = Result.target and EnemyHealth <= Dealt and Result.nearest <= Config.LethalRange and Result.count == 1
        and not State.nearVoid and not State.narrowBridge and not Result.highGround and State.escapeAvailable == true
        and (not Result.oneHit or Result.support >= Config.FinishSupport) and not Result.carrying

    self:Gate(Ratio, Result.healthState == "Critical" or Result.count > 1 and Result.score >= Config.MaxThreat, Result.count > 0 or Result.score >= Config.MaxThreat)
    self.Assessment = Result
    return Result
end

function MindClass.RouteRisk(self, Positions: {Vector3}, Now: number)
    local Risk, Nearest, Unknown = 0, math.huge, false

    for _, v: any in self.WorldState.enemies do
        if not v.value.position then
            Unknown = true
            continue
        end
        local Distance: number = math.huge
        for _, Position: Vector3 in Positions do
            Distance = math.min(Distance, (Position - v.value.position).Magnitude)
        end
        Nearest = math.min(Nearest, Distance)
        if Distance < self.Config.RouteEnemyRadius then
            Risk += (1 - Distance / self.Config.RouteEnemyRadius) * self.Config.Weights.Enemy * math.max(v.confidence, 0.25)
        end
    end

    for _, v: any in self.Memory.failures do
        if v.position and Now - v.timestamp < self.Config.FailureLifetime then
            for _, Position: Vector3 in Positions do
                if (Position - v.position).Magnitude < self.Config.ArrivalRadius then
                    Risk += self.Config.Weights.Failure * v.count
                    break
                end
            end
        end
    end

    return Risk + (Unknown and self.Config.Weights.Uncertainty or 0), Nearest
end

function MindClass.Clear(self, Now: number?)
    if self.Goal then
        self.Previous = {id = self.Goal.id, ended = Now or self.ObservedAt or 0}
    end
    self.Goal, self.Decision = nil, nil
    self.Revision += 1
end

function MindClass.Record(self, Kind: string, Key: string, Reason: string, Now: number, Position: Vector3?)
    if Kind == "failure" then
        self.Memory:Failure(Key, Reason, Now, Position)
        self.Recovery = math.min(self.Recovery + 1, self.Config.RecoveryLimit)
        self.NextAction = Now + (self.Recovery >= self.Config.RecoveryLimit and self.Config.RecoveryWait or self.Config.ReactionTime)
        self:Clear(Now)
        return
    end

    self.Memory:Event({kind = Kind, key = Key, reason = Reason, timestamp = Now, position = Position})
    if Kind == "kill" then
        self.NextAction = Now + self.Config.PostKillWait
        self:Clear(Now)
    elseif Kind == "bedlost" then
        self.Retreating = true
        self:Clear(Now)
    elseif Kind == "success" then
        self.Memory:Success(Key, Now)
        self.Recovery = 0
    end
end

function MindClass.Complete(self, Goal, Now: number)
    self.Memory:Success(Goal.id, Now)
    if self.Goal == Goal then
        self.Previous = {id = Goal.id, ended = Now}
        self.Goal, self.Decision = nil, nil
    end
end

function MindClass.Decide(self, Now: number)
    local State, Environment, Config = self.Snapshot.self, self.Snapshot.environment, self.Config
    local Assessment = self:Assess(Now)
    local Candidates = {}
    local Danger = self.Retreating or Assessment.score >= Config.MaxThreat or State.narrowBridge and Assessment.target ~= nil

    local function Add(Name: string, Priority: number, Reason: string, Destination, Action: string, Emergency: boolean?, Category: string?)
        local Id: string = `{Name}:{Destination and Destination.id or ""}`
        local Failed = self.Memory.failures[Id]
        if Failed and Name ~= "Recover" and (Action ~= "Wait" or Destination) and Now - Failed.timestamp < (Failed.count >= Config.RecoveryLimit and Config.FailureLifetime or Config.FailureCooldown * Failed.count) then
            return
        end

        Priority = (Config.Priorities[Name] or Priority) + (Name == "ReturnToBase" and Config.BasePreference or 0)
        local Risk: number = Destination and self:RouteRisk({Destination.position}, Now) or 0
        local Distance: number = Destination and (Destination.position - State.position).Magnitude or 0
        Category = Category or "Valuable"
        table.insert(Candidates, {
            id = Id, name = Name, goal = Name, priority = Priority, reason = Reason,
            destination = Destination, target = Destination, action = Action, subgoal = Action,
            emergency = Emergency == true, interruptible = not Emergency, category = Category, risk = Risk,
            urgency = Emergency and "Emergency" or Category == "Essential" and "High" or Category == "Optional" and "Low" or "Normal",
            score = Priority - Risk - Distance * Config.Weights.Travel - (Failed and Failed.count * Config.Weights.Failure or 0),
            timeout = Action == "Collect" and Config.CollectTimeout or Action == "Fight" and Config.FightTimeout or Config.GoalTimeout
        })
    end

    if not State.alive or Environment.matchEnded then
        Add("WaitForSpawn", 1000, "Character unavailable or match finished", nil, "Wait", true, "Essential")
    elseif State.falling then
        Add("Recover", 1000, "Falling without a verified landing", nil, "Recover", true, "Essential")
    elseif Now - self.ObservedAt > Config.ObservationLifetime or not State.health or not State.maxHealth then
        Add("WaitForInformation", 950, "Health or perception is uncertain", nil, "Wait", true, "Essential")
    else
        local Threatened: boolean = Environment.bedThreat == true
        local Purchase = self.Snapshot.purchase
        local Saving = Purchase and Purchase.currency ~= "iron" and (State.resources[Purchase.currency] or 0) < Purchase.cost and Assessment.ratio >= Config.HighHealth and Assessment.count == 0 and not Assessment.chased and Assessment.score < Config.SafeRouteRisk
        local Returning = Assessment.carrying and not State.insideBase and not Saving
        local Escape = {}

        for _, v: any in self.Snapshot.destinations or {} do
            if v.kind == "base" or v.kind == "teammate" or v.kind == "surface" or v.kind == "cover" or v.kind == "shop" then
                table.insert(Escape, v)
            end
        end
        for _, v: {id: string, kind: string, position: Vector3, timestamp: number, confidence: number} in self.Memory.surfaces do
            if Now - v.timestamp < Config.ObservationLifetime then
                table.insert(Escape, v)
            end
        end

        if Danger or Returning or Threatened then
            for _, v: any in Escape do
                local Risk: number = self:RouteRisk({v.position}, Now)
                if Risk <= (Threatened and not Danger and Config.RouteRiskLimit or Config.SafeRouteRisk) and (not Danger or not Assessment.target or (v.position - Assessment.target.position).Magnitude > Assessment.nearest + Config.ArrivalRadius) then
                    local Home: boolean = v.kind == "base"
                    local Defend = Threatened and Home and not self.Retreating
                    Add(Defend and "DefendBed" or Home and "ReturnToBase" or "Escape", (Defend and 220 or Danger and 230 or 160) + (Home and Config.BasePreference or 0),
                        Defend and "Enemy entered the base" or Returning and "Secure valuable resources" or "Reach verified safety before continuing", v,
                        "Wait", Danger or Threatened, "Essential")
                end
            end
            if #Candidates == 0 and Danger then
                if State.canBuildCover and State.blocks > Config.BlockReserve then
                    Add("BuildCover", 230, "No safe horizontal route; block pursuit or line of sight", nil, "BuildCover", true, "Essential")
                end
                if State.canBuildUp and self.Snapshot.upperExit and not Assessment.ranged and not State.nearVoid and not State.falling then
                    Add("BuildUp", 229, "Verified upper exit and descent are safer than remaining here", self.Snapshot.upperExit, "Wait", true, "Essential")
                end
                if Assessment.target and Assessment.nearest <= Config.LethalRange and State.swordDamage > 0 then
                    Add("SurvivalCombat", 225, "No safe escape; resist immediate lethal pressure", Assessment.target, "Fight", true, "Essential")
                end
                Add("Hide", 220, "Wait for a verified escape without stepping into danger", nil, "Wait", true, "Essential")
            end
        end

        if Threatened and not self.Retreating and not Assessment.carrying and Assessment.target and not State.nearVoid and not State.narrowBridge and Assessment.count <= 1 then
            Add("DefendBed", 245, "Remove an isolated intruder before resuming collection", Assessment.target, "Fight", true, "Essential")
        end

        if Assessment.finish then
            Add("Finish", 260, "Isolated one-hit enemy on safe ground with a supported escape", Assessment.target, "Fight", true)
        elseif not Danger and not Returning and not Threatened and Now >= self.NextAction and Assessment.target then
            if Assessment.highGround then
                if (State.projectiles or 0) > 0 and State.safeSurface and State.cover and Assessment.nearest > Config.LethalRange and State.escapeAvailable then
                    Add("Harass", 150, "Use cover and a ranged weapon against high ground", Assessment.target, "Harass")
                end
                if State.canBuildCover then
                    Add("BuildCover", 145, "Enemy controls high ground", nil, "BuildCover", true)
                end
                for _, v: any in Escape do
                    if (v.position - Assessment.target.position).Magnitude > Assessment.nearest then
                        Add("Reposition", 140, "Change approach instead of charging high ground", v, "Wait", true)
                    end
                end
                Add("WaitForInformation", 120, "High ground cannot be challenged safely", nil, "Wait", true)
            elseif Assessment.fightScore >= Config.FightThreshold and State.escapeAvailable and not State.nearVoid and not State.narrowBridge and State.swordDamage > 0 then
                Add("Fight", 120, "Isolated opponent; health, equipment and escape justify engagement", Assessment.target, "Fight")
            end
        end

        if not Danger and not Returning and not Threatened and Now >= self.NextAction then
            if Purchase and State.inventorySpace ~= false then
                local Missing: number = math.max(Purchase.cost - ((State.resources or {})[Purchase.currency] or 0), 0)
                for _, v: any in self.Snapshot.destinations or {} do
                    if Missing > 0 and v.kind == "generator" and v.resource == Purchase.currency then
                        Add("CollectForPurchase", State.blocks <= Config.BlockReserve and 115 or 90, `Need {Missing} {Purchase.currency} for {Purchase.item}`, v, "Collect")
                    elseif Missing == 0 and v.kind == (Purchase.upgrade and "upgrade" or "shop") then
                        Add("BuyEquipment", State.blocks <= Config.BlockReserve and 116 or 95, `Purchase {Purchase.item}; preserve survival reserves`, v, "Buy")
                    end
                end
            end
            if State.blocks >= Config.TravelBlocks and Assessment.ratio > Config.LowHealth then
                for _, v: any in self.Snapshot.destinations or {} do
                    if v.kind == "generator" and v.resource ~= "iron" and not Assessment.carrying and State.inventorySpace ~= false and Assessment.phase ~= "Early" then
                        if v.resource == "diamond" and (State.resources.diamond or 0) < Config.DiamondTarget or v.resource == "emerald" and (State.resources.emerald or 0) < Config.EmeraldTarget and Assessment.ratio >= Config.HighHealth and (Assessment.support > 0 or Assessment.score < Config.SafeRouteRisk / 2) then
                            Add("CollectResources", v.resource == "emerald" and 55 or 65, `Collect a useful amount of {v.resource} with an escape`, v, "Collect", false, "Optional")
                        end
                    elseif v.kind == "enemybed" and self.Snapshot.canBreakBed and not Assessment.carrying and Assessment.ratio >= Config.HighHealth and Environment.ownBed == true and State.escapeAvailable then
                        Add("AttackBed", 70, "Healthy, equipped and able to withdraw", v, "BreakBed", false, "Optional")
                    elseif v.kind == "teammate" and v.underPressure and Assessment.fightScore >= Config.FightThreshold then
                        Add("SupportTeam", 110, "Nearby teammate can be supported without a second death", v, "Wait")
                    elseif v.kind == "drop" and not Assessment.carrying and Assessment.count == 0 and State.inventorySpace ~= false then
                        Add("CollectDrops", 85, "Collect visible useful resources after checking reinforcements", v, "Collect", false, "Optional")
                    end
                end
            end
        end

        Add("Reassess", 1, Now < self.NextAction and "Recovering or checking for reinforcements" or "No useful action has a verified safety advantage", nil, "Wait")
    end

    table.sort(Candidates, function(A, B)
        if A.emergency ~= B.emergency then
            return A.emergency
        end
        if A.score ~= B.score then
            return A.score > B.score
        end
        return A.id < B.id
    end)

    local Selected = Candidates[1]
    if self.Goal and Now - self.Goal.started > self.Goal.timeout and self.Goal.action ~= "Wait" then
        self:Record("failure", self.Goal.id, "Objective timed out without useful progress", Now, State.position)
        return self:Decide(Now)
    end

    local Flipping = self.Previous and Selected.id == self.Previous.id and Now - self.Previous.ended < Config.FlipWindow
    local Margin: number = Config.SwitchMargin * (Flipping and 2 or 1)
    for _, v: any in Candidates do
        if self.Goal and v.id == self.Goal.id and (not Selected.emergency or v.emergency and Selected.priority <= v.priority) and (Now - self.Goal.started < Config.CommitTime or Selected.score < v.score + Margin) then
            Selected = v
            break
        end
    end

    Selected.started = self.Goal and Selected.id == self.Goal.id and self.Goal.started or Now
    if not self.Goal or Selected.id ~= self.Goal.id then
        if self.Goal then
            self.Previous = {id = self.Goal.id, ended = Now}
        end
        self.Revision += 1
        table.insert(self.Debug, {timestamp = Now, goal = Selected.name, reason = Selected.reason, threat = Assessment.score, health = Assessment.healthState, resources = Assessment.valuable, combat = Selected.action == "Fight" and (Selected.name == "Finish" and "FINISH" or "FIGHT") or Danger and "RETREAT" or "ABORT"})
        if #self.Debug > Config.DebugLimit then
            table.remove(self.Debug, 1)
        end
    end

    Selected.revision, Selected.expiresAt = self.Revision, Selected.started + Selected.timeout
    self.Goal, self.Decision, self.GoalStack = Selected, Selected, Candidates
    self.WorldState.self.currentGoal = {value = Selected.name, timestamp = Now, confidence = 1, source = "cache"}
    self.WorldState.self.currentTarget = {value = Selected.destination or false, timestamp = Now, confidence = 1, source = "cache"}
    self.WorldState.self.currentSubgoal = {value = Selected.action, timestamp = Now, confidence = 1, source = "cache"}
    self.WorldState.self.currentThreat = {value = Assessment, timestamp = Now, confidence = math.max(0, 1 - Assessment.uncertainty / 4), source = "cache"}
    return Selected
end

function Navigation.Pattern(Name: string, Grid: Vector3, Direction: Vector3): {Vector3}?
    local Forward: Vector3 = math.abs(Direction.X) > math.abs(Direction.Z) and Vector3.new(math.sign(Direction.X), 0, 0) or Vector3.new(0, 0, math.sign(Direction.Z))
    if Forward.Magnitude == 0 then
        Forward = Vector3.new(1, 0, 0)
    end

    local Side: Vector3 = Vector3.new(-Forward.Z, 0, Forward.X)
    local Up: Vector3 = Vector3.new(0, 1, 0)
    local Patterns: {[string]: {Vector3}} = {
        Tower = {Grid + Up, Grid + Up * 2},
        Staircase = {Grid + Forward, Grid + Forward * 2 + Up, Grid + Forward * 3 + Up * 2},
        SideWall = {Grid + Side + Up, Grid + Side + Up * 2},
        Roof = {Grid + Forward + Up, Grid + Forward + Up * 2, Grid + Forward + Up * 3, Grid + Up * 3},
        Cover = {Grid + Forward + Up, Grid + Forward + Up * 2},
        EmergencyPlatform = {Grid + Forward, Grid + Forward + Side, Grid + Forward - Side},
        Bridge = {Grid + Forward, Grid + Forward * 2, Grid + Forward * 3},
        Barrier = {Grid + Forward + Up, Grid + Forward + Side + Up, Grid + Forward - Side + Up},
        RetreatBlocker = {Grid - Forward + Up, Grid - Forward + Up * 2},
        Landing = {Grid + Forward, Grid + Forward + Side, Grid + Forward - Side}
    }
    return Patterns[Name]
end

local AgentClass = {}
AgentClass.__index = AgentClass

local Planar: Vector3 = Vector3.new(1, 0, 1)

function Navigation.newAgent(Options)
    Options = Options or {}

    local Mind = Options.Mind or Navigation.newMind(Options.Config)
    local Planner = Options.Planner or Navigation
    local Interface = Options.Interface or Options.Context and Navigation.newInterface(Options.Context, Mind.Config)
    return setmetatable({
        Mind = Mind,
        Brain = Mind,
        Memory = Mind.Memory,
        Planner = Planner,
        Navigation = Planner,
        Interface = Interface,
        Adapter = Interface,
        Fallback = Options.Fallback,
        Running = true,
        Generation = 0,
        PlanRevision = 0,
        TargetRevision = 0,
        NextThink = 0,
        NextPlace = 0,
        NextAttack = 0,
        NextVerify = 0,
        Index = 1,
        Stage = 0,
        Stalls = 0,
        Breakouts = 0,
        Repaths = {},
        RecoveryState = "REASSESS",
        DebugState = {},
        Throttled = {}
    }, AgentClass)
end

function AgentClass.Log(self, Key: string, Text: string)
    if self.Interface and self.Interface.Log then
        self.Interface.Log(Key, Text)
    end
end

function AgentClass.Throttle(self, Key: string, Interval: number?): boolean
    local Now: number = os.clock()
    if (self.Throttled[Key] or 0) > Now then
        return false
    end
    self.Throttled[Key] = Now + (Interval or self.Mind.Config.DebugInterval)
    return true
end

function AgentClass.Note(self, Goal, Subgoal, Reason)
    self.Objective, self.Subgoal, self.Reason = Goal, Subgoal, Reason
end

function AgentClass.Drop(self)
    if self.Request then
        self.Request:Cancel()
    end
    self.Request, self.Route, self.Index = nil, nil, 1
    self.PlanRevision += 1
end

function AgentClass.Cancel(self)
    self.Generation += 1
    self:Drop()
    self.Pending, self.Build, self.TowerJump, self.Breaking = nil, nil, nil, nil
    self.Jumping, self.RouteGoal, self.ActiveGoal = nil, nil, nil
    if self.Interface then
        self.Interface.Stop()
    end
end

function AgentClass.Destroy(self)
    self.Running = false
    self:Cancel()
    self.Purchase = nil
    self.RecoveryState = "RESET_GOAL"
end

function AgentClass.Fail(self, Reason: string, Now: number)
    local Mind = self.Mind
    local Goal = Mind.Goal
    Mind:Record("failure", Goal and Goal.id or "action", Reason, Now, Mind.Snapshot and Mind.Snapshot.self.position)
    self.LastFailure = Reason
    self:Cancel()
    if self.Purchase and self.Purchase.done then
        self.Purchase = nil
    end
    self.NextThink = 0
    self.Stalls, self.Stage, self.Approach = 0, 0, nil
    self.RecoveryState = Mind.Recovery >= Mind.Config.RecoveryLimit and "WAIT_FOR_INFORMATION" or "REPATH"
    self:Log("failure", Reason)
end

function AgentClass.Options(self, State, Emergency: boolean?)
    local Mind = self.Mind
    local Config = Mind.Config
    local Assessment = Mind.Assessment or {}
    local Cautious = Mind.Retreating or Assessment.carrying or Assessment.ranged
    local Approach = self.Approach
    return {
        Channel = "bedwarsai",
        Mode = "Legit",
        BlocksAvailable = math.max(0, State.blocks - (Emergency and 0 or Config.BlockReserve)),
        Avoid = self.Memory:Avoid(self.Now or 0),
        Agent = {
            WalkSpeed = State.speed,
            HipHeight = State.hipHeight,
            JumpVelocity = State.jumpVelocity,
            Gravity = State.gravity,
            MaxDrop = Cautious and 6 or 12,
            DamageAllowance = 0
        },
        Search = {
            MaxSteps = Config.PlanSteps,
            WalkSteps = Config.PlanSteps,
            Fallback = false,
            Smooth = false,
            Segment = Config.Segment,
            Bridge = (Approach == "Build" or not Cautious) and State.blocks > Config.BlockReserve,
            Tower = Approach == "Build" or Mind.Goal and Mind.Goal.name == "BuildUp",
            JumpGap = Approach ~= "Careful" and not Cautious,
            GoalDrop = 4
        }
    }
end

function AgentClass.Place(self, Grid: Vector3, Now: number, Emergency: boolean?): string
    if not self.Running then
        return "failed"
    end

    local Mind = self.Mind
    local State, Config = Mind.Snapshot.self, Mind.Config
    if self.Interface.Block(Grid) then
        self.Pending = nil
        return "complete"
    end
    if self.Pending then
        if Now - self.Pending.started > Config.PlacementTimeout then
            self.Memory:Route(Grid, "placement", Now)
            self:Fail("Placement was not confirmed by collision geometry", Now)
            return "failed"
        end
        return "pending"
    end
    if Now < self.NextPlace then
        return "pending"
    end
    if State.blocks <= (Emergency and 0 or Config.BlockReserve) then
        self:Fail("Emergency block reserve would be spent", Now)
        return "failed"
    end

    local Placement = self.Planner:SolvePlacement({Position = State.position, Velocity = State.velocity, Grounded = State.grounded}, Grid, {Mode = "Legit"})
    local Goal, Route = Mind.Goal, self.Route
    Mind.WorldState.environment.lastPlacement = {value = Placement, timestamp = Now, confidence = 1, source = "cache"}
    if not Placement.Valid and Placement.Reason == "Body" and (Goal and Goal.name == "BuildUp" or self.Approach == "Build") and State.grounded and not self.TowerJump then
        self.TowerJump = Now
        self.Interface.Move(State.position, true)
        return "pending"
    end
    if not Placement.Valid and self.TowerJump and Now - self.TowerJump < Config.JumpCommitTime then
        return "pending"
    end
    if not Placement.Valid or not self.Interface.ValidatePlacement(Placement, Route and Route.Waypoints[Route.Cursor]) then
        self.Memory:Route(Grid, "placement", Now)
        self:Fail(`Invalid placement: {Placement.Reason or "collision, movement or escape corridor"}`, Now)
        return "failed"
    end

    self.NextPlace = Now + math.max(Config.PlacementCooldown, State.placeInterval or 0)
    self.Pending = {grid = Grid, started = Now}
    self.TowerJump = nil
    self.Interface.Place(Placement.Position)
    return "pending"
end

function AgentClass.Stale(self, Route)
    if self.Planner ~= Navigation then
        return self.Planner:IsStale(Route.Result)
    end
    return Route:Stale()
end

function AgentClass.Drifted(self, Route, Target: Vector3?, Position: Vector3): boolean
    if not Route.Target or not Target then
        return false
    end
    local Config = self.Mind.Config
    return (Target - Route.Target).Magnitude > math.clamp((Target - Position).Magnitude * Config.TargetDrift, Config.ArrivalRadius, 30)
end

function AgentClass.Adopt(self, Plan, State, Now: number)
    local Current, Config = self.Route, self.Mind.Config
    Plan:Resume(State.position, State.velocity, State.airborne)

    if Current and not Current.Expired and Current.Kind == Plan.Kind and Current.TargetId == Plan.TargetId and Current.Cursor <= #Current.Waypoints and #Plan.Waypoints > 0 and not self:Stale(Current) then
        if Current:Deviation(Plan) <= CellSize * 1.1 then
            Current.Target = Plan.Target or Current.Target
            return Current, false
        end
        local Mine, Theirs = Current.Waypoints[#Current.Waypoints], Plan.Waypoints[#Plan.Waypoints]
        if (Mine.Position - Theirs.Position).Magnitude <= CellSize and Plan:Remaining() >= Current:Remaining() * (1 - Config.ReplanMargin) then
            return Current, false
        end
    end

    self.PlanRevision += 1
    Plan.Revision = self.PlanRevision
    self.Route, self.Index, self.Breakouts = Plan, Plan.Cursor, 0
    self.ProgressAt, self.ProgressPosition, self.ProgressDistance, self.Nudged = Now, State.position, math.huge, nil
    return Plan, true
end

function AgentClass.Hold(self, State)
    if self.Jumping and State.airborne then
        return
    end
    self.Interface.Stop()
end

function AgentClass.Dispatch(self, Destination, State, Now: number)
    if self.Planner == Navigation and not Navigation.World then
        return false
    end
    if self.Request then
        self.Request:Cancel()
    end

    local Request = self.Planner:FindPathAsync({Position = State.position, Velocity = State.velocity, Grounded = State.grounded}, Destination.position, self:Options(State))
    Request.Generation, Request.TargetId, Request.Target, Request.Origin = self.Generation, Destination.id, Destination.position, State.position
    self.Request, self.RequestedAt, self.RouteGoal = Request, Now, Destination.position
    return true
end

function AgentClass.Receive(self, Goal, Destination, State, Now: number)
    local Mind, Request = self.Mind, self.Request
    local Config = Mind.Config
    if not Request.Done then
        if Now - self.RequestedAt > Config.PlanTimeout then
            if self.Route then
                Request:Cancel()
                self.Request = nil
            else
                self:Fail("Navigation exceeded its planning deadline", Now)
            end
        end
        return
    end

    self.Request = nil
    local Result = Request.Result
    if Request.Generation ~= self.Generation or Request.TargetId ~= Destination.id then
        return
    end
    if not Result or not Result.Success or Result.Partial then
        if self.Route and not self:Stale(self.Route) then
            return
        end
        if Result and Result.Reason == "NoPath" and self:Breakout(State, Destination.position, Now) then
            return
        end
        self:Fail(Result and Result.Reason or "Path computation failed", Now)
        return
    end

    local Actions = Result.Actions or {}
    local Samples, Jumps, Turns, Narrow, Previous, LastDirection = {}, 0, 0, false, State.position, nil
    local Stride: number = math.max(1, math.ceil(#Actions / Config.RouteSampleLimit))
    for i: number, v: any in Actions do
        if v.Type ~= "PlaceBlock" then
            if i % Stride == 0 or i == #Actions then
                table.insert(Samples, v.Position)
                Narrow = Narrow or self.Interface.Surface(v.Position).narrow
            end
            Jumps += v.Type == "Jump" and 1 or 0
            local Direction: Vector3 = (v.Position - Previous) * Planar
            if Direction.Magnitude > 0.1 then
                Turns += LastDirection and LastDirection:Dot(Direction.Unit) < 0.5 and 1 or 0
                LastDirection = Direction.Unit
            end
            Previous = v.Position
        end
    end

    local Assessment = Mind.Assessment
    local Blocks: number = Result.BlocksUsed or 0
    local Risk, Nearest = Mind:RouteRisk(Samples, Now)
    local Danger: number = Risk + Jumps * Config.Weights.Jump + Turns * Config.Weights.Turns + Blocks * Config.Weights.Block + (Narrow and Config.Weights.Narrow or 0)
    local Limit: number = (Mind.Retreating or Assessment.carrying) and Config.SafeRouteRisk or Config.RouteRiskLimit
    local DestinationRisk: number = Mind:RouteRisk({Destination.position}, Now)
    if Danger > Limit or Goal.emergency and Assessment.target and Nearest + Config.ArrivalRadius < Assessment.nearest
        or Goal.name ~= "BuildUp" and (Mind.Retreating or Assessment.carrying) and (Blocks > 0 or Jumps > 0 or DestinationRisk > Config.SafeRouteRisk) then
        self:Fail("Route exposes health or cargo to unacceptable risk", Now)
        return
    end

    local Plan = self:Adopt(Navigation.newPlan(Result, {Kind = "Path", TargetId = Destination.id, Target = Request.Target, Origin = Request.Origin, Now = Now}), State, Now)
    Mind.WorldState.self.currentRoute = {value = Plan.Result, timestamp = Now, confidence = 1, source = "cache"}
    Mind.WorldState.self.currentEscapeRoute = {value = Goal.emergency and Plan.Result or false, timestamp = Now, confidence = 1, source = "cache"}
    Mind.WorldState.environment.bridgeQuality = {value = {narrow = Narrow, jumps = Jumps, turns = Turns, blocks = Blocks, risk = Danger}, timestamp = Now, confidence = 1, source = "raycast"}
end

function AgentClass.Follow(self, Route, State, Now: number)
    local Config = self.Mind.Config
    local Points, Position = Route.Waypoints, State.position
    local Point, Distance

    for _ = 1, 4 do
        Point = Points[Route.Cursor]
        if not Point then
            self:Fail("Route ended outside interaction range", Now)
            return
        end

        if Point.Blocks and not Point.Built then
            for _, v: any in Point.Blocks do
                local Status: string = self:Place(v.Grid, Now)
                if Status ~= "complete" then
                    if Status == "pending" then
                        self.Interface.Stop()
                    end
                    return
                end
            end
            Point.Built, self.ProgressAt = true, Now
        end

        local Previous = Points[Route.Cursor - 1]
        local Lateral, _, Raw = SegmentDistance(Previous and Previous.Position or Route.Origin or Position, Point.Position, Position)
        Distance = (Point.Position - Position).Magnitude
        if Distance > Config.ArrivalRadius * 0.35 and not (Raw >= 1 and Lateral <= 1.5 and math.abs(Point.Position.Y - Position.Y) <= 2.5) then
            break
        end

        Route.Cursor += 1
        self.Index = Route.Cursor
        self.ProgressAt, self.ProgressDistance, self.Jumping, self.Nudged = Now, math.huge, nil, nil
        self:Settled(Now)
        Point = nil
    end

    if not Point then
        return
    end

    if Distance < self.ProgressDistance - Config.ProgressDistance then
        self.ProgressAt, self.ProgressDistance = Now, Distance
    elseif self.ProgressDistance < math.huge and Distance > self.ProgressDistance + CellSize * 2 and Now >= self.NextVerify then
        self.NextVerify = Now + Config.VerifyInterval
        local _, Gap = Route:Resume(Position, State.velocity, State.airborne)
        self.Index, self.ProgressDistance = Route.Cursor, math.huge
        if Gap > Config.OffRoute then
            self:Repath("Displaced from the route", Now)
            self:Hold(State)
        end
        return
    end

    local Stalled: number = Now - (self.ProgressAt or Now)
    if Stalled > Config.StuckTime then
        self:Recover(Point, State, Now)
        return
    end

    if Stalled > Config.StuckTime * 0.5 and not self.Nudged and State.grounded and self.Interface.ValidateMove(Point, false) then
        self.Nudged = Now
        self.RecoveryState = "NUDGE"
        self.Interface.Move(Point.Position, true, "Nudge")
        return
    end

    local Jump = Point.Type == "Jump" and not self.Jumping and State.grounded
    if not self.Interface.ValidateMove(Point, self.Jumping ~= nil) then
        self:Repath("Next movement lacks collision support or clearance", Now, self:Ahead(State, Point))
        self:Hold(State)
        return
    end
    if Jump then
        self.Jumping = Now
    end
    self.Interface.Move(Point.Position, Jump, Point.Type)
    if self.Stage == 0 then
        self.RecoveryState = "REASSESS"
    end
end

function AgentClass.Navigate(self, Goal, Now: number): boolean
    local Mind = self.Mind
    local State, Config = Mind.Snapshot.self, Mind.Config
    local Destination = Goal.destination
    if not Destination or not self.Interface.Valid(Destination) then
        self:Fail("Destination disappeared or changed team", Now)
        return false
    end

    if (Destination.position - State.position).Magnitude <= (Goal.action == "Fight" and (State.attackRange or Config.LethalRange * 0.65) or Config.ArrivalRadius) then
        self.Interface.Stop()
        if self.Route or self.Request then
            self:Drop()
        end
        return true
    end

    if self.Request then
        self:Receive(Goal, Destination, State, Now)
        if self.ActiveGoal ~= Goal.id then
            return false
        end
    end

    if self.Breaking then
        self:Unblock(Now)
        return false
    end

    local Route = self.Route
    if Route and self:Stale(Route) then
        self:Repath("Route support changed", Now)
        Route = nil
    end

    if not Route then
        if not self.Request and not self:Dispatch(Destination, State, Now) then
            self:Fail("Navigation world is unavailable", Now)
            return false
        end
        self:Hold(State)
        return false
    end

    if not self.Request and Now - (self.RequestedAt or -math.huge) >= Config.ReplanInterval and self:Drifted(Route, Destination.position, State.position) then
        self:Dispatch(Destination, State, Now)
    end

    self:Follow(Route, State, Now)
    return false
end

function AgentClass.Step(self, Snapshot, Now: number)
    if not self.Running then
        return
    end

    Now = Now or os.clock()
    self.Now = Now
    Snapshot = Snapshot or self.Interface.Observe(Now)

    local Mind = self.Mind
    local Route = self.Route
    local Landing = Route and Route.Waypoints[Route.Cursor]
    if self.Jumping and Landing and Now - self.Jumping < Mind.Config.JumpCommitTime then
        if self.Interface.ValidateMove(Landing, true) and (Landing.Position - Snapshot.self.position):Dot(Snapshot.self.velocity) > 0 then
            Snapshot.self.falling = false
        end
    end

    Snapshot.self.currentlyBuilding = self.Pending ~= nil
    Snapshot.self.currentlyAttacking = Mind.Goal and Mind.Goal.action == "Fight" or false
    Snapshot.self.currentlyRetreating = Mind.Retreating
    Mind:Observe(Snapshot, Now)

    local Previous = Mind.Goal
    if Now >= self.NextThink or Snapshot.self.falling or Snapshot.self.underPressure or not Snapshot.self.alive or Snapshot.environment.bedThreat or Previous and Previous.destination and not self.Interface.Valid(Previous.destination) then
        Mind:Decide(Now)
        self.NextThink = Now + Mind.Config.ThinkInterval
    end

    local Goal, Config = Mind.Goal, Mind.Config
    if not Goal then
        self:Describe()
        return
    end

    if self.ActiveGoal ~= Goal.id then
        if self.Jumping and Landing and not Snapshot.self.grounded and not Snapshot.self.falling and Now - self.Jumping < Config.JumpCommitTime then
            if self.Interface.ValidateMove(Landing, true) then
                self.Interface.Move(Landing.Position, false)
                return
            end
        end
        self:Cancel()
        self.ActiveGoal = Goal.id
        self.Stalls, self.Stage, self.Approach = 0, 0, nil
        self.ReadyAt = Now + (Goal.emergency and 0 or Config.ReactionTime)
        self:Log(Goal.name, Goal.reason)
    end

    if Now < (self.ReadyAt or 0) then
        return
    end
    if not Snapshot.self.alive or Snapshot.environment.matchEnded then
        self.Interface.Stop()
        return
    end

    local State, Assessment = Snapshot.self, Mind.Assessment
    if self.Purchase and Now - self.Purchase.started > Config.PlanTimeout then
        self.Purchase = nil
        self.BuyUntil = Now + Config.FailureCooldown
    end

    if Goal.action == "Recover" then
        self.Interface.Stop()
        if Now < Mind.NextAction then
            return
        end
        self.RecoveryState = "BUILD_RECOVERY_PLATFORM"
        local Result = self.Planner:FindClutch({Position = State.position, Velocity = State.velocity, Grounded = false}, {
            Mode = "Legit", BlocksAvailable = State.blocks, Clutch = {Void = true, MaxBlocks = Config.BuildLimit}
        })
        if Result.Success and Result.BridgePath[1] then
            self:Place(Result.BridgePath[1].Grid, Now, true)
        elseif not self.RecoveryReported then
            self.RecoveryReported = true
            self:Log("FIND_SAFE_SURFACE", "No physically valid clutch placement is available")
        end
        return
    end
    self.RecoveryReported = nil

    if Goal.action == "BuildCover" or Goal.action == "BuildUp" then
        self.Interface.Stop()
        if not self.Build then
            self.Build = self.Interface.Build(Goal.action, Assessment, Config.BuildLimit)
        end
        if not self.Build or not self.Build[1] then
            self:Fail("No useful legal building continuation", Now)
            return
        end
        if self:Place(self.Build[1], Now) == "complete" then
            table.remove(self.Build, 1)
            if #self.Build == 0 then
                self.Build = nil
                Mind:Complete(Goal, Now)
                Mind.NextAction = Now + Config.ReactionTime
                self.NextThink = 0
            end
        end
        return
    end

    if Goal.action == "Harass" then
        self.Interface.Stop()
        if Now >= self.NextAttack and Assessment.count == 0 and State.safeSurface and not State.nearVoid then
            self.NextAttack = Now + Config.RangedInterval
            self.Interface.Ranged(Goal.destination)
        end
        return
    end

    if Goal.destination and not self:Navigate(Goal, Now) then
        if Assessment.chased and State.safeSurface and State.cover and Assessment.nearest > Config.LethalRange and State.projectiles > 0 and Now >= self.NextAttack then
            self.NextAttack = Now + Config.RangedInterval
            self.Interface.Ranged(Assessment.target)
        end
        self:Describe()
        return
    end

    self.Interface.Stop()
    if Goal.action == "Fight" then
        local Current = Mind:Assess(Now)
        if not Goal.destination or not self.Interface.Valid(Goal.destination) or Current.target and Current.target.id ~= Goal.destination.id
            or Goal.name ~= "SurvivalCombat" and Goal.name ~= "Finish" and Goal.name ~= "DefendBed" and (Current.fightScore < Config.FightThreshold or Current.highGround or State.nearVoid or State.narrowBridge or Mind.Retreating) then
            self:Fail("Fight conditions changed; disengaging", Now)
            return
        end
        if Now >= self.NextAttack then
            self.NextAttack = Now + Config.AttackInterval
            self.Interface.Attack(Goal.destination)
        end
    elseif Goal.action == "Buy" then
        if self.Purchase then
            if self.Purchase.done then
                if self.Purchase.success then
                    Mind:Complete(Goal, Now)
                    self.Purchase = nil
                    Mind.Recovery, self.NextThink = 0, 0
                    self.BuyUntil = Now + Config.PlacementTimeout
                else
                    self:Fail("Shop rejected purchase", Now)
                end
            elseif Now - self.Purchase.started > Config.PlanTimeout then
                self:Fail("Purchase acknowledgement timed out", Now)
            end
        elseif Snapshot.purchase and Now >= (self.BuyUntil or 0) and Assessment.count == 0 and not Mind.Retreating and State.inventorySpace ~= false then
            local Pending = {started = Now}
            self.Purchase = Pending
            self.Interface.Buy(Goal.destination, Snapshot.purchase, function(Success)
                if self.Running and self.Purchase == Pending then
                    Pending.done, Pending.success = true, Success
                end
            end)
        end
    elseif Goal.action == "BreakBed" then
        if Now >= self.NextAttack and Snapshot.canBreakBed and Assessment.count == 0 and not Mind.Retreating then
            self.NextAttack = Now + Config.AttackInterval
            self.Interface.BreakBed(Goal.destination)
        end
    elseif Goal.action == "Collect" then
        self.RecoveryState = "REASSESS"
        local Amount: number = (State.resources or {})[Goal.destination.resource] or 0
        if self.Collected ~= Amount then
            self.Collected = Amount
            self.NextThink = 0
            Mind.Recovery = 0
        end
        if Goal.destination.kind == "drop" and Now >= self.NextAttack then
            self.NextAttack = Now + Config.RangedInterval
            self.Interface.Pickup(Goal.destination)
        end
    elseif Assessment.target then
        self.Interface.Look(Assessment.target.position)
    end
    self:Describe()
end

function AgentClass.Draft(self, From, Target: Vector3?, Options, Threats, TargetId, Request)
    local Now: number = os.clock()
    self.Now = Now
    if self.Planner == Navigation and not Navigation.World then
        return nil, nil
    end

    Options = Options or {}
    Options.Avoid = Options.Avoid or self.Memory:Avoid(Now)
    local State = typeof(From) == "Vector3" and {Position = From} or From
    local Result = Threats and self.Planner:FindRetreat(State, Threats, Options, Request) or self.Planner:FindPath(State, Target, Options, Request)
    if Request and Request.Cancelled then
        return nil, Result
    end
    local Plan = Navigation.newPlan(Result, {
        Kind = Threats and "Retreat" or "Path",
        TargetId = TargetId,
        Target = Threats and Result.Goal and Result.Goal * CellSize or Target,
        Origin = State.Position,
        Now = Now
    })

    if #Plan.Waypoints == 0 and Result.Success and Result.Goal then
        table.insert(Plan.Waypoints, {Type = "Walk", Grid = Result.Goal, Position = Result.Goal * CellSize, Center = Result.Goal * CellSize})
    elseif #Plan.Waypoints == 0 then
        Plan = nil
        local Points = Target and not Threats and self.Fallback and self.Fallback(State.Position, Target)
        if Points and #Points > 0 and (Points[#Points] - Target).Magnitude <= 6 then
            Plan = Navigation.newPlan({}, {Kind = "Fallback", TargetId = TargetId, Target = Target, Origin = State.Position, Now = Now, World = Navigation.World})
            for _, v: Vector3 in Points do
                table.insert(Plan.Waypoints, {Type = "Walk", Position = v, Center = v})
            end
        end
    end

    if not Plan then
        self.LastFailure = Result.Reason
        return nil, Result
    end
    if Options.Label and self.Interface then
        for _, v: any in Plan.Waypoints do
            v.Ground = self.Interface.Label(v.Center)
        end
    end

    return Plan, Result
end

function AgentClass.Plan(self, From, Target: Vector3?, Options, Threats, TargetId)
    local Plan, Result = self:Draft(From, Target, Options, Threats, TargetId)
    if not Plan then
        return nil, false, Result
    end

    local State = typeof(From) == "Vector3" and {Position = From} or From
    local Current, Adopted = self:Adopt(Plan, {position = State.Position, velocity = State.Velocity, airborne = State.Airborne}, self.Now)
    return Current, Adopted, Result
end

function AgentClass.Current(self)
    return self.Route
end

function AgentClass.IsCurrent(self, Plan): boolean
    return Plan ~= nil and self.Route == Plan
end

function AgentClass.Invalidate(self, Reason: string?)
    if self.Route then
        self.Route.Expired = true
    end
    if Reason then
        self.LastFailure = Reason
    end
end

function AgentClass.Cheapest(self, Targets, Origin: Vector3, Options)
    if #Targets == 0 then
        return nil
    end

    local Positions: {Vector3} = {}
    for i: number, v: any in Targets do
        Positions[i] = v.Position
    end

    local Costs = (self.Planner ~= Navigation or Navigation.World) and self.Planner:GetBlockCosts(Origin, Positions, Options) or {}
    local Margin: number = self.Mind.Config.TargetMargin
    local Best, Cost, Distance = nil, math.huge, math.huge
    for i: number, v: any in Targets do
        local Value: number = (Costs[i] or 0) - (v.Id == self.Target and Margin or 0)
        local Magnitude: number = (Origin - v.Position).Magnitude
        if Value < Cost or Value == Cost and Magnitude < Distance then
            Best, Cost, Distance = v, Value, Magnitude
        end
    end

    if Best and Best.Id ~= self.Target then
        self.Target = Best.Id
        self.TargetRevision += 1
    end
    return Best, Cost
end

function AgentClass.Event(self, Kind: string, Now: number, Data)
    local Mind = self.Mind
    if Kind == "death" then
        local Snapshot = Mind.Snapshot
        if Snapshot then
            Mind:Record("failure", Mind.Goal and Mind.Goal.id or "death", Mind.Assessment and Mind.Assessment.carrying and "Died carrying resources" or "Died during objective", Now, Snapshot.self.position)
            self.Memory:Route(Navigation.WorldToGrid(Snapshot.self.position - Vector3.new(0, (Snapshot.self.hipHeight or 3) - HalfCell, 0)), "death", Now)
        end
        self:Cancel()
    elseif Kind == "kill" then
        Mind:Record("kill", "combat", "Check health, cargo and reinforcements after a kill", Now)
        self:Cancel()
    elseif Kind == "forget" then
        Mind.WorldState.enemies[Data] = nil
    elseif Kind == "inventory" then
        self.NextThink = 0
    elseif Kind == "bed" then
        self.NextThink = 0
        if self.Interface and self.Interface.Mark then
            self.Interface.Mark("beds")
        end
    end
end

function AgentClass.Describe(self)
    local Mind, Route, State = self.Mind, self.Route, self.DebugState
    local Goal, Assessment = Mind.Goal, Mind.Assessment
    State.Goal = Goal and Goal.name or self.Objective
    State.Target = Goal and Goal.destination and Goal.destination.id or self.Target
    State.Subgoal = Goal and Goal.action or self.Subgoal
    State.Reason = Goal and Goal.reason or self.Reason
    State.Route = Route and #Route.Waypoints or 0
    State.Cursor = Route and Route.Cursor or 0
    State.RouteCost = Route and Route.Cost or 0
    State.Blocks = Route and Route:Pending() or 0
    State.Threat = Assessment and Assessment.score or 0
    State.Health = Assessment and Assessment.healthState or nil
    State.Replanning = self.Request ~= nil
    State.LastFailure = self.LastFailure
    State.PlanRevision = self.PlanRevision
    State.GoalRevision = Mind.Revision
    State.Recovery = self.RecoveryState
    State.Stage = self.Stage
    return State
end

function AgentClass.Summary(self)
    local State = self:Describe()
    return string.format("goal=%s target=%s subgoal=%s reason=%s route=%d/%d cost=%.1f blocks=%d threat=%.0f health=%s replanning=%s revision=%d/%d recovery=%s stage=%d failure=%s",
        tostring(State.Goal), tostring(State.Target), tostring(State.Subgoal), tostring(State.Reason), State.Cursor, State.Route, State.RouteCost, State.Blocks,
        State.Threat, tostring(State.Health), tostring(State.Replanning), State.PlanRevision, State.GoalRevision, tostring(State.Recovery), State.Stage, tostring(State.LastFailure))
end

function AgentClass.Repath(self, Reason: string, Now: number, Grid: Vector3?, Stage: string?)
    local Config = self.Mind.Config
    local Repaths: {number} = self.Repaths
    if Grid then
        self.Memory:Route(Grid, Reason, Now)
    end

    table.insert(Repaths, Now)
    while Repaths[1] and Now - Repaths[1] > Config.RepathWindow do
        table.remove(Repaths, 1)
    end

    self.LastFailure = Reason
    if #Repaths > Config.RecoveryLimit * 2 then
        table.clear(Repaths)
        self:Fail(`Repeated route failures: {Reason}`, Now)
        return
    end

    self.RecoveryState = Stage or "REPATH"
    self:Log("repath", Reason)
    self:Drop()
end

function AgentClass.Ahead(self, State, Point): Vector3
    local Flat: Vector3 = (Point.Position - State.position) * Planar
    local Step: Vector3 = Flat.Magnitude > 0.1 and Flat.Unit * CellSize or Vector3.zero
    return Navigation.WorldToGrid(State.position + Step - Vector3.new(0, (State.hipHeight or Navigation.Config.Agent.HipHeight) - HalfCell, 0))
end

function AgentClass.Obstruction(self, State, Point, Now: number)
    if not self.Interface.Break then
        return nil
    end

    local Feet: Vector3 = self:Ahead(State, Point)
    for Height: number = 0, 1 do
        local Grid: Vector3 = Feet + Vector3.new(0, Height, 0)
        if self.Interface.Block(Grid) then
            self.Breaking = {grid = Grid, started = Now}
            return Grid
        end
    end
    return nil
end

function AgentClass.Breakout(self, State, Target: Vector3, Now: number): boolean
    if not self.Interface.Break or self.Breakouts >= 4 then
        return false
    end

    local World = self.Planner.World
    local Flat: Vector3 = (Target - State.position) * Planar
    local Feet: Vector3 = Navigation.WorldToGrid(State.position - Vector3.new(0, (State.hipHeight or Navigation.Config.Agent.HipHeight) - HalfCell, 0))
    local Best, Score = nil, -math.huge
    for i: number = 1, 4 do
        local Direction: {number} = Flats[i]
        local Open: boolean = true
        for Height: number = 0, 1 do
            local Grid: Vector3 = Feet + Vector3.new(Direction[1], Height, Direction[3])
            local Placed = self.Interface.Block(Grid)
            if Placed or World and World:Solid(Grid.X, Grid.Y, Grid.Z) then
                Open = false
            end
            if Placed then
                local Value: number = Flat.Magnitude > 0.1 and Flat.Unit:Dot(Vector3.new(Direction[1], 0, Direction[3])) or 0
                if Value > Score then
                    Best, Score = Grid, Value
                end
            end
        end
        if Open then
            return false
        end
    end

    if not Best then
        return false
    end
    self.Breakouts += 1
    self.Breaking = {grid = Best, started = Now}
    self.RecoveryState = "BREAK_OBSTRUCTION"
    self:Log("breakout", "Enclosed by placed blocks; breaking toward the destination")
    return true
end

function AgentClass.Recover(self, Point, State, Now: number)
    self.Stalls += 1
    self.StalledAt = Now
    self.Stage = math.min(self.Stalls + 1, 6)
    self.ProgressAt, self.ProgressDistance, self.Nudged = Now, math.huge, nil

    local Cell: Vector3 = self:Ahead(State, Point)
    if self.Stage == 2 then
        self:Repath("Movement stalled; re-evaluating the local route", Now, Cell, "REPATH")
    elseif self.Stage == 3 then
        self.Approach = "Careful"
        self:Repath("Stalled again; changing the movement approach", Now, Cell, "CHANGE_APPROACH")
    elseif self.Stage == 4 then
        self.Approach = "Build"
        self:Repath("Stalled repeatedly; allowing build-up and alternate routes", Now, Cell, "ALTERNATE_ROUTE")
    elseif self.Stage == 5 and self:Obstruction(State, Point, Now) then
        self.RecoveryState = "BREAK_OBSTRUCTION"
        self.Interface.Stop()
    else
        self:Fail("Movement stalled or building has no continuation", Now)
    end
end

function AgentClass.Unblock(self, Now: number)
    local Breaking, Config = self.Breaking, self.Mind.Config
    if not self.Interface.Block(Breaking.grid) then
        self.Breaking = nil
        self:Repath("Obstruction cleared", Now, nil, "REPATH")
    elseif Now - Breaking.started > Config.BreakTimeout then
        self.Breaking = nil
        self:Fail("Obstruction could not be broken", Now)
    elseif Now >= self.NextAttack then
        self.NextAttack = Now + Config.AttackInterval
        self.Interface.Break(Breaking.grid)
    end
end

function AgentClass.Settled(self, Now: number)
    if self.Stalls > 0 and Now - (self.StalledAt or 0) > self.Mind.Config.RecoveryReset then
        self.Stalls, self.Stage, self.Approach = 0, 0, nil
        self.RecoveryState = "REASSESS"
    end
end

Navigation.Brain = {
    Config = Navigation.Config.Mind,
    new = Navigation.newMind
}

Navigation.Adapter = {
    new = Navigation.newInterface
}

Navigation.Controller = {
    Pattern = Navigation.Pattern,
    new = function(Brain, Planner, Adapter)
        return Navigation.newAgent({Mind = Brain, Planner = Planner, Interface = Adapter})
    end
}

function Navigation.newDebugAdapter(Parent: Instance?, Limit: number?)
    local Pool: {Part} = {}
    local Index: number = 0
    local Model: Model = Instance.new("Model")
    Model.Name = "navigation"
    Model.Parent = Parent or workspace.Terrain

    return {
        Model = Model,
        Point = function(Position: Vector3, Color: Color3, Size: number?)
            if Index >= (Limit or 600) then
                return
            end

            Index += 1
            local Part: Part? = Pool[Index]
            if not Part then
                Part = Instance.new("Part")
                Part.Anchored = true
                Part.CanCollide = false
                Part.CanQuery = false
                Part.CanTouch = false
                Part.Material = Enum.Material.Neon
                Part.Parent = Model
                Pool[Index] = Part
            end

            Part.Size = Vector3.new(Size or 1, Size or 1, Size or 1)
            Part.Color = Color
            Part.Transparency = 0.55
            Part.Position = Position
        end,
        Clear = function()
            for Slot: number = 1, Index do
                Pool[Slot].Transparency = 1
                Pool[Slot].Position = Vector3.new(9e9, 9e9, 9e9)
            end
            Index = 0
        end
    }
end

function Navigation.Visualize(self, Result)
    if not self.DebugAdapter then
        self.DebugAdapter = self.newDebugAdapter()
    end

    self.DebugAdapter.Clear()

    for _, v: any in Result.Actions do
        if v.Type == "PlaceBlock" then
            self.DebugAdapter.Point(v.Position, v.PlacementType == "Diagonal" and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(70, 140, 255), CellSize - 0.4)
            self.DebugAdapter.Point(v.AimPosition, Color3.fromRGB(255, 255, 255), 0.5)
        elseif v.Type == "Land" then
            self.DebugAdapter.Point(v.Position, Color3.fromRGB(255, 60, 60), 1.4)
        else
            self.DebugAdapter.Point(v.Position, v.Type == "Jump" and Color3.fromRGB(255, 230, 90) or Color3.fromRGB(90, 255, 120), 1)
        end
    end

    return self.DebugAdapter
end

return Navigation